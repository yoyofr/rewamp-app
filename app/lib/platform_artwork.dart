// Per-platform placeholder artwork — shown when a track has no cover of its own.
//
// The mark is rewamp's own synthwave "sunset sun" (a disc sliced by widening
// horizontal gaps near the bottom, see assets/branding/splash/splash_logo.png),
// recoloured to evoke the ORIGIN platform of the format (C64 blue, NES red,
// Amiga orange…) with the platform name below. Same mark everywhere → coherent
// with rewamp; colour + name → "the platform concerned".
//
// The PNGs under assets/placeholders/ are GENERATED from `paintPlatformArtwork`
// by test/gen_placeholders.dart (`flutter test test/gen_placeholders.dart`) —
// edit the palette/painter here and re-run to regenerate. The app loads the
// PNGs (see ArtworkImage); this file is also the single source of truth for the
// extension→platform mapping.

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum SoundPlatform {
  rewamp, c64, nes, snes, gameboy, gba, nds, n64,
  amiga, atariST, atari8, msx, zxSpectrum, amstradCpc,
  pc98, x68000, fmTowns, segaGenesis, segaSaturn, segaDreamcast,
  pcEngine, wonderswan, playstation, adlib, midi,
}

class _Pal {
  final int bgTop, bgBottom, sunTop, sunBottom, accent;
  final String label;
  const _Pal(this.bgTop, this.bgBottom, this.sunTop, this.sunBottom,
      this.accent, this.label);
}

// 0xAARRGGBB. bg = dark platform-tinted gradient, sun = the recoloured disc,
// accent = the platform name.
const Map<SoundPlatform, _Pal> _palettes = {
  SoundPlatform.rewamp:
      _Pal(0xFF160A1E, 0xFF2A1030, 0xFFFF6FB4, 0xFFE81E8C, 0xFFFF6FB4, 'rewamp'),
  SoundPlatform.c64:
      _Pal(0xFF0A0A28, 0xFF1A1A4A, 0xFF9AA8F0, 0xFF4B4BC8, 0xFF9AA8F0, 'C64'),
  SoundPlatform.nes:
      _Pal(0xFF1E0A0A, 0xFF2E0C0C, 0xFFF07070, 0xFFC0392B, 0xFFF07878, 'NES'),
  SoundPlatform.snes:
      _Pal(0xFF15102A, 0xFF241A42, 0xFFB8A8E8, 0xFF6E5AA0, 0xFFB8A8E8, 'SNES'),
  SoundPlatform.gameboy:
      _Pal(0xFF0A1A0A, 0xFF102810, 0xFFB6D24A, 0xFF306230, 0xFF9BBC0F, 'GAME BOY'),
  SoundPlatform.gba:
      _Pal(0xFF120A2A, 0xFF1E1044, 0xFF9A7AF0, 0xFF4E3CA8, 0xFF9A7AF0, 'GBA'),
  SoundPlatform.nds:
      _Pal(0xFF0A1424, 0xFF10203E, 0xFF9AC0F0, 0xFF3A6AD0, 0xFF9AC0F0, 'NINTENDO DS'),
  SoundPlatform.n64:
      _Pal(0xFF0A1A14, 0xFF102E20, 0xFF70D890, 0xFF2AA84E, 0xFF70D890, 'NINTENDO 64'),
  SoundPlatform.amiga:
      _Pal(0xFF1A0F05, 0xFF2C1808, 0xFFFFA850, 0xFFE8631E, 0xFFFFA850, 'AMIGA'),
  SoundPlatform.atariST:
      _Pal(0xFF0A1020, 0xFF121A34, 0xFFF0B040, 0xFFE8631E, 0xFFF0B040, 'ATARI ST'),
  SoundPlatform.atari8:
      _Pal(0xFF14100A, 0xFF241C0C, 0xFFF0C050, 0xFFE89020, 0xFFF0C050, 'ATARI'),
  SoundPlatform.msx:
      _Pal(0xFF1A0A0A, 0xFF2A1010, 0xFFF06060, 0xFFC00000, 0xFFF06868, 'MSX'),
  SoundPlatform.zxSpectrum:
      _Pal(0xFF0A0A0A, 0xFF171717, 0xFFF04A38, 0xFFC0271A, 0xFFF0D030, 'ZX SPECTRUM'),
  SoundPlatform.amstradCpc:
      _Pal(0xFF0A1024, 0xFF101A3A, 0xFFF0D050, 0xFFE8A020, 0xFFF0D858, 'AMSTRAD CPC'),
  SoundPlatform.pc98:
      _Pal(0xFF0A1220, 0xFF101E36, 0xFF60D0E0, 0xFF2A8AA0, 0xFF60D0E0, 'PC-98'),
  SoundPlatform.x68000:
      _Pal(0xFF0F0F16, 0xFF1C1C24, 0xFFC0C0C8, 0xFF70707A, 0xFF90E070, 'X68000'),
  SoundPlatform.fmTowns:
      _Pal(0xFF1A0A16, 0xFF2C0F22, 0xFFF070A8, 0xFFC02068, 0xFFF070A8, 'FM TOWNS'),
  SoundPlatform.segaGenesis:
      _Pal(0xFF0A1024, 0xFF0F1A42, 0xFF4A9AF0, 0xFF0055B8, 0xFF4A9AF0, 'SEGA'),
  SoundPlatform.segaSaturn:
      _Pal(0xFF0C0C1E, 0xFF161636, 0xFFA0A8F0, 0xFF5A5AB0, 0xFFA0A8F0, 'SATURN'),
  SoundPlatform.segaDreamcast:
      _Pal(0xFF14100A, 0xFF241608, 0xFFF0964A, 0xFFE8631E, 0xFFF0964A, 'DREAMCAST'),
  SoundPlatform.pcEngine:
      _Pal(0xFF1A0F05, 0xFF2A1608, 0xFFF0A840, 0xFFE87020, 0xFFF0A840, 'PC ENGINE'),
  SoundPlatform.wonderswan:
      _Pal(0xFF0A1A1A, 0xFF0F2C2C, 0xFF50D0C0, 0xFF208A80, 0xFF50D0C0, 'WONDERSWAN'),
  SoundPlatform.playstation:
      _Pal(0xFF0E0E14, 0xFF1A1A24, 0xFFC8C8D0, 0xFF787884, 0xFFC8C8D0, 'PLAYSTATION'),
  SoundPlatform.adlib:
      _Pal(0xFF0A1020, 0xFF101A32, 0xFF60D0E0, 0xFF2A8AC0, 0xFF60D0E0, 'ADLIB · OPL'),
  SoundPlatform.midi:
      _Pal(0xFF14101E, 0xFF201834, 0xFFC0B0F0, 0xFF7060B0, 0xFFC0B0F0, 'MIDI'),
};

