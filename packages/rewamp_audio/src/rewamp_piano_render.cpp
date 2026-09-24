// Piano visualizer — C/OpenGL renderer (viz mode 6), two looks:
//   0 « clavier par voix »  : one keyboard per voice (row), the notes that
//                              sound NOW light their keys (Modizer's
//                              DrawPianoRollFX);
//   1 « chute »             : one keyboard at the bottom, the coming notes fall
//                              onto it as bars, the keys light up when hit
//                              (Modizer's DrawPianoRollSynthesiaFX).
//
// Included into the same TU as rewamp_viz_render.cpp / rewamp_notes_render.cpp
// (see the Apple podspecs, src/android/rewamp_viz_android.cpp and
// src/linux/rewamp_viz_linux.cc): it reuses k_gl_preamble, compile_shader,
// link_program, art_* from the first and nv_voice_color / nv_now from the
// second — so the keys and bars follow the notation's voice palette, and
// nothing here is a second copy of it. All file-scope symbols are pk_-prefixed.
//
// Data: the look-ahead note timeline (rewamp_notes.c), exactly like the
// notation — the column under the playhead says what sounds NOW, the columns
// after it are the falling bars. Nothing is polled from the chips directly.
//
// ── Geometry lives in KEY UNITS, the view is a uniform ──────────────────────
// Every vertex carries (xk, yb, ty): xk = horizontal position in WHITE-KEY
// units over the whole MIDI range (C-1 is white key 0, G9 is 74), yb = a pixel
// baseline (the bottom of the keys, or a bar's y), ty = a multiple of the key
// height added to it. The vertex shader applies the VIEW — key width, key
// height and horizontal offset — so:
//   - the whole 128-note keyboard (every row) is tessellated ONCE into a
//     static VBO, and never again for a zoom, a pan or an auto-range change;
//   - per frame only the keys that MOVE are re-emitted (pressed, releasing, or
//     a white whose black neighbour moves — its shadow depends on it), drawn
//     between the static whites and the static blacks so a pressed white never
//     covers a black; Modizer re-emitted every key of every row each frame;
//   - the view itself (lo, span) is CONTINUOUS and eased with a cubic
//     ease-in-out when the auto range moves, so the keyboard glides and grows
//     instead of jumping; manual pan/pinch from Dart sets it directly.
// The spark texture became particles (GL_POINTS, radial falloff in the
// fragment shader) plus a small contact flash — no asset, one draw call.
// The key-press animation is time-based (Modizer stepped per frame).
//
// Pixel y is DOWN (top-left origin); the NDC conversion in the shader honours
// REWAMP_GL_Y_FLIPPED (see rewamp_gl_orientation.h). A Modizer `y + k` (its y
// is UP, from the key bottom) becomes ty = -k/keyH here.

#include "rewamp_notes.h"
#include "ModizerVoicesData.h"   // generic_mute_mask: une voix coupée ne joue pas de touche
#include "rewamp_gl.h"
#include "rewamp_gl_orientation.h"
#include <math.h>
#include <string.h>
#include <stdlib.h>

#define PK_MAXCOLS   1024      /* ≥ (margin + future) / capture step */
#define PK_VOICES    64        /* NOTE_VOICES in rewamp_notes.c */
#define PK_NOTES     128       /* MIDI range */
#define PK_WHITES    75        /* white keys in 0..127 */
#define PK_MAXROWS   16        /* keyboards per screen, roll mode */
#define PK_FUTURE_S  1.5       /* seconds of falling bars above the keyboard */
#define PK_MAXBARS   2048
#define PK_VFLOATS   7         /* xk, yb, ty, r,g,b,a */
#define PK_PFLOATS   8         /* xk, yb, ty, size, r,g,b,a (points) */
#define PK_VERTS_KEYW 60       /* DrawKeyW worst case: 54 + 6 shadow */
#define PK_VERTS_KEYB 36
#define PK_VERTS_BOX  30
#define PK_MAXPARTICLES 1024
#define PK_FFLOATS   9         /* xk, yb, ty, u, v, r,g,b,a (flames) */
/* Black key width (white = 1) and the dark gap between two whites: the white
 * FACE is then ~0.92 wide, twice the black key's lit face. Mirrored in the
 * lighting shader (BW). */
#define PK_BW  0.56f
#define PK_GAP 0.04f
#define PK_SPAN_MIN   7.0f     /* one octave */
#define PK_SPAN_MAX   ((float)PK_WHITES)
#define PK_EASE_GROW_S    0.3  /* auto range grows: a note is off the keyboard, catch up */
#define PK_EASE_SHRINK_S  1.2  /* auto range zooms in: unhurried */
#define PK_SHRINK_WINDOW  8.0  /* zoom in only to what the last N s needed... */
#define PK_SHRINK_MIN     3    /* ...only for a gain of at least N white keys */

/* ── options (set from Dart, read on the render thread) ─────────────────── */
static volatile int g_pk_mode  = 0;   /* 0 = keyboards (per voice, shared when zoomed), 1 = falling bars */
static volatile int g_pk_color = 0;   /* 0 = by voice (notation palette), 1 = by instrument */
static volatile int g_pk_glow  = 1;   /* falling mode: sparkles on the struck keys */
static volatile int g_pk_light = 1;   /* a light in front of each struck key, casting shadows */

REWAMP_EXPORT void rewamp_set_piano_options(int mode, int colorMode, int glow, int light) {
    g_pk_mode  = mode ? 1 : 0;
    g_pk_color = colorMode ? 1 : 0;
    g_pk_glow  = glow ? 1 : 0;
    g_pk_light = light ? 1 : 0;
}

/* ── view: [lo, lo+span] in white-key units; auto (eased) or manual ─────── */
static float  g_pk_lo = 14.0f, g_pk_span = 28.0f;      /* current (C2..C6) */
static float  g_pk_tlo = 14.0f, g_pk_tspan = 28.0f;    /* auto target */
static float  g_pk_flo = 14.0f, g_pk_fspan = 28.0f;    /* ease start */
static double g_pk_ease_t0 = -1.0;                     /* < 0 = at rest */
static double g_pk_ease_dur = PK_EASE_GROW_S;          /* current glide duration */
static volatile int   g_pk_manual = 0;
static volatile float g_pk_mlo = 14.0f, g_pk_mspan = 28.0f;

/* Zoom floor imposed by the surface: a key keeps its 1:4 aspect, so the
 * widest key that still fits the keyboard's height bounds the smallest span.
 * Computed each frame from the layout (see pk_compute_layout); before the
 * first frame, the static floor alone. */
static volatile float g_pk_span_floor = PK_SPAN_MIN;

static void pk_clamp_view(float* lo, float* span) {
    const float smin = g_pk_span_floor > PK_SPAN_MIN ? g_pk_span_floor : PK_SPAN_MIN;
    if (*span < smin) *span = smin;
    if (*span > PK_SPAN_MAX) *span = PK_SPAN_MAX;
    if (*lo < 0.0f) *lo = 0.0f;
    if (*lo + *span > PK_SPAN_MAX) *lo = PK_SPAN_MAX - *span;
}

REWAMP_EXPORT void rewamp_pianoviz_set_view(float lo, float span) {
    pk_clamp_view(&lo, &span);
    g_pk_mlo = lo; g_pk_mspan = span;
    g_pk_manual = 1;
}
REWAMP_EXPORT void  rewamp_pianoviz_set_auto(void)   { g_pk_manual = 0; }

/* Horizon RÉELLEMENT visible au-dessus du clavier: c'est la fenêtre que doit
 * couvrir une légende « par instrument » (les barres montrent du futur), et
 * elle dépend du mode — le mode claviers n'affiche que l'instant. */
REWAMP_EXPORT double rewamp_pianoviz_future_seconds(void) {
    return g_pk_mode == 1 ? PK_FUTURE_S : 0.0;
}
REWAMP_EXPORT int   rewamp_pianoviz_is_manual(void)  { return g_pk_manual; }
REWAMP_EXPORT float rewamp_pianoviz_view_lo(void)    { return g_pk_manual ? g_pk_mlo : g_pk_lo; }
REWAMP_EXPORT float rewamp_pianoviz_view_span(void)  { return g_pk_manual ? g_pk_mspan : g_pk_span; }

/* ── GL objects ──────────────────────────────────────────────────────────── */
static unsigned g_pk_gen  = 0;
static GLuint   g_pk_prog = 0;
static GLint    g_pk_uView = -1, g_pk_uKey = -1;
static GLuint   g_pk_svao = 0, g_pk_svbo = 0;   /* static keyboard(s) */
static GLuint   g_pk_dvao = 0, g_pk_dvbo = 0;   /* per-frame layer */
static GLuint   g_pk_pprog = 0;                 /* points: particles + flash */
static GLint    g_pk_puView = -1, g_pk_puKey = -1;
static GLuint   g_pk_pvao = 0, g_pk_pvbo = 0;
static float    g_pk_point_max = 64.0f;
static GLuint   g_pk_fprog = 0;                 /* flames at the struck keys */
static GLint    g_pk_fuView = -1, g_pk_fuKey = -1, g_pk_fuTime = -1, g_pk_fuSpike = -1;
static GLuint   g_pk_fvao = 0, g_pk_fvbo = 0;
static GLfloat* g_pk_fverts = NULL;
#define PK_FVERTS_MAX (PK_MAXROWS * PK_NOTES * 6)
static GLuint   g_pk_lprog = 0;                 /* lighting pass (one quad per keyboard) */
static GLint    g_pk_luView = -1, g_pk_luKey = -1, g_pk_luBase = -1, g_pk_luN = -1;
static GLint    g_pk_luPos = -1, g_pk_luCol = -1, g_pk_luPress = -1, g_pk_luPass = -1;
static GLuint   g_pk_lvao = 0, g_pk_lvbo = 0;
#define PK_MAXLIGHTS 32

/* ── timeline scratch ────────────────────────────────────────────────────── */
static float   g_pk_hz[PK_MAXCOLS * PK_VOICES];
static uint8_t g_pk_vol[PK_MAXCOLS * PK_VOICES];
static uint8_t g_pk_instr[PK_MAXCOLS * PK_VOICES];
static int64_t g_pk_pos[PK_MAXCOLS];

/* ── key table (mode-independent) ────────────────────────────────────────── */
static float   g_pk_kx[PK_NOTES];      /* x in white-key units */
static float   g_pk_kw[PK_NOTES];      /* width in white-key units (1 or 0.5) */
static uint8_t g_pk_black[PK_NOTES];
static int     g_pk_widx[PK_NOTES];    /* white index of the white key at/below the note */
static int     g_pk_tables_ready = 0;

static void pk_build_tables(void) {
    int wk = 0; float lastWhite = 0.0f;
    for (int n = 0; n < PK_NOTES; n++) {
        int pc = n % 12;
        int black = (pc == 1 || pc == 3 || pc == 6 || pc == 8 || pc == 10);
        g_pk_black[n] = (uint8_t)black;
        if (!black) {
            lastWhite = (float)wk; g_pk_kx[n] = lastWhite; g_pk_kw[n] = 1.0f;
            g_pk_widx[n] = wk; wk++;
        } else {
            /* Modizer's offsets, fractions of the white key to the left. */
            float f;
            switch (pc) {
                case 1:  f = 8.0f / 12; break;   /* C# */
                case 3:  f = 10.0f / 12; break;  /* D# */
                case 6:  f = 8.0f / 12; break;   /* F# */
                case 8:  f = 9.0f / 12; break;   /* G# */
                default: f = 10.0f / 12; break;  /* A# */
            }
            g_pk_kx[n] = lastWhite + f - (PK_BW - 0.5f) * 0.5f; g_pk_kw[n] = PK_BW;
            g_pk_widx[n] = wk - 1;
        }
    }
    g_pk_tables_ready = 1;
}

