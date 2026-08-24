import 'dart:io';

import 'package:flutter/services.dart';
import 'package:rewamp_audio/rewamp_audio.dart' show SubsongInfo;

import 'formats.dart';
import 'local_db.dart' show LocalDb, TrackRecord;
import 'player_controller.dart';
import 'preset_manager.dart';
import 'rewamp_db.dart';
import 'uade_info.dart';

/// Turning a local PATH into the tracks it stands for — the part of "open a
/// file" that has nothing to do with WHERE the path came from.
///
/// This used to live inside HomeScreen._pickFile, welded to a BuildContext and
/// to that widget's callbacks, and each branch played its result and returned.
/// That is fine for a picker, which hands over exactly one path, and useless
/// for anything else: a drag-and-drop delivers SEVERAL paths at once and has to
/// accumulate them into one queue operation, and a drop on the Dock icon
/// arrives at the app level where HomeScreen may not even be built yet.
///
/// So the routing is here, context-free and UI-free. Callers decide what to do
/// with the tracks (play, append, replace) and how to surface [LocalOpenNotice].

/// Extensions whose files can hold SEVERAL subsongs, so a single path expands
/// into a whole queue — the set the native probe is allowed to interrogate.
const kMultiTrackExts = {
  'nsf', 'nsfe',      // NES
  'gbs',              // Game Boy
  'sid', 'psid', 'rsid',
  'sap',              // Atari 8-bit
  'kss', 'mgs', 'bgm', 'mpk', 'mbm', 'opx', 'mus',
  'hes', 'sgc',
  'ay', 'vtx', 'pt3', 'stc', 'chp',
  'gym', 's98', 'vgm', 'vgz', 'dro', 'dr0',
  'wsr',              // WonderSwan
  'sndh',             // Atari ST — SNDH archives commonly bundle up to 128 subsongs.
  // OpenMPT tracker modules can hold several subsongs (order-list sequences,
  // e.g. some S3M/IT compilations). probeSubsongCount tries to open ANY file
  // via libopenmpt regardless of extension and returns 0/1 for a plain single-
  // song module, so gating on these extensions is safe and just extends the
  // existing count>1 check to trackers.
  ...kTrackerExts,
};

/// Something the caller may want to tell the user about. Kept as an enum rather
/// than a string so this file needs no l10n and no BuildContext.
enum LocalOpenNotice {
  extractingArchive,
  archiveEmpty,
  playlistUnreadable,
  /// Milkdrop presets landed in the projectM library instead of the queue
  /// (a dropped .milk, or an archive holding presets and no audio).
  presetsImported,
  /// Ouverture en LOT dont TOUT a été filtré (pochettes, banques
  /// d'échantillons, bibliothèques PSF). Sans ce mot, un « tout sélectionner »
  /// sur un dossier sans musique ne ferait rien du tout, en silence.
  nothingPlayable,
}

/// Hands local paths to the running app — set by AppShell, called by whatever
/// delivers files from outside the UI (a drop on the window, a drop on the Dock
/// icon, "Open With" in the Finder).
///
/// A global rather than a callback threaded down, for the same reason
/// globalOnQueueAdd is one: the caller is not a widget and has no route to the
/// shell. Null until the shell is built, which is exactly the cold-start case
/// the native side has to buffer for.
Future<void> Function(List<String> paths)? globalOpenLocalPaths;

// ── Files macOS hands the app from outside the UI ────────────────────────────

const _openFilesChannel = MethodChannel('rewamp/open_files');

/// Paths collected from the native buffer before [globalOpenLocalPaths] was
/// set. `takePending` CLEARS the native side, so anything we fetch is ours to
/// keep or to lose — dropping it because the shell was one frame late would
/// silently swallow the files that started the app.
final List<String> _awaitingShell = [];

/// Starts listening for files opened through the Dock, the Finder, or a
/// double-click. Call once, after [globalOpenLocalPaths] is set.
///
/// macOS only for now: it is the one desktop that builds, and the mechanism is
/// per-platform (Linux has no equivalent of application(_:open:); Windows
/// passes paths as argv). The rest of the pipeline is platform-agnostic, so
/// they plug in here when their runners exist.
void listenForOpenedFiles() {
  if (!Platform.isMacOS) return;
  _openFilesChannel.setMethodCallHandler((call) async {
    if (call.method == 'filesAvailable') await drainOpenedFiles();
  });
  // A cold start opened BY a file: the native buffer is already full and no
  // nudge is coming that we have not already missed, so ask straight away.
  drainOpenedFiles();
}

