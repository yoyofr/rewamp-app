// libzxtune plugin — ZX Spectrum / AY / chiptune multi-format player via the
// Modizer-authored ZxTuneWrapper (emscripten/Spectre.h). Compiled only when
// REWAMP_WITH_ZXTUNE is defined.
#ifdef REWAMP_WITH_ZXTUNE

#include "rewamp_plugin.h"

/* Boucle forcée (rewamp_audio.c) — lus à l'open, comme vgmstream. */
extern "C" int g_force_loop_mode;
extern "C" int g_force_loop_native_veto;
#include "rewamp_channel_data.h"   // per-voice oscilloscope buffers (m_voice_buff[*])
#include "ModizerVoicesData.h"     // vgm_last_instr[] (instrument de chaque voie, .chp)

#include "Spectre.h"   // ZxTuneWrapper + SongInfo (libzxtune/emscripten, on the include path)
#include "chp2ym.h"    // libchpconv: .chp (Amstrad CPC ChipTracker) → YM3 conversion

#include <mutex>
#include <vector>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <ctype.h>
#include <string>

static const int ZXTUNE_RATE = 44100;

// Modizer global referenced by zxtune's ym_vtx.cpp for an Amstrad CPC .chp clock
// hack. Set true in zx_open() only when feeding a chp2ym-converted YM3 buffer.
bool mdz_amstrad_cph_hack = false;

struct RewampDecoder {
    ZxTuneWrapper* w;
    int            subsong;     // 0-based (wrapper API is 1-based)
    double         rate;
    int16_t*       pcm;         // scratch stereo int16
    int            pcmFrames;
    int            lastOrder;    // dernière (ordre,ligne) vue (boucle infinie)
    int            lastRow;
    int            cursorMoves;  // 1 dès que (ordre,ligne) a bougé une fois
    int64_t        stalledFrames;// images rendues sans que la LIGNE bouge
    int            ayEmul;       // .ay ZXAYEMUL: code Z80 émulé (vitesse générique)
    // .chp: la chanson CHIPNSFX (grille de motifs) et, par image YM3,
    // l'instrument de chaque voie — voir chp_* plus bas. NULL ailleurs.
    ChpSong*       chp;
    uint8_t*       chpInstr;     // [frames * 3]
};

/* Boucle infinie: au-delà de ce temps rendu SANS que la LIGNE du motif change,
 * le module tourne sur place et on repart du début.
 *
 * ⚠️ Le critère est la (ORDRE, LIGNE), et les deux autres candidats ont été
 * essayés puis écartés, chacun pour une raison mesurée:
 *
 *  • le SILENCE marche mais confond une vraie respiration du morceau avec une
 *    boucle morte — un passage muet de plus de deux secondes se ferait couper;
 *  • la POSITION (`get_current_position`) ne bouge JAMAIS: `Frame()` est un
 *    compteur de TICS, pas un numéro de ligne. Il continue d'avancer pendant
 *    que le module reboucle sur place, donc rien ne se déclenchait.
 *
 * La ligne, elle, distingue exactement les deux cas: un morceau qui se tait
 * continue d'avancer dans son motif; un module qui reboucle sur une région
 * vide reste sur la même ligne. C'est littéralement ce qu'on voit à l'écran —
 * le curseur figé sur la dernière ligne pendant que le temps défile.
 *
 * 0,5 s: une ligne peut légitimement durer plusieurs tics à tempo lent, mais
 * pas un demi-tic de seconde — et surtout, ce seuil ne dit rien du CONTENU
 * musical, contrairement à celui du silence.
 *
 * ⚠️ **Le test ne s'arme qu'après avoir vu le curseur bouger AU MOINS UNE
 * FOIS.** Tous les modules zxtune n'ont pas de motifs: pour un format STREAMÉ
 * (.ym, .vtx, .psg), `streaming.cpp` rend `Position() = 0` et `Line() = 0` en
 * dur, pour toujours. Sans cette garde, le détecteur aurait relancé chacun de
 * ces morceaux toutes les demi-secondes. Un module à motifs, lui, fait bouger
 * son curseur dès les premières lignes. */
static const int64_t ZX_LOOP_STALL_FRAMES = ZXTUNE_RATE / 2;

// ZX Spectrum / AY chiptune formats zxtune owns. Kept to ones not already handled
// by other plugins (libvgm/libgme/openmpt/sid). Registered before vgmstream's
// catch-all but its score (55) loses to format-specific plugins.
static const char* const kZxExts[] = {
    "ay", "ym", "vtx", "psg", "pt1", "pt2", "pt3", "mt3", "stc", "st1", "stp",
    "asc", "sqt", "psc", "gtr", "chi", "dst", "sqd", "str", "dmm",
    "tfc", "tfd", "tfe", "ftc", "psm", "pdt", "chp", "vt2",
    /* E-Tracker (SAM Coupé, SAA1099): le décodeur était VENDORÉ et ENREGISTRÉ
     * depuis le début (cop_supp + devices/saa), seul le routage d'extension
     * manquait — même histoire que le .vt2. zxart sert la famille sous TROIS
     * extensions (.cop, .etc, .saa — vérifié sur le catalogue: son format
     * `cop` couvre les trois), et l'identité se confirme au CONTENU par le
     * décodeur lui-même: une extension usurpée échoue à l'open() et retombe.
     * Capture scope/notes/motifs: VÉRIFIÉE sur un .etc réel — le collecteur
     * de motifs passe par CreateTrackStateIterator (le point unique des 18
     * lecteurs, cop_supp compris) et la capture par voix couvre aussi le
     * SAA, pas seulement l'AY de psg.h. */
    "cop", "etc", "saa",
    /* MultiTrackContainer (magie "MTC1", outil mtctool): plusieurs modules de
     * formats zxtune INTERNES joues ENSEMBLE (fusion multi-device, le plus
     * long fait la duree) — un .mtc = UN morceau, PAS des sous-chansons.
     * Limite assumee: seuls les formats de notre set curate s'ouvrent a
     * l'interieur (AY/tracker/TFM/SAA/DAC); un MTC-SID resterait muet. */
    "mtc",
    /* .mct: renommage vu sur zxart ("200%", Xenium 2024 — magie MTC1). La
     * sonde native attrape la magie quel que soit le nom; l'alias sert aux
     * portes DART (jouabilite par extension, palier de format). */
    "mct",
    /* Disquettes TR-DOS (.trd image brute, .scl compactée): le lecteur de
     * conteneurs de zxtune (formats/archived/trd.cpp, scl.cpp) y cherche les
     * modules, chacun devient une sous-chanson (sonde ci-dessous). Les décodeurs
     * étaient compilés depuis le début, seul le routage manquait. Une disquette
     * qui ne porte qu'un PROGRAMME (musique beeper: BASIC + code) n'a aucun
     * module: open() échoue, comme pour tout fichier que zxtune ne reconnaît
     * pas. Mesuré 2026-11-05 sur scene.org: nes.trd (DiHalt 2011) et
     * hypno_.scl (Paradigmus 2003) jouent; gnampf.trd et BeepsEra.scl non. */
    "trd", "scl", NULL
};

