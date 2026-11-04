import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/media_session.dart';
import 'package:rewamp/player_controller.dart';

class Controller extends ChangeNotifier implements PlayerController {
  @override
  bool shuffleEnabled = false;
  int toggles = 0;
  @override
  void toggleShuffle() {
    toggles++;
    shuffleEnabled = !shuffleEnabled;
    notifyListeners();
  }

  @override
  bool hasFile = false, isPlaying = false, playbackPreparing = false;
  @override
  bool canGoNext = false, canGoPrev = false;
  @override
  double position = 0, duration = 0;
  @override
  String fileName = '';
  @override
  int queueIdx = -1, subsongIdx = 0;
  @override
  List<QueueEntry> queue = [];
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets(
      'system shuffle commands change the shared queue mode idempotently',
      (tester) async {
    final controller = Controller();
    final handler = RewampAudioHandler(controller);
    expect(handler.playbackState.value.systemActions,
        contains(MediaAction.setShuffleMode));
    expect(
        handler.playbackState.value.shuffleMode, AudioServiceShuffleMode.none);

    await handler.setShuffleMode(AudioServiceShuffleMode.all);
    expect(controller.shuffleEnabled, true);
    expect(controller.toggles, 1);
    expect(
        handler.playbackState.value.shuffleMode, AudioServiceShuffleMode.all);
    await handler.setShuffleMode(AudioServiceShuffleMode.all);
    expect(controller.toggles, 1);

    await handler.setShuffleMode(AudioServiceShuffleMode.none);
    expect(controller.shuffleEnabled, false);
    expect(
        handler.playbackState.value.shuffleMode, AudioServiceShuffleMode.none);
    expect(controller.toggles, 2);
    // A phone-side change must update the system indicator too.
    controller.toggleShuffle();
    expect(
        handler.playbackState.value.shuffleMode, AudioServiceShuffleMode.all);
    await tester.pump(const Duration(milliseconds: 250));
    controller.dispose();
  });
}
