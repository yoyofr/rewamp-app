import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rewamp_audio/rewamp_audio.dart';

import 'user_settings.dart';
import 'viz_gl_ownership.dart';
import 'viz_platform_view.dart';

/// Debug escape hatch: force the Dart CustomPaint grid even where the GL
/// renderer (rewamp_pattern_render.cpp, mode 4) is available, to A/B the two
/// paths. The painter is NOT dead code — it is also the real fallback on
/// platforms with no GL display path (see [_PatternScopeWidgetState._useGl]),
/// exactly like the other scope widgets keep theirs.
const bool kPatternVizForceCpu = false;

/// Upper bound on the decode look-ahead the synthesized grid may request.
/// MUST NOT exceed DS_LEAD_MAX_SECS in rewamp_datasource.c — the engine clamps
/// to the ring anyway, but asking beyond it silently caps and the leading edge
/// stays blank with no hint why. The lead is also mute/settings latency, so
/// this is a ceiling, not a target: a very tall surface at a very small zoom
/// hits it and shows a little empty edge, which beats a multi-second delay on
/// every mute.
const double kPatternLookaheadMaxSecs = 8.0;

/// Tracker "pattern" visualizer: the classic channels × rows grid of the module
/// being played, scrolling with the heard playback position. Native pattern
/// data (libopenmpt today, Furnace next) via RewampAudio.fetchPatternSong; the
/// live (order,row) cursor is consumer-synced in C so the highlight matches what
/// is heard, not what is decoded ~2 s ahead.
///
/// Rendered in C/OpenGL (rewamp_pattern_render.cpp, mode 4) wherever a GL
/// display path exists — the Flutter Texture on Apple, the SurfaceView
/// PlatformView on Android. Desktop Linux/Windows have neither, and there the
/// Dart CustomPaint grid below draws it instead (same fallback arrangement as
/// the other scope widgets).
///
/// Options (UserSettings, toggled from the in-viz overlay):
///   - scroll mode: fixed bar (row centered) vs moving bar (page-anchored);
///   - per-channel volume bars along the bottom;
///   - color scheme evoking classic trackers (PatternPalette.presets).
class PatternScopeWidget extends StatefulWidget {
  final RewampAudio audio;

  /// Changing this re-fetches the song (a new track loaded).
  final String? trackKey;

  const PatternScopeWidget({super.key, required this.audio, this.trackKey});

  @override
  State<PatternScopeWidget> createState() => _PatternScopeWidgetState();
}

