import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/platform_artwork.dart';
void main() {
  test('platformForName sur les vrais noms du catalogue', () {
    const cases = {
      'Amiga': SoundPlatform.amiga,
      'Amstrad CPC': SoundPlatform.amstradCpc,
      'Atari 8-bit': SoundPlatform.atari8,
      'Atari 5200': SoundPlatform.atari8,
      'Atari ST': SoundPlatform.atariST,
      'C64': SoundPlatform.c64,
      'Dreamcast': SoundPlatform.segaDreamcast,
      'FM Towns': SoundPlatform.fmTowns,
      'Famicom Disk System': SoundPlatform.nes,
      'NES': SoundPlatform.nes,
      'SNES': SoundPlatform.snes,
      'Game Boy': SoundPlatform.gameboy,
      'Game Boy Color': SoundPlatform.gameboy,
      'Game Boy Advance': SoundPlatform.gba,
      'Game Gear': SoundPlatform.segaGenesis,
      'Mega Drive': SoundPlatform.segaGenesis,
      'Master System': SoundPlatform.segaGenesis,
      'Sega CD': SoundPlatform.segaGenesis,
      'Sega Saturn': SoundPlatform.segaSaturn,
      'SG-1000': SoundPlatform.segaGenesis,
      '32X': SoundPlatform.segaGenesis,
      'MSX': SoundPlatform.msx,
      'MSX2+': SoundPlatform.msx,
      'MSX turbo R': SoundPlatform.msx,
      'Nintendo 64': SoundPlatform.n64,
      'Nintendo DS': SoundPlatform.nds,
      'PC Engine': SoundPlatform.pcEngine,
      'PC Engine CD': SoundPlatform.pcEngine,
      'SuperGrafx': SoundPlatform.pcEngine,
      'PC-88': SoundPlatform.pc98,
      'PC-98': SoundPlatform.pc98,
      'PlayStation': SoundPlatform.playstation,
      'PlayStation 2': SoundPlatform.playstation,
      'Sharp X68000': SoundPlatform.x68000,
      'WonderSwan Color': SoundPlatform.wonderswan,
      'ZX Spectrum': SoundPlatform.zxSpectrum,
      'IBM PC': SoundPlatform.adlib,
      // Sans marque dédiée -> générique, volontairement.
      'Apple II': SoundPlatform.rewamp,
      'Arcade': SoundPlatform.rewamp,
      'Neo Geo Pocket Color': SoundPlatform.rewamp,
      'PC-FX': SoundPlatform.rewamp,
      'Vectrex': SoundPlatform.rewamp,
      'X1': SoundPlatform.rewamp,
      'PC Tracked Music': SoundPlatform.rewamp,
      '': SoundPlatform.rewamp,
    };
    cases.forEach((k, v) => expect(platformForName(k), v, reason: k));
    // Un conteneur ne doit JAMAIS impliquer une plateforme.
    for (final e in ['lha', 'lzh', 'zip', '7z']) {
      expect(platformForExt(e), SoundPlatform.rewamp, reason: e);
    }
    // Le nom prime sur l'extension conteneur.
    expect(platformAssetFor(platformName: 'Amiga', pathOrExt: 'lha'),
        platformAssetForPlatform(SoundPlatform.amiga));
    expect(platformAssetFor(platformName: 'Sharp X68000', pathOrExt: 'lzh'),
        platformAssetForPlatform(SoundPlatform.x68000));
  });
}
