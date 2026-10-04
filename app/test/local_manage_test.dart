// Ranger ses imports: un CHEMIN est une identité, et la déplacer se paie.
//
// Quatre porteurs de chemin doivent bouger ensemble (tracks, playlist_tracks,
// recent_albums, library_items), dans DEUX graphies (`{sandbox}/…` et absolue)
// — n'en traiter qu'une laissait la moitié des entrées de playlist pointer
// dans le vide. Ce fichier épingle les règles PURES; la réécriture SQL est
// exercée par local_manage_db_test.

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

  // Les règles de CHEMIN, sous les DEUX styles (p.posix / p.windows) sur
  // n'importe quelle machine: la CI Linux exerce Windows, et réciproquement.
  for (final c in [p.posix, p.windows]) {
    final style = c.style == p.Style.windows ? 'Windows' : 'POSIX';
    final l = c.style == p.Style.windows ? r'C:\l' : '/l';
    String at(List<String> parts) => c.joinAll([l, ...parts]);

    group('un dossier ne rentre pas dans lui-même ($style)', () {
      test('dans lui-même', () {
        expect(movesIntoItself(at(['Jeux']), at(['Jeux']), ctx: c), isTrue);
      });
      test('dans un descendant', () {
        expect(movesIntoItself(at(['Jeux']), at(['Jeux', 'MT-32']), ctx: c),
            isTrue);
      });
      test('ailleurs, c\'est permis', () {
        expect(movesIntoItself(at(['Jeux']), at(['Archives', 'Jeux']), ctx: c),
            isFalse);
        // ⚠️ Un préfixe de NOM n'est pas un préfixe de CHEMIN.
        expect(movesIntoItself(at(['Jeux']), at(['Jeux2']), ctx: c), isFalse);
      });
    });

    group('nom libre ($style)', () {
      test('libre: on garde le nom demandé', () {
        expect(freeName(at(['a.mid']), (_) => false, ctx: c), at(['a.mid']));
      });

      test('pris: on suffixe AVANT l\'extension', () {
        // « a (2).mid », jamais « a.mid (2) » — l'extension doit rester la
        // dernière chose du nom, sinon le fichier n'est plus routable.
        final taken = {at(['a.mid'])};
        expect(freeName(at(['a.mid']), taken.contains, ctx: c),
            at(['a (2).mid']));
      });

      test('on monte jusqu\'au premier libre', () {
        final taken = {at(['a.mid']), at(['a (2).mid']), at(['a (3).mid'])};
        expect(freeName(at(['a.mid']), taken.contains, ctx: c),
            at(['a (4).mid']));
      });

      test('un DOSSIER n\'a pas d\'extension à préserver', () {
        final taken = {at(['Jeux'])};
        expect(freeName(at(['Jeux']), taken.contains, ctx: c), at(['Jeux (2)']));
      });
    });
  }
}