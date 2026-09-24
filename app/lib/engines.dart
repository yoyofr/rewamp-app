// Registry of the playback engines bundled in rewamp, each with its license and
// the format extensions it handles. Single source for the Credits screen and the
// "Formats lus" screen (engine_formats_screen.dart). Extension groups come from
// lib/formats.dart; vgmstream's set lives on RewampDb.
import 'formats.dart';
import 'l10n.dart';
import 'rewamp_db.dart' show RewampDb;

class DecoderEngine {
  final String name;         // engine / library name
  final String license;      // SPDX-ish short license
  /// Upstream project page, when a stable one is known — the credits row gets
  /// an "open" button. null = no link shown (rather than a guessed URL).
  final String? url;
  /// Author(s)/maintainer(s) as they credit themselves, when known. Proper
  /// nouns, so never translated.
  final String? author;
  /// One-line role, in French — the fallback used when the engine has no
  /// localized string yet. Prefer [descriptionOf].
  final String description;
  final Set<String> formats; // extensions it plays (may overlap other engines)

  const DecoderEngine({
    required this.name,
    required this.license,
    required this.description,
    required this.formats,
    this.url,
    this.author,
  });

  int get formatCount => formats.length;

  /// Localized one-line role. Keyed by [name] (unique across [kEngines]);
  /// falls back to the French [description] for an unknown engine.
  String descriptionOf(AppLocalizations l10n) => switch (name) {
        'libopenmpt'                 => l10n.engineDescOpenmpt,
        'libxmp'                     => l10n.engineDescXmp,
        'libvgm'                     => l10n.engineDescVgm,
        'Game Music Emu (libgme)'    => l10n.engineDescGme,
        'NSFPlay (libnsfplay)'       => l10n.engineDescNsfplay,
        'gbsplay (libgbsplay)'       => l10n.engineDescGbsplay,
        'libsidplayfp'               => l10n.engineDescSidplayfp,
        'NEZplug++'                  => l10n.engineDescNez,
        'libkss'                     => l10n.engineDescKss,
        'Furnace (DivEngine)'        => l10n.engineDescFurnace,
        'ZXTune'                     => l10n.engineDescZxtune,
        'UADE'                       => l10n.engineDescUade,
        'HivelyTracker'              => l10n.engineDescHively,
        'ASAP'                       => l10n.engineDescAsap,
        'AdPlug + libbinio'          => l10n.engineDescAdplug,
        'FluidLite + TinyMidiLoader' => l10n.engineDescMidi,
        'munt mt32emu'               => l10n.engineDescMt32,
        'Highly Experimental'        => l10n.engineDescHighlyExp,
        'libgsf (VBA)'               => l10n.engineDescGsf,
        'vio2sf (Cog / melonDS)'     => l10n.engineDescVio2sf,
        'SSEQPlayer (Naram Qashat)'  => l10n.engineDescNcsf,
        'v2redux (synthé V2 de Farbrausch)' => l10n.engineDescV2m,
        'AtariAudio (Arnaud Carré)'  => l10n.engineDescSndh,
        'libLazyusf (Mupen64plus)'   => l10n.engineDescLazyusf,
        'beetle-wswan (Mednafen)'    => l10n.engineDescWonderswan,
        'HighlyQuixotic'             => l10n.engineDescQsf,
        'highlytheoritical'          => l10n.engineDescHighlyTheoritical,
        'libpt3 (ayumi)'             => l10n.engineDescPt3,
        'Organya'                    => l10n.engineDescOrganya,
        'PxTone Collage'             => l10n.engineDescPxtone,
        'PMD'                        => l10n.engineDescPmd,
        'mdxplay'                    => l10n.engineDescMdx,
        'FMP (98fmplayer)'           => l10n.engineDescFmp,
        'eupmini'                    => l10n.engineDescEup,
        'sc68'                       => l10n.engineDescSc68,
        "Monkey's Audio (MACLib)"    => l10n.engineDescMac,
        'vgmstream'                  => l10n.engineDescVgmstream,
        'miniaudio'                  => l10n.engineDescMiniaudio,
        _                            => description,
      };
}

