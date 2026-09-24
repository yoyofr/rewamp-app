// Stereo spectrum analyzer (FFT) GL renderer — viz mode 5.
//
// Included AFTER rewamp_viz_render.cpp in the same TU on every platform (the
// Apple podspecs' rewamp_viz_impl.mm and Android's rewamp_viz_android.cpp), so
// it reuses k_gl_preamble, compile_shader, link_program, art_upload_if_dirty,
// art_render and (Android) rewamp_gl_force_opaque — same deal as
// rewamp_notes_render.cpp. All file-scope symbols are sp_/g_sp_-prefixed.
//
// Design: mirrored bars around a horizontal midline — left channel grows UP,
// right channel grows DOWN — with slow-falling peak caps and a whisper of a
// midline.
//
// Five looks (rewamp_spectrum_palette()): 0 bars in the scope's colours,
// 1 bars coloured by frequency, 2 the beam, 3 the line, 4 the beam bent into a
// ring. 2 and 4 share one program and differ by a single uniform.
//   0 — the stereo scope's own settings (mono / bi-color L+R), so the spectrum
//       matches whatever the user already picked for the waveform;
//   1 — colored by FREQUENCY with brightness following amplitude, the Modizer
//       look: blue at the bottom of the range, red peaking mid, green climbing
//       to the top, each bar lit by how loud it is and washing toward white
//       when it saturates. Ported from RenderUtils::DrawSpectrum2D, rescaled —
//       Modizer's amplitudes are raw/512 and unbounded, ours are 0..1 dB-mapped.
// Because a bar's color now varies bar to bar, color is a VERTEX attribute
// here (the oscilloscope's uColor uniform could only paint a whole batch).
//
// Audio: rewamp_get_waveform() with the FULL ring (2048 frames — the same
// smoothed read head the oscilloscope uses, so pause freezes both the same
// way). Hann window, radix-2 FFT in-place, per-bar peak over log-spaced bins
// (30 Hz – 16 kHz at the engine's fixed 44100), mapped through dB [-60, 0].
// Ballistics are wall-clock-based (the render rate is 60 on Apple, whatever
// vsync says on Android): instant-ish attack, exponential release, linear
// peak fall after a short hold.

#define SP_FFT      2048                 /* REWAMP_WAVEFORM_FRAMES — whole ring */
#define SP_BINS     (SP_FFT / 2)
#define SP_BARS     64
/* Bands behind the beam palette — four times the bars, log-spaced the same way.
 * Only ever sampled through a texture, so the count costs a per-frame loop and
 * a 512-byte upload, nothing per pixel. */
#define SP_FINE     256
#define SP_FMIN     30.0f
#define SP_FMAX     16000.0f
#define SP_RATE     44100.0f             /* engine output rate (fixed) */
#define SP_DB_FLOOR (-60.0f)
/* verts: per channel per bar = bar quad (6) + cap quad (6); + midline (6) */
#define SP_MAX_VERTS (SP_BARS * 2 * 12 + 6)
#define SP_VFLOATS   6                   /* x, y, r, g, b, a */

/* Per-vertex color: one draw call still covers a whole channel even though
 * every bar has its own hue. */
static const char* k_sp_vert_body =
    "in vec2 aPos;\n"
    "in vec4 aCol;\n"
    "out vec4 vCol;\n"
    "void main() { gl_Position = vec4(aPos, 0.0, 1.0); vCol = aCol; }\n";

static const char* k_sp_frag_body =
    "in vec4 vCol;\n"
    "out vec4 fragColor;\n"
    "void main() { fragColor = vec4(vCol.rgb, vCol.a); }\n";

/* ── Palette 2: the beam ────────────────────────────────────────────────────
 * A full-screen pass instead of bars, after the classic Shadertoy "electric
 * beam": a scrolling R→G→B rainbow across x, a faint 100-line grid, and a
 * horizontal glow with a 1/|y| falloff. What makes it a SPECTRUM rather than
 * wallpaper is the thickness: the beam swells wherever the band under that
 * column is loud, upward on the left channel, downward on the right — the same
 * mirrored reading as the bars.
 *
 * Levels arrive as a TEXTURE (SP_FINE bands, one row per channel), not as
 * uniform arrays: the bars' 64 bands drew a visibly stepped beam, and a float
 * uniform array can cost one whole vector PER ELEMENT — two arrays fine enough
 * to fix that would have flirted with GL_MAX_FRAGMENT_UNIFORM_VECTORS, whose
 * ES 3.0 floor is 224. The texture also brings free linear interpolation
 * between bands, which is most of what "finer" means to the eye. */
static const char* k_sp_beam_vert =
    "in vec2 aPos;\n"
    "out vec2 vUv;\n"
    "void main() { gl_Position = vec4(aPos, 0.0, 1.0); vUv = aPos * 0.5 + 0.5; }\n";

