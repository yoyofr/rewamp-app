// libzxtune plugin — ZX Spectrum / AY / chiptune multi-format player via the
// Modizer-authored ZxTuneWrapper (emscripten/Spectre.h). Compiled only when
// REWAMP_WITH_ZXTUNE is defined.
#ifdef REWAMP_WITH_ZXTUNE

#include "rewamp_plugin.h"

/* Boucle forcée (rewamp_audio.c) — lus à l'open, comme vgmstream. */
extern "C" int g_force_loop_mode;
extern "C" int g_force_loop_native_veto;
#include "rewamp_channel_data.h"   // per-voice oscilloscope buffers (m_voice_buff[*])

#include "Spectre.h"   // ZxTuneWrapper + SongInfo (libzxtune/emscripten, on the include path)
#include "chp2ym.h"    // libchpconv: .chp (Amstrad CPC ChipTracker) → YM3 conversion

#include <vector>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
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
    "ay", "ym", "vtx", "psg", "pt1", "pt2", "pt3", "stc", "st1", "stp",
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
    "mct", NULL
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
    if (isChp) {
        uint8_t* ym = NULL;
        int ymLen = chp2ym(clean, &ym);
        if (ymLen <= 0 || !ym) { free(ym); return NULL; }
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

    ZxTuneWrapper* w = NULL;
    try {
        w = new ZxTuneWrapper(std::string(clean), data, (size_t)len, ZXTUNE_RATE);
        w->parseModules();
        SongInfo info;
        w->get_song_info((unsigned)(subsong + 1), info);
        w->decodeInitialize((unsigned)(subsong + 1), info);
        // Info panel: zxtune module metadata.
        {
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
        return NULL;
    }
    free(data);   // wrapper copies what it needs

    /* Mode 1 (N boucles): pas de compte natif chez ce zxtune — veto, le
     * générique Dart compte les passes (voir zx_configure_loop). */
    if (g_force_loop_mode == 1) g_force_loop_native_veto = 1;

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { delete w; return NULL; }
    dec->w         = w;
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
    return (dec && dec->w) ? dec->w->pattern_order(order) : -1;
}

static int zx_pattern_num_rows(RewampDecoder* dec, int pattern) {
    return (dec && dec->w) ? dec->w->pattern_rows(pattern) : 0;
}

static int zx_pattern_get(RewampDecoder* dec, int pattern,
                          RewampPatternCell* out, int maxCells) {
    if (!dec || !dec->w || !out) return 0;
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
    if (dec && dec->w) dec->w->pattern_cursor(order, row);
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
};


extern "C" const RewampPluginVTable* rewamp_zxtune_plugin(void) { return &kZxVTable; }

#endif /* REWAMP_WITH_ZXTUNE */
