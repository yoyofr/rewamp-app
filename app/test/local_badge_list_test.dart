// La pastille « local » manquait aux dispositions en LISTE: la grille la
// posait (accueil, albums, « Ajoutés récemment »), la liste non — le même
// morceau était donc marqué en grille et nu en liste, à un bouton d'écart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_badge.dart';

Future<void> _pump(WidgetTester t, {required bool show}) => t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LocalBadgedArtwork(
              show: show,
              child: const ColoredBox(color: Colors.teal),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('une vignette locale porte la pastille', (t) async {
    await _pump(t, show: true);
    expect(find.byType(LocalBadge), findsOneWidget);
  });

  testWidgets('une vignette de catalogue n\'en porte pas', (t) async {
    await _pump(t, show: false);
    expect(find.byType(LocalBadge), findsNothing);
  });

  testWidgets('la vignette garde sa taille, pastille ou pas', (t) async {
    // La pastille est en SURIMPRESSION: elle ne doit pas pousser la ligne.
    for (final show in const [true, false]) {
      await _pump(t, show: show);
      expect(t.getSize(find.byType(LocalBadgedArtwork)), const Size(40, 40),
          reason: 'show=$show');
    }
  });
}
