// libgsf plugin — Game Boy Advance .gsf/.minigsf via the VBA (VisualBoyAdvance)
// GBA emulator core. Vendored from Modizer's libs/libgsf (already carries the
// Modizer per-voice oscilloscope patch in VBA/Sound.cpp: it writes the 6 GBA
// channels into m_voice_buff[]). Compiled only when REWAMP_WITH_GSF is defined.
//
// The VBA core is PUSH-driven: CPULoop() periodically calls
// systemWriteDataToSoundBuffer() → writeSound(), which hands us one chunk of
// int16 stereo in soundFinalWave[0..soundBufferLen]. We adapt it to rewamp's
// pull-based read() with a FIFO: read() runs EmulationLoop() until the FIFO
// holds enough frames, then drains it.
#ifdef REWAMP_WITH_GSF

#include "rewamp_plugin.h"

/* Boucle forcée (rewamp_audio.c) — lus à l'open. */
extern "C" int g_force_loop_mode;
extern "C" int g_force_loop_native_veto;
#include "rewamp_channel_data.h"   // per-voice scope + chip grouping
#include "rewamp_psf_fade.h"   // fondu de fin décrit par le tag `fade`
#include "libpsflib/psflib.h"      // GSF is a PSF (0x22): read length/fade tags

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>   // strcasecmp

// ── VBA / gsf core entry points (gsf.cpp, VBA/*) ────────────────────────────
extern "C" {
int  GSFRun(char* filename);
void GSFClose(void);
int  EmulationLoop(void);   // BOOL → int
void GSFSoundChannelsEnable(int channels, bool active);
extern unsigned short soundFinalWave[2304];
extern int soundBufferLen;    // bytes ready in soundFinalWave after writeSound
extern int GSFsndSamplesPerSec;
extern int GSFshoudlReset;
extern char soundEcho, soundLowPass;   // 1-byte flags in Sound.cpp
extern int  soundQuality, soundInterpolation;
}

// ── App-provided globals the VBA core references (were in Modizer's .mm) ─────
extern "C" {
int TrackLength      = 0;      // ms; 0 → play until natural end / silence
int FadeLength       = 0;
int IgnoreTrackLength = 1;     // rewamp bounds duration itself (server songlen)
int DefaultLength    = 150000;
int playforever      = 0;
int TrailingSilence  = 1000;
int DetectSilence    = 1;
int silencedetected  = 0;
int silencelength    = 5;      // seconds of silence → end
int sndSamplesPerSec = 44100;
int cpupercent       = 0;
int sndNumChannels   = 2;
int sndBitsPerSample = 16;
// VBA scales the mix by relvolume/1000, so 1000 = unity. GSFRun overwrites
// relvolume from the file's `volume` tag, or falls back to defvolume when the
// tag is absent (the common case). Modizer uses 1000; 256 made gsf ~4x quieter
// than every other backend.
int relvolume        = 1000;
int defvolume        = 1000;
int deflen           = 120;      // default track length (s) when tag absent
int deffade          = 5;        // default fade (s)
float decode_pos_ms  = 0.0f;
int   seek_needed    = -1;
}

#define GSF_CHANNELS 2
#define GSF_VOICES   6         // GBA: 4 PSG + 2 DirectSound (Modizer capture)
// FIFO of interleaved int16 stereo frames.
#define GSF_FIFO_FRAMES (65536)

static volatile int g_playing = 0;
extern "C" void end_of_track(void) { g_playing = 0; }

struct RewampDecoder {
    int16_t* fifo;
    int      head, tail, fill;   // frames
    int      rate;
    int      ended;
    uint64_t totalFrames;        // from the length+fade tags; 0 = unknown
    uint64_t fadeFrames = 0;     // rampe finale (tag `fade`), 0 = aucune
    uint64_t framePos;           // frames emitted so far
};

// ── PSF-tag length reading (GSF is a PSF v0x22) ─────────────────────────────
static void*  gsf_psf_fopen(const char* uri)                        { return fopen(uri, "rb"); }
static size_t gsf_psf_fread(void* b, size_t s, size_t n, void* h)   { return fread(b, s, n, (FILE*)h); }
static int    gsf_psf_fseek(void* h, int64_t o, int w)              { return fseek((FILE*)h, (long)o, w); }
static int    gsf_psf_fclose(void* h)                               { return fclose((FILE*)h); }
static int64_t gsf_psf_ftell(void* h)                               { return ftell((FILE*)h); }
static const psf_file_callbacks kGsfPsfCbs = {
    "\\/:", gsf_psf_fopen, gsf_psf_fread, gsf_psf_fseek, gsf_psf_fclose, gsf_psf_ftell,
};