/* ── layout (what the static VBO was built for) ─────────────────────────── */
typedef struct {
    int   H, mode, rows;
    int   light;            /* lighting pass on: no baked neighbour shadows */
    float rowH;             /* roll: row pitch px */
    float keyWpx;           /* current white key width px (view) */
    float keyH;             /* px, ≤ keyWpx*4, clamped by the row / the surface */
    float feltH;            /* px */
} PkLayout;
static PkLayout g_pk_lay;
static int      g_pk_static_dirty = 1;
static int      g_pk_static_whites = 0;
static int      g_pk_static_blacks = 0;

/* ── animation state ─────────────────────────────────────────────────────── */
static float   g_pk_keypos[PK_MAXROWS][PK_NOTES];   /* 0 = up, 1 = fully down */
static uint8_t g_pk_pressed[PK_MAXROWS][PK_NOTES];  /* this frame */
static float   g_pk_keyr[PK_MAXROWS][PK_NOTES], g_pk_keyg[PK_MAXROWS][PK_NOTES], g_pk_keyb[PK_MAXROWS][PK_NOTES];
static float   g_pk_spark[PK_MAXROWS][PK_NOTES];    /* 0..1 aura envelope, per keyboard */
/* Manual view: a note sounding OFF-SCREEN flashes a small arrow on that side
 * of its keyboard (time of the last trigger; [r][0] = left, [r][1] = right),
 * in the note's colour. */
static double  g_pk_arrow_t[PK_MAXROWS][2];
static float   g_pk_arrow_c[PK_MAXROWS][2][3];
#define PK_ARROW_S 0.3
static float   g_pk_emit[PK_MAXROWS][PK_NOTES];     /* particle emission accumulator */
static double  g_pk_last_t = -1.0;

typedef struct { float xk, y, vxk, vy, life, lifeMax, r, g, b, size; } PkParticle;
static PkParticle g_pk_part[PK_MAXPARTICLES];
static int        g_pk_npart = 0;
static unsigned   g_pk_rng = 0x9E3779B9u;
static inline float pk_rand(void) {   /* xorshift, 0..1 */
    g_pk_rng ^= g_pk_rng << 13; g_pk_rng ^= g_pk_rng >> 17; g_pk_rng ^= g_pk_rng << 5;
    return (float)(g_pk_rng & 0xFFFFFF) / 16777216.0f;
}

/* ── auto range: a tight frame around the content, sticky ───────────────── */
static int    g_pk_range_lo = 21, g_pk_range_hi = 49;   /* white keys, C2..C6 */
/* When each frame edge was last NEEDED (white-key units): the union over the
 * last PK_SHRINK_WINDOW seconds is the most a zoom-in may take away. */
static double g_pk_lo_seen[PK_WHITES + 1], g_pk_hi_seen[PK_WHITES + 1];
static double g_pk_range_changed = 0.0;                 /* last grow or shrink */
static int    g_pk_seen_ready = 0;

/* ── buffers (heap: only users of this viz pay for them) ────────────────── */
static GLfloat* g_pk_sverts = NULL;
static GLfloat* g_pk_dverts = NULL;
static GLfloat* g_pk_pverts = NULL;
#define PK_SVERTS_MAX (PK_MAXROWS * PK_NOTES * PK_VERTS_KEYW)
#define PK_DVERTS_MAX (PK_MAXBARS * PK_VERTS_BOX + PK_MAXROWS * PK_NOTES * PK_VERTS_KEYW + PK_MAXROWS * 6)
#define PK_PVERTS_MAX (PK_MAXPARTICLES + PK_NOTES)

static int pk_ensure_buffers(void) {
    if (!g_pk_sverts) g_pk_sverts = (GLfloat*)malloc((size_t)PK_SVERTS_MAX * PK_VFLOATS * sizeof(GLfloat));
    if (!g_pk_dverts) g_pk_dverts = (GLfloat*)malloc((size_t)PK_DVERTS_MAX * PK_VFLOATS * sizeof(GLfloat));
    if (!g_pk_pverts) g_pk_pverts = (GLfloat*)malloc((size_t)PK_PVERTS_MAX * PK_PFLOATS * sizeof(GLfloat));
    if (!g_pk_fverts) g_pk_fverts = (GLfloat*)malloc((size_t)PK_FVERTS_MAX * PK_FFLOATS * sizeof(GLfloat));
    return g_pk_sverts && g_pk_dverts && g_pk_pverts && g_pk_fverts;
}

/* ── vertex emission (key units; colours 0..255 like the Modizer source) ── */
static inline void pk_put(GLfloat* v, int* nv, float xk, float yb, float ty,
                          float r, float g, float b, float a) {
    float* q = &v[(*nv) * PK_VFLOATS];
    q[0] = xk; q[1] = yb; q[2] = ty;
    q[3] = (r > 255 ? 255 : r < 0 ? 0 : r) / 255.0f;
    q[4] = (g > 255 ? 255 : g < 0 ? 0 : g) / 255.0f;
    q[5] = (b > 255 ? 255 : b < 0 ? 0 : b) / 255.0f;
    q[6] = (a > 255 ? 255 : a < 0 ? 0 : a) / 255.0f;
    (*nv)++;
}
/* Quad between (x0,t0) and (x1,t1): x in key units, t in key-height units
 * (ty = -t, measured UP from the baseline yb). c0/c1 = left/right colours. */
static inline void pk_quad_k(GLfloat* v, int* nv, float yb,
                             float x0, float t0, float x1, float t1,
                             float r0, float g0, float b0, float a0,
                             float r1, float g1, float b1, float a1) {
    pk_put(v, nv, x0, yb, -t0, r0, g0, b0, a0); pk_put(v, nv, x1, yb, -t0, r1, g1, b1, a1); pk_put(v, nv, x1, yb, -t1, r1, g1, b1, a1);
    pk_put(v, nv, x0, yb, -t0, r0, g0, b0, a0); pk_put(v, nv, x1, yb, -t1, r1, g1, b1, a1); pk_put(v, nv, x0, yb, -t1, r0, g0, b0, a0);
}
static inline void pk_quad_k1(GLfloat* v, int* nv, float yb,
                              float x0, float t0, float x1, float t1,
                              float r, float g, float b, float a) {
    pk_quad_k(v, nv, yb, x0, t0, x1, t1, r, g, b, a, r, g, b, a);
}
/* Pixel-space quad (ty = 0): x in key units, y in px. Vertical gradient. */
static inline void pk_quad_px(GLfloat* v, int* nv, float x0, float y0, float x1, float y1,
                              float rt, float gt, float bt, float at,
                              float rb, float gb, float bb, float ab) {
    pk_put(v, nv, x0, y0, 0, rt, gt, bt, at); pk_put(v, nv, x1, y0, 0, rt, gt, bt, at); pk_put(v, nv, x1, y1, 0, rb, gb, bb, ab);
    pk_put(v, nv, x0, y0, 0, rt, gt, bt, at); pk_put(v, nv, x1, y1, 0, rb, gb, bb, ab); pk_put(v, nv, x0, y1, 0, rb, gb, bb, ab);
}

/* Une voix COUPÉE n'enfonce aucune touche et ne fait tomber aucune barre —
 * lu au RENDU (immédiat), voir nv_voice_muted dans la notation. */
static int pk_voice_muted(int v) {
    return (v >= 0 && v < 64) && ((generic_mute_mask >> v) & 1);
}

/* ── colours ─────────────────────────────────────────────────────────────── */
static void pk_note_color(int voice, int instr, float* r, float* g, float* b) {
    float rr, gg, bb;
    /* By instrument: the timeline's per-column instrument number (what the
     * tracker/driver reports — 0 on chips that have none, hence one colour)
     * indexes the notation palette, so a sample keeps its colour whichever
     * voice plays it. By voice: the notation's own colour. */
    int idx = voice;
    /* Règle: l'ÉCHANTILLON quand il existe, sinon la VOIX — jamais « tout
     * de la couleur 0 » sur un moteur sans notion d'instrument (SID, UADE,
     * HVL, puces). */
    if (g_pk_color && instr > 0) {
        /* Au-delà des 16 teintes de la palette, nv_voice_color décline la MÊME
         * teinte en plus clair puis plus sombre: les instruments n et n+16 ne
         * différaient que par la luminosité — « couleurs très proches » sur
         * un MOD à 31 échantillons. On décale la teinte de 5 entrées par
         * palier: n+16 prend le clair d'une AUTRE teinte. */
        const int tier = (instr / NV_PAL_SIZE) % 3;
        idx = (instr + 5 * tier) % NV_PAL_SIZE + tier * NV_PAL_SIZE;
    }
    nv_voice_color(idx, &rr, &gg, &bb);
    *r = rr * 255.0f; *g = gg * 255.0f; *b = bb * 255.0f;
}

/* ── layout ──────────────────────────────────────────────────────────────── */
static void pk_compute_layout(PkLayout* L, int W, int H, int mode, int vc, float span) {
    memset(L, 0, sizeof(*L));
    L->H = H; L->mode = mode; L->light = g_pk_light;
    const float gap = 16.0f * (W > 900 ? 1.5f : 1.0f);
    /* The key ALWAYS keeps its 1:4 aspect. Rather than clamping the height
     * (which squashed the keys past a certain zoom), the ZOOM is floored: the
     * span cannot go below what keeps a 4-wide key inside the keyboard's
     * height budget. The floor feeds pk_clamp_view for both auto and manual. */
    /* Keyboard-per-voice: the floor is ONE keyboard's worth of height, not
     * one per voice — zooming in is allowed to eat rows, and the voices then
     * SHARE the keyboards that remain (v % rows, below). With 16 voices the
     * per-voice budget made the keys tiny and the zoom impossible. */
    const float budget = (mode == 0) ? ((float)H - gap) : ((float)H * 0.28f);
    float floorSpan = (budget > 8.0f) ? (float)W * 4.0f / budget : PK_SPAN_MIN;
    if (floorSpan < PK_SPAN_MIN) floorSpan = PK_SPAN_MIN;
    if (floorSpan > PK_SPAN_MAX) floorSpan = PK_SPAN_MAX;
    g_pk_span_floor = floorSpan;
    if (span < floorSpan) span = floorSpan;
    L->keyWpx = (float)W / (span > 1.0f ? span : 1.0f);
    const float naturalH = L->keyWpx * 4.0f;
    if (mode == 0) {
        int rows = (int)floorf((float)H / (naturalH + gap));
        if (rows > vc) rows = vc;
        if (rows > PK_MAXROWS) rows = PK_MAXROWS;
        if (rows < 1) rows = 1;
        L->rows = rows;
        L->rowH = (float)H / (float)rows;
        L->keyH  = naturalH < 8.0f ? 8.0f : naturalH;
        L->feltH = L->keyH / 24.0f;
    } else {
        L->rows  = 1;
        L->keyH  = naturalH < 8.0f ? 8.0f : naturalH;
        L->feltH = L->keyH / 32.0f;
        L->rowH  = (float)H;
    }
}
/* Baseline (bottom of the keys, px) of row r. */
static inline float pk_row_base(const PkLayout* L, int r) {
    return (L->mode == 0) ? L->rowH * (float)(r + 1) : (float)L->H;
}
/* Does the static VBO need rebuilding for L? Only what it encodes: baselines
 * (H, rows) and the mode. Key width/height are uniforms. */
