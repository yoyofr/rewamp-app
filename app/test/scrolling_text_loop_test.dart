// Le défilement d'un libellé trop long est une BOUCLE dans un seul sens, pas
// un aller-retour (décision du 2026-09-26): deux copies séparées d'un écart,
// on défile d'une longueur de texte plus l'écart, on saute à zéro — invisible,
// la seconde copie était là — et l'on marque la pause au DÉPART. Ces tests
// épinglent ce que l'aller-retour faisait autrement: l'offset ne REDESCEND
// jamais pendant le mouvement, et le texte est immobile au début du cycle.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/marquee_text.dart';
import 'package:rewamp/scrolling_text.dart';

const _long = 'titreABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 encore et encore';
const _short = 'court';

Widget _host(Widget child, {double width = 120}) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: width, child: child)),
      ),
    );

ScrollController _ctrlOf(WidgetTester t) =>
    t.widget<SingleChildScrollView>(find.byType(SingleChildScrollView)).controller!;

void main() {
  testWidgets('ScrollingText: un texte qui tient ne défile pas et n\'est rendu qu\'une fois',
      (tester) async {
    await tester.pumpWidget(_host(const ScrollingText(text: _short, pauseMs: 100)));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(_short), findsOneWidget);
    expect(_ctrlOf(tester).offset, 0);
  });

  testWidgets('ScrollingText: deux copies, un seul sens, retour à zéro puis pause',
      (tester) async {
    await tester.pumpWidget(_host(const ScrollingText(
        text: _long, pauseMs: 100, pixelsPerSecond: 400)));
    await tester.pump();
    // Une seule pour `find.text` (et pour un lecteur d'écran); deux à l'écran.
    expect(find.text(_long), findsOneWidget);
    expect(find.text(_long, findRichText: true), findsNWidgets(2),
        reason: 'la seconde copie prend le relais');

    final c = _ctrlOf(tester);
    // Pause au départ: immobile.
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.offset, 0);
    // Puis ça défile, et l'offset ne fait que MONTER jusqu'au saut.
    await tester.pump(const Duration(milliseconds: 100));
    var prev = c.offset;
    var climbed = false, jumped = false;
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      final o = c.offset;
      if (o > prev) climbed = true;
      // Une baisse n'est légitime QUE le saut à zéro — jamais une marche arrière.
      if (o < prev) { expect(o, 0, reason: 'seul retour permis: le saut à 0'); jumped = true; }
      prev = o;
    }
    expect(climbed, isTrue);
    expect(jumped, isTrue, reason: 'un cycle complet doit s\'être bouclé en 3,2 s');
  });

  testWidgets('MarqueeText vertical: bloc qui déborde ⇒ deux copies, boucle',
      (tester) async {
    await tester.pumpWidget(_host(
      const MarqueeText(_long, axis: Axis.vertical, maxLines: 2,
          pause: Duration(milliseconds: 100), velocity: 400),
      width: 80,
    ));
    await tester.pump();
    expect(find.text(_long), findsOneWidget);
    expect(find.text(_long, findRichText: true), findsNWidgets(2));
    final c = _ctrlOf(tester);
    await tester.pump(const Duration(milliseconds: 150));
    var prev = c.offset, climbed = false, jumped = false;
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      final o = c.offset;
      if (o > prev) climbed = true;
      if (o < prev) { expect(o, 0); jumped = true; }
      prev = o;
    }
    expect(climbed, isTrue);
    expect(jumped, isTrue);
  });

  testWidgets('MarqueeText vertical: bloc qui tient ⇒ une copie, immobile',
      (tester) async {
    await tester.pumpWidget(_host(
      const MarqueeText(_short, axis: Axis.vertical, maxLines: 2,
          pause: Duration(milliseconds: 100)),
      width: 200,
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(_short), findsOneWidget);
    expect(_ctrlOf(tester).offset, 0);
  });
}