static int zx_probe(const char* ext, const uint8_t* hdr, size_t n) {
    /* La magie "MTC1" AVANT la porte d'extension: zxart sert des fichiers mal
     * nommes (.mct vu en prod, magie MTC1 a l'interieur) et une magie de
     * conteneur dedie vaut plus qu'un suffixe. Score 101 = confirme par
     * l'en-tete, passe devant le fourre-tout vgmstream quel que soit le nom. */
    if (hdr && n >= 4 && memcmp(hdr, "MTC1", 4) == 0) return 101;
    if (!ext || !rewamp_ext_in_list(ext, kZxExts)) return 0;
    // An .ay is claimed by libgme too, and libgme wins on score (100: extension
    // plus a header it identifies). For the variant zxtune actually supports we
    // want zxtune instead — it is the native ZX engine, it exposes the file's
    // several tunes, and it is the only one of the two that can show notes and
    // patterns for AY. Same idiom as NEZ over GME on .hes and KSS over GME on
    // .kss: an ext-only score cannot beat a header match, so confirm the header
    // here and outbid by one.
    //
    // Strictly ZXAYEMUL: zxtune's own parser says "only one type is supported
    // now", and a ZXAYAMAD file does fail to open — measured on one in the
    // corpus. Leaving those at 55 keeps them with libgme, which plays them.
    if (strcasecmp(ext, "ay") == 0) {   /* the registry lowercases, but do not rely on it */
        if (hdr && n >= 8 && memcmp(hdr, "ZXAYEMUL", 8) == 0) return 101;
    }
    return 55;
}

// ── En-tête texte des .chp (CHIPNSFX) ───────────────────────────────────────
// Un .chp est un TEXTE: « CHIPNSFX format », le TITRE, la DESCRIPTION (« by
// CNGSOFT after Ben Daglish » sur 805 des 808 fichiers de la distribution),
// une ligne « === », puis « hertz/diviseur ±transposition » (loadsong() de
// CHIPNSFX.C). La conversion en YM3 pour zxtune les PERD — le YM3 n'a aucun
// champ de titre —, d'où un panneau ⓘ vide et le nom de fichier comme titre.
// ⚠️ Encodage DOS CP437, pas Latin-1: 0x81 = ü (« Markus Müller »), 0xA2 = ó
// (« Mortadelo & Filemón »). Un texte déjà en UTF-8 valide passe tel quel.
static void chp_cp437_to_utf8(const std::string& in, std::string& out) {
    static const uint16_t hi[128] = {
        0x00C7,0x00FC,0x00E9,0x00E2,0x00E4,0x00E0,0x00E5,0x00E7,0x00EA,0x00EB,0x00E8,0x00EF,0x00EE,0x00EC,0x00C4,0x00C5,
        0x00C9,0x00E6,0x00C6,0x00F4,0x00F6,0x00F2,0x00FB,0x00F9,0x00FF,0x00D6,0x00DC,0x00A2,0x00A3,0x00A5,0x20A7,0x0192,
        0x00E1,0x00ED,0x00F3,0x00FA,0x00F1,0x00D1,0x00AA,0x00BA,0x00BF,0x2310,0x00AC,0x00BD,0x00BC,0x00A1,0x00AB,0x00BB,
        0x2591,0x2592,0x2593,0x2502,0x2524,0x2561,0x2562,0x2556,0x2555,0x2563,0x2551,0x2557,0x255D,0x255C,0x255B,0x2510,
        0x2514,0x2534,0x252C,0x251C,0x2500,0x253C,0x255E,0x255F,0x255A,0x2554,0x2569,0x2566,0x2560,0x2550,0x256C,0x2567,
        0x2568,0x2564,0x2565,0x2559,0x2558,0x2552,0x2553,0x256B,0x256A,0x2518,0x250C,0x2588,0x2584,0x258C,0x2590,0x2580,
        0x03B1,0x00DF,0x0393,0x03C0,0x03A3,0x03C3,0x00B5,0x03C4,0x03A6,0x0398,0x03A9,0x03B4,0x221E,0x03C6,0x03B5,0x2229,
        0x2261,0x00B1,0x2265,0x2264,0x2320,0x2321,0x00F7,0x2248,0x00B0,0x2219,0x00B7,0x221A,0x207F,0x00B2,0x25A0,0x00A0,
    };
    // UTF-8 valide (un fichier réenregistré par un éditeur moderne)?
    bool utf8 = true;
    for (size_t i = 0; i < in.size() && utf8;) {
        const uint8_t c = (uint8_t)in[i];
        const size_t n = c < 0x80 ? 0 : (c & 0xE0) == 0xC0 ? 1 : (c & 0xF0) == 0xE0 ? 2 : (c & 0xF8) == 0xF0 ? 3 : 4;
        if (n == 4 || i + n >= in.size() + (n ? 0 : 1)) { utf8 = false; break; }
        for (size_t k = 1; k <= n; k++)
            if (((uint8_t)in[i + k] & 0xC0) != 0x80) { utf8 = false; break; }
        i += n + 1;
    }
    if (utf8) { out = in; return; }
    out.clear();
    for (unsigned char c : in) {
        const uint32_t u = c < 0x80 ? c : hi[c - 0x80];
        if (u < 0x80) out += (char)u;
        else if (u < 0x800) { out += (char)(0xC0 | (u >> 6)); out += (char)(0x80 | (u & 0x3F)); }
        else { out += (char)(0xE0 | (u >> 12)); out += (char)(0x80 | ((u >> 6) & 0x3F)); out += (char)(0x80 | (u & 0x3F)); }
    }
}