/// Every bundled decoder, registration order roughly matching rewamp_registry.c.
/// Some engines overlap (e.g. libgme + libnsfplay both read .nsf, libgme + libkss
/// both read .kss) — the "total formats" count below dedupes across engines.
const List<DecoderEngine> kEngines = [
  DecoderEngine(
    name: 'libopenmpt',
    url: 'https://lib.openmpt.org/libopenmpt/',
    author: 'OpenMPT team',
    license: 'BSD-3-Clause',
    description: 'Modules tracker (MOD/XM/S3M/IT/…)',
    formats: kTrackerExts,
  ),
  DecoderEngine(
    // ⚠️ Le NOM est la clé du switch de descriptionOf: le renommer sans
    // toucher au switch fait sortir la description en français partout.
    name: 'libxmp',
    url: 'https://github.com/libxmp/libxmp',
    author: 'Claudio Matsuoka, Hipolito Carraro Jr',
    license: 'MIT',
    description: 'Modules que libopenmpt ne lit pas (.musx, .liq, .fnk…)',
    formats: kXmpExts,
  ),
  DecoderEngine(
    name: 'libvgm',
    url: 'https://github.com/ValleyBell/libvgm',
    author: 'ValleyBell',
    license: 'GPL-2.0',
    description: 'VGM/S98/GYM/DRO — puces sonores, scope par canal',
    formats: kVgmChipExts,
  ),
  DecoderEngine(
    name: 'Game Music Emu (libgme)',
    url: 'https://github.com/libgme/game-music-emu',
    author: 'Shay Green (blargg), Michael Pyne',
    license: 'LGPL-2.1',
    description: 'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + archives RSN',
    formats: kGmeExts,
  ),
  DecoderEngine(
    name: 'NSFPlay (libnsfplay)',
    url: 'https://github.com/bbbradsmith/nsfplay',
    author: 'Brad Smith, Brezza',
    license: 'réutilisation libre, sans licence formelle',
    description: 'NES NSF/NSFe — voix par canal',
    formats: {'nsf', 'nsfe'},
  ),
  DecoderEngine(
    name: 'gbsplay (libgbsplay)',
    url: 'https://github.com/mmitch/gbsplay',
    author: 'Christian Garbs, Maximilian Rehkopf',
    license: 'GPL-1.0+',
    description: 'Game Boy GBS/GBR',
    formats: {'gbs', 'gbr'},
  ),
  DecoderEngine(
    name: 'libsidplayfp',
    url: 'https://github.com/libsidplayfp/libsidplayfp',
    author: 'Leandro Nini ; reSIDfp : Dag Lem, Antti Lankila',
    license: 'GPL-2.0',
    description: 'Commodore 64 SID (moteur reSIDfp)',
    formats: kSidExts,
  ),
  DecoderEngine(
    name: 'NEZplug++',
    url: 'https://bitbucket.org/wothke/webnez/src/master/',
    author: 'Mamiya ; portage webNEZ : Jürgen Wothke',
    license: 'PDS (domaine public)',
    description: 'PC-Engine HES + Sega SGC (SN76489/YM2413)',
    formats: {'hes', 'sgc'},
  ),
  DecoderEngine(
    name: 'libkss',
    url: 'https://github.com/digital-sound-antiques/libkss',
    author: 'Mitsutaka Okazaki',
    license: 'ISC (kss-drivers non couverts)',
    description: 'Chiptunes MSX (KSS/MGS/BGM/MPK/MBM/OPX)',
    formats: kKssExts,
  ),
  DecoderEngine(
    name: 'Furnace (DivEngine)',
    url: 'https://github.com/tildearrow/furnace',
    author: 'tildearrow',
    license: 'GPL-2.0',
    description: 'Chiptunes multi-puces .fur / FamiTracker .ftm',
    formats: kFurnaceExts,
  ),
  DecoderEngine(
    name: 'ZXTune',
    url: 'https://zxtune.bitbucket.io/',
    author: 'Vitamin/CAIG',
    license: 'GPL-3.0',
    description: 'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp',
    formats: kZxtuneExts,
  ),
  DecoderEngine(
    name: 'UADE',
    url: 'https://zakalwe.fi/uade/',
    author: 'Heikki Orsila ; patches webUADE+ : Jürgen Wothke',
    license: 'GPL-2.0 (+ songdb CC BY-NC-SA)',
    description: 'Formats Amiga custom-chip via émulation 68k (~320 exts)',
    formats: kUadeExts,
  ),
  DecoderEngine(
    name: 'HivelyTracker',
    url: 'http://www.hivelytracker.co.uk/',
    author: 'Pete Gordon, Xeron/IRIS',
    license: 'aucune licence explicite',
    description: 'AHX / Hively Tracker (.ahx/.hvl/.thx)',
    formats: {'ahx', 'hvl', 'thx'},
  ),
  DecoderEngine(
    name: 'ASAP',
    url: 'https://asap.sourceforge.net/',
    author: 'Piotr Fusik',
    license: 'GPL-2.0',
    description: 'Atari 8-bit POKEY (.sap/.rmt/.cmc/.tmc/…)',
    formats: kAsapExts,
  ),
  DecoderEngine(
    name: 'AdPlug + libbinio',
    url: 'https://adplug.github.io/',
    author: 'Simon Peter et al.',
    license: 'LGPL-2.1',
    description: 'AdLib OPL2/OPL3 (.d00/.hsc/.cmf/.a2m/.rol/…)',
    formats: kAdplugExts,
  ),
  DecoderEngine(
    name: 'FluidLite + TinyMidiLoader',
    url: 'https://github.com/divideconcept/FluidLite',
    author: 'Robin Lobel (FluidLite) ; Bernhard Schelling (tml.h)',
    license: 'LGPL-2.1 (FluidLite) / MIT (tml.h)',
    description: 'MIDI standard + SoundFont (.mid/.midi/.kar/.rmi)',
    formats: kMidiExts,
  ),
  DecoderEngine(
    name: 'munt mt32emu',
    url: 'https://github.com/munt/munt',
    author: 'Dean Beeler, Jerome Fisher, Sergey V. Mikayev',
    license: 'LGPL-2.1',
    description: 'Émulation Roland MT-32 / CM-32L pour le MIDI (.mid/.midi/.kar/.rmi)',
    formats: kMidiExts,
  ),
  DecoderEngine(
    name: 'Highly Experimental',
    url: 'https://github.com/kode54/Highly_Experimental',
    author: 'Neill Corlett ; Chris Moeller (kode54)',
    license: 'aucune licence explicite (Neill Corlett)',
    description: 'PlayStation PSF/PSF2',
    formats: kPsfExts,
  ),
  DecoderEngine(
    name: 'libgsf (VBA)',
    url: 'https://github.com/yshui/playgsf',
    author: 'VisualBoyAdvance team ; playgsf : yshui',
    license: 'GPL-2.0 (VBA) ; playgsf sans licence explicite',
    description: 'Game Boy Advance .gsf/.minigsf',
    formats: kGsfExts,
  ),
  DecoderEngine(
    name: 'vio2sf (Cog / melonDS)',
    // kode54/vio2sf a disparu de GitHub (404 en 2026-08); le plugin vit
    // désormais dans Cog, le lecteur du même auteur.
    url: 'https://github.com/losnoco/Cog',
    author: 'Chris Moeller (kode54) ; melonDS : Arisotura',
    license: 'GPL-3.0',
    description: 'Nintendo DS .2sf/.mini2sf',
    formats: kVio2sfExts,
  ),
  DecoderEngine(
    name: 'SSEQPlayer (Naram Qashat)',
    url: 'https://github.com/CyberBotX/SSEQPlayer',
    author: 'Naram Qashat (CyberBotX)',
    license: 'aucune licence explicite',
    description: 'Nintendo DS .ncsf/.minincsf — synthé SDAT/SSEQ (16 voix)',
    formats: kNcsfExts,
  ),
  DecoderEngine(
    name: 'snsf9x (snes9x / blargg)',
    url: 'https://github.com/loveemu/snsf9x',
    author: 'loveemu ; snes9x team',
    license: 'non commercial / usage personnel (snes9x)',
    description: 'Super Nintendo .snsf/.minisnsf — SPC700/S-DSP (8 voix)',
    formats: kSnsfExts,
  ),
  DecoderEngine(
    // Moteur remplacé le 2026-08-20: v2redux (portage C++17 propre, VERSION-NATIVE)
    // a pris la place du v2mplayer de Modizer. Le PORTAGE est CC0; le synthé V2
    // dont il dérive a été placé dans le domaine public par son auteur.
    name: 'v2redux (synthé V2 de Farbrausch)',
    url: 'https://github.com/spheenik/v2redux',
    author: 'Portage : spheenik — synthé V2 : Tammo \'kb\' Hinrichs',
    license: 'CC0-1.0 (portage) / domaine public (V2)',
    description: 'Synthé V2M (.v2m/.v2mz)',
    formats: kV2mExts,
  ),
  DecoderEngine(
    name: 'AtariAudio (Arnaud Carré)',
    url: 'https://github.com/arnaud-carre/sndh-player',
    author: 'Arnaud Carré (Leonard/Oxygene)',
    license: 'aucune licence explicite ; Musashi MIT',
    description: 'Atari ST .sndh — vraie émulation 68000 + YM2149 + DAC STE',
    formats: {'sndh'},
  ),
  DecoderEngine(
    name: 'PSG play',
    url: 'https://github.com/frno7/psgplay',
    author: 'Fredrik Noring',
    license: 'GPL-2.0',
    // Second .sndh engine, chosen in Réglages → Moteurs. It emulates the whole
    // machine, including the STE/TT LMC1992 tone and volume mixer (SNDH flag
    // 'l') that AtariAudio does not model.
    description: 'Atari ST .sndh — machine complète, mixeur LMC1992',
    formats: {'sndh'},
  ),
  DecoderEngine(
    name: 'libLazyusf (Mupen64plus)',
    // Idem: kode54/lazyusf2 a disparu, Cog en garde une copie vivante.
    url: 'https://github.com/losnoco/Cog',
    author: 'Chris Moeller (kode54) ; Mupen64Plus team',
    license: 'GPL-2.0',
    description: 'Nintendo 64 .usf — émulation R4300 + RSP audio',
    formats: kLazyusfExts,
  ),
  DecoderEngine(
    // A remplacé OSwan (aucune licence explicite, aucune source publique),
    // retiré du dépôt le 2026-07-26.
    name: 'beetle-wswan (Mednafen)',
    url: 'https://github.com/libretro/beetle-wswan-libretro',
    author: 'Mednafen team (Ryphecha) ; portage libretro ; Blip_Buffer : Shay Green',
    license: 'GPL-2.0+ ; Blip_Buffer LGPL-2.1+',
    description: 'WonderSwan .wsr — émulation NEC V30MZ',
    formats: kWonderswanExts,
  ),
  DecoderEngine(
    name: 'HighlyQuixotic',
    url: 'https://github.com/kode54/Highly_Quixotic',
    author: 'Neill Corlett ; Chris Moeller (kode54)',
    license: 'aucune licence explicite (Neill Corlett)',
    description: 'Capcom QSound .qsf — Z80 + puce QSound',
    formats: kHighlyQuixoticExts,
  ),
  DecoderEngine(
    name: 'highlytheoritical',
    url: 'https://github.com/kode54/Highly_Theoretical',
    author: 'Neill Corlett ; Chris Moeller (kode54)',
    license: 'aucune licence explicite ; m68k Musashi non commercial',
    description: 'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP',
    formats: kHighlyTheoriticalExts,
  ),
  DecoderEngine(
    name: 'libpt3 (ayumi)',
    url: 'https://github.com/true-grue/ayumi',
    author: 'Peter Sovietov (ayumi)',
    license: 'ayumi MIT ; libpt3 sans licence explicite',
    description: 'ZX Spectrum .pt3 — vrai synthé AY-3-8910/YM2149',
    formats: kLibpt3Exts,
  ),
  DecoderEngine(
    name: 'Organya',
    url: 'https://www.wothke.ch/',
    author: 'Daisuke Amaya (Pixel) ; portage webPixel : Jürgen Wothke',
    license: 'WTFPL',
    description: 'Cave Story .org — moteur natif de Pixel',
    formats: kOrganyaExts,
  ),
  DecoderEngine(
    name: 'PxTone Collage',
    url: 'https://pxtone.org/',
    author: 'Daisuke Amaya (STUDIO PIXEL)',
    license: 'MIT (STUDIO PIXEL)',
    description: 'Tracker de Pixel — .ptcop/.pttune',
    formats: kPxtoneExts,
  ),
  DecoderEngine(
    name: 'PMD',
    url: 'https://github.com/mistydemeo/pmdmini',
    author: 'M. Kajihara (KAJA) ; pmdmini : Misty De Meo ; ymfm : Aaron Giles',
    license: 'GPL-2.0',
    description: 'PC-98 Professional Music Driver — .m/.m2/.mz',
    formats: kPmdExts,
  ),
  DecoderEngine(
    name: 'mdxplay',
    url: 'https://github.com/gzaffin/mdxmini',
    author: 'mdxmini : Giuseppe Zaffin (gzaffin)',
    license: 'GPL-2.0+',
    description: 'Sharp X68000 — .mdx (+ échantillons .pdx)',
    formats: kMdxExts,
  ),
  DecoderEngine(
    name: 'FMP (98fmplayer)',
    url: 'https://github.com/myon98/98fmplayer',
    author: 'あぼ (Abo) ; 98fmplayer : myon98',
    license: 'BSD-2-Clause (98fmplayer)',
    description: 'PC-98 FMP — OPNA + PPZ8 (.opi/.ovi/.ozi)',
    formats: kFmpExts,
  ),
  DecoderEngine(
    name: 'eupmini',
    url: 'https://github.com/gzaffin/eupmini',
    author: 'eupmini : Giuseppe Zaffin (gzaffin)',
    license: 'GPL-2.0 (+ mame / Nuked-OPN2)',
    description: 'FM Towns EUPHONY — YM2612 + PCM (.eup)',
    formats: kEupExts,
  ),
  DecoderEngine(
    name: 'sc68',
    url: 'https://sourceforge.net/projects/sc68/',
    author: 'Benjamin Gerard',
    license: 'GPL-3.0',
    description: 'Atari ST (YM2149/STE) + Amiga (Paula) — vrai 68000 emu68',
    formats: kSc68Exts,
  ),
  DecoderEngine(
    name: 'SunVox',
    url: 'https://warmplace.ru/soft/sunvox/',
    // The SunVox library license asks for a visible credit; the engine row
    // carries it (no separate tile — it is an engine like the others).
    author: '© 2008–2026 Alexander Zolotov · WarmPlace.ru',
    license: 'SunVox (usage libre + attribution)',
    description: 'Synthé modulaire + tracker (.sunvox) — Alexander Zolotov',
    formats: kSunvoxExts,
  ),
  DecoderEngine(
    name: 'TIATracker',
    url: 'https://bitbucket.org/kylearan/tiatracker/',
    // The tracker application is GPLv2, but only its PLAYER ROUTINE is used
    // here, and that one is Apache-2.0 — which requires the attribution.
    // Sound emulation is Stella's TIA core (GPL-2.0).
    author: 'Andre « Kylearan » Wichmann · TIA emu: Stella',
    license: 'Apache-2.0 (routine de replay) + GPL-2.0 (TIA Stella)',
    description: 'Atari VCS 2600 (TIA, 2 voies) — .ttt',
    formats: kTiaTrackerExts,
  ),
  DecoderEngine(
    name: "Monkey's Audio (MACLib)",
    url: 'https://monkeysaudio.com/',
    author: 'Matthew T. Ashland',
    license: 'propriétaire (source dispo)',
    description: 'Lossless .ape',
    formats: kApeExts,
  ),
  DecoderEngine(
    name: 'vgmstream',
    url: 'https://vgmstream.org/',
    author: 'vgmstream team (bnnm, kode54, …)',
    license: 'ISC + licences des dépendances',
    description: 'Formats audio de jeux streamés (700+, dont .rrds)',
    formats: RewampDb.kVgmstreamExts,
  ),
  DecoderEngine(
    name: 'miniaudio',
    url: 'https://miniaud.io/',
    author: 'David Reid',
    license: 'MIT-0 / domaine public',
    description: 'PCM/MP3/FLAC/OGG — décodeur de repli',
    formats: kPlainAudioExts,
  ),
];

