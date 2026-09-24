// libxmp plugin — the module formats libopenmpt does NOT know.
//
// rewamp already plays MOD/XM/IT/S3M and friends through libopenmpt, which is
// the better replayer for those. libxmp earns its place on the ~10 formats it
// alone loads — Archimedes Tracker (.musx), Liquid Tracker (.liq/.no),
// Funktracker (.fnk), Megatracker (.mgt), Slamtilt (.stim), Quadra Composer
// (.emod), Magnetic Fields Packer (.mfp), Coconizer (.coco), MUSE (.muse).
//
// Scoring therefore stays BELOW libopenmpt everywhere the two overlap: an
// extension match scores 60, and a content confirmation (libxmp's own
// xmp_test_module on the real file, via probe_path) scores 90 — one notch
// under libopenmpt's 100 for "extension + header confirmed", so a .mod still
// goes to libopenmpt while a file no other plugin recognizes lands here.
//
// Compiled only when REWAMP_WITH_XMP is defined.
#ifdef REWAMP_WITH_XMP

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

/* Chemin relatif plutôt qu'un chemin d'inclusion: comme pour prowizard, rien
 * de l'arbre libxmp ne doit atteindre la recherche d'en-têtes des autres TU
 * (common.h, mixer.h, player.h, format.h, loader.h y vivent). */
#include "../third_party/libxmp/include/xmp.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// libxmp renders at whatever rate we ask; ask for the ring's rate (44100)
// like libopenmpt does, so the producer never resamples for nothing.
#define XMP_RENDER_RATE     44100
#define XMP_RENDER_CHANNELS 2

// Frames per xmp_play_buffer call. libxmp fills in whole internal ticks, so a
// generous chunk keeps the call count low; read() tops it up in a loop anyway.
#define XMP_CHUNK_FRAMES    4096

struct RewampDecoder {
    xmp_context ctx;
    int         started;        // xmp_start_player succeeded (needs end_player)
    int         loaded;         // module loaded (needs release_module)
    int         loopParam;      // xmp_play_buffer's `loop` argument
    int         ended;          // the module signalled end of replay
    int         numChannels;
    int         volBase;        // libxmp's volume scale for this module
    struct xmp_module* mod;     // borrowed from xmp_get_module_info (transpose)
    int64_t     lastMuteMask;
    int16_t     pcm[XMP_CHUNK_FRAMES * XMP_RENDER_CHANNELS];

    // Immutable pattern table for the pattern visualizer, built in open().
    int                 patChannels;
    int                 patNumOrders;
    int                 patNumPatterns;
    int32_t*            patOrder;
    int32_t*            patRows;
    RewampPatternCell** patCells;

    // Live (order,row) cursor, refreshed by read() from xmp_get_frame_info.
    int                 curOrder, curRow;
};

// Extensions libxmp is the ONLY engine here to load. Deliberately short: every
// mainstream tracker extension belongs to libopenmpt, and adding one here
// would only create a probe fight it has to lose anyway.
static const char* const kXmpExts[] = {
    "musx",   // Archimedes Tracker (MUSX)
    "liq",    // Liquid Tracker
    "no",     // Liquid Tracker NO
    "fnk",    // Funktracker
    "mgt",    // Megatracker
    "stim",   // Slamtilt
    "emod",   // Quadra Composer
    "mfp",    // Magnetic Fields Packer
    "coco",   // Coconizer
    "muse",   // MUSE container
    NULL
};

static int xmp_plugin_probe(const char* ext, const uint8_t* header, size_t headerSize) {
    (void)header; (void)headerSize;
    return rewamp_ext_in_list(ext, kXmpExts) ? 60 : 0;
}

/* Content probe on the REAL file: libxmp identifies most of its formats from
 * magic bytes, but several (Archimedes, Coconizer) validate structure past the
 * header window the registry hands out — xmp_test_module reads the file itself
 * and never loads samples, so it is cheap and it is the authority. */
static int xmp_plugin_probe_path(const char* ext, const uint8_t* header,
                                 size_t headerSize, const char* path,
                                 uint64_t fileSize) {
    (void)header; (void)headerSize; (void)fileSize;
    int extMatch = rewamp_ext_in_list(ext, kXmpExts);
    if (path != NULL) {
        struct xmp_test_info info;
        if (xmp_test_module((char*)path, &info) == 0)
            return extMatch ? 100 : 90;
    }
    return extMatch ? 60 : 0;
}

