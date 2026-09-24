// PMD plugin — PC-98 Professional Music Driver (.m/.m2/.mz) via the vendored
// libpmdmini (third_party/pmdmini: C60's PMDWin core + ymfm's OPNA/SSG/ADPCM
// emulation, wrapped by pmdmini.cpp's small C API).
//
// The engine is a PROCESS-GLOBAL singleton (pmdwininit deletes and re-news the
// two PMDWIN instances) — fine, rewamp never runs two decoders concurrently.
//
// Rhythm samples: OPNA::Init loads the YM2608 ADPCM rhythm ROM from the
// `bundlePath` global (a Modizer-era extern DEFINED IN rewamp_channel_data.c —
// libfmpmini's drum ROM loader wants the same global and the same ROM, so
// neither plugin can own it). It points at <datadir>/opna/, where main.dart
// copies the bundled ym2608_adpcm_rom.bin. Set it BEFORE pmd_init — pmd_init
// constructs the PMDWIN objects, which is where the ROM is read.
//
// Voice layout is decided by the core during getlength()'s offline simulation
// (which pmd_play runs): pmd_system_voice_idx/nb say which of FM (13 voices:
// 6 FM + 6 rhythm + 1 ADPCM-B), SSG (3) and PPZ8 (8) the tune actually uses,
// and pmd_real_tracks_used is the total. Those three are extern "C" globals
// the core writes and the app defines — they live here.
//
// Per-voice scope/notes/mute already live in the vendored cores (grep YOYOFR
// in ymfm/ymfm_opn.cpp, ymfm/ymfm_fm.ipp, ymfm/ymfm_adpcm.cpp, ymfm/opna.cpp,
// pmdwin/ppz8l.cpp, pmdwin/pmdwincore.cpp); they read generic_mute_mask
// directly and gate the real mix, so the plugin has no mute wiring to do.
// Their ring mask is SOUND_BUFFER_SIZE_SAMPLE*4*4 (8192) — the physical
// RING_BUF_SAMPLES ceiling — hence the ring_write_size below.
//
// Loop: PMD self-loops forever, but the library can't be told "replay this N
// times and stop", so this is a GENERIC-loop plugin (configure_loop = NULL):
// length() reports the SINGLE-pass duration (getlength with maxloop=1) and the
// Dart _tickForceLoop drives repeats/fade.
#ifdef REWAMP_WITH_PMD

#include "rewamp_plugin.h"

/* Boucle forcée (rewamp_audio.c) — lus à l'open. */
extern "C" int g_force_loop_mode;
extern "C" int g_force_loop_native_veto;
#include "rewamp_channel_data.h"
#include "rewamp_assets.h"   // rewamp_get_data_dir() → bundled ym2608_adpcm_rom.bin
#include "ModizerVoicesData.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern "C" {
#include "pmdmini.h"
}

// libpmdmini ships its own table-driven Shift-JIS → UTF-8 converter (ymfm/
// sjis2utf.cpp) — portable, no iconv, and the right one for PMD's own text.
// Declared here rather than including sjis2utf.h, whose portability_fmgen.h
// include would pull the ymfm dir onto this TU's path for no benefit. It is
// C++-linkage on purpose: that file is compiled as C++.
uint8_t* sjis2utf8n(uint8_t* dest, uint8_t* src, size_t count);

#define PMD_RATE 44100

// ── globals the vendored cores expect the app to define ──────────────────────
extern "C" {
extern char bundlePath[1024];        // dir holding ym2608_adpcm_rom.bin (rewamp_channel_data.c)
int         pmd_real_tracks_used;    // total voices the tune actually uses
signed char pmd_system_voice_idx[3]; // first voice index of FM / SSG / PPZ (-1 = unused)
signed char pmd_system_voice_nb[3];  // voice count of FM / SSG / PPZ
}

#define PMD_VOICE_FM  0
#define PMD_VOICE_SSG 1
#define PMD_VOICE_PPZ 2

// FM (6 + 6 rhythm + 1 ADPCM-B) + SSG (3) + PPZ8 (8). The cores index their
// rings with this layout from the very first chip write, which happens inside
// pmd_init — before pmd_play has told us how many voices the tune really uses.
#define PMD_MAX_VOICES 24

