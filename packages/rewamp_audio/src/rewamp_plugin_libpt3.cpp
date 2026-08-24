// libpt3 plugin — ZX Spectrum PT3 (.pt3, ProTracker 3) via the vendored
// pt3player.c (Volutar) + ayumi.c (Peter Sovietov, AY-3-8910/YM2149 synth),
// third_party/libpt3. Unlike the PSF-family engines earlier in this batch,
// libpt3 is a self-contained tracker player with a real, working (if empty
// ObjC-wrapper-stubbed) Modizer app integration — the register-to-synth
// translation (pt3_update_ayumi_state), tick/render loop (pt3_renday), and
// note-frequency capture all live in ModizMusicPlayer.mm itself, not inside
// the vendored library, and are ported here. func_setup_music can return
// >1 chip for TSData (TurboSound, multi-AY combined) files — each chip's
// output is rendered separately then averaged, matching Modizer's own
// pt3_tmpbuf[]-per-chip + `/pt3_numofchips` mix.
//
// Per-voice waveform capture already lived in ayumi.c (grep YOYOFR), but
// its ring wraparound was undersized (bare SOUND_BUFFER_SIZE_SAMPLE=512,
// no explicit mask at all on the write) — same bug class as the SNDH/HVL/
// V2M/GSF sweep, fixed to *4*2=4096 with an explicit mask. Mute used
// Modizer's pt3_mute[] app-level array — ported as a direct
// generic_mute_mask read instead (no new plugin-specific global).
#ifdef REWAMP_WITH_LIBPT3

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"
extern "C" {
#include "ayumi.h"
#include "pt3player.h"
}

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define PT3_RATE       44100
#define PT3_FRAME_RATE 50.0
#define PT3_CLOCK      1750000
#define PT3_MAX_CHIPS  3   // TSData combined files carry at most 3 chips

#define PT3_HDR_DELAY        100
#define PT3_HDR_NUMPOS       101
#define PT3_HDR_LOOPPOS      102
#define PT3_HDR_PATPTR       103
#define PT3_HDR_POSLIST      201
#define PT3_MAX_POSITIONS    256
#define PT3_EVENT_BYTE_LIMIT 64     /* a single row event never runs this long */

struct RewampDecoder {
    struct ayumi ay[PT3_MAX_CHIPS];
    int      numChips;
    int      isrStep;              // samples per music tick (rate/frameRate)
    int      sampleCounter[PT3_MAX_CHIPS];
    uint64_t totalFrames;          // measured via silent render; 0 = unknown
    uint64_t framePos;
    int64_t  lastMuteMask;
    uint8_t  regs[14];
    // Pattern view. The module bytes are COPIED rather than pointed at: the
    // originals live in pt3player's globals, which the next open() overwrites,
    // and cells are decoded lazily long after open() returned.
    uint8_t* mod[PT3_MAX_CHIPS];
    int      modTS[PT3_MAX_CHIPS];
    int      numPositions;
    int      patRows[256];
    int      patternsOk;
    // Tick timeline per chip: the start tick of every line, and where each
    // position begins in it. This is what lines a TurboSound pair up — see the
    // note above pt3_pattern_get.
    uint32_t* tlTick[PT3_MAX_CHIPS];
    uint16_t* tlPos[PT3_MAX_CHIPS];
    uint16_t* tlRow[PT3_MAX_CHIPS];
    int       tlCount[PT3_MAX_CHIPS];
    int       tlPosStart[PT3_MAX_CHIPS][PT3_MAX_POSITIONS];
    uint32_t  tlTotal[PT3_MAX_CHIPS];
    uint32_t  tlLoop[PT3_MAX_CHIPS];
    // Last envelope shape actually written. Register 13 carries 0xFF for "no
    // change this tick" (func_play_tick resets it every tick), so the current
    // shape has to be latched to know whether the envelope is a periodic tone.
    uint8_t  envShape[PT3_MAX_CHIPS];
};

static const char* const kPt3Exts[] = { "pt3", NULL };

static int pt3_probe(const char* ext, const uint8_t* h, size_t n) {
    (void)h; (void)n;
    return rewamp_ext_in_list(ext, kPt3Exts) ? 90 : 0;
}

