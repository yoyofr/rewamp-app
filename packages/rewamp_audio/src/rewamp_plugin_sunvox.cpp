/* SunVox plugin — Alexander Zolotov / WarmPlace's modular synth+tracker (.sunvox).
 * Vendored full source (third_party/sunvox, headless SunDog config). The library
 * is a NATIVE pull decoder: sv_audio_callback() has the exact shape of our read()
 * — no push→pull adaptation (unlike gsf/mdx/eup).
 *
 * Voice model: each SunVox "module" flagged SV_MODULE_FLAG_GENERATOR is a voice.
 * Modules are sparse (gaps in the id space) so a contiguous voice index v maps to
 * module id s_gen[v]. Per-voice oscilloscope comes FREE from the library's own
 * sv_get_module_scope2() (first engine in the repo needing no YOYOFR scope patch);
 * mute is the one source addition — rewamp_sv_set_module_mute() in sunvox_lib.cpp
 * toggles the engine's internal PSYNTH_FLAG_MUTE (honored in the real mix, and a
 * flag — not a ctl — so the tune's pattern automation never overwrites it).
 *
 * Loop: SunVox self-loops the project forever (autostop=0, never signals
 * end_of_song), like a SID — so this is the GENERIC loop path (configure_loop
 * left NULL); read() plays indefinitely and PlayerController._tickForceLoop drives
 * repeats/fade/stop from the elapsed timeline. length() is native-exact. seek() is
 * native (sv_rewind by line, frame→line via the SV_TIME_MAP_FRAMECNT table). */
#ifdef REWAMP_WITH_SUNVOX

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"
#include "ModizerConstants.h"

#define SUNVOX_STATIC_LIB
#include "sunvox.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

/* Added to sunvox_lib.cpp (surfaces the engine's internal per-module mute). */
extern "C" int rewamp_sv_set_module_mute(int slot, int mod_num, int mute);

/* Per-module playing note, filled by the psynth_add_event patch (psynth_net.cpp).
 * Indexed by SunVox module id; the plugin maps module -> voice for vgm_last_*. */
extern "C" int32_t g_rewamp_sv_note_pitch[1024] = {0};
extern "C" int16_t g_rewamp_sv_note_vel[1024]   = {0};

#define SV_SLOT      0
#define SV_MAXVOICES 128           /* cap; SunVox songs rarely exceed this in gens */
#define SV_RATE      44100
#define SV_PAT_MAXCOLS 48          /* flattened-grid column cap (note-receiving modules) */
#define SV_PAT_CHUNK   64          /* rows per exposed "pattern" (timeline slice) */

struct RewampDecoder {
    int        gen[SV_MAXVOICES];  /* voice v -> module id */
    int        nvoices;
    uint32_t*  lineFrame;          /* frame counter at start of each line */
    int        nlines;
    uint64_t   totalFrames;
    uint64_t   pos;                /* absolute frame position (monotonic) */
    int64_t    muteApplied;        /* last generic_mute_mask we pushed */
    int16_t    scopeTmp[4096];
    /* Pattern view: SunVox lays patterns FREELY on a 2D timeline and plays MANY
     * at once (different y layers), so a single pattern is never "the" thing
     * being heard. We instead FLATTEN the whole timeline into one module×line
     * grid (columns = the modules that receive notes, merged across every
     * overlapping pattern) and expose it to the linear order→pattern renderer as
     * fixed-size row CHUNKS. flat[line*ncols + col]; colMod[col] = module id. */
    RewampPatternCell* flat;
    int        flatLines;
    int        ncols;
    int        colMod[SV_PAT_MAXCOLS];
};

static int          s_inited = 0;
static RewampDecoder* s_active = NULL;  /* only one .sunvox decodes at a time */

static const char* const kSunvoxExts[] = { "sunvox", NULL };

static int sv_probe(const char* ext, const uint8_t* h, size_t n) {
    /* Header magic "SVOX" confirms; extension is exclusive anyway. */
    if (h && n >= 4 && h[0]=='S' && h[1]=='V' && h[2]=='O' && h[3]=='X') return 100;
    return (ext && rewamp_ext_in_list(ext, kSunvoxExts)) ? 90 : 0;
}

static int ensure_init(void) {
    if (s_inited) return 0;
    int r = sv_init(0, SV_RATE, 2,
                    SV_INIT_FLAG_USER_AUDIO_CALLBACK | SV_INIT_FLAG_ONE_THREAD |
                    SV_INIT_FLAG_AUDIO_FLOAT32 | SV_INIT_FLAG_NO_DEBUG_OUTPUT);
    if (r < 0) return -1;
    s_inited = 1;
    return 0;
}

