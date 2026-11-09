// libuade plugin — Amiga custom-chip music via UADE (Unix Amiga Delitracker
// Emulator). Real 68k emulation + bundled "eagleplayer" players. Compiled only
// when REWAMP_WITH_UADE is defined.
//
// Process model: upstream UADE spawns uadecore (the 68k emulator) as a
// subprocess. rewamp builds the vendored tree with -DUADE_IN_PROCESS so uadecore
// runs in a pthread instead (iOS-safe, no fork). See third_party/uade patches
// (ossupport.c / uadestate.c / uademain.c) and the uade-integration memory.
#ifdef REWAMP_WITH_UADE

#include "rewamp_plugin.h"
#include "rewamp_assets.h"   // rewamp_get_data_dir() → bundled players/score/confs
#include "rewamp_channel_data.h" // per-voice scope + chip grouping (Paula 4 voices)

extern "C" {
#include <uade/uade.h>
#include <uade/amifilemagic.h>   // uade_filemagic() — content detection for prefix-form files
}

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <vector>
#include <strings.h>
#include <signal.h>

struct RewampDecoder {
    struct uade_state* st;
    int       rate;
    int16_t*  pcm;        // scratch interleaved int16 stereo
    uint64_t  pcmFrames;
    int       ended;
    double    speed;      // native playback speed asked for (0 = 1×)
    int       seekPending;// the speed waits at 1× until UADE's seek completes
    int       speedRefused;// paced by audio interrupts (TFMX): no native speed
};

/* uadecore/custom.c: native playback speed — CIA E clock and VBlank × speed,
 * Paula at its clock (the pitch does not move); libuade counts song time. */
extern "C" volatile double uade_rewamp_speed;
/* uadecore/custom.c: the replay is paced by audio interrupts (TFMX). */
extern "C" int uade_rewamp_audio_paced(void);

/* Settings → Moteurs → UADE (Modizer's UADE family; uade_effect_run applies
 * these inside libuade's own read pipeline). Defaults: post-FX ON, panning ON
 * at 0.7, the rest OFF — matching Modizer. */
static void uade_apply_engine_params(struct uade_state* st) {
    int postfx = (int)rewamp_get_engine_param("uade", "postfx", 1);
    int pan    = (int)rewamp_get_engine_param("uade", "pan_enabled", 1);
    int head   = (int)rewamp_get_engine_param("uade", "headphones", 0);
    int gain   = (int)rewamp_get_engine_param("uade", "gain_enabled", 0);
    double panv  = rewamp_get_engine_param("uade", "pan_value", 0.7);
    double gainv = rewamp_get_engine_param("uade", "gain_value", 0.5);
    (postfx ? uade_effect_enable : uade_effect_disable)(st, UADE_EFFECT_ALLOW);
    (pan    ? uade_effect_enable : uade_effect_disable)(st, UADE_EFFECT_PAN);
    (head   ? uade_effect_enable : uade_effect_disable)(st, UADE_EFFECT_HEADPHONES);
    /* LED (Paula low-pass filter): 0 = auto (song controls its own LED —
     * don't touch), 1 = force ON, 2 = force OFF. Forcing works live:
     * uade_set_filter_state queues the filter command to uadecore (uade123
     * does exactly this after toggling UC_FORCE_LED). */
    int led = (int)rewamp_get_engine_param("uade", "led", 0);
    if (led != 0) {
        struct uade_config* ec = uade_get_effective_config(st);
        if (ec) uade_config_set_option(ec, UC_FORCE_LED, led == 1 ? "on" : "off");
        uade_set_filter_state(st, led == 1 ? 1 : 0);
    }
    /* NOTE: modern libuade dropped UADE_EFFECT_NORMALISE — not exposed. */
    (gain   ? uade_effect_enable : uade_effect_disable)(st, UADE_EFFECT_GAIN);
    uade_effect_pan_set_amount(st, (float)panv);
    uade_effect_gain_set_amount(st, (float)gainv);
}

