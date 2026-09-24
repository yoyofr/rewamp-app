// Un format dont SEUL le décodeur sait compter les sous-chansons.
//
// `isContainerRow` encode la règle du sidecar serveur: `subsong_count == 1`
// veut dire « mono, AFFIRMÉ », donc on joue le fichier direct. Vrai partout —
// sauf là où le serveur n'a pas de tracklist du tout et où ce 1 est un DÉFAUT,
// pas un constat.
//
// Le cas payé: `modland/Ad Lib/ADL/Paul Mudra/eob2 - catacomb.adl`. Le serveur
// répond `track_count: 1` (vérifié sur search_music); le fichier tient 111
// morceaux jouables. Et la sous-chanson 0 d'un `.adl` Westwood est presque
// toujours la routine d'ARRÊT du pilote: joué tel quel, il ne produit RIEN.
// Le même fichier IMPORTÉ localement marchait — la porte locale
// (`kMultiTrackExts`) ne regarde que l'extension —, d'où « ça ne marche que
// pour les fichiers ouverts en local ».

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

SearchResult row(String ext, {int? count, bool resolved = false}) =>
    SearchResult(
      songId: 'bcb8c353-590d-50b7-82ee-7bc72c3f0bb9',
      collection: 'modland',
      title: 'eob2 - catacomb',
      filename: 'eob2 - catacomb.$ext',
      formatExt: ext,
      downloadUrl: null,
      fileSize: 8358,
      year: null,
      artistNames: const [],
      totalCount: 1,
      album: null,
      subsongCount: count,
      resolvedSubsong: resolved,
    );

void main() {
  test('un `.adl` reste un conteneur malgré un compte serveur de 1', () {
    expect(RewampDb.isContainerRow(row('adl', count: 1)), isTrue);
    expect(RewampDb.isContainerRow(row('adl')), isTrue);
  });

  test('la règle du sidecar tient pour tout le reste', () {
    // Un `.sid` dont le serveur AFFIRME une seule sous-chanson se joue direct:
    // c'est un constat (hvsc a de vraies tracklists), pas un défaut.
    expect(RewampDb.isContainerRow(row('sid', count: 1)), isFalse);
    // Compte inconnu + format à conteneurs: on sonde à l'ouverture.
    expect(RewampDb.isContainerRow(row('sid')), isTrue);
    // Un format ordinaire ne devient jamais un conteneur.
    expect(RewampDb.isContainerRow(row('mod')), isFalse);
    expect(RewampDb.isContainerRow(row('mod', count: 1)), isFalse);
  });

  test('une ligne DÉJÀ résolue n\'est pas le conteneur', () {
    // Sinon chaque sous-chanson épinglée (entrée de playlist, palmarès) se
    // redéplierait en toutes les autres.
    expect(RewampDb.isContainerRow(row('adl', count: 1, resolved: true)),
        isFalse);
  });

  test('un rang de tracklist n\'est jamais le conteneur', () {
    final r = row('adl', count: 1).copyWith(trackPosition: 3);
    expect(RewampDb.isContainerRow(r), isFalse);
  });
}
