import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/storage_screen.dart';

void main() {
  StorageEntry e(String path, String label) =>
      StorageEntry(path, label, 10, false);

  test('files grouped under one header per folder, root files headerless', () {
    final rows = groupStorageRows([
      e('/r/b/2.mod', 'b/2.mod'),
      e('/r/top.mod', 'top.mod'),
      e('/r/a/1.mod', 'a/1.mod'),
      e('/r/b/1.mod', 'b/1.mod'),
    ]);
    String show(Object r) => r is StorageDirGroup
        ? '[${r.label}:${r.entries.length}]'
        : (r as StorageEntry).label;
    expect(rows.map(show).toList(),
        ['top.mod', '[a:1]', 'a/1.mod', '[b:2]', 'b/1.mod', 'b/2.mod']);
  });

  test('two real folders with the same readable label stay separate', () {
    final rows = groupStorageRows([
      e('/r/uuid1/x.vgz', 'Album/x.vgz'),
      e('/r/uuid2/y.vgz', 'Album/y.vgz'),
    ]);
    final groups = rows.whereType<StorageDirGroup>().toList();
    expect(groups.length, 2);
    expect(groups.map((g) => g.entries.single.path).toSet(),
        {'/r/uuid1/x.vgz', '/r/uuid2/y.vgz'});
  });
}
