/* MT-32 plugin: Standard MIDI rendered by a Roland MT-32 / CM-32L emulation
 * (munt's libmt32emu, LGPL-2.1), driven by TinyMidiLoader (tml.h) as the
 * sequencer — the same event list the FluidLite plugin plays, plus the System
 * Exclusive messages tml.h now keeps (rewamp alteration, tml_load_filename_ex):
 * an MT-32 score loads its custom timbres through them.
 *
 * SECOND engine for .mid, next to FluidLite (SoundFont). Neither is exclusive:
 * both score 100 on a plain MIDI file (FluidLite registered first wins the
 * tie), this one scores 104 when the file carries Roland MT-32 sysex
 * (F0 41 xx 16), and the app pins one or the other through
 * rewamp_registry_set_preferred_plugin("mid", …) from the « Synthé MIDI »
 * setting. Without a usable ROM set the probe returns 0 — the pin is then
 * simply absent and FluidLite plays.
 *
 * ROMs are Roland's copyright: NEVER bundled, never downloaded. The user
 * imports them (Settings → MIDI → MT-32), they live in <datadir>/mt32/ and
 * are identified by SHA1 through mt32emu's own ROMInfo table — MAME split
 * halves (_a/_b, _l/_h) are paired at load. Model preference (engine param
 * "model": 0 auto, 1 MT-32, 2 CM-32L) picks the set; auto prefers the CM-32L
 * (a superset of the MT-32 timbres) when its 1 MB PCM ROM is present, else
 * the classic MT-32 v1.07 that most game scores were composed on.
 *
 * Per-voice scope: 9 voices = the 8 melodic parts + the rhythm part. mt32emu
 * mixes its 32 partials into shared buffers, so the per-part signal is
 * rebuilt by three hooks in the vendored core (rewamp_mt32_capture.h, grep
 * YOYOFR under third_party/mt32emu). Notes come from Synth::getPlayingNotes
 * (the emulator's own truth, which survives sysex channel reassignment);
 * mute is native (setPartVolumeOverride 0 = no sound generated at all).
 */

#include "rewamp_plugin.h"
#include "rewamp_mt32_detect.h"   /* « ce MIDI vise-t-il le MT-32 ? », partagé avec FluidLite */
#include "rewamp_registry.h"
#include "rewamp_channel_data.h"
#include "rewamp_assets.h"
#include "rewamp_audio.h"            /* extern "C" exports — FFI linkage rule */
#include "ModizerVoicesData.h"
#include "ModizerConstants.h"
#include "rewamp_mt32_capture.h"

#include "tml.h"                     /* implementation lives in rewamp_tml.c */
#include <mt32emu/mt32emu.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdarg>
#include <mutex>
#include <strings.h>
#include <dirent.h>
#include <sys/stat.h>

using namespace MT32Emu;

#define MT32_NATIVE_RATE 32000       /* mt32emu timestamps count these */
#define MT32_TAIL_MS     2000        /* let releases / reverb ring out */
#define MT32_PARTS       9           /* 8 melodic + rhythm */
/* Index d'instrument de la partie RYTHMIQUE dans la timeline des viz: au-dessus
 * des 128 programmes mélodiques (index programme + 1), comme le canal 10 de
 * FluidLite. Elle valait 0 — « aucun instrument » — donc en mode « par
 * instrument » la légende n'avait rien à nommer pour elle et un solo sur
 * « Rhythm » affichait le libellé d'une autre voix (constaté 2026-09-12). */
#define MT32_RHYTHM_INSTR 129u
#define MT32_RING_SIZE   (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)   /* power of 2 */
#define MT32_FP          MODIZER_OSCILLO_OFFSET_FIXEDPOINT

/* ── ROM directory + set selection ──────────────────────────────────────────── */

static char g_rom_dir[4096] = "";

extern "C" void rewamp_mt32_set_rom_dir(const char* path) {
    if (!path) { g_rom_dir[0] = '\0'; return; }
    strncpy(g_rom_dir, path, sizeof(g_rom_dir) - 1);
    g_rom_dir[sizeof(g_rom_dir) - 1] = '\0';
}

static const char* mt32_rom_dir(void) {
    if (g_rom_dir[0]) return g_rom_dir;
    const char* dd = rewamp_get_data_dir();
    if (dd && dd[0]) {
        static char def[4096];
        snprintf(def, sizeof(def), "%s/mt32", dd);
        return def;
    }
    return NULL;
}

/* One known ROM file on disk. */
struct RomFile {
    char           path[4096];
    const ROMInfo* info;
};

#define MT32_MAX_ROM_FILES 64

/* Identification cache. Recognising a file means a SHA1 over the whole of it
 * (ROMInfo::getROMInfo), and the scan runs on EVERY probe of a .mid — the
 * registry probes each candidate file, and `rewamp_can_play` sits in the local
 * open path. Uncached, a 1.7 MB ROM set cost 2.6 ms per probe (0.03 ms without
 * the scan): half a second for a folder of 185 MIDIs, before anything played.
 * A file is re-hashed only when its (path, size, mtime) changes; the directory
 * walk + stat stay, so an imported or deleted ROM is seen at the next probe.
 * The probe runs on the Dart thread and open() on the producer thread, hence
 * the lock. */
struct RomIdCache {
    char           path[4096];
    off_t          size;
    time_t         mtime;
    const ROMInfo* info;   /* NULL = hashed, not a known ROM */
};
static RomIdCache g_rom_id_cache[MT32_MAX_ROM_FILES * 2];
static int        g_rom_id_count = 0;
static std::mutex g_rom_id_mutex;