// Extension (lower-case, no dot) → origin platform. Unmapped → rewamp generic.
// Cross-platform PC trackers (xm/it/s3m/mptm/fur…) intentionally fall through to
// the generic rewamp mark — they have no single origin console.
const Map<String, SoundPlatform> _extMap = {
  // Commodore 64
  'sid': SoundPlatform.c64, 'psid': SoundPlatform.c64, 'mus': SoundPlatform.c64,
  // NES / Famicom
  'nsf': SoundPlatform.nes, 'nsfe': SoundPlatform.nes,
  // SNES
  'spc': SoundPlatform.snes, 'rsn': SoundPlatform.snes,
  'snsf': SoundPlatform.snes, 'minisnsf': SoundPlatform.snes,
  // Game Boy
  'gbs': SoundPlatform.gameboy,
  // Game Boy Advance
  'gsf': SoundPlatform.gba, 'minigsf': SoundPlatform.gba,
  // Nintendo DS
  '2sf': SoundPlatform.nds, 'mini2sf': SoundPlatform.nds,
  'ncsf': SoundPlatform.nds, 'minincsf': SoundPlatform.nds,
  // Nintendo 64
  'usf': SoundPlatform.n64, 'miniusf': SoundPlatform.n64,
  // Commodore Amiga (MOD family + the common UADE/AHX/HVL formats).
  // NOTE: do NOT map archive containers (.lha/.lzh/.zip/.7z) to a platform.
  // They say nothing about origin — .lzh is as common on X68000 and PC-98 as
  // .lha is on Amiga. Use platformForName() with the row's own platform field.
  'mod': SoundPlatform.amiga, 'med': SoundPlatform.amiga, 'okt': SoundPlatform.amiga,
  'digi': SoundPlatform.amiga, 'dbm': SoundPlatform.amiga, 'ahx': SoundPlatform.amiga,
  'thx': SoundPlatform.amiga, 'hvl': SoundPlatform.amiga, 'tfmx': SoundPlatform.amiga,
  'mdat': SoundPlatform.amiga, 'cust': SoundPlatform.amiga, 'hip': SoundPlatform.amiga,
  'fc': SoundPlatform.amiga, 'fc13': SoundPlatform.amiga, 'fc14': SoundPlatform.amiga,
  'sfx': SoundPlatform.amiga, 'aon': SoundPlatform.amiga, 'dw': SoundPlatform.amiga,
  'prt': SoundPlatform.amiga,   // Pretracker (pink/Abyss), plays via UADE
  // Atari ST
  'sndh': SoundPlatform.atariST, 'sc68': SoundPlatform.atariST, 'snd': SoundPlatform.atariST,
  '4v': SoundPlatform.atariST,   // Quartet ST score (its SMP.set bank sits alongside)
  // Atari 8-bit / 5200
  'sap': SoundPlatform.atari8,
  // MSX
  'kss': SoundPlatform.msx, 'mgs': SoundPlatform.msx, 'bgm': SoundPlatform.msx,
  'mpk': SoundPlatform.msx, 'mbm': SoundPlatform.msx, 'opx': SoundPlatform.msx,
  // ZX Spectrum
  'ay': SoundPlatform.zxSpectrum, 'ym': SoundPlatform.zxSpectrum, 'vtx': SoundPlatform.zxSpectrum,
  'pt3': SoundPlatform.zxSpectrum, 'pt2': SoundPlatform.zxSpectrum, 'stc': SoundPlatform.zxSpectrum,
  'psg': SoundPlatform.zxSpectrum, 'asc': SoundPlatform.zxSpectrum, 'stp': SoundPlatform.zxSpectrum,
  // Amstrad CPC
  'chp': SoundPlatform.amstradCpc, 'cpc': SoundPlatform.amstradCpc,
  // PC-98
  'm': SoundPlatform.pc98, 'm2': SoundPlatform.pc98, 'mz': SoundPlatform.pc98,
  'opi': SoundPlatform.pc98, 'ovi': SoundPlatform.pc98, 'ozi': SoundPlatform.pc98,
  's98': SoundPlatform.pc98,
  // Sharp X68000
  'mdx': SoundPlatform.x68000,
  // FM Towns
  'eup': SoundPlatform.fmTowns,
  // Sega Mega Drive / Master System / Game Gear
  'gym': SoundPlatform.segaGenesis, 'sgc': SoundPlatform.segaGenesis,
  // Sega Saturn / Dreamcast
  'ssf': SoundPlatform.segaSaturn, 'minissf': SoundPlatform.segaSaturn,
  'dsf': SoundPlatform.segaDreamcast, 'minidsf': SoundPlatform.segaDreamcast,
  // NEC PC-Engine / TurboGrafx-16
  'hes': SoundPlatform.pcEngine,
  // Bandai WonderSwan
  'wsr': SoundPlatform.wonderswan,
  // Sony PlayStation
  'psf': SoundPlatform.playstation, 'minipsf': SoundPlatform.playstation,
  'psf2': SoundPlatform.playstation, 'minipsf2': SoundPlatform.playstation,
  // AdLib / OPL (IBM PC)
  'd00': SoundPlatform.adlib, 'hsc': SoundPlatform.adlib, 'cmf': SoundPlatform.adlib,
  'rol': SoundPlatform.adlib, 'a2m': SoundPlatform.adlib, 'a2t': SoundPlatform.adlib,
  'dro': SoundPlatform.adlib, 'adl': SoundPlatform.adlib, 'bam': SoundPlatform.adlib,
  'rad': SoundPlatform.adlib, 'rix': SoundPlatform.adlib, 'lds': SoundPlatform.adlib,
  'laa': SoundPlatform.adlib, 'imf': SoundPlatform.adlib, 'ksm': SoundPlatform.adlib,
  // Standard MIDI
  'mid': SoundPlatform.midi, 'midi': SoundPlatform.midi, 'kar': SoundPlatform.midi,
  'rmi': SoundPlatform.midi,
};

