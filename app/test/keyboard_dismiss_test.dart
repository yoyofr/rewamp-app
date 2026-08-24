// Le clavier virtuel se ferme dès qu'un doigt se pose HORS du champ édité.
//
// Ce qui se teste sans IME réel: la perte (et la conservation) du FOCUS, dont
// la visibilité du clavier découle. Le widget est gardé par
// `viewInsets.bottom > 0` — le clavier est simulé par un MediaQuery, comme le
// ferait la fenêtre quand l'IME est à l'écran.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/keyboard_dismiss.dart';

// L'inset du clavier se simule au niveau de la VUE (comme le ferait l'IME):
// le garde du widget lit le MediaQuery au-dessus du Navigator, celui que
// MaterialApp fabrique depuis la fenêtre — un MediaQuery posé sous `home`
// serait invisible pour lui (c'est le piège que ce test a payé).
Widget _host() => MaterialApp(
      builder: (context, child) =>
          KeyboardDismissOnTapOutside(child: child ?? const SizedBox.shrink()),
      home: Scaffold(
        body: Column(children: [
          const TextField(key: Key('field')),
          const SizedBox(height: 40),
          ElevatedButton(
              key: const Key('btn'), onPressed: () {}, child: const Text('go')),
          const Expanded(child: SizedBox.expand()),
        ]),
      ),
    );

extension on WidgetTester {
  bool get fieldHasFocus =>
      FocusManager.instance.primaryFocus?.hasFocus == true &&
      state<EditableTextState>(find.byType(EditableText))
          .widget.focusNode.hasFocus;
}

void main() {
  testWidgets('tap hors du champ = focus perdu', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host());
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    expect(tester.fieldHasFocus, isTrue);

    await tester.tapAt(const Offset(200, 400));   // le vide sous le bouton
    await tester.pump();
    expect(tester.fieldHasFocus, isFalse);
  });

  testWidgets('tap sur un BOUTON aussi — c\'est le cas qui compte', (tester) async {
    // Un GestureDetector racine aurait perdu l'arène contre le bouton et
    // laissé le clavier ouvert; le Listener voit le pointeur avant l'arène.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host());
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('btn')));
    await tester.pump();
    expect(tester.fieldHasFocus, isFalse);
  });

  testWidgets('tap DANS le champ = focus conservé (pas de clignotement)',
      (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host());
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('field')));   // repositionner le curseur
    await tester.pump();
    expect(tester.fieldHasFocus, isTrue);
  });

  testWidgets('clavier absent (inset 0) = inerte', (tester) async {
    // Desktop / clavier physique: le framework gère déjà le clic-dehors,
    // on ne double pas son comportement.
    await tester.pumpWidget(_host());   // pas d'inset posé = pas de clavier
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();

    await tester.tapAt(const Offset(200, 400));
    await tester.pump();
    expect(tester.fieldHasFocus, isTrue);
  });
}
