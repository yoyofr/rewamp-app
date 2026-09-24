import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'user_settings.dart';
import 'app_theme.dart';

/// The artwork tint of the player that is currently open, shared with the
/// panels it opens (voices, track info, options) so they read as part of the
/// same surface instead of reverting to the neutral theme colour.
class PlayerTint {
  PlayerTint._();

  /// Dominant colour of the artwork on screen; null when the player is closed,
  /// the cover is monochrome, or the setting is off.
  static Color? dominant;

  /// SECOND dominant colour, when the cover genuinely has one (a distinct hue
  /// covering a comparable area — see [ArtworkTint]). Null on a single-hue
  /// cover, which is the common case; callers must degrade to [dominant].
  static Color? dominantAlt;

  /// The player sheet's own background — the dominant hue, kept fairly rich but
  /// moved to the theme's end of the lightness scale.
  static Color? sheet(BuildContext context) => _tinted(context, dominant);

  /// Same treatment for the second dominant hue, so the two sit at the same
  /// lightness/saturation and only differ by hue. Null when there is only one.
  static Color? sheetAlt(BuildContext context) => _tinted(context, dominantAlt);

  /// Moves an artwork colour onto the player's surface WITHOUT flattening it.
  ///
  /// The tinted player is DEEP in both app themes (the Spotify model): the
  /// sheet keeps the cover's hue at close to its real richness and the
  /// FOREGROUND adapts (white text, via [themeOf]) instead of the tint being
  /// dragged into the zone where the app theme's text happens to be legible.
  /// The old light-theme mapping (saturation capped at 0.55, lightness pulled
  /// to 0.78) turned a deep royal-blue cover into a washed-out lavender that
  /// sat next to the artwork instead of with it.
  ///
  /// Depth is set in **OKLab**, not HSL, and that is the whole point: HSL
  /// lightness is not a perceptual quantity, so the same L means wildly
  /// different things per hue. The wall this has to clear is a MEASURED one —
  /// white body text at WCAG 4.5:1 needs a background relative luminance
  /// ≤ 0.183, so the colour is darkened until `computeLuminance()` passes
  /// 0.175 (margin) — and relative luminance weights green 0.7152 against blue
  /// 0.0722. In HSL that loop was therefore a hue filter nobody asked for:
  /// measured at L 0.39, a yellow needed 7 darkening steps (down to L 0.25)
  /// and a blue needed none, while the blue was ALREADY at luminance 0.039,
  /// i.e. miles under a ceiling it was being clamped by anyway. Perceived
  /// depth across the hue wheel spread 0.186 in OKLab L; setting the depth in
  /// OKLab in the first place brings that to 0.050, and the safety loop below
  /// stops firing at all for ordinary covers.
  ///
  /// Contrast is now paid in CHROMA, not depth: [_oklchToColor] keeps L and
  /// hue and gives up colourfulness to land back inside sRGB (a saturated cyan
  /// simply does not exist at this lightness). That is the same trade the old
  /// code made by darkening, except it costs the thing nobody reads text
  /// against.
  static Color? _tinted(BuildContext context, Color? art) {
    if (art == null || !UserSettings.instance.artworkTintedPlayer) return null;
    // 0 = keep the cover's own perceived lightness, 1 = flatten every cover to
    // the anchor. Deliberately not 1: a dark moody cover SHOULD give a deeper
    // sheet than a bright one — that variation is the source's, not an
    // artefact of the colour space.
    const pull = 0.65;
    const anchor = 0.52;
    final (l0, chroma0, hue) = _toOklch(art);
    var l = (l0 + (anchor - l0) * pull).clamp(0.34, 0.54).toDouble();
    final c = (chroma0 * 0.95).clamp(0.035, 0.18).toDouble();
    var out = _oklchToColor(l, c, hue);
    while (out.computeLuminance() > 0.175 && l > 0.20) {
      l -= 0.01;
      out = _oklchToColor(l, c, hue);
    }
    return out;
  }

  /// Surface for a panel opened ON TOP of the player: the sheet's own colour.
  /// The panel's elevation/scrim already separates it, so no lighten/darken.
  static Color? panel(BuildContext context) => sheet(context);

