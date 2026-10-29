// Réglages « quand entendre ce qu'on lance » (play_start.dart) et « au
// démarrage » (launch_window.dart): ce qui se décide sans moteur ni fenêtre.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/l10n/app_localizations.dart';
import 'package:rewamp/launch_window.dart';
import 'package:rewamp/play_start.dart';
import 'package:rewamp/track_options_sheet.dart';
import 'package:rewamp/user_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserSettings.init();
    globalQueueHasContent = () => true;
  });
  tearDown(() => globalQueueHasContent = null);

  test('défauts: demander dans l\'app, lire tout de suite depuis le système',
      () {
    final s = UserSettings.instance;
    expect(s.playStartInApp, PlayStartAction.ask);
    expect(s.playStartExternal, PlayStartAction.now);
    expect(PlayStartAction.fromName('martian', PlayStartAction.end),
        PlayStartAction.end);
    expect(playChoiceFor(PlayStartAction.ask), isNull);
    expect(playChoiceFor(PlayStartAction.next), PlayChoice.next);
  });

  Future<(PlayChoice?, bool)> tap(WidgetTester tester,
      {bool hold = false}) async {
    PlayChoice? got;
    var settled = false;
    Future<void> gesture(BuildContext context) async {
      got = await showPlayChoiceSheet(context, title: 'x');
      settled = true;
    }

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => hold
                  ? withPlayChoiceSheet(() => gesture(context))
                  : gesture(context),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return (got, settled);
  }

  testWidgets('réglage « ensuite »: pas de feuille, le choix est fait',
      (tester) async {
    UserSettings.instance.playStartInApp = PlayStartAction.next;
    final (got, settled) = await tap(tester);
    expect(settled, isTrue);
    expect(got, PlayChoice.next);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('appui long: la feuille revient malgré le réglage — même '
      'après un await dans le geste', (tester) async {
    UserSettings.instance.playStartInApp = PlayStartAction.now;
    final (_, settled) = await tap(tester, hold: true);
    expect(settled, isFalse); // la feuille attend un choix
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('appui long, file VIDE: la feuille s\'affiche quand même',
      (tester) async {
    globalQueueHasContent = () => false;
    final (_, settled) = await tap(tester, hold: true);
    expect(settled, isFalse);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  test('zone: un geste résolu APRÈS un await reste « feuille imposée »',
      () async {
    var seen = false;
    await withPlayChoiceSheet(() async {
      await Future<void>.delayed(Duration.zero);
      seen = playChoiceSheetForced;
    });
    expect(seen, isTrue);
    expect(playChoiceSheetForced, isFalse);
  });

  test('au démarrage: normal, mini, ou comme à la fermeture', () {
    final s = UserSettings.instance;
    expect(s.launchWindow, LaunchWindowMode.normal);
    expect(launchPrefersMini(s), isFalse);
    s.launchWindow = LaunchWindowMode.mini;
    expect(launchPrefersMini(s), isTrue);
    s.launchWindow = LaunchWindowMode.last;
    s.lastWindowMini = false;
    expect(launchPrefersMini(s), isFalse);
    s.lastWindowMini = true;
    expect(launchPrefersMini(s), isTrue);
  });
}
