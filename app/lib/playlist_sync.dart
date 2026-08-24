import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'local_db.dart';
import 'rewamp_db.dart';
import 'user_settings.dart';

/// Backup and restore of the user's LOCAL playlists through their account.
///
/// What travels is the playlist, not the audio: the user moves their own files
/// between devices. An entry the catalogue knows comes back downloadable; an
/// entry that is a file of their own comes back as a `ext_ref` snapshot and
/// shows as missing until that file is there (server migration 176 — before it,
/// such entries were dropped silently and the playlist arrived holed).
///
/// The push is a FULL replacement (`reorder_playlist` with the complete entry
/// list): order and duplicates are part of the playlist, and a diff would have
/// to reason about positions that the server re-densifies after every write.
class PlaylistSync {
  PlaylistSync._();

  /// Entry → what to send. Every entry travels with its snapshot (`ext_ref`),
  /// plus its `song_id` when the catalogue knows it — verified against the
  /// server: an entry carrying both comes back COMPLETE, catalogue columns
  /// included, so nothing is lost by always sending both.
  static PlaylistItemPayload? _payloadOf(PlaylistEntry e) {
    // The CATALOGUE id, never the local one: a container subsong is stored here
    // as '<uuid>#<i>', which the server's uuid column rejects outright (22P02)
    // — one such entry failed the push of the whole playlist. What '#<i>'
    // encodes (which entry of the tracklist) is carried by the ext_ref below,
    // which every catalogue entry sends precisely for this.
    final songId = catalogueSongId(e.songId);
    final fileName = e.filePath != null && e.filePath!.isNotEmpty
        ? p.basename(e.filePath!)
        : (e.relPath != null && e.relPath!.isNotEmpty
            ? p.basename(e.relPath!)
            : e.track?.filePath != null
                ? p.basename(e.track!.filePath)
                : null);

    // The ext_ref goes along even for a catalogue entry. Two reasons, both
    // measured: a song_id the server does not know is dropped SILENTLY (an
    // entry vanished from a 101-entry playlist on the first round trip), and
    // the file name it carries is what lets another device re-bind a copy the
    // user brought over themselves.
    if (fileName == null || fileName.isEmpty) {
      // Nothing identifies this entry — it cannot be restored anywhere. Only
      // possible for a row with no snapshot at all (pre-migration-28 residue).
      return songId != null && songId.isNotEmpty
          ? PlaylistItemPayload(songId: songId)
          : null;
    }
    final catalogued = songId != null && songId.isNotEmpty;
    return PlaylistItemPayload(
      songId: catalogued ? songId : null,
      // A CATALOGUE entry only needs what the catalogue cannot say: which file
      // and which subsong. Title, artist, album, duration and the local path
      // all come back with the song row, so sending them again costs bytes on
      // every push for nothing (measured on a 100-entry playlist: 25 kB → 12 kB).
      // An out-of-catalogue entry keeps the full snapshot — there it IS the
      // only description of the tune.
      // The album id rides along in BOTH forms, catalogue included: it is
      // exactly what the song row cannot give back when the id is a
      // container's, and without it the receiving device writes a track row
      // with no album — the inert album link and the coverless recents tile.
      extRef: catalogued
          ? PlaylistExtRef(
              fileName:   fileName,
              entryPath:  e.entryPath,
              subsongIdx: e.subsongIdx,
              albumId:    e.albumId ?? e.track?.albumId,
            )
          : PlaylistExtRef(
              fileName:   fileName,
              relPath:    e.relPath,
              entryPath:  e.entryPath,
              subsongIdx: e.subsongIdx,
              title:      e.track?.title  ?? e.title,
              artist:     e.track?.artist ?? e.artist,
              album:      e.album,
              albumId:    e.albumId ?? e.track?.albumId,
              formatExt:  e.formatExt,
              durationS:  e.durationS,
            ),
    );
  }

  /// Identity of an entry for matching a remote row against a local one: the
  /// catalogue id when there is one, else the file name — plus the subsong,
  /// which distinguishes two entries of the same file.
  static String _entryKey(String? songId, String? path, int subsongIdx) {
    if (songId != null && songId.isNotEmpty) return 'S:$songId:$subsongIdx';
    final name = (path == null || path.isEmpty) ? '' : p.basename(path);
    return 'F:$name:$subsongIdx';
  }

