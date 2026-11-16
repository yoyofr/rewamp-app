// Une panne de RÉSEAU ou de SERVEUR se dit en une phrase claire, et se répare
// seule: classification des erreurs (load_error.dart) et état du lien
// (network_status.dart, client installé pour toute l'app).
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rewamp/load_error.dart';
import 'package:rewamp/network_status.dart';

void main() {
  group('classifyLoadError', () {
    test('hors ligne', () {
      expect(classifyLoadError(const SocketException('Failed host lookup: api.rewamp.app')),
          LoadErrorKind.offline);
      expect(classifyLoadError("ClientException with SocketException: Failed host lookup: 'api.rewamp.app'"),
          LoadErrorKind.offline);
    });
    test('lent / instable', () {
      expect(classifyLoadError(TimeoutException('x')), LoadErrorKind.slow);
      expect(classifyLoadError('TimeoutException after 0:00:25.000000: Future not completed'),
          LoadErrorKind.slow);
      expect(classifyLoadError('Exception: search_music HTTP 504 '), LoadErrorKind.slow);
      expect(classifyLoadError('RewampRpcException(57014, canceling statement due to statement timeout)'),
          LoadErrorKind.slow);
    });
    test('panne serveur', () {
      expect(classifyLoadError('Exception: search_music HTTP 503 '), LoadErrorKind.server);
      expect(classifyLoadError('Exception: list_tags HTTP 500 boom'), LoadErrorKind.server);
      expect(classifyLoadError('Exception: list_tags HTTP 429 '), LoadErrorKind.server);
    });
    test('le reste n\'est PAS mis sur le dos du réseau', () {
      expect(classifyLoadError('Exception: list_tags HTTP 400 bad'), LoadErrorKind.other);
      expect(classifyLoadError(StateError('x')), LoadErrorKind.other);
    });
  });

  group('NetworkAwareClient', () {
    setUp(() => NetworkStatus.instance.resetForTest());
    tearDown(() => NetworkStatus.instance.resetForTest());
    final api = Uri.parse('https://api.rewamp.app/rpc/x');

    test('échec réseau vers le serveur ⇒ hors ligne, réponse ⇒ ok', () async {
      final down = NetworkAwareClient(MockClient(
          (_) async => throw const SocketException('Failed host lookup')));
      await expectLater(down.get(api), throwsA(isA<SocketException>()));
      expect(NetworkStatus.instance.value, NetIssue.offline);
      final up = NetworkAwareClient(MockClient((_) async => http.Response('[]', 200)));
      await up.get(api);
      expect(NetworkStatus.instance.value, NetIssue.none);
    });

    test('X-Rewamp-Client vers NOTRE API seulement', () async {
      final seen = <String, String?>{};
      final c = NetworkAwareClient(MockClient((r) async {
        seen[r.url.host] = r.headers['X-Rewamp-Client'];
        return http.Response('[]', 200);
      }));
      await c.get(api);
      await c.get(Uri.parse('https://ftp.modland.com/x'));
      expect(seen['api.rewamp.app'], isNotNull);
      expect(seen['api.rewamp.app'], startsWith(Platform.operatingSystem));
      expect(seen['ftp.modland.com'], isNull);
    });

    test('passerelle 503 ⇒ lent; un autre hôte ne compte pas', () async {
      final gw = NetworkAwareClient(MockClient((_) async => http.Response('', 503)));
      await gw.get(Uri.parse('https://ftp.modland.com/x'));
      expect(NetworkStatus.instance.value, NetIssue.none);
      await gw.get(api);
      expect(NetworkStatus.instance.value, NetIssue.slow);
    });

    // testWidgets: son horloge est FAUSSE (pump avance les minuteurs).
    testWidgets('une requête qui traîne marque le lien lent', (tester) async {
      final c = Completer<http.Response>();
      final slow = NetworkAwareClient(MockClient((_) => c.future));
      final f = slow.get(api);
      await tester.pump(NetworkStatus.slowAfter + const Duration(seconds: 1));
      expect(NetworkStatus.instance.value, NetIssue.slow);
      c.complete(http.Response('[]', 200));
      await f;
      expect(NetworkStatus.instance.value, NetIssue.none);
      NetworkStatus.instance.resetForTest();
    });
  });
}
