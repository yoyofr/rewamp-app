/* vio2sf plugin — Nintendo DS .2sf/.mini2sf decoder via melonDS (Cog vio2sf).
 *
 * Uses libpsflib to parse the 2SF container (tags + _lib chains, save maps) and
 * the melonDS NDS core (interpreter only, JIT_ENABLED=0 — iOS-safe) driven
 * directly in C++: NDSCart::ParseROM -> NDS::Reset/Start -> RunFrame ->
 * SPU::ReadOutput.  Built-in FreeBIOS (no external BIOS files).
 *
 * The 2SF ROM/save assembly (load_twosf_map / _mapz / twosf_loader) is ported
 * from Cog's HighlyComplete HCDecoder.mm (type 0x24 path).
 *
 * Compiled only when REWAMP_WITH_VIO2SF is defined. */
#ifdef REWAMP_WITH_VIO2SF

extern "C" {
#include "rewamp_plugin.h"

/* Boucle forcée (rewamp_audio.c) — lus à l'open. */
extern "C" int g_force_loop_mode;
extern "C" int g_force_loop_native_veto;
#include "rewamp_channel_data.h"
#include "rewamp_psf_fade.h"   // fondu de fin décrit par le tag `fade`
#include "ModizerVoicesData.h"
#include "ModizerConstants.h"
}

#include "libpsflib/psflib.h"

#include <vio2sf/NDS.h>
#include <vio2sf/NDSCart.h>
#include <vio2sf/SPU.h>
#include <vio2sf/SPI.h>
#include <vio2sf/Args.h>
#include <vio2sf/FreeBIOS.h>

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cstdio>
#include <climits>
#include <memory>
#include <vector>
#include <optional>
#include <strings.h>   /* strcasecmp */
#include <zlib.h>      /* uncompress / crc32, for compressed save maps */

/* NDS ARM7 clock = 33513982 Hz; 2SF audio rate = ARM7_CLOCK / 1024. */
#define VIO2SF_SAMPLE_RATE  (33513982.0 / 1024.0)   /* ≈ 32728.5 Hz */
#define VIO2SF_STEREO       2
#define VIO2SF_VOICES       16    /* NDS SPU channels */
/* Batch render size (frames) per RunFrame drain loop. */
#define VIO2SF_BATCH_FRAMES 1024

static uint32_t get_le32(const void *p) {
    const uint8_t *b = (const uint8_t*)p;
    return (uint32_t)b[0] | ((uint32_t)b[1] << 8) |
           ((uint32_t)b[2] << 16) | ((uint32_t)b[3] << 24);
}

/* ── psflib file callbacks (stdio) ──────────────────────────────────────────── */

static void*  vio_fopen(const char *uri)                        { return fopen(uri, "rb"); }
static size_t vio_fread(void *buf, size_t sz, size_t n, void *h){ return fread(buf, sz, n, (FILE*)h); }
static int    vio_fseek(void *h, int64_t off, int whence)       { return fseek((FILE*)h, (long)off, whence); }
static int    vio_fclose(void *h)                               { return fclose((FILE*)h); }
static int64_t vio_ftell(void *h)                               { return ftell((FILE*)h); }

static const psf_file_callbacks kVioFileCallbacks = {
    "\\/:",
    vio_fopen,
    vio_fread,
    vio_fseek,
    vio_fclose,
    vio_ftell,
};

/* ── 2SF ROM/save assembly (ported from HCDecoder.mm) ───────────────────────── */

struct twosf_loader_state {
    std::unique_ptr<uint8_t[]> rom;
    std::unique_ptr<uint8_t[]> state;
    size_t rom_size = 0;
    size_t state_size = 0;
    int initial_frames = -1;
    int sync_type = 0;
};

