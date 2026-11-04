// `assets/cli/cli_manifest.json` est GÉNÉRÉ depuis kCliOptions: le natif le
// lit avant que Dart n'existe (--help, --version, commande de pilotage sans
// instance). Régénérer:
//   cd app && REWAMP_WRITE_CLI_MANIFEST=1 flutter test test/cli_manifest_sync_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/cli_options.dart';

void main() {
  test('cli_manifest.json suit kCliOptions', () {
    final f = File('assets/cli/cli_manifest.json');
    final want = cliManifestJson();
    if (Platform.environment['REWAMP_WRITE_CLI_MANIFEST'] == '1') {
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(want);
    }
    expect(f.existsSync(), isTrue, reason: 'manifeste absent: régénérer');
    expect(f.readAsStringSync(), want,
        reason: 'manifeste périmé: REWAMP_WRITE_CLI_MANIFEST=1 flutter test '
            'test/cli_manifest_sync_test.dart');
  });
}