static void* read_all(const char* path, uint32_t* outSize) {
    char clean[4096];
    strncpy(clean, path, sizeof(clean) - 1); clean[sizeof(clean)-1] = '\0';
    { char* q = strrchr(clean, '?'); if (q) *q = '\0'; }   /* strip ?subsong= */
    FILE* f = fopen(clean, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
    if (sz <= 0) { fclose(f); return NULL; }
    void* p = malloc(sz);
    if (p && fread(p, 1, sz, f) != (size_t)sz) { free(p); p = NULL; }
    fclose(f);
    if (outSize) *outSize = (uint32_t)sz;
    return p;
}

/* Map a SunVox pattern note into a display cell.
 *
 * A sunvox_note is NN VV MM CCEE XXYY — note, velocity, module, a packed
 * controller/effect word and its 16-bit parameter. Everything here used to be
 * squeezed into the tracker-shaped defaults and lost information: the module
 * was masked to a byte (SunVox allows 65535), the CCEE word was collapsed to
 * whichever half was non-zero, and ctl_val was truncated to its low byte. The
 * cell now carries all of it; the per-song widths in sv_pattern_song_info tell
 * the renderer how much room to give each field. */
static void sv_fill_cell(RewampPatternCell* cell, const sunvox_note* sn) {
    static const char hexd[] = "0123456789ABCDEF";
    if (sn->note == 0)        cell->note = REWAMP_NOTE_EMPTY;
    else if (sn->note >= 128) cell->note = REWAMP_NOTE_OFF;          /* off / NOTECMD_* */
    else                      cell->note = (int16_t)(sn->note - 1);  /* SunVox note 1 → C-0 */
    /* Module number as SunVox shows it: 1-based, the full 16-bit range. */
    cell->instrument = (sn->module != 0) ? (int32_t)sn->module : -1;
    cell->volume     = (sn->vel != 0)    ? (int16_t)sn->vel    : -1;
    if (sn->ctl != 0 || sn->ctl_val != 0) {
        /* The whole CCEE word, both halves, exactly as the tracker prints it. */
        cell->fx[0][0] = hexd[(sn->ctl >> 12) & 0xF];
        cell->fx[0][1] = hexd[(sn->ctl >>  8) & 0xF];
        cell->fx[0][2] = hexd[(sn->ctl >>  4) & 0xF];
        cell->fx[0][3] = hexd[(sn->ctl      ) & 0xF];
        cell->num_fx   = 1;
        cell->fxval[0] = (int32_t)sn->ctl_val;   /* full XXYY */
    } else {
        cell->num_fx = 0;
        cell->fx[0][0] = cell->fx[0][1] = cell->fx[0][2] = cell->fx[0][3] = 0;
        cell->fxval[0] = -1;
    }
}

/* Flatten every pattern on SunVox's 2D timeline into one module×line grid, so
 * the displayed rows carry the notes ACTUALLY heard (all overlapping layers
 * merged), not one arbitrary layer. Columns = the modules that receive notes. */
static void build_flat_pattern(RewampDecoder* d) {
    d->flatLines = sv_get_song_length_lines(SV_SLOT);
    if (d->flatLines <= 0) { d->flatLines = 0; return; }
    const int nslots = sv_get_number_of_patterns(SV_SLOT);

    /* Pass 1: collect distinct note-receiving modules → columns. */
    for (int p = 0; p < nslots && d->ncols < SV_PAT_MAXCOLS; p++) {
        int lines = sv_get_pattern_lines(SV_SLOT, p);
        if (lines <= 0) continue;
        int tr = sv_get_pattern_tracks(SV_SLOT, p);
        const sunvox_note* data = sv_get_pattern_data(SV_SLOT, p);
        if (!data) continue;
        for (int r = 0; r < lines && d->ncols < SV_PAT_MAXCOLS; r++)
            for (int t = 0; t < tr; t++) {
                int mod = data[r * tr + t].module;
                if (mod == 0) continue;
                int have = 0;
                for (int c = 0; c < d->ncols; c++) if (d->colMod[c] == mod - 1) { have = 1; break; }
                if (!have && d->ncols < SV_PAT_MAXCOLS) d->colMod[d->ncols++] = mod - 1;
            }
    }
    if (d->ncols == 0) d->ncols = 1;
    for (int i = 1; i < d->ncols; i++) {   /* stable layout: sort columns by module id */
        int m = d->colMod[i], j = i - 1;
        while (j >= 0 && d->colMod[j] > m) { d->colMod[j+1] = d->colMod[j]; j--; }
        d->colMod[j+1] = m;
    }

    size_t n = (size_t)d->flatLines * d->ncols;
    d->flat = (RewampPatternCell*)malloc(n * sizeof(RewampPatternCell));
    if (!d->flat) { d->flatLines = 0; return; }
    memset(d->flat, 0, n * sizeof(RewampPatternCell));
    for (size_t i = 0; i < n; i++) {
        d->flat[i].note = REWAMP_NOTE_EMPTY; d->flat[i].instrument = -1;
        d->flat[i].volume = -1; d->flat[i].num_fx = 0;
        d->flat[i].fxval[0] = -1;   /* fx[] chars zeroed by the memset above */
    }

    /* Pass 2: place each pattern's notes into flat[global_line][module_col]. */
    for (int p = 0; p < nslots; p++) {
        int lines = sv_get_pattern_lines(SV_SLOT, p);
        if (lines <= 0) continue;
        int x  = sv_get_pattern_x(SV_SLOT, p);
        int tr = sv_get_pattern_tracks(SV_SLOT, p);
        const sunvox_note* data = sv_get_pattern_data(SV_SLOT, p);
        if (!data) continue;
        for (int r = 0; r < lines; r++) {
            int gl = x + r;
            if (gl < 0 || gl >= d->flatLines) continue;
            for (int t = 0; t < tr; t++) {
                const sunvox_note* sn = &data[r * tr + t];
                if (sn->module == 0) continue;   /* no target module → can't place */
                if (sn->note == 0 && sn->ctl == 0 && sn->ctl_val == 0) continue;
                int col = -1;
                for (int c = 0; c < d->ncols; c++) if (d->colMod[c] == sn->module - 1) { col = c; break; }
                if (col < 0) continue;
                RewampPatternCell* dst = &d->flat[(size_t)gl * d->ncols + col];
                /* Overlapping layers writing the same module+line: a real NOTE
                 * wins over a bare ctl/effect already there. */
                int newHasNote = (sn->note >= 1 && sn->note <= 127) || sn->note >= 128;
                if (dst->note != REWAMP_NOTE_EMPTY && !newHasNote) continue;
                sv_fill_cell(dst, sn);
            }
        }
    }
}

static RewampDecoder* sv_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path || ensure_init()) return NULL;

    uint32_t size = 0;
    void* data = read_all(path, &size);
    if (!data) return NULL;

    sv_open_slot(SV_SLOT);
    if (sv_load_from_memory(SV_SLOT, data, size) != 0) {
        free(data);
        sv_close_slot(SV_SLOT);
        return NULL;
    }
    free(data);  /* SunVox copies the project internally */

    RewampDecoder* d = (RewampDecoder*)calloc(1, sizeof(RewampDecoder));
    if (!d) { sv_close_slot(SV_SLOT); return NULL; }

    /* Enumerate generator modules → voices. */
    int nmod = sv_get_number_of_modules(SV_SLOT);
    d->nvoices = 0;
    for (int m = 0; m < nmod && d->nvoices < SV_MAXVOICES; m++) {
        uint32_t fl = sv_get_module_flags(SV_SLOT, m);
        if (!(fl & SV_MODULE_FLAG_EXISTS)) continue;
        if (fl & SV_MODULE_FLAG_GENERATOR) d->gen[d->nvoices++] = m;
    }
    if (d->nvoices == 0) d->nvoices = 1;  /* degenerate: keep one voice slot */

    d->totalFrames = sv_get_song_length_frames(SV_SLOT);
    if (d->totalFrames == 0) d->totalFrames = (uint64_t)SV_RATE * 60;

    /* Build the line→frame table for native seek. */
    d->nlines = sv_get_song_length_lines(SV_SLOT);
    if (d->nlines > 0) {
        d->lineFrame = (uint32_t*)malloc(sizeof(uint32_t) * d->nlines);
        if (d->lineFrame &&
            sv_get_time_map(SV_SLOT, 0, d->nlines, d->lineFrame, SV_TIME_MAP_FRAMECNT) != 0) {
            free(d->lineFrame); d->lineFrame = NULL;
        }
    }

    /* Flatten the 2D pattern timeline into one module×line grid. */
    build_flat_pattern(d);

    /* Voice framework setup (BEFORE the first render). */
    rewamp_channel_data_reset(d->nvoices);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);  /* 4096 */
    rewamp_channel_data_set_ring_circular(1);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("SunVox", 0, d->nvoices);
    for (int v = 0; v < d->nvoices; v++) {
        const char* nm = sv_get_module_name(SV_SLOT, d->gen[v]);
        if (nm && nm[0]) rewamp_voice_set_name(v, nm);
    }

    /* Info panel (PSF-style: the format publishes its own tags). */
    const char* song = sv_get_song_name(SV_SLOT);
    rewamp_track_message_append("Format: SunVox (modular synth & tracker)\n");
    if (song && song[0]) rewamp_track_message_append("Title: %s\n", song);
    rewamp_track_message_append("Modules: %d (%d generators)\n", nmod, d->nvoices);
    rewamp_track_message_append("BPM: %d  TPL: %d\n",
                                sv_get_song_bpm(SV_SLOT), sv_get_song_tpl(SV_SLOT));

    memset(g_rewamp_sv_note_vel, 0, sizeof(g_rewamp_sv_note_vel));
    memset(g_rewamp_sv_note_pitch, 0, sizeof(g_rewamp_sv_note_pitch));
    d->muteApplied = 0;
    d->pos = 0;
    s_active = d;
    sv_play_from_beginning(SV_SLOT);

    outFormat->channels = 2;
    outFormat->sampleRate = SV_RATE;
    return d;
}

