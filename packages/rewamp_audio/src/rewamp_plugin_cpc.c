/* Amstrad CPC 6128 plugin — plays a .dsk by RUNNING it on an emulated CPC.
 * Compiled only when REWAMP_WITH_CPC is defined.
 *
 * A CPC music disk is a PROGRAM, not a tune file: a player routine that pokes
 * the AY-3-8912 through the 8255, very often through the firmware (Arkos
 * Tracker players print their credits with TXT OUTPUT, set the screen mode…).
 * Nothing short of the whole machine plays it, so this is floooh/chips' CPC
 * (Z80, gate array, CRTC, 8255, AY, uPD765 + the real 6128 ROMs), driven the
 * way a person would: boot, type RUN"<file>, listen.
 *
 * What the plugin adds around the emulator:
 *  - it reads the disk's CATALOGUE itself to decide what to RUN (a loader
 *    named like one, else the only BASIC/binary file, else |CPM on a system
 *    disk) — see cpc_pick_program;
 *  - boot, typing and disk loading run SILENTLY and as fast as the host can
 *    go (≈35× real time on a laptop), until the first audible sample: a disk
 *    loads for seconds before its music starts, and that wait is not music;
 *  - stereo the CPC way (A left, B centre, C right) and per-voice scopes,
 *    from the PSG patch in third_party/chips (ay38910_t.rw_chn — the chip
 *    averaged over each output sample instead of point-sampled);
 *  - seek FORWARD = keep running from where we are (discard-render); seek
 *    BACKWARD = restore the snapshot taken when the sound started, then
 *    discard-render up to the target;
 *  - the text the program prints during that start goes to the ⓘ panel.
 *
 * The tune never ends on its own (a player loops), so length() is 0 and the
 * generic Dart loop path applies, like SID. */
#ifdef REWAMP_WITH_CPC

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"
#include "ModizerConstants.h"

#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>

/* Every non-static chips symbol gets an rwcpc_ prefix: nez has a z80_tick of
 * its own, and mem_init / kbd_init / fdd_read are names waiting to collide. */
#include "rewamp_chips_rename.h"
#define CHIPS_IMPL
#define CHIPS_ASSERT(c) ((void)0)
#include "chips/chips_common.h"
#include "chips/z80.h"
#include "chips/ay38910.h"
#include "chips/i8255.h"
#include "chips/mc6845.h"
#include "chips/am40010.h"
#include "chips/upd765.h"
#include "chips/kbd.h"
#include "chips/clk.h"
#include "chips/mem.h"
#include "chips/fdd.h"
#include "chips/fdd_cpc.h"
#include "systems/cpc.h"
#include "rewamp_cpc6128_roms.h"

#define CPC_RATE        44100
#define CPC_VOICES      3
#define CPC_FIFO_FRAMES 8192
#define CPC_SCOPE_RING  (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)   /* 4096, PLUGINS.md §2.3 */
/* Boot: the 6128 firmware reaches BASIC's Ready after ≈0.9 s emulated; keys
 * typed earlier are LOST (measured in the harness: 0.8 s → the command never
 * runs, 0.9 s → it does). 1.2 s for margin — it costs ~40 ms of host CPU.
 * Same story for the key timing: 25 ms per press drops characters, 40 ms
 * does not. */
#ifndef CPC_BOOT_US
#define CPC_BOOT_US     1200000u
#endif
#ifndef CPC_KEY_US
#define CPC_KEY_US      40000u
#endif
/* Longest a program may stay silent after RUN before we give up skipping and
 * just play what it does (an intro without music, a very slow loader). */
#define CPC_MAX_SKIP_US 40000000u
#define CPC_SKIP_STEP_US 10000u
#define CPC_SILENCE     0.004f
#define CPC_GAIN        0.7f
#define CPC_TEXT_MAX    1024

