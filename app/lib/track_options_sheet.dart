import 'dart:io';

import 'package:flutter/material.dart';
import 'app_snack.dart';

import 'favorite_color.dart';
import 'package:path/path.dart' as p;
import 'l10n.dart';
import 'local_db.dart';
import 'queue_position_icon.dart';
import 'player_controller.dart';
import 'note_markdown.dart';
import 'playlist_picker.dart';
import 'production_screen.dart';
import 'rewamp_db.dart';
import 'scrolling_text.dart';
import 'sync_service.dart';
import 'user_settings.dart';
import 'video_screen.dart';

typedef OnNavigateAlbum  = void Function(String albumName,
    {String? collection, String? platform, String? artworkUrl, String? albumId});
typedef OnNavigateArtist = void Function(String artistName,
    // artistId whenever known: homonym artists (two "Moby"s) share a name.
    {String? collection, String? artistId});
typedef OnNavigateTag    = void Function(String tagName, {String? category});
/// [tagId] whenever the caller has one — two groups can carry confusable
/// names, and the id is what get_group_details resolves first.
typedef OnOpenGroup      = void Function(String groupName, {String? tagId});
typedef OnQueueAdd      = Future<void> Function(SearchResult result,
    {required bool atEnd});
typedef OnAlbumQueueAdd = Future<void> Function(List<SearchResult> tracks,
    {required bool atEnd, bool silent});

/// Global queue hooks, set once by AppShell. Deep screens (facet browser,
/// party/playlist details, …) reach the sheet without the queue callbacks
/// threaded through their constructors; these fallbacks keep "Lire ensuite" /
/// "Ajouter à la fin" available everywhere.
OnQueueAdd?      globalOnQueueAdd;
OnAlbumQueueAdd? globalOnAlbumQueueAdd;
/// Play NOW, REPLACING the queue (the "Lire maintenant" of the "…" sheet and
/// the rail popups). Set once by AppShell — it goes through _startAlbumQueue
/// with AppShell's own long-lived context, because the sheet's context is
/// dead by the time the tap runs (popped), and _startAlbumQueue checks
/// ctx.mounted before playing.
Future<void> Function(SearchResult r)? globalOnPlayNowSong;
/// Queue-add for LOCAL rows (TrackRecord — already on disk, no download).
/// The rails resolve their entries into TrackRecords; _onQueueAdd only knows
/// SearchResult and would try to re-download. Set once by AppShell.
Future<void> Function(List<TrackRecord> tracks, {required bool atEnd})?
    globalOnLocalQueueAdd;
/// True when there is anything a queue insert could relate to: a non-empty
/// queue OR a track playing outside it (single-file plays empty the queue but
/// keep playing). Set once by AppShell. [showPlayChoiceSheet] consults it —
/// with nothing playing, "ensuite" and "à la fin" mean the same as "lire",
/// so the popup skips itself and answers "now".
bool Function()? globalQueueHasContent;
/// Endless "radio" station over a featured series (a year's games, …). Unlike
/// a play-all, this never resolves the whole pool: AppShell keeps a small
/// rolling window (a few tracks ahead, a few behind), refilled on every
/// advance. Set once by AppShell.
void Function(List<FeaturedSlot> pool)? globalOnStartFeaturedRadio;
/// Whole-list play (used by ContainerSubsongScreen's 'Lire tous les subsongs'
/// when the screen wasn't given an onPlayAll — e.g. reached from a list that
/// didn't thread onPlayAlbum). Set once by AppShell.
OnPlayAlbum?     globalOnPlayAlbum;
/// Cross-entity tag search (SearchScreen with initialTags). Fallback for
/// screens that reach an artist header without onNavigateTag threaded through
/// (browse artist lists, …). Set once by AppShell.
OnNavigateTag? globalOnNavigateTag;
/// Group screen (server migs 201/202). A `group` chip does NOT go through the
/// tag search: a group is an entity with its own profile, members and — above
/// all — its productions, which no tag query can list (a production carries no
/// tag, it is released BY a group). Set once by AppShell so the push lands on
/// the active tab navigator and the player is restored on the way back.
OnOpenGroup? globalOnOpenGroup;

