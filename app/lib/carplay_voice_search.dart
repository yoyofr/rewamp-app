import 'rewamp_db.dart';

typedef VoiceSongSearch = Future<List<SearchResult>> Function(String query,
    {String? artistName,
    String? artistId,
    String? albumName,
    required bool fuzzy,
    required int limit});
typedef VoiceArtistSearch = Future<List<ArtistResult>> Function(String query,
    {required bool fuzzy, required int limit});

/// Keep Siri's fields separate: the catalogue's text query does not match
/// words distributed across a song title and its artist name.
class CarPlayVoiceQuery {
  CarPlayVoiceQuery(String text, {String? artist, String? album})
      : text = text.trim(),
        artist = _optional(artist),
        album = _optional(album);

  final String text;
  final String? artist;
  final String? album;
  bool get isEmpty => text.isEmpty && artist == null && album == null;

  static String? _optional(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}

class CarPlayVoiceSearcher {
  CarPlayVoiceSearcher({VoiceSongSearch? songs, VoiceArtistSearch? artists})
      : _songs = songs ?? RewampDb.search,
        _artists = artists ?? RewampDb.searchArtists;

  final VoiceSongSearch _songs;
  final VoiceArtistSearch _artists;
  static const _candidates = 50;

  Future<List<SearchResult>> search(CarPlayVoiceQuery query) async {
    if (query.isEmpty) return [];
    // A title can itself contain "by". Try it intact before interpreting a
    // whole utterance left in mediaName as "title by artist".
    final exact = await _songs(query.text,
        artistName: query.artist,
        albumName: query.album,
        fuzzy: false,
        limit: _candidates);
    if (exact.isNotEmpty) return _rank(exact, query.text);

    final by = RegExp(r'^(.+)\s+by\s+(.+)$', caseSensitive: false)
        .firstMatch(query.text);
    if (by != null && (query.artist == null || _close(query.artist!, by[2]!))) {
      return search(CarPlayVoiceQuery(by[1]!,
          artist: query.artist ?? by[2], album: query.album));
    }
    if (query.artist == null) {
      return _fuzzyTitle(query);
    }

    // search_music's artist filter remains strict even when fuzzy=true.
    // Resolve a small, plausible set of canonical artist IDs first. The artist
    // RPC also returns cross-entity matches, so reject unrelated names locally.
    final artists = (await _artists(query.artist!, fuzzy: true, limit: 20))
        .where((artist) => _close(query.artist!, artist.name))
        .toList();
    artists.sort((a, b) => _distance(_normal(query.artist!), _normal(a.name))
        .compareTo(_distance(_normal(query.artist!), _normal(b.name))));
    final matches = <SearchResult>[];
    final seenArtists = <String>{};
    for (final artist in artists) {
      if (!seenArtists.add(artist.artistId)) continue;
      if (seenArtists.length > 3) break;
      final rows = await _songs(query.text,
          artistId: artist.artistId,
          albumName: query.album,
          fuzzy: false,
          limit: _candidates);
      matches.addAll(rows.isNotEmpty
          ? rows
          : await _fuzzyTitle(query, artistId: artist.artistId));
    }
    return _rank(matches, query.text);
  }

  Future<List<SearchResult>> _fuzzyTitle(CarPlayVoiceQuery query,
      {String? artistId}) async {
    if (query.text.isEmpty) return [];
    final rows = await _songs(query.text,
        artistName: artistId == null ? query.artist : null,
        artistId: artistId,
        albumName: query.album,
        fuzzy: true,
        limit: _candidates);
    return _rank(
        rows.where((row) => _close(query.text, row.displayTitle)).toList(),
        query.text);
  }

  static List<SearchResult> _rank(List<SearchResult> rows, String title) {
    final normalized = _normal(title);
    // The server can rank album matches ahead of exact track names. Retrieve
    // a bounded candidate page, then prefer the requested title for Siri's five
    // disambiguation choices, retaining the server order among equal matches.
    final indexed = rows.indexed.toList();
    indexed.sort((a, b) {
      final aExact = _normal(a.$2.displayTitle) == normalized;
      final bExact = _normal(b.$2.displayTitle) == normalized;
      if (aExact != bExact) return aExact ? -1 : 1;
      return a.$1.compareTo(b.$1);
    });
    final seen = <String>{};
    return [
      for (final (_, row) in indexed)
        if (seen.add('${row.songId}:${row.subsongIdx}')) row
    ].take(5).toList();
  }

  static String _normal(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'''[\s_.,\-!?'"“”‘’/\\:;()\[\]{}]+'''), ' ')
      .trim();

  static bool _close(String requested, String candidate) {
    final a = _normal(requested), b = _normal(candidate);
    if (a == b) return true;
    // Avoid broad corrections of short handles, and bound work for arbitrary
    // recognized text. One edit covers Randal/Randall; longer names allow two.
    if (a.length < 4 || a.length > 100 || b.length > 100) return false;
    final edits = a.length >= 8 ? 2 : 1;
    if ((a.length - b.length).abs() > edits) return false;
    return _distance(a, b) <= edits;
  }

  static int _distance(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final replace = previous[j] + (a[i] == b[j] ? 0 : 1);
        final insert = current[j] + 1;
        final delete = previous[j + 1] + 1;
        current[j + 1] =
            [replace, insert, delete].reduce((a, b) => a < b ? a : b);
      }
      previous = current;
    }
    return previous.last;
  }
}
