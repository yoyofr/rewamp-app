#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"
#include "rewamp_waveform.h"

#if defined(__APPLE__)
#include <iconv.h>
#elif !defined(_WIN32)
#include <dlfcn.h>   /* iconv résolu à l'exécution: bionic ≥ API 28, glibc */
#endif

#include <limits.h>
#include <stdlib.h>
#include <string.h>

/* ── Global definitions (declared extern in ModizerVoicesData.h) ────────── */

/* Modizer-era app global: the directory vendored cores look in for auxiliary
 * ROMs they load themselves. Both PC-98 engines want the YM2608 (OPNA) ADPCM
 * rhythm ROM from it — libpmdmini's OPNA::Init and libfmpmini's
 * fmplayer_drumrom_unix.c each declare their own `extern char bundlePath[]`,
 * so it can live in neither plugin: whichever one owned it would become a link
 * dependency of the other. The plugins point it at <datadir>/opna/ in open().
 */
char bundlePath[1024];

signed char      *m_voice_buff[SOUND_MAXVOICES_BUFFER_FX];
int64_t           m_voice_current_ptr[SOUND_MAXVOICES_BUFFER_FX];
int64_t           m_voice_prev_current_ptr[SOUND_MAXVOICES_BUFFER_FX];
int               m_voice_ChipID[SOUND_MAXVOICES_BUFFER_FX];

signed char       m_voice_current_system     = 0;
signed char       m_voice_current_systemSub  = 0;
char              m_voice_current_systemPairedOfs = 0;
char              m_voice_current_total      = 0;
int               m_voice_current_samplerate = 44100;
double            m_voice_current_rateratio  = 1.0;

unsigned int      vgm_last_vol[SOUND_MAXVOICES_BUFFER_FX];
unsigned int      vgm_last_note[SOUND_MAXVOICES_BUFFER_FX];
unsigned char     vgm_last_instr[SOUND_MAXVOICES_BUFFER_FX];
unsigned int      vgm_last_sample_address[SOUND_MAXVOICES_BUFFER_FX];
unsigned int      vgm_last_sample_address_inst[256];
unsigned char     vgm_last_sample_address_lastupdate[SOUND_MAXVOICES_BUFFER_FX];

signed int       *m_voice_buff_accumul_temp[SOUND_MAXVOICES_BUFFER_FX];
unsigned char    *m_voice_buff_accumul_temp_cnt[SOUND_MAXVOICES_BUFFER_FX];
int               m_voice_buff_adjustement = 0;
int               m_voice_fadeout_factor   = 0;

int64_t           generic_mute_mask  = 0;
int               m_voicesForceOfs   = 0;

int64_t           mdz_ratio_fp_cnt = 0;
int64_t           mdz_ratio_fp_inc = 0;
int64_t           mdz_ratio_fp_inv_inc = 0;
double            mdz_pbratio = 1.0;

int               m_genNumVoicesChannels     = 0;
int               m_genNumMidiVoicesChannels = 0;
int               m_genMasterVol             = 256; /* libnsfplay fader.h extern */
char              m_voicesStatus[SOUND_MAXMOD_CHANNELS];
int               m_voice_systemColor[SOUND_VOICES_MAX_ACTIVE_CHIPS];
int               m_voice_voiceColor[SOUND_MAXVOICES_BUFFER_FX];

char              vgmVRC7   = 0;
char              vgm2610b  = 0;

/* Voice / chipset grouping metadata (see ModizerVoicesData.h). */
char              modizChipsetStartVoice[MODIZ_MAX_CHIPS];
char              modizChipsetVoicesCount[MODIZ_MAX_CHIPS];
char              modizChipsetName[MODIZ_MAX_CHIPS][MODIZ_CHIP_NAME_MAX_CHAR];
char              modizVoicesName[SOUND_MAXVOICES_BUFFER_FX][MODIZ_VOICE_NAME_MAX_CHAR];
char              modizInstrName[MODIZ_MAX_INSTR][MODIZ_VOICE_NAME_MAX_CHAR];
static unsigned   g_instr_name_gen = 0;
unsigned rewamp_instrument_names_gen(void) { return g_instr_name_gen; }
char              modizChipsetCount = 0;

/* libsidplayfp oscilloscope state (SID.cpp Modizer patches) */
void             *m_sid_chipId[MAXSID_CHIPS] = {0};
int               m_sid_chipNb = 1;
char              mSIDSeekInProgress = 0;
int               sid_v4 = 0;

short int         pmBuffer[PM_BUFFER_SIZE * 2];
int               pmBufferPosWrite = 0;
int               pmBufferPosRead  = 0;

unsigned char     m_voice_channel_mapping[256];
unsigned char     m_channel_voice_mapping[256];

/* ── Internal state ────────────────────────────────────────────────────── */

