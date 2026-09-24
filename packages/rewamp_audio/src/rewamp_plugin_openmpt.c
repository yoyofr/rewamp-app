// libopenmpt plugin — decodes tracker / module formats (MOD, XM, IT, S3M, ...).
// Compiled only when REWAMP_WITH_OPENMPT is defined and libopenmpt is linked.
#ifdef REWAMP_WITH_OPENMPT

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

#include <libopenmpt/libopenmpt.h>
#include <libopenmpt/libopenmpt_ext.h>

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>   /* strcasecmp */

// libopenmpt renders at whatever rate we ask — so ask for the RING's rate
// (REWAMP_RING_RATE, 44100) directly: the decode-ahead ring runs at 44100
// fixed since the crossfade work, and rendering at 48000 was paying one
// producer-side resample for nothing. The module's own samples are
// interpolated by libopenmpt to the requested rate either way; there is no
// "native" module rate to preserve.
#define OPENMPT_RENDER_RATE     44100
#define OPENMPT_RENDER_CHANNELS 2

struct RewampDecoder {
    openmpt_module_ext* modExt; // owner (destroyed on close)
    openmpt_module*     mod;    // borrowed from modExt
    // "interactive" ext interface — per-channel mute (all-zero if unavailable).
    openmpt_module_ext_interface_interactive interactive;
    int     hasInteractive;
    int64_t lastMuteMask;       // applied generic_mute_mask snapshot
    // Per-voice scope write head snapshot (see idle-voice zero-fill in read()).
    int64_t voicePrevPtr[SOUND_MAXVOICES_BUFFER_FX];
    // Live instrument tracking: last instrument number triggered per channel
    // (pattern INSTRUMENT column at each new row), for the ⓘ highlight.
    uint8_t lastInstr[64];
    int32_t lastPattern, lastRow;

    // Immutable tracker-pattern table for the pattern visualizer, built once in
    // open() (single-threaded → no libopenmpt re-entry race with the producer).
    // The engine reads it via the pattern_* vtable slots under decodeLock.
    int                 patChannels;
    int                 patNumOrders;
    int                 patNumPatterns;
    int32_t*            patOrder;    // [patNumOrders] → pattern index
    int32_t*            patRows;     // [patNumPatterns] row count
    RewampPatternCell** patCells;    // [patNumPatterns], each patRows[p]*patChannels
    // Does this FORMAT have a volume column? Decided from the format, not from
    // whether the module happens to use it — the grid should look like the
    // original tracker's, where the column is there even on an empty row.
    int                 patHasVol;
};

/* ── Live "playing instruments" snapshot (single active decoder) ──────────
 * g_active_instr[ch] = 1-based instrument (MOD: sample) number last
 * triggered on that channel, but only while the channel is audible
 * (VU > threshold); 0 otherwise. Read by Dart for the ⓘ highlight. */
static uint8_t g_active_instr[64];
static int     g_active_channels = 0;

int rewamp_openmpt_active_instruments(uint8_t* out, int maxOut) {
    int n = g_active_channels;
    if (n > maxOut) n = maxOut;
    for (int i = 0; i < n; i++) out[i] = g_active_instr[i];
    return n;
}

// Common module extensions. libopenmpt supports many more; this is the fast
// pre-filter, the header probe is the authority.
static const char* const kOpenmptExts[] = {
    "mod", "xm", "it", "s3m", "mptm", "mo3", "stm", "nst", "m15", "stk", "wow",
    "ult", "669", "mtm", "med", "far", "mdl", "ams", "dsm", "amf", "okt",
    "dmf", "ptm", "psm", "mt2", "dbm", "digi", "imf", "j2b", "gdm", "umx",
    NULL
};

static int openmpt_probe(const char* ext, const uint8_t* header, size_t headerSize) {
    int extMatch = rewamp_ext_in_list(ext, kOpenmptExts);

    // libopenmpt's own content sniffing on the file header.
    int probe = OPENMPT_PROBE_FILE_HEADER_RESULT_FAILURE;
    if (header != NULL && headerSize > 0) {
        probe = openmpt_probe_file_header_without_filesize(
            OPENMPT_PROBE_FILE_HEADER_FLAGS_DEFAULT,
            header, headerSize,
            NULL, NULL, NULL, NULL, NULL, NULL);
    }

    if (probe == OPENMPT_PROBE_FILE_HEADER_RESULT_SUCCESS) {
        return extMatch ? 100 : 90;   // content confirmed
    }
    if (extMatch) {
        return 60;   // trust the extension; open() is the final arbiter
    }
    // WANTMOREDATA / FAILURE without an extension match: let other plugins win.
    return 0;
}

