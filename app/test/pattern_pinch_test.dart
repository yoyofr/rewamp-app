// Les gestes de la vue MOTIFS: un geste, un réglage.
//   • pincement (2 doigts) → taille de police, en continu;
//   • glissement vertical (1 doigt) → détail des colonnes, par crans;
//   • glissement horizontal (1 doigt) → défilement.
// Seule la décision des CRANS est pure et testable ici — un widget de
// visualiseur ne se teste pas.

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/pattern_scope_widget.dart';
import 'package:rewamp/user_settings.dart';

void main() {
  group('détail des colonnes (glissement vertical)', () {
    test('vers le HAUT = plus de détail, donc un delta NÉGATIF', () {
      // L'index va dans l'autre sens (0 = tout, 2 = la note seule): monter le
      // doigt doit FAIRE BAISSER l'index.
      expect(patternColumnSteps(-kPatternColumnsDragStep), -1);
      expect(patternColumnSteps(-2 * kPatternColumnsDragStep), -2);
    });

    test('vers le BAS = moins de détail', () {
      expect(patternColumnSteps(kPatternColumnsDragStep), 1);
      expect(patternColumnSteps(2 * kPatternColumnsDragStep), 2);
    });

    test('un petit mouvement ne change rien', () {
      expect(patternColumnSteps(0), 0);
      expect(patternColumnSteps(10), 0);
      expect(patternColumnSteps(-10), 0);
    });

    test('le pas est symétrique', () {
      for (final d in [30.0, 90.0, 150.0, 400.0]) {
        expect(patternColumnSteps(d), -patternColumnSteps(-d));
      }
    });

    test('appliqué à la valeur de DÉPART, le résultat reste dans 0..2', () {
      for (final start in [0, 1, 2]) {
        for (final dy in [-500.0, -70.0, 0.0, 70.0, 500.0]) {
          final v = (start + patternColumnSteps(dy)).clamp(0, 2);
          expect(v, inInclusiveRange(0, 2));
        }
      }
    });
  });

  group('taille de police (pincement)', () {
    test('la quantification borne et arrondit au pas', () {
      // Ce que le pincement pose: taille de départ × facteur, quantifiée.
      expect(UserSettings.quantizePatternSize(1.0 * 1.5), 1.5);
      expect(UserSettings.quantizePatternSize(1.0 * 0.004),
          UserSettings.kPatternSizeMin);
      expect(UserSettings.quantizePatternSize(1.0 * 99),
          UserSettings.kPatternSizeMax);
    });

    test('un facteur 1 ne bouge rien', () {
      for (final v in [0.15, 0.5, 1.0, 2.0]) {
        expect(UserSettings.quantizePatternSize(v * 1.0), v);
      }
    });
  });
}