/* Per-channel oscilloscope ring buffer (8-bit signed samples).
 * Sized to the LARGEST write mask used by any backend core:
 *   - libvgm cores index with &(SOUND_BUFFER_SIZE_SAMPLE*4*2-1)
 *   - libgme cores (e.g. Spc_Dsp) index with &(SOUND_BUFFER_SIZE_SAMPLE*4*4-1)
 * The buffer MUST cover the max (*4*4); using *4*2 let libgme write up to 2×
 * past the allocation → heap corruption → crash during sustained playback. */
#define RING_BUF_SAMPLES (SOUND_BUFFER_SIZE_SAMPLE * 4 * 4)

static int g_channel_count    = 0;
static int g_ring_write_size  = RING_BUF_SAMPLES; /* set by each backend */

/* ── Delayed per-voice store (look-ahead sync) ──────────────────────────────
 * When the data source decodes ahead of playback (~2s) for the notation
 * visualizer, the per-voice oscilloscope rings (above) get written at PRODUCER
 * time. To keep the voice oscilloscope synced to the HEARD audio, each producer
 * step also appends the freshly written voice samples into a large per-voice
 * delayed ring, indexed by absolute oscilloscope-sample position. The scope then
 * reads a window ending at the CONSUMER position. Inactive (no decode-ahead) →
 * scope reads the live ring as before. */
#define DRING_SAMPLES   131072            /* ~2.97s @44100, power of two */
#define DRING_MASK      (DRING_SAMPLES - 1)
static int8_t*  g_dring[SOUND_MAXVOICES_BUFFER_FX];     /* per-voice delayed ring */
static int64_t  g_dprev[SOUND_MAXVOICES_BUFFER_FX];     /* last copied osc-sample count */
static volatile int64_t g_consumer_pos = 0;             /* heard position (frames) */
static int      g_delayed_active = 0;

/* Per-channel previous ptr — used to detect when the write pointer has wrapped
 * around (ptr_now < ptr_prev).  libnsfplay writes with a circular ptr that
 * cycles in [0, REWAMP_NSF_OSCILLO_SIZE); after the first wrap the ring is
 * fully valid and `available` must be the full ring size, not the current ptr.
 * No explicit "circular mode" flag is needed: the wrap is detected automatically. */
static int g_ring_circular = 0;   /* set by plugin: ptr wraps mod g_ring_write_size */
static int64_t g_ring_warmup[SOUND_MAXVOICES_BUFFER_FX]; /* samples written so far (monotonic) */

/* ── Oscilloscope trigger (NCC correlation-based stabilization) ─────────── */

/* Full-resolution template length (bytes, = beginning of previous frame).
 * 512 samples ≈ 5 periods at 440 Hz / 48 kHz → good peak discrimination. */
#define TRIGGER_TEMPLATE_SIZE   512

/* Decimation factor for the coarse global search.  Box-filter average of D
 * samples → aliases above fs/(2D) but fine for periodic chip signals. */
#define TRIGGER_DECIM            4

/* Coarse search window in *real* samples.  Covers down to ~28 Hz at 48 kHz
 * (period ≈ 1714 samples).  Must satisfy outLen + TRIGGER_SEARCH_LEN ≤
 * g_ring_write_size (worst case 4096 for libvgm/openmpt backends):
 *   735 + 1700 = 2435 < 4096 ✓  */
#define TRIGGER_SEARCH_LEN      1700

/* Per-channel template (beginning of previous aligned frame, full-res). */
static int8_t g_trigger_template[SOUND_MAXVOICES_BUFFER_FX][TRIGGER_TEMPLATE_SIZE];

/* Shared work buffers — UI thread only (calls are sequential). */
/* Puits d'écriture pour les voies NON allouées. Les coeurs de puce calculent
 * eux-mêmes l'index de voie où écrire leur oscilloscope (offset du chip +
 * décalage de puce liée), et un index faux y devient un déréférencement de
 * NULL — sur le fil PRODUCTEUR, donc un plantage du processus. Payé deux fois:
 * NES+FDS (voir vgm-nes-fds-voice-crash) puis le SSG du YM2203 en 2026-08-21.
 * Les slots inutilisés pointent donc vers ce tampon partagé: une écriture
 * égarée est perdue au lieu de tuer l'app. Il n'est JAMAIS relu, donc le
 * partage entre slots (et entre fils) est sans conséquence.
 * ⚠️ Ce n'est PAS un correctif: la cause doit être traitée dans le coeur. */
static signed char g_voice_sink[RING_BUF_SAMPLES];

static int8_t g_trigger_raw[RING_BUF_SAMPLES];
static int8_t g_trigger_raw_ds[RING_BUF_SAMPLES / TRIGGER_DECIM]; /* decimated raw */
static int    g_trigger_tmpl_zm[TRIGGER_TEMPLATE_SIZE];           /* zero-mean, full-res */
static int    g_trigger_tmpl_ds_zm[TRIGGER_TEMPLATE_SIZE / TRIGGER_DECIM]; /* coarse */