// Parse "m:ss.xxx" / "ss.xxx" into milliseconds (least-significant field = seconds).
static int gsf_time_ms(const char* v) {
    char buf[64];
    strncpy(buf, v, sizeof(buf) - 1); buf[sizeof(buf) - 1] = '\0';
    char* nl = strchr(buf, '\n'); if (nl) *nl = '\0';
    const char* parts[4] = {0}; int np = 0;
    char* tok = strtok(buf, ":");
    while (tok && np < 4) { parts[np++] = tok; tok = strtok(NULL, ":"); }
    double total = 0.0, mult = 1000.0;
    for (int i = np - 1; i >= 0; i--) { total += atof(parts[i]) * mult; mult *= 60.0; }
    return (int)total;
}

struct gsf_tag_state {
    int  length_ms, fade_ms;
    char title[256], artist[256], game[256], year[64], copyright[256], gsfby[128];
};
static void gsf_copy_tag(char* dst, size_t n, const char* v) {
    rewamp_psf_tag_copy(dst, n, v);   // 1re ligne, Shift-JIS → UTF-8 au besoin
}
static int gsf_tag_cb(void* ctx, const char* name, const char* value) {
    struct gsf_tag_state* st = (struct gsf_tag_state*)ctx;
    if (!name || !value) return 0;
    if      (strcasecmp(name, "length")    == 0) st->length_ms = gsf_time_ms(value);
    else if (strcasecmp(name, "fade")      == 0) st->fade_ms   = gsf_time_ms(value);
    else if (strcasecmp(name, "title")     == 0) gsf_copy_tag(st->title,     sizeof(st->title),     value);
    else if (strcasecmp(name, "artist")    == 0) gsf_copy_tag(st->artist,    sizeof(st->artist),    value);
    else if (strcasecmp(name, "game")      == 0) gsf_copy_tag(st->game,      sizeof(st->game),      value);
    else if (strcasecmp(name, "year")      == 0) gsf_copy_tag(st->year,      sizeof(st->year),      value);
    else if (strcasecmp(name, "copyright") == 0) gsf_copy_tag(st->copyright, sizeof(st->copyright), value);
    else if (strcasecmp(name, "gsfby")     == 0) gsf_copy_tag(st->gsfby,     sizeof(st->gsfby),     value);
    return 0;
}

// Only one gsf decoder is live at a time (the VBA core is a singleton).
static RewampDecoder* g_active = nullptr;

// Called by the VBA core (systemWriteDataToSoundBuffer) with one chunk.
extern "C" void writeSound(void) {
    RewampDecoder* d = g_active;
    if (!d || !d->fifo) return;
    const int frames = soundBufferLen / (2 * GSF_CHANNELS);  // int16 stereo
    const int16_t* src = (const int16_t*)soundFinalWave;
    for (int i = 0; i < frames; i++) {
        if (d->fill >= GSF_FIFO_FRAMES) break;   // overrun: drop (shouldn't happen)
        d->fifo[d->head * 2 + 0] = src[i * 2 + 0];
        d->fifo[d->head * 2 + 1] = src[i * 2 + 1];
        d->head = (d->head + 1) % GSF_FIFO_FRAMES;
        d->fill++;
    }
}

static const char* const kGsfExts[] = { "gsf", "minigsf", "gsflib", NULL };

static int gsf_probe(const char* ext, const uint8_t* hdr, size_t n) {
    // PSF magic "PSF" + version 0x22 (GSF). minigsf shares the container.
    int magic = n >= 4 && hdr[0] == 'P' && hdr[1] == 'S' && hdr[2] == 'F' &&
                hdr[3] == 0x22;
    int extMatch = rewamp_ext_in_list(ext, kGsfExts);
    if (magic) return extMatch ? 110 : 100;
    if (extMatch) return 70;
    return 0;
}

