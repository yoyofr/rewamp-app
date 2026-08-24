// HighlyQuixotic plugin — Capcom QSound .qsf/.qsflib via the vendored
// qsound.c (third_party/highlyquixotic): a real Z80 CPU (z80.c) driving the
// ripped CPS2 sound-board program against a QSound DSP core (qsound_ctr.c,
// libvgm-derived), with kabuki.c decrypting kabuki-protected Z80 program ROMs.
// QSF is PSF-family (magic 0x41). Unlike GSF/vio2sf/lazyusf, this core ships
// NO ready-made loader glue in Modizer's own libs/HighlyQuixotic (the ObjC
// wrapper was a stub) — the loader (qsf_loader/upload_qsf_section) and the
// psf_load call site are ported here from Modizer's real, working
// ModizMusicPlayer.mm (mmp_HCLoad, HC_type==0x41), per the user's pointer to
// that reference. Per-voice scope+notes capture already lived in
// qsound_ctr.c (grep YOYOFR) at TWO sites — the scope write AND the real
// stereo mix — both gated on a Modizer app-level global (HC_voicesMuteMask1)
// that doesn't exist in rewamp: always read as 0, meaning the mix gate was
// permanently false and QSound would have been totally silent, not just
// scope-less. Fixed both to rely on chip->muteMask (already correctly
// zeroing voice_output[] for muted voices — a real per-instance field, no
// bare global), wired from generic_mute_mask via qsoundc_set_mute_mask()
// below each read().
#ifdef REWAMP_WITH_HIGHLYQUIXOTIC

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"
#include "qsound.h"
extern "C"
{
// Renamed from qsound_ctr.h: libvgm's own emu/cores/ also has a same-named
// qsound_ctr.h (a different QSound implementation, all-static so no symbol
// clash, but its earlier position on the include search path was winning
// the #include "qsound_ctr.h" resolution and hiding this one entirely).
#include "hq_qsound_ctr.h" // qsoundc_set_mute_mask (no C++ guard upstream)
}
#include "libpsflib/psflib.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#define QSF_RATE 24038 // qsound_clear_state's own qsound_set_rates(...,24038)
#define QSF_VOICES 19  // 16 PCM + 3 ADPCM (qsound_ctr.c's voice_output[16+3])

struct RewampDecoder
{
    uint8_t *core;        // qsound_get_state_size() block
    uint8_t *z80_rom;     // kept alive: qsound_set_z80_rom() stores the pointer,
    uint32_t z80_size;    // doesn't copy (banked ROM areas read it live)
    uint8_t *sample_rom;  // kept alive too, only to replay on seek-rewind
    uint32_t sample_size; // (qsound_set_sample_rom itself copies internally)
    uint32_t swapKey1, swapKey2;
    uint16_t addrKey;
    uint8_t xorKey;
    uint64_t totalFrames; // from length+fade tags; 0 = unknown
    uint64_t framePos;
    int64_t lastMuteMask; // applied generic_mute_mask snapshot
};

// ── psflib stdio callbacks ──────────────────────────────────────────────────
static void *hq_psf_fopen(const char *uri) { return fopen(uri, "rb"); }
static size_t hq_psf_fread(void *b, size_t s, size_t n, void *h) { return fread(b, s, n, (FILE *)h); }
static int hq_psf_fseek(void *h, int64_t o, int w) { return fseek((FILE *)h, (long)o, w); }
static int hq_psf_fclose(void *h) { return fclose((FILE *)h); }
static int64_t hq_psf_ftell(void *h) { return ftell((FILE *)h); }
static const psf_file_callbacks kHqPsfCbs = {
    "\\/:",
    hq_psf_fopen,
    hq_psf_fread,
    hq_psf_fseek,
    hq_psf_fclose,
    hq_psf_ftell,
};

// ── QSF loader (ported from Modizer's ModizMusicPlayer.mm, HC_type==0x41) ──
// QSF's "exe" section is a stream of 3-char-tag + LE32 offset + LE32 size +
// data chunks (KEY/Z80/SMP), NOT the usual PSF exe-blob convention.
struct qsf_loader_state
{
    uint8_t *key;
    uint32_t key_size;
    uint8_t *z80_rom;
    uint32_t z80_size;
    uint8_t *sample_rom;
    uint32_t sample_size;
};