static const char* k_sp_beam_frag =
    "uniform float uTime;\n"
    "uniform float uAspect;\n"
    "uniform float uPolar;\n"
    "uniform sampler2D uBands;\n"
    "in vec2 vUv;\n"
    "out vec4 fragColor;\n"
    "void main() {\n"
    "    vec2 uv = vUv;\n"
    /* Polar variant (palette 4): the SAME beam read in (angle, radius)
     * instead of (x, y), which bends the straight beam into a ring — the
     * substitution the Shadertoy original suggests. Aspect is applied to x
     * before the conversion so the ring stays round on a wide panel, and the
     * angle is shifted into 0..1 because the band texture clamps at its edges
     * (a raw atan gives -0.5..0.5, and the whole left half would have sampled
     * band 0). Everything downstream is untouched: `c.y = 2r-1` crosses zero
     * at r = 0.5, so the glow that used to sit on the midline now sits on that
     * circle, one channel inside it and the other outside. */
    "    if (uPolar > 0.5) {\n"
    "        vec2 p = vec2((vUv.x * 2.0 - 1.0) * uAspect, vUv.y * 2.0 - 1.0);\n"
    "        uv = vec2(atan(p.x, p.y) / 6.2831853 + 0.5, length(p));\n"
    "    }\n"
    "    float xCol = mod((uv.x - uTime / 8.0) * 3.0, 3.0);\n"
    "    vec3 horColour = vec3(0.25);\n"
    "    if (xCol < 1.0)      { horColour.r += 1.0 - xCol; horColour.g += xCol; }\n"
    "    else if (xCol < 2.0) { xCol -= 1.0; horColour.g += 1.0 - xCol; horColour.b += xCol; }\n"
    "    else                 { xCol -= 2.0; horColour.b += 1.0 - xCol; horColour.r += xCol; }\n"
    "    float backValue = 1.0;\n"
    "    if (mod(uv.y * 100.0, 1.0) > 0.75 ||\n"
    "        mod(uv.x * 100.0 * uAspect, 1.0) > 0.75) backValue = 1.15;\n"
    "    vec2 c = uv * 2.0 - 1.0;\n"
    "    float lvl = texture(uBands, vec2(uv.x, c.y >= 0.0 ? 0.25 : 0.75)).r;\n"
    "    float k = 0.06 + 0.85 * lvl * lvl;\n"
    "    float beam = min(abs(k / c.y), 6.0);\n"
    "    vec3 col = vec3(backValue) * beam * horColour;\n"
    "    col = min(col, vec3(1.0));\n"
    "    fragColor = vec4(col, max(max(col.r, col.g), col.b));\n"
    "}\n";

/* ── Palette 3: the line ────────────────────────────────────────────────────
 * "Audio visualizer" by Jan Mróz (jaszunio15), Shadertoy, CC BY 3.0 — credited
 * in Settings → About. A single glowing line scrolling right to left, its shape
 * the SUM of one sine per band, each sine's amplitude driven by that band and
 * its speed by a fixed per-band hash. Loud lows make the long slow swells, a
 * bright top end adds the fast ripple, silence flattens it to a straight line.
 *
 * Two departures from the original, both because it sampled a 512-texel FFT
 * texture and we have 64 analyzed bars:
 *   - the per-band weight (its pow/smoothstep/square chain) is computed ONCE
 *     per frame on the CPU into uAmp, instead of per pixel per band — it does
 *     not vary across the screen, and that is the whole cost of the effect;
 *   - fewer oscillators (SP_OSC): the sum is per-PIXEL, so halving it halves
 *     the fill cost for a difference nobody can point at.
 *
 * ── EVERY KNOB OF THIS PALETTE IS BELOW ────────────────────────────────────
 * They are the only numbers worth touching to change how it looks; the shader
 * and the CPU pass read them through, so editing one line here is enough. The
 * "original" values are the Shadertoy's, kept in the comments where we differ.
 *
 * The ones the SHADER reads are stringified into its source, so they must stay
 * valid GLSL float literals: keep the decimal point (600.0, never 600 — an int
 * where a float is expected fails to compile), and no `f` suffix. The ones the
 * CPU reads are plain C floats and do take the `f`. SP_OSC is an integer on
 * purpose: it is a count, used as an array size and a loop bound in both.
 */
#include "spectrum_line_shader.inc"

static unsigned g_sp_gen  = 0;
static GLuint   g_sp_prog = 0;
static GLuint   g_sp_vao  = 0;
static GLuint   g_sp_vbo  = 0;
static GLuint   g_sp_beam_prog = 0;
static GLuint   g_sp_beam_vao  = 0;
static GLuint   g_sp_beam_vbo  = 0;
static GLint    g_sp_beam_timeLoc = -1, g_sp_beam_aspLoc = -1;
static GLint    g_sp_beam_texLoc = -1;
static GLint    g_sp_beam_polarLoc = -1;   /* 1 = ring, 0 = straight beam */
static GLuint   g_sp_band_tex = 0;        /* SP_FINE x 2, R8: the beam's levels */
static GLuint   g_sp_line_prog = 0;
static GLint    g_sp_line_pxLoc = -1, g_sp_line_resyLoc = -1;
static GLint    g_sp_line_colLoc = -1, g_sp_line_ampLoc = -1, g_sp_line_phLoc = -1;
static GLint    g_sp_line_xsLoc = -1;
static float    g_sp_osc_ph[SP_OSC];      /* per-band speed, the original's hash */
static float    g_sp_osc_phase[SP_OSC];   /* phase envoyée au shader, réduite mod 2π */
static int      g_sp_osc_ph_ready = 0;
static float    g_sp_osc_amp[SP_OSC];     /* per-band weight, rebuilt each frame */
static float    g_sp_time = 0.0f;         /* seconds of rendering, for the scroll */

static float g_sp_wl[SP_FFT], g_sp_wr[SP_FFT];       /* waveform fetch      */
static float g_sp_re[SP_FFT], g_sp_im[SP_FFT];       /* FFT workspace       */
static float g_sp_hann[SP_FFT];
static int   g_sp_hann_ready = 0;
static float g_sp_mag[SP_BINS];
static int   g_sp_edges[SP_BARS + 1];                /* bin edge per bar    */
static int   g_sp_fedges[SP_FINE + 1];               /* bin edge per fine band */
static int   g_sp_edges_ready = 0;

/* Ballistics state, [channel][bar], normalized 0..1. */
static float g_sp_level[2][SP_BARS];
static float g_sp_fine [2][SP_FINE];                 /* same, at beam resolution */
static unsigned char g_sp_band_px[SP_FINE * 2];      /* upload staging          */
static float g_sp_peak [2][SP_BARS];
static float g_sp_hold [2][SP_BARS];                 /* peak hold time left */

