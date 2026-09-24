import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Durée inconnue (aucune longueur au catalogue ni dérivable du fichier): la
// barre reste VISIBLE, désactivée et à zéro. Un trou à sa place faisait
// paraître le lecteur cassé sur une piste qui joue très bien, et une barre
// active mentirait: on ne se déplace pas dans une durée qu'on ignore.
// Ce test vérifie la propriété Material dont dépend l'apparence grisée.
void main() {
  testWidgets('un Slider sans onChanged est désactivé et reste à 0',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SliderTheme(
          data: SliderThemeData(trackHeight: 3),
          child: Slider(value: 0, min: 0, max: 1, onChanged: null),
        ),
      ),
    ));
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.onChanged, isNull, reason: 'désactivé: aucun seek possible');
    expect(slider.value, 0);

    // Un glissement ne change rien (aucun rappel n'existe).
    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
  });
}
