// TIATracker plugin — Atari VCS 2600 music (.ttt), the project files of
// Andre "Kylearan" Wichmann's TIATracker (bitbucket.org/kylearan/tiatracker).
//
// Three layers, and only the middle one is ours to get right:
//   1. the file is JSON — parsed and converted to the VCS replay tables in
//      src/tiatracker/ttt_song.cpp;
//   2. the replayer — src/tiatracker/ttt_player.cpp, a transcription of
//      TIATracker's own 6502 routine, which is published under Apache-2.0
//      (the tracker APPLICATION is GPLv2, its player routine is not);
//   3. TIA sound emulation — Stella's, vendored at third_party/tiasound with
//      its namespace renamed to TttTia (furnace ships the same classes as
//      `namespace TIA`, and reusing those would tie .ttt support to
//      REWAMP_WITH_FURNACE).
//
// Fidelity: the JSON→tables conversion was checked against the tracker's OWN
// exported trackdata for six songs, then both were run through the same
// replayer semantics — 20 000 frames of AUDC/AUDF/AUDV per song, zero
// divergence.
//
// The player is a PUSH engine at the TV frame rate (50 Hz PAL / 60 Hz NTSC)
// driving a chip that runs at the colour clock, so the read loop below is
// clock-accurate rather than block-based: every output sample advances the
// colour-clock accumulator, a video frame boundary runs one player frame and
// pushes the six registers, and the TIA core is ticked for exactly the
// duration of that sample. No resampler — the chip updates its output at
// ~31.4 kHz and the hardware holds it, which is what the zero-order read at
// 44.1 kHz reproduces.
#ifdef REWAMP_WITH_TIATRACKER

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"
#include "tiatracker/ttt_player.h"
#include "tiatracker/ttt_song.h"
// Relative on purpose: "Audio.h" is as generic as a header name gets, and no
// engine here is worth putting third_party/ on a pod-wide search path for.
#include "../third_party/tiasound/Audio.h"

#include <math.h>
#include <new>
#include <vector>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define TTT_RATE        44100
#define TTT_VOICES      2
#define TTT_RING        (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)   // 4096
#define TTT_MAX_MINUTES 20
// Rows per page in the pattern view (see ttt_build_pattern_table).
#define TTT_PAGE_ROWS   64
#define TTT_MAX_ROWS    32768

// TIA register addresses, as the replayer writes them.
enum { kAudC0 = 0x15, kAudC1 = 0x16, kAudF0 = 0x17, kAudF1 = 0x18,
       kAudV0 = 0x19, kAudV1 = 0x1a };

struct RewampDecoder {
    TttTables     song;
    TttPlayer     player;
    TttTia::Audio tia;

    double   colorClock;        // TIA clock, PAL and NTSC differ
    double   clocksPerSample;   // colour clocks in one 44.1 kHz sample
    double   clocksPerFrame;    // colour clocks in one TV frame
    double   frameAcc;          // clocks accumulated towards the next TV frame
    double   tickAcc;           // fractional colour clocks owed to the core

    uint64_t framePos;          // output frames produced
    uint64_t totalFrames;       // 0 when the song never repeats
    int64_t  lastMuteMask;

    // Pattern view: the song's row timeline, 2 cells per row (see
    // ttt_build_pattern_table for why it is a timeline and not a pattern list).
    std::vector<RewampPatternCell> patCells;
    int      patRows;
    int64_t  rowIndex;          // live cursor, in rows since the start
};

static const char* const kTttExts[] = { "ttt", NULL };

// Divisor each AUDC waveform applies on top of the (AUDF+1) counter: the
// pre-divider times the polynomial-counter length, i.e. how often the output
// pattern repeats. Reported as the voice's pitch to the notes/pattern views.
//
// It is tempting to report only the "pure" waveforms (4/5, 12/13, 6/10, 14)
// and call the polynomial ones noise. That is wrong for this machine, and it
// showed: "Synth Blast" (Zoltar X) writes its bass on AUDC 2, its buzz bass on
// AUDC 1 and a lead on AUDC 3, so half the song had no notes at all in the
// visualizers. On a 2-voice console the buzzy distortions ARE melodic
// material — only 0 and 11 (the constant-output ones) are truly silent.
// AUDC 8 is genuine white noise; its 9-bit poly still has a repeat rate, and
// showing the drum hits beats showing an empty channel.
static const int kToneDiv[16] = {
      0,  15, 225, 465,   // 0 silence, 1 poly4, 2 ÷15→poly4, 3 poly5→poly4
      2,   2,  31,  31,   // 4/5 pure, 6 ÷31, 7 poly5
    511,  31,  31,   0,   // 8 poly9 (noise), 9 poly5, 10 ÷31, 11 silence
      6,   6,  93,  93    // 12/13 pure ÷3, 14 ÷93, 15 poly5 ÷3
};