/// Shows a modal bottom sheet with library + navigation + queue options for a
/// [SearchResult]. Pass null for callbacks that are unavailable in context.
Future<void> showTrackOptions(
  BuildContext     context,
  SearchResult     result, {
  OnNavigateAlbum?  onNavigateAlbum,
  OnNavigateArtist? onNavigateArtist,
  OnNavigateTag?    onNavigateTag,
  OnQueueAdd?       onQueueAdd,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: _TrackOptionsSheet(
          result:           result,
          onNavigateAlbum:  onNavigateAlbum,
          onNavigateArtist: onNavigateArtist,
          onNavigateTag:    onNavigateTag,
          onQueueAdd:       onQueueAdd ?? globalOnQueueAdd,
        ),
      ),
    ),
  );
}

class _TrackOptionsSheet extends StatefulWidget {
  final SearchResult       result;
  final OnNavigateAlbum?   onNavigateAlbum;
  final OnNavigateArtist?  onNavigateArtist;
  final OnNavigateTag?     onNavigateTag;
  final OnQueueAdd?        onQueueAdd;

  const _TrackOptionsSheet({
    required this.result,
    this.onNavigateAlbum,
    this.onNavigateArtist,
    this.onNavigateTag,
    this.onQueueAdd,
  });

  @override
  State<_TrackOptionsSheet> createState() => _TrackOptionsSheetState();
}

class _TrackOptionsSheetState extends State<_TrackOptionsSheet> {
  bool _inLibrary = false;
  bool _loading   = true;
  SongContext? _ctx; // song context (tags/year/rating) — rebound chips
  String? _cachedPath; // on-disk file when the track is downloaded

  SearchResult get r => widget.result;

  /// Canonical library_items key — ALWAYS subsong-scoped, matching
  /// PlayerController.libraryRefId, so this sheet and the player heart agree on
  /// the same row (they used to write two different keys for the same track).
  String get _libraryRefId => '${r.songId}?subsong=${r.subsongIdx}';

  @override
  void initState() {
    super.initState();
    LocalDb.instance.isInLibrary('track', _libraryRefId).then((v) {
      if (mounted) setState(() { _inLibrary = v; _loading = false; });
    });
    if (r.songId.isNotEmpty) {
      RewampDb.getSongContext(r.songId).then((c) {
        if (mounted && c != null) setState(() => _ctx = c);
      });
    }
    _resolveCachedPath();
  }

  Future<void> _resolveCachedPath() async {
    try {
      String? path = r.localPath;
      if (path == null || !await File(path).exists()) {
        final rec = await LocalDb.instance.getTrackByOnlineId(r.songId);
        if (rec != null && await File(rec.filePath).exists()) {
          path = rec.filePath;
        } else {
          final computed = await RewampDb.localPath(r);
          path = await File(computed).exists() ? computed : null;
        }
      }
      if (mounted) setState(() => _cachedPath = path);
    } catch (_) {}
  }