static void xmp_apply_engine_params(xmp_context ctx) {
    int interp = (int)rewamp_get_engine_param("xmp", "interpolation", XMP_INTERP_SPLINE);
    int ssep   = (int)rewamp_get_engine_param("xmp", "stereo_sep", 70);
    int amp    = (int)rewamp_get_engine_param("xmp", "amplify", 1);
    int vol    = (int)rewamp_get_engine_param("xmp", "master_volume", 100);
    int dsp    = (int)rewamp_get_engine_param("xmp", "dsp_lowpass", 1);
    int a500   = (int)rewamp_get_engine_param("xmp", "amiga_mixer", 0);

    if (interp < 0) interp = 0;
    if (interp > XMP_INTERP_SPLINE) interp = XMP_INTERP_SPLINE;
    if (ssep < 0)   ssep = 0;
    if (ssep > 100) ssep = 100;
    if (amp < 0)    amp = 0;
    if (amp > 3)    amp = 3;
    if (vol < 0)    vol = 0;
    if (vol > 200)  vol = 200;

    xmp_set_player(ctx, XMP_PLAYER_INTERP, interp);
    xmp_set_player(ctx, XMP_PLAYER_MIX,    ssep);
    xmp_set_player(ctx, XMP_PLAYER_AMP,    amp);
    xmp_set_player(ctx, XMP_PLAYER_VOLUME, vol);
    xmp_set_player(ctx, XMP_PLAYER_DSP,    dsp ? XMP_DSP_ALL : 0);
    /* CFLAGS is the per-module copy of FLAGS — the one that takes effect on
     * the loaded module. A500 only does anything on Amiga-lineage modules,
     * libxmp checks that itself. */
    {
        int flags = xmp_get_player(ctx, XMP_PLAYER_CFLAGS);
        if (a500) flags |= XMP_FLAGS_A500;
        else      flags &= ~XMP_FLAGS_A500;
        xmp_set_player(ctx, XMP_PLAYER_CFLAGS, flags);
    }
}

static void xmp_plugin_param_changed(RewampDecoder* dec, const char* key) {
    (void)key;
    if (dec && dec->ctx) xmp_apply_engine_params(dec->ctx);
}

static void xmp_build_patterns(RewampDecoder* dec, struct xmp_module* mod);
static void xmp_free_patterns(RewampDecoder* dec);

