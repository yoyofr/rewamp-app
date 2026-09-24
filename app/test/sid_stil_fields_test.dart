import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

/// STIL a QUATRE champs de nommage et DEUX usages opposés:
///   NAME/AUTHOR   → le sous-chant       → titre et artiste de la piste
///   TITLE/ARTIST  → l'ŒUVRE REPRISE     → panneau ⓘ
/// Les confondre affichait « Magnetic Fields, Part 1 » de Jean-Michel Jarre à
/// la place de « Space Game », le vrai nom de la piste 1 de « One Man and His
/// Droid ». Le cas réel, tel que le RPC le rend depuis la migration 237.
SidInfo _oneManAndHisDroid() => SidInfo.fromJson({
      'md5': 'deadbeef',
      'subsong_count': 14,
      'subsongs': [
        {
          'idx': 1,
          'length_ms': 51000,
          'name': 'Space Game',
          'title': 'Magnetic Fields, Part 1 [from Magnetic Fields] (0:41-0:51)',
          'artist': 'Jean-Michel Jarre',
        },
        // Les treize autres sous-chants: STIL ne les nomme pas.
        {'idx': 2, 'length_ms': 12000},
      ],
    });

void main() {
  _multiCoverTests();
  test('le titre vient de NAME, pas de l\'œuvre reprise', () {
    final info = _oneManAndHisDroid();
    expect(info.nameFor(0), 'Space Game');
    expect(info.coverTitleFor(0),
        'Magnetic Fields, Part 1 [from Magnetic Fields] (0:41-0:51)');
    expect(info.coverArtistFor(0), 'Jean-Michel Jarre');
    // L'artiste de la PISTE n'est pas l'auteur de l'œuvre citée.
    expect(info.authorFor(0), isNull);
  });

  test('un sous-chant que STIL ne nomme pas rend null', () {
    // L'appelant garde alors le nom déjà calculé (« NOM (n) ») — il ne doit
    // surtout pas retomber sur l'œuvre reprise du voisin.
    final info = _oneManAndHisDroid();
    expect(info.perSubsongNameFor(1), isNull);
    expect(info.coverTitleFor(1), isNull);
  });

  test('AUTHOR est le compositeur du sous-chant', () {
    // Ultima V #8: STIL annonçait « Rule Britannia » alors que le morceau
    // s'appelle « The Missing Monarch ».
    final info = SidInfo.fromJson({
      'md5': 'x',
      'subsongs': [
        {
          'idx': 8,
          'name': 'The Missing Monarch',
          'author': 'Ken Arnold',
          'title': 'Rule Britannia',
          'artist': 'Thomas Arne',
        },
      ],
    });
    expect(info.nameFor(7), 'The Missing Monarch');
    expect(info.authorFor(7), 'Ken Arnold');
    expect(info.coverTitleFor(7), 'Rule Britannia');
    expect(info.subsongAt(7)!.hasCover, isTrue);
  });

  test('le bloc GLOBAL sert de repli, dans les deux familles', () {
    final info = SidInfo.fromJson({
      'md5': 'x',
      'stil_global': {'name': 'Nom global', 'author': 'Auteur global',
                      'title': 'Œuvre globale', 'artist': 'Auteur cité'},
      'subsongs': [
        {'idx': 1},
        {'idx': 2, 'name': 'Propre'},
      ],
    });
    expect(info.nameFor(0), 'Nom global');
    expect(info.authorFor(0), 'Auteur global');
    expect(info.nameFor(1), 'Propre');
    expect(info.coverTitleFor(0), 'Œuvre globale');
    // …mais le repli global n'a pas sa place dans une LISTE: répéter le même
    // nom sur chaque ligne n'apprend rien.
    expect(info.perSubsongNameFor(0), isNull);
  });

  test('un serveur antérieur (sans name/author) ne casse rien', () {
    final info = SidInfo.fromJson({
      'md5': 'x',
      'subsongs': [
        {'idx': 1, 'title': 'Commando', 'artist': 'Rob Hubbard'},
      ],
    });
    expect(info.nameFor(0), isNull);       // rien à afficher comme titre
    expect(info.coverTitleFor(0), 'Commando');
    expect(info.subsongAt(0)!.hasCover, isTrue);
  });
}

