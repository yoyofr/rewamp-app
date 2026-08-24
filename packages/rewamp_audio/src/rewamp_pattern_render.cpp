// Tracker-pattern visualizer — C/OpenGL renderer (mode 4).
//
// Included into the same TU as rewamp_viz_render.cpp / rewamp_scope_render.cpp /
// rewamp_notes_render.cpp (Apple podspec wrapper + Android unity TU), reusing
// k_gl_preamble, compile_shader, link_program and art_* from viz_render. All
// file-scope symbols are pv_/g_pv_-prefixed — same rule as nv_.
//
// Replaces the Dart CustomPaint grid (pattern_scope_widget.dart), which
// re-laid-out a TextPainter per cell on every row change — too slow on weak
// devices. Here the pattern text is STATIC geometry:
//
//   - glyphs come from an embedded bitmap font (unscii-16 by default,
//     rewamp_pattern_font.h; the FastTracker 2 font for the FT2 palette,
//     rewamp_pattern_font_ft2.h) uploaded once as an alpha atlas;
//   - a sliding window of rows around the play cursor (~3 screens) is
//     tessellated into one VBO — one textured quad per glyph, colors baked from
//     the palette — and ONLY re-tessellated when the cursor nears the window
//     edge, the order/track/palette changes, or the surface is resized;
//   - per frame the CPU work is: read the consumer-synced cursor, compute one
//     scroll offset uniform, stream a handful of dynamic quads (current-row
//     bar + VU meters + header strip + pinned row-number gutter). Everything
//     else is a static draw.
//
// Sizing is per-font (PvMetrics, computed each frame): the note glyph is scaled
// to fill a consistent row height; for the FT2 style the instrument/volume/fx
// sub-fields use a slightly smaller glyph and the channel numbers a bigger one,
// mirroring the real FastTracker 2 layout.
//
// Pattern data is read straight from the C engine (rewamp_pattern_* — dispatch
// under decodeLock in rewamp_audio.c), so no Dart marshalling is involved.

#include "rewamp_pattern.h"
#include "rewamp_notes.h"              /* shared smoothed playhead + note timeline */
#include "rewamp_pattern_font.h"        /* unscii bitmap (TTF fallback) + PV_FONT_* */
#include "rewamp_pattern_font_ft2.h"    /* FastTracker 2 bitmap (palette option)   */
// High-res default font: stb_truetype bakes a monospace TTF into the atlas, so
// glyphs are crisp at any zoom instead of an upscaled 1-bit bitmap. STBTT_STATIC
// keeps its symbols file-local (this TU is unity-included on Android).
#define STB_TRUETYPE_IMPLEMENTATION
#define STBTT_STATIC
#include "../third_party/stb/stb_truetype.h"
#include "rewamp_pattern_font_ttf.h"    /* embedded JetBrains Mono (ASCII subset)  */
#include "rewamp_pattern_font_ft2ttf.h" /* embedded Font1 Bitmap = FT2 palette font */
#include "rewamp_gl.h"
#include "rewamp_gl_orientation.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define PV_SEP_SHIFT_U 0.5f      /* nudge inter-cell separators left by half a
                                    note-glyph so they sit centered in the gap
                                    (the fx field is usually 3 chars) instead of
                                    glued to the next column's first glyph */
#define PV_MAXCH      64
#define PV_MAX_ORDERS 2048

/* Sliding tessellation window. Visible rows ≈ 34 (size tracks height), so a
 * ~3-screen window re-tessellates only every ~30 rows of playback. */
#define PV_WIN_ROWS   144
#define PV_WIN_EDGE   24         /* re-center when cursor is this close to an edge */
#define PV_MAX_QUADS  (PV_WIN_ROWS * PV_MAXCH * 12 + 4096)
#define PV_VFLOATS    8          /* x,y (window-local px), u,v (atlas; u<0 = solid), r,g,b,a */
#define PV_DYN_QUADS  3072       /* per-frame layer: highlight + VU meters + header
                                    + gutter (worst: 64ch segmented = 64×20 blocks) */

/* ── palettes (mirror PatternPalette.presets in pattern_scope_widget.dart —
 * keep both in sync) ─────────────────────────────────────────────────────── */
/* Volume-meter styles (mirror PatternVolStyle in Dart). */
#define PV_VOL_SOLID     0
#define PV_VOL_GRADIENT  1   /* Y-fixed gradient (ProTracker scope) */
#define PV_VOL_SEGMENTED 2   /* DOS stacked blocks, bicolour top (ST3/IT) */

typedef struct {
    unsigned bg, headerBg, headerText, rowNum, beatRowNum;
    unsigned note, noteEmpty, instrument, volume, fx;
    /* Effect PARAMETER (the value digits) when a style wants it apart from the
     * command; 0 = draw it in `fx`, which is what every stock style does. */
    unsigned fxParam;
    unsigned highlight, beatBg, separator;   /* 0xAARRGGBB */
    float    sepWidthPx;                     /* logical px (×scale at draw) */
    unsigned currentRowText;                 /* 0 = no override */
    int      cornerHeader;                   /* FT2: big number overlay, no strip */
    int      volStyle;                       /* PV_VOL_* */
    unsigned volBar;                         /* solid color / gradient base */
    unsigned volGrad[3];                     /* gradient top→bottom */
    unsigned volLow, volHigh;                /* segmented lower ¾ / top ¼ */
    float    volBarWidthPx;                  /* logical px (×scale) */
    /* ── per-style extras (GL renderer only; the Dart CustomPaint fallback,
     * which only ever runs on the not-yet-shipped Linux/Windows desktop, does
     * not mirror them) ──────────────────────────────────────────────────── */
    int      barBevel;      /* raised-button edge on the highlight bar */
    int      vuOnBar;       /* volume meters stand ON the bar instead of the
                               bottom of the screen (they grow upward from it) */
    int      forceFixedBar; /* the style PINS the bar centered — the moving-bar
                               option is a no-op for it (and hidden in the UI) */
} PvPalette;

static const PvPalette g_pv_palettes[] = {
    /* 0 Rewamp — current row is inverse-video: bright opaque bar + dark glyphs. */
    { 0xFF0A0A0A,0xFF16181C,0xFFB4BCC8,0xFF6A6A6A,0xFF9AA4B0,
      0xFFE8F0FF,0xFF3A3A3A,0xFF5FC9F8,0xFFA8E063,0xFFf2bad4, /* fxParam: same as fx */ 0,
      0xF0EAF0FF,0x0EFFFFFF,0x18FFFFFF, 1.0f, 0xFF0A0A0F, 0,
      PV_VOL_SOLID, 0xFFA8E063, {0,0,0}, 0, 0, 5.0f,
      /* no bevel */ 0, /* VU at the bottom */ 0, /* bar follows the option */ 0 },
    /* 1 ProTracker — the Amiga original holds the playing line in a RAISED grey
     * button: bevelled edge, line pinned mid-screen (the page scrolls under it,
     * never the line), and the volume meters standing
     * ON it rather than at the bottom of the window. The three trailing fields
     * carry exactly that; every other style leaves them zero, i.e. "none".
     * (A 15% magnifier over the bar was tried and dropped: under smooth
     * scrolling the growing/shrinking rows read worse than a plain grid.) */
    { 0xFF000000,0xFFA0A0A0,0xFF202020,0xFF6EDAFB,0xFFFFFFFF,
      0xFF6EDAFB,0xFF23305E,0xFF6EDAFB,0xFF6EDAFB,0xFF6EDAFB, 0,
      0x24B3B3B3,0x14304AC0,0xFF3A3A5A, 1.0f, 0xFFFFFFFF, 0,
      PV_VOL_GRADIENT, 0xFF35C935, {0xFFE83A2A,0xFFE8D020,0xFF35C935}, 0, 0, 10.0f,
      /* bevel */ 1, /* VU on bar */ 1, /* fixed bar */ 1 },
    /* 2 ScreamTracker 3 */
    { 0xFF000000,0xFFA99A66,0xFF1A1400,0xFF7A7A6A,0xFFD8D8C0,
      0xFFE8E8E0,0xFF3A3A32,0xFFB8B8A8,0xFFB8B8A8,0xFFB8B8A8, 0,
      0x55A08A3A,0x14A08A3A,0xFFA99A66, 3.0f, 0, 0,
      PV_VOL_SEGMENTED, 0xFF44CC44, {0,0,0}, 0xFF33CC33, 0xFFE03020, 9.0f,
      0, 0, 0 },
    /* 3 FastTracker II — solid light-blue VU (FT2 is a flat UI: no gradient;
     * gradients are the ProTracker signature), a touch wider (chunky DOS). */
    { 0xFF000000,0xFF000000,0xFFFFFFFF,0xFF8090B0,0xFFE0E4EC,
      0xFFBFC4CE,0xFF303848,0xFF7E98CC,0xFF7E98CC,0xFF7E98CC, 0,
      0xE02E50B0,0x1A2E50B0,0xFF3A6AD0, 1.0f, 0, 1,
      PV_VOL_SOLID, 0xFF9EC2F0, {0,0,0}, 0, 0, 8.0f,
      0, 0, 0 },
    /* 4 Impulse Tracker */
    { 0xFF000000,0xFFB6A784,0xFF241C0A,0xFFC8C0AC,0xFFECE4D0,
      0xFF5CBE5C,0xFF244A24,0xFF4AA24A,0xFF4AA24A,0xFF4AA24A, 0,
      0x99542A2A,0x14FFFFFF,0xFFB6A784, 3.0f, 0, 0,
      PV_VOL_SEGMENTED, 0xFF4EA84E, {0,0,0}, 0xFFC89A2E, 0xFFE03020, 9.0f,
      0, 0, 0 },
    /* 5 MilkyTracker */
    { 0xFF000000,0xFF1A1A2A,0xFFE8E030,0xFFE8ECF0,0xFFE8E030,
      0xFFE8ECF0,0xFF2A2A34,0xFF96DAF8,0xFFA1FC8E,0xFFEF87DB, 0xFFFAE18D,
      0x66701460,0x14283048,0xFF3A5AC0, 1.0f, 0, 0,
      PV_VOL_SOLID, 0xFF3FD23F, {0,0,0}, 0, 0, 5.0f,
      0, 0, 0 },
};
#define PV_PAL_COUNT ((int)(sizeof(g_pv_palettes)/sizeof(g_pv_palettes[0])))
#define PV_PAL_FT2   3   /* uses the authentic FastTracker 2 bitmap font (font1) */

/* Options pushed from Dart (UserSettings). */
static volatile int   g_pv_opt_palette = 0;
static volatile int   g_pv_opt_scroll  = 0;   /* 0 = fixed bar, 1 = moving bar */
static volatile int   g_pv_opt_vu      = 0;   /* per-channel volume meters */
static volatile int   g_pv_opt_smooth  = 1;   /* sub-row interpolated scroll */
static volatile float g_pv_opt_xscroll = 0;   /* horizontal scroll, logical rows-px */
static volatile float g_pv_opt_size    = 1.0f;/* user zoom (x1 / x1.5 / x2 …) */
/* Device pixel ratio of the surface. The glyph size is a FIXED number of
 * logical px (see PV_BASE_ROW_PX) times this — so the font stays the same
 * on-screen size regardless of the window/viewport size, and matches across
 * densities. 1.0 for a logical-sized surface (Apple Texture); the real DPR for
 * a physical-px surface (Android SurfaceView renders at physical resolution). */
static volatile float g_pv_opt_pixscale = 1.0f;
/* Force an OPAQUE black background instead of letting the artwork show through
 * (the grid is dense text; a busy cover under it hurts legibility). */
static volatile int   g_pv_opt_opaque_bg = 0;

REWAMP_EXPORT void rewamp_patternviz_set_opaque_bg(int on) {
    g_pv_opt_opaque_bg = on ? 1 : 0;
}
static volatile int   g_pv_opt_cols    = 0;   /* 0 all, 1 note+instr, 2 note only */

REWAMP_EXPORT void rewamp_patternviz_set_options(int palette, int scrollMode, int showVolume, int smoothScroll) {
    if (palette < 0) palette = 0;
    if (palette >= PV_PAL_COUNT) palette = PV_PAL_COUNT - 1;
    g_pv_opt_palette = palette;
    g_pv_opt_scroll  = scrollMode ? 1 : 0;
    g_pv_opt_vu      = showVolume ? 1 : 0;
    g_pv_opt_smooth  = smoothScroll ? 1 : 0;
}
REWAMP_EXPORT void rewamp_patternviz_set_xscroll(float px) { g_pv_opt_xscroll = px; }

