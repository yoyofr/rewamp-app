/* ASAP plugin — Atari 8-bit POKEY formats (SAP, CMC, RMT, TMC, MPT, …).
 * Backed by the vendored generated ASAP C (third_party/asap: upstream release
 * + rewamp patches for per-channel voice capture, see patches/asap/).
 * Mirrors Modizer's MMP_ASAP: ASAP_Load / ASAP_PlaySong / ASAP_Generate /
 * ASAP_MutePokeyChannels; the patched core mirrors each POKEY channel into
 * m_voice_buff at (write ptr + sample idx) — this plugin advances the write
 * pointers after every generate call. */
#ifdef REWAMP_WITH_ASAP

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

#include "asap.h"

#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ASAP_RING_SIZE (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)

/* Défini par le patch rewamp 0002 d'asap.c (patches/asap/): pas dans asap.h,
 * que sync_asap.sh recopie tel quel depuis l'amont. */
void ASAP_RewampSetSpeed(ASAP *self, double speed, int songDurationMs, int songPosMs);
void ASAP_RewampPlayForever(ASAP *self);   /* patch 0003 */

/* Boucle forcée (rewamp_audio.c), lue dans open(). */
extern int g_force_loop_mode;
extern int g_force_loop_count;
extern int g_force_loop_native_veto;
extern int g_loop_lift_refused;

struct RewampDecoder {
    ASAP*    asap;
    int      voices;        /* 4 (mono POKEY) or 8 (stereo/dual POKEY) */
    int      outChannels;   /* 1 or 2 */
    int      song;
    int      durationMs;    /* per-song duration from the file, -1 = unknown */
    int      loops;         /* the tune loops by itself (SAP « TIME … LOOP ») */
    int      endMs;         /* where ASAP stops, song time; -1 = never */
    int      infinite;      /* infinite loop armed (configure_loop 2) */
    int64_t  lastMuteMask;  /* applied generic_mute_mask snapshot */
    int16_t* pcm;           /* int16 scratch */
    int      pcmFrames;
    double   speed;         /* vitesse native (0 = 1×) */
    double   songMs;        /* position dans le MORCEAU (fin, seek) */
};

/* Extensions ASAP owns (Modizer's SUPPORTED_FILETYPE_ASAP). NB: '.mpt' here is
 * Atari Music ProTracker, unrelated to OpenMPT (whose native ext is .mptm). */
static const char* const kAsapExts[] = {
    "sap", "cmc", "cm3", "cmr", "cms", "dmc", "dlt",
    "mpt", "mpd", "rmt", "tmc", "tm8", "tm2", NULL
};

static int asap_probe(const char* ext, const uint8_t* header, size_t headerSize) {
    /* SAP header magic is decisive; must beat libgme's generic SAP claim. */
    if (header && headerSize >= 3 &&
        header[0] == 'S' && header[1] == 'A' && header[2] == 'P') {
        return (ext && strcmp(ext, "sap") == 0) ? 110 : 90;
    }
    if (!ext) return 0;
    return rewamp_ext_in_list(ext, kAsapExts) ? 65 : 0;
}

/* ── Sonde de sous-chansons ────────────────────────────────────────────────
 *
 * `.sap` (et toute la famille ASAP) n'avait AUCUNE branche dans
 * rewamp_probe_subsong_count(): la chaîne finissait chez libgme, qui possède
 * bien un Sap_Emu mais REFUSE les fichiers `TYPE D` — « Digimusic not
 * supported », un `return` sec dans son parse_info(). gme_open_file échouait
 * donc, la sonde rendait 0, et l'écran des sous-chansons affichait
 * « Impossible de lire les pistes » sur un fichier qu'ASAP joue très bien.
 * Mesuré sur `asma/Games/Ghostbusters.sap` (SAP, TYPE D, SONGS 2).
 *
 * Et ça ne concerne pas que le TYPE D: libgme ne connaît AUCUN des autres
 * formats ASAP (cmc, rmt, tmc, mpt…), donc un `.rmt` à plusieurs morceaux
 * tombait dans le même trou.
 *
 * ASAPInfo suffit — il lit l'en-tête, pas le morceau: pas de moteur créé, pas
 * de POKEY émulé.
 */