/// Origin platform from the SERVER's platform name (`SearchResult.platform`,
/// browse_folder's `platform`, …). This is the authoritative signal when the
/// file extension is a mere container: an UnExotica `.lha` is Amiga, an
/// X68000 `.lzh` is not, and the extension cannot tell them apart.
///
/// Matching is loose on purpose — the catalogue mixes spellings ("Amiga",
/// "Commodore Amiga", "Sharp X68000", "PC-98"/"PC98"). Unknown → rewamp.
SoundPlatform platformForName(String? name) {
  if (name == null || name.trim().isEmpty) return SoundPlatform.rewamp;
  final n = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  // Tokens are matched IN ORDER, most specific first ("gameboyadvance" before
  // "gameboy", "segasaturn" before the Sega catch-all, "superfamicom" before
  // "famicom"). Built against the catalogue's real 58 platform names
  // (search_facets facet_kind='platform'), not guessed spellings. Platforms
  // with no mark of their own (Apple II, Arcade, Neo Geo, Vectrex, X1…) fall
  // through to the generic rewamp placeholder on purpose.
  const rules = <(List<String>, SoundPlatform)>[
    (['amiga'], SoundPlatform.amiga),
    (['atarist'], SoundPlatform.atariST),
    (['atari8bit', 'atari5200', 'atari7800'], SoundPlatform.atari8),
    (['c64'], SoundPlatform.c64),
    (['x68000'], SoundPlatform.x68000),
    (['pc98', 'pc88'], SoundPlatform.pc98),
    (['fmtowns'], SoundPlatform.fmTowns),
    (['zxspectrum'], SoundPlatform.zxSpectrum),
    (['amstradcpc'], SoundPlatform.amstradCpc),
    (['msx'], SoundPlatform.msx),
    (['gameboyadvance'], SoundPlatform.gba),
    (['gameboy'], SoundPlatform.gameboy),
    (['nintendo64'], SoundPlatform.n64),
    (['nintendods'], SoundPlatform.nds),
    (['snes', 'superfamicom', 'supernintendo'], SoundPlatform.snes),
    (['nes', 'famicom'], SoundPlatform.nes),
    (['dreamcast'], SoundPlatform.segaDreamcast),
    (['saturn'], SoundPlatform.segaSaturn),
    (['megadrive', 'mastersystem', 'gamegear', 'segacd', 'genesis',
      'sg1000', 'sc3000', '32x'], SoundPlatform.segaGenesis),
    (['pcengine', 'supergrafx', 'turbografx'], SoundPlatform.pcEngine),
    (['wonderswan'], SoundPlatform.wonderswan),
    (['playstation'], SoundPlatform.playstation),
    (['ibmpc'], SoundPlatform.adlib),
  ];
  for (final (tokens, platform) in rules) {
    for (final t in tokens) {
      if (n.contains(t)) return platform;
    }
  }
  return SoundPlatform.rewamp;
}

