// Oscilloscope GL renderer — shared between iOS (GLES 3.0 via MetalANGLE)
// and macOS (OpenGL 3.2 core native).
// Included as part of rewamp_viz_impl.mm; GL headers already visible.
#include "rewamp_audio.h"
#include "rewamp_gl.h"   // rewamp_gl_ensure / rewamp_gl_generation
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <mutex>

#define VIZ_SAMPLES REWAMP_WAVEFORM_COUNT

#ifdef REWAMP_GL_GLES
static const char *k_gl_preamble = "#version 300 es\nprecision mediump float;\n";
#else
static const char *k_gl_preamble = "#version 150\n";
#endif

static const char *k_vert_body =
    "in vec2 aPos;\n"
    "in float aAlpha;\n"
    "out float vAlpha;\n"
    "void main() { gl_Position = vec4(aPos, 0.0, 1.0); vAlpha = aAlpha; }\n";

static const char *k_frag_body =
    "uniform vec4 uColor;\n"
    "in float vAlpha;\n"
    "out vec4 fragColor;\n"
    "void main() { fragColor = vec4(uColor.rgb, uColor.a * vAlpha); }\n";

static unsigned g_viz_gen = 0;   // GL generation these objects were built on
static GLuint g_prog = 0;
static GLuint g_vao = 0;
static GLuint g_vbo = 0;
static GLuint g_vbo_a = 0;     // per-vertex alpha (beam-speed intensity)
static GLint g_colorLoc = -1;
static GLint g_alphaLoc = -1;  // aAlpha attribute location
// Trigger stabilisation: fetch extra samples so we can search for a
// rising zero-crossing before the display window.
#define VIZ_TRIGGER_GUARD 256  // extra samples to search in (≥ VIZ_SAMPLES/2)
#define VIZ_FETCH (VIZ_SAMPLES + VIZ_TRIGGER_GUARD)

static GLfloat g_verts[VIZ_SAMPLES * 2 * 2];
static float g_left[VIZ_FETCH];
static float g_right[VIZ_FETCH];

// Forward declarations (definitions later in this TU).
static GLuint compile_shader(GLenum type, const char *preamble, const char *body);
static GLuint link_program(GLuint vert, GLuint frag);

// Triangle-strip ribbon: 2 vertices per polyline point.
static GLfloat g_ribbon[VIZ_SAMPLES * 2 * 2];

// Expands a polyline (NDC, interleaved x,y, `n` points) into a triangle-strip
// ribbon of constant pixel thickness. Writes 2*n (x,y) vertices into out.
// Thickness is computed in pixel space (via viewport W/H) so it's uniform
// regardless of aspect ratio. glLineWidth is a no-op on Metal/ANGLE, hence this.
static void build_ribbon(const float* pts, int n, float thickPx,
                         int W, int H, GLfloat* out)
{
    const float halfX = thickPx * 0.5f / (float)W * 2.0f; // px→NDC, ×½ width
    const float halfY = thickPx * 0.5f / (float)H * 2.0f;
    for (int i = 0; i < n; i++) {
        // Tangent from neighbours in pixel space.
        int a = i > 0 ? i - 1 : i;
        int b = i < n - 1 ? i + 1 : i;
        float dx = (pts[b * 2]     - pts[a * 2])     * (float)W; // NDC→px (×W/2 dropped, normalised below)
        float dy = (pts[b * 2 + 1] - pts[a * 2 + 1]) * (float)H;
        float len = sqrtf(dx * dx + dy * dy);
        if (len < 1e-6f) { dx = 1.0f; dy = 0.0f; len = 1.0f; }
        // Normal (perpendicular), unit length in pixel space.
        float nx = -dy / len;
        float ny =  dx / len;
        float ox = nx * halfX;
        float oy = ny * halfY;
        out[i * 4]     = pts[i * 2]     + ox;
        out[i * 4 + 1] = pts[i * 2 + 1] + oy;
        out[i * 4 + 2] = pts[i * 2]     - ox;
        out[i * 4 + 3] = pts[i * 2 + 1] - oy;
    }
}

// Per-ribbon-vertex alpha for the beam-speed effect: slow beam (short segment
// in pixels) = brighter, fast beam = dimmer — mimics CRT phosphor dwell time.
static GLfloat g_ribbon_a[VIZ_SAMPLES * 2];

