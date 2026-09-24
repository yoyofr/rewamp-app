// À l'import, un M3U qui liste PLUSIEURS fichiers distincts fait un ALBUM;
// un M3U qui n'en liste qu'UN décrit ses sous-chansons et n'en fait pas un.
// C'est la règle qui décide si la bibliothèque montre un album ou vingt
// morceaux détachés.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/local_import.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rewamp_m3u_album');
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  Future<String> mk(String name, [String content = 'x']) async {
    final f = File(p.join(tmp.path, name));
    await f.writeAsString(content);
    return f.path;
  }

  LocalImportPendingTrack track(String path, [String fmt = 'vgz']) =>
      LocalImportPendingTrack(path, p.basename(path), 'picker', fmt);

  test('un M3U de plusieurs fichiers fait un album, dans son ORDRE', () async {
    final a = await mk('02 Rebellion.vgz');
    final b = await mk('01 Logo.vgz');
    final m3u = await mk('Battle Garegga.m3u',
        '01 Logo.vgz\n02 Rebellion.vgz\n');
    final items = [track(a), track(b)];

    final plan = await applyM3uAlbums(items, const [], [m3u]);
    final albums = plan.albums;

    expect(albums.length, 1);
    expect(albums.first.name, 'Battle Garegga');
    // L'ordre vient du M3U, pas de celui de la copie.
    final byName = {for (final t in items) p.basename(t.filePath): t};
    expect(byName['01 Logo.vgz']!.position, 0);
    expect(byName['02 Rebellion.vgz']!.position, 1);
    expect(byName['01 Logo.vgz']!.album, 'Battle Garegga');
  });

  test("un M3U d'UN SEUL fichier décrit des sous-chansons, pas un album",
      () async {
    final mod = await mk('dmg-raj.gbs');
    final m3u = await mk('dmg-raj.m3u',
        'dmg-raj.gbs::GBS,1,Title A\ndmg-raj.gbs::GBS,3,Title B\n');
    final items = [track(mod)];

    final albums = (await applyM3uAlbums(items, const [], [m3u])).albums;

    expect(albums, isEmpty);
    expect(items.first.album, isNull);
    expect(items.first.position, isNull);
  });

  test('sans M3U, rien ne change', () async {
    final items = [track(await mk('a.vgz')), track(await mk('b.vgz'))];
    expect((await applyM3uAlbums(items, const [], const [])).albums, isEmpty);
    expect(items.every((t) => t.album == null), isTrue);
  });

  test('une piste déjà rattachée ne change pas d\'album', () async {
    final a = await mk('a.vgz');
    final b = await mk('b.vgz');
    final first = await mk('Premier.m3u', 'a.vgz\nb.vgz\n');
    final second = await mk('Second.m3u', 'a.vgz\nb.vgz\n');
    final items = [track(a), track(b)];

    final albums = (await applyM3uAlbums(items, const [], [first, second])).albums;

    expect(items.every((t) => t.album == 'Premier'), isTrue);
    // Le second M3U ne revendique rien: pas d'album vide non plus.
    expect(albums.map((a) => a.name), ['Premier']);
  });

  test('le M3U fait AUTORITÉ: il promeut ce qu\'il nomme et démote le reste',
      () async {
    // Le cas Touhou 06 (joshw_pc): chaque morceau existe en .pos (une piste
    // vgmstream: 8 octets de boucle + le .wav voisin), en .wav et en .mid. Le
    // !tags.m3u ne liste que les .pos.
    final pos1 = await mk('th06_01.pos');
    final pos2 = await mk('th06_02.pos');
    final wav1 = await mk('th06_01.wav');
    final mid1 = await mk('th06_01.mid');
    final m3u = await mk('!tags.m3u',
        '# @ALBUM Touhou 06\n'
        '# %TITLE Un titre\n'
        'th06_01.pos\n'
        '# %TITLE Un autre\n'
        'th06_02.pos\n');
    // .wav et .mid sont des PISTES pour les listes d'extensions; .pos non.
    final items  = [track(wav1, 'wav'), track(mid1, 'mid')];
    final others = [track(pos1, 'pos'), track(pos2, 'pos')];

    final plan = await applyM3uAlbums(items, others, [m3u],
        canPlay: (_) => true);

    final names = plan.tracks.map((t) => p.basename(t.filePath)).toList();
    expect(names, ['th06_01.pos', 'th06_02.pos']);
    // Le nom vient de @ALBUM, pas du fichier: « !tags » n'est pas un titre.
    expect(plan.albums.single.name, 'Touhou 06');
    expect(plan.tracks.first.title, 'Un titre');
  });

  test("sans @ALBUM, « !tags » retombe sur le nom du DOSSIER", () async {
    final a = await mk('a.pos');
    final b = await mk('b.pos');
    final m3u = await mk('!tags.m3u', 'a.pos\nb.pos\n');
    final plan = await applyM3uAlbums(<LocalImportPendingTrack>[],
        [track(a, 'pos'), track(b, 'pos')], [m3u], canPlay: (_) => true);
    expect(plan.albums.single.name, p.basename(tmp.path));
  });

  test('sans confirmation du moteur, rien n\'est promu', () async {
    final pos1 = await mk('a.pos');
    final pos2 = await mk('b.pos');
    final m3u = await mk('liste.m3u', 'a.pos\nb.pos\n');
    final plan = await applyM3uAlbums(
        <LocalImportPendingTrack>[], [track(pos1, 'pos'), track(pos2, 'pos')],
        [m3u]);   // canPlay absent
    expect(plan.tracks, isEmpty);
    expect(plan.albums, isEmpty);
  });
}
