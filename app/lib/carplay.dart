import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'l10n/app_localizations.dart';
import 'local_db.dart';
import 'player_controller.dart';
import 'rewamp_db.dart';
import 'download_cancel.dart';
import 'carplay_voice_search.dart';

/// A new selection or transport skip supersedes the pending download. The
/// cancelled task may still unwind, but it can never clear its successor's UI.
class CarPlayPlayback extends ChangeNotifier {
  DownloadCancelToken? _active;
  bool get busy => _active != null;
  bool get ownsCurrent =>
      _active != null && identical(_active, DownloadCancelToken.current);

  Future<void> run(Future<void> Function() action) async {
    if (ownsCurrent) return action();
    _active?.cancel();
    final token = DownloadCancelToken();
    _active = token;
    notifyListeners();
    try {
      await token.run(action);
      token.throwIfCancelled();
    } catch (_) {
      token.throwIfCancelled(); // A superseded network error is cancellation.
      rethrow;
    } finally {
      if (identical(_active, token)) {
        _active = null;
        notifyListeners();
      }
    }
  }

  void cancel() => _active?.cancel();

  @override
  void dispose() {
    cancel();
    _active = null;
    super.dispose();
  }
}

/// Now Playing uses audio_service's
/// existing MPNowPlayingInfoCenter / MPRemoteCommandCenter integration.
abstract class CarPlayLibrary {
  Future<List<TrackRecord>> tracks(String source);
  Future<List<UserPlaylist>> playlists();
  Future<List<Collection>> collections();
  Future<List<SearchResult>> voiceSearch(CarPlayVoiceQuery query);
  Future<List<SearchResult>> online(
      String source, String query, int offset, int limit);
}

/// The normal queue expander supplies the real subsong indices and titles.
/// Unknown per-subsong lengths stay unknown instead of inheriting the first
/// track's duration. The downloaded file and its origin remain shared.
List<TrackRecord> carPlayResolvedSubsongs(
        TrackRecord file, List<SearchResult> rows) =>
    [
      for (final row in rows)
        TrackRecord(
          id: '${row.songId}?subsong=${row.subsongIdx}',
          filePath: file.filePath,
          entryPath: file.entryPath,
          subsongIdx: row.subsongIdx,
          title: row.displayTitle,
          artist: row.artistLabel.isEmpty ? file.artist : row.artistLabel,
          metaAlbum: file.metaAlbum,
          albumId: file.albumId,
          position: row.trackPosition,
          durationS: row.durationMs == null ? null : row.durationMs! / 1000.0,
          formatExt: file.formatExt,
          subsongCount: row.subsongCount ?? file.subsongCount,
          source: file.source,
          onlineId: row.songId,
          artworkUrl: file.artworkUrl,
          collectionSlug: file.collectionSlug,
          platformName: file.platformName,
          year: file.year,
          isFavorite: file.isFavorite,
          inLibrary: file.inLibrary,
          playCount: file.playCount,
          lastPlayedAt: file.lastPlayedAt,
        )
    ];

class LocalCarPlayLibrary implements CarPlayLibrary {
  @override
  Future<List<SearchResult>> voiceSearch(CarPlayVoiceQuery query) =>
      CarPlayVoiceSearcher().search(query);
  @override
  Future<List<Collection>> collections() => RewampDb.fetchCollections();

  @override
  Future<List<SearchResult>> online(
          String source, String query, int offset, int limit) =>
      source.startsWith('onlineSearch')
          ? RewampDb.search(query,
              offset: offset,
              limit: limit,
              collection: source.startsWith('onlineSearch:')
                  ? source.substring('onlineSearch:'.length)
                  : null)
          : source.startsWith('album:')
              ? RewampDb.albumTracks(
                  albumId: source.substring('album:'.length),
                  sortBy: 'position',
                  offset: offset,
                  limit: limit)
              : RewampDb.browse(
                  collection: source.substring('collection:'.length),
                  sortBy: 'popularity',
                  offset: offset,
                  limit: limit);

  @override
  Future<List<UserPlaylist>> playlists() => LocalDb.instance.getPlaylists();

  @override
  Future<List<TrackRecord>> tracks(String source) async {
    if (source.startsWith('playlist:')) {
      return carPlayPlaylistTracks(await LocalDb.instance
          .getPlaylistEntryRefs(source.substring('playlist:'.length)));
    }
    return switch (source) {
      'favorites' => LocalDb.instance.getFavorites(),
      'recent' => LocalDb.instance.getRecentTracks(limit: 200),
      'search' => LocalDb.instance.getLibraryTracks(),
      _ => throw ArgumentError.value(source, 'source'),
    };
  }
}

