/* SNSF plugin — Super Nintendo .snsf/.minisnsf decoder via snsf9x.
 *
 * SNSF is PSF-family (magic 0x23). Unlike NCSF (a pure software synth), an SNSF
 * embeds a real SNES ROM image plus an optional SRAM patch, and playback is full
 * hardware emulation: snsf9x is a stripped snes9x (65c816 CPU + PPU + DMA + SA-1
 * + S-DD1) driving blargg's SPC700/S-DSP APU core. The 8 voices the oscilloscope
 * shows are the S-DSP's real hardware channels.
 *
 * The container glue is NOT in the library: snsf9x exposes only
 * snsf_start/snsf_gen/snsf_term, and the loader that turns a PSF exe section
 * into (ROM, SRAM) lives in Modizer's ModizMusicPlayer.mm (mmp_HCLoad, the
 * HC_type==0x23 path). It is ported here verbatim — same situation as
 * highlyquixotic (QSF) and highlytheoritical (SSF/DSF).
 *
 * ⚠ snes9x keeps its emulator state in PROCESS GLOBALS (Settings, Memory,
 * spc_core), so only one .snsf can be decoding at a time. That matches every
 * other CPU-emulation engine here (UADE, SNDH's Musashi, Organya) and rewamp
 * never runs two decoders concurrently.
 *
 * Compiled only when REWAMP_WITH_SNSF is defined. */
#ifdef REWAMP_WITH_SNSF

extern "C" {
#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"
#include "ModizerConstants.h"
}

#include "libpsflib/psflib.h"
#include "../third_party/snsf/snsf_drvimpl.h"

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cstdio>
#include <new>
#include <strings.h>   /* strcasecmp */

#define SNSF_SAMPLE_RATE  32000   /* snsf_drvimpl.cpp's SampleRate default */
#define SNSF_STEREO       2
#define SNSF_VOICES       8       /* S-DSP hardware channels */
#define SNSF_BATCH_FRAMES 1024

static uint32_t snsf_get_le32(const void *p) {
    const uint8_t *b = (const uint8_t*)p;
    return (uint32_t)b[0] | ((uint32_t)b[1] << 8) |
           ((uint32_t)b[2] << 16) | ((uint32_t)b[3] << 24);
}

/* ── psflib file callbacks (stdio) ──────────────────────────────────────────── */

static void*  snsf_fopen(const char *uri)                        { return fopen(uri, "rb"); }
static size_t snsf_fread(void *buf, size_t sz, size_t n, void *h){ return fread(buf, sz, n, (FILE*)h); }
static int    snsf_fseek(void *h, int64_t off, int whence)       { return fseek((FILE*)h, (long)off, whence); }
static int    snsf_fclose(void *h)                               { return fclose((FILE*)h); }
static int64_t snsf_ftell(void *h)                               { return ftell((FILE*)h); }

static const psf_file_callbacks kSnsfFileCallbacks = {
    "\\/:",             /* path separators */
    snsf_fopen,
    snsf_fread,
    snsf_fseek,
    snsf_fclose,
    snsf_ftell,
};

/* ── SNSF loader (ModizMusicPlayer.mm's snsf_loader) ───────────────────────────
 * The PSF exe section is [u32 load offset][u32 size][ROM bytes]; psflib walks the
 * _lib chain oldest-first, so a .minisnsf's small patch overlays the shared
 * .snsflib's full ROM. The FIRST section seen fixes the base offset; later ones
 * are relative to it. The reserved section, when present, carries SRAM patches
 * (type 0 blocks). Buffers grow to the next power of two, +10 slack — kept as
 * upstream wrote it. */
struct snsf_loader_state {
    int       base_set;
    uint32_t  base;
    uint8_t  *data;
    size_t    data_size;
    uint8_t  *sram;
    size_t    sram_size;
};

static void snsf_loader_state_free(snsf_loader_state *s) {
    if (!s) return;
    if (s->data) free(s->data);
    if (s->sram) free(s->sram);
    free(s);
}

static unsigned snsf_next_pow2(unsigned v) {
    v -= 1;
    v |= v >> 1;  v |= v >> 2;  v |= v >> 4;
    v |= v >> 8;  v |= v >> 16;
    return v + 1;
}

