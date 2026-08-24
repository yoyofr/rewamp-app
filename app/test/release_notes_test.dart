// La note de version est montrée UNE fois, au premier lancement d'une build.
//
// Ce qui se casse sans qu'on le voie: une clé ARB ajoutée en anglais et
// oubliée ailleurs (l'écran s'affiche vide dans cette langue), et le point
// « données effacées » montré à une installation neuve, qui n'a rien perdu.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:rewamp/l10n/app_localizations.dart';
import 'package:rewamp/l10n/app_localizations_fr.dart';
import 'package:rewamp/release_notes.dart';

Widget _host(Locale locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReleaseNotesSplash(onDismiss: () {}),
    );

void main() {
  testWidgets('la note se rend et son bouton répond', (tester) async {
    await tester.pumpWidget(_host(const Locale('fr')));
    await tester.pumpAndSettle();

    final fr = AppLocalizationsFr();
    expect(find.text(fr.releaseNotesTitle), findsOneWidget);
    expect(find.text(kReleaseNotesLabel), findsOneWidget);
    expect(find.text(fr.releaseNotesDismiss), findsOneWidget);
    for (final b in releaseNotesBullets(fr)) {
      expect(find.text(b), findsOneWidget, reason: b);
    }
  });

  testWidgets('sans effacement, le point « données effacées » est absent',
      (tester) async {
    // `dataWasReset` est faux par défaut: c'est l'état d'une installation
    // neuve, celle qui n'a précisément rien perdu.
    await tester.pumpWidget(_host(const Locale('fr')));
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsFr().releaseNotesDataReset), findsNothing);
  });

  test('les 18 langues traduisent chaque point', () async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      final texts = [
        l10n.releaseNotesTitle,
        l10n.releaseNotesDismiss,
        l10n.releaseNotesDataReset,
        ...releaseNotesBullets(l10n),
      ];
      for (final t in texts) {
        expect(t.trim(), isNotEmpty, reason: locale.languageCode);
      }
    }
  });
}
