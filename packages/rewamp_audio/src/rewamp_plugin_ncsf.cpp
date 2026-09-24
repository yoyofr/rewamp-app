/* NCSF plugin — Nintendo DS .ncsf/.minincsf decoder via SSEQPlayer.
 *
 * NCSF is PSF-family (magic 0x25) but, unlike 2SF, it is NOT an emulated ROM:
 * the file embeds an SDAT sound archive (the DS's own sound-bank format) and a
 * reserved-section SSEQ index. Playback is a pure software synth — SSEQPlayer
 * (Naram Qashat's, itself derived from fincs' FeOS Sound System), reproducing
 * the 16 NDS hardware channels. So this is a distinct engine from vio2sf's
 * melonDS, sharing only libpsflib.
 *
 * The container glue (ncsf_loader, the SDAT/Player setup, the render loop) is
 * ported from Cog's HighlyComplete HCDecoder.mm (type 0x25 path).
 *
 * Compiled only when REWAMP_WITH_NCSF is defined. */
#ifdef REWAMP_WITH_NCSF

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

#include <SSEQPlayer/Player.h>
#include <SSEQPlayer/SDAT.h>
#include <SSEQPlayer/common.h>

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cstdio>
#include <memory>
#include <vector>
#include <exception>
#include <strings.h>   /* strcasecmp */

#define NCSF_SAMPLE_RATE  44100
#define NCSF_STEREO       2
#define NCSF_VOICES       16     /* NDS hardware channels */
#define NCSF_BATCH_FRAMES 1024   /* SSEQPlayer renders in blocks */

static uint32_t ncsf_get_le32(const void *p) {
    const uint8_t *b = (const uint8_t*)p;
    return (uint32_t)b[0] | ((uint32_t)b[1] << 8) |
           ((uint32_t)b[2] << 16) | ((uint32_t)b[3] << 24);
}

/* ── psflib file callbacks (stdio) ──────────────────────────────────────────── */

static void*  ncsf_fopen(const char *uri)                        { return fopen(uri, "rb"); }
static size_t ncsf_fread(void *buf, size_t sz, size_t n, void *h){ return fread(buf, sz, n, (FILE*)h); }
static int    ncsf_fseek(void *h, int64_t off, int whence)       { return fseek((FILE*)h, (long)off, whence); }
static int    ncsf_fclose(void *h)                               { return fclose((FILE*)h); }
static int64_t ncsf_ftell(void *h)                               { return ftell((FILE*)h); }

static const psf_file_callbacks kNcsfFileCallbacks = {
    "\\/:",             /* path separators */
    ncsf_fopen,
    ncsf_fread,
    ncsf_fseek,
    ncsf_fclose,
    ncsf_ftell,
};

/* ── NCSF loader (HCDecoder.mm's ncsf_loader) ──────────────────────────────────
 * The PSF "exe" section IS the SDAT (its size lives at offset 8); psflib merges
 * a _lib chain into one buffer, so a .minincsf's tiny exe overlays the shared
 * .ncsflib's full SDAT. The reserved section carries the SSEQ id to play — the
 * ONE thing that distinguishes two minincsf siblings of the same lib. */
struct ncsf_loader_state {
    uint32_t             sseq = 0;
    std::vector<uint8_t> sdatData;
    std::unique_ptr<SDAT> sdat;
    std::vector<uint8_t> outputBuffer;
};

static int ncsf_loader(void *context, const uint8_t *exe, size_t exe_size,
                       const uint8_t *reserved, size_t reserved_size) {
    ncsf_loader_state *state = (ncsf_loader_state*)context;

    if (reserved_size >= 4) state->sseq = ncsf_get_le32(reserved);

    if (exe_size >= 12) {
        uint32_t sdat_size = ncsf_get_le32(exe + 8);
        if (sdat_size > exe_size) return -1;
        if (state->sdatData.size() < sdat_size) state->sdatData.resize(sdat_size, 0);
        memcpy(&state->sdatData[0], exe, sdat_size);
    }
    return 0;
}

/* ── tag parsing (length / fade) ────────────────────────────────────────────── */

struct ncsf_info_state {
    int  tag_length_ms = 0;
    int  tag_fade_ms   = 0;
    char title[256]     = {0};
    char game[256]      = {0};
    char artist[256]    = {0};
    char year[64]       = {0};
    char copyright[256] = {0};
    char ncsfby[256]    = {0};
};