class _PatternScopeWidgetState extends State<PatternScopeWidget>
    with SingleTickerProviderStateMixin {
  PatternSong? _song;
  int _order = -1;
  int _row = -1;
  int _fetchTries = 0;
  List<int> _vols = const [];
  late final Ticker _ticker;

  // GPU path (Apple Texture; Android uses the SurfaceView PlatformView).
  int  _gpuTextureId = -1;
  Size _gpuSize      = Size.zero;
  double _xScroll    = 0;

  // GL needs a display path too: Android renders via the SurfaceView
  // PlatformView, elsewhere via the Flutter Texture (vizGpuAvailable). Desktop
  // Linux/Windows have neither → CustomPaint fallback keeps working.
  bool get _useGl =>
      !kPatternVizForceCpu &&
      widget.audio.hasPatternGl &&
      (!kIsWeb && Platform.isAndroid || widget.audio.vizGpuAvailable);

  @override
  void initState() {
    super.initState();
    _pushGlOptions();
    if (!_useGl) _fetch();
    UserSettings.instance.addListener(_onSettings);
    _ticker = createTicker(_onTick)..start();
  }

  void _pushGlOptions() {
    // A synthesized grid (no NATIVE tracker data — the rows are built from the
    // note timeline) has no per-cell volume and no page to scroll: force volume
    // bars OFF and the bar FIXED regardless of the persisted setting. The
    // matching controls are hidden too (see VizSelectorWidget._patternControls).
    // A style may pin the bar too (ProTracker) — same treatment, and the
    // renderer enforces it on its side whatever we push here.
    final native  = widget.audio.patternSupported;
    final palette = UserSettings.instance.patternPalette;
    final pinned  = PatternPalette.selectedPinsBar(palette);
    widget.audio.setPatternVizOptions(
      palette,
      (native && !pinned) ? UserSettings.instance.patternScrollMode : 0,
      native && UserSettings.instance.patternShowVolume,
      smoothScroll: UserSettings.instance.patternSmoothScroll,
    );
    widget.audio.setPatternVizOpaqueBg(UserSettings.instance.patternOpaqueBg);
    widget.audio.setPatternVizLayout(
      UserSettings.instance.patternSize,
      UserSettings.instance.patternColumns,
    );
  }

  void _onSettings() {
    _pushGlOptions();
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(PatternScopeWidget old) {
    super.didUpdateWidget(old);
    if (old.trackKey != widget.trackKey) {
      _song = null;
      _order = _row = -1;
      _fetchTries = 0;
      _fetch();
    }
  }

  void _fetch() {
    if (!widget.audio.patternSupported) return;
    final s = widget.audio.fetchPatternSong();
    if (s != null && mounted) setState(() => _song = s);
  }

  void _initGpu(Size size) {
    if (size == _gpuSize && _gpuTextureId >= 0) return;
    if (_gpuTextureId >= 0) {
      widget.audio.vizResizeRegister(size.width.toInt(), size.height.toInt());
      _gpuSize = size;
      return;
    }
    final id =
        widget.audio.patternvizRegister(size.width.toInt(), size.height.toInt());
    if (id >= 0) setState(() { _gpuTextureId = id; _gpuSize = size; });
  }

  bool? _optNative;   // last patternSupported the GL options were pushed for
  bool _lookahead = false;
  double _lookaheadSecs = 0.0;

  void _onTick(Duration elapsed) {
    if (_useGl) {
      // Track change can flip native↔synthesized (the widget persists across
      // tracks) → re-push options so bar-fixed / volume-off is applied for a
      // synthesized grid and restored for a native one.
      final native = widget.audio.patternSupported;
      if (native != _optNative) { _optNative = native; _pushGlOptions(); }
      // Synthesized mode (no real pattern data) draws future rows from the
      // note timeline → needs the decode look-ahead. Tracker data does not,
      // and look-ahead delays mute/settings changes — keep it off there.
      final want = !widget.audio.patternSupported;
      // The look-ahead must cover the FUTURE rows on screen: the playhead sits
      // at the vertical centre, so half the visible rows are future.
      //
      // ASK THE RENDERER — do not recompute it here. Row height is a fixed
      // logical size × surface DPR × user zoom (rewamp_pattern_render.cpp,
      // PV_BASE_ROW_PX); it used to be a fraction of the view. The old copy of
      // that formula lived here, ignored both the DPR and the zoom, and on a
      // large high-DPI surface asked for ~2s where the grid needed 3-5 → the
      // leading edge stayed blank. On Android it was worse still: that path is
      // a SurfaceView, _initGpu never runs, so _gpuSize stayed zero and the
      // estimate was built on a 400px fallback whatever the real screen.
      final wantSecs = !want
          ? 0.0
          : () {
              final native = widget.audio.patternVizFutureSeconds;
              if (native != null && native > 0) {
                return (native + 0.5).clamp(1.0, kPatternLookaheadMaxSecs);
              }
              // Stale binary: keep a rough estimate rather than none.
              final h = _gpuSize.height > 0 ? _gpuSize.height : 400.0;
              final visible = (h / 32.0).clamp(1.0, 200.0);
              return (visible / 2.0 / 8.0 + 0.5)
                  .clamp(1.0, kPatternLookaheadMaxSecs);
            }();
      if (want != _lookahead || (want && (wantSecs - _lookaheadSecs).abs() > 0.2)) {
        _lookahead = want;
        _lookaheadSecs = wantSecs;
        widget.audio.setLookaheadSeconds(wantSecs);
      }
      if (_gpuTextureId >= 0) {
        widget.audio.vizSetFrameTime(elapsed.inMicroseconds / 1e6);
        widget.audio.patternvizRenderAndNotify();
      }
      return;
    }
    // The plugin's open() builds the pattern table during loadFile; on a fresh
    // track the first fetch may land a hair early — retry a few frames.
    if (_song == null) {
      if (_fetchTries < 30 && widget.audio.patternSupported) {
        _fetchTries++;
        _fetch();
      }
      return;
    }
    final c = widget.audio.patternCursor();
    final showVol = UserSettings.instance.patternShowVolume;
    var dirty = false;
    if (c != null && (c.order != _order || c.row != _row)) {
      _order = c.order;
      _row = c.row;
      dirty = true;
    }
    if (showVol) {
      // Live per-channel level (0..~127), consumer-side — repaint every frame
      // for smooth meters.
      final nch = _song!.numChannels;
      final v = List<int>.generate(nch, (i) => widget.audio.channelVolume(i));
      _vols = v;
      dirty = true;
    } else if (_vols.isNotEmpty) {
      _vols = const [];
      dirty = true;
    }
    if (dirty && mounted) setState(() {});
  }

  @override
  void dispose() {
    // NB: do NOT clear the look-ahead here. Switching to another look-ahead
    // viz (notes) builds its widget and sets its own lead BEFORE this dispose
    // runs (Flutter disposes the outgoing child at frame end), so clearing here
    // would clobber the incoming viz's setting. VizSelectorWidget owns the
    // release: it clears when the active effect isn't notes/patterns, or when
    // the whole selector goes away.
    UserSettings.instance.removeListener(_onSettings);
    _ticker.dispose();
    // GL context is shared by all visualizers and owned by VizSelectorWidget
    // while on screen — same rule as the notes/scope widgets.
    if (_gpuTextureId >= 0 && !kVizGlOwnedBySelector) {
      widget.audio.vizUnregister();
    }
    super.dispose();
  }

  /// Horizontal drag scrolls the GL grid (wide modules). Wrapping only the GL
  /// surface: same arena behaviour as the CPU path's SingleChildScrollView —
  /// it wins horizontal drags over the player's swipe-to-skip, deliberately.
  /// [pixelScale] converts the drag delta (logical px) into the native render
  /// space. On Android the SurfaceView renders at PHYSICAL px (its viewport is
  /// the surface's physical w/h) and `_xScroll` is a native-px offset, so a raw
  /// logical delta scrolled at 1/devicePixelRatio of the finger. The Apple
  /// Texture path registers the GL at logical size → scale 1.0.
  Widget _glGestures(Widget child, {double pixelScale = 1.0}) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) {
          _xScroll =
              (_xScroll - d.delta.dx * pixelScale).clamp(0.0, 100000.0);
          widget.audio.setPatternVizXScroll(_xScroll);
        },
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    if (_useGl) {
      // Android: SurfaceView PlatformView (mode 4) — native GL straight into a
      // SurfaceFlinger layer, no Flutter stage in the display path.
      if (!kIsWeb &&
          Platform.isAndroid &&
          !kVizForceTextureOnAndroid) {
        // Physical-px surface: the native font is a fixed logical size × DPR.
        final dpr = MediaQuery.of(context).devicePixelRatio;
        widget.audio.setPatternVizPixelScale(dpr);
        return _glGestures(const RewampVizPlatformView(mode: 4),
            pixelScale: dpr);
      }
      // Apple/desktop Texture path. Render the pattern GL at DEVICE resolution
      // (logical × DPR) so its TEXT is crisp on a Retina display instead of a
      // logical-res surface the OS upscales. Only THIS visualizer opts in — the
      // others (stereo/voices/notes/projectM) stay logical-sized for perf, they
      // are smooth curves that don't need the resolution. Guarded on
      // hasPatternPixelScale: without the native pixscale setter the font would
      // not scale up with the bigger buffer → a half-size grid, so fall back to
      // logical (correct size, just soft) on a stale binary.
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final scale = (widget.audio.hasPatternPixelScale && dpr > 1.0) ? dpr : 1.0;
      widget.audio.setPatternVizPixelScale(scale);
      return LayoutBuilder(builder: (ctx, constraints) {
        final w = (constraints.maxWidth * scale).toInt();
        final h = (constraints.maxHeight * scale).toInt();
        if (w > 0 && h > 0) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _initGpu(Size(w.toDouble(), h.toDouble())));
        }
        if (_gpuTextureId >= 0) {
          return _glGestures(
            SizedBox(
              width: double.infinity, height: double.infinity,
              child: Texture(textureId: _gpuTextureId),
            ),
            pixelScale: scale,
          );
        }
        return const SizedBox.expand();
      });
    }
    final song = _song;
    final palette = PatternPalette.presets[
        UserSettings.instance.patternPalette
            .clamp(0, PatternPalette.presets.length - 1)];
    if (song == null || song.numChannels <= 0) {
      return ColoredBox(
        color: palette.bg,
        child: Center(
          child: Icon(Icons.grid_off, color: palette.noteEmpty, size: 40),
        ),
      );
    }
    return ColoredBox(
      color: palette.bg,
      child: LayoutBuilder(builder: (ctx, constraints) {
        const cellW = _PatternPainter.cellWidth;
        const gutterW = _PatternPainter.gutterWidth;
        // FastTracker II has no header strip — its channel numbers are drawn as
        // a corner overlay inside the grid instead.
        final strip = palette.headerStyle == PatternHeaderStyle.strip;
        final headerH = strip ? _PatternPainter.headerHeight : 0.0;
        final fullW = gutterW + song.numChannels * cellW;
        final totalH = constraints.maxHeight;
        final gridH = (totalH - headerH).clamp(0.0, double.infinity);

        // Header (channel numbers) + grid, stacked vertically. Both are fixed
        // width so they scroll horizontally IN SYNC — the header pins to the
        // top while the columns slide under it. Vertical scrolling is the
        // painter's job (it centers / follows the heard row).
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (strip)
              CustomPaint(
                size: Size(fullW, headerH),
                painter: _PatternHeaderPainter(
                    channels: song.numChannels, palette: palette),
              ),
            SizedBox(
              width: fullW,
              height: gridH,
              child: Stack(
                children: [
                  // Grid text is isolated in a RepaintBoundary + repaints only on
                  // a row/order change (shouldRepaint) — the per-frame volume
                  // layer above never forces the text to re-lay out.
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _PatternPainter(
                          song: song,
                          order: _order,
                          row: _row,
                          palette: palette,
                          scrollMode: UserSettings.instance.patternScrollMode,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  if (_vols.isNotEmpty)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _VolumeBarsPainter(
                          song: song, palette: palette, volumes: _vols),
                        child: const SizedBox.expand(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );

        if (fullW <= constraints.maxWidth) {
          return SizedBox(width: constraints.maxWidth, height: totalH, child: content);
        }
        // Horizontal scroll when channels overflow. dragDevices includes mouse
        // so a click-drag scrolls too (default only allows touch/trackpad).
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(ctx).copyWith(dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          }),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: content,
          ),
        );
      }),
    );
  }
}

