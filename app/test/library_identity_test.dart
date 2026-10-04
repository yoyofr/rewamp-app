import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/library_identity.dart';
import 'package:rewamp/local_import.dart';

/// La garde d'identité: ce qu'une entrée de bibliothèque a le droit de nommer.
///
/// Ce qu'on protège ici, c'est la RÈGLE, pas l'UI: un chemin sous le cache
/// d'ouverture, un téléchargement, un dossier de l'utilisateur qui s'appelle
/// « local » — chacun a produit des entrées mortes, et chacun a un test.
///
/// Les règles de CHEMIN tournent sous les DEUX styles (p.posix et p.windows),
/// sur n'importe quelle machine: la CI Linux exerce Windows, et réciproquement.
/// Les fonctions qui suivent la plateforme (purge, ajout) sont testées avec
/// des racines construites dans le style de la plateforme courante.

/// Une racine fictive dans le style [c]: `/sup/local` ou `C:\sup\local`.
String _abs(p.Context c, List<String> parts) =>
    c.joinAll([c.style == p.Style.windows ? r'C:\' : '/', ...parts]);

void main() {
  for (final c in [p.posix, p.windows]) {
    final style = c.style == p.Style.windows ? 'Windows' : 'POSIX';
    final imports = _abs(c, ['sup', 'local']);
    final downloads = _abs(c, ['docs', 'online']);
    final archives = _abs(c, ['cache', 'local_archives']);
    String under(String root, List<String> parts) => c.joinAll([root, ...parts]);

    LibraryRefKind kindOf(String ref) => libraryRefKind(ref,
        imports: imports, downloads: downloads, archiveCache: archives, ctx: c);

    group('libraryRefKind ($style)', () {
      test('un uuid de catalogue est une identité, avec ou sans sous-chanson',
          () {
        const uuid = '1b4e28ba-2fa1-11d2-883f-0016d3cca427';
        expect(kindOf(uuid), LibraryRefKind.catalogue);
        expect(kindOf('$uuid?subsong=4'), LibraryRefKind.catalogue);
        expect(kindOf('$uuid#3?subsong=3'), LibraryRefKind.catalogue);
      });

      test('un import pérenne est la seule forme de CHEMIN légitime', () {
        expect(kindOf('${under(imports, ['Games', 'tune.sid'])}?subsong=0'),
            LibraryRefKind.durableImport);
      });

      test('un téléchargement doit passer par son songId', () {
        expect(
            kindOf('${under(downloads, ['jw_spc', 'album', 'tune.spc'])}'
                '?subsong=2'),
            LibraryRefKind.download);
      });

      test("le cache d'extraction d'une archive OUVERTE est jetable", () {
        expect(kindOf(under(archives, ['rip_4096', 'mod.tune'])),
            LibraryRefKind.ephemeral);
      });

      test('un chemin hors des racines connues est jetable', () {
        expect(kindOf(_abs(c, ['sup', 'opened', 'tune.mod'])),
            LibraryRefKind.ephemeral);
        expect(kindOf(_abs(c, ['Users', 'moi', 'Musique', 'tune.mod'])),
            LibraryRefKind.ephemeral);
      });

      // Le dossier « local » de l'utilisateur n'est pas le NÔTRE: c'est ce que
      // la comparaison de PRÉFIXE gagne sur une recherche de sous-chaîne.
      test("un dossier nommé « local » ailleurs n'est pas un import", () {
        expect(kindOf(_abs(c, ['Users', 'moi', 'local', 'tune.mod'])),
            LibraryRefKind.ephemeral);
      });

      // Préfixe de NOM ≠ préfixe de CHEMIN: `local2/` n'est pas sous `local/`.
      test("un dossier frère au nom prolongé n'est pas sous la racine", () {
        expect(kindOf(_abs(c, ['sup', 'local2', 'tune.mod'])),
            LibraryRefKind.ephemeral);
      });
    });

    group('movedImportPath ($style)', () {
      final opened = _abs(c, ['sup', 'opened']);
      test('fichier importé seul: la destination est celle de la source', () {
        final src = c.join(opened, 'a.mod');
        final res = LocalImportResult()
          ..destinations[src] = c.join(imports, 'a.mod');
        expect(movedImportPath(res, path: src, source: src, ctx: c),
            c.join(imports, 'a.mod'));
      });

      // L'archive est importée ENTIÈRE (ses compagnons sont ses voisins): le
      // membre se retrouve au même chemin RELATIF dans le dossier d'extraction.
      test("membre d'archive: même chemin relatif sous le dossier importé", () {
        final src = c.join(opened, 'rip.lha');
        final res = LocalImportResult()
          ..destinations[src] = c.join(imports, 'rip');
        expect(
            movedImportPath(res,
                path: under(archives, ['rip_4096', 'sous', 'mod.tune']),
                source: src,
                ctx: c),
            under(imports, ['rip', 'sous', 'mod.tune']));
      });

      test('import sans destination: rien à écrire', () {
        final src = c.join(opened, 'a.mod');
        expect(
            movedImportPath(LocalImportResult(),
                path: src, source: src, ctx: c),
            isNull);
      });
    });
  }

  // ⚠️ Le cas qui a motivé `isWithin`: avant portable_path.dart, l'app
  // fabriquait sous Windows des chemins MÉLANGÉS. Avec le test « préfixe +
  // séparateur NATIF », un tel import n'était sous aucune racine — classé
  // jetable, donc PURGÉ DU COMPTE par le nettoyage.
  test('Windows: un import au chemin MÉLANGÉ reste un import', () {
    expect(
        libraryRefKind(r'C:\Users\u\Rewamp\local/Jeux/a.mid?subsong=0',
            imports: r'C:\Users\u\Rewamp\local', ctx: p.windows),
        LibraryRefKind.durableImport);
  });

  // Les fonctions qui suivent la PLATEFORME: racines dans son style.
  final c = p.context;
  final imports = _abs(c, ['sup', 'local']);
  final importsAlt = _abs(c, ['docs', 'local']);
  final downloads = _abs(c, ['docs', 'online']);
  final archives = _abs(c, ['cache', 'local_archives']);

  test('racines inconnues: on retombe sur les segments de chemin', () {
    LibraryRoots.reset();
    expect(libraryRefKind(_abs(c, ['x', 'local', 'tune.mod'])),
        LibraryRefKind.durableImport);
    expect(libraryRefKind(_abs(c, ['x', 'online', 'a', 'tune.spc'])),
        LibraryRefKind.download);
    expect(libraryRefKind(_abs(c, ['x', 'local_archives', 'k', 'tune.mod'])),
        LibraryRefKind.ephemeral);
  });

  // LE contrat multi-appareils. Ce nettoyage purge AUSSI le compte, donc tout
  // faux positif ici ampute les AUTRES appareils.
  group('libraryRefIsDeadIdentity', () {
    setUp(() {
      LibraryRoots.reset();
      LibraryRoots.imports = imports;
      LibraryRoots.importsAlt = importsAlt;
      LibraryRoots.downloads = downloads;
      LibraryRoots.archiveCache = archives;
    });
    tearDown(LibraryRoots.reset);

    test('un import ABSENT d’ici n’est pas mort: il vit sur un autre appareil',
        () {
      // Le fichier n'a jamais été copié sur CET appareil — le pull a posé une
      // ligne « à l'endroit où il irait ». La purger retirerait du COMPTE
      // l'import de l'appareil qui le possède.
      expect(
          libraryRefIsDeadIdentity(
              '${c.join(imports, 'jamais copié.sid')}?subsong=0'),
          isFalse);
      // Même chose sous la racine MIROIR, celle que expectedPathFor fabrique
      // quand le fichier n'existe sous aucune des deux.
      expect(
          libraryRefIsDeadIdentity(
              '${c.join(importsAlt, 'jamais copié.sid')}?subsong=0'),
          isFalse);
    });

    test('un téléchargement identifié par son CHEMIN est mort', () {
      expect(
          libraryRefIsDeadIdentity(
              '${c.joinAll([downloads, 'jw_spc', 'a', 'tune.spc'])}?subsong=0'),
          isTrue);
    });

    test('un cache d’ouverture est mort, fichier présent ou non', () {
      expect(libraryRefIsDeadIdentity(c.joinAll([archives, 'rip_4096', 'mod.tune'])),
          isTrue);
    });

    test('un chemin hors de nos racines est mort', () {
      expect(
          libraryRefIsDeadIdentity(_abs(c, ['Users', 'moi', 'Musique', 'tune.mod'])),
          isTrue);
    });

    test('une entrée de CATALOGUE n’est jamais candidate', () {
      expect(
          libraryRefIsDeadIdentity(
              '1b4e28ba-2fa1-11d2-883f-0016d3cca427?subsong=2'),
          isFalse);
    });
  });

  group('refus', () {
    // Le motif décide du message: « identifiant inconnu » sur un fichier qu'on
    // vient de supprimer se lit comme un bug.
    test('un import dont le fichier a disparu est un refus « fichier absent »',
        () async {
      LibraryRoots.reset();
      LibraryRoots.imports = imports;
      final d = await resolveLibraryRefForAdd(
          '${c.join(imports, 'parti.mod')}?subsong=0');
      expect(d, isA<LibraryRefRefused>());
      expect((d as LibraryRefRefused).reason, LibraryRefRefusal.fileGone);
      LibraryRoots.reset();
    });
  });

  group('réécritures', () {
    setUp(clearLibraryRefRewrites);

    test('la clé réécrite est rendue aux DEUX bouts, écriture et lecture', () {
      recordLibraryRefRewrite('/tmp/a.mod?subsong=0', '$imports/a.mod?subsong=0');
      expect(libraryRefRewrite('/tmp/a.mod?subsong=0'),
          '$imports/a.mod?subsong=0');
      expect(libraryRefRewrite('/tmp/autre.mod?subsong=0'),
          '/tmp/autre.mod?subsong=0');
    });

    test('une chaîne de réécritures se suit', () {
      recordLibraryRefRewrite('a', 'b');
      recordLibraryRefRewrite('b', 'c');
      expect(libraryRefRewrite('a'), 'c');
    });

    // Le cas vécu: on ♥ un fichier ouvert, la garde propose l'import, la copie
    // devient la clé. Puis l'utilisateur supprime cet import — l'arbre efface
    // le FICHIER avec la ligne — et la réécriture désigne le vide. Sans
    // annulation, ré-ajouter le morceau qu'on écoute répondait « fichier
    // absent de cet appareil ».
    test('une réécriture morte s’annule et rend la clé d’origine', () {
      recordLibraryRefRewrite('/tmp/ouvert/x.mid?subsong=0',
          '$imports/x.mid?subsong=0');
      expect(forgetLibraryRefRewrite('$imports/x.mid?subsong=0'),
          '/tmp/ouvert/x.mid?subsong=0');
      // Les deux sens sont oubliés: la clé d'origine redevient elle-même.
      expect(libraryRefRewrite('/tmp/ouvert/x.mid?subsong=0'),
          '/tmp/ouvert/x.mid?subsong=0');
      // Et une clé qui n'a jamais été une cible ne rend rien.
      expect(forgetLibraryRefRewrite('$imports/jamais.mid?subsong=0'), isNull);
    });

    test('une réécriture sur elle-même ne boucle pas', () {
      recordLibraryRefRewrite('a', 'a');
      expect(libraryRefRewrite('a'), 'a');
    });
  });
}
