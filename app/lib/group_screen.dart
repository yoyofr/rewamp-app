part of 'search_screen.dart';

/// Opens the group screen from anywhere (group chips live in sheets that never
/// got navigation callbacks threaded through). Set once by AppShell so the push
/// lands on the ACTIVE tab navigator and the full player is restored on the way
/// back — same contract as [globalOnNavigateTag] / [globalOnOpenProduction].
///
/// Declared in track_options_sheet.dart next to the other global hooks so the
/// sheets can reach it without importing the search library.

/// Routes a group chip: the AppShell hook when set, else a plain push on the
/// current navigator (the screen is standalone — it resolves its own profile,
/// counts and tabs).
///
/// [closeSheet] pops the route the chip lives in FIRST, and the navigator is
/// captured before that pop: a popped sheet's context is deactivated and
/// `Navigator.of` on it throws.
void openGroup(BuildContext context, String name,
    {String? tagId, bool closeSheet = false}) {
  final nav = Navigator.of(context);
  if (closeSheet) nav.pop();
  openGroupOn(nav, name, tagId: tagId);
}

/// Same, for callers that must pop several routes first (the player's info
/// sheet pops itself AND the player): no context survives its own route pop,
/// so they capture the navigator up front.
void openGroupOn(NavigatorState nav, String name, {String? tagId}) {
  final hook = globalOnOpenGroup;
  if (hook != null) {
    hook(name, tagId: tagId);
    return;
  }
  nav.push(MaterialPageRoute(
    builder: (_) => GroupScreen(name: name, tagId: tagId),
  ));
}

/// The five entity tabs of a group screen. Which ones EXIST is decided by the
/// server counts before anything is loaded (a zero-count tab is hidden), so the
/// list is built per group rather than being a fixed enum position.
enum _GroupTab { songs, artists, albums, playlists, productions }

/// One demozoo group (server migs 201/202): header (members + note) on top of
/// the five listings that group produced.
///
/// Three server rules this screen is built on:
/// - `tag_categories: ['group']` is MANDATORY on the four tag-driven tabs — a
///   group name collides with a party name ("Apocalypse" is both), and without
///   it the filter resolves across every category.
/// - productions travel by `group_name`, NEVER by tag: a production is not
///   tagged, it is RELEASED BY a group (`groups[]` column).
/// - Playlists are always 0 and Albums are 0 for ~99 % of groups — structural,
///   not a gap. Productions is the tab that carries a group's output.
class GroupScreen extends StatefulWidget {
  final String  name;
  /// Preferred over the name whenever known (homonym-proof, mig 201). Null for
  /// a group known only through `productions.groups`.
  final String? tagId;
  final Future<void> Function(BuildContext, SearchResult)? onTap;
  final OnPlayAlbum?     onPlayAlbum;
  final OnQueueAdd?      onQueueAdd;
  final OnAlbumQueueAdd? onAlbumQueueAdd;
  final OnFileReady?     onFileReady;

