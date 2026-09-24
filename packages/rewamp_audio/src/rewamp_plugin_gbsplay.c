/* libgbsplay plugin — Game Boy GBS decoder with per-channel voice data.
 * Compiled only when REWAMP_WITH_GBSPLAY is defined. */
#ifdef REWAMP_WITH_GBSPLAY

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"
#include "ModizerConstants.h"

#include "libgbsplay/libgbs.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

/* seek_needed: used by gbhw.c YOYOFR patches to gate voice-buffer writes.
 * -1 = normal playback (writes enabled); other values = seeking (skip writes). */
int gbs_seek_needed = -1;

#define GBS_RATE          44100
#define GBS_STEREO        2
#define GBS_VOICE_COUNT   4
/* gbhw flushes its sound buffer in chunks of this many frames (one sound
 * callback per chunk).  Must match the integration loop in gbhw.c. */
#define GBS_BATCH_FRAMES  SOUND_BUFFER_SIZE_SAMPLE
/* gbs_step()'s time_to_work argument is in MILLISECONDS of emulated time.
 * Drive ~one batch of audio per step (512 frames @44100 ≈ 11.6 ms); a single
 * step may flush 1-2 callbacks, all captured into the FIFO below. */
#define GBS_STEP_MS       12
/* PCM FIFO capacity (frames).  Holds callback output until read() drains it. */
#define GBS_FIFO_FRAMES   (GBS_BATCH_FRAMES * 8)
/* Oscilloscope ring size (samples).  MUST match GBS_OSCILLO_SIZE in gbhw.c. */
#define GBS_OSCILLO_SIZE  4096

struct RewampDecoder {
    struct gbs              *gbs;
    struct gbs_output_buffer outbuf_desc;
    int16_t                 *pcm_buf;      /* GBS_BATCH_FRAMES * GBS_STEREO scratch */
    int16_t                 *fifo;         /* GBS_FIFO_FRAMES * GBS_STEREO */
    int                      fifo_frames;  /* frames currently queued */
    int                      voiceCount;
    int                      finished;
    int64_t                  lastMuteMask; /* applied generic_mute_mask snapshot */
};

/* `.gbr` n'est pas un `.gbs`: c'est un rip du DRIVER (magie « GBRF », ROM à
 * l'offset 0x20, adresses d'init/vsync/timer dans l'en-tête), et libgbsplay
 * l'ouvre par le même `gbs_open` — son `gbs_open_mem` aiguille sur la MAGIE.
 * Aucun autre moteur d'ici ne le lit, donc pas d'épingle à poser: l'extension
 * (60) passe déjà devant la revendication générique de vgmstream (50), et la
 * magie monte à 90/100. */
static const char* const kGbsExts[] = { "gbs", "gbr", NULL };

/* ── sound callback ──────────────────────────────────────────────────────── */
// Called by gbhw each time its buffer fills (buf->pos frames).  Append the
// frames to the FIFO so read() can drain arbitrary amounts later.

static void gbsplay_sound_cb(struct gbs *gbs,
                              struct gbs_output_buffer *buf,
                              void *priv)
{
    struct RewampDecoder *dec = (struct RewampDecoder*)priv;
    (void)gbs;
    int frames = (int)buf->pos;
    if (frames <= 0) return;
    if (dec->fifo_frames + frames > GBS_FIFO_FRAMES)
        frames = GBS_FIFO_FRAMES - dec->fifo_frames; /* drop overflow (shouldn't happen) */
    if (frames <= 0) return;
    memcpy(dec->fifo + dec->fifo_frames * GBS_STEREO,
           buf->data,
           (size_t)frames * GBS_STEREO * sizeof(int16_t));
    dec->fifo_frames += frames;
}

/* ── probe ───────────────────────────────────────────────────────────────── */

