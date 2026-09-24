#include "miniaudio.h"
#include "rewamp_audio.h"
#include "rewamp_registry.h"
#include "rewamp_datasource.h"
#include "rewamp_waveform.h"
#include "rewamp_channel_data.h"
#include "rewamp_loaded_files.h"
#include "rewamp_notes.h"       /* rewamp_notes_set_paused */
#include "rewamp_pattern.h"
#include "ModizerVoicesData.h"  /* modizChipset*, generic_mute_mask, m_voice_ChipID */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>   /* clock_gettime — waveform read-head smoothing */
#include <pthread.h> /* background seek thread — see rewamp_seek_seconds() */

#ifdef REWAMP_WITH_PROWIZARD
#include <dirent.h>
#include <sys/stat.h>
#ifdef _WIN32
#include <direct.h>
#endif
#include "rewamp_assets.h"      /* rewamp_get_data_dir */
/* Relative on purpose: third_party/prowizard/ holds generic header names
 * (common.h, format.h, hio.h) that must never land on an include path. */
#include "../third_party/prowizard/rewamp_prowizard.h"
#endif

// Android foreground service — start/stop via JNI (defined in rewamp_viz_android.cpp).
// No-ops on all other platforms.
#ifdef __ANDROID__
void rewamp_android_start_service(void);
void rewamp_android_stop_service(void);
#else
static inline void rewamp_android_start_service(void) {}
static inline void rewamp_android_stop_service(void) {}
#endif

/* ---------------------------------------------------------------------------
 * Oscilloscope ring buffer
 * Audio thread writes; Dart/UI thread reads.  We intentionally skip locking:
 * a torn read during a 60-fps oscilloscope poll is imperceptible.
 * --------------------------------------------------------------------------- */
static float          g_wf_left[REWAMP_WAVEFORM_FRAMES];
static float          g_wf_right[REWAMP_WAVEFORM_FRAMES];
static volatile int   g_wf_pos = 0;   /* write head (unbounded counter) */

/* Silence detection: counts consecutive near-silent output frames. The engine
 * runs at 44100 Hz, so silent_seconds = g_silent_frames / 44100. Reset on
 * load/seek. Used by the Dart layer to auto-skip to the next track when a song
 * has effectively ended (e.g. a PSF with no length tag that fades to silence). */
#define REWAMP_SILENCE_EPS 0.0008f   /* ~ |sample| < 26/32768 */
static volatile int64_t g_silent_frames = 0;

void rewamp_waveform_write(const float* pcm, uint64_t frame_count, int channels) {
    if (channels < 1) channels = 1;
    /* Mono (channels==1): L and R mirror the single channel. Stereo+: take the
     * first two channels. Previously this hardcoded a stride of 2, so a mono
     * source (e.g. an 11025 Hz vgmstream .rrds) over-read past the buffer and
     * scrambled both the stereo and voice oscilloscopes. */
    const int rc = channels > 1 ? 1 : 0;   /* right-channel offset */
    int64_t silent = g_silent_frames;
    for (uint64_t i = 0; i < frame_count; i++) {
        float l = pcm[i * channels];
        float r = pcm[i * channels + rc];
        int pos         = g_wf_pos & (REWAMP_WAVEFORM_FRAMES - 1);
        g_wf_left[pos]  = l;
        g_wf_right[pos] = r;
        g_wf_pos++;

        float al = l < 0 ? -l : l;
        float ar = r < 0 ? -r : r;
        if (al < REWAMP_SILENCE_EPS && ar < REWAMP_SILENCE_EPS) silent++;
        else silent = 0;
    }
    g_silent_frames = silent;
}

/* Seconds of continuous silence at the output, or 0 while audio is present. */
double rewamp_silent_seconds(void) {
    return (double)g_silent_frames / 44100.0;
}

/* Reset the silence counter (call on load / seek so a fresh track isn't
 * immediately judged silent by leftover state). */
void rewamp_reset_silence(void) { g_silent_frames = 0; }

/* « Le décodeur a encore de la matière »: un morceau SÉQUENCÉ dont il reste des
 * événements à jouer n'est pas fini, même si sa sortie est muette à cet
 * instant.
 *
 * Le cas qui l'impose: un MIDI MT-32 passe ses premières secondes à PROGRAMMER
 * le synthé (banque de timbres, réverbération, assignation des parties). Le
 * flux d'événements est dense, la sortie audio parfaitement silencieuse, et le
 * saut automatique des silences (Réglages → Lecture) concluait « fin de piste »
 * puis avançait la file — le morceau était sauté avant d'avoir commencé.
 *
 * ⚠️ Ce n'est pas la même chose que `rewamp_reset_silence`, qui repart d'un
 * chargement ou d'un seek: ici c'est le DÉCODEUR qui dit qu'il travaille, à
 * chaque passe de lecture. Écriture racée assumée (même discipline que les
 * compteurs de télémétrie): le producteur écrit, le rappel audio écrit aussi,
 * et une remise à zéro perdue coûte un tour de compteur, rien de plus. */
void rewamp_decoder_activity(void) { g_silent_frames = 0; }

/* Oscilloscope line thickness multiplier (0.5–3); applied by the GL renderers
 * as a ribbon half-width. 1.0 = default. */
static volatile float g_viz_line_width = 1.0f;
void  rewamp_set_viz_line_width(float w) {
    if (w < 0.25f) w = 0.25f;
    if (w > 4.0f)  w = 4.0f;
    g_viz_line_width = w;
}
float rewamp_get_viz_line_width(void) { return g_viz_line_width; }

/* CRT effect levels packed into one int (set from settings):
 *   bits 0-1 = glow level  (0=off, 1=low, 2=high)
 *   bits 2-3 = speed level (0=off, 1=low, 2=high) */
static volatile int g_crt_flags = 0;
void rewamp_set_crt_flags(int mask) { g_crt_flags = mask; }
int  rewamp_get_crt_flags(void)     { return g_crt_flags; }

/* Frame timestamp for the visualizers, set by Dart from the Flutter Ticker's
 * vsync-aligned elapsed time BEFORE each render_and_notify. Rendering clocks
 * (the notes scroll) must use THIS, not wall-clock-at-render: FFI ticks reach
 * us with ±ms of scheduling jitter, so a wall-clock-dated frame advances the
 * content irregularly even though presentation is perfectly regular →
 * permanent micro-trembling. Flutter's own animations are smooth for exactly
 * this reason (they animate on the frame timestamp). -1 = not provided
 * (renderer falls back to wall clock). */
static volatile double g_viz_frame_time = -1.0;
void   rewamp_viz_set_frame_time(double t) { g_viz_frame_time = t; }
double rewamp_viz_frame_time(void)         { return g_viz_frame_time; }


/* Decode-ahead (look-ahead) for the scrolling-notation visualizer. Off by
 * default: the decoder stays consumer-paced so the oscilloscopes are synced to
 * the heard audio. Enabled only while the notation visualizer is shown. */
static volatile int    g_lookahead = 0;
/* Explicit look-ahead target in SECONDS (0 = off → consumer-paced). A
 * visualizer sets exactly what it needs: the pattern viz scales it with the
 * on-screen row count (a fullscreen grid shows more future rows than a small
 * one), the notation viz asks for its fixed future window. 0 falls back to the
 * binary flag for older callers. Clamped by the datasource to the ring size. */
static volatile double g_lookahead_secs = 0.0;
/* The two setters are kept in lockstep so the seconds value is always
 * authoritative — otherwise clearing one (viz hidden → set 0) left the other
 * asserting a lead and the decode-ahead never shrank back. */
void rewamp_set_lookahead(int on) {
    g_lookahead      = on ? 1 : 0;
    g_lookahead_secs = on ? 2.0 : 0.0;   /* legacy binary → the old fixed 2 s */
}
int    rewamp_get_lookahead(void)         { return g_lookahead; }
void   rewamp_set_lookahead_seconds(double s) {
    if (s < 0.0) s = 0.0;
    g_lookahead_secs = s;
    g_lookahead      = (s > 0.0) ? 1 : 0;   /* 0 clears BOTH → back to minimum */
}
double rewamp_get_lookahead_seconds(void) { return g_lookahead_secs; }

/* ── Oscilloscope colors (RGB 0..1) ─────────────────────────────────────────
 * Voice scope + stereo mono use a single color; stereo bi-color uses L/R. */
static volatile float g_scope_col[3]   = { 0.00f, 1.00f, 0.27f }; /* green   */
static volatile float g_stereo_mono[3] = { 0.00f, 1.00f, 0.27f }; /* green   */
static volatile float g_stereo_l[3]    = { 0.42f, 0.78f, 1.00f }; /* lt blue */
static volatile float g_stereo_r[3]    = { 1.00f, 0.42f, 0.12f }; /* orange  */
static volatile int   g_stereo_bicolor = 1;
/* Spectrum palette: 0 = the scope colors, 1 = colored by frequency (Modizer). */
static volatile int   g_spectrum_palette = 0;

void rewamp_set_scope_color(float r, float g, float b)        { g_scope_col[0]=r;  g_scope_col[1]=g;  g_scope_col[2]=b; }
void rewamp_set_stereo_mono_color(float r, float g, float b)  { g_stereo_mono[0]=r;g_stereo_mono[1]=g;g_stereo_mono[2]=b; }
void rewamp_set_stereo_left_color(float r, float g, float b)  { g_stereo_l[0]=r;   g_stereo_l[1]=g;   g_stereo_l[2]=b; }
void rewamp_set_stereo_right_color(float r, float g, float b) { g_stereo_r[0]=r;   g_stereo_r[1]=g;   g_stereo_r[2]=b; }
void rewamp_set_stereo_bicolor(int on)                        { g_stereo_bicolor = on ? 1 : 0; }
void rewamp_set_spectrum_palette(int mode)                    { g_spectrum_palette = mode; }

const float* rewamp_scope_color(void)        { return (const float*)g_scope_col; }
const float* rewamp_stereo_mono_color(void)  { return (const float*)g_stereo_mono; }
const float* rewamp_stereo_left_color(void)  { return (const float*)g_stereo_l; }
const float* rewamp_stereo_right_color(void) { return (const float*)g_stereo_r; }
int          rewamp_stereo_bicolor(void)     { return g_stereo_bicolor; }
int          rewamp_spectrum_palette(void)   { return g_spectrum_palette; }

/* ── Voice / chipset grouping + muting (Dart FFI) ───────────────────────────
 * Thin, thread-safe accessors over the grouping metadata + generic_mute_mask.
 * When a plugin registered no chips, we synthesize a single chip "—" spanning
 * all voices and name voices "Voice N", so the UI always has something to show. */

int rewamp_voice_count(void) { return rewamp_channel_count(); }
int rewamp_voice_count_raw(void) { return rewamp_channel_count_raw(); }

int rewamp_chip_count(void) {
    return modizChipsetCount > 0 ? modizChipsetCount : 1;
}

