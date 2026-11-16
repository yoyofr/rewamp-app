// Un dossier LIÉ, parcouru niveau par niveau depuis la table des noms
// (local_roots.dart) — pas depuis `tracks`: rien n'est en base avant qu'un
// fichier ne joue. Le champ du haut FILTRE le niveau quand il est court et
// CHERCHE dans tout l'arbre (nom + chemin) dès trois caractères.
//
// Jouer passe par le routage commun (`globalOpenLocalPaths`): dépliage des
// sous-chansons, feuille « quand l'entendre », filtrage du lot — tout ce que
// la ligne ne sait pas faire.
import 'tv_focus.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'app_snack.dart';
import 'artwork_image.dart' show ArtworkCache;
import 'cancel_field.dart';
import 'l10n.dart';
import 'local_browse_view.dart';
import 'local_db.dart';
import 'local_open.dart' show globalOpenLocalPaths;
import 'local_ops.dart' show LocalOpsBanner;
import 'local_roots.dart';
import 'portable_path.dart';
import 'radio_surprise_buttons.dart';
import 'scrolling_text.dart';
import 'play_start.dart';

class LinkedRootScreen extends StatefulWidget {
  final String rootId;

  /// '' = la racine, sinon terminé par '/'.
  final String relDir;

  const LinkedRootScreen({super.key, required this.rootId, this.relDir = ''});

  @override
  State<LinkedRootScreen> createState() => _LinkedRootScreenState();
}

class _LinkedRootScreenState extends State<LinkedRootScreen> {
  final _filterCtrl = TextEditingController();
  String _query = '';
  bool _loading = true;
  Map<String, int> _folders = const {};
  List<LinkedEntry> _files = const [];
  List<LinkedEntry>? _search; // non nul = résultats de recherche affichés
  Map<String, String> _folderArt = const {};
  Map<String, int> _folderMtimes = const {};
  LocalBrowseOrder _order = LocalBrowseOrder.read();

  LocalRoot? get _root => LocalRoots.instance.byId(widget.rootId);

  @override
  void initState() {
    super.initState();
    _load();
    LocalDb.instance.addListener(_load);
    LocalRoots.instance.addListener(_onRoots);
    // Le niveau vient d'un INSTANTANÉ (la table des noms): on le remet à jour
    // en ouvrant, puis on SURVEILLE le dossier affiché tant que l'écran est
    // là (bureau) — un fichier qui arrive dans ~/Downloads apparaît seul.
    LocalRoots.instance.refresh(widget.rootId, minGap: const Duration(seconds: 5));
    _watch();
  }

  StreamSubscription<FileSystemEvent>? _watchSub;
  Timer? _watchDebounce;