struct ChpHeader {
    std::string title, desc;
    int hertz = 0, divisor = 0;
    std::vector<std::pair<int, std::string>> instruments;   // (n°, nom), ordre du fichier
};

// Tout le fichier: l'en-tête en tête, la table des INSTRUMENTS en fin
// (« :01 EFE2 0000 077 Chan1 Beep7 » = n°, deux enveloppes, fréquence, puis le
// NOM, espaces compris — loadsong() de CHIPNSFX.C).
static bool chp_read_header(const char* path, ChpHeader& h) {
    FILE* f = fopen(path, "rb");
    if (!f) return false;
    std::vector<std::string> lines;
    char buf[1024];
    while (lines.size() < 20000 && fgets(buf, sizeof buf, f)) {
        std::string l(buf);
        while (!l.empty() && (l.back() == '\n' || l.back() == '\r')) l.pop_back();
        lines.push_back(l);
    }
    fclose(f);
    if (lines.size() < 3) return false;
    std::string id = lines[0];
    if (id.size() >= 3 && (uint8_t)id[0] == 0xEF && (uint8_t)id[1] == 0xBB && (uint8_t)id[2] == 0xBF) id.erase(0, 3);
    if (id != "CHIPNSFX format") return false;
    chp_cp437_to_utf8(lines[1], h.title);
    chp_cp437_to_utf8(lines[2], h.desc);
    if (lines.size() >= 5) sscanf(lines[4].c_str(), "%d/%d", &h.hertz, &h.divisor);
    for (size_t k = 5; k < lines.size(); k++) {
        const std::string& l = lines[k];
        if (l.empty() || l[0] != ':') continue;
        unsigned no, a, b, c; int used = 0;
        if (sscanf(l.c_str() + 1, "%x %x %x %x%n", &no, &a, &b, &c, &used) != 4) continue;
        if (no == 0 || no > 255) continue;
        size_t at = 1 + (size_t)used;
        while (at < l.size() && l[at] == ' ') at++;
        std::string name;
        chp_cp437_to_utf8(l.substr(at), name);
        h.instruments.emplace_back((int)no, name);
    }
    return true;
}

// Les tags structurés. La ligne de titre suit un motif constant dans la
// distribution (808 fichiers): « "Jeu" partie année éditeur » — « "Zub"
// in-game 1987 Mastertronic », « "Mechanicus" (main menu) 1991 Game On ».
// TITRE = « Jeu – partie » (la partie est ce qui DISTINGUE les morceaux d'un
// même jeu), ALBUM = le jeu, ARTISTE = la description sans son « by »
// (« CNGSOFT after Ben Daglish »: l'arrangeur ET le compositeur d'origine,
// tels que le fichier les crédite). Sans guillemets, la ligne entière.
static std::string chp_trim(const std::string& x) {
    size_t a = 0, b = x.size();
    while (a < b && x[a] == ' ') a++;
    while (b > a && x[b - 1] == ' ') b--;
    return x.substr(a, b - a);
}

static void chp_publish(const ChpHeader& h) {
    std::string title = h.title, album;
    const size_t q1 = h.title.find('"');
    const size_t q2 = q1 == std::string::npos ? q1 : h.title.find('"', q1 + 1);
    if (q2 != std::string::npos && q2 > q1 + 1) {
        album = h.title.substr(q1 + 1, q2 - q1 - 1);
        std::string rest = h.title.substr(q2 + 1);
        // La partie s'arrête à l'ANNÉE (19xx / 20xx, mot entier).
        size_t cut = rest.size();
        for (size_t k = 0; k + 4 <= rest.size(); k++) {
            const bool start = k == 0 || rest[k - 1] == ' ';
            const bool end = k + 4 == rest.size() || rest[k + 4] == ' ' || rest[k + 4] == ',';
            if (start && end && (rest.compare(k, 2, "19") == 0 || rest.compare(k, 2, "20") == 0) &&
                isdigit((unsigned char)rest[k + 2]) && isdigit((unsigned char)rest[k + 3])) { cut = k; break; }
        }
        std::string part = chp_trim(rest.substr(0, cut));
        if (part.size() >= 2 && part.front() == '(' && part.back() == ')') part = part.substr(1, part.size() - 2);
        title = part.empty() ? album : album + " \u2013 " + part;
    }
    std::string artist = h.desc;
    if (artist.size() > 3 && strncasecmp(artist.c_str(), "by ", 3) == 0) artist.erase(0, 3);
    rewamp_track_tag_set(title.empty() ? nullptr : title.c_str(),
                         artist.empty() ? nullptr : artist.c_str(),
                         album.empty() ? nullptr : album.c_str());
    if (!h.title.empty()) rewamp_track_message_append("Title: %s\n", h.title.c_str());
    if (!h.desc.empty())  rewamp_track_message_append("Description: %s\n", h.desc.c_str());
    if (h.hertz > 0)
        rewamp_track_message_append(h.divisor > 1 ? "Clock: %d Hz / %d\n" : "Clock: %d Hz\n", h.hertz, h.divisor);
    rewamp_track_message_append("Program: CHIPNSFX\n");
    // Liste dans le panneau ⓘ, comme la liste d'instruments d'un module. Les
    // noms nomment aussi les voix des viz (zx_open: rewamp_instrument_set_name,
    // et l'instrument de chaque voie posé à la lecture, chp_instrument_track).
    if (!h.instruments.empty()) {
        rewamp_track_message_append("\nInstruments:\n");
        for (const auto& in : h.instruments)
            rewamp_track_message_append("%02X: %s\n", in.first, in.second.c_str());
    }
}