static RewampDecoder* gsf_open(const char* path, RewampAudioFormat* outFormat) {
    /* Mode 1 (N boucles): pas de compte natif -> veto, le generique
     * Dart compte les passes (voir configure_loop ci-dessous). */
    if (g_force_loop_mode == 1) g_force_loop_native_veto = 1;
    if (!path) return NULL;

    char clean[4096];
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strchr(clean, '?');
    if (q) *q = '\0';

    // The VBA core is a singleton — close any previous instance first.
    if (g_active) { GSFClose(); g_active = nullptr; }

    soundQuality       = 1;
    /* Engine params (Settings → Moteurs → GSF) — also live via
     * gsf_param_changed (the VBA sound globals are read continuously).
     * Modizer defaults: interpolation ON, low-pass ON, echo OFF. */
    soundInterpolation = (int)rewamp_get_engine_param("gsf", "interpolation", 1);
    soundLowPass = (char)(int)rewamp_get_engine_param("gsf", "lowpass", 1);
    soundEcho    = (char)(int)rewamp_get_engine_param("gsf", "echo", 0);
    GSFshoudlReset = 0;

    if (!GSFRun(clean)) return NULL;

    RewampDecoder* d = (RewampDecoder*)calloc(1, sizeof(RewampDecoder));
    if (!d) { GSFClose(); return NULL; }
    d->fifo = (int16_t*)malloc((size_t)GSF_FIFO_FRAMES * 2 * sizeof(int16_t));
    if (!d->fifo) { free(d); GSFClose(); return NULL; }
    d->rate = GSFsndSamplesPerSec > 0 ? GSFsndSamplesPerSec : 44100;

    // Tags via psflib (title/artist/game/year/… + length/fade), like Modizer's
    // mmp_gsfLoad. GSF drivers loop forever, so the length+fade tag is also what
    // bounds the track (0 = no tag → driver's own end/silence). The tags feed
    // the ⓘ info panel (rewamp_track_message_*): the plugin path gets no generic
    // Format/Duration append, so we add them here too.
    struct gsf_tag_state ts;
    memset(&ts, 0, sizeof(ts));
    if (psf_load(clean, &kGsfPsfCbs, 0, 0, 0, gsf_tag_cb, &ts, 0) >= 0) {
        int len_ms = ts.length_ms + ts.fade_ms;
        if (len_ms > 0)
            d->totalFrames = (uint64_t)((double)len_ms / 1000.0 * d->rate);
        d->fadeFrames = rewamp_psf_fade_frames(ts.fade_ms, (uint32_t)d->rate,
                                               d->totalFrames);
    }
    d->framePos = 0;

    if (ts.title[0])     rewamp_track_message_append("Title: %s\n", ts.title);
    if (ts.game[0])      rewamp_track_message_append("Game: %s\n", ts.game);
    if (ts.artist[0])    rewamp_track_message_append("Artist: %s\n", ts.artist);
    if (ts.year[0])      rewamp_track_message_append("Year: %s\n", ts.year);
    if (ts.copyright[0]) rewamp_track_message_append("Copyright: %s\n", ts.copyright);
    if (ts.gsfby[0])     rewamp_track_message_append("GSF by: %s\n", ts.gsfby);
    rewamp_track_message_append("Format: GSF, %d Hz, stereo\n", d->rate);
    if (d->totalFrames > 0) {
        unsigned total = (unsigned)(d->totalFrames / d->rate);
        rewamp_track_message_append("Duration: %u:%02u\n", total / 60, total % 60);
    }

    // Per-voice scope: Sound.cpp writes the 6 GBA channels into m_voice_buff[].
    // Ring MUST be >= ~2212 (rewamp_channel_buf_triggered's search window) or
    // the scope's stabilization trigger silently never runs — see PLUGINS.md
    // §2.3 (was bare SOUND_BUFFER_SIZE_SAMPLE=512, undersized, fixed 2026-07-07).
    rewamp_channel_data_reset(GSF_VOICES);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);
    rewamp_channel_data_set_ring_circular(1);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("GBA", 0, GSF_VOICES);
    static const char* kNames[GSF_VOICES] = {
        "Square 1", "Square 2", "Wave", "Noise", "DirectSound A", "DirectSound B"
    };
    for (int i = 0; i < GSF_VOICES; i++) rewamp_voice_set_name(i, kNames[i]);

    g_active  = d;
    g_playing = 1;

    if (outFormat) {
        outFormat->channels   = GSF_CHANNELS;
        outFormat->sampleRate = (uint32_t)d->rate;
    }
    return d;
}

static uint64_t gsf_read(RewampDecoder* d, float* out, uint64_t frameCount) {
    if (!d || !d->fifo || !out || frameCount == 0 || d->ended) return 0;
    const uint64_t fadeBase = d->framePos;
    g_active = d;

    // Enforce the tagged length (length + fade): GSF drivers loop forever.
    if (d->totalFrames > 0) {
        if (d->framePos >= d->totalFrames) { d->ended = 1; return 0; }
        uint64_t remain = d->totalFrames - d->framePos;
        if (frameCount > remain) frameCount = remain;
    }

    uint64_t produced = 0;
    const float inv = 1.0f / 32768.0f;
    while (produced < frameCount) {
        if (d->fill == 0) {
            if (!g_playing) { d->ended = 1; break; }
            // Run the emulator to refill the FIFO (writeSound appends).
            if (!EmulationLoop()) { d->ended = 1; break; }
            if (d->fill == 0 && !g_playing) { d->ended = 1; break; }
            continue;
        }
        int16_t l = d->fifo[d->tail * 2 + 0];
        int16_t r = d->fifo[d->tail * 2 + 1];
        d->tail = (d->tail + 1) % GSF_FIFO_FRAMES;
        d->fill--;
        out[produced * 2 + 0] = l * inv;
        out[produced * 2 + 1] = r * inv;
        produced++;
    }
    rewamp_psf_fade_apply(out, produced, 2, fadeBase,
                          d->totalFrames, d->fadeFrames);
    d->framePos += produced;
    return produced;
}

