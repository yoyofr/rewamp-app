#include "rewamp_notes.h"
#include "ModizerVoicesData.h"      /* vgm_last_note[] */
#include "rewamp_channel_data.h"    /* rewamp_channel_count() */
#include "rewamp_audio.h"           /* rewamp_viz_frame_time() */
#include "rewamp_plugin.h"          /* pattern_get: échantillon depuis la grille */
#include <stdint.h>
#include <stdlib.h>

#include <string.h>
#include <time.h>

#define NOTE_COLS   2048   /* ring capacity in columns */
#define NOTE_VOICES 64     /* max tracked voices */

/* Per-column snapshot of voice note frequencies (Hz), tagged by sample pos.
 * Written by the producer (audio thread), read by the UI thread; intentionally
 * lock-free — a torn read during a 60 fps poll is visually harmless. */
static float            g_hz[NOTE_COLS][NOTE_VOICES];
static uint8_t          g_vol[NOTE_COLS][NOTE_VOICES];
static uint8_t          g_instr[NOTE_COLS][NOTE_VOICES];
static int64_t          g_pos[NOTE_COLS];
static volatile int64_t g_head = 0;     /* monotonic column counter */
static int              g_vc   = 0;     /* voice count */
static volatile int64_t g_played = 0;   /* consumer sample position */
static double           g_played_t = 0; /* monotonic seconds at last update */
/* Set by a load or a seek, cleared by the first consumer update that MOVES the
 * position: until the new audio actually flows, the wall clock says nothing
 * about where the music is, and extrapolating it ran the display up to 0.25 s
 * ahead of a track that had not started — an offset the display then had to
 * walk back (see rewamp_notes_played_smooth). */
static volatile int     g_clock_held = 1;

/* ── Échantillon depuis la grille (voir rewamp_notes.h) ─────────────────── */
static uint8_t            g_grid_instr[NOTE_VOICES];
static RewampPatternCell* g_grid_cells   = NULL;
static int                g_grid_cap     = 0;
static int                g_grid_pattern = -1;
static int                g_grid_rows    = 0;
static int                g_grid_ch      = 0;
static int                g_grid_order   = -1;
static int                g_grid_row     = -1;

static void grid_reset(void) {
    memset(g_grid_instr, 0, sizeof(g_grid_instr));
    g_grid_pattern = -1;
    g_grid_rows = g_grid_ch = 0;
    g_grid_order = g_grid_row = -1;
}

void rewamp_notes_grid_update(const RewampPluginVTable* vt, RewampDecoder* dec,
                              int order, int row) {
    if (vt == NULL || dec == NULL || order < 0 || row < 0) return;
    if (vt->pattern_get == NULL || vt->pattern_order == NULL ||
        vt->pattern_num_rows == NULL || vt->pattern_song_info == NULL) return;
    if (order == g_grid_order && row == g_grid_row) return;
    g_grid_order = order; g_grid_row = row;

    int pat = vt->pattern_order(dec, order);
    if (pat < 0) return;
    if (pat != g_grid_pattern) {
        RewampPatternSongInfo si;
        memset(&si, 0, sizeof(si));
        if (!vt->pattern_song_info(dec, &si) || si.num_channels <= 0) return;
        int rows = vt->pattern_num_rows(dec, pat);
        if (rows <= 0) return;
        int need = rows * si.num_channels;
        if (need > g_grid_cap) {
            RewampPatternCell* p = (RewampPatternCell*)realloc(
                g_grid_cells, (size_t)need * sizeof(RewampPatternCell));
            if (p == NULL) return;
            g_grid_cells = p; g_grid_cap = need;
        }
        if (vt->pattern_get(dec, pat, g_grid_cells, need) <= 0) {
            g_grid_pattern = -1;
            return;
        }
        g_grid_pattern = pat; g_grid_rows = rows; g_grid_ch = si.num_channels;
    }
    if (row >= g_grid_rows) return;
    int n = g_grid_ch < NOTE_VOICES ? g_grid_ch : NOTE_VOICES;
    for (int c = 0; c < n; c++) {
        /* La colonne de la voie c dans la grille — même index que la voie,
         * comme la notation le suppose pour ses en-têtes. Un numéro ≤ 0 n'est
         * pas un échantillon (−1 = cellule vide; 0 = « aucun » chez tous les
         * formats à grille), il garde le dernier connu. */
        int32_t ins = g_grid_cells[(size_t)row * g_grid_ch + c].instrument;
        if (ins > 0) g_grid_instr[c] = (uint8_t)(ins > 255 ? 255 : ins);
    }
}

