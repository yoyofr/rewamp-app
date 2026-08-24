# Third-party notices

Rewamp bundles the decoders, visualizers and support libraries
listed below. Each keeps its own licence and its own authors;
this file exists so the binary states what it redistributes.

**Generated — do not edit by hand.** The source of truth is
`app/lib/engines.dart`, the same list the app shows under
Settings → About. Regenerate with:

```bash
cd app && REWAMP_WRITE_NOTICES=1 \
  flutter test test/third_party_notices_test.dart
```

(a `flutter test`, not a `dart run`: engines.dart pulls in the
FFI plugin, which the plain Dart VM refuses to compile. The same
test CHECKS the file without the variable, so a row added
without regenerating turns the suite red.)

See [LICENSING.md](LICENSING.md) for how these licences combine,
and for the two that constrain what may be redistributed.

## Playback engines (40)

1235 file extensions across all of them.

| Engine | Licence | Authors | Role |
| --- | --- | --- | --- |
| [AdPlug + libbinio](https://adplug.github.io/) | LGPL-2.1 | Simon Peter et al. | AdLib OPL2/OPL3 (.d00/.hsc/.cmf/.a2m/.rol/…) |
| [ASAP](https://asap.sourceforge.net/) | GPL-2.0 | Piotr Fusik | Atari 8-bit POKEY (.sap/.rmt/.cmc/.tmc/…) |
| [AtariAudio (Arnaud Carré)](https://github.com/arnaud-carre/sndh-player) | aucune licence explicite ; Musashi MIT | Arnaud Carré (Leonard/Oxygene) | Atari ST .sndh — vraie émulation 68000 + YM2149 + DAC STE |
| [beetle-wswan (Mednafen)](https://github.com/libretro/beetle-wswan-libretro) | GPL-2.0+ ; Blip_Buffer LGPL-2.1+ | Mednafen team (Ryphecha) ; portage libretro ; Blip_Buffer : Shay Green | WonderSwan .wsr — émulation NEC V30MZ |
| [eupmini](https://github.com/gzaffin/eupmini) | GPL-2.0 (+ mame / Nuked-OPN2) | eupmini : Giuseppe Zaffin (gzaffin) | FM Towns EUPHONY — YM2612 + PCM (.eup) |
| [FluidLite + TinyMidiLoader](https://github.com/divideconcept/FluidLite) | LGPL-2.1 (FluidLite) / MIT (tml.h) | Robin Lobel (FluidLite) ; Bernhard Schelling (tml.h) | MIDI standard + SoundFont (.mid/.midi/.kar/.rmi) |
| [FMP (98fmplayer)](https://github.com/myon98/98fmplayer) | BSD-2-Clause (98fmplayer) | あぼ (Abo) ; 98fmplayer : myon98 | PC-98 FMP — OPNA + PPZ8 (.opi/.ovi/.ozi) |
| [Furnace (DivEngine)](https://github.com/tildearrow/furnace) | GPL-2.0 | tildearrow | Chiptunes multi-puces .fur / FamiTracker .ftm |
| [Game Music Emu (libgme)](https://github.com/libgme/game-music-emu) | LGPL-2.1 | Shay Green (blargg), Michael Pyne | NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + archives RSN |
| [gbsplay (libgbsplay)](https://github.com/mmitch/gbsplay) | GPL-1.0+ | Christian Garbs, Maximilian Rehkopf | Game Boy GBS |
| [Highly Experimental](https://github.com/kode54/Highly_Experimental) | aucune licence explicite (Neill Corlett) | Neill Corlett ; Chris Moeller (kode54) | PlayStation PSF/PSF2 |
| [HighlyQuixotic](https://github.com/kode54/Highly_Quixotic) | aucune licence explicite (Neill Corlett) | Neill Corlett ; Chris Moeller (kode54) | Capcom QSound .qsf — Z80 + puce QSound |
| [highlytheoritical](https://github.com/kode54/Highly_Theoretical) | aucune licence explicite ; m68k Musashi non commercial | Neill Corlett ; Chris Moeller (kode54) | Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP |
| [HivelyTracker](http://www.hivelytracker.co.uk/) | aucune licence explicite | Pete Gordon, Xeron/IRIS | AHX / Hively Tracker (.ahx/.hvl/.thx) |
| [libgsf (VBA)](https://github.com/yshui/playgsf) | GPL-2.0 (VBA) ; playgsf sans licence explicite | VisualBoyAdvance team ; playgsf : yshui | Game Boy Advance .gsf/.minigsf |
| [libkss](https://github.com/digital-sound-antiques/libkss) | ISC (kss-drivers non couverts) | Mitsutaka Okazaki | Chiptunes MSX (KSS/MGS/BGM/MPK/MBM/OPX) |
| [libLazyusf (Mupen64plus)](https://github.com/losnoco/Cog) | GPL-2.0 | Chris Moeller (kode54) ; Mupen64Plus team | Nintendo 64 .usf — émulation R4300 + RSP audio |
| [libopenmpt](https://lib.openmpt.org/libopenmpt/) | BSD-3-Clause | OpenMPT team | Modules tracker (MOD/XM/S3M/IT/…) |
| [libpt3 (ayumi)](https://github.com/true-grue/ayumi) | ayumi MIT ; libpt3 sans licence explicite | Peter Sovietov (ayumi) | ZX Spectrum .pt3 — vrai synthé AY-3-8910/YM2149 |
| [libsidplayfp](https://github.com/libsidplayfp/libsidplayfp) | GPL-2.0 | Leandro Nini ; reSIDfp : Dag Lem, Antti Lankila | Commodore 64 SID (moteur reSIDfp) |
| [libvgm](https://github.com/ValleyBell/libvgm) | GPL-2.0 | ValleyBell | VGM/S98/GYM/DRO — puces sonores, scope par canal |
| [mdxplay](https://github.com/gzaffin/mdxmini) | GPL-2.0+ | mdxmini : Giuseppe Zaffin (gzaffin) | Sharp X68000 — .mdx (+ échantillons .pdx) |
| [miniaudio](https://miniaud.io/) | MIT-0 / domaine public | David Reid | PCM/MP3/FLAC/OGG — décodeur de repli |
| [Monkey's Audio (MACLib)](https://monkeysaudio.com/) | propriétaire (source dispo) | Matthew T. Ashland | Lossless .ape |
| [NEZplug++](https://bitbucket.org/wothke/webnez/src/master/) | PDS (domaine public) | Mamiya ; portage webNEZ : Jürgen Wothke | PC-Engine HES + Sega SGC (SN76489/YM2413) |
| [NSFPlay (libnsfplay)](https://github.com/bbbradsmith/nsfplay) | réutilisation libre, sans licence formelle | Brad Smith, Brezza | NES NSF/NSFe — voix par canal |
| [Organya](https://www.wothke.ch/) | WTFPL | Daisuke Amaya (Pixel) ; portage webPixel : Jürgen Wothke | Cave Story .org — moteur natif de Pixel |
| [PMD](https://github.com/mistydemeo/pmdmini) | GPL-2.0 | M. Kajihara (KAJA) ; pmdmini : Misty De Meo ; ymfm : Aaron Giles | PC-98 Professional Music Driver — .m/.m2/.mz |
| [PSG play](https://github.com/frno7/psgplay) | GPL-2.0 | Fredrik Noring | Atari ST .sndh — machine complète, mixeur LMC1992 |
| [PxTone Collage](https://pxtone.org/) | MIT (STUDIO PIXEL) | Daisuke Amaya (STUDIO PIXEL) | Tracker de Pixel — .ptcop/.pttune |
| [sc68](https://sourceforge.net/projects/sc68/) | GPL-3.0 | Benjamin Gerard | Atari ST (YM2149/STE) + Amiga (Paula) — vrai 68000 emu68 |
| [snsf9x (snes9x / blargg)](https://github.com/loveemu/snsf9x) | non commercial / usage personnel (snes9x) | loveemu ; snes9x team | Super Nintendo .snsf/.minisnsf — SPC700/S-DSP (8 voix) |
| [SSEQPlayer (Naram Qashat)](https://github.com/CyberBotX/SSEQPlayer) | aucune licence explicite | Naram Qashat (CyberBotX) | Nintendo DS .ncsf/.minincsf — synthé SDAT/SSEQ (16 voix) |
| [SunVox](https://warmplace.ru/soft/sunvox/) | SunVox (usage libre + attribution) | © 2008–2026 Alexander Zolotov · WarmPlace.ru | Synthé modulaire + tracker (.sunvox) — Alexander Zolotov |
| [TIATracker](https://bitbucket.org/kylearan/tiatracker/) | Apache-2.0 (routine de replay) + GPL-2.0 (TIA Stella) | Andre « Kylearan » Wichmann · TIA emu: Stella | Atari VCS 2600 (TIA, 2 voies) — .ttt |
| [UADE](https://zakalwe.fi/uade/) | GPL-2.0 (+ songdb CC BY-NC-SA) | Heikki Orsila ; patches webUADE+ : Jürgen Wothke | Formats Amiga custom-chip via émulation 68k (~320 exts) |
| [v2redux (synthé V2 de Farbrausch)](https://github.com/spheenik/v2redux) | CC0-1.0 (portage) / domaine public (V2) | Portage : spheenik — synthé V2 : Tammo 'kb' Hinrichs | Synthé V2M (.v2m/.v2mz) |
| [vgmstream](https://vgmstream.org/) | ISC + licences des dépendances | vgmstream team (bnnm, kode54, …) | Formats audio de jeux streamés (700+, dont .rrds) |
| [vio2sf (Cog / melonDS)](https://github.com/losnoco/Cog) | GPL-3.0 | Chris Moeller (kode54) ; melonDS : Arisotura | Nintendo DS .2sf/.mini2sf |
| [ZXTune](https://zxtune.bitbucket.io/) | GPL-3.0 | Vitamin/CAIG | ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp |

## Bundled components (18)

Everything the binary redistributes that is not a decoder:
archive handling, the visualizer, fonts, shaders, data sets.

| Component | Licence | Authors |
| --- | --- | --- |
| [ANGLE](https://chromium.googlesource.com/angle/angle) | BSD-3-Clause | Google |
| [Audio visualizer (Shadertoy)](https://www.shadertoy.com/view/ttfGzH) | CC BY 3.0 | Jan Mróz (jaszunio15) |
| [FFmpeg (ffmpeg-kit)](https://ffmpeg.org/) | LGPL-3.0 | FFmpeg team |
| [ft2-clone (police FastTracker 2)](https://github.com/8bitbubsy/ft2-clone) | BSD-3-Clause | Olav Sørensen |
| [JetBrains Mono (police par défaut)](https://www.jetbrains.com/lp/mono/) | SIL OFL 1.1 | The JetBrains Mono Project Authors |
| [libarchive](https://www.libarchive.org/) | BSD-2-Clause | Tim Kientzle |
| [libchpconv (CHIPNSFX)](http://cngsoft.no-ip.org/chipnsfx.htm) | GPL-3.0 | Cesar Nicolas-Gonzalez / CNGSOFT |
| [liblzma (XZ Utils)](https://tukaani.org/xz/) | 0BSD | Lasse Collin |
| [libogg](https://xiph.org/ogg/) | BSD-3-Clause | Xiph.Org Foundation |
| [libpsflib](https://gitlab.com/kode54/psflib) | aucune licence explicite | Chris Moeller (kode54) |
| [libvorbis](https://xiph.org/vorbis/) | BSD-3-Clause | Xiph.Org Foundation |
| [Milkwave (motifs de transition)](https://github.com/IkeC/Milkwave) | BSD-3-Clause | Milkwave (fork de BeatDrop) |
| [projectM](https://github.com/projectM-visualizer/projectm) | LGPL-2.1 | projectM team |
| [ProWizard (libxmp)](https://xmp.sourceforge.net/) | MIT | Claudio Matsuoka ; ProWizard : Sylvain 'Asle' Chipaux |
| [stb_truetype (rastérisation)](https://github.com/nothings/stb) | domaine public / MIT | Sean Barrett |
| [UnRAR](https://www.rarlab.com/license.htm) | licence UnRAR (décompression uniquement) | Alexander Roshal |
| [unscii-16 (police bitmap)](http://viznut.fi/unscii/) | domaine public / CC0 | Viznut |
| [webUADE (patches audio.device)](https://www.wothke.ch/) | GPL-2.0 | Jürgen Wothke |

## UnRAR — required notice

The UnRAR licence requires the following paragraph to be
reproduced in the licence or documentation of any package that
includes it. The full text is in
`packages/rewamp_audio/third_party/unrar/license.txt`.

> UnRAR source code may be used in any software to handle RAR
> archives without limitations free of charge, but cannot be
> used to develop RAR (WinRAR) compatible archiver and to
> re-create RAR compression algorithm, which is proprietary.
> Distribution of modified UnRAR source code in separate form
> or as a part of other software is permitted, provided that
> full text of this paragraph, starting from "UnRAR source
> code" words, is included in license, or in documentation if
> license is not available, and in source code comments of
> resulting package.

## Attribution asked for by name

Some licences ask for a visible credit rather than only a file.
These appear in the app itself, under Settings → About:

- **SunVox** — © 2008–2026 Alexander Zolotov · WarmPlace.ru
  (the vendored sources are MIT; the credit is asked for by the
  project and carried on its engine row).
- **UADE song database** — CC BY-NC-SA, per-subsong lengths.
- **Milkwave** — BSD-3, preset-transition patterns.
- **Shadertoy spectrum shader** — CC BY 3.0, Jan Mróz.