struct RewampDecoder {
    cpc_t*   sys;
    cpc_t*   snap;              /* state when the sound started (seek origin) */
    float*   fifo;              /* interleaved stereo */
    int      fifo_frames;
    uint64_t pos;               /* frames read() has returned since the start */
    bool     discard;           /* preroll: samples go nowhere */
    /* the 10 ms step in which the sound started: kept, so a seek to before
     * the snapshot still returns those frames */
    float*   head;
    int      head_frames;
    /* DC blockers: output L/R + one per voice for the scopes */
    float    dc_x[2], dc_y[2];
    float    vdc_x[CPC_VOICES], vdc_y[CPC_VOICES];
    int64_t  last_mute;
    char     cmd[24];
    /* text printed by the program (TXT OUTPUT) during the start */
    char     text[CPC_TEXT_MAX];
    int      text_len;
    int      ctrl_skip;         /* parameter bytes of a control code still due */
};

/* ── DSK reading (standard "MV - CPC" and "EXTENDED CPC DSK") ───────────── */

typedef struct {
    const uint8_t* d;
    size_t n;
    int tracks, sides, extended;
} Dsk;

static bool dsk_open(Dsk* k, const uint8_t* d, size_t n) {
    memset(k, 0, sizeof(*k));
    if (n < 0x100) return false;
    if (memcmp(d, "EXTENDED CPC DSK", 16) == 0) k->extended = 1;
    else if (memcmp(d, "MV - CPC", 8) != 0) return false;
    k->d = d; k->n = n;
    k->tracks = d[0x30];
    k->sides  = d[0x31] ? d[0x31] : 1;
    return k->tracks > 0;
}

/* Offset of track `t` (side 0) in the image, or 0. */
static size_t dsk_track(const Dsk* k, int t) {
    size_t off = 0x100;
    const int idx = t * k->sides;
    for (int i = 0; i < idx; i++) {
        size_t sz = k->extended ? (size_t)k->d[0x34 + i] * 256
                                : (size_t)(k->d[0x32] | (k->d[0x33] << 8));
        off += sz;
    }
    if (off + 0x100 > k->n) return 0;
    if (memcmp(k->d + off, "Track-Info", 10) != 0) return 0;
    return off;
}

/* Sector with id `r` on track `t`; NULL if absent. */
static const uint8_t* dsk_sector(const Dsk* k, int t, uint8_t r, int* len) {
    const size_t off = dsk_track(k, t);
    if (!off) return NULL;
    const uint8_t* ti = k->d + off;
    const int nsec = ti[0x15];
    size_t p = off + 0x100;
    for (int s = 0; s < nsec && s < 29; s++) {
        const uint8_t* si = ti + 0x18 + 8 * s;
        size_t ln = k->extended ? (size_t)(si[6] | (si[7] << 8))
                                : (size_t)(128u << (si[3] & 7));
        if (p + ln > k->n) return NULL;
        if (si[2] == r) { if (len) *len = (int)ln; return k->d + p; }
        p += ln;
    }
    return NULL;
}

/* First sector id of track 0: 0xC1 = DATA format, 0x41 = SYSTEM (CP/M). */
static int dsk_first_id(const Dsk* k) {
    const size_t off = dsk_track(k, 0);
    if (!off || k->d[off + 0x15] == 0) return -1;
    int lo = 0x100;
    for (int s = 0; s < k->d[off + 0x15] && s < 29; s++) {
        int r = k->d[off + 0x18 + 8 * s + 2];
        if (r < lo) lo = r;
    }
    return lo;
}

typedef struct {
    char name[9];
    char ext[4];
    bool hidden;
} CpcFile;