static int snsf_loader(void *context, const uint8_t *exe, size_t exe_size,
                       const uint8_t *reserved, size_t reserved_size) {
    if (exe_size < 8) return -1;

    snsf_loader_state *state = (snsf_loader_state*)context;

    unsigned xofs  = snsf_get_le32(exe + 0);
    unsigned xsize = snsf_get_le32(exe + 4);
    if (xsize > exe_size - 8) return -1;

    if (!state->base_set) { state->base = xofs; state->base_set = 1; }
    else                  { xofs += state->base; }

    uint8_t *iptr  = state->data;
    unsigned isize = (unsigned)state->data_size;
    state->data = 0;
    state->data_size = 0;

    if (!iptr) {
        unsigned rsize = snsf_next_pow2(xofs + xsize);
        iptr = (uint8_t*)malloc(rsize + 10);
        if (!iptr) return -1;
        memset(iptr, 0, rsize + 10);
        isize = rsize;
    } else if (isize < xofs + xsize) {
        unsigned rsize = snsf_next_pow2(xofs + xsize);
        uint8_t *xptr = (uint8_t*)realloc(iptr, xofs + rsize + 10);
        if (!xptr) { free(iptr); return -1; }
        iptr = xptr;
        isize = rsize;
    }
    memcpy(iptr + xofs, exe + 8, xsize);
    state->data = iptr;
    state->data_size = isize;

    /* Reserved section: SRAM patch blocks. */
    if (reserved_size >= 8) {
        unsigned rsvtype = snsf_get_le32(reserved + 0);
        unsigned rsvsize = snsf_get_le32(reserved + 4);
        if (rsvtype != 0) return -1;                       /* unsupported type */
        if (reserved_size < 12 || rsvsize < 4) return -1;  /* too short */

        unsigned sram_offset     = snsf_get_le32(reserved + 8);
        unsigned sram_patch_size = rsvsize - 4;
        if (sram_offset + sram_patch_size > 0x20000) return -1;
        if (reserved_size < 12 + (size_t)sram_patch_size) return -1;

        if (!state->sram) {
            state->sram = (uint8_t*)malloc(0x20000);
            if (!state->sram) return -1;
            memset(state->sram, 0, 0x20000);
        }
        memcpy(state->sram + sram_offset, reserved + 12, sram_patch_size);
        if (state->sram_size < sram_offset + sram_patch_size)
            state->sram_size = sram_offset + sram_patch_size;
    }
    return 0;
}

/* ── tag parsing (length / fade / free text) ────────────────────────────────── */

struct snsf_info_state {
    int  tag_length_ms;
    int  tag_fade_ms;
    char title[256];
    char game[256];
    char artist[256];
    char year[64];
    char copyright[256];
    char snsfby[256];
};

static void snsf_copy_tag(char *dst, size_t cap, const char *v) {
    strncpy(dst, v, cap - 1);
    dst[cap - 1] = '\0';
    char *nl = strchr(dst, '\n'); if (nl) *nl = '\0';
}

