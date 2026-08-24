// Scrolling-notation visualizer — C/OpenGL renderer (mode 2).
//
// Included into the same TU as rewamp_viz_render.cpp / rewamp_scope_render.cpp
// (see the Apple podspecs), reusing k_gl_preamble, compile_shader, link_program
// and art_* from there. Reads the look-ahead note timeline (rewamp_notes.c) and
// draws absolutely-positioned note blocks → smooth scroll. Playhead is centered:
// future notes enter from the right, light up as they reach the center (start
// playing), then dim back to normal as they pass to the left.
//   X = time (center = now), Y = pitch (auto-calibrated per track), color = voice.

#include "rewamp_notes.h"
#include "rewamp_gl.h"   // rewamp_gl_ensure / rewamp_gl_generation
#include "rewamp_gl_orientation.h"   // REWAMP_GL_Y_FLIPPED — macOS only, NOT all Apple
#include <time.h>
#include <stdlib.h>   /* qsort */

#define NV_MAXCOLS  1024        /* ≥ window(3s) / step(256) ≈ 517 columns */
#define NV_VOICES   64          /* matches NOTE_VOICES in rewamp_notes.c */
#define NV_HALF     1.5         /* seconds shown on each side of the playhead */
#define NV_SR       44100.0
#define NV_MAXBOXES 8192        /* max note blocks drawn per frame. Sized for a
                                   busy multi-chip VGM: ~500 capture columns ×
                                   dozens of voices can legitimately produce
                                   thousands of runs — the old 2048 cap cut the
                                   collection MID-VOICE, and the cut point moved
                                   with every frame's run merging, so boxes near
                                   the cap blinked (overlapping voices appeared
                                   to swap colors). */
#define NV_VFLOATS  6           /* per vertex: x,y, r,g,b, bright */

static unsigned g_nv_gen = 0;
static GLuint g_nv_prog = 0;
static GLuint g_nv_vao  = 0;
static GLuint g_nv_vbo  = 0;

static float   g_nv_hz[NV_MAXCOLS * NV_VOICES];
static uint8_t g_nv_vol[NV_MAXCOLS * NV_VOICES];
static uint8_t g_nv_instr[NV_MAXCOLS * NV_VOICES];
static int64_t g_nv_pos[NV_MAXCOLS];

/* One note block (merged run). Collected from all voices, then sorted by screen
 * position so overlapping blocks always draw in a stable order (no flicker). */
typedef struct { float x0,y0,x1,y1,bright,r,g,b; } NvBox;
/* Box + vertex buffers are heap-allocated on first use: at 8192 boxes the
 * vertex buffer alone is ~5.9 MB — too fat to keep as always-resident BSS for
 * users who never open this visualizer. */
static NvBox*   g_nv_box   = NULL;   /* NV_MAXBOXES */
/* up to 5 quads (fill + 4 edges) × 6 verts × NV_VFLOATS per box */
static GLfloat* g_nv_verts = NULL;   /* NV_MAXBOXES * 5 * 6 * NV_VFLOATS */

static int nv_ensure_buffers(void) {
    if (!g_nv_box)
        g_nv_box = (NvBox*)malloc((size_t)NV_MAXBOXES * sizeof(NvBox));
    if (!g_nv_verts)
        g_nv_verts = (GLfloat*)malloc(
            (size_t)NV_MAXBOXES * 5 * 6 * NV_VFLOATS * sizeof(GLfloat));
    return g_nv_box != NULL && g_nv_verts != NULL;
}

static int nv_push_quad(GLfloat* v, int nv, float x0, float y0, float x1, float y1,
                        float r, float g, float b, float br) {
    float* q = &v[nv * NV_VFLOATS];
    #define NV_V(X,Y) *q++=(X); *q++=(Y); *q++=r; *q++=g; *q++=b; *q++=br;
    NV_V(x0,y0) NV_V(x1,y0) NV_V(x1,y1)
    NV_V(x0,y0) NV_V(x1,y1) NV_V(x0,y1)
    #undef NV_V
    return nv + 6;
}