  Future<void> _deleteDownload() async {
    final path = _cachedPath;
    if (path == null) return;
    final l10n      = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trackOptionsDeleteDownloadTitle),
        content: Text(l10n.trackOptionsDeleteDownloadBody(path)),
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
    Navigator.pop(context);
    // Stop if this file is playing, drop EVERY queue entry that plays from it
    // (all subsongs of a .sid/.nsf, all members of an .rsn) and move to the next
    // entry — player closes when nothing follows. Before the delete: it reads
    // the DB rows deleteLocalTrack is about to remove.
    await PlayerController.current?.handleDeletedTrack(path);
    await RewampDb.deleteLocalTrack(path);
    AppSnack.showOn(messenger, l10n.trackOptionsDownloadDeleted, duration: const Duration(seconds: 2));
  }

  static IconData _tagIcon(String category) => switch (category) {
        'chip'            => Icons.memory,
        'group'           => Icons.groups,
        'party'           => Icons.celebration,
        'year'            => Icons.calendar_today,
        'production-type' => Icons.category_outlined,
        'platform'        => Icons.devices_other,
        'origin'          => Icons.public,
        // Same glyphs as the browse landing's category cards
        // (search_screen._categoryCardStyle) — one visual language.
        'arcade-board'    => Icons.developer_board,
        'publisher'       => Icons.storefront_outlined,
        'developer'       => Icons.code,
        _                 => Icons.sell_outlined,
      };

  Future<void> _toggleLibrary() async {
    final next = !_inLibrary;
    setState(() => _inLibrary = next);
    Navigator.pop(context);
    if (next) {
      await LocalDb.instance.addToLibrary(
        type:        'track',
        refId:       _libraryRefId,
        name:        r.displayTitle,
        artist:      r.artistLabel.isEmpty ? null : r.artistLabel,
        album:       r.album,
        albumId:     r.albumId,
        artworkUrl:  r.artworkUrl,
        formatExt:   r.formatExt,
        filename:    r.filename,
        downloadUrl: r.downloadUrl,
      );
      // Fire-and-forget; the handler must still return a String (the Future's
      // type) — returning nothing threw a TypeError on any download failure.
      RewampDb.downloadToLibrary(r).onError((_, __) => '');
    } else {
      await LocalDb.instance.removeFromLibrary('track', _libraryRefId);
      // Legacy rows were keyed by the bare song id — clean those up too.
      await LocalDb.instance.removeFromLibrary('track', r.songId);
    }
    // Le geste doit PARTIR: cette feuille écrivait en local et rien d'autre.
    await SyncService.recordTrackMembership(
      refId:     _libraryRefId,
      value:     next,
      title:     r.displayTitle,
      artist:    r.artistLabel.isEmpty ? null : r.artistLabel,
      album:     r.album,
      formatExt: r.formatExt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header — track title + artist
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ScrollingText(
                        text: r.displayTitle,
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (r.artistLabel.isNotEmpty)
                        ScrollingText(
                          text: r.artistLabel,
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Song context (get_song_context): metadata line + rebound tag chips.
          // Every chip is a door: tap → browse everything carrying that tag.
          if (_ctx != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  [
                    r.collection,
                    r.formatExt,
                    if ((_ctx!.song.year ?? r.year) != null)
                      '${_ctx!.song.year ?? r.year}',
                    if ((_ctx!.song.rating ?? r.rating) != null)
                      '★ ${(_ctx!.song.rating ?? r.rating)!.toStringAsFixed(1)}',
                  ].join(' · '),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
            if (_ctx!.tags.isNotEmpty || _ctx!.usedIn.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      // Productions come FIRST and are entities, not tags
                      // (migs 161-163): the id opens the exact demo, where the
                      // old `production` tag mixed up homonyms.
                      for (final prod in _ctx!.usedIn)
                        ActionChip(
                          avatar: const Icon(Icons.movie_outlined, size: 14),
                          label: Text(prod.label),
                          labelStyle: tt.bodySmall,
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              openProduction(context, prod, closeSheet: true),
                        ),
                      for (final e in _ctx!.tags.entries)
                        for (final name in e.value)
                          ActionChip(
                            avatar: Icon(_tagIcon(e.key), size: 14),
                            label: Text(name),
                            labelStyle: tt.bodySmall,
                            visualDensity: VisualDensity.compact,
                            // A group chip opens the GROUP screen, not a tag
                            // search: only that screen lists the group's
                            // productions (untagged by nature).
                            onPressed: e.key == 'group'
                                ? () {
                                    final nav = Navigator.of(context);
                                    nav.pop();
                                    final hook = globalOnOpenGroup;
                                    if (hook != null) {
                                      hook(name);
                                    } else {
                                      widget.onNavigateTag
                                          ?.call(name, category: e.key);
                                    }
                                  }
                                : widget.onNavigateTag == null
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        // e.key = the tag's category (mig 159)
                                        // — scopes the search to that namespace.
                                        widget.onNavigateTag!(name,
                                            category: e.key);
                                      },
                          ),
                    ],
                  ),
                ),
              )
            else
              const SizedBox(height: 10),
            const Divider(height: 1),
          ],

          // Play NOW — first action, replaces the current queue (goes through
          // AppShell's _startAlbumQueue, so a multi-subsong file queues all
          // its subtunes exactly like a normal tap-to-play).
          if (globalOnPlayNowSong != null)
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(l10n.trackOptionsPlayNow),
              onTap: () {
                final play = globalOnPlayNowSong!;
                Navigator.pop(context);
                play(r);
              },
            ),

          // Library toggle
          ListTile(
            leading: _loading
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _inLibrary
                        ? Icons.library_add_check
                        : Icons.library_add_outlined,
                    color: _inLibrary ? cs.primary : null,
                  ),
            title: Text(_inLibrary
                ? l10n.trackOptionsRemoveFromLibrary
                : l10n.trackOptionsAddToLibrary),
            enabled: !_loading,
            onTap: _toggleLibrary,
          ),

          // View album
          if (r.album != null && r.album!.isNotEmpty && widget.onNavigateAlbum != null)
            ListTile(
              leading: const Icon(Icons.album_outlined),
              title: Text(l10n.trackOptionsViewAlbum,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(r.album!, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(context);
                widget.onNavigateAlbum!(
                  r.album!,
                  collection: r.collection,
                  platform:   r.platform,
                  artworkUrl: r.artworkUrl,
                  albumId:    r.albumId,
                );
              },
            ),

          // View artist(s)
          if (widget.onNavigateArtist != null)
            for (final name in r.artistNames)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(l10n.trackOptionsViewArtist,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.pop(context);
                  // Pair the tapped name with its uuid (artist_ids is aligned
                  // with artist_names on every songs RPC, mig 129).
                  final i = r.artistNames.indexOf(name);
                  widget.onNavigateArtist!(name,
                      collection: r.collection,
                      artistId: (i >= 0 && i < r.artistIds.length)
                          ? r.artistIds[i]
                          : null);
                },
              ),

          // Watch the demozoo production video(s) — only when the song
          // context lists any (fetched async; the tile appears when it lands).
          if (_ctx != null && _ctx!.videos.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.ondemand_video),
              title: Text(l10n.videoWatchDemo,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: _ctx!.videos.first.title != null
                  ? Text(_ctx!.videos.first.title!,
                      maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              onTap: () {
                final videos = _ctx!.videos;
                Navigator.pop(context);
                VideoScreen.open(context, PlayerController.current, videos,
                    songId: r.songId);
              },
            ),

          // The tune's OWN demozoo entry (productions kind='own', mig 161):
          // a link out, not a browse — the tune is the production here, so
          // there is nothing of ours to list.
          if (_ctx?.ownProduction?.url != null)
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('demozoo.org'),
              subtitle: Text(_ctx!.ownProduction!.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => openExternalLink(
                  context, _ctx!.ownProduction!.url!),
            ),

          // Demozoo notes — production notes first (server-ordered); the tile
          // shows the first note's title, the sheet renders all of them.
          if (_ctx != null && _ctx!.notes.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: Text(l10n.contextNotes,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: _ctx!.notes.first.title != null
                  ? Text(_ctx!.notes.first.title!,
                      maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              onTap: () => showSongNotesSheet(context, _ctx!.notes),
            ),

          // Playlists — a single track adds just itself (no expansion).
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: Text(l10n.playlistAddTo),
            onTap: () {
              Navigator.pop(context);
              showAddToPlaylistSheet(context,
                  resolveTrackIds: () => trackIdsForResults([r]));
            },
          ),

          // Queue — add next
          if (widget.onQueueAdd != null) ...[
            ListTile(
              leading: const QueuePositionIcon(first: true),
              title: Text(l10n.trackOptionsPlayNext),
              onTap: () {
                Navigator.pop(context);
                widget.onQueueAdd!(r, atEnd: false);
              },
            ),
            ListTile(
              leading: const QueuePositionIcon(first: false),
              title: Text(l10n.trackOptionsAddToQueueEnd),
              onTap: () {
                Navigator.pop(context);
                widget.onQueueAdd!(r, atEnd: true);
              },
            ),
          ],

          // Delete the downloaded file + its local-DB rows.
          if (_cachedPath != null)
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text(l10n.trackOptionsDeleteDownload),
              onTap: _deleteDownload,
            ),

          const SizedBox(height: 8),
        ],
    );
  }
}