  void _watch() {
    final root = _root;
    if (root == null || !root.available || root.kind == LocalRootKind.saf) return;
    if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) return;
    try {
      _watchSub = Directory(joinPortable(root.path, widget.relDir))
          .watch()
          .listen((_) {
        _watchDebounce?.cancel();
        _watchDebounce = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) {
            LocalRoots.instance.refresh(widget.rootId, minGap: Duration.zero);
          }
        });
      }, onError: (_) {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    _watchDebounce?.cancel();
    LocalDb.instance.removeListener(_load);
    LocalRoots.instance.removeListener(_onRoots);
    _filterCtrl.dispose();
    super.dispose();
  }

  void _onRoots() {
    if (!mounted) return;
    if (_root == null) {
      Navigator.of(context).pop(); // déliée pendant qu'on la regardait
      return;
    }
    setState(() {});
  }

  Future<void> _load() async {
    final (folders, files) =
        await LocalDb.instance.linkedEntriesUnder(widget.rootId, widget.relDir);
    final mtimes =
        await LocalDb.instance.linkedFolderMtimes(widget.rootId, widget.relDir);
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _folderMtimes = mtimes;
      _files = files;
      _loading = false;
    });
    _loadFolderArt();
  }

  /// La pochette de chaque sous-dossier (règles génériques, voir
  /// ArtworkCache.findFolderArtwork), après l'affichage.
  Future<void> _loadFolderArt() async {
    final root = _root;
    if (root == null || !root.available) return;
    final base = joinPortable(root.path, widget.relDir);
    final art = <String, String>{};
    await Future.wait([
      for (final n in _folders.keys)
        ArtworkCache.instance.findFolderArtwork(p.join(base, n)).then((a) {
          if (a != null) art[n] = a;
        }),
    ]);
    if (!mounted || mapEquals(art, _folderArt)) return;
    setState(() => _folderArt = art);
  }

  Future<void> _onFilterChanged(String v) async {
    _query = v.trim();
    if (_query.length < 3) {
      setState(() => _search = null);
      return;
    }
    final q = _query;
    final res = await LocalDb.instance
        .searchLinkedEntries(q, rootId: widget.rootId, limit: 300);
    if (!mounted || q != _query) return;
    setState(() => _search = res);
  }

  Future<void> _play(Iterable<LinkedEntry> entries) async {
    final roots = LocalRoots.instance;
    // iOS: un fichier iCloud pas encore descendu l'est ICI, avant la lecture.
    final paths = await roots
        .materialize([for (final e in entries) roots.absolutePathOf(e)]);
    if (paths.isEmpty) return;
    globalOpenLocalPaths?.call(paths);
  }

  Future<void> _playAllHere() async {
    final all =
        await LocalDb.instance.linkedSubtree(widget.rootId, widget.relDir);
    _play(all);
  }

  Future<void> _playShuffledHere() async {
    final all =
        await LocalDb.instance.linkedSubtree(widget.rootId, widget.relDir);
    _play(all..shuffle(Random()));
  }

  Future<void> _surpriseHere() async {
    final all =
        await LocalDb.instance.linkedSubtree(widget.rootId, widget.relDir);
    if (all.isEmpty) return;
    _play([all[Random().nextInt(all.length)]]);
  }

  Future<void> _rename() async {
    final root = _root;
    if (root == null) return;
    final l10n = context.l10n;
    final ctrl = TextEditingController(text: root.label);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.linkedRootRename),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text(l10n.commonOk)),
        ],
      ),
    );
    if (name != null) await LocalRoots.instance.rename(root.id, name);
  }

  Future<void> _unlink() async {
    final root = _root;
    if (root == null) return;
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.linkedRootUnlinkConfirmTitle),
        content: Text(l10n.linkedRootUnlinkConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.linkedRootUnlink)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await LocalRoots.instance.unlink(root.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final root = _root;
    final isAppFolder = LocalRoots.instance.isAppFolder(widget.rootId);
    final title = widget.relDir.isEmpty
        ? (isAppFolder ? l10n.linkedRootAppFolder : (root?.label ?? ''))
        : p.basename(widget.relDir.substring(0, widget.relDir.length - 1));
    final searching = _search != null;
    final o = _order;
    // Le niveau se trie selon le réglage (nom / date, sens); des RÉSULTATS de
    // recherche gardent leur classement de pertinence.
    final folderNames = sortLocalEntries(_folders.keys,
        name: (n) => n, mtime: (n) => _folderMtimes[n],
        sort: o.sort, ascending: o.ascending);
    final levelFiles = sortLocalEntries(_files,
        name: (e) => e.name, mtime: (e) => e.mtimeMs,
        sort: o.sort, ascending: o.ascending);
    final shownFiles = searching
        ? _search!
        : (_query.isEmpty
            ? levelFiles
            : [
                for (final f in levelFiles)
                  if (f.name.toLowerCase().contains(_query.toLowerCase())) f,
              ]);
    final shownFolders = searching
        ? const <String>[]
        : (_query.isEmpty
            ? folderNames
            : [
                for (final n in folderNames)
                  if (n.toLowerCase().contains(_query.toLowerCase())) n,
              ]);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          LocalBrowseActions(
              order: _order, onChanged: (o) => setState(() => _order = o)),
          if (widget.relDir.isEmpty && root != null && isAppFolder)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.linkedRootRescan,
              onPressed: LocalRoots.instance.isScanning(root.id)
                  ? null
                  : () => LocalRoots.instance.scan(root.id),
            ),
          if (widget.relDir.isEmpty && root != null && !isAppFolder)
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'rescan':
                    LocalRoots.instance.scan(root.id);
                  case 'rename':
                    _rename();
                  case 'unlink':
                    _unlink();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'rescan',
                  enabled: !LocalRoots.instance.isScanning(root.id),
                  child: Text(l10n.linkedRootRescan),
                ),
                PopupMenuItem(
                    value: 'rename', child: Text(l10n.linkedRootRename)),
                PopupMenuItem(
                    value: 'unlink', child: Text(l10n.linkedRootUnlink)),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          const LocalOpsBanner(),
          if (root != null && !root.available)
            MaterialBanner(
              content: Text(l10n.linkedRootUnavailable),
              leading: const Icon(Icons.link_off),
              actions: [
                TextButton(
                  onPressed: () => LocalRoots.instance.scan(root.id),
                  child: Text(l10n.linkedRootRescan),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 4),
            child: CancelField(
              controller: _filterCtrl,
              onCleared: _onFilterChanged,
              builder: (_) => TvGatedText(builder: (tvNode, tvReadOnly) => TextField(
              focusNode: tvNode,
              readOnly: tvReadOnly,
                controller: _filterCtrl,
                decoration: InputDecoration(
                  hintText: l10n.linkedRootSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: _onFilterChanged,
              )),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    searching
                        ? l10n.linkedRootSearchResults(shownFiles.length)
                        : l10n.albumTrackCount(shownFiles.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                RadioSurpriseButtons(
                  onPlayAll: searching
                      ? (shownFiles.isEmpty ? null : () => _play(shownFiles))
                      : _playAllHere,
                  onRadio: searching
                      ? (shownFiles.isEmpty
                          ? null
                          : () => _play(List.of(shownFiles)..shuffle(Random())))
                      : _playShuffledHere,
                  onSurprise: searching
                      ? (shownFiles.isEmpty
                          ? null
                          : () => _play([
                                shownFiles[Random().nextInt(shownFiles.length)]
                              ]))
                      : _surpriseHere,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (shownFolders.isEmpty && shownFiles.isEmpty)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            searching
                                ? l10n.linkedRootSearchResults(0)
                                // Le dossier de l'app vide: dire OÙ déposer —
                                // c'est le seul endroit où on peut l'apprendre.
                                : (isAppFolder
                                    ? l10n.linkedRootAppFolderHint
                                    : l10n.linkedRootEmpty),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      )
                    : o.isGrid
                        ? GridView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                            gridDelegate: localGridDelegate(o.view),
                            itemCount: shownFolders.length + shownFiles.length,
                            itemBuilder: (ctx, i) => i < shownFolders.length
                                ? LocalGridTile(
                                    art: LocalFolderArt(
                                        art: _folderArt[shownFolders[i]]),
                                    title: shownFolders[i],
                                    subtitle: l10n.albumTrackCount(
                                        _folders[shownFolders[i]] ?? 0),
                                    onTap: () => _openFolder(ctx, shownFolders[i]),
                                  )
                                : _fileGridTile(ctx,
                                    shownFiles[i - shownFolders.length], root),
                          )
                        : ListView.builder(
                        itemCount: shownFolders.length + shownFiles.length,
                        itemBuilder: (ctx, i) {
                          if (i < shownFolders.length) {
                            final name = shownFolders[i];
                            return ListTile(
                              dense: true,
                              leading: _folderLeading(_folderArt[name], cs),
                              title: ScrollingText(text: name),
                              subtitle: Text(
                                  l10n.albumTrackCount(_folders[name] ?? 0),
                                  style:
                                      TextStyle(color: cs.onSurfaceVariant)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openFolder(ctx, name),
                            );
                          }
                          final e = shownFiles[i - shownFolders.length];
                          // Sous recherche, le chemin dit OÙ est le fichier;
                          // au niveau courant, tout est au même endroit.
                          final dir = searching
                              ? p.posix.dirname(e.relPath)
                              : null;
                          return PlayChoiceHold.tile(ListTile(
                            dense: true,
                            leading: root != null && root.available
                                ? _FileArt(
                                    key: ValueKey(e.relPath),
                                    path: LocalRoots.instance.absolutePathOf(e))
                                : const Icon(Icons.music_note_outlined),
                            title: ScrollingText(text: e.name),
                            subtitle: dir != null && dir != '.'
                                ? ScrollingText(
                                    text: dir,
                                    style: TextStyle(color: cs.onSurfaceVariant))
                                : null,
                            onTap: () => _tapFile(ctx, e, root),
                          ));
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _openFolder(BuildContext ctx, String name) => Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          builder: (_) => LinkedRootScreen(
            rootId: widget.rootId,
            relDir: '${widget.relDir}$name/',
          ),
        ),
      );

  void _tapFile(BuildContext ctx, LinkedEntry e, LocalRoot? root) {
    if (root != null && !root.available) {
      AppSnack.show(ctx, ctx.l10n.linkedRootUnavailable);
      return;
    }
    _play([e]);
  }

  Widget _fileGridTile(BuildContext ctx, LinkedEntry e, LocalRoot? root) {
    final cs = Theme.of(ctx).colorScheme;
    final glyph = Container(
      decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8)),
      child: Icon(Icons.music_note_outlined, size: 40, color: cs.onSurfaceVariant),
    );
    return PlayChoiceHold(
      onTap: () => _tapFile(ctx, e, root),
      child: LocalGridTile(
        art: root != null && root.available
            ? _FileArt(
                key: ValueKey(e.relPath),
                path: LocalRoots.instance.absolutePathOf(e),
                fill: true,
                placeholder: glyph)
            : glyph,
        title: e.name,
        onTap: () => _tapFile(ctx, e, root),
      ),
    );
  }

  Widget _folderLeading(String? art, ColorScheme cs) {
    const icon = Icon(Icons.folder_outlined);
    if (art == null) return icon;
    return SizedBox(
      width: 40,
      height: 40,
      child: ClipRRect(
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
    );
  }
}

/// Vignette d'un FICHIER lié: l'image posée à côté de lui (même nom, ou
/// pochette du dossier — les règles de ArtworkCache.findLocalArtwork, celles
/// de la bibliothèque), résolue après l'affichage; sinon la note. Rien n'est
/// lu dans le fichier lui-même (un parcours, pas un import).
class _FileArt extends StatefulWidget {
  const _FileArt(
      {super.key, required this.path, this.fill = false, this.placeholder});
  final String path;

  /// Vue icônes: remplit la tuile (carrée) au lieu des 40 px d'une ligne.
  final bool fill;
  final Widget? placeholder;

  @override
  State<_FileArt> createState() => _FileArtState();
}

class _FileArtState extends State<_FileArt> {
  String? _art;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_FileArt old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _art = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final path = widget.path;
    final a = await ArtworkCache.instance.findLocalArtwork(path);
    if (mounted && path == widget.path && a != _art) setState(() => _art = a);
  }

  @override
  Widget build(BuildContext context) {
    final Widget icon = widget.placeholder ?? const Icon(Icons.music_note_outlined);
    final art = _art;
    if (art == null) return icon;
    if (widget.fill) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(art),
            fit: BoxFit.cover,
            cacheWidth: 300,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => icon),
      );
    }
    return SizedBox(
      width: 40,
      height: 40,
      child: ClipRRect(
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
    );
  }
}