static int load_twosf_map(twosf_loader_state *state, int issave,
                          const unsigned char *udata, unsigned usize) {
    if (usize < 8) return -1;

    std::unique_ptr<uint8_t[]> iptr;
    size_t isize;
    std::unique_ptr<uint8_t[]> xptr;
    unsigned xsize = get_le32(udata + 4);
    unsigned xofs  = get_le32(udata + 0);
    if (issave) { iptr = std::move(state->state); isize = state->state_size; state->state_size = 0; }
    else        { iptr = std::move(state->rom);   isize = state->rom_size;   state->rom_size   = 0; }

    if (!iptr) {
        size_t rsize = xofs + xsize;
        if (!issave) {
            rsize -= 1; rsize |= rsize >> 1; rsize |= rsize >> 2; rsize |= rsize >> 4;
            rsize |= rsize >> 8; rsize |= rsize >> 16; rsize += 1;
        }
        iptr = std::make_unique<uint8_t[]>(rsize + 10);
        if (!iptr) return -1;
        std::fill_n(&iptr[0], rsize + 10, 0);
        isize = rsize;
    } else if (isize < xofs + xsize) {
        size_t rsize = xofs + xsize;
        if (!issave) {
            rsize -= 1; rsize |= rsize >> 1; rsize |= rsize >> 2; rsize |= rsize >> 4;
            rsize |= rsize >> 8; rsize |= rsize >> 16; rsize += 1;
        }
        xptr = std::make_unique<uint8_t[]>(xofs + rsize + 10);
        if (!xptr) return -1;
        std::copy_n(&iptr[0], isize, &xptr[0]);
        std::fill_n(&xptr[isize], rsize + 10, 0);
        iptr = std::move(xptr);
        isize = rsize;
    }
    std::copy_n(udata + 8, xsize, &iptr[xofs]);
    if (issave) { state->state = std::move(iptr); state->state_size = isize; }
    else        { state->rom   = std::move(iptr); state->rom_size   = isize; }
    return 0;
}

static int load_twosf_mapz(twosf_loader_state *state, int issave,
                           const unsigned char *zdata, unsigned zsize, unsigned zcrc) {
    int ret, zerr;
    uLongf usize = 8;
    uLongf rsize = usize;
    unsigned char *udata = (unsigned char*)malloc(usize);
    if (!udata) return -1;

    while (Z_OK != (zerr = uncompress(udata, &usize, zdata, zsize))) {
        if (Z_MEM_ERROR != zerr && Z_BUF_ERROR != zerr) { free(udata); return -1; }
        if (usize >= 8) {
            usize = get_le32(udata + 4) + 8;
            if (usize < rsize) { rsize += rsize; usize = rsize; } else rsize = usize;
        } else { rsize += rsize; usize = rsize; }
        unsigned char *rdata = (unsigned char*)realloc(udata, usize);
        if (!rdata) { free(udata); return -1; }
        udata = rdata;
    }

    unsigned char *rdata = (unsigned char*)realloc(udata, usize);
    if (!rdata) { free(udata); return -1; }

    // NOTE: the save-block CRC is deliberately NOT checked — matching Modizer's
    // vio2sf (twosfplug.cpp guards it with `if (0)`). Real modland/joshw 2sf libs
    // carry a save_crc that matches neither the compressed nor the decompressed
    // data, so enforcing it rejected every .mini2sf (the .2sf .lib's own "SAVE"
    // chunk failed first). Successful zlib inflate is validation enough.
    (void)zcrc;

    ret = load_twosf_map(state, issave, rdata, (unsigned)usize);
    free(rdata);
    return ret;
}

static int twosf_loader(void *context, const uint8_t *exe, size_t exe_size,
                        const uint8_t *reserved, size_t reserved_size) {
    twosf_loader_state *state = (twosf_loader_state*)context;

    if (exe_size >= 8) {
        if (load_twosf_map(state, 0, exe, (unsigned)exe_size)) return -1;
    }
    if (reserved_size) {
        size_t resv_pos = 0;
        if (reserved_size < 16) return -1;
        while (resv_pos + 12 < reserved_size) {
            unsigned save_size = get_le32(reserved + resv_pos + 4);
            unsigned save_crc  = get_le32(reserved + resv_pos + 8);
            if (get_le32(reserved + resv_pos + 0) == 0x45564153) { /* "SAVE" */
                if (resv_pos + 12 + save_size > reserved_size) return -1;
                if (load_twosf_mapz(state, 1, reserved + resv_pos + 12, save_size, save_crc))
                    return -1;
            }
            resv_pos += 12 + save_size;
        }
    }
    return 0;
}

static int twosf_info(void *context, const char *name, const char *value) {
    twosf_loader_state *state = (twosf_loader_state*)context;
    if (!name || !value) return 0;
    if      (strcasecmp(name, "_frames") == 0)        state->initial_frames = atoi(value);
    else if (strcasecmp(name, "_2sf_sync_type") == 0) state->sync_type = atoi(value);
    return 0;
}

/* ── tag parsing (length / fade) ────────────────────────────────────────────── */

struct vio_info_state {
    int  tag_length_ms = 0;
    int  tag_fade_ms   = 0;
    char title[256]     = {0};
    char game[256]      = {0};
    char artist[256]    = {0};
    char year[64]       = {0};
    char copyright[256] = {0};
    char twosfby[256]   = {0};
};