// Ported from ModizMusicPlayer.mm's pt3_update_ayumi_state, generic_mute_mask
// instead of the app-level pt3_mute[] array.
static void pt3_update_ayumi_state(RewampDecoder* dec, struct ayumi* ay,
                                    uint8_t* r, int ch) {
    func_getregs(r, ch);
    ayumi_set_tone(ay, 0, (r[1] << 8) | r[0]);
    ayumi_set_tone(ay, 1, (r[3] << 8) | r[2]);
    ayumi_set_tone(ay, 2, (r[5] << 8) | r[4]);
    ayumi_set_noise(ay, r[6]);
    ayumi_set_mixer(ay, 0, r[7] & 1, (r[7] >> 3) & 1, r[8] >> 4);
    ayumi_set_mixer(ay, 1, (r[7] >> 1) & 1, (r[7] >> 4) & 1, r[9] >> 4);
    ayumi_set_mixer(ay, 2, (r[7] >> 2) & 1, (r[7] >> 5) & 1, r[10] >> 4);
    ayumi_set_volume(ay, 0, r[8] & 0xf);
    ayumi_set_volume(ay, 1, r[9] & 0xf);
    ayumi_set_volume(ay, 2, r[10] & 0xf);
    ayumi_set_envelope(ay, (r[12] << 8) | r[11]);
    if (r[13] != 255) { ayumi_set_envelope_shape(ay, r[13]); dec->envShape[ch] = r[13]; }

    for (int i = 0; i < 3; i++) {
        if (generic_mute_mask & (1LL << (ch * 3 + i))) {
            ayumi_set_volume(ay, i, 0);
            int t_off = (r[7] >> i) & 1, n_off = (r[7] >> (i + 3)) & 1;
            ayumi_set_mixer(ay, i, t_off, n_off, 0);
        }
    }

    // Per-voice pitch/level for the notation viz and the scope's note readout.
    // The AY registers we just wrote ARE the answer — no need to reach into the
    // player's own note number: a tone period is what the chip actually sounds,
    // so slides, ornaments and the envelope-driven pitch all come out right,
    // where Chan->Note is only the note the pattern asked for.
    //
    // Two gates, both needed. The MIXER bit decides whether the tone generator
    // reaches the output at all (a noise-only or silent channel must not hold
    // the previous pitch on screen — same failure the SPC capture had), and a
    // zero amplitude with no envelope means the voice is off. An envelope-driven
    // voice (bit 4 of the amplitude register) has no fixed level here, so it
    // reports full scale rather than the 0 its amplitude nibble would give.
    for (int i = 0; i < 3; i++) {
        const int v = ch * 3 + i;
        if (v >= SOUND_MAXVOICES_BUFFER_FX) break;
        const int amp      = r[8 + i];
        const int envDriven = (amp & 0x10) != 0;
        const int level    = envDriven ? 15 : (amp & 0x0f);
        const int toneOn   = ((r[7] >> i) & 1) == 0;
        const int period   = ((r[i * 2 + 1] & 0x0f) << 8) | r[i * 2];

        vgm_last_vol[v] = (unsigned)((level * 255) / 15);
        if (toneOn && level > 0 && period > 0) {
            vgm_last_note[v] = (unsigned)(PT3_CLOCK / (16.0 * period));
        } else if (envDriven && !toneOn) {
            // PT3's envelope bass: the tone generator is switched OFF and the
            // pitch is carried by the envelope itself, which the chip then plays
            // as a waveform. Reading only the tone period leaves those voices
            // silent on screen — and they are usually the bass line. Only the
            // REPEATING shapes are a pitch: 8/A/C/E cycle, the odd ones and
            // everything below 8 decay once and hold.
            const int shape = dec->envShape[ch];
            const int envPeriod = (r[12] << 8) | r[11];
            const int repeating = (shape & 0x08) && !(shape & 0x01);
            vgm_last_note[v] = (repeating && envPeriod > 0)
                ? (unsigned)(PT3_CLOCK / (256.0 * envPeriod))
                : 0;
        } else {
            vgm_last_note[v] = 0;
        }
    }
}

// Ported from pt3_renday: runs music ticks at PT3_FRAME_RATE cadence,
// rendering `frames` stereo samples per chip. buf==NULL means silent
// (length-measurement pass). Returns nonzero once the song hits its
// loop/end point (func_play_tick's own signal).
static int pt3_tick_and_render(RewampDecoder* dec, int ch, int16_t* buf, int frames) {
    struct ayumi* ay = &dec->ay[ch];
    int ret = 0;
    for (int i = 0; i < frames; i++) {
        if (dec->sampleCounter[ch] >= dec->isrStep) {
            ret = func_play_tick(ch);
            if (buf) pt3_update_ayumi_state(dec, ay, dec->regs, ch);
            dec->sampleCounter[ch] = 0;
        }
        if (buf) {
            ayumi_process(ay, ch);
            ayumi_remove_dc(ay);
            buf[i * 2 + 0] = (int16_t)(ay->left  * 10000.0);
            buf[i * 2 + 1] = (int16_t)(ay->right * 10000.0);
        }
        dec->sampleCounter[ch]++;
        if (ret) break;
    }
    return ret;
}


