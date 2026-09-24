import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/rewamp_db.dart';

/// Le SOUS-DOSSIER d'un fichier compagnon fait partie de son identité.
///
/// Aplatir au basename marche pour les compagnons FRÈRES (TFMX `mdat.X` /
/// `smpl.X`, le `.pdx` de mdxplay) mais casse les formats dont le player
/// cherche ses échantillons dans un RÉPERTOIRE. SMUS (Sonix Music Driver) en
/// est le cas: modland livre ses instruments sous `Instruments/…`, et UADE
/// résout le volume Amiga `Instruments:` en `<dossier du module>/instruments/`
/// (`ossupport.c`). Aplatis à côté du `.smus`, ils sont introuvables.
void main() {
  String sep(String s) => s.replaceAll('/', p.separator);

  test('un compagnon SMUS garde son dossier « Instruments »', () {
    expect(RewampDb.auxRelativePath('Instruments/Bello.instr'),
        sep('Instruments/Bello.instr'));
    expect(RewampDb.auxRelativePath('Instruments/BflatClariGliss.ss'),
        sep('Instruments/BflatClariGliss.ss'));
  });

  test('un compagnon FRÈRE reste à plat', () {
    // Le cas historique — il ne doit rien changer.
    expect(RewampDb.auxRelativePath('smpl.turrican'), 'smpl.turrican');
  });

  test('la traversée est refusée composant par composant', () {
    // ⚠️ La garde n'est plus « c'est un basename »: il faut jeter `..` et le
    // préfixe absolu SANS jeter le sous-dossier légitime.
    expect(RewampDb.auxRelativePath('../../etc/passwd'), sep('etc/passwd'));
    expect(RewampDb.auxRelativePath('/etc/passwd'), sep('etc/passwd'));
    expect(RewampDb.auxRelativePath('Instruments/../../x'), sep('Instruments/x'));
    expect(RewampDb.auxRelativePath('..'), '');
    expect(RewampDb.auxRelativePath('/'), '');
    expect(RewampDb.auxRelativePath(''), '');
  });

  test('les séparateurs Windows comptent aussi', () {
    expect(RewampDb.auxRelativePath(r'Instruments\Bello.instr'),
        sep('Instruments/Bello.instr'));
    expect(RewampDb.auxRelativePath(r'..\..\x'), 'x');
  });

  test('un composant qui ne laisse rien après assainissement est sauté', () {
    // « : » et « ? » deviennent « _ », donc le composant survit; c'est un
    // composant VIDE ou purement « . » qui disparaît.
    expect(RewampDb.auxRelativePath('Instruments//Bello.ss'),
        sep('Instruments/Bello.ss'));
    expect(RewampDb.auxRelativePath('./Bello.ss'), 'Bello.ss');
  });

  test('le chemin rendu reste SOUS le dossier du module', () async {
    final d = await Directory.systemTemp.createTemp('aux');
    for (final hostile in [
      '../../etc/passwd', '/etc/passwd', 'Instruments/../../x', r'..\..\y',
    ]) {
      final rel = RewampDb.auxRelativePath(hostile);
      if (rel.isEmpty) continue;
      final full = p.normalize(p.join(d.path, rel));
      expect(p.isWithin(d.path, full), isTrue,
          reason: '$hostile → $rel sort du dossier');
    }
  });
}
