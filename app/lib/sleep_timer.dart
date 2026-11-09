// Mode veille (minuterie de sommeil): au bout de la durée choisie, le son
// s'éteint en fondu puis la lecture se met en PAUSE.
//
// Ce fichier porte l'ÉTAT (un singleton, jamais persisté: une minuterie qui
// survivrait à un redémarrage couperait une écoute que personne n'a armée) et
// les DÉCISIONS, pures et testées. Les gestes eux-mêmes — remplir la file,
// lancer, mettre en pause, poser le gain — appartiennent à la coquille et au
// contrôleur, qui s'y branchent par les rappels ci-dessous (la file est à
// AppShell, le volume à PlayerController: on ne les court-circuite pas).
//
// Trois règles:
//   * l'échéance est une HEURE MURALE, pas un compte de ticks: les minuteurs
//     Dart ne tournent pas pendant une suspension, et une app réveillée après
//     l'échéance doit mettre en pause tout de suite (`check` au retour);
//   * le fondu est un GAIN À PART, multiplié par le contrôleur avec celui du
//     fondu de boucle forcée — l'un n'écrase jamais l'autre;
//   * annuler, même en plein fondu, rend le volume TOUT DE SUITE.
import 'dart:async';

import 'package:flutter/foundation.dart';

/// Les durées proposées, en minutes.
const List<int> kSleepTimerMinutes = [15, 30, 45, 60, 90, 120];

/// Le fondu final: le son descend sur les 30 dernières secondes.
const Duration kSleepFadeDuration = Duration(seconds: 30);

/// Le gain à appliquer quand il reste [remaining]. Courbe QUADRATIQUE: une
/// rampe linéaire d'amplitude s'entend comme un palier puis une chute brutale
/// à la fin, le carré suit mieux l'oreille.
double sleepFadeGain(Duration remaining,
    {Duration fade = kSleepFadeDuration}) {
  if (fade <= Duration.zero) return remaining > Duration.zero ? 1.0 : 0.0;
  if (remaining >= fade) return 1.0;
  if (remaining <= Duration.zero) return 0.0;
  final x = remaining.inMicroseconds / fade.inMicroseconds;
  return x * x;
}

enum SleepRemainingUnit { minutes, seconds }

/// Ce que le bouton affiche: des minutes (arrondies AU-DESSUS — « 1 min »
/// tant qu'il en reste une entamée), puis les secondes de la dernière minute.
/// Rend l'unité et le nombre; le texte vient de l'ARB (jamais un nom injecté).
({SleepRemainingUnit unit, int count}) sleepRemainingParts(Duration remaining) {
  final ms = remaining.inMilliseconds;
  if (ms <= 0) return (unit: SleepRemainingUnit.seconds, count: 0);
  if (ms > 60000) {
    return (unit: SleepRemainingUnit.minutes, count: (ms + 59999) ~/ 60000);
  }
  return (unit: SleepRemainingUnit.seconds, count: (ms + 999) ~/ 1000);
}

/// « La file a-t-elle une suite ? » — sinon la musique s'arrêterait avant la
/// minuterie. Radio/station: elle se remplit seule. Repeat (file OU morceau,
/// [loopMode] ≠ 0): elle ne finit pas. Sinon il faut une piste APRÈS celle en
/// cours.
bool sleepQueueFilled({
  required int queueLength,
  required int currentIndex,
  required int loopMode,
  required bool radioActive,
}) {
  if (radioActive) return true;
  if (queueLength == 0) return false;
  if (loopMode != 0) return true;
  return currentIndex >= 0 && currentIndex < queueLength - 1;
}

enum SleepStartAction {
  /// Rien à faire sur la file (elle a une suite, ou le ∞ est déjà allumé).
  none,

  /// Allumer le ∞: c'est lui qui prolongera la file.
  enableAutoplay,

  /// File VIDE: le ∞ n'a rien sur quoi se greffer, on part des écoutes
  /// récentes (et on allume le ∞ pour la suite).
  startFromRecent,
}

