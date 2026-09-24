import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

/// `search_artists.total_count` n'est parfois qu'un PLANCHER: le serveur borne
/// son décompte sur les recherches très larges et le DIT (colonne `truncated`,
/// migration 247) au lieu de rendre un nombre qui a l'air exact. Une seule
/// conséquence côté client: écrire « 4403+ ».
///
/// Le correctif serveur qui l'accompagne vaut d'être noté: ce n'était pas la
/// page 1 (stable) mais la pagination PROFONDE — offset 1000 rendait quatre
/// pages différentes en quatre appels, et `total_count` oscillait entre 3246 et
/// 3743 pour le MÊME appel. C'est ce que voyaient les rapports « le nombre de
/// résultats change » et « en scrollant je perds des artistes ».
void main() {
  Map<String, dynamic> row({Object? truncated}) => {
        'artist_id': 'a1',
        'name': 'Rob Hubbard',
        'total_count': 4403,
        if (truncated != null) 'truncated': truncated,
      };

  test('truncated true ⇒ le total est un plancher', () {
    final a = ArtistResult.fromJson(row(truncated: true));
    expect(a.totalCount, 4403);
    expect(a.totalTruncated, isTrue);
  });

  test('truncated false ⇒ total exact', () {
    expect(ArtistResult.fromJson(row(truncated: false)).totalTruncated, isFalse);
  });

  test('colonne ABSENTE (serveur antérieur à la 247) ⇒ total exact', () {
    // Le repli doit être le comportement d'avant: un total non borné. Lire
    // `null` comme « tronqué » collerait un « + » à tous les résultats.
    expect(ArtistResult.fromJson(row()).totalTruncated, isFalse);
  });

  test('une valeur non booléenne ne passe pas pour vraie', () {
    // PostgREST peut rendre une chaîne; `== true` est volontairement strict.
    expect(ArtistResult.fromJson(row(truncated: 'true')).totalTruncated, isFalse);
    expect(ArtistResult.fromJson(row(truncated: 1)).totalTruncated, isFalse);
  });
}