static void ncsf_copy_tag(char *dst, size_t cap, const char *v) {
    rewamp_psf_tag_copy(dst, cap, v);   /* 1re ligne, Shift-JIS → UTF-8 au besoin */
}

/* Parse "m:ss.xxx" / "ss.xxx" time into milliseconds. */
static int ncsf_parse_time_ms(const char *value) {
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

static int ncsf_info_meta(void *ctx, const char *name, const char *value) {
    ncsf_info_state *st = (ncsf_info_state*)ctx;
    if (!name || !value) return 0;
    if      (strcasecmp(name, "length") == 0) st->tag_length_ms = ncsf_parse_time_ms(value);
    else if (strcasecmp(name, "fade")   == 0) st->tag_fade_ms   = ncsf_parse_time_ms(value);
    /* Free-text tags for the ⓘ panel (same set the PSF spec defines and the
     * other PSF-family plugins publish). */
    else if (strcasecmp(name, "title")     == 0) ncsf_copy_tag(st->title,     sizeof(st->title),     value);
    else if (strcasecmp(name, "game")      == 0) ncsf_copy_tag(st->game,      sizeof(st->game),      value);
    else if (strcasecmp(name, "artist")    == 0) ncsf_copy_tag(st->artist,    sizeof(st->artist),    value);
    else if (strcasecmp(name, "year")      == 0) ncsf_copy_tag(st->year,      sizeof(st->year),      value);
    else if (strcasecmp(name, "copyright") == 0) ncsf_copy_tag(st->copyright, sizeof(st->copyright), value);
    else if (strcasecmp(name, "ncsfby")    == 0) ncsf_copy_tag(st->ncsfby,    sizeof(st->ncsfby),    value);
    return 0;
}

/* ── decoder ────────────────────────────────────────────────────────────────── */

struct RewampDecoder {
    Player               *player = nullptr;
    ncsf_loader_state    *state  = nullptr;   /* owns sdatData + the SDAT */
    uint64_t              totalFrames = 0;
    uint64_t              framePos = 0;
    uint64_t              fadeFrames = 0;  /* rampe finale (tag `fade`) */
    int                   finished = 0;
    char                  path[4096] = {0};
};

/* Build (or rebuild, for a backward seek) the player from the already-loaded
 * SDAT. Cheap — no file I/O, the SDAT stays parsed. */
static int ncsf_build_player(RewampDecoder *dec) {
    if (dec->player) { delete dec->player; dec->player = nullptr; }
    if (!dec->state || !dec->state->sdat) return -1;
    try {
        Player *player = new Player;
        player->interpolation = INTERPOLATION_SINC;
        player->sampleRate    = NCSF_SAMPLE_RATE;
        const SSEQ *sseq = dec->state->sdat->sseq.get();
        if (!sseq) { delete player; return -1; }
        player->Setup(sseq);
        player->Timer();
        dec->player = player;
    } catch (std::exception &) {
        return -1;
    }
    dec->framePos = 0;
    dec->finished = 0;
    return 0;
}

/* ── probe ──────────────────────────────────────────────────────────────────── */

static const char* const kNcsfExts[] = { "ncsf", "minincsf", "ncsflib", NULL };

static int ncsf_probe(const char *ext, const uint8_t *hdr, size_t hdrSize) {
    int extMatch = rewamp_ext_in_list(ext, kNcsfExts);
    /* PSF header: 'P','S','F', version byte 0x25 = NCSF. */
    if (hdr && hdrSize >= 4 && hdr[0]=='P' && hdr[1]=='S' && hdr[2]=='F' && hdr[3]==0x25)
        return extMatch ? 100 : 85;
    return extMatch ? 60 : 0;
}

/* ── open ───────────────────────────────────────────────────────────────────── */

static RewampDecoder* ncsf_open(const char *path, RewampAudioFormat *outFormat) {
    /* Mode 1 (N boucles): pas de compte natif -> veto, le generique
     * Dart compte les passes (voir configure_loop). */
    if (g_force_loop_mode == 1) g_force_loop_native_veto = 1;
    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char *q = strrchr(cleanPath, '?');
    if (q) *q = '\0';   /* NCSF has no subsongs; strip any ?suffix */

    /* Pass 1: length/fade tags. */
    ncsf_info_state info;
    if (psf_load(cleanPath, &kNcsfFileCallbacks, 0x25, 0, 0,
                 ncsf_info_meta, &info, 0) < 0)
        return nullptr;

    RewampDecoder *dec = new (std::nothrow) RewampDecoder();
    if (!dec) return nullptr;
    dec->state = new (std::nothrow) ncsf_loader_state();
    if (!dec->state) { delete dec; return nullptr; }
    strncpy(dec->path, cleanPath, sizeof(dec->path) - 1);

    /* Pass 2: merge the _lib chain into one SDAT + pick up the SSEQ id. */
    if (psf_load(cleanPath, &kNcsfFileCallbacks, 0x25, ncsf_loader, dec->state,
                 0, 0, 0) <= 0) {
        delete dec->state; delete dec; return nullptr;
    }
    if (dec->state->sdatData.empty()) { delete dec->state; delete dec; return nullptr; }

    try {
        PseudoFile file;
        file.data = &dec->state->sdatData;
        file.pos  = 0;
        dec->state->sdat.reset(new SDAT(file, dec->state->sseq));
    } catch (std::exception &) {
        delete dec->state; delete dec; return nullptr;
    }
    dec->state->outputBuffer.resize(NCSF_BATCH_FRAMES * sizeof(int16_t) * NCSF_STEREO);

    /* Voice / oscilloscope setup — before the first render (Player::Setup runs
     * the sequencer's first tick, and GenerateSamples writes m_voice_buff[]). */
    rewamp_channel_data_reset(NCSF_VOICES);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);
    rewamp_channel_data_set_ring_circular(1);
    m_voice_current_samplerate = NCSF_SAMPLE_RATE;
    generic_mute_mask = 0;
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("NDS SPU", 0, NCSF_VOICES);

    if (ncsf_build_player(dec) != 0) {
        delete dec->state; delete dec; return nullptr;
    }

    int len_ms = info.tag_length_ms + info.tag_fade_ms;
    dec->totalFrames = (len_ms > 0)
        ? (uint64_t)((double)len_ms / 1000.0 * NCSF_SAMPLE_RATE) : 0;
    dec->fadeFrames = rewamp_psf_fade_frames(info.tag_fade_ms,
                                             NCSF_SAMPLE_RATE, dec->totalFrames);

    /* ⓘ panel: the generic tag reader (rewamp_tags.c) only knows ID3/Vorbis/
     * RIFF containers, so a PSF-family plugin must publish its own tags. */
    if (info.title[0])     rewamp_track_message_append("Title: %s\n", info.title);
    if (info.game[0])      rewamp_track_message_append("Game: %s\n", info.game);
    if (info.artist[0])    rewamp_track_message_append("Artist: %s\n", info.artist);
    if (info.year[0])      rewamp_track_message_append("Year: %s\n", info.year);
    if (info.copyright[0]) rewamp_track_message_append("Copyright: %s\n", info.copyright);
    if (info.ncsfby[0])    rewamp_track_message_append("NCSF by: %s\n", info.ncsfby);
    rewamp_track_message_append("Format: NCSF (SDAT/SSEQ), %d Hz, stereo\n",
                                NCSF_SAMPLE_RATE);
    rewamp_track_message_append("SSEQ: #%u\n", dec->state->sseq);
    if (dec->totalFrames > 0) {
        unsigned total = (unsigned)(dec->totalFrames / NCSF_SAMPLE_RATE);
        rewamp_track_message_append("Duration: %u:%02u\n", total / 60, total % 60);
    }

    if (outFormat) {
        outFormat->channels   = NCSF_STEREO;
        outFormat->sampleRate = NCSF_SAMPLE_RATE;
    }
    return dec;
}

