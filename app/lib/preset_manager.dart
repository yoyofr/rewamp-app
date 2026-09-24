import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rewamp_audio/rewamp_audio.dart';

import 'download_cancel.dart';
import 'download_manager.dart';
import 'local_db.dart';
import 'rewamp_db.dart' show PresetInfo, PresetPack, PresetPlaylistInfo, RewampDb;
import 'user_settings.dart';

/// Manages the Milkdrop presets the projectM visualizer plays: server packs,
/// user imports, local preset playlists, and which SOURCE is active.
///
/// Disk layout, all under `<datadir>/projectm/` (the same datadir the native
/// engine got via setDataDir — its default scan targets `presets/`):
///   presets/         bundled martins — REWRITTEN on `_kBundledAssetsVersion`
///                    bump, so nothing user-owned may live there
///   `packs/<slug>/`    installed server packs (archive structure preserved)
///   `packtex/<key>/`   pack texture bundles, key = sha1 of the URL — several
///                    packs share one bundle, it is downloaded once
///   `single/<id>.milk` presets downloaded one by one (id = server uuid5,
///                    stable across re-imports → the filename IS the id)
///   user/            local imports (picker, drag'n'drop, archives) — preset
///                    AND texture files (a .milk names its bitmaps bare)
///
/// Every path stored in the DB (pm_playlist_items.path, pm_preset_ids.path)
/// is RELATIVE to `<datadir>/projectm/`: the iOS container UUID changes on
/// every app update, an absolute path would break.
class PresetManager extends ChangeNotifier {
  PresetManager._();
  static final PresetManager instance = PresetManager._();

  late String _pmDir; // <datadir>/projectm
  RewampAudio? _audio;
  bool _ready = false;

  /// Progress 0..1 per job key (`pack:<slug>`, `srvlist:<id>`), removed when
  /// idle. UI listens per row (same mechanism as SoundfontManager).
  final ValueNotifier<Map<String, double>> progress = ValueNotifier(const {});

  /// Last pack-install failure, for the packs screen (DownloadManager swallows
  /// job errors by design — the job itself must surface them).
  String? lastError;

  void init(String dataDir, RewampAudio audio) {
    _pmDir = '$dataDir/projectm';
    _audio = audio;
    _ready = true;
  }

  // ── Directories & path mapping ─────────────────────────────────────────────

  String get bundledPresetsDir => '$_pmDir/presets';
  String get bundledTexturesDir => '$_pmDir/textures';
  String get userDir => '$_pmDir/user';
  String get singleDir => '$_pmDir/single';
  String packDir(String slug) => '$_pmDir/packs/$slug';

  String _urlKey(String url) => sha1.convert(url.codeUnits).toString();
  String texturesDirFor(String url) => '$_pmDir/packtex/${_urlKey(url)}';

  /// Relative (to `<datadir>/projectm/`) form of an absolute preset path.
  String relOf(String abs) =>
      abs.startsWith('$_pmDir/') ? abs.substring(_pmDir.length + 1) : abs;

  String absOf(String rel) => rel.startsWith('/') ? rel : '$_pmDir/$rel';

  // ── Sources ────────────────────────────────────────────────────────────────
  //
  // Encoded as the persisted `vis.pm_source` string:
  //   'bundled'                  bundled martins
  //   'all'                      everything installed
  //   'user'                     local imports
  //   'pack:<slug>'              one installed pack
  //   'packdir:<slug>/<folder>'  a folder within a pack
  //   'plist:<id>'               a local pm_playlist (incl. imported curated)

  String get activeSource => UserSettings.instance.pmSource;

  /// Le filtre du garde-fou de cadence, appliqué à TOUTE liste poussée au
  /// moteur — un seul point de passage, sinon un chemin oublié (démarrage,
  /// aperçu, playlist) ramènerait le preset écarté.
  List<String> _withoutSlow(List<String> paths) {
    final blocked = UserSettings.instance.pmSlowPresets;
    if (blocked.isEmpty) return paths;
    final set = blocked.toSet();
    final kept = [for (final p in paths) if (!set.contains(relOf(p))) p];
    // Jamais VIDE: une liste vide laisse le moteur scanner son dossier par
    // défaut, ce qui ramènerait justement ce qu'on vient d'écarter. Si tout est
    // écarté, c'est au garde-fou de couper le visualiseur, pas à ce filtre.
    return kept.isEmpty ? paths : kept;
  }

  /// Resolves [source] to the absolute paths of existing .milk files.
  Future<List<String>> resolveSource(String source) async {
    if (!_ready) return const [];
    if (source == 'bundled') return _scanMilk(bundledPresetsDir);
    if (source == 'user') return _scanMilk(userDir);
    if (source == 'all') {
      final out = <String>[
        ...await _scanMilk(bundledPresetsDir),
        ...await _scanMilk(userDir),
        ...await _scanMilk(singleDir),
      ];
      final packs = Directory('$_pmDir/packs');
      if (packs.existsSync()) {
        for (final d in packs.listSync().whereType<Directory>()) {
          out.addAll(await _scanMilk(d.path));
        }
      }
      return out;
    }
    if (source.startsWith('pack:')) {
      return _scanMilk(packDir(source.substring(5)));
    }
    if (source.startsWith('packdir:')) {
      final rest = source.substring(8); // <slug>/<folder>
      final slash = rest.indexOf('/');
      if (slash < 0) return _scanMilk(packDir(rest));
      return _scanMilk(
          '${packDir(rest.substring(0, slash))}/${rest.substring(slash + 1)}');
    }
    if (source.startsWith('plist:')) {
      final items =
          await LocalDb.instance.pmPlaylistItems(source.substring(6));
      return [
        for (final it in items)
          if (File(absOf(it.path)).existsSync()) absOf(it.path),
      ];
    }
    return const [];
  }

