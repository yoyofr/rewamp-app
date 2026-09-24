import 'dart:math';

import 'package:flutter/widgets.dart';

import 'rewamp_db.dart' show SearchResult, OnPlayAlbum;
import 'track_options_sheet.dart' show globalOnPlayAlbum;

/// « Tout lire » / Radio / Surprise sur une liste d'ENTITÉS (artistes, groupes,
/// albums, playlists, productions, formats, pays…), c'est-à-dire de lignes qui
/// ne sont pas des pistes: chacune se DÉPLIE en pistes par [fetch].
///
/// Une seule implémentation pour tous les écrans, parce que les trois actions
/// doivent se lire comme UNE famille partout (demande du 2026-09-02) et que
/// les plafonds sont un choix de produit, pas un détail d'écran: « tout lire »
/// est un LANCEMENT, pas un aspirateur.
typedef EntityFetch<T> = Future<List<SearchResult>> Function(T entity);

/// Combien d'entités on déplie, et combien de pistes au total.
const int kEntityMaxExpand = 10;
const int kEntityTrackCap = 2000;

/// Déplie [rows] (plafonnées) en pistes et les envoie à la file, par lots de 5.
///
/// ⚠️ Un album CONTENEUR — une seule ligne multi-sous-chansons, ou l'ARCHIVE
/// d'un album joshw dont le serveur ne connaît pas le détail piste par piste —
/// est GARDÉ TEL QUEL, comme UNE entrée de file. Il était jeté, et le geste
/// « lire » d'une liste d'albums démarrait alors au DEUXIÈME (mesuré sur
/// « Kondo »: le 1er album, `jw_spc`, rend une seule ligne `.7z` à
/// `track_count: 11`). Ce qu'il faut éviter, c'est de le DÉPLIER ici —
/// `expandContainerAlbum` télécharge et sonde le fichier, soit dix
/// téléchargements pour un bouton — pas de le perdre: `_startAlbumQueue`
/// extrait les archives (`ensureAlbumExtracted`) et diffère l'expansion des
/// sous-chansons jusqu'à ce que l'entrée soit ATTEINTE.
Future<void> playEntitiesChained<T>(
  BuildContext context,
  List<T> rows,
  EntityFetch<T> fetch, {
  OnPlayAlbum? onPlayAlbum,
  int maxExpand = kEntityMaxExpand,
  int cap = kEntityTrackCap,
}) async {
  final take = rows.take(maxExpand).toList();
  final all = <SearchResult>[];
  for (var i = 0; i < take.length && all.length < cap; i += 5) {
    final chunk = take.sublist(i, min(i + 5, take.length));
    final lists = await Future.wait([
      for (final e in chunk) fetch(e).catchError((_) => const <SearchResult>[]),
    ]);
    for (final l in lists) {
      all.addAll(l);
    }
  }
  if (all.isEmpty || !context.mounted) return;
  (onPlayAlbum ?? globalOnPlayAlbum)?.call(context, all.take(cap).toList());
}

/// Les trois rappels prêts à poser dans un `RadioSurpriseButtons`. Radio = la
/// MÊME liste mélangée (ce n'est pas une station serveur), surprise = UNE
/// entrée au hasard.
({VoidCallback playAll, VoidCallback radio, VoidCallback surprise})
    entityPlayActions<T>(
  BuildContext context,
  List<T> rows,
  EntityFetch<T> fetch, {
  OnPlayAlbum? onPlayAlbum,
  int maxExpand = kEntityMaxExpand,
  int cap = kEntityTrackCap,
}) {
  Future<void> run(List<T> list) => playEntitiesChained<T>(
        context,
        list,
        fetch,
        onPlayAlbum: onPlayAlbum,
        maxExpand: maxExpand,
        cap: cap,
      );
  return (
    playAll: () => run(rows),
    radio: () => run(List.of(rows)..shuffle(Random())),
    surprise: () => run([rows[Random().nextInt(rows.length)]]),
  );
}
