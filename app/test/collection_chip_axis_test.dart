// L'axe de puce d'une collection (General MIDI / MT-32 sur `midi`).
//
// Ce qui se teste sans serveur: la table elle-même et la façon dont le nom de
// tag voyage. Les NOMS comptent — le serveur apparie `tags TEXT[]` par NOM,
// jamais par slug (voir RewampDb._tagParams), donc un `mt-32` écrit ici ne
// filtrerait RIEN et le symptôme serait une liste vide, pas une erreur.
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/collection_chip_axis.dart';

void main() {
  test('midi propose General MIDI et MT-32, par NOM de tag', () {
    expect(chipAxisFor('midi'), ['General MIDI', 'MT-32']);
  });

  test('une collection sans axe ne propose rien (et null non plus)', () {
    expect(chipAxisFor('modland'), isEmpty);
    expect(chipAxisFor(null), isEmpty);
  });

  test('aucun slug ne se glisse dans la table', () {
    // Un slug (minuscules, tirets, pas d'espace) serait la faute silencieuse:
    // le serveur ne l'apparie pas.
    for (final entry in kCollectionChipAxis.entries) {
      for (final tag in entry.value) {
        expect(tag, isNot(matches(RegExp(r'^[a-z0-9-]+$'))),
            reason: '${entry.key}: "$tag" ressemble à un slug, pas à un nom');
      }
    }
  });
}