static RewampDecoder* xmp_plugin_open(const char* path, RewampAudioFormat* outFormat) {
    // ?subsong=N → sequence N (0-based), applied through its entry point.
    char clean[4096];
    int subsong = 0;
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    {
        char* q = strrchr(clean, '?');
        if (q && strncmp(q, "?subsong=", 9) == 0) { subsong = atoi(q + 9); *q = '\0'; }
    }

    xmp_context ctx = xmp_create_context();
    if (ctx == NULL) return NULL;

    if (xmp_load_module(ctx, clean) < 0) {
        xmp_free_context(ctx);
        return NULL;
    }

    if (xmp_start_player(ctx, XMP_RENDER_RATE, 0) != 0) {
        xmp_release_module(ctx);
        xmp_free_context(ctx);
        return NULL;
    }

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(RewampDecoder));
    if (dec == NULL) {
        xmp_end_player(ctx);
        xmp_release_module(ctx);
        xmp_free_context(ctx);
        return NULL;
    }
    dec->ctx     = ctx;
    dec->started = 1;
    dec->loaded  = 1;
    dec->loopParam = 1;          // play once unless configure_loop says otherwise
    dec->curOrder = dec->curRow = -1;

    xmp_apply_engine_params(ctx);

    struct xmp_module_info mi;
    xmp_get_module_info(ctx, &mi);
    struct xmp_module* mod = mi.mod;

    // Sequence (subsong) selection: each sequence starts at its own order.
    if (subsong > 0 && subsong < mi.num_sequences && mi.seq_data != NULL)
        xmp_set_position(ctx, mi.seq_data[subsong].entry_point);

    dec->volBase = (mi.vol_base > 0) ? mi.vol_base : 64;
    dec->mod     = mod;

    int numChannels = mod->chn;
    if (numChannels < 1) numChannels = 1;
    if (numChannels > SOUND_MAXVOICES_BUFFER_FX) numChannels = SOUND_MAXVOICES_BUFFER_FX;
    dec->numChannels = numChannels;

    // Voice capture must be armed BEFORE the first decode (PLUGINS.md §2.6).
    m_genNumVoicesChannels = numChannels;
    rewamp_channel_data_reset(numChannels);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);

    rewamp_voices_meta_reset();
    {
        char chip[MODIZ_CHIP_NAME_MAX_CHAR];
        const char* type = (mod->type[0] != '\0') ? mod->type : "Tracker";
        snprintf(chip, sizeof(chip), "%s", type);
        rewamp_voices_add_chip(chip, 0, numChannels);
    }

    // ⓘ panel: title, format, comment, instrument and sample names.
    if (mod->name[0]) rewamp_track_message_append("Title: %s\n", mod->name);
    if (mod->type[0]) rewamp_track_message_append("Type: %s\n", mod->type);
    rewamp_track_message_append("Channels: %d\n", mod->chn);
    if (mi.num_sequences > 1)
        rewamp_track_message_append("Sequences: %d\n", mi.num_sequences);
    if (mi.comment && mi.comment[0])
        rewamp_track_message_append("\n%s\n", mi.comment);

    if (mod->ins > 0) {
        rewamp_track_message_append("\nInstruments:\n");
        for (int i = 0; i < mod->ins; i++) {
            const char* nm = mod->xxi[i].name;
            rewamp_track_message_append("%02d: %s\n", i + 1, nm ? nm : "");
            /* The viz timeline carries the pattern's 1-based instrument
             * number; the same index names the "by instrument" legend. */
            if (nm && nm[0]) rewamp_instrument_set_name(i + 1, nm);
        }
    }
    if (mod->smp > 0 && mod->ins <= 0) {
        rewamp_track_message_append("\nSamples:\n");
        for (int i = 0; i < mod->smp; i++) {
            const char* nm = mod->xxs[i].name;
            rewamp_track_message_append("%02d: %s\n", i + 1, nm ? nm : "");
            if (nm && nm[0]) rewamp_instrument_set_name(i + 1, nm);
        }
    }

    xmp_build_patterns(dec, mod);

    if (outFormat != NULL) {
        outFormat->channels   = XMP_RENDER_CHANNELS;
        outFormat->sampleRate = XMP_RENDER_RATE;
    }
    return dec;
}

/* Instrument transpose applied to a key, exactly as read_event.c does it. */
static int xmp_transpose(const RewampDecoder* dec, const struct xmp_channel_info* ci) {
    const struct xmp_module* mod = dec->mod;
    if (mod == NULL || mod->xxi == NULL) return 0;
    int ins = ci->instrument;
    int key = ci->note;
    if (ins < 0 || ins >= mod->ins) return 0;
    if (key < 0 || key >= XMP_MAX_KEYS) return 0;
    const struct xmp_instrument* xxi = &mod->xxi[ins];
    int sub = xxi->map[key].ins;
    int xpo = xxi->map[key].xpo;
    if (xxi->sub != NULL && sub >= 0 && sub < xxi->nsm) xpo += xxi->sub[sub].xpo;
    return xpo;
}

