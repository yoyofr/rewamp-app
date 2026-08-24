import 'dart:async' show Timer;
import 'dart:ffi' hide Size;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rewamp_audio/rewamp_audio.dart';

import 'viz_gl_ownership.dart';

import 'l10n.dart';
import 'user_settings.dart';
import 'viz_platform_view.dart';

/// Scrolling-notation visualizer: note blocks move right→left, vertical position
/// = pitch, color = voice index. Fed by the C look-ahead note timeline
/// (~2s ahead of playback). Rendered in the C/OpenGL backend (mode 2) on Apple;
/// falls back to a Dart CustomPaint where the GPU path is unavailable.
class NotesScopeWidget extends StatefulWidget {
  final RewampAudio audio;
  const NotesScopeWidget({super.key, required this.audio});

  @override
  State<NotesScopeWidget> createState() => _NotesScopeWidgetState();
}

/// Vertical drag that BOWS OUT the moment a second finger touches down.
///
/// The pan and the pinch live in the same RawGestureDetector, so they compete
/// for the first pointer. A plain VerticalDragGestureRecognizer wins it as soon
/// as the finger moves, which knocks the ScaleGestureRecognizer out of that
/// arena — and a recognizer that has lost cannot come back. Adding a second
/// finger then did nothing: zoom only worked again once every finger had been
/// lifted and the sequence restarted, which is exactly the "I have to wait" the
/// gesture had.
///
/// Rejecting here releases the first pointer too, so the scale recognizer —
/// which tracks both — takes over immediately. A one-finger horizontal swipe is
/// still none of our business and keeps reaching the player's skip-track drag.
class _PanUnlessPinch extends VerticalDragGestureRecognizer {
  /// Fingers already down when a new one arrives, owned by the State's
  /// Listener. It does NOT include the pointer being added: the gesture
  /// detector is a CHILD of that Listener, so the hit-test path reaches it
  /// first and the Listener has not counted the new finger yet. Hence the
  /// `>= 1` test below, not `> 1`.
  ///
  /// NOT counted inside this class: a pointer it refuses is never tracked, so
  /// that pointer's up never reaches handleEvent. An internal counter therefore
  /// never came back down — stuck at 2 after one pinch, refusing every later
  /// drag. The Listener sees every down and up unconditionally.
  final int Function() pointerCount;

  _PanUnlessPinch({required this.pointerCount});

  Offset?  _origin;
  Duration _downAt = Duration.zero;

  /// Movement (logical px) after which a clearly-vertical drag claims the
  /// gesture. Below Flutter's own touch slop on purpose — see [handleEvent].
  static const double _kClaimSlop = 6.0;

