import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

// `subsong_length_ms` (search_music, browse_music, get_song_context) est la
// durée du PREMIER sous-chant, pas celle du fichier. Mesuré sur « Commando »
// (hvsc): la ligne annonce 235594 ms, or les sous-chants font 235594, 61288,
// 6000, 1124, 645, 964… La recopier en dépliant donnait 3:55 sur les 19
// lignes — affiché, et APPLIQUÉ par le filet « fin connue » (un SID ne finit
// jamais seul): 3:55 de silence sur un sous-chant d'une seconde.
void main() {
  SearchResult row() => SearchResult.fromJson({
        'song_id': 'uuid',
        'collection': 'hvsc',
        'title': 'Commando',
        'filename': 'Commando.sid',
        'format_ext': 'sid',
        'track_count': 19,
        'subsong_length_ms': 235594,
      });

  test('la ligne du conteneur garde la durée du premier sous-chant', () {
    expect(row().durationMs, 235594);
    expect(row().withSubsong(0).durationMs, 235594,
        reason: 'sous-chant 0 = celui que le serveur a mesuré');
  });

  test('un AUTRE sous-chant part sans durée plutôt qu\'avec une fausse', () {
    expect(row().withSubsong(3).durationMs, isNull);
    expect(row().withSubsongEntry(3).durationMs, isNull);
  });

  test('une durée connue est évidemment conservée', () {
    expect(row().withSubsong(3, durationMs: 1124).durationMs, 1124);
  });

  test('re-désigner le MÊME sous-chant ne perd rien', () {
    final pinned = row().withSubsong(3, durationMs: 1124);
    expect(pinned.withSubsong(3).durationMs, 1124);
    expect(pinned.withSubsongEntry(3).durationMs, 1124);
  });
}