int rewamp_chip_voice_start(int c) {
    if (modizChipsetCount <= 0) return c == 0 ? 0 : 0;      /* synthetic chip 0 */
    if (c < 0 || c >= modizChipsetCount) return 0;
    return (int)modizChipsetStartVoice[c];
}

int rewamp_chip_voice_count(int c) {
    if (modizChipsetCount <= 0) return c == 0 ? rewamp_channel_count() : 0;
    if (c < 0 || c >= modizChipsetCount) return 0;
    return (int)modizChipsetVoicesCount[c];
}

int rewamp_voice_chip(int v) {
    if (modizChipsetCount <= 0) return 0;                   /* all in synthetic chip 0 */
    if (v < 0 || v >= SOUND_MAXVOICES_BUFFER_FX) return 0;
    /* Derive from the registered chip ranges — NOT m_voice_ChipID, which some
     * cores (libvgm) repurpose as a device-id routing table for scope writes. */
    for (int c = 0; c < modizChipsetCount; c++) {
        int start = modizChipsetStartVoice[c];
        int count = modizChipsetVoicesCount[c];
        if (v >= start && v < start + count) return c;
    }
    return 0;
}

int rewamp_chip_name(int c, char* out, int len) {
    if (!out || len <= 0) return 0;
    const char* name;
    if (modizChipsetCount <= 0) {
        name = "\xE2\x80\x94";                              /* em dash "—" */
    } else if (c < 0 || c >= modizChipsetCount || modizChipsetName[c][0] == '\0') {
        name = "\xE2\x80\x94";
    } else {
        name = modizChipsetName[c];
    }
    int n = snprintf(out, (size_t)len, "%s", name);
    return n < 0 ? 0 : (n >= len ? len - 1 : n);
}

int rewamp_voice_name(int v, char* out, int len) {
    if (!out || len <= 0) return 0;
    int n;
    if (v >= 0 && v < SOUND_MAXVOICES_BUFFER_FX && modizVoicesName[v][0] != '\0')
        n = snprintf(out, (size_t)len, "%s", modizVoicesName[v]);
    else
        n = snprintf(out, (size_t)len, "Voice %d", v + 1);  /* synthetic default */
    return n < 0 ? 0 : (n >= len ? len - 1 : n);
}

/* Nom d'un INSTRUMENT (index de vgm_last_instr[]). Repli « Inst n »: tous les
 * moteurs n'ont pas de noms, et un numéro reste une identité utilisable. */
int rewamp_instrument_name(int idx, char* out, int len) {
    if (!out || len <= 0) return 0;
    int n;
    if (idx > 0 && idx < MODIZ_MAX_INSTR && modizInstrName[idx][0] != '\0')
        n = snprintf(out, (size_t)len, "%s", modizInstrName[idx]);
    else
        n = snprintf(out, (size_t)len, "Inst %d", idx);
    return n < 0 ? 0 : (n >= len ? len - 1 : n);
}

/* Instrument joué EN CE MOMENT par la voix v (0 = aucun / moteur sans notion
 * d'instrument). Lu au rendu par la légende « par instrument » du piano. */
int rewamp_voice_instrument(int v) {
    if (v < 0 || v >= SOUND_MAXVOICES_BUFFER_FX) return 0;
    return (int)vgm_last_instr[v];
}

/* Les instruments de TOUTES les voies en UN appel: l'UI les relit à cadence
 * rapide pour suivre un changement d'instrument, et un appel FFI par voie (×
 * 64 voies × 60 img/s) coûterait pour rien. Rend le nombre d'entrées écrites. */
int rewamp_voice_instruments(int32_t* out, int max) {
    if (!out || max <= 0) return 0;
    int n = SOUND_MAXVOICES_BUFFER_FX < max ? SOUND_MAXVOICES_BUFFER_FX : max;
    for (int v = 0; v < n; v++) out[v] = (int32_t)vgm_last_instr[v];
    return n;
}

/* Génération des NOMS d'instruments (voir rewamp_channel_data.c): l'UI ne
 * relit une chaîne que lorsqu'elle change. */
unsigned rewamp_instrument_names_generation(void) { return rewamp_instrument_names_gen(); }

int64_t rewamp_get_voice_mute_mask(void) { return generic_mute_mask; }
void    rewamp_set_voice_mute_mask(int64_t mask) { generic_mute_mask = mask; }

void rewamp_get_waveform(float* leftOut, float* rightOut, int count) {
    /* Smooth the read head. Audio callbacks write the ring in device-sized
     * bursts — AAudio on Android can deliver ~2048 frames per callback, i.e.
     * the WHOLE scope window — so reading at the raw write head makes the
     * window teleport once per burst: the scope strobes between unrelated
     * waveforms instead of scrolling (very visible at 120 Hz). Follow the
     * head with a rate-estimating tracker paced by wall-clock time so the
     * window advances continuously; clamps keep it within half a window of
     * the freshest data (small-burst platforms are effectively unchanged). */
    static int64_t         sm_pos = 0, last_target = 0;
    static double          rate = 44100.0;
    static struct timespec last = {0, 0};
    struct timespec now;
#ifdef _WIN32
    timespec_get(&now, TIME_UTC);          /* MSVC has no clock_gettime */
#else
    clock_gettime(CLOCK_MONOTONIC, &now);  /* Android NDK lacks timespec_get */
#endif
    int64_t target = (int64_t)g_wf_pos;
    if (last.tv_sec != 0) {
        double dt = (double)(now.tv_sec - last.tv_sec)
                  + (double)(now.tv_nsec - last.tv_nsec) / 1e9;
        if (dt > 0.0 && dt < 1.0) {
            if (target > last_target) {          /* estimate the real write rate */
                double inst = (double)(target - last_target) / dt;
                if (inst > 1000.0 && inst < 400000.0) rate = rate * 0.9 + inst * 0.1;
            }
            sm_pos += (int64_t)(dt * rate);
        } else {
            sm_pos = target;                     /* long gap (pause/seek) → snap */
        }
    } else {
        sm_pos = target;
    }
    last = now;
    last_target = target;
    if (sm_pos > target) sm_pos = target;                       /* never ahead  */
    if (target - sm_pos > REWAMP_WAVEFORM_FRAMES / 2)           /* bounded lag  */
        sm_pos = target - REWAMP_WAVEFORM_FRAMES / 2;

    int end   = (int)sm_pos;
    int start = end - count;
    for (int i = 0; i < count; i++) {
        int pos       = (start + i) & (REWAMP_WAVEFORM_FRAMES - 1);
        leftOut[i]  = g_wf_left[pos];
        rightOut[i] = g_wf_right[pos];
    }
}

/* Read the last `n` samples of the main output waveform for one stereo channel
 * (0 = left, 1 = right) as 8-bit signed values. Used as the per-voice scope
 * fallback for backends that produce no per-channel data (e.g. vgmstream).
 * Returns the number of samples written (≤ n, ≤ ring size). */
/* Monotonic write head of the main waveform ring — lets the per-voice scope
 * fallback detect "new data available" the same way it does for real voices. */
int64_t rewamp_waveform_pos(void) { return (int64_t)g_wf_pos; }

int rewamp_waveform_read_i8(int channel, int8_t* out, int n) {
    if (channel < 0 || channel > 1 || !out) return 0;
    const float* src = (channel == 0) ? g_wf_left : g_wf_right;
    int end   = g_wf_pos;
    int avail = (end < REWAMP_WAVEFORM_FRAMES) ? end : REWAMP_WAVEFORM_FRAMES;
    if (n > avail) n = avail;
    if (n <= 0) return 0;
    int start = end - n;
    for (int i = 0; i < n; i++) {
        int pos = (start + i) & (REWAMP_WAVEFORM_FRAMES - 1);
        float f = src[pos];
        if (f >  1.0f) f =  1.0f;
        if (f < -1.0f) f = -1.0f;
        out[i] = (int8_t)(f * 127.0f);
    }
    return n;
}

static ma_engine         g_engine;
static ma_sound          g_sound;
static RewampDataSource  g_dataSource;     // used when a plugin decodes the file
static int               g_initialized = 0;
static int               g_sound_loaded = 0;
static int               g_using_plugin = 0;  // 1 if g_sound is backed by g_dataSource

static void engine_param_notify(const char* engine, const char* key) {
    if (!g_using_plugin || !g_dataSource.vt) return;
    const RewampPluginVTable* vt = g_dataSource.vt;
    if (!vt->engine_id || !vt->param_changed) return;
    if (strcmp(vt->engine_id, engine) != 0) return;
    pthread_mutex_lock(&g_dataSource.decodeLock);
    vt->param_changed(g_dataSource.decoder, key);
    pthread_mutex_unlock(&g_dataSource.decodeLock);
}

/* ── Tracker-pattern view FFI ────────────────────────────────────────────────
 * Dispatch static pattern queries to the active plugin's vtable slots. Held
 * under decodeLock so a concurrent rewamp_load_file()/close() (which tears down
 * g_dataSource under the same discipline) cannot free the plugin's immutable
 * pattern table between the NULL check and the read. The plugin builds that
 * table in open() and only reads it here (no libopenmpt/Furnace re-entry), so
 * this never contends with the producer's own decode beyond the brief lock. */
static const RewampPluginVTable* pattern_vt(void) {
    if (!g_using_plugin || !g_dataSource.vt) return NULL;
    return g_dataSource.vt;
}

int rewamp_pattern_supported(void) {
    const RewampPluginVTable* vt = pattern_vt();
    return (vt && vt->pattern_song_info && vt->pattern_get) ? 1 : 0;
}

int rewamp_pattern_song_info(RewampPatternSongInfo* out) {
    if (!out) return 0;
    /* Zero FIRST: the per-song field widths are optional, and a plugin written
     * before they existed sets only the four original members. 0 is the
     * documented "use the default" value, so the caller must not see stack
     * garbage in the fields the plugin skipped. */
    memset(out, 0, sizeof(*out));
    const RewampPluginVTable* vt = pattern_vt();
    if (!vt || !vt->pattern_song_info) return 0;
    pthread_mutex_lock(&g_dataSource.decodeLock);
    int ok = vt->pattern_song_info(g_dataSource.decoder, out);
    pthread_mutex_unlock(&g_dataSource.decodeLock);
    return ok;
}

int rewamp_pattern_order(int order) {
    const RewampPluginVTable* vt = pattern_vt();
    if (!vt || !vt->pattern_order) return -1;
    pthread_mutex_lock(&g_dataSource.decodeLock);
    int p = vt->pattern_order(g_dataSource.decoder, order);
    pthread_mutex_unlock(&g_dataSource.decodeLock);
    return p;
}

int rewamp_pattern_num_rows(int pattern) {
    const RewampPluginVTable* vt = pattern_vt();
    if (!vt || !vt->pattern_num_rows) return 0;
    pthread_mutex_lock(&g_dataSource.decodeLock);
    int r = vt->pattern_num_rows(g_dataSource.decoder, pattern);
    pthread_mutex_unlock(&g_dataSource.decodeLock);
    return r;
}

