// Sprite overlays for launch-intro effects — the CPU half of the hybrid
// pipeline (see SplashEffect.overlay in splash_intro.dart).
//
// Why this exists: a fragment shader pays O(pixels x objects) — every pixel of
// the screen re-derived the position of all 78 balls and all 180 conveyor
// beads, which is why "effects a 486 ran at 60fps" crawled. A sprite pays
// O(its own pixels): positions are computed ONCE per frame here, and Skia/
// Impeller instances the draws. The shaders keep only what needs the texture
// (the wordmark reveal).
//
// The starfield's STARS were the last holdout, on the argument that depth
// layers of a jittered grid make them O(layers) per pixel rather than
// O(stars). That is still a per-pixel loop, and the density ramp took it to
// 64 layers x 3 hashes x 2 divisions on every fragment — ~160M inner
// iterations per frame on a 1080x2340 phone, measured as very slow on
// Android. Same model, moved here: ~25 us of CPU per frame and a handful of
// batched point draws.
//
// Every constant that also lives in a .frag is marked MIRROR — the two sides
// share a clock, and drifting one breaks the hand-off (a bead landing where
// no texel lights).

import 'dart:math' as math;
import 'dart:typed_data' show Float32List, Int32List, Uint8List;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'splash_intro.dart';

// ---------------------------------------------------------------------------
// Vector balls — 78 shaded-sphere sprites forming REWAMP under the sun.
// The whole effect lives here; its .frag only paints the background.
// ---------------------------------------------------------------------------

// Dot-matrix font: (col, row) per letter, 3x5 cells (5x5 for W and M), 13
// balls per letter, shorter letters repeating their first dot. Same data the
// shader carried packed base-25 — in Dart it can simply be written down.
const List<List<Offset>> _vbLetters = [
  // R
  [Offset(0, 0), Offset(1, 0), Offset(0, 1), Offset(2, 1), Offset(0, 2),
   Offset(1, 2), Offset(0, 3), Offset(2, 3), Offset(0, 4), Offset(2, 4)],
  // E
  [Offset(0, 0), Offset(1, 0), Offset(2, 0), Offset(0, 1), Offset(0, 2),
   Offset(1, 2), Offset(0, 3), Offset(0, 4), Offset(1, 4), Offset(2, 4)],
  // W (5 wide)
  [Offset(0, 0), Offset(4, 0), Offset(0, 1), Offset(4, 1), Offset(0, 2),
   Offset(2, 2), Offset(4, 2), Offset(0, 3), Offset(2, 3), Offset(4, 3),
   Offset(1, 4), Offset(3, 4)],
  // A
  [Offset(1, 0), Offset(0, 1), Offset(2, 1), Offset(0, 2), Offset(1, 2),
   Offset(2, 2), Offset(0, 3), Offset(2, 3), Offset(0, 4), Offset(2, 4)],
  // M (5 wide)
  [Offset(0, 0), Offset(4, 0), Offset(0, 1), Offset(1, 1), Offset(3, 1),
   Offset(4, 1), Offset(0, 2), Offset(2, 2), Offset(4, 2), Offset(0, 3),
   Offset(4, 3), Offset(0, 4), Offset(4, 4)],
  // P
  [Offset(0, 0), Offset(1, 0), Offset(0, 1), Offset(2, 1), Offset(0, 2),
   Offset(1, 2), Offset(0, 3), Offset(0, 4)],
];
const List<double> _vbOff = [0, 4, 8, 14, 18, 24]; // column offsets in the word

// MIRROR of the retired shader constants (splash_fx_vectorballs history).
const double _vbStart = 0.06, _vbDelayL = 0.045, _vbDelayB = 0.005;
const double _vbJitter = 0.02, _vbTravel = 0.36;
const double _vbWordW = 0.88, _vbCells = 27.0;

