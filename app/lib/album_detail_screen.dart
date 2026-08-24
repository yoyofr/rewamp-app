import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'favorite_color.dart';
import 'package:path/path.dart' as p;
import 'l10n.dart';
import 'local_db.dart';
import 'production_screen.dart';
import 'podium_badge.dart';
import 'competition_screen.dart' show podiumColor;
import 'rewamp_db.dart';
import 'sync_service.dart';
import 'user_settings.dart';
import 'scrolling_text.dart';
import 'artwork_image.dart';
import 'download_manager.dart';
import 'library_button.dart';
import 'track_options_sheet.dart';
import 'shell_insets.dart';

// Human-readable byte size (B / KB / MB).
String _fmtBytes(AppLocalizations l10n, int b) {
  if (b < 1024) return l10n.unitBytes('$b');
  if (b < 1024 * 1024) return l10n.unitKilobytes((b / 1024).toStringAsFixed(0));
  return l10n.unitMegabytes((b / (1024 * 1024)).toStringAsFixed(1));
}

// ---------------------------------------------------------------------------
// AlbumDetailScreen
//
// Shows artwork + rich metadata from get_album_details, then a paginated
// track list from browse_music (album_name filter).
// ---------------------------------------------------------------------------

class AlbumDetailScreen extends StatefulWidget {
  final String       albumName;
  /// Stable album id (from SearchResult.albumId). When set, tracks are fetched
  /// with get_album_tracks(albumId) so same-named albums (e.g. "Commando", 5
  /// distinct albums) resolve to the exact one instead of being merged by name.
  final String?      albumId;
  final String?      platformName;
  final String?      collectionSlug;
  /// Pre-loaded artwork URL hint (shown immediately before AlbumDetails loads).
  final String?      artworkUrl;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnPlayAlbum? onPlayAlbum;
  /// Called when the user taps a composer/artist name.
  final void Function(String artistName)? onArtistTap;
  final OnQueueAdd?       onQueueAdd;
  final OnAlbumQueueAdd?  onAlbumQueueAdd;
  /// Plays an already-downloaded album straight from local DB records — used
  /// when the album is opened from the library and its files are on disk, so
  /// no server round-trip (which may have an incomplete collection/platform) is
  /// needed.
  final OnPlayLocalAlbum? onPlayLocalAlbum;

  const AlbumDetailScreen({
    super.key,
    required this.albumName,
    this.albumId,
    this.platformName,
    this.collectionSlug,
    this.artworkUrl,
    required this.onTap,
    this.onPlayAlbum,
    this.onArtistTap,
    this.onQueueAdd,
    this.onAlbumQueueAdd,
    this.onPlayLocalAlbum,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  // Metadata
  AlbumDetails? _details;
  bool _detailsLoading = true;
  // Artist override from M3U header (joshw containers) — supersedes server data.
  List<String>? _m3uArtistNames;

  List<String> get _effectiveComposerNames {
    if (_m3uArtistNames != null && _m3uArtistNames!.isNotEmpty) {
      return _m3uArtistNames!;
    }
    final composers = _details?.composerNames ?? const <String>[];
    if (composers.isNotEmpty) return composers;
    // Last resort: union of the album tracks' artists (e.g. PSF tag-derived).
    return _albumArtistsFromTracks();
  }

  /// Distinct, order-preserving union of every track's artist names.
  List<String> _albumArtistsFromTracks() {
    final seen = <String>{};
    final out  = <String>[];
    for (final t in _tracks) {
      for (final a in t.artistNames) {
        final n = a.trim();
        if (n.isEmpty || n.toLowerCase() == 'null') continue;
        if (seen.add(n)) out.add(n);
      }
    }
    return out;
  }

  // Track list
  final _tracks    = <SearchResult>[];
  int   _total       = 0;
  int   _offset      = 0;
  bool  _hasMore     = false;
  bool  _tracksLoading = true;
  bool  _loadingMore   = false;
  bool  _playingAll    = false;
  String? _error;

  // Incremented after every ZIP extraction so visible track tiles re-check disk.
  int _downloadRevision = 0;

  // PSF archive album state
  bool _isPsfArchiveAlbum = false;
  bool _psfAlbumDownloaded = false;

  // Container album state (single multi-subsong file, e.g. joshw .hes/.nsf in
  // a 7z): not expanded until the archive is on disk — opening the screen must
  // NOT trigger a download (PSF-style placeholder instead).
  bool _isContainerAlbum = false;
  bool _containerDownloaded = false;
  // The single server "container" row (one .gbs/.nsf holding N subsongs), kept
  // so a download/expand always targets the real container even while _tracks
  // shows the per-subsong preview rows built from its server tracklist.
  SearchResult? _containerRow;

  // Generic "album is on disk" state (any album type) — drives the download
  // icon next to "Lire l'album" and the "Re-télécharger" menu entry.
  bool _albumDownloaded = false;

  // Local album state: the album is fully on disk (opened from the library).
  // _localTracks parallels _tracks 1:1 so a tap can play the real file path.
  bool _localAlbum = false;
  final _localTracks = <TrackRecord>[];
  int  _localBytes = 0; // summed on-disk size (distinct files) for local albums

  // A "shared-file" album = one file holding N subsongs (joshw .nsf / Amiga
  // container): the file size belongs to the file, not each subsong, so the
  // per-row size is hidden (only the header total is shown). Detected generically:
  // at most one row carries a size (subsongRowsFromServer puts it on row 0 only;
  // the local path zeroes per-track size for allSameFile). A real one-file-per-
  // track album has a size on every row → not shared.
  bool get _sharedFileAlbum {
    if (_tracks.length <= 1) return false;
    return _tracks.where((t) => t.totalFileSize > 0).length <= 1;
  }

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // A track deleted elsewhere (player options) removes its DB rows, which fires
    // LocalDb — re-check the per-track download badges + album state so a deleted
    // row stops showing as downloaded without leaving/re-entering the screen.
    LocalDb.instance.addListener(_onLocalDbChanged);
    // Bulk downloads run in the DownloadManager queue now: each completed job
    // fires this, refreshing the per-track badges and the album state (the
    // old inline loop did it after each await).
    DownloadManager.instance.addListener(_onLocalDbChanged);
    _init();
  }

  void _onLocalDbChanged() {
    if (!mounted) return;
    setState(() => _downloadRevision++);   // tiles re-run their per-file check
    _refreshDownloadedState();
  }

  // Per-subsong scores of a CONTAINER album (one file, N subtunes): fetched
  // from the container's song context — the expanded preview rows carry no
  // scores of their own (they are synthetic). File-grain albums don't need
  // this: each row is a file whose rating/popularity ride the listing.
  Map<int, SubsongScore> _subsongScores = const {};

  Future<void> _init() async {
    // Server first: browse returns the full track list. The local DB only holds
    // tracks that were actually played, so it must never pre-empt the server
    // (that showed a single track for freshly-downloaded albums).
    await Future.wait([_loadDetails(), _loadTracks(0)]);
    if (!mounted) return;
    final containerId = _isContainerAlbum
        ? catalogueSongId(_containerRow?.songId)
        : null;
    if (containerId != null) {
      RewampDb.getSongContext(containerId).then((c) {
        if (mounted && c != null && c.subsongScores.isNotEmpty) {
          setState(() => _subsongScores = c.subsongScores);
        }
      });
    }
    // Fallback: server returned nothing usable but the album is on disk (e.g. a
    // library item whose collection/platform is incomplete) → use local records.
    if (_tracks.isEmpty) {
      await _tryLoadLocalAlbum();
    }
  }

  /// Returns true if the album's tracks were loaded from the local DB.
  Future<bool> _tryLoadLocalAlbum() async {
    if (widget.onPlayLocalAlbum == null) return false;
    final tracks = await LocalDb.instance
        .getTracksForAlbum(widget.albumName, albumId: widget.albumId);
    if (tracks.isEmpty) return false;
    // Confirm the files are actually on disk before committing to local mode.
    if (!await File(tracks.first.filePath).exists()) return false;
    if (!mounted) return false;

    // On-disk sizes. Sum DISTINCT files (multi-subsong containers like RSN/NSF
    // share one file across many tracks — count it once). Per-track size is only
    // shown for one-file-per-track albums; for shared-file albums it's omitted to
    // avoid showing the whole-container size on every subsong.
    final distinctFiles = {for (final t in tracks) t.filePath};
    final allSameFile = distinctFiles.length <= 1;
    final sizeOf = <String, int>{};
    int localBytes = 0;
    for (final path in distinctFiles) {
      try {
        final n = File(path).statSync().size;
        sizeOf[path] = n;
        localBytes += n;
      } catch (_) {}
    }

    setState(() {
      _localAlbum = true;
      _localBytes = localBytes;
      _localTracks
        ..clear()
        ..addAll(tracks);
      _tracks
        ..clear()
        ..addAll(tracks.map((t) => _localToSearchResult(
              t, allSameFile ? 0 : (sizeOf[t.filePath] ?? 0))));
      _total           = tracks.length;
      _offset          = tracks.length;
      _hasMore         = false;
      _tracksLoading   = false;
      _albumDownloaded = true; // local mode only runs when files are on disk
    });
    return true;
  }

  SearchResult _localToSearchResult(TrackRecord t, [int fileSize = 0]) => SearchResult(
        songId:       t.onlineId ?? t.id,
        collection:   widget.collectionSlug ?? '',
        title:        t.displayTitle,
        filename:     t.filePath.split(Platform.pathSeparator).last,
        album:        t.metaAlbum ?? widget.albumName,
        formatExt:    t.formatExt ?? '',
        downloadUrl:  null,
        fileSize:     fileSize,
        year:         null,
        artistNames:  t.artist != null ? [t.artist!] : const [],
        totalCount:   0,
        platform:     widget.platformName,
        artworkUrl:   t.artworkUrl,
        trackPosition: t.position,
        subsongIdx:   t.subsongIdx,
      );

  @override
  void dispose() {
    LocalDb.instance.removeListener(_onLocalDbChanged);
    DownloadManager.instance.removeListener(_onLocalDbChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() {}); // rebuild title opacity
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMoreTracks();
    }
  }