static int pk_static_differs(const PkLayout* a, const PkLayout* b) {
    return a->H != b->H || a->mode != b->mode || a->rows != b->rows || a->light != b->light;
}

/* ── the keys (Modizer's DrawKeyW / DrawKeyB in key units) ───────────────── */
#define PK_SHADOW_WHITE       (1 << 0)
#define PK_SHADOW_SMALL_BLACK (1 << 1)
#define PK_SHADOW_LARGE_BLACK (1 << 2)
/* Fixed fractions standing for Modizer's absolute pixels ("+1", "+2") so the
 * static keyboard is zoom-independent: 1 px at a 25 px key, 2 px at 100 px. */
#define PK_EX  0.04f
#define PK_EY  0.02f

static void pk_key_white(GLfloat* v, int* nv, const PkLayout* L, int r, int note,
                         float cr, float cg, float cb, float pos, int pressed) {
    /* inset by the inter-key gap: the pitch stays 1, the key is narrower */
    const float x = g_pk_kx[note] + PK_GAP * 0.5f, w = 1.0f - PK_GAP;
    const float yb = pk_row_base(L, r);
    /* bottom lip height, as a fraction of the key height */
    float h2 = (1.0f / 24.0f) * pos + (1.0f / 8.0f) * (1.0f - pos);
    if (pressed) { cr *= 0.8f; cg *= 0.8f; cb *= 0.8f; }

    /* Modizer's baked neighbour shadows only stand in for a light when there
     * is none: with the lighting pass on, the real one casts them. */
    unsigned shadow = 0; float shadowOfs = 0.0f;
    if (!g_pk_light && note > 0) {
        int left = note - 1;
        if (!g_pk_black[left]) {
            if (!g_pk_pressed[r][left] && pressed) shadow = PK_SHADOW_WHITE;
        } else {
            if (!g_pk_pressed[r][left]) {
                shadow = pressed ? PK_SHADOW_LARGE_BLACK : PK_SHADOW_SMALL_BLACK;
                switch (left % 12) {
                    case 1: case 6: shadowOfs = 2.0f / 12; break;
                    case 3: case 10: shadowOfs = 4.0f / 12; break;
                    case 8: shadowOfs = 3.0f / 12; break;
                    default: break;
                }
            }
            if (note >= 2 && !g_pk_pressed[r][note - 2] && pressed) shadow |= PK_SHADOW_WHITE;
        }
    }
    float c[4][3];
    const float fact[4] = {0.25f, 0.5f, 0.75f, 1.5f};
    const float ofs[4]  = {0, 0, 0, 100};
    for (int i = 0; i < 4; i++) { c[i][0] = cr * fact[i] + ofs[i]; c[i][1] = cg * fact[i] + ofs[i]; c[i][2] = cb * fact[i] + ofs[i]; }
    const float A = 255.0f;
    /* left high / low, right high / low */
    pk_quad_k1(v, nv, yb, x, h2, x + PK_EX, 1.0f, c[0][0], c[0][1], c[0][2], A);
    pk_quad_k1(v, nv, yb, x, 0, x + w / 12, h2, 0, 0, 0, A);
    pk_quad_k1(v, nv, yb, x + w - PK_EX, h2, x + w, 1.0f, c[0][0], c[0][1], c[0][2], A);
    pk_quad_k1(v, nv, yb, x + w - w / 12, 0, x + w, h2, 0, 0, 0, A);
    /* face, lip, lit edge, base */
    pk_quad_k1(v, nv, yb, x + PK_EX, h2 + PK_EY, x + w - PK_EX, 1.0f, cr, cg, cb, A);
    pk_quad_k1(v, nv, yb, x + w / 16, PK_EY, x + w - w / 16, h2, c[1][0], c[1][1], c[1][2], A);
    pk_quad_k1(v, nv, yb, x + PK_EX, h2, x + w - PK_EX, h2 + PK_EY, c[3][0], c[3][1], c[3][2], A);
    pk_quad_k1(v, nv, yb, x + w / 16, 0, x + w - w / 16, PK_EY, c[0][0], c[0][1], c[0][2], A);

    if (shadow & PK_SHADOW_WHITE) {
        pk_put(v, nv, x + PK_EX, yb, -(7.0f / 8), 0, 0, 0, 128);
        pk_put(v, nv, x + w / 3, yb, -(h2 + h2),  0, 0, 0, 0);
        pk_put(v, nv, x + PK_EX, yb, -h2,         0, 0, 0, 128);
    }
    if (shadow & PK_SHADOW_SMALL_BLACK) {
        pk_put(v, nv, x + shadowOfs,         yb, -1.0f,             0, 0, 0, 128);
        pk_put(v, nv, x + shadowOfs + w / 4, yb, -(2.0f / 5 + h2),  0, 0, 0, 0);
        pk_put(v, nv, x + shadowOfs,         yb, -(2.0f / 5),       0, 0, 0, 128);
    }
    if (shadow & PK_SHADOW_LARGE_BLACK) {
        pk_put(v, nv, x + shadowOfs,         yb, -1.0f,        0, 0, 0, 128);
        pk_put(v, nv, x + shadowOfs + w / 5, yb, -1.0f,        0, 0, 0, 128);
        pk_put(v, nv, x + shadowOfs,         yb, -(2.0f / 5),  0, 0, 0, 128);
        pk_put(v, nv, x + shadowOfs + w / 5, yb, -1.0f,                 0, 0, 0, 128);
        pk_put(v, nv, x + shadowOfs + w / 2, yb, -(2.0f / 5 + h2 * 3),  0, 0, 0, 0);
        pk_put(v, nv, x + shadowOfs,         yb, -(2.0f / 5),           0, 0, 0, 128);
    }
}

static void pk_key_black(GLfloat* v, int* nv, const PkLayout* L, int r, int note,
                         float cr, float cg, float cb, float pos, int pressed) {
    const float x = g_pk_kx[note], w = PK_BW;
    const float yb = pk_row_base(L, r);
    /* The black key spans the top 3/5 of the white, slightly over the felt. */
    const float b0 = 1.0f - 0.6f, hb = 0.6f * 1.02f;
    float h2 = (hb / 12.0f) * pos + (hb / 4.0f) * (1.0f - pos);
    if (pressed) { cr *= 0.8f; cg *= 0.8f; cb *= 0.8f; }
    float c[4][3];
    const float fact[4] = {0.5f, 1.25f, 1.2f, 1.5f};
    const float ofs[4]  = {0, 100, 128, 128};
    for (int i = 0; i < 4; i++) { c[i][0] = cr * fact[i] + ofs[i]; c[i][1] = cg * fact[i] + ofs[i]; c[i][2] = cb * fact[i] + ofs[i]; }
    const float A = 255.0f;
    #define T(k) (-(b0 + (k)))
    /* flanks (trapezoids) */
    pk_put(v, nv, x,         yb, T(0),  c[0][0], c[0][1], c[0][2], A);
    pk_put(v, nv, x + w / 8, yb, T(h2), c[1][0], c[1][1], c[1][2], A);
    pk_put(v, nv, x + w / 8, yb, T(hb), c[1][0], c[1][1], c[1][2], A);
    pk_put(v, nv, x,         yb, T(0),  c[0][0], c[0][1], c[0][2], A);
    pk_put(v, nv, x + w / 8, yb, T(hb), c[1][0], c[1][1], c[1][2], A);
    pk_put(v, nv, x,         yb, T(hb), c[0][0], c[0][1], c[0][2], A);
    pk_put(v, nv, x + w,         yb, T(0),  c[0][0], c[0][1], c[0][2], A);
    pk_put(v, nv, x + w - w / 8, yb, T(h2), c[1][0], c[1][1], c[1][2], A);
    pk_put(v, nv, x + w - w / 8, yb, T(hb), c[1][0], c[1][1], c[1][2], A);
    pk_put(v, nv, x + w,         yb, T(0),  c[0][0], c[0][1], c[0][2], A);
    pk_put(v, nv, x + w - w / 8, yb, T(hb), c[1][0], c[1][1], c[1][2], A);
    pk_put(v, nv, x + w,         yb, T(hb), c[0][0], c[0][1], c[0][2], A);
    /* face */
    pk_quad_k1(v, nv, yb, x + w / 8, b0 + h2 + PK_EY, x + w - w / 8, b0 + hb, cr, cg, cb, A);
    /* lip (trapezoid) */
    pk_put(v, nv, x,             yb, T(PK_EY), c[0][0], c[0][1], c[0][2], A);
    pk_put(v, nv, x + w,         yb, T(PK_EY), c[0][0], c[0][1], c[0][2], A);
    pk_put(v, nv, x + w / 8,     yb, T(h2),    c[1][0], c[1][1], c[1][2], A);
    pk_put(v, nv, x + w,         yb, T(PK_EY), c[0][0], c[0][1], c[0][2], A);
    pk_put(v, nv, x + w / 8,     yb, T(h2),    c[1][0], c[1][1], c[1][2], A);
    pk_put(v, nv, x + w - w / 8, yb, T(h2),    c[1][0], c[1][1], c[1][2], A);
    /* lit edge, base */
    pk_quad_k1(v, nv, yb, x + w / 8, b0 + h2, x + w - w / 8, b0 + h2 + PK_EY, c[3][0], c[3][1], c[3][2], A);
    pk_quad_k1(v, nv, yb, x, b0, x + w, b0 + PK_EY, c[0][0], c[0][1], c[0][2], A);
    #undef T
}

/* Bevelled bar (Modizer's DrawBox): x in key units, y in px. */
static void pk_box(GLfloat* v, int* nv, float x, float y, float w, float h, float bsx, float bsy,
                   float cr, float cg, float cb, float a) {
    float c[2][3];
    c[0][0] = cr * 0.5f; c[0][1] = cg * 0.5f; c[0][2] = cb * 0.5f;
    c[1][0] = cr * 1.5f + 100; c[1][1] = cg * 1.5f + 100; c[1][2] = cb * 1.5f + 100;
    if (bsx * 2 > w) bsx = w * 0.5f;
    if (bsy * 2 > h) bsy = h * 0.5f;
    /* Dark on top and left, light on the bottom and right (the side facing the
     * keyboard the bar falls onto). */
    pk_quad_px(v, nv, x,           y,           x + w,   y + bsy,     c[0][0], c[0][1], c[0][2], a, c[0][0], c[0][1], c[0][2], a);
    pk_quad_px(v, nv, x,           y,           x + bsx, y + h,       c[0][0], c[0][1], c[0][2], a, c[0][0], c[0][1], c[0][2], a);
    pk_quad_px(v, nv, x,           y + h - bsy, x + w,   y + h,       c[1][0], c[1][1], c[1][2], a, c[1][0], c[1][1], c[1][2], a);
    pk_quad_px(v, nv, x + w - bsx, y,           x + w,   y + h,       c[1][0], c[1][1], c[1][2], a, c[1][0], c[1][1], c[1][2], a);
    pk_quad_px(v, nv, x + bsx,     y + bsy,     x + w - bsx, y + h - bsy, cr, cg, cb, a, cr, cg, cb, a);
}

