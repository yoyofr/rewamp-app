// L'identité catalogue d'une entrée « écoutés récemment » (migration 51).
//
// Un `online_id` de la forme `<uuid>#<rang>` désigne UNE ENTRÉE d'un conteneur,
// et le rang n'est pas l'index de sous-chanson — mesuré sur un `.gbs` joshw
// réel: la sous-chanson 12 porte `#13`. Seul l'uuid identifie le FICHIER, donc
// c'est lui qu'on retient, et seulement si toutes les lignes du fichier
// s'accordent dessus. Le test porte sur la REQUÊTE, comme les autres tests
// LocalDb (qui a besoin de path_provider).
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _kBackfill = '''
  UPDATE recent_albums SET online_id = (
    SELECT MIN(CASE WHEN instr(t.online_id, '#') > 0
                    THEN substr(t.online_id, 1, instr(t.online_id, '#') - 1)
                    ELSE t.online_id END)
      FROM tracks t
     WHERE t.file_path = recent_albums.file_path
       AND t.online_id IS NOT NULL
    HAVING COUNT(DISTINCT CASE WHEN instr(t.online_id, '#') > 0
                    THEN substr(t.online_id, 1, instr(t.online_id, '#') - 1)
                    ELSE t.online_id END) = 1
  ) WHERE online_id IS NULL
''';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE tracks (
      file_path TEXT, subsong_idx INTEGER, online_id TEXT)''');
    await db.execute('''CREATE TABLE recent_albums (
      album_key TEXT PRIMARY KEY, meta_album TEXT, file_path TEXT,
      online_id TEXT)''');
  });

  tearDown(() => db.close());

  Future<String?> backfilled(String key) async {
    await db.execute(_kBackfill);
    final r = await db
        .rawQuery('SELECT online_id FROM recent_albums WHERE album_key = ?', [key]);
    return r.single['online_id'] as String?;
  }

  test('un conteneur rend son uuid, jamais le rang de la sous-chanson', () async {
    const uuid = '06eb55e9-31ff-5378-bffa-9d2ab4e93818';
    const path = '/online/jw_gbs/x/DMG-RWA.gbs';
    // Le décalage rang/sous-chanson est le vrai cas mesuré: 12 → #13.
    for (final (idx, rank) in [(7, 7), (8, 8), (12, 13), (15, 14)]) {
      await db.insert('tracks',
          {'file_path': path, 'subsong_idx': idx, 'online_id': '$uuid#$rank'});
    }
    // Les sous-chansons jamais jouées en ligne n'ont pas d'identité.
    for (var i = 0; i < 7; i++) {
      await db.insert('tracks',
          {'file_path': path, 'subsong_idx': i, 'online_id': null});
    }
    await db.insert('recent_albums',
        {'album_key': 'a', 'meta_album': 'Mega Man', 'file_path': path});

    expect(await backfilled('a'), uuid);
  });

  test('un fichier revendiqué par deux uuid ne rend rien', () async {
    const path = '/online/snesmusic/y/album.rsn';
    await db.insert('tracks',
        {'file_path': path, 'subsong_idx': 0, 'online_id': 'aaa#1'});
    await db.insert('tracks',
        {'file_path': path, 'subsong_idx': 1, 'online_id': 'bbb#2'});
    await db.insert('recent_albums',
        {'album_key': 'b', 'meta_album': 'RSN', 'file_path': path});

    expect(await backfilled('b'), isNull);
  });

  test('un id sans suffixe passe tel quel, un fichier local reste nul', () async {
    await db.insert('tracks', {
      'file_path': '/online/modland/z/song.mod',
      'subsong_idx': 0,
      'online_id': 'plain-uuid',
    });
    await db.insert('recent_albums', {
      'album_key': 'c',
      'meta_album': 'Mod',
      'file_path': '/online/modland/z/song.mod',
    });
    await db.insert('recent_albums', {
      'album_key': 'd',
      'meta_album': 'Perso',
      'file_path': '/Users/me/Music/track.xm',
    });

    expect(await backfilled('c'), 'plain-uuid');
    expect(await backfilled('d'), isNull);
  });
}