SoundPlatform platformForExt(String? ext) {
  if (ext == null) return SoundPlatform.rewamp;
  var e = ext.toLowerCase();
  if (e.startsWith('.')) e = e.substring(1);
  return _extMap[e] ?? SoundPlatform.rewamp;
}

/// Origin platform from a file path or a bare extension/format hint.
SoundPlatform platformForPath(String? path) {
  if (path == null || path.isEmpty) return SoundPlatform.rewamp;
  // strip a query suffix (?subsong=N) and archive members if present
  var s = path.split('?').first;
  final dot = s.lastIndexOf('.');
  if (dot < 0 || dot == s.length - 1) {
    // maybe the whole string IS the extension/format (e.g. "sid")
    return platformForExt(s);
  }
  final byExt = platformForExt(s.substring(dot + 1));
  if (byExt != SoundPlatform.rewamp) return byExt;
  // Amiga PREFIX convention: the format sits BEFORE the dot ("mdat.monkey
  // island", "cust.turrican"), so the rule above just read ".monkey island"
  // as an extension and found nothing — every TFMX/custom module fell back to
  // the generic mark in the mini player and the recents rail. The leading
  // token is looked up in the same table, and only accepted when it really
  // names a format; trying it AFTER the extension keeps a normal name like
  // "fc.foo.sid" on its true extension.
  final slash = s.lastIndexOf(RegExp(r'[/\\]'));
  final base = slash >= 0 ? s.substring(slash + 1) : s;
  final firstDot = base.indexOf('.');
  if (firstDot > 0) return platformForExt(base.substring(0, firstDot));
  return SoundPlatform.rewamp;
}

String _idOf(SoundPlatform p) => p.name.toLowerCase();

