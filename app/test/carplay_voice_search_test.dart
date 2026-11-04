import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/carplay_voice_search.dart';
import 'package:rewamp/rewamp_db.dart';

SearchResult song(String id, String title, String artist) => SearchResult(
    songId: id,
    collection: 'modland',
    filename: '$title.mod',
    title: title,
    album: null,
    formatExt: 'mod',
    downloadUrl: 'https://example.invalid/$id.mod',
    fileSize: 100,
    year: null,
    artistNames: [artist],
    totalCount: 0);

void main() {
  final bullet = song('bullet-modland', 'the bullet', 'Randall');
  final ampBullet = song('bullet-amp', 'the_bullet', 'Randall');
  final unrelated = song('wrong-song', 'November Light', 'Randall');
  const randall = ArtistResult(artistId: 'randall', name: 'Randall');
  const noise = ArtistResult(artistId: 'unrelated', name: 'Jean-Michel Jarre');
  late CarPlayVoiceSearcher searcher;
  late List<
      ({
        String text,
        String? artist,
        String? artistId,
        String? album,
        bool fuzzy
      })> requests;
  late List<String> artistQueries;

  setUp(() {
    requests = [];
    artistQueries = [];
    searcher = CarPlayVoiceSearcher(
      songs: (query,
          {artistName,
          artistId,
          albumName,
          required fuzzy,
          required limit}) async {
        requests.add((
          text: query,
          artist: artistName,
          artistId: artistId,
          album: albumName,
          fuzzy: fuzzy
        ));
        if (artistId == 'unrelated') {
          fail('Unrelated artist must never be searched');
        }
        if (query.toLowerCase() == 'the bullet' &&
            (artistName == 'Randall' || artistId == 'randall')) {
          return [bullet, ampBullet];
        }
        return [];
      },
      artists: (query, {required fuzzy, required limit}) async {
        artistQueries.add(query);
        expect(fuzzy, true);
        // The live artist RPC includes cross-entity matches with unrelated
        // names ahead of genuine spelling candidates.
        return [noise, randall];
      },
    );
  });

  test('The Bullet by Randall uses separate title and artist fields', () async {
    final found = await searcher
        .search(CarPlayVoiceQuery('The Bullet', artist: 'Randall'));
    expect(found.map((r) => r.songId), ['bullet-modland', 'bullet-amp']);
    expect(requests.single.text, 'The Bullet');
    expect(requests.single.artist, 'Randall');
    expect(artistQueries, isEmpty);
  });

  test('Siri losing the second l resolves Randal to canonical Randall',
      () async {
    final found = await searcher
        .search(CarPlayVoiceQuery('The Bullet', artist: 'Randal'));
    expect(found.map((r) => r.songId), ['bullet-modland', 'bullet-amp']);
    expect(artistQueries, ['Randal']);
    expect(requests.last.artistId, 'randall');
    expect(requests.every((r) => !r.fuzzy), true);
  });

  for (final spelling in ['Randall', 'Randal']) {
    test('whole spoken phrase The Bullet by $spelling resolves the right MOD',
        () async {
      final found =
          await searcher.search(CarPlayVoiceQuery('The Bullet by $spelling'));
      expect(found.first.songId, 'bullet-modland');
      expect(found.every((r) => r.artistNames.contains('Randall')), true);
    });
  }

  test('an actual title containing by is searched intact first', () async {
    final title = song('stand-by-me', 'Stand by Me', 'Composer');
    final lookup = CarPlayVoiceSearcher(songs: (query,
        {artistName,
        artistId,
        albumName,
        required fuzzy,
        required limit}) async {
      expect(query, 'Stand by Me');
      expect(artistName, isNull);
      return [title];
    });
    expect(
        (await lookup.search(CarPlayVoiceQuery('Stand by Me'))).single.songId,
        'stand-by-me');
  });

  test('an artist repeated in mediaName is not treated as part of the title',
      () async {
    final found = await searcher
        .search(CarPlayVoiceQuery('The Bullet by Randall', artist: 'Randal'));
    expect(found.first.songId, 'bullet-modland');
  });

  test('artist correction retains the requested album constraint', () async {
    final found = await searcher.search(
        CarPlayVoiceQuery('The Bullet', artist: 'Randal', album: 'Remedy 96'));
    expect(found.first.songId, 'bullet-modland');
    expect(requests.every((r) => r.album == 'Remedy 96'), true);
  });

  test('no plausible artist match never falls back to a different artist',
      () async {
    final found = await searcher
        .search(CarPlayVoiceQuery('The Bullet', artist: 'Unknown composer'));
    expect(found, isEmpty);
    expect(requests.length, 1);
    expect(requests.single.artist, 'Unknown composer');
  });

  test('single-letter artist handles are not loosely corrected', () async {
    expect(await searcher.search(CarPlayVoiceQuery('The Bullet', artist: 'R')),
        isEmpty);
    expect(requests.length, 1);
  });

  test('exact song titles outrank popular album and cross-entity matches',
      () async {
    final lookup = CarPlayVoiceSearcher(songs: (query,
        {artistName,
        artistId,
        albumName,
        required fuzzy,
        required limit}) async {
      expect(limit, greaterThan(5));
      return [
        song('album', 'Bite the Bullet', ''),
        ampBullet,
        for (var i = 0; i < 25; i++)
          song('noise-$i', 'Bullet theme $i', 'Other'),
        bullet
      ];
    });
    final found = await lookup.search(CarPlayVoiceQuery('The Bullet'));
    expect(
        found.take(2).map((r) => r.songId), ['bullet-amp', 'bullet-modland']);
    expect(found.length, 5);
  });

  test('fuzzy title fallback keeps artist scope and rejects unrelated music',
      () async {
    final lookup = CarPlayVoiceSearcher(
      songs: (query,
          {artistName,
          artistId,
          albumName,
          required fuzzy,
          required limit}) async {
        if (fuzzy) {
          expect(artistId, 'randall');
          return [unrelated, bullet];
        }
        return [];
      },
      artists: (query, {required fuzzy, required limit}) async => [randall],
    );
    final found =
        await lookup.search(CarPlayVoiceQuery('The Bulet', artist: 'Randall'));
    expect(found.single.songId, 'bullet-modland');
  });

  test('artist-only requests are not treated as an empty query', () async {
    final lookup = CarPlayVoiceSearcher(songs: (query,
        {artistName,
        artistId,
        albumName,
        required fuzzy,
        required limit}) async {
      expect(query, '');
      expect(artistName, 'Randall');
      return [bullet];
    });
    expect(
        (await lookup.search(CarPlayVoiceQuery('', artist: 'Randall')))
            .single
            .songId,
        'bullet-modland');
  });

  test('empty requests do not query the catalogue', () async {
    expect(
        await searcher.search(CarPlayVoiceQuery('  ', artist: '  ')), isEmpty);
    expect(requests, isEmpty);
    expect(artistQueries, isEmpty);
  });

  test('network failures propagate rather than being called a spelling miss',
      () async {
    final lookup = CarPlayVoiceSearcher(songs: (query,
        {artistName,
        artistId,
        albumName,
        required fuzzy,
        required limit}) async {
      throw StateError('offline');
    });
    await expectLater(
        lookup.search(CarPlayVoiceQuery('The Bullet', artist: 'Randall')),
        throwsStateError);
  });
}
