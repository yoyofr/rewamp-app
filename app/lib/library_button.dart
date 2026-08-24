import 'dart:io';

import 'package:flutter/material.dart';
import 'l10n.dart';
import 'local_db.dart';
import 'sync_service.dart';
import 'user_settings.dart';

/// Icon button that toggles an item's membership in the user's library.
/// Checks [LocalDb] on first build; shows [Icons.library_add] when absent,
/// [Icons.library_add_check] (coloured) when present.
class LibraryButton extends StatefulWidget {
  final String  type;       // 'track', 'album', 'artist'
  final String  refId;      // onlineId for tracks; album name; artist name
  final String  name;
  final String? artist;
  final String? album;
  final String? artworkUrl;
  final String? formatExt;
  final String? collectionSlug;
  final String? platformName;
  /// Stored in library_items.filename (playlists: the server slug).
  final String? filename;
  /// Server album id (albums only) — persisted so a library replay expands
  /// joshw/jw_spc albums via get_album_tracks instead of browse-by-name.
  final String? albumId;
  /// Called after adding to library to trigger a background download.
  final Future<void> Function()? onDownload;
  final double  iconSize;
  final EdgeInsetsGeometry padding;
  /// Called after each successful toggle with the new state.
  final void Function(bool inLibrary)? onChanged;

  const LibraryButton({
    super.key,
    required this.type,
    required this.refId,
    required this.name,
    this.artist,
    this.album,
    this.artworkUrl,
    this.formatExt,
    this.collectionSlug,
    this.platformName,
    this.filename,
    this.albumId,
    this.onDownload,
    this.iconSize = 24,
    this.padding  = const EdgeInsets.all(8),
    this.onChanged,
  });

  @override
  State<LibraryButton> createState() => _LibraryButtonState();
}

class _LibraryButtonState extends State<LibraryButton> {
  bool _inLibrary = false;
  bool _loading   = true;

