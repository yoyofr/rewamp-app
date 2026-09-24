import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewamp/cancel_field.dart';

/// Le contrat de la croix d'annulation: sur mobile elle sort dès que le champ
/// a le focus — MÊME VIDE, c'est tout l'intérêt — et l'appuyer efface la
/// saisie et referme le clavier.
void main() {
  // L'override DOIT être remis à null AVANT la fin du corps du test: le
  // harnais vérifie les variables de debug juste après, et un `tearDown`
  // passe trop tard.
  void on(TargetPlatform p) => debugDefaultTargetPlatformOverride = p;
  void off() => debugDefaultTargetPlatformOverride = null;

  Widget host(TextEditingController ctrl) => MaterialApp(
        home: Scaffold(
          body: CancelField(
            controller: ctrl,
            builder: (_) => TextField(controller: ctrl),
          ),
        ),
      );

  group('mobile', () {
    testWidgets('rien tant que le champ n\'a pas le focus', (t) async {
      on(TargetPlatform.iOS);
      await t.pumpWidget(host(TextEditingController()));
      expect(find.byIcon(Icons.clear), findsNothing);
      off();
    });

    testWidgets('la croix sort au focus, champ VIDE', (t) async {
      on(TargetPlatform.iOS);
      await t.pumpWidget(host(TextEditingController()));
      await t.tap(find.byType(TextField));
      await t.pump();
      expect(find.byIcon(Icons.clear), findsOneWidget);
      off();
    });

    // LE bug: posée dans le `suffixIcon`, la croix est DANS la zone de geste
    // du champ — l'appuyer referme le clavier puis le champ traite le même tap
    // et le rouvre aussitôt. Elle doit donc être un VOISIN, pas un descendant.
    testWidgets('la croix n\'est PAS dans le champ', (t) async {
      on(TargetPlatform.iOS);
      await t.pumpWidget(host(TextEditingController()));
      await t.tap(find.byType(TextField));
      await t.pump();
      expect(find.byIcon(Icons.clear), findsOneWidget);
      expect(
        find.descendant(
            of: find.byType(TextField), matching: find.byIcon(Icons.clear)),
        findsNothing,
      );
      off();
    });

    testWidgets('champ VIDE: annuler referme le clavier et n\'y revient pas',
        (t) async {
      on(TargetPlatform.iOS);
      final ctrl = TextEditingController();
      await t.pumpWidget(host(ctrl));
      await t.tap(find.byType(TextField));
      await t.pump();
      await t.tap(find.byIcon(Icons.clear));
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.clear), findsNothing,
          reason: 'le champ ne doit pas avoir repris le focus');
      off();
    });

    testWidgets('annuler efface le texte et rend le focus', (t) async {
      on(TargetPlatform.iOS);
      final ctrl = TextEditingController();
      await t.pumpWidget(host(ctrl));
      await t.enterText(find.byType(TextField), 'coucou');
      await t.pump();
      expect(ctrl.text, 'coucou');

      await t.tap(find.byIcon(Icons.clear));
      await t.pump();
      expect(ctrl.text, isEmpty);
      // Clavier refermé = plus personne n'a le focus, donc plus de croix.
      expect(find.byIcon(Icons.clear), findsNothing);
      off();
    });

    testWidgets('onCleared n\'est prévenu que s\'il y avait du texte',
        (t) async {
          on(TargetPlatform.iOS);
      final calls = <String>[];
      final ctrl = TextEditingController();
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CancelField(
            controller: ctrl,
            onCleared: calls.add,
            builder: (_) => TextField(controller: ctrl),
          ),
        ),
      ));
      await t.tap(find.byType(TextField));
      await t.pump();
      await t.tap(find.byIcon(Icons.clear));
      await t.pump();
      expect(calls, isEmpty, reason: 'champ vide: rien à relancer');

      await t.enterText(find.byType(TextField), 'x');
      await t.pump();
      await t.tap(find.byIcon(Icons.clear));
      await t.pump();
      expect(calls, ['']);
      off();
    });
  });

  group('bureau', () {
    testWidgets('pas de croix sur un champ vide qui a le focus', (t) async {
      on(TargetPlatform.macOS);
      await t.pumpWidget(host(TextEditingController()));
      await t.tap(find.byType(TextField));
      await t.pump();
      expect(find.byIcon(Icons.clear), findsNothing);
      off();
    });

    testWidgets('mais la croix d\'effacement reste quand il y a du texte',
        (t) async {
          on(TargetPlatform.macOS);
      final ctrl = TextEditingController();
      await t.pumpWidget(host(ctrl));
      await t.enterText(find.byType(TextField), 'abc');
      await t.pump();
      expect(find.byIcon(Icons.clear), findsOneWidget);
      off();
    });
  });
}
