import 'dart:async' show Timer, scheduleMicrotask;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kReleaseMode, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'splash_fx_overlays.dart';

/// Native splash background — must match Runner splash (#160A1E) so the
/// native→Flutter handoff is seamless. Also the desktop window fill (no native
/// splash there).
const Color kSplashBg = Color(0xFF160A1E);

const String _kSplashAsset = 'assets/branding/splash/splash_logo.png';

/// Logo display size in LOGICAL points. Must match the native splash so the
/// handoff is seamless: iOS LaunchImage is 250/500/750px @1/2/3x with
/// contentMode=center (unscaled) → 250 pt. (Android-12 sizing is OS-controlled
/// and calibrated separately.)
const double kSplashLogoSize = 250.0;

/// Sun centre in logo UV — used to hand effects a ready-made screen-space
/// sun position (uSunPos) instead of each shader recomputing it.
const Offset kSplashSunUv = Offset(0.5, 0.38);

/// Logo-UV y split between the sun band (above) and the wordmark (below) —
/// MIRROR of kSplit in splash_common.glsl.
const double kSplashSplit = 0.582;

/// The shared end-of-intro dissolve — MIRROR of dissolveAlpha() in
/// splash_common.glsl, for the sprite half of hybrid effects.
double splashDissolveAlpha(double p) {
  final t = ((p - 0.82) / 0.18).clamp(0.0, 1.0);
  return 1.0 - t * t * (3.0 - 2.0 * t);
}

/// Everything a sprite overlay needs for one frame. [logoPixelAt] samples the
/// decoded artwork (un-premultiplied ARGB, null before the async decode lands
/// — overlays must tolerate that first frame).
class SplashFrame {
  final double progress;
  final double seed;
  final Rect logoRect;
  final Offset sunPos;
  final ByteData? _pixels;
  final int _pw, _ph;

  /// The artwork ITSELF, for overlays that must draw a piece of it rather than
  /// a flat colour. Reading one texel per block and filling a rect with it
  /// quantises the wordmark to the block grid — at ~2pt blocks that is a
  /// visibly chunky, "low-res" logo (paid on the laser engraver). Blitting the
  /// block's own texels keeps the artwork at full resolution while the effect
  /// still owns which blocks exist and when.
  final ui.Image image;

  const SplashFrame(this.progress, this.seed, this.logoRect, this.sunPos,
      this._pixels, this._pw, this._ph, this.image);

  /// Source rect, in IMAGE pixels, of the logo-UV box [u0,v0]-[u1,v1].
  Rect logoSrc(double u0, double v0, double u1, double v1) =>
      Rect.fromLTRB(u0 * _pw, v0 * _ph, u1 * _pw, v1 * _ph);

  int? logoPixelAt(double u, double v) {
    final px = _pixels;
    if (px == null) return null;
    final x = (u * _pw).floor().clamp(0, _pw - 1);
    final y = (v * _ph).floor().clamp(0, _ph - 1);
    final o = (y * _pw + x) * 4;
    final r = px.getUint8(o), g = px.getUint8(o + 1);
    final b = px.getUint8(o + 2), a = px.getUint8(o + 3);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  /// The brand pink, read off the sun's own pixels (fallback: measured).
  Color get brandPink {
    final px = logoPixelAt(kSplashSunUv.dx, kSplashSunUv.dy - 0.06);
    if (px == null || ((px >> 24) & 0xff) < 128) {
      return const Color(0xFFF52E93);
    }
    return Color(0xFF000000 | (px & 0xFFFFFF));
  }
}

/// A sprite pass drawn by the painter AFTER the shader rect — the CPU-computed,
/// GPU-instanced half of a hybrid effect. Positions are derived once per frame
/// here instead of once per PIXEL in the shader, which is the whole
/// optimisation (a fragment loop pays O(pixels x objects)).
typedef SplashOverlay = void Function(Canvas canvas, Size size, SplashFrame f);

/// One launch-intro effect: a fragment shader asset + its play duration.
/// All effects share the uniform contract in splash_intro's painter, so the
/// driver is common and effects stay swappable (see splash_fx_*.frag).
class SplashEffect {
  final String asset;
  final Duration duration;

  /// Sprite pass over the shader (see [SplashOverlay]); null = shader-only.
  final SplashOverlay? overlay;