static void vio_copy_tag(char *dst, size_t cap, const char *v) {
    rewamp_psf_tag_copy(dst, cap, v);   /* 1re ligne, Shift-JIS → UTF-8 au besoin */
}

/* Parse "m:ss.xxx" / "ss.xxx" time into milliseconds. */
static int parse_time_ms(const char *value) {
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

static int vio_info_meta(void *ctx, const char *name, const char *value) {
    vio_info_state *st = (vio_info_state*)ctx;
    if (!name || !value) return 0;
    if      (strcasecmp(name, "length") == 0) st->tag_length_ms = parse_time_ms(value);
    else if (strcasecmp(name, "fade")   == 0) st->tag_fade_ms   = parse_time_ms(value);
    /* Free-text tags for the ⓘ panel — the generic tag reader only knows
     * ID3/Vorbis/RIFF, so a PSF-family plugin publishes its own. */
    else if (strcasecmp(name, "title")     == 0) vio_copy_tag(st->title,     sizeof(st->title),     value);
    else if (strcasecmp(name, "game")      == 0) vio_copy_tag(st->game,      sizeof(st->game),      value);
    else if (strcasecmp(name, "artist")    == 0) vio_copy_tag(st->artist,    sizeof(st->artist),    value);
    else if (strcasecmp(name, "year")      == 0) vio_copy_tag(st->year,      sizeof(st->year),      value);
    else if (strcasecmp(name, "copyright") == 0) vio_copy_tag(st->copyright, sizeof(st->copyright), value);
    else if (strcasecmp(name, "2sfby")     == 0) vio_copy_tag(st->twosfby,   sizeof(st->twosfby),   value);
    return 0;
}

/* ── decoder ────────────────────────────────────────────────────────────────── */

struct RewampDecoder {
    melonDS::NDS *nds = nullptr;
    std::vector<uint8_t> rom;      /* kept for backward-seek rebuild */
    int initial_frames = 0;
    int sampleRate = (int)VIO2SF_SAMPLE_RATE;
    uint64_t totalFrames = 0;
    uint64_t fadeFrames = 0;   /* rampe finale (tag `fade`) */
    uint64_t framePos = 0;
    int finished = 0;
    int64_t lastMuteMask = 0;
    char path[4096];
};

/* Build (or rebuild) the NDS core from dec->rom.  Returns 0 on success. */
static int vio_build_core(RewampDecoder *dec) {
    if (dec->nds) { delete dec->nds; dec->nds = nullptr; }
    if (dec->rom.empty()) return -1;

    melonDS::NDSArgs args;                        /* defaults: FreeBIOS + firmware + SW renderer */
    args.JIT = std::nullopt;                      /* interpreter only (iOS-safe) */
    args.Interpolation = melonDS::AudioInterpolation::None;
    args.OutputSampleRate = VIO2SF_SAMPLE_RATE;

    melonDS::NDS *nds = new melonDS::NDS(std::move(args), nullptr);
    if (!nds) return -1;

    /* ParseROM consumes the buffer, so hand it a fresh copy each build. */
    auto rombuf = std::make_unique<uint8_t[]>(dec->rom.size());
    std::copy(dec->rom.begin(), dec->rom.end(), rombuf.get());
    auto cart = melonDS::NDSCart::ParseROM(std::move(rombuf), (uint32_t)dec->rom.size());
    nds->SetNDSCart(std::move(cart));
    nds->SetGBACart(nullptr);

    nds->Reset();
    nds->SPI.GetPowerMan()->SetBatteryLevelOkay(true);
    if (nds->NeedsDirectBoot()) nds->SetupDirectBoot("dummy.nds");
    nds->Start();

    /* Skip the tune's initial (silent) frames. */
    for (int f = dec->initial_frames; f > 0; f--) {
        nds->RunFrame();
        nds->SPU.DrainOutput();
    }

    dec->nds = nds;
    dec->framePos = 0;
    dec->finished = 0;
    return 0;
}

/* ── probe ──────────────────────────────────────────────────────────────────── */

static const char* const kVioExts[] = { "2sf", "mini2sf", NULL };

static int vio_probe(const char *ext, const uint8_t *hdr, size_t hdrSize) {
    int extMatch = rewamp_ext_in_list(ext, kVioExts);
    /* PSF header: 'P','S','F', version byte 0x24 = 2SF. */
    if (hdr && hdrSize >= 4 && hdr[0]=='P' && hdr[1]=='S' && hdr[2]=='F' && hdr[3]==0x24)
        return extMatch ? 100 : 85;
    return extMatch ? 60 : 0;
}

/* ── open ───────────────────────────────────────────────────────────────────── */

static RewampDecoder* vio_open(const char *path, RewampAudioFormat *outFormat) {
    /* Mode 1 (N boucles): pas de compte natif -> veto, le generique
     * Dart compte les passes (voir configure_loop). */
    if (g_force_loop_mode == 1) g_force_loop_native_veto = 1;
    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char *q = strrchr(cleanPath, '?');
    if (q) *q = '\0';   /* 2SF has no subsongs; strip any ?suffix */

    /* Pass 1: length/fade tags. */
    vio_info_state info;
    if (psf_load(cleanPath, &kVioFileCallbacks, 0x24, 0, 0, vio_info_meta, &info, 0) < 0)
        return nullptr;

    /* Pass 2: assemble the ROM (+ save maps) via the 2sf loader. */
    twosf_loader_state ls;
    if (psf_load(cleanPath, &kVioFileCallbacks, 0x24, twosf_loader, &ls,
                 twosf_info, &ls, 1) <= 0)
        return nullptr;
    if (!ls.rom || ls.rom_size == 0 || ls.rom_size > UINT_MAX) return nullptr;

    RewampDecoder *dec = new (std::nothrow) RewampDecoder();
    if (!dec) return nullptr;
    dec->rom.assign(ls.rom.get(), ls.rom.get() + ls.rom_size);
    dec->initial_frames = (ls.initial_frames > 0) ? ls.initial_frames : 0;
    strncpy(dec->path, cleanPath, sizeof(dec->path) - 1);

    /* Voice / oscilloscope setup — before the first RunFrame (build_core). */
    rewamp_channel_data_reset(VIO2SF_VOICES);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);
    rewamp_channel_data_set_ring_circular(1);
    m_voice_current_samplerate = dec->sampleRate;
    generic_mute_mask = 0;
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("NDS SPU", 0, VIO2SF_VOICES);

    if (vio_build_core(dec) != 0) { delete dec; return nullptr; }

    int len_ms = info.tag_length_ms + info.tag_fade_ms;
    dec->totalFrames = (len_ms > 0)
        ? (uint64_t)((double)len_ms / 1000.0 * dec->sampleRate) : 0;
    dec->fadeFrames = rewamp_psf_fade_frames(info.tag_fade_ms,
                                             (uint32_t)dec->sampleRate,
                                             dec->totalFrames);

    if (info.title[0])     rewamp_track_message_append("Title: %s\n", info.title);
    if (info.game[0])      rewamp_track_message_append("Game: %s\n", info.game);
    if (info.artist[0])    rewamp_track_message_append("Artist: %s\n", info.artist);
    if (info.year[0])      rewamp_track_message_append("Year: %s\n", info.year);
    if (info.copyright[0]) rewamp_track_message_append("Copyright: %s\n", info.copyright);
    if (info.twosfby[0])   rewamp_track_message_append("2SF by: %s\n", info.twosfby);
    rewamp_track_message_append("Format: 2SF (melonDS), %d Hz, stereo\n",
                                dec->sampleRate);
    if (dec->totalFrames > 0) {
        unsigned total = (unsigned)(dec->totalFrames / dec->sampleRate);
        rewamp_track_message_append("Duration: %u:%02u\n", total / 60, total % 60);
    }

    if (outFormat) {
        outFormat->channels   = VIO2SF_STEREO;
        outFormat->sampleRate = (uint32_t)dec->sampleRate;
    }
    return dec;
}

