// Garde-fou: UNE seule fabrique de ThemeData.
//
// Trois copies du thème divergeaient: le repli de police CJK, posé sur la
// première seulement, manquait au lecteur teinté et au panneau ⓘ (kanji en
// rectangles, 2026-09-21). Ce test fait échouer la suite si un `ThemeData(`
// réapparaît hors de app_theme.dart.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aucun ThemeData( construit hors de app_theme.dart', () {
    final offenders = <String>[];
    // `IconThemeData(`, `SliderThemeData(`… ne sont pas des thèmes complets.
    final re = RegExp(r'(?<![A-Za-z])ThemeData\(');
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('app_theme.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i].trimLeft();
        if (l.startsWith('//')) continue;
        if (re.hasMatch(l)) offenders.add('${f.path}:${i + 1}: ${l.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'passer par rewampThemeData() — sinon le thème perd le repli '
            'CJK (et tout ce qu\'on y ajoutera ensuite)');
  });
}
