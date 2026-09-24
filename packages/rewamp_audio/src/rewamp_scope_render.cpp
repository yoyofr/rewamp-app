// Per-channel (multi-voice) oscilloscope GL renderer — shared iOS/macOS.
// Included as part of rewamp_viz_impl.mm; GL headers already visible.
#include "rewamp_audio.h"
#include "rewamp_gl.h"   // rewamp_gl_ensure / rewamp_gl_generation
#include "rewamp_gl_orientation.h"   // REWAMP_GL_Y_FLIPPED — macOS only, NOT all Apple
#include <stdlib.h>
#include <math.h>
#include <stdio.h>

#define SCOPE_SAMPLES  512
#define MAX_VOICES     32

static unsigned g_scope_gen = 0;
static GLuint g_scope_prog     = 0;
static GLuint g_scope_vao      = 0;
static GLuint g_scope_vbo      = 0;
static GLint  g_scope_colorLoc = -1;

static GLfloat g_scope_verts[SCOPE_SAMPLES * 2];
static GLfloat g_scope_ribbon[SCOPE_SAMPLES * 4]; // 2 verts/point for thickness
static GLfloat g_scope_ribbon_a[SCOPE_SAMPLES * 2]; // per-vertex alpha (speed)
static int8_t  g_scope_buf[SCOPE_SAMPLES];

static GLuint g_scope_vbo_a    = 0;   // alpha VBO (beam-speed intensity)
static GLint  g_scope_alphaLoc = -1;

// Defined in rewamp_viz_render.cpp (same TU).
static void build_ribbon(const float* pts, int n, float thickPx,
                         int W, int H, GLfloat* out);
static void build_speed_alpha(const float* pts, int n, int level, int W, int H, GLfloat* outA);

/* Whether the per-cell border grid is drawn (toggled from settings). */
static int g_scope_grid = 1;

REWAMP_EXPORT void rewamp_scope_set_grid(int enabled) { g_scope_grid = enabled ? 1 : 0; }

// k_gl_preamble is defined in rewamp_viz_render.cpp (same TU).

static GLuint scope_compile(GLenum type, const char* body) {
    GLuint s = glCreateShader(type);
    const char* srcs[2] = { k_gl_preamble, body };
    glShaderSource(s, 2, srcs, NULL);
    glCompileShader(s);
    GLint ok = 0; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[512]; glGetShaderInfoLog(s, sizeof(log), NULL, log);
        fprintf(stderr, "rewamp_scope: shader error: %s\n", log);
        glDeleteShader(s); return 0;
    }
    return s;
}

// Best column count: minimise |cellW/cellH - 2.0|
static int best_cols(int n, float w, float h) {
    if (n <= 0 || h <= 0) return 1;
    int   best = 1;
    float bestDiff = 1e9f;
    for (int c = 1; c <= n; c++) {
        int   rows  = (n + c - 1) / c;
        float ratio = (w / c) / (h / rows);
        float diff  = fabsf(ratio - 2.0f);
        if (diff < bestDiff) { bestDiff = diff; best = c; }
    }
    return best;
}

