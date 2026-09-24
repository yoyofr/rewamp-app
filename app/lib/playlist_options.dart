import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import 'app_snack.dart';
import 'display_name_dialog.dart';
import 'l10n.dart';
import 'local_db.dart';
import 'playlist_sync.dart';
import 'rewamp_db.dart' show Playlist, RewampDb, RewampRpcException;
import 'user_settings.dart';
import 'scrolling_text.dart';

/// Everything the "…" menu of a USER playlist can do — rename, move, back up,
/// publish, delete — in one place.
///
/// It lives outside the library list because the same menu belongs on the
/// playlist's own screen: a user who opened a playlist to work on it should not
/// have to walk back up to the list to rename it. Both callers get the same
/// entries, in the same order, with the same guards.
///
/// The publication state (review status per playlist, the account's pen name)
/// is SERVER-ONLY, so the caller passes what it already knows and anything
/// missing is fetched here. The library list holds it for its badges and hands
/// it over; the playlist screen has none and lets this module fetch.
class PlaylistOptions {
  PlaylistOptions._();

  /// Opens the menu for [playlist] and runs whatever the user picks.
  ///
  /// [onChanged] runs after any change that the caller may need to reflect and
  /// that the LocalDb listener does NOT cover — publication state in
  /// particular, which never touches the local database. [onDeleted] runs
  /// instead when the playlist is gone (the playlist screen must close itself;
  /// the list just reloads).
  static Future<void> show(
    BuildContext context, {
    required UserPlaylist playlist,
    Playlist? review,
    String? displayName,
    int pendingReviews = 0,
    List<PlaylistFolder>? folders,
    Future<void> Function()? onChanged,
    VoidCallback? onDeleted,
  }) async {
    final l10n = context.l10n;
    // What the caller could not supply: fetch it, but never let a network
    // failure keep the menu shut — offline, publication entries simply behave
    // as "not published yet" and the server has the last word anyway.
    var rev  = review;
    var name = displayName;
    var pending = pendingReviews;
    if (review == null || displayName == null) {
      final state = await fetchPublicState();
      if (!context.mounted) return;
      rev ??= state.$1[playlist.serverId ?? ''];
      name ??= state.$2;
      if (review == null) {
        pending = state.$1.values.where((p) => p.isPendingReview).length;
      }
    }
    final allFolders =
        folders ?? await LocalDb.instance.getAllPlaylistFolders();
    if (!context.mounted) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      // Scrollable: a modal sheet is capped at about half the window, and this
      // menu carries up to seven entries with subtitles — on a short window the
      // last ones were simply cut off (13-pixel overflow on macOS).
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.commonRename),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            if (allFolders.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: Text(l10n.playlistMoveToFolder),
                onTap: () => Navigator.pop(ctx, 'move'),
              ),
            ListTile(
              leading: Icon(playlist.isSynced
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_upload_outlined),
              title: Text(playlist.isSynced
                  ? l10n.playlistBackupUpdate
                  : l10n.playlistBackupToAccount),
              subtitle: Text(playlist.isSynced
                  ? l10n.playlistBackupUpdateSubtitle
                  : l10n.playlistBackupSubtitle),
              onTap: () => Navigator.pop(ctx, 'backup'),
            ),
            if (playlist.isSynced)
              ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: Text(l10n.playlistBackupStop),
                onTap: () => Navigator.pop(ctx, 'unlink'),
              ),
            // Publishing is a REQUEST: pending/approved offer the way back,
            // private/rejected offer to (re)submit.
            if (rev != null && (rev.isPendingReview || rev.isApproved))
              ListTile(
                leading: const Icon(Icons.public_off),
                title: Text(l10n.playlistUnpublish),
                subtitle: Text(rev.isApproved
                    ? l10n.playlistUnpublishSubtitle
                    : l10n.playlistPublishPending),
                onTap: () => Navigator.pop(ctx, 'withdraw'),
              )
            else
              ListTile(
                leading: const Icon(Icons.public),
                title: Text(l10n.playlistPublish),
                subtitle: Text(rev != null && rev.isReviewRejected
                    ? l10n.playlistPublishRejectedShort
                    : l10n.playlistPublishSubtitle),
                onTap: () => Navigator.pop(ctx, 'publish'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.commonDelete),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ]),
        ),
      ),
    );
    if (!context.mounted || action == null) return;

    switch (action) {
      case 'rename':
        await _rename(context, playlist, rev, onChanged);
      case 'move':
        final dest = await pickFolder(context, allFolders,
            currentId: playlist.folderId);
        if (dest != null) {
          await LocalDb.instance.movePlaylistToFolder(playlist.id, dest.id);
        }
      case 'backup':
        await backup(context, playlist);
      case 'unlink':
        await PlaylistSync.unlink(playlist);
        if (context.mounted) AppSnack.show(context, l10n.playlistBackupStopped);
      case 'publish':
        await publish(context, playlist,
            displayName: name, pendingReviews: pending, onChanged: onChanged);
      case 'withdraw':
        await withdraw(context, playlist, onChanged: onChanged);
      case 'delete':
        if (await confirm(context, l10n.playlistDeleteTitle(playlist.name),
            l10n.playlistDeleteBody)) {
          // The account copy goes with it: leaving it there would resurrect the
          // playlist on the next pull.
          if (playlist.isSynced) await PlaylistSync.unlink(playlist);
          await LocalDb.instance.deletePlaylist(playlist.id);
          onDeleted?.call();
        }
    }
  }

  /// (review by server id, account display name). Empty/null when there is no
  /// account or the network is down — publication then reads as "never asked".
  static Future<(Map<String, Playlist>, String?)> fetchPublicState() async {
    if (!UserSettings.instance.hasAuthToken) {
      return (const <String, Playlist>{}, null);
    }
    try {
      final mine = await RewampDb.listPlaylists(onlyMine: true, limit: 200);
      final acc  = await RewampDb.getAccount();
      return ({for (final p in mine) p.id: p}, acc?.displayName);
    } catch (_) {
      // Offline: the badges simply do not show. Nothing here is destructive
      // enough to be worth an error banner on a library screen.
      return (const <String, Playlist>{}, null);
    }
  }

  static Future<void> _rename(BuildContext context, UserPlaylist p,
      Playlist? review, Future<void> Function()? onChanged) async {
    final l10n = context.l10n;
    // The name and the description are what gets moderated, so renaming a
    // playlist that is pending or public sends it back through review and
    // unpublishes it meanwhile. Say so BEFORE, or the author watches it
    // disappear and blames the rename for something else. Adding or reordering
    // tracks does nothing of the sort.
    if (review != null && (review.isPendingReview || review.isApproved)) {
      final go = await confirm(context, l10n.playlistRenamePublishedTitle,
          l10n.playlistRenamePublishedBody, confirmLabel: l10n.commonRename);
      if (!go || !context.mounted) return;
    }
    final name = await promptName(context, l10n.playlistRenameTitle,
        initial: p.name);
    if (name == null || name.isEmpty) return;
    await LocalDb.instance.renamePlaylist(p.id, name);
    await PlaylistSync.pushIfLinked(p.id);
    if (review != null) await onChanged?.call();
  }

  // ── Publishing (migrations 192/193) ───────────────────────────────────────
  //
  // The server refuses a submission with a bare 23514 whatever the reason, so
  // all four rules are checked HERE: a user who is told "invalid" and nothing
  // else has no way to act. The server stays the authority — these checks only
  // decide which sentence to show.

  /// The message explaining why this playlist cannot be submitted, or null when
  /// it can. Order matters: the missing pen name comes first because it is the
  /// only one with something to do about it right there.
  static String? publishBlocker(BuildContext context, List<PlaylistEntry> entries,
      {String? displayName, int pendingReviews = 0}) {
    final l10n = context.l10n;
    if ((displayName ?? '').isEmpty) return l10n.playlistPublishNeedName;
    final catalogue = entries.where((e) => (e.songId ?? '').isNotEmpty).length;
    final local = entries.length - catalogue;
    // A local file is unplayable for everyone else AND its description is text
    // the client wrote, which nobody moderated.
    if (local > 0) return l10n.playlistPublishHasLocal;
    if (catalogue < 5) return l10n.playlistPublishNeedTracks;
    if (pendingReviews >= 3) return l10n.playlistPublishTooManyPending;
    return null;
  }

  static Future<void> publish(BuildContext context, UserPlaylist p,
      {String? displayName,
      int pendingReviews = 0,
      Future<void> Function()? onChanged}) async {
    final l10n = context.l10n;
    final entries = await LocalDb.instance.getPlaylistEntryRefs(p.id);
    if (!context.mounted) return;
    final blocker = publishBlocker(context, entries,
        displayName: displayName, pendingReviews: pendingReviews);
    if (blocker != null) {
      // No pen name yet: offer to pick one instead of stopping at the message.
      if ((displayName ?? '').isEmpty) {
        final res = await showDisplayNameDialog(context);
        if (res == null || !context.mounted) return;
        return publish(context, p,
            displayName: res.displayName,
            pendingReviews: pendingReviews,
            onChanged: onChanged);
      }
      AppSnack.show(context, blocker);
      return;
    }
    final ok = await confirm(context, l10n.playlistPublishTitle,
        l10n.playlistPublishBody, confirmLabel: l10n.playlistPublishCta);
    if (!ok || !context.mounted) return;
    try {
      // Push first: what the operator reviews must be what the user sees, and
      // a playlist that was never backed up has no server copy to submit.
      //
      // push() returns null for ONE reason: no account on this device. Falling
      // back to p.serverId here (as this did) submits an id that belongs to an
      // account we can no longer prove we own — the call dies on the server's
      // ownership check with 42501, which lands in the generic catch below and
      // reads as "publication failed" while nothing whatsoever reached the
      // server. Say what is actually wrong instead.
      final sid = await PlaylistSync.push(p, force: true);
      if (sid == null || sid.isEmpty) {
        if (context.mounted) {
          AppSnack.show(context, l10n.playlistBackupNoAccount);
        }
        return;
      }
      await RewampDb.submitPlaylistForReview(sid);
      if (!context.mounted) return;
      AppSnack.show(context, l10n.playlistPublishSubmitted);
      await onChanged?.call();
    } on RewampRpcException catch (e) {
      if (!context.mounted) return;
      debugPrint('[publish] submit refused: ${e.code} ${e.message}');
      // A 23514 here means a rule moved under us (tracks removed on another
      // device, a third playlist submitted elsewhere) — the server's word wins.
      AppSnack.show(context, e.code == '23514'
          ? l10n.playlistPublishRefused
          : _debugSuffix(l10n.playlistPublishFailed, e.code));
    } catch (e, st) {
      // Never swallow this one silently: a bare "failed" with no trace is what
      // made this failure impossible to diagnose from a tester's report.
      debugPrint('[publish] submit failed: $e\n$st');
      if (context.mounted) {
        AppSnack.show(context, _debugSuffix(l10n.playlistPublishFailed, '$e'));
      }
    }
  }

  static Future<void> withdraw(BuildContext context, UserPlaylist p,
      {Future<void> Function()? onChanged}) async {
    final l10n = context.l10n;
    final sid = p.serverId;
    if (sid == null || sid.isEmpty) return;
    try {
      await RewampDb.withdrawPlaylist(sid);
      if (!context.mounted) return;
      AppSnack.show(context, l10n.playlistPublishWithdrawn);
      await onChanged?.call();
    } catch (e) {
      debugPrint('[publish] withdraw failed: $e');
      if (context.mounted) {
        AppSnack.show(context, _debugSuffix(l10n.playlistPublishFailed, '$e'));
      }
    }
  }

  static Future<void> backup(BuildContext context, UserPlaylist p) async {
    final l10n = context.l10n;
    try {
      final id = await PlaylistSync.push(p);
      if (!context.mounted) return;
      AppSnack.show(context,
          id == null ? l10n.playlistBackupNoAccount : l10n.playlistBackupDone);
    } catch (e) {
      debugPrint('[playlist] backup failed: $e');
      if (context.mounted) AppSnack.show(context, l10n.playlistBackupFailed);
    }
  }

  /// Appends the underlying cause to a user-facing failure — DEBUG BUILDS ONLY.
  /// Release keeps the plain sentence; a code means nothing to a listener.
  static String _debugSuffix(String message, String detail) {
    if (kReleaseMode || detail.isEmpty) return message;
    final short = detail.length > 60 ? '${detail.substring(0, 60)}…' : detail;
    return '$message — $short';
  }
}