/* ── static keyboard: every note, every row, all keys UP ─────────────────── */
static void pk_build_static(void) {
    const PkLayout* L = &g_pk_lay;
    int nv = 0;
    /* The shadows a key casts depend on its neighbours' state, and the static
     * copy is the resting keyboard. (The frame's own pressed table is
     * recomputed right after the layout, so nothing is lost.) */
    memset(g_pk_pressed, 0, sizeof(g_pk_pressed));
    for (int r = 0; r < L->rows; r++)
        for (int n = 0; n < PK_NOTES; n++)
            if (!g_pk_black[n] && nv + PK_VERTS_KEYW <= PK_SVERTS_MAX)
                pk_key_white(g_pk_sverts, &nv, L, r, n, 220, 220, 220, 0.0f, 0);
    g_pk_static_whites = nv;
    for (int r = 0; r < L->rows; r++)
        for (int n = 0; n < PK_NOTES; n++)
            if (g_pk_black[n] && nv + PK_VERTS_KEYB <= PK_SVERTS_MAX)
                pk_key_black(g_pk_sverts, &nv, L, r, n, 40, 40, 40, 0.0f, 0);
    g_pk_static_blacks = nv - g_pk_static_whites;
    glBindBuffer(GL_ARRAY_BUFFER, g_pk_svbo);
    glBufferData(GL_ARRAY_BUFFER, (GLsizeiptr)nv * PK_VFLOATS * sizeof(GLfloat), g_pk_sverts, GL_STATIC_DRAW);
    g_pk_static_dirty = 0;
}

/* ── GL setup ────────────────────────────────────────────────────────────── */
static void pk_bind_layout(GLuint prog, GLuint vao, GLuint vbo, int points) {
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    const GLsizei stride = (points ? PK_PFLOATS : PK_VFLOATS) * sizeof(GLfloat);
    GLint aK = glGetAttribLocation(prog, "aKey");    /* xk, yb, ty */
    GLint aC = glGetAttribLocation(prog, "aCol");
    glEnableVertexAttribArray(aK);
    glVertexAttribPointer(aK, 3, GL_FLOAT, GL_FALSE, stride, (void*)0);
    if (points) {
        GLint aS = glGetAttribLocation(prog, "aSize");
        glEnableVertexAttribArray(aS);
        glVertexAttribPointer(aS, 1, GL_FLOAT, GL_FALSE, stride, (void*)(3 * sizeof(GLfloat)));
        glEnableVertexAttribArray(aC);
        glVertexAttribPointer(aC, 4, GL_FLOAT, GL_FALSE, stride, (void*)(4 * sizeof(GLfloat)));
    } else {
        glEnableVertexAttribArray(aC);
        glVertexAttribPointer(aC, 4, GL_FLOAT, GL_FALSE, stride, (void*)(3 * sizeof(GLfloat)));
    }
    glBindVertexArray(0);
}

REWAMP_EXPORT int rewamp_pianoviz_init(int width, int height) {
    {
        int err = rewamp_gl_ensure(width, height);
        if (err != 0) return err;
    }
    if (!g_pk_tables_ready) pk_build_tables();
    // Reuse only if built on THIS context — a non-zero id proves nothing after
    // a context rebuild (see rewamp_notes_render.cpp).
    if (g_pk_prog && g_pk_gen == rewamp_gl_generation()) return 0;
    g_pk_prog = 0; g_pk_pprog = 0;

    /* The view transform: px = xk * keyW + offX ; py = yb + ty * keyH. */
#if REWAMP_GL_Y_FLIPPED
    #define PK_NDC_Y "py * 2.0 / uView.y - 1.0"
#else
    #define PK_NDC_Y "1.0 - py * 2.0 / uView.y"
#endif
    static const char* k_vert =
        "in vec3 aKey;\n"
        "in vec4 aCol;\n"
        /* highp on both: the lighting fragment stage declares the same
         * uniforms in highp, and GLES refuses to link a uniform whose
         * precision differs between stages. */
        "uniform highp vec2 uView;\n"    /* W, H px */
        "uniform highp vec3 uKey;\n"     /* keyW px, offX px, keyH px */
        "out vec4 vC;\n"
        "void main() {\n"
        "  float px = aKey.x * uKey.x + uKey.y;\n"
        "  float py = aKey.y + aKey.z * uKey.z;\n"
        "  gl_Position = vec4(px * 2.0 / uView.x - 1.0, " PK_NDC_Y ", 0.0, 1.0);\n"
        "  vC = aCol;\n"
        "}\n";
    static const char* k_frag =
        "in vec4 vC;\n"
        "out vec4 fragColor;\n"
        "void main() { fragColor = vec4(vC.rgb * vC.a, vC.a); }\n";   /* premultiplied */
    static const char* k_pvert =
        "in vec3 aKey;\n"
        "in float aSize;\n"
        "in vec4 aCol;\n"
        "uniform highp vec2 uView;\n"
        "uniform highp vec3 uKey;\n"
        "out vec4 vC;\n"
        "void main() {\n"
        "  float px = aKey.x * uKey.x + uKey.y;\n"
        "  float py = aKey.y + aKey.z * uKey.z;\n"
        "  gl_Position = vec4(px * 2.0 / uView.x - 1.0, " PK_NDC_Y ", 0.0, 1.0);\n"
        "  gl_PointSize = aSize;\n"
        "  vC = aCol;\n"
        "}\n";
    /* Round sparkle: soft radial falloff, additive. */
    static const char* k_pfrag =
        "in vec4 vC;\n"
        "out vec4 fragColor;\n"
        "void main() {\n"
        "  vec2 d = gl_PointCoord * 2.0 - 1.0;\n"
        "  float r = dot(d, d);\n"
        "  float a = vC.a * max(0.0, 1.0 - r) * max(0.0, 1.0 - r);\n"
        "  fragColor = vec4(vC.rgb * a, a);\n"
        "}\n";
    #include "piano_light_shader.inc"
    /* ── Flames: a small quad standing on the felt at each struck key, the
     * fire drawn procedurally — a bright core at the base tapering upward,
     * its width flickering, a few thin tongues whose height dances with
     * time. Additive, premultiplied. uv.x ∈ [-1,1] across, uv.y ∈ [0,1] up. */
    static const char* k_fvert =
        "in vec3 aKey;\n"
        "in vec2 aUv;\n"
        "in vec4 aCol;\n"
        "uniform highp vec2 uView;\n"
        "uniform highp vec3 uKey;\n"
        "out vec2 vUv;\n"
        "out vec4 vC;\n"
        "void main() {\n"
        "  float px = aKey.x * uKey.x + uKey.y;\n"
        "  float py = aKey.y + aKey.z * uKey.z;\n"
        "  gl_Position = vec4(px * 2.0 / uView.x - 1.0, " PK_NDC_Y ", 0.0, 1.0);\n"
        "  vUv = aUv; vC = aCol;\n"
        "}\n";
    static const char* k_ffrag =
        "in vec2 vUv;\n"
        "in vec4 vC;\n"
        "uniform float uTime;\n"
        "uniform vec2 uSpike;\n"        /* spike pitch and base half-width, in uv units (from px) */
        "out vec4 fragColor;\n"
        "float hash1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }\n"
        "void main() {\n"
        "  float x = vUv.x, y = clamp(vUv.y, 0.0, 1.0), t = uTime;\n"
        /* A SPIKED aura — Saiyan hair, not a candle: a low base glow hugging
           the key top, and sharp TRIANGULAR spikes standing on it, each with
           its own slowly breathing height, leaning outward the farther from
           the centre. A spike is crisp (max, not sum), lit from its base and
           along its edges (a rim), dark-ish in its middle: relief.
           RESOLUTION-INDEPENDENT: the spike pitch and base width are given in
           uv units computed from PIXELS (uSpike), so a bigger aura has MORE
           spikes, not fatter ones — and a fragment only looks at the three
           spikes around it, whatever their number. */
        "  float core = exp(-(x * x) / 0.7);\n"
        "  float body = core * pow(1.0 - y, 3.0) * 0.9;\n"
        "  float spike = 0.0; float rim = 0.0;\n"
        "  float pitch = uSpike.x, hwb = uSpike.y;\n"
        "  float i0 = floor((x + 1.0) / pitch);\n"
        "  for (int j = -1; j <= 1; j++) {\n"
        "    float fi = i0 + float(j);\n"
        "    float cx0 = -1.0 + (fi + 0.5) * pitch;\n"
        "    float ph  = hash1(fi) * 6.2832;\n"
        "    float h   = (0.4 + 0.55 * (0.5 + 0.5 * sin(t * (1.6 + 0.6 * hash1(fi + 7.0)) + ph))) * (1.0 - 0.4 * abs(cx0));\n"
        "    float cx  = cx0 + cx0 * 0.35 * y + 0.35 * pitch * sin(t * 2.6 + ph);\n"   /* lean outward, wobble */
        "    float hw  = hwb * max(0.0, 1.0 - y / h);\n"   /* triangle: wide base, sharp tip */
        "    float d   = abs(x - cx);\n"
        "    if (y < h && d < hw) {\n"
        "      float e = d / hw;\n"                               /* 0 centre .. 1 edge */
        "      float v = (1.0 - y / h) * (0.55 + 0.45 * e);\n"    /* brighter toward the edges */
        "      spike = max(spike, v);\n"
        "      rim = max(rim, smoothstep(0.75, 1.0, e) * (1.0 - y / h));\n"
        "    }\n"
        "  }\n"
        "  float breathe = 0.85 + 0.15 * sin(t * 2.1);\n"
        "  float a = vC.a * breathe * clamp(body + spike * 0.95, 0.0, 1.0);\n"
        /* white-hot at the base and on the rims, the note's colour inside */
        "  vec3 col = mix(vC.rgb, vec3(1.0), clamp(core * pow(1.0 - y, 3.0) * 0.7 + rim * 0.6, 0.0, 1.0));\n"
        "  fragColor = vec4(col * a, a);\n"
        "}\n";
    #undef PK_NDC_Y
    GLuint vs = compile_shader(GL_VERTEX_SHADER,   k_gl_preamble, k_vert);
    GLuint fs = compile_shader(GL_FRAGMENT_SHADER, k_gl_preamble, k_frag);
    if (!vs || !fs) return -10;
    g_pk_prog = link_program(vs, fs);
    glDeleteShader(vs); glDeleteShader(fs);
    if (!g_pk_prog) return -11;
    g_pk_uView = glGetUniformLocation(g_pk_prog, "uView");
    g_pk_uKey  = glGetUniformLocation(g_pk_prog, "uKey");
    GLuint pvs = compile_shader(GL_VERTEX_SHADER,   k_gl_preamble, k_pvert);
    GLuint pfs = compile_shader(GL_FRAGMENT_SHADER, k_gl_preamble, k_pfrag);
    if (!pvs || !pfs) return -12;
    g_pk_pprog = link_program(pvs, pfs);
    glDeleteShader(pvs); glDeleteShader(pfs);
    if (!g_pk_pprog) return -13;
    g_pk_puView = glGetUniformLocation(g_pk_pprog, "uView");
    g_pk_puKey  = glGetUniformLocation(g_pk_pprog, "uKey");
    {
        /* Same vertex stage as the keys (the quad is emitted in key units). */
        GLuint lvs = compile_shader(GL_VERTEX_SHADER,   k_gl_preamble, k_vert);
        GLuint lfs = compile_shader(GL_FRAGMENT_SHADER, k_gl_preamble, k_lfrag);
        if (!lvs || !lfs) return -14;
        g_pk_lprog = link_program(lvs, lfs);
        glDeleteShader(lvs); glDeleteShader(lfs);
        if (!g_pk_lprog) return -15;
        g_pk_luView = glGetUniformLocation(g_pk_lprog, "uView");
        g_pk_luKey  = glGetUniformLocation(g_pk_lprog, "uKey");
        g_pk_luBase = glGetUniformLocation(g_pk_lprog, "uBase");
        g_pk_luN    = glGetUniformLocation(g_pk_lprog, "uNL");
        g_pk_luPos  = glGetUniformLocation(g_pk_lprog, "uLPos");
        g_pk_luCol  = glGetUniformLocation(g_pk_lprog, "uLCol");
        g_pk_luPress = glGetUniformLocation(g_pk_lprog, "uPress");
        g_pk_luPass  = glGetUniformLocation(g_pk_lprog, "uPass");
    }
    {
        GLuint fvs = compile_shader(GL_VERTEX_SHADER,   k_gl_preamble, k_fvert);
        GLuint ffs = compile_shader(GL_FRAGMENT_SHADER, k_gl_preamble, k_ffrag);
        if (!fvs || !ffs) return -16;
        g_pk_fprog = link_program(fvs, ffs);
        glDeleteShader(fvs); glDeleteShader(ffs);
        if (!g_pk_fprog) return -17;
        g_pk_fuView = glGetUniformLocation(g_pk_fprog, "uView");
        g_pk_fuKey  = glGetUniformLocation(g_pk_fprog, "uKey");
        g_pk_fuTime = glGetUniformLocation(g_pk_fprog, "uTime");
        g_pk_fuSpike = glGetUniformLocation(g_pk_fprog, "uSpike");
    }
    {
        GLfloat range[2] = {1.0f, 64.0f};
        glGetFloatv(GL_ALIASED_POINT_SIZE_RANGE, range);
        g_pk_point_max = range[1] > 1.0f ? range[1] : 64.0f;
    }
#ifndef REWAMP_GL_GLES
    glEnable(GL_PROGRAM_POINT_SIZE);   /* desktop GL: gl_PointSize is opt-in */
#endif

    glGenVertexArrays(1, &g_pk_svao); glGenBuffers(1, &g_pk_svbo);
    glGenVertexArrays(1, &g_pk_dvao); glGenBuffers(1, &g_pk_dvbo);
    glGenVertexArrays(1, &g_pk_pvao); glGenBuffers(1, &g_pk_pvbo);
    glGenVertexArrays(1, &g_pk_lvao); glGenBuffers(1, &g_pk_lvbo);
    pk_bind_layout(g_pk_prog,  g_pk_svao, g_pk_svbo, 0);
    pk_bind_layout(g_pk_prog,  g_pk_dvao, g_pk_dvbo, 0);
    pk_bind_layout(g_pk_pprog, g_pk_pvao, g_pk_pvbo, 1);
    pk_bind_layout(g_pk_lprog, g_pk_lvao, g_pk_lvbo, 0);
    {
        glGenVertexArrays(1, &g_pk_fvao); glGenBuffers(1, &g_pk_fvbo);
        glBindVertexArray(g_pk_fvao);
        glBindBuffer(GL_ARRAY_BUFFER, g_pk_fvbo);
        const GLsizei stride = PK_FFLOATS * sizeof(GLfloat);
        GLint aK = glGetAttribLocation(g_pk_fprog, "aKey");
        GLint aU = glGetAttribLocation(g_pk_fprog, "aUv");
        GLint aC = glGetAttribLocation(g_pk_fprog, "aCol");
        glEnableVertexAttribArray(aK);
        glVertexAttribPointer(aK, 3, GL_FLOAT, GL_FALSE, stride, (void*)0);
        glEnableVertexAttribArray(aU);
        glVertexAttribPointer(aU, 2, GL_FLOAT, GL_FALSE, stride, (void*)(3 * sizeof(GLfloat)));
        glEnableVertexAttribArray(aC);
        glVertexAttribPointer(aC, 4, GL_FLOAT, GL_FALSE, stride, (void*)(5 * sizeof(GLfloat)));
        glBindVertexArray(0);
    }

    g_pk_static_dirty = 1;
    memset(g_pk_keypos, 0, sizeof(g_pk_keypos));
    memset(g_pk_spark, 0, sizeof(g_pk_spark));
    memset(g_pk_emit, 0, sizeof(g_pk_emit));
    memset(g_pk_arrow_t, 0, sizeof(g_pk_arrow_t));
    g_pk_npart = 0;
    g_pk_last_t = -1.0;
    g_pk_gen = rewamp_gl_generation();
    return 0;
}

