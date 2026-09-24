import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/local_import.dart';

/// Un M3U ne fait la loi que dans SON dossier.
///
/// Un lot d'import mélange plusieurs dossiers (chaque archive dépliée dans le
/// sien, plus la racine), et les rips nomment leurs pistes « 01 Title.vgz »:
/// deux albums du lot partagent couramment des noms de fichiers. Clefé par nom
/// seul, le plan d'albums faisait deux choses fausses: le second fichier de
/// même nom ÉCRASAIT le premier dans la table, puis le M3U du premier album
/// réclamait le fichier du second et lui posait SON album, SON artiste et une
/// position — l'album et l'artiste d'un morceau sur les premières pistes d'un
/// autre.
void main() {
  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rewamp_m3u_scope_');
  });
  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  Future<LocalImportPendingTrack> track(String dir, String name) async {
    final f = File(p.join(tmp.path, dir, name));
    await f.parent.create(recursive: true);
    await f.writeAsBytes(const [0, 1, 2, 3]);
    return LocalImportPendingTrack(
        f.path, p.relative(f.path, from: tmp.path), 'archive', 'vgz');
  }

  test('des noms identiques dans deux dossiers ne se réclament pas', () async {
    // Album A: un M3U qui liste ses deux pistes.
    final a1 = await track('AlbumA', '01 Intro.vgz');
    final a2 = await track('AlbumA', '02 Stage.vgz');
    final m3u = File(p.join(tmp.path, 'AlbumA', '!tags.m3u'));
    await m3u.writeAsString('# @ALBUM  Album A\n01 Intro.vgz\n02 Stage.vgz\n');
    // Album B: les MÊMES noms de fichiers, et pas de M3U.
    final b1 = await track('AlbumB', '01 Intro.vgz');
    final b2 = await track('AlbumB', '02 Stage.vgz');

    final plan = await applyM3uAlbums([a1, a2, b1, b2], [], [m3u.path],
        canPlay: (_) => true);

    expect(a1.album, 'Album A');
    expect(a2.album, 'Album A');
    expect([a1.position, a2.position], [0, 1]);
    // ⚠️ Les pistes de B restent UNITAIRES: rien ne les a nommées.
    expect(b1.album, isNull, reason: 'AlbumB/01 réclamé par le M3U de A');
    expect(b2.album, isNull);
    expect(b1.position, isNull);
    // Et personne n'a disparu du plan (la démotion ne vaut que dans le dossier
    // régi par un M3U, et les deux pistes de A y sont nommées).
    expect(plan.tracks.length, 4);
    expect(plan.albums.map((x) => x.name), ['Album A']);
  });
}