// ── Shared dialogs (used by both playlist screens) ──────────────────────────

Future<String?> promptName(BuildContext context, String title,
        {String? initial}) =>
    showDialog<String>(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        final ctrl = TextEditingController(text: initial);
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.playlistNameHint),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: Text(l10n.commonOk)),
          ],
        );
      },
    );

/// Shared confirm dialog (Cancel / `<confirm>`). Returns true if confirmed.
Future<bool> confirm(BuildContext context, String title, String body,
    {String? confirmLabel}) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel)),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel ?? l10n.commonDelete)),
      ],
    ),
  );
  return ok == true;
}

/// "Move to folder" picker. Returns a record whose `id` is the chosen folder
/// (null = root); returns null when the sheet is dismissed without a choice.
/// [currentId] is disabled (can't move an item onto its own folder). Folders
/// are rendered as a TREE (DFS from the roots, indented by depth) so a deep
/// folder/sub-folder arborescence stays legible instead of a flat dump.
Future<({String? id})?> pickFolder(
    BuildContext context, List<PlaylistFolder> allFolders,
    {String? currentId}) async {
  final l10n = context.l10n;
  final byParent = <String?, List<PlaylistFolder>>{};
  for (final f in allFolders) {
    (byParent[f.parentId] ??= []).add(f);
  }
  final ordered = <(PlaylistFolder, int)>[];
  void walk(String? parent, int depth) {
    for (final f in (byParent[parent] ?? const <PlaylistFolder>[])) {
      ordered.add((f, depth));
      walk(f.id, depth + 1);
    }
  }
  walk(null, 0);
  // Safety: any folder whose parent chain doesn't reach a root (shouldn't
  // happen — delete reparents — but never drop one) lands at depth 0.
  final seen = {for (final (f, _) in ordered) f.id};
  for (final f in allFolders) {
    if (!seen.contains(f.id)) ordered.add((f, 0));
  }

  return showModalBottomSheet<({String? id})>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: Text(l10n.playlistFolderRoot),
            enabled: currentId != null,
            onTap: () => Navigator.pop(ctx, (id: null)),
          ),
          for (final (f, depth) in ordered)
            ListTile(
              contentPadding:
                  EdgeInsets.only(left: 16.0 + depth * 20, right: 16),
              leading: const Icon(Icons.folder_outlined),
              title: ScrollingText(text: f.name),
              enabled: currentId != f.id,
              onTap: () => Navigator.pop(ctx, (id: f.id)),
            ),
        ],
      ),
    ),
  );
}
