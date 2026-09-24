import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/settings_screen.dart';

/// L'écran Réglages → Moteurs liste ses moteurs par NOM. La liste dans le code
/// n'est donc plus qu'un inventaire: écrire un moteur neuf n'importe où le
/// range au bon endroit, là où une liste ordonnée à la main dérive au premier
/// ajout pressé.
void main() {
  test('l\'ordre est insensible à la CASSE', () {
    // Comparer les chaînes telles quelles range toutes les majuscules avant
    // toutes les minuscules: on obtient deux alphabets, et « UADE » se
    // retrouve loin de « libvgm ». Ce n'est pas ce qu'on lit dans une liste.
    expect(compareEngineNames('UADE', 'libvgm'), greaterThan(0));
    expect(compareEngineNames('AdPlug', 'FluidLite'), lessThan(0));
    expect('UADE'.compareTo('libvgm'), lessThan(0),
        reason: 'le piège que la comparaison naïve tend');
  });

  test('les moteurs livrés sortent dans l\'ordre attendu', () {
    final names = <String>[
      'libopenmpt', 'libgme', 'nsfplay', 'gbsplay', 'FluidLite',
      'libgsf (VBA)', 'UADE', 'libsidplayfp', 'AdPlug',
      'Highly Experimental', 'libvgm',
    ]..sort(compareEngineNames);
    expect(names, [
      'AdPlug',
      'FluidLite',
      'gbsplay',
      'Highly Experimental',
      'libgme',
      'libgsf (VBA)',
      'libopenmpt',
      'libsidplayfp',
      'libvgm',
      'nsfplay',
      'UADE',
    ]);
  });

  test('chaque moteur du menu du lecteur a un nom de page', () {
    // kEngineSettingsPages est la table du raccourci « Réglages du moteur »:
    // ses titres sont les mêmes noms, et un titre vide sortirait en tête de
    // liste sans qu'on le voie.
    for (final e in kEngineSettingsPages.entries) {
      expect(e.value.title.trim(), isNotEmpty, reason: 'slug ${e.key}');
    }
  });
}