static const ROMInfo* mt32_identify_cached(const char* path, const struct stat& st) {
    for (int i = 0; i < g_rom_id_count; i++) {
        RomIdCache& c = g_rom_id_cache[i];
        if (c.size == st.st_size && c.mtime == st.st_mtime && strcmp(c.path, path) == 0)
            return c.info;
    }
    FileStream fs;
    const ROMInfo* info = NULL;
    if (fs.open(path)) {
        info = ROMInfo::getROMInfo(&fs);
        fs.close();
    }
    /* Replace a stale entry for the same path, else append; when full, start
     * over (a directory with 128 candidate files is not a ROM set). */
    int slot = -1;
    for (int i = 0; i < g_rom_id_count; i++)
        if (strcmp(g_rom_id_cache[i].path, path) == 0) { slot = i; break; }
    if (slot < 0) {
        if (g_rom_id_count >= (int)(sizeof(g_rom_id_cache) / sizeof(g_rom_id_cache[0])))
            g_rom_id_count = 0;
        slot = g_rom_id_count++;
    }
    RomIdCache& c = g_rom_id_cache[slot];
    strncpy(c.path, path, sizeof(c.path) - 1);
    c.path[sizeof(c.path) - 1] = '\0';
    c.size  = st.st_size;
    c.mtime = st.st_mtime;
    c.info  = info;
    return info;
}

/* Scans the ROM directory: every file mt32emu's ROMInfo table recognises. */
static int mt32_scan_roms(RomFile* out, int maxOut) {
    const char* dir = mt32_rom_dir();
    if (!dir) return 0;
    DIR* d = opendir(dir);
    if (!d) return 0;
    std::lock_guard<std::mutex> lock(g_rom_id_mutex);
    int n = 0;
    struct dirent* e;
    while ((e = readdir(d)) != NULL && n < maxOut) {
        if (e->d_name[0] == '.') continue;
        RomFile rf;
        snprintf(rf.path, sizeof(rf.path), "%s/%s", dir, e->d_name);
        struct stat st;
        if (stat(rf.path, &st) != 0 || !S_ISREG(st.st_mode)) continue;
        /* All known ROMs are 32 KB .. 1 MB; skip anything else before hashing. */
        if (st.st_size < 32768 || st.st_size > 1048576) continue;
        rf.info = mt32_identify_cached(rf.path, st);
        if (!rf.info) continue;
        out[n++] = rf;
    }
    closedir(d);
    return n;
}

/* Preference order of control ROMs per model choice. shortName prefixes;
 * halves share the prefix of their full image (ctrl_mt32_1_07 / _a / _b). */
static const char* const kCtrlMt32[]  = { "ctrl_mt32_1_07", "ctrl_mt32_1_06", "ctrl_mt32_1_05",
                                          "ctrl_mt32_1_04", "ctrl_mt32_bluer", "ctrl_mt32_2_07",
                                          "ctrl_mt32_2_06", "ctrl_mt32_2_04", "ctrl_mt32_2_03", NULL };
static const char* const kCtrlCm32l[] = { "ctrl_cm32l_1_02", "ctrl_cm32l_1_00", "ctrl_cm32ln_1_00", NULL };

static int mt32_name_is(const ROMInfo* i, const char* prefix) {
    size_t n = strlen(prefix);
    if (strncmp(i->shortName, prefix, n) != 0) return 0;
    const char* rest = i->shortName + n;
    return rest[0] == '\0' || rest[0] == '_';   /* exact, or a half (_a/_b/_l/_h) */
}

/* A usable image for [prefix]: a Full file, or a paired half set. Returns the
 * indexes into files[] (idx2 = -1 for a full image), 0 when absent. */
static int mt32_find_image(const RomFile* files, int n, const char* prefix,
                           ROMInfo::Type type, int* idx1, int* idx2) {
    for (int i = 0; i < n; i++)
        if (files[i].info->type == type && files[i].info->pairType == ROMInfo::Full &&
            mt32_name_is(files[i].info, prefix)) { *idx1 = i; *idx2 = -1; return 1; }
    for (int i = 0; i < n; i++) {
        const ROMInfo* a = files[i].info;
        if (a->type != type || a->pairType == ROMInfo::Full || !mt32_name_is(a, prefix)) continue;
        for (int j = 0; j < n; j++) {
            const ROMInfo* b = files[j].info;
            if (i == j || b->type != type) continue;
            if (a->pairROMInfo == b || b->pairROMInfo == a) { *idx1 = i; *idx2 = j; return 1; }
        }
    }
    return 0;
}

struct RomSet {
    int  ctrl1, ctrl2, pcm1, pcm2;     /* indexes into the scan; -1 = none */
    const char* ctrlName;
    const char* pcmName;
    int  isCm32l;
};

/* Picks the control + PCM pair for the model preference. */
static int mt32_select_set(const RomFile* files, int n, int model, RomSet* out) {
    const char* const* order[2];
    int norder = 0;
    if (model == 2)      { order[norder++] = kCtrlCm32l; }
    else if (model == 1) { order[norder++] = kCtrlMt32; }
    else                 { order[norder++] = kCtrlCm32l; order[norder++] = kCtrlMt32; }
    for (int o = 0; o < norder; o++) {
        for (const char* const* p = order[o]; *p; p++) {
            int c1, c2;
            if (!mt32_find_image(files, n, *p, ROMInfo::Control, &c1, &c2)) continue;
            int cm = strncmp(*p, "ctrl_cm32l", 10) == 0;
            /* A CM-32L control ROM needs the 1 MB CM-32L PCM; an MT-32 one
             * takes its own 512 KB PCM, or the CM-32L PCM whose first half
             * is the same data. */
            int p1, p2;
            const char* pcmName = NULL;
            if (mt32_find_image(files, n, cm ? "pcm_cm32l" : "pcm_mt32", ROMInfo::PCM, &p1, &p2))
                pcmName = cm ? "pcm_cm32l" : "pcm_mt32";
            else if (!cm && mt32_find_image(files, n, "pcm_cm32l", ROMInfo::PCM, &p1, &p2))
                pcmName = "pcm_cm32l";
            if (!pcmName) continue;
            out->ctrl1 = c1; out->ctrl2 = c2; out->pcm1 = p1; out->pcm2 = p2;
            out->ctrlName = files[c1].info->description;
            out->pcmName  = files[p1].info->description;
            out->isCm32l  = cm;
            return 1;
        }
    }
    return 0;
}

