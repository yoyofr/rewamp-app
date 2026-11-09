#include "rewamp_registry.h"

#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <ctype.h>
#include <pthread.h>

/* Must stay comfortably above the number of rewamp_register_plugin() calls in
 * rewamp_register_builtin_plugins() — there are 35 with every engine enabled
 * (the default). rewamp_register_plugin() SILENTLY DROPS anything past this cap
 * (returns -1, no log), so an overflow makes the LAST-registered plugins
 * disappear: at 32 that was eup, sc68 and vgmstream (the 700-format catch-all),
 * which then never claimed their files and fell through to a failing miniaudio.
 * Keep headroom for future engines. */
#define REWAMP_MAX_PLUGINS   64
/* ⚠️ The app pins MANY extensions (nsf family, gbs, sndh, the 4 MIDI ones,
 * 8 Amiga tracker ones…), and a pin that does not fit used to be DROPPED
 * SILENTLY: with 8 slots, switching « Synthé MIDI » to MT-32 after the Amiga
 * pins had filled the table left .mid on FluidLite (and launching with MT-32
 * set dropped the UADE pins instead). Sized with room to spare; overflow is
 * now reported on stderr. */
#define REWAMP_MAX_OVERRIDES  64
#define REWAMP_HEADER_PROBE_BYTES 2048

static const RewampPluginVTable* g_plugins[REWAMP_MAX_PLUGINS];
static int g_plugin_count = 0;

/* « Lire avec… »: a plugin forced for ONE file (exact clean path), set from
 * the UI thread before a load / a gapless arm, read on the loader or the
 * producer thread — hence the lock. Small table: Dart sets the entries of
 * what it is about to play (current + next) and clears them, it does not
 * mirror its whole store here. */
#define REWAMP_MAX_PATH_OVERRIDES 32
typedef struct { char path[1024]; char plugin_name[32]; } PathOverride;
static PathOverride    g_path_overrides[REWAMP_MAX_PATH_OVERRIDES];
static int             g_path_override_count = 0;
static pthread_mutex_t g_path_override_lock = PTHREAD_MUTEX_INITIALIZER;

/* « Lire avec… »: one OPTION of a plugin chosen for ONE file — the SoundFont
 * of FluidLite, the model of the MT-32 — read by that plugin's open() above
 * its own setting. Same life as the table above (Dart rebuilds it before a
 * load, adds the next file before a gapless arm), same lock. */
typedef struct { char path[1024]; char plugin_name[32]; char value[1024]; } PathOption;
static PathOption g_path_options[REWAMP_MAX_PATH_OVERRIDES];
static int        g_path_option_count = 0;

typedef struct { char ext[16]; char plugin_name[32]; } PluginOverride;
static PluginOverride g_overrides[REWAMP_MAX_OVERRIDES];
static int g_override_count = 0;