/* ── API ─────────────────────────────────────────────────────────────────── */

void rewamp_channel_data_init(void) {
    memset(m_voice_buff, 0, sizeof(m_voice_buff));
    memset(m_voice_buff_accumul_temp, 0, sizeof(m_voice_buff_accumul_temp));
    memset(m_voice_buff_accumul_temp_cnt, 0, sizeof(m_voice_buff_accumul_temp_cnt));
    g_channel_count = 0;
}

void rewamp_channel_data_cleanup(void) {
    for (int i = 0; i < SOUND_MAXVOICES_BUFFER_FX; i++) {
        if (m_voice_buff[i] && m_voice_buff[i] != g_voice_sink) {
            free(m_voice_buff[i]);
        }
        m_voice_buff[i] = NULL;
        if (m_voice_buff_accumul_temp[i]) {
            free(m_voice_buff_accumul_temp[i]);
            m_voice_buff_accumul_temp[i] = NULL;
        }
        if (m_voice_buff_accumul_temp_cnt[i]) {
            free(m_voice_buff_accumul_temp_cnt[i]);
            m_voice_buff_accumul_temp_cnt[i] = NULL;
        }
        if (g_dring[i]) {
            free(g_dring[i]);
            g_dring[i] = NULL;
        }
    }
    g_channel_count = 0;
}

void rewamp_channel_data_reset(int channelCount) {
    /* Free any existing buffers first. */
    rewamp_channel_data_cleanup();

    if (channelCount <= 0 || channelCount > SOUND_MAXVOICES_BUFFER_FX)
        channelCount = 0;

    memset(m_voice_ChipID, -1, sizeof(m_voice_ChipID));
    /* Reset voice/chip grouping metadata + mute mask (all voices audible). */
    modizChipsetCount = 0;
    memset(modizChipsetStartVoice, 0, sizeof(modizChipsetStartVoice));
    memset(modizChipsetVoicesCount, 0, sizeof(modizChipsetVoicesCount));
    memset(modizChipsetName, 0, sizeof(modizChipsetName));
    memset(modizVoicesName, 0, sizeof(modizVoicesName));
    generic_mute_mask = 0;
    memset(m_voice_current_ptr, 0, sizeof(m_voice_current_ptr));
    memset(m_voice_prev_current_ptr, 0, sizeof(m_voice_prev_current_ptr));
    memset(vgm_last_vol, 0, sizeof(vgm_last_vol));
    memset(vgm_last_note, 0, sizeof(vgm_last_note));
    memset(vgm_last_instr, 0, sizeof(vgm_last_instr));

    for (int i = 0; i < channelCount; i++) {
        m_voice_buff[i] = (signed char*)calloc(RING_BUF_SAMPLES, 1);
        g_dring[i]      = (int8_t*)calloc(DRING_SAMPLES, 1);
        g_dprev[i]      = 0;
    }
    /* Filet: au-delà des voies réellement allouées, un puits partagé plutôt que
     * NULL (voir g_voice_sink). Les lecteurs de scope bornent leur index par le
     * nombre de voies, ils ne verront jamais ce tampon. */
    for (int i = channelCount; i < SOUND_MAXVOICES_BUFFER_FX; i++)
        m_voice_buff[i] = g_voice_sink;
    g_consumer_pos = 0;
    /* accumul_temp[0] is a scratch buffer used by the libopenmpt Fastmix patch
     * to capture the pre-mix buffer content so each channel's contribution can
     * be isolated.  Allocate when any channel-based decoder is active. */
    if (channelCount > 0) {
        m_voice_buff_accumul_temp[0] = (signed int*)calloc(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2, sizeof(signed int));
    }

    m_voice_current_system     = 0;
    m_voice_current_systemSub  = 0;
    m_voice_current_systemPairedOfs = 0;
    m_voice_current_total      = 0;
    m_voice_current_samplerate = 44100;
    m_voice_current_rateratio  = 1.0;

    vgmVRC7  = 0;
    vgm2610b = 0;

    g_channel_count   = channelCount;
    g_ring_write_size = RING_BUF_SAMPLES;
    g_ring_circular   = 0;
    memset(g_ring_warmup, 0, sizeof(g_ring_warmup));
    memset(g_trigger_template, 0, sizeof(g_trigger_template));
}

void rewamp_channel_data_clear(void) {
    for (int i = 0; i < SOUND_MAXVOICES_BUFFER_FX; i++) {
        /* Seul site qui balaie les 256 slots: sauter le puits, sinon on
         * effacerait 250 fois le même tampon partagé pour rien. */
        if (m_voice_buff[i] && m_voice_buff[i] != g_voice_sink)
            memset(m_voice_buff[i], 0, RING_BUF_SAMPLES);
        m_voice_current_ptr[i]      = 0;
        m_voice_prev_current_ptr[i] = 0;
        vgm_last_vol[i]   = 0;
        vgm_last_note[i]  = 0;
        vgm_last_instr[i] = 0;
    }
    memset(g_trigger_template, 0, sizeof(g_trigger_template));
    // Leave g_channel_count unchanged: oscilloscope stays visible but shows
    // blank waveforms, then refills when playback resumes.
}