  /// Pushes ONE local playlist to the account, creating the remote copy the
  /// first time. Returns the server id, or null when there is no account yet.
  static Future<String?> push(UserPlaylist playlist, {bool force = false}) async {
    if (!UserSettings.instance.hasAuthToken) return null;

    // Nothing changed locally since the last successful push → the account copy
    // is already this version. Skipping matters: the push is a FULL replacement,
    // so an unconditional one re-uploaded every entry of every playlist on every
    // sync (100 entries per run here), and it also cleared the "in sync with
    // version X" marker, which then forced the pull to re-download them.
    final localUpdated = playlist.updatedAt.millisecondsSinceEpoch ~/ 1000;
    if (!force &&
        playlist.isSynced &&
        playlist.pushedAt != 0 &&
        localUpdated <= playlist.pushedAt) {
      return playlist.serverId;
    }

    final entries = await LocalDb.instance.getPlaylistEntryRefs(playlist.id);
    final payload = <PlaylistItemPayload>[
      for (final e in entries)
        if (_payloadOf(e) case final pl?) pl,
    ];

    var serverId = playlist.serverId;
    DateTime? serverVersion;

    if (serverId == null || serverId.isEmpty) {
      // ACK PERDU sur une création précédente: le serveur a la playlist, la
      // réponse n'est jamais arrivée, et `serverId` est resté nul — recréer
      // fabrique un DOUBLON de compte (que la pull redescend ensuite en
      // doublon local). L'adoption de la pull ne couvre pas ce cas: elle
      // exige `pushed_at > 0`, or une PREMIÈRE création perdue n'a jamais
      // marqué quoi que ce soit. Avant de créer, on cherche donc au compte
      // une copie du même nom et du même nombre d'entrées QUE RIEN DE LOCAL
      // ne pointe — état transitoire par nature: une copie de compte sans
      // jumelle locale est normalement matérialisée par la pull suivante,
      // donc la trouver ici est la signature de l'ACK perdu.
      try {
        final mine = await RewampDb.listPlaylists(onlyMine: true, limit: 500);
        for (final r in mine) {
          if (!r.isOwned ||
              r.name != playlist.name ||
              r.trackCount != payload.length) {
            continue;
          }
          if (await LocalDb.instance.playlistByServerId(r.id) != null) {
            continue; // une locale la pointe déjà: vraie homonyme, on crée
          }
          debugPrint('[PlaylistSync] create: adopting lost-ack twin '
              '"${r.name}" → ${r.id}');
          await LocalDb.instance.setPlaylistServerLink(playlist.id, r.id,
              serverUpdatedAt: r.updatedAt);
          await LocalDb.instance.setPlaylistPushedState(playlist.id,
              localUpdatedAt: localUpdated, entryCount: payload.length);
          return r.id;
        }
      } catch (_) {/* la recherche est un bonus: on crée comme avant */}
      final created = await RewampDb.createPlaylist(
        name: playlist.name,
        description: playlist.description,
        entries: payload,
      );
      serverId = created.id;
      serverVersion = created.updatedAt;
    } else if (playlist.dirtyKind == 'append' &&
        playlist.pushedCount > 0 &&
        payload.length > playlist.pushedCount) {
      // Only additions at the END since the last push: send the TAIL. A push is
      // otherwise a FULL replacement, so adding one track to a 100-entry
      // playlist re-uploaded all of it (~12 kB) instead of a few hundred bytes.
      // The server appends in the order given.
      final tail = payload.sublist(playlist.pushedCount);
      final added = await RewampDb.addPlaylistItems(
        playlistId: serverId,
        entries: tail,
        ifUnmodifiedSince: playlist.serverVersion,
      );
      if (added.conflict) {
        // ACK PERDU sur CET append: le serveur l'a appliqué, la réponse s'est
        // perdue, et notre précondition (l'ancienne version) échoue contre la
        // version que NOTRE écriture a produite. La réponse de conflit porte
        // la playlist courante: si son compte d'entrées est exactement le
        // nôtre, l'append a déjà atterri — rejouer la queue la DUPLIQUERAIT
        // (contrairement au conflit ordinaire, où rien n'a été écrit et où
        // rejouer est justement la bonne réponse). On scelle l'état et c'est
        // fini. Compte différent = vraie édition d'un autre appareil, le
        // chemin de conflit ordinaire s'applique.
        final srv = added.playlist;
        if (srv != null && srv.trackCount == payload.length) {
          debugPrint('[PlaylistSync] append conflict = lost ack '
              '("${playlist.name}", ${payload.length} entries) — sealing');
          await LocalDb.instance.setPlaylistServerLink(playlist.id, serverId,
              serverUpdatedAt: srv.updatedAt ?? added.updatedAt);
          await LocalDb.instance.setPlaylistPushedState(playlist.id,
              localUpdatedAt: localUpdated, entryCount: payload.length);
          return serverId;
        }
        return _retryOnConflict(playlist, serverId, added, force);
      }
      serverVersion = added.updatedAt;
      debugPrint('[PlaylistSync] appended ${tail.length} entr(ies) to '
          '"${playlist.name}"');
    } else {
      // The version this push is based on, VERBATIM: synced_at is truncated to
      // the second, and a truncated precondition makes the server consider its
      // own row newer — every write then came back as a conflict.
      final base = playlist.serverVersion;

      final updated = await RewampDb.updatePlaylist(
        playlistId: serverId,
        name: playlist.name,
        description: playlist.description,
        ifUnmodifiedSince: base,
      );
      if (updated.conflict) {
        return _retryOnConflict(playlist, serverId, updated, force);
      }

      final reordered = await RewampDb.reorderPlaylist(
        playlistId: serverId,
        entries: payload,
        // The update above moved the version — base the second write on what it
        // just returned, else our OWN write looks like someone else's.
        ifUnmodifiedSince: updated.updatedAt ?? base,
      );
      if (reordered.conflict) {
        return _retryOnConflict(playlist, serverId, reordered, force);
      }
      serverVersion = reordered.updatedAt;
    }

    // The write returns the version it produced (mig 182), so the pair is known
    // to be in sync without re-reading the playlist.
    await LocalDb.instance.setPlaylistServerLink(playlist.id, serverId,
        serverUpdatedAt: serverVersion);
    await LocalDb.instance.setPlaylistPushedState(playlist.id,
        localUpdatedAt: localUpdated, entryCount: payload.length);
    debugPrint('[PlaylistSync] pushed "${playlist.name}" '
        '(${payload.length} entries) → $serverId');
    return serverId;
  }