/// Pulls whatever the native side has buffered and hands it to the shell.
Future<void> drainOpenedFiles() async {
  if (!Platform.isMacOS) return;
  try {
    final fetched = await _openFilesChannel.invokeListMethod<String>('takePending');
    if (fetched != null) _awaitingShell.addAll(fetched);
  } catch (_) {/* channel not up yet — the next nudge retries */}
  final open = globalOpenLocalPaths;
  if (open == null || _awaitingShell.isEmpty) return;
  final batch = List<String>.from(_awaitingShell);
  _awaitingShell.clear();
  await open(batch);
}

typedef LocalOpenReporter = void Function(LocalOpenNotice notice);

/// Extensions qui n'existent QUE pour être chargées par un autre fichier: la
/// moitié « bibliothèque » d'un jeu PSF, dont le `.mini*sf` porte la musique.
///
/// ⚠️ Elles sont dans `kExtractedAudioExts` **à raison** — une archive DOIT les
/// extraire, sinon le `.minigsf` qui les référence ne joue pas. « Faut-il
/// extraire ce fichier ? » et « faut-il le METTRE EN FILE ? » sont deux
/// questions différentes, et c'est la seconde que ce jeu tranche.
const kCompanionOnlyExts = <String>{
  'psflib', 'psf2lib', 'gsflib', '2sflib', 'ncsflib',
  'usflib', 'ssflib', 'dsflib', 'snsflib', 'qsflib',
};

/// Ce fichier mérite-t-il d'entrer dans une file quand on en ouvre PLUSIEURS
/// d'un coup (« tout sélectionner » dans un dossier, dépôt d'un lot, dossier).
///
/// Volontairement PAS appliqué à un choix unique et délibéré: si l'utilisateur
/// désigne un seul fichier, on essaie de le jouer même d'extension inconnue —
/// c'est `rewamp_can_play` qui tranche au chargement. Le filtre sert à ne pas
/// noyer la file sous des pochettes et des banques d'échantillons, pas à
/// interdire.
/// [canPlay] est la SECONDE CHANCE, confiée au moteur, pour ce que la liste
/// d'extensions ne peut pas trancher — et elle est nécessaire, pas cosmétique:
/// certains formats sont reconnus par leur CONTENU et volontairement absents
/// de toute liste d'extensions parce que celle-ci est trop générique. Le `.raw`
/// en est le cas d'école: `monkey island 2 - intro.raw` commence par
/// `RAWADATA` et AdPlug le joue, mais `raw` désigne aussi du PCM sans en-tête,
/// donc ni le probe natif ni `kExtractedAudioExts` ne l'inscrivent — c'est
/// l'en-tête qui décide (`adplug_magic_score`, score 100). Filtrer sur la
/// seule liste écartait donc un fichier parfaitement jouable.
///
/// Passer `rewamp_can_play` (registre complet: extension + en-tête, sans
/// décoder). Les règles NÉGATIVES ci-dessus restent absolues: une bibliothèque
/// PSF est un conteneur valide que le registre accepterait, alors qu'elle n'a
/// pas de musique à elle.
bool isBulkQueueCandidate(String path, {bool Function(String)? canPlay}) {
  final b = path.split(Platform.pathSeparator).last;
  if (b.startsWith('.')) return false;
  final ext = b.contains('.') ? b.split('.').last.toLowerCase() : '';
  // Forme PRÉFIXE des modules Amiga: `mdat.NAME`, `smpl.NAME`… — le format est
  // avant le point, donc le suffixe ne dit rien.
  final pre = b.contains('.') ? b.split('.').first.toLowerCase() : '';
  if (kCompanionOnlyExts.contains(ext)) return false;
  if (RewampDb.kExtractedAudioExts.contains(ext) ||
      RewampDb.kExtractedAudioExts.contains(pre) ||
      RewampDb.kLocalArchiveExts.contains(ext)) {
    return true;
  }
  return canPlay?.call(path) ?? false;
}