static GLfloat g_sp_verts[SP_MAX_VERTS * SP_VFLOATS];

/* In-place iterative radix-2 FFT (decimation in time). n = power of two. */
static void sp_fft(float* re, float* im, int n)
{
    for (int i = 1, j = 0; i < n; i++) {              /* bit reversal */
        int bit = n >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j |= bit;
        if (i < j) {
            float t = re[i]; re[i] = re[j]; re[j] = t;
            t = im[i]; im[i] = im[j]; im[j] = t;
        }
    }
    for (int len = 2; len <= n; len <<= 1) {
        const float ang = -2.0f * (float)M_PI / (float)len;
        const float wr0 = cosf(ang), wi0 = sinf(ang);
        for (int i = 0; i < n; i += len) {
            float wr = 1.0f, wi = 0.0f;
            for (int k = 0; k < len / 2; k++) {
                const int a = i + k, b = i + k + len / 2;
                const float xr = re[b] * wr - im[b] * wi;
                const float xi = re[b] * wi + im[b] * wr;
                re[b] = re[a] - xr;  im[b] = im[a] - xi;
                re[a] += xr;         im[a] += xi;
                const float nwr = wr * wr0 - wi * wi0;
                wi = wr * wi0 + wi * wr0;
                wr = nwr;
            }
        }
    }
}

/* Log-spaced bar edges over the FFT bins, each bar at least one bin wide. */
static void sp_build_edges(void)
{
    const float binHz = SP_RATE / (float)SP_FFT;
    const float lmin = logf(SP_FMIN), lmax = logf(SP_FMAX);
    int prev = (int)(SP_FMIN / binHz); if (prev < 1) prev = 1;
    g_sp_edges[0] = prev;
    for (int b = 1; b <= SP_BARS; b++) {
        const float f = expf(lmin + (lmax - lmin) * (float)b / (float)SP_BARS);
        int e = (int)(f / binHz + 0.5f);
        if (e <= prev) e = prev + 1;                  /* monotonic, ≥1 bin  */
        if (e > SP_BINS) e = SP_BINS;
        g_sp_edges[b] = e;
        prev = e;
    }
    /* Same law, SP_FINE times — the beam's own resolution. */
    prev = (int)(SP_FMIN / binHz); if (prev < 1) prev = 1;
    g_sp_fedges[0] = prev;
    for (int b = 1; b <= SP_FINE; b++) {
        const float f = expf(lmin + (lmax - lmin) * (float)b / (float)SP_FINE);
        int e = (int)(f / binHz + 0.5f);
        /* Unlike the bars, a fine band may REPEAT a bin: 256 log-spaced bands
         * over 1024 bins runs out of bins at the bottom, and forcing them apart
         * would drag the whole scale off its frequencies. */
        if (e < prev) e = prev;
        if (e > SP_BINS) e = SP_BINS;
        g_sp_fedges[b] = e;
        prev = e;
    }
    g_sp_edges_ready = 1;
}

/* One channel: window → FFT → per-band dB → 0..1, into out[SP_BARS] and, for
 * the beam, fine[SP_FINE] — same FFT, two groupings. */
static void sp_analyze(const float* pcm, float* out, float* fine)
{
    for (int i = 0; i < SP_FFT; i++) {
        g_sp_re[i] = pcm[i] * g_sp_hann[i];
        g_sp_im[i] = 0.0f;
    }
    sp_fft(g_sp_re, g_sp_im, SP_FFT);
    /* 2/(N·coherent-gain of Hann 0.5) = 4/N puts a full-scale sine at ~0 dB. */
    const float norm = 4.0f / (float)SP_FFT;
    for (int i = 0; i < SP_BINS; i++)
        g_sp_mag[i] = sqrtf(g_sp_re[i] * g_sp_re[i] + g_sp_im[i] * g_sp_im[i]) * norm;
    for (int b = 0; b < SP_BARS; b++) {
        float m = 0.0f;
        for (int i = g_sp_edges[b]; i < g_sp_edges[b + 1]; i++)
            if (g_sp_mag[i] > m) m = g_sp_mag[i];    /* peak, not average: crisper */
        float db = 20.0f * log10f(m + 1e-9f);
        float t = (db - SP_DB_FLOOR) / (0.0f - SP_DB_FLOOR);
        out[b] = t < 0.0f ? 0.0f : (t > 1.0f ? 1.0f : t);
    }
    if (!fine) return;
    for (int b = 0; b < SP_FINE; b++) {
        float m = 0.0f;
        const int lo = g_sp_fedges[b];
        int hi = g_sp_fedges[b + 1];
        if (hi <= lo) hi = lo + 1;               /* a band always reads a bin */
        for (int i = lo; i < hi && i < SP_BINS; i++)
            if (g_sp_mag[i] > m) m = g_sp_mag[i];
        float db = 20.0f * log10f(m + 1e-9f);
        float t = (db - SP_DB_FLOOR) / (0.0f - SP_DB_FLOOR);
        fine[b] = t < 0.0f ? 0.0f : (t > 1.0f ? 1.0f : t);
    }
}

/* Seconds since the previous call (per-process; one spectrum at a time). */
static float sp_frame_dt(void)
{
    static struct timespec last = {0, 0};
    struct timespec now;
#ifdef _WIN32
    timespec_get(&now, TIME_UTC);
#else
    clock_gettime(CLOCK_MONOTONIC, &now);
#endif
    float dt = 1.0f / 60.0f;
    if (last.tv_sec != 0) {
        dt = (float)(now.tv_sec - last.tv_sec)
           + (float)(now.tv_nsec - last.tv_nsec) / 1e9f;
        if (dt <= 0.0f || dt > 0.5f) dt = 1.0f / 60.0f;   /* pause/seek gap */
    }
    last = now;
    return dt;
}

