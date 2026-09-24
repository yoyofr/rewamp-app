import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_snack.dart';
import 'l10n.dart';
import 'artwork_image.dart';
import 'cancel_field.dart';
import 'local_db.dart';
import 'local_import.dart' show localImportsDir;
import 'local_open.dart' show globalOpenLocalPaths;
import 'opened_files.dart';
import 'player_controller.dart';
import 'rewamp_db.dart';
import 'sync_service.dart';
import 'scrolling_text.dart';
import 'shell_insets.dart';

/// Réglages → Stockage: ce que l'app garde sur disque, POSTE PAR POSTE, avec
/// la suppression en face.
///
/// La règle qui a fait naître cet écran: l'app copie des fichiers chez elle
/// (téléchargements, fichiers « ouverts avec », pochettes, SoundFonts) et
/// l'utilisateur doit pouvoir VOIR ce que ça pèse et le REPRENDRE — sinon
/// l'espace disque baisse sans qu'aucun geste dans l'app n'explique pourquoi.
/// La purge automatique du dossier `opened/` n'est qu'un filet; le contrôle,
/// c'est ici.
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _CategoryStat {
  final int files;
  final int bytes;
  const _CategoryStat(this.files, this.bytes);
}

class _OpenedEntry {
  final String path;
  final int bytes;
  final DateTime modified;
  final bool referenced;
  const _OpenedEntry(this.path, this.bytes, this.modified, this.referenced);
}

/// Les dossiers projectM qui appartiennent à l'UTILISATEUR (packs serveur,
/// imports, playlists locales) — voir preset_manager.dart.
const _kPresetUserDirs = ['packs', 'packtex', 'single', 'user'];

class _StorageScreenState extends State<StorageScreen> {
  _CategoryStat? _downloads;
  _CategoryStat? _localImports;
  _CategoryStat? _artwork;
  _CategoryStat? _soundfonts;
  _CategoryStat? _presets;
  List<_OpenedEntry>? _opened;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<_CategoryStat> _statDir(Directory d) async {
    var files = 0, bytes = 0;
    if (await d.exists()) {
      await for (final e in d.list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        files++;
        try {
          bytes += await e.length();
        } catch (_) {}
      }
    }
    return _CategoryStat(files, bytes);
  }