// Amiga formats UADE handles, addressed by file *suffix*. This is Modizer's full
// UADE extension set, cross-checked against the bundled eagleplayer.conf, with the
// extensions owned by a better-suited plugin removed to keep their routing intact
// (openmpt: mod/med/okt/digi; sidplayfp: sid; highlyexp: psf; zxtune: ay/sqt; …)
// and the prefix-form tokens with dots ("tfmx1.5") dropped (a suffix probe can't
// match them). Many UADE files use the Amiga *prefix* convention ("ahx.song") —
// those don't reach a suffix probe and are out of scope. Score 58: beats
// vgmstream's catch-all (50), loses to any format-specific plugin with a header.
static const char* const kUadeExts[] = {
    "arp", "ast", "ahx", "thx", "amc", "abk", "aam", "alp", "aon", "aon4",
    "aon8", "adsc", "mod_adsc4", "bss", "bd", "bds", "uds", "kris", "cin", "core",
    "cus", "cust", "custom", "cm", "rk", "rkb", "dz", "mkiio", "dl", "dl_deli",
    "dln", "dh", "dw", "dwold", "dlm2", "dm2", "dlm1", "dm1", "dsr", "db",
    "dsc", "dss", "dns", "ems", "emsv6", "ex", "fc13", "fc3", "fc", "fc14",
    "fc4", "fred", "gray", "bfc", "bsi", "fc-bsi", "fp", "fw", "glue", "gm",
    "ea", "mg", "hd", "hipc", "soc", "emod", "qc", "ims", "dum", "is",
    "is20", "jam", "jc", "jmf", "jcb", "jcbo", "jpn", "jpnd", "jp", "jt",
    "mon_old", "jo", "hip", "mcmd", "sog", "hip7", "s7g", "hst", "kh", "powt",
    "pt", "lme", "mon", "mfp", "hn", "mtp2", "thn", "mc", "mcr", "mco",
    "mk2", "mkii", "avp", "mw", "max", "mcmd_org", "mmd0", "mmd1", "mmd2", "mso",
    "md", "mmdc", "dmu", "mug", "dmu2", "mug2", "ma", "mm4", "mm8", "mms",
    "ntp", "two", "octamed", "okta", "one", "ps", "snk", "pvp", "pap", "psa",
    "mod_doc", "mod15", "mod15_mst", "mod_ntk", "mod_ntk1", "mod_ntk2", "mod_ntkamp", "mod_flt4", "mod_comp", "40a",
    "40b", "41a", "50a", "60a", "61a", "ac1", "ac1d", "aval", "chan", "cp",
    "cplx", "crb", "di", "eu", "fc-m", "fcm", "ft", "fuz", "fuzz", "gmc",
    "gv", "hmc", "hrt", "ice", "it1", "kef", "kef7", "krs", "ksm", "lax",
    "mexxmp", "mpro", "np", "np1", "np2", "noisepacker2", "np3", "noisepacker3", "nr", "nru",
    "ntpk", "p10", "p21", "p30", "p40a", "p40b", "p41a", "p4x", "p50a", "p5a",
    "p5x", "p60", "p60a", "p61", "p61a", "p6x", "pha", "pin", "pm", "pm0",
    "pm01", "pm1", "pm10c", "pm18a", "pm2", "pm20", "pm4", "pm40", "pmz", "polk",
    "pp10", "pp20", "pp21", "pp30", "ppk", "pr1", "pr2", "prom", "pru", "pru1",
    "pru2", "prun", "prun1", "prun2", "pwr", "pyg", "pygm", "pygmy", "skt", "skyt",
    "snt", "st2", "st26", "st30", "star", "stpk", "tp", "tp1", "tp2", "tp3",
    "un2", "unic", "unic2", "wn", "xan", "xann", "zen", "puma", "rjp", "sng",
    "riff", "rh", "rho", "sa-p", "scumm", "s-c", "scn", "scr", "sid1", "smn",
    "sid2", "mok", "sa", "sonic", "sa_old", "smus", "snx", "tiny", "spl", "sc",
    "sct", "sfx", "sfx13", "tw", "sm", "sm1", "sm2", "sm3", "smpro", "bp",
    "sndmon", "bp3", "sjs", "jd", "doda", "sas", "ss", "sb", "jpo", "jpold",
    "sun", "syn", "sdr", "osp", "st", "synmod", "tfmx7v", "tfhd7v", "mdat", "tfmxpro",
    "tfhdpro", "tfmx", "mdst", "thm", "tf", "tme", "sg", "dp", "trc", "tro",
    "tronic", "mod15_ust", "vss", "wb", "ml", "mod15_st-iv", "agi", "tpu", "qpa", "qts",
    // Quartet ST scores are named NAME.4v by modland while UADE knows the
    // format as the "qts" prefix; eagleplayer.conf carries 4v as an alias so
    // both spellings reach Quartet_ST (it tries the prefix, then the suffix).
    "4v",
    "oss", "ymst", "lion",
    // Andrew Parton (eagleplayer.conf: "Andrew_Parton prefixes=bye") — a
    // prefix-convention format ("bye.NAME"); listed here because the registry
    // probes the Amiga prefix token against this same list (see
    // extract_prefix), so one entry covers both bye.NAME and NAME.bye.
    "bye",
    // Remaining eagleplayer.conf prefixes not owned by a better-suited plugin.
    // Deliberately still excluded: dat/sid/mus (sidplayfp), psf (highlyexp),
    // ftm (furnace), midi (FluidLite), ptm (openmpt), ym/sqt (zxtune), and
    // "adpcm" (vgmstream owns it — UADE's 58 would hijack every game-stream
    // .adpcm to the Amiga raw-ADPCM player). The dotted tokens (tfmx1.5,
    // tfhd1.5) are unmatchable by either a suffix or a first-dot prefix.
    "!pm!", "aps", "ash", "dm", "hot", "hrt!", "ism", "jb", "js", "kim",
    "mod3", "mosh", "mth", "npp", "oldw", "pat", "pn", "prt", "rj", "sdata",
    "sdc", "sfx20", "sj", "smod", "snt!", "tcb", "tits", "tmk", "tron", "ufo",
    // webUADE+ soundcore players (audio.device/multitasking score extensions):
    // Digital Sound Creations ("han.NAME" — UnExotica's Hanlon rips), Music-X
    // driver, MaxTrax, GT Game Systems, SoundTracker Pro II, Stonetracker,
    // PlayAY's amad/strc. "ay" stays deliberately EXCLUDED (zxtune owns it).
    // "stp" is NOT here: zxtune claims .stp too (ZX Sound Tracker Pro, score
    // 55), so it lives in kUadeSharedExts below (40) — zx files keep their
    // engine, the Amiga prefix-form "stp.NAME" still routes here (zxtune only
    // matches the suffix), and the per-extension preference can pin UADE.
    "han", "mx", "mxp", "mxtx", "dux", "spm", "amad", "strc",
    NULL
};

// Formats normally owned by libopenmpt but also playable by UADE (real Amiga
// replay): claimed at a LOW score so libopenmpt keeps winning by default,
// while the user's per-extension preference (Settings → Moteurs) can pin UADE.
static const char* const kUadeSharedExts[] = {
    "mod", "med", "mmd0", "mmd1", "mmd2", "mmd3", "okt", "digi", "stp", NULL,
};

/* BP SoundMon V1 (« BPSM ») — converti en V.2 AVANT de le donner à UADE.
 *
 * UADE n'embarque que les replays V.2 et V.2.2, dont le contrôle de format
 * exige « V.2 » / « V.3 » à l'offset 26: un module V1 est refusé net
 * (« module check failed »), et UADE AMONT ne connaît pas non plus cette
 * magie. Or les deux versions ne diffèrent QUE par l'en-tête — 26 octets de
 * titre, puis 4 octets « BPSM » en V1 contre « V.2 » suivi du NOMBRE DE TABLES
 * D'ONDE en V.2 (un module V1 n'a pas ce bloc, donc zéro table). Instruments
 * (nom sur 24 octets + longueur / loop / repeat / volume), table de steps,
 * motifs et effets sont identiques; seule la V.3 ajoute des cas particuliers.
 *
 * ⚠️ La voie essayée d'abord — ajouter le replay Eagleplayer « SoundMon »,
 * qui lui accepte « BPSM » — a été ÉCARTÉE: il joue, mais il repointe la voie
 * sur deux octets nuls du module avec `AUDxLEN = 0`, ce qui vaut 65536 mots
 * sur Paula. À la fin de chaque percussion (`repeat == 2`, donc sans boucle) le
 * DMA continuait alors à lire le MODULE comme un échantillon, à la période de
 * la note: craquements réguliers sur la voie 1. Le replay Delitracker d'UADE
 * écrit `LEN = 1` au même endroit — vérifié sur le même module V.2, mêmes
 * notes, seul ce mot diffère (385 × 0 contre 386 × 1). Mesuré sur « reaching
 * for the sky »: 45 discontinuités et un bruit HF de 622 par le replay EP,
 * 21 et 502 par celui-ci, les 21 restants étant des attaques de percussion. */
static bool uade_is_bpsm_v1(const unsigned char* h, size_t n) {
    return h != NULL && n >= 30 && memcmp(h + 26, "BPSM", 4) == 0;
}

/* Le fichier entier en mémoire, magie réécrite — NULL si ce n'est pas un V1
 * (le cas courant: on ne lit alors que l'en-tête). L'appelant libère. */