static void openmpt_apply_engine_params(openmpt_module* mod) {
    int interp = (int)rewamp_get_engine_param("openmpt", "interpolation", 8);
    int ssep   = (int)rewamp_get_engine_param("openmpt", "stereo_sep", 100);
    double mv  = rewamp_get_engine_param("openmpt", "master_volume", 1.0);
    int amiga  = (int)rewamp_get_engine_param("openmpt", "amiga_filter", 0);
    openmpt_module_set_render_param(mod,
        OPENMPT_MODULE_RENDER_INTERPOLATIONFILTER_LENGTH, interp);
    openmpt_module_set_render_param(mod,
        OPENMPT_MODULE_RENDER_STEREOSEPARATION_PERCENT, ssep);
    if (mv < 0.01) mv = 0.01;   /* linear gain, 1.0 = 0 dB → millibel */
    openmpt_module_set_render_param(mod,
        OPENMPT_MODULE_RENDER_MASTERGAIN_MILLIBEL, (int32_t)(2000.0 * log10(mv)));
    /* Amiga resampler emulation: 0 off, 1 A500, 2 A1200. */
    openmpt_module_ctl_set(mod, "render.resampler.emulate_amiga",
                           amiga ? "1" : "0");
    if (amiga)
        openmpt_module_ctl_set(mod, "render.resampler.emulate_amiga_type",
                               amiga == 1 ? "a500" : "a1200");
}

/* Live settings change (called under the decode lock). */
static void openmpt_param_changed(RewampDecoder* dec, const char* key) {
    (void)key;   /* all four params are cheap — re-apply the lot */
    if (dec && dec->mod) openmpt_apply_engine_params(dec->mod);
}

static void openmpt_build_patterns(RewampDecoder* dec);   /* defined below */