// Forward declarations of plugin vtable getters, gated by build flags.
#ifdef REWAMP_WITH_OPENMPT
const RewampPluginVTable* rewamp_openmpt_plugin(void);
#endif
#ifdef REWAMP_WITH_XMP
const RewampPluginVTable* rewamp_xmp_plugin(void);
#endif
#ifdef REWAMP_WITH_VGM
const RewampPluginVTable* rewamp_vgm_plugin(void);
#endif
#ifdef REWAMP_WITH_GME
const RewampPluginVTable* rewamp_gme_plugin(void);
#endif
#ifdef REWAMP_WITH_SID
const RewampPluginVTable* rewamp_sid_plugin(void);
#endif
#ifdef REWAMP_WITH_NSFPLAY
const RewampPluginVTable* rewamp_nsfplay_plugin(void);
#endif
#ifdef REWAMP_WITH_GBSPLAY
const RewampPluginVTable* rewamp_gbsplay_plugin(void);
#endif
#ifdef REWAMP_WITH_CPC
const RewampPluginVTable* rewamp_cpc_plugin(void);
#endif
#ifdef REWAMP_WITH_ZXSPECTRUM
const RewampPluginVTable* rewamp_zxspectrum_plugin(void);
#endif
#ifdef REWAMP_WITH_HIGHLYEXP
const RewampPluginVTable* rewamp_highlyexp_plugin(void);
#endif
#ifdef REWAMP_WITH_VGMSTREAM
const RewampPluginVTable* rewamp_vgmstream_plugin(void);
#endif
#ifdef REWAMP_WITH_FURNACE
const RewampPluginVTable* rewamp_furnace_plugin(void);
#endif
#ifdef REWAMP_WITH_ZXTUNE
const RewampPluginVTable* rewamp_zxtune_plugin(void);
const RewampPluginVTable* rewamp_samcop_plugin(void);
#endif
#ifdef REWAMP_WITH_UADE
const RewampPluginVTable* rewamp_uade_plugin(void);
#endif
#ifdef REWAMP_WITH_NEZ
const RewampPluginVTable* rewamp_nez_plugin(void);
#endif
#ifdef REWAMP_WITH_KSS
const RewampPluginVTable* rewamp_kss_plugin(void);
#endif
#ifdef REWAMP_WITH_MAC
const RewampPluginVTable* rewamp_mac_plugin(void);
#endif
#ifdef REWAMP_WITH_ASAP
const RewampPluginVTable* rewamp_asap_plugin(void);
#endif
#ifdef REWAMP_WITH_HVL
const RewampPluginVTable* rewamp_hvl_plugin(void);
#endif
#ifdef REWAMP_WITH_V2M
const RewampPluginVTable* rewamp_v2m_plugin(void);
#endif
#ifdef REWAMP_WITH_MIDI
const RewampPluginVTable* rewamp_midi_plugin(void);
#endif
#ifdef REWAMP_WITH_MT32
const RewampPluginVTable* rewamp_mt32_plugin(void);
#endif
#ifdef REWAMP_WITH_ADLMIDI
const RewampPluginVTable* rewamp_adlmidi_plugin(void);
#endif
#ifdef REWAMP_WITH_OPNMIDI
const RewampPluginVTable* rewamp_opnmidi_plugin(void);
#endif
#ifdef REWAMP_WITH_GSF
const RewampPluginVTable* rewamp_gsf_plugin(void);
#endif
#ifdef REWAMP_WITH_VIO2SF
const RewampPluginVTable* rewamp_vio2sf_plugin(void);
#endif
#ifdef REWAMP_WITH_NCSF
const RewampPluginVTable* rewamp_ncsf_plugin(void);
#endif
#ifdef REWAMP_WITH_SNSF
const RewampPluginVTable* rewamp_snsf_plugin(void);
#endif
#ifdef REWAMP_WITH_ADPLUG
const RewampPluginVTable* rewamp_adplug_plugin(void);
#endif
#ifdef REWAMP_WITH_SNDH
const RewampPluginVTable* rewamp_sndh_plugin(void);
const RewampPluginVTable* rewamp_atariaudio_ym_plugin(void);
#endif
#ifdef REWAMP_WITH_PSGPLAY
const RewampPluginVTable* rewamp_psgplay_plugin(void);
#endif
#ifdef REWAMP_WITH_LAZYUSF
const RewampPluginVTable* rewamp_lazyusf_plugin(void);
#endif
#ifdef REWAMP_WITH_WONDERSWAN
const RewampPluginVTable* rewamp_wonderswan_plugin(void);
#endif
#ifdef REWAMP_WITH_HIGHLYQUIXOTIC
const RewampPluginVTable* rewamp_highlyquixotic_plugin(void);
#endif
#ifdef REWAMP_WITH_HIGHLYTHEORITICAL
const RewampPluginVTable* rewamp_highlytheoritical_plugin(void);
#endif
#ifdef REWAMP_WITH_LIBPT3
const RewampPluginVTable* rewamp_libpt3_plugin(void);
#endif
#ifdef REWAMP_WITH_ORGANYA
const RewampPluginVTable* rewamp_organya_plugin(void);
#endif
#ifdef REWAMP_WITH_MINIBAE
const RewampPluginVTable* rewamp_minibae_plugin(void);
#endif
#ifdef REWAMP_WITH_NTGS
const RewampPluginVTable* rewamp_ntgs_plugin(void);
#endif
#ifdef REWAMP_WITH_TIATRACKER
const RewampPluginVTable* rewamp_tiatracker_plugin(void);
#endif
#ifdef REWAMP_WITH_RONKLAREN
const RewampPluginVTable* rewamp_ronklaren_plugin(void);
#endif
#ifdef REWAMP_WITH_PXTONE
const RewampPluginVTable* rewamp_pxtone_plugin(void);
#endif
#ifdef REWAMP_WITH_PMD
const RewampPluginVTable* rewamp_pmd_plugin(void);
#endif
#ifdef REWAMP_WITH_MDX
const RewampPluginVTable* rewamp_mdx_plugin(void);
#endif
#ifdef REWAMP_WITH_FMP
const RewampPluginVTable* rewamp_fmp_plugin(void);
#endif
#ifdef REWAMP_WITH_EUP
const RewampPluginVTable* rewamp_eup_plugin(void);
#endif
#ifdef REWAMP_WITH_SC68
const RewampPluginVTable* rewamp_sc68_plugin(void);
#endif
#ifdef REWAMP_WITH_SUNVOX
const RewampPluginVTable* rewamp_sunvox_plugin(void);
#endif

int rewamp_register_plugin(const RewampPluginVTable* vt) {
    if (vt == NULL) return -1;
    if (g_plugin_count >= REWAMP_MAX_PLUGINS) {
        // Silent before: an overflow just made the last engines vanish. Shout
        // so the next person who adds one past the cap sees it immediately.
        fprintf(stderr, "[rewamp] plugin registry FULL (%d) — dropping \"%s\"; "
                "raise REWAMP_MAX_PLUGINS\n",
                REWAMP_MAX_PLUGINS, vt->name ? vt->name : "?");
        return -1;
    }
    g_plugins[g_plugin_count++] = vt;
    return 0;
}