  /// Theme override for anything sitting ON the tinted sheet. The sheet is now
  /// always deep (see [_tinted]) whatever the app theme, so its foregrounds
  /// must come from a DARK scheme — in a light app theme the inherited black
  /// text would be illegible. Built by the app's ONE theme factory
  /// (`rewampThemeData`, app_theme.dart — it was a copy, and the copy lost the
  /// CJK font fallback: kanji in rectangles on the player and the ⓘ panel)
  /// but seeded from the artwork's dominant colour, so accents (slider,
  /// buttons, switches) stay in the cover's family. Null when the tint is
  /// off/unavailable — callers keep the inherited theme.
  static ThemeData? themeOf(BuildContext context) {
    final surface = sheet(context);
    if (surface == null) return null;
    final seed = dominant!;   // sheet() non-null implies dominant non-null
    if (_themeMemo?.$1 != (seed, surface)) {
      _themeMemo = (
        (seed, surface),
        rewampThemeData(ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ).copyWith(surface: surface)),
      );
    }
    return _themeMemo!.$2;
  }

  static ((Color, Color), ThemeData)? _themeMemo;

  /// Wraps [child] in [themeOf]'s dark theme when a tint is active; identity
  /// otherwise. For the modal sheets the player opens (voices, info, options,
  /// queue) — they are separate routes, so they do NOT inherit the player's
  /// own Theme override.
  static Widget wrap(BuildContext context, Widget child) {
    final t = themeOf(context);
    return t == null ? child : Theme(data: t, child: child);
  }

  /// Background for the queue revealed FROM the player — the artwork tint, but
  /// pushed LIGHTER than the player sheet so the queue reads as a raised layer
  /// over the player rather than the same slab. Null (caller falls back to a
  /// neutral scrim) when the tint is off / unavailable.
  static Color? queueReveal(BuildContext context) {
    final base = sheet(context);
    if (base == null) return null;
    final hsl  = HSLColor.fromColor(base);
    // The sheet is deep in both themes now, so this is always a lighten; the
    // ceiling keeps white queue text comfortably above 4.5:1.
    return hsl
        .withLightness((hsl.lightness + 0.07).clamp(0.0, 0.50))
        .toColor();
  }

  /// Fill for a control sitting ON a tinted panel (the voice pills): same hue,
  /// lifted off the deep panel so the control reads as raised without leaving
  /// the colour family.
  static Color? container(BuildContext context) {
    final base = sheet(context);
    if (base == null) return null;
    final hsl  = HSLColor.fromColor(base);
    return hsl
        .withSaturation((hsl.saturation * 1.2).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + 0.20).clamp(0.0, 1.0))
        .toColor();
  }

  /// Legible foreground for [container].
  static Color? onContainer(BuildContext context) {
    final c = container(context);
    if (c == null) return null;
    return ThemeData.estimateBrightnessForColor(c) == Brightness.dark
        ? Colors.white
        : Colors.black87;
  }
}

// ── OKLab (Björn Ottosson, bottosson.github.io/posts/oklab) ─────────────────
// Just enough of it for the tint: sRGB → OKLCh and back, with a gamut map that
// gives up chroma rather than lightness. No package for four matrices.

double _srgbToLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _linearToSrgb(double c) => c <= 0.0031308
    ? 12.92 * c
    : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;

/// (lightness, chroma, hue-in-radians).
(double, double, double) _toOklch(Color x) {
  final r = _srgbToLinear(x.r), g = _srgbToLinear(x.g), b = _srgbToLinear(x.b);
  final l = math.pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3).toDouble();
  final m = math.pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3).toDouble();
  final s = math.pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3).toDouble();
  final okL = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
  final okA = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
  final okB = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
  return (okL, math.sqrt(okA * okA + okB * okB), math.atan2(okB, okA));
}

/// Linear-light sRGB for an OKLab colour; components outside 0…1 mean the
/// colour does not exist in sRGB.
(double, double, double) _oklabToLinear(double okL, double okA, double okB) {
  final l = math.pow(okL + 0.3963377774 * okA + 0.2158037573 * okB, 3).toDouble();
  final m = math.pow(okL - 0.1055613458 * okA - 0.0638541728 * okB, 3).toDouble();
  final s = math.pow(okL - 0.0894841775 * okA - 1.2914855480 * okB, 3).toDouble();
  return (
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
  );
}