static int sp_push_quad(int nv, float x0, float y0, float x1, float y1,
                        float a0, float a1, const float* rgb)
{
    /* a0 = alpha at y0 edge, a1 at y1 edge (vertical gradient). */
    if (nv + 6 > SP_MAX_VERTS) return nv;
    GLfloat* v = g_sp_verts + nv * SP_VFLOATS;
    const float r = rgb[0], g = rgb[1], b = rgb[2];
    const GLfloat q[6][SP_VFLOATS] = {
        {x0, y0, r, g, b, a0}, {x1, y0, r, g, b, a0}, {x0, y1, r, g, b, a1},
        {x1, y0, r, g, b, a0}, {x1, y1, r, g, b, a1}, {x0, y1, r, g, b, a1},
    };
    memcpy(v, q, sizeof(q));
    return nv + 6;
}

/* Modizer's palette, rescaled. Its bar index drives the hue — blue owns the
 * bottom two thirds fading out, green climbs over the top two thirds, red is a
 * triangle peaking at the middle band — and its amplitude drives brightness
 * (`crt *= 0.5 + spL`). Modizer's amplitude is raw/512 and unbounded, so the
 * loudest bars there both brighten AND wash out (`if (spL>2) crt += …`); ours
 * is a 0..1 dB mapping, so the same two effects are keyed to its top quarter.
 * Out on `rgb[3]`. */
/* The original's hash, kept verbatim so the band speeds stay the ones that
 * make the line read as several waves crossing rather than one shape. */
static float sp_hash(float v)
{
    const float s = sinf(v * 124.14518f) * 2123.14121f;
    return (s - floorf(s)) - 0.5f;
}

/* Per-band weight of the line palette, once per frame: the original's
 * pow(band, 2 - HIGH_FREQ_APPERANCE) → smoothstep(0.2, 1) → squared, over the
 * loudest of the two channels (the line is one shape, not a stereo pair). */
/* [H] est la hauteur du panneau EN PIXELS: la pente d'un oscillateur s'y
 * mesure, et c'est elle qui décide s'il peut être dessiné (voir le budget de
 * pente plus bas). */
static void sp_build_osc_amp(int H)
{
    if (!g_sp_osc_ph_ready) {
        for (int i = 0; i < SP_OSC; i++) g_sp_osc_ph[i] = sp_hash((float)(i + 1));
        g_sp_osc_ph_ready = 1;
    }
    /* BUDGET DE PENTE, par oscillateur, en pixels par pixel.
     *
     * L'oscillateur i vaut `A·a_i·sin(f_i·x·uXScale)`, donc sa pente en pixels
     * est `A/SP_OSC · (H/2) · a_i · f_i · uXScale·2/W`. Le dernier facteur ne
     * dépend PAS du panneau — uXScale est proportionnel à W, le W s'annule et
     * il reste `SP_LINE_XSCALE·2/1000` — mais le `H/2` en dépend: **la pente en
     * pixels croît avec la HAUTEUR du panneau**. Un panneau paysage de 420 px
     * de haut garde tous ses oscillateurs sous le plafond; le panneau d'un
     * téléphone en portrait (≈1470 px) en met 18 sur 32 au-dessus, jusqu'à 44
     * px/px pour un plafond de 24 — le fragment n'ombre alors qu'une poignée de
     * pixels par colonne et la courbe sort en POINTILLÉS verticaux. C'est le
     * bug: la même ligne, correcte sur un écran large, brisée sur un téléphone.
     *
     * Élargir la tolérance du shader ne suffit pas: au-delà d'un cycle par
     * poignée de pixels il n'y a plus de courbe à tracer, seulement du
     * repliement. On atténue donc la bande là où la géométrie ne peut pas la
     * rendre, avec un genou doux plutôt qu'une coupure (une bande qui
     * disparaît d'un coup quand la fenêtre grandit se voit). Les bandes lentes,
     * qui portent la FORME, passent intactes; les rapides, qui ne portaient que
     * du bruit sur ce panneau, s'effacent. Mesuré: pente maximale 44 → 13 px/px
     * sur le téléphone (zéro bande au-dessus du plafond), 12 → 8 sur un
     * panneau de bureau, où le rendu ne bouge donc pas. */
    const float slopeK = (float)SP_LINE_AMPLITUDE / (float)SP_OSC * 0.5f
                       * ((float)SP_LINE_XSCALE * 2.0f / 1000.0f) * (float)H;
    const int step = SP_BARS / SP_OSC;
    for (int i = 0; i < SP_OSC; i++) {
        float v = 0.0f;
        for (int k = 0; k < step; k++) {           /* the bars this band covers */
            const int b = i * step + k;
            if (g_sp_level[0][b] > v) v = g_sp_level[0][b];
            if (g_sp_level[1][b] > v) v = g_sp_level[1][b];
        }
        v = powf(v, 2.0f - (float)SP_LINE_HF_APPEAR);
        float t = (v - SP_LINE_GATE_LO) / (SP_LINE_GATE_HI - SP_LINE_GATE_LO);
        t = t < 0.0f ? 0.0f : (t > 1.0f ? 1.0f : t);
        t = t * t * (3.0f - 2.0f * t);              /* smoothstep, then square */
        const float hf = (float)i / (float)(SP_OSC - 1);
        /* f_i = ((i+1)/SP_OSC)², la loi du shader — la répéter ici est ce qui
         * rend le budget exact plutôt qu'approché. */
        const float f  = ((float)(i + 1) / (float)SP_OSC)
                       * ((float)(i + 1) / (float)SP_OSC);
        const float sl = slopeK * f;                       /* px/px à pleine amplitude */
        const float w  = 1.0f / sqrtf(1.0f + (sl / (float)SP_LINE_MAX_SLOPE)
                                           * (sl / (float)SP_LINE_MAX_SLOPE));
        /* LIMITE DE NYQUIST, l'autre moitié du problème. Le budget ci-dessus
         * mesure une PENTE, donc une bande de faible amplitude et de haute
         * fréquence le passe sans peine — tout en oscillant plus vite que la
         * grille de pixels ne peut le montrer. Deux colonnes voisines tombent
         * alors sur des phases opposées: la ligne se déchire par petits bouts,
         * précisément là où elle bouge le plus.
         *
         * La période d'une bande ne dépend NI de la largeur (le W de uXScale
         * s'annule) NI de la hauteur: c'est une constante par bande, 3,9 px
         * pour la plus haute. On l'atténue donc en fondu de MIN_PERIOD à
         * 2×MIN_PERIOD, ce qui ne retire que ce qui n'était pas représentable.
         *
         * Mesuré sur un modèle fidèle du shader, toutes bandes à fond (le pire
         * cas), en comptant les colonnes où la courbe se coupe:
         *   paysage 1400×400   624 → 0   (cap 24 sans limite → cap 96 + 8 px)
         *   portrait 1080×1470 410 → 0
         * Le plafond de pente SEUL n'y suffit pas (598 et 156), la limite de
         * période SEULE non plus (7 et 177): il faut les deux. */
        const float per = 6.28318530718f
                        / (f * (float)SP_LINE_XSCALE * 2.0f / 1000.0f);
        float n = (per - SP_LINE_MIN_PERIOD) / SP_LINE_MIN_PERIOD;
        n = n < 0.0f ? 0.0f : (n > 1.0f ? 1.0f : n);
        n = n * n * (3.0f - 2.0f * n);
        g_sp_osc_amp[i] = t * t * (1.0f - SP_LINE_HF_ROLLOFF * hf) * w * n;
    }
}

