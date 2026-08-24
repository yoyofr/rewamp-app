#ifndef REWAMP_GL_H
#define REWAMP_GL_H

#ifdef __cplusplus
extern "C" {
#endif

// Offscreen OpenGL ES 3.0 context for visualizer rendering.
// iOS: backed by Google MetalANGLE (OpenGL ES → Metal).
// Android/Linux: backed by native EGL.
//
// Returns 0 on success, negative error code on failure.
int          rewamp_gl_init(int width, int height);
void         rewamp_gl_make_current(void);

// Make sure a USABLE context exists, and say whether it is the same one as last
// time. This is what the renderers must call — not init/make_current directly.
//
// Two things it handles that a raw make_current cannot:
//   - The context now SURVIVES a visualizer switch (that is the whole point:
//     rebuilding it cost ~38 ms and threw away every compiled program). So a
//     context the OS destroyed under us — GPU reset, memory pressure, a long
//     spell in the background — used to self-heal on the next switch and no
//     longer does. eglMakeCurrent's return value was being thrown away;
//     EGL_CONTEXT_LOST is now caught and the context rebuilt.
//   - When it IS rebuilt, every GL object the renderers cached (programs, VAOs,
//     the artwork texture) belongs to the dead context and must be rebuilt too.
//     rewamp_gl_generation() changes on every new context, so each renderer can
//     tell "mine is still valid" from "mine is a stale handle" — which a plain
//     non-zero id cannot.
//
// Returns 0 on success, negative on failure.
int          rewamp_gl_ensure(int width, int height);
// Bumped on every context creation. Renderers cache it alongside their GL
// objects; a change means those objects are gone with the old context.
unsigned     rewamp_gl_generation(void);
// Signals end of a frame — call after rendering, before reading the texture.
void         rewamp_gl_flush(void);
void         rewamp_gl_uninit(void);

// FBO name that ProjectM / visualizers should bind and render into.
unsigned int rewamp_gl_get_fbo(void);
// RGBA8 color texture attached to the FBO (256×height pixels).
unsigned int rewamp_gl_get_texture(void);

int  rewamp_gl_width(void);
int  rewamp_gl_height(void);

// ── Preload context — background shader compilation (projectM) ──────────────
// A SECOND EGL context in the same share group as the render context, made
// current on a dedicated worker thread. Shaders/programs are share-group
// objects in GLES3, so a program linked on the worker is usable by the render
// context (after a glFlush on the worker side); FBOs/VAOs are NOT shared —
// the preload path must not create any. This is the only legal way to compile
// GL shaders off the render thread: an EGLContext is current to exactly one
// thread at a time, and GL calls without a current context are no-ops.
//
// create() is called from the render thread (idempotent; needs the main
// context to exist); make_current()/release() from the worker. create()
// returning nonzero = no preload support -> caller must fall back to
// synchronous loads.
int  rewamp_gl_preload_context_create(void);
int  rewamp_gl_preload_make_current(void);
void rewamp_gl_preload_release(void);

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_GL_H */
