import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// EXPERIMENT (2026-07-07, Impeller + Flutter-Texture path): when true, the
/// three viz widgets skip [RewampVizPlatformView] on Android and fall through
/// to the Texture/SurfaceProducer path (same one already used on iOS/macOS).
/// Combine with EnableImpeller=true in AndroidManifest.xml to test whether
/// Impeller's external-texture compositing avoids the judder that killed this
/// path under Skia. Revert both to false/false if it doesn't pan out — the
/// SurfaceView path stays the default otherwise.
const bool kVizForceTextureOnAndroid = false;

/// Android visualizer platform view (native SurfaceView, GL-rendered by the
/// C engine on a vsync-locked thread; SurfaceFlinger composites it directly).
///
/// Forces HYBRID COMPOSITION (`initExpensiveAndroidView`): the default
/// `AndroidView` uses TextureLayerHybridComposition, which does not support
/// SurfaceView content correctly — composition alternated our rendered frames
/// with black ones (strobe visible on the artwork background). Hybrid
/// composition places the real SurfaceView in the Android view hierarchy.
///
/// mode: 0 = stereo oscilloscope, 1 = per-voice scopes, 2 = notes.
class RewampVizPlatformView extends StatelessWidget {
  final int mode;
  const RewampVizPlatformView({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    // Detach entirely while the soft keyboard is up. Hybrid composition is not
    // free: as long as this view is in the tree, Flutter renders the whole UI
    // through FlutterImageViews and re-composes every frame, and that turns the
    // keyboard's inset animation into slow-motion scrolling (reported while
    // creating a playlist over a running visualizer). Nothing is lost — the
    // keyboard means a text field, i.e. a sheet or dialog covering the viz
    // anyway. Coming back re-creates the view, which costs one surface rebind,
    // the same as switching visualizer.
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const ColoredBox(color: Color(0xFF000000));
    }
    // IgnorePointer: display-only — taps must reach the Flutter overlay
    // controls (viz selector buttons), not the platform view.
    return IgnorePointer(
      child: PlatformViewLink(
        viewType: 'rewamp_viz_surface',
        surfaceFactory: (context, controller) => AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        ),
        onCreatePlatformView: (params) {
          final controller = PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: 'rewamp_viz_surface',
            layoutDirection: TextDirection.ltr,
            creationParams: {'mode': mode},
            creationParamsCodec: const StandardMessageCodec(),
          );
          controller
            ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
            ..create();
          return controller;
        },
      ),
    );
  }
}