/// Les sous-chansons qu'un M3U posé À CÔTÉ de [path] déclare POUR CE FICHIER,
/// ou null quand il n'y en a pas.
///
/// C'est le M3U qui fait autorité, pas la sonde native, et la différence n'est
/// pas cosmétique: le `.gbs` de « Gargoyle's Quest » a ses morceaux aux index
/// 0, 2, 3, 12 et 16 — la sonde en annonce des dizaines, dont les cases mortes
/// entre les deux, toutes nommées « DMG-RAJ (n) ». Le M3U, lui, donne les cinq
/// vrais, leurs titres et leurs durées. Un rip joshw/GBgbs est TOUJOURS livré
/// avec le sien, dans l'archive comme à côté du fichier.
///
/// Rapproché par BASENAME: le chemin qu'écrit le parseur passe par `_sanitize`
/// et ne vaut pas caractère pour caractère celui du fichier sur disque.
Future<List<TrackRecord>?> m3uSubsongsFor(
  String path, {
  String? album,
  String? artist,
}) async {
  List<SubsongInfo>? subs;
  try {
    subs = await RewampDb.probeLocalM3u(path);
  } catch (_) {
    return null;
  }
  if (subs == null || subs.isEmpty) return null;
  final name = path.split(Platform.pathSeparator).last;
  final want = name.toLowerCase();
  final mine = [
    for (final s in subs)
      if (s.filePath.split(Platform.pathSeparator).last.toLowerCase() == want) s
  ];
  if (mine.isEmpty) return null;
  final ext  = name.split('.').last.toLowerCase();
  final base = name.replaceAll(RegExp(r'\.\w+$'), '');
  return [
    for (var i = 0; i < mine.length; i++)
      TrackRecord(
        id:         '',
        // Le chemin RÉEL, jamais celui reconstruit par le parseur.
        filePath:   path,
        entryPath:  '',
        subsongIdx: mine[i].subsongIdx,
        title:      mine[i].title ?? '$base (${i + 1})',
        metaAlbum:  album,
        artist:     artist,
        durationS:  (mine[i].durationMs ?? 0) > 0
            ? mine[i].durationMs! / 1000.0
            : null,
        formatExt:  ext,
        source:     'local',
        isFavorite: false,
        inLibrary:  false,
        playCount:  0,
      ),
  ];
}

/// Les sous-chansons telles que le FICHIER les déclare: titres et durées lus
/// par le moteur, pas fabriqués.
///
/// Un `.nsfe` porte ses noms de piste (chunk `tlbl`) et ses durées (`time`);
/// un `.gbs`, un `.spc`, un `.kss` en portent aussi selon le rip. Le probe
/// natif les remonte déjà (`rewamp_probe_get_title`/`_duration_ms`), mais
/// l'ouverture locale ne s'en servait pas: elle ne prenait que le COMPTE et
/// fabriquait « NOM (1) », « NOM (2) »… — les vrais titres étaient là, à un
/// appel de distance, et personne ne les lisait.
///
/// Rend null quand il n'y a rien à apporter (une seule sous-chanson, ou aucun
/// titre non vide): l'appelant garde alors ses noms numérotés, qui valent
/// mieux qu'une liste de chaînes vides.
///
/// [known] = les lignes DÉJÀ en base pour ce fichier, par index de
/// sous-chanson. Elles portent l'artwork, les compteurs de lecture et le ♥;
/// on ne remplace que ce que le fichier dit mieux.
List<TrackRecord>? engineSubsongsFor(
  String path,
  PlayerController controller, {
  String? album,
  Map<int, TrackRecord> known = const {},
}) {
  final List<SubsongInfo> subs;
  try {
    subs = controller.audio.probeSubsongs(path);
  } catch (_) {
    return null;
  }
  return subsongRecordsFrom(subs, path, album: album, known: known);
}

/// La moitié PURE de [engineSubsongsFor] — celle qui décide — séparée du
/// moteur pour être testable: l'hôte de test Dart n'a pas le natif.
List<TrackRecord>? subsongRecordsFrom(
  List<SubsongInfo> subs,
  String path, {
  String? album,
  Map<int, TrackRecord> known = const {},
}) {
  if (subs.length < 2) return null;
  if (!subs.any((s) => (s.title ?? '').trim().isNotEmpty)) return null;

  final name = path.split(Platform.pathSeparator).last;
  final ext  = name.split('.').last.toLowerCase();
  final base = name.replaceAll(RegExp(r'\.\w+$'), '');
  return [
    for (var i = 0; i < subs.length; i++)
      () {
        final s     = subs[i];
        final title = (s.title ?? '').trim();
        final secs  = (s.durationMs ?? 0) > 0 ? s.durationMs! / 1000.0 : null;
        final row   = known[s.subsongIdx];
        // Une ligne déjà connue garde TOUT ce qu'elle sait (♥, écoutes,
        // pochette) et ne reçoit que ce que le fichier énonce mieux.
        if (row != null) {
          return row.copyWith(
            title:     title.isEmpty ? null : title,
            durationS: secs,
          );
        }
        return TrackRecord(
          id:         '',
          filePath:   path,
          entryPath:  '',
          subsongIdx: s.subsongIdx,
          // Un titre vide au milieu d'une liste qui en a: on numérote celui-là
          // seul, plutôt que de laisser une ligne sans nom.
          title:      title.isEmpty ? '$base (${i + 1})' : title,
          metaAlbum:  album,
          durationS:  secs,
          formatExt:  ext,
          source:     'local',
          isFavorite: false,
          inLibrary:  false,
          playCount:  0,
        );
      }(),
  ];
}

