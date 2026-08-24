// The launch-intro effect CONTRACT, enforced over every registered effect
// (kSplashEffects) — rendered through the exact painter the app uses
// (SplashIntroPainter), so a new shaders/splash_fx_*.frag that violates either
// invariant fails here instead of flashing at launch:
//
//   1. Frame-0 identity: at uProgress == 0 the output is the SUN ONLY
//      (upper kSplit band of splash_logo.png) over kSplashBg — pixel-matching
//      the native splash so the native→Flutter handoff is seamless.
//   2. Dissolve: at uProgress == 1 the output is fully transparent, revealing
//      AppShell underneath.
//
// Effects are rendered with seed 0 (determinism — the lesson of the projectM
// wall-clock probe: never compare a nondeterministic render).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/splash_intro.dart';

/// Logo-UV y split between the sun (above) and wordmark+EQ (below) — mirrors
/// kSplit in shaders/splash_common.glsl.
const double _kSplit = 0.582;

const Size _kCanvas = Size(400, 600);

Future<ui.Image> _loadLogo() async {
  final data = await rootBundle.load('assets/branding/splash/splash_logo.png');
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  return (await codec.getNextFrame()).image;
}

Future<Uint8List> _pixels(ui.Image img) async {
  final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  return bd!.buffer.asUint8List();
}

Future<ui.Image> _renderEffect(ui.FragmentProgram prog, ui.Image logo,
    double progress, SplashEffect effect) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  // The effect is passed so hybrid effects (sprite overlay + canvas sun) run
  // through the exact path the app uses — a shader-only render of one of
  // those has no sun at all.
  SplashIntroPainter(prog, logo, progress, seed: 0, effect: effect)
      .paint(canvas, _kCanvas);
  return rec
      .endRecording()
      .toImage(_kCanvas.width.toInt(), _kCanvas.height.toInt());
}

/// The native-splash look every effect must reproduce at frame-0: the sun band
/// of the logo, centred at kSplashLogoSize, over kSplashBg.
Future<ui.Image> _renderSunReference(ui.Image logo) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(Offset.zero & _kCanvas, Paint()..color = kSplashBg);
  const lw = kSplashLogoSize;
  const lh = kSplashLogoSize;
  final lx = (_kCanvas.width - lw) / 2.0;
  final ly = (_kCanvas.height - lh) / 2.0;
  canvas.drawImageRect(
    logo,
    Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height * _kSplit),
    Rect.fromLTWH(lx, ly, lw, lh * _kSplit),
    Paint()..filterQuality = FilterQuality.low,
  );
  return rec
      .endRecording()
      .toImage(_kCanvas.width.toInt(), _kCanvas.height.toInt());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ui.Image logo;
  late Uint8List sunRef;

  setUpAll(() async {
    logo = await _loadLogo();
    sunRef = await _pixels(await _renderSunReference(logo));
  });

  for (final effect in kSplashEffects) {
    group(effect.asset, () {
      late ui.FragmentProgram prog;

      setUpAll(() async {
        prog = await ui.FragmentProgram.fromAsset(effect.asset);
      });

      test('frame-0 is the sun only over the splash background', () async {
        final out = await _pixels(await _renderEffect(prog, logo, 0.0, effect));
        expect(out.length, sunRef.length);

        // Bilinear sampling in the shader vs drawImageRect will not match bit
        // for bit — the contract is "no visible difference": small mean error,
        // and a negligible share of pixels beyond a small delta (the kSplit
        // boundary row and scaling filter differences live in that share).
        var sum = 0;
        var bad = 0;
        final px = out.length ~/ 4;
        for (var i = 0; i < out.length; i += 4) {
          for (var c = 0; c < 4; c++) {
            final d = (out[i + c] - sunRef[i + c]).abs();
            sum += d;
            if (d > 12) {
              bad++;
              break;
            }
          }
        }
        final mean = sum / out.length;
        final badFrac = bad / px;
        expect(mean, lessThan(1.5),
            reason: 'frame-0 drifts from the native splash (mean channel '
                'diff $mean) — the intro will flash at the handoff');
        expect(badFrac, lessThan(0.005),
            reason: '${(badFrac * 100).toStringAsFixed(2)}% of pixels differ '
                'visibly from the sun-only native splash at uProgress=0');
      });

      test('progress-1 is fully transparent (dissolve contract)', () async {
        final out = await _pixels(await _renderEffect(prog, logo, 1.0, effect));
        var maxA = 0;
        for (var i = 3; i < out.length; i += 4) {
          if (out[i] > maxA) maxA = out[i];
        }
        expect(maxA, lessThanOrEqualTo(2),
            reason: 'effect still opaque at uProgress=1 — AppShell would '
                'never be revealed');
      });
    });
  }
}
