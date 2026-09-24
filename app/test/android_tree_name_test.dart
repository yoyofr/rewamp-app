import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_import.dart';

/// Le nom du dossier importé sur Android vient de l'URI d'ARBRE SAF: il n'y a
/// pas de chemin de système de fichiers à lire (c'est tout le point du
/// correctif — un chemin brut n'est pas lisible sans permission de stockage).
void main() {
  test('dernier segment d\'un sous-dossier', () {
    expect(
      androidTreeName(
          'content://com.android.externalstorage.documents/tree/primary%3AMusic%2Fsid'),
      'sid',
    );
  });

  test('dossier à la racine du volume', () {
    expect(
      androidTreeName(
          'content://com.android.externalstorage.documents/tree/primary%3AMusic'),
      'Music',
    );
  });

  test('espaces et accents décodés', () {
    expect(
      androidTreeName(
          'content://com.android.externalstorage.documents/tree/primary%3AMusique%2FAmiga%20mod%C3%A8les'),
      'Amiga modèles',
    );
  });

  test('carte SD: le volume n\'est pas « primary »', () {
    expect(
      androidTreeName(
          'content://com.android.externalstorage.documents/tree/1B0C-2E1F%3Achiptunes'),
      'chiptunes',
    );
  });

  test('la RACINE d\'un volume n\'a pas de nom — repli, jamais vide', () {
    // Un nom vide ferait de la racine des imports la destination, et cet
    // import se mélangerait à tous les autres.
    expect(
      androidTreeName(
          'content://com.android.externalstorage.documents/tree/primary%3A'),
      'import',
    );
  });
}
