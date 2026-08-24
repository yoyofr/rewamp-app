// Une entrée de bibliothèque se retrouve par (uuid, SOUS-CHANSON), pas par le
// seul uuid.
//
// Le compte tient une ligne par sous-chanson d'un même morceau — et c'est la
// règle, pas l'exception, pour un album conteneur dont toutes les pistes
// partagent l'identité du fichier (un `.psf` d'album jw_psf, un `.nsf`
// multi-subsongs). Une recherche sur le seul uuid ramenait la MÊME entrée
// locale pour toutes ces lignes: la dernière appliquée écrasait les
// précédentes, si bien qu'un ♥ posé depuis le lecteur s'éteignait quelques
// secondes plus tard, quand une ligne sœur `favourite: false` passait dans la
// même synchro.
//
// Le test tient sur la REQUÊTE — c'est elle qui décidait mal.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// La résolution telle que `LocalDb.libraryRefIdForSong` la pose.
Future<String?> refIdForSong(Database db, String songId,
    {int? subsongIdx}) async {
  Future<String?> exact(List<String> forms) async {
    final marks = List.filled(forms.length, '?').join(',');
    final rows = await db.query('library_items',
        columns: ['ref_id'],
        where: "type = 'track' AND ref_id IN ($marks)",
        whereArgs: forms,
        limit: 1);
    return rows.isEmpty ? null : rows.first['ref_id'] as String?;
  }

  if (subsongIdx != null) {
    final hit = await exact([
      '$songId?subsong=$subsongIdx',
      '$songId#$subsongIdx?subsong=0',
      '$songId#$subsongIdx?subsong=$subsongIdx',
      '$songId#$subsongIdx',
    ]);
    if (hit != null) return hit;
    if (subsongIdx != 0) return null;
  }
  final rows = await db.query('library_items',
      columns: ['ref_id'],
      where: "type = 'track' "
          "AND (ref_id = ? OR ref_id LIKE ? OR ref_id LIKE ?)",
      whereArgs: [songId, '$songId?subsong=%', '$songId#%'],
      limit: 1);
  return rows.isEmpty ? null : rows.first['ref_id'] as String?;
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const uuid = 'd8b57277-16fd-5415-91a6-64c70d5253ae';
  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(
        'CREATE TABLE library_items (type TEXT, ref_id TEXT, is_favorite INTEGER)');
  });

  tearDown(() => db.close());

  Future<void> item(String refId) =>
      db.insert('library_items', {'type': 'track', 'ref_id': refId, 'is_favorite': 0});

  test('chaque sous-chanson trouve SON entrée', () async {
    await item('$uuid?subsong=0');
    await item('$uuid?subsong=3');

    expect(await refIdForSong(db, uuid, subsongIdx: 0), '$uuid?subsong=0');
    expect(await refIdForSong(db, uuid, subsongIdx: 3), '$uuid?subsong=3');
  });

  test('une sous-chanson sans entrée n\'emprunte pas celle d\'une autre',
      () async {
    // Le cœur du bug: la ligne de la sous-chanson 7 s'appliquait sur l'entrée
    // de la 0 et en éteignait le ♥.
    await item('$uuid?subsong=0');

    expect(await refIdForSong(db, uuid, subsongIdx: 7), isNull);
  });

  test('la forme conteneur uuid#N est reconnue', () async {
    await item('$uuid#4');

    expect(await refIdForSong(db, uuid, subsongIdx: 4), '$uuid#4');
  });

  test('la clé du lecteur sur une piste de conteneur est reconnue', () async {
    // Ce que `PlayerController.libraryRefId` écrit pour la 30e piste d'un
    // album conteneur: le `#29` porte la sous-chanson, le `?subsong=0` dit que
    // le fichier de cette piste n'en a qu'une. Le compte, lui, la connaît
    // comme (uuid, 29) — c'est ce couple que la synchro rapporte.
    await item('$uuid#29?subsong=0');

    expect(await refIdForSong(db, uuid, subsongIdx: 29), '$uuid#29?subsong=0');
    // …et surtout: elle n'est PAS confondue avec une autre piste.
    expect(await refIdForSong(db, uuid, subsongIdx: 3), isNull);
  });

  test('repli large pour les entrées héritées, sous-chanson 0 seulement',
      () async {
    await item(uuid);   // entrée d'avant le scope par sous-chanson

    expect(await refIdForSong(db, uuid, subsongIdx: 0), uuid);
    expect(await refIdForSong(db, uuid, subsongIdx: 2), isNull);
  });
}
