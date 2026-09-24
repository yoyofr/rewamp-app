// Renommer une entrée de file se fait par FICHIER et SOUS-CHANSON, jamais par
// position.
//
// Vécu: lancer un morceau depuis le rail « Vos tendances » donne une file de
// morceaux SANS RAPPORT. STIL nomme la sous-chanson 0 de « One Man and his
// Droid » « Space Game », et l'ancienne signature (indexée par position)
// renommait l'entrée 0 de la file — « panic », un .s3m de Purple Motion.
//
// Et la reconstruction perdait huit champs sur dix: pochette, sous-titre,
// album et surtout `id`, dont le panneau se sert comme clé de widget.
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/player_controller.dart';

QueueEntry _e(String title, {String? file, int? sub, Object? id}) => QueueEntry(
      id: id,
      title: title,
      artist: 'A',
      artworkUrl: 'http://art/$title.png',
      subtitle: 'contexte',
      localFilePath: file,
      subsongIdx: sub,
    );

void main() {
  test('une entrée d\'un AUTRE fichier n\'est jamais renommée', () {
    final q = [
      _e('panic', file: '/x/panic.s3m', sub: 0, id: 1),
      _e('One_Man (2)', file: '/x/omahd.sid', sub: 1, id: 2),
    ];
    final renamed = applyQueueTitles(q, '/x/omahd.sid', {0: 'Space Game'});
    expect(renamed[0].title, 'panic', reason: 'autre fichier');
    expect(renamed[1].title, 'One_Man (2)', reason: 'autre sous-chanson');
  });

  test('la bonne sous-chanson du bon fichier est renommée', () {
    final q = [
      _e('panic', file: '/x/panic.s3m', sub: 0, id: 1),
      _e('One_Man (1)', file: '/x/omahd.sid', sub: 0, id: 2),
    ];
    final renamed = applyQueueTitles(q, '/x/omahd.sid', {0: 'Space Game'});
    expect(renamed[0].title, 'panic');
    expect(renamed[1].title, 'Space Game');
  });

  test('renommer ne perd RIEN d\'autre', () {
    final q = [_e('One_Man (1)', file: '/x/omahd.sid', sub: 0, id: 42)];
    final r = applyQueueTitles(q, '/x/omahd.sid', {0: 'Space Game'}).single;
    expect(r.title, 'Space Game');
    expect(r.id, 42);                        // clé de widget du panneau
    expect(r.artworkUrl, isNotNull);
    expect(r.subtitle, 'contexte');
    expect(r.localFilePath, '/x/omahd.sid');
    expect(r.subsongIdx, 0);
    expect(r.artist, 'A');
  });
}
