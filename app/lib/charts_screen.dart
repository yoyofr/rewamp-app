// Le navigateur « Charts » — les palmarès, en deux familles que le premier
// écran sépare:
//
//  - GLOBAL: tout le catalogue, par les RPC de popularité rewamp
//    (`most_popular_songs` en mode rating, `most_popular_albums`);
//  - PAR COLLECTION: les mêmes palmarès bornés à une collection, PLUS ses
//    playlists de CLASSEMENT quand elle en a (HVSC Top 100…) — reconstruites
//    chaque dimanche depuis une source externe, voir [ChartPlaylist].
//
// ⚠️ Une playlist de classement se LIT comme n'importe quelle playlist
// (get_playlist_tracks, `meta.rank` = le rang, la convention des compos
// demozoo — le badge de podium marche tel quel), et ne se PROPOSE JAMAIS à
// l'édition. `chart_url` est le crédit vers la source: il se MONTRE, c'est
// leur travail.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_snack.dart';
import 'artwork_image.dart';
import 'browse_screen.dart' show PlaylistTracksScreen;
import 'collection_families.dart' show collectionFamilyOf;
import 'l10n.dart';
import 'library_toolbar.dart' show ListFilterField, kListFilterThreshold,
    matchesFilterQuery;
import 'radio_surprise_buttons.dart';
import 'rewamp_db.dart';
import 'scrolling_text.dart';
import 'search_screen.dart' show playAlbumFromList;
import 'album_detail_screen.dart';
import 'shell_insets.dart';
import 'song_tile.dart';
import 'track_options_sheet.dart'
    show OnQueueAdd, OnAlbumQueueAdd, globalOnPlayAlbum;

/// Le rang d'une ligne de palmarès — médailles sur le podium, nombre après.
/// La même convention que les playlists de compétition.
String chartRankLabel(int pos) => switch (pos) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '$pos',
    };

enum ChartMode { songs, albums }

// ── Écran 1: global ou par collection ──────────────────────────────────────

class ChartsScreen extends StatefulWidget {
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnPlayAlbum? onPlayAlbum;
  final OnQueueAdd? onQueueAdd;
  final OnAlbumQueueAdd? onAlbumQueueAdd;

  const ChartsScreen({
    super.key,
    required this.onTap,
    this.onPlayAlbum,
    this.onQueueAdd,
    this.onAlbumQueueAdd,
  });

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  List<Collection>? _collections;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cols = await RewampDb.fetchCollections();
      if (mounted) setState(() => _collections = cols);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _openResults(ChartMode mode, {String? slug, String? name}) {
    final l10n = context.l10n;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChartResultsScreen(
        title: name == null
            ? (mode == ChartMode.songs
                ? l10n.chartsTopSongs
                : l10n.chartsTopAlbums)
            : '$name — ${mode == ChartMode.songs ? l10n.chartsTopSongs : l10n.chartsTopAlbums}',
        mode: mode,
        collectionSlug: slug,
        onTap: widget.onTap,
        onPlayAlbum: widget.onPlayAlbum,
        onQueueAdd: widget.onQueueAdd,
        onAlbumQueueAdd: widget.onAlbumQueueAdd,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final cols = _collections ?? const <Collection>[];
    final visible = [
      for (final c in cols)
        if (matchesFilterQuery(_query, [c.name, c.slug])) c,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.browseCharts)),
      body: _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: cs.error)))
          : ListView(
              padding: shellInset(context, EdgeInsets.zero),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(l10n.chartsGlobal,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  leading: const Icon(Icons.music_note_outlined),
                  title: Text(l10n.chartsTopSongs),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openResults(ChartMode.songs),
                ),
                ListTile(
                  leading: const Icon(Icons.album_outlined),
                  title: Text(l10n.chartsTopAlbums),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openResults(ChartMode.albums),
                ),
                const Divider(height: 24),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(l10n.chartsByCollection,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                if (_collections == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (cols.length > kListFilterThreshold)
                    ListFilterField(
                      query: _query,
                      onQuery: (v) => setState(() => _query = v),
                    ),
                  for (final c in visible)
                    ListTile(
                      dense: true,
                      title: Text(c.name),
                      // La famille (joshw…) comme repère, pas comme filtre:
                      // un palmarès se demande PAR collection au serveur.
                      subtitle: collectionFamilyOf(c.slug) != null
                          ? Text(collectionFamilyOf(c.slug)!.label,
                              style: TextStyle(
                                  fontSize: 10, color: cs.onSurfaceVariant))
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CollectionChartsScreen(
                          slug: c.slug,
                          name: c.name,
                          onTap: widget.onTap,
                          onPlayAlbum: widget.onPlayAlbum,
                          onQueueAdd: widget.onQueueAdd,
                          onAlbumQueueAdd: widget.onAlbumQueueAdd,
                        ),
                      )),
                    ),
                ],
              ],
            ),
    );
  }
}

