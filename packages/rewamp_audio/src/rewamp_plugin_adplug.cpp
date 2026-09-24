// rewamp_plugin_adplug.cpp — AdPlug decoder plugin (AdLib / OPL2/OPL3 formats).
//
// Covers the classic AdLib tracker/streamer formats (.d00 .hsc .rol .laa .cmf
// .imf .dro .adl .bam .rad .a2m .amd .sng .rix .lds .ksm .mkj .cff .xad …) via
// AdPlug (latest upstream) driven by the DOSBox "woody" OPL3 emulator wrapped in
// CSurroundopl (Modizer's default: two detuned mono chips → stereo).
//
// Per-voice oscilloscope + notes + mute are produced INSIDE the vendored OPL
// emulator: woodyopl.cpp writes the 18 OPL3 channels into voicesData[] then into
// m_voice_buff[] (ring mask SOUND_BUFFER_SIZE_SAMPLE*2 = 1024) and honors
// generic_mute_mask; surroundopl.cpp gates capture to chip A via
// m_voice_current_system so the stereo pair isn't captured twice. This plugin
// wires playback (tick loop) + the OPL3 chip grouping metadata.

#ifdef REWAMP_WITH_ADPLUG

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"   // per-voice scope + chip grouping + track message
#include "rewamp_assets.h"         // rewamp_get_data_dir() → bundled adplug.db

#include "adplug.h"
#include "adl.h"          // CadlPlayer: la sonde de sous-chansons interroge le pilote
#include "fprovide.h"     // CProvider_Filesystem (chargement de la sonde)
#include "surroundopl.h"
#include "wemuopl.h"
#include "silentopl.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <string>

#define ADPLUG_RATE          44100
#define ADPLUG_CHANNELS      2
#define ADPLUG_VOICES        18                 // OPL3 = 18 channels
#define ADPLUG_RING_SAMPLES  (512 * 2)          // woodyopl ring mask: SOUND_BUFFER_SIZE_SAMPLE*2

struct RewampDecoder {
    CPlayer*   player;
    Copl*      opl;
    int        rate;
    double     tickSamples;   // fractional samples remaining in the current replay tick
    int16_t*   pcm;           // scratch interleaved int16 stereo
    uint64_t   pcmFrames;
    int        ended;
    uint64_t   totalFrames;   // songlength()-derived duration (0 = unknown)
    uint64_t   framePos;
};

// AdLib-exclusive extensions (Modizer SUPPORTED_FILETYPE_ADPLUG minus the ones
// owned by stronger rewamp plugins: mid→FluidLite, s3m→OpenMPT, vgm/vgz→libvgm,
// and the too-generic m/raw). AdPlug still content-verifies in open().
static const char* const kAdplugExts[] = {
    "a2m","a2t","adl","adlib","agd","amd","as3m","bam","bmf","cff","cmf",
    "d00","dfm","dm0","dmo","dr0","dro","dtm","got","ha2","hsc","hsp","hsq",
    "ims","imf","jbm","ksm","laa","lds","mad","mdi","mdy","mkf","mkj","msc",
    "mtk","mtr","mus","pis","plx","rac","rad","rix","rol","sa2","sat","sci",
    "sdb","sng","sop","sqx","wlf","xad","xms","xsm",
    NULL
};

// AdPlug formats with an unambiguous file-magic. These win by CONTENT even when
// the extension is generic/shared (e.g. .raw = Rdos RAW-OPL vs vgmstream's
// headerless PCM .raw), so a header check routes them to AdPlug before
// vgmstream's catch-all (score 50) claims them by extension.
static int adplug_magic_score(const uint8_t* hdr, size_t n) {
    if (n >= 8 && memcmp(hdr, "RAWADATA", 8) == 0) return 100;  // raw.cpp (Rdos RAW OPL)
    if (n >= 8 && memcmp(hdr, "DBRAWOPL", 8) == 0) return 100;  // dro/dro2.cpp (DOSBox raw OPL)
    return 0;
}

static int adplug_probe(const char* ext, const uint8_t* hdr, size_t n) {
    int m = adplug_magic_score(hdr, n);
    if (m) return m;   // header-identified → beats vgmstream regardless of ext
    if (!ext || !rewamp_ext_in_list(ext, kAdplugExts)) return 0;
    // Exclusive AdLib extensions: score above the generic fallback but below
    // header-confirmed native plugins. open() runs AdPlug's real content probe.
    return 90;
}

