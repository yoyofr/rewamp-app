#ifndef REWAMP_PLUGIN_H
#define REWAMP_PLUGIN_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque per-file decoder instance, owned by the plugin.
typedef struct RewampDecoder RewampDecoder;

// Generic engine-parameter lookup (values pushed from Dart via
// rewamp_set_engine_param, Settings → Moteurs). Plugins read them in open().
double rewamp_get_engine_param(const char* engine, const char* key,
                               double defval);

// PCM format a decoder produces. Decoders always output interleaved float32.
typedef struct {
    uint32_t channels;
    uint32_t sampleRate;
} RewampAudioFormat;

// ── Tracker-pattern view (optional plugin capability) ────────────────────────
// A generic cell for the "pattern" visualizer. Each plugin that has real
// tracker data (libopenmpt, Furnace) normalizes its native encoding into this;
// backends without patterns leave the vtable slots below NULL (the visualizer
// then synthesizes rows from the captured per-voice notes, or hides itself).
//   note: >=0  → semitone index, 0 = C-0 (octave = note/12, name = note%12);
//         or one of the sentinels below.
#define REWAMP_NOTE_EMPTY  (-1)
#define REWAMP_NOTE_OFF    (-2)   // note-off / key-off (== in trackers)
#define REWAMP_NOTE_CUT    (-3)   // note-cut (^^)
#define REWAMP_NOTE_FADE   (-4)   // note-fade (~~)
#define REWAMP_PATTERN_MAX_FX 8   // Furnace may stack several effect columns

#define REWAMP_PATTERN_FX_CHARS 4 // room for a 4-hex effect code (SunVox 0xCCEE)
#define REWAMP_PATTERN_VOL_CHARS 4 // "v40", "p32", … + NUL

typedef struct {
    int16_t note;                          // semitone index or REWAMP_NOTE_*
    int32_t instrument;                    // -1 none, else 0..0xFFFF (see
                                           // instr_digits: SunVox module numbers
                                           // are 16-bit, they do not fit a byte)
    int16_t volume;                        // -1 none, else 0..255. Plain numeric
                                           // volume; leave -1 and use [vol]
                                           // when the format's volume column is
                                           // not a plain volume.
    // Pre-formatted volume-column text, '' when the row has none. Trackers
    // differ: MOD/MTM/669/OKT/MED/ULT/IMF/DBM/GDM/AHX have NO volume column at
    // all (the value only exists as a Cxx effect or as playback state, and
    // inventing one is worse than showing nothing), while XM and IT have a
    // column that is NOT a plain volume — it multiplexes volume, fine slides,
    // vibrato speed/depth, panning and portamento over disjoint ranges. Rather
    // than carry those tables, libopenmpt formats the cell exactly as its own
    // tracker would; see rewamp_plugin_openmpt.c.
    char    vol[REWAMP_PATTERN_VOL_CHARS];
    uint8_t num_fx;                        // active effect columns (1 = openmpt)
    // Effect display code per column, format-native: openmpt puts the tracker
    // effect LETTER in [c][0] (MOD → '0'..'F', IT/S3M → 'A'..'Z') and 0 in the
    // rest; Furnace puts its 2 hex digits in [c][0..1]; SunVox puts all 4 digits
    // of its 0xCCEE controller/effect word. A leading 0 byte means "no effect in
    // this column". Consumers print the non-zero chars verbatim, so a shorter
    // code just needs its terminator.
    char    fx[REWAMP_PATTERN_MAX_FX][REWAMP_PATTERN_FX_CHARS];
    int32_t fxval[REWAMP_PATTERN_MAX_FX];  // effect parameter, -1 none. Width is
                                           // per-song (fxval_digits) — SunVox's
                                           // ctl_val is a full 16-bit word.
} RewampPatternCell;

typedef struct {
    int num_channels;
    int num_orders;      // length of the order (sequence) list
    int num_patterns;    // distinct patterns
    int max_fx_cols;     // widest effect-column count in the song (1 = openmpt)
    // Display widths in CHARACTERS for this song's cells; 0 means "the default".
    // They size the cell as well as format it, which is why they are per-song
    // and not per-cell. Trackers keep the defaults (2/2/2); SunVox needs wider
    // fields because its module number and its effect parameter are 16-bit and
    // its controller/effect code is a packed word — printing those as 2 hex
    // digits silently dropped the high half of each.
    int instr_digits;    // instrument / module column   (0 → 2)
    int vol_chars;       // volume column                (0 → 2)
    int fxcode_chars;    // effect code                  (0 → 2)
    int fxval_digits;    // effect parameter             (0 → 2)
} RewampPatternSongInfo;

