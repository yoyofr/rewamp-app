import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'app_snack.dart';
import 'charts_screen.dart';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:path/path.dart' as p;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'favorite_color.dart';
import 'download_cancel.dart';
import 'l10n.dart';
import 'player_controller.dart' show PlayerController;
import 'podium_badge.dart';
import 'radio_surprise_buttons.dart';
import 'note_markdown.dart';
import 'production_screen.dart';
import 'cancel_field.dart';
import 'collection_families.dart';
import 'entity_play_actions.dart';
import 'podium_filter.dart';
import 'rewamp_db.dart';
import 'scrolling_text.dart';
import 'artwork_image.dart';
import 'album_detail_screen.dart';
import 'local_db.dart';
import 'local_open.dart' show globalOpenLocalPaths;
import 'library_button.dart';
import 'local_library_screen.dart';
import 'song_tile.dart';
import 'track_options_sheet.dart';
import 'horizontal_scroll_arrows.dart';
import 'facet_picker_sheet.dart';
import 'browse_screen.dart'
    show CollectionAlbumsScreen, FacetValuesScreen, PlaylistTracksScreen;
import 'user_settings.dart';

// The group screen reuses this library's private result lists (_AlbumList,
// _ArtistResultList, _PlaylistList, _ProductionList, _PaginatedListView) —
// hence a part rather than a separate library that would have to duplicate them.
import 'shell_insets.dart';

part 'group_screen.dart';

// ---------------------------------------------------------------------------
// Shared download + play action
// ---------------------------------------------------------------------------

/// Downloads [r] to local storage then calls [onFileReady].
/// Shows a loading dialog and handles errors via SnackBar.
/// Safe to call from any BuildContext (checks mounted before every UI op).
Future<void> downloadAndPlay(
  BuildContext    context,
  SearchResult    r,
  OnFileReady     onFileReady, {
  bool            afterSourceRefresh = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final nav       = Navigator.of(context);
  final l10n      = context.l10n;

  // The row knows its podium (`compo_podium` is a column of every listing) —
  // hand it to the player now so the cup is up with the first frame instead of
  // one get_song_context later. Consumed by the matching loadFile, dropped
  // otherwise. This is the single choke point of every catalogue play.
  PlayerController.primePodium(r.songId, r.podium);

  showDialog(
    context: context,
    barrierDismissible: false,
    useRootNavigator: false,
    builder: (_) => AlertDialog(
      content: Row(children: [
        const CircularProgressIndicator(),
        const SizedBox(width: 16),
        Expanded(child: Text(l10n.searchDownloading)),
      ]),
      // This dialog is MODAL: its barrier sits over the global download banner,
      // so without an action here the ✕ down there is unreachable and a
      // several-hundred-MB album archive can only be waited out.
      actions: [
        TextButton(
          onPressed: RewampDb.cancelAmbientDownloads,
          child: Text(l10n.downloadsCancel),
        ),
      ],
    ),
  );

  // Closes the dialog exactly once. `nav` was captured synchronously and
  // showDialog pushes the dialog route synchronously too, so popping works even
  // if the download finished before the dialog's first frame — and it does NOT
  // depend on `context.mounted`, so a disposed triggering screen can't orphan
  // the modal. Guarded against the navigator itself being gone.
  var dialogClosed = false;
  void dismiss() {
    if (dialogClosed) return;
    dialogClosed = true;
    try { nav.pop(); } catch (_) {}
  }

  try {
    String localPath;
    SearchResult resolved = r;

    // A songId that is an absolute PATH is a LOCAL identity, never a catalogue
    // one: the file IS the track, so if it is not on disk there is nothing to
    // resolve. Without this the row fell through to the album branch on the
    // strength of its `album` field alone and resolved a catalogue album by
    // NAME — a phantom "03 Kingdom Baron" (album "Final Fantasy IV") queried a
    // 56-track album it was never part of, and the failure surfaced as the
    // misleading "wrong album resolved". Same reasoning as `catalogueSongId`:
    // a local identity must not be sent where a uuid is expected.
    final songIdIsPath =
        r.songId.startsWith('/') || r.songId.contains(':\\');
    if (songIdIsPath && !await File(splitLibraryRefId(r.songId).$1).exists()) {
      throw Exception('local file missing: ${r.songId}');
    }

    // Row already pointing at an on-disk file (subsong-picker rows, PSF
    // expansions): play it as-is. Without this, a picker row whose album field
    // is the container's display name fell into the ALBUM branch, whose cached
    // lookup returns an arbitrary subsong row (LIMIT 1) — every tap replayed
    // the same subsong.
    if (r.localPath != null && await File(r.localPath!).exists()) {
      final artworkTargetDir = await RewampDb.artworkDirForResult(r);
      dismiss();
      onFileReady(
        r.localPath!,
        r.displayTitle,
        artist:           r.artistLabel.isEmpty ? null : r.artistLabel,
        album:            r.album,
        albumId:          r.albumId,
        formatExt:        r.formatExt,
        onlineId:         r.songId,
        artworkUrl:       r.artworkUrl,
        artworkTargetDir: artworkTargetDir,
        subsongIdx:       r.subsongIdx,
        durationS:        r.durationMs != null ? r.durationMs! / 1000.0 : null,
        subsongCount:     r.subsongCount,
      );
      return;
    }

    // Library/playlist rows saved from the player carry no downloadUrl (only
    // the online id) — after the download was deleted, replaying such a trace
    // must re-resolve a playable URL from the server, else downloadToLibrary
    // throws ('Téléchargement impossible'). Album-archive tracks keep a null
    // URL here and fall through to the album-zip path below unchanged.
    //
    // AUSSI quand l'albumId manque (même avec une url): le chemin sur disque
    // est dérivé de l'identité d'album depuis le layout par album-id — une
    // ligne bibliothèque sans albumId (« ajouts récents » d'avant la colonne)
    // téléchargeait sous online/<col>/unknown/… au lieu du dossier uuid.
    if (r.songId.isNotEmpty &&
        (r.downloadUrl == null || r.albumId == null || r.albumId!.isEmpty)) {
      final cached = await LocalDb.instance.getTrackByOnlineId(r.songId);
      final onDisk = cached != null && await File(cached.filePath).exists();
      if (onDisk && r.album == null) {
        // Cached simple file (no album context): play it directly — the
        // album-archive fast path below only covers album rows, and the
        // downloadToLibrary fallback would throw on the missing URL.
        // Respect the CALLER's subsong index: getTrackByOnlineId returns an
        // arbitrary subsong row (LIMIT 1 — e.g. the favourited one), and
        // playing its index made every container-row tap replay that same
        // subsong. Resolve the exact row for its title/duration when known.
        final exact = (cached.subsongIdx == r.subsongIdx)
            ? cached
            : (await LocalDb.instance.getTracksForFile(cached.filePath))
                .where((t) => t.subsongIdx == r.subsongIdx)
                .firstOrNull;
        dismiss();
        onFileReady(
          cached.filePath,
          exact?.title ?? r.displayTitle,
          artist:     exact?.artist ?? cached.artist,
          album:      cached.metaAlbum,
          albumId:    r.albumId ?? cached.albumId,
          formatExt:  cached.formatExt ?? r.formatExt,
          onlineId:   r.songId,
          artworkUrl: cached.artworkUrl ?? r.artworkUrl,
          subsongIdx: r.subsongIdx,
          durationS:  exact?.durationS ??
              (r.durationMs != null ? r.durationMs! / 1000.0 : null),
          subsongCount: r.subsongCount ?? cached.subsongCount,
        );
        return;
      }
      if (!onDisk) {
        try {
          final sc = await RewampDb.getSongContext(r.songId);
          // Le catalogue ne connaît que le morceau: pour un album CONTENEUR
          // (jw_spc, jw_psf) c'est l'archive entière, dont le `filename` est le
          // nom de l'album. Le bloc plus bas reconstruit la ligne avec
          // `filename: s.filename` dès qu'il y a une url — il écrasait donc le
          // nom du VRAI fichier que l'appelant tenait, et le téléchargement
          // demandait « Final Fantasy VI.spc », absent du 7z: exact-miss puis
          // pick générique (une piste au hasard sous le titre d'une autre).
          final ctxSong = sc?.song;
          // Serveur d'abord (`get_song_entry`, mig 235): l'ENTRÉE directement,
          // repli radical compris, null explicite si introuvable. Le
          // rétrécissement client reste le repli d'un serveur antérieur.
          final s = await RewampDb.getSongEntry(r.songId,
                  fileName: r.filename) ??
              (ctxSong == null
                  ? null
                  : RewampDb.narrowedToMember(ctxSong, r.songId,
                      wantFileName: r.filename));
          // IDENTITY FIRST, url second. This used to be gated on
          // `s.downloadUrl != null`, so a track that lives INSIDE an archive
          // (every .rsn member — no url of its own) threw the whole context
          // away, `album_id` and `collection` included. The album branch below
          // then had nothing but a bare name to go on and picked a HOMONYM
          // across collections — "Final Fantasy III" resolved to the NES set
          // instead of the SNES .rsn, no track matched, and the index fallback
          // played an unrelated tune. Take what identifies the tune whenever
          // the catalogue answers; the url only decides the download route.
          if (s != null && s.downloadUrl == null) {
            r = r.copyWithIdentity(
              collection: s.collection.isNotEmpty ? s.collection : null,
              album:      s.album,
              albumId:    s.albumId,
            );
          }
          if (s != null && s.downloadUrl != null) {
            r = SearchResult(
              songId:       r.songId,
              collection:   s.collection.isNotEmpty ? s.collection : r.collection,
              title:        r.title,
              filename:     s.filename,
              album:        r.album ?? s.album,
              albumId:      r.albumId ?? s.albumId,
              formatExt:    s.formatExt,
              downloadUrl:  s.downloadUrl,
              mirrorUrl:    s.mirrorUrl,
              fileSize:     s.fileSize,
              year:         r.year ?? s.year,
              artistNames:  r.artistNames.isNotEmpty ? r.artistNames : s.artistNames,
              totalCount:   r.totalCount,
              platform:     r.platform ?? s.platform,
              rating:       r.rating,
              artworkUrl:   r.artworkUrl ?? s.artworkUrl,
              trackPosition: r.trackPosition,
              subsongIdx:   r.subsongIdx,
              auxFiles:     s.auxFiles,
            );
            resolved = r;
          }
        } on ArchiveEntryMissingException catch (e) {
    // La tracklist nomme un fichier que l'archive ne contient pas. Dire QUOI
    // manque, et le SIGNALER: c'est une lacune du catalogue (le rip liste ses
    // pistes vocales sans les livrer), pas un incident de téléchargement, et
    // personne ne peut le voir depuis le serveur.
    dismiss();
    debugPrint('[search] absent de l\'archive: ${e.filename} (${e.url})');
    if (context.mounted) {
      AppSnack.showOn(messenger,
          l10n.playbackTrackNotInArchive(p.basename(e.filename)),
          duration: const Duration(seconds: 4));
    }
    if (e.songId != null && e.songId!.isNotEmpty) {
      RewampDb.reportSong(
        songId:       e.songId!,
        reason:       'download_failed',
        subsongIndex: e.subsongIndex > 0 ? e.subsongIndex : null,
        detail:       'tracklist names "${e.filename}", absent from ${e.url}',
      );
    }
  } on DownloadTimeoutException catch (e) {
    // L'origine n'a pas répondu. Le fait UTILE est le nom de l'hôte — pas
    // « TimeoutException after 0:00:20.000000: Future not completed », qui est
    // ce que le bandeau affichait. Rien à signaler au serveur: le fichier
    // n'est pas en cause, la route l'est (mesuré le 2026-09-02: la même url
    // répondait en 0,19 s ailleurs, et est repassée toute seule ensuite).
    dismiss();
    debugPrint('[search] source timeout: ${e.host} (${r.filename})');
    if (context.mounted) {
      AppSnack.showOn(messenger, l10n.playbackSourceTimeout(e.host),
          duration: const Duration(seconds: 4));
    }
  } on DownloadCancelledException {
          rethrow; // aborted by the user, not an offline miss
        } catch (_) {/* offline → the branches below surface the error */}
      }
    }

    if (r.downloadUrl == null && r.album != null) {
      // Track has no direct download URL — it lives inside an album archive
      // (e.g. an SPC inside an RSN).

      // Fast path: if this track was already downloaded (DB record + file exists),
      // skip the network entirely.
      final cached = await LocalDb.instance.getTrackByOnlineId(r.songId);
      if (cached != null && await File(cached.filePath).exists()) {
        resolved  = r;
        localPath = cached.filePath;
        // Subsong index: for shared-songId containers (SID) getTrackByOnlineId
        // returns an arbitrary subsong row (LIMIT 1), so the CALLER's index is
        // authoritative. But RSN rows have a UNIQUE per-track songId whose
        // cached row records the track's rank inside the .rsn — a playlist
        // entry's own subsongIdx does NOT (it played the wrong / first track).
        final isRsn = cached.filePath.toLowerCase().endsWith('.rsn');
        final playSubsong = isRsn ? cached.subsongIdx : r.subsongIdx;
        final exact = (cached.subsongIdx == playSubsong)
            ? cached
            : (await LocalDb.instance.getTracksForFile(cached.filePath))
                .where((t) => t.subsongIdx == playSubsong)
                .firstOrNull;
        resolved  = SearchResult(
          songId:       r.songId,
          collection:   r.collection,
          // Prefer the caller's album id, else the persisted track row's —
          // library rows saved before album_id was threaded everywhere carry
          // none, and without it the player shows the subsong-container link
          // instead of the album link.
          albumId:      r.albumId ?? cached.albumId,
          title:        exact?.title ?? r.title,
          filename:     cached.filePath.split('/').last,
          album:        r.album,
          formatExt:    cached.formatExt ?? r.formatExt,
          downloadUrl:  r.downloadUrl,
          fileSize:     r.fileSize,
          year:         r.year,
          artistNames:  r.artistNames,
          totalCount:   r.totalCount,
          platform:     r.platform,
          rating:       r.rating,
          artworkUrl:   r.artworkUrl,
          trackPosition: r.trackPosition,
          subsongIdx:   playSubsong,
        );
        localPath = cached.filePath;
        final artworkTargetDir = await RewampDb.artworkDirForResult(resolved);
        dismiss();
        onFileReady(
          localPath,
          resolved.displayTitle,
          artist:           resolved.artistLabel.isEmpty ? null : resolved.artistLabel,
          album:            resolved.album,
          albumId:          resolved.albumId,
          formatExt:        resolved.formatExt,
          onlineId:         resolved.songId,
          artworkUrl:       resolved.artworkUrl,
          artworkTargetDir: artworkTargetDir,
          subsongIdx:       resolved.subsongIdx,
          durationS:        resolved.durationMs != null ? resolved.durationMs! / 1000.0 : null,
          subsongCount:     resolved.subsongCount,
        );
        return;
      }

      // Slow path: download the whole album archive. Resolve by album UUID when
      // we have one — a bare name (especially with an empty collection, e.g. a
      // library row without a slug) matches HOMONYM albums across collections,
      // and the first mismatched track then derives the wrong on-disk path
      // (a snesmusic "Dr. Mario" .rsn once landed under online/jw_gbs/…/gb/).
      final details = await RewampDb.fetchAlbumDetails(
        r.album!,
        collectionSlug: r.collection.isEmpty ? null : r.collection,
        albumId: r.albumId,
      );
      final zipUrl = details.isNotEmpty ? details.first.zipUrl : null;
      final mirrorZip = details.isNotEmpty ? details.first.mirrorZipUrl : null;

      // Fetch full track list to build the subsong map (exact by album UUID
      // when known; name+collection browse otherwise).
      final aid = r.albumId ?? details.firstOrNull?.albumId;
      final songs = (aid != null && aid.isNotEmpty)
          ? await RewampDb.albumTracks(
              albumId: aid, sortBy: 'position', limit: 500)
          : await RewampDb.browse(
              albumName:  r.album,
              collection: r.collection.isEmpty ? null : r.collection,
              sortBy:     'position',
              limit:      500,
            );
      if (songs.isEmpty) throw Exception('Album track list empty for ${r.album}');

      // Locates the tapped track in a (re)downloaded list. Library traces from
      // an expanded PSF album carry a SYNTHETIC id ('<uuid>#<idx>', minted
      // locally by the expansion) that server rows don't have — fall back to a
      // title match, then to the subsong index.
      SearchResult pickIn(List<SearchResult> list) {
        final byId = list.where((s) => s.songId == r.songId).firstOrNull;
        if (byId != null) return byId;
        final byTitle = list
            .where((s) =>
                s.title != null &&
                r.title != null &&
                s.title!.toLowerCase() == r.title!.toLowerCase())
            .firstOrNull;
        if (byTitle != null) return byTitle;
        // Position is the LAST resort, and only for a row the catalogue cannot
        // match by id: a synthetic '<uuid>#<idx>' minted by an expansion, or no
        // id at all. A real catalogue id that is absent from this album's track
        // list means we are looking at the WRONG ALBUM — taking the row at that
        // index there is how a deleted "Terra" (SNES .rsn, subsong 27) came
        // back as track 27 of the homonym NES album. Fail instead: the queue
        // reports it and moves on, which is recoverable; playing an unrelated
        // tune under the right title is not.
        final synthetic = r.songId.isEmpty || r.songId.contains('#');
        if (!synthetic) {
          throw Exception('track ${r.songId} ("${r.title}") is not in album '
              '"${r.album}" (${list.length} tracks) — wrong album resolved');
        }
        return list[r.subsongIdx.clamp(0, list.length - 1)];
      }

      // Re-download by ALBUM TYPE — the generic path assumed a ZIP and fed
      // joshw 7z archives to ZipDecoder ('Could not find End of Central
      // Directory Record' on jw_psf/jw_nsf replays after a delete).
      // NOTE: a jw_psf album row is BOTH a container (track_count > 1, tracks
      // JSONB) and a PSF 7z archive — the PSF check must come FIRST, else
      // expandContainerAlbum fabricates rows straight from the JSONB names
      // (including deleted files, no existence check) and play dies silently.
      List<SearchResult> finalSongs;
      if (RewampDb.isPsfArchiveAlbum(songs)) {
        // PSF-family 7z album (jw_psf .minipsf sets, …): 7z-aware path.
        finalSongs = await RewampDb.downloadPsfAlbum(songs);
        // A single deleted file in an otherwise-downloaded album: the album
        // reads as cached, extraction was skipped, and the rebuilt dir-scan
        // list misses the deleted file entirely (synthetic '#idx' ids shift
        // onto the wrong tracks). Detect it either by the picked row's file
        // being absent or by the expected TITLE not existing in the list, and
        // force one archive re-extract.
        final probe = pickIn(finalSongs);
        final pp = (probe.localPath != null && probe.localPath!.isNotEmpty)
            ? probe.localPath!
            : await RewampDb.localPath(probe);
        final titleFound = r.title == null ||
            finalSongs.any((s) =>
                s.title != null &&
                s.title!.toLowerCase() == r.title!.toLowerCase());
        if (!await File(pp).exists() || !titleFound) {
          debugPrint('[downloadAndPlay] psf track missing '
              '(file=${await File(pp).exists()}, title=$titleFound) — '
              'forcing archive re-extract');
          finalSongs = await RewampDb.downloadPsfAlbum(songs, force: true);
        }
      } else if (songs.length == 1 && RewampDb.isContainerRow(songs.first)) {
        // Single container file (jw_nsf .nsf, …): download + expand subsongs.
        finalSongs = await RewampDb.expandContainerAlbum(songs.first);
      } else {
        if (zipUrl == null) {
          throw Exception('No download URL and no album zip for ${r.filename}');
        }
        // Standard album archive (zip, or RSN handled by magic inside).
        final reordered = await RewampDb.downloadAndExtractZip(zipUrl, songs,
            mirrorZipUrl: mirrorZip, albumId: r.albumId);
        finalSongs = reordered ?? songs;
      }

      // Find our specific track in the rewritten list.
      final match = pickIn(finalSongs);
      resolved  = match;
      // PSF/container expansions return rows pointing at the REAL extracted
      // file (localPath) — the recomputed standard path may not exist (7z
      // layouts keep their own names/subdirs).
      localPath = (match.localPath != null &&
              await File(match.localPath!).exists())
          ? match.localPath!
          : await RewampDb.localPath(match);
    } else {
      localPath = await RewampDb.downloadToLibrary(r);
    }

    final artworkTargetDir = await RewampDb.artworkDirForResult(resolved);
    dismiss();
    onFileReady(
      localPath,
      resolved.displayTitle,
      artist:           resolved.artistLabel.isEmpty ? null : resolved.artistLabel,
      album:            resolved.album,
      // Synthetic PSF rows may lack the id — fall back to the caller's row
      // (library traces carry it) so the album link survives a re-download.
      albumId:          resolved.albumId ?? r.albumId,
      formatExt:        resolved.formatExt,
      onlineId:         resolved.songId,
      artworkUrl:       resolved.artworkUrl,
      artworkTargetDir: artworkTargetDir,
      subsongIdx:       resolved.subsongIdx,
      durationS:        resolved.durationMs != null ? resolved.durationMs! / 1000.0 : null,
      subsongCount:     resolved.subsongCount,
    );
  } on FormatUnsupportedException catch (e) {
    dismiss();
    // Before blaming the format, ask the server whether the file was REPLACED
    // (same song_id, new download_url). If so, retry once with the fresh row
    // (url converges → no loop).
    final fresh = await RewampDb.resolveReplacement(e, r);
    if (fresh != null) {
      // Replaceable: retry when we still have a live context to drive the
      // download dialog; if the context is gone, bail WITHOUT reporting — it is
      // not unsupported, just un-retryable here.
      if (context.mounted) {
        debugPrint('[search] ${e.filename} replaced server-side — retrying');
        return downloadAndPlay(context, fresh, onFileReady);
      }
      return;
    }
    // Fetched fine, but no engine plays it — say so explicitly (file + ext),
    // not "download failed", and report the song. `messenger`/`l10n` were
    // captured at entry, so the snackbar shows even if the triggering context
    // has since unmounted (the download can outlive its screen).
    debugPrint('[search] unsupported format: ${e.filename} .${e.ext}');
    AppSnack.showOn(messenger,
        l10n.playbackFormatUnsupported(e.filename, e.ext),
        duration: const Duration(seconds: 3));
    if (e.songId != null) {
      RewampDb.reportSong(
        songId:       e.songId!,
        reason:       'no_playback',
        subsongIndex: e.subsongIndex > 0 ? e.subsongIndex : null,
        detail:       e.detail.isNotEmpty
            ? e.detail
            : 'unsupported: ${e.filename} (.${e.ext})',
      );
    }
  } on DownloadHttpException catch (e) {
    // The file is GONE from the origin (404/403/410) — say so and report it
    // (download_failed), rather than a generic error.
    dismiss();
    debugPrint('[search] file gone (HTTP ${e.statusCode}): ${e.url}');
    if (e.isGone) {
      // The origin is gone — but a mirror may have been synced since this row
      // was fetched (download_url unchanged). Refresh the source ONCE and retry
      // via the new mirror before reporting.
      if (!afterSourceRefresh) {
        final fresh = await RewampDb.refreshSongSource(r, triedUrl: e.url);
        if (fresh != null && context.mounted) {
          debugPrint('[search] ${r.filename} source refreshed after 404 — retrying');
          return downloadAndPlay(context, fresh, onFileReady,
              afterSourceRefresh: true);
        }
      }
      AppSnack.showOn(messenger, l10n.playbackFileGone(p.basename(r.filename)),
          duration: const Duration(seconds: 3));
      final songId = r.songId.split('#').first.split('?').first;
      if (songId.isNotEmpty) {
        RewampDb.reportSong(
          songId:       songId,
          reason:       'download_failed',
          subsongIndex: r.subsongIdx > 0 ? r.subsongIdx : null,
          detail:       'HTTP ${e.statusCode} at ${e.url}',
        );
      }
    } else if (context.mounted) {
      AppSnack.showOn(messenger, l10n.searchError(e.toString()));
    }
  } on DownloadCancelledException {
    // The user's own gesture — close the dialog and say nothing.
    debugPrint('[search] download cancelled: ${r.filename}');
    dismiss();
  } catch (e, st) {
    debugPrint('[search] download error: $e\n$st');
    dismiss();
    if (context.mounted) {
      AppSnack.showOn(messenger, l10n.searchError(e.toString()));
    }
  } finally {
    // Ultimate safety net: whatever happened above (an early return, an
    // unmounted context, an unexpected throw), the modal is always closed.
    dismiss();
  }
}

/// Plays an album from a list context (no AlbumDetailScreen).
/// Fetches the full track list, downloads the album ZIP if needed
/// (e.g. RSN/snesmusic where individual tracks have no downloadUrl),
/// then hands off to [onPlayAlbum].
Future<void> playAlbumFromList(
  BuildContext ctx,
  String       albumName, {
  String?      collection,
  String?      platform,
  required OnPlayAlbum onPlayAlbum,
}) async {
  // 0. ▶ sur une ligne d'ALBUM ouvre le MÊME choix que partout ailleurs
  // (« Lire maintenant » / « Lire ensuite » / « Ajouter à la fin »), au lieu
  // d'écraser la file sans rien demander. Posé ICI, dans l'entonnoir, et non
  // sur les six ▶ qui y mènent (navigateur d'albums en liste et en grille,
  // onglet Albums d'un artiste, palmarès, résultats dédiés) — les recoder un
  // par un garantirait qu'il en manque un, exactement la leçon des liens
  // « voir » de showPlayChoiceSheet.
  //
  // La feuille passe AVANT la résolution des pistes: elle est instantanée,
  // alors que la suite fait un aller-retour serveur et peut TÉLÉCHARGER le zip
  // de l'album — un choix écarté ne doit rien avoir coûté.
  // ⚠️ File vide ⇒ `showPlayChoiceSheet` rend `now` sans rien afficher: le
  // geste reste direct quand il n'y a pas de file à écraser.
  final subtitle = [
    if (platform != null && platform.isNotEmpty) platform,
    if (collection != null && collection.isNotEmpty)
      RewampDb.collectionLabel(collection),
  ].join(' · ');
  final choice = await showPlayChoiceSheet(ctx,
      title: albumName, subtitle: subtitle.isEmpty ? null : subtitle);
  if (choice == null || !ctx.mounted) return;

  // Un seul point de sortie pour les DEUX chemins (album conteneur déplié,
  // album ordinaire): le choix décide, jamais l'appelant.
  Future<void> hand(List<SearchResult> tracks) async {
    if (!ctx.mounted || tracks.isEmpty) return;
    switch (choice) {
      case PlayChoice.now:
        await onPlayAlbum(ctx, tracks);
      case PlayChoice.next:
      case PlayChoice.end:
        // `globalOnAlbumQueueAdd` déplie chaque piste en ses sous-chansons et
        // annonce le plafond de file, comme le fait `onPlayAlbum`.
        await globalOnAlbumQueueAdd?.call(tracks,
            atEnd: choice == PlayChoice.end);
      case PlayChoice.open:
        break; // pas d'`openLabel` ici — inatteignable, mais le switch est exhaustif
    }
  }

  // 1. Full track list ordered by position.
  var songs = await RewampDb.browse(
    albumName:  albumName,
    collection: collection,
    platform:   platform,
    sortBy:     'position',
    limit:      500,
  );
  if (songs.isEmpty || !ctx.mounted) return;

  // 1b. Container album (joshw NSF/GBS/…): the server lists one multi-subsong
  // file with no per-track breakdown.  Download + probe to expand the subsongs.
  if (songs.length == 1 && RewampDb.isContainerRow(songs.first)) {
    try {
      final expanded = await RewampDb.expandContainerAlbum(songs.first);
      if (!ctx.mounted) return;
      await hand(expanded);
    } catch (e) {
      if (ctx.mounted) {
        AppSnack.show(ctx, ctx.l10n.searchError(e.toString()));
      }
    }
    return;
  }

  // 2. Fetch album details to get zipUrl (needed for RSN + other zip-only collections).
  final details = await RewampDb.fetchAlbumDetails(
    albumName,
    collectionSlug: collection,
    platformName:   platform,
  );
  final zipUrl = details.isNotEmpty ? details.first.zipUrl : null;
  final mirrorZip = details.isNotEmpty ? details.first.mirrorZipUrl : null;

  if (zipUrl != null) {
    final firstPath = await RewampDb.localPath(songs.first);
    if (!await File(firstPath).exists() && ctx.mounted) {
      final nav = Navigator.of(ctx, rootNavigator: false);
      final l10n = ctx.l10n;
      showDialog(
        context: ctx,
        barrierDismissible: false,
        useRootNavigator: false,
        builder: (_) => AlertDialog(
          content: Row(children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(l10n.searchDownloadingAlbum)),
          ]),
        ),
      );
      try {
        final reordered = await RewampDb.downloadAndExtractZip(zipUrl, songs,
            mirrorZipUrl: mirrorZip);
        if (reordered != null) songs = reordered;
      } catch (_) {
        // Fall through — individual downloads will be attempted per track.
      } finally {
        if (ctx.mounted) nav.pop();
      }
    }
  }

  if (!ctx.mounted) return;
  await hand(songs);
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