// Sort boxes: leftmost first (x0 asc); ties → screen-bottom first. The texture is
// Y-flipped, so screen-bottom = larger NDC y → secondary key y0 descending. Later
// draws land on top, so top/right boxes end up above bottom/left ones.
static int nv_box_cmp(const void* a, const void* b) {
    const NvBox* p = (const NvBox*)a; const NvBox* q = (const NvBox*)b;
    if (p->x0 < q->x0) return -1;
    if (p->x0 > q->x0) return  1;
    if (p->y0 > q->y0) return -1;   /* larger NDC y (screen bottom) first */
    if (p->y0 < q->y0) return  1;
    /* deterministic tie-break (avoids unstable qsort order → flicker) */
    if (p->r != q->r) return p->r < q->r ? -1 : 1;
    if (p->g != q->g) return p->g < q->g ? -1 : 1;
    if (p->b != q->b) return p->b < q->b ? -1 : 1;
    return 0;
}

// ── Coordinated color palettes (0xRRGGBB), one per voice ──────────────────────
// 16 base colors each; voices 16-31 render a LIGHTER variant, 32-47 a DARKER
// one (see nv_voice_color) → 48 distinct voice colors per palette. Adjacent
// entries are hue-spread so neighbouring voices always contrast. MIRRORED in
// Dart (UserSettings.notePaletteColors) for the settings preview — keep both
// in sync.
#define NV_PAL_SIZE  16
#define NV_PAL_COUNT 9
static const unsigned int g_palettes[NV_PAL_COUNT][NV_PAL_SIZE] = {
    /* 0 Cyberpunk — neon signage on a night street: electric cyan/magenta
       backbone, acid green + hot yellow accents */
    { 0x00F0FF,0xFF2BD6,0x39FF14,0xB026FF,0xFFE000,0xFF3860,0x1B6CFF,0xFF8C00,
      0x7DF9FF,0xC724B1,0x00FF9F,0x8A2BE2,0xFFF700,0xFF6EC7,0x00BFFF,0xADFF2F },
    /* 1 Rétro — warm 8-bit console: brick/terracotta/gold earth tones with
       leaf-green and dusty-blue relief */
    { 0xE84855,0xF9A03F,0x6BBF59,0x3A7CA5,0xF9C846,0xC44536,0x2A9D8F,0xD9BF77,
      0xE76F51,0x4E9F3D,0x6D9DC5,0xE9C46A,0xA15C3E,0x8FBC8F,0xB5838D,0xF4A261 },
    /* 2 Pastel — soft sorbet: everything light and low-chroma, no hard edges */
    { 0x8CE99A,0xFF8787,0x74C0FC,0xFFD43B,0xB197FC,0xF783AC,0x63E6BE,0xFFA94D,
      0x99E9F2,0xA9E34B,0xFFC9C9,0xD0BFFF,0xFFE066,0x96F2D7,0xFCC2D7,0xBAC8FF },
    /* 3 Synthwave — sunset-grid: pink→violet→blue sweep, sun-yellow and
       horizon-orange accents */
    { 0xFF6AD5,0x08F7FE,0xF5D300,0xC774E8,0xFF2E97,0x94D0FF,0xFF901F,0xAD8CFF,
      0xFE53BB,0x00B8FF,0xFFD319,0x8795E8,0xFF3864,0x6A00F4,0x2DE2E6,0xF222FF },
    /* 4 Classique — single-phosphor green scope, only lightness varies */
    { 0x00FF44,0x66FFAA,0x00CC55,0x88FFBB,0x22DD66,0x00FF99,0x44FF88,0x11EE55,
      0x77FFCC,0x00DD44,0x55FFAA,0x33FF77,0x00B840,0x99FFC0,0x00E87A,0x2AFF9E },
    /* 5 Vibrant — high-contrast categorical (dataviz-grade separation) */
    { 0xE60049,0x0BB4FF,0x50E991,0xE6D800,0x9B19F5,0xFFA300,0xDC0AB4,0x00BFA0,
      0xFF6E54,0x7C5CFF,0xB3D4FF,0x00C2A8,0xF46A9B,0x8BD346,0xFF8C42,0x5AD2F4 },
    /* 6 Spring — fresh meadow: leaf greens, blossom pinks, clear-sky blues */
    { 0xEA5545,0xF46A9B,0xEF9B20,0xEDBF33,0xBDCF32,0x87BC45,0x27AEEF,0xB33DC6,
      0xEDE15B,0xFF8C42,0x5AD2F4,0x9D4EDD,0x64C466,0xF97B72,0x4CC9F0,0xDA7FD9 },
    /* 7 Arcade — cabinet/Pico-8 primaries: saturated, punchy, CRT-bright */
    { 0xFF004D,0x29ADFF,0xFFEC27,0x00E436,0xFF77A8,0x00FFCC,0xFFA300,0x7E2FF2,
      0xFF3C00,0x00B8F5,0xB5FF39,0xFF5DB1,0x00D66C,0xFFC825,0x4D7CFF,0xF25EFF },
    /* 8 Candy — sweet shop: bubblegum, mint, lemon drop, grape, caramel */
    { 0xFF87B7,0x8FE3CF,0xFFD97A,0xC79BFF,0xFFA37A,0x7AD1FF,0xFF6F91,0xA5E887,
      0xFFB3DE,0x6FDCB8,0xFFCE85,0xB19CFF,0xFF8A80,0x8CD9FF,0xE887C7,0xFFE9A8 },
};
static volatile int g_palette = 0;
static volatile int g_style   = 0;   /* 0 = flat, 1 = box (beveled relief) */

