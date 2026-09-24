import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/artwork_image.dart';

/// La pochette d'un DOSSIER du navigateur local: seulement les règles
/// génériques — un nom consacré, sinon l'unique image qui n'appartient à
/// aucune piste. Jamais la pochette d'un seul morceau.
void main() {
  const d = '/imports/Battle Garegga';

  test('nom consacré', () {
    expect(ArtworkCache.folderArtworkFromListing(['$d/01.vgz', '$d/cover.jpg', '$d/02.vgz']),
        '$d/cover.jpg');
  });

  test("l'unique image, même nommée comme l'album et sa playlist", () {
    expect(ArtworkCache.folderArtworkFromListing(['$d/01.vgz', '$d/Album.png', '$d/Album.m3u']),
        '$d/Album.png');
  });

  test("l'image d'UN morceau n'est pas celle du dossier", () {
    expect(ArtworkCache.folderArtworkFromListing(['$d/01.sid', '$d/01.jpg', '$d/02.sid']), isNull);
  });

  test('deux images sans nom consacré: ambigu, rien', () {
    expect(ArtworkCache.folderArtworkFromListing(['$d/a.png', '$d/b.png', '$d/01.sid']), isNull);
  });

  test('dossier vide', () {
    expect(ArtworkCache.folderArtworkFromListing(const []), isNull);
  });


  // Une image qui porte le NOM DU DOSSIER est sa pochette, même si une piste
  // du dossier porte le même radical (`cbmt/cbmt.jpg` + `cbmt/cbmt.mid`): la
  // règle générique l'écartait comme « appartenant à la piste », et le dossier
  // restait sur son icône alors que le morceau montrait l'image.
  test('image au nom du dossier: pochette du dossier', () {
    expect(
      ArtworkCache.folderArtworkFromListing(
        ['/l/cbmt/cbmt.mid', '/l/cbmt/CB.SYX', '/l/cbmt/cbmt.jpg'],
        folderName: 'cbmt',
      ),
      '/l/cbmt/cbmt.jpg',
    );
  });

  test('sans le nom du dossier, la règle générique décide encore', () {
    // L'image appartient à la piste: rien pour le dossier (règle d'avant).
    expect(
      ArtworkCache.folderArtworkFromListing(
        ['/l/cbmt/cbmt.mid', '/l/cbmt/cbmt.jpg'],
        folderName: 'autre',
      ),
      isNull,
    );
    // Nom consacré: toujours pris.
    expect(
      ArtworkCache.folderArtworkFromListing(
        ['/l/x/a.mid', '/l/x/folder.jpg'],
        folderName: 'x',
      ),
      '/l/x/folder.jpg',
    );
  });

}