int rewamp_pattern_get(int pattern, RewampPatternCell* out, int maxCells) {
    if (!out || maxCells <= 0) return 0;
    const RewampPluginVTable* vt = pattern_vt();
    if (!vt || !vt->pattern_get) return 0;
    pthread_mutex_lock(&g_dataSource.decodeLock);
    int n = vt->pattern_get(g_dataSource.decoder, pattern, out, maxCells);
    pthread_mutex_unlock(&g_dataSource.decodeLock);
    return n;
}

static const char*       g_backend_name = "";

/* Forced-loop setting (Settings → Lecture), snapshotted at load time — see
 * rewamp_set_forced_loop()/rewamp_has_native_loop_support() below. NOT
 * static: plugins whose native loop/fade config must be applied before
 * their own internal "start" step (earlier than the configure_loop vtable
 * hook fires) read these directly from inside their own open() — see
 * rewamp_plugin_vgm.cpp / rewamp_plugin_vgmstream.cpp. */
/* ── Generic engine parameters (Settings → Moteurs) ─────────────────────────
 * Small upsert table; plugins query in open(). Doubles cover bools/enums. */
typedef struct { char engine[16]; char key[24]; double value; } EngineParam;
#define MAX_ENGINE_PARAMS 128
static EngineParam g_engine_params[MAX_ENGINE_PARAMS];
static int         g_engine_param_count = 0;

/* Live apply: when the playing plugin declares this engine + a param_changed
 * hook, re-apply immediately (under the decode lock — the audio thread calls
 * into the same decoder). */
static void engine_param_notify(const char* engine, const char* key);

void rewamp_set_engine_param(const char* engine, const char* key, double value) {
    if (!engine || !key) return;
    int changed = 1;
    int found = 0;
    for (int i = 0; i < g_engine_param_count; i++) {
        if (strcmp(g_engine_params[i].engine, engine) == 0 &&
            strcmp(g_engine_params[i].key, key) == 0) {
            changed = (g_engine_params[i].value != value);
            g_engine_params[i].value = value;
            found = 1;
            break;
        }
    }
    if (!found) {
        if (g_engine_param_count >= MAX_ENGINE_PARAMS) return;
        EngineParam* p = &g_engine_params[g_engine_param_count++];
        snprintf(p->engine, sizeof(p->engine), "%s", engine);
        snprintf(p->key,    sizeof(p->key),    "%s", key);
        p->value = value;
    }
    if (changed) engine_param_notify(engine, key);
}

double rewamp_get_engine_param(const char* engine, const char* key, double defval) {
    for (int i = 0; i < g_engine_param_count; i++) {
        if (strcmp(g_engine_params[i].engine, engine) == 0 &&
            strcmp(g_engine_params[i].key, key) == 0)
            return g_engine_params[i].value;
    }
    return defval;
}

int           g_force_loop_mode          = 0;  /* 0=off, 1=on, 2=infinite */
int           g_force_loop_count         = 0;
int           g_force_fadeout_enabled    = 0;
double        g_force_fadeout_seconds    = 0.0;
/* Known single-pass length of the track about to load, in seconds, when the
 * caller (Dart, from server/DB catalogue metadata) knows it — 0 = unknown.
 * Some native-loop plugins can't derive the base length themselves (plain
 * NSF has no embedded duration → libnsfplay would fall back to its 5-minute
 * default_playtime, making every forced-loop NSF report 5:00); those read
 * this to seed their loop math with the real per-song length instead. */
double        g_force_base_duration_secs = 0.0;
/* Set by a plugin's open() to decline native looping for the file it just
 * opened (e.g. vgmstream/libvgm on a stream with no loop point). Reset before
 * every open(); read once right after in rewamp_load_file(). */
int           g_force_loop_native_veto   = 0;
static int    g_native_loop_supported    = 0;  /* set by the last rewamp_load_file() */

/* Generic native fadeout window for a natively-looped track with a known
 * single-pass length (see rewamp_set_forced_loop's doc comment) — computed
 * once in rewamp_load_file() right after a successful configure_loop() call,
 * then applied sample-accurately in ds_read() (rewamp_datasource.c), which
 * every plugin's output already passes through. -1 = disabled. NOT static:
 * read (and, once exhausted, cleared) from rewamp_datasource.c. */
int64_t g_loop_fadeout_start_frame  = -1;
int64_t g_loop_fadeout_total_frames = 0;

/* Seek state — written by g_seek_thread (see below) and by each plugin's
 * seek() while it runs on that thread (e.g. sid_seek), read by Dart via FFI.
 * Intentionally racy (no lock): a torn read of a double/int64 during a 60-fps
 * progress poll is harmless. */
volatile int      g_seek_cancel          = 0;  /* set by stop/new-seek to abort */
volatile int      g_is_seeking           = 0;  /* 1 while a seek is in flight   */
volatile double   g_seek_progress_s      = 0.0;
volatile double   g_seek_target_s        = 0.0;

int    rewamp_is_seeking(void)              { return g_is_seeking; }
double rewamp_seek_progress_seconds(void)   { return g_seek_progress_s; }

/* Background seek thread. CPU-emulation plugins (UADE/vio2sf/SNDH/lazyusf/…)
 * implement seek as a slow discard-render loop; running that on the calling
 * (Dart FFI) thread blocked the whole UI isolate for its whole duration, so a
 * second seek request (e.g. dragging the progress bar again before the first
 * one lands) could never arrive until the first one finished — g_seek_cancel
 * existed but nothing could ever call rewamp_seek_seconds() again to set it
 * while the first call was still running. Only one seek is ever in flight:
 * a new seek cancels + joins whatever is running first (bounded — engines
 * check g_seek_cancel every discard-loop iteration), so no two seek threads
 * ever run concurrently and no lock is needed around g_sound access here vs
 * rewamp_stop()/rewamp_unload() (they also cancel+join before touching it). */
static pthread_t    g_seek_thread;
// 1 = a thread was created and has not been joined yet — regardless of
// whether it is still running or already finished. A fast seek (e.g. SID)
// commonly finishes before the *next* seek call: joining must happen
// unconditionally on the next use (pthread_join reclaims an already-finished
// thread immediately) or every such seek leaks a thread handle.
static volatile int g_seek_thread_valid = 0;

static void* rewamp_seek_thread_main(void* arg) {
    (void)arg;
    double seconds = g_seek_target_s;
    ma_uint32 sample_rate = 0;
    ma_sound_get_data_format(&g_sound, NULL, NULL, &sample_rate, NULL, 0);
    if (sample_rate == 0) sample_rate = ma_engine_get_sample_rate(&g_engine);
    ma_uint64 frame = (ma_uint64)(seconds * sample_rate);
    // Deliberately NOT ma_sound_seek_to_pcm_frame(): that call only does an
    // atomic exchange on pSound->seekTarget and returns immediately — the
    // ACTUAL seek (our ds_seek vtable fn) is deferred to whenever miniaudio's
    // mixing thread next processes this sound. If a NEWER seek arrives while
    // that deferred one is still running its slow discard-loop, the mixing
    // thread's own post-seek "clear seekTarget to NONE" silently clobbers the
    // newer request the instant the stale one finally returns — the seek
    // just requested is lost, and playback lands on the STALE target instead
    // (this is what made "move the slider again during a seek" not stick).
    // ma_data_source_seek_to_pcm_frame() calls our ds_seek() SYNCHRONOUSLY,
    // right here on g_seek_thread — genuinely serialized with cancel+join in
    // rewamp_seek_seconds(), and serialized against the mixing thread's own
    // concurrent ds_read() via RewampDataSource.decodeLock (see
    // rewamp_datasource.c).
    ma_data_source_seek_to_pcm_frame(&g_dataSource.base, frame);
    g_is_seeking = 0;
    return NULL;   // g_seek_thread_valid is only cleared by the joiner
}

static void rewamp_seek_thread_cancel_join(void) {
    if (!g_seek_thread_valid) return;
    g_seek_cancel = 1;   // no-op if the thread already finished on its own
    pthread_join(g_seek_thread, NULL);
    g_seek_thread_valid = 0;
}

/* ── The device, owned by us rather than by ma_engine ─────────────────────────
 *
 * ma_engine can create its own device, and it did. The problem is that then the
 * only thing we can time is ds_read — the cadence at which the DATA SOURCE is
 * read — and that is NOT the cadence of the device callback. It stops entirely
 * while paused, which made a 720 ms pause look like a 720 ms scheduling stall
 * and sent three rounds of debugging down the wrong hole.
 *
 * Owning the device gives us the real thing: this callback fires continuously as
 * long as audio output is running — paused, between tracks, silence, whatever.
 * A gap here IS the OS failing to schedule the realtime thread, with no
 * interpretation needed. Measure at the layer you want to reason about.
 */
static ma_device g_device;
static int       g_device_valid = 0;

/* Own context so output devices can be enumerated and the device re-created on
 * a specific one (macOS output picker). NULL-context devices each build a
 * private context, which cannot enumerate. */
static ma_context g_context;
static int        g_context_valid = 0;

/* Playback devices as of the last rewamp_output_devices_json() call — the
 * index passed to rewamp_set_output_device() indexes THIS snapshot. */
#define REWAMP_MAX_OUT_DEVICES 64
static ma_device_id g_out_ids[REWAMP_MAX_OUT_DEVICES];
static int          g_out_count    = 0;
static int          g_out_selected = -1;   /* -1 = system default */

/* Real device-callback telemetry (rewamp_datasource.c owns the ds_read ones). */
int64_t g_dev_late_callbacks = 0;
int64_t g_dev_max_gap_us     = 0;
static int64_t g_dev_last_us = 0;
static int64_t g_dev_period_us = 0;

/* How long ma_engine_read_pcm_frames itself takes, worst case (µs). This is
 * the LAST unmeasured layer: `slow` only times ds_read, but the device callback
 * also runs the whole engine graph (mixer, resampler, fades). If THIS is large,
 * the "OS didn't schedule us" reading of device gaps is wrong — the callback
 * was busy/blocked inside the engine, and the gap is of our own making. If it
 * stays microseconds while gaps hit 400 ms, the callback truly was not invoked,
 * and the cause is outside the process (session interruption, debug tether). */
static int64_t g_dev_max_busy_us = 0;
int64_t rewamp_device_max_busy_us(void) { return g_dev_max_busy_us; }

int64_t rewamp_device_late_count(void) { return g_dev_late_callbacks; }
int64_t rewamp_device_max_gap_us(void) { return g_dev_max_gap_us; }

static void rewamp_device_callback(ma_device* pDevice, void* pOutput,
                                   const void* pInput, ma_uint32 frameCount) {
    (void)pDevice; (void)pInput;

    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    const int64_t now = (int64_t)t.tv_sec * 1000000 + t.tv_nsec / 1000;
    if (g_dev_last_us != 0) {
        const int64_t gap = now - g_dev_last_us;
        if (gap > g_dev_max_gap_us) g_dev_max_gap_us = gap;
        // Past 2 periods we have missed a buffer: the hardware ran dry.
        if (g_dev_period_us > 0 && gap > g_dev_period_us * 2) g_dev_late_callbacks++;
    }

    ma_engine_read_pcm_frames(&g_engine, pOutput, frameCount, NULL);

    struct timespec t2;
    clock_gettime(CLOCK_MONOTONIC, &t2);
    const int64_t done = (int64_t)t2.tv_sec * 1000000 + t2.tv_nsec / 1000;
    if (done - now > g_dev_max_busy_us) g_dev_max_busy_us = done - now;
    g_dev_last_us = done;
}

