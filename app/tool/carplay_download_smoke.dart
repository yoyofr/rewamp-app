// End-to-end CarPlay bridge smoke: real catalogue, download, queue and decoder.
// Build only for a disposable simulator; restore lib/main.dart afterward.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rewamp/main.dart' as app;
import 'package:rewamp/media_session.dart';
import 'package:rewamp/rewamp_db.dart';
import 'package:rewamp/user_settings.dart';

Future<Object?> incoming(String method, Map<String, Object?> args) async {
  const codec = StandardMethodCodec();
  final reply = Completer<ByteData?>();
  ServicesBinding.instance.channelBuffers.push('rewamp/carplay',
      codec.encodeMethodCall(MethodCall(method, args)), reply.complete);
  return codec.decodeEnvelope((await reply.future)!);
}

void main() {
  app.main();
  unawaited(run().catchError((Object error, StackTrace stack) {
    debugPrint('[CarPlay download smoke] FAILED: $error\n$stack');
  }));
}

Future<void> run() async {
  while (gMediaHandler == null) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  await Future<void>.delayed(const Duration(seconds: 2));
  await incoming('setConnected', {'connected': true});
  RewampDb.downloadStatus.addListener(() {
    final info = RewampDb.downloadStatus.value;
    debugPrint(
        '[CarPlay download smoke] download: ${info?.label} ${info?.progress} ${info?.error}');
  });
  final results = await incoming('voiceSearch',
      {'query': 'The Bullet', 'artist': 'Randall'}) as List;
  final item = results.first as Map;
  debugPrint('[CarPlay download smoke] selecting ${item['title']}');
  final settings = UserSettings.instance;
  final previousAutoplay = settings.queueAutoplay;
  settings.queueAutoplay = true;
  try {
    await incoming('select', {'source': 'voiceSearch', 'id': item['id']});
    if (!gMediaHandler!.c.isPlaying) {
      throw StateError('Selection completed without playback');
    }
    debugPrint('[CarPlay download smoke] PASSED: ${gMediaHandler!.c.fileName}');
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (!gMediaHandler!.c.queue.any((entry) => entry.autoplay)) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('CarPlay playback did not refill upstream autoplay');
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    debugPrint('[CarPlay download smoke] PASSED: upstream autoplay refill');
  } finally {
    settings.queueAutoplay = previousAutoplay;
  }
  await gMediaHandler!.stop();

  final nextPage = await incoming('browse',
      {'source': 'onlineSearch', 'query': 'ocean loader', 'limit': 5}) as Map;
  final nextItem =
      (nextPage['items'] as List).firstWhere((r) => r['id'] != null);
  final skipped = Completer<void>();
  var requestedSkip = false;
  void skipDuringDownload() {
    final status = RewampDb.downloadStatus.value;
    if (requestedSkip || status == null || status.error != null) return;
    requestedSkip = true;
    debugPrint('[CarPlay download smoke] skipping pending ${status.label}');
    // A remote transport event is independent of the download's async scope.
    Zone.root.run(() {
      unawaited(gMediaHandler!
          .skipToNext()
          .then(skipped.complete, onError: skipped.completeError));
    });
  }

  RewampDb.downloadStatus.addListener(skipDuringDownload);
  try {
    try {
      await incoming(
          'select', {'source': 'onlineSearch', 'id': nextItem['id']});
      throw StateError('Pending selection was not cancelled by skip');
    } on PlatformException catch (error) {
      if (error.code != 'cancelled') rethrow;
    }
    await skipped.future.timeout(const Duration(seconds: 45));
    if (!gMediaHandler!.c.isPlaying || gMediaHandler!.c.queueIdx != 1) {
      throw StateError('Skip did not start the next queue entry');
    }
    debugPrint('[CarPlay download smoke] PASSED: skip while downloading, '
        '${gMediaHandler!.c.fileName}');
    await gMediaHandler!.stop();
  } finally {
    RewampDb.downloadStatus.removeListener(skipDuringDownload);
  }
}
