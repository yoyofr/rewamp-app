// Les deux podspecs Apple, relus SANS CocoaPods.
//
// Un podspec est du Ruby exécuté par `pod install`: une variable employée avant
// d'avoir été déclarée n'est pas une liste vide, c'est une NameError, et
// l'installation meurt sur « undefined local variable or method 'libs' » — un
// message qui ne dit ni le fichier fautif ni qu'il s'agit d'un ORDRE.
//
// Deux façons d'y tomber, et les deux ont été payées:
//
//   * 2026-09-24, macOS: le bloc furnace réclamait zlib (`libs << 'z'`) à la
//     ligne 636, alors que `libs` n'était déclaré qu'à la 1810, tout en bas,
//     près du `s.libraries` qui le consomme. Personne ne le voit en lisant le
//     bloc, qui est juste — c'est le reste du fichier qui décide;
//   * le piège jumeau, déjà documenté: **les deux podspecs n'emploient PAS les
//     mêmes noms** (iOS `defines`/`search_paths`/`libraries`, macOS
//     `preprocessor`/`header_dirs`/`libs`). Un bloc copié d'un fichier à
//     l'autre sans renommer produit EXACTEMENT la même erreur, puisque le nom
//     recopié n'existe pas dans le fichier d'arrivée.
//
// Ce test attrape les deux d'un coup, sur une machine qui n'a ni Ruby ni
// CocoaPods: tout nom employé en `nom << …` doit avoir été déclaré `nom = …`
// PLUS HAUT dans le même fichier.
//
// ⚠️ Ce qu'il ne prétend pas faire: il ne remplace pas `pod install`. Il ne
// vérifie pas la syntaxe Ruby, ni que le bloc compile — seulement l'ordre, qui
// est ce qui casse en silence à la lecture.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `nom << valeur` en début de ligne (l'accumulation), et `nom = …` (la
/// déclaration). On ignore ce qui est derrière un `.` (`s.libraries`) et les
/// commentaires.
final _push = RegExp(r'^\s*([a-z_][a-z0-9_]*)\s*<<');
final _decl = RegExp(r'^\s*([a-z_][a-z0-9_]*)\s*=[^=~]');

void main() {
  for (final platform in const ['ios', 'macos']) {
    test('$platform: aucun accumulateur employé avant sa déclaration', () {
      final file =
          File('../packages/rewamp_audio/$platform/rewamp_audio.podspec');
      expect(file.existsSync(), isTrue, reason: '${file.path} introuvable');

      final declared = <String, int>{};
      final offenders = <String>[];
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('#')) continue;

        final decl = _decl.firstMatch(line);
        if (decl != null) declared.putIfAbsent(decl.group(1)!, () => i + 1);

        final push = _push.firstMatch(line);
        if (push != null && !declared.containsKey(push.group(1)!)) {
          offenders.add('  ligne ${i + 1}: ${push.group(1)} — ${line.trim()}');
        }
      }

      expect(offenders, isEmpty,
          reason: 'accumulateur employé avant d\'exister dans '
              '${file.path} (pod install lèvera « undefined local variable »):\n'
              '${offenders.join('\n')}\n'
              'Le déclarer en tête, avec les autres — et vérifier qu\'il porte '
              'bien le nom de CE podspec (ios et macos en emploient des '
              'différents).');
    });
  }
}