  Future<void> _loadDetails() async {
    try {
      final list = await RewampDb.fetchAlbumDetails(
        widget.albumName,
        platformName:   widget.platformName,
        collectionSlug: widget.collectionSlug,
        albumId:        widget.albumId,  // authoritative → exact album, no .first guess
      );
      if (!mounted) return;
      setState(() {
        _details        = list.isNotEmpty ? list.first : null;
        _detailsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _detailsLoading = false);
    }
  }

  /// Fetch this album's tracks. Prefers get_album_tracks(albumId) for an exact
  /// match (disambiguates same-named albums); falls back to browse-by-name when
  /// no albumId was passed (older nav paths / library entries).
  Future<List<SearchResult>> _fetchAlbumTracks({
    required String sortBy,
    required int limit,
    required int offset,
  }) {
    final id = widget.albumId;
    if (id != null && id.isNotEmpty) {
      return RewampDb.albumTracks(
          albumId: id, sortBy: sortBy, limit: limit, offset: offset);
    }
    return RewampDb.browse(
      albumName:  widget.albumName,
      collection: widget.collectionSlug,
      platform:   widget.platformName,
      sortBy:     sortBy,
      limit:      limit,
      offset:     offset,
    );
  }

  Future<void> _loadTracks(int offset) async {
    try {
      final res = await _fetchAlbumTracks(
        sortBy: 'position',
        limit:  50,
        offset: offset,
      );
      if (!mounted) return;

      // Container album: the server lists a single multi-subsong file (e.g. a
      // joshw NSF/GBS). Expand from disk when already downloaded. Otherwise, if
      // the server carries the per-subsong tracklist (`subsongs` JSONB), list
      // those tracks straight away (titles/durations, no download); only when
      // the tracklist is unknown do we fall back to the "download to see the
      // tracks" placeholder. Opening the screen must NOT download anything.
      if (offset == 0 &&
          res.length == 1 &&
          RewampDb.isContainerRow(res.first)) {
        final container = res.first;
        final cached = await RewampDb.isContainerDownloaded(container);
        if (!mounted) return;
        if (cached) {
          setState(() {
            _isContainerAlbum = true;
            _containerDownloaded = true;
            _containerRow = container;
          });
          // Tracklist serveur connue → l'AFFICHAGE se construit sans toucher
          // au réseau: mêmes lignes que le préview, pointées sur le dossier
          // local. _expandContainer (→ expandContainerAlbum) est un chemin
          // d'EXTRACTION — depuis le lecteur (« Voir l'album »), il relançait
          // un téléchargement complet quand l'album avait été remplacé côté
          // serveur, avant même d'afficher quoi que ce soit. L'extraction et
          // sa détection de péremption appartiennent au PLAY.
          if (container.subsongs.isNotEmpty) {
            final dir =
                p.dirname(await RewampDb.localPath(container));
            final rows =
                RewampDb.subsongRowsFromServer(container, extractedDir: dir);
            if (!mounted) return;
            setState(() {
              _tracks..clear()..addAll(rows);
              _total           = rows.length;
              _offset          = rows.length;
              _hasMore         = false;
              _tracksLoading   = false;
              // isContainerDownloaded a déjà répondu oui — les DEUX drapeaux,
              // comme l'ancien _expandContainer: l'icône de téléchargement
              // au niveau ALBUM lit _albumDownloaded, et l'oublier la
              // laissait affichée sur un album déjà sur disque.
              _albumDownloaded = true;
            });
            return;
          }
          await _expandContainer(container);
          return;
        }
        // Server tracklist known → show the subsongs now (pre-download preview).
        if (container.subsongs.isNotEmpty) {
          final preview = RewampDb.subsongRowsFromServer(container);
          setState(() {
            _tracks..clear()..addAll(preview);
            _total               = preview.length;
            _offset              = preview.length;
            _hasMore             = false;
            _tracksLoading       = false;
            _isContainerAlbum    = true;
            _containerDownloaded = false;
            _containerRow        = container;
          });
          return;
        }
        // Unknown tracklist → placeholder; expand after a user-initiated download.
        setState(() {
          _tracks..clear()..add(container);
          _total               = 1;
          _offset              = 1;
          _hasMore             = false;
          _tracksLoading       = false;
          _isContainerAlbum    = true;
          _containerDownloaded = false;
          _containerRow        = container;
        });
        return;
      }

      final isPsf = RewampDb.isPsfArchiveAlbum(res);
      final psfDone = isPsf ? await RewampDb.isPsfAlbumDownloaded(res) : false;

      // PSF archive already on disk: the server only lists the 7z as one row,
      // so expand it into the real per-file track list straight from disk
      // (downloadPsfAlbum skips the network when already downloaded). Otherwise
      // re-entering the screen would show a single "<album>" track.
      if (offset == 0 && isPsf && psfDone) {
        final expanded = await RewampDb.downloadPsfAlbum(res);
        if (!mounted) return;
        setState(() {
          _tracks..clear()..addAll(expanded);
          _total              = expanded.length;
          _offset             = expanded.length;
          _hasMore            = false;
          _tracksLoading      = false;
          _isPsfArchiveAlbum  = true;
          _psfAlbumDownloaded = true;
          _albumDownloaded    = true;
        });
        return;
      }

      setState(() {
        if (offset == 0) {
          _tracks.clear();
          _total = res.isEmpty ? 0 : res.first.totalCount;
        }
        _tracks.addAll(res);
        _offset       = _tracks.length;
        _hasMore      = _total > 0 && _offset < _total;
        _tracksLoading = false;
        if (offset == 0) {
          _isPsfArchiveAlbum  = isPsf;
          _psfAlbumDownloaded = psfDone;
        }
      });
      if (offset == 0) _refreshDownloadedState();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tracksLoading = false;
        if (offset == 0) _error = e.toString();
      });
    }
  }

  /// Album favourited: persist its FULL track list into the local `tracks`
  /// table (the Favoris playlist reads `tracks WHERE meta_album = <name>`,
  /// which is otherwise only fed at play time — a fresh favourite showed just
  /// the track that happened to be playing). Loads any remaining server pages
  /// first so a paginated album (>50 rows) materializes completely. The
  /// screen's _tracks is already expanded for downloaded PSF/container albums
  /// (real extracted paths) and for server-tracklist previews; materialize
  /// handles the container-row case itself. No network downloads.
  Future<void> _materializeFavoriteTracks() async {
    try {
      var guard = 0;
      while (_hasMore && !_localAlbum && guard++ < 40) {
        await _loadTracks(_offset);
      }
      if (_tracks.isEmpty) return;
      await RewampDb.materializeAlbumTracks(
        widget.albumName,
        List.of(_tracks),
        albumId: widget.albumId,
      );
    } catch (_) {/* favourite itself succeeded; list just stays played-only */}
  }

  /// Downloads + probes a single container file and replaces the track list
  /// with one row per subsong.  Shows the spinner while it runs.
  Future<void> _expandContainer(SearchResult container) async {
    try {
      final expanded = await RewampDb.expandContainerAlbum(container);
      if (!mounted) return;
      setState(() {
        _tracks
          ..clear()
          ..addAll(expanded);
        _total         = expanded.length;
        _offset        = expanded.length;
        _hasMore       = false;
        _tracksLoading = false;
        if (expanded.isNotEmpty && expanded.first.artistNames.isNotEmpty) {
          _m3uArtistNames = expanded.first.artistNames;
        }
        _albumDownloaded = true; // container is fetched + probed = on disk
        _containerDownloaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tracksLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMoreTracks() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _fetchAlbumTracks(
        sortBy:     'position',
        limit:      50,
        offset:     _offset,
      );
      if (!mounted) return;
      setState(() {
        _tracks.addAll(more);
        _offset  = _tracks.length;
        _hasMore = _offset < _total;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }


  /// Resolves the full track list and downloads/extracts the album if needed
  /// (PSF 7z or standard ZIP). Returns the (possibly reordered/expanded) song
  /// list, or null on failure. Shows a modal progress dialog while downloading.
  Future<List<SearchResult>?> _ensureDownloaded({bool force = false}) async {
    var songs = _hasMore
        ? await _fetchAlbumTracks(
            sortBy:     'position',
            limit:      500,
            offset:     0,
          )
        : List<SearchResult>.from(_tracks);

    // Force = start clean: wipe the album folder AND its local-DB rows so the
    // fresh download rewrites correct files + metadata (stale rows from old
    // bugs otherwise keep polluting « écoutés récemment »).
    if (force && songs.isNotEmpty) {
      try {
        final dir = p.dirname(
            await RewampDb.localPath(_containerRow ?? songs.first));
        await RewampDb.deleteLocalAlbumDir(dir);
      } catch (_) {}
      // Container albums: the expanded rows point at deleted files — refetch
      // the server row so the container branch re-downloads and re-expands.
      if (_isContainerAlbum) {
        songs = await _fetchAlbumTracks(
            sortBy: 'position', limit: 500, offset: 0);
      }
      if (mounted) {
        setState(() {
          _psfAlbumDownloaded  = false;
          _containerDownloaded = false;
          _downloadRevision++;
        });
      }
    }

    // Container album not yet on disk: download + expand now (user-initiated).
    if (_isContainerAlbum && !_containerDownloaded && songs.isNotEmpty) {
      if (!mounted) return null;
      try {
        // Expand from the real container row (not a preview subsong row) so the
        // resulting songIds match the pre-download preview.
        final expanded =
            await RewampDb.expandContainerAlbum(_containerRow ?? songs.first);
        songs = expanded;
        if (mounted) {
          setState(() {
            _tracks..clear()..addAll(expanded);
            _total  = expanded.length;
            _offset = expanded.length;
            _hasMore = false;
            _containerDownloaded = true;
            _albumDownloaded = true;
            if (expanded.isNotEmpty && expanded.first.artistNames.isNotEmpty) {
              _m3uArtistNames = expanded.first.artistNames;
            }
            _downloadRevision++;
          });
        }
      } catch (_) {
        // Fall through — placeholder stays.
      }
      return songs;
    }

    // PSF archive album: download + extract 7z if needed.
    if (_isPsfArchiveAlbum && songs.isNotEmpty) {
      if (force || !_psfAlbumDownloaded) {
        if (!mounted) return null;
        try {
          songs = await RewampDb.downloadPsfAlbum(songs, force: force);
          if (mounted) {
            setState(() {
            _psfAlbumDownloaded = true;
            _tracks
              ..clear()
              ..addAll(songs);
            _total  = songs.length;
            _offset = songs.length;
            _hasMore = false;
            _downloadRevision++;
          });
          }
        } catch (_) {
          // Fall through.
        }
      }
    }
    // Non-PSF ZIP albums (RSN, SID zip, etc.)
    else {
      final zipUrl = _details?.zipUrl;
      if (zipUrl != null && songs.isNotEmpty) {
        if (force ||
            (!await _trackFileCached(songs.first) && !await _albumCached(songs.first))) {
          if (!mounted) return null;
          try {
            final reordered = await RewampDb.downloadAndExtractZip(zipUrl, songs,
                mirrorZipUrl: _details?.mirrorZipUrl, albumId: widget.albumId);
            if (reordered != null) songs = reordered;
            if (mounted) setState(() => _downloadRevision++);
          } catch (_) {
          }
        }
      }
      // Multi-file albums with no zip (modland/hvsc/asma) are NOT bulk-downloaded
      // here: playback starts on the first/selected track and the rest prefetch
      // in the background (see _prefetchRemaining, called after onPlayAlbum). The
      // explicit "Télécharger" button downloads everything via _downloadAllFiles.
    }
    return songs;
  }

  /// True for a real one-file-per-track album with no album archive (modland /
  /// hvsc / asma folder tree) — where each track must be fetched individually.
  bool get _isMultiFileAlbum =>
      !_isContainerAlbum &&
      !_isPsfArchiveAlbum &&
      (_details?.zipUrl == null) &&
      !_sharedFileAlbum;

  /// Background prefetch of every not-yet-cached album file — handed to the
  /// DownloadManager queue (visible, pausable, editable) instead of an inline
  /// loop. [skip] is the just-started track (already being fetched by the
  /// play path).
  Future<void> _prefetchRemaining(List<SearchResult> songs,
      {SearchResult? skip}) async {
    if (!_isMultiFileAlbum) return;
    for (final s in songs) {
      if (skip != null && s.songId == skip.songId) continue;
      if (await _trackFileCached(s)) continue;
      DownloadManager.instance.enqueue(
        s.displayTitle,
        () => RewampDb.downloadToLibrary(s).then((_) {}),
        artworkUrl: s.artworkUrl,
        key: '${s.songId}|${s.filename}',
      );
    }
    // Per-file completion refresh + the final _albumDownloaded flip both ride
    // the manager listener (_onDownloadQueueChanged).
  }

  /// Explicit "download the whole album" (the Télécharger button): every
  /// missing file goes to the DownloadManager queue — non-blocking, visible
  /// and pausable from the queue screen. No-op when all are cached.
  Future<void> _downloadAllFiles(List<SearchResult> songs,
      {bool force = false}) async {
    for (final s in songs) {
      if (!force && await _trackFileCached(s)) continue;
      DownloadManager.instance.enqueue(
        s.displayTitle,
        () => RewampDb.downloadToLibrary(s).then((_) {}),
        artworkUrl: s.artworkUrl,
        key: '${s.songId}|${s.filename}',
      );
    }
  }

  /// Stamps the authoritative server album id onto every track that lacks one,
  /// so the player can offer "Voir l'album" (and route back to this album) even
  /// when the tracks were fetched from a source that didn't carry album_id —
  /// e.g. a cached .rsn launched from the library, whose download+stamp step is
  /// skipped.
  List<SearchResult> _stampAlbumId(List<SearchResult> songs) {
    final aid = widget.albumId;
    if (aid == null || aid.isEmpty) return songs;
    return [
      for (final s in songs)
        (s.albumId == null || s.albumId!.isEmpty) ? s.withAlbumId(aid) : s,
    ];
  }

  Future<void> _playAll({bool forceDownload = false}) async {
    // Local album: play from on-disk records via the local queue.
    if (_localAlbum && widget.onPlayLocalAlbum != null) {
      if (_localTracks.isEmpty) return;
      await widget.onPlayLocalAlbum!(context, _localTracks);
      return;
    }
    if (widget.onPlayAlbum == null || _playingAll) return;
    setState(() => _playingAll = true);
    try {
      var songs = await _ensureDownloaded(force: forceDownload);
      await _refreshDownloadedState();
      if (songs == null || !mounted) return;
      songs = _stampAlbumId(songs);
      await widget.onPlayAlbum!(context, songs);
      // Play started on track 0 (fetched by the play path); pull the rest in the
      // background for a one-file-per-track (modland) album.
      unawaited(_prefetchRemaining(songs,
          skip: songs.isNotEmpty ? songs.first : null));
    } finally {
      if (mounted) setState(() => _playingAll = false);
    }
  }

  /// Downloads (or re-downloads) the album without starting playback.
  Future<void> _downloadAlbumOnly({bool force = false}) async {
    if (_playingAll) return;
    // Archive albums (PSF 7z, zip, single container): ONE job in the
    // DownloadManager queue — visible, pausable, non-blocking. The PLAY path
    // keeps its direct download in _ensureDownloaded (a track about to play
    // must not wait behind a paused queue). Completion reaches this screen
    // through the manager listener → _refreshDownloadedState's disk probes.
    final zipUrl = _details?.zipUrl;
    if (_isPsfArchiveAlbum || _isContainerAlbum || zipUrl != null) {
      final songs = List<SearchResult>.from(_tracks);
      if (songs.isEmpty) return;
      final psf       = _isPsfArchiveAlbum;
      final container = _isContainerAlbum ? (_containerRow ?? songs.first) : null;
      DownloadManager.instance.enqueue(
        widget.albumName,
        () async {
          if (psf) {
            await RewampDb.downloadPsfAlbum(songs, force: force);
          } else if (container != null) {
            await RewampDb.expandContainerAlbum(container, force: force);
          } else {
            await RewampDb.downloadAndExtractZip(zipUrl!, songs,
                mirrorZipUrl: _details?.mirrorZipUrl,
                albumId: widget.albumId);
          }
        },
        artworkUrl: _effectiveArtworkUrl,
        key: 'album|${widget.albumId ?? widget.albumName}',
      );
      return;
    }
    setState(() => _playingAll = true);
    try {
      final songs = await _ensureDownloaded(force: force);
      // Multi-file albums (modland/…) aren't bulk-fetched by _ensureDownloaded —
      // the explicit button queues all of them here.
      if (songs != null && _isMultiFileAlbum) {
        await _downloadAllFiles(songs, force: force);
      }
      await _refreshDownloadedState();
    } finally {
      if (mounted) setState(() => _playingAll = false);
    }
  }

  /// Tapping a track starts the full album queue from that track's position.
  /// If the album has a ZIP and the file isn't cached, downloads the whole
  /// pack first so every track becomes instantly available.
  Future<void> _onTrackTap(BuildContext ctx, SearchResult r) async {
    // The blocking "downloading…" modal is gone (the global DownloadBanner
    // carries the feedback, the UI stays usable) — so THIS is now the only
    // thing preventing a second tap from starting a second archive download.
    if (_playingAll) return;
    _playingAll = true;
    try {
      await _onTrackTapImpl(ctx, r);
    } finally {
      _playingAll = false;
    }
  }

  Future<void> _onTrackTapImpl(BuildContext ctx, SearchResult r) async {
    // PAS de popup ici: on est DANS l'album, et le tap initialise la file avec
    // ses pistes en démarrant sur celle-ci. La popup sert aux taps qui
    // écraseraient la file par surprise (un rail, une liste de recherche, les
    // stats); ouvrir un album puis toucher une piste EST la demande de le jouer.
    // Local album: play straight from the on-disk records via the local queue.
    if (_localAlbum && widget.onPlayLocalAlbum != null) {
      final idx = _tracks.indexOf(r).clamp(0, _localTracks.length - 1);
      await widget.onPlayLocalAlbum!(ctx, _localTracks, startIndex: idx);
      return;
    }

    // Container album (one .gbs/.nsf holding N subsongs): the tapped row may be
    // a pre-download preview from the server tracklist. Ensure the container is
    // downloaded + expanded, then play the tapped subsong from the result. The
    // expansion reuses the same songId scheme, so r resolves by songId.
    if (_isContainerAlbum) {
      final expanded = await _ensureDownloaded();
      if (!ctx.mounted) return;
      final list = expanded ?? List<SearchResult>.from(_tracks);
      final startIdx =
          list.indexWhere((s) => s.songId == r.songId).clamp(0, list.length - 1);
      if (widget.onPlayAlbum != null) {
        await widget.onPlayAlbum!(ctx, list, startIndex: startIdx);
      } else {
        await widget.onTap(ctx, r);
      }
      return;
    }

    // 1. Resolve the complete track list (for proper prev/next coverage).
    // PSF archive albums use local extracted filenames — never re-fetch from
    // server, which would give the wrong filenames/paths.
    var songs = (!_isPsfArchiveAlbum && _hasMore)
        ? await _fetchAlbumTracks(
            sortBy:     'position',
            limit:      500,
            offset:     0,
          )
        : List<SearchResult>.from(_tracks);
    if (songs.isEmpty) songs = List<SearchResult>.from(_tracks);

    // 2. If not cached, download — PSF archive or standard ZIP.
    if (_isPsfArchiveAlbum && songs.isNotEmpty) {
      if (!_psfAlbumDownloaded) {
        if (!ctx.mounted) return;
        try {
          songs = await RewampDb.downloadPsfAlbum(songs);
          if (mounted) {
            setState(() {
            _psfAlbumDownloaded = true;
            _tracks..clear()..addAll(songs);
            _total  = songs.length;
            _offset = songs.length;
            _hasMore = false;
            _downloadRevision++;
          });
          }
        } catch (_) {
        }
      }
    } else {
      final zipUrl = _details?.zipUrl;
      if (zipUrl != null && songs.isNotEmpty) {
        if (!await _trackFileCached(r) && !await _albumCached(r)) {
          if (!ctx.mounted) return;
          try {
            final reordered = await RewampDb.downloadAndExtractZip(zipUrl, songs,
                mirrorZipUrl: _details?.mirrorZipUrl, albumId: widget.albumId);
            if (reordered != null) songs = reordered;
            if (mounted) setState(() => _downloadRevision++);
          } catch (_) {
          }
        }
      }
    }

    // Downloading here may have put the album on disk — refresh the download
    // state so the "Télécharger" icon disappears and "Re-télécharger" appears.
    await _refreshDownloadedState();

    if (!ctx.mounted) return;

    songs = _stampAlbumId(songs);

    // 3. Find the tapped track by songId in the (potentially reordered) list.
    final startIdx =
        songs.indexWhere((s) => s.songId == r.songId).clamp(0, songs.length - 1);

    if (widget.onPlayAlbum != null) {
      await widget.onPlayAlbum!(ctx, songs, startIndex: startIdx);
      // Start on the tapped track (fetched by the play path); prefetch the rest
      // in the background for a one-file-per-track (modland) album.
      unawaited(_prefetchRemaining(songs, skip: r));
    } else {
      // No album callback (e.g. browse screen) — play the single track.
      await widget.onTap(ctx, r);
    }
  }

  /// True when this album already has a cached file on disk, matched by server
  /// album_id (falling back to album name). Robust for containers like .rsn,
  /// whose subsongs all share one file and whose per-track online_id may not
  /// line up between a fresh server fetch and the persisted rows — the reason a
  /// downloaded .rsn re-downloaded when relaunched from the library.
  Future<bool> _albumCached([SearchResult? first]) async {
    // RSN: the whole album is a single .rsn saved at a path derived purely from
    // the first track (collection/artist/platform/album) — identical inputs give
    // the identical path, so checking it is the most reliable "downloaded?" probe
    // (no album_id / online_id / meta-name matching needed). This is the case
    // that kept re-downloading when relaunched from the library.
    final zip = _details?.zipUrl?.toLowerCase();
    final firstTrack = first ?? (_tracks.isNotEmpty ? _tracks.first : null);
    if (zip != null && zip.endsWith('.rsn') && firstTrack != null) {
      final rsnPath = await RewampDb.rsnLocalPath(firstTrack);
      if (await File(rsnPath).exists()) return true;
    }
    // Generic fallback: any file recorded for this album (by id or name).
    final name = firstTrack?.album ?? widget.albumName;
    final paths = await LocalDb.instance
        .albumCachedFilePaths(albumId: widget.albumId, metaAlbum: name);
    for (final fp in paths) {
      if (await File(fp).exists()) return true;
    }
    return false;
  }

  /// Returns true if [r] is already on disk.
  /// For RSN/archive tracks (no downloadUrl) the real local file is the .rsn
  /// container stored under the DB record's filePath, not the SPC-derived path
  /// that RewampDb.localPath() would compute. Check the DB first.
  static Future<bool> _trackFileCached(SearchResult r) async {
    // Row synthesized from an already-extracted file: it IS the cache.
    if (r.localPath != null && await File(r.localPath!).exists()) return true;
    final rec = await LocalDb.instance.getTrackByOnlineId(r.songId);
    if (rec != null && await File(rec.filePath).exists()) return true;
    // Fallback: check the standard computed path (non-RSN tracks).
    if (r.downloadUrl != null) {
      final path = await RewampDb.localPath(r);
      return File(path).exists();
    }
    return false;
  }

  /// Recomputes [_albumDownloaded] for any album type: PSF archives use the
  /// dedicated flag; other albums are considered downloaded when their first
  /// track file is on disk (proxy for the whole pack/zip).
  Future<void> _refreshDownloadedState() async {
    bool done;
    if (_isPsfArchiveAlbum) {
      // Disk probe, not only the flag: the archive may have been fetched by a
      // queued DownloadManager job, which never touches this screen's state.
      done = _psfAlbumDownloaded ||
          (_tracks.isNotEmpty &&
              await RewampDb.isPsfAlbumDownloaded(_tracks));
      _psfAlbumDownloaded = done;
    } else if (_isContainerAlbum) {
      done = _containerDownloaded ||
          (_containerRow != null && await _trackFileCached(_containerRow!));
    } else if (_tracks.isEmpty) {
      done = false;
    } else if (_isMultiFileAlbum) {
      // One-file-per-track album: "downloaded" only once EVERY file is on disk
      // (so the download button hides only when the background prefetch finishes,
      // not after the first track). (Paginated tail beyond the loaded page isn't
      // counted — modland albums typically fit one page.)
      done = true;
      for (final t in _tracks) {
        if (!await _trackFileCached(t)) { done = false; break; }
      }
    } else {
      done = await _trackFileCached(_tracks.first) || await _albumCached(_tracks.first);
    }
    if (mounted && done != _albumDownloaded) {
      setState(() => _albumDownloaded = done);
    }
  }

  String? get _effectiveArtworkUrl =>
      _details?.artworkUrl ?? widget.artworkUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;

    // Fade the app-bar title in only once the artwork has scrolled away.
    const expandedHeight = 280.0;
    const toolbarHeight  = 56.0;
    final scrollOffset   = _scroll.hasClients ? _scroll.offset : 0.0;
    final titleOpacity   = ((scrollOffset - (expandedHeight - toolbarHeight)) / toolbarHeight)
        .clamp(0.0, 1.0);

    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          // ── Artwork header ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: expandedHeight,
            pinned: true,
            leading: const Padding(
              padding: EdgeInsets.all(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: BackButton(color: Colors.white),
              ),
            ),
            title: Opacity(
              opacity: titleOpacity,
              child: Text(
                widget.albumName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Blurred fill background
                  if (_effectiveArtworkUrl != null) ...[
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: ArtworkImage(
                        url:    _effectiveArtworkUrl,
                        album:  widget.albumName,
                        artist: _effectiveComposerNames.firstOrNull,
                        fit:    BoxFit.cover,
                        placeholder: Container(color: cs.primaryContainer),
                      ),
                    ),
                    Container(color: Colors.black.withValues(alpha: 0.20)),
                    ArtworkImage(
                      url:    _effectiveArtworkUrl,
                      album:  widget.albumName,
                      artist: _effectiveComposerNames.firstOrNull,
                      fit:    BoxFit.contain,
                      placeholder: Container(
                        color: cs.primaryContainer,
                        child: Icon(Icons.album, size: 80,
                            color: cs.onPrimaryContainer),
                      ),
                    ),
                  ] else
                    // No cover at all → themed per-platform placeholder
                    // (rewamp sun in the album format's origin-platform colours).
                    ArtworkImage(
                      url:        null,
                      formatHint: _tracks.isNotEmpty ? _tracks.first.formatExt : null,
                      fit:        BoxFit.cover,
                    ),
                ],
              ),
            ),
          ),

          // ── Metadata + Play All ───────────────────────────────────────
          SliverToBoxAdapter(child: _buildMeta(cs)),

          // ── Tracks ───────────────────────────────────────────────────
          if (_tracksLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red)),
              ),
            )
          else ...[
            // PSF / container archive — not yet downloaded placeholder
            if (((_isPsfArchiveAlbum && !_psfAlbumDownloaded) ||
                    (_isContainerAlbum && !_containerDownloaded)) &&
                _tracks.length == 1 && _tracks.first.trackPosition == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.download_outlined, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        l10n.albumDownloadToSeeTracks,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _playingAll ? null : () => _downloadAlbumOnly(),
                        icon: _playingAll
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.download),
                        label: Text(l10n.commonDownload),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
            // PSF banner — files not yet downloaded but track list known
            if (_isPsfArchiveAlbum && !_psfAlbumDownloaded)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Card(
                    color: cs.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(children: [
                        Icon(Icons.info_outline,
                            size: 18, color: cs.onSecondaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.albumNotDownloadedHint,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSecondaryContainer),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(children: [
                  Builder(builder: (_) {
                    final bytes = _localAlbum
                        ? _localBytes
                        : _tracks.fold<int>(0, (s, t) => s + t.totalFileSize);
                    final label = bytes > 0
                        ? '${l10n.albumTrackCount(_total)}  ·  '
                            '${_fmtBytes(l10n, bytes)}'
                        : l10n.albumTrackCount(_total);
                    return Text(label,
                        style: Theme.of(context).textTheme.bodySmall);
                  }),
                  if (_loadingMore) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ]),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  if (i == _tracks.length) {
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _loadMoreTracks());
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _AlbumTrackTile(
                    index:            i + 1,
                    result:           _tracks[i],
                    subsongScore:
                        _subsongScores[_tracks[i].subsongIdx],
                    onTap:            _onTrackTap,
                    downloadRevision: _downloadRevision,
                    // Local album: every track is guaranteed on disk. A PSF
                    // archive is NOT forced any more — its rows carry the real
                    // extracted localPath, so the per-file check tells a deleted
                    // track apart from a present one (else a deleted row kept the
                    // downloaded badge). Re-checked on _downloadRevision bumps.
                    forceLocal:       _localAlbum,
                    onNavigateArtist: widget.onArtistTap != null
                        ? (name, {collection, artistId}) =>
                            widget.onArtistTap!(name)
                        : null,
                    onQueueAdd:       widget.onQueueAdd,
                    sharedFileAlbum:  _sharedFileAlbum,
                  );
                },
                childCount: _tracks.length + (_hasMore ? 1 : 0),
              ),
            ),
            // Description — after track list
            if (_details?.description != null &&
                _details!.description!.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Text(
                    _details!.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ], // end else (known track list or not-PSF)
          ],
          // Room for the floating chrome (see shellInsetSliver).
          shellInsetSliver(context),
        ],
      ),
    );
  }

  Widget _buildMeta(ColorScheme cs) {
    final l10n = context.l10n;
    final d    = _details;
    final tt   = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album title — always shown immediately below artwork.
          Text(
            widget.albumName,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          if (_detailsLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(l10n.albumLoadingInfo),
              ]),
            )
          else if (d != null) ...[
            // Platform / year — shown as coloured subtitle next to title.
            if (d.platform != null || d.year != null) ...[
              Text(
                [
                  if (d.platform != null) d.platform!,
                  if (d.year     != null) d.year.toString(),
                ].join(' · '),
                style: tt.bodyMedium?.copyWith(color: cs.primary),
              ),
              const SizedBox(height: 4),
            ],

            // Note de l'album (migrations serveur 207/208). 2,5 = la moyenne du
            // catalogue, pas « la moitié » — et `null` n'est PAS zéro: zéro
            // voudrait dire « écouté et rejeté par tous », alors que null veut
            // dire « moins de 5 auditeurs ». On ne montre donc rien du tout
            // dans ce cas, ce qui sera le cas de la quasi-totalité du
            // catalogue au début.
            if (d.rating != null) ...[
              Row(children: [
                Icon(Icons.star_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 3),
                Text(d.rating!.toStringAsFixed(1), style: tt.bodySmall),
                if ((d.ratingCount ?? 0) > 0) ...[
                  Text('  ·  ',
                      style: tt.bodySmall?.copyWith(color: cs.outline)),
                  Text(l10n.ratingVotes(d.ratingCount!),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ]),
              const SizedBox(height: 4),
            ],

            // Competition podium of the album (mig 186) — gold/silver/bronze
            // cup plus the compo it placed in. Tapping opens that competition,
            // same target as the badge on the listings.
            if (d.podium != null) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => openPodium(context, d.podium!),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.emoji_events,
                      size: 18, color: podiumColor(context, d.podium!.rank)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      podiumLabel(context, d.podium!),
                      style: tt.bodySmall?.copyWith(
                          color: podiumColor(context, d.podium!.rank)),
                    ),
                  ),
                ]),
              ),
            ],

            // Aliases
            if (d.aliases.isNotEmpty) ...[
              const SizedBox(height: 4),
              for (final alias in d.aliases)
                Text(
                  l10n.albumAka(alias.label),
                  style: tt.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],

            // Demozoo productions this album comes from (mig 163) — e.g. the
            // musicdisk a modland folder rips. Tap opens that production.
            if (d.productions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final prod in d.productions)
                    ActionChip(
                      avatar: const Icon(Icons.movie_outlined, size: 14),
                      label: Text(prod.label,
                          style: const TextStyle(fontSize: 12)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => openProduction(context, prod),
                    ),
                ],
              ),
            ],

            // Chip names
            if (d.chipNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: d.chipNames
                    .map((c) => Chip(
                          label: Text(c,
                              style: const TextStyle(fontSize: 12)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                        ))
                    .toList(),
              ),
            ],

            // Composers (tappable when onArtistTap is provided)
            if (_effectiveComposerNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              widget.onArtistTap != null
                  ? Wrap(
                      spacing: 0,
                      children: [
                        for (int i = 0; i < _effectiveComposerNames.length; i++) ...[
                          GestureDetector(
                            onTap: () =>
                                widget.onArtistTap!(_effectiveComposerNames[i]),
                            child: Text(
                              _effectiveComposerNames[i],
                              style: tt.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: cs.primary,
                                decoration: TextDecoration.underline,
                                decorationColor: cs.primary,
                              ),
                            ),
                          ),
                          if (i < _effectiveComposerNames.length - 1)
                            Text(', ',
                                style: tt.bodySmall
                                    ?.copyWith(fontStyle: FontStyle.italic)),
                        ],
                      ],
                    )
                  : Text(
                      _effectiveComposerNames.join(', '),
                      style: tt.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic),
                    ),
            ],

            const SizedBox(height: 10),
          ],

          // Play All + star + "..." row
          Row(
            children: [
              if (widget.onPlayAlbum != null)
                FilledButton.icon(
                  onPressed: _playingAll ? null : _playAll,
                  icon: _playingAll
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(l10n.albumPlayAlbum),
                ),
              // Download-only button next to play, shown until the album is on disk.
              if (!_albumDownloaded && !_localAlbum)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    icon: const Icon(Icons.download),
                    tooltip: l10n.commonDownload,
                    onPressed: _playingAll ? null : () => _downloadAlbumOnly(),
                  ),
                ),
              const Spacer(),
              _AlbumFavoriteButton(
                refId:          albumLibraryRefId(
                    widget.albumName, widget.albumId),
                name:           widget.albumName,
                artist:         _effectiveComposerNames.firstOrNull,
                artworkUrl:     _effectiveArtworkUrl,
                collectionSlug: widget.collectionSlug,
                platformName:   widget.platformName,
                albumId:        widget.albumId,
                onFavorited:    _materializeFavoriteTracks,
              ),
              LibraryButton(
                type:           'album',
                refId:          albumLibraryRefId(
                    widget.albumName, widget.albumId),
                name:           widget.albumName,
                albumId:        widget.albumId,
                artworkUrl:     _effectiveArtworkUrl,
                artist:         _effectiveComposerNames.firstOrNull,
                collectionSlug: widget.collectionSlug,
                platformName:   widget.platformName,
                // Route through the screen's own download logic: it knows the
                // album type (container/PSF/zip/multi-file) and skips when the
                // files are already on disk. The old per-track downloadToLibrary
                // fallback threw on container subsong rows (no per-track
                // downloadUrl) and flashed "Téléchargement impossible" even
                // though the album was already downloaded and playing.
                onDownload:     _albumDownloaded
                    ? null
                    : () => _downloadAlbumOnly(),
              ),
              // Always shown: screens that don't thread onAlbumQueueAdd
              // (search results, artist screen, …) fall back to the global
              // queue hooks inside showAlbumOptions — gating the button on
              // the threaded callback hid the whole menu (favourite,
              // playlist, queue) outside the library path.
              IconButton(
                icon: const Icon(Icons.more_vert),
                tooltip: l10n.commonOptions,
                onPressed: () => showAlbumOptions(
                  context,
                  widget.albumName,
                  albumId:        widget.albumId,
                  artworkUrl:     _effectiveArtworkUrl,
                  artist:         _effectiveComposerNames.firstOrNull,
                  collectionSlug: widget.collectionSlug,
                  platformName:   widget.platformName,
                  onQueueAddNext: widget.onAlbumQueueAdd == null
                      ? null // → globalOnAlbumQueueAdd
                      : (tracks, {required atEnd, silent = false}) =>
                          widget.onAlbumQueueAdd!(tracks, atEnd: false),
                  onQueueAddAtEnd: widget.onAlbumQueueAdd == null
                      ? null // → globalOnAlbumQueueAdd
                      : (tracks, {required atEnd, silent = false}) =>
                          widget.onAlbumQueueAdd!(tracks, atEnd: true),
                  fetchTracks: () async => List<SearchResult>.from(_tracks),
                  onRedownload: _albumDownloaded
                      ? () => _downloadAlbumOnly(force: true)
                      : null,
                  // Album files just deleted: leave this (now stale) screen.
                  onDeleted: () {
                    if (mounted) Navigator.of(context).maybePop();
                  },
                ),
              ),
            ],
          ),

          const Divider(height: 20),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Track tile — numbered, no artwork (all tracks share the same album artwork)