static double now_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

void rewamp_notes_reset(int voiceCount) {
    if (voiceCount < 0) voiceCount = 0;
    if (voiceCount > NOTE_VOICES) voiceCount = NOTE_VOICES;
    g_vc     = voiceCount;
    g_head   = 0;
    g_played = 0;
    g_clock_held = 1;
    memset(g_hz, 0, sizeof(g_hz));
    memset(g_vol, 0, sizeof(g_vol));
    memset(g_instr, 0, sizeof(g_instr));
    memset(g_pos, 0, sizeof(g_pos));
    grid_reset();
}

void rewamp_notes_capture(int64_t producerSamplePos) {
    if (g_vc <= 0) return;
    int slot = (int)(g_head & (NOTE_COLS - 1));
    for (int i = 0; i < g_vc; i++) {
        g_hz[slot][i]    = (float)vgm_last_note[i];
        unsigned int vl  = vgm_last_vol[i];
        unsigned int ins = vgm_last_instr[i];
        if (ins == 0) ins = g_grid_instr[i];   /* échantillon lu dans la grille */
        g_vol[slot][i]   = (uint8_t)(vl  > 255 ? 255 : vl);
        g_instr[slot][i] = (uint8_t)(ins > 255 ? 255 : ins);
    }
    g_pos[slot] = producerSamplePos;
    g_head++;
}

void rewamp_notes_set_played(int64_t playedSamplePos) {
    if (playedSamplePos != g_played) g_clock_held = 0;
    g_played   = playedSamplePos;
    g_played_t = now_sec();
}

void rewamp_notes_seek_played(int64_t playedSamplePos) {
    g_played     = playedSamplePos;
    g_played_t   = now_sec();
    g_clock_held = 1;
}

static volatile int g_paused = 0;
void rewamp_notes_set_paused(int paused) { g_paused = paused ? 1 : 0; }
int  rewamp_notes_paused(void)           { return g_paused; }

static double g_rate = 44100.0;
void   rewamp_notes_set_rate(int sampleRate) { if (sampleRate > 0) g_rate = (double)sampleRate; }
double rewamp_notes_rate(void)               { return g_rate; }

/* Relais gapless: le décodeur a changé, la réserve NON — voir le commentaire
 * d'époque de rewamp_datasource.c. On ne remet donc rien à zéro; seul le NOMBRE
 * DE VOIX (et le taux) change pour les captures à venir.
 *
 * ⚠️ Les lecteurs utilisent UN pas de voix pour toute la fenêtre (l'appelant
 * alloue `cols * vc`), donc une colonne ANCIENNE relue avec un pas PLUS GRAND
 * exposerait, au-delà des voix du morceau précédent, ce qu'un tour de tampon
 * plus vieux avait laissé là. On efface donc ces voix-là une bonne fois sur
 * tout l'anneau — ~0,5 Mo de memset à une frontière de piste, sur le fil
 * producteur. Un pas PLUS PETIT ne demande rien: on lit simplement moins de
 * voix de la queue précédente. */
void rewamp_notes_new_epoch(int voiceCount, int sampleRate) {
    if (voiceCount < 0) voiceCount = 0;
    if (voiceCount > NOTE_VOICES) voiceCount = NOTE_VOICES;
    const int old = g_vc;
    if (voiceCount > old) {
        const size_t n = (size_t)(voiceCount - old);
        for (int s = 0; s < NOTE_COLS; s++) {
            memset(&g_hz[s][old],    0, n * sizeof(float));
            memset(&g_vol[s][old],   0, n);
            memset(&g_instr[s][old], 0, n);
        }
    }
    g_vc = voiceCount;
    if (sampleRate > 0) g_rate = (double)sampleRate;
    /* Autre décodeur, autres motifs: le cache de grille est périmé (un index
     * de motif égal désignerait les cellules de l'ANCIEN morceau). */
    grid_reset();
}

int rewamp_notes_voice_count(void) { return g_vc; }