// The pitch a channel actually repeats at, in Hz. 0 when the waveform makes no
// periodic output at all (AUDC 0 and 11 hold their output constant).
static double ttt_pitch_hz(double colorClock, int audc, int audf) {
    const int div = kToneDiv[audc & 0x0f];
    if (div <= 0) return 0.0;
    return (colorClock / 114.0) / (double)((audf + 1) * div);
}

// Semitone index for the pattern view, 0 = C-0 (16.35 Hz).
static int ttt_semitone(double hz) {
    if (hz <= 0.0) return REWAMP_NOTE_EMPTY;
    const int n = (int)lround(12.0 * log2(hz / 16.351597831287414));
    if (n < 0 || n > 127) return REWAMP_NOTE_EMPTY;
    return n;
}

// One pass over the whole song, recording what each channel plays on every
// row. TIATracker gives each channel its OWN sequence of patterns, of
// independent lengths, so "a pattern" in this format is a single-channel
// object and the pattern view's rows × channels grid does not exist as such.
// What does exist: the sequencer advances BOTH channels on the same tick, so
// rows are aligned in TIME. This walks that timeline once and cuts it into
// fixed pages — exact, aligned, and stable across the song's repeats (the
// cost being that a pattern played twice shows up as two pages).
static void ttt_build_pattern_table(RewampDecoder* dec) {
    dec->patCells.clear();
    dec->patRows = 0;

    const int fps = dec->song.frameRateHz();
    int64_t frames = dec->totalFrames > 0
        ? (int64_t)((double)dec->totalFrames / TTT_RATE * fps)
        : (int64_t)fps * 60 * TTT_MAX_MINUTES;

    TttPlayer p;
    p.reset(&dec->song);
    for (int64_t f = 0; f < frames && dec->patRows < TTT_MAX_ROWS; ++f) {
        p.frame();
        if (!p.newRow) continue;
        for (int ch = 0; ch < TTT_VOICES; ++ch) {
            RewampPatternCell c;
            memset(&c, 0, sizeof(c));
            c.note       = REWAMP_NOTE_EMPTY;
            c.instrument = -1;
            c.volume     = -1;
            c.num_fx     = 0;
            for (int k = 0; k < REWAMP_PATTERN_MAX_FX; ++k) c.fxval[k] = -1;

            const int note = p.rowNote[ch];
            if (note == kTttNotePause) {
                c.note = REWAMP_NOTE_OFF;           // into release, then silence
            } else if (note < kTttNotePause) {
                // Hold (8) leaves the row empty; anything else is a slide, whose
                // amount is the byte minus 8.
                if (note != kTttNoteHold && note != kTttNoteEndOfPattern) {
                    c.fx[0][0] = 'S';
                    c.fxval[0] = note - 8;
                    c.num_fx   = 1;
                }
            } else if (note < 32) {
                // Percussion: its pitch is fixed by its own first frame.
                const int idx   = note - kTttNoteFirstPerc;
                const int start = (idx >= 0 && idx < (int)dec->song.percIndex.size())
                    ? dec->song.percIndex[idx] - 1 : -1;
                if (start >= 0 && start < (int)dec->song.percCtrlVol.size()) {
                    const int wf = (dec->song.percCtrlVol[start] >> 4) & 0x0f;
                    const int fq = dec->song.percFreq[start] & kTttFreqMask;
                    c.note = (int16_t)ttt_semitone(ttt_pitch_hz(dec->colorClock, wf, fq));
                }
                // Percussion numbering continues after the 7 melodic slots so
                // the two are told apart at a glance in the instrument column.
                c.instrument = 8 + idx;
            } else {
                const int slot = note >> 5;
                const int freq = note & kTttFreqMask;
                const int wf = (slot >= 1 && slot <= (int)dec->song.insCtrl.size())
                    ? dec->song.insCtrl[slot - 1] : 0;
                c.note       = (int16_t)ttt_semitone(ttt_pitch_hz(dec->colorClock, wf, freq));
                c.instrument = slot;
            }
            dec->patCells.push_back(c);
        }
        ++dec->patRows;
    }
}