void splashVectorBallsOverlay(Canvas canvas, Size size, SplashFrame f) {
  final a = splashDissolveAlpha(f.progress);
  if (a <= 0) return;

  // Word geometry — anchored under the sun band, capped by remaining height.
  final sunBot = f.logoRect.top + f.logoRect.width * kSplashSplit;
  final wordY = sunBot + size.height * 0.045;
  final cell = math.min(
      size.width * _vbWordW / _vbCells, (size.height * 0.94 - wordY) / 5.0);
  final ballR = cell * 0.72;
  final wordOx = size.width * 0.5 - 13.0 * cell;

  final pink = f.brandPink;
  const white = Color(0xFFFFFFFF);

  for (var i = 0; i < 78; i++) {
    final li = i ~/ 13;
    final dots = _vbLetters[li];
    final d = dots[(i - li * 13) % dots.length];
    final tgt = Offset(wordOx + (_vbOff[li] + d.dx) * cell, wordY + d.dy * cell);

    // Own clock, then own arc: quadratic Bezier from the sun, control point
    // from golden-ratio sequences (matches the shader's final form).
    final t = ((f.progress - _vbStart - li * _vbDelayL - (i - li * 13) * _vbDelayB
                - _frac(i * 0.7548777) * _vbJitter) / _vbTravel)
        .clamp(0.0, 1.0);
    if (t <= 0) continue;
    final e = t * t * (3.0 - 2.0 * t);
    final cd = Offset(_frac(i * 0.618034) - 0.5, _frac(i * 0.324718) - 0.5);
    final cl = cd.distance < 1e-3 ? const Offset(1, 0) : cd / cd.distance;
    final crad = (0.35 + 0.75 * _frac(i * 0.5545497)) * size.height * 0.55;
    final ctrl = f.sunPos + cl * crad;
    final pos = Offset.lerp(
        Offset.lerp(f.sunPos, ctrl, e)!, Offset.lerp(ctrl, tgt, e)!, e)!;

    final vis = _smooth(0.0, 0.10, t) * a;
    if (vis <= 0) continue;

    // The classic vector-ball sprite: a focal radial gradient — hot spec
    // toward the light (upper-left, like the rest of the intro), base tone,
    // dark rim. What the era baked into the sprite, Skia instances for free.
    final base = (li == 2 || li == 3) ? pink : white;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        pos, ballR,
        [white, base, _scale(base, 0.22)],
        const [0.0, 0.42, 1.0],
        TileMode.clamp, null,
        pos + Offset(-ballR * 0.45, -ballR * 0.4),
        ballR * 0.05,
      )
      ..color = Color.fromRGBO(255, 255, 255, vis);
    canvas.drawCircle(pos, ballR, paint);
  }
}

// ---------------------------------------------------------------------------
// Starfield — the stars AND the conveyor, the ribbon of pixel beads feeding
// the raster-scan pen. The reveal itself stays in the .frag (it needs the
// texture); everything that FLIES is here. The clock (nHead) and the three
// scan coins are MIRRORS of splash_fx_starfield.frag — same formulas, same
// constants, or a bead lands where no texel lights.
// ---------------------------------------------------------------------------

const double _sfChain = 180, _sfRevIn = 0.20, _sfRevSpan = 0.52;
const double _sfBlocks = 128, _sfEdgeSpd = 0.9;
const double _sfColLo = 0.225, _sfColHi = 0.78;
const double _sfRowLo = 0.585, _sfRowHi = 0.70;

// --- the stars -------------------------------------------------------------
//
// They used to be depth LAYERS of a jittered grid inside the .frag — the
// standard way to fake sprites in a fragment shader, and still O(layers) PER
// PIXEL. The density ramp took that to 64 layers x 3 hashes x 2 divisions on
// every fragment: ~160M inner iterations per frame at 1080x2340. Here the
// SAME model (a plane at depth z, projected radially, wrapping to the far
// plane, each star born at its own moment) costs one pass over the pool per
// frame, and the ~600 that land on screen go out as a handful of batched
// point draws.
//
// MIRROR of the retired shader constants: the motion is unchanged, so the
// effect still reads as the same sky.
const int _sfStars = 3600;    // pool; ~1/6 of it is on screen at any time
const double _sfZSpd = 0.42;  // depth wraps per intro, before the ramp
const double _sfBirth = 0.55; // births spread over this much progress
const int _sfBands = 8;       // depth quantisation: one draw batch per band
const int _sfBandCap = 512;   // points per batch (band x colour)

/// Per-star constants, built once: direction in the depth plane (a square of
/// half-extent 1, scaled by the screen's half-diagonal), depth phase, birth
/// moment, and whether the star leans pink.
Float32List? _sfDirX, _sfDirY, _sfPhase, _sfBorn;
Uint8List? _sfPink;

