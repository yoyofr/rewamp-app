import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/download_cancel.dart';
import 'package:rewamp/download_manager.dart';

void main() {
  test('le jeton voyage par la ZONE jusque dans les continuations imbriquées',
      () async {
    final token = DownloadCancelToken();
    DownloadCancelToken? seen;
    await token.run(() async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>(() async {
        await Future<void>.delayed(Duration.zero);
        seen = DownloadCancelToken.current; // deep inside, no parameter passed
      });
    });
    expect(identical(seen, token), isTrue);
    expect(DownloadCancelToken.current, isNull); // pas de fuite hors de run()
  });

  test('cancel ferme les clients enregistrés, y compris ceux inscrits APRÈS',
      () {
    final token = DownloadCancelToken();
    var closedBefore = 0, closedAfter = 0;
    token.register(() => closedBefore++);
    token.cancel();
    expect(closedBefore, 1);
    token.register(() => closedAfter++); // arrive trop tard: fermé sur-le-champ
    expect(closedAfter, 1);
    token.cancel(); // idempotent
    expect(closedBefore, 1);
  });

  test('unregister retire le client une fois le fetch terminé', () {
    final token = DownloadCancelToken();
    var closed = 0;
    void closer() => closed++;
    token.register(closer);
    token.unregister(closer);
    token.cancel();
    expect(closed, 0);
  });

  test('throwIfCancelled lève DownloadCancelledException', () {
    final token = DownloadCancelToken()..cancel();
    expect(() => token.throwIfCancelled('x'),
        throwsA(isA<DownloadCancelledException>()));
  });

  test('annuler le job ACTIF le termine et la file enchaîne sur le suivant',
      () async {
    final mgr = DownloadManager.instance;
    final firstStarted = Completer<void>();
    final secondRan = Completer<void>();

    mgr.enqueue('long', () async {
      firstStarted.complete();
      // Une transmission qui ne finit jamais d'elle-même: seul le jeton la
      // termine — exactement le cas d'un gros album sur un lien lent.
      while (true) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        DownloadCancelToken.current?.throwIfCancelled('long');
      }
    }, key: 'test:long');
    mgr.enqueue('court', () async {
      secondRan.complete();
    }, key: 'test:court');

    await firstStarted.future;
    expect(mgr.active?.label, 'long');
    mgr.cancelActive();
    await secondRan.future.timeout(const Duration(seconds: 5));
    // La file a bien avancé et rien ne reste en vol.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(mgr.count, 0);
  });
}