void rewamp_channel_data_set_ring_write_size(int size) {
    if (size > 0 && size <= RING_BUF_SAMPLES)
        g_ring_write_size = size;
}

void rewamp_channel_data_set_ring_circular(int circular) {
    g_ring_circular = circular ? 1 : 0;
}

/* ── Delayed store (look-ahead sync) ───────────────────────────────────────── */

/* Enable the delayed per-voice store (decode-ahead active). Works for all cores
 * incl. circular-ptr ones (libnsfplay): capture copies the last-written samples
 * via modulo, and reads index the delayed ring by absolute frame position. */
void rewamp_channel_data_set_delayed(int active) {
    g_delayed_active = active ? 1 : 0;
}

void rewamp_channel_data_set_consumer_pos(int64_t framePos) {
    g_consumer_pos = framePos;
}

/* Appends the per-voice samples produced by the latest decode step into the
 * delayed ring, keyed by ABSOLUTE audio frame position [startFramePos .. +frames)
 * (so it stays aligned with the consumer cursor across seeks). Assumes the
 * oscilloscope sample rate equals the audio rate (true for the chip cores).
 * Called by the producer after each decode step. */
void rewamp_channel_data_capture_delayed(int64_t startFramePos, int frames) {
    if (!g_delayed_active || frames <= 0) return;
    if (frames > DRING_SAMPLES) frames = DRING_SAMPLES;
    const int rsize = g_ring_write_size;
    for (int v = 0; v < g_channel_count; v++) {
        if (!g_dring[v] || !m_voice_buff[v]) continue;
        int64_t cnt = m_voice_current_ptr[v] >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
        int64_t src = cnt - frames;   /* the just-written window in the live ring */
        for (int i = 0; i < frames; i++) {
            int64_t s = src + i;
            int8_t  v8 = (s >= 0) ? m_voice_buff[v][(int)(((s % rsize) + rsize) % rsize)] : 0;
            g_dring[v][(startFramePos + i) & DRING_MASK] = v8;
        }
    }
    (void)g_dprev;
}


void rewamp_channel_data_fade_recent(int frames, float gainStart, float gainEnd) {
    if (frames <= 0 || (gainStart >= 1.0f && gainEnd >= 1.0f)) return;
    const int rsize = g_ring_write_size;
    if (rsize <= 0) return;
    if (frames > rsize) frames = rsize;
    for (int v = 0; v < g_channel_count; v++) {
        signed char* buf = m_voice_buff[v];
        /* Le PUITS est partagé par toutes les voies au-delà du compte alloué:
         * l'atténuer reviendrait à le faire N fois, et il ne s'affiche pas. */
        if (!buf || buf == g_voice_sink) continue;
        const int64_t cnt = m_voice_current_ptr[v] >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
        for (int i = 0; i < frames; i++) {
            const int64_t s = cnt - frames + i;
            if (s < 0) continue;
            const float t = frames > 1 ? (float)i / (float)(frames - 1) : 1.0f;
            const float g = gainStart + (gainEnd - gainStart) * t;
            const int idx = (int)(((s % rsize) + rsize) % rsize);
            buf[idx] = (signed char)((float)buf[idx] * g);
        }
    }
}

/* Backends with no per-voice data (vgmstream, miniaudio fallback) leave
 * g_channel_count == 0; we then expose 2 virtual voices (L/R) fed from the
 * main output waveform ring so the per-voice scope still shows something. */
#define WAVEFORM_FALLBACK_VOICES 2

int rewamp_channel_count(void) {
    return g_channel_count ? g_channel_count : WAVEFORM_FALLBACK_VOICES;
}

/* Raw count WITHOUT the 2-virtual-voice fallback: 0 ⇒ the backend exposes no
 * per-voice data (stereo-only). Used by the datasource to decide whether
 * generic_mute_mask bits 0/1 mean "mute L/R output". */
int rewamp_channel_count_raw(void) {
    return g_channel_count;
}

/* Copy the last `n` samples from channel ch's ring into `out`.
 * Returns actual count (may be < n if insufficient data written yet). */
