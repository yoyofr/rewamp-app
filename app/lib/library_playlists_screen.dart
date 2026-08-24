import 'package:flutter/material.dart';
import 'package:rewamp_audio/rewamp_audio.dart' show RewampAudio;
import 'artwork_image.dart';
import 'library_toolbar.dart';
import 'local_db.dart';
import 'l10n.dart';
import 'playlist_options.dart';
import 'sync_service.dart';
import 'rewamp_db.dart'
    show OnPlayAlbum, OnPlayLocalAlbum, Playlist, RewampDb, SearchResult;
import 'browse_screen.dart' show PlaylistTracksScreen;
import 'local_playlist_screen.dart';
import 'shell_insets.dart';

typedef OnFileReady = void Function(
  String path,
  String label, {
  String? artist,
  String? album,
  String? albumId,
  String? formatExt,
  String? onlineId,
  String? artworkUrl,
  String? artworkTargetDir,
  int subsongIdx,
  double? durationS,
  int? subsongCount,
});

class LibraryPlaylistsScreen extends StatefulWidget {
  final OnFileReady? onPlayTrack;
  /// Online play path (download-and-play) for server-playlist tracks.
  final Future<void> Function(BuildContext, SearchResult)? onPlayOnline;
  final OnPlayAlbum? onPlayAlbum;
  /// Local queue play (favourites / user playlists "Tout lire").
  final OnPlayLocalAlbum? onPlayLocalAlbum;
  /// Folder being browsed (null = racine).
  final PlaylistFolder? folder;

  const LibraryPlaylistsScreen(
      {super.key, this.onPlayTrack, this.onPlayOnline, this.onPlayAlbum,
       this.onPlayLocalAlbum, this.folder});

  @override
  State<LibraryPlaylistsScreen> createState() => _LibraryPlaylistsScreenState();
}

class _LibraryPlaylistsScreenState extends State<LibraryPlaylistsScreen> {
  final _searchCtrl = TextEditingController();
  List<UserPlaylist>   _playlists = [];
  List<PlaylistFolder> _folders   = [];
  List<PlaylistFolder> _allFolders = []; // every folder (for the move picker)
  List<LibraryItem>    _serverPlaylists = [];
  int _favCount = 0;
  bool _loading = true;
  // Mini-thumbnail source per playlist id (first track's artwork), + Favoris.
  Map<String, ({String? url, String? filePath})> _artworks = {};
  String? _favArtworkUrl;
  String _orderBy = 'name'; // 'name' | 'recent' | 'created'
  /// Sens du tri. Il manquait: choisir « Nom » sans pouvoir l'inverser laisse
  /// la moitié du classement hors de portée.
  bool _asc = true;
  bool _dragging = false;   // a playlist is being dragged (shows drop targets)

  // ── Publication state (migrations 192/193) ────────────────────────────────
  // Review status lives ONLY server-side, so it is fetched once here and after
  // every publish/withdraw — not in _load(), which re-runs on every local DB
  // change (a rename, a track added) and would turn each of them into a request.
  Map<String, Playlist> _reviewByServerId = const {};
  String? _displayName;

  int get _pendingReviews =>
      _reviewByServerId.values.where((p) => p.isPendingReview).length;

  /// Review status of a local playlist, via its server copy. null = never
  /// pushed, or the server does not know about publication (older build).
  Playlist? _review(UserPlaylist p) {
    final sid = p.serverId;
    if (sid == null || sid.isEmpty) return null;
    return _reviewByServerId[sid];
  }

  bool _isPrivate(Playlist p) =>
      !p.isPendingReview && !p.isApproved && !p.isReviewRejected;