// ── Sonde de sous-chansons `.adl` (Westwood ADL) ──────────────────────────
//
// Un `.adl` est une TABLE de morceaux, et AdPlug n'en compte que la LONGUEUR:
// `CadlPlayer::load` cherche la DERNIÈRE entrée valide et pose
// `numsubsongs = index + 1` (adl.cpp), TROUS COMPRIS. Mesuré: DUNE19.ADL
// annonce 74 pistes, LOREINTR.ADL 55, « eob2 - catacomb » 120 — pour 43, 28 et
// 111 qui produisent réellement une note. Un rip complet affichait donc des
// dizaines de lignes muettes.
//
// ⚠️ **L'en-tête seul ne suffit PAS.** Une première version lisait les tables
// (entrée ≠ sentinelle + offset de programme non nul, les deux conditions que
// `play()` et `getProgram()` exigent) et retirait bien les 28 slots morts de
// DUNE19 — mais elle gardait les entrées 0, 1 et 10, qui portent de VRAIS
// programmes dont aucun ne joue une note: ce sont les routines de CONTRÔLE du
// pilote Westwood (arrêt, fondu — `beginFadeOut` joue la piste 1). Et la règle
// « les programmes bas sont du contrôle » ne tient pas non plus: sur
// « eob2 - catacomb » c'est l'entrée 2, qui désigne le programme 98.
//
// Donc on demande au PILOTE, pas à l'en-tête: `rewind(n)` puis on fait tourner
// le programme sur un OPL ESPION qui ne synthétise rien et ne retient qu'une
// chose — un key-on a-t-il été écrit (0xB0-0xB8 bit 5, ou les percussions en
// 0xBD). C'est exactement ce que la lecture ferait, sans émulation ni sortie.
// Coût mesuré sur les quatre `.adl` du disque: 0,3 à 0,9 ms pour le FICHIER
// ENTIER (la plupart des programmes se terminent en quelques trames, et on
// s'arrête à la PREMIÈRE note). Budget 60 s de rejeu par piste, ce qui borne le
// seul cas coûteux — un programme qui ne finit jamais et ne joue rien.
//
// ⚠️ La liste est CREUSE: la 6e piste jouable de DUNE19 porte l'index 10. Le
// `?subsong=` de rewamp veut le VRAI index (celui que `rewind()` reçoit), donc
// la position dans la liste ne peut pas en tenir lieu — d'où
// rewamp_adplug_probe_get_index(), relayé par rewamp_probe_subsong_index().
//
// ⚠️ « joue une note » ne veut pas dire « musique »: beaucoup d'entrées d'un
// ADL de jeu sont des BRUITAGES, et rien ne les distingue d'un thème. On ne
// retire que ce qui est PROUVÉ muet.
static void adplug_ensure_database(void);   // défini plus bas (une fois par processus)

#define ADPLUG_ADL_PROBE_MAX   250
// Le replay ADL est fixé à 72 Hz, et la borne est celle d'AdPlug lui-même
// (`CPlayer::songlength` s'arrête à 10 minutes de temps VIRTUEL).
#define ADPLUG_ADL_PROBE_TICKS (72 * 600)

static int s_adl_probe_count = 0;
static int s_adl_probe_index[ADPLUG_ADL_PROBE_MAX];
static int s_adl_probe_ms[ADPLUG_ADL_PROBE_MAX];

// OPL espion: aucune synthèse, on ne retient que « une note a-t-elle démarré ».
class CAdlProbeOpl : public Copl {
public:
    int keyed = 0;
    void write(int reg, int val) override {
        if (reg >= 0xB0 && reg <= 0xB8 && (val & 0x20)) keyed = 1;       // key-on
        else if (reg == 0xBD && (val & 0x20) && (val & 0x1F)) keyed = 1; // percussions
    }
    void init(void) override { keyed = 0; }
};

extern "C" int rewamp_adplug_probe_subsong_count(const char* path) {
    s_adl_probe_count = 0;
    if (!path) return 0;

    char clean[4096];
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strrchr(clean, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) *q = '\0';

    const char* dot = strrchr(clean, '.');
    if (!dot) return 0;
    char ext[16] = {0};
    for (int i = 0; dot[i + 1] && i < 15; i++)
        ext[i] = (char)tolower((unsigned char)dot[i + 1]);
    if (strcmp(ext, "adl") != 0) return 0;   // le seul format concerné

    adplug_ensure_database();

    CAdlProbeOpl opl;
    CadlPlayer player(&opl);
    CProvider_Filesystem fp;
    // load() refait ses propres contrôles de plausibilité (tailles minimales,
    // offsets de programmes): un faux `.adl` échoue ici et la sonde rend 0.
    if (!player.load(clean, fp)) return 0;

    const unsigned nsub = player.getsubsongs();
    const float refresh = player.getrefresh() > 0.0f ? player.getrefresh() : 72.0f;
    int live = 0;
    for (unsigned s = 0; s < nsub && live < ADPLUG_ADL_PROBE_MAX; s++) {
        opl.keyed = 0;
        player.rewind((int)s);
        // UNE passe donne les deux réponses. On ne s'arrête PAS à la première
        // note: la DURÉE veut la fin du programme, et c'est exactement la
        // boucle de `CPlayer::songlength` — qui, elle, échangerait notre OPL
        // espion contre son propre CSilentopl et masquerait les key-on. Coût
        // mesuré pour le fichier entier: 0,4 ms (eob2, 120 morceaux), 2,4 ms
        // (LOREINTR).
        int ticks = 0;
        while (ticks < ADPLUG_ADL_PROBE_TICKS && player.update()) ticks++;
        if (opl.keyed) {
            s_adl_probe_ms[live]      = (int)((double)ticks * 1000.0 / refresh);
            s_adl_probe_index[live++] = (int)s;
        }
    }

    s_adl_probe_count = live;
    return live;
}