static uint32_t hq_get_le32(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}
static uint32_t hq_get_be32(const uint8_t *p)
{
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | (uint32_t)p[3];
}
static uint16_t hq_get_be16(const uint8_t *p)
{
    return (uint16_t)(((uint16_t)p[0] << 8) | (uint16_t)p[1]);
}

static int hq_upload_section(struct qsf_loader_state *state, const char *section,
                             uint32_t start, const uint8_t *data, uint32_t size)
{
    uint8_t **array = NULL;
    uint32_t *array_size = NULL;
    uint32_t max_size = 0x7fffffff;

    if (!strcmp(section, "KEY"))
    {
        array = &state->key;
        array_size = &state->key_size;
        max_size = 11;
    }
    else if (!strcmp(section, "Z80"))
    {
        array = &state->z80_rom;
        array_size = &state->z80_size;
    }
    else if (!strcmp(section, "SMP"))
    {
        array = &state->sample_rom;
        array_size = &state->sample_size;
    }
    else
        return -1;

    if ((start + size) < start)
        return -1;
    uint32_t new_size = start + size;
    uint32_t old_size = *array_size;
    if (new_size > max_size)
        return -1;

    if (new_size > old_size)
    {
        *array = (uint8_t *)realloc(*array, new_size);
        *array_size = new_size;
        memset((*array) + old_size, 0, new_size - old_size);
    }
    memcpy((*array) + start, data, size);
    return 0;
}

static int hq_qsf_loader(void *context, const uint8_t *exe, size_t exe_size,
                         const uint8_t *reserved, size_t reserved_size)
{
    (void)reserved;
    (void)reserved_size;
    struct qsf_loader_state *state = (struct qsf_loader_state *)context;
    for (;;)
    {
        char s[4];
        if (exe_size < 11)
            break;
        memcpy(s, exe, 3);
        exe += 3;
        exe_size -= 3;
        s[3] = 0;
        uint32_t dataofs = hq_get_le32(exe);
        exe += 4;
        exe_size -= 4;
        uint32_t datasize = hq_get_le32(exe);
        exe += 4;
        exe_size -= 4;
        if (datasize > exe_size)
            return -1;
        if (hq_upload_section(state, s, dataofs, exe, datasize) < 0)
            return -1;
        exe += datasize;
        exe_size -= datasize;
    }
    return 0;
}

