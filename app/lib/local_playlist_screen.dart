import 'package:flutter/material.dart';

import 'app_snack.dart';
import 'artwork_image.dart';
import 'download_cancel.dart';
import 'l10n.dart';
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
  bool _loading = true;
  /// The playlist as it is NOW. widget.playlist is the caller's snapshot: after
  /// a rename or a first backup made from this screen's own menu it is stale,
  /// and the title would keep showing the old name until the screen is left.
  UserPlaylist? _live;

  UserPlaylist get _playlist => _live ?? widget.playlist;

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
    final choice = await showPlayChoiceSheet(context, title: row.displayTitle);
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
    LocalDb.instance.getPlaylistEntryRefs(widget.playlist.id).then((e) {
      if (mounted) setState(() { _entries = e; _loading = false; });
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
                      // Same menu as the library list (rename, back up,
                      // publish, …): having to walk back up to the list to
                      // rename the playlist you are looking at made no sense.
                      IconButton(
                        icon: const Icon(Icons.more_horiz),
                        tooltip: l10n.commonOptions,
                        onPressed: _options,
                      ),
                    ]),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: _entries.length,
                      // onReorderItem (vs deprecated onReorder) already gives a
                      // newIndex adjusted for the removed item.
                      onReorderItem: (oldIndex, newIndex) async {
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
                      itemBuilder: (_, i) {
                        final e = _entries[i];
                        final t = e.track;
                        final missing = e.isMissing;
                        return ListTile(
                          key: ValueKey(e.rowId),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text('${i + 1}',
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
                            opacity: missing ? 0.5 : 1,
                            child: ScrollingText(text: e.displayTitle),
                          ),
                          subtitle: missing
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    size: 20),
                                tooltip: l10n.playlistRemoveEntry,
                                onPressed: () async {
                                  await LocalDb.instance.removePlaylistEntry(
                                      widget.playlist.id, e.rowId);
                                  await PlaylistSync.pushIfLinked(
                                      widget.playlist.id);
                                },
                              ),
                              // Drag handle: reorder the entry (persists the new
                              // order to playlist_tracks.position).
                              ReorderableDragStartListener(
                                index: i,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(Icons.drag_handle, size: 20),
                                ),
                              ),
                            ],
                          ),
                          // Tap = whole playlist queued, positioned here.
                          onTap: () {
                            // A missing entry with no catalogue id is the only
                            // dead end left; a restorable one is queued like
                            // any other and downloads when its turn comes.
                            if (missing && !e.isRestorable) {
                              AppSnack.show(context, l10n.playlistEntryMissing);
                              return;
                            }
                            if (widget.onPlayLocalAlbum == null) {
                              // No queue owner (shouldn't happen from the
                              // library): fall back to the single-entry fetch.
                              if (missing) _playMissing(e);
                              return;
                            }
                            widget.onPlayLocalAlbum!(context, _queueTracks,
                                startIndex: _playIndexOf(i));
                          },
                        );
                      },
                    ),
                  ),
                ]),
    );
  }
}
