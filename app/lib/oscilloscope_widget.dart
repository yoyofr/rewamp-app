import 'dart:typed_data';
import 'dart:ui' as ui;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rewamp_audio/rewamp_audio.dart';

import 'viz_gl_ownership.dart';

import 'user_settings.dart';
import 'viz_platform_view.dart';

// Visualizer render size. Matches the widget's logical height × device pixel ratio.
const int _kVizWidth  = 512;
const int _kVizHeight = 256;

class OscilloscopeWidget extends StatefulWidget {
  final RewampAudio audio;
  final double height;
  /// When true the widget expands to fill parent constraints instead of using
  /// the fixed [height].  The parent must provide bounded height constraints.
  final bool fillHeight;

  const OscilloscopeWidget({
    super.key,
    required this.audio,
    this.height     = 160,
    this.fillHeight = false,
  });

  @override
  State<OscilloscopeWidget> createState() => _OscilloscopeWidgetState();
}

class _OscilloscopeWidgetState extends State<OscilloscopeWidget>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  // GPU path (iOS/macOS MetalANGLE, Android EGL render thread) — Flutter Texture
  int _gpuTextureId = -1;   // > 0 when active
  Size _gpuSize     = Size.zero;
  int  _gpuFailures = 0;    // vizRegister failures; after 3 → shader fallback
  bool _gpuGaveUp   = false;

  // CPU-GL path (old fallback)
  bool _glReady = false;

  // Flutter FragmentProgram fallback
  ui.FragmentProgram? _program;

  // Shared: decoded image for CPU paths
  ui.Image? _image;
  bool _buildingImage = false;

  // Fallback path: waveform buffers + pixel encoding
  final _left   = Float32List(RewampAudio.waveformCount);
  final _right  = Float32List(RewampAudio.waveformCount);
  final _pixels = Uint8List(256 * 2 * 4);

  @override
  void initState() {
    super.initState();
    _applySettings();
    UserSettings.instance.addListener(_onSettingsChanged);
    _initVisualizer();
    _ticker = createTicker(_onTick)..start();
  }

  void _onSettingsChanged() => _applySettings();

  void _applySettings() {
    final s = UserSettings.instance;
    widget.audio.setVizLineWidth(s.vizLineThickness);
    widget.audio.setCrtFlags(s.crtFlags);
    // Stereo scope colors + mono/bi-color mode.
    void rgb(int v, void Function(double, double, double) f) =>
        f(((v >> 16) & 0xFF) / 255.0, ((v >> 8) & 0xFF) / 255.0, (v & 0xFF) / 255.0);
    rgb(s.stereoMonoColor,  widget.audio.setStereoMonoColor);
    rgb(s.stereoLeftColor,  widget.audio.setStereoLeftColor);
    rgb(s.stereoRightColor, widget.audio.setStereoRightColor);
    widget.audio.setStereoBicolor(s.stereoBicolor);
  }

  Future<void> _initVisualizer() async {
    // GPU path first (iOS/macOS MetalANGLE) — zero-copy Flutter Texture.
    // Size unknown at init; _initGpu() is called from LayoutBuilder on first build.
    if (widget.audio.vizGpuAvailable) return; // wait for size

    // CPU-GL path.
    if (widget.audio.vizAvailable) {
      final ok = widget.audio.vizInit(_kVizWidth, _kVizHeight);
      if (ok) { setState(() => _glReady = true); return; }
    }
    // Fallback: Flutter FragmentProgram shader.
    try {
      final prog = await ui.FragmentProgram.fromAsset('shaders/oscilloscope.frag');
      if (mounted) setState(() => _program = prog);
    } catch (e) {
      debugPrint('OscilloscopeWidget: shader load failed — $e');
    }
  }

  void _initGpu(Size physicalSize) {
    if (!widget.audio.vizGpuAvailable || _gpuGaveUp) return;
    if (physicalSize == _gpuSize && _gpuTextureId >= 0) return;
    if (_gpuTextureId >= 0) {
      // Resize existing context.
      widget.audio.vizResizeRegister(physicalSize.width.toInt(), physicalSize.height.toInt());
      _gpuSize = physicalSize;
      return;
    }
    final id = widget.audio.vizRegister(physicalSize.width.toInt(), physicalSize.height.toInt());
    if (id >= 0) {
      setState(() { _gpuTextureId = id; _gpuSize = physicalSize; });
    } else if (++_gpuFailures >= 3) {
      // GPU texture path broken on this device/build — stop retrying every
      // frame (it used to spam-register forever) and fall back to the
      // FragmentProgram shader path.
      _gpuGaveUp = true;
      _initVisualizerFallback();
    }
  }

  Future<void> _initVisualizerFallback() async {
    try {
      final prog = await ui.FragmentProgram.fromAsset('shaders/oscilloscope.frag');
      if (mounted) setState(() => _program = prog);
    } catch (e) {
      debugPrint('OscilloscopeWidget: fallback shader load failed — $e');
    }
  }

  void _onTick(Duration _) {
    if (_gpuTextureId >= 0) {
      widget.audio.vizRenderAndNotify(); // renders + notifies Flutter via main thread
      return;
    }
    if (_buildingImage) return;
    if (_glReady) {
      _tickGl();
    } else if (_program != null) {
      _tickFlutter();
    }
  }

  // ---- CPU-GL path (readback, fallback) -----------------------------------

  void _tickGl() {
    widget.audio.vizRender();
    // CPU readback removed — this path is now a no-op placeholder.
    // Will be removed once GPU path covers all platforms.
  }

  // ---- Flutter FragmentProgram fallback -----------------------------------

  void _tickFlutter() {
    widget.audio.getWaveform(_left, _right);
    _buildingImage = true;

    for (int i = 0; i < 256; i++) {
      final lByte = ((_left[i]  * 0.5 + 0.5).clamp(0.0, 1.0) * 255).toInt();
      final rByte = ((_right[i] * 0.5 + 0.5).clamp(0.0, 1.0) * 255).toInt();
      _pixels[i * 4]            = lByte;
      _pixels[i * 4 + 1]        = 0;
      _pixels[i * 4 + 2]        = 0;
      _pixels[i * 4 + 3]        = 255;
      _pixels[(256 + i) * 4]     = rByte;
      _pixels[(256 + i) * 4 + 1] = 0;
      _pixels[(256 + i) * 4 + 2] = 0;
      _pixels[(256 + i) * 4 + 3] = 255;
    }

    ui.decodeImageFromPixels(
      Uint8List.fromList(_pixels), 256, 2, ui.PixelFormat.rgba8888,
      (img) {
        if (!mounted) { img.dispose(); _buildingImage = false; return; }
        setState(() {
          _image?.dispose();
          _image = img;
          _buildingImage = false;
        });
      },
    );
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
    if (_glReady) widget.audio.vizUninit();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizedBox = widget.fillHeight
        ? const SizedBox.expand()
        : SizedBox(width: double.infinity, height: widget.height);

    // Android: PlatformView (SurfaceView) — native GL renders straight into a
    // SurfaceFlinger-composited surface (vsync-locked thread), bypassing
    // Flutter's Texture/ImageReader import pipeline which judders on some
    // devices. iOS/macOS keep the Flutter Texture path.
    if (!kIsWeb &&
        Platform.isAndroid &&
        widget.audio.vizGpuAvailable &&
        !kVizForceTextureOnAndroid) {
      return const RewampVizPlatformView(mode: 0);
    }
    // GPU path: use logical size so each GL pixel maps to dpr screen pixels → thick lines.
    if (widget.audio.vizGpuAvailable && !_gpuGaveUp) {
      return LayoutBuilder(builder: (ctx, constraints) {
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
        return sizedBox; // not yet ready
      });
    }

    // CPU/fallback paths.
    final img = _image;
    if (img == null) return sizedBox;
    return ClipRect(
      child: CustomPaint(
        painter: _glReady
            ? _ImagePainter(img)
            : _ShaderPainter(_program!, img),
        child: sizedBox,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

/// GL path: the backend already rendered the full image — just draw it.
class _ImagePainter extends CustomPainter {
  final ui.Image _image;
  _ImagePainter(this._image);

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(0, 0, _image.width.toDouble(), _image.height.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(_image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(covariant _ImagePainter old) => old._image != _image;
}

/// Flutter fallback: FragmentProgram shader reads waveform from sampler2D.
class _ShaderPainter extends CustomPainter {
  final ui.FragmentProgram _prog;
  final ui.Image           _image;
  _ShaderPainter(this._prog, this._image);

  @override
  void paint(Canvas canvas, Size size) {
    final shader = _prog.fragmentShader();
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setImageSampler(0, _image);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _ShaderPainter _) => true;
}