static RewampDecoder* openmpt_open(const char* path, RewampAudioFormat* outFormat) {
    // Strip the rewamp ?subsong=N suffix (0-based; s3m/xm/it/mod can carry
    // several subsongs). N is applied via openmpt_module_select_subsong below.
    char clean[4096];
    int subsong = 0;
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    {
        char* q = strrchr(clean, '?');
        if (q && strncmp(q, "?subsong=", 9) == 0) { subsong = atoi(q + 9); *q = '\0'; }
    }

    FILE* f = fopen(clean, "rb");
    if (f == NULL) return NULL;

    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size <= 0) { fclose(f); return NULL; }

    void* data = malloc((size_t)size);
    if (data == NULL) { fclose(f); return NULL; }
    size_t got = fread(data, 1, (size_t)size, f);
    fclose(f);
    if (got != (size_t)size) { free(data); return NULL; }

    // module_ext (not plain module): required for the "interactive" interface
    // that provides per-channel muting.
    openmpt_module_ext* modExt = openmpt_module_ext_create_from_memory(
        data, got, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
    free(data);  // libopenmpt copies the data internally
    if (modExt == NULL) return NULL;
    openmpt_module* mod = openmpt_module_ext_get_module(modExt);

    /* Engine params (Settings → Moteurs → libopenmpt) — also re-applied LIVE
     * on a settings change via openmpt_param_changed below. */
    openmpt_apply_engine_params(mod);

    // Select the requested subsong (only when >0 so single-song modules keep the
    // libopenmpt default). num_subsongs guards out-of-range values.
    if (subsong > 0) {
        int nsub = openmpt_module_get_num_subsongs(mod);
        if (subsong < nsub) openmpt_module_select_subsong(mod, subsong);
    }

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(RewampDecoder));
    if (dec == NULL) { openmpt_module_ext_destroy(modExt); return NULL; }
    dec->modExt = modExt;
    dec->mod    = mod;
    dec->lastPattern = dec->lastRow = -1;   /* capture row 0 too */
    dec->hasInteractive = openmpt_module_ext_get_interface(
        modExt, LIBOPENMPT_EXT_C_INTERFACE_INTERACTIVE,
        &dec->interactive, sizeof(dec->interactive)) ? 1 : 0;

    int numChannels = openmpt_module_get_num_channels(mod);
    m_genNumVoicesChannels = numChannels;
    rewamp_channel_data_reset(numChannels);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);

    // Voice metadata for the mute/grouping UI: one group named after the
    // module type, tracker channel names when the file provides them.
    rewamp_voices_meta_reset();
    {
        const char* type = openmpt_module_get_metadata(mod, "type");
        char chip[24] = "Tracker";
        if (type && type[0]) {
            size_t n = strlen(type);
            if (n > sizeof(chip) - 1) n = sizeof(chip) - 1;
            for (size_t k = 0; k < n; k++)
                chip[k] = (char)((type[k] >= 'a' && type[k] <= 'z')
                                     ? type[k] - 32 : type[k]);
            chip[n] = '\0';
        }
        openmpt_free_string(type);
        rewamp_voices_add_chip(chip, 0, numChannels);
        for (int j = 0; j < numChannels && j < SOUND_MAXVOICES_BUFFER_FX; j++) {
            const char* cn = openmpt_module_get_channel_name(mod, j);
            if (cn && cn[0]) rewamp_voice_set_name(j, cn);
            openmpt_free_string(cn);
        }
    }

    // Info panel (rewamp_track_message): metadata + free-text message +
    // instrument/sample name lists (the tracker-scene "song message").
    {
        static const struct { const char* key; const char* label; } kMeta[] = {
            { "title",     "Title" },   { "artist",    "Artist" },
            { "type_long", "Type" },    { "tracker",   "Tracker" },
            { "date",      "Date" },
        };
        for (size_t k = 0; k < sizeof(kMeta) / sizeof(kMeta[0]); k++) {
            const char* v = openmpt_module_get_metadata(mod, kMeta[k].key);
            if (v && v[0])
                rewamp_track_message_append("%s: %s\n", kMeta[k].label, v);
            openmpt_free_string(v);
        }
        const char* msg = openmpt_module_get_metadata(mod, "message");
        if (msg && msg[0]) rewamp_track_message_append("\n%s\n", msg);
        openmpt_free_string(msg);

        int32_t ni = openmpt_module_get_num_instruments(mod);
        int32_t ns = openmpt_module_get_num_samples(mod);
        if (ni > 0) {
            rewamp_track_message_append("\nInstruments:\n");
            for (int32_t i = 0; i < ni; i++) {
                const char* nm = openmpt_module_get_instrument_name(mod, i);
                rewamp_track_message_append("%02d: %s\n", i + 1,
                                            (nm && nm[0]) ? nm : "");
                /* La timeline des viz porte le NUMÉRO d'instrument lu dans le
                 * motif (1-based): le même index nomme la légende « par
                 * instrument ». Un module à instruments les nomme ici, un
                 * module à échantillons seuls plus bas. */
                if (nm && nm[0]) rewamp_instrument_set_name((int)i + 1, nm);
                openmpt_free_string(nm);
            }
        }
        if (ns > 0) {
            rewamp_track_message_append("\nSamples:\n");
            for (int32_t i = 0; i < ns; i++) {
                const char* nm = openmpt_module_get_sample_name(mod, i);
                /* Sans table d'instruments, la colonne du motif désigne
                 * l'ÉCHANTILLON: c'est lui qui nomme la légende. */
                if (ni <= 0 && nm && nm[0]) rewamp_instrument_set_name((int)i + 1, nm);
                rewamp_track_message_append("%02d: %s\n", i + 1,
                                            (nm && nm[0]) ? nm : "");
                openmpt_free_string(nm);
            }
        }
    }

    // Snapshot the tracker patterns for the pattern visualizer (immutable table).
    openmpt_build_patterns(dec);

    if (outFormat != NULL) {
        outFormat->channels   = OPENMPT_RENDER_CHANNELS;
        outFormat->sampleRate = OPENMPT_RENDER_RATE;
    }
    return dec;
}

