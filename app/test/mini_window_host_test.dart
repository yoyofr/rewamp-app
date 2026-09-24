import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/mini_window.dart';
import 'package:rewamp/mini_window_player.dart';

/// Tient lieu de coquille: un ÉTAT (la file de lecture vit dans celui
/// d'AppShell) et la taille qu'il lit dans MediaQuery (AppShell y choisit sa
/// disposition bureau/téléphone).
class _Shell extends StatefulWidget {
  const _Shell();
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int taps = 0;
  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return GestureDetector(
      onTap: () => setState(() => taps++),
      child: ColoredBox(
        color: Colors.black,
        child: Text('taps=$taps mq=${s.width.toInt()}x${s.height.toInt()}',
            textDirection: TextDirection.ltr),
      ),
    );
  }
}

void main() {
  tearDown(() => MiniWindow.instance.debugSetMini(false));

  Widget host() => const MaterialApp(
        home: MiniWindowHost(
          mini: Text('MINI'),
          child: Builder(builder: _shell),
        ),
      );

  testWidgets('entrer puis sortir du mini lecteur garde l\'ÉTAT de la coquille',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byType(_Shell));
    await tester.pump();
    expect(find.textContaining('taps=1'), findsOneWidget);
    expect(find.text('MINI'), findsNothing);

    MiniWindow.instance.debugSetMini(true, frozenSize: const Size(1280, 720));
    await tester.pump();
    expect(find.text('MINI'), findsOneWidget);
    // Hors scène mais TOUJOURS montée.
    expect(find.byType(_Shell, skipOffstage: false), findsOneWidget);
    expect(find.byType(_Shell), findsNothing);

    MiniWindow.instance.debugSetMini(false);
    await tester.pump();
    expect(find.text('MINI'), findsNothing);
    // L'état a survécu: un étage inséré/retiré selon le mode l'aurait remis
    // à zéro (la coquille démontée, la file perdue).
    expect(find.textContaining('taps=1'), findsOneWidget);
  });

  testWidgets('hors scène, la coquille garde la taille de la fenêtre principale',
      (tester) async {
    // La fenêtre est déjà rétrécie à la taille du mini lecteur.
    tester.view.physicalSize = const Size(440, 132);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    MiniWindow.instance.debugSetMini(true, frozenSize: const Size(1280, 720));
    await tester.pump();

    // Ce que la coquille LIT (choix bureau/téléphone)…
    expect(find.textContaining('mq=1280x720', skipOffstage: false),
        findsOneWidget);
    // …et la contrainte qu'elle REÇOIT.
    expect(tester.getSize(find.byType(_Shell, skipOffstage: false)),
        const Size(1280, 720));
  });
}

Widget _shell(BuildContext context) => const _Shell();
