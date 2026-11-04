import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/carplay.dart';
import 'package:rewamp/carplay_voice_search.dart';
import 'package:rewamp/local_db.dart';
import 'package:rewamp/player_controller.dart';
import 'package:rewamp/rewamp_db.dart';

TrackRecord track(String id, {int subsong = 0, String? onlineId}) =>
    TrackRecord(
        id: id,
        filePath: '/music/$id.sid',
        entryPath: '',
        subsongIdx: subsong,
        title: 'Tune $id',
        artist: 'Composer',
        metaAlbum: 'Game soundtrack',
        source: onlineId == null ? 'local' : 'online',
        onlineId: onlineId,
        isFavorite: true,
        inLibrary: true,
        playCount: 1);

SearchResult song(int i) => SearchResult(
    songId: 'song-$i',
    collection: 'test',
    filename: '$i.sid',
    title: 'Online $i',
    album: null,
    formatExt: 'sid',
    downloadUrl: 'https://example.invalid/$i.sid',
    fileSize: 10,
    year: null,
    artistNames: const ['Composer'],
    totalCount: 0,
    subsongIdx: i);

class Library implements CarPlayLibrary {
  final voiceQueries = <CarPlayVoiceQuery>[];
  @override
  Future<List<SearchResult>> voiceSearch(CarPlayVoiceQuery query) {
    voiceQueries.add(query);
    return online('onlineSearch', query.text, 0, 5);
  }

  List<TrackRecord> records = [];
  List<SearchResult> songs = List.generate(12, song);
  final calls = <(String, String, int, int)>[];
  Object? error;
  @override
  Future<List<TrackRecord>> tracks(String source) async => records;
  @override
  Future<List<UserPlaylist>> playlists() async => [
        UserPlaylist(
            id: 'playlist-1',
            name: 'Road music',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026))
      ];
  @override
  Future<List<Collection>> collections() async =>
      const [Collection(slug: 'test', name: 'Test collection', filesCount: 12)];
  @override
  Future<List<SearchResult>> online(
      String source, String query, int offset, int limit) async {
    calls.add((source, query, offset, limit));
    if (error != null) throw error!;
    return songs.skip(offset).take(limit).toList();
  }
}

List<Map<String, Object?>> rows(Map<String, Object?> page) =>
    (page['items'] as List).cast<Map<String, Object?>>();