// Device period — a genuine trade-off, so it is one number, documented.
// Short keeps the consumer position fine-grained (ds_read advances it, and
// every visualizer's data window is keyed off it; some Android devices
// negotiated ~110 ms periods and the visualizers visibly stepped). Long
// gives the OS more slack before the hardware runs dry.
//
// History, so it doesn't get re-litigated: this was raised to 40 ms while
// chasing crackles that looked like the OS scheduling the callback late.
// The verdict cleared it — those stalls were the DEBUG TETHER suspending
// the whole process (detached: no crackle, worst busy=0.1 ms), which no
// buffer survives anyway. So the slack buys nothing, and 20 ms gives the
// visualizers a 50 Hz consumer position instead of 25 Hz.
// Override at build time: -DREWAMP_PERIOD_MS=40.
#ifndef REWAMP_PERIOD_MS
#define REWAMP_PERIOD_MS 20
#endif

/* (Re-)creates + starts g_device on [pDeviceID] (NULL = system default). The
 * config is THE one — rewamp_init and the output picker must not drift. */
static ma_result rewamp_create_device(const ma_device_id* pDeviceID) {
    if (g_device_valid) { ma_device_uninit(&g_device); g_device_valid = 0; }

    ma_device_config dev = ma_device_config_init(ma_device_type_playback);
    dev.playback.pDeviceID = (ma_device_id*)pDeviceID;
    dev.playback.format   = ma_format_f32;   // must match the engine's format
    dev.playback.channels = 2;
    dev.sampleRate        = 44100;
    // Max-order anti-alias LPF on the device's linear resampler. When the
    // hardware runs at a different rate than our 44.1 kHz output (e.g. 48 kHz
    // Mac), miniaudio resamples 44100→native; its default order-4 LPF smears
    // FULL-SPECTRUM content — MSX "1-bit DA" digitized speech (KSS) came out
    // unintelligible while bandlimited tone music was unaffected. Order 8
    // sharpens it toward what Modizer got for free from CoreAudio's own SRC.
    dev.resampling.algorithm       = ma_resample_algorithm_linear;
    dev.resampling.linear.lpfOrder = MA_MAX_FILTER_ORDER;
    dev.periodSizeInMilliseconds = REWAMP_PERIOD_MS;
    dev.dataCallback      = rewamp_device_callback;
    ma_result r = ma_device_init(&g_context, &dev, &g_device);
    if (r != MA_SUCCESS) return r;
    g_device_valid = 1;
    g_dev_period_us = (int64_t)g_device.playback.internalPeriodSizeInFrames
                      * 1000000 / (int64_t)g_device.playback.internalSampleRate;
    g_dev_last_us = 0;   // fresh device — no phantom telemetry gap
    r = ma_device_start(&g_device);
    if (r != MA_SUCCESS) {
        ma_device_uninit(&g_device);
        g_device_valid = 0;
    }
    return r;
}

RewampResult rewamp_init(void) {
    if (g_initialized) return REWAMP_OK;

    ma_engine_config cfg = ma_engine_config_init();
    cfg.sampleRate = 44100;
    cfg.channels   = 2;
    cfg.noDevice   = MA_TRUE;   // we create it below, so we can time it
    ma_result result = ma_engine_init(&cfg, &g_engine);
    if (result != MA_SUCCESS) return REWAMP_ERROR_INIT_FAILED;

    if (ma_context_init(NULL, 0, NULL, &g_context) != MA_SUCCESS) {
        ma_engine_uninit(&g_engine);
        return REWAMP_ERROR_INIT_FAILED;
    }
    g_context_valid = 1;

    if (rewamp_create_device(NULL) != MA_SUCCESS) {
        ma_context_uninit(&g_context);
        g_context_valid = 0;
        ma_engine_uninit(&g_engine);
        return REWAMP_ERROR_INIT_FAILED;
    }

    rewamp_register_builtin_plugins();
    rewamp_channel_data_init();

    g_initialized = 1;
    return REWAMP_OK;
}

/* What the device ACTUALLY negotiated — not what we asked for.
 *
 * periodSizeInMilliseconds is a REQUEST. On iOS it becomes AVAudioSession's
 * *preferred* IO buffer duration, which the system may clamp, and which any
 * other component that reconfigures the session can override — and audio_service
 * owns the session category here (see AppDelegate.swift), configuring it right
 * after we init. So the buffer we run with may have nothing to do with the 40 ms
 * we asked for, and every conclusion drawn from "we have 40 ms of slack" would
 * be built on sand. Read it back instead of believing it. */
int rewamp_device_period_frames(void) {
    return g_device_valid ? (int)g_device.playback.internalPeriodSizeInFrames : 0;
}

int rewamp_device_requested_period_ms(void) { return REWAMP_PERIOD_MS; }

int rewamp_device_periods(void) {
    return g_device_valid ? (int)g_device.playback.internalPeriods : 0;
}

int rewamp_device_sample_rate(void) {
    return g_device_valid ? (int)g_device.playback.internalSampleRate : 0;
}

void rewamp_uninit(void) {
    if (!g_initialized) return;
    rewamp_unload();
    if (g_device_valid) { ma_device_uninit(&g_device); g_device_valid = 0; }
    if (g_context_valid) { ma_context_uninit(&g_context); g_context_valid = 0; }
    ma_engine_uninit(&g_engine);
    rewamp_channel_data_cleanup();
    g_initialized = 0;
}

/* ── Output device picker (desktop; the mobile OSes route system-wide) ──────
 * JSON array of the playback devices: [{"i":0,"name":"...","def":1,"sel":0}].
 * "sel" marks the device rewamp_set_output_device() applied (-1/none = the
 * system default is in charge). The returned buffer is static — copy it. */
const char* rewamp_output_devices_json(void) {
    static char buf[REWAMP_MAX_OUT_DEVICES * 300 + 16];
    buf[0] = '[';
    size_t pos = 1;

    ma_device_info* infos = NULL;
    ma_uint32 count = 0;
    g_out_count = 0;
    if (g_context_valid &&
        ma_context_get_devices(&g_context, &infos, &count, NULL, NULL)
            == MA_SUCCESS) {
        if (count > REWAMP_MAX_OUT_DEVICES) count = REWAMP_MAX_OUT_DEVICES;
        for (ma_uint32 i = 0; i < count; i++) {
            g_out_ids[g_out_count] = infos[i].id;
            if (g_out_count > 0) buf[pos++] = ',';
            pos += (size_t)snprintf(buf + pos, sizeof(buf) - pos,
                "{\"i\":%d,\"name\":\"", g_out_count);
            /* Escape the name for JSON. */
            for (const char* p = infos[i].name; *p && pos < sizeof(buf) - 40; p++) {
                unsigned char c = (unsigned char)*p;
                if (c == '"' || c == '\\') { buf[pos++] = '\\'; buf[pos++] = (char)c; }
                else if (c < 0x20)         { buf[pos++] = ' '; }
                else                       { buf[pos++] = (char)c; }
            }
            pos += (size_t)snprintf(buf + pos, sizeof(buf) - pos,
                "\",\"def\":%d,\"sel\":%d}",
                infos[i].isDefault ? 1 : 0,
                g_out_selected == g_out_count ? 1 : 0);
            g_out_count++;
        }
    }
    buf[pos++] = ']';
    buf[pos] = '\0';
    return buf;
}

/* Re-creates the device on the given snapshot index (-1 = system default,
 * which also restores miniaudio's default-device following). Playback state
 * survives: the engine + ring are untouched, only the sink is swapped. */
RewampResult rewamp_set_output_device(int index) {
    if (!g_initialized || !g_context_valid) return REWAMP_ERROR_INIT_FAILED;
    if (index >= g_out_count) return REWAMP_ERROR_LOAD_FAILED;
    const ma_device_id* id = (index >= 0) ? &g_out_ids[index] : NULL;
    if (rewamp_create_device(id) != MA_SUCCESS) {
        /* The requested device refused (unplugged?) — fall back to default
         * rather than leaving the app silent. */
        g_out_selected = -1;
        return rewamp_create_device(NULL) == MA_SUCCESS
            ? REWAMP_ERROR_LOAD_FAILED : REWAMP_ERROR_INIT_FAILED;
    }
    g_out_selected = (index >= 0) ? index : -1;
    return REWAMP_OK;
}

/* ── ProWizard last-resort conversion ──────────────────────────────────────
 * A packed Amiga module (ProPacker, NoisePacker, The Player, Tracker Packer,
 * Promizer, …) that NO plugin could open is handed to ProWizard, which detects
 * it BY CONTENT and rebuilds a standard Protracker MOD; that MOD then goes
 * back through the normal plugin selection (libopenmpt / UADE).
 *
 * LAST RESORT on purpose: the detection is heuristic and can false-positive on
 * a healthy file, so a file any plugin already claims must never reach it —
 * which also makes overlap with libopenmpt's own packer loaders (gmc, nru,
 * unic, ice, mus_km) a non-issue.
 *
 * The converted module needs a PATH (plugins open files, not buffers), so it
 * is written under <datadir>/prowiz/ keeping the original basename (UADE and
 * the info panel both surface it). The directory holds one file at a time. */
#ifdef REWAMP_WITH_PROWIZARD
/* Set while replaying a conversion's output, so it can't be re-converted. */
static int g_prowizard_retry = 0;

static int rewamp_prowizard_to_file(const char* srcPath, char* outPath,
                                    size_t outPathSize) {
    if (rewamp_get_data_dir()[0] == '\0') return 0;

    FILE* f = fopen(srcPath, "rb");
    if (!f) return 0;
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    /* Packed Amiga modules are tiny; anything huge is not one of them. */
    if (size < 2048 || size > 4 * 1024 * 1024 || fseek(f, 0, SEEK_SET) != 0) {
        fclose(f);
        return 0;
    }
    void* buf = malloc((size_t)size);
    if (!buf || fread(buf, 1, (size_t)size, f) != (size_t)size) {
        free(buf);
        fclose(f);
        return 0;
    }
    fclose(f);

    void* mod = NULL;
    size_t modLen = 0;
    const char* fmtName = NULL;
    int ok = rewamp_prowizard_convert(buf, (size_t)size, &mod, &modLen, &fmtName);
    free(buf);
    if (!ok) return 0;

    char dir[4096];
    snprintf(dir, sizeof(dir), "%s/prowiz", rewamp_get_data_dir());
#ifdef _WIN32
    _mkdir(dir);
#else
    mkdir(dir, 0755);
#endif
    /* Drop whatever the previous conversion left behind. */
    DIR* d = opendir(dir);
    if (d) {
        struct dirent* e;
        while ((e = readdir(d)) != NULL) {
            if (e->d_name[0] == '.') continue;
            char victim[4096];
            snprintf(victim, sizeof(victim), "%s/%s", dir, e->d_name);
            remove(victim);
        }
        closedir(d);
    }

    const char* base = strrchr(srcPath, '/');
    base = base ? base + 1 : srcPath;
    snprintf(outPath, outPathSize, "%s/%s.mod", dir, base);

    FILE* o = fopen(outPath, "wb");
    if (!o) { free(mod); return 0; }
    size_t written = fwrite(mod, 1, modLen, o);
    fclose(o);
    free(mod);
    if (written != modLen) { remove(outPath); return 0; }

    fprintf(stderr, "[rewamp] prowizard: %s -> Protracker MOD (%zu bytes)\n",
            fmtName ? fmtName : "?", modLen);
    return 1;
}
#endif /* REWAMP_WITH_PROWIZARD */

