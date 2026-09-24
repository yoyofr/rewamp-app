import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

/// `?subsong=N` porte le numéro que le MOTEUR joue. Pour SNDH et sc68 c'est le
/// numéro natif, 1-based, et 0 y veut dire « le défaut du fichier » — un
/// dépliage en 0..n-1 décalait tout d'un cran et perdait le dernier morceau.
void main() {
  test('un SNDH déplié sans sonde compte à partir de 1', () {
    expect(RewampDb.genericSubsongIndices('sndh', 3), [1, 2, 3]);
    expect(RewampDb.genericSubsongIndices('SNDH', 2), [1, 2]);
    expect(RewampDb.genericSubsongIndices('sc68', 2), [1, 2]);
  });

  test('le dernier morceau est atteint, et 0 (« défaut ») n\'est jamais émis',
      () {
    final idx = RewampDb.genericSubsongIndices('sndh', 20);
    expect(idx.last, 20);
    expect(idx, isNot(contains(0)));
  });

  test('les autres formats restent en 0..n-1', () {
    expect(RewampDb.genericSubsongIndices('sid', 3), [0, 1, 2]);
    expect(RewampDb.genericSubsongIndices('nsf', 2), [0, 1]);
  });
}