static int ttt_pattern_song_info(RewampDecoder* dec, RewampPatternSongInfo* out) {
    if (!dec || !out || dec->patRows <= 0) return 0;
    const int pages = (dec->patRows + TTT_PAGE_ROWS - 1) / TTT_PAGE_ROWS;
    out->num_channels = TTT_VOICES;
    out->num_orders   = pages;
    out->num_patterns = pages;
    out->max_fx_cols  = 1;
    out->instr_digits = 2;
    out->vol_chars    = -1;   // negative = the column does not exist: a TIA row
                              // carries no volume, the instrument envelope does
    out->fxcode_chars = 0;
    out->fxval_digits = 2;
    return 1;
}

static int ttt_pattern_order(RewampDecoder* dec, int order) {
    if (!dec || order < 0) return -1;
    const int pages = (dec->patRows + TTT_PAGE_ROWS - 1) / TTT_PAGE_ROWS;
    return order < pages ? order : -1;   // pages are their own order
}

static int ttt_pattern_num_rows(RewampDecoder* dec, int pattern) {
    if (!dec || pattern < 0) return 0;
    const int start = pattern * TTT_PAGE_ROWS;
    if (start >= dec->patRows) return 0;
    const int left = dec->patRows - start;
    return left < TTT_PAGE_ROWS ? left : TTT_PAGE_ROWS;
}

static int ttt_pattern_get(RewampDecoder* dec, int pattern,
                           RewampPatternCell* out, int maxCells) {
    if (!dec || !out) return 0;
    const int rows = ttt_pattern_num_rows(dec, pattern);
    if (rows <= 0) return 0;
    int cells = rows * TTT_VOICES;
    if (cells > maxCells) cells = maxCells - (maxCells % TTT_VOICES);
    if (cells <= 0) return 0;
    memcpy(out, &dec->patCells[(size_t)pattern * TTT_PAGE_ROWS * TTT_VOICES],
           (size_t)cells * sizeof(RewampPatternCell));
    return cells;
}

static void ttt_pattern_cursor(RewampDecoder* dec, int* order, int* row) {
    if (!dec || dec->patRows <= 0 || dec->rowIndex < 0) {
        if (order) *order = -1;
        if (row)   *row   = -1;
        return;
    }
    const int64_t r = dec->rowIndex < dec->patRows ? dec->rowIndex : dec->patRows - 1;
    if (order) *order = (int)(r / TTT_PAGE_ROWS);
    if (row)   *row   = (int)(r % TTT_PAGE_ROWS);
}

static int ttt_plugin_probe(const char* ext, const uint8_t* header, size_t n) {
    const bool extOk = rewamp_ext_in_list(ext, kTttExts) != 0;
    // A .ttt is JSON, so the header alone can confirm it outright — but the
    // extension is what makes it cheap, and no other format in the registry
    // claims it.
    if (header && n > 0 && ttt_probe(header, n)) return extOk ? 95 : 80;
    return extOk ? 60 : 0;
}

static void ttt_push_registers(RewampDecoder* dec) {
    const TttPlayer& p = dec->player;
    dec->tia.write(kAudC0, p.audc[0]);
    dec->tia.write(kAudC1, p.audc[1]);
    dec->tia.write(kAudF0, p.audf[0]);
    dec->tia.write(kAudF1, p.audf[1]);
    // Muting a voice is a volume write, not a state change in the player, so
    // the song keeps running exactly as it would unmuted.
    dec->tia.write(kAudV0, (generic_mute_mask & 1LL) ? 0 : p.audv[0]);
    dec->tia.write(kAudV1, (generic_mute_mask & 2LL) ? 0 : p.audv[1]);

    for (int v = 0; v < TTT_VOICES; ++v) {
        const bool muted = (generic_mute_mask & (1LL << v)) != 0;
        const double hz = ttt_pitch_hz(dec->colorClock, p.audc[v], p.audf[v]);
        if (hz > 0.0 && p.audv[v] > 0 && !muted) {
            vgm_last_note[v] = (unsigned)hz;
            vgm_last_vol[v]  = (unsigned)(p.audv[v] * 17); // 0..15 → 0..255
        } else {
            vgm_last_note[v] = 0;
            vgm_last_vol[v]  = 0;
        }
    }
}

