// MDX plugin — Sharp X68000 MML music (.mdx, with its .pdx sample bank) via
// the vendored mdxplay (third_party/mdxplay: BKG's MDX player — YM2151 FM +
// the PCM8 sample driver — plus freeverb, which mdx_load enables by default).
//
// mdxplay is PUSH-driven and blocking: mdx_play() parses the whole MML to the
// end, calling do_pcm8() to render, which hands finished buffers to an
// app-provided mdx_update(). This plugin drives it the other way round, the
// same shape as rewamp_plugin_gsf.cpp: mdx_update() is implemented here as a
// FIFO append, and read() advances the engine only as far as the frames it was
// asked for. That's possible because mdxplay also exposes a tick-at-a-time
// parser (mdx_parse_mml_ym2151_async), whose audio rendering upstream left
// commented out — the render loop below is mdx_parse_mml_ym2151()'s own,
// reproduced around the async tick: each tick advances mdx->elapsed_time, and
// do_pcm8() renders 1 ms (PCM8_SYSTEM_RATE) of 44.1 kHz 16-bit stereo per call
// until the audio clock catches up with it.
//
// Per-voice scope/notes/mute already live in the vendored cores (grep YOYOFR in
// mdx_ym2151.c = voices 0-7 (YM2151 FM), pcm8.c = voices 8-15 (PCM8 samples),
// mdxmml_ym2151.c = the realtracks counter); they read generic_mute_mask
// directly and gate the real mix, so the plugin wires no mute.
//
// Process-global singleton (mdxplay's __GETSELF instances) — fine, rewamp never
// runs two decoders concurrently.
#ifdef REWAMP_WITH_MDX

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Included by relative path, deliberately: mdxplay's dir holds a `version.h`
// (one of nine under third_party/) and `mdx.h`/`pcm8.h`, so it must never go on
// a pod-wide or cmake-target-wide include path. A quote-include resolves
// against the including file's own directory first, so this needs no -I at all
// — and mdx.h's own quote-includes then resolve from mdxplay/. Same idiom as
// rewamp_plugin_vgm.cpp.
extern "C" {
#include "../third_party/mdxplay/mdx.h"
}

#define MDX_RATE       44100
#define MDX_VOICES     16          // 0-7 YM2151 FM, 8-15 PCM8 samples
#define MDX_FM_VOICES  8
#define MDX_TICK_US    1000        // PCM8_SYSTEM_RATE: one do_pcm8() = 1 ms
#define MDX_INF_LOOPS  32767       // mdxplay's own "large enough" sentinel

// ── globals the vendored cores expect the app to define ──────────────────────
// seek_needed/decode_pos_ms/PLAYBACK_FREQ are renamed to mdx_* by a per-engine
// -D (cmake + both Podfiles): rewamp_plugin_gsf.cpp already defines its own
// seek_needed/decode_pos_ms for VBA, and sharing one global between two
// unrelated engines is a silent coupling waiting to happen (same reasoning as
// gbsplay's gbs_seek_needed rename).
extern "C" {
int   mdx_seek_needed   = -1;   // -1 = not seeking; pcm8_write_dev gates on it
float mdx_decode_pos_ms = 0.0f;
int   mdx_playback_freq = MDX_RATE;
int   MDXshoudlReset    = 0;    // [sic] upstream spelling; mid-play restart flag
}

// ── the FIFO the engine pushes into ──────────────────────────────────────────
// do_pcm8() emits pcm_buffer_size (SOUND_BUFFER_SIZE_SAMPLE*4 = 2048) bytes at
// a time: 16-bit stereo, host-endian.
struct MdxFifo {
    int16_t* buf;
    size_t   cap;      // in frames
    size_t   count;    // frames available
};

static MdxFifo s_fifo;
static int     s_discard;   // seek: run the engine but throw its output away

static void fifo_reset(void) { s_fifo.count = 0; }

static void fifo_push(const int16_t* src, size_t frames) {
    if (s_discard) return;
    if (s_fifo.count + frames > s_fifo.cap) {
        size_t cap = s_fifo.cap ? s_fifo.cap : 8192;
        while (cap < s_fifo.count + frames) cap *= 2;
        int16_t* nb = (int16_t*)realloc(s_fifo.buf, cap * 2 * sizeof(int16_t));
        if (!nb) return;   // drop rather than die; the tune just glitches
        s_fifo.buf = nb;
        s_fifo.cap = cap;
    }
    memcpy(s_fifo.buf + s_fifo.count * 2, src, frames * 2 * sizeof(int16_t));
    s_fifo.count += frames;
}