REWAMP_EXPORT int rewamp_scope_init(int width, int height) {
    // Ensures a USABLE context (rebuilding it if the OS destroyed ours) and tells
    // us, via the generation, whether our cached GL objects survived.
    {
        int err = rewamp_gl_ensure(width, height);
        if (err != 0) return err;
    }

    // Reuse only if built on THIS context: a non-zero id is not enough —
    // after a context rebuild it is a stale handle pointing at nothing.
    if (g_scope_prog && g_scope_gen == rewamp_gl_generation()) return 0;
    g_scope_prog = 0;   // stale (or first time): rebuild below

    static const char* k_vert =
        "in vec2 aPos;\n"
        "in float aAlpha;\n"
        "out float vAlpha;\n"
        "void main() { gl_Position = vec4(aPos, 0.0, 1.0); vAlpha = aAlpha; }\n";
    static const char* k_frag =
        "uniform vec4 uColor;\n"
        "in float vAlpha;\n"
        "out vec4 fragColor;\n"
        "void main() { fragColor = vec4(uColor.rgb, uColor.a * vAlpha); }\n";

    GLuint vert = scope_compile(GL_VERTEX_SHADER,   k_vert);
    GLuint frag = scope_compile(GL_FRAGMENT_SHADER, k_frag);
    if (!vert || !frag) return -10;

    g_scope_prog = glCreateProgram();
    glAttachShader(g_scope_prog, vert); glAttachShader(g_scope_prog, frag);
    glBindAttribLocation(g_scope_prog, 0, "aPos");
    glLinkProgram(g_scope_prog);
    glDeleteShader(vert); glDeleteShader(frag);
    GLint ok = 0; glGetProgramiv(g_scope_prog, GL_LINK_STATUS, &ok);
    if (!ok) { glDeleteProgram(g_scope_prog); g_scope_prog = 0; return -11; }

    g_scope_colorLoc = glGetUniformLocation(g_scope_prog, "uColor");
    g_scope_alphaLoc = glGetAttribLocation(g_scope_prog, "aAlpha");

    glGenVertexArrays(1, &g_scope_vao);
    glBindVertexArray(g_scope_vao);
    // NOTE on vertex uploads: every upload below uses glBufferData (allocate +
    // fill = buffer ORPHANING), never glBufferSubData. These VBOs are refilled
    // several times PER FRAME (once per voice) with draws still queued on the
    // previous contents; on deferred tiled GPUs (Adreno) glBufferSubData over
    // in-flight draws produced mixed old/new geometry — flickering "ghost"
    // waveforms on Android. Orphaning gives the driver fresh storage per draw.
    glGenBuffers(1, &g_scope_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, g_scope_vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(g_scope_ribbon), NULL, GL_DYNAMIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2*sizeof(GLfloat), (void*)0);
    glGenBuffers(1, &g_scope_vbo_a);
    glBindBuffer(GL_ARRAY_BUFFER, g_scope_vbo_a);
    glBufferData(GL_ARRAY_BUFFER, sizeof(g_scope_ribbon_a), NULL, GL_DYNAMIC_DRAW);
    if (g_scope_alphaLoc >= 0) {
        glEnableVertexAttribArray(g_scope_alphaLoc);
        glVertexAttribPointer(g_scope_alphaLoc, 1, GL_FLOAT, GL_FALSE, sizeof(GLfloat), (void*)0);
    }
    glBindVertexArray(0);
    g_scope_gen = rewamp_gl_generation();   // these objects belong to THIS context
    return 0;
}

// Sets the alpha attribute to a constant (array disabled) for opaque draws.
static void scope_alpha_const(float a) {
    if (g_scope_alphaLoc >= 0) {
        glDisableVertexAttribArray(g_scope_alphaLoc);
        glVertexAttrib1f(g_scope_alphaLoc, a);
    }
}

// Draws the waveform currently in g_scope_verts (SCOPE_SAMPLES pts) with the
// given color, applying the beam-speed alpha at the given level (0/1/2).
//
// ⚠️ Le HALO (« glow ») a été RETIRÉ le 2026-09-15 (demande utilisateur), ici
// comme sur l'oscilloscope stéréo: deux passes larges et additives sous chaque
// trace. Les bits 0-1 de `rewamp_set_crt_flags` restent réservés.
static void scope_draw_wave(const float* color, int speedLvl,
                            float thick, int W, int H) {
    const GLsizei bytes = (GLsizei)(SCOPE_SAMPLES * 4 * sizeof(GLfloat));

    if (speedLvl > 0) {
        build_speed_alpha(g_scope_verts, SCOPE_SAMPLES, speedLvl, W, H, g_scope_ribbon_a);
        glBindBuffer(GL_ARRAY_BUFFER, g_scope_vbo_a);
        glBufferData(GL_ARRAY_BUFFER, (GLsizei)sizeof(g_scope_ribbon_a), g_scope_ribbon_a, GL_DYNAMIC_DRAW) /* orphan: tiler-safe */;
        if (g_scope_alphaLoc >= 0) glEnableVertexAttribArray(g_scope_alphaLoc);
    } else {
        scope_alpha_const(1.0f);
    }

    build_ribbon(g_scope_verts, SCOPE_SAMPLES, thick, W, H, g_scope_ribbon);
    glBindBuffer(GL_ARRAY_BUFFER, g_scope_vbo);
    glBufferData(GL_ARRAY_BUFFER, bytes, g_scope_ribbon, GL_DYNAMIC_DRAW) /* orphan: tiler-safe */;
    glUniform4f(g_scope_colorLoc, color[0], color[1], color[2], 1.0f);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, SCOPE_SAMPLES * 2);
}