double rewamp_notes_lead_seconds(void) {
    if (g_vc <= 0 || g_head == 0) return 0.0;
    int slot = (int)((g_head - 1) & (NOTE_COLS - 1));
    int64_t lead = g_pos[slot] - g_played;
    if (lead < 0) lead = 0;
    /* Producer/consumer share the data source rate. */
    return (double)lead / g_rate;
}

int64_t rewamp_notes_played(void) { return g_played; }

/* Playhead extrapolated to the current wall-clock instant for smooth scrolling
 * between audio callbacks. Clamped so a stalled/paused stream can't run away. */
double rewamp_notes_played_interp(int sampleRate) {
    (void)sampleRate;           /* uses the track's real rate (set at load) */
    /* Paused: the true position is final — extrapolating the wall clock past
     * it made the notation scroll on after the pause button. */
    if (g_paused || g_clock_held) return (double)g_played;
    double dt = now_sec() - g_played_t;
    if (dt < 0)    dt = 0;
    /* Cap must exceed the platform's consumer-update cadence: Android/AAudio
     * was measured updating set_played only every ~109 ms — the old 100 ms cap
     * froze the target every cycle and the renderer's correction dragged the
     * scroll backwards (sawtooth judder). */
    if (dt > 0.25) dt = 0.25;
    return (double)g_played + dt * g_rate;
}

/* Display playhead, SHARED by every visualizer that scrolls with the music.
 *
 * `rewamp_notes_played_interp` extrapolates the wall clock between two consumer
 * updates, but it SNAPS back to the truth at each audio callback, and callbacks
 * do not arrive on a perfect 20 ms grid: that snap is a few milliseconds of
 * position, i.e. a few hundredths of a tracker row, and it is what remained of
 * the pattern viz judder once the capture granularity was fixed. The notation
 * viz had solved it long ago with the clock below; the pattern viz was reading
 * the raw value, so the two visualizers did not even agree on the instant they
 * were showing. One implementation, one clock, both of them.
 *
 * Rate-locked and MONOTONIC while playing: advance at the track rate and trim
 * gently toward the truth, never backwards - a late consumer update leaving the
 * display ahead used to flash the whole scroll back a few tenths of a second.
 * Paused, it converges in BOTH directions so the small overshoot accumulated
 * before the pause flag landed glides back instead of freezing ahead. */
static double g_disp_last = 0.0;    /* dernière valeur rendue par played_smooth */
/* ⚠️ En horloge MURALE, jamais celle des frames: `rewamp_viz_frame_time` est
 * POUSSÉE par le viz qui rend, donc elle gèle elle aussi dès qu'aucun rendu ne
 * la met à jour — comparer deux horloges gelées donne un écart constant, et la
 * péremption ne se déclenchait jamais (constaté: libellés figés après un
 * passage par le viz-pattern, 2026-09-13). */
static double g_disp_last_t = 0.0;  /* et QUAND elle l'a été (horloge murale) */

