// La fusion des écoutes de plusieurs appareils (écran Stats, migration 45).
//
// Deux sources: `play_events` (cet appareil) et `account_play_events` (la
// timeline du compte, miroir de `user_play_history`). Deux choses doivent
// tenir, et rien d'autre ne compte vraiment:
//
//   * ne JAMAIS compter deux fois la même écoute. Le marqueur est
//     `play_events.pushed`, pas un rapprochement temporel: `log_play` n'envoie
//     pas de `played_at` et le serveur estampille `now()`, jusqu'à une
//     longueur de morceau après le début de la lecture.
//   * regrouper la même piste écoutée ICI et AILLEURS sur une seule ligne —
//     c'est le rôle de la clé `k` du fragment, et le seul endroit où les deux
//     façons d'identifier une piste (locale, serveur) se rencontrent.
//
// Le test tient sur le SQL (LocalDb.statsEventsCte), pas sur LocalDb, qui a
// besoin de path_provider.
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE tracks (
      id TEXT PRIMARY KEY, file_path TEXT NOT NULL, entry_path TEXT NOT NULL
        DEFAULT '', subsong_idx INTEGER NOT NULL DEFAULT 0,
      title TEXT, artist TEXT, meta_album TEXT, album_id TEXT,
      duration_s REAL, format_ext TEXT, online_id TEXT, artwork_url TEXT,
      ext_key TEXT)''');
    await db.execute('''CREATE TABLE play_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT, track_id TEXT NOT NULL,
      played_at INTEGER NOT NULL, played_ms INTEGER, backend TEXT,
      pushed INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''CREATE TABLE account_play_events (
      kind TEXT NOT NULL, song_id TEXT NOT NULL DEFAULT '',
      subsong_idx INTEGER NOT NULL DEFAULT 0,
      ext_key TEXT NOT NULL DEFAULT '', played_at INTEGER NOT NULL,
      played_ms INTEGER, backend TEXT,
      PRIMARY KEY (song_id, subsong_idx, ext_key, played_at))''');
    await db.execute('''CREATE TABLE account_track_meta (
      song_id TEXT NOT NULL DEFAULT '', subsong_idx INTEGER NOT NULL DEFAULT 0,
      ext_key TEXT NOT NULL DEFAULT '', title TEXT, artist TEXT, album TEXT,
      album_id TEXT, artwork_url TEXT, collection TEXT, platform TEXT,
      format_ext TEXT, duration_s REAL,
      PRIMARY KEY (song_id, subsong_idx, ext_key))''');
  });

  tearDown(() => db.close());

  Future<void> track(String id,
      {String? onlineId, int subsong = 0, String? extKey, String? title}) =>
      db.insert('tracks', {
        'id':          id,
        'file_path':   '/music/$id.mod',
        'entry_path':  '',
        'subsong_idx': subsong,
        'title':       title ?? id,
        'online_id':   onlineId,
        'ext_key':     extKey,
      });

  Future<void> localPlay(String trackId, int at, {bool pushed = false}) =>
      db.insert('play_events',
          {'track_id': trackId, 'played_at': at, 'pushed': pushed ? 1 : 0});

  Future<void> accountPlay(int at,
          {String songId = '', int subsong = 0, String extKey = ''}) =>
      db.insert('account_play_events', {
        'kind':        extKey.isEmpty ? 'song' : 'ext',
        'song_id':     songId,
        'subsong_idx': subsong,
        'ext_key':     extKey,
        'played_at':   at,
      });

  /// Le classement des morceaux, réduit à ce que le test regarde: la clé de
  /// regroupement et le nombre d'écoutes.
  Future<List<(String, int)>> tops({required bool merged}) async {
    final rows = await db.rawQuery('''
      WITH ${LocalDb.statsEventsCte(merged)}
      SELECT e.k AS k, COUNT(*) AS plays FROM ev e
      GROUP BY e.k ORDER BY plays DESC, k
    ''');
    return [
      for (final r in rows) (r['k'] as String, (r['plays'] as int?) ?? 0),
    ];
  }

  test('vue locale: toutes les écoutes de cet appareil, livrées ou non',
      () async {
    await track('t1', onlineId: 'uuid-a');
    await localPlay('t1', 1000);
    await localPlay('t1', 2000, pushed: true);
    await accountPlay(2000, songId: 'uuid-a');

    expect(await tops(merged: false), [('song:uuid-a#0', 2)]);
  });

  test('vue fusionnée: le compte fait autorité sur sa fenêtre', () async {
    await track('t1', onlineId: 'uuid-a');
    await localPlay('t1', 1500);                 // dans la fenêtre du compte
    await accountPlay(1000, songId: 'uuid-a');
    await accountPlay(3000, songId: 'uuid-a');   // un autre appareil

    // Les deux du compte, et rien de local: 2, pas 3.
    expect(await tops(merged: true), [('song:uuid-a#0', 2)]);
  });

  test('une écoute POSTÉRIEURE au miroir attend sa descente', () async {
    // Elle ne compte pas encore: c'est ce qui empêche une lecture interrompue
    // (rien ne partira jamais) de faire diverger deux appareils pour toujours.
    await track('t1', onlineId: 'uuid-a');
    await accountPlay(1000, songId: 'uuid-a');
    await localPlay('t1', 5000);

    expect(await tops(merged: true), [('song:uuid-a#0', 1)]);
    expect(await tops(merged: false), [('song:uuid-a#0', 1)]);
  });

  test('l\'historique d\'AVANT le compte compte, lui', () async {
    // C'est la seule chose que le local apporte: le compte ne peut pas l'avoir.
    await track('t1', onlineId: 'uuid-a');
    await localPlay('t1', 500);                  // avant tout ce que le compte a
    await accountPlay(1000, songId: 'uuid-a');
    await accountPlay(2000, songId: 'uuid-a');

    expect(await tops(merged: true), [('song:uuid-a#0', 3)]);
  });

  test('miroir vide: la vue fusionnée compte tout le local', () async {
    await track('t1', onlineId: 'uuid-a');
    await localPlay('t1', 1000);
    await localPlay('t1', 2000);

    expect(await tops(merged: true), [('song:uuid-a#0', 2)]);
  });

  test('un uuid nu + subsong_idx et un uuid#n désignent la même piste',
      () async {
    await track('t2', onlineId: 'uuid-b', subsong: 2);
    await localPlay('t2', 1000);
    await accountPlay(2000, songId: 'uuid-b', subsong: 2);

    expect(await tops(merged: true), [('song:uuid-b#2', 2)]);
  });

  test('un uuid#n local rejoint la même identité serveur', () async {
    await track('t3', onlineId: 'uuid-c#4');
    await localPlay('t3', 1000);
    await accountPlay(2000, songId: 'uuid-c', subsong: 4);

    expect(await tops(merged: true), [('song:uuid-c#4', 2)]);
  });

  test('un fichier hors catalogue se rejoint par son ext_key', () async {
    await track('t4', extKey: 'local:abc');
    await localPlay('t4', 1000);
    await accountPlay(2000, extKey: 'local:abc');

    expect(await tops(merged: true), [('ext:local:abc', 2)]);
  });

  test('sans ext_key connue, la piste locale reste identifiée par son chemin',
      () async {
    await track('t5');
    await localPlay('t5', 1000);
    await accountPlay(2000, extKey: 'local:jamais-vue');

    expect(await tops(merged: true),
        [('ext:local:jamais-vue', 1), ('file:/music/t5.mod||0', 1)]);
  });

  test('plusieurs lignes tracks pour un même morceau ne dupliquent pas '
      'ses écoutes', () async {
    // Le même morceau téléchargé deux fois (chemins différents, même
    // online_id): un LEFT JOIN sur tracks comptait chaque écoute deux fois.
    await track('t1', onlineId: 'uuid-a');
    await track('t1bis', onlineId: 'uuid-a');
    await accountPlay(1000, songId: 'uuid-a');
    await accountPlay(2000, songId: 'uuid-a');

    expect(await tops(merged: true), [('song:uuid-a#0', 2)]);
  });

  test('le moteur fusionne: celui du compte comme celui d\'ici', () async {
    await track('t1', onlineId: 'uuid-a');
    await db.insert('play_events', {
      'track_id': 't1', 'played_at': 500, 'pushed': 0, 'backend': 'uade'});
    await db.insert('account_play_events', {
      'kind': 'song', 'song_id': 'uuid-b', 'subsong_idx': 0, 'ext_key': '',
      'played_at': 2000, 'backend': 'psgplay'});
    final rows = await db.rawQuery('''
      WITH ${LocalDb.statsEventsCte(true)}
      SELECT e.backend AS k, COUNT(*) AS n FROM ev e
      WHERE e.backend IS NOT NULL AND e.backend != ''
      GROUP BY e.backend ORDER BY k
    ''');
    expect([for (final r in rows) (r['k'], r['n'])],
        [('psgplay', 1), ('uade', 1)]);
  });

  test('une écoute du compte portant sur une piste absente compte quand même',
      () async {
    await db.insert('account_track_meta', {
      'song_id': 'uuid-d', 'subsong_idx': 0, 'ext_key': '',
      'title': 'Ailleurs', 'album': 'Un album',
    });
    await accountPlay(1000, songId: 'uuid-d');
    await accountPlay(2000, songId: 'uuid-d');

    expect(await tops(merged: true), [('song:uuid-d#0', 2)]);
    // Et elle est nommée, sinon l'écran n'afficherait qu'un uuid.
    final named = await db.rawQuery('''
      WITH ${LocalDb.statsEventsCte(true)}
      SELECT MAX(e.title) AS t, MAX(e.album_name) AS a FROM ev e
    ''');
    expect(named.first['t'], 'Ailleurs');
    expect(named.first['a'], 'Un album');
  });
}