void main() {
  test(
      'expanded online subsongs keep their real indices and independent lengths',
      () {
    final tracks = carPlayResolvedSubsongs(track('file', onlineId: 'file-id'), [
      song(3).copyWith(title: 'Third subsong', durationMs: 12000),
      song(9).copyWith(title: 'Ninth subsong', dropDurationMs: true),
    ]);
    expect(tracks.map((t) => t.subsongIdx), [3, 9]);
    expect(tracks.map((t) => t.title), ['Third subsong', 'Ninth subsong']);
    expect(tracks.map((t) => t.durationS), [12.0, null]);
    expect(tracks.map((t) => t.filePath).toSet(), {'/music/file.sid'});
    expect(tracks[1].onlineId, 'song-9');
  });

  test('a playlist restored from an account keeps downloadable snapshots', () {
    final tracks = carPlayPlaylistTracks([
      PlaylistEntry(rowId: 1, track: track('local', subsong: 3)),
      const PlaylistEntry(
          rowId: 2,
          songId: 'online-song',
          subsongIdx: 8,
          title: 'Remote subsong',
          albumId: 'album-id',
          formatExt: 'sid'),
      const PlaylistEntry(rowId: 3, title: 'Missing local file'),
    ]);
    expect(tracks.length, 2);
    expect(tracks[1].onlineId, 'online-song');
    expect(tracks[1].subsongIdx, 8);
    expect(tracks[1].albumId, 'album-id');
    expect(tracks[1].title, 'Remote subsong');
  });

  late Library library;
  late CarPlayBrowser browser;
  late List<QueueEntry> queue;
  late Set<String> missing;
  int? playedQueue;
  (List<TrackRecord>, int)? playedTracks;
  SearchResult? playedOnline;
  bool? playlistShuffle;
  Completer<void>? waitForPlay;

  setUp(() {
    library = Library();
    queue = [
      const QueueEntry(id: 1, title: 'Same', subsongIdx: 0),
      const QueueEntry(id: 2, title: 'Same', subsongIdx: 1)
    ];
    missing = {};
    playedQueue = null;
    playedTracks = null;
    playedOnline = null;
    playlistShuffle = null;
    waitForPlay = null;
    browser = CarPlayBrowser(
        library: library,
        queue: () => queue,
        queueIndex: () => 1,
        playQueueIndex: (index) async {
          playedQueue = index;
          await waitForPlay?.future;
        },
        playTracks: (tracks, index) async {
          playedTracks = (tracks, index);
        },
        playOnline: (song) async {
          playedOnline = song;
        },
        playPlaylist: (tracks, shuffle) async {
          playedTracks = (tracks, 0);
          playlistShuffle = shuffle;
        },
        fileExists: (path) => !missing.contains(path));
  });

  test('a displayed queue row follows its identity after reorder and rename',
      () async {
    final page = rows(await browser.browse('queue'));
    expect(page[1]['playing'], true);
    final selected = page[1]['id'] as String;
    queue = [queue[1].copyWith(title: 'Renamed'), queue[0]];
    await browser.select('queue', selected);
    expect(playedQueue, 0);
  });

  test('removing a displayed row cannot play its replacement', () async {
    final selected = rows(await browser.browse('queue'))[0]['id'] as String;
    queue.removeAt(0);
    await expectLater(browser.select('queue', selected), throwsStateError);
    expect(playedQueue, isNull);
  });

  test('stand-in queue rows use object identity', () async {
    queue = [const QueueEntry(title: 'Stand-in')];
    final token = rows(await browser.browse('queue'))[0]['id'] as String;
    queue = [QueueEntry(title: String.fromCharCodes('Stand-in'.codeUnits))];
    await expectLater(browser.select('queue', token), throwsStateError);
  });

  test('selection completion waits for queue playback/download', () async {
    waitForPlay = Completer<void>();
    final token = rows(await browser.browse('queue'))[0]['id'] as String;
    var completed = false;
    final playing =
        browser.select('queue', token).then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(completed, false);
    waitForPlay!.complete();
    await playing;
    expect(completed, true);
  });

  test(
      'library includes redownloadable references and excludes missing local files',
      () async {
    library.records = [
      track('local'),
      track('missing'),
      track('online', onlineId: 'catalogue-id')
    ];
    missing.addAll(['/music/missing.sid', '/music/online.sid']);
    final page = rows(await browser.browse('favorites'));
    expect(page.map((r) => r['title']), ['Tune local', 'Tune online']);
    await browser.select('favorites', page[1]['id'] as String);
    expect(playedTracks!.$1[playedTracks!.$2].onlineId, 'catalogue-id');
  });

  test('file deleted after display fails before playback', () async {
    library.records = [track('local')];
    final token = rows(await browser.browse('recent'))[0]['id'] as String;
    missing.add('/music/local.sid');
    await expectLater(browser.select('recent', token), throwsStateError);
    expect(playedTracks, isNull);
  });

  test('duplicate playlist tracks preserve the selected subsong and row',
      () async {
    library.records = [
      track('a', subsong: 2),
      track('a', subsong: 9),
      track('a', subsong: 2)
    ];
    final page = rows(await browser.browse('playlist:playlist-1'));
    await browser.select('playlist:playlist-1', page[1]['id'] as String);
    expect(playedTracks!.$2, 1);
    expect(playedTracks!.$1[1].subsongIdx, 9);
    expect(playedTracks!.$1.length, 3);
  });

  test('local search matches words across title, artist and album', () async {
    library.records = [track('one'), track('two')];
    final page =
        rows(await browser.browse('search', query: 'COMPOSER two soundtrack'));
    expect(page.single['title'], 'Tune two');
    expect(library.calls, isEmpty);
  });

  test('paging leaves other displayed snapshots selectable', () async {
    library.records = [track('a'), track('b'), track('c')];
    final first = await browser.browse('recent', limit: 2);
    final oldToken = rows(first)[0]['id'] as String;
    final second = await browser.browse('recent', offset: 2, limit: 2);
    expect(first['nextOffset'], 2);
    expect(second['nextOffset'], isNull);
    await browser.select('recent', oldToken);
    expect(playedTracks!.$1[playedTracks!.$2].id, 'a');
  });

  test('navigation preserves collection and playlist IDs', () async {
    expect(rows(await browser.browse('catalogue')).single['source'],
        'collection:test');
    expect(rows(await browser.browse('playlists')).single['source'],
        'playlist:playlist-1');
    expect(rows(await browser.browse('library')).map((r) => r['source']),
        ['favorites', 'recent', 'playlists']);
    expect(playedOnline, isNull);
  });

  test('an archive album opens its track list without downloading or playing',
      () async {
    library.songs = [
      song(0).copyWith(
          album: 'Game album',
          albumId: 'album-id',
          filename: 'game.7z',
          formatExt: '7z',
          subsongCount: 20,
          downloadUrl: 'https://example.invalid/game.7z')
    ];
    final page = rows(await browser.browse('collection:test'));
    expect(page.single['source'], 'album:album-id');
    expect(playedOnline, isNull);
    await browser.browse('album:album-id');
    expect(library.calls.last.$1, 'album:album-id');
  });

  test('online pages use server pagination and download only the selection',
      () async {
    final page = await browser.browse('collection:test', offset: 3, limit: 4);
    expect(library.calls.single, ('collection:test', '', 3, 5));
    expect(rows(page).length, 4);
    expect(page['nextOffset'], 7);
    expect(playedOnline, isNull);
    await browser.select('collection:test', rows(page)[2]['id'] as String);
    expect(playedOnline!.songId, 'song-5');
    expect(playedOnline!.subsongIdx, 5);
    expect(
        (await browser.browse('collection:test',
            offset: 10, limit: 4))['nextOffset'],
        isNull);
  });

  test(
      'online search forwards the query without filtering only downloaded files',
      () async {
    missing.addAll(library.songs.map((s) => s.filename));
    final page =
        await browser.browse('onlineSearch', query: 'Last Ninja', limit: 3);
    expect(library.calls.single, ('onlineSearch', 'Last Ninja', 0, 4));
    expect(rows(page).length, 3);
  });

  test('network errors propagate for the native retry UI', () async {
    library.error = TimeoutException('offline');
    await expectLater(
        browser.browse('collection:test'), throwsA(isA<TimeoutException>()));
    expect(playedOnline, isNull);
  });

  test('playlist Play and Shuffle include the entire playlist across pages',
      () async {
    library.records = [track('a'), track('a', subsong: 9), track('b')];
    final page =
        await browser.browse('playlist:playlist-1', offset: 2, limit: 1);
    final controls = (page['controls'] as List).cast<Map<String, Object?>>();
    expect(controls.map((c) => c['label']), ['playAll', 'shuffle']);
    await browser.select('playlist:playlist-1', controls[0]['id'] as String);
    expect(playlistShuffle, false);
    expect(playedTracks!.$1.map((t) => (t.id, t.subsongIdx)),
        [('a', 0), ('a', 9), ('b', 0)]);
    await browser.select('playlist:playlist-1', controls[1]['id'] as String);
    expect(playlistShuffle, true);
    expect(playedTracks!.$1.length, 3);
  });

  test('empty playlists have no playback actions', () async {
    expect((await browser.browse('playlist:empty'))['controls'], isEmpty);
  });

  test('collection search retains query and scope while paging', () async {
    await browser.browse('onlineSearch:test',
        query: 'Hubbard', offset: 4, limit: 3);
    expect(library.calls.single, ('onlineSearch:test', 'Hubbard', 4, 4));
  });

  test('online selection supplies a queue before downloading', () async {
    (List<SearchResult>, int)? selected;
    final queuedBrowser = CarPlayBrowser(
      library: library,
      queue: () => [],
      queueIndex: () => -1,
      playQueueIndex: (_) async {},
      playTracks: (tracks, index) async {},
      playOnline: (_) async => fail('single-track fallback'),
      playOnlineQueue: (songs, index) async => selected = (songs, index),
    );
    final page = rows(await queuedBrowser.browse('collection:test', limit: 3));
    await queuedBrowser.select('collection:test', page[1]['id'] as String);
    expect(selected!.$1.map((s) => s.songId), ['song-0', 'song-1', 'song-2']);
    expect(selected!.$2, 1);
  });

  test(
      'Siri searches uncached catalogue tracks and keeps disambiguated selections',
      () async {
    final results = await browser.voiceSearch('Last Ninja');
    expect(library.calls.single, ('onlineSearch', 'Last Ninja', 0, 5));
    final token = results[2]['id'] as String;
    await browser.voiceSearch('Other query');
    await browser.select('voiceSearch', token);
    expect(playedOnline!.songId, 'song-2');
  });

  test(
      'Siri playlist shuffle uses the matched playlist and explicit shuffle action',
      () async {
    library.records = [track('a'), track('b')];
    final results =
        await browser.voiceSearch('road', playlistsOnly: true, shuffle: true);
    expect(results.single['title'], 'Road music');
    expect(results.single['playlist'], true);
    expect(library.calls, isEmpty);
    await browser.select('voiceSearch', results.single['id'] as String);
    expect(playlistShuffle, true);
    expect(playedTracks!.$1.map((t) => t.id), ['a', 'b']);
  });

  test('empty Siri search makes no catalogue request', () async {
    expect(await browser.voiceSearch('  '), isEmpty);
    expect(library.calls, isEmpty);
  });

  test('Siri preserves title, artist and album as separate search fields',
      () async {
    await browser.voiceSearch('The Bullet',
        artistName: 'Randal', albumName: 'Remedy 96');
    final request = library.voiceQueries.single;
    expect(request.text, 'The Bullet');
    expect(request.artist, 'Randal');
    expect(request.album, 'Remedy 96');
  });

  for (final request in [
    ('Acidland Metropolis', 'Booster'),
    ('Durban Poison', 'Randall')
  ]) {
    test('Siri catalogue fallback for misclassified ${request.$1}', () async {
      final results = await browser.voiceSearch(request.$1,
          artistName: request.$2, playlistsOnly: true);
      expect(results, isNotEmpty);
      expect(results.first['playlist'], false);
      expect(library.voiceQueries.single.text, request.$1);
      expect(library.voiceQueries.single.artist, request.$2);
    });
  }

  test(
      'Siri catalogue copies have distinct spoken labels and retain both selections',
      () async {
    library.songs = [
      song(0).copyWith(
          title: 'Durban Poison',
          collection: 'modland',
          artistNames: ['Randall']),
      song(1).copyWith(
          title: 'Durban Poison', collection: 'amp', artistNames: ['Randall']),
    ];
    final results =
        await browser.voiceSearch('Durban Poison', artistName: 'Randall');
    expect(results.map((r) => r['spokenTitle']),
        ['Durban Poison (Modland)', 'Durban Poison (AMP)']);
    expect(results.map((r) => r['mediaId']), ['song-0', 'song-1']);
    await browser.select('voiceSearch', results.last['id'] as String);
    expect(playedOnline!.songId, 'song-1');
  });

  test('playlist classification does not discard an artist-only request',
      () async {
    final results = await browser.voiceSearch('',
        artistName: 'Randall', playlistsOnly: true);
    expect(results, isNotEmpty);
    expect(results.first['playlist'], false);
    expect(library.voiceQueries.single.artist, 'Randall');
  });

  test('Siri version labels normalize underscores and case', () async {
    library.songs = [
      song(0).copyWith(title: 'Durban Poison', collection: 'modland'),
      song(1).copyWith(title: 'durban_poison', collection: 'amp'),
    ];
    final results = await browser.voiceSearch('Durban Poison');
    expect(results.first['spokenTitle'], 'Durban Poison (Modland)');
    expect(results.last['spokenTitle'], 'durban_poison (AMP)');
  });

  test('a restarted browser cannot reuse an old Siri action token', () async {
    final old = await browser.voiceSearch('Durban Poison');
    final restarted = CarPlayBrowser(
        library: library,
        queue: () => [],
        queueIndex: () => -1,
        playQueueIndex: (_) async {},
        playTracks: (tracks, index) async {},
        playOnline: (_) async => fail('Stale selection played'));
    final fresh = await restarted.voiceSearch('Durban Poison');
    expect(fresh.first['id'], isNot(old.first['id']));
    await expectLater(
        restarted.select('voiceSearch', old.first['id'] as String),
        throwsStateError);
  });

  test('invalid pagination and unknown selections fail safely', () async {
    await expectLater(browser.browse('queue', limit: 0), throwsArgumentError);
    await expectLater(browser.browse('queue', offset: -1), throwsArgumentError);
    await expectLater(browser.select('queue', 'unknown'), throwsStateError);
    expect(playedQueue, isNull);
  });
}