/// Every playable track [path] stands for, in play order.
///
/// Empty means "nothing playable here" — the caller decides whether that is
/// worth a message. A plain single-subsong file returns exactly one record.
Future<List<TrackRecord>> tracksForLocalPath(
  String path, {
  required PlayerController controller,
  LocalOpenReporter? report,
}) async {
  final name = path.split(Platform.pathSeparator).last;
  final ext  = name.split('.').last.toLowerCase();
  final base = name.replaceAll(RegExp(r'\.\w+$'), '');

  // Dropped FOLDER: presets first (a folder of .milk must never end up queued
  // as bogus audio), then every playable file inside, recursively — each one
  // back through this router so archives/containers inside the folder expand
  // exactly like a direct drop.
  if (FileSystemEntity.isDirectorySync(path)) {
    final n = await PresetManager.instance.importFromDir(path);
    if (n > 0) report?.call(LocalOpenNotice.presetsImported);
    final files = <String>[];
    try {
      await for (final e
          in Directory(path).list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        // Même règle que « tout sélectionner » dans un dossier: un dossier est
        // plein de pochettes, de notes et de banques d'échantillons qu'une file
        // doit sauter (voir isBulkQueueCandidate).
        if (isBulkQueueCandidate(e.path, canPlay: controller.audio.canPlay)) {
          files.add(e.path);
        }
      }
    } catch (_) {}
    files.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final out = <TrackRecord>[];
    for (final f in files) {
      out.addAll(
          await tracksForLocalPath(f, controller: controller, report: report));
    }
    return out;
  }

  // Milkdrop preset: not audio — it goes to the projectM library (user/ dir),
  // never to the queue.
  if (ext == 'milk') {
    final n = await PresetManager.instance.importMilkFiles([path]);
    if (n > 0) report?.call(LocalOpenNotice.presetsImported);
    return const [];
  }

  // Local archive (UnExotica .lha, or any container): extract to cache and
  // enqueue every playable module inside. A locally-opened archive carries no
  // server aux_files, so any multifile companions (TFMX smpl.*, …) must live
  // inside the archive — and do, since the C extractor unpacks every entry;
  // UADE then resolves them as siblings.
  if (RewampDb.kLocalArchiveExts.contains(ext)) {
    report?.call(LocalOpenNotice.extractingArchive);
    final fileRecs = await RewampDb.extractLocalArchiveToTracks(path);
    if (fileRecs.isEmpty) {
      // Content detection: an archive with no playable audio can still be a
      // PRESET pack (zip of .milk + textures). The extraction already
      // happened into the cache dir — inspect it, no second extraction.
      try {
        final dir = await RewampDb.localArchiveCacheDir(path);
        final n = await PresetManager.instance.importFromDir(dir);
        if (n > 0) {
          report?.call(LocalOpenNotice.presetsImported);
          return const [];
        }
      } catch (_) {}
      report?.call(LocalOpenNotice.archiveEmpty);
      return const [];
    }
    // Expand each module into its subsongs so the queue plays EVERY subsong,
    // not just the first of each multi-subsong module (TFMX/NSF/…).
    return expandLocalModules(fileRecs, controller);
  }

  // Playlist file: expand the M3U/M3U8 and queue everything it references
  // (files resolved as siblings in the M3U's own directory; per-entry subsong
  // indices + titles/durations honoured). See RewampDb.parseM3uToSubsongs.
  if (ext == 'm3u' || ext == 'm3u8') {
    try {
      final content = await RewampDb.readM3uText(File(path));
      final subs    = RewampDb.parseM3uToSubsongs(content, File(path).parent.path);
      if (subs.isNotEmpty) {
        return [
          for (final s in subs)
            TrackRecord(
              id:         '',
              filePath:   s.filePath,
              entryPath:  '',
              subsongIdx: s.subsongIdx,
              title:      s.title ?? '${s.index + 1}',
              metaAlbum:  base,
              durationS:  (s.durationMs ?? 0) > 0 ? s.durationMs! / 1000.0 : null,
              formatExt:  s.filePath.split('.').last.toLowerCase(),
              source:     'local',
              isFavorite: false,
              inLibrary:  false,
              playCount:  0,
            ),
        ];
      }
    } catch (_) {/* fall through to the notice below */}
    report?.call(LocalOpenNotice.playlistUnreadable);
    return const [];
  }

  // Multi-track container (NSF/GBS/SID/…): rebuild the full subsong queue.
  if (kMultiTrackExts.contains(ext)) {
    // Un M3U voisin bat la sonde native — voir m3uSubsongsFor.
    final fromM3u = await m3uSubsongsFor(path);
    if (fromM3u != null) return fromM3u;
    // Real subsong count from the native decoder (header).
    final count = controller.audio.probeSubsongCount(path);
    // Titles/artwork for subsongs already played (keyed by subsong index).
    final played = await LocalDb.instance.getTracksForFile(path);
    final byIdx  = {for (final t in played) t.subsongIdx: t};
    // Puis ce que le FICHIER déclare (NSFe `tlbl`/`time`, …), avant les noms
    // fabriqués plus bas.
    final fromEngine =
        engineSubsongsFor(path, controller, known: byIdx);
    if (fromEngine != null) return fromEngine;
    if (count > 1) {
      // Reuse DB rows when present so a single previously-played subsong never
      // collapses the queue to one entry.
      return List.generate(count, (i) => byIdx[i] ?? TrackRecord(
        id:         '',
        filePath:   path,
        entryPath:  '',
        subsongIdx: i,
        title:      '$base (${i + 1})',
        formatExt:  ext,
        source:     'local',
        isFavorite: false,
        inLibrary:  false,
        playCount:  0,
      ));
    }
    if (played.isNotEmpty) return played; // single-subsong, already known
  }

  // UADE multi-subsong (TFMX, some FC/…): subsong count/titles/durations come
  // from the audacious-uade songdb, not a native probe.
  if (UadeInfoService.isUadePath(path)) {
    final info = await UadeInfoService.instance.forPath(path);
    // playableSubsongs drops the songdb's NOSOUND slots (silent, length 0) —
    // same default as upstream's skip_broken_subsongs.
    final playable = info?.playableSubsongs ?? const [];
    if (info != null && info.subsongCount > 1 && playable.length > 1) {
      return [
        for (var i = 0; i < playable.length; i++)
          TrackRecord(
            id:         '',
            filePath:   path,
            entryPath:  '',
            subsongIdx: playable[i].idx,
            title:      '$base (${i + 1})',
            metaAlbum:  info.album,
            artist:     info.authors.isEmpty ? null : info.authors.join(', '),
            durationS:  (playable[i].lengthMs ?? 0) > 0
                ? playable[i].lengthMs! / 1000.0
                : null,
            formatExt:  ext,
            source:     'local',
            isFavorite: false,
            inLibrary:  false,
            playCount:  0,
          ),
      ];
    }
  }

  // Plain single-subsong file.
  return [
    TrackRecord(
      id:         '',
      filePath:   path,
      entryPath:  '',
      subsongIdx: 0,
      title:      base,
      formatExt:  ext,
      source:     'local',
      isFavorite: false,
      inLibrary:  false,
      playCount:  0,
    ),
  ];
}