// ── Grille de motifs des .chp ────────────────────────────────────────────────
// zxtune joue un YM3 (registres seuls), sans motifs: la grille vient de la
// chanson CHIPNSFX elle-même (chp2ym_song). UN motif générique par LIGNE
// D'ORDRE — chaque voie y désigne son propre score, avec sa transposition —,
// trois voies, longueur = le score de la voie C (c'est lui qui fait avancer
// l'ordre, snd_frame de chp2ym.c). Le curseur et l'instrument de chaque voie
// sont lus par IMAGE YM3, telles que le rejeu de conversion les a vues.

// Image YM3 en cours, boucle comprise: `Frame()` continue de compter après la
// reprise (voir ZX_LOOP_STALL_FRAMES), le YM3b reprend à loop_frame.
static int chp_frame_now(const RewampDecoder* dec) {
    const ChpSong* c = dec->chp;
    long f = (long)dec->w->get_current_position() / 20;   // ms, 50 Hz nominaux
    if (f < 0) f = 0;
    if (f >= c->frames) {
        const long lp = c->loop_frame > 0 && c->loop_frame < c->frames ? c->loop_frame : 0;
        f = lp + (f - lp) % (c->frames - lp);
    }
    return (int)f;
}

// Instrument de chaque voie à chaque image: le dernier déclenché (une note
// AVEC instrument), 0 après un silence « ^^^ ». Une note sans instrument est
// un portamento: l'instrument ne change pas.
static uint8_t* chp_instrument_track(const ChpSong* c) {
    uint8_t* t = (uint8_t*)calloc((size_t)c->frames * 3, 1);
    if (!t) return NULL;
    uint8_t cur[3] = {0, 0, 0};
    int lo = -1, lr = -1;
    for (int f = 0; f < c->frames; f++) {
        const int o = c->cur_order[f], r = c->cur_row[f];
        if ((o != lo || r != lr) && o >= 0 && o < c->orders && r >= 0) {
            for (int ch = 0; ch < 3; ch++) {
                const int p = c->order[ch][o][0];
                if (r >= c->scrln[p]) continue;
                const int n = c->score[p][r][0], ins = c->score[p][r][1];
                if (n == 112) cur[ch] = 0;
                else if (n >= 1 && n <= 109 && ins) cur[ch] = (uint8_t)ins;
            }
            lo = o; lr = r;
        }
        memcpy(t + (size_t)f * 3, cur, 3);
    }
    return t;
}

static int chp_pattern_song_info(const ChpSong* c, RewampPatternSongInfo* out) {
    memset(out, 0, sizeof(*out));
    out->num_channels = 3;
    out->num_orders   = c->orders;
    out->num_patterns = c->orders;   // un motif par ligne d'ordre
    out->max_fx_cols  = 0;
    out->instr_digits = 2;
    // Ni volume ni effets dans une cellule CHIPNSFX (« A-4:01 »): colonnes
    // RETIRÉES (largeur négative), pas dessinées en points.
    out->vol_chars    = -1;
    out->fxcode_chars = -1;
    out->fxval_digits = -1;
    return c->orders > 0;
}

static int chp_pattern_rows(const ChpSong* c, int o) {
    if (o < 0 || o >= c->orders) return 0;
    return c->scrln[c->order[2][o][0]];
}

static int chp_pattern_get(const ChpSong* c, int o, RewampPatternCell* out, int maxCells) {
    const int rows = chp_pattern_rows(c, o);
    int n = rows * 3;
    if (n > maxCells) n = maxCells - maxCells % 3;
    for (int i = 0; i < n; i++) {
        const int r = i / 3, ch = i % 3;
        RewampPatternCell& cell = out[i];
        memset(&cell, 0, sizeof(cell));
        cell.note = REWAMP_NOTE_EMPTY;
        cell.instrument = -1;
        cell.volume = -1;
        for (int k = 0; k < REWAMP_PATTERN_MAX_FX; k++) cell.fxval[k] = -1;
        const int p = c->order[ch][o][0];
        if (r >= c->scrln[p]) continue;
        const int nt = c->score[p][r][0], ins = c->score[p][r][1];
        if (nt >= 1 && nt <= 108) {
            // La note ENTENDUE: transpositions du morceau et de l'ordre comprises.
            int v = nt - 1 + c->transpose + (signed char)c->order[ch][o][1];
            cell.note = (int16_t)(v < 0 ? 0 : v > 107 ? 107 : v);
            if (ins) cell.instrument = ins;
        } else if (nt == 109) {
            // SFX (bruitage de l'instrument, sans hauteur): le tracker l'écrit
            // « C-9 », la note juste au-dessus de B-8 (musical() de CHIPNSFX.C).
            cell.note = 108;
            if (ins) cell.instrument = ins;
        } else if (nt == 110) {
            cell.note = REWAMP_NOTE_OFF;   // « === » frein
        } else if (nt == 112) {
            cell.note = REWAMP_NOTE_CUT;   // « ^^^ » silence
        }
    }
    return n;
}

static void chp_pattern_cursor(const RewampDecoder* dec, int* order, int* row) {
    const int f = chp_frame_now(dec);
    if (order) *order = dec->chp->cur_order[f];
    if (row)   *row   = dec->chp->cur_row[f];
}