/* User zoom (0.5..4) and column visibility (0 all / 1 note+instr / 2 note). */
REWAMP_EXPORT void rewamp_patternviz_set_layout(float sizeScale, int columnMode) {
    if (sizeScale < 0.5f) sizeScale = 0.5f;
    if (sizeScale > 4.0f) sizeScale = 4.0f;
    g_pv_opt_size = sizeScale;
    if (columnMode < 0) columnMode = 0;
    if (columnMode > 2) columnMode = 2;
    g_pv_opt_cols = columnMode;
}

/* Device pixel ratio of the render surface (see g_pv_opt_pixscale). */
REWAMP_EXPORT void rewamp_patternviz_set_pixel_scale(float dpr) {
    if (dpr < 0.25f) dpr = 0.25f;
    if (dpr > 8.0f)  dpr = 8.0f;
    g_pv_opt_pixscale = dpr;
}

/* ── per-font layout metrics (recomputed each frame) ─────────────────────────
 * The note glyph is scaled to fill a consistent row height regardless of the
 * font's native cell height; the FT2 style then shrinks the sub-fields and
 * enlarges the channel numbers. All positions are in pixels. */
typedef struct {
    GLuint tex;                  /* atlas texture to bind */
    int    fontH;               /* glyph rows in the atlas cell (unscii 16, FT2 10) */
    float  noteS;               /* note-field glyph scale */
    float  subS;                /* instr/vol/fx glyph scale (≤ noteS) */
    float  numS;                /* channel-number glyph scale (> noteS) */
    float  noteW, subW;         /* per-field glyph advance px */
    float  rowH;                /* row pitch px (= fontH * noteS) */
    float  subYoff;             /* sub-field baseline drop so it sits on the note baseline */
    float  gutW;                /* row-number gutter width px */
    float  xNote, xInstr, xVol, xFx, cellW;  /* field x within a cell, px */
    float  sepShift;            /* inter-cell separator left nudge px */
    float  headerH;             /* pinned header strip height px (0 = FT2 corner) */
    int    colMode;             /* 0 all, 1 note+instr, 2 note only */
} PvMetrics;
static PvMetrics g_pv_m;

/* ── GL objects ──────────────────────────────────────────────────────────── */
static unsigned g_pv_gen  = 0;
static GLuint   g_pv_prog = 0;
static GLuint   g_pv_vao = 0, g_pv_vbo = 0;      /* static window tessellation */
static GLuint   g_pv_dvao = 0, g_pv_dvbo = 0;    /* per-frame dynamic layer */
/* Glyph atlases live in g_font_ttf / g_font_ft2 (PvFont, above). */
static GLint    g_pv_uOff = -1, g_pv_uView = -1, g_pv_uTex = -1;
static GLint    g_pv_uOvr = -1, g_pv_uOvrY = -1;

/* ── tessellation state ──────────────────────────────────────────────────── */
static float*   g_pv_verts   = NULL;   /* PV_MAX_QUADS * 6 * PV_VFLOATS, lazy */
static float*   g_pv_dverts  = NULL;   /* PV_DYN_QUADS * 6 * PV_VFLOATS, lazy */
static RewampPatternCell* g_pv_cells = NULL;
static int      g_pv_cells_cap = 0;

static int      g_pv_have    = 0;      /* a window is tessellated + uploaded */
static unsigned g_pv_song_gen = ~0u;   /* rewamp_pattern_song_generation at tess */
static int      g_pv_tess_pal = -1, g_pv_tess_scroll = -1;
static int      g_pv_tess_cols = -1;   /* column mode at tess */
static float    g_pv_tess_rowH = -1;   /* metrics row height at tess (size key) */
static int      g_pv_nch     = 0;      /* channels DISPLAYED (≤ PV_MAXCH) */
static int      g_pv_nch_data = 0;     /* real channel stride of pattern_get data */
static int      g_pv_first_g = 0;      /* window start, GLOBAL row index */
static int      g_pv_nrows   = 0;      /* rows tessellated */
static int      g_pv_bg_verts = 0;     /* [0,bg) bands+separators, [bg,all) cell glyphs */
static int      g_pv_all_verts = 0;
static int      g_pv_tess_order = -1;  /* moving mode: order the window belongs to */

/* Per-order prefix sums (fixed mode's global row timeline). */
static int g_pv_pre[PV_MAX_ORDERS + 1];
static int g_pv_norders = 0, g_pv_total_rows = 0;

static const char* g_pv_note_names[12] =
    { "C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-" };

/* ── helpers ─────────────────────────────────────────────────────────────── */

static void pv_color(unsigned argb, float dimAlpha, float* r, float* g, float* b, float* a) {
    *a = ((argb >> 24) & 0xFF) / 255.0f * dimAlpha;
    if (*a > 1.0f) *a = 1.0f;   /* dimAlpha may boost >1 (bar pulse) — clamp for the blend */
    *r = ((argb >> 16) & 0xFF) / 255.0f;
    *g = ((argb >>  8) & 0xFF) / 255.0f;
    *b = ( argb        & 0xFF) / 255.0f;
}

static int pv_push_quad(float* v, int nv, int maxv,
                        float x0, float y0, float x1, float y1,
                        float u0, float v0, float u1, float v1,
                        float r, float g, float b, float a) {
    if (nv + 6 > maxv) return nv;
    float* q = &v[nv * PV_VFLOATS];
    #define PV_V(X,Y,U,VV) *q++=(X); *q++=(Y); *q++=(U); *q++=(VV); *q++=r; *q++=g; *q++=b; *q++=a;
    PV_V(x0,y0,u0,v0) PV_V(x1,y0,u1,v0) PV_V(x1,y1,u1,v1)
    PV_V(x0,y0,u0,v0) PV_V(x1,y1,u1,v1) PV_V(x0,y1,u0,v1)
    #undef PV_V
    return nv + 6;
}

/* Atlas: 16 glyphs per row, 6 rows (95 printable-ASCII glyphs). Each cell carries
 * a TRANSPARENT gutter (PvFont.pad texels/side): with LINEAR filtering, edge
 * fragments blend toward the gutter (0) not the neighbour glyph — no bleed.
 *
 * Every font has its own cell size (PvFont.cw/ch texels) decoupled from the
 * LAYOUT: a glyph is always drawn into PV_FONT_W×fontH_layout scaled units
 * (fixed tracker column width), sampling the whole cell. So the default font can
 * be baked at high texel resolution (crisp when downsampled) while the layout
 * stays the classic 8×16 grid. */
#define PV_ATLAS_COLS 16
/* Default font: JetBrains Mono baked by stb_truetype at the DISPLAY glyph size
 * (re-baked on zoom/DPR change from pv_compute_metrics) — cellW = cellH/2, the
 * tracker column aspect. Rasterizing at the real pixel size keeps it crisp at
 * every scale (no up/down-sampling). PV_TTF_PAD = the transparent gutter. */
#define PV_TTF_PAD 2

typedef struct {
    GLuint tex;
    int    cw, ch;   /* glyph cell size in atlas TEXELS (excl. gutter) */
    int    pad;      /* gutter texels per side */
    int    aw, ah;   /* full atlas size in texels */
} PvFont;
static PvFont        g_font_ttf = {0};   /* default (all non-FT2 palettes) */
static PvFont        g_font_ft2 = {0};   /* FastTracker 2 palette */
static const PvFont* g_pv_active_font = &g_font_ttf;
static int           g_ttf_baked_h = 0;  /* cell height the default TTF atlas is baked at */
static int           g_ft2_baked_h = 0;  /* cell height the FT2 TTF atlas is baked at */
static void          pv_build_ttf_font(PvFont* f, int cellH);  /* rebaked from metrics */
static void          pv_build_ft2_font(PvFont* f, int cellH);  /* rebaked from metrics */

/* Draw one glyph at scale s. fontH = the glyph's own pixel height (≤ PV_FONT_H);
 * it selects both the quad height and the vertical UV span from the cell top, so
 * a shorter font (FT2 = 10px) draws tight, not squashed. */
static int pv_push_glyph(float* v, int nv, int maxv, char ch,
                         float xpx, float ypx, float s, int fontH,
                         float r, float g, float b, float a) {
    if (ch < PV_FONT_FIRST || ch > PV_FONT_LAST || ch == ' ') return nv;
    const PvFont* f = g_pv_active_font;
    int gi = ch - PV_FONT_FIRST;
    /* Glyph region = the WHOLE cell (texels), inside its gutter. The quad is in
     * LAYOUT units (PV_FONT_W × fontH scaled) regardless of the cell's texel
     * resolution — the sampler maps the cell into it. */
    float gx = (float)((gi % PV_ATLAS_COLS) * (f->cw + 2 * f->pad) + f->pad);
    float gy = (float)((gi / PV_ATLAS_COLS) * (f->ch + 2 * f->pad) + f->pad);
    float u0 = gx / f->aw;
    float v0 = gy / f->ah;
    float u1 = (gx + f->cw) / f->aw;
    float v1 = (gy + f->ch) / f->ah;
    return pv_push_quad(v, nv, maxv, xpx, ypx,
                        xpx + PV_FONT_W * s, ypx + fontH * s,
                        u0, v0, u1, v1, r, g, b, a);
}

static int pv_push_text(float* v, int nv, int maxv, const char* txt,
                        float xpx, float ypx, float s, int fontH,
                        float r, float g, float b, float a) {
    for (; *txt; txt++, xpx += PV_FONT_W * s)
        nv = pv_push_glyph(v, nv, maxv, *txt, xpx, ypx, s, fontH, r, g, b, a);
    return nv;
}

static int pv_push_solid(float* v, int nv, int maxv,
                         float x0, float y0, float x1, float y1,
                         unsigned argb, float dimAlpha) {
    float r,g,b,a; pv_color(argb, dimAlpha, &r,&g,&b,&a);
    return pv_push_quad(v, nv, maxv, x0,y0,x1,y1, -1,-1,-1,-1, r,g,b,a);
}

/* Solid quad with distinct top/bottom colors (vertical gradient segment). */
static int pv_push_grad_quad(float* v, int nv, int maxv,
                             float x0, float y0, float x1, float y1,
                             float tr, float tg, float tb, float ta,
                             float br, float bg, float bb, float ba) {
    if (nv + 6 > maxv) return nv;
    float* q = &v[nv * PV_VFLOATS];
    #define PV_GV(X,Y,R,G,B,A) *q++=(X); *q++=(Y); *q++=-1.0f; *q++=-1.0f; \
        *q++=(R); *q++=(G); *q++=(B); *q++=(A);
    PV_GV(x0,y0,tr,tg,tb,ta) PV_GV(x1,y0,tr,tg,tb,ta) PV_GV(x1,y1,br,bg,bb,ba)
    PV_GV(x0,y0,tr,tg,tb,ta) PV_GV(x1,y1,br,bg,bb,ba) PV_GV(x0,y1,br,bg,bb,ba)
    #undef PV_GV
    return nv + 6;
}

/* Color of the ProTracker-style Y-fixed gradient at height fraction t of the
 * meter zone (0 = bottom = grad[2], 0.5 = grad[1], 1 = top = grad[0]). */
static void pv_grad_at(const unsigned grad[3], float t, float* r, float* g, float* b) {
    float r0,g0,b0,a0, r1,g1,b1,a1, f;
    if (t < 0.5f) { pv_color(grad[2],1,&r0,&g0,&b0,&a0); pv_color(grad[1],1,&r1,&g1,&b1,&a1); f = t * 2.0f; }
    else          { pv_color(grad[1],1,&r0,&g0,&b0,&a0); pv_color(grad[0],1,&r1,&g1,&b1,&a1); f = (t - 0.5f) * 2.0f; }
    *r = r0 + (r1 - r0) * f;
    *g = g0 + (g1 - g0) * f;
    *b = b0 + (b1 - b0) * f;
}

/* Channel separator: 1px flat, or a 3-tone bevel when wide (ST3/IT). s = the
 * separator-width scale; e = the bevel edge width px. */
