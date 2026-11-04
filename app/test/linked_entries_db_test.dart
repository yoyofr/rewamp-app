// La table des NOMS des dossiers liés (local_roots.dart): un niveau se
// calcule en SQL, « tout lire » suit l'ordre des chemins, la recherche classe
// nom exact > préfixe > contenu > chemin, et un `_` ou un `%` dans un nom est
// un caractère, pas un joker.
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_db.dart';
import 'package:rewamp/local_roots.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Database db;

  const root = 'r1';
  List<LinkedEntry> entries(List<String> paths) =>
      [for (final p in paths) LinkedEntry(root, p, size: 1)];

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(kLinkedEntriesSchema);
    await db.execute(kLinkedEntriesIndex);
    await LocalDb.replaceLinkedEntriesOn(db, root, entries([
      'Amiga/Chris Huelsbeck/mdat.turrican 2',
      'Amiga/Chris Huelsbeck/mdat.apidya',
      'Amiga/Jogeir/hvl/a.hvl',
      'C64/Rob Hubbard/Monty_on_the_Run.sid',
      'C64/Rob Hubbard/50%_off.sid',
      'readme.txt',
      'intro.mod',
    ]));
    await LocalDb.replaceLinkedEntriesOn(db, 'r2', [
      const LinkedEntry('r2', 'Other/Monty_on_the_Run.sid'),
    ]);
  });
  tearDown(() => db.close());

  test('la racine: ses dossiers avec leur compte, ses fichiers seuls',
      () async {
    final (folders, files) = await LocalDb.linkedEntriesUnderOn(db, root, '');
    expect(folders, {'Amiga': 3, 'C64': 2});
    expect(files.map((e) => e.name), ['intro.mod', 'readme.txt']);
  });

  test('un niveau intermédiaire', () async {
    final (folders, files) =
        await LocalDb.linkedEntriesUnderOn(db, root, 'Amiga/');
    expect(folders, {'Chris Huelsbeck': 2, 'Jogeir': 1});
    expect(files, isEmpty);
    final (f2, files2) =
        await LocalDb.linkedEntriesUnderOn(db, root, 'Amiga/Chris Huelsbeck/');
    expect(f2, isEmpty);
    expect(files2.map((e) => e.name), ['mdat.apidya', 'mdat.turrican 2']);
  });

  test('le sous-arbre, dans l\'ordre des chemins, borné à SA racine',
      () async {
    final all = await LocalDb.linkedSubtreeOn(db, root, 'C64/');
    expect(all.map((e) => e.relPath),
        ['C64/Rob Hubbard/50%_off.sid', 'C64/Rob Hubbard/Monty_on_the_Run.sid']);
    expect((await LocalDb.linkedSubtreeOn(db, root, '')).length, 7);
  });

  test('recherche: nom exact, puis préfixe, puis contenu, puis chemin',
      () async {
    final r = await LocalDb.searchLinkedEntriesOn(db, 'hubbard', rootId: root);
    // Aucun NOM ne contient « hubbard »: les deux viennent du CHEMIN.
    expect(r.map((e) => e.name).toSet(),
        {'Monty_on_the_Run.sid', '50%_off.sid'});
    final t = await LocalDb.searchLinkedEntriesOn(db, 'turrican', rootId: root);
    expect(t.single.relPath, 'Amiga/Chris Huelsbeck/mdat.turrican 2');
    final m = await LocalDb.searchLinkedEntriesOn(db, 'mdat', rootId: root);
    expect(m.map((e) => e.name), ['mdat.apidya', 'mdat.turrican 2']);
  });

  test('recherche sur TOUTES les racines, et sur une seule', () async {
    final all = await LocalDb.searchLinkedEntriesOn(db, 'monty');
    expect(all.map((e) => e.rootId).toSet(), {root, 'r2'});
    final one = await LocalDb.searchLinkedEntriesOn(db, 'monty', rootId: 'r2');
    expect(one.single.rootId, 'r2');
  });

  test('`%` et `_` dans la question sont des caractères, pas des jokers',
      () async {
    expect((await LocalDb.searchLinkedEntriesOn(db, '50%')).single.name,
        '50%_off.sid');
    expect(await LocalDb.searchLinkedEntriesOn(db, 'on_the'), hasLength(2));
    expect(await LocalDb.searchLinkedEntriesOn(db, 'onXthe'), isEmpty);
    expect(await LocalDb.searchLinkedEntriesOn(db, '   '), isEmpty);
  });

  test('un nouveau parcours REMPLACE la table de sa racine, et d\'elle seule',
      () async {
    await LocalDb.replaceLinkedEntriesOn(db, root, entries(['x.mod']));
    expect(await LocalDb.countLinkedEntriesOn(db, root), 1);
    expect(await LocalDb.countLinkedEntriesOn(db, 'r2'), 1);
  });
}
