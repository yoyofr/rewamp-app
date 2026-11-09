import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/sleep_timer.dart';

void main() {
  group('sleepRemainingParts', () {
    test('minutes arrondies au-dessus tant qu’il reste plus d’une minute', () {
      expect(sleepRemainingParts(const Duration(minutes: 23)),
          (unit: SleepRemainingUnit.minutes, count: 23));
      expect(sleepRemainingParts(const Duration(minutes: 22, seconds: 1)),
          (unit: SleepRemainingUnit.minutes, count: 23));
      expect(sleepRemainingParts(const Duration(seconds: 61)),
          (unit: SleepRemainingUnit.minutes, count: 2));
    });
    test('la dernière minute se compte en secondes', () {
      expect(sleepRemainingParts(const Duration(seconds: 60)),
          (unit: SleepRemainingUnit.seconds, count: 60));
      expect(sleepRemainingParts(const Duration(milliseconds: 1500)),
          (unit: SleepRemainingUnit.seconds, count: 2));
      expect(sleepRemainingParts(Duration.zero),
          (unit: SleepRemainingUnit.seconds, count: 0));
      expect(sleepRemainingParts(const Duration(seconds: -3)),
          (unit: SleepRemainingUnit.seconds, count: 0));
    });
  });

  group('sleepFadeGain', () {
    test('plein volume avant le fondu, zéro à l’échéance', () {
      expect(sleepFadeGain(const Duration(minutes: 5)), 1.0);
      expect(sleepFadeGain(kSleepFadeDuration), 1.0);
      expect(sleepFadeGain(Duration.zero), 0.0);
      expect(sleepFadeGain(const Duration(seconds: -1)), 0.0);
    });
    test('courbe quadratique, monotone', () {
      expect(sleepFadeGain(const Duration(seconds: 15)), closeTo(0.25, 1e-9));
      var prev = 0.0;
      for (var s = 1; s <= 30; s++) {
        final g = sleepFadeGain(Duration(seconds: s));
        expect(g, greaterThan(prev));
        prev = g;
      }
    });
  });

  group('sleepQueueFilled / sleepStartAction', () {
    SleepStartAction act({
      int len = 3,
      int idx = 0,
      int loop = 0,
      bool radio = false,
      bool autoplay = false,
      bool playing = true,
    }) =>
        sleepStartAction(
            queueLength: len,
            currentIndex: idx,
            loopMode: loop,
            radioActive: radio,
            autoplayOn: autoplay,
            isPlaying: playing);

    test('une suite après la piste en cours = file remplie', () {
      expect(
          sleepQueueFilled(
              queueLength: 3, currentIndex: 1, loopMode: 0, radioActive: false),
          isTrue);
      expect(act(idx: 1), SleepStartAction.none);
    });
    test('dernière piste sans repeat ⇒ allumer le ∞', () {
      expect(
          sleepQueueFilled(
              queueLength: 3, currentIndex: 2, loopMode: 0, radioActive: false),
          isFalse);
      expect(act(idx: 2), SleepStartAction.enableAutoplay);
      expect(act(idx: 2, autoplay: true), SleepStartAction.none);
    });
    test('repeat (file ou morceau) et radio: la musique ne finit pas', () {
      expect(act(idx: 2, loop: 1), SleepStartAction.none);
      expect(act(idx: 2, loop: 2), SleepStartAction.none);
      expect(act(idx: 2, radio: true), SleepStartAction.none);
    });
    test('file vide ⇒ départ des écoutes récentes, ∞ allumé ou non', () {
      expect(act(len: 0, idx: -1, playing: false),
          SleepStartAction.startFromRecent);
      expect(act(len: 0, idx: -1, playing: false, autoplay: true),
          SleepStartAction.startFromRecent);
      // Quelque chose joue hors file: on ne le remplace pas.
      expect(act(len: 0, idx: -1, playing: true), SleepStartAction.none);
    });
  });

  group('SleepTimer', () {
    test('échéance murale, fondu composé, pause puis gain rendu', () async {
      final t = SleepTimer.instance;
      var now = DateTime(2026, 11, 8, 23);
      t.clock = () => now;
      final gains = <double>[];
      var expired = 0;
      t.onGain = gains.add;
      t.onExpire = () => expired++;
      t.start(const Duration(minutes: 15));
      expect(t.active, isTrue);
      expect(t.chosen, const Duration(minutes: 15));

      now = now.add(const Duration(minutes: 14, seconds: 45));
      t.check();
      expect(gains.last, closeTo(0.25, 1e-9));

      // Suspendue au-delà de l'échéance: le réveil met en pause.
      now = now.add(const Duration(minutes: 5));
      t.check();
      expect(expired, 1);
      expect(t.active, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(gains.last, 1.0);

      // Annuler en plein fondu rend le volume tout de suite.
      t.start(const Duration(minutes: 15));
      now = now.add(const Duration(minutes: 14, seconds: 50));
      t.check();
      expect(gains.last, lessThan(1.0));
      t.cancel();
      expect(gains.last, 1.0);
      expect(t.active, isFalse);
      t
        ..onGain = null
        ..onExpire = null;
    });
  });
}
