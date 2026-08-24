/* Highly Experimental plugin — PlayStation PSF/PSF2 decoder (PSX SPU emulation)
 * with per-channel voice/oscilloscope data.  Compiled only when
 * REWAMP_WITH_HIGHLYEXP is defined.
 *
 * Uses libpsflib to parse the PSF container (tags + _lib chains + PSF2 vfs) and
 * Highly Experimental's PSX core (psx.c/iop.c/spu*.c/r3000.c) for emulation.
 * The HE core requires EMU_COMPILE / EMU_LITTLE_ENDIAN / HAVE_STDINT_H defines. */
#ifdef REWAMP_WITH_HIGHLYEXP

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"
#include "ModizerConstants.h"

#include "highlyexperimental/Core/psx.h"
#include "highlyexperimental/Core/iop.h"
#include "highlyexperimental/Core/r3000.h"
#include "highlyexperimental/Core/spu.h"
#include "highlyexperimental/Core/bios.h"
#include "highlyexperimental/hebios.h"

#include "libpsflib/psflib.h"
#include "libpsflib/psf2fs.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <limits.h>
#include <ctype.h>
#include <strings.h>  /* strcasecmp / strncasecmp */

#define HE_PSF1_RATE   44100
#define HE_PSF2_RATE   48000
#define HE_STEREO      2
/* psx_execute renders up to this many frames per call (Modizer convention). */
#define HE_BATCH_FRAMES SOUND_BUFFER_SIZE_SAMPLE
/* Oscilloscope ring size: spucore.c masks writes with &(SOUND_BUFFER_SIZE_SAMPLE
 * *2*4 - 1), so the effective ring spans this many samples. */
#define HE_OSCILLO_SIZE (SOUND_BUFFER_SIZE_SAMPLE * 2 * 4)

struct RewampDecoder {
    void    *core;          /* psx state */
    void    *psf2fs;        /* PSF2 virtual filesystem, NULL for PSF1 */
    int      version;       /* 1 = PSF1, 2 = PSF2 */
    int      sampleRate;
    int      voiceCount;
    uint64_t totalFrames;   /* from tags (length + fade), 0 if unknown */
    uint64_t framePos;      /* current emulator output position (frames) */
    int      finished;
    char     path[4096];    /* clean path, for reload-based backward seek */
};

static const char* const kHeExts[] = { "psf", "minipsf", "psf2", "minipsf2", NULL };

/* ── one-time global HE init (BIOS image + tables) ──────────────────────────── */

static int g_he_inited = 0;
static void he_global_init(void) {
    if (g_he_inited) return;
    bios_set_image(hebios, HEBIOS_SIZE);
    psx_init();
    g_he_inited = 1;
}

static uint32_t get_le32(const void *p) {
    const uint8_t *b = (const uint8_t*)p;
    return (uint32_t)b[0] | ((uint32_t)b[1] << 8) |
           ((uint32_t)b[2] << 16) | ((uint32_t)b[3] << 24);
}

/* ── psflib file callbacks (stdio) ──────────────────────────────────────────── */

static void* he_fopen(const char *uri)                      { return fopen(uri, "rb"); }
static size_t he_fread(void *buf, size_t sz, size_t n, void *h) { return fread(buf, sz, n, (FILE*)h); }
static int   he_fseek(void *h, int64_t off, int whence)     { return fseek((FILE*)h, (long)off, whence); }
static int   he_fclose(void *h)                             { return fclose((FILE*)h); }
static int64_t he_ftell(void *h)                            { return ftell((FILE*)h); }

static const psf_file_callbacks kHeFileCallbacks = {
    "\\/:",      /* path separators */
    he_fopen,
    he_fread,
    he_fseek,
    he_fclose,
    he_ftell,
};

/* ── tag parsing ─────────────────────────────────────────────────────────────── */

struct he_info_state {
    int tag_length_ms;
    int tag_fade_ms;
    unsigned refresh;
};

