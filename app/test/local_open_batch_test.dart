import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/local_db.dart';
import 'package:rewamp/rewamp_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ouvrir un dossier (« Tout lire » sur les imports locaux) résolvait CHAQUE
/// fichier par sa propre requête `tracks` et relistait son dossier pour y
/// chercher un M3U — en série, derrière la file unique de sqflite. Mesuré:
/// 185 MIDIs, 5,2 s de résolution, jusqu'à 197 ms pour UN fichier alors que la
/// requête coûte 0,02 ms. Les deux raccourcis (une requête pour le lot, une
/// mémoire M3U par geste) doivent rendre EXACTEMENT ce que rendait le chemin
/// un-par-un.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('getTracksForFiles', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('''CREATE TABLE tracks (
        id TEXT PRIMARY KEY, file_path TEXT NOT NULL, entry_path TEXT NOT NULL,
        subsong_idx INTEGER NOT NULL, title TEXT, artist TEXT, meta_album TEXT,
        album_id TEXT, position INTEGER, duration_s REAL, format_ext TEXT,
        subsong_count INTEGER, source TEXT NOT NULL, online_id TEXT,
        artwork_url TEXT, collection_slug TEXT, platform_name TEXT,
        year INTEGER, is_favorite INTEGER NOT NULL DEFAULT 0,
        in_library INTEGER NOT NULL DEFAULT 0,
        play_count INTEGER NOT NULL DEFAULT 0, last_played_at INTEGER,
        UNIQUE(file_path, entry_path, subsong_idx))''');
      LocalDb.instance.debugUseDatabase(db);
    });

    tearDown(() => db.close());

    Future<void> add(String path, int sub, String title) => db.insert('tracks', {
          'id': '$path#$sub', 'file_path': path, 'entry_path': '',
          'subsong_idx': sub, 'title': title, 'source': 'local',
        });

    test('même résultat que getTracksForFile, chemin par chemin', () async {
      await add('/m/a.mid', 0, 'A');
      await add('/m/b.nsf', 2, 'B3');
      await add('/m/b.nsf', 0, 'B1');
      await add('/m/c.mid', 0, 'C');
      final asked = ['/m/a.mid', '/m/b.nsf', '/m/absent.mid', '/m/c.mid'];

      final batch = await LocalDb.instance.getTracksForFiles(asked);
      for (final f in asked) {
        final one = await LocalDb.instance.getTracksForFile(f);
        final many = batch[f] ?? const [];
        expect([for (final t in many) (t.subsongIdx, t.title)],
            [for (final t in one) (t.subsongIdx, t.title)],
            reason: f);
      }
      // Un chemin sans ligne est ABSENT de la table, pas une liste vide.
      expect(batch.containsKey('/m/absent.mid'), isFalse);
      expect([for (final t in batch['/m/b.nsf']!) t.subsongIdx], [0, 2]);
    });

    test('au-delà d\'une tranche de paramètres liés', () async {
      final paths = [for (var i = 0; i < 1234; i++) '/big/f$i.mid'];
      final b = db.batch();
      for (final f in paths) {
        b.insert('tracks', {
          'id': f, 'file_path': f, 'entry_path': '', 'subsong_idx': 0,
          'title': p.basename(f), 'source': 'local',
        });
      }
      await b.commit(noResult: true);
      final got = await LocalDb.instance.getTracksForFiles(paths);
      expect(got.length, paths.length);
      expect(got['/big/f1233.mid']!.single.title, 'f1233.mid');
    });

    test('lot vide: aucune requête, table vide', () async {
      expect(await LocalDb.instance.getTracksForFiles(const []), isEmpty);
    });
  });

  group('M3uLookupCache', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('m3u_cache_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('mêmes sous-chansons avec et sans mémoire, dossier listé une fois',
        () async {
      for (final n in ['a.nsf', 'b.nsf', 'c.nsf']) {
        File(p.join(dir.path, n)).writeAsBytesSync(const [0]);
      }
      // Deux playlists: la plus LONGUE gagne, quel que soit le fichier.
      File(p.join(dir.path, 'short.m3u'))
          .writeAsStringSync('a.nsf::NSF,1,Un,0:30,,\n');
      File(p.join(dir.path, 'long.m3u')).writeAsStringSync(
          'a.nsf::NSF,1,Un,0:30,,\n'
          'b.nsf::NSF,1,Deux,0:40,,\n'
          'c.nsf::NSF,2,Trois,0:50,,\n');

      final cache = M3uLookupCache();
      for (final n in ['a.nsf', 'b.nsf', 'c.nsf']) {
        final f = p.join(dir.path, n);
        final plain = await RewampDb.probeLocalM3u(f);
        final cached = await RewampDb.probeLocalM3u(f, cache: cache);
        expect(cached, isNotNull, reason: n);
        expect(
            [for (final s in cached!) (s.filePath, s.subsongIdx, s.title, s.durationMs)],
            [for (final s in plain!) (s.filePath, s.subsongIdx, s.title, s.durationMs)],
            reason: n);
      }
      expect(cache.m3usByDir.keys, [dir.path]);
      expect(cache.entryCount.length, 2);
      expect(cache.subs.keys.map(p.basename), ['long.m3u']);
    });

    test('pas de M3U: null avec et sans mémoire', () async {
      final f = p.join(dir.path, 'x.mid');
      File(f).writeAsBytesSync(const [0]);
      final cache = M3uLookupCache();
      expect(await RewampDb.probeLocalM3u(f), isNull);
      expect(await RewampDb.probeLocalM3u(f, cache: cache), isNull);
      expect(cache.m3usByDir[dir.path], isEmpty);
    });
  });
}
