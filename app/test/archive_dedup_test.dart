import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

void main() {
  // La clé de déduplication des archives. Si elle gardait le cache-buster,
  // deux descentes de la MÊME archive ne se reconnaîtraient pas et la
  // déduplication serait inerte — sans rien signaler.
  group('archiveKeyForUrl', () {
    test('une url sans query est sa propre clé', () {
      const u = 'https://x360.joshw.info/r/Remember%20Me.7z';
      expect(RewampDb.archiveKeyForUrl(u), u);
    });

    test('le cache-buster est retiré: les deux formes ont la MÊME clé', () {
      const u = 'https://x360.joshw.info/r/Remember%20Me.7z';
      final busted = RewampDb.cacheBusted(u);
      expect(busted, isNot(u));
      expect(RewampDb.archiveKeyForUrl(busted), u);
    });

    test('les autres paramètres survivent', () {
      const u = 'https://cdn.example/a.7z?token=abc';
      expect(RewampDb.archiveKeyForUrl('$u&rcb=123'), u);
      expect(RewampDb.archiveKeyForUrl(u), u);
    });

    test('le buster inséré en tête d\'une query existante', () {
      expect(
        RewampDb.archiveKeyForUrl('https://cdn.example/a.7z?rcb=9&token=abc'),
        'https://cdn.example/a.7z?token=abc',
      );
    });

    test('deux bustings successifs convergent sur la même clé', () {
      const u = 'https://cdn.example/a.7z';
      final a = RewampDb.cacheBusted(u);
      final b = RewampDb.cacheBusted(a);
      expect(RewampDb.archiveKeyForUrl(a), RewampDb.archiveKeyForUrl(b));
    });
  });
}
