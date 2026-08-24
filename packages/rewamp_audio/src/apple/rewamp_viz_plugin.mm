// Included after rewamp_viz_texture.h + rewamp_viz_texture.mm.
// RewampVizTexture @interface already declared.
#if TARGET_OS_OSX
#import <FlutterMacOS/FlutterMacOS.h>
#else
#import <Flutter/Flutter.h>
#endif
#include "rewamp_audio.h"

static id<FlutterTextureRegistry> g_textureRegistry = nil;
static RewampVizTexture*          g_vizTexture       = nil;

// mode 0 = stereo waveform, 1 = per-channel scope, 2 = note scroll,
// 3 = projectM, 4 = tracker patterns, 5 = stereo spectrum (FFT)
static int g_viz_mode = 0;

// Switching visualizer must NOT rebuild the GL world.
//
// All four renderers share ONE EGL context (they all call rewamp_gl_init), so
// tearing it down between them was pure waste: the next one rebuilt an identical
// context, re-created the pixel buffers, recompiled its shaders, and — on
// ANGLE/Metal — built its pipeline state at the first draw. That is the several
// hundred milliseconds between tapping a viz button and seeing it change.
//
// Now the context and the Flutter texture SURVIVE a switch: we only initialize
// the incoming renderer (whose own program is compiled once and kept) and hand
// back the same texture id. The teardown belongs to leaving the visualizer, and
// that is what rewamp_viz_unregister() is for.
static int64_t _register_common(int mode, int width, int height) {
    if (!g_textureRegistry) return -1;
    const BOOL reuse = (g_vizTexture != nil);
    g_viz_mode = mode;
    // A REGISTER at a size the live surface doesn't have must still resize it.
    // Every renderer's init calls rewamp_gl_ensure(), which deliberately
    // IGNORES the size when a context is already alive (that idempotence is
    // what makes switching visualizers cheap) — so a register arriving at a new
    // size kept the old surface, and Flutter stretched the old-aspect frame
    // into the new box. That is what deformed the pattern grid in fullscreen.
    if (reuse && (rewamp_gl_width() != width || rewamp_gl_height() != height)) {
        rewamp_gl_resize(width, height);
    }
    int err;
    if      (mode == 1) err = rewamp_scope_init(width, height);
    else if (mode == 2) err = rewamp_noteviz_init(width, height);
#if defined(REWAMP_WITH_PROJECTM)
    else if (mode == 3) err = rewamp_projectm_init(width, height);
#endif
    else if (mode == 4) err = rewamp_patternviz_init(width, height);
    else if (mode == 5) err = rewamp_spectrum_init(width, height);
    else                err = rewamp_viz_init(width, height);
    if (err != 0) return (int64_t)err;
    if (reuse) return [g_vizTexture textureId];
    g_vizTexture = [[RewampVizTexture alloc] init];
    return [g_vizTexture registerWithRegistry:g_textureRegistry];
}

REWAMP_EXPORT int64_t rewamp_viz_register(int width, int height) {
    return _register_common(0, width, height);
}

REWAMP_EXPORT int64_t rewamp_scope_register(int width, int height) {
    return _register_common(1, width, height);
}

REWAMP_EXPORT int64_t rewamp_noteviz_register(int width, int height) {
    return _register_common(2, width, height);
}

#if defined(REWAMP_WITH_PROJECTM)
REWAMP_EXPORT int64_t rewamp_projectm_register(int width, int height) {
    return _register_common(3, width, height);
}

REWAMP_EXPORT void rewamp_projectm_render_and_notify(void) {
    rewamp_projectm_render();
    if (g_vizTexture) [g_vizTexture markFrameAvailable];
}
#endif

REWAMP_EXPORT void rewamp_noteviz_render_and_notify(void) {
    rewamp_noteviz_render();
    if (g_vizTexture) [g_vizTexture markFrameAvailable];
}

REWAMP_EXPORT int64_t rewamp_patternviz_register(int width, int height) {
    return _register_common(4, width, height);
}

REWAMP_EXPORT void rewamp_patternviz_render_and_notify(void) {
    rewamp_patternviz_render();
    if (g_vizTexture) [g_vizTexture markFrameAvailable];
}

REWAMP_EXPORT int64_t rewamp_spectrum_register(int width, int height) {
    return _register_common(5, width, height);
}

REWAMP_EXPORT void rewamp_spectrum_render_and_notify(void) {
    rewamp_spectrum_render();
    if (g_vizTexture) [g_vizTexture markFrameAvailable];
}

REWAMP_EXPORT int rewamp_viz_resize_register(int width, int height) {
    int err = rewamp_gl_resize(width, height);
    if (err == 0 && g_vizTexture) [g_vizTexture markFrameAvailable];
    return err;
}

REWAMP_EXPORT void rewamp_viz_render_and_notify(void) {
    rewamp_viz_render();
    if (g_vizTexture) [g_vizTexture markFrameAvailable];
}

REWAMP_EXPORT void rewamp_scope_render_and_notify(void) {
    rewamp_scope_render();
    if (g_vizTexture) [g_vizTexture markFrameAvailable];
}

REWAMP_EXPORT void rewamp_viz_unregister(void) {
    if (g_vizTexture) { [g_vizTexture unregister]; g_vizTexture = nil; }
    rewamp_viz_uninit();
    rewamp_scope_uninit();
    rewamp_noteviz_uninit();
    rewamp_patternviz_uninit();
    rewamp_spectrum_uninit();
#if defined(REWAMP_WITH_PROJECTM)
    rewamp_projectm_uninit();
#endif
}

@interface RewampVizFlutterPlugin : NSObject <FlutterPlugin>
@end

@implementation RewampVizFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    g_textureRegistry = [registrar textures];
}
@end