static void apply_mute(RewampDecoder* d) {
    int64_t mask = (int64_t)generic_mute_mask;
    if (mask == d->muteApplied) return;
    for (int v = 0; v < d->nvoices; v++) {
        int want = (mask >> v) & 1;
        int had  = (d->muteApplied >> v) & 1;
        if (want != had) rewamp_sv_set_module_mute(SV_SLOT, d->gen[v], want);
    }
    d->muteApplied = mask;
}

static void fill_scope(RewampDecoder* d, uint64_t frames) {
    int n = (int)frames; if (n > 4096) n = 4096;
    for (int v = 0; v < d->nvoices; v++) {
        int mod   = d->gen[v];
        int muted = (generic_mute_mask >> v) & 1;

        /* Notes: pitch/velocity captured by the psynth_add_event patch, mapped
         * module -> voice. SunVox pitch: PS_NOTE0_PITCH=30720 (note 0), 256/semi;
         * Hz = 2^((30720-pitch)/3072) * 16.334 (C0). */
        int16_t vel = (mod < 1024) ? g_rewamp_sv_note_vel[mod] : 0;
        if (vel > 0 && !muted) {
            float pitch = (float)((mod < 1024) ? g_rewamp_sv_note_pitch[mod] : 30720);
            vgm_last_note[v] = powf(2.0f, (30720.0f - pitch) / 3072.0f) * 16.333984375f;
            vgm_last_vol[v]  = vel > 255 ? 255 : vel;
        } else {
            vgm_last_note[v] = 0;
            vgm_last_vol[v]  = 0;
        }

        if (!m_voice_buff[v]) continue;
        int got = (int)sv_get_module_scope2(SV_SLOT, mod, 0, d->scopeTmp, n);
        int64_t p = m_voice_current_ptr[v];
        for (int i = 0; i < n; i++) {
            int s = (i < got && !muted) ? (d->scopeTmp[i] >> 8) : 0;  /* int16 → int8 */
            m_voice_buff[v][(p >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT)
                            & (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2 - 1)] = LIMIT8(s);
            p += (int64_t)1 << MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
        }
        m_voice_current_ptr[v] = p;
    }
}

