/* libLazyusf plugin — Nintendo 64 .usf/.miniusf via a real 68k^H^H R4300
 * interpreter + RSP audio-ucode emulation (Mupen64plus-derived, "lazyusf"
 * fork by Near). Vendored from Modizer's libs/libLazyusf (third_party/lazyusf,
 * curated ~52-file interpreter-only set — no dynarec, see the Makefile note
 * reproduced in third_party/lazyusf/README.md). Per-voice scope + notes +
 * mute already live in the vendored cores (grep YOYOFR in rsp_hle/alist.c,
 * rsp_hle/musyx.c, usf/usf.c, ai/ai_controller.c): alist.c's resample path
 * tracks up to 32 dynamically-assigned voices by their RDRAM sample address
 * (N64 has no fixed voice slots — LRU-recycled like a software synth) and
 * fills m_voice_buff[]/vgm_last_note/vgm_last_vol, honoring generic_mute_mask
 * in the ACTUAL RSP audio-list resample output.
 *
 * USF is a PSF-family format (magic byte 0x21) — psf_load handles nested
 * "_libN" sibling files transparently via the file_callbacks, same as
 * GSF (0x22) / 2SF (0x24). HLE audio (fast ucode-specific audio synthesis)
 * is used by default; RSP LLE (full vector-unit interpreter) is the library's
 * own fallback when an unrecognized ucode is detected — no plugin-level
 * choice needed. */
#ifdef REWAMP_WITH_LAZYUSF

#include "rewamp_plugin.h"

/* Boucle forcée (rewamp_audio.c) — lus à l'open. */
extern "C" int g_force_loop_mode;
extern "C" int g_force_loop_native_veto;
#include "rewamp_channel_data.h"
#include "rewamp_psf_fade.h"   // fondu de fin décrit par le tag `fade`
#include "ModizerVoicesData.h"

#include "usf/usf.h"
#include "libpsflib/psflib.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#define LAZYUSF_VOICES 32   /* SOUND_MAXVOICES_BUFFER_FX_USF in rsp_hle/alist.c */
#define LAZYUSF_RING_SIZE (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)   /* already what the core writes with */

struct RewampDecoder {
    void*    state;         /* usf_state_t, opaque, malloc'd to usf_get_state_size() */
    int      sampleRate;    /* learned from the first usf_render(..., 0, ...) call */
    uint64_t totalFrames;   /* from length+fade tags; 0 = unknown */
    uint64_t fadeFrames;    /* rampe finale (tag `fade`), 0 = aucune */
    uint64_t framePos;
    char     path[4096];    /* kept for usf_restart-based seek (re-open on rewind) */
};

// ── psflib stdio callbacks ──────────────────────────────────────────────────
static void*   lu_fopen(const char* uri)                         { return fopen(uri, "rb"); }
static size_t  lu_fread(void* p, size_t sz, size_t n, void* f)    { return fread(p, sz, n, (FILE*)f); }
static int     lu_fseek(void* f, int64_t off, int whence)         { return fseek((FILE*)f, (long)off, whence); }
static int     lu_fclose(void* f)                                 { return fclose((FILE*)f); }
static int64_t lu_ftell(void* f)                                  { return ftell((FILE*)f); }

static const psf_file_callbacks kLazyusfCallbacks = {
    "\\/:", lu_fopen, lu_fread, lu_fseek, lu_fclose, lu_ftell,
};

// Uploads the ROM/save-state "reserved" section into the emulator state as
// psf_load walks the _libN chain (deepest/first-nested first, matching
// usf_upload_section's own ordering contract). USF has no "exe" section.
static int lu_loader(void* context, const uint8_t* exe, size_t exe_size,
                     const uint8_t* reserved, size_t reserved_size) {
    if (exe && exe_size > 0) return -1;
    RewampDecoder* dec = (RewampDecoder*)context;
    return usf_upload_section(dec->state, reserved, reserved_size);
}