static int ring_read(int ch, int8_t* out, int n) {
    /* Delayed mode: read a window ending at the consumer (heard) position from
     * the large delayed ring → voice oscilloscope stays synced to the audio
     * even though the decoder runs ~2s ahead. */
    if (g_delayed_active && g_dring[ch]) {
        int64_t end = g_consumer_pos;
        if (n > DRING_SAMPLES) n = DRING_SAMPLES;
        if (n > end) n = (int)end;
        if (n <= 0) return 0;
        int64_t start = end - n;
        for (int i = 0; i < n; i++)
            out[i] = g_dring[ch][(start + i) & DRING_MASK];
        return n;
    }

    int64_t ptr   = m_voice_current_ptr[ch] >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
    int     rsize = g_ring_write_size;

    /* Tear guard: the audio thread writes bursts into the ring while we read
     * (lock-free by design). Reading right AT the write head can catch a
     * half-written window — half old cycle, half new — which flashes as a
     * "ghost" waveform (very visible on a 120 Hz voice scope). Read a window
     * that ends a burst-sized margin BEHIND the head instead (~23 ms). */
    {
        int margin = rsize / 4;
        if (margin > 1024) margin = 1024;
        ptr -= margin;
        if (!g_ring_circular && ptr < 0) ptr = 0;
    }

    /* Circular mode (libnsfplay): ptr wraps mod rsize.  The ring is always
     * fully valid once the plugin sets the flag — first ~93ms may show zeros
     * (calloc'd) but that is better than flickering to blank on every wrap. */
    int available = (g_ring_circular)
                    ? rsize
                    : ((ptr < rsize) ? (int)ptr : rsize);
    if (n > available) n = available;
    if (n <= 0) return 0;

    /* Modulo handles negative (ptr - n) for the circular case. */
    int start = (int)(((ptr - n) % rsize + rsize) % rsize);
    int tail  = rsize - start;

    if (tail >= n) {
        memcpy(out, m_voice_buff[ch] + start, (size_t)n);
    } else {
        memcpy(out,        m_voice_buff[ch] + start, (size_t)tail);
        memcpy(out + tail, m_voice_buff[ch],          (size_t)(n - tail));
    }
    return n;
}

/* Muted voices draw a flat line: many cores (libvgm, gbsplay) keep writing
 * their scope ring pre-mute (muting happens at their mix stage), so the
 * display side is the one place that reliably covers every backend. */
static int channel_muted(int ch) {
    return (ch >= 0 && ch < 64) && ((generic_mute_mask >> ch) & 1);
}

int rewamp_channel_buf(int ch, int8_t* out, int outLen) {
    if (g_channel_count == 0)            /* waveform fallback (L/R) */
        return rewamp_waveform_read_i8(ch, out, outLen);
    if (ch < 0 || ch >= g_channel_count) return 0;
    if (!m_voice_buff[ch]) return 0;
    if (channel_muted(ch)) { memset(out, 0, (size_t)outLen); return outLen; }
    return ring_read(ch, out, outLen);
}