static int mt32_model_param(void) {
    return (int)rewamp_get_engine_param("mt32", "model", 0);
}

/* What the plugin would play with right now — the Settings subtitle. Empty
 * when no usable set is installed. */
extern "C" const char* rewamp_mt32_rom_status(void) {
    static char buf[256];
    buf[0] = '\0';
    /* Heap, not stack: 64 × 4 KB paths = 256 KB, and this runs on the Dart
     * thread (probe) and the producer thread (open), not on main. */
    RomFile* files = (RomFile*)calloc(MT32_MAX_ROM_FILES, sizeof(RomFile));
    if (!files) return buf;
    int n = mt32_scan_roms(files, MT32_MAX_ROM_FILES);
    RomSet set;
    if (n > 0 && mt32_select_set(files, n, mt32_model_param(), &set))
        snprintf(buf, sizeof(buf), "%s + %s", set.ctrlName, set.pcmName);
    free(files);
    return buf;
}

/* Identifies ONE file for the import flow: description ("MT-32 Control
 * v1.07"), or empty when mt32emu does not know it. A half image is flagged
 * so the UI can say the other half is still needed. */
extern "C" const char* rewamp_mt32_identify_rom(const char* path) {
    static char buf[256];
    buf[0] = '\0';
    if (!path) return buf;
    FileStream fs;
    if (!fs.open(path)) return buf;
    const ROMInfo* info = ROMInfo::getROMInfo(&fs);
    fs.close();
    if (!info) return buf;
    snprintf(buf, sizeof(buf), "%s%s", info->description,
             info->pairType == ROMInfo::Full ? "" : " (half)");
    return buf;
}

/* ── Report handler: LCD text (game titles arrive here by sysex), patch names ── */

static char g_lcd[64] = "";

/* Dernier index d'instrument NOMMÉ par partie (0 = aucun): le nom du patch
 * est recopié quand le programme de la partie CHANGE, pas à chaque pas de
 * capture. Un seul greffon MT-32 vit à la fois, comme g_lcd. */
static unsigned g_named_instr[8] = {0};

extern "C" const char* rewamp_mt32_lcd(void) { return g_lcd; }

class RewampReportHandler : public ReportHandler {
public:
    void printDebug(const char*, va_list) override {}
    void showLCDMessage(const char* message) override {
        if (!message) return;
        strncpy(g_lcd, message, sizeof(g_lcd) - 1);
        g_lcd[sizeof(g_lcd) - 1] = '\0';
    }
    bool onMIDIQueueOverflow() override { return false; }
    void onProgramChanged(Bit8u partNum, const char*, const char* patchName) override {
        if (partNum < MT32_PARTS && patchName && patchName[0]) {
            char nm[MODIZ_VOICE_NAME_MAX_CHAR];
            snprintf(nm, sizeof(nm), "%.*s", (int)sizeof(nm) - 1, patchName);
            rewamp_voice_set_name(partNum, nm);
        }
    }
};

/* ── Per-part scope capture (hooks called from the vendored core) ───────────── */

static float    g_acc[MT32_PARTS][MAX_SAMPLES_PER_RUN];
static unsigned g_acc_len = 0;
static int      g_capture_on = 0;
static int64_t  g_capture_incr = 1 << MT32_FP;   /* output frames per native sample, fixed point */

extern "C" void rewamp_mt32_run_begin(unsigned int nativeLen) {
    if (!g_capture_on) return;
    if (nativeLen > MAX_SAMPLES_PER_RUN) nativeLen = MAX_SAMPLES_PER_RUN;
    g_acc_len = nativeLen;
    for (int p = 0; p < MT32_PARTS; p++) memset(g_acc[p], 0, nativeLen * sizeof(float));
}

extern "C" void rewamp_mt32_run_add(unsigned int part, unsigned int sampleNum, float lr) {
    if (!g_capture_on || part >= MT32_PARTS || sampleNum >= g_acc_len) return;
    if ((generic_mute_mask >> part) & 1) return;
    g_acc[part][sampleNum] += lr;
}

/* Native 32 kHz samples land in rings that advance at the OUTPUT rate (the
 * datasource keys captures by output frame): each native sample fills the
 * ring forward by `incr` (1.5 frames at 48 kHz) — the libvgm idiom. Every
 * part advances, sounding or not, so the nine stay squared up. */
extern "C" void rewamp_mt32_run_end(unsigned int nativeLen) {
    if (!g_capture_on) return;
    if (nativeLen > g_acc_len) nativeLen = g_acc_len;
    const int mask = MT32_RING_SIZE - 1;
    for (int p = 0; p < MT32_PARTS; p++) {
        if (!m_voice_buff[p]) continue;
        int64_t ofs = m_voice_current_ptr[p];
        for (unsigned i = 0; i < nativeLen; i++) {
            float f = g_acc[p][i] * 127.0f;
            if (f > 127.0f) f = 127.0f;
            if (f < -128.0f) f = -128.0f;
            int8_t v = (int8_t)f;
            int64_t end = ofs + g_capture_incr;
            for (;;) {
                m_voice_buff[p][(ofs >> MT32_FP) & mask] = v;
                ofs += 1 << MT32_FP;
                if (ofs >= end) break;
            }
            ofs = end;
        }
        m_voice_current_ptr[p] = ofs;
    }
}

/* ── Decoder ────────────────────────────────────────────────────────────────── */

