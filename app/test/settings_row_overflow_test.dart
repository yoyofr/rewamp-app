// Un menu déroulant se dimensionne sur son item le PLUS LARGE et IGNORE la
// contrainte de largeur qu'on lui pose: sa Row interne déborde en silence
// jusqu'à ce qu'un `RenderFlex overflowed` tombe en debug.
//
// Vu sur Réglages → Moteurs → libvgm, où le nom d'un cœur porte son
// avertissement (« SameBoy (sans oscilloscope) »): « A RenderFlex overflowed by
// 16 pixels on the right », deux fois. Ce n'est PAS SettingRow qui manque une
// borne — il en pose bien une (60 % de la ligne) — c'est le DropdownButton qui
// passe outre tant qu'il n'est pas `isExpanded`.
//
// Les deux moitiés comptent: sans `isExpanded` l'item n'est pas flexible, et
// avec `isExpanded` mais sans `overflow: ellipsis` c'est le Text qui déborde.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/settings_screen.dart' show SettingRow;

const _long = [
  'SameBoy (sans oscilloscope)',
  'Gambatte (sans oscilloscope)',
  'DMG (par défaut)',
];

Future<void> _pump(WidgetTester t, Widget dropdown) async {
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 380,   // téléphone étroit: la ligne fait 380 - 32 de marges
        child: SettingRow(label: 'GameBoy', child: dropdown),
      ),
    ),
  ));
}

void main() {
  testWidgets('isExpanded + élision: aucun débordement', (t) async {
    await _pump(
      t,
      DropdownButton<int>(
        value: 0,
        isDense: true,
        isExpanded: true,
        items: [
          for (var i = 0; i < _long.length; i++)
            DropdownMenuItem(
                value: i, child: Text(_long[i], overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (_) {},
      ),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('sans isExpanded, la même ligne DÉBORDE', (t) async {
    // Le test du piège lui-même: si Flutter change d'avis un jour, il tombera
    // et la règle pourra être revue.
    await _pump(
      t,
      DropdownButton<int>(
        value: 0,
        isDense: true,
        items: [
          for (var i = 0; i < _long.length; i++)
            DropdownMenuItem(value: i, child: Text(_long[i])),
        ],
        onChanged: (_) {},
      ),
    );
    expect(t.takeException(), isA<FlutterError>());
  });
}
