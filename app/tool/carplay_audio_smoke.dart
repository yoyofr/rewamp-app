// Simulator/device smoke entrypoint. Build with
// FLUTTER_TARGET=tool/carplay_audio_smoke.dart, then restore lib/main.dart.
// Exercises the real native engine and audio session, without a file picker.
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rewamp_audio/rewamp_audio.dart';
import 'package:rewamp/local_open.dart';
import 'package:rewamp/main.dart' as app;
import 'package:rewamp/media_session.dart';

Future<void> until(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Smoke test timed out');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  app.main();
  unawaited(run().catchError((Object error, StackTrace stack) {
    debugPrint('[CarPlay audio smoke] FAILED: $error\n$stack');
  }));
}

Future<void> run() async {
  await until(() => globalOpenLocalPaths != null && gMediaHandler != null);
  final audio = RewampAudio();
  if (audio.devicePeriods != 0) {
    throw StateError('Output opened before playback');
  }
  debugPrint('[CarPlay audio smoke] startup has no output device');

  const frames = 44100 * 10;
  final bytes = ByteData(44 + frames * 2);
  void text(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  bytes.setUint32(4, bytes.lengthInBytes - 8, Endian.little);
  text(8, 'WAVEfmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, 44100, Endian.little);
  bytes.setUint32(28, 88200, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  text(36, 'data');
  bytes.setUint32(40, frames * 2, Endian.little);
  for (var i = 0; i < frames; i++) {
    bytes.setInt16(44 + i * 2, (150 * sin(2 * pi * 440 * i / 44100)).round(),
        Endian.little);
  }
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/carplay-audio-smoke.wav');
  await file.writeAsBytes(bytes.buffer.asUint8List());
  await globalOpenLocalPaths!([file.path]);
  await until(() => audio.isPlaying && audio.devicePeriods > 0);
  debugPrint(
      '[CarPlay audio smoke] first play created output and started audio');
  await gMediaHandler!.pause();
  await until(() => !audio.isPlaying);
  await Future<void>.delayed(const Duration(milliseconds: 200));
  await gMediaHandler!.play();
  await until(() => audio.isPlaying);
  await gMediaHandler!.stop();
  await until(() => !audio.isPlaying);
  debugPrint('[CarPlay audio smoke] PASSED: play, pause, resume and stop');
}