static void sp_freq_color(int bar, float amp, float* rgb)
{
    const float t = SP_BARS > 1 ? (float)bar / (float)(SP_BARS - 1) : 0.0f;
    float r = 1.0f - fabsf(t - 0.5f) * 2.0f;               /* peaks mid-range */
    float g = t > (1.0f / 3.0f) ? (t - 1.0f / 3.0f) / (2.0f / 3.0f) : 0.0f;
    float b = t < (2.0f / 3.0f) ? (2.0f / 3.0f - t) / (2.0f / 3.0f) : 0.0f;
    /* Saturating bars wash toward white — Modizer's `spL > 2` branch, which
     * only ever fires on the very loudest bands. */
    const float w = amp > 0.80f ? (amp - 0.80f) * 0.8f : 0.0f;
    /* Brightness by amplitude. Modizer multiplies by `0.5 + spL` and clamps at
     * 1, where spL is raw/512 and UNBOUNDED — so an ordinary band is already
     * past 1 and clips, and the ramp from dark to full colour happens over the
     * bottom of the range, not across it. Our amp is 0..1, so the same feel
     * needs a gain: at 0.5 + 3·amp a bar is at full colour by a sixth of its
     * height, and the floor stays at half — which is what was asked for both
     * times (half at rest, then rising fast). */
    const float k = 0.55f + 5.0f * amp;
    r = (r + w) * k; g = (g + w) * k; b = (b + w) * k;
    rgb[0] = r > 1.0f ? 1.0f : r;
    rgb[1] = g > 1.0f ? 1.0f : g;
    rgb[2] = b > 1.0f ? 1.0f : b;
}

