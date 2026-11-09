/* ZX Spectrum plugin — plays a .tap by RUNNING it on an emulated Spectrum.
 * Compiled only when REWAMP_WITH_ZXSPECTRUM is defined.
 *
 * A tape from a party's ZX music compo is a PROGRAM, not a tune file: a BASIC
 * loader and machine code, often packed, that plays the AY of the 128K or —
 * the whole "beeper" category — toggles the 1-bit speaker from the CPU in a
 * timed loop. No module format survives that (zxtune finds nothing in them),
 * so this is floooh/chips' Spectrum (Z80, ULA, beeper, AY-3-8912, the real
 * Amstrad/Sinclair ROMs), driven the way a person would: power on, LOAD "",
 * listen.
 *
 * What the plugin adds around the emulator:
 *  - the TAPE is not emulated: the ROM's LD-BYTES routine (0x0556) is TRAPPED
 *    and each block of the .tap copied straight into memory (rw_m1 hook in
 *    systems/zx.h, the classic emulator trick: a standard-speed tape loads in
 *    no time). Custom turbo loaders cannot be expressed in a .tap anyway;
 *  - the machine is chosen by the program: it starts on a 128K (the menu's
 *    "Tape Loader"); if the program never writes the AY, it is BEEPER music
 *    and is run again on a 48K — beeper pitch and tempo are counted in CPU
 *    T-states, and the 128K's clock is 1.3 % faster than the 48K's;
 *  - power-on, loading and the program's own unpacking run SILENTLY and as
 *    fast as the host can go, until the first audible sample;
 *  - stereo ABC for the AY (A left, B centre, C right, the ZX scene's
 *    convention), the beeper in the centre; per-voice scopes and mutes;
 *  - seek FORWARD = keep running; seek BACKWARD = restore the snapshot taken
 *    when the sound started (tape position included), then discard-render;
 *  - what the program PRINTs through the ROM (RST 10h) during the start goes
 *    to the ⓘ panel, with the tape's file names.
 *
 * A program plays forever, so length() is 0 and the generic Dart loop path
 * applies, like SID and the CPC. */
#ifdef REWAMP_WITH_ZXSPECTRUM

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
#include <strings.h>

/* Same prefixing as the CPC plugin (rwcpc_*). The chips CORE (Z80, AY, kbd,
 * clk, mem) is implemented ONCE: in the CPC plugin's TU when that one is
 * built, here otherwise. beeper.h and zx.h are only ever implemented here. */
#include "rewamp_chips_rename.h"
#define CHIPS_ASSERT(c) ((void)0)
#ifndef REWAMP_WITH_CPC
#define CHIPS_IMPL
#endif
#include "chips/chips_common.h"
#include "chips/z80.h"
#include "chips/ay38910.h"
#include "chips/kbd.h"
#include "chips/clk.h"
#include "chips/mem.h"
#ifndef CHIPS_IMPL
#define CHIPS_IMPL
#endif
#include "chips/beeper.h"
#include "systems/zx.h"
#include "rewamp_zx_roms.h"

#define ZX_RATE         44100
#define ZX_AY_VOICES    3
#define ZX_VOICES       4             /* AY A, B, C + beeper */
#define ZX_BEEPER_VOICE 3
#define ZX_FIFO_FRAMES  8192
#define ZX_SCOPE_RING   (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)
/* Power-on until the ROM listens to the keyboard. Measured in the harness:
 * see the numbers next to the constants in docs/ENGINES.md (ZXSPECTRUM). */
#ifndef ZX_BOOT48_US
#define ZX_BOOT48_US    2500000u
#endif
#ifndef ZX_BOOT128_US
#define ZX_BOOT128_US   2500000u
#endif
#ifndef ZX_KEY_US
#define ZX_KEY_US       60000u
#endif
#define ZX_MAX_SKIP_US  40000000u
#define ZX_SKIP_STEP_US 10000u
#define ZX_SILENCE      0.004f
#define ZX_GAIN         0.7f
#define ZX_BEEPER_GAIN  1.0f
#define ZX_TEXT_MAX     1024
#define ZX_MAX_BLOCKS   256

typedef struct { uint32_t off, len; } TapBlock;   /* len includes flag + checksum */