/* ── read ───────────────────────────────────────────────────────────────────── */

static uint64_t vio_read(RewampDecoder *dec, float *out, uint64_t frameCount) {
    if (!dec || !dec->nds || dec->finished || frameCount == 0) return 0;
    const uint64_t fadeBase = dec->framePos;

    if (dec->totalFrames > 0) {
        if (dec->framePos >= dec->totalFrames) { dec->finished = 1; return 0; }
        uint64_t remain = dec->totalFrames - dec->framePos;
        if (frameCount > remain) frameCount = remain;
    }

    melonDS::NDS *nds = dec->nds;
    static int16_t tmp[VIO2SF_BATCH_FRAMES * VIO2SF_STEREO];
    uint64_t written = 0;
    while (written < frameCount) {
        int num_avail = nds->SPU.GetOutputSize();
        if (!num_avail) { nds->RunFrame(); num_avail = nds->SPU.GetOutputSize(); }
        if (!num_avail) continue;

        uint64_t room = frameCount - written;
        if ((uint64_t)num_avail > room) num_avail = (int)room;
        if (num_avail > VIO2SF_BATCH_FRAMES) num_avail = VIO2SF_BATCH_FRAMES;

        int got = nds->SPU.ReadOutput(tmp, num_avail);
        if (got <= 0) { nds->RunFrame(); continue; }

        float *dst = out + written * VIO2SF_STEREO;
        for (int i = 0; i < got * VIO2SF_STEREO; i++) dst[i] = tmp[i] / 32768.0f;
        written += got;
    }
    rewamp_psf_fade_apply(out, written, 2, fadeBase,
                          dec->totalFrames, dec->fadeFrames);
    dec->framePos += written;
    return written;
}

