import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_db.dart';

TrackRecord _t(String path, {String? title, int? count}) => TrackRecord(
      id: '1', filePath: path, entryPath: '', subsongIdx: 0,
      title: title, subsongCount: count, source: 'download',
      isFavorite: false, inLibrary: false, playCount: 0);

void main() {
  test('un conteneur se nomme par son FICHIER, pas par sa sous-chanson 0', () {
    // La numérotation « NOM (n) » est dérivée à la lecture et finit stockée.
    expect(_t('/a/Commando.sid', title: 'Commando (1)', count: 7).containerName,
        'Commando');
    expect(
        _t('/a/Monty_on_the_Run.sid', title: 'Monty_on_the_Run.sid', count: 4)
            .containerName,
        'Monty_on_the_Run');
  });

  test('la convention Amiga met le format AVANT le point', () {
    expect(_t('/a/mdat.monkey island', count: 22).containerName,
        'monkey island');
  });

  test('un fichier simple garde son titre', () {
    expect(_t('/a/x.sid', title: 'Space Game', count: 1).displayTitle,
        'Space Game');
  });
}
