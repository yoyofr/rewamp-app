import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/fullscreen_progress_line.dart';

/// The first version of this line rendered at ZERO WIDTH and nothing caught it:
/// `flutter analyze` was clean, the widget was built, and the only symptom was
/// "I do not see it". Its Stack's only unpositioned child was the fill, so the
/// Stack took the width of the FILL — about a pixel early in a track — and the
/// dark bed, laid out with Positioned.fill, faithfully matched that width.
/// Hence a test that asserts on GEOMETRY rather than on presence.
void main() {
  Future<void> pumpLine(WidgetTester tester,
      {required double position, required double duration}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 200,
            child: FullscreenProgressLine(
              position: position,
              duration: duration,
            ),
          ),
        ),
      ),
    ));
    // The tween settles over 230 ms; let it finish so the fill is at its target.
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
  }

  testWidgets('takes the full width of its parent, whatever the progress',
      (tester) async {
    for (final pos in <double>[0, 1, 50, 99, 100]) {
      await pumpLine(tester, position: pos, duration: 100);
      final size = tester.getSize(find.byType(FullscreenProgressLine));
      expect(size.width, 200,
          reason: 'la ligne doit occuper la largeur donnée, à $pos s');
      expect(size.height, 3);
    }
  });

  testWidgets('the fill is proportional to the position', (tester) async {
    await pumpLine(tester, position: 25, duration: 100);
    // Scoped to the widget: a Scaffold paints its own ColoredBox, and an
    // unscoped finder happily returned it (800 px wide) instead of the fill.
    final inLine = find.descendant(
      of: find.byType(FullscreenProgressLine),
      matching: find.byType(ColoredBox),
    );
    expect(tester.widgetList(inLine).length, 2, reason: 'un remplissage et un lit');
    expect(tester.getSize(inLine.first).width, closeTo(50, 0.5),
        reason: '25 % de 200 px');
    // LA HAUTEUR, et c'est elle qui manquait: un ColoredBox sans enfant prend
    // constraints.smallest, et un Row aligné au centre donne des contraintes de
    // hauteur LÂCHES - les deux moitiés se posaient donc à hauteur zéro. La
    // ligne réservait sa place et ne peignait rien, ce que trois tests de
    // largeur ont laissé passer.
    for (final box in <int>[0, 1]) {
      expect(tester.getSize(inLine.at(box)).height, 3,
          reason: 'les deux moitiés doivent remplir la hauteur');
    }
  });

  group('seek bar', _seekBarTests);
  group('libellés', _labelTests);
  group('raffinements', _refinementTests);

  testWidgets('a position past the duration does not overflow', (tester) async {
    await pumpLine(tester, position: 999, duration: 100);
    final inLine = find.descendant(
      of: find.byType(FullscreenProgressLine),
      matching: find.byType(ColoredBox),
    );
    expect(tester.getSize(inLine.first).width, closeTo(200, 0.5));
  });
}

/// The scrubbable version. What matters here is not that a callback fires but
/// WHERE it points, and that the visualizer underneath never sees the pointer.
void _seekBarTests() {
  Future<void> pump(WidgetTester tester,
      {required void Function(double) onSeek,
      void Function()? onBackgroundTap}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GestureDetector(
          // Stands in for the visualizer's own recognisers, which sit UNDER the
          // controls: an opaque hit area must keep them from ever firing.
          onTap: onBackgroundTap,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: FullscreenSeekBar(
              position: 10,
              duration: 100,
              width: 200,
              onSeek: onSeek,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a tap seeks to the fraction it lands on', (tester) async {
    final seeks = <double>[];
    await pump(tester, onSeek: seeks.add);
    // The rect of the LINE, not of the widget: the latter now includes the two
    // timestamps, so a fraction of it is not a fraction of the track.
    final box = tester.getRect(find.byType(FullscreenProgressLine));
    await tester.tapAt(Offset(box.left + box.width * 0.25, box.center.dy));
    await tester.pump();
    expect(seeks.single, closeTo(25, 0.5), reason: '25 % de 100 s');
  });

  testWidgets('a drag seeks ONCE, on release, at the finger', (tester) async {
    final seeks = <double>[];
    await pump(tester, onSeek: seeks.add);
    final box = tester.getRect(find.byType(FullscreenProgressLine));
    final gesture =
        await tester.startGesture(Offset(box.left + 10, box.center.dy));
    await gesture.moveTo(Offset(box.left + box.width * 0.75, box.center.dy));
    await tester.pump();
    expect(seeks, isEmpty, reason: 'un seek par frame de glissement coûterait cher');
    await gesture.up();
    await tester.pump();
    expect(seeks.single, closeTo(75, 0.5));
  });

  testWidgets('the pointer never reaches what is underneath', (tester) async {
    var background = 0;
    await pump(tester, onSeek: (_) {}, onBackgroundTap: () => background++);
    await tester.tap(find.byType(FullscreenSeekBar));
    await tester.pump();
    expect(background, 0);
  });

  testWidgets('no duration, no gesture: it stays a plain indicator',
      (tester) async {
    final seeks = <double>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: FullscreenSeekBar(
            position: 0,
            duration: 0,
            width: 200,
            onSeek: seeks.add,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FullscreenSeekBar));
    await tester.pump();
    expect(seeks, isEmpty);
  });
}