/* The AMSDOS directory: 64 entries, first extent of each user-0 file. */
static int dsk_catalogue(const Dsk* k, CpcFile* out, int max, int* format) {
    const int first = dsk_first_id(k);
    int track, base;
    if ((first & 0xF0) == 0xC0)      { track = 0; base = 0xC1; *format = 'D'; }
    else if ((first & 0xF0) == 0x40) { track = 2; base = 0x41; *format = 'S'; }
    else { *format = '?'; return 0; }
    uint8_t dir[2048];
    for (int i = 0; i < 4; i++) {
        int len = 0;
        const uint8_t* s = dsk_sector(k, track, (uint8_t)(base + i), &len);
        if (!s || len < 512) return 0;
        memcpy(dir + 512 * i, s, 512);
    }
    int n = 0;
    for (int e = 0; e < 64 && n < max; e++) {
        const uint8_t* ent = dir + 32 * e;
        if (ent[0] != 0) continue;           /* deleted (E5) or other user */
        if (ent[12] != 0) continue;          /* not the first extent */
        CpcFile f;
        memset(&f, 0, sizeof(f));
        int j = 0;
        for (int i = 1; i <= 8; i++) {
            char c = (char)(ent[i] & 0x7F);
            if (c != ' ') f.name[j++] = c;
        }
        j = 0;
        for (int i = 9; i <= 11; i++) {
            char c = (char)(ent[i] & 0x7F);
            if (c != ' ') f.ext[j++] = c;
        }
        f.hidden = (ent[10] & 0x80) != 0;    /* AMSDOS "system" attribute */
        if (!f.name[0]) continue;
        bool dup = false;
        for (int i = 0; i < n; i++)
            if (!strcmp(out[i].name, f.name) && !strcmp(out[i].ext, f.ext)) dup = true;
        if (!dup) out[n++] = f;
    }
    return n;
}

static bool name_is(const char* s, const char* w) {
    for (; *s && *w; s++, w++)
        if (toupper((unsigned char)*s) != *w) return false;
    return *w == 0;
}

/* What to RUN. A disk's own boot convention first (a file named like a
 * loader), then the only program on it, then the first BASIC, the first
 * binary. Hidden files are data (AMSDOS "system" attribute) and only count
 * when nothing else is there. Returns the command to type, or false. */
static bool cpc_pick_program(const Dsk* k, char* cmd, size_t cmdsz,
                             char* listing, size_t listsz) {
    CpcFile files[64];
    int format = 0;
    const int n = dsk_catalogue(k, files, 64, &format);
    listing[0] = 0;
    for (int i = 0; i < n; i++) {
        size_t l = strlen(listing);
        snprintf(listing + l, listsz - l, "%s%s%s%s", l ? ", " : "",
                 files[i].name, files[i].ext[0] ? "." : "", files[i].ext);
    }
    int best = -1, bestScore = 0;
    for (int pass = 0; pass < 2 && best < 0; pass++) {
        for (int i = 0; i < n; i++) {
            const CpcFile* f = &files[i];
            if (f->hidden != (pass == 1)) continue;
            int sc = 0;
            if (name_is(f->ext, "BAS") || f->ext[0] == 0) sc = 3;
            else if (name_is(f->ext, "BIN")) sc = 2;
            else continue;
            static const char* const kLoaders[] = {
                "DISC", "DISK", "MENU", "LOADER", "BOOT", "START", "RUN",
                "INTRO", "DEMO", "MUSIC", NULL };
            for (int w = 0; kLoaders[w]; w++)
                if (name_is(f->name, kLoaders[w])) sc += 10;
            if (f->name[0] == '-') sc += 10;  /* "-NAME" = run me first */
            if (sc > bestScore) { bestScore = sc; best = i; }
        }
    }
    if (best >= 0) {
        snprintf(cmd, cmdsz, "run\"%s%s%s\r", files[best].name,
                 files[best].ext[0] ? "." : "", files[best].ext);
        return true;
    }
    if (format == 'S') { snprintf(cmd, cmdsz, "|cpm\r"); return true; }
    return false;
}

/* ── emulator callbacks ─────────────────────────────────────────────────── */

static inline float dc_block(float x, float* px, float* py) {
    /* one-pole high-pass ≈ 7 Hz: the AY output is a positive level */
    const float y = x - *px + 0.999f * *py;
    *px = x; *py = y;
    return y;
}