#define ASAP_PROBE_MAX 256
static int s_probe_count = 0;
static int s_probe_durations_ms[ASAP_PROBE_MAX];

int rewamp_asap_probe_subsong_count(const char* path) {
    s_probe_count = 0;
    if (!path) return 0;

    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q) *q = '\0';

    const char* dot = strrchr(cleanPath, '.');
    if (!dot) return 0;
    char ext[16] = {0};
    for (int i = 0; dot[i + 1] && i < 15; i++) {
        ext[i] = (char)tolower((unsigned char)dot[i + 1]);
    }
    if (!rewamp_ext_in_list(ext, kAsapExts)) return 0;

    FILE* f = fopen(cleanPath, "rb");
    if (!f) return 0;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0 || len > 64 * 1024 * 1024) { fclose(f); return 0; }
    uint8_t* data = (uint8_t*)malloc((size_t)len);
    if (!data) { fclose(f); return 0; }
    size_t got = fread(data, 1, (size_t)len, f);
    fclose(f);
    if (got != (size_t)len) { free(data); return 0; }

    ASAPInfo* info = ASAPInfo_New();
    if (!info) { free(data); return 0; }
    int count = 0;
    if (ASAPInfo_Load(info, cleanPath, data, (int)len)) {
        count = ASAPInfo_GetSongs(info);
        if (count < 0) count = 0;
        if (count > ASAP_PROBE_MAX) count = ASAP_PROBE_MAX;
        for (int i = 0; i < count; i++) {
            /* -1 = durée inconnue, la convention de l'appelant. */
            s_probe_durations_ms[i] = ASAPInfo_GetDuration(info, i);
        }
    }
    ASAPInfo_Delete(info);
    free(data);
    s_probe_count = count;
    return count;
}

/* ASAP ne nomme pas ses sous-chansons (ASAPInfo_GetTitle nomme le FICHIER):
 * pas de fonction de titre, l'appelant laisse alors le champ vide. */
int rewamp_asap_probe_get_duration_ms(int index) {
    if (index < 0 || index >= s_probe_count) return -1;
    return s_probe_durations_ms[index];
}

static RewampDecoder* asap_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    char cleanPath[4096];
    int  subsong = 0;
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) { subsong = atoi(q + 9); *q = '\0'; }

    FILE* f = fopen(cleanPath, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0 || len > 64 * 1024 * 1024) { fclose(f); return NULL; }
    uint8_t* data = (uint8_t*)malloc((size_t)len);
    if (!data) { fclose(f); return NULL; }
    size_t got = fread(data, 1, (size_t)len, f);
    fclose(f);
    if (got != (size_t)len) { free(data); return NULL; }

    ASAP* asap = ASAP_New();
    if (!asap) { free(data); return NULL; }
    if (!ASAP_Load(asap, cleanPath, data, (int)len)) {
        ASAP_Delete(asap);
        free(data);
        return NULL;
    }
    free(data);   /* ASAP copies what it needs */

    const ASAPInfo* info = ASAP_GetInfo(asap);
    const int songs   = ASAPInfo_GetSongs(info);
    int song = subsong;
    if (song < 0 || song >= songs) song = ASAPInfo_GetDefaultSong(info);
    const int durationMs = ASAPInfo_GetDuration(info, song); /* -1 = unknown */

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { ASAP_Delete(asap); return NULL; }
    dec->asap        = asap;
    dec->song        = song;
    dec->durationMs  = durationMs;
    dec->loops       = ASAPInfo_GetLoop(info, song) ? 1 : 0;

    /* NATIVE loop, for a tune that loops by ITSELF (« LOOP » after its TIME):
     * ASAP just goes on playing past one pass, from the composer's loop
     * point and without a seam — the generic loop could only start it over
     * from the intro. Infinite = no end at all; N repeats = N+1 passes (the
     * generic C window fades the last seconds out). A tune that really ENDS,
     * or whose length is unknown, keeps the generic loop (veto). */
    dec->endMs = durationMs;
    if (g_force_loop_mode != 0) {
        if (!dec->loops || durationMs <= 0)
            g_force_loop_native_veto = 1;
        else if (g_force_loop_mode == 2)
            dec->endMs = -1;
        else
            dec->endMs = durationMs * (g_force_loop_count + 1);
    }
    dec->outChannels = ASAPInfo_GetChannels(info);   /* 1 or 2 */
    dec->voices      = dec->outChannels == 2 ? 8 : 4;

    /* Voice ring buffers BEFORE PlaySong (the patched core writes on the
     * first generated sample) + the *4*2 write mask used by the patch. */
    rewamp_channel_data_reset(dec->voices);
    rewamp_channel_data_set_ring_write_size(ASAP_RING_SIZE);
    /* accumul_temp[0] is allocated by reset(); the patch needs one per voice. */
    for (int ch = 1; ch < dec->voices; ch++) {
        if (!m_voice_buff_accumul_temp[ch]) {
            m_voice_buff_accumul_temp[ch] =
                (signed int*)calloc(ASAP_RING_SIZE, sizeof(signed int));
        }
    }

    /* Chip grouping + voice names (after reset — it wipes the tables). */
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip(dec->voices > 4 ? "POKEY 1" : "POKEY", 0, 4);
    if (dec->voices > 4) rewamp_voices_add_chip("POKEY 2", 4, 4);
    for (int v = 0; v < dec->voices; v++) {
        char nm[12];
        snprintf(nm, sizeof(nm), "Ch %d", (v % 4) + 1);
        rewamp_voice_set_name(v, nm);
    }

    /* Info panel. */
    {
        const char* s;
        s = ASAPInfo_GetTitle(info);
        if (s && s[0]) rewamp_track_message_append("Title: %s\n", s);
        s = ASAPInfo_GetAuthor(info);
        if (s && s[0]) rewamp_track_message_append("Author: %s\n", s);
        s = ASAPInfo_GetDate(info);
        if (s && s[0]) rewamp_track_message_append("Date: %s\n", s);
        rewamp_track_message_append("POKEY chips: %d\nSongs: %d\n",
                                    dec->outChannels, songs);
    }

    if (!ASAP_PlaySong(asap, song, dec->endMs)) {
        ASAP_Delete(asap);
        free(dec);
        return NULL;
    }

    if (outFormat) {
        outFormat->channels   = (uint32_t)dec->outChannels;
        outFormat->sampleRate = ASAP_SAMPLE_RATE;
    }
    return dec;
}

