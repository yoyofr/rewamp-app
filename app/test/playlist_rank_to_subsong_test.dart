// La re-matérialisation d'une entrée de playlist traduit le RANG transporté
// par ext_ref en VRAI index de sous-chanson — via la tracklist que le serveur
// renvoie avec le conteneur, sans aller-retour. Avant, withSubsongEntry posait
// le rang en subsong_idx: sur un fichier à décalage (.kss absolu, .gbs à
// NOSOUND) la lecture visait la sous-chanson du rang.

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

Map<String, dynamic> containerRow({List<Map<String, dynamic>>? tracks,
    Map<String, dynamic>? extRef, int? trackCount}) => {
      'song_id': '11111111-2222-3333-4444-555555555555',
      'collection': 'joshw',
      'title': 'IK MSX',
      'filename': 'ik.kss',
      'format_ext': 'kss',
      'track_count': trackCount ?? tracks?.length,
      if (tracks != null) 'tracks': tracks,
      if (extRef != null) 'ext_ref': extRef,
    };

void main() {
  test('rang → vrai index via la tracklist (décalage KSS)', () {
    // Numérotation absolue: le rang 0 est la sous-chanson 6.
    final r = RewampDb.playlistCatalogueRowForTest(containerRow(
      tracks: [
        {'subsong': 6, 'title': 'Round 1'},
        {'subsong': 7, 'title': 'Round 2'},
        {'subsong': 9, 'title': 'Boss'},
      ],
      extRef: {'subsong_idx': 2},
    ));
    expect(r.songId, endsWith('#2'), reason: 'le rang reste l\'IDENTITÉ');
    expect(r.subsongIdx, 9, reason: 'l\'index JOUÉ vient de la tracklist');
    expect(r.title, 'Boss');
  });

  test('membre multi-fichiers: son fichier joue entier', () {
    final r = RewampDb.playlistCatalogueRowForTest(containerRow(
      tracks: [
        {'file': 'a.psf', 'title': 'A'},
        {'file': 'b.psf', 'title': 'B'},
      ],
      extRef: {'subsong_idx': 1, 'file_name': 'b.psf'},
    ));
    expect(r.songId, endsWith('#1'));
    expect(r.subsongIdx, 0,
        reason: 'withSubsongEntry écrasait le 0 du membre par le rang');
  });

  test('rang hors de la tracklist: comportement inchangé', () {
    final r = RewampDb.playlistCatalogueRowForTest(containerRow(
      tracks: [{'subsong': 0, 'title': 'Seule'}],
      trackCount: 21,
      extRef: {'subsong_idx': 13},
    ));
    expect(r.songId, endsWith('#13'));
    expect(r.subsongIdx, 13, reason: 'sans entrée à traduire, on ne devine pas');
  });
}