/* ── auto range → view target ────────────────────────────────────────────── */
static void pk_update_range(int n, int vc, double now) {
    int mn = 999, mx = -1;
    for (int c = 0; c < n; c++)
        for (int v = 0; v < vc; v++) {
            if (pk_voice_muted(v)) continue;
            float hz = g_pk_hz[c * vc + v];
            if (hz < 1.0f) continue;
            int m = (int)lroundf(69.0f + 12.0f * log2f(hz / 440.0f));
            if (m < 0 || m >= PK_NOTES) continue;
            if (m < mn) mn = m;
            if (m > mx) mx = m;
        }
    if (!g_pk_seen_ready) {
        for (int k = 0; k <= PK_WHITES; k++) g_pk_lo_seen[k] = g_pk_hi_seen[k] = -1e18;
        g_pk_range_changed = now;
        g_pk_seen_ready = 1;
    }
    if (mx < 0) return;   /* silence: keep what we have */
    /* In WHITE-KEY units: the outer edges of the lowest and highest keys, half
     * a white key of margin, whole keys, at least one octave. It used to be
     * whole OCTAVES with THREE at the minimum, so a tune that fits in two
     * octaves framed 50 % wider than a manual zoom that already showed every
     * note (reported on DukeNukem_Level1.mid, 2026-09-10). The layout's own
     * floor (a key never wider than its height allows) still bounds the zoom,
     * in pk_clamp_view. */
    int lo = (int)floorf(g_pk_kx[mn] - 0.5f);
    int hi = (int)ceilf(g_pk_kx[mx] + g_pk_kw[mx] + 0.5f);
    if (hi - lo < 7) { int mid = (lo + hi) / 2; lo = mid - 3; hi = lo + 7; }
    if (lo < 0) { hi -= lo; lo = 0; }
    if (hi > PK_WHITES) { lo -= hi - PK_WHITES; hi = PK_WHITES; if (lo < 0) lo = 0; }
    g_pk_lo_seen[lo] = now;
    g_pk_hi_seen[hi] = now;
    /* Grow at once: a note outside the keyboard is unacceptable. */
    if (lo < g_pk_range_lo || hi > g_pk_range_hi) {
        if (lo > g_pk_range_lo) lo = g_pk_range_lo;
        if (hi < g_pk_range_hi) hi = g_pk_range_hi;
        g_pk_range_lo = lo; g_pk_range_hi = hi;
        g_pk_range_changed = now;
        return;
    }
    /* Zoom in with slack: at most once per window since the last change, only
     * to the UNION of what the whole window needed, and only for a real gain.
     * With the tight frame, "shrink to what is playing after 4 s" re-framed on
     * every phrase — too much motion (user report, 2026-09-10). */
    if (now - g_pk_range_changed < PK_SHRINK_WINDOW) return;
    int ulo = PK_WHITES, uhi = 0;
    for (int k = 0; k <= PK_WHITES; k++) {
        if (g_pk_lo_seen[k] >= now - PK_SHRINK_WINDOW && k < ulo) ulo = k;
        if (g_pk_hi_seen[k] >= now - PK_SHRINK_WINDOW && k > uhi) uhi = k;
    }
    if (uhi - ulo < 7) return;
    if (ulo < g_pk_range_lo) ulo = g_pk_range_lo;
    if (uhi > g_pk_range_hi) uhi = g_pk_range_hi;
    if ((g_pk_range_hi - g_pk_range_lo) - (uhi - ulo) >= PK_SHRINK_MIN) {
        g_pk_range_lo = ulo; g_pk_range_hi = uhi;
        g_pk_range_changed = now;
    }
}

/* Cubic ease-in-out (a Bézier with horizontal tangents at both ends). */
static inline float pk_ease(float t) {
    if (t <= 0.0f) return 0.0f;
    if (t >= 1.0f) return 1.0f;
    return t * t * (3.0f - 2.0f * t);
}

/* Advance the view: manual = follow the finger; auto = glide to the target
 * whenever it moves (a target that changes mid-glide restarts from where the
 * view IS, never jumps). */
static void pk_update_view(double now) {
    if (g_pk_manual) {
        g_pk_lo = g_pk_mlo; g_pk_span = g_pk_mspan;
        /* Keep the auto target in sync so leaving manual eases from here. */
        g_pk_tlo = g_pk_lo; g_pk_tspan = g_pk_span; g_pk_ease_t0 = -1.0;
        return;
    }
    float tlo = (float)g_pk_range_lo;
    float tspan = (float)(g_pk_range_hi - g_pk_range_lo);
    pk_clamp_view(&tlo, &tspan);
    if (tlo != g_pk_tlo || tspan != g_pk_tspan) {
        /* Fast when the target reaches past the current view (a note is off
         * the keyboard), slow when it zooms in. */
        g_pk_ease_dur = (tlo < g_pk_lo - 0.01f || tlo + tspan > g_pk_lo + g_pk_span + 0.01f)
                        ? PK_EASE_GROW_S : PK_EASE_SHRINK_S;
        g_pk_flo = g_pk_lo; g_pk_fspan = g_pk_span;
        g_pk_tlo = tlo; g_pk_tspan = tspan;
        g_pk_ease_t0 = now;
    }
    if (g_pk_ease_t0 >= 0.0) {
        float s = pk_ease((float)((now - g_pk_ease_t0) / g_pk_ease_dur));
        g_pk_lo   = g_pk_flo   + (g_pk_tlo   - g_pk_flo)   * s;
        g_pk_span = g_pk_fspan + (g_pk_tspan - g_pk_fspan) * s;
        if (s >= 1.0f) g_pk_ease_t0 = -1.0;
    }
}

/* Where the glow (sparkles AND flames) is born: the TOP EDGE OF THE KEYS, i.e.
 * the bottom of the red felt strip — not the top of it. Both effects are drawn
 * after the felt, so they rise OVER it: a jet that started above the felt left
 * a dead red band between the struck key and its own sparks. One definition
 * for the two emitters, so they can never drift apart. */
static inline float pk_glow_origin_y(const PkLayout* L, int row) {
    return pk_row_base(L, row) - L->keyH;
}