struct RewampDecoder {
    zx_t*    sys;
    zx_t*    snap;              /* state when the sound started (seek origin) */
    int      snap_tap_next;
    float*   fifo;              /* interleaved stereo */
    int      fifo_frames;
    uint64_t pos;               /* frames read() has returned since the start */
    bool     discard;
    float*   head;
    int      head_frames;
    float    dc_x[2], dc_y[2];
    float    vdc_x[ZX_VOICES], vdc_y[ZX_VOICES];
    /* which source is AUDIBLE (beeper vs AY): energy since the last reset,
     * after their own DC filters — a register write proves nothing, the 128K
     * ROM writes the AY itself */
    float    e_ay, e_bp;
    float    edc_x[2], edc_y[2];
    int64_t  last_mute;
    bool     beeper_muted;
    /* the tape */
    uint8_t* tap;
    size_t   tap_size;
    TapBlock blocks[ZX_MAX_BLOCKS];
    int      nblocks;
    int      tap_next;
    int      tap_loads;         /* blocks actually loaded by the trap */
    /* PRINT capture */
    bool     capture_text;
    char     text[ZX_TEXT_MAX];
    int      text_len;
    int      ctrl_skip;
};

/* ── TAP ────────────────────────────────────────────────────────────────── */

/* A .tap is a chain of [u16 length][flag][data…][xor checksum] blocks that
 * must end exactly at the end of the file. `strict` also wants every
 * checksum right (the probe); open() tolerates a bad one, as the ROM would
 * report "Tape loading error" for that block only. */
static int tap_parse(const uint8_t* d, size_t n, TapBlock* out, int max, bool strict) {
    size_t p = 0;
    int k = 0;
    while (p < n) {
        if (p + 2 > n) return 0;
        const uint32_t len = (uint32_t)d[p] | ((uint32_t)d[p + 1] << 8);
        p += 2;
        if (len < 2 || p + len > n) return 0;
        if (strict) {
            uint8_t x = 0;
            for (uint32_t i = 0; i < len; i++) x ^= d[p + i];
            if (x != 0) return 0;
        }
        if (k < max) { out[k].off = (uint32_t)p; out[k].len = len; }
        k++;
        p += len;
    }
    return k <= max ? k : 0;
}

/* "Program: Caffeine, Bytes: caffeine1" from the 19-byte headers. */
static void tap_listing(const struct RewampDecoder* dec, char* out, size_t outsz) {
    out[0] = 0;
    for (int i = 0; i < dec->nblocks; i++) {
        const uint8_t* b = dec->tap + dec->blocks[i].off;
        if (dec->blocks[i].len != 19 || b[0] != 0x00) continue;
        static const char* const kType[] = { "Program", "Number array",
                                             "Character array", "Bytes" };
        char name[11];
        int j = 0;
        for (int c = 0; c < 10; c++) {
            const uint8_t ch = b[2 + c];
            name[j++] = (ch >= 32 && ch < 127) ? (char)ch : '?';
        }
        while (j && name[j - 1] == ' ') j--;
        name[j] = 0;
        const size_t l = strlen(out);
        snprintf(out + l, outsz - l, "%s%s: %s", l ? ", " : "",
                 b[1] < 4 ? kType[b[1]] : "?", name);
    }
}

/* ── emulator hooks ─────────────────────────────────────────────────────── */

static inline float dc_block(float x, float* px, float* py) {
    const float y = x - *px + 0.999f * *py;
    *px = x; *py = y;
    return y;
}

