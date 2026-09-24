import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:rewamp_audio/rewamp_audio.dart';

import 'viz_gl_ownership.dart';

import 'l10n.dart';
import 'preset_manager.dart';
import 'viz_platform_view.dart';

/// projectM (Milkdrop) visualizer — mode 3. Renders a full opaque frame in the
/// C/OpenGL-ES(ANGLE) backend; no artwork background (projectM owns the frame).
/// GPU-only: shown only where the native GL path + projectM are available.
class ProjectMWidget extends StatefulWidget {
  final RewampAudio audio;
  const ProjectMWidget({super.key, required this.audio});

  @override
  State<ProjectMWidget> createState() => _ProjectMWidgetState();
}

class _ProjectMWidgetState extends State<ProjectMWidget>
    with SingleTickerProviderStateMixin {
  int  _gpuTextureId = -1;
  Size _gpuSize      = Size.zero;
  late final Ticker _ticker;

  // The preset-name display itself lives in VizSelectorWidget's overlay
  // (_PmPresetBanner) — ONE widget for the change-flash and the tap-reveal, so
  // they can never draw on top of each other. Here we only poll the serial for
  // the usage tick.
  int _lastSerial = -1;

  late final bool _useSurfaceView = !kIsWeb &&
      Platform.isAndroid &&
      widget.audio.vizGpuAvailable &&
      !kVizForceTextureOnAndroid;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _lastSerial = widget.audio.projectmPresetSerial;
  }

  void _initGpu(Size physicalSize) {
    if (!widget.audio.vizGpuAvailable || !widget.audio.hasProjectM) return;
    if (physicalSize == _gpuSize && _gpuTextureId >= 0) return;
    if (_gpuTextureId >= 0) {
      widget.audio.vizResizeRegister(
          physicalSize.width.toInt(), physicalSize.height.toInt());
      _gpuSize = physicalSize;
      return;
    }
    final id = widget.audio.projectmRegister(
        physicalSize.width.toInt(), physicalSize.height.toInt());
    if (id >= 0) {
      setState(() { _gpuTextureId = id; _gpuSize = physicalSize; });
    }
  }

  void _onTick(Duration elapsed) {
    if (_useSurfaceView) {
      // Native thread renders; only poll for preset changes here.
    } else {
      if (_gpuTextureId < 0) return;
      // Voir src/rewamp_viz_idle.h. La veille du preset, plus bas, continue:
      // c'est le natif qui le change, et la bannière doit suivre.
      if (widget.audio.vizFrameDue) widget.audio.projectmRenderAndNotify();
    }
    // Usage stats: accumulate the preset id on every change (server-known
    // presets only), pushed in BATCHES by the manager — never one POST per
    // switch. The visible name display is VizSelectorWidget's banner.
    final serial = widget.audio.projectmPresetSerial;
    if (serial != _lastSerial) {
      _lastSerial = serial;
      PresetManager.instance
          .noteUsageTick(serial, widget.audio.projectmPresetPath);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    // Not on a visualizer SWITCH: all four renderers share one GL context, so
    // tearing it down here made the next one rebuild it from scratch (context,
    // buffers, shaders, Metal pipeline) — the delay after tapping a viz button.
    // VizSelectorWidget owns the teardown while it is on screen.
    if (_gpuTextureId >= 0 && !kVizGlOwnedBySelector) {
      widget.audio.vizUnregister();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.audio.vizGpuAvailable || !widget.audio.hasProjectM) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(context.l10n.vizProjectmUnavailable,
              style: const TextStyle(color: Colors.white54)),
        ),
      );
    }
    // Android: SurfaceView PlatformView (mode 3), like the other three viz —
    // native GL renders straight into a SurfaceFlinger-composited surface from
    // its own vsync-locked thread. The Flutter-Texture path below stays for
    // iOS/macOS.
    if (!kIsWeb &&
        Platform.isAndroid &&
        widget.audio.vizGpuAvailable &&
        !kVizForceTextureOnAndroid) {
      return const RewampVizPlatformView(mode: 3);
    }
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth.toInt();
      final h = constraints.maxHeight.toInt();
      if (w > 0 && h > 0) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _initGpu(Size(w.toDouble(), h.toDouble())));
      }
      if (_gpuTextureId < 0) {
        return const ColoredBox(color: Colors.black);
      }
      return Texture(textureId: _gpuTextureId);
    });
  }
}