static void cpc_psg_sample(void* user, const ay38910_t* psg) {
    struct RewampDecoder* dec = (struct RewampDecoder*)user;
    const float a = psg->rw_chn[0], b = psg->rw_chn[1], c = psg->rw_chn[2];
    const float l = dc_block(a + 0.5f * b, &dec->dc_x[0], &dec->dc_y[0]) * CPC_GAIN;
    const float r = dc_block(c + 0.5f * b, &dec->dc_x[1], &dec->dc_y[1]) * CPC_GAIN;
    if (dec->fifo_frames < CPC_FIFO_FRAMES) {
        dec->fifo[2 * dec->fifo_frames]     = l;
        dec->fifo[2 * dec->fifo_frames + 1] = r;
        dec->fifo_frames++;
    }
    if (dec->discard) return;
    for (int v = 0; v < CPC_VOICES; v++) {
        float s = dc_block(psg->rw_chn[v], &dec->vdc_x[v], &dec->vdc_y[v]);
        int q = (int)(s * 220.0f);
        if (m_voice_buff[v])
            m_voice_buff[v][(m_voice_current_ptr[v] >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT)
                            & (CPC_SCOPE_RING - 1)] = (signed char)LIMIT8(q);
        m_voice_current_ptr[v] += 1 << MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
    }
}

/* Parameter bytes following each CPC text control code (firmware manual,
 * TXT OUTPUT): they are not characters and must not reach the panel. */
static const uint8_t kCtrlParams[32] = {
    0,1,0,0,1,1,0,0, 0,0,0,0,0,0,1,1, 0,0,0,0,0,0,1,1, 0,9,4,0,3,2,0,2 };

static void cpc_txt_out(void* user, uint8_t ch) {
    struct RewampDecoder* dec = (struct RewampDecoder*)user;
    if (dec->ctrl_skip > 0) { dec->ctrl_skip--; return; }
    if (dec->text_len >= CPC_TEXT_MAX - 2) return;
    if (ch < 32) {
        if (ch == 10 || ch == 13) {
            if (dec->text_len && dec->text[dec->text_len - 1] != '\n')
                dec->text[dec->text_len++] = '\n';
        } else {
            dec->ctrl_skip = kCtrlParams[ch];
        }
        return;
    }
    if (ch >= 127) return;                    /* CPC graphic characters */
    if (ch == ' ' && dec->text_len && (dec->text[dec->text_len - 1] == ' '
                                       || dec->text[dec->text_len - 1] == '\n'))
        return;
    dec->text[dec->text_len++] = (char)ch;
    dec->text[dec->text_len] = 0;
}

/* ── running the machine ────────────────────────────────────────────────── */

static void run_us(struct RewampDecoder* dec, uint32_t us) {
    while (us > 0) {
        const uint32_t step = us > 20000 ? 20000 : us;
        /* never overflow the FIFO: drop what a silent preroll produced */
        if (dec->discard) dec->fifo_frames = 0;
        cpc_exec(dec->sys, step);
        us -= step;
    }
}

static void type_text(struct RewampDecoder* dec, const char* s) {
    for (; *s; s++) {
        cpc_key_down(dec->sys, (unsigned char)*s);
        run_us(dec, CPC_KEY_US);
        cpc_key_up(dec->sys, (unsigned char)*s);
        run_us(dec, CPC_KEY_US);
        /* A DOUBLED letter (RUN"GINFIZZ) needs the key seen UP for longer:
         * after 40 ms the firmware still took the second Z for the first one
         * held and typed "GINFIZ" (measured: 60 ms works, 80 ms kept). */
        if (s[1] == s[0]) run_us(dec, CPC_KEY_US);
    }
}

static bool fifo_audible(const struct RewampDecoder* dec) {
    for (int i = 0; i < dec->fifo_frames * 2; i++) {
        const float v = dec->fifo[i];
        if (v > CPC_SILENCE || v < -CPC_SILENCE) return true;
    }
    return false;
}

/* ── probe / open ───────────────────────────────────────────────────────── */

