import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_open.dart' show kMultiTrackExts;

/// `kMultiTrackExts` est la porte par où l'ouverture locale décide de DÉPLIER
/// un fichier en sous-chansons. Une extension qui manque à cette liste ne
/// produit aucune erreur: le fichier joue sa sous-chanson 0 et l'utilisateur
/// voit « ça ne joue que la première piste ».
///
/// Le cas payé: un `.rsn` importé localement. C'est un RAR SOLIDE de `.spc`
/// joué EN PLACE — jamais dépaqueté, les chemins `.spc` par piste n'existent
/// pas — donc ses pistes SONT des sous-chansons. Le probe natif savait déjà
/// les compter (`gme_open_file` ouvre le conteneur via Rsn_Emu, et le probe
/// n'est filtré par AUCUNE extension): il manquait uniquement de le lui
/// demander.
void main() {
  test('un conteneur RAR de SPC (.rsn) est un multi-pistes', () {
    expect(kMultiTrackExts, contains('rsn'));
  });

  test('un module Furnace/FamiTracker est un multi-pistes', () {
    // Furnace importe les morceaux d'un `.ftm` en SOUS-CHANSONS. Le décodeur
    // savait déjà en jouer une (`?subsong=N` → `selectSong`) et le panneau ⓘ
    // annonçait leur nombre, mais rien ne les COMPTAIT: `probe_subsong_count`
    // n'avait aucune branche Furnace. Vu de l'utilisateur, « Shovel Knight »
    // ne proposait aucune sous-chanson et s'entendait comme une piste unique
    // qui les enchaîne.
    for (final ext in ['ftm', 'fur', '0cc', 'dnm', 'eft']) {
      expect(kMultiTrackExts, contains(ext), reason: '$ext manque');
    }
  });

  test('les conteneurs à sous-chansons connus y sont tous', () {
    // Témoins d'origines différentes, pour qu'une refonte de la liste ne
    // puisse pas en perdre une famille entière en silence.
    for (final ext in ['nsf', 'gbs', 'sid', 'sap', 'kss', 'hes', 'vgm',
                       'wsr', 'sndh', 'rsn', 'ftm']) {
      expect(kMultiTrackExts, contains(ext), reason: '$ext manque');
    }
  });

  test("une archive à EXTRAIRE n'est pas un conteneur à sous-chansons", () {
    // `.rsn` est la seule archive de la liste, et c'est justifié: elle n'est
    // jamais extraite. Un `.zip` ou un `.7z`, eux, deviennent des dossiers de
    // fichiers — les déplier en sous-chansons donnerait des pistes fantômes.
    for (final ext in ['zip', '7z', 'rar', 'lha', 'tar', 'gz']) {
      expect(kMultiTrackExts, isNot(contains(ext)), reason: '$ext ne doit pas y être');
    }
  });
}
