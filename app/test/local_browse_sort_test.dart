import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/library_toolbar.dart' show LibrarySort;
import 'package:rewamp/local_browse_view.dart';

void main() {
  final items = [('track 10', 3), ('Track 2', 1), ('alpha', null), ('beta', 2)];
  List<String> sorted(LibrarySort s, bool asc) => sortLocalEntries(items,
          name: (e) => e.$1, mtime: (e) => e.$2, sort: s, ascending: asc)
      .map((e) => e.$1)
      .toList();

  test('par nom: sans casse, nombres dans l\'ordre naturel', () {
    expect(sorted(LibrarySort.name, true), ['alpha', 'beta', 'Track 2', 'track 10']);
    expect(sorted(LibrarySort.name, false), ['track 10', 'Track 2', 'beta', 'alpha']);
  });

  test('par date: date inconnue en FIN dans les deux sens', () {
    expect(sorted(LibrarySort.modified, true), ['Track 2', 'beta', 'track 10', 'alpha']);
    expect(sorted(LibrarySort.modified, false), ['track 10', 'beta', 'Track 2', 'alpha']);
  });

  test('par date: égalité départagée par le nom croissant', () {
    final r = sortLocalEntries([('b', 5), ('a', 5)],
        name: (e) => e.$1, mtime: (e) => e.$2,
        sort: LibrarySort.modified, ascending: false);
    expect(r.map((e) => e.$1), ['a', 'b']);
  });

  test('compareNatural', () {
    expect(compareNatural('a2', 'a10') < 0, isTrue);
    expect(compareNatural('A', 'a') != 0, isTrue); // stable, pas d'égalité ambiguë
    expect(compareNatural('x', 'x'), 0);
  });
}