// ── Tag reading (title/artist/game/year/copyright + length/fade) ──────────
static int hq_time_ms(const char *v)
{
    char buf[64];
    strncpy(buf, v, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';
    char *nl = strchr(buf, '\n');
    if (nl)
        *nl = '\0';
    const char *parts[4] = {0};
    int np = 0;
    char *tok = strtok(buf, ":");
    while (tok && np < 4)
    {
        parts[np++] = tok;
        tok = strtok(NULL, ":");
    }
    double total = 0.0, mult = 1000.0;
    for (int i = np - 1; i >= 0; i--)
    {
        total += atof(parts[i]) * mult;
        mult *= 60.0;
    }
    return (int)total;
}
struct hq_tag_state
{
    int length_ms, fade_ms;
    char title[256], artist[256], game[256], year[64], copyright[256];
};
static void hq_copy_tag(char *dst, size_t n, const char *v)
{
    strncpy(dst, v, n - 1);
    dst[n - 1] = '\0';
    char *nl = strchr(dst, '\n');
    if (nl)
        *nl = '\0';
}
static int hq_tag_cb(void *ctx, const char *name, const char *value)
{
    struct hq_tag_state *st = (struct hq_tag_state *)ctx;
    if (!name || !value)
        return 0;
    if (strcasecmp(name, "length") == 0)
        st->length_ms = hq_time_ms(value);
    else if (strcasecmp(name, "fade") == 0)
        st->fade_ms = hq_time_ms(value);
    else if (strcasecmp(name, "title") == 0)
        hq_copy_tag(st->title, sizeof(st->title), value);
    else if (strcasecmp(name, "artist") == 0)
        hq_copy_tag(st->artist, sizeof(st->artist), value);
    else if (strcasecmp(name, "game") == 0)
        hq_copy_tag(st->game, sizeof(st->game), value);
    else if (strcasecmp(name, "year") == 0)
        hq_copy_tag(st->year, sizeof(st->year), value);
    else if (strcasecmp(name, "copyright") == 0)
        hq_copy_tag(st->copyright, sizeof(st->copyright), value);
    return 0;
}

static const char *const kHqExts[] = {"qsf", "miniqsf", "qsflib", NULL};

static int hq_probe(const char *ext, const uint8_t *h, size_t n)
{
    int magic = n >= 4 && h[0] == 'P' && h[1] == 'S' && h[2] == 'F' && h[3] == 0x41;
    int extMatch = rewamp_ext_in_list(ext, kHqExts);
    if (magic)
        return extMatch ? 110 : 90;
    if (extMatch)
        return 90;
    return 0;
}

static void hq_apply_roms(RewampDecoder *dec)
{
    if (dec->z80_rom)
    {
        if (dec->swapKey1 || dec->swapKey2 || dec->addrKey || dec->xorKey)
            qsound_set_kabuki_key(dec->core, dec->swapKey1, dec->swapKey2, dec->addrKey, dec->xorKey);
        else
            qsound_set_kabuki_key(dec->core, 0, 0, 0, 0);

        qsound_set_z80_rom(dec->core, dec->z80_rom, dec->z80_size);
    }
    if (dec->sample_rom)
        qsound_set_sample_rom(dec->core, dec->sample_rom, dec->sample_size);
    // qsound_clear_state() (called by our caller just before this) wipes
    // chip->muteMask back to 0 -- reapply the real mute state right away so
    // a backward seek doesn't silently drop the user's per-voice mutes, and
    // cache it so hq_read()'s change-check doesn't immediately redo it.
    qsoundc_set_mute_mask(qsound_get_qmix_state(dec->core), (UINT32)generic_mute_mask);
    dec->lastMuteMask = generic_mute_mask;
}

static RewampDecoder *hq_open(const char *path, RewampAudioFormat *outFormat)
{
    if (!path)
        return NULL;

    // YOYOFR (rewamp): qsound_init() (which calls z80_init()) populates the
    // Z80 core's global static flag-lookup tables (SZ/SZP/SZHV_inc/SZHV_dec,
    // used by every arithmetic/logic instruction to compute Z/S/H/P/V flags).
    // Modizer calls this once at app launch (mmp_HCLoad-adjacent init); our
    // plugin never called it at all, so every conditional Z80 branch (JR Z,
    // JR NZ, ...) evaluated against all-zero tables -- this alone explains
    // both a driver stuck forever in the wrong branch of a polling loop
    // (silent hang) and a driver computing the wrong sample bank/address
    // (audible noise). Idempotent + cheap (256-entry table fill), but only
    // needs to run once process-wide (global static tables, not per-instance).
    static bool s_qsoundInitDone = false;
    if (!s_qsoundInitDone)
    {
        qsound_init();
        s_qsoundInitDone = true;
    }

    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char *q = strrchr(cleanPath, '?');
    if (q)
        *q = '\0';

    struct qsf_loader_state ld;
    memset(&ld, 0, sizeof(ld));
    struct hq_tag_state ts;
    memset(&ts, 0, sizeof(ts));
    if (psf_load(cleanPath, &kHqPsfCbs, 0x41, hq_qsf_loader, &ld, hq_tag_cb, &ts, 0) <= 0)
    {
        free(ld.key);
        free(ld.z80_rom);
        free(ld.sample_rom);
        return NULL;
    }

    RewampDecoder *dec = (RewampDecoder *)calloc(1, sizeof(*dec));
    if (!dec)
    {
        free(ld.key);
        free(ld.z80_rom);
        free(ld.sample_rom);
        return NULL;
    }

    dec->core = (uint8_t *)calloc(1, qsound_get_state_size());
    if (!dec->core)
    {
        free(ld.key);
        free(ld.z80_rom);
        free(ld.sample_rom);
        free(dec);
        return NULL;
    }
    qsound_clear_state(dec->core);

    if (ld.key_size == 11)
    {
        dec->swapKey1 = hq_get_be32(ld.key + 0);
        dec->swapKey2 = hq_get_be32(ld.key + 4);
        dec->addrKey = hq_get_be16(ld.key + 8);
        dec->xorKey = ld.key[10];
    }
    free(ld.key);
    ld.key = NULL;

    // Reset first (zeroes generic_mute_mask too) so hq_apply_roms below applies
    // a clean mute state to the freshly-cleared chip, not a stale one left
    // over from a previous track.
    m_genNumVoicesChannels = QSF_VOICES;
    rewamp_channel_data_reset(QSF_VOICES);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);
    rewamp_channel_data_set_ring_circular(1);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("QSound", 0, QSF_VOICES);

    dec->z80_rom = ld.z80_rom;
    dec->z80_size = ld.z80_size;
    dec->sample_rom = ld.sample_rom;
    dec->sample_size = ld.sample_size;
    hq_apply_roms(dec);

    if (ts.length_ms > 0)
        dec->totalFrames = (uint64_t)((double)(ts.length_ms + ts.fade_ms) / 1000.0 * QSF_RATE);

    if (ts.title[0])
        rewamp_track_message_append("Title: %s\n", ts.title);
    if (ts.game[0])
        rewamp_track_message_append("Game: %s\n", ts.game);
    if (ts.artist[0])
        rewamp_track_message_append("Artist: %s\n", ts.artist);
    if (ts.year[0])
        rewamp_track_message_append("Year: %s\n", ts.year);
    if (ts.copyright[0])
        rewamp_track_message_append("Copyright: %s\n", ts.copyright);
    rewamp_track_message_append("Format: QSF (Capcom QSound), %d Hz, stereo\n", QSF_RATE);

    if (outFormat)
    {
        outFormat->channels = 2;
        outFormat->sampleRate = QSF_RATE;
    }
    return dec;
}