static RewampDecoder* zx_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    char clean[4096];
    int subsong = 0;
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strrchr(clean, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) { subsong = atoi(q + 9); *q = '\0'; }

    // .chp (Amstrad CPC ChipTracker) is not a native zxtune format: convert it to
    // an in-memory YM3 buffer via libchpconv first, and enable ym_vtx.cpp's clock
    // hack. Every other format is read straight from disk.
    const char* dot = strrchr(clean, '.');
    const int isChp = (dot && strcasecmp(dot, ".chp") == 0);

    void* data = NULL;
    long  len  = 0;
    ChpSong* chpSong = NULL;
    if (isChp) {
        uint8_t* ym = NULL;
        chpSong = (ChpSong*)calloc(1, sizeof(ChpSong));
        int ymLen = chpSong ? chp2ym_song(clean, &ym, chpSong) : chp2ym(clean, &ym);
        if (ymLen <= 0 || !ym) { free(ym); free(chpSong); return NULL; }
        data = ym;
        len  = ymLen;
        mdz_amstrad_cph_hack = true;
    } else {
        FILE* f = fopen(clean, "rb");
        if (!f) return NULL;
        fseek(f, 0, SEEK_END);
        len = ftell(f);
        fseek(f, 0, SEEK_SET);
        if (len <= 0) { fclose(f); return NULL; }
        data = malloc((size_t)len);
        if (!data) { fclose(f); return NULL; }
        size_t got = fread(data, 1, (size_t)len, f);
        fclose(f);
        if (got != (size_t)len) { free(data); return NULL; }
        mdz_amstrad_cph_hack = false;
    }

    const int ayEmul = len >= 8 && memcmp(data, "ZXAYEMUL", 8) == 0;
    ChpHeader chpHdr;
    bool chpHdrOk = false;
    ZxTuneWrapper* w = NULL;
    try {
        w = new ZxTuneWrapper(std::string(clean), data, (size_t)len, ZXTUNE_RATE);
        w->parseModules();
        SongInfo info;
        w->get_song_info((unsigned)(subsong + 1), info);
        w->decodeInitialize((unsigned)(subsong + 1), info);
        // Info panel: zxtune module metadata. Un .chp converti n'en a aucune
        // (YM3): son en-tête TEXTE la remplace (chp_read_header).
        if (isChp && (chpHdrOk = chp_read_header(clean, chpHdr))) chp_publish(chpHdr);
        else {
            const char* v;
            v = info.get_title();
            if (v && v[0]) rewamp_track_message_append("Title: %s\n", v);
            v = info.get_author();
            if (v && v[0]) rewamp_track_message_append("Author: %s\n", v);
            v = info.get_program();
            if (v && v[0]) rewamp_track_message_append("Program: %s\n", v);
            v = info.get_codec();
            if (v && v[0]) rewamp_track_message_append("Codec: %s\n", v);
            v = w->get_system_name();
            if (v && v[0]) rewamp_track_message_append("System: %s\n", v);
            v = info.get_comment();
            if (v && v[0]) rewamp_track_message_append("\n%s\n", v);
        }
        // Allocate the per-voice oscilloscope ring buffers BEFORE the first render:
        // zxtune's chip cores (aym_base/dac_base/… via mdz_update_voice) write into
        // m_voice_buff[*] as a side effect of rendering, with no NULL guard, so the
        // buffers must exist or render_sound crashes on frame one. decodeInitialize
        // only seeks to 0 (no render), so resetting here is correctly ordered.
        int nch = w->get_channels_count();
        if (nch < 1)   nch = 1;
        if (nch > 256) nch = 256;   // SOUND_MAXVOICES_BUFFER_FX
        rewamp_channel_data_reset(nch);
        // zxtune's cores write the scope ring with mask &(SOUND_BUFFER_SIZE_SAMPLE
        // *4*2-1) (devices/details/renderers.h, dac.cpp), the libvgm/openmpt size —
        // not the libgme *4*4 default. The cores WRAP the write pointer modulo the
        // ring, so the reader must be circular or the scope flashes flat right
        // after every wrap (same bug as UADE).
        rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);
        rewamp_channel_data_set_ring_circular(1);
        // Voice metadata for the mute/grouping UI. zxtune's cores already honor
        // generic_mute_mask during render (devices/details/renderers.h), so
        // only the names/grouping need registering: system name + hardware
        // channel names straight from the renderer (one flat group — zxtune's
        // public surface has no per-chip breakdown; Modizer did the same).
        rewamp_voices_meta_reset();
        const char* sysName = w->get_system_name();
        rewamp_voices_add_chip((sysName && sysName[0]) ? sysName : "ZX", 0, nch);
        for (int i = 0; i < nch; i++) {
            const char* cn = w->get_channel_name(i);
            if (cn && cn[0]) rewamp_voice_set_name(i, cn);
        }
    } catch (...) {
        free(data);
        if (w) delete w;
        if (chpSong) { chp_song_free(chpSong); free(chpSong); }
        return NULL;
    }
    free(data);   // wrapper copies what it needs

    /* Mode 1 (N boucles): pas de compte natif chez ce zxtune — veto, le
     * générique Dart compte les passes (voir zx_configure_loop). */
    if (g_force_loop_mode == 1) g_force_loop_native_veto = 1;

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) {
        delete w;
        if (chpSong) { chp_song_free(chpSong); free(chpSong); }
        return NULL;
    }
    dec->w         = w;
    if (chpSong && chpSong->frames > 0) {
        dec->chp = chpSong;
        dec->chpInstr = chp_instrument_track(chpSong);
        // Les noms, APRÈS rewamp_voices_meta_reset (posé avec les voix, plus
        // haut), qui les effacerait.
        if (chpHdrOk)
            for (const auto& in : chpHdr.instruments)
                if (!in.second.empty()) rewamp_instrument_set_name(in.first, in.second.c_str());
    } else if (chpSong) {
        chp_song_free(chpSong);
        free(chpSong);
    }
    dec->ayEmul    = ayEmul;
    dec->subsong   = subsong;
    dec->rate      = ZXTUNE_RATE;
    dec->pcm       = NULL;
    dec->pcmFrames = 0;
    /* -2 et non 0: `calloc` donne 0, et (ordre 0, ligne 0) est un état RÉEL —
     * la toute première comparaison se croirait bloquée. -2 ne peut être ni
     * une ligne valide ni le -1 que `pattern_cursor` rend quand il ne sait
     * pas. */
    dec->lastOrder = -2;
    dec->lastRow   = -2;

    outFormat->channels   = 2;                 // wrapper renders stereo
    outFormat->sampleRate = (uint32_t)ZXTUNE_RATE;
    return dec;
}

