// Le remélange d'un nouveau TOUR de file (lecture aléatoire).
//
// Ce qui se teste ici est ce qui peut casser en silence: perdre ou dupliquer
// une entrée, et rouvrir le tour sur le morceau qu'on vient de finir — le seul
// endroit où un vrai hasard s'entend comme un bug.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/queue_shuffle.dart';

void main() {
  test('le tour suivant garde EXACTEMENT les mêmes entrées', () {
    final items = List<int>.generate(50, (i) => i);
    for (var seed = 0; seed < 20; seed++) {
      final out = reshuffledForNewPass(items, rng: Random(seed));
      expect(out.length, items.length);
      expect(out.toSet(), items.toSet());
    }
  });

  test('ne rouvre jamais sur le morceau qu\'on vient de finir', () {
    // Des objets distincts: la garde compare l'IDENTITÉ, pas la valeur — deux
    // entrées de file peuvent porter la même piste (une sous-chanson ajoutée
    // deux fois) et ce sont bien deux entrées.
    final items = [for (var i = 0; i < 8; i++) Object()];
    for (var seed = 0; seed < 200; seed++) {
      final out = reshuffledForNewPass(items,
          justPlayed: items[3], rng: Random(seed));
      expect(identical(out.first, items[3]), isFalse,
          reason: 'graine $seed: le tour rouvre sur la piste qui vient de finir');
      expect(out.toSet().length, items.length);
    }
  });

  test('une file d\'un seul élément est rendue telle quelle', () {
    final one = [Object()];
    final out = reshuffledForNewPass(one, justPlayed: one.first);
    expect(out.length, 1);
    expect(identical(out.first, one.first), isTrue);
    expect(reshuffledForNewPass(<Object>[]), isEmpty);
  });

  test('deux tours ne donnent pas le même ordre (le vrai symptôme)', () {
    // 30 entrées: deux permutations identiques par hasard sont improbables au
    // point qu'un échec ici veut dire « le mélange n'a pas eu lieu ».
    final items = List<int>.generate(30, (i) => i);
    final a = reshuffledForNewPass(items);
    final b = reshuffledForNewPass(items);
    expect(a, isNot(equals(b)));
  });
}
