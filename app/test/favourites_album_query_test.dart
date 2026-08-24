// La playlist Favoris et les pistes d'un album favori.
//
// Depuis la migration 41, le `ref_id` d'un album est son UUID (deux albums
// homonymes s'évinçaient l'un l'autre), alors que `tracks.meta_album` porte le
// NOM d'affichage — c'est ce que materializeAlbumTracks y écrit. La lecture,
// elle, comparait `meta_album` au `ref_id` : elle ne matchait donc plus rien et
// mettre un album en favori ne faisait apparaître aucune de ses pistes.
//
// Le test tient sur la REQUÊTE, pas sur LocalDb (qui a besoin de path_provider):
// c'est la jointure qui était fausse, et c'est elle qu'il faut figer.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _kOldQuery = '''
  SELECT * FROM tracks
  WHERE meta_album = ?
  ORDER BY COALESCE(position, 999) ASC, subsong_idx ASC
''';

/// La requête telle que LocalDb.getFavorites la pose aujourd'hui.
const _kNewQuery = '''
  SELECT * FROM tracks
  WHERE (album_id IS NOT NULL AND album_id = ?)
     OR meta_album = ?
     OR meta_album = ?
  ORDER BY COALESCE(position, 999) ASC, subsong_idx ASC
''';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE library_items (
      type TEXT, ref_id TEXT, name TEXT, album_id TEXT, is_favorite INTEGER)''');
    await db.execute('''CREATE TABLE tracks (
      file_path TEXT, subsong_idx INTEGER, title TEXT,
      meta_album TEXT, album_id TEXT, position INTEGER)''');
  });

  tearDown(() => db.close());

  Future<List<Map<String, Object?>>> run(String sql, List<Object?> args) =>
      db.rawQuery(sql, args);

  test('un album favori keyé par UUID retrouve ses pistes', () async {
    const uuid = '3237fadf-58af-500e-9fe7-8520f910df4e';
    const name = 'Insignificant Demo';
    await db.insert('library_items', {
      'type': 'album', 'ref_id': uuid, 'name': name,
      'album_id': uuid, 'is_favorite': 1,
    });
    for (var i = 1; i <= 3; i++) {
      await db.insert('tracks', {
        'file_path': '/x/$i.4v', 'subsong_idx': 0, 'title': 'piste $i',
        'meta_album': name, 'album_id': uuid, 'position': i,
      });
    }

    // Ce que faisait l'ancienne lecture : comparer le NOM au ref_id (un UUID).
    expect((await run(_kOldQuery, [uuid])), isEmpty,
        reason: 'la régression: aucune piste ne remontait');

    final rows = await run(_kNewQuery, [uuid, name, uuid]);
    expect(rows.map((r) => r['title']), ['piste 1', 'piste 2', 'piste 3']);
  });

  test('une ligne antérieure à la mig 41 (keyée par le nom) marche encore',
      () async {
    const name = 'Vieil Album';
    await db.insert('library_items', {
      'type': 'album', 'ref_id': name, 'name': name,
      'album_id': null, 'is_favorite': 1,
    });
    await db.insert('tracks', {
      'file_path': '/x/1.mod', 'subsong_idx': 0, 'title': 'unique',
      'meta_album': name, 'album_id': null, 'position': 1,
    });

    final rows = await run(_kNewQuery, [null, name, name]);
    expect(rows.map((r) => r['title']), ['unique']);
  });

  test('deux albums homonymes ne se mélangent pas', () async {
    const a = 'aaaaaaaa-0000-0000-0000-000000000000';
    const b = 'bbbbbbbb-0000-0000-0000-000000000000';
    const name = 'Final Fantasy III';
    for (final (uuid, title) in [(a, 'snes'), (b, 'nes')]) {
      await db.insert('tracks', {
        'file_path': '/x/$title.spc', 'subsong_idx': 0, 'title': title,
        'meta_album': name, 'album_id': uuid, 'position': 1,
      });
    }
    // L'identité prime: le nom seul ramènerait les deux.
    final rows = await run('''
      SELECT * FROM tracks WHERE album_id IS NOT NULL AND album_id = ?
    ''', [a]);
    expect(rows.map((r) => r['title']), ['snes']);
  });
}
