// Une ligne de réglage ne doit JAMAIS déborder, quelle que soit la largeur.
//
// Le cas vécu: plusieurs contrôles sont des `SingleChildScrollView` horizontaux
// (un SegmentedButton de cinq segments ne tient pas sur un téléphone et ne
// scrolle pas seul), et une vue défilante prend TOUTE la contrainte qu'on lui
// donne. Le côté label n'avait plus que 8,4 px, où la pastille de
// réinitialisation (28 px minimum) débordait de 12 px.
//
// Le test ne vérifie aucune valeur de pixel: il vérifie qu'aucun débordement
// n'est signalé aux largeurs que l'app utilise vraiment — ce qu'une assertion
// de rendu dit à l'exécution et que rien ne dit à la relecture.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/l10n/app_localizations.dart';
import 'package:rewamp/settings_screen.dart';

/// Un contrôle GOURMAND: exactement ce que fait un SegmentedButton scrollable.
Widget _greedy() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('Segment libellé $i'),
          ),
      ]),
    );

Widget _host(double width, Widget control) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: SettingRow(
              label: 'Un libellé de réglage plutôt long, comme en allemand',
              child: control,
            ),
          ),
        ),
      ),
    );

void main() {
  // 259 px = le panneau de queue dans le lecteur d'un téléphone; 320 = un petit
  // téléphone; 600 = le seuil desktop; 1200 = une fenêtre large.
  for (final w in [200.0, 259.0, 320.0, 600.0, 1200.0]) {
    testWidgets('pas de débordement à ${w.toInt()} px (contrôle gourmand)',
        (t) async {
      await t.pumpWidget(_host(w, _greedy()));
      await t.pump();
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('un contrôle ÉTROIT garde sa taille naturelle', (t) async {
    // La borne ne doit pas étirer un interrupteur à 60 % de la ligne: on ne
    // corrige la famine que quand elle a lieu.
    const key = ValueKey('control');
    await t.pumpWidget(
        _host(600, const SizedBox(key: key, width: 52, height: 32)));
    await t.pump();
    expect(t.getSize(find.byKey(key)).width, 52);
    expect(t.takeException(), isNull);
  });
}
