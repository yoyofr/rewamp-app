// L'identité SERVEUR d'un morceau: uuid ET sous-chanson.
//
// `catalogueSongId` coupe le `#N` d'un `<uuid>#<i>` parce que la colonne
// serveur est un `uuid` — mais ce `#N` EST la sous-chanson. Le jeter sans le
// reporter faisait retomber toutes les pistes d'un album conteneur sur la même
// ligne de compte (uuid, 0): un ♥ posé sur la 30e piste écrivait sur la ligne
// de la 1re, et la synchro suivante ramenait l'état de celle-ci — le ♥
// s'éteignait tout seul quelques secondes plus tard.
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

void main() {
  const uuid = 'd8b57277-16fd-5415-91a6-64c70d5253ae';

  test('un uuid nu passe tel quel', () {
    expect(catalogueSongRef(uuid), (uuid, 0));
    expect(catalogueSongRef(uuid, subsongIdx: 4), (uuid, 4));
  });

  test('le #N d\'un conteneur DEVIENT la sous-chanson', () {
    expect(catalogueSongRef('$uuid#29'), (uuid, 29));
    // Et il gagne sur le `?subsong=` de la clé locale, qui ne vaut que pour le
    // fichier de la piste (lequel n'a qu'une sous-chanson).
    expect(catalogueSongRef('$uuid#29?subsong=0'), (uuid, 29));
  });

  test('la clé subsong-scopée d\'un fichier multi-pistes est respectée', () {
    expect(catalogueSongRef('$uuid?subsong=7', subsongIdx: 7), (uuid, 7));
  });

  test('un chemin local n\'a pas d\'identité catalogue', () {
    final (id, _) = catalogueSongRef('/Users/x/y.mod?subsong=2', subsongIdx: 2);
    expect(id, isNull);
  });
}