/* Parse "m:ss.xxx" / "ss.xxx" time into milliseconds. */
static int snsf_parse_time_ms(const char *value) {
    char buf[64];
    strncpy(buf, value, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';
    char *nl = strchr(buf, '\n'); if (nl) *nl = '\0';

    const char *parts[4] = {0};
    int nparts = 0;
    char *tok = strtok(buf, ":");
    while (tok && nparts < 4) { parts[nparts++] = tok; tok = strtok(NULL, ":"); }

    double total = 0.0, mult = 1000.0;
    for (int i = nparts - 1; i >= 0; i--) { total += atof(parts[i]) * mult; mult *= 60.0; }
    return (int)total;
}

static int snsf_info_meta(void *ctx, const char *name, const char *value) {
    snsf_info_state *st = (snsf_info_state*)ctx;
    if (!name || !value) return 0;
    if      (strcasecmp(name, "length") == 0) st->tag_length_ms = snsf_parse_time_ms(value);
    else if (strcasecmp(name, "fade")   == 0) st->tag_fade_ms   = snsf_parse_time_ms(value);
    else if (strcasecmp(name, "title")     == 0) snsf_copy_tag(st->title,     sizeof(st->title),     value);
    else if (strcasecmp(name, "game")      == 0) snsf_copy_tag(st->game,      sizeof(st->game),      value);
    else if (strcasecmp(name, "artist")    == 0) snsf_copy_tag(st->artist,    sizeof(st->artist),    value);
    else if (strcasecmp(name, "year")      == 0) snsf_copy_tag(st->year,      sizeof(st->year),      value);
    else if (strcasecmp(name, "copyright") == 0) snsf_copy_tag(st->copyright, sizeof(st->copyright), value);
    else if (strcasecmp(name, "snsfby")    == 0) snsf_copy_tag(st->snsfby,    sizeof(st->snsfby),    value);
    return 0;
}

/* ── decoder ────────────────────────────────────────────────────────────────── */

struct RewampDecoder {
    snsf_loader_state *state;        /* owns the ROM + SRAM images */
    uint64_t           totalFrames;
    uint64_t           framePos;
    int                finished;
    int                started;      /* snsf_start() succeeded → snsf_term() owed */
    int64_t            muteCached;
    int16_t            batch[SNSF_BATCH_FRAMES * SNSF_STEREO];
};

/* (Re)start the emulator from the already-loaded ROM/SRAM images. Used by open()
 * and by a backward seek — there is no other rewind for a running CPU. */
static int snsf_restart(RewampDecoder *dec) {
    if (dec->started) { snsf_term(); dec->started = 0; }
    if (!snsf_start(dec->state->data, (INT32)dec->state->data_size,
                    dec->state->sram, (INT32)dec->state->sram_size))
        return -1;
    dec->started  = 1;
    dec->framePos = 0;
    dec->finished = 0;
    /* snsf_start() re-inits the DSP with stereo_switch = all voices audible, and
     * resets drvimpl's dwChannelMute/dwChannelMuteOld pair to match, so force our
     * own cache to re-push the mask on the next read(). */
    dec->muteCached = -1;
    return 0;
}

/* snsf9x's mute is the S-DSP's stereo_switch, which gates the REAL mix
 * (SPC_DSP.cpp's amp *= …) as well as the scope capture — and its polarity is
 * INVERTED versus ours: there, a set bit means the voice is AUDIBLE. */
static void snsf_apply_mute(RewampDecoder *dec) {
    if (dec->muteCached == generic_mute_mask) return;
    dec->muteCached = generic_mute_mask;
    dwChannelMute = (unsigned long)((~(uint64_t)generic_mute_mask) & 0xFFu);
}

/* ── probe ──────────────────────────────────────────────────────────────────── */

static const char* const kSnsfExts[] = { "snsf", "minisnsf", "snsflib", NULL };

static int snsf_probe(const char *ext, const uint8_t *hdr, size_t hdrSize) {
    int extMatch = rewamp_ext_in_list(ext, kSnsfExts);
    /* PSF header: 'P','S','F', version byte 0x23 = SNSF. */
    if (hdr && hdrSize >= 4 && hdr[0]=='P' && hdr[1]=='S' && hdr[2]=='F' && hdr[3]==0x23)
        return extMatch ? 100 : 85;
    return extMatch ? 60 : 0;
}

/* ── open ───────────────────────────────────────────────────────────────────── */

static RewampDecoder* snsf_open(const char *path, RewampAudioFormat *outFormat) {
    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char *q = strrchr(cleanPath, '?');
    if (q) *q = '\0';   /* SNSF has no subsongs; strip any ?suffix */

    /* Pass 1: length/fade + free-text tags. */
    snsf_info_state info;
    memset(&info, 0, sizeof(info));
    if (psf_load(cleanPath, &kSnsfFileCallbacks, 0x23, 0, 0,
                 snsf_info_meta, &info, 0) < 0)
        return nullptr;

    RewampDecoder *dec = new (std::nothrow) RewampDecoder();
    if (!dec) return nullptr;
    memset(dec, 0, sizeof(*dec));
    dec->state = (snsf_loader_state*)calloc(1, sizeof(snsf_loader_state));
    if (!dec->state) { delete dec; return nullptr; }

    /* Pass 2: merge the _lib chain into one ROM image (+ SRAM patches). */
    if (psf_load(cleanPath, &kSnsfFileCallbacks, 0x23, snsf_loader, dec->state,
                 0, 0, 0) < 0 || !dec->state->data) {
        snsf_loader_state_free(dec->state);
        delete dec;
        return nullptr;
    }

    /* Voice / oscilloscope setup — BEFORE the first decode: SPC_DSP writes into
     * m_voice_buff[] from inside snsf_start()'s DSP init. */
    rewamp_channel_data_reset(SNSF_VOICES);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);
    rewamp_channel_data_set_ring_circular(1);
    /* SPC_DSP.cpp's capture advances the ring at 44100-equivalent units
     * (44100/32000 per DSP sample), not at the 32 kHz output rate. */
    m_voice_current_samplerate = 44100;
    generic_mute_mask = 0;
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("S-DSP", 0, SNSF_VOICES);

    if (snsf_restart(dec) != 0) {
        snsf_loader_state_free(dec->state);
        delete dec;
        return nullptr;
    }

    int len_ms = info.tag_length_ms + info.tag_fade_ms;
    dec->totalFrames = (len_ms > 0)
        ? (uint64_t)((double)len_ms / 1000.0 * SNSF_SAMPLE_RATE) : 0;

    /* ⓘ panel: the generic tag reader (rewamp_tags.c) only knows ID3/Vorbis/RIFF
     * containers, so a PSF-family plugin must publish its own tags. */
    if (info.title[0])     rewamp_track_message_append("Title: %s\n", info.title);
    if (info.game[0])      rewamp_track_message_append("Game: %s\n", info.game);
    if (info.artist[0])    rewamp_track_message_append("Artist: %s\n", info.artist);
    if (info.year[0])      rewamp_track_message_append("Year: %s\n", info.year);
    if (info.copyright[0]) rewamp_track_message_append("Copyright: %s\n", info.copyright);
    if (info.snsfby[0])    rewamp_track_message_append("SNSF by: %s\n", info.snsfby);
    rewamp_track_message_append("Format: SNSF (SNES/SPC700), %d Hz, stereo\n",
                                SNSF_SAMPLE_RATE);
    rewamp_track_message_append("ROM: %u KB\n", (unsigned)(dec->state->data_size / 1024));
    if (dec->state->sram_size)
        rewamp_track_message_append("SRAM patch: %u bytes\n", (unsigned)dec->state->sram_size);
    if (dec->totalFrames > 0) {
        unsigned total = (unsigned)(dec->totalFrames / SNSF_SAMPLE_RATE);
        rewamp_track_message_append("Duration: %u:%02u\n", total / 60, total % 60);
    }

    if (outFormat) {
        outFormat->channels   = SNSF_STEREO;
        outFormat->sampleRate = SNSF_SAMPLE_RATE;
    }
    return dec;
}