static unsigned char* uade_bpsm_v1_to_v2(const char* path, size_t* outSize) {
    FILE* f = fopen(path, "rb");
    if (!f) return NULL;
    unsigned char head[30];
    size_t got = fread(head, 1, sizeof(head), f);
    if (!uade_is_bpsm_v1(head, got)) { fclose(f); return NULL; }
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return NULL; }
    long size = ftell(f);
    /* Un module SoundMon tient dans quelques centaines de kilo-octets. */
    if (size < 30 || size > (long)(8 * 1024 * 1024)) { fclose(f); return NULL; }
    rewind(f);
    unsigned char* buf = (unsigned char*)malloc((size_t)size);
    if (!buf) { fclose(f); return NULL; }
    if (fread(buf, 1, (size_t)size, f) != (size_t)size) {
        free(buf); fclose(f); return NULL;
    }
    fclose(f);
    memcpy(buf + 26, "V.2\0", 4);   /* « V.2 » + zéro table d'onde */
    *outSize = (size_t)size;
    return buf;
}

/* Maximum Effect (« MAX.* », compagnon « SMP.* ») — des mots longs dont les
 * trois octets HAUTS sont remplis d'un octet de BOURRAGE au lieu de zéros.
 *
 * Le format s'ouvre sur deux constantes, 15 et 20 (`0000000f 00000014`), puis
 * les offsets des quatre pistes. Une partie des rips modland porte, dans
 * certains de ces mots longs, `2d2d2d` (« --- ») ou `d4d4d4` à la place de
 * `000000`: le replay 68k refuse alors le module (« module check failed »),
 * `uade123` amont compris, et l'option qui ignore ce contrôle ne rend que du
 * silence — les offsets pointent hors du fichier. Mesuré sur modland: les cinq
 * « AlloAllo level* » (Old Tramp, `2d`) et « DinosaurDetective intro /
 * complete » (Jonathan Scarcliffe, `d4`); les quinze autres fichiers des deux
 * dossiers sont propres. Le bourrage ne se limite pas à l'en-tête: « intro »
 * l'a aussi sur le mot long qui précède chaque piste (`d4d4d424`).
 *
 * Réparation: l'octet de bourrage se lit sur l'une des deux constantes, et
 * tout mot long ALIGNÉ dont les trois octets hauts le valent est remis à zéro.
 * Vérifié par `uade123` sur les sept fichiers réparés: tous jouent (RMS
 * 1944 à 4264, du même ordre que les fichiers propres). Le FICHIER n'est pas
 * modifié: son md5 sert de clé à la base de durées (songdb). */
static bool uade_is_max_name(const char* path) {
    const char* b = strrchr(path, '/');
    b = b ? b + 1 : path;
#ifdef _WIN32
    const char* bs = strrchr(b, '\\');
    if (bs) b = bs + 1;
#endif
    const size_t n = strlen(b);
    return strncasecmp(b, "max.", 4) == 0 ||
           (n > 4 && strcasecmp(b + n - 4, ".max") == 0);
}

/* L'octet de bourrage, ou 0 quand l'en-tête est propre (le cas courant). */
static unsigned char uade_max_filler(const unsigned char* h, size_t n) {
    if (h == NULL || n < 8) return 0;
    const unsigned char lows[2] = {0x0f, 0x14};
    for (int i = 0; i < 2; i++) {
        const unsigned char* w = h + 4 * i;
        if (w[3] == lows[i] && w[0] != 0 && w[0] == w[1] && w[1] == w[2])
            return w[0];
    }
    return 0;
}

/* Le fichier entier en mémoire, bourrage remis à zéro — NULL si ce n'est pas
 * un Maximum Effect bourré (on ne lit alors que l'en-tête). L'appelant libère. */
static unsigned char* uade_max_unfill(const char* path, size_t* outSize) {
    if (!uade_is_max_name(path)) return NULL;
    FILE* f = fopen(path, "rb");
    if (!f) return NULL;
    unsigned char head[8];
    size_t got = fread(head, 1, sizeof(head), f);
    const unsigned char fill = uade_max_filler(head, got);
    if (fill == 0) { fclose(f); return NULL; }
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return NULL; }
    long size = ftell(f);
    /* Une partition Maximum Effect pèse quelques kilo-octets. */
    if (size < 24 || size > (long)(1024 * 1024)) { fclose(f); return NULL; }
    rewind(f);
    unsigned char* buf = (unsigned char*)malloc((size_t)size);
    if (!buf) { fclose(f); return NULL; }
    if (fread(buf, 1, (size_t)size, f) != (size_t)size) {
        free(buf); fclose(f); return NULL;
    }
    fclose(f);
    for (long o = 0; o + 3 < size; o += 4) {
        if (buf[o] == fill && buf[o + 1] == fill && buf[o + 2] == fill)
            buf[o] = buf[o + 1] = buf[o + 2] = 0;
    }
    *outSize = (size_t)size;
    return buf;
}

/* SoundTracker 2.6 / Ice Tracker (« MTN\0 » ou « IT10 » à l'offset $5b8) —
 * une BOUCLE D'ÉCHANTILLON qui déborde de l'échantillon FIGE le convertisseur.
 *
 * UADE joue ce format par PTK-Prowiz, un binaire 68k qui le CONVERTIT en
 * Protracker dans son InitPlayer, avant que le score ne signale le démarrage
 * audio (`AMIGAMSG_START_OUTPUT`). Sur « Soundtracker 2.6/Starbuck/test.mod »
 * (modland) le sample 2 porte début de boucle 36 + longueur de boucle 14110
 * = 14146 octets pour 14126 de longueur: la conversion ne rend jamais la main
 * (le 68k part écrire des registres au hasard — « blitter stroken »,
 * « dsklen striken » en boucle), uadecore attend son plafond de démarrage
 * puis l'ouverture échoue; `uade123` 3.05 amont fait exactement pareil, et
 * son `-i` n'y change rien puisque ce n'est pas le contrôle qui refuse. Les
 * cinq autres champs suspects du fichier (4 octets de queue, table de
 * positions non vide après la longueur, nom d'instrument mal terminé…) ont
 * été corrigés un à un sans effet; ramener la boucle dans l'échantillon suffit
 * (RMS normal, aucun autre changement). Protracker, libopenmpt et libxmp
 * tolèrent ce débordement en le tronquant: on fait pareil, dans le tampon
 * remis à UADE — le FICHIER n'est pas modifié (son md5 est la clé du songdb).
 * Vérifié sur trois modules ST2.6 propres de modland: aucun champ touché. */
static bool uade_is_st26(const unsigned char* h, size_t n) {
    return h != NULL && n >= 0x5bc &&
           (memcmp(h + 0x5b8, "MTN\0", 4) == 0 || memcmp(h + 0x5b8, "IT10", 4) == 0);
}

