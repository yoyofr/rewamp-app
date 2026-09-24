import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'app_snack.dart';

import 'l10n.dart';
import 'local_db.dart';
import 'playlist_sync.dart';
import 'scrolling_text.dart';
import 'cancel_field.dart';
import 'rewamp_db.dart' show RewampDb, SearchResult;

/// "Ajouter à la playlist" — overlay sheet listing the playlist tree with a
/// search filter, multi-select, and creation of new playlists/folders ('+').
/// [resolveTracks] is called ON CONFIRM and must return the tracks-table ids
/// to append (an album/multi-subsong source returns every track; a single
/// track returns just itself). Tracks are always appended at the END of each
/// selected playlist; duplicates are skipped.
Future<void> showAddToPlaylistSheet(
  BuildContext context, {
  required Future<List<String>> Function() resolveTrackIds,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PlaylistPickerSheet(resolveTrackIds: resolveTrackIds),
  );
}

/// Expands container rows (one file holding N subsongs) into per-subsong rows
/// — an album/multi-subsong source adds ALL its tracks to the playlist. Uses
/// the server tracklist when known, else probes the downloaded file.
Future<List<SearchResult>> expandForPlaylist(List<SearchResult> results) async {
  final out = <SearchResult>[];
  for (final r in results) {
    if (RewampDb.isContainerRow(r)) {
      if (r.subsongs.isNotEmpty) {
        out.addAll(RewampDb.subsongRowsFromServer(r));
        continue;
      }
      try {
        final lp = r.localPath ?? await RewampDb.localPath(r);
        if (await File(lp).exists()) {
          final subs = await RewampDb.probeContainerFile(lp);
          if (subs.length > 1) {
            out.addAll([
              for (final s in subs)
                r.withSubsong(s.subsongIdx,
                    title: s.title, durationMs: s.durationMs),
            ]);
            continue;
          }
        }
      } catch (_) {}
    }
    out.add(r);
  }
  return out;
}

/// Converts SearchResults (album rows, container subsongs, single tracks) into
/// tracks-table ids, minting rows for entries never played yet. The on-disk
/// path may not exist yet — the row still carries online_id/album_id so the
/// download machinery can resolve it on play.
Future<List<String>> trackIdsForResults(List<SearchResult> results) async {
  final ids = <String>[];
  for (final r in results) {
    final path = r.localPath ?? await RewampDb.localPath(r);
    final id = await LocalDb.instance.upsertTrack(
      filePath:   path,
      subsongIdx: r.subsongIdx,
      title:      r.matchSubsongTitle ?? r.displayTitle,
      artist:     r.artistLabel.isEmpty ? null : r.artistLabel,
      metaAlbum:  r.album,
      position:   r.trackPosition,
      durationS:  r.durationMs != null ? r.durationMs! / 1000.0 : null,
      formatExt:  r.formatExt,
      source:     'online',
      onlineId:   r.songId,
      albumId:    r.albumId,
      // L'origine voyage avec la ligne: sans elle, une piste ajoutée à une
      // playlist naissait avec un online_id et une collection nulle.
      collectionSlug: r.collection,
      platformName:   r.platform,
      artworkUrl: r.artworkUrl,
    );
    ids.add(id);
  }
  return ids;
}

/// Converts TrackRecords, minting rows for synthesized entries (id == '').
Future<List<String>> trackIdsForRecords(List<TrackRecord> tracks) async {
  final ids = <String>[];
  for (final t in tracks) {
    if (t.id.isNotEmpty) {
      ids.add(t.id);
      continue;
    }
    ids.add(await LocalDb.instance.upsertTrack(
      filePath:   t.filePath,
      entryPath:  t.entryPath,
      subsongIdx: t.subsongIdx,
      title:      t.title,
      artist:     t.artist,
      metaAlbum:  t.metaAlbum,
      durationS:  t.durationS,
      formatExt:  t.formatExt,
      source:     t.source,
      onlineId:   t.onlineId,
      albumId:    t.albumId,
      collectionSlug: t.collectionSlug,
      platformName:   t.platformName,
      artworkUrl: t.artworkUrl,
    ));
  }
  return ids;
}

class _PlaylistPickerSheet extends StatefulWidget {
  final Future<List<String>> Function() resolveTrackIds;
  const _PlaylistPickerSheet({required this.resolveTrackIds});

  @override
  State<_PlaylistPickerSheet> createState() => _PlaylistPickerSheetState();
}

