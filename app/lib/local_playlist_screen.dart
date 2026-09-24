import 'package:flutter/material.dart';

import 'app_snack.dart';
import 'artwork_image.dart';
import 'download_cancel.dart';
import 'l10n.dart';
import 'library_presence.dart';
import 'library_toolbar.dart' show ListFilterField, kListFilterThreshold,
    matchesFilterQuery;
import 'local_db.dart';
import 'playlist_options.dart';
import 'playlist_sync.dart';
import 'rewamp_db.dart' show OnPlayLocalAlbum, RewampDb, SearchResult;
import 'scrolling_text.dart';
import 'track_options_sheet.dart'
    show showPlayChoiceSheet, PlayChoice, globalOnQueueAdd, globalOnPlayNowSong;

/// Tracks of one user playlist: play-all header + positioned start on tap,
/// per-row removal.
///
/// An entry whose file is not here right now (download deleted, folder moved,
/// file not copied to this device yet) STAYS in the list, greyed out: the
/// playlist is the user's work, the file is only its material. Playback skips
/// it, and it rebinds by itself once the file is back (see
/// [LocalDb.getPlaylistEntryRefs]).
class LocalPlaylistScreen extends StatefulWidget {
  final UserPlaylist playlist;
  final OnPlayLocalAlbum? onPlayLocalAlbum;
  /// Download-and-play path for an entry the catalogue can supply. Without it a
  /// playlist restored on a fresh device is entirely unplayable — every entry
  /// is "missing" there until its file is fetched.
  final Future<void> Function(BuildContext, SearchResult)? onPlayOnline;

  const LocalPlaylistScreen(
      {super.key, required this.playlist, this.onPlayLocalAlbum,
       this.onPlayOnline});

  @override
  State<LocalPlaylistScreen> createState() => _LocalPlaylistScreenState();
}

class _LocalPlaylistScreenState extends State<LocalPlaylistScreen> {
  List<PlaylistEntry> _entries = [];
  /// Fichiers locaux absents d'ICI (entrée connue de la base, fichier sur un
  /// autre appareil) — voir library_presence. Distinct de `isMissing`, qui
  /// est une entrée sans LIGNE.
  Set<String> _elsewhere = const {};
  bool _loading = true;
  /// The playlist as it is NOW. widget.playlist is the caller's snapshot: after
  /// a rename or a first backup made from this screen's own menu it is stale,
  /// and the title would keep showing the old name until the screen is left.
  UserPlaylist? _live;

  UserPlaylist get _playlist => _live ?? widget.playlist;

  /// Mode ÉDITION: les lignes prennent une case à cocher, le tap sélectionne au
  /// lieu de jouer, et le bandeau propose de retirer le lot. Même modèle que le
  /// panneau de file — retirer UNE entrée est un glissement, en retirer
  /// plusieurs demande un mode, sinon c'est N glissements sans annulation.
  bool _editing = false;
  String _query = '';
  /// Des ROW IDS, jamais des positions: un réordonnancement ou un retrait
  /// renumérote les lignes et une sélection tenue par index désignerait
  /// aussitôt d'autres entrées.
  final _selected = <int>{};

  void _setEditing(bool on) => setState(() {
        _editing = on;
        _selected.clear();
      });

  Future<void> _removeEntries(Set<int> rowIds) async {
    if (rowIds.isEmpty) return;
    await LocalDb.instance
        .removePlaylistEntries(widget.playlist.id, rowIds);
    // L'ordre fait partie de la playlist: une playlist sauvegardée ne doit pas
    // dériver de sa copie de compte.
    await PlaylistSync.pushIfLinked(widget.playlist.id);
  }

  Future<void> _removeSelected() async {
    if (_selected.isEmpty) return;
    // Copie: le retrait relit la liste, et le set est vidé en sortant du mode.
    final go = Set<int>.of(_selected);
    _setEditing(false);
    await _removeEntries(go);
  }

  /// What actually gets QUEUED: every entry that can play, including the ones
  /// whose file is not on this device yet.
  ///
  /// Queueing only the downloaded ones (what this screen used to hand over)
  /// made a 6-entry playlist with 3 files on disk read "1/3", and the three
  /// others were never fetched — the queue had never heard of them. A
  /// restorable entry becomes a synthetic row carrying its catalogue id, and
  /// the queue's own play path re-downloads on a missing file that has one
  /// (`_playAt`'s `_LocalItem` branch in app_shell). Only an entry with
  /// nothing to resolve — a file of the user's own, gone from this device — is
  /// left out: no id, no download, it would just fail at its turn.
  List<TrackRecord> get _queueTracks => [
        for (final e in _entries)
          if (e.track case final t?)
            t
          else if (e.isRestorable)
            _syntheticTrack(e),
      ];

