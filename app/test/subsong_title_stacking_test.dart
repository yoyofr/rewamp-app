// Le numéro « NOM (n) » d'une sous-chanson se dérive à la lecture — mais il se
// PERSISTE ensuite dans `tracks.title`, et la ligne d'un conteneur est celle de
// sa sous-chanson 0. Prendre ce titre comme base du numéro suivant empile les
// suffixes: mesuré sur la base réelle, « Commando (1) (1) (1) » (SID de Rob
// Hubbard), jusque dans le nom de l'entrée de bibliothèque.

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_db.dart';
import 'package:rewamp/rewamp_db.dart';
import 'package:rewamp/sync_service.dart';

SearchResult _row({required String title, required String filename}) =>
    SearchResult(
      songId: 'id', collection: 'hvsc', title: title, filename: filename,
      album: null, formatExt: 'sid', downloadUrl: null, fileSize: 0,
      year: null, artistNames: const [], totalCount: 0,
    );

void main() {
  group('base du numéro de sous-chanson', () {
    test('un titre déjà numéroté retombe sur le nom du FICHIER', () {
      expect(_row(title: 'Commando (1)', filename: 'Commando.sid')
          .subsongTitleBase, 'Commando');
      expect(_row(title: 'Commando (1) (1) (1)', filename: 'Commando.sid')
          .subsongTitleBase, 'Commando');
    });

    test('un titre propre est rendu tel quel', () {
      expect(_row(title: 'Commando', filename: 'Commando.sid')
          .subsongTitleBase, 'Commando');
    });

    test('un vrai titre finissant par un nombre entre parenthèses survit', () {
      // « Sonic (2) » n'est pas « sonic2 » + un numéro: on n'y touche pas.
      expect(_row(title: 'Sonic (2)', filename: 'sonic2.nsf')
          .subsongTitleBase, 'Sonic (2)');
    });

    test('la convention Amiga (format AVANT le point) n\'est pas amputée', () {
      // containerName rend le nom ENTIER ici (« monkey island » n'est pas une
      // extension plausible), donc rien à retirer.
      expect(_row(title: 'monkey island', filename: 'mdat.monkey island')
          .subsongTitleBase, 'monkey island');
    });
  });

  group('réparation des titres empilés (migration 71)', () {
    test('des groupes consécutifs IDENTIQUES se replient', () {
      expect(LocalDb.collapseRepeatedTitleSuffix('Commando (1) (1) (1)'),
          'Commando (1)');
    });

    test('des groupes DIFFÉRENTS ne sont pas touchés', () {
      // 24 lignes de la base réelle sont dans ce cas, une seule était fausse.
      for (final t in const [
        'Deja Vu (Vampire Killer) (Block-8)',
        '10b Pathetique (Beethoven) (Music Player)',
        'Cj Splinter, MmcM - Stellar one (2011) (DiHalt 2011, 1)',
      ]) {
        expect(LocalDb.collapseRepeatedTitleSuffix(t), isNull, reason: t);
      }
    });

    test('un titre sans répétition rend null', () {
      expect(LocalDb.collapseRepeatedTitleSuffix('Commando (1)'), isNull);
      expect(LocalDb.collapseRepeatedTitleSuffix('Commando'), isNull);
    });
  });

  group('nom d\'une entrée appliquée par le pull', () {
    test('un CONTENEUR prend le titre du CATALOGUE, jamais sa sous-chanson 0', () {
      expect(
        SyncService.libraryEntryName(
            containerEntry: true,
            localTitle: 'Commando (1)',
            catalogueTitle: 'Commando'),
        'Commando',
      );
    });

    test('sans titre catalogue, un CONTENEUR prend le nom de FICHIER', () {
      expect(
        SyncService.libraryEntryName(
            containerEntry: true,
            localTitle: 'Commando (1)',
            fileName: 'Commando.sid'),
        'Commando.sid',
      );
    });

    test('une PISTE garde la ligne LOCALE (piège « Wild Arms »)', () {
      expect(
        SyncService.libraryEntryName(
            containerEntry: false,
            localTitle: 'Into the Wilderness',
            catalogueTitle: 'Wild Arms'),
        'Into the Wilderness',
      );
    });

    test('rien de connu rend « ? »', () {
      expect(SyncService.libraryEntryName(containerEntry: true), '?');
      expect(SyncService.libraryEntryName(containerEntry: false), '?');
    });
  });
}

// ── Le NIVEAU du nom suit le NIVEAU de l'entrée ────────────────────────────
//
// Deux erreurs symétriques, toutes deux payées: une entrée de PISTE nommée par
// le catalogue prenait le nom du CONTENEUR (« Wild Arms »), et une entrée de
// CONTENEUR nommée par la ligne locale prenait le titre de sa SOUS-CHANSON 0
// (« Commando (1) », réécrit par le pull juste après le geste).