  /// Grace period before claiming anything. A pinch puts two fingers down in
  /// quick succession, never at the same instant; claiming on the first one's
  /// movement closed its arena and locked the scale recognizer out for good —
  /// which is why a pinch was harder to start on Android, where that first
  /// finger tends to travel a little before the second lands.
  static const Duration _kPinchGrace = Duration(milliseconds: 90);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    // A finger is already down ⇒ this is the second one ⇒ a pinch. Step aside
    // so the scale recognizer gets both pointers.
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
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _origin = null;
    }
    // Claim the gesture as soon as the vertical component DOMINATES, instead of
    // waiting for the stock recognizer to clear its own slop. It measures only
    // |dy| against the touch slop and never compares it with |dx|, so on a
    // slightly diagonal drag the player's horizontal skip-swipe — which is
    // racing for the same pointer — often crossed its threshold first and took
    // the gesture. Panning then required an almost perfectly vertical finger.
    // A drag that leans horizontal is deliberately left alone: that one IS the
    // skip swipe.
    if (event is PointerMoveEvent &&
        pointerCount() <= 1 &&
        _origin != null &&
        event.timeStamp - _downAt > _kPinchGrace) {
      final d = event.position - _origin!;
      if (d.dy.abs() > _kClaimSlop && d.dy.abs() > d.dx.abs()) {
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

class _NotesScopeWidgetState extends State<NotesScopeWidget>
    with SingleTickerProviderStateMixin {
  static const int _cols    = 256;
  static const int _maxV    = 64;
  static const double _ahead = 2.0;

  // GPU path.
  int  _gpuTextureId = -1;
  Size _gpuSize      = Size.zero;

  // CPU fallback.
  Pointer<Float>? _buf;
  final Float32List _grid = Float32List(_cols * _maxV);
  int _vc = 0;

  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    // The notation view shows a fixed 1.5s future window (NV_HALF in
    // rewamp_notes_render.cpp), so decode-ahead only needs that plus a small
    // margin — it does NOT scale with the surface height the way the pattern
    // grid does. Request it explicitly so switching from the pattern viz sets
    // the right lead instead of inheriting the pattern's larger one.
    widget.audio.setLookaheadSeconds(2.0);   // 1.5s window + margin
    _pushStyle();
    UserSettings.instance.addListener(_onSettings);
    if (!widget.audio.vizGpuAvailable) {
      _buf = calloc<Float>(_cols * _maxV);
    }
    // The manual flag lives C-side and survives viz switches — resync the
    // AUTO button on rebuild (shown briefly, then auto-hides).
    _manual = widget.audio.notevizIsManual;
    if (_manual) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pokeAutoBtn());
    }
    _ticker = createTicker(_onTick)..start();
  }

  void _onSettings() => _pushStyle();

  void _pushStyle() {
    widget.audio.setNotePalette(UserSettings.instance.notePalette);
    widget.audio.setNoteStyle(UserSettings.instance.noteBoxStyle ? 1 : 0);
  }

  // ── Manual vertical range: drag = pan, pinch = zoom ───────────────────────
  // Vertical-drag-only pan (axis-locked) keeps the player's horizontal
  // skip-track swipe working over the viz; the scale recognizer only acts on
  // ≥2 pointers (pinch). Any gesture switches the C renderer to manual and
  // surfaces the AUTO button; tapping it resumes auto-calibration.
  bool _manual = false;      // mirrors the C-side flag (survives viz switches)
  double _h = 1;             // surface height px (gesture → octaves mapping)
  double _pinchLo = 0, _pinchHi = 0, _pinchF0 = 0;

  // AUTO button auto-hide: shown on entering manual / touching / hovering the
  // viz, gone 3s later (same idea as the viz-choice buttons).
  bool _autoBtnVisible = false;
  Timer? _autoBtnTimer;

  // Mouse pinch alternative: RIGHT-button drag up/down = zoom (anchored at
  // the press point). Raw Listener events — drag recognizers only track the
  // primary button, so this never fights the pan gesture.
  bool _rzoomActive = false;
  /// Fingers currently down on the viz — see [_PanUnlessPinch.pointerCount].
  int _pointers = 0;
  double _rzoomY0 = 0, _rzoomLo = 0, _rzoomHi = 0, _rzoomF0 = 0;

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

  void _onPanUpdate(DragUpdateDetails d) {
    final lo = widget.audio.notevizRangeLo, hi = widget.audio.notevizRangeHi;
    final span = hi - lo;
    // Content follows the finger: dragging down shifts the window up in
    // pitch-fraction terms (pitch under the finger stays put).
    final sh = d.delta.dy / _h * span;
    widget.audio.notevizSetRange(lo + sh, hi + sh);
    _enterManual();
  }

  void _onScaleStart(ScaleStartDetails d) {
    _pinchLo = widget.audio.notevizRangeLo;
    _pinchHi = widget.audio.notevizRangeHi;
    _pinchF0 = d.localFocalPoint.dy / _h;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount < 2) return;   // 1-finger pan is the drag recognizer's
    final span0 = _pinchHi - _pinchLo;
    final span = (span0 / d.scale.clamp(0.05, 20.0)).clamp(0.5, 15.0);
    // Keep the pitch under the gesture-start focal point anchored there.
    final pitch0 = _pinchHi - _pinchF0 * span0;
    final f1 = d.localFocalPoint.dy / _h;
    final hi = pitch0 + f1 * span;
    widget.audio.notevizSetRange(hi - span, hi);
    _enterManual();
  }

  void _resetAuto() {
    widget.audio.notevizSetAuto();
    _autoBtnTimer?.cancel();
    setState(() { _manual = false; _autoBtnVisible = false; });
  }

  /// Zoom by [factor] (>1 = zoom in) keeping the pitch at height-fraction
  /// [anchorF] (from top) fixed. Base range: [lo0, hi0].
  void _zoomAround(double lo0, double hi0, double anchorF, double factor) {
    final span0 = hi0 - lo0;
    final span = (span0 / factor).clamp(0.5, 15.0);
    final pitch0 = hi0 - anchorF * span0;
    final hi = pitch0 + anchorF * span;
    widget.audio.notevizSetRange(hi - span, hi);
    _enterManual();
  }

  void _onPointerDown(PointerDownEvent e) {
    _pokeAutoBtn();
    if (e.kind == PointerDeviceKind.mouse &&
        (e.buttons & kSecondaryMouseButton) != 0) {
      _rzoomActive = true;
      _rzoomY0 = e.localPosition.dy;
      _rzoomLo = widget.audio.notevizRangeLo;
      _rzoomHi = widget.audio.notevizRangeHi;
      _rzoomF0 = e.localPosition.dy / _h;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_rzoomActive) return;
    if ((e.buttons & kSecondaryMouseButton) == 0) { _rzoomActive = false; return; }
    // Drag UP = zoom in; 150 px = one doubling.
    final dy = e.localPosition.dy - _rzoomY0;
    _zoomAround(_rzoomLo, _rzoomHi, _rzoomF0, math.pow(2.0, -dy / 150.0).toDouble());
  }

  void _onPointerSignal(PointerSignalEvent e) {
    // Scroll wheel / trackpad scroll: the other desktop zoom path.
    if (e is PointerScrollEvent) {
      _zoomAround(
        widget.audio.notevizRangeLo,
        widget.audio.notevizRangeHi,
        e.localPosition.dy / _h,
        math.pow(2.0, -e.scrollDelta.dy / 400.0).toDouble(),
      );
    }
  }

  Widget _wrapGestures(Widget child) {
    return LayoutBuilder(builder: (ctx, cons) {
      if (cons.maxHeight > 0) _h = cons.maxHeight;
      return Stack(fit: StackFit.expand, children: [
        // The viz itself, BELOW the gesture layer.
        //
        // On Android this is a hybrid-composition PlatformView (SurfaceView),
        // and a gesture detector wrapping it as a PARENT never saw the touches:
        // the native view sits in the Android hierarchy and takes them first, so
        // pinch-zoom and pan silently did nothing there while working on the
        // Flutter Texture path. A sibling painted ON TOP receives them normally
        // — the same reason the viz-selector buttons are siblings, not
        // parents.
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
              // opaque: this layer is transparent but must still be hit-tested,
              // otherwise there is nothing to hand the pointers to. Ancestors
              // (the player's horizontal skip-swipe, its double-tap) stay in the
              // arena — opaque only stops widgets BEHIND it in the Stack.
              behavior: HitTestBehavior.opaque,
              gestures: {
                _PanUnlessPinch: GestureRecognizerFactoryWithHandlers<
                    _PanUnlessPinch>(
                  () => _PanUnlessPinch(pointerCount: () => _pointers),
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
        if (_manual)
          Positioned(
            // TOP-LEFT, le coin des réglages par visualiseur (spectre et
            // patterns y mettent déjà les leurs). La notation n'a pas de
            // cluster à cet endroit, donc AUTO ne recouvre rien.
            top: 8, left: 8,
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

  void _initGpu(Size physicalSize) {
    if (!widget.audio.vizGpuAvailable) return;
    if (physicalSize == _gpuSize && _gpuTextureId >= 0) return;
    if (_gpuTextureId >= 0) {
      widget.audio.vizResizeRegister(physicalSize.width.toInt(), physicalSize.height.toInt());
      _gpuSize = physicalSize;
      return;
    }
    final id = widget.audio.notevizRegister(physicalSize.width.toInt(), physicalSize.height.toInt());
    if (id >= 0) setState(() { _gpuTextureId = id; _gpuSize = physicalSize; });
  }

  void _onTick(Duration elapsed) {
    if (widget.audio.vizGpuAvailable) {
      if (_gpuTextureId >= 0) {
        // Frame-grid timestamp → native scroll clock (kills wall-clock jitter).
        widget.audio.vizSetFrameTime(elapsed.inMicroseconds / 1e6);
        widget.audio.notevizRenderAndNotify();
      }
      return;
    }
    // CPU fallback: poll the note window and repaint.
    final buf = _buf;
    if (buf == null) return;
    final vc = widget.audio.notesWindow(buf, _cols, _ahead);
    if (vc > 0) _grid.setAll(0, buf.asTypedList(_cols * vc));
    if (mounted) setState(() => _vc = vc);
  }

  @override
  void dispose() {
    // Look-ahead release is owned by VizSelectorWidget, not cleared here:
    // switching to the pattern viz sets its own lead before this dispose runs,
    // and clearing here would clobber it (see PatternScopeWidget.dispose).
    UserSettings.instance.removeListener(_onSettings);
    _autoBtnTimer?.cancel();
    _ticker.dispose();
    // Not on a visualizer SWITCH: all four renderers share one GL context, so
    // tearing it down here made the next one rebuild it from scratch (context,
    // buffers, shaders, Metal pipeline) — the delay after tapping a viz button.
    // VizSelectorWidget owns the teardown while it is on screen.
    if (_gpuTextureId >= 0 && !kVizGlOwnedBySelector) {
      widget.audio.vizUnregister();
    }
    final p = _buf;
    if (p != null) calloc.free(p);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Android: PlatformView (SurfaceView) — native GL renders straight into a
    // SurfaceFlinger-composited surface (vsync-locked thread), bypassing
    // Flutter's Texture/ImageReader import pipeline which judders on some
    // devices. iOS/macOS keep the Flutter Texture path.
    if (!kIsWeb &&
        Platform.isAndroid &&
        widget.audio.vizGpuAvailable &&
        !kVizForceTextureOnAndroid) {
      return _wrapGestures(const RewampVizPlatformView(mode: 2));
    }
    if (widget.audio.vizGpuAvailable) {
      return _wrapGestures(LayoutBuilder(builder: (ctx, constraints) {
        final w = constraints.maxWidth.toInt();
        final h = constraints.maxHeight.toInt();
        if (w > 0 && h > 0) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _initGpu(Size(w.toDouble(), h.toDouble())));
        }
        if (_gpuTextureId >= 0) {
          return SizedBox(
            width: double.infinity, height: double.infinity,
            child: Texture(textureId: _gpuTextureId),
          );
        }
        return const SizedBox.expand();
      }));
    }
    return CustomPaint(
      painter: _NotesPainter(grid: _grid, cols: _cols, voices: _vc),
      child: const SizedBox.expand(),
    );
  }
}

class _NotesPainter extends CustomPainter {
  final Float32List grid; // column-major: grid[col*voices + v] = Hz (0 = off)
  final int cols;
  final int voices;

  const _NotesPainter({required this.grid, required this.cols, required this.voices});

  static const double _midiLo = 24;
  static const double _midiHi = 108;

  static double _hzToMidi(double hz) => 69.0 + 12.0 * (math.log(hz / 440.0) / math.ln2);

  static Color _voiceColor(int v) {
    final hue = (v * 137.508) % 360.0;
    return HSVColor.fromAHSV(1.0, hue, 0.55, 1.0).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0A0A0A));
    if (voices <= 0) return;

    final colW = size.width / cols;
    final blockH = (size.height / (_midiHi - _midiLo) * 1.6).clamp(3.0, 10.0);

    double yFor(double midi) {
      final t = ((midi - _midiLo) / (_midiHi - _midiLo)).clamp(0.0, 1.0);
      return size.height * (1.0 - t) - blockH / 2;
    }

    final paint = Paint()..style = PaintingStyle.fill;
    for (int v = 0; v < voices; v++) {
      paint.color = _voiceColor(v);
      for (int c = 0; c < cols; c++) {
        final hz = grid[c * voices + v];
        if (hz <= 1.0) continue;
        canvas.drawRect(
            Rect.fromLTWH(c * colW, yFor(_hzToMidi(hz)), colW + 1.0, blockH), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_NotesPainter old) => true;
}
