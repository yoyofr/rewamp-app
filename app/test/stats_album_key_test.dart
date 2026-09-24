import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Un album a DEUX clés possibles, et il ne faut pas les mélanger.
///
/// `COALESCE(album_id, nom)` retombe sur le NOM quand l'uuid manque — et il
/// manque pour toute écoute HORS CATALOGUE (`ext_key` en `local:<sha>`,
/// `song_id` vide): le compte connaît alors le nom d'album, jamais son uuid ni
/// sa pochette. Un album écouté des DEUX façons sortait donc DEUX FOIS dans
/// « Top albums », la moitié « nom » sans pochette. Mesuré sur la base réelle:
/// « Mega Man - Dr. Wily's Revenge » en `ce2341a6…` (24 écoutes, pochette) ET
/// en clair (33 écoutes, sans pochette).
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE tracks (
      id INTEGER PRIMARY KEY, file_path TEXT, entry_path TEXT,
      subsong_idx INTEGER, title TEXT, artist TEXT, meta_album TEXT,
      album_id TEXT, artwork_url TEXT, format_ext TEXT, duration_s REAL,
      online_id TEXT, ext_key TEXT)''');
    await db.execute('''CREATE TABLE play_events (
      id INTEGER PRIMARY KEY, track_id INTEGER, played_at INTEGER,
      played_ms INTEGER, backend TEXT)''');
    await db.execute('''CREATE TABLE account_play_events (
      song_id TEXT, subsong_idx INTEGER, ext_key TEXT, played_at INTEGER,
      played_ms INTEGER, backend TEXT)''');
    await db.execute('''CREATE TABLE account_track_meta (
      song_id TEXT, subsong_idx INTEGER, ext_key TEXT, title TEXT,
      album TEXT, album_id TEXT, artwork_url TEXT, artist TEXT,
      collection TEXT, format_ext TEXT, duration_s REAL)''');
  });

  tearDown(() => db.close());

  Future<List<Map<String, Object?>>> topAlbums() => db.rawQuery('''
      WITH ${LocalDb.statsEventsCte(false)}
      SELECT e.album_key AS k, MAX(e.album_name) AS name,
             MAX(e.artwork) AS art, COUNT(*) AS plays
      FROM ev e
      WHERE e.album_name IS NOT NULL AND e.album_name != ''
      GROUP BY e.album_key ORDER BY plays DESC
    ''');

  Future<void> play(int trackId) => db.insert('play_events',
      {'track_id': trackId, 'played_at': 1000, 'played_ms': 180000});

  test('le même album, avec et sans uuid, ne fait qu\'UNE ligne', () async {
    // La ligne du CATALOGUE: uuid + pochette.
    await db.insert('tracks', {
      'id': 1, 'file_path': '/x/a.gbs', 'entry_path': '', 'subsong_idx': 0,
      'title': 'Intro', 'meta_album': "Mega Man - Dr. Wily's Revenge",
      'album_id': 'ce2341a6', 'artwork_url': 'https://art/cover.jpg',
    });
    // Le MÊME album joué depuis un fichier local: ni uuid ni pochette.
    await db.insert('tracks', {
      'id': 2, 'file_path': '/y/b.gbs', 'entry_path': '', 'subsong_idx': 0,
      'title': 'Stage', 'meta_album': "Mega Man - Dr. Wily's Revenge",
    });
    await play(1);
    await play(2);
    await play(2);

    final rows = await topAlbums();
    expect(rows.length, 1, reason: 'un doublon signifie deux clés: $rows');
    expect(rows.first['k'], 'ce2341a6', reason: 'l\'uuid doit gagner');
    expect(rows.first['plays'], 3);
    expect(rows.first['art'], 'https://art/cover.jpg',
        reason: 'la pochette du catalogue doit survivre à la fusion');
  });

  test('un nom AMBIGU n\'est pas fusionné', () async {
    // « Commando » couvre cinq albums distincts: un nom n'est pas une
    // identité. Deux uuid pour un nom ⇒ on ne résout PAS, et la ligne sans
    // uuid reste à part plutôt que d'être collée au hasard sur l'un des deux.
    await db.insert('tracks', {
      'id': 1, 'file_path': '/x/a', 'entry_path': '', 'subsong_idx': 0,
      'meta_album': 'Commando', 'album_id': 'uuid-A',
    });
    await db.insert('tracks', {
      'id': 2, 'file_path': '/x/b', 'entry_path': '', 'subsong_idx': 0,
      'meta_album': 'Commando', 'album_id': 'uuid-B',
    });
    await db.insert('tracks', {
      'id': 3, 'file_path': '/x/c', 'entry_path': '', 'subsong_idx': 0,
      'meta_album': 'Commando',
    });
    await play(1);
    await play(2);
    await play(3);

    final keys = (await topAlbums()).map((r) => r['k']).toSet();
    expect(keys, {'uuid-A', 'uuid-B', 'Commando'});
  });

  test('un album SANS uuid nulle part garde son nom pour clé', () async {
    await db.insert('tracks', {
      'id': 1, 'file_path': '/x/a', 'entry_path': '', 'subsong_idx': 0,
      'meta_album': 'Démo maison',
    });
    await play(1);
    final rows = await topAlbums();
    expect(rows.single['k'], 'Démo maison');
  });
}
