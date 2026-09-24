#include "rewamp_pattern.h"

#include <stdint.h>
#include <string.h>

/* Smooth, per-frame consumer position from the notes clock (wall-clock
 * interpolated between the coarse set_played updates — ~20 ms on macOS, ~109 ms
 * on Android). The producer feeds rewamp_notes_set_played on the SAME cadence as
 * our own set_played, so this is our consumer position too, but continuous — the
 * raw g_pat_played steps too coarsely for smooth sub-row scrolling. */
extern double rewamp_notes_played_interp(int sampleRate);
extern double rewamp_notes_played_smooth(void);

/* Live playback-cursor ring, keyed by producer sample position — the exact
 * mechanism rewamp_notes.c uses for the notation viz, but each column stores an
 * (order,row) pair instead of per-voice frequencies. The producer writes ahead
 * of playback; the UI reads the column matching the consumer (heard) position,
 * so the highlighted pattern row is the one being heard, not the one decoded
 * up to ~2 s ahead. Lock-free: a torn read during a 60 fps poll is harmless.
 *
 * NOTE: the file names below are g_pat_*-prefixed on purpose — the Apple build
 * unity-#includes this TU together with rewamp_notes.c (Classes/rewamp_audio.c),
 * so a bare g_head/g_played/g_pos would collide with that file's statics. */

/* Ring capacity (power of two). Sized in TIME, not in columns: the viz can ask
 * for up to kPatternLookaheadMaxSecs = 8 s of look-ahead, and the ring holds the
 * LAST PAT_COLS captures — so if it covers less than that, the position being
 * HEARD falls off the back of the ring and the cursor lands on whatever is
 * oldest, i.e. on a row seconds away from the music. At one capture per
 * DS_CURSOR_SUB_FRAMES = 32 frames, 16384 columns cover 11.9 s. 196 KB. */
#define PAT_COLS 16384

static int16_t          g_pat_ord[PAT_COLS];
static int16_t          g_pat_row[PAT_COLS];
static int64_t          g_pat_pos[PAT_COLS];
static volatile int64_t g_pat_head   = 0;   /* monotonic column counter */
static volatile int64_t g_pat_played = 0;   /* consumer sample position */
static volatile int     g_pat_active = 0;   /* 1 once a cursor is captured */
static volatile unsigned g_pat_gen   = 0;   /* bumped per track load / seek */

/* ── ÉPOQUE DE MORCEAU ────────────────────────────────────────────────────────
 * Un relais gapless échange le décodeur des SECONDES avant que l'oreille
 * n'atteigne la frontière (le viz-pattern demande lui-même une avance
 * proportionnelle à une demi-hauteur d'écran). Effacer la réserve à ce
 * moment-là jetait précisément la queue du morceau EN COURS: le motif
 * s'arrêtait avant la fin, et c'est le viz qui creusait son propre angle mort.
 *
 * La réserve est clefée par position ABSOLUE, donc elle peut porter les DEUX
 * morceaux à la fois. Il suffit d'étiqueter chaque capture: le lecteur rend
 * celle qui correspond à la position ENTENDUE avec son époque, et l'appelant
 * (le renderer GL) sait alors s'il regarde encore le morceau précédent — auquel
 * cas il ne doit surtout pas rafraîchir sa table d'ordres, qui décrirait déjà
 * le suivant. La bascule se fait quand l'oreille franchit, comme tout le reste
 * du gapless. */
static uint16_t          g_pat_ep[PAT_COLS];
static volatile unsigned g_pat_live_ep = 0;   /* époque que le producteur capture */
static volatile unsigned g_pat_heard_ep = 0;  /* époque de la dernière lecture */

unsigned rewamp_pattern_song_generation(void) { return g_pat_gen; }
unsigned rewamp_pattern_live_epoch(void)  { return g_pat_live_ep; }
unsigned rewamp_pattern_heard_epoch(void) { return g_pat_heard_ep; }

void rewamp_pattern_cursor_reset(void) {
    g_pat_gen++;   /* GL renderer: drop the cached tessellation */
    g_pat_head   = 0;
    g_pat_played = 0;
    g_pat_active = 0;
    g_pat_live_ep  = 0;
    g_pat_heard_ep = 0;
    memset(g_pat_ord, -1, sizeof(g_pat_ord));
    memset(g_pat_row, -1, sizeof(g_pat_row));
    memset(g_pat_pos, 0, sizeof(g_pat_pos));
    memset(g_pat_ep,  0, sizeof(g_pat_ep));
}

/* Relais gapless: le décodeur a changé, la réserve NON. Les captures suivantes
 * décrivent le nouveau morceau et sont étiquetées comme telles; celles d'avant
 * restent lisibles jusqu'à ce que l'oreille les dépasse. */
void rewamp_pattern_cursor_new_epoch(void) {
    g_pat_live_ep++;
}

void rewamp_pattern_cursor_capture(int64_t producerSamplePos, int order, int row) {
    int slot = (int)(g_pat_head & (PAT_COLS - 1));
    g_pat_ord[slot] = (int16_t)order;
    g_pat_row[slot] = (int16_t)row;
    g_pat_pos[slot] = producerSamplePos;
    g_pat_ep[slot]  = (uint16_t)g_pat_live_ep;
    g_pat_head++;
    g_pat_active = 1;
}