  /// Draw the sun band via the canvas AFTER the overlay, so sprites pass
  /// BEHIND the sun. The effect's shader must then NOT draw the sun itself.
  final bool sunOnTop;

  const SplashEffect(this.asset,
      {this.duration = const Duration(milliseconds: 1600),
      this.overlay,
      this.sunOnTop = false});
}

/// Registry of intro effects. Adding one = a shaders/splash_fx_*.frag that
/// `#include`s splash_common.glsl (the uniform contract + the two invariants),
/// a pubspec `shaders:` entry, and a line here — the driver, random pick,
/// reduce-motion and static fallback are shared. The contract is enforced by
/// test/splash_contract_test.dart (frame-0 = sun only; progress-1 = transparent).
const List<SplashEffect> kSplashEffects = <SplashEffect>[
  SplashEffect('shaders/splash_fx_raster.frag'),
  SplashEffect('shaders/splash_fx_copper.frag',
      duration: Duration(milliseconds: 3000)),
  SplashEffect('shaders/splash_fx_twister.frag',
      duration: Duration(milliseconds: 3000)),
  SplashEffect('shaders/splash_fx_vectorballs.frag',
      duration: Duration(milliseconds: 3600),
      overlay: splashVectorBallsOverlay,
      sunOnTop: true),
  SplashEffect('shaders/splash_fx_starfield.frag',
      duration: Duration(milliseconds: 3600),
      overlay: splashStarfieldOverlay,
      sunOnTop: true),
  SplashEffect('shaders/splash_fx_laser.frag',
      duration: Duration(milliseconds: 3600),
      overlay: splashLaserOverlay,
      sunOnTop: true),
  SplashEffect('shaders/splash_fx_rotozoom.frag',
      duration: Duration(milliseconds: 4200)),
];

/// DEV ONLY — pins the launch intro to ONE effect while it is being tuned
/// (every launch shows it instead of the random pick). Set back to null before
/// a release; pickRandomEffect ignores it when null.
// ignore: unnecessary_nullable_for_final_variable_declarations
const String? kSplashForcedEffect = null;

/// The hidden picker: a finger HELD on the screen while the intro plays forces
/// one effect. The screen is a 3x5 grid read the way text is — the top-left
/// cell is the first registered effect, the one to its right the second, and
/// so on down the rows.
///
/// "While the intro plays", not "while the app starts": a finger already down
/// before the app's window exists is never delivered to it, at any layer —
/// see the note above [installLaunchTouchProbe].
///
/// Fifteen cells for seven effects today, and a cell PAST the end of the
/// registry deliberately does nothing (the random pick stands): that is what
/// lets the list grow later without moving a cell anyone has learned. The
/// mapping is the registration order of [kSplashEffects], so inserting an
/// effect in the MIDDLE of that list renumbers every cell after it — append.
const int kSplashGridCols = 3, kSplashGridRows = 5;

/// Effect index for a launch touch at [p] on a screen of [size], or null when
/// the cell holds no effect.
int? splashEffectIndexAt(Offset p, Size size) {
  if (size.width <= 0 || size.height <= 0) return null;
  final col =
      (p.dx / size.width * kSplashGridCols).floor().clamp(0, kSplashGridCols - 1);
  final row =
      (p.dy / size.height * kSplashGridRows).floor().clamp(0, kSplashGridRows - 1);
  final i = row * kSplashGridCols + col;
  return i < kSplashEffects.length ? i : null;
}

/// How long the finger must STAY down before it counts. The gesture has to be
/// distinguishable from the impatient tap of someone who wants the intro over
/// with — that one must not silently change the effect.
const Duration kSplashHoldTime = Duration(milliseconds: 250);

// ---------------------------------------------------------------------------
// The held finger — and why it is held DURING the intro, not before it.
//
// The first two attempts both tried to catch a finger already down while the
// app was starting, and both were inert. MEASURED, not reasoned: with the
// probe below narrating every packet it sees, launching from `adb shell am
// start` with a finger on the screen prints "aucun appui reçu" — nothing
// whatsoever reaches Dart.
//
// The cause is not Flutter's and no layer fixes it: the system routes a
// gesture to the WINDOW THAT RECEIVED ITS `down`. A finger pressed before our
// window exists belongs to the launcher; our window then appears under that
// finger and is sent nothing at all — no `down`, no `move`. Capturing in
// MainActivity.dispatchTouchEvent / AppDelegate would intercept exactly the
// same nothing. The only case native capture would have won is a press that
// starts after our window is up but before Dart listens, and the probe below
// already covers that one.
//
// So the gesture is a HOLD DURING THE INTRO: the finger goes down while the
// sun is on screen, which is a `down` our own window receives normally.
//
// The probe still sits on the raw pointer packets rather than on a Listener,
// for a reason that survives the change: a Listener only exists once runApp
// has built a tree, and main() spends a long time before that (bundled-asset
// copy, DB open, shader warm-up). A hold started in that hole is buffered here
// and handed over when the intro is finally there to use it — the
// pull-not-push shape already used for files opened before Dart is listening
// (AppDelegate/takePending).
//
// ⚠️ It must be installed AFTER WidgetsFlutterBinding.ensureInitialized():
// GestureBinding installs its own handler there, and doing it the other way
// round overwrites ours in silence. The previous handler is always called on,
// or the app stops receiving input entirely.
typedef LaunchTouchCallback = void Function(Offset position);

Offset? _pendingLaunchTouch;
LaunchTouchCallback? _launchTouchSink;
bool _launchProbeLive = false;
bool _launchProbeInstalled = false;
Offset? _holdOrigin;
Timer? _holdTimer;

/// Set to have the probe narrate what it sees. On by default in debug only —
/// when a hidden feature does nothing, "no touch reached Dart at all" and
/// "the touch landed on an empty cell" are the two answers to tell apart, and
/// silence looks identical either way.
bool kDebugLaunchTouch = !kReleaseMode;

void installLaunchTouchProbe() {
  if (_launchProbeInstalled) return;
  _launchProbeInstalled = true;
  _launchProbeLive = true;
  final dispatcher = ui.PlatformDispatcher.instance;
  final previous = dispatcher.onPointerDataPacket;
  dispatcher.onPointerDataPacket = (ui.PointerDataPacket packet) {
    if (_launchProbeLive) {
      for (final d in packet.data) {
        // Lifting ABANDONS the hold — that is what separates the gesture from
        // a tap, and it has to be watched as carefully as the press itself.
        if (d.change == ui.PointerChange.up ||
            d.change == ui.PointerChange.cancel ||
            d.change == ui.PointerChange.remove) {
          _holdTimer?.cancel();
          _holdTimer = null;
          _holdOrigin = null;
          continue;
        }
        // A finger, not a cursor drifting over the window: for touch and
        // stylus the synthesised `add` counts too (it carries the same
        // position and precedes the `down`).
        final finger = d.kind == ui.PointerDeviceKind.touch ||
            d.kind == ui.PointerDeviceKind.stylus;
        final pressed = d.change == ui.PointerChange.down ||
            (finger && d.change == ui.PointerChange.add);
        if (!pressed || _holdOrigin != null) continue;
        // Kept in PHYSICAL pixels, deliberately. Converting here would need
        // devicePixelRatio, and this runs so early that the view may not have
        // reported its metrics yet — a ratio fallen back to 1 puts the touch
        // three times too far out, it clamps to the bottom-right cell, that
        // cell holds no effect, and the feature does nothing WITHOUT A WORD.
        // The consumer divides by the same view's physicalSize, so the ratio
        // cancels instead of having to be right.
        //
        // The ORIGIN is what is kept, not wherever the finger has drifted to
        // by the time the hold completes: the user aimed at a cell.
        _holdOrigin = Offset(d.physicalX, d.physicalY);
        if (kDebugLaunchTouch) {
          debugPrint('[launch touch] doigt posé '
              '@${d.physicalX.round()},${d.physicalY.round()} — maintenir '
              '${kSplashHoldTime.inMilliseconds} ms');
        }
        _holdTimer = Timer(kSplashHoldTime, () {
          _holdTimer = null;
          _pendingLaunchTouch = _holdOrigin;
          _drainLaunchTouch();
        });
        break;
      }
    }
    previous?.call(packet);
  };
}

void _drainLaunchTouch() {
  final p = _pendingLaunchTouch, sink = _launchTouchSink;
  if (p == null || sink == null) return;
  _pendingLaunchTouch = null;
  _launchProbeLive = false;
  // Never re-entrant with the pointer packet being dispatched, nor with the
  // build that registered the sink.
  scheduleMicrotask(() => sink(p));
}

/// Hand the launch touch to [cb] — at once if one was already seen while the
/// app was still booting, otherwise as soon as one arrives. The position is in
/// PHYSICAL pixels: measure the grid against the view's `physicalSize`.
void listenLaunchTouch(LaunchTouchCallback cb) {
  _launchTouchSink = cb;
  _drainLaunchTouch();
}

/// Stop listening and forget anything buffered.
void stopLaunchTouchProbe() {
  if (kDebugLaunchTouch && _launchProbeLive) {
    debugPrint('[launch touch] fin de l\'intro — '
        '${_holdOrigin == null ? "aucun doigt posé" : "doigt posé mais pas maintenu"}');
  }
  _launchProbeLive = false;
  _launchTouchSink = null;
  _pendingLaunchTouch = null;
  _holdTimer?.cancel();
  _holdTimer = null;
  _holdOrigin = null;
}

/// Re-arms the probe so a test can exercise it more than once (it is a
/// once-per-process affair in the app).
@visibleForTesting
void resetLaunchTouchProbeForTest() {
  _holdTimer?.cancel();
  _holdTimer = null;
  _holdOrigin = null;
  _launchProbeLive = true;
  _launchTouchSink = null;
  _pendingLaunchTouch = null;
}

/// Pick a random effect, avoiding [avoid] (the previous pick) when possible.
SplashEffect pickRandomEffect({String? avoid, math.Random? rng}) {
  if (kSplashForcedEffect != null) {
    return kSplashEffects.firstWhere((e) => e.asset == kSplashForcedEffect,
        orElse: () => kSplashEffects.first);
  }
  final r = rng ?? math.Random();
  if (kSplashEffects.length == 1) return kSplashEffects.first;
  final pool = avoid == null
      ? kSplashEffects
      : kSplashEffects.where((e) => e.asset != avoid).toList();
  final list = pool.isEmpty ? kSplashEffects : pool;
  return list[r.nextInt(list.length)];
}

/// Decodes the splash logo once (call before runApp so frame-0 is exact).
Future<ui.Image> loadSplashImage() async {
  final data = await rootBundle.load(_kSplashAsset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// Plays one shader intro over a [kSplashBg] background, then calls [onDone].
/// Mirrors oscilloscope_widget's Ticker + FragmentProgram pipeline.
class SplashIntro extends StatefulWidget {
  final SplashEffect effect;
  final ui.Image image;
  final VoidCallback onDone;

  const SplashIntro({
    super.key,
    required this.effect,
    required this.image,
    required this.onDone,
  });

  @override
  State<SplashIntro> createState() => _SplashIntroState();
}

class _SplashIntroState extends State<SplashIntro>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  ui.FragmentProgram? _program;
  bool _shaderFailed = false;
  double _progress = 0.0;
  Duration _elapsed = Duration.zero;
  bool _done = false;
  // Per-launch variation handed to effects as uSeed (0 in tests — determinism).
  final double _seed = math.Random().nextDouble();

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = createTicker(_onTick)..start();
  }

  ByteData? _pixels;

  Future<void> _load() async {
    try {
      final prog = await ui.FragmentProgram.fromAsset(widget.effect.asset);
      // The artwork's pixels, for overlays that colour sprites from texels.
      final px = widget.effect.overlay == null
          ? null
          : await widget.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (mounted) {
        setState(() {
          _program = prog;
          _pixels = px;
        });
      }
    } catch (e) {
      debugPrint('SplashIntro: shader load failed (${widget.effect.asset}) — $e');
      if (mounted) setState(() => _shaderFailed = true);
    }
  }

  void _onTick(Duration elapsed) {
    if (_done) return;
    _elapsed = elapsed;
    final total = widget.effect.duration.inMicroseconds;
    final p = total <= 0 ? 1.0 : (elapsed.inMicroseconds / total).clamp(0.0, 1.0);
    setState(() => _progress = p);
    if (p >= 1.0) _finish();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _ticker.stop();
    // Defer so we don't setState/pop during the ticker callback's build.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduce-motion: hold the static splash a beat, then finish (no shader).
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion || _shaderFailed || _program == null) {
      // Static fallback = native splash look: centered logo on the bg.
      if ((reduceMotion || _shaderFailed) &&
          !_done &&
          _elapsed > const Duration(milliseconds: 350)) {
        _finish();
      }
      // While the shader is merely LOADING, this frame must be the SUN ALONE:
      // the native splash is sun-only and so is every effect's frame 0 — the
      // full lockup here made the wordmark flash on and then vanish when the
      // effect took over (seen on iOS, whenever the async load spanned enough
      // frames to be visible). The deliberate fallbacks (reduce-motion,
      // shader failure) keep the full logo: there, it IS the show.
      return _StaticSplash(
          image: widget.image,
          sunOnly: !(reduceMotion || _shaderFailed));
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: SplashIntroPainter(_program!, widget.image, _progress,
            seed: _seed, effect: widget.effect, pixels: _pixels),
        size: Size.infinite,
      ),
    );
  }
}