static uint64_t xmp_plugin_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (dec == NULL || dec->ctx == NULL || dec->ended) return 0;

    // Mute: libxmp's own per-channel mute silences the REAL mix, so a muted
    // voice also writes silence into the scope (its mix delta is zero).
    if (dec->lastMuteMask != generic_mute_mask) {
        dec->lastMuteMask = generic_mute_mask;
        for (int j = 0; j < dec->numChannels; j++)
            xmp_channel_mute(dec->ctx, j, (int)((generic_mute_mask >> j) & 1));
    }

    uint64_t done = 0;
    while (done < frameCount) {
        uint64_t want = frameCount - done;
        if (want > XMP_CHUNK_FRAMES) want = XMP_CHUNK_FRAMES;

        int bytes = (int)(want * XMP_RENDER_CHANNELS * sizeof(int16_t));
        if (xmp_play_buffer(dec->ctx, dec->pcm, bytes, dec->loopParam) != 0) {
            dec->ended = 1;
            break;
        }
        for (uint64_t i = 0; i < want * XMP_RENDER_CHANNELS; i++)
            out[(done * XMP_RENDER_CHANNELS) + i] = dec->pcm[i] * (1.0f / 32768.0f);
        done += want;
    }

    // Per-channel note / volume / instrument, from the frame we just rendered.
    struct xmp_frame_info fi;
    xmp_get_frame_info(dec->ctx, &fi);
    dec->curOrder = fi.pos;
    dec->curRow   = fi.row;
    for (int j = 0; j < dec->numChannels && j < XMP_MAX_CHANNELS; j++) {
        const struct xmp_channel_info* ci = &fi.channel_info[j];
        if (ci->volume > 0 && ci->period > 0) {
            /* ci->note is the KEY the pattern pressed, NOT the pitch: libxmp
             * adds the instrument's transpose only when it computes the
             * period (read_event.c: key + sub->xpo + map[key].xpo). Reporting
             * the bare key made every voice of an instrument with a relative
             * note come out transposed — and only SOME voices, which is why a
             * single constant offset looked right on one module and wrong on
             * the next. libopenmpt reports the SOUNDING note, so we must too.
             *
             * Key 60 is middle C in libxmp's scale (PERIOD_BASE/2^(60/12) =
             * 428, the Amiga period every tracker calls C), the same number
             * libopenmpt reports, so no octave constant is needed on top.
             * pitchbend is in cents from the key. */
            double note = (double)ci->note + xmp_transpose(dec, ci)
                        + (double)ci->pitchbend / 100.0;
            vgm_last_note[j] = (unsigned int)(440.0 * pow(2.0, (note - 69.0) / 12.0));
        } else {
            vgm_last_note[j] = 0;
        }
        /* vgm_last_vol is 0..255 everywhere; libxmp reports 0..vol_base and
         * vol_base is per FORMAT (64 for MOD, 128 for IT). */
        {
            int v = ci->volume * 255 / dec->volBase;
            vgm_last_vol[j] = (unsigned int)(v > 255 ? 255 : (v < 0 ? 0 : v));
        }
        vgm_last_instr[j] = (unsigned char)(ci->instrument + 1);
    }
    return done;
}

static void xmp_plugin_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (dec == NULL || dec->ctx == NULL) return;
    int ms = (int)((double)frameIndex * 1000.0 / (double)XMP_RENDER_RATE);
    xmp_seek_time(dec->ctx, ms);
    /* A decoder that reported end of replay must come back to life after a
     * seek — the generic "relance" path in PlayerController does seek(0)+play
     * and would otherwise get silence forever. */
    dec->ended = 0;
}

static uint64_t xmp_plugin_length(RewampDecoder* dec) {
    if (dec == NULL || dec->ctx == NULL) return 0;
    struct xmp_frame_info fi;
    xmp_get_frame_info(dec->ctx, &fi);
    if (fi.total_time <= 0) return 0;
    return (uint64_t)((double)fi.total_time * XMP_RENDER_RATE / 1000.0);
}

static void xmp_plugin_close(RewampDecoder* dec) {
    if (dec == NULL) return;
    xmp_free_patterns(dec);
    if (dec->ctx) {
        if (dec->started) xmp_end_player(dec->ctx);
        if (dec->loaded)  xmp_release_module(dec->ctx);
        xmp_free_context(dec->ctx);
    }
    free(dec);
}

/* Native forced loop: xmp_play_buffer's `loop` is the loop count at which it
 * stops, and 0 means "never stop". Ours is "repeats AFTER the first pass", so
 * a finite count is count+1 passes. The fadeout is left to the generic
 * sample-accurate window in ds_read() (supportsNativeFadeout stays 0). */
static void xmp_plugin_configure_loop(RewampDecoder* dec, int mode, int count) {
    if (dec == NULL) return;
    if (mode == 2)      dec->loopParam = 0;
    else if (mode == 1) dec->loopParam = count + 1;
    else                dec->loopParam = 1;
}

// ── Tracker-pattern view ─────────────────────────────────────────────────────
// libxmp keeps patterns as an index of TRACKS (mod->xxp[p]->index[chn] names a
// track, mod->xxt[track]->event[row] the cell), so a pattern's cells come from
// as many tracks as it has channels. Snapshot the lot at open time like the
// libopenmpt plugin does: the module structures are read-only during playback,
// but the visualizer runs on another thread and close() must not free data
// mid-read.
static void xmp_free_patterns(RewampDecoder* dec) {
    if (dec->patCells) {
        for (int p = 0; p < dec->patNumPatterns; p++) free(dec->patCells[p]);
        free(dec->patCells); dec->patCells = NULL;
    }
    free(dec->patRows);  dec->patRows  = NULL;
    free(dec->patOrder); dec->patOrder = NULL;
    dec->patChannels = dec->patNumOrders = dec->patNumPatterns = 0;
}