/// How a palette renders channel labels: a top strip vs FastTracker II's big
/// white number overlaid in each channel's top-left corner (sticky on scroll).
enum PatternHeaderStyle { strip, corner }

/// Volume-meter rendering: a flat solid bar, a Y-fixed gradient (ProTracker's
/// green→yellow→red scope), or DOS-style stacked blocks with a bicolour top
/// (ScreamTracker 3 / Impulse Tracker).
enum PatternVolStyle { solid, gradient, segmented }

/// A color scheme for the pattern grid, each evoking a historic tracker's real
/// look (see the reference screenshots). Proper-noun preset names (tracker
/// products) are NOT localized, like 'projectM'.
class PatternPalette {
  final String name;
  final Color bg;
  final Color headerBg;
  final Color headerText;
  final Color rowNum;
  final Color beatRowNum;      // row number on beat rows (every 4th)
  final Color note;
  final Color noteEmpty;       // empty cell dots
  final Color instrument;
  final Color volume;
  final Color fx;
  /// Effect PARAMETER (the value digits) when a style wants it apart from the
  /// command; null = draw it in [fx], which is what every stock style does.
  /// Mirrors PvPalette.fxParam in rewamp_pattern_render.cpp (0 there = null
  /// here) — the GL renderer is what actually draws on every shipping platform.
  final Color? fxParam;
  final Color highlight;       // current-row bar (alpha baked per tracker)
  final Color? currentRowText; // override ALL current-row text (ProTracker: white)
  final Color beatBg;          // faint band every 4th row (measure = ×2)
  final Color separator;       // channel separators
  final double separatorWidth; // wider + opaque boxes off channels (ST3/IT)
  final Color volBar;          // per-channel volume meter (solid)
  final PatternVolStyle volStyle;
  final List<Color>? volGradient; // gradient style: top→bottom colours
  final Color? volLow;         // segmented style: lower ~3/4
  final Color? volHigh;        // segmented style: top ~1/4
  final double volBarWidth;
  final PatternHeaderStyle headerStyle;

