// La piste en cours doit se retrouver du coin de l'œil dans une file longue.
// Elle n'avait que du gras et une couleur de texte — aucun fond.
//
// Le test porte sur la RÈGLE, pas sur une valeur: en thème sombre la ligne
// s'ÉCLAIRE, en thème clair elle s'ASSOMBRIT — dans les deux cas elle s'éloigne
// du fond. Et la teinte de la piste en cours doit rester DISTINCTE de celle de
// la sélection: les deux états coexistent sur une même ligne (la piste en cours
// peut être cochée en mode édition), deux fonds identiques ne diraient plus
// lequel est lequel.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/player_screen.dart';
import 'package:rewamp/player_controller.dart';
import 'package:rewamp/l10n/app_localizations.dart';

QueueEntry _entry(int i) =>
    QueueEntry(id: i, title: 'Track $i', artist: 'Artist');

Widget _host(Brightness b) => MaterialApp(
      theme: ThemeData(brightness: b),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: QueuePanel(
          cs: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: b),
          queue: [for (var i = 0; i < 4; i++) _entry(i)],
          currentIdx: 1,
          onTap: (_) {},
        ),
      ),
    );

/// Le `tileColor` de la n-ième ligne, ou null.
Color? _tileColorAt(WidgetTester t, int index) {
  final tiles = t.widgetList<ListTile>(find.byType(ListTile)).toList();
  return tiles[index].tileColor;
}

void main() {
  testWidgets('la ligne en cours porte un fond, les autres non', (t) async {
    await t.pumpWidget(_host(Brightness.dark));
    await t.pump();
    expect(_tileColorAt(t, 1), isNotNull, reason: 'la piste en cours');
    expect(_tileColorAt(t, 0), isNull);
    expect(_tileColorAt(t, 2), isNull);
  });

  testWidgets('sombre: on ÉCLAIRE', (t) async {
    await t.pumpWidget(_host(Brightness.dark));
    await t.pump();
    final dark = _tileColorAt(t, 1)!;
    expect(dark.computeLuminance(), greaterThan(0.5));
  });

  testWidgets('clair: on ASSOMBRIT', (t) async {
    await t.pumpWidget(_host(Brightness.light));
    await t.pump();
    final light = _tileColorAt(t, 1)!;
    expect(light.computeLuminance(), lessThan(0.5));
  });

  // ⚠️ `pumpAndSettle` et non `pump`: re-pomper un MaterialApp du MÊME type
  // dans un seul test réutilise les éléments, et la ligne rendait encore la
  // teinte du thème précédent — un `pump` unique donnait deux fois la valeur
  // SOMBRE et faisait passer un test qui ne mesurait rien. Les deux cas sont
  // aussi vérifiés séparément ci-dessus, où le piège n'existe pas.
  testWidgets('les deux teintes diffèrent', (t) async {
    await t.pumpWidget(_host(Brightness.dark));
    await t.pump();
    final dark = _tileColorAt(t, 1)!;
    await t.pumpWidget(_host(Brightness.light));
    await t.pumpAndSettle();
    final light = _tileColorAt(t, 1)!;

    // Un voile blanc en sombre, noir en clair: la comparaison porte sur la
    // luminance de la teinte, pas sur une valeur d'alpha choisie à la main.
    expect(dark.computeLuminance(), greaterThan(light.computeLuminance()));
    expect(dark.a, greaterThan(0));
    expect(light.a, greaterThan(0));
  });

  testWidgets('le fond « en cours » n\'est pas celui de la SÉLECTION',
      (t) async {
    await t.pumpWidget(_host(Brightness.dark));
    await t.pump();
    final tile = t
        .widgetList<ListTile>(find.byType(ListTile))
        .toList()[1];
    expect(tile.tileColor, isNot(tile.selectedTileColor));
  });
}
