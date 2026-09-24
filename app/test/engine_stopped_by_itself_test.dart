import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/player_controller.dart';

/// « Le moteur s'est-il arrêté tout seul ? » gouverne DEUX gestes destructeurs:
/// avancer la file (fin de piste) et relancer le morceau depuis zéro (boucle
/// forcée). Une reprise EN VOL présente exactement la même signature — drapeau
/// d'UI à vrai, moteur pas encore démarré — parce que la session audio de la
/// plateforme se réactive derrière une porte asynchrone. Un tick tombant là
/// faisait partir « suivant » ou « précédent » sur un appui lecture/pause.
void main() {
  test('moteur arrêté alors qu\'on se croit en lecture = fin de piste', () {
    expect(
      engineStoppedByItself(
          enginePlaying: false, uiPlaying: true, engineStartPending: false),
      isTrue,
    );
  });

  test('une REPRISE EN VOL n\'est pas une fin de piste', () {
    // Le cas du bug: l'appui a posé isPlaying, `audio.play()` attend la porte.
    expect(
      engineStoppedByItself(
          enginePlaying: false, uiPlaying: true, engineStartPending: true),
      isFalse,
    );
  });

  test('une pause n\'est pas une fin de piste', () {
    // pause() pose isPlaying=false AVANT d'arrêter le moteur: l'invariant sur
    // lequel toute la détection repose.
    expect(
      engineStoppedByItself(
          enginePlaying: false, uiPlaying: false, engineStartPending: false),
      isFalse,
    );
  });

  test('lecture normale: rien ne se termine', () {
    expect(
      engineStoppedByItself(
          enginePlaying: true, uiPlaying: true, engineStartPending: false),
      isFalse,
    );
  });

  test('le moteur qui a DÉMARRÉ referme la fenêtre, même drapeau posé', () {
    expect(
      engineStoppedByItself(
          enginePlaying: true, uiPlaying: true, engineStartPending: true),
      isFalse,
    );
  });
}
