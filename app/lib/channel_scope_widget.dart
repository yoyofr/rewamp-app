import 'dart:ffi' hide Size;
import 'dart:math' as math show min;
import 'dart:math' show log, ln2;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rewamp_audio/rewamp_audio.dart';

import 'viz_gl_ownership.dart';

import 'user_settings.dart';
import 'viz_platform_view.dart';
import 'font_fallback.dart';

/// Per-channel oscilloscope grid for VGM/S98/GYM/DRO playback.
/// Shows one mini waveform cell per active chip channel, with note name overlay.
/// Collapses to zero height when no per-channel data is available.
class ChannelScopeWidget extends StatefulWidget {
  final RewampAudio audio;
  final int    cols;       // number of columns in the grid
  final double rowHeight;  // logical-pixel height per row (ignored when fillHeight = true)
  /// When true the widget expands to fill parent constraints; the painter
  /// derives row height from the actual canvas size instead of [rowHeight].
  final bool   fillHeight;

  const ChannelScopeWidget({
    super.key,
    required this.audio,
    this.cols       = 4,
    this.rowHeight  = 44,
    this.fillHeight = false,
  });

  @override
  State<ChannelScopeWidget> createState() => _ChannelScopeWidgetState();
}

class _ChannelScopeWidgetState extends State<ChannelScopeWidget>
    with SingleTickerProviderStateMixin {

  // Cap: more than any real VGM chip set ever exposes.
  static const _maxCh = 32;

  // Exactly one 60 fps frame of audio at 44 100 Hz.
  // The C ring buffer returns the last `_kDisplaySamples` in chronological
  // order, so the display is 100 % fresh on every Flutter frame.
  static const _kDisplaySamples = 44100 ~/ 60; // 735

  // GPU path — zero-copy FlutterTexture.
  int  _gpuTextureId = -1;
  Size _gpuSize      = Size.zero;

  late final Ticker _ticker;

  // One native buffer reused every tick — avoids per-call heap allocation.
  Pointer<Int8>? _nativeBuf;
  // Idem pour les instruments courants: un seul appel FFI rend les N voies,
  // et la comparaison se fait sur des entiers. C'est ce qui permet de suivre
  // un changement d'instrument à ~8 Hz sans allouer ni décoder une chaîne.
  Pointer<Int32>? _instrBuf;   // instruments datés (timeline, tête ENTENDUE)
  Pointer<Int32>? _instrLive;  // repli: l'instant du producteur
  List<int> _lastInstr = const [];

  int _count = 0;

  final _bufs           = List.generate(_maxCh, (_) => Int8List(_kDisplaySamples));
  final _freqs          = List<double>.filled(_maxCh, 0.0);
  final _lastPtrs       = List<int>.filled(_maxCh, -1);
  final _silenceFrames  = List<int>.filled(_maxCh, 0);

  // Frames of unchanged write-ptr required before a channel is considered
  // silent and its buffer cleared.  At 60 fps: 4 frames ≈ 67 ms grace window.
  // Prevents jitter-induced flicker when the UI tick races the audio callback.
  static const _kSilenceThreshold = 4;

  @override
  void initState() {
    super.initState();
    if (!widget.audio.vizGpuAvailable) {
      _nativeBuf = calloc<Int8>(_kDisplaySamples);
    }
    _applySettings();
    UserSettings.instance.addListener(_onSettingsChanged);
    _ticker = createTicker(_onTick)..start();
  }

  void _onSettingsChanged() {
    _applySettings();
    if (mounted) setState(() {});
  }

  void _applySettings() {
    // Un réglage a changé: l'image doit suivre même à l'arrêt.
    widget.audio.vizWake();
    final s = UserSettings.instance;
    widget.audio.scopeSetGrid(s.vizVoiceGrid);
    widget.audio.setVizLineWidth(s.vizLineThickness);
    widget.audio.setCrtFlags(s.crtFlags);
    final v = s.scopeColor;
    widget.audio.setScopeColor(
        ((v >> 16) & 0xFF) / 255.0, ((v >> 8) & 0xFF) / 255.0, (v & 0xFF) / 255.0);
  }

  void _initGpu(Size physicalSize) {
    if (!widget.audio.vizGpuAvailable) return;
    if (physicalSize == _gpuSize && _gpuTextureId >= 0) return;
    if (_gpuTextureId >= 0) {
      widget.audio.vizResizeRegister(physicalSize.width.toInt(), physicalSize.height.toInt());
      _gpuSize = physicalSize;
      return;
    }
    final id = widget.audio.scopeRegister(physicalSize.width.toInt(), physicalSize.height.toInt());
    // A fresh GL context resets the grid flag to its default — re-apply.
    widget.audio.scopeSetGrid(UserSettings.instance.vizVoiceGrid);
    if (id >= 0) setState(() { _gpuTextureId = id; _gpuSize = physicalSize; });
  }

  @override
  void dispose() {
    UserSettings.instance.removeListener(_onSettingsChanged);
    _ticker.dispose();
    // Not on a visualizer SWITCH: all four renderers share one GL context, so
    // tearing it down here made the next one rebuild it from scratch (context,
    // buffers, shaders, Metal pipeline) — the delay after tapping a viz button.
    // VizSelectorWidget owns the teardown while it is on screen.
    if (_gpuTextureId >= 0 && !kVizGlOwnedBySelector) {
      widget.audio.vizUnregister();
    }
    final p = _nativeBuf;
    if (p != null) { calloc.free(p); _nativeBuf = null; }
    final ip = _instrBuf;
    if (ip != null) { calloc.free(ip); _instrBuf = null; }
    final lp = _instrLive;
    if (lp != null) { calloc.free(lp); _instrLive = null; }
    super.dispose();
  }

  // Voice names for the overlay (see _VoiceNamesOverlay). Refreshed on a slow
  // cadence: they only change on a track/subsong change, and reading them is an
  // FFI call + string decode per voice.
  List<String> _names = const [];
  int _nameTick = 0;

  /// Les instruments ont-ils changé depuis la dernière lecture ? Un appel FFI
  /// groupé + une comparaison d'entiers: assez bon marché pour tourner à
  /// cadence rapide, là où relire les NOMS ne l'est pas.
  bool _instrumentsChanged(int count) {
    if (count <= 0) return false;
    final buf  = _instrBuf  ??= calloc<Int32>(_maxCh);
    final live = _instrLive ??= calloc<Int32>(_maxCh);
    // La TIMELINE d'abord: son instrument est celui de la tête de lecture
    // ENTENDUE, donc synchrone avec la forme d'onde affichée, là où
    // vgm_last_instr[] décrit le producteur (200 ms à 2 s d'avance).
    final nTl = widget.audio.notesVoiceInstrumentsInto(buf, _maxCh);
    // ⚠️ Repli PAR VOIE, pas « tout ou rien »: une voie peut n'avoir aucun
    // instrument daté (rien capturé à cet instant) alors que les autres en
    // ont. Un repli global ne partait jamais et TOUS les libellés restaient
    // sur le nom de voie — c'est ce qui donnait « ça ne suit pas ».
    final nLive = widget.audio.voiceInstrumentsInto(live, _maxCh);
    final n = nTl > nLive ? nTl : nLive;
    if (n <= 0) return false;
    final lim = count < n ? count : n;
    int at(int v) {
      final tl = v < nTl ? buf[v] : 0;
      if (tl > 0) return tl;
      return v < nLive ? live[v] : 0;
    }
    if (_lastInstr.length != lim) {
      _lastInstr = [for (var v = 0; v < lim; v++) at(v)];
      return true;
    }
    var changed = false;
    for (var v = 0; v < lim; v++) {
      final now = at(v);
      if (_lastInstr[v] != now) { _lastInstr[v] = now; changed = true; }
    }
    return changed;
  }

  /// Vrai quand un instrument a changé. AUCUN maintien ici (demande
  /// utilisateur, 2026-09-12): le libellé de l'oscilloscope doit être
  /// SYNCHRONE avec la forme d'onde affichée, quitte à changer vite.
  bool _instrModeChanged(int count) {
    final s = UserSettings.instance;
    if (!s.vizVoiceNames || s.vizVoiceNameSource != 1) return false;
    return _instrumentsChanged(count);
  }

  /// Instrument de la voie [v] tel qu'on l'ENTEND (dernière lecture groupée,
  /// rafraîchie par _instrumentsChanged); 0 si aucun.
  int _instrumentOf(int v) =>
      (v >= 0 && v < _lastInstr.length) ? _lastInstr[v] : 0;

  void _refreshNames(int count) {
    final s = UserSettings.instance;
    if (!s.vizVoiceNames) {
      if (_names.isNotEmpty) setState(() => _names = const []);
      return;
    }
    // Le libellé dit la VOIE, ou l'INSTRUMENT qu'elle joue en ce moment — et
    // celui-là change en cours de morceau (un canal MIDI change de programme,
    // une voie de tracker d'échantillon), d'où la même cadence de
    // rafraîchissement pour les deux. Sans instrument (SID, UADE, puces sans
    // notion d'échantillon), on garde le nom de la voie: « Inst 0 » ne dirait
    // rien à personne.
    final next = [
      for (var v = 0; v < count; v++)
        if (s.vizVoiceNameSource == 1 && _instrumentOf(v) > 0)
          widget.audio.instrumentName(_instrumentOf(v))
        else
          widget.audio.voiceName(v),
    ];
    if (next.length != _names.length ||
        !Iterable<int>.generate(next.length).every((i) => next[i] == _names[i])) {
      setState(() => _names = next);
    }
  }

  void _onTick(Duration _) {
    // GPU paths (Flutter Texture, or the Android SurfaceView which renders on
    // its own thread and leaves _gpuTextureId at -1): the C side draws the
    // waveforms, but the name overlay still needs the live voice count.
    if (widget.audio.vizGpuAvailable) {
      if (_gpuTextureId >= 0 && widget.audio.vizFrameDue) {
        // Voir src/rewamp_viz_idle.h. Le comptage des voix et les noms, eux,
        // restent vivants: ils viennent du greffon, pas de l'image.
        widget.audio.scopeRenderAndNotify();
      }
      final count = widget.audio.channelCount.clamp(0, _maxCh);
      // En veille (pause, grâce écoulée) rien ne bouge: ni les instruments
      // entendus ni les noms. Seul le COMPTE de voies reste surveillé (un
      // chargement en pause change de morceau). Règle de rewamp_viz_idle.h.
      final awake = widget.audio.vizShouldRender;
      if (count != _count) {
        setState(() => _count = count);
        _refreshNames(count);
      } else if (awake && _instrModeChanged(count)) {
        _nameTick = 0;
        _refreshNames(count);
      } else if (awake && ++_nameTick >= 30) {
        _nameTick = 0;
        _refreshNames(count); // names can land after the count (plugin open)
      }
      return;
    }
    final p = _nativeBuf;
    if (p == null) return;

    final count = widget.audio.channelCount.clamp(0, _maxCh);
    bool changed = count != _count;
    if (count != _count) {
      _silenceFrames.fillRange(0, _maxCh, 0);
      _lastPtrs.fillRange(0, _maxCh, -1);
    }

    final playing = widget.audio.isPlaying;
    for (int ch = 0; ch < count; ch++) {
      final ptr = widget.audio.channelWritePtr(ch);
      if (ptr != _lastPtrs[ch]) {
        // Write-ptr advanced → channel has new data.
        _lastPtrs[ch]      = ptr;
        _silenceFrames[ch] = 0;
        final len = widget.audio.channelBufTriggeredNative(ch, p, _kDisplaySamples);
        if (len > 0) _bufs[ch].setAll(0, p.asTypedList(len));
        _freqs[ch] = widget.audio.channelFreqHz(ch);
        changed = true;
      } else if (playing) {
        // Ptr unchanged while playing.  Count consecutive idle frames before
        // concluding the channel is truly silent (guards against UI/audio jitter).
        _silenceFrames[ch]++;
        if (_silenceFrames[ch] >= _kSilenceThreshold) {
          _bufs[ch].fillRange(0, _bufs[ch].length, 0);
          _freqs[ch] = 0;
          changed = true;
        }
      }
      // Paused: ptr frozen → keep last frame as-is (no counter advance).
    }

    // Chemin CustomPaint: la lecture groupée des instruments doit tourner ici
    // aussi, sinon _lastInstr reste vide et un libellé « par instrument » ne
    // trouve jamais son instrument (le chemin GL a le sien dans _onTick).
    final instrMoved = widget.audio.vizShouldRender && _instrModeChanged(count);
    if (changed) {
      setState(() => _count = count);
      _refreshNames(count);
    } else if (instrMoved) {
      _refreshNames(count);
    }
  }

  /// The GL renderer picks its column count itself (rewamp_scope_render.cpp,
  /// best_cols): the count minimising |cellAspect - 2|. The name overlay must
  /// use the SAME grid, so this is a port of it — it only depends on the cell
  /// aspect ratio, so logical pixels give the same answer as physical ones.
  static int _glBestCols(int n, double w, double h) {
    if (n <= 0 || h <= 0) return 1;
    var best = 1;
    var bestDiff = double.infinity;
    for (var c = 1; c <= n; c++) {
      final rows  = (n + c - 1) ~/ c;
      final diff  = ((w / c) / (h / rows) - 2.0).abs();
      if (diff < bestDiff) { bestDiff = diff; best = c; }
    }
    return best;
  }

  /// Wraps a GL-rendered scope with the voice-name overlay (the C renderer has
  /// no text; Flutter draws the labels on top, on the same grid).
  Widget _withNames(Widget scope, {required bool glGrid}) {
    if (!UserSettings.instance.vizVoiceNames || _count == 0 || _names.isEmpty) {
      return scope;
    }
    return Stack(
      children: [
        Positioned.fill(child: scope),
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (ctx, c) => _VoiceNamesOverlay(
                names: _names,
                count: _count,
                cols: glGrid
                    ? _glBestCols(_count, c.maxWidth, c.maxHeight)
                    : widget.cols.clamp(1, _count),
              ),
            ),
          ),
        ),
      ],
    );
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
      return _withNames(const RewampVizPlatformView(mode: 1), glGrid: true);
    }
    // GPU path.
    if (widget.audio.vizGpuAvailable) {
      return LayoutBuilder(builder: (ctx, constraints) {
        final w = constraints.maxWidth.toInt();
        final h = constraints.maxHeight.toInt();
        if (w > 0 && h > 0) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _initGpu(Size(w.toDouble(), h.toDouble())));
        }
        if (_gpuTextureId >= 0) {
          return SizedBox(
            width: double.infinity,
            height: widget.fillHeight ? double.infinity : widget.rowHeight * widget.cols,
            child: _withNames(Texture(textureId: _gpuTextureId), glGrid: true),
          );
        }
        return SizedBox(width: double.infinity, height: widget.rowHeight * widget.cols);
      });
    }

    // CPU fallback.
    if (_count == 0) return const SizedBox.shrink();

    final cols    = widget.cols.clamp(1, _count);
    final rows    = (_count + cols - 1) ~/ cols;
    final painter = _ChannelPainter(
      bufs:  _bufs,
      freqs: _freqs,
      count: _count,
      cols:  cols,
      grid:  UserSettings.instance.vizVoiceGrid,
      thickness: UserSettings.instance.vizLineThickness,
      waveColor: Color(0xFF000000 | UserSettings.instance.scopeColor),
    );

    if (widget.fillHeight) {
      return _withNames(
        CustomPaint(painter: painter, child: const SizedBox.expand()),
        glGrid: false,
      );
    }

    return SizedBox(
      width:  double.infinity,
      height: rows * widget.rowHeight,
      child: _withNames(CustomPaint(painter: painter), glGrid: false),
    );
  }
}