double rewamp_notes_played_smooth(void) {
    static double disp = 0.0, vel = 0.0, lastT = 0.0, prevTarget = -1.0, changeT = 0.0;
    static int wasPaused = 0;
    static int catchUp = 0;   /* a discontinuity is being closed (see below) */
    static double catchT = 0.0;
    /* The render clock is the FLUTTER FRAME timestamp when we have it, not the
     * wall clock: a wall-clock reading taken at render time carries the FFI
     * scheduling jitter of the call itself, which trembles the scroll. Wall
     * clock only as a fallback (Android's own render thread, tests). */
    double tnow = rewamp_viz_frame_time();
    if (tnow < 0.0) tnow = now_sec();
    const double sr = g_rate;
    const double target = rewamp_notes_played_interp(0);

    if (lastT == 0.0) { disp = target; vel = sr; prevTarget = target; changeT = tnow; }
    double rdt = tnow - lastT;
    lastT = tnow;
    if (rdt < 0) rdt = 0;
    if (rdt > 0.1) rdt = 0.1;
    /* A DISCONTINUITY of the true position (a track change restarts it, a
     * short seek moves it) arms the fast catch-up below; ordinary playback
     * only ever moves it by one callback's worth (~20 ms, a few tenths after
     * a late callback), far under this. */
    if (target != prevTarget) {
        const double jump = target - prevTarget;
        if (prevTarget >= 0.0 && (jump > 0.2 * sr || jump < -0.2 * sr)) { catchUp = 1; catchT = tnow; }
        /* A BACKWARD jump past the extrapolation cap (0.25 s) is never
         * jitter — a track change or a seek back. Closing it through the
         * speed meant slowing the scroll to half speed for 2-3 s, the piano's
         * bars being born below the top all along (user log, 2026-09-11: a
         * track skipped after 0.9 s left the display 0.95 s ahead, under the
         * 1 s snap below). Snap, like the big jumps. */
        if (prevTarget >= 0.0 && jump < -0.3 * sr) { disp = target; vel = sr; }
        changeT = tnow; prevTarget = target;
    }

    const int paused  = rewamp_notes_paused();
    /* Advanced recently, and the new audio has started (a held clock is a
     * track that is loaded but not yet heard: the display waits with it). */
    const int playing = !paused && !g_clock_held && (tnow - changeT) < 0.6;
    const double diff = target - disp;

    if (diff > 1.0 * sr || diff < -1.0 * sr) {
        disp = target;                                       /* seek / big jump → snap */
        vel = sr;
    } else if (paused) {
        /* Transport pause: converge on the TRUE position in BOTH directions, so
         * the small overshoot accumulated before the pause flag landed glides
         * back instead of freezing ahead of the audio. */
        double k = rdt * 8.0; if (k > 1.0) k = 1.0;
        disp += diff * k;
        vel = 0.0;
    } else if (!playing) {
        /* Not paused, but nothing has advanced for 0.6 s - a stalled or ended
         * stream. Drift in FORWARD ONLY: a backwards correction flashes the
         * whole scroll back, which is worse than being a few ms early. */
        double k = rdt * 3.0; if (k > 0.5) k = 0.5;
        if (diff > 0) disp += diff * k;
        vel = 0.0;
    } else {
        /* The correction acts on the SPEED, and the position integrates it, so
         * nothing can step between two frames. Correcting the POSITION - what
         * this did - fed `target`'s sawtooth straight into the motion: the
         * consumer position only refreshes once per audio callback (21.3 ms on
         * an iPhone) while frames land every 16.7 ms, the two grids beat, and a
         * late callback (the device logs 300 ms gaps) lands as one visible jolt.
         *
         * Simulated over the real chain, per-frame advance wobble: 1.6 % with
         * the position correction, 0.72 % here - and after a 300 ms late
         * callback, 6.6 % against 0.7 %, i.e. the jolt disappears rather than
         * shrinking. Gains chosen on the same simulation: below kOffset 0.6 the
         * clock stops converging at all (a 40 ms offset never closes), above it
         * the wobble climbs back (1.14 % at 1.0). The trim is bounded to ±5 %
         * of the track rate so a correction can never read as a speed change,
         * and the speed itself is never negative: the scroll cannot walk back. */
        static const double kOffset = 0.6;   /* offset → speed trim, per second */
        static const double tauSecs = 0.30;  /* speed smoothing time constant   */
        static const double maxTrim = 0.05;  /* ±5 % of the track rate          */
        if (wasPaused) { vel = sr; }         /* resume at speed, not from zero  */
        /* After a DISCONTINUITY (a track change, a short seek — both under
         * the 1 s snap) the offset used to close at the same ±5 % as the
         * callback jitter: 0.27 s of error took eight seconds, and the
         * piano's falling bars were born below the top all along (user
         * report, 2026-09-10). Armed by the jump above, the trim widens (×2,
         * ±50 %) until the offset is under 20 ms — about a second, still
         * through the SPEED, so nothing steps between two frames. An OFFSET
         * threshold instead of the jump latch was tried and rejected: a late
         * callback crossed it and the frame-to-frame advance wobbled up to
         * 19 % (smooth_sim, against 2.9 % without). */
        /* Held two seconds at least: the jump itself snaps the display (over
         * 1 s), and the real offset only appears when the new track's audio
         * STARTS — a few tenths later, the display having run on meanwhile. */
        if (catchUp && tnow - catchT > 2.0 && diff < 0.02 * sr && diff > -0.02 * sr) catchUp = 0;
        const int big = catchUp;
        const double gain  = big ? 2.0 : kOffset;
        const double bound = big ? 0.50 : maxTrim;
        double trim = diff * gain;
        if (trim >  bound * sr) trim =  bound * sr;
        if (trim < -bound * sr) trim = -bound * sr;
        double velTarget = sr + trim;
        if (velTarget < 0.0) velTarget = 0.0;
        double a = rdt / tauSecs; if (a > 1.0) a = 1.0;
        vel += (velTarget - vel) * a;
        if (vel < 0.0) vel = 0.0;
        disp += vel * rdt;
    }
    wasPaused = paused || !playing;
    g_disp_last = disp;
    g_disp_last_t = now_sec();
    return disp;
}