static void xmp_build_patterns(RewampDecoder* dec, struct xmp_module* mod) {
    int nch  = mod->chn;
    int nord = mod->len;
    int npat = mod->pat;
    if (nch <= 0 || npat <= 0 || mod->xxp == NULL || mod->xxt == NULL) return;

    dec->patChannels    = nch;
    dec->patNumOrders   = nord > 0 ? nord : 0;
    dec->patNumPatterns = npat;

    if (dec->patNumOrders > 0) {
        dec->patOrder = (int32_t*)calloc((size_t)dec->patNumOrders, sizeof(int32_t));
        if (dec->patOrder) {
            for (int o = 0; o < dec->patNumOrders; o++) {
                int pat = mod->xxo[o];
                /* S3M/IT mark skipped and end positions in the order list. */
                dec->patOrder[o] = (pat >= npat) ? -1 : pat;
            }
        }
    }
    dec->patRows  = (int32_t*)calloc((size_t)npat, sizeof(int32_t));
    dec->patCells = (RewampPatternCell**)calloc((size_t)npat, sizeof(RewampPatternCell*));
    if (!dec->patRows || !dec->patCells) { xmp_free_patterns(dec); return; }

    for (int p = 0; p < npat; p++) {
        struct xmp_pattern* xxp = mod->xxp[p];
        int rows = (xxp != NULL) ? xxp->rows : 0;
        if (rows < 0) rows = 0;
        dec->patRows[p] = rows;
        if (rows == 0 || xxp == NULL) continue;

        RewampPatternCell* cells = (RewampPatternCell*)calloc(
            (size_t)rows * nch, sizeof(RewampPatternCell));
        dec->patCells[p] = cells;
        if (!cells) continue;

        for (int c = 0; c < nch; c++) {
            int trk = xxp->index[c];
            struct xmp_track* xxt = (trk >= 0 && trk < mod->trk) ? mod->xxt[trk] : NULL;
            for (int r = 0; r < rows; r++) {
                RewampPatternCell* cell = &cells[(size_t)r * nch + c];
                cell->note       = REWAMP_NOTE_EMPTY;
                cell->instrument = -1;
                cell->volume     = -1;
                cell->vol[0]     = 0;
                cell->fxval[0]   = -1;
                if (xxt == NULL || r >= xxt->rows) continue;

                struct xmp_event* e = &xxt->event[r];
                if      (e->note == 0)           cell->note = REWAMP_NOTE_EMPTY;
                else if (e->note == XMP_KEY_OFF) cell->note = REWAMP_NOTE_OFF;
                else if (e->note == XMP_KEY_CUT) cell->note = REWAMP_NOTE_CUT;
                else if (e->note == XMP_KEY_FADE)cell->note = REWAMP_NOTE_FADE;
                else if (e->note <= XMP_MAX_KEYS)
                    cell->note = (int16_t)(e->note - 1);   /* 1 = C-0 */

                if (e->ins) cell->instrument = (int32_t)e->ins;

                /* libxmp normalizes the volume column to 1..vol_base+1, 0
                 * meaning "no volume in this cell" — unlike XM/IT's
                 * multiplexed column, which it has already decoded into
                 * effects, so a plain number is the honest display here. */
                if (e->vol) cell->volume = (int16_t)(e->vol - 1);

                if (e->fxt || e->fxp) {
                    cell->num_fx = 1;
                    /* Effect types below 0x10 are the classic MOD/XM set in
                     * the classic order, so they print as the tracker's own
                     * hex digit. Above that libxmp's numbering is its own —
                     * print it as two hex digits rather than invent a letter
                     * the file's tracker never used. */
                    if (e->fxt < 0x10) {
                        cell->fx[0][0] = "0123456789ABCDEF"[e->fxt];
                    } else {
                        static const char* kHex = "0123456789ABCDEF";
                        cell->fx[0][0] = kHex[(e->fxt >> 4) & 0xF];
                        cell->fx[0][1] = kHex[e->fxt & 0xF];
                    }
                    cell->fxval[0] = (int32_t)e->fxp;
                }
            }
        }
    }
}

