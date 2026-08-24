// highlytheoritical plugin — Sega Saturn .ssf/.ssflib (32ch SCSP) and Sega
// Dreamcast .dsf/.dsflib (64ch AICA) via the vendored sega.c/satsound.c/
// dcsound.c/yam.c (third_party/highlytheoritical): a real Musashi-derived
// 68000 CPU (Saturn's sound-board MC68EC000) or ARM7 core (Dreamcast's AICA
// controller) driving the ripped sound-driver program against a shared
// Yamaha SCSP-derived DSP core (yam.c). SSF/DSF are PSF-family (magic 0x11/
// 0x12). Like HighlyQuixotic, Modizer's own libs/highlytheoritical shipped
// NO loader glue (the ObjC wrapper was a stub) — the loader (sdsf_loader,
// a growing-buffer section merge, same idiom as GSF's exe merging) and the
// psf_load call site are ported here from Modizer's real, working
// ModizMusicPlayer.mm (mmp_HCLoad, HC_type==0x11/0x12).
//
// Per-voice scope+notes+mute already lived in yam.c (grep YOYOFR) at TWO
// sites, both gated on the same now-removed HC_voicesMuteMask1/2 globals as
// HighlyQuixotic had — fixed to read generic_mute_mask directly (yam.c
// already includes ModizerVoicesData.h; only one chip is ever active per
// instance here, so the full 64-bit mask needs no per-instance offset,
// unlike highlyexp's dual-SPU PSF2 case).
//
// Build note: satsound.c's 68000 core is selectable (Starscream / Musashi
// "m68k" / c68k); only "m68k" (a second, separate Musashi copy — not the
// SNDH/AtariAudio one) is actually vendored here (c68k/Starscream sources
// aren't present in Modizer's checkout), selected via -DUSE_M68K. Its
// public m68k_*/m68ki_* symbols are -D-renamed to ht_* to avoid a duplicate-
// symbol clash with the SNDH engine's own Musashi vendor copy — see
// PLUGINS.md §6.4 and the highlytheoritical-integration memory.
#ifdef REWAMP_WITH_HIGHLYTHEORITICAL

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"
#include "sega.h"
#include "libpsflib/psflib.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#define HT_RATE 44100

struct RewampDecoder {
    uint8_t* core;
    int      version;      // 1 = Saturn SSF (32ch), 2 = Dreamcast DSF (64ch)
    uint8_t* progData;     // kept alive for seek-rewind (sega_upload_program's
    uint32_t progSize;     // own upload_to_ram COPIES it, but re-uploading
                            // after a fresh sega_clear_state needs the bytes)
    uint64_t totalFrames;  // from length+fade tags; 0 = unknown
    uint64_t framePos;
};

// ── psflib stdio callbacks ──────────────────────────────────────────────────
static void*   ht_psf_fopen(const char* uri)                      { return fopen(uri, "rb"); }
static size_t  ht_psf_fread(void* b, size_t s, size_t n, void* h) { return fread(b, s, n, (FILE*)h); }
static int     ht_psf_fseek(void* h, int64_t o, int w)             { return fseek((FILE*)h, (long)o, w); }
static int     ht_psf_fclose(void* h)                              { return fclose((FILE*)h); }
static int64_t ht_psf_ftell(void* h)                               { return ftell((FILE*)h); }
static const psf_file_callbacks kHtPsfCbs = {
    "\\/:", ht_psf_fopen, ht_psf_fread, ht_psf_fseek, ht_psf_fclose, ht_psf_ftell,
};