static void ttt_prepare_chip(RewampDecoder* dec) {
    dec->tia.reset(false);      // mono: myCurrentSample[0] is the summed output
    dec->frameAcc = dec->clocksPerFrame;   // frame one runs the player at once
    dec->tickAcc  = 0.0;
}

static RewampDecoder* ttt_open(const char* path, RewampAudioFormat* outFormat) {
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
    if (size <= 0 || size > 32 * 1024 * 1024) { fclose(f); return NULL; }
    char* buf = (char*)malloc((size_t)size);
    if (!buf) { fclose(f); return NULL; }
    const size_t got = fread(buf, 1, (size_t)size, f);
    fclose(f);
    if (got != (size_t)size) { free(buf); return NULL; }

    RewampDecoder* dec = new (std::nothrow) RewampDecoder();
    if (!dec) { free(buf); return NULL; }

    std::string err;
    if (!ttt_parse(buf, (size_t)size, dec->song, &err)) {
        free(buf);
        delete dec;
        return NULL;
    }
    free(buf);

    // PAL and NTSC differ in both tuning (the colour clock the audio divider
    // runs off) and tempo (50 vs 60 player frames per second).
    dec->colorClock      = dec->song.pal ? 3546894.0 : 3579545.0;
    dec->clocksPerSample = dec->colorClock / (double)TTT_RATE;
    dec->clocksPerFrame  = dec->colorClock / (double)dec->song.frameRateHz();
    dec->framePos        = 0;
    dec->lastMuteMask    = generic_mute_mask;

    // Per-voice oscilloscope: two channels, and they must be reset BEFORE the
    // first decode so the ring buffers exist when the read loop writes them.
    m_genNumVoicesChannels = TTT_VOICES;
    rewamp_channel_data_reset(TTT_VOICES);
    rewamp_channel_data_set_ring_write_size(TTT_RING);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("TIA", 0, TTT_VOICES);
    rewamp_voice_set_name(0, "Channel 0");
    rewamp_voice_set_name(1, "Channel 1");

    // Length: the song repeats when both channels return to a sequence
    // position they have been at together. A song without a goto never does —
    // the VCS routine's behaviour past the end is explicitly undefined — so
    // length() reports 0 and the generic end-of-stream handling applies.
    int loopStart = 0;
    const int lenFrames = ttt_song_length_frames(
        dec->song, dec->song.frameRateHz() * 60 * TTT_MAX_MINUTES, &loopStart);
    dec->totalFrames = lenFrames > 0
        ? (uint64_t)((double)lenFrames / dec->song.frameRateHz() * TTT_RATE)
        : 0;

    ttt_build_pattern_table(dec);
    dec->rowIndex = -1;   // no row consumed yet
    dec->player.reset(&dec->song);
    ttt_prepare_chip(dec);

    if (!dec->song.name.empty())
        rewamp_track_message_append("%s\n", dec->song.name.c_str());
    if (!dec->song.author.empty())
        rewamp_track_message_append("By: %s\n", dec->song.author.c_str());
    rewamp_track_message_append("Format: TIATracker (Atari VCS 2600 TIA), %s, %d Hz replay\n",
                                dec->song.pal ? "PAL" : "NTSC", dec->song.frameRateHz());
    rewamp_track_message_append("Tempo: %d%s frames per row\n", dec->song.speedEven,
                                dec->song.useFunkTempo ? " (even) / funktempo" : "");
    if (dec->totalFrames > 0) {
        const unsigned secs = (unsigned)(dec->totalFrames / TTT_RATE);
        rewamp_track_message_append("Duration: %u:%02u\n", secs / 60, secs % 60);
    }
    if (!dec->song.comment.empty())
        rewamp_track_message_append("\n%s\n", dec->song.comment.c_str());

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = TTT_RATE;
    }
    return dec;
}