// ---------------------------------------------------------------------------

class _AlbumTrackTile extends StatefulWidget {
  final int          index;
  final SearchResult result;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final int          downloadRevision;
  final OnNavigateArtist? onNavigateArtist;
  final OnQueueAdd?       onQueueAdd;
  /// Force the "on disk" state without a path check — used for downloaded PSF
  /// archive / local albums where every listed track is on disk by definition
  /// and the computed path may not match the actual extracted location.
  final bool         forceLocal;
  /// One-file-with-subsongs album → hide the per-row file size (shown in header).
  final bool         sharedFileAlbum;
  /// Subsong-grain score of a container album's row (mv_subsong_scores) —
  /// the synthetic preview rows carry no rating/popularity of their own.
  final SubsongScore? subsongScore;

  const _AlbumTrackTile({
    required this.index,
    required this.result,
    required this.onTap,
    required this.downloadRevision,
    this.onNavigateArtist,
    this.onQueueAdd,
    this.forceLocal = false,
    this.sharedFileAlbum = false,
    this.subsongScore,
  });

  @override
  State<_AlbumTrackTile> createState() => _AlbumTrackTileState();
}

class _AlbumTrackTileState extends State<_AlbumTrackTile> {
  bool _isLocal    = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    if (widget.forceLocal) {
      _isLocal = true;
    } else {
      _checkLocal();
    }
    // Live: the star reflects the FAVOURITE flag (not library membership —
    // un-favouriting keeps the library row, but the star must go out), and any
    // LocalDb change (player heart, options sheet) refreshes it in place.
    LocalDb.instance.addListener(_recheckFavorite);
    _recheckFavorite();
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_recheckFavorite);
    super.dispose();
  }

  void _recheckFavorite() {
    final id = widget.result.songId;
    if (id.isEmpty) return;
    LocalDb.instance.isTrackFavoriteAnySubsong(id).then((v) {
      if (mounted && v != _isFavorite) setState(() => _isFavorite = v);
    });
  }

  @override
  void didUpdateWidget(_AlbumTrackTile old) {
    super.didUpdateWidget(old);
    if (widget.forceLocal) {
      if (!_isLocal) setState(() => _isLocal = true);
    } else if (old.downloadRevision != widget.downloadRevision) {
      _checkLocal();
    }
    if (old.result.songId != widget.result.songId) _recheckFavorite();
  }

  Future<void> _checkLocal() async {
    // RSN/archive tracks have no per-SPC file on disk — their real local file is
    // the .rsn, recorded in the DB by online_id. RewampDb.localPath() computes a
    // per-SPC path that never exists, so a downloaded RSN album opened from
    // search read as not-downloaded. Use the same RSN-aware check as the
    // album-level flag (_trackFileCached: localPath → online_id → .rsn → url).
    final ok = await _AlbumDetailScreenState._trackFileCached(widget.result);
    // Reflect the REAL state both ways: a re-check after a delete must be able to
    // turn the badge back OFF, not only ever set it on (or a deleted track keeps
    // the downloaded icon forever).
    if (mounted && ok != _isLocal) setState(() => _isLocal = ok);
  }

  @override
  Widget build(BuildContext context) {
    final r          = widget.result;
    final cs         = Theme.of(context).colorScheme;
    final displayNum = r.trackPosition ?? widget.index;

    final statusIcon = Icon(
      _isLocal ? Icons.offline_pin_rounded : Icons.download_outlined,
      size:  20,
      color: _isLocal ? cs.primary : cs.onSurfaceVariant,
    );

    return ListTile(
      leading: SizedBox(
        width: 32,
        child: Text(
          '$displayNum',
          style: TextStyle(color: cs.onSurfaceVariant),
          textAlign: TextAlign.end,
        ),
      ),
      title: ScrollingText(text: r.displayTitle),
      subtitle: Builder(builder: (_) {
        // Scores: the row's own file-grain pair (mig 207/208, one file per
        // track) when ANY of it exists, else the container's subsong-grain
        // pair. One SOURCE per line, never panached — the two percentile
        // scales must not be mixed.
        final fileGrain = r.rating != null || r.popularity != null;
        final rating = fileGrain ? r.rating : widget.subsongScore?.rating;
        final pop =
            fileGrain ? r.popularity : widget.subsongScore?.popularity;
        final parts = <String>[
          if (r.artistLabel.isNotEmpty) r.artistLabel,
          if (r.formatExt.isNotEmpty) r.formatExt.toUpperCase(),
          // Shared-file albums: size belongs to the file, shown in the header —
          // not on each subsong row (it would sit on row 0 only = confusing).
          if (r.fileSize > 0 && !widget.sharedFileAlbum) r.fileSizeLabel,
          if (rating != null) '★ ${rating.toStringAsFixed(1)}',
          // Percentile = a RANK: only the top of the basket says anything in
          // a listing (same 95 threshold as SongTile), clamp as ever.
          if ((pop ?? 0) >= 95)
            context.l10n.statsTopPercent((100 - pop!).clamp(1, 100)),
        ];
        return parts.isEmpty ? const SizedBox.shrink()
            : ScrollingText(text: parts.join('  ·  '));
      }),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Per-track podium (compo_podium): only the tracks that actually
          // placed carry one, so this is rare and worth the room.
          if (r.podium != null) ...[
            PodiumBadge(r.podium!, size: 15),
            const SizedBox(width: 4),
          ],
          if (_isFavorite)
            const Icon(Icons.star_rounded, size: 15, color: kFavoriteColor),
          statusIcon,
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => showTrackOptions(
              context, r,
              onNavigateArtist: widget.onNavigateArtist,
              onQueueAdd:       widget.onQueueAdd,
            ),
          ),
        ],
      ),
      onTap: () => widget.onTap(context, widget.result),
    );
  }
}

