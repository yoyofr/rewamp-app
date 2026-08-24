/* V2M plugin — Farbrausch V2 synthesizer modules (.v2m / .v2mz gzip).
 *
 * Moteur: v2redux (spheenik, CC0), portage C++17 propre du V2 d'origine, en
 * remplacement du v2mplayer de Modizer. Ce qu'il change pour nous:
 *
 *   - VERSION-NATIVE. Un .v2m existe en formats 0 à 6, et le synthé a vraiment
 *     changé de comportement au fil des ans (oscillateurs, schéma FM,
 *     polyphonie, générateur de bruit). v2mplayer convertissait tout vers la
 *     dernière version (ConvertV2M) — une étape avec pertes. v2redux joue
 *     chaque fichier avec le moteur de SON époque, et se dit vérifié
 *     échantillon par échantillon contre les binaires de démo d'origine.
 *   - Longueur EXACTE sans rendre l'audio (lengthMs), là où l'ancien lecteur
 *     déduisait « dernier événement de la timeline + 2 s ».
 *   - Mute, polyphonie et niveaux par canal offerts par l'API, explicitement
 *     hors du contrat de déterminisme.
 *
 * Nos deux accroches d'affichage vivent dans `third_party/v2redux/src/v2core.cpp`
 * (marquées YOYOFR, patch dans `patches/v2redux/`): l'oscilloscope par voix et
 * la hauteur de note. Elles lisent le bus de canal et n'y reviennent jamais.
 */
#ifdef REWAMP_WITH_V2M

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

#include "v2redux.h"

#include <zlib.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <strings.h>

#define V2M_RATE   44100
#define V2M_VOICES 16
/* Queue de réverbération après la dernière note: lengthMs() rend le point de
 * boucle, pas la traîne. v2dump mesure ~4 s sur les morceaux du corpus. */
#define V2M_TAIL_MS 4000

struct RewampDecoder {
    v2redux::Player* player;
    uint64_t totalFrames;
    uint64_t pos;
    int64_t  lastMuteMask;
};

static const char* const kV2mExts[] = { "v2m", "v2mz", NULL };

static int v2m_probe(const char* ext, const uint8_t* h, size_t n) {
    (void)h; (void)n;
    return (ext && rewamp_ext_in_list(ext, kV2mExts)) ? 80 : 0;
}

/* Lit le fichier, en dégzippant si c'est un .v2mz. */
static uint8_t* v2m_read_file(const char* path, unsigned int* outSize) {
    const char* dot = strrchr(path, '.');
    const int gz = dot && (strcasecmp(dot, ".v2mz") == 0);
    if (gz) {
        FILE* f = fopen(path, "rb");
        if (!f) return NULL;
        fseek(f, -4, SEEK_END);
        uint32_t rawSize = 0;
        if (fread(&rawSize, 1, 4, f) != 4) { fclose(f); return NULL; }
        fclose(f);
        if (rawSize == 0 || rawSize > 64u * 1024 * 1024) return NULL;
        uint8_t* data = (uint8_t*)malloc(rawSize);
        if (!data) return NULL;
        gzFile g = gzopen(path, "rb");
        if (!g) { free(data); return NULL; }
        const int got = gzread(g, data, rawSize);
        gzclose(g);
        if (got <= 0) { free(data); return NULL; }
        *outSize = (unsigned int)got;
        return data;
    }
    FILE* f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0 || len > 64L * 1024 * 1024) { fclose(f); return NULL; }
    uint8_t* data = (uint8_t*)malloc((size_t)len);
    if (!data) { fclose(f); return NULL; }
    if (fread(data, 1, (size_t)len, f) != (size_t)len) {
        fclose(f); free(data); return NULL;
    }
    fclose(f);
    *outSize = (unsigned int)len;
    return data;
}

