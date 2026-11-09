import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

// Le repli « chemin connu en base » de downloadToLibrary ne doit jamais
// substituer un AUTRE morceau (rangs de tracklist qui glissent, UnExoticA
// « Denaris » 2026-11-06).
void main() {
  const dir = '/x/online/unexotica/b5a9e5b4/Denaris';

  test('même nom de fichier: accepté (chemin dérivé qui a bougé)', () {
    expect(RewampDb.knownPathFitsRow('/old/place/dz.title', 'Denaris/dz.title'),
        isTrue);
  });

  test('rang glissé vers un autre membre: refusé', () {
    expect(
        RewampDb.knownPathFitsRow('$dir/Darius_Zendeh_Player/Darius Zendeh',
            'Denaris/Mark_II_Version/mii.game_end'),
        isFalse);
    expect(
        RewampDb.knownPathFitsRow(
            '$dir/dz.title', 'Denaris/Mark_II_Version/mii.title'),
        isFalse);
  });

  test('préfixe Amiga: même radical, autre morceau: refusé', () {
    expect(RewampDb.knownPathFitsRow('$dir/dz.game_end', 'Denaris/dz.title'),
        isFalse);
  });

  test('extension de format différente, même radical: accepté', () {
    expect(
        RewampDb.knownPathFitsRow(
            '/a/Audio Track 01.ogg', 'Audio Track 01.wav'),
        isTrue);
  });

  test('RSN joué en place: accepté', () {
    expect(RewampDb.knownPathFitsRow('/a/Super Mario World.rsn', 'ct-06.spc'),
        isTrue);
  });

  test('ligne sans nom: rien à vérifier', () {
    expect(RewampDb.knownPathFitsRow('/a/b.mod', ''), isTrue);
  });
}