REWAMP_EXPORT int rewamp_spectrum_init(int width, int height)
{
    {
        int err = rewamp_gl_ensure(width, height);
        if (err != 0) return err;
    }
    if (g_sp_prog && g_sp_gen == rewamp_gl_generation())
        return 0;
    g_sp_prog = 0;
    art_invalidate();   /* the artwork texture died with the old context too */

    /* Own program: position + per-vertex RGBA (see the palette note on top). */
    GLuint vert = compile_shader(GL_VERTEX_SHADER,   k_gl_preamble, k_sp_vert_body);
    GLuint frag = compile_shader(GL_FRAGMENT_SHADER, k_gl_preamble, k_sp_frag_body);
    if (!vert || !frag) return -10;
    g_sp_prog = link_program(vert, frag);
    glDeleteShader(vert);
    glDeleteShader(frag);
    if (!g_sp_prog) return -11;
    const GLint posLoc = glGetAttribLocation(g_sp_prog, "aPos");
    const GLint colLoc = glGetAttribLocation(g_sp_prog, "aCol");

    glGenVertexArrays(1, &g_sp_vao);
    glBindVertexArray(g_sp_vao);
    glGenBuffers(1, &g_sp_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, g_sp_vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(g_sp_verts), NULL, GL_DYNAMIC_DRAW);
    glEnableVertexAttribArray(posLoc);
    glVertexAttribPointer(posLoc, 2, GL_FLOAT, GL_FALSE,
                          SP_VFLOATS * sizeof(GLfloat), (void*)0);
    if (colLoc >= 0) {
        glEnableVertexAttribArray(colLoc);
        glVertexAttribPointer(colLoc, 4, GL_FLOAT, GL_FALSE,
                              SP_VFLOATS * sizeof(GLfloat),
                              (void*)(2 * sizeof(GLfloat)));
    }
    glBindVertexArray(0);

    /* Beam palette: its own program + a full-screen quad. Built here rather
     * than lazily so a failure shows up at init like every other program. */
    {
        GLuint bv = compile_shader(GL_VERTEX_SHADER,   k_gl_preamble, k_sp_beam_vert);
        GLuint bf = compile_shader(GL_FRAGMENT_SHADER, k_gl_preamble, k_sp_beam_frag);
        if (bv && bf) {
            g_sp_beam_prog = link_program(bv, bf);
            glDeleteShader(bv);
            glDeleteShader(bf);
        }
        if (g_sp_beam_prog) {
            g_sp_beam_timeLoc = glGetUniformLocation(g_sp_beam_prog, "uTime");
            g_sp_beam_aspLoc  = glGetUniformLocation(g_sp_beam_prog, "uAspect");
            g_sp_beam_texLoc  = glGetUniformLocation(g_sp_beam_prog, "uBands");
      g_sp_beam_polarLoc = glGetUniformLocation(g_sp_beam_prog, "uPolar");
            /* One row per channel, LINEAR so the beam reads as a curve rather
             * than 256 steps; CLAMP so the edges do not wrap into each other. */
            glGenTextures(1, &g_sp_band_tex);
            glBindTexture(GL_TEXTURE_2D, g_sp_band_tex);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, SP_FINE, 2, 0,
                         GL_RED, GL_UNSIGNED_BYTE, NULL);
            glBindTexture(GL_TEXTURE_2D, 0);
            const GLint bpos  = glGetAttribLocation(g_sp_beam_prog, "aPos");
            static const GLfloat kQuad[] = {
                -1.f, -1.f,  1.f, -1.f,  -1.f,  1.f,
                 1.f, -1.f,  1.f,  1.f,  -1.f,  1.f,
            };
            glGenVertexArrays(1, &g_sp_beam_vao);
            glBindVertexArray(g_sp_beam_vao);
            glGenBuffers(1, &g_sp_beam_vbo);
            glBindBuffer(GL_ARRAY_BUFFER, g_sp_beam_vbo);
            glBufferData(GL_ARRAY_BUFFER, sizeof(kQuad), kQuad, GL_STATIC_DRAW);
            glEnableVertexAttribArray(bpos);
            glVertexAttribPointer(bpos, 2, GL_FLOAT, GL_FALSE, 0, (void*)0);
            glBindVertexArray(0);
        }
    }

    /* Line palette: same full-screen quad + vertex shader, its own fragment. */
    {
        GLuint lv = compile_shader(GL_VERTEX_SHADER,   k_gl_preamble, k_sp_beam_vert);
        GLuint lf = compile_shader(GL_FRAGMENT_SHADER, k_gl_preamble, k_sp_line_frag);
        if (lv && lf) {
            g_sp_line_prog = link_program(lv, lf);
            glDeleteShader(lv);
            glDeleteShader(lf);
        }
        if (g_sp_line_prog) {
            g_sp_line_pxLoc   = glGetUniformLocation(g_sp_line_prog, "uPx");
            g_sp_line_resyLoc = glGetUniformLocation(g_sp_line_prog, "uResY");
            g_sp_line_colLoc  = glGetUniformLocation(g_sp_line_prog, "uCol");
            g_sp_line_xsLoc   = glGetUniformLocation(g_sp_line_prog, "uXScale");
            g_sp_line_ampLoc  = glGetUniformLocation(g_sp_line_prog, "uAmp");
            g_sp_line_phLoc   = glGetUniformLocation(g_sp_line_prog, "uPh");
        }
    }

    if (!g_sp_hann_ready) {
        for (int i = 0; i < SP_FFT; i++)
            g_sp_hann[i] = 0.5f - 0.5f * cosf(2.0f * (float)M_PI * i / (SP_FFT - 1));
        g_sp_hann_ready = 1;
    }
    if (!g_sp_edges_ready) sp_build_edges();

    g_sp_gen = rewamp_gl_generation();
    return 0;
}