REWAMP_EXPORT void rewamp_set_note_palette(int i) {
    if (i < 0) i = 0;
    if (i >= NV_PAL_COUNT) i = NV_PAL_COUNT - 1;
    g_palette = i;
}

REWAMP_EXPORT void rewamp_set_note_style(int s) { g_style = s ? 1 : 0; }

static void nv_voice_color(int v, float* r, float* g, float* b) {
    unsigned int hex = g_palettes[g_palette][v % NV_PAL_SIZE];
    float rr = ((hex >> 16) & 0xFF) / 255.0f;
    float gg = ((hex >> 8)  & 0xFF) / 255.0f;
    float bb = ( hex        & 0xFF) / 255.0f;
    // Past the 16 base colors, cycle lighter then darker variants → 48
    // distinct voice colors before any true repeat.
    switch ((v / NV_PAL_SIZE) % 3) {
        case 1: /* lighter: blend 40% toward white */
            rr += (1.0f - rr) * 0.40f;
            gg += (1.0f - gg) * 0.40f;
            bb += (1.0f - bb) * 0.40f;
            break;
        case 2: /* darker */
            rr *= 0.55f; gg *= 0.55f; bb *= 0.55f;
            break;
        default: break;
    }
    *r = rr; *g = gg; *b = bb;
}

/* ── Vertical range: auto-calibrated (default) or manual (drag/pinch) ──────
 * The calibrated range persists across frames; the manual override (set from
 * Dart gestures) freezes it — while manual is on, the calibrated state tracks
 * the manual range so switching back to auto eases from the same view. */
static float g_nv_cal_lo = 4.5f, g_nv_cal_hi = 12.5f;   /* log2(Hz) */
static volatile int   g_nv_manual = 0;
static volatile float g_nv_man_lo = 4.5f, g_nv_man_hi = 12.5f;

#define NV_ABS_LO  0.0f    /* 1 Hz */
#define NV_ABS_HI 15.0f    /* 32 kHz */
#define NV_SPAN_MIN_MANUAL 0.5f
#define NV_SPAN_MAX 15.0f