typedef struct {
    Synth*                 synth;
    RewampReportHandler*   report;
    FileStream*            files[4];
    const ROMImage*        ctrlHalf[2];   /* halves kept until merged/freed */
    const ROMImage*        pcmHalf[2];
    const ROMImage*        ctrl;
    const ROMImage*        pcm;
    RomSet                 set;
    tml_message*           events;        /* full list (owned) */
    tml_sysex_store*       sysex;         /* owned */
    tml_message*           next;          /* next event to enqueue */
    uint32_t               rate;          /* output rate (48000 in ACCURATE mode) */
    uint64_t               out_pos;       /* frames rendered at `rate` */
    uint64_t               total_frames;
    unsigned               total_ms;
    int64_t                ts_offset;     /* file native ts − synth counter (re-aligned by every seek) */
    int64_t                mute_applied;  /* generic_mute_mask last pushed */
    uint8_t                chan_prog[16]; /* piano « par instrument » */
    int                    remap_gm;      /* channel 1 used, channel 9 free: GM layout */
    unsigned char*         bank;          /* companion MT-32 setup: F0..F7 messages, back to back */
    size_t                 bank_len;
    unsigned               bank_count;
    char                   bank_name[128];
} Mt32Dec;

static const char* const kMidiExts[] = { "mid", "midi", "kar", "rmi", NULL };

static int mt32_probe(const char* ext, const uint8_t* header, size_t headerSize) {
    int extMatch = rewamp_ext_in_list(ext, kMidiExts);
    int magic = headerSize >= 4 && memcmp(header, "MThd", 4) == 0;
    if (!magic && headerSize >= 12 &&
        memcmp(header, "RIFF", 4) == 0 && memcmp(header + 8, "RMID", 4) == 0)
        magic = 1;
    if (!magic && !extMatch) return 0;
    /* No usable ROM set → 0: the pin (if any) is simply absent, FluidLite plays. */
    if (rewamp_mt32_rom_status()[0] == '\0') return 0;
    if (magic) return extMatch ? 100 : 95;
    return 60;
}

static int mt32_probe_path(const char* ext, const uint8_t* header, size_t headerSize,
                           const char* path, uint64_t fileSize) {
    int s = mt32_probe(ext, header, headerSize);
    if (s < 95) return s;
    /* Roland MT-32 sysex inside — or an MT-32 bank beside it — = written FOR
     * this synth: beat FluidLite's 100 in auto mode, stay under
     * REWAMP_SCORE_EXCLUSIVE (105) so the SoundFont pin can still override. */
    if (rewamp_mt32_file_has_sysex(path, fileSize)) return 104;
    if (path && (rewamp_mt32_dir_has_bank(path) || rewamp_mt32_in_mt32_folder(path))) return 104;
    return s;
}

static uint32_t mt32_pack(const tml_message* m) {
    uint32_t status = (uint32_t)m->type | (uint32_t)(m->channel & 0x0F);
    uint32_t d1 = 0, d2 = 0;
    switch (m->type) {
        case TML_NOTE_OFF: case TML_NOTE_ON: case TML_KEY_PRESSURE:
            d1 = (uint8_t)m->key; d2 = (uint8_t)m->velocity; break;
        case TML_CONTROL_CHANGE:
            d1 = (uint8_t)m->control; d2 = (uint8_t)m->control_value; break;
        case TML_PROGRAM_CHANGE:
            d1 = (uint8_t)m->program; break;
        case TML_CHANNEL_PRESSURE:
            d1 = (uint8_t)m->channel_pressure; break;
        case TML_PITCH_BEND:
            d1 = m->pitch_bend & 0x7F; d2 = (m->pitch_bend >> 7) & 0x7F; break;
        default: return 0;
    }
    return status | (d1 << 8) | (d2 << 16);
}

static int mt32_is_channel_msg(const tml_message* m) {
    switch (m->type) {
        case TML_NOTE_OFF: case TML_NOTE_ON: case TML_KEY_PRESSURE:
        case TML_CONTROL_CHANGE: case TML_PROGRAM_CHANGE:
        case TML_CHANNEL_PRESSURE: case TML_PITCH_BEND: return 1;
        default: return 0;
    }
}

static void mt32_note_prog(Mt32Dec* d, const tml_message* m) {
    if (m->type == TML_PROGRAM_CHANGE && m->channel < 16)
        d->chan_prog[m->channel] = (uint8_t)m->program;
}

/* Returns 0 when the synth queue is full (caller renders, then retries). */
static int mt32_enqueue(Mt32Dec* d, const tml_message* m, uint32_t ts) {
    if (m->type == TML_SYSEX_MESSAGE) {
        unsigned len = 0;
        const unsigned char* sx = tml_sysex_get(d->sysex, m->sysex, &len);
        if (!sx || len < 2) return 1;                 /* nothing to play, consumed */
        if (sx[0] != 0xF0) return 1;                  /* F7 escape / fragment: ignore */
        return d->synth->playSysex(sx, len, ts) ? 1 : 0;
    }
    if (!mt32_is_channel_msg(m)) return 1;            /* tempo etc.: timeline only */
    return d->synth->playMsg(mt32_pack(m), ts) ? 1 : 0;
}

/* Immediate dispatch (seek fast-forward): state-bearing events only. */
static void mt32_dispatch_now(Mt32Dec* d, const tml_message* m) {
    if (m->type == TML_SYSEX_MESSAGE) {
        unsigned len = 0;
        const unsigned char* sx = tml_sysex_get(d->sysex, m->sysex, &len);
        if (sx && len >= 2 && sx[0] == 0xF0) d->synth->playSysexNow(sx, len);
        return;
    }
    if (m->type == TML_NOTE_ON || m->type == TML_NOTE_OFF || m->type == TML_KEY_PRESSURE) return;
    if (!mt32_is_channel_msg(m)) return;
    d->synth->playMsgNow(mt32_pack(m));
}