  /// The one line that says where a playlist stands with the operator. A refusal
  /// carries its reason (the server returns it to the owner only) — without it
  /// the author has nothing to fix.
  Widget _reviewBadge(Playlist review) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final (IconData icon, String label, Color color) = review.isApproved
        ? (Icons.public, l10n.playlistPublishApproved, cs.primary)
        : review.isPendingReview
            ? (Icons.hourglass_top, l10n.playlistPublishPending,
                cs.onSurfaceVariant)
            : (Icons.report_gmailerrorred_outlined,
                (review.reviewNote ?? '').isEmpty
                    ? l10n.playlistPublishRejectedShort
                    : l10n.playlistPublishRejected(review.reviewNote!),
                cs.error);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 12)),
        ),
      ]),
    );
  }

  Future<void> _loadPublicState() async {
    final (reviews, name) = await PlaylistOptions.fetchPublicState();
    if (!mounted) return;
    setState(() {
      _reviewByServerId = reviews;
      _displayName = name;
    });
  }

  bool get _root => widget.folder == null;
  bool get _searching => _searchCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    LocalDb.instance.addListener(_reload);
    // A review is DECIDED on the server, silently: the operator approves a
    // playlist and this device learns nothing — the badge stayed on "pending"
    // until the screen was rebuilt. Publication state never touches the local
    // database, so the LocalDb listener above cannot see it either. Refresh at
    // the end of every account sync, which is the moment the device is talking
    // to the server anyway.
    SyncService.instance.addListener(_onSyncChanged);
    _reload();
    _loadPublicState();
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_reload);
    SyncService.instance.removeListener(_onSyncChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _syncWasRunning = false;

  void _onSyncChanged() {
    final running = SyncService.instance.isRunning;
    // Only on the falling edge: the notifier fires at both ends of a run, and
    // refreshing at the start would read the state the run is about to change.
    if (running) {
      _syncWasRunning = true;
      return;
    }
    if (!_syncWasRunning) return;
    _syncWasRunning = false;
    _loadPublicState();
  }

  void _reload() => _load();

  Future<void> _load() async {
    // Searching: flat global list. Otherwise: this folder's contents.
    final playlists = await LocalDb.instance.getPlaylistsFiltered(
      folderId: widget.folder?.id,
      scoped:   !_searching,
      query:    _searching ? _searchCtrl.text : null,
      orderBy:  _orderBy,
    );
    // Le SENS s'applique ici plutôt que dans la requête: `getPlaylistsFiltered`
    // n'expose qu'un champ, et inverser une liste déjà triée donne exactement
    // le même ordre que l'ORDER BY inverse.
    final ordered = _asc ? playlists : playlists.reversed.toList();
    final folders = _searching
        ? <PlaylistFolder>[]
        : await LocalDb.instance.getPlaylistFolders(parentId: widget.folder?.id);
    final favs   = _root ? await LocalDb.instance.getFavorites() : const <TrackRecord>[];
    // Saved server playlists now live in folders too — scope to this folder.
    var server = _searching
        ? const <LibraryItem>[]
        : await LocalDb.instance.getLibraryItems(
            type: 'playlist', folderId: widget.folder?.id, scoped: true);
    // Les playlists ENREGISTRÉES suivent le même tri que celles de l'utilisateur
    // — elles se mélangent dans la même liste, deux ordres y seraient illisibles.
    server = sortLibraryItems(
        server,
        switch (_orderBy) {
          'name' => LibrarySort.name,
          _      => LibrarySort.added,   // récent / création: la date d'ajout
        },
        _orderBy == 'name' ? _asc : !_asc);
    final artworks = <String, ({String? url, String? filePath})>{};
    for (final pl in playlists) {
      artworks[pl.id] = await LocalDb.instance.getPlaylistArtworkSource(pl.id);
    }
    final favArt = _root ? await LocalDb.instance.getFavoritesArtworkUrl() : null;
    final allFolders = await LocalDb.instance.getAllPlaylistFolders();
    if (!mounted) return;
    setState(() {
      _favCount        = favs.length;
      _playlists       = ordered;
      _folders         = folders;
      _allFolders      = allFolders;
      _serverPlaylists = server;
      _artworks        = artworks;
      _favArtworkUrl   = favArt;
      _loading         = false;
    });
  }

  /// 40×40 rounded thumbnail for a list tile; falls back to the given icon
  /// avatar when the playlist has no resolvable artwork.
  Widget _thumb({String? url, String? filePath, required Widget fallback}) {
    if ((url == null || url.isEmpty) && (filePath == null || filePath.isEmpty)) {
      return fallback;
    }
    return SizedBox(
      width: 40, height: 40,
      child: ArtworkImage(
        url:           url,
        localFilePath: filePath,
        size:          40,
        borderRadius:  BorderRadius.circular(6),
        placeholder:   fallback,
      ),
    );
  }

  Future<String?> _promptName(String title, {String? initial}) =>
      promptName(context, title, initial: initial);

  Future<void> _create() async {
    final l10n = context.l10n;
    final kind = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: Text(l10n.playlistNew),
            onTap: () => Navigator.pop(ctx, 'playlist'),
          ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text(l10n.playlistNewFolder),
            onTap: () => Navigator.pop(ctx, 'folder'),
          ),
        ]),
      ),
    );
    if (kind == null || !mounted) return;
    final name = await _promptName(
        kind == 'folder' ? l10n.playlistNewFolder : l10n.playlistNew);
    if (name == null || name.isEmpty) return;
    if (kind == 'folder') {
      await LocalDb.instance
          .createPlaylistFolder(name, parentId: widget.folder?.id);
    } else {
      await LocalDb.instance.createPlaylist(name, folderId: widget.folder?.id);
    }
  }

  Future<bool> _confirm(String title, String body, {String? confirmLabel}) =>
      confirm(context, title, body, confirmLabel: confirmLabel);

  Future<({String? id})?> _pickFolder({String? currentId}) =>
      pickFolder(context, _allFolders, currentId: currentId);

  // ── Drag & drop: move a playlist into a folder ───────────────────────────
  Future<void> _movePlaylistData(_PlaylistDragData d, String? folderId) async {
    // Clear the drag state up-front: the move reloads the list (notifyListeners
    // → _reload), which disposes the in-flight Draggable so its onDragEnd never
    // fires — leaving the parent-folder banner stuck if we waited for it.
    if (mounted) setState(() => _dragging = false);
    if (d.isServer) {
      await LocalDb.instance.setLibraryItemFolder('playlist', d.id, folderId);
    } else {
      await LocalDb.instance.movePlaylistToFolder(d.id, folderId);
    }
  }

  Widget _dragFeedback(String name) => Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 240),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.drag_indicator, size: 18),
            const SizedBox(width: 6),
            Flexible(
                child: Text(name,
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      );

  /// Wraps a playlist [row] so a long-press starts a drag; dropping it on a
  /// folder (or the parent-folder banner) moves it there.
  Widget _draggablePlaylist(Widget row, _PlaylistDragData data, String name) {
    return LongPressDraggable<_PlaylistDragData>(
      data: data,
      onDragStarted: () => setState(() => _dragging = true),
      onDragEnd: (_) => setState(() => _dragging = false),
      onDraggableCanceled: (_, __) => setState(() => _dragging = false),
      feedback: _dragFeedback(name),
      childWhenDragging: Opacity(opacity: 0.4, child: row),
      child: row,
    );
  }

  /// The playlist "…" menu — shared with the playlist's own screen, so both
  /// offer exactly the same actions (see [PlaylistOptions]). The review state
  /// is handed over rather than re-fetched: this screen already holds it for
  /// the badges, and publication is the one thing no local listener reports.
  Future<void> _playlistOptions(UserPlaylist p) => PlaylistOptions.show(
        context,
        playlist:       p,
        review:         _review(p),
        displayName:    _displayName,
        pendingReviews: _pendingReviews,
        folders:        _allFolders,
        onChanged:      _loadPublicState,
      );

  Future<void> _folderOptions(PlaylistFolder f) async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.commonRename),
            onTap: () => Navigator.pop(ctx, 'rename'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l10n.commonDelete),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'rename') {
      final name =
          await _promptName(l10n.playlistRenameFolderTitle, initial: f.name);
      if (name != null && name.isNotEmpty) {
        await LocalDb.instance.renamePlaylistFolder(f.id, name);
      }
    } else if (action == 'delete') {
      // Recursive delete: a non-empty folder needs an explicit confirmation
      // that spells out how much (playlists + sub-folders across the whole
      // subtree) is about to be permanently removed.
      final (folders, playlists) =
          await LocalDb.instance.countFolderContents(f.id);
      if (!mounted) return;
      final String body;
      if (folders == 0 && playlists == 0) {
        body = l10n.playlistDeleteFolderEmptyBody;
      } else {
        final parts = <String>[l10n.playlistDeleteFolderContentsHeader];
        if (playlists > 0) {
          parts.add('• ${l10n.playlistFolderPlaylistCount(playlists)}');
        }
        if (folders > 0) {
          parts.add('• ${l10n.playlistFolderSubfolderCount(folders)}');
        }
        body = parts.join('\n');
      }
      if (await _confirm(l10n.playlistDeleteFolderTitle(f.name), body)) {
        await LocalDb.instance.deletePlaylistFolderRecursive(f.id);
      }
    }
  }

  Future<void> _favoritesOptions() async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.delete_sweep_outlined,
                color: Theme.of(ctx).colorScheme.error),
            title: Text(l10n.playlistClearFavorites),
            onTap: () => Navigator.pop(ctx, 'clear'),
          ),
        ]),
      ),
    );
    if (!mounted || action != 'clear') return;
    if (await _confirm(
        l10n.playlistClearFavoritesTitle, l10n.playlistClearFavoritesBody)) {
      await LocalDb.instance.clearAllFavorites();
    }
  }

  Future<void> _serverPlaylistOptions(LibraryItem item) async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_allFolders.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: Text(l10n.playlistMoveToFolder),
              onTap: () => Navigator.pop(ctx, 'move'),
            ),
          ListTile(
            leading: const Icon(Icons.bookmark_remove_outlined),
            title: Text(l10n.playlistRemoveFromLibrary),
            onTap: () => Navigator.pop(ctx, 'remove'),
          ),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'move') {
      final dest = await _pickFolder(currentId: item.folderId);
      if (dest != null) {
        await LocalDb.instance
            .setLibraryItemFolder('playlist', item.refId, dest.id);
      }
    } else if (action == 'remove') {
      await LocalDb.instance.removeFromLibrary('playlist', item.refId);
      // Le compte doit l'apprendre, sinon la playlist REVIENT: la photo
      // d'identités la contient toujours et `syncLibraryPlaylists` ne fait
      // qu'ajouter. Même famille que les morceaux retirés localement sans
      // rien envoyer (voir SyncService.recordTrackMembership).
      await SyncService.recordLibraryChange(
          itemType: 'playlist', itemId: item.refId, value: false);
    }
  }

  void _openFolder(PlaylistFolder f) {
    Navigator.push<void>(context, MaterialPageRoute(
      builder: (_) => LibraryPlaylistsScreen(
        onPlayTrack:      widget.onPlayTrack,
        onPlayOnline:     widget.onPlayOnline,
        onPlayAlbum:      widget.onPlayAlbum,
        onPlayLocalAlbum: widget.onPlayLocalAlbum,
        folder:           f,
      ),
    ));
  }

  void _openPlaylist(UserPlaylist p) {
    Navigator.push<void>(context, MaterialPageRoute(
      builder: (_) => LocalPlaylistScreen(
        playlist:         p,
        onPlayLocalAlbum: widget.onPlayLocalAlbum,
        onPlayOnline:     widget.onPlayOnline,
      ),
    ));
  }

  void _openServerPlaylist(LibraryItem item) {
    if (widget.onPlayOnline == null) return;
    Navigator.push<void>(context, MaterialPageRoute(
      builder: (_) => PlaylistTracksScreen(
        playlist: Playlist(
          id:       item.refId,
          slug:     item.filename ?? '',
          name:     item.name,
          coverUrl: item.artworkUrl,
        ),
        onTap:       widget.onPlayOnline!,
        onPlayAlbum: widget.onPlayAlbum,
      ),
    ));
  }

  void _openFavorites(BuildContext ctx) {
    Navigator.push<void>(ctx, MaterialPageRoute(
      builder: (_) => _FavoritesPlaylistScreen(
          onPlayTrack: widget.onPlayTrack,
          onPlayLocalAlbum: widget.onPlayLocalAlbum),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder?.name ?? l10n.libraryPlaylists),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: l10n.commonSort,
            onSelected: (v) {
              if (v == 'asc' || v == 'desc') {
                _asc = v == 'asc';
              } else {
                _orderBy = v;
              }
              _load();
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                  value: 'name',
                  checked: _orderBy == 'name',
                  child: Text(l10n.sortName)),
              CheckedPopupMenuItem(
                  value: 'recent',
                  checked: _orderBy == 'recent',
                  child: Text(l10n.sortRecentlyModified)),
              CheckedPopupMenuItem(
                  value: 'created',
                  checked: _orderBy == 'created',
                  child: Text(l10n.sortCreationDate)),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(
                  value: 'asc',
                  checked: _asc,
                  child: Text(l10n.searchSortAsc)),
              CheckedPopupMenuItem(
                  value: 'desc',
                  checked: !_asc,
                  child: Text(l10n.searchSortDesc)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.playlistNewTooltip,
            onPressed: _create,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: shellInset(context, const EdgeInsets.fromLTRB(16, 8, 16, 4)),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: l10n.playlistSearchHint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searching
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _load();
                              })
                          : null,
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => _load(),
                  ),
                ),
                // While dragging inside a folder, a banner to drop the playlist
                // up into the parent folder (or root).
                if (_dragging && !_root)
                  DragTarget<_PlaylistDragData>(
                    onWillAcceptWithDetails: (_) => true,
                    onAcceptWithDetails: (d) =>
                        _movePlaylistData(d.data, widget.folder!.parentId),
                    builder: (ctx, cand, rej) => Container(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: cand.isNotEmpty
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.drive_folder_upload_outlined,
                              size: 20),
                          const SizedBox(width: 8),
                          Text(l10n.playlistMoveUp),
                        ],
                      ),
                    ),
                  ),
                if (_root && !_searching)
                  ListTile(
                    leading: _thumb(
                      url: _favArtworkUrl,
                      fallback: CircleAvatar(
                        backgroundColor: cs.errorContainer,
                        child: Icon(Icons.star, color: cs.error, size: 20),
                      ),
                    ),
                    title: Text(l10n.libraryFavorites),
                    subtitle: Text(l10n.playlistTrackCount(_favCount)),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      tooltip: l10n.navMore,
                      onPressed: _favCount == 0 ? null : _favoritesOptions,
                    ),
                    onTap: () => _openFavorites(context),
                  ),
                for (final f in _folders)
                  DragTarget<_PlaylistDragData>(
                    onWillAcceptWithDetails: (_) => true,
                    onAcceptWithDetails: (d) =>
                        _movePlaylistData(d.data, f.id),
                    builder: (ctx, cand, rej) => Material(
                      color: cand.isNotEmpty
                          ? cs.primaryContainer.withValues(alpha: 0.5)
                          : Colors.transparent,
                      child: ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(f.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          tooltip: l10n.navMore,
                          onPressed: () => _folderOptions(f),
                        ),
                        onTap: () => _openFolder(f),
                      ),
                    ),
                  ),
                ..._playlists.map((p) {
                  final review = _review(p);
                  final row = ListTile(
                    leading: _thumb(
                      url:      _artworks[p.id]?.url,
                      filePath: _artworks[p.id]?.filePath,
                      fallback: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Icon(Icons.queue_music,
                            color: cs.primary, size: 20),
                      ),
                    ),
                    title: Text(p.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Backed up in the account — the mark says it
                            // survives this install, nothing else.
                            if (p.isSynced) ...[
                              Icon(Icons.cloud_done_outlined,
                                  size: 13, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(l10n.playlistTrackCount(p.trackCount),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        if (review != null && !_isPrivate(review))
                          _reviewBadge(review),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      tooltip: l10n.navMore,
                      onPressed: () => _playlistOptions(p),
                    ),
                    onTap: () => _openPlaylist(p),
                  );
                  // Long-press drags (options live under the "…" button now).
                  return _draggablePlaylist(
                      row, _PlaylistDragData(false, p.id), p.name);
                }),
                // Server playlists saved from search / facet browser.
                if (!_searching)
                  ..._serverPlaylists.map((p) {
                    final row = ListTile(
                      leading: _thumb(
                        url: p.artworkUrl,
                        fallback: CircleAvatar(
                          backgroundColor: cs.primaryContainer,
                          child: Icon(Icons.playlist_play,
                              color: cs.primary, size: 20),
                        ),
                      ),
                      title: Text(p.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      // A saved server playlist is read-only (no rename/delete/
                      // reorder) — the server icon + message keeps it distinct
                      // from an editable local playlist.
                      subtitle: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_outlined,
                              size: 13, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                                [
                                  p.playlistCount != null
                                      ? l10n.playlistTrackCount(p.playlistCount!)
                                      : l10n.playlistServerReadOnly,
                                  // Author of a published USER playlist, stashed
                                  // in `artist` when the playlist was saved (see
                                  // PlaylistSync.syncLibraryPlaylists). Absent on
                                  // a server playlist, and on rows saved before
                                  // this was stored — it fills in on the next
                                  // save, nothing to migrate.
                                  if ((p.artist ?? '').isNotEmpty)
                                    l10n.playlistByAuthor(p.artist!),
                                ].join('  ·  '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: cs.onSurfaceVariant, fontSize: 12)),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert),
                        tooltip: l10n.navMore,
                        onPressed: () => _serverPlaylistOptions(p),
                      ),
                      onTap: () => _openServerPlaylist(p),
                    );
                    return _draggablePlaylist(
                        row, _PlaylistDragData(true, p.refId), p.name);
                  }),
              ],
            ),
    );
  }
}