// level 1 = low (subtle), 2 = high (strong contrast between slow/fast beam).
static void build_speed_alpha(const float* pts, int n, int level, int W, int H, GLfloat* outA)
{
    const float factor = level == 2 ? 0.12f : 0.06f;
    const float minA   = level == 2 ? 0.08f : 0.25f;
    for (int i = 0; i < n; i++) {
        int a = i > 0 ? i - 1 : i;
        int b = i < n - 1 ? i + 1 : i;
        float dx = (pts[b * 2]     - pts[a * 2])     * (float)W;
        float dy = (pts[b * 2 + 1] - pts[a * 2 + 1]) * (float)H;
        float spd = sqrtf(dx * dx + dy * dy) / (b - a > 0 ? (b - a) : 1);
        float al = 1.0f - spd * factor;
        if (al < minA) al = minA;
        if (al > 1.0f) al = 1.0f;
        outA[i * 2]     = al;
        outA[i * 2 + 1] = al;
    }
}


// Returns the index in [0, VIZ_TRIGGER_GUARD) of the first rising
// zero-crossing in buf[], or 0 if none found.
static int find_trigger(const float* buf, int guard)
{
    // Hysteresis: require previous sample < -threshold, current >= +threshold.
    static const float kThresh = 0.02f;
    for (int i = 1; i < guard; i++) {
        if (buf[i - 1] < -kThresh && buf[i] >= kThresh) return i;
    }
    // Fallback: simple zero-crossing (no hysteresis).
    for (int i = 1; i < guard; i++) {
        if (buf[i - 1] < 0.0f && buf[i] >= 0.0f) return i;
    }
    return 0;
}

static GLuint compile_shader(GLenum type, const char *preamble, const char *body)
{
    GLuint s = glCreateShader(type);
    const char *srcs[2] = {preamble, body};
    glShaderSource(s, 2, srcs, NULL);
    glCompileShader(s);
    GLint ok = 0;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok)
    {
        char log[512];
        glGetShaderInfoLog(s, sizeof(log), NULL, log);
        fprintf(stderr, "rewamp_viz: shader error: %s\n", log);
        glDeleteShader(s);
        return 0;
    }
    return s;
}

static GLuint link_program(GLuint vert, GLuint frag)
{
    GLuint p = glCreateProgram();
    glAttachShader(p, vert);
    glAttachShader(p, frag);
    glBindAttribLocation(p, 0, "aPos");
    glLinkProgram(p);
    GLint ok = 0;
    glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok)
    {
        char log[512];
        glGetProgramInfoLog(p, sizeof(log), NULL, log);
        fprintf(stderr, "rewamp_viz: link error: %s\n", log);
        glDeleteProgram(p);
        return 0;
    }
    return p;
}

// ── Artwork background quad ───────────────────────────────────────────────────
// Shared between oscilloscope and channel-scope renderers (same TU).
// Pixels are stored on the C heap until the next render call uploads them to GL.

static GLuint  g_art_tex    = 0;
static GLuint  g_art_prog   = 0;
static GLuint  g_art_vao    = 0;
static GLuint  g_art_vbo    = 0;
static GLint   g_art_opacLoc  = -1;
static GLint   g_art_vaLoc    = -1;
static GLint   g_art_taLoc    = -1;
static GLint   g_art_sampLoc  = -1;
static int     g_art_tw     = 1;
static int     g_art_th     = 1;
static float   g_art_opacity = 0.0f;

static uint8_t* g_art_pending = nullptr;
static int      g_art_pending_w = 0;
static int      g_art_pending_h = 0;
static volatile int g_art_dirty = 0;
// On Android the GL renderer runs on its own thread (sv_thread_main) while Dart
// calls rewamp_viz_set_artwork/clear_artwork from the platform thread — so the
// pending buffer + its dims are touched concurrently. Without this lock the
// render thread could glTexImage2D from a buffer that set_artwork just free()d or
// is mid-memcpy (→ wrong/garbage artwork, most visible on viz re-enable). On
// Apple everything is on one thread, so the lock is uncontended.
static std::mutex g_art_mtx;

