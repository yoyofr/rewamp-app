// Dossiers liés (local_roots.dart): ce qui se décide sans disque ni canal —
// le modèle persisté, le relatif qui fait l'identité, ce qu'on indexe, et le
// classement d'un fichier lié comme PÉRENNE pour la bibliothèque.
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/library_identity.dart';
import 'package:rewamp/local_roots.dart';

void main() {
  test('une racine survit à un aller-retour JSON', () {
    final r = LocalRoot(
      id: 'root-1',
      kind: LocalRootKind.bookmark,
      label: 'Musique',
      path: '/Users/x/Music',
      bookmark: 'AAEC',
      addedAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    final back = LocalRoot.fromJson(r.toJson())!;
    expect(back.id, 'root-1');
    expect(back.kind, LocalRootKind.bookmark);
    expect(back.label, 'Musique');
    expect(back.path, '/Users/x/Music');
    expect(back.bookmark, 'AAEC');
    expect(back.addedAt.millisecondsSinceEpoch, 1000);
    // Un genre inconnu (build plus récent) retombe sur « dossier », une ligne
    // sans chemin est ignorée.
    expect(LocalRoot.fromJson({'id': 'a', 'path': '/p', 'kind': 'martian'})!.kind,
        LocalRootKind.folder);
    expect(LocalRoot.fromJson({'id': 'a'}), isNull);
  });

  test('on indexe ce que les moteurs jouent, préfixe Amiga compris', () {
    const exts = {'mod', 'sid', 'mdat', 'zip', 'm3u'};
    expect(isIndexedFileName('intro.MOD', exts: exts), isTrue);
    expect(isIndexedFileName('mdat.monkey island', exts: exts), isTrue);
    expect(isIndexedFileName('smpl.monkey island', exts: exts), isFalse);
    expect(isIndexedFileName('readme.txt', exts: exts), isFalse);
    expect(isIndexedFileName('noext', exts: exts), isFalse);
    expect(isIndexedFileName('.mod', exts: exts), isFalse);
    expect(isIndexedFileName('pack.zip', exts: exts), isTrue);
  });

  group('le relatif à la racine est l\'identité', () {
    for (final ctx in [p.posix, p.windows]) {
      final root = ctx.style == p.Style.windows ? r'D:\Musique' : '/mnt/music';
      final roots = LocalRoots.instance;
      test('(${ctx.style})', () {
        roots.debugSetRoots([
          LocalRoot(
              id: 'r', kind: LocalRootKind.folder, label: 'M', path: root,
              addedAt: DateTime.now()),
        ]);
        final inside = ctx.join(root, 'Amiga', 'mdat.turrican 2');
        final (r, rel) = roots.relPathOf(inside, ctx: ctx)!;
        expect(r.id, 'r');
        expect(rel, 'Amiga/mdat.turrican 2'); // PORTABLE, quel que soit l'OS
        // Un dossier VOISIN au nom proche n'est pas sous la racine.
        expect(roots.rootOf('${root}2${ctx.separator}x.mod', ctx: ctx), isNull);
        expect(roots.rootOf(root, ctx: ctx)?.id, 'r');
        roots.debugSetRoots(const []);
      });
    }
  });

  test('un fichier d\'un dossier lié est PÉRENNE pour la bibliothèque', () {
    for (final ctx in [p.posix, p.windows]) {
      final root = ctx.style == p.Style.windows ? r'D:\Musique' : '/mnt/music';
      final file = ctx.join(root, 'a.mod');
      expect(
          libraryRefKind(file,
              imports: ctx.join(ctx.rootPrefix(root), 'sup', 'local'),
              downloads: ctx.join(ctx.rootPrefix(root), 'dl', 'online'),
              archiveCache: ctx.join(ctx.rootPrefix(root), 'c', 'local_archives'),
              linkedRoots: [root],
              ctx: ctx),
          LibraryRefKind.durableImport,
          reason: ctx.style.toString());
      // Sans racine liée, le même chemin est jetable — c'était la règle.
      expect(
          libraryRefKind(file,
              imports: ctx.join(ctx.rootPrefix(root), 'sup', 'local'),
              downloads: ctx.join(ctx.rootPrefix(root), 'dl', 'online'),
              archiveCache: ctx.join(ctx.rootPrefix(root), 'c', 'local_archives'),
              linkedRoots: const [],
              ctx: ctx),
          LibraryRefKind.ephemeral);
    }
  });

  test('un espace réservé iCloud est indexé sous son VRAI nom', () {
    expect(icloudPlaceholderName('.intro.mod.icloud'), 'intro.mod');
    expect(icloudPlaceholderName('.mdat.turrican 2.icloud'), 'mdat.turrican 2');
    expect(icloudPlaceholderName('intro.mod'), isNull);
    expect(icloudPlaceholderName('.DS_Store'), isNull);
    expect(icloudPlaceholderName('..icloud'), isNull);
  });

  test('une racine qui CONTIENT les téléchargements (iOS: Documents) ne les '
      'fait pas passer pour des fichiers de l\'utilisateur', () {
    final c = p.posix;
    const docs = '/var/app/Documents';
    expect(
        libraryRefKind('$docs/online/modland/a.mod',
            imports: '/var/app/Library/local',
            downloads: '$docs/online',
            archiveCache: '/var/app/Caches/local_archives',
            linkedRoots: [docs],
            ctx: c),
        LibraryRefKind.download);
    expect(
        libraryRefKind('$docs/Mes mods/a.mod',
            imports: '/var/app/Library/local',
            downloads: '$docs/online',
            archiveCache: '/var/app/Caches/local_archives',
            linkedRoots: [docs],
            ctx: c),
        LibraryRefKind.durableImport);
  });

  group('mise en scène Android: quels voisins copier', () {
    List<SafSibling> sib(Map<String, int> m, {List<String> dirs = const []}) => [
          for (final e in m.entries) SafSibling(e.key, size: e.value),
          for (final d in dirs) SafSibling(d, isDir: true),
        ];
    const mb = 1024 * 1024;
    const exts = {'mdat', 'mdx', 'minipsf', 'psf', 'mod'};

    test('un dossier PETIT part en entier, sous-dossiers exclus', () {
      final out = stagingSetFor('mdat.x',
          sib({'mdat.x': 1000, 'smpl.x': 9000, 'readme.txt': 10},
              dirs: ['Other']),
          wholeDirBytes: 32 * mb);
      expect(out.toSet(), {'mdat.x', 'smpl.x', 'readme.txt'});
    });

    test('un dossier GROS: le fichier et ses compagnons nommés seulement', () {
      final big = <String, int>{
        'mdat.monkey island': 2 * mb,
        'smpl.monkey island': 3 * mb,
        'mdat.apidya': 2 * mb,
        'smpl.apidya': 3 * mb,
        'song.mdx': 1 * mb,
        'song.pdx': 4 * mb,
        'game.psflib': 8 * mb,
        'track01.minipsf': 1 * mb,
        'disc.m3u': 1,
        'huge.wav': 60 * mb,
      };
      expect(
          stagingSetFor('mdat.monkey island', sib(big), wholeDirBytes: 32 * mb, exts: exts)
              .toSet(),
          {'mdat.monkey island', 'smpl.monkey island', 'game.psflib', 'disc.m3u'});
      expect(stagingSetFor('song.mdx', sib(big), wholeDirBytes: 32 * mb, exts: exts).toSet(),
          {'song.mdx', 'song.pdx', 'game.psflib', 'disc.m3u'});
      expect(
          stagingSetFor('track01.minipsf', sib(big), wholeDirBytes: 32 * mb, exts: exts)
              .toSet(),
          {'track01.minipsf', 'game.psflib', 'disc.m3u'});
    });

    test('le fichier demandé est toujours dans le lot, même absent du listing',
        () {
      expect(stagingSetFor('a.mod', const [], wholeDirBytes: 1), ['a.mod']);
    });
  });
}

