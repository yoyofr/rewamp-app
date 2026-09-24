import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Une LECTURE n'est pas une ÉCOUTE.
///
/// `play_events` porte une ligne par lecture LANCÉE, quelle que soit sa durée —
/// parcourir les vingt sous-chansons d'un SID en produit vingt. Le COMPTE, lui,
/// ne reçoit que ce qui a franchi le seuil de `log_play`. Les deux vues
/// comptaient donc des choses différentes sous le même mot: sur la base réelle
/// de l'utilisateur, « Commando » affichait 74 écoutes au rail local de
/// l'accueil contre 24 à l'écran Stats fusionné, ses lignes locales étant
/// massivement des passages de 0 à 8 s.
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
    await db.insert('tracks', {
      'id': 1, 'file_path': '/x/commando.sid', 'entry_path': '',
      'subsong_idx': 0, 'title': 'Commando', 'online_id': 'uuid-commando',
      'ext_key': '',
    });
  });

  tearDown(() => db.close());

  Future<int> countedPlays() async {
    final rows = await db.rawQuery('''
      WITH ${LocalDb.statsEventsCte(false)}
      SELECT COUNT(*) AS n FROM ev e
    ''');
    return rows.first['n'] as int;
  }

  Future<void> play(int? ms) => db.insert('play_events',
      {'track_id': 1, 'played_at': 1000, 'played_ms': ms, 'backend': 'sid'});

  test('un saut de sous-chanson ne compte pas comme une écoute', () async {
    for (final ms in [0, 900, 4000, 8000, 9999]) {
      await play(ms);
    }
    expect(await countedPlays(), 0);
  });

  test('une écoute au-delà du seuil compte', () async {
    await play(LocalDb.kCountedPlayMinMs);
    await play(180000);
    expect(await countedPlays(), 2);
  });

  test('une durée INCONNUE compte — l\'app tuée n\'est pas un saut', () async {
    // `played_ms` n'est backfillé qu'à la fin propre d'une lecture: une app
    // tuée laisse une écoute réelle sans durée, et l'écarter la punirait deux
    // fois.
    await play(null);
    expect(await countedPlays(), 1);
  });

  test('le seuil est celui de log_play', () {
    // S'ils divergent, le rail local et l'écran Stats recomptent
    // différemment — c'est exactement le bug qu'on vient de corriger.
    expect(LocalDb.kCountedPlayMinMs, 10000);
  });
}