static uint64_t openmpt_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (dec == NULL || dec->mod == NULL) return 0;

    // Apply voice-mute changes from the UI via the interactive ext interface
    // (Modizer: ompt_mod_interactive->set_channel_mute_status).
    if (dec->hasInteractive && dec->lastMuteMask != generic_mute_mask) {
        dec->lastMuteMask = generic_mute_mask;
        int numCh0 = m_genNumVoicesChannels;
        for (int j = 0; j < numCh0 && j < 64; j++) {
            dec->interactive.set_channel_mute_status(
                dec->modExt, j, (int)((generic_mute_mask >> j) & 1));
        }
    }

    uint64_t rendered = (uint64_t)openmpt_module_read_interleaved_float_stereo(
        dec->mod, OPENMPT_RENDER_RATE, (size_t)frameCount, out);

    // Track the instrument column at each new pattern row, and publish the
    // per-channel "currently sounding instrument" snapshot (VU-gated).
    {
        int32_t pat = openmpt_module_get_current_pattern(dec->mod);
        int32_t row = openmpt_module_get_current_row(dec->mod);
        int nch = m_genNumVoicesChannels;
        if (nch > 64) nch = 64;
        if (pat != dec->lastPattern || row != dec->lastRow) {
            dec->lastPattern = pat;
            dec->lastRow     = row;
            for (int j = 0; j < nch; j++) {
                uint8_t ins = (uint8_t)openmpt_module_get_pattern_row_channel_command(
                    dec->mod, pat, row, j, OPENMPT_MODULE_COMMAND_INSTRUMENT);
                if (ins) dec->lastInstr[j] = ins;
            }
        }
        for (int j = 0; j < nch; j++) {
            float vu = openmpt_module_get_current_channel_vu_mono(dec->mod, j);
            g_active_instr[j] = (vu > 0.001f) ? dec->lastInstr[j] : 0;
            // La timeline des viz notation/piano (rewamp_notes_capture) lit
            // vgm_last_instr[], pas g_active_instr[] — sans cette ligne le
            // piano « par instrument » recevait 0 pour toutes les voix d'un
            // module et peignait tout de la couleur de l'instrument 0
            // (constaté à l'écran le 2026-09-08). Le DERNIER instrument
            // déclenché, sans porte VU: une note qui démarre a un VU encore
            // nul et changerait de couleur après son attaque.
            if (j < SOUND_MAXVOICES_BUFFER_FX)
                vgm_last_instr[j] = dec->lastInstr[j];
            // Per-channel level for the pattern viz volume meters (and any
            // rewamp_channel_volume consumer): Modizer's exact formula, VU*255
            // clamped. libopenmpt otherwise never fills vgm_last_vol[].
            int vol = (int)(vu * 255.0f);
            if (vol < 0)   vol = 0;
            if (vol > 255) vol = 255;
            vgm_last_vol[j] = (unsigned int)vol;
        }
        g_active_channels = nch;
    }

    // libopenmpt's float API applies NO clipping — busy modules routinely
    // exceed ±1.0, which both clips audibly downstream and blows up the
    // stereo oscilloscope (other plugins are int16-bounded). Saturate like
    // Modizer's int16 output stage did.
    for (uint64_t i = 0; i < rendered * 2; i++) {
        if (out[i] > 1.0f)  out[i] = 1.0f;
        if (out[i] < -1.0f) out[i] = -1.0f;
    }

    // Idle-voice zero-fill: the Fastmix scope patch only writes for channels
    // that actually mix. A voice that goes quiet stops advancing its write
    // head and the scope keeps showing its LAST waveform frozen — pad the
    // missed span with zeros so idle voices draw a flat line.
    int numCh = m_genNumVoicesChannels;
    for (int j = 0; j < numCh && j < SOUND_MAXVOICES_BUFFER_FX; j++) {
        if (m_voice_buff[j] == NULL) continue;
        const int64_t step     = (int64_t)1 << MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
        const int64_t expected = dec->voicePrevPtr[j] + (int64_t)rendered * step;
        int64_t ptr = m_voice_current_ptr[j];
        while (ptr < expected) {
            m_voice_buff[j][(ptr >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT) &
                            (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2 - 1)] = 0;
            ptr += step;
        }
        if (ptr != m_voice_current_ptr[j]) m_voice_current_ptr[j] = ptr;
        dec->voicePrevPtr[j] = ptr;
    }

    // Poll current note per channel (openmpt_module_get_current_channel_note
    // returns nNote<<10; nNote 1=C-0=MIDI 0, ..., 120=B-9=MIDI 119).
    for (int j = 0; j < numCh && j < SOUND_MAXVOICES_BUFFER_FX; j++) {
        int32_t noteScaled = openmpt_module_get_current_channel_note(dec->mod, j);
        if (noteScaled > 0) {
            int nNote   = noteScaled >> 10;          // exact: was nNote << 10
            int midiNote = nNote - 1;                 // OpenMPT 1-based → MIDI 0-based
            vgm_last_note[j] = (unsigned int)(440.0 * pow(2.0, (midiNote - 69) / 12.0));
        } else {
            vgm_last_note[j] = 0;
        }
    }
    return rendered;
}