  const PatternPalette({
    required this.name,
    required this.bg,
    required this.headerBg,
    required this.headerText,
    required this.rowNum,
    required this.beatRowNum,
    required this.note,
    required this.noteEmpty,
    required this.instrument,
    required this.volume,
    required this.fx,
    this.fxParam,
    required this.highlight,
    this.currentRowText,
    required this.beatBg,
    required this.separator,
    this.separatorWidth = 1.0,
    required this.volBar,
    this.volStyle = PatternVolStyle.solid,
    this.volGradient,
    this.volLow,
    this.volHigh,
    this.volBarWidth = 5.0,
    this.headerStyle = PatternHeaderStyle.strip,
    this.pinsBar = false,
  });

  /// The style PINS the playing line mid-screen (ProTracker): the page scrolls
  /// under it, never the line. The GL renderer enforces it (PvPalette
  /// .forceFixedBar in rewamp_pattern_render.cpp — same rule, kept in sync);
  /// here it drives what is PUSHED to the engine and hides the scroll toggle,
  /// so the option is never shown as a dead switch.
  final bool pinsBar;

  /// Whether the currently selected style pins the bar.
  static bool selectedPinsBar(int index) =>
      presets[index.clamp(0, presets.length - 1)].pinsBar;

  static const presets = <PatternPalette>[
    // Rewamp — the app's own dark scheme.
    PatternPalette(
      name: 'Rewamp',
      bg: Color(0xFF0A0A0A), headerBg: Color(0xFF16181C),
      headerText: Color(0xFFB4BCC8),
      rowNum: Color(0xFF6A6A6A), beatRowNum: Color(0xFF9AA4B0),
      note: Color(0xFFE8F0FF), noteEmpty: Color(0xFF3A3A3A),
      instrument: Color(0xFF5FC9F8), volume: Color(0xFFA8E063),
      fx: Color(0xFFF7A85C), highlight: Color(0x33FFFFFF),
      beatBg: Color(0x0EFFFFFF), separator: Color(0x18FFFFFF),
      volBar: Color(0xFFA8E063),
    ),
    // ProTracker (Amiga) — monochrome blue on black, current row inverted white,
    // Workbench-grey chrome, green→yellow→red VU meters (colour by height).
    PatternPalette(
      name: 'ProTracker',
      bg: Color(0xFF000000), headerBg: Color(0xFFA0A0A0),
      headerText: Color(0xFF202020),
      rowNum: Color(0xFF4E6CE0), beatRowNum: Color(0xFFFFFFFF),
      note: Color(0xFF4E6CE0), noteEmpty: Color(0xFF23305E),
      instrument: Color(0xFF4E6CE0), volume: Color(0xFF4E6CE0),
      fx: Color(0xFF4E6CE0), highlight: Color(0x24FFFFFF),
      currentRowText: Color(0xFFFFFFFF),
      beatBg: Color(0x14304AC0), separator: Color(0xFF3A3A5A),
      volBar: Color(0xFF35C935),
      volStyle: PatternVolStyle.gradient,
      volGradient: [Color(0xFFE83A2A), Color(0xFFE8D020), Color(0xFF35C935)],
      volBarWidth: 10.0,
      pinsBar: true,
    ),
    // ScreamTracker 3 — tan/sand DOS chrome, black pattern, grey/white text,
    // olive highlight, EGA-green VU.
    PatternPalette(
      name: 'ScreamTracker 3',
      bg: Color(0xFF000000), headerBg: Color(0xFFA99A66),
      headerText: Color(0xFF1A1400),
      rowNum: Color(0xFF7A7A6A), beatRowNum: Color(0xFFD8D8C0),
      note: Color(0xFFE8E8E0), noteEmpty: Color(0xFF3A3A32),
      instrument: Color(0xFFB8B8A8), volume: Color(0xFFB8B8A8),
      fx: Color(0xFFB8B8A8), highlight: Color(0x55A08A3A),
      beatBg: Color(0x14A08A3A), separator: Color(0xFFA99A66), separatorWidth: 3.0,
      volBar: Color(0xFF44CC44),
      volStyle: PatternVolStyle.segmented,
      volLow: Color(0xFF33CC33), volHigh: Color(0xFFE03020), volBarWidth: 9.0,
    ),
    // FastTracker II — NO header strip: a big white channel number overlaid in
    // each column's top-left corner. White notes + steel-blue values on black,
    // solid blue current-row bar, blue dividers, light-blue VU (solid: FT2 is
    // a flat UI — the gradient look belongs to ProTracker), slightly wider.
    PatternPalette(
      name: 'FastTracker II',
      bg: Color(0xFF000000), headerBg: Color(0xFF000000),
      headerText: Color(0xFFFFFFFF),
      rowNum: Color(0xFF8090B0), beatRowNum: Color(0xFFE0E4EC),
      note: Color(0xFFBFC4CE), noteEmpty: Color(0xFF303848),
      instrument: Color(0xFF7E98CC), volume: Color(0xFF7E98CC),
      fx: Color(0xFF7E98CC), highlight: Color(0xE02E50B0),
      beatBg: Color(0x1A2E50B0), separator: Color(0xFF3A6AD0),
      volBar: Color(0xFF9EC2F0), volBarWidth: 8.0,
      headerStyle: PatternHeaderStyle.corner,
    ),
    // Impulse Tracker (default scheme) — tan DOS chrome, black pattern,
    // MONOCHROME GREEN text, light row numbers, maroon current-row bar.
    PatternPalette(
      name: 'Impulse Tracker',
      bg: Color(0xFF000000), headerBg: Color(0xFFB6A784),
      headerText: Color(0xFF241C0A),
      rowNum: Color(0xFFC8C0AC), beatRowNum: Color(0xFFECE4D0),
      note: Color(0xFF5CBE5C), noteEmpty: Color(0xFF244A24),
      instrument: Color(0xFF4AA24A), volume: Color(0xFF4AA24A),
      fx: Color(0xFF4AA24A), highlight: Color(0x99542A2A),
      beatBg: Color(0x14FFFFFF), separator: Color(0xFFB6A784), separatorWidth: 3.0,
      volBar: Color(0xFF4EA84E),
      volStyle: PatternVolStyle.segmented,
      volLow: Color(0xFFC89A2E), volHigh: Color(0xFFE03020), volBarWidth: 9.0,
    ),
    // MilkyTracker — FT2-clone colours: white note, green instr, cyan vol,
    // magenta fx, yellow channel headers + beat rows, blue dividers.
    PatternPalette(
      name: 'MilkyTracker',
      bg: Color(0xFF000000), headerBg: Color(0xFF1A1A2A),
      headerText: Color(0xFFE8E030),
      rowNum: Color(0xFF5A5A5A), beatRowNum: Color(0xFFE8E030),
      note: Color(0xFFE8ECF0), noteEmpty: Color(0xFF2A2A34),
      instrument: Color(0xFF3FD23F), volume: Color(0xFF50B8E8),
      fx: Color(0xFFE060E0), highlight: Color(0x66701460),
      beatBg: Color(0x14283048), separator: Color(0xFF3A5AC0),
      volBar: Color(0xFF3FD23F),
    ),
  ];
}