typedef OnFileReady = void Function(
  String path,
  String label, {
  String? artist,
  String? album,
  String? albumId,
  String? formatExt,
  String? onlineId,
  String? artworkUrl,
  String? artworkTargetDir,
  int     subsongIdx,
  double? durationS,
  int?    subsongCount,
});

class SearchScreen extends StatefulWidget {
  final OnFileReady      onFileReady;
  final OnPlayAlbum?     onPlayAlbum;
  final OnQueueAdd?      onQueueAdd;
  final OnAlbumQueueAdd? onAlbumQueueAdd;
  /// Bumped by the shell when the search tab is re-selected while already
  /// active → resets every search criterion (text, tags, année, note…).
  final ValueListenable<int>? resetTick;
  /// Pre-applied tag facets — used when the screen is PUSHED as a tag browse
  /// (tapping a tag in the player info sheet), so it opens showing songs,
  /// artists AND albums for that tag across its tabs.
  final List<String> initialTags;
  // mig 159: category of the initial tag(s) when the chip that navigated here
  // knew it (group/party/production/…) — scopes tag resolution server-side.
  final String? initialTagCategory;

  const SearchScreen({
    super.key,
    required this.onFileReady,
    this.onPlayAlbum,
    this.onQueueAdd,
    this.onAlbumQueueAdd,
    this.resetTick,
    this.initialTags = const [],
    this.initialTagCategory,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

// ---------------------------------------------------------------------------
// Album identity — deduplicates by (name, collection, platform)
// ---------------------------------------------------------------------------

class _AlbumId {
  final String           name;
  final String           collection; // "modland" | "vgmrips" | …
  final String?          platform;   // vgmrips platform tag; null for modland
  final String?          artworkUrl;
  final List<AlbumAlias> aliases;
  // Stable server album id; null for text-only albums / local. When present it
  // IS the identity — distinct same-named albums (e.g. Commando) stay distinct.
  final String?          albumId;
  final List<String>     artistNames;
  final String?          format;   // fallback for the qualifier when platform is null
  final int              fileSize; // total album size in bytes (0 if unknown)
  final String?          matchReason; // search_albums: direct|via_artist|via_song
  final bool             hasVideo;    // a track has a linked demozoo video
  /// Album-level competition podium (mig 186): the album IS the placed
  /// production, or one of its tracks placed.
  final CompoPodium?     podium;
  // Album-grain score (207/208 semantics) — null until the album listing
  // RPCs expose the columns (parsed by name in ArtistAlbum).
  final double?          rating;
  final int?             popularity;

  const _AlbumId(
    this.name,
    this.collection,
    this.platform, [
    this.artworkUrl,
    this.aliases = const [],
    this.albumId,
    this.artistNames = const [],
    this.format,
    this.fileSize = 0,
    this.matchReason,
    this.hasVideo = false,
    this.podium,
    this.rating,
    this.popularity,
  ]);

  String? get fileSizeLabel {
    if (fileSize <= 0) return null;
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(0)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Identity key: the server album_id when known, else the legacy
  // (collection,name,platform) composite (text albums / local, no id).
  String get key => albumId ?? '$collection\x00$name\x00${platform ?? ''}';

  // One-line qualifier shown as tile subtitle. Use the platform when known,
  // otherwise fall back to the file format (uppercased) so the line isn't bare.
  String? get qualifier {
    final hasPlatform = platform != null && platform!.isNotEmpty;
    final hasFormat   = format != null && format!.isNotEmpty;
    final parts = <String>[
      if (hasPlatform) platform!
      else if (hasFormat) format!.toUpperCase(),
      collection,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

// ---------------------------------------------------------------------------
// Tabs
// ---------------------------------------------------------------------------

// Tag facet categories are fetched dynamically from the server
// (`list_tag_categories` RPC) so new categories (e.g. `production`) appear
// without a client change. Slugs are mapped to localized labels by
// [_categoryLabel]; unknown slugs fall back to a capitalized slug. This static
// list is only the offline fallback when the RPC is unavailable.
const List<String> _kTagCategoriesFallback = [
  'chip',
  'group',
  'party',
  'production-type',
  'year',
  'origin',
];

// Known slug → localized label. Slugs not listed here get a capitalized fallback.
String _categoryLabel(String slug, AppLocalizations l10n) {
  final known = switch (slug) {
    'chip'            => l10n.searchCategoryChip,
    'group'           => l10n.searchCategoryGroup,
    'party'           => l10n.searchCategoryParty,
    'year'            => l10n.searchCategoryYear,
    'origin'          => l10n.searchCategoryOrigin,
    // New server-side category (get_song_context.tags): reuse the existing
    // "Plateforme" label rather than mint a 19th translation of one word.
    'platform'        => l10n.searchPlatform,
    'production-type' => l10n.searchCategoryProductionType,
    'saga'            => l10n.searchCategorySaga,
    'genre'           => l10n.searchCategoryGenre,
    // These three shipped with the raw capitalized slug ("Publisher") in all
    // 18 locales — the fallback below is for UNKNOWN server additions only.
    'publisher'       => l10n.searchCategoryPublisher,
    'developer'       => l10n.searchCategoryDeveloper,
    'arcade-board'    => l10n.searchCategoryArcadeBoard,
    _                 => null,
  };
  if (known != null) return known;
  if (slug.isEmpty) return slug;
  return slug[0].toUpperCase() + slug.substring(1);
}

// Formats tab dropped — the server search_facets RPC now feeds a Format filter
// dropdown (cross-entity) instead of a standalone client-derived tab.
enum _Tab { all, artists, groups, albums, playlists, productions, local }

String _tabLabel(_Tab t, AppLocalizations l10n) => switch (t) {
  _Tab.all       => l10n.tabAll,
  _Tab.artists   => l10n.tabArtists,
  // searchCategoryGroup is already the plural facet label ("Groupes",
  // "Gruppen", "Группы") in all 18 locales — a 19th translation of one word
  // would be the same string.
  _Tab.groups    => l10n.searchCategoryGroup,
  _Tab.albums    => l10n.tabAlbums,
  _Tab.playlists => l10n.libraryPlaylists,
  _Tab.productions => l10n.tabProductions,
  _Tab.local     => l10n.localLibraryTitle,
};

// Cross-entity match_reason → UX label. 'direct'/null (a plain name/browse
// match) shows no badge; only the 1-hop reasons get a "trouvé via …" chip.
String? _matchReasonLabel(String? reason, AppLocalizations l10n) =>
    switch (reason) {
  'via_artist' => l10n.searchViaArtist,
  'via_album'  => l10n.searchViaAlbum,
  'via_song'   => l10n.searchViaSong,
  _            => null,
};

/// Small pill shown on a result row when it matched through a relationship hop.
class _MatchReasonBadge extends StatelessWidget {
  final String? reason;
  const _MatchReasonBadge(this.reason);

  @override
  Widget build(BuildContext context) {
    final label = _matchReasonLabel(reason, context.l10n);
    if (label == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: cs.onTertiaryContainer)),
    );
  }
}

// ---------------------------------------------------------------------------
// Main search state
// ---------------------------------------------------------------------------

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _controller = TextEditingController();
  // Owned by the screen (NOT the filter sheet): disposing a controller right
  // after `await showModalBottomSheet` races the sheet's swipe-dismiss rebuild
  // (EditableText re-adds a listener on a disposed controller → crash). Living
  // as long as the screen sidesteps that entirely.
  final _tagSearchCtrl = TextEditingController();
  final _focus      = FocusNode();
  Timer? _debounce;

  final _resultsNotifier = ValueNotifier<List<SearchResult>>([]);
  int    _totalCount   = 0;
  int    _offset       = 0;
  bool   _hasMore      = false;
  String  _currentQuery = '';
  // Onglet « Sur cet appareil »: les imports locaux qui matchent la requête.
  // Filtrage en MÉMOIRE (quelques milliers de lignes au plus), pas de
  // pagination; -1 = pas encore chargé (le libellé d'onglet reste nu).
  List<(String, TrackRecord)> _localMatches = const [];
  int _localTotal = -1;
  String  _sortBy       = 'relevance'; // relevance|title|year|rating
  final List<TagItem> _selectedTags = []; // tag facets (display name, send slug)

  // Server tag filter matches by NAME (case-insensitive), not slug — see
  // RewampDb._tagParams.
  List<String> get _tagNames => _selectedTags.map((t) => t.name).toList();
  // mig 159: categories restricting tag resolution — only when EVERY selected
  // tag has one (any uncategorized tag → null = historic all-category union).
  List<String>? get _tagCategoriesFilter {
    if (_selectedTags.isEmpty) return null;
    final cats = <String>{};
    for (final t in _selectedTags) {
      final c = t.category;
      if (c == null || c.isEmpty) return null;
      cats.add(c);
    }
    return cats.toList();
  }
  bool    _exact = UserSettings.instance.searchExact; // false = fuzzy
  int?    _yearMin;          // year facet, inclusive (null = off)
  int?    _yearMax;
  double  _ratingMin = 0;    // 0 = off (rating derives from plays, often null)
  int?    _podium;           // p_podium: null = aucun, 0 = tout podium, 1-3 = rang
  List<FacetCount> _facetsAlbum = [];   // facettes au grain ALBUM (onglet Albums)
  // Seed for sort_by 'random': fixed per "radio session" ⇒ stable pagination
  // order without repeats; regenerated on each new radio start / sort toggle.
  String  _radioSeed = DateTime.now().millisecondsSinceEpoch.toString();
  String? _collectionFilter; // null = all collections
  String? _formatFilter;     // format_filter (ext) — from search_facets dropdown
  String? _platformFilter;   // platform_name — from search_facets dropdown
  String? _sortDir;          // asc|desc; null = server default per sort_by
  // Facet counts (format/platform/collection) for the current q+filters, from
  // search_facets — feeds the Format/Platform dropdowns with true totals.
  List<FacetCount> _facets = [];
  // "Did you mean" fuzzy fallback: after an exact (fuzzy=false) query returns
  // few/no results, offer a one-tap re-run with fuzzy on.
  bool _fuzzyFallbackOffered = false;
  // Demozoo party note for a single-tag browse (null = not a party / no note).
  String? _tagNote;
  bool _tagNoteExpanded = false;
  bool    _loading       = false;
  bool    _loadingMore   = false;
  bool    _albumsLoading = false;
  String? _error;

  List<ArtistResult> _artistResults = []; // Artistes tab — search_artists RPC
  bool               _artistsLoading = false;
  List<_AlbumId>   _albums      = [];
  List<Collection> _collections = [];
  List<Playlist>   _playlists   = [];
  bool             _playlistsLoaded   = false;
  bool             _playlistsLoading  = false;
  // Productions tab (search_productions, migs 161-163) — same lazy shape as
  // the playlists tab: loaded when the tab is first opened for a query.
  List<ProductionSearchRow> _productions = [];
  bool _productionsLoaded  = false;
  bool _productionsLoading = false;
  int  _productionTotal = -1, _productionOffset = 0;
  bool _productionHasMore = false, _productionLoadingMore = false;

  // Groups tab (search_groups, mig 201). TEXT ONLY: that RPC takes no facet —
  // no collection, no year, no tag — so a facet-only browse leaves it empty
  // rather than showing a whole-catalogue list the filters did not touch.
  List<GroupSearchResult> _groups = [];
  bool _groupsLoaded = false, _groupsLoading = false;
  int  _groupTotal = -1, _groupOffset = 0;
  bool _groupHasMore = false, _groupLoadingMore = false;
  String _groupsQuery = '';

  // Per-tab pagination (Artistes / Albums / Playlists) — mirrors the Tous tab's
  // _totalCount/_offset/_hasMore. total = server total_count (1st row), -1 unknown.
  static const int _kEntityPage = 50;
  int  _artistTotal = -1,  _artistOffset = 0;
  /// `search_artists` a BORNÉ son décompte: `_artistTotal` est un plancher.
  bool _artistTotalIsFloor = false;
  bool _artistHasMore = false, _artistLoadingMore = false;
  int  _albumTotal = -1,   _albumOffset = 0;
  bool _albumHasMore = false, _albumLoadingMore = false;
  int  _playlistTotal = -1, _playlistOffset = 0;
  bool _playlistHasMore = false, _playlistLoadingMore = false;

  // Tag facet category SLUGS, fetched once from the server (labels are
  // localized at build time via _categoryLabel). Falls back to the static list
  // until loaded (or if the RPC is unavailable).
  List<String> _tagCategories = _kTagCategoriesFallback;

  @override
  void initState() {
    super.initState();
    RewampDb.serverLacksChanged.addListener(_onServerCapabilities);
    _tabs = TabController(length: _Tab.values.length, vsync: this);
    _tabs.addListener(_onTabChanged);
    widget.resetTick?.addListener(_resetAllCriteria);
    _loadCollections();
    _loadTagCategories();
    // Pushed as a tag browse: seed the tag facet and run the cross-entity
    // search so all tabs (songs/artists/albums) populate on open.
    if (widget.initialTags.isNotEmpty) {
      _selectedTags
          .addAll(widget.initialTags.map((n) => TagItem(
              slug: n, name: n, category: widget.initialTagCategory)));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search('');
      });
      // Single-tag browse: the tag may be a demoparty — fetch its demozoo
      // note (cheap PostgREST read, null for non-party tags) for the banner.
      if (widget.initialTags.length == 1) {
        RewampDb.getPartyNotes(widget.initialTags.first).then((n) {
          if (mounted && n != null) setState(() => _tagNote = n);
        });
      }
    }
  }

  /// Clears every search criterion and returns to the browse landing.
  /// Triggered by re-selecting the search tab while already on it.
  void _resetAllCriteria() {
    if (!mounted) return;
    _debounce?.cancel();
    _controller.clear();
    _currentQuery = '';
    _resultsNotifier.value = [];
    setState(() {
      _selectedTags.clear();
      _yearMin = null;
      _yearMax = null;
      _ratingMin = 0;
      _podium = null;
      _collectionFilter = null;
      _formatFilter = null;
      _platformFilter = null;
      _sortDir = null;
      _facets = [];
      _fuzzyFallbackOffered = false;
      // Back to the persisted mode: the "did you mean" fallback flips _exact
      // to fuzzy for ONE query — a tab reset must not keep that leak alive.
      _exact = UserSettings.instance.searchExact;
      _tagNote = null;
      _tagNoteExpanded = false;
      _sortBy = 'relevance';
      _loading = false;
      _albumsLoading = false;
      _loadingMore = false;
      _totalCount = 0;
      _offset = 0;
      _hasMore = false;
      _error = null;
      _albums = [];
      _artistResults = [];
      _artistsLoading = false;
      _playlists = [];
      _playlistsLoaded = false;
      _productions = [];
      _productionsLoaded = false;
      _groups = []; _groupsLoaded = false; _groupsLoading = false;
      _groupTotal = -1; _groupOffset = 0; _groupHasMore = false; _groupLoadingMore = false;
      _artistTotal = -1; _artistTotalIsFloor = false;
      _artistOffset = 0; _artistHasMore = false; _artistLoadingMore = false;
      _albumTotal = -1; _albumOffset = 0; _albumHasMore = false; _albumLoadingMore = false;
      _playlistTotal = -1; _playlistOffset = 0; _playlistHasMore = false; _playlistLoadingMore = false;
      _productionTotal = -1; _productionOffset = 0; _productionHasMore = false; _productionLoadingMore = false;
    });
  }

  bool _tagCategoriesFromServer = false;

  Future<void> _loadTagCategories() async {
    try {
      final slugs = await RewampDb.listTagCategories();
      if (!mounted || slugs.isEmpty) return;
      setState(() {
        _tagCategoriesFromServer = true;
        _tagCategories = slugs;
      });
    } catch (_) {
      // Keep the static fallback; retried when the browse landing rebuilds.
    }
  }

  void _onTabChanged() {
    // The source filter belongs to the playlists tab alone, so its bar has to
    // appear and disappear with the tab — hence a rebuild here, which the tab
    // switch did not trigger on its own.
    if (mounted) setState(() {});
    // Load the playlists (browse list or query matches) when the tab opens.
    if (_tabs.index == _Tab.playlists.index && !_playlistsLoaded) {
      _loadPlaylists(_currentQuery);
    }
    if (_tabs.index == _Tab.productions.index && !_productionsLoaded) {
      _loadProductions(_currentQuery);
    }
    if (_tabs.index == _Tab.groups.index && !_groupsLoaded) {
      _loadGroups(_currentQuery);
    }
  }

  /// The one facet a production CAN be filtered by: its group. `tags[]` does
  /// not exist on the production RPCs (a production is not tagged, it is
  /// released BY a group), so a group tag has to travel as `group_name` on
  /// list_productions — matched `lower(g) = lower(group_name)`, exact, on the
  /// tag NAME ("Future Crew"), never the slug. Every other tag category (party,
  /// chip, country…) has no production-side equivalent and is ignored here.
  /// Only one can be sent, so a multi-group selection keeps the first.
  String? get _productionGroupName {
    for (final t in _selectedTags) {
      if (t.category == 'group' && t.name.trim().isNotEmpty) return t.name;
    }
    return null;
  }

  /// Same shape as _playlistCacheKey: the tab reloads when ANY criterion that
  /// reaches the production RPCs moves, not just the text.
  String get _productionCacheKey =>
      [_currentQuery, _exact, _productionGroupName, _yearMin, _yearMax].join(' ');

  /// Demozoo productions for the current criteria.
  ///
  /// Two RPCs, and picking the wrong one is what made this tab come back empty
  /// on a group browse: `search_productions` is TEXT-ONLY, so a tag browse —
  /// which arrives with an empty query and the group in `_selectedTags` — hit
  /// the `q.isEmpty` bail-out and showed nothing. When a group tag is selected
  /// the tab goes through `list_productions(group_name:)` instead, which is the
  /// only RPC that can filter productions by group (and also takes the year
  /// range). Plain text with no group keeps `search_productions`, whose rows
  /// the server disambiguates (group + year) for the search tab.
  Future<void> _loadProductions(String q, {int offset = 0}) async {
    final group = _productionGroupName;
    final key   = _productionCacheKey;
    if (q.trim().isEmpty && group == null) {
      setState(() {
        _productions = [];
        _productionTotal = 0;
        _productionHasMore = false;
        _productionsQuery = key;
        _productionsLoaded = true;
      });
      return;
    }
    if (offset == 0 && (_productionsLoading ||
        (_productionsLoaded && _productionsQuery == key))) {
      return;
    }
    if (offset == 0) setState(() => _productionsLoading = true);
    final rows = group != null
        ? await RewampDb.listProductions(
            query:    q.trim().isEmpty ? null : q.trim(),
            group:    group,
            fuzzy:    !_exact,
            yearMin:  _yearMin,
            yearMax:  _yearMax,
            limit:    _kEntityPage,
            offset:   offset,
          )
        : await RewampDb.searchProductions(q,
            fuzzy: !_exact, limit: _kEntityPage, offset: offset);
    if (!mounted || key != _productionCacheKey) {
      if (mounted) {
        setState(() {
          _productionsLoading = false;
          _productionLoadingMore = false;
        });
      }
      return;
    }
    setState(() {
      _productions = offset == 0 ? rows : [..._productions, ...rows];
      if (offset == 0) {
        _productionTotal = rows.isEmpty ? 0 : rows.first.totalCount;
      }
      _productionOffset = _productions.length;
      _productionHasMore = rows.length >= _kEntityPage;
      _productionsQuery = key;
      _productionsLoaded = true;
      _productionsLoading = false;
      _productionLoadingMore = false;
    });
  }

  Future<void> _loadMoreProductions() async {
    if (_productionLoadingMore || !_productionHasMore) return;
    setState(() => _productionLoadingMore = true);
    await _loadProductions(_currentQuery, offset: _productionOffset);
  }

  /// Groups matching the text (`search_groups`). Server-ranked — the rows are
  /// used in the order they arrive, never re-sorted. `only_with_content` is
  /// left OFF so a group that only exists through its productions still shows
  /// up; its screen opens on Productions.
  Future<void> _loadGroups(String q, {int offset = 0}) async {
    final key = [q, _exact].join(' ');
    if (q.trim().isEmpty) {
      setState(() {
        _groups = [];
        _groupTotal = 0;
        _groupHasMore = false;
        _groupsQuery = key;
        _groupsLoaded = true;
        _groupsLoading = false;
      });
      return;
    }
    if (offset == 0 &&
        (_groupsLoading || (_groupsLoaded && _groupsQuery == key))) {
      return;
    }
    if (offset == 0) setState(() => _groupsLoading = true);
    final rows = await RewampDb.searchGroups(q,
        fuzzy: !_exact, limit: _kEntityPage, offset: offset);
    if (!mounted || _currentQuery != q) {
      if (mounted) {
        setState(() { _groupsLoading = false; _groupLoadingMore = false; });
      }
      return;
    }
    setState(() {
      _groups = offset == 0 ? rows : [..._groups, ...rows];
      // total_count is -1 from the second page on (the server only counts the
      // first) — keep page 0's total instead of clobbering it with the sentinel.
      if (offset == 0) _groupTotal = rows.isEmpty ? 0 : rows.first.totalCount;
      _groupOffset      = _groups.length;
      _groupHasMore     = rows.length >= _kEntityPage;
      _groupsQuery      = key;
      _groupsLoaded     = true;
      _groupsLoading    = false;
      _groupLoadingMore = false;
    });
  }

  Future<void> _loadMoreGroups() async {
    if (_groupLoadingMore || !_groupHasMore) return;
    setState(() => _groupLoadingMore = true);
    await _loadGroups(_currentQuery, offset: _groupOffset);
  }

  String _productionsQuery = '';   // _productionCacheKey the rows were fetched for

  String _playlistsQuery = '';   // query the current _playlists match

  /// Playlists tab only — `list_playlists` p_source (migration 199): null =
  /// everything, 'user' = playlists published by people, 'server' = ours.
  /// Filtering client-side was not an option: user playlists are a handful
  /// among 4600+ server ones, so a page would come back almost empty.
  String? _playlistSource;

  /// Server-side playlist search (list_playlists `q` = name filter);
  /// empty query → first page of the catalogue.
  // Cache key = q + the whole filter set, so a tag/collection/… change with the
  // SAME (possibly empty) q still triggers a reload of the playlists tab.
  String get _playlistCacheKey => [
        _currentQuery, _exact, _collectionFilter, _platformFilter, _formatFilter,
        _yearMin, _yearMax, _ratingMin, _playlistSource, ..._tagNames,
      ].join(' ');

  Future<void> _loadPlaylists(String q, {int offset = 0}) async {
    final key = _playlistCacheKey;
    // The cache guard applies to first-page loads only; a loadMore (offset > 0)
    // must proceed even though the tab is "loaded".
    if (offset == 0 &&
        (_playlistsLoading || (_playlistsLoaded && _playlistsQuery == key))) {
      return;
    }
    // Only the first page swaps the tab to a full-screen spinner; a loadMore
    // (offset > 0) keeps the list and shows the trailing spinner instead.
    if (offset == 0) setState(() => _playlistsLoading = true);
    try {
      // Same fuzzy toggle as the song/album search for consistency; falls
      // back cleanly while the server hasn't got the parameter yet.
      final pls = await RewampDb.listPlaylists(
          query: q.isEmpty ? null : q, fuzzy: !_exact,
          source: _playlistSource,
          // Pas (encore) de p_collections sur listPlaylists — slug seul,
          // une famille y vaut « toutes » (priorité 2 de la proposition).
          collection: _collectionParams.$1, collections: _collectionParams.$2,
          platform: _platformFilter,
          formatFilter: _formatFilter, tags: _tagNames, tagCategories: _tagCategoriesFilter,
          yearMin: _yearMin, yearMax: _yearMax,
          ratingMin: _ratingMin > 0 ? _ratingMin : null,
          sortDir: _sortDir, limit: _kEntityPage, offset: offset);
      if (!mounted || key != _playlistCacheKey) {
        if (mounted) setState(() { _playlistsLoading = false; _playlistLoadingMore = false; });
        return;
      }
      setState(() {
        _playlists = offset == 0 ? pls : [..._playlists, ...pls];
        if (offset == 0) _playlistTotal = pls.isEmpty ? 0 : pls.first.totalCount;
        _playlistOffset = _playlists.length;
        _playlistHasMore = pls.length >= _kEntityPage;
        _playlistsQuery = key;
        _playlistsLoaded = true;
        _playlistsLoading = false;
        _playlistLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() { _playlistsLoading = false; _playlistLoadingMore = false; });
    }
  }

  Future<void> _loadMorePlaylists() async {
    if (_playlistLoadingMore || !_playlistHasMore) return;
    setState(() => _playlistLoadingMore = true);
    await _loadPlaylists(_currentQuery, offset: _playlistOffset);
  }

  /// Direct play (▶ button on a playlist row): whole ranked playlist.
  Future<void> _playPlaylistNow(BuildContext ctx, Playlist pl) async {
    try {
      final tracks = await RewampDb.playlistTracks(pl.id);
      if (!ctx.mounted || tracks.isEmpty) return;
      await widget.onPlayAlbum?.call(ctx, tracks);
    } catch (_) {}
  }

  Future<void> _openPlaylist(BuildContext ctx, Playlist pl) async {
    // Open the track list (single play + per-row queue options) instead of
    // blindly playing the whole playlist.
    await Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => PlaylistTracksScreen(
        playlist:    pl,
        onTap:       _onSongTap,
        onPlayAlbum: widget.onPlayAlbum,
      ),
    ));
  }

  Future<void> _loadCollections() async {
    try {
      final cols = await RewampDb.fetchCollections();
      if (mounted) {
        setState(() => _collections = cols.where((c) => c.filesCount > 0).toList());
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    widget.resetTick?.removeListener(_resetAllCriteria);
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _controller.dispose();
    _tagSearchCtrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    _resultsNotifier.dispose();
    RewampDb.serverLacksChanged.removeListener(_onServerCapabilities);
    super.dispose();
  }

  // ---- Search ---------------------------------------------------------------

  /// The server turned out not to know `p_podium` (404, migration not yet
  /// applied): the page just shown was filtered client-side (RewampDb), but
  /// paging an unapplied filter would be a lie — say so, clear it, and run the
  /// search again. The chip stays hidden for the session.
  void _onServerCapabilities() {
    if (!mounted || _podium == null || !RewampDb.serverLacks('p_podium')) return;
    setState(() => _podium = null);
    AppSnack.show(context, context.l10n.searchPodiumUnavailable);
    _search(_controller.text.trim());
  }

  // Facet filters that make an empty-text query meaningful (browse path).
  bool get _hasFacets =>
      _selectedTags.isNotEmpty ||
      _yearMin != null ||
      _yearMax != null ||
      _ratingMin > 0 ||
      _podium != null ||
      _formatFilter != null ||
      _platformFilter != null;

  // A search is active when there's text OR at least one facet selected.
  bool get _hasActiveSearch => _currentQuery.isNotEmpty || _hasFacets;

  // One page of results. With a text query → search_music (FTS); facet-only
  // (no text) → browse_music (metadata filter, no FTS). Both carry the facets.
  Future<List<SearchResult>> _fetchPage(String q, int offset,
      {String? sortBy, String? seed}) {
    final sort = sortBy ?? _sortBy;
    final rndSeed = sort == 'random' ? (seed ?? _radioSeed) : null;
    if (q.isNotEmpty) {
      return RewampDb.search(
        q, fuzzy: !_exact, sortBy: sort, sortDir: _sortDir,
        collection: _collectionParams.$1, collections: _collectionParams.$2,
        tags: _tagNames, tagCategories: _tagCategoriesFilter,
        formatFilter: _formatFilter, platform: _platformFilter,
        yearMin: _yearMin, yearMax: _yearMax,
        ratingMin: _ratingMin > 0 ? _ratingMin : null,
        podium: _podium,
        seed: rndSeed,
        limit: 50, offset: offset,
      );
    }
    return RewampDb.browse(
      collection: _collectionParams.$1, collections: _collectionParams.$2,
      tags: _tagNames, tagCategories: _tagCategoriesFilter,
      formatFilter: _formatFilter, platform: _platformFilter,
      yearMin: _yearMin, yearMax: _yearMax,
      ratingMin: _ratingMin > 0 ? _ratingMin : null,
      podium: _podium,
      seed: rndSeed,
      sortBy: sort == 'relevance' ? 'name' : sort, sortDir: _sortDir,
      limit: 50, offset: offset,
    );
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      // No text: still search if facets are selected (facet-only browse), else clear.
      if (_hasFacets) {
        _debounce = Timer(const Duration(milliseconds: 300), () => _search(''));
      } else {
        _currentQuery = '';
        _resultsNotifier.value = [];
        setState(() {
          _loading = false; _albumsLoading = false;
          _totalCount = 0; _offset = 0; _hasMore = false; _error = null;
          _albums = []; _artistResults = []; _playlists = [];
          _productions = []; _productionsLoaded = false;
          _groups = []; _groupsLoaded = false;
          _artistTotal = -1; _albumTotal = -1; _playlistTotal = -1; _productionTotal = -1;
          _groupTotal = -1; _groupHasMore = false;
          _artistHasMore = false; _albumHasMore = false; _playlistHasMore = false;
          _productionHasMore = false;
        });
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 650), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    _currentQuery = q;
    if (q.isEmpty && !_hasFacets) {
      _resultsNotifier.value = [];
      setState(() {
        _loading = false; _albumsLoading = false;
        _totalCount = 0; _offset = 0; _hasMore = false; _error = null;
        _albums = []; _artistResults = []; _playlists = [];
        _productions = []; _productionsLoaded = false;
        _groups = []; _groupsLoaded = false;
        _artistTotal = -1; _albumTotal = -1; _playlistTotal = -1; _productionTotal = -1;
        _groupTotal = -1; _groupHasMore = false;
        _localMatches = const []; _localTotal = -1;
        _artistHasMore = false; _albumHasMore = false; _playlistHasMore = false;
        _productionHasMore = false;
      });
      return;
    }
    setState(() {
      _loading = true; _albumsLoading = true; _artistsLoading = true;
      _error = null; _fuzzyFallbackOffered = false;
    });
    // Local: indépendant des RPCs — part en parallèle, s'affiche quand prêt.
    unawaited(_loadLocalMatches(q));
    // Fan-out: the other entity tabs (Artistes/Albums/Playlists) + the facet
    // counts resolve their own cross-entity RPC in parallel with the Songs page.
    // Fired for a text query AND for facet-only browse (empty q + tags/filters):
    // search_artists/search_albums/list_playlists all treat empty q as a browse
    // over the filter set (server-supported).
    _fetchFacets(q);
    if (q.isNotEmpty || _hasFacets) {
      _searchArtists(q);
      _searchAlbums(q);
      _loadPlaylists(q);  // q may be empty → tag/filter browse
      // Productions used to be lazy — loaded only when its tab was opened —
      // which is exactly what kept its "(N)" count hidden until you tapped it,
      // while every other tab advertised its total up front. One RPC, the same
      // page size as the three above, so the tab now carries its count from
      // the moment the results land. (_onTabChanged keeps its own call for the
      // case where the tab is opened without a search having run.)
      _loadProductions(q);
      // Groups: text only (search_groups takes no facet), so a facet-only
      // browse clears the tab instead of listing the whole catalogue.
      _loadGroups(q);
    } else {
      setState(() {
        _albums = []; _albumsLoading = false;
        _artistResults = []; _artistsLoading = false;
      });
    }
    try {
      final res = await _fetchPage(q, 0);
      if (!mounted || _currentQuery != q) return;
      // Record fruitful searches — text AND facet-only (tags/année/note/
      // collection). Facet queries are stored as JSON so tapping the recent
      // chip restores the full criteria; plain text stays plain (the prefix
      // collapse in addRecentSearch handles typing intermediates).
      if (res.isNotEmpty && (q.isNotEmpty || _hasFacets)) {
        UserSettings.instance.addRecentSearch(_encodeRecentQuery(q));
      }
      _resultsNotifier.value = res;
      _totalCount = res.isEmpty ? 0 : res.first.totalCount;
      _offset     = res.length;
      _hasMore    = _offset < _totalCount;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted || _currentQuery != q) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  /// Facet counts (format/platform/collection) for the current q+filters, from
  /// search_facets — feeds the Format/Platform dropdowns. Note: the server does
  /// NOT restrict a facet dimension by its own selected value, so a dropdown
  /// keeps all its options while that dimension is filtered.
  Future<void> _fetchFacets(String q) async {
    try {
      Future<List<FacetCount>> at(String? grain) => RewampDb.searchFacets(
        q,
        grain:        grain,
        fuzzy:        !_exact,
        // Famille dépliée en ses membres depuis la migration serveur 243: les
        // comptes portent enfin sur la famille et non sur tout le catalogue.
        collection:   _collectionParams.$1,
        collections:  _collectionParams.$2,
        platform:     _platformFilter,
        formatFilter: _formatFilter,
        tags:         _tagNames,
        tagCategories: _tagCategoriesFilter,
        yearMin:      _yearMin,
        yearMax:      _yearMax,
        ratingMin:    _ratingMin > 0 ? _ratingMin : null,
        podium:       _podium,
      );
      final both = await Future.wait([
        at(null),
        // Onglet Albums: la facette podium y compte des ALBUMS (p_grain), comme
        // search_albums — le compte du rang r égale alors son total_count.
        at('album').catchError((Object _) => const <FacetCount>[]),
      ]);
      if (!mounted || _currentQuery != q) return;
      setState(() { _facets = both[0]; _facetsAlbum = both[1]; });
    } catch (_) {/* leave prior facets */}
  }

  /// Artistes tab via search_artists RPC (cross-entity: name ∪ song ∪ album).
  /// offset 0 = first page (replace); offset > 0 = append (infinite scroll).
  Future<void> _searchArtists(String q, {int offset = 0}) async {
    try {
      final res = await RewampDb.searchArtists(
        q,
        fuzzy:        !_exact,
        // Famille dépliée (mig serveur 247). ⚠️ Le serveur filtre sur les
        // MORCEAUX connectés et rend une UNION: sc68 157 + zxart 16 = 173
        // artistes, pas 173 par addition.
        collection:   _collectionParams.$1,
        collections:  _collectionParams.$2,
        platform:     _platformFilter,
        formatFilter: _formatFilter,
        tags:         _tagNames,
        tagCategories: _tagCategoriesFilter,
        yearMin:      _yearMin,
        yearMax:      _yearMax,
        ratingMin:    _ratingMin > 0 ? _ratingMin : null,
        sortDir:      _sortDir,
        limit:        _kEntityPage,
        offset:       offset,
      );
      if (!mounted || _currentQuery != q) return;
      setState(() {
        _artistResults = offset == 0 ? res : [..._artistResults, ...res];
        // total_count is only sent for the first page (offset 0); it's -1 on
        // later pages, so keep the page-0 total for the label and DON'T clobber it.
        if (offset == 0) {
          _artistTotal = res.isEmpty ? 0 : res.first.totalCount;
          _artistTotalIsFloor = res.isNotEmpty && res.first.totalTruncated;
        }
        _artistOffset  = _artistResults.length;
        // Drive hasMore off "was this page full?" — robust when total_count is
        // unknown (-1) on paginated pages. A short/empty page = end of results.
        _artistHasMore = res.length >= _kEntityPage;
        _artistsLoading = false;
        _artistLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() { _artistsLoading = false; _artistLoadingMore = false; });
    }
  }

  Future<void> _loadMoreArtists() async {
    if (_artistLoadingMore || !_artistHasMore) return;
    setState(() => _artistLoadingMore = true);
    await _searchArtists(_currentQuery, offset: _artistOffset);
  }

  /// Dedicated album search via search_albums RPC (partial name match).
  /// offset 0 = first page (replace); offset > 0 = append (infinite scroll).
  Future<void> _searchAlbums(String q, {int offset = 0}) async {
    try {
      final res = await RewampDb.searchAlbums(
        q,
        podium:       _podium,
        fuzzy:        !_exact,
        collection:   _collectionParams.$1,
        collections:  _collectionParams.$2,
        platform:     _platformFilter,
        formatFilter: _formatFilter,
        tags:         _tagNames,
        tagCategories: _tagCategoriesFilter,
        yearMin:      _yearMin,
        yearMax:      _yearMax,
        ratingMin:    _ratingMin > 0 ? _ratingMin : null,
        sortDir:      _sortDir,
        limit:        _kEntityPage,
        offset:       offset,
      );
      if (!mounted || _currentQuery != q) return;
      final albums = res
          .map((a) => _AlbumId(a.name, a.collection, a.platform, a.artworkUrl, a.aliases, a.albumId, a.artistNames, a.format, a.fileSize, a.matchReason, a.hasVideo, a.podium, a.rating, a.popularity))
          .toList();
      setState(() {
        _albums       = offset == 0 ? albums : [..._albums, ...albums];
        if (offset == 0) _albumTotal = res.isEmpty ? 0 : res.first.totalCount;
        _albumOffset  = _albums.length;
        _albumHasMore = res.length >= _kEntityPage;
        _albumsLoading = false;
        _albumLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() { _albumsLoading = false; _albumLoadingMore = false; });
    }
  }

  Future<void> _loadMoreAlbums() async {
    if (_albumLoadingMore || !_albumHasMore) return;
    setState(() => _albumLoadingMore = true);
    await _searchAlbums(_currentQuery, offset: _albumOffset);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || !_hasActiveSearch) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _fetchPage(_currentQuery, _offset);
      if (!mounted) return;
      final next = [..._resultsNotifier.value, ...more];
      _resultsNotifier.value = next;
      _offset  += more.length;
      _hasMore  = _offset < _totalCount;
      setState(() => _loadingMore = false);
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ---- Sort -----------------------------------------------------------------

  // Cycles the sort_by contract:
  // relevance → name → popularity → rating → year → random.
  //
  // `rating` n'a de sens que depuis les migrations serveur 207/208, qui
  // remplissent enfin la colonne (elle était NULL partout). Les notés d'abord,
  // les non-notés en queue — c'est le serveur qui l'ordonne.
  void _toggleSort() {
    setState(() {
      _sortBy = switch (_sortBy) {
        'relevance'  => 'name',
        'name'       => 'popularity',
        'popularity' => 'rating',
        'rating'     => 'year',
        'year'       => 'random',
        _            => 'relevance',
      };
      if (_sortBy == 'random') {
        _radioSeed = DateTime.now().millisecondsSinceEpoch.toString();
      }
    });
    if (_hasActiveSearch) _search(_currentQuery);
  }

  // Flip sort direction (null = server default per sort_by → first tap makes it
  // explicit). Hidden for relevance/random where direction is meaningless.
  void _toggleSortDir() {
    setState(() => _sortDir = (_sortDir == 'asc') ? 'desc' : 'asc');
    if (_hasActiveSearch) _search(_currentQuery);
  }

  bool get _sortDirMeaningful =>
      _sortBy != 'relevance' && _sortBy != 'random';

  static ({IconData icon, String label}) _sortMeta(
          String sortBy, AppLocalizations l10n) =>
      switch (sortBy) {
    'name'       => (icon: Icons.sort_by_alpha,  label: l10n.sortAZ),
    'popularity' => (icon: Icons.trending_up,    label: l10n.searchSortPopular),
    'rating'     => (icon: Icons.star_outline,   label: l10n.searchSortRating),
    'year'       => (icon: Icons.calendar_today, label: l10n.searchSortYear),
    'random'     => (icon: Icons.shuffle,        label: l10n.searchSortRandom),
    _            => (icon: Icons.auto_awesome,   label: l10n.sortRelevance),
  };

  // ---- Collection filter ----------------------------------------------------

  /// Le filtre déplié pour les RPC: (slug unique, liste de membres).
  ///
  /// `_collectionFilter` porte soit un slug, soit le sentinel `family:<key>`
  /// (la ligne « joshw » du sélecteur, sélectionnable depuis la migration
  /// serveur 240). La famille se déplie ICI en ses membres — le serveur reste
  /// ignorant du regroupement, il reçoit `p_collections` — et le repli est
  /// déjà dans le transport (`_postJsonOptional` rejoue sans le paramètre sur
  /// un serveur antérieur).
  ///
  /// Depuis la migration serveur 247, les HUIT RPC qui avaient
  /// `collection_slug` prennent aussi `p_collections`: plus aucun appelant ne
  /// se contente du slug seul. ⚠️ Restent SANS paramètre de collection, et ce
  /// n'est pas un oubli: `list_tags` n'en a jamais eu, et le hub
  /// (`get_collection_overview`, `list_collection_groups`) est mono-slug par
  /// nature — un hub EST une collection.
  ///
  /// ⚠️ Deux sémantiques serveur à ne pas confondre avec un bug:
  ///  - `search_facets` ne filtre PAS la facette collection elle-même, sinon
  ///    on ne pourrait plus en changer depuis le menu.
  ///  - `search_artists` rend une UNION, pas une somme: sc68 157 + zxart 16
  ///    donne 173 artistes, un même artiste des deux collections ne comptant
  ///    qu'une fois.
  (String?, List<String>?) get _collectionParams {
    final f = _collectionFilter;
    if (f == null) return (null, null);
    if (f.startsWith('family:')) {
      final key = f.substring('family:'.length);
      return (
        null,
        [
          for (final c in _collections)
            if (collectionFamilyOf(c.slug)?.key == key) c.slug,
        ],
      );
    }
    return (f, null);
  }

  void _setCollectionFilter(String? slug) {
    // slug == null → all collections. Picks come from the bottom sheet, so set
    // the chosen value directly (no toggle).
    if (_collectionFilter == slug) return;
    setState(() => _collectionFilter = slug);
    if (_hasActiveSearch) _search(_currentQuery);
  }

  // Display label for the current collection filter (the pill text).
  String get _currentCollectionLabel {
    final f = _collectionFilter;
    if (f == null) return context.l10n.searchCollectionAll;
    if (f.startsWith('family:')) {
      final key = f.substring('family:'.length);
      for (final fam in kCollectionFamilies) {
        if (fam.key == key) return fam.label;
      }
      return key;
    }
    for (final c in _collections) {
      if (c.slug == f) {
        return c.name.isNotEmpty ? c.name : c.slug;
      }
    }
    return f;
  }

  // ---- Filters --------------------------------------------------------------

  bool get _hasActiveFilters => _hasFacets || _exact;

  // Year facet slider bounds (chip music: nothing meaningful before 1980).
  static const double _kYearLo = 1980;
  static const double _kYearHi = 2026;

  Future<void> _showFilterSheet({String? initialCategory}) async {
    final l10n = context.l10n;
    bool exact = _exact;
    var yearRange = RangeValues(
      (_yearMin ?? _kYearLo.toInt()).toDouble().clamp(_kYearLo, _kYearHi),
      (_yearMax ?? _kYearHi.toInt()).toDouble().clamp(_kYearLo, _kYearHi),
    );
    double ratingMin = _ratingMin;
    final sel = List<TagItem>.from(_selectedTags); // working copy
    final tagCtrl = _tagSearchCtrl..clear(); // screen-owned; cleared per open
    final cats = _tagCategories; // snapshot of loaded facet category slugs
    String category =
        (initialCategory != null && cats.contains(initialCategory))
            ? initialCategory
            : cats.first; // active facet
    List<TagItem> suggestions = [];
    int reqId = 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> fetchTags(String q) async {
            final id = ++reqId;
            try {
              final res = await RewampDb.listTags(
                  query: q, category: category, byUsage: true, limit: 40);
              if (id != reqId) return; // stale
              setSheet(() => suggestions = res
                  .where((t) => !sel.any((s) => s.slug == t.slug))
                  .toList());
            } catch (_) {}
          }

          void addTag(TagItem t) {
            if (sel.any((s) => s.slug == t.slug)) return;
            setSheet(() {
              sel.add(t);
              suggestions.removeWhere((s) => s.slug == t.slug);
            });
          }

          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.85,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text(l10n.searchFilters,
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 20),

                // ── Recherche exacte ──────────────────────────────────────
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.searchExactSearch),
                  subtitle: Text(l10n.searchExactSearchSubtitle),
                  value: exact,
                  onChanged: (v) => setSheet(() => exact = v),
                ),
                const SizedBox(height: 12),

                // ── Tags (facettes par catégorie) ─────────────────────────
                Text(l10n.searchTags,
                    style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 8),
                if (sel.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final t in sel)
                        InputChip(
                          label: Text(t.name),
                          onDeleted: () =>
                              setSheet(() => sel.removeWhere((s) => s.slug == t.slug)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Category selector (facet key).
                Wrap(
                  spacing: 6,
                  children: [
                    for (final c in cats)
                      ChoiceChip(
                        label: Text(_categoryLabel(c, l10n)),
                        selected: category == c,
                        onSelected: (_) {
                          setSheet(() {
                            category = c;
                            suggestions = [];
                          });
                          fetchTags(tagCtrl.text.trim());
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                CancelField(
                  controller: tagCtrl,
                  onCleared: fetchTags,
                  builder: (_) => TextField(
                    controller: tagCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n
                          .searchTagSearchHint(_categoryLabel(category, l10n)),
                      prefixIcon: const Icon(Icons.tag, size: 18),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: fetchTags,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: suggestions.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              l10n.searchTagTypeToSearch,
                              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(ctx).colorScheme.outline),
                            ),
                          )
                        : Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final t in suggestions)
                                ActionChip(
                                  label: Text(t.name),
                                  onPressed: () => addTag(t),
                                ),
                            ],
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.searchTagsAndLogic,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.outline),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Année (bornes incluses; exclut les morceaux non datés) ─
                Row(
                  children: [
                    Text(l10n.searchFilterYear,
                        style: Theme.of(ctx).textTheme.labelLarge),
                    const SizedBox(width: 8),
                    Text(
                      (yearRange.start <= _kYearLo && yearRange.end >= _kYearHi)
                          ? l10n.searchFilterAll
                          : l10n.searchYearRange(
                              yearRange.start.round(), yearRange.end.round()),
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.outline),
                    ),
                  ],
                ),
                RangeSlider(
                  values: yearRange,
                  min: _kYearLo,
                  max: _kYearHi,
                  divisions: (_kYearHi - _kYearLo).toInt(),
                  labels: RangeLabels('${yearRange.start.round()}',
                      '${yearRange.end.round()}'),
                  onChanged: (v) => setSheet(() => yearRange = v),
                ),
                if (!(yearRange.start <= _kYearLo && yearRange.end >= _kYearHi))
                  Text(
                    l10n.searchYearFilterNote,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.outline),
                  ),
                const SizedBox(height: 8),

                // ── Note minimale (rating dérivé des écoutes) ──────────────
                Row(
                  children: [
                    Text(l10n.searchMinRating,
                        style: Theme.of(ctx).textTheme.labelLarge),
                    const SizedBox(width: 8),
                    Text(
                      ratingMin <= 0
                          ? l10n.searchFilterAll
                          : l10n.searchRatingValue(ratingMin.toStringAsFixed(1)),
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.outline),
                    ),
                  ],
                ),
                Slider(
                  value: ratingMin,
                  min: 0,
                  max: 5,
                  divisions: 10,
                  label: ratingMin <= 0
                      ? l10n.searchFilterAll
                      : ratingMin.toStringAsFixed(1),
                  onChanged: (v) => setSheet(() => ratingMin = v),
                ),
                      ],
                    ),
                  ),
                ),
                // ── Actions (sticky footer — stays visible however many tags
                // push the filter list off-screen; icons so it stays compact) ─
                Material(
                  color: Theme.of(ctx).colorScheme.surface,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 12,
                      ),
                      child: LayoutBuilder(
                        builder: (ctx, box) {
                          // Portrait mobile: 3 labeled buttons overflow/wrap
                          // ugly ("Réinitialiser" alone is ~110px). Below the
                          // threshold, icon-only + Tooltip instead.
                          final compact = box.maxWidth < 380;

                          void doCancel() => Navigator.pop(ctx); // discard, no apply
                          void doReset() => setSheet(() {
                                sel.clear();
                                tagCtrl.clear();
                                suggestions = [];
                                // Reset = back to the DEFAULTS, and the default
                                // search mode is EXACT (searchExact ?? true) —
                                // `false` here flipped the persisted setting to
                                // fuzzy on every filter reset + apply.
                                exact = true;
                                yearRange = const RangeValues(_kYearLo, _kYearHi);
                                ratingMin = 0;
                              });
                          void doApply() {
                            setState(() {
                              _selectedTags
                                ..clear()
                                ..addAll(sel);
                              _exact = exact;
                              // Full-range slider = no year filter (avoid
                              // excluding the many undated songs by default).
                              _yearMin = yearRange.start.round() <= _kYearLo
                                  ? null
                                  : yearRange.start.round();
                              _yearMax = yearRange.end.round() >= _kYearHi
                                  ? null
                                  : yearRange.end.round();
                              _ratingMin = ratingMin;
                            });
                            UserSettings.instance.searchExact = exact; // persist
                            Navigator.pop(ctx);
                            // Re-run with the current text; facet-only (empty
                            // text) is a valid search via browse_music.
                            _search(_controller.text.trim());
                          }

                          if (compact) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Tooltip(
                                  message: l10n.searchCancel,
                                  child: IconButton.filledTonal(
                                    onPressed: doCancel,
                                    icon: const Icon(Icons.close),
                                  ),
                                ),
                                Tooltip(
                                  message: l10n.searchReset,
                                  child: IconButton.outlined(
                                    onPressed: doReset,
                                    icon: const Icon(Icons.refresh),
                                  ),
                                ),
                                Tooltip(
                                  message: l10n.searchApply,
                                  child: IconButton.filled(
                                    onPressed: doApply,
                                    icon: const Icon(Icons.check),
                                  ),
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: doCancel,
                                  icon: const Icon(Icons.close, size: 18),
                                  label: Text(l10n.searchCancel),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: doReset,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: Text(l10n.searchReset),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: doApply,
                                  icon: const Icon(Icons.check, size: 18),
                                  label: Text(l10n.searchApply),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    // tagCtrl is screen-owned (_tagSearchCtrl) → disposed in State.dispose(), not
    // here (avoids the swipe-dismiss "used after disposed" race).
  }

  // ---- Radio / surprise -------------------------------------------------------

  /// Radio ▶: random order over the current facets (text + tags + year + note
  /// + collection). Fixed seed ⇒ the 50-song queue is stable and repeat-free;
  /// with no facet at all this is a whole-catalogue radio.
  Future<void> _startRadio() async {
    _radioSeed = DateTime.now().millisecondsSinceEpoch.toString();
    try {
      final songs =
          await _fetchPage(_currentQuery, 0, sortBy: 'random', seed: _radioSeed);
      if (!mounted || songs.isEmpty) return;
      if (widget.onPlayAlbum != null) {
        await widget.onPlayAlbum!(context, songs);
      } else {
        await downloadAndPlay(context, songs.first, widget.onFileReady);
      }
    } catch (_) {}
  }

  /// 🎲: one random song within the current facets (fresh seed each tap).
  Future<void> _surpriseMe() async {
    final seed = '${DateTime.now().microsecondsSinceEpoch}';
    final ratingMin = _ratingMin > 0 ? _ratingMin : null;
    try {
      final songs = _currentQuery.isNotEmpty
          ? await RewampDb.search(
              _currentQuery, fuzzy: !_exact, sortBy: 'random', seed: seed,
              collection: _collectionParams.$1,
              collections: _collectionParams.$2,
              tags: _tagNames, tagCategories: _tagCategoriesFilter,
              formatFilter: _formatFilter, platform: _platformFilter,
              yearMin: _yearMin, yearMax: _yearMax, ratingMin: ratingMin,
              podium: _podium,
              limit: 1)
          : await RewampDb.browse(
              sortBy: 'random', seed: seed,
              collection: _collectionParams.$1,
              collections: _collectionParams.$2,
              tags: _tagNames, tagCategories: _tagCategoriesFilter,
              formatFilter: _formatFilter, platform: _platformFilter,
              yearMin: _yearMin, yearMax: _yearMax, ratingMin: ratingMin,
              podium: _podium,
              limit: 1);
      if (!mounted || songs.isEmpty) return;
      await downloadAndPlay(context, songs.first, widget.onFileReady);
    } catch (_) {}
  }

  // ---- Download + play ------------------------------------------------------

  Future<void> _onSongTap(BuildContext ctx, SearchResult r) =>
      downloadAndPlay(ctx, r, widget.onFileReady);

  // ---- Recent-search (de)serialization ---------------------------------------
  // Plain string = text-only query. JSON object = query with facets.

  String _encodeRecentQuery(String q) {
    if (!_hasFacets && _collectionFilter == null) return q;
    return jsonEncode({
      if (q.isNotEmpty) 'q': q,
      if (_selectedTags.isNotEmpty)
        'tags': _selectedTags.map((t) => t.name).toList(),
      // Parallel to 'tags' (same order, '' where unknown). A tag's category is
      // not decoration: it narrows tag resolution server-side, and it is what
      // routes the Productions tab to list_productions(group_name:). Restoring
      // a recent browse without it silently widened the search.
      if (_selectedTags.any((t) => t.category != null))
        'tcat': _selectedTags.map((t) => t.category ?? '').toList(),
      if (_yearMin != null) 'ymin': _yearMin,
      if (_yearMax != null) 'ymax': _yearMax,
      if (_ratingMin > 0) 'rmin': _ratingMin,
      if (_podium != null) 'pod': _podium,
      if (_collectionFilter != null) 'col': _collectionFilter,
    });
  }

  ({String label, bool hasFacets, void Function() apply}) _decodeRecentQuery(
      String stored) {
    Map<String, dynamic>? m;
    if (stored.startsWith('{')) {
      try {
        m = jsonDecode(stored) as Map<String, dynamic>;
      } catch (_) {}
    }
    if (m == null) {
      return (
        label: stored,
        hasFacets: false,
        apply: () {
          _controller.text = stored;
          _search(stored);
        },
      );
    }
    final q    = (m['q'] as String?) ?? '';
    final tags = (m['tags'] as List?)?.whereType<String>().toList() ?? const [];
    // Absent on entries saved before 'tcat' existed → every category null,
    // i.e. exactly the old behaviour.
    final tcat = (m['tcat'] as List?)?.whereType<String>().toList() ?? const [];
    final ymin = (m['ymin'] as num?)?.toInt();
    final ymax = (m['ymax'] as num?)?.toInt();
    final rmin = (m['rmin'] as num?)?.toDouble() ?? 0;
    final col  = m['col'] as String?;
    final label = [
      if (q.isNotEmpty) q,
      ...tags,
      if (ymin != null || ymax != null) '${ymin ?? '…'}–${ymax ?? '…'}',
      if (rmin > 0) '★≥${rmin.toStringAsFixed(1)}',
      if (col != null) col,
    ].join(' · ');
    return (
      label: label.isEmpty ? stored : label,
      hasFacets: true,
      apply: () {
        setState(() {
          _selectedTags
            ..clear()
            ..addAll([
              for (var i = 0; i < tags.length; i++)
                TagItem(
                  slug: tags[i],
                  name: tags[i],
                  category: (i < tcat.length && tcat[i].isNotEmpty)
                      ? tcat[i]
                      : null,
                ),
            ]);
          _yearMin = ymin;
          _yearMax = ymax;
          _ratingMin = rmin;
          _podium = podiumFromStored(m?['pod']);
          _collectionFilter = col;
        });
        _controller.text = q;
        _search(q);
      },
    );
  }

  // ---- Browse landing (Apple-Music-style, shown when no search is active) ----

  // One colour SYSTEM, not ten one-offs. Hues spread on the wheel so no two
  // categories collide (chip and production-type were both purple, developer
  // and origin both teal — and origin vs group was 25° with the same dark
  // end, twins on screen). Every gradient is analogous — same hue, both
  // stops SATURATED (bright → rich, never muddy): a darker-end-only pass was
  // tried and read as dull. Rough logic: cold hues = the MACHINE (origin
  // turquoise globe, arcade azure PCB, platform steel, year blue, chip
  // violet, production-type magenta), warm hues = the PEOPLE (party rose,
  // publisher amber, developer terminal-lime, group green). Platform is the
  // one deliberately DARK card (hardware slab).
  static ({IconData icon, List<Color> colors}) _categoryCardStyle(String slug) =>
      switch (slug) {
        'chip'            => (icon: Icons.memory,            colors: [const Color(0xFF8A3FFF), const Color(0xFF6414E8)]),
        'group'           => (icon: Icons.groups,            colors: [const Color(0xFF2ECC71), const Color(0xFF159A50)]),
        'party'           => (icon: Icons.celebration,       colors: [const Color(0xFFFF512F), const Color(0xFFDD2476)]),
        'year'            => (icon: Icons.calendar_month,    colors: [const Color(0xFF3D6DFF), const Color(0xFF2748F0)]),
        'production-type' => (icon: Icons.category_outlined, colors: [const Color(0xFFC239FF), const Color(0xFF9410D8)]),
        'origin'          => (icon: Icons.public,            colors: [const Color(0xFF00C9A7), const Color(0xFF00997F)]),
        'platform'        => (icon: Icons.devices_other,     colors: [const Color(0xFF3A6073), const Color(0xFF16222A)]),
        'arcade-board'    => (icon: Icons.developer_board,   colors: [const Color(0xFF00B0FF), const Color(0xFF0072D6)]),
        'publisher'       => (icon: Icons.storefront_outlined, colors: [const Color(0xFFFFB300), const Color(0xFFF57C00)]),
        'developer'       => (icon: Icons.code,              colors: [const Color(0xFFA0D93B), const Color(0xFF5FA315)]),
        _                 => (icon: Icons.sell_outlined,     colors: [const Color(0xFF536976), const Color(0xFF292E49)]),
      };

  Widget _buildBrowseLanding() {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    // The category list came from the static fallback (startup fetch failed,
    // e.g. offline launch) → retry so the full server set shows up.
    if (!_tagCategoriesFromServer) _loadTagCategories();

    return ListenableBuilder(
      listenable: UserSettings.instance,
      builder: (context, _) {
        final recents = UserSettings.instance.recentSearches;
        return ListView(
          padding: shellInset(context, const EdgeInsets.fromLTRB(16, 8, 16, 24)),
          children: [
            // Recent searches: single compact horizontal rail (scrolls to the
            // right, newest first), clear button at the end. Hidden when empty.
            if (recents.isNotEmpty) ...[
              SizedBox(
                height: 36,
                child: HorizontalScrollArrows(
                  builder: (ctx, controller) => ListView.separated(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  itemCount: recents.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (ctx, i) {
                    if (i == recents.length) {
                      return IconButton(
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                        tooltip: l10n.searchClearRecent,
                        visualDensity: VisualDensity.compact,
                        onPressed: UserSettings.instance.clearRecentSearches,
                      );
                    }
                    final r = _decodeRecentQuery(recents[i]);
                    return ActionChip(
                      avatar: Icon(
                          r.hasFacets ? Icons.sell_outlined : Icons.history,
                          size: 14),
                      label:
                          Text(r.label, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: r.apply,
                    );
                  },
                ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            Text(l10n.searchBrowse,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.9,
              ),
              // +5 leading cards: Collections, Productions (demozoo entities
              // since migs 161-163 — no longer a tag category), Albums,
              // Charts et Imports locaux.
              // La catégorie `origin` est ÉCARTÉE: trois tags en tout (Game /
              // Demoscene / AI Generated), une carte entière pour une liste de
              // trois lignes — la carte Albums prend sa place et la grille
              // reste à 12. Filtrée à l'affichage et non dans _tagCategories:
              // les puces de filtre de l'onglet Tags doivent continuer à la
              // proposer.
              itemCount:
                  _tagCategories.where((s) => s != 'origin').length + 5,
              itemBuilder: (ctx, i) {
                final cats =
                    _tagCategories.where((s) => s != 'origin').toList();
                if (i == 3) {
                  return _BrowseCard(
                    label: l10n.browseCharts,
                    icon: Icons.leaderboard_outlined,
                    // Indigo — hors de la roue des catégories, comme les
                    // autres cartes de tête; aucun voisin dans ces tons.
                    colors: const [Color(0xFF6366F1), Color(0xFF4338CA)],
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChartsScreen(
                        onTap:           _onSongTap,
                        onPlayAlbum:     widget.onPlayAlbum,
                        onQueueAdd:      widget.onQueueAdd,
                        onAlbumQueueAdd: widget.onAlbumQueueAdd,
                      ),
                    )),
                  );
                }
                if (i == 4) {
                  // « Sur cet appareil » — l'arbre des imports locaux
                  // (local_rel_path). Toujours affichée: l'écran vide guide
                  // vers les gestes d'import de l'accueil.
                  return _BrowseCard(
                    // « Imports locaux », pas « Sur cet appareil »: la carte
                    // ouvre l'arbre des IMPORTS — les téléchargements ont leur
                    // entrée dans l'onglet Local — et le nom doit dire ce
                    // qu'on va y trouver.
                    label: l10n.storageLocalImports,
                    icon: Icons.devices_outlined,
                    // Gris-bleu ardoise — hors de la roue des catégories,
                    // volontairement neutre: c'est le local, pas le catalogue.
                    colors: const [Color(0xFF64748B), Color(0xFF334155)],
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const LocalLibraryScreen(),
                    )),
                  );
                }
                if (i == 2) {
                  return _BrowseCard(
                    label: l10n.tabAlbums,
                    icon: Icons.album_outlined,
                    // Teal — hors de la roue des catégories (comme Collections
                    // et Productions), aucune carte voisine dans ces tons.
                    colors: const [Color(0xFF14B8A6), Color(0xFF0E7490)],
                    // Parcours alphabétique du catalogue ENTIER: `search_albums`
                    // accepte un q vide sans aucun filtre depuis le
                    // 2026-08-11 (33 126 albums; il répondait 0 avant, quel que
                    // soit le tri, et l'écran ne vivait que par sa recherche).
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CollectionAlbumsScreen(
                        collection:  null,       // tout le catalogue
                        title:       l10n.tabAlbums,
                        onTap:       _onSongTap,
                        onPlayAlbum: widget.onPlayAlbum,
                      ),
                    )),
                  );
                }
                if (i == 1) {
                  return _BrowseCard(
                    label: l10n.tabProductions,
                    icon: Icons.movie_outlined,
                    // Fuchsia — its old gold STARTED on publisher's exact
                    // colour. Sits in the 315° slot of the category wheel
                    // (see _categoryCardStyle), between production-type's
                    // magenta and party's rose.
                    colors: const [Color(0xFFE93AA4), Color(0xFFB3117A)],
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProductionsBrowseScreen(
                        onPlayAlbum: widget.onPlayAlbum,
                      ),
                    )),
                  );
                }
                if (i == 0) {
                  return _BrowseCard(
                    label: l10n.browseCollections,
                    icon: Icons.folder_special_outlined,
                    // Vivid orange, 15° slot: between party's rose and
                    // publisher's amber, distinct from both.
                    colors: const [Color(0xFFFF6231), Color(0xFFDC3C10)],
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FacetValuesScreen(
                        title: l10n.browseCollections,
                        onTap: _onSongTap,
                        onPlayAlbum: widget.onPlayAlbum,
                      ),
                    )),
                  );
                }
                final slug  = cats[i - 5];
                final label = _categoryLabel(slug, l10n);
                final style = _categoryCardStyle(slug);
                return _BrowseCard(
                  label: label,
                  icon: style.icon,
                  colors: style.colors,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FacetValuesScreen(
                      title: label,
                      tagCategory: slug,
                      onTap: _onSongTap,
                      onPlayAlbum: widget.onPlayAlbum,
                    ),
                  )),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              l10n.searchBrowseHint,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        // A little breathing room so the pill does not touch the back arrow.
        titleSpacing: 4,
        // A filled pill, not a bare TextField: borderless and magnifier-less
        // in the AppBar, the search box read as part of the bar — the one
        // control this screen exists for was the least visible thing on it.
        // Structure stays CONSTANT (see the `bottom` note below): the wrapper
        // is unconditional, so the TextField never changes tree position and
        // never drops focus.
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
          ),
          child: CancelField(
            controller: _controller,
            onCleared: _onChanged,
            builder: (_) => TextField(
            controller: _controller,
            focusNode: _focus,
            // Opened as a tag browse: show the results, don't pop the keyboard.
            autofocus: widget.initialTags.isEmpty,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              border: InputBorder.none,
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 38, minHeight: 38),
              contentPadding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            onChanged: _onChanged,
            ),
          ),
        ),
        actions: [
          // Filter button — badge when filters are active
          Badge(
            isLabelVisible: _hasActiveFilters,
            child: IconButton(
              icon: const Icon(Icons.tune),
              tooltip: l10n.searchFilters,
              onPressed: _showFilterSheet,
            ),
          ),
          // Sort toggle — cycles relevance → A-Z → Populaire → Année → Aléatoire
          if (_resultsNotifier.value.isNotEmpty)
            TextButton.icon(
              icon: Icon(_sortMeta(_sortBy, l10n).icon, size: 18),
              label: Text(
                _sortMeta(_sortBy, l10n).label,
                style: const TextStyle(fontSize: 13),
              ),
              onPressed: _toggleSort,
            ),
          // Sort direction — only where it's meaningful (not relevance/random).
          if (_resultsNotifier.value.isNotEmpty && _sortDirMeaningful)
            IconButton(
              icon: Icon(
                  _sortDir == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 18),
              tooltip:
                  _sortDir == 'asc' ? l10n.searchSortAsc : l10n.searchSortDesc,
              onPressed: _toggleSortDir,
            ),
        ],
        // Keep `bottom` non-null at all times: toggling it between null and a
        // TabBar changes the AppBar's structure, which rebuilds the `title`
        // TextField at a different tree position and drops keyboard focus (lost
        // on the first character typed and on backspacing to empty). A constant
        // PreferredSize with a zero-height empty child avoids that.
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_hasActiveSearch ? 46.0 : 0.0),
          child: !_hasActiveSearch
              ? const SizedBox.shrink()
              : TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: _Tab.values
                      .map((t) => Tab(text: _tabLabelCount(t, l10n)))
                      .toList(),
                ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Facet bar always visible once collections load: the Radio/🎲 buttons
    // work with no facet at all (whole-catalogue radio).
    final showChips = _collections.isNotEmpty;
    return Column(
      children: [
        if (showChips) _buildCollectionChips(),
        // Format / Platform dropdowns from search_facets (true totals, cross-tab).
        if (_hasActiveSearch) _buildFacetFilterBar(),
        // Gated on _hasActiveSearch like the TabBar itself: without it a
        // stale tab index (playlists selected, then the query cleared) left
        // these chips floating over the browse landing, where there is no
        // playlist list for them to filter.
        if (_hasActiveSearch && _tabs.index == _Tab.playlists.index)
          _buildPlaylistSourceBar(),
        if (_shouldOfferFuzzy) _buildDidYouMeanBanner(),
        if (_tagNote != null) _buildTagNoteBanner(),
        Expanded(child: _buildResults()),
      ],
    );
  }

  /// Demozoo note of the browsed party tag — one collapsed line, tap to
  /// expand the full Markdown (height-bounded so it never eats the results).
  Widget _buildTagNoteBanner() {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      child: InkWell(
        onTap: () => setState(() => _tagNoteExpanded = !_tagNoteExpanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.celebration, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: _tagNoteExpanded
                      ? const SizedBox.shrink()
                      : Text(
                          noteToPlainLine(_tagNote!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                ),
                Icon(
                  _tagNoteExpanded
                      ? Icons.arrow_drop_up
                      : Icons.arrow_drop_down,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ]),
              if (_tagNoteExpanded)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),
                  child: SingleChildScrollView(
                    child: NoteMarkdown(
                      text: _tagNote!,
                      onOpenLink: (u) => openExternalLink(context, u),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // After an exact (fuzzy=false) query returns few results, offer a one-tap
  // approximate re-run — the server's recommended "did you mean" pattern.
  bool get _shouldOfferFuzzy =>
      _currentQuery.isNotEmpty && _exact && !_loading &&
      !_fuzzyFallbackOffered && _totalCount < 3;

  Widget _buildDidYouMeanBanner() {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Material(
      color: cs.surfaceContainerHighest,
      child: InkWell(
        onTap: () {
          setState(() { _exact = false; _fuzzyFallbackOffered = true; });
          _search(_currentQuery);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Icon(Icons.search, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.searchDidYouMean,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ),
            Text(l10n.searchYes, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
          ]),
        ),
      ),
    );
  }

  // Facet values for one dimension (server-sorted by count desc), from the last
  // search_facets call. Empty until a search runs.
  List<FacetCount> _facetsOf(String kind) =>
      _facets.where((f) => f.kind == kind).toList();

  // A Format / Platform dropdown fed by search_facets. The counted dimension is
  // NOT restricted by its own value server-side, so every option stays available
  // even while selected. Picking re-runs the whole fan-out.
  Widget _buildFacetFilterBar() {
    final l10n      = context.l10n;
    final formats   = _facetsOf('format');
    final platforms = _facetsOf('platform');
    // Podium: au même niveau que Format / Plateforme. Comptes par rang de la
    // facette 'podium' (grain de l'onglet affiché); masquée pour la session si
    // le serveur ne connaît pas p_podium (404 mémorisé).
    final podCounts = podiumCounts(
        _tabs.index == _Tab.albums.index ? _facetsAlbum : _facets);
    final podTotal  = podiumTotal(podCounts);
    final showPodium = !RewampDb.serverLacks('p_podium') &&
        (podTotal > 0 || _podium != null);
    if (formats.isEmpty && platforms.isEmpty && !showPodium) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(children: [
        if (formats.isNotEmpty)
          _facetChip(l10n.searchFormat, _formatFilter, formats,
              (v) => setState(() { _formatFilter = v; _search(_currentQuery); })),
        if (formats.isNotEmpty && platforms.isNotEmpty) const SizedBox(width: 6),
        if (platforms.isNotEmpty)
          _facetChip(l10n.searchPlatform, _platformFilter, platforms,
              (v) => setState(() { _platformFilter = v; _search(_currentQuery); })),
        if (showPodium && (formats.isNotEmpty || platforms.isNotEmpty))
          const SizedBox(width: 6),
        if (showPodium)
          ActionChip(
            avatar: Icon(_podium != null ? Icons.check : Icons.emoji_events_outlined,
                size: 14),
            label: Text(podiumChipLabel(l10n, _podium, podTotal),
                style: const TextStyle(fontSize: 11)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: _podium != null
                ? Theme.of(context).colorScheme.secondaryContainer
                : null,
            onPressed: () async {
              final v = await showPodiumPicker(context,
                  current: _podium, counts: podCounts);
              if (v == null || !mounted) return;
              setState(() => _podium = v < 0 ? null : v);
              _search(_currentQuery);
            },
          ),
      ]),
    );
  }

  /// Who made the playlist (`p_source`, migration 199). Three states rather
  /// than a toggle: "everything" is the default, and someone who wants the
  /// catalogue's own selections wants to EXCLUDE the community ones just as
  /// much as the reverse.
  Widget _buildPlaylistSourceBar() {
    final l10n = context.l10n;
    Widget chip(String label, String? value) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(label, style: const TextStyle(fontSize: 11)),
            selected: _playlistSource == value,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            // A ChoiceChip fires with `false` when the SELECTED one is tapped;
            // ignoring that keeps one of the three always on, which is what a
            // filter with a default should do.
            onSelected: (on) {
              if (!on || _playlistSource == value) return;
              setState(() => _playlistSource = value);
              _loadPlaylists(_currentQuery);
            },
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(children: [
        chip(l10n.searchPlaylistSourceAll, null),
        chip(l10n.searchPlaylistSourceUser, 'user'),
        chip(l10n.searchPlaylistSourceServer, 'server'),
      ]),
    );
  }

  // Format / Platform picker: a sheet with a type-to-filter field on top (these
  // lists run long — a search across the whole catalogue can surface 40+
  // formats and 60+ platforms, unusable as a flat popup menu).
  Widget _facetChip(String label, String? current, List<FacetCount> values,
      void Function(String?) onPick) {
    final selected = current != null;
    return ActionChip(
      avatar: Icon(selected ? Icons.check : Icons.expand_more, size: 14),
      label: Text(
          selected ? context.l10n.searchFacetSelected(label, current) : label,
          style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: selected
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => FacetPickerSheet(
          label:    label,
          values:   values,
          selected: current,
          onPick:   (v) {
            Navigator.of(ctx).pop();
            onPick(v);
          },
        ),
      ),
    );
  }

  // Single-line facet bar: "current collection" pill (tap → picker sheet) +
  // Radio ▶ / 🎲 actions over the current facets.
  Widget _buildCollectionChips() {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.folder_outlined, size: 14),
                label: Text(l10n.searchCollectionLabel(_currentCollectionLabel),
                    style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: _openCollectionSheet,
              ),
            ),
          ),
          // Same pair, same shape, same spacing as on the artist screen —
          // plus « Tout lire » DEVANT Radio quand il y a des résultats
          // (déplacé depuis la _CountBar, demandé le 2026-09-02: trois
          // actions de lancement, une seule famille de boutons).
          // ⚠️ Les trois actions appartiennent à l'ONGLET ACTIF, et elles
          // DISPARAISSENT quand il n'a rien à jouer — sinon l'onglet Groupes
          // vide laissait lancer une lecture prise ailleurs (signalé le
          // 2026-09-02). La liste des résultats est un ValueNotifier: sans
          // l'écouter ici, la rangée ne se redessinerait pas à l'arrivée des
          // morceaux.
          ValueListenableBuilder<List<SearchResult>>(
            valueListenable: _resultsNotifier,
            builder: (_, __, ___) {
              final a = _tabActions();
              if (a == null) return const SizedBox.shrink();
              return RadioSurpriseButtons(
                onPlayAll: a.playAll,
                onRadio: a.radio,
                onSurprise: a.surprise,
              );
            },
          ),
        ],
      ),
    );
  }

  /// Les trois actions de lancement de l'onglet ACTIF, ou `null` quand il n'a
  /// aucune entrée — la rangée n'est alors pas rendue du tout.
  ///
  /// La source EST l'onglet: morceaux = les lignes chargées, artistes /
  /// groupes / albums / playlists / productions = leurs entrées DÉPLIÉES en
  /// pistes, « sur cet appareil » = les fichiers locaux. Seul l'onglet
  /// morceaux garde la radio de FACETTES (une station sur la recherche
  /// courante, pas sur la page chargée) — c'est ce qui fait vivre la page
  /// d'accueil de la recherche, où il n'y a pas encore de résultats.
  ({VoidCallback? playAll, VoidCallback? radio, VoidCallback? surprise})?
      _tabActions() {
    final tab = _Tab.values[_tabs.index];
    switch (tab) {
      case _Tab.all:
        final rows = _resultsNotifier.value;
        // Pas de recherche en cours = page d'accueil: la radio et la surprise
        // portent sur les FACETTES et restent offertes; « Tout lire » n'a rien
        // à lire.
        if (!_hasActiveSearch) {
          return (playAll: null, radio: _startRadio, surprise: _surpriseMe);
        }
        if (rows.isEmpty) return null;
        return (
          playAll: _playAllResults,
          radio: _startRadio,
          surprise: _surpriseMe,
        );
      case _Tab.artists:
        final rows = _artistResults;
        if (rows.isEmpty) return null;
        return _entityActions<ArtistResult>(
          rows,
          (a) => RewampDb.browse(
              artistId: a.artistId.isEmpty ? null : a.artistId,
              artistName: a.artistId.isEmpty ? a.name : null,
              sortBy: 'name',
              limit: _kEntityFanout),
        );
      case _Tab.groups:
        final rows = _groups;
        if (rows.isEmpty) return null;
        return _entityActions<GroupSearchResult>(
          rows,
          (g) => RewampDb.browse(
              tags: [g.name],
              tagCategories: const ['group'],
              sortBy: 'name',
              limit: _kEntityFanout),
        );
      case _Tab.albums:
        final rows = _albums;
        if (rows.isEmpty) return null;
        return _entityActions<_AlbumId>(
          rows,
          (a) => RewampDb.browse(
              albumName: a.name,
              collection: a.collection,
              platform: a.platform,
              sortBy: 'position',
              limit: 500),
        );
      case _Tab.playlists:
        final rows = _playlists;
        if (rows.isEmpty) return null;
        return _entityActions<Playlist>(
            rows, (p) => RewampDb.playlistTracks(p.id));
      case _Tab.productions:
        final rows = _productions;
        if (rows.isEmpty) return null;
        return _entityActions<ProductionSearchRow>(
            rows, (p) => RewampDb.productionTracks(p.production.id));
      case _Tab.local:
        final rows = _localMatches;
        if (rows.isEmpty || globalOpenLocalPaths == null) return null;
        void play(List<(String, TrackRecord)> list) {
          final paths = [for (final e in list) e.$2.filePath];
          if (paths.isEmpty) return;
          globalOpenLocalPaths?.call(paths);
        }
        return (
          playAll: () => play(rows),
          radio: () => play(List.of(rows)..shuffle(Random())),
          surprise: () => play([rows[Random().nextInt(rows.length)]]),
        );
    }
  }

  /// « Tout lire » sur les lignes CHARGÉES du tab Tous (pas le total
  /// serveur — la file est plafonnée en aval, kQueueLimit).
  ///
  /// ⚠️ Le filtre porte sur les lignes qui représentent un ALBUM ENTIER, et
  /// sur elles SEULES — exactement ce que la liste affiche. L'ancien filtre
  /// utilisait `isAlbumLevelMatch`, qui attrape en plus les MEMBRES d'archive
  /// sans url à eux: sur « Kondo » + plage d'années il écartait 10 lignes sur
  /// 10 et le bouton ne faisait plus rien. Les membres, eux, s'enfilent très
  /// bien — `_startAlbumQueue` extrait l'archive (`ensureAlbumExtracted`) et
  /// résout chaque entrée au moment où elle est jouée.
  Future<void> _playAllResults() async {
    // Les MORCEAUX de la liste — une ligne qui représente un album entier n'en
    // est pas un (elle a son onglet). Prédicat ÉTROIT: voir isWholeAlbumRow.
    final songs = _currentQuery.isEmpty
        ? _resultsNotifier.value
        : [
            for (final r in _resultsNotifier.value)
              if (!RewampDb.isWholeAlbumRow(r) &&
                  !RewampDb.matchedAlbumNameOnly(r, _currentQuery))
                r,
          ];
    if (songs.isEmpty) return;
    // ⚠️ Une ligne dont le serveur a nommé la PISTE désigne cette piste, pas le
    // conteneur: la résoudre AVANT d'enfiler, sinon « into the wilderness »
    // lançait l'album entier au lieu du morceau trouvé.
    final resolved = await RewampDb.resolveMatchedTracks(songs);
    if (!mounted) return;
    (widget.onPlayAlbum ?? globalOnPlayAlbum)?.call(context, resolved);
  }

  /// Combien de pistes on tire d'UNE entité (artiste, groupe). Un « tout lire »
  /// est un lancement, pas un aspirateur: la file est plafonnée en aval
  /// (kQueueLimit) et le helper partagé borne déjà entités et total.
  static const int _kEntityFanout = 200;

  /// La même famille d'actions pour tout onglet dont les entrées sont des
  /// ENTITÉS — une seule implémentation, partagée avec les écrans d'angle du
  /// navigateur de collection (`entity_play_actions.dart`).
  ({VoidCallback? playAll, VoidCallback? radio, VoidCallback? surprise})
      _entityActions<T>(
    List<T> rows,
    Future<List<SearchResult>> Function(T) fetch,
  ) {
    final a = entityPlayActions<T>(context, rows, fetch,
        onPlayAlbum: widget.onPlayAlbum);
    return (playAll: a.playAll, radio: a.radio, surprise: a.surprise);
  }

  void _openCollectionSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _CollectionPickerSheet(
        collections: _collections,
        selected: _collectionFilter,
        onPick: (slug) {
          Navigator.of(ctx).pop();
          _setCollectionFilter(slug);
        },
      ),
    );
  }

  // Tab label + a "(N)" suffix from the server total_count once a tab has loaded.
  String _tabLabelCount(_Tab t, AppLocalizations l10n) {
    final base = _tabLabel(t, l10n);
    final int total = switch (t) {
      _Tab.all       => _totalCount,
      _Tab.artists   => _artistTotal,
      _Tab.groups    => _groupTotal,
      _Tab.albums    => _albumTotal,
      _Tab.playlists => _playlistTotal,
      _Tab.productions => _productionTotal,
      _Tab.local     => _localTotal,
    };
    // ⚠️ Le total des ARTISTES peut n'être qu'un PLANCHER (migration serveur
    // 247): le serveur borne son décompte sur les recherches très larges et le
    // DIT, au lieu de rendre un nombre qui a l'air exact. « 4403+ ».
    final floor = t == _Tab.artists && _artistTotalIsFloor;
    return total > 0
        ? l10n.searchTabWithCount(base, '$total${floor ? '+' : ''}')
        : base;
  }

  Widget _buildResults() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return ValueListenableBuilder<List<SearchResult>>(
      valueListenable: _resultsNotifier,
      builder: (_, results, __) {
        if (!_hasActiveSearch) return _buildBrowseLanding();
        return TabBarView(
          controller: _tabs,
          children: [
            // Tous — infinite scroll sur la recherche principale
            _PaginatedSongList(
              // Empty query ⇒ _fetchPage browses instead of searching, and the
              // album-level filter must not run on those rows.
              textSearch:       _currentQuery.isNotEmpty,
              query:            _currentQuery,
              resultsNotifier:  _resultsNotifier,
              totalCount:       _totalCount,
              loadingMore:      _loadingMore,
              hasMore:          _hasMore,
              loadMore:         _loadMore,
              onTap:            _onSongTap,
              onNavigateAlbum:  (name, {collection, platform, artworkUrl, albumId}) =>
                  _pushAlbumSearch(_AlbumId(name, collection ?? '', platform,
                      artworkUrl, const [], albumId)),
              onNavigateArtist: (name, {collection, artistId}) =>
                  _pushArtistSearch(name, artistId: artistId),
              onQueueAdd:       widget.onQueueAdd,
              onPlayAlbum:      widget.onPlayAlbum,
            ),
            // Artistes — search_artists RPC (name ∪ song ∪ album, 1-hop)
            _artistsLoading
                ? const Center(child: CircularProgressIndicator())
                : _ArtistResultList(
                    items:       _artistResults,
                    total:       _artistTotal,
                    totalIsFloor: _artistTotalIsFloor,
                    hasMore:     _artistHasMore,
                    loadingMore: _artistLoadingMore,
                    loadMore:    _loadMoreArtists,
                    onTap: (a) => _pushArtistSearch(a.name, artistId: a.artistId),
                  ),
            // Groupes — search_groups (mig 201), text only
            _groupsLoading
                ? const Center(child: CircularProgressIndicator())
                : _GroupList(
                    items:       _groups,
                    total:       _groupTotal,
                    hasMore:     _groupHasMore,
                    loadingMore: _groupLoadingMore,
                    loadMore:    _loadMoreGroups,
                    onTap:       (g) => _pushGroupScreen(g.name, tagId: g.tagId),
                  ),
            // Albums
            _albumsLoading
                ? const Center(child: CircularProgressIndicator())
                : _AlbumList(
                    items:       _albums,
                    total:       _albumTotal,
                    hasMore:     _albumHasMore,
                    loadingMore: _albumLoadingMore,
                    loadMore:    _loadMoreAlbums,
                    onTap:   _pushAlbumSearch,
                    onPlay:  widget.onPlayAlbum,
                  ),
            // Playlists (server-curated; server-side name filter)
            _playlistsLoading
                ? const Center(child: CircularProgressIndicator())
                : _PlaylistList(
                    items:       _playlists,
                    total:       _playlistTotal,
                    hasMore:     _playlistHasMore,
                    loadingMore: _playlistLoadingMore,
                    loadMore:    _loadMorePlaylists,
                    onTap:  _openPlaylist,
                    onPlay: _playPlaylistNow,
                  ),
            // Productions (demozoo entities, migs 161-163)
            _productionsLoading
                ? const Center(child: CircularProgressIndicator())
                : _ProductionList(
                    items:       _productions,
                    total:       _productionTotal,
                    hasMore:     _productionHasMore,
                    loadingMore: _productionLoadingMore,
                    loadMore:    _loadMoreProductions,
                    onTap: (ctx, row) => row.isVideoOnly
                        ? openProductionVideo(ctx, row.production)
                        : openProduction(ctx, row.production),
                  ),
            // Sur cet appareil — imports locaux (filtrage en mémoire)
            _buildLocalTab(),
          ],
        );
      },
    );
  }

  /// Correspondances LOCALES pour l'onglet « Sur cet appareil » — titre ET
  /// chemin relatif (le nom d'archive/dossier est dans le chemin). Pas de
  /// facettes: les imports locaux n'en ont pas; une recherche à facettes
  /// seules montre tout.
  Future<void> _loadLocalMatches(String q) async {
    try {
      final all = await LocalDb.instance.getLocalImports();
      if (!mounted || _currentQuery != q) return;
      final lower = q.toLowerCase();
      final hits = lower.isEmpty
          ? all
          : [
              for (final e in all)
                if (e.$1.toLowerCase().contains(lower) ||
                    (e.$2.title ?? '').toLowerCase().contains(lower))
                  e,
            ];
      setState(() {
        _localMatches = hits;
        _localTotal = hits.length;
      });
    } catch (_) {}
  }

  Widget _buildLocalTab() {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    if (_localMatches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.searchNoResults,
              style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }
    return ListView.builder(
      itemCount: _localMatches.length,
      itemBuilder: (ctx, i) {
        final (rel, t) = _localMatches[i];
        return ListTile(
          dense: true,
          leading: RailArtwork(
            url:           t.artworkUrl,
            localFilePath: t.filePath,
            formatHint:    t.formatExt,
            platformName:  t.platformName,
            size:          40,
          ),
          title: ScrollingText(text: t.displayTitle),
          subtitle: Text(rel, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => globalOpenLocalPaths?.call([t.filePath]),
        );
      },
    );
  }

  /// [artistId] whenever the caller has one (artist rows): homonym artists
  /// (two "Moby"s) share a name — only the id addresses the right profile.
  void _pushArtistSearch(String artist, {String? artistId}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ArtistResultsScreen(
        artistName:  artist,
        artistId:    artistId,
        onTap:       _onSongTap,
        onPlayAlbum: widget.onPlayAlbum,
        onQueueAdd:  widget.onQueueAdd,
        // Tag chip in the artist header → a fresh tag-scoped search screen
        // (same behavior as AppShell._pushTagSearch).
        onNavigateTag: (tag, {category}) =>
            Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SearchScreen(
            initialTags:     [tag],
            initialTagCategory: category,
            onFileReady:     widget.onFileReady,
            onPlayAlbum:     widget.onPlayAlbum,
            onQueueAdd:      widget.onQueueAdd,
            onAlbumQueueAdd: widget.onAlbumQueueAdd,
          ),
        )),
      ),
    ));
  }

  /// Group row / chip → the group screen. Pushed locally (not through the
  /// AppShell hook): this screen is already on the active navigator, and the
  /// hook exists for chips that live in sheets with no navigation threaded.
  void _pushGroupScreen(String name, {String? tagId}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GroupScreen(
        name:            name,
        tagId:           tagId,
        onTap:           _onSongTap,
        onPlayAlbum:     widget.onPlayAlbum,
        onQueueAdd:      widget.onQueueAdd,
        onAlbumQueueAdd: widget.onAlbumQueueAdd,
        onFileReady:     widget.onFileReady,
      ),
    ));
  }

  void _pushAlbumSearch(_AlbumId album) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AlbumDetailScreen(
        albumName:      album.name,
        albumId:        album.albumId,
        platformName:   album.platform,
        collectionSlug: album.collection,
        artworkUrl:     album.artworkUrl,
        onTap:           _onSongTap,
        onPlayAlbum:     widget.onPlayAlbum,
        onQueueAdd:      widget.onQueueAdd,
        onAlbumQueueAdd: widget.onAlbumQueueAdd,
        onArtistTap:     _pushArtistSearch,
      ),
    ));
  }

}