class _PlaylistPickerSheetState extends State<_PlaylistPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _selected   = <String>{};          // playlist ids
  final _crumbs     = <PlaylistFolder>[];  // current folder path (empty = root)
  List<PlaylistFolder> _folders   = [];
  List<UserPlaylist>   _playlists = [];
  bool _busy = false;

  String? get _folderId => _crumbs.isEmpty ? null : _crumbs.last.id;
  bool get _searching => _searchCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    // While searching: flat, global (ignores the folder scope). Otherwise the
    // current folder's contents.
    final playlists = await LocalDb.instance.getPlaylistsFiltered(
      folderId: _folderId,
      scoped:   !_searching,
      query:    _searching ? _searchCtrl.text : null,
      orderBy:  'name',
    );
    final folders = _searching
        ? <PlaylistFolder>[]
        : await LocalDb.instance.getPlaylistFolders(parentId: _folderId);
    if (mounted) setState(() { _playlists = playlists; _folders = folders; });
  }

  Future<String?> _promptName(String title) => showDialog<String>(
        context: context,
        builder: (ctx) {
          final l10n = ctx.l10n;
          final ctrl = TextEditingController();
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              decoration:
                  InputDecoration(hintText: l10n.playlistNameHint),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.commonCancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                  child: Text(l10n.commonCreate)),
            ],
          );
        },
      );

  Future<void> _create() async {
    final l10n = context.l10n;
    final kind = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: Text(l10n.playlistNew),
            onTap: () => Navigator.pop(ctx, 'playlist'),
          ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text(l10n.playlistNewFolder),
            onTap: () => Navigator.pop(ctx, 'folder'),
          ),
        ]),
      ),
    );
    if (kind == null || !mounted) return;
    final name = await _promptName(
        kind == 'folder' ? l10n.playlistNewFolder : l10n.playlistNew);
    if (name == null || name.isEmpty) return;
    if (kind == 'folder') {
      await LocalDb.instance.createPlaylistFolder(name, parentId: _folderId);
    } else {
      final id =
          await LocalDb.instance.createPlaylist(name, folderId: _folderId);
      _selected.add(id); // creating from the picker = you want to add to it
    }
    await _reload();
  }

  Future<void> _confirm() async {
    if (_selected.isEmpty) return;
    setState(() => _busy = true);
    final l10n      = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final trackIds = await widget.resolveTrackIds();
      // Entries already present? Ask: add again (duplicates allowed) or skip.
      var skipDuplicates = false;
      final dupes = await LocalDb.instance
          .countTracksAlreadyInPlaylists(_selected.toList(), trackIds);
      if (dupes > 0 && mounted) {
        final choice = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.playlistDuplicatesTitle),
            content: Text(l10n.playlistDuplicatesBody(dupes)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cancel'),
                  child: Text(l10n.commonCancel)),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, 'skip'),
                  child: Text(l10n.playlistSkipDuplicates)),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, 'add'),
                  child: Text(l10n.playlistAddAgain)),
            ],
          ),
        );
        if (choice == null || choice == 'cancel') {
          if (mounted) setState(() => _busy = false);
          return;
        }
        skipDuplicates = choice == 'skip';
      }
      await LocalDb.instance.addTracksToPlaylists(
          _selected.toList(), trackIds, skipDuplicates: skipDuplicates);
      if (mounted) Navigator.pop(context);
      // Fire-and-forget: a backed-up playlist follows its local edits; a sync
      // failure must never turn into an error on an add that DID work.
      for (final id in _selected) {
        unawaited(PlaylistSync.pushIfLinked(id));
      }
    } catch (e) {
      AppSnack.showOn(messenger, l10n.playlistAddFailed(e.toString()));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(children: [
                Expanded(
                  child: Text(l10n.playlistAddTo,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: l10n.playlistNewTooltip,
                  onPressed: _create,
                ),
              ]),
            ),
            // Search filter.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CancelField(
                controller: _searchCtrl,
                onCleared: (_) => _reload(),
                builder: (_) => TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.playlistFilterHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => _reload(),
                ),
              ),
            ),
            // Breadcrumb (folder navigation).
            if (!_searching && _crumbs.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 18),
                      onPressed: () {
                        setState(() => _crumbs.removeLast());
                        _reload();
                      },
                    ),
                    Expanded(
                      child: Text(
                        _crumbs.map((f) => f.name).join(' / '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ]),
                ),
              ),
            Flexible(
              child: (_folders.isEmpty && _playlists.isEmpty)
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                          _searching
                              ? l10n.playlistNoMatch
                              : l10n.playlistNoneCreateHint,
                          style: TextStyle(color: cs.outline)),
                    )
                  : ListView(shrinkWrap: true, children: [
                      for (final f in _folders)
                        ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: ScrollingText(text: f.name),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            setState(() => _crumbs.add(f));
                            _reload();
                          },
                        ),
                      for (final p in _playlists)
                        CheckboxListTile(
                          secondary: const Icon(Icons.queue_music),
                          title: ScrollingText(text: p.name),
                          subtitle: Text(l10n.playlistTrackCount(p.trackCount)),
                          value: _selected.contains(p.id),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(p.id);
                            } else {
                              _selected.remove(p.id);
                            }
                          }),
                        ),
                    ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _selected.isEmpty || _busy ? null : _confirm,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.playlist_add_check),
                  label: Text(_selected.isEmpty
                      ? l10n.playlistSelectOne
                      : l10n.playlistAddToN(_selected.length)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
