// Le sous-chant de DÉPART qu'un fichier désigne, et l'ordre de lecture qui en
// découle. Deux règles, toutes deux faciles à décaler d'un cran: les formats
// ne comptent pas pareil (SID à partir de 1, SAP à partir de 0), et « tout
// lire » doit TOUT lire — donc une rotation, pas une troncature.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/default_subsong.dart';
import 'package:rewamp/local_open.dart' show rotateToDefaultSubsong;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rewamp_defsong');
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  Future<String> writeSid(String magic, int startSong) async {
    final b = Uint8List(0x80);
    b.setRange(0, 4, magic.codeUnits);
    b[0x10] = (startSong >> 8) & 0xFF;   // BIG-endian, 1-based
    b[0x11] = startSong & 0xFF;
    final f = File(p.join(tmp.path, 'tune.sid'));
    await f.writeAsBytes(b);
    return f.path;
  }

  Future<String> writeSap(String header) async {
    final f = File(p.join(tmp.path, 'tune.sap'));
    await f.writeAsBytes([
      ...'SAP\r\n$header'.codeUnits,
      0xFF, 0xFF,
    ]);
    return f.path;
  }

  group('en-tête', () {
    test('SID: startSong est 1-BASED, on rend du 0-based dense', () async {
      expect(await defaultSubsongFromHeader(await writeSid('PSID', 5)), 4);
      expect(await defaultSubsongFromHeader(await writeSid('RSID', 3)), 2);
    });

    test('SID: 0 (non précisé) et 1 (le premier) ne désignent rien', () async {
      expect(await defaultSubsongFromHeader(await writeSid('PSID', 0)), isNull);
      expect(await defaultSubsongFromHeader(await writeSid('PSID', 1)), isNull);
    });

    test('SAP: DEFSONG est déjà 0-BASED, aucune conversion', () async {
      expect(
          await defaultSubsongFromHeader(
              await writeSap('AUTHOR "X"\r\nSONGS 4\r\nDEFSONG 2\r\n')),
          2);
    });

    test('SAP sans DEFSONG, ou DEFSONG 0: rien à désigner', () async {
      expect(
          await defaultSubsongFromHeader(await writeSap('SONGS 4\r\n')), isNull);
      expect(
          await defaultSubsongFromHeader(await writeSap('DEFSONG 0\r\n')),
          isNull);
    });

    test('un fichier qui n\'est ni SID ni SAP ne dit rien', () async {
      final f = File(p.join(tmp.path, 'x.mod'));
      await f.writeAsBytes(List.filled(64, 0));
      expect(await defaultSubsongFromHeader(f.path), isNull);
      expect(await defaultSubsongFromHeader('/nexiste/pas.sid'), isNull);
    });
  });

  group('ordre de lecture', () {
    test('la liste TOURNE: 5 pistes, défaut en 3e → 3,4,5,1,2', () {
      expect(rotateToDefaultSubsong([1, 2, 3, 4, 5], 2), [3, 4, 5, 1, 2]);
    });

    test('rien à faire pour 0, null, ou un index hors bornes', () {
      expect(rotateToDefaultSubsong([1, 2, 3], 0), [1, 2, 3]);
      expect(rotateToDefaultSubsong([1, 2, 3], null), [1, 2, 3]);
      expect(rotateToDefaultSubsong([1, 2, 3], 3), [1, 2, 3]);
      expect(rotateToDefaultSubsong([1, 2, 3], 99), [1, 2, 3]);
      expect(rotateToDefaultSubsong(<int>[], 1), isEmpty);
    });

    test('aucune piste ne se perd, et l\'ordre relatif tient', () {
      final out = rotateToDefaultSubsong(['a', 'b', 'c', 'd'], 3);
      expect(out, ['d', 'a', 'b', 'c']);
      expect(out.toSet(), {'a', 'b', 'c', 'd'});
    });
  });
}