static RewampDecoder* v2m_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;
    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    { char* q = strrchr(cleanPath, '?'); if (q) *q = '\0'; }

    unsigned int dataSize = 0;
    uint8_t* data = v2m_read_file(cleanPath, &dataSize);
    if (!data) return NULL;

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { free(data); return NULL; }
    dec->player = new v2redux::Player();
    /* open() COPIE les données: le tampon peut être libéré juste après. */
    const v2redux::Result r = dec->player->open(data, dataSize);
    free(data);
    if (r != v2redux::Result::OK) {
        delete dec->player;
        free(dec);
        return NULL;
    }

    /* Anneaux du scope AVANT le premier rendu: le cœur y écrit en ligne dès la
     * première frame (v2core.cpp). L'anneau est circulaire, donc le lecteur
     * doit l'être aussi. Taille >= ~2212 exigée par la recherche de
     * stabilisation du scope (PLUGINS.md §2.3). */
    m_genNumVoicesChannels = V2M_VOICES;
    rewamp_channel_data_reset(V2M_VOICES);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);
    rewamp_channel_data_set_ring_circular(1);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("V2 Synth", 0, V2M_VOICES);

    /* ⚠️ lengthMs() rend la fin de la SÉQUENCE, pas celle de la MUSIQUE. Mesuré
     * sur fr019: du son à 1 min, puis silence complet de 10 à 66 min, et
     * lengthMs() annonce 67 min — un morceau de 4 min afficherait une heure et
     * ne finirait jamais. Le dernier ÉVÉNEMENT de séquence est le bon repère;
     * c'est déjà ce que l'ancien portage utilisait (CalcPositions + 2 s). */
    long long ms = dec->player->lastEventMs();
    if (ms <= 0) ms = dec->player->lengthMs();
    dec->totalFrames = ms > 0
        ? (uint64_t)((ms + V2M_TAIL_MS) * (long long)V2M_RATE / 1000)
        : 0;

    const int ver = dec->player->fileVersion();
    if (ver >= 0)
        rewamp_track_message_append("Format: V2M v%d (Farbrausch V2 synth)\n", ver);
    else
        rewamp_track_message_append("Format: V2M (Farbrausch V2 synth)\n");
    if (ms > 0)
        rewamp_track_message_append("Duration: %lld:%02lld\n",
                                    ms / 60000, (ms / 1000) % 60);

    /* lengthMs() implique une remise à zéro du synthé — jouer APRÈS. */
    dec->player->play(0);
    dec->lastMuteMask = ~(int64_t)0;   /* force le premier push du masque */

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = V2M_RATE;
    }
    return dec;
}

static uint64_t v2m_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->player || frameCount == 0) return 0;
    if (dec->totalFrames && dec->pos >= dec->totalFrames) return 0;
    if (dec->totalFrames && dec->pos + frameCount > dec->totalFrames)
        frameCount = dec->totalFrames - dec->pos;

    /* Mute: le masque de v2redux est l'INVERSE du nôtre — bit posé = canal
     * AUDIBLE, alors que generic_mute_mask pose le bit d'une voix COUPÉE.
     * Un canal muet continue de rendre ses voix et ses effets, donc couper et
     * rétablir est instantané et en phase (rien ne se désynchronise). */
    if (dec->lastMuteMask != generic_mute_mask) {
        dec->lastMuteMask = generic_mute_mask;
        dec->player->setChannelMask((uint32_t)(~generic_mute_mask) & 0xFFFFu);
    }

    dec->player->render(out, (uint32_t)frameCount);
    dec->pos += frameCount;

    /* Niveau par voix, lu-et-effacé à chaque bloc. C'est un vrai niveau, là où
     * l'ancien portage écrivait la constante 1 dans une échelle 0..255 — la
     * jauge d'une voix V2M lisait donc zéro.
     *
     * La note s'éteint quand le canal n'a plus AUCUNE voix active. Le critère
     * est la POLYPHONIE, pas le niveau: une note qui décroît sans note-off doit
     * disparaître, mais un niveau nul ne veut pas dire « finie » — le mètre est
     * lu-et-effacé, donc une nappe tenue traverse des blocs nuls. Mesuré: en
     * comptant les blocs silencieux, deux voies de fr08 sortaient sans aucune
     * note alors qu'elles jouaient tout du long, dont une frappée UNE fois. */
    float lv[16];
    dec->player->getChannelLevels(lv);
    int poly[16];
    dec->player->getChannelPoly(poly);
    for (int c = 0; c < V2M_VOICES; c++) {
        float v = lv[c];
        if (v < 0.0f) v = 0.0f;
        if (v > 1.0f) v = 1.0f;
        vgm_last_vol[c] = (unsigned int)(v * 255.0f);
        if (poly[c] <= 0) vgm_last_note[c] = 0;
    }
    return frameCount;
}

static void v2m_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->player) return;
    dec->player->play((uint32_t)(frameIndex * 1000ull / V2M_RATE));
    dec->pos = frameIndex;
}

static uint64_t v2m_length(RewampDecoder* dec) {
    return dec ? dec->totalFrames : 0;
}

static void v2m_close(RewampDecoder* dec) {
    if (!dec) return;
    delete dec->player;
    free(dec);
}

static const RewampPluginVTable kV2mVTable = {
    "v2m",
    v2m_probe,
    v2m_open,
    v2m_read,
    v2m_seek,
    v2m_length,
    v2m_close,
};

extern "C" const RewampPluginVTable* rewamp_v2m_plugin(void) { return &kV2mVTable; }

#endif /* REWAMP_WITH_V2M */
