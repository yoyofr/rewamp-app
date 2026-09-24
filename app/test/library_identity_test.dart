import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/library_identity.dart';
import 'package:rewamp/local_import.dart';

/// La garde d'identité: ce qu'une entrée de bibliothèque a le droit de nommer.
///
/// Ce qu'on protège ici, c'est la RÈGLE, pas l'UI: un chemin sous le cache
/// d'ouverture, un téléchargement, un dossier de l'utilisateur qui s'appelle
/// « local » — chacun a produit des entrées mortes, et chacun a un test.
void main() {
  const imports = '/sup/local';
  const downloads = '/docs/online';
  const archives = '/cache/local_archives';

  LibraryRefKind kindOf(String ref) => libraryRefKind(ref,
      imports: imports, downloads: downloads, archiveCache: archives);

  group('libraryRefKind', () {
    test('un uuid de catalogue est une identité, avec ou sans sous-chanson', () {
      const uuid = '1b4e28ba-2fa1-11d2-883f-0016d3cca427';
      expect(kindOf(uuid), LibraryRefKind.catalogue);
      expect(kindOf('$uuid?subsong=4'), LibraryRefKind.catalogue);
      expect(kindOf('$uuid#3?subsong=3'), LibraryRefKind.catalogue);
    });

    test('un import pérenne est la seule forme de CHEMIN légitime', () {
      expect(kindOf('$imports/Games/tune.sid?subsong=0'),
          LibraryRefKind.durableImport);
    });

    test('un téléchargement doit passer par son songId', () {
      expect(kindOf('$downloads/jw_spc/album/tune.spc?subsong=2'),
          LibraryRefKind.download);
    });

    test("le cache d'extraction d'une archive OUVERTE est jetable", () {
      expect(kindOf('$archives/rip_4096/mod.tune'), LibraryRefKind.ephemeral);
    });

    test('un chemin hors des racines connues est jetable', () {
      expect(kindOf('/sup/opened/tune.mod'), LibraryRefKind.ephemeral);
      expect(kindOf('/Users/moi/Musique/tune.mod'), LibraryRefKind.ephemeral);
    });

    // Le dossier « local » de l'utilisateur n'est pas le NÔTRE: c'est ce que la
    // comparaison de PRÉFIXE gagne sur une recherche de sous-chaîne.
    test("un dossier nommé « local » ailleurs n'est pas un import", () {
      expect(kindOf('/Users/moi/local/tune.mod'), LibraryRefKind.ephemeral);
    });

    test('racines inconnues: on retombe sur les segments de chemin', () {
      LibraryRoots.reset();
      expect(libraryRefKind('/x/local/tune.mod'), LibraryRefKind.durableImport);
      expect(libraryRefKind('/x/online/a/tune.spc'), LibraryRefKind.download);
      expect(libraryRefKind('/x/local_archives/k/tune.mod'),
          LibraryRefKind.ephemeral);
    });
  });

  // LE contrat multi-appareils. Ce nettoyage purge AUSSI le compte, donc tout
  // faux positif ici ampute les AUTRES appareils.
  group('libraryRefIsDeadIdentity', () {
    setUp(() {
      LibraryRoots.reset();
      LibraryRoots.imports = imports;
      LibraryRoots.importsAlt = '/docs/local';
      LibraryRoots.downloads = downloads;
      LibraryRoots.archiveCache = archives;
    });
    tearDown(LibraryRoots.reset);

    test('un import ABSENT d’ici n’est pas mort: il vit sur un autre appareil',
        () {
      // Le fichier n'a jamais été copié sur CET appareil — le pull a posé une
      // ligne « à l'endroit où il irait ». La purger retirerait du COMPTE
      // l'import de l'appareil qui le possède.
      expect(libraryRefIsDeadIdentity('$imports/jamais copié.sid?subsong=0'),
          isFalse);
      // Même chose sous la racine MIROIR, celle que expectedPathFor fabrique
      // quand le fichier n'existe sous aucune des deux.
      expect(libraryRefIsDeadIdentity('/docs/local/jamais copié.sid?subsong=0'),
          isFalse);
    });

    test('un téléchargement identifié par son CHEMIN est mort', () {
      expect(
          libraryRefIsDeadIdentity('$downloads/jw_spc/a/tune.spc?subsong=0'),
          isTrue);
    });

    test('un cache d’ouverture est mort, fichier présent ou non', () {
      expect(libraryRefIsDeadIdentity('$archives/rip_4096/mod.tune'), isTrue);
    });

    test('un chemin hors de nos racines est mort', () {
      expect(libraryRefIsDeadIdentity('/Users/moi/Musique/tune.mod'), isTrue);
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
      final d = await resolveLibraryRefForAdd('$imports/parti.mod?subsong=0');
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

  group('movedImportPath', () {
    test('fichier importé seul: la destination est celle de la source', () {
      final res = LocalImportResult()
        ..destinations['/sup/opened/a.mod'] = '$imports/a.mod';
      expect(
          movedImportPath(res,
              path: '/sup/opened/a.mod', source: '/sup/opened/a.mod'),
          '$imports/a.mod');
    });

    // L'archive est importée ENTIÈRE (ses compagnons sont ses voisins): le
    // membre se retrouve au même chemin RELATIF dans le dossier d'extraction.
    test("membre d'archive: même chemin relatif sous le dossier importé", () {
      final res = LocalImportResult()
        ..destinations['/sup/opened/rip.lha'] = '$imports/rip';
      expect(
          movedImportPath(res,
              path: '$archives/rip_4096/sous/mod.tune',
              source: '/sup/opened/rip.lha'),
          '$imports/rip/sous/mod.tune');
    });

    test('import sans destination: rien à écrire', () {
      expect(
          movedImportPath(LocalImportResult(),
              path: '/sup/opened/a.mod', source: '/sup/opened/a.mod'),
          isNull);
    });
  });
}