REWAMP_EXPORT void rewamp_spectrum_render(void)
{
    rewamp_gl_make_current();

    rewamp_get_waveform(g_sp_wl, g_sp_wr, SP_FFT);
    /* The fine grouping is only read by the beam — do not pay for it elsewhere.
     * Both beam variants read it: 2 = straight, 4 = polar (the ring). */
    const int palette = rewamp_spectrum_palette();
    const int wantFine = (palette == 2 || palette == 4);
    static float lvlL[SP_BARS], lvlR[SP_BARS];
    static float finL[SP_FINE], finR[SP_FINE];
    sp_analyze(g_sp_wl, lvlL, wantFine ? finL : NULL);
    sp_analyze(g_sp_wr, lvlR, wantFine ? finR : NULL);

    /* Ballistics: fast attack (~30 ms), release ~7 dB-equivalents/s worth of
     * exponential fall, peaks hold 0.55 s then drop at 0.45 units/s. */
    const float dt = sp_frame_dt();
    const float atk = 1.0f - expf(-dt / 0.030f);
    const float rel = expf(-dt * 6.5f);
    for (int ch = 0; ch < 2; ch++) {
        const float* t = ch == 0 ? lvlL : lvlR;
        for (int b = 0; b < SP_BARS; b++) {
            float* v = &g_sp_level[ch][b];
            if (t[b] > *v) *v += (t[b] - *v) * atk;
            else           *v = t[b] + (*v - t[b]) * rel;
            float* p = &g_sp_peak[ch][b];
            if (*v >= *p) { *p = *v; g_sp_hold[ch][b] = 0.55f; }
            else if (g_sp_hold[ch][b] > 0.0f) g_sp_hold[ch][b] -= dt;
            else { *p -= dt * 0.45f; if (*p < *v) *p = *v; }
        }
        if (!wantFine) continue;
        const float* f = ch == 0 ? finL : finR;
        for (int b = 0; b < SP_FINE; b++) {   /* same ballistics, no peak hold */
            float* v = &g_sp_fine[ch][b];
            if (f[b] > *v) *v += (f[b] - *v) * atk;
            else           *v = f[b] + (*v - f[b]) * rel;
        }
    }

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

    /* The clock the beam and the line animate on only runs while sound does.
     * Both scroll AND rotate every band's phase with it, so on pause the wave
     * went on sliding and rippling over a waveform that was frozen — the viz
     * looked alive with nothing playing. The bars never showed it: their only
     * motion IS the audio. */
    if (rewamp_is_playing()) g_sp_time += dt;

    /* Line palette: one full-screen pass, no bar geometry either. Tinted with
     * the scope's own color so it stays the user's chosen look. */
    if (rewamp_spectrum_palette() == 3 && g_sp_line_prog) {
        sp_build_osc_amp(H);
        const float* lc = rewamp_stereo_bicolor() ? rewamp_stereo_left_color()
                                                  : rewamp_stereo_mono_color();
        glUseProgram(g_sp_line_prog);
        /* uPx = one pixel expressed in uv.y units, so SP_LINE_WIDTH is read in
         * real pixels whatever the panel is. */
        glUniform1f(g_sp_line_pxLoc, H > 0 ? 2.0f / (float)H : 0.01f);
        glUniform1f(g_sp_line_resyLoc, (float)H);
        /* Tied to the width: the wave then has a fixed wavelength in PIXELS
         * instead of a fixed number of cycles per screen, so a wide window
         * shows more of the same wave rather than the same wave stretched, and
         * a narrow one fewer rather than a scribble. */
        const double xs = (double)SP_LINE_XSCALE * (double)W / 1000.0;
        glUniform1f(g_sp_line_xsLoc, (float)xs);
        /* Phase de chaque bande, réduite modulo 2π ICI, en double.
         *
         * Le shader recevait `uTime` et recomposait
         * `f_i * ((uv.x + uTime*SCROLL) * uXScale + uTime*PHASE_SPEED*hash_i)`.
         * Les deux termes en temps croissent sans borne — à 100 s de lecture le
         * premier vaut déjà ~10^5 — et mangent la précision du sinus: tout de
         * suite en mediump (le défaut GLES, cf. le shader), à la longue même en
         * highp. Réduit ici, le shader ne voit plus qu'un décalage borné et
         * `f_i*uv.x*uXScale`, dont l'amplitude ne dépend que du panneau. */
        for (int i = 0; i < SP_OSC; i++) {
            const double f = ((double)(i + 1) / (double)SP_OSC)
                           * ((double)(i + 1) / (double)SP_OSC);
            const double ph = f * ((double)g_sp_time * (double)SP_LINE_SCROLL * xs
                                 + (double)g_sp_time * (double)SP_LINE_PHASE_SPEED
                                   * (double)g_sp_osc_ph[i]);
            g_sp_osc_phase[i] = (float)fmod(ph, 6.283185307179586);
        }
        glUniform3f(g_sp_line_colLoc, lc[0], lc[1], lc[2]);
        glUniform1fv(g_sp_line_ampLoc, SP_OSC, g_sp_osc_amp);
        glUniform1fv(g_sp_line_phLoc,  SP_OSC, g_sp_osc_phase);
        glBindVertexArray(g_sp_beam_vao);
        glDrawArrays(GL_TRIANGLES, 0, 6);
        glBindVertexArray(0);
#ifdef __ANDROID__
        rewamp_gl_force_opaque();
#endif
        rewamp_gl_flush();
        return;
    }

    /* Beam palette: one full-screen pass, no bar geometry at all. Palette 4 is
     * the SAME pass read in polar coordinates — one uniform apart, so it costs
     * neither a second program nor a second upload. */
    if ((palette == 2 || palette == 4) && g_sp_beam_prog && g_sp_band_tex) {
        for (int ch = 0; ch < 2; ch++) {
            for (int b = 0; b < SP_FINE; b++) {
                float v = g_sp_fine[ch][b];
                v = v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v);
                g_sp_band_px[ch * SP_FINE + b] = (unsigned char)(v * 255.0f + 0.5f);
            }
        }
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, g_sp_band_tex);
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, SP_FINE, 2,
                        GL_RED, GL_UNSIGNED_BYTE, g_sp_band_px);
        glUseProgram(g_sp_beam_prog);
        /* Temps REPLIÉ sur la période du motif. Le faisceau ne s'en sert que
         * dans `mod((uv.x - uTime/8) * 3, 3)`, de période 8 s: laisser filer
         * l'horloge finissait par manger la précision du `mod` — en mediump
         * (défaut GLES) le pas de quantification atteint 0.25 après une heure
         * et le dégradé se met à marcher par paliers. Même famille que la
         * phase réduite du mode Ligne. */
        glUniform1f(g_sp_beam_timeLoc, (float)fmod((double)g_sp_time, 8.0));
        glUniform1f(g_sp_beam_aspLoc, H > 0 ? (float)W / (float)H : 1.0f);
        glUniform1i(g_sp_beam_texLoc, 0);
        glUniform1f(g_sp_beam_polarLoc, palette == 4 ? 1.0f : 0.0f);
        glBindVertexArray(g_sp_beam_vao);
        glDrawArrays(GL_TRIANGLES, 0, 6);
        glBindVertexArray(0);
#ifdef __ANDROID__
        rewamp_gl_force_opaque();