/* ── miniaudio-decoder fallback wrapped as a RewampDecoder ─────────────────
 * wav/mp3/flac/ogg go through the SAME data source as every plugin, so the
 * waveform oscilloscope and the stereo L/R mute work for them too. */

/* length is computed ONCE at open() and cached: for mp3,
 * ma_decoder_get_length_in_pcm_frames() runs a full decode-scan with internal
 * seeks on the SAME ma_decoder the audio thread is reading — calling it live
 * from the Dart thread (duration polling) corrupted dr_mp3 state (SIGBUS in
 * L3_restore_reservoir). */
typedef struct { ma_decoder dec; ma_uint64 lengthFrames; } RewampMaDec;

static RewampDecoder* rewamp_madec_open(const char* path,
                                        RewampAudioFormat* outFormat) {
    RewampMaDec* d = (RewampMaDec*)calloc(1, sizeof(RewampMaDec));
    if (!d) return NULL;
    ma_decoder_config cfg = ma_decoder_config_init(ma_format_f32, 0, 0);
    if (ma_decoder_init_file(path, &cfg, &d->dec) != MA_SUCCESS) {
        free(d);
        return NULL;
    }
    ma_format f; ma_uint32 ch = 0, rate = 0;
    ma_decoder_get_data_format(&d->dec, &f, &ch, &rate, NULL, 0);
    if (ch == 0 || rate == 0) {
        ma_decoder_uninit(&d->dec);
        free(d);
        return NULL;
    }
    if (outFormat) { outFormat->channels = ch; outFormat->sampleRate = rate; }
    /* miniaudio decodes audio only — pull tags (ID3 / Vorbis / RIFF INFO)
     * for the info panel ourselves, plus basic stream facts so the panel is
     * never empty for tag-less files. */
    rewamp_tags_append_info(path);
    {
        const char* dot = strrchr(path, '.');
        char extUp[8] = "";
        if (dot && strlen(dot + 1) < sizeof(extUp)) {
            for (int i = 0; dot[1 + i] && i < (int)sizeof(extUp) - 1; ++i)
                extUp[i] = (char)toupper((unsigned char)dot[1 + i]);
        }
        /* Safe here: playback has not started, nothing else touches d->dec.
         * (mp3: full decode-scan + seek back to the start.) */
        ma_decoder_get_length_in_pcm_frames(&d->dec, &d->lengthFrames);
        rewamp_track_message_append("Format: %s%s%u Hz, %s\n",
            extUp, extUp[0] ? ", " : "", rate,
            ch == 1 ? "mono" : (ch == 2 ? "stereo" : "multichannel"));
        if (d->lengthFrames > 0 && rate > 0) {
            unsigned total = (unsigned)(d->lengthFrames / rate);
            rewamp_track_message_append("Duration: %u:%02u\n",
                                        total / 60, total % 60);
        }
    }
    return (RewampDecoder*)d;
}

static uint64_t rewamp_madec_read(RewampDecoder* rd, float* out,
                                  uint64_t frameCount) {
    ma_uint64 got = 0;
    ma_decoder_read_pcm_frames(&((RewampMaDec*)rd)->dec, out, frameCount, &got);
    return (uint64_t)got;
}

static void rewamp_madec_seek(RewampDecoder* rd, uint64_t frameIndex) {
    ma_decoder_seek_to_pcm_frame(&((RewampMaDec*)rd)->dec, frameIndex);
}

static uint64_t rewamp_madec_length(RewampDecoder* rd) {
    /* Cached at open() — NEVER query the live decoder from another thread
     * (mp3 length = destructive decode-scan; see RewampMaDec). */
    return (uint64_t)((RewampMaDec*)rd)->lengthFrames;
}

static void rewamp_madec_close(RewampDecoder* rd) {
    ma_decoder_uninit(&((RewampMaDec*)rd)->dec);
    free(rd);
}

static int rewamp_madec_probe(const char* ext, const uint8_t* hdr, size_t n) {
    (void)ext; (void)hdr; (void)n;
    return 0;   /* never registered — used explicitly as the load fallback */
}

static const RewampPluginVTable g_madec_vtable = {
    "miniaudio",
    rewamp_madec_probe,
    rewamp_madec_open,
    rewamp_madec_read,
    rewamp_madec_seek,
    rewamp_madec_length,
    rewamp_madec_close,
};

static const RewampPluginVTable* rewamp_madec_vtable(void) {
    return &g_madec_vtable;
}

/* One opened, loop-configured decoder — everything a load does short of the
 * datasource/sound wiring. Factored out of rewamp_load_file so the gapless
 * handoff (rewamp_handoff_open_next, called from the PRODUCER thread) opens
 * the next track through the exact same orchestration: per-track state resets,
 * registry cascade, configure_loop + fadeout window, ProWizard rescue,
 * miniaudio fallback, tags, backend name. */
typedef struct {
    const RewampPluginVTable* vt;
    RewampDecoder*            dec;
    RewampAudioFormat         fmt;
    RewampDeclick*            declick;   /* NULL sauf rip CD + réglage actif */
} RewampOpenedTrack;

/* Déclic de début de piste des rips CD — voir rewamp_declick.h. Décidé ICI,
 * au-dessus des greffons, sur le CHEMIN: un `.ape` est joué par MAC, un
 * `.ogg` par vgmstream, un build sans FFmpeg retombe sur miniaudio — et le
 * déchet est dans le FICHIER, pas dans le moteur. (Première version posée dans
 * le seul greffon vgmstream: `T-3103G_02.ape` claquait toujours.) Réglage
 * Réglages → Lecture → « Rips CD », actif par défaut. */
static RewampDeclick* rewamp_declick_for(const char* path, const RewampAudioFormat* fmt) {
    if (path == NULL || fmt == NULL) return NULL;
    if (rewamp_get_engine_param("rewamp", "cd_rip_declick", 1.0) == 0.0) return NULL;
    char clean[4096];
    snprintf(clean, sizeof(clean), "%s", path);
    char* q = strstr(clean, "?subsong=");
    if (q != NULL) *q = '\0';
    const char* slash = strrchr(clean, '/');
    const char* base  = slash ? slash + 1 : clean;
    const char* dot   = strrchr(base, '.');
    if (dot == NULL || !rewamp_declick_ext_is_cd_rip(dot + 1)) return NULL;
    return rewamp_declick_create((int)fmt->channels, (int)fmt->sampleRate);
}