  Future<void> _load() async {
    final support = await getApplicationSupportDirectory();
    final cache = await getApplicationCacheDirectory();
    final docs = (await RewampDb.downloadsBaseDir()).path;

    // Chaque poste est mesuré sur le DISQUE, pas déduit d'une comptabilité: le
    // disque est la seule vérité que cet écran promet.
    //
    // ⚠️ SoundFonts et presets vivent sous `rewamp_data/` (le datadir que le
    // moteur natif reçoit), PAS à la racine du support — mesurer le mauvais
    // dossier affichait « 0 B » sous 42 Mo de SF2. Et pour projectM on ne
    // compte que les QUATRE dossiers de l'utilisateur (packs serveur, imports):
    // le reste de `rewamp_data/projectm` est de l'EMBARQUÉ recopié au
    // démarrage — le montrer inviterait à le purger, et il ne reviendrait
    // qu'au prochain bump de version d'assets, pas au prochain lancement.
    final downloads = await _statDir(Directory(p.join(docs, 'online')));
    final localImports = await _statDir(await localImportsDir());
    final artwork = await _statDir(Directory(p.join(cache.path, 'artwork')));
    final soundfonts = await _statDir(
        Directory(p.join(support.path, 'rewamp_data', 'soundfonts')));
    var presetFiles = 0, presetBytes = 0;
    for (final sub in _kPresetUserDirs) {
      final st = await _statDir(
          Directory(p.join(support.path, 'rewamp_data', 'projectm', sub)));
      presetFiles += st.files;
      presetBytes += st.bytes;
    }
    final presets = _CategoryStat(presetFiles, presetBytes);

    final openedDir = await OpenedFiles.dir();
    final referenced = await OpenedFiles.referencedPaths();
    final opened = <_OpenedEntry>[];
    if (await openedDir.exists()) {
      await for (final e in openedDir.list()) {
        if (e is! File) continue;
        try {
          final stat = await e.stat();
          opened.add(_OpenedEntry(
              e.path, stat.size, stat.modified, referenced.contains(e.path)));
        } catch (_) {}
      }
    }
    opened.sort((a, b) => b.modified.compareTo(a.modified));

    if (!mounted) return;
    setState(() {
      _downloads = downloads;
      _localImports = localImports;
      _artwork = artwork;
      _soundfonts = soundfonts;
      _presets = presets;
      _opened = opened;
    });
  }

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _deleteAllOpened() async {
    final l10n = context.l10n;
    final entries = _opened ?? const <_OpenedEntry>[];
    // « Tout supprimer » ÉPARGNE ce qu'une playlist / la bibliothèque tient
    // encore: le geste global nettoie, il ne casse pas ce que l'utilisateur a
    // construit. La ligne référencée se supprime UNE PAR UNE, sciemment.
    final victims = [for (final e in entries) if (!e.referenced) e];
    if (victims.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.storageOpenedDeleteAllTitle),
        content: Text(l10n.storageOpenedDeleteAllBody(victims.length)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.commonDelete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    // Même patron que la suppression d'une sélection: les entrées/sorties
    // d'abord, puis TOUTES les écritures de base en une transaction avec UN
    // notifyListeners. Passer par _deleteOpened en boucle notifiait ET
    // rechargeait l'écran entier À CHAQUE fichier.
    for (final e in victims) {
      await PlayerController.current?.handleDeletedTrack(e.path);
      try {
        final f = File(e.path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    await LocalDb.instance.runBatchWrites((db) async {
      for (final e in victims) {
        await LocalDb.instance
            .deleteEntriesUnderPath(e.path, db: db, notify: false);
      }
    });
    if (mounted) setState(() => _busy = false);
    await _load();
  }

  /// Confirmation UNIFORME des purges: chaque catégorie dit ce qu'elle efface
  /// et ce que ça coûte — la demande explicite de l'utilisateur, un « Vider »
  /// par poste, jamais un geste global.
  Future<bool> _confirm(String title, String body) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.commonDelete)),
        ],
      ),
    );
    return ok == true && mounted;
  }

  Future<void> _clearDownloads() async {
    final l10n = context.l10n;
    if (!await _confirm(l10n.storageDownloads,
        l10n.storageDownloadsClearBody)) {
      return;
    }
    setState(() => _busy = true);
    // Par FICHIER via deleteLocalTrack, pas un rm -rf du dossier: c'est lui qui
    // sait arrêter la lecture en cours, purger les lignes `tracks` et la queue
    // — un effacement disque seul laisserait la base pleine de fantômes.
    final docs = (await RewampDb.downloadsBaseDir()).path;
    final dir = Directory(p.join(docs, 'online'));
    if (await dir.exists()) {
      final files = <String>[];
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is File) files.add(e.path);
      }
      for (final f in files) {
        await PlayerController.current?.handleDeletedTrack(f);
        await RewampDb.deleteLocalTrack(f);
      }
      // deleteLocalTrack efface fichier + dossier d'album; balayer le reste
      // (dossiers vides, caches d'archive).
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
    if (mounted) setState(() => _busy = false);
    await _load();
  }

  Future<void> _clearSoundfonts() async {
    final l10n = context.l10n;
    if (!await _confirm(l10n.storageSoundfonts,
        l10n.storageSoundfontsClearBody)) {
      return;
    }
    final support = await getApplicationSupportDirectory();
    final dir =
        Directory(p.join(support.path, 'rewamp_data', 'soundfonts'));
    if (await dir.exists()) {
      await for (final e in dir.list()) {
        try {
          await e.delete(recursive: true);
        } catch (_) {}
      }
    }
    await _load();
  }

  Future<void> _clearPresets() async {
    final l10n = context.l10n;
    if (!await _confirm(l10n.storagePresets, l10n.storagePresetsClearBody)) {
      return;
    }
    final support = await getApplicationSupportDirectory();
    // SEULEMENT les dossiers de l'utilisateur — l'embarqué recopié au démarrage
    // ne reviendrait pas avant le prochain bump d'assets (voir _load).
    for (final sub in _kPresetUserDirs) {
      final dir =
          Directory(p.join(support.path, 'rewamp_data', 'projectm', sub));
      if (await dir.exists()) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      }
    }
    await _load();
  }

  Future<void> _clearArtwork() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final removed = await ArtworkCache.instance.clearCache();
    await LocalDb.instance.clearMetadataCache();
    AppSnack.showOn(messenger, l10n.settingsCacheCleared(removed));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final opened = _opened;
    final openedBytes =
        opened?.fold<int>(0, (sum, e) => sum + e.bytes) ?? 0;

    // Un poste s'OUVRE: la vue par catégorie liste ses fichiers, les filtre et
    // en supprime une sélection. « Vider » reste en face pour le geste global —
    // les deux répondent à des besoins différents (faire de la place vs retirer
    // ce morceau-là), et forcer l'un à travers l'autre serait pénible dans les
    // deux sens.
    Widget catTile(IconData icon, String title, _CategoryStat? stat,
        {String? subtitle, Widget? trailing, StorageKind? kind}) {
      return ListTile(
        leading: Icon(icon, color: cs.primary),
        title: Text(title),
        subtitle: Text(stat == null
            ? '…'
            : subtitle ??
                l10n.storageCategoryStat(stat.files, _fmtSize(stat.bytes))),
        trailing: trailing == null
            ? const Icon(Icons.chevron_right)
            : Row(mainAxisSize: MainAxisSize.min, children: [
                trailing,
                const Icon(Icons.chevron_right),
              ]),
        onTap: (kind == null || (stat?.files ?? 0) == 0)
            ? null
            : () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      StorageCategoryScreen(kind: kind, title: title),
                ));
                await _load();   // la vue de détail a pu supprimer
              },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.storageTitle)),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: shellInset(context, EdgeInsets.zero),
              children: [
                // ── Postes globaux ─────────────────────────────────────────
                catTile(Icons.download_outlined, l10n.storageDownloads,
                    _downloads,
                    subtitle: _downloads == null
                        ? null
                        : l10n.storageDownloadsSubtitle(_downloads!.files,
                            _fmtSize(_downloads!.bytes)),
                    kind: StorageKind.downloads,
                    trailing: TextButton(
                      onPressed: (_downloads?.files ?? 0) > 0
                          ? _clearDownloads
                          : null,
                      child: Text(l10n.storageClear),
                    )),
                catTile(Icons.library_music_outlined, l10n.storageLocalImports,
                    _localImports,
                    kind: StorageKind.localImports),
                catTile(Icons.image_outlined, l10n.storageArtworkCache,
                    _artwork,
                    kind: StorageKind.artwork,
                    trailing: TextButton(
                      onPressed: (_artwork?.files ?? 0) > 0
                          ? _clearArtwork
                          : null,
                      child: Text(l10n.storageClear),
                    )),
                catTile(Icons.piano_outlined, l10n.storageSoundfonts,
                    _soundfonts,
                    kind: StorageKind.soundfonts,
                    trailing: TextButton(
                      onPressed: (_soundfonts?.files ?? 0) > 0
                          ? _clearSoundfonts
                          : null,
                      child: Text(l10n.storageClear),
                    )),
                catTile(Icons.auto_awesome_outlined, l10n.storagePresets,
                    _presets,
                    kind: StorageKind.presets,
                    trailing: TextButton(
                      onPressed: (_presets?.files ?? 0) > 0
                          ? _clearPresets
                          : null,
                      child: Text(l10n.storageClear),
                    )),
                const Divider(height: 24),

                // Fichiers ouverts: même forme que les autres postes. La
                // liste vit dans la vue de détail — ici on garde ce qui est
                // PROPRE à cette catégorie: « tout supprimer » ÉPARGNE le
                // référencé, le geste global nettoie sans casser ce que
                // l'utilisateur a construit.
                //
                // ⚠️ MOBILE seulement. `OpenedFiles.materialise` ne recopie que
                // sur iOS/Android — sur bureau le sélecteur rend le VRAI chemin
                // du fichier de l'utilisateur, qui joue depuis là où il est
                // (le dupliquer ferait une copie fantôme de sa discothèque).
                // Le dossier n'existe donc jamais là, et un poste
                // éternellement vide se lit comme « mes fichiers ouverts ont
                // disparu ».
                if (Platform.isIOS || Platform.isAndroid)
                catTile(Icons.folder_open, l10n.storageOpenedFiles,
                    opened == null
                        ? null
                        : _CategoryStat(opened.length, openedBytes),
                    kind: StorageKind.opened,
                    trailing: (opened?.any((e) => !e.referenced) ?? false)
                        ? TextButton(
                            onPressed: _deleteAllOpened,
                            child: Text(l10n.storageDeleteAll),
                          )
                        : null),
                // Même condition que la ligne au-dessus: sans elle, le
                // « aucun fichier ouvert » restait seul sur un bureau où la
                // catégorie n'existe pas.
                if ((Platform.isIOS || Platform.isAndroid) &&
                    opened != null &&
                    opened.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(l10n.storageOpenedEmpty,
                        style: TextStyle(color: cs.outline)),
                  ),
              ],
            ),
    );
  }
}

