import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/player_controller.dart';

/// Le bouton repeat du transport et le réglage « boucle forcée » se fondent en
/// UN mode, celui que voient les moteurs. Ce qui compte ici n'est pas la table
/// mais les deux invariants qu'elle protège:
///
///  - repeat-morceau DOIT valoir 'infinite', jamais un rechargement du fichier:
///    un format à point de boucle repartirait de l'intro à chaque passe.
///  - repeat-file DOIT valoir 'off', sinon la piste ne finit jamais et la file
///    n'avance pas — le bouton ne ferait plus rien.
void main() {
  test('repeat-morceau EST une boucle infinie, quel que soit le réglage', () {
    for (final setting in ['off', 'on', 'infinite']) {
      expect(effectiveForceLoopModeFor(2, setting), 'infinite',
          reason: 'réglage « $setting » : repeat-morceau doit primer');
    }
  });

  test('repeat-file coupe la boucle forcée — la piste doit FINIR', () {
    for (final setting in ['off', 'on', 'infinite']) {
      expect(effectiveForceLoopModeFor(1, setting), 'off',
          reason: 'réglage « $setting » : la file ne pourrait plus avancer');
    }
  });

  test('repeat éteint laisse le réglage global intact', () {
    expect(effectiveForceLoopModeFor(0, 'off'), 'off');
    expect(effectiveForceLoopModeFor(0, 'on'), 'on');
    expect(effectiveForceLoopModeFor(0, 'infinite'), 'infinite');
  });

  _loopCutTests();
  _infiniteTotalTests();
}

/// Couper repeat PENDANT la lecture: la décision se prend sur la durée
/// NOMINALE (une passe, sans boucle), pas sur une frontière de passe devinée.
void _loopCutTests() {
  test('avant la fin nominale: on joue jusqu\'à la fin NATURELLE, pas de coupure',
      () {
    // Couper à 0:30 un morceau de 2:30 parce qu'on éteint repeat serait un
    // saut de piste déguisé — c'est le cas que cette règle protège.
    expect(
      loopCutActionFor(
          elapsedSeconds: 30,
          nominalSeconds: 150,
          fadeoutEnabled: true,
          fadeoutSeconds: 5),
      LoopCutAction.playToNominalEnd,
      reason: 'le fondu ne doit PAS primer tant qu\'on est dans la 1re passe',
    );
  });

  test('passe supplémentaire: on termine, en fondu si demandé', () {
    expect(
      loopCutActionFor(
          elapsedSeconds: 440,
          nominalSeconds: 150,
          fadeoutEnabled: true,
          fadeoutSeconds: 5),
      LoopCutAction.fadeOut,
    );
    expect(
      loopCutActionFor(
          elapsedSeconds: 440,
          nominalSeconds: 150,
          fadeoutEnabled: false,
          fadeoutSeconds: 5),
      LoopCutAction.stopNow,
    );
    // Fondu « activé » mais de durée nulle = pas de fondu.
    expect(
      loopCutActionFor(
          elapsedSeconds: 440,
          nominalSeconds: 150,
          fadeoutEnabled: true,
          fadeoutSeconds: 0),
      LoopCutAction.stopNow,
    );
  });

  test('pile à la durée nominale = passe terminée, on ne relance pas', () {
    expect(
      loopCutActionFor(
          elapsedSeconds: 150,
          nominalSeconds: 150,
          fadeoutEnabled: false,
          fadeoutSeconds: 0),
      LoopCutAction.stopNow,
    );
  });

  test('durée nominale inconnue: on ne devine pas', () {
    for (final n in [null, 0.0, -1.0]) {
      expect(
        loopCutActionFor(
            elapsedSeconds: 999,
            nominalSeconds: n,
            fadeoutEnabled: true,
            fadeoutSeconds: 5),
        LoopCutAction.none,
        reason: 'nominal = $n',
      );
    }
  });
}

/// Boucle infinie: la règle graduée ne couvre qu'UNE passe et la position y est
/// PLAFONNÉE. C'est ce qui rend le seek exact (toute cible reste dans le
/// domaine du décodeur) sans prétendre savoir où un point de boucle inconnu
/// fait repartir la musique.
void _infiniteTotalTests() {
  test('1re passe: la position est le temps écoulé (pas de saut)', () {
    expect(infiniteDisplayPosition(0, 150), 0);
    expect(infiniteDisplayPosition(30, 150), 30);
    expect(infiniteDisplayPosition(149.5, 150), 149.5);
  });

  test('passes suivantes: la barre SATURE au lieu de reboucler', () {
    // Reboucler à zéro prétendrait savoir où la musique repart — faux dès
    // qu'il y a un point de boucle, et on ne le connaît pas.
    expect(infiniteDisplayPosition(150, 150), 150);
    expect(infiniteDisplayPosition(151, 150), 150);
    expect(infiniteDisplayPosition(4321, 150), 150);
  });

  test('la position reste TOUJOURS dans [0, nominal]', () {
    // La propriété qui compte: elle garantit qu'un seek vise un point que le
    // décodeur sait atteindre, quel que soit son point de boucle.
    for (var t = 0.0; t < 900; t += 7.3) {
      final pos = infiniteDisplayPosition(t, 150);
      expect(pos >= 0 && pos <= 150, isTrue, reason: 'écoulé $t -> $pos');
    }
  });

  test('la position ne RECULE jamais', () {
    var prev = 0.0;
    for (var t = 0.0; t < 900; t += 3.1) {
      final pos = infiniteDisplayPosition(t, 150);
      expect(pos >= prev, isTrue, reason: 'écoulé $t: $pos < $prev');
      prev = pos;
    }
  });

  test('durée nominale inconnue: on rend le temps écoulé tel quel', () {
    for (final n in [null, 0.0, -1.0]) {
      expect(infiniteDisplayPosition(999, n), 999, reason: 'nominal = $n');
    }
  });
}
