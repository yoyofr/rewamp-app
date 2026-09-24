import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/artwork_image.dart';

// Un nom Amiga porte son FORMAT avant le point: « mdat.apidya (level 1) ».
// La recherche de pochette voisine essaie le nom COMPLET puis, pour une
// pochette déposée à la main, le nom sans extension — qui vaut ici « mdat »,
// commun à tout le dossier d'un artiste. Un `mdat.jpg` (résidu d'une version
// d'avant, ou dépôt manuel) servait donc la pochette d'un module à tous les
// autres: Apidya affichait celle de Monkey Island, même artiste, même dossier.
void main() {
  const dir = '/m/Chris Hulsbeck/amiga';
  const listing = [
    '$dir/mdat.apidya (level 1)',
    '$dir/mdat.monkey island',
    '$dir/mdat.monkey island.jpg',
    '$dir/mdat.turrican 2 level 0-intro',
    '$dir/mdat.turrican 2 level 0-intro.png',
    '$dir/mdat.jpg', // résidu ambigu
    '$dir/smpl.apidya (level 1)',
  ];

  test('nom de forme préfixe: pas de repli sur le TOKEN de format', () {
    expect(
      ArtworkCache.localArtworkFromListing(
          listing, '$dir/mdat.apidya (level 1)'),
      isNull,
      reason: 'aucune pochette pour ce module — mieux que celle du voisin',
    );
  });

  test('le nom COMPLET reste trouvé', () {
    expect(
      ArtworkCache.localArtworkFromListing(listing, '$dir/mdat.monkey island'),
      '$dir/mdat.monkey island.jpg',
    );
    expect(
      ArtworkCache.localArtworkFromListing(
          listing, '$dir/mdat.turrican 2 level 0-intro'),
      '$dir/mdat.turrican 2 level 0-intro.png',
    );
  });

  test('nom ordinaire: le repli « déposée à la main » vaut toujours', () {
    const d2 = '/m/album';
    const l2 = ['$d2/Axelay.spc', '$d2/Axelay.jpg', '$d2/Other.spc'];
    expect(ArtworkCache.localArtworkFromListing(l2, '$d2/Axelay.spc'),
        '$d2/Axelay.jpg');
  });
}