static void openmpt_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (dec == NULL || dec->mod == NULL) return;
    double seconds = (double)frameIndex / (double)OPENMPT_RENDER_RATE;
    openmpt_module_set_position_seconds(dec->mod, seconds);
}

static uint64_t openmpt_length(RewampDecoder* dec) {
    if (dec == NULL || dec->mod == NULL) return 0;
    double seconds = openmpt_module_get_duration_seconds(dec->mod);
    if (seconds <= 0.0) return 0;
    return (uint64_t)(seconds * OPENMPT_RENDER_RATE);
}

// ── Tracker-pattern view ─────────────────────────────────────────────────────
// Snapshot the whole song's pattern data into an immutable table at open time,
// so the pattern visualizer never re-enters libopenmpt from the UI thread while
// the producer is decoding (the module is not thread-safe). Only the live
// (order,row) cursor is polled at play time, on the producer thread.
static void openmpt_free_patterns(RewampDecoder* dec) {
    if (dec->patCells) {
        for (int p = 0; p < dec->patNumPatterns; p++) free(dec->patCells[p]);
        free(dec->patCells); dec->patCells = NULL;
    }
    free(dec->patRows);  dec->patRows  = NULL;
    free(dec->patOrder); dec->patOrder = NULL;
    dec->patChannels = dec->patNumOrders = dec->patNumPatterns = 0;
}

/* Does this tracker format HAVE a volume column in its cells?
 *
 * Per format, not per module: the point is to look like the tune's own tracker,
 * which draws the column even where every row leaves it empty. The formats
 * WITHOUT one keep the volume in an effect (Cxx) or purely in playback state,
 * and reconstructing a number there would be inventing data.
 *
 * With a column: STM, S3M, XM, IT/MPTM, FAR, MDL, PTM, AMF, PSM, AMS, LIQ.
 * Without: MOD (every ProTracker/NoiseTracker/xCHN variant), MTM, 669, OKT,
 * MED/OctaMED, ULT, IMF, DBM, GDM, AHX/HVL. Careful with ULT/IMF/DBM/OctaMED:
 * they have a SECOND effect column, which looks like a volume column but is
 * not one.
 *
 * XM and IT's column is multiplexed (volume, fine slides, vibrato, panning,
 * portamento over disjoint ranges) — which is why the cell stores libopenmpt's
 * formatted text rather than a number. */
static int openmpt_format_has_volume_column(openmpt_module* mod) {
    const char* type = openmpt_module_get_metadata(mod, "type");
    if (!type) return 0;
    static const char* const kWithVolume[] = {
        "stm", "s3m", "xm", "it", "mptm", "far", "mdl", "ptm",
        "amf", "psm", "ams", "liq", NULL,
    };
    int found = 0;
    for (int i = 0; kWithVolume[i]; i++) {
        if (strcasecmp(type, kWithVolume[i]) == 0) { found = 1; break; }
    }
    openmpt_free_string(type);
    return found;
}

