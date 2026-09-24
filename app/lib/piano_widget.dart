import 'dart:async' show Timer;
import 'dart:ffi' hide Size;  // tampon d'entiers réutilisé; Size vient du framework
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:ffi/ffi.dart' show calloc;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rewamp_audio/rewamp_audio.dart';

import 'l10n.dart';
import 'user_settings.dart';
import 'viz_gl_ownership.dart';
import 'viz_platform_view.dart';

/// Piano visualizer — viz mode 6, rendered by the C engine
/// (rewamp_piano_render.cpp): one keyboard per voice, or the coming notes
/// falling onto one keyboard (the Synthesia look). Same display plumbing as
/// the other GL visualizers: Android = SurfaceView PlatformView, iOS/macOS =
/// Flutter Texture driven by a Ticker. No CPU fallback — the selector only
/// offers this mode where the GL path exists.
///
/// Gestures, mirrored from the notation but on the HORIZONTAL axis (the
/// keyboard scrolls sideways): one-finger horizontal drag = pan, pinch = zoom,
/// right-button drag / wheel = zoom on desktop. Any of them switches the
/// renderer to MANUAL and surfaces the AUTO button.
///
/// ⚠️ A horizontal drag over this viz is therefore NOT the player's skip-track
/// swipe any more — the recognizer below claims it. That is the requested
/// behaviour: the keyboard is what the finger moves here.
class PianoWidget extends StatefulWidget {
  final RewampAudio audio;
  final double height;
  final bool fillHeight;

  const PianoWidget({
    super.key,
    required this.audio,
    this.height     = 160,
    this.fillHeight = false,
  });

  @override
  State<PianoWidget> createState() => _PianoWidgetState();
}

/// Horizontal drag that BOWS OUT the moment a second finger touches down —
/// same construction as the notation's vertical one (see
/// notes_scope_widget.dart for the arena pitfalls it works around): the pan
/// and the pinch share one RawGestureDetector, and a drag recognizer that wins
/// the first pointer locks the scale recognizer out for good.
class _HPanUnlessPinch extends HorizontalDragGestureRecognizer {
  final int Function() pointerCount;
  _HPanUnlessPinch({required this.pointerCount});

  Offset?  _origin;
  Duration _downAt = Duration.zero;
  static const double   _kClaimSlop  = 6.0;
  static const Duration _kPinchGrace = Duration(milliseconds: 90);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (pointerCount() >= 1) {
      resolve(GestureDisposition.rejected);
      return;
    }
    _origin = event.position;
    _downAt = event.timeStamp;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) _origin = null;
    // Claim as soon as the horizontal component dominates — after the pinch
    // grace, so a second finger landing a beat later still gets the arena.
    if (event is PointerMoveEvent &&
        pointerCount() <= 1 &&
        _origin != null &&
        event.timeStamp - _downAt > _kPinchGrace) {
      final d = event.position - _origin!;
      if (d.dx.abs() > _kClaimSlop && d.dx.abs() > d.dy.abs()) {
        resolve(GestureDisposition.accepted);
      }
    }
    super.handleEvent(event);
  }

  @override
  void dispose() {
    _origin = null;
    super.dispose();
  }
}