// ---------------------------------------------------------------------------
// Reprises MULTIPLES (migration serveur 238)
//
// L'unité qui se répète dans un bloc STIL n'est pas le CHAMP, c'est le GROUPE
// `TITLE` + `ARTIST` + `COMMENT`, horodaté dans le titre. La piste 1 du
// « Commando » de Rob Hubbard en cite SEPT; l'importateur n'en gardait qu'une,
// et c'était la DERNIÈRE — celle qui commence à 3:33, la moins utile.
// ---------------------------------------------------------------------------

SidInfo _commando() => SidInfo.fromJson({
      'md5': 'cafebabe',
      'subsong_count': 3,
      'subsongs': [
        {
          'idx': 1,
          // Le serveur garde title/artist sur le PREMIER groupe (238).
          'title': 'BGM1 [from the arcade game Commando] (0:00)',
          'artist': 'Tamayo Kawamoto',
          'covers': [
            {
              'title': 'BGM1 [from the arcade game Commando] (0:00)',
              'artist': 'Tamayo Kawamoto',
            },
            {
              'title': 'Base [from the arcade game Commando] (0:53)',
              'artist': 'Tamayo Kawamoto',
            },
            {
              'title':
                  'Level Complete [from the arcade game Commando] (1:16-1:32)',
              'artist': 'Tamayo Kawamoto',
            },
          ],
        },
      ],
    });

void _multiCoverTests() {
  test('les sept reprises reviennent toutes, dans l\'ordre du fichier', () {
    final covers = _commando().coversFor(0);
    expect(covers.length, 3);
    expect(covers.first.title, startsWith('BGM1'));
    expect(covers.last.title, startsWith('Level Complete'));
  });

  test('title/artist restent la PREMIÈRE reprise, pas la dernière', () {
    final info = _commando();
    // C'était le bug: on affichait « Base … (3:33-3:36) », le dernier groupe.
    expect(info.coverTitleFor(0), startsWith('BGM1'));
    expect(info.coverTitleFor(0), info.coversFor(0).first.title);
  });

  test('un serveur ANTÉRIEUR à la 238 ne rend pas de covers, title tient', () {
    final info = SidInfo.fromJson({
      'md5': 'x',
      'subsongs': [
        {'idx': 1, 'title': 'Commando, Tune #1', 'artist': 'Rob Hubbard'},
      ],
    });
    expect(info.coversFor(0), isEmpty);
    expect(info.coverTitleFor(0), 'Commando, Tune #1');
  });

  test('les reprises du bloc global servent de repli', () {
    final info = SidInfo.fromJson({
      'md5': 'x',
      'stil_global': {
        'covers': [
          {'title': 'Aura Lea (1:11-2:05)', 'artist': 'George R. Poulton'},
        ],
      },
      'subsongs': [
        {'idx': 1},
      ],
    });
    expect(info.coversFor(0).single.title, 'Aura Lea (1:11-2:05)');
  });

  test('un commentaire voyage avec SA reprise', () {
    final info = SidInfo.fromJson({
      'md5': 'x',
      'subsongs': [
        {
          'idx': 1,
          'covers': [
            {
              'title': 'Plynie Wisla, plynie (0:44-1:06)',
              'comment': 'Polish patriotic song.',
            },
            {
              'title': 'Aura Lea (1:11-2:05)',
              'comment': 'Covers the version "Love Me Tender" by Elvis Presley.',
            },
          ],
        },
      ],
    });
    final covers = info.coversFor(0);
    expect(covers[0].comment, 'Polish patriotic song.');
    expect(covers[1].comment, contains('Love Me Tender'));
  });
}