/// Account-restored playlists may have catalogue snapshots but no local track
/// row yet. Keep those entries downloadable, including their exact subsong.
List<TrackRecord> carPlayPlaylistTracks(List<PlaylistEntry> entries) => [
      for (final entry in entries)
        if (entry.track != null)
          entry.track!
        else if (entry.isRestorable)
          TrackRecord(
              id: 'carplay-playlist:${entry.rowId}',
              filePath: entry.filePath ?? '',
              entryPath: entry.entryPath,
              subsongIdx: entry.subsongIdx,
              title: entry.displayTitle,
              artist: entry.artist,
              metaAlbum: entry.album,
              albumId: entry.albumId,
              formatExt: entry.formatExt,
              durationS: entry.durationS,
              source: 'online',
              onlineId: entry.songId,
              isFavorite: false,
              inLibrary: false,
              playCount: 0),
    ];

/// Tokens represent the rows actually shown, never a mutable queue position.
/// In particular, removing/reordering a queue row between display and selection
/// must not play whatever has since moved into that position.
class CarPlayBrowser {
  CarPlayBrowser({
    required this.library,
    required this.queue,
    required this.queueIndex,
    required this.playQueueIndex,
    required this.playTracks,
    required this.playOnline,
    this.playPlaylist,
    this.playOnlineQueue,
    bool Function(String)? fileExists,
  }) : fileExists = fileExists ?? ((path) => File(path).existsSync());

  final CarPlayLibrary library;
  final List<QueueEntry> Function() queue;
  final int Function() queueIndex;
  final Future<void> Function(int) playQueueIndex;
  final Future<void> Function(List<TrackRecord>, int) playTracks;
  final Future<void> Function(SearchResult) playOnline;
  final Future<void> Function(List<TrackRecord>, bool)? playPlaylist;
  final Future<void> Function(List<SearchResult>, int)? playOnlineQueue;
  final bool Function(String) fileExists;
  final Map<String, Map<String, Future<void> Function()>> _selections = {};
  int _nextToken = 0;
  final String _tokenPrefix = '${DateTime.now().microsecondsSinceEpoch}-'
      '${Random.secure().nextInt(0x7fffffff)}';
  String _token() => '$_tokenPrefix:${_nextToken++}';