/* Pour le harnais (scripts/verify_zxtune_voices.cpp): le wrapper d'un
 * décodeur ouvert. Linkage C++ (le type est C++), jamais exporté. */
ZxTuneWrapper* rewamp_zxtune_wrapper_of(RewampDecoder* dec) { return dec ? dec->w : NULL; }

static uint64_t zx_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->w || !out || frameCount == 0) return 0;

    if ((int)frameCount > dec->pcmFrames) {
        free(dec->pcm);
        dec->pcm = (int16_t*)malloc(frameCount * 2 * sizeof(int16_t));
        dec->pcmFrames = (int)frameCount;
    }
    if (!dec->pcm) return 0;

    int rendered = dec->w->render_sound(dec->pcm, (size_t)frameCount);

    /* ⚠️ **`Sound::LOOPED` peut « boucler » sur RIEN.** Il reboucle au point de
     * boucle du module, et quand ce point tombe dans une queue morte le
     * renderer continue de rendre — indéfiniment, sans avancer et sans un son.
     * Vu de l'utilisateur: le temps défile, le curseur de motif reste figé sur
     * la dernière ligne. Mesuré sur « touchingthedew_6ch.vt2 ».
     *
     * Et comme on annonce cette boucle comme NATIVE, le repli générique de
     * Dart est désarmé. Le filet doit donc vivre ici.
     *
     * Il ne teste PAS `rendered <= 0` (le rendu continue), NI le silence (un
     * morceau a le droit de se taire), NI la position (elle avance quand
     * même): il teste que la LIGNE du motif ne change plus. Voir
     * ZX_LOOP_STALL_FRAMES. */
    if (rendered > 0 && g_force_loop_mode == 2) {
        int o = -1, r = -1;
        dec->w->pattern_cursor(&o, &r);
        if (o != dec->lastOrder || r != dec->lastRow) {
            /* Le curseur bouge: ce module a bien un modèle de motif, le test
             * devient valide pour lui (voir ZX_LOOP_STALL_FRAMES). */
            if (dec->lastOrder != -2) dec->cursorMoves = 1;
            dec->lastOrder = o;
            dec->lastRow   = r;
            dec->stalledFrames = 0;
        } else if (dec->cursorMoves) {
            dec->stalledFrames += rendered;
            if (dec->stalledFrames >= ZX_LOOP_STALL_FRAMES) {
                dec->stalledFrames = 0;
                dec->w->seek_position(0);   /* millisecondes, comme zx_seek */
                dec->w->pattern_cursor(&dec->lastOrder, &dec->lastRow);
                rendered = dec->w->render_sound(dec->pcm, (size_t)frameCount);
            }
        }
    }

    if (rendered <= 0) {
        /* ⚠️ **`Sound::LOOPED` ne suffit pas.** On annonce la boucle infinie
         * comme NATIVE (voir zx_configure_loop), ce qui DÉSARME le repli
         * générique de Dart: si le module ne reboucle pas, plus rien ne le
         * relance et la piste s'arrête. Mesuré sur
         * « touchingthedew_6ch.vt2 »: `natifRetenu=true`, LOOPED posé, et le
         * rendu s'arrête quand même — tous les modules zxtune n'honorent pas
         * ce paramètre (le décodeur Vortex TEXTE en particulier).
         *
         * Filet: quand le rendu se tarit en mode INFINI, on repart de zéro et
         * on réessaie une fois. Inerte pour les modules dont LOOPED marche —
         * ils ne rendent jamais 0 — et une relance au début vaut infiniment
         * mieux qu'un silence. */
        if (g_force_loop_mode != 2) return 0;
        dec->stalledFrames = 0;
        dec->w->seek_position(0);
        rendered = dec->w->render_sound(dec->pcm, (size_t)frameCount);
        if (rendered <= 0) return 0;
    }

    // .chp: l'instrument de chaque voie, lu par les viz (vgm_last_instr[] ↔
    // rewamp_notes, piano, oscilloscopes) au rythme du producteur.
    if (dec->chp && dec->chpInstr) {
        const uint8_t* t = dec->chpInstr + (size_t)chp_frame_now(dec) * 3;
        for (int ch = 0; ch < 3; ch++) vgm_last_instr[ch] = t[ch];
    }

    const int samples = rendered * 2;
    const float inv = 1.0f / 32768.0f;
    for (int i = 0; i < samples; i++) out[i] = dec->pcm[i] * inv;
    return (uint64_t)rendered;
}

static void zx_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->w) return;
    dec->stalledFrames = 0;   /* un seek repart d'un endroit qui progresse */
    dec->w->seek_position((int)(frameIndex * 1000 / (uint64_t)dec->rate));
    dec->w->pattern_cursor(&dec->lastOrder, &dec->lastRow);
}

static uint64_t zx_length(RewampDecoder* dec) {
    if (!dec || !dec->w) return 0;
    int ms = dec->w->get_max_position();
    if (ms <= 0) return 0;
    return (uint64_t)((double)ms * dec->rate / 1000.0);
}

/* Boucle FORCÉE (Réglages → Lecture / bouton repeat). zxtune boucle
 * NATIVEMENT au point de boucle du module (`Sound::LOOPED`, un paramètre
 * DYNAMIQUE relu par le renderer — donc applicable ici, après l'open) — c'est
 * ce que le repli générique ne peut pas faire: sa relance repart du DÉBUT et
 * s'entend (rapporté sur un .ay, « Midnight Resistance », en repeat-piste).
 *
 * Seul l'INFINI (mode 2) est natif: ce zxtune n'a pas de compte de boucles,
 * donc un mode 1 (N passes) pose le VETO et laisse le générique Dart compter —
 * comportement inchangé pour lui. */
static void zx_configure_loop(RewampDecoder* dec, int mode, int count) {
    (void)count;
    if (!dec || !dec->w) return;
    dec->w->setLoopMode(mode == 2 ? 1 : 0);
}