// Vertex shader: maps NDC quad to screen UV. A top-down artwork image needs its
// UV.y flipped on iOS (MetalANGLE glReadPixels path) and Android GLES, but NOT on
// macOS: its ANGLE IOSurface keeps the same bottom-left GL origin as the old
// NSOpenGL path, so the artwork renders upright without a flip (flipping it there
// turned the background upside down after the macOS EGL/ANGLE migration).
#if defined(__APPLE__)
#  include <TargetConditionals.h>
#endif
#if defined(REWAMP_GL_GLES) && !(defined(__APPLE__) && TARGET_OS_OSX)
#  define ART_UV_Y "1.0 - (aPos.y * 0.5 + 0.5)"
#else
#  define ART_UV_Y "aPos.y * 0.5 + 0.5"
#endif
static const char *k_art_vert =
    "in vec2 aPos;\n"
    "out vec2 vUV;\n"
    "void main() {\n"
    "    gl_Position = vec4(aPos, 0.0, 1.0);\n"
    "    vUV = vec2(aPos.x * 0.5 + 0.5, " ART_UV_Y ");\n"
    "}\n";

// Fragment shader: BoxFit.contain UV scaling + opacity.
// The artwork is scaled to fit entirely within the viewport (no cropping),
// centered, with transparent padding — matches how ArtworkImage renders alone.
static const char *k_art_frag =
    "uniform sampler2D uTex;\n"
    "uniform float uOpacity;\n"
    "uniform float uViewAsp;\n"
    "uniform float uTexAsp;\n"
    "in vec2 vUV;\n"
    "out vec4 fragColor;\n"
    "void main() {\n"
    "    vec2 uv = vUV;\n"
    "    if (uViewAsp > uTexAsp) {\n"
    "        float r = uTexAsp / uViewAsp;\n"
    "        uv.x = 0.5 + (uv.x - 0.5) / r;\n"
    "    } else {\n"
    "        float r = uViewAsp / uTexAsp;\n"
    "        uv.y = 0.5 + (uv.y - 0.5) / r;\n"
    "    }\n"
    "    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {\n"
    "        fragColor = vec4(0.0);\n"
    "        return;\n"
    "    }\n"
    "    vec4 col = texture(uTex, uv);\n"
    "    fragColor = vec4(col.rgb, col.a * uOpacity);\n"
    "}\n";

static void art_init_gl(void)
{
    GLuint vert = compile_shader(GL_VERTEX_SHADER,   k_gl_preamble, k_art_vert);
    GLuint frag = compile_shader(GL_FRAGMENT_SHADER, k_gl_preamble, k_art_frag);
    if (!vert || !frag) return;
    g_art_prog = link_program(vert, frag);
    glDeleteShader(vert);
    glDeleteShader(frag);
    if (!g_art_prog) return;

    g_art_opacLoc = glGetUniformLocation(g_art_prog, "uOpacity");
    g_art_vaLoc   = glGetUniformLocation(g_art_prog, "uViewAsp");
    g_art_taLoc   = glGetUniformLocation(g_art_prog, "uTexAsp");
    g_art_sampLoc = glGetUniformLocation(g_art_prog, "uTex");

    static const GLfloat kQuad[] = {
        -1.f, -1.f,   1.f, -1.f,   -1.f,  1.f,
         1.f, -1.f,   1.f,  1.f,   -1.f,  1.f,
    };
    glGenVertexArrays(1, &g_art_vao);
    glBindVertexArray(g_art_vao);
    glGenBuffers(1, &g_art_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, g_art_vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(kQuad), kQuad, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), (void *)0);
    glBindVertexArray(0);

    glGenTextures(1, &g_art_tex);
    glBindTexture(GL_TEXTURE_2D, g_art_tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glBindTexture(GL_TEXTURE_2D, 0);
}

static void art_upload_if_dirty(void)
{
    // Hold the lock across the glTexImage2D read so set_artwork can't free/rewrite
    // g_art_pending mid-upload (glTexImage2D copies synchronously, so the buffer is
    // fully consumed before we release). set_artwork is rare → no real contention.
    std::lock_guard<std::mutex> lk(g_art_mtx);
    if (!g_art_dirty) return;

    if (!g_art_prog) art_init_gl();
    // Clear the flag ONLY once we are actually going to upload. Clearing it up
    // front dropped the artwork for good whenever this ran before the GL
    // objects existed (Android renders on its own thread, so a set_artwork can
    // land in that window): the cover then stayed missing until some later
    // set_artwork re-raised the flag.
    if (!g_art_prog || !g_art_pending) return;
    g_art_dirty = 0;

    glBindTexture(GL_TEXTURE_2D, g_art_tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,
                 g_art_pending_w, g_art_pending_h,
                 0, GL_RGBA, GL_UNSIGNED_BYTE, g_art_pending);
    glBindTexture(GL_TEXTURE_2D, 0);

    g_art_tw = g_art_pending_w;
    g_art_th = g_art_pending_h;
    /* Keep g_art_pending alive: the GL context is torn down and recreated each
     * time the viz widget switches (stereo ↔ voices) or resizes, which destroys
     * g_art_tex. art_cleanup re-flags g_art_dirty so the next context re-uploads
     * from this cached copy — otherwise the artwork background would vanish on
     * every mode switch. The copy is freed only by set_artwork/clear_artwork. */
}

