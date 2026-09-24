// Ranger ses imports: un CHEMIN est une identité, et la déplacer se paie.
//
// Quatre porteurs de chemin doivent bouger ensemble (tracks, playlist_tracks,
// recent_albums, library_items), dans DEUX graphies (`{sandbox}/…` et absolue)
// — n'en traiter qu'une laissait la moitié des entrées de playlist pointer
// dans le vide. Ce fichier épingle les règles PURES; la réécriture SQL est
// exercée par local_manage_db_test.

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_manage.dart';

void main() {
  group('nom valide', () {
    test('un nom ordinaire passe, accents et parenthèses compris', () {
      expect(isValidLocalName('Day of the Tentacle (MT-32)'), isTrue);
      expect(isValidLocalName('Rêves d\'été'), isTrue);
    });

    test('ce qui ferait SORTIR de l\'arbre est refusé', () {
      expect(isValidLocalName('..'), isFalse);
      expect(isValidLocalName('.'), isFalse);
      expect(isValidLocalName('a/b'), isFalse);
      expect(isValidLocalName(r'a\b'), isFalse);
      expect(isValidLocalName('   '), isFalse);
      expect(isValidLocalName(''), isFalse);
    });

    test('on s\'aligne sur le système le plus STRICT', () {
      // Un import peut voyager par une sauvegarde: ce que Windows refuse ne
      // doit pas entrer ici, même si macOS l'accepte.
      for (final n in ['a:b', 'a*b', 'a?b', 'a"b', 'a<b', 'a>b', 'a|b']) {
        expect(isValidLocalName(n), isFalse, reason: n);
      }
    });
  });

  group('un dossier ne rentre pas dans lui-même', () {
    test('dans lui-même', () {
      expect(movesIntoItself('/l/Jeux', '/l/Jeux'), isTrue);
    });
    test('dans un descendant', () {
      expect(movesIntoItself('/l/Jeux', '/l/Jeux/MT-32'), isTrue);
    });
    test('ailleurs, c\'est permis', () {
      expect(movesIntoItself('/l/Jeux', '/l/Archives/Jeux'), isFalse);
      // ⚠️ Un préfixe de NOM n'est pas un préfixe de CHEMIN.
      expect(movesIntoItself('/l/Jeux', '/l/Jeux2'), isFalse);
    });
  });

  group('nom libre', () {
    test('libre: on garde le nom demandé', () {
      expect(freeName('/l/a.mid', (_) => false), '/l/a.mid');
    });

    test('pris: on suffixe AVANT l\'extension', () {
      // « a (2).mid », jamais « a.mid (2) » — l'extension doit rester la
      // dernière chose du nom, sinon le fichier n'est plus routable.
      final taken = {'/l/a.mid'};
      expect(freeName('/l/a.mid', taken.contains), '/l/a (2).mid');
    });

    test('on monte jusqu\'au premier libre', () {
      final taken = {'/l/a.mid', '/l/a (2).mid', '/l/a (3).mid'};
      expect(freeName('/l/a.mid', taken.contains), '/l/a (4).mid');
    });

    test('un DOSSIER n\'a pas d\'extension à préserver', () {
      final taken = {'/l/Jeux'};
      expect(freeName('/l/Jeux', taken.contains), '/l/Jeux (2)');
    });
  });
}