/// Star toggle for an album (library_items type='album', is_favorite flag).
/// A favourite is a library item with is_favorite=1, so favouriting also adds
/// the album to the library. Listens to LocalDb so it reflects external changes.
class _AlbumFavoriteButton extends StatefulWidget {
  final String  refId;
  final String  name;
  final String? artist;
  final String? artworkUrl;
  final String? collectionSlug;
  final String? platformName;
  final String? albumId;
  /// Called after the album is favourited — the parent persists the FULL track
  /// list into the local DB (materialize) so the Favoris playlist shows every
  /// track, not just the played ones.
  final Future<void> Function()? onFavorited;
  const _AlbumFavoriteButton({
    required this.refId,
    required this.name,
    this.artist,
    this.artworkUrl,
    this.collectionSlug,
    this.platformName,
    this.albumId,
    this.onFavorited,
  });

  @override
  State<_AlbumFavoriteButton> createState() => _AlbumFavoriteButtonState();
}

class _AlbumFavoriteButtonState extends State<_AlbumFavoriteButton> {
  bool _fav = false;

  @override
  void initState() {
    super.initState();
    LocalDb.instance.addListener(_recheck);
    _recheck();
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_recheck);
    super.dispose();
  }

  void _recheck() {
    LocalDb.instance
        .isAlbumFavorite(widget.refId, albumId: widget.albumId)
        .then((v) {
      if (mounted && v != _fav) setState(() => _fav = v);
    });
  }

  Future<void> _toggle() async {
    final next = !_fav;
    setState(() => _fav = next);
    await LocalDb.instance.setLibraryItemFavorite(
      'album', widget.refId,
      value:          next,
      name:           widget.name,
      artist:         widget.artist,
      artworkUrl:     widget.artworkUrl,
      collectionSlug: widget.collectionSlug,
      platformName:   widget.platformName,
      albumId:        widget.albumId,
    );
    // Server sync: the server keys albums by UUID (albumId), not the display
    // name in refId. No albumId (local / legacy row) → no server identity, skip.
    //
    // Queued, never POSTed straight: a direct RewampDb.setLibrary drops the
    // gesture when the request fails, and — the reason this was found — it
    // never woke the sync, so the heart itself (a client-state key, unlike the
    // library row) only left the device on the next scheduled run.
    final signedIn = UserSettings.instance.hasAuthToken;
    final aid    = widget.albumId;
    if (signedIn && aid != null && aid.isNotEmpty) {
      await SyncService.recordLibraryChange(
        itemType: 'album', itemId: aid, value: next, favourite: next);
    }
    if (next) await widget.onFavorited?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IconButton(
      icon: Icon(_fav ? Icons.star : Icons.star_border,
          color: _fav ? kFavoriteColor : null),
      tooltip: _fav
          ? l10n.commonRemoveFromFavorites
          : l10n.commonAddToFavorites,
      onPressed: _toggle,
    );
  }
}