  Future<Map<String, Object?>> browse(String source,
      {String query = '', int offset = 0, int limit = 100}) async {
    if (offset < 0 || limit < 1 || limit > 100) {
      throw ArgumentError('Invalid CarPlay page');
    }
    final actions = <String, Future<void> Function()>{};
    Map<String, Object?> row(
        String title, String? subtitle, Future<void> Function() action,
        {bool playing = false}) {
      final token = _token();
      actions[token] = action;
      return {
        'id': token,
        'title': title,
        'subtitle': subtitle,
        'playing': playing
      };
    }

    final rows = <Map<String, Object?>>[];
    final controls = <Map<String, Object?>>[];
    int? onlineNext;
    var alreadyPaged = false;
    if (source == 'library') {
      for (final key in ['favorites', 'recent', 'playlists']) {
        rows.add({'label': key, 'source': key});
      }
    } else if (source == 'catalogue') {
      for (final collection in await library.collections()) {
        rows.add({
          'title': collection.name,
          'source': 'collection:${collection.slug}'
        });
      }
    } else if (source.startsWith('collection:') ||
        source.startsWith('album:') ||
        source.startsWith('onlineSearch')) {
      final songs = await library.online(source, query, offset, limit + 1);
      alreadyPaged = true;
      if (songs.length > limit) onlineNext = offset + limit;
      final playable = songs.take(limit).toList();
      for (var i = 0; i < playable.length; i++) {
        final song = playable[i];
        final index = i;
        if (!source.startsWith('album:') &&
            song.albumId != null &&
            (RewampDb.isArchiveAlbumRow(song) ||
                RewampDb.isAlbumLevelMatch(song))) {
          rows.add({
            'title': song.album ?? song.displayTitle,
            'subtitle': song.artistLabel,
            'source': 'album:${song.albumId}'
          });
        } else {
          rows.add(row(
              song.displayTitle,
              song.artistLabel,
              () => playOnlineQueue != null
                  ? playOnlineQueue!(playable, index)
                  : playOnline(song)));
        }
      }
    } else if (source == 'playlists') {
      for (final playlist in await library.playlists()) {
        rows.add({'title': playlist.name, 'source': 'playlist:${playlist.id}'});
      }
    } else if (source == 'queue') {
      final entries = List<QueueEntry>.of(queue());
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        rows.add(row(entry.title, entry.artist ?? entry.subtitle, () async {
          final current = queue();
          final index = current.indexWhere((candidate) => entry.id != null
              ? candidate.id == entry.id
              : identical(candidate, entry));
          if (index < 0) throw StateError('Queue entry is no longer available');
          await playQueueIndex(index);
        }, playing: i == queueIndex()));
      }
    } else {
      // Local files and catalogue references are both playable: an online
      // trace can be downloaded again. Preserve subsong and playlist order.
      final tracks = (await library.tracks(source))
          .where((track) =>
              (track.filePath.isNotEmpty && fileExists(track.filePath)) ||
              (track.onlineId?.isNotEmpty ?? false))
          .where((track) {
        if (source != 'search') return true;
        final text = '${track.displayTitle} ${track.artist ?? ''} '
                '${track.metaAlbum ?? ''}'
            .toLowerCase();
        return query
            .trim()
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .every(text.contains);
      }).toList();
      if (source.startsWith('playlist:') &&
          tracks.isNotEmpty &&
          playPlaylist != null) {
        for (final shuffle in [false, true]) {
          final control = row('', null,
              () => playPlaylist!(List<TrackRecord>.of(tracks), shuffle));
          control['label'] = shuffle ? 'shuffle' : 'playAll';
          controls.add(control);
        }
      }
      for (var i = 0; i < tracks.length; i++) {
        final index = i;
        final track = tracks[i];
        rows.add(
            row(track.displayTitle, track.artist ?? track.metaAlbum, () async {
          if (!fileExists(track.filePath) && track.onlineId == null) {
            throw StateError('File is no longer available');
          }
          // A snapshot keeps the selected subsong tied to its displayed row.
          await playTracks(tracks, index);
        }));
      }
    }
    final page = alreadyPaged ? rows : rows.skip(offset).take(limit).toList();
    final visible = {
      for (final item in [...controls, ...page]) item['id']
    };
    actions.removeWhere((token, _) => !visible.contains(token));
    final retained = _selections.putIfAbsent(source, () => {});
    retained.addAll(actions);
    while (retained.length > 500) {
      retained.remove(retained.keys.first);
    }
    // Bound retained snapshots when browsing many collections/playlists.
    if (_selections.length > 32) _selections.remove(_selections.keys.first);
    return {
      'items': page,
      'controls': controls,
      'nextOffset': alreadyPaged
          ? onlineNext
          : offset + page.length < rows.length
              ? offset + page.length
              : null
    };
  }

  Future<void> select(String source, String token) async {
    final action = _selections[source]?[token];
    if (action == null) throw StateError('CarPlay list has changed');
    await action();
  }

  /// Siri supplies recognized text; use the catalogue, including uncached
  /// tracks. Keep the resolved action snapshot for Siri's disambiguation step.
  Future<List<Map<String, Object?>>> voiceSearch(String query,
      {String? artistName,
      String? albumName,
      bool playlistsOnly = false,
      bool shuffle = false}) async {
    final request =
        CarPlayVoiceQuery(query, artist: artistName, album: albumName);
    if (request.isEmpty) return [];
    final actions = <String, Future<void> Function()>{};
    final results = <Map<String, Object?>>[];
    if (playlistsOnly &&
        query.trim().isNotEmpty &&
        request.artist == null &&
        request.album == null) {
      for (final playlist in await library.playlists()) {
        if (!playlist.name.toLowerCase().contains(query.trim().toLowerCase())) {
          continue;
        }
        final token = _token();
        actions[token] = () async {
          final tracks = (await library.tracks('playlist:${playlist.id}'))
              .where((t) => fileExists(t.filePath) || t.onlineId != null)
              .toList();
          if (tracks.isEmpty) throw StateError('Playlist is empty');
          if (playPlaylist != null) {
            await playPlaylist!(tracks, shuffle);
          } else {
            await playTracks(tracks, 0);
          }
        };
        results.add({
          'id': token,
          'title': playlist.name,
          'playlist': true,
          'mediaId': playlist.id,
          'artist': '',
          'album': ''
        });
        if (results.length == 5) break;
      }
    }
    if (results.isEmpty) {
      final songs = await library.voiceSearch(request);
      for (final song in songs) {
        final token = _token();
        actions[token] = () => playOnline(song);
        results.add({
          'id': token,
          'title': song.displayTitle,
          'subtitle': song.artistLabel,
          'playlist': false,
          'mediaId': song.songId,
          'subsong': song.subsongIdx,
          'artist': song.artistLabel,
          'artists': song.artistNames,
          'album': song.album ?? '',
          'collection': song.collection,
          'format': song.formatExt,
        });
      }
    }
    String spokenKey(Object? value) => (value as String? ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[_\s]+'), ' ')
        .trim();
    for (final result in results) {
      final duplicates = results
          .where((other) =>
              spokenKey(other['title']) == spokenKey(result['title']) &&
              spokenKey(other['artist']) == spokenKey(result['artist']))
          .toList();
      if (duplicates.length < 2) continue;
      final collection = result['collection'] as String? ?? '';
      final label =
          collection == 'modland' ? 'Modland' : collection.toUpperCase();
      final sameCollection =
          duplicates.where((r) => r['collection'] == collection);
      final suffix = sameCollection.length > 1
          ? '$label, ${result['format']}, version ${duplicates.indexOf(result) + 1}'
          : label;
      result['spokenTitle'] = '${result['title']} ($suffix)';
    }
    final retained = _selections.putIfAbsent('voiceSearch', () => {});
    retained.addAll(actions);
    while (retained.length > 100) {
      retained.remove(retained.keys.first);
    }
    return results;
  }
}