static uint64_t asap_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->asap || frameCount == 0) return 0;

    /* Apply voice-mute changes (bit v ⇒ muted; ASAP mask bit = mute). */
    if (dec->lastMuteMask != generic_mute_mask) {
        dec->lastMuteMask = generic_mute_mask;
        ASAP_MutePokeyChannels(dec->asap, (int)(generic_mute_mask & 0xFF));
    }

    if (dec->pcmFrames < (int)frameCount) {
        free(dec->pcm);
        dec->pcm = (int16_t*)malloc((size_t)frameCount * dec->outChannels *
                                    sizeof(int16_t));
        dec->pcmFrames = (int)frameCount;
    }
    if (!dec->pcm) return 0;

    const int wantBytes =
        (int)frameCount * dec->outChannels * (int)sizeof(int16_t);
    const int gotBytes = ASAP_Generate(dec->asap, (uint8_t*)dec->pcm,
                                       wantBytes, ASAPSampleFormat_S16_L_E);
    const int frames = gotBytes / (dec->outChannels * (int)sizeof(int16_t));
    if (frames <= 0) return 0;
    dec->songMs += frames * 1000.0 / ASAP_SAMPLE_RATE * (dec->speed > 0.0 ? dec->speed : 1.0);

    const float scale = 1.0f / 32768.0f;
    for (int i = 0; i < frames * dec->outChannels; i++)
        out[i] = dec->pcm[i] * scale;

    /* Advance the voice-scope write pointers by the frames just generated —
     * the patched Pokey_StoreSample wrote at (ptr + sample idx). */
    for (int v = 0; v < dec->voices; v++) {
        m_voice_current_ptr[v] +=
            (int64_t)frames << MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
    }

    return (uint64_t)frames;
}

static void asap_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->asap) return;
    const double sp = dec->speed > 0.0 ? dec->speed : 1.0;
    const double songMs = (double)frameIndex * 1000.0 / ASAP_SAMPLE_RATE;
    /* ASAP_Seek compte en SORTIE depuis le début (rejoue à la vitesse en
     * vigueur): cible du MORCEAU ÷ vitesse. Un retour en arrière relance le
     * morceau, qui repose la fin à 1× ⇒ on la repose après. */
    ASAP_Seek(dec->asap, (int)(songMs / sp + 0.5));
    dec->songMs = songMs;
    if (sp != 1.0) ASAP_RewampSetSpeed(dec->asap, sp, dec->endMs, (int)songMs);
}

