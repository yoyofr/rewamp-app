// Une carte de rail doit contenir DEUX lignes de titre.
//
// Un nom de module tronqué ne dit plus rien — « mdat.monkey isl… » ne se
// distingue pas de son voisin — d'où le passage à deux lignes. Mais la hauteur
// de carte est une CONSTANTE (`_kRecentCardHeight`): ajouter une ligne sans la
// suivre fait déborder la colonne, et un débordement de quelques pixels ne se
// voit pas à l'œil sur un simulateur.
//
// Le test asserte donc la dimension DÉFAILLANTE (la hauteur occupée), pas la
// simple présence du texte: c'est la seule qui rougit quand la constante et le
// nombre de lignes divergent.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Mêmes valeurs que home_screen.dart (constantes privées là-bas).
const double kCardWidth  = 110.0;
const double kCardHeight = 175.0;

void main() {
  testWidgets('titre sur deux lignes + sous-titre tiennent dans la carte',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: kCardWidth,
            child: Column(
              key: key,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // La pochette est CARRÉE et large comme la carte.
                Container(width: kCardWidth, height: kCardWidth,
                    color: Colors.grey),
                const SizedBox(height: 5),
                Builder(builder: (ctx) {
                  final theme = Theme.of(ctx).textTheme;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'mdat.monkey island — un titre assez long pour replier',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Chris Huelsbeck',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    ));

    final h = tester.getSize(find.byKey(key)).height;
    expect(h, lessThanOrEqualTo(kCardHeight),
        reason: 'la carte fait $kCardHeight, le contenu en demande $h — '
            'ajuster _kRecentCardHeight dans home_screen.dart');
  });
}