REWAMP_EXPORT void rewamp_scope_render(void) {
    rewamp_gl_make_current();

    int n = rewamp_channel_count();
    if (n < 1) n = 1;
    if (n > MAX_VOICES) n = MAX_VOICES;

    float W = (float)rewamp_gl_width();
    float H = (float)rewamp_gl_height();

    int cols = best_cols(n, W, H);
    int rows = (n + cols - 1) / cols;

    // NDC cell size
    float cellW =  2.0f / cols;   // NDC width  per cell
    float cellH =  2.0f / rows;   // NDC height per cell

    const int speedLvl = REWAMP_CRT_SPEED_LEVEL(rewamp_get_crt_flags());
    const float thick = rewamp_get_viz_line_width();

    glBindFramebuffer(GL_FRAMEBUFFER, rewamp_gl_get_fbo());
    glViewport(0, 0, (GLsizei)W, (GLsizei)H);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    // ONCE, on every platform. Android renders into an OPAQUE SurfaceView so it
    // cannot rely on Flutter compositing the artwork behind a translucent
    // texture — but the call below already covers that. There used to be an
    // extra #ifdef __ANDROID__ copy here, left behind when the call was made
    // unconditional: Android blended the artwork twice, turning opacity a into
    // a·(2−a), so 50% looked like 75% and the background read as fully opaque.
    art_upload_if_dirty();
    art_render((int)W, (int)H);

    glUseProgram(g_scope_prog);
    glBindVertexArray(g_scope_vao);

    const float* sc = rewamp_scope_color();          // user voice color (RGB)
    const float kWave[4]   = { sc[0], sc[1], sc[2], 1.0f };
    static const float kBorder[4] = { 0.55f, 0.85f, 0.55f, 0.35f };

    for (int ch = 0; ch < n; ch++) {
        int col = ch % cols;
        int row = ch / cols;

        float x0 =  -1.0f + col * cellW;
#if REWAMP_GL_Y_FLIPPED
        // macOS only: we render straight into the IOSurface, so NDC +y reaches
        // Flutter as the screen BOTTOM. Without this, voice 0 sat at the bottom
        // of the grid and every waveform was mirrored.
        float y0 =  -1.0f + row * cellH;        // cell's screen-top edge
        float y1 =   y0 + cellH;
        float yAmp = -cellH * 0.45f;            // +sample must go screen-UP
#else
        // Android (window surface) and iOS (glReadPixels already flips on the
        // way out): NDC +y = screen top.
        float y1 =   1.0f - row * cellH;        // cell's screen-top edge
        float y0 =   y1 - cellH;
        float yAmp = cellH * 0.45f;
#endif
        float yMid = (y0 + y1) * 0.5f;

        // --- border (optional grid) — always opaque ---
        if (g_scope_grid) {
            scope_alpha_const(1.0f);
            glUniform4fv(g_scope_colorLoc, 1, kBorder);
            float border[10] = {
                x0,          y0,
                x0 + cellW,  y0,
                x0 + cellW,  y1,
                x0,          y1,
                x0,          y0,
            };
            glBindBuffer(GL_ARRAY_BUFFER, g_scope_vbo);
            glBufferData(GL_ARRAY_BUFFER, sizeof(border), border, GL_DYNAMIC_DRAW) /* orphan: tiler-safe */;
            glDrawArrays(GL_LINE_STRIP, 0, 5);
        }

        // --- waveform ---
        // got==0 (voice has no ring history yet -- nothing written since the
        // last reset, e.g. a libvgm voice that hasn't played its first note)
        // is NOT an error: the loop below already zero-fills every sample
        // past `got` (i < got is false for all i when got==0), correctly
        // drawing a flat silence line. Skipping the draw entirely here used
        // to leave that voice's cell with no trace at all until its first
        // note, instead of the flat line every other silent-but-started
        // voice shows.
        int got = rewamp_channel_buf_triggered(ch, g_scope_buf, SCOPE_SAMPLES);
        if (got < 0) continue;

        for (int i = 0; i < SCOPE_SAMPLES; i++) {
            float t = (float)i / (SCOPE_SAMPLES - 1);
            float s = (i < got) ? (float)g_scope_buf[i] / 128.0f : 0.0f;
            g_scope_verts[i*2]     = x0 + t * cellW;
            g_scope_verts[i*2 + 1] = yMid + s * yAmp;
        }

        scope_draw_wave(kWave, speedLvl, thick, (int)W, (int)H);
    }

    glBindVertexArray(0);
#ifdef __ANDROID__
    rewamp_gl_force_opaque();   // opaque SurfaceView: force alpha=1 before the single swap
#endif
    rewamp_gl_flush();
}

REWAMP_EXPORT void rewamp_scope_uninit(void) {
    if (g_scope_prog)  { glDeleteProgram(g_scope_prog);         g_scope_prog = 0; }
    if (g_scope_vbo)   { glDeleteBuffers(1, &g_scope_vbo);      g_scope_vbo  = 0; }
    if (g_scope_vbo_a) { glDeleteBuffers(1, &g_scope_vbo_a);    g_scope_vbo_a = 0; }
    if (g_scope_vao)   { glDeleteVertexArrays(1, &g_scope_vao); g_scope_vao  = 0; }
}