  /// Another device wrote this playlist between our last sync and this push.
  ///
  /// Nothing was written, so the LOCAL edit is intact — and it is what the
  /// person in front of this device just did, so it wins. The conflict answer
  /// already carries the account's current version, so there is nothing to
  /// re-read: adopt that version as the precondition and push again, ONCE
  /// (two devices editing in a loop must not ping-pong).
  ///
  /// Pulling the remote content here instead would silently DISCARD the local
  /// edit — the pull replaces the entries — which is the opposite of what a
  /// conflict should cost.
  static Future<String?> _retryOnConflict(UserPlaylist playlist,
      String serverId, PlaylistWriteResult result, bool alreadyRetried) async {
    debugPrint('[PlaylistSync] conflict on "${playlist.name}"'
        '${alreadyRetried ? " — giving up for this run" : " — retrying on the current version"}');
    if (alreadyRetried) return serverId;
    final fresh = result.playlist?.updatedAt ?? result.updatedAt;
    if (fresh == null) return serverId;
    await LocalDb.instance
        .setPlaylistServerLink(playlist.id, serverId, serverUpdatedAt: fresh);
    final reloaded = await LocalDb.instance.playlistByServerId(serverId);
    return push(reloaded ?? playlist, force: true);
  }

  /// Pushes every local playlist. Returns (pushed, failed).
  static Future<(int, int)> pushAll() async {
    final playlists = await LocalDb.instance.getPlaylists();
    var ok = 0, ko = 0;
    for (final pl in playlists) {
      try {
        final id = await push(pl);
        if (id != null) {
          ok++;
        } else {
          ko++;
        }
      } catch (e) {
        debugPrint('[PlaylistSync] push "${pl.name}" FAILED: $e');
        ko++;
      }
    }
    return (ok, ko);
  }