// ── Album-level options sheet ─────────────────────────────────────────────────

Future<void> showAlbumOptions(
  BuildContext context,
  String albumName, {
  /// Server UUID: THE identity when it exists (two jw_spc albums are both
  /// called "Final Fantasy VI"). Null for a local folder.
  String? albumId,
  String? artworkUrl,
  String? artist,
  String? collectionSlug,
  String? platformName,
  OnAlbumQueueAdd? onQueueAddNext,
  OnAlbumQueueAdd? onQueueAddAtEnd,
  required Future<List<SearchResult>> Function() fetchTracks,
  Future<void> Function()? onRedownload,
  VoidCallback? onDeleted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: _AlbumOptionsSheet(
          albumName:      albumName,
          albumId:        albumId,
          artworkUrl:     artworkUrl,
          artist:         artist,
          collectionSlug: collectionSlug,
          platformName:   platformName,
          onQueueAddNext: onQueueAddNext ?? globalOnAlbumQueueAdd,
          onQueueAddAtEnd: onQueueAddAtEnd ?? globalOnAlbumQueueAdd,
          fetchTracks:    fetchTracks,
          onRedownload:   onRedownload,
          onDeleted:      onDeleted,
        ),
      ),
    ),
  );
}

class _AlbumOptionsSheet extends StatefulWidget {
  final String  albumName;
  final String? artworkUrl;
  final String? artist;
  final String? albumId;
  final String? collectionSlug;
  final String? platformName;
  final OnAlbumQueueAdd? onQueueAddNext;
  final OnAlbumQueueAdd? onQueueAddAtEnd;
  final Future<List<SearchResult>> Function() fetchTracks;
  final Future<void> Function()? onRedownload;
  /// Called after the album's files + DB rows were deleted — lets the caller
  /// pop the (now stale) album screen.
  final VoidCallback? onDeleted;