/* ── seek ───────────────────────────────────────────────────────────────────── */
// 2SF has no random access.  Backward seek rebuilds the core; then render-and-
// discard forward to the target frame.

extern "C" volatile int    g_seek_cancel;
extern "C" volatile int    g_is_seeking;
extern "C" volatile double g_seek_progress_s;

static void vio_seek(RewampDecoder *dec, uint64_t frameIndex) {
    if (!dec) return;
    if (frameIndex < dec->framePos) {
        if (vio_build_core(dec) != 0) { dec->finished = 1; return; }
    }
    if (frameIndex <= dec->framePos) return;

    g_is_seeking = 1;
    melonDS::NDS *nds = dec->nds;
    static int16_t tmp[VIO2SF_BATCH_FRAMES * VIO2SF_STEREO];
    while (dec->framePos < frameIndex && !g_seek_cancel) {
        int num_avail = nds->SPU.GetOutputSize();
        if (!num_avail) { nds->RunFrame(); num_avail = nds->SPU.GetOutputSize(); }
        if (!num_avail) continue;
        uint64_t room = frameIndex - dec->framePos;
        if ((uint64_t)num_avail > room) num_avail = (int)room;
        if (num_avail > VIO2SF_BATCH_FRAMES) num_avail = VIO2SF_BATCH_FRAMES;
        int got = nds->SPU.ReadOutput(tmp, num_avail);   /* discard */
        if (got <= 0) { nds->RunFrame(); continue; }
        dec->framePos += got;
        g_seek_progress_s = (double)dec->framePos / VIO2SF_SAMPLE_RATE;
    }
    g_is_seeking = 0;
}

/* ── length / close ─────────────────────────────────────────────────────────── */

static uint64_t vio_length(RewampDecoder *dec) { return dec ? dec->totalFrames : 0; }


/* Boucle FORCÉE (repeat-morceau): le moteur ÉMULÉ boucle DE LUI-MÊME au point
 * de boucle de la musique — c'est notre troncature à totalFrames (longueur de
 * catalogue/tag) qui coupait, et la relance générique repartait du DÉBUT, ce
 * qui s'entend (même famille que le .ay zxtune, « Midnight Resistance »).
 * Mode 2 (infini): on lève la troncature, l'émulation joue et boucle au bon
 * endroit. Mode 1 (N passes): pas de compte natif ici → VETO posé à l'open,
 * le générique Dart compte — comportement inchangé. Filet: un moteur qui
 * s'arrêterait quand même rend un read() à 0 → rechargement replayCurrent,
 * exactement le comportement d'avant ce câblage. */
static void vio_configure_loop_fn(RewampDecoder* dec, int mode, int count) {
    (void)count;
    if (dec == NULL) return;
    if (mode == 2) dec->totalFrames = 0;
    // Toute boucle forcée retire le fondu natif: voir rewamp_psf_fade.h.
    if (mode != 0) dec->fadeFrames = 0;
}

static void vio_close(RewampDecoder *dec) {
    if (!dec) return;
    if (dec->nds) delete dec->nds;
    delete dec;
}

/* ── vtable ─────────────────────────────────────────────────────────────────── */

static const RewampPluginVTable kVioVTable = {
    "vio2sf",
    vio_probe,
    vio_open,
    vio_read,
    vio_seek,
    vio_length,
    vio_close,
    vio_configure_loop_fn,
};

extern "C" const RewampPluginVTable* rewamp_vio2sf_plugin(void) {
    return &kVioVTable;
}

#endif /* REWAMP_WITH_VIO2SF */