void rewamp_register_builtin_plugins(void) {
    g_plugin_count = 0;
#ifdef REWAMP_WITH_VGM
    rewamp_register_plugin(rewamp_vgm_plugin());
#endif
#ifdef REWAMP_WITH_NSFPLAY
    // Registered before GME so that NSF/NSFe header matches (score 100) from
    // nsfplay beat GME's identical score by virtue of first-registered wins ties.
    rewamp_register_plugin(rewamp_nsfplay_plugin());
#endif
#ifdef REWAMP_WITH_GBSPLAY
    // Registered before GME so gbsplay wins on .gbs files (score 100 vs 60).
    rewamp_register_plugin(rewamp_gbsplay_plugin());
#endif
#ifdef REWAMP_WITH_CPC
    // Amstrad CPC .dsk, claimed on the image MAGIC only (.dsk is also Apple
    // II, MSX, Atari ST…), so no rival can lose a file to it.
    rewamp_register_plugin(rewamp_cpc_plugin());
#endif
#ifdef REWAMP_WITH_ZXSPECTRUM
    // ZX Spectrum .tap, RUN on an emulated 48K/128K. Claimed with the file:
    // the whole block chain must hold (lengths + checksums) — .tap is also
    // Commodore and Oric.
    rewamp_register_plugin(rewamp_zxspectrum_plugin());
#endif
#ifdef REWAMP_WITH_HIGHLYEXP
    rewamp_register_plugin(rewamp_highlyexp_plugin());
#endif
#ifdef REWAMP_WITH_FURNACE
    // .fur header → score 95; extension-only → 70. Registered before GME so it
    // wins .dmf over any generic claim.
    rewamp_register_plugin(rewamp_furnace_plugin());
#endif
#ifdef REWAMP_WITH_NEZ
    // Registered before GME so .hes routes to nez (HuC6280 voice grouping):
    // nez scores 101/120 vs GME's 100. .sgc has no other claimant.
    rewamp_register_plugin(rewamp_nez_plugin());
#endif
#ifdef REWAMP_WITH_KSS
    // Registered before GME so MSX chiptunes route to libkss for the per-chip
    // voice grouping: .kss scores 101 vs GME's 100; .mgs/.bgm/.mpk/.mbm/.opx/
    // .mus are libkss-only (score 90, content-verified).
    rewamp_register_plugin(rewamp_kss_plugin());
#endif
#ifdef REWAMP_WITH_ASAP
    // Registered before GME: SAP magic scores 110 vs GME's 100, so Atari SAP
    // routes to ASAP (per-POKEY voices); tracker exts (cmc/rmt/tmc/…) are
    // ASAP-only.
    rewamp_register_plugin(rewamp_asap_plugin());
#endif
#ifdef REWAMP_WITH_GME
    rewamp_register_plugin(rewamp_gme_plugin());
#endif
#ifdef REWAMP_WITH_OPENMPT
    rewamp_register_plugin(rewamp_openmpt_plugin());
#endif
#ifdef REWAMP_WITH_XMP
    // libxmp AFTER libopenmpt, deliberately: the two overlap on every
    // mainstream tracker format and libopenmpt is the better replayer there,
    // so libxmp scores one notch below (90 vs 100 on a confirmed header) and
    // loses every tie. It exists for the ~10 formats libopenmpt cannot load
    // at all — Archimedes Tracker (.musx), Liquid Tracker, Funktracker…
    rewamp_register_plugin(rewamp_xmp_plugin());
#endif
#ifdef REWAMP_WITH_SID
    rewamp_register_plugin(rewamp_sid_plugin());
#endif
#ifdef REWAMP_WITH_ZXTUNE
    // ZX Spectrum / AY chiptune formats (score 55) — before vgmstream's catch-all.
    rewamp_register_plugin(rewamp_zxtune_plugin());
    // SAM Coupé `.cop` qui sont des programmes Z80 BRUTS (pas des modules
    // E-Tracker): z80ex + la SAA1099 de zxtune. Lecteur « B » reconnu à
    // l'en-tête (100), le reste par l'absence d'E-Tracker (probe_path, 70) —
    // les deux au-dessus des 55 de zxtune, qui échouait à les ouvrir.
    rewamp_register_plugin(rewamp_samcop_plugin());
#endif
#ifdef REWAMP_WITH_HVL
    // HivelyTracker/AHX native replayer — beats UADE's generic suffix claim
    // on .ahx/.hvl (64 vs 58), like Modizer's MMP_HVL.
    rewamp_register_plugin(rewamp_hvl_plugin());
#endif
#ifdef REWAMP_WITH_UADE
    // Amiga custom-chip formats (score 58) — before vgmstream's catch-all.
    rewamp_register_plugin(rewamp_uade_plugin());
#endif
#ifdef REWAMP_WITH_V2M
    // Farbrausch V2 synth (.v2m/.v2mz) — extension-only claim (80).
    rewamp_register_plugin(rewamp_v2m_plugin());
#endif
#ifdef REWAMP_WITH_MAC
    // Monkey's Audio .ape (magic 'MAC ' → 95/70, ext → 60) — before vgmstream.
    rewamp_register_plugin(rewamp_mac_plugin());
#endif
#ifdef REWAMP_WITH_MIDI
    // Standard MIDI via FluidLite+SF2 (MThd/RMID magic → 110/100; probe
    // declines when no SoundFont is installed).
    rewamp_register_plugin(rewamp_midi_plugin());
#endif
#ifdef REWAMP_WITH_MT32
    // Second .mid engine: Roland MT-32 / CM-32L emulation (mt32emu). Same
    // 100 as FluidLite on a plain file, so registering it AFTER makes
    // FluidLite win the tie; 104 when the file carries MT-32 sysex; 0 without
    // an imported ROM set. Neither is exclusive (< 105): the app pins one or
    // the other through rewamp_registry_set_preferred_plugin("mid", ...).
    rewamp_register_plugin(rewamp_mt32_plugin());
#endif
#ifdef REWAMP_WITH_ADLMIDI
    // Third .mid engine: libADLMIDI on an emulated OPL3 (AdLib / Sound
    // Blaster). 95 on a plain MIDI — under FluidLite's and MT-32's 100, so
    // only « Synthé MIDI: OPL3 » (a pin) selects it there; 100 on the formats
    // no other plugin plays, confirmed by their magic (XMI, DMX MUS, HMI/HMP,
    // GMF). A `.mus` without the DMX magic stays with SID/KSS/vgmstream.
    rewamp_register_plugin(rewamp_adlmidi_plugin());
#endif
#ifdef REWAMP_WITH_OPNMIDI
    // Fourth .mid engine: libOPNMIDI on an emulated OPN2 (Mega Drive) / OPNA
    // (PC-98). 94 on a plain MIDI: only « Synthé MIDI: OPN2 » (a pin) selects
    // it. 90 on the DOS formats, under libADLMIDI's 100: an OPL wrote them.
    rewamp_register_plugin(rewamp_opnmidi_plugin());
#endif
#ifdef REWAMP_WITH_GSF
    // GBA .gsf/.minigsf via VBA (PSF 0x22 magic → 110/100). Before highlyexp
    // (which claims generic PSF) — distinct magic byte, no real conflict.
    rewamp_register_plugin(rewamp_gsf_plugin());
#endif
#ifdef REWAMP_WITH_VIO2SF
    // Nintendo DS .2sf/.mini2sf via melonDS (PSF 0x24 magic → 100/85). Distinct
    // magic byte; no conflict with the generic-PSF highlyexp plugin.
    rewamp_register_plugin(rewamp_vio2sf_plugin());
#endif
#ifdef REWAMP_WITH_NCSF
    // Nintendo DS .ncsf/.minincsf via SSEQPlayer (PSF 0x25 magic → 100/85).
    // Same console as vio2sf but a different engine entirely: NCSF embeds an
    // SDAT sound archive played by a software synth, not an emulated ROM.
    rewamp_register_plugin(rewamp_ncsf_plugin());
#endif
#ifdef REWAMP_WITH_SNSF
    // Super Nintendo .snsf/.minisnsf via snsf9x (PSF 0x23 magic → 100/85).
    // Distinct magic byte, exclusive extensions — no conflict with the generic
    // highlyexp PSF plugin, nor with libgme's .spc (a different container).
    rewamp_register_plugin(rewamp_snsf_plugin());
#endif
#ifdef REWAMP_WITH_ADPLUG
    // AdLib / OPL2/OPL3 formats (score 90 on exclusive exts; AdPlug content-
    // verifies in open()). Before vgmstream's catch-all; mid/s3m/vgm excluded so
    // FluidLite/OpenMPT/libvgm keep those.
    rewamp_register_plugin(rewamp_adplug_plugin());
#endif
#ifdef REWAMP_WITH_SNDH
    // Atari ST .sndh (score 100 on SNDH magic / 90 ext-only) — exclusive
    // extension, no conflict with any other plugin.
    rewamp_register_plugin(rewamp_sndh_plugin());
    // .ym through the same library: 90 on a YM header (LZH, LeOnArD!, YM2/3),
    // 60 on the extension alone — above zxtune's 55 either way, so AtariAudio
    // is the default; « Décodeurs par défaut » pins zxtune back.
    rewamp_register_plugin(rewamp_atariaudio_ym_plugin());
#endif
#ifdef REWAMP_WITH_PSGPLAY
    // Second .sndh engine (psgplay): whole-machine emulation with the STE
    // LMC1992 mixer AtariAudio does not model, and native stereo. It is the
    // DEFAULT for .sndh, but not by probe score — it deliberately scores one
    // point BELOW the AtariAudio plugin at every step, and the app pins it
    // through rewamp_registry_set_preferred_plugin("sndh", "psgplay") at
    // startup (same mechanism as the nsfplay/gbsplay and Amiga settings). So
    // an embedder that registers the plugins and sets no preference keeps
    // AtariAudio, which is the conservative fallback.
    rewamp_register_plugin(rewamp_psgplay_plugin());
#endif
#ifdef REWAMP_WITH_LAZYUSF
    // Nintendo 64 .usf/.miniusf (PSF magic 0x21 → 110/90) — exclusive
    // extension, no conflict with any other plugin.
    rewamp_register_plugin(rewamp_lazyusf_plugin());
#endif
#ifdef REWAMP_WITH_WONDERSWAN
    // WonderSwan .wsr rip on the beetle-wswan (Mednafen) core (ext-only, footer
    // magic not in the probed header) — exclusive extension, no conflict with
    // any other plugin.
    rewamp_register_plugin(rewamp_wonderswan_plugin());
#endif
#ifdef REWAMP_WITH_HIGHLYQUIXOTIC
    // Capcom QSound .qsf/.qsflib (PSF magic 0x41 -> 110/90) — exclusive
    // extension, no conflict with any other plugin.
    rewamp_register_plugin(rewamp_highlyquixotic_plugin());
#endif
#ifdef REWAMP_WITH_HIGHLYTHEORITICAL
    // Saturn .ssf/.ssflib (PSF magic 0x11) + Dreamcast .dsf/.dsflib (magic
    // 0x12) -> 110/90 — exclusive extensions, no conflict with any other
    // plugin (vgmstream's own kSkipExts already carves these out).
    rewamp_register_plugin(rewamp_highlytheoritical_plugin());
#endif
#ifdef REWAMP_WITH_LIBPT3
    // ZX Spectrum PT3 (.pt3) — score 90 (ext-only), beats zxtune's own .pt3
    // claim (score 55, no content check) for the per-chip AY voice model.
    rewamp_register_plugin(rewamp_libpt3_plugin());
#endif
#ifdef REWAMP_WITH_ORGANYA
    // Cave Story .org (magic "Org-01".."Org-03" -> 110/90) — exclusive
    // extension, no conflict with any other plugin.
    rewamp_register_plugin(rewamp_organya_plugin());
#endif
#ifdef REWAMP_WITH_MINIBAE
    // Beatnik RMF (magic "IREZ" -> 110 with .rmf, 90 without) — no other
    // plugin claims either the extension or the magic.
    rewamp_register_plugin(rewamp_minibae_plugin());
#endif
#ifdef REWAMP_WITH_NTGS
    // NoiseTracker GS 1.x (Apple IIGS): reconnu par le CONTENU (« FTA
    // MODULEFILE » aux octets 2..15) — les rips n'ont le plus souvent AUCUNE
    // extension. Aucun autre greffon ne revendique cette magie.
    rewamp_register_plugin(rewamp_ntgs_plugin());
#endif
#ifdef REWAMP_WITH_TIATRACKER
    // Atari VCS 2600 .ttt (TIATracker project files, which are JSON -> 95/80)
    // — exclusive extension, no conflict with any other plugin.
    rewamp_register_plugin(rewamp_tiatracker_plugin());
#endif
#ifdef REWAMP_WITH_RONKLAREN
    // Ron Klaren (Amiga .rk): 100 seulement quand le fichier porte le hunk
    // exécutable ET « RON_KLAREN_SOUNDMODULE! » à l'octet 40 — devant les 58
    // qu'UADE donne à l'extension seule, sous REWAMP_SCORE_EXCLUSIVE. UADE y
    // envoyait le player générique CustomMade, qui ne connaît que la forme à
    // interruption CIA de la routine (« electricity.rk »: 2 418 sous-chansons
    // annoncées, silence). Sans la marque (`.cm`, `.rkb`, autre `.rk`): 0, le
    // fichier reste à UADE. L'ordre d'enregistrement ne joue pas (pas d'égalité).
    rewamp_register_plugin(rewamp_ronklaren_plugin());
#endif
#ifdef REWAMP_WITH_PXTONE
    // PxTone Collage .ptcop/.pttune (magic "PTCOLLAGE-"/"PTTUNE--" -> 110/90)
    // — exclusive extensions, no conflict with any other plugin.
    rewamp_register_plugin(rewamp_pxtone_plugin());
#endif
#ifdef REWAMP_WITH_PMD
    // PC-98 PMD .m/.m2/.mz — header-verified (score 100) and declined without
    // that header, since ".m" is far too generic to claim on extension alone.
    rewamp_register_plugin(rewamp_pmd_plugin());
#endif
#ifdef REWAMP_WITH_MDX
    // Sharp X68000 .mdx — exclusive extension (score 90, no magic: an .mdx
    // opens with its own Shift-JIS title text).
    rewamp_register_plugin(rewamp_mdx_plugin());
#endif
#ifdef REWAMP_WITH_FMP
    // PC-98 FMP .opi/.ovi/.ozi — exclusive extensions (score 90, no magic:
    // libfmpmini verifies the content in fmplayer_file_alloc during open()).
    rewamp_register_plugin(rewamp_fmp_plugin());
#endif
#ifdef REWAMP_WITH_EUP
    // FM Towns .eup — exclusive extension (score 90, no magic; the header is a
    // 2 KB metadata block with no signature at offset 0).
    rewamp_register_plugin(rewamp_eup_plugin());
#endif
#ifdef REWAMP_WITH_SC68
    // Atari ST + Amiga .sc68 (magic "SC68 Music-file" -> 110/90; gzip/ICE
    // packed accepted on extension). Exclusive extension — .sndh stays with
    // the AtariAudio plugin.
    rewamp_register_plugin(rewamp_sc68_plugin());
#endif
#ifdef REWAMP_WITH_SUNVOX
    // Alexander Zolotov's SunVox modular synth+tracker .sunvox (magic "SVOX"
    // -> 100, exclusive extension -> 90). SunVox also reads XM/MOD but the
    // probe claims neither — libopenmpt keeps those.
    rewamp_register_plugin(rewamp_sunvox_plugin());
#endif
#ifdef REWAMP_WITH_VGMSTREAM
    // Registered last: score 50 catch-all, loses to any plugin with higher evidence.
    rewamp_register_plugin(rewamp_vgmstream_plugin());
#endif
}

