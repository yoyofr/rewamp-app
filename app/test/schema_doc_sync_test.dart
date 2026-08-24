// `local_db_schema.sql` est une DOCUMENTATION du schéma que `_onCreate`
// exécute vraiment (`_kSchemaStatements`) — la règle des trois copies a déjà
// cassé deux fois des installations neuves en silence (migs 23 et 37), et le
// doc avait dérivé de six tables et quatre colonnes quand ce test a été écrit.
// Ici la dérive devient un test rouge: tables et colonnes doivent coïncider.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _head = RegExp(r'CREATE TABLE (?:IF NOT EXISTS )?(\w+)\s*\(');

/// Un compteur de parenthèses, pas une regex: le corps d'une table contient
/// des parenthèses imbriquées (UNIQUE(...), REFERENCES x(id)) et une regex
/// non gourmande s'arrête à la première fermante — la moitié des tables
/// disparaissait du relevé.
Map<String, Set<String>> tablesOf(String src) {
  final out = <String, Set<String>>{};
  for (final m in _head.allMatches(src)) {
    var depth = 1;
    var i = m.end;
    while (i < src.length && depth > 0) {
      if (src[i] == '(') depth++;
      if (src[i] == ')') depth--;
      i++;
    }
    final cols = <String>{};
    for (var line in src.substring(m.end, i - 1).split('\n')) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('--')) continue;
      final w = line.split(RegExp(r'[\s(]')).first;
      if (w.isEmpty || {'UNIQUE', 'PRIMARY', 'FOREIGN', 'CHECK'}.contains(w)) {
        continue;
      }
      cols.add(w);
    }
    out[m.group(1)!] = cols;
  }
  return out;
}

void main() {
  test('local_db_schema.sql reflète _kSchemaStatements', () {
    final dart = File('lib/local_db.dart').readAsStringSync();
    final doc = File('lib/local_db_schema.sql').readAsStringSync();

    final i = dart.indexOf('const _kSchemaStatements = [');
    final j = dart.indexOf('\n];', i);
    var code = dart.substring(i, j);
    // _kPlaylistTracksDdl est référencé par identifiant dans la liste.
    final pt = RegExp(r"const _kPlaylistTracksDdl = '''(.*?)''';", dotAll: true)
        .firstMatch(dart)!
        .group(1)!;
    code = '$code\n$pt;';

    final codeTables = tablesOf(code);
    final docTables = tablesOf(doc);

    expect(docTables.keys.toSet(), codeTables.keys.toSet(),
        reason: 'tables du doc ≠ tables du schéma embarqué — régénérer '
            'local_db_schema.sql (voir son en-tête)');
    for (final t in codeTables.keys) {
      expect(docTables[t], codeTables[t],
          reason: 'colonnes de `$t` — le doc a dérivé du code');
    }

    // La version affichée dans l'en-tête du doc suit celle du code.
    final v = RegExp(r'version: (\d+),').firstMatch(dart)!.group(1)!;
    expect(doc.contains('version $v'), isTrue,
        reason: 'l\'en-tête du doc annonce une autre version que le code ($v)');
  });
}
