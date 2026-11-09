// `composer_ids` (mig serveur 293) est ALIGNÉ sur `composer_names`: un nom que
// le client écarte doit emporter son uuid, sinon l'en-tête d'album ouvrirait
// le mauvais artiste pour tous les noms qui suivent.
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/artist_links.dart';
import 'package:rewamp/rewamp_db.dart';

void main() {
  test('ids recalés sur les noms gardés', () {
    final ids = AlbumDetails.alignedComposerIds(
        ['A', null, 'null', 'B', ''], ['ua', 'ux', 'uy', 'ub', 'uz']);
    expect(ids, ['ua', 'ub']);
  });

  test('un compositeur sans uuid garde sa place', () {
    final ids = AlbumDetails.alignedComposerIds(['A', 'B'], [null, 'ub']);
    expect(ids, ['', 'ub']);
    expect(artistIdAt(ids, 0), isNull);
    expect(artistIdAt(ids, 1), 'ub');
  });

  test('serveur sans la colonne: liste vide, repli au nom', () {
    expect(AlbumDetails.alignedComposerIds(['A'], null), isEmpty);
    final d = AlbumDetails.fromJson({
      'album_id': 'x', 'name': 'n', 'collection': 'c',
      'composer_names': ['A'],
    });
    expect(d.composerIds, isEmpty);
    expect(artistIdAt(d.composerIds, 0), isNull);
  });

  test('fromJson lit composer_ids', () {
    final d = AlbumDetails.fromJson({
      'album_id': 'x', 'name': 'n', 'collection': 'c',
      'composer_names': ['A', 'B'], 'composer_ids': ['ua', 'ub'],
    });
    expect(d.composerIds, ['ua', 'ub']);
  });
}