static uint64_t sv_read(RewampDecoder* d, float* out, uint64_t frameCount) {
    if (!d || s_active != d) return 0;
    apply_mute(d);
    sv_audio_callback(out, (int)frameCount, 0, sv_get_ticks());
    fill_scope(d, frameCount);
    d->pos += frameCount;
    return frameCount;  /* self-looping: never signals EOF (generic loop path) */
}

static void sv_seek(RewampDecoder* d, uint64_t frameIndex) {
    if (!d || s_active != d) return;
    int line = 0;
    if (d->lineFrame && d->nlines > 0) {
        /* largest line whose start frame <= frameIndex */
        int lo = 0, hi = d->nlines - 1;
        while (lo < hi) {
            int mid = (lo + hi + 1) >> 1;
            if (d->lineFrame[mid] <= frameIndex) lo = mid; else hi = mid - 1;
        }
        line = lo;
    } else if (d->totalFrames > 0) {
        line = (int)((frameIndex * (uint64_t)(d->nlines > 0 ? d->nlines : 1)) / d->totalFrames);
    }
    sv_rewind(SV_SLOT, line);
    memset(g_rewamp_sv_note_vel, 0, sizeof(g_rewamp_sv_note_vel));  /* drop stale notes */
    d->muteApplied = 0;   /* re-push mute after the engine reset */
    d->pos = frameIndex;
}