static void art_render(int vw, int vh)
{
    if (!g_art_prog || !g_art_tex || g_art_opacity <= 0.001f || g_art_tw < 1 || g_art_th < 1) return;
    glUseProgram(g_art_prog);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, g_art_tex);
    glUniform1i(g_art_sampLoc,  0);
    glUniform1f(g_art_opacLoc,  g_art_opacity);
    glUniform1f(g_art_vaLoc,    (float)vw / (float)vh);
    glUniform1f(g_art_taLoc,    (float)g_art_tw / (float)g_art_th);
    glBindVertexArray(g_art_vao);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    glBindVertexArray(0);
    glBindTexture(GL_TEXTURE_2D, 0);
}

/* The context is GONE (lost, or rebuilt after loss): forget the handles WITHOUT
 * touching GL — the objects died with it, and deleting them would be issuing
 * calls against a dead context. Pixels are kept and re-flagged dirty, so the
 * next upload recreates the texture. Without this the artwork background just
 * silently stopped appearing: the code held a non-zero, dangling texture id and
 * happily bound it. */
static void art_invalidate(void)
{
    g_art_tex = 0; g_art_prog = 0; g_art_vbo = 0; g_art_vao = 0;
    g_art_tw = 1; g_art_th = 1;
    std::lock_guard<std::mutex> lk(g_art_mtx);
    g_art_dirty = (g_art_pending != nullptr) ? 1 : 0;
}

static void art_cleanup(void)
{
    /* Context teardown (widget switch/resize): drop GL objects but KEEP the
     * cached pixels and re-flag dirty so the next context re-uploads them. */
    if (g_art_tex)  { glDeleteTextures(1, &g_art_tex);       g_art_tex  = 0; }
    if (g_art_prog) { glDeleteProgram(g_art_prog);            g_art_prog = 0; }
    if (g_art_vbo)  { glDeleteBuffers(1, &g_art_vbo);         g_art_vbo  = 0; }
    if (g_art_vao)  { glDeleteVertexArrays(1, &g_art_vao);    g_art_vao  = 0; }
    g_art_tw = 1; g_art_th = 1;
    // Re-flag under the lock: g_art_pending may be swapped by a concurrent
    // set_artwork/clear_artwork on the platform thread.
    std::lock_guard<std::mutex> lk(g_art_mtx);
    g_art_dirty = (g_art_pending != nullptr) ? 1 : 0;
}

REWAMP_EXPORT void rewamp_viz_set_artwork(const uint8_t* rgba, int w, int h, float opacity)
{
    std::lock_guard<std::mutex> lk(g_art_mtx);
    g_art_opacity = opacity;
    if (g_art_pending) { free(g_art_pending); g_art_pending = nullptr; }
    if (rgba && w > 0 && h > 0) {
        size_t sz = (size_t)w * h * 4;
        g_art_pending = (uint8_t*)malloc(sz);
        if (g_art_pending) {
            memcpy(g_art_pending, rgba, sz);
            g_art_pending_w = w;
            g_art_pending_h = h;
        }
    }
    g_art_dirty = 1;
}

REWAMP_EXPORT void rewamp_viz_set_artwork_opacity(float opacity)
{
    g_art_opacity = opacity;
}

REWAMP_EXPORT void rewamp_viz_clear_artwork(void)
{
    std::lock_guard<std::mutex> lk(g_art_mtx);
    g_art_opacity = 0.0f;
    if (g_art_pending) { free(g_art_pending); g_art_pending = nullptr; }
    g_art_dirty = 0;
}

// ── Oscilloscope renderer ─────────────────────────────────────────────────────