void _sfBuildStars() {
  final dx = Float32List(_sfStars), dy = Float32List(_sfStars);
  final ph = Float32List(_sfStars), bn = Float32List(_sfStars);
  final pk = Uint8List(_sfStars);
  // The sky is the same on every launch, as it was when the shader owned it.
  //
  // ⚠️ Deux pièges, et le second ne se voit qu'au DÉBUT de l'intro.
  //
  // 1. Surtout pas cinq suites `frac(i * constante)` du MÊME indice: elles
  //    sont équiréparties chacune de son côté mais CORRÉLÉES entre elles, si
  //    bien que la date de naissance suivait la position en y — le ciel se
  //    peuplait par le BAS avant de s'équilibrer une fois toutes les étoiles
  //    nées. Symptôme rapporté tel quel.
  //
  // 2. Des naissances TIRÉES AU HASARD ne corrigent que la corrélation, pas
  //    le grumeau: à p = 0.05 il n'y a qu'une quarantaine d'étoiles à l'écran
  //    et n'importe quel tirage y fait des paquets. La position est donc une
  //    suite à FAIBLE DISCRÉPANCE (R2, la constante plastique) parcourue DANS
  //    L'ORDRE DES NAISSANCES: la propriété de cette suite est que tout
  //    PRÉFIXE couvre le carré uniformément, donc le ciel est bien réparti à
  //    chaque instant par construction, et non par chance. La naissance est
  //    l'indice lui-même, à un demi-pas de gigue près pour que les apparitions
  //    ne soient pas métronomiques.
  //
  // La PROFONDEUR, elle, doit rester indépendante: la lier à l'indice ferait
  // du plan de chaque étoile une fonction de sa position, ce qui se lit comme
  // une structure dans le ciel.
  const double a1 = 0.7548776662466927;  // 1/g,  g = plastic number
  const double a2 = 0.5698402909980532;  // 1/g^2
  final rng = math.Random(0x5EED5);
  for (var i = 0; i < _sfStars; i++) {
    dx[i] = _frac(0.5 + i * a1) * 2.0 - 1.0;
    dy[i] = _frac(0.5 + i * a2) * 2.0 - 1.0;
    ph[i] = rng.nextDouble();
    bn[i] = _sfBirth * (i + 0.5 + (rng.nextDouble() - 0.5)) / _sfStars;
    pk[i] = rng.nextDouble() > 0.8 ? 1 : 0;
  }
  _sfDirX = dx;
  _sfDirY = dy;
  _sfPhase = ph;
  _sfBorn = bn;
  _sfPink = pk;
}

/// One point buffer per (depth band, colour) — filled in place, no per-frame
/// allocation. A band shares one size and one brightness, which is exactly
/// what lets the whole band go out as a single drawRawPoints.
final List<Float32List> _sfBuf =
    List<Float32List>.generate(_sfBands * 2, (_) => Float32List(_sfBandCap * 2));
final Int32List _sfCount = Int32List(_sfBands * 2);