/// Lightens (f>0) or darkens (f<0) a colour toward white/black.
Color _shiftColor(Color c, double f) => f >= 0
    ? Color.lerp(c, const Color(0xFFFFFFFF), f)!
    : Color.lerp(c, const Color(0xFF000000), -f)!;

/// A vertical channel separator. When wide (ST3/IT) it's a 3-tone bevel
/// (dark | base | light) for a lit-groove look that stays visible on BOTH the
/// black pattern and the tan header — and is rendered identically in the header
/// and grid so the column is continuous across the seam. 1px = flat.
void _paintSeparator(
    Canvas canvas, double x, double top, double h, PatternPalette p) {
  final w = p.separatorWidth;
  if (w < 3) {
    canvas.drawRect(Rect.fromLTWH(x, top, w, h), Paint()..color = p.separator);
    return;
  }
  canvas.drawRect(Rect.fromLTWH(x, top, 1, h),
      Paint()..color = _shiftColor(p.separator, -0.5));
  canvas.drawRect(Rect.fromLTWH(x + 1, top, w - 2, h),
      Paint()..color = p.separator);
  canvas.drawRect(Rect.fromLTWH(x + w - 1, top, 1, h),
      Paint()..color = _shiftColor(p.separator, 0.5));
}

class _PatternPainter extends CustomPainter {
  final PatternSong song;
  final int order; // current order-list index
  final int row;   // current row within that order's pattern
  final PatternPalette palette;
  final int scrollMode;      // 0 = fixed bar, 1 = moving bar (page)

