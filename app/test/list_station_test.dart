import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/list_station.dart';
import 'package:rewamp/rewamp_db.dart';

/// Une portée de [size] morceaux, servie dans un ordre qui dépend de la
/// graine — comme `sort_by: random` + `seed` côté serveur.
class _FakeScope {
  final int size;
  final calls = <(String, int, int)>[];
  _FakeScope(this.size);

  Future<List<SearchResult>> page(String seed, int offset, int limit) async {
    calls.add((seed, offset, limit));
    final order = List.generate(size, (i) => i)
      ..sort((a, b) => '$seed-$a'.hashCode.compareTo('$seed-$b'.hashCode));
    return [
      for (final i in order.skip(offset).take(limit))
        SearchResult.fromJson(
            {'song_id': 'song-$i', 'title': 'T$i', 'filename': 't$i.mod',
             'collection': 'modland'}),
    ];
  }
}

void main() {
  test('les lots se suivent dans la portée sans se répéter, puis un nouveau '
      'tour repart sur une graine neuve', () async {
    final scope = _FakeScope(120);
    final st = RandomStation(scope.page);
    final seen = <String>{};
    for (var i = 0; i < 3; i++) {
      for (final r in await st.next()) {
        expect(seen.add(r.songId), isTrue, reason: 'doublon dans un tour');
      }
    }
    expect(seen.length, 120);                      // 50 + 50 + 20
    expect(scope.calls.map((c) => c.$2), [0, 50, 100]);
    expect(scope.calls.map((c) => c.$1).toSet().length, 1);

    final nextTour = await st.next();
    expect(nextTour, hasLength(50));
    expect(scope.calls.last.$2, 0);
    expect(scope.calls.last.$1, isNot(scope.calls.first.$1));
  });

  test('une portée plus petite qu\'un lot rejoue un tour à chaque lot',
      () async {
    final scope = _FakeScope(7);
    final st = RandomStation(scope.page);
    expect(await st.next(), hasLength(7));
    expect(await st.next(), hasLength(7));
    expect(scope.calls.map((c) => c.$2), [0, 0]);
  });

  test('une portée vide rend un lot vide, sans boucler', () async {
    final scope = _FakeScope(0);
    final st = RandomStation(scope.page);
    expect(await st.next(), isEmpty);
    expect(scope.calls, hasLength(1));
  });
}