int rewamp_registry_count(void) {
    return g_plugin_count;
}

int rewamp_ext_in_list(const char* ext, const char* const* list) {
    if (ext == NULL || list == NULL) return 0;
    for (int i = 0; list[i] != NULL; ++i) {
        if (strcmp(ext, list[i]) == 0) return 1;
    }
    return 0;
}

// Extract the Amiga PREFIX token (basename up to the FIRST dot, lowercased)
// into `out`. Amiga customs use the reversed convention "token.name"
// ("mdat.turrican", "jt.hiscore_and_menu") — the suffix is the song name, the
// prefix is the format. Returns 1 when a token was found.
static int extract_prefix(const char* path, char* out, size_t outSize) {
    const char* slash = strrchr(path, '/');
    const char* base  = slash ? slash + 1 : path;
    const char* dot   = strchr(base, '.');
    if (dot == NULL || dot == base) return 0;
    size_t n = 0;
    while (base + n < dot && n < outSize - 1) {
        out[n] = (char)tolower((unsigned char)base[n]);
        ++n;
    }
    out[n] = '\0';
    return n > 0;
}

// Extract lowercased extension (without dot) into `out` (size `outSize`).
// Returns 1 if an extension was found, else 0.
static int extract_ext(const char* path, char* out, size_t outSize) {
    const char* dot = strrchr(path, '.');
    const char* slash = strrchr(path, '/');
    if (dot == NULL || (slash != NULL && dot < slash)) return 0;

    const char* e = dot + 1;
    size_t n = 0;
    while (e[n] != '\0' && n < outSize - 1) {
        out[n] = (char)tolower((unsigned char)e[n]);
        ++n;
    }
    out[n] = '\0';
    return n > 0;
}