/// Drag payload for moving a playlist into a folder. [id] is the local
/// playlist id, or the server playlist's ref_id when [isServer].
class _PlaylistDragData {
  final bool isServer;
  final String id;
  const _PlaylistDragData(this.isServer, this.id);
}

// ── Favorites auto-playlist ───────────────────────────────────────────────────

class _FavoritesPlaylistScreen extends StatefulWidget {
  final OnFileReady? onPlayTrack;
  final OnPlayLocalAlbum? onPlayLocalAlbum;
  const _FavoritesPlaylistScreen({this.onPlayTrack, this.onPlayLocalAlbum});

  @override
  State<_FavoritesPlaylistScreen> createState() =>
      _FavoritesPlaylistScreenState();
}

class _FavoritesPlaylistScreenState extends State<_FavoritesPlaylistScreen> {
  List<TrackRecord> _tracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    LocalDb.instance.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    LocalDb.instance
        .getFavorites(
            probeSubsongCount: (fp) => RewampAudio().probeSubsongCount(fp))
        .then((t) {
      if (mounted) setState(() { _tracks = t; _loading = false; });
      _enrichTitles(t);
    });
  }

  /// Replaces the numbered placeholder titles of SYNTHESIZED entries (whole-
  /// file / container-album favourites whose subsongs were never played — no
  /// DB row, id == '') with the real titles: server album tracklist (jw JSONB)
  /// → SID STIL (get_sid_info) → native container probe (NSFe & co).
  Future<void> _enrichTitles(List<TrackRecord> tracks) async {
    final byFile = <String, List<int>>{};
    for (var i = 0; i < tracks.length; i++) {
      if (tracks[i].id.isEmpty) {
        byFile.putIfAbsent(tracks[i].filePath, () => []).add(i);
      }
    }
    if (byFile.isEmpty) return;

    final out = List<TrackRecord>.of(tracks);
    var changed = false;
    for (final e in byFile.entries) {
      final fp     = e.key;
      final sample = tracks[e.value.first];
      final titles = <int, String>{};

      // 1. Server tracklist via the album id (jw containers: tracks JSONB).
      final aid = sample.albumId;
      if (aid != null && aid.isNotEmpty) {
        try {
          final rows =
              await RewampDb.albumTracks(albumId: aid, sortBy: 'position');
          if (rows.isNotEmpty) {
            for (final r in RewampDb.subsongRowsFromServer(rows.first)) {
              final t = r.title;
              if (t != null && t.isNotEmpty) titles[r.subsongIdx] = t;
            }
          }
        } catch (_) {}
      }
      // 2. SID: per-subsong STIL titles by file md5.
      final ext = fp.split('.').last.toLowerCase();
      if (titles.isEmpty &&
          const {'sid', 'psid', 'rsid', 'mus'}.contains(ext)) {
        try {
          final md5 = RewampAudio().sidMd5(fp);
          final info = md5.isEmpty ? null : await RewampDb.getSidInfo(md5);
          if (info != null) {
            for (final i in e.value) {
              final t = info.perSubsongNameFor(tracks[i].subsongIdx);
              if (t != null && t.isNotEmpty) titles[tracks[i].subsongIdx] = t;
            }
          }
        } catch (_) {}
      }
      // 3. Native probe (NSFe track names, …).
      if (titles.isEmpty) {
        try {
          for (final sub in await RewampDb.probeContainerFile(fp)) {
            final t = sub.title;
            if (t != null && t.isNotEmpty) titles[sub.subsongIdx] = t;
          }
        } catch (_) {}
      }
      if (titles.isEmpty) continue;

      for (final i in e.value) {
        final t = out[i];
        final title = titles[t.subsongIdx];
        if (title == null || title == t.title) continue;
        out[i] = TrackRecord(
          id:         t.id,
          filePath:   t.filePath,
          entryPath:  t.entryPath,
          subsongIdx: t.subsongIdx,
          title:      title,
          artist:     t.artist,
          metaAlbum:  t.metaAlbum,
          albumId:    t.albumId,
          position:   t.position,
          durationS:  t.durationS,
          formatExt:  t.formatExt,
          source:     t.source,
          onlineId:   t.onlineId,
          artworkUrl: t.artworkUrl,
          isFavorite: t.isFavorite,
          inLibrary:  t.inLibrary,
          playCount:  t.playCount,
        );
        changed = true;
      }
    }
    if (changed && mounted) setState(() => _tracks = out);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.star, color: cs.error, size: 20),
          const SizedBox(width: 8),
          Text(l10n.libraryFavorites),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tracks.isEmpty
              ? Center(child: Text(l10n.libraryEmpty,
                  style: TextStyle(color: cs.outline)))
              : Column(children: [
                  // Header: play the whole playlist + entry count.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(children: [
                      FilledButton.icon(
                        onPressed: widget.onPlayLocalAlbum == null
                            ? null
                            : () => widget.onPlayLocalAlbum!(
                                context, List.of(_tracks)),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(l10n.commonPlayAll),
                      ),
                      const Spacer(),
                      Text(
                        l10n.playlistTrackCount(_tracks.length),
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ]),
                  ),
                  Expanded(child: ListView.builder(
                  itemCount: _tracks.length,
                  itemBuilder: (_, i) {
                    final t = _tracks[i];
                    return ListTile(
                      leading: SizedBox(
                        width: 40, height: 40,
                        child: ArtworkImage(
                          url:           t.artworkUrl,
                          localFilePath: t.filePath,
                          size:          40,
                          borderRadius:  BorderRadius.circular(6),
                          placeholder:
                              Icon(Icons.music_note, color: cs.primary),
                        ),
                      ),
                      title: Text(t.displayTitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: t.artist != null
                          ? Text(t.artist!,
                              maxLines: 1, overflow: TextOverflow.ellipsis)
                          : null,
                      // Tapping an entry starts the WHOLE playlist as a
                      // queue, positioned on the tapped entry.
                      onTap: () {
                        if (widget.onPlayLocalAlbum != null) {
                          widget.onPlayLocalAlbum!(context, List.of(_tracks),
                              startIndex: i);
                        } else if (widget.onPlayTrack != null) {
                          widget.onPlayTrack!(
                            t.filePath,
                            t.displayTitle,
                            artist:     t.artist,
                            album:      t.metaAlbum,
                            albumId:    t.albumId,
                            formatExt:  t.formatExt,
                            onlineId:   t.onlineId,
                            artworkUrl: t.artworkUrl,
                            subsongIdx: t.subsongIdx,
                            durationS:  t.durationS,
                          );
                        }
                      },
                    );
                  },
                )),
              ]),
    );
  }
}
