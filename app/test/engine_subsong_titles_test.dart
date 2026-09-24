import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_db.dart' show TrackRecord;
import 'package:rewamp/local_open.dart';
import 'package:rewamp_audio/rewamp_audio.dart' show SubsongInfo;

/// Un `.nsfe` porte ses noms de piste (chunk `tlbl`) et ses durées (`time`).
/// Le probe natif les remontait déjà; l'ouverture locale ne prenait que le
/// COMPTE et fabriquait « NOM (1) », « NOM (2) »… — les vrais titres étaient à
/// un appel de distance. Vérifié sur le binaire livré: « Castlevania 3.nsfe »
/// rend 28 sous-chansons, « Prelude (Intro) » 102 136 ms en tête.
SubsongInfo _s(int i, {String? title, int? ms}) => SubsongInfo(
      index: i,
      filePath: '/x/Castlevania 3.nsfe',
      subsongIdx: i,
      title: title,
      durationMs: ms,
    );

const _path = '/x/Castlevania 3.nsfe';

void main() {
  test('les titres du FICHIER deviennent ceux de la file', () {
    final out = subsongRecordsFrom([
      _s(0, title: 'Prelude (Intro)', ms: 102136),
      _s(1, title: 'Prayer (Opening)', ms: 11197),
      _s(2, title: 'Beginning (Block-1)', ms: 100437),
    ], _path);

    expect(out, isNotNull);
    expect([for (final t in out!) t.title],
        ['Prelude (Intro)', 'Prayer (Opening)', 'Beginning (Block-1)']);
    // Les durées aussi: elles s'affichent dans la file.
    expect(out.first.durationS, closeTo(102.136, 0.001));
    expect(out.every((t) => t.filePath == _path), isTrue);
    expect(out.every((t) => t.formatExt == 'nsfe'), isTrue);
  });

  test('sans aucun titre, on rend null et l\'appelant garde ses numéros', () {
    // Un .nsf ordinaire n'a pas de `tlbl`: mieux vaut « NOM (1) » qu'une
    // liste de lignes sans nom.
    expect(subsongRecordsFrom([_s(0), _s(1), _s(2)], _path), isNull);
    expect(subsongRecordsFrom([_s(0, title: '  '), _s(1)], _path), isNull);
  });

  test('une seule sous-chanson n\'est pas un conteneur', () {
    expect(subsongRecordsFrom([_s(0, title: 'Seul')], _path), isNull);
  });

  test('un titre vide au milieu est numéroté, les autres gardent le leur', () {
    final out = subsongRecordsFrom(
        [_s(0, title: 'Prelude'), _s(1), _s(2, title: 'Boss Fight')], _path)!;
    expect([for (final t in out) t.title],
        ['Prelude', 'Castlevania 3 (2)', 'Boss Fight']);
  });

  test('l\'index de sous-chanson vient du probe, jamais de la position', () {
    // Les formats à base non nulle (KSS: trk_min) renvoient un index ABSOLU:
    // le recalculer depuis la position jouerait une autre piste.
    final out = subsongRecordsFrom([
      const SubsongInfo(index: 0, filePath: _path, subsongIdx: 128, title: 'A'),
      const SubsongInfo(index: 1, filePath: _path, subsongIdx: 129, title: 'B'),
    ], _path)!;
    expect([for (final t in out) t.subsongIdx], [128, 129]);
  });

  test('une ligne DÉJÀ connue garde son ♥ et ses écoutes', () {
    // Le fichier n'énonce que le titre et la durée; tout le reste appartient à
    // la ligne en base et se perdrait à la recopier champ par champ.
    const known = TrackRecord(
      id: 'row-1',
      filePath: _path,
      entryPath: '',
      subsongIdx: 1,
      title: 'Castlevania 3 (2)',
      artworkUrl: 'file:///art.png',
      source: 'local',
      isFavorite: true,
      inLibrary: true,
      playCount: 7,
    );
    final out = subsongRecordsFrom(
      [_s(0, title: 'Prelude'), _s(1, title: 'Prayer (Opening)', ms: 11197)],
      _path,
      known: {1: known},
    )!;
    final row = out[1];
    expect(row.title, 'Prayer (Opening)');   // le fichier dit mieux
    expect(row.durationS, closeTo(11.197, 0.001));
    expect(row.isFavorite, isTrue);          // …et n'efface rien d'autre
    expect(row.inLibrary, isTrue);
    expect(row.playCount, 7);
    expect(row.artworkUrl, 'file:///art.png');
    expect(row.id, 'row-1');
  });
}
