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
#include <strings.h>
#include <signal.h>

struct RewampDecoder {
    struct uade_state* st;
    int       rate;
    int16_t*  pcm;        // scratch interleaved int16 stereo
    uint64_t  pcmFrames;
    int       ended;
};

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
    return uade_probe(ext, hdr, n);
}

/* Instantané des boucles forcées, posé par rewamp_audio.c avant open().
 * 0 = off, 1 = n fois, 2 = infini. */
extern "C" int g_force_loop_mode;

static RewampDecoder* uade_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    // A dying uadecore write can raise SIGPIPE; ignore it process-wide (the
    // in-process build talks over a socketpair to the uadecore thread).
    signal(SIGPIPE, SIG_IGN);

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

    /* BP SoundMon V1 → V.2 (voir [uade_bpsm_v1_to_v2]). NULL pour tout le reste,
     * qui continue de passer par le CHEMIN: `uade_play_from_buffer` ne sait pas
     * charger les compagnons d'un format multi-fichiers. */
    size_t bpsmSize = 0;
    unsigned char* bpsm = uade_bpsm_v1_to_v2(clean, &bpsmSize);
    auto playSong = [&](struct uade_state* s) -> int {
        const int sub = subsong > 0 ? subsong : -1;
        return bpsm ? uade_play_from_buffer(clean, bpsm, bpsmSize, sub, s)
                    : uade_play(clean, sub, s);
    };

    struct uade_state* st = makeState(0);
    if (!st) { free(bpsm); return NULL; }

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
        if (bpsm || (pre[0] != '\0' && strcmp(pre, "reject") != 0 &&
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
        if (!st) { free(bpsm); return NULL; }
    }
    /* UADE a copié ce qu'il lui fallait (« buf can be freed after call »). */
    free(bpsm);
    bpsm = NULL;

    int rate = uade_get_sampling_rate(st);
    if (rate <= 0) rate = 44100;

    /* Engine params (Settings → Moteurs → UADE) — also live via
     * uade_param_changed (uade_effect_run sits in the library's own read
     * pipeline, so toggles take effect on the next chunk). */
    uade_apply_engine_params(st);

    // Per-voice oscilloscope + note capture: Amiga Paula has 4 hardware voices.
    // Set up the ring buffers + chip grouping BEFORE the first uade_read() so
    // audio.c's uade_capture_voices() has allocated m_voice_buff[0..3] to write.
    rewamp_channel_data_reset(4);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 4);
    // audio.c's uade_capture_voices() WRAPS m_voice_current_ptr modulo the
    // ring size; without the circular flag ring_read() treats a just-wrapped
    // pointer as "almost nothing written" → the voice scope flashes flat on
    // every ring cycle (~every 0.3s).
    rewamp_channel_data_set_ring_circular(1);
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
    if (n <= 0) { dec->ended = 1; return 0; }   // 0 = song end, -1 = error

    const int samples = (int)(n / (ssize_t)sizeof(int16_t));
    const float inv = 1.0f / 32768.0f;
    for (int i = 0; i < samples; i++) out[i] = dec->pcm[i] * inv;
    return (uint64_t)(samples / UADE_CHANNELS);
}

static void uade_seek_frames(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->st) return;
    double seconds = (double)frameIndex / (double)dec->rate;
    if (uade_seek(UADE_SEEK_SONG_RELATIVE, seconds, 0, dec->st) == 0)
        dec->ended = 0;
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
};

extern "C" const RewampPluginVTable* rewamp_uade_plugin(void) { return &kUadeVTable; }

#endif /* REWAMP_WITH_UADE */
