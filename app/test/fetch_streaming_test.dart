// Le cœur de téléchargement, contre un VRAI serveur HTTP local.
//
// Il est sur le chemin de TOUS les téléchargements: le refactor du 2026-09-21
// l'a fait écrire dans un « puits » (mémoire ou fichier) au lieu d'un
// BytesBuilder en dur. Ces tests épinglent les deux puits, et surtout les deux
// comportements que le passage au fichier rendait nouveaux: l'effacement du
// `.part` sur échec, et la REMISE À ZÉRO du puits au rejeu d'interstitiel.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/download_cancel.dart';
import 'package:rewamp/rewamp_db.dart';

void main() {
  late HttpServer server;
  late Directory tmp;
  late Uint8List payload;
  late String base;
  // Comportement de la route /interstitiel: la 1re réponse est une page HTML
  // qui pose un cookie `verified`, la suivante (avec le cookie) le fichier.
  var interstitialHits = 0;

  setUpAll(() async {
    final rnd = Random(42);
    // 3 Mo: assez pour traverser de nombreux blocs réseau.
    payload = Uint8List.fromList(
        List<int>.generate(3 * 1024 * 1024, (_) => rnd.nextInt(256)));
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      final res = req.response;
      switch (req.uri.path) {
        case '/file':
          res.contentLength = payload.length;
          res.add(payload);
          await res.close();
        case '/drop':
          // Annonce 3 Mo, en envoie 64 Ko, puis coupe la connexion.
          // ⚠️ Piège de HARNAIS payé ici: `detachSocket` doit venir AVANT tout
          // octet écrit par la réponse — après un `flush()` il lève « Headers
          // already sent », la connexion n'est jamais coupée, et le test
          // échoue par DÉLAI en accusant le code testé. On écrit donc la
          // réponse HTTP à la main, sur la socket détachée.
          final s = await res.detachSocket(writeHeaders: false);
          s.write('HTTP/1.1 200 OK\r\n'
              'Content-Length: ${payload.length}\r\n\r\n');
          s.add(payload.sublist(0, 64 * 1024));
          await s.flush();
          s.destroy();
        case '/interstitiel':
          interstitialHits++;
          final cookie = req.headers.value('cookie') ?? '';
          if (!cookie.contains('verified=')) {
            res.headers.add('set-cookie', 'verified=ok; Path=/');
            res.headers.contentType = ContentType.html;
            res.write('<!DOCTYPE html><html><body>Verifying your browser'
                '…</body></html>');
          } else {
            res.contentLength = payload.length;
            res.add(payload);
          }
          await res.close();
        case '/slow':
          // 3 Mo au compte-gouttes: le transfert est EN COURS quand on annule.
          res.contentLength = payload.length;
          for (var i = 0; i < payload.length; i += 16 * 1024) {
            res.add(payload.sublist(i, min(i + 16 * 1024, payload.length)));
            await res.flush();
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          await res.close();
        default:
          res.statusCode = 404;
          await res.close();
      }
    });
  });

  tearDownAll(() => server.close(force: true));
  setUp(() async => tmp = await Directory.systemTemp.createTemp('fetch_'));
  tearDown(() async => tmp.delete(recursive: true));

  test('mémoire: les octets reçus sont exactement ceux servis', () async {
    final got = await RewampDb.fetchBytesForTest('$base/file');
    expect(got, payload);
  });

  test('fichier: contenu, taille et EN-TÊTE exacts; aucun .part laissé',
      () async {
    final dest = File('${tmp.path}/a.7z');
    final (len, head) = await RewampDb.fetchToFileForTest('$base/file', dest);

    expect(len, payload.length);
    expect(await dest.readAsBytes(), payload);
    expect(head, payload.sublist(0, 512),
        reason: 'l\'en-tête sert à TOUS les reniflages (HTML, Rar!, gzip)');
    expect(File('${dest.path}.part').existsSync(), isFalse);
  });

  test('fichier: une connexion COUPÉE ne laisse ni fichier ni .part', () async {
    // C'est la raison d'être du .part: le tampon d'archives ne vérifie que
    // l'existence et l'âge, donc un fichier tronqué y serait repris comme bon.
    final dest = File('${tmp.path}/b.7z');
    await expectLater(
        RewampDb.fetchToFileForTest('$base/drop', dest), throwsA(anything));
    expect(dest.existsSync(), isFalse, reason: 'jamais d\'archive tronquée');
    expect(File('${dest.path}.part').existsSync(), isFalse);
  });

  test('fichier: le rejeu d\'interstitiel REPART DE ZÉRO', () async {
    // Nouveau avec le puits fichier: sans reset(), la page HTML resterait
    // collée DEVANT le vrai contenu, et l'archive serait illisible.
    interstitialHits = 0;
    final dest = File('${tmp.path}/c.7z');
    final (len, head) =
        await RewampDb.fetchToFileForTest('$base/interstitiel', dest);

    expect(interstitialHits, 2, reason: 'une page, puis le fichier');
    expect(len, payload.length);
    expect(await dest.readAsBytes(), payload,
        reason: 'aucun résidu HTML devant le contenu');
    expect(head, payload.sublist(0, 512));
  });
  // Depuis le 2026-09-22 le transfert tourne dans un ISOLATE (voir
  // isolate_fetch.dart). Le jeton d'annulation, lui, vit dans la ZONE de
  // l'appelant: ces deux tests épinglent ce qui doit traverser la frontière.
  test('annuler EN PLEIN transfert: rend la main vite, sans .part', () async {
    final dest = File('${tmp.path}/d.7z');
    final token = DownloadCancelToken();
    final sw = Stopwatch()..start();
    final fut = token.run(() => RewampDb.fetchToFileForTest('$base/slow', dest));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(File('${dest.path}.part').existsSync(), isTrue,
        reason: 'le transfert doit être en cours au moment de l\'annulation');
    token.cancel();
    await expectLater(fut, throwsA(isA<DownloadCancelledException>()));
    expect(sw.elapsed, lessThan(const Duration(seconds: 2)),
        reason: 'le serveur lent mettrait ~4 s à tout envoyer');
    expect(dest.existsSync(), isFalse);
    expect(File('${dest.path}.part').existsSync(), isFalse);
  });

  test('statut non-200: DownloadHttpException, pas un autre type', () async {
    await expectLater(RewampDb.fetchBytesForTest('$base/absent'),
        throwsA(isA<DownloadHttpException>()));
  });
}