  const _PatternPainter({
    required this.song,
    required this.order,
    required this.row,
    required this.palette,
    required this.scrollMode,
  });

  static const double cellWidth = 118.0;
  static const double gutterWidth = 34.0;
  static const double rowHeight = 15.0;
  static const double fontSize = 11.0;
  /// Monospace advance at [fontSize] — the fallback painter lays its columns
  /// out by hand (30 / 20 px steps above), so a second draw inside a field
  /// (the effect parameter) needs the glyph step explicitly.
  static const double charWidth = fontSize * 0.6;
  static const double headerHeight = 18.0;

  static const _noteNames = [
    'C-', 'C#', 'D-', 'D#', 'E-', 'F-', 'F#', 'G-', 'G#', 'A-', 'A#', 'B-'
  ];

  static String _noteText(int n) {
    if (n == PatternNote.empty) return '...';
    if (n == PatternNote.off)   return '===';
    if (n == PatternNote.cut)   return '^^^';
    if (n == PatternNote.fade)  return '~~~';
    if (n < 0) return '...';
    return '${_noteNames[n % 12]}${n ~/ 12}';
  }

  static String _hex2(int v) =>
      v < 0 ? '..' : v.toRadixString(16).toUpperCase().padLeft(2, '0');

  @override
  void paint(Canvas canvas, Size size) {
    // Clip: rows are drawn one past each edge (partial rows), and an unclipped
    // CustomPaint would spill them outside the viz area — visible for narrow
    // (non-scrolled) modules that skip the SingleChildScrollView clip.
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.bg);
    if (order < 0 || order >= song.numOrders) return;