static uint64_t sv_length(RewampDecoder* d) {
    return d ? d->totalFrames : 0;
}

static void sv_close(RewampDecoder* d) {
    if (!d) return;
    if (s_active == d) {
        sv_stop(SV_SLOT);
        sv_close_slot(SV_SLOT);
        s_active = NULL;
    }
    free(d->lineFrame);
    free(d->flat);
    free(d);
}

/* ── Flattened real pattern data (module×line grid, exposed as row chunks) ──── */
static int sv_pat_chunks(RewampDecoder* d) {
    return (d->flatLines + SV_PAT_CHUNK - 1) / SV_PAT_CHUNK;
}

static int sv_pattern_song_info(RewampDecoder* d, RewampPatternSongInfo* out) {
    if (!d || !d->flat || d->flatLines <= 0 || !out) return 0;
    out->num_channels = d->ncols;
    out->num_orders   = sv_pat_chunks(d);
    out->num_patterns = sv_pat_chunks(d);
    out->max_fx_cols  = 1;
    /* SunVox's row is NN VV MM CCEE XXYY — the module and the effect parameter
     * are 16-bit and the effect code is a packed word, so the tracker defaults
     * of 2 digits per field would truncate three of the five. */
    out->instr_digits = 4;   /* module 1..65535 */
    out->fxcode_chars = 4;   /* CCEE */
    out->fxval_digits = 4;   /* XXYY */
    return 1;
}

static int sv_pattern_order(RewampDecoder* d, int order) {
    if (!d || order < 0 || order >= sv_pat_chunks(d)) return -1;
    return order;   /* chunk index == order index */
}

static int sv_pattern_num_rows(RewampDecoder* d, int chunk) {
    if (!d || d->flatLines <= 0 || chunk < 0 || chunk >= sv_pat_chunks(d)) return 0;
    int start = chunk * SV_PAT_CHUNK;
    int rows  = d->flatLines - start;
    return rows > SV_PAT_CHUNK ? SV_PAT_CHUNK : rows;
}

static int sv_pattern_get(RewampDecoder* d, int chunk, RewampPatternCell* out, int maxCells) {
    if (!d || !d->flat || !out) return 0;
    int rows = sv_pattern_num_rows(d, chunk);
    if (rows <= 0) return 0;
    int start = chunk * SV_PAT_CHUNK;
    int cells = rows * d->ncols;
    if (cells > maxCells) cells = (maxCells / d->ncols) * d->ncols;   /* whole rows only */
    memcpy(out, &d->flat[(size_t)start * d->ncols], (size_t)cells * sizeof(RewampPatternCell));
    return cells;
}

static void sv_pattern_cursor(RewampDecoder* d, int* order, int* row) {
    if (order) *order = -1;
    if (row)   *row   = -1;
    if (!d || d->flatLines <= 0 || s_active != d) return;
    int line = sv_get_current_line(SV_SLOT);
    if (line < 0) line = 0;
    if (line >= d->flatLines) line = d->flatLines - 1;
    if (order) *order = line / SV_PAT_CHUNK;
    if (row)   *row   = line % SV_PAT_CHUNK;
}

static const RewampPluginVTable kVTable = {
    /* name           */ "SunVox",
    /* probe          */ sv_probe,
    /* open           */ sv_open,
    /* read           */ sv_read,
    /* seek           */ sv_seek,
    /* length         */ sv_length,
    /* close          */ sv_close,
    /* configure_loop */ NULL,   /* generic loop (self-loops natively, SID-like) */
    /* supportsNativeFadeout */ 0,
    /* engine_id      */ NULL,
    /* param_changed  */ NULL,
    /* pattern_song_info */ sv_pattern_song_info,
    /* pattern_order  */ sv_pattern_order,
    /* pattern_num_rows */ sv_pattern_num_rows,
    /* pattern_get    */ sv_pattern_get,
    /* pattern_cursor */ sv_pattern_cursor,
};

extern "C" const RewampPluginVTable* rewamp_sunvox_plugin(void) { return &kVTable; }

#endif /* REWAMP_WITH_SUNVOX */