  /// A queue row for an entry that has no local file. It is deliberately NOT
  /// written to the database: `PlaylistEntry.isMissing` is "no track row", so
  /// persisting one would make the entry look present while its file is still
  /// absent — greyed rows would un-grey and the "fetch missing" batch would
  /// find nothing to do. Queue persistence already handles rows with no DB id
  /// (it falls back to the serialized record on restore).
  TrackRecord _syntheticTrack(PlaylistEntry e) => TrackRecord(
        id:         'playlist-entry:${e.rowId}',
        filePath:   e.filePath ?? e.relPath ?? e.displayTitle,
        entryPath:  e.entryPath,
        subsongIdx: e.subsongIdx,
        title:      e.title,
        artist:     e.artist,
        metaAlbum:  e.album,
        // Since migration 38 the entry carries it, so a queued-but-not-yet
        // downloaded track reaches the player with its album already known.
        albumId:    e.albumId,
        durationS:  e.durationS,
        formatExt:  e.formatExt,
        source:     'online',
        onlineId:   e.songId,
        isFavorite: false,
        inLibrary:  false,
        playCount:  0,
      );

  int get _missingCount => _entries.where((e) => e.isMissing).length;

  /// Missing entries the catalogue can supply again (they carry a song_id).
  List<PlaylistEntry> get _restorable =>
      [for (final e in _entries) if (e.isRestorable) e];

  bool _fetching = false;
  int _fetchDone = 0;
  /// Captured when the batch starts: entries leave [_restorable] as they bind,
  /// so using its live length would make the denominator shrink as we go.
  int _fetchTotal = 0;

  /// Resolves an entry's catalogue row (the snapshot has no download url —
  /// only the song id travels between devices).
  Future<SearchResult?> _resolveOnline(PlaylistEntry e) async {
    final id = e.songId;
    if (id == null || id.isEmpty) return null;
    final ctx = await RewampDb.getSongContext(id);
    return ctx?.song;
  }

  /// Re-resolves one entry and refreshes its row in place (no full reload: the
  /// list must not be rebuilt under the user while a batch is running).
  Future<void> _bindNow(PlaylistEntry e) async {
    final t = await LocalDb.instance.findTrackForSnapshot(
      songId:     e.songId,
      filePath:   e.filePath,
      relPath:    e.relPath,
      entryPath:  e.entryPath,
      subsongIdx: e.subsongIdx,
    );
    if (t == null || !mounted) return;
    await LocalDb.instance.bindPlaylistEntry(e.rowId, t);
    if (!mounted) return;
    final i = _entries.indexWhere((x) => x.rowId == e.rowId);
    if (i >= 0) setState(() => _entries[i] = _entries[i].withTrack(t));
  }

  Future<void> _playMissing(PlaylistEntry e) async {
    final l10n = context.l10n;
    if (widget.onPlayOnline == null) {
      AppSnack.show(context, l10n.playlistEntryMissing);
      return;
    }
    final row = await _resolveOnline(e);
    if (!mounted) return;
    if (row == null) {
      AppSnack.show(context, l10n.playlistEntryFetchFailed);
      return;
    }
    // Un tap qui ÉCRASERAIT la file demande d'abord, comme partout ailleurs;
    // la popup répond `now` sans s'afficher quand rien ne joue.
    final choice =
        await showPlayChoiceSheet(context, title: row.displayTitle, result: row);
    if (choice == null || !mounted) return;
    if (choice != PlayChoice.now) {
      await globalOnQueueAdd?.call(row, atEnd: choice == PlayChoice.end);
      return;
    }
    // REMPLACE la file — voir song_tile; le repli garde l'ancien chemin.
    final playNow = globalOnPlayNowSong;
    if (playNow != null) {
      await playNow(row);
    } else {
      await widget.onPlayOnline!(context, row);
    }
    // The download created a local row: re-resolve so the entry stops showing
    // as missing without waiting for the next visit.
    await _bindNow(e);
  }