/* File time → synth timestamp. The synth counter restarts at 0 on a rewind
 * and stays put across a fast-forward, while file times keep counting from
 * the start: the offset, recomputed by every seek, realigns the two. */
static inline uint32_t mt32_file_ts(const Mt32Dec* d, const tml_message* m) {
    int64_t ts = (int64_t)m->time * (MT32_NATIVE_RATE / 1000) - d->ts_offset;
    return ts > 0 ? (uint32_t)ts : 0u;
}

static void mt32_poll_notes(Mt32Dec* d) {
    Bit8u keys[DEFAULT_MAX_PARTIALS * 2], vels[DEFAULT_MAX_PARTIALS * 2];
    for (int p = 0; p < MT32_PARTS; p++) {
        Bit32u n = d->synth->getPlayingNotes((Bit8u)p, keys, vels);
        if (n == 0 || ((generic_mute_mask >> p) & 1)) {
            vgm_last_note[p] = 0;
            vgm_last_vol[p]  = 0;
            continue;
        }
        unsigned key = keys[n - 1], vel = 0;   /* the newest poly */
        for (Bit32u i = 0; i < n; i++) if (vels[i] > vel) vel = vels[i];
        vgm_last_note[p] = (unsigned int)(440.0 * pow(2.0, ((int)key - 69) / 12.0) + 0.5);
        vgm_last_vol[p]  = vel;
        /* Program of the MIDI channel this part listens to by default
         * (parts 1-8 = channels 2-9); the rhythm part has its OWN index. */
        vgm_last_instr[p] = p < 8 ? (unsigned int)d->chan_prog[p + 1] + 1u
                                  : MT32_RHYTHM_INSTR;
        /* Nom de l'instrument pour la légende « par instrument » des viz: le
         * PATCH de la partie, tel que le synthé l'a appliqué — c'est le nom
         * que le vrai matériel affiche, et il vaut mieux que « Inst 42 » sur
         * un MT-32 où les timbres sont propres au jeu.
         * ⚠️ La chaîne rendue n'est garantie que jusqu'au prochain rendu
         * (contrat de mt32emu): elle est COPIÉE tout de suite.
         * ⚠️ Le nom suit l'état APPLIQUÉ du synthé, l'index vient du flux
         * MIDI: un program change encore dans la file du synthé nomme donc
         * l'index avec le patch précédent, le temps de quelques millisecondes
         * de rendu. */
        if (p < 8) {
            const unsigned idx = (unsigned)d->chan_prog[p + 1] + 1u;
            if (idx != g_named_instr[p]) {
                const char* pn = d->synth->getPatchName((Bit8u)p);
                if (pn && pn[0]) {
                    rewamp_instrument_set_name((int)idx, pn);
                    g_named_instr[p] = idx;
                }
            }
        }
    }
}

static void mt32_apply_mute(Mt32Dec* d) {
    if (d->mute_applied == generic_mute_mask) return;
    for (int p = 0; p < MT32_PARTS; p++) {
        int was = (int)((d->mute_applied >> p) & 1), now = (int)((generic_mute_mask >> p) & 1);
        if (was != now) d->synth->setPartVolumeOverride((Bit8u)p, now ? 0 : 255);
    }
    d->mute_applied = generic_mute_mask;
}

static void mt32_apply_params(Mt32Dec* d) {
    Synth* s = d->synth;
    if (!s) return;
    int    rev  = (int)rewamp_get_engine_param("mt32", "reverb", 1);
    double gain = rewamp_get_engine_param("mt32", "gain", 1.0);
    s->setReverbEnabled(rev != 0);
    s->setOutputGain((float)gain);
    s->setReverbOutputGain((float)gain);
}

static void mt32_close(RewampDecoder* rd);

/* The MT-32 listens to MIDI channels 2-9 (parts 1-8) and 10 (rhythm); channel
 * 1 is unassigned at power-on — a real unit stays SILENT on a file written
 * for the GM layout (channels 1-8), and so did prelude.mid here. When the file
 * uses channel 1 and leaves channel 9 free, the parts are moved to channels
 * 1-8 through the unit's own System-area sysex (address 10 00 0D: nine
 * channel numbers, parts 1-8 then rhythm), the way the ScummVM MT-32 driver
 * does. The file stays in charge: a later reassignment of its own wins. */
static void mt32_remap_channels(Mt32Dec* d) {
    if (!d->remap_gm) return;
    Bit8u sx[8 + 9 + 2];
    int n = 0;
    sx[n++] = 0xF0; sx[n++] = 0x41; sx[n++] = 0x10; sx[n++] = 0x16; sx[n++] = 0x12;
    sx[n++] = 0x10; sx[n++] = 0x00; sx[n++] = 0x0D;
    for (int p = 0; p < 8; p++) sx[n++] = (Bit8u)p;   /* parts 1-8 → channels 1-8 */
    sx[n++] = 9;                                       /* rhythm stays on channel 10 */
    unsigned sum = 0;
    for (int i = 5; i < n; i++) sum += sx[i];
    sx[n++] = (Bit8u)((128 - (sum % 128)) % 128);
    sx[n++] = 0xF7;
    d->synth->playSysexNow(sx, (Bit32u)n);
}

/* ── Companion MT-32 bank ──────────────────────────────────────────────────
 * Many rips ship the game's MT-32 setup APART from the tunes, to be sent
 * first: a raw dump (<game>.SYX — Sierra, Prince of Persia, Betrayal at
 * Krondor…) or a MIDI file that carries only sysex (Ultima VII's
 * sysexmain.mid: "play this first to program the MT-32"). Without it every
 * tune plays the FACTORY patches at custom-timbre program numbers — Ultima
 * VII's wind and birds came out as random instruments. The bank is sent
 * before the first note and again after every synth restart (a rewind
 * reopens the unit, which wipes timbre memory). */