static int cpc_probe(const char* ext, const uint8_t* hdr, size_t hdrSize) {
    if (hdrSize >= 16 && memcmp(hdr, "EXTENDED CPC DSK", 16) == 0) return 95;
    if (hdrSize >= 8 && memcmp(hdr, "MV - CPC", 8) == 0) return 95;
    (void)ext;   /* .dsk is also Apple II, Atari ST, MSX…: the magic decides */
    return 0;
}

static void cpc_close(RewampDecoder* dec);

static RewampDecoder* cpc_open(const char* path, RewampAudioFormat* outFormat) {
    /* strip ?subsong= (one program per disk for now) */
    char fpath[4096];
    snprintf(fpath, sizeof(fpath), "%s", path);
    char* q = strstr(fpath, "?subsong=");
    if (q) *q = 0;

    FILE* f = fopen(fpath, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (sz <= 0 || sz > (long)FDD_MAX_DISC_SIZE + 0x10000) { fclose(f); return NULL; }
    uint8_t* dsk = (uint8_t*)malloc((size_t)sz);
    if (!dsk || fread(dsk, 1, (size_t)sz, f) != (size_t)sz) { fclose(f); free(dsk); return NULL; }
    fclose(f);

    Dsk k;
    char listing[512];
    struct RewampDecoder* dec = (struct RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec || !dsk_open(&k, dsk, (size_t)sz)
        || !cpc_pick_program(&k, dec->cmd, sizeof(dec->cmd), listing, sizeof(listing))) {
        free(dsk); free(dec);
        return NULL;
    }
    dec->sys  = (cpc_t*)calloc(1, sizeof(cpc_t));
    dec->snap = (cpc_t*)calloc(1, sizeof(cpc_t));
    dec->fifo = (float*)calloc(CPC_FIFO_FRAMES * 2, sizeof(float));
    dec->head = (float*)calloc(CPC_FIFO_FRAMES * 2, sizeof(float));
    if (!dec->sys || !dec->snap || !dec->fifo || !dec->head) {
        free(dsk); cpc_close(dec); return NULL;
    }

    cpc_init(dec->sys, &(cpc_desc_t){
        .type  = CPC_TYPE_6128,
        .audio = { .sample_rate = CPC_RATE, .volume = 1.0f },
        .roms.cpc6128 = {
            .os     = { .ptr = (void*)rw_cpc6128_os,     .size = sizeof(rw_cpc6128_os) },
            .basic  = { .ptr = (void*)rw_cpc6128_basic,  .size = sizeof(rw_cpc6128_basic) },
            .amsdos = { .ptr = (void*)rw_cpc6128_amsdos, .size = sizeof(rw_cpc6128_amsdos) },
        },
    });
    dec->sys->rw_psg_sample = cpc_psg_sample;
    dec->sys->rw_psg_user   = dec;
    /* the drive keeps its own copy of the image */
    const bool inserted = cpc_insert_disc(dec->sys, (chips_range_t){ .ptr = dsk, .size = (size_t)sz });
    free(dsk);
    if (!inserted) { cpc_close(dec); return NULL; }

    /* Voice data BEFORE the first emulated sample (PLUGINS.md §2.6). */
    rewamp_channel_data_reset(CPC_VOICES);
    rewamp_channel_data_set_ring_write_size(CPC_SCOPE_RING);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("AY-3-8912", 0, CPC_VOICES);
    rewamp_voice_set_name(0, "A (left)");
    rewamp_voice_set_name(1, "B (centre)");
    rewamp_voice_set_name(2, "C (right)");

    /* Boot, type, load: silent and as fast as the host goes. */
    dec->discard = true;
    run_us(dec, CPC_BOOT_US);
    type_text(dec, dec->cmd);
    dec->sys->rw_txt_out = cpc_txt_out;
    uint32_t waited = 0;
    for (;;) {
        /* the state BEFORE this step is the seek origin if it turns audible */
        dec->fifo_frames = 0;
        cpc_exec(dec->sys, CPC_SKIP_STEP_US);
        waited += CPC_SKIP_STEP_US;
        if (fifo_audible(dec) || waited >= CPC_MAX_SKIP_US) break;
    }
    dec->sys->rw_txt_out = NULL;            /* off the hot path from here */
    /* This step's frames start the tune; the machine state after it is the
     * snapshot a seek restores (frames before it come from `head`). */
    memcpy(dec->head, dec->fifo, (size_t)dec->fifo_frames * 2 * sizeof(float));
    dec->head_frames = dec->fifo_frames;
    cpc_save_snapshot(dec->sys, dec->snap);
    dec->discard = false;

    /* ⓘ panel */
    rewamp_track_message_append("Format: Amstrad CPC disk image (DSK)\n");
    rewamp_track_message_append("Machine: CPC 6128 (emulated, floooh/chips)\n");
    {
        char shown[24];
        snprintf(shown, sizeof(shown), "%s", dec->cmd);
        char* cr = strchr(shown, '\r');
        if (cr) *cr = 0;
        for (char* p = shown; *p; p++) *p = (char)toupper((unsigned char)*p);
        rewamp_track_message_append("Runs: %s\n", shown);
    }
    if (listing[0]) rewamp_track_message_append("Disk: %s\n", listing);
    if (waited > CPC_SKIP_STEP_US)
        rewamp_track_message_append("Loading skipped: %.1f s\n", waited / 1e6);
    if (dec->text_len > 0) {
        while (dec->text_len && (dec->text[dec->text_len - 1] == '\n'
                                 || dec->text[dec->text_len - 1] == ' '))
            dec->text[--dec->text_len] = 0;
        if (dec->text_len)
            rewamp_track_message_append("\nOn screen:\n%s\n", dec->text);
    }

    dec->last_mute = -1;
    outFormat->channels   = 2;
    outFormat->sampleRate = CPC_RATE;
    return dec;
}

/* ── read / seek ────────────────────────────────────────────────────────── */

static void cpc_capture_notes(struct RewampDecoder* dec) {
    const ay38910_t* psg = &dec->sys->psg;
    for (int v = 0; v < CPC_VOICES; v++) {
        const int period = ((psg->reg[2 * v + 1] & 0x0F) << 8) | psg->reg[2 * v];
        const int tone_on = !((psg->reg[AY38910_REG_ENABLE] >> v) & 1);
        const uint8_t amp = psg->reg[AY38910_REG_AMP_A + v];
        const int vol = (amp & 0x10) ? 15 : (amp & 0x0F);
        const bool muted = (generic_mute_mask >> v) & 1;
        /* CPC AY clock: 1 MHz; tone = clock / (16 × period) */
        vgm_last_note[v] = (tone_on && vol && period && !muted)
                         ? (unsigned int)(1000000 / (16 * period)) : 0;
        vgm_last_vol[v]  = (tone_on && !muted) ? (unsigned int)(vol * 255 / 15) : 0;
    }
}

static uint64_t cpc_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->sys || frameCount == 0) return 0;
    if (dec->last_mute != generic_mute_mask) {
        dec->last_mute = generic_mute_mask;
        dec->sys->psg.rw_mute = (uint32_t)(generic_mute_mask & 7);
    }
    uint64_t written = 0;
    while (written < frameCount) {
        if (dec->fifo_frames == 0) {
            /* enough emulated time for the rest, bounded by the FIFO */
            uint64_t want = frameCount - written;
            if (want > CPC_FIFO_FRAMES / 2) want = CPC_FIFO_FRAMES / 2;
            uint32_t us = (uint32_t)(want * 1000000ull / CPC_RATE) + 1;
            cpc_exec(dec->sys, us);
            if (dec->fifo_frames == 0) continue;
        }
        int take = (int)(frameCount - written);
        if (take > dec->fifo_frames) take = dec->fifo_frames;
        memcpy(out + written * 2, dec->fifo, (size_t)take * 2 * sizeof(float));
        const int remain = dec->fifo_frames - take;
        if (remain > 0)
            memmove(dec->fifo, dec->fifo + take * 2, (size_t)remain * 2 * sizeof(float));
        dec->fifo_frames = remain;
        written += (uint64_t)take;
    }
    cpc_capture_notes(dec);
    dec->pos += written;
    return written;
}