void _sfDrawStars(Canvas canvas, Size size, double p, double a) {
  if (_sfDirX == null) _sfBuildStars();
  final dirX = _sfDirX!, dirY = _sfDirY!, phase = _sfPhase!, born = _sfBorn!;
  final pink = _sfPink!;

  final cx = size.width * 0.5, cy = size.height * 0.5;
  // The plane's unit, in pixels: half the screen diagonal, so a star's
  // direction covers the whole frame when its plane is at unit depth.
  final r = 0.5 * math.sqrt(size.width * size.width + size.height * size.height);
  // The rush ACCELERATES, as it did in the shader (p * kZSpd * (1 + 3p)).
  final travel = p * _sfZSpd * (1.0 + 3.0 * p);
  const margin = 4.0;
  final maxX = size.width + margin, maxY = size.height + margin;

  for (var i = 0; i < _sfBands * 2; i++) {
    _sfCount[i] = 0;
  }

  for (var i = 0; i < _sfStars; i++) {
    if (p <= born[i]) continue; // not yet born: the sky thickens from nothing
    final z = _frac(phase[i] - travel);
    // Depth band 0 is the far plane — its stars are dimmer than one alpha
    // step, so they are skipped before the projection is even computed.
    final near = 1.0 - z;
    final band = (near * _sfBands).floor();
    if (band <= 0) continue;
    final inv = r / (z + 0.08);
    final x = cx + dirX[i] * inv;
    if (x < -margin || x > maxX) continue;
    final y = cy + dirY[i] * inv;
    if (y < -margin || y > maxY) continue;
    final b = band * 2 + pink[i];
    final n = _sfCount[b];
    if (n >= _sfBandCap) continue;
    final buf = _sfBuf[b];
    buf[n * 2] = x;
    buf[n * 2 + 1] = y;
    _sfCount[b] = n + 1;
  }

  final paint = Paint()..strokeCap = StrokeCap.square;
  for (var band = 1; band < _sfBands; band++) {
    // The band's own depth, taken at its centre: nearer = bigger, brighter.
    final near = (band + 0.5) / _sfBands;
    final alpha = math.min(near * near * 1.4, 1.0) * a;
    if (alpha <= 0.004) continue;
    paint.strokeWidth = 2.0 * (1.0 + 0.6 * near);
    for (var c = 0; c < 2; c++) {
      final n = _sfCount[band * 2 + c];
      if (n == 0) continue;
      // A hint of the palette: some stars lean pink, most stay white.
      paint.color = c == 1
          ? Color.fromRGBO(255, 158, 209, alpha)
          : Color.fromRGBO(255, 255, 255, alpha);
      canvas.drawRawPoints(ui.PointMode.points,
          Float32List.sublistView(_sfBuf[band * 2 + c], 0, n * 2), paint);
    }
  }
}

void splashStarfieldOverlay(Canvas canvas, Size size, SplashFrame f) {
  final a = splashDissolveAlpha(f.progress);
  if (a <= 0) return;

  _sfDrawStars(canvas, size, f.progress, a);

  final colLo = (_sfColLo * _sfBlocks).floorToDouble();
  final colHi = (_sfColHi * _sfBlocks).floorToDouble();
  final rowLo = (_sfRowLo * _sfBlocks).floorToDouble();
  final rowHi = (_sfRowHi * _sfBlocks).floorToDouble();
  final nCols = colHi - colLo + 1.0;
  final nRows = rowHi - rowLo + 1.0;
  final total = nCols * nRows;
  final nHead = (f.progress - _sfRevIn) / _sfRevSpan * total;
  if (nHead <= -_sfChain || nHead >= total + 1.0) return;

  // Les trois pièces du balayage — voir la note dans splash_fx_starfield.frag:
  // elles ne peuvent PAS venir d'un hash à sinus. Le shader calcule en float32
  // et ce code en float64; le facteur 43758.5453 amplifie l'écart du sinus
  // au-delà du seuil de 0.5, et les deux côtés choisissaient alors des motifs
  // différents (mesuré: 8 % / 14 % / 20 % de désaccord sur des graines de
  // 0..1). Les bits sont lus dans la graine par ×8 + floor — un décalage
  // d'exposant, exact dans les deux précisions — après avoir ARRONDI la graine
  // en float32, qui est ce que l'uniforme porte réellement.
  final pat = (_f32(f.seed) * 8).floor();
  final rowMaj = pat & 1 != 0;
  final flipX = pat & 2 != 0;
  final flipY = pat & 4 != 0;

  final j = _rimPoint(
      _sinHash(f.seed * 9.0 + 2.0) + _sfEdgeSpd * f.progress, size);
  final bow = 0.30 * size.height *
      math.sin(2 * math.pi * (_sinHash(f.seed * 9.0 + 2.0) + 0.35 * f.progress));

  final blockHf = 0.5 * f.logoRect.width / _sfBlocks;
  final n0 = nHead.floorToDouble() + 1.0;
  final paint = Paint();
  for (var m = 0.0; m < _sfChain; m += 1.0) {
    final n = n0 + m;
    if (n < 0 || n >= total) continue;
    final u = 1.0 - (n - nHead) / _sfChain;

    var ic = rowMaj ? n % nCols : (n / nRows).floorToDouble();
    var ir = rowMaj ? (n / nCols).floorToDouble() : n % nRows;
    if (flipX) ic = nCols - 1 - ic;
    if (flipY) ir = nRows - 1 - ir;
    final cellU = (colLo + ic + 0.5) / _sfBlocks;
    final cellV = (rowLo + ir + 0.5) / _sfBlocks;

    // The bead IS its future texel: colour and existence from the artwork.
    final px = f.logoPixelAt(cellU, cellV);
    if (px == null || ((px >> 24) & 0xff) < 90) continue;

    final dst = Offset(f.logoRect.left + cellU * f.logoRect.width,
        f.logoRect.top + cellV * f.logoRect.height);
    final mid = Offset.lerp(j, dst, 0.5)!;
    final dir = dst - j;
    final perp = dir.distance < 1e-3
        ? Offset.zero
        : Offset(dir.dy, -dir.dx) / dir.distance;
    final ctrl = mid + perp * bow;
    final pos = Offset.lerp(
        Offset.lerp(j, ctrl, u)!, Offset.lerp(ctrl, dst, u)!, u)!;
    final sz = math.max(_lerp(2.2, blockHf, u), 1.0);

    paint.color = Color.fromRGBO(
        (px >> 16) & 0xff, (px >> 8) & 0xff, px & 0xff, a);
    canvas.drawRect(
        Rect.fromCenter(center: pos, width: sz * 2, height: sz * 2), paint);
  }
}