static void mt32_bank_append(Mt32Dec* d, const unsigned char* buf, size_t n) {
    for (size_t i = 0; i < n; i++) {
        if (buf[i] != 0xF0) continue;
        size_t j = i + 1;
        while (j < n && buf[j] != 0xF7 && !(buf[j] & 0x80)) j++;
        if (j >= n || buf[j] != 0xF7) continue;          /* truncated: skip */
        size_t len = j - i + 1;
        unsigned char* nb = (unsigned char*)realloc(d->bank, d->bank_len + len);
        if (!nb) return;
        d->bank = nb;
        memcpy(d->bank + d->bank_len, buf + i, len);
        d->bank_len += len;
        d->bank_count++;
        i = j;
    }
}

static int mt32_bank_cmp(const void* a, const void* b) {
    return strcmp((const char*)a, (const char*)b);
}

static void mt32_load_bank(Mt32Dec* d, const char* songPath) {
    char dir[4096];
    strncpy(dir, songPath, sizeof(dir) - 1);
    dir[sizeof(dir) - 1] = '\0';
    char* slash = strrchr(dir, '/');
    if (!slash) return;
    *slash = '\0';
    const char* songBase = slash + 1 - dir + songPath;
    DIR* dd = opendir(dir);
    if (!dd) return;
    char names[8][256];
    int nn = 0;
    struct dirent* e;
    while ((e = readdir(dd)) != NULL && nn < 8) {
        const char* nm = e->d_name;
        if (nm[0] == '.' || strcmp(nm, songBase) == 0) continue;
        const char* dot = strrchr(nm, '.');
        if (!dot) continue;
        int syx = strcasecmp(dot, ".syx") == 0;
        int sysMid = (strcasecmp(dot, ".mid") == 0 || strcasecmp(dot, ".midi") == 0) &&
                     strncasecmp(nm, "sys", 3) == 0;
        if (!syx && !sysMid) continue;
        snprintf(names[nn++], sizeof(names[0]), "%s", nm);
    }
    closedir(dd);
    if (nn == 0) return;
    qsort(names, (size_t)nn, sizeof(names[0]), mt32_bank_cmp);
    for (int k = 0; k < nn; k++) {
        char path[4096 + 256];
        snprintf(path, sizeof(path), "%s/%s", dir, names[k]);
        const char* dot = strrchr(names[k], '.');
        unsigned before = d->bank_count;
        if (strcasecmp(dot, ".syx") == 0) {
            struct stat st;
            if (stat(path, &st) != 0 || st.st_size <= 0 || st.st_size > (1 << 20)) continue;
            FILE* f = fopen(path, "rb");
            if (!f) continue;
            unsigned char* buf = (unsigned char*)malloc((size_t)st.st_size);
            if (buf) {
                size_t got = fread(buf, 1, (size_t)st.st_size, f);
                mt32_bank_append(d, buf, got);
                free(buf);
            }
            fclose(f);
        } else {
            tml_sysex_store* store = NULL;
            tml_message* evs = tml_load_filename_ex(path, &store);
            int notes = 0;
            for (tml_message* m = evs; m; m = m->next)
                if (m->type == TML_NOTE_ON && m->velocity > 0) notes++;
            /* A "sys*.mid" that plays notes is a tune, not a bank. */
            if (!notes) {
                for (tml_message* m = evs; m; m = m->next) {
                    if (m->type != TML_SYSEX_MESSAGE) continue;
                    unsigned len = 0;
                    const unsigned char* sx = tml_sysex_get(store, m->sysex, &len);
                    if (sx && len >= 2 && sx[0] == 0xF0) mt32_bank_append(d, sx, len);
                }
            }
            if (evs) tml_free(evs);
            if (store) tml_sysex_free(store);
        }
        if (d->bank_count > before) {
            size_t used = strlen(d->bank_name);
            snprintf(d->bank_name + used, sizeof(d->bank_name) - used, "%s%s",
                     used ? ", " : "", names[k]);
        }
    }
}

static void mt32_send_bank(Mt32Dec* d) {
    size_t i = 0;
    while (i < d->bank_len) {
        size_t j = i;
        while (j < d->bank_len && d->bank[j] != 0xF7) j++;
        if (j >= d->bank_len) break;
        d->synth->playSysexNow(d->bank + i, (Bit32u)(j - i + 1));
        i = j + 1;
    }
}

static int mt32_open_synth(Mt32Dec* d) {
    /* Reset on a rewind: keeps the ROM images, restarts the emulated MCU. */
    if (d->synth->isOpen()) d->synth->close();
    if (!d->synth->open(*d->ctrl, *d->pcm, DEFAULT_MAX_PARTIALS, AnalogOutputMode_ACCURATE))
        return 0;
    d->rate = d->synth->getStereoOutputSampleRate();
    g_capture_incr = ((int64_t)d->rate << MT32_FP) / MT32_NATIVE_RATE;
    d->mute_applied = 0;
    mt32_apply_params(d);
    mt32_send_bank(d);
    mt32_remap_channels(d);
    return 1;
}

