// La règle « quel compagnon appartient à quelle piste » de la suppression
// d'imports locaux — c'est elle qui protège un compagnon PARTAGÉ (deux pistes
// de même radical, la banque d'un mdat.*) d'une suppression collatérale.

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_import.dart';

void main() {
  test('même radical: X.jpg appartient à X.mid', () {
    expect(localImportCompanionClaims('Doom2-Stage01.mid', 'Doom2-Stage01.jpg'),
        isTrue);
  });

  test('nom complet (forme artBasenameFor): X.mid.jpg appartient à X.mid', () {
    expect(
        localImportCompanionClaims('Doom2-Stage01.mid', 'Doom2-Stage01.mid.jpg'),
        isTrue);
  });

  test('forme préfixe Amiga: smpl.Y appartient à mdat.Y', () {
    expect(localImportCompanionClaims('mdat.monkey island', 'smpl.monkey island'),
        isTrue);
  });

  test("un compagnon d'un AUTRE radical n'est pas revendiqué", () {
    expect(localImportCompanionClaims('Doom2-Stage01.mid', 'Doom2-Stage02.jpg'),
        isFalse);
    expect(localImportCompanionClaims('mdat.monkey island', 'smpl.autre jeu'),
        isFalse);
  });

  test('partage: X.vgz revendique aussi X.jpg (le supprimer avec X.mid serait '
      'une perte)', () {
    expect(localImportCompanionClaims('Doom2-Stage01.vgz', 'Doom2-Stage01.jpg'),
        isTrue);
  });

  test("la pochette d'une ARCHIVE porte le nom de l'archive", () {
    // Le cas réel: JEU.zip + JEU.png posés côte à côte. L'image doit suivre
    // l'archive DANS son dossier d'extraction, sinon la découverte locale ne
    // la voit jamais (deux dossiers différents).
    const zip = 'Super Mario Land (GB)(1989-04-21)(Nintendo RD1)(Nintendo).zip';
    const png = 'Super Mario Land (GB)(1989-04-21)(Nintendo RD1)(Nintendo).png';
    expect(localImportCompanionClaims(zip, png), isTrue);
    expect(localImportCompanionClaims(zip, 'Autre Jeu (GB).png'), isFalse);
  });

  test('deux archives voisines ne se revendiquent pas (même extension ≠ '
      'compagnon)', () {
    // « Même partie après le premier point » est la règle des noms Amiga
    // (mdat.X / smpl.X). Sans garde, elle dit « même extension »: chaque .zip
    // d'un dossier réclamait tous les autres et se les faisait copier dans son
    // dossier d'extraction (constaté dans local/midimt32/cbmt/).
    expect(localImportCompanionClaims('cbmt.zip', 'kq5mt.zip'), isFalse);
    expect(localImportCompanionClaims('cbmt.zip', 'wc1midi.zip'), isFalse);
    expect(localImportCompanionClaims('a.mid', 'b.mid'), isFalse);
    // La forme Amiga, elle, tient toujours (couverte plus haut).
  });

  test('insensible à la casse', () {
    expect(localImportCompanionClaims('SONG.MOD', 'song.jpg'), isTrue);
  });
}