/* Index RÉEL de la i-ème sous-chanson jouable (la liste est creuse). */
extern "C" int rewamp_adplug_probe_get_index(int idx) {
    if (idx < 0 || idx >= s_adl_probe_count) return idx;
    return s_adl_probe_index[idx];
}

/* Durée de la i-ème sous-chanson jouable, en ms. Même passe que le comptage
 * (voir ci-dessus), donc gratuite. -1 hors liste = « inconnue ». */
extern "C" int rewamp_adplug_probe_get_duration_ms(int idx) {
    if (idx < 0 || idx >= s_adl_probe_count) return -1;
    return s_adl_probe_ms[idx];
}

// Build the surround OPL3 (two woody chips) exactly like Modizer's default path
// (mADPLUGopltype=0, mADPLUGstereosurround=1).
static Copl* adplug_make_opl(int rate) {
    /* Settings → Moteurs → AdPlug: 1 = surround (two detuned chips, Modizer
     * default), 0 = plain stereo single chip. Applied on the next open. */
    if (rewamp_get_engine_param("adplug", "surround", 1) > 0.5) {
        COPLprops a, b;
        a.use16bit = b.use16bit = true;
        a.stereo   = b.stereo   = false;
        a.opl = new CWemuopl(rate, a.use16bit, a.stereo);
        b.opl = new CWemuopl(rate, b.use16bit, b.stereo);
        return new CSurroundopl(&a, &b, true);
    }
    return new CWemuopl(rate, true, true);
}

// The AdPlug module-info database (title/length + per-file playback hints some
// players need). Loaded once from <datadir>/adplug/adplug.db and shared by all
// factory() calls via CAdPlug::set_database().
static void adplug_ensure_database(void) {
    static int tried = 0;
    if (tried) return;
    tried = 1;
    const char* dd = rewamp_get_data_dir();
    if (!dd || !dd[0]) return;
    char path[4096];
    snprintf(path, sizeof(path), "%s/adplug/adplug.db", dd);
    CAdPlugDatabase* db = new CAdPlugDatabase();
    if (db->load(path)) {
        CAdPlug::set_database(db);
    } else {
        delete db;   // absent → factory works without it (detection by ext/magic)
    }
}

static void adplug_setup_voices(void) {
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("OPL3", 0, ADPLUG_VOICES);
    char nm[16];
    for (int i = 0; i < ADPLUG_VOICES; i++) {
        snprintf(nm, sizeof(nm), "OPL %d", i + 1);
        rewamp_voice_set_name(i, nm);
    }
    // woodyopl writes m_voice_buff[] with mask &(SOUND_BUFFER_SIZE_SAMPLE*2-1)
    // and wraps m_voice_current_ptr the same way → circular ring (not monotonic).
    rewamp_channel_data_reset(ADPLUG_VOICES);
    rewamp_channel_data_set_ring_write_size(ADPLUG_RING_SAMPLES);
    rewamp_channel_data_set_ring_circular(1);
}