// ── Détail d'une catégorie ───────────────────────────────────────────────────

/// Ce qu'une catégorie sait faire de ses fichiers. Le comportement varie sur un
/// seul point — comment on EFFACE — et il n'est pas cosmétique: un
/// téléchargement doit passer par `deleteLocalTrack` (arrêt de la lecture,
/// purge des lignes `tracks` et de la queue), là où une SoundFont n'est qu'un
/// fichier. Effacer un téléchargement « à la main » laisserait la base pleine
/// de fantômes.
enum StorageKind { downloads, opened, localImports, soundfonts, presets, artwork }

class StorageCategoryScreen extends StatefulWidget {
  final StorageKind kind;
  final String title;
  const StorageCategoryScreen(
      {super.key, required this.kind, required this.title});

  @override
  State<StorageCategoryScreen> createState() => _StorageCategoryScreenState();
}

class _Entry {
  final String path;
  /// Ce qu'on AFFICHE et ce sur quoi le filtre porte: le chemin relatif à la
  /// racine de la catégorie. Un basename seul ne distingue pas deux
  /// « artwork.png » de deux albums, et le chemin absolu est illisible.
  final String label;
  final int bytes;
  final bool referenced;
  const _Entry(this.path, this.label, this.bytes, this.referenced);
}

class _StorageCategoryScreenState extends State<StorageCategoryScreen> {
  final _filterCtrl = TextEditingController();
  final _selected = <String>{};   // des CHEMINS: une position ne survit pas au filtre
  // Mode sélection EXPLICITE (voir le navigateur local): « Tout désélectionner »
  // vide la sélection sans quitter le mode; la croix et la fin d'une
  // suppression en sortent.
  bool _selecting = false;
  List<_Entry>? _all;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<Directory> _root() async {
    final support = await getApplicationSupportDirectory();
    switch (widget.kind) {
      case StorageKind.downloads:
        return Directory(
            p.join((await RewampDb.downloadsBaseDir()).path, 'online'));
      case StorageKind.opened:
        return OpenedFiles.dir();
      case StorageKind.localImports:
        return localImportsDir();
      case StorageKind.soundfonts:
        return Directory(p.join(support.path, 'rewamp_data', 'soundfonts'));
      case StorageKind.presets:
        return Directory(p.join(support.path, 'rewamp_data', 'projectm'));
      case StorageKind.artwork:
        final cache = await getApplicationCacheDirectory();
        return Directory(p.join(cache.path, 'artwork'));
    }
  }

