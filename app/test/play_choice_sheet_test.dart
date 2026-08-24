import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/l10n/app_localizations.dart';
import 'package:rewamp/track_options_sheet.dart';

/// Le contrat sur lequel s'appuie l'ouverture de fichiers déposés
/// (AppShell._openLocalPaths): la feuille ne s'affiche QUE s'il y a quelque
/// chose à protéger, et un rejet ne vaut pas « à la fin ».
void main() {
  tearDown(() => globalQueueHasContent = null);

  Future<PlayChoice?> run(WidgetTester tester) async {
    PlayChoice? got;
    var settled = false;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                got = await showPlayChoiceSheet(context, title: 'Dropped');
                settled = true;
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    if (settled) return got;
    return null; // la feuille est encore là — l'appelant décide de la suite
  }

  testWidgets('file vide et rien en lecture: pas de feuille, « maintenant »',
      (tester) async {
    // Sur une app fraîchement lancée, un dépôt ne doit rien demander: tous les
    // choix se valent, il n'y a ni file ni morceau à préserver.
    globalQueueHasContent = () => false;
    PlayChoice? got;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async =>
                  got = await showPlayChoiceSheet(context, title: 'Dropped'),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(got, PlayChoice.now);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('file non vide: les trois choix, et le titre du dépôt',
      (tester) async {
    globalQueueHasContent = () => true;
    await run(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Dropped'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    // Pas de tuile de navigation sans openLabel: un dépôt n'a pas d'écran de
    // détail où aller.
    expect(find.byIcon(Icons.album_outlined), findsNothing);
  });

  testWidgets('écarter la feuille rend null, jamais un choix par défaut',
      (tester) async {
    globalQueueHasContent = () => true;
    PlayChoice? got;
    var done = false;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                got = await showPlayChoiceSheet(context, title: 'Dropped');
                done = true;
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    // Tap sur la barrière modale (hors de la feuille).
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(got, isNull);
  });
}