  @override
  void initState() {
    super.initState();
    // Listen for external membership changes: favouriting an album (the star
    // next to this button) ALSO adds it to the library (favourite ⊆ library),
    // and this button must light up without a screen rebuild.
    LocalDb.instance.addListener(_check);
    _check();
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_check);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LibraryButton old) {
    super.didUpdateWidget(old);
    if (old.refId != widget.refId || old.type != widget.type) _check();
  }

  Future<void> _check() async {
    // Albums: match by server UUID when known — ref_id is the display name, so
    // a name-only check lights up on homonym albums.
    // Artists: ref_id is the uuid OR the name depending on which screen saved
    // the row — match both forms, else the heart stays dark on the other one
    // and a second tap duplicates the artist.
    final v = switch (widget.type) {
      'album' => await LocalDb.instance
          .isAlbumInLibrary(widget.refId, albumId: widget.albumId),
      'artist' => await LocalDb.instance
          .isArtistInLibrary(widget.name, refId: widget.refId),
      _ => await LocalDb.instance.isInLibrary(widget.type, widget.refId),
    };
    if (mounted) setState(() { _inLibrary = v; _loading = false; });
  }

  Future<void> _toggle() async {
    final next = !_inLibrary;

    setState(() => _inLibrary = next);
    if (next) {
      // Artist saved under its uuid: absorb a legacy NAME-keyed row first, so
      // the upsert (keyed on ref_id) cannot leave two rows for one artist.
      if (widget.type == 'artist' && widget.refId != widget.name) {
        await LocalDb.instance.removeFromLibrary('artist', widget.name);
      }
      await LocalDb.instance.addToLibrary(
        type:           widget.type,
        refId:          widget.refId,
        name:           widget.name,
        artist:         widget.artist,
        album:          widget.album,
        artworkUrl:     widget.artworkUrl,
        formatExt:      widget.formatExt,
        collectionSlug: widget.collectionSlug,
        platformName:   widget.platformName,
        filename:       widget.filename,
        albumId:        widget.albumId,
      );
      widget.onDownload?.call().catchError((_) {});
    } else if (widget.type == 'artist') {
      // Every key form at once (uuid ref_id, name ref_id, display name): one
      // un-heart clears an existing duplicate pair, and a name-only caller
      // still removes a uuid-saved row.
      await LocalDb.instance
          .removeArtistFromLibrary(widget.name, refId: widget.refId);
    } else {
      await LocalDb.instance.removeFromLibrary(widget.type, widget.refId);
    }
    // Sync to server for track/album/playlist (artist has no server-side
    // library counterpart). The server keys albums by their UUID (albumId), NOT
    // the display name stored in refId; tracks by the BARE song uuid (strip any
    // '?subsong=N' local-key suffix); playlists by their own uuid, which is
    // what refId already holds. Purely-local items (file path refId / no
    // albumId) have no server identity — skip the sync.
    if (widget.type == 'track' ||
        widget.type == 'album' ||
        widget.type == 'playlist') {
      final signedIn = UserSettings.instance.hasAuthToken;
      String? serverId;
      if (widget.type == 'album') {
        serverId = widget.albumId;
      } else if (widget.type == 'playlist') {
        serverId = widget.refId;
      } else {
        final base = splitLibraryRefId(widget.refId).$1;
        if (!base.startsWith('/') && !base.contains(':\\')) serverId = base;
      }
      if (signedIn && (serverId == null || serverId.isEmpty) &&
          widget.type == 'track') {
        // Local file (the ref_id is a path): no catalogue identity, so it goes
        // out with a snapshot instead — parked until the server can take it.
        final base = splitLibraryRefId(widget.refId).$1;
        await SyncService.recordLocalLibraryChange(
          itemType:   'song',
          fileName:   base.split(Platform.pathSeparator).last,
          // The app-relative path travels too. Without it the snapshot named a
          // file and nothing else, so the pull could not tell the file was
          // already on this device: it minted a row under the computed
          // `local/<name>` path and the tune appeared TWICE in the library.
          relPath:    await LocalDb.instance.relPathOf(base),
          value:      next,
          subsongIdx: splitLibraryRefId(widget.refId).$2 ?? 0,
          title:      widget.name,
          artist:     widget.artist,
          album:      widget.album,
          formatExt:  widget.formatExt,
        );
      } else if (signedIn && serverId != null && serverId.isNotEmpty) {
        // Queued, not POSTed: the change is delivered by SyncService and
        // survives being offline or a server error.
        await SyncService.recordLibraryChange(
          itemType: switch (widget.type) {
            'album'    => 'album',
            'playlist' => 'playlist',
            _          => 'song',
          },
          itemId:     serverId,
          value:      next,
          subsongIdx: widget.type == 'track'
              ? (splitLibraryRefId(widget.refId).$2 ?? 0)
              : 0,
        );
      } else if (signedIn) {
        // Silent until now: an album row that reached the heart WITHOUT its
        // album_id has no server identity, so the favourite stays on this
        // device only — and looks like a broken sync on the other one. Name it.
        debugPrint('[LibraryButton] no server id for ${widget.type} '
            '"${widget.refId}" — favourite kept local, not synced');
      }
    }
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width:  widget.iconSize + widget.padding.horizontal,
        height: widget.iconSize + widget.padding.vertical,
      );
    }
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(
        _inLibrary ? Icons.library_add_check : Icons.library_add_outlined,
        color: _inLibrary ? cs.primary : null,
        size:  widget.iconSize,
      ),
      padding:     widget.padding,
      constraints: BoxConstraints(
        minWidth:  widget.iconSize + widget.padding.horizontal,
        minHeight: widget.iconSize + widget.padding.vertical,
      ),
      tooltip: _inLibrary
          ? _removedLabel(l10n, widget.type)
          : _addedLabel(l10n, widget.type),
      onPressed: _toggle,
    );
  }
}

String _addedLabel(AppLocalizations l10n, String type) => switch (type) {
  'album'  => l10n.libraryAddedAlbum,
  'artist' => l10n.libraryAddedArtist,
  _        => l10n.libraryAddedTrack,
};

String _removedLabel(AppLocalizations l10n, String type) => switch (type) {
  'album'  => l10n.libraryRemovedAlbum,
  'artist' => l10n.libraryRemovedArtist,
  _        => l10n.libraryRemovedTrack,
};
