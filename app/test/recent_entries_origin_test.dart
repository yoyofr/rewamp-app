// « Écoutés récemment » remonte l'origine du CATALOGUE (mig 52).
//
// Le placeholder thématisé du rail se décidait sur l'extension du fichier —
// laquelle ne dit RIEN d'un conteneur (`.lha`, `.zip`) et se trompe sur un nom
// Amiga, qui porte son format AVANT le point (« mdat.monkey island »). Les
// colonnes existent sur `tracks` depuis la migration 52; ce test fige la
// requête qui les fait remonter, y compris pour une ligne d'ALBUM, que
// `recent_albums` ne peut pas renseigner elle-même.
//
// La requête n'est PAS recopiée ici: elle est lue dans le source. Une UNION mal
// alignée ne se voit qu'à l'exécution, et une copie aurait dérivé en silence.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Le corps SQL de `LocalDb.getRecentEntries`, tel qu'il sera exécuté.
String _recentEntriesSql() {
  // latin1: le fichier porte un octet non-UTF8 (`grep` le voit BINAIRE), et
  // seul le SQL nous intéresse, qui est en ASCII.
  final src = latin1.decode(File('lib/local_db.dart').readAsBytesSync());
  final at    = src.indexOf('Future<List<RecentEntry>> getRecentEntries');
  expect(at, greaterThan(0), reason: 'getRecentEntries introuvable');
  final start = src.indexOf("'''", at) + 3;
  final end   = src.indexOf("'''", start);
  final sql   = src.substring(start, end);
  expect(sql, contains('recent_albums'));
  return sql;
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE tracks (
      id TEXT PRIMARY KEY, title TEXT, artist TEXT, meta_album TEXT,
      album_id TEXT, online_id TEXT, file_path TEXT, entry_path TEXT,
      subsong_idx INTEGER, artwork_url TEXT, platform_name TEXT,
      format_ext TEXT, last_played_at INTEGER, is_favorite INTEGER DEFAULT 0,
      in_library INTEGER DEFAULT 0)''');
    await db.execute('''CREATE TABLE recent_albums (
      album_key TEXT, meta_album TEXT, artist TEXT, album_id TEXT,
      online_id TEXT, file_path TEXT, artwork_url TEXT,
      last_played_at INTEGER)''');
    await db.execute('''CREATE TABLE library_items (
      type TEXT, ref_id TEXT, album_id TEXT, is_favorite INTEGER)''');
  });

  tearDown(() => db.close());

  Future<List<Map<String, Object?>>> recents() =>
      db.rawQuery(_recentEntriesSql(), [50]);

  test('un module Amiga remonte sa plateforme et son format', () async {
    // Deux sous-chansons du MÊME fichier: le rail n'en montre qu'une.
    for (final (id, idx, played) in [('t1', 0, 100), ('t2', 1, 150)]) {
      await db.insert('tracks', {
        'id': id,
        'title': 'monkey island (${idx + 1})',
        'artist': 'Chris Huelsbeck',
        'online_id': 'uuid#$idx',
        'file_path': '/x/online/modland/mdat.monkey island',
        'entry_path': '',
        'subsong_idx': idx,
        'platform_name': 'Amiga',
        'format_ext': 'mdat',
        'last_played_at': played,
      });
    }
    final rows = await recents();
    expect(rows, hasLength(1));
    expect(rows.single['platform_name'], 'Amiga');
    expect(rows.single['format_ext'], 'mdat');
    // La sous-chanson la plus récente est celle que le rail relance.
    expect(rows.single['subsong_idx'], 1);
  });

  test("une ligne d'ALBUM hérite de l'origine d'une de ses pistes", () async {
    await db.insert('tracks', {
      'id': 't3',
      'title': 'some track',
      'meta_album': 'An Album',
      'album_id': 'alb-1',
      'online_id': 'uuid2',
      'file_path': '/x/online/joshw/a.gbs',
      'entry_path': '',
      'subsong_idx': 0,
      'platform_name': 'Game Boy',
      'format_ext': 'gbs',
      'last_played_at': 200,
    });
    await db.insert('recent_albums', {
      'album_key': 'alb-1',
      'meta_album': 'An Album',
      'album_id': 'alb-1',
      'file_path': '/x/online/joshw/a.gbs',
      'last_played_at': 210,
    });
    final rows = await recents();
    // La piste de l'album ne fait PAS une entrée à part.
    expect(rows, hasLength(1));
    expect(rows.single['kind'], 'album');
    expect(rows.single['platform_name'], 'Game Boy');
    expect(rows.single['format_ext'], 'gbs');
  });

  test('un fichier purement local n\'invente aucune origine', () async {
    await db.insert('tracks', {
      'id': 't4',
      'title': 'mine.mod',
      'file_path': '/home/me/mine.mod',
      'entry_path': '',
      'subsong_idx': 0,
      'last_played_at': 300,
    });
    final rows = await recents();
    expect(rows.single['platform_name'], isNull);
    expect(rows.single['format_ext'], isNull);
  });
}