static void zx_close(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->w) delete dec->w;
    if (dec->chp) { chp_song_free(dec->chp); free(dec->chp); }
    free(dec->chpInstr);
    free(dec->pcm);
    free(dec);
}


// ── subsong probe ───────────────────────────────────────────────────────────
//
// An .ay is a CONTAINER: its header carries a table of tunes, and a real one on
// disk holds eleven. Nothing exposed them — rewamp_probe_subsong_count had no
// zxtune branch, so the whole file came out as a single track and only tune 1
// was ever reachable. (A CATALOGUED file escaped that: the server's
// subsong_count routed it to the container screen and ?subsong=N worked, which
// the plugin has always honoured.)
//
// Claimed ONLY when zxtune finds MORE than one module. That is what makes the
// branch safe to put ahead of libgme's: a single-module file falls straight
// through, so every format another engine owns is untouched, and an .ay variant
// zxtune cannot parse (only ZXAYEMUL is supported — ZXAYAMAD is not) fails to
// open here and is left to libgme.

static std::string      s_probe_path;
static std::vector<std::string> s_probe_titles;

extern "C" int rewamp_zxtune_probe_subsong_count(const char* path) {
    if (!path) return 0;
    const char* dot = strrchr(path, '.');
    if (!dot || !rewamp_ext_in_list(dot + 1, kZxExts)) return 0;

    FILE* f = fopen(path, "rb");
    if (!f) return 0;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0) { fclose(f); return 0; }
    std::vector<uint8_t> data((size_t)len);
    const size_t got = fread(data.data(), 1, (size_t)len, f);
    fclose(f);
    if (got != (size_t)len) return 0;

    int count = 0;
    s_probe_titles.clear();
    try {
        ZxTuneWrapper w(std::string(path), data.data(), (size_t)len, ZXTUNE_RATE);
        w.parseModules();
        SongInfo info;
        // The wrapper only reports the total through a module's info, so ask the
        // first one and then read each title.
        w.get_song_info(1, info);
        const char* total = info.get_total_tracks();
        count = total ? atoi(total) : 0;
        for (int i = 0; i < count; i++) {
            SongInfo si;
            w.get_song_info((unsigned)(i + 1), si);
            const char* t = si.get_title();
            s_probe_titles.push_back(t ? t : "");
        }
    } catch (...) {
        return 0;
    }
    if (count <= 1) { s_probe_titles.clear(); return 0; }
    s_probe_path = path;
    return count;
}

extern "C" const char* rewamp_zxtune_probe_get_title(int idx) {
    if (idx < 0 || (size_t)idx >= s_probe_titles.size()) return NULL;
    const std::string& t = s_probe_titles[(size_t)idx];
    return t.empty() ? NULL : t.c_str();
}

// ── pattern-view vtable slots ───────────────────────────────────────────────
//
// zxtune already holds a complete, format-agnostic pattern model — note,
// sample, ornament, volume and commands per cell — filled by every one of its
// tracker-based players. The wrapper exposes it (see Spectre.h); all that is
// left here is the conversion to the display cell.
//
// Patterns are keyed by ORDER POSITION, which is what makes a TurboSound pair
// work: there each chip is a separate module with its own pattern numbering,
// and only the position lines them up. The wrapper refuses a grid outright when
// the two halves do not agree on the structure.

static int zx_pattern_song_info(RewampDecoder* dec, RewampPatternSongInfo* out) {
    if (!dec || !dec->w || !out) return 0;
    if (dec->chp) return chp_pattern_song_info(dec->chp, out);
    const int chans = dec->w->pattern_channels();
    const int orders = dec->w->pattern_orders();
    if (chans <= 0 || orders <= 0) return 0;
    memset(out, 0, sizeof(*out));
    out->num_channels = chans;
    out->num_orders   = orders;
    out->num_patterns = orders;
    out->max_fx_cols  = 4;
    out->instr_digits = 2;
    out->vol_chars    = 1;
    // The effect CODE is the model's raw command type, in hex. Each format
    // family numbers its own commands, so a letter mapping would have to be
    // invented per player and would be wrong somewhere; the number is what the
    // model actually says.
    out->fxcode_chars = 2;
    out->fxval_digits = 4;
    return 1;
}

static int zx_pattern_order(RewampDecoder* dec, int order) {
    if (dec && dec->chp) return order >= 0 && order < dec->chp->orders ? order : -1;
    return (dec && dec->w) ? dec->w->pattern_order(order) : -1;
}

static int zx_pattern_num_rows(RewampDecoder* dec, int pattern) {
    if (dec && dec->chp) return chp_pattern_rows(dec->chp, pattern);
    return (dec && dec->w) ? dec->w->pattern_rows(pattern) : 0;
}

static int zx_pattern_get(RewampDecoder* dec, int pattern,
                          RewampPatternCell* out, int maxCells) {
    if (!dec || !dec->w || !out) return 0;
    if (dec->chp) return chp_pattern_get(dec->chp, pattern, out, maxCells);
    const int chans = dec->w->pattern_channels();
    const int rows  = dec->w->pattern_rows(pattern);
    if (chans <= 0 || rows <= 0) return 0;
    int cells = rows * chans;
    if (cells > maxCells) cells = maxCells - (maxCells % chans);
    if (cells <= 0) return 0;

    std::vector<ZxPatternCell> src((size_t)cells);
    const int got = dec->w->pattern_cells(pattern, src.data(), cells);
    if (got <= 0) return 0;

    for (int i = 0; i < got; i++) {
        const ZxPatternCell& z = src[(size_t)i];
        RewampPatternCell* c = &out[i];
        memset(c, 0, sizeof(*c));
        // Note 0 is C-1 in every AY tracker zxtune parses, and the renderer
        // derives the octave as note/12 — hence the shift, which also keeps a
        // .pt3 reading the same here as through libpt3.
        c->note = (int16_t)(z.note >= 0 ? z.note + 12 : REWAMP_NOTE_EMPTY);
        if (z.note < 0 && z.enabled == 0) c->note = REWAMP_NOTE_OFF;
        c->instrument = z.sample;
        c->volume = -1;
        if (z.volume >= 0) snprintf(c->vol, sizeof(c->vol), "%X", z.volume & 0xF);

        int n = 0;
        for (int k = 0; k < z.numCmd && n < REWAMP_PATTERN_MAX_FX; k++, n++) {
            snprintf(c->fx[n], REWAMP_PATTERN_FX_CHARS, "%02X", z.cmdType[k] & 0xFF);
            c->fxval[n] = z.cmdP1[k];
        }
        if (z.ornament >= 0 && n < REWAMP_PATTERN_MAX_FX) {
            c->fx[n][0] = 'O'; c->fxval[n] = z.ornament; n++;
        }
        // The speed lives on the LINE here; a PT3 file writes it as a channel
        // command, so showing it on the first column keeps the two readings of
        // the same file comparable.
        if (z.lineTempo >= 0 && (i % chans) == 0 && n < REWAMP_PATTERN_MAX_FX) {
            c->fx[n][0] = 'T'; c->fxval[n] = z.lineTempo; n++;
        }
        for (int k = n; k < REWAMP_PATTERN_MAX_FX; k++) c->fxval[k] = -1;
        c->num_fx = (uint8_t)n;
    }
    return got;
}