/* Parse "m:ss.xxx" / "ss.xxx" style time into milliseconds. */
static int parse_time_ms(const char *value) {
    /* tokenize on ':' from least-significant (seconds) upward */
    char buf[64];
    strncpy(buf, value, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';
    /* cut at newline */
    char *nl = strchr(buf, '\n'); if (nl) *nl = '\0';

    const char *parts[4] = {0};
    int nparts = 0;
    char *tok = strtok(buf, ":");
    while (tok && nparts < 4) { parts[nparts++] = tok; tok = strtok(NULL, ":"); }

    double total = 0.0, mult = 1000.0;
    for (int i = nparts - 1; i >= 0; i--) {
        total += atof(parts[i]) * mult;
        mult *= 60.0;
    }
    return (int)total;
}

static int he_info_meta(void *ctx, const char *name, const char *value) {
    struct he_info_state *st = (struct he_info_state*)ctx;
    if (!name || !value) return 0;
    if      (strcasecmp(name, "length") == 0)   st->tag_length_ms = parse_time_ms(value);
    else if (strcasecmp(name, "fade") == 0)     st->tag_fade_ms   = parse_time_ms(value);
    else if (strcasecmp(name, "_refresh") == 0) st->refresh       = (unsigned)atoi(value);
    return 0;
}

/* ── PSF1 EXE loader (uploads to IOP RAM) ───────────────────────────────────── */

struct he_psf1_state {
    void    *emu;
    int      first;
    unsigned refresh;
};

static int he_psf1_info(void *ctx, const char *name, const char *value) {
    struct he_psf1_state *st = (struct he_psf1_state*)ctx;
    if (name && value && !st->refresh && strcasecmp(name, "_refresh") == 0)
        st->refresh = (unsigned)atoi(value);
    return 0;
}

static int he_psf1_loader(void *ctx, const uint8_t *exe, size_t exe_size,
                          const uint8_t *reserved, size_t reserved_size) {
    (void)reserved; (void)reserved_size;
    struct he_psf1_state *st = (struct he_psf1_state*)ctx;
    if (exe_size < 0x800 || exe_size > UINT_MAX) return -1;

    uint32_t addr = get_le32(exe + 0x18); /* exec.t_addr */
    uint32_t size = (uint32_t)exe_size - 0x800;
    addr &= 0x1fffff;
    if (addr < 0x10000 || size > 0x1f0000 || addr + size > 0x200000) return -1;

    void *pIOP = psx_get_iop_state(st->emu);
    iop_upload_to_ram(pIOP, addr, exe + 0x800, size);

    if (!st->refresh) {
        if      (!strncasecmp((const char*)exe + 113, "Japan", 5))         st->refresh = 60;
        else if (!strncasecmp((const char*)exe + 113, "Europe", 6))        st->refresh = 50;
        else if (!strncasecmp((const char*)exe + 113, "North America", 13))st->refresh = 60;
    }

    if (st->first) {
        void *pR3000 = iop_get_r3000_state(pIOP);
        r3000_setreg(pR3000, R3000_REG_PC,      get_le32(exe + 0x10)); /* exec.pc0 */
        r3000_setreg(pR3000, R3000_REG_GEN + 29, get_le32(exe + 0x30)); /* exec.s_ptr */
        st->first = 0;
    }
    return 0;
}

/* PSF2 virtual readfile callback for the PSX core. */
static int EMU_CALL he_virtual_readfile(void *ctx, const char *path, int offset,
                                        char *buffer, int length) {
    return psf2fs_virtual_readfile(ctx, path, offset, buffer, length);
}

/* ── probe ──────────────────────────────────────────────────────────────────── */

static int he_probe(const char *ext, const uint8_t *hdr, size_t hdrSize) {
    int extMatch = rewamp_ext_in_list(ext, kHeExts);
    /* PSF header: 'P','S','F', version byte (0x01 = PSF1, 0x02 = PSF2). */
    if (hdr && hdrSize >= 4 && hdr[0]=='P' && hdr[1]=='S' && hdr[2]=='F' &&
        (hdr[3] == 0x01 || hdr[3] == 0x02))
        return extMatch ? 100 : 85;
    return extMatch ? 60 : 0;
}

/* ── core (re)build ─────────────────────────────────────────────────────────── */
// Builds (or rebuilds) the PSX emulator state from dec->path + dec->version,
// freeing any previous core/psf2fs first.  Returns 0 on success, -1 on failure.

static int he_build_core(RewampDecoder *dec) {
    if (dec->core)   { free(dec->core);          dec->core   = NULL; }
    if (dec->psf2fs) { psf2fs_delete(dec->psf2fs); dec->psf2fs = NULL; }

    if (dec->version == 1) {
        dec->core = calloc(1, psx_get_state_size(1));
        if (!dec->core) return -1;
        psx_clear_state(dec->core, 1);

        struct he_psf1_state st = { dec->core, 1, 0 };
        if (psf_load(dec->path, &kHeFileCallbacks, 1,
                     he_psf1_loader, &st, he_psf1_info, &st, 1) <= 0) {
            free(dec->core); dec->core = NULL; return -1;
        }
        if (st.refresh) psx_set_refresh(dec->core, st.refresh);

        void *pIOP = psx_get_iop_state(dec->core);
        iop_set_compat(pIOP, IOP_COMPAT_HARSH);
        void *spu = iop_get_spu_state(pIOP);
        /* Settings → Moteurs → PSF: SPU main/reverb (Modizer HC family). */
        spu_enable_main(spu,
            (int)rewamp_get_engine_param("highlyexp", "spu_main", 1));
        spu_enable_reverb(spu,
            (int)rewamp_get_engine_param("highlyexp", "spu_reverb", 1));
    } else { /* version == 2 */
        dec->psf2fs = psf2fs_create();
        if (!dec->psf2fs) return -1;

        struct he_psf1_state st = { 0, 1, 0 };
        if (psf_load(dec->path, &kHeFileCallbacks, 2,
                     psf2fs_load_callback, dec->psf2fs, he_psf1_info, &st, 1) <= 0) {
            psf2fs_delete(dec->psf2fs); dec->psf2fs = NULL; return -1;
        }
        dec->core = calloc(1, psx_get_state_size(2));
        if (!dec->core) { psf2fs_delete(dec->psf2fs); dec->psf2fs = NULL; return -1; }
        psx_clear_state(dec->core, 2);
        if (st.refresh) psx_set_refresh(dec->core, st.refresh);
        psx_set_readfile(dec->core, he_virtual_readfile, dec->psf2fs);
    }
    dec->framePos = 0;
    dec->finished = 0;
    return 0;
}

/* ── open ───────────────────────────────────────────────────────────────────── */

static RewampDecoder* he_open(const char *path, RewampAudioFormat *outFormat) {
    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char *q = strrchr(cleanPath, '?');
    if (q) *q = '\0'; /* PSF has no subsongs; strip any ?suffix */

    he_global_init();

    /* First pass: detect version + read length/fade tags. */
    struct he_info_state info = {0};
    int version = psf_load(cleanPath, &kHeFileCallbacks, 0, 0, 0,
                           he_info_meta, &info, 0);
    if (version != 1 && version != 2) return NULL;

    RewampDecoder *dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) return NULL;
    dec->version    = version;
    dec->sampleRate = (version == 1) ? HE_PSF1_RATE : HE_PSF2_RATE;
    dec->voiceCount = (version == 1) ? 24 : 48; /* PSF2 = two SPUs */
    strncpy(dec->path, cleanPath, sizeof(dec->path) - 1);

    if (he_build_core(dec) != 0) { free(dec); return NULL; }

    /* Total length from tags (length + fade); 0 → unknown (caller defaults). */
    int len_ms = info.tag_length_ms + info.tag_fade_ms;
    dec->totalFrames = (len_ms > 0)
        ? (uint64_t)((double)len_ms / 1000.0 * dec->sampleRate) : 0;

    /* Voice / oscilloscope setup. */
    rewamp_channel_data_reset(dec->voiceCount);
    rewamp_channel_data_set_ring_write_size(HE_OSCILLO_SIZE);
    rewamp_channel_data_set_ring_circular(1);
    m_voice_current_samplerate = dec->sampleRate;   /* spucore smplIncr basis */
    generic_mute_mask  = 0;

    /* Voice metadata for the mute/grouping UI (after reset — it wipes the
     * tables): PSF1 = one SPU (24 voices), PSF2 = two SPUs. */
    rewamp_voices_meta_reset();
    if (dec->voiceCount > 24) {
        rewamp_voices_add_chip("SPU 1", 0, 24);
        rewamp_voices_add_chip("SPU 2", 24, dec->voiceCount - 24);
    } else {
        rewamp_voices_add_chip("SPU", 0, dec->voiceCount);
    }

    if (outFormat) {
        outFormat->channels   = HE_STEREO;
        outFormat->sampleRate = (uint32_t)dec->sampleRate;
    }
    return dec;
}

