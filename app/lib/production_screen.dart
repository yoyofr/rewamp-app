import 'dart:async';

import 'package:flutter/material.dart';

import 'album_detail_screen.dart';
import 'artwork_image.dart';
import 'l10n.dart';
import 'note_markdown.dart' show openExternalLink;
import 'player_controller.dart';
import 'rewamp_db.dart';
import 'track_options_sheet.dart';
import 'video_screen.dart';
import 'shell_insets.dart';

/// Opens the production screen from anywhere (chips live in sheets that never
/// got navigation callbacks threaded through). Set once by AppShell so the
/// push lands on the ACTIVE tab navigator and the full player is restored when
/// the user comes back — same contract as [globalOnNavigateTag].
void Function(int productionId, {String? title})? globalOnOpenProduction;

/// Routes a production chip: the AppShell hook when set, else a plain push on
/// the current navigator (the screen works standalone — it resolves its own
/// details, tracks and play callback).
///
/// [closeSheet] pops the current route (the options sheet the chip lives in)
/// first. The navigator is captured BEFORE that pop: a popped sheet's context
/// is deactivated, and `Navigator.of` on it throws.
void openProduction(BuildContext context, ProductionRef ref,
    {bool closeSheet = false}) {
  final nav = Navigator.of(context);
  if (closeSheet) nav.pop();
  openProductionOn(nav, ref);
}

/// Same, for callers that must pop several routes first (the player's info
/// sheet pops itself AND the player): they capture the navigator up front,
/// because no context survives its own route being popped.
void openProductionOn(NavigatorState nav, ProductionRef ref) {
  final hook = globalOnOpenProduction;
  if (hook != null) {
    hook(ref.id, title: ref.title);
    return;
  }
  nav.push(MaterialPageRoute(
    builder: (_) => ProductionScreen(productionId: ref.id, title: ref.title),
  ));
}

/// Video-only production (song_count=0 + has_video): there is nothing to play,
/// so a row goes STRAIGHT to the video rather than to a screen whose single
/// control is that same button. Falls back to the production screen when the
/// details RPC brings back no video after all.
Future<void> openProductionVideo(
    BuildContext context, ProductionRef ref) async {
  final nav = Navigator.of(context);
  final d = await RewampDb.getProductionDetails(ref.id);
  if (!context.mounted) return;
  if (d != null && d.videos.isNotEmpty) {
    await VideoScreen.open(context, PlayerController.current, d.videos,
        productionId: d.id);
    return;
  }
  openProductionOn(nav, ref);
}

/// One demozoo production (migs 161-163): the sheet from
/// `get_production_details` on top of its soundtrack from
/// `get_production_tracks` — the playlist screen's shape, with a header that
/// names the demo instead of a playlist.
class ProductionScreen extends StatefulWidget {
  final int productionId;
  /// Title already known by the caller (the chip) — shown while the details
  /// RPC is in flight, so the app bar never flashes empty.
  final String? title;
  final OnPlayAlbum? onPlayAlbum;

  const ProductionScreen({
    super.key,
    required this.productionId,
    this.title,
    this.onPlayAlbum,
  });

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  ProductionDetails? _details;
  List<SearchResult>? _tracks;
  /// Albums the production's tunes come from (get_production_albums) — what
  /// makes `album_count` actionable. Empty (and hidden) for most productions.
  List<ArtistAlbum> _albums = const [];
  String? _error;

  OnPlayAlbum? get _playAlbum => widget.onPlayAlbum ?? globalOnPlayAlbum;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Details are optional chrome: a failure there must not hide the tracks.
    RewampDb.getProductionDetails(widget.productionId).then((d) {
      if (mounted && d != null) setState(() => _details = d);
    });
    RewampDb.getProductionAlbums(widget.productionId).then((a) {
      if (mounted && a.isNotEmpty) setState(() => _albums = a);
    });
    try {
      final tracks = await RewampDb.productionTracks(widget.productionId);
      if (!mounted) return;
      setState(() => _tracks = tracks);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  /// A production with a video but NO playable tune (server contract:
  /// song_count=0 + has_video → get_production_tracks is empty). The only
  /// action offered is watching the video — no play-all, no track list.
  /// The details RPC is what carries the video URLs, so this stays false
  /// until it lands.
  bool get _isVideoOnly =>
      (_tracks?.isEmpty ?? false) && (_details?.videos.isNotEmpty ?? false);

  Widget _videoOnlyBody(BuildContext context) {
    final l10n = context.l10n;
    final d = _details!;
    return ListView(
      children: [
        _header(context),
        Padding(
          padding: shellInset(context, const EdgeInsets.fromLTRB(16, 12, 16, 4)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              icon: const Icon(Icons.ondemand_video),
              label: Text(l10n.videoWatchDemo),
              onPressed: () => VideoScreen.open(
                  context, PlayerController.current, d.videos,
                  productionId: d.id),
            ),
          ),
        ),
      ],
    );
  }

