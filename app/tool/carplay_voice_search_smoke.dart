// Explicit live catalogue check, not part of the offline regression suite:
// flutter test --no-pub tool/carplay_voice_search_smoke.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/carplay_voice_search.dart';

void main() {
  for (final query in [
    CarPlayVoiceQuery('The Bullet', artist: 'Randall'),
    CarPlayVoiceQuery('The Bullet', artist: 'Randal'),
    CarPlayVoiceQuery('The Bullet by Randal'),
  ]) {
    test('live Siri lookup: ${query.text} / ${query.artist}', () async {
      final found = await CarPlayVoiceSearcher().search(query);
      expect(
          found.any((row) =>
              row.collection == 'modland' &&
              row.displayTitle.toLowerCase() == 'the bullet' &&
              row.artistNames.contains('Randall')),
          true);
    });
  }
}
