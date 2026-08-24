// Pourquoi les listes longues des Réglages n'utilisent pas un DropdownButton.
//
// Constaté sur le choix du motif de transition projectM (23 entrées): « je
// n'arrive pas à cliquer sur la première entrée… en fait seule la moitié
// inférieure de la cellule répond ». Sortir la première entrée du menu n'a fait
// que déplacer le symptôme sur celle qui prenait sa place — le défaut est
// attaché à la POSITION, pas à la valeur.
//
// Ce test mesure le comportement de Flutter lui-même: dès qu'un menu déroulant
// Material devient SCROLLABLE, le haut de sa première cellule n'est plus
// réceptif (le `kMaterialListPadding` du ListView interne y mange ~8 px, et un
// tap qui y atterrit va à la liste, pas à l'entrée). Si un jour Flutter le
// corrige, ce test tombera: la règle « pas de DropdownButton pour une liste
// longue » pourra alors être revue.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ouvre un menu de [count] entrées et tape la cellule [target] à [frac] de sa
/// hauteur. Rend la valeur reçue, ou null si le tap n'a rien déclenché.
Future<int?> tapCell(WidgetTester t, int count, int target, double frac) async {
  int? got;
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: DropdownButton<int>(
          value: 5,
          items: [
            for (var i = 0; i < count; i++)
              DropdownMenuItem(value: i, child: Text('motif $i')),
          ],
          onChanged: (v) => got = v,
        ),
      ),
    ),
  ));
  await t.tap(find.text('motif 5').last);
  await t.pumpAndSettle();
  final r = t.getRect(find.text('motif $target').last);
  await t.tapAt(Offset(r.center.dx, r.center.dy - 24 + 48 * frac));
  await t.pumpAndSettle();
  return got;
}

void main() {
  testWidgets('menu SCROLLABLE: le haut de la 1re cellule est mort', (t) async {
    expect(await tapCell(t, 23, 0, 0.15), isNull,
        reason: 'si ce tap passe, Flutter a corrigé la bande morte');
    expect(await tapCell(t, 23, 0, 0.65), 0);
  });

  testWidgets('le défaut tient à la POSITION, pas à la valeur', (t) async {
    // Une cellule du milieu répond sur toute sa hauteur: ce n'est donc pas
    // l'entrée choisie qui est en cause, et masquer la première ne règle rien.
    expect(await tapCell(t, 23, 4, 0.15), 4);
    expect(await tapCell(t, 23, 4, 0.85), 4);
  });

  testWidgets('menu court: aucune bande morte', (t) async {
    // La borne du problème: tant que le menu tient à l'écran, tout répond.
    expect(await tapCell(t, 6, 0, 0.15), 0);
    expect(await tapCell(t, 6, 0, 0.85), 0);
  });
}