    if (scrollMode == 1) {
      _paintMoving(canvas, size);
    } else {
      _paintFixed(canvas, size);
    }
    if (palette.headerStyle == PatternHeaderStyle.corner) {
      _paintCornerLabels(canvas, size);
    }
  }

  // Fixed bar: current row centered, timeline scrolls under it; previous/next
  // orders show dimmed above and below.
  void _paintFixed(Canvas canvas, Size size) {
    final centerY = size.height / 2 - rowHeight / 2;
    final rowsAbove = (centerY / rowHeight).ceil() + 1;
    final rowsBelow = ((size.height - centerY) / rowHeight).ceil() + 1;

    canvas.drawRect(
      Rect.fromLTWH(0, centerY, size.width, rowHeight),
      Paint()..color = palette.highlight,
    );

    for (int d = -rowsAbove; d <= rowsBelow; d++) {
      final loc = _locate(order, row, d);
      if (loc == null) continue;
      final y = centerY + d * rowHeight;
      _paintRow(canvas, y, loc, loc.order != order, d == 0);
    }
  }

  // Moving bar: the page is anchored to the current pattern; the bar moves down
  // and the page scrolls only when the pattern is taller than the view. On an
  // order change the row resets to 0 → the page flips back to the top.
  void _paintMoving(Canvas canvas, Size size) {
    final patRows = _rowsOf(order);
    if (patRows <= 0) return;
    final rowsVisible = math.max(1, (size.height / rowHeight).floor());

    int startRow = row - (rowsVisible - 1);
    if (startRow < 0) startRow = 0;
    final maxStart = math.max(0, patRows - rowsVisible);
    if (startRow > maxStart) startRow = maxStart;

    final barY = (row - startRow) * rowHeight;
    canvas.drawRect(
      Rect.fromLTWH(0, barY, size.width, rowHeight),
      Paint()..color = palette.highlight,
    );

    for (int r = startRow; r < patRows && (r - startRow) * rowHeight < size.height; r++) {
      _paintRow(canvas, (r - startRow) * rowHeight, _RowLoc(order, r), false, r == row);
    }
  }

  // Live per-channel volume meters: a vertical bar centered in each column,
  // anchored at the bottom, growing up with the level.
  // FastTracker II corner labels: a big white channel number in each column's
  // top-left, drawn last so it stays overlaid on the scrolling rows.
  void _paintCornerLabels(Canvas canvas, Size size) {
    final nch = song.numChannels;
    void draw(int ch, Color c, Offset o) {
      final x = gutterWidth + ch * cellWidth + 4;
      final tp = TextPainter(
        text: TextSpan(
          text: '${ch + 1}',
          style: TextStyle(
            color: c,
            fontSize: 15,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + o.dx, 2 + o.dy));
    }
    // Transparent background: a 1px dark shadow keeps the white number legible
    // over the pattern text beneath it.
    for (int ch = 0; ch < nch; ch++) {
      draw(ch, const Color(0xE6000000), const Offset(1, 1));
      draw(ch, palette.headerText, Offset.zero);
    }
  }

  // Resolve the row that is [delta] rows away from (o,r) along the order list.
  _RowLoc? _locate(int o, int r, int delta) {
    int curO = o, curR = r + delta;
    while (curR >= _rowsOf(curO)) {
      curR -= _rowsOf(curO);
      curO++;
      if (curO >= song.numOrders) return null;
      if (_rowsOf(curO) == 0) return null;
    }
    while (curR < 0) {
      curO--;
      if (curO < 0) return null;
      final rc = _rowsOf(curO);
      if (rc == 0) return null;
      curR += rc;
    }
    return _RowLoc(curO, curR);
  }

  int _rowsOf(int o) {
    if (o < 0 || o >= song.numOrders) return 0;
    final p = song.order[o];
    if (p < 0 || p >= song.patternRows.length) return 0;
    return song.patternRows[p];
  }

  List<PatternCell> _cellsOf(int o) {
    final p = song.order[o];
    if (p < 0 || p >= song.patterns.length) return const [];
    return song.patterns[p];
  }

  void _paintRow(Canvas canvas, double y, _RowLoc loc, bool dim, bool isCurrent) {
    final cells = _cellsOf(loc.order);
    final nch = song.numChannels;
    final rowW = gutterWidth + nch * cellWidth;

    // Beat / measure bands (every 4th / 16th row), like real trackers — skipped
    // on the current row, whose highlight bar takes over.
    if (!isCurrent && loc.row % 4 == 0) {
      canvas.drawRect(Rect.fromLTWH(0, y, rowW, rowHeight),
          Paint()..color = palette.beatBg);
      if (loc.row % 16 == 0) {
        canvas.drawRect(Rect.fromLTWH(0, y, rowW, rowHeight),
            Paint()..color = palette.beatBg);
      }
    }

    // ProTracker-style: the whole current row inverts to a single color.
    final override =
        (isCurrent && palette.currentRowText != null) ? palette.currentRowText : null;
    final rowNumColor =
        override ?? (loc.row % 4 == 0 ? palette.beatRowNum : palette.rowNum);
    _text(canvas, _hex2(loc.row), Offset(4, y), rowNumColor, dim);

    if (cells.isEmpty) return;
    for (int ch = 0; ch < nch; ch++) {
      final idx = loc.row * nch + ch;
      final cell = (idx >= 0 && idx < cells.length) ? cells[idx] : PatternCell.blank;
      final x = gutterWidth + ch * cellWidth + 4;
      _paintCell(canvas, x, y, cell, dim, override);
      _paintSeparator(canvas, gutterWidth + ch * cellWidth, y, rowHeight, palette);
    }
  }

  void _paintCell(
      Canvas canvas, double x, double y, PatternCell c, bool dim, Color? override) {
    double cx = x;
    _text(canvas, _noteText(c.note), Offset(cx, y),
        override ?? (c.note == PatternNote.empty ? palette.noteEmpty : palette.note),
        dim);
    cx += 30;
    _text(canvas, _hex2(c.instrument), Offset(cx, y),
        override ?? (c.instrument < 0 ? palette.noteEmpty : palette.instrument), dim);
    cx += 20;
    _text(canvas, _hex2(c.volume), Offset(cx, y),
        override ?? (c.volume < 0 ? palette.noteEmpty : palette.volume), dim);
    cx += 20;
    if (c.fx.isEmpty) {
      _text(canvas, '...', Offset(cx, y), override ?? palette.noteEmpty, dim);
    } else {
      // Command and parameter are two colours (fxParam null = one look), so
      // two draws, the second advanced by the command's width.
      final f = c.fx.first;
      final code = f.code;
      final param =
          f.param.toRadixString(16).toUpperCase().padLeft(2, '0') +
              (c.fx.length > 1 ? '+' : '');
      final fxColor = override ?? palette.fx;
      _text(canvas, code, Offset(cx, y), fxColor, dim);
      _text(canvas, param, Offset(cx + code.length * charWidth, y),
          override ?? palette.fxParam ?? palette.fx, dim);
    }
  }

  void _text(Canvas canvas, String s, Offset at, Color color, bool dim) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: dim ? color.withValues(alpha: 0.32) : color,
          fontSize: fontSize,
          fontFamily: 'monospace',
          fontFeatures: const [FontFeature.tabularFigures()],
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(at.dx, at.dy + (rowHeight - tp.height) / 2));
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.order != order ||
      old.row != row ||
      old.scrollMode != scrollMode ||
      !identical(old.palette, palette) ||
      !identical(old.song, song);
}