SleepStartAction sleepStartAction({
  required int queueLength,
  required int currentIndex,
  required int loopMode,
  required bool radioActive,
  required bool autoplayOn,
  required bool isPlaying,
}) {
  if (radioActive) return SleepStartAction.none;
  // Quelque chose joue hors file (cas marginal): on ne le remplace pas.
  if (queueLength == 0) {
    return isPlaying ? SleepStartAction.none : SleepStartAction.startFromRecent;
  }
  if (sleepQueueFilled(
      queueLength: queueLength,
      currentIndex: currentIndex,
      loopMode: loopMode,
      radioActive: radioActive)) {
    return SleepStartAction.none;
  }
  return autoplayOn ? SleepStartAction.none : SleepStartAction.enableAutoplay;
}

class SleepTimer extends ChangeNotifier {
  SleepTimer._();
  static final SleepTimer instance = SleepTimer._();

  /// Posé par la coquille: remplir/lancer selon [sleepStartAction].
  Future<void> Function()? onStart;

  /// Posé par la coquille: mettre en pause et l'annoncer.
  void Function()? onExpire;

  /// Posé par la coquille: transmet le gain de veille au contrôleur.
  void Function(double gain)? onGain;

  /// Horloge injectable (tests).
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  DateTime? _deadline;
  Duration? _chosen;
  Timer? _timer;
  double _gain = 1.0;
  ({SleepRemainingUnit unit, int count})? _shown;

  bool get active => _deadline != null;

  /// La durée choisie au dernier armement (pour cocher la ligne de la feuille).
  Duration? get chosen => _chosen;

  Duration get remaining {
    final d = _deadline;
    if (d == null) return Duration.zero;
    final r = d.difference(clock());
    return r.isNegative ? Duration.zero : r;
  }

  /// Arme (ou RE-arme: choisir une autre durée repart de zéro).
  void start(Duration duration) {
    _deadline = clock().add(duration);
    _chosen = duration;
    _setGain(1.0);      // un fondu en cours est abandonné
    _shown = sleepRemainingParts(remaining);
    _schedule();
    notifyListeners();
    final f = onStart;
    if (f != null) unawaited(f());
  }

  void cancel() {
    if (!active) return;
    _clear();
    _setGain(1.0);
    notifyListeners();
  }

  /// Appelé par le minuteur ET au retour au premier plan: une app suspendue
  /// au-delà de l'échéance met en pause dès qu'elle se réveille.
  void check() {
    if (!active) return;
    final rem = remaining;
    if (rem <= Duration.zero) {
      _expire();
      return;
    }
    _setGain(sleepFadeGain(rem));
    final parts = sleepRemainingParts(rem);
    if (parts != _shown) {
      _shown = parts;
      notifyListeners();
    }
    _schedule();
  }

  void _expire() {
    _clear();
    onExpire?.call();
    // Le volume revient APRÈS la pause et son fondu anti-clic de 12 ms, sinon
    // la queue de la pause remonterait d'un coup. Pas si on a ré-armé entre
    // temps (le nouvel armement a déjà rendu le gain).
    Timer(const Duration(milliseconds: 150), () {
      if (!active) _setGain(1.0);
    });
    notifyListeners();
  }

  void _clear() {
    _timer?.cancel();
    _timer = null;
    _deadline = null;
    _chosen = null;
    _shown = null;
  }

  /// Une seconde hors fondu (l'affichage ne bouge qu'à la minute ou à la
  /// seconde), 200 ms pendant le fondu pour une rampe sans paliers audibles.
  void _schedule() {
    _timer?.cancel();
    final rem = remaining;
    final Duration next;
    if (rem <= kSleepFadeDuration) {
      next = const Duration(milliseconds: 200);
    } else {
      final toFade = rem - kSleepFadeDuration;
      next = toFade < const Duration(seconds: 1)
          ? toFade
          : const Duration(seconds: 1);
    }
    _timer = Timer(next, check);
  }

  void _setGain(double g) {
    if (g == _gain) return;
    _gain = g;
    onGain?.call(g);
  }
}
