// Boucle infinie NATIVE d'un morceau sans point de boucle (vio2sf: la fin est
// levée, l'émulation joue du silence après la dernière note): relance passé la
// durée nominale, jamais avant, jamais sans durée connue.
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/player_controller.dart';

void main() {
  test('silence passé la durée nominale: relance', () {
    expect(
        nativeInfiniteShouldRestart(
            silentSeconds: 2.5, decoderPositionSeconds: 19, nominalSeconds: 17),
        isTrue);
  });

  test('blanc au milieu du morceau: pas de relance', () {
    expect(
        nativeInfiniteShouldRestart(
            silentSeconds: 5, decoderPositionSeconds: 8, nominalSeconds: 17),
        isFalse);
  });

  test('silence trop court: on attend', () {
    expect(
        nativeInfiniteShouldRestart(
            silentSeconds: 1.5, decoderPositionSeconds: 30, nominalSeconds: 17),
        isFalse);
  });

  test('durée inconnue: jamais (un moteur qui reboucle seul peut se taire)', () {
    expect(
        nativeInfiniteShouldRestart(
            silentSeconds: 10, decoderPositionSeconds: 300, nominalSeconds: null),
        isFalse);
  });
}