// ---------------------------------------------------------------------------
// Laser engraver — EVERYTHING that engraves. The .frag draws the bare plate and
// nothing else; see its header for why the split is this way round.
//
// The short version: a laser must only ever point at a block that HOLDS INK,
// or it reads as a cathode-ray sweep wandering over empty plate. Ordering
// blocks by "how many inked blocks come before me" is a counting problem a
// fragment cannot solve (up to 1080 texture reads per pixel); here the decoded
// artwork is already in hand, so the queue is built once and each cut block is
// a canvas rect — the same O(objects) argument as every other hybrid effect.
//
// The lasers share the LETTERS, not the columns: the wordmark is split at its
// empty columns (a wordmark has clean gaps between glyphs), letters are dealt
// round-robin so neighbours go to different beams, and each laser walks its
// letters one after another. That is what makes the beam look like it is
// writing rather than scanning.
// ---------------------------------------------------------------------------

const double _lzRevIn = 0.13, _lzRevSpan = 0.62;

/// Engraving grid. Finer than the starfield's 128 on purpose: there the grid
/// only TIMES a per-fragment reveal, here it also defines the SILHOUETTE, and
/// a 128-grid puts a ~2pt staircase on every glyph edge. At 224 the step is
/// under a logical point — the block is at the artwork's own scale — and the
/// band still holds ~2 400 cells, a sprite bill, not a per-pixel one.
const double _lzBlocks = 224;
const double _lzColLo = 0.225, _lzColHi = 0.78;
const double _lzRowLo = 0.585, _lzRowHi = 0.70;

/// Below this alpha a block is bare plate — no ink, nothing to engrave. Low on
/// purpose: it is tested against the block's MOST OPAQUE texel, so it decides
/// where the glyph's anti-aliased rim stops, not where its body is.
const int _lzInkAlpha = 24;

/// Cooling: how long (in PROGRESS units) a block stays visibly hot. The block
/// grid is ~2 logical px, so the heat has to live in TIME, not in slots — at
/// this size a two-frame flash is simply not seen.
const double _lzCoolT = 0.16;

/// Sparks: how long an ember lives, how many fly per cut block, and the two
/// constants that shape its arc (px per progress unit, and px per progress²).
///
/// The ejection speed is what makes the shower READ as a shower: at 340 the
/// embers barely cleared the block they came from. It is also why gravity
/// climbs with it — the arc's height is speed²/(2·g), so raising one alone
/// would send them off the top of the screen instead of throwing them further.
const double _lzSparkLife = 0.13;
const int _lzSparkPer = 2;
const double _lzSparkSpeed = 1150.0, _lzSparkGravity = 9000.0;

/// DEV ONLY — pins the laser count while the effect is being tuned. Null =
/// read it from the seed (1..3), which is what a release must ship.
// ignore: unnecessary_nullable_for_final_variable_declarations
const int? _lzForceLasers = null;

/// One inked block of the wordmark: its cell (logo-UV of the block CENTRE) and
/// the colour it cools to. The colour is only used for the heat ramp — the
/// block itself is blitted from the artwork, so it keeps its real detail.
class _LzHit {
  final double u, v;
  final int argb;
  const _LzHit(this.u, this.v, this.argb);
}