/// Asset path of the generated placeholder for [p].
String platformAssetForPlatform(SoundPlatform p) =>
    'assets/placeholders/${_idOf(p)}.png';

/// Asset path of the placeholder appropriate for [path] (file / ext / format).
String platformAssetForPath(String? path) =>
    platformAssetForPlatform(platformForPath(path));

/// Placeholder asset choosing the best available signal: the server's platform
/// NAME first (authoritative), the file/extension hint only as a fallback.
/// Needed because a container extension (.lha/.lzh/.zip/.7z) carries no origin.
String platformAssetFor({String? platformName, String? pathOrExt}) {
  final byName = platformForName(platformName);
  if (byName != SoundPlatform.rewamp) return platformAssetForPlatform(byName);
  return platformAssetForPath(pathOrExt);
}

/// Paint the rewamp sunset-sun mark, recoloured for [p], onto [canvas]. Shared
/// by the app and the PNG generator so the assets always match this code.
/// [fontFamily] lets the generator inject a real font (the widget-tester's
/// default renders every glyph as a box).
void paintPlatformArtwork(Canvas canvas, Size size, SoundPlatform p,
    {String? fontFamily}) {
  final pal = _palettes[p] ?? _palettes[SoundPlatform.rewamp]!;
  final w = size.width, h = size.height;
  final rect = Offset.zero & size;

  // Background: vertical platform-tinted gradient.
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0), Offset(0, h),
        [Color(pal.bgTop), Color(pal.bgBottom)],
      ),
  );

  // Faint horizon glow behind the sun.
  final cx = w * 0.5, cy = h * 0.42;
  final r = w * 0.25;
  canvas.drawCircle(
    Offset(cx, cy), r * 1.9,
    Paint()
      ..shader = ui.Gradient.radial(Offset(cx, cy), r * 1.9, [
        Color(pal.sunBottom).withValues(alpha: 0.22),
        const Color(0x00000000),
      ]),
  );

  // The disc, in its own layer so the synthwave slits reveal the BACKGROUND
  // (BlendMode.clear on the layer) rather than punching transparent holes.
  final discRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
  canvas.saveLayer(discRect.inflate(2), Paint());
  canvas.clipRRect(RRect.fromRectXY(discRect, r, r));
  canvas.drawRect(
    discRect,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx, cy - r), Offset(cx, cy + r),
        [Color(pal.sunTop), Color(pal.sunBottom)],
      ),
  );
  // Widening horizontal gaps across the lower half of the disc.
  final gapPaint = Paint()..blendMode = BlendMode.clear;
  double y = cy + r * 0.14;
  double gap = r * 0.05;
  double step = r * 0.21;
  while (y < cy + r) {
    canvas.drawRect(Rect.fromLTWH(cx - r, y, r * 2, gap), gapPaint);
    y += step;
    gap *= 1.32;
  }
  canvas.restore();

  // Platform name, in the accent colour, centered below the sun.
  final tp = TextPainter(
    text: TextSpan(
      text: pal.label.toUpperCase(),
      style: TextStyle(
        color: Color(pal.accent),
        fontFamily: fontFamily,
        fontSize: (h * 0.072).clamp(12.0, 56.0),
        fontWeight: FontWeight.w800,
        letterSpacing: w * 0.005,
        height: 1.0,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: w * 0.88);
  tp.paint(canvas, Offset((w - tp.width) / 2, cy + r + h * 0.05));

  // Small equalizer bars pinned at the very bottom — the rewamp synthwave signature.
  final barPaint = Paint()..color = Color(pal.accent).withValues(alpha: 0.8);
  const n = 7;
  final bw = w * 0.026;
  final gapW = w * 0.02;
  final totalW = n * bw + (n - 1) * gapW;
  final startX = (w - totalW) / 2;
  final baseY = h * 0.955;
  for (var i = 0; i < n; i++) {
    // Deterministic pseudo-random heights (no RNG → reproducible generator).
    final t = math.sin(i * 1.7 + 0.5).abs();
    final bh = h * (0.02 + 0.05 * t);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX + i * (bw + gapW), baseY - bh, bw, bh),
        Radius.circular(bw * 0.35),
      ),
      barPaint,
    );
  }
}

/// All platforms (for the generator to iterate).
List<SoundPlatform> get allSoundPlatforms => SoundPlatform.values;