static RewampDecoder* mt32_open(const char* path, RewampAudioFormat* outFormat) {
    RomFile* files = (RomFile*)calloc(MT32_MAX_ROM_FILES, sizeof(RomFile));   /* heap: see rom_status */
    if (!files) return NULL;
    int nfiles = mt32_scan_roms(files, MT32_MAX_ROM_FILES);
    RomSet set;
    if (nfiles == 0 || !mt32_select_set(files, nfiles, mt32_model_param(), &set)) { free(files); return NULL; }

    char clean[4096];
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strchr(clean, '?');
    if (q) *q = '\0';

    Mt32Dec* d = (Mt32Dec*)calloc(1, sizeof(Mt32Dec));
    if (!d) { free(files); return NULL; }
    d->set = set;

    d->events = tml_load_filename_ex(clean, &d->sysex);
    if (!d->events) { free(files); mt32_close((RewampDecoder*)d); return NULL; }
    d->next = d->events;

    unsigned lastMs = 0;
    int noteCount = 0, sysexCount = 0;
    unsigned usedChannels = 0;
    for (tml_message* m = d->events; m; m = m->next) {
        if (m->time > lastMs) lastMs = m->time;
        if (m->type == TML_NOTE_ON && m->velocity > 0) { noteCount++; usedChannels |= 1u << (m->channel & 15); }
        if (m->type == TML_SYSEX_MESSAGE) sysexCount++;
    }
    d->total_ms = lastMs + MT32_TAIL_MS;
    /* GM layout (see mt32_remap_channels): channel 1 in use, channel 9 free. */
    d->remap_gm = (usedChannels & 1u) && !(usedChannels & (1u << 8));

    /* ROM images. FileStreams must outlive the images (they reference the
     * mapped data), hence kept in the decoder. */
    int nf = 0;
    const RomSet* s = &set;
    {
        const int idx[4] = { s->ctrl1, s->ctrl2, s->pcm1, s->pcm2 };
        const ROMImage* img[4] = { NULL, NULL, NULL, NULL };
        for (int k = 0; k < 4; k++) {
            if (idx[k] < 0) continue;
            FileStream* fs = new FileStream();
            if (!fs->open(files[idx[k]].path)) { delete fs; free(files); mt32_close((RewampDecoder*)d); return NULL; }
            d->files[nf++] = fs;
            img[k] = ROMImage::makeROMImage(fs, ROMInfo::getAllROMInfos());
            if (!img[k]) { free(files); mt32_close((RewampDecoder*)d); return NULL; }
        }
        if (img[1]) { d->ctrlHalf[0] = img[0]; d->ctrlHalf[1] = img[1];
                      d->ctrl = ROMImage::mergeROMImages(img[0], img[1]); }
        else d->ctrl = img[0];
        if (img[3]) { d->pcmHalf[0] = img[2]; d->pcmHalf[1] = img[3];
                      d->pcm = ROMImage::mergeROMImages(img[2], img[3]); }
        else d->pcm = img[2];
        if (!d->ctrl || !d->pcm) { free(files); mt32_close((RewampDecoder*)d); return NULL; }
    }
    free(files);

    d->report = new RewampReportHandler();
    d->synth  = new Synth(d->report);
    g_lcd[0]  = '\0';

    /* Scope voices BEFORE the first render (§2.6). Nine fixed parts: the
     * MT-32's part layout does not depend on which channels the file uses. */
    rewamp_channel_data_reset(MT32_PARTS);
    rewamp_channel_data_set_ring_write_size(MT32_RING_SIZE);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip(set.isCm32l ? "CM-32L" : "MT-32", 0, MT32_PARTS);
    memset(g_acc, 0, sizeof(g_acc));
    g_capture_on = 1;
    for (int p = 0; p < MT32_PARTS; p++) { vgm_last_note[p] = 0; vgm_last_vol[p] = 0; vgm_last_instr[p] = 0; }
    memset(g_named_instr, 0, sizeof(g_named_instr));

    mt32_load_bank(d, clean);
    if (!mt32_open_synth(d)) { mt32_close((RewampDecoder*)d); return NULL; }
    d->total_frames = (uint64_t)d->total_ms * d->rate / 1000;

    for (int p = 0; p < MT32_PARTS; p++) {
        const char* pn = d->synth->getPatchName((Bit8u)p);
        char nm[MODIZ_VOICE_NAME_MAX_CHAR];
        if (p == 8) {
            snprintf(nm, sizeof(nm), "Rhythm");
            /* Le même nom pour l'INSTRUMENT de la partie: un kit, pas un
             * timbre — l'instrument y est porté par la touche. */
            rewamp_instrument_set_name((int)MT32_RHYTHM_INSTR, "Rhythm");
        }
        else if (pn && pn[0]) snprintf(nm, sizeof(nm), "%.*s", (int)sizeof(nm) - 1, pn);
        else snprintf(nm, sizeof(nm), "Part %d", p + 1);
        rewamp_voice_set_name(p, nm);
    }

    rewamp_track_message_append("Format: Standard MIDI (Roland MT-32)\n");
    rewamp_track_message_append("Synth: %s\n", set.ctrlName);
    rewamp_track_message_append("PCM: %s\n", set.pcmName);
    rewamp_track_message_append("Notes: %d\n", noteCount);
    if (sysexCount) rewamp_track_message_append("SysEx: %d\n", sysexCount);
    if (d->bank_count)
        rewamp_track_message_append("MT-32 bank: %s (%u sysex)\n", d->bank_name, d->bank_count);
    if (d->remap_gm) rewamp_track_message_append("Channels: GM layout (1-8 mapped to parts 1-8)\n");
    rewamp_track_message_append("Duration: %u:%02u\n", lastMs / 60000, (lastMs / 1000) % 60);

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = d->rate;
    }
    return (RewampDecoder*)d;
}