  /// Downloads every restorable entry so the playlist becomes playable offline
  /// — the one gesture that makes a playlist restored on a new device usable.
  Future<void> _fetchAllMissing() async {
    final l10n = context.l10n;
    final todo = _restorable;
    if (todo.isEmpty) return;
    setState(() { _fetching = true; _fetchDone = 0; _fetchTotal = todo.length; });
    var failed = 0;
    for (final e in todo) {
      try {
        final row = await _resolveOnline(e);
        if (row == null) { failed++; continue; }
        final path = await RewampDb.downloadToLibrary(row);
        // Downloading only puts the file on disk. Entry resolution goes through
        // the `tracks` table, so without this row the entry would still show as
        // missing right after a successful download.
        await LocalDb.instance.upsertTrack(
          filePath:   path,
          subsongIdx: e.subsongIdx,
          // Le titre de l'ENTRÉE d'abord, celui du catalogue ensuite: `row`
          // est la ligne du CONTENEUR, dont le titre est le nom du fichier
          // (« Monkey Island »), alors que l'entrée porte son nom numéroté
          // (« monkey island (7) »). Dans l'autre sens, « Télécharger tout »
          // renommait les 21 entrées d'un module avec le seul nom du
          // conteneur.
          title:      e.title ?? row.title,
          artist:     row.artistNames.isEmpty ? e.artist : row.artistNames.first,
          metaAlbum:  row.album ?? e.album,
          durationS:  row.durationMs == null
              ? e.durationS
              : row.durationMs! / 1000.0,
          formatExt:  row.formatExt,
          source:     'online',
          onlineId:   row.songId,
          albumId:    row.albumId,
          collectionSlug: row.collection,
          platformName:   row.platform,
          artworkUrl: row.artworkUrl,
        );
        // Un-grey THIS row now: waiting for the end of the batch made a long
        // download look like nothing was happening.
        await _bindNow(e);
      } on DownloadCancelledException {
        // Cancel means « stop », not « skip this one »: continuing would start
        // the next download immediately.
        break;
      } catch (_) {
        failed++;
      }
      if (!mounted) return;
      setState(() => _fetchDone++);
    }
    if (!mounted) return;
    setState(() => _fetching = false);
    _reload();
    AppSnack.show(context,
        failed > 0 ? l10n.playlistFetchPartial : l10n.playlistFetchDone);
  }

  /// Les indices, dans [_entries], des lignes que la liste MONTRE.
  ///
  /// ⚠️ **Le filtre sert à TROUVER, pas à redéfinir la playlist.** Tout ce qui
  /// suit raisonne donc sur l'index de la liste COMPLÈTE: le numéro affiché,
  /// la position de lecture ([_playIndexOf]) et le réordonnancement. Passer
  /// l'index de la liste filtrée démarrerait un autre morceau — ou pire,
  /// déplacerait une autre ligne.
  List<int> get _visibleIdx => [
        for (var i = 0; i < _entries.length; i++)
          if (matchesFilterQuery(_query, [
            _entries[i].track?.displayTitle,
            _entries[i].track?.artist,
            _entries[i].track?.metaAlbum,
          ]))
            i,
      ];

  /// Index of [entryIndex] within [_queueTracks]. The two lists only drift
  /// apart on an entry that could not be queued at all (missing AND not
  /// restorable) — every other entry is there, downloaded or not.
  int _playIndexOf(int entryIndex) {
    var n = 0;
    for (var i = 0; i < entryIndex; i++) {
      final e = _entries[i];
      if (e.track != null || e.isRestorable) n++;
    }
    return n;
  }

  @override
  void initState() {
    super.initState();
    LocalDb.instance.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    LocalDb.instance.getPlaylistEntryRefs(widget.playlist.id).then((e) async {
      final gone = await missingLocalTrackFiles(
          [for (final x in e) if (x.track != null) x.track!]);
      if (!mounted) return;
      setState(() {
        _entries = e;
        _elsewhere = gone;
        _loading = false;
        // Une entrée retirée ailleurs (autre écran, synchro) ne doit pas rester
        // « sélectionnée »: le bouton de retrait paraîtrait armé pour rien.
        final live = {for (final x in e) x.rowId};
        _selected.removeWhere((id) => !live.contains(id));
      });
    });
    LocalDb.instance.playlistById(widget.playlist.id).then((p) {
      if (mounted && p != null) setState(() => _live = p);
    });
  }

