import 'rewamp_db.dart';
import 'voice_text.dart';

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

    // Siri a laissé « titre + artiste » ENTIER dans le titre. Découpage
    // INDÉPENDANT de la langue: aucun connecteur connu d'avance (« by », « par »,
    // « von », « の »…) — on essaie les quelques derniers puis premiers mots
    // comme artiste (l'artiste vient AVANT le titre en japonais, chinois,
    // coréen), en retirant le petit mot de liaison qui les sépare, et c'est le
    // CATALOGUE qui tranche: seul un nom que la recherche d'artistes reconnaît
    // est retenu. La forme intacte a déjà été essayée juste au-dessus.
    if (query.artist == null) {
      final split = await _searchSplit(query);
      if (split.isNotEmpty) return split;
    } else {
      // Siri a rempli l'artiste ET l'a laissé dans le titre (« The Bullet by
      // Randall », artiste « Randal »): le découpage dont l'artiste lui
      // ressemble suffit, sans requête d'artistes.
      for (final (title, who) in splitCandidates(query.text)) {
        if (!_close(query.artist!, who)) continue;
        final rows = await search(
            CarPlayVoiceQuery(title, artist: query.artist, album: query.album));
        if (rows.isNotEmpty) return rows;
      }
    }
    // Écriture non latine (cyrillique, grec, kana): le catalogue est surtout
    // latin — un second essai sous la forme translittérée (« Тетрис » → tetris).
    if (hasTransliterableScript(query.text)) {
      final latin = foldVoiceText(query.text);
      final rows = await _songs(latin,
          artistName: query.artist,
          albumName: query.album,
          fuzzy: true,
          limit: _candidates);
      if (rows.isNotEmpty) return _rank(rows, latin);
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

  Future<List<SearchResult>> _searchSplit(CarPlayVoiceQuery query) async {
    final candidates = splitCandidates(query.text);
    if (candidates.isEmpty) return [];
    // Les noms candidats, validés EN PARALLÈLE (Siri n'attend pas): un nom
    // n'est gardé que si la recherche d'artistes en rend un proche.
    final names = {for (final c in candidates) c.$2}.take(8).toList();
    final known = <String>{};
    await Future.wait(names.map((name) async {
      final hits = await _artists(name, fuzzy: true, limit: 5);
      if (hits.any((a) => _close(name, a.name))) known.add(name);
    }));
    for (final (title, who) in candidates) {
      if (!known.contains(who)) continue;
      final rows =
          await search(CarPlayVoiceQuery(title, artist: who, album: query.album));
      if (rows.isNotEmpty) return rows;
    }
    return [];
  }

  /// Les découpages (titre, artiste) plausibles d'une phrase, du plus au moins
  /// probable. Pur et testé.
  static List<(String, String)> splitCandidates(String text) {
    final out = <(String, String)>[];
    void add(String title, String who) {
      title = title.trim();
      // Élision collée à l'artiste: « d'AC/DC », « l'Orchestre ».
      who = who.trim().replaceFirst(RegExp(r"^\p{L}['’]", unicode: true), '');
      if (title.isEmpty || who.isEmpty) return;
      if (!out.contains((title, who))) out.add((title, who));
    }
    // CJK: pas d'espaces — on coupe à la particule possessive (の 的 의),
    // artiste AVANT (« 久石譲の… »), sinon après.
    final cjk = RegExp(r'[のの的의]').allMatches(text).toList();
    if (cjk.isNotEmpty) {
      final m = cjk.first;
      add(text.substring(m.end), text.substring(0, m.start));
      add(text.substring(0, m.start), text.substring(m.end));
    }
    final words = text.trim().split(RegExp(r'\s+'));
    final n = words.length;
    bool small(String w) => w.runes.length <= 3;
    for (var k = 1; k <= 3 && k < n; k++) {
      // Artiste à la FIN, mot de liaison retiré (« … par Koji Kondo »).
      final head = words.sublist(0, n - k);
      final tail = words.sublist(n - k).join(' ');
      if (head.length > 1 && small(head.last)) {
        add(head.sublist(0, head.length - 1).join(' '), tail);
      }
      // Élision collée: « Thunderstruck d'AC/DC ».
      if (k == 1 && RegExp(r"^\p{L}['’]", unicode: true).hasMatch(tail)) {
        add(head.join(' '), tail);
      }
    }
    for (var k = 1; k <= 3 && k < n; k++) {
      // Artiste au DÉBUT (« Koji Kondo – Ocarina », ordre japonais romanisé).
      final who = words.sublist(0, k).join(' ');
      final rest = words.sublist(k);
      if (rest.length > 1 && small(rest.first)) {
        add(rest.sublist(1).join(' '), who);
      }
    }
    return out;
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
    // The server can rank album matches ahead of exact track names, and its
    // order is POPULARITY among rows that merely contain the words. Rank by
    // how well the TITLE matches what was said: exact first, then the share
    // of spoken words the title contains, then the closest length — and only
    // then the server order. Exact-only ranking let the most popular row with
    // a shared word win whenever Siri's transcription differed by an accent
    // or a word (« souvent ça ne trouve pas le bon morceau », iOS FR).
    final want = normalized.split(' ').where((w) => w.isNotEmpty).toSet();
    double score(SearchResult r) {
      final t = _normal(r.displayTitle);
      if (t == normalized) return 0;
      final have = t.split(' ').toSet();
      final hit = want.isEmpty ? 0 : want.where(have.contains).length / want.length;
      final extra = have.length > want.length ? have.length - want.length : 0;
      return 2 - hit + extra * 0.05;
    }
    final indexed = rows.indexed.map((e) => (e.$1, e.$2, score(e.$2))).toList();
    indexed.sort((a, b) {
      final c = a.$3.compareTo(b.$3);
      if (c != 0) return c;
      return a.$1.compareTo(b.$1);
    });
    final seen = <String>{};
    return [
      for (final (_, row, _) in indexed)
        if (seen.add('${row.songId}:${row.subsongIdx}')) row
    ].take(5).toList();
  }

  /// Minuscules, sans diacritiques, translittéré quand c'est possible
  /// (voice_text.dart), « & » = « and », ponctuation en espaces.
  static String _normal(String value) => foldVoiceText(value)
      .replaceAll(RegExp(r'\s*&\s*'), ' and ')
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