static int pv_push_separator(float* v, int nv, int maxv, const PvPalette* pal,
                             float x, float y0, float y1, float s, float e) {
    float w = pal->sepWidthPx * s;
    if (w < 1.0f) w = 1.0f;
    unsigned base = pal->separator;
    if (pal->sepWidthPx < 3.0f)
        return pv_push_solid(v, nv, maxv, x, y0, x + w, y1, base, 1.0f);
    unsigned rgb = base & 0xFFFFFF, aa = base & 0xFF000000;
    unsigned dark  = aa | (((rgb >> 16 & 0xFF) / 2) << 16) | (((rgb >> 8 & 0xFF) / 2) << 8) | ((rgb & 0xFF) / 2);
    #define PV_LT(c) (unsigned)((c) + (255 - (c)) / 2)
    unsigned light = aa | (PV_LT(rgb >> 16 & 0xFF) << 16) | (PV_LT(rgb >> 8 & 0xFF) << 8) | PV_LT(rgb & 0xFF);
    #undef PV_LT
    nv = pv_push_solid(v, nv, maxv, x,         y0, x + e,     y1, dark,  1.0f);
    nv = pv_push_solid(v, nv, maxv, x + e,     y0, x + w - e, y1, base,  1.0f);
    nv = pv_push_solid(v, nv, maxv, x + w - e, y0, x + w,     y1, light, 1.0f);
    return nv;
}

/* Current-row bar, optionally BEVELLED like an Amiga raised button: a light
 * band on the top and right edges, a dark one on the bottom and left.
 * [leftEdge]/[rightEdge] say whether this slice owns those edges — the bar is
 * drawn twice (the grid span, then the pinned row-number gutter which masks its
 * left end), and an inner edge drawn mid-bar would read as a seam.
 * [e] = band thickness px, already scaled. */
static int pv_push_bar(float* v, int nv, int maxv,
                       float x0, float y0, float x1, float y1,
                       unsigned argb, float e, int bevel,
                       int leftEdge, int rightEdge) {
    nv = pv_push_solid(v, nv, maxv, x0, y0, x1, y1, argb, 1.0f);
    if (!bevel || e <= 0.0f) return nv;
    const unsigned rgb = argb & 0xFFFFFF, aa = argb & 0xFF000000u;
    const unsigned dark = aa | (((rgb >> 16 & 0xFF) / 2) << 16)
                             | (((rgb >>  8 & 0xFF) / 2) <<  8)
                             |  ((rgb       & 0xFF) / 2);
    #define PV_LT(c) (unsigned)((c) + (255 - (c)) / 2)
    const unsigned light = aa | (PV_LT(rgb >> 16 & 0xFF) << 16)
                              | (PV_LT(rgb >>  8 & 0xFF) <<  8)
                              |  PV_LT(rgb       & 0xFF);
    #undef PV_LT
    nv = pv_push_solid(v, nv, maxv, x0, y0,     x1, y0 + e, light, 1.0f);
    nv = pv_push_solid(v, nv, maxv, x0, y1 - e, x1, y1,     dark,  1.0f);
    if (rightEdge)
        nv = pv_push_solid(v, nv, maxv, x1 - e, y0, x1,      y1, light, 1.0f);
    if (leftEdge)
        nv = pv_push_solid(v, nv, maxv, x0,     y0, x0 + e,  y1, dark,  1.0f);
    return nv;
}

static void pv_note_text(int note, char out[4]) {
    if (note >= 0) {
        int oct = note / 12; if (oct > 9) oct = 9;
        out[0] = g_pv_note_names[note % 12][0];
        out[1] = g_pv_note_names[note % 12][1];
        out[2] = (char)('0' + oct);
    } else if (note == REWAMP_NOTE_OFF)  { out[0]=out[1]=out[2]='='; }
    else if (note == REWAMP_NOTE_CUT)    { out[0]=out[1]=out[2]='^'; }
    else if (note == REWAMP_NOTE_FADE)   { out[0]=out[1]=out[2]='~'; }
    else                                 { out[0]=out[1]=out[2]='.'; }
    out[3] = 0;
}

static void pv_hex2(int val, char out[3]) {
    static const char* H = "0123456789ABCDEF";
    if (val < 0) { out[0] = out[1] = '.'; }
    else { out[0] = H[(val >> 4) & 15]; out[1] = H[val & 15]; }
    out[2] = 0;
}

/* Same, but `digits` wide (2 or 4). A field's width is a per-song property
 * (RewampPatternSongInfo) because it sizes the cell as well as formatting it:
 * SunVox's module number and effect parameter are 16-bit, trackers' are bytes. */
#define PV_MAX_FIELD_DIGITS 4
static void pv_hexn(int val, int digits, char* out) {
    static const char* H = "0123456789ABCDEF";
    if (digits < 1) digits = 2;
    if (digits > PV_MAX_FIELD_DIGITS) digits = PV_MAX_FIELD_DIGITS;
    for (int i = 0; i < digits; i++)
        out[i] = (val < 0) ? '.' : H[(val >> (4 * (digits - 1 - i))) & 15];
    out[digits] = 0;
}

/* Per-song field widths, refreshed with the order table (0 ⇒ tracker default). */
static int g_pv_instr_digits = 2;
static int g_pv_vol_chars    = 2;
static int g_pv_fxcode_chars = 2;
static int g_pv_fxval_digits = 2;

/* Refresh the order→global-row prefix sums. ~2 locked calls per order, only on
 * a song/track change. */
static int pv_refresh_orders(void) {
    RewampPatternSongInfo si;
    if (!rewamp_pattern_song_info(&si)) return 0;
    if (si.num_channels <= 0 || si.num_orders <= 0) return 0;
    int no = si.num_orders; if (no > PV_MAX_ORDERS) no = PV_MAX_ORDERS;
    g_pv_pre[0] = 0;
    for (int o = 0; o < no; o++) {
        int p = rewamp_pattern_order(o);
        int r = (p >= 0) ? rewamp_pattern_num_rows(p) : 0;
        g_pv_pre[o + 1] = g_pv_pre[o] + (r > 0 ? r : 0);
    }
    g_pv_norders    = no;
    g_pv_total_rows = g_pv_pre[no];
    /* Cells arrive with the REAL channel stride; display caps at PV_MAXCH
     * (a >64-channel module is horizontally scrolled anyway). */
    g_pv_nch_data   = si.num_channels;
    g_pv_nch        = si.num_channels < PV_MAXCH ? si.num_channels : PV_MAXCH;
    // 0 = "use the default width"; NEGATIVE = the song does not use that column
    // at all, so it is dropped from the layout rather than drawn as dots (a MOD
    // has no volume column; a module that never sets an instrument has no use
    // for that one either).
    g_pv_instr_digits = si.instr_digits == 0 ? 2 : si.instr_digits;
    g_pv_vol_chars    = si.vol_chars    == 0 ? 2 : si.vol_chars;
    g_pv_fxcode_chars = si.fxcode_chars == 0 ? 2 : si.fxcode_chars;
    g_pv_fxval_digits = si.fxval_digits == 0 ? 2 : si.fxval_digits;
    if (g_pv_instr_digits < 0) g_pv_instr_digits = 0;
    if (g_pv_vol_chars    < 0) g_pv_vol_chars    = 0;
    /* A negative fx width drops the pair (code + value) — a backend with no
     * effects at all. 0 after this clamp means ABSENT everywhere below. */
    if (g_pv_fxcode_chars < 0 || g_pv_fxval_digits < 0)
        g_pv_fxcode_chars = g_pv_fxval_digits = 0;
    if (g_pv_instr_digits > PV_MAX_FIELD_DIGITS) g_pv_instr_digits = PV_MAX_FIELD_DIGITS;
    if (g_pv_vol_chars > REWAMP_PATTERN_VOL_CHARS - 1)
        g_pv_vol_chars = REWAMP_PATTERN_VOL_CHARS - 1;
    if (g_pv_fxcode_chars > REWAMP_PATTERN_FX_CHARS) g_pv_fxcode_chars = REWAMP_PATTERN_FX_CHARS;
    if (g_pv_fxval_digits > PV_MAX_FIELD_DIGITS) g_pv_fxval_digits = PV_MAX_FIELD_DIGITS;
    return g_pv_total_rows > 0;
}

/* Global row index → (order, row). Returns 0 when out of the song. */
static int pv_locate(int gidx, int* order, int* row) {
    if (gidx < 0 || gidx >= g_pv_total_rows) return 0;
    int lo = 0, hi = g_pv_norders - 1;
    while (lo < hi) {                       /* first order with pre[o+1] > gidx */
        int mid = (lo + hi) / 2;
        if (g_pv_pre[mid + 1] > gidx) hi = mid; else lo = mid + 1;
    }
    *order = lo; *row = gidx - g_pv_pre[lo];
    return g_pv_pre[lo + 1] > g_pv_pre[lo];  /* empty order → invalid */
}

/* Compute per-font layout metrics for this frame (see PvMetrics). */
/* Base row height in LOGICAL px at zoom 1.0. Fixed — the glyph size must not
 * track the window size (the whole point of this metric). The real px row
 * height is this × the surface DPR × the user zoom, so it stays the same
 * on-screen size across window sizes AND densities. Chosen to match the old
 * ~H/32 look at a typical panel size. */
#define PV_BASE_ROW_PX 17.0f
static void pv_compute_metrics(int H) {
    (void)H;   /* row height is fixed now — no longer a fraction of the view */
    const int ft2 = (g_pv_opt_palette == PV_PAL_FT2);
    const PvPalette* pal = &g_pv_palettes[g_pv_opt_palette];
    PvMetrics m;
    // Select the atlas for this palette. fontH is the LAYOUT height (the note
    // glyph fills a row of `rowH`, so noteS = rowH/fontH); it is independent of
    // the font's atlas texel resolution.
    g_pv_active_font = ft2 ? &g_font_ft2 : &g_font_ttf;
    m.fontH = ft2 ? PV_FT2_FONT_H : PV_FONT_H;   /* m.tex set after any TTF rebake below */

    /* Fixed logical row height × surface DPR × user zoom (NOT viewport-relative).
     * FT2's glyph cell is taller/heavier → a per-font trim so it reads the same
     * size as the others. The note glyph fills the row — no wasted air. */
    float zoom = g_pv_opt_size; if (zoom <= 0.0f) zoom = 1.0f;
    float dpr  = g_pv_opt_pixscale; if (dpr <= 0.0f) dpr = 1.0f;
    float rowH = PV_BASE_ROW_PX * dpr * zoom * (ft2 ? 0.95f : 1.0f);
    if (rowH < (float)m.fontH) rowH = (float)m.fontH;   /* never sub-pixel a glyph */
    m.rowH  = rowH;
    m.noteS = rowH / (float)m.fontH;
    m.subS  = ft2 ? m.noteS * 0.78f : m.noteS;   /* FT2: slightly smaller sub-fields */
    m.numS  = m.noteS * 1.28f;                   /* channel numbers ≥20% bigger */

    /* Re-bake the active TTF atlas at the REAL glyph pixel size when it changes
     * (zoom / DPR). This is what keeps it crisp at every scale: glyphs are
     * rasterized at their display size (1:1, no upscale) rather than a fixed
     * atlas that gets downsampled (heavy → muddy/dark at small zoom) or upscaled
     * (soft at big). Bake to the LARGEST field (channel numbers = rowH×1.28) so
     * every field is a ≤1:1 downscale. Render thread only; only on a size change. */
    {
        int wantH = (int)(m.rowH * 1.28f + 0.5f);
        if (wantH < 12)  wantH = 12;
        if (wantH > 220) wantH = 220;
        if (ft2) {
            if (wantH != g_ft2_baked_h) {
                if (g_font_ft2.tex) { glDeleteTextures(1, &g_font_ft2.tex); g_font_ft2.tex = 0; }
                pv_build_ft2_font(&g_font_ft2, wantH);
                g_ft2_baked_h = wantH;
            }
        } else {
            if (wantH != g_ttf_baked_h) {
                if (g_font_ttf.tex) { glDeleteTextures(1, &g_font_ttf.tex); g_font_ttf.tex = 0; }
                pv_build_ttf_font(&g_font_ttf, wantH);
                g_ttf_baked_h = wantH;
            }
        }
    }
    m.tex = g_pv_active_font->tex;

    m.noteW = PV_FONT_W * m.noteS;
    m.subW  = PV_FONT_W * m.subS;
    m.subYoff = m.fontH * (m.noteS - m.subS);    /* bottom-align sub-fields to the note */

    const float pad  = 0.5f * m.noteW;           /* left pad + note→instr gap */
    const float sgap = 0.5f * m.subW;            /* gaps between sub-fields */
    /* Field widths follow the SONG, not the format we assume: SunVox's module
     * and effect parameter are 16-bit words (see RewampPatternSongInfo). */
    const float instrW = (float)g_pv_instr_digits * m.subW;
    const float volW   = (float)g_pv_vol_chars    * m.subW;
    const float fxW    = (float)(g_pv_fxcode_chars + g_pv_fxval_digits) * m.subW;
    m.xNote  = pad;
    m.xInstr = m.xNote  + 3 * m.noteW + pad;
    // A dropped column contributes neither width NOR its separating gap.
    m.xVol   = m.xInstr + instrW + (g_pv_instr_digits > 0 ? sgap : 0.0f);
    m.xFx    = m.xVol   + volW   + (g_pv_vol_chars    > 0 ? sgap : 0.0f);
    m.gutW   = 3 * m.noteW;                       /* 2 hex digits + padding */
    m.sepShift = PV_SEP_SHIFT_U * m.noteW;

    /* Column visibility trims the cell width to what is drawn. */
    m.colMode = g_pv_opt_cols;
    switch (m.colMode) {
        case 2:  m.cellW = m.xNote  + 3 * m.noteW + 0.5f * m.noteW; break;  /* minimal  */
        case 1:  m.cellW = m.xInstr + instrW + 0.5f * m.subW;        break;  /* reduced  */
        /* fxW is 0 when the effect pair is absent (a synthesized grid has no
         * effects at all), and xFx then still carries the volume gap — so the
         * cell ends right after the volume, with no reserved dot field. */
        default: m.cellW = m.xFx    + fxW         + 0.5f * m.subW;          /* full     */
    }

    m.headerH = pal->cornerHeader ? 0.0f : (m.fontH * m.numS + 4.0f);
    g_pv_m = m;
}