#endif
        rewamp_gl_flush();
        return;
    }

    glUseProgram(g_sp_prog);
    glBindVertexArray(g_sp_vao);
    glBindBuffer(GL_ARRAY_BUFFER, g_sp_vbo);

    const int byFreq  = rewamp_spectrum_palette() == 1;

    /* Layout (NDC). Mirrored around the midline; a hair of breathing room on
     * the sides; bars fill 68% of their slot. Pixel-derived minima keep the
     * idle state visible as a clean dotted line rather than nothing.
     *
     * The frequency palette closes the middle: no separating line there (see
     * the midline quad below) and half the clearance, so the two halves read as
     * ONE mirrored spectrum. Not zero — each bar carries a black outline that
     * eats 0.8 px of it, and letting the two rims touch would weld the halves
     * into a single block. */
    const float margin  = 0.02f;
    const float slotW   = (2.0f - 2.0f * margin) / SP_BARS;
    const float barW    = slotW * 0.68f;
    const float gapY    = (byFreq ? 1.5f : 3.0f) / (float)H * 2.0f;
    const float half    = 1.0f - gapY;                     /* usable half-height */
    const float minH    = 2.0f  / (float)H * 2.0f;         /* idle stub          */
    const float capH    = 2.5f  / (float)H * 2.0f;         /* peak cap thickness */
    const float capOff  = 2.0f  / (float)H * 2.0f;         /* cap gap above bar  */
    const int bicolor = rewamp_stereo_bicolor();
    const float* cl = bicolor ? rewamp_stereo_left_color()  : rewamp_stereo_mono_color();
    const float* cr = bicolor ? rewamp_stereo_right_color() : rewamp_stereo_mono_color();

    for (int ch = 0; ch < 2; ch++) {
        const float sgn = ch == 0 ? 1.0f : -1.0f;          /* L up, R down */
        const float* col = ch == 0 ? cl : cr;
        int nv = 0;
        for (int b = 0; b < SP_BARS; b++) {
            const float x0 = -1.0f + margin + b * slotW + (slotW - barW) * 0.5f;
            const float x1 = x0 + barW;
            const float lvl = g_sp_level[ch][b];
            float h = lvl * half; if (h < minH) h = minH;
            float rgb[3];
            if (byFreq) sp_freq_color(b, lvl, rgb);
            else { rgb[0] = col[0]; rgb[1] = col[1]; rgb[2] = col[2]; }
            /* A hairline of black UNDER the bar, drawn first and overpainted
             * everywhere but its rim: side by side, two neighbouring hues bleed
             * into one another over the artwork, and the outline is what makes
             * each bar's own colour read. Only in the frequency palette — the
             * scope one is a single hue, nothing to separate. */
            if (byFreq) {
                const float ex = 0.8f / (float)W * 2.0f;
                const float ey = 0.8f / (float)H * 2.0f;
                static const float kBlack[3] = {0.0f, 0.0f, 0.0f};
                nv = sp_push_quad(nv, x0 - ex, sgn * (gapY - ey),
                                  x1 + ex, sgn * (gapY + h + ey),
                                  1.0f, 1.0f, kBlack);
            }
            /* Scope palette: bright at the midline, softer at the tip. The
             * frequency palette fills FLAT and opaque instead — its colour
             * already carries the level, and fading the tip only muddied it. */
            nv = sp_push_quad(nv, x0, sgn * gapY, x1, sgn * (gapY + h),
                              byFreq ? 1.0f : 0.92f, byFreq ? 1.0f : 0.55f, rgb);
            /* Peak caps belong to the scope palette only: on coloured bars the
             * little floating dashes read as a second, unrelated signal. */
            float ph = g_sp_peak[ch][b] * half;
            if (!byFreq && ph > h + capOff) {
                const float py = sgn * (gapY + ph);
                nv = sp_push_quad(nv, x0, py, x1, py + sgn * capH, 1.0f, 1.0f, rgb);
            }
        }
        /* Midline whisper, drawn once with the right-channel batch. The
         * frequency palette does without: its bars already meet in the middle,
         * and a line across them read as a scale that means nothing. */
        if (ch == 1 && !byFreq) {
            const float ly = 0.5f / (float)H * 2.0f;
            const float mrgb[3] = { col[0], col[1], col[2] };
            nv = sp_push_quad(nv, -1.0f + margin, -ly, 1.0f - margin, ly,
                              0.22f, 0.22f, mrgb);
        }
        glBufferData(GL_ARRAY_BUFFER, sizeof(g_sp_verts), NULL, GL_DYNAMIC_DRAW);
        glBufferSubData(GL_ARRAY_BUFFER, 0,
                        (GLsizeiptr)(nv * SP_VFLOATS * sizeof(GLfloat)), g_sp_verts);
        glDrawArrays(GL_TRIANGLES, 0, nv);
    }

    glBindVertexArray(0);
#ifdef __ANDROID__
    rewamp_gl_force_opaque();
#endif
    rewamp_gl_flush();
}

REWAMP_EXPORT void rewamp_spectrum_uninit(void)
{
    if (g_sp_prog) { glDeleteProgram(g_sp_prog);         g_sp_prog = 0; }
    if (g_sp_vbo)  { glDeleteBuffers(1, &g_sp_vbo);      g_sp_vbo  = 0; }
    if (g_sp_vao)  { glDeleteVertexArrays(1, &g_sp_vao); g_sp_vao  = 0; }
    if (g_sp_line_prog) { glDeleteProgram(g_sp_line_prog);         g_sp_line_prog = 0; }
    if (g_sp_beam_prog) { glDeleteProgram(g_sp_beam_prog);         g_sp_beam_prog = 0; }
    if (g_sp_beam_vbo)  { glDeleteBuffers(1, &g_sp_beam_vbo);      g_sp_beam_vbo  = 0; }
    if (g_sp_beam_vao)  { glDeleteVertexArrays(1, &g_sp_beam_vao); g_sp_beam_vao  = 0; }
    if (g_sp_band_tex)  { glDeleteTextures(1, &g_sp_band_tex);     g_sp_band_tex  = 0; }
    memset(g_sp_level, 0, sizeof(g_sp_level));
    memset(g_sp_peak,  0, sizeof(g_sp_peak));
    memset(g_sp_hold,  0, sizeof(g_sp_hold));
}