/// [tracksForLocalPath] over several paths, concatenated in the given order.
///
/// Order is the caller's: a Finder multi-selection arrives in the order the
/// user picked, and a drop keeps it. Unreadable paths are skipped rather than
/// aborting the batch — dropping ten files and getting nothing because the
/// third is a .txt would be the wrong trade.
Future<List<TrackRecord>> tracksForLocalPaths(
  List<String> paths, {
  required PlayerController controller,
  LocalOpenReporter? report,
  bool? filterCandidates,
}) async {
  // Ouverture en LOT (tout sélectionner, dépôt multiple): écarter ce qui n'a
  // rien à faire dans une file. Un chemin UNIQUE passe tel quel — voir
  // isBulkQueueCandidate pour pourquoi le filtre ne s'applique pas là.
  //
  // [filterCandidates] force la décision: un DÉPÔT filtre toujours, même à un
  // seul fichier. Poser une pochette sur la fenêtre n'est pas « ouvre ce
  // fichier-ci », c'est un geste large qui attrape ce qui passe — alors qu'un
  // sélecteur, lui, DÉSIGNE. Sans ça, un `.jpg` déposé seul devenait une piste
  // et allait jusqu'à faire apparaître la feuille « Lire maintenant ».
  final filter = filterCandidates ?? paths.length > 1;
  final kept = filter
      ? paths
          .where((path) =>
              // Un DOSSIER n'est pas jugé ici: il est parcouru plus bas, et
              // c'est son CONTENU qui est filtré.
              FileSystemEntity.isDirectorySync(path) ||
              isBulkQueueCandidate(path, canPlay: controller.audio.canPlay))
          .toList()
      : paths;
  if (kept.isEmpty && paths.isNotEmpty) {
    report?.call(LocalOpenNotice.nothingPlayable);
    return const [];
  }
  final out = <TrackRecord>[];
  for (final p in kept) {
    try {
      out.addAll(await tracksForLocalPath(p, controller: controller, report: report));
    } catch (_) {/* skip this one, keep the batch */}
  }
  return out;
}