static int rewamp_open_track(const char* path, RewampOpenedTrack* out) {
    g_native_loop_supported    = 0; // set again below only on a configure_loop
                                     // plugin that did not veto
    g_loop_fadeout_start_frame = -1;

    // Clear any per-voice state from the previous file. Plugins that produce
    // per-channel data call rewamp_channel_data_reset(N) inside their open();
    // backends without it (vgmstream, miniaudio fallback) leave the count at 0,
    // which switches the per-voice scope to the L/R waveform fallback. Without
    // this reset a stale count from a prior file (e.g. an 8-voice PSF) would
    // persist and the scope would keep showing dead voices.
    rewamp_channel_data_reset(0);
    rewamp_reset_silence();
    // Fresh info panel for the new file/subsong; the plugin's open() appends
    // whatever its library exposes (tags, copyright, instruments, …).
    rewamp_track_message_clear();
    rewamp_track_artwork_clear();

    // Strip any ?subsong=N suffix before probing (it's parsed by the plugin's
    // own open() call and must not confuse extension detection or fopen).
    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    {
        char* q = strchr(cleanPath, '?');
        if (q) *q = '\0';
    }

    // The files this decode actually opens, for the info panel. Reset here and
    // seeded with the main file; a loader that pulls companions (UADE's
    // multifile resolver, the PSF lib chain, .mdx/.pdx, .eup banks) adds its
    // own. Deriving the list from the NAME instead was wrong both ways: a
    // .psflib is usually named after the game, not the tune, and a neighbour
    // that merely shares the stem is not a companion.
    rewamp_loaded_files_reset();
    rewamp_loaded_files_add(cleanPath);

    // 1. Ask the registry for every plugin claiming this file, best first, and
    // cascade: if the winner's open() fails (e.g. a converted/packed Amiga .mod
    // that libopenmpt rejects), try the next-best claimant (UADE's ProWizard
    // path plays many of those) before giving up to miniaudio.
    const RewampPluginVTable* cands[8];
    int candCount = rewamp_registry_select_ranked(cleanPath, cands,
                                                  (int)(sizeof(cands) / sizeof(cands[0])));
    for (int c = 0; c < candCount; ++c) {
        const RewampPluginVTable* vt = cands[c];
        if (c > 0) {
            // A failed open() may have registered voices/chips or appended to
            // the info panel; wipe that state before the next attempt.
            rewamp_channel_data_reset(0);
            rewamp_track_message_clear();
            // Et les TAGS (titre/artiste/album) avec: ce sont des globaux de
            // processus que seul l'appelant remet à zéro, et un candidat qui
            // échoue APRÈS les avoir posés les laisserait au gagnant — Dart
            // les lit comme « le tag de CE fichier » et les persiste.
            rewamp_track_artwork_clear();
        }
        RewampAudioFormat fmt = {0};
        g_force_loop_native_veto = 0; // plugin's open() may set it (see below)
        // Pass the ORIGINAL path (with suffix) so the plugin can read subsong.
        RewampDecoder* dec = vt->open(path, &fmt);
        if (dec != NULL && fmt.channels > 0 && fmt.sampleRate > 0) {
            g_loop_fadeout_start_frame = -1; // reset; only armed below when possible
            if (vt->configure_loop != NULL) {
                vt->configure_loop(dec, g_force_loop_mode, g_force_loop_count);
                // Generic native fadeout window (see rewamp_set_forced_loop's
                // doc comment): skipped entirely when the plugin ALSO fades
                // natively (it already read g_force_fadeout_* itself, from
                // inside open() — see supportsNativeFadeout's doc comment).
                // Otherwise only computable for a FINITE native loop
                // (mode==1) whose single-pass length is known. length()
                // reflects one pass regardless of the just-armed repeat
                // count (confirmed for libopenmpt; assumed true for any
                // future configure_loop plugin too).
                if (!vt->supportsNativeFadeout &&
                    g_force_loop_mode == 1 && g_force_fadeout_enabled &&
                    g_force_fadeout_seconds > 0.0 && vt->length != NULL) {
                    uint64_t singlePassFrames = vt->length(dec);
                    if (singlePassFrames > 0) {
                        // The window is applied in ds_read against the RING's
                        // cursor (REWAMP_RING_RATE) — a decoder rendering at
                        // another rate (openmpt at 48 kHz) is resampled by the
                        // producer, so its native frame counts scale here.
                        int64_t fadeFrames = (int64_t)(g_force_fadeout_seconds *
                                                        (double)REWAMP_RING_RATE);
                        int64_t totalFrames = (int64_t)singlePassFrames *
                                               (int64_t)(g_force_loop_count + 1);
                        if (fmt.sampleRate != REWAMP_RING_RATE && fmt.sampleRate > 0)
                            totalFrames = totalFrames * REWAMP_RING_RATE
                                          / (int64_t)fmt.sampleRate;
                        if (fadeFrames > 0 && fadeFrames < totalFrames) {
                            g_loop_fadeout_start_frame  = totalFrames - fadeFrames;
                            g_loop_fadeout_total_frames = fadeFrames;
                        }
                    }
                }
            }
            g_backend_name = vt->name;
            /* Container tags (ID3 / Vorbis / RIFF INFO) for plugin-decoded
             * files: vgmstream/ffmpeg play tagged mp3/ogg but publish only
             * technical stream facts (Format/Codec/…) to the panel — never
             * the metadata tags. Read them ourselves and APPEND (no
             * empty-guard: vgmstream already wrote its lines, and we want the
             * tags in ADDITION). Safe for every plugin: rewamp_tags_append_info
             * detects the container by magic and NO-OPS on non-container
             * formats (PSF/VGM/chip files), so it never duplicates a PSF
             * plugin's own tags. Uses cleanPath (no ?subsong= suffix) — the
             * real on-disk file. */
            rewamp_tags_append_info(cleanPath);
            // A plugin can VETO native loop per-file in its open() (e.g.
            // vgmstream/libvgm on a stream with no loop point — its native
            // loop_count is a no-op there, so the generic Dart loop must take
            // over). g_force_loop_native_veto is reset above before each
            // open() and set by the plugin.
            g_native_loop_supported =
                (vt->configure_loop != NULL && !g_force_loop_native_veto) ? 1 : 0;
            out->vt  = vt;
            out->dec = dec;
            out->fmt = fmt;
            out->declick = rewamp_declick_for(path, &fmt);
            return 1;
        }
        if (dec != NULL) vt->close(dec);
        // This plugin claimed the file but failed; try the next candidate.
    }

#ifdef REWAMP_WITH_PROWIZARD
    // 1b. Nobody could play it: try ProWizard's content-based detection and, if
    // it recognises a packed Amiga module, replay the Protracker MOD it rebuilds
    // through this very function (guarded against recursing on the conversion's
    // own output).
    if (!g_prowizard_retry) {
        char convPath[4096];
        if (rewamp_prowizard_to_file(cleanPath, convPath, sizeof(convPath))) {
            g_prowizard_retry = 1;
            int ok = rewamp_open_track(convPath, out);
            g_prowizard_retry = 0;
            if (ok) return 1;
        }
    }
#endif

    // 2. Fallback: miniaudio's built-in decoders (wav / mp3 / flac / ogg),
    // wrapped as a RewampDecoder so playback still flows through our data
    // source (ds_read) — that is what feeds the waveform oscilloscope and
    // applies the stereo L/R mute; ma_sound_init_from_file would bypass both.
    {
        if (candCount > 0) {
            // Wipe anything the failed plugin attempts left behind.
            rewamp_channel_data_reset(0);
            rewamp_track_message_clear();
        }
        RewampAudioFormat fmt = {0};
        RewampDecoder* dec = rewamp_madec_open(cleanPath, &fmt);
        if (dec != NULL && fmt.channels > 0 && fmt.sampleRate > 0) {
            g_backend_name = "miniaudio";
            out->vt  = rewamp_madec_vtable();
            out->dec = dec;
            out->fmt = fmt;
            out->declick = rewamp_declick_for(path, &fmt);
            return 1;
        }
        if (dec != NULL) rewamp_madec_vtable()->close(dec);
    }
    return 0;
}

RewampResult rewamp_load_file(const char* path) {
    if (!g_initialized) return REWAMP_ERROR_NOT_INITIALIZED;

    rewamp_unload();
    // A manual load supersedes whatever next-track was staged for gapless: the
    // queue decision that staged it is stale the moment the user picks a track.
    rewamp_clear_next_file();
    // La fin de piste posée par Dart est PAR PISTE — celle d'hier ne doit pas
    // couper celle d'aujourd'hui. Dart re-pose après chaque load/adoption.
    rewamp_set_track_end_seconds(0.0);

    RewampOpenedTrack ot;
    if (!rewamp_open_track(path, &ot)) return REWAMP_ERROR_LOAD_FAILED;
    /* Nouvelle piste = nouvelle image (pochette, grille de motifs, voies),
     * même si l'on ne joue pas encore: le visualiseur doit sortir de sa veille.
     * Voir rewamp_viz_idle.h. */
    rewamp_viz_wake();

    if (rewamp_data_source_init(&g_dataSource, ot.vt, ot.dec, ot.fmt, ot.declick)
            == MA_SUCCESS) {
        if (ma_sound_init_from_data_source(
                &g_engine, &g_dataSource.base, 0, NULL, &g_sound) == MA_SUCCESS) {
            g_sound_loaded = 1;
            g_using_plugin = 1;
            return REWAMP_OK;
        }
        rewamp_data_source_uninit(&g_dataSource);  // also closes dec
        ot.dec = NULL;
    }
    if (ot.dec != NULL && ot.vt->close != NULL) ot.vt->close(ot.dec);
    rewamp_declick_destroy(ot.declick);
    g_backend_name = "";
    return REWAMP_ERROR_LOAD_FAILED;
}

void rewamp_unload(void) {
    if (!g_sound_loaded) return;
    // Must happen before ma_sound_uninit(): the seek thread reads/mutates the
    // live decoder state (g_sound / g_dataSource) — never tear that down out
    // from under it.
    rewamp_seek_thread_cancel_join();
    ma_sound_uninit(&g_sound);
    if (g_using_plugin) {
        rewamp_data_source_uninit(&g_dataSource);
    }
    g_sound_loaded = 0;
    g_using_plugin = 0;
    g_backend_name = "";
}

/* Short enough to feel instant, long enough to kill the click. */
#define REWAMP_PAUSE_FADE_MS 12

RewampResult rewamp_play(void) {
    if (!g_initialized) return REWAMP_ERROR_NOT_INITIALIZED;
    if (!g_sound_loaded) return REWAMP_ERROR_NO_SOUND;
    // A pause may have SUSPENDED the whole device (see rewamp_device_suspend —
    // iOS Now Playing ignores playbackRate=0 while the audio unit runs).
    // Restart it before the sound; a no-op when it never stopped.
    if (ma_device_get_state(&g_device) != ma_device_state_started) {
        if (ma_device_start(&g_device) != MA_SUCCESS)
            return REWAMP_ERROR_INIT_FAILED;
    }
    // Resuming a waveform mid-cycle from zero is a step discontinuity — i.e. a
    // click. Ramp in. (And clear any fade/stop the previous pause scheduled,
    // which miniaudio requires before restarting.)
    ma_sound_reset_stop_time_and_fade(&g_sound);
    ma_sound_set_fade_in_milliseconds(&g_sound, 0.0f, 1.0f, REWAMP_PAUSE_FADE_MS);
    ma_sound_start(&g_sound);
    rewamp_notes_set_paused(0);
    // The data source stops being read while paused, so the next ds_read would
    // otherwise measure the whole pause as a "late callback" (it did: 720 ms).
    g_dataSource.lastReadUs = 0;
    rewamp_android_start_service();
    return REWAMP_OK;
}

RewampResult rewamp_pause(void) {
    if (!g_initialized) return REWAMP_ERROR_NOT_INITIALIZED;
    if (!g_sound_loaded) return REWAMP_ERROR_NO_SOUND;
    if (ma_device_get_state(&g_device) != ma_device_state_started) {
        // Device not running (iOS session interruption — Spotify took the
        // output — or an earlier suspend): the fade below would NEVER land.
        // Its stop is keyed on the ENGINE clock, which only advances when the
        // device renders, so the sound stayed "playing" forever and the UI
        // pause flap-flopped against the tick (`isPlaying = audio.isPlaying`).
        // Nothing renders, so there is no waveform to click: stop dead.
        ma_sound_stop(&g_sound);
        rewamp_notes_set_paused(1);
        rewamp_android_stop_service();
        return REWAMP_OK;
    }
    // NOT ma_sound_stop(): cutting the waveform dead mid-cycle is a step
    // discontinuity, which is exactly the click heard on pause. Fade it out.
    ma_sound_stop_with_fade_in_milliseconds(&g_sound, REWAMP_PAUSE_FADE_MS);
    // Freeze the notation playhead NOW: extrapolating through the pause made
    // the notes scroll on for a beat and resume out of sync.
    rewamp_notes_set_paused(1);
    rewamp_android_stop_service();
    return REWAMP_OK;
}

/* iOS: the system's Now Playing UI treats an app whose audio I/O unit is
 * RUNNING as "playing", regardless of the playbackRate=0 that audio_service
 * advertises — so after a pause (which only stops the ma_sound; the device
 * keeps rendering silence) Control Center kept showing the pause glyph.
 * Stopping the whole device flips it. Called from Dart a beat AFTER
 * rewamp_pause() so the 12 ms anti-click fade has actually rendered
 * (stopping the device here would cut it dead — the very click the fade
 * exists to kill). rewamp_play() restarts the device transparently. */
RewampResult rewamp_device_suspend(void) {
    if (!g_initialized) return REWAMP_ERROR_NOT_INITIALIZED;
    /* Only while genuinely paused — a play racing the delayed suspend wins. */
    if (g_sound_loaded && ma_sound_is_playing(&g_sound)) return REWAMP_OK;
    ma_device_stop(&g_device);
    g_dev_last_us = 0;   /* else the resume gap logs as a giant device-late */
    return REWAMP_OK;
}

RewampResult rewamp_stop(void) {
    if (!g_initialized) return REWAMP_ERROR_NOT_INITIALIZED;
    if (!g_sound_loaded) return REWAMP_ERROR_NO_SOUND;
    rewamp_seek_thread_cancel_join();   // abort + wait out any in-progress seek
    ma_sound_stop(&g_sound);
    ma_sound_seek_to_pcm_frame(&g_sound, 0);
    // Zero oscilloscope ring buffers and note/volume state so the visualizer
    // goes blank immediately (buffers refill automatically on next play).
    rewamp_channel_data_clear();
    // Zero the stereo waveform ring buffer too.
    memset(g_wf_left,  0, sizeof(g_wf_left));
    memset(g_wf_right, 0, sizeof(g_wf_right));
    g_wf_pos = 0;
    return REWAMP_OK;
}

