// Les rails se font glisser à la SOURIS (clic maintenu + déplacement
// horizontal), un clic simple sur une carte reste un clic, et un glissement ne
// déclenche pas le clic de la carte sur laquelle il a commencé.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/horizontal_scroll_arrows.dart';

Widget _rail({required void Function(int) onTap, bool wrap = true}) {
  Widget list(ScrollController c) => ListView.builder(
        controller: c,
        scrollDirection: Axis.horizontal,
        itemCount: 30,
        itemBuilder: (_, i) => SizedBox(
          width: 100,
          child: InkWell(onTap: () => onTap(i), child: Text('carte $i')),
        ),
      );
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 120,
        child: wrap
            ? HorizontalScrollArrows(builder: (_, c) => list(c))
            : Builder(builder: (_) => list(ScrollController())),
      ),
    ),
  );
}

ScrollPosition _pos(WidgetTester t) =>
    t.state<ScrollableState>(find.byType(Scrollable)).position;

Future<void> _mouseDrag(WidgetTester t, Offset from, Offset by) async {
  final g = await t.startGesture(from, kind: PointerDeviceKind.mouse);
  for (var i = 1; i <= 10; i++) {
    await g.moveBy(by / 10);
    await t.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await t.pumpAndSettle();
}

void main() {
  testWidgets('un glissement à la souris fait défiler le rail', (t) async {
    final taps = <int>[];
    await t.pumpWidget(_rail(onTap: taps.add));
    expect(_pos(t).pixels, 0);
    await _mouseDrag(t, t.getCenter(find.text('carte 2')), const Offset(-300, 0));
    expect(_pos(t).pixels, greaterThan(250));
    // Le glissement a commencé SUR une carte: elle ne doit pas s'ouvrir.
    expect(taps, isEmpty);
  });

  testWidgets('un clic simple à la souris reste un clic', (t) async {
    final taps = <int>[];
    await t.pumpWidget(_rail(onTap: taps.add));
    await t.tap(find.text('carte 1'), kind: PointerDeviceKind.mouse);
    await t.pumpAndSettle();
    expect(taps, [1]);
    expect(_pos(t).pixels, 0);
  });

  testWidgets('témoin: sans l\'enveloppe, la souris ne fait PAS défiler',
      (t) async {
    await t.pumpWidget(_rail(onTap: (_) {}, wrap: false));
    await _mouseDrag(t, t.getCenter(find.text('carte 2')), const Offset(-300, 0));
    expect(_pos(t).pixels, 0);
  });
}