extern "C" volatile int    g_seek_cancel;
extern "C" volatile int    g_is_seeking;
extern "C" volatile double g_seek_progress_s;

static void gsf_seek(RewampDecoder* d, uint64_t frameIndex) {
    if (!d) return;
    // No random seek in the VBA core: restart and render-skip to the target.
    g_active = d;
    GSFshoudlReset = 1;   // Sound.cpp reset hook
    // Drain FIFO + re-run from the start.
    d->head = d->tail = d->fill = 0;
    d->ended = 0;
    d->framePos = 0;             // gsf_read re-counts as we skip forward
    g_playing = 1;
    // Skip forward by discarding rendered frames. Reports progress via
    // g_is_seeking/g_seek_progress_s (Dart seek progress bar) and honors
    // g_seek_cancel so a new seek request aborts a slow one promptly.
    g_is_seeking = 1;
    uint64_t remaining = frameIndex;
    float scratch[4096 * 2];
    while (remaining > 0 && !d->ended && !g_seek_cancel) {
        uint64_t chunk = remaining > 4096 ? 4096 : remaining;
        uint64_t got = gsf_read(d, scratch, chunk);
        if (got == 0) break;
        remaining -= got;
        g_seek_progress_s = (double)d->framePos / (double)(d->rate > 0 ? d->rate : 1);
    }
    g_is_seeking = 0;
}

static uint64_t gsf_length(RewampDecoder* d) {
    // From the GSF length+fade tags (0 when the file carries no length tag, in
    // which case rewamp/server bounds the duration).
    return d ? d->totalFrames : 0;
}


/* Boucle FORCÉE (repeat-morceau): le moteur ÉMULÉ boucle DE LUI-MÊME au point
 * de boucle de la musique — c'est notre troncature à totalFrames (longueur de
 * catalogue/tag) qui coupait, et la relance générique repartait du DÉBUT, ce
 * qui s'entend (même famille que le .ay zxtune, « Midnight Resistance »).
 * Mode 2 (infini): on lève la troncature, l'émulation joue et boucle au bon
 * endroit. Mode 1 (N passes): pas de compte natif ici → VETO posé à l'open,
 * le générique Dart compte — comportement inchangé. Filet: un moteur qui
 * s'arrêterait quand même rend un read() à 0 → rechargement replayCurrent,
 * exactement le comportement d'avant ce câblage. */
static void gsf_configure_loop_fn(RewampDecoder* dec, int mode, int count) {
    (void)count;
    if (dec == NULL) return;
    if (mode == 2) dec->totalFrames = 0;
    // Toute boucle forcée retire le fondu natif: voir rewamp_psf_fade.h.
    if (mode != 0) dec->fadeFrames = 0;
}

static void gsf_close(RewampDecoder* d) {
    if (!d) return;
    if (g_active == d) {
        g_playing = 0;
        GSFClose();
        g_active = nullptr;
    }
    free(d->fifo);
    free(d);
}

/* Live settings change (called under the decode lock — the VBA sound globals
 * are consulted continuously by the mixer). */
static void gsf_param_changed(RewampDecoder* dec, const char* key) {
    (void)dec; (void)key;
    soundInterpolation = (int)rewamp_get_engine_param("gsf", "interpolation", 1);
    soundLowPass = (char)(int)rewamp_get_engine_param("gsf", "lowpass", 1);
    soundEcho    = (char)(int)rewamp_get_engine_param("gsf", "echo", 0);
}

static const RewampPluginVTable kGsfVTable = {
    "gsf",
    gsf_probe,
    gsf_open,
    gsf_read,
    gsf_seek,
    gsf_length,
    gsf_close,
    gsf_configure_loop_fn,
    0,                  /* supportsNativeFadeout */
    "gsf",              /* engine_id */
    gsf_param_changed,  /* live settings */
};

extern "C" const RewampPluginVTable* rewamp_gsf_plugin(void) { return &kGsfVTable; }

#endif /* REWAMP_WITH_GSF */