  const _AlbumOptionsSheet({
    required this.albumName,
    this.albumId,
    this.artworkUrl,
    this.artist,
    this.collectionSlug,
    this.platformName,
    this.onQueueAddNext,
    this.onQueueAddAtEnd,
    required this.fetchTracks,
    this.onRedownload,
    this.onDeleted,
  });

  @override
  State<_AlbumOptionsSheet> createState() => _AlbumOptionsSheetState();
}

class _AlbumOptionsSheetState extends State<_AlbumOptionsSheet> {
  bool _inLibrary = false;
  bool _loading = true;
  bool _busy = false;

  /// This album's library key: its UUID when the catalogue gave one, else the
  /// name (see [albumLibraryRefId]).
  String get _refId => albumLibraryRefId(widget.albumName, widget.albumId);

  @override
  void initState() {
    super.initState();
    LocalDb.instance.isLibraryFavorite('album', _refId).then((v) {
      if (mounted) setState(() { _inLibrary = v; _loading = false; });
    });
  }

  Future<void> _toggleLibrary() async {
    final next = !_inLibrary;
    setState(() => _inLibrary = next);
    Navigator.pop(context);
    if (next) {
      await LocalDb.instance.addToLibrary(
        type:           'album',
        refId:          _refId,
        name:           widget.albumName,
        albumId:        widget.albumId,
        artist:         widget.artist,
        artworkUrl:     widget.artworkUrl,
        collectionSlug: widget.collectionSlug,
        platformName:   widget.platformName,
        isFavorite:     true,
        explicit:       false, // favorite flow — not an explicit library add
      );
      // Persist the album's full track list so the Favoris playlist shows
      // every track (the tracks table is otherwise only fed at play time).
      String? albumId = widget.albumId;
      try {
        final rows = await widget.fetchTracks();
        if (rows.isNotEmpty) {
          albumId ??= rows.first.albumId;
          await RewampDb.materializeAlbumTracks(widget.albumName, rows);
        }
      } catch (_) {/* favourite succeeded; list stays played-only */}
      // The account (and the cross-device heart) key albums by their UUID. The
      // caller normally hands it over; when it does not, take it from the
      // tracks we just fetched and backfill it. Without it the favourite was
      // this device's secret: no server row, and no identity the other device
      // could match it to.
      if (albumId != null && albumId.isNotEmpty) {
        await LocalDb.instance.setLibraryItemFavorite(
            'album', _refId, value: true, albumId: albumId);
      }
      await _syncAlbumFavourite(albumId, true);
    } else {
      final albumId = await _localAlbumId();
      await LocalDb.instance.setLibraryItemFavorite(
          'album', _refId, value: false);
      await _syncAlbumFavourite(albumId, false);
    }
  }

