// vgmstream plugin — decodes 200+ game audio formats via libvgmstream.
// Compiled only when REWAMP_WITH_VGMSTREAM is defined and libvgmstream is linked.
#ifdef REWAMP_WITH_VGMSTREAM

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"

extern "C" {
#include "libvgmstream.h"  // includes libvgmstream_streamfile.h transitively
}

#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <stdio.h>

// Forced-loop setting (Settings → Lecture) — see rewamp_audio.c.
extern "C" int    g_force_loop_mode;
extern "C" int    g_force_loop_count;
extern "C" int    g_force_fadeout_enabled;
extern "C" double g_force_fadeout_seconds;
extern "C" int    g_force_loop_native_veto;

// Extensions handled natively by miniaudio or by higher-priority plugins —
// vgmstream returns 0 for these so miniaudio's built-in decoders win.
// NOT ogg/opus: miniaudio only decodes wav/mp3/flac natively (no Vorbis/Opus
// backend registered), so those fail there — vgmstream decodes them via FFmpeg
// (ffmpeg-kit) where enabled; on non-FFmpeg builds vgmstream declines at open()
// and the miniaudio fallback still runs (same broken state as before, no regression).
static const char* const kSkipExts[] = {
    "wav", "mp3", "mp2", "mp1", "flac",
    // formats owned by other rewamp plugins
    "nsf", "nsfe", "gbs", "spc", "hes", "kss", "sap", "ay", "rsn",
    "vgm", "vgz", "s98", "gym", "dro",
    "mod", "xm", "s3m", "it", "mptm", "mtm", "669", "far", "med",
    "sid", "mus", "str", "prg",
    "psf", "minipsf", "psf2", "minipsf2", "ssflib", "minissf",
    "dsf", "minidsf", "qsf", "miniqsf",
    NULL
};

struct RewampDecoder {
    libvgmstream_t*  lib;
    libstreamfile_t* sf;
    int              channels;
    int              sampleRate;
    int64_t          totalSamples; // play_samples from format
    int16_t*         pcmBuf;       // temp PCM16 buffer for float conversion
    int              pcmBufFrames; // capacity in frames
};

static int vgm_probe_fn(const char* ext, const uint8_t* /*header*/, size_t /*headerSize*/) {
    if (ext) {
        for (int i = 0; kSkipExts[i]; i++) {
            if (strcasecmp(ext, kSkipExts[i]) == 0)
                return 0;
        }
    }
    // Moderate confidence — registered last, so only wins when nothing else claims it.
    return 50;
}

static RewampDecoder* vgm_open_fn(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    // Strip optional ?subsong=N suffix.
    char cleanPath[4096];
    int subsong = 0;
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) {
        subsong = atoi(q + 9);
        *q = '\0';
    }

    libstreamfile_t* sf = libstreamfile_open_from_stdio(cleanPath);
    if (!sf) return NULL;

    // Must init → open → setup (setup after open so mixing engine is ready).
    libvgmstream_t* lib = libvgmstream_init();
    if (!lib) { libstreamfile_close(sf); return NULL; }

    if (libvgmstream_open_stream(lib, sf, subsong) < 0) {
        libvgmstream_free(lib);
        libstreamfile_close(sf);
        return NULL;
    }

    libvgmstream_config_t cfg = {};
    cfg.loop_count            = 2.0;   // pre-existing defaults — kept as-is
    cfg.fade_time             = 10.0;  // when force-loop (Settings → Lecture) is off
    cfg.force_sfmt            = LIBVGMSTREAM_SFMT_PCM16;
    cfg.stereo_track          = 1;
    cfg.auto_downmix_channels = 2;
    // Native forced-loop: libvgmstream_config_t already has full native
    // loop-count + fade support (this plugin was already using it for its
    // own always-on defaults above) — override with the Settings → Lecture
    // values when active. Must happen here, before libvgmstream_setup();
    // there's no later hook that runs early enough (see rewamp_plugin.h's
    // configure_loop / supportsNativeFadeout doc comments).
    if (g_force_loop_mode == 2) {
        cfg.allow_play_forever = true;
        cfg.play_forever       = true;
    } else if (g_force_loop_mode == 1) {
        // libvgmstream's loop_count is "target loops" — total times the loop
        // section plays (its own default is 1 = one natural pass through).
        // Our g_force_loop_count is REPEATS after the first pass (Settings
        // "1 boucle" == loop once == 2 total passes), matching the generic
        // Dart fallback's loopCount+1 convention — off by one vs. vgmstream's
        // own scale without the +1.
        cfg.loop_count = (double)(g_force_loop_count + 1);
        if (g_force_fadeout_enabled && g_force_fadeout_seconds > 0.0) {
            cfg.fade_time  = g_force_fadeout_seconds;
            cfg.fade_delay = 0.0;
        } else {
            cfg.ignore_fade = true; // hard stop right at the target loop count
        }
    }
    libvgmstream_setup(lib, &cfg);

    const libvgmstream_format_t* fmt = lib->format;

    // Native loop only does anything when the stream actually HAS a loop point.
    // For a loopless stream, loop_count/play_forever are no-ops → veto native
    // looping so the generic Dart loop (seek-replay to base×passes + fade) takes
    // over, honoring the forced loop count. play_samples here is the single
    // length, exactly what the generic loop needs as its base.
    if (g_force_loop_mode != 0 && !fmt->loop_flag) {
        g_force_loop_native_veto = 1;
    }

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(RewampDecoder));
    if (!dec) {
        libvgmstream_free(lib);
        libstreamfile_close(sf);
        return NULL;
    }

    dec->lib          = lib;
    dec->sf           = sf;
    dec->channels     = fmt->channels;
    dec->sampleRate   = fmt->sample_rate;
    dec->totalSamples = fmt->play_samples;
    dec->pcmBuf       = NULL;
    dec->pcmBufFrames = 0;

    outFormat->channels   = (uint32_t)fmt->channels;
    outFormat->sampleRate = (uint32_t)fmt->sample_rate;

    // Info panel: everything libvgmstream describes about the stream.
    if (fmt->meta_name[0])
        rewamp_track_message_append("Format: %s\n", fmt->meta_name);
    if (fmt->codec_name[0])
        rewamp_track_message_append("Codec: %s\n", fmt->codec_name);
    if (fmt->layout_name[0] && strcasecmp(fmt->layout_name, "flat") != 0)
        rewamp_track_message_append("Layout: %s\n", fmt->layout_name);
    if (fmt->stream_name[0])
        rewamp_track_message_append("Stream: %s\n", fmt->stream_name);
    rewamp_track_message_append("Channels: %d @ %d Hz\n",
                                fmt->channels, fmt->sample_rate);
    if (fmt->input_channels > fmt->channels)
        rewamp_track_message_append("Source channels: %d (downmixed)\n",
                                    fmt->input_channels);
    if (fmt->loop_flag) {
        rewamp_track_message_append("Loop: %lld → %lld\n",
            (long long)fmt->loop_start, (long long)fmt->loop_end);
    }
    if (fmt->play_samples > 0 && fmt->sample_rate > 0) {
        unsigned total = (unsigned)(fmt->play_samples / fmt->sample_rate);
        rewamp_track_message_append("Duration: %u:%02u\n",
                                    total / 60, total % 60);
    }
    if (fmt->subsong_count > 1)
        rewamp_track_message_append("Subsongs: %d\n", fmt->subsong_count);

    return dec;
}

