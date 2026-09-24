// La réécriture des porteurs de chemin, exécutée contre un vrai SQLite.
//
// ⚠️ Le test appelle le CODE, pas une copie de sa requête: une faute de SQL
// est invisible à l'analyzer (payé le même jour avec `album_id != ""`, que
// SQLite lit comme un IDENTIFIANT), et recopier la requête ici n'aurait testé
// que la copie.
//
// Quatre porteurs doivent bouger ensemble — en oublier un laisse une identité
// morte, la classe de bug de library_identity.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const root = '/sup/local';
  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE tracks (id INTEGER PRIMARY KEY, '
        'file_path TEXT, local_rel_path TEXT, ext_key TEXT)');
    await db.execute('CREATE TABLE playlist_tracks (id INTEGER PRIMARY KEY, '
        'file_path TEXT, rel_path TEXT)');
    await db.execute('CREATE TABLE recent_albums ('
        'album_key TEXT PRIMARY KEY, file_path TEXT)');
    await db.execute('CREATE TABLE library_items (id TEXT PRIMARY KEY, '
        'type TEXT, ref_id TEXT)');
  });
  tearDown(() => db.close());

  Future<void> move(String from, String to, {required bool dir}) =>
      LocalDb.rewriteLocalPaths(db,
          from: from, to: to, importsRoot: root, isDirectory: dir);

  Future<List<String?>> col(String table, String c) async =>
      [for (final r in await db.query(table, orderBy: 'rowid')) r[c] as String?];

  test('renommer un FICHIER bouge les quatre porteurs', () async {
    await db.insert('tracks', {
      'file_path': '$root/Jeux/a.mid', 'local_rel_path': 'Jeux/a.mid',
      'ext_key': 'local:abc',
    });
    await db.insert('playlist_tracks',
        {'file_path': '$root/Jeux/a.mid', 'rel_path': 'Jeux/a.mid'});
    await db.insert('recent_albums',
        {'album_key': 'k', 'file_path': '$root/Jeux/a.mid'});
    await db.insert('library_items',
        {'id': '1', 'type': 'track', 'ref_id': '$root/Jeux/a.mid'});

    await move('$root/Jeux/a.mid', '$root/Jeux/b.mid', dir: false);

    expect(await col('tracks', 'file_path'), ['$root/Jeux/b.mid']);
    expect(await col('tracks', 'local_rel_path'), ['Jeux/b.mid']);
    expect(await col('playlist_tracks', 'file_path'), ['$root/Jeux/b.mid']);
    expect(await col('playlist_tracks', 'rel_path'), ['Jeux/b.mid']);
    expect(await col('recent_albums', 'file_path'), ['$root/Jeux/b.mid']);
    expect(await col('library_items', 'ref_id'), ['$root/Jeux/b.mid']);
  });

  test('l\'identité de COMPTE (ext_key) ne bouge PAS', () async {
    // C'est le ♥ et les écoutes de ce fichier sur le compte, frappés une fois.
    // La recalculer ferait repartir de zéro ce que l'utilisateur a accumulé.
    await db.insert('tracks', {
      'file_path': '$root/a.mid', 'local_rel_path': 'a.mid',
      'ext_key': 'local:abc',
    });
    await move('$root/a.mid', '$root/b.mid', dir: false);
    expect(await col('tracks', 'ext_key'), ['local:abc']);
  });

  test('déplacer un DOSSIER emmène tout son sous-arbre', () async {
    await db.insert('tracks', {
      'file_path': '$root/Jeux/MT-32/a.mid',
      'local_rel_path': 'Jeux/MT-32/a.mid',
    });
    await db.insert('tracks', {
      'file_path': '$root/Jeux/MT-32/sous/b.mid',
      'local_rel_path': 'Jeux/MT-32/sous/b.mid',
    });
    await move('$root/Jeux/MT-32', '$root/Archives/MT-32', dir: true);

    expect(await col('tracks', 'file_path'), [
      '$root/Archives/MT-32/a.mid',
      '$root/Archives/MT-32/sous/b.mid',
    ]);
    expect(await col('tracks', 'local_rel_path'), [
      'Archives/MT-32/a.mid',
      'Archives/MT-32/sous/b.mid',
    ]);
  });

  test('un préfixe de NOM n\'est pas un préfixe de CHEMIN', () async {
    // Déplacer « Jeux » ne doit pas emporter « Jeux2 »: la comparaison porte
    // sur « Jeux/ », séparateur compris.
    await db.insert('tracks',
        {'file_path': '$root/Jeux/a.mid', 'local_rel_path': 'Jeux/a.mid'});
    await db.insert('tracks',
        {'file_path': '$root/Jeux2/b.mid', 'local_rel_path': 'Jeux2/b.mid'});
    await move('$root/Jeux', '$root/Rangé', dir: true);

    expect(await col('tracks', 'file_path'),
        ['$root/Rangé/a.mid', '$root/Jeux2/b.mid']);
  });

  test('le suffixe ?subsong=N d\'une clé de bibliothèque est CONSERVÉ', () async {
    await db.insert('library_items',
        {'id': '1', 'type': 'track', 'ref_id': '$root/a.sid?subsong=3'});
    await move('$root/a.sid', '$root/b.sid', dir: false);
    expect(await col('library_items', 'ref_id'), ['$root/b.sid?subsong=3']);
  });

  test('un `_` dans un nom de dossier n\'est pas un joker LIKE', () async {
    // `_` vaut « un caractère quelconque » en SQL: sans échappement, déplacer
    // « a_b » emportait aussi « axb ».
    await db.insert('tracks',
        {'file_path': '$root/a_b/x.mid', 'local_rel_path': 'a_b/x.mid'});
    await db.insert('tracks',
        {'file_path': '$root/axb/y.mid', 'local_rel_path': 'axb/y.mid'});
    await move('$root/a_b', '$root/rangé', dir: true);

    expect(await col('tracks', 'file_path'),
        ['$root/rangé/x.mid', '$root/axb/y.mid']);
  });

  test('ce qui n\'est pas concerné ne bouge pas', () async {
    await db.insert('tracks', {
      'file_path': '/sup/online/jw/x.vgz', 'local_rel_path': null,
    });
    await move('$root/a.mid', '$root/b.mid', dir: false);
    expect(await col('tracks', 'file_path'), ['/sup/online/jw/x.vgz']);
  });

  // ── Déplacer une RACINE entière (Documents/Rewamp, 2026-09-21) ────────────
  //
  // Ce n'est pas le cas pour lequel la fonction a été écrite: elle déplace un
  // fichier ou un dossier À L'INTÉRIEUR des imports, et les chemins RELATIFS à
  // la racine bougent alors avec lui. Quand c'est la RACINE qui bouge, les
  // relatifs sont au contraire INVARIANTS — c'est ce qu'ils veulent dire.

  test('déplacer la RACINE des imports laisse les relatifs INTACTS', () async {
    const newRoot = '/home/u/Documents/Rewamp/local';
    await db.insert('tracks', {
      'file_path': '$root/Jeux/a.mid', 'local_rel_path': 'Jeux/a.mid',
    });
    await db.insert('playlist_tracks',
        {'file_path': '$root/Jeux/a.mid', 'rel_path': 'Jeux/a.mid'});
    await db.insert('library_items',
        {'id': '1', 'type': 'track', 'ref_id': '$root/Jeux/a.mid?subsong=2'});

    await LocalDb.rewriteLocalPaths(db,
        from: root, to: newRoot, importsRoot: root, isDirectory: true,
        rewriteRelative: false);

    expect(await col('tracks', 'file_path'), ['$newRoot/Jeux/a.mid']);
    expect(await col('tracks', 'local_rel_path'), ['Jeux/a.mid']);
    expect(await col('playlist_tracks', 'file_path'), ['$newRoot/Jeux/a.mid']);
    expect(await col('playlist_tracks', 'rel_path'), ['Jeux/a.mid']);
    expect(await col('library_items', 'ref_id'),
        ['$newRoot/Jeux/a.mid?subsong=2']);
  });

  test('déplacer la racine des TÉLÉCHARGEMENTS réécrit leurs chemins', () async {
    // Un téléchargement n'a pas de relatif (il n'est pas un import): seul le
    // chemin absolu porte l'identité, et il doit suivre.
    const oldOnline = '/home/u/Documents/online';
    const newOnline = '/home/u/Documents/Rewamp/online';
    await db.insert('tracks', {
      'file_path': '$oldOnline/jw_psf/uuid/a.ogg', 'local_rel_path': null,
    });
    await db.insert('recent_albums',
        {'album_key': 'k', 'file_path': '$oldOnline/jw_psf/uuid/a.ogg'});

    await LocalDb.rewriteLocalPaths(db,
        from: oldOnline, to: newOnline, importsRoot: root, isDirectory: true,
        rewriteRelative: false);

    expect(await col('tracks', 'file_path'),
        ['$newOnline/jw_psf/uuid/a.ogg']);
    expect(await col('tracks', 'local_rel_path'), [null]);
    expect(await col('recent_albums', 'file_path'),
        ['$newOnline/jw_psf/uuid/a.ogg']);
  });

  test('un chemin qui COMMENCE comme la racine sans en être n\'est pas pris',
      () async {
    // `/home/u/Documents/online2/…` commence par `/home/u/Documents/online`:
    // la comparaison se fait sur « racine + séparateur », pas sur le préfixe.
    const oldOnline = '/home/u/Documents/online';
    await db.insert('tracks', {'file_path': '/home/u/Documents/online2/x.ogg'});
    await LocalDb.rewriteLocalPaths(db,
        from: oldOnline, to: '/home/u/Documents/Rewamp/online',
        importsRoot: root, isDirectory: true, rewriteRelative: false);
    expect(await col('tracks', 'file_path'), ['/home/u/Documents/online2/x.ogg']);
  });
}