// ── PT3 pattern decoding (static grid for the pattern visualizer) ────────────
//
// PT3 stores each pattern as THREE independent byte streams, one per channel,
// and the interpreter in pt3player.c walks them as it plays. To draw a grid we
// have to walk them the same way WITHOUT applying any playback state — which is
// only safe if we consume exactly the same bytes, opcode for opcode: a single
// mis-sized operand desynchronises the stream and everything after it is
// garbage. pt3_parse_event below is therefore a transcription of
// PatternInterpreter's byte consumption, and verify_pt3_patterns.sh checks the
// result against the player itself rather than against this reading of it.
//
// Two properties of the format drive the loop:
//   * CHANNEL A defines the rows. Its stream is the only one tested for the
//     end-of-pattern marker (opcode 0), exactly as func_play_tick does.
//   * a row is one pass in which EVERY channel decrements its skip counter;
//     a channel only reads its stream when its counter reaches zero.
//
// Patterns are keyed by POSITION, not by PT3's own pattern number. That costs a
// re-decode when a pattern is reused, and in exchange it is the only key that
// survives TurboSound: there each chip carries its OWN module, with its own
// pattern numbering, and only the position lines them up.


static inline unsigned pt3_rd16(const uint8_t* m, unsigned off) {
    return (unsigned)m[off] | ((unsigned)m[off + 1] << 8);
}

// Stream offset of one channel's data for a position. Mirrors func_play_tick's
// own lookup, TurboSound remap included.
static unsigned pt3_chan_addr(const uint8_t* m, int ts, int position, int chan) {
    int i = m[PT3_HDR_POSLIST + position];
    if (ts != 0x20) i = ts * 3 - 3 - i;
    return pt3_rd16(m, pt3_rd16(m, PT3_HDR_PATPTR) + (unsigned)(i + chan) * 2);
}

struct Pt3Ev {
    int note, sample, ornament, volume, envType, envPeriod, noise, skip;
    int cmd[4], cmdVal[4], numCmd;
};

static void pt3_ev_clear(Pt3Ev* e) {
    e->note = e->sample = e->ornament = e->volume = -1;
    e->envType = e->envPeriod = e->noise = e->skip = -1;
    e->numCmd = 0;
}

static void pt3_ev_cmd(Pt3Ev* e, int code, int val) {
    if (e->numCmd >= 4) return;
    e->cmd[e->numCmd] = code;
    e->cmdVal[e->numCmd] = val;
    e->numCmd++;
}

// Reads ONE row event for one channel, advancing *pa past it.
static void pt3_parse_event(const uint8_t* m, unsigned* pa, Pt3Ev* e) {
    unsigned a = *pa;
    const unsigned start = a;
    int f1 = 0, f2 = 0, f3 = 0, f4 = 0, f5 = 0, f8 = 0, f9 = 0, counter = 0;
    int quit = 0;

    pt3_ev_clear(e);
    while (!quit && a - start < PT3_EVENT_BYTE_LIMIT && a < 0xFFFE) {
        const uint8_t op = m[a];
        if (op >= 0xf0)      { e->ornament = op - 0xf0; e->sample = m[++a] / 2; }
        else if (op >= 0xd1) { e->sample = op - 0xd0; }
        else if (op == 0xd0) { quit = 1; }
        else if (op >= 0xc1) { e->volume = op - 0xc0; }
        else if (op == 0xc0) { e->note = REWAMP_NOTE_OFF; quit = 1; }
        else if (op >= 0xb2) { e->envType = op - 0xb1;
                               e->envPeriod = (m[a + 1] << 8) | m[a + 2]; a += 2; }
        else if (op == 0xb1) { e->skip = m[++a]; }
        else if (op == 0xb0) { e->envType = 0; }
        else if (op >= 0x50) { e->note = op - 0x50; quit = 1; }
        else if (op >= 0x40) { e->ornament = op - 0x40; }
        else if (op >= 0x20) { e->noise = op - 0x20; }
        else if (op >= 0x11) { e->envType = op - 0x10;
                               e->envPeriod = (m[a + 1] << 8) | m[a + 2]; a += 2;
                               e->sample = m[++a] / 2; }
        else if (op == 0x10) { e->envType = 0; e->sample = m[++a] / 2; }
        else if (op == 9)    { f9 = ++counter; }
        else if (op == 8)    { f8 = ++counter; }
        else if (op == 5)    { f5 = ++counter; }
        else if (op == 4)    { f4 = ++counter; }
        else if (op == 3)    { f3 = ++counter; }
        else if (op == 2)    { f2 = ++counter; }
        else if (op == 1)    { f1 = ++counter; }
        a++;
    }
    // Effect operands follow the row's terminating opcode, in REVERSE order of
    // the command bytes that announced them — the player walks its flags from
    // the highest counter down, and reading them the other way round would
    // consume the wrong bytes.
    while (counter > 0 && a < 0xFFF8) {
        if (counter == f1)      { a++; pt3_ev_cmd(e, 1, (int)pt3_rd16(m, a)); a += 2; }
        else if (counter == f2) { a++; pt3_ev_cmd(e, 2, (int)pt3_rd16(m, a + 2)); a += 4; }
        else if (counter == f3) { pt3_ev_cmd(e, 3, m[a]); a++; }
        else if (counter == f4) { pt3_ev_cmd(e, 4, m[a]); a++; }
        else if (counter == f5) { pt3_ev_cmd(e, 5, (m[a] << 8) | m[a + 1]); a += 2; }
        else if (counter == f8) { a++; pt3_ev_cmd(e, 8, (int)pt3_rd16(m, a)); a += 2; }
        else if (counter == f9) { pt3_ev_cmd(e, 9, m[a]); a++; }
        counter--;
    }
    *pa = a;
}