static void zxs_on_sample(void* user, const void* vsys) {
    struct RewampDecoder* dec = (struct RewampDecoder*)user;
    const zx_t* sys = (const zx_t*)vsys;
    float a = 0.0f, b = 0.0f, c = 0.0f;
    if (sys->type == ZX_TYPE_128) {
        a = sys->ay.rw_chn[0]; b = sys->ay.rw_chn[1]; c = sys->ay.rw_chn[2];
    }
    /* beeper.sample = mean of the 1-bit state over the last 128 CPU ticks
     * (chips/beeper.h), 0..base_volume (1.0 here) */
    const float bp = dec->beeper_muted ? 0.0f : sys->beeper.sample;
    {
        const float ea = dc_block(a + b + c, &dec->edc_x[0], &dec->edc_y[0]);
        const float eb = dc_block(sys->beeper.sample, &dec->edc_x[1], &dec->edc_y[1]);
        dec->e_ay += ea * ea;
        dec->e_bp += eb * eb;
    }
    const float l = dc_block(a + 0.5f * b + ZX_BEEPER_GAIN * bp, &dec->dc_x[0], &dec->dc_y[0]) * ZX_GAIN;
    const float r = dc_block(c + 0.5f * b + ZX_BEEPER_GAIN * bp, &dec->dc_x[1], &dec->dc_y[1]) * ZX_GAIN;
    if (dec->fifo_frames < ZX_FIFO_FRAMES) {
        dec->fifo[2 * dec->fifo_frames]     = l;
        dec->fifo[2 * dec->fifo_frames + 1] = r;
        dec->fifo_frames++;
    }
    if (dec->discard) return;
    const float v4[ZX_VOICES] = { a, b, c, bp };
    for (int v = 0; v < ZX_VOICES; v++) {
        float s = dc_block(v4[v], &dec->vdc_x[v], &dec->vdc_y[v]);
        int q = (int)(s * 220.0f);
        if (m_voice_buff[v])
            m_voice_buff[v][(m_voice_current_ptr[v] >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT)
                            & (ZX_SCOPE_RING - 1)] = (signed char)LIMIT8(q);
        m_voice_current_ptr[v] += 1 << MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
    }
}

/* Parameter bytes after the Spectrum's PRINT control codes: INK..OVER take
 * one, AT and TAB two. */
static void zxs_print(struct RewampDecoder* dec, uint8_t ch) {
    if (dec->ctrl_skip > 0) { dec->ctrl_skip--; return; }
    if (dec->text_len >= ZX_TEXT_MAX - 2) return;
    if (ch >= 0x10 && ch <= 0x15) { dec->ctrl_skip = 1; return; }
    if (ch == 0x16 || ch == 0x17) { dec->ctrl_skip = 2; return; }
    if (ch == 0x0D) {
        if (dec->text_len && dec->text[dec->text_len - 1] != '\n')
            dec->text[dec->text_len++] = '\n';
        dec->text[dec->text_len] = 0;
        return;
    }
    if (ch == 0x7F) ch = 'c';                 /* © */
    if (ch < 32 || ch >= 0x80) return;        /* graphics, UDGs, tokens */
    if (ch == ' ' && dec->text_len && (dec->text[dec->text_len - 1] == ' '
                                       || dec->text[dec->text_len - 1] == '\n'))
        return;
    dec->text[dec->text_len++] = (char)ch;
    dec->text[dec->text_len] = 0;
}

/* The 48K BASIC ROM is in: always on a 48K, ROM 1 on a 128K (bit 4 of the
 * last write to 0x7FFD; the 128K's ROM 0, the editor, has other code at
 * these addresses). */
static bool zxs_basic_rom(const zx_t* sys) {
    return sys->type == ZX_TYPE_48K || (sys->last_mem_config & 0x10);
}

/* LD-BYTES (0x0556). Entry: A = expected flag byte, IX = destination,
 * DE = length, carry set = LOAD (reset = VERIFY). Exit: carry = success.
 * The next tape block answers; a wrong flag fails it and moves on, exactly
 * what the ROM does with a block it was not looking for. */
static bool zxs_on_m1(void* user, void* vsys, uint16_t addr) {
    struct RewampDecoder* dec = (struct RewampDecoder*)user;
    zx_t* sys = (zx_t*)vsys;
    if (!zxs_basic_rom(sys)) return false;
    z80_t* cpu = &sys->cpu;
    if (addr == 0x0010) {
        if (dec->capture_text) zxs_print(dec, cpu->a);
        return false;
    }
    if (dec->tap_next >= dec->nblocks) {      /* end of tape */
        cpu->f &= (uint8_t)~Z80_CF;
        return true;
    }
    const TapBlock blk = dec->blocks[dec->tap_next++];
    const uint8_t* b = dec->tap + blk.off;
    if (b[0] != cpu->a) {
        cpu->f &= (uint8_t)~Z80_CF;
        return true;
    }
    const bool load = (cpu->f & Z80_CF) != 0;
    const uint32_t avail = blk.len - 2;
    const uint32_t want = cpu->de;
    const uint32_t n = want < avail ? want : avail;
    if (load) {
        for (uint32_t i = 0; i < n; i++)
            mem_wr(&sys->mem, (uint16_t)(cpu->ix + i), b[1 + i]);
    }
    cpu->ix = (uint16_t)(cpu->ix + n);
    cpu->de = (uint16_t)(cpu->de - n);
    if (n == want) cpu->f |= Z80_CF; else cpu->f &= (uint8_t)~Z80_CF;
    dec->tap_loads++;
    return true;
}

