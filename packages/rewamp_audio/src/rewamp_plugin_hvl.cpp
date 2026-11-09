/* HivelyTracker plugin — .hvl (HivelyTracker) + .ahx (AHX) via the vendored
 * hvl_replay from Modizer (third_party/hivelytracker, inline voice-capture
 * patches: cores honor generic_mute_mask and write m_voice_buff with a
 * circular 1024-sample ring). Native replayer — preferred over UADE for AHX
 * (probe 64 > uade's suffix 58), like Modizer's MMP_HVL. */
#ifdef REWAMP_WITH_HVL

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

#include "hvl_replay.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define HVL_RATE 44100

extern "C" {
extern int g_force_loop_mode;
extern int g_force_loop_native_veto;
extern int g_loop_lift_refused;
}

struct RewampDecoder {
    struct hvl_tune* ht;
    int              voices;
    /* One-frame FIFO: hvl_DecodeFrame renders rate/50 frames per call
     * (it runs the sequencer via hvl_play_irq — mixchunk alone is silent). */
    int16_t*         fifo;        /* frameSamples * 2 int16 */
    int              fifoSamples; /* capacity in frames */
    int              fifoPos;     /* consumed frames */
    int              fifoLen;     /* valid frames */
    /* Vitesse native: chaque tick du séquenceur (hvl_play_irq) mixe
     * taux/50/multiplicateur ÷ vitesse échantillons au lieu d'une trame fixe —
     * les ticks se rapprochent, les voix gardent leur hauteur. Seek et durée
     * comptent en ticks: déjà en temps du MORCEAU. */
    double           speed;
    double           acc;         /* reste fractionnaire d'échantillons */
    /* Durée d'une passe, mesurée UNE fois à l'ouverture. hvl_GetPlayTime fait
     * tourner le séquenceur jusqu'à la fin puis le remet au début: appelé par
     * length() — que rewamp_get_duration_seconds sert depuis le fil UI, sans
     * verrou, pendant que le producteur décode — il rembobinait la lecture en
     * pleine course (notes en accéléré au départ ou au bouclage). */
    uint64_t         lengthFrames;
    /* Boucle infinie NATIVE armée (configure_loop 2). Le replayer boucle déjà
     * de lui-même: en fin de liste il repart à ht_Restart (en-tête, AHX comme
     * HVL), un Bxx arrière saute en arrière — dans les deux cas il lève
     * seulement ht_SongEndReached. On ne s'arrête donc plus sur ce drapeau;
     * seul F00 (tempo 0, le séquenceur se fige) reste une vraie fin. */
    int              infinite;
    int              stops;       /* la passe finit par F00: pas de boucle */
};

/* Fin à respecter? Sous boucle infinie, le drapeau de fin de passe est
 * consommé et la lecture continue, sauf tempo 0. */
static int hvl_end_reached(RewampDecoder* dec) {
    struct hvl_tune* ht = dec->ht;
    if (!ht->ht_SongEndReached) return 0;
    if (!dec->infinite || ht->ht_Tempo == 0) return 1;
    ht->ht_SongEndReached = 0;
    return 0;
}

/* Ticks (appels de hvl_play_irq) jusqu'à la fin, BORNÉS: un morceau qui ne
 * lève jamais ht_SongEndReached ne doit pas figer l'ouverture. Remet le
 * morceau au début, comme hvl_GetPlayTime. */
static uint64_t hvl_count_ticks(struct hvl_tune* ht, int* stops) {
    const int mult = ht->ht_SpeedMultiplier > 0 ? ht->ht_SpeedMultiplier : 1;
    const uint64_t cap = (uint64_t)60 * 60 * 50 * mult;   /* une heure */
    uint64_t n = 0;
    while (!ht->ht_SongEndReached && n < cap) { hvl_play_irq(ht); n++; }
    const int ended = ht->ht_SongEndReached;
    *stops = ended && ht->ht_Tempo == 0;
    hvl_InitSubsong(ht, ht->ht_SongNum);
    return ended ? n : 0;
}

static const char* const kHvlExts[] = { "hvl", "ahx", "thx", NULL };

