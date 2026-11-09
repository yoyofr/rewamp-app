import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';
import 'package:rewamp/sync_service.dart';

/// Artistes au compte (mig serveur 296). Le ref_id local d'un artiste est son
/// UUID OU son NOM selon l'écran qui l'a enregistré: seul l'UUID a une
/// identité serveur, un nom reste local (homonymes) — et un geste d'artiste
/// part par la MÊME forme d'outbox qu'un album.
void main() {
  const id = '0123abcd-4567-89ab-cdef-0123456789ab';

  test('un UUID est une identité serveur, normalisée en minuscules', () {
    expect(artistServerIdOf(id), id);
    expect(artistServerIdOf(' ${id.toUpperCase()} '), id);
  });

  test('un NOM n\'en est pas une', () {
    expect(artistServerIdOf('Jeroen Tel'), isNull);
    expect(artistServerIdOf(''), isNull);
    expect(artistServerIdOf('$id#2'), isNull);
  });

  test('ajout d\'artiste: value, pas de ♥', () {
    final p = SyncService.outboxRowParams({
      'id': 1, 'item_id': id, 'item_type': 'artist', 'value': 1,
      'subsong_idx': 0,
    })!;
    expect(p['item_type'], 'artist');
    expect(p['item_id'], id);
    expect(p['value'], isTrue);
    expect(p.containsKey('favourite'), isFalse);
  });

  test('retrait de ♥ d\'artiste: favourite false SANS value', () {
    final p = SyncService.outboxRowParams({
      'id': 2, 'item_id': id, 'item_type': 'artist', 'value': 0,
      'favourite': 0, 'subsong_idx': 0,
    })!;
    expect(p['favourite'], isFalse);
    expect(p.containsKey('value'), isFalse);
  });

  test('user_artists se lit par nom de colonne', () {
    final a = UserLibraryArtist.fromJson({
      'artist_id': id, 'name': 'Jeroen Tel', 'artwork_url': null,
      'song_count': 12, 'in_library': true, 'favourite': true,
      'added_at': '2026-11-08T10:00:00Z', 'updated_at': '2026-11-08T11:00:00Z',
    });
    expect(a.artistId, id);
    expect(a.name, 'Jeroen Tel');
    expect(a.songCount, 12);
    expect(a.favourite, isTrue);
    expect(a.updatedAt, DateTime.utc(2026, 11, 8, 11));
    expect(UserLibraryArtist.fromJson({'artist_id': id, 'in_library': false})
        .inLibrary, isFalse);
  });
}
