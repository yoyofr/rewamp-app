// iOS: `tracks.file_path` est STOCKÉ normalisé (`{sandbox}/…` — l'UUID du
// conteneur change à chaque lancement), donc les deux vues des
// téléchargements doivent traduire dans le bon sens: `_norm` pour interroger
// la colonne, `_denorm` pour toucher le disque.
//
// Sans ça, sur iOS seulement: le compte comparait la colonne à une racine
// ABSOLUE (aucune ligne) et la liste `stat`ait la forme stockée (aucun
// fichier) — l'onglet Local annonçait « 0 téléchargement » alors que
// `online/` était plein.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/library_presence.dart';
import 'package:rewamp/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;
  late String base;
  late Database db;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dlsandbox');
    // La forme iOS: <conteneur>/Documents est la racine de l'app, et c'est le
    // PARENT qui est tokenisé.
    base = p.join(tmp.path, 'Documents');
    await Directory(p.join(base, 'online', 'jw_spc', 'uuid')).create(
        recursive: true);
    await File(p.join(base, 'online', 'jw_spc', 'uuid', 'a.spc'))
        .writeAsString('x');

    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE tracks (id TEXT PRIMARY KEY, '
        'file_path TEXT, entry_path TEXT, subsong_idx INTEGER, '
        'album_id TEXT, meta_album TEXT, title TEXT, artist TEXT, '
        'source TEXT, online_id TEXT, is_favorite INTEGER, '
        'in_library INTEGER, play_count INTEGER)');
    await db.execute("CREATE TABLE library_items (ref_id TEXT, type TEXT, "
        "name TEXT)");
    await db.execute('CREATE TABLE recent_albums (album_id TEXT, '
        'meta_album TEXT)');
    // La ligne telle que l'app l'écrit sur iOS.
    await db.insert('tracks', {
      'id': 't1',
      'file_path': '{sandbox}/Documents/online/jw_spc/uuid/a.spc',
      'entry_path': '',
      'subsong_idx': 0,
      'title': 'a',
      'source': 'online',
      'is_favorite': 0,
      'in_library': 0,
      'play_count': 0,
    });
    LocalDb.instance.debugUseDatabase(db);
    LocalDb.instance.debugUseBaseDir(Directory(base));
    LocalDb.setSandboxRoot(tmp.path);
    invalidateLocalPresence();
  });

  tearDown(() async {
    await db.close();
    LocalDb.setSandboxRoot('');
    invalidateLocalPresence();
    await tmp.delete(recursive: true);
  });

  test('une ligne {sandbox} est COMPTÉE', () async {
    expect(await LocalDb.instance.countDownloadedTracks(), 1);
  });

  test('une ligne {sandbox} est LISTÉE, chemin absolu', () async {
    final rows = await LocalDb.instance.getDownloadedTracks();
    expect(rows.length, 1);
    expect(rows.first.$1, p.join('jw_spc', 'uuid', 'a.spc'));
    expect(rows.first.$2.filePath,
        p.join(base, 'online', 'jw_spc', 'uuid', 'a.spc'));
  });

  test('une ligne dont le fichier manque ne compte pas', () async {
    await File(p.join(base, 'online', 'jw_spc', 'uuid', 'a.spc')).delete();
    invalidateLocalPresence();
    expect(await LocalDb.instance.countDownloadedTracks(), 0);
    expect(await LocalDb.instance.getDownloadedTracks(), isEmpty);
  });
}