static int hvl_probe(const char* ext, const uint8_t* h, size_t n) {
    /* Magic: "HVL" (Hively) / "THX" (AHX). */
    int magic = 0;
    if (h && n >= 3) {
        if (h[0] == 'H' && h[1] == 'V' && h[2] == 'L') magic = 1;
        if (h[0] == 'T' && h[1] == 'H' && h[2] == 'X') magic = 1;
    }
    const int extMatch = ext && rewamp_ext_in_list(ext, kHvlExts);
    if (magic) return extMatch ? 100 : 64;   /* 64 beats uade's suffix 58 */
    if (extMatch) return 64;
    return 0;
}

static RewampDecoder* hvl_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    char cleanPath[4096];
    int  subsong = 0;
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) { subsong = atoi(q + 9); *q = '\0'; }

    hvl_InitReplayer();   /* idempotent table setup */
    struct hvl_tune* ht = hvl_LoadTune((TEXT*)cleanPath, HVL_RATE, 1);
    if (!ht) return NULL;

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { hvl_FreeTune(ht); return NULL; }
    dec->ht     = ht;
    dec->voices = ht->ht_Channels;
    if (dec->voices < 1) dec->voices = 4;
    if (dec->voices > HVL_MAX_CHANNELS) dec->voices = HVL_MAX_CHANNELS;

    /* Ring buffers BEFORE InitSubsong/mix (cores write m_voice_buff inline,
     * circular ring masked SOUND_BUFFER_SIZE_SAMPLE*4*2-1 = 4096 samples).
     * MUST be >= ~2212 (rewamp_channel_buf_triggered's outLen+TRIGGER_SEARCH_LEN)
     * or the scope's stabilization search silently never runs — see PLUGINS.md
     * §2.3 (was SOUND_BUFFER_SIZE_SAMPLE*2=1024, undersized, fixed 2026-07-07). */
    m_genNumVoicesChannels = dec->voices;
    rewamp_channel_data_reset(dec->voices);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);
    rewamp_channel_data_set_ring_circular(1);

    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("Paula", 0, dec->voices);

    /* Info panel. */
    if (ht->ht_Name[0])
        rewamp_track_message_append("Title: %s\n", ht->ht_Name);
    rewamp_track_message_append("Channels: %d\nSubsongs: %d\n",
                                (int)ht->ht_Channels,
                                (int)ht->ht_SubsongNr + 1);

    if (!hvl_InitSubsong(ht, (uint32)(subsong > 0 ? subsong : 0))) {
        hvl_FreeTune(ht);
        free(dec);
        return NULL;
    }

    {
        const int mult = ht->ht_SpeedMultiplier > 0 ? ht->ht_SpeedMultiplier : 1;
        const uint64_t ticks = hvl_count_ticks(ht, &dec->stops);
        dec->lengthFrames = ticks * HVL_RATE / (50ull * (uint64_t)mult);
    }
    /* N passes: la reprise n'est pas le début (ht_Restart, Bxx), donc la
     * fenêtre de fondu générique (passe × (N+1)) tomberait faux — le
     * générique compte. */
    if (g_force_loop_mode == 1 || (g_force_loop_mode == 2 && dec->stops))
        g_force_loop_native_veto = 1;

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = HVL_RATE;
    }
    return dec;
}