// Parses "m:ss.xxx" / "ss.xxx" (least-significant field = seconds) to ms.
static int lu_parse_time_ms(const char* value) {
    char buf[64];
    strncpy(buf, value, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';
    char* nl = strchr(buf, '\n'); if (nl) *nl = '\0';
    const char* parts[4] = {0};
    int nparts = 0;
    char* tok = strtok(buf, ":");
    while (tok && nparts < 4) { parts[nparts++] = tok; tok = strtok(nullptr, ":"); }
    double total = 0.0, mult = 1000.0;
    for (int i = nparts - 1; i >= 0; i--) { total += atof(parts[i]) * mult; mult *= 60.0; }
    return (int)total;
}

struct LuTags {
    int  lengthMs      = 0;
    int  fadeMs        = 0;
    int  enableCompare = 0;
    int  enableFifoFull = 0;
    char title[256]    = {0};
    char artist[256]   = {0};
};

static int lu_info(void* context, const char* name, const char* value) {
    LuTags* t = (LuTags*)context;
    if (!name || !value) return 0;
    if      (strcasecmp(name, "length") == 0) t->lengthMs = lu_parse_time_ms(value);
    else if (strcasecmp(name, "fade")   == 0) t->fadeMs   = lu_parse_time_ms(value);
    else if (strcasecmp(name, "_enablecompare")  == 0 && *value) t->enableCompare  = 1;
    else if (strcasecmp(name, "_enablefifofull") == 0 && *value) t->enableFifoFull = 1;
    else if (strcasecmp(name, "title") == 0)
        { rewamp_psf_tag_copy(t->title, sizeof(t->title), value); }
    else if (strcasecmp(name, "artist") == 0)
        { rewamp_psf_tag_copy(t->artist, sizeof(t->artist), value); }
    return 0;
}

static int lazyusf_probe(const char* ext, const uint8_t* header, size_t headerSize) {
    const int extMatch = ext && (strcmp(ext, "usf") == 0 || strcmp(ext, "miniusf") == 0);
    // PSF header: "PSF" + version byte; USF's version byte is 0x21.
    if (header && headerSize >= 4 && header[0] == 'P' && header[1] == 'S' &&
        header[2] == 'F' && header[3] == 0x21) {
        return extMatch ? 110 : 90;
    }
    return extMatch ? 90 : 0;
}

static RewampDecoder* lazyusf_open(const char* path, RewampAudioFormat* outFormat) {
    /* Mode 1 (N boucles): pas de compte natif -> veto, le generique
     * Dart compte les passes (voir configure_loop). */
    if (g_force_loop_mode == 1) g_force_loop_native_veto = 1;
    if (!path) return nullptr;

    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) *q = '\0';   // USF has no subsongs; tolerate the suffix

    RewampDecoder* dec = new RewampDecoder();
    strncpy(dec->path, cleanPath, sizeof(dec->path) - 1);
    dec->path[sizeof(dec->path) - 1] = '\0';

    dec->state = malloc(usf_get_state_size());
    if (!dec->state) { delete dec; return nullptr; }
    usf_clear(dec->state);

    LuTags tags;
    if (psf_load(cleanPath, &kLazyusfCallbacks, 0x21, lu_loader, dec,
                 lu_info, &tags, /*info_want_nested_tags=*/1) <= 0) {
        usf_shutdown(dec->state);
        free(dec->state);
        delete dec;
        return nullptr;
    }

    usf_set_compare(dec->state, tags.enableCompare);
    usf_set_fifo_full(dec->state, tags.enableFifoFull);
    usf_set_hle_audio(dec->state, 1);   // fast ucode-specific audio path (default for realtime playback)

    // Ring buffers BEFORE the first render (alist.c writes m_voice_buff inline,
    // circular ring already masked SOUND_BUFFER_SIZE_SAMPLE*4*2-1 in the core).
    rewamp_channel_data_reset(LAZYUSF_VOICES);
    rewamp_channel_data_set_ring_write_size(LAZYUSF_RING_SIZE);
    rewamp_channel_data_set_ring_circular(1);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("RSP Audio", 0, LAZYUSF_VOICES);

    int32_t sampleRate = 0;
    usf_render(dec->state, nullptr, 0, &sampleRate);   // prime + learn the real AI DAC rate
    dec->sampleRate = sampleRate > 0 ? sampleRate : 44100;

    const int64_t totalMs = (int64_t)tags.lengthMs + tags.fadeMs;
    dec->totalFrames = totalMs > 0
        ? (uint64_t)totalMs * (uint64_t)dec->sampleRate / 1000ull : 0;
    dec->fadeFrames = rewamp_psf_fade_frames(tags.fadeMs,
                                             (uint32_t)dec->sampleRate,
                                             dec->totalFrames);
    dec->framePos = 0;

    if (tags.title[0])  rewamp_track_message_append("Title: %s\n", tags.title);
    if (tags.artist[0]) rewamp_track_message_append("Artist: %s\n", tags.artist);
    rewamp_track_message_append("Sample rate: %dHz\n", dec->sampleRate);

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = (uint32_t)dec->sampleRate;
    }
    return dec;
}