/// The engraving plan, built once per image: one ordered queue per laser.
class _LzPlan {
  final List<List<_LzHit>> queues;
  final int lasers;
  final double rot;
  final Size size;
  const _LzPlan(this.queues, this.lasers, this.rot, this.size);
}

_LzPlan? _lzPlan;
double _lzPlanSeed = double.nan;

/// Splits the wordmark into letters at its empty columns, deals them to the
/// lasers round-robin, and orders each letter's ink in raster order.
_LzPlan _lzBuildPlan(SplashFrame f, Size size) {
  final colLo = (_lzColLo * _lzBlocks).floor();
  final colHi = (_lzColHi * _lzBlocks).floor();
  final rowLo = (_lzRowLo * _lzBlocks).floor();
  final rowHi = (_lzRowHi * _lzBlocks).floor();

  // Ink per column, and the blocks themselves.
  //
  // A block counts as inked when ANY of its texels is inked, not when the one
  // texel at its centre is. Testing the centre drops every block a glyph only
  // partly covers — which is exactly the anti-aliased RIM of every letter — so
  // the silhouette came out chopped to the block grid while the interior was
  // full-resolution: the wordmark read as more pixelated than in the other
  // effects, whose shaders sample the texture per fragment. The block's colour
  // is taken from its most opaque texel, for the same reason.
  final imgW = f.image.width, imgH = f.image.height;
  final byCol = <int, List<_LzHit>>{};
  for (var cx = colLo; cx <= colHi; cx++) {
    for (var cy = rowLo; cy <= rowHi; cy++) {
      final x0 = (cx / _lzBlocks * imgW).floor();
      final x1 = math.max(((cx + 1) / _lzBlocks * imgW).ceil(), x0 + 1);
      final y0 = (cy / _lzBlocks * imgH).floor();
      final y1 = math.max(((cy + 1) / _lzBlocks * imgH).ceil(), y0 + 1);
      var bestA = 0, best = 0;
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          final px = f.logoPixelAt((x + 0.5) / imgW, (y + 0.5) / imgH);
          if (px == null) continue;
          final al = (px >> 24) & 0xff;
          if (al > bestA) {
            bestA = al;
            best = px;
          }
        }
      }
      if (bestA < _lzInkAlpha) continue;
      (byCol[cx] ??= <_LzHit>[])
          .add(_LzHit((cx + 0.5) / _lzBlocks, (cy + 0.5) / _lzBlocks, best));
    }
  }

  // Letters = runs of consecutive inked columns.
  final letters = <List<int>>[];
  List<int>? run;
  for (var cx = colLo; cx <= colHi; cx++) {
    if (byCol.containsKey(cx)) {
      (run ??= <int>[]).add(cx);
    } else if (run != null) {
      letters.add(run);
      run = null;
    }
  }
  if (run != null) letters.add(run);

  // 1..3 lasers from the seed. Exact arithmetic (x64 is an exponent shift):
  // nothing mirrors this any more, but the rule stays one rule.
  final code = (_f32(f.seed) * 64).floor();
  final lasers = math.min(
      _lzForceLasers ?? (1 + code % 3), math.max(letters.length, 1));
  final rot = (code ~/ 4) / 16.0;

  final queues = List<List<_LzHit>>.generate(lasers, (_) => <_LzHit>[]);
  for (var i = 0; i < letters.length; i++) {
    // Round-robin, so two beams never work on neighbouring glyphs.
    final q = queues[i % lasers];
    // Raster order INSIDE the letter: row by row, left to right — a pen
    // filling a glyph, not a scan crossing the whole word.
    final cells = <_LzHit>[];
    for (final cx in letters[i]) {
      cells.addAll(byCol[cx]!);
    }
    cells.sort((a, b) {
      final dv = a.v.compareTo(b.v);
      return dv != 0 ? dv : a.u.compareTo(b.u);
    });
    q.addAll(cells);
  }
  return _LzPlan(queues, lasers, rot, size);
}

