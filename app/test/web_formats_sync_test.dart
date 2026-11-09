// L'app web (webapp/) affiche dans « À propos » le nombre de formats lus et
// leur liste, moteur par moteur — la MÊME que Réglages → À propos → Formats
// de l'app (engine_formats_screen.dart). Les extensions vivent dans des
// constantes Dart éparpillées (kTrackerExts, RewampDb.kVgmstreamExts…): le
// web ne les relit pas, il lit webapp/formats.json, généré ici.
//
//   REWAMP_WRITE_WEB_FORMATS=1 flutter test test/web_formats_sync_test.dart
//     → réécrit webapp/formats.json;
//   flutter test (normal)
//     → échoue si le fichier ne correspond plus à kEngines.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/engines.dart';

/// Depuis `app/`, où `flutter test` s'exécute.
const _out = '../webapp/formats.json';

String _generate() {
  final engines = [
    for (final e in kEngines)
      {
        'name': e.name,
        'formats': (e.formats.map((x) => x.toLowerCase()).toSet().toList()..sort()),
      },
  ];
  return '${const JsonEncoder.withIndent(' ').convert({
        'source': 'app/lib/engines.dart (test/web_formats_sync_test.dart)',
        'count': kTotalFormatCount,
        'engines': engines,
      })}\n';
}

void main() {
  test('webapp/formats.json suit kEngines', () {
    final want = _generate();
    final f = File(_out);
    if (Platform.environment['REWAMP_WRITE_WEB_FORMATS'] == '1') {
      f.writeAsStringSync(want);
      return;
    }
    expect(f.existsSync(), isTrue, reason: 'lancer avec REWAMP_WRITE_WEB_FORMATS=1');
    expect(f.readAsStringSync(), want,
        reason: 'formats.json périmé: REWAMP_WRITE_WEB_FORMATS=1 flutter test test/web_formats_sync_test.dart');
  });
}
