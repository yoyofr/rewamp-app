/* WonderSwan plugin — .wsr (WonderSwan Rip) on the beetle-wswan-libretro core
 * (Mednafen lineage), vendored headless at third_party/wonderswan.
 *
 * Replaced the OSwan core (removed 2026-07-26, once this one had been
 * validated by ear against Modizer): far better maintained V30MZ + PSG
 * emulation, and it implements the Sound DMA / Hyper Voice path (ports
 * 0x4A-0x52) OSwan rendered poorly on WonderSwan Color. OSwan also ignored the
 * subsong entirely and always played the footer's track.
 *
 * The core is a single process-global machine (one .wsr at a time), like SNDH.
 *
 * Per-voice scope/notes/mute live in the core: third_party/wonderswan/
 * rewamp_wswan_capture.h, hooked into wswan/sound.c. 6 voices:
 *   0-3 tone, 4 = direct-D/A voice + Hyper Voice, 5 = noise.
 */
#ifdef REWAMP_WITH_WONDERSWAN

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

#include "rewamp_wswan.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#define WS_RATE   44100
#define WS_VOICES 6

struct RewampDecoder {
    uint64_t framePos;
    int      song;      /* the track handed to the V30MZ AW register */
};

static const char* const kWonderswanExts[] = { "wsr", NULL };

static int wonderswan_probe(const char* ext, const uint8_t* h, size_t n) {
    (void)h; (void)n;
    /* The "WSRF" magic sits in a 0x20-byte FOOTER; probe() only ever sees the
     * file's leading bytes, so extension-only. */
    return (ext && rewamp_ext_in_list(ext, kWonderswanExts)) ? 90 : 0;
}

static RewampDecoder* wonderswan_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    /* ?subsong=N — the OSwan plugin could only ever play the footer's track.
     *
     * Tracks are addressed through AW and they are ONE-based: AW=0 is a dead
     * slot (dead silent on Arc the Lad, a stray fragment on Densha de Go).
     * rewamp's subsong index is zero-based (entry 1 carries no suffix at all),
     * so the mapping is AW = subsong + 1 — the same numbering Modizer uses.
     * Getting this wrong shifts the whole list: entry 2 played the dead AW=0,
     * entry 3 replayed entry 1, and every real track sat one row too low.
     *
     * The footer's own "first song" byte is NOT used to pick the track: it is
     * the game's default (17 on Densha de Go), not the head of the catalogue
     * listing. It stays in the info panel. The footer carries no track count
     * either, so enumeration remains a catalogue matter. */
    int subsong = 0;
    const char* q = strrchr(path, '?');
    if (q) {
        const char* s = strstr(q, "subsong=");
        if (s) subsong = atoi(s + 8);
    }

    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    { char* c = strrchr(cleanPath, '?'); if (c) *c = '\0'; }

    FILE* f = fopen(cleanPath, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size <= 0x20) { fclose(f); return NULL; }

    uint8_t* buf = (uint8_t*)malloc((size_t)size);
    if (!buf) { fclose(f); return NULL; }
    size_t got = fread(buf, 1, (size_t)size, f);
    fclose(f);
    if (got != (size_t)size) { free(buf); return NULL; }

    /* MUST run before anything advances the emulation: the capture hooks in
     * sound.c write m_voice_buff[] unconditionally and it is NULL until this
     * call — the ordering constraint every plugin's open() must respect. */
    m_genNumVoicesChannels = WS_VOICES;
    rewamp_channel_data_reset(WS_VOICES);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("WonderSwan", 0, WS_VOICES);
    rewamp_voice_set_name(0, "Tone 1");
    rewamp_voice_set_name(1, "Tone 2");
    rewamp_voice_set_name(2, "Tone 3 (sweep)");
    rewamp_voice_set_name(3, "Tone 4");
    rewamp_voice_set_name(4, "Voice / Hyper");
    rewamp_voice_set_name(5, "Noise");

    if (!rewamp_wswan_load(buf, (size_t)size, WS_RATE)) { free(buf); return NULL; }
    free(buf);   /* the core copies into its own padded ROM buffer */

    const int firstSong = rewamp_wswan_first_song();
    const int song      = (subsong > 0 ? subsong : 0) + 1;
    if (song != firstSong) rewamp_wswan_reset(song);

    /* .wsr has no text metadata whatsoever — the footer is 32 binary bytes
     * (magic + track index). Publish what there is, like the V2M plugin. */
    rewamp_track_message_append("Format: WonderSwan Rip (.wsr), %d Hz, stereo\n", WS_RATE);
    rewamp_track_message_append("Core: beetle-wswan (Mednafen), WonderSwan Color\n");
    rewamp_track_message_append("Track: %d%s\n", song,
                                song == firstSong ? " (file default)" : "");

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { rewamp_wswan_close(); return NULL; }
    dec->song = song;

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = WS_RATE;
    }
    return dec;
}

static uint64_t wonderswan_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || frameCount == 0) return 0;

    static int16_t s_buf[2048 * 2];
    uint64_t written = 0;
    const float scale = 1.0f / 32768.0f;

    while (written < frameCount) {
        uint64_t want = frameCount - written;
        if (want > 2048) want = 2048;
        /* The core always fills the block (padding with silence if the frame
         * loop stalls), so a short read is impossible and can't spin. */
        int frames = rewamp_wswan_render(s_buf, (int)want);
        if (frames <= 0) break;
        float* dst = out + written * 2;
        for (int i = 0; i < frames * 2; i++) dst[i] = s_buf[i] * scale;
        written       += (uint64_t)frames;
        dec->framePos += (uint64_t)frames;
    }
    return written;
}

extern "C" volatile int    g_seek_cancel;
extern "C" volatile int    g_is_seeking;
extern "C" volatile double g_seek_progress_s;

static void wonderswan_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec) return;
    /* No native seek in a CPU emulator — rewind + discard-render, the same
     * idiom as UADE/vio2sf/SNDH/lazyusf. */
    if (frameIndex < dec->framePos) {
        rewamp_wswan_reset(dec->song);
        dec->framePos = 0;
    }
    if (dec->framePos == frameIndex) return;
    g_is_seeking = 1;
    static float tmp[512 * 2];
    while (dec->framePos < frameIndex && !g_seek_cancel) {
        uint64_t want = frameIndex - dec->framePos;
        if (want > 512) want = 512;
        if (wonderswan_read(dec, tmp, want) == 0) break;
        g_seek_progress_s = (double)dec->framePos / (double)WS_RATE;
    }
    g_is_seeking = 0;
}

static uint64_t wonderswan_length(RewampDecoder* dec) {
    (void)dec;
    return 0; /* Unknown — the footer carries no duration. */
}

static void wonderswan_close(RewampDecoder* dec) {
    if (!dec) return;
    rewamp_wswan_close();
    free(dec);
}

static const RewampPluginVTable kWonderswanVTable = {
    "wonderswan",
    wonderswan_probe,
    wonderswan_open,
    wonderswan_read,
    wonderswan_seek,
    wonderswan_length,
    wonderswan_close,
};

extern "C" const RewampPluginVTable* rewamp_wonderswan_plugin(void) { return &kWonderswanVTable; }

#endif /* REWAMP_WITH_WONDERSWAN */