/* Le fichier entier, boucles ramenées dans leur échantillon — NULL quand ce
 * n'est pas un ST2.6 ou qu'aucune boucle ne déborde (le cas courant). */
static unsigned char* uade_st26_clamp_loops(const char* path, size_t* outSize) {
    FILE* f = fopen(path, "rb");
    if (!f) return NULL;
    unsigned char head[0x5bc];
    size_t got = fread(head, 1, sizeof(head), f);
    if (!uade_is_st26(head, got)) { fclose(f); return NULL; }
    bool broken = false;
    for (int i = 0; i < 31 && !broken; i++) {
        const unsigned char* s = head + 20 + i * 30;
        const unsigned len = (unsigned)((s[22] << 8) | s[23]);   /* en mots */
        const unsigned rs  = (unsigned)((s[26] << 8) | s[27]);
        const unsigned rl  = (unsigned)((s[28] << 8) | s[29]);
        if (len > 0 && rs + rl > len) broken = true;
    }
    if (!broken) { fclose(f); return NULL; }
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return NULL; }
    long size = ftell(f);
    /* 31 échantillons de 64 Ko au plus, 128 positions, 256 octets par piste. */
    if (size < 0x5bc || size > (long)(4 * 1024 * 1024)) { fclose(f); return NULL; }
    rewind(f);
    unsigned char* buf = (unsigned char*)malloc((size_t)size);
    if (!buf) { fclose(f); return NULL; }
    if (fread(buf, 1, (size_t)size, f) != (size_t)size) {
        free(buf); fclose(f); return NULL;
    }
    fclose(f);
    for (int i = 0; i < 31; i++) {
        unsigned char* s = buf + 20 + i * 30;
        const unsigned len = (unsigned)((s[22] << 8) | s[23]);
        unsigned rs = (unsigned)((s[26] << 8) | s[27]);
        unsigned rl = (unsigned)((s[28] << 8) | s[29]);
        if (len == 0 || rs + rl <= len) continue;
        if (rs >= len) { rs = 0; rl = 1; }      /* début hors échantillon: pas de boucle */
        else rl = len - rs;                     /* boucle tronquée à la fin de l'échantillon */
        s[26] = (unsigned char)(rs >> 8); s[27] = (unsigned char)rs;
        s[28] = (unsigned char)(rl >> 8); s[29] = (unsigned char)rl;
    }
    *outSize = (size_t)size;
    return buf;
}

static int uade_probe(const char* ext, const uint8_t* hdr, size_t n) {
    /* Règle NÉGATIVE, avant tout le reste: `.sng` n'est pas UNE chose. C'est
     * l'extension d'un module ZoundMonitor AMIGA (`eagleplayer.conf`,
     * `prefixes=sng`) — que UADE joue — MAIS aussi celle d'un morceau
     * GoatTracker 2, qui est du C64 et que rien ici ne lit. La magie tranche:
     * `GTS3`/`GTS4`/`GTS5` en tête. Sans ce refus, UADE réclame le fichier par
     * sa seule extension et confie du 6502 au 68k.
     *
     * Mesuré sur la release scene.org « eightbm_tomarkus_chipcompo »: son
     * `.sng` de 21 288 octets est le SOURCE GoatTracker du morceau, dont le
     * `.prg` voisin — 4 200 octets, joué sans broncher par libsidplayfp — est
     * la version exécutable. */
    if (ext && strcasecmp(ext, "sng") == 0 && hdr && n >= 3 &&
        hdr[0] == 'G' && hdr[1] == 'T' && hdr[2] == 'S') {
        return 0;
    }

    /* `.sqt` n'est pas UNE chose non plus: SQ-Tracker sur ZX Spectrum (zxtune,
     * 55 sur la seule extension) MAIS aussi Quartet PSG sur Atari ST
     * (`eagleplayer.conf`: `Quartet_PSG prefixes=sqt`), que seul UADE joue.
     * Le second est du CODE 68000 qui s'ouvre sur une table de sauts —
     * `BRA.W` (`60 00 dddd`) répétés — ce qu'un module ZX, qui commence par
     * des pointeurs little-endian, n'a aucune raison d'avoir deux fois de
     * suite. Mesuré sur « time machine.sqt »: `60 00 02 64 60 00 03 0c …`,
     * joué par uade123 3.05 (replay Quartet_PSG, RMS 6398). 70 > 55. */
    if (ext && strcasecmp(ext, "sqt") == 0 && hdr && n >= 8 &&
        hdr[0] == 0x60 && hdr[1] == 0x00 && hdr[4] == 0x60 && hdr[5] == 0x00) {
        return 70;
    }

    /* `.psf` aussi est double: le Portable Sound Format de la PlayStation
     * (highlyexp, 60 sur la seule extension, 100 avec sa magie « PSF » +
     * version) — et SoundFactory sur Amiga (`SoundFactory prefixes=psf`),
     * que seul UADE joue. Mesuré sur « axelf.psf » (modland): `00 01 3d 67…`,
     * joué par uade123 3.05 (replay SoundFactory, RMS 5235). Tout ce qui
     * commence par « PSF » reste ailleurs — le PSF de Pivotal que vgmstream
     * lit aussi porte cette magie. 70 > 60. */
    if (ext && strcasecmp(ext, "psf") == 0 && hdr && n >= 4 &&
        !(hdr[0] == 'P' && hdr[1] == 'S' && hdr[2] == 'F')) {
        return 70;
    }

    /* BP SoundMon V1: `uade_filemagic` ne connaît pas « BPSM » (ni chez nous ni
     * en amont), donc la détection par contenu ci-dessous le manquerait — et un
     * rip à la mode AMIGA (« BP.morceau ») n'a pas non plus d'extension utile.
     * Même score qu'une extension reconnue: [uade_open] le convertit en V.2. */
    if (uade_is_bpsm_v1(hdr, n)) return 58;

    // 1. Suffix match (covers song.ahx / song.tfmx / …).
    if (ext && rewamp_ext_in_list(ext, kUadeExts)) return 58;
    if (ext && rewamp_ext_in_list(ext, kUadeSharedExts)) return 40;

    // 2. Content detection — catches Amiga *prefix*-convention names ("ahx.song",
    //    "mdat.turrican") whose suffix isn't a format token, by inspecting the
    //    header. uade_filemagic() recognises TFMX/AHX/HIP/FC/… by magic and fills
    //    `pre` with a format token ("" = unknown, "reject" = WAV). We pass no path
    //    (AS/NT sibling probing is skipped safely) and realfilesize == header size,
    //    which makes the size-validated MOD checks bow out — fine, plain MODs route
    //    to libopenmpt by suffix anyway. Score 56: below a suffix/header-confirmed
    //    format plugin, above vgmstream's catch-all (50).
    if (hdr && n > 0) {
        char pre[64] = {0};
        uade_filemagic((unsigned char*)hdr, n, pre, n, "", 0);
        if (pre[0] != '\0' && strcmp(pre, "reject") != 0) return 56;
    }
    return 0;
}