static size_t read_header(const char* path, uint8_t* buf, size_t bufSize) {
    FILE* f = fopen(path, "rb");
    if (f == NULL) return 0;
    size_t n = fread(buf, 1, bufSize, f);
    fclose(f);
    return n;
}

void rewamp_registry_set_preferred_plugin(const char* ext, const char* plugin_name) {
    if (!ext) return;
    // Update existing entry if present.
    for (int i = 0; i < g_override_count; i++) {
        if (strcmp(g_overrides[i].ext, ext) == 0) {
            if (!plugin_name) {
                // Remove: shift remaining entries.
                for (int j = i; j < g_override_count - 1; j++)
                    g_overrides[j] = g_overrides[j + 1];
                g_override_count--;
            } else {
                strncpy(g_overrides[i].plugin_name, plugin_name, 31);
                g_overrides[i].plugin_name[31] = '\0';
            }
            return;
        }
    }
    // New entry.
    if (!plugin_name) return;
    if (g_override_count >= REWAMP_MAX_OVERRIDES) {
        fprintf(stderr, "[registry] pin table full (%d): '%s' -> '%s' ignored\n",
                REWAMP_MAX_OVERRIDES, ext, plugin_name);
        return;
    }
    strncpy(g_overrides[g_override_count].ext, ext, 15);
    g_overrides[g_override_count].ext[15] = '\0';
    strncpy(g_overrides[g_override_count].plugin_name, plugin_name, 31);
    g_overrides[g_override_count].plugin_name[31] = '\0';
    g_override_count++;
}