/* ── running the machine ────────────────────────────────────────────────── */

static void run_us(struct RewampDecoder* dec, uint32_t us) {
    while (us > 0) {
        const uint32_t step = us > 20000 ? 20000 : us;
        if (dec->discard) dec->fifo_frames = 0;
        zx_exec(dec->sys, step);
        us -= step;
    }
}

static void press(struct RewampDecoder* dec, int key) {
    zx_key_down(dec->sys, key);
    run_us(dec, ZX_KEY_US);
    zx_key_up(dec->sys, key);
    run_us(dec, ZX_KEY_US);
}

static bool fifo_audible(const struct RewampDecoder* dec) {
    for (int i = 0; i < dec->fifo_frames * 2; i++) {
        const float v = dec->fifo[i];
        if (v > ZX_SILENCE || v < -ZX_SILENCE) return true;
    }
    return false;
}

/* Power on as [type], LOAD "", run silently to the first audible sample.
 * Returns the emulated wait after the LOAD (µs), and whether it got sound. */
static bool zxs_start(struct RewampDecoder* dec, zx_type_t type, uint32_t* waited_out) {
    zx_init(dec->sys, &(zx_desc_t){
        .type  = type,
        .audio = { .sample_rate = ZX_RATE, .beeper_volume = 1.0f, .ay_volume = 1.0f },
        .roms  = {
            .zx48k   = { .ptr = (void*)rw_zx48k,   .size = sizeof(rw_zx48k) },
            .zx128_0 = { .ptr = (void*)rw_zx128_0, .size = sizeof(rw_zx128_0) },
            .zx128_1 = { .ptr = (void*)rw_zx128_1, .size = sizeof(rw_zx128_1) },
        },
    });
    dec->sys->rw_sample = zxs_on_sample;
    dec->sys->rw_m1     = zxs_on_m1;
    dec->sys->rw_user   = dec;
    dec->tap_next = 0;
    dec->tap_loads = 0;
    dec->text_len = 0;
    dec->text[0] = 0;
    dec->ctrl_skip = 0;
    memset(dec->dc_x, 0, sizeof(dec->dc_x));
    memset(dec->dc_y, 0, sizeof(dec->dc_y));
    dec->discard = true;
    dec->capture_text = false;

    /* What the program prints is captured from the Enter on: before it, the
     * screen only echoes the line being typed. */
    if (type == ZX_TYPE_128) {
        run_us(dec, ZX_BOOT128_US);
        dec->capture_text = true;
        press(dec, 0x0D);                     /* menu: "Tape Loader" = LOAD "" */
    } else {
        run_us(dec, ZX_BOOT48_US);
        press(dec, 'j');                      /* K mode: J = LOAD */
        press(dec, '"');
        /* the SAME key twice: the ROM takes the second press for the first
         * one still held unless it sees the key up for longer (measured: the
         * line read LOAD " and failed — same story as the CPC's RUN"GINFIZZ) */
        run_us(dec, 3 * ZX_KEY_US);
        press(dec, '"');
        dec->capture_text = true;
        press(dec, 0x0D);
    }
    /* The key click is the beeper too: let it die out of the DC filter
     * before listening for the program. */
    run_us(dec, 200000u);
    memset(dec->dc_x, 0, sizeof(dec->dc_x));
    memset(dec->dc_y, 0, sizeof(dec->dc_y));
    uint32_t waited = 0;
    bool audible = false;
    for (;;) {
        dec->fifo_frames = 0;
        dec->e_ay = dec->e_bp = 0.0f;
        zx_exec(dec->sys, ZX_SKIP_STEP_US);
        waited += ZX_SKIP_STEP_US;
        if (fifo_audible(dec)) { audible = true; break; }
        if (waited >= ZX_MAX_SKIP_US) break;
    }
    dec->capture_text = false;
#ifdef ZX_DEBUG
    fprintf(stderr, "[zx] %s: audible %d after %.2fs, blocks %d/%d, e_ay %g e_bp %g, text <<%s>>\n",
            type == ZX_TYPE_128 ? "128K" : "48K", audible, waited / 1e6,
            dec->tap_loads, dec->nblocks, dec->e_ay, dec->e_bp, dec->text);
#endif
    *waited_out = waited;
    return audible;
}

