// Un M3U d'ALBUM — plusieurs fichiers distincts listés une fois chacun —
// n'est PAS une liste de sous-chansons: l'appliquer à un fichier mono-piste
// lui inventait un index et un titre (« 02 Rebellion [Opening].vgz » sortait
// « 2 », Battle Garegga). L'autorité M3U ne vaut que quand le fichier y
// apparaît plusieurs fois (joshw: un .nsf, vingt lignes) ou que le M3U ne
// parle que de lui.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/local_open.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rewamp_m3u_test');
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

  test("un M3U d'album (fichiers distincts) ne pilote PAS les sous-chansons",
      () async {
    final a = await mk('01 One.vgz');
    await mk('02 Two.vgz');
    await mk('Album.m3u', '01 One.vgz\n02 Two.vgz\n');
    expect(await m3uSubsongsFor(a), isNull);
  });

  test('un M3U joshw (un fichier, N lignes) reste une autorité de sous-chansons',
      () async {
    final a = await mk('game.nsf');
    await mk('game.m3u',
        'game.nsf::NSF,1,Title Screen,60000\n'
        'game.nsf::NSF,2,Stage 1,120000\n');
    final subs = await m3uSubsongsFor(a);
    expect(subs, isNotNull);
    expect(subs!.length, 2);
    expect(subs.first.title, 'Title Screen');
  });

  test("un M3U qui ne parle QUE de ce fichier vaut aussi pour une seule ligne",
      () async {
    final a = await mk('solo.vgz');
    await mk('solo.m3u', 'solo.vgz::VGM,1,Le titre,60000\n');
    final subs = await m3uSubsongsFor(a);
    expect(subs, isNotNull);
    expect(subs!.single.title, 'Le titre');
  });
}
