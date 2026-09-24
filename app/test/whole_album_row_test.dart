import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

/// L'onglet Morceaux ne liste QUE des morceaux, et « Tout lire » ne met en file
/// que ceux-là. Le prédicat qui les sépare des lignes d'ALBUM ENTIER est étroit
/// exprès: mesuré sur la recherche « Kondo », `isAlbumLevelMatch` écartait 10
/// lignes sur 10 (les membres d'un `.rsn` snesmusic n'ont pas d'url à eux) et
/// le bouton « Tout lire » ne faisait plus rien.
void main() {
  SearchResult row(Map<String, dynamic> j) => SearchResult.fromJson({
        'song_id': 'id',
        'collection': 'c',
        'filename': 'f',
        ...j,
      });

  test('une archive joshw est une ligne d\'ALBUM ENTIER', () {
    // jw_spc « Bishoujo Senshi Sailor Moon S - Kondo wa Puzzle… »: une seule
    // ligne, l'archive .7z, 11 pistes annoncées, aucune position de piste.
    expect(
      RewampDb.isWholeAlbumRow(row({
        'album_id': '56b2c2bf-5cda-5fc0-818b-2f9198752435',
        'track_count': 11,
        'download_url': 'https://spc.joshw.info/b/x.7z',
      })),
      isTrue,
    );
  });

  test('un membre d\'archive SANS url à lui reste un MORCEAU', () {
    // snesmusic « A Challenging Opponent »: download_url ET mirror_url nuls —
    // le fichier vit dans le .rsn de l'album. isAlbumLevelMatch le prend pour
    // un album; ce n'en est pas un.
    final r = row({
      'album_id': '3b7ccf5a-7148-5439-b8d7-63dd7be0e016',
      'track_count': 1,
      'track_position': 6,
    });
    expect(RewampDb.isWholeAlbumRow(r), isFalse);
    expect(RewampDb.isAlbumLevelMatch(r), isTrue, reason: 'le piège');
  });

  test('un fichier multi-sous-chansons SANS album reste un MORCEAU', () {
    // Un .sid HVSC: 20 sous-chansons, aucun album — c'est un morceau.
    expect(
      RewampDb.isWholeAlbumRow(row({
        'track_count': 20,
        'download_url': 'https://hvsc.brona.dk/x.sid',
      })),
      isFalse,
    );
  });

  group('matché par le NOM DE L\'ALBUM seulement', () {
    // « Kondo »: les onze pistes de l'album snesmusic ne portent pas le mot,
    // c'est le nom de l'album qui matche — elles polluaient l'onglet Morceaux.
    final member = row({
      'title': 'A Challenging Opponent',
      'filename': 'smspo-06.spc',
      'album': 'Bishoujo Senshi Sailor Moon S: Kondo wa Puzzle de Oshioki yo!',
      'album_id': '3b7ccf5a',
      'track_count': 1,
      'track_position': 6,
      'artist_names': ['Harumi Fujita'],
    });

    test('elle est écartée', () {
      expect(RewampDb.matchedAlbumNameOnly(member, 'Kondo'), isTrue);
    });

    test('une piste du MÊME album dont le titre matche est GARDÉE', () {
      final titled = row({
        'title': 'Kondo Theme',
        'filename': 'smspo-02.spc',
        'album': 'Bishoujo Senshi Sailor Moon S: Kondo wa Puzzle de Oshioki yo!',
        'album_id': '3b7ccf5a',
        'track_count': 1,
        'track_position': 2,
      });
      expect(RewampDb.matchedAlbumNameOnly(titled, 'Kondo'), isFalse);
    });

    test('un match par ARTISTE est un match', () {
      final byArtist = row({
        'title': 'Overworld',
        'filename': 'x.spc',
        'album': 'Kondo Best',
        'album_id': 'a',
        'artist_names': ['Koji Kondo'],
      });
      expect(RewampDb.matchedAlbumNameOnly(byArtist, 'Kondo'), isFalse);
    });

    test('recherche FLOUE: rien à attribuer à l\'album, on garde', () {
      // Le titre a matché sans contenir la chaîne (faute de frappe): l'album ne
      // la contient pas davantage, donc on ne peut PAS imputer le match à
      // l'album — la ligne reste.
      expect(RewampDb.matchedAlbumNameOnly(member, 'Kondoo'), isFalse);
    });
  });

  group('le serveur a nommé la PISTE (match_track_title)', () {
    // « into the wilderness »: les 8 résultats sont des conteneurs joshw dont
    // le serveur nomme la piste trouvée (Wild Arms → « To the End of the
    // Wilderness »). Sans cette garde, l'onglet Morceaux affichait « 0 / 8 ».
    final named = row({
      'title': 'Wild Arms',
      'filename': 'Wild Arms.psf',
      'album': 'Wild Arms',
      'album_id': 'wa',
      'track_count': 86,
      'match_track_title': 'To the End of the Wilderness ~ To a New Journey',
      'match_track_index': 12,
    });

    test('ce n\'est PAS une ligne d\'album entier', () {
      expect(RewampDb.isWholeAlbumRow(named), isFalse);
    });

    test('elle n\'est jamais écartée comme « match par nom d\'album »', () {
      // Même si le nom de l'album contenait la recherche: le serveur a nommé
      // la piste, le match vient d'elle.
      expect(RewampDb.matchedAlbumNameOnly(named, 'Wild Arms'), isFalse);
    });
  });
}