/* ── read ───────────────────────────────────────────────────────────────────── */

static uint64_t he_read(RewampDecoder *dec, float *out, uint64_t frameCount) {
    if (!dec || !dec->core || dec->finished || frameCount == 0) return 0;

    /* Enforce the tagged length (length + fade): PSF drivers loop forever, so
     * psx_execute never signals end on its own. Without this the track plays
     * indefinitely and the queue never auto-advances. totalFrames == 0 means no
     * length tag — then we fall back to the driver's own end (rarely fires). */
    if (dec->totalFrames > 0) {
        if (dec->framePos >= dec->totalFrames) { dec->finished = 1; return 0; }
        uint64_t remain = dec->totalFrames - dec->framePos;
        if (frameCount > remain) frameCount = remain;
    }

    static int16_t tmp[HE_BATCH_FRAMES * HE_STEREO];
    uint64_t written = 0;
    while (written < frameCount) {
        uint32_t want = HE_BATCH_FRAMES;
        uint64_t room = frameCount - written;
        if (want > room) want = (uint32_t)room;

        uint32_t howmany = want;
        if (psx_execute(dec->core, 0x7fffffff, tmp, &howmany, 0) < 0) {
            dec->finished = 1;
            break;
        }
        if (howmany == 0) { dec->finished = 1; break; }

        float *dst = out + written * HE_STEREO;
        for (uint32_t i = 0; i < howmany * HE_STEREO; i++)
            dst[i] = tmp[i] / 32768.0f;
        written += howmany;
    }
    dec->framePos += written;
    return written;
}

