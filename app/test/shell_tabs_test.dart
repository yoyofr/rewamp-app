import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/shell_tabs.dart';

/// Les onglets: ordre persistable, barre à quatre places, « Plus » pour le
/// reste. Ce qui est testé ici est le CONTRAT, pas la mise en page.
void main() {
  test('les ids sont stables et uniques', () {
    final ids = [for (final t in ShellTab.values) t.id];
    expect(ids.toSet().length, ids.length);
    // Persistés: les renommer invaliderait les préférences déjà écrites.
    expect(ids, [
      'home', 'search', 'local', 'library', 'stats', 'settings', 'about',
    ]);
  });

  // L'index de l'enum EST l'index d'écran dans app_shell: y insérer une valeur
  // déplace un écran. Le test rend le déplacement VISIBLE.
  test('l’ordre de l’enum est celui des écrans (et du rail)', () {
    expect(ShellTab.home.index, 0);
    expect(ShellTab.search.index, 1);
    expect(ShellTab.local.index, 2);   // sous « Recherche », comme au rail
    expect(ShellTab.library.index, 3);
    expect(kShellTabsDefault, ShellTab.values);
  });

  test('rien de persisté = ordre livré du téléphone', () {
    expect(normalizeShellTabs(const []), kPhoneTabsDefault);
  });

  // La demande explicite: sur téléphone, « Local » commence dans le « … ».
  test('sur téléphone, Local est sous « Plus » par défaut', () {
    final (bar, overflow) = splitPhoneTabs(kPhoneTabsDefault);
    expect(bar.length, kPhoneBarSlots);
    expect(bar.contains(ShellTab.local), isFalse);
    expect(overflow.first, ShellTab.local);
  });

  test('le choix de l’utilisateur est respecté', () {
    final order = normalizeShellTabs([ShellTab.local.id, ShellTab.home.id]);
    expect(order.first, ShellTab.local);
    expect(order[1], ShellTab.home);
    expect(order.toSet(), ShellTab.values.toSet());
  });

  test('un id inconnu est jeté', () {
    final order = normalizeShellTabs(
        ['onglet_du_futur', ...kPhoneTabsDefault.map((t) => t.id)]);
    expect(order, kPhoneTabsDefault);
  });

  // Un onglet AJOUTÉ par une mise à jour revient à sa place par défaut, et pas
  // à la fin: sinon il n'apparaîtrait que sous « Plus », chez tous ceux qui ont
  // déjà rangé leur barre.
  test('un onglet absent revient près de sa devancière', () {
    final stored = [
      for (final t in kPhoneTabsDefault)
        if (t != ShellTab.library) t.id
    ];
    final order = normalizeShellTabs(stored);
    expect(order, kPhoneTabsDefault);
  });

  test('absent ET barre réordonnée: il suit sa devancière, pas sa suivante',
      () {
    // L'utilisateur a mis Stats en tête; « Bibliothèque » est neuve. Elle doit
    // suivre « Recherche », sa devancière d'origine — et surtout pas se coller
    // devant Stats, désormais en première place.
    final order = normalizeShellTabs([
      ShellTab.stats.id, ShellTab.home.id, ShellTab.search.id,
      ShellTab.local.id, ShellTab.settings.id, ShellTab.about.id,
    ]);
    expect(order.first, ShellTab.stats);
    expect(order.indexOf(ShellTab.library),
        order.indexOf(ShellTab.search) + 1);
  });

  test('un doublon ne duplique pas l’onglet', () {
    final order =
        normalizeShellTabs([ShellTab.local.id, ShellTab.local.id]);
    expect(order.where((t) => t == ShellTab.local).length, 1);
    expect(order.toSet(), ShellTab.values.toSet());
  });

  // ⚠️ Un onglet s'adresse PAR SON NOM, jamais par un index littéral: l'index
  // est le rang dans l'enum, et insérer un onglet au milieu les décale tous.
  // C'est arrivé — « Local » ajouté en 3e position a fait pointer le raccourci
  // « Réglages » du menu « … » du lecteur sur STATS (4 était Réglages avant,
  // Stats après), sans rien signaler: ni erreur d'analyse, ni test rouge, juste
  // le mauvais écran. Le seul garde-fou possible est de rendre la FORME
  // impossible, donc on la cherche dans la source.
  test('aucun onglet n’est adressé par un index littéral', () {
    final shell = File('lib/app_shell.dart').readAsStringSync();
    final literals = RegExp(r'_onTabSelected\(\s*\d')
        .allMatches(shell)
        .map((m) => m.group(0))
        .toList();
    expect(literals, isEmpty,
        reason: 'utiliser ShellTab.<nom>.index, jamais un nombre');
  });
}