int rewamp_channel_buf_triggered(int ch, int8_t* out, int outLen) {
    if (g_channel_count == 0)            /* waveform fallback: raw, no trigger */
        return rewamp_waveform_read_i8(ch, out, outLen);
    if (ch < 0 || ch >= g_channel_count || !m_voice_buff[ch]) return 0;
    if (outLen <= 0) return 0;
    if (channel_muted(ch)) { memset(out, 0, (size_t)outLen); return outLen; }

    int totalNeeded = outLen + TRIGGER_SEARCH_LEN;
    if (totalNeeded > RING_BUF_SAMPLES) totalNeeded = RING_BUF_SAMPLES;

    int got = ring_read(ch, g_trigger_raw, totalNeeded);
    if (got < outLen) {
        memcpy(out, g_trigger_raw, (size_t)got);
        return got;
    }

    int searchLen = got - outLen;
    int best_d    = 0;

    int8_t* tmpl = g_trigger_template[ch];
    int Mf = (TRIGGER_TEMPLATE_SIZE < outLen) ? TRIGGER_TEMPLATE_SIZE : outLen;

    /* ── Build full-res zero-mean template ──────────────────────────────── */
    int tmpl_sum = 0;
    for (int i = 0; i < Mf; i++) tmpl_sum += (int)tmpl[i];
    int tmpl_mean   = tmpl_sum / Mf;
    int tmpl_energy = 0;
    for (int i = 0; i < Mf; i++) {
        int v = (int)tmpl[i] - tmpl_mean;
        g_trigger_tmpl_zm[i] = v;
        tmpl_energy += (v < 0 ? -v : v);
    }

    if (tmpl_energy > 0 && searchLen > 0) {
        /* ── Coarse pass: box-filter decimation by TRIGGER_DECIM ─────────
         *
         * Reduces the search space from O(searchLen × Mf) to
         * O((searchLen/D) × (Mf/D)) — D² times fewer multiply-adds.
         * Box filter preserves periodic structure down to fs/(2D). */
        int D  = TRIGGER_DECIM;
        int Mc = Mf / D;                /* coarse template length */
        int raw_ds_len = got / D;
        int sc = searchLen / D;         /* coarse search steps */

        /* Decimate raw buffer. */
        for (int i = 0; i < raw_ds_len; i++) {
            int s = 0;
            for (int j = 0; j < D; j++) s += (int)g_trigger_raw[i * D + j];
            g_trigger_raw_ds[i] = (int8_t)(s / D);
        }

        /* Decimate template + zero-mean. */
        int tmpl_ds_sum = 0;
        for (int i = 0; i < Mc; i++) {
            int s = 0;
            for (int j = 0; j < D; j++) s += (int)tmpl[i * D + j];
            g_trigger_tmpl_ds_zm[i] = s / D; /* store raw mean first */
            tmpl_ds_sum += g_trigger_tmpl_ds_zm[i];
        }
        int tmpl_ds_mean = tmpl_ds_sum / Mc;
        int tmpl_ds_energy = 0;
        for (int i = 0; i < Mc; i++) {
            int v = g_trigger_tmpl_ds_zm[i] - tmpl_ds_mean;
            g_trigger_tmpl_ds_zm[i] = v;
            tmpl_ds_energy += (v < 0 ? -v : v);
        }

        int best_dc = 0;
        if (tmpl_ds_energy > 0 && sc > 0) {
            /* NCC on decimated buffers with sliding-window mean.
             * Overflow: |(ds[d+i] - mean)| ≤ 127, product ≤ 16 129,
             * sum of Mc=128 ≤ 2 064 512 < INT_MAX. */
            int win_sum = 0;
            for (int i = 0; i < Mc; i++) win_sum += (int)g_trigger_raw_ds[i];

            int best_corr = INT_MIN;
            for (int d = 0; d < sc; d++) {
                int wm   = win_sum / Mc;
                int corr = 0;
                for (int i = 0; i < Mc; i++)
                    corr += ((int)g_trigger_raw_ds[d + i] - wm) * g_trigger_tmpl_ds_zm[i];
                if (corr > best_corr) { best_corr = corr; best_dc = d; }
                win_sum += (int)g_trigger_raw_ds[d + Mc] - (int)g_trigger_raw_ds[d];
            }
        }

        /* ── Fine pass: full-res NCC in ±D samples around coarse peak ─── */
        int fine_center = best_dc * D;
        int fine_start  = fine_center - D;
        int fine_end    = fine_center + D + 1;
        if (fine_start < 0)          fine_start = 0;
        if (fine_end   > searchLen)  fine_end   = searchLen;

        int best_corr_f = INT_MIN;
        for (int d = fine_start; d < fine_end; d++) {
            /* Local mean over [d, d+Mf) via running sum (recompute per step —
             * window is tiny so no sliding needed). */
            int lsum = 0;
            for (int i = 0; i < Mf; i++) lsum += (int)g_trigger_raw[d + i];
            int lmean = lsum / Mf;
            int corr  = 0;
            for (int i = 0; i < Mf; i++)
                corr += ((int)g_trigger_raw[d + i] - lmean) * g_trigger_tmpl_zm[i];
            if (corr > best_corr_f) { best_corr_f = corr; best_d = d; }
        }
    }

    memcpy(out, g_trigger_raw + best_d, (size_t)outLen);

    /* Update template with the beginning of the newly aligned frame. */
    int tmplCopy = (Mf < outLen) ? Mf : outLen;
    memcpy(tmpl, g_trigger_raw + best_d, (size_t)tmplCopy);

    return outLen;
}

int64_t rewamp_channel_write_ptr(int ch) {
    if (g_channel_count == 0)               /* fallback: main waveform head */
        return (ch >= 0 && ch <= 1) ? rewamp_waveform_pos() : 0;
    if (ch < 0 || ch >= g_channel_count) return 0;
    return m_voice_current_ptr[ch] >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
}

float rewamp_channel_freq_hz(int ch) {
    if (g_channel_count == 0) return 0.0f;   /* fallback: no pitch info */
    if (ch < 0 || ch >= g_channel_count) return 0.0f;
    if (channel_muted(ch)) return 0.0f;
    return (float)vgm_last_note[ch];
}

int rewamp_channel_volume(int ch) {
    if (g_channel_count == 0) {              /* fallback: peak of last frame */
        if (ch < 0 || ch > 1) return 0;
        int8_t tmp[256];
        int n = rewamp_waveform_read_i8(ch, tmp, 256);
        int peak = 0;
        for (int i = 0; i < n; i++) {
            int v = tmp[i] < 0 ? -tmp[i] : tmp[i];
            if (v > peak) peak = v;
        }
        return peak;
    }
    if (ch < 0 || ch >= g_channel_count) return 0;
    if (channel_muted(ch)) return 0;
    return (int)vgm_last_vol[ch];
}

/* ── Voice / chipset grouping metadata ─────────────────────────────────────
 * A plugin describes its voices in open(): reset, then add one chip per sound
 * source (auto-assigning m_voice_ChipID), then optionally name each voice.
 * When a plugin sets nothing, the FFI getters synthesize a single "—" chip
 * spanning all voices with names "Voice N" (see rewamp_audio.c). */