  /// Écarte [absPath] des listes futures et re-pousse la source: le garde-fou
  /// de cadence vient de le mesurer sous 6 images/s sur cet appareil.
  ///
  /// La liste est FILTRÉE à la résolution plutôt que le fichier supprimé: un
  /// preset trop lourd ici tourne très bien ailleurs, et il appartient souvent
  /// à un pack qu'on ne veut pas amputer. Re-pousser la source est nécessaire —
  /// sans ça la rotation du moteur y reviendrait au tour suivant.
  Future<void> blockSlowPreset(String absPath) async {
    if (!_ready || absPath.isEmpty) {
      debugPrint('[preset] écartement ignoré (ready=$_ready, path="$absPath")');
      return;
    }
    UserSettings.instance.addPmSlowPreset(relOf(absPath));
    debugPrint('[preset] écarté (trop lent): ${relOf(absPath)} — '
        '${UserSettings.instance.pmSlowPresets.length} au total');
    await applySource(UserSettings.instance.pmSource, persist: false);
  }

  /// Remet [rel] (chemin RELATIF, tel que stocké) dans les listes: le
  /// garde-fou l'avait écarté, l'utilisateur le réhabilite.
  Future<void> unblockSlowPreset(String rel) async {
    UserSettings.instance.removePmSlowPreset(rel);
    if (!_ready) return;
    await applySource(UserSettings.instance.pmSource, persist: false);
  }

  /// Resolves and pushes [source] to the native playlist (applied on the
  /// render thread; staged for the next init when the viz is off).
  Future<void> applySource(String source, {bool persist = true}) async {
    final paths = _withoutSlow(await resolveSource(source));
    if (persist) UserSettings.instance.pmSource = source;
    _audio?.projectmSetPlaylist(paths);
    notifyListeners();
  }

  /// Remembers the preset currently on screen, so the next run opens on it.
  /// Stored relative to `<datadir>/projectm/`, like every other preset path.
  void rememberCurrentPreset(String absPath) {
    if (!_ready || absPath.isEmpty) return;
    UserSettings.instance.pmLastPreset = relOf(absPath);
  }

  /// Startup: push texture dirs + the persisted source so the first projectM
  /// init picks them up, opening on the preset the last run ended with. No
  /// network.
  Future<void> applyStartup() async {
    if (!_ready) return;
    await _pushTextureDirs();
    final src = UserSettings.instance.pmSource;
    final last = UserSettings.instance.pmLastPreset;

    // Restoring means naming an index, which means pushing the list we indexed
    // into — including for 'bundled', which otherwise stages nothing and lets
    // the engine scan the default directory itself. Only worth it when the
    // remembered preset is actually still in that list: a pack can be
    // uninstalled, an import deleted, the source changed since.
    if (last != null) {
      final paths = _withoutSlow(await resolveSource(src));
      final idx = paths.indexOf(absOf(last));
      if (idx >= 0) {
        _audio?.projectmSetPlaylist(paths, startIndex: idx);
        notifyListeners();
        return;
      }
    }

    // 'bundled' is the native default — nothing to stage.
    if (src != 'bundled') await applySource(src, persist: false);
  }

  /// Plays [absPath] right now, WITHOUT narrowing the list to it: the active
  /// source stays the list (the preset is prepended when it isn't part of it),
  /// so next/prev keep working — a one-entry playlist made both buttons dead
  /// while the source menu still showed the pack, which read as a bug.
  /// Nothing is persisted: [applySource] or the next startup restores the
  /// source untouched.
  Future<void> previewPreset(String absPath) async {
    // Le filtre s'applique à la LISTE, pas au preset demandé: choisir
    // explicitement un preset écarté doit marcher (c'est une demande, pas la
    // rotation automatique), et il est simplement re-préfixé s'il n'y est plus.
    final list = _withoutSlow(
        await resolveSource(UserSettings.instance.pmSource));
    var idx = list.indexOf(absPath);
    final paths = idx >= 0 ? list : [absPath, ...list];
    if (idx < 0) idx = 0;
    _audio?.projectmSetPlaylist(paths, startIndex: idx);
    notifyListeners();
  }

  Future<List<String>> _scanMilk(String dir) async {
    final d = Directory(dir);
    if (!d.existsSync()) return const [];
    final out = <String>[];
    await for (final e in d.list(recursive: true, followLinks: false)) {
      if (e is File && e.path.toLowerCase().endsWith('.milk')) out.add(e.path);
    }
    out.sort();
    return out;
  }

  Future<void> _pushTextureDirs() async {
    final dirs = <String>[bundledTexturesDir];
    final packtex = Directory('$_pmDir/packtex');
    if (packtex.existsSync()) {
      for (final d in packtex.listSync().whereType<Directory>()) {
        dirs.add(d.path);
      }
    }
    if (Directory(userDir).existsSync()) dirs.add(userDir);
    _audio?.projectmSetTextureDirs(dirs);
  }

  // ── Pack install ───────────────────────────────────────────────────────────

  bool isPackInstalled(String slug) =>
      File('${packDir(slug)}/.installed').existsSync();