/* Lecture SANS effet de bord de la tête de lecture affichée.
 *
 * ⚠️ `rewamp_notes_played_smooth` n'est PAS un accesseur: elle intègre une
 * vitesse sur le temps écoulé depuis son dernier appel, donc l'appeler hors
 * de la cadence de rendu (depuis un tick Dart, par exemple) fait avancer
 * l'horloge deux fois par image et dérègle le défilement de TOUS les
 * visualiseurs. Toute requête qui veut seulement SAVOIR où on en est passe
 * ici. Avant le premier rendu, on retombe sur la position interpolée. */
double rewamp_notes_played_display(void) {
    /* ⚠️ L'horloge lissée n'avance QUE si un rendu l'appelle — notation, piano
     * ou motifs. Sous l'OSCILLOSCOPE aucun de ces trois ne tourne: la dernière
     * valeur restait celle du dernier viz affiché, et toute requête datée
     * (instruments visibles, instrument par voie) répondait éternellement pour
     * cet instant-là. Vu dans le journal: `timeline=` figé sur plusieurs
     * secondes pendant que la source vivante changeait (2026-09-13).
     *
     * Périmée, on retombe donc sur la position INTERPOLÉE, qui ne dépend que
     * du consommateur. Le seuil est large devant une image (60-120 Hz) et
     * étroit devant le pas de capture. */
    if (g_disp_last > 0.0 && now_sec() - g_disp_last_t < 0.15) return g_disp_last;
    return rewamp_notes_played_interp(0);
}

/* ── Instruments VISIBLES (timeline, donc DATÉS) ──────────────────────────
 * Un libellé « par instrument » lu dans vgm_last_instr[] décrit ce que le
 * PRODUCTEUR vient de décoder — jusqu'à 2 s avant l'oreille — et ne connaît
 * qu'un instrument par voie, celui de l'instant. Or le piano en mode
 * « chute » montre 1,5 s de FUTUR: à l'écran cohabitent les instruments de
 * plusieurs instants. Ces deux requêtes lisent donc la TIMELINE, dont chaque
 * colonne porte sa position: l'instrument est daté, comme les notes.
 *
 * Fenêtre exprimée en secondes RELATIVES à la tête de lecture lissée (celle
 * que les visualiseurs dessinent), négatif = passé. Une voix COUPÉE ne se
 * dessine pas, donc elle ne nomme rien non plus. */
int rewamp_notes_instruments_window(double fromSec, double toSec,
                                    int32_t* out, int max) {
    const int vc = g_vc;
    if (vc <= 0 || !out || max <= 0) return 0;
    const double played = rewamp_notes_played_display();
    const int64_t from = (int64_t)(played + fromSec * g_rate);
    const int64_t to   = (int64_t)(played + toSec   * g_rate);
    const int64_t head = g_head;
    const int valid = (int)(head < NOTE_COLS ? head : NOTE_COLS);
    int n = 0;
    for (int64_t i = head - valid; i < head; i++) {
        const int slot = (int)(i & (NOTE_COLS - 1));
        const int64_t p = g_pos[slot];
        if (p < from || p > to) continue;
        for (int v = 0; v < vc && v < 64; v++) {
            if ((generic_mute_mask >> v) & 1) continue;   /* coupée = invisible */
            if (g_hz[slot][v] < 1.0f) continue;           /* rien ne sonne */
            const int ins = (int)g_instr[slot][v];
            if (ins <= 0) continue;
            int k = 0;
            while (k < n && out[k] != (int32_t)ins) k++;
            if (k == n && n < max) out[n++] = (int32_t)ins;
        }
    }
    /* Tri croissant (liste courte: une poignée d'instruments à l'écran). */
    for (int a = 1; a < n; a++) {
        const int32_t x = out[a];
        int b = a - 1;
        while (b >= 0 && out[b] > x) { out[b + 1] = out[b]; b--; }
        out[b + 1] = x;
    }
    return n;
}