static uint64_t vgm_read_fn(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !out || frameCount == 0) return 0;

    // Grow PCM16 temp buffer if needed.
    if ((int)frameCount > dec->pcmBufFrames) {
        free(dec->pcmBuf);
        dec->pcmBuf = (int16_t*)malloc(frameCount * (size_t)dec->channels * sizeof(int16_t));
        dec->pcmBufFrames = (int)frameCount;
    }
    if (!dec->pcmBuf) return 0;

    // libvgmstream_fill returns a result code (>=0 ok), NOT a sample count;
    // the decoded frame count lands in lib->decoder->buf_samples. fill also
    // loops internally to satisfy the whole request, so one call suffices.
    int rc = libvgmstream_fill(dec->lib, dec->pcmBuf, (int)frameCount);
    if (rc < 0) return 0;
    uint64_t filled = dec->lib->decoder ? (uint64_t)dec->lib->decoder->buf_samples : 0;

    // Convert PCM16 → float32.
    const int samples = (int)(filled * (uint64_t)dec->channels);
    for (int i = 0; i < samples; i++)
        out[i] = dec->pcmBuf[i] * (1.0f / 32768.0f);

    return filled;
}

static void vgm_seek_fn(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec) return;
    libvgmstream_seek(dec->lib, (int64_t)frameIndex);
}

static uint64_t vgm_length_fn(RewampDecoder* dec) {
    if (!dec || dec->totalSamples <= 0) return 0;
    return (uint64_t)dec->totalSamples;
}

static void vgm_close_fn(RewampDecoder* dec) {
    if (!dec) return;
    libvgmstream_free(dec->lib);
    libstreamfile_close(dec->sf);
    free(dec->pcmBuf);
    free(dec);
}

// configure_loop is called AFTER open() (see rewamp_plugin.h's doc comment)
// — too late for libvgmstream_setup(), which must run inside open(). The
// real work already happened in vgm_open_fn() above by reading the
// g_force_loop_* globals directly; this only exists so the vtable field is
// non-NULL (rewamp_has_native_loop_support).
static void vgm_configure_loop_fn(RewampDecoder* dec, int mode, int count) {
    (void)dec; (void)mode; (void)count;
}

static const RewampPluginVTable kVgmstreamPlugin = {
    "vgmstream",
    vgm_probe_fn,
    vgm_open_fn,
    vgm_read_fn,
    vgm_seek_fn,
    vgm_length_fn,
    vgm_close_fn,
    vgm_configure_loop_fn,
    /* supportsNativeFadeout */ 1,
};

extern "C" const RewampPluginVTable* rewamp_vgmstream_plugin(void) {
    return &kVgmstreamPlugin;
}

#endif // REWAMP_WITH_VGMSTREAM