static void openmpt_build_patterns(RewampDecoder* dec) {
    openmpt_module* mod = dec->mod;
    int nch  = openmpt_module_get_num_channels(mod);
    int nord = openmpt_module_get_num_orders(mod);
    int npat = openmpt_module_get_num_patterns(mod);
    if (nch <= 0 || npat <= 0) return;   // nothing to show

    dec->patChannels    = nch;
    dec->patNumOrders   = nord > 0 ? nord : 0;
    dec->patNumPatterns = npat;

    if (dec->patNumOrders > 0) {
        dec->patOrder = (int32_t*)calloc((size_t)dec->patNumOrders, sizeof(int32_t));
        if (dec->patOrder)
            for (int o = 0; o < dec->patNumOrders; o++)
                dec->patOrder[o] = openmpt_module_get_order_pattern(mod, o);
    }
    dec->patHasVol = openmpt_format_has_volume_column(mod);
    dec->patRows  = (int32_t*)calloc((size_t)npat, sizeof(int32_t));
    dec->patCells = (RewampPatternCell**)calloc((size_t)npat, sizeof(RewampPatternCell*));
    if (!dec->patRows || !dec->patCells) { openmpt_free_patterns(dec); return; }

    for (int p = 0; p < npat; p++) {
        int rows = openmpt_module_get_pattern_num_rows(mod, p);
        if (rows < 0) rows = 0;
        dec->patRows[p] = rows;
        if (rows == 0) continue;
        RewampPatternCell* cells = (RewampPatternCell*)calloc(
            (size_t)rows * nch, sizeof(RewampPatternCell));
        dec->patCells[p] = cells;
        if (!cells) continue;

        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < nch; c++) {
                RewampPatternCell* cell = &cells[(size_t)r * nch + c];

                uint8_t rawNote = openmpt_module_get_pattern_row_channel_command(
                    mod, p, r, c, OPENMPT_MODULE_COMMAND_NOTE);
                if      (rawNote == 0)   cell->note = REWAMP_NOTE_EMPTY;
                else if (rawNote == 255) cell->note = REWAMP_NOTE_OFF;   /* == */
                else if (rawNote == 254) cell->note = REWAMP_NOTE_CUT;   /* ^^ */
                else if (rawNote == 253) cell->note = REWAMP_NOTE_FADE;  /* ~~ */
                else if (rawNote >= 1 && rawNote <= 120)
                    cell->note = (int16_t)(rawNote - 1);   /* 1=C-0 → semitone 0 */
                else cell->note = REWAMP_NOTE_EMPTY;       /* PC notes etc. */

                uint8_t ins = openmpt_module_get_pattern_row_channel_command(
                    mod, p, r, c, OPENMPT_MODULE_COMMAND_INSTRUMENT);
                cell->instrument = ins ? (int16_t)ins : -1;

                /* Volume column, as the ORIGINAL TRACKER prints it.
                 *
                 * Not decoded here on purpose. Reading the raw VOLUME byte and
                 * showing it whenever VOLUMEEFFECT is non-zero — which is what
                 * this did — is wrong for XM and IT, whose volume column is
                 * multiplexed: only part of the range is a volume, the rest is
                 * fine slides, vibrato speed/depth, panning or portamento. A
                 * vibrato depth was being displayed as if it were a volume.
                 * And most formats (MOD, MTM, 669, OKT, MED, ULT, IMF, DBM,
                 * GDM, AHX) have no volume column whatsoever, so there is
                 * nothing to show. libopenmpt already knows all of this per
                 * format and formats the cell accordingly. */
                {
                    /* LETTER from libopenmpt, VALUE formatted here.
                     *
                     * The letter is what makes XM/IT readable: their volume
                     * column is multiplexed (volume, fine slides, vibrato,
                     * panning, portamento over disjoint ranges) and libopenmpt
                     * maps each to the letter that format's own tracker uses.
                     *
                     * The value is NOT taken from
                     * format_pattern_row_channel_command(…VOLUME): that path is
                     * broken upstream. It formats with mpt::afmt::HEX0<2>, whose
                     * argument (cell.vol) is a byte-sized type, so it is treated
                     * as a CHARACTER — volume 32 came out as '0' followed by
                     * raw 0x20, i.e. "v0 " on screen, and 40 as "v0(". Verified
                     * identical through the C++ API, so it is not our binding.
                     * Two decimal digits is also what ST3/IT/FT2 themselves
                     * show (00-64), which is the point of this column. */
                    const char* vc = openmpt_module_format_pattern_row_channel_command(
                        mod, p, r, c, OPENMPT_MODULE_COMMAND_VOLUMEEFFECT);
                    uint8_t vraw = openmpt_module_get_pattern_row_channel_command(
                        mod, p, r, c, OPENMPT_MODULE_COMMAND_VOLUME);
                    int n = 0;
                    /* ' ' / '.' are libopenmpt's "no volume command" fillers. */
                    if (vc && vc[0] && vc[0] != '.' && vc[0] != ' ')
                        cell->vol[n++] = vc[0];
                    if (n > 0) {
                        cell->vol[n++] = (char)('0' + (vraw / 10) % 10);
                        cell->vol[n++] = (char)('0' + vraw % 10);
                    }
                    cell->vol[n] = 0;
                    openmpt_free_string(vc);
                    cell->volume = -1;   /* the string is authoritative here */
                }

                uint8_t cmd = openmpt_module_get_pattern_row_channel_command(
                    mod, p, r, c, OPENMPT_MODULE_COMMAND_EFFECT);
                uint8_t par = openmpt_module_get_pattern_row_channel_command(
                    mod, p, r, c, OPENMPT_MODULE_COMMAND_PARAMETER);
                if (cmd != 0) {
                    cell->num_fx = 1;
                    /* Format-native effect LETTER (MOD→'0'..'F', IT→'A'..'Z'). */
                    const char* s = openmpt_module_format_pattern_row_channel_command(
                        mod, p, r, c, OPENMPT_MODULE_COMMAND_EFFECT);
                    if (s && s[0] && s[0] != '.') cell->fx[0][0] = s[0];
                    openmpt_free_string(s);
                    cell->fxval[0] = (int16_t)par;
                } else {
                    cell->fxval[0] = -1;
                }
            }
        }
    }
}