void rewamp_voices_meta_reset(void) {
    modizChipsetCount = 0;
    memset(modizChipsetStartVoice, 0, sizeof(modizChipsetStartVoice));
    memset(modizChipsetVoicesCount, 0, sizeof(modizChipsetVoicesCount));
    memset(modizChipsetName, 0, sizeof(modizChipsetName));
    memset(modizVoicesName, 0, sizeof(modizVoicesName));
    memset(modizInstrName, 0, sizeof(modizInstrName));
    g_instr_name_gen++;
}

int rewamp_voices_add_chip(const char* name, int startVoice, int count) {
    if (modizChipsetCount >= MODIZ_MAX_CHIPS) return -1;
    if (startVoice < 0 || count <= 0) return -1;
    int idx = modizChipsetCount;
    modizChipsetStartVoice[idx]  = (char)startVoice;
    modizChipsetVoicesCount[idx] = (char)count;
    if (name) {
        strncpy(modizChipsetName[idx], name, MODIZ_CHIP_NAME_MAX_CHAR - 1);
        modizChipsetName[idx][MODIZ_CHIP_NAME_MAX_CHAR - 1] = '\0';
    }
    /* Deliberately do NOT touch m_voice_ChipID here: some cores (libvgm) use
     * it to ROUTE their scope writes (value = libvgm device id, set by the
     * plugin), which is unrelated to this UI chip index. The UI derives a
     * voice's chip from the [startVoice, startVoice+count) ranges instead
     * (rewamp_voice_chip in rewamp_audio.c). */
    modizChipsetCount++;
    return idx;
}

void rewamp_voice_set_name(int v, const char* name) {
    if (v < 0 || v >= SOUND_MAXVOICES_BUFFER_FX || !name) return;
    strncpy(modizVoicesName[v], name, MODIZ_VOICE_NAME_MAX_CHAR - 1);
    modizVoicesName[v][MODIZ_VOICE_NAME_MAX_CHAR - 1] = '\0';
}

void rewamp_instrument_set_name(int idx, const char* name) {
    if (idx <= 0 || idx >= MODIZ_MAX_INSTR || !name) return;
    /* Un nom identique ne fait pas avancer la génération: sinon un moteur qui
     * repose le même nom ferait invalider le cache de l'UI à chaque pas. */
    if (strncmp(modizInstrName[idx], name, MODIZ_VOICE_NAME_MAX_CHAR - 1) == 0) return;
    strncpy(modizInstrName[idx], name, MODIZ_VOICE_NAME_MAX_CHAR - 1);
    modizInstrName[idx][MODIZ_VOICE_NAME_MAX_CHAR - 1] = '\0';
    g_instr_name_gen++;
}

/* ── Track info message (Modizer mod_message equivalent) ─────────────────── */

#include <stdarg.h>
#include <stdio.h>

static char g_track_message[REWAMP_TRACK_MSG_MAX];

void rewamp_track_message_clear(void) {
    g_track_message[0] = '\0';
}

void rewamp_track_message_append(const char* fmt, ...) {
    if (!fmt) return;
    size_t used = strlen(g_track_message);
    if (used >= REWAMP_TRACK_MSG_MAX - 1) return;
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(g_track_message + used, REWAMP_TRACK_MSG_MAX - used, fmt, ap);
    va_end(ap);
}

/* ── ISO-8859-1 → UTF-8 ────────────────────────────────────────────────────── */

/* True when `s` is well-formed UTF-8. Used to leave an already-converted tag
 * alone: the two encodings cannot be mistaken for one another, since a Latin-1
 * accented byte (0xA0-0xFF standing alone) is never a valid UTF-8 sequence. */
static int rewamp_is_utf8(const unsigned char* s, size_t len) {
    size_t i = 0;
    while (i < len) {
        unsigned char c = s[i];
        int extra;
        if (c < 0x80)             { i++; continue; }
        else if ((c & 0xE0) == 0xC0) extra = 1;
        else if ((c & 0xF0) == 0xE0) extra = 2;
        else if ((c & 0xF8) == 0xF0) extra = 3;
        else return 0;
        if (i + (size_t)extra >= len) return 0;
        for (int k = 1; k <= extra; k++)
            if ((s[i + k] & 0xC0) != 0x80) return 0;
        i += (size_t)extra + 1;
    }
    return 1;
}

void rewamp_latin1_to_utf8(const char* in, char* out, size_t outCap) {
    if (!out || outCap == 0) return;
    if (!in) { out[0] = '\0'; return; }

    const size_t inLen = strlen(in);
    if (rewamp_is_utf8((const unsigned char*)in, inLen)) {
        size_t n = inLen < outCap - 1 ? inLen : outCap - 1;
        memcpy(out, in, n);
        out[n] = '\0';
        return;
    }
    size_t w = 0;
    for (size_t i = 0; i < inLen; i++) {
        const unsigned char c = (unsigned char)in[i];
        if (c < 0x80) {
            if (w + 1 >= outCap) break;
            out[w++] = (char)c;
        } else {
            if (w + 2 >= outCap) break;
            out[w++] = (char)(0xC0 | (c >> 6));
            out[w++] = (char)(0x80 | (c & 0x3F));
        }
    }
    out[w] = '\0';
}

