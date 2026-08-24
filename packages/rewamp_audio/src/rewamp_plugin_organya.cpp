// Organya plugin — Cave Story's own .org tracker format via the vendored
// organya.c (third_party/libpixel/organya): Daisuke "Pixel" Amaya's engine,
// ported to a portable memory-based API by Juergen Wothke for his webPixel
// project (third_party's file IS that adapter, not the raw Windows Winamp
// plugin source Modizer's libs/libpixel also carries — the adapter is
// self-contained, no Win32 dependency, and already has Modizer's per-voice
// capture patches baked in, grep YOYOFR). Cleanest API of this whole batch:
// org_setPosition() is a REAL native seek (forward and backward, including
// loop unrolling), and org_getlength() gives an exact analytical duration —
// no CPU-emulation rewind-and-discard, no throwaway measurement pass.
//
// organya_mute_mask (an app-level uint64_t extern, same bit convention as
// generic_mute_mask) was renamed to generic_mute_mask directly in the
// vendored source during vendoring — no plugin-specific global introduced.
//
// Process-global singleton (single static `struct organya org`, like UADE/
// Musashi) — fine, rewamp never runs two decoders concurrently.
#ifdef REWAMP_WITH_ORGANYA

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ORG_RATE   44100
#define ORG_VOICES 16
#define ORG_LOOPS  2   // matches Modizer's mmp_pixelLoad default

extern "C" {
int  org_play(const char* fn, char* buf);
int  org_gensamples(char* buf, int samplesNb);
int  org_setPosition(int pos_ms);
void org_setLoopNb(int loopNb);
void org_init(void);
int  org_getlength(void);
void unload_org(void);
}

struct RewampDecoder {
    uint64_t totalFrames;  // from org_getlength(); 0 = unknown
    uint64_t framePos;
};

static const char* const kOrgExts[] = { "org", NULL };

static int org_probe(const char* ext, const uint8_t* h, size_t n) {
    int magic = n >= 6 && h[0] == 'O' && h[1] == 'r' && h[2] == 'g' && h[3] == '-' &&
                h[4] == '0' && h[5] >= '1' && h[5] <= '3';
    int extMatch = rewamp_ext_in_list(ext, kOrgExts);
    if (magic) return extMatch ? 110 : 90;
    if (extMatch) return 90;
    return 0;
}

static RewampDecoder* org_open_impl(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q) *q = '\0';

    FILE* f = fopen(cleanPath, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size <= 0) { fclose(f); return NULL; }

    char* buf = (char*)malloc((size_t)size);
    if (!buf) { fclose(f); return NULL; }
    size_t got = fread(buf, 1, (size_t)size, f);
    fclose(f);
    if (got != (size_t)size) { free(buf); return NULL; }

    org_init();
    org_setLoopNb(ORG_LOOPS);
    // org_play consumes (memcpy-copies internally, via load_org's memread)
    // the buffer while parsing — safe to free right after.
    int failed = org_play(cleanPath, buf);
    free(buf);
    if (failed) return NULL;

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { unload_org(); return NULL; }

    m_genNumVoicesChannels = ORG_VOICES;
    rewamp_channel_data_reset(ORG_VOICES);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);
    rewamp_channel_data_set_ring_circular(1);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("Organya", 0, ORG_VOICES);

    int lengthMs = org_getlength();
    if (lengthMs > 0) dec->totalFrames = (uint64_t)lengthMs * ORG_RATE / 1000;

    const char* base = strrchr(cleanPath, '/');
    rewamp_track_message_append("Title: %s\n", base ? base + 1 : cleanPath);
    rewamp_track_message_append("Format: Organya (Cave Story), %d Hz, stereo\n", ORG_RATE);
    if (dec->totalFrames > 0) {
        unsigned total = (unsigned)(dec->totalFrames / ORG_RATE);
        rewamp_track_message_append("Duration: %u:%02u\n", total / 60, total % 60);
    }

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = ORG_RATE;
    }
    return dec;
}

static uint64_t org_read_impl(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || frameCount == 0) return 0;
    if (dec->totalFrames > 0) {
        if (dec->framePos >= dec->totalFrames) return 0;
        uint64_t remain = dec->totalFrames - dec->framePos;
        if (frameCount > remain) frameCount = remain;
    }

    static int16_t s_buf[4096 * 2];
    const float scale = 1.0f / 32768.0f;
    uint64_t written = 0;
    while (written < frameCount) {
        uint32_t want = (uint32_t)(frameCount - written);
        if (want > 4096) want = 4096;
        if (!org_gensamples((char*)s_buf, (int)want)) break;
        float* dst = out + written * 2;
        for (uint32_t i = 0; i < want * 2; i++) dst[i] = s_buf[i] * scale;
        written += want;
        dec->framePos += want;
    }
    return written;
}

static void org_seek_impl(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec) return;
    org_setPosition((int)(frameIndex * 1000ull / ORG_RATE));
    dec->framePos = frameIndex;
}

static uint64_t org_length_impl(RewampDecoder* dec) {
    return dec ? dec->totalFrames : 0;
}

static void org_close_impl(RewampDecoder* dec) {
    if (!dec) return;
    unload_org();
    free(dec);
}

static const RewampPluginVTable kOrgVTable = {
    "organya",
    org_probe,
    org_open_impl,
    org_read_impl,
    org_seek_impl,
    org_length_impl,
    org_close_impl,
};

extern "C" const RewampPluginVTable* rewamp_organya_plugin(void) { return &kOrgVTable; }

#endif /* REWAMP_WITH_ORGANYA */
