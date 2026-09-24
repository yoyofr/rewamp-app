import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/formats.dart';
import 'package:rewamp/local_open.dart';
import 'package:rewamp/rewamp_db.dart';

/// Un dossier de compagnons ne contient pas de pistes — et rien dans le NOM de
/// ses fichiers ne le dit: `.ss` est SpeedySystem dans `eagleplayer.conf`,
/// donc parfaitement jouable ailleurs. Seul l'EMPLACEMENT tranche.
///
/// Sans cette règle, les 80 échantillons d'un album SMUS entrent dans la file,
/// chacun échoue, et la bannière « Format non supporté » se réaffiche sans fin
/// (elle ne « colle » pas: elle est REMPLACÉE à chaque échec, ce qui la rend
/// intappable). Pire au classement d'archive: un `.ss` de 31 Ko est du même
/// palier qu'un `.smus` de 6 Ko et le bat à la TAILLE.
void main() {
  test('un fichier dans Instruments/ est un compagnon', () {
    expect(isInCompanionDir('Instruments/Bello.ss'), isTrue);
    expect(isInCompanionDir('Album/Instruments/Bello.instr'), isTrue);
    expect(isInCompanionDir(r'Album\Instruments\Bello.ss'), isTrue);
  });

  test('la casse ne compte pas', () {
    // modland écrit « Instruments », UADE construit « instruments ».
    expect(isInCompanionDir('instruments/Bello.ss'), isTrue);
    expect(isInCompanionDir('INSTRUMENTS/Bello.ss'), isTrue);
  });

  test('un module à côté n\'est pas touché', () {
    expect(isInCompanionDir('001-096.smus'), isFalse);
    expect(isInCompanionDir('Album/001-096.smus'), isFalse);
  });

  test('un FICHIER nommé Instruments n\'est pas un dossier', () {
    // Seuls les composants INTERMÉDIAIRES comptent; le dernier est le fichier.
    expect(isInCompanionDir('Instruments'), isFalse);
    expect(isInCompanionDir('Album/Instruments'), isFalse);
  });

  test('un échantillon n\'entre pas dans une file en LOT', () {
    // `.ss` passerait le filtre d'extension sans la règle d'emplacement.
    expect(isBulkQueueCandidate('/x/Instruments/Bello.ss'), isFalse);
    expect(isBulkQueueCandidate('/x/001-096.smus'), isTrue);
  });

  test('le pick d\'archive préfère le module au gros échantillon', () async {
    // Le cas exact: un module de 6 Ko contre un échantillon de 31 Ko, tous
    // deux au palier 1. Sans le filtre, la taille DÉCROISSANTE sert le second.
    final d = await Directory.systemTemp.createTemp('smus');
    await File('${d.path}/001-096.smus').writeAsBytes(List.filled(6384, 1));
    await Directory('${d.path}/Instruments').create();
    await File('${d.path}/Instruments/BflatClariGliss.ss')
        .writeAsBytes(List.filled(31806, 2));
    final picked = await RewampDb.debugFindExtractedAudio(d.path);
    expect(picked, isNotNull);
    expect(picked!.endsWith('001-096.smus'), isTrue, reason: picked);
  });
}