/* ── window tessellation ─────────────────────────────────────────────────── */

/* Push the cell glyphs of one row. cx = cell left px, y = row top px. */
static int pv_push_cell(float* v, int nv, int maxv, const PvMetrics* m,
                        const RewampPatternCell* c, float cx, float y,
                        const PvPalette* pal, float dim) {
    float cr, cg, cb, ca;
    char txt[16];   /* widest: 4-char effect code + 4-digit param + '+' + NUL */

    char nt[4]; pv_note_text(c->note, nt);
    pv_color(c->note == REWAMP_NOTE_EMPTY ? pal->noteEmpty : pal->note,
             dim, &cr, &cg, &cb, &ca);
    nv = pv_push_text(v, nv, maxv, nt, cx + m->xNote, y, m->noteS, m->fontH, cr, cg, cb, ca);
    if (m->colMode >= 2) return nv;   /* note only */

    const float sy = y + m->subYoff;
    if (g_pv_instr_digits > 0) {
        pv_hexn(c->instrument, g_pv_instr_digits, txt);
        pv_color(c->instrument < 0 ? pal->noteEmpty : pal->instrument, dim, &cr, &cg, &cb, &ca);
        nv = pv_push_text(v, nv, maxv, txt, cx + m->xInstr, sy, m->subS, m->fontH, cr, cg, cb, ca);
    }
    if (m->colMode >= 1) return nv;   /* note + instrument */

    // The volume column is a STRING when the backend pre-formatted it (see
    // RewampPatternCell::vol): XM/IT multiplex that column, and most formats
    // have none at all, so libopenmpt renders it the way its own tracker does.
    // Numeric `volume` is the fallback for backends with a plain 0..255 volume.
    int volEmpty;
    if (g_pv_vol_chars <= 0) {
        volEmpty = -1;               /* column dropped for this song */
    } else if (c->vol[0]) {
        int k = 0;
        for (; k < REWAMP_PATTERN_VOL_CHARS - 1 && c->vol[k]; k++) txt[k] = c->vol[k];
        txt[k] = 0;
        volEmpty = 0;
    } else if (c->volume >= 0) {
        pv_hexn(c->volume, g_pv_vol_chars, txt);
        volEmpty = 0;
    } else {
        int n = g_pv_vol_chars;
        for (int k = 0; k < n; k++) txt[k] = '.';
        txt[n] = 0;
        volEmpty = 1;
    }
    if (volEmpty >= 0) {
        pv_color(volEmpty ? pal->noteEmpty : pal->volume, dim, &cr, &cg, &cb, &ca);
        nv = pv_push_text(v, nv, maxv, txt, cx + m->xVol, sy, m->subS, m->fontH, cr, cg, cb, ca);
    }

    /* fx: display chars + param (openmpt "A0F", furnace "0AFF"), '+' marker when
     * more columns are stacked. Empty → "...". Width 0 = the backend has no
     * effect columns at all → nothing here, not even the dots. */
    if (g_pv_fxcode_chars <= 0 && g_pv_fxval_digits <= 0) return nv;
    if (c->num_fx > 0 && c->fx[0][0]) {
        /* The effect COMMAND and its PARAMETER carry their own colour (a style
         * wanting one look leaves fxParam at 0, and both fall back to `fx`),
         * hence two pushes: the second is advanced by the command's width, a
         * glyph advance being PV_FONT_W * scale — the step pv_push_text uses.
         * The '+' marker (this cell stacks more effect columns) qualifies the
         * COMMAND, so it takes its colour; it can only sit at the end, after
         * the parameter. */
        int fi = 0;
        for (int k = 0; k < REWAMP_PATTERN_FX_CHARS && c->fx[0][k]; k++)
            txt[fi++] = c->fx[0][k];
        txt[fi] = 0;
        pv_color(pal->fx, dim, &cr, &cg, &cb, &ca);
        nv = pv_push_text(v, nv, maxv, txt, cx + m->xFx, sy, m->subS, m->fontH,
                          cr, cg, cb, ca);
        float px = cx + m->xFx + (float)fi * PV_FONT_W * m->subS;
        if (c->fxval[0] >= 0) {
            char h[PV_MAX_FIELD_DIGITS + 1];
            pv_hexn(c->fxval[0], g_pv_fxval_digits, h);
            float pr, pg, pb, pa;
            pv_color(pal->fxParam ? pal->fxParam : pal->fx, dim, &pr, &pg, &pb, &pa);
            nv = pv_push_text(v, nv, maxv, h, px, sy, m->subS, m->fontH,
                              pr, pg, pb, pa);
            for (int k = 0; h[k]; k++) px += PV_FONT_W * m->subS;
        }
        if (c->num_fx > 1)
            nv = pv_push_text(v, nv, maxv, "+", px, sy, m->subS, m->fontH,
                              cr, cg, cb, ca);
        return nv;
    }
    {
        int n = g_pv_fxcode_chars + 1;   /* an empty field still reads as a field */
        for (int k = 0; k < n; k++) txt[k] = '.';
        txt[n] = 0;
        pv_color(pal->noteEmpty, dim, &cr, &cg, &cb, &ca);
    }
    nv = pv_push_text(v, nv, maxv, txt, cx + m->xFx, sy, m->subS, m->fontH, cr, cg, cb, ca);
    return nv;
}

/* Tessellate rows [firstG, firstG+nRows) of the global timeline into the static
 * VBO. Layout: [background: beat bands + inter-cell + closing separators][cell
 * glyphs]. Row-number gutter is drawn per-frame (pinned) in the render pass, not
 * here. Coordinates are window-local px (row i top = i*rowH); the draw adds a
 * scroll uniform. */
static int pv_tessellate(int firstG, int curOrder) {
    const PvMetrics* m = &g_pv_m;
    const PvPalette* pal = &g_pv_palettes[g_pv_opt_palette];
    const float rowH  = m->rowH;
    const int   nch   = g_pv_nch;
    const float gutW  = m->gutW;
    const float cellW = m->cellW;
    const float rowW  = gutW + nch * cellW;
    const float sepS  = m->noteS;
    const int   maxv  = PV_MAX_QUADS * 6;

    if (!g_pv_verts) {
        g_pv_verts = (float*)malloc((size_t)PV_MAX_QUADS * 6 * PV_VFLOATS * sizeof(float));
        if (!g_pv_verts) return 0;
    }
    int nRows = PV_WIN_ROWS;
    if (firstG < 0) firstG = 0;
    if (firstG + nRows > g_pv_total_rows) nRows = g_pv_total_rows - firstG;
    if (nRows <= 0) return 0;

    /* Fetch each distinct pattern in the window once — sized/indexed with the
     * REAL channel stride (nchData), which can exceed the displayed nch. */
    const int nchData = g_pv_nch_data;
    int cellsNeeded = 0;
    { int o0, r0, o1, r1;
      if (!pv_locate(firstG, &o0, &r0) || !pv_locate(firstG + nRows - 1, &o1, &r1)) return 0;
      for (int o = o0; o <= o1; o++) {
          int rows = g_pv_pre[o + 1] - g_pv_pre[o];
          if (rows * nchData > cellsNeeded) cellsNeeded = rows * nchData;
      }
    }
    if (cellsNeeded > g_pv_cells_cap) {
        free(g_pv_cells);
        g_pv_cells = (RewampPatternCell*)malloc((size_t)cellsNeeded * sizeof(RewampPatternCell));
        if (!g_pv_cells) { g_pv_cells_cap = 0; return 0; }
        g_pv_cells_cap = cellsNeeded;
    }

    float* v = g_pv_verts;
    int nv = 0;

    /* Background: beat/measure bands + inter-cell separators (ch 1..nch, so the
     * last one closes the final column; the gutter separator is pinned). */
    for (int i = 0; i < nRows; i++) {
        int o, r;
        if (!pv_locate(firstG + i, &o, &r)) continue;
        if (g_pv_opt_scroll == 1 && o != curOrder) continue;   /* moving: own pattern only */
        if (r % 4 == 0) {
            float y = i * rowH;
            nv = pv_push_solid(v, nv, maxv, 0, y, rowW, y + rowH, pal->beatBg, 1.0f);
            if (r % 16 == 0)
                nv = pv_push_solid(v, nv, maxv, 0, y, rowW, y + rowH, pal->beatBg, 1.0f);
        }
    }
    for (int ch = 1; ch <= nch; ch++)
        nv = pv_push_separator(v, nv, maxv, pal,
                               gutW + ch * cellW - m->sepShift, 0, nRows * rowH, sepS, sepS);
    int bgVerts = nv;

    /* Cell glyphs, row-major. Pattern cells are fetched lazily per order. */
    int loadedOrder = -1, loadedRows = 0, haveCells = 0;
    for (int i = 0; i < nRows; i++) {
        int o, r;
        if (!pv_locate(firstG + i, &o, &r)) continue;
        if (g_pv_opt_scroll == 1 && o != curOrder) continue;
        if (o != loadedOrder) {
            loadedOrder = o;
            loadedRows  = g_pv_pre[o + 1] - g_pv_pre[o];
            int p = rewamp_pattern_order(o);
            haveCells = (p >= 0) &&
                rewamp_pattern_get(p, g_pv_cells, loadedRows * nchData)
                    == loadedRows * nchData;
        }
        if (!haveCells) continue;
        const float y   = i * rowH;
        const float dim = (o == curOrder) ? 1.0f : 0.32f;   /* adjacent orders dimmed */
        for (int ch = 0; ch < nch; ch++)
            nv = pv_push_cell(v, nv, maxv, m, &g_pv_cells[r * nchData + ch],
                              gutW + ch * cellW, y, pal, dim);
    }

    glBindBuffer(GL_ARRAY_BUFFER, g_pv_vbo);
    glBufferData(GL_ARRAY_BUFFER, (GLsizeiptr)(nv * PV_VFLOATS * sizeof(float)),
                 g_pv_verts, GL_STATIC_DRAW);

    g_pv_first_g   = firstG;
    g_pv_nrows     = nRows;
    g_pv_bg_verts  = bgVerts;
    g_pv_all_verts = nv;
    g_pv_tess_rowH = rowH;
    g_pv_tess_pal  = g_pv_opt_palette;
    g_pv_tess_scroll = g_pv_opt_scroll;
    g_pv_tess_cols   = m->colMode;
    g_pv_tess_order  = curOrder;
    g_pv_have      = 1;
    return 1;
}

/* ── synthesized mode (backends without pattern data) ────────────────────────
 * Rows are generated from the look-ahead note timeline (rewamp_notes): a fixed
 * 8 rows/s grid, each cell showing the note (Hz → semitone), volume and
 * instrument the voice held at that row's start. No orders, no fx. Re-
 * tessellated on every row advance (8 Hz × a few-thousand quads — trivial),
 * which is also how freshly-decoded look-ahead rows appear. */

#define PV_SYN_ROWS_PER_S 8.0
#define PV_SYN_COLS       1024