void splashLaserOverlay(Canvas canvas, Size size, SplashFrame f) {
  final a = splashDissolveAlpha(f.progress);
  if (a <= 0) return;
  final headF = (f.progress - _lzRevIn) / _lzRevSpan;
  if (headF <= 0) return; // frame-0 stays the sun alone

  var plan = _lzPlan;
  if (plan == null || plan.size != size || _lzPlanSeed != f.seed) {
    // The artwork does not change during an intro, so the scan of the block
    // grid (~1150 lookups) and the letter split are paid once, not per frame.
    plan = _lzBuildPlan(f, size);
    if (plan.queues.every((q) => q.isEmpty)) return; // artwork not decoded yet
    _lzPlan = plan;
    _lzPlanSeed = f.seed;
  }

  final block = f.logoRect.width / _lzBlocks;
  // The visual grain of the heat — glow, impact square, embers. Deliberately
  // NOT the block: the block is the engraving resolution and got finer to fix
  // the silhouette, which would have shrunk every spark with it. This stays
  // proportional to the logo, so the fire keeps its size whatever the grid.
  final grain = f.logoRect.width / 128.0;
  final paint = Paint();
  final beam = Paint()..style = PaintingStyle.stroke;

  Offset at(_LzHit h) => Offset(f.logoRect.left + h.u * f.logoRect.width,
      f.logoRect.top + h.v * f.logoRect.height);

  // ---- The cut blocks ------------------------------------------------------
  // Drawn first, under the beams and the sparks. Each laser's queue advances on
  // the SHARED normalised head, so unequal queues still start and finish
  // together — a per-queue slot clock would have one beam idle while another
  // is still cutting.
  for (var li = 0; li < plan.lasers; li++) {
    final q = plan.queues[li];
    if (q.isEmpty) continue;
    final cut = headF * q.length;
    final upto = math.min(cut.floor(), q.length);
    const half = 0.5 / _lzBlocks;
    for (var i = 0; i < upto; i++) {
      final h = q[i];
      final pos = at(h);
      // The block is BLITTED from the artwork, not filled with the one texel
      // sampled at its centre: at ~2pt per block a flat fill quantises the
      // wordmark to the grid and the logo comes out visibly chunky. The dest
      // rect is grown half a pixel so neighbouring blits cannot leave a
      // hairline seam between them.
      final dst = Rect.fromLTRB(pos.dx - block * 0.5, pos.dy - block * 0.5,
          pos.dx + block * 0.5 + 0.5, pos.dy + block * 0.5 + 0.5);
      paint
        ..color = Color.fromRGBO(255, 255, 255, a)
        ..filterQuality = FilterQuality.low;
      canvas.drawImageRect(
          f.image,
          f.logoSrc(h.u - half, h.v - half, h.u + half, h.v + half),
          dst,
          paint);

      // Age in PROGRESS units: (slots behind the head) mapped back through the
      // cut window. This is what makes the heat last long enough to be seen.
      final ageT = (cut - i) / q.length * _lzRevSpan;
      final k = (ageT / _lzCoolT).clamp(0.0, 1.0);
      final cool = k * k * (3.0 - 2.0 * k); // smoothstep
      if (cool >= 1.0) continue;
      // The heat is a GLOW laid over the blitted block: white for an instant,
      // then red-orange, fading as the block cools. It spills a little past the
      // cut, the way hot metal does — but only a LITTLE: sized on the visual
      // grain it reached ~2.5 grains across, and a heat blob wider than the
      // stroke it sits in swallows the glyph, which reads as fat molten pixels
      // rather than a cut. The spill is now the block's own size plus a
      // fraction of a grain, so the burn follows the engraving resolution.
      final hot = 1.0 - cool;
      final core = 1.0 - math.min(k * 3.0, 1.0);
      final s = block + grain * 0.55 * hot + 0.5;
      paint
        ..filterQuality = FilterQuality.none
        ..color = Color.fromRGBO(
            255,
            (70 + 185 * core).round(),
            (10 + 210 * core * core).round(),
            hot * hot * a);
      canvas.drawRect(
          Rect.fromCenter(center: pos, width: s, height: s), paint);
    }
  }

  // ---- The beams and the sparks -------------------------------------------
  for (var li = 0; li < plan.lasers; li++) {
    final q = plan.queues[li];
    if (q.isEmpty) continue;
    final cut = headF * q.length;
    final origin = _rimPoint(plan.rot + li / plan.lasers, size);

    if (headF < 1.0) {
      final head = at(q[cut.floor().clamp(0, q.length - 1)]);
      // A cutting laser reads RED: a wide deep-red halo, a narrower orange
      // body, and only a thin near-white core where the beam is hottest. Three
      // strokes rather than two — with only a glow and a white core the beam
      // came out looking like a plain bright line.
      beam
        ..strokeWidth = 7.0
        ..color = Color.fromRGBO(255, 20, 0, 0.20 * a);
      canvas.drawLine(origin, head, beam);
      beam
        ..strokeWidth = 3.0
        ..color = Color.fromRGBO(255, 70, 20, 0.55 * a);
      canvas.drawLine(origin, head, beam);
      beam
        ..strokeWidth = 1.0
        ..color = Color.fromRGBO(255, 190, 150, 0.85 * a);
      canvas.drawLine(origin, head, beam);
      paint
        ..filterQuality = FilterQuality.none
        ..color = Color.fromRGBO(255, 236, 214, a);
      canvas.drawRect(
          Rect.fromCenter(
              center: head, width: grain * 2.4, height: grain * 2.4),
          paint);
    }

    // Embers: every block cut within the last _lzSparkLife of PROGRESS throws
    // a handful, which arc away from the cut and fall. Counted in progress
    // units rather than in slots, so the shower does not thin out as the queue
    // gets longer.
    final liveSlots = (_lzSparkLife / _lzRevSpan * q.length).ceil();
    final first = math.max(0, cut.floor() - liveSlots);
    final last = math.min(cut.floor(), q.length - 1);
    for (var i = first; i <= last; i++) {
      final ageT = (cut - i) / q.length * _lzRevSpan;
      if (ageT < 0 || ageT > _lzSparkLife) continue;
      final t = ageT / _lzSparkLife; // 0 = just cut, 1 = gone
      final fade = (1.0 - t) * (1.0 - t);
      final src = at(q[i]);
      for (var s = 0; s < _lzSparkPer; s++) {
        final h1 = _sinHash(i * 3.7 + s * 11.3 + li * 5.1);
        final h2 = _sinHash(i * 8.1 + s * 2.9 + li * 7.7);
        // Upward hemisphere at birth — sparks jump OFF the plate — then
        // gravity takes them down.
        final ang = math.pi * (1.15 + 0.7 * h1);
        final spd = _lzSparkSpeed * (0.35 + 0.65 * h2);
        final pos = src +
            Offset(math.cos(ang) * spd * ageT,
                math.sin(ang) * spd * ageT +
                    _lzSparkGravity * ageT * ageT);
        final sz = math.max(grain * (1.7 - 1.0 * t), 1.2);
        // Yellow-white at birth, deep red as it dies.
        paint.color = Color.fromRGBO(
            255,
            (235 - 175 * t).round().clamp(0, 255),
            (190 - 190 * t).round().clamp(0, 255),
            fade * a);
        canvas.drawRect(
            Rect.fromCenter(center: pos, width: sz, height: sz), paint);
      }
    }
  }
}

