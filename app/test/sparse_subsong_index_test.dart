import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_open.dart';
import 'package:rewamp_audio/rewamp_audio.dart' show SubsongInfo;

/// Un `.adl` Westwood est une TABLE de morceaux, et AdPlug n'en compte que la
/// LONGUEUR (`numsubsongs` = index de la dernière entrée valide + 1, TROUS
/// COMPRIS). Mesuré sur le disque: DUNE19.ADL annonce 74 pistes pour 43 qui
/// jouent une note, LOREINTR.ADL 55 pour 28. La sonde native écarte les autres
/// — entrées sentinelles ET routines de CONTRÔLE du pilote (arrêt, fondu, qui
/// portent un vrai programme mais ne jouent rien).
///
/// La liste qui en sort est donc CREUSE: la 6e piste jouable de DUNE19 porte
/// l'index 10. Deux règles en découlent, et c'est ce que ce fichier épingle.
const _path = '/x/DUNE19.ADL';

SubsongInfo _s(int position, int subsong, {String? title}) => SubsongInfo(
      index: position,
      filePath: _path,
      subsongIdx: subsong,
      title: title,
      durationMs: null,
    );

// Les six premières entrées vivantes de DUNE19.ADL, mesurées.
final _dune19 = [
  _s(0, 2), _s(1, 3), _s(2, 4), _s(3, 20), _s(4, 22), _s(5, 23),
];

void main() {
  test('une liste CREUSE est adoptée même SANS titres', () {
    // Règle 1. Sans titres, la sonde n'apporte rien que le COMPTE ne dise déjà
    // — c'est pourquoi `subsongRecordsFrom` renonce. Mais quand la liste est
    // creuse, l'index réel est une information que l'appelant ne peut PAS
    // reconstruire depuis le compte: renoncer ici met en file des slots muets.
    final out = subsongRecordsFrom(_dune19, _path);
    expect(out, isNotNull, reason: 'une liste creuse sans titres doit être gardée');
    expect([for (final t in out!) t.subsongIdx], [2, 3, 4, 20, 22, 23]);
  });

  test('le NUMÉRO affiché reste la POSITION, pas l\'index', () {
    // Règle du dépôt: « NOM (n) », n = position dans la liste JOUABLE. Afficher
    // l'index ferait commencer DUNE19 à « (3) » et sauter à « (21) ».
    final out = subsongRecordsFrom(_dune19, _path)!;
    expect([for (final t in out) t.title],
        ['DUNE19 (1)', 'DUNE19 (2)', 'DUNE19 (3)',
         'DUNE19 (4)', 'DUNE19 (5)', 'DUNE19 (6)']);
  });

  test('une liste DENSE sans titres renonce toujours', () {
    // La règle d'avant, intacte: pour tout le reste, un compte nu ne vaut pas
    // mieux que ce que l'appelant sait déjà faire.
    expect(subsongRecordsFrom([_s(0, 0), _s(1, 1), _s(2, 2)], _path), isNull);
  });

  test('un `.adl` est un conteneur à sous-chansons', () {
    // Sans cette porte, un `.adl` ouvert localement jouait sa sous-chanson 0
    // — qui est presque toujours la routine d'ARRÊT du pilote Westwood, donc
    // rien du tout.
    expect(kMultiTrackExts, contains('adl'));
  });
}