static size_t fifo_pop(float* out, size_t frames) {
    if (frames > s_fifo.count) frames = s_fifo.count;
    for (size_t i = 0; i < frames * 2; i++) out[i] = s_fifo.buf[i] / 32768.0f;
    s_fifo.count -= frames;
    if (s_fifo.count)
        memmove(s_fifo.buf, s_fifo.buf + frames * 2, s_fifo.count * 2 * sizeof(int16_t));
    return frames;
}

// pcm8_write_dev() calls this with each finished buffer — this IS the engine's
// audio sink (upstream's blocked write to the sound device).
extern "C" void mdx_update(unsigned char* data, int len, int end_reached) {
    (void)end_reached;
    fifo_push((const int16_t*)data, (size_t)len / 4);   // 4 bytes per stereo frame
}

extern "C" {
void* mdx_parse_mml_ym2151_async_initialize(MDX_DATA*, PDX_DATA*);
int   mdx_parse_mml_ym2151_async(void*);
void  mdx_parse_mml_ym2151_async_finalize(void*);
void  do_pcm8(int flush_for_end);
}

// Forced-loop globals the engine layer publishes before each open().
extern "C" int    g_force_loop_mode;
extern "C" double g_force_base_duration_secs;

struct RewampDecoder {
    MDX_DATA* mdx;
    PDX_DATA* pdx;
    void*     parser;      // the async parser instance (a singleton, in truth)
    uint64_t  totalFrames; // single-pass length; 0 = unknown
    uint64_t  framePos;
    int64_t   audioClockUs; // how far do_pcm8() has rendered
    int       finished;
    char      path[4096];
};

static const char* const kMdxExts[] = { "mdx", NULL };

static int mdx_probe(const char* ext, const uint8_t* h, size_t n) {
    (void)h; (void)n;
    // No magic: an .mdx starts with its (Shift-JIS, arbitrary) title text.
    return rewamp_ext_in_list(ext, kMdxExts) ? 90 : 0;
}

static void mdx_setup_voices(void) {
    m_genNumVoicesChannels = MDX_VOICES;
    rewamp_channel_data_reset(MDX_VOICES);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);
    rewamp_channel_data_set_ring_circular(1);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("YM2151 FM", 0, MDX_FM_VOICES);
    rewamp_voices_add_chip("PCM8", MDX_FM_VOICES, MDX_VOICES - MDX_FM_VOICES);
}

// Advance the engine by one MML tick and render the audio that tick covers.
// Returns 0 once every track has finished (or the fade-out has run out).
static int mdx_advance_tick(RewampDecoder* dec) {
    if (!mdx_parse_mml_ym2151_async(dec->parser)) return 0;
    // The tick moved mdx->elapsed_time forward; render until the audio clock
    // catches up. (Upstream's mdx_parse_mml_ym2151 does exactly this with two
    // timevals; elapsed_time is in microseconds despite its "mili-second"
    // comment — mdx_get_length divides it by 1000 to get ms.)
    while (dec->audioClockUs < dec->mdx->elapsed_time) {
        do_pcm8(0);
        dec->audioClockUs += MDX_TICK_US;
    }
    return 1;
}