static RewampDecoder* adplug_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    // Strip ?subsong=N (rewamp convention).
    char clean[4096];
    int subsong = 0;
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strrchr(clean, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) { subsong = atoi(q + 9); *q = '\0'; }

    adplug_ensure_database();       // shared module-info DB (once)

    // ── Metadata + duration on a THROWAWAY player ──────────────────────────
    // songlength() replays the whole song to the end; some players (notably
    // Adlib Tracker 2 / .a2m/.a2t) don't fully reset on the following rewind() →
    // the real playback would be silent. Measure on a separate player instance
    // whose OPL is a CSilentopl, so the player we actually play is only ever
    // rewind()'d (never advanced past the end).
    uint64_t totalFrames = 0;
    std::string mType, mTitle, mAuthor, mDesc;
    unsigned int nsub = 1, ninstr = 0;
    std::string instrs;
    {
        CSilentopl silent;
        CPlayer* meta = CAdPlug::factory(clean, &silent);
        if (!meta) return NULL;     // not an AdPlug file → registry falls through
        nsub = meta->getsubsongs();
        int ss = subsong;
        if (ss < 0 || (unsigned)ss >= nsub) ss = 0;
        unsigned long ms = meta->songlength(ss);
        totalFrames = (uint64_t)ms * (uint64_t)ADPLUG_RATE / 1000ULL;
        mType = meta->gettype();  mTitle = meta->gettitle();
        mAuthor = meta->getauthor();  mDesc = meta->getdesc();
        ninstr = meta->getinstruments();
        for (unsigned int i = 0; i < ninstr; i++) {
            std::string in = meta->getinstrument(i);
            if (!in.empty()) { instrs += in; instrs += '\n'; }
        }
        delete meta;
    }
    if (subsong < 0 || (unsigned)subsong >= nsub) subsong = 0;

    // ── Real playback player ───────────────────────────────────────────────
    Copl* opl = adplug_make_opl(ADPLUG_RATE);
    if (!opl) return NULL;
    CPlayer* player = CAdPlug::factory(clean, opl);
    if (!player) { delete opl; return NULL; }

    // Per-voice scope + OPL3 grouping BEFORE the first tick so woodyopl writes
    // into freshly-allocated m_voice_buff[*].
    adplug_setup_voices();
    player->rewind(subsong);        // primes tick 0 (never advanced to the end)

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { delete player; delete opl; return NULL; }
    dec->player      = player;
    dec->opl         = opl;
    dec->rate        = ADPLUG_RATE;
    dec->tickSamples = 0.0;
    dec->totalFrames = totalFrames;

    // Info panel.
    if (!mType.empty())   rewamp_track_message_append("Type: %s\n", mType.c_str());
    if (!mTitle.empty())  rewamp_track_message_append("Title: %s\n", mTitle.c_str());
    if (!mAuthor.empty()) rewamp_track_message_append("Author: %s\n", mAuthor.c_str());
    if (!mDesc.empty())   rewamp_track_message_append("Description: %s\n", mDesc.c_str());
    if (nsub > 1)         rewamp_track_message_append("Subsongs: %u\n", nsub);
    if (!instrs.empty())  rewamp_track_message_append("\nInstruments:\n%s", instrs.c_str());

    outFormat->channels   = ADPLUG_CHANNELS;
    outFormat->sampleRate = (uint32_t)ADPLUG_RATE;
    return dec;
}

static uint64_t adplug_read_frames(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->player || !dec->opl || !out || frameCount == 0) return 0;
    if (dec->ended) return 0;

    if (frameCount > dec->pcmFrames) {
        free(dec->pcm);
        dec->pcm = (int16_t*)malloc(frameCount * ADPLUG_CHANNELS * sizeof(int16_t));
        dec->pcmFrames = dec->pcm ? frameCount : 0;
    }
    if (!dec->pcm) return 0;

    uint64_t produced = 0;
    while (produced < frameCount) {
        if (dec->tickSamples < 1.0) {
            if (!dec->player->update()) { dec->ended = 1; break; }
            float refresh = dec->player->getrefresh();
            if (refresh <= 0.0f) refresh = 50.0f;
            dec->tickSamples += (double)dec->rate / (double)refresh;
        }
        uint64_t chunk = frameCount - produced;
        if ((double)chunk > dec->tickSamples) chunk = (uint64_t)dec->tickSamples;
        if (chunk == 0) chunk = 1;
        dec->opl->update(dec->pcm + produced * ADPLUG_CHANNELS, (int)chunk);
        dec->tickSamples -= (double)chunk;
        produced += chunk;
    }

    const int samples = (int)(produced * ADPLUG_CHANNELS);
    const float inv = 1.0f / 32768.0f;
    for (int i = 0; i < samples; i++) out[i] = dec->pcm[i] * inv;
    dec->framePos += produced;
    return produced;
}

static void adplug_seek_frames(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->player) return;
    // CPlayer::seek is ms-based and rewinds internally; converts frame→ms.
    unsigned long ms = (unsigned long)(frameIndex * 1000ULL / (uint64_t)dec->rate);
    dec->player->seek(ms);
    dec->tickSamples = 0.0;
    dec->ended = 0;
    dec->framePos = frameIndex;
}

static uint64_t adplug_length_frames(RewampDecoder* dec) {
    return dec ? dec->totalFrames : 0;
}

static void adplug_close(RewampDecoder* dec) {
    if (!dec) return;
    delete dec->player;   // does not own opl
    delete dec->opl;      // CSurroundopl deletes its two child OPLs
    free(dec->pcm);
    free(dec);
}

static const RewampPluginVTable kAdplugVTable = {
    "adplug",
    adplug_probe,
    adplug_open,
    adplug_read_frames,
    adplug_seek_frames,
    adplug_length_frames,
    adplug_close,
};

extern "C" const RewampPluginVTable* rewamp_adplug_plugin(void) { return &kAdplugVTable; }

#endif /* REWAMP_WITH_ADPLUG */