/* Le voisin est-il une vraie TABLE D'INSTRUMENTS de synthèse ?
 *
 * ⚠️ `mod32check` d'amifilemagic conclut « Audio Sculpture » dès qu'un fichier
 * `.as` OU `.nt` EXISTE à côté d'un Startrekker — il ne regarde jamais son
 * contenu. On vérifie donc la MAGIE, mais on accepte les TROIS familles, parce
 * que le player Audio Sculpture d'UADE joue aussi les Startrekker AM: mesuré
 * sur `Startrekker AM/Backlash/war hawk.st1.3.mod` (+ `.nt`, « ST1.3
 * ModuleINFO »), qui tourne 12 s sans un avertissement.
 *
 * N'exiger que « AudioSculpture10 » était une erreur de ma part: ça renvoyait
 * tous les Startrekker AM à libopenmpt, qui les joue SANS leurs instruments de
 * synthèse (il sait les lire, mais seulement sous `MPT_EXTERNAL_SAMPLES` et
 * depuis un CHEMIN — deux choses que la bibliothèque n'offre pas: son API ne
 * transmet jamais de nom de fichier).
 *
 * La magie sert donc seulement à écarter un `.as`/`.nt` qui n'est pas une table
 * du tout. */
static bool uade_companion_is_audiosculpture(const char* path,
                                            char* outComp, size_t outCompSize) {
    if (!path || !path[0]) return false;
    static const char* kSuffixes[] = { ".as", ".AS", ".nt", ".NT" };
    for (size_t i = 0; i < sizeof(kSuffixes) / sizeof(kSuffixes[0]); i++) {
        char cand[4200];
        if (snprintf(cand, sizeof(cand), "%s%s", path, kSuffixes[i]) <= 0)
            continue;
        FILE* f = fopen(cand, "rb");
        if (!f) continue;
        char magic[16] = {0};
        size_t got = fread(magic, 1, sizeof(magic), f);
        fclose(f);
        if (got < sizeof(magic)) continue;
        /* Les TROIS familles, et c'est mesuré:
         *   « AudioSculpture10 » — Audio Sculpture (`NOM.adsc` + `.adsc.as`).
         *   « ST1.2 ModuleINFO » — Startrekker AM 1.2 (`false dreams.mod`).
         *   « ST1.3 ModuleINFO » — Startrekker AM 1.3 (`war hawk.st1.3.mod`).
         * Les deux derniers tournent sans un avertissement sous le player
         * Audio Sculpture d'UADE, alors que libopenmpt les joue SANS leurs
         * instruments de synthèse.
         *
         * N'accepter que « AudioSculpture10 » était une sur-restriction de ma
         * part, prise quand la boucle 68k n'était pas encore bornée: un lecteur
         * parti dans le décor tuait l'app (uadecore est un THREAD chez nous,
         * un sous-processus en amont). Ce garde-fou est maintenant dans
         * `m68k_run_1` — voir `uadecore_pc_is_mapped` — donc un module que le
         * player ne digère pas rend la main au lieu d'emporter le processus.
         *
         * ⚠️ Le sous-chant 1 de `m.mod` (Forni) échoue EN AMONT aussi
         * (« dsklen striken » puis « Invalid event » à 2,4 s, `uade123` 3.05,
         * avec ou sans son `.as`, et même avec celui d'un autre module): c'est
         * une limite du player Amiga, pas un défaut de routage. Ses sept autres
         * sous-chants jouent. */
        bool ok = memcmp(magic, "AudioSculpture", 14) == 0 ||
                  (memcmp(magic, "ST1.", 4) == 0 &&
                   memcmp(magic + 5, " ModuleINFO", 11) == 0);
        if (ok) {
            if (outComp && outCompSize) snprintf(outComp, outCompSize, "%s", cand);
            return true;
        }
    }
    return false;
}


/* Paul Robotham (« space 1889.dat » + « space 1889.ssd », ou la forme
 * préfixe « dat.NOM » + « ssd.NOM ») — un module dont l'identité tient au
 * VOISIN: la partition `.dat` n'a pas de magie que `uade_filemagic` connaisse,
 * et `.dat` est d'abord une extension SID (score 60 sur la seule extension).
 * Sans cette règle le fichier partait chez libsidplayfp, qui le refusait. Le
 * replay `PaulRobotham` d'UADE (`prefixes=dat`) le joue — mesuré avec
 * uade123 3.05: RMS 7378; sans le `.ssd`, « score died ». Un vrai `.dat` SID
 * garde sa place: sa magie PSID/RSID lui vaut 100 chez SID. */
static bool uade_file_exists(const char* p) {
    FILE* f = fopen(p, "rb");
    if (!f) return false;
    fclose(f);
    return true;
}

static bool uade_has_robotham_companion(const char* path) {
    if (!path || !path[0]) return false;
    const char* slash = strrchr(path, '/');
#ifdef _WIN32
    const char* bs = strrchr(path, '\\');
    if (!slash || (bs && bs > slash)) slash = bs;
#endif
    const char* base = slash ? slash + 1 : path;
    const size_t dirLen = (size_t)(base - path);
    const size_t n = strlen(base);
    char cand[4200];
    // Forme suffixe: « NOM.dat » → « NOM.ssd ».
    if (n > 4 && strcasecmp(base + n - 4, ".dat") == 0) {
        static const char* kExt[] = { ".ssd", ".SSD" };
        for (int i = 0; i < 2; i++) {
            snprintf(cand, sizeof(cand), "%.*s%s", (int)(dirLen + n - 4), path, kExt[i]);
            if (uade_file_exists(cand)) return true;
        }
    }
    // Le kit PAR DÉFAUT du replay: faute de « NOM.SSD », le player demande
    // « mdtest.ssd » (vu à uade123 -v: « Amiga requests file: mdtest.ssd »).
    // C'est ce que font les « Ashes of Empire » -auto/-enemy/-land, dont seul
    // -finale a son propre kit.
    const bool isDat = (n > 4 && strcasecmp(base + n - 4, ".dat") == 0) ||
                       (n > 4 && strncasecmp(base, "dat.", 4) == 0);
    if (isDat) {
        static const char* kDef[] = { "mdtest.ssd", "MDTEST.SSD" };
        for (int i = 0; i < 2; i++) {
            snprintf(cand, sizeof(cand), "%.*s%s", (int)dirLen, path, kDef[i]);
            if (uade_file_exists(cand)) return true;
        }
    }
    // Forme préfixe: « dat.NOM » → « ssd.NOM ».
    if (n > 4 && strncasecmp(base, "dat.", 4) == 0) {
        static const char* kPre[] = { "ssd.", "SSD." };
        for (int i = 0; i < 2; i++) {
            snprintf(cand, sizeof(cand), "%.*s%s%s", (int)dirLen, path, kPre[i], base + 4);
            if (uade_file_exists(cand)) return true;
        }
    }
    return false;
}