static uint64_t mt32_read(RewampDecoder* rd, float* out, uint64_t frameCount) {
    Mt32Dec* d = (Mt32Dec*)rd;
    if (d->next == NULL && d->out_pos >= d->total_frames) return 0;
    mt32_apply_mute(d);

    uint64_t done = 0;
    while (done < frameCount) {
        uint64_t remaining = frameCount - done;
        uint32_t nativeNow = d->synth->getInternalRenderedSampleCount();
        uint32_t nativeEnd = nativeNow + (uint32_t)(remaining * MT32_NATIVE_RATE / d->rate) + 1;

        /* Queue every event due inside this chunk, sample-accurately. A full
         * queue (dense sysex bursts) stops early: render up to that event,
         * then come back for the rest. */
        int full = 0;
        uint32_t stopAt = 0;
        while (d->next) {
            uint32_t ts = mt32_file_ts(d, d->next);
            if (ts >= nativeEnd) break;
            if (ts < nativeNow) ts = nativeNow;
            if (!mt32_enqueue(d, d->next, ts)) { full = 1; stopAt = ts; break; }
            mt32_note_prog(d, d->next);
            d->next = d->next->next;
        }
        uint64_t chunk = remaining;
        if (full) {
            chunk = (uint64_t)(stopAt - nativeNow) * d->rate / MT32_NATIVE_RATE;
            if (chunk == 0) chunk = 1;
            if (chunk > remaining) chunk = remaining;
        }
        /* Il reste des événements: le morceau n'est pas fini, même si cette
         * tranche est muette. Les premières secondes d'un MIDI MT-32 sont
         * exactement ça — la banque de timbres et la configuration du synthé
         * passent en sysex avant la première note, et le saut automatique des
         * silences avançait la file avant que la musique ne commence. Vaut
         * aussi quand la FILE du synthé est pleine: on ne dépile plus, on rend
         * du silence, et sans ce signal rien ne dirait qu'on travaille. */
        if (d->next != NULL) rewamp_decoder_activity();
        d->synth->render(out + done * 2, (Bit32u)chunk);
        done += chunk;
        d->out_pos += chunk;
        if (d->next == NULL && d->out_pos >= d->total_frames) break;
    }
    mt32_poll_notes(d);
    return done;
}

static void mt32_seek(RewampDecoder* rd, uint64_t frameIndex) {
    Mt32Dec* d = (Mt32Dec*)rd;
    uint64_t targetMs = frameIndex * 1000 / d->rate;
    if (frameIndex < d->out_pos) {
        /* Rewind = restart the emulated unit; the ROMs stay loaded. The synth
         * counter restarts at 0 while file timestamps keep counting from the
         * start: the offset realigns them at the target. */
        if (!mt32_open_synth(d)) return;
        d->next = d->events;
        for (int p = 0; p < MT32_PARTS; p++) { vgm_last_note[p] = 0; vgm_last_vol[p] = 0; }
        memset(d->chan_prog, 0, sizeof(d->chan_prog));
        /* Le synthé repart neuf: ses patches aussi, donc les noms mémorisés
         * ne décrivent plus rien. */
        memset(g_named_instr, 0, sizeof(g_named_instr));
    }
    /* Notes sounding at the departure point would never get their note-off
     * (the fast-forward skips notes): silence every channel first — a note
     * held for the rest of the piece is what a seek used to leave behind. */
    for (int ch = 0; ch < 16; ch++) {
        d->synth->playMsgNow(0xB0u | (Bit32u)ch | (123u << 8));   /* all notes off */
        d->synth->playMsgNow(0xB0u | (Bit32u)ch | (120u << 8));   /* all sound off */
    }
    /* Fast-forward: programs, controllers and SYSEX applied now, notes skipped —
     * a custom timbre loaded before the target must be there when we land. */
    while (d->next && d->next->time <= targetMs) {
        mt32_dispatch_now(d, d->next);
        mt32_note_prog(d, d->next);
        d->next = d->next->next;
    }
    d->out_pos = frameIndex;
    /* Realign: the event due at the target must play at the synth's NOW —
     * forward seeks left the synth counter at the departure point, and the
     * next 22 seconds of the file waited for 22 seconds of rendering. */
    d->ts_offset = (int64_t)targetMs * (MT32_NATIVE_RATE / 1000)
                 - (int64_t)d->synth->getInternalRenderedSampleCount();
}

static uint64_t mt32_length(RewampDecoder* rd) {
    Mt32Dec* d = (Mt32Dec*)rd;
    return d->total_frames;
}

static void mt32_close(RewampDecoder* rd) {
    Mt32Dec* d = (Mt32Dec*)rd;
    if (!d) return;
    g_capture_on = 0;
    if (d->synth) { if (d->synth->isOpen()) d->synth->close(); delete d->synth; }
    delete d->report;
    if (d->ctrlHalf[1]) { ROMImage::freeROMImage(d->ctrl); ROMImage::freeROMImage(d->ctrlHalf[0]); ROMImage::freeROMImage(d->ctrlHalf[1]); }
    else if (d->ctrl)   ROMImage::freeROMImage(d->ctrl);
    if (d->pcmHalf[1])  { ROMImage::freeROMImage(d->pcm); ROMImage::freeROMImage(d->pcmHalf[0]); ROMImage::freeROMImage(d->pcmHalf[1]); }
    else if (d->pcm)    ROMImage::freeROMImage(d->pcm);
    for (int i = 0; i < 4; i++) if (d->files[i]) { d->files[i]->close(); delete d->files[i]; }
    if (d->events) tml_free(d->events);
    if (d->sysex)  tml_sysex_free(d->sysex);
    free(d->bank);
    free(d);
}

/* Live settings (Settings → Moteurs → MT-32): reverb / gain now; the model
 * choice needs a reload and is read at the next open(). */
static void mt32_param_changed(RewampDecoder* rd, const char* key) {
    (void)key;
    Mt32Dec* d = (Mt32Dec*)rd;
    if (d) mt32_apply_params(d);
}

static const RewampPluginVTable g_mt32_vtable = {
    "mt32",
    mt32_probe,
    mt32_open,
    mt32_read,
    mt32_seek,
    mt32_length,
    mt32_close,
    NULL,                 /* configure_loop: generic (Dart) loop path */
    0,                    /* supportsNativeFadeout */
    "mt32",               /* engine_id */
    mt32_param_changed,   /* live settings */
    NULL, NULL, NULL, NULL, NULL,   /* pattern_* : MIDI has no tracker grid */
    mt32_probe_path,      /* probe_path: sysex sniff needs the whole file */
    1,                    /* noPrefixProbe */
};

extern "C" const RewampPluginVTable* rewamp_mt32_plugin(void) {
    return &g_mt32_vtable;
}