  /// The UUID this album is known by: the caller's when it has one, else the
  /// one stored on the local row (a row keyed by name predates migration 41,
  /// or belongs to an album the catalogue never identified).
  Future<String?> _localAlbumId() async {
    if (widget.albumId != null && widget.albumId!.isNotEmpty) {
      return widget.albumId;
    }
    for (final i in await LocalDb.instance.getLibraryItems(type: 'album')) {
      if (i.refId == _refId) return i.albumId;
    }
    return null;
  }

  /// Queues the membership change for the account. Queued, not POSTed: the
  /// gesture then survives being offline, and it wakes the sync so the heart
  /// (client state) leaves the device with it.
  Future<void> _syncAlbumFavourite(String? albumId, bool value) async {
    final signedIn = UserSettings.instance.hasAuthToken;
    if (!signedIn || albumId == null || albumId.isEmpty) return;
    await SyncService.recordLibraryChange(
        itemType: 'album', itemId: albumId, value: value, favourite: value);
  }

  Future<void> _deleteAlbumFiles() async {
    final l10n      = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    // Resolve the album directory from its first track's on-disk location.
    String? dir;
    try {
      final tracks = await widget.fetchTracks();
      if (tracks.isNotEmpty) {
        final first = tracks.first;
        final path = first.localPath ?? await RewampDb.localPath(first);
        dir = p.dirname(path);
        if (!await Directory(dir).exists()) dir = null;
      }
    } catch (_) {}
    if (!mounted) return;
    if (dir == null) {
      AppSnack.showOn(messenger, l10n.trackOptionsAlbumNotDownloaded);
      return;
    }
    final dirPath = dir;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trackOptionsDeleteAlbumTitle),
        content: Text(l10n.trackOptionsDeleteAlbumBody(dirPath)),
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
    Navigator.pop(context);
    // Stop if a track of this album is playing, drop EVERY queue entry living
    // under the directory and move to the next survivor (player closes when
    // nothing follows). Before the delete: the resolution reads the DB rows
    // deleteLocalAlbumDir is about to remove.
    await PlayerController.current?.handleDeletedAlbum(dirPath);
    await RewampDb.deleteLocalAlbumDir(dirPath);
    AppSnack.showOn(messenger, l10n.trackOptionsAlbumDeleted, duration: const Duration(seconds: 2));
    widget.onDeleted?.call();
  }

  Future<void> _queueAdd({required bool atEnd}) async {
    final cb = atEnd ? widget.onQueueAddAtEnd : widget.onQueueAddNext;
    if (cb == null || _busy) return;
    setState(() => _busy = true);
    Navigator.pop(context);
    final tracks = await widget.fetchTracks();
    if (tracks.isNotEmpty) await cb(tracks, atEnd: atEnd);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(widget.albumName,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const Divider(height: 1),
        ListTile(
          leading: _loading
              ? const SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_inLibrary ? Icons.star : Icons.star_border,
                  color: _inLibrary ? kFavoriteColor : null),
          title: Text(_inLibrary
              ? l10n.trackOptionsRemoveFromFavorites
              : l10n.trackOptionsAddToFavorites),
          enabled: !_loading,
          onTap: _toggleLibrary,
        ),
        if (widget.onQueueAddNext != null)
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: Text(l10n.playlistAddTo),
            onTap: () {
              Navigator.pop(context);
              showAddToPlaylistSheet(context, resolveTrackIds: () async {
                // Whole album → every track (containers expanded).
                final tracks = await widget.fetchTracks();
                return trackIdsForResults(await expandForPlaylist(tracks));
              });
            },
          ),
          ListTile(
            leading: const QueuePositionIcon(first: true),
            title: Text(l10n.trackOptionsPlayNext),
            onTap: () => _queueAdd(atEnd: false),
          ),
        if (widget.onQueueAddAtEnd != null)
          ListTile(
            leading: const QueuePositionIcon(first: false),
            title: Text(l10n.trackOptionsPlayLast),
            onTap: () => _queueAdd(atEnd: true),
          ),
        if (widget.onRedownload != null)
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text(l10n.trackOptionsRedownloadAlbum),
            subtitle: Text(l10n.trackOptionsRedownloadAlbumSubtitle),
            onTap: () {
              Navigator.pop(context);
              widget.onRedownload!();
            },
          ),
        ListTile(
          leading: Icon(Icons.delete_outline,
              color: Theme.of(context).colorScheme.error),
          title: Text(l10n.trackOptionsDeleteAlbumFiles),
          subtitle: Text(l10n.trackOptionsDeleteAlbumFilesSubtitle),
          onTap: _deleteAlbumFiles,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Play-choice sheet ─────────────────────────────────────────────────────────

/// What the user picked in [showPlayChoiceSheet].
enum PlayChoice { now, next, end, open }

/// The rail-tap popup: "Lire maintenant" (replaces the queue) / "Lire
/// ensuite" / "Ajouter à la fin de la file". [openLabel] adds a navigation
/// tile (album cards: "Voir l'album") so the popup never becomes a dead end
/// to the detail screen the tap used to open. Null = dismissed.
Future<PlayChoice?> showPlayChoiceSheet(
  BuildContext context, {
  String? title,
  String? subtitle,
  String? openLabel,
}) {
  // Nothing queued and nothing playing: every choice collapses into "play
  // now" — skip the popup and start playback directly.
  if (!(globalQueueHasContent?.call() ?? true)) {
    return Future.value(PlayChoice.now);
  }
  return showModalBottomSheet<PlayChoice>(
    context: context,
    // ROOT navigator: the tab navigators live UNDER the floating chrome
    // (mini player + nav bar, an AppShell Stack overlay) — a sheet pushed on
    // them slides in BEHIND the chrome. The root overlay covers everything.
    useRootNavigator: true,
    builder: (ctx) {
      final l10n = ctx.l10n;
      final tt   = Theme.of(ctx).textTheme;
      final cs   = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(l10n.trackOptionsPlayNow),
              onTap: () => Navigator.pop(ctx, PlayChoice.now),
            ),
            ListTile(
              leading: const QueuePositionIcon(first: true),
              title: Text(l10n.trackOptionsPlayNext),
              onTap: () => Navigator.pop(ctx, PlayChoice.next),
            ),
            ListTile(
              leading: const QueuePositionIcon(first: false),
              title: Text(l10n.trackOptionsAddToQueueEnd),
              onTap: () => Navigator.pop(ctx, PlayChoice.end),
            ),
            if (openLabel != null)
              ListTile(
                leading: const Icon(Icons.album_outlined),
                title: Text(openLabel),
                onTap: () => Navigator.pop(ctx, PlayChoice.open),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