/// Native-splash-equivalent static frame: centered logo at the native splash's
/// display size on the splash background. [sunOnly] draws just the sun band
/// (what the native splash shows), for the frames spent waiting on the shader.
class _StaticSplash extends StatelessWidget {
  final ui.Image image;
  final bool sunOnly;
  const _StaticSplash({required this.image, this.sunOnly = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StaticSplashPainter(image, sunOnly),
      size: Size.infinite,
    );
  }
}

class _StaticSplashPainter extends CustomPainter {
  final ui.Image image;
  final bool sunOnly;
  _StaticSplashPainter(this.image, this.sunOnly);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = kSplashBg);
    final frac = sunOnly ? kSplashSplit : 1.0;
    const lw = kSplashLogoSize;
    final lx = (size.width - lw) / 2.0;
    final ly = (size.height - lw) / 2.0;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height * frac),
      Rect.fromLTWH(lx, ly, lw, lw * frac),
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(covariant _StaticSplashPainter old) =>
      old.image != image || old.sunOnly != sunOnly;
}

/// The ONE painter every effect goes through — it owns the uniform contract
/// (mirrored in splash_common.glsl, enforced by test/splash_contract_test.dart).
/// Public so the contract test renders effects through the exact same path
/// the app uses.
class SplashIntroPainter extends CustomPainter {
  final ui.FragmentProgram _prog;
  final ui.Image _image;
  final double _progress;
  final double seed;
  final SplashEffect? effect;
  final ByteData? pixels;
  SplashIntroPainter(this._prog, this._image, this._progress,
      {this.seed = 0, this.effect, this.pixels});