void rewamp_registry_set_path_plugin(const char* path, const char* plugin_name) {
    if (path == NULL || !path[0]) return;
    pthread_mutex_lock(&g_path_override_lock);
    int at = -1;
    for (int i = 0; i < g_path_override_count; i++)
        if (strcmp(g_path_overrides[i].path, path) == 0) { at = i; break; }
    if (plugin_name == NULL || !plugin_name[0]) {
        if (at >= 0) {
            for (int j = at; j < g_path_override_count - 1; j++)
                g_path_overrides[j] = g_path_overrides[j + 1];
            g_path_override_count--;
        }
    } else {
        if (at < 0) {
            if (g_path_override_count >= REWAMP_MAX_PATH_OVERRIDES) {
                /* Oldest out: Dart only keeps what it is about to play. */
                for (int j = 0; j < g_path_override_count - 1; j++)
                    g_path_overrides[j] = g_path_overrides[j + 1];
                g_path_override_count--;
                fprintf(stderr, "[registry] path override table full, oldest dropped\n");
            }
            at = g_path_override_count++;
            strncpy(g_path_overrides[at].path, path, sizeof(g_path_overrides[at].path) - 1);
            g_path_overrides[at].path[sizeof(g_path_overrides[at].path) - 1] = '\0';
        }
        strncpy(g_path_overrides[at].plugin_name, plugin_name, 31);
        g_path_overrides[at].plugin_name[31] = '\0';
    }
    pthread_mutex_unlock(&g_path_override_lock);
}

void rewamp_registry_clear_path_plugins(void) {
    pthread_mutex_lock(&g_path_override_lock);
    g_path_override_count = 0;
    pthread_mutex_unlock(&g_path_override_lock);
}

