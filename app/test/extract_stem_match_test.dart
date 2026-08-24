// Le catalogue et l'archive ne s'accordent pas toujours sur l'EXTENSION d'une
// même piste: jw_psf « Hexen — Beyond Heretic » annonce « Audio Track 01.wav »
// là où le 7z contient « Audio Track 01.ogg ». C'est le NOM qui identifie la
// piste, pas son suffixe.
//
// Sans la correspondance par radical, l'exact-hit manquait pour toutes les
// pistes: chacune retéléchargeait l'archive (deux fois — le miss déclenchait la
// reprise cache-bustée, qui efface d'abord le dossier), puis retombait sur un
// pick générique qui servait la piste 01 à tout l'album.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/rewamp_db.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rewamp_stem');
  });
  tearDown(() async {
    try { await dir.delete(recursive: true); } catch (_) {}
  });

  Future<void> put(String name, {int size = 4096}) async {
    final f = File(p.join(dir.path, name));
    await f.parent.create(recursive: true);
    await f.writeAsBytes(List<int>.filled(size, 7));
  }

  test('extension différente, même radical → la BONNE piste', () async {
    await put('Audio Track 01.ogg');
    await put('Audio Track 02.ogg');
    await put('Audio Track 03.ogg');

    // Chaque ligne retrouve LA SIENNE, pas la première du dossier.
    expect(p.basename((await RewampDb.debugFindByStem(dir.path, 'Audio Track 02.wav'))!),
        'Audio Track 02.ogg');
    expect(p.basename((await RewampDb.debugFindByStem(dir.path, 'Audio Track 03.wav'))!),
        'Audio Track 03.ogg');
  });

  test('radical présent plusieurs fois → le moins enfoui, pas null', () async {
    // Le rip jw_psf2 « Disgaea » range les mêmes SNDPAK_* sous jp/ ET usa/.
    // Rendre null là faisait retomber l'appelant sur le scan générique — qui
    // sert le plus gros fichier d'allure audio, donc une AUTRE piste — et,
    // avant lui, sur un re-téléchargement cache-busté de l'archive entière à
    // chaque lecture. Le NOM demandé est le bon: on choisit, à ordre stable.
    await put('track.ogg');
    await put('sub/track.flac');
    expect(await RewampDb.debugFindByStem(dir.path, 'track.wav'),
        endsWith('/track.ogg'));
  });

  test('un fichier non jouable au même nom ne compte pas', () async {
    await put('Audio Track 01.txt');
    expect(await RewampDb.debugFindByStem(dir.path, 'Audio Track 01.wav'), isNull);
  });

  test('artwork et archive temporaire sont ignorés', () async {
    await put('artwork.jpg');
    await put('_tmp_archive.7z');
    expect(await RewampDb.debugFindByStem(dir.path, 'artwork.png'), isNull);
  });

  test('rien à ce radical → null, le chemin normal reprend', () async {
    await put('autre chose.ogg');
    expect(await RewampDb.debugFindByStem(dir.path, 'Audio Track 01.wav'), isNull);
  });
}