  /// Brings the account's playlists down. A remote playlist already linked to a
  /// local one is REPLACED in place (the account is the reference for a pull);
  /// an unknown one creates a local playlist. Returns (created, updated).
  ///
  /// Server-curated playlists are ignored: only what the user owns
  /// (`is_owned`) is theirs to restore.
  /// [since] asks the server for the playlists whose CONTENT changed since a
  /// cursor (migration 182) instead of listing everything — every write moves
  /// `playlists.updated_at`, so this is exactly "what needs re-reading".
  /// [only] restricts the pass to one playlist (conflict resolution).
  /// [reconcile] additionally DELETES the local playlists the account no longer
  /// has: that requires the FULL list, so it is incompatible with [since].
  static Future<(int, int)> pull(
      {DateTime? since, String? only, bool reconcile = false}) async {
    if (!UserSettings.instance.hasAuthToken) return (0, 0);

    final remote = await RewampDb.listPlaylists(
        onlyMine: true, limit: 500, since: reconcile ? null : since);
    var created = 0, updated = 0;

    if (reconcile) {
      // A deleted playlist leaves no tombstone: it simply stops being listed
      // (spec §6bis). What is linked here and absent there was deleted
      // elsewhere.
      final live = {for (final r in remote) if (r.isOwned) r.id};
      for (final local in await LocalDb.instance.getPlaylists()) {
        final sid = local.serverId;
        if (sid == null || sid.isEmpty) continue; // never pushed: local-only
        if (live.contains(sid)) continue;
        debugPrint('[PlaylistSync] "${local.name}" deleted on another device');
        await LocalDb.instance.deletePlaylist(local.id);
      }
    }

    // Playlists that HAD an account copy and lost the link (pushed_at survives
    // the unlink, server_id does not) — the candidates for adoption below. A
    // playlist that was never backed up is deliberately excluded: backing up is
    // an explicit gesture, and a local-only playlist that happens to share a
    // name and a length with an account one must not be swallowed by it.
    final orphans = [
      for (final p in await LocalDb.instance.getPlaylists())
        if (!p.isSynced && p.pushedAt > 0) p,
    ];

    for (final r in remote) {
      if (!r.isOwned) continue;
      if (only != null && r.id != only) continue;
      var existing = await LocalDb.instance.playlistByServerId(r.id);

      // Nothing local points at this account copy — but it may BE one of ours,
      // arriving back under a new id. Signing into an account merges this
      // device's playlists into it server-side, while the client unlinks its
      // own (their ids belonged to the previous account) and re-pushes them —
      // and pushAll runs BEFORE pull, so the same playlist ends up twice in the
      // account and twice on the device, once more per sign-in. Adopting an
      // orphan of the same name and length instead of creating a second row is
      // what breaks that cycle; the push that follows then UPDATES the account
      // copy rather than creating another.
      var adopted = false;
      if (existing == null) {
        final idx = orphans.indexWhere(
            (o) => o.name == r.name && o.trackCount == r.trackCount);
        if (idx >= 0) {
          existing = orphans.removeAt(idx);
          adopted = true;
          debugPrint('[PlaylistSync] adopting "${r.name}" → ${r.id}');
        }
      }

      // Unchanged since this device last agreed with the account? Then its
      // tracks are already here — skip the round trip. Without this, every
      // sync re-downloaded every entry of every playlist (100 entries here,
      // for nothing). Both sides are the SERVER's updated_at, compared at
      // second granularity (synced_at is stored as unix seconds).
      // An adoption never takes this exit: the synced_at it carries was agreed
      // with the PREVIOUS account and says nothing about this copy.
      final syncedAt = existing?.syncedAt;
      if (!adopted && existing != null && syncedAt != null &&
          r.updatedAt != null &&
          r.updatedAt!.millisecondsSinceEpoch ~/ 1000 <=
              syncedAt.millisecondsSinceEpoch ~/ 1000) {
        continue;
      }

      final tracks = await RewampDb.playlistTracks(r.id);

      // What this device already knows about these tunes. The account copy is
      // authoritative on CONTENT and ORDER, never on where the file lives: it
      // carries no absolute path, so rebuilding entries from it alone threw the
      // local binding away and turned entries that played fine into "missing".
      final known = <String, List<PlaylistEntry>>{};
      if (existing != null) {
        for (final e in await LocalDb.instance.getPlaylistEntryRefs(existing.id)) {
          (known[_entryKey(e.songId, e.filePath ?? e.relPath, e.subsongIdx)] ??=
              []).add(e);
        }
      }

      final entries = <PlaylistEntry>[];
      for (final t in tracks) {
        final ref = t.extRef;
        final songId = t.songId.isEmpty ? null : t.songId;
        final relPath = ref?.relPath;
        // Duplicates are legal, so matches are CONSUMED in order rather than
        // reused: [A, B, A] must keep both A bindings, not the first one twice.
        final key = _entryKey(songId, ref?.fileName ?? relPath, t.subsongIdx);
        final prev = known[key];
        final reuse = (prev != null && prev.isNotEmpty) ? prev.removeAt(0) : null;

        final track = reuse?.track ??
            await LocalDb.instance.findTrackForSnapshot(
              songId:     songId,
              filePath:   reuse?.filePath,
              relPath:    relPath ?? reuse?.relPath,
              entryPath:  ref?.entryPath ?? '',
              subsongIdx: t.subsongIdx,
            );
        entries.add(PlaylistEntry(
          rowId:      0, // assigned by the insert
          track:      track,
          songId:     songId,
          filePath:   track?.filePath ?? reuse?.filePath,
          relPath:    relPath ?? reuse?.relPath,
          entryPath:  ref?.entryPath ?? '',
          subsongIdx: t.subsongIdx,
          title:      ref?.title  ?? t.title,
          artist:     ref?.artist ?? (t.artistNames.isEmpty ? null : t.artistNames.first),
          album:      ref?.album  ?? t.album,
          // Snapshot first, then the catalogue row, then whatever the local
          // entry already knew — a device that pushed before migration 38
          // sends no album_id, and its rows must not lose theirs on a pull.
          albumId:    ref?.albumId ?? t.albumId ?? reuse?.albumId,
          formatExt:  ref?.formatExt ?? t.formatExt,
          durationS:  t.durationMs == null ? null : t.durationMs! / 1000.0,
        ));
      }

      if (existing != null) {
        await LocalDb.instance.clearPlaylistEntries(existing.id);
        await LocalDb.instance
            .appendPlaylistEntries(existing.id, entries, touch: false);
        if (existing.name != r.name) {
          await LocalDb.instance.renamePlaylist(existing.id, r.name);
        }
        await LocalDb.instance.setPlaylistServerLink(existing.id, r.id,
            serverUpdatedAt: r.updatedAt);
        // The local copy now equals the account's, and no local change was
        // made: mark it pushed too, otherwise the next run re-uploads it.
        await LocalDb.instance.setPlaylistPushedState(existing.id,
            localUpdatedAt: existing.updatedAt.millisecondsSinceEpoch ~/ 1000,
            entryCount: entries.length);
        updated++;
      } else {
        final localId = await LocalDb.instance.createPlaylist(r.name);
        await LocalDb.instance
            .appendPlaylistEntries(localId, entries, touch: false);
        await LocalDb.instance.setPlaylistServerLink(localId, r.id,
            serverUpdatedAt: r.updatedAt);
        final fresh = await LocalDb.instance.playlistByServerId(r.id);
        if (fresh != null) {
          await LocalDb.instance.setPlaylistPushedState(fresh.id,
              localUpdatedAt: fresh.updatedAt.millisecondsSinceEpoch ~/ 1000,
              entryCount: entries.length);
        }
        created++;
      }
    }
    // Advance the content cursor to the newest version seen, so the next run
    // only asks for what moved after it.
    DateTime? maxSeen;
    for (final r in remote) {
      final u = r.updatedAt;
      if (u == null) continue;
      if (maxSeen == null || u.isAfter(maxSeen)) maxSeen = u;
    }
    if (maxSeen != null && only == null) {
      final prev = UserSettings.instance.playlistCursor;
      if (prev == null || maxSeen.isAfter(prev)) {
        UserSettings.instance.playlistCursor = maxSeen;
      }
    }
    debugPrint('[PlaylistSync] pulled: $created created, $updated updated');
    return (created, updated);
  }