/* How many seconds of FUTURE rows the synthesized grid currently shows, i.e.
 * how much decode look-ahead it needs to draw a full surface. Dart polls this
 * and feeds rewamp_set_lookahead_seconds().
 *
 * This has to live here because only this file knows the row height, and that
 * rule changed: rows used to be a fraction of the view (~H/32), they are now a
 * FIXED logical size scaled by the surface DPR and the user zoom (see
 * PV_BASE_ROW_PX). Dart still carried the old `16 * round(H/640)` model, which
 * on a big high-DPI surface computes far too FEW visible rows — it asked for
 * ~2 s where the grid needed 3-5, so the leading edge stayed blank. It also had
 * no way to see the zoom at all: zooming out doubles the visible rows and thus
 * the look-ahead needed.
 *
 * Deliberately ignores the pinned header strip (a small slice of the surface is
 * not grid): counting it as grid over-estimates the future slightly, and
 * over-estimating look-ahead only costs a little latency, while
 * under-estimating is the visible bug. */
REWAMP_EXPORT double rewamp_patternviz_future_seconds(void) {
    const int H = rewamp_gl_height();
    if (H <= 0) return 0.0;
    const int ft2 = (g_pv_opt_palette == PV_PAL_FT2);
    float zoom = g_pv_opt_size;     if (zoom <= 0.0f) zoom = 1.0f;
    float dpr  = g_pv_opt_pixscale; if (dpr  <= 0.0f) dpr  = 1.0f;
    /* Same expression as pv_compute_metrics — keep the two in step. */
    float rowH = PV_BASE_ROW_PX * dpr * zoom * (ft2 ? 0.95f : 1.0f);
    const int fontH = ft2 ? PV_FT2_FONT_H : PV_FONT_H;
    if (rowH < (float)fontH) rowH = (float)fontH;
    /* Synth mode always centres the play bar, so half the surface is future. */
    const double futureRows = ((double)H / (double)rowH) * 0.5;
    return futureRows / PV_SYN_ROWS_PER_S;
}

static float*   g_pv_syn_hz    = NULL;
static uint8_t* g_pv_syn_vol   = NULL;
static uint8_t* g_pv_syn_instr = NULL;
static int64_t* g_pv_syn_pos   = NULL;

static int pv_tessellate_synth(int firstG, int nRows, int vc, double sr) {
    const PvMetrics* m = &g_pv_m;
    const PvPalette* pal = &g_pv_palettes[g_pv_opt_palette];
    const float rowH  = m->rowH;
    const int   nch   = vc < PV_MAXCH ? vc : PV_MAXCH;
    const float gutW  = m->gutW;
    const float cellW = m->cellW;
    const float rowW  = gutW + nch * cellW;
    const float sepS  = m->noteS;
    const int   maxv  = PV_MAX_QUADS * 6;

    if (!g_pv_verts) {
        g_pv_verts = (float*)malloc((size_t)PV_MAX_QUADS * 6 * PV_VFLOATS * sizeof(float));
        if (!g_pv_verts) return 0;
    }
    if (!g_pv_syn_hz) {
        g_pv_syn_hz    = (float*)  malloc((size_t)PV_SYN_COLS * PV_MAXCH * sizeof(float));
        g_pv_syn_vol   = (uint8_t*)malloc((size_t)PV_SYN_COLS * PV_MAXCH);
        g_pv_syn_instr = (uint8_t*)malloc((size_t)PV_SYN_COLS * PV_MAXCH);
        g_pv_syn_pos   = (int64_t*)malloc((size_t)PV_SYN_COLS * sizeof(int64_t));
        if (!g_pv_syn_hz || !g_pv_syn_vol || !g_pv_syn_instr || !g_pv_syn_pos) return 0;
    }
    if (firstG < 0) firstG = 0;
    if (nRows <= 0) return 0;

    const double rowSamples = sr / PV_SYN_ROWS_PER_S;
    const int ncols = rewamp_notes_collect(
        (int64_t)(firstG * rowSamples), (int64_t)((firstG + nRows) * rowSamples),
        g_pv_syn_hz, g_pv_syn_vol, g_pv_syn_instr, g_pv_syn_pos, PV_SYN_COLS);

    float* v = g_pv_verts;
    int nv = 0;

    /* Background: beat bands every 4/16 rows + inter-cell + closing separators. */
    for (int i = 0; i < nRows; i++) {
        int g = firstG + i;
        if (g % 4 == 0) {
            float y = i * rowH;
            nv = pv_push_solid(v, nv, maxv, 0, y, rowW, y + rowH, pal->beatBg, 1.0f);
            if (g % 16 == 0)
                nv = pv_push_solid(v, nv, maxv, 0, y, rowW, y + rowH, pal->beatBg, 1.0f);
        }
    }
    for (int ch = 1; ch <= nch; ch++)
        nv = pv_push_separator(v, nv, maxv, pal,
                               gutW + ch * cellW - m->sepShift, 0, nRows * rowH, sepS, sepS);
    int bgVerts = nv;

    /* Cell glyphs. A HELD note (no re-trigger) must NOT be reprinted on every
     * row — the synth timeline reports the sustained pitch continuously, but a
     * tracker only writes the trigger row. Same run rule as the notes
     * visualizer: a new note starts on a pitch step (>0.75 semitone from the
     * held bin), an instrument change, or a sharp volume rise (re-attack).
     *
     * CRITICAL: scan EVERY capture column inside the row span, not one sample
     * per row. Capture columns land every ~12 ms while a row spans 125 ms — a
     * note-off + re-attack at the SAME pitch entirely inside one row (SID
     * repeated notes) is invisible at row boundaries (same pitch, same instr,
     * volume back at the same level), which made the notes visualizer show
     * blocks this grid missed. Per-voice state advances per COLUMN; the first
     * trigger inside a row is what the row prints. */
    float heldBin[PV_MAXCH]; int heldInstr[PV_MAXCH], prevVol[PV_MAXCH], active[PV_MAXCH];
    for (int ch = 0; ch < nch; ch++) { active[ch] = 0; prevVol[ch] = 0; heldBin[ch] = 0; heldInstr[ch] = -1; }
    int col = 0;
    for (int i = 0; i < nRows; i++) {
        const int   g = firstG + i;
        const float y = i * rowH;
        const int64_t rowEnd = (int64_t)((g + 1) * rowSamples);
        char txt[8];
        float cr, cg, cb, ca;
        const float sy = y + m->subYoff;

        /* Walk all capture columns belonging to this row, updating per-voice
         * state and recording the first trigger per voice. */
        int   trig[PV_MAXCH];  int trigInstr[PV_MAXCH], trigVol[PV_MAXCH];
        float trigBin[PV_MAXCH];
        for (int ch = 0; ch < nch; ch++) trig[ch] = 0;
        for (; col < ncols && g_pv_syn_pos[col] < rowEnd; col++) {
            for (int ch = 0; ch < nch; ch++) {
                const float hz = g_pv_syn_hz[col * vc + ch];
                if (hz >= 1.0f) {
                    const int instr = g_pv_syn_instr[col * vc + ch];
                    const int vol   = g_pv_syn_vol[col * vc + ch];
                    const float raw = 12.0f * log2f(hz / 440.0f);
                    const int trigger = !active[ch]
                           || fabsf(raw - heldBin[ch]) > 0.75f   /* pitch step */
                           || instr != heldInstr[ch]             /* instrument change */
                           || vol > prevVol[ch] + 2;             /* re-attack (vol up) */
                    if (trigger) {
                        heldBin[ch] = roundf(raw); heldInstr[ch] = instr; active[ch] = 1;
                        if (!trig[ch]) {
                            trig[ch] = 1;
                            trigBin[ch] = heldBin[ch];
                            trigInstr[ch] = instr;
                            trigVol[ch] = vol;
                        }
                    }
                    prevVol[ch] = vol;
                } else {
                    active[ch] = 0; prevVol[ch] = 0;   /* note off releases the hold */
                }
            }
        }

        for (int ch = 0; ch < nch; ch++) {
            const float cx = gutW + ch * cellW;
            const int show = trig[ch];   /* print note/instr/vol only on the trigger row */

            char nt[4];
            if (show) {
                int semi = (int)roundf(trigBin[ch]) + 57;    /* A-4 = 57 */
                if (semi < 0) semi = 0;
                if (semi > 179) semi = 179;
                pv_note_text(semi, nt);
                pv_color(pal->note, 1.0f, &cr, &cg, &cb, &ca);
            } else {
                pv_note_text(REWAMP_NOTE_EMPTY, nt);
                pv_color(pal->noteEmpty, 1.0f, &cr, &cg, &cb, &ca);
            }
            nv = pv_push_text(v, nv, maxv, nt, cx + m->xNote, y, m->noteS, m->fontH, cr, cg, cb, ca);
            if (m->colMode >= 2) continue;   /* note only */

            int drawInstr = show ? trigInstr[ch] : -1;
            pv_hex2(drawInstr, txt);
            pv_color(drawInstr < 0 ? pal->noteEmpty : pal->instrument, 1.0f, &cr, &cg, &cb, &ca);
            nv = pv_push_text(v, nv, maxv, txt, cx + m->xInstr, sy, m->subS, m->fontH, cr, cg, cb, ca);
            if (m->colMode >= 1) continue;   /* note + instrument */

            int drawVol = show ? trigVol[ch] : -1;
            pv_hex2(drawVol, txt);
            pv_color(drawVol < 0 ? pal->noteEmpty : pal->volume, 1.0f, &cr, &cg, &cb, &ca);
            nv = pv_push_text(v, nv, maxv, txt, cx + m->xVol, sy, m->subS, m->fontH, cr, cg, cb, ca);

            /* No effect column at all here: a synthesized grid is built from the
             * note timeline (pitch / instrument / volume), so an fx field could
             * only ever be dots. It is dropped from the layout instead (see the
             * fx widths zeroed in the synth branch of the render), which buys
             * back ~3 characters of cell width per channel. */
        }
    }

    glBindBuffer(GL_ARRAY_BUFFER, g_pv_vbo);
    glBufferData(GL_ARRAY_BUFFER, (GLsizeiptr)(nv * PV_VFLOATS * sizeof(float)),
                 g_pv_verts, GL_STATIC_DRAW);

    g_pv_first_g   = firstG;
    g_pv_nrows     = nRows;
    g_pv_bg_verts  = bgVerts;
    g_pv_all_verts = nv;
    g_pv_tess_rowH = rowH;
    g_pv_tess_pal  = g_pv_opt_palette;
    g_pv_tess_scroll = g_pv_opt_scroll;
    g_pv_tess_cols   = m->colMode;
    g_pv_nch       = nch;
    g_pv_nch_data  = vc;
    g_pv_have      = 1;
    return 1;
}

/* ── GL init / render / uninit ───────────────────────────────────────────── */

/* Upload an R8 alpha atlas. LINEAR + the per-cell gutter → no neighbour bleed
 * and anti-aliased edges (see the atlas comment near PV_ATLAS_COLS). */
static void pv_upload_atlas(GLuint* tex, const unsigned char* px, int w, int h) {
    glGenTextures(1, tex);
    glBindTexture(GL_TEXTURE_2D, *tex);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, w, h, 0, GL_RED, GL_UNSIGNED_BYTE, px);
    /* Mipmaps: at small zoom the glyph is MINIFIED (a high-res 64px cell drawn
     * at ~17px), so trilinear averages the source instead of point-sampling it —
     * thin strokes keep their coverage rather than dropping out. The per-cell
     * gutter (≥ the coarsest useful mip footprint) keeps neighbours from
     * bleeding at these levels. MAG stays LINEAR for big zoom. */
    glGenerateMipmap(GL_TEXTURE_2D);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
}

/* Bake a 1-bit bitmap font (MSB = leftmost) into f: cw×fontH-texel cells, gutter
 * 1. Used for the FastTracker 2 font (and the unscii TTF fallback). */
static void pv_build_bitmap_font(PvFont* f, const unsigned char* font,
                                 int cw, int fontH) {
    f->cw = cw; f->ch = fontH; f->pad = 1;
    f->aw = PV_ATLAS_COLS * (cw + 2);
    f->ah = 6 * (fontH + 2);
    unsigned char* atlas = (unsigned char*)calloc((size_t)f->aw * f->ah, 1);
    if (!atlas) return;
    for (int gi = 0; gi <= PV_FONT_LAST - PV_FONT_FIRST; gi++) {
        int cx = (gi % PV_ATLAS_COLS) * (cw + 2) + 1;
        int cy = (gi / PV_ATLAS_COLS) * (fontH + 2) + 1;
        for (int ry = 0; ry < fontH; ry++) {
            unsigned char bits = font[gi * fontH + ry];
            for (int rx = 0; rx < cw; rx++)
                if (bits & (0x80 >> rx))
                    atlas[(cy + ry) * f->aw + cx + rx] = 0xFF;
        }
    }
    pv_upload_atlas(&f->tex, atlas, f->aw, f->ah);
    free(atlas);
}