int rewamp_is_playing(void) {
    if (!g_initialized || !g_sound_loaded) return 0;
    return ma_sound_is_playing(&g_sound) ? 1 : 0;
}

void rewamp_set_volume(float volume) {
    if (!g_initialized || !g_sound_loaded) return;
    ma_sound_set_volume(&g_sound, volume);
}

void rewamp_set_forced_loop(int mode, int count,
                            int fadeoutEnabled, double fadeoutSeconds,
                            double baseDurationSeconds) {
    g_force_loop_mode         = mode;
    g_force_loop_count        = count;
    g_force_fadeout_enabled   = fadeoutEnabled;
    g_force_fadeout_seconds   = fadeoutSeconds;
    g_force_base_duration_secs = baseDurationSeconds > 0.0 ? baseDurationSeconds : 0.0;
}

/* ── Gapless: staged next track ──────────────────────────────────────────────
 * Dart arms the NEXT queue entry here as soon as the current track is playing
 * and the next file exists on disk; the producer thread consumes it at decoder
 * EOF (rewamp_handoff_attempt → rewamp_handoff_open_next) and swaps decoders
 * inside the same ring. The staged snapshot carries the same per-track values
 * rewamp_set_forced_loop would have carried for a plain load — open() reads
 * them from the g_force_* globals, so they are applied JUST before the open.
 * Any queue mutation (edit, reorder, shuffle/repeat change, manual skip)
 * must re-arm or clear; a manual rewamp_load_file() clears it itself. */
typedef struct {
    int    staged;
    char   path[4096];
    int    loopMode;
    int    loopCount;
    int    fadeoutEnabled;
    double fadeoutSeconds;
    double baseDurationSecs;
} RewampNextTrack;
static RewampNextTrack g_next;
static pthread_mutex_t g_next_mtx = PTHREAD_MUTEX_INITIALIZER;

void rewamp_set_next_file(const char* path, int loopMode, int loopCount,
                          int fadeoutEnabled, double fadeoutSeconds,
                          double baseDurationSeconds) {
    if (path == NULL || path[0] == '\0') { rewamp_clear_next_file(); return; }
    pthread_mutex_lock(&g_next_mtx);
    snprintf(g_next.path, sizeof(g_next.path), "%s", path);
    g_next.loopMode         = loopMode;
    g_next.loopCount        = loopCount;
    g_next.fadeoutEnabled   = fadeoutEnabled;
    g_next.fadeoutSeconds   = fadeoutSeconds;
    g_next.baseDurationSecs = baseDurationSeconds;
    g_next.staged           = 1;
    pthread_mutex_unlock(&g_next_mtx);
}

void rewamp_clear_next_file(void) {
    pthread_mutex_lock(&g_next_mtx);
    g_next.staged = 0;
    pthread_mutex_unlock(&g_next_mtx);
}

/* Crossfade duration — the storage lives in rewamp_datasource.c (the producer
 * reads it every track end); this is the FFI face. */
extern double g_crossfade_seconds;
void rewamp_set_crossfade_seconds(double seconds) {
    g_crossfade_seconds = seconds > 0.0 ? seconds : 0.0;
}

/* Fin de piste posée par Dart — voir g_track_end_seconds (rewamp_datasource.c).
 * Par piste: remise à zéro à chaque load et à chaque handoff. */
extern double g_track_end_seconds;
void rewamp_set_track_end_seconds(double seconds) {
    g_track_end_seconds = seconds > 0.0 ? seconds : 0.0;
}

int rewamp_next_staged(void) {
    pthread_mutex_lock(&g_next_mtx);
    int s = g_next.staged;
    pthread_mutex_unlock(&g_next_mtx);
    return s;
}

/* Producer-thread half of the handoff (see rewamp_handoff_attempt in
 * rewamp_datasource.c): consume the staged track, apply its per-track loop
 * snapshot and open it through the exact same orchestration as a plain load.
 * Consumes the staging even on failure — a broken file must not be retried in
 * a loop every producer wake; the plain end-of-track path takes over. */
int rewamp_handoff_open_next(const RewampPluginVTable** outVt,
                             RewampDecoder** outDec,
                             RewampAudioFormat* outFmt,
                             RewampDeclick** outDeclick) {
    RewampNextTrack next;
    pthread_mutex_lock(&g_next_mtx);
    if (!g_next.staged) {
        pthread_mutex_unlock(&g_next_mtx);
        return 0;
    }
    next = g_next;
    g_next.staged = 0;
    pthread_mutex_unlock(&g_next_mtx);

    rewamp_set_forced_loop(next.loopMode, next.loopCount, next.fadeoutEnabled,
                           next.fadeoutSeconds, next.baseDurationSecs);
    // Même règle qu'au load: la fin posée par Dart appartenait à la piste
    // SORTANTE. Dart re-posera celle de la nouvelle à l'adoption (le staging
    // porte déjà sa durée de BASE, qui sert de première approximation).
    rewamp_set_track_end_seconds(next.baseDurationSecs);

    RewampOpenedTrack ot;
    if (!rewamp_open_track(next.path, &ot)) return 0;
    *outVt  = ot.vt;
    *outDec = ot.dec;
    *outFmt = ot.fmt;
    *outDeclick = ot.declick;
    return 1;
}

int rewamp_has_native_loop_support(void) {
    return g_native_loop_supported;
}

double rewamp_get_position_seconds(void) {
    if (!g_initialized || !g_sound_loaded) return 0.0;
    float pos = 0.0f;
    ma_sound_get_cursor_in_seconds(&g_sound, &pos);
    return (double)pos;
}

double rewamp_get_duration_seconds(void) {
    if (!g_initialized || !g_sound_loaded) return 0.0;
    float dur = 0.0f;
    ma_sound_get_length_in_seconds(&g_sound, &dur);
    return (double)dur;
}

RewampResult rewamp_seek_seconds(double seconds) {
    if (!g_initialized) return REWAMP_ERROR_NOT_INITIALIZED;
    if (!g_sound_loaded) return REWAMP_ERROR_NO_SOUND;

    // Cancel + join whatever seek is already running (bounded — see the
    // comment above rewamp_seek_thread_cancel_join()) before arming the new
    // one, so this call returns almost immediately: the actual seek runs on
    // g_seek_thread, off the calling (Dart FFI) thread.
    rewamp_seek_thread_cancel_join();

    g_seek_cancel     = 0;
    g_is_seeking      = 1;
    g_seek_progress_s = 0.0;
    g_seek_target_s   = seconds;

    if (pthread_create(&g_seek_thread, NULL, rewamp_seek_thread_main, NULL) == 0) {
        g_seek_thread_valid = 1;
    } else {
        // Thread spawn failed (should never happen) — fall back to running it
        // synchronously rather than silently doing nothing.
        rewamp_seek_thread_main(NULL);
    }
    return REWAMP_OK;
}

const char* rewamp_get_backend_name(void) {
    return g_backend_name;
}

#ifdef REWAMP_WITH_GME
extern int         rewamp_gme_probe_subsong_info(const char* path);
extern int         rewamp_gme_probe_subsong_count(const char* path);
extern const char* rewamp_gme_probe_get_title(int idx);
extern int         rewamp_gme_probe_get_duration_ms(int idx);
#endif
#ifdef REWAMP_WITH_SID
extern int rewamp_sid_probe_subsong_count(const char* path);
#endif
#ifdef REWAMP_WITH_KSS
extern int         rewamp_kss_probe_subsong_count(const char* path);
extern const char* rewamp_kss_probe_get_title(int idx);
extern int         rewamp_kss_probe_get_duration_ms(int idx);
extern int         rewamp_kss_probe_base(void);
#endif
#ifdef REWAMP_WITH_OPENMPT
extern int         rewamp_openmpt_probe_subsong_count(const char* path);
extern const char* rewamp_openmpt_probe_get_title(int idx);
#endif
#ifdef REWAMP_WITH_XMP
extern int         rewamp_xmp_probe_subsong_count(const char* path);
extern int         rewamp_xmp_probe_get_duration_ms(int idx);
#endif
#ifdef REWAMP_WITH_SC68
extern int         rewamp_sc68_probe_subsong_count(const char* path);
extern const char* rewamp_sc68_probe_get_title(int idx);
extern int         rewamp_sc68_probe_get_duration_ms(int idx);
extern int         rewamp_sc68_probe_base(void);
#endif
#ifdef REWAMP_WITH_SNDH
extern int         rewamp_sndh_probe_subsong_count(const char* path);
extern const char* rewamp_sndh_probe_get_title(int idx);
extern int         rewamp_sndh_probe_get_duration_ms(int idx);
extern int         rewamp_sndh_probe_base(void);
#endif

#ifdef REWAMP_WITH_ASAP
extern int         rewamp_asap_probe_subsong_count(const char* path);
extern int         rewamp_asap_probe_get_duration_ms(int idx);
#endif

#ifdef REWAMP_WITH_ZXTUNE
extern int         rewamp_zxtune_probe_subsong_count(const char* path);
extern const char* rewamp_zxtune_probe_get_title(int idx);
#endif
#ifdef REWAMP_WITH_ADPLUG
extern int         rewamp_adplug_probe_subsong_count(const char* path);
extern int         rewamp_adplug_probe_get_index(int idx);
extern int         rewamp_gbsplay_probe_subsong_count(const char* path);
extern int         rewamp_gbsplay_probe_get_index(int idx);
extern int         rewamp_adplug_probe_get_duration_ms(int idx);
#endif
#ifdef REWAMP_WITH_FURNACE
extern int         rewamp_furnace_probe_subsong_info(const char* path);
extern const char* rewamp_furnace_probe_get_title(int idx);
extern int         rewamp_furnace_probe_get_duration_ms(int idx);
#endif

// ── Probe-cache dispatch (last-file cache, set by rewamp_probe_subsong_count) ─

typedef const char* (*probe_get_title_fn)(int);
typedef int         (*probe_get_duration_fn)(int);
typedef int         (*probe_get_index_fn)(int);

static probe_get_title_fn    s_probe_title_fn    = NULL;
static probe_get_duration_fn s_probe_duration_fn = NULL;
/* Set only by a format whose playable subsongs are SPARSE (AdPlug `.adl`: the
 * table holds sentinel entries between the live ones). NULL = dense, and the
 * index is then s_probe_base + position, as it always was. */
static probe_get_index_fn    s_probe_index_fn    = NULL;
// The absolute base of the last probe's subsong indices (0 for formats whose
// subsong index is already absolute, e.g. NSF; trk_min for KSS). The Dart layer
// adds this to the 0-based position so probeSubsongs advertises absolute indices.
static int s_probe_base = 0;

int rewamp_probe_subsong_base(void) { return s_probe_base; }

int rewamp_probe_subsong_index(int idx) {
    if (s_probe_index_fn) return s_probe_index_fn(idx);
    return s_probe_base + idx;
}

