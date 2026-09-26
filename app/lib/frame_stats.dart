// Statistiques d'IMAGES Flutter et de blocages de l'isolate UI, activées par
// REWAMP_VIZ_STATS=1 — le pendant Dart de src/linux/rewamp_viz_stats.cc.
//
// Ce que le natif ne voit pas: nos stats de viz mesurent la cadence à laquelle
// le fil principal APPELLE le rendu et celle à laquelle Flutter CONSOMME la
// texture, mais pas ce que Flutter fait ENTRE les deux. Sur le Steam Deck en
// mode bureau (2026-09-26), rendu et populate tenaient 16,7 ms en médiane avec
// des trous réguliers de 66,7 ms — exactement QUATRE périodes de vsync — alors
// que notre rendu coûtait 0,5 ms, la barrière GPU 0,01 ms et l'audio rien.
// Trois suspects restaient, et seule cette mesure les sépare:
//
//   build   — le fil UI met trop longtemps à construire une image (Dart);
//   raster  — le fil de rastérisation met trop longtemps à la dessiner (GPU,
//             flous du chrome en verre, textures);
//   blocage — quelque chose tient le fil UI hors d'une image (un appel
//             synchrone: D-Bus, base, fichier), et le vsync passe sans nous.
//
// Toutes les 5 s: images, p50/p95/max du build, du raster et du total, le
// nombre d'images au-delà de 25 ms, les blocages de la boucle d'événements
// (sonde de 4 ms) et le pire tick du contrôleur. Inerte sans la variable.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/scheduler.dart';

class FrameStats {
  FrameStats._();
  static final FrameStats instance = FrameStats._();

  static bool get enabled =>
      Platform.environment.containsKey('REWAMP_VIZ_STATS');

  final _build = <double>[], _raster = <double>[], _total = <double>[];
  final _stalls = <double>[];
  double _worstTick = 0;
  int _slowBuild = 0, _slowRaster = 0;
  Timer? _probe, _report;
  Stopwatch? _probeWatch;
  bool _started = false;

  void start() {
    if (_started || !enabled) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    // Sonde de blocage: un timer de 4 ms qui mesure son propre retard. Un
    // retard de 30 ms, c'est le fil UI tenu 30 ms par quelque chose qui n'est
    // pas une image — sinon le build l'aurait compté.
    _probeWatch = Stopwatch()..start();
    _probe = Timer.periodic(const Duration(milliseconds: 4), (_) {
      final late = _probeWatch!.elapsedMicroseconds / 1000.0 - 4;
      _probeWatch!.reset();
      if (late > 25) _stalls.add(late);
    });
    _report = Timer.periodic(const Duration(seconds: 5), (_) => _flush());
  }

  /// Durée du tick de 250 ms du contrôleur (AppShell): le pire par fenêtre.
  void noteTick(double ms) {
    if (ms > _worstTick) _worstTick = ms;
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final b = t.buildDuration.inMicroseconds / 1000.0;
      final r = t.rasterDuration.inMicroseconds / 1000.0;
      final s = t.totalSpan.inMicroseconds / 1000.0;
      _build.add(b);
      _raster.add(r);
      _total.add(s);
      if (b > 25) _slowBuild++;
      if (r > 25) _slowRaster++;
    }
  }

  static String _pct(List<double> v) {
    if (v.isEmpty) return '-';
    final s = List<double>.of(v)..sort();
    String f(double x) => x.toStringAsFixed(1);
    return 'p50 ${f(s[s.length ~/ 2])}  p95 ${f(s[(s.length * 95) ~/ 100])}  '
        'max ${f(s.last)}';
  }

  void _flush() {
    final n = _total.length;
    // ignore: avoid_print
    print('[frame-stats] $n images en 5 s | build ${_pct(_build)} ms '
        '(${_slowBuild} > 25 ms) | raster ${_pct(_raster)} ms '
        '(${_slowRaster} > 25 ms) | total ${_pct(_total)} ms | '
        'blocages UI > 25 ms: ${_stalls.length}'
        '${_stalls.isEmpty ? '' : ' (${_pct(_stalls)} ms)'} | '
        'pire tick ${_worstTick.toStringAsFixed(1)} ms');
    _build.clear();
    _raster.clear();
    _total.clear();
    _stalls.clear();
    _slowBuild = _slowRaster = 0;
    _worstTick = 0;
  }

  void dispose() {
    _probe?.cancel();
    _report?.cancel();
  }
}