/* Variante avec le CHEMIN et la TAILLE RÉELLE — voir `probe_path` dans
 * rewamp_plugin.h.
 *
 * Ce que ça débloque: **Audio Sculpture**. C'est un Startrekker dont le SEUL
 * signe distinctif est un fichier voisin `.as` (`NOM.mod` + `NOM.mod.as`).
 * `mod32check` sait déjà le reconnaître — `has_as_or_nt_file(path)` — mais on
 * lui passait un chemin VIDE et une taille égale à l'en-tête, donc la branche
 * n'était jamais atteinte et le fichier partait chez libopenmpt, qui le joue
 * comme un Startrekker ordinaire: les échantillons synthétiques du `.as` sont
 * muets.
 *
 * Le score doit BATTRE libopenmpt (100 quand il confirme un `.mod` par
 * l'en-tête, ce qu'il fait ici puisque c'est un vrai module 31 instruments).
 * On ne monte au-dessus que sur une identification EXPLICITE d'Audio
 * Sculpture — pas sur une reconnaissance UADE quelconque, sinon on volerait
 * tous les MOD à libopenmpt, qui les joue mieux. */
static int uade_probe_path(const char* ext, const uint8_t* hdr, size_t n,
                           const char* path, uint64_t fileSize) {
    if (hdr && n > 0 && path && path[0]) {
        char pre[64] = {0};
        uade_filemagic((unsigned char*)hdr, n, pre,
                       fileSize ? (size_t)fileSize : n, path, 0);
        /* ⚠️ MAJUSCULES: `uade_filemagic` rend le NOM D'ÉNUMÉRATION
         * (« MOD_ADSC4 », table `.str` d'amifilemagic.c), pas le `file_ext`
         * en minuscules qui figure dix lignes plus haut dans le même fichier.
         * Comparé en minuscules, ça ne matchait jamais — et l'échec était
         * SILENCIEUX: on retombait sur `uade_probe`, donc le fichier partait
         * chez libopenmpt exactement comme avant le correctif. */
        if ((strcasecmp(pre, "MOD_ADSC4") == 0 ||
             strcasecmp(pre, "MOD_ADSC8") == 0) &&
            uade_companion_is_audiosculpture(path, NULL, 0))
            return 110;
    }
    /* Au-dessus des 60 que SID donne à la seule extension `.dat`, sous les
     * 100 d'un vrai SID (magie PSID/RSID). */
    if (uade_has_robotham_companion(path)) return 70;
    /* SidMon 1: modland le nomme `NOM.sid`, l'extension du C64 — libsidplayfp
     * en prend 60 sur le seul nom, puis échoue à l'ouvrir faute de magie
     * PSID/RSID. `sid1test` d'amifilemagic suit un `LEA` jusqu'à la chaîne
     * « SID-MON BY R.v.VLIET », qui tombe souvent APRÈS les 2 Ko d'en-tête de
     * la sonde: mesuré sur les 61 fichiers de modland « SidMon 1 », 37 seulement
     * reconnus sur l'en-tête, 61 sur le fichier entier (« synthetic age.sid »
     * parmi les manqués). On relit donc le fichier — seulement pour un `.sid`
     * sans magie C64, donc jamais pour un vrai SID. 70 > 60. */
    if (ext && strcasecmp(ext, "sid") == 0 && path && path[0] && hdr && n >= 4 &&
        memcmp(hdr, "PSID", 4) != 0 && memcmp(hdr, "RSID", 4) != 0 &&
        fileSize > 0 && fileSize <= 4u * 1024 * 1024) {
        FILE* f = fopen(path, "rb");
        if (f) {
            std::vector<unsigned char> buf((size_t)fileSize);
            const size_t got = fread(buf.data(), 1, buf.size(), f);
            fclose(f);
            char pre[64] = {0};
            if (got == buf.size())
                uade_filemagic(buf.data(), got, pre, got, path, 0);
            if (strcasecmp(pre, "SID1") == 0) return 70;
        }
    }
    return uade_probe(ext, hdr, n);
}

/* Instantané des boucles forcées, posé par rewamp_audio.c avant open().
 * 0 = off, 1 = n fois, 2 = infini. */
extern "C" int g_force_loop_mode;

static RewampDecoder* uade_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;
    uade_rewamp_speed = 1.0;   // the producer pushes the speed after open()

    // A dying uadecore write can raise SIGPIPE; ignore it process-wide (the
    // in-process build talks over a socketpair to the uadecore thread).
    // Windows: deux tubes CRT, et une écriture dans un tube refermé y rend une
    // ERREUR (EPIPE/EINVAL), jamais un signal — SIGPIPE n'existe pas.
#ifdef SIGPIPE
    signal(SIGPIPE, SIG_IGN);
