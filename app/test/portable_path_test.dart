// Un chemin RELATIF voyage en '/' (portable_path.dart). Ces tests passent sous
// les DEUX styles de chemin sur n'importe quelle machine (p.windows / p.posix):
// la CI Linux exerce la logique Windows, et réciproquement.
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/portable_path.dart';
import 'package:rewamp/sync_service.dart';

void main() {
  group('relatif portable', () {
    test('Windows: p.relative natif devient portable', () {
      expect(
          portableRelative(r'C:\Users\u\AppData\rewamp\local\Jeux\a.mid',
              from: r'C:\Users\u\AppData\rewamp', ctx: p.windows),
          'local/Jeux/a.mid');
    });

    test('POSIX: un \\ est un caractère de NOM, jamais un séparateur', () {
      // Un fichier qui s'appelle vraiment « a\b.mid » sous Linux ou macOS.
      expect(toPortableRel(r'local/a\b.mid', ctx: p.posix), r'local/a\b.mid');
      expect(
          portableRelative('/sup/local/Jeux/a.mid',
              from: '/sup', ctx: p.posix),
          'local/Jeux/a.mid');
    });

    test('retour vers le natif: jamais de chemin MÉLANGÉ', () {
      expect(joinPortable(r'C:\base', 'local/Jeux/a.mid', ctx: p.windows),
          r'C:\base\local\Jeux\a.mid');
      expect(joinPortable('/base', 'local/Jeux/a.mid', ctx: p.posix),
          '/base/local/Jeux/a.mid');
      expect(joinPortable(r'C:\base', '', ctx: p.windows), r'C:\base');
    });

    test('aller-retour Windows: natif → portable → natif', () {
      const root = r'C:\Users\u\Documents\Rewamp';
      const abs = r'C:\Users\u\Documents\Rewamp\local\rip\sous\mod.tune';
      final rel = portableRelative(abs, from: root, ctx: p.windows);
      expect(rel, 'local/rip/sous/mod.tune');
      expect(joinPortable(root, rel, ctx: p.windows), abs);
    });
  });

  group('clé de compte d\'un fichier importé (ext_key)', () {
    // ⚠️ Le cœur de l'affaire: la MÊME clé sur un iPhone et sur un PC, sinon
    // le même fichier importé fait deux entrées de compte.
    test('un relatif Windows et le même relatif iPhone font la même clé', () {
      final iphone = SyncService.localLibraryKey(
          fileName: 'a.mid', relPath: 'local/Jeux/a.mid', keyContext: p.posix);
      final pc = SyncService.localLibraryKey(
          fileName: 'a.mid', relPath: r'local\Jeux\a.mid', keyContext: p.windows);
      expect(pc, iphone);
    });

    test('une clé existante (iPhone, Android, Mac, Linux) ne change PAS', () {
      // Valeur figée: la clé d'un relatif déjà en '/' est celle que le compte
      // tient aujourd'hui pour ces appareils.
      final before = SyncService.localLibraryKey(
          fileName: 'a.mid', relPath: 'local/Jeux/a.mid', keyContext: p.posix);
      final portable = SyncService.localLibraryKey(
          fileName: 'a.mid', relPath: 'local/Jeux/a.mid', keyContext: p.windows);
      expect(portable, before);
    });
  });
}