// One decoded event → one display cell. The renderer draws a SINGLE effect
// column (and a '+' when more are stacked), so the effects are ordered by how
// much they explain the row: the PT3 command first, then the envelope (a PT3
// bass line lives there), the ornament, and the noise offset last.
static void pt3_fill_cell(RewampPatternCell* cell, const Pt3Ev* e) {
    memset(cell, 0, sizeof(*cell));
    cell->note = (int16_t)(e->note >= 0 ? e->note + 12 : e->note);  // PT3 note 0 = C-1
    if (e->note < 0 && e->note != REWAMP_NOTE_OFF) cell->note = REWAMP_NOTE_EMPTY;
    cell->instrument = e->sample;
    cell->volume = -1;
    if (e->volume >= 0) snprintf(cell->vol, sizeof(cell->vol), "%X", e->volume & 0xF);

    int n = 0;
    for (int i = 0; i < e->numCmd && n < REWAMP_PATTERN_MAX_FX; i++, n++) {
        cell->fx[n][0] = (char)('0' + e->cmd[i]);
        cell->fxval[n] = e->cmdVal[i];
    }
    if (e->envType >= 0 && n < REWAMP_PATTERN_MAX_FX) {
        cell->fx[n][0] = e->envType == 0 ? 'e' : 'E';   // lowercase = envelope off
        cell->fxval[n] = e->envType == 0 ? -1 : e->envPeriod;
        n++;
    }
    if (e->ornament >= 0 && n < REWAMP_PATTERN_MAX_FX) {
        cell->fx[n][0] = 'O'; cell->fxval[n] = e->ornament; n++;
    }
    if (e->noise >= 0 && n < REWAMP_PATTERN_MAX_FX) {
        cell->fx[n][0] = 'N'; cell->fxval[n] = e->noise; n++;
    }
    for (int i = n; i < REWAMP_PATTERN_MAX_FX; i++) cell->fxval[i] = -1;
    cell->num_fx = (uint8_t)n;
}
// Walks a position's three streams row by row. `out` may be NULL — then this
// only counts the rows, which is what open() needs before any cell is asked for.
static int pt3_decode_position(const uint8_t* m, int ts, int position,
                               RewampPatternCell* out, int outRows, int outStride,
                               int chanBase, int startTempo, uint16_t* rowTempo) {
    unsigned addr[3];
    int skip[3], counter[3];
    for (int c = 0; c < 3; c++) {
        addr[c] = pt3_chan_addr(m, ts, position, c);
        skip[c] = 1;
        counter[c] = 1;
    }

    int row = 0;
    int tempo = startTempo > 0 ? startTempo : 1;
    const int outRowsTempo = 256;
    Pt3Ev ev;
    Pt3Ev rowEv[3];
    while (row < 256) {
        // Channel A both drives the row and owns the end marker, and the player
        // only looks at that marker on the tick its counter reaches zero.
        int parsed[3] = { 0, 0, 0 };
        if (--counter[0] == 0) {
            if (m[addr[0]] == 0) break;
            pt3_parse_event(m, &addr[0], &ev);
            parsed[0] = 1;
            rowEv[0] = ev;
            if (ev.skip >= 0) skip[0] = ev.skip;
            counter[0] = skip[0] > 0 ? skip[0] : 1;
            if (out && row < outRows) {
                RewampPatternCell* cell = &out[(size_t)row * outStride + chanBase];
                pt3_fill_cell(cell, &ev);
            }
        }
        for (int c = 1; c < 3; c++) {
            if (--counter[c] == 0) {
                pt3_parse_event(m, &addr[c], &ev);
                parsed[c] = 1;
                rowEv[c] = ev;
                if (ev.skip >= 0) skip[c] = ev.skip;
                counter[c] = skip[c] > 0 ? skip[c] : 1;
                if (out && row < outRows) {
                    RewampPatternCell* cell = &out[(size_t)row * outStride + chanBase + c];
                    pt3_fill_cell(cell, &ev);
                }
            }
        }
        (void)parsed;
        // The speed change (command 9) takes effect on the row that carries it:
        // the player reloads its DelayCounter from Delay AFTER the interpreters
        // have run. Publishing the tempo here is what lets a TurboSound pair be
        // lined up on time rather than on row numbers.
        for (int c = 0; c < 3; c++) {
            if (!parsed[c]) continue;
            for (int k = 0; k < rowEv[c].numCmd; k++)
                if (rowEv[c].cmd[k] == 9 && rowEv[c].cmdVal[k] > 0)
                    tempo = rowEv[c].cmdVal[k];
        }
        if (rowTempo && row < outRowsTempo) rowTempo[row] = (uint16_t)tempo;
        row++;
    }
    return row;
}