/* Instrument de CHAQUE voie à la tête de lecture ENTENDUE (colonne la plus
 * récente au plus égale à `played`): ce que l'oscilloscope doit nommer, sa
 * forme d'onde étant elle aussi synchronisée sur le consommateur. 0 = rien. */
int rewamp_notes_voice_instruments(int32_t* out, int max) {
    const int vc = g_vc;
    if (vc <= 0 || !out || max <= 0) return 0;
    const int lim = vc < max ? vc : max;
    for (int v = 0; v < lim; v++) out[v] = 0;
    const double played = rewamp_notes_played_display();
    const int64_t at = (int64_t)played;
    const int64_t head = g_head;
    const int valid = (int)(head < NOTE_COLS ? head : NOTE_COLS);
    int64_t bestPos = INT64_MIN;
    int bestSlot = -1;
    for (int64_t i = head - valid; i < head; i++) {
        const int slot = (int)(i & (NOTE_COLS - 1));
        const int64_t p = g_pos[slot];
        if (p <= at && p > bestPos) { bestPos = p; bestSlot = slot; }
    }
    /* ⚠️ AUCUNE colonne à cet instant: rendre `lim` ferait passer un tableau de
     * ZÉROS pour une réponse valable, et l'appelant ne pourrait pas distinguer
     * « pas d'instrument » de « je ne sais pas » — son repli ne partirait
     * jamais. Rendre 0 dit « je ne sais pas ». */
    if (bestSlot < 0) return 0;
    int known = 0;
    for (int v = 0; v < lim; v++) {
        out[v] = (int32_t)g_instr[bestSlot][v];
        if (out[v] > 0) known = 1;
    }
    return known ? lim : 0;
}

int rewamp_notes_collect(int64_t fromSample, int64_t toSample,
                         float* outHz, uint8_t* outVol, uint8_t* outInstr,
                         int64_t* outPos, int maxCols) {
    const int vc = g_vc;
    if (vc <= 0 || !outHz || !outPos || maxCols <= 0) return 0;
    const int64_t head = g_head;
    int valid = (int)(head < NOTE_COLS ? head : NOTE_COLS);
    int64_t oldest = head - valid;
    int count = 0;
    for (int64_t i = oldest; i < head && count < maxCols; i++) {
        int slot = (int)(i & (NOTE_COLS - 1));
        int64_t p = g_pos[slot];
        if (p < fromSample || p > toSample) continue;
        outPos[count] = p;
        for (int v = 0; v < vc; v++) {
            outHz[count * vc + v]              = g_hz[slot][v];
            if (outVol)   outVol[count * vc + v]   = g_vol[slot][v];
            if (outInstr) outInstr[count * vc + v] = g_instr[slot][v];
        }
        count++;
    }
    return count;
}

int rewamp_notes_window(float* out, int cols, double aheadSec, int sampleRate) {
    const int vc = g_vc;
    if (!out || cols <= 0 || vc <= 0 || sampleRate <= 0) return 0;
    memset(out, 0, (size_t)cols * vc * sizeof(float));

    const int64_t head  = g_head;
    int valid = (int)(head < NOTE_COLS ? head : NOTE_COLS);
    if (valid <= 0) return vc;

    const int64_t oldest = head - valid;            /* column index of first valid */
    const int64_t played = g_played;
    const double  span   = aheadSec * (double)sampleRate;

    /* Merge-walk: columns are monotonic in pos, targets are monotonic in j. */
    int64_t ci = oldest;                             /* current column index */
    for (int j = 0; j < cols; j++) {
        int64_t target = played + (int64_t)(span * j / (cols > 1 ? (cols - 1) : 1));
        /* Advance ci while the next column is still <= target. */
        while (ci + 1 < head) {
            int nslot = (int)((ci + 1) & (NOTE_COLS - 1));
            if (g_pos[nslot] <= target) ci++;
            else break;
        }
        int slot = (int)(ci & (NOTE_COLS - 1));
        /* Only emit if the chosen column is at/after playback start of window. */
        if (g_pos[slot] <= target + (int64_t)span) {
            float* dst = out + (size_t)j * vc;
            for (int i = 0; i < vc; i++) dst[i] = g_hz[slot][i];
        }
    }
    return vc;
}