  /// What the catalogue said about a pack when it was installed. The marker
  /// file doubles as the signature; older installs wrote a bare URL there and
  /// parse to null — which means "unknown", never "outdated" (proposing a
  /// 116 MB re-download on a guess is worse than missing one update).
  Map<String, dynamic>? _installedStamp(String slug) {
    try {
      final f = File('${packDir(slug)}/.installed');
      if (!f.existsSync()) return null;
      final txt = f.readAsStringSync().trim();
      if (!txt.startsWith('{')) return null;   // legacy: url or 'granular'
      final j = jsonDecode(txt);
      return j is Map ? Map<String, dynamic>.from(j) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeInstalledStamp(PresetPack pack) async {
    await File('${packDir(pack.slug)}/.installed').writeAsString(
      jsonEncode({
        'content_hash': pack.contentHash,
        'textures_hash': pack.texturesHash,
        // Which bundle this pack uses, so an uninstall can tell whether the
        // bundle still has a user without asking the server.
        'textures_key': (pack.texturesUrl == null || pack.texturesUrl!.isEmpty)
            ? null
            : _urlKey(pack.texturesUrl!),
        // Kept for display/debug only — never compared (see packNeedsUpdate).
        'version': pack.version,
        'preset_count': pack.presetCount,
        'total_bytes': pack.totalBytes,
      }),
      flush: true,
    );
  }

  /// True when the catalogue's copy of [pack] no longer matches what was
  /// installed here — presets OR textures.
  ///
  /// `content_hash` / `textures_hash` (server migs 232/233) hash the CONTENT,
  /// so a renamed pack or an edited licence does not trigger a 116 MB
  /// re-download, while a preset swapped for one of the same size does. They
  /// are compared INDEPENDENTLY because they move independently: the images of
  /// a pack can change without a single preset moving, and the reverse.
  ///
  /// The earlier count+size heuristic is gone: a retouched .milk very often
  /// weighs exactly the same. A stamp with no `content_hash` (installed before
  /// this scheme, or a server that publishes none) means UNKNOWN, never
  /// outdated — a wrong guess costs the user a full re-download.
  bool packNeedsUpdate(PresetPack pack) {
    if (!isPackInstalled(pack.slug)) return false;
    final st = _installedStamp(pack.slug);
    if (st == null) return false;   // legacy marker — stay quiet
    final haveContent = st['content_hash'] as String?;
    if (haveContent != null &&
        pack.contentHash != null &&
        haveContent != pack.contentHash) {
      return true;
    }
    return texturesNeedFetch(pack);
  }

  /// Installed packs from DISK (works offline): (slug, display name).
  List<(String, String)> installedPacks() {
    final root = Directory('$_pmDir/packs');
    if (!root.existsSync()) return const [];
    final out = <(String, String)>[];
    for (final d in root.listSync().whereType<Directory>()) {
      if (!File('${d.path}/.installed').existsSync()) continue;
      final slug = d.uri.pathSegments.where((s) => s.isNotEmpty).last;
      var name = slug;
      final nameFile = File('${d.path}/.packname');
      if (nameFile.existsSync()) {
        final n = nameFile.readAsStringSync().trim();
        if (n.isNotEmpty) name = n;
      }
      out.add((slug, name));
    }
    out.sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase()));
    return out;
  }

  /// Where a preset path comes from, for display:
  /// ('pack', display name, sub-folder within the pack or null) |
  /// ('bundled'|'user'|'single', null, null) | ('', null, null) when unknown.
  /// The caller maps the kinds to localized labels.
  (String, String?, String?) sourceOfPath(String absPath) {
    if (!_ready || absPath.isEmpty) return ('', null, null);
    final rel = relOf(absPath);
    if (rel.startsWith('packs/')) {
      final parts = rel.split('/');
      if (parts.length < 2) return ('', null, null);
      final slug = parts[1];
      String? name;
      for (final (s, n) in installedPacks()) {
        if (s == slug) { name = n; break; }
      }
      // packs/<slug>/<sub/dirs>/<file> → the dirs between slug and file.
      final subDir = parts.length > 3
          ? parts.sublist(2, parts.length - 1).join('/')
          : null;
      return ('pack', name ?? slug, subDir);
    }
    if (rel.startsWith('presets/')) return ('bundled', null, null);
    if (rel.startsWith('user/')) return ('user', null, null);
    if (rel.startsWith('single/')) {
      // single/<pack>/<sub/dirs>/<file> — name the pack it BELONGS to, so the
      // listener knows which pack to install if they like it.
      final parts = rel.split('/');
      if (parts.length < 3 || parts[1] == '_') return ('single', null, null);
      final slug = parts[1];
      final subDir = parts.length > 3
          ? parts.sublist(2, parts.length - 1).join('/')
          : null;
      return ('single', packNameFor(slug) ?? slug, subDir);
    }
    return ('', null, null);
  }