// ---------------------------------------------------------------------------
// Paginated song list (main search — Tous tab)
// ---------------------------------------------------------------------------

class _PaginatedSongList extends StatefulWidget {
  final ValueNotifier<List<SearchResult>> resultsNotifier;
  final int  totalCount;
  final bool loadingMore;
  final bool hasMore;
  final Future<void> Function() loadMore;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnNavigateAlbum?  onNavigateAlbum;
  final OnNavigateArtist? onNavigateArtist;
  final OnQueueAdd?       onQueueAdd;
  final OnPlayAlbum?      onPlayAlbum;
  /// Whether these rows come from a TEXT search. Album-level rows only exist
  /// then: the predicate that detects them reads matchSubsongTitle == null as
  /// "matched by album name, not by track title", and browse_music never sets
  /// it because it runs no text search. Applying it to a browse listing hides
  /// every row that merely has an album and a subsong — i.e. most of them.
  final bool textSearch;
  /// Le texte cherché — sert à distinguer une piste dont le NOM matche d'une
  /// ligne qui ne matche que par le nom de son ALBUM (voir
  /// [RewampDb.matchedAlbumNameOnly]). Vide en mode browse.
  final String query;

  const _PaginatedSongList({
    required this.resultsNotifier,
    required this.totalCount,
    required this.loadingMore,
    required this.hasMore,
    required this.loadMore,
    required this.onTap,
    this.onNavigateAlbum,
    this.onNavigateArtist,
    this.onQueueAdd,
    this.onPlayAlbum,
    this.textSearch = true,
    this.query = '',
  });