/* ── probe / open ───────────────────────────────────────────────────────── */

static int zxs_probe(const char* ext, const uint8_t* hdr, size_t n) {
    if (!ext || strcasecmp(ext, "tap") != 0) return 0;
    /* .tap is also Commodore (raw pulses, "C64-TAPE-RAW") and Oric: the
     * Spectrum's first block is a 19-byte header (flag 0) almost always. */
    if (n >= 12 && memcmp(hdr, "C64-TAPE-RAW", 12) == 0) return 0;
    if (n >= 3 && hdr[0] == 19 && hdr[1] == 0 && hdr[2] == 0) return 60;
    return 0;
}

/* With the file: the whole block chain must hold (lengths to the byte,
 * checksums), which no other tape format does by chance. */
static int zxs_probe_path(const char* ext, const uint8_t* hdr, size_t n,
                         const char* path, uint64_t fileSize) {
    if (!ext || strcasecmp(ext, "tap") != 0 || !path) return zxs_probe(ext, hdr, n);
    if (fileSize < 4 || fileSize > 4u * 1024 * 1024) return 0;
    FILE* f = fopen(path, "rb");
    if (!f) return 0;
    uint8_t* d = (uint8_t*)malloc((size_t)fileSize);
    const size_t got = d ? fread(d, 1, (size_t)fileSize, f) : 0;
    fclose(f);
    int score = 0;
    if (d && got == (size_t)fileSize) {
        static TapBlock tmp[ZX_MAX_BLOCKS];   /* probes run one at a time (load lock) */
        if (tap_parse(d, got, tmp, ZX_MAX_BLOCKS, true) > 0) score = 95;
    }
    free(d);
    return score;
}

static void zxs_close(RewampDecoder* dec);