  /// Imported presets (absolute paths, sorted). Flat: imports are copied by
  /// basename into user/.
  List<String> userPresets() {
    final d = Directory(userDir);
    if (!d.existsSync()) return const [];
    final out = [
      for (final e in d.listSync(recursive: true, followLinks: false))
        if (e is File && e.path.toLowerCase().endsWith('.milk')) e.path,
    ];
    out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  /// One-off downloads still on disk (Popular/Browse "try this one"), as
  /// (absolute path, bytes). Excludes anything a playlist points at — those
  /// are not leftovers.
  Future<List<(String, int)>> orphanSingles() async {
    final d = Directory(singleDir);
    if (!d.existsSync()) return const [];
    final kept = (await LocalDb.instance.pmPlaylistPathsUnder('single/')).toSet();
    final out = <(String, int)>[];
    await for (final e in d.list(recursive: true, followLinks: false)) {
      if (e is! File || !e.path.toLowerCase().endsWith('.milk')) continue;
      if (kept.contains(relOf(e.path))) continue;
      var size = 0;
      try { size = await e.length(); } catch (_) {}
      out.add((e.path, size));
    }
    out.sort((a, b) => a.$1.toLowerCase().compareTo(b.$1.toLowerCase()));
    return out;
  }

  /// Deletes the one-off downloads no playlist references. Returns the count.
  Future<int> purgeOrphanSingles() async {
    _invalidateSingleCache();
    final list = await orphanSingles();
    for (final (path, _) in list) {
      try {
        await File(path).delete();
        await LocalDb.instance.forgetPmPresetPath(relOf(path));
      } catch (_) {}
    }
    if (list.isNotEmpty) {
      _invalidateSingleCache();
      await _reapplyIfCovers('single');
      notifyListeners();
    }
    return list.length;
  }

  bool get hasUserPresets {
    final d = Directory(userDir);
    if (!d.existsSync()) return false;
    return d
        .listSync(recursive: true)
        .any((e) => e is File && e.path.toLowerCase().endsWith('.milk'));
  }

  /// Whether [pack]'s texture bundle must be (re)fetched.
  ///
  /// The directory is keyed by URL — several packs share one bundle and it is
  /// downloaded once — but the URL is STABLE when the images change, so the
  /// marker file carries `textures_hash` and that is what decides. Without it,
  /// a refreshed bundle at the same address would never have been noticed.
  bool texturesNeedFetch(PresetPack pack) {
    final url = pack.texturesUrl;
    if (url == null || url.isEmpty) return false;
    final marker = File('${texturesDirFor(url)}/.installed');
    if (!marker.existsSync()) return true;
    final want = pack.texturesHash;
    if (want == null) return false;           // server publishes no hash
    String have;
    try {
      have = marker.readAsStringSync().trim();
    } catch (_) {
      return true;
    }
    // A marker holding the url is a pre-hash install: unknown, not stale.
    if (have == url) return false;
    return have != want;
  }

  /// Queues the install in the DownloadManager (visible, pausable). Dedup by
  /// key: enqueueing an already-queued pack is a no-op.
  void enqueueInstall(PresetPack pack) {
    DownloadManager.instance
        .enqueue(pack.name, () => installPack(pack), key: 'pmpack:${pack.slug}');
  }

  /// TEXTURES FIRST: a .milk references its bitmaps by bare name, so playing
  /// a pack before its texture bundle landed shows black shapes. The bundle is
  /// keyed by URL — shared across packs, downloaded once.
  Future<void> installPack(PresetPack pack) async {
    final key = 'pack:${pack.slug}';
    _setProgress(key, 0);
    try {
      lastError = null;
      final texUrl = pack.texturesUrl;
      if (texUrl != null && texUrl.isNotEmpty && texturesNeedFetch(pack)) {
        final dir = Directory(texturesDirFor(texUrl));
        _invalidateOrphanTexCache();
        if (dir.existsSync()) await dir.delete(recursive: true);
        await dir.create(recursive: true);
        final tmp = File('${dir.path}/_tmp_textures');
        await _downloadToFile(texUrl, tmp);
        await _extract(tmp.path, dir.path);
        await tmp.delete();
        // The marker IS the signature: the bundle's content hash when the
        // server publishes one, the url otherwise (older servers).
        await File('${dir.path}/.installed')
            .writeAsString(pack.texturesHash ?? texUrl);
      }
      // Claim the bundle even when it was already installed by another pack:
      // that is exactly the shared case the counting exists for.
      if (texUrl != null && texUrl.isNotEmpty) {
        await _addTexUser(_urlKey(texUrl), pack.slug);
      }
      final archUrl = pack.archiveUrl;
      final dir = Directory(packDir(pack.slug));
      if (dir.existsSync()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
      if (archUrl != null && archUrl.isNotEmpty) {
        final tmp = File('${dir.path}/_tmp_archive');
        await _downloadToFile(archUrl, tmp,
            expectedSize: pack.totalBytes, progressKey: key);
        await _extract(tmp.path, dir.path);
        await tmp.delete();
        await _writeInstalledStamp(pack);
      } else {
        // No bulk zip published for this pack (archive_url null — seen live on
        // martins-collection): fall back to GRANULAR install, one preset at a
        // time through browse_presets. Slower, but it also hands us every
        // preset_id for free — cached for usage logging.
        await _installGranular(pack, key);
        await _writeInstalledStamp(pack);
      }
      // Display name for offline listings (the source menu can't reach the
      // server to turn a slug back into a name).
      await File('${dir.path}/.packname').writeAsString(pack.name);
      await _absorbSinglesIntoPack(pack.slug);
      _invalidateSingleCache();
      await _pushTextureDirs();
      await _reapplyIfCovers('pack:${pack.slug}');
    } on DownloadCancelledException {
      // Cancelled by the user: the half-written pack dir is already gone
      // (each step deletes its tmp), and this is NOT an install failure —
      // leaving lastError set would flash « install failed » on the screen.
      debugPrint('[PresetManager] install ${pack.slug} cancelled');
      rethrow;
    } catch (e) {
      lastError = e.toString();
      debugPrint('[PresetManager] install ${pack.slug} FAILED: $e');
      rethrow;
    } finally {
      _setProgress(key, null);
      notifyListeners();
    }
  }

  /// Granular install: walk the pack's server tree and download every preset
  /// into `packs/<slug>/<server path>`. Structure preserved so the usage
  /// resolver's folder-level browse matches; ids cached along the way.
  Future<void> _installGranular(PresetPack pack, String progressKey) async {
    final root = packDir(pack.slug);
    final total = pack.presetCount;
    final idMap = <String, String>{};
    var done = 0;

    Future<void> walk(String folder) async {
      {
        final page =
            await RewampDb.browsePresets(pack: pack.slug, folder: folder);
        for (final d in page.dirs) {
          await walk(d.dirPath);
        }
        for (final p in page.presets) {
          final url = p.downloadUrl;
          if (url == null || url.isEmpty) continue;
          var rel = (p.path != null && p.path!.isNotEmpty)
              ? p.path!
              : '${folder.isEmpty ? '' : '$folder/'}${p.name}';
          if (!rel.toLowerCase().endsWith('.milk')) rel = '$rel.milk';
          // Server paths are data, not instructions: never let one climb out.
          if (rel.split('/').any((s) => s == '..' || s.isEmpty)) continue;
          final dest = File('$root/$rel');
          await dest.parent.create(recursive: true);
          final tmp = File('${dest.path}.part');
          await _downloadToFile(url, tmp, sha256Hex: p.sha256);
          await tmp.rename(dest.path);
          if (p.presetId != null) {
            idMap['packs/${pack.slug}/$rel'] = p.presetId!;
          }
          done++;
          if (total > 0) _setProgress(progressKey, done / total);
        }
      }
    }

    await walk('');
    if (idMap.isNotEmpty) await LocalDb.instance.cachePmPresetIds(idMap);
    if (done == 0) {
      throw Exception('granular install: no preset downloaded for ${pack.slug}');
    }
  }

  /// A preset tried from the Popular/Browse tabs was downloaded on its own; the
  /// pack now holds the same file. Delete the single copy and repoint whatever
  /// referenced it (playlist entries, the id cache) at the pack's — otherwise
  /// the preset sits on disk twice and plays twice in the "all" source.
  Future<void> _absorbSinglesIntoPack(String slug) async {
    final root = Directory('$singleDir/$slug');
    if (!root.existsSync()) return;
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is! File || !e.path.toLowerCase().endsWith('.milk')) continue;
      final sub = e.path.substring(root.path.length + 1);
      final inPack = File('${packDir(slug)}/$sub');
      if (!inPack.existsSync()) continue; // the pack does not ship it
      final oldRel = relOf(e.path);
      await LocalDb.instance.repathPmPreset(oldRel, relOf(inPack.path));
      try { await e.delete(); } catch (_) {}
    }
    try {
      if (root.listSync(recursive: true).whereType<File>().isEmpty) {
        await root.delete(recursive: true);
      }
    } catch (_) {}
  }