REWAMP_EXPORT void rewamp_noteviz_set_range(float lo, float hi) {
    float span = hi - lo;
    if (span < NV_SPAN_MIN_MANUAL) span = NV_SPAN_MIN_MANUAL;
    if (span > NV_SPAN_MAX)        span = NV_SPAN_MAX;
    float m = (lo + hi) * 0.5f;
    lo = m - span * 0.5f; hi = m + span * 0.5f;
    if (lo < NV_ABS_LO) { hi += NV_ABS_LO - lo; lo = NV_ABS_LO; }
    if (hi > NV_ABS_HI) { lo -= hi - NV_ABS_HI; hi = NV_ABS_HI; }
    g_nv_man_lo = lo; g_nv_man_hi = hi;
    g_nv_manual = 1;
}

REWAMP_EXPORT void rewamp_noteviz_set_auto(void) { g_nv_manual = 0; }
REWAMP_EXPORT int  rewamp_noteviz_is_manual(void) { return g_nv_manual; }
REWAMP_EXPORT float rewamp_noteviz_range_lo(void) {
    return g_nv_manual ? g_nv_man_lo : g_nv_cal_lo;
}
REWAMP_EXPORT float rewamp_noteviz_range_hi(void) {
    return g_nv_manual ? g_nv_man_hi : g_nv_cal_hi;
}