/* ── particles ───────────────────────────────────────────────────────────── */
static void pk_particles_step(const PkLayout* L, float dt, float keyWpx) {
    /* Emit from the struck keys (falling mode only): small bright grains that
     * shoot up from the top of the keys, over the felt, and drift back down. Rate per key, budgeted
     * by the pool — a chord of ten never starves the frame. */
    if (g_pk_glow) {
        const float rate = 70.0f;   /* particles per second per pressed key */
        /* Keyboard-per-voice: shorter, slower jets that stay in their row. */
        const float rowScale = (L->mode == 0) ? 0.55f : 1.0f;
        for (int r = 0; r < L->rows; r++)
        for (int m = 0; m < PK_NOTES; m++) {
            if (!g_pk_pressed[r][m]) { g_pk_emit[r][m] = 0.0f; continue; }
            g_pk_emit[r][m] += rate * dt;
            while (g_pk_emit[r][m] >= 1.0f && g_pk_npart < PK_MAXPARTICLES) {
                g_pk_emit[r][m] -= 1.0f;
                PkParticle* p = &g_pk_part[g_pk_npart++];
                float w = g_pk_kw[m];
                p->xk  = g_pk_kx[m] + w * (0.3f + 0.4f * pk_rand());
                p->y   = pk_glow_origin_y(L, r);
                /* An UNDERWATER JET: a narrow column (±16°) rising slowly, the
                 * grains drifting, thinning and sinking back as they fade —
                 * not a fountain. Speeds in px/s, scaled with the key size so
                 * the plume keeps its shape at any zoom; x in key units. */
                float scale = (L->keyH / 100.0f + 0.5f);
                float ang = (pk_rand() - 0.5f) * 0.55f;                    /* radians, 0 = straight up */
                /* ×1.35 on the launch speed (was 55 + 75·rand): the plume reads
                 * taller. Height comes from SPEED, not from a longer life —
                 * drag and gravity cap the climb, so extra life alone only
                 * makes the grains linger at the same height. */
                float spd = (75.0f + 100.0f * pk_rand()) * scale * rowScale;
                p->vy  = -cosf(ang) * spd;
                p->vxk = sinf(ang) * spd / (keyWpx > 1 ? keyWpx : 1);
                p->lifeMax = (1.25f + 0.95f * pk_rand()) * rowScale;
                p->life = p->lifeMax;
                float cr = g_pk_keyr[r][m], cg = g_pk_keyg[r][m], cb = g_pk_keyb[r][m];
                /* Toward white, like Modizer's spark tint. */
                p->r = ((cr * 3 + 255 * 3) / 6) / 255.0f;
                p->g = ((cg * 3 + 255 * 3) / 6) / 255.0f;
                p->b = ((cb * 3 + 255 * 3) / 6) / 255.0f;
                p->size = 2.0f + 3.0f * pk_rand();
            }
            if (g_pk_emit[r][m] > 2.0f) g_pk_emit[r][m] = 2.0f;
        }
    }
    /* Integrate; dead ones are swapped out (order is irrelevant). */
    const float g = 60.0f * (L->keyH / 100.0f + 0.5f);    /* px/s²: a slow settle, like in water */
    for (int i = 0; i < g_pk_npart; ) {
        PkParticle* p = &g_pk_part[i];
        p->life -= dt;
        if (p->life <= 0.0f) { g_pk_part[i] = g_pk_part[--g_pk_npart]; continue; }
        p->vy += g * dt;
        /* water drag: the jet loses its push as it climbs */
        float drag = 1.0f - 0.9f * dt;
        p->vy *= drag; p->vxk *= drag;
        p->y  += p->vy * dt;
        p->xk += p->vxk * dt;
        i++;
    }
}

/* ── frame ───────────────────────────────────────────────────────────────── */
typedef struct { int note, voice; float y0, y1; int active; float r, g, b; } PkBar;
static PkBar g_pk_bars[PK_MAXBARS];

