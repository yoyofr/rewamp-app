import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

/// La release scene.org « eightbm_tomarkus_chipcompo » (compo Chip MSX de
/// Xenium 2024) livre le même morceau DEUX fois: un `.prg` de 4 200 octets —
/// un exécutable C64 que libsidplayfp joue — et un `.sng` de 21 288 octets,
/// qui est le SOURCE GoatTracker 2. Les deux sont au palier 1, l'égalité se
/// départage à la taille DÉCROISSANTE, et c'est donc le source qui sortait:
/// aucun moteur ne lit GoatTracker, le morceau ne jouait pas du tout.
void main() {
  Future<Directory> release({required bool goatTrackerMagic}) async {
    final d = await Directory.systemTemp.createTemp('rel');
    // Un exécutable C64: en-tête d'adresse de chargement $0801 puis du binaire.
    final prg = Uint8List(4200)..[0] = 0x01..[1] = 0x08..[2] = 0x0b;
    await File('${d.path}/interstellar_abduction.prg').writeAsBytes(prg);
    final sng = Uint8List(21288);
    if (goatTrackerMagic) {
      // « GTS5 » — GoatTracker 2. Sans cette magie, le même suffixe désigne un
      // module ZoundMonitor AMIGA, que UADE joue vraiment.
      sng.setRange(0, 4, 'GTS5'.codeUnits);
    } else {
      sng.setRange(0, 4, [0x00, 0x01, 0x02, 0x03]);
    }
    await File('${d.path}/interstellar_abduction.sng').writeAsBytes(sng);
    await File('${d.path}/interstellar_abduction.txt')
        .writeAsString('release name: interstellar abduction\n');
    return d;
  }

  test('un .sng GoatTracker est écarté: le .prg jouable sort', () async {
    final d = await release(goatTrackerMagic: true);
    final picked = await RewampDb.debugFindExtractedAudio(d.path);
    expect(picked, isNotNull);
    expect(picked!.endsWith('.prg'), isTrue,
        reason: 'le source GoatTracker ne doit pas gagner: $picked');
  });

  test('un .sng SANS la magie GoatTracker reste candidat (ZoundMonitor Amiga)',
      () async {
    final d = await release(goatTrackerMagic: false);
    final picked = await RewampDb.debugFindExtractedAudio(d.path);
    expect(picked, isNotNull);
    // La règle est NÉGATIVE et porte sur le CONTENU: sans la magie, rien ne
    // change — le classement par taille sert le .sng comme avant.
    expect(picked!.endsWith('.sng'), isTrue, reason: picked);
  });
}
