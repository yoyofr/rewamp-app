import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/l10n/app_localizations.dart';

/// Sur iOS et macOS, la liste des langues qu'Apple propose dans Réglages →
/// l'app → Langue vient de `CFBundleLocalizations`, PAS de `supportedLocales`.
/// Les deux plists n'y déclaraient que `en` et `fr`: l'app parle 18 langues et
/// le système n'en offrait que deux, sans le moindre avertissement au build.
///
/// ⚠️ Le test lit le PLIST, pas une constante Dart recopiée: c'est la
/// divergence entre les deux mondes qu'il surveille, et une constante partagée
/// n'existe pas ici (les plists sont lus par Xcode, jamais par Dart).
void main() {
  final expected = AppLocalizations.supportedLocales
      .map((l) => l.languageCode)
      .toSet();

  for (final path in const [
    'ios/Runner/Info.plist',
    'macos/Runner/Info.plist',
  ]) {
    test('$path déclare les ${expected.length} langues de l\'app', () {
      final xml = File(path).readAsStringSync();
      final start = xml.indexOf('<key>CFBundleLocalizations</key>');
      expect(start, isNot(-1), reason: 'clé CFBundleLocalizations absente');
      final open = xml.indexOf('<array>', start);
      final close = xml.indexOf('</array>', open);
      final declared = RegExp(r'<string>([^<]+)</string>')
          .allMatches(xml.substring(open, close))
          .map((m) => m.group(1)!)
          .toSet();
      expect(declared, equals(expected));
    });
  }
}