/// Expands each extracted archive module into its subsongs so a picked archive
/// plays EVERY subsong, not just the first of each multi-subsong module.
/// TFMX/FC/… resolve via the UADE songdb (md5 lookup); NSF/GBS/SID/… via the
/// native probe. Single-subsong modules stay one entry.
Future<List<TrackRecord>> expandLocalModules(
    List<TrackRecord> recs, PlayerController controller) async {
  // Warm the UADE songdb cache in one batch so the per-file forPath() calls
  // below hit the cache instead of N serial round-trips.
  await UadeInfoService.instance
      .prefetchPaths([for (final r in recs) r.filePath]);

  final out = <TrackRecord>[];
  for (final r in recs) {
    final path = r.filePath;
    final ext  = (r.formatExt ?? '').toLowerCase();
    final name = r.title ?? path.split(Platform.pathSeparator).last;
    // Song base name for the "<base> – N" subsong titles. Amiga prefix-form
    // ("mdat.Turrican_2") → the part AFTER the format token; suffix-form
    // ("song.tfmx") → the part before the extension.
    final base = name.toLowerCase().startsWith('$ext.')
        ? name.substring(ext.length + 1)
        : name.replaceAll(RegExp(r'\.\w+$'), '');

    // UADE multi-subsong (audacious-uade songdb).
    if (UadeInfoService.isUadePath(path)) {
      final info = await UadeInfoService.instance.forPath(path);
      // NOSOUND slots filtered out — see UadeInfo.playableSubsongs.
      final playable = info?.playableSubsongs ?? const [];
      if (info != null && info.subsongCount > 1 && playable.length > 1) {
        for (var i = 0; i < playable.length; i++) {
          out.add(TrackRecord(
            id: '', filePath: path, entryPath: '',
            subsongIdx: playable[i].idx,
            title: '$base (${i + 1})',
            metaAlbum: r.metaAlbum,
            artist: info.authors.isEmpty ? null : info.authors.join(', '),
            durationS: (playable[i].lengthMs ?? 0) > 0
                ? playable[i].lengthMs! / 1000.0
                : null,
            formatExt: ext, source: 'local',
            isFavorite: false, inLibrary: false, playCount: 0,
          ));
        }
        continue;
      }
      out.add(r);
      continue;
    }

    // Native multi-track container (NSF/GBS/SID/…).
    if (kMultiTrackExts.contains(ext)) {
      // Le M3U de l'archive: extrait à côté du module, il nomme les morceaux
      // et ne liste que les vrais. Il était simplement ignoré — un `.zip`
      // GBgbs jouait ses cases mortes sous des titres numérotés.
      final fromM3u = await m3uSubsongsFor(path, album: r.metaAlbum);
      if (fromM3u != null) {
        out.addAll(fromM3u);
        continue;
      }
      // Puis les titres que porte le fichier lui-même.
      final fromEngine =
          engineSubsongsFor(path, controller, album: r.metaAlbum);
      if (fromEngine != null) {
        out.addAll(fromEngine);
        continue;
      }
      final count = controller.audio.probeSubsongCount(path);
      if (count > 1) {
        for (var i = 0; i < count; i++) {
          out.add(TrackRecord(
            id: '', filePath: path, entryPath: '', subsongIdx: i,
            title: '$base (${i + 1})', metaAlbum: r.metaAlbum,
            formatExt: ext, source: 'local',
            isFavorite: false, inLibrary: false, playCount: 0,
          ));
        }
        continue;
      }
    }
    out.add(r);
  }
  return out;
}