// A decoder plugin. One instance of this vtable is registered per library
// (libopenmpt, libxmp, gme, ...). All plugins emit interleaved float32 PCM;
// miniaudio handles device output, resampling and mixing downstream.
typedef struct {
    // Human-readable backend name, e.g. "libopenmpt".
    const char* name;

    // Probe whether this plugin should decode the file.
    //   ext        lowercased extension without the dot ("xm"), or NULL
    //   header     first bytes of the file (may be partial)
    //   headerSize number of valid bytes in `header`
    // Returns a confidence score in [0, 100]; 0 means "cannot handle".
    // Convention: extension match alone ~= 60, header confirmation pushes higher.
    int (*probe)(const char* ext, const uint8_t* header, size_t headerSize);

    // Open a decoder for `path`. On success returns a non-NULL handle and fills
    // `outFormat`. Returns NULL on failure.
    RewampDecoder* (*open)(const char* path, RewampAudioFormat* outFormat);

    // Read up to `frameCount` interleaved float32 frames into `out`.
    // Returns the number of frames actually produced (0 == end of stream).
    uint64_t (*read)(RewampDecoder* dec, float* out, uint64_t frameCount);

    // Seek to an absolute frame index. No-op if unsupported.
    void (*seek)(RewampDecoder* dec, uint64_t frameIndex);

    // Total length in frames, or 0 if unknown / non-seekable.
    uint64_t (*length)(RewampDecoder* dec);

    // Release the decoder instance.
    void (*close)(RewampDecoder* dec);

    // Optional: configure native loop/repeat behavior at open time. NULL
    // (the default — every existing plugin gets this via trailing-field
    // zero-init, no plugin needs to be touched) means "no native support";
    // rewamp_load_file() then leaves the forced-loop setting (Settings ->
    // Lecture) to PlayerController's generic seek+volume fallback, which
    // works uniformly regardless of format.
    //   mode  0=off, 1=on (loop `count` times total, i.e. play count+1
    //         times), 2=infinite
    //   count total loop count when mode==1 (ignored otherwise)
    // Called once, right after a successful open(), with the CURRENT
    // setting — not re-called if the setting changes mid-playback (matches
    // every other Settings->Lecture option, snapshotted at load time).
    // Some engines (libvgm's PlayerA, vgmstream's libvgmstream_config_t) need
    // the loop/fade config set BEFORE their own internal "start" step, which
    // happens inside open() itself, earlier than this hook fires — those
    // plugins read the g_force_loop_* globals (rewamp_audio.c) directly from
    // open() instead, and configure_loop here is a no-op that exists only so
    // this field is non-NULL (see supportsNativeFadeout below).
    void (*configure_loop)(RewampDecoder* dec, int mode, int count);

    // 1 if this plugin ALSO natively fades out at the end of its configured
    // loop (independent of configure_loop's own params — set via the
    // g_force_loop_* globals directly, same reason as above). When 1,
    // rewamp_load_file() skips computing the generic ds_read fadeout window
    // entirely (would double-apply the fade otherwise). 0 (default, via
    // trailing-field zero-init) means "loop-only native support" — the
    // generic window still applies for the fadeout part, e.g. libopenmpt.
    int supportsNativeFadeout;

    // Optional live parameter support. `engine_id` is the engine key used with
    // rewamp_set_engine_param ("openmpt", "gme", …). When non-NULL and a file
    // of this plugin is playing, a settings change calls `param_changed(dec,
    // key)` UNDER THE DECODE LOCK so the plugin can re-apply the value on the
    // live decoder immediately (key = the parameter that changed). Plugins
    // without it still pick new values up on the next open().
    const char* engine_id;
    void (*param_changed)(RewampDecoder* dec, const char* key);

    // ── Optional tracker-pattern view ────────────────────────────────────────
    // All NULL by default (trailing-field zero-init) — a plugin fills them in
    // only when it exposes real pattern data. Two implementation styles exist:
    // openmpt copies everything into an IMMUTABLE table in open(); Furnace
    // converts lazily per pattern_get from the engine's (read-only, playback-
    // stable) song structures. Either way the engine calls these under
    // decodeLock (rewamp_audio.c), so they never race the producer's decode and
    // a concurrent close() cannot free the data mid-read.
    //
    // pattern_song_info: fill *out, return 1 on success / 0 if no patterns.
    int  (*pattern_song_info)(RewampDecoder* dec, RewampPatternSongInfo* out);
    // pattern_order: order index → pattern index (-1 if out of range).
    int  (*pattern_order)(RewampDecoder* dec, int order);
    // pattern_num_rows: rows in a pattern (0 if out of range).
    int  (*pattern_num_rows)(RewampDecoder* dec, int pattern);
    // pattern_get: fill out[row*num_channels + chan] for the WHOLE pattern,
    // capped at maxCells cells; returns cells written (rows*channels) or 0.
    int  (*pattern_get)(RewampDecoder* dec, int pattern,
                        RewampPatternCell* out, int maxCells);
    // pattern_cursor: the LIVE playback position (order,row). Polled on the
    // producer thread each decode step and stored keyed by frame, so the
    // visualizer reads it at the HEARD position (see rewamp_pattern.c). Writes
    // -1 to both when unknown.
    void (*pattern_cursor)(RewampDecoder* dec, int* order, int* row);
} RewampPluginVTable;

// Helper for plugins: returns 1 if `ext` (lowercase, no dot) is in a
// NULL-terminated list of lowercase extensions, else 0.
int rewamp_ext_in_list(const char* ext, const char* const* list);

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_PLUGIN_H */
