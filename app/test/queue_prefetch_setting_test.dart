import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/user_settings.dart';

/// Pré-télécharger toute la file, ou seulement le morceau suivant.
///
/// ⚠️ Dans les DEUX modes un seul téléchargement court à la fois — c'est la
/// charge qu'on borne, pas le nombre de morceaux. La différence est le
/// CHAÎNAGE: « tout » repart sur le manquant suivant dès qu'un fichier a
/// atterri, « suivant » attend le prochain changement de piste.
void main() {
  test('le défaut est TOUT télécharger', () {
    // Avec « suivant seulement », une file de vingt morceaux n'en pré-chargeait
    // qu'un: le vingtième se téléchargeait à son tour, au moment précis où il
    // fallait l'entendre.
    expect(UserSettings.kEnginePrefKeys.containsKey('queuePrefetchAll'), isTrue,
        reason: 'sans cette entrée, le bouton de remise à zéro ne se dessine '
            'même pas — et l\'oubli est SILENCIEUX');
  });

  test('le réglage appartient à la section Lecture', () {
    // Sans ça, la remise à zéro de la SECTION saute le réglage.
    final key = UserSettings.kEnginePrefKeys['queuePrefetchAll'];
    expect(key, isNotNull);
    expect(UserSettings.kSectionKeys['playback'], contains(key));
  });
}
