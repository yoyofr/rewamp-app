import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/l10n/app_localizations.dart';
import 'package:rewamp/locale_resolution.dart';

/// Apple canonicalise « no » en « nb » (mesuré sur macOS 26:
/// `Locale.canonicalLanguageIdentifier(from: "no")` rend `nb`), alors que nos
/// traductions vivent dans `app_no.arb`. Sans rapprochement, un appareil
/// norvégien voit l'app en anglais avec sa traduction sur l'étagère.
void main() {
  final supported = AppLocalizations.supportedLocales;

  test('bokmål et nynorsk trouvent le norvégien', () {
    expect(resolveAppLocale(const Locale('nb'), supported),
        const Locale('no'));
    expect(resolveAppLocale(const Locale('nn'), supported),
        const Locale('no'));
    expect(resolveAppLocale(const Locale('no'), supported),
        const Locale('no'));
  });

  test('une variante régionale trouve sa langue', () {
    expect(resolveAppLocale(const Locale('fr', 'CA'), supported),
        const Locale('fr'));
    expect(resolveAppLocale(const Locale('pt', 'BR'), supported),
        const Locale('pt'));
    // zh_Hant: le script voyage dans le countryCode chez Flutter selon la
    // plateforme — dans les deux cas c'est le code de LANGUE qui décide.
    expect(resolveAppLocale(const Locale('zh', 'TW'), supported),
        const Locale('zh'));
  });

  test('la casse du code ne décide de rien', () {
    expect(resolveAppLocale(const Locale('NB'), supported),
        const Locale('no'));
  });

  test('langue inconnue et absence de langue: anglais, jamais la tête de liste',
      () {
    // ⚠️ Sans callback Flutter servirait `supportedLocales.first`, et la liste
    // générée est ALPHABÉTIQUE — donc le tchèque.
    expect(supported.first.languageCode, 'cs', reason: 'ordre alphabétique');
    expect(resolveAppLocale(const Locale('is'), supported),
        const Locale('en'));
    expect(resolveAppLocale(null, supported), const Locale('en'));
  });

  test('les 18 langues de l\'app se résolvent sur elles-mêmes', () {
    for (final l in supported) {
      expect(resolveAppLocale(l, supported), l, reason: l.languageCode);
    }
  });
}
