import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/carplay.dart';
import 'package:rewamp/carplay_voice_search.dart';
import 'package:rewamp/download_cancel.dart';
import 'package:rewamp/l10n/app_localizations_en.dart';
import 'package:rewamp/local_db.dart';
import 'package:rewamp/player_controller.dart';
import 'package:rewamp/rewamp_db.dart';

class Controller extends ChangeNotifier implements PlayerController {
  @override
  List<QueueEntry> queue = [const QueueEntry(id: 1, title: 'Tune')];
  @override
  int queueIdx = 0;
  @override
  int queueRevision = 0;
  @override
  bool canGoNext = true;
  @override
  bool canGoPrev = false;
  @override
  bool shuffleEnabled = false;
  int shuffleToggles = 0;
  @override
  void toggleShuffle() {
    shuffleToggles++;
    shuffleEnabled = !shuffleEnabled;
    notifyListeners();
  }

  @override
  void setPlaybackPreparing(bool value) {}
  Future<void> Function()? next;
  @override
  Future<void> goNext() async => next?.call();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Library implements CarPlayLibrary {
  Object? voiceError;
  List<TrackRecord> recent = [];
  @override
  Future<List<SearchResult>> voiceSearch(CarPlayVoiceQuery query) async {
    if (voiceError != null) throw voiceError!;
    return [];
  }

  @override
  Future<List<TrackRecord>> tracks(String source) async => recent;
  @override
  Future<List<UserPlaylist>> playlists() async => [];
  @override
  Future<List<Collection>> collections() async => [];
  @override
  Future<List<SearchResult>> online(
          String source, String query, int offset, int limit) async =>
      [];
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('rewamp/carplay');
  const codec = StandardMethodCodec();
  late Controller controller;
  late CarPlaySession session;
  late Library library;
  late List<MethodCall> calls;
  Future<void> Function()? play;

  Future<Object?> incoming(
      String method, Map<String, Object?> arguments) async {
    final reply = Completer<ByteData?>();
    binding.defaultBinaryMessenger.handlePlatformMessage(channel.name,
        codec.encodeMethodCall(MethodCall(method, arguments)), reply.complete);
    return codec.decodeEnvelope((await reply.future)!);
  }

  setUp(() {
    calls = [];
    controller = Controller();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call);
      return call.method == 'ready';
    });
    library = Library();
    final browser = CarPlayBrowser(
        library: library,
        queue: () => controller.queue,
        queueIndex: () => controller.queueIdx,
        playQueueIndex: (_) async {
          await play?.call();
        },
        playTracks: (tracks, index) async {},
        playOnline: (_) async {});
    session = CarPlaySession(controller, browser, () => AppLocalizationsEn());
    play = null;
  });
  tearDown(() {
    session.dispose();
    controller.dispose();
    RewampDb.downloadStatus.value = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets(
      'cold-start handshake returns localized labels then handles native browse',
      (tester) async {
    await session.start();
    expect(session.connected, true);
    expect((calls.first.arguments as Map)['library'], 'Library');
    final page = await incoming('browse', {'source': 'queue'}) as Map;
    expect((page['items'] as List).single['title'], 'Tune');
    await tester.pump(const Duration(milliseconds: 250));
    expect(calls.where((c) => c.method == 'changed').length, 1);
  });

  testWidgets(
      'player ticks do not repeatedly rebuild the car lists; disconnect silences updates',
      (tester) async {
    await session.start();
    controller.notifyListeners();
    await tester.pump(const Duration(milliseconds: 250));
    calls.clear();
    for (var i = 0; i < 10; i++) {
      controller.notifyListeners();
    }
    await tester.pump(const Duration(seconds: 1));
    expect(calls, isEmpty);
    await incoming('setConnected', {'connected': false});
    controller.queueIdx = 1;
    controller.notifyListeners();
    RewampDb.downloadStatus.value =
        const DownloadInfo('Download', progress: .5);
    await tester.pump(const Duration(milliseconds: 250));
    expect(calls, isEmpty);
  });

  testWidgets('Now Playing toggles the shared shuffle state on and off',
      (tester) async {
    await session.start();
    expect(calls.lastWhere((c) => c.method == 'shuffleState').arguments, false);
    expect(await incoming('toggleShuffle', {}), true);
    expect(controller.shuffleToggles, 1);
    expect(calls.lastWhere((c) => c.method == 'shuffleState').arguments, true);
    expect(await incoming('toggleShuffle', {}), false);
    expect(controller.shuffleToggles, 2);
    expect(calls.lastWhere((c) => c.method == 'shuffleState').arguments, false);
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('phone shuffle changes and reconnect refresh the car indicator',
      (tester) async {
    controller.shuffleEnabled = true;
    await session.start();
    expect(calls.lastWhere((c) => c.method == 'shuffleState').arguments, true);
    controller.toggleShuffle();
    expect(calls.lastWhere((c) => c.method == 'shuffleState').arguments, false);
    await incoming('setConnected', {'connected': false});
    calls.clear();
    controller.toggleShuffle();
    expect(calls, isEmpty);
    await incoming('setConnected', {'connected': true});
    expect(calls.lastWhere((c) => c.method == 'shuffleState').arguments, true);
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets(
      'slow download publishes progress until playback actually completes',
      (tester) async {
    await session.start();
    final resume = Completer<void>();
    play = () async {
      RewampDb.downloadStatus.value =
          const DownloadInfo('New tune', progress: .35);
      await resume.future;
    };
    final page = await incoming('browse', {'source': 'queue'}) as Map;
    var complete = false;
    final selection = incoming('select', {
      'source': 'queue',
      'id': (page['items'] as List).single['id']
    }).then((_) => complete = true);
    await tester.pump();
    expect(complete, false);
    final progress =
        calls.lastWhere((c) => c.method == 'download').arguments as Map;
    expect(progress['title'], 'New tune');
    expect(progress['progress'], .35);
    expect(progress['canNext'], true);
    controller.canGoNext = false;
    controller.notifyListeners();
    final updated =
        calls.lastWhere((c) => c.method == 'download').arguments as Map;
    expect(updated['canNext'], false);
    expect(updated['progress'], .35);
    // Unrelated background downloads may not steal the progress display.
    final count = calls.where((c) => c.method == 'download').length;
    RewampDb.downloadStatus.value =
        const DownloadInfo('Prefetch', progress: .9);
    expect(calls.where((c) => c.method == 'download').length, count);
    resume.complete();
    await selection;
    expect(calls.lastWhere((c) => c.method == 'download').arguments, isNull);
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets(
      'skip supersedes a pending download without a busy or failure alert',
      (tester) async {
    await session.start();
    final resume = Completer<void>();
    final started = Completer<void>();
    late DownloadCancelToken original;
    play = () async {
      original = DownloadCancelToken.current!;
      started.complete();
      await resume.future;
      original.throwIfCancelled();
    };
    final page = await incoming('browse', {'source': 'queue'}) as Map;
    final selection = incoming('select',
        {'source': 'queue', 'id': (page['items'] as List).single['id']});
    final cancelled = expectLater(
        selection,
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'cancelled')));
    await started.future;
    var skipped = false;
    controller.next = () async {
      skipped = true;
    };
    await incoming('skip', {});
    expect(original.isCancelled, true);
    expect(skipped, true);
    resume.complete();
    await cancelled;
    expect(calls.where((c) => c.method == 'error'), isEmpty);
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets(
      'cancel aborts only the active CarPlay selection and returns a cancelled result',
      (tester) async {
    await session.start();
    final started = Completer<void>();
    final resume = Completer<void>();
    late DownloadCancelToken token;
    play = () async {
      token = DownloadCancelToken.current!;
      started.complete();
      await resume.future;
      token.throwIfCancelled();
    };
    final page = await incoming('browse', {'source': 'queue'}) as Map;
    final selection = incoming('select',
        {'source': 'queue', 'id': (page['items'] as List).single['id']});
    final expectation = expectLater(
        selection,
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'cancelled')));
    await started.future;
    await incoming('cancel', {});
    expect(token.isCancelled, true);
    resume.complete();
    await expectation;
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets(
      'Siri service failures remain errors and diagnostics omit error payloads',
      (tester) async {
    library.voiceError = StateError('private request contents');
    await session.start();
    await expectLater(
        incoming('voiceSearch', {
          'query': 'Durban Poison',
          'artist': 'Randall',
          'request': 'test-request'
        }),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'search_unavailable')));
    final event =
        calls.lastWhere((c) => c.method == 'siriLog').arguments as Map;
    expect(event['stage'], 'catalogue_error');
    expect(event['request'], 'test-request');
    expect(event['error'], 'StateError');
    expect(event.toString(), isNot(contains('private request contents')));
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('Siri no-match remains an empty successful lookup',
      (tester) async {
    await session.start();
    expect(await incoming('voiceSearch', {'query': 'No such module'}), isEmpty);
    final event =
        calls.lastWhere((c) => c.method == 'siriLog').arguments as Map;
    expect(event['stage'], 'catalogue_result');
    expect(event['count'], 0);
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('Siri diagnostic HTTP status is retained without request secrets',
      (tester) async {
    library.voiceError =
        Exception('search_music HTTP 403; private request contents');
    await session.start();
    await expectLater(incoming('voiceSearch', {'query': 'Durban Poison'}),
        throwsA(isA<PlatformException>()));
    final event =
        calls.lastWhere((c) => c.method == 'siriLog').arguments as Map;
    expect(event['httpStatus'], 403);
    expect(event['kind'], 'http');
    expect(event.toString(), isNot(contains('private request contents')));
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('Siri vocabulary includes recent tracker artists',
      (tester) async {
    library.recent = [
      TrackRecord(
          id: 'module',
          filePath: '',
          entryPath: '',
          subsongIdx: 0,
          title: 'Durban Poison',
          artist: 'Randall',
          source: 'online',
          isFavorite: false,
          inLibrary: false,
          playCount: 1)
    ];
    await session.start();
    final vocabulary =
        calls.lastWhere((c) => c.method == 'vocabulary').arguments as Map;
    expect(vocabulary['artists'], ['Randall']);
    await tester.pump(const Duration(milliseconds: 250));
  });
}