static int xmp_pattern_song_info(RewampDecoder* dec, RewampPatternSongInfo* out) {
    if (!dec || !out || dec->patNumPatterns <= 0 || !dec->patCells) return 0;
    out->num_channels = dec->patChannels;
    out->num_orders   = dec->patNumOrders;
    out->num_patterns = dec->patNumPatterns;
    out->max_fx_cols  = 1;
    return 1;
}

static int xmp_pattern_order(RewampDecoder* dec, int order) {
    if (!dec || !dec->patOrder || order < 0 || order >= dec->patNumOrders) return -1;
    return dec->patOrder[order];
}

static int xmp_pattern_num_rows(RewampDecoder* dec, int pattern) {
    if (!dec || !dec->patRows || pattern < 0 || pattern >= dec->patNumPatterns) return 0;
    return dec->patRows[pattern];
}

static int xmp_pattern_get(RewampDecoder* dec, int pattern,
                           RewampPatternCell* out, int maxCells) {
    if (!dec || !out || !dec->patCells ||
        pattern < 0 || pattern >= dec->patNumPatterns) return 0;
    RewampPatternCell* src = dec->patCells[pattern];
    if (!src) return 0;
    int n = dec->patRows[pattern] * dec->patChannels;
    if (n > maxCells) n = maxCells;
    if (n <= 0) return 0;
    memcpy(out, src, (size_t)n * sizeof(RewampPatternCell));
    return n;
}

static void xmp_pattern_cursor(RewampDecoder* dec, int* order, int* row) {
    if (order) *order = dec ? dec->curOrder : -1;
    if (row)   *row   = dec ? dec->curRow   : -1;
}

static const RewampPluginVTable g_xmp_vtable = {
    "libxmp",
    xmp_plugin_probe,
    xmp_plugin_open,
    xmp_plugin_read,
    xmp_plugin_seek,
    xmp_plugin_length,
    xmp_plugin_close,
    xmp_plugin_configure_loop,
    0,                          /* supportsNativeFadeout */
    "xmp",                      /* engine_id */
    xmp_plugin_param_changed,
    xmp_pattern_song_info,
    xmp_pattern_order,
    xmp_pattern_num_rows,
    xmp_pattern_get,
    xmp_pattern_cursor,
    xmp_plugin_probe_path,
    1,                          /* noPrefixProbe: the content test decides, and
                                 * probing the Amiga prefix token would parse
                                 * the whole file a second time for nothing. */
};

const RewampPluginVTable* rewamp_xmp_plugin(void) {
    return &g_xmp_vtable;
}

// ── Subsong probe (a module can carry several order-list sequences) ──────────
#define XMP_MAX_PROBE_SUBSONGS 256
static int g_xmp_probe_count = 0;
static int g_xmp_probe_ms[XMP_MAX_PROBE_SUBSONGS];

int rewamp_xmp_probe_subsong_count(const char* path) {
    g_xmp_probe_count = 0;
    if (!path) return 0;
    char clean[4096];
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    {
        char* q = strrchr(clean, '?');
        if (q && strncmp(q, "?subsong=", 9) == 0) *q = '\0';
    }

    xmp_context ctx = xmp_create_context();
    if (ctx == NULL) return 0;
    if (xmp_load_module(ctx, clean) < 0) { xmp_free_context(ctx); return 0; }

    struct xmp_module_info mi;
    xmp_get_module_info(ctx, &mi);
    int n = mi.num_sequences;
    if (n < 0) n = 0;
    if (n > XMP_MAX_PROBE_SUBSONGS) n = XMP_MAX_PROBE_SUBSONGS;
    for (int i = 0; i < n; i++)
        g_xmp_probe_ms[i] = mi.seq_data ? mi.seq_data[i].duration : 0;
    g_xmp_probe_count = n;

    xmp_release_module(ctx);
    xmp_free_context(ctx);
    return n;
}

int rewamp_xmp_probe_get_duration_ms(int idx) {
    if (idx < 0 || idx >= g_xmp_probe_count) return 0;
    return g_xmp_probe_ms[idx];
}

#endif /* REWAMP_WITH_XMP */