// ── SSF/DSF loader (ported from Modizer's ModizMusicPlayer.mm, sdsf_loader) ─
// Growing-buffer merge of the "exe" section across a _lib chain — same idiom
// as GSF's exe merging, just LE32 offset prefix instead of a header struct.
struct sdsf_loader_state {
    uint8_t* data;
    size_t   data_size;
};
static uint32_t ht_get_le32(const uint8_t* p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}
static int ht_sdsf_loader(void* context, const uint8_t* exe, size_t exe_size,
                           const uint8_t* reserved, size_t reserved_size) {
    (void)reserved; (void)reserved_size;
    if (exe_size < 4) return -1;
    struct sdsf_loader_state* state = (struct sdsf_loader_state*)context;
    uint8_t* dst = state->data;

    if (state->data_size < 4) {
        state->data = dst = (uint8_t*)malloc(exe_size);
        state->data_size = exe_size;
        memcpy(dst, exe, exe_size);
        return 0;
    }

    uint32_t dst_start = ht_get_le32(dst) & 0x7fffff;
    uint32_t src_start = ht_get_le32(exe) & 0x7fffff;
    size_t dst_len = state->data_size - 4; if (dst_len > 0x800000) dst_len = 0x800000;
    size_t src_len = exe_size - 4;         if (src_len > 0x800000) src_len = 0x800000;

    if (src_start < dst_start) {
        uint32_t diff = dst_start - src_start;
        state->data_size = dst_len + 4 + diff;
        state->data = dst = (uint8_t*)realloc(dst, state->data_size);
        memmove(dst + 4 + diff, dst + 4, dst_len);
        memset(dst + 4, 0, diff);
        dst_len += diff;
        dst_start = src_start;
        dst[0] = (uint8_t)(dst_start); dst[1] = (uint8_t)(dst_start >> 8);
        dst[2] = (uint8_t)(dst_start >> 16); dst[3] = (uint8_t)(dst_start >> 24);
    }
    if ((src_start + src_len) > (dst_start + dst_len)) {
        size_t diff = (src_start + src_len) - (dst_start + dst_len);
        state->data_size = dst_len + 4 + diff;
        state->data = dst = (uint8_t*)realloc(dst, state->data_size);
        memset(dst + 4 + dst_len, 0, diff);
    }
    memcpy(dst + 4 + (src_start - dst_start), exe + 4, src_len);
    return 0;
}

// ── Tag reading (length/fade — no title/artist/etc parsed, matches V2M's
// minimal fallback style since none of the mmp_HCLoad SSF/DSF path's tag
// fields beyond length/fade are surfaced to the info panel there either). ──
static int ht_time_ms(const char* v) {
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
struct ht_tag_state { int length_ms, fade_ms; char title[256], artist[256]; };
static void ht_copy_tag(char* dst, size_t n, const char* v) {
    strncpy(dst, v, n - 1); dst[n - 1] = '\0';
    char* nl = strchr(dst, '\n'); if (nl) *nl = '\0';
}
static int ht_tag_cb(void* ctx, const char* name, const char* value) {
    struct ht_tag_state* st = (struct ht_tag_state*)ctx;
    if (!name || !value) return 0;
    if      (strcasecmp(name, "length") == 0) st->length_ms = ht_time_ms(value);
    else if (strcasecmp(name, "fade")   == 0) st->fade_ms   = ht_time_ms(value);
    else if (strcasecmp(name, "title")  == 0) ht_copy_tag(st->title,  sizeof(st->title),  value);
    else if (strcasecmp(name, "artist") == 0) ht_copy_tag(st->artist, sizeof(st->artist), value);
    return 0;
}

static const char* const kSsfExts[] = { "ssf", "minissf", "ssflib", NULL };
static const char* const kDsfExts[] = { "dsf", "minidsf", "dsflib", NULL };

static int ht_probe(const char* ext, const uint8_t* h, size_t n) {
    int magicSsf = n >= 4 && h[0] == 'P' && h[1] == 'S' && h[2] == 'F' && h[3] == 0x11;
    int magicDsf = n >= 4 && h[0] == 'P' && h[1] == 'S' && h[2] == 'F' && h[3] == 0x12;
    int extSsf = rewamp_ext_in_list(ext, kSsfExts);
    int extDsf = rewamp_ext_in_list(ext, kDsfExts);
    if (magicSsf) return extSsf ? 110 : 90;
    if (magicDsf) return extDsf ? 110 : 90;
    if (extSsf || extDsf) return 90;
    return 0;
}

static void ht_upload(RewampDecoder* dec) {
    uint32_t start = ht_get_le32(dec->progData);
    size_t length = dec->progSize;
    const size_t max_length = (dec->version == 2) ? 0x800000 : 0x80000;
    if ((start + (length - 4)) > max_length) length = max_length - start + 4;
    sega_upload_program(dec->core, dec->progData, (uint32_t)length);
}

static RewampDecoder* ht_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q) *q = '\0';

    sega_init();  // idempotent (library_was_initialized guard)

    const char* extDot = strrchr(cleanPath, '.');
    int isDsf = extDot && rewamp_ext_in_list(extDot + 1, kDsfExts);
    uint8_t hcType = isDsf ? 0x12 : 0x11;

    struct sdsf_loader_state ld; memset(&ld, 0, sizeof(ld));
    struct ht_tag_state ts;      memset(&ts, 0, sizeof(ts));
    if (psf_load(cleanPath, &kHtPsfCbs, hcType, ht_sdsf_loader, &ld, ht_tag_cb, &ts, 0) <= 0) {
        free(ld.data);
        return NULL;
    }
    if (ld.data_size < 4) { free(ld.data); return NULL; }

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { free(ld.data); return NULL; }
    dec->version = isDsf ? 2 : 1;
    dec->progData = ld.data;
    dec->progSize = (uint32_t)ld.data_size;

    dec->core = (uint8_t*)malloc(sega_get_state_size((uint8_t)dec->version));
    if (!dec->core) { free(dec->progData); free(dec); return NULL; }
    sega_clear_state(dec->core, (uint8_t)dec->version);
    sega_enable_dry(dec->core, 1);
    sega_enable_dsp(dec->core, 1);
    sega_enable_dsp_dynarec(dec->core, 0);
    ht_upload(dec);

    const int voices = isDsf ? 64 : 32;
    m_genNumVoicesChannels = voices;
    rewamp_channel_data_reset(voices);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);
    rewamp_channel_data_set_ring_circular(1);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip(isDsf ? "AICA (Dreamcast)" : "SCSP (Saturn)", 0, voices);

    // yam.c routes its scope+note writes through the libvgm-style ChipID
    // lookup (m_voice_ofs = first index where m_voice_ChipID[ii] matches
    // m_voice_current_system/Sub) -- rewamp_channel_data_reset() sets
    // m_voice_ChipID to -1 (no match) and m_voice_current_system/Sub to 0,
    // so without this the lookup NEVER matches: m_voice_ofs stays -1 and
    // every scope/note write is silently skipped (audio + mute still work
    // fine, they don't go through this path -- exactly the "no oscilloscope
    // but mute/unmute works" symptom). System id 0 matches the already-reset
    // m_voice_current_system/Sub defaults, so just claim the voice range.
    for (int v = 0; v < voices; v++) m_voice_ChipID[v] = 0;

    if (ts.length_ms > 0)
        dec->totalFrames = (uint64_t)((double)(ts.length_ms + ts.fade_ms) / 1000.0 * HT_RATE);

    if (ts.title[0])  rewamp_track_message_append("Title: %s\n", ts.title);
    if (ts.artist[0]) rewamp_track_message_append("Artist: %s\n", ts.artist);
    rewamp_track_message_append("Format: %s, %d Hz, stereo\n",
                                 isDsf ? "DSF (Dreamcast AICA)" : "SSF (Saturn SCSP)", HT_RATE);

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = HT_RATE;
    }
    return dec;
}