static double nv_now(void) {
    /* Prefer the Flutter frame timestamp (vsync-aligned, set by Dart before
     * each tick's render) — wall clock at render time carries FFI scheduling
     * jitter that trembles the scroll. Fallback: wall clock. */
    double ext = rewamp_viz_frame_time();
    if (ext >= 0.0) return ext;
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

REWAMP_EXPORT int rewamp_noteviz_init(int width, int height) {
    // Ensures a USABLE context (rebuilding it if the OS destroyed ours) and tells
    // us, via the generation, whether our cached GL objects survived.
    {
        int err = rewamp_gl_ensure(width, height);
        if (err != 0) return err;
    }

    // Reuse only if built on THIS context: a non-zero id is not enough —
    // after a context rebuild it is a stale handle pointing at nothing.
    if (g_nv_prog && g_nv_gen == rewamp_gl_generation()) return 0;
    g_nv_prog = 0;   // stale (or first time): rebuild below

    static const char* k_vert =
        "in vec2 aPos;\n"
        "in vec3 aCol;\n"
        "in float aBright;\n"
        "out vec3 vC;\n"
        "out float vB;\n"
        "void main() { gl_Position = vec4(aPos, 0.0, 1.0); vC = aCol; vB = aBright; }\n";
    static const char* k_frag =
        "in vec3 vC;\n"
        "in float vB;\n"
        "out vec4 fragColor;\n"
        "void main() {\n"
        "  vec3 col;\n"
        "  if (vB > 1.0) col = mix(vC, vec3(1.0), clamp(vB - 1.0, 0.0, 1.0));\n"
        "  else          col = vC * vB;\n"
        "  fragColor = vec4(col, 1.0);\n"   // opaque → no blend-order flicker
        "}\n";
    GLuint vert = compile_shader(GL_VERTEX_SHADER,   k_gl_preamble, k_vert);
    GLuint frag = compile_shader(GL_FRAGMENT_SHADER, k_gl_preamble, k_frag);
    if (!vert || !frag) return -10;
    g_nv_prog = link_program(vert, frag);
    glDeleteShader(vert); glDeleteShader(frag);
    if (!g_nv_prog) return -11;

    glGenVertexArrays(1, &g_nv_vao);
    glBindVertexArray(g_nv_vao);
    glGenBuffers(1, &g_nv_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, g_nv_vbo);
    glBufferData(GL_ARRAY_BUFFER,
                 (GLsizeiptr)NV_MAXBOXES * 5 * 6 * NV_VFLOATS * sizeof(GLfloat),
                 NULL, GL_DYNAMIC_DRAW);
    const GLsizei stride = NV_VFLOATS * sizeof(GLfloat);
    GLint aPos = glGetAttribLocation(g_nv_prog, "aPos");
    GLint aCol = glGetAttribLocation(g_nv_prog, "aCol");
    GLint aBri = glGetAttribLocation(g_nv_prog, "aBright");
    glEnableVertexAttribArray(aPos);
    glVertexAttribPointer(aPos, 2, GL_FLOAT, GL_FALSE, stride, (void*)0);
    glEnableVertexAttribArray(aCol);
    glVertexAttribPointer(aCol, 3, GL_FLOAT, GL_FALSE, stride, (void*)(2*sizeof(GLfloat)));
    glEnableVertexAttribArray(aBri);
    glVertexAttribPointer(aBri, 1, GL_FLOAT, GL_FALSE, stride, (void*)(5*sizeof(GLfloat)));
    glBindVertexArray(0);

    g_nv_gen = rewamp_gl_generation();   // these objects belong to THIS context
    return 0;
}

REWAMP_EXPORT void rewamp_noteviz_render(void) {
    rewamp_gl_make_current();
    if (!nv_ensure_buffers()) return;

    const int vc = rewamp_notes_voice_count();

    // Smooth display playhead — the shared clock (rewamp_notes_played_smooth):
    // rate-locked, monotonic while playing, converging both ways when paused. It
    // used to live here; the pattern viz was reading the RAW interpolated value
    // instead, so the two visualizers judder differently and did not even agree
    // on the instant they showed. One implementation for both.
    const double played = rewamp_notes_played_smooth();
    const int64_t playedI = (int64_t)played;
    const int64_t halfS  = (int64_t)(NV_HALF * NV_SR);
    // Collect a margin BEYOND the visible left edge so a note run that's only
    // partially on screen keeps its TRUE onset column (not clamped to the window
    // start). Otherwise, as the window scrolls right, a straddling run's start
    // jumps forward each frame → its sort x0 jumps → draw order swaps with a
    // neighbour → flicker. With the margin, x0 stays stable while any part is
    // visible; vertices past x=-1 are clipped by the GL rasterizer. (~1024 col cap
    // covers 4.5 s at the capture step.)
    const int64_t leftMargin = halfS;   /* 1.5 s of extra off-screen history */
    // QUANTIZE the window start to an absolute grid (~0.74 s). A run straddling
    // the window start takes its semitone BIN (and its split decisions) from
    // whichever column happens to be first in the window — with a per-frame
    // sliding start, a pitch sitting near a bin boundary (vibrato, detuned
    // near-unison layers) re-binned ±1 semitone every frame, visibly
    // re-pitching/re-splitting the run's ON-SCREEN portion (empirically: whole
    // box bands flashing on a busy VGM even while paused). A quantized start
    // keeps the entry column fixed between rare jumps.
    const int64_t kWinQuantum = 512 * 64;
    int64_t wstart = playedI - halfS - leftMargin;
    wstart -= ((wstart % kWinQuantum) + kWinQuantum) % kWinQuantum;
    int n = (vc > 0)
        ? rewamp_notes_collect(wstart, playedI + halfS,
                               g_nv_hz, g_nv_vol, g_nv_instr, g_nv_pos, NV_MAXCOLS)
        : 0;

    glBindFramebuffer(GL_FRAMEBUFFER, rewamp_gl_get_fbo());
    glViewport(0, 0, rewamp_gl_width(), rewamp_gl_height());
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    // ONCE, on every platform — the extra #ifdef __ANDROID__ copy that used to
    // sit here blended the artwork twice on Android (opacity a became a·(2−a),
    // so 50% looked like 75%). See rewamp_scope_render.cpp.
    art_upload_if_dirty();
    art_render(rewamp_gl_width(), rewamp_gl_height());

    if (n <= 0 || vc <= 0) {
#ifdef __ANDROID__
        rewamp_gl_force_opaque();
#endif
        rewamp_gl_flush(); return;
    }

    // Soft vertical calibration targeting ~75% of the height used by the
    // content: the range is the content span / TARGET_USE, centred on the
    // content. Re-range only when a note falls OUTSIDE the range or the usage
    // drifts out of the [60%..90%] deadband — the deadband plus the gentle
    // ease keep the graph from re-zooming on every vibrato wiggle or short
    // rest. A small minimum span still bounds the zoom (a lone held note must
    // not blow ±semitone vibrato across the whole screen).
    #define NV_MIN_SPAN   1.0f    /* min vertical span in octaves (log2) */
    #define NV_TARGET_USE 0.75f   /* fraction of the height content should use */
    float omin = 1e9f, omax = -1e9f;
    for (int c = 0; c < n; c++)
        for (int v = 0; v < vc; v++) {
            float val = g_nv_hz[c * vc + v];
            if (val < 1.0f) continue;
            float l = log2f(val);
            if (l < omin) omin = l;
            if (l > omax) omax = l;
        }
    if (g_nv_manual) {
        /* Manual range (drag/pinch from Dart) — keep the calibrated state in
         * sync so re-enabling auto eases from the current view. */
        g_nv_cal_lo = g_nv_man_lo;
        g_nv_cal_hi = g_nv_man_hi;
    } else if (omax >= omin) {
        float range   = g_nv_cal_hi - g_nv_cal_lo;
        float use     = (omax - omin) / (range > 0.1f ? range : 0.1f);
        int   outside = (omin < g_nv_cal_lo) || (omax > g_nv_cal_hi);
        if (outside || use < 0.60f || use > 0.90f) {
            float span = (omax - omin) / NV_TARGET_USE;
            if (span < NV_MIN_SPAN) span = NV_MIN_SPAN;
            float m   = (omin + omax) * 0.5f;
            float tlo = m - span * 0.5f;
            float thi = m + span * 0.5f;
            g_nv_cal_lo += (tlo - g_nv_cal_lo) * 0.04f;    /* gentle ease */
            g_nv_cal_hi += (thi - g_nv_cal_hi) * 0.04f;
        }
    }
    const float lo = g_nv_cal_lo, hi = g_nv_cal_hi,
                span = (hi - lo) > 0.1f ? (hi - lo) : 0.1f;

    const double halfSamples = NV_HALF * NV_SR;
    const float  blockH = 0.05f;   /* NDC block height */
    /* Vibrato tremble gain: NDC offset per semitone of instantaneous deviation.
     * The TRUE deviation over a ≥7-octave span is sub-pixel (0.5 semitone ≈
     * 0.5% of the height) — exaggerate so ±0.75 semitone ≈ 60% of the block's
     * half-height. Applied only to the ACTIVE block (see below). */
    const float  vibGain = 0.03f;
    const float  Wf = (float)rewamp_gl_width();
    const float  Hf = (float)rewamp_gl_height();
    const float  exB = (Wf > 0 ? 4.0f / Wf : 0.005f);   /* ~2px edge */
    const float  eyB = (Hf > 0 ? 4.0f / Hf : 0.005f);

    const double stepEst = 512.0; /* capture step (DS_STEP_FRAMES); last-col width */

    // 1) Collect one merged box per note run, across all voices.
    int nbox = 0;
    for (int v = 0; v < vc && nbox < NV_MAXBOXES; v++) {
        float vr, vg, vb; nv_voice_color(v, &vr, &vg, &vb);
        for (int c = 0; c < n && nbox < NV_MAXBOXES; ) {
            float val = g_nv_hz[c * vc + v];
            if (val < 1.0f) { c++; continue; }
            // Vibrato tolerance: chips that expose the raw pitch register (e.g.
            // OPN LFO PM) wobble continuously around the note. Group by the
            // SEMITONE BIN of the run start with ±0.75-semitone hysteresis —
            // vibrato/detune stays merged, a real note step (≥1 semitone from
            // the bin centre) still splits. A raw 1% (±17 cent) compare made a
            // held vibrato note shatter into dozens of micro-boxes (the active
            // highlight blinked as the playhead crossed them).
            float sem0 = roundf(12.0f * log2f(val / 440.0f));
            int cs = c, ce = c;
            while (ce + 1 < n) {
                int   nidx = (ce + 1) * vc + v, cidx = ce * vc + v;
                float nhz  = g_nv_hz[nidx];
                if (nhz < 1.0f) break;                                    // note off
                if (fabsf(12.0f * log2f(nhz / 440.0f) - sem0) > 0.75f) break; // pitch change
                if (g_nv_instr[nidx] != g_nv_instr[cidx]) break;          // instrument change
                if (g_nv_vol[nidx] > g_nv_vol[cidx] + 2) break;           // re-attack (vol up)
                if ((double)(g_nv_pos[ce + 1] - g_nv_pos[ce]) > stepEst * 3.0) break;
                ce++;
            }
            // Box end snaps to the NEXT capture column's position (the capture
            // grid) so adjacent boxes share an exact boundary → stable, no
            // junction flicker. Last column falls back to +one step.
            double runStart = (double)g_nv_pos[cs];
            double runEnd   = (ce + 1 < n)
                ? (double)g_nv_pos[ce + 1]
                : (double)g_nv_pos[ce] + stepEst;
            // Draw at the semitone-bin centre, not the raw run-start pitch —
            // otherwise the block's height depends on the vibrato phase at
            // the instant the run began.
            float  binHz = 440.0f * exp2f(sem0 / 12.0f);
            float  t = (log2f(binHz) - lo) / span;
            if (t < 0) t = 0; if (t > 1) t = 1;
#if REWAMP_GL_Y_FLIPPED
            float yc = 1.0f - 2.0f * t;          /* macOS: texture reaches Flutter flipped */
#else
            float yc = 2.0f * t - 1.0f;          /* +y = screen top (Android, iOS)         */
#endif
            const int active = (played >= runStart && played <= runEnd);
            // Vibrato tremble: the ACTIVE block follows the instantaneous
            // pitch's deviation from its semitone bin. The playhead advances
            // every frame, so sampling the deviation at `played` animates the
            // block along the actual vibrato waveform. Inactive blocks stay at
            // the bin centre (nothing is sounding — nothing to vibrate).
            if (active) {
                int ci = cs;                     /* column under the playhead */
                while (ci < ce && (double)g_nv_pos[ci + 1] <= played) ci++;
                float ihz = g_nv_hz[ci * vc + v];
                if (ihz >= 1.0f) {
                    // Deviation vs the run's MEAN pitch, not the bin centre: a
                    // one-sided vibrato (classic downward dip) has a DC bias vs
                    // the bin, which shifted the whole active block off-centre —
                    // combined with the active height bump it read as growing in
                    // one direction. The mean removes the DC → pure tremble
                    // around the block's own centre.
                    float sum = 0.0f; int cnt = 0;
                    for (int k = cs; k <= ce; k++) {
                        float khz = g_nv_hz[k * vc + v];
                        if (khz >= 1.0f) { sum += log2f(khz); cnt++; }
                    }
                    float meanL2 = cnt > 0 ? sum / (float)cnt : log2f(binHz);
                    float dev = 12.0f * (log2f(ihz) - meanL2);
                    if (dev >  1.5f) dev =  1.5f;    /* runaway glide guard */
                    if (dev < -1.5f) dev = -1.5f;
#if REWAMP_GL_Y_FLIPPED
                    yc -= dev * vibGain;             /* flipped: +pitch = -y */
#else
                    yc += dev * vibGain;
#endif
                }
            }
            NvBox* bx = &g_nv_box[nbox++];
            bx->x0 = (float)((runStart - played) / halfSamples);
            bx->x1 = (float)((runEnd   - played) / halfSamples);
            // Active block: slightly TALLER (height only — width would distort
            // the note's duration) and pushed toward white (bright > 1 mixes
            // the voice color with white in the shader, hue preserved).
            // Inactive blocks show the palette color at full strength.
            float h = blockH * (active ? 1.35f : 1.0f);
            bx->y0 = yc - h * 0.5f;
            bx->y1 = yc + h * 0.5f;
            bx->bright = active ? 1.6f : 0.7f;
            bx->r = vr; bx->g = vg; bx->b = vb;
            c = ce + 1;
        }
    }

    // 2) Sort by screen position (left→right, then bottom→top) for a stable
    //    overlap order — kills the flicker between close/overlapping boxes.
    qsort(g_nv_box, nbox, sizeof(NvBox), nv_box_cmp);

    // 3) Emit all boxes (fill + optional bevel edges) into one buffer, in order.
    int nverts = 0;
    for (int i = 0; i < nbox; i++) {
        NvBox* bx = &g_nv_box[i];
        float x0=bx->x0, x1=bx->x1, y0=bx->y0, y1=bx->y1, br=bx->bright;
        float r=bx->r, g=bx->g, b=bx->b;
        nverts = nv_push_quad(g_nv_verts, nverts, x0, y0, x1, y1, r, g, b, br); // fill
        if (g_style) {
            // Uniform-thickness edges INSIDE the box (box size unchanged): the
            // screen-TOP edge is lit, the screen-BOTTOM one shaded, left dark
            // and right light. Emitted last so corners take the horizontal
            // bands' colour.
            //
            // WHICH NDC edge is the screen top is per-platform, exactly like the
            // yc computation above: on macOS the texture reaches Flutter
            // flipped, so the LOW NDC y is the screen top; on Android and iOS
            // +y is up, so it is the HIGH one. This used to be hardcoded to the
            // macOS case, which turned the relief upside down everywhere else —
            // lit band at the bottom, shaded at the top.
            //
            // Clamp thickness to half the box so thin/short blocks don't overflow.
            float ex = fminf(exB, (x1 - x0) * 0.5f);
            float ey = fminf(eyB, (y1 - y0) * 0.5f);
            /* +0.45 (not +1.0): with inactive bright now 1.0, +1.0 made every
             * light edge pure white; +0.45 keeps ~45% white like before. */
            float lb = br + 0.45f, db = br * 0.35f;
#if REWAMP_GL_Y_FLIPPED
            const float bLowY = lb, bHighY = db;   /* low NDC y = screen top */
#else
            const float bLowY = db, bHighY = lb;   /* low NDC y = screen bottom */
#endif
            nverts = nv_push_quad(g_nv_verts, nverts, x0, y0, x0 + ex, y1, r, g, b, db); // left
            nverts = nv_push_quad(g_nv_verts, nverts, x1 - ex, y0, x1, y1, r, g, b, lb); // right
            nverts = nv_push_quad(g_nv_verts, nverts, x0, y0, x1, y0 + ey, r, g, b, bLowY);
            nverts = nv_push_quad(g_nv_verts, nverts, x0, y1 - ey, x1, y1, r, g, b, bHighY);
        }
    }

    if (nverts > 0) {
        glUseProgram(g_nv_prog);
        glBindVertexArray(g_nv_vao);
        glBindBuffer(GL_ARRAY_BUFFER, g_nv_vbo);
        glBufferData(GL_ARRAY_BUFFER, nverts * NV_VFLOATS * sizeof(GLfloat), g_nv_verts, GL_DYNAMIC_DRAW) /* orphan: tiler-safe */;
        glDrawArrays(GL_TRIANGLES, 0, nverts);
        glBindVertexArray(0);
    }
#ifdef __ANDROID__
    rewamp_gl_force_opaque();
#endif
    rewamp_gl_flush();
}

REWAMP_EXPORT void rewamp_noteviz_uninit(void) {
    if (g_nv_prog) { glDeleteProgram(g_nv_prog);        g_nv_prog = 0; }
    if (g_nv_vbo)  { glDeleteBuffers(1, &g_nv_vbo);     g_nv_vbo  = 0; }
    if (g_nv_vao)  { glDeleteVertexArrays(1, &g_nv_vao);g_nv_vao  = 0; }
    free(g_nv_box);   g_nv_box   = NULL;
    free(g_nv_verts); g_nv_verts = NULL;
}