REWAMP_EXPORT int rewamp_viz_init(int width, int height)
{
    // Ensures a USABLE context — creating one, or REBUILDING it if the OS
    // destroyed ours (a long spell in the background, memory pressure, a GPU
    // reset). That check matters now: the context survives a visualizer switch,
    // so a lost one no longer heals itself on the next switch.
    {
        int err = rewamp_gl_ensure(width, height);
        if (err != 0)
            return err;
    }

    // Reuse only if built on THIS context: a non-zero id is not enough — after a
    // rebuild it is a stale handle pointing at nothing.
    if (g_prog && g_viz_gen == rewamp_gl_generation())
        return 0;
    g_prog = 0;   // stale (or first time): rebuild below
    // The artwork texture died with the old context too — it lives in this file.
    // Drop the handle so the next upload recreates it instead of binding a
    // dangling id (that is how the background silently vanished).
    art_invalidate();

    GLuint vert = compile_shader(GL_VERTEX_SHADER, k_gl_preamble, k_vert_body);
    GLuint frag = compile_shader(GL_FRAGMENT_SHADER, k_gl_preamble, k_frag_body);
    if (!vert || !frag)
        return -10;

    g_prog = link_program(vert, frag);
    glDeleteShader(vert);
    glDeleteShader(frag);
    if (!g_prog)
        return -11;

    g_colorLoc = glGetUniformLocation(g_prog, "uColor");
    g_alphaLoc = glGetAttribLocation(g_prog, "aAlpha");

    glGenVertexArrays(1, &g_vao);
    glBindVertexArray(g_vao);
    glGenBuffers(1, &g_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, g_vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(g_ribbon), NULL, GL_DYNAMIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), (void *)0);
    // Per-vertex alpha buffer (beam-speed intensity).
    glGenBuffers(1, &g_vbo_a);
    glBindBuffer(GL_ARRAY_BUFFER, g_vbo_a);
    glBufferData(GL_ARRAY_BUFFER, sizeof(g_ribbon_a), NULL, GL_DYNAMIC_DRAW);
    if (g_alphaLoc >= 0) {
        glEnableVertexAttribArray(g_alphaLoc);
        glVertexAttribPointer(g_alphaLoc, 1, GL_FLOAT, GL_FALSE, sizeof(GLfloat), (void *)0);
    }
    glBindVertexArray(0);
    g_viz_gen = rewamp_gl_generation();   // these objects belong to THIS context
    return 0;
}

// Draws one channel's trace (ribbon) with optional CRT glow + beam-speed alpha.
static void draw_trace(const float* pts, float r, float g, float b,
                       int glowLvl, int speedLvl, float thick, int W, int H)
{
    const GLsizei ribbonBytes = (GLsizei)(sizeof(GLfloat) * VIZ_SAMPLES * 4);

    // Per-vertex alpha (beam speed) or constant 1.0.
    if (speedLvl > 0) {
        build_speed_alpha(pts, VIZ_SAMPLES, speedLvl, W, H, g_ribbon_a);
        glBindBuffer(GL_ARRAY_BUFFER, g_vbo_a);
        glBufferData(GL_ARRAY_BUFFER, (GLsizei)sizeof(g_ribbon_a), g_ribbon_a, GL_DYNAMIC_DRAW) /* orphan: tiler-safe */;
        if (g_alphaLoc >= 0) glEnableVertexAttribArray(g_alphaLoc);
    } else if (g_alphaLoc >= 0) {
        glDisableVertexAttribArray(g_alphaLoc);
        glVertexAttrib1f(g_alphaLoc, 1.0f);
    }

    if (glowLvl > 0) {
        // Additive halo passes; high level = wider + brighter.
        const float w1 = glowLvl == 2 ? 6.0f : 4.0f;
        const float w2 = glowLvl == 2 ? 3.0f : 2.0f;
        const float a1 = glowLvl == 2 ? 0.28f : 0.18f;
        const float a2 = glowLvl == 2 ? 0.42f : 0.30f;
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
        build_ribbon(pts, VIZ_SAMPLES, thick * w1, W, H, g_ribbon);
        glBindBuffer(GL_ARRAY_BUFFER, g_vbo);
        glBufferData(GL_ARRAY_BUFFER, ribbonBytes, g_ribbon, GL_DYNAMIC_DRAW) /* orphan: tiler-safe */;
        glUniform4f(g_colorLoc, r, g, b, a1);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, VIZ_SAMPLES * 2);

        build_ribbon(pts, VIZ_SAMPLES, thick * w2, W, H, g_ribbon);
        glBufferData(GL_ARRAY_BUFFER, ribbonBytes, g_ribbon, GL_DYNAMIC_DRAW) /* orphan: tiler-safe */;
        glUniform4f(g_colorLoc, r, g, b, a2);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, VIZ_SAMPLES * 2);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }

    // Core trace.
    build_ribbon(pts, VIZ_SAMPLES, thick, W, H, g_ribbon);
    glBindBuffer(GL_ARRAY_BUFFER, g_vbo);
    glBufferData(GL_ARRAY_BUFFER, ribbonBytes, g_ribbon, GL_DYNAMIC_DRAW) /* orphan: tiler-safe */;
    glUniform4f(g_colorLoc, r, g, b, 1.0f);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, VIZ_SAMPLES * 2);
}

