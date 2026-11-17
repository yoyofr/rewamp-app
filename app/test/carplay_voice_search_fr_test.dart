// Siri en français (iOS, 2026-11-17: « souvent ça ne trouve pas le bon
// morceau »): transcription accentuée, « titre par / de artiste » laissé
// entier dans le titre, et un classement qui ne regardait que l'égalité
// exacte — la ligne la plus POPULAIRE contenant un mot commun gagnait.
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
  test('les accents de la transcription ne cachent pas le titre exact', () async {
    final popular = song('a', 'Zelda Overworld Remix Legende', 'X');
    final wanted = song('b', 'Legende de Zelda', 'Koji Kondo');
    final s = CarPlayVoiceSearcher(
      songs: (q, {artistName, artistId, albumName, required fuzzy, required limit}) async =>
          [popular, wanted],
      artists: (q, {required fuzzy, required limit}) async => [],
    );
    final r = await s.search(CarPlayVoiceQuery('Légende de Zelda'));
    expect(r.first.songId, 'b');
  });

  test('à défaut d\'exact, le titre qui contient le plus de mots dits gagne',
      () async {
    final popular = song('a', 'Main Theme', 'X');
    final wanted = song('b', 'Fairy Fountain Theme', 'Y');
    final s = CarPlayVoiceSearcher(
      songs: (q, {artistName, artistId, albumName, required fuzzy, required limit}) async =>
          [popular, wanted],
      artists: (q, {required fuzzy, required limit}) async => [],
    );
    final r = await s.search(CarPlayVoiceQuery('fairy fountain theme music'));
    expect(r.first.songId, 'b');
  });

  test('« titre par artiste » est découpé en français, au dernier connecteur',
      () async {
    final wanted = song('b', 'La Legende de Zelda', 'Koji Kondo');
    final seen = <(String, String?)>[];
    final s = CarPlayVoiceSearcher(
      songs: (q, {artistName, artistId, albumName, required fuzzy, required limit}) async {
        seen.add((q, artistName ?? artistId));
        if (q == 'La Légende de Zelda' && artistId == 'kk') return [wanted];
        return [];
      },
      artists: (q, {required fuzzy, required limit}) async =>
          q == 'Koji Kondo' ? [const ArtistResult(artistId: 'kk', name: 'Koji Kondo')] : [],
    );
    final r = await s.search(CarPlayVoiceQuery('La Légende de Zelda par Koji Kondo'));
    expect(r.single.songId, 'b');
  });
}
