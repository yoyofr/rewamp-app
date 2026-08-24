// `subsong_count` décrit le FICHIER, `resolvedSubsong` décrit la LIGNE.
//
// Les deux vivaient dans la même colonne: « subsongCount == 1 » servait de
// sentinelle « cette ligne est déjà une sous-chanson résolue, ne pas la
// redéplier ». Mais le compte est lu ailleurs comme une propriété du FICHIER
// (isContainerRow, l'écran des stats, la migration 49), et une ligne de
// sous-chanson d'un `.sid` sortait donc à 1, c'est-à-dire « fichier à une seule
// sous-chanson » — faux, et c'est ce qui rendait la question « ce fichier
// est-il multi-sous-chansons ? » sans réponse fiable en base.

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

SearchResult row({int? count, bool resolved = false}) => SearchResult(
      songId: 'uuid-1',
      collection: 'hvsc',
      title: 'Monty on the Run',
      filename: 'Monty_on_the_Run.sid',
      formatExt: 'sid',
      downloadUrl: null,
      fileSize: 0,
      year: null,
      artistNames: const [],
      totalCount: 0,
      album: null,
      subsongCount: count,
      resolvedSubsong: resolved,
    );

void main() {
  test('un compte de 1 ne veut plus dire « déjà résolue »', () {
    // Le cas qui piégeait: un fichier à UNE sous-chanson n'est pas, pour
    // autant, une ligne qu'il ne faut plus déplier.
    expect(row(count: 1).resolvedSubsong, isFalse);
    expect(row(count: 21).resolvedSubsong, isFalse);
  });

  test('le drapeau est indépendant du compte', () {
    final r = row(count: 21, resolved: true);
    expect(r.resolvedSubsong, isTrue);
    expect(r.subsongCount, 21,
        reason: 'une sous-chanson résolue garde le compte de SON fichier');
  });

  test('le membre d\'un album multi-fichiers: 1 sous-chanson ET résolu', () {
    // `narrowedToFile` est le producteur historique de la sentinelle. Ici le 1
    // est un vrai compte — le membre EST un fichier d'une seule sous-chanson —
    // et « résolue » voyage à côté.
    const container = SearchResult(
        songId: 'uuid-album',
        collection: 'jw_psf',
        title: 'Un album',
        filename: 'album.7z',
        formatExt: '7z',
        downloadUrl: null,
        fileSize: 0,
        year: null,
        artistNames: [],
        totalCount: 0,
        album: 'Un album',
        subsongCount: 86);
    final member = container.narrowedToFile(
        const AlbumSubsong(file: 'track01.psf', title: 'Track 01', subsong: 0));
    expect(member.subsongCount, 1);
    expect(member.resolvedSubsong, isTrue);
  });

  test('rétrécir vers une SOUS-CHANSON garde le compte du fichier', () {
    // Le cas HVSC: le serveur renvoie 19 sous-chansons pour UN fichier. Chacune
    // est une ligne résolue, mais le FICHIER en porte toujours 19 — c'était le
    // dernier endroit d'où sortait un « subsong_count = 1 » faux.
    final sid = row(count: 19);
    final sub = sid.narrowedToFile(
        const AlbumSubsong(subsong: 6, title: 'Monty on the Run (7)'));
    expect(sub.subsongCount, 19);
    expect(sub.resolvedSubsong, isTrue);
    expect(sub.subsongIdx, 6);
  });

  test('par défaut une ligne de catalogue n\'est pas résolue', () {
    expect(row().resolvedSubsong, isFalse);
  });

  test('copyWith ne perd AUCUN champ — la classe de bugs des faiseurs', () {
    // narrowedToFile perdait sept champs à la main (hasVideo, podium, extRef,
    // popularity, matchSubsongTitle, matchSubsongIndex, isAlbumRow). Les
    // faiseurs passant par copyWith, une copie préserve tout ce qu'elle ne
    // change pas — épinglé sur les champs qui ont déjà été perdus une fois.
    final src = row(count: 19).copyWith(
      popularity: 97,
      hasVideo: true,
      trackPosition: 4,
      localPath: '/d/x.sid',
    );
    final sub = src.narrowedToFile(const AlbumSubsong(subsong: 6, title: 'T (7)'));
    expect(sub.popularity, 97);
    expect(sub.hasVideo, isTrue);
    expect(sub.trackPosition, 4);
    expect(sub.localPath, '/d/x.sid');
    expect(sub.subsongCount, 19);
    final entry = src.withSubsongEntry(3);
    expect(entry.hasVideo, isTrue);
    expect(entry.songId, 'uuid-1#3');
    expect(entry.resolvedSubsong, isTrue);
  });
}