  @override
  void paint(Canvas canvas, Size size) {
    // Logo rect: centered at the native splash's fixed display size so the
    // shader's frame-0 output matches the native splash pixel-for-pixel.
    const lw = kSplashLogoSize;
    const lh = kSplashLogoSize;
    final lx = (size.width - lw) / 2.0;
    final ly = (size.height - lh) / 2.0;

    final shader = _prog.fragmentShader();
    shader.setFloat(0, size.width);                       // uSize
    shader.setFloat(1, size.height);
    shader.setFloat(2, _progress);                        // uProgress
    shader.setFloat(3, lx);                               // uLogoRect
    shader.setFloat(4, ly);
    shader.setFloat(5, lw);
    shader.setFloat(6, lh);
    shader.setFloat(7, lx + kSplashSunUv.dx * lw);        // uSunPos
    shader.setFloat(8, ly + kSplashSunUv.dy * lh);
    shader.setFloat(9, seed);                             // uSeed
    shader.setImageSampler(0, _image);                    // uTexLogo
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );

    // Hybrid effects: sprite pass over the shader, then the sun band drawn by
    // the canvas so sprites pass BEHIND it (their shader does not draw it).
    final fx = effect;
    if (fx?.overlay != null) {
      final frame = SplashFrame(
          _progress,
          seed,
          Rect.fromLTWH(lx, ly, lw, lh),
          Offset(lx + kSplashSunUv.dx * lw, ly + kSplashSunUv.dy * lh),
          pixels,
          _image.width,
          _image.height,
          _image);
      fx!.overlay!(canvas, size, frame);
    }
    if (fx?.sunOnTop ?? false) {
      final a = splashDissolveAlpha(_progress);
      if (a > 0) {
        canvas.drawImageRect(
          _image,
          Rect.fromLTWH(
              0, 0, _image.width.toDouble(), _image.height * kSplashSplit),
          Rect.fromLTWH(lx, ly, lw, lh * kSplashSplit),
          Paint()
            ..filterQuality = FilterQuality.low
            ..color = Color.fromRGBO(255, 255, 255, a),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SplashIntroPainter old) =>
      old._progress != _progress || old._image != _image;
}
