#include "rewamp_notes.h"
#include "ModizerVoicesData.h"      /* vgm_last_note[] */
#include "rewamp_channel_data.h"    /* rewamp_channel_count() */
#include "rewamp_audio.h"           /* rewamp_viz_frame_time() */

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
    memset(g_hz, 0, sizeof(g_hz));
    memset(g_vol, 0, sizeof(g_vol));
    memset(g_instr, 0, sizeof(g_instr));
    memset(g_pos, 0, sizeof(g_pos));
}

void rewamp_notes_capture(int64_t producerSamplePos) {
    if (g_vc <= 0) return;
    int slot = (int)(g_head & (NOTE_COLS - 1));
    for (int i = 0; i < g_vc; i++) {
        g_hz[slot][i]    = (float)vgm_last_note[i];
        unsigned int vl  = vgm_last_vol[i];
        unsigned int ins = vgm_last_instr[i];
        g_vol[slot][i]   = (uint8_t)(vl  > 255 ? 255 : vl);
        g_instr[slot][i] = (uint8_t)(ins > 255 ? 255 : ins);
    }
    g_pos[slot] = producerSamplePos;
    g_head++;
}

void rewamp_notes_set_played(int64_t playedSamplePos) {
    g_played   = playedSamplePos;
    g_played_t = now_sec();
}

static volatile int g_paused = 0;
void rewamp_notes_set_paused(int paused) { g_paused = paused ? 1 : 0; }
int  rewamp_notes_paused(void)           { return g_paused; }

static double g_rate = 44100.0;
void   rewamp_notes_set_rate(int sampleRate) { if (sampleRate > 0) g_rate = (double)sampleRate; }
double rewamp_notes_rate(void)               { return g_rate; }

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
    if (g_paused) return (double)g_played;
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
double rewamp_notes_played_smooth(void) {
    static double disp = 0.0, vel = 0.0, lastT = 0.0, prevTarget = -1.0, changeT = 0.0;
    static int wasPaused = 0;
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
    if (target != prevTarget) { changeT = tnow; prevTarget = target; }

    const int paused  = rewamp_notes_paused();
    const int playing = !paused && (tnow - changeT) < 0.6;   /* advanced recently */
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
        double trim = diff * kOffset;
        if (trim >  maxTrim * sr) trim =  maxTrim * sr;
        if (trim < -maxTrim * sr) trim = -maxTrim * sr;
        double velTarget = sr + trim;
        if (velTarget < 0.0) velTarget = 0.0;
        double a = rdt / tauSecs; if (a > 1.0) a = 1.0;
        vel += (velTarget - vel) * a;
        if (vel < 0.0) vel = 0.0;
        disp += vel * rdt;
    }
    wasPaused = paused || !playing;
    return disp;
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