/* Bake a monospace TTF (ttf) into f with cellW×cellH-texel cells via
 * stb_truetype, baseline-aligned; cellH is the DISPLAY glyph height so glyphs
 * are rasterized at (near) 1:1 — crisp, not up/down-scaled. fitX (<1) shrinks
 * the horizontal fit a touch so wide glyphs don't clip the cell. Returns 0 on
 * success (f->tex bound), non-0 if the font failed to parse. */
static int pv_bake_ttf(PvFont* f, const unsigned char* ttf,
                       int cellH, int cellW, float fitX) {
    int th = cellH, tw = cellW;
    if (th < 8) th = 8;
    if (tw < 4) tw = 4;
    stbtt_fontinfo font;
    if (!stbtt_InitFont(&font, ttf, stbtt_GetFontOffsetForIndex(ttf, 0)))
        return -1;
    f->cw = tw; f->ch = th; f->pad = PV_TTF_PAD;
    f->aw = PV_ATLAS_COLS * (tw + 2 * PV_TTF_PAD);
    f->ah = 6 * (th + 2 * PV_TTF_PAD);
    unsigned char* atlas = (unsigned char*)calloc((size_t)f->aw * f->ah, 1);
    if (!atlas) return -2;

    int ascent, descent, lineGap;
    stbtt_GetFontVMetrics(&font, &ascent, &descent, &lineGap);
    float sy = (float)(th - 2) / (float)(ascent - descent);        /* em → cell */
    int adv, lsb;
    stbtt_GetCodepointHMetrics(&font, 'M', &adv, &lsb);            /* mono advance */
    float sx = adv > 0 ? (float)tw / (float)adv * fitX : sy;      /* fit advance */
    int baseline = (int)(ascent * sy) + 1;
    for (int gi = 0; gi <= PV_FONT_LAST - PV_FONT_FIRST; gi++) {
        int ch = PV_FONT_FIRST + gi;
        int cx = (gi % PV_ATLAS_COLS) * (tw + 2 * PV_TTF_PAD) + PV_TTF_PAD;
        int cy = (gi / PV_ATLAS_COLS) * (th + 2 * PV_TTF_PAD) + PV_TTF_PAD;
        int gw = 0, gh = 0, ox = 0, oy = 0;
        unsigned char* bmp = stbtt_GetCodepointBitmapSubpixel(
            &font, sx, sy, 0.0f, 0.0f, ch, &gw, &gh, &ox, &oy);
        if (!bmp) continue;
        int px0 = (tw - gw) / 2; if (px0 < 0) px0 = 0;         /* centre in cell */
        int py0 = baseline + oy;                               /* on the baseline */
        for (int ry = 0; ry < gh; ry++) {
            int ay = py0 + ry;
            if (ay < 0 || ay >= th) continue;
            for (int rx = 0; rx < gw; rx++) {
                int ax = px0 + rx;
                if (ax < 0 || ax >= tw) continue;
                atlas[(cy + ay) * f->aw + (cx + ax)] = bmp[ry * gw + rx];
            }
        }
        stbtt_FreeBitmap(bmp, NULL);
    }
    pv_upload_atlas(&f->tex, atlas, f->aw, f->ah);
    free(atlas);
    return 0;
}

/* Default font (JetBrains Mono, all non-FT2 palettes): 8×16 layout aspect. */
static void pv_build_ttf_font(PvFont* f, int cellH) {
    if (pv_bake_ttf(f, g_pv_ttf_data, cellH, cellH / 2, 1.0f) != 0)
        pv_build_bitmap_font(f, &g_pv_font[0][0], PV_FONT_W, PV_FONT_H);
}

/* FastTracker 2 palette (Font1 Bitmap): 8×10 layout aspect (cellW = cellH×8/10);
 * fitX 0.92 so the wide 'M' etc. don't clip. Falls back to the FT2 bitmap. */
static void pv_build_ft2_font(PvFont* f, int cellH) {
    if (pv_bake_ttf(f, g_pv_ft2ttf_data, cellH,
                    (cellH * PV_FONT_W) / PV_FT2_FONT_H, 0.92f) != 0)
        pv_build_bitmap_font(f, &g_pv_ft2_font[0][0], PV_FONT_W, PV_FT2_FONT_H);
}

static void pv_setup_vao(GLuint vao, GLuint vbo, GLsizeiptr size) {
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, size, NULL, GL_DYNAMIC_DRAW);
    const GLsizei stride = PV_VFLOATS * sizeof(GLfloat);
    GLint aPos = glGetAttribLocation(g_pv_prog, "aPos");
    GLint aUV  = glGetAttribLocation(g_pv_prog, "aUV");
    GLint aCol = glGetAttribLocation(g_pv_prog, "aCol");
    glEnableVertexAttribArray(aPos);
    glVertexAttribPointer(aPos, 2, GL_FLOAT, GL_FALSE, stride, (void*)0);
    glEnableVertexAttribArray(aUV);
    glVertexAttribPointer(aUV,  2, GL_FLOAT, GL_FALSE, stride, (void*)(2*sizeof(GLfloat)));
    glEnableVertexAttribArray(aCol);
    glVertexAttribPointer(aCol, 4, GL_FLOAT, GL_FALSE, stride, (void*)(4*sizeof(GLfloat)));
    glBindVertexArray(0);
}

REWAMP_EXPORT int rewamp_patternviz_init(int width, int height) {
    {
        int err = rewamp_gl_ensure(width, height);
        if (err != 0) return err;
    }
    if (g_pv_prog && g_pv_gen == rewamp_gl_generation()) return 0;
    g_pv_prog = 0;
    g_pv_have = 0;   /* VBO contents died with the old context */

    static const char* k_vert =
        /* The shared preamble declares mediump — a HALF float on Adreno/Mali,
         * whose step reaches 1 unit around 2048, while everything here is a
         * screen PIXEL coordinate and a wide grid scrolls well past that. Same
         * rule as the spectrum Line shader: a shader handling unbounded
         * magnitudes states its precision. */
        "precision highp float;\n"
        "in vec2 aPos;\n"
        "in vec2 aUV;\n"
        "in vec4 aCol;\n"
        "uniform vec2 uView;\n"    /* surface w,h px */
        "uniform vec2 uOff;\n"     /* window-local px → screen px offset */
        "out vec2 vUV;\n"
        "out vec4 vC;\n"
        "out float vYpx;\n"
        "void main() {\n"
        "  vec2 p = aPos + uOff;\n"
        "  vYpx = p.y;\n"
        "  float x = p.x / uView.x * 2.0 - 1.0;\n"
#if REWAMP_GL_Y_FLIPPED
        "  float y = p.y / uView.y * 2.0 - 1.0;\n"  /* macOS: texture Y-flipped */
#else
        "  float y = 1.0 - p.y / uView.y * 2.0;\n"  /* screen-top = +1 (Android, iOS) */
#endif
        "  gl_Position = vec4(x, y, 0.0, 1.0);\n"
        "  vUV = aUV; vC = aCol;\n"
        "}\n";
    static const char* k_frag =
        /* vYpx is a screen-pixel y compared against the current-row band —
         * same precision argument as the vertex stage above. */
        "precision highp float;\n"
        "in vec2 vUV;\n"
        "in vec4 vC;\n"
        "in float vYpx;\n"
        "uniform sampler2D uTex;\n"
        "uniform vec4 uOvr;\n"     /* rgb + enable: current-row text override */
        "uniform vec2 uOvrY;\n"    /* screen-px y range of the current row */
        "out vec4 fragColor;\n"
        "void main() {\n"
        "  vec4 c = vC;\n"
        "  if (uOvr.a > 0.5 && vYpx >= uOvrY.x && vYpx < uOvrY.y) c.rgb = uOvr.rgb;\n"
        /* Plain (mip-)linear sample: the atlas is a HIGH-RES TTF bake, so
         * minification (small zoom) is a proper mipmapped downsample — thin
         * strokes like '-' keep their coverage instead of undersampling to
         * nothing — and magnification stays smooth. The old sharp-bilinear trick
         * was for the low-res 1-bit bitmap and actively thinned strokes here. */
        "  float a = (vUV.x < 0.0) ? 1.0 : texture(uTex, vUV).r;\n"
        "  fragColor = vec4(c.rgb, c.a * a);\n"
        "}\n";
    GLuint vert = compile_shader(GL_VERTEX_SHADER,   k_gl_preamble, k_vert);
    GLuint frag = compile_shader(GL_FRAGMENT_SHADER, k_gl_preamble, k_frag);
    if (!vert || !frag) return -10;
    g_pv_prog = link_program(vert, frag);
    glDeleteShader(vert); glDeleteShader(frag);
    if (!g_pv_prog) return -11;
    g_pv_uOff  = glGetUniformLocation(g_pv_prog, "uOff");
    g_pv_uView = glGetUniformLocation(g_pv_prog, "uView");
    g_pv_uTex  = glGetUniformLocation(g_pv_prog, "uTex");
    g_pv_uOvr  = glGetUniformLocation(g_pv_prog, "uOvr");
    g_pv_uOvrY = glGetUniformLocation(g_pv_prog, "uOvrY");

    /* Glyph atlases: both TTF-baked (default = JetBrains Mono, FT2 palette =
     * Font1 Bitmap), at a placeholder size; the first pv_compute_metrics for the
     * active palette rebakes it to the real display size. */
    pv_build_ttf_font(&g_font_ttf, 48);
    g_ttf_baked_h = 48;
    pv_build_ft2_font(&g_font_ft2, 48);
    g_ft2_baked_h = 48;

    glGenVertexArrays(1, &g_pv_vao);
    glGenBuffers(1, &g_pv_vbo);
    pv_setup_vao(g_pv_vao, g_pv_vbo, 0);
    glGenVertexArrays(1, &g_pv_dvao);
    glGenBuffers(1, &g_pv_dvbo);
    pv_setup_vao(g_pv_dvao, g_pv_dvbo,
                 (GLsizeiptr)PV_DYN_QUADS * 6 * PV_VFLOATS * sizeof(float));

    g_pv_gen = rewamp_gl_generation();
    return 0;
}

/* Upload + draw the current dynamic buffer (dn vertices), pinned (uOff=0). */
static void pv_flush_dynamic(int dn) {
    if (dn <= 0) return;
    glBindVertexArray(g_pv_dvao);
    glBindBuffer(GL_ARRAY_BUFFER, g_pv_dvbo);
    glBufferData(GL_ARRAY_BUFFER, (GLsizeiptr)PV_DYN_QUADS * 6 * PV_VFLOATS * sizeof(float),
                 NULL, GL_DYNAMIC_DRAW);   /* orphan: tiler-safe */
    glBufferSubData(GL_ARRAY_BUFFER, 0, (GLsizeiptr)(dn * PV_VFLOATS * sizeof(float)),
                    g_pv_dverts);
    glUniform2f(g_pv_uOff, 0, 0);
    glDrawArrays(GL_TRIANGLES, 0, dn);
}