// Walks one chip once and gives every line its absolute start tick, honouring
// the speed changes it meets. Returns 0 when the chip has no usable pattern data.
static int pt3_build_timeline(RewampDecoder* dec, int ch) {
    const uint8_t* m = dec->mod[ch];
    const int positions = m[PT3_HDR_NUMPOS];
    if (positions <= 0 || positions > PT3_MAX_POSITIONS) return 0;
    const int loopPos = m[PT3_HDR_LOOPPOS] < positions ? m[PT3_HDR_LOOPPOS] : 0;

    int cap = 0;
    uint16_t rowTempo[256];
    int tempo = m[PT3_HDR_DELAY] > 0 ? m[PT3_HDR_DELAY] : 1;
    // First pass: how many lines in total, so the arrays are sized once.
    for (int p = 0; p < positions; p++)
        cap += pt3_decode_position(m, dec->modTS[ch], p, NULL, 0, 0, 0, 1, NULL);
    if (cap <= 0) return 0;

    dec->tlTick[ch] = (uint32_t*)malloc((size_t)cap * sizeof(uint32_t));
    dec->tlPos[ch]  = (uint16_t*)malloc((size_t)cap * sizeof(uint16_t));
    dec->tlRow[ch]  = (uint16_t*)malloc((size_t)cap * sizeof(uint16_t));
    if (!dec->tlTick[ch] || !dec->tlPos[ch] || !dec->tlRow[ch]) return 0;

    int n = 0;
    uint32_t tick = 0;
    for (int p = 0; p < positions; p++) {
        dec->tlPosStart[ch][p] = n;
        if (p == loopPos) dec->tlLoop[ch] = tick;
        const int rows = pt3_decode_position(m, dec->modTS[ch], p, NULL, 0, 0, 0,
                                             tempo, rowTempo);
        for (int r = 0; r < rows && n < cap; r++) {
            tempo = rowTempo[r] > 0 ? rowTempo[r] : tempo;
            dec->tlTick[ch][n] = tick;
            dec->tlPos[ch][n]  = (uint16_t)p;
            dec->tlRow[ch][n]  = (uint16_t)r;
            n++;
            tick += (uint32_t)tempo;
        }
    }
    dec->tlCount[ch] = n;
    dec->tlTotal[ch] = tick;
    return n > 0;
}

// The first line of chip `ch` that STARTS inside [from, from+span). An event
// must appear once, on the row where it fires — repeating it on every row it
// spans would read as a re-trigger. A chip that has run out folds back onto its
// loop position, exactly as it does in playback.
static int pt3_first_line_in(RewampDecoder* dec, int ch, uint32_t from, uint32_t span) {
    const int n = dec->tlCount[ch];
    if (n <= 0 || !span) return -1;
    if (from >= dec->tlTotal[ch]) {
        const uint32_t loop = dec->tlTotal[ch] - dec->tlLoop[ch];
        from = loop ? dec->tlLoop[ch] + (from - dec->tlLoop[ch]) % loop : dec->tlLoop[ch];
    }
    int lo = 0, hi = n;                       /* first line with tick >= from */
    while (lo < hi) {
        const int mid = (lo + hi) / 2;
        if (dec->tlTick[ch][mid] < from) lo = mid + 1; else hi = mid;
    }
    if (lo >= n) return -1;
    return dec->tlTick[ch][lo] < from + span ? lo : -1;
}

