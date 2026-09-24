// Une entrée de bibliothèque qui vise le FICHIER ENTIER n'est pas une entrée
// posée sur la SOUS-CHANSON 0 — et le compte doit pouvoir les distinguer.
//
// Le compte ne porte qu'un `subsong_idx` ENTIER: sans drapeau, les deux
// partageaient la même ligne. Le symptôme mesuré était un `.rsn` importé qui
// apparaissait DEUX fois en bibliothèque (le pull re-fabriquant la jumelle
// `?subsong=0` une seconde après l'import), la doublure ne jouant que sa 1re
// sous-chanson. Le corriger en fusionnant les deux aurait interdit de mettre
// en favori la 1re sous-chanson d'un conteneur.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';
import 'package:rewamp/sync_service.dart';

void main() {
  group('clé de compte', () {
    test('« fichier entier » et « sous-chanson 0 » ont des clés DIFFÉRENTES', () {
      final whole = SyncService.localLibraryKey(
          fileName: 'Super Mario World.rsn', relPath: 'local', whole: true);
      final sub0 = SyncService.localLibraryKey(
          fileName: 'Super Mario World.rsn', relPath: 'local', subsongIdx: 0);
      expect(whole, isNot(sub0));
    });

    test('une entrée ordinaire garde EXACTEMENT sa clé d\'avant le drapeau', () {
      // Le jeton n'est ajouté au matériel que lorsqu'il est vrai: aucune
      // entrée de compte existante ne change d'identité.
      expect(
        SyncService.localLibraryKey(
            fileName: 'a.sid', relPath: 'local', subsongIdx: 3),
        SyncService.localLibraryKey(
            fileName: 'a.sid', relPath: 'local', subsongIdx: 3, whole: false),
      );
    });

    test('la sous-chanson reste discriminante', () {
      expect(
        SyncService.localLibraryKey(fileName: 'a.sid', subsongIdx: 0),
        isNot(SyncService.localLibraryKey(fileName: 'a.sid', subsongIdx: 1)),
      );
    });
  });

  group('instantané envoyé au compte', () {
    test('le drapeau voyage', () {
      const ref = PlaylistExtRef(
          fileName: 'Super Mario World.rsn', relPath: 'local', whole: true);
      final json = ref.toJson();
      expect(json['whole'], true);
      expect(PlaylistExtRef.fromJson(
              jsonDecode(jsonEncode(json)) as Map<String, dynamic>).whole,
          true);
    });

    test('une entrée ordinaire n\'émet PAS le champ', () {
      const ref = PlaylistExtRef(fileName: 'a.sid', subsongIdx: 0);
      expect(ref.toJson().containsKey('whole'), false);
    });

    test('un instantané ANTÉRIEUR se lit « pas entier »', () {
      // Un client plus ancien n'écrivait pas le champ: on retombe sur la
      // sous-chanson 0 — dégradé, jamais faux.
      expect(
        PlaylistExtRef.fromJson(
            {'file_name': 'a.rsn', 'subsong_idx': 0}).whole,
        false,
      );
    });
  });
}
