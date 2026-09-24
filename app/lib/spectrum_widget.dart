import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rewamp_audio/rewamp_audio.dart';

import 'user_settings.dart';
import 'viz_gl_ownership.dart';
import 'viz_platform_view.dart';

/// Stereo spectrum analyzer (FFT) — viz mode 5, rendered by the C engine
/// (rewamp_spectrum_render.cpp). Same display plumbing as the other GL
/// visualizers: Android = SurfaceView PlatformView, iOS/macOS = Flutter
/// Texture driven by a Ticker. No CPU fallback — the selector only offers
/// this mode where the GL path exists.
class SpectrumWidget extends StatefulWidget {
  final RewampAudio audio;
  final double height;
  final bool fillHeight;

  const SpectrumWidget({
    super.key,
    required this.audio,
    this.height     = 160,
    this.fillHeight = false,
  });

  @override
  State<SpectrumWidget> createState() => _SpectrumWidgetState();
}

class _SpectrumWidgetState extends State<SpectrumWidget>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int  _gpuTextureId = -1;
  Size _gpuSize      = Size.zero;

  @override
  void initState() {
    super.initState();
    _applySettings();
    UserSettings.instance.addListener(_applySettings);
    _ticker = createTicker(_onTick)..start();
  }

  /// The spectrum reuses the stereo scope's colors (mono / bi-color L+R), so
  /// push them here too — the user may open this viz without ever having
  /// opened the oscilloscope this session.
  void _applySettings() {
    // Un réglage a changé: l'image doit suivre même à l'arrêt.
    widget.audio.vizWake();
    final s = UserSettings.instance;
    void rgb(int v, void Function(double, double, double) f) =>
        f(((v >> 16) & 0xFF) / 255.0, ((v >> 8) & 0xFF) / 255.0,
          (v & 0xFF) / 255.0);
    rgb(s.stereoMonoColor,  widget.audio.setStereoMonoColor);
    rgb(s.stereoLeftColor,  widget.audio.setStereoLeftColor);
    rgb(s.stereoRightColor, widget.audio.setStereoRightColor);
    widget.audio.setStereoBicolor(s.stereoBicolor);
    widget.audio.setSpectrumPalette(s.spectrumPalette);
  }

  void _onTick(Duration _) {
    // Lecteur en pause et rien qui bouge: on ne redessine pas (voir
    // src/rewamp_viz_idle.h). Le réveil vient du `build` et des gestes.
    if (!widget.audio.vizFrameDue) return;
    if (_gpuTextureId >= 0) widget.audio.spectrumRenderAndNotify();
  }

  void _initGpu(Size size) {
    if (size == _gpuSize && _gpuTextureId >= 0) return;
    if (_gpuTextureId >= 0) {
      widget.audio.vizResizeRegister(size.width.toInt(), size.height.toInt());
      _gpuSize = size;
      return;
    }
    final id =
        widget.audio.spectrumRegister(size.width.toInt(), size.height.toInt());
    if (id >= 0) setState(() { _gpuTextureId = id; _gpuSize = size; });
  }

  @override
  void dispose() {
    UserSettings.instance.removeListener(_applySettings);
    _ticker.dispose();
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
      return const RewampVizPlatformView(mode: 5);
    }
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
      return widget.fillHeight
          ? const SizedBox.expand()
          : SizedBox(width: double.infinity, height: widget.height);
    });
  }
}