static RewampDecoder* pt3_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q) *q = '\0';

    FILE* f = fopen(cleanPath, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size <= 0) { fclose(f); return NULL; }

    // +16 zero-padded tail: func_setup_music's TSData::TSID (a 4-byte,
    // NON-null-terminated field at the very end of the buffer) gets
    // strcmp()'d against "03TS"/"02TS" -- a real heap-overflow in the
    // vendored code on any file whose last bytes partially match (a real
    // TurboSound file's TSID legitimately does), since strcmp reads past
    // the buffer hunting for a terminator that was never guaranteed to
    // exist. Caught by ASan on a real 6-channel .pt3. Padding (not patching
    // pt3player.c's algorithm) keeps the vendor diff minimal.
    uint8_t* buf = (uint8_t*)calloc((size_t)size + 16, 1);
    if (!buf) { fclose(f); return NULL; }
    size_t got = fread(buf, 1, (size_t)size, f);
    fclose(f);
    if (got != (size_t)size) { free(buf); return NULL; }

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { free(buf); return NULL; }

    int numChips = func_setup_music(buf, (int)size, 0, 1);
    char header[100]; memcpy(header, buf, size < 99 ? (size_t)size : 99);
    header[size < 99 ? size : 99] = '\0';
    free(buf);
    if (numChips <= 0) { free(dec); return NULL; }
    if (numChips > PT3_MAX_CHIPS) numChips = PT3_MAX_CHIPS;
    dec->numChips = numChips;
    dec->isrStep = (int)(PT3_RATE / PT3_FRAME_RATE);

    for (int ch = 0; ch < numChips; ch++) {
        if (!ayumi_configure(&dec->ay[ch], 1 /*is_ym*/, PT3_CLOCK, PT3_RATE)) {
            free(dec);
            return NULL;
        }
        ayumi_set_pan(&dec->ay[ch], 0, 0.1, 1);
        ayumi_set_pan(&dec->ay[ch], 1, 0.5, 1);
        ayumi_set_pan(&dec->ay[ch], 2, 0.9, 1);
    }

    const int voices = numChips * 3;
    m_genNumVoicesChannels = voices;
    rewamp_channel_data_reset(voices);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);
    rewamp_channel_data_set_ring_circular(1);
    rewamp_voices_meta_reset();
    for (int ch = 0; ch < numChips; ch++) {
        char name[32];
        snprintf(name, sizeof(name), numChips > 1 ? "AY #%d" : "AY-3-8910", ch + 1);
        rewamp_voices_add_chip(name, ch * 3, 3);
    }

    // Measure length via a silent render pass (PT3 has no embedded length —
    // same "throwaway measurement" idiom as AdPlug's a2m/a2t songlength()).
    int16_t scratch[4096 * 2];
    uint64_t measured = 0;
    for (;;) {
        int ended = 0;
        for (int ch = 0; ch < numChips; ch++)
            if (pt3_tick_and_render(dec, ch, NULL, 4096)) ended = 1;
        measured += 4096;
        if (ended || measured > (uint64_t)PT3_RATE * 600) break;  // 10 min safety cap
    }
    dec->totalFrames = measured;
    for (int ch = 0; ch < numChips; ch++) {
        func_restart_music(ch);
        dec->sampleCounter[ch] = 0;
    }

    // Pattern index. Rows are a property of the pattern (channel A's stream), so
    // they are measured once here; the cells themselves are decoded on demand.
    // A TurboSound file only gets SIX columns when the chips agree on the
    // structure — each chip is a SEPARATE module with its own tempo and its own
    // pattern lengths, and if they diverge anywhere the second half drifts out
    // of step with the cursor. When they do, the grid falls back to the FIRST
    // chip: three columns the cursor genuinely describes beat six that lie, and
    // beat showing nothing at all.
    dec->patternsOk = 0;
    for (int ch = 0; ch < numChips; ch++) {
        const uint8_t* md = NULL; int len = 0;
        dec->modTS[ch] = func_get_module(ch, &md, &len);
        // The whole 64 KB image, not `len`: pattern and sample pointers are
        // 16-bit offsets into it and a compiled module can point past the file
        // length it was loaded from.
        if (md) {
            dec->mod[ch] = (uint8_t*)malloc(65536);
            if (dec->mod[ch]) memcpy(dec->mod[ch], md, 65536);
        }
    }
    if (dec->mod[0]) {
        const int positions = dec->mod[0][PT3_HDR_NUMPOS];
        if (positions > 0 && positions <= PT3_MAX_POSITIONS) {
            dec->numPositions = positions;
            dec->patternsOk = 1;
            for (int ch = 0; ch < numChips && dec->patternsOk; ch++) {
                if (!dec->mod[ch]) { dec->patternsOk = 0; break; }
                if (!pt3_build_timeline(dec, ch)) dec->patternsOk = 0;
            }
            if (dec->patternsOk)
                for (int p = 0; p < positions; p++)
                    dec->patRows[p] = (p + 1 < positions
                        ? dec->tlPosStart[0][p + 1] : dec->tlCount[0])
                        - dec->tlPosStart[0][p];
        }
    }

    if (header[0]) rewamp_track_message_append("%s\n", header);
    rewamp_track_message_append("Format: PT3 (ProTracker 3), %d Hz, stereo%s\n",
                                 PT3_RATE, numChips > 1 ? ", TurboSound" : "");
    if (dec->totalFrames > 0) {
        unsigned total = (unsigned)(dec->totalFrames / PT3_RATE);
        rewamp_track_message_append("Duration: %u:%02u\n", total / 60, total % 60);
    }

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = PT3_RATE;
    }
    return dec;
}

