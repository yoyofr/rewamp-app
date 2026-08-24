// Quand une archive contient PLUSIEURS fichiers jouables du même morceau —
// c'est la règle sur scene.org, pas l'exception: le module d'origine ET son
// rendu — le choix se faisait sur la TAILLE. Or la plus grosse est justement la
// moins intéressante: un mp3 pèse dix fois le `.xm` dont il sort et ne donne ni
// patterns, ni voies, ni sous-chansons.
//
// L'ordre est désormais la RICHESSE du format:
//   0 · patterns natifs (openmpt, furnace, sunvox, tiatracker)
//   1 · puce multi-voies (vgm, nsf, sid, psf, uade…)
//   2 · flux (mp3, ogg, vgmstream, ape…)
// le nom de l'archive gardant la priorité, et la taille ne servant plus qu'à
// départager deux fichiers de même palier.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/rewamp_db.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rewamp_tier');
  });
  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  // Contenu BINAIRE: un fichier fait de texte est écarté comme stub (readme).
  Future<void> put(String name, {int size = 4096}) async {
    final f = File(p.join(dir.path, name));
    await f.parent.create(recursive: true);
    await f.writeAsBytes(List<int>.filled(size, 0));
  }

  Future<String?> pick() async =>
      (await RewampDb.debugFindExtractedAudio(dir.path))
          ?.split(Platform.pathSeparator)
          .last;

  test('le module gagne contre son rendu mp3, dix fois plus gros', () async {
    await put('song.xm', size: 60 * 1024);
    await put('song.mp3', size: 6 * 1024 * 1024);
    expect(await pick(), 'song.xm');
  });

  test('une puce passe devant un flux, quelle que soit la taille', () async {
    await put('theme.vgz', size: 30 * 1024);
    await put('theme.ogg', size: 4 * 1024 * 1024);
    expect(await pick(), 'theme.vgz');
  });

  test('un format que vgmstream réclame AUSSI reste une puce', () async {
    // `vgm` et `spc` sont dans les 705 extensions de vgmstream ET joués par
    // libvgm / libgme. Les classer sur la seule appartenance à vgmstream en
    // ferait des flux, et ils perdraient contre le `.ogg` d'à côté.
    await put('battle.vgm', size: 20 * 1024);
    await put('battle.ogg', size: 3 * 1024 * 1024);
    expect(await pick(), 'battle.vgm');
  });

  test('spc aussi, alors qu\'il est dans la liste vgmstream', () async {
    await put('boss.spc', size: 64 * 1024);
    await put('boss.ogg', size: 3 * 1024 * 1024);
    expect(await pick(), 'boss.spc');
  });

  test('l\'extension fait autorité, le préfixe n\'est qu\'un repli', () async {
    // `bgm` est un vrai token (libkss, vgmstream): consulter le préfixe d'un
    // fichier qui a déjà une extension connue le classait sur `bgm` au lieu de
    // `vgz`, et le module perdait contre le rendu.
    await put('bgm.vgz', size: 30 * 1024);
    await put('bgm.ogg', size: 4 * 1024 * 1024);
    expect(await pick(), 'bgm.vgz');
  });

  test('les patterns passent devant la puce', () async {
    await put('tune.nsf', size: 512 * 1024);
    await put('tune.it', size: 20 * 1024);
    expect(await pick(), 'tune.it');
  });

  test('à palier égal, la taille départage comme avant', () async {
    await put('a.mod', size: 10 * 1024);
    await put('b.mod', size: 90 * 1024);
    expect(await pick(), 'b.mod');
  });

  test('entre flux, la taille départage encore', () async {
    await put('a.ogg', size: 10 * 1024);
    await put('b.mp3', size: 90 * 1024);
    expect(await pick(), 'b.mp3');
  });

  test('la convention Amiga du PRÉFIXE est reconnue comme une puce', () async {
    // « mdat.NOM » porte son format AVANT le point: sans le test de préfixe il
    // passerait pour un fichier sans extension connue, donc en flux.
    await put('mdat.monkey island', size: 40 * 1024);
    await put('preview.mp3', size: 3 * 1024 * 1024);
    expect(await pick(), 'mdat.monkey island');
  });

  test('rien de jouable → null, l\'appelant garde son chemin d\'erreur',
      () async {
    await put('readme.txt');
    expect(await pick(), isNull);
  });
}