// ── Écran 2: les palmarès d'UNE collection ─────────────────────────────────

class CollectionChartsScreen extends StatefulWidget {
  final String slug;
  final String name;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnPlayAlbum? onPlayAlbum;
  final OnQueueAdd? onQueueAdd;
  final OnAlbumQueueAdd? onAlbumQueueAdd;

  const CollectionChartsScreen({
    super.key,
    required this.slug,
    required this.name,
    required this.onTap,
    this.onPlayAlbum,
    this.onQueueAdd,
    this.onAlbumQueueAdd,
  });

  @override
  State<CollectionChartsScreen> createState() => _CollectionChartsScreenState();
}

class _CollectionChartsScreenState extends State<CollectionChartsScreen> {
  CollectionOverview? _overview;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // UN appel: `get_collection_overview` porte à la fois `album_count`
      // (l'axe Albums ne se propose que s'il existe — hvsc n'en a pas) et la
      // liste `charts` de la collection.
      final o = await RewampDb.getCollectionOverview(widget.slug);
      if (mounted) setState(() => _overview = o ?? const CollectionOverview());
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _openResults(ChartMode mode) {
    final l10n = context.l10n;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChartResultsScreen(
        title:
            '${widget.name} — ${mode == ChartMode.songs ? l10n.chartsTopSongs : l10n.chartsTopAlbums}',
        mode: mode,
        collectionSlug: widget.slug,
        onTap: widget.onTap,
        onPlayAlbum: widget.onPlayAlbum,
        onQueueAdd: widget.onQueueAdd,
        onAlbumQueueAdd: widget.onAlbumQueueAdd,
      ),
    ));
  }

  Future<void> _openChartUrl(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) AppSnack.showOn(messenger, url);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final o = _overview;
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.name,
              maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: cs.error)))
          : o == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: shellInset(context, EdgeInsets.zero),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(l10n.chartsRewampSection,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.music_note_outlined),
                      title: Text(l10n.chartsTopSongs),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openResults(ChartMode.songs),
                    ),
                    // « si ça s'applique »: certaines collections n'ont pas
                    // d'albums (hvsc: album_count = 0) — pas de choix mort.
                    if (o.albumCount > 0)
                      ListTile(
                        leading: const Icon(Icons.album_outlined),
                        title: Text(l10n.chartsTopAlbums),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openResults(ChartMode.albums),
                      ),
                    if (o.charts.isNotEmpty) ...[
                      const Divider(height: 24),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: Text(l10n.chartsPublishedSection,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      for (final c in o.charts)
                        ListTile(
                          leading: const Icon(Icons.leaderboard_outlined),
                          title: Text(c.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          isThreeLine: c.updatedAt != null,
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(l10n.playlistTrackCount(c.trackCount),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              if (c.updatedAt != null)
                                Text(
                                  l10n.chartsUpdated(DateFormat.yMd(locale)
                                      .format(c.updatedAt!.toLocal())),
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: cs.onSurfaceVariant),
                                ),
                            ],
                          ),
                          // Le crédit vers la source, toujours visible: le
                          // classement est LEUR travail.
                          trailing: (c.chartUrl != null &&
                                  c.chartUrl!.isNotEmpty)
                              ? IconButton(
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  tooltip: l10n.chartsSource,
                                  onPressed: () => _openChartUrl(c.chartUrl!),
                                )
                              : null,
                          onTap: () =>
                              Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ChartPlaylistScreen(
                              chart: c,
                              onTap: widget.onTap,
                              onPlayAlbum: widget.onPlayAlbum,
                              onQueueAdd: widget.onQueueAdd,
                              onAlbumQueueAdd: widget.onAlbumQueueAdd,
                            ),
                          )),
                        ),
                    ],
                  ],
                ),
    );
  }
}