REWAMP_EXPORT void rewamp_patternviz_render(void) {
    rewamp_gl_make_current();

    const int W = rewamp_gl_width(), H = rewamp_gl_height();
    glBindFramebuffer(GL_FRAMEBUFFER, rewamp_gl_get_fbo());
    glViewport(0, 0, W, H);

    const PvPalette* pal = &g_pv_palettes[g_pv_opt_palette];
    float br, bg_, bb, ba; pv_color(pal->bg, 1.0f, &br, &bg_, &bb, &ba);
    // Opaque mode: the palette's own background at FULL alpha (every palette's
    // bg is black or near-black), so nothing shows through — neither the
    // artwork below nor, on the Apple texture path, the black backdrop Flutter
    // composites under a translucent texture.
    if (g_pv_opt_opaque_bg) ba = 1.0f;
    glClearColor(br * ba, bg_ * ba, bb * ba, ba);
    glClear(GL_COLOR_BUFFER_BIT);

    /* Current-row inverse video: a solid, STYLE-coloured bar (the palette's own
     * highlight hue forced opaque) with every info glyph (row number, note,
     * instrument, volume, fx) recoloured to CONTRAST it — dark on a bright bar,
     * light on a dark one, chosen from the bar's luminance so each palette stays
     * readable. This replaces the per-palette currentRowText override. */
    const unsigned pv_barRGB = pal->highlight & 0xFFFFFFu;
    const unsigned pv_barCol = pv_barRGB | 0xF2000000u;   /* ~95% opaque style bar */
    const float    pv_barLum = (0.299f * ((pv_barRGB >> 16) & 0xFF)
                              + 0.587f * ((pv_barRGB >>  8) & 0xFF)
                              + 0.114f * ( pv_barRGB        & 0xFF)) / 255.0f;
    const unsigned pv_ovrCol = (pv_barLum > 0.55f) ? 0xFF0A0A0Fu : 0xFFF2F4F8u;
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    /* Artwork background on ALL platforms (blended over the palette bg just
     * cleared) — this was Android-only, so iOS/macOS showed no artwork behind
     * the pattern while every other visualizer drew it. */
    // Opaque mode: skip the artwork entirely. The clear above already wrote
    // black; alpha 1 makes it opaque on the Apple texture path too (Android's
    // SurfaceView is opaque anyway).
    if (!g_pv_opt_opaque_bg) {
        art_upload_if_dirty();
        art_render(W, H);
    }

    int order = -1, row = -1;
    unsigned songGen = rewamp_pattern_song_generation();
    const int supported = rewamp_pattern_supported();
    int synth = 0, synVc = 0, gcur = -1;
    double synSr = 44100.0;
    float pv_frac = 0.0f;   /* sub-row progress [0,1) for smooth scrolling */

    if (supported) {
        int haveCursor = rewamp_pattern_cursor_frac(&order, &row, &pv_frac);
        if (!pv_refresh_orders() || !haveCursor ||
            order < 0 || order >= g_pv_norders) {
#ifdef __ANDROID__
            rewamp_gl_force_opaque();
#endif
            rewamp_gl_flush();
            return;
        }
        /* Effective row counts can be shorter than the engine's nominal ones
         * (furnace jump effects) — clamp so gcur stays inside this order. */
        { int rowsCur = g_pv_pre[order + 1] - g_pv_pre[order];
          if (rowsCur > 0 && row >= rowsCur) row = rowsCur - 1; }
        gcur = g_pv_pre[order] + row;
    } else {
        /* Synthesized rows from the note timeline (any chip backend). */
        synVc = rewamp_notes_voice_count();
        if (synVc <= 0) {
#ifdef __ANDROID__
            rewamp_gl_force_opaque();
#endif
            rewamp_gl_flush();
            return;
        }
        synth = 1;
        synSr = rewamp_notes_rate();
        if (synSr <= 0) synSr = 44100.0;
        /* Same smoothed clock as the tracker path above. */
        double played = rewamp_notes_played_smooth();
        double gcurF = played / (synSr / PV_SYN_ROWS_PER_S);
        gcur = (int)gcurF;
        if (gcur < 0) { gcur = 0; pv_frac = 0.0f; }
        else pv_frac = (float)(gcurF - (double)gcur);   /* already continuous — keep the fraction */
        g_pv_nch = synVc < PV_MAXCH ? synVc : PV_MAXCH;   /* layout below */
        /* Synthesized rows carry plain byte-sized instrument/volume, and this
         * path never calls pv_refresh_orders — so reset the per-song field
         * widths, or a wide song (SunVox) would leave its 4-digit layout
         * behind and the synthesized grid would draw over-wide empty cells. */
        g_pv_instr_digits = 2;
        g_pv_vol_chars    = 2;
        /* No effect column: the rows are built from the note timeline (pitch,
         * instrument, volume) and nothing else, so the field could only ever
         * hold dots. 0 = ABSENT — it takes neither its width nor its gap. */
        g_pv_fxcode_chars = 0;
        g_pv_fxval_digits = 0;
    }

    /* Per-font metrics: note glyph sized to a consistent row height; FT2 shrinks
     * the sub-fields and enlarges the channel numbers. */
    pv_compute_metrics(H);
    const PvMetrics* m = &g_pv_m;
    const float rowH    = m->rowH;
    /* A style may PIN the bar (ProTracker): the page scrolls, the line never
     * does. Decided here, before the tessellation key below reads `moving`, so
     * switching to that palette re-tessellates like any other mode change. The
     * matching toggle is hidden in the UI rather than left dead. */
    const int   moving  = pal->forceFixedBar ? 0 : g_pv_opt_scroll;
    const float headerH = m->headerH;
    const float gutW  = m->gutW;
    const float cellW = m->cellW;
    const float rowW  = gutW + g_pv_nch * cellW;
    float xOff = (rowW <= (float)W) ? 0.0f : -g_pv_opt_xscroll;
    if (xOff < (float)W - rowW) xOff = (float)W - rowW;
    if (xOff > 0) xOff = 0;

    /* (Re-)tessellate when the song/options/size changed or the cursor neared
     * the window edge (only where more rows exist beyond it — the ends of the
     * song clamp). Everything else is a cached static draw. Synth mode
     * re-tessellates on every row advance (8 Hz, a few-thousand quads) — also
     * how freshly-decoded look-ahead rows appear. */
    static int g_pv_tess_synth = 0;
    int stale = !g_pv_have
        || g_pv_gen != rewamp_gl_generation()
        || songGen != g_pv_song_gen
        || g_pv_tess_pal != g_pv_opt_palette
        || g_pv_tess_scroll != moving
        || g_pv_tess_cols != m->colMode
        || g_pv_tess_rowH != rowH
        || g_pv_tess_synth != synth
        /* tracker: the 0.32 dim of adjacent orders is BAKED relative to the
         * order current at tessellation time — crossing into the next pattern
         * must re-bake so the focus follows. synth: tess_order carries the
         * anchor row instead → re-bake per row. */
        || g_pv_tess_order != (synth ? gcur : order);
    int nearEdge = 0;
    if (!stale && !synth) {
        if (gcur < g_pv_first_g || gcur >= g_pv_first_g + g_pv_nrows)
            nearEdge = 1;                                   /* seek jumped out */
        else {
            if (gcur < g_pv_first_g + PV_WIN_EDGE && g_pv_first_g > 0)
                nearEdge = 1;
            if (gcur >= g_pv_first_g + g_pv_nrows - PV_WIN_EDGE &&
                g_pv_first_g + g_pv_nrows < g_pv_total_rows)
                nearEdge = 1;
        }
    }
    if (stale || nearEdge) {
        if (g_pv_gen != rewamp_gl_generation()) {
            int err = rewamp_patternviz_init(W, H);
            if (err != 0) { rewamp_gl_flush(); return; }
        }
        g_pv_song_gen = songGen;
        int tessOk;
        if (synth) {
            int visible = (int)(((float)H - headerH) / rowH); if (visible < 1) visible = 1;
            int nRows = visible + 12;
            int first = gcur - nRows / 2; if (first < 0) first = 0;
            tessOk = pv_tessellate_synth(first, nRows, synVc, synSr);
            g_pv_tess_order = gcur;
        } else {
            int first = gcur - PV_WIN_ROWS / 2;
            if (first < 0) first = 0;
            tessOk = pv_tessellate(first, order);
        }
        g_pv_tess_synth = synth;
        if (!tessOk) {
#ifdef __ANDROID__
            rewamp_gl_force_opaque();
#endif
            rewamp_gl_flush();
            return;
        }
    }

    if (!g_pv_opt_smooth) pv_frac = 0.0f;   /* toggle off → snap per row */

    /* Vertical placement (screen px of the current row's top edge). Synth mode
     * has no patterns to page-anchor → always the centered fixed bar. */
    const float gridTop = headerH;
    float barY;
    if (!moving || synth) {
        barY = gridTop + ((float)H - gridTop) * 0.5f - rowH * 0.5f;   /* centered */
    } else {
        /* Moving bar. The page anchor is CONTINUOUS - it used to be an integer
         * row, and that is what made the bottom of a pattern judder: while the
         * bar walks down the page nothing moves (good), but once it reaches the
         * last visible line the page has to scroll, and an integer anchor
         * scrolls it a WHOLE ROW at a time while the bar sits pinned at the
         * bottom. One jump per row, which reads as the bar being stuck and the
         * grid stepping.
         *
         * Written as a clamp on the continuous position, the three regimes fall
         * out of one line: at the top of a pattern the clamp holds the anchor at
         * 0, so the bar glides and the page is still; in the middle the anchor
         * follows row+frac, so the bar is pinned and the page glides; at the end
         * it holds at maxStart and the bar glides again to the last row. */
        const int patRows = g_pv_pre[order + 1] - g_pv_pre[order];
        int visible = (int)(((float)H - gridTop) / rowH); if (visible < 1) visible = 1;
        float maxStart = (float)(patRows - visible); if (maxStart < 0.0f) maxStart = 0.0f;
        const float pos = (float)row + pv_frac;
        float startF = pos - (float)(visible - 1);
        if (startF < 0.0f)      startF = 0.0f;
        if (startF > maxStart)  startF = maxStart;
        barY = gridTop + (pos - startF) * rowH;
    }
    /* Window-local px → screen px. In the fixed-bar case barY is constant, so
     * the +pv_frac here scrolls the whole grid smoothly under the centered bar;
     * in the moving-bar case the frac in barY above cancels it (static page). */
    const float yOff = barY - ((float)(gcur - g_pv_first_g) + pv_frac) * rowH;

    glUseProgram(g_pv_prog);
    glUniform2f(g_pv_uView, (float)W, (float)H);
    glUniform1i(g_pv_uTex, 0);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, m->tex);
    glUniform4f(g_pv_uOvr, 0, 0, 0, 0);
    glUniform2f(g_pv_uOvrY, 0, 0);

    /* Bevel band thickness: 3 LOGICAL px, so it stays 3 px on screen whatever
     * the surface density (Android renders at physical resolution). Never more
     * than a third of the row, or the bar would be all edge and no face. */
    const float pv_bevel = fminf(3.0f * g_pv_opt_pixscale, rowH / 3.0f);

    if (!g_pv_dverts)
        g_pv_dverts = (float*)malloc((size_t)PV_DYN_QUADS * 6 * PV_VFLOATS * sizeof(float));
    const int dmax = PV_DYN_QUADS * 6;
    int dn;

    /* 1) static background (beat bands + inter-cell/closing separators) */
    glBindVertexArray(g_pv_vao);
    glUniform2f(g_pv_uOff, xOff, yOff);
    if (g_pv_bg_verts > 0) glDrawArrays(GL_TRIANGLES, 0, g_pv_bg_verts);

    /* 2) dynamic layer: current-row bar over the cells (under the text). A steady
     * opaque bar (no pulse — that strobed when scrolling fast); the current row's
     * glyphs are recoloured to a DARK inverse in step 3, so the row reads as
     * inverse-video (dark text on the bright bar) as it crosses. */
    if (g_pv_dverts) {
        /* Left edge: owned by the gutter slice redrawn in step 6, which masks
         * this one there. Right edge: the end of the last column. */
        dn = pv_push_bar(g_pv_dverts, 0, dmax,
                         xOff, barY, xOff + rowW, barY + rowH,
                         pv_barCol, pv_bevel, pal->barBevel,
                         /*leftEdge*/0, /*rightEdge*/1);
        pv_flush_dynamic(dn);
    }

    /* 3) static cell glyphs, with the inverse-video current-row override
     * (contrast colour over the style bar, band-locked at the playhead). */
    glBindVertexArray(g_pv_vao);
    glUniform2f(g_pv_uOff, xOff, yOff);
    {
        float orr, org, orb, ora;
        pv_color(pv_ovrCol, 1.0f, &orr, &org, &orb, &ora);
        glUniform4f(g_pv_uOvr, orr, org, orb, 1.0f);
        glUniform2f(g_pv_uOvrY, barY, barY + rowH);
    }
    if (g_pv_all_verts > g_pv_bg_verts)
        glDrawArrays(GL_TRIANGLES, g_pv_bg_verts, g_pv_all_verts - g_pv_bg_verts);
    glUniform4f(g_pv_uOvr, 0, 0, 0, 0);

    /* 4) live per-channel VU meters (over the grid, like the Dart layer) — a
     * bar centered in each column, level from the consumer-side channel volume
     * (openmpt VU*255). Dynamic: a handful of quads per frame.
     *
     * The base is normally the bottom of the window; a style may instead stand
     * the meters ON the current-row bar (ProTracker), i.e. grow upward from its
     * TOP edge. Their height is then clamped to what is actually above the bar,
     * or a tall meter would climb behind the header. */
    if (g_pv_opt_vu && g_pv_dverts) {
        dn = 0;
        const int   seg   = (pal->volStyle == PV_VOL_SEGMENTED);
        const float vuBase = pal->vuOnBar ? barY : (float)H;
        float maxH  = seg
            ? fminf((float)H * 0.36f, 85.0f * m->noteS)
            : fminf((float)H * 0.50f, 56.0f * m->noteS);
        if (pal->vuOnBar) {
            const float room = vuBase - gridTop;
            if (maxH > room) maxH = room;
        }
        if (maxH < 1.0f) maxH = 1.0f;
        const float barW  = pal->volBarWidthPx * m->noteS;
        const float zoneTop = vuBase - maxH;
        /* Centre between the SEPARATORS, not on the cell origin — same
         * correction the header's channel numbers already carry. Separators are
         * drawn sepShift left of the cell origin, so a column's visual span is
         * [x - sepShift + sepW, x + cellW - sepShift]; centring on [x, x+cellW]
         * put every meter visibly right of its column. */
        const float sepW = fmaxf(pal->sepWidthPx * m->noteS, 1.0f);
        for (int ch = 0; ch < g_pv_nch; ch++) {
            const float cx = xOff + gutW + ch * cellW
                             - m->sepShift + sepW * 0.5f + cellW * 0.5f;
            if (cx + barW < 0 || cx - barW > (float)W) continue;
            const float left = cx - barW * 0.5f;
            float norm = rewamp_channel_volume(ch) / 255.0f;
            if (norm < 0) norm = 0; if (norm > 1) norm = 1;
            /* Segmented meters use their black gaps as the "track" — no base. */
            if (!seg)
                dn = pv_push_solid(g_pv_dverts, dn, dmax, left, zoneTop,
                                   left + barW, vuBase,
                                   (pal->volBar & 0xFFFFFF) | 0x29000000, 1.0f);
            const float h = norm * maxH;
            if (h <= 0.5f) continue;
            switch (pal->volStyle) {
                case PV_VOL_SEGMENTED: {
                    /* 20 stacked blocks, ~78% filled, bottom ¾ low / top ¼ high. */
                    const int   nBlocks = 20;
                    const float slot  = maxH / nBlocks;
                    const float fillH = slot * 0.78f;
                    const int   lit   = (int)(norm * nBlocks + 0.5f);
                    for (int b = 0; b < lit; b++) {
                        float by = vuBase - b * slot - fillH;
                        unsigned col = ((float)b / nBlocks < 0.75f) ? pal->volLow
                                                                    : pal->volHigh;
                        dn = pv_push_solid(g_pv_dverts, dn, dmax,
                                           left, by, left + barW, by + fillH,
                                           col, 1.0f);
                    }
                    break;
                }
                case PV_VOL_GRADIENT: {
                    /* Gradient FIXED to Y (same color at a given height): split
                     * the bar at the zone midpoint so the 3-stop ramp keeps its
                     * middle color exactly there. */
                    float mr, mg, mb, tr, tg, tb;
                    const float tTop = h / maxH;         /* bar top, zone frac */
                    pv_grad_at(pal->volGrad, tTop, &tr, &tg, &tb);
                    if (tTop <= 0.5f) {
                        float br2, bg2, bb2;
                        pv_grad_at(pal->volGrad, 0.0f, &br2, &bg2, &bb2);
                        dn = pv_push_grad_quad(g_pv_dverts, dn, dmax,
                                               left, vuBase - h, left + barW, vuBase,
                                               tr, tg, tb, 1.0f, br2, bg2, bb2, 1.0f);
                    } else {
                        float br2, bg2, bb2;
                        pv_grad_at(pal->volGrad, 0.5f, &mr, &mg, &mb);
                        pv_grad_at(pal->volGrad, 0.0f, &br2, &bg2, &bb2);
                        const float midY = vuBase - maxH * 0.5f;
                        dn = pv_push_grad_quad(g_pv_dverts, dn, dmax,
                                               left, vuBase - h, left + barW, midY,
                                               tr, tg, tb, 1.0f, mr, mg, mb, 1.0f);
                        dn = pv_push_grad_quad(g_pv_dverts, dn, dmax,
                                               left, midY, left + barW, vuBase,
                                               mr, mg, mb, 1.0f, br2, bg2, bb2, 1.0f);
                    }
                    break;
                }
                default:
                    dn = pv_push_solid(g_pv_dverts, dn, dmax,
                                       left, vuBase - h, left + barW, vuBase,
                                       pal->volBar, 1.0f);
            }
        }
        pv_flush_dynamic(dn);
    }

    /* 5) header: opaque strip pinned on top (or FT2 corner numbers), channel
     * numbers drawn ~28% bigger than the cell font. Scrolls with the columns. */
    if (g_pv_dverts) {
        dn = 0;
        char num[8];
        float hr, hg, hb, ha;
        const float numW = PV_FONT_W * m->numS;
        if (!pal->cornerHeader) {
            dn = pv_push_solid(g_pv_dverts, dn, dmax, 0, 0, (float)W, headerH,
                               pal->headerBg, 1.0f);
            dn = pv_push_solid(g_pv_dverts, dn, dmax, 0, headerH - m->noteS, (float)W, headerH,
                               pal->separator, 1.0f);
            pv_color(pal->headerText, 1.0f, &hr, &hg, &hb, &ha);
            /* Center between the SEPARATORS: they are drawn sepShift left of
             * the cell origin, so the column's visual span is
             * [x - sepShift + sepW, x + cellW - sepShift] — centering on
             * [x, x+cellW] (the old math) sat the number visibly right. */
            const float sepW = fmaxf(pal->sepWidthPx * m->noteS, 1.0f);
            for (int ch = 0; ch < g_pv_nch; ch++) {
                float x = xOff + gutW + ch * cellW;
                if (x > (float)W || x + cellW < 0) continue;
                dn = pv_push_separator(g_pv_dverts, dn, dmax, pal,
                                       x - m->sepShift, 0, headerH, m->noteS, m->noteS);
                snprintf(num, sizeof num, "%d", ch + 1);
                float tw = (float)strlen(num) * numW;
                dn = pv_push_text(g_pv_dverts, dn, dmax, num,
                                  x - m->sepShift + sepW * 0.5f + (cellW - tw) * 0.5f,
                                  2.0f, m->numS, m->fontH, hr, hg, hb, ha);
            }
            /* close the last column's header separator */
            {
                float x = xOff + gutW + g_pv_nch * cellW;
                if (x <= (float)W && x + m->noteS >= 0)
                    dn = pv_push_separator(g_pv_dverts, dn, dmax, pal,
                                           x - m->sepShift, 0, headerH, m->noteS, m->noteS);
            }
        } else {
            /* FastTracker II: big number overlaid top-left per column, with a
             * 1px dark drop shadow for legibility. */
            pv_color(pal->headerText, 1.0f, &hr, &hg, &hb, &ha);
            for (int ch = 0; ch < g_pv_nch; ch++) {
                float x = xOff + gutW + ch * cellW - m->sepShift + 2.0f * m->numS;
                /* Channel 0's left neighbour is the row-number gutter, whose
                 * separator is pinned at gutW (not sepShifted like the inter-
                 * cell ones) — the -sepShift nudge would push the "1" onto that
                 * line. Clamp so its indent past the gutter matches the other
                 * columns' indent past their own separator (+2·numS). */
                if (ch == 0) {
                    const float minX = xOff + gutW + 2.0f * m->numS;
                    if (x < minX) x = minX;
                }
                if (x > (float)W || x + cellW < 0) continue;
                snprintf(num, sizeof num, "%d", ch + 1);
                dn = pv_push_text(g_pv_dverts, dn, dmax, num, x + m->numS, 2.0f * m->numS + m->numS,
                                  m->numS, m->fontH, 0, 0, 0, 0.9f);
                dn = pv_push_text(g_pv_dverts, dn, dmax, num, x, 2.0f * m->numS,
                                  m->numS, m->fontH, hr, hg, hb, ha);
            }
        }
        pv_flush_dynamic(dn);
    }

    /* 6) pinned row-number gutter (LAST, full height, fixed x): opaque strip +
     * per-visible-row beat band + current-row highlight + row numbers + the
     * gutter separator. Masks any columns scrolled under it. */
    if (g_pv_dverts) {
        dn = 0;
        dn = pv_push_solid(g_pv_dverts, dn, dmax, 0, 0, gutW, (float)H, pal->bg, 1.0f);
        float nr, ng, nb, na, br2, bg2, bb2, ba2;
        float cur_r = 0, cur_g = 0, cur_b = 0, cur_a = 0;
        pv_color(pal->rowNum, 1.0f, &nr, &ng, &nb, &na);
        pv_color(pal->beatRowNum, 1.0f, &br2, &bg2, &bb2, &ba2);
        int haveCur = 1;   /* inverse-video override is always applied now */
        pv_color(pv_ovrCol, 1.0f, &cur_r, &cur_g, &cur_b, &cur_a);
        const float rownumX = 0.5f * m->noteW;
        for (int i = 0; i < g_pv_nrows; i++) {
            const int g = g_pv_first_g + i;
            const float y = yOff + i * rowH;
            if (y + rowH < gridTop || y > (float)H) continue;
            int r, o = order;
            if (synth) { r = g & 0xFF; }
            else {
                if (!pv_locate(g, &o, &r)) continue;
                if (moving && o != order) continue;
            }
            const int beat = (synth ? (g % 4 == 0) : (r % 4 == 0));
            if (beat) dn = pv_push_solid(g_pv_dverts, dn, dmax, 0, y, gutW, y + rowH,
                                         pal->beatBg, 1.0f);
            const int isCur = (g == gcur);
            /* The gutter is drawn LAST and masks the main current-row bar over
             * its area, so it must redraw the highlight at the SAME place as that
             * bar — barY (fixed center in the smooth-scroll case), not the row's
             * scrolled position y, or the gutter slice of the bar drifts while
             * the rest stays put. */
            if (isCur) dn = pv_push_bar(g_pv_dverts, dn, dmax, 0, barY, gutW, barY + rowH,
                                        pv_barCol, pv_bevel, pal->barBevel,
                                        /*leftEdge*/1, /*rightEdge*/0);
            /* ...and recolour the row NUMBER that is physically AT the bar band
             * (this row's center falls inside it), NOT g==gcur whose glyph sits
             * at the scrolled position y (= barY - frac*rowH): the channel cells
             * are recoloured by the fixed-band shader override at barY, so the
             * gutter must light the same row or the number drifts frac*rowH off
             * the notes. Exactly one row center lands in the rowH-tall band. */
            const float rowMid = y + rowH * 0.5f;
            const int atBar = (rowMid >= barY && rowMid < barY + rowH);
            char txt[3]; pv_hex2(r, txt);
            float tr, tg, tb, ta;
            if (atBar && haveCur)  { tr = cur_r; tg = cur_g; tb = cur_b; ta = cur_a; }
            else if (beat)        { tr = br2;   tg = bg2;   tb = bb2;   ta = ba2; }
            else                  { tr = nr;    tg = ng;    tb = nb;    ta = na; }
            dn = pv_push_text(g_pv_dverts, dn, dmax, txt, rownumX, y, m->noteS, m->fontH,
                              tr, tg, tb, ta);
        }
        /* gutter separator (fixed, full height) */
        dn = pv_push_separator(g_pv_dverts, dn, dmax, pal, gutW, 0, (float)H, m->noteS, m->noteS);
        pv_flush_dynamic(dn);
    }

    glBindVertexArray(0);