#endif

    char clean[4096];
    int subsong = 0;
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strrchr(clean, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) { subsong = atoi(q + 9); *q = '\0'; }

    const char* dataDir = rewamp_get_data_dir();
    if (!dataDir || !dataDir[0]) return NULL;

    char baseDir[4096];
    size_t dl = strlen(dataDir);
    int hasSlash = (dl > 0 && dataDir[dl - 1] == '/');
    snprintf(baseDir, sizeof(baseDir), "%s%suade", dataDir, hasSlash ? "" : "/");

    /* La config est CONSOMMÉE par uade_new_state, donc elle se refabrique à
     * l'identique pour la seconde chance ci-dessous. */
    auto makeState = [&](int ignorePlayerCheck) -> struct uade_state* {
        struct uade_config* uc = uade_new_config();
        if (!uc) return NULL;
        uade_config_set_option(uc, UC_BASE_DIR, baseDir);
        /* Paula filter model: 0 = A500 (library default), 1 = A1200, 2 = none.
         * Initialised per song (UC_FILTER_TYPE). */
        {
            int ft = (int)rewamp_get_engine_param("uade", "filter_type", 0);
            uade_config_set_option(uc, UC_FILTER_TYPE,
                                   ft == 2 ? "none" : (ft == 1 ? "a1200" : "a500"));
        }
        /* LED forced state must also be part of the song config so led_forced is
         * set from the start (live toggles then use uade_set_filter_state). */
        {
            int led = (int)rewamp_get_engine_param("uade", "led", 0);
            if (led != 0)
                uade_config_set_option(uc, UC_FORCE_LED, led == 1 ? "on" : "off");
        }
        if (ignorePlayerCheck)
            uade_config_set_option(uc, UC_IGNORE_PLAYER_CHECK, NULL);
        /* Boucle INFINIE: on ignore la fin annoncée par l'eagleplayer
         * (l'option `-n` d'uade123).
         *
         * Sans ça le décodeur rend « terminé » à la fin de la sous-chanson, le
         * repli générique relance par un seek, et le player — qui a déjà
         * enchaîné en interne — se retrouve AILLEURS: la lecture continue mais
         * sur la sous-chanson SUIVANTE. C'est le symptôme rapporté.
         *
         * Mesuré sur « aquatic games.sng » (modland, Richard Joseph), une seule
         * sous-chanson forcée: sans l'option la piste s'arrête à 30,8 s (RMS
         * 1670); avec, elle tient les 60 s de la mesure (RMS 1659) et la
         * seconde moitié est toujours de la musique (RMS 1661) — même
         * sous-chanson, jouée en boucle par le replayer lui-même, ce qui est
         * exactement ce qu'on demande en repeat infini.
         *
         * ⚠️ Réservé au mode INFINI: en mode normal la fin annoncée est ce qui
         * fait avancer la file, et l'ignorer partout ferait jouer chaque module
         * Amiga pour toujours. L'instantané est pris à l'OUVERTURE, comme tout
         * le reste des boucles forcées. */
        if (g_force_loop_mode == 2)
            uade_config_set_option(uc, UC_NO_EP_END, NULL);
        struct uade_state* s = uade_new_state(uc);
        free(uc);                   // uade_new_state copies the config
        return s;
    };

    /* Modules RÉPARÉS en mémoire avant UADE: BP SoundMon V1 → V.2 (voir
     * [uade_bpsm_v1_to_v2]), Maximum Effect bourré ([uade_max_unfill]) et
     * SoundTracker 2.6 à boucle débordante ([uade_st26_clamp_loops]).
     * NULL pour tout le reste, qui passe par le CHEMIN comme toujours.
     *
     * Les compagnons suivent dans les deux cas: `uade_play_from_buffer` garde
     * le NOM du module (`uade_file(fname, …)`), d'où uadestate.c tire
     * `modulefname` puis le dossier où le player cherche son `SMP.*` —
     * exactement comme `uade_play` (même `uade_play_internal`). */
    size_t patchedSize = 0;
    unsigned char* patched = uade_bpsm_v1_to_v2(clean, &patchedSize);
    if (!patched) patched = uade_max_unfill(clean, &patchedSize);
    if (!patched) patched = uade_st26_clamp_loops(clean, &patchedSize);
    auto playSong = [&](struct uade_state* s) -> int {
        const int sub = subsong > 0 ? subsong : -1;
        return patched ? uade_play_from_buffer(clean, patched, patchedSize, sub, s)
                       : uade_play(clean, sub, s);
    };

    // Per-voice oscilloscope rings: Amiga Paula has 4 hardware voices.
    //
    // ⚠️ AVANT makeState(), pas après uade_play(). uadecore est un FIL, créé
    // par uade_new_state (uade_arch_spawn), et il ÉMULE dès que uade_play lui a
    // remis le module: audio.c::uade_capture_voices() écrit alors dans
    // m_voice_buff[0..3], sans verrou. rewamp_channel_data_reset() LIBÈRE puis
    // réalloue ces tampons — appelée après uade_play, elle tournait EN MÊME
    // TEMPS que le fil, qui écrivait dans un tampon nul ou libéré. Plantage
    // `uade_capture_voices+0x1ab`, écriture à 0x71a, reproduit au harnais en
    // enchaînant les sous-chansons de « mdat.monkey island » (TFMX) avec un
    // visualiseur qui lit les voies; signalé sous Windows, mais la course est la
    // même sur toutes les plateformes. Ici aucun fil uadecore n'existe encore:
    // le décodeur précédent a été fermé (fil rejoint) avant cet open().
    rewamp_channel_data_reset(4);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 4);
    // audio.c's uade_capture_voices() WRAPS m_voice_current_ptr modulo the
    // ring size; without the circular flag ring_read() treats a just-wrapped
    // pointer as "almost nothing written" → the voice scope flashes flat on
    // every ring cycle (~every 0.3s).
    rewamp_channel_data_set_ring_circular(1);

    struct uade_state* st = makeState(0);
    if (!st) { free(patched); return NULL; }

    // subsong=0 means "default subsong" by rewamp convention → pass -1 to UADE.
    int playret = playSong(st);
    if (playret != 1) {             // 0 = unplayable, -1 = fatal
        uade_cleanup_state(st);
        st = NULL;
        /* SECONDE CHANCE: le CONTRÔLE DU PLAYER refuse des fichiers que le
         * player joue parfaitement.
         *
         * Le player 68k vérifie le module avant de le prendre (`EP_Check3`), et
         * ce contrôle est plus strict que le player lui-même. Mesuré sur les 20
         * premiers « Richard Joseph » de modland (paires `NOM.sng` + `NOM.ins`):
         * DIX-NEUF passent, un seul est refusé — « aquatic games » — et il joue
         * 6 sous-chansons parfaitement dès qu'on ignore le contrôle (RMS 1572,
         * identique à ses voisins; sans son `.ins` la sortie est vide, donc le
         * compagnon est bien chargé). `uade123` 3.05 amont échoue exactement
         * pareil, et réussit pareil avec son option `-i`: ce n'est donc pas un
         * défaut de notre portage, et le corriger dans le player demanderait de
         * désassembler un binaire 68k dont l'arbre amont n'a pas la source.
         *
         * ⚠️ Second essai UNIQUEMENT si UADE a RECONNU le contenu: sans cette
         * garde, n'importe quel fichier que la sonde a laissé passer par son
         * extension serait joué en bruit au lieu d'être proprement refusé —
         * `.sng` désigne aussi bien un ZoundMonitor qu'autre chose. */
        char pre[64] = {0};
        FILE* hf = fopen(clean, "rb");
        if (hf) {
            unsigned char hdr[1024];
            size_t got = fread(hdr, 1, sizeof(hdr), hf);
            fclose(hf);
            if (got > 0)
                uade_filemagic(hdr, got, pre, got, clean, 0);
        }
        if (patched || (pre[0] != '\0' && strcmp(pre, "reject") != 0 &&
                     strcmp(pre, "packed") != 0)) {
            st = makeState(1);
            if (st) {
                playret = playSong(st);
                if (playret != 1) {
                    uade_cleanup_state(st);
                    st = NULL;
                }
            }
        }
        if (!st) { free(patched); return NULL; }
    }
    /* UADE a copié ce qu'il lui fallait (« buf can be freed after call »). */
    free(patched);
    patched = NULL;

    int rate = uade_get_sampling_rate(st);
    if (rate <= 0) rate = 44100;

    /* Engine params (Settings → Moteurs → UADE) — also live via
     * uade_param_changed (uade_effect_run sits in the library's own read
     * pipeline, so toggles take effect on the next chunk). */
    uade_apply_engine_params(st);

    // Chip grouping + voice names (the ring buffers were set up before
    // makeState — see above; resetting them here would race uadecore).
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("Paula", 0, 4);
    for (int i = 0; i < 4; i++) {
        char nm[MODIZ_VOICE_NAME_MAX_CHAR];
        snprintf(nm, sizeof(nm), "Voice %d", i + 1);
        rewamp_voice_set_name(i, nm);
    }

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { uade_cleanup_state(st); return NULL; }
    dec->st   = st;
    dec->rate = rate;

    // Info panel: eagleplayer / format / module metadata from libuade.
    {
        const struct uade_song_info* si = uade_get_song_info(st);
        if (si) {
            if (si->modulename[0])
                rewamp_track_message_append("Module: %s\n", si->modulename);
            if (si->formatname[0])
                rewamp_track_message_append("Format: %s\n", si->formatname);
            if (si->playername[0])
                rewamp_track_message_append("Player: %s\n", si->playername);
            if (si->subsongs.max > si->subsongs.min)
                rewamp_track_message_append("Subsongs: %d (%d..%d)\n",
                    si->subsongs.max - si->subsongs.min + 1,
                    si->subsongs.min, si->subsongs.max);
            if (si->modulebytes > 0)
                rewamp_track_message_append("Size: %zu bytes\n",
                                            si->modulebytes);
            if (si->duration > 0.0)
                rewamp_track_message_append("Duration: %d:%02d\n",
                    (int)si->duration / 60, (int)si->duration % 60);
        }
    }

    outFormat->channels   = UADE_CHANNELS;   // 2
    outFormat->sampleRate = (uint32_t)rate;
    return dec;
}

