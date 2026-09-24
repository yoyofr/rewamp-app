// La pochette GÉNÉRIQUE d'un dossier (image livrée dans une archive ou un
// dossier importé) — les règles qui empêchent l'histoire `mdat.jpg` de se
// rejouer: les noms consacrés gagnent, l'unique image du dossier sert de
// pochette commune, DEUX images = ambigu (placeholder), et une image nommée
// d'après un AUTRE morceau du dossier ne fuit jamais sur ses voisins.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/artwork_image.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rewamp_art_test');
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  Future<String> mk(String name) async {
    final f = File(p.join(tmp.path, name));
    await f.writeAsBytes(const [1, 2, 3]);
    return f.path;
  }

  test('un nom consacré (cover.png) sert toutes les pistes du dossier',
      () async {
    final audio = await mk('song.mod');
    final cover = await mk('cover.png');
    await mk('autre.mod');
    expect(await ArtworkCache.instance.findLocalArtwork(audio), cover);
  });

  test("l'unique image du dossier sert de pochette commune", () async {
    final audio = await mk('song.mod');
    final art = await mk('illustration quelconque.jpg');
    expect(await ArtworkCache.instance.findLocalArtwork(audio), art);
  });

  test('deux images = ambigu, on ne devine pas', () async {
    final audio = await mk('song.mod');
    await mk('a.jpg');
    await mk('b.jpg');
    expect(await ArtworkCache.instance.findLocalArtwork(audio), isNull);
  });

  test("l'image d'un AUTRE morceau ne fuit pas sur ses voisins", () async {
    final audio = await mk('song.mod');
    await mk('voisin.mod');
    await mk('voisin.jpg'); // la pochette DU voisin
    expect(await ArtworkCache.instance.findLocalArtwork(audio), isNull);
  });

  test("un .m3u/.txt d'album partageant le radical ne bloque PAS la pochette",
      () async {
    // Le cas réel Battle Garegga: Album.png + Album.m3u + Album.txt — la
    // playlist et les notes de rip ne « possèdent » pas l'image.
    final audio = await mk('01 Raizing Logo.vgz');
    final art = await mk('Battle Garegga.png');
    await mk('Battle Garegga.m3u');
    await mk('Battle Garegga.txt');
    expect(await ArtworkCache.instance.findLocalArtwork(audio), art);
  });

  test("l'image au radical du morceau le sert (Doom2-Stage01.mid + .jpg)",
      () async {
    // Le cas multi-sélection du picker: la pochette est nommée d'après le
    // morceau SANS son extension. Deux images dans le dossier — la forme
    // nommée doit gagner sans tomber dans la règle « unique image ».
    final audio = await mk('Doom2-Stage01.mid');
    final art = await mk('Doom2-Stage01.jpg');
    await mk('Doom2-Stage02.mid');
    await mk('Doom2-Stage02.jpg');
    expect(await ArtworkCache.instance.findLocalArtwork(audio), art);
  });

  test('le nom du morceau lui-même gagne sur tout (règle existante)',
      () async {
    final audio = await mk('song.mod');
    final own = await mk('song.mod.jpg'); // artBasenameFor: nom COMPLET
    await mk('cover.png');
    expect(await ArtworkCache.instance.findLocalArtwork(audio), own);
  });
}