/// OKLCh → the closest sRGB colour at the SAME lightness and hue: chroma is
/// bisected down until the result fits. Lightness is what the contrast rule
/// and the visual weight are expressed in, so it is the one thing that must
/// not be traded away here.
Color _oklchToColor(double l, double c, double hue) {
  final ca = math.cos(hue), sa = math.sin(hue);
  bool fits(double chroma) {
    final (r, g, b) = _oklabToLinear(l, chroma * ca, chroma * sa);
    const e = 1e-4;
    return r >= -e && r <= 1 + e && g >= -e && g <= 1 + e && b >= -e && b <= 1 + e;
  }

  var lo = 0.0, hi = c;
  if (!fits(c)) {
    for (var i = 0; i < 20; i++) {
      final mid = (lo + hi) / 2;
      if (fits(mid)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
  } else {
    lo = c;
  }
  final (r, g, b) = _oklabToLinear(l, lo * ca, lo * sa);
  double ch(double v) => _linearToSrgb(v < 0 ? 0 : v).clamp(0.0, 1.0);
  return Color.from(alpha: 1, red: ch(r), green: ch(g), blue: ch(b));
}

/// The colours an artwork is tinted from: its dominant colour, plus a second
/// one when the cover genuinely has two (see [ArtworkPalette]).
@immutable
class ArtworkTint {
  final Color primary;
  final Color? secondary;
  const ArtworkTint(this.primary, [this.secondary]);

  @override
  bool operator ==(Object other) =>
      other is ArtworkTint &&
      other.primary == primary &&
      other.secondary == secondary;

  @override
  int get hashCode => Object.hash(primary, secondary);
}

/// Extracts the dominant colour(s) of an artwork image (Apple-Music-style
/// player background).
///
/// The image is decoded at 64px, every usable pixel is converted to HSL once,
/// and the colours are found by MODE-SEEKING, not by averaging:
///
///  1. a coarse 3-D histogram (hue × saturation × lightness) picks the busiest
///     region — 3-D because a hue-only histogram lumps a navy sky and a pale
///     cyan into one "blue" bin whose *average* is a dead mid-blue that appears
///     nowhere on the cover. That washing-out is what made every tint look like
///     the same tired pastel;
///  2. a few mean-shift passes then walk that seed to the real peak, averaging
///     ONLY the pixels inside a tight window around it, so the result keeps the
///     saturation and lightness of the colour that actually dominates instead
///     of regressing to the middle of a wide bucket;
///  3. those pixels are claimed and the search runs a SECOND time on what is
///     left, giving the cover's other colour when there is one.
///
/// Weighting is AREA-first (each pixel ≈ 1, saturation only nudges) so a small
/// vivid accent — a logo, a bit of orange text — cannot outvote the muted
/// colour covering the cover. Returns null for an effectively monochrome image
/// (caller falls back to the plain theme surface).
class ArtworkPalette {
  ArtworkPalette._();

  static final _cache = <String, ArtworkTint?>{};
  static final _pending = <String, Future<ArtworkTint?>>{};

  /// [key] identifies the artwork (resolved file path or URL) for caching.
  static Future<ArtworkTint?> tint(ImageProvider provider, String key) {
    if (_cache.containsKey(key)) return Future.value(_cache[key]);
    return _pending[key] ??= () async {
      try {
        // Timeout so a stuck decode can't poison the de-dup forever: without
        // it, one hung extraction left _pending holding a never-completing
        // future and EVERY later caller for the same key waited on it — the
        // "tint only works after close/reopen" bug.
        final c = await _extract(provider).timeout(const Duration(seconds: 8));
        _cache[key] = c;   // completed (null = monochrome) → cacheable
        return c;
      } catch (_) {
        return null;       // timeout/error → NOT cached → retried next time
      } finally {
        _pending.remove(key);
      }
    }();
  }

  /// Primary colour only — the pre-warm hook the mini player passes to
  /// `ArtworkImage.onImageResolved`, and any caller that wants one colour.
  static Future<Color?> dominantColor(ImageProvider provider, String key) async =>
      (await tint(provider, key))?.primary;

  // Mean-shift window. Wide enough that a shaded surface (same colour, varying
  // light) stays ONE cluster, tight enough that two real colours don't merge.
  static const double _hueTol   = 24;    // degrees
  static const double _satTol   = 0.34;
  static const double _lightTol = 0.22;
  // A second colour has to be worth showing: a decent share of the cover, and
  // far enough round the wheel to read as another colour rather than a shade of
  // the first. Deliberately generous — the second hue only ever tints one
  // corner's glow, so a colour holding a fifth of the cover is worth catching;
  // the floor's real job is to keep a small vivid accent (a logo, a line of
  // text) from painting half the player.
  static const double _altMinShare = 0.22;
  static const double _altMinHue   = 25;  // degrees

  static Future<ArtworkTint?> _extract(ImageProvider provider) async {
    final ui.Image img;
    try {
      img = await _decodeDirect(provider);
    } catch (_) {
      return null;
    }
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    if (data == null) return null;

    // ── Pass 1: pixels → HSL, once. Kept in flat typed lists (no per-pixel
    // object allocation — this runs over ~4k pixels and must stay cheap on old
    // devices), then re-read by every mean-shift iteration.
    final bytes = data.buffer.asUint8List();
    final cap = bytes.length ~/ 4;
    final ph = Float32List(cap), ps = Float32List(cap), pl = Float32List(cap);
    final pw = Float32List(cap);
    var n = 0;

    for (var i = 0; i + 3 < bytes.length; i += 4) {
      if (bytes[i + 3] < 128) continue;
      final r = bytes[i] / 255.0,
          g = bytes[i + 1] / 255.0,
          bl = bytes[i + 2] / 255.0;
      final mx = r > g ? (r > bl ? r : bl) : (g > bl ? g : bl);
      final mn = r < g ? (r < bl ? r : bl) : (g < bl ? g : bl);
      final light = (mx + mn) / 2;
      final d = mx - mn;
      // Near-black / near-white pixels carry no usable hue.
      if (light < 0.06 || light > 0.94 || d == 0) continue;
      final sat = d / (1 - (2 * light - 1).abs());
      // Low floor on purpose: a desaturated blue-grey IS the dominant colour of
      // plenty of covers, and a 0.15 cut-off throws those pixels away — leaving
      // a small saturated logo to decide the whole background.
      if (sat < 0.06) continue;
      double hue;
      if (mx == r) {
        hue = ((g - bl) / d) % 6;
      } else if (mx == g) {
        hue = (bl - r) / d + 2;
      } else {
        hue = (r - g) / d + 4;
      }
      hue *= 60;
      if (hue < 0) hue += 360;
      ph[n] = hue;
      ps[n] = sat;
      pl[n] = light;
      pw[n] = 1.0 + sat * 0.5;   // AREA first; saturation only nudges
      n++;
    }
    if (n == 0) return null;   // monochrome cover

    // Pull three clusters, then rank them BY WEIGHT. The seed is the busiest
    // histogram CELL, which is not always the biggest colour: a hue spread over
    // several lightness cells (a shaded magenta wall) loses the seed to a
    // flatter, smaller area (a plain teal band) and would otherwise be demoted
    // to "second colour" on a cover it actually dominates.
    final claimed = Uint8List(n);
    final found = <_Cluster>[];
    for (var k = 0; k < 3; k++) {
      final c = _seek(ph, ps, pl, pw, n, claimed, claim: true);
      if (c == null) break;
      found.add(c);
    }
    if (found.isEmpty) return null;
    found.sort((a, b) => b.weight.compareTo(a.weight));

    final first = found.first;
    final primary = first.toColor();
    // The runner-up only counts if it holds a comparable share AND reads as a
    // different colour; a third cluster gets its chance when the second is just
    // a shade of the first.
    for (final c in found.skip(1)) {
      if (c.weight < first.weight * _altMinShare) break;   // sorted → done
      if (_hueDist(first.hue, c.hue) < _altMinHue) continue;
      return ArtworkTint(primary, c.toColor());
    }
    return ArtworkTint(primary);
  }

  /// Finds the dominant cluster among the not-yet-[claimed] pixels: seeds on
  /// the busiest 3-D histogram cell, then mean-shifts to the actual peak.
  /// Marks its members claimed when [claim] is set.
  static _Cluster? _seek(Float32List ph, Float32List ps, Float32List pl,
      Float32List pw, int n, Uint8List claimed, {required bool claim}) {
    // Coarse 3-D histogram: 24 hues × 3 saturations × 4 lightnesses. Splitting
    // on S and L too is the point — it keeps a dark saturated red and a pale
    // pink from voting for the same bin.
    const hb = 24, sb = 3, lb = 4;
    final hist = Float32List(hb * sb * lb);
    var live = 0.0;
    for (var i = 0; i < n; i++) {
      if (claimed[i] != 0) continue;
      final bh = (ph[i] * hb ~/ 360).clamp(0, hb - 1);
      final bs = (ps[i] * sb).floor().clamp(0, sb - 1);
      final blq = (pl[i] * lb).floor().clamp(0, lb - 1);
      hist[(bh * sb + bs) * lb + blq] += pw[i];
      live += pw[i];
    }
    if (live <= 0) return null;
    var best = 0;
    for (var i = 1; i < hist.length; i++) {
      if (hist[i] > hist[best]) best = i;
    }
    if (hist[best] <= 0) return null;
    final bl0 = best % lb, bs0 = (best ~/ lb) % sb, bh0 = best ~/ (lb * sb);
    var ch = (bh0 + 0.5) * (360 / hb);
    var cs = (bs0 + 0.5) / sb;
    var cl = (bl0 + 0.5) / lb;

    // Mean-shift: recentre on the weighted mean of the window, repeat. Four
    // passes is plenty at this resolution; it stops early once it settles.
    var weight = 0.0;
    for (var pass = 0; pass < 4; pass++) {
      var sumW = 0.0, sumS = 0.0, sumL = 0.0, sumSin = 0.0, sumCos = 0.0;
      for (var i = 0; i < n; i++) {
        if (claimed[i] != 0) continue;
        if (_hueDist(ph[i], ch) > _hueTol) continue;
        if ((ps[i] - cs).abs() > _satTol) continue;
        if ((pl[i] - cl).abs() > _lightTol) continue;
        final w = pw[i];
        final rad = ph[i] * math.pi / 180;
        sumSin += math.sin(rad) * w;   // circular mean: averaging 350° and 10°
        sumCos += math.cos(rad) * w;   // arithmetically would land on 180°
        sumS += ps[i] * w;
        sumL += pl[i] * w;
        sumW += w;
      }
      if (sumW <= 0) break;
      var nh = math.atan2(sumSin, sumCos) * 180 / math.pi;
      if (nh < 0) nh += 360;
      final moved = _hueDist(nh, ch) + (sumS / sumW - cs).abs() * 90 +
          (sumL / sumW - cl).abs() * 90;
      ch = nh;
      cs = sumS / sumW;
      cl = sumL / sumW;
      weight = sumW;
      if (moved < 0.5) break;
    }
    if (weight <= 0) return null;

    if (claim) {
      for (var i = 0; i < n; i++) {
        if (claimed[i] != 0) continue;
        if (_hueDist(ph[i], ch) > _hueTol) continue;
        if ((ps[i] - cs).abs() > _satTol) continue;
        if ((pl[i] - cl).abs() > _lightTol) continue;
        claimed[i] = 1;
      }
    }
    return _Cluster(ch, cs, cl, weight);
  }

  /// Shortest distance between two hues on the wheel, in degrees (0…180).
  static double _hueDist(double a, double b) {
    final d = (a - b).abs() % 360;
    return d > 180 ? 360 - d : d;
  }

  /// Decodes [provider] at ~64px WITHOUT the Flutter image pipeline where
  /// possible. `provider.resolve()` was observed (macOS, during live playback)
  /// to never deliver its frame for a FileImage — the stream just stayed
  /// silent — which hung the extraction. Reading the bytes and calling the
  /// codec directly is deterministic and shares no pipeline state.
  static Future<ui.Image> _decodeDirect(ImageProvider provider) async {
    var p = provider;
    if (p is ResizeImage) p = p.imageProvider;
    final Uint8List? bytes;
    if (p is FileImage) {
      bytes = await p.file.readAsBytes();
    } else if (p is AssetImage) {
      bytes = (await rootBundle.load(p.assetName)).buffer.asUint8List();
    } else if (p is MemoryImage) {
      bytes = p.bytes;
    } else {
      bytes = null;   // network etc. → pipeline fallback below
    }
    if (bytes != null) {
      final codec = await ui.instantiateImageCodec(bytes,
          targetWidth: 64, targetHeight: 64, allowUpscaling: false);
      final frame = await codec.getNextFrame();
      return frame.image;
    }
    return _decodeViaPipeline(ResizeImage(provider,
        width: 64, height: 64, policy: ResizeImagePolicy.fit));
  }

  static Future<ui.Image> _decodeViaPipeline(ImageProvider provider) {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        completer.complete(info.image);
      },
      onError: (e, st) {
        stream.removeListener(listener);
        completer.completeError(e, st);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}

/// One found colour: its HSL centre and the weight (≈ area) it holds.
class _Cluster {
  final double hue, sat, light, weight;
  const _Cluster(this.hue, this.sat, this.light, this.weight);

  Color toColor() => HSLColor.fromAHSL(
        1,
        hue % 360,
        sat.clamp(0.0, 1.0),
        light.clamp(0.0, 1.0),
      ).toColor();
}