/// Per-channel volume meters, drawn as a SEPARATE layer over the grid so the
/// live per-frame updates never re-lay the (expensive) text grid — that only
/// repaints on a row change. Cheap: rectangles only.
class _VolumeBarsPainter extends CustomPainter {
  final PatternSong song;
  final PatternPalette palette;
  final List<int> volumes; // per-channel level 0..255

  const _VolumeBarsPainter({
    required this.song,
    required this.palette,
    required this.volumes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final nch = song.numChannels;
    final barW = palette.volBarWidth;
    final seg = palette.volStyle == PatternVolStyle.segmented;
    final maxH = seg
        ? math.min(size.height * 0.36, 85.0)
        : math.min(size.height * 0.5, 56.0);
    final base = Paint()..color = palette.volBar.withValues(alpha: 0.16);
    for (int ch = 0; ch < nch && ch < volumes.length; ch++) {
      final cx = _PatternPainter.gutterWidth + ch * _PatternPainter.cellWidth +
          _PatternPainter.cellWidth / 2;
      // rewamp_channel_volume returns openmpt's VU*255 (see the plugin).
      final norm = (volumes[ch] / 255.0).clamp(0.0, 1.0);
      final left = cx - barW / 2;
      final zone = Rect.fromLTWH(left, size.height - maxH, barW, maxH);
      // Segmented meters use their black gaps as the "track" — no base fill.
      if (!seg) {
        canvas.drawRRect(RRect.fromRectAndRadius(zone, const Radius.circular(2)), base);
      }
      final h = norm * maxH;
      if (h <= 0.5) continue;
      switch (palette.volStyle) {
        case PatternVolStyle.segmented:
          // DOS-style stacked blocks, ~8/10 filled with a black gap, bicolour:
          // bottom ¾ low colour, top ¼ high colour.
          const nBlocks = 20;
          final slot = maxH / nBlocks;
          final fillH = slot * 0.78;
          final low = palette.volLow ?? palette.volBar;
          final high = palette.volHigh ?? low;
          final lit = (norm * nBlocks).round();
          for (int b = 0; b < lit; b++) {
            final by = size.height - b * slot - fillH;
            final p = Paint()..color = (b / nBlocks) < 0.75 ? low : high;
            canvas.drawRect(Rect.fromLTWH(left, by, barW, fillH), p);
          }
        case PatternVolStyle.gradient:
          // Gradient fixed to Y (same colour at a given height): the shader
          // spans the FULL meter zone, so a short bar shows only the bottom
          // colours and a tall one reaches the top — like ProTracker's scope.
          final fill = Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: palette.volGradient ?? [palette.volBar, palette.volBar],
            ).createShader(zone);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(left, size.height - h, barW, h),
                const Radius.circular(2)),
            fill,
          );
        case PatternVolStyle.solid:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(left, size.height - h, barW, h),
                const Radius.circular(2)),
            Paint()..color = palette.volBar,
          );
      }
    }
  }

  @override
  bool shouldRepaint(_VolumeBarsPainter old) =>
      !identical(old.volumes, volumes) || !identical(old.palette, palette);
}

class _RowLoc {
  final int order;
  final int row;
  const _RowLoc(this.order, this.row);
}

/// Fixed header row: 1-based channel number over each column, aligned to the
/// grid's column geometry so it stays in register while scrolling horizontally.
class _PatternHeaderPainter extends CustomPainter {
  final int channels;
  final PatternPalette palette;
  const _PatternHeaderPainter({required this.channels, required this.palette});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.headerBg);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      Paint()..color = palette.separator,
    );

    const cellW = _PatternPainter.cellWidth;
    const gutterW = _PatternPainter.gutterWidth;
    for (int ch = 0; ch < channels; ch++) {
      final x = gutterW + ch * cellW;
      // Same separator as the grid → the column is continuous across the seam;
      // its 3-tone bevel keeps it visible on the tan header (blends flat mid,
      // but the dark/light edges delineate).
      _paintSeparator(canvas, x, 0, size.height, palette);
      final tp = TextPainter(
        text: TextSpan(
          text: '${ch + 1}',
          style: TextStyle(
            color: palette.headerText,
            fontSize: 10,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + (cellW - tp.width) / 2, (size.height - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(_PatternHeaderPainter old) =>
      old.channels != channels || !identical(old.palette, palette);
}