class _PianoWidgetState extends State<PianoWidget>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int  _gpuTextureId = -1;
  Size _gpuSize      = Size.zero;

  // View bounds, in white-key units (see rewamp_piano_render.cpp).
  static const double _kWhites  = 75.0;
  static const double _kSpanMin = 7.0;

  // Légende du bas: noms lus à cadence lente (un appel FFI + décodage par
  // entrée). En mode « par voix » ce sont les voix; en mode « par instrument »
  // ce sont les INSTRUMENTS qui jouent en ce moment — et ceux-là changent en
  // cours de morceau, d'où la même cadence pour les deux.
  List<String> _names = const [];
  List<int> _legendColors = const [];
  int _nameTick = 0;
  // Détection bon marché d'un changement d'instrument: un appel FFI groupé
  // rend les N voies, la comparaison porte sur des entiers. Les NOMS, eux,
  // sortent du cache de RewampAudio.
  Pointer<Int32>? _instrBuf;
  List<int> _lastInstr = const [];
  /// Autant d'entrées que la légende peut raisonnablement porter.
  static const int _kMaxLegend = 64;
  /// Passé gardé dans la fenêtre: une barre déjà entamée est encore à l'écran.
  static const double _kLegendPastSecs = 0.35;
  /// Temps MINIMUM d'affichage d'un jeu de libellés. En mode claviers la
  /// légende ne montre que l'instant, et sur un motif rapide elle clignoterait
  /// sans qu'on puisse rien lire. La liste visible continue d'être relue
  /// pendant le maintien: à son expiration, on affiche l'état courant.
  static const int _kLabelHoldMs = 1000;
  int _labelHoldUntilMs = 0;
  bool _instrDirty = false;

  bool _manual = false;      // mirrors the C-side flag (survives viz switches)
  double _w = 1;             // surface width px (gesture → key-units mapping)
  double _pinchLo = 0, _pinchSpan = 0, _pinchF0 = 0;
  bool _autoBtnVisible = false;
  Timer? _autoBtnTimer;
  bool _rzoomActive = false;
  int _pointers = 0;
  double _rzoomX0 = 0, _rzoomLo = 0, _rzoomSpan = 0, _rzoomF0 = 0;

  @override
  void initState() {
    super.initState();
    // L'avance de décodage est décidée par le MODE (voir _applySettings) —
    // posée ici explicitement, pour qu'en venant du viz-pattern on ne garde
    // pas son avance plus grande. Relâchée par le sélecteur quand un effet
    // sans avance prend la main.
    _applySettings();
    UserSettings.instance.addListener(_applySettings);
    _manual = widget.audio.pianovizIsManual;
    if (_manual) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pokeAutoBtn());
    }
    _ticker = createTicker(_onTick)..start();
  }

  /// The keys follow the notation's voice palette — push it too: the user may
  /// open the piano without ever having opened the notation this session.
  void _applySettings() {
    // Un réglage a changé: l'image doit suivre même à l'arrêt.
    widget.audio.vizWake();
    final s = UserSettings.instance;
    widget.audio.setNotePalette(s.notePalette);
    widget.audio.setPianoOptions(
        s.pianoMode, s.pianoColorMode, s.pianoGlow, s.pianoLighting);
    // Seul le mode « chute » montre du FUTUR (1,5 s de barres, PK_FUTURE_S):
    // lui demande 2 s d'avance au décodeur. Le mode claviers n'enfonce que les
    // touches de l'instant: à l'avance minimale (200 ms), couper ou rallumer
    // une voix s'ENTEND presque aussitôt au lieu de deux secondes plus tard —
    // le rendu, lui, lit le masque au moment du dessin et réagit tout de suite.
    widget.audio.setLookaheadSeconds(s.pianoMode == 1 ? 2.0 : 0.0);
    if (mounted) _refreshNames();   // the toggle, or a palette change
  }

  /// Bottom strip: one chip per voice — a square in the voice's colour (the
  /// notation palette, exactly what the C side draws) and its name. At the
  /// BOTTOM so it does not move with the zoom/pan of the keyboard above.
  Widget _voiceLegend() {
    final s = UserSettings.instance;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          color: Colors.black.withValues(alpha: 0.55),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 7,
            runSpacing: 1,
            children: [
              for (var v = 0; v < _names.length; v++)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      color: Color(v < _legendColors.length
                          ? _legendColors[v]
                          : s.noteVoiceColor(v)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(_names[v],
                      style: const TextStyle(
                          fontSize: 8, color: Colors.white, height: 1.1)),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  /// Les instruments VISIBLES à l'écran, datés: la légende doit nommer ce
  /// qu'on voit, et en mode chute l'écran montre du futur (les barres tombent
  /// pendant `pianoFutureSeconds`). Un peu de passé aussi, pour les barres qui
  /// n'ont pas fini de traverser le clavier.
  List<int> _visibleInstruments() {
    final buf = _instrBuf ??= calloc<Int32>(_kMaxLegend);
    final n = widget.audio.instrumentsInWindowInto(
        buf, _kMaxLegend, -_kLegendPastSecs, widget.audio.pianoFutureSeconds);
    if (n <= 0) return const [];
    return [for (var i = 0; i < n; i++) buf[i]];
  }

  /// Vrai si l'ensemble des instruments visibles a changé. La comparaison est
  /// sur des ENTIERS, et la liste est déjà triée par le natif — assez bon
  /// marché pour tourner à chaque image, là où relire les noms ne l'est pas.
  bool _instrumentsChanged() {
    final next = _visibleInstruments();
    if (next.length != _lastInstr.length) { _lastInstr = next; return true; }
    for (var i = 0; i < next.length; i++) {
      if (next[i] != _lastInstr[i]) { _lastInstr = next; return true; }
    }
    return false;
  }

  /// Vrai quand les instruments visibles ont changé ET que la légende
  /// précédente a été affichée assez longtemps pour être lue.
  bool _instrHoldElapsed() {
    final s = UserSettings.instance;
    if (!s.pianoVoiceNames || s.pianoColorMode != 1) return false;
    if (_instrumentsChanged()) _instrDirty = true;
    if (!_instrDirty) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < _labelHoldUntilMs) return false;
    _instrDirty = false;
    _labelHoldUntilMs = now + _kLabelHoldMs;
    return true;
  }

  void _refreshNames() {
    final s = UserSettings.instance;
    if (!s.pianoVoiceNames) {
      if (_names.isNotEmpty) {
        setState(() { _names = const []; _legendColors = const []; });
      }
      return;
    }
    final count = widget.audio.voiceCountRaw;
    List<String> next;
    List<int> cols;
    if (s.pianoColorMode == 0) {
      next = [for (var v = 0; v < count; v++) widget.audio.voiceName(v)];
      cols = [for (var v = 0; v < count; v++) s.noteVoiceColor(v)];
    } else {
      // Par instrument: la légende ne peut plus nommer les voies (plusieurs
      // peuvent partager un instrument, et une voix en change en cours de
      // route). Elle liste les instruments qui JOUENT, dédoublonnés, dans
      // l'ordre de leur numéro — le moteur donne leur nom quand il en a un
      // (SoundFont, échantillons d'un module), sinon « Inst n ».
      // Tous les instruments VISIBLES (le futur des barres compris), datés par
      // la timeline. Repli sur l'instant si le binaire ne connaît pas l'export.
      var list = _visibleInstruments();
      if (list.isEmpty) {
        final seen = <int>{};
        for (var v = 0; v < count; v++) {
          final i = widget.audio.voiceInstrument(v);
          if (i > 0) seen.add(i);
        }
        list = seen.toList()..sort();
      }
      next = [for (final i in list) widget.audio.instrumentName(i)];
      cols = [for (final i in list) s.noteInstrumentColor(i)];
    }
    if (next.length != _names.length ||
        cols.length != _legendColors.length ||
        !Iterable<int>.generate(next.length).every((i) => next[i] == _names[i]) ||
        !Iterable<int>.generate(cols.length).every((i) => cols[i] == _legendColors[i])) {
      setState(() { _names = next; _legendColors = cols; });
    }
  }

  void _onTick(Duration elapsed) {
    // Slow cadence, on the Texture AND the Android PlatformView path (the
    // legend is Flutter-drawn either way).
    // Légende « par instrument »: elle doit suivre un changement d'instrument
    // sans attendre la cadence lente — la détection ne coûte qu'un appel FFI
    // groupé et une comparaison d'entiers.
    // ⚠️ RIEN de tout ça en veille (pause, et la grâce écoulée): la timeline ne
    // bouge plus, donc ni les instruments visibles ni les noms — balayer 2 048
    // colonnes et allouer une liste à chaque image serait du processeur brûlé
    // pour une image identique (règle de src/rewamp_viz_idle.h).
    if (widget.audio.vizShouldRender) {
      if (_instrHoldElapsed()) {
        _nameTick = 0;
        _refreshNames();
      } else if (!_instrDirty && ++_nameTick % 30 == 0) {
        // Même garde que l'oscilloscope: le filet lent ne publie pas un libellé
        // que le maintien retient encore.
        _refreshNames();
      }
    }
    if (_gpuTextureId < 0) return;
    // Lecteur en pause et rien qui bouge: on ne redessine pas (voir
    // src/rewamp_viz_idle.h). Le réveil vient du `build` et des gestes.
    if (!widget.audio.vizFrameDue) return;

    // L'horloge de frame AVANT le rendu: le playhead lissé et l'animation des
    // touches (rewamp_notes_played_smooth, nv_now) lisent
    // rewamp_viz_frame_time(). Sans elle, la valeur reste celle posée par le
    // dernier viz qui l'a écrite: dt = 0, rien ne bouge, et le clavier ne
    // « saute » qu'aux snaps du callback audio — l'effet « 1 image/s ».
    widget.audio.vizSetFrameTime(elapsed.inMicroseconds / 1e6);
    widget.audio.pianovizRenderAndNotify();
  }

  // ── Manual view: drag = pan, pinch = zoom ───────────────────────────────
  void _pokeAutoBtn() {
    if (!_manual) return;
    if (!_autoBtnVisible && mounted) setState(() => _autoBtnVisible = true);
    _autoBtnTimer?.cancel();
    _autoBtnTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _autoBtnVisible = false);
    });
  }

  void _enterManual() {
    if (!_manual && mounted) setState(() => _manual = true);
    _pokeAutoBtn();
  }

  void _setView(double lo, double span) {
    span = span.clamp(_kSpanMin, _kWhites);
    lo = lo.clamp(0.0, _kWhites - span);
    widget.audio.pianovizSetView(lo, span);
    // Un geste de vue ne reconstruit pas forcément le widget: réveiller ici,
    // sinon zoomer ou déplacer en PAUSE ne redessinerait rien (voir
    // src/rewamp_viz_idle.h).
    widget.audio.vizWake();
    _enterManual();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final lo = widget.audio.pianovizViewLo, span = widget.audio.pianovizViewSpan;
    // The keyboard follows the finger: dragging right shows lower keys.
    _setView(lo - d.delta.dx / _w * span, span);
  }

  void _onScaleStart(ScaleStartDetails d) {
    _pinchLo   = widget.audio.pianovizViewLo;
    _pinchSpan = widget.audio.pianovizViewSpan;
    _pinchF0   = d.localFocalPoint.dx / _w;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount < 2) return;   // 1-finger pan is the drag recognizer's
    final span = (_pinchSpan / d.scale.clamp(0.05, 20.0)).clamp(_kSpanMin, _kWhites);
    // Keep the key under the gesture-start focal point anchored there.
    final key0 = _pinchLo + _pinchF0 * _pinchSpan;
    final f1 = d.localFocalPoint.dx / _w;
    _setView(key0 - f1 * span, span);
  }

  void _resetAuto() {
    widget.audio.pianovizSetAuto();
    _autoBtnTimer?.cancel();
    setState(() { _manual = false; _autoBtnVisible = false; });
  }

  /// Zoom by [factor] (>1 = zoom in) keeping the key at width-fraction
  /// [anchorF] fixed. Base view: [lo0, span0].
  void _zoomAround(double lo0, double span0, double anchorF, double factor) {
    final span = (span0 / factor).clamp(_kSpanMin, _kWhites);
    final key0 = lo0 + anchorF * span0;
    _setView(key0 - anchorF * span, span);
  }

  void _onPointerDown(PointerDownEvent e) {
    _pokeAutoBtn();
    if (e.kind == PointerDeviceKind.mouse &&
        (e.buttons & kSecondaryMouseButton) != 0) {
      _rzoomActive = true;
      _rzoomX0   = e.localPosition.dy;
      _rzoomLo   = widget.audio.pianovizViewLo;
      _rzoomSpan = widget.audio.pianovizViewSpan;
      _rzoomF0   = e.localPosition.dx / _w;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_rzoomActive) return;
    if ((e.buttons & kSecondaryMouseButton) == 0) { _rzoomActive = false; return; }
    // Right-button drag UP = zoom in; 150 px = one doubling.
    final dy = e.localPosition.dy - _rzoomX0;
    _zoomAround(_rzoomLo, _rzoomSpan, _rzoomF0, math.pow(2.0, -dy / 150.0).toDouble());
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      _zoomAround(
        widget.audio.pianovizViewLo,
        widget.audio.pianovizViewSpan,
        e.localPosition.dx / _w,
        math.pow(2.0, -e.scrollDelta.dy / 400.0).toDouble(),
      );
    }
  }

  Widget _wrapGestures(Widget child) {
    return LayoutBuilder(builder: (ctx, cons) {
      if (cons.maxWidth > 0) _w = cons.maxWidth;
      return Stack(fit: StackFit.expand, children: [
        // The viz BELOW the gesture layer: a sibling on top, never a parent —
        // an Android PlatformView takes the touches first otherwise.
        child,
        Listener(
          onPointerDown:   (e) { _pointers++; _onPointerDown(e); },
          onPointerMove:   _onPointerMove,
          onPointerUp:     (_) { if (_pointers > 0) _pointers--; _rzoomActive = false; },
          onPointerCancel: (_) { if (_pointers > 0) _pointers--; _rzoomActive = false; },
          onPointerSignal: _onPointerSignal,
          child: MouseRegion(
            onHover: (_) => _pokeAutoBtn(),
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                _HPanUnlessPinch: GestureRecognizerFactoryWithHandlers<
                    _HPanUnlessPinch>(
                  () => _HPanUnlessPinch(pointerCount: () => _pointers),
                  (r) => r.onUpdate = _onPanUpdate,
                ),
                ScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                    ScaleGestureRecognizer>(
                  () => ScaleGestureRecognizer(),
                  (r) => r
                    ..onStart = _onScaleStart
                    ..onUpdate = _onScaleUpdate,
                ),
              },
              child: const SizedBox.expand(),
            ),
          ),
        ),
        if (_names.isNotEmpty) _voiceLegend(),
        if (_manual)
          Positioned(
            // Top-LEFT, UNDER this viz's own controls (look / colours /
            // sparkles: an 8 px padding + a 34 px row of icon buttons, laid
            // out by VizSelectorWidget._pianoControls). Both appear on touch,
            // so they read as one group; a button on the right looked lost.
            top: 8 + 34 + 6, left: 8,
            child: AnimatedOpacity(
              opacity: _autoBtnVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_autoBtnVisible,
                child: Material(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _resetAuto,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.center_focus_strong,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(ctx.l10n.vizRangeAuto,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]);
    });
  }

  void _initGpu(Size size) {
    if (size == _gpuSize && _gpuTextureId >= 0) return;
    if (_gpuTextureId >= 0) {
      widget.audio.vizResizeRegister(size.width.toInt(), size.height.toInt());
      _gpuSize = size;
      return;
    }
    final id =
        widget.audio.pianovizRegister(size.width.toInt(), size.height.toInt());
    if (id >= 0) setState(() { _gpuTextureId = id; _gpuSize = size; });
  }

  @override
  void dispose() {
    UserSettings.instance.removeListener(_applySettings);
    _autoBtnTimer?.cancel();
    _ticker.dispose();
    final ip = _instrBuf;
    if (ip != null) { calloc.free(ip); _instrBuf = null; }
    // Not on a visualizer SWITCH — the GL context is shared and owned by the
    // selector while it is on screen (see OscilloscopeWidget.dispose).
    if (_gpuTextureId >= 0 && !kVizGlOwnedBySelector) {
      widget.audio.vizUnregister();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb &&
        Platform.isAndroid &&
        widget.audio.vizGpuAvailable &&
        !kVizForceTextureOnAndroid) {
      return _wrapGestures(const RewampVizPlatformView(mode: 6));
    }
    return _wrapGestures(LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth.toInt();
      final h = constraints.maxHeight.toInt();
      if (w > 0 && h > 0) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _initGpu(Size(w.toDouble(), h.toDouble())));
      }
      if (_gpuTextureId >= 0) {
        return SizedBox(
          width:  double.infinity,
          height: widget.fillHeight ? double.infinity : widget.height,
          child: Texture(textureId: _gpuTextureId),
        );
      }
      return widget.fillHeight
          ? const SizedBox.expand()
          : SizedBox(width: double.infinity, height: widget.height);
    }));
  }
}