/* ── read ───────────────────────────────────────────────────────────────────── */

static uint64_t ncsf_read(RewampDecoder *dec, float *out, uint64_t frameCount) {
    if (!dec || !dec->player || dec->finished || frameCount == 0) return 0;
    const uint64_t fadeBase = dec->framePos;

    if (dec->totalFrames > 0) {
        if (dec->framePos >= dec->totalFrames) { dec->finished = 1; return 0; }
        uint64_t remain = dec->totalFrames - dec->framePos;
        if (frameCount > remain) frameCount = remain;
    }

    std::vector<uint8_t> &buf = dec->state->outputBuffer;
    uint64_t written = 0;
    try {
        while (written < frameCount) {
            unsigned n = NCSF_BATCH_FRAMES;
            if ((uint64_t)n > frameCount - written) n = (unsigned)(frameCount - written);
            dec->player->GenerateSamples(buf, 0, n);
            const int16_t *src = (const int16_t*)buf.data();
            float *dst = out + written * NCSF_STEREO;
            for (unsigned i = 0; i < n * NCSF_STEREO; i++) dst[i] = src[i] / 32768.0f;
            written += n;
        }
    } catch (std::exception &) {
        dec->finished = 1;
    }
    rewamp_psf_fade_apply(out, written, 2, fadeBase,
                          dec->totalFrames, dec->fadeFrames);
    dec->framePos += written;
    return written;
}

