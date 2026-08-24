// Ce qu'une tracklist serveur donne à CHAQUE sous-chanson d'un conteneur.
//
// C'est la pièce qui rend l'identité complète stockable au téléchargement
// (`materializeAlbumTracks`), y compris pour les sous-chansons jamais jouées:
// sans elle, seules celles qu'on avait écoutées avaient une ligne, et la
// relance repartait sans identité — le lecteur affichait alors « local » pour
// un album pourtant téléchargé.
//
// Les deux nombres NE SONT PAS le même, et c'est le piège: `#i` est le RANG
// dans la liste serveur (0-based, toujours), tandis que `subsongIdx` est
// l'index de LECTURE, normalisé depuis la numérotation native du format (NSF
// 1-based, GBS 0-based, KSS absolu). Mesuré sur un `.gbs` réel: la sous-chanson
// 12 porte `#13`. Recopier l'un pour l'autre viserait la mauvaise piste.
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

SearchResult _container(String ext, List<AlbumSubsong> subs) => SearchResult(
      songId: 'uuid',
      collection: 'jw_gbs',
      title: 'Album',
      filename: 'DMG-RWA.$ext',
      album: 'Album',
      formatExt: ext,
      downloadUrl: null,
      fileSize: 0,
      year: 1991,
      artistNames: const ['Capcom'],
      totalCount: 1,
      subsongs: subs,
      platform: 'Game Boy',
    );

void main() {
  test('un conteneur 1-based (NSF): rang 0-based, lecture décalée', () {
    final rows = RewampDb.subsongRowsFromServer(_container('nsf', const [
      AlbumSubsong(subsong: 1, title: 'A'),
      AlbumSubsong(subsong: 2, title: 'B'),
      AlbumSubsong(subsong: 14, title: 'N'),
    ]));

    expect(rows.map((r) => r.songId), ['uuid#0', 'uuid#1', 'uuid#2']);
    // 1-based côté serveur → 0-based côté lecture.
    expect(rows.map((r) => r.subsongIdx), [0, 1, 13]);
  });

  test('un conteneur 0-based (GBS) ne décale pas la lecture', () {
    final rows = RewampDb.subsongRowsFromServer(_container('gbs', const [
      AlbumSubsong(subsong: 0, title: 'Title'),
      AlbumSubsong(subsong: 7, title: 'Fire Man'),
      AlbumSubsong(subsong: 12, title: 'Wily 2'),
    ]));

    expect(rows.map((r) => r.songId), ['uuid#0', 'uuid#1', 'uuid#2']);
    expect(rows.map((r) => r.subsongIdx), [0, 7, 12]);
  });

  test('chaque sous-chanson hérite de ce qui identifie sa PROVENANCE', () {
    final rows = RewampDb.subsongRowsFromServer(_container('gbs', const [
      AlbumSubsong(subsong: 0, title: 'A'),
      AlbumSubsong(subsong: 1, title: 'B'),
    ]));

    for (final r in rows) {
      expect(r.collection, 'jw_gbs');
      expect(r.platform, 'Game Boy');
      expect(r.year, 1991);
      expect(r.subsongCount, 2);
    }
  });

  test('un fichier MONO-sous-chanson traverse intact', () {
    // Pas de liste de sous-chansons: la ligne est déjà la piste, et elle garde
    // SON identité — rien à renuméroter, rien à suffixer.
    const one = SearchResult(
      songId: 'plain-uuid',
      collection: 'modland',
      title: 'Song',
      filename: 'song.mod',
      album: null,
      formatExt: 'mod',
      downloadUrl: null,
      fileSize: 0,
      year: null,
      artistNames: [],
      totalCount: 1,
    );
    final rows = RewampDb.subsongRowsFromServer(one);

    expect(rows.length, 1);
    expect(rows.single.songId, 'plain-uuid');
    expect(rows.single.subsongIdx, 0);
  });

  test('une tracklist d\'UNE entrée est prise telle quelle — 0-based', () {
    // zxart publie le même conteneur .ay une fois par tune: chaque ligne porte
    // sa SEULE entrée jouable, `tracks=[{"subsong":6}]`, et track_count vaut 1.
    // Le repérage du 1-based lit le MINIMUM de la liste — il n'a de sens que si
    // la liste couvre le fichier. Sur une entrée unique il concluait « 1-based »
    // dès que l'index n'était pas 0 et jouait la tune d'AVANT: sept lignes
    // fausses sur huit.
    for (final idx in [0, 1, 6, 7]) {
      final rows = RewampDb.subsongRowsFromServer(
          _container('ay', [AlbumSubsong(subsong: idx, title: 'Tune')]));
      expect(rows, hasLength(1));
      expect(rows.single.subsongIdx, idx,
          reason: 'entrée unique: aucune base à déduire, le serveur est 0-based');
    }
  });

  test('plusieurs entrées: la base se déduit encore du minimum', () {
    // Le garde-fou ci-dessus ne doit pas désarmer la normalisation là où elle
    // sert (joshw NSF, 1-based sur toute la liste).
    final rows = RewampDb.subsongRowsFromServer(_container('nsf', const [
      AlbumSubsong(subsong: 1, title: 'A'),
      AlbumSubsong(subsong: 5, title: 'B'),
    ]));
    expect(rows.map((r) => r.subsongIdx), [0, 4]);
  });
}