static uint64_t pt3_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || frameCount == 0) return 0;
    if (dec->totalFrames > 0) {
        if (dec->framePos >= dec->totalFrames) return 0;
        uint64_t remain = dec->totalFrames - dec->framePos;
        if (frameCount > remain) frameCount = remain;
    }

    if (dec->lastMuteMask != generic_mute_mask) dec->lastMuteMask = generic_mute_mask;

    static int16_t s_buf[PT3_MAX_CHIPS][4096 * 2];
    const float scale = 1.0f / 32768.0f;
    uint64_t written = 0;
    while (written < frameCount) {
        uint32_t want = (uint32_t)(frameCount - written);
        if (want > 4096) want = 4096;

        int ended = 0;
        for (int ch = 0; ch < dec->numChips; ch++)
            if (pt3_tick_and_render(dec, ch, s_buf[ch], (int)want)) ended = 1;

        float* dst = out + written * 2;
        for (uint32_t i = 0; i < want * 2; i++) {
            int32_t sum = 0;
            for (int ch = 0; ch < dec->numChips; ch++) sum += s_buf[ch][i];
            dst[i] = (sum / dec->numChips) * scale;
        }
        written += want;
        dec->framePos += want;
        if (ended) break;
    }
    return written;
}

extern "C" volatile int    g_seek_cancel;
extern "C" volatile int    g_is_seeking;
extern "C" volatile double g_seek_progress_s;

static void pt3_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec) return;
    if (frameIndex < dec->framePos) {
        for (int ch = 0; ch < dec->numChips; ch++) {
            func_restart_music(ch);
            dec->sampleCounter[ch] = 0;
        }
        dec->framePos = 0;
    }
    if (dec->framePos == frameIndex) return;
    g_is_seeking = 1;
    float tmp[256 * 2];
    while (dec->framePos < frameIndex && !g_seek_cancel) {
        uint64_t want = frameIndex - dec->framePos;
        if (want > 256) want = 256;
        uint64_t got = pt3_read(dec, tmp, want);
        g_seek_progress_s = (double)dec->framePos / (double)PT3_RATE;
        if (got == 0) break;
    }
    g_is_seeking = 0;
}

static uint64_t pt3_length(RewampDecoder* dec) {
    return dec ? dec->totalFrames : 0;
}

static void pt3_close(RewampDecoder* dec) {
    if (!dec) return;
    for (int ch = 0; ch < PT3_MAX_CHIPS; ch++) {
        free(dec->mod[ch]);
        free(dec->tlTick[ch]);
        free(dec->tlPos[ch]);
        free(dec->tlRow[ch]);
    }
    free(dec);
}

// ── pattern-view vtable slots ───────────────────────────────────────────────

static int pt3_pattern_song_info(RewampDecoder* dec, RewampPatternSongInfo* out) {
    if (!dec || !out || !dec->patternsOk) return 0;
    memset(out, 0, sizeof(*out));
    out->num_channels = dec->numChips * 3;
    out->num_orders   = dec->numPositions;
    out->num_patterns = dec->numPositions;
    out->max_fx_cols  = 4;
    out->instr_digits = 2;   // a sample number is read as byte/2, so it can pass 15
    out->vol_chars    = 1;   // PT3 volume is one nibble
    out->fxcode_chars = 1;
    out->fxval_digits = 4;   // widest is the envelope period, a 16-bit word
    return 1;
}

static int pt3_pattern_order(RewampDecoder* dec, int order) {
    if (!dec || !dec->patternsOk || order < 0 || order >= dec->numPositions) return -1;
    return order;   // patterns are keyed by position (see the decoder's header)
}

static int pt3_pattern_num_rows(RewampDecoder* dec, int pattern) {
    if (!dec || !dec->patternsOk || pattern < 0 || pattern >= dec->numPositions) return 0;
    return dec->patRows[pattern];
}

