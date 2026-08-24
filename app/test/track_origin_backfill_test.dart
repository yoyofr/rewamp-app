// L'origine d'une piste est STOCKÉE, plus déduite (migration 52).
//
// `tracks` était un journal de lecture: il retenait ce qu'on avait joué, pas
// d'où ça venait. Une relance devait donc re-deviner la collection à partir du
// chemin — et quand la déduction ratait, le lecteur affichait « local » pour un
// album pourtant téléchargé. Les colonnes existent maintenant; ce test fige le
// rattrapage, qui lit la collection dans le chemin des téléchargements
// (`…/online/<collection>/…`) et ne doit rien inventer ailleurs.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _kBackfill = '''
  UPDATE tracks SET collection_slug =
    substr(file_path,
           instr(file_path, '/online/') + 8,
           instr(substr(file_path, instr(file_path, '/online/') + 8), '/') - 1)
   WHERE collection_slug IS NULL
     AND instr(file_path, '/online/') > 0
''';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE tracks (
      file_path TEXT PRIMARY KEY, collection_slug TEXT)''');
  });

  tearDown(() => db.close());

  Future<String?> slugOf(String path) async {
    final r = await db.rawQuery(
        'SELECT collection_slug FROM tracks WHERE file_path = ?', [path]);
    return r.single['collection_slug'] as String?;
  }

  test('la collection se lit dans le chemin des téléchargements', () async {
    const p = '/Users/me/Documents/online/jw_gbs/ce23-uuid/DMG-RWA.gbs';
    await db.insert('tracks', {'file_path': p});
    await db.execute(_kBackfill);
    expect(await slugOf(p), 'jw_gbs');
  });

  test('un fichier hors de l\'arbre des téléchargements reste sans origine',
      () async {
    const p = '/Users/me/Music/mon morceau.xm';
    await db.insert('tracks', {'file_path': p});
    await db.execute(_kBackfill);
    expect(await slugOf(p), isNull);
  });

  test('une origine déjà connue n\'est jamais écrasée', () async {
    // Le rattrapage ne comble que les trous: ce que le catalogue a écrit fait
    // foi sur ce que le chemin laisse deviner.
    const p = '/Users/me/Documents/online/sceneorg/x/song.mod';
    await db.insert('tracks', {'file_path': p, 'collection_slug': 'modland'});
    await db.execute(_kBackfill);
    expect(await slugOf(p), 'modland');
  });

  test('un sous-dossier profond ne rend que le premier segment', () async {
    const p = '/data/online/vgmrips/uuid/Disc 1/03 track.vgz';
    await db.insert('tracks', {'file_path': p});
    await db.execute(_kBackfill);
    expect(await slugOf(p), 'vgmrips');
  });
}
