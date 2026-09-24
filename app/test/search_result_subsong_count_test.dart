// `SearchResult.subsongCount` doit accepter les DEUX noms de colonne serveur.
//
// Le renommage de 2026-07 (`subsong_count` → `track_count`) n'a PAS touché les
// palmarès: `most_popular_songs` rend encore `subsong_count` (vérifié dans sa
// signature, migration serveur 244, et documenté par la mig 216). Ne lire que
// `track_count` laissait donc le compte NUL sur tout rail servi par ces RPC —
// « Tendances », « Top de tous les temps » — et « Voir les sous-chansons » ne
// pouvait pas s'afficher pour un fichier qui en porte vingt.
//
// Le compte pilote aussi le routage vers l'écran conteneur, donc l'absence ne
// se voyait pas qu'à cet endroit.
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

Map<String, dynamic> _row(Map<String, dynamic> extra) => {
      'song_id':    '00000000-0000-0000-0000-000000000001',
      'collection': 'hvsc',
      'title':      'Commando',
      'filename':   'Commando.sid',
      ...extra,
    };

void main() {
  test('le nom RENOMMÉ est lu (search_music, browse_music…)', () {
    expect(SearchResult.fromJson(_row({'track_count': 21})).subsongCount, 21);
  });

  test('le nom D\'ORIGINE est lu (palmarès, jamais renommés)', () {
    expect(SearchResult.fromJson(_row({'subsong_count': 21})).subsongCount, 21);
  });

  test('un `subsong_index` serveur marque la ligne comme DÉJÀ RÉSOLUE', () {
    // Les palmarès sont la SEULE famille à rendre `subsong_index` (vérifié
    // contre search_music, browse_music, get_album_tracks, list_featured): sa
    // présence dit que le serveur a nommé UNE sous-chanson. Sans ce drapeau,
    // l'expansion déplie le fichier en 0..count-1 et la lecture repart de la
    // sous-chanson 0 — deux entrées d'un même module dans un palmarès
    // jouaient alors toutes deux la première.
    final r = SearchResult.fromJson(
        _row({'subsong_count': 21, 'subsong_index': 7}));
    expect(r.resolvedSubsong, isTrue);
    expect(r.subsongIdx, 7);
  });

  test('sans `subsong_index`, la ligne reste un CONTENEUR à déplier', () {
    final r = SearchResult.fromJson(_row({'track_count': 21}));
    expect(r.resolvedSubsong, isFalse);
  });

  test('absent des deux côtés: null, et surtout pas 0', () {
    // null veut dire « on ne sait pas »; 0 voudrait dire « aucune piste », ce
    // qu'aucun fichier jouable n'est.
    expect(SearchResult.fromJson(_row(const {})).subsongCount, isNull);
  });
}