static RewampDecoder* zxs_open(const char* path, RewampAudioFormat* outFormat) {
    char fpath[4096];
    snprintf(fpath, sizeof(fpath), "%s", path);
    char* q = strstr(fpath, "?subsong=");
    if (q) *q = 0;

    FILE* f = fopen(fpath, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (sz <= 0 || sz > 4 * 1024 * 1024) { fclose(f); return NULL; }
    struct RewampDecoder* dec = (struct RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { fclose(f); return NULL; }
    dec->tap = (uint8_t*)malloc((size_t)sz);
    if (!dec->tap || fread(dec->tap, 1, (size_t)sz, f) != (size_t)sz) {
        fclose(f); zxs_close(dec); return NULL;
    }
    fclose(f);
    dec->tap_size = (size_t)sz;
    dec->nblocks = tap_parse(dec->tap, dec->tap_size, dec->blocks, ZX_MAX_BLOCKS, false);
    if (dec->nblocks <= 0) { zxs_close(dec); return NULL; }

    dec->sys  = (zx_t*)calloc(1, sizeof(zx_t));
    dec->snap = (zx_t*)calloc(1, sizeof(zx_t));
    dec->fifo = (float*)calloc(ZX_FIFO_FRAMES * 2, sizeof(float));
    dec->head = (float*)calloc(ZX_FIFO_FRAMES * 2, sizeof(float));
    if (!dec->sys || !dec->snap || !dec->fifo || !dec->head) { zxs_close(dec); return NULL; }

    /* Voice data BEFORE the first emulated sample (PLUGINS.md §2.6). */
    rewamp_channel_data_reset(ZX_VOICES);
    rewamp_channel_data_set_ring_write_size(ZX_SCOPE_RING);

    uint32_t waited = 0;
    zx_type_t machine = ZX_TYPE_128;
    bool audible = zxs_start(dec, ZX_TYPE_128, &waited);
    /* What started sounding is the BEEPER alone: beeper music, timed in 48K
     * T-states. Keep the 128K run if the program does not play on a 48K. */
    /* (the energies are those of the step that turned audible) */
    if (audible && dec->e_ay < 0.01f * dec->e_bp) {
        uint32_t w48 = 0;
        if (zxs_start(dec, ZX_TYPE_48K, &w48)) {
            machine = ZX_TYPE_48K;
            waited = w48;
        } else {
            zxs_start(dec, ZX_TYPE_128, &waited);
        }
    }

    rewamp_voices_meta_reset();
    if (machine == ZX_TYPE_128) {
        rewamp_voices_add_chip("AY-3-8912", 0, ZX_AY_VOICES);
        rewamp_voice_set_name(0, "A (left)");
        rewamp_voice_set_name(1, "B (centre)");
        rewamp_voice_set_name(2, "C (right)");
    }
    rewamp_voices_add_chip("Beeper", ZX_BEEPER_VOICE, 1);
    rewamp_voice_set_name(ZX_BEEPER_VOICE, "Beeper");

    memcpy(dec->head, dec->fifo, (size_t)dec->fifo_frames * 2 * sizeof(float));
    dec->head_frames = dec->fifo_frames;
    zx_save_snapshot(dec->sys, dec->snap);
    dec->snap_tap_next = dec->tap_next;
    dec->discard = false;

    /* ⓘ panel */
    char listing[512];
    tap_listing(dec, listing, sizeof(listing));
    rewamp_track_message_append("Format: ZX Spectrum tape image (TAP)\n");
    rewamp_track_message_append("Machine: ZX Spectrum %s (emulated, floooh/chips)\n",
                                machine == ZX_TYPE_128 ? "128K" : "48K");
    rewamp_track_message_append("Sound: %s\n",
                                machine == ZX_TYPE_128 ? "AY-3-8912 (+ beeper)" : "beeper");
    if (listing[0]) rewamp_track_message_append("Tape: %s\n", listing);
    rewamp_track_message_append("Blocks loaded: %d of %d\n", dec->tap_loads, dec->nblocks);
    if (waited > ZX_SKIP_STEP_US)
        rewamp_track_message_append("Loading skipped: %.1f s\n", waited / 1e6);
    /* the 128K's own banner for its tape loader is not the program's */
    if (strncmp(dec->text, "Tape Loader", 11) == 0) {
        const char* nl = strchr(dec->text, '\n');
        const int cut = nl ? (int)(nl + 1 - dec->text) : dec->text_len;
        memmove(dec->text, dec->text + cut, (size_t)(dec->text_len - cut + 1));
        dec->text_len -= cut;
    }
    if (dec->text_len > 0) {
        while (dec->text_len && (dec->text[dec->text_len - 1] == '\n'
                                 || dec->text[dec->text_len - 1] == ' '))
            dec->text[--dec->text_len] = 0;
        if (dec->text_len)
            rewamp_track_message_append("\nOn screen:\n%s\n", dec->text);
    }

    dec->last_mute = -1;
    outFormat->channels   = 2;
    outFormat->sampleRate = ZX_RATE;
    return dec;
}

/* ── read / seek ────────────────────────────────────────────────────────── */

static void zxs_apply_mute(struct RewampDecoder* dec) {
    dec->last_mute = generic_mute_mask;
    dec->sys->ay.rw_mute = (uint32_t)(generic_mute_mask & 7);
    dec->beeper_muted = ((generic_mute_mask >> ZX_BEEPER_VOICE) & 1) != 0;
}

static void zxs_capture_notes(struct RewampDecoder* dec) {
    if (dec->sys->type != ZX_TYPE_128) return;
    const ay38910_t* psg = &dec->sys->ay;
    for (int v = 0; v < ZX_AY_VOICES; v++) {
        const int period = ((psg->reg[2 * v + 1] & 0x0F) << 8) | psg->reg[2 * v];
        const int tone_on = !((psg->reg[AY38910_REG_ENABLE] >> v) & 1);
        const uint8_t amp = psg->reg[AY38910_REG_AMP_A + v];
        const int vol = (amp & 0x10) ? 15 : (amp & 0x0F);
        const bool muted = (generic_mute_mask >> v) & 1;
        /* 128K AY clock: 3.5469 MHz / 2; tone = clock / (16 × period) */
        vgm_last_note[v] = (tone_on && vol && period && !muted)
                         ? (unsigned int)(1773447 / (16 * period)) : 0;
        vgm_last_vol[v]  = (tone_on && !muted) ? (unsigned int)(vol * 255 / 15) : 0;
    }
}

static uint64_t zxs_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->sys || frameCount == 0) return 0;
    if (dec->last_mute != generic_mute_mask) zxs_apply_mute(dec);
    uint64_t written = 0;
    while (written < frameCount) {
        if (dec->fifo_frames == 0) {
            uint64_t want = frameCount - written;
            if (want > ZX_FIFO_FRAMES / 2) want = ZX_FIFO_FRAMES / 2;
            zx_exec(dec->sys, (uint32_t)(want * 1000000ull / ZX_RATE) + 1);
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
    zxs_capture_notes(dec);
    dec->pos += written;
    return written;
}

extern volatile int    g_seek_cancel;
extern volatile double g_seek_progress_s;

static uint64_t zxs_skip_frames(struct RewampDecoder* dec, uint64_t target, uint64_t skip) {
    dec->discard = true;
    while (skip > 0 && !g_seek_cancel) {
        if (dec->fifo_frames == 0) {
            uint64_t chunk = skip > ZX_FIFO_FRAMES / 2 ? ZX_FIFO_FRAMES / 2 : skip;
            zx_exec(dec->sys, (uint32_t)(chunk * 1000000ull / ZX_RATE) + 1);
            if (dec->fifo_frames == 0) break;
        }
        if ((uint64_t)dec->fifo_frames > skip) {
            const int keep = dec->fifo_frames - (int)skip;
            memmove(dec->fifo, dec->fifo + skip * 2, (size_t)keep * 2 * sizeof(float));
            dec->fifo_frames = keep;
            skip = 0;
        } else {
            skip -= (uint64_t)dec->fifo_frames;
            dec->fifo_frames = 0;
        }
        g_seek_progress_s = (double)(target - skip) / ZX_RATE;
    }
    dec->discard = false;
    return skip;
}

static void zxs_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->sys) return;
    if (frameIndex >= dec->pos) {
        const uint64_t left = zxs_skip_frames(dec, frameIndex, frameIndex - dec->pos);
        dec->pos = frameIndex - left;
        return;
    }
    zx_load_snapshot(dec->sys, ZX_SNAPSHOT_VERSION, dec->snap);
    dec->sys->rw_sample = zxs_on_sample;
    dec->sys->rw_m1     = zxs_on_m1;
    dec->sys->rw_user   = dec;
    dec->tap_next = dec->snap_tap_next;
    zxs_apply_mute(dec);
    dec->fifo_frames = 0;
    if (frameIndex < (uint64_t)dec->head_frames) {
        const int n = dec->head_frames - (int)frameIndex;
        memcpy(dec->fifo, dec->head + frameIndex * 2, (size_t)n * 2 * sizeof(float));
        dec->fifo_frames = n;
        dec->pos = frameIndex;
        return;
    }
    const uint64_t left = zxs_skip_frames(dec, frameIndex,
                                         frameIndex - (uint64_t)dec->head_frames);
    dec->pos = frameIndex - left;
}

static uint64_t zxs_length(RewampDecoder* dec) {
    (void)dec;
    return 0;   /* a program plays forever: generic loop path */
}

static void zxs_close(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->sys) zx_discard(dec->sys);
    free(dec->sys);
    free(dec->snap);
    free(dec->fifo);
    free(dec->head);
    free(dec->tap);
    free(dec);
}

static const RewampPluginVTable kZxSpectrumVTable = {
    "zxspectrum",
    zxs_probe,
    zxs_open,
    zxs_read,
    zxs_seek,
    zxs_length,
    zxs_close,
    NULL,                         /* configure_loop: generic (plays forever) */
    0,                            /* supportsNativeFadeout */
    "zxspectrum",                 /* engine_id */
    NULL,                         /* param_changed */
    NULL, NULL, NULL, NULL, NULL, /* pattern view */
    zxs_probe_path, 0,             /* probe_path, noPrefixProbe */
    NULL,                         /* set_speed: generic resampling */
};

const RewampPluginVTable* rewamp_zxspectrum_plugin(void) { return &kZxSpectrumVTable; }

#endif /* REWAMP_WITH_ZXSPECTRUM */
