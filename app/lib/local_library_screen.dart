// « Sur cet appareil » — l'arbre des imports locaux (plan
// local-import-library). La structure d'origine est PRÉSERVÉE, jamais gérée:
// l'arbre affiché est dérivé de `local_rel_path` à la lecture, aucun état de
// dossier n'existe en base. Un niveau = les sous-dossiers (premier segment
// après le préfixe) + les pistes posées à ce niveau; la recherche est plate
// sur tout le sous-arbre courant.

import 'dart:math' show Random;
import 'dart:io';

import 'package:flutter/foundation.dart' show mapEquals, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'artwork_image.dart' show ArtworkCache, RailArtwork;
import 'cancel_field.dart';
import 'l10n.dart';
import 'formats.dart';
import 'local_db.dart';
import 'rewamp_db.dart';
import 'local_delete.dart'
    show deleteDownloadedTrack, deleteDownloadedFolder;
import 'local_ops.dart' show LocalOpsBanner;
import 'app_snack.dart';
import 'local_manage.dart';
import 'local_import.dart'
    show deleteLocalImportTrack, deleteLocalImportFolder, showLocalImportSheet,
         localImportsDir;
import 'local_open.dart' show globalOpenLocalPaths;
import 'radio_surprise_buttons.dart';
import 'scrolling_text.dart';

/// Ce que l'arbre parcourt. Deux arbres, un seul écran: la structure et les
/// gestes sont les mêmes, seules la SOURCE des lignes et la propriété du
/// contenu changent.
enum LocalBrowseSource {
  /// `<support>/local/` — ce que l'utilisateur a importé. Lui appartient: il
  /// peut le supprimer d'ici.
  imports,

  /// `<downloads>/online/` — ce que le catalogue a descendu. La suppression
  /// reste dans Réglages → Données → Stockage: c'est un geste de PLACE
  /// DISQUE, et un téléchargement se re-télécharge.
  downloads,
}

class LocalLibraryScreen extends StatefulWidget {
  /// Préfixe de chemin relatif ('' = racine, sinon toujours terminé par '/').
  final String prefix;
  final String? title;
  final LocalBrowseSource source;

  const LocalLibraryScreen({
    super.key,
    this.prefix = '',
    this.title,
    this.source = LocalBrowseSource.imports,
  });

  @override
  State<LocalLibraryScreen> createState() => _LocalLibraryScreenState();
}

class _FolderEntry {
  final String name;
  int count = 0;
  _FolderEntry(this.name);
}

class _LocalLibraryScreenState extends State<LocalLibraryScreen> {
  final _filterCtrl = TextEditingController();
  String _filter = '';

