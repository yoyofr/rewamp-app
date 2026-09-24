import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/artwork_image.dart';

/// Une pochette rangée à côté de son morceau se nomme d'après le fichier
/// COMPLET — extension comprise.
///
/// La convention Amiga met le FORMAT avant le point (`mdat.monkey island`), donc
/// `basenameWithoutExtension` y répond « mdat »: tous les modules d'un dossier
/// partageaient un unique `mdat.jpg`. Constaté sur un vrai profil — un seul
/// `mdat.jpg` pour trois modules de Chris Hülsbeck.
void main() {
  test('un nom Amiga ne collisionne plus avec ses voisins', () {
    final a = ArtworkCache.artBasenameFor('/x/amiga/mdat.monkey island');
    final b = ArtworkCache.artBasenameFor('/x/amiga/mdat.carl lewis challenge');
    expect(a, 'mdat.monkey island');
    expect(b, 'mdat.carl lewis challenge');
    expect(a, isNot(b));   // c'était « mdat » et « mdat »
  });

  test('les trois modules du cas réel donnent trois noms distincts', () {
    final names = [
      'mdat.monkey island',
      'mdat.carl lewis challenge',
      'mdat.carl lewis challenge-ingame',
    ].map((f) => ArtworkCache.artBasenameFor('/x/$f')).toSet();
    expect(names.length, 3);
  });

  test('un nom ordinaire garde son extension, donc reste unique aussi', () {
    // Deux formats du MÊME morceau coexistent dans un dossier d'album: sans
    // l'extension ils se seraient écrasés de la même façon.
    expect(ArtworkCache.artBasenameFor('/x/Chrono Trigger.spc'),
        'Chrono Trigger.spc');
    expect(ArtworkCache.artBasenameFor('/x/Chrono Trigger.rsn'),
        'Chrono Trigger.rsn');
  });

  test('un fichier sans extension reste entier', () {
    expect(ArtworkCache.artBasenameFor('/x/MODULE'), 'MODULE');
  });
}