  Future<void> _load() async {
    final root = await _root();
    // Seuls les fichiers ouverts portent une notion de « référencé »: c'est là
    // que la purge automatique s'applique, donc là qu'il faut prévenir AVANT le
    // geste. Un téléchargement, lui, est toujours re-téléchargeable.
    final referenced = widget.kind == StorageKind.opened
        ? await OpenedFiles.referencedPaths()
        : const <String>{};
    // Un dossier d'album téléchargé est nommé d'après l'UUID de l'album (le
    // seul rangement qui ne se dédouble pas quand l'artiste varie d'un flux à
    // l'autre) — juste sur le disque, illisible ici. On traduit à l'AFFICHAGE,
    // jamais sur le disque: le chemin reste la vérité, et `path` (ce que la
    // suppression vise) n'est pas touché.
    final albumNames = widget.kind == StorageKind.downloads
        ? await LocalDb.instance.albumNamesById()
        : const <String, String>{};
    final out = <_Entry>[];
    if (await root.exists()) {
      // Les presets n'exposent que les dossiers de l'UTILISATEUR (voir
      // _kPresetUserDirs): l'embarqué ne se purge pas utilement.
      final roots = widget.kind == StorageKind.presets
          ? [for (final s in _kPresetUserDirs) Directory(p.join(root.path, s))]
          : [root];
      for (final r in roots) {
        if (!await r.exists()) continue;
        await for (final e in r.list(recursive: true, followLinks: false)) {
          if (e is! File) continue;
          try {
            out.add(_Entry(
                e.path,
                readableRelPath(p.relative(e.path, from: root.path), albumNames),
                await e.length(),
                referenced.contains(e.path)));
          } catch (_) {}
        }
      }
    }
    out.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _all = out;
      _selected.removeWhere((s) => !out.any((e) => e.path == s));
    });
  }

  List<_Entry> get _shown {
    final all = _all ?? const <_Entry>[];
    final q = _filterCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [for (final e in all) if (e.label.toLowerCase().contains(q)) e];
  }

  Future<void> _deleteSelection() async {
    final l10n = context.l10n;
    final victims = [
      for (final e in (_all ?? const <_Entry>[]))
        if (_selected.contains(e.path)) e,
    ];
    if (victims.isEmpty) return;
    final inUse = victims.where((e) => e.referenced).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.storageDeleteSelection),
        content: Text(inUse > 0
            ? l10n.storageDeleteSelectionInUseBody(victims.length, inUse)
            : l10n.storageDeleteSelectionBody(victims.length)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.commonDelete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final tracked = widget.kind == StorageKind.downloads ||
        widget.kind == StorageKind.opened ||
        widget.kind == StorageKind.localImports;
    // 1) Ce qui doit s'arrêter AVANT que les fichiers disparaissent sous le
    //    décodeur, et les fichiers eux-mêmes. Hors transaction: ce sont des
    //    entrées/sorties, pas des écritures de base.
    for (final e in victims) {
      if (tracked) await PlayerController.current?.handleDeletedTrack(e.path);
      try {
        final f = File(e.path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    // 2) TOUTES les écritures de base en UNE transaction, UN notifyListeners.
    //    Une par une, chaque suppression notifiait — et chaque écran à
    //    l'écoute (récents, bibliothèque, « Sur cet appareil », cet écran-ci)
    //    re-requêtait la base à chaque fichier: « tout supprimer » sur
    //    quelques centaines d'imports devenait quadratique.
    if (tracked) {
      await LocalDb.instance.runBatchWrites((db) async {
        for (final e in victims) {
          if (widget.kind == StorageKind.localImports) {
            // Un import EST une entrée de bibliothèque (le modèle): la
            // suppression doit la retirer ET le dire au compte — sinon la
            // synchro la ferait revivre au prochain pull (la leçon du favori
            // fantôme). L'outbox s'écrit dans le MÊME commit.
            await SyncService.recordTrackMembership(
                db: db, refId: '${e.path}?subsong=0', value: false);
            await LocalDb.instance.removeFromLibrary(
                'track', '${e.path}?subsong=0', db: db, notify: false);
          }
          await LocalDb.instance
              .deleteEntriesUnderPath(e.path, db: db, notify: false);
        }
      });
    }
    if (mounted) setState(() { _busy = false; _selected.clear(); _selecting = false; });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final shown = _shown;
    final all = _all;

    return Scaffold(
      appBar: AppBar(
        title: Text(!_selecting
            ? widget.title
            : l10n.storageSelectedCount(_selected.length)),
        actions: [
          if (_selecting) ...[
            // Même icône et même bascule que le navigateur local: tout coché
            // ⇒ le bouton désélectionne, sinon il complète la sélection.
            if (_selected.containsAll(shown.map((e) => e.path)))
              IconButton(
                icon: const Icon(Icons.deselect),
                tooltip: l10n.pmSelectNone,
                onPressed: () => setState(_selected.clear),
              )
            else
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: l10n.storageSelectAll,
                onPressed: () => setState(
                    () => _selected.addAll(shown.map((e) => e.path))),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.storageDeleteSelection,
              onPressed: _deleteSelection,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.commonCancel,
              onPressed: () => setState(() { _selected.clear(); _selecting = false; }),
            ),
          ] else if (shown.isNotEmpty)
            // « Tout » porte sur ce qui est AFFICHÉ, pas sur le dossier: avec un
            // filtre actif, sélectionner ce qu'on ne voit pas serait un piège.
            // Une ICÔNE, la même que dans le navigateur local — deux boutons
            // pour un même geste ne doivent pas se ressembler différemment.
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: l10n.storageSelectAll,
              onPressed: () => setState(() {
                _selecting = true;
                _selected.addAll(shown.map((e) => e.path));
              }),
            ),
        ],
      ),
      body: _busy || all == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: CancelField(
                    controller: _filterCtrl,
                    onCleared: (_) => setState(() {}),
                    builder: (_) => TextField(
                      controller: _filterCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.search, size: 18),
                        hintText: l10n.storageFilterHint,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.storageCategoryStat(shown.length,
                          _StorageScreenState._fmtSize(
                              shown.fold<int>(0, (s, e) => s + e.bytes))),
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
                Expanded(
                  child: shown.isEmpty
                      ? Center(
                          child: Text(l10n.storageNoMatch,
                              style: TextStyle(color: cs.outline)))
                      : ListView.builder(
                          padding: shellInset(context, EdgeInsets.zero),
                          itemCount: shown.length,
                          itemBuilder: (_, i) {
                            final e = shown[i];
                            final sel = _selected.contains(e.path);
                            void toggle() => setState(() {
                                  _selecting = true;
                                  sel ? _selected.remove(e.path) : _selected.add(e.path);
                                });
                            final subtitle = Text(
                              [
                                _StorageScreenState._fmtSize(e.bytes),
                                if (e.referenced) l10n.storageInUse,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: e.referenced
                                  ? TextStyle(color: cs.primary)
                                  : null,
                            );
                            // « Fichiers ouverts »: la ligne se JOUE au tap —
                            // c'est la seule surface de relance une fois le
                            // morceau sorti de la file et des récents (sa
                            // copie, elle, est encore là). La case reste le
                            // geste de sélection; en mode sélection le tap
                            // bascule, comme partout. Le routeur local gère
                            // aussi une ARCHIVE ouverte (extraction + file).
                            if (widget.kind == StorageKind.opened ||
                                widget.kind == StorageKind.localImports) {
                              return ListTile(
                                dense: true,
                                leading: Checkbox(
                                    value: sel, onChanged: (_) => toggle()),
                                title: ScrollingText(text: e.label),
                                subtitle: subtitle,
                                trailing: !_selecting
                                    ? const Icon(Icons.play_arrow, size: 20)
                                    : null,
                                onTap: () {
                                  if (_selecting) {
                                    toggle();
                                  } else {
                                    globalOpenLocalPaths?.call([e.path]);
                                  }
                                },
                                onLongPress: toggle,
                              );
                            }
                            return CheckboxListTile(
                              dense: true,
                              value: sel,
                              onChanged: (_) => toggle(),
                              title: ScrollingText(text: e.label),
                              subtitle: subtitle,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