REWAMP_EXPORT void rewamp_pianoviz_render(void) {
    rewamp_gl_make_current();
    if (!pk_ensure_buffers()) return;
    if (!g_pk_tables_ready) pk_build_tables();

    const int W = rewamp_gl_width(), H = rewamp_gl_height();
    const int vc = rewamp_notes_voice_count();
    const int mode = g_pk_mode;
    const double now = nv_now();
    float dt = (g_pk_last_t < 0.0) ? (1.0f / 60.0f) : (float)(now - g_pk_last_t);
    if (dt < 0.0f) dt = 0.0f; if (dt > 0.1f) dt = 0.1f;
    g_pk_last_t = now;
    const float step = dt * 60.0f;   /* Modizer stepped once per 60 Hz frame */

    const double rate   = rewamp_notes_rate();
    const double played = rewamp_notes_played_smooth();
    const int64_t playedI = (int64_t)played;
    const int64_t future  = (int64_t)(PK_FUTURE_S * rate);
    /* A little history so the column under the playhead is always present
     * (the capture step is ~512 frames; a run that started earlier still
     * needs its true onset for the bar merge). Quantised start like the
     * notation, so a straddling run keeps a stable bin. */
    const int64_t kWinQuantum = 512 * 64;
    int64_t wstart = playedI - (int64_t)(0.5 * rate);
    wstart -= ((wstart % kWinQuantum) + kWinQuantum) % kWinQuantum;
    int n = (vc > 0)
        ? rewamp_notes_collect(wstart, playedI + future,
                               g_pk_hz, g_pk_vol, g_pk_instr, g_pk_pos, PK_MAXCOLS)
        : 0;

    glBindFramebuffer(GL_FRAMEBUFFER, rewamp_gl_get_fbo());
    glViewport(0, 0, W, H);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glEnable(GL_BLEND);
    /* The artwork shader outputs STRAIGHT alpha (its opacity is the alpha):
     * blend it as such, like every other viz. Our own geometry is
     * premultiplied — the switch to GL_ONE comes AFTER the artwork. Drawing it
     * under GL_ONE ignored the opacity: the cover came out at 100 %. */
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    art_upload_if_dirty();
    art_render(W, H);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);   /* premultiplied */

    if (vc <= 0 || W <= 0 || H <= 0) {
#ifdef __ANDROID__
        rewamp_gl_force_opaque();
#endif
        rewamp_gl_flush(); return;
    }

    if (n > 0) pk_update_range(n, vc, now);
    pk_update_view(now);
    /* The zoom floor depends on the surface: re-clamp the live view against
     * the floor the layout is about to compute (a rotation or a fullscreen
     * toggle can raise it under a view that was fine). */
    {
        PkLayout L;
        pk_compute_layout(&L, W, H, mode, vc, g_pk_span);
        pk_clamp_view(&g_pk_lo, &g_pk_span);
        if (g_pk_manual) { float ml = g_pk_mlo, ms = g_pk_mspan; pk_clamp_view(&ml, &ms); g_pk_mlo = ml; g_pk_mspan = ms; }
    }
    const float lo = g_pk_lo, span = g_pk_span;

    /* Layout every frame (cheap); the static keyboard only when what it
     * encodes (baselines, rows, mode) changed. Key size is a uniform. */
    {
        PkLayout L;
        pk_compute_layout(&L, W, H, mode, vc, span);
        if (g_pk_static_dirty || pk_static_differs(&L, &g_pk_lay)) {
            g_pk_lay = L;
            pk_build_static();
        } else {
            g_pk_lay = L;
        }
    }
    const PkLayout* L = &g_pk_lay;
    const int rows = L->rows;
    const float keyW = L->keyWpx;
    const float offX = -lo * keyW;
    const int vis0 = (int)floorf(lo), vis1 = (int)ceilf(lo + span);   /* visible white indices */

    /* ── what sounds NOW: the last column at or before the playhead ──────── */
    int nowCol = -1;
    for (int c = 0; c < n; c++) { if (g_pk_pos[c] <= playedI) nowCol = c; else break; }
    memset(g_pk_pressed, 0, sizeof(g_pk_pressed));
    if (nowCol >= 0) {
        for (int v = 0; v < vc; v++) {
            if (pk_voice_muted(v)) continue;
            float hz = g_pk_hz[nowCol * vc + v];
            if (hz < 1.0f) continue;
            int m = (int)lroundf(69.0f + 12.0f * log2f(hz / 440.0f));
            if (m < 0 || m >= PK_NOTES) continue;
            int r = (mode == 0) ? (v % rows) : 0;
            g_pk_pressed[r][m] = 1;
            pk_note_color(v, g_pk_instr[nowCol * vc + v],
                          &g_pk_keyr[r][m], &g_pk_keyg[r][m], &g_pk_keyb[r][m]);
            if (g_pk_manual) {
                int side = -1;
                if (g_pk_kx[m] + g_pk_kw[m] < lo) side = 0;
                else if (g_pk_kx[m] > lo + span) side = 1;
                if (side >= 0) {
                    g_pk_arrow_t[r][side] = now;
                    g_pk_arrow_c[r][side][0] = g_pk_keyr[r][m];
                    g_pk_arrow_c[r][side][1] = g_pk_keyg[r][m];
                    g_pk_arrow_c[r][side][2] = g_pk_keyb[r][m];
                }
            }
        }
    }

    /* ── falling bars (mode 1): merged runs, like the notation ───────────── */
    int nbars = 0;
    if (mode == 1 && n > 0) {
        const double stepEst = 512.0;
        const float yTop = 0.0f, yBot = (float)H - L->keyH - L->feltH;
        const double pxPerSample = (double)(yBot - yTop) / (double)future;
        for (int v = 0; v < vc && nbars < PK_MAXBARS; v++) {
            if (pk_voice_muted(v)) continue;
            for (int c = 0; c < n && nbars < PK_MAXBARS; ) {
                float val = g_pk_hz[c * vc + v];
                if (val < 1.0f) { c++; continue; }
                float sem0 = roundf(12.0f * log2f(val / 440.0f));
                int cs = c, ce = c;
                while (ce + 1 < n) {
                    int nidx = (ce + 1) * vc + v, cidx = ce * vc + v;
                    float nhz = g_pk_hz[nidx];
                    if (nhz < 1.0f) break;
                    if (fabsf(12.0f * log2f(nhz / 440.0f) - sem0) > 0.75f) break;
                    if (g_pk_instr[nidx] != g_pk_instr[cidx]) break;
                    if (g_pk_vol[nidx] > g_pk_vol[cidx] + 2) break;
                    if ((double)(g_pk_pos[ce + 1] - g_pk_pos[ce]) > stepEst * 3.0) break;
                    ce++;
                }
                double runStart = (double)g_pk_pos[cs];
                double runEnd   = (ce + 1 < n) ? (double)g_pk_pos[ce + 1] : (double)g_pk_pos[ce] + stepEst;
                int m = (int)sem0 + 69;
                if (m >= 0 && m < PK_NOTES && runEnd > played &&
                    g_pk_kx[m] + g_pk_kw[m] >= (float)vis0 && g_pk_kx[m] <= (float)vis1) {
                    float y1 = yBot - (float)((runStart - played) * pxPerSample);   /* bottom (onset) */
                    float y0 = yBot - (float)((runEnd   - played) * pxPerSample);   /* top (release) */
                    if (y1 > yBot) y1 = yBot;
                    if (y0 < yTop) y0 = yTop;
                    if (y1 - y0 >= 1.0f) {
                        PkBar* b = &g_pk_bars[nbars++];
                        b->note = m; b->voice = v; b->y0 = y0; b->y1 = y1;
                        b->active = (played >= runStart);
                        pk_note_color(v, g_pk_instr[cs * vc + v], &b->r, &b->g, &b->b);
                    }
                }
                c = ce + 1;
            }
        }
    }

    /* ── key animation ───────────────────────────────────────────────────── */
    for (int r = 0; r < rows; r++)
        for (int m = 0; m < PK_NOTES; m++) {
            float* p = &g_pk_keypos[r][m];
            if (g_pk_pressed[r][m]) { *p += step / 4.0f; if (*p > 1.0f) *p = 1.0f; }
            else                    { *p -= step / 7.0f; if (*p < 0.0f) *p = 0.0f; }
        }
    for (int r = 0; r < rows; r++)
        for (int m = 0; m < PK_NOTES; m++) {
            float* s = &g_pk_spark[r][m];
            if (g_pk_pressed[r][m]) { *s += step * 8.0f / 128.0f; if (*s > 1.0f) *s = 1.0f; }
            else                    { *s -= step * 8.0f / 128.0f; if (*s < 0.0f) *s = 0.0f; }
        }
    pk_particles_step(L, dt, keyW);

    /* ── dynamic layer ───────────────────────────────────────────────────── */
    GLfloat* dv = g_pk_dverts;
    int nv = 0;
    const int maxv = PK_DVERTS_MAX;

    /* Felt strips (drawn under the keys), across the whole keyboard. */
    for (int r = 0; r < rows; r++) {
        float yb = pk_row_base(L, r);
        float y = yb - L->keyH - L->feltH;
        if (nv + 6 > maxv) break;
        if (mode == 0) pk_quad_px(dv, &nv, 0, y, (float)PK_WHITES, y + L->feltH, 80, 40, 40, 255, 140, 0, 0, 255);
        else           pk_quad_px(dv, &nv, 0, y, (float)PK_WHITES, y + L->feltH, 60, 60, 60, 255, 120, 0, 0, 255);
    }

    /* Bars — before the keys, so a bar landing on the felt is covered by the
     * key it strikes. */
    if (mode == 1) {
        for (int i = 0; i < nbars && nv + PK_VERTS_BOX <= maxv; i++) {
            const PkBar* b = &g_pk_bars[i];
            float x = g_pk_kx[b->note], w = g_pk_kw[b->note];
            float extra = b->active ? 2.0f / keyW : 0.0f;   /* key units */
            float extraY = b->active ? 2.0f : 0.0f;
            float cr = b->r, cg = b->g, cb = b->b;
            if (b->active) { cr = (cr + 255) * 0.5f; cg = (cg + 255) * 0.5f; cb = (cb + 255) * 0.5f; }
            float bsy = (keyW >= 8.0f) ? 2.0f : 1.0f;
            pk_box(dv, &nv, x - extra, b->y0 - extraY, w + extra * 2, (b->y1 - b->y0) + extraY * 2,
                   bsy / keyW, bsy, cr, cg, cb, 192);
        }
    }
    const int nvBars = nv;

    /* Moving keys, visible ones only: pressed or still easing, plus the white
     * keys whose shadow depends on a moving black neighbour. */
    int nvWhite0 = nv;
    for (int r = 0; r < rows; r++)
        for (int m = 0; m < PK_NOTES; m++) {
            if (g_pk_black[m]) continue;
            if (g_pk_kx[m] + 1.0f < (float)vis0 || g_pk_kx[m] > (float)vis1) continue;
            int moving = g_pk_pressed[r][m] || g_pk_keypos[r][m] > 0.0f;
            if (!moving && m > 0 && g_pk_black[m - 1] && (g_pk_pressed[r][m - 1] || g_pk_keypos[r][m - 1] > 0.0f))
                moving = 1;
            if (!moving || nv + PK_VERTS_KEYW > maxv) continue;
            float cr = 220, cg = 220, cb = 220;
            if (g_pk_pressed[r][m]) { cr = g_pk_keyr[r][m]; cg = g_pk_keyg[r][m]; cb = g_pk_keyb[r][m]; }
            else if (g_pk_keypos[r][m] > 0.0f) {
                float t = g_pk_keypos[r][m];   /* releasing: back toward ivory */
                cr = 220 + (g_pk_keyr[r][m] - 220) * t; cg = 220 + (g_pk_keyg[r][m] - 220) * t; cb = 220 + (g_pk_keyb[r][m] - 220) * t;
            }
            pk_key_white(dv, &nv, L, r, m, cr, cg, cb, g_pk_keypos[r][m], g_pk_pressed[r][m]);
        }
    const int nvWhite1 = nv;
    for (int r = 0; r < rows; r++)
        for (int m = 0; m < PK_NOTES; m++) {
            if (!g_pk_black[m]) continue;
            if (g_pk_kx[m] + 0.5f < (float)vis0 || g_pk_kx[m] > (float)vis1) continue;
            int moving = g_pk_pressed[r][m] || g_pk_keypos[r][m] > 0.0f;
            if (!moving || nv + PK_VERTS_KEYB > maxv) continue;
            float cr = 40, cg = 40, cb = 40;
            if (g_pk_pressed[r][m]) { cr = g_pk_keyr[r][m]; cg = g_pk_keyg[r][m]; cb = g_pk_keyb[r][m]; }
            else {
                float t = g_pk_keypos[r][m];
                cr = 40 + (g_pk_keyr[r][m] - 40) * t; cg = 40 + (g_pk_keyg[r][m] - 40) * t; cb = 40 + (g_pk_keyb[r][m] - 40) * t;
            }
            pk_key_black(dv, &nv, L, r, m, cr, cg, cb, g_pk_keypos[r][m], g_pk_pressed[r][m]);
        }
    const int nvBlack1 = nv;

    /* Off-screen note arrows (manual view): a thin « -> » at the bottom of
     * the keyboard, on the side the note is, in the note's colour with a fine
     * black outline (the outline = the same strokes, wider, drawn first),
     * fading out over PK_ARROW_S. Geometry in PIXELS around an anchor, so it
     * keeps its size at any zoom. */
    for (int r = 0; r < rows; r++)
        for (int side = 0; side < 2; side++) {
            double age = now - g_pk_arrow_t[r][side];
            if (g_pk_arrow_t[r][side] <= 0.0 || age < 0.0 || age > PK_ARROW_S) continue;
            if (nv + 18 > maxv) break;
            float a = (float)(1.0 - age / PK_ARROW_S) * 255.0f;
            const float yb = pk_row_base(L, r);
            const float dir = (side == 0) ? -1.0f : 1.0f;      /* the head points off-screen */
            /* anchor = the arrow's tip, px from the keyboard's edge and bottom */
            const float tipX = (side == 0) ? (lo + 8.0f / keyW) : (lo + span - 8.0f / keyW);
            const float tipY = 0.08f * L->keyH + 6.0f;          /* px above the base */
            const float* c = g_pk_arrow_c[r][side];
            /* a stroke from (x0,y0) to (x1,y1), px relative to the tip, `th` px wide */
            #define STROKE(X0, Y0, X1, Y1, TH, R, G, B) do { \
                float sx = (X1) - (X0), sy = (Y1) - (Y0); float ln = sqrtf(sx * sx + sy * sy); \
                float nx = -sy / ln * (TH) * 0.5f, ny = sx / ln * (TH) * 0.5f; \
                float ax = tipX + ((X0) + nx) / keyW, ay = -(tipY + (Y0) + ny) / L->keyH; \
                float bx = tipX + ((X1) + nx) / keyW, by = -(tipY + (Y1) + ny) / L->keyH; \
                float cx = tipX + ((X1) - nx) / keyW, cy = -(tipY + (Y1) - ny) / L->keyH; \
                float dx = tipX + ((X0) - nx) / keyW, dy = -(tipY + (Y0) - ny) / L->keyH; \
                pk_put(dv, &nv, ax, yb, ay, R, G, B, a); pk_put(dv, &nv, bx, yb, by, R, G, B, a); pk_put(dv, &nv, cx, yb, cy, R, G, B, a); \
                pk_put(dv, &nv, ax, yb, ay, R, G, B, a); pk_put(dv, &nv, cx, yb, cy, R, G, B, a); pk_put(dv, &nv, dx, yb, dy, R, G, B, a); \
            } while (0)
            /* a filled triangle, px relative to the tip */
            #define TRI(X0, Y0, X1, Y1, X2, Y2, R, G, B) do { \
                pk_put(dv, &nv, tipX + (X0) / keyW, yb, -(tipY + (Y0)) / L->keyH, R, G, B, a); \
                pk_put(dv, &nv, tipX + (X1) / keyW, yb, -(tipY + (Y1)) / L->keyH, R, G, B, a); \
                pk_put(dv, &nv, tipX + (X2) / keyW, yb, -(tipY + (Y2)) / L->keyH, R, G, B, a); \
            } while (0)
            /* 14 px overall: shaft 4 px thick up to 6 px from the tip, then a
             * FILLED head 6 px long and 12 px tall; the outline pass is the
             * same shape grown by ~1.2 px */
            for (int pass = 0; pass < 2; pass++) {
                const float g  = pass == 0 ? 1.2f : 0.0f;
                const float th = 4.0f + 2.0f * g;
                const float cr = pass == 0 ? 0 : c[0], cg = pass == 0 ? 0 : c[1], cb = pass == 0 ? 0 : c[2];
                STROKE(-dir * (14.0f + g), 0, -dir * (6.0f - g), 0, th, cr, cg, cb);
                TRI(dir * g * 1.5f, 0,
                    -dir * (6.0f + g), -(6.0f + g * 1.5f),
                    -dir * (6.0f + g),  (6.0f + g * 1.5f), cr, cg, cb);
            }
            #undef TRI
            #undef STROKE
        }
    const int nvArrow1 = nv;

    /* ── points: particles + a small contact flash on each struck key ────── */
    int np = 0;
    if (g_pk_glow) {
        GLfloat* pv = g_pk_pverts;
        #define PV(XK, Y, SZ, R, G, B, A) do { float* q = &pv[np * PK_PFLOATS]; q[0] = (XK); q[1] = (Y); q[2] = 0.0f; \
            float sz = (SZ); if (sz > g_pk_point_max) sz = g_pk_point_max; if (sz < 1.0f) sz = 1.0f; q[3] = sz; \
            q[4] = (R); q[5] = (G); q[6] = (B); q[7] = (A); np++; } while (0)
        for (int i = 0; i < g_pk_npart && np < PK_PVERTS_MAX; i++) {
            const PkParticle* p = &g_pk_part[i];
            float t = p->life / p->lifeMax;          /* 1 → 0 */
            PV(p->xk, p->y, p->size * (0.4f + 0.6f * t), p->r, p->g, p->b, t * 0.9f);
        }
        #undef PV
    }

    /* ── draw ────────────────────────────────────────────────────────────── */
    glUseProgram(g_pk_prog);
    glUniform2f(g_pk_uView, (float)W, (float)H);
    glUniform3f(g_pk_uKey, keyW, offX, L->keyH);
    glBindVertexArray(g_pk_dvao);
    glBindBuffer(GL_ARRAY_BUFFER, g_pk_dvbo);
    glBufferData(GL_ARRAY_BUFFER, (GLsizeiptr)nv * PK_VFLOATS * sizeof(GLfloat), dv, GL_DYNAMIC_DRAW);
    if (nvBars > 0) glDrawArrays(GL_TRIANGLES, 0, nvBars);                 /* felt + bars */
    glBindVertexArray(g_pk_svao);
    if (g_pk_static_whites > 0) glDrawArrays(GL_TRIANGLES, 0, g_pk_static_whites);
    glBindVertexArray(g_pk_dvao);
    if (nvWhite1 > nvWhite0) glDrawArrays(GL_TRIANGLES, nvWhite0, nvWhite1 - nvWhite0);
    glBindVertexArray(g_pk_svao);
    if (g_pk_static_blacks > 0) glDrawArrays(GL_TRIANGLES, g_pk_static_whites, g_pk_static_blacks);
    glBindVertexArray(g_pk_dvao);
    if (nvBlack1 > nvWhite1) glDrawArrays(GL_TRIANGLES, nvWhite1, nvBlack1 - nvWhite1);
    if (nvArrow1 > nvBlack1) glDrawArrays(GL_TRIANGLES, nvBlack1, nvArrow1 - nvBlack1);

    /* ── flames: one quad standing on the KEY TOPS (over the felt) per struck key */
    int nf = 0;
    if (g_pk_glow) {
        GLfloat* fv = g_pk_fverts;
        for (int r = 0; r < rows; r++)
        for (int m = 0; m < PK_NOTES && nf + 6 <= PK_FVERTS_MAX; m++) {
            float s = g_pk_spark[r][m];
            if (s <= 0.0f) continue;
            if (g_pk_kx[m] + g_pk_kw[m] < (float)vis0 || g_pk_kx[m] > (float)vis1) continue;
            const float feltY = pk_glow_origin_y(L, r);
            float cr = ((g_pk_keyr[r][m] * 2 + 255) / 3) / 255.0f;
            float cg = ((g_pk_keyg[r][m] * 2 + 255) / 3) / 255.0f;
            float cb = ((g_pk_keyb[r][m] * 2 + 255) / 3) / 255.0f;
            float cx = g_pk_kx[m] + g_pk_kw[m] * 0.5f;
            float hw = 1.6f;                       /* half width, key units: wide */
            /* height px: low, and kept inside the row in keyboard-per-voice */
            float fh = keyW * 1.5f;          /* was 1.1: taller, with the jet */
            if (L->mode == 0 && fh > L->rowH - L->keyH) fh = L->rowH - L->keyH;
            #define FV(XK, Y, U, V) do { float* q = &fv[nf * PK_FFLOATS]; q[0] = (XK); q[1] = (Y); q[2] = 0.0f;                 q[3] = (U); q[4] = (V); q[5] = cr; q[6] = cg; q[7] = cb; q[8] = s; nf++; } while (0)
            FV(cx - hw, feltY,      -1, 0); FV(cx + hw, feltY,      1, 0); FV(cx + hw, feltY - fh, 1, 1);
            FV(cx - hw, feltY,      -1, 0); FV(cx + hw, feltY - fh, 1, 1); FV(cx - hw, feltY - fh, -1, 1);
            #undef FV
        }
    }

    /* ── lighting pass: one quad per keyboard, lights = the moving keys ─── */
    if (g_pk_light && g_pk_lprog) {
        glUseProgram(g_pk_lprog);
        glUniform2f(g_pk_luView, (float)W, (float)H);
        glUniform3f(g_pk_luKey, keyW, offX, L->keyH);
        glBindVertexArray(g_pk_lvao);
        glBindBuffer(GL_ARRAY_BUFFER, g_pk_lvbo);
        float lpos[PK_MAXLIGHTS * 2], lcol[PK_MAXLIGHTS * 3];
        for (int r = 0; r < rows; r++) {
            int nl = 0;
            for (int m = 0; m < PK_NOTES && nl < PK_MAXLIGHTS; m++) {
                float k = g_pk_keypos[r][m];
                if (k <= 0.0f) continue;
                if (g_pk_kx[m] + g_pk_kw[m] < (float)vis0 - 3 || g_pk_kx[m] > (float)vis1 + 3) continue;
                lpos[nl * 2 + 0] = g_pk_kx[m] + g_pk_kw[m] * 0.5f;
                lpos[nl * 2 + 1] = k;                       /* eased press amount */
                /* the key's colour pushed toward white, like the sparkles */
                lcol[nl * 3 + 0] = ((g_pk_keyr[r][m] * 2 + 255) / 3) / 255.0f;
                lcol[nl * 3 + 1] = ((g_pk_keyg[r][m] * 2 + 255) / 3) / 255.0f;
                lcol[nl * 3 + 2] = ((g_pk_keyb[r][m] * 2 + 255) / 3) / 255.0f;
                nl++;
            }
            /* nl == 0 still draws: the ambient dimming is what makes a
             * struck key's light read as light. */
            const float yb = pk_row_base(L, r);
            glUniform1f(g_pk_luBase, yb);
            glUniform1i(g_pk_luN, nl);
            if (nl > 0) {
                glUniform2fv(g_pk_luPos, nl, lpos);
                glUniform3fv(g_pk_luCol, nl, lcol);
            }
            /* every key's press amount: the surfaces tilt, the occluders too */
            glUniform4fv(g_pk_luPress, PK_NOTES / 4, g_pk_keypos[r]);
            GLfloat q[6 * PK_VFLOATS]; int nq = 0;
            /* the keys and the felt strip above them, visible span only */
            pk_quad_k1(q, &nq, yb, lo - 0.5f, -L->feltH / L->keyH, lo + span + 0.5f, 1.0f, 0, 0, 0, 0);
            glBufferData(GL_ARRAY_BUFFER, (GLsizeiptr)nq * PK_VFLOATS * sizeof(GLfloat), q, GL_DYNAMIC_DRAW);
            /* REWAMP_PIANO_LIGHT_DEBUG=<n>: draw ONE pass opaque, unblended —
             * 3 = the shader's view of the keyboard (cell x, black, depth),
             * 0 = the modulate factor alone, 1 = the additive light alone. */
            static int dbg = -2;
            if (dbg == -2) { const char* e = getenv("REWAMP_PIANO_LIGHT_DEBUG"); dbg = e ? atoi(e) : -1; }
            if (dbg >= 0) {
                glDisable(GL_BLEND);
                glUniform1i(g_pk_luPass, dbg);
                glDrawArrays(GL_TRIANGLES, 0, nq);
                glEnable(GL_BLEND);
                continue;
            }
            /* pass 0: per-channel modulate (dim + coloured shadows) */
            glBlendFunc(GL_ZERO, GL_SRC_COLOR);
            glUniform1i(g_pk_luPass, 0);
            glDrawArrays(GL_TRIANGLES, 0, nq);
            /* pass 1: additive highlight */
            glBlendFunc(GL_ONE, GL_ONE);
            glUniform1i(g_pk_luPass, 1);
            glDrawArrays(GL_TRIANGLES, 0, nq);
        }
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    }

    if (nf > 0) {
        glBlendFunc(GL_ONE, GL_ONE);   /* additive fire */
        glUseProgram(g_pk_fprog);
        glUniform2f(g_pk_fuView, (float)W, (float)H);
        glUniform3f(g_pk_fuKey, keyW, offX, L->keyH);
        glUniform1f(g_pk_fuTime, (float)fmod(now, 1000.0));
        /* Spike pitch 7 px, base half-width 3.5 px — the look of the player's
         * windowed viz (keyW ≈ 20 px), kept in PIXELS at every size. uv spans
         * 2 over the quad's 2·hw key units. */
        {
            const float quadHalfPx = 1.6f * keyW;
            glUniform2f(g_pk_fuSpike, 7.0f / quadHalfPx, 3.5f / quadHalfPx);
        }
        glBindVertexArray(g_pk_fvao);
        glBindBuffer(GL_ARRAY_BUFFER, g_pk_fvbo);
        glBufferData(GL_ARRAY_BUFFER, (GLsizeiptr)nf * PK_FFLOATS * sizeof(GLfloat), g_pk_fverts, GL_DYNAMIC_DRAW);
        glDrawArrays(GL_TRIANGLES, 0, nf);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    }
    if (np > 0) {
        glBlendFunc(GL_ONE, GL_ONE);   /* additive sparkles */
        glUseProgram(g_pk_pprog);
        glUniform2f(g_pk_puView, (float)W, (float)H);
        glUniform3f(g_pk_puKey, keyW, offX, L->keyH);
        glBindVertexArray(g_pk_pvao);
        glBindBuffer(GL_ARRAY_BUFFER, g_pk_pvbo);
        glBufferData(GL_ARRAY_BUFFER, (GLsizeiptr)np * PK_PFLOATS * sizeof(GLfloat), g_pk_pverts, GL_DYNAMIC_DRAW);
        glDrawArrays(GL_POINTS, 0, np);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    }
    glBindVertexArray(0);