static RewampDecoder* mdx_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    char cleanPath[4096];
    snprintf(cleanPath, sizeof(cleanPath), "%s", path);
    char* q = strrchr(cleanPath, '?');
    if (q) *q = '\0';

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) return NULL;
    snprintf(dec->path, sizeof(dec->path), "%s", cleanPath);

    // maxloop=1 → the length measured below is ONE pass (plus the tune's own
    // fade), which is the base the generic Dart loop needs. mdx_load also
    // resolves the .pdx sample bank: it looks for the name the .mdx header
    // carries next to the file (case-insensitively), which is where the
    // server's aux_files download puts it.
    if (mdx_load(cleanPath, &dec->mdx, &dec->pdx, 1) != 0) { free(dec); return NULL; }

    // Runs the parser to the end with no audio rendering — cheap, and it is
    // also what counts realtracks. Leaves the track work area re-initialised.
    int lengthMs = mdx_get_length(dec->mdx, dec->pdx);
    if (lengthMs <= 0 && g_force_base_duration_secs > 0.0)
        lengthMs = (int)(g_force_base_duration_secs * 1000.0);
    if (lengthMs > 0) dec->totalFrames = (uint64_t)lengthMs * MDX_RATE / 1000;

    // Force-loop on → play indefinitely and let Dart's _tickForceLoop own the
    // repeats and the fade (the length above stays the single-pass base). The
    // tune's own fade-out would otherwise end it after the first pass.
    if (g_force_loop_mode != 0) dec->mdx->max_infinite_loops = MDX_INF_LOOPS;

    mdx_setup_voices();

    // The title is the raw Shift-JIS text the .mdx header opens with (mdxplay
    // strdup's it verbatim), so it needs converting before it's published.
    unsigned char* title = mdx_get_title(dec->mdx);
    if (title && title[0]) {
        char utf8[1024];
        rewamp_sjis_to_utf8((const char*)title, utf8, sizeof(utf8));
        rewamp_track_message_append("Title: %s\n", utf8);
    }
    if (title) free(title);
    rewamp_track_message_append("Format: MDX (Sharp X68000), YM2151 FM");
    if (dec->mdx->haspdx) rewamp_track_message_append(" + PCM8 samples (%s)", dec->mdx->pdx_name);
    rewamp_track_message_append(", %d Hz, stereo\n", MDX_RATE);
    if (dec->mdx->haspdx && !dec->mdx->pdx_enable)
        rewamp_track_message_append("Note: sample bank %s not found — PCM parts are silent\n",
                                    dec->mdx->pdx_name);
    if (dec->totalFrames > 0) {
        unsigned total = (unsigned)(dec->totalFrames / MDX_RATE);
        rewamp_track_message_append("Duration: %u:%02u\n", total / 60, total % 60);
    }

    fifo_reset();
    s_discard = 0;
    dec->audioClockUs = 0;
    dec->parser = mdx_parse_mml_ym2151_async_initialize(dec->mdx, dec->pdx);
    if (!dec->parser) { mdx_close(dec->mdx, dec->pdx); free(dec); return NULL; }

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = MDX_RATE;
    }
    return dec;
}

static uint64_t mdx_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || frameCount == 0) return 0;

    while (s_fifo.count < frameCount && !dec->finished) {
        if (!mdx_advance_tick(dec)) {
            do_pcm8(1);          // flush whatever the last tick left pending
            dec->finished = 1;
        }
    }

    uint64_t got = fifo_pop(out, (size_t)frameCount);
    dec->framePos += got;
    return got;
}

// No native seek — the position IS the parser + chip state. Backward restarts
// the parser (cheap: the MML and samples stay loaded); both directions then run
// ticks with the output discarded (same idiom as UADE/vio2sf/SNDH/PMD).
static void mdx_seek_impl(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec) return;

    if (frameIndex < dec->framePos) {
        mdx_parse_mml_ym2151_async_finalize(dec->parser);
        dec->parser = mdx_parse_mml_ym2151_async_initialize(dec->mdx, dec->pdx);
        if (!dec->parser) return;
        dec->framePos     = 0;
        dec->audioClockUs = 0;
        dec->finished     = 0;
        fifo_reset();
    }

    s_discard = 1;
    while (dec->framePos < frameIndex && !dec->finished) {
        // The engine's own frame counter is the audio clock: a tick renders
        // (elapsed_time - audioClockUs)/1000 ms worth of frames.
        int64_t before = dec->audioClockUs;
        if (!mdx_advance_tick(dec)) { dec->finished = 1; break; }
        dec->framePos += (uint64_t)((dec->audioClockUs - before) * MDX_RATE / 1000000);
    }
    s_discard = 0;
    fifo_reset();
    dec->framePos = frameIndex;
}

static uint64_t mdx_length(RewampDecoder* dec) {
    return dec ? dec->totalFrames : 0;
}

static void mdx_close_impl(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->parser) mdx_parse_mml_ym2151_async_finalize(dec->parser);
    mdx_close(dec->mdx, dec->pdx);
    free(s_fifo.buf);
    s_fifo.buf = NULL;
    s_fifo.cap = s_fifo.count = 0;
    free(dec);
}

// configure_loop is NULL on purpose: mdxplay CAN repeat a tune
// (max_infinite_loops) but only fades it out with the file's own fade_out_speed
// — it has no way to honour a requested fade length, and no way to stop after
// N passes without that fade. The generic Dart loop owns both instead.
static const RewampPluginVTable kMdxVTable = {
    "mdx",
    mdx_probe,
    mdx_open,
    mdx_read,
    mdx_seek_impl,
    mdx_length,
    mdx_close_impl,
};

extern "C" const RewampPluginVTable* rewamp_mdx_plugin(void) { return &kMdxVTable; }

#endif /* REWAMP_WITH_MDX */
