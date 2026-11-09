import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

/// Même fichier à une autre adresse = déplacement, jamais un remplacement:
/// la purge d'un album en archive se faisait à CHAQUE piste quand le serveur a
/// fait de son miroir l'url principale (Atelier Annie jw_2sf, 2026-11-07).
void main() {
  const joshw = 'https://2sf.joshw.info/a/Atelier%20Annie%20-%20Alchemists'
      '%20of%20Sera%20Island%20%5bNDS%5d.7z';
  const mirror = 'https://files.rewamp.app/2sf/a/Atelier%20Annie%20-%20'
      'Alchemists%20of%20Sera%20Island%20%5bNDS%5d.7z';

  test('origine → miroir, même nom: déplacement', () {
    expect(RewampDb.sourceUrlIsRelocation(joshw, mirror), isTrue);
  });

  test('encodage différent du même nom: déplacement', () {
    expect(
        RewampDb.sourceUrlIsRelocation(
            'https://a.example/x/My%20Song.7z', 'https://b.example/My Song.7z'),
        isTrue);
  });

  test('autre nom de fichier: remplacement', () {
    expect(
        RewampDb.sourceUrlIsRelocation(
            'https://a.example/x/Album.7z', 'https://a.example/x/Album (fix).7z'),
        isFalse);
  });

  test('override: jamais un déplacement', () {
    expect(
        RewampDb.sourceUrlIsRelocation('https://a.example/x/song.mod',
            'https://files.rewamp.app/overrides/abc/song.mod'),
        isFalse);
  });

  test('url identique ou vide: rien', () {
    expect(RewampDb.sourceUrlIsRelocation(joshw, joshw), isFalse);
    expect(RewampDb.sourceUrlIsRelocation(null, joshw), isFalse);
    expect(RewampDb.sourceUrlIsRelocation(joshw, ''), isFalse);
  });
}