class CarPlaySession {
  CarPlaySession(this.controller, this.browser, this.labels,
      {this.channel = const MethodChannel('rewamp/carplay')});

  final PlayerController controller;
  final CarPlayBrowser browser;
  final AppLocalizations Function() labels;
  final MethodChannel channel;
  final playback = CarPlayPlayback();
  bool _connected = false;
  bool _disposed = false;
  Timer? _debounce;
  Timer? _vocabularyTimer;
  (int, int, bool, bool)? _lastQueue;
  bool? _lastShuffle;
  DownloadInfo? _currentDownload;
  bool get connected => _connected;

  static Future<bool> isConnected() async {
    if (!Platform.isIOS) return false;
    try {
      return await const MethodChannel('rewamp/carplay')
              .invokeMethod<bool>('isConnected') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  void reportPlaybackError() {
    if (!_connected || _disposed) return;
    unawaited(channel.invokeMethod<void>('error').catchError((Object e) {
      debugPrint('[carplay] playback error: $e');
    }));
  }

  Future<void> start() async {
    channel.setMethodCallHandler((call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
      switch (call.method) {
        case 'setConnected':
          _connected = args['connected'] == true;
          if (_connected) {
            _syncShuffle(force: true);
            _changed();
          }
          return null;
        case 'toggleShuffle':
          controller.toggleShuffle();
          return controller.shuffleEnabled;
        case 'browse':
          return browser.browse(args['source'] as String,
              query: args['query'] as String? ?? '',
              offset: args['offset'] as int? ?? 0,
              limit: args['limit'] as int? ?? 100);
        case 'voiceSearch':
          final watch = Stopwatch()..start();
          try {
            final rows = await browser.voiceSearch(args['query'] as String,
                artistName: args['artist'] as String?,
                albumName: args['album'] as String?,
                playlistsOnly: args['playlist'] == true,
                shuffle: args['shuffle'] == true);
            _voiceLog({
              'stage': 'catalogue_result',
              'request': args['request'],
              'count': rows.length,
              'ms': watch.elapsedMilliseconds
            });
            return rows;
          } catch (error) {
            final status =
                RegExp(r'HTTP\s+(\d{3})').firstMatch(error.toString())?[1];
            _voiceLog({
              'stage': 'catalogue_error',
              'request': args['request'],
              'error': error.runtimeType.toString(),
              if (status != null) 'httpStatus': int.parse(status),
              'kind': error is TimeoutException
                  ? 'timeout'
                  : status != null
                      ? 'http'
                      : 'service',
              'ms': watch.elapsedMilliseconds
            });
            throw PlatformException(
                code: 'search_unavailable',
                message: 'The catalogue search service is unavailable');
          }
        case 'select':
          try {
            await playback.run(() =>
                browser.select(args['source'] as String, args['id'] as String));
          } on DownloadCancelledException {
            throw PlatformException(code: 'cancelled');
          }
          return null;
        case 'skip':
          try {
            await playback.run(args['previous'] == true
                ? controller.goPrev
                : controller.goNext);
          } on DownloadCancelledException {
            throw PlatformException(code: 'cancelled');
          }
          return null;
        case 'cancel':
          playback.cancel();
          return null;
        default:
          throw MissingPluginException('Unknown CarPlay method ${call.method}');
      }
    });
    controller.addListener(_playerChanged);
    LocalDb.instance.addListener(_libraryChanged);
    RewampDb.downloadStatus.addListener(_downloadChanged);
    playback.addListener(_playbackChanged);
    try {
      _connected =
          await channel.invokeMethod<bool>('ready', _strings()) ?? false;
      if (_connected && !_disposed) {
        _syncShuffle(force: true);
        _changed();
      }
    } on PlatformException catch (e) {
      debugPrint('[carplay] initialization failed: $e');
    } on MissingPluginException {
      // Allows an older native host to run the Dart app.
    }
    await _syncVocabulary();
  }

  void _voiceLog(Map<String, Object?> event) {
    unawaited(
        channel.invokeMethod<void>('siriLog', event).catchError((Object _) {}));
  }

  void _libraryChanged() {
    _changed();
    _vocabularyTimer?.cancel();
    _vocabularyTimer = Timer(const Duration(seconds: 1), () {
      unawaited(_syncVocabulary());
    });
  }

  Future<void> _syncVocabulary() async {
    try {
      final recent = await browser.library.tracks('recent');
      final playlists = await browser.library.playlists();
      if (_disposed) return;
      await channel.invokeMethod<void>('vocabulary', {
        'artists': {
          for (final t in recent)
            if ((t.artist ?? '').isNotEmpty) t.artist!
        }.take(100).toList(),
        'playlists': playlists.map((p) => p.name).take(100).toList(),
      });
    } catch (error) {
      debugPrint('[Siri] vocabulary unavailable: ${error.runtimeType}');
    }
  }

  Map<String, String> _strings() {
    final l = labels();
    return {
      'queue': l.playerQueue,
      'favorites': l.libraryFavorites,
      'recent': l.recentlyPlayed,
      'playlists': l.libraryPlaylists,
      'search': l.navSearch,
      'empty': l.libraryEmpty,
      'error': l.failedToLoadFile,
      'retry': l.commonRetry,
      'library': l.navLibrary,
      'catalogue': l.searchBrowse,
      'more': l.navMore,
      'cancel': l.downloadsCancel,
      'ok': l.commonOk,
      'downloading': l.searchDownloading,
      'playAll': l.commonPlayAll,
      'shuffle': l.browseShuffle,
      'next': l.carPlayNext,
      'previous': l.carPlayPrevious,
    };
  }

  void _downloadChanged() {
    if (!_connected || _disposed || !playback.ownsCurrent) return;
    final status = RewampDb.downloadStatus.value;
    // Global download banners also describe background prefetch. Only the
    // currently-owned playback operation is allowed to update the car screen.
    if (status?.error != null) return;
    _currentDownload = status;
    _sendDownload(_currentDownload);
  }

  void _playbackChanged() {
    _currentDownload = null;
    controller.setPlaybackPreparing(playback.busy);
    _sendDownload(null);
  }

  void _sendDownload(DownloadInfo? status) {
    if (!_connected || _disposed) return;
    unawaited(channel
        .invokeMethod<void>(
            'download',
            !playback.busy
                ? null
                : {
                    'title': status?.label ?? labels().searchDownloading,
                    'progress': status?.progress,
                    'canNext': controller.canGoNext,
                    'canPrevious': controller.canGoPrev,
                  })
        .catchError((Object e) {
      debugPrint('[carplay] download status: $e');
    }));
  }

  void _playerChanged() {
    _syncShuffle();
    // PlayerController ticks four times a second. Only structural/metadata
    // changes cross this channel; audio_service owns transport and progress.
    final key = (
      controller.queueRevision,
      controller.queueIdx,
      controller.canGoNext,
      controller.canGoPrev
    );
    if (_lastQueue == key) return;
    _lastQueue = key;
    if (playback.busy) _sendDownload(_currentDownload);
    _changed();
  }

  void _syncShuffle({bool force = false}) {
    if (!_connected || _disposed) return;
    final enabled = controller.shuffleEnabled;
    if (!force && _lastShuffle == enabled) return;
    _lastShuffle = enabled;
    unawaited(channel
        .invokeMethod<void>('shuffleState', enabled)
        .catchError((Object error) {
      debugPrint('[carplay] shuffle state: $error');
    }));
  }

  void _changed() {
    if (!_connected || _disposed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        await channel.invokeMethod<void>('changed', _strings());
      } on PlatformException catch (e) {
        debugPrint('[carplay] refresh failed: $e');
      } on MissingPluginException {/* older native host */}
    });
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _vocabularyTimer?.cancel();
    controller.removeListener(_playerChanged);
    LocalDb.instance.removeListener(_libraryChanged);
    RewampDb.downloadStatus.removeListener(_downloadChanged);
    playback.removeListener(_playbackChanged);
    playback.dispose();
    channel.setMethodCallHandler(null);
  }
}