  /// Re-pushes a playlist that is ALREADY linked, after a local edit. Silent
  /// no-op when it was never pushed (backing up is an explicit gesture) or when
  /// there is no account. Never throws: a failed sync must not break the edit
  /// the user just made locally.
  static Future<void> pushIfLinked(String localPlaylistId) async {
    try {
      final all = await LocalDb.instance.getPlaylists();
      final pl = all.where((p) => p.id == localPlaylistId).firstOrNull;
      if (pl == null || !pl.isSynced) return;
      await push(pl);
    } catch (e) {
      debugPrint('[PlaylistSync] pushIfLinked($localPlaylistId) failed: $e');
    }
  }

  // ── Organisation: folders + saved server playlists (server migration 178) ──
  //
  // A folder is an organisation decision, not a property of a playlist: the
  // server has no folder concept and cannot derive one. It is therefore carried
  // in the opaque client-state space, under a single key that covers BOTH the
  // local playlists (addressed by their account id) and the saved server ones.

  static const kFoldersKey = 'playlist_folders';
  static const _kFoldersKey = kFoldersKey;

  /// Value equality, key order aside. Postgres `jsonb` REORDERS object keys, so
  /// comparing raw encodings never matched and the key was rewritten on every
  /// sync — exactly the traffic this check exists to avoid.
  static bool sameJson(dynamic a, dynamic b) =>
      jsonEncode(_canon(a)) == jsonEncode(_canon(b));