static void zx_pattern_cursor(RewampDecoder* dec, int* order, int* row) {
    if (order) *order = -1;
    if (row)   *row   = -1;
    if (dec && dec->w && dec->chp) { chp_pattern_cursor(dec, order, row); return; }
    if (dec && dec->w) dec->w->pattern_cursor(order, row);
}

/* Vitesse NATIVE: la durée de trame du rendu zxtune (FRAMEDURATION) devient
 * nominale ÷ vitesse — les trames du lecteur se rapprochent, l'AY/YM/SAA/TFM
 * garde son horloge (hauteur conservée). Position, durée et seek du wrapper
 * comptent en trames × durée NOMINALE: déjà en temps du MORCEAU. */
static int zx_set_speed(RewampDecoder* dec, double speed) {
    /* Pas pour un .ay ZXAYEMUL: c'est le CODE Z80 du jeu qui joue, et beaucoup
     * de routines tournent en continu, cadencées par le CPU et non par
     * l'interruption trame — accélérer l'interruption ne les accélère pas
     * (mesuré, enveloppe d'énergie contre 1×: Trantor 0,88-0,97, Lisitska
     * 0,24-0,34, AgentX de Tim Follin 0,01-0,05). La source rééchantillonne. */
    if (dec && dec->ayEmul) return 0;
    if (!dec || !dec->w || speed < 0.2 || speed > 3.0) return 0;
    try {
        return dec->w->set_speed(speed) ? 1 : 0;
    } catch (...) {
        return 0;
    }
}

/* Disquette TR-DOS: réclamée seulement si zxtune y TROUVE un module.
 *
 * L'extension ne dit rien du contenu: une disquette de compo beeper (« Gnampf »,
 * DiHalt 2011: un BASIC et du code machine) n'a aucun module. Réclamée sur son
 * seul nom, elle gagnait le choix du fichier dans un zip de scene.org —
 * `rewamp_can_play` ne regarde qu'extension et en-tête — puis échouait à
 * l'ouverture: « unsupported format » là où rien n'aurait été proposé. On pose
 * donc la vraie question (le même parcours que la sonde des sous-chansons),
 * MÉMORISÉE par (chemin, taille): le registre interroge le même fichier
 * plusieurs fois (jouabilité, choix, chargement). Les autres extensions
 * gardent la sonde ordinaire. */
static std::mutex       s_disk_mu;
static std::string      s_disk_path;
static uint64_t         s_disk_size = 0;
static int              s_disk_ok = 0;

static int zx_disk_has_module(const char* path, uint64_t size) {
    {
        std::lock_guard<std::mutex> g(s_disk_mu);
        if (s_disk_size == size && s_disk_path == path) return s_disk_ok;
    }
    int ok = 0;
    FILE* f = fopen(path, "rb");
    if (f) {
        std::vector<uint8_t> data((size_t)size);
        const size_t got = size ? fread(data.data(), 1, (size_t)size, f) : 0;
        fclose(f);
        if (size > 0 && got == (size_t)size) {
            try {
                ZxTuneWrapper w(std::string(path), data.data(), (size_t)size, ZXTUNE_RATE);
                w.parseModules();
                SongInfo info;
                w.get_song_info(1, info);
                const char* total = info.get_total_tracks();
                ok = total && atoi(total) > 0;
            } catch (...) {
                ok = 0;
            }
        }
    }
    std::lock_guard<std::mutex> g(s_disk_mu);
    s_disk_path = path;
    s_disk_size = size;
    s_disk_ok = ok;
    return ok;
}

static int zx_probe_path(const char* ext, const uint8_t* hdr, size_t n,
                         const char* path, uint64_t fileSize) {
    const int s = zx_probe(ext, hdr, n);
    if (s <= 0 || !ext || !path) return s;
    if (strcasecmp(ext, "trd") != 0 && strcasecmp(ext, "scl") != 0) return s;
    return zx_disk_has_module(path, fileSize) ? s : 0;
}

static const RewampPluginVTable kZxVTable = {
    "zxtune",
    zx_probe,
    zx_open,
    zx_read,
    zx_seek,
    zx_length,
    zx_close,
    zx_configure_loop,
    0,                       /* supportsNativeFadeout */
    NULL,                    /* engine_id */
    NULL,                    /* param_changed */
    zx_pattern_song_info,    /* pattern view */
    zx_pattern_order,
    zx_pattern_num_rows,
    zx_pattern_get,
    zx_pattern_cursor,
    zx_probe_path,           /* probe_path: disquettes TR-DOS jugées au contenu */
    0,                       /* noPrefixProbe */
    zx_set_speed,            /* vitesse native (durée de trame) */
};


extern "C" const RewampPluginVTable* rewamp_zxtune_plugin(void) { return &kZxVTable; }

#endif /* REWAMP_WITH_ZXTUNE */