struct RewampDecoder {
    uint64_t totalFrames;  // single-pass length; 0 = unknown
    uint64_t framePos;
    int      voices;       // real count, re-applied after a seek's reload
    char     path[4096];   // kept for seek (backward = reload + discard-render)
};

static const char* const kPmdExts[] = { "m", "m2", "mz", NULL };

// PMD header: byte0 <= 0x0f, byte1 is 0x18 or 0x1a, byte2 is 0 or 0xe6 (the
// same check pmd_is_pmd does on the file — replicated here so probe() can work
// off the header the registry already read).
static int pmd_probe(const char* ext, const uint8_t* h, size_t n) {
    const int extMatch = rewamp_ext_in_list(ext, kPmdExts);
    if (!extMatch) return 0;   // no magic worth claiming a foreign file on
    const int magic = n >= 3 && h[0] <= 0x0f && (h[1] == 0x18 || h[1] == 0x1a) &&
                      (h[2] == 0 || h[2] == 0xe6);
    return magic ? 100 : 0;
}

static void pmd_set_bundle_path(void) {
    const char* dd = rewamp_get_data_dir();
    if (dd && *dd) snprintf(bundlePath, sizeof(bundlePath), "%s/opna/", dd);
    else           bundlePath[0] = '\0';
}

// Load (or reload, for a backward seek) the tune. Runs the offline length
// simulation as a side effect, which is also what fills the voice-layout
// globals — so the real voice count is only known once this returns.
//
// The rings must therefore be allocated for the FULL layout before the first
// chip write: pmd_init constructs the PMDWIN objects, and PMDWIN::init already
// pokes OPNA registers, whose YOYOFR capture writes m_voice_buff[0..12]
// unguarded (§2.6 — reset after that is a NULL-deref, which is exactly what it
// did). The caller narrows the count to what the tune actually uses afterwards.
static int pmd_load(const char* path) {
    char dir[4096];
    snprintf(dir, sizeof(dir), "%s", path);
    char* slash = strrchr(dir, '/');
    if (slash) *slash = '\0';
    else        dir[0] = '\0';

    rewamp_channel_data_reset(PMD_MAX_VOICES);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 4);
    rewamp_channel_data_set_ring_circular(1);

    pmd_set_bundle_path();
    pmd_init(dir);
    pmd_setrate(PMD_RATE);

    memset(pmd_system_voice_idx, -1, sizeof(pmd_system_voice_idx));
    memset(pmd_system_voice_nb, 0, sizeof(pmd_system_voice_nb));
    pmd_real_tracks_used = 0;

    if (!pmd_is_pmd(path)) return 0;

    // argv[1] = the file; argv[2]/[3] are pmdmini's optional PPC/PPS override
    // path, unused here (the core resolves companions from the file's own dir,
    // which setpcmdir gets from argv[1]'s dirname).
    char* argv[4] = { NULL, (char*)path, NULL, NULL };
    // maxloop=1: length becomes the duration of ONE pass (the point the tune
    // first reaches its loop), which is the base the generic Dart loop needs.
    if (pmd_play(argv, dir, 1) != 0) return 0;
    return 1;
}

// Total voices the tune uses, as counted by the core's own simulation.
static int pmd_voice_count(void) {
    int voices = pmd_real_tracks_used;
    if (voices <= 0) voices = pmd_get_tracks();
    if (voices <= 0) voices = 1;
    if (voices > PMD_MAX_VOICES) voices = PMD_MAX_VOICES;
    return voices;
}

// Narrow the rings from the PMD_MAX_VOICES pmd_load had to allocate down to
// what this tune uses, and publish the chip grouping. Also re-run after a
// seek's reload, since that goes back through pmd_load.
static void pmd_apply_voice_layout(int voices) {
    m_genNumVoicesChannels = voices;
    rewamp_channel_data_reset(voices);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 4);
    rewamp_channel_data_set_ring_circular(1);
    rewamp_voices_meta_reset();

    static const char* const kChipName[3] = { "OPNA FM", "OPNA SSG", "PPZ8" };
    for (int c = 0; c < 3; c++) {
        if (pmd_system_voice_idx[c] >= 0 && pmd_system_voice_nb[c] > 0)
            rewamp_voices_add_chip(kChipName[c], pmd_system_voice_idx[c],
                                   pmd_system_voice_nb[c]);
    }
}