static uint64_t ht_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
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
        uint32_t got = want;
        int32_t r = sega_execute(dec->core, 0x7fffffff, s_buf, &got);
        if (r < 0 || got == 0) break;
        float* dst = out + written * 2;
        for (uint32_t i = 0; i < got * 2; i++) dst[i] = s_buf[i] * scale;
        written += got;
        dec->framePos += got;
        if (got < want) break;
    }
    return written;
}

extern "C" volatile int    g_seek_cancel;
extern "C" volatile int    g_is_seeking;
extern "C" volatile double g_seek_progress_s;

static void ht_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec) return;
    // No native seek in sega.h — rewind (sega_clear_state + re-upload the
    // kept program bytes) + discard-render forward, same idiom as UADE/
    // vio2sf/SNDH/WonderSwan/HighlyQuixotic. Reports progress via
    // g_is_seeking/g_seek_progress_s (Dart seek progress bar, same
    // mechanism as libsidplayfp) and honors g_seek_cancel.
    if (frameIndex < dec->framePos) {
        sega_clear_state(dec->core, (uint8_t)dec->version);
        sega_enable_dry(dec->core, 1);
        sega_enable_dsp(dec->core, 1);
        sega_enable_dsp_dynarec(dec->core, 0);
        ht_upload(dec);
        dec->framePos = 0;
    }
    if (dec->framePos == frameIndex) return;
    g_is_seeking = 1;
    float tmp[256 * 2];
    while (dec->framePos < frameIndex && !g_seek_cancel) {
        uint64_t want = frameIndex - dec->framePos;
        if (want > 256) want = 256;
        uint64_t got = ht_read(dec, tmp, want);
        g_seek_progress_s = (double)dec->framePos / (double)HT_RATE;
        if (got == 0) break;
    }
    g_is_seeking = 0;
}

static uint64_t ht_length(RewampDecoder* dec) {
    return dec ? dec->totalFrames : 0;
}

static void ht_close(RewampDecoder* dec) {
    if (!dec) return;
    free(dec->core);
    free(dec->progData);
    free(dec);
}

static const RewampPluginVTable kHtVTable = {
    "highlytheoritical",
    ht_probe,
    ht_open,
    ht_read,
    ht_seek,
    ht_length,
    ht_close,
};

extern "C" const RewampPluginVTable* rewamp_highlytheoritical_plugin(void) { return &kHtVTable; }

#endif /* REWAMP_WITH_HIGHLYTHEORITICAL */