/// Distinct extensions across all engines (overlaps deduped).
final int kTotalFormatCount =
    kEngines.expand((e) => e.formats).toSet().length;

/// Bundled third-party components that are NOT decoders — they play no format,
/// so they are deliberately outside [kEngines] (which feeds the format counter)
/// and are listed on their own in the credits. Name + license only: both are
/// proper nouns, so nothing here needs translating.
class BundledComponent {
  final String name;
  final String license;
  final String? url;
  final String? author;
  const BundledComponent(this.name, this.license, {this.url, this.author});
}

const List<BundledComponent> kComponents = [
  // FAC Soundtracker: le `.MUS` est enveloppé avec FST2.BIN — le replayer FAC
  // d'ORIGINE, redistribué tel quel — dans une image KSS que la VM Z80 de
  // libkss exécute. Le binaire porte « (C)1990/1991 FAC / All rights
  // reserved »: il est redistribué, donc il se crédite, comme les drivers MSX
  // que libkss embarque déjà (son propre LICENSE.md exclut explicitement
  // kss-drivers de sa licence). Le convertisseur, lui, vient d'un script de
  // NYYRIKKI porté en C.
  BundledComponent('FAC Soundtracker (FST2.BIN + mus2kss)',
      'Replayer © FAC, tous droits réservés',
      url: 'https://www.msx.org/wiki/FAC_Soundtracker',
      author: 'FAC ; conversion : NYYRIKKI'),
  BundledComponent('ProWizard (libxmp)', 'MIT',
      url: 'https://xmp.sourceforge.net/',
      author: "Claudio Matsuoka ; ProWizard : Sylvain 'Asle' Chipaux"),
  // Table MT-32 → General MIDI: un MIDI écrit pour MT-32 numérote ses
  // programmes dans la liste d'usine du MT-32, sans rapport avec le GM. Sans
  // ROMs Roland, FluidLite les traduit avec cette table. Vendorée depuis la
  // v2.0.0 de ScummVM et PAS depuis son master: les valeurs sont identiques,
  // mais la v2.0.0 est GPL-2.0-or-later là où master est passé en GPL-3 —
  // autant ne pas ajouter un composant GPL-3 de plus (voir LICENSING.md).
  BundledComponent('ScummVM (table MT-32 → General MIDI)', 'GPL-2.0-or-later',
      url: 'https://github.com/scummvm/scummvm',
      author: 'ScummVM team'),
  BundledComponent('webUADE (patches audio.device)', 'GPL-2.0',
      url: 'https://www.wothke.ch/', author: 'Jürgen Wothke'),
  BundledComponent('projectM', 'LGPL-2.1',
      url: 'https://github.com/projectM-visualizer/projectm',
      author: 'projectM team'),
  // Preset-transition patterns ported from Milkwave's blend patterns
  // (plugin_blendpatterns.cpp). BSD-3 requires the attribution, hence a row of
  // its own rather than a code comment.
  BundledComponent('Milkwave (motifs de transition)', 'BSD-3-Clause',
      url: 'https://github.com/IkeC/Milkwave',
      author: 'Milkwave (fork de BeatDrop)'),
  BundledComponent('FFmpeg (ffmpeg-kit)', 'LGPL-3.0',
      url: 'https://ffmpeg.org/', author: 'FFmpeg team'),
  BundledComponent('ANGLE', 'BSD-3-Clause',
      url: 'https://chromium.googlesource.com/angle/angle',
      author: 'Google'),
  // Shadertoy shader adapted for the spectrum's "line" palette. CC BY 3.0
  // REQUIRES the credit, hence its own row rather than a code comment.
  BundledComponent('Audio visualizer (Shadertoy)', 'CC BY 3.0',
      url: 'https://www.shadertoy.com/view/ttfGzH',
      author: 'Jan Mróz (jaszunio15)'),
  // Archives (.zip/.7z/.rar/.lha/.gz/.tar) — le RSN de libgme en dépend aussi.
  BundledComponent('libarchive', 'BSD-2-Clause',
      url: 'https://www.libarchive.org/', author: 'Tim Kientzle'),
  BundledComponent('liblzma (XZ Utils)', '0BSD',
      url: 'https://tukaani.org/xz/', author: 'Lasse Collin'),
  // ⚠️ Licence PARTICULIÈRE, et c'est pourquoi elle est citée telle quelle: le
  // code UnRAR peut être utilisé pour DÉCOMPRESSER du RAR, mais pas pour
  // recréer l'algorithme de compression. On ne fait que décompresser (les RAR
  // solides, que libarchive ne sait pas ouvrir).
  BundledComponent('UnRAR', 'licence UnRAR (décompression uniquement)',
      url: 'https://www.rarlab.com/license.htm', author: 'Alexander Roshal'),
  // Compilés depuis l'arbre vendoré par le submodule libopenmpt, pour le
  // décodeur Vorbis « custom » de vgmstream (Wwise, FSB, OGL…). Licence LUE
  // dans leur COPYING, pas de mémoire.
  BundledComponent('libogg', 'BSD-3-Clause',
      url: 'https://xiph.org/ogg/', author: 'Xiph.Org Foundation'),
  BundledComponent('libvorbis', 'BSD-3-Clause',
      url: 'https://xiph.org/vorbis/', author: 'Xiph.Org Foundation'),
  // Chargeur commun à toute la famille PSF (gsf/2sf/ncsf/usf/qsf/ssf/dsf/snsf).
  BundledComponent('libpsflib', 'aucune licence explicite',
      url: 'https://gitlab.com/kode54/psflib',
      author: 'Chris Moeller (kode54)'),
  // Le visualiseur de patterns EMBARQUE quatre polices dans des en-têtes C
  // (src/rewamp_pattern_font*.h) — ce sont des fontes REDISTRIBUÉES, donc
  // créditées ici, pas seulement le moteur de rastérisation.
  BundledComponent('stb_truetype (rastérisation)', 'domaine public / MIT',
      url: 'https://github.com/nothings/stb', author: 'Sean Barrett'),
  BundledComponent('JetBrains Mono (police par défaut)', 'SIL OFL 1.1',
      url: 'https://www.jetbrains.com/lp/mono/',
      author: 'The JetBrains Mono Project Authors'),
  BundledComponent('unscii-16 (police bitmap)', 'domaine public / CC0',
      url: 'http://viznut.fi/unscii/', author: 'Viznut'),
  // Deux en-tetes, une seule fonte: la bitmap 8x10 (font1) et sa VECTORISATION
  // en TTF pour l'atlas stb_truetype. Un seul credit.
  BundledComponent('ft2-clone (police FastTracker 2)', 'BSD-3-Clause',
      url: 'https://github.com/8bitbubsy/ft2-clone',
      author: 'Olav Sørensen'),
  BundledComponent('libchpconv (CHIPNSFX)', 'GPL-3.0',
      url: 'http://cngsoft.no-ip.org/chipnsfx.htm',
      author: 'Cesar Nicolas-Gonzalez / CNGSOFT'),
];