static int gbsplay_probe(const char *ext, const uint8_t *hdr, size_t hdrSize)
{
    int extMatch = rewamp_ext_in_list(ext, kGbsExts);
    if (hdr && hdrSize >= 4 && memcmp(hdr, "GBRF", 4) == 0)
        return extMatch ? 100 : 90;
    if (hdr && hdrSize >= 3 &&
        hdr[0] == 'G' && hdr[1] == 'B' && hdr[2] == 'S')
        return extMatch ? 100 : 90;
    return extMatch ? 60 : 0;
}

/* Un GBR ne porte NI table de morceaux NI étiquettes, et libgbsplay le dit à
 * sa façon: `songs` est un `uint8_t` épinglé à 255 — la valeur maximale, faute
 * de savoir — et titre/auteur/copyright tombent sur un « gbr / not available »
 * de remplissage. Publier ça dans le panneau ⓘ, c'est afficher une information
 * FAUSSE là où il n'y en a pas. D'où la détection ici, sur la magie: le
 * `filetype` que la bibliothèque connaît n'est pas exposé par son API. */
static int gbsplay_is_gbr(const char *path)
{
    FILE *f = fopen(path, "rb");
    if (!f) return 0;
    char magic[4] = {0};
    size_t n = fread(magic, 1, sizeof(magic), f);
    fclose(f);
    return n == sizeof(magic) && memcmp(magic, "GBRF", 4) == 0;
}

/* ── open ────────────────────────────────────────────────────────────────── */