static RewampDecoder* pmd_open(const char* path, RewampAudioFormat* outFormat) {
    /* Mode 1 (N boucles): pas de compte natif -> veto, le generique
     * Dart compte les passes (voir configure_loop). */
    if (g_force_loop_mode == 1) g_force_loop_native_veto = 1;
    if (!path) return NULL;

    char cleanPath[4096];
    snprintf(cleanPath, sizeof(cleanPath), "%s", path);
    char* q = strrchr(cleanPath, '?');
    if (q) *q = '\0';

    if (!pmd_load(cleanPath)) return NULL;

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { pmd_stop(); return NULL; }
    snprintf(dec->path, sizeof(dec->path), "%s", cleanPath);

    dec->voices = pmd_voice_count();
    pmd_apply_voice_layout(dec->voices);

    int lengthMs = pmd_length_msec();
    if (lengthMs > 0) dec->totalFrames = (uint64_t)lengthMs * PMD_RATE / 1000;

    // Title/composer come out of the file as Shift-JIS (PMD is a Japanese
    // format) — convert before publishing, or the info panel shows mojibake.
    char title[1024] = { 0 }, compo[1024] = { 0 };
    pmd_get_title(title);
    pmd_get_compo(compo);
    if (title[0]) {
        uint8_t utf8[2048];
        sjis2utf8n(utf8, (uint8_t*)title, sizeof(utf8));
        rewamp_track_message_append("Title: %s\n", (const char*)utf8);
    }
    if (compo[0]) {
        uint8_t utf8[2048];
        sjis2utf8n(utf8, (uint8_t*)compo, sizeof(utf8));
        rewamp_track_message_append("Composer: %s\n", (const char*)utf8);
    }
    rewamp_track_message_append("Format: PMD (PC-98 Professional Music Driver), "
                                "%d Hz, stereo\n", PMD_RATE);
    if (dec->totalFrames > 0) {
        unsigned total = (unsigned)(dec->totalFrames / PMD_RATE);
        rewamp_track_message_append("Duration: %u:%02u\n", total / 60, total % 60);
    }

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = PMD_RATE;
    }
    return dec;
}

static uint64_t pmd_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
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
        pmd_renderer(s_buf, (int)want);   // always fills; PMD never self-stops
        float* dst = out + written * 2;
        for (uint32_t i = 0; i < want * 2; i++) dst[i] = s_buf[i] * scale;
        written += want;
        dec->framePos += want;
    }
    return written;
}

// No native seek: the position IS the driver + chip state. Forward = render and
// discard; backward = reload the tune, then render forward (same idiom as
// UADE/vio2sf/SNDH). pmd_renderer(NULL, n) advances without producing audio,
// which is what makes the discard cheap.
static void pmd_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec) return;
    if (frameIndex < dec->framePos) {
        pmd_stop();
        if (!pmd_load(dec->path)) return;
        pmd_apply_voice_layout(dec->voices);
        dec->framePos = 0;
    }
    while (dec->framePos < frameIndex) {
        uint64_t skip = frameIndex - dec->framePos;
        if (skip > SOUND_BUFFER_SIZE_SAMPLE) skip = SOUND_BUFFER_SIZE_SAMPLE;
        pmd_renderer(NULL, (int)skip);
        dec->framePos += skip;
    }
}

static uint64_t pmd_length(RewampDecoder* dec) {
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
static void pmd_configure_loop_fn(RewampDecoder* dec, int mode, int count) {
    (void)count;
    if (dec != NULL && mode == 2) dec->totalFrames = 0;
}

static void pmd_close(RewampDecoder* dec) {
    if (!dec) return;
    pmd_stop();
    free(dec);
}

static const RewampPluginVTable kPmdVTable = {
    "pmd",
    pmd_probe,
    pmd_open,
    pmd_read,
    pmd_seek,
    pmd_length,
    pmd_close,
    pmd_configure_loop_fn,
};

extern "C" const RewampPluginVTable* rewamp_pmd_plugin(void) { return &kPmdVTable; }

#endif /* REWAMP_WITH_PMD */