  /// [idx] null = "Tout lire" — see PlaylistTracksScreen._playFrom: a
  /// startIndex, even 0, pins that track at the head of a shuffled queue.
  Future<void> _playFrom(int? idx) async {
    final tracks = _tracks;
    final play = _playAlbum;
    if (tracks == null || tracks.isEmpty || play == null) return;
    await play(context, List.of(tracks), startIndex: idx);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final title = _details?.title ?? widget.title ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_details?.url != null)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'demozoo.org',
              onPressed: () => openExternalLink(context, _details!.url!),
            ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _tracks == null
              ? const Center(child: CircularProgressIndicator())
              : _isVideoOnly
                  ? _videoOnlyBody(context)
                  : Builder(builder: (ctx0) {
                // Leading rows: sheet, [albums strip], play-all — the strip
                // lands asynchronously, so the count is derived, not constant.
                // Play-all is dropped entirely when nothing is playable.
                final leading = (_tracks!.isEmpty ? 1 : 2) +
                    (_albums.isEmpty ? 0 : 1);
                return ListView.builder(
                  itemCount: _tracks!.length + leading,
                  itemBuilder: (ctx, idx) {
                    if (idx == 0) return _header(ctx);
                    if (_albums.isNotEmpty && idx == 1) return _albumStrip(ctx);
                    if (_tracks!.isNotEmpty && idx == leading - 1) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(children: [
                          FilledButton.icon(
                            onPressed:
                                _tracks!.isEmpty ? null : () => _playFrom(null),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(l10n.commonPlayAll),
                          ),
                          const Spacer(),
                          Text(l10n.playlistTrackCount(_tracks!.length),
                              style: TextStyle(color: cs.onSurfaceVariant)),
                        ]),
                      );
                    }
                    final i = idx - leading;
                    final r = _tracks![i];
                    // track_position = order of the tune inside the demo.
                    final pos = r.trackPosition ?? (i + 1);
                    final subtitle = [
                      if (r.artistLabel.isNotEmpty) r.artistLabel,
                      if (r.album != null && r.album!.isNotEmpty) r.album!,
                    ].join(' — ');
                    final hasArt =
                        r.artworkUrl != null && r.artworkUrl!.isNotEmpty;
                    return ListTile(
                      leading: hasArt
                          // Placeholder thématisé (voir RailArtwork): un
                          // `placeholder:` explicite l'écrase.
                          ? RailArtwork(
                              url: r.artworkUrl,
                              artist:
                                  r.artistLabel.isEmpty ? null : r.artistLabel,
                              album: r.album,
                              formatHint: r.formatExt,
                              platformName: r.platform,
                              size: 44,
                            )
                          : SizedBox(
                              width: 36,
                              child: Center(
                                child: Text('$pos',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: cs.onSurfaceVariant)),
                              ),
                            ),
                      title: Text(r.displayTitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: subtitle.isEmpty
                          ? null
                          : Text(subtitle,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert, size: 20),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: () => showTrackOptions(ctx, r),
                      ),
                      onTap: () => _playFrom(i),
                    );
                  },
                );
              }),
    );
  }

  /// Horizontal strip of the albums this production's tunes live in. Tapping
  /// one opens the normal album screen; a track tap there plays that track as
  /// a one-item queue (this screen has no song-tap callback of its own).
  Widget _albumStrip(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.tabAlbums,
              style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: _albums.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final a = _albums[i];
                return SizedBox(
                  width: 96,
                  child: InkWell(
                    onTap: () => _openAlbum(ctx, a),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ArtworkImage(
                          url: a.artworkUrl,
                          album: a.name,
                          artist: a.artistNames.isEmpty
                              ? null : a.artistNames.first,
                          formatHint: a.format,
                          platformName: a.platform,
                          size: 96,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 4),
                        Text(a.name,
                            style: tt.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openAlbum(BuildContext context, ArtistAlbum a) {
    final play = _playAlbum;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AlbumDetailScreen(
        albumName:      a.name,
        albumId:        a.albumId,
        platformName:   a.platform,
        collectionSlug: a.collection,
        artworkUrl:     a.artworkUrl,
        onTap:          (ctx, r) async => play?.call(ctx, [r]),
        onPlayAlbum:    play,
      ),
    ));
  }

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final d = _details;
    final title = d?.title ?? widget.title ?? '';
    final subtitle = d?.subtitle ?? '';
    final art = d?.artworkUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (art != null && art.isNotEmpty) ...[
            ArtworkImage(
              url: art,
              size: 88,
              borderRadius: BorderRadius.circular(8),
              placeholder: const Icon(Icons.movie_outlined, size: 32),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style:
                          tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
                if (d != null && d.videos.isNotEmpty && !_isVideoOnly) ...[
                  const SizedBox(height: 6),
                  // Watching the demo pauses the music (the capture has its
                  // own audio) — same contract as the song video tile.
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.ondemand_video, size: 18),
                    label: Text(l10n.videoWatchDemo),
                    onPressed: () => VideoScreen.open(
                        context, PlayerController.current, d.videos,
                        productionId: d.id),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ProductionsBrowseScreen — the « Parcourir » card that replaced the removed
// `production` tag category: the whole catalogue via list_productions
// (productions with no playable tune are excluded server-side), filterable by
// name, sortable, and narrowable to the ones that HAVE a video of their own.
// ---------------------------------------------------------------------------

class ProductionsBrowseScreen extends StatefulWidget {
  final OnPlayAlbum? onPlayAlbum;
  /// Opens straight on the video-only view (entry point "productions with a
  /// video"); the chip stays togglable.
  final bool initialOnlyWithVideo;

  const ProductionsBrowseScreen({
    super.key,
    this.onPlayAlbum,
    this.initialOnlyWithVideo = false,
  });

  @override
  State<ProductionsBrowseScreen> createState() =>
      _ProductionsBrowseScreenState();
}

class _ProductionsBrowseScreenState extends State<ProductionsBrowseScreen> {
  final _filterCtrl = TextEditingController();
  final _scroll     = ScrollController();
  Timer? _debounce;

  final _rows = <ProductionSearchRow>[];
  String _query        = '';
  bool   _onlyVideo    = false;
  bool   _byUsage      = true;   // most tunes first; false = alphabetical
  bool   _loading      = true;
  bool   _loadingMore  = false;
  bool   _hasMore      = false;
  String? _error;
  int    _reqId = 0;

  static const _pageSize = 100;

  @override
  void initState() {
    super.initState();
    _onlyVideo = widget.initialOnlyWithVideo;
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    _scroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _onFilterChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _query = text.trim();
      _load();
    });
  }

  Future<void> _load() async {
    final id = ++_reqId;
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await RewampDb.listProductions(
        query:         _query.isEmpty ? null : _query,
        byUsage:       _byUsage,
        onlyWithVideo: _onlyVideo,
        limit:         _pageSize,
      );
      if (!mounted || id != _reqId) return;
      setState(() {
        _rows..clear()..addAll(rows);
        final total = rows.isEmpty ? 0 : rows.first.totalCount;
        _hasMore = total > _rows.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    final id = _reqId;
    try {
      final more = await RewampDb.listProductions(
        query:         _query.isEmpty ? null : _query,
        byUsage:       _byUsage,
        onlyWithVideo: _onlyVideo,
        limit:         _pageSize,
        offset:        _rows.length,
      );
      if (!mounted || id != _reqId) return;
      setState(() {
        _rows.addAll(more);
        _hasMore = more.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _open(ProductionSearchRow row) {
    // Video-only: skip the screen, play the video (server contract).
    if (row.isVideoOnly) {
      openProductionVideo(context, row.production);
      return;
    }
    final hook = globalOnOpenProduction;
    if (hook != null) {
      hook(row.production.id, title: row.production.title);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductionScreen(
        productionId: row.production.id,
        title:        row.production.title,
        onPlayAlbum:  widget.onPlayAlbum,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tt   = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabProductions),
        actions: [
          IconButton(
            icon: Icon(_byUsage ? Icons.sort_by_alpha : Icons.trending_up),
            onPressed: () {
              setState(() => _byUsage = !_byUsage);
              _load();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _filterCtrl,
              decoration: InputDecoration(
                hintText: l10n.browseFilterFacet(
                    l10n.tabProductions.toLowerCase()),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: _onFilterChanged,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: FilterChip(
                avatar: const Icon(Icons.ondemand_video, size: 16),
                label: Text(l10n.filterWithVideo),
                selected: _onlyVideo,
                visualDensity: VisualDensity.compact,
                onSelected: (v) {
                  setState(() => _onlyVideo = v);
                  _load();
                },
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? Center(child: Text(l10n.searchNoResults))
                    : ListView.builder(
                        controller: _scroll,
                        itemCount: _rows.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i >= _rows.length) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: Center(
                                  child: SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))),
                            );
                          }
                          final row = _rows[i];
                          final p   = row.production;
                          final sub = <String>[
                            if (p.subtitle.isNotEmpty) p.subtitle,
                            if (row.songCount > 0)
                              l10n.browseTracksCount(row.songCount),
                          ].join('  ·  ');
                          return ListTile(
                            leading: SizedBox(
                              width: 48,
                              height: 48,
                              child: (p.artworkUrl != null &&
                                      p.artworkUrl!.isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(p.artworkUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.movie_outlined)),
                                    )
                                  : const Icon(Icons.movie_outlined),
                            ),
                            title: Row(children: [
                              Flexible(
                                child: Text(p.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (row.hasVideo) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.ondemand_video, size: 14),
                                if (row.videoCount > 1)
                                  Text(' ${row.videoCount}', style: tt.bodySmall),
                              ],
                            ]),
                            subtitle: sub.isEmpty
                                ? null
                                : Text(sub,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                            trailing: Icon(row.isVideoOnly
                                ? Icons.play_circle_outline
                                : Icons.chevron_right),
                            onTap: () => _open(row),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