#ifdef __ANDROID__
// Force the framebuffer fully OPAQUE before presenting. The glow/trace blend with
// SRC_ALPHA and leave per-pixel alpha < 1 where nothing opaque was drawn; the
// Android viz is an OPAQUE SurfaceView layer, so any alpha < 1 makes SurfaceFlinger
// BLEND the layer over whatever is behind it — a stale/frozen backing buffer —
// which reads as a static ghost image showing THROUGH the live viz. Alpha-only
// clear to 1. MUST run on the same buffer that is about to be presented (i.e. just
// before this frame's single rewamp_gl_flush/eglSwapBuffers): doing it after the
// swap (as the old sv_thread loop did) touched an already-rotated buffer AND caused
// a second swap that presented that stale buffer.
static void rewamp_gl_force_opaque(void)
{
    glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_TRUE);
    glClearColor(0.f, 0.f, 0.f, 1.f);
    glClear(GL_COLOR_BUFFER_BIT);
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
}
#endif

REWAMP_EXPORT void rewamp_viz_render(void)
{
    rewamp_gl_make_current();
    rewamp_get_waveform(g_left, g_right, VIZ_FETCH);

    // Find a stable trigger point using the left channel.
    int trig = find_trigger(g_left, VIZ_TRIGGER_GUARD);

    for (int i = 0; i < VIZ_SAMPLES; i++)
    {
        float x = (float)i / (VIZ_SAMPLES - 1) * 2.0f - 1.0f;
        g_verts[i * 2] = x;
        g_verts[i * 2 + 1] = g_left[trig + i];
        g_verts[VIZ_SAMPLES * 2 + i * 2] = x;
        g_verts[VIZ_SAMPLES * 2 + i * 2 + 1] = g_right[trig + i];
    }

    const int flags    = rewamp_get_crt_flags();
    const int glowLvl  = REWAMP_CRT_GLOW_LEVEL(flags);
    const int speedLvl = REWAMP_CRT_SPEED_LEVEL(flags);
    const int W = rewamp_gl_width();
    const int H = rewamp_gl_height();

    glBindFramebuffer(GL_FRAMEBUFFER, rewamp_gl_get_fbo());
    glViewport(0, 0, W, H);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    art_upload_if_dirty();
    art_render(W, H);

    glUseProgram(g_prog);
    glBindVertexArray(g_vao);

    const float thick = rewamp_get_viz_line_width(); // x1 ≈ old 1px GL line
    // Mono: both channels share one color; bi-color: separate L/R colors.
    const float* cl = rewamp_stereo_bicolor() ? rewamp_stereo_left_color()
                                              : rewamp_stereo_mono_color();
    const float* cr = rewamp_stereo_bicolor() ? rewamp_stereo_right_color()
                                              : rewamp_stereo_mono_color();
    draw_trace(g_verts,                   cl[0], cl[1], cl[2], glowLvl, speedLvl, thick, W, H);
    draw_trace(g_verts + VIZ_SAMPLES * 2, cr[0], cr[1], cr[2], glowLvl, speedLvl, thick, W, H);

    glBindVertexArray(0);
#ifdef __ANDROID__
    rewamp_gl_force_opaque();
#endif
    rewamp_gl_flush();
}

REWAMP_EXPORT void rewamp_viz_uninit(void)
{
    if (g_prog)
    {
        glDeleteProgram(g_prog);
        g_prog = 0;
    }
    if (g_vbo)
    {
        glDeleteBuffers(1, &g_vbo);
        g_vbo = 0;
    }
    if (g_vao)
    {
        glDeleteVertexArrays(1, &g_vao);
        g_vao = 0;
    }
    if (g_vbo_a) { glDeleteBuffers(1, &g_vbo_a); g_vbo_a = 0; }
    art_cleanup();
    rewamp_gl_uninit();
}
