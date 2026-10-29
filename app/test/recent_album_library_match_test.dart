// L'étoile de bibliothèque d'un album RÉCENT (LocalDb.kRecentAlbumLibraryMatch).
//
// Mesuré sur une vraie base: « Dune » nomme trois albums du catalogue et un
// import local. Rattachés par « uuid OU nom », les trois prenaient l'étoile de
// l'import, et celui qui avait AUSSI sa propre entrée sortait en deux lignes —
// des clés dupliquées dans la rangée animée de l'accueil (RangeError). L'uuid
// décide quand il existe; le nom ne vaut que pour un album sans uuid.
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE recent_albums (
      album_key TEXT PRIMARY KEY, meta_album TEXT, album_id TEXT)''');
    await db.execute('''CREATE TABLE library_items (
      type TEXT, ref_id TEXT, album_id TEXT, is_favorite INTEGER)''');
    // Trois « Dune » du catalogue, dont un en bibliothèque (♥), et l'import
    // local homonyme, en bibliothèque lui aussi.
    for (final id in ['u-a', 'u-b', 'u-c']) {
      await db.insert('recent_albums',
          {'album_key': id, 'meta_album': 'Dune', 'album_id': id});
    }
    await db.insert('recent_albums',
        {'album_key': 'Dune', 'meta_album': 'Dune', 'album_id': null});
    await db.insert('library_items',
        {'type': 'album', 'ref_id': 'u-c', 'album_id': 'u-c', 'is_favorite': 1});
    await db.insert('library_items',
        {'type': 'album', 'ref_id': 'Dune', 'album_id': null, 'is_favorite': 0});
  });

  tearDown(() => db.close());

  Future<Map<String, (int, int)>> stars() async {
    const m = LocalDb.kRecentAlbumLibraryMatch;
    final rows = await db.rawQuery('''
      SELECT ra.album_key AS k,
        COALESCE((SELECT MAX(COALESCE(li.is_favorite, 0)) FROM library_items li
                   WHERE $m), 0) AS fav,
        EXISTS (SELECT 1 FROM library_items li WHERE $m) AS lib
      FROM recent_albums ra''');
    return {
      for (final r in rows)
        r['k'] as String: (r['fav'] as int, r['lib'] as int),
    };
  }

  test('une ligne par album, et l\'homonyme ne prête pas son étoile', () async {
    final s = await stars();
    expect(s.length, 4);
    expect(s['u-a'], (0, 0));
    expect(s['u-b'], (0, 0));
    expect(s['u-c'], (1, 1));
    expect(s['Dune'], (0, 1)); // l'import local garde la sienne
  });
}