static uint64_t hvl_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->ht || frameCount == 0) return 0;

    if (!dec->fifo) {
        /* Un tick à la vitesse la plus lente (0,2×) tient dans le tampon. */
        dec->fifoSamples = (int)(dec->ht->ht_Frequency / 50 / 0.2) + 4;
        if (dec->fifoSamples <= 0) return 0;
        dec->fifo = (int16_t*)malloc((size_t)dec->fifoSamples * 2 *
                                     sizeof(int16_t));
        if (!dec->fifo) return 0;
    }

    const float scale = 1.0f / 32768.0f;
    uint64_t written = 0;
    while (written < frameCount) {
        if (dec->fifoPos >= dec->fifoLen) {
            if (hvl_end_reached(dec)) break;
            /* Un tick: hvl_play_irq (séquenceur) puis le mix de sa durée —
             * ce que fait hvl_DecodeFrame, tick par tick, avec une durée qui
             * suit la vitesse. int16 L/R par deux pointeurs, pas de 4. */
            const double sp = dec->speed > 0.0 ? dec->speed : 1.0;
            const int mult = dec->ht->ht_SpeedMultiplier > 0 ? dec->ht->ht_SpeedMultiplier : 1;
            dec->acc += (double)dec->ht->ht_Frequency / 50.0 / mult / sp;
            int n = (int)dec->acc;
            if (n > dec->fifoSamples) n = dec->fifoSamples;
            dec->acc -= n;
            hvl_play_irq(dec->ht);
            if (n > 0)
                hvl_mixchunk(dec->ht, (uint32)n, (int8*)dec->fifo,
                             (int8*)dec->fifo + 2, 4);
            dec->fifoPos = 0;
            dec->fifoLen = n;
            if (n == 0) continue;
        }
        const int take0 = (int)(frameCount - written);
        const int avail = dec->fifoLen - dec->fifoPos;
        const int take  = take0 < avail ? take0 : avail;
        const int16_t* src = dec->fifo + (size_t)dec->fifoPos * 2;
        float* dst = out + written * 2;
        for (int i = 0; i < take * 2; i++) dst[i] = src[i] * scale;
        dec->fifoPos += take;
        written += (uint64_t)take;
    }
    return written;
}

static void hvl_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->ht) return;
    /* hvl_Seek arrondit à la SECONDE (seek_time/1000 en entier): tick exact
     * ici. Seek au-delà de la fin: le morceau s'arrête là, comme hvl_Seek. */
    struct hvl_tune* ht = dec->ht;
    const int mult = ht->ht_SpeedMultiplier > 0 ? ht->ht_SpeedMultiplier : 1;
    uint64_t ticks = frameIndex * 50ull * (uint64_t)mult / HVL_RATE;
    hvl_InitSubsong(ht, ht->ht_SongNum);
    while (ticks-- && !hvl_end_reached(dec)) hvl_play_irq(ht);
    dec->fifoPos = dec->fifoLen = 0;   /* drop stale mixed audio */
    dec->acc = 0.0;
}

static uint64_t hvl_length(RewampDecoder* dec) {
    if (!dec || dec->infinite) return 0;   /* plus de fin pour le producteur */
    return dec->lengthFrames;
}

static void hvl_close(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->ht) hvl_FreeTune(dec->ht);
    free(dec->fifo);
    free(dec);
}

/* Mode 2 seulement, à l'ouverture comme EN COURS de lecture
 * (rewamp_lift_end_for_infinite): rien à relancer, read() cesse seulement de
 * s'arrêter au drapeau de fin. Le mode 1 a posé son veto dans open(). */
static void hvl_configure_loop(RewampDecoder* dec, int mode, int count) {
    (void)count;
    if (!dec || !dec->ht || mode != 2) return;
    if (dec->stops) { g_loop_lift_refused = 1; return; }
    dec->infinite = 1;
}

/* Vitesse NATIVE (voir RewampDecoder.speed). */
static int hvl_set_speed(RewampDecoder* dec, double speed) {
    if (!dec || !dec->ht || speed < 0.2 || speed > 3.0) return 0;
    dec->speed = speed;
    return 1;
}

static const RewampPluginVTable kHvlVTable = {
    "hivelytracker",
    hvl_probe,
    hvl_open,
    hvl_read,
    hvl_seek,
    hvl_length,
    hvl_close,
    hvl_configure_loop, 0, nullptr, nullptr,     /* boucle infinie native … param_changed */
    nullptr, nullptr, nullptr, nullptr, nullptr, /* pattern view */
    nullptr, 0,                                  /* probe_path, noPrefixProbe */
    hvl_set_speed,                               /* vitesse native */
};

extern "C" const RewampPluginVTable* rewamp_hvl_plugin(void) { return &kHvlVTable; }

/* Subsong count probe (AHX/HVL list subsongs in the header). */
extern "C" int rewamp_hvl_probe_subsong_count(const char* path) {
    if (!path) return 0;
    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q) *q = '\0';
    hvl_InitReplayer();
    struct hvl_tune* ht = hvl_LoadTune((TEXT*)cleanPath, HVL_RATE, 1);
    if (!ht) return 0;
    const int n = ht->ht_SubsongNr + 1;
    hvl_FreeTune(ht);
    return n;
}

#endif /* REWAMP_WITH_HVL */
