import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/player_controller.dart';

/// Sous boucle infinie, un silence relançait le morceau depuis zéro. Deux
/// fichiers l'ont montré le 2026-08-29:
///  - « Run » (sceneorg): des passages silencieux au MILIEU, la lecture
///    rebouclait sur ses premières secondes.
///  - « Inside The BORG Cube »: 1,54 s de silence NUMÉRIQUE en tête (mesuré
///    sous `REWAMP_SILENCE_EPS`), soit plus que le seuil de 1,2 s — la piste
///    se relançait avant d'avoir joué une note. Aucun son du tout.
void main() {
  test('un blanc au DÉBUT d\'un flux connu n\'est pas une fin', () {
    // BORG: 1,54 s de silence au début d'un mp3 de 2:25.
    expect(
        silenceCanMeanEnd(
            decoderPositionSeconds: 1.6, nominalSeconds: 145.5),
        isFalse);
  });

  test('un blanc au MILIEU n\'est pas une fin', () {
    expect(
        silenceCanMeanEnd(decoderPositionSeconds: 70, nominalSeconds: 145.5),
        isFalse);
  });

  test('un silence AU BOUT en est une', () {
    expect(
        silenceCanMeanEnd(decoderPositionSeconds: 145.0, nominalSeconds: 145.5),
        isTrue);
    // La marge couvre un décodeur qui s'arrête un peu avant le total annoncé
    // (fondu, padding de fin) et un curseur échantillonné au tick de 250 ms.
    expect(
        silenceCanMeanEnd(decoderPositionSeconds: 143.6, nominalSeconds: 145.5),
        isTrue);
  });

  test('durée inconnue: le silence reste la seule fin observable', () {
    // C'est la population pour laquelle le détecteur a été écrit — SID, NSF,
    // PSF sans tag: le décodeur ne s'arrête jamais.
    expect(
        silenceCanMeanEnd(decoderPositionSeconds: 3, nominalSeconds: null),
        isTrue);
    expect(silenceCanMeanEnd(decoderPositionSeconds: 3, nominalSeconds: 0),
        isTrue);
  });
}
