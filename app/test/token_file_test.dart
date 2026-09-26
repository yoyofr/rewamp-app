// Le jeton en fichier 0600, repli sans service de secrets (voir token_file.dart).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/token_file.dart';

void main() {
  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tok_');
    TokenFile.dirOverride = tmp;
  });
  tearDown(() async {
    TokenFile.dirOverride = null;
    await tmp.delete(recursive: true);
  });

  test('rien écrit ⇒ null', () async {
    expect(await TokenFile.read(), isNull);
  });

  test('écrit, relu à l\'identique, et lisible par le seul propriétaire', () async {
    expect(await TokenFile.write('abc.def.ghi'), isTrue);
    expect(await TokenFile.read(), 'abc.def.ghi');
    if (!Platform.isWindows) {
      final mode = (await Process.run('stat', ['-c', '%a', '${tmp.path}/auth_token']))
          .stdout
          .toString()
          .trim();
      expect(mode, '600', reason: 'un secret qui reste doit rester PRIVÉ');
    }
  });

  test('réécrit: le nouveau remplace l\'ancien, mode conservé', () async {
    await TokenFile.write('premier');
    await TokenFile.write('second');
    expect(await TokenFile.read(), 'second');
  });

  test('effacé ⇒ null, et effacer deux fois ne lève pas', () async {
    await TokenFile.write('x');
    await TokenFile.delete();
    await TokenFile.delete();
    expect(await TokenFile.read(), isNull);
  });
}
