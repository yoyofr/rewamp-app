import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/home_sections.dart';

/// L'ordre des sections de l'accueil est un réglage: ce qui est persisté n'est
/// que le CHOIX, et la réconciliation avec les sections que le binaire connaît
/// est ce qui empêche une préférence d'hier de casser l'accueil d'aujourd'hui.
void main() {
  test('rien de persisté = ordre livré', () {
    expect(normalizeHomeSections(const []), kHomeSectionsDefault);
  });

  test('le choix de l’utilisateur est respecté', () {
    final order = normalizeHomeSections(
        [for (final s in kHomeSectionsDefault.reversed) s.id]);
    expect(order, kHomeSectionsDefault.reversed.toList());
  });

  test('un id inconnu est jeté, pas rendu', () {
    final order = normalizeHomeSections(
        ['sections_du_futur', ...kHomeSectionsDefault.map((s) => s.id)]);
    expect(order, kHomeSectionsDefault);
  });

  test('un doublon ne duplique pas la section', () {
    final order = normalizeHomeSections(
        [HomeSection.featured.id, HomeSection.featured.id]);
    expect(order.where((s) => s == HomeSection.featured).length, 1);
    expect(order.toSet(), HomeSection.values.toSet());
  });

  // La règle qui compte: une section AJOUTÉE par une mise à jour revient à sa
  // place PAR DÉFAUT et non à la fin — sinon elle apparaîtrait tout en bas
  // chez tous ceux qui ont déjà rangé leur accueil, là où personne ne la voit.
  test('une section absente revient à sa place par défaut', () {
    final stored = [
      for (final s in kHomeSectionsDefault)
        if (s != HomeSection.yourTrends) s.id
    ];
    final order = normalizeHomeSections(stored);
    expect(order, kHomeSectionsDefault);
    expect(order.indexOf(HomeSection.yourTrends),
        kHomeSectionsDefault.indexOf(HomeSection.yourTrends));
  });

  test('absente ET liste réordonnée: elle se pose devant sa suivante', () {
    // L'utilisateur a mis « Top de tous les temps » en tête; « Vos tendances »
    // est neuve. Elle doit précéder « Votre top all-time », sa suivante
    // d'origine — pas se coller à la section remontée.
    final order = normalizeHomeSections([
      HomeSection.allTimeTop.id,
      HomeSection.recents.id,
      HomeSection.yourAllTimeTop.id,
    ]);
    expect(order.indexOf(HomeSection.yourTrends) <
        order.indexOf(HomeSection.yourAllTimeTop), isTrue);
    expect(order.first, HomeSection.allTimeTop);
    expect(order.toSet(), HomeSection.values.toSet());
  });

  // `local_files` a existé puis a été retiré (l'onglet Local l'a remplacé):
  // une préférence d'hier qui le nomme encore est jetée sans trou ni plantage.
  test('l’id d’une section RETIRÉE est jeté', () {
    final order = normalizeHomeSections(
        ['local_files', ...kHomeSectionsDefault.map((s) => s.id)]);
    expect(order, kHomeSectionsDefault);
  });

  test('chaque section a un id STABLE et unique', () {
    final ids = [for (final s in HomeSection.values) s.id];
    expect(ids.toSet().length, ids.length);
    // Les ids sont persistés: les renommer invaliderait les préférences déjà
    // écrites. Ce test EST le contrat.
    expect(ids, [
      'recents', 'featured', 'your_trends', 'your_all_time_top',
      'trending', 'all_time_top',
    ]);
  });
}