static uint64_t uade_read_frames(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->st || !out || frameCount == 0 || dec->ended) return 0;

    if (frameCount > dec->pcmFrames) {
        free(dec->pcm);
        dec->pcm = (int16_t*)malloc(frameCount * UADE_CHANNELS * sizeof(int16_t));
        dec->pcmFrames = dec->pcm ? frameCount : 0;
    }
    if (!dec->pcm) return 0;

    size_t bytes = (size_t)frameCount * UADE_BYTES_PER_FRAME;
    ssize_t n = uade_read(dec->pcm, bytes, dec->st);
    /* A seek skips at 1× (its byte arithmetic is 1×): the speed comes back
     * once libuade has landed. */
    if (dec->seekPending && !uade_is_seeking(dec->st)) {
        dec->seekPending = 0;
        uade_rewamp_speed = dec->speed > 0.0 ? dec->speed : 1.0;
    }
    /* The player arms its interrupts AFTER open(): a speed accepted then may
     * turn out to be unreachable (TFMX, see uade_set_speed). Hand it back. */
    if (!dec->speedRefused && dec->speed > 0.0 && dec->speed != 1.0 &&
        uade_rewamp_audio_paced()) {
        dec->speedRefused = 1;
        uade_rewamp_speed = 1.0;
        rewamp_speed_renegotiate();
    }
    if (n <= 0) { dec->ended = 1; return 0; }   // 0 = song end, -1 = error

    const int samples = (int)(n / (ssize_t)sizeof(int16_t));
    const float inv = 1.0f / 32768.0f;
    for (int i = 0; i < samples; i++) out[i] = dec->pcm[i] * inv;
    return (uint64_t)(samples / UADE_CHANNELS);
}

static void uade_seek_frames(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->st) return;
    double seconds = (double)frameIndex / (double)dec->rate;
    /* Always: a speed set right after this call must also wait. */
    uade_rewamp_speed = 1.0;
    dec->seekPending = 1;
    if (uade_seek(UADE_SEEK_SONG_RELATIVE, seconds, 0, dec->st) == 0)
        dec->ended = 0;
}

/* Native speed: see uade_rewamp_speed. Refused while a seek is landing. */
static int uade_set_speed(RewampDecoder* dec, double speed) {
    if (!dec || !dec->st || speed < 0.2 || speed > 3.0) return 0;
    /* A replay timed by Paula's audio interrupts (TFMX) ignores CIA, VBlank
     * and CPU alike: claiming the speed would change NOTHING, and the user
     * hears 1x. Refusing hands it to the generic resampler (pitch moves too,
     * but the tempo does). Asked here, after open(): the player has set its
     * interrupts by the time the first block came out. */
    if (speed != 1.0 && (dec->speedRefused || uade_rewamp_audio_paced())) {
        dec->speedRefused = 1;
        dec->speed = 1.0;
        uade_rewamp_speed = 1.0;
        return 0;
    }
    dec->speed = speed;
    if (!dec->seekPending) uade_rewamp_speed = speed;
    return 1;
}

static uint64_t uade_length_frames(RewampDecoder* dec) {
    if (!dec || !dec->st) return 0;
    const struct uade_song_info* si = uade_get_song_info(dec->st);
    if (!si || si->duration <= 0.0) return 0;
    return (uint64_t)(si->duration * (double)dec->rate);
}

static void uade_close(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->st) uade_cleanup_state(dec->st);   // implies uade_stop()
    uade_rewamp_speed = 1.0;
    free(dec->pcm);
    free(dec);
}

/* Live settings change (called under the decode lock). */
static void uade_param_changed(RewampDecoder* dec, const char* key) {
    (void)key;
    if (dec && dec->st) uade_apply_engine_params(dec->st);
}

static const RewampPluginVTable kUadeVTable = {
    "uade",
    uade_probe,
    uade_open,
    uade_read_frames,
    uade_seek_frames,
    uade_length_frames,
    uade_close,
    NULL,                /* configure_loop */
    0,                   /* supportsNativeFadeout */
    "uade",              /* engine_id */
    uade_param_changed,  /* live settings */
    /* ⚠️ Les vtables sont initialisées PAR POSITION: tout champ intercalé doit
     * être énuméré, même à NULL. Un initialiseur trop court ne « saute » pas —
     * il décale, et le compilateur ne le voit que si les types diffèrent (ici
     * il l'a vu; il aurait pu ne pas le voir). */
    NULL,                /* pattern_song_info */
    NULL,                /* pattern_order     */
    NULL,                /* pattern_num_rows  */
    NULL,                /* pattern_get       */
    NULL,                /* pattern_cursor    */
    uade_probe_path,     /* Audio Sculpture: identité portée par un VOISIN */
    0,                   /* noPrefixProbe */
    uade_set_speed,      /* vitesse native (CIA + VBlank) */
};

extern "C" const RewampPluginVTable* rewamp_uade_plugin(void) { return &kUadeVTable; }

#endif /* REWAMP_WITH_UADE */
