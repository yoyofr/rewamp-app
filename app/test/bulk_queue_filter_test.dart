import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_open.dart';

/// Ouvrir un dossier entier en « tout sélectionner » ne doit pas noyer la file
/// sous ce qui n'est pas de la musique. Ce qui compte ici n'est pas la liste
/// mais les trois familles qu'elle sépare.
void main() {
  test('musique: gardée', () {
    for (final f in ['a.mod', 'b.sid', 'c.minigsf', 'd.spc', 'e.vgz', 'f.xm']) {
      expect(isBulkQueueCandidate('/x/$f'), isTrue, reason: f);
    }
  });

  test('module Amiga en forme PRÉFIXE: gardé', () {
    // Le format est AVANT le point, le suffixe ne dit rien.
    expect(isBulkQueueCandidate('/x/mdat.monkey island'), isTrue);
  });

  test('banque d\'échantillons Amiga: écartée', () {
    // `smpl.NAME` accompagne `mdat.NAME`, il ne se joue pas seul.
    expect(isBulkQueueCandidate('/x/smpl.monkey island'), isFalse);
  });

  test('bibliothèques PSF: écartées bien qu\'EXTRACTIBLES', () {
    // Elles sont dans kExtractedAudioExts à raison — une archive doit les
    // extraire — mais elles n'ont pas de musique à elles.
    for (final f in ['g.psflib', 'h.gsflib', 'i.2sflib', 'j.ssflib',
                     'k.dsflib', 'l.snsflib', 'm.qsflib', 'n.ncsflib',
                     'o.usflib', 'p.psf2lib']) {
      expect(isBulkQueueCandidate('/x/$f'), isFalse, reason: f);
    }
  });

  test('pochettes, notes et fichiers cachés: écartés', () {
    for (final f in ['cover.png', 'front.jpg', 'readme.txt', 'file_id.diz',
                     '.DS_Store', 'notes.nfo']) {
      expect(isBulkQueueCandidate('/x/$f'), isFalse, reason: f);
    }
  });

  test('archives: gardées, elles se déplient ensuite', () {
    expect(isBulkQueueCandidate('/x/pack.zip'), isTrue);
  });

  // Le même filtre sert au DÉPÔT, où il s'applique même à un fichier UNIQUE
  // (tracksForLocalPaths(filterCandidates: true)): poser une pochette sur la
  // fenêtre n'est pas « ouvre ce fichier-ci ». Sans ça, un .jpg déposé seul
  // devenait une piste et faisait apparaître la feuille « Lire maintenant ».
  test('un dépôt d\'un seul fichier non jouable est écarté', () {
    for (final f in ['photo.jpg', 'smpl.turrican', 'notes.txt', 'sheet.pdf']) {
      expect(isBulkQueueCandidate('/x/$f'), isFalse, reason: f);
    }
  });

  // Une liste d'extensions ne peut pas tout trancher: certains formats se
  // reconnaissent à leur CONTENU et n'ont volontairement aucune extension
  // déclarée, parce qu'elle est trop générique. `monkey island 2 - intro.raw`
  // commence par « RAWADATA » et AdPlug le joue; `raw` désigne aussi du PCM
  // sans en-tête, donc ni le probe natif ni kExtractedAudioExts ne l'inscrivent.
  // D'où la seconde chance confiée au moteur (rewamp_can_play).
  group('seconde chance du moteur', () {
    bool yes(String _) => true;
    bool no(String _) => false;

    test('extension inconnue mais le moteur sait la lire: gardée', () {
      expect(isBulkQueueCandidate('/x/intro.raw', canPlay: yes), isTrue);
    });

    test('extension inconnue et le moteur ne sait pas: écartée', () {
      expect(isBulkQueueCandidate('/x/photo.jpg', canPlay: no), isFalse);
    });

    test('sans moteur, seule la liste décide', () {
      expect(isBulkQueueCandidate('/x/intro.raw'), isFalse);
      expect(isBulkQueueCandidate('/x/song.mod'), isTrue);
    });

    // Les règles NÉGATIVES sont absolues: le registre ACCEPTERAIT une
    // bibliothèque PSF (c'est un conteneur valide), mais elle n'a pas de
    // musique à elle et n'a rien à faire dans une file.
    test('une bibliothèque PSF reste écartée même si le moteur dit oui', () {
      expect(isBulkQueueCandidate('/x/game.gsflib', canPlay: yes), isFalse);
    });

    test('un fichier caché reste écarté même si le moteur dit oui', () {
      expect(isBulkQueueCandidate('/x/.hidden.mod', canPlay: yes), isFalse);
    });
  });

  test('le filtre repose sur la liste COMPLÈTE des formats du binaire', () {
    // kExtractedAudioExts = conteneurs + vgmstream + tous les décodeurs
    // (~1200 extensions), donc filtrer un dépôt n'écarte pas un format
    // exotique mais bien pris en charge.
    for (final f in ['x.gbs', 'x.nsfe', 'x.ttt', 'x.v2m', 'x.sndh', 'x.ptcop']) {
      expect(isBulkQueueCandidate('/x/$f'), isTrue, reason: f);
    }
  });
}