  const GroupScreen({
    super.key,
    required this.name,
    this.tagId,
    this.onTap,
    this.onPlayAlbum,
    this.onQueueAdd,
    this.onAlbumQueueAdd,
    this.onFileReady,
  });

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen>
    with TickerProviderStateMixin {
  static const int _kPage = 50;

  GroupDetails? _details;
  bool _detailsLoading = true;
  bool _noteExpanded   = false;

  /// Tabs actually shown, derived from the counts. Empty until the profile
  /// lands; the TabController is rebuilt with it (length is fixed at creation).
  List<_GroupTab> _shown = const [];
  TabController?  _tabs;

  // Songs
  final _songs = ValueNotifier<List<SearchResult>>([]);
  int  _songTotal = -1, _songOffset = 0;
  bool _songsLoading = false, _songsLoaded = false;
  bool _songHasMore = false, _songLoadingMore = false;

  // Artists
  List<ArtistResult> _artists = [];
  int  _artistTotal = -1, _artistOffset = 0;
  bool _artistsLoading = false, _artistsLoaded = false;
  bool _artistHasMore = false, _artistLoadingMore = false;

  // Albums
  List<_AlbumId> _albums = [];
  int  _albumTotal = -1, _albumOffset = 0;
  bool _albumsLoading = false, _albumsLoaded = false;
  bool _albumHasMore = false, _albumLoadingMore = false;

  // Playlists
  List<Playlist> _playlists = [];
  int  _playlistTotal = -1, _playlistOffset = 0;
  bool _playlistsLoading = false, _playlistsLoaded = false;
  bool _playlistHasMore = false, _playlistLoadingMore = false;

  // Productions
  List<ProductionSearchRow> _productions = [];
  int  _productionTotal = -1, _productionOffset = 0;
  bool _productionsLoading = false, _productionsLoaded = false;
  bool _productionHasMore = false, _productionLoadingMore = false;

  /// The name the RPCs are filtered by: the server's spelling once the profile
  /// is in (matched `lower()`, so it must NOT be reshaped), the caller's until
  /// then — that is what lets the first tab load before the header resolves.
  String get _name => _details?.name ?? widget.name;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  void dispose() {
    _tabs?.dispose();
    _songs.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    final d = await RewampDb.getGroupDetails(widget.name, tagId: widget.tagId);
    if (!mounted) return;
    setState(() {
      _details = d;
      _detailsLoading = false;
      _shown = _visibleTabs(d);
      _tabs?.dispose();
      _tabs = _shown.isEmpty
          ? null
          : (TabController(length: _shown.length, vsync: this)
            ..addListener(_onTabChanged));
    });
    if (_shown.isNotEmpty) _loadTab(_shown.first);
  }

  /// Hide a tab whose count is 0 — decided from `counts` BEFORE loading
  /// anything. An unknown group (no profile) keeps Productions alone: a
  /// tag-less group still has releases, and that is the only listing that can
  /// find them.
  List<_GroupTab> _visibleTabs(GroupDetails? d) {
    if (d == null) return const [_GroupTab.productions];
    final c = d.counts;
    return [
      if (c.songs > 0)       _GroupTab.songs,
      if (c.artists > 0)     _GroupTab.artists,
      if (c.albums > 0)      _GroupTab.albums,
      if (c.playlists > 0)   _GroupTab.playlists,
      if (c.productions > 0) _GroupTab.productions,
    ];
  }

  void _onTabChanged() {
    final t = _tabs;
    if (t == null || !mounted) return;
    if (t.indexIsChanging) return;
    _loadTab(_shown[t.index]);
  }

  /// Lazy per tab, first page only — a group with 2 299 songs must not pay for
  /// five listings when the user came for its productions.
  void _loadTab(_GroupTab tab) {
    switch (tab) {
      case _GroupTab.songs:       if (!_songsLoaded)       _loadSongs();
      case _GroupTab.artists:     if (!_artistsLoaded)     _loadArtists();
      case _GroupTab.albums:      if (!_albumsLoaded)      _loadAlbums();
      case _GroupTab.playlists:   if (!_playlistsLoaded)   _loadPlaylists();
      case _GroupTab.productions: if (!_productionsLoaded) _loadProductions();
    }
  }

  // ---- Loaders --------------------------------------------------------------

  Future<void> _loadSongs({int offset = 0}) async {
    if (offset == 0) {
      if (_songsLoading) return;
      setState(() => _songsLoading = true);
    }
    try {
      // browse_music, not search_music: there is no text here, and a q=name
      // search would drag in the whole cross-entity FTS (slow, and it matches
      // titles that merely contain the group name).
      final res = await RewampDb.browse(
        tags:          [_name],
        tagCategories: const ['group'],
        sortBy:        'name',
        limit:         _kPage,
        offset:        offset,
      );
      if (!mounted) return;
      setState(() {
        _songs.value = offset == 0 ? res : [..._songs.value, ...res];
        if (offset == 0) _songTotal = res.isEmpty ? 0 : res.first.totalCount;
        _songOffset      = _songs.value.length;
        _songHasMore     = res.length >= _kPage;
        _songsLoading    = false;
        _songLoadingMore = false;
        _songsLoaded     = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _songsLoading = false;
          _songLoadingMore = false;
          _songsLoaded = true;
        });
      }
    }
  }

  Future<void> _loadMoreSongs() async {
    if (_songLoadingMore || !_songHasMore) return;
    setState(() => _songLoadingMore = true);
    await _loadSongs(offset: _songOffset);
  }