/* ── seek ───────────────────────────────────────────────────────────────────── */
// PSF has no random access.  Absolute seek = (reload core if seeking backward)
// then render-and-discard forward to the target frame.  Voice-buffer writes are
// suppressed during the skip so the oscilloscope doesn't flash garbage.

extern volatile int    g_seek_cancel;
extern volatile int    g_is_seeking;
extern volatile double g_seek_progress_s;

static void he_seek(RewampDecoder *dec, uint64_t frameIndex) {
    if (!dec) return;

    /* Backward (or to start): rebuild the emulator from frame 0. */
    if (frameIndex < dec->framePos) {
        if (he_build_core(dec) != 0) { dec->finished = 1; return; }
    }
    if (frameIndex <= dec->framePos) return;

    g_is_seeking = 1;
    static int16_t tmp[HE_BATCH_FRAMES * HE_STEREO];
    while (dec->framePos < frameIndex && !g_seek_cancel) {
        uint32_t want = HE_BATCH_FRAMES;
        uint64_t room = frameIndex - dec->framePos;
        if (want > room) want = (uint32_t)room;
        uint32_t howmany = want;
        if (psx_execute(dec->core, 0x7fffffff, tmp, &howmany, 0) < 0) { dec->finished = 1; break; }
        if (howmany == 0) { dec->finished = 1; break; }
        dec->framePos += howmany;
        g_seek_progress_s = (double)dec->framePos / (double)(dec->sampleRate > 0 ? dec->sampleRate : 1);
    }
    g_is_seeking = 0;
}

/* ── length ─────────────────────────────────────────────────────────────────── */

static uint64_t he_length(RewampDecoder *dec) {
    return dec ? dec->totalFrames : 0;
}

/* ── close ──────────────────────────────────────────────────────────────────── */

static void he_close(RewampDecoder *dec) {
    if (!dec) return;
    if (dec->psf2fs) psf2fs_delete(dec->psf2fs);
    if (dec->core)   free(dec->core);
    free(dec);
}

/* ── vtable ─────────────────────────────────────────────────────────────────── */

/* Live settings change (called under the decode lock) — PSF1 only (the PSF2
 * path drives the SPU through psf2fs, same iop state access still applies). */
static void he_param_changed(RewampDecoder* dec, const char* key) {
    (void)key;
    if (!dec || !dec->core) return;
    void *pIOP = psx_get_iop_state(dec->core);
    if (!pIOP) return;
    void *spu = iop_get_spu_state(pIOP);
    if (!spu) return;
    spu_enable_main(spu,
        (int)rewamp_get_engine_param("highlyexp", "spu_main", 1));
    spu_enable_reverb(spu,
        (int)rewamp_get_engine_param("highlyexp", "spu_reverb", 1));
}

static const RewampPluginVTable kHeVTable = {
    "highlyexp",
    he_probe,
    he_open,
    he_read,
    he_seek,
    he_length,
    he_close,
    NULL,              /* configure_loop */
    0,                 /* supportsNativeFadeout */
    "highlyexp",       /* engine_id */
    he_param_changed,  /* live settings */
};

const RewampPluginVTable* rewamp_highlyexp_plugin(void) {
    return &kHeVTable;
}

#endif /* REWAMP_WITH_HIGHLYEXP */
