import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/carplay.dart';
import 'package:rewamp/download_cancel.dart';

void main() {
  test('late download completion cannot start audio or clear newer progress',
      () async {
    final playback = CarPlayPlayback();
    final firstDone = Completer<void>();
    final secondDone = Completer<void>();
    var firstPlayed = false;
    final first = playback.run(() async {
      final cancel = DownloadCancelToken.current!;
      await firstDone.future;
      cancel.throwIfCancelled();
      firstPlayed = true;
    });
    final cancelled =
        expectLater(first, throwsA(isA<DownloadCancelledException>()));
    final second = playback.run(() async {
      await secondDone.future;
      DownloadCancelToken.current!.throwIfCancelled();
    });
    firstDone.complete();
    await cancelled;
    expect(firstPlayed, false);
    expect(playback.busy, true);
    secondDone.complete();
    await second;
    expect(playback.busy, false);
    playback.dispose();
  });

  test('only a real failure of the current download propagates as an error',
      () async {
    final playback = CarPlayPlayback();
    final error = StateError('Download failed');
    await expectLater(
        playback.run(() async => throw error), throwsA(same(error)));
    expect(playback.busy, false);
    playback.dispose();
  });

  test('nested queue playback shares its selection cancellation scope',
      () async {
    final playback = CarPlayPlayback();
    await playback.run(() async {
      final original = DownloadCancelToken.current;
      await playback.run(() async {
        expect(DownloadCancelToken.current, same(original));
        expect(playback.ownsCurrent, true);
      });
      expect(playback.busy, true);
      expect(original!.isCancelled, false);
    });
    playback.dispose();
  });
}
