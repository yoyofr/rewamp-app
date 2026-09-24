// L'élagage des dossiers vides remonte vers une RACINE — et il ne doit jamais
// la dépasser. La racine diffère selon l'arbre (imports sous `<support>/local`,
// téléchargements sous `<documents>/online`), c'est justement pour ça qu'elle
// est devenue un paramètre; se tromper de borne effacerait des dossiers qui
// n'appartiennent pas au geste.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/local_delete.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('rewamp_prune'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('les dossiers vides remontent jusqu\'à la racine, EXCLUE', () async {
    final root = Directory(p.join(tmp.path, 'online'))..createSync();
    final deep = Directory(p.join(root.path, 'coll', 'album'))
      ..createSync(recursive: true);

    await pruneEmptyDirs(deep.path, root: root.path);

    expect(deep.existsSync(), isFalse);
    expect(Directory(p.join(root.path, 'coll')).existsSync(), isFalse);
    // La racine elle-même RESTE: elle n'appartient pas au geste.
    expect(root.existsSync(), isTrue);
    expect(tmp.existsSync(), isTrue);
  });

  test('un dossier NON vide arrête la remontée', () async {
    final root = Directory(p.join(tmp.path, 'online'))..createSync();
    final coll = Directory(p.join(root.path, 'coll'))..createSync();
    File(p.join(coll.path, 'cover.jpg')).writeAsStringSync('x');
    final album = Directory(p.join(coll.path, 'album'))..createSync();

    await pruneEmptyDirs(album.path, root: root.path);

    expect(album.existsSync(), isFalse);
    expect(coll.existsSync(), isTrue, reason: 'il lui reste une pochette');
  });

  test('un dossier HORS de la racine n\'est pas touché', () async {
    final root = Directory(p.join(tmp.path, 'online'))..createSync();
    final outside = Directory(p.join(tmp.path, 'ailleurs'))..createSync();

    await pruneEmptyDirs(outside.path, root: root.path);

    expect(outside.existsSync(), isTrue);
  });
}