#ifdef __ANDROID__
    rewamp_gl_force_opaque();
#endif
    rewamp_gl_flush();
}

REWAMP_EXPORT void rewamp_pianoviz_uninit(void) {
    if (g_pk_prog)  { glDeleteProgram(g_pk_prog);  g_pk_prog  = 0; }
    if (g_pk_pprog) { glDeleteProgram(g_pk_pprog); g_pk_pprog = 0; }
    if (g_pk_lprog) { glDeleteProgram(g_pk_lprog); g_pk_lprog = 0; }
    if (g_pk_fprog) { glDeleteProgram(g_pk_fprog); g_pk_fprog = 0; }
    if (g_pk_fvbo)  { glDeleteBuffers(1, &g_pk_fvbo); g_pk_fvbo = 0; }
    if (g_pk_fvao)  { glDeleteVertexArrays(1, &g_pk_fvao); g_pk_fvao = 0; }
    free(g_pk_fverts); g_pk_fverts = NULL;
    if (g_pk_lvbo)  { glDeleteBuffers(1, &g_pk_lvbo); g_pk_lvbo = 0; }
    if (g_pk_lvao)  { glDeleteVertexArrays(1, &g_pk_lvao); g_pk_lvao = 0; }
    if (g_pk_svbo)  { glDeleteBuffers(1, &g_pk_svbo); g_pk_svbo = 0; }
    if (g_pk_svao)  { glDeleteVertexArrays(1, &g_pk_svao); g_pk_svao = 0; }
    if (g_pk_dvbo)  { glDeleteBuffers(1, &g_pk_dvbo); g_pk_dvbo = 0; }
    if (g_pk_dvao)  { glDeleteVertexArrays(1, &g_pk_dvao); g_pk_dvao = 0; }
    if (g_pk_pvbo)  { glDeleteBuffers(1, &g_pk_pvbo); g_pk_pvbo = 0; }
    if (g_pk_pvao)  { glDeleteVertexArrays(1, &g_pk_pvao); g_pk_pvao = 0; }
    free(g_pk_sverts); g_pk_sverts = NULL;
    free(g_pk_dverts); g_pk_dverts = NULL;
    free(g_pk_pverts); g_pk_pverts = NULL;
    g_pk_static_dirty = 1;
    g_pk_npart = 0;
}