  /// Sous-arbre courant, trié par chemin relatif (l'ordre de la requête).
  List<(String relPath, TrackRecord track)> _subtree = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Une suppression dans Données/Stockage ou un nouvel import doivent se
    // refléter au retour sur l'écran.
    LocalDb.instance.addListener(_load);
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_load);
    _filterCtrl.dispose();
    super.dispose();
  }

  /// uuid d'album → nom lisible. Vide pour les imports (leurs dossiers sont
  /// ceux de l'utilisateur); pour les téléchargements, c'est ce qui remplace
  /// `online/jw_spc/2f3c…-…/` par le nom de l'album.
  Map<String, String> _albumNames = const {};

  /// Les playlists (.m3u/.m3u8) POSÉES à ce niveau de l'arbre.
  ///
  /// Elles n'ont pas de ligne `tracks` — ce ne sont pas des pistes — donc elles
  /// viennent du DISQUE, et seulement pour le niveau affiché (un listing non
  /// récursif). Elles comptent: un album téléchargé peut être la FUSION de
  /// plusieurs playlists (jw_dsf en livre une par sortie), et sans elles il n'y
  /// a aucun moyen de rejouer l'une d'elles plutôt que le dossier entier.
  List<String> _playlists = const [];
  /// Les dossiers RÉELS du niveau courant (y compris vides) — voir _load.
  Set<String> _diskFolders = const {};

  /// Nom de sous-dossier (niveau affiché) → sa pochette sur le disque.
  Map<String, String> _folderArt = const {};

  /// Sélection multiple, même modèle que Stockage: active dès qu'un élément
  /// est coché (pas de mode à part). Des CLÉS, jamais des positions: un
  /// rechargement (la base notifie à chaque suppression) ne doit pas déplacer
  /// la sélection sur une autre ligne. `dir:<préfixe>` / `track:<chemin>`.
  final _selected = <String>{};
  // Mode sélection EXPLICITE, pas déduit de « la sélection n'est pas vide »:
  // « Tout désélectionner » vide la sélection SANS quitter le mode (on veut
  // pouvoir recocher), seuls la croix, le retour et la fin d'un geste (lire,
  // supprimer) en sortent.
  bool _selecting = false;
  void _exitSelection() { _selected.clear(); _selecting = false; }
  static String _dirKey(String childPrefix) => 'dir:$childPrefix';
  static String _trackKey(TrackRecord t) => 'track:${t.filePath}';
  void _toggle(String key) => setState(() {
        _selecting = true;
        _selected.contains(key) ? _selected.remove(key) : _selected.add(key);
      });

  /// La racine absolue de l'arbre parcouru.
  Future<String> _rootPath() async =>
      widget.source == LocalBrowseSource.downloads
          ? await RewampDb.onlineLibraryDir()
          : (await localImportsDir()).path;

  Future<void> _load() async {
    final db = LocalDb.instance;
    final all = widget.source == LocalBrowseSource.downloads
        ? await db.getDownloadedTracks()
        : await db.getLocalImports();
    final names = widget.source == LocalBrowseSource.downloads
        ? await db.albumNamesById()
        : const <String, String>{};
    // Le niveau courant, sur le disque. Un dossier absent (piste dont le
    // fichier a disparu) rend simplement une liste vide.
    final playlists = <String>[];
    // ⚠️ Les dossiers du niveau courant se lisent SUR LE DISQUE, pas dans la
    // base. L'arbre se dérive de `local_rel_path`, donc un dossier qui ne
    // contient AUCUNE piste n'y existe pas — un dossier fraîchement créé était
    // invisible, donc ni renommable ni supprimable: on offrait un geste dont
    // le résultat n'apparaissait nulle part.
    final diskFolders = <String>{};
    try {
      final dir = Directory(p.join(await _rootPath(), widget.prefix));
      if (await dir.exists()) {
        await for (final e in dir.list(followLinks: false)) {
          if (e is Directory) {
            diskFolders.add(p.basename(e.path));
            continue;
          }
          if (e is! File) continue;
          final ext = p.extension(e.path).replaceFirst('.', '').toLowerCase();
          if (ext == 'm3u' || ext == 'm3u8') playlists.add(e.path);
        }
      }
    } catch (_) {}
    playlists.sort((a, b) =>
        p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase()));
    if (!mounted) return;
    setState(() {
      _albumNames = names;
      _playlists = playlists;
      _diskFolders = diskFolders;
      _subtree = [
        for (final e in all)
          // Un dossier de COMPAGNONS n'a pas de pistes à montrer: ses fichiers
          // portent des extensions jouables (`.ss` = SpeedySystem) mais ce
          // sont des échantillons. Une ligne y menant ne peut que finir en
          // « Format non supporté ». Voir [isInCompanionDir].
          if (e.$1.startsWith(widget.prefix) && !isInCompanionDir(e.$1)) e,
      ];
      // Ce qui a disparu (supprimé ici ou ailleurs) sort de la sélection.
      _selected.removeWhere((k) => k.startsWith('dir:')
          ? !_subtree.any((e) => e.$1.startsWith(k.substring(4)))
          : !_subtree.any((e) => _trackKey(e.$2) == k));
      _loading = false;
    });
    _loadFolderArt();
  }

  /// La pochette de chaque sous-dossier du niveau affiché (voir
  /// ArtworkCache.findFolderArtwork). Hors du chargement principal: la liste
  /// s'affiche tout de suite, les vignettes arrivent ensuite, et un dossier
  /// sans image garde son icône. Vaut aussi pour les téléchargements, dont
  /// le dossier d'album porte son `artwork.jpg`.
  Future<void> _loadFolderArt() async {
    final names = <String>{};
    for (final (rel, _) in _subtree) {
      final rest = rel.substring(widget.prefix.length);
      final slash = rest.indexOf('/');
      if (slash > 0) names.add(rest.substring(0, slash));
    }
    final root = await _rootPath();
    final art = <String, String>{};
    await Future.wait([
      for (final n in names)
        ArtworkCache.instance
            .findFolderArtwork(p.join(root, widget.prefix, n))
            .then((a) {
          if (a != null) art[n] = a;
        }),
    ]);
    if (!mounted || mapEquals(art, _folderArt)) return;
    setState(() => _folderArt = art);
  }

  /// Vignette de dossier: sa pochette quand il en a une, le glyphe de dossier
  /// en badge (la ligne reste reconnaissable comme un DOSSIER au milieu des
  /// pistes); sinon l'icône seule.
  Widget _folderLeading(String? art, ColorScheme cs) {
    const icon = Icon(Icons.folder_outlined);
    if (art == null) return icon;
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(art),
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              cacheWidth: 120,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => icon,
            ),
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.folder, size: 14, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  /// Le nom AFFICHÉ d'un segment de chemin. Un dossier d'album téléchargé est
  /// nommé d'après l'UUID de l'album (le seul rangement qui ne se dédouble pas
  /// quand l'artiste varie selon le flux) — juste sur le disque, illisible à
  /// l'écran.
  String _segmentLabel(String segment) => _albumNames[segment] ?? segment;

  void _onFilterChanged([String? _]) {
    setState(() => _filter = _filterCtrl.text.trim());
  }

  /// Jouer par CHEMIN — le routage commun à l'ouverture et au dépôt.
  ///
  /// Tentation évitée: passer les `TrackRecord` que cet écran tient déjà
  /// (« ils portent l'identité »). Le chemin fait TROIS choses que la ligne ne
  /// fait pas — il DÉPLIE (un `.sid` importé a 21 sous-chansons, la ligne n'en
  /// est qu'une), il passe par la feuille « quand l'entendre » (règle du
  /// projet: tout geste qui ÉCRASERAIT la file y passe), et il filtre le lot.
  /// Et l'identité n'est plus un argument: `tracksForLocalPath` réutilise
  /// désormais la ligne DÉJÀ EN BASE quand elle existe.
  void _playAll(Iterable<TrackRecord> records) {
    final list = records.toList();
    if (list.isEmpty) return;
    globalOpenLocalPaths?.call([for (final t in list) t.filePath]);
  }

  /// Les DEUX arbres se suppriment ici.
  ///
  /// Ça n'a pas toujours été le cas: le geste était réservé aux imports, au
  /// motif qu'un téléchargement se supprime dans Réglages → Données →
  /// Stockage. Mais cet écran-là ne connaît que des FICHIERS à plat, alors que
  /// c'est ici qu'on voit l'arborescence — et donc ici qu'on veut retirer un
  /// album ou un dossier entier.
  ///
  /// ⚠️ Les deux gestes n'effacent pas la même chose: un import supprimé quitte
  /// aussi la BIBLIOTHÈQUE et le compte, un téléchargement ne libère que de la
  /// place (son entrée reste, le catalogue le re-téléchargera). Voir
  /// local_delete.dart.
  bool get _canDelete => true;

  bool get _isDownloads => widget.source == LocalBrowseSource.downloads;

  Widget _deleteBackground(ColorScheme cs) => Container(
        color: cs.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
      );

  /// Confirmation puis suppression d'UNE piste (fichier + bibliothèque +
  /// synchro + compagnons non partagés — deleteLocalImportTrack). Rend false
  /// dans tous les cas: la ligne ne se retire pas par l'animation du
  /// Dismissible mais par le rechargement (_load, déclenché par le
  /// notifyListeners de la base) — sinon la ligne animée et la ligne rechargée
  /// se battent.
  Future<bool> _confirmAndDeleteTrack(TrackRecord t) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.commonDelete),
        content: Text(l10n.localDeleteTrackConfirm(t.displayTitle)),
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
    if (ok == true) {
      await (_isDownloads
          ? deleteDownloadedTrack(t.filePath)
          : deleteLocalImportTrack(t.filePath));
    }
    return false;
  }

  /// Confirmation (nom + compte) puis suppression du SOUS-ARBRE
  /// (deleteLocalImportFolder — compagnons et pochettes partent avec le
  /// répertoire). Même contrat `false` que la piste.
  Future<bool> _confirmAndDeleteFolder(
      String childPrefix, String name, int count) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.commonDelete),
        content: Text(l10n.localDeleteFolderConfirm(name, count)),
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
    if (ok == true) {
      if (_isDownloads) {
        // Le sous-arbre part d'un bloc: `deleteLocalAlbumDir` efface le
        // répertoire ET les lignes locales qui vivent dessous. Il lui faut le
        // chemin ABSOLU, pas le préfixe relatif de l'arbre.
        final rel = childPrefix.endsWith('/')
            ? childPrefix.substring(0, childPrefix.length - 1)
            : childPrefix;
        await deleteDownloadedFolder(p.join(await _rootPath(), rel));
      } else {
        await deleteLocalImportFolder(childPrefix);
      }
    }
    return false;
  }

  /// Lire la sélection: pistes cochées + sous-arbres des dossiers cochés, par
  /// le routage commun (feuille « quand l'entendre », dépliage).
  void _playSelection() {
    final list = expandLocalSelection(_subtree, _selected, (t) => t.filePath);
    setState(_exitSelection);
    _playAll(list);
  }

  /// Supprimer la sélection, après UNE confirmation qui compte les FICHIERS
  /// visés. Un dossier part d'un bloc (compagnons et pochettes compris); une
  /// piste cochée DANS un dossier coché n'est pas supprimée deux fois.
  Future<void> _deleteSelection() async {
    final l10n = context.l10n;
    final victims = expandLocalSelection(_subtree, _selected, (t) => t.filePath);
    final count = {for (final t in victims) t.filePath}.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.storageDeleteSelection),
        content: Text(l10n.storageDeleteSelectionBody(count)),
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
    final dirs = [
      for (final k in _selected)
        if (k.startsWith('dir:')) k.substring(4),
    ];
    final loose = [
      for (final (rel, t) in _subtree)
        if (_selected.contains(_trackKey(t)) && !dirs.any(rel.startsWith)) t,
    ];
    setState(_exitSelection);
    final root = await _rootPath();
    for (final d in dirs) {
      if (_isDownloads) {
        final rel = d.endsWith('/') ? d.substring(0, d.length - 1) : d;
        await deleteDownloadedFolder(p.join(root, rel));
      } else {
        await deleteLocalImportFolder(d);
      }
    }
    final done = <String>{};
    for (final t in loose) {
      if (!done.add(t.filePath)) continue;
      await (_isDownloads
          ? deleteDownloadedTrack(t.filePath)
          : deleteLocalImportTrack(t.filePath));
    }
  }


  // ── Rangement (imports seulement) ───────────────────────────────────────
  //
  // ⚠️ Réservé aux IMPORTS: l'arbre `online/` est le miroir du catalogue, ses
  // chemins sont DÉRIVÉS de champs serveur et un téléchargement les recalcule.
  // Voir local_manage.dart.
  bool get _canManage => !_isDownloads;

  /// Demande un nom. Rend null si annulé ou vide.
  Future<String?> _askName(String title, String label, {String initial = ''}) {
    final l10n = context.l10n;
    final ctrl = TextEditingController(text: initial);
    // Le radical présélectionné: renommer « a.mid » vise « a », pas
    // l'extension — c'est ce que fait tout gestionnaire de fichiers.
    final dot = initial.lastIndexOf('.');
    ctrl.selection = TextSelection(
        baseOffset: 0, extentOffset: dot > 0 ? dot : initial.length);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(l10n.commonOk)),
        ],
      ),
    ).then((v) => (v == null || v.isEmpty) ? null : v);
  }

  /// ⚠️ Un message par RAISON, jamais le nom de l'enum injecté dans une
  /// phrase: un libellé qui n'existe que dans le code n'est pas traduisible,
  /// et les raisons qu'on ne peut pas expliquer se replient sur une seule.
  void _manageFailed(Object e) {
    if (!mounted) return;
    final l10n = context.l10n;
    final reason = e is LocalManageException ? e.reason : null;
    AppSnack.show(context, switch (reason) {
      LocalManageError.badName      => l10n.localNameInvalid,
      LocalManageError.exists       => l10n.localNameTaken,
      LocalManageError.intoItself   => l10n.localMoveIntoItself,
      _                             => l10n.localManageFailed,
    });
  }

  Future<void> _createFolder() async {
    final l10n = context.l10n;
    final name = await _askName(l10n.localNewFolder, l10n.localFolderName);
    if (name == null || !mounted) return;
    try {
      await createLocalFolder(
          p.join(await _rootPath(), widget.prefix), name);
      await _load();
    } catch (e) {
      _manageFailed(e);
    }
  }

  /// Le chemin ABSOLU de l'unique entrée sélectionnée (piste ou dossier).
  Future<String?> _soleSelectionPath() async {
    if (_selected.length != 1) return null;
    final k = _selected.first;
    if (k.startsWith('dir:')) {
      final rel = k.substring(4);
      return p.join(await _rootPath(),
          rel.endsWith('/') ? rel.substring(0, rel.length - 1) : rel);
    }
    return k.substring('track:'.length);
  }

  Future<void> _renameSelection() async {
    final l10n = context.l10n;
    final src = await _soleSelectionPath();
    if (src == null || !mounted) return;
    final name = await _askName(l10n.localRename, l10n.localFolderName,
        initial: p.basename(src));
    if (name == null || !mounted) return;
    setState(_exitSelection);
    try {
      await renameLocalEntry(src, name);
      await _load();
    } catch (e) {
      _manageFailed(e);
    }
  }

  /// Les dossiers où l'on peut déplacer: la racine et tout son arbre, moins
  /// ceux qu'on déplace (on n'entre pas dans soi-même).
  Future<List<String>> _destinationDirs(List<String> moving) async {
    final root = await _rootPath();
    final out = <String>{root};
    try {
      await for (final e in Directory(root).list(recursive: true, followLinks: false)) {
        if (e is Directory) out.add(e.path);
      }
    } catch (_) {}
    return [
      for (final d in out)
        if (!moving.any((m) => movesIntoItself(m, d))) d,
    ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Future<void> _moveSelection() async {
    final l10n = context.l10n;
    final root = await _rootPath();
    // Dossiers cochés d'abord: une piste cochée DANS un dossier coché part
    // avec lui, on ne la déplace pas deux fois (même règle que la
    // suppression).
    String abs(String key) {
      final rel = key.substring(4);
      return p.join(
          root, rel.endsWith('/') ? rel.substring(0, rel.length - 1) : rel);
    }

    final dirs = [
      for (final k in _selected)
        if (k.startsWith('dir:')) abs(k),
    ];
    final loose = [
      for (final (_, t) in _subtree)
        if (_selected.contains(_trackKey(t)) &&
            !dirs.any((d) => p.isWithin(d, t.filePath)))
          t.filePath,
    ];
    final moving = [...dirs, ...{...loose}];
    if (moving.isEmpty || !mounted) return;

    final dests = await _destinationDirs(moving);
    if (!mounted) return;
    final dest = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.localMoveTo),
        children: [
          for (final d in dests)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d),
              child: Text(p.equals(d, root) ? '/' : p.relative(d, from: root)),
            ),
        ],
      ),
    );
    if (dest == null || !mounted) return;
    setState(_exitSelection);
    final done = await moveLocalEntries(moving, dest);
    if (!mounted) return;
    if (done == 0) AppSnack.show(context, l10n.localMoveNothing);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;

    // Partition du niveau courant — dérivée à chaque build (quelques centaines
    // de lignes, trivial), jamais stockée.
    final folders = <String, _FolderEntry>{};
    final tracks = <(String rel, TrackRecord t)>[];
    final q = _filter.toLowerCase();
    for (final (rel, t) in _subtree) {
      final rest = rel.substring(widget.prefix.length);
      if (q.isNotEmpty) {
        // Recherche PLATE sur le sous-arbre: le chemin relatif porte les noms
        // de dossiers, donc « garegga » trouve aussi par le nom d'archive.
        if (rel.toLowerCase().contains(q) ||
            (t.title ?? '').toLowerCase().contains(q)) {
          tracks.add((rel, t));
        }
        continue;
      }
      final slash = rest.indexOf('/');
      if (slash < 0) {
        tracks.add((rel, t));
      } else {
        final name = rest.substring(0, slash);
        (folders[name] ??= _FolderEntry(name)).count++;
      }
    }
    // Les dossiers VIDES: présents sur le disque, absents de la base. Pas sous
    // filtre — la recherche est plate et ne liste que des pistes.
    if (q.isEmpty) {
      for (final name in _diskFolders) {
        folders.putIfAbsent(name, () => _FolderEntry(name));
      }
    }
    // ⚠️ Le tri est EXPLICITE. Il ne l'était pas: l'ordre venait par accident de
    // l'`ORDER BY local_rel_path COLLATE NOCASE` de la requête, donc les
    // dossiers dérivés des pistes sortaient alphabétiques par hasard — et un
    // dossier lu sur le DISQUE, ajouté après la boucle, atterrissait en fin de
    // liste (un dossier « 00 » après « midimt32 »). Un ordre d'affichage se
    // décide ici, il ne s'hérite pas d'une clause SQL trois couches plus bas.
    final folderList = folders.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // « Ce qui est affiché »: sous filtre, les pistes qui matchent; sinon le
    // sous-arbre entier (les dossiers listés le représentent). C'est ce que
    // visent « Tout lire », la radio et la surprise — la file est plafonnée
    // en aval (kQueueLimit, annoncé).
    final displayed = q.isNotEmpty
        ? [for (final (_, t) in tracks) t]
        : [for (final e in _subtree) e.$2];

    // Ce que « Tout sélectionner » coche: les lignes AFFICHÉES (dossiers et
    // pistes du niveau, ou résultats du filtre), jamais les playlists — elles
    // ne se suppriment pas d'ici.
    final shownKeys = [
      if (q.isEmpty)
        for (final f in folderList) _dirKey('${widget.prefix}${f.name}/'),
      for (final (_, t) in tracks) _trackKey(t),
    ];

    // Défaut = le nom de la carte du navigateur (« Imports locaux »), la seule
    // entrée qui arrive ici sans titre; l'onglet Local passe toujours le sien.
    final title = widget.title ?? l10n.storageLocalImports;
    return PopScope(
      // Retour = sortir de la sélection d'abord, comme la croix.
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_exitSelection);
      },
      child: Scaffold(
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.commonCancel,
                onPressed: () => setState(_exitSelection),
              ),
              title: Text(l10n.storageSelectedCount(_selected.length)),
              actions: [
                // Une seule icône pour « tout sélectionner » dans l'app (la même
                // qu'à Réglages → Stockage), et la même BASCULE: quand tout ce
                // qui est affiché est déjà coché, le bouton désélectionne.
                if (_selected.containsAll(shownKeys))
                  IconButton(
                    icon: const Icon(Icons.deselect),
                    tooltip: l10n.pmSelectNone,
                    onPressed: () => setState(_selected.clear),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.select_all),
                    tooltip: l10n.storageSelectAll,
                    onPressed: () => setState(() {
                      _selecting = true;
                      _selected.addAll(shownKeys);
                    }),
                  ),
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: l10n.commonPlayAll,
                  onPressed: _playSelection,
                ),
                // Renommer n'a de sens que sur UNE entrée — et ça évite
                // d'inventer un geste par ligne: la sélection est le modèle
                // que cet écran (et Réglages → Stockage) utilise déjà.
                if (_canManage && _selected.length == 1)
                  IconButton(
                    icon: const Icon(Icons.drive_file_rename_outline),
                    tooltip: l10n.localRename,
                    onPressed: _renameSelection,
                  ),
                if (_canManage)
                  IconButton(
                    icon: const Icon(Icons.drive_file_move_outline),
                    tooltip: l10n.localMove,
                    onPressed: _moveSelection,
                  ),
                if (_canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.storageDeleteSelection,
                    onPressed: _deleteSelection,
                  ),
              ],
            )
          : AppBar(
        title: Text(title),
        // Le « + » n'est qu'à la RACINE: dans un sous-dossier il laisserait
        // croire qu'on importe LÀ, or un import va toujours sous `local/` en
        // préservant sa propre arborescence.
        actions: [
          // Entrée en sélection sans appui long (bureau, souris): coche
          // tout ce qui est affiché, on décoche ensuite.
          if (shownKeys.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: l10n.storageSelectAll,
              onPressed: () => setState(() {
                _selecting = true;
                _selected.addAll(shownKeys);
              }),
            ),
          // Créer un dossier À TOUT NIVEAU, contrairement au « + »
          // d'import: on range LÀ où on regarde.
          if (_canManage)
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined),
              tooltip: l10n.localNewFolder,
              onPressed: _createFolder,
            ),
          if (widget.prefix.isEmpty && _canDelete)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.localImportFiles,
              onPressed: () => showLocalImportSheet(context),
            ),
        ],
      ),
      body: Column(
        children: [
          const LocalOpsBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: CancelField(
              controller: _filterCtrl,
              onCleared: _onFilterChanged,
              builder: (_) => TextField(
                controller: _filterCtrl,
                decoration: InputDecoration(
                  hintText: l10n.browseFilterByTitle,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: _onFilterChanged,
              ),
            ),
          ),
          // Compteur + « Tout lire » + la paire Radio/Surprise habituelle —
          // même rangée que les autres écrans de résultats. Radio = le même
          // contenu MÉLANGÉ (pas de station serveur pour du local), surprise
          // = UN morceau au hasard.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.albumTrackCount(displayed.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.play_arrow, size: 21),
                  tooltip: l10n.browsePlayAll,
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      displayed.isEmpty ? null : () => _playAll(displayed),
                ),
                const SizedBox(width: 8),
                RadioSurpriseButtons(
                  onRadio: displayed.isEmpty
                      ? null
                      : () =>
                          _playAll(List.of(displayed)..shuffle(Random())),
                  onSurprise: displayed.isEmpty
                      ? null
                      : () => _playAll([
                            displayed[Random().nextInt(displayed.length)],
                          ]),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                // Les PLAYLISTS comptent comme du contenu: un dossier qui
                // n'en contient que (un rip dont les pistes vivent ailleurs,
                // un niveau intermédiaire) s'annonçait VIDE alors qu'il y
                // avait quelque chose à lancer.
                : (folderList.isEmpty && tracks.isEmpty && _playlists.isEmpty)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            widget.source == LocalBrowseSource.downloads
                                ? l10n.libraryEmpty
                                : l10n.localLibraryEmpty,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      )
                    : ListView.builder(
                        // Les playlists d'abord: elles décrivent le dossier
                        // qu'on vient d'ouvrir, et elles sont peu nombreuses.
                        // Écartées sous filtre — la recherche porte sur des
                        // PISTES.
                        itemCount: (q.isEmpty ? _playlists.length : 0) +
                            folderList.length +
                            tracks.length,
                        itemBuilder: (ctx, i) {
                          final pls = q.isEmpty ? _playlists : const <String>[];
                          if (i < pls.length) {
                            final m3u = pls[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.queue_music),
                              title: ScrollingText(
                                  text: p.basenameWithoutExtension(m3u)),
                              subtitle: Text(
                                  p.extension(m3u).replaceFirst('.', '')
                                      .toUpperCase(),
                                  style: TextStyle(color: cs.onSurfaceVariant)),
                              // Le routage commun déplie le M3U (entrées,
                              // sous-chansons, durées) — voir
                              // tracksForLocalPath.
                              onTap: () =>
                                  globalOpenLocalPaths?.call([m3u]),
                            );
                          }
                          i -= pls.length;
                          if (i < folderList.length) {
                            final f = folderList[i];
                            final childPrefix = '${widget.prefix}${f.name}/';
                            // Glissement = suppression du SOUS-ARBRE, avec
                            // confirmation (nom + compte). Clé sur le préfixe:
                            // l'identité du dossier, pas sa position.
                            return Dismissible(
                              key: ValueKey('dir:$childPrefix'),
                              direction: (_canDelete && !_selecting)
                                  ? DismissDirection.endToStart
                                  : DismissDirection.none,
                              background: _deleteBackground(cs),
                              confirmDismiss: (_) => _confirmAndDeleteFolder(
                                  childPrefix, f.name, f.count),
                              child: ListTile(
                              dense: true,
                              selected: _selected.contains(_dirKey(childPrefix)),
                              leading: _selecting
                                  ? Checkbox(
                                      value: _selected.contains(_dirKey(childPrefix)),
                                      onChanged: (_) => _toggle(_dirKey(childPrefix)))
                                  : _folderLeading(_folderArt[f.name], cs),
                              title: ScrollingText(text: _segmentLabel(f.name)),
                              subtitle: Text(l10n.albumTrackCount(f.count)),
                              onLongPress: () => _toggle(_dirKey(childPrefix)),
                              trailing: _selecting ? null : IconButton(
                                icon: const Icon(Icons.play_arrow, size: 20),
                                tooltip: l10n.browsePlayAll,
                                onPressed: () => _playAll([
                                  for (final (rel, t) in _subtree)
                                    if (rel.startsWith(childPrefix)) t,
                                ]),
                              ),
                              onTap: _selecting
                                  ? () => _toggle(_dirKey(childPrefix))
                                  : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LocalLibraryScreen(
                                    prefix: childPrefix,
                                    title: _segmentLabel(f.name),
                                    source: widget.source,
                                  ),
                                ),
                              ),
                              ),
                            );
                          }
                          final (rel, t) = tracks[i - folderList.length];
                          return Dismissible(
                            key: ValueKey('track:${t.filePath}'),
                            direction: (_canDelete && !_selecting)
                                ? DismissDirection.endToStart
                                : DismissDirection.none,
                            background: _deleteBackground(cs),
                            confirmDismiss: (_) => _confirmAndDeleteTrack(t),
                            child: ListTile(
                            dense: true,
                            selected: _selected.contains(_trackKey(t)),
                            leading: _selecting
                                ? Checkbox(
                                    value: _selected.contains(_trackKey(t)),
                                    onChanged: (_) => _toggle(_trackKey(t)))
                                : RailArtwork(
                              url:           t.artworkUrl,
                              localFilePath: t.filePath,
                              formatHint:    t.formatExt,
                              platformName:  t.platformName,
                              size:          40,
                            ),
                            // Cet arbre montre des FICHIERS: un conteneur
                            // s'y nomme par son fichier, jamais par le titre
                            // de sa sous-chanson 0.
                            title: ScrollingText(
                                text: (t.subsongCount ?? 1) > 1
                                    ? t.containerName
                                    : t.displayTitle),
                            // En recherche le chemin situe la piste dans
                            // l'arbre; sinon le format suffit.
                            subtitle: Text(
                              q.isNotEmpty
                                  ? readableRelPath(rel, _albumNames)
                                  : (t.formatExt ?? '').toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: _selecting
                                ? () => _toggle(_trackKey(t))
                                : () => _playAll([t]),
                            onLongPress: () => _toggle(_trackKey(t)),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Ce que désigne une sélection du navigateur local, dans l'ordre de l'arbre:
/// les pistes cochées et TOUT le sous-arbre des dossiers cochés, sans doublon
/// (une piste cochée dans un dossier coché ne compte qu'une fois; les
/// sous-chansons d'un même fichier non plus — le routage par chemin les
/// redéplie). Clés: `dir:<préfixe relatif>` et `track:<chemin>`.
@visibleForTesting
List<T> expandLocalSelection<T>(
    List<(String, T)> subtree, Set<String> keys, String Function(T) pathOf) {
  final dirs = [
    for (final k in keys)
      if (k.startsWith('dir:')) k.substring(4),
  ];
  final seen = <String>{};
  return [
    for (final (rel, t) in subtree)
      if ((keys.contains('track:${pathOf(t)}') || dirs.any(rel.startsWith)) &&
          seen.add(pathOf(t)))
        t,
  ];
}
