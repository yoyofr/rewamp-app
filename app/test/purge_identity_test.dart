// La purge juge l'IDENTITÉ, pas le fichier.
//
// Mesuré sur la base réelle le 2026-09-13: une passe de « Nettoyer la base
// locale » a retiré ~190 lignes, dont la quasi-totalité écrite EXPRÈS par
// `materializeAlbumTracks` — une ligne par piste d'album, clefée sur le chemin
// où le fichier ATTERRIRA, pour qu'une piste relancée depuis les récents avant
// sa première lecture ait un id, une collection et un titre. Les juger sur
// `File.exists()` effaçait chaque nuit ce que la lecture écrit le jour.
//
// C'est exactement la correction que la passe sœur (library_items) a reçue le
// 2026-08-28: « il ne teste PLUS l'existence du fichier ».

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _uuid = 'bcb8c353-590d-50b7-82ee-7bc72c3f0bb9';

void main() {
  group('critère de mort', () {
    test('une identité de CATALOGUE survit à l\'absence du fichier', () {
      // La ligne écrite d'avance pour la piste 40 d'un album de 150.
      expect(
          LocalDb.trackRowIsDead(onlineId: _uuid, fileExists: false), isFalse);
      // Une sous-chanson de conteneur porte `<uuid>#<rang>`.
      expect(LocalDb.trackRowIsDead(onlineId: '$_uuid#12', fileExists: false),
          isFalse);
    });

    test('un CHEMIN meurt avec son fichier', () {
      // Import local, lecture d'un fichier de l'utilisateur: le chemin est la
      // seule identité de la ligne.
      expect(LocalDb.trackRowIsDead(onlineId: null, fileExists: false), isTrue);
      expect(LocalDb.trackRowIsDead(onlineId: '', fileExists: false), isTrue);
      // Un `online_id` qui n'est PAS un uuid n'est pas une identité serveur.
      expect(
          LocalDb.trackRowIsDead(onlineId: '/tmp/x.mod', fileExists: false),
          isTrue);
    });

    test('un fichier présent n\'est jamais mort', () {
      expect(LocalDb.trackRowIsDead(onlineId: null, fileExists: true), isFalse);
      expect(LocalDb.trackRowIsDead(onlineId: _uuid, fileExists: true), isFalse);
    });
  });

  group('les albums touchés par une suppression', () {
    // ⚠️ Ce test EXÉCUTE la requête. Une faute de SQL est invisible à
    // l'analyzer: la première version écrivait `album_id != ""`, que SQLite
    // lit comme un IDENTIFIANT — « no such column: "" » —, et ça n'est apparu
    // qu'au premier geste de suppression, en pleine utilisation.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    test('la requête tourne et rend les albums sous le chemin', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('CREATE TABLE tracks (id INTEGER PRIMARY KEY, '
          'file_path TEXT, album_id TEXT)');
      await db.insert('tracks',
          {'file_path': '/m/album/a.vgz', 'album_id': 'A'});
      await db.insert('tracks',
          {'file_path': '/m/album/b.vgz', 'album_id': 'A'});
      await db.insert('tracks',
          {'file_path': '/m/autre/c.vgz', 'album_id': 'B'});
      // Une ligne sans album ne doit pas rendre une valeur vide.
      await db.insert('tracks', {'file_path': '/m/album/d.vgz', 'album_id': ''});
      await db.insert('tracks', {'file_path': '/m/album/e.vgz'});

      final rows = await db.rawQuery(
          LocalDb.kTouchedAlbumsSql, ['/m/album', '/m/album%']);
      expect([for (final r in rows) r['album_id']], ['A']);
      await db.close();
    });
  });

  group('marqueur album périmé', () {
    // `album_materialised` dit « la liste complète est en base ». C'est le SEUL
    // juge de `_healAlbumFavourites`: un marqueur que la base dément fige
    // l'album pour toujours — sa playlist Favoris reste amputée. Mesuré avant
    // correctif: 18 albums annonçaient 12 pistes pour 2 restantes.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    late Database db;
    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute(
          'CREATE TABLE tracks (id INTEGER PRIMARY KEY, album_id TEXT)');
      await db.execute('CREATE TABLE album_materialised ('
          'album_id TEXT PRIMARY KEY, track_count INTEGER, at INTEGER)');
    });
    tearDown(() => db.close());

    // La MÊME requête que pruneStaleAlbumMaterialised.
    Future<List<String>> stale() async {
      final rows = await db.rawQuery(
          'SELECT m.album_id AS id, m.track_count AS promised, '
          '(SELECT count(*) FROM tracks t WHERE t.album_id = m.album_id) AS actual '
          'FROM album_materialised m');
      return [
        for (final r in rows)
          if (((r['actual'] as num?)?.toInt() ?? 0) <
              ((r['promised'] as num?)?.toInt() ?? 0))
            r['id'] as String,
      ];
    }

    test('un marqueur que la base dément est périmé', () async {
      await db.insert('album_materialised',
          {'album_id': 'A', 'track_count': 12, 'at': 0});
      for (var i = 0; i < 2; i++) {
        await db.insert('tracks', {'album_id': 'A'});
      }
      expect(await stale(), ['A']);
    });

    test('un marqueur tenu ne bouge pas', () async {
      await db.insert('album_materialised',
          {'album_id': 'B', 'track_count': 3, 'at': 0});
      for (var i = 0; i < 3; i++) {
        await db.insert('tracks', {'album_id': 'B'});
      }
      expect(await stale(), isEmpty);
    });

    test('PLUS de lignes que promis n\'est pas périmé', () async {
      // Une piste jouée crée une ligne: le compte peut dépasser la promesse
      // sans que la liste soit incomplète. C'est précisément pourquoi le juge
      // est « moins que promis », et non « différent de ».
      await db.insert('album_materialised',
          {'album_id': 'C', 'track_count': 2, 'at': 0});
      for (var i = 0; i < 5; i++) {
        await db.insert('tracks', {'album_id': 'C'});
      }
      expect(await stale(), isEmpty);
    });
  });
}