/* ── Shift-JIS → UTF-8 ─────────────────────────────────────────────────────── */

void rewamp_sjis_to_utf8(const char* in, char* out, size_t outCap) {
    if (!out || outCap == 0) return;
    if (!in) { out[0] = '\0'; return; }

    size_t inLen = strlen(in);
    int ascii = 1;
    for (size_t i = 0; i < inLen; i++) {
        if ((unsigned char)in[i] >= 0x80) { ascii = 0; break; }
    }
    if (ascii) {
        size_t n = inLen < outCap - 1 ? inLen : outCap - 1;
        memcpy(out, in, n);
        out[n] = '\0';
        return;
    }

#if defined(__APPLE__)
    {
        iconv_t cd = iconv_open("UTF-8", "CP932");
        if (cd != (iconv_t)-1) {
            char*  src     = (char*)in;
            size_t srcLeft = inLen;
            char*  dst     = out;
            size_t dstLeft = outCap - 1;
            /* Partial output on an undecodable byte is fine — better a
             * truncated real title than none at all. */
            iconv(cd, &src, &srcLeft, &dst, &dstLeft);
            *dst = '\0';
            iconv_close(cd);
            if (out[0]) return;
        }
    }
#elif !defined(_WIN32)
    {
        /* Même conversion, iconv cherché à l'exécution (comme
         * StrUtils-CPConv_Stub.c): présent dans la glibc et dans bionic
         * depuis l'API 28; absent, on retombe sur le '?' par glyphe. */
        typedef void*  (*open_fn)(const char*, const char*);
        typedef size_t (*conv_fn)(void*, char**, size_t*, char**, size_t*);
        typedef int    (*close_fn)(void*);
        static open_fn  s_open;
        static conv_fn  s_conv;
        static close_fn s_close;
        static int      s_looked;
        if (!s_looked) {
            s_looked = 1;
            void* self = dlopen(NULL, RTLD_LAZY);
            if (self) {
                s_open  = (open_fn) dlsym(self, "iconv_open");
                s_conv  = (conv_fn) dlsym(self, "iconv");
                s_close = (close_fn)dlsym(self, "iconv_close");
            }
        }
        if (s_open && s_conv && s_close) {
            void* cd = s_open("UTF-8", "CP932");
            if (cd == (void*)-1) cd = s_open("UTF-8", "SHIFT_JIS");
            if (cd != (void*)-1) {
                char*  src     = (char*)in;
                size_t srcLeft = inLen;
                char*  dst     = out;
                size_t dstLeft = outCap - 1;
                s_conv(cd, &src, &srcLeft, &dst, &dstLeft);
                *dst = '\0';
                s_close(cd);
                if (out[0]) return;
            }
        }
    }
#endif
    /* No converter: one '?' per glyph (skip the SJIS trail byte, or a
     * two-byte kanji would print as two '?'). */
    {
        size_t w = 0;
        for (size_t i = 0; i < inLen && w < outCap - 1; i++) {
            unsigned char c = (unsigned char)in[i];
            out[w++] = (c < 0x80) ? (char)c : '?';
            if (c >= 0x81) i++;
        }
        out[w] = '\0';
    }
}

int rewamp_utf8_valid(const char* s) {
    const unsigned char* p = (const unsigned char*)s;
    if (!p) return 0;
    while (*p) {
        unsigned char c = *p;
        int n = c < 0x80 ? 0 : (c >> 5) == 6 ? 1 : (c >> 4) == 14 ? 2 : (c >> 3) == 30 ? 3 : -1;
        if (n < 0) return 0;
        for (int i = 1; i <= n; i++) if ((p[i] & 0xC0) != 0x80) return 0;
        p += n + 1;
    }
    return 1;
}

void rewamp_text_to_utf8(const char* in, char* out, size_t outCap) {
    if (!out || outCap == 0) return;
    if (!in) { out[0] = '\0'; return; }
    if (rewamp_utf8_valid(in)) {
        size_t n = strlen(in);
        if (n > outCap - 1) n = outCap - 1;
        memcpy(out, in, n);
        out[n] = '\0';
        return;
    }
    rewamp_sjis_to_utf8(in, out, outCap);
}

void rewamp_psf_tag_copy(char* dst, size_t dstCap, const char* value) {
    if (!dst || dstCap == 0) return;
    if (!value) { dst[0] = '\0'; return; }
    char line[1024];
    size_t n = 0;
    while (value[n] && value[n] != '\n' && value[n] != '\r' && n < sizeof(line) - 1) {
        line[n] = value[n];
        n++;
    }
    line[n] = '\0';
    rewamp_text_to_utf8(line, dst, dstCap);
}

const char* rewamp_track_message(void) {
    return g_track_message;
}
