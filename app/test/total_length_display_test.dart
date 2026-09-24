import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

// `total_length_ms` (listings serveur) est la durée du FICHIER; le vieux
// `subsong_length_ms` reste celle du PREMIER sous-chant. Ce qui s'affiche sur
// une ligne, et ce qu'on fait quand le serveur ne sait pas.
void main() {
  SearchResult row({int? total, int? first, int tracks = 1}) =>
      SearchResult.fromJson({
        'song_id': 'u', 'collection': 'hvsc', 'title': 't', 'filename': 'x.sid',
        'format_ext': 'sid', 'track_count': tracks,
        if (first != null) 'subsong_length_ms': first,
        if (total != null) 'total_length_ms': total,
      });

  test('conteneur: on montre le FICHIER, jamais son premier sous-chant', () {
    expect(RewampDb.listDurationMs(row(total: 700000, first: 235594, tracks: 19)),
        700000);
    expect(RewampDb.listDurationMs(row(first: 235594, tracks: 19)), isNull,
        reason: 'sans total, 3:55 désignerait une durée que rien ne joue');
  });

  test('fichier mono: sa durée, d\'où qu\'elle vienne', () {
    expect(RewampDb.listDurationMs(row(first: 61568)), 61568);
    expect(RewampDb.listDurationMs(row(total: 61568)), 61568);
    expect(RewampDb.listDurationMs(row()), isNull, reason: 'inconnu ≠ 0:00');
  });

  test('ligne qui DÉSIGNE une piste du conteneur: pas la durée du fichier', () {
    // search_music rend la ligne du FICHIER avec match_track_title quand la
    // recherche a trouvé un titre à l'intérieur. « Iron Arms » affichait
    // 1:18:37, la durée des 73 sous-chants de « Juukou Senki Bullet
    // Battlers.gbs ». Le serveur ne donne pas la durée de cette piste-là.
    final matched = SearchResult.fromJson({
      'song_id': 'u', 'collection': 'jw_gbs', 'title': 'Juukou Senki',
      'filename': 'Juukou Senki.gbs', 'format_ext': 'gbs', 'track_count': 73,
      'total_length_ms': 4717000,
      'match_track_title': 'Iron Arms [Iron Ore Weapon Battle]',
      'match_track_index': 1,
    });
    expect(RewampDb.listDurationMs(matched), isNull,
        reason: 'serveur d\'avant match_track_length_ms: rien plutôt que faux');

    // Depuis le 2026-09-06 le serveur donne la durée de la piste nommée.
    final withLen = SearchResult.fromJson({
      'song_id': 'u', 'collection': 'jw_gbs', 'title': 'Juukou Senki',
      'filename': 'Juukou Senki.gbs', 'format_ext': 'gbs', 'track_count': 73,
      'total_length_ms': 4717000,
      'match_track_title': 'Iron Arms [Iron Ore Weapon Battle]',
      'match_track_index': 1,
      'match_track_length_ms': 53000,
    });
    expect(RewampDb.listDurationMs(withLen), 53000);
    expect(RewampDb.formatDurationMs(53000), '0:53');

    // Même règle pour une entrée épinglée à un sous-chant.
    final pinned = row(total: 700000, first: 235594, tracks: 19).withSubsongEntry(3);
    expect(RewampDb.listDurationMs(pinned), isNull);
  });

  test('somme: exacte ou rien', () {
    expect(RewampDb.sumSubsongDurationsMs([1000, 2000, 500]), 3500);
    expect(RewampDb.sumSubsongDurationsMs([1000, null, 500]), isNull);
    expect(RewampDb.sumSubsongDurationsMs([1000, 0]), isNull);
    expect(RewampDb.sumSubsongDurationsMs(const []), isNull);
  });

  test('format: m:ss, et h:mm:ss au-delà de l\'heure', () {
    expect(RewampDb.formatDurationMs(61568), '1:01');
    expect(RewampDb.formatDurationMs(4680), '0:04');
    expect(RewampDb.formatDurationMs(3723000), '1:02:03');
  });

  test('total d\'album: exact, partiel avec « + », ou rien', () {
    // Le serveur ne rend pas de total d'ALBUM (total_length_ms est PAR
    // fichier): le client somme les lignes, et le dit quand c'est partiel.
    expect(
      RewampDb.albumDurationLabel(
          [row(first: 60000), row(first: 90000), row(first: 30000)]),
      '3:00',
    );
    expect(
      RewampDb.albumDurationLabel([row(first: 60000), row(), row(first: 90000)]),
      '2:30+',
      reason: 'partielle, elle ne doit pas se faire passer pour exacte',
    );
    expect(RewampDb.albumDurationLabel([row(), row()]), isNull);
    expect(RewampDb.albumDurationLabel(const []), isNull);
  });

  test('total d\'album: un conteneur compte pour son FICHIER', () {
    // Une ligne de conteneur n'apporte que total_length_ms; sans lui elle ne
    // compte pas — son premier sous-chant n'est pas la durée de l'album.
    expect(
      RewampDb.albumDurationLabel(
          [row(total: 120000, first: 30000, tracks: 8), row(first: 60000)]),
      '3:00',
    );
    expect(
      RewampDb.albumDurationLabel(
          [row(first: 30000, tracks: 8), row(first: 60000)]),
      '1:00+',
    );
  });

  test('le champ survit à la persistance de la file', () {
    final r = row(total: 700000, first: 235594, tracks: 19);
    expect(SearchResult.fromJson(r.toJson()).totalLengthMs, 700000);
  });
}