void rewamp_pattern_cursor_set_played(int64_t playedSamplePos) {
    g_pat_played = playedSamplePos;
}

int rewamp_pattern_cursor(int* order, int* row) {
    if (order) *order = -1;
    if (row)   *row   = -1;
    if (!g_pat_active) return 0;

    const int64_t head = g_pat_head;
    if (head == 0) return 0;
    int valid = (int)(head < PAT_COLS ? head : PAT_COLS);
    int64_t oldest = head - valid;
    const int64_t played = g_pat_played;

    /* Walk newest→oldest, pick the last column whose producer position is at or
     * before the heard position. Columns are monotonic in pos, so the first hit
     * scanning backwards is the answer; fall back to the oldest still buffered
     * (playback just started / after a seek the store is nearly empty). */
    int slot = (int)(oldest & (PAT_COLS - 1));   /* default: oldest */
    for (int64_t i = head - 1; i >= oldest; i--) {
        int s = (int)(i & (PAT_COLS - 1));
        if (g_pat_pos[s] <= played) { slot = s; break; }
    }
    if (order) *order = g_pat_ord[slot];
    if (row)   *row   = g_pat_row[slot];
    g_pat_heard_ep = g_pat_ep[slot];
    return 1;
}

int rewamp_pattern_cursor_frac(int* order, int* row, float* frac) {
    if (frac) *frac = 0.0f;
    if (order) *order = -1;
    if (row)   *row   = -1;
    if (!g_pat_active) return 0;

    const int64_t head = g_pat_head;
    if (head == 0) return 0;
    int valid = (int)(head < PAT_COLS ? head : PAT_COLS);
    int64_t oldest = head - valid;
    /* SMOOTHED consumer position, the same clock the notation viz scrolls on.
     * Not the raw interpolated one: that snaps back to the truth at every audio
     * callback, and callbacks do not land on a perfect grid - those few
     * milliseconds are a few hundredths of a row, i.e. the small hiccups left
     * once the capture granularity was fixed. The clock is rate-locked and
     * monotonic, so it never walks backwards either.
     *
     * No "never behind g_pat_played" clamp any more: it snapped the position
     * forward at each callback, which is exactly the jitter being removed here.
     * A display a few milliseconds behind the audio is not visible; a snap is. */
    int64_t played = (int64_t)rewamp_notes_played_smooth();

    /* Same newest→oldest walk as rewamp_pattern_cursor, but remember the column
     * INDEX i (not just the ring slot) so we can look at the NEXT capture for
     * interpolation. */
    int64_t found = oldest;   /* default: oldest still buffered */
    for (int64_t i = head - 1; i >= oldest; i--) {
        int s = (int)(i & (PAT_COLS - 1));
        if (g_pat_pos[s] <= played) { found = i; break; }
    }
    int slot = (int)(found & (PAT_COLS - 1));
    const int16_t curOrd = g_pat_ord[slot];
    const int16_t curRow = g_pat_row[slot];
    if (order) *order = curOrd;
    if (row)   *row   = curRow;
    g_pat_heard_ep = g_pat_ep[slot];

    /* Sub-ROW fraction. The producer captures once per decode CHUNK, not once per
     * row, so a single row can span several captures with the same (order,row):
     * interpolating between adjacent captures would give sub-chunk progress and
     * jitter. Instead find the sample span of THIS row — from the first capture
     * that entered it (walk back over equal (order,row)) to the first capture of
     * the NEXT row (walk forward) — and place `played` inside that span. The
     * producer runs ~2 s ahead, so the next row's capture is normally buffered.
     * Leave frac 0 when the next row isn't captured yet or the span isn't
     * forward (pattern break/loop → snap, don't glide backwards). */
    int64_t rowStart = g_pat_pos[slot];
    for (int64_t i = found - 1; i >= oldest; i--) {
        int s = (int)(i & (PAT_COLS - 1));
        if (g_pat_ep[s] != g_pat_ep[slot]) break;   /* autre morceau */
        if (g_pat_ord[s] != curOrd || g_pat_row[s] != curRow) break;
        rowStart = g_pat_pos[s];
    }
    int64_t nextStart = -1;
    for (int64_t i = found + 1; i < head; i++) {
        int s = (int)(i & (PAT_COLS - 1));
        /* Une capture du morceau SUIVANT ne borne pas la ligne en cours: la
         * fraction glisserait vers un temps qui n'appartient pas à ce motif. */
        if (g_pat_ep[s] != g_pat_ep[slot]) break;
        if (g_pat_ord[s] != curOrd || g_pat_row[s] != curRow) { nextStart = g_pat_pos[s]; break; }
    }
    if (nextStart > rowStart && played >= rowStart) {
        double f = (double)(played - rowStart) / (double)(nextStart - rowStart);
        if (f < 0.0) f = 0.0; else if (f > 0.99999) f = 0.99999;
        if (frac) *frac = (float)f;
    }
    return 1;
}