/* Seek thread contract (rewamp_audio.c): publish progress, honour cancel. */
extern volatile int    g_seek_cancel;
extern volatile double g_seek_progress_s;

/* Emulate and throw away [skip] frames, starting with what the FIFO holds.
 * Returns the frames NOT skipped (non-zero only on cancel). */
static uint64_t cpc_skip_frames(struct RewampDecoder* dec, uint64_t target,
                                uint64_t skip) {
    dec->discard = true;                     /* no scope writes while skipping */
    while (skip > 0 && !g_seek_cancel) {
        if (dec->fifo_frames == 0) {
            uint64_t chunk = skip > CPC_FIFO_FRAMES / 2 ? CPC_FIFO_FRAMES / 2 : skip;
            cpc_exec(dec->sys, (uint32_t)(chunk * 1000000ull / CPC_RATE) + 1);
            if (dec->fifo_frames == 0) break;
        }
        if ((uint64_t)dec->fifo_frames > skip) {
            /* keep what overshot the target */
            const int keep = dec->fifo_frames - (int)skip;
            memmove(dec->fifo, dec->fifo + skip * 2, (size_t)keep * 2 * sizeof(float));
            dec->fifo_frames = keep;
            skip = 0;
        } else {
            skip -= (uint64_t)dec->fifo_frames;
            dec->fifo_frames = 0;
        }
        g_seek_progress_s = (double)(target - skip) / CPC_RATE;
    }
    dec->discard = false;
    return skip;
}