  Future<void> _loadArtists({int offset = 0}) async {
    if (offset == 0) {
      if (_artistsLoading) return;
      setState(() => _artistsLoading = true);
    }
    try {
      final res = await RewampDb.searchArtists(
        '',
        tags:          [_name],
        tagCategories: const ['group'],
        limit:         _kPage,
        offset:        offset,
      );
      if (!mounted) return;
      setState(() {
        _artists = offset == 0 ? res : [..._artists, ...res];
        if (offset == 0) _artistTotal = res.isEmpty ? 0 : res.first.totalCount;
        _artistOffset      = _artists.length;
        _artistHasMore     = res.length >= _kPage;
        _artistsLoading    = false;
        _artistLoadingMore = false;
        _artistsLoaded     = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _artistsLoading = false;
          _artistLoadingMore = false;
          _artistsLoaded = true;
        });
      }
    }
  }

  Future<void> _loadMoreArtists() async {
    if (_artistLoadingMore || !_artistHasMore) return;
    setState(() => _artistLoadingMore = true);
    await _loadArtists(offset: _artistOffset);
  }

  Future<void> _loadAlbums({int offset = 0}) async {
    if (offset == 0) {
      if (_albumsLoading) return;
      setState(() => _albumsLoading = true);
    }
    try {
      final res = await RewampDb.searchAlbums(
        '',
        tags:          [_name],
        tagCategories: const ['group'],
        limit:         _kPage,
        offset:        offset,
      );
      if (!mounted) return;
      final albums = res
          .map((a) => _AlbumId(a.name, a.collection, a.platform, a.artworkUrl,
              a.aliases, a.albumId, a.artistNames, a.format, a.fileSize,
              a.matchReason, a.hasVideo, a.podium))
          .toList();
      setState(() {
        _albums = offset == 0 ? albums : [..._albums, ...albums];
        if (offset == 0) _albumTotal = res.isEmpty ? 0 : res.first.totalCount;
        _albumOffset      = _albums.length;
        _albumHasMore     = res.length >= _kPage;
        _albumsLoading    = false;
        _albumLoadingMore = false;
        _albumsLoaded     = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _albumsLoading = false;
          _albumLoadingMore = false;
          _albumsLoaded = true;
        });
      }
    }
  }

  Future<void> _loadMoreAlbums() async {
    if (_albumLoadingMore || !_albumHasMore) return;
    setState(() => _albumLoadingMore = true);
    await _loadAlbums(offset: _albumOffset);
  }

  Future<void> _loadPlaylists({int offset = 0}) async {
    if (offset == 0) {
      if (_playlistsLoading) return;
      setState(() => _playlistsLoading = true);
    }
    try {
      final res = await RewampDb.listPlaylists(
        tags:          [_name],
        tagCategories: const ['group'],
        limit:         _kPage,
        offset:        offset,
      );
      if (!mounted) return;
      setState(() {
        _playlists = offset == 0 ? res : [..._playlists, ...res];
        if (offset == 0) {
          _playlistTotal = res.isEmpty ? 0 : res.first.totalCount;
        }
        _playlistOffset      = _playlists.length;
        _playlistHasMore     = res.length >= _kPage;
        _playlistsLoading    = false;
        _playlistLoadingMore = false;
        _playlistsLoaded     = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _playlistsLoading = false;
          _playlistLoadingMore = false;
          _playlistsLoaded = true;
        });
      }
    }
  }

  Future<void> _loadMorePlaylists() async {
    if (_playlistLoadingMore || !_playlistHasMore) return;
    setState(() => _playlistLoadingMore = true);
    await _loadPlaylists(offset: _playlistOffset);
  }

  Future<void> _loadProductions({int offset = 0}) async {
    if (offset == 0) {
      if (_productionsLoading) return;
      setState(() => _productionsLoading = true);
    }
    try {
      // group_name, never a tag — productions carry no tags at all.
      final res = await RewampDb.listProductions(
        group:  _name,
        limit:  _kPage,
        offset: offset,
      );
      if (!mounted) return;
      setState(() {
        _productions = offset == 0 ? res : [..._productions, ...res];
        if (offset == 0) {
          _productionTotal = res.isEmpty ? 0 : res.first.totalCount;
        }
        _productionOffset      = _productions.length;
        _productionHasMore     = res.length >= _kPage;
        _productionsLoading    = false;
        _productionLoadingMore = false;
        _productionsLoaded     = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _productionsLoading = false;
          _productionLoadingMore = false;
          _productionsLoaded = true;
        });
      }
    }
  }

  Future<void> _loadMoreProductions() async {
    if (_productionLoadingMore || !_productionHasMore) return;
    setState(() => _productionLoadingMore = true);
    await _loadProductions(offset: _productionOffset);
  }

  // ---- Navigation -----------------------------------------------------------

  Future<void> _onSongTap(BuildContext ctx, SearchResult r) async {
    final tap = widget.onTap;
    if (tap != null) return tap(ctx, r);
    final ready = widget.onFileReady;
    if (ready != null) return downloadAndPlay(ctx, r, ready);
  }

  void _pushArtist(String name, {String? artistId}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ArtistResultsScreen(
        artistName:      name,
        artistId:        artistId,
        onTap:           _onSongTap,
        onPlayAlbum:     widget.onPlayAlbum,
        onQueueAdd:      widget.onQueueAdd,
        onAlbumQueueAdd: widget.onAlbumQueueAdd,
        onNavigateTag:   globalOnNavigateTag,
      ),
    ));
  }

  void _pushAlbum(_AlbumId album) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AlbumDetailScreen(
        albumName:       album.name,
        albumId:         album.albumId,
        platformName:    album.platform,
        collectionSlug:  album.collection,
        artworkUrl:      album.artworkUrl,
        onTap:           _onSongTap,
        onPlayAlbum:     widget.onPlayAlbum,
        onQueueAdd:      widget.onQueueAdd,
        onAlbumQueueAdd: widget.onAlbumQueueAdd,
        onArtistTap:     (n) => _pushArtist(n),
      ),
    ));
  }

  Future<void> _openPlaylist(BuildContext ctx, Playlist pl) async {
    await Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => PlaylistTracksScreen(
        playlist:    pl,
        onTap:       _onSongTap,
        onPlayAlbum: widget.onPlayAlbum,
      ),
    ));
  }

  Future<void> _playPlaylistNow(BuildContext ctx, Playlist pl) async {
    try {
      final tracks = await RewampDb.playlistTracks(pl.id);
      if (!ctx.mounted || tracks.isEmpty) return;
      await widget.onPlayAlbum?.call(ctx, tracks);
    } catch (_) {}
  }

  // ---- Build ----------------------------------------------------------------

  String _tabLabelOf(_GroupTab t, AppLocalizations l10n) {
    final c = _details?.counts;
    final (String base, int badge, int loaded) = switch (t) {
      // ⚠️ counts.artists (artists WITH a track), never artist_count, which is
      // the member count that goes with the header chips.
      _GroupTab.songs =>
        (l10n.tabAll, c?.songs ?? 0, _songTotal),
      _GroupTab.artists =>
        (l10n.tabArtists, c?.artists ?? 0, _artistTotal),
      _GroupTab.albums =>
        (l10n.tabAlbums, c?.albums ?? 0, _albumTotal),
      _GroupTab.playlists =>
        (l10n.libraryPlaylists, c?.playlists ?? 0, _playlistTotal),
      _GroupTab.productions =>
        (l10n.tabProductions, c?.productions ?? 0, _productionTotal),
    };
    // The counts come from a materialized view and can trail the live listings
    // by a couple of units — once a list is loaded, its own total_count wins.
    final n = loaded >= 0 ? loaded : badge;
    return n > 0 ? l10n.searchTabWithCount(base, '$n') : base;
  }

  Widget _tabView(_GroupTab t) {
    final l10n = context.l10n;
    switch (t) {
      case _GroupTab.songs:
        if (_songsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return ValueListenableBuilder<List<SearchResult>>(
          valueListenable: _songs,
          builder: (_, rows, __) => _PaginatedListView(
            itemCount:   rows.length,
            total:       _songTotal,
            hasMore:     _songHasMore,
            loadingMore: _songLoadingMore,
            loadMore:    _loadMoreSongs,
            empty:       Center(child: Text(l10n.searchNoSongs)),
            itemBuilder: (_, i) => SongTile(
              result:           rows[i],
              onTap:            _onSongTap,
              onQueueAdd:       widget.onQueueAdd,
              onPlayAlbum:      widget.onPlayAlbum,
              // browse_music rows are tracks, never album-level matches.
              albumRowsAllowed: false,
              showCollection:   true,
            ),
          ),
        );
      case _GroupTab.artists:
        if (_artistsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return _ArtistResultList(
          items:       _artists,
          total:       _artistTotal,
          hasMore:     _artistHasMore,
          loadingMore: _artistLoadingMore,
          loadMore:    _loadMoreArtists,
          onTap:       (a) => _pushArtist(a.name, artistId: a.artistId),
        );
      case _GroupTab.albums:
        if (_albumsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return _AlbumList(
          items:       _albums,
          total:       _albumTotal,
          hasMore:     _albumHasMore,
          loadingMore: _albumLoadingMore,
          loadMore:    _loadMoreAlbums,
          onTap:       _pushAlbum,
          onPlay:      widget.onPlayAlbum,
        );
      case _GroupTab.playlists:
        if (_playlistsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return _PlaylistList(
          items:       _playlists,
          total:       _playlistTotal,
          hasMore:     _playlistHasMore,
          loadingMore: _playlistLoadingMore,
          loadMore:    _loadMorePlaylists,
          onTap:       _openPlaylist,
          onPlay:      widget.onPlayAlbum == null ? null : _playPlaylistNow,
        );
      case _GroupTab.productions:
        if (_productionsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return _ProductionList(
          items:       _productions,
          total:       _productionTotal,
          hasMore:     _productionHasMore,
          loadingMore: _productionLoadingMore,
          loadMore:    _loadMoreProductions,
          onTap: (ctx, row) => row.isVideoOnly
              ? openProductionVideo(ctx, row.production)
              : openProduction(ctx, row.production),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d    = _details;
    final tabs = _tabs;

    return Scaffold(
      appBar: AppBar(
        title: Text(d?.name ?? widget.name),
        actions: [
          if (d?.notesUrl != null)
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              tooltip: 'demozoo.org',
              onPressed: () => openExternalLink(context, d!.notesUrl!),
            ),
        ],
        bottom: tabs == null
            ? null
            : TabBar(
                controller: tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  for (final t in _shown) Tab(text: _tabLabelOf(t, l10n)),
                ],
              ),
      ),
      body: _detailsLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (d != null) _buildHeader(d),
                if (tabs == null)
                  Expanded(
                    child: Center(child: Text(l10n.searchNoResults)),
                  )
                else
                  Expanded(
                    child: TabBarView(
                      controller: tabs,
                      children: [for (final t in _shown) _tabView(t)],
                    ),
                  ),
              ],
            ),
    );
  }

  /// Members first (the actionable part), the demozoo note under them as one
  /// collapsed line — a long bio must never push the tabs off-screen.
  Widget _buildHeader(GroupDetails d) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;
    final tt   = Theme.of(context).textTheme;
    if (d.artists.isEmpty && d.note == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.artists.isNotEmpty) ...[
            // artist_count IS the member count (it goes with artists[]).
            Text(l10n.groupMembersCount(d.artistCount),
                style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.18,
              ),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: -4,
                  children: [
                    for (final a in d.artists)
                      ActionChip(
                        avatar: const Icon(Icons.person_outline, size: 16),
                        label: Text(a.name),
                        labelStyle: tt.bodySmall,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        onPressed: () => _pushArtist(a.name, artistId: a.id),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (d.note != null) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _noteExpanded = !_noteExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _noteExpanded
                          ? Icons.arrow_drop_up
                          : Icons.arrow_drop_down,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    Expanded(
                      child: _noteExpanded
                          ? ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.3,
                              ),
                              child: SingleChildScrollView(
                                child: NoteMarkdown(
                                  text: d.note!,
                                  onOpenLink: (u) =>
                                      openExternalLink(context, u),
                                  style: tt.bodySmall,
                                ),
                              ),
                            )
                          // Collapsed: link SYNTAX would show as raw markup,
                          // hence noteToPlainLine rather than the raw text.
                          : Text(
                              noteToPlainLine(d.note!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Groups tab of the search screen (`search_groups`).
class _GroupList extends StatelessWidget {
  final List<GroupSearchResult> items;
  final int  total;
  final bool hasMore;
  final bool loadingMore;
  final Future<void> Function() loadMore;
  final void Function(GroupSearchResult) onTap;

  const _GroupList({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.loadingMore,
    required this.loadMore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _PaginatedListView(
      itemCount:   items.length,
      total:       total,
      hasMore:     hasMore,
      loadingMore: loadingMore,
      loadMore:    loadMore,
      empty:       Center(child: Text(l10n.searchNoResults)),
      itemBuilder: (_, i) {
        final g = items[i];
        final parts = <String>[
          if (g.memberCount > 0) l10n.groupMembersCount(g.memberCount),
          if (g.songCount > 0) l10n.searchSongsCount(g.songCount),
          if (g.productionCount > 0)
            l10n.searchTabWithCount(l10n.tabProductions, '${g.productionCount}'),
        ];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.groups)),
          title: Row(children: [
            Flexible(
              // shrinkWrap: l'icône vidéo suit le nom dans cette Row.
              child: ScrollingText(text: g.name, shrinkWrap: true),
            ),
            if (g.videoCount > 0) ...[
              const SizedBox(width: 4),
              const Icon(Icons.ondemand_video, size: 14),
            ],
          ]),
          subtitle: parts.isEmpty ? null : Text(parts.join(' · ')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onTap(g),
        );
      },
    );
  }
}