  /// The playlist "…" menu — the same one the library list shows, so a rename
  /// or a backup is reachable from the playlist you are actually looking at.
  /// Deleting it here has to close the screen: what it lists is gone.
  Future<void> _options() => PlaylistOptions.show(
        context,
        playlist:  _playlist,
        onChanged: () async => _reload(),
        onDeleted: () => Navigator.of(context).maybePop(),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;
    final visible = _visibleIdx;
    return Scaffold(
      appBar: AppBar(
        title: Text(_playlist.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          // `_fetching` first: entries leave [_restorable] as they bind, and a
          // batch that empties it would take its own progress counter away.
          if (_fetching || _restorable.isNotEmpty)
            _fetching
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Text('$_fetchDone/$_fetchTotal',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.download_outlined),
                    tooltip: l10n.playlistFetchMissing,
                    onPressed: _fetchAllMissing,
                  ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Text(l10n.playlistEmpty,
                      style: TextStyle(color: cs.outline)))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    // Play-all left, the counts CENTRED, the "…" menu right.
                    // The counter sits in an Expanded rather than after a
                    // Spacer so it is centred on the ROW, not on what is left
                    // of it — otherwise a long "Play all" label in a declined
                    // language would push it off-centre.
                    child: Row(children: [
                      // En édition « tout lire » n'a pas sa place: le geste
                      // en cours porte sur une sélection, pas sur la lecture.
                      if (!_editing)
                        FilledButton.icon(
                          onPressed: (widget.onPlayLocalAlbum == null ||
                                  _queueTracks.isEmpty)
                              ? null
                              : () => widget.onPlayLocalAlbum!(
                                  context, _queueTracks),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(l10n.commonPlayAll),
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              l10n.playlistTrackCount(_entries.length),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                            if (_missingCount > 0)
                              Text(
                                l10n.playlistMissingCount(_missingCount),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    TextStyle(color: cs.error, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      if (_editing) ...[
                        // Même bascule que Stockage et le navigateur local:
                        // tout ce qui est AFFICHÉ coché ⇒ le bouton
                        // désélectionne (sans quitter l'édition), sinon il
                        // complète. Une seule icône pour ce geste dans l'app.
                        if (visible.isNotEmpty &&
                            visible.every((i) => _selected.contains(_entries[i].rowId)))
                          IconButton(
                            icon: const Icon(Icons.deselect),
                            tooltip: l10n.pmSelectNone,
                            onPressed: () => setState(_selected.clear),
                          )
                        else if (visible.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.select_all),
                            tooltip: l10n.storageSelectAll,
                            onPressed: () => setState(() => _selected
                                .addAll([for (final i in visible) _entries[i].rowId])),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: l10n.queueRemoveSelected,
                          onPressed:
                              _selected.isEmpty ? null : _removeSelected,
                        ),
                        IconButton(
                          icon: const Icon(Icons.done),
                          tooltip: l10n.queueEditDone,
                          onPressed: () => _setEditing(false),
                        ),
                      ] else ...[
                        IconButton(
                          icon: const Icon(Icons.checklist),
                          tooltip: l10n.queueEdit,
                          onPressed: () => _setEditing(true),
                        ),
                        // Same menu as the library list (rename, back up,
                        // publish, …): having to walk back up to the list to
                        // rename the playlist you are looking at made no sense.
                        IconButton(
                          icon: const Icon(Icons.more_horiz),
                          tooltip: l10n.commonOptions,
                          onPressed: _options,
                        ),
                      ],
                    ]),
                  ),
                  // Le filtre n'apparaît qu'au-delà du seuil: en dessous, l'œil
                  // va plus vite que le clavier.
                  if (_entries.length > kListFilterThreshold)
                    ListFilterField(
                      query: _query,
                      onQuery: (v) => setState(() => _query = v),
                    ),
                  Expanded(
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: visible.length,
                      // onReorderItem (vs deprecated onReorder) already gives a
                      // newIndex adjusted for the removed item.
                      onReorderItem: (oldIndex, newIndex) async {
                        // Inatteignable sous filtre: la poignée disparaît alors
                        // (voir plus bas), et sans poignée rien ne démarre un
                        // glissement — `buildDefaultDragHandles` est faux.
                        // Réordonner une liste filtrée déplacerait une AUTRE
                        // ligne, les index ne désignant plus la même chose.
                        setState(() {
                          final e = _entries.removeAt(oldIndex);
                          _entries.insert(newIndex, e);
                        });
                        await LocalDb.instance.setPlaylistEntryOrder(
                            widget.playlist.id,
                            [for (final e in _entries) e.rowId]);
                        // Order is part of the playlist: a backed-up playlist
                        // must not drift from its account copy.
                        await PlaylistSync.pushIfLinked(widget.playlist.id);
                      },
                      itemBuilder: (_, vi) {
                        final i = visible[vi];
                        final e = _entries[i];
                        final t = e.track;
                        final missing = e.isMissing;
                        final elsewhere =
                            t != null && _elsewhere.contains(t.filePath);
                        final selected = _selected.contains(e.rowId);
                        final tile = ListTile(
                          selected: selected,
                          selectedTileColor:
                              cs.primary.withValues(alpha: 0.10),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                // La case à cocher prend la place du numéro:
                                // elle répond à la même question (« quelle
                                // ligne est-ce ? ») et élargir la ligne
                                // décalerait la pochette.
                                width: 24,
                                child: _editing
                                    ? Checkbox(
                                        value: selected,
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        onChanged: (v) => setState(() =>
                                            v == true
                                                ? _selected.add(e.rowId)
                                                : _selected.remove(e.rowId)),
                                      )
                                    : Text('${i + 1}',
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                            color: cs.onSurfaceVariant)),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 40, height: 40,
                                child: missing
                                    ? DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: cs.surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Icon(Icons.music_off_outlined,
                                            size: 20, color: cs.outline),
                                      )
                                    : ArtworkImage(
                                        url:           t!.artworkUrl,
                                        localFilePath: t.filePath,
                                        // Placeholder thématisé comme partout:
                                        // un `placeholder:` explicite
                                        // l'écrasait. Pas de platformName ici,
                                        // `tracks` ne la stocke pas — le
                                        // format suffit à choisir la teinte.
                                        formatHint:    t.formatExt,
                                        size:          40,
                                        borderRadius:  BorderRadius.circular(6),
                                      ),
                              ),
                            ],
                          ),
                          title: Opacity(
                            opacity: (missing || elsewhere) ? 0.5 : 1,
                            child: ScrollingText(text: e.displayTitle),
                          ),
                          subtitle: elsewhere
                              ? Text(libraryElsewhereLabel(context),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: cs.onSurfaceVariant))
                              : missing
                              ? Text(
                                  e.isRestorable
                                      ? l10n.playlistEntryMissingRestorable
                                      : l10n.playlistEntryMissing,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: cs.error),
                                )
                              : (e.displayArtist != null
                                  ? Text(e.displayArtist!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)
                                  : null),
                          // Retirer une entrée est un GLISSEMENT (voir le
                          // Dismissible plus bas) ou la sélection multiple du
                          // mode édition — plus de bouton par ligne: il
                          // doublait le geste et volait la largeur du titre.
                          // Drag handle: reorder the entry (persists the new
                          // order to playlist_tracks.position).
                          // Pas de poignée sous filtre: l'index d'un
                          // glissement serait celui de la liste VISIBLE et
                          // déplacerait une autre ligne.
                          trailing: _query.isNotEmpty
                              ? null
                              : ReorderableDragStartListener(
                                  index: vi,
                                  child: const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(Icons.drag_handle, size: 20),
                                  ),
                                ),
                          // Tap = whole playlist queued, positioned here.
                          // En édition, le tap SÉLECTIONNE: viser une case de
                          // 24 px alors que toute la ligne dit « ceci » est un
                          // geste inutilement précis.
                          onTap: _editing
                              ? () => setState(() => selected
                                  ? _selected.remove(e.rowId)
                                  : _selected.add(e.rowId))
                              : () {
                                  // A missing entry with no catalogue id is the
                                  // only dead end left; a restorable one is
                                  // queued like any other and downloads when
                                  // its turn comes.
                                  if (elsewhere) {
                                    AppSnack.show(context,
                                        libraryElsewhereLabel(context));
                                    return;
                                  }
                                  if (missing && !e.isRestorable) {
                                    AppSnack.show(
                                        context, l10n.playlistEntryMissing);
                                    return;
                                  }
                                  if (widget.onPlayLocalAlbum == null) {
                                    // No queue owner (shouldn't happen from the
                                    // library): fall back to the single-entry
                                    // fetch.
                                    if (missing) _playMissing(e);
                                    return;
                                  }
                                  widget.onPlayLocalAlbum!(
                                      context, _queueTracks,
                                      startIndex: _playIndexOf(i));
                                },
                        );

                        // Clé sur l'ENTRÉE (rowId), jamais sur la position:
                        // c'est ce qui permet au réordonnancement et au
                        // Dismissible de survivre à la renumérotation.
                        final key = ValueKey(e.rowId);
                        if (_editing) {
                          // En édition le glissement se battrait avec la
                          // sélection pour le même geste.
                          return KeyedSubtree(key: key, child: tile);
                        }
                        return Dismissible(
                          key: key,
                          direction: DismissDirection.endToStart,
                          // Volontairement au-delà de la moitié: une entrée est
                          // à un revers de doigt de disparaître et il n'y a pas
                          // d'annulation, donc le geste doit être VOULU.
                          dismissThresholds: const {
                            DismissDirection.endToStart: 0.5
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: cs.errorContainer,
                            child: Icon(Icons.delete_outline,
                                color: cs.onErrorContainer),
                          ),
                          onDismissed: (_) => _removeEntries({e.rowId}),
                          child: tile,
                        );
                      },
                    ),
                  ),
                ]),
    );
  }
}