  // ── Texture bundles: who uses them ─────────────────────────────────────────
  //
  // A bundle is keyed by the sha1 of its URL, so two packs published against
  // the same images share one directory — which is why uninstalling a pack
  // could not simply delete it. It now keeps the list of packs that pulled it
  // (`.users`), and the uninstall drops the bundle once that list is empty.
  //
  // Singles matter too: uninstalling a pack RESCUES the presets a playlist
  // points at into single/<slug>/, and those still need the images. So the slug
  // only leaves the list when no single of that pack remains.

  File _texUsersFile(String key) => File('$_pmDir/packtex/$key/.users');

  Set<String> _texUsers(String key) {
    final f = _texUsersFile(key);
    if (!f.existsSync()) return <String>{};
    try {
      return f
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _addTexUser(String key, String slug) async {
    _invalidateOrphanTexCache();
    final users = _texUsers(key)..add(slug);
    try {
      await _texUsersFile(key).writeAsString('${users.join('\n')}\n', flush: true);
    } catch (_) {/* a bundle we cannot annotate is merely not reference-counted */}
  }

  bool _hasSinglesOf(String slug) {
    final d = Directory('$singleDir/$slug');
    if (!d.existsSync()) return false;
    return d
        .listSync(recursive: true)
        .whereType<File>()
        .any((f) => f.path.toLowerCase().endsWith('.milk'));
  }

  int _dirBytes(Directory d) {
    var total = 0;
    try {
      for (final e in d.listSync(recursive: true).whereType<File>()) {
        try {
          total += e.lengthSync();
        } catch (_) {}
      }
    } catch (_) {}
    return total;
  }

  /// Texture bundles nothing points at any more, as (directory key, bytes).
  ///
  /// A bundle counts as USED when its `.users` list is non-empty or when an
  /// installed pack's stamp names it. Bundles installed before the reference
  /// counting have neither, so they show up here — which is the point: they are
  /// the ones that leaked, and they cannot be attributed without asking the
  /// server. Hence an explicit user action rather than a silent purge: a single
  /// rescued from a since-uninstalled pack may still need one of them.
  /// Memoised: the answer needs a recursive walk of every bundle (1177 files in
  /// one of them, measured) and the tile that shows it rebuilds on every
  /// notifyListeners. Invalidated wherever a bundle appears or disappears.
  List<(String, int)>? _orphanTexCache;

  void _invalidateOrphanTexCache() => _orphanTexCache = null;

  List<(String, int)> orphanTextureBundles() {
    final cached = _orphanTexCache;
    if (cached != null) return cached;
    final root = Directory('$_pmDir/packtex');
    if (!root.existsSync()) return _orphanTexCache = const [];

    final claimed = <String>{};
    for (final (slug, _) in installedPacks()) {
      final st = _installedStamp(slug);
      final key = st?['textures_key'] as String?;
      if (key != null && key.isNotEmpty) claimed.add(key);
    }

    final out = <(String, int)>[];
    for (final d in root.listSync().whereType<Directory>()) {
      final key = d.path.split(Platform.pathSeparator).last;
      if (claimed.contains(key)) continue;
      if (_texUsers(key).isNotEmpty) continue;
      out.add((key, _dirBytes(d)));
    }
    return _orphanTexCache = out;
  }

  /// Deletes every bundle [orphanTextureBundles] lists. Returns bytes freed.
  Future<int> purgeOrphanTextures() async {
    var freed = 0;
    final bundles = orphanTextureBundles();
    _invalidateOrphanTexCache();
    for (final (key, bytes) in bundles) {
      final d = Directory('$_pmDir/packtex/$key');
      try {
        if (d.existsSync()) await d.delete(recursive: true);
        freed += bytes;
      } catch (_) {/* keep going: one locked bundle must not block the rest */}
    }
    if (freed > 0) {
      await _pushTextureDirs();
      notifyListeners();
    }
    return freed;
  }

  Future<void> uninstallPack(PresetPack pack) async {
    // Rescue what a playlist still points at: uninstalling a pack must not
    // silently empty a playlist built from it. Only those files are kept —
    // copied back into single/, where a one-off download would have put them.
    final prefix = 'packs/${pack.slug}/';
    for (final rel in await LocalDb.instance.pmPlaylistPathsUnder(prefix)) {
      final src = File(absOf(rel));
      if (!src.existsSync()) continue;
      final newRel = 'single/${pack.slug}/${rel.substring(prefix.length)}';
      final dst = File(absOf(newRel));
      try {
        await dst.parent.create(recursive: true);
        await src.copy(dst.path);
        await LocalDb.instance.repathPmPreset(rel, newRel);
      } catch (_) {/* keep going: one unreadable file must not block it */}
    }
    _invalidateSingleCache();
    // Read the bundle key BEFORE the pack directory (and its stamp) goes.
    final texKey = _installedStamp(pack.slug)?['textures_key'] as String? ??
        ((pack.texturesUrl == null || pack.texturesUrl!.isEmpty)
            ? null
            : _urlKey(pack.texturesUrl!));

    final dir = Directory(packDir(pack.slug));
    if (dir.existsSync()) await dir.delete(recursive: true);

    // Release the texture bundle. It used to be kept unconditionally ("another
    // pack may share it, and it is small") — sharing needs the SAME url, which
    // is rare, and small it is not: six orphan bundles totalling 176 MB were
    // measured on a device with no pack left installed. It goes as soon as no
    // other pack claims it AND no single rescued from this one remains.
    if (texKey != null) {
      final users = _texUsers(texKey)..remove(pack.slug);
      final keep = users.isNotEmpty || _hasSinglesOf(pack.slug);
      final bundle = Directory('$_pmDir/packtex/$texKey');
      if (keep) {
        try {
          await _texUsersFile(texKey)
              .writeAsString(users.isEmpty ? '' : '${users.join('\n')}\n', flush: true);
        } catch (_) {}
      } else if (bundle.existsSync()) {
        try {
          await bundle.delete(recursive: true);
          _invalidateOrphanTexCache();
          await _pushTextureDirs();
        } catch (_) {}
      }
    }
    final src = UserSettings.instance.pmSource;
    if (src == 'pack:${pack.slug}' || src.startsWith('packdir:${pack.slug}/')) {
      await applySource('bundled');
    } else {
      await _reapplyIfCovers('pack:${pack.slug}');
    }
    notifyListeners();
  }

  /// Re-push the active source when [changed] contributes to it.
  Future<void> _reapplyIfCovers(String changed) async {
    final src = UserSettings.instance.pmSource;
    final covers = src == 'all' ||
        src == changed ||
        (changed.startsWith('pack:') &&
            src.startsWith('packdir:${changed.substring(5)}/')) ||
        (changed == 'user' && src == 'user');
    if (covers) await applySource(src, persist: false);
  }

  // ── Single-preset download ─────────────────────────────────────────────────

  /// Where a single download of [p] lives: `single/<pack>/<server path>`.
  ///
  /// The file NAME is the preset's real name and the tree keeps the pack and
  /// its sub-folders — the engine derives the displayed preset name from the
  /// basename, so the first design (`single/<uuid>.milk`, id-as-filename) put
  /// a raw uuid on screen and lost which pack the preset came from.
  String singlePathFor(PresetInfo p) {
    final pack = (p.pack == null || p.pack!.isEmpty) ? '_' : _sanitize(p.pack!);
    var rel = (p.path != null && p.path!.isNotEmpty) ? p.path! : p.name;
    if (!rel.toLowerCase().endsWith('.milk')) rel = '$rel.milk';
    // Server paths are data, not instructions: sanitize each segment and drop
    // anything that would climb out of the tree.
    final segs = [
      for (final s in rel.split('/'))
        if (s.isNotEmpty && s != '.' && s != '..') _sanitize(s),
    ];
    if (segs.isEmpty) return '$singleDir/$pack/${_sanitize(p.name)}.milk';
    return '$singleDir/$pack/${segs.join('/')}';
  }

  /// Absolute paths of every one-off download, cached in memory.
  ///
  /// The preset lists ask "is this one already here?" for EVERY visible row,
  /// on every frame. One `stat` per row per frame is invisible on a Mac and is
  /// jank on a phone, so the answer comes from a set built once and invalidated
  /// whenever something writes under single/.
  Set<String>? _singleCache;

  bool isSingleDownloaded(String absPath) {
    final cache = _singleCache ??= () {
      final d = Directory(singleDir);
      if (!d.existsSync()) return <String>{};
      return {
        for (final e in d.listSync(recursive: true, followLinks: false))
          if (e is File && e.path.toLowerCase().endsWith('.milk')) e.path,
      };
    }();
    return cache.contains(absPath);
  }

  void _invalidateSingleCache() => _singleCache = null;

  /// A downloaded copy of [presetId], if any — the current layout via the
  /// path→id cache, plus the legacy `single/<id>.milk` form.
  Future<String?> pathForPresetIdAsync(String presetId) async {
    final legacy = File('$singleDir/$presetId.milk');
    if (legacy.existsSync()) return legacy.path;
    final rel = await LocalDb.instance.pmPathForPresetId(presetId);
    if (rel == null) return null;
    final f = File(absOf(rel));
    return f.existsSync() ? f.path : null;
  }

  /// Where the INSTALLED pack would hold this preset — `single/<pack>/<path>`
  /// mirrors the pack layout on purpose, so the two forms map onto each other
  /// by a prefix swap (see [_absorbSinglesIntoPack]).
  String? packPathFor(PresetInfo p) {
    if (p.pack == null || p.pack!.isEmpty) return null;
    final single = singlePathFor(p);
    final prefix = '$singleDir/${_sanitize(p.pack!)}/';
    if (!single.startsWith(prefix)) return null;
    return '${packDir(_sanitize(p.pack!))}/${single.substring(prefix.length)}';
  }

  /// Downloads [p] under `single/<pack>/<path>` (sha256-verified) and caches
  /// the path→id mapping. Returns the absolute path, null when [p] carries no
  /// id/url. Never downloads what an installed pack already holds.
  Future<String?> ensurePresetDownloaded(PresetInfo p) async {
    final id = p.presetId;
    final url = p.downloadUrl;
    if (id == null || url == null || url.isEmpty) return null;
    // The pack copy wins: downloading a second copy under single/ would leave
    // the same preset on disk twice (and twice in the "all" source).
    final inPack = packPathFor(p);
    if (inPack != null && File(inPack).existsSync()) {
      await LocalDb.instance.cachePmPresetIds({relOf(inPack): id});
      return inPack;
    }
    final existing = await pathForPresetIdAsync(id);
    if (existing != null) return existing;
    final dest = File(singlePathFor(p));
    if (dest.existsSync()) return dest.path;
    await dest.parent.create(recursive: true);
    final tmp = File('${dest.path}.part');
    // download_url is already percent-encoded by the server — never re-encode.
    await _downloadToFile(url, tmp, sha256Hex: p.sha256);
    await tmp.rename(dest.path);
    await LocalDb.instance.cachePmPresetIds({relOf(dest.path): id});
    _invalidateSingleCache();
    notifyListeners();
    return dest.path;
  }

  // ── Pack display names ────────────────────────────────────────────────────
  //
  // A single download names the pack the preset BELONGS to — a pack the user
  // may not have installed, so `.packname` on disk cannot answer. The catalogue
  // does, so every listing that fetches it feeds this cache, persisted next to
  // the presets and read back offline.

  Map<String, String>? _packNames;

  String? packNameFor(String slug) {
    _packNames ??= _loadPackNames();
    return _packNames![slug];
  }

  Map<String, String> _loadPackNames() {
    try {
      final f = File('$_pmDir/packnames.json');
      if (f.existsSync()) {
        final j = jsonDecode(f.readAsStringSync());
        if (j is Map) {
          return {
            for (final e in j.entries) e.key.toString(): e.value.toString(),
          };
        }
      }
    } catch (_) {}
    return {};
  }

  /// Called by any screen that loaded the pack catalogue.
  Future<void> rememberPackNames(List<PresetPack> packs) async {
    if (packs.isEmpty) return;
    final map = {..._packNames ??= _loadPackNames()};
    for (final p in packs) {
      map[p.slug] = p.name;
    }
    if (map.length == _packNames!.length &&
        packs.every((p) => _packNames![p.slug] == p.name)) {
      return; // nothing new
    }
    _packNames = map;
    try {
      await File('$_pmDir/packnames.json')
          .writeAsString(jsonEncode(map), flush: true);
    } catch (_) {}
    notifyListeners();
  }

  // ── Curated server playlists → local mirror ────────────────────────────────

  /// Imports (or refreshes) a curated server playlist as a local pm_playlist:
  /// downloads missing presets into `single/`, rewrites the item list, returns
  /// the LOCAL playlist id (source `plist:<id>`). Progress key `srvlist:<id>`.
  Future<String> importServerPlaylist(PresetPlaylistInfo pl) async {
    final key = 'srvlist:${pl.id}';
    _setProgress(key, 0);
    try {
      final items = await RewampDb.getPresetPlaylistItems(pl.id);
      final local = <PmPlaylistItem>[];
      for (var i = 0; i < items.length; i++) {
        final p = items[i];
        final path = await ensurePresetDownloaded(p);
        if (path != null) {
          local.add(PmPlaylistItem(
            id: 0, // ignored on insert
            path: relOf(path),
            presetId: p.presetId,
            name: p.name,
            position: local.length,
          ));
        }
        _setProgress(key, (i + 1) / items.length);
      }
      final db = LocalDb.instance;
      var localId = await db.pmPlaylistIdForServer(pl.id);
      localId ??= await db.createPmPlaylist(pl.name, serverId: pl.id);
      await db.setPmPlaylistItems(localId, local);
      return localId;
    } finally {
      _setProgress(key, null);
    }
  }

  // ── Local imports (picker / drag'n'drop / archives) ────────────────────────

  static const _kTextureExts = {'.jpg', '.jpeg', '.png', '.tga', '.bmp', '.dds'};

  /// Copies .milk files into `user/`. Returns how many were imported.
  Future<int> importMilkFiles(Iterable<String> paths) async {
    var n = 0;
    for (final src in paths) {
      if (!src.toLowerCase().endsWith('.milk')) continue;
      final f = File(src);
      if (!f.existsSync()) continue;
      final name = _sanitize(f.uri.pathSegments.last);
      await Directory(userDir).create(recursive: true);
      await f.copy('$userDir/$name');
      n++;
    }
    if (n > 0) {
      await _reapplyIfCovers('user');
      notifyListeners();
    }
    return n;
  }

  /// Imports every .milk (and companion texture image) found under [dir] — an
  /// extracted archive or a dropped folder. Returns the preset count, 0 when
  /// none. Two passes: nothing is copied unless at least one .milk exists —
  /// otherwise an AUDIO folder's cover art would land in user/ as a "texture".
  Future<int> importFromDir(String dir) async {
    final d = Directory(dir);
    if (!d.existsSync()) return 0;
    final milks = <File>[];
    final textures = <File>[];
    await for (final e in d.list(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      if (e.uri.pathSegments.last.startsWith('.')) continue;
      final lower = e.path.toLowerCase();
      if (lower.endsWith('.milk')) {
        milks.add(e);
      } else if (_kTextureExts.any(lower.endsWith)) {
        textures.add(e);
      }
    }
    if (milks.isEmpty) return 0;
    await Directory(userDir).create(recursive: true);
    for (final e in milks) {
      await e.copy('$userDir/${_sanitize(e.uri.pathSegments.last)}');
    }
    for (final e in textures) {
      // Textures ride along: a .milk names its bitmaps bare, and user/ is on
      // the texture search path.
      await e.copy('$userDir/${_sanitize(e.uri.pathSegments.last)}');
    }
    await _pushTextureDirs();
    await _reapplyIfCovers('user');
    notifyListeners();
    return milks.length;
  }

  Future<void> deleteUserPreset(String absPath) async {
    if (!absPath.startsWith('$userDir/')) return;
    final f = File(absPath);
    if (f.existsSync()) await f.delete();
    await _reapplyIfCovers('user');
    notifyListeners();
  }

  /// Deletes several imports at once. Returns how many files actually went.
  ///
  /// One re-apply and one notification for the whole batch: going through
  /// [deleteUserPreset] per file would re-push the source list — and rescan the
  /// preset tree — once per preset, which on a selection of a few hundred is
  /// the difference between instant and a visible freeze.
  Future<int> deleteUserPresets(Iterable<String> absPaths) async {
    var removed = 0;
    for (final abs in absPaths) {
      if (!abs.startsWith('$userDir/')) continue;
      final f = File(abs);
      try {
        if (f.existsSync()) {
          await f.delete();
          removed++;
        }
      } catch (_) {/* keep going: one locked file must not abort the batch */}
    }
    if (removed > 0) {
      await _reapplyIfCovers('user');
      notifyListeners();
    }
    return removed;
  }

  String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');

  // ── Usage logging (log_preset_uses) ────────────────────────────────────────
  //
  // The preset changes every ~30 s: NEVER one POST per change. Ids accumulate
  // and leave in batches (≥20, or an explicit flush on app background). Only
  // presets with a server id are logged: singles carry it in their filename,
  // pack presets resolve their whole FOLDER in one browse_presets call
  // (cached in pm_preset_ids); bundled/user presets have none and are skipped.

  final List<String> _usePending = [];
  final Set<String> _useFoldersTried = {}; // per-session, avoids retry storms
  int _lastUseSerial = 0;
  Timer? _useFlushTimer;

  /// Feed from the UI's serial poll (ProjectMWidget ticks it already).
  void noteUsageTick(int serial, String absPath) {
    if (serial == _lastUseSerial || absPath.isEmpty) return;
    _lastUseSerial = serial;
    if (!_ready) return;
    final rel = relOf(absPath);
    if (rel.startsWith('single/')) {
      final base = rel.substring(7);
      if (base.toLowerCase().endsWith('.milk')) {
        _usePending.add(base.substring(0, base.length - 5));
        _maybeFlushUsage();
      }
    } else if (rel.startsWith('packs/')) {
      unawaited(_resolvePackUse(rel));
    }
    // bundled/user: no server identity — not logged.
  }

  Future<void> _resolvePackUse(String rel) async {
    try {
      final db = LocalDb.instance;
      final cached = await db.pmPresetIdsForPaths([rel]);
      var id = cached[rel];
      if (id == null) {
        // packs/<slug>/<folder…>/<file>
        final parts = rel.split('/');
        if (parts.length < 3) return;
        final slug = parts[1];
        final folder = parts.sublist(2, parts.length - 1).join('/');
        final fileBase = _stripMilk(parts.last).toLowerCase();
        final folderKey = '$slug/$folder';
        if (_useFoldersTried.contains(folderKey)) return;
        _useFoldersTried.add(folderKey);
        final page = await RewampDb.browsePresets(pack: slug, folder: folder);
        final mapping = <String, String>{};
        for (final p in page.presets) {
          final pid = p.presetId;
          if (pid == null) continue;
          final base = _stripMilk(
              (p.path ?? p.name).split('/').last);
          final relPath = folder.isEmpty
              ? 'packs/$slug/$base.milk'
              : 'packs/$slug/$folder/$base.milk';
          mapping[relPath] = pid;
          if (base.toLowerCase() == fileBase) id = pid;
        }
        if (mapping.isNotEmpty) await db.cachePmPresetIds(mapping);
      }
      if (id != null) {
        _usePending.add(id);
        _maybeFlushUsage();
      }
    } catch (_) {/* offline — the play is simply not counted */}
  }

  String _stripMilk(String s) =>
      s.toLowerCase().endsWith('.milk') ? s.substring(0, s.length - 5) : s;

  void _maybeFlushUsage() {
    if (_usePending.length >= 20) {
      unawaited(flushUsage());
      return;
    }
    // Time-based backstop. Batching on "20 ids or the app backgrounds" never
    // shipped anything on a desktop that stays open for hours — a preset
    // changes every ~30 s, so 20 takes 10 minutes and macOS rarely reports
    // paused/hidden. One POST every 90 s of actual watching is nothing.
    _useFlushTimer ??= Timer(const Duration(seconds: 90), () {
      _useFlushTimer = null;
      unawaited(flushUsage());
    });
  }

  /// Push the accumulated ids (cap 500/batch server-side). Called on app
  /// background and opportunistically; failures put the batch back.
  Future<void> flushUsage() async {
    _useFlushTimer?.cancel();
    _useFlushTimer = null;
    if (_usePending.isEmpty) return;
    final batch = List<String>.from(_usePending);
    _usePending.clear();
    try {
      await RewampDb.logPresetUses(batch);
    } catch (_) {
      _usePending.insertAll(0, batch);
    }
  }

  // ── Plumbing ───────────────────────────────────────────────────────────────

  void _setProgress(String key, double? v) {
    final map = Map<String, double>.from(progress.value);
    if (v == null) {
      map.remove(key);
    } else {
      map[key] = v.clamp(0.0, 1.0);
    }
    progress.value = map;
  }

  /// Streamed download to [dest] (packs can be tens of MB — no RAM copy),
  /// optional sha256 verification, per-chunk stall timeout.
  Future<void> _downloadToFile(String url, File dest,
      {int? expectedSize, String? sha256Hex, String? progressKey}) async {
    // Same cancellation contract as RewampDb's fetch: the token comes from the
    // zone the queue job runs in, poll per chunk + force-close on a stall.
    final cancel = DownloadCancelToken.current;
    cancel?.throwIfCancelled(url);
    final client = http.Client();
    void closeClient() => client.close();
    cancel?.register(closeClient);
    IOSink? sink;
    try {
      final resp = await client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode} on $url');
      }
      final total = (resp.contentLength ?? expectedSize ?? 0);
      sink = dest.openWrite();
      final digestSink = sha256Hex == null ? null : _DigestSink();
      final conv =
          digestSink == null ? null : sha256.startChunkedConversion(digestSink);
      var got = 0;
      await for (final chunk
          in resp.stream.timeout(const Duration(seconds: 30))) {
        if (cancel?.isCancelled ?? false) throw DownloadCancelledException(url);
        sink.add(chunk);
        conv?.add(chunk);
        got += chunk.length;
        if (progressKey != null && total > 0) {
          _setProgress(progressKey, got / total);
        }
      }
      await sink.close();
      sink = null;
      conv?.close();
      if (digestSink != null &&
          digestSink.digest.toString().toLowerCase() !=
              sha256Hex!.toLowerCase()) {
        await dest.delete();
        throw Exception('sha256 mismatch on $url');
      }
    } catch (e) {
      try {
        await sink?.close();
        if (dest.existsSync()) await dest.delete();
      } catch (_) {}
      if ((cancel?.isCancelled ?? false) && e is! DownloadCancelledException) {
        throw DownloadCancelledException(url);
      }
      rethrow;
    } finally {
      cancel?.unregister(closeClient);
      client.close();
    }
  }

  /// libarchive via FFI, off the UI thread (same pattern as RewampDb's
  /// _extractArchiveOffThread: the isolate re-binds its own FFI).
  Future<void> _extract(String archivePath, String destDir) async {
    final (rc, err) = await Isolate.run(() {
      final a = RewampAudio();
      final rc = a.extractArchive(archivePath, destDir);
      return (rc, rc == 0 ? '' : a.extractLastError());
    }).timeout(const Duration(seconds: 300));
    if (rc != 0) {
      throw Exception('extract failed (rc=$rc): $err');
    }
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest digest;
  @override
  void add(Digest data) => digest = data;
  @override
  void close() {}
}