// ── Écran 3: le palmarès lui-même ──────────────────────────────────────────

class ChartResultsScreen extends StatefulWidget {
  final String title;
  final ChartMode mode;
  /// null = tout le catalogue (les lignes montrent alors leur collection).
  final String? collectionSlug;
  /// Source de REMPLACEMENT (mode songs seulement): la carte « … » d'un rail
  /// de l'accueil pousse cet écran avec LA MÊME source que le rail, plafond
  /// plus haut — le palmarès rating par défaut ne correspondrait pas à ce que
  /// le rail montrait.
  final Future<List<SearchResult>> Function()? fetchSongs;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnPlayAlbum? onPlayAlbum;
  final OnQueueAdd? onQueueAdd;
  final OnAlbumQueueAdd? onAlbumQueueAdd;

  const ChartResultsScreen({
    super.key,
    required this.title,
    required this.mode,
    this.collectionSlug,
    this.fetchSongs,
    required this.onTap,
    this.onPlayAlbum,
    this.onQueueAdd,
    this.onAlbumQueueAdd,
  });

  @override
  State<ChartResultsScreen> createState() => _ChartResultsScreenState();
}

class _ChartResultsScreenState extends State<ChartResultsScreen> {
  List<SearchResult>? _songs;
  List<PopularAlbum>? _albums;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.mode == ChartMode.songs) {
        if (widget.fetchSongs != null) {
          final rows = await widget.fetchSongs!();
          if (mounted) setState(() => _songs = rows);
          return;
        }
        // Mode RATING, période all-time: un chart dit « les meilleurs », pas
        // « les plus joués cette semaine » — l'accueil a déjà ces rails-là.
        final rows = await RewampDb.mostPopularSongs(
            period: 'all', n: 100, sortBy: 'rating',
            collectionSlug: widget.collectionSlug);
        if (mounted) setState(() => _songs = rows);
      } else {
        // ⚠️ Pas de mode rating côté albums: `most_popular_albums` n'a pas de
        // `sort_by` (signature vérifiée sur le serveur) — c'est un palmarès au
        // volume d'écoutes.
        final rows = await RewampDb.mostPopularAlbums(
            period: 'all', n: 100, collectionSlug: widget.collectionSlug);
        if (mounted) setState(() => _albums = rows);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Widget _rank(BuildContext context, int pos) => SizedBox(
        width: 34,
        child: Center(
          child: Text(chartRankLabel(pos),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );

  /// Les lignes JOUABLES du palmarès: une ligne album (mig 107) route vers
  /// son écran, elle n'est pas un morceau — même règle que la recherche.
  List<SearchResult> get _playable => [
        for (final r in _songs ?? const <SearchResult>[])
          if (!r.isAlbumRow) r,
      ];

  void _playRows(List<SearchResult> rows) {
    if (rows.isEmpty) return;
    (widget.onPlayAlbum ?? globalOnPlayAlbum)?.call(context, rows);
  }

  /// Les lignes d'ALBUM du palmarès de morceaux. ⚠️ Sur une collection dont
  /// les écoutes s'agrègent au niveau de l'archive (vgmrips, snesmusic,
  /// smspower, joshw), `most_popular_songs` ne rend QUE des lignes
  /// `item_type='album'` (mig 107): filtrer les lignes jouables laissait alors
  /// une liste VIDE — le bouton « Tout lire » DISPARAISSAIT (il n'est rendu
  /// que si son rappel est non nul) et Radio/Surprise sortaient grisés. Un
  /// palmarès n'est jamais vide de sens: ces lignes se déplient comme sur le
  /// palmarès d'albums.
  List<SearchResult> get _albumRows => [
        for (final r in _songs ?? const <SearchResult>[])
          if (r.isAlbumRow) r,
      ];

  /// « Tout lire » d'une liste MIXTE: une ligne jouable part telle quelle, une
  /// ligne d'album est dépliée par `browse` (mêmes plafonds et même règle que
  /// [_playAlbumsChained] — 20 albums, 2000 pistes, lots de 5, un album
  /// CONTENEUR gardé comme UNE entrée).
  Future<void> _playSongRowsChained(List<SearchResult> rows) async {
    final all = <SearchResult>[];
    final albums = <SearchResult>[];
    for (final r in rows) {
      if (r.isAlbumRow) {
        if (albums.length < 20) albums.add(r);
      } else {
        all.add(r);
      }
    }
    for (var i = 0; i < albums.length && all.length < 2000; i += 5) {
      final chunk = albums.sublist(i, min(i + 5, albums.length));
      final lists = await Future.wait([
        for (final a in chunk)
          RewampDb.browse(
            albumName: _albumNameOf(a),
            collection: a.collection,
            platform: a.platform,
            sortBy: 'position',
            limit: 500,
          ).catchError((_) => const <SearchResult>[]),
      ]);
      for (final l in lists) {
        all.addAll(l);
      }
    }
    if (all.isEmpty || !mounted) return;
    (widget.onPlayAlbum ?? globalOnPlayAlbum)
        ?.call(context, all.take(2000).toList());
  }

  static String _albumNameOf(SearchResult r) =>
      (r.album != null && r.album!.isNotEmpty) ? r.album! : r.displayTitle;

  /// Surprise sur une liste mixte: une ligne jouable se joue seule, une ligne
  /// d'album passe par `playAlbumFromList` (qui, lui, sait gérer un conteneur
  /// — un seul album à télécharger).
  void _surpriseSongRow(List<SearchResult> rows) {
    final r = rows[Random().nextInt(rows.length)];
    if (!r.isAlbumRow) {
      _playRows([r]);
      return;
    }
    final play = widget.onPlayAlbum ?? globalOnPlayAlbum;
    if (play == null) return;
    playAlbumFromList(context, _albumNameOf(r),
        collection: r.collection, platform: r.platform, onPlayAlbum: play);
  }

  /// « Tout lire » d'un palmarès d'ALBUMS: les pistes de chaque album dans
  /// l'ordre reçu, plafonné — 20 albums, 2000 pistes (kQueueLimit), fetch par
  /// lots de 5.
  ///
  /// ⚠️ Un album CONTENEUR (une seule ligne multi-sous-chansons, ou l'archive
  /// d'un album joshw sans détail serveur) est GARDÉ TEL QUEL, comme UNE
  /// entrée. Ce qu'on évite ici est de le DÉPLIER — `expandContainerAlbum`
  /// télécharge et sonde le fichier, soit vingt téléchargements pour un bouton
  /// « lire » — pas de le perdre: jeté, il faisait démarrer la lecture à
  /// l'album SUIVANT. `_startAlbumQueue` extrait les archives et diffère
  /// l'expansion jusqu'à ce que l'entrée soit atteinte. La surprise, elle,
  /// passe par playAlbumFromList, qui déplie pour de bon (un seul album).
  Future<void> _playAlbumsChained(List<PopularAlbum> albums) async {
    final take = albums.take(20).toList();
    final all = <SearchResult>[];
    for (var i = 0; i < take.length && all.length < 2000; i += 5) {
      final chunk = take.sublist(i, min(i + 5, take.length));
      final lists = await Future.wait([
        for (final a in chunk)
          RewampDb.browse(
            albumName: a.name,
            collection: a.collection,
            platform: a.platform,
            sortBy: 'position',
            limit: 500,
          ).catchError((_) => const <SearchResult>[]),
      ]);
      for (final l in lists) {
        all.addAll(l);
      }
    }
    if (all.isEmpty || !mounted) return;
    (widget.onPlayAlbum ?? globalOnPlayAlbum)
        ?.call(context, all.take(2000).toList());
  }

  void _surpriseAlbum(List<PopularAlbum> albums) {
    final a = albums[Random().nextInt(albums.length)];
    final play = widget.onPlayAlbum ?? globalOnPlayAlbum;
    if (play == null) return;
    playAlbumFromList(context, a.name,
        collection: a.collection, platform: a.platform, onPlayAlbum: play);
  }

  /// La même rangée pour la liste d'ALBUMS — radio = les albums enchaînés en
  /// ordre MÉLANGÉ, surprise = un album au hasard (entier, conteneurs
  /// compris).
  Widget _albumActionsRow(BuildContext context) {
    final l10n = context.l10n;
    final albums = _albums ?? const <PopularAlbum>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(children: [
        Expanded(
          child: Text(
            l10n.searchAlbumsCount(albums.length),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        RadioSurpriseButtons(
          onPlayAll:
              albums.isEmpty ? null : () => _playAlbumsChained(albums),
          onRadio: albums.isEmpty
              ? null
              : () =>
                  _playAlbumsChained(List.of(albums)..shuffle(Random())),
          onSurprise: albums.isEmpty ? null : () => _surpriseAlbum(albums),
        ),
      ]),
    );
  }

  /// Compteur + « Tout lire » / Radio / Surprise — la même rangée que les
  /// autres écrans de résultats (onglet Local, recherche). Radio = la MÊME
  /// liste mélangée (un palmarès n'est pas une station serveur), surprise =
  /// un morceau au hasard.
  Widget _actionsRow(BuildContext context) {
    final l10n = context.l10n;
    // Les lignes jouables D'ABORD, puis les lignes d'album: la même famille
    // « Tout lire / Radio / Surprise » que partout ailleurs, et elle n'est
    // grisée que sur un palmarès réellement vide.
    final all = [..._playable, ..._albumRows];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(children: [
        Expanded(
          child: Text(
            l10n.albumTrackCount(_songs?.length ?? 0),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        RadioSurpriseButtons(
          onPlayAll: all.isEmpty ? null : () => _playSongRowsChained(all),
          onRadio: all.isEmpty
              ? null
              : () => _playSongRowsChained(List.of(all)..shuffle(Random())),
          onSurprise: all.isEmpty ? null : () => _surpriseSongRow(all),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final loading = _error == null && _songs == null && _albums == null;
    final empty = (_songs?.isEmpty ?? false) || (_albums?.isEmpty ?? false);
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.title,
              maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: cs.error)))
          : loading
              ? const Center(child: CircularProgressIndicator())
              : empty
                  ? Center(child: Text(l10n.searchNoResults,
                      style: TextStyle(color: cs.outline)))
                  : Column(children: [
                      if (_songs != null) _actionsRow(context),
                      if (_albums != null) _albumActionsRow(context),
                      Expanded(child: ListView.builder(
                      padding: shellInset(context, EdgeInsets.zero),
                      itemCount: _songs?.length ?? _albums!.length,
                      itemBuilder: (ctx, i) {
                        if (_songs != null) {
                          return Row(children: [
                            _rank(ctx, i + 1),
                            Expanded(
                              child: SongTile(
                                result: _songs![i],
                                onTap: widget.onTap,
                                onPlayAlbum: widget.onPlayAlbum,
                                albumRowsAllowed: false,
                                showCollection:
                                    widget.collectionSlug == null,
                              ),
                            ),
                          ]);
                        }
                        final a = _albums![i];
                        return Row(children: [
                          _rank(ctx, i + 1),
                          Expanded(
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.only(left: 0, right: 16),
                              leading: RailArtwork(
                                url: a.artworkUrl,
                                album: a.name,
                                platformName: a.platform,
                                size: 44,
                              ),
                              title: ScrollingText(text: a.name),
                              subtitle: Text(
                                [
                                  if (a.platform != null &&
                                      a.platform!.isNotEmpty)
                                    a.platform!,
                                  if (widget.collectionSlug == null)
                                    RewampDb.collectionLabel(a.collection),
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(ctx).push(
                                MaterialPageRoute(
                                  builder: (_) => AlbumDetailScreen(
                                    albumName: a.name,
                                    albumId: a.albumId,
                                    collectionSlug: a.collection,
                                    platformName: a.platform,
                                    artworkUrl: a.artworkUrl,
                                    onTap: widget.onTap,
                                    onPlayAlbum: widget.onPlayAlbum,
                                    onQueueAdd: widget.onQueueAdd,
                                    onAlbumQueueAdd: widget.onAlbumQueueAdd,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ]);
                      },
                    )),
                    ]),
    );
  }
}

// ── Une playlist de classement, au bon GRAIN ───────────────────────────────

/// Affiche un classement au grain que la playlist DÉCLARE (`ChartPlaylist
/// .grain`, porté par `list_charts` et par la clé `charts` du hub):
///
///  - **'album'** (vgmrips, snesmusic — des packs): `get_chart_albums`, ~100
///    lignes dans l'ordre du rang, au lieu des 2364 pistes de la playlist —
///    en liste de pistes, le rang n° 1 occupait un écran entier. Un album
///    présent plusieurs fois garde son MEILLEUR rang (dédoublonnage serveur).
///  - **'song'** (hvsc) ou serveur antérieur (grain nul): l'écran de playlist
///    existant, qui sait déjà tout (rangs compris, par `meta.rank`).
///
/// Le grain a d'abord été DEVINÉ ici en groupant la première page de pistes —
/// remplacé par la déclaration serveur: le client sait comment présenter
/// AVANT de charger quoi que ce soit, et la lecture reste la playlist telle
/// quelle (toutes les pistes y sont, dans l'ordre du classement).
class ChartPlaylistScreen extends StatefulWidget {
  final ChartPlaylist chart;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnPlayAlbum? onPlayAlbum;
  final OnQueueAdd? onQueueAdd;
  final OnAlbumQueueAdd? onAlbumQueueAdd;

  const ChartPlaylistScreen({
    super.key,
    required this.chart,
    required this.onTap,
    this.onPlayAlbum,
    this.onQueueAdd,
    this.onAlbumQueueAdd,
  });

  @override
  State<ChartPlaylistScreen> createState() => _ChartPlaylistScreenState();
}

class _ChartPlaylistScreenState extends State<ChartPlaylistScreen> {
  List<(int, ArtistAlbum)>? _albums; // grain album, ordre du rang
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.chart.albumGrain) _load();
  }

  Future<void> _load() async {
    try {
      final rows = await RewampDb.chartAlbums(widget.chart.id);
      if (mounted) setState(() => _albums = rows);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    if (!widget.chart.albumGrain) {
      // Grain PISTE: l'écran de playlist existant fait tout.
      return PlaylistTracksScreen(
        playlist: Playlist(
          id: widget.chart.id,
          slug: widget.chart.slug,
          name: widget.chart.name,
          description: widget.chart.description,
          coverUrl: widget.chart.coverUrl,
          trackCount: widget.chart.trackCount,
        ),
        // Pas de `note`: elle doublait la description — l'en-tête aurait
        // affiché deux fois le même texte (« Lala's HVSC Top 100 SIDs »,
        // constaté). La note est pour un texte DIFFÉRENT (le « pourquoi » du
        // rail featured), pas pour répéter ce que la playlist dit déjà.
        onTap: widget.onTap,
        onPlayAlbum: widget.onPlayAlbum,
      );
    }
    final albums = _albums;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.chart.name,
              maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: cs.error)))
          : albums == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: shellInset(context, EdgeInsets.zero),
                  itemCount: albums.length,
                  itemBuilder: (ctx, i) {
                    final (rank, a) = albums[i];
                    return Row(children: [
                      SizedBox(
                        width: 34,
                        child: Center(
                          child: Text(chartRankLabel(rank),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurfaceVariant)),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.only(left: 0, right: 8),
                          leading: RailArtwork(
                            url: a.artworkUrl,
                            album: a.name,
                            artist: a.artistNames.firstOrNull,
                            platformName: a.platform,
                            size: 44,
                          ),
                          title: ScrollingText(text: a.name),
                          subtitle: Text(
                            [
                              if (a.artistNames.isNotEmpty)
                                a.artistNames.join(' & '),
                              if (a.platform != null && a.platform!.isNotEmpty)
                                a.platform!,
                              l10n.playlistTrackCount(a.songCount),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.onPlayAlbum != null)
                                IconButton(
                                  icon: const Icon(Icons.play_circle_outline,
                                      size: 22),
                                  tooltip: l10n.albumPlayAlbum,
                                  // Même chemin que le navigateur d'albums
                                  // (gère les albums zip-only: RSN, smspower).
                                  onPressed: () => playAlbumFromList(
                                    ctx,
                                    a.name,
                                    collection: a.collection,
                                    platform: a.platform,
                                    onPlayAlbum: widget.onPlayAlbum!,
                                  ),
                                ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () => Navigator.of(ctx).push(
                            MaterialPageRoute(
                              builder: (_) => AlbumDetailScreen(
                                albumName: a.name,
                                albumId: a.albumId,
                                collectionSlug: a.collection,
                                platformName: a.platform,
                                artworkUrl: a.artworkUrl,
                                onTap: widget.onTap,
                                onPlayAlbum: widget.onPlayAlbum,
                                onQueueAdd: widget.onQueueAdd,
                                onAlbumQueueAdd: widget.onAlbumQueueAdd,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]);
                  },
                ),
    );
  }
}
