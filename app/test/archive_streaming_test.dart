// Le tampon d'archives partagé, depuis que les archives vont sur DISQUE.
//
// Jusqu'au 2026-09-21 une archive d'album (couramment plusieurs centaines de
// Mo) existait en ENTIER en mémoire — et DEUX fois pour un album zip, parce que
// `Isolate.run` copie ce que sa closure capture. Elle est maintenant écrite au
// fil de l'eau dans le tampon. Ces tests épinglent ce que ce passage pouvait
// casser: la réutilisation, la DÉDUPLICATION de deux descentes simultanées, et
// l'absence de fichier tronqué dans le tampon.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

void main() {
  late HttpServer server;
  late Directory base;
  late Uint8List payload;
  late String url;
  var gets = 0;

  setUpAll(() async {
    final rnd = Random(7);
    payload = Uint8List.fromList(
        List<int>.generate(2 * 1024 * 1024, (_) => rnd.nextInt(256)));
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    url = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      final res = req.response;
      if (req.uri.path.startsWith('/drop')) {
        final s = await res.detachSocket(writeHeaders: false);
        s.write('HTTP/1.1 200 OK\r\nContent-Length: ${payload.length}\r\n\r\n');
        s.add(payload.sublist(0, 32 * 1024));
        await s.flush();
        s.destroy();
        return;
      }
      res.contentLength = payload.length;
      if (req.method == 'HEAD') {       // la sonde de taille (_remoteSize)
        await res.close();
        return;
      }
      gets++;
      // Un peu de latence: rend la fenêtre de DÉDUPLICATION observable.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      res.add(payload);
      await res.close();
    });
  });
  tearDownAll(() => server.close(force: true));

  setUp(() async {
    base = await Directory.systemTemp.createTemp('arch_');
    RewampDb.debugDownloadsBaseOverride = base;
    gets = 0;
  });
  tearDown(() async {
    RewampDb.debugDownloadsBaseOverride = null;
    await base.delete(recursive: true);
  });

  // Chaque test a sa PROPRE url: le tampon et sa table des descentes en vol
  // sont statiques et clés sur l'url.
  var n = 0;
  String fresh(String path) => '$url$path/${n++}.7z';

  test('première descente: le fichier est dans le tampon, entier', () async {
    final u = fresh('/a');
    final (head, path) = await RewampDb.fetchArchiveSharedForTest(null, u,
        expectedSize: payload.length);

    expect(path, startsWith(base.path));
    expect(await File(path).readAsBytes(), payload);
    expect(head, payload.sublist(0, 512));
    expect(File('$path.part').existsSync(), isFalse);
    expect(gets, 1);
  });

  test('deuxième demande: servie par le tampon, SANS nouvelle descente',
      () async {
    final u = fresh('/b');
    final (_, p1) = await RewampDb.fetchArchiveSharedForTest(null, u,
        expectedSize: payload.length);
    final (head, p2) = await RewampDb.fetchArchiveSharedForTest(null, u,
        expectedSize: payload.length);

    expect(p2, p1);
    expect(head, payload.sublist(0, 512));
    expect(gets, 1, reason: 'le tampon ne relit que l\'EN-TÊTE, pas l\'archive');
  });

  test('deux demandes SIMULTANÉES: une seule descente', () async {
    final u = fresh('/c');
    final results = await Future.wait([
      RewampDb.fetchArchiveSharedForTest(null, u, expectedSize: payload.length),
      RewampDb.fetchArchiveSharedForTest(null, u, expectedSize: payload.length),
    ]);
    expect(results[0].$2, results[1].$2);
    expect(gets, 1, reason: 'la seconde REJOINT la première au lieu de redescendre');
    expect(await File(results[0].$2).readAsBytes(), payload);
  });

  test('connexion coupée: rien dans le tampon, ni fichier ni .part', () async {
    final u = fresh('/drop');
    await expectLater(
        RewampDb.fetchArchiveSharedForTest(null, u,
            expectedSize: payload.length),
        throwsA(anything));
    final cache = Directory('${base.path}/online/_archive_cache');
    final left = cache.existsSync() ? cache.listSync() : <FileSystemEntity>[];
    expect(left, isEmpty,
        reason: 'une archive TRONQUÉE dans le tampon serait reprise comme bonne');
  });

  test('zip: décoder depuis un FICHIER rend exactement les mêmes entrées',
      () async {
    // Le seul changement de comportement du chemin album zip: `decodeBytes`
    // sur des octets en mémoire → `decodeStream` sur un InputFileStream.
    final arc = Archive();
    final rnd = Random(3);
    arc.add(ArchiveFile.bytes('Album/01 Intro.vgz',
        Uint8List.fromList(List.generate(300000, (_) => rnd.nextInt(256)))));
    arc.add(ArchiveFile.string('Album/sub/!tags.m3u', '# @ALBUM Test\na.vgz\n'));
    arc.add(ArchiveFile.bytes('Album/cover.png',
        Uint8List.fromList(List.generate(5000, (i) => i % 256))));
    final zipBytes = ZipEncoder().encodeBytes(arc);
    final f = File('${base.path}/t.zip')..writeAsBytesSync(zipBytes);

    final fromMem = ZipDecoder().decodeBytes(zipBytes);
    final input = InputFileStream(f.path);
    try {
      final fromFile = ZipDecoder().decodeStream(input);
      expect([for (final e in fromFile) e.name],
          [for (final e in fromMem) e.name]);
      for (var i = 0; i < fromMem.length; i++) {
        expect(fromFile[i].content, fromMem[i].content,
            reason: 'contenu décompressé de ${fromMem[i].name}');
      }
    } finally {
      input.closeSync();
    }
  });
}
