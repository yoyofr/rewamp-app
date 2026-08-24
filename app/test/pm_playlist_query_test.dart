// Playlists de presets projectM (migration 50).
//
// Comme les autres tests LocalDb, on teste les REQUÊTES sur une base mémoire
// (LocalDb exige path_provider) : l'append en fin de playlist
// (COALESCE(MAX(position)+1, 0)), la déduplication par (playlist_id, path) et
// l'upsert du cache chemin→preset_id — les trois points où une régression
// serait silencieuse (une position dupliquée ne casse rien à l'écriture, elle
// mélange l'ordre à la lecture).
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    // DDL identique à la migration 50 / _kSchemaStatements.
    await db.execute('''CREATE TABLE pm_playlists (
      id         TEXT    PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
      name       TEXT    NOT NULL,
      server_id  TEXT,
      created_at INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute('''CREATE TABLE pm_playlist_items (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      playlist_id TEXT    NOT NULL REFERENCES pm_playlists(id) ON DELETE CASCADE,
      position    INTEGER NOT NULL,
      path        TEXT    NOT NULL,
      preset_id   TEXT,
      name        TEXT
    )''');
    await db.execute('''CREATE TABLE pm_preset_ids (
      path       TEXT PRIMARY KEY,
      preset_id  TEXT NOT NULL
    )''');
  });

  tearDown(() => db.close());

  Future<String> createPlaylist(String name) async {
    final r = await db.rawQuery(
        'INSERT INTO pm_playlists (name) VALUES (?) RETURNING id', [name]);
    return r.first['id'] as String;
  }

  // La même forme d'INSERT que LocalDb.addPmPlaylistItem.
  Future<void> append(String pl, String path) => db.rawInsert(
      'INSERT INTO pm_playlist_items (playlist_id, position, path) '
      'VALUES (?, COALESCE((SELECT MAX(position) + 1 FROM pm_playlist_items '
      '                      WHERE playlist_id = ?), 0), ?)',
      [pl, pl, path]);

  test("l'append numérote 0,1,2 et par playlist", () async {
    final a = await createPlaylist('A');
    final b = await createPlaylist('B');
    await append(a, 'user/x.milk');
    await append(a, 'user/y.milk');
    await append(b, 'user/z.milk'); // sa numérotation ne dépend pas de A

    final rowsA = await db.rawQuery(
        'SELECT path, position FROM pm_playlist_items '
        'WHERE playlist_id = ? ORDER BY position', [a]);
    expect(rowsA.map((r) => r['position']).toList(), [0, 1]);
    final rowsB = await db.rawQuery(
        'SELECT position FROM pm_playlist_items WHERE playlist_id = ?', [b]);
    expect(rowsB.single['position'], 0);
  });

  test('la déduplication est par (playlist, path), pas globale', () async {
    final a = await createPlaylist('A');
    final b = await createPlaylist('B');
    await append(a, 'packs/base/p.milk');

    Future<bool> exists(String pl, String path) async {
      final r = await db.rawQuery(
          'SELECT 1 FROM pm_playlist_items WHERE playlist_id = ? AND path = ?',
          [pl, path]);
      return r.isNotEmpty;
    }

    expect(await exists(a, 'packs/base/p.milk'), isTrue);
    // Le même preset reste ajoutable à une AUTRE playlist.
    expect(await exists(b, 'packs/base/p.milk'), isFalse);
  });

  test('le cache chemin→id est un upsert (ré-import serveur = même id)', () async {
    Future<void> put(String path, String id) => db.rawInsert(
        'INSERT INTO pm_preset_ids (path, preset_id) VALUES (?, ?) '
        'ON CONFLICT(path) DO UPDATE SET preset_id = excluded.preset_id',
        [path, id]);

    await put('packs/base/p.milk', 'id-1');
    await put('packs/base/p.milk', 'id-2'); // seconde résolution: remplace
    final r = await db
        .rawQuery('SELECT preset_id FROM pm_preset_ids WHERE path = ?',
            ['packs/base/p.milk']);
    expect(r.single['preset_id'], 'id-2');
  });
}