  static dynamic _canon(dynamic v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: _canon(v[k])};
    }
    if (v is List) return [for (final e in v) _canon(e)];
    // 0 and 0.0 must compare equal: a jsonb round trip can change the form.
    if (v is num) return v == v.roundToDouble() ? v.toInt() : v;
    return v;
  }

  /// Snapshot of this device's organisation, in the shape stored server-side.
  ///
  /// Each assignment carries WHEN it was decided (`at`, epoch seconds). Without
  /// it the merge cannot tell an actual decision from a default: a device that
  /// had just received a playlist reported "folder: null" as loudly as the
  /// device that had filed it, and the playlist came back to the root.
  static Future<Map<String, dynamic>> _localOrganisation() async {
    final db = LocalDb.instance;
    final folders = await db.getAllPlaylistFolders();
    final assign = <String, dynamic>{};

    // Local playlists are addressed by their ACCOUNT id: the local id means
    // nothing on another device.
    for (final pl in await db.getPlaylists()) {
      final sid = pl.serverId;
      if (sid == null || sid.isEmpty) continue;
      assign[sid] = {'folder': pl.folderId, 'at': pl.folderChangedAt};
    }
    // Saved server playlists are already addressed by their own uuid.
    for (final item in await db.getLibraryItems(type: 'playlist')) {
      assign[item.refId] = {
        'folder': item.folderId,
        'at': item.folderChangedAt,
      };
    }

    return {
      'folders': [
        for (final f in folders)
          {'id': f.id, 'name': f.name, 'parent': f.parentId},
      ],
      'assign': assign,
    };
  }

  /// (folder, decidedAt) of one assignment, tolerating the first shape shipped
  /// (a bare folder id or null, with no timestamp).
  static (String?, int) _readAssign(dynamic v) {
    if (v is Map) {
      return (v['folder'] as String?, (v['at'] as num?)?.toInt() ?? 0);
    }
    return (v as String?, 0);
  }

  /// Merges two organisations. Folders are unioned (a folder is never implicitly
  /// deleted). For an assignment, the **most recent decision wins**, whichever
  /// device made it; ties go to the local one. What the other device organised
  /// and this one never touched is preserved untouched — losing another
  /// device's whole tree because a single key is shared is exactly what must
  /// not happen.
  static Map<String, dynamic> _mergeOrganisation(
      dynamic remote, Map<String, dynamic> local) {
    final folders = <String, Map<String, dynamic>>{};
    final assign = <String, Map<String, dynamic>>{};

    void ingest(dynamic src, {required bool isLocal}) {
      if (src is! Map) return;
      final fs = src['folders'];
      if (fs is List) {
        for (final f in fs) {
          if (f is Map && f['id'] is String) {
            folders[f['id'] as String] = {
              'id':     f['id'],
              'name':   f['name'],
              'parent': f['parent'],
            };
          }
        }
      }
      final a = src['assign'];
      if (a is! Map) return;
      a.forEach((k, v) {
        if (k is! String) return;
        final (folder, at) = _readAssign(v);
        final existing = assign[k];
        if (existing != null) {
          final prevAt = (existing['at'] as num?)?.toInt() ?? 0;
          if (at < prevAt || (at == prevAt && !isLocal)) return;
        }
        assign[k] = {'folder': folder, 'at': at};
      });
    }

    ingest(remote, isLocal: false);
    ingest(local,  isLocal: true);
    return {'folders': folders.values.toList(), 'assign': assign};
  }

  /// Applies a merged organisation to this device: creates the folders it does
  /// not have (same ids everywhere) and files each playlist it knows.
  static Future<void> _applyOrganisation(Map<String, dynamic> org) async {
    final db = LocalDb.instance;
    final fs = org['folders'];
    if (fs is List) {
      // Parents first, so a child never references a folder that is not there
      // yet — the tree can arrive in any order.
      final byId = <String, Map>{};
      for (final f in fs) {
        if (f is Map && f['id'] is String) byId[f['id'] as String] = f;
      }
      final done = <String>{};
      Future<void> insert(String id) async {
        if (!byId.containsKey(id) || done.contains(id)) return;
        done.add(id);
        final f = byId[id]!;
        final parent = f['parent'] as String?;
        if (parent != null) await insert(parent);
        await db.upsertPlaylistFolder(id, (f['name'] as String?) ?? '?', parent);
      }
      for (final id in byId.keys.toList()) {
        await insert(id);
      }
    }

    final assign = org['assign'];
    if (assign is! Map) return;

    // The decision's own timestamp is written back, NOT "now": applying a move
    // is not making one, and dating it now would make this device win the next
    // merge with a decision it merely received.
    for (final pl in await db.getPlaylists()) {
      final sid = pl.serverId;
      if (sid == null || !assign.containsKey(sid)) continue;
      final (folderId, at) = _readAssign(assign[sid]);
      if (folderId != pl.folderId || at != pl.folderChangedAt) {
        await db.movePlaylistToFolder(pl.id, folderId, changedAt: at);
      }
    }
    for (final item in await db.getLibraryItems(type: 'playlist')) {
      if (!assign.containsKey(item.refId)) continue;
      final (folderId, at) = _readAssign(assign[item.refId]);
      if (folderId != item.folderId || at != item.folderChangedAt) {
        await db.setLibraryItemFolder('playlist', item.refId, folderId,
            changedAt: at);
      }
    }
  }

  /// Pushes this device's organisation and applies what the account holds.
  /// Optimistic concurrency: the write carries the `updated_at` we read, and a
  /// conflict comes back as a RESULT with the current value (never as an
  /// error — PostgREST would replay a 40001 forever), which we merge and
  /// rewrite once.
  /// [state] is the client-state map already fetched by the caller — folders
  /// and favourites live in the same space, so ONE read serves both instead of
  /// one call per key on every sync.
  static Future<void> syncOrganisation(
      {Map<String, (dynamic, DateTime?)>? state}) async {
    if (!UserSettings.instance.hasAuthToken) return;

    final fetched =
        state ?? await RewampDb.getUserState(keys: const [_kFoldersKey]);
    final (remote, updatedAt) = fetched[_kFoldersKey] ?? (null, null);

    final local = await _localOrganisation();
    var merged = _mergeOrganisation(remote, local);

    // Writing a key that already holds this exact value is pure traffic — and
    // it happened on EVERY sync, since the merge of unchanged data is equal to
    // what is already there.
    if (remote != null && sameJson(remote, merged)) {
      await _applyOrganisation(merged);
      return;
    }

    final conflict =
        await RewampDb.setUserState(_kFoldersKey, merged,
            ifUnmodifiedSince: updatedAt);
    if (conflict != null) {
      // Someone else wrote in between: merge on top of THEIR value and retry
      // once. A second conflict is left alone — the next sync will settle it.
      merged = _mergeOrganisation(conflict.$1, local);
      await RewampDb.setUserState(_kFoldersKey, merged,
          ifUnmodifiedSince: conflict.$2);
    }

    await _applyOrganisation(merged);
  }

  /// Brings down the playlists the user put in their library on another device
  /// (server migration 178), and pushes the ones this device knows about.
  /// Returns how many were added locally.
  static Future<int> syncLibraryPlaylists() async {
    if (!UserSettings.instance.hasAuthToken) return 0;

    final db = LocalDb.instance;
    // Un geste encore en attente de livraison interdit d'appliquer l'état du
    // compte: il est plus ancien que ce geste, par construction.
    final settled = await db.pendingSyncCount() == 0;
    final localItems = await db.getLibraryItems(type: 'playlist');
    final localIds = {for (final i in localItems) i.refId};

    // TOUTES les lignes du compte, y compris `in_library = false`. La nuance
    // est ce qui distingue « le compte n'en a jamais entendu parler » de « elle
    // en a été RETIRÉE », et sans elle cette passe était add-only dans les deux
    // sens: l'appareil A retirait la playlist, l'appareil B la re-déclarait
    // `value: true` à sa synchro suivante (sa ligne locale existait encore et
    // le compte ne l'avait plus), et A la voyait revenir quelques secondes plus
    // tard. Un retrait ne pouvait jamais gagner contre l'autre appareil.
    final remoteAll = await RewampDb.userPlaylists(inLibrary: null);
    final known     = {for (final pl in remoteAll) pl.id};
    final remote    = [for (final pl in remoteAll) if (pl.inLibrary != false) pl];

    // Declare only what the account has NEVER heard of. Re-declaring every
    // saved playlist on every sync was a write per run for nothing — et
    // re-déclarer celles qu'il a retirées annulait le retrait.
    for (final item in localItems) {
      if (known.contains(item.refId)) continue;
      await RewampDb.setLibrary(
        itemId: item.refId, itemType: 'playlist', value: true);
    }

    // Retirée ailleurs: l'appliquer ici. C'est la moitié qui manquait — la
    // photo d'identités (`_reconcileRemovals`) ne passe que toutes les 12 h.
    if (settled) {
      for (final pl in remoteAll) {
        if (pl.inLibrary != false) continue;
        if (!localIds.contains(pl.id)) continue;
        await db.removeFromLibrary('playlist', pl.id);
      }
    }

    // Author of a playlist saved BEFORE the pen name was stored locally: fill
    // it in once. Only when the row has none and the account has one, so this
    // is a no-op on every later run rather than a write per playlist per sync.
    final localById = {for (final i in localItems) i.refId: i};
    for (final pl in remote) {
      final local = localById[pl.id];
      if (local == null ||
          (pl.authorName ?? '').isEmpty ||
          (local.artist ?? '').isNotEmpty) {
        continue;
      }
      await db.addToLibrary(
        type:       'playlist',
        refId:      pl.id,
        name:       pl.name,
        artworkUrl: pl.coverUrl,
        formatExt:  pl.trackCount > 0 ? '${pl.trackCount}' : null,
        artist:     pl.authorName,
      );
    }

    var added = 0;
    for (final pl in remote) {
      if (localIds.contains(pl.id)) continue;
      await db.addToLibrary(
        type:       'playlist',
        refId:      pl.id,
        name:       pl.name,
        artworkUrl: pl.coverUrl,
        // The saved-playlist row stashes its entry count in format_ext (a
        // playlist has no format) — see LibraryItem.playlistCount.
        formatExt:  pl.trackCount > 0 ? '${pl.trackCount}' : null,
        // …and the author's pen name in `artist`, so the library list can
        // credit a published user playlist without a round-trip. Empty on the
        // server's own playlists, which have no author.
        artist:     pl.authorName,
      );
      added++;
    }
    return added;
  }

  /// Forgets the account copy: deletes it server-side and unlinks the local
  /// playlist, which stays untouched.
  static Future<void> unlink(UserPlaylist playlist) async {
    final serverId = playlist.serverId;
    if (serverId == null || serverId.isEmpty) return;
    try {
      await RewampDb.deletePlaylist(serverId);
    } catch (e) {
      // Already gone server-side (another device deleted it) — unlink anyway.
      debugPrint('[PlaylistSync] delete $serverId failed: $e');
    }
    await LocalDb.instance.setPlaylistServerLink(playlist.id, null);
  }
}
