// Explicit live catalogue check, not part of the offline regression suite:
// flutter test --no-pub tool/carplay_voice_search_smoke.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/carplay_voice_search.dart';

void main() {
  for (final (query, title, artist) in [
    (
      CarPlayVoiceQuery('The Bullet', artist: 'Randall'),
      'the bullet',
      'Randall'
    ),
    (
      CarPlayVoiceQuery('The Bullet', artist: 'Randal'),
      'the bullet',
      'Randall'
    ),
    (CarPlayVoiceQuery('The Bullet by Randal'), 'the bullet', 'Randall'),
    (
      CarPlayVoiceQuery('Acidland Metropolis', artist: 'Booster'),
      'acidland metropolis',
      'Booster'
    ),
    (
      CarPlayVoiceQuery('Acidland Metropolis by Booster'),
      'acidland metropolis',
      'Booster'
    ),
    (
      CarPlayVoiceQuery('Durban Poison', artist: 'Randall'),
      'durban poison',
      'Randall'
    ),
    (CarPlayVoiceQuery('Durban Poison by Randall'), 'durban poison', 'Randall'),
  ]) {
    test('live Siri lookup: ${query.text} / ${query.artist}', () async {
      final found = await CarPlayVoiceSearcher().search(query);
      expect(
          found.any((row) =>
              row.collection == 'modland' &&
              row.displayTitle.toLowerCase() == title &&
              row.artistNames.contains(artist)),
          true);
    });
  }
}