int rewamp_decode_text(const char* in, char* out, int out_cap) {
    if (!out || out_cap <= 0) return 0;
    rewamp_text_to_utf8(in, out, (size_t)out_cap);
    return (int)strlen(out);
}

const char* rewamp_probe_get_title(int idx) {
    if (s_probe_title_fn) return s_probe_title_fn(idx);
    return "";
}

int rewamp_probe_get_duration_ms(int idx) {
    if (s_probe_duration_fn) return s_probe_duration_fn(idx);
    return -1;
}

// Return 1 if the file (after stripping ?subsong=) starts with a SID magic.
static int rewamp_is_sid_file(const char* path) {
    if (!path) return 0;
    char clean[4096];
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strrchr(clean, '?');
    if (q) *q = '\0';
    FILE* f = fopen(clean, "rb");
    if (!f) return 0;
    char hdr[4] = {0};
    size_t n = fread(hdr, 1, 4, f);
    fclose(f);
    if (n < 4) return 0;
    return (memcmp(hdr, "PSID", 4) == 0) || (memcmp(hdr, "RSID", 4) == 0);
}

// Return 1 if the file (after stripping ?subsong=) has a libkss-family extension.
static int rewamp_is_kss_file(const char* path) {
    if (!path) return 0;
    char clean[4096];
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strrchr(clean, '?');
    if (q) *q = '\0';
    const char* dot = strrchr(clean, '.');
    if (!dot) return 0;
    char ext[16] = {0};
    for (int i = 0; dot[i + 1] && i < 15; i++) ext[i] = (char)tolower((unsigned char)dot[i + 1]);
    static const char* const k[] = { "kss", "mgs", "bgm", "mpk", "mbm", "opx", "mus", NULL };
    for (int i = 0; k[i]; i++) if (strcmp(ext, k[i]) == 0) return 1;
    return 0;
}

int rewamp_can_play(const char* path) {
    /* The registry's own answer: extension + header scoring across EVERY
     * plugin, no decode. See the header for why rewamp_probe_subsong_count()
     * cannot stand in for this. */
    if (!path || !*path) return 0;
    return rewamp_registry_select(path) != NULL ? 1 : 0;
}

int rewamp_probe_subsong_count(const char* path) {
    s_probe_title_fn    = NULL;
    s_probe_duration_fn = NULL;
    s_probe_index_fn    = NULL;
    s_probe_base        = 0;

#ifdef REWAMP_WITH_SID
    if (rewamp_is_sid_file(path))
        return rewamp_sid_probe_subsong_count(path);
        // SID titles/durations come from the HVSC/STIL server path; leave fns NULL.
#endif
#ifdef REWAMP_WITH_KSS
    // libkss owns MSX chiptune playback; count/titles/durations from its KSS
    // header (libgme can't reliably count KSS tracks). `.mus` is content-verified
    // by KSS_load_file — a non-MSX .mus returns 0 here → fall through to GME.
    if (rewamp_is_kss_file(path)) {
        const int n = rewamp_kss_probe_subsong_count(path);
        if (n > 0) {
            s_probe_title_fn    = rewamp_kss_probe_get_title;
            s_probe_duration_fn = rewamp_kss_probe_get_duration_ms;
            // KSS song numbers are absolute; the native list starts at trk_min so
            // the Dart layer offsets its 0-based positions by this base.
            s_probe_base        = rewamp_kss_probe_base();
            return n;
        }
    }
#endif
#ifdef REWAMP_WITH_OPENMPT
    // Tracker modules (s3m/xm/it/mod/…) can hold several subsongs (order-list
    // sequences). Only claim when there really are >1 — a single-song module
    // (n<=1) falls through so it isn't treated as a container. libopenmpt fails
    // to open non-module files (nsf/gbs/…) → n==0 → also falls through to GME.
    {
        const int n = rewamp_openmpt_probe_subsong_count(path);
        if (n > 1) {
            s_probe_title_fn    = rewamp_openmpt_probe_get_title;
            s_probe_duration_fn = NULL;   // openmpt exposes no per-subsong ms here
            return n;
        }
    }
#endif
#ifdef REWAMP_WITH_XMP
    // Same idea for the formats libopenmpt cannot load: libxmp counts the
    // module's order-list SEQUENCES and, unlike libopenmpt, gives a duration
    // for each one. AFTER the libopenmpt branch, so a module both can read
    // keeps libopenmpt's answer (and its subsong titles).
    {
        const int n = rewamp_xmp_probe_subsong_count(path);
        if (n > 1) {
            s_probe_title_fn    = NULL;   // libxmp names no sequence
            s_probe_duration_fn = rewamp_xmp_probe_get_duration_ms;
            return n;
        }
    }
#endif
#ifdef REWAMP_WITH_SNDH
    // .sndh files commonly bundle several subsongs (up to 128); SndhFile's own
    // header parsing gives the exact count + per-subsong titles/durations.
    {
        const int n = rewamp_sndh_probe_subsong_count(path);
        if (n > 0) {
            s_probe_title_fn    = rewamp_sndh_probe_get_title;
            s_probe_duration_fn = rewamp_sndh_probe_get_duration_ms;
            s_probe_base        = rewamp_sndh_probe_base();
            return n;
        }
    }
#endif
#ifdef REWAMP_WITH_SC68
    // .sc68 disks are multi-track (up to 99); sc68_music_info gives count +
    // per-track titles/durations. Extension-gated inside the probe fn.
    {
        const int n = rewamp_sc68_probe_subsong_count(path);
        if (n > 0) {
            s_probe_title_fn    = rewamp_sc68_probe_get_title;
            s_probe_duration_fn = rewamp_sc68_probe_get_duration_ms;
            s_probe_base        = rewamp_sc68_probe_base();
            return n;
        }
    }
#endif
#ifdef REWAMP_WITH_ZXTUNE
    // An .ay is a container — a real one on disk holds eleven tunes — and
    // nothing exposed them, so only the first was ever reachable. zxtune claims
    // ONLY when it finds more than one module: a single-song file falls through
    // untouched, which keeps this branch harmless for every format libgme owns
    // and leaves libgme the .ay variants zxtune cannot parse (only ZXAYEMUL is
    // supported; a ZXAYAMAD fails to open here).
    {
        const int n = rewamp_zxtune_probe_subsong_count(path);
        if (n > 1) {
            s_probe_title_fn    = rewamp_zxtune_probe_get_title;
            s_probe_duration_fn = NULL;   /* zxtune exposes no per-module length */
            return n;
        }
    }
#endif
#ifdef REWAMP_WITH_FURNACE
    // Un `.ftm` FamiTracker porte couramment une dizaine de morceaux, que
    // Furnace importe en sous-chansons; le décodeur savait déjà en jouer une
    // (`?subsong=N`), rien ne les COMPTAIT. La sonde se garde elle-même par
    // extension (charger un module coûte une init de DivEngine), et ne
    // revendique qu'au-delà d'une sous-chanson: un module simple retombe sur
    // la suite, donc cette branche est inerte pour tout ce que libgme possède.
    {
        const int n = rewamp_furnace_probe_subsong_info(path);
        if (n > 1) {
            s_probe_title_fn    = rewamp_furnace_probe_get_title;
            s_probe_duration_fn = rewamp_furnace_probe_get_duration_ms;
            return n;
        }
    }
#endif
#ifdef REWAMP_WITH_ASAP
    // AVANT libgme, et c'est le point: libgme a bien un Sap_Emu, mais il
    // REFUSE les `.sap` de `TYPE D` (« Digimusic not supported », un return sec
    // dans son parse_info) et ne connaît AUCUN des autres formats ASAP (cmc,
    // rmt, tmc, mpt…). La sonde rendait donc 0 et l'écran des sous-chansons
    // affichait « Impossible de lire les pistes » sur un fichier qu'ASAP joue
    // sans broncher — mesuré sur `asma/Games/Ghostbusters.sap` (TYPE D,
    // SONGS 2).
    //
    // La branche est bornée par la liste d'extensions d'ASAP ET par le succès
    // d'ASAPInfo_Load: ce qui n'est pas à lui retombe sur libgme, inchangé.
    {
        const int n = rewamp_asap_probe_subsong_count(path);
        if (n > 0) {
            s_probe_title_fn    = NULL;   // ASAP ne nomme pas ses sous-chansons
            s_probe_duration_fn = rewamp_asap_probe_get_duration_ms;
            return n;
        }
    }
#endif
#ifdef REWAMP_WITH_ADPLUG
    // Un `.adl` Westwood est une TABLE de morceaux et personne ne la comptait:
    // la chaîne finissait chez libgme, qui ne connaît pas le format — donc 0,
    // et l'écran des sous-chansons annonçait « Impossible de lire les pistes »
    // sur un fichier qui en tient des dizaines.
    //
    // Et elle ÉCARTE ce qu'AdPlug laisse dans son compte (`numsubsongs` =
    // index de la dernière entrée valide + 1, TROUS COMPRIS): DUNE19.ADL
    // annonce 74 pistes pour 43 qui jouent une note. La liste rendue est donc
    // CREUSE — c'est le seul consommateur de s_probe_index_fn, et la raison
    // pour laquelle l'index ne peut plus se déduire de la position.
    //
    // Bornée à l'extension `.adl` et au contenu (`CadlPlayer::load` refait ses
    // contrôles de plausibilité): tout le reste retombe sur la suite, inchangé.
    {
        const int n = rewamp_adplug_probe_subsong_count(path);
        if (n > 0) {
            s_probe_title_fn    = NULL;   // le format ne nomme pas ses morceaux
            s_probe_duration_fn = rewamp_adplug_probe_get_duration_ms;
            s_probe_index_fn    = rewamp_adplug_probe_get_index;
            return n;
        }
    }
#endif
#ifdef REWAMP_WITH_GBSPLAY
    // Un `.gbr` est un rip du DRIVER Game Boy: pas de table de morceaux, donc
    // libgbsplay annonce 255 — la valeur maximale d'un `uint8_t`, qui veut dire
    // « je ne sais pas ». La sonde demande au PILOTE lequel joue vraiment (même
    // principe que `.adl`: on n'écarte que ce qui est PROUVÉ muet), et la liste
    // rendue est CREUSE, d'où s_probe_index_fn.
    //
    // Bornée à la magie GBRF: un `.gbs` porte un vrai compte dans son en-tête
    // et reste à libgme, plus bas.
    {
        const int n = rewamp_gbsplay_probe_subsong_count(path);
        if (n > 0) {
            s_probe_title_fn    = NULL;   // le format ne nomme rien
            s_probe_duration_fn = NULL;   // ni ne mesure rien
            s_probe_index_fn    = rewamp_gbsplay_probe_get_index;
            return n;
        }
    }
#endif
#ifdef REWAMP_WITH_GME
    {
        const int n = rewamp_gme_probe_subsong_info(path);
        if (n > 0) {
            s_probe_title_fn    = rewamp_gme_probe_get_title;
            s_probe_duration_fn = rewamp_gme_probe_get_duration_ms;
        }
        return n;
    }
#else
    (void)path;
    return 1;
#endif
}