// --- small helpers ---------------------------------------------------------

double _frac(double x) => x - x.floorToDouble();
double _lerp(double a, double b, double t) => a + (b - a) * t;
double _smooth(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

/// La graine telle que le SHADER la voit: `setFloat` la range en float32.
/// Tout ce qui doit s'accorder avec le shader au bit près part de là.
final Float32List _f32buf = Float32List(1);
double _f32(double x) {
  _f32buf[0] = x;
  return _f32buf[0];
}

/// hash11 of splash_common.glsl. Doubles instead of float32: only a hash
/// landing within ~1e-7 of a coin's 0.5 threshold could disagree with the
/// shader, which is lottery odds — accepted.
double _sinHash(double x) => _frac(math.sin(x * 12.9898) * 43758.5453);

Color _scale(Color c, double k) => Color.fromARGB(255, (c.r * 255 * k).round(),
    (c.g * 255 * k).round(), (c.b * 255 * k).round());

/// MIRROR of rimPoint() in splash_fx_starfield.frag.
Offset _rimPoint(double s, Size size) {
  final per = 2 * (size.width + size.height);
  final u = _frac(s) * per;
  if (u < size.width) return Offset(u, 0);
  if (u < size.width + size.height) return Offset(size.width, u - size.width);
  if (u < 2 * size.width + size.height) {
    return Offset(2 * size.width + size.height - u, size.height);
  }
  return Offset(0, per - u);
}