/* ── read ───────────────────────────────────────────────────────────────────── */

static uint64_t snsf_read(RewampDecoder *dec, float *out, uint64_t frameCount) {
    if (!dec || !dec->started || dec->finished || frameCount == 0) return 0;

    if (dec->totalFrames > 0) {
        if (dec->framePos >= dec->totalFrames) { dec->finished = 1; return 0; }
        uint64_t remain = dec->totalFrames - dec->framePos;
        if (frameCount > remain) frameCount = remain;
    }

    snsf_apply_mute(dec);

    uint64_t written = 0;
    while (written < frameCount) {
        unsigned n = SNSF_BATCH_FRAMES;
        if ((uint64_t)n > frameCount - written) n = (unsigned)(frameCount - written);
        if (snsf_gen(dec->batch, n) <= 0) { dec->finished = 1; break; }
        const int16_t *src = dec->batch;
        float *dst = out + written * SNSF_STEREO;
        for (unsigned i = 0; i < n * SNSF_STEREO; i++) dst[i] = src[i] / 32768.0f;
        written += n;
    }
    dec->framePos += written;
    return written;
}

/* ── seek ───────────────────────────────────────────────────────────────────── */
/* No random access — the "position" IS the running CPU/APU state. Backward:
 * restart the emulator from the ROM image (no file I/O) then render-and-discard;
 * forward: discard from where we are. Same idiom as UADE/vio2sf/SNDH/lazyusf. */

extern "C" volatile int    g_seek_cancel;
extern "C" volatile int    g_is_seeking;
extern "C" volatile double g_seek_progress_s;

static void snsf_seek(RewampDecoder *dec, uint64_t frameIndex) {
    if (!dec || !dec->started) return;
    if (frameIndex < dec->framePos) {
        if (snsf_restart(dec) != 0) { dec->finished = 1; return; }
    }
    if (frameIndex <= dec->framePos) return;

    g_is_seeking = 1;
    snsf_apply_mute(dec);
    while (dec->framePos < frameIndex && !g_seek_cancel) {
        unsigned n = SNSF_BATCH_FRAMES;
        if ((uint64_t)n > frameIndex - dec->framePos)
            n = (unsigned)(frameIndex - dec->framePos);
        if (snsf_gen(dec->batch, n) <= 0) { dec->finished = 1; break; }  /* discard */
        dec->framePos += n;
        g_seek_progress_s = (double)dec->framePos / SNSF_SAMPLE_RATE;
    }
    g_is_seeking = 0;
}

/* ── length / close ─────────────────────────────────────────────────────────── */

static uint64_t snsf_length(RewampDecoder *dec) { return dec ? dec->totalFrames : 0; }

static void snsf_close(RewampDecoder *dec) {
    if (!dec) return;
    if (dec->started) snsf_term();
    snsf_loader_state_free(dec->state);
    delete dec;
}

/* ── vtable ─────────────────────────────────────────────────────────────────── */

static const RewampPluginVTable kSnsfVTable = {
    "snsf",
    snsf_probe,
    snsf_open,
    snsf_read,
    snsf_seek,
    snsf_length,
    snsf_close,
};

extern "C" const RewampPluginVTable* rewamp_snsf_plugin(void) {
    return &kSnsfVTable;
}

#endif /* REWAMP_WITH_SNSF */