static void cpc_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->sys) return;
    /* FORWARD: the machine is already on the way — restarting from the
     * snapshot made every forward seek re-emulate the whole tune so far. */
    if (frameIndex >= dec->pos) {
        const uint64_t left = cpc_skip_frames(dec, frameIndex, frameIndex - dec->pos);
        dec->pos = frameIndex - left;
        return;
    }
    cpc_load_snapshot(dec->sys, CPC_SNAPSHOT_VERSION, dec->snap);
    dec->sys->rw_psg_sample = cpc_psg_sample;
    dec->sys->rw_txt_out    = NULL;
    dec->sys->rw_psg_user   = dec;
    dec->sys->psg.rw_mute   = (uint32_t)(generic_mute_mask & 7);
    dec->last_mute          = generic_mute_mask;
    dec->fifo_frames = 0;
    if (frameIndex < (uint64_t)dec->head_frames) {
        const int n = dec->head_frames - (int)frameIndex;
        memcpy(dec->fifo, dec->head + frameIndex * 2, (size_t)n * 2 * sizeof(float));
        dec->fifo_frames = n;
        dec->pos = frameIndex;
        return;
    }
    const uint64_t left = cpc_skip_frames(dec, frameIndex,
                                          frameIndex - (uint64_t)dec->head_frames);
    dec->pos = frameIndex - left;
}

static uint64_t cpc_length(RewampDecoder* dec) {
    (void)dec;
    return 0;   /* a player loops forever: generic loop path */
}

static void cpc_close(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->sys) cpc_discard(dec->sys);
    free(dec->sys);
    free(dec->snap);
    free(dec->fifo);
    free(dec->head);
    free(dec);
}

static const RewampPluginVTable kCpcVTable = {
    "cpc",
    cpc_probe,
    cpc_open,
    cpc_read,
    cpc_seek,
    cpc_length,
    cpc_close,
    NULL,                         /* configure_loop: generic (plays forever) */
    0,                            /* supportsNativeFadeout */
    "cpc",                        /* engine_id */
    NULL,                         /* param_changed */
    NULL, NULL, NULL, NULL, NULL, /* pattern view */
    NULL, 0,                      /* probe_path, noPrefixProbe */
    NULL,                         /* set_speed: generic resampling */
};

const RewampPluginVTable* rewamp_cpc_plugin(void) { return &kCpcVTable; }

#endif /* REWAMP_WITH_CPC */
