// La réécriture des chemins d'un fichier JSON persisté (queue_state.json).
//
// C'est le CINQUIÈME porteur de chemin, découvert à la première exécution
// réelle de la migration Documents/Rewamp: la base était juste, la file
// persistée non — elle désignait encore 86 chemins sous l'ancienne racine.
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/storage_roots.dart';

void main() {
  const from = '/home/u/Documents/online';
  const to = '/home/u/Documents/Rewamp/online';

  (Object?, int) rw(Object? v) =>
      rewritePathsInJsonValue(v, from, to, separator: '/');

  test('un chemin SOUS la racine est réécrit', () {
    final (out, n) = rw('$from/jw_psf/uuid/a.psf');
    expect(out, '$to/jw_psf/uuid/a.psf');
    expect(n, 1);
  });

  test('la racine elle-même est réécrite', () {
    final (out, n) = rw(from);
    expect(out, to);
    expect(n, 1);
  });

  test('un préfixe de NOM n\'est pas un préfixe de CHEMIN', () {
    // `online2` commence par `online`: sans la règle « racine + séparateur »
    // on l'aurait pris pour un enfant.
    final (out, n) = rw('/home/u/Documents/online2/x.ogg');
    expect(out, '/home/u/Documents/online2/x.ogg');
    expect(n, 0);
  });

  test('la forme réelle de la file: listes et objets imbriqués', () {
    final queue = {
      'index': 1,
      'items': [
        {'path': '$from/a/1.ogg', 'title': 'Hope', 'seq': 0},
        {'path': '$from/a/2.psf', 'title': 'Cold Darkness', 'seq': 1},
        {'path': '/elsewhere/3.mod', 'title': 'x', 'seq': 2},
      ],
    };
    final (out, n) = rw(queue);
    final items = (out as Map)['items'] as List;
    expect(items[0]['path'], '$to/a/1.ogg');
    expect(items[1]['path'], '$to/a/2.psf');
    expect(items[2]['path'], '/elsewhere/3.mod', reason: 'hors racine: intact');
    expect(items[0]['title'], 'Hope', reason: 'une chaîne qui n\'est pas un chemin');
    expect(out['index'], 1, reason: 'les non-chaînes passent telles quelles');
    expect(n, 2);
  });

  test('rien à réécrire: compte nul', () {
    final (_, n) = rw({'items': <Object>[], 'index': 0});
    expect(n, 0);
  });
}
