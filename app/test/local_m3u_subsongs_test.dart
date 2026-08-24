import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_open.dart';

/// Le M3U d'un rip GBgbs, tel qu'il voyage DANS l'archive: index de
/// sous-chansons NON CONTIGUS, titres réels, durées. C'est ce que la sonde
/// native ne peut pas savoir — elle rendrait un compte brut, cases mortes
/// comprises, sous des titres numérotés.
const _m3u = '''
# @TITLE       Gargoyle's Quest
# @ARTIST      Capcom
# @RIPPER      GBgbs

DMG-RAJ.gbs::GBS,0,Title,1:17,,10
DMG-RAJ.gbs::GBS,2,Village,0:32,,10
DMG-RAJ.gbs::GBS,3,Demon Border,1:12,,10
DMG-RAJ.gbs::GBS,12,Boss,1:09,,10
DMG-RAJ.gbs::GBS,16,Clear,0:05,,1
''';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('rewamp_m3u_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String write(String name, String content) {
    final f = File('${tmp.path}/$name')..writeAsStringSync(content);
    return f.path;
  }

  test('le M3U voisin fait autorité sur les sous-chansons', () async {
    // Le module n'est jamais lu ici: seul le M3U parle.
    final gbs = write('DMG-RAJ.gbs', 'stub');
    write('DMG-RAJ.m3u', _m3u);

    final tracks = await m3uSubsongsFor(gbs, album: 'Gargoyle\'s Quest');
    expect(tracks, isNotNull);
    expect(tracks!.length, 5);
    // Les VRAIS index, pas 0..4: les cases entre les deux sont muettes.
    expect([for (final t in tracks) t.subsongIdx], [0, 2, 3, 12, 16]);
    expect([for (final t in tracks) t.title],
        ['Title', 'Village', 'Demon Border', 'Boss', 'Clear']);
    // Le chemin RÉEL du fichier, pas celui reconstruit par le parseur.
    expect(tracks.every((t) => t.filePath == gbs), isTrue);
    expect(tracks.first.durationS, closeTo(77, 0.5)); // 1:17
    expect(tracks.first.metaAlbum, 'Gargoyle\'s Quest');
    expect(tracks.first.formatExt, 'gbs');
  });

  test('pas de M3U: on rend null et l\'appelant sonde le moteur', () async {
    final gbs = write('Solo.gbs', 'stub');
    expect(await m3uSubsongsFor(gbs), isNull);
  });

  test('un M3U qui ne parle pas de CE fichier ne le concerne pas', () async {
    // Deux modules dans le même dossier, un seul listé.
    write('DMG-RAJ.gbs', 'stub');
    write('DMG-RAJ.m3u', _m3u);
    final other = write('Autre.gbs', 'stub');
    expect(await m3uSubsongsFor(other), isNull);
  });
}