static uint64_t ttt_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !out || frameCount == 0) return 0;
    if (dec->totalFrames > 0) {
        if (dec->framePos >= dec->totalFrames) return 0;
        const uint64_t remain = dec->totalFrames - dec->framePos;
        if (frameCount > remain) frameCount = remain;
    }
    if (dec->lastMuteMask != generic_mute_mask) {
        dec->lastMuteMask = generic_mute_mask;
        ttt_push_registers(dec);   // apply immediately, do not wait for a row
    }

    signed char* v0 = m_voice_buff[0];
    signed char* v1 = m_voice_buff[1];
    const int64_t ptr0 = m_voice_current_ptr[0] >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
    const int64_t ptr1 = m_voice_current_ptr[1] >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT;

    const float scale = 1.0f / 32768.0f;
    for (uint64_t i = 0; i < frameCount; ++i) {
        dec->frameAcc += dec->clocksPerSample;
        while (dec->frameAcc >= dec->clocksPerFrame) {
            dec->frameAcc -= dec->clocksPerFrame;
            dec->player.frame();
            if (dec->player.newRow) ++dec->rowIndex;
            ttt_push_registers(dec);
        }

        // Advance the chip by exactly one output sample's worth of colour
        // clocks, carrying the fraction so the ~31.4 kHz update grid does not
        // drift against 44.1 kHz.
        dec->tickAcc += dec->clocksPerSample;
        const int ticks = (int)dec->tickAcc;
        if (ticks > 0) {
            dec->tickAcc -= (double)ticks;
            dec->tia.tick(ticks);
        }

        const float s = (float)dec->tia.myCurrentSample[0] * scale;
        out[i * 2 + 0] = s;
        out[i * 2 + 1] = s;   // the TIA is mono

        if (v0) v0[(ptr0 + (int64_t)i) & (TTT_RING - 1)] =
            (signed char)(dec->tia.myChannelOut[0] >> 8);
        if (v1) v1[(ptr1 + (int64_t)i) & (TTT_RING - 1)] =
            (signed char)(dec->tia.myChannelOut[1] >> 8);
    }

    for (int v = 0; v < TTT_VOICES; ++v)
        m_voice_current_ptr[v] += (int64_t)frameCount << MODIZER_OSCILLO_OFFSET_FIXEDPOINT;

    dec->framePos += frameCount;
    return frameCount;
}

static void ttt_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec) return;
    if (dec->totalFrames > 0 && frameIndex > dec->totalFrames)
        frameIndex = dec->totalFrames;

    // No native seek: replay the sequencer from the top. Only the player runs
    // (a few thousand trivial frames even for a long song); the chip is reset
    // and re-primed from the registers the target row leaves behind, which is
    // the same state it would have been in bar the tail of one waveform.
    dec->player.reset(&dec->song);
    ttt_prepare_chip(dec);

    const double clocks = (double)frameIndex * dec->clocksPerSample;
    const int64_t frames = (int64_t)(clocks / dec->clocksPerFrame);
    dec->rowIndex = -1;
    for (int64_t i = 0; i < frames; ++i) {
        dec->player.frame();
        // The pattern cursor is a row COUNT, so it has to be recounted here —
        // the replay is deterministic, so this lands on exactly the row the
        // table was built with.
        if (dec->player.newRow) ++dec->rowIndex;
    }
    dec->frameAcc = clocks - (double)frames * dec->clocksPerFrame;
    ttt_push_registers(dec);

    dec->framePos = frameIndex;
}

static uint64_t ttt_length(RewampDecoder* dec) {
    return dec ? dec->totalFrames : 0;
}

static void ttt_close(RewampDecoder* dec) {
    delete dec;
}

static const RewampPluginVTable kTiaTrackerPlugin = {
    "tiatracker",
    ttt_plugin_probe,
    ttt_open,
    ttt_read,
    ttt_seek,
    ttt_length,
    ttt_close,
    NULL,                    /* configure_loop */
    0,                       /* supportsNativeFadeout */
    NULL,                    /* engine_id */
    NULL,                    /* param_changed */
    ttt_pattern_song_info,   /* pattern view */
    ttt_pattern_order,
    ttt_pattern_num_rows,
    ttt_pattern_get,
    ttt_pattern_cursor,
};

extern "C" const RewampPluginVTable* rewamp_tiatracker_plugin(void) {
    return &kTiaTrackerPlugin;
}

#endif  // REWAMP_WITH_TIATRACKER