void rewamp_registry_set_path_option(const char* path, const char* plugin_name,
                                     const char* value) {
    if (path == NULL || !path[0] || plugin_name == NULL || !plugin_name[0]) return;
    pthread_mutex_lock(&g_path_override_lock);
    int at = -1;
    for (int i = 0; i < g_path_option_count; i++)
        if (strcmp(g_path_options[i].path, path) == 0 &&
            strcmp(g_path_options[i].plugin_name, plugin_name) == 0) { at = i; break; }
    if (value == NULL || !value[0]) {
        if (at >= 0) {
            for (int j = at; j < g_path_option_count - 1; j++)
                g_path_options[j] = g_path_options[j + 1];
            g_path_option_count--;
        }
    } else {
        if (at < 0) {
            if (g_path_option_count >= REWAMP_MAX_PATH_OVERRIDES) {
                for (int j = 0; j < g_path_option_count - 1; j++)
                    g_path_options[j] = g_path_options[j + 1];
                g_path_option_count--;
                fprintf(stderr, "[registry] path option table full, oldest dropped\n");
            }
            at = g_path_option_count++;
            snprintf(g_path_options[at].path, sizeof(g_path_options[at].path), "%s", path);
            snprintf(g_path_options[at].plugin_name, sizeof(g_path_options[at].plugin_name),
                     "%s", plugin_name);
        }
        snprintf(g_path_options[at].value, sizeof(g_path_options[at].value), "%s", value);
    }
    pthread_mutex_unlock(&g_path_override_lock);
}

void rewamp_registry_clear_path_options(void) {
    pthread_mutex_lock(&g_path_override_lock);
    g_path_option_count = 0;
    pthread_mutex_unlock(&g_path_override_lock);
}

int rewamp_registry_path_option(const char* path, const char* plugin_name,
                                char* out, size_t outSize) {
    if (out && outSize) out[0] = '\0';
    if (path == NULL || plugin_name == NULL || out == NULL || outSize == 0) return 0;
    int found = 0;
    pthread_mutex_lock(&g_path_override_lock);
    for (int i = 0; i < g_path_option_count; i++)
        if (strcmp(g_path_options[i].path, path) == 0 &&
            strcmp(g_path_options[i].plugin_name, plugin_name) == 0) {
            snprintf(out, outSize, "%s", g_path_options[i].value);
            found = 1;
            break;
        }
    pthread_mutex_unlock(&g_path_override_lock);
    return found;
}

/* Copies the forced plugin of [path] into [out] (empty when none). */
static void path_override_for(const char* path, char out[32]) {
    out[0] = '\0';
    pthread_mutex_lock(&g_path_override_lock);
    for (int i = 0; i < g_path_override_count; i++)
        if (strcmp(g_path_overrides[i].path, path) == 0) {
            memcpy(out, g_path_overrides[i].plugin_name, 32);
            break;
        }
    pthread_mutex_unlock(&g_path_override_lock);
}

static int select_ranked_core(const char* path, const RewampPluginVTable** out,
                              int maxOut);

/* « Lire avec… »: the plugin chosen for THIS file goes first — above an
 * extension pin and an exclusive identification too, since a person picked it
 * for this very file. Only among the plugins that claim it (probe > 0): one
 * that cannot read the file is not forced on it. The others stay behind, so a
 * failed open still cascades. ⚠️ Ranked on the FULL list, truncated after:
 * rewamp_registry_select asks for ONE candidate, and the forced plugin, second
 * by score, was cut before it could be lifted (caught by the harness). */
static int select_ranked_impl(const char* path, const RewampPluginVTable** out,
                              int maxOut, int usePathOverride) {
    char forced[32] = "";
    if (usePathOverride && path) path_override_for(path, forced);
    if (!forced[0]) return select_ranked_core(path, out, maxOut);
    const RewampPluginVTable* all[REWAMP_MAX_PLUGINS];
    const int n = select_ranked_core(path, all, REWAMP_MAX_PLUGINS);
    for (int k = 0; k < n; k++) {
        if (all[k]->name && strcmp(all[k]->name, forced) == 0) {
            const RewampPluginVTable* f = all[k];
            for (int m = k; m > 0; m--) all[m] = all[m - 1];
            all[0] = f;
            break;
        }
    }
    const int outN = n < maxOut ? n : maxOut;
    for (int k = 0; k < outN; k++) out[k] = all[k];
    return outN;
}

int rewamp_registry_select_ranked(const char* path,
                                  const RewampPluginVTable** out, int maxOut) {
    return select_ranked_impl(path, out, maxOut, 1);
}

/* The default order (no « Lire avec… » override), names joined by '\n' —
 * what the UI offers, the first being the engine that plays it by default.
 * Static buffer: one caller at a time (the UI thread). */
const char* rewamp_registry_candidates(const char* path) {
    static char buf[1024];
    buf[0] = '\0';
    if (path == NULL) return buf;
    const RewampPluginVTable* c[REWAMP_MAX_PLUGINS];
    const int n = select_ranked_impl(path, c, REWAMP_MAX_PLUGINS, 0);
    size_t len = 0;
    for (int i = 0; i < n; i++) {
        if (!c[i]->name) continue;
        const size_t l = strlen(c[i]->name);
        if (len + l + 2 >= sizeof(buf)) break;
        if (len) buf[len++] = '\n';
        memcpy(buf + len, c[i]->name, l);
        len += l;
        buf[len] = '\0';
    }
    return buf;
}

