import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/library_identity.dart';

/// « Sur un autre appareil » est une promesse que seul un compte JOIGNABLE peut
/// tenir. Sans e-mail, le compte ne peut pas être retrouvé ailleurs: un import
/// dont le fichier manque ici est un FANTÔME, et le nettoyage doit pouvoir
/// l'enlever. Constaté sur Android: 80 entrées d'un import Silksong dont une
/// réinstallation avait emporté les fichiers.
void main() {
  setUp(() {
    LibraryRoots.imports = '/app/files/local';
    LibraryRoots.downloads = '/app/files/online';
    LibraryRoots.importsAlt = null;
    LibraryRoots.archiveCache = null;
    LibraryRoots.opened = null;
  });

  const ref = '/app/files/local/Silksong/track.fsb';

  test('compte anonyme + fichier absent = fantôme', () {
    expect(
        libraryRefIsPhantomImport(ref,
            accountReachableElsewhere: false, fileExists: false),
        isTrue);
  });

  test('le fichier est là: rien à retirer', () {
    expect(
        libraryRefIsPhantomImport(ref,
            accountReachableElsewhere: false, fileExists: true),
        isFalse);
  });

  test('compte joignable: l\'entrée vit peut-être sur un autre appareil', () {
    expect(
        libraryRefIsPhantomImport(ref,
            accountReachableElsewhere: true, fileExists: false),
        isFalse);
  });

  test('un téléchargement n\'est pas un import — il meurt déjà de lui-même', () {
    const dl = '/app/files/online/sceneorg/x.mod';
    expect(
        libraryRefIsPhantomImport(dl,
            accountReachableElsewhere: false, fileExists: false),
        isFalse);
    expect(libraryRefIsDeadIdentity(dl), isTrue);
  });

  test('une identité de CATALOGUE ne meurt jamais du fichier', () {
    const uuid = '6d0cd913-12fc-5d68-a5f7-2aabbfdafc20?subsong=3';
    expect(
        libraryRefIsPhantomImport(uuid,
            accountReachableElsewhere: false, fileExists: false),
        isFalse);
  });
}