static int openmpt_pattern_song_info(RewampDecoder* dec, RewampPatternSongInfo* out) {
    if (!dec || !out || dec->patNumPatterns <= 0 || !dec->patCells) return 0;
    out->num_channels = dec->patChannels;
    out->num_orders   = dec->patNumOrders;
    out->num_patterns = dec->patNumPatterns;
    out->max_fx_cols  = 1;
    /* Negative = column ABSENT (dropped from the layout), as opposed to 0 which
     * means "use the default width". See openmpt_format_has_volume_column. */
    out->vol_chars    = dec->patHasVol ? 3 : -1;  /* "v40": letter + 2 digits */
    return 1;
}

static int openmpt_pattern_order(RewampDecoder* dec, int order) {
    if (!dec || !dec->patOrder || order < 0 || order >= dec->patNumOrders) return -1;
    return dec->patOrder[order];
}

static int openmpt_pattern_num_rows(RewampDecoder* dec, int pattern) {
    if (!dec || !dec->patRows || pattern < 0 || pattern >= dec->patNumPatterns) return 0;
    return dec->patRows[pattern];
}

static int openmpt_pattern_get(RewampDecoder* dec, int pattern,
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

static void openmpt_pattern_cursor(RewampDecoder* dec, int* order, int* row) {
    /* Called on the producer thread, under decodeLock, right after read() — so
     * these reflect the just-decoded position and never race the decoder. */
    if (order) *order = (dec && dec->mod) ? openmpt_module_get_current_order(dec->mod) : -1;
    if (row)   *row   = (dec && dec->mod) ? openmpt_module_get_current_row(dec->mod)   : -1;
}

static void openmpt_close(RewampDecoder* dec) {
    if (dec == NULL) return;
    openmpt_free_patterns(dec);
    if (dec->modExt != NULL) openmpt_module_ext_destroy(dec->modExt);
    free(dec);
}

// Native forced-loop (Settings → Lecture): openmpt_module_set_repeat_count's
// semantics are an EXACT match for ours (-1=forever, 0=play once, n>0=play
// once + n more times) — no seeking or loop-counting needed on our side.
// The fadeout is NOT handled here natively (libopenmpt's own end-of-song
// fade, ctl "play.at_end"="fadeout", is a fixed short fade — not the user's
// configurable fadeoutSeconds — and openmpt_module_get_duration_seconds()
// never accounts for repeat_count, always single-loop length, so we can't
// use it to predict an early fade start either). Instead rewamp_load_file()
// computes the fadeout window generically from openmpt_length()'s single-
// pass frame count x (loop count+1) and ds_read() (rewamp_datasource.c)
// ramps the gain sample-accurately — no per-plugin fade code needed at all.
static void openmpt_configure_loop(RewampDecoder* dec, int mode, int count) {
    if (dec == NULL || dec->mod == NULL) return;
    int32_t repeat = 0;
    if (mode == 2) repeat = -1;
    else if (mode == 1) repeat = (int32_t)count;
    openmpt_module_set_repeat_count(dec->mod, repeat);
}

static const RewampPluginVTable g_openmpt_vtable = {
    "libopenmpt",
    openmpt_probe,
    openmpt_open,
    openmpt_read,
    openmpt_seek,
    openmpt_length,
    openmpt_close,
    openmpt_configure_loop,
    0,                       /* supportsNativeFadeout */
    "openmpt",               /* engine_id */
    openmpt_param_changed,   /* live settings */
    openmpt_pattern_song_info,  /* pattern view */
    openmpt_pattern_order,
    openmpt_pattern_num_rows,
    openmpt_pattern_get,
    openmpt_pattern_cursor,
};

const RewampPluginVTable* rewamp_openmpt_plugin(void) {
    return &g_openmpt_vtable;
}

// ── Subsong probe (tracker modules can hold several subsongs) ────────────────
// Loads the module, caches num_subsongs + per-subsong names (openmpt subsongs
// are 0-based, matching ?subsong=N). Returns 0 when the file isn't a module the
// libopenmpt can open, so the registry dispatch falls through to GME.
#define OPENMPT_MAX_PROBE_SUBSONGS 256
static char* g_ompt_probe_names[OPENMPT_MAX_PROBE_SUBSONGS];
static int   g_ompt_probe_count = 0;

static void openmpt_probe_free(void) {
    for (int i = 0; i < g_ompt_probe_count; i++) { free(g_ompt_probe_names[i]); g_ompt_probe_names[i] = NULL; }
    g_ompt_probe_count = 0;
}

int rewamp_openmpt_probe_subsong_count(const char* path) {
    openmpt_probe_free();
    if (!path) return 0;
    char clean[4096];
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strrchr(clean, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) *q = '\0';

    FILE* f = fopen(clean, "rb");
    if (!f) return 0;
    fseek(f, 0, SEEK_END); long size = ftell(f); fseek(f, 0, SEEK_SET);
    if (size <= 0) { fclose(f); return 0; }
    void* data = malloc((size_t)size);
    if (!data) { fclose(f); return 0; }
    size_t got = fread(data, 1, (size_t)size, f);
    fclose(f);
    if (got != (size_t)size) { free(data); return 0; }

    // This probe is speculative: rewamp_probe_subsong_count() offers EVERY file
    // to libopenmpt, so a .sc68/.nsf/.sid legitimately fails to load here. A
    // NULL logfunc means libopenmpt's default, which prints that failure to
    // stderr ("openmpt_module_create_from_memory2: ERROR: error loading file")
    // once per probe — noise, not a fault. Silence it; a real openmpt file's
    // own load path (open()) keeps the default logger.
    openmpt_module* mod = openmpt_module_create_from_memory2(
        data, got, openmpt_log_func_silent, NULL, NULL, NULL, NULL, NULL, NULL);
    free(data);
    if (!mod) return 0;

    int n = openmpt_module_get_num_subsongs(mod);
    if (n < 0) n = 0;
    if (n > OPENMPT_MAX_PROBE_SUBSONGS) n = OPENMPT_MAX_PROBE_SUBSONGS;
    for (int i = 0; i < n; i++) {
        const char* nm = openmpt_module_get_subsong_name(mod, i);
        g_ompt_probe_names[i] = (nm && nm[0]) ? strdup(nm) : NULL;
        openmpt_free_string(nm);
    }
    g_ompt_probe_count = n;
    openmpt_module_destroy(mod);
    return n;
}

const char* rewamp_openmpt_probe_get_title(int idx) {
    if (idx < 0 || idx >= g_ompt_probe_count || !g_ompt_probe_names[idx]) return "";
    return g_ompt_probe_names[idx];
}

#endif /* REWAMP_WITH_OPENMPT */
