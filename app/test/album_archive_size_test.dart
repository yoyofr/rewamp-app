import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

/// La sonde HEAD d'une archive d'album compare la taille SERVIE à une taille
/// attendue. Prise sur la première PISTE d'un album en fichiers séparés
/// (vgmrips), elle valait 6 812 octets contre 803 770 pour le zip: « copie
/// périmée », miroir abandonné, origine seule — 410 — et l'album ne jouait
/// plus du tout (« Sonic the Hedgehog 2 », 2026-11-03).
void main() {
  const zip =
      'https://vgmrips.net/files/MegaDrive/Sonic%20the%20Hedgehog%202%20%28Mega%20Drive%2C%20Genesis%29.zip';
  const vgz =
      'https://vgmrips.net/packs/vgm/MegaDrive/Sonic%20the%20Hedgehog%202%20%28Mega%20Drive%2C%20Genesis%29/04%20-%20Act%20Clear.vgz';

  test('la taille du catalogue pour l\'archive passe en premier', () {
    expect(RewampDb.albumArchiveExpectedSize(zip, 803770, vgz, 9683), 803770);
  });

  test('une piste séparée ne prête JAMAIS sa taille à l\'archive', () {
    expect(RewampDb.albumArchiveExpectedSize(zip, 0, vgz, 9683), 0);
    expect(RewampDb.albumArchiveExpectedSize(zip, 0, null, 9683), 0);
  });

  test('une ligne qui EST l\'archive (conteneur joshw) donne la sienne', () {
    const sevenZ = 'https://example.org/jw/Some%20Game.7z';
    expect(RewampDb.albumArchiveExpectedSize(sevenZ, 0, sevenZ, 1234), 1234);
    // même archive, buster de cache en plus: même clé
    expect(
        RewampDb.albumArchiveExpectedSize(
            sevenZ, 0, '$sevenZ?rcb=42', 1234),
        1234);
  });
}
