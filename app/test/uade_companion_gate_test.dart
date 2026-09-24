import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/uade_info.dart';

// Startrekker AM / Audio Sculpture: un `.mod` ordinaire dont les instruments
// de synthèse vivent dans un fichier VOISIN (`m.mod` + `m.mod.as`). Le test de
// NOM répond non — et « mod » n'a rien à faire dans les extensions UADE, on
// volerait tous les modules à libopenmpt. Sans ce portillon, l'écran de détail
// de « m » (Phornee, modland) n'interrogeait pas la songdb: 8 sous-chants
// connus du serveur, aucune durée affichée.
void main() {
  // Amont filtre un sous-chant à longueur MESURÉE nulle, quel que soit son
  // code de statut — pas seulement NOSOUND. « m.mod » a un slot `e` (erreur,
  // 0 ms) en tête: gardé, il n'a pas de durée, ne produit rien, et le lecteur
  // s'y arrête pour toujours (un morceau muet n'a pas de fin à signaler).
  group('slots morts', () {
    UadeInfo info(List<UadeSubsong> subs) =>
        UadeInfo(subsongs: subs, minSubsong: 1, subsongCount: subs.length);

    test('longueur zéro = cassé, quel que soit le code', () {
      expect(const UadeSubsong(idx: 1, songend: 'e', lengthMs: 0).isBroken, isTrue);
      expect(const UadeSubsong(idx: 2, songend: 'n', lengthMs: 0).isBroken, isTrue);
      expect(const UadeSubsong(idx: 3, songend: 'p', lengthMs: 4680).isBroken, isFalse);
    });

    test('durée INCONNUE (null) reste jouable', () {
      expect(const UadeSubsong(idx: 1, songend: 't').isBroken, isFalse);
    });

    test('m.mod: les deux slots de tête tombent, six restent', () {
      final i = info(const [
        UadeSubsong(idx: 1, songend: 'e', lengthMs: 0),
        UadeSubsong(idx: 2, songend: 'n', lengthMs: 0),
        UadeSubsong(idx: 3, songend: 'p', lengthMs: 4680),
        UadeSubsong(idx: 4, songend: 'p', lengthMs: 139760),
        UadeSubsong(idx: 5, songend: 'p', lengthMs: 147460),
        UadeSubsong(idx: 6, songend: 'p', lengthMs: 36740),
        UadeSubsong(idx: 7, songend: 'p', lengthMs: 30840),
        UadeSubsong(idx: 8, songend: 'p', lengthMs: 8280),
      ]);
      expect(i.playableSubsongs.map((s) => s.idx).toList(), [3, 4, 5, 6, 7, 8]);
    });

    test('tout cassé: on garde la première (garde-fou amont)', () {
      final i = info(const [
        UadeSubsong(idx: 1, songend: 'e', lengthMs: 0),
        UadeSubsong(idx: 2, songend: 'n', lengthMs: 0),
      ]);
      expect(i.playableSubsongs.map((s) => s.idx).toList(), [1]);
    });
  });

  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('uadegate'));
  tearDown(() => tmp.delete(recursive: true));

  test('.mod avec compagnon .as: reconnu par le CHEMIN, pas par le nom', () async {
    final mod = File('${tmp.path}/m.mod')..writeAsStringSync('x');
    expect(UadeInfoService.isUadePath(mod.path), isFalse);
    expect(UadeInfoService.isUadeFileAt(mod.path), isFalse);
    File('${tmp.path}/m.mod.as').writeAsStringSync('ST1.2 ModuleINFO');
    expect(UadeInfoService.isUadeFileAt(mod.path), isTrue);
  });

  test('compagnon .nt aussi', () async {
    final mod = File('${tmp.path}/w.mod')..writeAsStringSync('x');
    File('${tmp.path}/w.mod.nt').writeAsStringSync('ST1.3 ModuleINFO');
    expect(UadeInfoService.isUadeFileAt(mod.path), isTrue);
  });

  test('un .mod ordinaire reste à libopenmpt', () async {
    final mod = File('${tmp.path}/plain.mod')..writeAsStringSync('x');
    File('${tmp.path}/plain.mod.txt').writeAsStringSync('note');
    expect(UadeInfoService.isUadeFileAt(mod.path), isFalse);
  });

  test('le SERVICE lui-même passe le portillon (pas seulement l\'appelant)',
      () async {
    // forPath re-testait le nom: la branche UADE était prise, puis le service
    // refusait la requête. Corriger un portillon sans l'autre ne changeait
    // RIEN à l'écran — vérifier CHAQUE chemin, pas le premier trouvé.
    final mod = File('${tmp.path}/z.mod')..writeAsStringSync('x');
    File('${tmp.path}/z.mod.as').writeAsStringSync('ST1.2 ModuleINFO');
    // Sans réseau, forPath rend null; ce qui se teste ici est qu'il aille
    // JUSQU'AU md5 — donc qu'il ne refuse pas sur le nom.
    expect(UadeInfoService.isUadeFileAt(mod.path), isTrue);
  });

  test('un nom UADE reste reconnu sans compagnon', () async {
    final f = File('${tmp.path}/mdat.apidya')..writeAsStringSync('x');
    expect(UadeInfoService.isUadeFileAt(f.path), isTrue);
  });
}
