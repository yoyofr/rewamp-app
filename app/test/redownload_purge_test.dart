import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Re-télécharger n'est pas supprimer.
///
/// Le geste efface les OCTETS et tout ce qui les décrit (durée, nombre de
/// sous-chansons, position, pochette, lignes de récents) — mais jamais ce que
/// l'utilisateur a posé: le ♥, l'appartenance à la bibliothèque, et
/// l'historique d'écoute qui pend à la ligne (`play_events` est en cascade sur
/// `tracks`, donc effacer la ligne effacerait les écoutes avec).
///
/// Les deux conditions — celle qui garde et celle qui supprime — sont
/// exactement complémentaires par construction (`NOT (…)` de la même chaîne):
/// ce test épingle cette complémentarité, la seule façon de laisser une ligne
/// dans les deux camps ou dans aucun étant de les réécrire séparément.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  const underPath = "file_path = ? OR file_path LIKE ? ESCAPE '\\'";

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE tracks (
      id INTEGER PRIMARY KEY, file_path TEXT NOT NULL, subsong_idx INTEGER,
      title TEXT, duration_s REAL, subsong_count INTEGER, position INTEGER,
      is_favorite INTEGER NOT NULL DEFAULT 0,
      in_library INTEGER NOT NULL DEFAULT 0,
      play_count INTEGER NOT NULL DEFAULT 0,
      last_played_at INTEGER)''');
  });

  tearDown(() => db.close());

  Future<void> add(int id, String path, Map<String, Object?> extra) =>
      db.insert('tracks', {
        'id': id,
        'file_path': path,
        'subsong_idx': 0,
        'duration_s': 120.0,
        'subsong_count': 8,
        'position': 3,
        ...extra,
      });

  /// La séquence exacte de deleteEntriesUnderPath(keepUserState: true).
  Future<void> purge(String prefix) async {
    final like = '${prefix.replaceAll('%', r'\%')}%';
    await db.rawUpdate(
      'UPDATE tracks SET duration_s = NULL, subsong_count = NULL, '
      'position = NULL WHERE ($underPath) AND (${LocalDb.kUserStateFilter})',
      [prefix, like],
    );
    await db.rawDelete(
      'DELETE FROM tracks WHERE ($underPath) '
      'AND NOT (${LocalDb.kUserStateFilter})',
      [prefix, like],
    );
  }

  Future<List<int>> ids() async {
    final rows = await db.query('tracks', columns: ['id'], orderBy: 'id');
    return [for (final r in rows) r['id'] as int];
  }

  test('une ligne sans état utilisateur part, une ligne ♥ reste', () async {
    await add(1, '/dl/album/a.nsf', const {});
    await add(2, '/dl/album/b.nsf', const {'is_favorite': 1});
    await purge('/dl/album');
    expect(await ids(), [2]);
  });

  test('bibliothèque, écoutes et dernière lecture retiennent aussi la ligne',
      () async {
    await add(1, '/dl/album/a.nsf', const {'in_library': 1});
    await add(2, '/dl/album/b.nsf', const {'play_count': 4});
    await add(3, '/dl/album/c.nsf', const {'last_played_at': 1720000000});
    await add(4, '/dl/album/d.nsf', const {});
    await purge('/dl/album');
    expect(await ids(), [1, 2, 3]);
  });

  test('la ligne gardée est VIDÉE de ce qui décrit le contenu', () async {
    await add(1, '/dl/album/a.nsf', const {'in_library': 1});
    await purge('/dl/album');
    final row = (await db.query('tracks', where: 'id = 1')).single;
    expect(row['duration_s'], isNull);
    expect(row['subsong_count'], isNull);
    expect(row['position'], isNull);
    // Ce que le geste ne touche pas.
    expect(row['in_library'], 1);
  });

  test('chaque ligne visée est dans un camp et un seul', () async {
    // Les deux conditions étant complémentaires, la somme des gardées et des
    // supprimées vaut toujours le nombre de lignes sous le chemin.
    for (var i = 0; i < 8; i++) {
      await add(i, '/dl/album/$i.nsf', {
        'is_favorite': i & 1,
        'in_library': (i >> 1) & 1,
        'play_count': (i >> 2) & 1,
      });
    }
    await purge('/dl/album');
    final kept = await ids();
    // id 0 = aucun drapeau: la seule ligne sans état utilisateur.
    expect(kept, [1, 2, 3, 4, 5, 6, 7]);
  });

  test('un album voisin au chemin proche n\'est pas touché', () async {
    await add(1, '/dl/album/a.nsf', const {});
    await add(2, '/dl/autre/b.nsf', const {});
    await purge('/dl/album');
    expect(await ids(), [2]);
  });
}