// N64 voice slots are dynamically assigned by RDRAM sample address (no fixed
// channels) — see the matching comment in alist.c. A "touched THIS read()
// call" flag doesn't work here: the RSP audio-list task that actually calls
// alist_resample per voice doesn't run once per read() call — usf_render()
// only re-runs it once per real N64 audio frame and just drains an internal
// buffer the rest of the time, so a per-call flag was cleared far more often
// than voices actually went idle (blanked the whole scope). Use an elapsed-
// tick decay instead: g_lazyusf_read_tick incrementing once per read() call
// is the shared clock, alist_resample stamps each voice's last-touched tick,
// and a slot is cleared once it's gone quiet for LAZYUSF_VOICE_SILENCE_TICKS
// real read() calls in a row.
extern "C" int64_t g_lazyusf_voice_last_touched_tick[LAZYUSF_VOICES];
extern "C" int64_t g_lazyusf_read_tick = 0;

// ~0.3s of real audio at typical N64 rates (32-48kHz, 512 frames/tick):
// long enough to survive a legitimate short gap between notes, short enough
// that a voice that truly stopped reads as silence promptly instead of
// staying frozen on its last waveform.
#define LAZYUSF_VOICE_SILENCE_TICKS 20

static void lazyusf_clear_stale_voices() {
    for (int i = 0; i < LAZYUSF_VOICES; i++) {
        if (m_voice_buff[i] == nullptr) continue;
        // Fire exactly once when a slot crosses the threshold (not every
        // subsequent tick) — a voice untouched since before init would
        // otherwise re-memset an already-zeroed buffer on every call.
        if (g_lazyusf_read_tick - g_lazyusf_voice_last_touched_tick[i] ==
            LAZYUSF_VOICE_SILENCE_TICKS) {
            memset(m_voice_buff[i], 0, LAZYUSF_RING_SIZE);
            vgm_last_vol[i]  = 0;
            vgm_last_note[i] = 0;
        }
    }
}

static uint64_t lazyusf_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || frameCount == 0) return 0;
    const uint64_t fadeBase = dec->framePos;

    static int16_t buf[8192];   /* 2ch interleaved */
    const float scale = 1.0f / 32768.0f;
    uint64_t written = 0;
    g_lazyusf_read_tick++;
    while (written < frameCount) {
        uint64_t remain = frameCount - written;
        int want = (int)(remain > 4096 ? 4096 : remain);
        int32_t rate = dec->sampleRate;
        const char* err = usf_render(dec->state, buf, (size_t)want, &rate);
        if (err) break;   // decode error → treat as end of stream
        for (int i = 0; i < want * 2; i++)
            out[written * 2 + (uint64_t)i] = buf[i] * scale;
        written += (uint64_t)want;
        dec->framePos += (uint64_t)want;
    }
    lazyusf_clear_stale_voices();
    rewamp_psf_fade_apply(out, written, 2, fadeBase,
                          dec->totalFrames, dec->fadeFrames);
    return written;
}

extern "C" volatile int    g_seek_cancel;
extern "C" volatile int    g_is_seeking;
extern "C" volatile double g_seek_progress_s;

static void lazyusf_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec) return;
    if (frameIndex < dec->framePos) {
        usf_restart(dec->state);   // reloads ROM/save state, discards buffered samples
        dec->framePos = 0;
    }
    if (dec->framePos == frameIndex) return;
    g_is_seeking = 1;
    int16_t tmp[2048];   /* 1024 frames * 2ch */
    while (dec->framePos < frameIndex && !g_seek_cancel) {
        uint64_t room = frameIndex - dec->framePos;
        int want = (int)(room > 1024 ? 1024 : room);
        int32_t rate = dec->sampleRate;
        if (usf_render(dec->state, tmp, (size_t)want, &rate)) break;
        dec->framePos += (uint64_t)want;
        g_seek_progress_s = (double)dec->framePos / (double)(dec->sampleRate > 0 ? dec->sampleRate : 1);
    }
    g_is_seeking = 0;
}

static uint64_t lazyusf_length(RewampDecoder* dec) {
    return dec ? dec->totalFrames : 0;
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
static void lazyusf_configure_loop_fn(RewampDecoder* dec, int mode, int count) {
    (void)count;
    if (dec == NULL) return;
    if (mode == 2) dec->totalFrames = 0;
    // Toute boucle forcée retire le fondu natif: voir rewamp_psf_fade.h.
    if (mode != 0) dec->fadeFrames = 0;
}

static void lazyusf_close(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->state) {
        usf_shutdown(dec->state);
        free(dec->state);
    }
    delete dec;
}

static const RewampPluginVTable kLazyusfVTable = {
    "lazyusf",
    lazyusf_probe,
    lazyusf_open,
    lazyusf_read,
    lazyusf_seek,
    lazyusf_length,
    lazyusf_close,
    lazyusf_configure_loop_fn,
};

extern "C" const RewampPluginVTable* rewamp_lazyusf_plugin(void) { return &kLazyusfVTable; }

#endif /* REWAMP_WITH_LAZYUSF */