static RewampDecoder* gbsplay_open(const char *path,
                                    RewampAudioFormat *outFormat)
{
    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    int subsong = 0;
    char *q = strrchr(cleanPath, '?');
    if (q) {
        if (strncmp(q + 1, "subsong=", 8) == 0)
            subsong = atoi(q + 9);
        *q = '\0';
    }

    struct gbs *gbs = gbs_open(cleanPath);
    if (!gbs) return NULL;

    struct RewampDecoder *dec =
        (struct RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { gbs_close(gbs); return NULL; }

    dec->gbs = gbs;

    /* Allocate int16 PCM batch (gbhw render target) + drain FIFO */
    dec->pcm_buf = (int16_t*)calloc(GBS_BATCH_FRAMES * GBS_STEREO, sizeof(int16_t));
    dec->fifo    = (int16_t*)calloc(GBS_FIFO_FRAMES * GBS_STEREO, sizeof(int16_t));
    if (!dec->pcm_buf || !dec->fifo) {
        gbs_close(gbs);
        if (dec->pcm_buf) free(dec->pcm_buf);
        if (dec->fifo)    free(dec->fifo);
        free(dec);
        return NULL;
    }

    /* Configure output: batch size in bytes = frames * stereo * sizeof(int16) */
    dec->outbuf_desc.data  = dec->pcm_buf;
    dec->outbuf_desc.bytes = GBS_BATCH_FRAMES * GBS_STEREO * (int)sizeof(int16_t);
    dec->outbuf_desc.pos   = 0;
    gbs_configure_output(gbs, &dec->outbuf_desc, GBS_RATE);
    gbs_set_sound_callback(gbs, gbsplay_sound_cb, dec);

    /* Voice / oscilloscope setup (4 GB channels: sq1, sq2, wave, noise).
     * GBS_OSCILLO_SIZE must match the value hard-coded in gbhw.c. */
    dec->voiceCount = GBS_VOICE_COUNT;
    rewamp_channel_data_reset(GBS_VOICE_COUNT);
    rewamp_channel_data_set_ring_write_size(GBS_OSCILLO_SIZE);
    rewamp_channel_data_set_ring_circular(1);

    /* Voice metadata for the mute/grouping UI. */
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("DMG", 0, GBS_VOICE_COUNT);
    rewamp_voice_set_name(0, "Square 1");
    rewamp_voice_set_name(1, "Square 2");
    rewamp_voice_set_name(2, "Wave");
    rewamp_voice_set_name(3, "Noise");

    /* accumul_temp[0] is allocated by reset(); allocate 1..3 manually. */
    for (int ch = 1; ch < GBS_VOICE_COUNT; ch++) {
        m_voice_buff_accumul_temp[ch] =
            (signed int*)calloc(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2, sizeof(signed int));
    }

    /* init the subsong first (populates subsong_len), then configure with no
     * timeout (0) so playback loops; rewamp enforces the known duration. */
    gbs_init(gbs, subsong);
    gbs_configure(gbs, subsong, 0, 0, 0, 0);

    /* Info panel: GBS header metadata — voir gbsplay_is_gbr pour le silence
     * sur un GBR. */
    if (!gbsplay_is_gbr(cleanPath)) {
        const struct gbs_metadata *md = gbs_get_metadata(gbs);
        const struct gbs_status   *st = gbs_get_status(gbs);
        if (md) {
            if (md->title && md->title[0])
                rewamp_track_message_append("Title: %s\n", md->title);
            if (md->author && md->author[0])
                rewamp_track_message_append("Author: %s\n", md->author);
            if (md->copyright && md->copyright[0])
                rewamp_track_message_append("Copyright: %s\n", md->copyright);
        }
        if (st && st->songs > 1)
            rewamp_track_message_append("Subsongs: %d (default %d)\n",
                                        st->songs, st->defaultsong);
    }

    if (outFormat) {
        outFormat->channels   = GBS_STEREO;
        outFormat->sampleRate = GBS_RATE;
    }
    return dec;
}

/* ── sonde de sous-chansons GBR ──────────────────────────────────────────── */
/*
 * Un GBR n'a pas de table de morceaux: `gbs_status.songs` vaut 255, qui est la
 * valeur maximale d'un `uint8_t` et veut dire « je ne sais pas ». Les lister
 * telles quelles donnerait 255 entrées dont presque toutes sont muettes. On
 * demande donc au PILOTE, exactement comme la sonde `.adl` d'AdPlug demande au
 * sien: on joue chaque morceau quelques dixièmes de seconde et on garde ceux
 * qui DÉCLENCHENT une voie.
 *
 * ⚠️ On n'écoute pas le son, on écoute les ÉCRITURES D'E/S (`gbs_set_io_callback`,
 * l'équivalent Game Boy de l'OPL espion d'AdPlug): un déclenchement, c'est le
 * bit 7 de NRx4 posé alors que le DAC de la voie est allumé et l'APU sous
 * tension. Pas de synthèse à analyser, pas de seuil de silence à choisir.
 *
 * ⚠️ Cette sonde tourne sur le fil de l'UI PENDANT qu'un autre morceau joue, et
 * les tampons `m_voice_*` appartiennent au morceau qu'on entend ⇒
 * `gbs_set_voice_capture(gbs, 0)` sur NOTRE instance. Sans ça la sonde écrit
 * dans les oscilloscopes d'un autre — et si ce moteur-là n'a pas alloué les
 * tampons d'accumulation, elle déréférence NULL.
 *
 * ⚠️ « déclenche une voie » ne veut pas dire « musique »: un pilote peut
 * répondre à un numéro inconnu par un bruitage. On n'écarte que ce qui est
 * PROUVÉ muet — même règle que `.adl`.
 */
/* Deux bornes, et c'est le couple qui rend la sonde rapide SANS la rendre
 * hâtive. La fenêtre est GÉNÉREUSE — un pilote peut poser son tempo à l'init
 * et ne lancer sa première note qu'après quelques trames — mais on l'abandonne
 * dès que le pilote ne TOUCHE plus l'APU: un numéro inconnu, c'est un `RET`
 * immédiat, et rien ne viendra. Mesuré sur 255 candidats dont 3 vivants:
 * 648 ms en attendant bêtement la fenêtre entière, 130 ms avec l'abandon. */
#define GBR_PROBE_MAX      255
#define GBR_PROBE_MS       320   /* fenêtre par morceau, en temps émulé */
#define GBR_PROBE_STEP_MS  16    /* ~une trame */
#define GBR_PROBE_IDLE     4     /* trames SANS écriture APU = morceau mort */

static int s_gbr_probe_count = 0;
static int s_gbr_probe_index[GBR_PROBE_MAX];

struct gbr_probe {
    int apu_on;
    int dac[4];   /* la voie peut-elle produire quoi que ce soit ? */
    int keyed;    /* un déclenchement a eu lieu, DAC allumé */
    int wrote;    /* le pilote a touché l'APU pendant cette trame */
    /* La voie 3 tient son DAC dans DEUX registres (NR30 alimentation, NR32
     * niveau de sortie): il faut les garder tous les deux pour trancher. */
    uint8_t nr30, nr32;
};

static void gbr_probe_seed(struct gbr_probe *st, struct gbs *gbs)
{
    /* L'état de départ vient des registres eux-mêmes: `gbhw_init` écrit les
     * valeurs de démarrage de la Game Boy avec le callback d'E/S DÉBRANCHÉ
     * (pour cacher ses propres pokes), donc on ne les verrait pas passer. */
    st->keyed  = 0;
    st->apu_on = (gbs_io_peek(gbs, 0xff26) & 0x80) != 0;
    st->nr30   = gbs_io_peek(gbs, 0xff1a);
    st->nr32   = gbs_io_peek(gbs, 0xff1c);
    st->dac[0] = (gbs_io_peek(gbs, 0xff12) & 0xf8) != 0;
    st->dac[1] = (gbs_io_peek(gbs, 0xff17) & 0xf8) != 0;
    st->dac[2] = (st->nr30 & 0x80) != 0 && (st->nr32 & 0x60) != 0;
    st->dac[3] = (gbs_io_peek(gbs, 0xff21) & 0xf8) != 0;
}

static void gbr_probe_io(struct gbs *gbs, cycles_t cycles,
                         uint32_t addr, uint8_t val, void *priv)
{
    struct gbr_probe *st = (struct gbr_probe*)priv;
    (void)gbs; (void)cycles;

    /* « Le pilote travaille-t-il ? » se mesure AVANT de savoir si le matériel
     * tiendra compte de l'écriture: une écriture ignorée reste un signe de
     * vie, et c'est ce signe-là qui décide d'attendre ou d'abandonner. */
    if (addr >= 0xff10 && addr <= 0xff26) st->wrote = 1;

    /* Le matériel IGNORE les registres sonores quand l'APU est coupé, et
     * `io_put` aussi — mais APRÈS nous avoir appelés (gbhw.c). Même borne. */
    if (!st->apu_on && addr >= 0xff10 && addr < 0xff26) return;

    switch (addr) {
    case 0xff26: st->apu_on = (val & 0x80) != 0; break;      /* NR52 */
    case 0xff12: st->dac[0] = (val & 0xf8) != 0; break;      /* NR12 */
    case 0xff17: st->dac[1] = (val & 0xf8) != 0; break;      /* NR22 */
    case 0xff1a: st->nr30 = val;
                 st->dac[2] = (val & 0x80) != 0 && (st->nr32 & 0x60) != 0; break;
    case 0xff1c: st->nr32 = val;
                 st->dac[2] = (st->nr30 & 0x80) != 0 && (val & 0x60) != 0; break;
    case 0xff21: st->dac[3] = (val & 0xf8) != 0; break;      /* NR42 */
    /* NRx4: bit 7 = déclenchement. */
    case 0xff14: if ((val & 0x80) && st->dac[0]) st->keyed = 1; break;
    case 0xff19: if ((val & 0x80) && st->dac[1]) st->keyed = 1; break;
    case 0xff1e: if ((val & 0x80) && st->dac[2]) st->keyed = 1; break;
    case 0xff23: if ((val & 0x80) && st->dac[3]) st->keyed = 1; break;
    default: break;
    }
}

int rewamp_gbsplay_probe_subsong_count(const char *path)
{
    s_gbr_probe_count = 0;
    if (!path) return 0;

    char clean[4096];
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char *q = strrchr(clean, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) *q = '\0';

    /* GBR seulement: un `.gbs` porte un VRAI compte dans son en-tête, et c'est
     * libgme qui le lit. */
    if (!gbsplay_is_gbr(clean)) return 0;

    struct gbs *gbs = gbs_open(clean);
    if (!gbs) return 0;

    /* La sortie ne sert à rien ici, mais `gb_sound` exige un tampon; le lot
     * reste celui du greffon — les tampons d'accumulation sont dimensionnés
     * pour lui. */
    int16_t  pcm[GBS_BATCH_FRAMES * GBS_STEREO];
    struct gbs_output_buffer out = { pcm, (long)sizeof(pcm), 0 };
    gbs_configure_output(gbs, &out, GBS_RATE);
    gbs_set_voice_capture(gbs, 0);   /* ⚠️ voir l'en-tête de bloc */

    struct gbr_probe st;
    gbs_set_io_callback(gbs, gbr_probe_io, &st);

    const struct gbs_status *status = gbs_get_status(gbs);
    int songs = status ? (int)status->songs : 0;
    if (songs > GBR_PROBE_MAX) songs = GBR_PROBE_MAX;

    int live = 0;
    for (int n = 0; n < songs; n++) {
        gbs_init(gbs, n);
        gbr_probe_seed(&st, gbs);
        int idle = 0;
        for (int ms = 0; ms < GBR_PROBE_MS && !st.keyed; ms += GBR_PROBE_STEP_MS) {
            st.wrote = 0;
            if (!gbs_step(gbs, GBR_PROBE_STEP_MS)) break;
            if (st.wrote) idle = 0;
            else if (++idle >= GBR_PROBE_IDLE) break;   /* plus personne */
        }
        if (st.keyed) s_gbr_probe_index[live++] = n;
    }

    gbs_close(gbs);
    s_gbr_probe_count = live;
    return live;
}

/* Index RÉEL du i-ème morceau vivant: la liste est CREUSE, la position ne peut
 * pas en tenir lieu (même contrat que la sonde `.adl`). */
int rewamp_gbsplay_probe_get_index(int idx)
{
    if (idx < 0 || idx >= s_gbr_probe_count) return idx;
    return s_gbr_probe_index[idx];
}

/* ── capture per-channel note/vol ────────────────────────────────────────── */

static void gbsplay_capture_voices(struct RewampDecoder *dec)
{
    const struct gbs_status *st = gbs_get_status(dec->gbs);
    if (!st) return;
    for (int ch = 0; ch < GBS_VOICE_COUNT; ch++) {
        long vol   = st->ch[ch].vol;
        long div_t = st->ch[ch].div_tc;
        int  on    = (int)st->ch[ch].playing;

        /* Frequency estimation from div_tc.
         * ch0,1 (square): f = 131072 / div_tc
         * ch2  (wave):    f = 65536  / div_tc
         * ch3  (noise):   approximate */
        unsigned int freq_hz = 0;
        if (div_t > 0) {
            if (ch == 0 || ch == 1)
                freq_hz = (unsigned int)(131072.0 / div_t);
            else if (ch == 2)
                freq_hz = (unsigned int)(65536.0 / div_t);
        }
        vgm_last_note[ch] = freq_hz;
        vgm_last_vol[ch]  = (on && vol > 0) ? (unsigned int)(vol * 255 / 15) : 0;
    }
}

/* ── read ────────────────────────────────────────────────────────────────── */

static uint64_t gbsplay_read(RewampDecoder *dec, float *out,
                              uint64_t frameCount)
{
    if (!dec || !dec->gbs || dec->finished || frameCount == 0) return 0;

    /* Apply voice-mute changes from the UI (Modizer: gbs_toggle_setmute). */
    if (dec->lastMuteMask != generic_mute_mask) {
        dec->lastMuteMask = generic_mute_mask;
        for (int ch = 0; ch < GBS_VOICE_COUNT; ch++)
            gbs_toggle_setmute(dec->gbs, ch,
                               (generic_mute_mask >> ch) & 1 ? 1 : 0);
    }

    uint64_t written = 0;
    while (written < frameCount) {
        /* Pump the emulator until the FIFO has data (or we hit EOF). */
        if (dec->fifo_frames == 0) {
            if (!gbs_step(dec->gbs, GBS_STEP_MS)) { dec->finished = 1; break; }
            if (dec->fifo_frames == 0) continue; /* step produced no flush yet */
        }

        int take = (int)(frameCount - written);
        if (take > dec->fifo_frames) take = dec->fifo_frames;

        const int16_t *src = dec->fifo;
        float         *dst = out + written * GBS_STEREO;
        for (int i = 0; i < take * GBS_STEREO; i++)
            dst[i] = src[i] / 32768.0f;

        /* Shift remaining FIFO frames down. */
        int remain = dec->fifo_frames - take;
        if (remain > 0) {
            memmove(dec->fifo,
                    dec->fifo + take * GBS_STEREO,
                    (size_t)remain * GBS_STEREO * sizeof(int16_t));
        }
        dec->fifo_frames = remain;
        written += (uint64_t)take;
    }

    gbsplay_capture_voices(dec);
    return written;
}

/* ── seek ────────────────────────────────────────────────────────────────── */

static void gbsplay_seek(RewampDecoder *dec, uint64_t frameIndex)
{
    if (!dec || !dec->gbs) return;
    /* Re-init the current subsong and fast-forward by skipping audio */
    const struct gbs_status *st = gbs_get_status(dec->gbs);
    int subsong = st ? (int)st->subsong : 0;
    gbs_init(dec->gbs, subsong);
    dec->fifo_frames = 0;
    dec->finished    = 0;
    /* gbs_init resets the engine's per-channel mute state while the plugin's
     * change-detection cache (and the restored generic_mute_mask) kept their
     * values — re-apply the user's mutes or they are silently dropped. */
    for (int ch = 0; ch < GBS_VOICE_COUNT; ch++)
        gbs_toggle_setmute(dec->gbs, ch,
                           (generic_mute_mask >> ch) & 1 ? 1 : 0);

    /* Fast-forward by running gbs_step and discarding audio.
     * Disable voice-buffer writes during seek (gbhw.c checks seek_needed). */
    gbs_seek_needed = 0;
    uint64_t done = 0;
    while (done < frameIndex) {
        if (!gbs_step(dec->gbs, GBS_STEP_MS)) break;
        done += (uint64_t)dec->fifo_frames;
        dec->fifo_frames = 0;
    }
    gbs_seek_needed = -1;
}

/* ── length ──────────────────────────────────────────────────────────────── */

static uint64_t gbsplay_length(RewampDecoder *dec)
{
    if (!dec || !dec->gbs) return 0;
    const struct gbs_status *st = gbs_get_status(dec->gbs);
    if (!st) return 0;
    /* subsong_len is in GBS_LEN_DIV ticks (1024 ticks = 1 second) */
    if (st->subsong_len == 0) return 0;
    return (uint64_t)((double)st->subsong_len / 1024.0 * GBS_RATE);
}

/* ── close ───────────────────────────────────────────────────────────────── */

static void gbsplay_close(RewampDecoder *dec)
{
    if (!dec) return;
    if (dec->gbs)     gbs_close(dec->gbs);
    if (dec->pcm_buf) free(dec->pcm_buf);
    if (dec->fifo)    free(dec->fifo);
    free(dec);
}

/* ── vtable ──────────────────────────────────────────────────────────────── */

/* Live settings change (called under the decode lock). */
static void gbsplay_param_changed(struct RewampDecoder* dec, const char* key) {
    (void)key;
    if (dec && dec->gbs)
        gbs_set_filter(dec->gbs, (enum gbs_filter_type)
            (int)rewamp_get_engine_param("gbsplay", "hp_filter", 1));
}

static const RewampPluginVTable kGbsplayVTable = {
    "gbsplay",
    gbsplay_probe,
    gbsplay_open,
    gbsplay_read,
    gbsplay_seek,
    gbsplay_length,
    gbsplay_close,
    NULL,                   /* configure_loop */
    0,                      /* supportsNativeFadeout */
    "gbsplay",              /* engine_id */
    gbsplay_param_changed,  /* live settings */
};

const RewampPluginVTable* rewamp_gbsplay_plugin(void) {
    return &kGbsplayVTable;
}

#endif /* REWAMP_WITH_GBSPLAY */
