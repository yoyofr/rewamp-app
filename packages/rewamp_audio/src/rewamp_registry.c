#include "rewamp_registry.h"

#include <stdio.h>
#include <string.h>
#include <ctype.h>

/* Must stay comfortably above the number of rewamp_register_plugin() calls in
 * rewamp_register_builtin_plugins() — there are 35 with every engine enabled
 * (the default). rewamp_register_plugin() SILENTLY DROPS anything past this cap
 * (returns -1, no log), so an overflow makes the LAST-registered plugins
 * disappear: at 32 that was eup, sc68 and vgmstream (the 700-format catch-all),
 * which then never claimed their files and fell through to a failing miniaudio.
 * Keep headroom for future engines. */
#define REWAMP_MAX_PLUGINS   64
#define REWAMP_MAX_OVERRIDES  8
#define REWAMP_HEADER_PROBE_BYTES 2048

static const RewampPluginVTable* g_plugins[REWAMP_MAX_PLUGINS];
static int g_plugin_count = 0;

typedef struct { char ext[16]; char plugin_name[32]; } PluginOverride;
static PluginOverride g_overrides[REWAMP_MAX_OVERRIDES];
static int g_override_count = 0;

// Forward declarations of plugin vtable getters, gated by build flags.
#ifdef REWAMP_WITH_OPENMPT
const RewampPluginVTable* rewamp_openmpt_plugin(void);
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
#ifdef REWAMP_WITH_TIATRACKER
const RewampPluginVTable* rewamp_tiatracker_plugin(void);
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
#ifdef REWAMP_WITH_SID
    rewamp_register_plugin(rewamp_sid_plugin());
#endif
#ifdef REWAMP_WITH_ZXTUNE
    // ZX Spectrum / AY chiptune formats (score 55) — before vgmstream's catch-all.
    rewamp_register_plugin(rewamp_zxtune_plugin());
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
#ifdef REWAMP_WITH_TIATRACKER
    // Atari VCS 2600 .ttt (TIATracker project files, which are JSON -> 95/80)
    // — exclusive extension, no conflict with any other plugin.
    rewamp_register_plugin(rewamp_tiatracker_plugin());
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
    if (!plugin_name || g_override_count >= REWAMP_MAX_OVERRIDES) return;
    strncpy(g_overrides[g_override_count].ext, ext, 15);
    g_overrides[g_override_count].ext[15] = '\0';
    strncpy(g_overrides[g_override_count].plugin_name, plugin_name, 31);
    g_overrides[g_override_count].plugin_name[31] = '\0';
    g_override_count++;
}

int rewamp_registry_select_ranked(const char* path,
                                  const RewampPluginVTable** out, int maxOut) {
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
        int s = vt->probe(extPtr, header, headerSize);
        if (prefixPtr) {
            int sp = vt->probe(prefixPtr, header, headerSize);
            if (sp > s) s = sp;
        }
        if (s <= 0) continue;
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
    if (preferred && outN < maxOut) out[outN++] = preferred;
    for (int i = 0; i < n && outN < maxOut; ++i) out[outN++] = cand[i];
    return outN;
}

const RewampPluginVTable* rewamp_registry_select(const char* path) {
    const RewampPluginVTable* best = NULL;
    return rewamp_registry_select_ranked(path, &best, 1) > 0 ? best : NULL;
}
