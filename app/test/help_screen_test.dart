// L'onglet Aide (lib/help_screen.dart): le lien vers la documentation en
// ligne a son texte dans toutes les langues et vise le site en https.
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/help_screen.dart';
import 'package:rewamp/l10n/app_localizations.dart';

void main() {
  test('le lien de documentation a son texte et vise rewamp.app en https', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      expect(l.helpTitle, isNotEmpty, reason: '$locale');
      expect(l.helpDocsTitle, isNotEmpty, reason: '$locale');
      expect(l.helpDocsSubtitle, isNotEmpty, reason: '$locale');
    }
    expect(kOnlineDocsUrl, startsWith('https://rewamp.app/'));
  });
}