static int select_ranked_core(const char* path, const RewampPluginVTable** out,
                              int maxOut) {
    if (path == NULL || out == NULL || maxOut <= 0 || g_plugin_count == 0)
        return 0;

    char ext[32];
    const char* extPtr = extract_ext(path, ext, sizeof(ext)) ? ext : NULL;
    // Amiga prefix-convention token ("mdat.NAME", "jt.NAME"): probed as a
    // SECOND extension candidate — each plugin gets max(score(ext),
    // score(prefix)). Skipped when identical to the suffix.
    char prefix[32];
    const char* prefixPtr =
        extract_prefix(path, prefix, sizeof(prefix)) ? prefix : NULL;
    if (prefixPtr && extPtr && strcmp(prefixPtr, extPtr) == 0) prefixPtr = NULL;

    uint8_t header[REWAMP_HEADER_PROBE_BYTES];
    size_t headerSize = read_header(path, header, sizeof(header));

    /* Taille RÉELLE du fichier, pour les probes qui en ont besoin: plusieurs
     * validations de amifilemagic comparent la taille calculée depuis
     * l'en-tête à celle du fichier, et abdiquent quand on leur ment. */
    uint64_t fileSize = 0;
    {
        struct stat st;
        if (stat(path, &st) == 0 && S_ISREG(st.st_mode))
            fileSize = (uint64_t)st.st_size;
    }

    // Check if user has an extension-level plugin preference (suffix first,
    // then the Amiga prefix token).
    const char* preferredName = NULL;
    for (int pass = 0; pass < 2 && !preferredName; pass++) {
        const char* key = pass == 0 ? extPtr : prefixPtr;
        if (!key) continue;
        for (int i = 0; i < g_override_count; i++) {
            if (strcmp(g_overrides[i].ext, key) == 0) {
                preferredName = g_overrides[i].plugin_name;
                break;
            }
        }
    }

    // Score every plugin once.
    const RewampPluginVTable* cand[REWAMP_MAX_PLUGINS];
    int score[REWAMP_MAX_PLUGINS];
    int n = 0;
    const RewampPluginVTable* preferred = NULL;
    for (int i = 0; i < g_plugin_count; ++i) {
        const RewampPluginVTable* vt = g_plugins[i];
        if (vt->probe == NULL) continue;
        int s = vt->probe_path
            ? vt->probe_path(extPtr, header, headerSize, path, fileSize)
            : vt->probe(extPtr, header, headerSize);
        /* Le préfixe n'est demandé qu'aux greffons qui répondent par une
         * LISTE. Un fourre-tout (vgmstream) y verrait un jeton inconnu et
         * rendrait son score de repli, ce qui annule sa propre liste
         * d'exclusion sur tout nom `radical.ext`. Voir `noPrefixProbe`. */
        if (prefixPtr && !vt->noPrefixProbe) {
            int sp = vt->probe_path
                ? vt->probe_path(prefixPtr, header, headerSize, path, fileSize)
                : vt->probe(prefixPtr, header, headerSize);
            if (sp > s) s = sp;
        }
        if (s <= 0) continue;
        /* Une IDENTIFICATION EXCLUSIVE passe devant l'épingle — voir
         * REWAMP_SCORE_EXCLUSIVE. L'épingle arbitre entre greffons qui savent
         * tous jouer le fichier; elle ne demande pas qu'on le joue MAL. */
        if (s >= REWAMP_SCORE_EXCLUSIVE) {
            cand[n] = vt;
            score[n] = s;
            n++;
            continue;
        }
        if (preferredName && vt->name && strcmp(vt->name, preferredName) == 0) {
            preferred = vt;   // pinned to the front below
            continue;
        }
        cand[n] = vt;
        score[n] = s;
        n++;
    }

    // Insertion sort by descending score (stable: registration order breaks ties).
    for (int i = 1; i < n; ++i) {
        const RewampPluginVTable* v = cand[i];
        int s = score[i];
        int j = i - 1;
        while (j >= 0 && score[j] < s) {
            cand[j + 1] = cand[j];
            score[j + 1] = score[j];
            --j;
        }
        cand[j + 1] = v;
        score[j + 1] = s;
    }

    int outN = 0;
    /* ⚠️ L'ORDRE DE SORTIE, pas seulement le classement: le greffon épinglé
     * était écrit EN TÊTE sans condition, donc trier une identification
     * exclusive au-dessus de lui ne servait à rien — elle restait en
     * deuxième position et n'était jamais essayée. Les identifications
     * exclusives (>= REWAMP_SCORE_EXCLUSIVE) passent donc AVANT l'épingle;
     * tout le reste garde l'ordre d'avant. */
    int i = 0;
    for (; i < n && outN < maxOut && score[i] >= REWAMP_SCORE_EXCLUSIVE; ++i)
        out[outN++] = cand[i];
    if (preferred && outN < maxOut) out[outN++] = preferred;
    for (; i < n && outN < maxOut; ++i) out[outN++] = cand[i];

    return outN;
}

const RewampPluginVTable* rewamp_registry_select(const char* path) {
    const RewampPluginVTable* best = NULL;
    return rewamp_registry_select_ranked(path, &best, 1) > 0 ? best : NULL;
}
