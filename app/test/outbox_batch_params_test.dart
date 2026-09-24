import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/sync_service.dart';

/// Un geste de l'outbox → un élément de `set_library_batch` (mig serveur 271).
/// Les règles sont celles de l'unitaire, et chacune a déjà été un bug:
/// un ♥ pur ne porte PAS `value` (un `false` retirerait l'entrée et le ♥ avec),
/// l'instantané `ext_ref` ne part que pour un AJOUT, et un `<uuid>#N` local
/// devient l'uuid nu + son `subsong_index` (un `#` dans une colonne uuid =
/// 22P02, qui bloquait toute l'outbox).
void main() {
  test('un ajout catalogue porte value et subsong_index', () {
    final p = SyncService.outboxRowParams({
      'id': 1, 'item_id': '0123456789ab-cdef-0123-4567-89abcdef0123',
      'item_type': 'song', 'value': 1, 'subsong_idx': 3,
    })!;
    expect(p['value'], isTrue);
    expect(p['subsong_index'], 3);
    expect(p.containsKey('favourite'), isFalse);
    expect(p.containsKey('ext_ref'), isFalse);
  });

  test('un ♥ pur ne porte pas value', () {
    final p = SyncService.outboxRowParams({
      'id': 2, 'item_id': 'abc', 'item_type': 'song', 'value': 0,
      'favourite': 1, 'subsong_idx': 0,
    })!;
    expect(p['favourite'], isTrue);
    expect(p.containsKey('value'), isFalse);
  });

  test('un favori hors catalogue: clé, et instantané seulement à l\'ajout', () {
    final add = SyncService.outboxRowParams({
      'id': 3, 'item_id': '', 'item_type': 'song', 'value': 1,
      'ext_key': 'local:abc', 'ext_ref': '{"file_name":"x.mod"}',
    })!;
    expect(add['ext_key'], 'local:abc');
    expect(add['ext_ref'], {'file_name': 'x.mod'});
    expect(add.containsKey('item_id'), isFalse);
    expect(add.containsKey('subsong_index'), isFalse);
    final remove = SyncService.outboxRowParams({
      'id': 4, 'item_id': '', 'item_type': 'song', 'value': 0,
      'ext_key': 'local:abc', 'ext_ref': '{"file_name":"x.mod"}',
    })!;
    expect(remove.containsKey('ext_ref'), isFalse);
  });

  test('une ligne sans item ni clé ne se livre à personne', () {
    expect(SyncService.outboxRowParams({'id': 5, 'item_id': '', 'value': 1}),
        isNull);
  });
}