// The grid is built on the FIRST chip's rows — the ones the cursor names — and
// every other chip contributes whatever it is PLAYING at the same instant.
//
// A TurboSound pair does not have to share a row grid: one measured file has
// 128 rows where the other has 64, eight positions out of twenty-one, both at
// speed 6. Their rows never line up, so a single (position,row) cannot name a
// line on both — but the TIME does line up, and that is what the timelines
// built at open() express. The row number displayed is the first chip's; the
// notes shown are what is heard on all voices. Where the halves do have the
// same shape the mapping is the identity, so there is one path for both cases.
static int pt3_pattern_get(RewampDecoder* dec, int pattern,
                           RewampPatternCell* out, int maxCells) {
    if (!dec || !out || !dec->patternsOk) return 0;
    if (pattern < 0 || pattern >= dec->numPositions) return 0;
    const int chans = dec->numChips * 3;
    const int rows  = dec->patRows[pattern];
    int cells = rows * chans;
    if (cells > maxCells) cells = maxCells - (maxCells % chans);
    if (cells <= 0) return 0;
    const int usableRows = cells / chans;

    // Every cell must be written: only the rows a channel actually reads carry
    // an event, and the rest have to read as empty rather than as leftovers.
    for (int i = 0; i < cells; i++) {
        memset(&out[i], 0, sizeof(out[i]));
        out[i].note = REWAMP_NOTE_EMPTY;
        out[i].instrument = -1;
        out[i].volume = -1;
        for (int f = 0; f < REWAMP_PATTERN_MAX_FX; f++) out[i].fxval[f] = -1;
    }
    // Chip one reads straight from the requested position.
    pt3_decode_position(dec->mod[0], dec->modTS[0], pattern,
                        out, usableRows, chans, 0, 1, NULL);
    if (dec->numChips <= 1) return cells;

    // The others are decoded one position at a time — a chip-one pattern spans
    // very few of theirs — and their rows are picked by tick.
    RewampPatternCell* scratch =
        (RewampPatternCell*)malloc((size_t)256 * 3 * sizeof(RewampPatternCell));
    if (!scratch) return cells;
    const int base = dec->tlPosStart[0][pattern];
    for (int ch = 1; ch < dec->numChips; ch++) {
        int loadedPos = -1;
        for (int r = 0; r < usableRows; r++) {
            const int idx = base + r;
            if (idx >= dec->tlCount[0]) break;
            const uint32_t tick = dec->tlTick[0][idx];
            const uint32_t next = idx + 1 < dec->tlCount[0] ? dec->tlTick[0][idx + 1]
                                                            : dec->tlTotal[0];
            const int li = pt3_first_line_in(dec, ch, tick, next > tick ? next - tick : 1);
            if (li < 0) continue;
            const int srcPos = dec->tlPos[ch][li], srcRow = dec->tlRow[ch][li];
            if (srcPos != loadedPos) {
                for (int i = 0; i < 256 * 3; i++) {
                    memset(&scratch[i], 0, sizeof(scratch[i]));
                    scratch[i].note = REWAMP_NOTE_EMPTY;
                    scratch[i].instrument = -1;
                    scratch[i].volume = -1;
                    for (int f = 0; f < REWAMP_PATTERN_MAX_FX; f++) scratch[i].fxval[f] = -1;
                }
                pt3_decode_position(dec->mod[ch], dec->modTS[ch], srcPos,
                                    scratch, 256, 3, 0, 1, NULL);
                loadedPos = srcPos;
            }
            if (srcRow >= 256) continue;
            for (int c = 0; c < 3; c++)
                out[(size_t)r * chans + ch * 3 + c] = scratch[(size_t)srcRow * 3 + c];
        }
    }
    free(scratch);
    return cells;
}

static void pt3_pattern_cursor(RewampDecoder* dec, int* order, int* row) {
    int pos = -1, r = -1;
    if (dec && dec->patternsOk) func_get_cursor(0, &pos, &r);
    if (order) *order = pos;
    if (row)   *row   = r;
}

static const RewampPluginVTable kPt3VTable = {
    "libpt3",
    pt3_probe,
    pt3_open,
    pt3_read,
    pt3_seek,
    pt3_length,
    pt3_close,
    NULL,                     /* configure_loop */
    0,                        /* supportsNativeFadeout */
    NULL,                     /* engine_id */
    NULL,                     /* param_changed */
    pt3_pattern_song_info,    /* pattern view */
    pt3_pattern_order,
    pt3_pattern_num_rows,
    pt3_pattern_get,
    pt3_pattern_cursor,
};

extern "C" const RewampPluginVTable* rewamp_libpt3_plugin(void) { return &kPt3VTable; }

#endif /* REWAMP_WITH_LIBPT3 */