  @override
  State<_PaginatedSongList> createState() => _PaginatedSongListState();
}

class _PaginatedSongListState extends State<_PaginatedSongList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      widget.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SearchResult>>(
      valueListenable: widget.resultsNotifier,
      builder: (_, all, __) {
        // Cet onglet liste des MORCEAUX. Une ligne qui représente un ALBUM
        // ENTIER (l'archive joshw d'un jeu, dont le serveur ne connaît pas le
        // détail) n'en est pas un: elle a son propre onglet Albums, et la
        // laisser ici mettait des albums complets dans « Tout lire ».
        //
        // ⚠️ Le prédicat est [RewampDb.isWholeAlbumRow], PAS `isAlbumLevelMatch`
        // — celui-là attrape aussi les MEMBRES d'archive sans url à eux (les
        // `.spc` d'un `.rsn`), qui sont bel et bien des morceaux. C'est cette
        // confusion qui avait fait retirer tout filtrage d'ici: elle vidait la
        // liste (« 4 et aucun » sur un album modland) et rendait la page 2
        // inatteignable. Deux garde-fous en conséquence: le « aucun résultat »
        // se juge sur la liste BRUTE, et une page entièrement filtrée demande
        // quand même la suivante — sinon la ListView est vide, ne défile pas,
        // et rien ne rappelle jamais `loadMore`.
        final results = widget.textSearch
            ? [
                for (final r in all)
                  if (!RewampDb.isWholeAlbumRow(r) &&
                      !RewampDb.matchedAlbumNameOnly(r, widget.query))
                    r,
              ]
            : all;
        if (all.isEmpty && !widget.loadingMore) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.searchNoResults,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        if (results.isEmpty && widget.hasMore && !widget.loadingMore) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => widget.loadMore());
        }
        return Column(
          children: [
            _CountBar(
              loaded: results.length,
              total: '${widget.totalCount}',
              loading: widget.loadingMore,
              hasMore: widget.hasMore,
              // Pas de « Tout lire » ici: il vit dans la rangée de facettes,
              // devant Radio (RadioSurpriseButtons.onPlayAll) — un seul
              // bouton pour une seule action.
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                itemCount: results.length + (widget.hasMore ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == results.length) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => widget.loadMore(),
                    );
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return SongTile(
                    result:           results[i],
                    onTap:            widget.onTap,
                    onNavigateAlbum:  widget.onNavigateAlbum,
                    onNavigateArtist: widget.onNavigateArtist,
                    onQueueAdd:       widget.onQueueAdd,
                    onPlayAlbum:      widget.onPlayAlbum,
                    albumRowsAllowed: widget.textSearch,
                    // Une recherche brasse toutes les collections: d'où vient
                    // la ligne est une information de premier plan ici.
                    showCollection:   true,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Dedicated results screen — own paginated search (for artists & albums)
// ---------------------------------------------------------------------------

class DedicatedResultsScreen extends StatefulWidget {
  final String  label;
  final String  query;
  final String? artistName;
  final String? albumName;
  final String? collection;
  final String? platform;
  final String? formatFilter;
  final List<String> tags;
  final String  sortBy;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnQueueAdd?      onQueueAdd;
  final OnAlbumQueueAdd? onAlbumQueueAdd;

  const DedicatedResultsScreen({
    super.key,
    required this.label,
    required this.query,
    this.artistName,
    this.albumName,
    this.collection,
    this.platform,
    this.formatFilter,
    this.tags = const [],
    this.sortBy = 'title',
    required this.onTap,
    this.onQueueAdd,
    this.onAlbumQueueAdd,
  });

  @override
  State<DedicatedResultsScreen> createState() => _DedicatedResultsScreenState();
}

class _DedicatedResultsScreenState extends State<DedicatedResultsScreen> {
  final _scroll   = ScrollController();
  final _notifier = ValueNotifier<List<SearchResult>>([]);
  int    _total       = 0;
  int    _offset      = 0;
  bool   _hasMore     = false;
  bool   _loading     = true;
  bool   _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _notifier.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    try {
      final res = await RewampDb.search(
        widget.query,
        fuzzy:        false,
        artistName:   widget.artistName,
        albumName:    widget.albumName,
        collection:   widget.collection,
        platform:     widget.platform,
        formatFilter: widget.formatFilter,
        tags:         widget.tags,
        sortBy:       widget.sortBy,
        limit:        50,
        offset:       0,
      );
      if (!mounted) return;
      _notifier.value = res;
      _total   = res.isEmpty ? 0 : res.first.totalCount;
      _offset  = res.length;
      _hasMore = _offset < _total;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final more = await RewampDb.search(
        widget.query,
        fuzzy:        false,
        artistName:   widget.artistName,
        albumName:    widget.albumName,
        collection:   widget.collection,
        platform:     widget.platform,
        formatFilter: widget.formatFilter,
        tags:         widget.tags,
        sortBy:       widget.sortBy,
        limit:        50,
        offset:       _offset,
      );
      if (!mounted) return;
      _notifier.value = [..._notifier.value, ...more];
      _offset  += more.length;
      _hasMore  = _offset < _total;
      setState(() => _loadingMore = false);
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.label)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ValueListenableBuilder<List<SearchResult>>(
                  valueListenable: _notifier,
                  builder: (_, all, __) {
                    // Nothing hidden — same rule as the songs tab: an
                    // album-level row is SHOWN and routes to its album screen,
                    // it is never dropped from a listing of tunes.
                    final results = all;
                    return Column(
                    children: [
                      _CountBar(
                        loaded: results.length,
                        total: '$_total',
                        loading: _loadingMore,
                        hasMore: _hasMore,
                        // Écran dédié: pas de onPlayAlbum en propre, le relais
                        // global suffit (posé par AppShell au démarrage).
                        onPlayAll: () {
                          final songs = [
                            for (final r in results)
                              if (!RewampDb.isAlbumLevelMatch(r)) r,
                          ];
                          if (songs.isEmpty) return;
                          globalOnPlayAlbum?.call(context, songs);
                        },
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: _scroll,
                          itemCount: results.length + (_hasMore ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i == results.length) {
                              WidgetsBinding.instance.addPostFrameCallback(
                                (_) => _loadMore(),
                              );
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            return SongTile(
                              result:           results[i],
                              onTap:            widget.onTap,
                              onQueueAdd:       widget.onQueueAdd,
                              onNavigateAlbum: (name, {collection, platform, artworkUrl, albumId}) =>
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => AlbumDetailScreen(
                                      albumName:       name,
                                      albumId:         results[i].albumId,
                                      collectionSlug:  collection,
                                      platformName:    platform,
                                      artworkUrl:      artworkUrl,
                                      onTap:           widget.onTap,
                                      onPlayAlbum:     null,
                                      onQueueAdd:      widget.onQueueAdd,
                                      onAlbumQueueAdd: widget.onAlbumQueueAdd,
                                    ),
                                  )),
                              onNavigateArtist: (name, {collection, artistId}) =>
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => ArtistResultsScreen(
                                      artistName:  name,
                                      artistId:    artistId,
                                      collection:  collection,
                                      onTap:       widget.onTap,
                                      onPlayAlbum: null,
                                    ),
                                  )),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                  },
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Artist results screen — Albums + Morceaux tabs
// ---------------------------------------------------------------------------

class ArtistResultsScreen extends StatefulWidget {
  final String       artistName;
  final String?      artistId;
  final String?      collection;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnPlayAlbum?     onPlayAlbum;
  final OnQueueAdd?      onQueueAdd;
  final OnAlbumQueueAdd? onAlbumQueueAdd;
  /// Tapping a searchable tag chip in the header → cross-entity tag search.
  final OnNavigateTag? onNavigateTag;

  const ArtistResultsScreen({
    super.key,
    required this.artistName,
    this.artistId,
    this.collection,
    required this.onTap,
    this.onPlayAlbum,
    this.onQueueAdd,
    this.onAlbumQueueAdd,
    this.onNavigateTag,
  });

  @override
  State<ArtistResultsScreen> createState() => _ArtistResultsScreenState();
}

class _ArtistResultsScreenState extends State<ArtistResultsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _scroll   = ScrollController();
  final _notifier = ValueNotifier<List<SearchResult>>([]);

  // Albums — loaded independently via get_artist_albums RPC
  List<ArtistAlbum> _albums       = [];
  bool              _albumsLoading = true;

  // Artist profile — loaded independently (header degrades to nothing on error)
  ArtistDetails? _details;
  bool           _aboutExpanded = false;

  // Facet filters (collection / format / platform), applied server-side to
  // the songs tab (browse_music params) and client-side to the albums tab
  // (get_artist_albums returns the full list at once). Options come from
  // search_facets scoped to this artist (complete set, true counts); the rows
  // loaded so far still feed the same sets as a fallback when that call is
  // unavailable (offline, or an artist known only by name).
  String? _fCollection, _fFormat, _fPlatform;
  // Podium (compétitions demoscene): albums filtrés côté client par rang
  // (get_artist_albums rend la liste complète); morceaux par
  // browse_music(p_podium) — tant que le serveur ne connaît pas le paramètre,
  // les morceaux restent NON filtrés (voir _onServerCapabilities) plutôt que
  // paginés à de faux décalages.
  int? _fPodium;            // p_podium: null = aucun, 0 = tout podium, 1-3
  Map<int, int> _podiumSongCounts = const {1: 0, 2: 0, 3: 0};   // facette serveur
  final Set<String> _optCollections = {};
  final Set<String> _optFormats     = {};   // lowercase
  final Set<String> _optPlatforms   = {};

  // Songs — first page on open, then lazy scroll
  int    _total       = 0;
  int    _offset      = 0;
  bool   _hasMore     = false;
  bool   _songsLoading  = true;
  bool   _loadingMore   = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    // La puce podium montre les comptes de l'onglet AFFICHÉ.
    _tabs.addListener(() { if (mounted) setState(() {}); });
    _scroll.addListener(_onScroll);
    // Load albums and first song page in parallel — independent requests
    Future.wait([_loadAlbums(), _loadSongs()]);
    _loadDetails(); // header, independent — never blocks the tabs
    _loadFacets();  // complete filter options, independent too
    RewampDb.serverLacksChanged.addListener(_onServerCapabilities);
  }

  int? get _podiumOnServer => RewampDb.serverLacks('p_podium') ? null : _fPodium;

  /// The server does not know `p_podium`: the songs page just loaded was
  /// filtered client-side, and paging on would use wrong offsets. Say so and
  /// reload the songs unfiltered — the albums stay filtered (client-side).
  void _onServerCapabilities() {
    if (!mounted || _fPodium == null || !RewampDb.serverLacks('p_podium')) return;
    AppSnack.show(context, context.l10n.searchPodiumUnavailable);
    _applyFilters();
  }

  /// Open an external link, mirroring the credits screen. Server-supplied urls
  /// often lack a scheme (`www.x`, `amp.dascene.net/...`) → macOS reports
  /// "impossible d'ouvrir l'application" because a scheme-less Uri has no
  /// handler; normalise to https first, and fall back to the clipboard when the
  /// launch is refused (same UX as `_CreditTile._open`).
  Future<void> _openExternal(String raw) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    var url = raw.trim();
    if (!url.contains('://')) url = 'https://$url';
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (_) {/* fall through to the clipboard */}
    if (opened) return;
    await Clipboard.setData(ClipboardData(text: url));
    AppSnack.showOn(messenger, l10n.settingsLinkCopied(url),
        duration: const Duration(seconds: 2));
  }

  /// Tag navigation: threaded callback when present, else the AppShell
  /// global fallback (covers browse/collection paths that don't thread it).
  OnNavigateTag? get _onTag =>
      widget.onNavigateTag ?? globalOnNavigateTag;

  Future<void> _loadDetails() async {
    final d = await RewampDb.getArtistDetails(
      widget.artistName,
      artistId: widget.artistId,
    );
    if (!mounted || d == null || d.isEmpty) return;
    setState(() {
      _details = d;
      _optCollections.addAll(d.collections.where((c) => c.isNotEmpty));
    });
  }

  /// Whole set of collections / formats / platforms this artist has, from
  /// search_facets scoped by artist. Silent on failure: the row-derived sets
  /// still populate the dropdowns, just partially.
  Future<void> _loadFacets() async {
    try {
      final facets = await RewampDb.searchFacets(
        '',
        artistId:   widget.artistId,
        artistName: widget.artistId == null ? widget.artistName : null,
      );
      if (!mounted || facets.isEmpty) return;
      setState(() {
        for (final f in facets) {
          if (f.value.isEmpty) continue;
          switch (f.kind) {
            case 'collection': _optCollections.add(f.value);
            case 'format':     _optFormats.add(f.value.toLowerCase());
            case 'platform':   _optPlatforms.add(f.value);
            case 'podium':
              final r = int.tryParse(f.value);
              if (r != null && r >= 1 && r <= 3) {
                _podiumSongCounts = {..._podiumSongCounts, r: f.count};
              }
          }
        }
      });
    } catch (_) {/* keep the row-derived options */}
  }

  void _accumulateOpts(Iterable<SearchResult> rows) {
    for (final r in rows) {
      if (r.collection.isNotEmpty) _optCollections.add(r.collection);
      // ⚠️ Seulement le format que le SERVEUR connaît: c'est sur SA colonne
      // que `browse_music(format_filter:)` filtre. Un format déduit du nom de
      // fichier (une ligne sceneorg est un `.zip` dont le module est dedans,
      // `format_ext` y est NULL) donnerait une option qui ne ramène jamais
      // rien — « je filtre sur ZIP et la liste se vide ». Bon pour AFFICHER,
      // pas pour INTERROGER.
      if (r.formatExt.isNotEmpty && !r.formatExtFromFileName) {
        _optFormats.add(r.formatExt.toLowerCase());
      }
      final p = r.platform;
      if (p != null && p.isNotEmpty) _optPlatforms.add(p);
    }
  }

  @override
  void dispose() {
    RewampDb.serverLacksChanged.removeListener(_onServerCapabilities);
    _tabs.dispose();
    _scroll.dispose();
    _notifier.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMoreSongs();
    }
  }

  Future<void> _loadAlbums() async {
    try {
      final albums = await RewampDb.fetchArtistAlbums(
        widget.artistName,
        artistId:   widget.artistId,
        collection: widget.collection,
      );
      if (!mounted) return;
      setState(() {
        _albums = albums;
        _albumsLoading = false;
        for (final a in albums) {
          if (a.collection.isNotEmpty) _optCollections.add(a.collection);
          final p = a.platform;
          if (p != null && p.isNotEmpty) _optPlatforms.add(p);
          final f = a.format;
          if (f != null && f.isNotEmpty) _optFormats.add(f.toLowerCase());
        }
      });
    } catch (_) {
      if (mounted) setState(() => _albumsLoading = false);
    }
  }

  Future<void> _loadSongs() async {
    try {
      // An artist's songs = browse by artist_name — NO `q`. Passing q=artistName
      // AND artist_name forced the full FTS/cross-entity match (title ∪ artist ∪
      // album + aggregates) which timed out for prolific artists. browse_music
      // filters by artist with no text search → fast. (guide §8)
      final res = await RewampDb.browse(
        artistName:   widget.artistName,
        artistId:     widget.artistId, // homonym-proof (p_artist_id, mig 146)
        collection:   _fCollection ?? widget.collection,
        formatFilter: _fFormat,
        platform:     _fPlatform,
        podium:       _podiumOnServer,
        sortBy:       'name',
        limit:        50,
        offset:       0,
      );
      if (!mounted) return;
      _accumulateOpts(res);
      _notifier.value = res;
      _total  = res.isEmpty ? 0 : res.first.totalCount;
      _offset = res.length;
      _hasMore = _offset < _total;
      setState(() => _songsLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _songsLoading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadMoreSongs() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final more = await RewampDb.browse(
        artistName:   widget.artistName,
        artistId:     widget.artistId,
        collection:   _fCollection ?? widget.collection,
        formatFilter: _fFormat,
        platform:     _fPlatform,
        podium:       _podiumOnServer,
        sortBy:       'name',
        limit:        50,
        offset:       _offset,
      );
      if (!mounted) return;
      _accumulateOpts(more);
      _notifier.value = [..._notifier.value, ...more];
      _offset  += more.length;
      _hasMore  = _offset < _total;
      setState(() => _loadingMore = false);
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _pushAlbum(ArtistAlbum album) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AlbumDetailScreen(
        albumName:      album.name,
        albumId:        album.albumId,
        platformName:   album.platform,
        collectionSlug: album.collection,
        artworkUrl:     album.artworkUrl,
        onTap:           widget.onTap,
        onPlayAlbum:     widget.onPlayAlbum,
        onQueueAdd:      widget.onQueueAdd,
        onAlbumQueueAdd: widget.onAlbumQueueAdd,
        onArtistTap:     (name) => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ArtistResultsScreen(
            artistName:      name,
            onTap:           widget.onTap,
            onPlayAlbum:     widget.onPlayAlbum,
            onQueueAdd:      widget.onQueueAdd,
            onAlbumQueueAdd: widget.onAlbumQueueAdd,
            onNavigateTag:   widget.onNavigateTag,
          ),
        )),
      ),
    ));
  }

  bool get _loading => _albumsLoading && _songsLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final albumsShown = _filteredAlbums;
    final albumLabel = albumsShown.isNotEmpty
        ? l10n.searchTabWithCount(l10n.tabAlbums, '${albumsShown.length}')
        : l10n.tabAlbums;
    final songsLabel = _total > 0
        ? l10n.searchTabWithCount(l10n.tabAll, '$_total')
        : l10n.tabAll;

    // Counts ride ALONG the name in the app bar rather than under it: the
    // header, the action bar and the filter bar were three separate strips
    // above the list, and the counts are the one line that never needed a strip
    // of its own.
    final songN = (_details?.songCount ?? 0) > 0 ? _details!.songCount : _total;
    final headCounts = <String>[
      if (songN > 0) l10n.searchSongsCount(songN),
      if (albumsShown.isNotEmpty) l10n.searchAlbumsCount(albumsShown.length),
    ].join('  ·  ');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(widget.artistName,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (headCounts.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(headCounts,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
            ],
          ],
        ),
        actions: [
          // Save the artist to the library. The row is LOCAL-ONLY (artists
          // have no server-side library counterpart — sync skips the type).
          // refId = the uuid when known: the name is homonym-prone, and the
          // library screen recovers the id from the refId to navigate.
          LibraryButton(
            type:  'artist',
            refId: (widget.artistId != null && widget.artistId!.isNotEmpty)
                ? widget.artistId!
                : widget.artistName,
            name:  widget.artistName,
            collectionSlug: widget.collection,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    if (_details != null) _buildHeader(_details!),
                    // Radio / surprise sit IN the filter row (icon-only) so they
                    // cost no vertical space of their own, and they stay
                    // reachable when the artist has no facet to filter by —
                    // which is why that row is always built now.
                    _buildFilterBar(),
                    TabBar(
                      controller: _tabs,
                      tabs: [Tab(text: songsLabel), Tab(text: albumLabel)],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [_buildSongsTab(), _buildAlbumsTab()],
                      ),
                    ),
                  ],
                ),
    );
  }

  /// Collapsible artist header: a compact always-visible line (country · counts
  /// · real name · searchable-tag chips) plus a "▾ À propos" toggle that reveals
  /// the full profile in a height-bounded, scrollable panel so a long bio never
  /// pushes the tabs off-screen.
  Widget _buildHeader(ArtistDetails d) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: cs.onSurfaceVariant);

    // Song/album counts moved UP into the app bar title (they were the bulk of
    // this line and they belong with the name). What is left here is identity:
    // country, and the real name when it differs.
    final metaBits = <String>[
      if (d.country != null) d.country!,
      if (d.realName != null && d.realName != d.name) d.realName!,
    ];

    final hasAbout = d.bio != null ||
        d.notes != null ||
        d.realName != null ||
        d.birthDate != null ||
        d.interviewUrl != null ||
        d.aliases.isNotEmpty ||
        d.countries.length > 1 ||
        d.groupNames.isNotEmpty ||
        d.amp.isNotEmpty ||
        d.collections.isNotEmpty;

    // Nothing to say about this artist: no strip at all, rather than an empty
    // tinted band eating the top of the list.
    if (metaBits.isEmpty && !hasAbout &&
        (d.nonGroupTags.isEmpty || _onTag == null)) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (metaBits.isNotEmpty)
            Text(metaBits.join('  ·  '),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
          // Searchable tags → clickable chips (existing tag-search pipeline).
          // Groups excluded here: they render as their own clickable section
          // in "À propos" (same names twice looked like a bug).
          if (d.nonGroupTags.isNotEmpty && _onTag != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: -4,
              children: [
                for (final t in d.nonGroupTags)
                  ActionChip(
                    label: Text(t.name),
                    labelStyle: Theme.of(context).textTheme.bodySmall,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onPressed: () => _onTag!(t.name, category: t.category),
                  ),
              ],
            ),
          ],
          if (hasAbout) ...[
            InkWell(
              onTap: () => setState(() => _aboutExpanded = !_aboutExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _aboutExpanded
                          ? Icons.arrow_drop_up
                          : Icons.arrow_drop_down,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    Text(l10n.settingsAbout, style: muted),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: _aboutExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.38,
                ),
                child: SingleChildScrollView(child: _buildAbout(d)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Group chip tap → the group screen (members, note and the five listings).
  /// It replaced a bottom sheet that could only show the note and the members:
  /// what a group actually has is its PRODUCTIONS, and a sheet had nowhere to
  /// put them. Pushed with the tag id when the chip carries one.
  void _openGroup(String name, {String? tagId}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GroupScreen(
        name:            name,
        tagId:           tagId,
        onTap:           widget.onTap,
        onPlayAlbum:     widget.onPlayAlbum,
        onQueueAdd:      widget.onQueueAdd,
        onAlbumQueueAdd: widget.onAlbumQueueAdd,
      ),
    ));
  }

  Widget _buildAbout(ArtistDetails d) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: cs.onSurfaceVariant);

    Widget kv(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: Text(label,
                    style: muted?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Expanded(
                  child: Text(value,
                      style: Theme.of(context).textTheme.bodySmall)),
            ],
          ),
        );

    final born = d.birthDate == null
        ? null
        : (d.birthSource != null
            ? '${d.birthDate}  (${d.birthSource})'
            : d.birthDate!);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.realName != null && d.realName != d.name)
            kv(l10n.artistRealName, d.realName!),
          if (d.aliases.isNotEmpty)
            kv(l10n.artistAliases, d.aliases.join(', ')),
          if (born != null) kv(l10n.artistBorn, born),
          if (d.countries.length > 1)
            kv(l10n.searchCategoryOrigin, d.countries.join(', ')),
          if (d.collections.isNotEmpty)
            kv(l10n.browseCollections, d.collections.join(', ')),
          // Group membership — derived from tags[category='group'] (the
          // legacy groups[] array is gone, server mig 144). Always in the
          // searchable namespace → clickable chips via the tag pipeline.
          if (d.groupNames.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(l10n.searchCategoryGroup,
                style: muted?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: -4,
              children: [
                for (final g in d.groupNames)
                  ActionChip(
                    label: Text(g),
                    labelStyle: Theme.of(context).textTheme.bodySmall,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onPressed: () => _openGroup(g),
                  ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (d.amp.isNotEmpty)
            for (final a in d.amp)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  a.moduleCount > 0
                      ? 'AMP: ${a.handle}  ·  ${l10n.artistModules(a.moduleCount)}'
                      : 'AMP: ${a.handle}',
                  style: muted,
                ),
              ),
          if (d.interviewUrl != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(l10n.artistInterview),
                onPressed: () => _openExternal(d.interviewUrl!),
              ),
            ),
          if (d.bio != null) ...[
            const SizedBox(height: 6),
            SelectableText(d.bio!,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          // Demozoo scener note (Markdown) + its demozoo page.
          if (d.notes != null) ...[
            const SizedBox(height: 6),
            NoteMarkdown(
              text: d.notes!,
              onOpenLink: _openExternal,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (d.notesUrl != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('demozoo.org'),
                  onPressed: () => _openExternal(d.notesUrl!),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Albums under the active facet filters (client-side: get_artist_albums
  /// returned the complete list already).
  List<ArtistAlbum> get _filteredAlbums => [
        for (final a in _albums)
          if ((_fCollection == null || a.collection == _fCollection) &&
              (_fPlatform == null || a.platform == _fPlatform) &&
              (_fFormat == null || a.format?.toLowerCase() == _fFormat) &&
              podiumMatches(a.podium, _fPodium))
            a,
      ];

  /// Re-runs the songs query with the current filters (server-side).
  void _applyFilters() {
    setState(() {
      _songsLoading = true;
      _total   = 0;
      _offset  = 0;
      _hasMore = false;
      _notifier.value = const [];
    });
    _loadSongs();
  }

  Future<void> _pickFacet({
    required String title,
    required List<String> options,
    required String? current,
    required void Function(String?) onPick,
    bool upper = false,
  }) async {
    final l10n = context.l10n;
    final picked = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(l10n.searchCollectionAll),
              selected: current == null,
              onTap: () => Navigator.pop(ctx, false), // false = clear
            ),
            for (final o in options)
              ListTile(
                title: Text(upper ? o.toUpperCase() : o),
                selected: o == current,
                onTap: () => Navigator.pop(ctx, o),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;          // dismissed
    onPick(picked == false ? null : picked as String);
    _applyFilters();
  }

  Widget _facetChip({
    required String label,
    required String? value,
    required List<String> options,
    required void Function(String?) onPick,
    bool upper = false,
  }) {
    final active = value != null;
    final shown = value == null ? label : (upper ? value.toUpperCase() : value);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(shown),
        selected: active,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        deleteIcon: active ? const Icon(Icons.close, size: 16) : null,
        onDeleted: active
            ? () { onPick(null); _applyFilters(); }
            : null,
        onPressed: () => _pickFacet(
            title: label,
            options: options.toList()..sort(),
            current: value,
            onPick: onPick,
            upper: upper),
      ),
    );
  }

  /// Facet chips row — hidden while nothing is known to filter on.
  // ---- Radio / surprise, scoped to this artist ------------------------------

  /// Both honour the active facet chips (collection/format/platform), like the
  /// search screen's equivalents honour its facets — the buttons act on what
  /// the screen is currently showing, not on the artist's whole catalogue.
  Future<List<SearchResult>> _randomSongs(int limit, String seed) =>
      RewampDb.browse(
        artistName:   widget.artistName,
        artistId:     widget.artistId,
        collection:   _fCollection ?? widget.collection,
        formatFilter: _fFormat,
        platform:     _fPlatform,
        podium:       _podiumOnServer,
        sortBy:       'random',
        seed:         seed,
        limit:        limit,
        offset:       0,
      );

  Future<void> _startArtistRadio() async {
    try {
      final songs = await _randomSongs(
          50, DateTime.now().millisecondsSinceEpoch.toString());
      if (!mounted || songs.isEmpty) return;
      final play = widget.onPlayAlbum;
      if (play != null) {
        await play(context, songs);
      } else {
        await widget.onTap(context, songs.first);
      }
    } catch (_) {}
  }

  /// « Tout lire » — les lignes CHARGÉES du tab Morceaux (même règle que la
  /// recherche: on lance ce qui est affiché, pas le total serveur). Vaut
  /// aussi depuis le tab Albums: comme Radio, le bouton porte sur les
  /// morceaux de l'artiste sous les facettes actives.
  void _playAllArtistSongs() {
    final songs = _notifier.value;
    if (songs.isEmpty) return;
    (widget.onPlayAlbum ?? globalOnPlayAlbum)?.call(context, songs);
  }

  Future<void> _surpriseArtist() async {
    try {
      final songs = await _randomSongs(
          1, DateTime.now().microsecondsSinceEpoch.toString());
      if (!mounted || songs.isEmpty) return;
      await widget.onTap(context, songs.first);
    } catch (_) {}
  }

  /// Radio / surprise + the collection/format/platform pickers, ONE row.
  ///
  /// They used to be two strips: the buttons had to stay out of the filter bar
  /// because that bar collapses to nothing when the artist has a single
  /// collection/format/platform, and they must stay reachable. Folding them in
  /// works the other way round — the row is now built unconditionally, and the
  /// pickers are what comes and goes inside it. Icon-only: the two labels were
  /// the widest thing on the strip and the tooltips carry the same words.
  Widget _buildFilterBar() {
    final l10n = context.l10n;
    final canCollection = _optCollections.length > 1 || _fCollection != null;
    final canFormat     = _optFormats.length > 1     || _fFormat != null;
    final canPlatform   = _optPlatforms.length > 1   || _fPlatform != null;
    final albumPodiums  = podiumCountsOf(_albums.map((x) => x.podium));
    final podCounts     = _tabs.index == 1 ? albumPodiums : _podiumSongCounts;
    final canPodium     = _fPodium != null ||
        podiumTotal(_podiumSongCounts) > 0 || podiumTotal(albumPodiums) > 0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(children: [
        RadioSurpriseButtons(
            onPlayAll:
                _notifier.value.isEmpty ? null : _playAllArtistSongs,
            onRadio: _startArtistRadio,
            onSurprise: _surpriseArtist),
        if (canCollection || canFormat || canPlatform || canPodium)
          const SizedBox(width: 12),
        if (canCollection)
          _facetChip(
            label: l10n.filterCollection,
            value: _fCollection,
            options: _optCollections.toList(),
            onPick: (v) => _fCollection = v,
          ),
        if (canFormat)
          _facetChip(
            label: l10n.searchFormat,
            value: _fFormat,
            options: _optFormats.toList(),
            onPick: (v) => _fFormat = v,
            upper: true,
          ),
        if (canPlatform)
          _facetChip(
            label: l10n.searchPlatform,
            value: _fPlatform,
            options: _optPlatforms.toList(),
            onPick: (v) => _fPlatform = v,
          ),
        if (canPodium)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InputChip(
              avatar: const Icon(Icons.emoji_events_outlined, size: 16),
              label: Text(podiumChipLabel(l10n, _fPodium, podiumTotal(podCounts))),
              selected: _fPodium != null,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              deleteIcon: _fPodium != null ? const Icon(Icons.close, size: 16) : null,
              onDeleted: _fPodium != null
                  ? () { _fPodium = null; _applyFilters(); }
                  : null,
              onPressed: () async {
                final v = await showPodiumPicker(context,
                    current: _fPodium, counts: podCounts);
                if (v == null || !mounted) return;
                _fPodium = v < 0 ? null : v;
                _applyFilters();
              },
            ),
          ),
      ]),
    );
  }

  Widget _buildAlbumsTab() {
    final l10n = context.l10n;
    if (_albumsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final albums = _filteredAlbums;
    if (albums.isEmpty) {
      return Center(
        child: Text(l10n.browseNoAlbum,
            style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    return ListView.builder(
      itemCount: albums.length,
      itemBuilder: (ctx, i) {
        final a = albums[i];
        return ListTile(
          // Placeholder thématisé (voir RailArtwork): un `placeholder:`
          // explicite l'écrase et rendait une icône générique.
          leading: RailArtwork(
            url:          a.artworkUrl,
            artist:       widget.artistName,
            album:        a.name,
            formatHint:   a.format,
            platformName: a.platform,
            size:         48,
          ),
          title: _albumTitleWithVideoBadge(context,
              name: a.name, hasVideo: a.hasVideo, podium: a.podium),
          subtitle: Text([
            a.collection,
            if (a.qualifier != null) a.qualifier!,
            l10n.searchSongsCount(a.songCount),
            a.fileSizeLabel,
            if (a.rating != null) '★ ${a.rating!.toStringAsFixed(1)}',
            if ((a.popularity ?? 0) >= 95)
              l10n.statsTopPercent((100 - a.popularity!).clamp(1, 100)),
          ].join('  ·  ')),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onPlayAlbum != null)
                _AlbumPlayButton(
                  onPlay: () => playAlbumFromList(
                    ctx,
                    a.name,
                    collection:  a.collection,
                    platform:    a.platform,
                    onPlayAlbum: widget.onPlayAlbum!,
                  ),
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => _pushAlbum(a),
        );
      },
    );
  }

  Widget _buildSongsTab() {
    if (_songsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ValueListenableBuilder<List<SearchResult>>(
      valueListenable: _notifier,
      builder: (_, results, __) {
        // NOT filtered by isAlbumLevelMatch, unlike the search tabs.
        //
        // That predicate answers "did a TEXT SEARCH match this row through its
        // album/game name rather than a track title?", and it detects it by
        // matchSubsongTitle being null. This tab is fed by browse_music, which
        // does no text search at all, so matchSubsongTitle is ALWAYS null here —
        // the test degenerated into "has an album and at least one subsong",
        // which is true of most of the catalogue. Every row was dropped: the tab
        // header showed the server's count while the list underneath was empty.
        if (results.isEmpty) {
          return Center(child: Text(context.l10n.searchNoSongs,
              style: Theme.of(context).textTheme.bodyMedium));
        }
        return Column(
          children: [
            _CountBar(
              loaded:  results.length,
              total:   '$_total',
              loading: _loadingMore,
              hasMore: _hasMore,
              // Pas de « Tout lire » ici: il vit dans la rangée de filtres,
              // devant Radio (`RadioSurpriseButtons.onPlayAll` dans
              // `_buildFilterBar`) — un seul bouton pour une seule action,
              // même règle que l'onglet Morceaux de la recherche. Le bouton
              // isolé de `_CountBar` reste pour les écrans qui n'ont PAS la
              // famille unifiée (DedicatedResultsScreen), où il est le seul.
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                itemCount: results.length + (_hasMore ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == results.length) {
                    WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _loadMoreSongs());
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return SongTile(
                      result: results[i],
                      onTap: widget.onTap,
                      onQueueAdd: widget.onQueueAdd,
                      onPlayAlbum: widget.onPlayAlbum,
                      // browse_music rows are tracks, never album matches.
                      albumRowsAllowed: false,
                      showCollection: true);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}


// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _CountBar extends StatelessWidget {
  final int  loaded;
  /// Déjà FORMATÉ — « 4403 », ou « 4403+ » quand le serveur dit que son
  /// décompte est un PLANCHER (`search_artists.truncated`, mig 247). null =
  /// total inconnu.
  final String? total;
  final bool loading;
  final bool hasMore;
  /// « Tout lire » — lance ce qui est AFFICHÉ (les lignes déjà chargées, pas
  /// le total serveur). La file est plafonnée en aval (kQueueLimit, annoncé).
  final VoidCallback? onPlayAll;

  const _CountBar({
    required this.loaded,
    required this.total,
    required this.loading,
    required this.hasMore,
    this.onPlayAll,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String label;
    if (total != null) {
      label = l10n.countTotal(loaded, total!);
    } else if (hasMore) {
      label = l10n.countLoadingMore(loaded);
    } else {
      label = l10n.countComplete(loaded);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          if (loading) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
          if (onPlayAll != null) ...[
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.play_arrow, size: 20),
              tooltip: l10n.browsePlayAll,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 28),
              onPressed: onPlayAll,
            ),
          ],
        ],
      ),
    );
  }
}

// Generic infinite-scroll list with a _CountBar header — shared by the
// Artistes / Albums / Playlists tabs (the Tous tab uses _PaginatedSongList,
// which is bound to the SearchResult notifier). total < 0 = unknown (CountBar
// shows the loaded count only).
class _PaginatedListView extends StatefulWidget {
  final int  itemCount;
  final int  total;
  /// Le total n'est qu'un PLANCHER (search_artists.truncated): « 4403+ ».
  final bool totalIsFloor;
  final bool hasMore;
  final bool loadingMore;
  final Future<void> Function() loadMore;
  final Widget Function(BuildContext, int) itemBuilder;
  final Widget empty;

  const _PaginatedListView({
    required this.itemCount,
    required this.total,
    this.totalIsFloor = false,
    required this.hasMore,
    required this.loadingMore,
    required this.loadMore,
    required this.itemBuilder,
    required this.empty,
  });

  @override
  State<_PaginatedListView> createState() => _PaginatedListViewState();
}

class _PaginatedListViewState extends State<_PaginatedListView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      widget.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0 && !widget.loadingMore) return widget.empty;
    return Column(
      children: [
        _CountBar(
          loaded:  widget.itemCount,
          total: widget.total >= 0
              ? '${widget.total}${widget.totalIsFloor ? '+' : ''}'
              : null,
          loading: widget.loadingMore,
          hasMore: widget.hasMore,
        ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            itemCount: widget.itemCount + (widget.hasMore ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == widget.itemCount) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => widget.loadMore());
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return widget.itemBuilder(ctx, i);
            },
          ),
        ),
      ],
    );
  }
}

class _AlbumList extends StatelessWidget {
  final List<_AlbumId>        items;
  final int  total;
  final bool hasMore;
  final bool loadingMore;
  final Future<void> Function() loadMore;
  final void Function(_AlbumId) onTap;
  final OnPlayAlbum?            onPlay;

  const _AlbumList({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.loadingMore,
    required this.loadMore,
    required this.onTap,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return _PaginatedListView(
      itemCount:   items.length,
      total:       total,
      hasMore:     hasMore,
      loadingMore: loadingMore,
      loadMore:    loadMore,
      empty:       Center(child: Text(context.l10n.noItems)),
      itemBuilder: (ctx, i) => _AlbumTile(
        album:  items[i],
        onTap:  onTap,
        onPlay: onPlay,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Album tile — shows a local-download badge overlay when the album is cached
// ---------------------------------------------------------------------------

class _AlbumTile extends StatefulWidget {
  final _AlbumId              album;
  final void Function(_AlbumId) onTap;
  final OnPlayAlbum?            onPlay;

  const _AlbumTile({
    required this.album,
    required this.onTap,
    this.onPlay,
  });

  @override
  State<_AlbumTile> createState() => _AlbumTileState();
}

class _AlbumTileState extends State<_AlbumTile> {
  bool _isLocal    = false;
  bool _inLibrary  = false;

  @override
  void initState() {
    super.initState();
    LocalDb.instance.addListener(_recheck);
    _checkLocal();
    _recheck();
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_recheck);
    super.dispose();
  }

  void _recheck() {
    // Match by album UUID (name-only lit the star on every homonym album and
    // never refreshed after a favourite toggle).
    LocalDb.instance
        .isAlbumInLibrary(widget.album.name, albumId: widget.album.albumId)
        .then((v) {
      if (mounted && v != _inLibrary) setState(() => _inLibrary = v);
    });
  }

  Future<void> _checkLocal() async {
    final local = await LocalDb.instance.hasLocalAlbum(widget.album.name);
    if (local && mounted) setState(() => _isLocal = true);
  }

  @override
  Widget build(BuildContext context) {
    final a  = widget.album;
    final cs = Theme.of(context).colorScheme;

    final artwork = Stack(
      clipBehavior: Clip.none,
      children: [
        // Placeholder thématisé par plateforme, comme partout ailleurs: un
        // `placeholder:` explicite l'écrase, et l'onglet Albums de la
        // recherche montrait une icône générique là où les grilles d'albums
        // affichent la pochette d'origine.
        RailArtwork(
          url:          a.artworkUrl,
          album:        a.name,
          artist:       a.artistNames.firstOrNull,
          formatHint:   a.format,
          platformName: a.platform,
          size:         48,
        ),
        if (_isLocal)
          Positioned(
            bottom: 0,
            right:  0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: cs.surface.withAlpha(210),
                borderRadius: const BorderRadius.only(
                  topLeft:     Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Icon(Icons.offline_pin_rounded,
                  size: 14, color: cs.primary),
            ),
          ),
        if (_inLibrary)
          const Positioned(
            top:   2,
            right: 2,
            child: Icon(
              Icons.star_rounded,
              size: 16,
              color: kFavoriteColor,
              shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
            ),
          ),
      ],
    );

    // Build subtitle: qualifier line + optional alias lines
    Widget? subtitle;
    {
      final tt = Theme.of(context).textTheme;
      // Qualifier line + album size (search_albums.file_size) on the same row.
      final metaText = [
        if (a.qualifier != null) a.qualifier!,
        if (a.fileSizeLabel != null) a.fileSizeLabel!,
        // Album-grain scores (207/208 rules: NULL ≠ 0★; percentile = a rank,
        // top of the basket only, clamped — « Top 0 % » means nothing).
        if (a.rating != null) '★ ${a.rating!.toStringAsFixed(1)}',
        if ((a.popularity ?? 0) >= 95)
          context.l10n.statsTopPercent((100 - a.popularity!).clamp(1, 100)),
      ].join('  ·  ');
      final aliasLines = a.aliases
          .map((al) => al.label)
          .toList();
      final artistsText = a.artistNames.isNotEmpty ? a.artistNames.join(' · ') : null;
      final hasBadge = _matchReasonLabel(a.matchReason, context.l10n) != null;

      if (metaText.isNotEmpty || artistsText != null || aliasLines.isNotEmpty || hasBadge) {
        subtitle = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (metaText.isNotEmpty)
              Text(metaText,
                  style: tt.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            if (artistsText != null)
              Text(artistsText,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            for (final label in aliasLines)
              Text(
                context.l10n.searchAka(label),
                style: tt.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            _MatchReasonBadge(a.matchReason),
          ],
        );
      }
    }

    return ListTile(
      leading:  artwork,
      title:    _albumTitleWithVideoBadge(context,
          name: a.name, hasVideo: a.hasVideo, podium: a.podium),
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onPlay != null)
            _AlbumPlayButton(
              onPlay: () => playAlbumFromList(
                context,
                a.name,
                collection:  a.collection,
                platform:    a.platform,
                onPlayAlbum: widget.onPlay!,
              ),
            ),
          LibraryButton(
            type:       'album',
            // The UUID, not the name: without it this button asked
            // isAlbumInLibrary() a name-only question, and adding ONE of the
            // two jw_spc "Final Fantasy VI" lit the button on both.
            refId:      albumLibraryRefId(a.name, a.albumId),
            name:       a.name,
            albumId:    a.albumId,
            collectionSlug: a.collection,
            platformName:   a.platform,
            artworkUrl: a.artworkUrl,
            iconSize:   20,
            padding:    const EdgeInsets.all(4),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => widget.onTap(a),
    );
  }
}

/// Play-album button with per-tile loading state.
/// Receives a pre-built async callback that fetches songs then triggers playback.
/// Album title with a small video badge when a track of the album has a
/// linked demozoo video (server `has_video` — see ArtistAlbum.hasVideo).
Widget _albumTitleWithVideoBadge(BuildContext context,
    {required String name, required bool hasVideo, CompoPodium? podium}) {
  if (!hasVideo && podium == null) return Text(name);
  return Row(children: [
    Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
    if (podium != null)
      Padding(
        padding: const EdgeInsets.only(left: 6),
        child: PodiumBadge(podium, size: 15),
      ),
    if (hasVideo)
      Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Icon(Icons.ondemand_video,
            size: 14, color: Theme.of(context).colorScheme.primary),
      ),
  ]);
}

class _AlbumPlayButton extends StatefulWidget {
  final Future<void> Function() onPlay;
  const _AlbumPlayButton({required this.onPlay});

  @override
  State<_AlbumPlayButton> createState() => _AlbumPlayButtonState();
}

class _AlbumPlayButtonState extends State<_AlbumPlayButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 24, height: 24,
        child: Padding(
          padding: EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.play_circle_outline),
      tooltip: context.l10n.browsePlayAlbum,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: () async {
        setState(() => _loading = true);
        try {
          await widget.onPlay();
        } finally {
          if (mounted) setState(() => _loading = false);
        }
      },
    );
  }
}

/// Artistes tab list — one row per `search_artists` result (artwork/icon, name,
/// "N morceaux · M albums" subtitle). match_reason badge lands in Step 3.
class _ArtistResultList extends StatelessWidget {
  final List<ArtistResult> items;
  final int  total;
  /// Voir `_PaginatedListView.totalIsFloor`.
  final bool totalIsFloor;
  final bool hasMore;
  final bool loadingMore;
  final Future<void> Function() loadMore;
  final void Function(ArtistResult) onTap;

  const _ArtistResultList({
    required this.items,
    required this.total,
    this.totalIsFloor = false,
    required this.hasMore,
    required this.loadingMore,
    required this.loadMore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _PaginatedListView(
      itemCount:   items.length,
      total:       total,
      totalIsFloor: totalIsFloor,
      hasMore:     hasMore,
      loadingMore: loadingMore,
      loadMore:    loadMore,
      empty:       Center(child: Text(l10n.noItems)),
      itemBuilder: (_, i) {
        final a = items[i];
        final parts = <String>[
          // Real name + country first: they tell two same-name artists apart
          // (two "Moby"s) before the user even opens the profile.
          if (a.realName != null && a.realName!.isNotEmpty &&
              a.realName != a.name)
            a.realName!,
          if (a.country != null && a.country!.isNotEmpty) a.country!,
          if (a.songCount > 0) l10n.searchSongsCount(a.songCount),
          if (a.albumCount > 0) l10n.searchAlbumsCount(a.albumCount),
        ];
        final hasBadge = _matchReasonLabel(a.matchReason, l10n) != null;
        return ListTile(
          leading: (a.artworkUrl != null && a.artworkUrl!.isNotEmpty)
              ? CircleAvatar(backgroundImage: NetworkImage(a.artworkUrl!))
              : const CircleAvatar(child: Icon(Icons.person)),
          title: ScrollingText(text: a.name),
          subtitle: (parts.isEmpty && !hasBadge)
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (parts.isNotEmpty) Text(parts.join(' · ')),
                    _MatchReasonBadge(a.matchReason),
                  ],
                ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onTap(a),
        );
      },
    );
  }
}

/// Scrollable, searchable collection picker shown as a modal bottom sheet.
/// "All" is pinned first; the active entry is highlighted; each row shows the
/// collection's file count. The search field is shown only when the list is long.
class _CollectionPickerSheet extends StatefulWidget {
  final List<Collection> collections;
  final String? selected; // null = all
  final ValueChanged<String?> onPick; // null = all

  const _CollectionPickerSheet({
    required this.collections,
    required this.selected,
    required this.onPick,
  });

  @override
  State<_CollectionPickerSheet> createState() => _CollectionPickerSheetState();
}

class _CollectionPickerSheetState extends State<_CollectionPickerSheet> {
  String _query = '';

  /// Familles DÉPLIÉES (clé → ouvert). La famille du slug sélectionné démarre
  /// ouverte: replier la sélection derrière un chevron la ferait chercher.
  late final Set<String> _expanded = {
    for (final f in kCollectionFamilies)
      if (widget.selected != null && widget.selected!.startsWith(f.prefix))
        f.key,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.collections
        : widget.collections
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.slug.toLowerCase().contains(q))
            .toList();
    // Le REGROUPEMENT ne vit qu'au repos: sous recherche, la liste est plate —
    // l'utilisateur a tapé, il veut des correspondances, pas de la structure.
    final entries = q.isEmpty ? groupCollections(filtered) : null;
    final showSearch = widget.collections.length > 8;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.searchChooseCollection,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            if (showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: CancelField(
                  hasText: _query.isNotEmpty,
                  onCleared: (_) => setState(() => _query = ''),
                  builder: (_) => TextField(
                    autofocus: false,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: l10n.searchFilterCollections,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (q.isEmpty)
                    _row(
                      context,
                      title: l10n.searchCollectionAll,
                      trailing: null,
                      selected: widget.selected == null,
                      onTap: () => widget.onPick(null),
                    ),
                  if (entries == null)
                    for (final c in filtered)
                      _row(
                        context,
                        title: c.name.isNotEmpty ? c.name : c.slug,
                        trailing: c.filesCount > 0 ? '${c.filesCount}' : null,
                        selected: widget.selected == c.slug,
                        onTap: () => widget.onPick(c.slug),
                      )
                  else
                    for (final e in entries)
                      ...switch (e) {
                        SingleCollectionEntry(:final collection) => [
                            _row(
                              context,
                              title: collection.name.isNotEmpty
                                  ? collection.name
                                  : collection.slug,
                              trailing: collection.filesCount > 0
                                  ? '${collection.filesCount}'
                                  : null,
                              selected: widget.selected == collection.slug,
                              onTap: () => widget.onPick(collection.slug),
                            ),
                          ],
                        CollectionFamilyEntry() => [
                          // La ligne de FAMILLE SÉLECTIONNE la famille entière
                          // (sentinel `family:<key>`, déplié en `p_collections`
                          // par l'écran — mig serveur 240; un serveur antérieur
                          // retombe sur « toutes », voir _postJsonOptional).
                          // Le DÉPLIAGE est sur le chevron, geste séparé: un
                          // seul tap ne peut pas vouloir dire les deux.
                          Builder(builder: (context) {
                            final famSel =
                                widget.selected == 'family:${e.key}';
                            final active =
                                famSel || e.contains(widget.selected);
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                  active
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  size: 20,
                                  color: active
                                      ? Theme.of(context).colorScheme.primary
                                      : null),
                              title: ScrollingText(
                                  text: e.label,
                                  style: TextStyle(
                                      fontWeight: active
                                          ? FontWeight.w600
                                          : FontWeight.normal)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${e.filesCount}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                        _expanded.contains(e.key)
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        size: 18),
                                    onPressed: () => setState(() =>
                                        _expanded.contains(e.key)
                                            ? _expanded.remove(e.key)
                                            : _expanded.add(e.key)),
                                  ),
                                ],
                              ),
                              onTap: () => widget.onPick('family:${e.key}'),
                            );
                          }),
                          if (_expanded.contains(e.key))
                            for (final c in e.members)
                              Padding(
                                padding: const EdgeInsets.only(left: 24),
                                child: _row(
                                  context,
                                  title: collectionMemberLabel(c, e.label),
                                  trailing: c.filesCount > 0
                                      ? '${c.filesCount}'
                                      : null,
                                  selected: widget.selected == c.slug,
                                  onTap: () => widget.onPick(c.slug),
                                ),
                              ),
                        ],
                      },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context,
      {required String title,
      required String? trailing,
      required bool selected,
      required VoidCallback onTap}) {
    final accent = Theme.of(context).colorScheme.primary;
    return ListTile(
      dense: true,
      leading: Icon(selected ? Icons.check_circle : Icons.circle_outlined,
          size: 20, color: selected ? accent : null),
      title: ScrollingText(
          text: title,
          style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      trailing: trailing == null
          ? null
          : Text(trailing,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
      onTap: onTap,
    );
  }
}

/// Format / Platform facet picker: filter field + counted values.
/// Values arrive server-sorted by count desc (search_facets); typing filters
/// them client-side (the whole list is already in memory — no RPC per keystroke).
/// Server-curated playlists list. Tap → load tracks → play as a queue.
/// Productions tab rows (search_productions). The server already disambiguates
/// homonyms (group + year in [ProductionRef.subtitle]), so the row shows the
/// bare title on top and the discriminators underneath.
class _ProductionList extends StatelessWidget {
  final List<ProductionSearchRow> items;
  final int  total;
  final bool hasMore;
  final bool loadingMore;
  final Future<void> Function() loadMore;
  final void Function(BuildContext, ProductionSearchRow) onTap;

  const _ProductionList({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.loadingMore,
    required this.loadMore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _PaginatedListView(
      itemCount:   items.length,
      total:       total,
      hasMore:     hasMore,
      loadingMore: loadingMore,
      loadMore:    loadMore,
      empty:       Center(child: Text(l10n.searchNoResults)),
      itemBuilder: (ctx, i) {
        final row = items[i];
        final p   = row.production;
        final sub = <String>[
          if (p.subtitle.isNotEmpty) p.subtitle,
          if (row.songCount > 0) l10n.browseTracksCount(row.songCount),
        ].join('  ·  ');
        return ListTile(
          leading: SizedBox(
            width: 48,
            height: 48,
            child: (p.artworkUrl != null && p.artworkUrl!.isNotEmpty)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(p.artworkUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.movie_outlined)),
                  )
                : const Icon(Icons.movie_outlined),
          ),
          title: Row(children: [
            Flexible(
              child:
                  Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            // Video of the PRODUCTION itself (server has_video, migs 161-163).
            if (row.hasVideo) ...[
              const SizedBox(width: 4),
              const Icon(Icons.ondemand_video, size: 14),
            ],
          ]),
          subtitle: sub.isEmpty
              ? null
              : Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
          // Video-only production (song_count=0 + has_video): nothing to
          // play, the row goes straight to the video.
          trailing: Icon(row.isVideoOnly
              ? Icons.play_circle_outline
              : Icons.chevron_right),
          onTap: () => onTap(ctx, row),
        );
      },
    );
  }
}

class _PlaylistList extends StatelessWidget {
  final List<Playlist> items;
  final int  total;
  final bool hasMore;
  final bool loadingMore;
  final Future<void> Function() loadMore;
  final Future<void> Function(BuildContext, Playlist) onTap;
  final Future<void> Function(BuildContext, Playlist)? onPlay;

  const _PlaylistList({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.loadingMore,
    required this.loadMore,
    required this.onTap,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _PaginatedListView(
      itemCount:   items.length,
      total:       total,
      hasMore:     hasMore,
      loadingMore: loadingMore,
      loadMore:    loadMore,
      empty:       Center(child: Text(l10n.searchNoPlaylist)),
      itemBuilder: (ctx, i) {
        final p = items[i];
        final sub = <String>[
          l10n.browseTracksCount(p.trackCount),
          // A published USER playlist is credited to its author's pen name
          // (migration 193); a server-curated one carries none, so this simply
          // does not appear on it — no need to know which is which.
          if ((p.authorName ?? '').isNotEmpty)
            l10n.playlistByAuthor(p.authorName!),
          if (p.tags.isNotEmpty) p.tags.take(3).join(' · '),
        ].join('  ·  ');
        return ListTile(
          leading: SizedBox(
            width: 48,
            height: 48,
            child: (p.coverUrl != null && p.coverUrl!.isNotEmpty)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(p.coverUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.queue_music)),
                  )
                : const Icon(Icons.queue_music),
          ),
          title: ScrollingText(text: p.name),
          subtitle: _matchReasonLabel(p.matchReason, l10n) == null
              ? Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
                    _MatchReasonBadge(p.matchReason),
                  ],
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onPlay != null)
                IconButton(
                  icon: const Icon(Icons.play_circle_outline),
                  tooltip: l10n.browsePlayPlaylist,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => onPlay!(ctx, p),
                ),
              LibraryButton(
                type:       'playlist',
                refId:      p.id,
                name:       p.name,
                artworkUrl: p.coverUrl,
                filename:   p.slug,
                formatExt:  p.trackCount > 0 ? '${p.trackCount}' : null,
                artist:     p.authorName,
                iconSize:   20,
                padding:    const EdgeInsets.all(4),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => onTap(ctx, p),
        );
      },
    );
  }
}

// ── Apple-Music-style browse card (search landing) ────────────────────────────

class _BrowseCard extends StatefulWidget {
  final String       label;
  final IconData     icon;
  final List<Color>  colors;
  final VoidCallback onTap;

  const _BrowseCard({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_BrowseCard> createState() => _BrowseCardState();
}

class _BrowseCardState extends State<_BrowseCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    // The old shape had NO visible feedback: InkWell paints its hover/ripple
    // on the ancestor Material, and the opaque gradient Container covered it
    // entirely. The ink layer now sits ON TOP of the gradient (transparent
    // Material filling the Stack), plus a slight hover scale for desktop.
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.colors,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 6,
                bottom: 2,
                child: Icon(
                  widget.icon,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    widget.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                    ),
                  ),
                ),
              ),
              // Ink ABOVE the gradient: hover veil + tap ripple both visible.
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    hoverColor: Colors.white.withValues(alpha: 0.10),
                    splashColor: Colors.white.withValues(alpha: 0.18),
                    highlightColor: Colors.white.withValues(alpha: 0.08),
                    onTap: widget.onTap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