/// The timestamps around the bar. The left one must follow the FINGER while a
/// scrub is in progress, not the audio — that is the whole reason they live
/// inside the widget that owns the drag.
void _labelTests() {
  testWidgets('elapsed on the left, total on the right', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: FullscreenSeekBar(
            position: 65, duration: 185, width: 200, onSeek: _noSeek),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('1:05'), findsWidgets);
    expect(find.text('3:05'), findsWidgets);
  });

  testWidgets('an unknown length prints --:--', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: FullscreenSeekBar(
            position: 12, duration: 0, width: 200, onSeek: _noSeek),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('--:--'), findsWidgets);
  });

  testWidgets('the elapsed label follows the finger during a scrub',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: FullscreenSeekBar(
            position: 0, duration: 100, width: 200, onSeek: _noSeek),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final box = tester.getRect(find.byType(FullscreenProgressLine));
    // Le déplacement doit dépasser le seuil de reconnaissance (18 px), sans quoi
    // le glissement n'est jamais accepté et le libellé montre encore l'audio -
    // ce que la première version de ce test prenait pour un bug du widget.
    final gesture =
        await tester.startGesture(Offset(box.left + 10, box.center.dy));
    await gesture.moveTo(Offset(box.left + box.width * 0.5, box.center.dy));
    await tester.pump();
    expect(find.text('0:50'), findsWidgets,
        reason: 'le libellé suit le doigt, à la moitié de 100 s');
    expect(find.text('0:00'), findsNothing);
    await gesture.up();
  });
}

void _noSeek(double _) {}

/// The two refinements: the scrub bubble, and the "born on the bar" signal.
void _refinementTests() {
  testWidgets('a drag shows the time bubble, release hides it', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: FullscreenSeekBar(
              position: 0, duration: 100, width: 200, onSeek: _noSeek),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final box = tester.getRect(find.byType(FullscreenProgressLine));
    final gesture =
        await tester.startGesture(Offset(box.left + 10, box.center.dy));
    await gesture.moveTo(Offset(box.left + box.width * 0.5, box.center.dy));
    await tester.pump();
    // The bubble and the left label BOTH print the target: two matches.
    expect(find.text('0:50'), findsNWidgets(4),
        reason: 'bulle + libellé gauche, chacun en deux Text (contour+fond)');
    await gesture.up();
    await tester.pump();
    expect(find.text('0:50'), findsNothing);
  });

  testWidgets('every pointer landing on the bar fires onPointerDown',
      (tester) async {
    var downs = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: FullscreenSeekBar(
            position: 0,
            duration: 100,
            width: 200,
            onSeek: (_) {},
            onPointerDown: () => downs++,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // A tap AND a vertical gesture both count: the signal exists precisely for
    // gestures the bar's own recognisers will NOT claim.
    await tester.tap(find.byType(FullscreenProgressLine));
    final box = tester.getRect(find.byType(FullscreenProgressLine));
    final g = await tester.startGesture(box.center);
    await g.moveBy(const Offset(0, 40));
    await g.up();
    await tester.pump();
    expect(downs, 2);
  });
}
