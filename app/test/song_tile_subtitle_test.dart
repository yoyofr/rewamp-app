// La COLLECTION a sa propre ligne, en petit, sous le sous-titre — pas une
// mention de plus au milieu de six autres. Une recherche brasse toutes les
// collections: d'où vient la ligne est justement ce qu'on y cherche, et noyée
// entre l'album, la plateforme, le format et la taille, elle était illisible.

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';
import 'package:rewamp/song_tile.dart';

SearchResult _row({
  String title = 'Commando',
  String collection = 'hvsc',
  String? album,
  String? platform,
  String formatExt = 'sid',
  List<String> artists = const ['Rob Hubbard'],
}) =>
    SearchResult(
      songId: 'id', collection: collection, title: title,
      filename: 'Commando.sid', album: album, formatExt: formatExt,
      downloadUrl: null, fileSize: 0, year: null,
      artistNames: artists, totalCount: 0, platform: platform,
    );

void main() {
  test('la collection n\'est PAS dans la ligne principale', () {
    final s = songTileSubtitle(_row(collection: 'jw_dsf'));
    expect(s, isNot(contains('jw_dsf')));
    expect(s, contains('Rob Hubbard'));
  });

  test('la ligne principale garde ce que le morceau EST', () {
    final s = songTileSubtitle(
        _row(album: 'Commando OST', platform: 'C64', formatExt: 'sid'));
    expect(s, 'Rob Hubbard · Commando OST · C64 · SID');
  });

  test('un album identique au titre n\'est pas répété', () {
    expect(songTileSubtitle(_row(album: 'Commando')),
        isNot(contains('Commando ·')));
  });

  test('le libellé de collection retombe sur le SLUG tant qu\'il est inconnu',
      () {
    // La table de référence n'est pas chargée dans un test: mieux vaut un slug
    // qu'un trou.
    expect(RewampDb.collectionLabel('jw_dsf'), 'jw_dsf');
  });
}
