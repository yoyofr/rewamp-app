import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/home_screen.dart';

/// Relancer un album depuis « Écoutés récemment » complétait sa liste en
/// scannant le dossier. Mesuré sur « Wild Arms 3 » (jw_psf2): 115 pistes au
/// catalogue ET en base, 138 fichiers d'allure audio sur le disque — doublons
/// régionaux `[jp]`/`[us]` et `.vgmstream` que le rip embarque sans les lister.
/// La file passait de 115 à 139, dont des entrées injouables.
void main() {
  test('album MATÉRIALISÉ: la liste du catalogue fait autorité', () {
    expect(
      shouldScanAlbumDirectory(catalogueAlbum: true, materialised: true, tracks: 115, dbTracks: 115),
      isFalse,
    );
  });

  test('album non matérialisé: la base ne contient que ce qui a été joué', () {
    // Le cas que le scan sert: un album multi-fichiers dont on n'a joué que
    // trois pistes.
    expect(
      shouldScanAlbumDirectory(catalogueAlbum: true, materialised: false, tracks: 3, dbTracks: 3),
      isTrue,
    );
  });

  test('une branche a DÉJÀ déplié la liste — ne pas l\'écraser', () {
    // M3U, sous-chansons ou songdb UADE ont rendu plus que la base: le scan
    // remplacerait cette liste par la sienne.
    expect(
      shouldScanAlbumDirectory(catalogueAlbum: true, materialised: false, tracks: 40, dbTracks: 3),
      isFalse,
    );
  });

  test('rien en base: rien à compléter', () {
    expect(
      shouldScanAlbumDirectory(catalogueAlbum: true, materialised: false, tracks: 0, dbTracks: 0),
      isFalse,
    );
  });

  test('album LOCAL (sans uuid): la base est sa liste, jamais de scan', () {
    // « The Seven Gates of Jambala », un .hip à la RACINE des imports: son
    // parent est `local/` entier — le scan en faisait une file de 200 pistes
    // démarrant sur Battle Garegga, chacune estampillée de sa pochette.
    expect(
      shouldScanAlbumDirectory(
          catalogueAlbum: false, materialised: false, tracks: 1, dbTracks: 1),
      isFalse,
    );
  });
}