/* Vitesse NATIVE (patch REWAMP d'asap.c): la routine de jeu est appelée tous
 * les 114 × fastplay ÷ vitesse cycles, la POKEY garde son horloge — tempo
 * changé, hauteur conservée. La fin (comptée en sortie par ASAP) est reposée
 * d'après le reste du morceau. */
static int asap_set_speed(RewampDecoder* dec, double speed) {
    /* RALENTIR seulement. Le 6502 tourne à son horloge réelle et la routine
     * de jeu en consomme une bonne part par trame: à 2× il faudrait deux
     * exécutions COMPLÈTES par trame, impossible dès qu'elle pèse plus d'une
     * demi-trame (les appels sont alors différés, le tempo ne double pas).
     * Mesuré sur 16 SAP de types B/C (registres POKEY relevés en temps du
     * morceau): 0,2× et 0,5× ⇒ 90-100 %, 2× ⇒ 30-100 %, 3× ⇒ 16-100 %.
     * Au-dessus de 1×, on refuse: la source rééchantillonne (hauteur
     * comprise), ce qui vaut mieux qu'une accélération irrégulière. */
    if (dec && dec->asap && speed > 1.0) {
        if (dec->speed > 0.0 && dec->speed != 1.0) {
            dec->speed = 1.0;
            ASAP_RewampSetSpeed(dec->asap, 1.0, dec->endMs, (int)dec->songMs);
        }
        return 0;
    }
    if (!dec || !dec->asap || speed < 0.2 || speed > 3.0) return 0;
    dec->speed = speed;
    ASAP_RewampSetSpeed(dec->asap, speed, dec->endMs, (int)dec->songMs);
    return 1;
}

/* ONE pass (the nominal length, and the base of the generic fade window
 * under N repeats); 0 once the infinite loop is armed — the producer must not
 * stop at it. */
static uint64_t asap_length(RewampDecoder* dec) {
    if (!dec || dec->infinite || dec->durationMs <= 0) return 0;
    return (uint64_t)dec->durationMs * ASAP_SAMPLE_RATE / 1000ull;
}

/* The loop itself is set in open() (it decides ASAP_PlaySong's end); this
 * call matters for mode 2 only, also when repeat is armed DURING playback
 * (rewamp_lift_end_for_infinite): the end is lifted in flight, no restart.
 * Refused for a tune that does not loop by itself. */
static void asap_configure_loop(RewampDecoder* dec, int mode, int count) {
    (void)count;
    if (!dec || !dec->asap || mode != 2) return;
    if (!dec->loops) { g_loop_lift_refused = 1; return; }
    dec->infinite = 1;
    dec->endMs = -1;
    ASAP_RewampPlayForever(dec->asap);
}

static void asap_close(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->asap) ASAP_Delete(dec->asap);
    free(dec->pcm);
    free(dec);
}

static const RewampPluginVTable kAsapVTable = {
    "asap",
    asap_probe,
    asap_open,
    asap_read,
    asap_seek,
    asap_length,
    asap_close,
    asap_configure_loop,          /* boucle native (morceaux « LOOP ») */
    0, NULL, NULL,                /* supportsNativeFadeout … param_changed */
    NULL, NULL, NULL, NULL, NULL, /* pattern view */
    NULL, 0,                      /* probe_path, noPrefixProbe */
    asap_set_speed,               /* vitesse native (appel de la routine) */
};

const RewampPluginVTable* rewamp_asap_plugin(void) { return &kAsapVTable; }

/* La sonde de sous-chansons vit plus haut (ASAPInfo seul, bornée par la liste
 * d'extensions, et elle rend aussi les durées). Celle qui était ici chargeait
 * le morceau ENTIER par ASAP_Load pour n'en lire que le compte — et surtout
 * elle n'était APPELÉE DE NULLE PART: `rewamp_probe_subsong_count` passait
 * directement à libgme, qui refuse les `.sap` de TYPE D. */

#endif /* REWAMP_WITH_ASAP */