/* ── seek ───────────────────────────────────────────────────────────────────── */
/* No random access: a backward seek rebuilds the player (cheap — the SDAT is
 * already parsed), then both directions render-and-discard forward. */

extern "C" volatile int    g_seek_cancel;
extern "C" volatile int    g_is_seeking;
extern "C" volatile double g_seek_progress_s;

static void ncsf_seek(RewampDecoder *dec, uint64_t frameIndex) {
    if (!dec || !dec->player) return;
    if (frameIndex < dec->framePos) {
        if (ncsf_build_player(dec) != 0) { dec->finished = 1; return; }
    }
    if (frameIndex <= dec->framePos) return;

    g_is_seeking = 1;
    std::vector<uint8_t> &buf = dec->state->outputBuffer;
    try {
        while (dec->framePos < frameIndex && !g_seek_cancel) {
            unsigned n = NCSF_BATCH_FRAMES;
            if ((uint64_t)n > frameIndex - dec->framePos)
                n = (unsigned)(frameIndex - dec->framePos);
            dec->player->GenerateSamples(buf, 0, n);   /* discard */
            dec->framePos += n;
            g_seek_progress_s = (double)dec->framePos / NCSF_SAMPLE_RATE;
        }
    } catch (std::exception &) {
        dec->finished = 1;
    }
    g_is_seeking = 0;
}

/* ── length / close ─────────────────────────────────────────────────────────── */

static uint64_t ncsf_length(RewampDecoder *dec) { return dec ? dec->totalFrames : 0; }


/* Boucle FORCÉE (repeat-morceau): le moteur ÉMULÉ boucle DE LUI-MÊME au point
 * de boucle de la musique — c'est notre troncature à totalFrames (longueur de
 * catalogue/tag) qui coupait, et la relance générique repartait du DÉBUT, ce
 * qui s'entend (même famille que le .ay zxtune, « Midnight Resistance »).
 * Mode 2 (infini): on lève la troncature, l'émulation joue et boucle au bon
 * endroit. Mode 1 (N passes): pas de compte natif ici → VETO posé à l'open,
 * le générique Dart compte — comportement inchangé. Filet: un moteur qui
 * s'arrêterait quand même rend un read() à 0 → rechargement replayCurrent,
 * exactement le comportement d'avant ce câblage. */
static void ncsf_configure_loop_fn(RewampDecoder* dec, int mode, int count) {
    (void)count;
    if (dec == NULL) return;
    if (mode == 2) dec->totalFrames = 0;
    // Toute boucle forcée retire le fondu natif: voir rewamp_psf_fade.h.
    if (mode != 0) dec->fadeFrames = 0;
}

static void ncsf_close(RewampDecoder *dec) {
    if (!dec) return;
    delete dec->player;
    delete dec->state;
    delete dec;
}

/* ── vtable ─────────────────────────────────────────────────────────────────── */

static const RewampPluginVTable kNcsfVTable = {
    "ncsf",
    ncsf_probe,
    ncsf_open,
    ncsf_read,
    ncsf_seek,
    ncsf_length,
    ncsf_close,
    ncsf_configure_loop_fn,
};

extern "C" const RewampPluginVTable* rewamp_ncsf_plugin(void) {
    return &kNcsfVTable;
}

#endif /* REWAMP_WITH_NCSF */
