import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/podium_filter.dart';
import 'package:rewamp/rewamp_db.dart' show CompoPodium, FacetCount;

/// Contrat p_podium (serveur): null = aucun filtre, 0 = tout podium, 1-3 = ce
/// rang (le MEILLEUR, celui du badge). Toute autre valeur = HTTP 400.
void main() {
  CompoPodium pod(int rank) => CompoPodium.fromJson({'rank': rank, 'via': 'self'})!;

  test('la valeur envoyée est bornée à 0-3, sinon rien', () {
    expect([for (final v in [null, -1, 0, 1, 2, 3, 4, 99]) podiumParam(v)],
        [null, null, 0, 1, 2, 3, null, null]);
  });

  test("une recherche récente à l'ancien format booléen vaut « tout podium »", () {
    expect(podiumFromStored(true), 0);
    expect(podiumFromStored(false), isNull);
    expect(podiumFromStored(2), 2);
    expect(podiumFromStored(7), isNull);
    expect(podiumFromStored('1'), isNull);
    expect(podiumFromStored(null), isNull);
  });

  test('correspondance par MEILLEUR rang', () {
    expect(podiumMatches(null, null), isTrue);
    expect(podiumMatches(null, 0), isFalse);
    expect(podiumMatches(pod(3), 0), isTrue);
    expect(podiumMatches(pod(1), 1), isTrue);
    expect(podiumMatches(pod(1), 3), isFalse, reason: '1er ailleurs: sort sous 1, pas sous 3');
  });

  test('facette: reclassée par rang, rang absent = 0, autres types ignorés', () {
    final rows = [
      const FacetCount(kind: 'podium', value: '3', count: 40),   // trié par compte
      const FacetCount(kind: 'podium', value: '1', count: 12),
      const FacetCount(kind: 'format', value: 'mod', count: 900),
    ];
    final c = podiumCounts(rows);
    expect(c, {1: 12, 2: 0, 3: 40});
    expect(podiumTotal(c), 52);
  });

  test('comptes sur une liste complète (albums d\'un artiste)', () {
    expect(podiumCountsOf([pod(1), null, pod(3), pod(1)]), {1: 2, 2: 0, 3: 1});
  });
}