/// Voice names laid over the oscilloscope grid, one per cell, top-left.
class _VoiceNamesOverlay extends StatelessWidget {
  final List<String> names;
  final int count;
  final int cols;

  const _VoiceNamesOverlay({
    required this.names,
    required this.count,
    required this.cols,
  });

  @override
  Widget build(BuildContext context) {
    final n = count.clamp(0, names.length);
    if (n == 0 || cols < 1) return const SizedBox.shrink();
    final rows = (n + cols - 1) ~/ cols;
    return LayoutBuilder(builder: (ctx, c) {
      final cellW = c.maxWidth / cols;
      final cellH = c.maxHeight / rows;
      // Shrink with the cell (both axes — a 16-voice grid gets short AND narrow
      // cells) so the label never eats the waveform it labels.
      final size = math
          .min(cellH * 0.20, cellW * 0.14)
          .clamp(6.0, 12.0)
          .toDouble();
      final pad = (size * 0.35).clamp(1.5, 4.0);
      return Stack(
        children: [
          for (var v = 0; v < n; v++)
            if (names[v].isNotEmpty)
              Positioned(
                left:  (v % cols) * cellW + pad,
                top:   (v ~/ cols) * cellH + pad * 0.5,
                width: cellW - pad * 2,
                child: Text(
                  names[v],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: withCjkFallback(TextStyle(
                    fontSize: size,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.75),
                    // The scope draws over an arbitrary background (artwork,
                    // black); a shadow keeps the label legible on both.
                    shadows: const [
                      Shadow(blurRadius: 3, color: Color(0xCC000000)),
                    ],
                  )),
                ),
              ),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ChannelPainter extends CustomPainter {
  final List<Int8List> bufs;
  final List<double>   freqs;
  final int            count;
  final int            cols;
  final bool           grid;
  final double         thickness;
  final Color          waveColor;

  const _ChannelPainter({
    required this.bufs,
    required this.freqs,
    required this.count,
    required this.cols,
    required this.grid,
    required this.thickness,
    required this.waveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rows  = (count + cols - 1) ~/ cols;
    final rowH  = size.height / rows; // adapts to actual canvas size
    final cellW = size.width  / cols;

    final bgPaint  = Paint()..color = const Color(0xFF080808);
    final divPaint = Paint()
      ..color       = const Color(0xFF252525)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (int ch = 0; ch < count; ch++) {
      final col = ch % cols;
      final row = ch ~/ cols;
      final x0 = col * cellW;
      final y0 = row * rowH;

      final cellRect = Rect.fromLTWH(x0, y0, cellW, rowH);
      canvas.drawRect(cellRect, bgPaint);

      final yMid = y0 + rowH / 2;

      if (grid) canvas.drawRect(cellRect, divPaint);

      final buf = bufs[ch];
      if (buf.isEmpty) continue;

      final color = waveColor;

      // Downsample to avoid overdraw: at most cellW*2 points.
      final samples = buf.length;
      final step    = (samples / (cellW * 2)).ceil().clamp(1, samples);
      final yScale  = (rowH / 2 - 2) / 128.0;

      final pts = <Offset>[];
      for (int i = 0; i < samples; i += step) {
        pts.add(Offset(x0 + (i / samples) * cellW, yMid - buf[i] * yScale));
      }

      canvas.drawPoints(
        ui.PointMode.polygon,
        pts,
        Paint()
          ..color       = color
          ..strokeWidth = 1.5 * thickness
          ..style       = PaintingStyle.stroke,
      );

      // Note name in top-left corner.
      final hz = freqs[ch];
      if (hz > 0) {
        final note = _noteFromHz(hz);
        if (note.isNotEmpty) {
          final tp = TextPainter(
            text: TextSpan(
              text: note,
              style: withCjkFallback(TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: cellW - 4);
          tp.paint(canvas, Offset(x0 + 2, y0 + 2));
        }
      }
    }
  }

  static String _noteFromHz(double hz) {
    if (hz <= 0) return '';
    const names = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
    final midi = (12 * log(hz / 440.0) / ln2 + 69).round();
    if (midi < 0 || midi > 127) return '';
    return '${names[midi % 12]}${midi ~/ 12 - 1}';
  }

  @override
  bool shouldRepaint(_ChannelPainter _) => true;
}