#ifdef __ANDROID__
    rewamp_gl_force_opaque();
#endif
    rewamp_gl_flush();
}

REWAMP_EXPORT void rewamp_patternviz_uninit(void) {
    if (g_pv_prog) { glDeleteProgram(g_pv_prog);          g_pv_prog = 0; }
    if (g_pv_vbo)  { glDeleteBuffers(1, &g_pv_vbo);       g_pv_vbo  = 0; }
    if (g_pv_vao)  { glDeleteVertexArrays(1, &g_pv_vao);  g_pv_vao  = 0; }
    if (g_pv_dvbo) { glDeleteBuffers(1, &g_pv_dvbo);      g_pv_dvbo = 0; }
    if (g_pv_dvao) { glDeleteVertexArrays(1, &g_pv_dvao); g_pv_dvao = 0; }
    if (g_font_ttf.tex) { glDeleteTextures(1, &g_font_ttf.tex); g_font_ttf.tex = 0; }
    if (g_font_ft2.tex) { glDeleteTextures(1, &g_font_ft2.tex); g_font_ft2.tex = 0; }
    free(g_pv_verts);  g_pv_verts  = NULL;
    free(g_pv_dverts); g_pv_dverts = NULL;
    free(g_pv_cells);  g_pv_cells  = NULL; g_pv_cells_cap = 0;
    g_pv_have = 0;
}