static uint64_t hq_read(RewampDecoder *dec, float *out, uint64_t frameCount)
{
    if (!dec || frameCount == 0)
        return 0;

    if (dec->lastMuteMask != generic_mute_mask)
    {
        dec->lastMuteMask = generic_mute_mask;
        qsoundc_set_mute_mask(qsound_get_qmix_state(dec->core), (UINT32)generic_mute_mask);
    }

    if (dec->totalFrames > 0)
    {
        if (dec->framePos >= dec->totalFrames)
            return 0;
        uint64_t remain = dec->totalFrames - dec->framePos;
        if (frameCount > remain)
            frameCount = remain;
    }

    static int16_t s_buf[4096 * 2];
    const float scale = 1.0f / 32768.0f;
    uint64_t written = 0;
    while (written < frameCount)
    {
        uint32_t want = (uint32_t)(frameCount - written);
        if (want > 4096)
            want = 4096;
        uint32_t got = want;
        int32_t r = qsound_execute(dec->core, 0x7fffffff, s_buf, &got);
        if (r < 0 || got == 0)
            break;
        float *dst = out + written * 2;
        for (uint32_t i = 0; i < got * 2; i++)
            dst[i] = s_buf[i] * scale;
        written += got;
        dec->framePos += got;
        if (got < want)
            break;
    }
    return written;
}

extern "C" volatile int    g_seek_cancel;
extern "C" volatile int    g_is_seeking;
extern "C" volatile double g_seek_progress_s;

// No native seek in the QSound Z80 core -- rewind (on backward seek) +
// discard-render forward, same idiom as UADE/vio2sf/SNDH/lazyusf. Reports
// progress via g_is_seeking/g_seek_progress_s (polled by Dart for the seek
// progress bar, same mechanism as libsidplayfp's sid_seek) and honors
// g_seek_cancel so a new seek request during a slow one aborts promptly.
static void hq_seek(RewampDecoder *dec, uint64_t frameIndex)
{
    if (!dec)
        return;
    if (frameIndex < dec->framePos)
    {
        qsound_clear_state(dec->core);
        hq_apply_roms(dec);
        dec->framePos = 0;
    }
    if (dec->framePos == frameIndex)
        return;
    g_is_seeking = 1;
    float tmp[256 * 2];
    while (dec->framePos < frameIndex && !g_seek_cancel)
    {
        uint64_t want = frameIndex - dec->framePos;
        if (want > 256)
            want = 256;
        uint64_t got = hq_read(dec, tmp, want);
        g_seek_progress_s = (double)dec->framePos / (double)QSF_RATE;
        if (got == 0)
            break;
    }
    g_is_seeking = 0;
}

static uint64_t hq_length(RewampDecoder *dec)
{
    return dec ? dec->totalFrames : 0;
}

static void hq_close(RewampDecoder *dec)
{
    if (!dec)
        return;
    free(dec->core);
    free(dec->z80_rom);
    free(dec->sample_rom);
    free(dec);
}

static const RewampPluginVTable kHqVTable = {
    "highlyquixotic",
    hq_probe,
    hq_open,
    hq_read,
    hq_seek,
    hq_length,
    hq_close,
};

extern "C" const RewampPluginVTable *rewamp_highlyquixotic_plugin(void) { return &kHqVTable; }

#endif /* REWAMP_WITH_HIGHLYQUIXOTIC */
