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

/// Boucle infinie: le total AFFICHÉ doit suivre, sinon l'UI clampe la position
/// dessus et le compteur gèle à « nominal / nominal » alors que ça joue encore.
void _infiniteTotalTests() {
  test('1re passe: le total ne bouge pas (pas de saut au démarrage)', () {
    expect(infiniteDisplayTotal(0, 150), 150);
    expect(infiniteDisplayTotal(30, 150), 150);
    expect(infiniteDisplayTotal(150, 150), 150);
  });

  test('passes suivantes: le total monte d\'une passe entière', () {
    expect(infiniteDisplayTotal(151, 150), 300);
    expect(infiniteDisplayTotal(300, 150), 300);
    expect(infiniteDisplayTotal(301, 150), 450);
  });

  test('le total reste STRICTEMENT au-dessus de la position', () {
    // La propriété qui compte: c'est elle que le clamp de l'UI exige.
    for (var t = 0.0; t < 900; t += 7.3) {
      final total = infiniteDisplayTotal(t, 150)!;
      expect(total >= t, isTrue, reason: 'écoulé $t > total $total');
    }
  });

  test('durée nominale inconnue: null, on garde ce qu\'on avait', () {
    for (final n in [null, 0.0, -1.0]) {
      expect(infiniteDisplayTotal(999, n), isNull, reason: 'nominal = $n');
    }
  });
}
