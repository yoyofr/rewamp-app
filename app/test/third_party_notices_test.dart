// THIRD-PARTY-NOTICES.md est GÉNÉRÉ depuis lib/engines.dart — la même liste que
// l'écran « À propos ». Une liste de licences tenue à la main dérive: le trou
// trouvé le 2026-08-20 (quatre polices embarquées dans des .h, invisibles à un
// inventaire de third_party/) est exactement ce que la dérive produit.
//
// Ce test fait les DEUX moitiés du travail:
//   REWAMP_WRITE_NOTICES=1 flutter test test/third_party_notices_test.dart
//     → réécrit le fichier;
//   flutter test (normal)
//     → échoue si le fichier sur disque ne correspond plus au registre.
//
// C'est un test et non un `dart run` parce que engines.dart tire rewamp_db.dart
// et avec lui le plugin FFI, que la VM Dart nue refuse de compiler.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/third_party_notices.dart';

/// La racine du dépôt depuis `app/`, où `flutter test` s'exécute.
File get _notices => File('../THIRD-PARTY-NOTICES.md');

void main() {
  test('THIRD-PARTY-NOTICES.md suit le registre des moteurs', () {
    final expected = buildThirdPartyNotices();

    if (Platform.environment['REWAMP_WRITE_NOTICES'] == '1') {
      _notices.writeAsStringSync(expected);
      // ignore: avoid_print
      print('THIRD-PARTY-NOTICES.md réécrit (${expected.length} octets)');
      return;
    }

    expect(_notices.existsSync(), isTrue,
        reason: 'THIRD-PARTY-NOTICES.md absent — régénérer avec '
            'REWAMP_WRITE_NOTICES=1 flutter test '
            'test/third_party_notices_test.dart');
    expect(_notices.readAsStringSync(), expected,
        reason: 'engines.dart a bougé sans que les notices soient '
            'régénérées — un moteur ajouté, renommé ou relicencié ne doit pas '
            'disparaître du fichier que le binaire redistribue.');
  });
}
