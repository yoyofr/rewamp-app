import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_db.dart';

/// Un album téléchargé est rangé sous l'UUID que le serveur lui donne — le seul
/// rangement qui ne se dédouble pas quand l'artiste varie d'un flux à l'autre
/// (voir RewampDb._dirSegments). Juste sur le disque, illisible à l'écran: la
/// traduction se fait à l'AFFICHAGE, et seulement là.
void main() {
  const names = {
    '2f3c9d54-0000-4000-8000-000000000001': 'Chrono Trigger',
    '2f3c9d54-0000-4000-8000-000000000002': 'Final Fantasy VI',
  };

  test('un segment uuid connu devient le nom de l’album', () {
    expect(
      readableRelPath(
          'jw_spc/2f3c9d54-0000-4000-8000-000000000001/101 Chrono.spc', names),
      'jw_spc/Chrono Trigger/101 Chrono.spc',
    );
  });

  test('un uuid INCONNU reste tel quel — on ne devine pas', () {
    const rel = 'jw_spc/ffffffff-0000-4000-8000-00000000ffff/a.spc';
    expect(readableRelPath(rel, names), rel);
  });

  test('sans table de noms, le chemin ne bouge pas', () {
    const rel = 'modland/Turrican/mdat.turrican';
    expect(readableRelPath(rel, const {}), rel);
  });

  test('plusieurs segments traduits dans le même chemin', () {
    expect(
      readableRelPath(
          '2f3c9d54-0000-4000-8000-000000000002/'
          '2f3c9d54-0000-4000-8000-000000000001/x.spc',
          names),
      'Final Fantasy VI/Chrono Trigger/x.spc',
    );
  });

  // Windows: `p.relative` y rend des `\`, et un chemin non découpé aurait
  // laissé l'uuid entier visible.
  test('le séparateur Windows est reconnu', () {
    expect(
      readableRelPath(
          r'jw_spc\2f3c9d54-0000-4000-8000-000000000001\a.spc', names),
      'jw_spc/Chrono Trigger/a.spc',
    );
  });

  test('un chemin vide reste vide', () {
    expect(readableRelPath('', names), '');
  });
}
