import 'dart:convert';
import 'dart:io';

import 'uade_info.dart';
import 'user_settings.dart';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// ---------------------------------------------------------------------------
// Public model
// ---------------------------------------------------------------------------

/// Canonical library_items ref_id convention for tracks:
///   '<onlineId or filePath>?subsong=<idx>'
/// (PlayerController.libraryRefId writes this form.) This splits it back into
/// (baseId, subsongIdx); subsongIdx is null when the key carries no suffix
/// (legacy rows written with the bare online id).
(String, int?) splitLibraryRefId(String refId) {
  final q = refId.indexOf('?subsong=');
  if (q < 0) return (refId, null);
  return (refId.substring(0, q), int.tryParse(refId.substring(q + 9)));
}

/// Canonical library_items ref_id for an ALBUM: its server UUID when it has
/// one, its display name otherwise (a local folder has no catalogue identity).
///
/// The name alone was the key for a long time, and `library_items` is UNIQUE on
/// (type, ref_id) — so two HOMONYM albums shared one row: jw_spc has two "Final
/// Fantasy VI", and adding either lit the button on both, while the second add
/// overwrote the first's `album_id` and silently evicted it from the library.
/// Same lesson as `catalogueSongId` and the "Final Fantasy III" playback bug:
/// **an album NAME is not an identity**. Rows written before migration 41 are
/// rewritten by it; the name is still the key for albums with no UUID, which is
/// why [LocalDb.isAlbumInLibrary] keeps its name fallback.
String albumLibraryRefId(String name, String? albumId) =>
    (albumId != null && albumId.isNotEmpty) ? albumId : name;

class TrackRecord {
  final String  id;
  final String  filePath;
  final String  entryPath;   // '' = file_path IS the audio file
  final int     subsongIdx;  // 0 = whole file
  final String? title;
  final String? artist;
  final String? metaAlbum;
  // Server album_id (rewamp_db), when known — lets the player screen's
  // "Voir l'album" navigate to the exact album instead of resolving by name.
  // Stored in tracks.album_id; see getTracksForAlbum's primary (exact) match.
  final String? albumId;
  final int?    position;
  final double? durationS;
  final String? formatExt;
  /// Total subsongs of the CONTAINER file this row belongs to (denormalized on
  /// every row of the file). Server-sourced when known — the native probe
  /// returns a format default (HES/KSS → 256) for count-less headers, so this
  /// is what lets an OFFLINE recents replay rebuild the right queue.
  final int?    subsongCount;
  final String  source;
  final String? onlineId;
  final String? artworkUrl;
  /// Where the file came from, recorded when it was DOWNLOADED or played from
  /// a catalogue row (migration 52) — so a replay never has to re-derive it.
  final String? collectionSlug;
  final String? platformName;
  final int?    year;
  final bool    isFavorite;
  final bool    inLibrary;
  final int     playCount;
  final DateTime? lastPlayedAt;

  const TrackRecord({
    required this.id,
    required this.filePath,
    required this.entryPath,
    required this.subsongIdx,
    this.title,
    this.artist,
    this.metaAlbum,
    this.albumId,
    this.position,
    this.durationS,
    this.formatExt,
    this.subsongCount,
    required this.source,
    this.onlineId,
    this.artworkUrl,
    this.collectionSlug,
    this.platformName,
    this.year,
    required this.isFavorite,
    required this.inLibrary,
    required this.playCount,
    this.lastPlayedAt,
  });

  String get displayTitle => (title != null && title!.isNotEmpty) ? title! : p.basename(filePath);

  /// Même patron que `SearchResult.copyWith`, et pour la même raison: un
  /// faiseur de lignes n'énonce que sa DIFFÉRENCE. Recopier les vingt-deux
  /// champs à la main sur chaque site perd en silence ceux qu'on oublie —
  /// `isFavorite`, `playCount`, l'artwork — et la perte ne se voit qu'à
  /// l'écran, bien plus tard.
  ///
  /// Limite assumée: ne sait pas remettre un champ à null. Aucun appelant n'en
  /// a besoin; celui qui en aura besoin construira explicitement.
  TrackRecord copyWith({
    String? id,
    String? filePath,
    String? entryPath,
    int? subsongIdx,
    String? title,
    String? artist,
    String? metaAlbum,
    String? albumId,
    int? position,
    double? durationS,
    String? formatExt,
    int? subsongCount,
    String? source,
    String? onlineId,
    String? artworkUrl,
    String? collectionSlug,
    String? platformName,
    int? year,
    bool? isFavorite,
    bool? inLibrary,
    int? playCount,
    DateTime? lastPlayedAt,
  }) =>
      TrackRecord(
        id:             id             ?? this.id,
        filePath:       filePath       ?? this.filePath,
        entryPath:      entryPath      ?? this.entryPath,
        subsongIdx:     subsongIdx     ?? this.subsongIdx,
        title:          title          ?? this.title,
        artist:         artist         ?? this.artist,
        metaAlbum:      metaAlbum      ?? this.metaAlbum,
        albumId:        albumId        ?? this.albumId,
        position:       position       ?? this.position,
        durationS:      durationS      ?? this.durationS,
        formatExt:      formatExt      ?? this.formatExt,
        subsongCount:   subsongCount   ?? this.subsongCount,
        source:         source         ?? this.source,
        onlineId:       onlineId       ?? this.onlineId,
        artworkUrl:     artworkUrl     ?? this.artworkUrl,
        collectionSlug: collectionSlug ?? this.collectionSlug,
        platformName:   platformName   ?? this.platformName,
        year:           year           ?? this.year,
        isFavorite:     isFavorite     ?? this.isFavorite,
        inLibrary:      inLibrary      ?? this.inLibrary,
        playCount:      playCount      ?? this.playCount,
        lastPlayedAt:   lastPlayedAt   ?? this.lastPlayedAt,
      );

  factory TrackRecord.fromMap(Map<String, dynamic> m) => TrackRecord(
    id:           m['id']          as String,
    filePath:     LocalDb._denorm(m['file_path']   as String),
    entryPath:    LocalDb._denorm(m['entry_path']  as String),
    subsongIdx:   m['subsong_idx'] as int,
    title:        m['title']       as String?,
    artist:       m['artist']      as String?,
    metaAlbum:    m['meta_album']  as String?,
    albumId:      m['album_id']    as String?,
    position:     m['position']    as int?,
    durationS:    m['duration_s']  as double?,
    formatExt:    m['format_ext']  as String?,
    subsongCount: m['subsong_count'] as int?,
    source:       m['source']      as String,
    onlineId:     m['online_id']   as String?,
    artworkUrl:   m['artwork_url'] as String?,
    collectionSlug: m['collection_slug'] as String?,
    platformName:   m['platform_name']   as String?,
    year:           m['year']            as int?,
    isFavorite:   (m['is_favorite']  as int) == 1,
    inLibrary:    (m['in_library']   as int) == 1,
    playCount:    m['play_count']    as int,
    lastPlayedAt: m['last_played_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch((m['last_played_at'] as int) * 1000)
        : null,
  );

  /// Round-trippable snapshot for LOCAL persistence (queue across launches) —
  /// same keys/encodings as [fromMap] expects, paths NORMALISED (the iOS
  /// sandbox UUID changes every launch; fromMap's _denorm restores it).
  /// Needed because a queue's TrackRecords may be synthesized on the fly
  /// (local album/folder rows) and have no row in the tracks table at all.
  Map<String, dynamic> toPersistMap() => {
        'id': id,
        'file_path': LocalDb._norm(filePath),
        'entry_path': LocalDb._norm(entryPath),
        'subsong_idx': subsongIdx,
        'title': title,
        'artist': artist,
        'meta_album': metaAlbum,
        'album_id': albumId,
        'position': position,
        'duration_s': durationS,
        'format_ext': formatExt,
        'subsong_count': subsongCount,
        'source': source,
        'online_id': onlineId,
        'artwork_url': artworkUrl,
        'is_favorite': isFavorite ? 1 : 0,
        'in_library': inLibrary ? 1 : 0,
        'play_count': playCount,
        'last_played_at': lastPlayedAt != null
            ? lastPlayedAt!.millisecondsSinceEpoch ~/ 1000
            : null,
      };
}

// ---------------------------------------------------------------------------
// Listening stats models (aggregations over play_events)
// ---------------------------------------------------------------------------

class StatsOverview {
  final int plays;
  final int tracks;
  final int artists;
  final int albums;
  /// Cumulated listening time. Real elapsed time when recorded
  /// (play_events.played_ms), estimated from the track duration for legacy
  /// rows.
  final int listenedMs;
  const StatsOverview({
    required this.plays,
    required this.tracks,
    required this.artists,
    required this.albums,
    this.listenedMs = 0,
  });
}

/// One aggregated bucket keyed by a plain string — collection slug, format
/// extension or decoder backend.
class KeyStat {
  final String key;
  final int    plays;
  final int    listenedMs;
  const KeyStat(this.key, this.plays, this.listenedMs);
}

/// Library snapshot (period-independent): only what the user explicitly
/// saved — in_library tracks, favorites, saved albums/artists (library_items),
/// local + saved server playlists.
class LibraryOverview {
  final int tracks;       // tracks flagged in_library
  final int favorites;
  final int playlists;    // local playlists + saved server playlists
  final int albums;       // saved albums (library_items)
  final int artists;      // saved artists (library_items)
  const LibraryOverview({
    required this.tracks,
    required this.favorites,
    required this.playlists,
    required this.albums,
    required this.artists,
  });
}

class TrackStat {
  final TrackRecord track;
  final int plays;
  const TrackStat(this.track, this.plays);
}

/// One aggregated artist or album row. [key] is the GROUP BY key — for albums
/// album_id when known else the meta_album name (pass it back to
/// statsTopTracks' albumKey for drill-down); for artists the artist name.
class GroupStat {
  final String  key;
  final String  name;
  final String? artist;
  final String? artworkUrl;
  final int     plays;
  final int     trackCount;
  const GroupStat({
    required this.key,
    required this.name,
    this.artist,
    this.artworkUrl,
    required this.plays,
    required this.trackCount,
  });
}

/// One chart bucket: [label] = 'YYYY-MM-DD' (day) or 'YYYY-MM' (month).
class StatsPoint {
  final String label;
  final int count;
  const StatsPoint(this.label, this.count);
}

// ---------------------------------------------------------------------------
// RecentEntry — unified album+track model for "recently played"
// ---------------------------------------------------------------------------

class RecentEntry {
  final bool     isAlbum;
  /// Track id (for tracks) or meta_album string (for albums).
  final String   key;
  final String   label;
  final String?  artist;
  final String?  metaAlbum;
  /// Server album_id (albums: from recent_albums; tracks: from tracks.album_id;
  /// null for purely local files). Used to rebuild the exact album queue on
  /// replay and to keep the player's "Voir l'album" link working.
  final String?  albumId;
  /// Server online_id (tracks only; null for albums / purely local files).
  /// Must be passed back on replay: the player treats a null onlineId as a
  /// local file and disables the album link no matter what albumId says.
  final String?  onlineId;
  final String   filePath;
  final String   entryPath;
  final int      subsongIdx;
  final String?  artworkUrl;
  /// Origin of the track, as the CATALOGUE knows it (migration 52). The rail's
  /// themed placeholder guessed it from the file extension, which says nothing
  /// on a container (`.lha`, `.zip`) and nothing on an Amiga prefix name
  /// (`mdat.monkey island`). Null for a purely local file.
  final String?  platformName;
  /// Same idea for the format: better than reading the path, which may be an
  /// archive or carry the format BEFORE the dot.
  final String?  formatExt;
  final DateTime lastPlayedAt;
  final bool     isFavorite;
  final bool     inLibrary;

  const RecentEntry({
    required this.isAlbum,
    required this.key,
    required this.label,
    this.artist,
    this.metaAlbum,
    this.albumId,
    this.onlineId,
    required this.filePath,
    required this.entryPath,
    required this.subsongIdx,
    this.artworkUrl,
    this.platformName,
    this.formatExt,
    required this.lastPlayedAt,
    this.isFavorite = false,
    this.inLibrary  = false,
  });

  /// True for user-added local files (not downloaded from the server). Every
  /// server download is saved under `<Documents>/online/…` (RewampDb._localPath),
  /// so a path outside that tree — combined with no online id — is local-only.
  bool get isLocal =>
      onlineId == null &&
      albumId == null &&
      !filePath.contains('${Platform.pathSeparator}online${Platform.pathSeparator}');
}

// ---------------------------------------------------------------------------
// LocalDb — singleton
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// SID info cache model
// ---------------------------------------------------------------------------

class SidSubsongCache {
  final int     idx;       // 1-based
  final int?    lengthMs;
  /// STIL NAME/AUTHOR — le nom et le compositeur du SOUS-CHANT: c'est le titre
  /// et l'artiste de la piste. À ne pas confondre avec les deux suivants.
  final String? stilName;
  final String? stilAuthor;
  /// STIL TITLE/ARTIST — l'ŒUVRE REPRISE et son auteur. Panneau ⓘ seulement.
  final String? stilTitle;
  final String? stilArtist;
  final String? stilComment;

  const SidSubsongCache({
    required this.idx,
    this.lengthMs,
    this.stilName,
    this.stilAuthor,
    this.stilTitle,
    this.stilArtist,
    this.stilComment,
  });

  factory SidSubsongCache.fromMap(Map<String, dynamic> m) => SidSubsongCache(
    idx:        m['subsong_idx'] as int,
    lengthMs:   m['length_ms']   as int?,
    stilName:   m['stil_name']   as String?,
    stilAuthor: m['stil_author'] as String?,
    stilTitle:  m['stil_title']  as String?,
    stilArtist: m['stil_artist'] as String?,
    stilComment:m['stil_comment']as String?,
  );
}

// ---------------------------------------------------------------------------
// SAP info cache model — mirrors SidSubsongCache, no subsong dimension
// (ASMA's STIL.txt has no per-subsong granularity, unlike HVSC's).
// ---------------------------------------------------------------------------

class SapInfoCache {
  final String? stilTitle;
  final String? stilArtist;
  final String? stilComment;

  const SapInfoCache({this.stilTitle, this.stilArtist, this.stilComment});

  factory SapInfoCache.fromMap(Map<String, dynamic> m) => SapInfoCache(
    stilTitle:   m['stil_title']   as String?,
    stilArtist:  m['stil_artist']  as String?,
    stilComment: m['stil_comment'] as String?,
  );
}

// ---------------------------------------------------------------------------
// LibraryItem — entry in the user's library (track / album / artist)
// ---------------------------------------------------------------------------

class LibraryItem {
  final String  id;
  final String  type;      // 'track', 'album', 'artist'
  final String  refId;     // online_id for tracks, album name, artist name
  final String  name;
  final String? artist;
  final String? album;
  final String? artworkUrl;
  final String? formatExt;
  final String? collectionSlug;
  final String? platformName;
  /// Actual file name (e.g. "Commando.sid") — used to reconstruct localPath.
  final String? filename;
  /// Direct download URL for the track file (null for archive-based tracks).
  final String? downloadUrl;
  /// Server album id (albums only) — needed to expand joshw/jw_spc albums whose
  /// tracks live in a JSONB blob (get_album_tracks); without it a library replay
  /// falls back to browse-by-name and collapses to the single album-level row.
  final String? albumId;
  /// Folder this saved server playlist lives in (null = root). Playlists only.
  final String? folderId;
  /// Epoch seconds of the last folder decision (see UserPlaylist).
  final int folderChangedAt;
  /// Epoch seconds of the last favourite decision — arbitrates the shared
  /// client-state key across devices.
  final int favChangedAt;
  final DateTime addedAt;
  final bool    isFavorite;
  /// When this item was marked as favourite (null = not favourite or pre-v8).
  final DateTime? favoritedAt;

  /// Titre de la PISTE, lu sur la ligne `tracks` (voir getLibraryItems) —
  /// null quand cet appareil n'a pas la ligne, ou pour un album/artiste.
  /// [name] ne suffit pas: c'est le nom du fichier au moment du geste, donc
  /// celui de l'ALBUM dès que le fichier est un conteneur.
  final String? trackTitle;

  const LibraryItem({
    required this.id,
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
    this.downloadUrl,
    this.albumId,
    this.folderId,
    this.folderChangedAt = 0,
    this.favChangedAt = 0,
    this.trackTitle,
    required this.addedAt,
    this.isFavorite = false,
    this.favoritedAt,
  });

  /// True for user-added local items (never downloaded from the server).
  /// Tracks: the library key is '<filePath>?subsong=N' when there is no online
  /// id — a path-like ref_id means local. Albums/artists: local ones have no
  /// server album UUID, no collection, and no download URL.
  bool get isLocal => type == 'track'
      // …but a path under the app's `online/` tree is a SERVER download that
      // simply has no catalogue id to key on (every track of a jw_spc-style
      // album but its container). It was showing the phone badge on tunes that
      // came straight from the catalogue. Same test as RecentEntry.isLocal.
      ? ((refId.startsWith('/') || refId.contains(':\\')) &&
          !refId.contains('${Platform.pathSeparator}online${Platform.pathSeparator}'))
      : type == 'playlist'
          // A library_items playlist is ALWAYS a saved SERVER playlist (local
          // user playlists live in the `playlists` table, never here) — so it
          // is never "local", despite having no albumId/collection/downloadUrl.
          ? false
          : type == 'artist'
              // An artist saved under its catalogue UUID is a SERVER artist by
              // definition, whatever else the row lacks (an artist screen
              // opened from a chip carries no collection, and the generic test
              // below then put the phone badge on a catalogue artist). The
              // name-keyed legacy form falls through to the generic test.
              ? !_kUuidRe.hasMatch(refId) && collectionSlug == null
              : (albumId == null &&
                  collectionSlug == null &&
                  downloadUrl == null);

  static final _kUuidRe = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  /// A saved server playlist stashes its entry count in the `format_ext`
  /// column (otherwise unused for a playlist) so the list can show it with no
  /// network round-trip. Null when unknown (playlists saved before this).
  int? get playlistCount =>
      type == 'playlist' ? int.tryParse(formatExt ?? '') : null;

  factory LibraryItem.fromMap(Map<String, dynamic> m) => LibraryItem(
    id:             m['id']              as String,
    type:           m['type']            as String,
    refId:          m['ref_id']          as String,
    name:           m['name']            as String,
    // Repli sur l'artiste retrouvé dans `tracks` (albums — voir
    // getLibraryItems): l'entrée elle-même ne le porte pas toujours.
    artist:         (m['artist'] as String?) ??
                        (m['resolved_artist'] as String?),
    album:          (m['album'] as String?) ??
                        (m['resolved_album'] as String?),
    artworkUrl:     m['artwork_url']     as String?,
    formatExt:      m['format_ext']      as String?,
    collectionSlug: m['collection_slug'] as String?,
    platformName:   m['platform_name']   as String?,
    filename:       m['filename']        as String?,
    downloadUrl:    m['download_url']    as String?,
    albumId:        m['album_id']        as String?,
    folderId:       m['folder_id']       as String?,
    folderChangedAt: (m['folder_changed_at'] as int?) ?? 0,
    favChangedAt:   (m['fav_changed_at'] as int?) ?? 0,
    addedAt:        DateTime.fromMillisecondsSinceEpoch((m['added_at'] as int) * 1000),
    isFavorite:     (m['is_favorite'] as int? ?? 0) == 1,
    favoritedAt:    m['favorited_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch((m['favorited_at'] as int) * 1000)
        : null,
    trackTitle:     m['track_title'] as String?,
  );
}

// ---------------------------------------------------------------------------
// UserPlaylist — a named user-created playlist
// ---------------------------------------------------------------------------

class UserPlaylist {
  final String  id;
  final String  name;
  final String? description;
  /// Parent folder (playlist_folders.id), null = racine.
  final String? folderId;
  /// Number of tracks (filled by getPlaylists' JOIN; 0 otherwise).
  final int     trackCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// Account copy of this playlist (`playlists.id` server-side), null = never
  /// pushed. See PlaylistSync.
  final String? serverId;
  final DateTime? syncedAt;
  /// Exact server version (`updated_at` verbatim) — the value sent back as an
  /// optimistic-concurrency precondition. [syncedAt] is its second-truncated
  /// twin, only good for "has it moved?".
  final DateTime? serverVersion;
  /// Local `updated_at` at the last successful push — a playlist whose
  /// updated_at has not moved since needs no re-upload.
  final int pushedAt;
  /// 'append' when every local change since the last push was an addition at
  /// the END (the push can then send only the tail), 'full' otherwise.
  final String? dirtyKind;
  /// Number of entries the account copy holds — where the tail starts.
  final int pushedCount;
  /// Epoch seconds of the last folder decision made for this playlist — which
  /// side wins when two devices merge the shared organisation key.
  final int folderChangedAt;

  const UserPlaylist({
    required this.id,
    required this.name,
    this.description,
    this.folderId,
    this.trackCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.serverId,
    this.syncedAt,
    this.serverVersion,
    this.pushedAt = 0,
    this.dirtyKind,
    this.pushedCount = 0,
    this.folderChangedAt = 0,
  });

  bool get isSynced => serverId != null && serverId!.isNotEmpty;

  factory UserPlaylist.fromMap(Map<String, dynamic> m) => UserPlaylist(
    id:          m['id']          as String,
    name:        m['name']        as String,
    description: m['description'] as String?,
    folderId:    m['folder_id']   as String?,
    trackCount:  (m['track_count'] as int?) ?? 0,
    createdAt:   DateTime.fromMillisecondsSinceEpoch((m['created_at'] as int) * 1000),
    updatedAt:   DateTime.fromMillisecondsSinceEpoch((m['updated_at'] as int) * 1000),
    serverId:    m['server_id']   as String?,
    serverVersion: DateTime.tryParse(m['server_version'] as String? ?? ''),
    pushedAt:    (m['pushed_at'] as int?) ?? 0,
    dirtyKind:   m['dirty_kind'] as String?,
    pushedCount: (m['pushed_count'] as int?) ?? 0,
    folderChangedAt: (m['folder_changed_at'] as int?) ?? 0,
    syncedAt:    (m['synced_at'] as int?) == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch((m['synced_at'] as int) * 1000),
  );
}

/// One entry of a local playlist — a reference that survives its file.
///
/// [track] is the resolved local row when the file is here right now; it is
/// null when the tune is unavailable (download deleted, folder moved, file not
/// copied to this device yet). Such an entry is NEVER removed on its own: it
/// shows as missing, is skipped by "play all", and rebinds by itself as soon as
/// the file reappears. [songId] non-null means the catalogue can supply it
/// again, so a missing entry is offerable as a download.
class PlaylistEntry {
  /// playlist_tracks.id — the identity of the entry (a track may appear more
  /// than once in a playlist, so the track id does NOT identify a row).
  final int rowId;
  final TrackRecord? track;
  final String? songId;
  /// Server album id of the entry — travels with the snapshot (locally and in
  /// the account's ext_ref) because nothing else carries it: a container's song
  /// id says nothing about its album.
  final String? albumId;
  final String? filePath;
  final String? relPath;
  final String entryPath;
  final int subsongIdx;
  final String? title;
  final String? artist;
  final String? album;
  final String? formatExt;
  final double? durationS;

  const PlaylistEntry({
    required this.rowId,
    this.track,
    this.songId,
    this.albumId,
    this.filePath,
    this.relPath,
    this.entryPath = '',
    this.subsongIdx = 0,
    this.title,
    this.artist,
    this.album,
    this.formatExt,
    this.durationS,
  });

  bool get isMissing => track == null;

  PlaylistEntry withTrack(TrackRecord t) => PlaylistEntry(
        rowId:      rowId,
        track:      t,
        songId:     songId,
        albumId:    albumId ?? t.albumId,
        filePath:   t.filePath,
        relPath:    relPath,
        entryPath:  entryPath,
        subsongIdx: subsongIdx,
        title:      title,
        artist:     artist,
        album:      album,
        formatExt:  formatExt,
        durationS:  durationS,
      );

  /// Best label available whether the file is here or not.
  String get displayTitle =>
      track?.title ??
      title ??
      (filePath != null ? p.basename(filePath!) : '?');

  String? get displayArtist => track?.artist ?? artist;

  /// A missing entry the catalogue can re-supply (vs a local-only file the user
  /// has to bring back themselves).
  bool get isRestorable => isMissing && (songId != null && songId!.isNotEmpty);
}

/// Folder in the playlist tree (nestable via parentId).
class PlaylistFolder {
  final String  id;
  final String  name;
  final String? parentId;
  final DateTime createdAt;

  const PlaylistFolder({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
  });

  factory PlaylistFolder.fromMap(Map<String, dynamic> m) => PlaylistFolder(
    id:        m['id']        as String,
    name:      m['name']      as String,
    parentId:  m['parent_id'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch((m['created_at'] as int) * 1000),
  );
}

// ---------------------------------------------------------------------------
// LocalDb — singleton
// ---------------------------------------------------------------------------

class LocalDb extends ChangeNotifier {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;
  Database get _database => _db!;

  // iOS sandbox root changes UUID on every launch. Store paths with a
  // {sandbox} token so they survive restarts.
  static String? _sandboxRoot;

  static void setSandboxRoot(String root) => _sandboxRoot = root;

  static String _norm(String path) {
    final r = _sandboxRoot;
    if (r != null && path.startsWith(r)) {
      return '{sandbox}${path.substring(r.length)}';
    }
    return path;
  }

  static String _denorm(String path) {
    final r = _sandboxRoot;
    if (r != null && path.startsWith('{sandbox}')) {
      return r + path.substring(9);
    }
    return path;
  }

  // ── Initialization ─────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    try {
      await instance._open();
      debugPrint('LocalDb: opened successfully');
    } catch (e, st) {
      debugPrint('LocalDb initialize ERROR: $e');
      debugPrint(st.toString());
    }
  }

  /// Absolute path of the SQLite file (backup/restore).
  static Future<String> databaseFilePath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'rewamp_local.db');
  }

  /// Snapshots the live database into [destPath] via SQLite's online backup
  /// (VACUUM INTO — safe while the app keeps using the connection). The result
  /// is a defragmented, self-consistent copy. Used by the backup export.
  Future<void> vacuumInto(String destPath) async {
    await _open();
    final esc = destPath.replaceAll("'", "''");
    await _database.execute("VACUUM INTO '$esc'");
  }

  /// Replaces the live database file with [srcDbPath] (a restored backup),
  /// reopens it (running any pending migrations if the backup's schema is
  /// older), and notifies listeners so every screen reloads. Destructive:
  /// the caller must confirm first.
  Future<void> replaceDatabaseFromFile(String srcDbPath) async {
    await _db?.close();
    _db = null;
    final dst = await databaseFilePath();
    // Remove sqflite side-car files so no stale WAL/SHM survives the swap.
    for (final ext in ['', '-wal', '-shm', '-journal']) {
      final f = File('$dst$ext');
      if (await f.exists()) await f.delete();
    }
    await File(srcDbPath).copy(dst);
    await _open();
    notifyListeners();
  }

  Future<void> _open() async {
    if (_db != null) return;

    // databaseFactory is set to databaseFactoryFfi in main() for desktop,
    // before WidgetsFlutterBinding.ensureInitialized(), so openDatabase()
    // here already uses the correct factory for every platform.
    final dir  = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'rewamp_local.db');

    _db = await openDatabase(
      path,
      version: 60,
      onCreate:  _onCreate,
      onUpgrade: _onUpgrade,
      // PRAGMAs must be re-applied on every connection, not just at creation.
      // journal_mode=WAL returns a result row → rawQuery, not execute (iOS
      // sqflite throws Code=0 "not an error" when execute() sees result rows).
      onOpen: (db) async {
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 60) {
      // STIL a QUATRE champs de nommage et deux usages opposés: NAME/AUTHOR
      // nomment le SOUS-CHANT (titre et artiste de la piste), TITLE/ARTIST
      // nomment l'ŒUVRE REPRISE. Le serveur ne remontait que les seconds
      // (migration serveur 237 ajoute les premiers) et on les affichait comme
      // titre — la piste 1 de « One Man and His Droid », qui s'appelle « Space
      // Game », sortait « Magnetic Fields, Part 1 » de Jean-Michel Jarre.
      //
      // ⚠️ Le cache est VIDÉ, pas seulement élargi: ses lignes portent les
      // anciens champs et rien ne les distingue des nouvelles, donc un cache
      // conservé continuerait de servir l'œuvre citée comme titre — sans
      // jamais rappeler le serveur, puisqu'une entrée présente ne se
      // re-télécharge pas. Le coût est un aller-retour par fichier SID joué.
      for (final c in ['stil_name', 'stil_author']) {
        try {
          await db.execute('ALTER TABLE sid_info ADD COLUMN $c TEXT');
        } catch (_) {/* déjà là: base créée par _onCreate */}
      }
      await db.delete('sid_info');
    }
    if (oldVersion < 59) {
      // `subsong_count` décrit le FICHIER de la ligne — or les deux dépliages
      // (subsongRowsFromServer, expandContainerAlbum) écrivaient subs.length
      // sur CHAQUE ligne, y compris les membres d'un album multi-fichiers:
      // un .psf extrait de jw_psf portait « 53 sous-chansons ». Personne ne
      // s'en servait là, et l'écran des stats y lisait « multi-sous-chansons »
      // et ouvrait une liste pour un fichier d'une seule.
      //
      // Critère, chaque clause pour un cas réel (vérifié sur sqlite3):
      //  * `online_id LIKE '%#%'` — née d'un dépliage;
      //  * `subsong_idx = 0` — protège les sous-chansons d'index > 0;
      //  * pas de SŒUR sur le même fichier avec un autre index — un conteneur
      //    déplié a plusieurs lignes sur UN fichier, un membre a le sien.
      // Cas limite assumé: un conteneur dont seule la 1re sous-chanson a été
      // jouée est remis à null — la sonde moteur le remplit au play suivant
      // (et UADE passe par le songdb, pas par cette colonne).
      await db.rawUpdate('''
        UPDATE tracks SET subsong_count = NULL
         WHERE online_id LIKE '%#%'
           AND subsong_idx = 0
           AND subsong_count > 1
           AND NOT EXISTS (SELECT 1 FROM tracks u
                            WHERE u.file_path = tracks.file_path
                              AND u.subsong_idx <> tracks.subsong_idx)
      ''');
    }
    if (oldVersion < 58) {
      // La mig 55 rejouée, plus l'ANNÉE, plus les origines simplement absentes.
      //
      // Trois choses restaient. (1) Quatre appels à `setAlbumContext` ne
      // passaient pas `forPath`, donc la course que la mig 55 avait réparée
      // pouvait re-salir des lignes après elle — un module Amiga de modland
      // estampillé « jw_psf », avec l'année du morceau d'à côté. (2) La mig 55
      // ne touchait pas `year`, qui vient pourtant de la MÊME écriture fautive.
      // (3) `_mintTrackRow` (synchro du compte) et trois autres écritures
      // jetaient l'origine qu'elles avaient en main, laissant des lignes avec
      // un `online_id` et une collection NULLE — que le rattrapage par chemin
      // de la mig 52 ne pouvait plus réparer, n'ayant tourné qu'une fois.
      //
      // Le CHEMIN tranche, comme en 55: `…/online/<collection>/…` dit où les
      // octets SONT. Quand la collection stockée le contredit, plateforme ET
      // année repartent à NULL — elles viennent de la même écriture; la lecture
      // suivante les réécrira depuis une source sûre.
      const pathCol = "substr(file_path, instr(file_path, '/online/') + 8, "
          "instr(substr(file_path, instr(file_path, '/online/') + 8), '/') - 1)";
      await db.rawUpdate(
        'UPDATE tracks SET collection_slug = $pathCol, '
        '                  platform_name = NULL, year = NULL '
        " WHERE instr(file_path, '/online/') > 0 "
        '   AND collection_slug IS NOT NULL '
        '   AND collection_slug <> $pathCol',
      );
      await db.rawUpdate(
        'UPDATE tracks SET collection_slug = $pathCol '
        " WHERE instr(file_path, '/online/') > 0 "
        '   AND collection_slug IS NULL',
      );
    }
    if (oldVersion < 57) {
      // Séquelles du pick GÉNÉRIQUE sur une ligne CONTENEUR: après un
      // exact-miss, l'extraction servait « le plus gros fichier d'allure
      // audio » et l'écrivait dans `tracks` — « 124 Nostalgia.spc » enregistré
      // sous le titre « Harvest » — puis l'entrée de playlist née de cette
      // lecture pointait dessus. La playlist jouait le mauvais morceau, sans
      // une erreur. Le repli échoue franc depuis, mais les lignes déjà
      // écrites restent.
      //
      // L'artefact se reconnaît SANS ambiguïté: son `online_id` est l'uuid NU
      // du conteneur (qui ne désigne aucun fichier — chaque piste réelle est
      // une ligne `<uuid>#<i>`), son `subsong_idx` est 0, et une ligne sœur
      // `<uuid>#<i>` porte le MÊME titre sur un AUTRE fichier. On exige que
      // cette sœur soit UNIQUE: deux candidates voudraient dire que le titre
      // ne suffit pas à trancher, et on ne devine pas — c'est justement la
      // faute qu'on répare.
      final pairs = await db.rawQuery('''
        SELECT t.id AS bad_id, s.id AS good_id, s.online_id AS good_online,
               s.file_path AS good_path, s.subsong_idx AS good_sub
          FROM tracks t
          JOIN tracks s
            ON s.online_id LIKE t.online_id || '#%'
           AND s.title = t.title
           AND s.file_path <> t.file_path
         WHERE t.online_id NOT LIKE '%#%'
           AND t.subsong_idx = 0
           AND t.title IS NOT NULL
           AND (SELECT COUNT(*) FROM tracks s2
                 WHERE s2.online_id LIKE t.online_id || '#%'
                   AND s2.title = t.title
                   AND s2.file_path <> t.file_path) = 1
      ''');
      for (final r in pairs) {
        final badId = r['bad_id'] as String;
        // Les entrées de playlist qui pointaient sur l'artefact suivent la
        // bonne ligne: identité, index de sous-chanson ET chemins, sinon la
        // prochaine résolution retomberait sur le mauvais fichier par le
        // chemin stocké.
        await db.rawUpdate(
          'UPDATE playlist_tracks SET track_id = ?, song_id = ?, '
          'subsong_idx = ?, file_path = ?, rel_path = NULL '
          ' WHERE track_id = ?',
          [
            r['good_id'],
            r['good_online'],
            r['good_sub'],
            r['good_path'],
            badId,
          ],
        );
        await db.rawDelete('DELETE FROM tracks WHERE id = ?', [badId]);
      }
      if (pairs.isNotEmpty) {
        debugPrint('LocalDb mig57: ${pairs.length} ligne(s) fabriquée(s) par '
            'un pick générique remplacée(s) par le vrai fichier');
      }
    }
    if (oldVersion < 56) {
      // Marqueurs « album matérialisé » MENTEURS: `materializeAlbumTracks`
      // avalait chaque échec de ligne (`catch (_)`) puis posait le marqueur
      // quoi qu'il arrive. Un lot entièrement raté laissait donc l'album marqué
      // « liste complète reçue » avec ZÉRO ligne `tracks` — et le rattrapage
      // (`SyncService._healAlbumFavourites`), qui ne juge que sur ce marqueur,
      // ne le regardait plus jamais: ♥ visible dans la Bibliothèque (qui lit
      // `library_items`), absent de la playlist Favoris (qui lit `tracks`),
      // définitivement. Mesuré sur une base réelle: Wild Arms marqueur 86 /
      // 0 ligne, Sunset Riders 25 / 0, Final Fantasy V 67 / 1.
      //
      // Le marqueur n'est qu'un CACHE: le jeter coûte une requête par album
      // favori. Le critère est le COMPTE qu'il porte lui-même — moins de lignes
      // que promis = liste incomplète, quelle qu'en soit la raison (lot raté,
      // téléchargement supprimé depuis). Un album dont la liste est là garde
      // son marqueur, y compris quand l'expansion en a produit PLUS que la
      // tracklist (Chrono Trigger: marqueur 4, 72 lignes).
      await db.rawDelete('''
        DELETE FROM album_materialised
         WHERE track_count > (
           SELECT COUNT(*) FROM tracks t
            WHERE t.album_id = album_materialised.album_id)
      ''');
    }
    if (oldVersion < 55) {
      // Origines POLLUÉES par une course: la recherche d'origine d'un album se
      // fait en base, donc de façon asynchrone, et sa réponse était écrite sur
      // le morceau COURANT — pas sur celui qui l'avait demandée. Enchaîner
      // Commando (hvsc/c64) puis un module Amiga de modland estampillait donc
      // « hvsc / c64 » sur ce dernier: mauvais placeholder, et la valeur
      // restait (l'écriture d'origine est en COALESCE). La course est fermée
      // côté lecteur; ceci répare ce qui est déjà écrit.
      //
      // Le CHEMIN tranche: `…/online/<collection>/…` dit où les octets sont.
      // Quand la collection stockée le contredit, les deux champs viennent de
      // la même écriture fautive — la collection est reprise du chemin et la
      // plateforme REMISE À NULL plutôt que devinée: la lecture suivante la
      // réécrit depuis le chemin, et en attendant le placeholder retombe sur
      // l'extension, qui est juste.
      const pathCol = "substr(file_path, instr(file_path, '/online/') + 8, "
          "instr(substr(file_path, instr(file_path, '/online/') + 8), '/') - 1)";
      await db.rawUpdate(
        'UPDATE tracks SET collection_slug = $pathCol, platform_name = NULL '
        " WHERE instr(file_path, '/online/') > 0 "
        '   AND collection_slug IS NOT NULL '
        '   AND collection_slug <> $pathCol',
      );
    }
    if (oldVersion < 54) {
      // La mig 53 rejouée telle quelle. Elle avait nettoyé les doublons « même
      // identité catalogue, deux chemins » laissés par le repli sur l'album de
      // la QUEUE — puis une NOUVELLE source du même dégât est apparue: la
      // récupération d'un fichier absent télécharge sous le crédit d'artiste
      // que rend le catalogue (« Amusic & Leviathan »), quand la ligne d'origine
      // avait été rangée sous un autre (« Amusic »). Un morceau SANS album n'a
      // pas d'uuid dans son chemin, c'est la chaîne artiste qui le fait — deux
      // flux en désaccord sur le crédit font deux chemins, deux lignes, deux
      // cartes dans « écoutés récemment ». La prévention en continu vit
      // désormais dans pruneMissingDuplicates (appelée à chaque lecture
      // aboutie); ce passage efface ce qui existe déjà.
      await _dedupeMissingSiblings(db);
    }
    if (oldVersion < 53) {
      // Nettoyage: le MÊME morceau du catalogue rangé sous DEUX chemins.
      //
      // La reconstruction d'une ligne dont le fichier manquait empruntait
      // l'album de la QUEUE pour dériver le chemin de téléchargement — un
      // `.s3m` de modland s'est ainsi retrouvé sous l'uuid d'un album jw_gbs.
      // Deux entrées dans « écoutés récemment », dont une injouable
      // (« MISSING ON DISK »). La source est corrigée; ici on efface ce qu'elle
      // a laissé.
      //
      // Critère: même identité catalogue (online_id + sous-chanson), et le
      // fichier de CETTE ligne n'existe pas alors qu'une sœur en a un. Le test
      // du disque ne se fait pas en SQL, donc la boucle est en Dart — comme la
      // mig 49, pour la même raison.
      // Clé CONCATÉNÉE plutôt qu'un row-value `(a,b) IN (…)`: la syntaxe
      // n'existe qu'à partir de SQLite 3.15, et le SQLite du SYSTÈME sur un
      // Android API 26 (notre plancher) est plus ancien.
      await _dedupeMissingSiblings(db);
    }
    if (oldVersion < 52) {
      // Collection + plateforme SUR LA PISTE.
      //
      // `tracks` était un JOURNAL DE LECTURE (ce qu'on a joué, quand, combien
      // de fois): les colonnes d'identité s'y sont ajoutées une par une, au fil
      // des bugs, et celles-ci n'y sont jamais entrées — elles ne vivaient que
      // dans `library_items` (posé par un GESTE) et dans le miroir du compte.
      // Résultat, une relance devait re-DEVINER l'origine à partir du chemin ou
      // des lignes voisines. On la stocke désormais quand on la connaît.
      for (final col in ['collection_slug', 'platform_name', 'year']) {
        final cols = await db.rawQuery('PRAGMA table_info(tracks)');
        if (!cols.any((c) => c['name'] == col)) {
          await db.execute('ALTER TABLE tracks ADD COLUMN $col '
              '${col == 'year' ? 'INTEGER' : 'TEXT'}');
        }
      }
      // Rattrapage sans réseau: le chemin des téléchargements PORTE la
      // collection (`online/<collection>/…`). Ce que le disque affirme est plus
      // sûr qu'une déduction, et ça couvre tout l'historique d'un coup.
      await db.execute('''
        UPDATE tracks SET collection_slug =
          substr(file_path,
                 instr(file_path, '/online/') + 8,
                 instr(substr(file_path, instr(file_path, '/online/') + 8), '/') - 1)
         WHERE collection_slug IS NULL
           AND instr(file_path, '/online/') > 0
      ''');
    }
    if (oldVersion < 51) {
      // Identité CATALOGUE du fichier que l'entrée récents pointe.
      //
      // Un `online_id` désigne un FICHIER du catalogue, pas une sous-chanson:
      // les 16 sous-chansons d'un `.gbs` joshw partagent le même. La moitié
      // « album » de getRecentEntries produisait `NULL AS online_id_col` — pas
      // un choix, une absence de colonne — donc rejouer un album depuis les
      // récents fabriquait des lignes SANS identité, et le lecteur affichait
      // « local » au lieu de la collection (il traite `currentOnlineId == null`
      // comme un verdict sur la provenance).
      final cols = await db.rawQuery('PRAGMA table_info(recent_albums)');
      if (!cols.any((c) => c['name'] == 'online_id')) {
        await db.execute('ALTER TABLE recent_albums ADD COLUMN online_id TEXT');
      }
      // Rattrapage depuis ce que la base sait déjà de ce CHEMIN.
      //
      // On compare la partie AVANT le `#`: un conteneur expansé donne
      // `<uuid>#<rang>` par sous-chanson, et le rang n'est PAS l'index de
      // sous-chanson (mesuré sur un `.gbs` joshw: subsong 12 → `#13`). Seul
      // l'uuid identifie le fichier; le suffixe ne s'invente pas. Et l'id
      // n'est retenu que si toutes les lignes du fichier s'accordent dessus.
      await db.execute('''
        UPDATE recent_albums SET online_id = (
          SELECT MIN(CASE WHEN instr(t.online_id, '#') > 0
                          THEN substr(t.online_id, 1, instr(t.online_id, '#') - 1)
                          ELSE t.online_id END)
            FROM tracks t
           WHERE t.file_path = recent_albums.file_path
             AND t.online_id IS NOT NULL
          HAVING COUNT(DISTINCT CASE WHEN instr(t.online_id, '#') > 0
                          THEN substr(t.online_id, 1, instr(t.online_id, '#') - 1)
                          ELSE t.online_id END) = 1
        ) WHERE online_id IS NULL
      ''');
    }
    if (oldVersion < 50) {
      // Playlists de presets projectM (v1 locale, pas de synchro serveur) +
      // cache chemin→preset_id du catalogue. `path` est RELATIF à
      // <datadir>/projectm/ : le conteneur iOS change d'UUID à chaque mise à
      // jour de l'app, un chemin absolu casserait — même leçon que le _norm
      // des tracks.
      await db.execute('''CREATE TABLE IF NOT EXISTS pm_playlists (
        id         TEXT    PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
        name       TEXT    NOT NULL,
        server_id  TEXT,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0
      )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS pm_playlist_items (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id TEXT    NOT NULL REFERENCES pm_playlists(id) ON DELETE CASCADE,
        position    INTEGER NOT NULL,
        path        TEXT    NOT NULL,
        preset_id   TEXT,
        name        TEXT
      )''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_pm_playlist_items_order '
          'ON pm_playlist_items (playlist_id, position)');
      await db.execute('''CREATE TABLE IF NOT EXISTS pm_preset_ids (
        path       TEXT PRIMARY KEY,
        preset_id  TEXT NOT NULL
      )''');
    }
    if (oldVersion < 49) {
      // Réparation: des lignes FANTÔMES fabriquées par la synchro pour les
      // sous-chansons d'un album conteneur. Le catalogue ne connaît que le
      // conteneur, donc chacune portait l'uuid NU, le chemin de l'archive et
      // le titre de l'ALBUM — à côté de la vraie ligne, qui porte `<uuid>#<i>`.
      // La bibliothèque tombait sur le fantôme, le trouvait absent du disque et
      // relançait le téléchargement de l'album entier.
      //
      // Critère strict: uuid nu + sous-chanson > 0 + une vraie ligne existe
      // pour cette sous-chanson sous la forme conteneur. Une piste légitime
      // d'un fichier multi-sous-chansons (un `.sid`, un `.nsf`) n'a pas de
      // sœur `#N` et n'est donc pas touchée.
      //
      // ⚠️ Et le FICHIER doit être absent. Le seul critère SQL supprimait aussi
      // une ligne légitime: un `.nsf` d'album jw_nsf posé sur disque, keyé par
      // l'uuid nu avec sa vraie sous-chanson, à côté d'une ligne `#N` née de
      // l'expansion du conteneur. Un fantôme, lui, pointe un chemin qui
      // n'existe pas — c'est ce qui le distingue, et ça ne se teste pas en SQL.
      // Deux marques, et il faut l'UNE ou l'AUTRE (mesuré sur deux bases
      // réelles, aucune des deux ne suffit seule):
      //  * le fichier n'existe pas — c'est le fantôme au chemin de l'archive;
      //  * le fichier n'a pas tant de sous-chansons (`subsong_count` absent ou
      //    ≤ l'index) — c'est le fantôme posé sur le chemin d'une AUTRE piste
      //    de l'album, qui lui existe bel et bien.
      // Ce que ça épargne: la piste légitime d'un vrai fichier multi-sous-
      // chansons (un `.nsf` d'album jw_nsf, 28 sous-chansons, keyé par l'uuid
      // nu), qui a une sœur `#N` née de l'expansion du conteneur et que le
      // seul critère SQL supprimait.
      final suspects = await db.rawQuery('''
        SELECT t.id, t.file_path, t.subsong_idx, t.subsong_count FROM tracks t
         WHERE t.online_id IS NOT NULL
           AND t.online_id NOT LIKE '%#%'
           AND t.subsong_idx > 0
           AND EXISTS (SELECT 1 FROM tracks u
                        WHERE u.online_id = t.online_id || '#' || t.subsong_idx)
      ''');
      final doomed = <String>[];
      for (final r in suspects) {
        final idx   = (r['subsong_idx'] as int?) ?? 0;
        final count = (r['subsong_count'] as int?) ?? 1;
        if (count <= idx) { doomed.add(r['id'] as String); continue; }
        final path = _denorm(r['file_path'] as String);
        try {
          if (!await File(path).exists()) doomed.add(r['id'] as String);
        } catch (_) { doomed.add(r['id'] as String); }
      }
      if (doomed.isNotEmpty) {
        final marks = List.filled(doomed.length, '?').join(',');
        await db.rawDelete('DELETE FROM tracks WHERE id IN ($marks)', doomed);
        debugPrint('LocalDb mig49: ${doomed.length} phantom track row(s) removed');
      }
    }
    if (oldVersion < 48) {
      // Réparation: des morceaux SANS album (`meta_album` nul) portaient
      // l'`album_id` de la queue en cours. L'album est une propriété de la
      // QUEUE, `currentAlbumId` survit à la fin d'une lecture d'album, et le
      // stamp se faisait à chaque play — quatre pistes de modland et de
      // sceneorg rattachées à « Final Fantasy V », donc versées dans ses
      // favoris. La source est corrigée dans `_persistPlay`; ici on efface ce
      // qu'elle a laissé. Un morceau réellement d'un album en porte le NOM.
      await db.execute('UPDATE tracks SET album_id = NULL '
          "WHERE album_id IS NOT NULL AND COALESCE(meta_album, '') = ''");
    }
    if (oldVersion < 47) {
      // « Cet album a reçu sa liste COMPLÈTE. » Sans marqueur, le rattrapage
      // des albums favoris ne pouvait le déduire que de la présence de lignes
      // `tracks` — et une seule suffisait à le croire fini. Un album aimé
      // ailleurs mais simplement ÉCOUTÉ ici (une piste jouée = une ligne)
      // restait donc à une piste pour toujours: 1 contre 37 pour « Wild Arms »
      // entre deux appareils du même compte.
      //
      // Le compte des pistes est gardé pour pouvoir un jour repérer une liste
      // qui a changé côté serveur; rien ne le lit encore.
      await db.execute('''CREATE TABLE IF NOT EXISTS album_materialised (
        album_id    TEXT    PRIMARY KEY,
        track_count INTEGER NOT NULL,
        at          INTEGER NOT NULL
      )''');
    }
    if (oldVersion < 46) {
      // Le MOTEUR de décodage voyage désormais jusqu'au compte (`p_backend`
      // sur log_play, clé `backend` par événement sur log_plays_ext, colonne
      // `backend` sur user_play_history): la carte « Par moteur » de l'écran
      // Stats peut donc fusionner comme le reste. Deux colonnes ici: le
      // miroir la reçoit, l'outbox la transporte.
      //
      // Comme tout bloc de migration, celui-ci se suffit à lui-même (les blocs
      // sont écrits du plus récent au plus ancien, voir la 45).
      await db.execute('''CREATE TABLE IF NOT EXISTS account_play_events (
        kind        TEXT    NOT NULL,
        song_id     TEXT    NOT NULL DEFAULT '',
        subsong_idx INTEGER NOT NULL DEFAULT 0,
        ext_key     TEXT    NOT NULL DEFAULT '',
        played_at   INTEGER NOT NULL,
        played_ms   INTEGER,
        backend     TEXT,
        PRIMARY KEY (song_id, subsong_idx, ext_key, played_at)
      )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS ext_play_outbox (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        ext_key       TEXT    NOT NULL,
        ext_ref       TEXT,
        duration_ms   INTEGER NOT NULL,
        played_at     INTEGER NOT NULL,
        attempts      INTEGER NOT NULL DEFAULT 0,
        play_event_id INTEGER,
        backend       TEXT
      )''');
      for (final t in ['account_play_events', 'ext_play_outbox']) {
        final cols = await db.rawQuery('PRAGMA table_info($t)');
        if (!cols.any((c) => c['name'] == 'backend')) {
          await db.execute('ALTER TABLE $t ADD COLUMN backend TEXT');
        }
      }
    }
    if (oldVersion < 45) {
      // Écoutes FUSIONNÉES entre appareils (écran Stats). Le local seul ne peut
      // pas y répondre: une écoute faite sur un autre appareil n'existe ici
      // qu'au compte, et une piste absente de CET appareil n'a pas de ligne
      // `tracks` à laquelle accrocher un `play_events`.
      //
      //  * account_play_events — miroir de `user_play_history` (mig serveur
      //    221), identité SERVEUR (song_id+subsong / ext_key), sans lien vers
      //    `tracks`: une écoute est un fait, elle ne dépend pas de la présence
      //    du fichier. Clé primaire = l'identité + l'instant, donc un pull qui
      //    rejoue une page (curseur inclusif) n'ajoute rien.
      //  * account_track_meta — de quoi NOMMER une piste absente d'ici
      //    (titre/album/pochette de `user_songs`, snapshot pour l'ext).
      //  * play_events.pushed — 0 = le compte devrait l'avoir et ne l'a pas,
      //    1 = livrée (ou rejouée DEPUIS le compte), 2 = jamais proposée
      //    (sous le seuil de log_play: un morceau sauté). La fusion compte 0
      //    et le miroir, jamais 2. C'est ce qui rend la fusion exacte au lieu
      //    d'approximative:
      //    `log_play` n'envoie pas de played_at (le serveur estampille `now()`,
      //    jusqu'à une longueur de morceau plus tard), donc apparier par le
      //    temps doublerait ou perdrait des écoutes.
      //  * ext_play_outbox.play_event_id — la ligne locale que la livraison du
      //    lot fera passer à pushed=1.
      await db.execute('''CREATE TABLE IF NOT EXISTS account_play_events (
        kind        TEXT    NOT NULL,             -- 'song' | 'ext'
        song_id     TEXT    NOT NULL DEFAULT '',  -- uuid catalogue ('' si ext)
        subsong_idx INTEGER NOT NULL DEFAULT 0,
        ext_key     TEXT    NOT NULL DEFAULT '',  -- '' si catalogue
        played_at   INTEGER NOT NULL,             -- epoch seconds (UTC)
        played_ms   INTEGER,
        PRIMARY KEY (song_id, subsong_idx, ext_key, played_at)
      )''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_account_plays_recency '
          'ON account_play_events (played_at DESC)');
      await db.execute('''CREATE TABLE IF NOT EXISTS account_track_meta (
        song_id     TEXT    NOT NULL DEFAULT '',
        subsong_idx INTEGER NOT NULL DEFAULT 0,
        ext_key     TEXT    NOT NULL DEFAULT '',
        title       TEXT,
        artist      TEXT,
        album       TEXT,
        album_id    TEXT,
        artwork_url TEXT,
        collection  TEXT,
        platform    TEXT,
        format_ext  TEXT,
        duration_s  REAL,
        PRIMARY KEY (song_id, subsong_idx, ext_key)
      )''');
      // PRAGMA-vérifiées: une base neuve les tient déjà de _kSchemaStatements.
      final pe = await db.rawQuery('PRAGMA table_info(play_events)');
      if (!pe.any((c) => c['name'] == 'pushed')) {
        await db.execute(
            'ALTER TABLE play_events ADD COLUMN pushed INTEGER NOT NULL DEFAULT 0');
      }
      // ⚠️ Les blocs de _onUpgrade sont écrits du plus RÉCENT au plus ancien:
      // celui-ci s'exécute AVANT `oldVersion < 44`, qui crée ext_play_outbox.
      // Une base restée en 43 n'a donc pas encore la table, et un ALTER dessus
      // faisait échouer TOUTE l'ouverture de la base — écrans figés sur leur
      // roue, partout, pas seulement dans les stats. Le bloc doit se suffire à
      // lui-même: créer la table dans sa forme d'AUJOURD'HUI (le CREATE de la
      // 44, `IF NOT EXISTS`, devient alors un no-op), puis n'altérer que ce
      // qui existait déjà.
      await db.execute('''CREATE TABLE IF NOT EXISTS ext_play_outbox (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        ext_key       TEXT    NOT NULL,
        ext_ref       TEXT,
        duration_ms   INTEGER NOT NULL,
        played_at     INTEGER NOT NULL,
        attempts      INTEGER NOT NULL DEFAULT 0,
        play_event_id INTEGER
      )''');
      final ob = await db.rawQuery('PRAGMA table_info(ext_play_outbox)');
      if (!ob.any((c) => c['name'] == 'play_event_id')) {
        await db.execute(
            'ALTER TABLE ext_play_outbox ADD COLUMN play_event_id INTEGER');
      }
      // Identité HORS CATALOGUE de la piste (localLibraryKey), posée quand
      // une écoute part au compte. C'est ce qui permet à l'écran Stats de
      // reconnaître, dans la timeline du compte, un fichier local qui est ici:
      // sans elle, les écoutes livrées (identifiées par leur ext_key) et les
      // écoutes restées locales (identifiées par leur chemin) feraient deux
      // lignes pour le même morceau.
      final tk = await db.rawQuery('PRAGMA table_info(tracks)');
      if (!tk.any((c) => c['name'] == 'ext_key')) {
        await db.execute('ALTER TABLE tracks ADD COLUMN ext_key TEXT');
      }
    }
    if (oldVersion < 44) {
      // Outbox des écoutes de fichiers LOCAUX (serveur: log_plays_ext) — une
      // écoute est un fait, pas un geste rejouable: elle part en lot (≤500),
      // idempotente côté serveur (PK user/ext_key/played_at), et survit ici
      // hors-ligne jusqu'à livraison. Les écoutes catalogue passent par
      // log_play (HTTP direct) comme avant.
      await db.execute('''CREATE TABLE IF NOT EXISTS ext_play_outbox (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        ext_key     TEXT    NOT NULL,
        ext_ref     TEXT,
        duration_ms INTEGER NOT NULL,
        played_at   INTEGER NOT NULL,          -- epoch seconds (UTC)
        attempts    INTEGER NOT NULL DEFAULT 0
      )''');
    }
    if (oldVersion < 43) {
      // Migration serveur 206: le ♥ devient une colonne serveur, donc un geste
      // ♥ doit pouvoir voyager dans l'outbox SANS emporter une appartenance
      // (retirer de la bibliothèque efface le ♥ côté serveur — ce n'est pas ce
      // qu'un un-♥ veut dire). NULL = ce geste ne touche pas au ♥.
      //
      // PRAGMA-vérifiée: une migration de réparation tourne sur les deux sortes
      // de base, et une base créée par _kSchemaStatements a déjà la colonne.
      final cols = await db.rawQuery('PRAGMA table_info(sync_outbox)');
      if (!cols.any((c) => c['name'] == 'favourite')) {
        await db.execute('ALTER TABLE sync_outbox ADD COLUMN favourite INTEGER');
      }
    }
    if (oldVersion < 42) {
      // Repair of a one-run regression from migration 41: the favourite-sync
      // path materialised an album's tracklist with the library ref_id where a
      // NAME is expected (`tracks.meta_album`), and that ref_id had just become
      // the UUID. Those rows are invisible to the Favoris playlist, which
      // selects on the name.
      //
      // The UUID is exactly what makes them repairable: it identifies the album
      // row that holds the real name. Anything that does not resolve is left
      // alone rather than guessed at.
      await db.execute('''
        UPDATE tracks SET meta_album = (
          SELECT li.name FROM library_items li
           WHERE li.type = 'album' AND li.ref_id = tracks.meta_album
        )
        WHERE meta_album LIKE '________-____-____-____-____________'
          AND EXISTS (SELECT 1 FROM library_items li
                       WHERE li.type = 'album' AND li.ref_id = tracks.meta_album)
      ''');
    }
    if (oldVersion < 41) {
      // Album library rows move from the display NAME to the server UUID (see
      // albumLibraryRefId). Row by row rather than one UPDATE, because
      // library_items is UNIQUE on (type, ref_id): a row already keyed by that
      // uuid must win, and the name-keyed duplicate go — an UPDATE would abort
      // the whole statement on the first collision.
      final rows = await db.query('library_items',
          columns: ['id', 'ref_id', 'album_id'], where: "type = 'album'");
      final taken = {
        for (final r in rows)
          if ((r['ref_id'] as String?) != null) r['ref_id'] as String,
      };
      for (final r in rows) {
        final id      = r['album_id'] as String?;
        final refId   = r['ref_id'] as String?;
        if (id == null || id.isEmpty || refId == null || refId == id) continue;
        if (taken.contains(id)) {
          // Already a row under the uuid: this one is the homonym-collapsed
          // leftover, and keeping it would show the album twice.
          await db.delete('library_items',
              where: 'id = ?', whereArgs: [r['id']]);
          continue;
        }
        await db.update('library_items', {'ref_id': id},
            where: 'id = ?', whereArgs: [r['id']]);
        taken.add(id);
      }
    }
    if (oldVersion < 40) {
      // Migration 39 purged the title-named phantoms this device had MINTED,
      // but the account still holds their snapshots, so the next pull put them
      // straight back ("03 Kingdom Baron" reappeared the same day). The pull
      // now refuses an extension-less snapshot (SyncService._applyExtFavourite)
      // — this clears the round that landed in between.
      //
      // Same shape as 39, minus the twin requirement (the phantom's title need
      // not match any track this device holds — "Kingdom Baron" against a
      // "Kingdom Trial" on disk), plus the decisive check 39 could not make in
      // SQL: the file is NOT THERE. An extension-less name directly under
      // local/, with no catalogue id and no file behind it, cannot be anything
      // but a title that was mistaken for a file name.
      final rows = await db.rawQuery('''
        SELECT id, file_path, subsong_idx FROM tracks
         WHERE file_path LIKE '%/Documents/local/%'
           AND instr(substr(file_path,
                 instr(file_path, '/Documents/local/') + 17), '/') = 0
           AND instr(substr(file_path,
                 instr(file_path, '/Documents/local/') + 17), '.') = 0
           AND (online_id IS NULL OR online_id = '')
      ''');
      for (final r in rows) {
        final fp = r['file_path'] as String;
        if (File(fp).existsSync()) continue;   // a real file: leave it alone
        await db.delete('library_items',
            where: "type = 'track' AND (ref_id = ? OR ref_id = ?)",
            whereArgs: [fp, '$fp?subsong=${r['subsong_idx']}']);
        await db.delete('tracks', where: 'id = ?', whereArgs: [r['id']]);
      }
    }
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tracks ADD COLUMN artwork_url TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''CREATE TABLE IF NOT EXISTS sid_info (
        md5          TEXT    NOT NULL,
        subsong_idx  INTEGER NOT NULL,
        length_ms    INTEGER,
        stil_title   TEXT,
        stil_artist  TEXT,
        stil_comment TEXT,
        fetched_at   INTEGER NOT NULL,
        PRIMARY KEY (md5, subsong_idx)
      )''');
    }
    if (oldVersion < 4) {
      await db.execute('''CREATE TABLE IF NOT EXISTS recent_albums (
        meta_album     TEXT    PRIMARY KEY,
        artist         TEXT,
        file_path      TEXT    NOT NULL,
        artwork_url    TEXT,
        last_played_at INTEGER NOT NULL
      )''');
    }
    if (oldVersion < 5) {
      await db.execute('''CREATE TABLE IF NOT EXISTS library_items (
        id          TEXT    PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
        type        TEXT    NOT NULL,
        ref_id      TEXT    NOT NULL,
        name        TEXT    NOT NULL,
        artist      TEXT,
        album       TEXT,
        artwork_url TEXT,
        format_ext  TEXT,
        added_at    INTEGER NOT NULL DEFAULT 0,
        UNIQUE (type, ref_id)
      )''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_library_items_type ON library_items (type)');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE library_items ADD COLUMN collection_slug TEXT');
      await db.execute('ALTER TABLE library_items ADD COLUMN platform_name TEXT');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE library_items ADD COLUMN filename TEXT');
      await db.execute('ALTER TABLE library_items ADD COLUMN download_url TEXT');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE library_items ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE library_items ADD COLUMN favorited_at INTEGER');
    }
    if (oldVersion < 9) {
      // recent_albums was keyed by meta_album alone, so two distinct albums with
      // the same name (e.g. "Commando" on HVSC vs ZX-Art) collapsed into one row
      // and replay mixed their tracks. Rebuild with a dedup key that prefers the
      // server album_id and otherwise falls back to "<name>|<album-dir>", so
      // same-named albums in different folders stay separate even without an id.
      await db.execute('ALTER TABLE recent_albums RENAME TO recent_albums_old');
      await db.execute('''CREATE TABLE recent_albums (
        album_key      TEXT    PRIMARY KEY,
        meta_album     TEXT    NOT NULL,
        album_id       TEXT,
        artist         TEXT,
        file_path      TEXT    NOT NULL,
        artwork_url    TEXT,
        last_played_at INTEGER NOT NULL
      )''');
      // Migrate: album_id unknown for old rows → key on meta_album (kept as-is;
      // dir-based separation kicks in on the next play).
      await db.execute('''
        INSERT OR IGNORE INTO recent_albums
          (album_key, meta_album, album_id, artist, file_path, artwork_url, last_played_at)
        SELECT meta_album, meta_album, NULL, artist, file_path, artwork_url, last_played_at
        FROM recent_albums_old
      ''');
      await db.execute('DROP TABLE recent_albums_old');
    }
    if (oldVersion < 10) {
      await db.execute(_kUadeCacheSchema);
    }
    if (oldVersion < 11) {
      // tracks.album_id was declared REFERENCES albums(id) ON DELETE SET
      // NULL, but the local `albums` table is a separate, never-populated
      // concept (nothing ever INSERTs into it) — album_id is meant to hold
      // the server's album UUID directly, same as recent_albums.album_id
      // (no FK there). With foreign_keys=ON, writing a real (non-null)
      // server album_id into tracks.album_id violated that FK on every
      // play, breaking play persistence entirely for any track whose album
      // is known server-side. Rebuild the table without the constraint.
      // SQLite has no DROP CONSTRAINT — recreate + copy is the only way.
      // legacy_alter_table=ON matters here: without it, modern SQLite
      // auto-rewrites OTHER tables' FK text to follow a renamed table, so
      // play_events/playlist_tracks's "REFERENCES tracks(id)" would silently
      // become "REFERENCES tracks_v10(id)" — a table we're about to drop,
      // permanently breaking every future operation on those two tables
      // (this bit a real user: DELETE FROM play_events itself started
      // failing with "no such table: tracks_v10"). See migration 12 for the
      // repair of databases that already went through this broken version.
      await db.execute('PRAGMA foreign_keys = OFF');
      await db.execute('PRAGMA legacy_alter_table = ON');
      await db.execute('ALTER TABLE tracks RENAME TO tracks_v10');
      await db.execute('''CREATE TABLE tracks (
        id               TEXT    PRIMARY KEY,
        album_id         TEXT,
        file_path        TEXT    NOT NULL,
        entry_path       TEXT    NOT NULL DEFAULT '',
        subsong_idx      INTEGER NOT NULL DEFAULT 0,
        title            TEXT,
        artist           TEXT,
        meta_album       TEXT,
        position         INTEGER,
        duration_s       REAL,
        format_ext       TEXT,
        source           TEXT    NOT NULL DEFAULT 'local',
        online_id        TEXT,
        artwork_url      TEXT,
        is_favorite      INTEGER NOT NULL DEFAULT 0,
        in_library       INTEGER NOT NULL DEFAULT 0,
        library_added_at INTEGER,
        play_count       INTEGER NOT NULL DEFAULT 0,
        last_played_at   INTEGER,
        UNIQUE (file_path, entry_path, subsong_idx)
      )''');
      await db.execute('''
        INSERT INTO tracks (id, album_id, file_path, entry_path, subsong_idx,
          title, artist, meta_album, position, duration_s, format_ext,
          source, online_id, artwork_url, is_favorite, in_library,
          library_added_at, play_count, last_played_at)
        SELECT id, album_id, file_path, entry_path, subsong_idx,
          title, artist, meta_album, position, duration_s, format_ext,
          source, online_id, artwork_url, is_favorite, in_library,
          library_added_at, play_count, last_played_at
        FROM tracks_v10
      ''');
      await db.execute('DROP TABLE tracks_v10');
      // Recreate the indexes the old table had (dropped along with it).
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tracks_last_played  ON tracks (last_played_at DESC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tracks_favorites    ON tracks (is_favorite) WHERE is_favorite = 1');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tracks_library      ON tracks (library_added_at DESC) WHERE in_library = 1');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tracks_online_id    ON tracks (online_id) WHERE online_id IS NOT NULL');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tracks_album        ON tracks (album_id) WHERE album_id IS NOT NULL');
      await db.execute('PRAGMA legacy_alter_table = OFF');
      await db.execute('PRAGMA foreign_keys = ON');
    }
    if (oldVersion < 12) {
      // Repairs databases that already went through the broken migration 11
      // (before the legacy_alter_table fix above): play_events and
      // playlist_tracks ended up with "REFERENCES tracks_v10(id)" — a table
      // that migration 11 then dropped — so EVERY operation touching either
      // table failed ("no such table: tracks_v10"), including clearHistory()
      // and resetDatabase() themselves. Only actually broken if oldVersion
      // was exactly 11 (came from the buggy migration), but rebuilding is
      // harmless/idempotent for anyone else, so don't bother branching on it.
      await db.execute('PRAGMA foreign_keys = OFF');
      await db.execute('PRAGMA legacy_alter_table = ON');

      await db.execute('ALTER TABLE play_events RENAME TO play_events_v11');
      await db.execute('''CREATE TABLE play_events (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        track_id   TEXT    NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
        played_at  INTEGER NOT NULL DEFAULT 0
      )''');
      await db.execute('''
        INSERT INTO play_events (id, track_id, played_at)
        SELECT id, track_id, played_at FROM play_events_v11
      ''');
      await db.execute('DROP TABLE play_events_v11');

      await db.execute('ALTER TABLE playlist_tracks RENAME TO playlist_tracks_v11');
      await db.execute('''CREATE TABLE playlist_tracks (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id TEXT    NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
        track_id    TEXT    NOT NULL REFERENCES tracks(id)    ON DELETE CASCADE,
        position    REAL    NOT NULL,
        added_at    INTEGER NOT NULL DEFAULT 0,
        UNIQUE (playlist_id, track_id)
      )''');
      await db.execute('''
        INSERT INTO playlist_tracks (id, playlist_id, track_id, position, added_at)
        SELECT id, playlist_id, track_id, position, added_at FROM playlist_tracks_v11
      ''');
      await db.execute('DROP TABLE playlist_tracks_v11');

      await db.execute('PRAGMA legacy_alter_table = OFF');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_play_events_track   ON play_events (track_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_play_events_recency ON play_events (played_at DESC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_playlist_order      ON playlist_tracks (playlist_id, position)');
      // DROP TABLE also drops triggers defined on it — recreate.
      await db.execute('''CREATE TRIGGER IF NOT EXISTS trg_after_play_insert
      AFTER INSERT ON play_events
      BEGIN
        UPDATE tracks
        SET play_count     = play_count + 1,
            last_played_at = NEW.played_at
        WHERE id = NEW.track_id;

        UPDATE albums
        SET play_count     = play_count + 1,
            last_played_at = CASE
                WHEN last_played_at IS NULL OR NEW.played_at > last_played_at
                THEN NEW.played_at ELSE last_played_at END
        WHERE id = (SELECT album_id FROM tracks WHERE id = NEW.track_id);
      END''');
      await db.execute('PRAGMA foreign_keys = ON');
    }
    if (oldVersion < 13) {
      // SAP metadata cache (get_sap_info, ASMA STIL) — mirrors sid_info but
      // no subsong dimension.
      await db.execute('''CREATE TABLE IF NOT EXISTS sap_info (
        md5          TEXT    PRIMARY KEY,
        stil_title   TEXT,
        stil_artist  TEXT,
        stil_comment TEXT,
        fetched_at   INTEGER NOT NULL
      )''');
    }
    if (oldVersion < 14) {
      // A forced-loop bug persisted libnsfplay's 5-minute default_playtime as
      // the canonical duration for NSF tracks (GetLength() fell back to it for
      // plain NSFs with no embedded length). Null those exact 300 s rows so the
      // next play recomputes a real single-pass length (server/native/m3u).
      await db.execute('''
        UPDATE tracks SET duration_s = NULL
        WHERE lower(format_ext) IN ('nsf', 'nsfe')
          AND duration_s IS NOT NULL
          AND duration_s BETWEEN 299.5 AND 300.5
      ''');
    }
    if (oldVersion < 15) {
      // Collapse duplicate recent_albums rows for the same album that got
      // recorded twice — once keyed by server album_id, once by "name|dir"
      // (see upsertRecentAlbum). Group by (meta_album, directory), keep the
      // most-recent row (preferring one that carries an album_id), drop rest.
      final rows = await db.query('recent_albums',
          columns: ['album_key', 'meta_album', 'album_id', 'file_path', 'last_played_at']);
      final byGroup = <String, List<Map<String, Object?>>>{};
      for (final r in rows) {
        final dir = p.dirname(_norm((r['file_path'] as String?) ?? ''));
        byGroup.putIfAbsent('${r['meta_album']} $dir', () => []).add(r);
      }
      for (final group in byGroup.values) {
        if (group.length < 2) continue;
        group.sort((a, b) {
          final aId = (a['album_id'] as String?) != null ? 1 : 0;
          final bId = (b['album_id'] as String?) != null ? 1 : 0;
          if (aId != bId) return bId - aId;                    // id-keyed first
          return ((b['last_played_at'] as int?) ?? 0)
              .compareTo((a['last_played_at'] as int?) ?? 0);  // newest first
        });
        for (final dupe in group.skip(1)) {
          await db.delete('recent_albums',
              where: 'album_key = ?', whereArgs: [dupe['album_key']]);
        }
      }
    }
    if (oldVersion < 16) {
      // Persist the server album_id for library albums so a replay can expand
      // joshw/jw_spc albums (tracks live in a JSONB blob → need get_album_tracks)
      // instead of falling back to browse-by-name (one album-level row).
      await db.execute('ALTER TABLE library_items ADD COLUMN album_id TEXT');
    }
    if (oldVersion < 17) {
      // Normalize track library keys onto the single canonical convention
      // '<onlineId or filePath>?subsong=<idx>'. Historically three writers used
      // three key shapes (bare online id / suffixed / file path), so the same
      // track could hold two library_items rows and the buttons disagreed.
      // 1. If a bare row has a suffixed '?subsong=0' twin, merge the favourite
      //    flag into the twin…
      await db.execute('''
        UPDATE library_items SET
          is_favorite  = 1,
          favorited_at = COALESCE(favorited_at,
            (SELECT b.favorited_at FROM library_items b
              WHERE b.type='track' AND b.ref_id || '?subsong=0' = library_items.ref_id))
        WHERE type='track' AND ref_id LIKE '%?subsong=0'
          AND EXISTS (SELECT 1 FROM library_items b
                       WHERE b.type='track' AND b.is_favorite = 1
                         AND b.ref_id || '?subsong=0' = library_items.ref_id)
      ''');
      // 2. …then drop the bare duplicate…
      await db.execute('''
        DELETE FROM library_items
        WHERE type='track' AND ref_id NOT LIKE '%?subsong=%'
          AND EXISTS (SELECT 1 FROM library_items s
                       WHERE s.type='track'
                         AND s.ref_id = library_items.ref_id || '?subsong=0')
      ''');
      // 3. …and rewrite the remaining bare keys as subsong 0 (best effort — the
      //    original subsong index was never stored on those rows).
      await db.execute('''
        UPDATE library_items SET ref_id = ref_id || '?subsong=0'
        WHERE type='track' AND ref_id NOT LIKE '%?subsong=%'
      ''');
    }
    if (oldVersion < 18) {
      // Drop the dead `albums` table: it was a "local container album" concept
      // that nothing ever INSERTed into — the stats trigger's UPDATE on it was
      // a permanent no-op and its old FK even broke plays (migration 11).
      // Recreate the trigger without the albums half, then drop the table.
      await db.execute('DROP TRIGGER IF EXISTS trg_after_play_insert');
      await db.execute('''CREATE TRIGGER IF NOT EXISTS trg_after_play_insert
      AFTER INSERT ON play_events
      BEGIN
        UPDATE tracks
        SET play_count     = play_count + 1,
            last_played_at = NEW.played_at
        WHERE id = NEW.track_id;
      END''');
      await db.execute('DROP INDEX IF EXISTS idx_albums_file_path');
      await db.execute('DROP INDEX IF EXISTS idx_albums_last_played');
      await db.execute('DROP TABLE IF EXISTS albums');
    }
    if (oldVersion < 19) {
      // Playlist folders (nestable) + playlist→folder attachment. Plain TEXT
      // references (no FK — cascades handled in code, same style as album_id).
      await db.execute('''CREATE TABLE IF NOT EXISTS playlist_folders (
        id         TEXT    PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
        name       TEXT    NOT NULL,
        parent_id  TEXT,
        created_at INTEGER NOT NULL DEFAULT 0
      )''');
      await db.execute('ALTER TABLE playlists ADD COLUMN folder_id TEXT');
    }
    if (oldVersion < 20) {
      // Allow MULTIPLE instances of the same track in a playlist: recreate
      // playlist_tracks without the UNIQUE(playlist_id, track_id) constraint.
      await db.execute('ALTER TABLE playlist_tracks RENAME TO playlist_tracks_v19');
      await db.execute('''CREATE TABLE playlist_tracks (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id TEXT    NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
        track_id    TEXT    NOT NULL REFERENCES tracks(id)    ON DELETE CASCADE,
        position    REAL    NOT NULL,
        added_at    INTEGER NOT NULL DEFAULT 0
      )''');
      await db.execute('''
        INSERT INTO playlist_tracks (id, playlist_id, track_id, position, added_at)
        SELECT id, playlist_id, track_id, position, added_at FROM playlist_tracks_v19
      ''');
      await db.execute('DROP TABLE playlist_tracks_v19');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_playlist_order ON playlist_tracks (playlist_id, position)');
    }
    if (oldVersion < 21) {
      // Total subsongs of the container FILE, denormalized on every row of the
      // file (server-sourced when known). Lets an OFFLINE recents replay
      // rebuild the right queue — the native probe returns a format default
      // (HES/KSS → 256) for headers that carry no count.
      await db.execute('ALTER TABLE tracks ADD COLUMN subsong_count INTEGER');
    }
    if (oldVersion < 23) {
      // REPAIR (idempotent): _onCreate's embedded _kSchemaStatements — the
      // REAL schema; local_db_schema.sql is documentation and had drifted —
      // was missing the subsong_count column migration 21 adds, so every
      // FRESH install since then had a tracks table without it and every
      // _persistPlay failed ("table tracks has no column named
      // subsong_count"). The embedded schema is fixed now; this block heals
      // the databases those builds created (they sit at v21 or v22 with the
      // column missing — hence the PRAGMA check rather than a blind ALTER,
      // same pattern as migration 12). THREE copies must stay in sync when a
      // migration touches a table: the migration, _kSchemaStatements, and
      // local_db_schema.sql.
      final cols = await db.rawQuery('PRAGMA table_info(tracks)');
      final hasIt = cols.any((c) => c['name'] == 'subsong_count');
      if (!hasIt) {
        await db.execute('ALTER TABLE tracks ADD COLUMN subsong_count INTEGER');
      }
    }
    if (oldVersion < 24) {
      // Track the download_url each online song was fetched from, so a
      // server-side file replacement (same song_id, new url) invalidates the
      // stale local copy. See download_sources in _kSchemaStatements.
      await db.execute('''CREATE TABLE IF NOT EXISTS download_sources (
        online_id   TEXT PRIMARY KEY,
        source_url  TEXT NOT NULL,
        updated_at  INTEGER
      )''');
    }
    if (oldVersion < 25) {
      // Saved SERVER playlists (library_items) can now live in a folder, like
      // local playlists — a nullable folder_id referencing playlist_folders.
      await db.execute('ALTER TABLE library_items ADD COLUMN folder_id TEXT');
    }
    if (oldVersion < 26) {
      // Listening-time + engine stats: real elapsed play time (backfilled at
      // track end/switch; NULL = legacy row, estimated from duration_s) and
      // the C backend that decoded the play (NULL = legacy/unknown).
      await db.execute('ALTER TABLE play_events ADD COLUMN played_ms INTEGER');
      await db.execute('ALTER TABLE play_events ADD COLUMN backend TEXT');
    }
    if (oldVersion < 27) {
      // saved=1 → EXPLICITLY added to the library (LibraryButton / "add to
      // library"); saved=0 → row exists only because it was favorited.
      // Un-favoriting a saved=0 row now DELETES it — favorite-then-unfavorite
      // used to leave a phantom entry in the Library screens forever.
      await db.execute(
          'ALTER TABLE library_items ADD COLUMN saved INTEGER NOT NULL DEFAULT 1');
      // Backfill: a row whose favorited_at equals its added_at was CREATED by
      // the favorite action, not an explicit add. (Already-unfavorited residue
      // has favorited_at NULL and is indistinguishable from an explicit add —
      // left as saved=1; remove those by hand once.)
      await db.execute('''UPDATE library_items SET saved = 0
        WHERE is_favorite = 1 AND favorited_at IS NOT NULL
          AND favorited_at = added_at''');
    }
    if (oldVersion < 28) {
      // A playlist entry becomes SELF-DESCRIBING instead of a bare FK to
      // tracks. Two things were destroying entries silently:
      //   * track_id … ON DELETE CASCADE + foreign_keys=ON → deleting a
      //     download (deleteEntriesUnderPath does DELETE FROM tracks) took
      //     every playlist entry of that file with it;
      //   * getPlaylistEntries INNER JOINed tracks → an entry whose row was
      //     gone vanished from the screen anyway.
      // Now: track_id is nullable and ON DELETE SET NULL (a cached binding to
      // the local row, nothing more), and the descriptive snapshot below is
      // what the entry IS. A file that goes away — deleted, moved, not yet
      // copied to this device — leaves the entry in place, shown as missing
      // and re-bound automatically when the file comes back.
      await db.execute('ALTER TABLE playlist_tracks RENAME TO playlist_tracks_v27');
      await db.execute(_kPlaylistTracksDdl);
      await db.execute('''
        INSERT INTO playlist_tracks
          (id, playlist_id, track_id, position, added_at,
           song_id, file_path, rel_path, entry_path, subsong_idx,
           title, artist, album, format_ext, duration_s)
        SELECT pt.id, pt.playlist_id, pt.track_id, pt.position, pt.added_at,
               t.online_id, t.file_path, NULL, t.entry_path, t.subsong_idx,
               t.title, t.artist, t.meta_album, t.format_ext, t.duration_s
        FROM playlist_tracks_v27 pt
        LEFT JOIN tracks t ON t.id = pt.track_id
      ''');
      await db.execute('DROP TABLE playlist_tracks_v27');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_playlist_order '
          'ON playlist_tracks (playlist_id, position)');
      // rel_path is filled in by getPlaylistEntryRefs the first time an entry
      // is resolved (it needs the app's base directory, which a migration
      // cannot reach).
    }
    if (oldVersion < 29) {
      // Migration 28 revived entries whose tracks row had already vanished
      // under the old CASCADE — the INNER JOIN used to hide them. Those have no
      // snapshot at all (nothing left to copy from), so they would show as
      // nameless "?" rows: drop the ones that carry NO information whatsoever.
      // An entry with a snapshot but no track_id is legitimate (missing file)
      // and is kept.
      await db.execute('''DELETE FROM playlist_tracks
        WHERE track_id IS NULL AND song_id IS NULL
          AND (file_path IS NULL OR file_path = '')
          AND (title IS NULL OR title = '')''');
    }
    if (oldVersion < 30) {
      // Link to the account copy of this playlist (server migration 176 makes
      // it able to hold out-of-catalogue entries too). NULL = never pushed.
      await db.execute('ALTER TABLE playlists ADD COLUMN server_id TEXT');
      await db.execute('ALTER TABLE playlists ADD COLUMN synced_at INTEGER');
    }
    if (oldVersion < 31) {
      // WHEN this device decided the folder of a playlist. The account holds a
      // single shared organisation key, so a merge has to know which side is
      // the more recent AUTHOR — without it, a device that had just received a
      // playlist (folder still null) overwrote the folder another device had
      // set, and every restored playlist landed back at the root.
      await db.execute(
          'ALTER TABLE playlists ADD COLUMN folder_changed_at INTEGER');
      await db.execute(
          'ALTER TABLE library_items ADD COLUMN folder_changed_at INTEGER');
      // Existing assignments predate the sync: date them from the row itself so
      // they still beat a never-organised (NULL → 0) copy.
      await db.execute('UPDATE playlists SET folder_changed_at = updated_at '
          'WHERE folder_id IS NOT NULL');
      await db.execute('UPDATE library_items SET folder_changed_at = added_at '
          'WHERE folder_id IS NOT NULL');
    }
    if (oldVersion < 32) {
      // Outbox of library changes not yet acknowledged by the server. A
      // favourite added or removed offline (or while the server is down) is a
      // USER GESTURE: it must survive until it is actually delivered, which a
      // fire-and-forget POST never guaranteed.
      await db.execute('''CREATE TABLE IF NOT EXISTS sync_outbox (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        kind        TEXT    NOT NULL,          -- 'library'
        item_type   TEXT    NOT NULL,          -- song | album | playlist
        item_id     TEXT    NOT NULL,          -- server uuid ('' for a local file)
        subsong_idx INTEGER NOT NULL DEFAULT 0,
        ext_key     TEXT,                      -- out-of-catalogue identity
        ext_ref     TEXT,                      -- its JSON snapshot
        value       INTEGER NOT NULL,          -- 1 = added, 0 = removed
        -- Migration serveur 206: le ♥ est une COLONNE serveur, plus un blob.
        -- NULL = ce geste ne touche pas au ♥ (c'est une appartenance); 1/0 = le
        -- geste EST un ♥, et alors `value` ne doit pas partir (retirer de la
        -- bibliothèque effacerait le ♥ côté serveur).
        favourite   INTEGER,
        changed_at  INTEGER NOT NULL,
        attempts    INTEGER NOT NULL DEFAULT 0
      )''');
      // One pending change per item: a later gesture on the same item replaces
      // the earlier one instead of queueing a contradictory pair.
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_outbox_item '
          'ON sync_outbox (kind, item_type, item_id, subsong_idx, '
          'COALESCE(ext_key, \'\'))');
    }
    if (oldVersion < 39) {
      // Purge the phantom rows the ext round trip minted. A favourite on a
      // track with no catalogue id travelled as a snapshot whose "file name"
      // was in fact the DISPLAY TITLE, so the pull could not see the file was
      // already here: it created a second track + library row under the
      // computed '<base>/local/<title>' path, and one tune showed up twice —
      // one copy starred with its artwork, one bare and badged "local". Both
      // halves are fixed at the source; this clears what they left behind.
      //
      // Narrow on purpose, and every clause carries its weight: directly under
      // 'local/', no catalogue id, NO EXTENSION (a real file always has one —
      // this one was named after a title), and a TWIN elsewhere with the same
      // subsong whose title or file name matches. Verified against the real
      // database: it takes the one phantom and spares both controls (a genuine
      // local file, and an extension-less name with no twin).
      const phantoms = '''
        SELECT t.id AS id, t.file_path AS fp, t.subsong_idx AS sub FROM tracks t
         WHERE t.file_path LIKE '%/Documents/local/%'
           AND instr(substr(t.file_path,
                 instr(t.file_path, '/Documents/local/') + 17), '/') = 0
           AND (t.online_id IS NULL OR t.online_id = '')
           AND instr(substr(t.file_path,
                 instr(t.file_path, '/Documents/local/') + 17), '.') = 0
           AND EXISTS (SELECT 1 FROM tracks x
                        WHERE x.id <> t.id AND x.subsong_idx = t.subsong_idx
                          AND x.file_path NOT LIKE '%/Documents/local/%'
                          AND (x.title = t.title
                               OR x.file_path LIKE '%/' || t.title || '.%'))
      ''';
      await db.execute('''
        DELETE FROM library_items WHERE type = 'track' AND (
             ref_id IN (SELECT fp FROM ($phantoms))
          OR ref_id IN (SELECT fp || '?subsong=' || sub FROM ($phantoms)))
      ''');
      await db.execute('DELETE FROM tracks WHERE id IN '
          '(SELECT id FROM ($phantoms))');
    }
    if (oldVersion < 38) {
      // The album identity a playlist entry never carried. PRAGMA-checked: a
      // fresh install already has it from _kPlaylistTracksDdl, an upgraded one
      // does not. THREE copies stay in sync — this migration, the DDL constant
      // (which _kSchemaStatements uses) and local_db_schema.sql.
      final cols = await db.rawQuery('PRAGMA table_info(playlist_tracks)');
      if (!cols.any((r) => r['name'] == 'album_id')) {
        await db.execute('ALTER TABLE playlist_tracks ADD COLUMN album_id TEXT');
      }
      // Free repair for every entry still bound to a track row: no network, and
      // it covers exactly the entries the backfill would otherwise re-fetch.
      await db.execute('''
        UPDATE playlist_tracks SET album_id = (
          SELECT t.album_id FROM tracks t WHERE t.id = playlist_tracks.track_id
        ) WHERE album_id IS NULL AND track_id IS NOT NULL
      ''');
    }
    if (oldVersion < 37) {
      // REPAIR (idempotent), the same failure as migration 23 and for the same
      // reason. Migration 26 added play_events.played_ms/backend by ALTER, and
      // local_db_schema.sql was updated — but _kSchemaStatements, the schema
      // _onCreate actually runs, was not. Upgraded databases were fine;
      // every FRESH install got a play_events without the two columns, so the
      // Stats screen threw on open and _persistPlay failed on every single
      // play — listening history was silently lost, not just mis-displayed.
      // PRAGMA-checked rather than a blind ALTER: this runs on both kinds of
      // database. THREE copies must stay in sync when a migration touches a
      // table: the migration, _kSchemaStatements, and local_db_schema.sql.
      final cols = await db.rawQuery('PRAGMA table_info(play_events)');
      bool has(String c) => cols.any((r) => r['name'] == c);
      if (!has('played_ms')) {
        await db.execute('ALTER TABLE play_events ADD COLUMN played_ms INTEGER');
      }
      if (!has('backend')) {
        await db.execute('ALTER TABLE play_events ADD COLUMN backend TEXT');
      }
    }
    if (oldVersion < 36) {
      // What kind of local change is waiting to be pushed, and how many entries
      // the account copy holds. A push is a FULL replacement, so appending one
      // track to a 100-entry playlist re-uploaded all 100; knowing the change
      // was an APPEND lets it go out as add_playlist_items (~150 bytes).
      // 'append' = only additions at the end since the last push; 'full' =
      // anything else (removal, reorder); NULL = nothing pending.
      await db.execute('ALTER TABLE playlists ADD COLUMN dirty_kind TEXT');
      await db.execute('ALTER TABLE playlists ADD COLUMN pushed_count INTEGER');
    }
    if (oldVersion < 35) {
      // WHEN the favourite flag of a library item last changed. The server has
      // a single `in_library` flag and no notion of "favourite", so the heart
      // travels through the client-state space — and a shared key needs a
      // per-item date to merge two devices without one erasing the other.
      await db.execute(
          'ALTER TABLE library_items ADD COLUMN fav_changed_at INTEGER');
      await db.execute('UPDATE library_items SET fav_changed_at = '
          'COALESCE(favorited_at, added_at) WHERE is_favorite = 1');
    }
    if (oldVersion < 34) {
      // EXACT server version of the playlist (ISO-8601 with microseconds).
      // synced_at is stored in whole seconds, which is fine to compare "has it
      // moved?" but WRONG as an optimistic-concurrency precondition: sending a
      // truncated timestamp makes the server see its own row as newer, so every
      // write came back as a conflict (measured: the conflict path retried and
      // conflicted again).
      await db.execute('ALTER TABLE playlists ADD COLUMN server_version TEXT');
    }
    if (oldVersion < 33) {
      // Local `updated_at` at the time of the last successful push. Without it
      // every sync re-uploaded every playlist in full (measured: 100 entries
      // pushed on each run with nothing changed) — and since a push clears the
      // "in sync with version X" marker, it also forced the pull to re-download
      // them right after.
      await db.execute('ALTER TABLE playlists ADD COLUMN pushed_at INTEGER');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // sqflite only supports one statement per execute() call.
    for (final sql in _kSchemaStatements) {
      final s = sql.trim();
      if (s.isEmpty) continue;
      try {
        await db.execute(s);
      } catch (e) {
        debugPrint('LocalDb _onCreate FAILED on:\n$s\nError: $e');
        rethrow;
      }
    }
  }

  // ── Track upsert ──────────────────────────────────────────────────────────

  /// Inserts the track if it doesn't exist yet; updates metadata if it does.
  /// Returns the track's id.
  Future<String> upsertTrack({
    required String filePath,
    String  entryPath  = '',
    int     subsongIdx = 0,
    String? title,
    String? artist,
    String? metaAlbum,
    int?    position,
    double? durationS,
    String? formatExt,
    int?    subsongCount,
    String  source   = 'local',
    String? onlineId,
    String? albumId,
    String? artworkUrl,
    String? collectionSlug,
    String? platformName,
    int?    year,
  }) async {
    // Deterministic ID: generated once at first INSERT, never changes.
    // We resolve the id via SELECT after INSERT OR IGNORE.
    final nfp = _norm(filePath);
    final nep = _norm(entryPath);
    await _database.execute('''
      INSERT OR IGNORE INTO tracks
        (id, file_path, entry_path, subsong_idx,
         title, artist, meta_album, position, duration_s, format_ext,
         subsong_count, source, online_id, album_id, artwork_url,
         collection_slug, platform_name, year)
      VALUES
        (lower(hex(randomblob(16))), ?, ?, ?,
         ?, ?, ?, ?, ?, ?,
         ?, ?, ?, ?, ?,
         ?, ?, ?)
    ''', [
      nfp, nep, subsongIdx,
      title, artist, metaAlbum, position, durationS, formatExt,
      subsongCount, source, onlineId, albumId, artworkUrl,
      collectionSlug, platformName, year,
    ]);

    // Update metadata on every call so renames / tag edits are reflected.
    // subsong_count only ever improves (COALESCE): a later play without the
    // server row must not erase a previously known count.
    //
    // online_id is COALESCE'd for the same reason, and it is not cosmetic:
    // getFavorites() resolves a favourite through
    // "WHERE (online_id = ? OR file_path = ?)" using the id baked into its
    // library_items ref_id. Playing the track from a LOCAL list (the favourites
    // screen plays TrackRecords, so onlineId arrives null) used to overwrite
    // online_id with NULL, the favourite stopped matching, dropped out of its
    // slot and only reappeared lower down via a container/album favourite's
    // expansion — i.e. tapping a favourite visibly moved it to the bottom, and
    // the queue (snapshotted before the reload) no longer lined up with the
    // list on screen.
    await _database.execute('''
      UPDATE tracks
      -- Un titre PLUS PRÉCIS déjà stocké n'est pas écrasé par un titre qui en
      -- est le PRÉFIXE. Une lecture réécrit le titre avec le libellé du chemin
      -- qui l'a lancée, et ces libellés diffèrent pour la MÊME sous-chanson:
      -- le catalogue ne nomme que le FICHIER (« monkey island »), tandis que
      -- l'écran des sous-chansons et la reconstruction de queue numérotent
      -- (« monkey island (6) »). Jouer les cinq premières pistes d'un module
      -- de 21 les renommait donc toutes « monkey island », et une playlist
      -- créée depuis la queue héritait de ce mélange: 5 lignes homonymes puis
      -- 16 numérotées. La règle ne mord QUE sur ce cas — « X » contre
      -- « X (…» — donc un vrai renommage (STIL qui arrive, tag corrigé)
      -- s'applique toujours.
      SET title = CASE
                    WHEN title IS NOT NULL AND ? <> ''
                     -- COLLATE NOCASE: le catalogue et l'écran des
                     -- sous-chansons ne capitalisent pas pareil (« Monkey
                     -- Island » contre « monkey island (7) »), et une
                     -- comparaison sensible à la casse laissait passer
                     -- exactement la dégradation que cette règle existe pour
                     -- bloquer.
                     AND substr(title, 1, length(?) + 2) = ? || ' (' COLLATE NOCASE
                    THEN title ELSE ? END,
          artist = ?, meta_album = ?,
          -- position is COALESCE'd for the same "only ever improves" reason, and
          -- it is what actually made a favourite jump to the bottom of the list:
          -- getFavorites() orders an ALBUM favourite by
          -- "COALESCE(position, 999) ASC, subsong_idx ASC", while the play path
          -- (_persistPlay → upsertTrack) passes no position at all. Playing a
          -- track therefore NULLed its position and sorted it last. A user
          -- playlist orders by playlist_tracks.position — a different table,
          -- never written here — which is why only Favoris was affected.
          position = COALESCE(?, position),
          duration_s = ?, format_ext = ?,
          online_id = COALESCE(?, online_id),
          subsong_count = COALESCE(?, subsong_count),
          artwork_url = COALESCE(?, artwork_url),
          album_id    = COALESCE(?, album_id),
          -- COALESCE like the rest: a later play that does not know where the
          -- file came from must not erase what a download recorded.
          collection_slug = COALESCE(?, collection_slug),
          platform_name   = COALESCE(?, platform_name),
          year            = COALESCE(?, year)
      WHERE file_path = ? AND entry_path = ? AND subsong_idx = ?
    ''', [
      title, title, title, title, artist, metaAlbum, position,
      durationS, formatExt, onlineId, subsongCount, artworkUrl, albumId,
      collectionSlug, platformName, year,
      nfp, nep, subsongIdx,
    ]);

    final row = await _database.rawQuery(
      'SELECT id FROM tracks WHERE file_path=? AND entry_path=? AND subsong_idx=?',
      [nfp, nep, subsongIdx],
    );
    return row.first['id'] as String;
  }

  /// Records where a track came from, on a row that already exists (mig 52).
  ///
  /// Separate from [upsertTrack] because the play path learns the origin AFTER
  /// the row is written: `_persistPlay` runs inside `loadFile`, and the shell
  /// only hands over the album context once that returns. COALESCE, so a caller
  /// that knows one of the two does not wipe the other.
  Future<void> setTrackOrigin(String trackId, String? collectionSlug,
      String? platformName, int? year) async {
    if ((collectionSlug ?? '').isEmpty &&
        (platformName ?? '').isEmpty &&
        year == null) {
      return;
    }
    await _database.rawUpdate(
      'UPDATE tracks SET collection_slug = COALESCE(?, collection_slug), '
      '                  platform_name   = COALESCE(?, platform_name), '
      '                  year            = COALESCE(?, year) '
      ' WHERE id = ?',
      [collectionSlug, platformName, year, trackId],
    );
  }

  /// Public poke for callers that batch raw [upsertTrack]s (which don't notify
  /// per-row) and want dependent screens (the Favoris auto-playlist, counters)
  /// to refresh once at the end.
  void notifyBatchChanged() => notifyListeners();

  // ── Play recording ────────────────────────────────────────────────────────

  /// Records a play event. The trigger in the DB updates play_count and
  /// last_played_at on both the track and its parent album automatically.
  ///
  /// play_events IS the listening-stats source (statsTop*, the home "Vos
  /// tendances" rail, the Stats tab), and every one of those listens to this
  /// object — so the write must notify, like every other write here. Without
  /// it the rails only refreshed when some unrelated change (a favourite, a
  /// playlist edit) happened to notify for them.
  /// Returns the new play_events row id so the caller can backfill the real
  /// elapsed play time via [setPlayEventDuration] when the play ends.
  /// [backend] = the C decoder that handled the file (engine stats).
  Future<int> recordPlay(String trackId, {String? backend}) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final id = await _database.rawInsert(
      'INSERT INTO play_events (track_id, played_at, backend) VALUES (?, ?, ?)',
      [trackId, nowSec, (backend == null || backend.isEmpty) ? null : backend],
    );
    notifyListeners();
    return id;
  }

  /// Backfills the real listened duration on a play event (track switch/stop).
  /// No notify: the next recordPlay refreshes every stats listener anyway.
  Future<void> setPlayEventDuration(int eventId, int playedMs) async {
    await _database.update('play_events', {'played_ms': playedMs},
        where: 'id = ?', whereArgs: [eventId]);
  }

  /// Marque des écoutes locales comme DÉJÀ présentes dans la timeline du compte
  /// (livrées par log_play / log_plays_ext, ou rejouées depuis le compte).
  /// C'est ce marqueur, et non un rapprochement temporel, qui empêche l'écran
  /// Stats de compter deux fois la même écoute: `log_play` n'envoie pas de
  /// `played_at` et le serveur estampille `now()`, jusqu'à une longueur de
  /// morceau après le début de la lecture.
  Future<void> markPlayEventsPushed(List<int> eventIds) async {
    if (eventIds.isEmpty) return;
    final marks = List.filled(eventIds.length, '?').join(',');
    await _database.rawUpdate(
        'UPDATE play_events SET pushed = 1 WHERE id IN ($marks)', eventIds);
  }

  /// Marque une écoute comme JAMAIS PROPOSÉE au compte (`pushed = 2`): elle
  /// n'a pas atteint le seuil de `log_play` (30 s, ou la moitié du morceau) —
  /// un morceau qu'on a sauté. Elle reste dans l'historique de cet appareil,
  /// mais la vue fusionnée l'ignore: le compte ne la connaîtra jamais, donc la
  /// compter ferait diverger deux appareils qui ont pourtant tout synchronisé.
  /// C'est la différence avec `pushed = 0`, qui veut dire « le compte devrait
  /// l'avoir et ne l'a pas » (envoi raté, hors ligne) — celle-là compte.
  Future<void> markPlayEventOffAccount(int eventId) async {
    await _database.rawUpdate(
        'UPDATE play_events SET pushed = 2 WHERE id = ? AND pushed = 0',
        [eventId]);
  }

  /// Records an album play — updates recent_albums.last_played_at for [metaAlbum]
  /// WITHOUT touching any individual track's last_played_at.
  /// Fills in the catalogue identity a row was created WITHOUT — the album id,
  /// the cover, and the artist credit — on every subsong of [filePath].
  ///
  /// Targeted on purpose: [upsertTrack] rewrites title/artist/duration from its
  /// arguments, so using it to carry two late-resolved fields would erase what
  /// the play path knows better. Both columns are COALESCE'd — a backfill only
  /// ever adds.
  ///
  /// Why it is needed: a track first played from a PLAYLIST entry has no album
  /// id (playlist_tracks carries none, and neither does the account's ext_ref
  /// snapshot), so the player showed an inert album label and the recents rail
  /// had no cover — for a tune the catalogue knows perfectly well.
  /// [metaAlbum] widens the repair to the whole album: a multi-file album (one
  /// .spc per track) keeps its files in ONE directory, and the sibling rows are
  /// missing exactly the same two fields. Without it only the track that
  /// happened to play got its link back — the next one in the queue was inert
  /// again, which reads as "the fix works once".
  ///
  /// [artist] does NOT take part in the album-wide pass below: an album id and
  /// a cover belong to the album, a credit belongs to the track — a
  /// compilation's siblings have their own, and stamping one over the folder
  /// would rewrite them all as the same composer.
  Future<void> backfillTrackIdentity(String filePath,
      {String? albumId, String? artworkUrl, String? metaAlbum,
      String? artist}) async {
    if ((albumId ?? '').isEmpty &&
        (artworkUrl ?? '').isEmpty &&
        (artist ?? '').isEmpty) {
      return;
    }
    final nfp = _norm(filePath);
    await _database.rawUpdate(
      'UPDATE tracks SET album_id = COALESCE(album_id, ?), '
      'artwork_url = COALESCE(artwork_url, ?), '
      "artist = COALESCE(NULLIF(artist, ''), ?) WHERE file_path = ?",
      [albumId, artworkUrl, artist, nfp],
    );
    if (metaAlbum != null && metaAlbum.isNotEmpty) {
      // Same directory AND same album name: two conditions rather than one, so
      // a folder that happens to hold more than one album cannot be stamped
      // with the wrong id.
      final dir = p.dirname(nfp);
      await _database.rawUpdate(
        'UPDATE tracks SET album_id = COALESCE(album_id, ?), '
        'artwork_url = COALESCE(artwork_url, ?) '
        'WHERE meta_album = ? AND file_path LIKE ? ESCAPE \'\\\' '
        "AND instr(substr(file_path, ?), '/') = 0",
        [
          albumId,
          artworkUrl,
          metaAlbum,
          '${dir.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}/%',
          dir.length + 2,
        ],
      );
    }
    notifyListeners();
  }

  Future<void> upsertRecentAlbum(
    String metaAlbum,
    String filePath, {
    String? artist,
    String? artworkUrl,
    String? albumId,
    String? onlineId,
  }) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nfp = _norm(filePath);
    final dir = p.dirname(nfp);
    // The FILE's identity only. `<uuid>#<rank>` names one entry inside a
    // container, and the rank is not the subsong index — storing it here would
    // hand a wrong entry id to whatever replays the album.
    final hash = onlineId?.indexOf('#') ?? -1;
    final fileOnlineId = hash > 0 ? onlineId!.substring(0, hash) : onlineId;
    // Prefer the server album_id; otherwise key on name + album directory so two
    // same-named albums in different folders/collections stay distinct.
    //
    // The same album can be played once WITH its server album_id (→ id key) and
    // once without (→ "name|dir" key), which would create two rows for one
    // album. Reconcile against any existing row for the same album (same name +
    // same directory): if this play knows the id, drop the stale fallback-keyed
    // dup; if it doesn't, reuse the existing row's key instead of minting a new
    // one. This keeps a single row per album regardless of id availability.
    String albumKey = albumId ?? '$metaAlbum|$dir';
    final existing = await _database.query('recent_albums',
        columns: ['album_key', 'album_id', 'file_path'],
        where: 'meta_album = ?', whereArgs: [metaAlbum]);
    for (final r in existing) {
      if (p.dirname(_norm(r['file_path'] as String)) != dir) continue; // diff album
      final rkey = r['album_key'] as String;
      if (albumId != null) {
        if (rkey != albumId) {
          await _database.delete('recent_albums',
              where: 'album_key = ?', whereArgs: [rkey]);
        }
      } else {
        // Reuse the existing row (prefer an id-keyed one) so we UPDATE it.
        if ((r['album_id'] as String?) != null) { albumKey = rkey; break; }
        albumKey = rkey;
      }
    }
    await _database.execute('''
      INSERT INTO recent_albums
        (album_key, meta_album, album_id, artist, file_path, artwork_url,
         last_played_at, online_id)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(album_key) DO UPDATE SET
        meta_album     = excluded.meta_album,
        album_id       = COALESCE(excluded.album_id, recent_albums.album_id),
        artist         = excluded.artist,
        file_path      = excluded.file_path,
        artwork_url    = COALESCE(excluded.artwork_url, recent_albums.artwork_url),
        last_played_at = excluded.last_played_at,
        -- The id belongs to the FILE: keep it only while the row still points
        -- at that same file (an album re-keyed onto another track must not
        -- inherit the previous one's identity).
        online_id      = CASE
          WHEN excluded.file_path = recent_albums.file_path
            THEN COALESCE(excluded.online_id, recent_albums.online_id)
          ELSE excluded.online_id
        END
    ''', [albumKey, metaAlbum, albumId, artist, nfp, artworkUrl, nowSec, fileOnlineId]);
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  /// Returns all tracks stored for a given local [filePath], ordered by subsong_idx.
  /// Useful to reconstruct the full subsong queue for multi-track archives (RSN, NSF…).
  Future<List<TrackRecord>> getTracksForFile(String filePath) async {
    final rows = await _database.rawQuery('''
      SELECT * FROM tracks
      WHERE  file_path = ?
      ORDER BY subsong_idx ASC
    ''', [_norm(filePath)]);
    return rows.map(TrackRecord.fromMap).toList();
  }

  /// Returns all tracks sharing the same [metaAlbum] tag.  Covers multi-file
  /// albums (e.g. one .vgz per track) where getTracksForFile would only return
  /// a single entry.
  /// Tracks for an album. Prefers the server [albumId] (exact, collection-proof);
  /// falls back to meta_album scoped to [nearFilePath]'s directory so two albums
  /// that share a name but live in different folders don't get mixed; finally
  /// falls back to meta_album alone (legacy).
  ///
  /// **The order is the TRACKLIST's** (`position`), not the file system's. This
  /// is the queue an album replayed from the recents rail gets, and it has to be
  /// the same one the album screen plays — that screen orders by the server's
  /// track_position. Ordering by file_path meant the two disagreed as soon as
  /// the file names were not in tracklist order: on "Disgaea - Hour of
  /// Darkness" the tracklist entries are `SNDPAK_<hex>` and only SOME of them
  /// carry their sub-folder (`usa/…`), so the un-foldered ones sort before the
  /// whole `usa/` block and the album played in a completely different order
  /// the second time. `position` is COALESCE'd on upsert, so a plain play never
  /// erases it; rows that never had one (a locally extracted archive) keep the
  /// old alphabetical behaviour by falling through to file_path.
  Future<List<TrackRecord>> getTracksForAlbum(
    String metaAlbum, {
    String? albumId,
    String? nearFilePath,
  }) async {
    const order =
        'ORDER BY COALESCE(position, 1000000) ASC, file_path ASC, subsong_idx ASC';
    if (albumId != null && albumId.isNotEmpty) {
      final rows = await _database.rawQuery('''
        SELECT * FROM tracks
        WHERE  album_id = ?
        $order
      ''', [albumId]);
      if (rows.isNotEmpty) return rows.map(TrackRecord.fromMap).toList();
    }
    if (nearFilePath != null && nearFilePath.isNotEmpty) {
      final dir = p.dirname(_norm(nearFilePath));
      final rows = await _database.rawQuery('''
        SELECT * FROM tracks
        WHERE  meta_album = ? AND file_path LIKE ? ESCAPE '\\'
        $order
      ''', [metaAlbum, '${_likeEscape(dir)}/%']);
      if (rows.isNotEmpty) return rows.map(TrackRecord.fromMap).toList();
    }
    final rows = await _database.rawQuery('''
      SELECT * FROM tracks
      WHERE  meta_album = ?
      $order
    ''', [metaAlbum]);
    return rows.map(TrackRecord.fromMap).toList();
  }

  // Escapes LIKE wildcards in a literal path prefix (used with ESCAPE '\').
  static String _likeEscape(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');

  Future<List<TrackRecord>> getRecentTracks({int limit = 50}) async {
    final rows = await _database.rawQuery('''
      SELECT * FROM tracks
      WHERE  last_played_at IS NOT NULL
      ORDER BY last_played_at DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(TrackRecord.fromMap).toList();
  }

  /// Returns a merged list of recently-played albums (from recent_albums) and
  /// individually-played tracks (from tracks), sorted by last_played_at DESC.
  /// Albums only appear when played via album mode; tracks only appear when
  /// played individually (single-track mode).

  /// Le nettoyage de la mig 53, partagé: même identité catalogue
  /// (online_id + sous-chanson) sous plusieurs chemins, on supprime celles dont
  /// le fichier n'existe pas — et SEULEMENT quand une sœur en a un (sinon on ne
  /// sait pas laquelle est la bonne, et une ligne porte l'historique d'écoute).
  /// Le test du disque ne se fait pas en SQL, d'où la boucle Dart (mig 49).
  /// Clé CONCATÉNÉE plutôt qu'un row-value `(a,b) IN (…)`: syntaxe SQLite 3.15,
  /// plus récente que le SQLite système d'un Android API 26.
  static Future<int> _dedupeMissingSiblings(DatabaseExecutor db) async {
    final dupes = await db.rawQuery('''
      SELECT id, file_path, online_id, subsong_idx FROM tracks
       WHERE online_id IS NOT NULL
         AND online_id || '#' || subsong_idx IN (
           SELECT online_id || '#' || subsong_idx FROM tracks
            WHERE online_id IS NOT NULL
            GROUP BY online_id, subsong_idx HAVING COUNT(*) > 1)
    ''');
    final byKey = <String, List<Map<String, Object?>>>{};
    for (final r in dupes) {
      byKey
          .putIfAbsent('${r['online_id']}#${r['subsong_idx']}', () => [])
          .add(r);
    }
    final doomed = <String>[];
    for (final group in byKey.values) {
      final present = <String>[];
      final missing = <String>[];
      for (final r in group) {
        final path = _denorm(r['file_path'] as String);
        var ok = false;
        try {
          ok = await File(path).exists();
        } catch (_) {}
        (ok ? present : missing).add(r['id'] as String);
      }
      if (present.isNotEmpty) doomed.addAll(missing);
    }
    if (doomed.isNotEmpty) {
      final marks = List.filled(doomed.length, '?').join(',');
      await db.rawDelete('DELETE FROM tracks WHERE id IN ($marks)', doomed);
      debugPrint('LocalDb dedupe: ${doomed.length} ligne(s) en double '
          '(fichier absent) supprimée(s)');
    }
    return doomed.length;
  }

  /// Prévention EN CONTINU du doublon que la mig 53/54 nettoie après coup:
  /// appelée quand une lecture vient d'ABOUTIR pour cette identité — l'instant
  /// exact où l'on sait qu'une ligne au fichier présent existe, donc où le
  /// critère « une sœur a le fichier » est acquis sans re-scanner la table.
  /// Un morceau sans album est rangé sous son ARTISTE, et deux flux peuvent
  /// nommer le crédit différemment: chaque désaccord recrée le doublon, un
  /// balayage unique ne suffit pas.
  Future<void> pruneMissingDuplicates(String onlineId, int subsongIdx,
      {required String keepPath}) async {
    final rows = await _database.rawQuery(
      'SELECT id, file_path FROM tracks '
      'WHERE online_id = ? AND subsong_idx = ? AND file_path <> ?',
      [onlineId, subsongIdx, _norm(keepPath)],
    );
    if (rows.isEmpty) return;
    final doomed = <String>[];
    for (final r in rows) {
      var ok = false;
      try {
        ok = await File(_denorm(r['file_path'] as String)).exists();
      } catch (_) {}
      if (!ok) doomed.add(r['id'] as String);
    }
    if (doomed.isEmpty) return;
    final marks = List.filled(doomed.length, '?').join(',');
    await _database
        .rawDelete('DELETE FROM tracks WHERE id IN ($marks)', doomed);
    debugPrint('LocalDb prune: ${doomed.length} doublon(s) au fichier absent '
        'pour $onlineId#$subsongIdx');
    notifyListeners();
  }

  Future<List<RecentEntry>> getRecentEntries({int limit = 50}) async {
    final rows = await _database.rawQuery('''
      SELECT
        'album'    AS kind,
        ra.album_key AS key,
        ra.meta_album AS label,
        ra.artist,
        ra.meta_album AS meta_album_col,
        ra.album_id AS album_id_col,
        ra.online_id AS online_id_col,
        ra.file_path,
        ''         AS entry_path,
        0          AS subsong_idx,
        ra.artwork_url,
        -- recent_albums holds no origin of its own, so take it from any track
        -- of the album — same matching rule as the library join below (server
        -- id first, name as the fallback for rows predating it).
        (SELECT t2.platform_name FROM tracks t2
          WHERE ((ra.album_id IS NOT NULL AND t2.album_id = ra.album_id)
              OR (ra.meta_album IS NOT NULL AND ra.meta_album != ''
                  AND t2.meta_album = ra.meta_album))
            AND t2.platform_name IS NOT NULL LIMIT 1) AS platform_name,
        (SELECT t2.format_ext FROM tracks t2
          WHERE ((ra.album_id IS NOT NULL AND t2.album_id = ra.album_id)
              OR (ra.meta_album IS NOT NULL AND ra.meta_album != ''
                  AND t2.meta_album = ra.meta_album))
            AND t2.format_ext IS NOT NULL LIMIT 1) AS format_ext,
        ra.last_played_at,
        COALESCE(li.is_favorite, 0) AS is_favorite,
        CASE WHEN li.ref_id IS NOT NULL THEN 1 ELSE 0 END AS in_library
      FROM recent_albums ra
      LEFT JOIN library_items li
        ON li.type = 'album'
       AND ( (ra.album_id IS NOT NULL AND li.album_id = ra.album_id)
             OR li.ref_id = ra.meta_album )

      UNION ALL

      SELECT kind, key, label, artist, meta_album_col, album_id_col,
             online_id_col, file_path, entry_path, subsong_idx, artwork_url,
             platform_name, format_ext,
             last_played_at, is_favorite, in_library
      FROM (
        SELECT
          'track'    AS kind,
          t.id       AS key,
          COALESCE(t.title, t.file_path) AS label,
          t.artist,
          t.meta_album AS meta_album_col,
          t.album_id AS album_id_col,
          t.online_id AS online_id_col,
          t.file_path,
          t.entry_path,
          t.subsong_idx,
          t.artwork_url,
          t.platform_name,
          t.format_ext,
          t.last_played_at,
          t.is_favorite,
          t.in_library,
          -- One recents entry per FILE: a 19-subsong SID played as a queue
          -- otherwise floods the list with one entry per subsong. Keep the
          -- most recently played subsong (tap resumes it).
          ROW_NUMBER() OVER (
            PARTITION BY t.file_path
            ORDER BY t.last_played_at DESC, t.subsong_idx ASC
          ) AS rn
        FROM tracks t
        WHERE t.last_played_at IS NOT NULL
          -- Recents shows ALBUMS or standalone FILES: hide a track whose album
          -- already has its own recents row (by server id or name) — playing
          -- an album track individually refreshes the album entry instead.
          AND NOT EXISTS (
            SELECT 1 FROM recent_albums ra2
            WHERE (t.album_id IS NOT NULL AND ra2.album_id = t.album_id)
               OR (t.meta_album IS NOT NULL AND t.meta_album != ''
                   AND ra2.meta_album = t.meta_album)
          )
      ) WHERE rn = 1

      ORDER BY last_played_at DESC
      LIMIT ?
    ''', [limit]);

    return rows.map((m) {
      final isAlbum = (m['kind'] as String) == 'album';
      return RecentEntry(
        isAlbum:      isAlbum,
        key:          m['key'] as String,
        label:        m['label'] as String,
        artist:       m['artist'] as String?,
        metaAlbum:    m['meta_album_col'] as String?,
        albumId:      m['album_id_col'] as String?,
        onlineId:     m['online_id_col'] as String?,
        filePath:     _denorm(m['file_path'] as String),
        entryPath:    _denorm(m['entry_path'] as String),
        subsongIdx:   m['subsong_idx'] as int,
        artworkUrl:   m['artwork_url'] as String?,
        platformName: m['platform_name'] as String?,
        formatExt:    m['format_ext'] as String?,
        lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(
            (m['last_played_at'] as int) * 1000),
        isFavorite:   (m['is_favorite'] as int? ?? 0) == 1,
        inLibrary:    (m['in_library']  as int? ?? 0) == 1,
      );
    }).toList();
  }

  /// Returns the favourites playlist: individual favourite tracks + all tracks
  /// from favourite albums, ordered by when each favourite was added.
  /// Album tracks appear together in album position order.
  /// [probeSubsongCount] (native subsong probe, injected by the UI layer)
  /// lets a container-level favourite expand to the file's FULL subsong list
  /// even for subsongs never played yet (no DB row).
  Future<List<TrackRecord>> getFavorites(
      {int Function(String filePath)? probeSubsongCount}) async {
    final libRows = await _database.rawQuery('''
      SELECT * FROM library_items
      WHERE is_favorite = 1
      ORDER BY COALESCE(favorited_at, added_at) ASC
    ''');

    final result  = <TrackRecord>[];
    final seenIds = <String>{};

    for (final item in libRows) {
      final type  = item['type']   as String;
      final refId = item['ref_id'] as String;

      if (type == 'track') {
        // ref_id convention is '<onlineId or filePath>?subsong=<idx>' (see
        // PlayerController.libraryRefId); the tracks table stores the BARE
        // online_id + a subsong_idx column — split the key back apart, else
        // player-heart favourites never match and drop out of this list.
        final (baseId, subsongIdx) = splitLibraryRefId(refId);
        if (subsongIdx != null) {
          final rows = await _database.rawQuery(
              'SELECT * FROM tracks WHERE (online_id = ? OR file_path = ?) '
              'AND subsong_idx = ? LIMIT 1',
              [baseId, _norm(baseId), subsongIdx]);
          if (rows.isNotEmpty) {
            final t = TrackRecord.fromMap(rows.first);
            if (seenIds.add(t.id)) result.add(t);
          }
        } else {
          // Container-level favourite (no suffix = the WHOLE file, see
          // ContainerSubsongScreen._songRefId): expand to every subsong of
          // that file, in order — a LIMIT-1 lookup surfaced one arbitrary
          // subsong only. DB rows exist only for PLAYED subsongs; the native
          // probe (when injected) gives the real count and the gaps are
          // synthesized so all 19 tunes of a fresh favourite show up.
          final any = await _database.rawQuery(
              'SELECT file_path FROM tracks WHERE online_id = ? OR file_path = ? LIMIT 1',
              [baseId, _norm(baseId)]);
          if (any.isNotEmpty) {
            final fp = _denorm(any.first['file_path'] as String);
            final rows = await _database.rawQuery(
                'SELECT * FROM tracks WHERE file_path = ? ORDER BY subsong_idx ASC',
                [_norm(fp)]);
            final known = [for (final row in rows) TrackRecord.fromMap(row)];
            int count = 0;
            if (probeSubsongCount != null) {
              try { count = probeSubsongCount(fp); } catch (_) {}
            }
            if (count > known.length) {
              final byIdx = {for (final t in known) t.subsongIdx: t};
              final ref = known.isNotEmpty ? known.first : null;
              final baseName = fp
                  .split(Platform.pathSeparator)
                  .last
                  .replaceAll(RegExp(r'\.\w+$'), '');
              for (var i = 0; i < count; i++) {
                final t = byIdx[i] ??
                    TrackRecord(
                      id:         '',
                      filePath:   fp,
                      entryPath:  '',
                      subsongIdx: i,
                      title:      '$baseName – ${i + 1}',
                      artist:     ref?.artist,
                      metaAlbum:  ref?.metaAlbum,
                      onlineId:   ref?.onlineId ?? baseId,
                      albumId:    ref?.albumId,
                      artworkUrl: ref?.artworkUrl,
                      formatExt:  fp.split('.').last.toLowerCase(),
                      source:     ref?.source ?? 'online',
                      isFavorite: false,
                      inLibrary:  false,
                      playCount:  0,
                    );
                if (t.id.isEmpty || seenIds.add(t.id)) result.add(t);
              }
            } else {
              for (final t in known) {
                if (seenIds.add(t.id)) result.add(t);
              }
            }
          }
        }
      } else if (type == 'album') {
        // Un ref_id d'album n'est PAS un nom d'album depuis la migration 41: il
        // est devenu l'UUID (deux albums homonymes s'évinçaient l'un l'autre),
        // alors que `tracks.meta_album` porte toujours le NOM d'affichage —
        // c'est ce qu'y écrit materializeAlbumTracks. Comparer meta_album au
        // ref_id ne matchait donc plus rien, et les pistes d'un album mis en
        // favori n'apparaissaient jamais dans la playlist Favoris. La mig 42
        // avait réparé le dégât SYMÉTRIQUE (des UUID écrits dans meta_album);
        // le lecteur, lui, était resté sur le ref_id.
        //
        // On apparie donc par identité d'abord (album_id, robuste aux
        // homonymes), puis par nom — et le ref_id reste accepté pour les lignes
        // antérieures à la mig 41, qui étaient bien keyées par le nom.
        // Le nom ne sert QU'AUX lignes sans identité: deux albums homonymes
        // existent pour de bon (« Chrono Trigger » est ripé par snesmusic ET
        // par jw_spc), et les rassembler par le nom collait 71 pistes de trop
        // dans les favoris — sur le seul appareil qui avait aussi l'autre rip,
        // ce qui a l'air d'un défaut de synchro sans en être un. Une ligne qui
        // porte un `album_id` est donc comparée par identité, un point c'est
        // tout; le repli par nom reste pour les lignes antérieures à la mig 41
        // (et pour le `ref_id`, qui était alors le nom).
        final albumUuid = item['album_id'] as String?;
        final albumName = (item['name'] as String?) ?? refId;
        // Album dont la liste complète a été rapatriée: cette liste FAIT FOI.
        // Les lignes sans identité catalogue qui portent le même album_id sont
        // alors des artefacts locaux — les fichiers extraits d'une archive,
        // sous un autre chemin, doublant des pistes déjà listées (cinq `.spc`
        // de « Final Fantasy V » présents sur un seul des deux appareils). Le
        // dédoublonnage par `online_id` ne peut pas les voir: ils n'en ont pas.
        final canonical = albumUuid != null &&
            albumUuid.isNotEmpty &&
            await isAlbumMaterialised(albumUuid);
        final rows = await _database.rawQuery('''
          SELECT * FROM tracks
          WHERE ((album_id IS NOT NULL AND album_id = ?)
             OR (album_id IS NULL AND (meta_album = ? OR meta_album = ?)))
            ${canonical ? 'AND online_id IS NOT NULL' : ''}
          ORDER BY COALESCE(position, 999) ASC, subsong_idx ASC
        ''', [albumUuid, albumName, refId]);
        final known = [for (final row in rows) TrackRecord.fromMap(row)];
        // Single-container album (jw_nsf: one .nsf holding all tracks): DB rows
        // exist only for PLAYED subsongs — probe the real count and synthesize
        // the gaps, same as a whole-file (container-level) track favourite.
        if (probeSubsongCount != null &&
            known.isNotEmpty &&
            known.every((t) => t.filePath == known.first.filePath)) {
          final fp = known.first.filePath;
          int count = 0;
          try { count = probeSubsongCount(fp); } catch (_) {}
          if (count > known.length) {
            final byIdx = {for (final t in known) t.subsongIdx: t};
            final ref = known.first;
            final baseName = fp
                .split(Platform.pathSeparator)
                .last
                .replaceAll(RegExp(r'\.\w+$'), '');
            for (var i = 0; i < count; i++) {
              final t = byIdx[i] ??
                  TrackRecord(
                    id:         '',
                    filePath:   fp,
                    entryPath:  '',
                    subsongIdx: i,
                    title:      '$baseName – ${i + 1}',
                    artist:     ref.artist,
                    metaAlbum:  ref.metaAlbum,
                    onlineId:   ref.onlineId,
                    albumId:    ref.albumId,
                    artworkUrl: ref.artworkUrl,
                    formatExt:  fp.split('.').last.toLowerCase(),
                    source:     ref.source,
                    isFavorite: false,
                    inLibrary:  false,
                    playCount:  0,
                  );
              if (t.id.isEmpty || seenIds.add(t.id)) result.add(t);
            }
            continue;
          }
        }
        for (final t in known) {
          if (seenIds.add(t.id)) result.add(t);
        }
      }
    }

    return _dedupeByCatalogueId(result);
  }

  /// Une même piste du catalogue peut avoir DEUX lignes `tracks`: celle du
  /// conteneur (un `.rsn` joué en place, une ligne par sous-chanson) et celle
  /// du fichier extrait, sous un autre chemin. Même `online_id`, deux lignes —
  /// et la playlist Favoris affichait alors l'album en double (140 entrées
  /// pour 70 morceaux, sur le seul appareil où l'extraction avait eu lieu).
  ///
  /// On garde celle dont le FICHIER existe (une ligne matérialisée pointe un
  /// chemin qui n'a pas encore été téléchargé), sinon la première. Les
  /// sous-chansons d'un conteneur ne se collapsent pas: chacune a son propre
  /// `online_id`.
  Future<List<TrackRecord>> _dedupeByCatalogueId(
      List<TrackRecord> tracks) async {
    final seen = <String, int>{};   // online_id → sa position dans [out]
    final out = <TrackRecord>[];
    for (final t in tracks) {
      final id = t.onlineId;
      if (id == null || id.isEmpty) { out.add(t); continue; }
      final at = seen[id];
      if (at == null) {
        seen[id] = out.length;
        out.add(t);
        continue;
      }
      // Doublon: le fichier présent l'emporte, à la place déjà tenue (l'ordre
      // de la playlist ne doit pas bouger pour autant).
      final kept = out[at];
      if (!await File(kept.filePath).exists() &&
          await File(t.filePath).exists()) {
        out[at] = t;
      }
    }
    return out;
  }

  Future<List<TrackRecord>> getLibraryTracks() async {
    final rows = await _database.rawQuery('''
      SELECT * FROM tracks
      WHERE  in_library = 1
      ORDER BY library_added_at DESC
    ''');
    return rows.map(TrackRecord.fromMap).toList();
  }

  // ── User actions ──────────────────────────────────────────────────────────

  Future<void> setFavorite(String trackId, {required bool value}) async {
    await _database.execute(
      'UPDATE tracks SET is_favorite = ? WHERE id = ?',
      [value ? 1 : 0, trackId],
    );
    notifyListeners();
  }

  Future<void> setInLibrary(String trackId, {required bool value}) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _database.execute(
      'UPDATE tracks SET in_library = ?, library_added_at = ? WHERE id = ?',
      [value ? 1 : 0, value ? nowSec : null, trackId],
    );
    notifyListeners();
  }

  // ── Library items (user's saved tracks / albums / artists) ───────────────

  /// Le ♥ d'une entrée de bibliothèque — null quand l'entrée n'existe pas.
  ///
  /// C'est la SEULE source du ♥ depuis la migration serveur 206: la colonne
  /// `tracks.is_favorite` n'est posée que par un geste fait sur cet appareil,
  /// donc un ♥ venu du compte ne s'y voit pas (le cœur du lecteur restait
  /// éteint sur un morceau pourtant aimé).
  /// Le ♥ porté par la LIGNE de piste (repli hérité: la colonne n'est posée
  /// que par un geste fait ici). Null si la ligne n'existe pas.
  Future<bool?> trackIsFavourite(String trackId) async {
    final rows = await _database.rawQuery(
        'SELECT is_favorite FROM tracks WHERE id = ? LIMIT 1', [trackId]);
    if (rows.isEmpty) return null;
    return (rows.first['is_favorite'] as int? ?? 0) == 1;
  }

  Future<bool?> libraryItemFavourite(String type, String refId) async {
    final rows = await _database.rawQuery(
      'SELECT is_favorite FROM library_items WHERE type = ? AND ref_id = ? '
      'LIMIT 1',
      [type, refId],
    );
    if (rows.isEmpty) return null;
    return (rows.first['is_favorite'] as int? ?? 0) == 1;
  }

  Future<bool> isInLibrary(String type, String refId) async {
    final rows = await _database.rawQuery(
      'SELECT 1 FROM library_items WHERE type = ? AND ref_id = ? LIMIT 1',
      [type, refId],
    );
    return rows.isNotEmpty;
  }

  /// Album membership matched by server UUID when available. ref_id holds the
  /// display NAME (legacy key), so a bare name check lights the star on every
  /// HOMONYM album; with [albumId] the exact row is matched first, and the
  /// name fallback only applies to legacy rows that never got an album_id.
  Future<bool> isAlbumInLibrary(String name, {String? albumId}) async {
    if (albumId != null && albumId.isNotEmpty) {
      final byId = await _database.rawQuery(
        "SELECT 1 FROM library_items WHERE type='album' AND album_id = ? LIMIT 1",
        [albumId],
      );
      if (byId.isNotEmpty) return true;
      final legacy = await _database.rawQuery(
        "SELECT 1 FROM library_items WHERE type='album' AND album_id IS NULL AND ref_id = ? LIMIT 1",
        [name],
      );
      return legacy.isNotEmpty;
    }
    return isInLibrary('album', name);
  }

  /// Artist membership across BOTH key forms. ref_id is the artist UUID when
  /// the saving screen knew it, the display NAME otherwise (legacy rows and
  /// name-only contexts) — checking one form alone left the heart dark on the
  /// other, and re-adding made a duplicate. The name arm can light up on a
  /// homonym artist, the same accepted trade-off as [isAlbumInLibrary]'s
  /// legacy arm; the uuid match wins whenever the caller has one.
  Future<bool> isArtistInLibrary(String name, {String? refId}) async {
    final rows = await _database.rawQuery(
      "SELECT 1 FROM library_items WHERE type='artist' "
      "AND (ref_id = ? OR ref_id = ? OR name = ?) LIMIT 1",
      [refId ?? name, name, name],
    );
    return rows.isNotEmpty;
  }

  /// Removes an artist across BOTH key forms (uuid ref_id, name ref_id) and
  /// by display name — one un-heart clears the pair a duplicate left behind,
  /// and a name-only caller still removes a uuid-saved row.
  Future<void> removeArtistFromLibrary(String name, {String? refId}) async {
    await _database.execute(
      "DELETE FROM library_items WHERE type='artist' "
      "AND (ref_id = ? OR ref_id = ? OR name = ?)",
      [refId ?? name, name, name],
    );
    notifyListeners();
  }

  /// True when ANY subsong of [songId] is in the library — track keys are
  /// subsong-scoped ('<id>?subsong=<idx>'), so a bare-id equality check never
  /// matches post-v17 rows.
  Future<bool> isTrackInLibraryAnySubsong(String songId) async {
    final rows = await _database.rawQuery(
      "SELECT 1 FROM library_items WHERE type='track' "
      "AND (ref_id = ? OR ref_id LIKE ? || '?subsong=%') LIMIT 1",
      [songId, songId],
    );
    return rows.isNotEmpty;
  }

  /// True when ANY subsong of [songId] is FAVOURITE (the gold star). Distinct
  /// from library membership: un-favouriting keeps the row in the library
  /// (favourite ⊆ library), and the star must go out immediately.
  Future<bool> isTrackFavoriteAnySubsong(String songId) async {
    final rows = await _database.rawQuery(
      "SELECT 1 FROM library_items WHERE type='track' AND is_favorite = 1 "
      "AND (ref_id = ? OR ref_id LIKE ? || '?subsong=%') LIMIT 1",
      [songId, songId],
    );
    return rows.isNotEmpty;
  }

  Future<bool> isLibraryFavorite(String type, String refId) async {
    final rows = await _database.rawQuery(
      'SELECT 1 FROM library_items WHERE type = ? AND ref_id = ? AND is_favorite = 1 LIMIT 1',
      [type, refId],
    );
    return rows.isNotEmpty;
  }

  /// Album favourite matched by server UUID when available (same homonym
  /// rationale as [isAlbumInLibrary]).
  Future<bool> isAlbumFavorite(String name, {String? albumId}) async {
    if (albumId != null && albumId.isNotEmpty) {
      final byId = await _database.rawQuery(
        "SELECT 1 FROM library_items WHERE type='album' AND album_id = ? AND is_favorite = 1 LIMIT 1",
        [albumId],
      );
      if (byId.isNotEmpty) return true;
      final legacy = await _database.rawQuery(
        "SELECT 1 FROM library_items WHERE type='album' AND album_id IS NULL AND ref_id = ? AND is_favorite = 1 LIMIT 1",
        [name],
      );
      return legacy.isNotEmpty;
    }
    return isLibraryFavorite('album', name);
  }

  /// [explicit] = the user deliberately ADDED this to the library
  /// (LibraryButton / "add to library"). Favorite flows pass false: the row
  /// then only lives as long as the favorite does (see the un-favorite paths,
  /// which delete saved=0 rows — favorite-then-unfavorite used to leave a
  /// phantom library entry). An explicit add on an existing row upgrades it.
  Future<void> addToLibrary({
    required String type,
    required String refId,
    required String name,
    String? artist,
    String? album,
    String? artworkUrl,
    String? formatExt,
    String? collectionSlug,
    String? platformName,
    String? filename,
    String? downloadUrl,
    String? albumId,
    bool isFavorite = false,
    bool explicit = true,
  }) async {
    final nowSec     = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final favoriteSec = isFavorite ? nowSec : null;
    await _database.execute('''
      INSERT INTO library_items
        (id, type, ref_id, name, artist, album, artwork_url, format_ext,
         collection_slug, platform_name, filename, download_url, album_id,
         is_favorite, favorited_at, added_at, saved)
      VALUES
        (lower(hex(randomblob(16))), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
         ?, ?, ?, ?)
      ON CONFLICT(type, ref_id) DO UPDATE SET
        name            = excluded.name,
        artist          = COALESCE(excluded.artist, library_items.artist),
        artwork_url     = COALESCE(excluded.artwork_url, library_items.artwork_url),
        album_id        = COALESCE(excluded.album_id, library_items.album_id),
        is_favorite     = CASE WHEN excluded.is_favorite = 1 THEN 1 ELSE library_items.is_favorite END,
        favorited_at    = CASE WHEN excluded.is_favorite = 1 AND library_items.favorited_at IS NULL
                               THEN excluded.favorited_at
                               ELSE library_items.favorited_at END,
        saved           = MAX(library_items.saved, excluded.saved)
    ''', [
      type, refId, name, artist, album, artworkUrl, formatExt,
      collectionSlug, platformName, filename, downloadUrl, albumId,
      isFavorite ? 1 : 0, favoriteSec, nowSec, explicit ? 1 : 0,
    ]);
    notifyListeners();
  }

  /// Toggles the `is_favorite` flag on an existing library item.
  /// If [value]=true and the item is not yet in the library, a minimal entry
  /// is inserted so it can be found by [getFavorites].
  Future<void> setLibraryItemFavorite(
    String type,
    String refId, {
    required bool value,
    String? name,
    String? artist,
    String? album,
    String? artworkUrl,
    String? formatExt,
    String? collectionSlug,
    String? platformName,
    String? albumId,
    /// Epoch seconds of the decision. The sync passes the OTHER device's date
    /// when it applies a remote choice, so this device does not then look like
    /// the most recent author of something it merely received.
    int? changedAt,
  }) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (value) {
      // Upsert: insert if absent, then set is_favorite=1. Persist album_id so a
      // favourited album keeps its server id (needed to expand it + to light the
      // star in "recently played", which joins on album_id). A row CREATED here
      // is favorite-only (saved=0); an existing explicit add keeps saved=1.
      await _database.execute('''
        INSERT INTO library_items
          (id, type, ref_id, name, artist, album, artwork_url, format_ext,
           collection_slug, platform_name, album_id, is_favorite, favorited_at, added_at, saved)
        VALUES
          (lower(hex(randomblob(16))), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, 0)
        ON CONFLICT(type, ref_id) DO UPDATE SET
          is_favorite  = 1,
          album_id     = COALESCE(excluded.album_id, library_items.album_id),
          favorited_at = COALESCE(library_items.favorited_at, excluded.favorited_at)
      ''', [
        type, refId, name ?? refId, artist, album, artworkUrl, formatExt,
        collectionSlug, platformName, albumId, nowSec, nowSec,
      ]);
      // Dated separately from favorited_at, which keeps the FIRST time it was
      // favourited; the sync needs the LAST decision.
      await _database.execute(
        'UPDATE library_items SET fav_changed_at = ? WHERE type = ? AND ref_id = ?',
        [changedAt ?? nowSec, type, refId],
      );
    } else {
      await _database.execute(
        'UPDATE library_items SET is_favorite = 0, favorited_at = NULL, '
        'fav_changed_at = ? WHERE type = ? AND ref_id = ?',
        [changedAt ?? nowSec, type, refId],
      );
      // Favorite-only row: un-favoriting removes it from the library entirely
      // (it was never explicitly saved).
      await _database.execute(
        'DELETE FROM library_items WHERE type = ? AND ref_id = ? AND saved = 0 AND is_favorite = 0',
        [type, refId],
      );
    }
    notifyListeners();
  }

  Future<void> removeFromLibrary(String type, String refId) async {
    await _database.execute(
      'DELETE FROM library_items WHERE type = ? AND ref_id = ?',
      [type, refId],
    );
    // Un favori est une entrée de bibliothèque (`favourite ⇒ in_library`, un
    // invariant que le serveur applique aussi: retirer efface le ♥). La ligne
    // partie, le ♥ part avec elle — mais `tracks.is_favorite` restait à 1 et
    // le cœur du lecteur allumé sur un morceau qui n'était plus en
    // bibliothèque. La colonne n'est plus qu'un repli d'affichage, elle doit
    // suivre.
    if (type == 'track') {
      final (base, sub) = splitLibraryRefId(refId);
      await _database.rawUpdate(
        'UPDATE tracks SET is_favorite = 0, in_library = 0 '
        'WHERE (online_id = ? OR file_path = ?)'
        '${sub != null ? ' AND subsong_idx = ?' : ''}',
        [base, _norm(base), if (sub != null) sub],
      );
    }
    notifyListeners();
  }

  /// Sets/clears the favourite flag for a library item, adding it to the
  /// library first when favouriting (favourites are surfaced from
  /// library_items). Un-favouriting keeps the item in the library.
  Future<void> setLibraryFavorite({
    required String type,
    required String refId,
    required String name,
    required bool   value,
    String? artist,
    String? album,
    String? artworkUrl,
    String? formatExt,
    String? filename,
  }) async {
    if (value) {
      await addToLibrary(
        type: type, refId: refId, name: name, artist: artist, album: album,
        artworkUrl: artworkUrl, formatExt: formatExt, filename: filename,
        isFavorite: true, explicit: false,
      );
    } else {
      await _database.execute(
        'UPDATE library_items SET is_favorite = 0, favorited_at = NULL '
        'WHERE type = ? AND ref_id = ?',
        [type, refId],
      );
      // Favorite-only row (never explicitly saved) → drop it entirely.
      await _database.execute(
        'DELETE FROM library_items WHERE type = ? AND ref_id = ? AND saved = 0 AND is_favorite = 0',
        [type, refId],
      );
      notifyListeners();
    }
  }

  /// Removes a library entry, clears its favourite flag(s), and deletes the
  /// associated files from disk. Returns the number of files deleted.
  Future<int> removeFromLibraryWithCleanup(String type, String refId) async {
    final pathsToDelete = <String>{};

    if (type == 'track') {
      final rows = await _database.rawQuery(
        "SELECT file_path FROM tracks WHERE online_id = ? AND source = 'online' LIMIT 1",
        [refId],
      );
      if (rows.isNotEmpty) {
        pathsToDelete.add(LocalDb._denorm(rows.first['file_path'] as String));
      }
      await _database.execute(
        "UPDATE tracks SET is_favorite = 0 WHERE online_id = ?", [refId]);
    } else if (type == 'album') {
      // All tracks in this online album share a directory — grab one path.
      final rows = await _database.rawQuery(
        "SELECT file_path FROM tracks WHERE meta_album = ? AND source = 'online' LIMIT 1",
        [refId],
      );
      if (rows.isNotEmpty) {
        final dir = p.dirname(LocalDb._denorm(rows.first['file_path'] as String));
        pathsToDelete.add(dir);
      }
      await _database.execute(
        "UPDATE tracks SET is_favorite = 0 WHERE meta_album = ? AND source = 'online'",
        [refId]);
    }

    await _database.execute(
      'DELETE FROM library_items WHERE type = ? AND ref_id = ?',
      [type, refId],
    );

    int deleted = 0;
    for (final path in pathsToDelete) {
      try {
        final dir = Directory(path);
        final file = File(path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          deleted++;
        } else if (await file.exists()) {
          await file.delete();
          deleted++;
        }
      } catch (_) {}
    }
    notifyListeners();
    return deleted;
  }

  /// Library items, optionally filtered by [type] and — when [scoped] is set —
  /// by folder ([folderId] null = root). Unscoped (default) returns every item
  /// regardless of folder (e.g. the "recently added" grid).
  Future<List<LibraryItem>> getLibraryItems(
      {String? type, String? folderId, bool scoped = false}) async {
    final conds = <String>[];
    final args  = <dynamic>[];
    if (type != null) { conds.add('type = ?'); args.add(type); }
    if (scoped) {
      if (folderId == null) {
        conds.add('folder_id IS NULL');
      } else {
        conds.add('folder_id = ?');
        args.add(folderId);
      }
    }
    final where = conds.isEmpty ? '' : 'WHERE ${conds.join(' AND ')}';
    // `name` d'une entrée MORCEAU est le nom du FICHIER au moment du geste —
    // pour un conteneur (un `.psf` d'album jw_psf, un `.nsf` multi-subsongs)
    // c'est le nom de l'ALBUM, pas celui de la piste. Le vrai titre est sur la
    // ligne `tracks`, retrouvée par l'identité que porte le `ref_id`
    // (`<uuid|chemin>?subsong=N`).
    //
    // ⚠️ DEUX formes d'identité locale pour la même piste, et il faut les deux
    // (même règle que `trackByOnlineIdAndSubsong`): un uuid NU avec sa colonne
    // `subsong_idx`, et le `uuid#N` synthétique que fabrique l'expansion d'un
    // conteneur. Deux appareils du même compte peuvent porter chacun une forme
    // selon la façon dont l'album est arrivé (extraction ou matérialisation) —
    // n'en gérer qu'une donnait le titre sur l'un et rien sur l'autre.
    const base = """CASE
      WHEN instr(li.ref_id, '?subsong=') > 0
        THEN substr(li.ref_id, 1, instr(li.ref_id, '?subsong=') - 1)
      ELSE li.ref_id END""";
    const sub = """CASE
      WHEN instr(li.ref_id, '?subsong=') > 0
        THEN CAST(substr(li.ref_id, instr(li.ref_id, '?subsong=') + 9) AS INTEGER)
      ELSE 0 END""";
    const trackTitle = '''
      (SELECT t.title FROM tracks t
        WHERE (t.online_id = $base AND t.subsong_idx = $sub)
           OR t.online_id = $base || '#' || $sub
           OR (t.file_path = $base AND t.subsong_idx = $sub)
        LIMIT 1) AS track_title''';
    // L'ARTISTE d'un album n'est pas stocké sur l'entrée: les écrans qui
    // enregistrent un album ne le connaissent pas toujours (une carte de
    // navigation par facettes n'a que le nom et la pochette). Il est sur les
    // lignes `tracks` de l'album — sans lui, la grille n'affichait rien sous la
    // pochette et le tri « par artiste » ne triait rien du tout.
    const albumArtist = '''
      (SELECT t.artist FROM tracks t
        WHERE li.type = 'album'
          AND t.artist IS NOT NULL AND t.artist != ''
          AND ((li.album_id IS NOT NULL AND t.album_id = li.album_id)
            OR (li.album_id IS NULL AND t.meta_album = li.name))
        LIMIT 1) AS resolved_artist''';
    // Idem pour l'ALBUM d'un morceau: l'entrée ne le porte que si l'écran qui
    // l'a enregistrée le connaissait. La ligne `tracks`, elle, le sait — c'est
    // ce qui manquait pour que l'écran Morceaux affiche l'album du morceau.
    const trackAlbum = '''
      (SELECT t.meta_album FROM tracks t
        WHERE li.type = 'track'
          AND t.meta_album IS NOT NULL AND t.meta_album != ''
          AND ((t.online_id = $base AND t.subsong_idx = $sub)
            OR t.online_id = $base || '#' || $sub
            OR (t.file_path = $base AND t.subsong_idx = $sub))
        LIMIT 1) AS resolved_album''';
    final rows = await _database.rawQuery(
      'SELECT li.*, $trackTitle, $albumArtist, $trackAlbum '
      'FROM library_items li $where ORDER BY added_at DESC', args);
    return rows.map(LibraryItem.fromMap).toList();
  }

  /// The library row of an album known only by NAME. Since migration 41 the
  /// ref_id of a catalogued album is its UUID, so the lookup is on `name`; the
  /// ref_id arm is kept for rows the migration left alone (no UUID), where the
  /// two columns hold the same string anyway.
  ///
  /// Ambiguous by construction on homonyms — the caller (album context: the
  /// collection/platform pair) only has a name to go on, and homonyms of the
  /// same name in DIFFERENT collections are exactly what it cannot tell apart.
  /// Prefer whichever row was added last; a caller holding the UUID should not
  /// be using this at all.
  Future<LibraryItem?> getLibraryAlbum(String albumName) async {
    final rows = await _database.rawQuery(
      "SELECT * FROM library_items WHERE type = 'album' "
      "AND (name = ? OR ref_id = ?) ORDER BY added_at DESC LIMIT 1",
      [albumName, albumName]);
    if (rows.isEmpty) return null;
    return LibraryItem.fromMap(rows.first);
  }

  Future<TrackRecord?> getTrackById(String id) async {
    final rows = await _database.rawQuery(
      'SELECT * FROM tracks WHERE id = ? LIMIT 1', [id]);
    if (rows.isEmpty) return null;
    return TrackRecord.fromMap(rows.first);
  }

  Future<TrackRecord?> getTrackByOnlineId(String onlineId) async {
    var rows = await _database.rawQuery(
      'SELECT * FROM tracks WHERE online_id = ? LIMIT 8', [onlineId]);
    // `<uuid>#<n>` names ONE subsong; the uuid alone names the FILE, and this
    // getter exists to FIND THE BYTES — the same bytes either way. The rows of
    // a container are stored under whichever form the play path used, so a
    // pinned id (a playlist entry, an expanded album row) found nothing and the
    // caller re-downloaded the file it already had, under the path its own RPC
    // happened to derive: the module ended up in two directories. Exact id
    // first — an RSN member's rank must keep winning — then the bare uuid.
    if (rows.isEmpty && onlineId.contains('#')) {
      rows = await _database.rawQuery(
        'SELECT * FROM tracks WHERE online_id = ? LIMIT 8',
        [onlineId.split('#').first]);
    }
    if (rows.isEmpty) return null;
    // Several rows can share an online id: an archive member gets a row at its
    // COMPUTED per-track path (…/ct-06.spc — which never exists for an RSN)
    // next to the row at the archive it actually plays from. Callers use this
    // row to FIND THE BYTES, so prefer the one whose file is on disk — the
    // unordered LIMIT 1 could return the phantom row, and every play of a
    // cached RSN member then fell into the full album-resolution path
    // (fetchAlbumDetails + browse + "téléchargement" flash, zero bytes moved).
    TrackRecord? first;
    for (final m in rows) {
      final rec = TrackRecord.fromMap(m);
      first ??= rec;
      try {
        if (rec.filePath.isNotEmpty && await File(rec.filePath).exists()) {
          return rec;
        }
      } catch (_) {}
    }
    return first;
  }

  /// The download_url a song was last fetched from (null = never recorded).
  /// Used to detect a server-side file replacement (same song_id, new url).
  Future<String?> getDownloadSourceUrl(String onlineId) async {
    final rows = await _database.rawQuery(
      'SELECT source_url FROM download_sources WHERE online_id = ? LIMIT 1',
      [onlineId]);
    if (rows.isEmpty) return null;
    return rows.first['source_url'] as String?;
  }

  /// Records the download_url a song was fetched from (upsert by online_id).
  Future<void> setDownloadSourceUrl(String onlineId, String url) async {
    await _database.insert(
      'download_sources',
      {
        'online_id':  onlineId,
        'source_url': url,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Distinct on-disk file paths recorded for an album, matched by server
  /// [albumId] and/or [metaAlbum]. Used to detect a cached container (e.g. an
  /// .rsn whose subsongs all share one file) without relying on per-track
  /// online_id, which can differ between a fresh server fetch and the persisted
  /// rows. Paths are de-normalised; the caller checks File existence.
  Future<List<String>> albumCachedFilePaths({
    String? albumId,
    String? metaAlbum,
  }) async {
    final clauses = <String>[];
    final args    = <Object?>[];
    if (albumId != null && albumId.isNotEmpty) {
      clauses.add('album_id = ?');
      args.add(albumId);
    }
    if (metaAlbum != null && metaAlbum.isNotEmpty) {
      clauses.add('meta_album = ?');
      args.add(metaAlbum);
    }
    if (clauses.isEmpty) return const [];
    final rows = await _database.rawQuery(
      'SELECT DISTINCT file_path FROM tracks WHERE ${clauses.join(' OR ')}', args);
    return rows.map((r) => _denorm(r['file_path'] as String)).toList();
  }

  // ── Playlists & folders ───────────────────────────────────────────────────

  /// Playlists, optionally scoped to [folderId] (null root when [scoped]),
  /// filtered by [query] (name substring, case-insensitive) and sorted:
  /// 'name' | 'recent' (updated_at desc) | 'created'.
  Future<List<UserPlaylist>> getPlaylistsFiltered({
    String? folderId,
    bool scoped = false,
    String? query,
    String orderBy = 'name',
  }) async {
    final where = <String>[];
    final args  = <Object?>[];
    if (scoped) {
      if (folderId == null) {
        where.add('p.folder_id IS NULL');
      } else {
        where.add('p.folder_id = ?');
        args.add(folderId);
      }
    }
    if (query != null && query.trim().isNotEmpty) {
      where.add('p.name LIKE ?');
      args.add('%${query.trim()}%');
    }
    final order = switch (orderBy) {
      'recent'  => 'p.updated_at DESC',
      'created' => 'p.created_at DESC',
      _         => 'p.name COLLATE NOCASE ASC',
    };
    final rows = await _database.rawQuery('''
      SELECT p.*, (SELECT COUNT(*) FROM playlist_tracks pt
                    WHERE pt.playlist_id = p.id) AS track_count
      FROM playlists p
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY $order
    ''', args);
    return rows.map(UserPlaylist.fromMap).toList();
  }

  /// Artwork source for a playlist's mini-thumbnail: the first track (by
  /// position) carrying an artwork_url, else the first track at all (its
  /// file path lets ArtworkImage find user-placed sibling artwork). Both null
  /// when the playlist is empty.
  Future<({String? url, String? filePath})> getPlaylistArtworkSource(
      String playlistId) async {
    Future<({String? url, String? filePath})?> pick(String extraWhere) async {
      final rows = await _database.rawQuery('''
        SELECT t.artwork_url, t.file_path FROM playlist_tracks pt
        JOIN tracks t ON t.id = pt.track_id
        WHERE pt.playlist_id = ? $extraWhere
        ORDER BY pt.position ASC LIMIT 1
      ''', [playlistId]);
      if (rows.isEmpty) return null;
      return (
        url:      rows.first['artwork_url'] as String?,
        filePath: _denorm(rows.first['file_path'] as String),
      );
    }
    return await pick('AND t.artwork_url IS NOT NULL') ??
        await pick('') ??
        (url: null, filePath: null);
  }

  /// Artwork for the Favoris auto-playlist tile: the oldest favourite carrying
  /// an artwork_url (albums store one on their library_items row directly).
  Future<String?> getFavoritesArtworkUrl() async {
    final rows = await _database.rawQuery('''
      SELECT artwork_url FROM library_items
      WHERE is_favorite = 1 AND artwork_url IS NOT NULL
      ORDER BY COALESCE(favorited_at, added_at) ASC LIMIT 1
    ''');
    return rows.isEmpty ? null : rows.first['artwork_url'] as String?;
  }

  Future<List<PlaylistFolder>> getPlaylistFolders({String? parentId}) async {
    final rows = await _database.query(
      'playlist_folders',
      where: parentId == null ? 'parent_id IS NULL' : 'parent_id = ?',
      whereArgs: parentId == null ? null : [parentId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(PlaylistFolder.fromMap).toList();
  }

  /// Every folder, flat (all levels) — for the "move to folder" picker.
  Future<List<PlaylistFolder>> getAllPlaylistFolders() async {
    final rows = await _database.query('playlist_folders',
        orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(PlaylistFolder.fromMap).toList();
  }

  Future<String> createPlaylist(String name, {String? folderId}) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final id = await _database.rawQuery(
      'INSERT INTO playlists (name, folder_id, created_at, updated_at) '
      'VALUES (?, ?, ?, ?) RETURNING id',
      [name, folderId, nowSec, nowSec],
    );
    notifyListeners();
    return id.first['id'] as String;
  }

  /// Creates or updates a folder with an EXPLICIT id — how a folder tree that
  /// came down from the account keeps the same ids on every device (the id is
  /// what the assignment map points at).
  Future<void> upsertPlaylistFolder(
      String id, String name, String? parentId) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _database.rawInsert(
      'INSERT INTO playlist_folders (id, name, parent_id, created_at) '
      'VALUES (?, ?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET name = excluded.name, '
      '                              parent_id = excluded.parent_id',
      [id, name, parentId, nowSec],
    );
    notifyListeners();
  }

  Future<String> createPlaylistFolder(String name, {String? parentId}) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final id = await _database.rawQuery(
      'INSERT INTO playlist_folders (name, parent_id, created_at) '
      'VALUES (?, ?, ?) RETURNING id',
      [name, parentId, nowSec],
    );
    notifyListeners();
    return id.first['id'] as String;
  }

  // ── projectM preset playlists (migration 50) ──────────────────────────────
  // Every `path` in these tables is RELATIVE to <datadir>/projectm/ —
  // PresetManager resolves to absolute at use (iOS container UUIDs move).

  Future<List<PmPlaylist>> pmPlaylists() async {
    final rows = await _database.rawQuery('''
      SELECT p.id, p.name, p.server_id, p.updated_at, COUNT(i.id) AS item_count
        FROM pm_playlists p
        LEFT JOIN pm_playlist_items i ON i.playlist_id = p.id
       GROUP BY p.id
       ORDER BY p.name COLLATE NOCASE
    ''');
    return [
      for (final r in rows)
        PmPlaylist(
          id: r['id'] as String,
          name: r['name'] as String,
          serverId: r['server_id'] as String?,
          itemCount: (r['item_count'] as int?) ?? 0,
          updatedAt: (r['updated_at'] as int?) ?? 0,
        ),
    ];
  }

  /// The local mirror of a curated server playlist, if it was imported.
  Future<String?> pmPlaylistIdForServer(String serverId) async {
    final rows = await _database.rawQuery(
        'SELECT id FROM pm_playlists WHERE server_id = ? LIMIT 1', [serverId]);
    return rows.isEmpty ? null : rows.first['id'] as String;
  }

  Future<String> createPmPlaylist(String name, {String? serverId}) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final id = await _database.rawQuery(
      'INSERT INTO pm_playlists (name, server_id, created_at, updated_at) '
      'VALUES (?, ?, ?, ?) RETURNING id',
      [name, serverId, nowSec, nowSec],
    );
    notifyListeners();
    return id.first['id'] as String;
  }

  /// Full item rewrite (curated-playlist import refresh).
  Future<void> setPmPlaylistItems(
      String playlistId, List<PmPlaylistItem> items) async {
    await _database.rawDelete(
        'DELETE FROM pm_playlist_items WHERE playlist_id = ?', [playlistId]);
    final batch = _database.batch();
    for (var i = 0; i < items.length; i++) {
      batch.rawInsert(
          'INSERT INTO pm_playlist_items (playlist_id, position, path, preset_id, name) '
          'VALUES (?, ?, ?, ?, ?)',
          [playlistId, i, items[i].path, items[i].presetId, items[i].name]);
    }
    await batch.commit(noResult: true);
    await _touchPmPlaylist(playlistId);
    notifyListeners();
  }

  Future<void> renamePmPlaylist(String id, String name) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _database.rawUpdate(
        'UPDATE pm_playlists SET name = ?, updated_at = ? WHERE id = ?',
        [name, nowSec, id]);
    notifyListeners();
  }

  Future<void> deletePmPlaylist(String id) async {
    // No FK cascade reliance: PRAGMA foreign_keys is per-connection.
    await _database
        .rawDelete('DELETE FROM pm_playlist_items WHERE playlist_id = ?', [id]);
    await _database.rawDelete('DELETE FROM pm_playlists WHERE id = ?', [id]);
    notifyListeners();
  }

  Future<List<PmPlaylistItem>> pmPlaylistItems(String playlistId) async {
    final rows = await _database.rawQuery(
        'SELECT id, path, preset_id, name, position FROM pm_playlist_items '
        'WHERE playlist_id = ? ORDER BY position',
        [playlistId]);
    return [
      for (final r in rows)
        PmPlaylistItem(
          id: r['id'] as int,
          path: r['path'] as String,
          presetId: r['preset_id'] as String?,
          name: r['name'] as String?,
          position: (r['position'] as int?) ?? 0,
        ),
    ];
  }

  /// Appends [path] to the playlist; returns false when it is already there
  /// (adding the current preset twice is a no-op, not a duplicate).
  Future<bool> addPmPlaylistItem(String playlistId,
      {required String path, String? presetId, String? name}) async {
    final dup = await _database.rawQuery(
        'SELECT 1 FROM pm_playlist_items WHERE playlist_id = ? AND path = ?',
        [playlistId, path]);
    if (dup.isNotEmpty) return false;
    await _database.rawInsert(
        'INSERT INTO pm_playlist_items (playlist_id, position, path, preset_id, name) '
        'VALUES (?, COALESCE((SELECT MAX(position) + 1 FROM pm_playlist_items '
        '                      WHERE playlist_id = ?), 0), ?, ?, ?)',
        [playlistId, playlistId, path, presetId, name]);
    await _touchPmPlaylist(playlistId);
    notifyListeners();
    return true;
  }

  Future<void> removePmPlaylistItem(String playlistId, int itemId) async {
    await _database.rawDelete(
        'DELETE FROM pm_playlist_items WHERE playlist_id = ? AND id = ?',
        [playlistId, itemId]);
    await _renumberPmPlaylist(playlistId);
    await _touchPmPlaylist(playlistId);
    notifyListeners();
  }

  /// [newIndex] already adjusted for the removal (ReorderableListView's
  /// onReorderItem convention, same as the queue panel).
  Future<void> reorderPmPlaylistItem(
      String playlistId, int oldIndex, int newIndex) async {
    final items = await pmPlaylistItems(playlistId);
    if (oldIndex < 0 || oldIndex >= items.length) return;
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex.clamp(0, items.length), moved);
    final batch = _database.batch();
    for (var i = 0; i < items.length; i++) {
      batch.rawUpdate(
          'UPDATE pm_playlist_items SET position = ? WHERE id = ?',
          [i, items[i].id]);
    }
    await batch.commit(noResult: true);
    await _touchPmPlaylist(playlistId);
    notifyListeners();
  }

  Future<void> _renumberPmPlaylist(String playlistId) async {
    final items = await pmPlaylistItems(playlistId);
    final batch = _database.batch();
    for (var i = 0; i < items.length; i++) {
      if (items[i].position != i) {
        batch.rawUpdate(
            'UPDATE pm_playlist_items SET position = ? WHERE id = ?',
            [i, items[i].id]);
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> _touchPmPlaylist(String playlistId) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _database.rawUpdate(
        'UPDATE pm_playlists SET updated_at = ? WHERE id = ?',
        [nowSec, playlistId]);
  }

  /// path→server preset_id cache (stable uuid5). Bulk read/write for the
  /// usage-logging resolver.
  Future<Map<String, String>> pmPresetIdsForPaths(List<String> paths) async {
    if (paths.isEmpty) return const {};
    final out = <String, String>{};
    for (var i = 0; i < paths.length; i += 500) {
      final chunk = paths.sublist(i, (i + 500).clamp(0, paths.length));
      final marks = List.filled(chunk.length, '?').join(',');
      final rows = await _database.rawQuery(
          'SELECT path, preset_id FROM pm_preset_ids WHERE path IN ($marks)',
          chunk);
      for (final r in rows) {
        out[r['path'] as String] = r['preset_id'] as String;
      }
    }
    return out;
  }

  /// Distinct playlist-item paths under [prefix] (a relative dir prefix like
  /// 'packs/<slug>/') — what a pack uninstall must rescue.
  Future<List<String>> pmPlaylistPathsUnder(String prefix) async {
    final rows = await _database.rawQuery(
        'SELECT DISTINCT path FROM pm_playlist_items WHERE path LIKE ?',
        ['$prefix%']);
    return [for (final r in rows) r['path'] as String];
  }

  /// Repoints every reference to a preset that MOVED on disk (a single
  /// download absorbed by its pack, a pack file rescued into single/).
  Future<void> repathPmPreset(String oldRel, String newRel) async {
    if (oldRel == newRel) return;
    await _database.rawUpdate(
        'UPDATE pm_playlist_items SET path = ? WHERE path = ?',
        [newRel, oldRel]);
    // The id cache is keyed BY path: move the row, and let an existing row at
    // the destination win (same preset, same id).
    final rows = await _database.rawQuery(
        'SELECT preset_id FROM pm_preset_ids WHERE path = ?', [oldRel]);
    if (rows.isNotEmpty) {
      await _database.rawInsert(
          'INSERT INTO pm_preset_ids (path, preset_id) VALUES (?, ?) '
          'ON CONFLICT(path) DO UPDATE SET preset_id = excluded.preset_id',
          [newRel, rows.first['preset_id']]);
    }
    await _database.rawDelete('DELETE FROM pm_preset_ids WHERE path = ?', [oldRel]);
    notifyListeners();
  }

  /// Drops the id cache entry of a deleted preset file.
  Future<void> forgetPmPresetPath(String rel) =>
      _database.rawDelete('DELETE FROM pm_preset_ids WHERE path = ?', [rel]);

  /// Reverse lookup: the local (relative) path a server preset id was cached
  /// under, if this device ever downloaded it.
  Future<String?> pmPathForPresetId(String presetId) async {
    final rows = await _database.rawQuery(
        'SELECT path FROM pm_preset_ids WHERE preset_id = ? LIMIT 1',
        [presetId]);
    return rows.isEmpty ? null : rows.first['path'] as String;
  }

  Future<void> cachePmPresetIds(Map<String, String> byPath) async {
    if (byPath.isEmpty) return;
    final batch = _database.batch();
    byPath.forEach((path, id) {
      batch.rawInsert(
          'INSERT INTO pm_preset_ids (path, preset_id) VALUES (?, ?) '
          'ON CONFLICT(path) DO UPDATE SET preset_id = excluded.preset_id',
          [path, id]);
    });
    await batch.commit(noResult: true);
  }

  /// Records which account playlist a local one is backed by, and WHICH SERVER
  /// VERSION it was last made identical to. [serverId] null unlinks it.
  ///
  /// [serverUpdatedAt] is the account copy's own `updated_at`, not this
  /// device's clock: the two are compared later to decide whether a playlist
  /// still needs pulling, and comparing a server microsecond timestamp with a
  /// local wall clock truncated to the second never matched (measured — every
  /// sync re-downloaded every entry). Null = "not known to be in sync", which
  /// makes the next pull fetch it once.
  Future<void> setPlaylistServerLink(String id, String? serverId,
      {DateTime? serverUpdatedAt}) async {
    await _database.update(
      'playlists',
      {
        'server_id': serverId,
        'synced_at': serverId == null || serverUpdatedAt == null
            ? null
            : serverUpdatedAt.millisecondsSinceEpoch ~/ 1000,
        // Kept verbatim: this one goes back to the server as
        // p_if_unmodified_since and must not lose a microsecond.
        'server_version': serverId == null || serverUpdatedAt == null
            ? null
            : serverUpdatedAt.toUtc().toIso8601String(),
      },
      where: 'id = ?', whereArgs: [id],
    );
    notifyListeners();
  }

  /// One playlist, fresh from the table. A screen holding a playlist SNAPSHOT
  /// (its constructor argument) shows a stale name and a stale sync state after
  /// its own options menu renamed or backed it up — this is how it re-reads.
  Future<UserPlaylist?> playlistById(String id) async {
    final rows = await _database
        .query('playlists', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return UserPlaylist.fromMap(rows.first);
  }

  /// Local playlist already linked to [serverId], if any — how a pull avoids
  /// re-creating a playlist that is simply already here.
  Future<UserPlaylist?> playlistByServerId(String serverId) async {
    final rows = await _database.query('playlists',
        where: 'server_id = ?', whereArgs: [serverId], limit: 1);
    if (rows.isEmpty) return null;
    return UserPlaylist.fromMap(rows.first);
  }

  /// Appends entries built from a REMOTE playlist: each one carries its own
  /// snapshot and is bound to a local `tracks` row only if [PlaylistEntry.track]
  /// was resolved by the caller. An entry whose file is not on this device is
  /// stored exactly like any missing entry — that is the whole point.
  /// [touch] false when the entries come FROM the account: applying what the
  /// server already has is not a local change, and bumping `updated_at` there
  /// made the next sync believe the playlist needed re-uploading — which
  /// cleared the "in sync" marker and forced another pull, on every run.
  Future<void> appendPlaylistEntries(
      String playlistId, List<PlaylistEntry> entries,
      {bool touch = true}) async {
    if (entries.isEmpty) return;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _database.transaction((txn) async {
      final maxRow = await txn.rawQuery(
          'SELECT COALESCE(MAX(position), 0) AS m FROM playlist_tracks '
          'WHERE playlist_id = ?', [playlistId]);
      var pos = ((maxRow.first['m'] as num?) ?? 0).toDouble();
      for (final e in entries) {
        pos += 1;
        await txn.insert('playlist_tracks', {
          'playlist_id': playlistId,
          'track_id':    e.track?.id,
          'position':    pos,
          'added_at':    nowSec,
          'song_id':     e.songId,
          'file_path':   e.track?.filePath ?? e.filePath,
          'rel_path':    e.relPath,
          'entry_path':  e.entryPath,
          'subsong_idx': e.subsongIdx,
          'title':       e.title,
          'artist':      e.artist,
          'album':       e.album,
          'album_id':    e.albumId,
          'format_ext':  e.formatExt,
          'duration_s':  e.durationS,
        });
      }
      if (touch) {
        await txn.update('playlists', {'updated_at': nowSec},
            where: 'id = ?', whereArgs: [playlistId]);
      }
    });
    notifyListeners();
  }

  /// True when a `tracks` row exists for this catalogue tune — what decides
  /// whether a pulled library entry is actually VISIBLE (every library screen
  /// reads through that table).
  /// The `#%` arm matches a container subsong: those rows carry the SYNTHETIC
  /// id '<uuid>#<i>' minted by expandContainerAlbum, while the server only ever
  /// knows the container's uuid. Without it a pulled favourite looked absent
  /// and minted a SECOND, duplicate row for a tune already on the device.
  Future<bool> hasTrackFor(String songId, int subsongIdx) async {
    final rows = await _database.query('tracks',
        columns: ['id'],
        where: '(online_id = ? OR online_id LIKE ?) AND subsong_idx = ?',
        whereArgs: [songId, '$songId#%', subsongIdx],
        limit: 1);
    return rows.isNotEmpty;
  }

  /// Toutes les identités catalogue présentes dans `tracks`, sous la forme
  /// SERVEUR `<uuid>#<sous-chanson>` — la même que celle sur laquelle
  /// [trackByOnlineIdAndSubsong] apparie, les deux formes comprises: un uuid nu
  /// avec sa colonne `subsong_idx`, et le `<uuid>#<rang>` synthétique fabriqué
  /// par l'expansion d'un conteneur.
  ///
  /// Une requête pour toute la table: la comparaison qui l'utilise tourne sur
  /// la photo entière du compte, et un aller-retour par entrée y coûterait des
  /// centaines de requêtes.
  Future<Set<String>> catalogueTrackKeys() async {
    final rows = await _database.query('tracks',
        columns: ['online_id', 'subsong_idx'],
        // Guillemets SIMPLES: en SQLite `""` est un IDENTIFIANT, pas une
        // chaîne vide — la requête échouait sur « no such column: "" ».
        where: "online_id IS NOT NULL AND online_id <> ''");
    final keys = <String>{};
    for (final r in rows) {
      final id = r['online_id'] as String;
      keys.add(id);                                   // forme synthétique
      keys.add('$id#${(r['subsong_idx'] as int?) ?? 0}');
    }
    return keys;
  }

  /// Where a file described by an out-of-catalogue snapshot WOULD live on this
  /// device: under the app base directory when the snapshot carries an
  /// app-relative path, else in a neutral local folder. The file need not
  /// exist — the entry is shown as missing until it does.
  Future<String> expectedPathFor(
      {String? relPath, required String fileName}) async {
    final base = (await _appBaseDir()).path;
    if (relPath != null && relPath.isNotEmpty) return p.join(base, relPath);
    return p.join(base, 'local', fileName);
  }

  /// The library ref_id already held for [songId], whatever its subsong scope
  /// ('<id>' or '<id>?subsong=N'). Null when this song is not in the library.
  ///
  /// The server only knows the BARE song id, while a favourite made in the app
  /// is subsong-scoped: inserting the pulled row blindly produced TWO library
  /// entries for one tune (verified: "Memento Mori" as both '…abb9?subsong=0'
  /// and '…abb9'). The local, more precise form wins until the server can carry
  /// the subsong index.
  /// The `#%` arm is the container-subsong form ('<uuid>#<i>?subsong=N'): the
  /// server carries the container's uuid alone, so without it the pulled row
  /// created a SECOND library entry beside the one the device already had.
  ///
  /// ⚠️ [subsongIdx] n'est pas décoratif. Le compte peut tenir PLUSIEURS lignes
  /// pour un même uuid — une par sous-chanson, et c'est la règle pour un album
  /// conteneur dont toutes les pistes partagent l'identité du fichier. Sans le
  /// préciser, la recherche large ramenait la même entrée locale pour toutes:
  /// la dernière ligne appliquée écrasait les précédentes, si bien qu'un ♥
  /// posé sur une sous-chanson s'ÉTEIGNAIT quelques secondes plus tard, à la
  /// synchro suivante, quand une ligne sœur `favourite: false` passait par là.
  /// La forme large ne sert donc plus que de repli, et seulement pour la
  /// sous-chanson 0 (les entrées héritées, keyées sur l'uuid nu).
  Future<String?> libraryRefIdForSong(String songId, {int? subsongIdx}) async {
    Future<String?> exact(List<String> forms) async {
      final marks = List.filled(forms.length, '?').join(',');
      final rows = await _database.query('library_items',
          columns: ['ref_id'],
          where: "type = 'track' AND ref_id IN ($marks)",
          whereArgs: forms,
          limit: 1);
      return rows.isEmpty ? null : rows.first['ref_id'] as String?;
    }

    if (subsongIdx != null) {
      final hit = await exact([
        '$songId?subsong=$subsongIdx',
        // Forme conteneur: le `#N` PORTE la sous-chanson, et la clé locale la
        // redouble d'un `?subsong=0` (le fichier de la piste n'a qu'une piste).
        '$songId#$subsongIdx?subsong=0',
        '$songId#$subsongIdx?subsong=$subsongIdx',
        '$songId#$subsongIdx',
      ]);
      if (hit != null) return hit;
      if (subsongIdx != 0) return null;   // pas de repli large hors sous-chanson 0
    }
    final rows = await _database.query('library_items',
        columns: ['ref_id'],
        where: "type = 'track' "
            "AND (ref_id = ? OR ref_id LIKE ? OR ref_id LIKE ?)",
        whereArgs: [songId, '$songId?subsong=%', '$songId#%'],
        limit: 1);
    return rows.isEmpty ? null : rows.first['ref_id'] as String?;
  }

  /// Binds ONE playlist entry to a local track row (a file that just arrived).
  /// Same write [getPlaylistEntryRefs] does when it re-resolves, exposed so a
  /// download can un-grey its row immediately instead of waiting for a reload
  /// of the whole list.
  Future<void> bindPlaylistEntry(int rowId, TrackRecord track) async {
    await _database.update(
      'playlist_tracks',
      {
        'track_id':  track.id,
        'file_path': track.filePath,
        'rel_path':  await _relPathOf(track.filePath),
      },
      where: 'id = ?', whereArgs: [rowId],
    );
    // No notifyListeners: the caller is updating its own row, and a global
    // refresh mid-download would rebuild the list under the user's finger.
  }

  /// Drops every entry of a playlist, keeping the playlist itself (a pull that
  /// overwrites local content with the account's).
  /// Used by the PULL: replacing local content with the account's is not a
  /// local change, so nothing is marked dirty here.
  Future<void> clearPlaylistEntries(String playlistId) async {
    await _database.delete('playlist_tracks',
        where: 'playlist_id = ?', whereArgs: [playlistId]);
    notifyListeners();
  }

  /// Resolves the local file of an entry described only by its snapshot
  /// (typically one that just came down from the account). Same order as
  /// [_resolvePlaylistEntry]; null when the file is not on this device.
  /// [fileName] is the last resort and it matters: a snapshot pushed before the
  /// paths were carried has ONLY a name, and without this the pull could not
  /// tell the file was already on the device — it minted a second row under the
  /// computed `local/<name>` path, so one tune appeared twice in the library
  /// (one copy starred with its artwork, one bare).
  Future<TrackRecord?> findTrackForSnapshot({
    String? songId,
    String? filePath,
    String? relPath,
    String? fileName,
    String entryPath = '',
    int subsongIdx = 0,
  }) =>
      _resolvePlaylistEntry({
        'song_id':     songId,
        'file_path':   filePath,
        'rel_path':    relPath,
        'file_name':   fileName,
        'entry_path':  entryPath,
        'subsong_idx': subsongIdx,
      });

  Future<void> renamePlaylist(String id, String name) async {
    // updated_at moves too: it is what tells the sync this playlist has to be
    // re-uploaded.
    await _database.update(
        'playlists',
        {'name': name,
         'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000},
        where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    await _database.delete('playlist_tracks',
        where: 'playlist_id = ?', whereArgs: [id]);
    await _database.delete('playlists', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  /// Deletes a folder; its sub-folders and playlists move to the parent.
  Future<void> deletePlaylistFolder(String id) async {
    final rows = await _database.query('playlist_folders',
        columns: ['parent_id'], where: 'id = ?', whereArgs: [id]);
    final parent = rows.isNotEmpty ? rows.first['parent_id'] as String? : null;
    await _database.update('playlist_folders', {'parent_id': parent},
        where: 'parent_id = ?', whereArgs: [id]);
    await _database.update('playlists', {'folder_id': parent},
        where: 'folder_id = ?', whereArgs: [id]);
    // Saved server playlists in this folder move up to the parent too.
    await _database.update('library_items', {'folder_id': parent},
        where: 'folder_id = ?', whereArgs: [id]);
    await _database.delete('playlist_folders', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  /// Recursively counts what a folder holds across its WHOLE subtree:
  /// (subfolders, playlists) where playlists = local + saved server playlists.
  /// Ids of [folderId] and every descendant folder (the whole subtree).
  Future<List<String>> _folderSubtreeIds(String folderId) async {
    final all = await getAllPlaylistFolders();
    final byParent = <String?, List<String>>{};
    for (final f in all) {
      (byParent[f.parentId] ??= <String>[]).add(f.id);
    }
    final out = <String>[folderId];
    var i = 0;
    while (i < out.length) {
      out.addAll(byParent[out[i]] ?? const <String>[]);
      i++;
    }
    return out;
  }

  Future<(int subfolders, int playlists)> countFolderContents(
      String folderId) async {
    final scope = await _folderSubtreeIds(folderId);
    final ph = List.filled(scope.length, '?').join(',');
    int one(List<Map<String, Object?>> rows) =>
        (rows.first.values.first as int?) ?? 0;
    final local = one(await _database.rawQuery(
        'SELECT COUNT(*) FROM playlists WHERE folder_id IN ($ph)', scope));
    final server = one(await _database.rawQuery(
        "SELECT COUNT(*) FROM library_items "
        'WHERE type = ? AND folder_id IN ($ph)',
        ['playlist', ...scope]));
    // scope includes the folder itself → subtree size minus 1 = sub-folders.
    return (scope.length - 1, local + server);
  }

  /// Deletes a folder AND its entire subtree: every descendant folder, every
  /// local playlist in it (with their entries), and every saved server playlist
  /// in it. (Contrast with [deletePlaylistFolder], which reparents instead.)
  Future<void> deletePlaylistFolderRecursive(String folderId) async {
    final ids = await _folderSubtreeIds(folderId);
    if (ids.isEmpty) return;
    final ph = List.filled(ids.length, '?').join(',');
    await _database.transaction((txn) async {
      await txn.rawDelete(
        'DELETE FROM playlist_tracks WHERE playlist_id IN '
        '(SELECT id FROM playlists WHERE folder_id IN ($ph))', ids);
      await txn.rawDelete('DELETE FROM playlists WHERE folder_id IN ($ph)', ids);
      await txn.rawDelete(
        'DELETE FROM library_items WHERE type = ? AND folder_id IN ($ph)',
        ['playlist', ...ids]);
      await txn.rawDelete('DELETE FROM playlist_folders WHERE id IN ($ph)', ids);
    });
    notifyListeners();
  }

  /// Rename a playlist folder.
  Future<void> renamePlaylistFolder(String id, String name) async {
    await _database.update('playlist_folders', {'name': name},
        where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  /// Move a LOCAL playlist into [folderId] (null = root).
  /// Files a playlist into [folderId] (null = root).
  ///
  /// [changedAt] (epoch seconds) is when that decision was MADE — the sync
  /// passes the remote timestamp when it applies someone else's move, so this
  /// device does not then look like the most recent author and win the next
  /// merge with a decision it merely received.
  Future<void> movePlaylistToFolder(String playlistId, String? folderId,
      {int? changedAt}) async {
    await _database.update(
        'playlists',
        {
          'folder_id': folderId,
          'folder_changed_at':
              changedAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
        where: 'id = ?', whereArgs: [playlistId]);
    notifyListeners();
  }

  /// Move a saved SERVER playlist (library_items) into [folderId] (null = root).
  Future<void> setLibraryItemFolder(
      String type, String refId, String? folderId, {int? changedAt}) async {
    await _database.update(
        'library_items',
        {
          'folder_id': folderId,
          'folder_changed_at':
              changedAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
        where: 'type = ? AND ref_id = ?', whereArgs: [type, refId]);
    notifyListeners();
  }

  /// Un-favourite every favourite (they stay in the library — favourite ⊆
  /// library). Clears the flag on both the library_items rows getFavorites reads
  /// and the tracks table.
  Future<void> clearAllFavorites() async {
    await _database.rawUpdate(
        'UPDATE library_items SET is_favorite = 0, favorited_at = NULL '
        'WHERE is_favorite = 1');
    await _database.rawUpdate(
        'UPDATE tracks SET is_favorite = 0 WHERE is_favorite = 1');
    notifyListeners();
  }

  /// Persist a new entry order for a playlist: [rowIdsInOrder] are playlist_track
  /// row ids in the desired sequence → rewritten to positions 1..N.
  Future<void> setPlaylistEntryOrder(
      String playlistId, List<int> rowIdsInOrder) async {
    await _database.transaction((txn) async {
      for (var i = 0; i < rowIdsInOrder.length; i++) {
        await txn.update('playlist_tracks', {'position': (i + 1).toDouble()},
            where: 'playlist_id = ? AND id = ?',
            whereArgs: [playlistId, rowIdsInOrder[i]]);
      }
      // A reorder can never go out as an append.
      await txn.update(
          'playlists',
          {
            'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'dirty_kind': 'full',
          },
          where: 'id = ?', whereArgs: [playlistId]);
    });
    notifyListeners();
  }

  /// How many of [trackIds] are already present in ANY of [playlistIds]
  /// (counted once per (playlist, track) pair — drives the duplicate prompt).
  Future<int> countTracksAlreadyInPlaylists(
      List<String> playlistIds, List<String> trackIds) async {
    if (playlistIds.isEmpty || trackIds.isEmpty) return 0;
    final pq = List.filled(playlistIds.length, '?').join(',');
    final tq = List.filled(trackIds.length, '?').join(',');
    final rows = await _database.rawQuery(
      'SELECT COUNT(DISTINCT playlist_id || \'|\' || track_id) AS n '
      'FROM playlist_tracks WHERE playlist_id IN ($pq) AND track_id IN ($tq)',
      [...playlistIds, ...trackIds],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Appends [trackIds] (tracks.id) to every playlist in [playlistIds], at the
  /// end. Duplicates are allowed (a playlist can hold several instances of a
  /// track); [skipDuplicates] instead ignores tracks already present in that
  /// playlist.
  Future<void> addTracksToPlaylists(
      List<String> playlistIds, List<String> trackIds,
      {bool skipDuplicates = false}) async {
    if (playlistIds.isEmpty || trackIds.isEmpty) return;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _database.transaction((txn) async {
      for (final pid in playlistIds) {
        Set<String> existing = const {};
        if (skipDuplicates) {
          final rows = await txn.rawQuery(
              'SELECT DISTINCT track_id FROM playlist_tracks WHERE playlist_id = ?',
              [pid]);
          existing = {for (final r in rows) r['track_id'] as String};
        }
        final maxRow = await txn.rawQuery(
            'SELECT COALESCE(MAX(position), 0) AS m FROM playlist_tracks '
            'WHERE playlist_id = ?', [pid]);
        var pos = ((maxRow.first['m'] as num?) ?? 0).toDouble();
        for (final tid in trackIds) {
          if (skipDuplicates && existing.contains(tid)) continue;
          pos += 1;
          // The snapshot is taken NOW, from the tracks row, so the entry keeps
          // meaning something after that row is gone.
          await txn.rawInsert(
            '''INSERT INTO playlist_tracks
               (playlist_id, track_id, position, added_at,
                song_id, file_path, rel_path, entry_path, subsong_idx,
                title, artist, album, album_id, format_ext, duration_s)
               SELECT ?, t.id, ?, ?,
                      t.online_id, t.file_path, ?, t.entry_path, t.subsong_idx,
                      t.title, t.artist, t.meta_album, t.album_id,
                      t.format_ext, t.duration_s
               FROM tracks t WHERE t.id = ?''',
            [pid, pos, nowSec, await _relPathOfTrack(txn, tid), tid],
          );
        }
        await txn.rawUpdate(
            'UPDATE playlists SET updated_at = ?, '
            "dirty_kind = CASE WHEN COALESCE(dirty_kind, 'append') = 'append' "
            "THEN 'append' ELSE 'full' END WHERE id = ?",
            [nowSec, pid]);
      }
    });
    notifyListeners();
  }

  /// Removes ONE playlist entry by its row id (duplicates allowed → the
  /// track_id alone no longer identifies a row).
  Future<void> removePlaylistEntry(String playlistId, int entryRowId) async {
    await _database.delete('playlist_tracks',
        where: 'playlist_id = ? AND id = ?',
        whereArgs: [playlistId, entryRowId]);
    await _touchPlaylist(playlistId);
    notifyListeners();
  }

  /// Marks a playlist as changed NOW — what makes the sync re-upload it.
  /// [append] true when the change was an addition at the END and nothing else:
  /// the push can then send only the new entries instead of the whole list. Any
  /// other change (removal, reorder) forces a full replacement, and once a
  /// playlist is 'full' it stays so until it has been pushed.
  Future<void> _touchPlaylist(String playlistId, {bool append = false}) async {
    await _database.rawUpdate(
        'UPDATE playlists SET updated_at = ?, '
        "dirty_kind = CASE WHEN ? = 1 AND COALESCE(dirty_kind, 'append') = 'append' "
        "THEN 'append' ELSE 'full' END "
        'WHERE id = ?',
        [DateTime.now().millisecondsSinceEpoch ~/ 1000, append ? 1 : 0,
         playlistId]);
  }

  /// Records what the account copy now holds after a successful push.
  Future<void> setPlaylistPushedState(String playlistId,
      {required int localUpdatedAt, required int entryCount}) async {
    await _database.update(
        'playlists',
        {
          'pushed_at': localUpdatedAt,
          'pushed_count': entryCount,
          'dirty_kind': null,
        },
        where: 'id = ?', whereArgs: [playlistId]);
  }

  /// Entries beyond [from] (0-based), in order — the tail an incremental push
  /// sends.
  Future<List<PlaylistEntry>> playlistEntriesFrom(
      String playlistId, int from) async {
    final all = await getPlaylistEntryRefs(playlistId);
    return from <= 0 || from >= all.length ? all : all.sublist(from);
  }

  // ── Sync outbox ───────────────────────────────────────────────────────────

  /// Queues a library change for the server. The row REPLACES any pending
  /// change on the same item: the user's last gesture is the truth, and
  /// delivering "added" then "removed" separately would just race.
  Future<void> queueLibraryChange({
    required String itemType, // song | album | playlist
    required String itemId,   // server uuid, '' for an out-of-catalogue file
    required bool value,
    int subsongIdx = 0,
    String? extKey,
    String? extRef,
    /// null = ce geste ne touche pas au ♥ (c'est une appartenance).
    /// true/false = le geste EST un ♥, et `value` ne partira pas au serveur
    /// (voir SyncService._drainOutbox).
    bool? favourite,
  }) async {
    await _database.insert(
      'sync_outbox',
      {
        'kind':        'library',
        'item_type':   itemType,
        'item_id':     itemId,
        'subsong_idx': subsongIdx,
        'ext_key':     extKey,
        'ext_ref':     extRef,
        'value':       value ? 1 : 0,
        'favourite':   favourite == null ? null : (favourite ? 1 : 0),
        'changed_at':  DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'attempts':    0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> pendingSyncChanges({int limit = 200}) =>
      _database.query('sync_outbox',
          orderBy: 'changed_at ASC, id ASC', limit: limit);

  /// Pending change on this exact item, if any (arbitration: a queued gesture
  /// older than the server's version must not be replayed on top of it).
  Future<Map<String, Object?>?> pendingChangeFor({
    required String itemType,
    String? itemId,
    String? extKey,
    int subsongIdx = 0,
  }) async {
    final rows = await _database.query(
      'sync_outbox',
      where: extKey != null && extKey.isNotEmpty
          ? 'item_type = ? AND ext_key = ?'
          : 'item_type = ? AND item_id = ? AND subsong_idx = ?',
      whereArgs: extKey != null && extKey.isNotEmpty
          ? [itemType, extKey]
          : [itemType, itemId ?? '', subsongIdx],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> deleteSyncChange(int id) async {
    await _database.delete('sync_outbox', where: 'id = ?', whereArgs: [id]);
  }

  /// Marks a failed attempt (kept for the next run — a change is only dropped
  /// once the server has taken it).
  Future<void> bumpSyncAttempts(int id) async {
    await _database.rawUpdate(
        'UPDATE sync_outbox SET attempts = attempts + 1 WHERE id = ?', [id]);
  }

  /// Changes waiting to be delivered — including favourites on the user's own
  /// files, which the server now takes as ext_key/ext_ref.
  Future<int> pendingSyncCount() async {
    final rows = await _database.rawQuery('SELECT COUNT(*) AS n FROM sync_outbox');
    return (rows.first['n'] as int?) ?? 0;
  }

  // ── Ext play outbox (log_plays_ext, migration 44) ─────────────────────────

  /// Queues one LOCAL-file play for delivery. An event is a fact, never
  /// replaced: no unique index — the server's PK (user, ext_key, played_at)
  /// makes a replayed batch idempotent.
  /// [playEventId] = la ligne `play_events` que cette écoute duplique
  /// localement; la livraison du lot la passe à `pushed = 1` pour que l'écran
  /// Stats ne la compte pas deux fois (une fois en local, une fois dans le
  /// miroir du compte).
  Future<void> queueExtPlay({
    required String extKey,
    String? extRef,
    required int durationMs,
    required int playedAtEpochS,
    int? playEventId,
    String? backend,
  }) async {
    await _database.insert('ext_play_outbox', {
      'ext_key':       extKey,
      'ext_ref':       extRef,
      'duration_ms':   durationMs,
      'played_at':     playedAtEpochS,
      'attempts':      0,
      'play_event_id': playEventId,
      'backend':       backend,
    });
  }

  Future<List<Map<String, Object?>>> pendingExtPlays({int limit = 500}) =>
      _database.query('ext_play_outbox',
          orderBy: 'played_at ASC, id ASC', limit: limit);

  Future<void> deleteExtPlays(List<int> ids) async {
    if (ids.isEmpty) return;
    final marks = List.filled(ids.length, '?').join(',');
    await _database
        .rawDelete('DELETE FROM ext_play_outbox WHERE id IN ($marks)', ids);
  }

  Future<void> bumpExtPlayAttempts(List<int> ids) async {
    if (ids.isEmpty) return;
    final marks = List.filled(ids.length, '?').join(',');
    await _database.rawUpdate(
        'UPDATE ext_play_outbox SET attempts = attempts + 1 '
        'WHERE id IN ($marks)', ids);
  }

  // ── Server play-stats application (user_play_stats) ───────────────────────

  /// The local track a CATALOGUE play-stat row refers to. Two id shapes exist
  /// (see catalogueSongId): a bare uuid with its own subsong_idx column, and
  /// the synthetic 'uuid#N' minted by container expansion.
  Future<TrackRecord?> trackByOnlineIdAndSubsong(
      String songId, int subsongIdx) async {
    final rows = await _database.rawQuery(
      'SELECT * FROM tracks WHERE (online_id = ? AND subsong_idx = ?) '
      'OR online_id = ? LIMIT 1',
      [songId, subsongIdx, '$songId#$subsongIdx'],
    );
    return rows.isEmpty ? null : TrackRecord.fromMap(rows.first);
  }

  /// REPLACES a track's play counters with the server's (the server is
  /// authoritative — never add). last_played_at only moves FORWARD so a stale
  /// server cursor cannot rewind the recency used by "recently played".
  Future<void> setTrackPlayStats({
    required String trackId,
    required int playCount,
    required int lastPlayedAtEpochS,
  }) async {
    await _database.rawUpdate(
      'UPDATE tracks SET play_count = ?, '
      'last_played_at = MAX(COALESCE(last_played_at, 0), ?) WHERE id = ?',
      [playCount, lastPlayedAtEpochS, trackId],
    );
  }

  /// Inserts one raw play event (timeline replay on a new device). Deduped on
  /// (track_id, played_at): the replay runs on every first sync of an account
  /// and must not double the history already there. NB: the play_events insert
  /// trigger bumps tracks.play_count — the caller fixes counters afterwards
  /// with [setTrackPlayStats] (server-authoritative replace).
  /// [pushed] = cette écoute vient DÉJÀ du compte (rejeu de timeline), donc
  /// l'écran Stats la prend dans le miroir et pas ici — sans quoi elle
  /// compterait double.
  Future<void> insertPlayEventRaw({
    required String trackId,
    required int playedAtEpochS,
    int? playedMs,
    bool pushed = false,
  }) async {
    final dup = await _database.rawQuery(
        'SELECT 1 FROM play_events WHERE track_id = ? AND played_at = ? LIMIT 1',
        [trackId, playedAtEpochS]);
    if (dup.isNotEmpty) return;
    await _database.insert('play_events', {
      'track_id':  trackId,
      'played_at': playedAtEpochS,
      'played_ms': playedMs,
      'pushed':    pushed ? 1 : 0,
    });
  }

  // ── Miroir de la timeline du COMPTE (account_play_events, migration 45) ────
  //
  // Ce que le local seul ne peut pas dire: une écoute faite sur un AUTRE
  // appareil, et une écoute d'une piste absente d'ici (pas de ligne `tracks`
  // où l'accrocher). Le miroir porte l'identité SERVEUR et rien d'autre; les
  // noms viennent de `account_track_meta` ou de `tracks` quand la piste est là.

  /// Insère une page de timeline du compte. `INSERT OR IGNORE` sur la PK
  /// (identité + instant): le curseur est inclusif, donc chaque pull rejoue au
  /// moins une ligne déjà connue.
  Future<int> upsertAccountPlayEvents(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return 0;
    var added = 0;
    final batch = _database.batch();
    for (final r in rows) {
      batch.rawInsert(
        'INSERT OR IGNORE INTO account_play_events '
        '(kind, song_id, subsong_idx, ext_key, played_at, played_ms, backend) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [r['kind'], r['song_id'], r['subsong_idx'], r['ext_key'],
         r['played_at'], r['played_ms'], r['backend']],
      );
    }
    for (final res in await batch.commit(noResult: false)) {
      if (res is int && res > 0) added++;
    }
    if (added > 0) notifyListeners();
    return added;
  }

  /// Nom/album/pochette d'une piste du compte, pour l'afficher même absente
  /// d'ici. COALESCE par colonne: une passe qui ne sait qu'une partie des
  /// champs (le snapshot ext n'a pas de pochette) n'efface pas le reste.
  Future<void> upsertAccountTrackMeta({
    String songId = '',
    int subsongIdx = 0,
    String extKey = '',
    String? title,
    String? artist,
    String? album,
    String? albumId,
    String? artworkUrl,
    String? collection,
    String? platform,
    String? formatExt,
    double? durationS,
  }) async {
    await _database.rawInsert('''
      INSERT INTO account_track_meta
        (song_id, subsong_idx, ext_key, title, artist, album, album_id,
         artwork_url, collection, platform, format_ext, duration_s)
      VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
      ON CONFLICT (song_id, subsong_idx, ext_key) DO UPDATE SET
        title       = COALESCE(excluded.title,       account_track_meta.title),
        artist      = COALESCE(excluded.artist,      account_track_meta.artist),
        album       = COALESCE(excluded.album,       account_track_meta.album),
        album_id    = COALESCE(excluded.album_id,    account_track_meta.album_id),
        artwork_url = COALESCE(excluded.artwork_url, account_track_meta.artwork_url),
        collection  = COALESCE(excluded.collection,  account_track_meta.collection),
        platform    = COALESCE(excluded.platform,    account_track_meta.platform),
        format_ext  = COALESCE(excluded.format_ext,  account_track_meta.format_ext),
        duration_s  = COALESCE(excluded.duration_s,  account_track_meta.duration_s)
    ''', [songId, subsongIdx, extKey, title, artist, album, albumId,
          artworkUrl, collection, platform, formatExt, durationS]);
  }

  /// Y a-t-il des écoutes venues du compte ? Décide si l'écran Stats propose
  /// la vue fusionnée (« tous mes appareils »).
  Future<bool> hasAccountPlayEvents() async {
    final r = await _database
        .rawQuery('SELECT 1 FROM account_play_events LIMIT 1');
    return r.isNotEmpty;
  }

  /// Les pistes CATALOGUE du miroir qu'on ne sait pas encore nommer (ou
  /// créditer), les plus écoutées d'abord — sans elles l'écran Stats affiche
  /// un uuid en guise de titre.
  ///
  /// Y compris les pistes PRÉSENTES ici: la vue fusionnée lit l'arme du compte,
  /// pas la ligne locale (dont les écoutes sont déjà dans le miroir), donc les
  /// exclure laissait deux appareils avec des crédits différents selon ce que
  /// chacun avait téléchargé — 169 artistes contre 187 sur le même compte. La
  /// ligne locale ne sert que de REPLI d'affichage, jamais de source
  /// d'autorité: son crédit peut différer de celui du catalogue et ferait
  /// diverger les comptages.
  ///
  /// Un `artist` VIDE (et non null) veut dire « demandé, le catalogue n'en
  /// donne pas » — sans quoi on redemanderait à chaque passe.
  Future<List<(String, int)>> unnamedAccountSongs({int limit = 50}) async {
    final rows = await _database.rawQuery('''
      SELECT a.song_id AS song_id, a.subsong_idx AS subsong_idx,
             COUNT(*) AS plays
      FROM account_play_events a
      LEFT JOIN account_track_meta m
        ON m.song_id = a.song_id AND m.subsong_idx = a.subsong_idx
       AND m.ext_key = ''
      WHERE a.song_id != ''
        AND (m.title IS NULL OR m.artist IS NULL)
      GROUP BY a.song_id, a.subsong_idx
      ORDER BY plays DESC
      LIMIT ?
    ''', [limit]);
    return [
      for (final r in rows)
        ((r['song_id'] as String), (r['subsong_idx'] as int?) ?? 0),
    ];
  }

  /// Le plus ancien instant couvert par le miroir du compte (epoch s), null
  /// s'il est vide.
  Future<int?> accountPlayHistoryStart() async {
    final r = await _database
        .rawQuery('SELECT MIN(played_at) AS m FROM account_play_events');
    return (r.first['m'] as num?)?.toInt();
  }

  /// « Cet album a reçu sa liste complète » (voir `album_materialised`).
  Future<void> markAlbumMaterialised(String albumId, int trackCount) async {
    if (albumId.isEmpty) return;
    await _database.insert(
      'album_materialised',
      {
        'album_id':    albumId,
        'track_count': trackCount,
        'at':          DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Jette tous les marqueurs (cache): chaque album favori sera redemandé une
  /// fois. Voir `SyncService._healAlbumFavourites`.
  Future<void> clearAlbumMaterialised() =>
      _database.delete('album_materialised');

  Future<bool> isAlbumMaterialised(String albumId) async {
    if (albumId.isEmpty) return false;
    final r = await _database.query('album_materialised',
        where: 'album_id = ?', whereArgs: [albumId], limit: 1);
    return r.isNotEmpty;
  }

  /// Pose l'identité hors catalogue d'une piste (voir `tracks.ext_key`).
  Future<void> setTrackExtKey(String trackId, String extKey) async {
    await _database.rawUpdate(
        'UPDATE tracks SET ext_key = ? WHERE id = ? AND '
        '(ext_key IS NULL OR ext_key != ?)',
        [extKey, trackId, extKey]);
  }

  /// Rattrapage unique, au premier remplissage du miroir: les écoutes locales
  /// postérieures au début de la timeline du compte y sont DÉJÀ (elles ont été
  /// livrées à l'époque par log_play / log_plays_ext, avant que le marqueur
  /// `pushed` n'existe). Sans ce passage, la vue fusionnée les compterait deux
  /// fois.
  ///
  /// Le choix est délibérément prudent d'un seul côté: on préfère manquer une
  /// écoute (une livraison ratée, log_play est sans reprise) plutôt que d'en
  /// inventer une. Ce qui précède le début de la timeline reste local — c'est
  /// l'historique d'avant le compte.
  /// Sort de la vue fusionnée les écoutes qu'aucun envoi n'a jamais pu porter
  /// au compte, antérieures à [beforeEpochS] (= le démarrage de l'app, pour ne
  /// pas toucher la lecture en cours):
  ///
  ///  * `played_ms < 10 s` — sous la garde en dur de `_maybeFireLogPlay`: un
  ///    morceau sauté, jamais proposé;
  ///  * `played_ms IS NULL` — une lecture INTERROMPUE (app tuée, redémarrage à
  ///    chaud): le flush de fin n'a pas eu lieu, donc rien n'est parti et rien
  ///    ne partira. C'est ce qui laissait un morceau d'écart permanent entre
  ///    deux appareils quand la dernière écoute locale était de ce genre — la
  ///    règle de fenêtre ne l'attrape pas, puisqu'elle tombe APRÈS le dernier
  ///    instant connu du miroir et qu'aucune écoute plus récente ne viendra
  ///    l'y faire entrer.
  ///
  /// L'historique de cet appareil les garde: seule la fusion les ignore.
  Future<int> markShortPlaysOffAccount(int beforeEpochS) async {
    final n = await _database.rawUpdate(
        'UPDATE play_events SET pushed = 2 '
        'WHERE pushed = 0 AND played_at < ? '
        '  AND (played_ms IS NULL OR played_ms < 10000)',
        [beforeEpochS]);
    if (n > 0) notifyListeners();
    return n;
  }

  Future<int> markLocalPlaysPushedBefore(int fromEpochS) async {
    final n = await _database.rawUpdate(
        'UPDATE play_events SET pushed = 1 WHERE pushed = 0 AND played_at >= ?',
        [fromEpochS]);
    if (n > 0) notifyListeners();
    return n;
  }

  // ── Playlist entry resolution ─────────────────────────────────────────────

  /// Containers a downloaded song may be stored as: the row exists under the
  /// same online_id as the file extracted from it.
  static const _kArchiveExts = {'.zip', '.7z', '.rar', '.lha', '.lzh', '.rsn'};

  /// App base directory, cached. Same rule as RewampDb._baseDir (external
  /// storage on Android, documents elsewhere) — duplicated rather than imported
  /// to keep local_db free of a dependency on rewamp_db.
  Directory? _baseDirCache;
  Future<Directory> _appBaseDir() async {
    if (_baseDirCache != null) return _baseDirCache!;
    Directory? dir;
    if (Platform.isAndroid) {
      try {
        dir = await getExternalStorageDirectory();
      } catch (_) {}
    }
    dir ??= await getApplicationDocumentsDirectory();
    return _baseDirCache = dir;
  }

  /// Path relative to the app base directory, or null when the file lives
  /// outside it (a user file opened in place). An absolute path is worthless
  /// after an iOS reinstall — the container UUID changes — so the relative form
  /// is what makes an entry survive.
  /// App-relative form of an absolute path (null when it is outside the app
  /// tree) — what a snapshot must carry for another device, or the round trip
  /// cannot tell the file is already here. Public: the library button needs it
  /// when it pushes a favourite that has no catalogue identity.
  Future<String?> relPathOf(String? absolute) => _relPathOf(absolute);

  Future<String?> _relPathOf(String? absolute) async {
    if (absolute == null || absolute.isEmpty) return null;
    final base = (await _appBaseDir()).path;
    if (!p.isWithin(base, absolute)) return null;
    return p.relative(absolute, from: base);
  }

  Future<String?> _relPathOfTrack(DatabaseExecutor db, String trackId) async {
    final rows = await db.query('tracks',
        columns: ['file_path'], where: 'id = ?', whereArgs: [trackId], limit: 1);
    if (rows.isEmpty) return null;
    return _relPathOf(rows.first['file_path'] as String?);
  }

  /// Finds the local row an entry refers to, and repairs the binding when the
  /// file moved. Order matters: the exact path first, then the app-relative
  /// path (survives a reinstall / container change), then the file name as a
  /// last resort — and only when it is UNAMBIGUOUS, so a same-named file from
  /// another album can never be silently substituted.
  Future<TrackRecord?> _resolvePlaylistEntry(Map<String, Object?> row) async {
    Future<TrackRecord?> byQuery(String where, List<Object?> args) async {
      final rows = await _database.query('tracks',
          where: where, whereArgs: args, limit: 2);
      if (rows.length != 1) return null;
      return TrackRecord.fromMap(rows.first);
    }

    final entryPath  = (row['entry_path'] as String?) ?? '';
    final subsongIdx = (row['subsong_idx'] as int?) ?? 0;

    // Catalogue id FIRST: a re-downloaded tune lands under a path derived from
    // its metadata, which has nothing to do with the path the entry was created
    // with (another device, another album layout). Without this, downloading a
    // missing entry left it missing.
    //
    // Several tracks rows CAN share one online_id — a downloaded archive and
    // the file extracted out of it are both "that song" (jabas.zip and
    // "Sual - Manifestacion MASTER.mp3"). Requiring a unique match here left
    // every such entry marked missing even once its file was on disk. The id is
    // the identity, so ambiguity is resolved by preferring a real audio file
    // over the container it came in.
    final songId = row['song_id'] as String?;
    if (songId != null && songId.isNotEmpty) {
      // ⚠️ DEUX formes d'identité locale pour la MÊME piste, et il faut les
      // deux (même règle que `trackByOnlineIdAndSubsong` et que la jointure de
      // `getLibraryItems`): l'uuid NU avec sa colonne `subsong_idx`, et le
      // `uuid#N` synthétique que fabrique l'expansion d'un conteneur. Une
      // entrée de playlist porte la SECONDE (c'est ainsi qu'un conteneur
      // survit d'un appareil à l'autre), alors qu'un `.rsn` joué en place a
      // ses lignes sous la PREMIÈRE — l'entrée ne retrouvait donc rien,
      // s'annonçait « fichier absent » et relançait un téléchargement complet
      // d'un album déjà sur le disque, à chaque lecture.
      final bare = songId.split('#').first;
      final rows = await _database.query('tracks',
          where: '(online_id = ? OR online_id = ?) AND subsong_idx = ?',
          whereArgs: [songId, bare, subsongIdx]);
      TrackRecord? archive;
      for (final r in rows) {
        final rec = TrackRecord.fromMap(r);
        if (!await File(rec.filePath).exists()) continue;
        if (_kArchiveExts.contains(p.extension(rec.filePath).toLowerCase())) {
          archive ??= rec;
          continue;
        }
        return rec;
      }
      if (archive != null) return archive;
    }

    final filePath = row['file_path'] as String?;
    if (filePath != null && filePath.isNotEmpty) {
      final t = await byQuery(
          'file_path = ? AND entry_path = ? AND subsong_idx = ?',
          [filePath, entryPath, subsongIdx]);
      if (t != null && await File(t.filePath).exists()) return t;
    }

    final relPath = row['rel_path'] as String?;
    if (relPath != null && relPath.isNotEmpty) {
      final abs = p.join((await _appBaseDir()).path, relPath);
      final t = await byQuery(
          'file_path = ? AND entry_path = ? AND subsong_idx = ?',
          [abs, entryPath, subsongIdx]);
      if (t != null && await File(t.filePath).exists()) return t;
    }

    final name = (filePath != null && filePath.isNotEmpty)
        ? p.basename(filePath)
        : (relPath != null && relPath.isNotEmpty
            ? p.basename(relPath)
            // A snapshot with neither path still carries its file name (see
            // findTrackForSnapshot).
            : row['file_name'] as String?);
    if (name != null) {
      final t = await byQuery(
          "file_path LIKE ? ESCAPE '\\' AND entry_path = ? AND subsong_idx = ?",
          ['%/${name.replaceAll('%', r'\%')}', entryPath, subsongIdx]);
      if (t != null && await File(t.filePath).exists()) return t;
    }

    // ADOPT: no `tracks` row for THIS subsong — but the FILE may well be here.
    //
    // Every lookup above needs a row to exist, and a playlist that came from
    // the account has none for its entries: the sync brings the playlist, not
    // the rows. So a subsong of a container already on disk (the other subsongs
    // of the same file were played, hence THEIR rows) showed as "to download"
    // while its audio sat right there — and playing it created the missing rows,
    // which is why several entries un-greyed at once. Mint the row from the
    // entry's own snapshot and the entry is simply present.
    Future<TrackRecord?> adoptAt(String path) async {
      final id = await upsertTrack(
        filePath:   path,
        entryPath:  entryPath,
        subsongIdx: subsongIdx,
        title:      row['title']  as String?,
        artist:     row['artist'] as String?,
        metaAlbum:  row['album']  as String?,
        // Carried by the entry since migration 38 — the adopted row is born
        // with its album, so the player's link works on the FIRST play and the
        // catalogue backfill has nothing left to ask for.
        albumId:    row['album_id'] as String?,
        durationS:  (row['duration_s'] as num?)?.toDouble(),
        formatExt:  row['format_ext'] as String?,
        source:     (songId != null && songId.isNotEmpty) ? 'online' : 'local',
        onlineId:   songId,
      );
      return getTrackById(id);
    }

    // A SIBLING SUBSONG of the same file counts as "the file is here".
    //
    // Every lookup above is scoped to this entry's subsong, and the snapshot
    // path an account-restored entry carries is the one it was created with —
    // a download of the same tune lands under a path derived from ITS metadata
    // and can differ. So on a playlist made of the subsongs of ONE module,
    // playing the first entry left the other twenty marked "to download" with
    // their audio already on disk: only subsong 0 had a row, and no snapshot
    // path resolved. The identity (`online_id`) and the file path both
    // designate the FILE, never one subsong of it — so a sibling's row tells us
    // where the file is, and we mint OUR OWN row at that path. Returning the
    // sibling itself would bind the entry to the wrong subsong.
    Future<TrackRecord?> siblingFile() async {
      for (final q in <(String, List<Object?>)>[
        if (songId != null && songId.isNotEmpty)
          ('online_id = ? AND subsong_idx != ?', [songId, subsongIdx]),
        if (filePath != null && filePath.isNotEmpty)
          ('file_path = ? AND subsong_idx != ?', [filePath, subsongIdx]),
      ]) {
        final rows = await _database.query('tracks',
            where: q.$1, whereArgs: q.$2, limit: 8);
        for (final r in rows) {
          final rec = TrackRecord.fromMap(r);
          // An archive is not the audio file (see the online_id block above).
          if (_kArchiveExts.contains(p.extension(rec.filePath).toLowerCase())) {
            continue;
          }
          if (await File(rec.filePath).exists()) return adoptAt(rec.filePath);
        }
      }
      return null;
    }

    for (final cand in <String>[
      if (filePath != null && filePath.isNotEmpty) filePath,
      if (relPath != null && relPath.isNotEmpty)
        p.join((await _appBaseDir()).path, relPath),
    ]) {
      if (!await File(cand).exists()) continue;
      final t = await adoptAt(cand);
      if (t != null) return t;
    }
    return siblingFile();
  }

  /// Entries of a playlist, in order — missing ones INCLUDED.
  ///
  /// Re-binds an entry that found its file again (track_id + the path snapshot
  /// are refreshed), so a re-downloaded or re-copied file simply works on the
  /// next open.
  Future<List<PlaylistEntry>> getPlaylistEntryRefs(String playlistId) async {
    final rows = await _database.rawQuery('''
      SELECT * FROM playlist_tracks
      WHERE playlist_id = ?
      ORDER BY position ASC
    ''', [playlistId]);

    final out = <PlaylistEntry>[];
    for (final row in rows) {
      final rowId   = row['id'] as int;
      final trackId = row['track_id'] as String?;
      TrackRecord? track;

      if (trackId != null) {
        final t = await _database.query('tracks',
            where: 'id = ?', whereArgs: [trackId], limit: 1);
        if (t.isNotEmpty) {
          final rec = TrackRecord.fromMap(t.first);
          if (await File(rec.filePath).exists()) track = rec;
        }
      }
      track ??= await _resolvePlaylistEntry(row);

      if (track != null && track.id != trackId) {
        await _database.update(
          'playlist_tracks',
          {
            'track_id':   track.id,
            'file_path':  track.filePath,
            'rel_path':   await _relPathOf(track.filePath),
          },
          where: 'id = ?', whereArgs: [rowId],
        );
      }

      out.add(PlaylistEntry(
        rowId:      rowId,
        track:      track,
        songId:     row['song_id']    as String?,
        // The row's own value first: a track row rebuilt later may have lost it
        // (or never had it), and the snapshot is what the account carries.
        albumId:    (row['album_id'] as String?) ?? track?.albumId,
        filePath:   row['file_path']  as String?,
        relPath:    row['rel_path']   as String?,
        entryPath:  (row['entry_path'] as String?) ?? '',
        subsongIdx: (row['subsong_idx'] as int?) ?? 0,
        title:      row['title']      as String?,
        artist:     row['artist']     as String?,
        album:      row['album']      as String?,
        formatExt:  row['format_ext'] as String?,
        durationS:  (row['duration_s'] as num?)?.toDouble(),
      ));
    }
    return out;
  }

  /// Entries of a playlist, in order: (row id, track) — AVAILABLE ones only.
  /// Kept for callers that can only deal with playable rows; anything showing
  /// the playlist to the user should use [getPlaylistEntryRefs] so missing
  /// tunes stay visible instead of silently disappearing.
  Future<List<(int, TrackRecord)>> getPlaylistEntries(String playlistId) async {
    final refs = await getPlaylistEntryRefs(playlistId);
    return [
      for (final e in refs)
        if (e.track != null) (e.rowId, e.track!),
    ];
  }

  /// Tracks of a playlist, in playlist order — playable ones only (a missing
  /// file is skipped, never removed). Goes through [getPlaylistEntryRefs] so a
  /// file that came back is re-bound here too.
  Future<List<TrackRecord>> getPlaylistTrackRecords(String playlistId) async {
    final refs = await getPlaylistEntryRefs(playlistId);
    return [for (final e in refs) if (e.track != null) e.track!];
  }

  Future<List<UserPlaylist>> getPlaylists() async {
    final rows = await _database.rawQuery(
      'SELECT * FROM playlists ORDER BY updated_at DESC');
    return rows.map(UserPlaylist.fromMap).toList();
  }

  // ── Housekeeping ──────────────────────────────────────────────────────────

  /// Removes play_events older than [days] days to keep the DB small.
  /// Does NOT affect play_count / last_played_at, which are already
  /// summarised in the tracks table.
  Future<void> pruneHistory({int days = 180}) async {
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch ~/ 1000;
    await _database.execute(
      'DELETE FROM play_events WHERE played_at < ?',
      [cutoff],
    );
  }

  /// Returns true if at least one track from [albumName] exists in the local
  /// database, meaning it was downloaded and played at least once.
  Future<bool> hasLocalAlbum(String albumName) async {
    final rows = await _database.rawQuery(
      'SELECT 1 FROM tracks WHERE meta_album = ? LIMIT 1',
      [albumName],
    );
    return rows.isNotEmpty;
  }

  // ── SID info cache ────────────────────────────────────────────────────────

  /// Returns cached SID subsong metadata for [md5], or null if not yet cached.
  /// Empty list means server was queried but returned no data.
  Future<List<SidSubsongCache>?> getSidInfoCache(String md5) async {
    final sentinel = await _database.rawQuery(
      'SELECT 1 FROM sid_info WHERE md5 = ? LIMIT 1',
      [md5],
    );
    if (sentinel.isEmpty) return null; // not cached
    final rows = await _database.rawQuery(
      'SELECT * FROM sid_info WHERE md5 = ? AND subsong_idx > 0 ORDER BY subsong_idx ASC',
      [md5],
    );
    return rows.map(SidSubsongCache.fromMap).toList();
  }

  /// Stores [subsongs] in the sid_info cache, replacing any existing rows.
  /// Pass an empty [subsongs] list to mark as "fetched but no data" (stores a
  /// sentinel row at subsong_idx=0 so the next call returns an empty list).
  Future<void> upsertSidInfoCache(String md5, List<SidSubsongCache> subsongs) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _database.transaction((txn) async {
      await txn.execute('DELETE FROM sid_info WHERE md5 = ?', [md5]);
      // Always insert a sentinel at idx=0 so getSidInfoCache knows we queried.
      await txn.execute(
        'INSERT INTO sid_info (md5, subsong_idx, fetched_at) VALUES (?, 0, ?)',
        [md5, nowSec],
      );
      for (final s in subsongs) {
        await txn.execute('''
          INSERT INTO sid_info (md5, subsong_idx, length_ms,
                                stil_name, stil_author,
                                stil_title, stil_artist, stil_comment, fetched_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [md5, s.idx, s.lengthMs, s.stilName, s.stilAuthor,
              s.stilTitle, s.stilArtist, s.stilComment, nowSec]);
      }
    });
  }

  // ── Listening stats ───────────────────────────────────────────────────────
  //
  // Deux sources, une seule requête. `play_events` est l'historique de CET
  // appareil (une ligne par écoute, jamais purgé — l'ancien pruneHistory(180j)
  // n'a aucun appelant). `account_play_events` est le miroir de la timeline du
  // COMPTE (migration 45): les écoutes faites sur les autres appareils, et
  // celles portant sur des pistes absentes d'ici, qui n'ont donc aucune ligne
  // `tracks` où s'accrocher.
  //
  // [merged] = false : cet appareil seul (le rail « Vos tendances » de
  // l'accueil, qui parle de ce qu'on a ICI). true : tous les appareils du
  // compte — les écoutes locales DÉJÀ livrées (`pushed = 1`) sont écartées,
  // puisque le miroir les porte; ce marqueur est exact là où le temps ne l'est
  // pas (log_play n'envoie pas de played_at, le serveur estampille `now()`).
  //
  // Toutes les requêtes prennent une fenêtre [from]/[to] en secondes epoch;
  // null = sans borne (« depuis toujours »).

  /// Fragment `ev` commun: une ligne par écoute, quelle qu'en soit la source.
  /// Public parce que c'est LUI qui porte la règle de fusion, et qu'un test
  /// (`test/stats_merge_test.dart`) la fige sans passer par LocalDb — qui a
  /// besoin de path_provider.
  ///
  /// `k` est l'identité de REGROUPEMENT, la seule chose qui permet de compter
  /// ensemble la même piste écoutée ici et ailleurs:
  ///  * `ext:<clé>` — fichier hors catalogue (`tracks.ext_key` ⟷ l'`ext_key`
  ///    du compte). C'est à ça que sert la colonne.
  ///  * `song:<uuid>#<n>` — piste du catalogue. Le local porte soit
  ///    `online_id = uuid#n`, soit un uuid nu + `subsong_idx`; les deux formes
  ///    sont ramenées à la seconde.
  ///  * `file:<chemin>` — repli: fichier local dont la clé n'est pas encore
  ///    connue (aucune écoute ne lui est encore partie).
  static String statsEventsCte(bool merged) {
    // Vue fusionnée: **le compte fait autorité, point**. Le local n'apporte
    // qu'une chose, celle que le compte ne peut pas avoir: l'historique
    // ANTÉRIEUR à sa timeline (écoutes d'avant le compte). Tout le reste vient
    // du miroir.
    //
    // La règle a été plus fine, et c'était une erreur. Compter aussi les
    // écoutes locales « pas encore redescendues » ouvrait la porte à tout ce
    // qui ne redescend JAMAIS: une lecture interrompue (app tuée, `played_ms`
    // nul, aucun envoi déclenché), un `log_play` raté (il est sans reprise),
    // une écoute en cours de livraison. Chaque appareil ajoutait les siennes
    // et deux appareils synchronisés affichaient des totaux différents — trois
    // correctifs successifs n'ont fait que déplacer le problème. Une seule
    // source, une seule vérité.
    //
    // Contrepartie assumée: une écoute faite à l'instant n'entre dans l'écran
    // Stats qu'une fois le miroir redescendu (au plus une synchro, 90 s). Le
    // rail « Vos tendances » de l'accueil, lui, est LOCAL et la montre tout de
    // suite.
    final localWhere = merged
        ? '''WHERE (SELECT COUNT(*) FROM account_play_events) = 0
              OR e.played_at <
                   (SELECT MIN(played_at) FROM account_play_events)'''
        : '';
    // Une piste locale qui EST cette piste du compte: identité catalogue
    // (uuid nu + subsong, ou la forme uuid#n) ou identité hors catalogue.
    const localMatch = '''
      (a.ext_key != '' AND lt.ext_key = a.ext_key)
      OR (a.ext_key = '' AND
          ((lt.online_id = a.song_id AND lt.subsong_idx = a.subsong_idx)
           OR lt.online_id = a.song_id || '#' || a.subsong_idx))''';
    final accountArm = !merged ? '' : """
      UNION ALL
      -- Repli sur la ligne locale: TITRE et POCHETTE seulement. Tout ce qui
      -- se COMPTE (artiste, album, format, durée) vient exclusivement du
      -- catalogue, sinon deux appareils comptent selon ce que chacun a
      -- téléchargé — et le cas vicieux n'est pas transitoire: un morceau que
      -- le catalogue ne crédite pas (`artist` vide) garderait pour toujours
      -- le crédit de la ligne locale sur l'appareil qui a le fichier.
      --
      -- ⚠️ Sous-requêtes SCALAIRES, jamais une jointure: `tracks` peut porter
      -- PLUSIEURS lignes pour un même `online_id` (même morceau retéléchargé
      -- ailleurs, copie d'archive), et un LEFT JOIN duplique alors l'écoute
      -- autant de fois — 1007 écoutes contre 944 sur le même compte.
      SELECT a.played_at,
             COALESCE(a.played_ms, CAST(m.duration_s * 1000 AS INTEGER), 0),
             a.backend,
             CASE WHEN a.ext_key != '' THEN 'ext:' || a.ext_key
                  ELSE 'song:' || a.song_id || '#' || a.subsong_idx END,
             NULL,
             COALESCE(m.title, (SELECT lt.title FROM tracks lt
                                WHERE $localMatch LIMIT 1)),
             m.artist,
             COALESCE(m.album_id, m.album),
             m.album,
             COALESCE(m.artwork_url, (SELECT lt.artwork_url FROM tracks lt
                                      WHERE $localMatch LIMIT 1)),
             lower(COALESCE(NULLIF(m.format_ext, ''), '?')),
             '',
             m.collection,
             a.song_id,
             a.subsong_idx
      FROM account_play_events a
      LEFT JOIN account_track_meta m
        ON m.song_id = a.song_id AND m.subsong_idx = a.subsong_idx
       AND m.ext_key = a.ext_key
    """;
    return """
    ev AS (
      SELECT e.played_at AS played_at,
             COALESCE(e.played_ms, CAST(t.duration_s * 1000 AS INTEGER), 0) AS ms,
             e.backend AS backend,
             CASE
               WHEN t.ext_key IS NOT NULL AND t.ext_key != ''
                 THEN 'ext:' || t.ext_key
               WHEN t.online_id IS NOT NULL AND instr(t.online_id, '#') > 0
                 THEN 'song:' || t.online_id
               WHEN t.online_id IS NOT NULL AND t.online_id != ''
                 THEN 'song:' || t.online_id || '#' || t.subsong_idx
               ELSE 'file:' || t.file_path || '|' || t.entry_path || '|' ||
                    t.subsong_idx
             END AS k,
             t.id AS track_id,
             COALESCE(t.title, t.file_path) AS title,
             t.artist AS artist,
             COALESCE(t.album_id, t.meta_album) AS album_key,
             t.meta_album AS album_name,
             t.artwork_url AS artwork,
             lower(COALESCE(NULLIF(t.format_ext, ''), '?')) AS format_ext,
             CASE WHEN instr(t.file_path, '/online/') = 0 THEN ''
                  ELSE substr(t.file_path, instr(t.file_path, '/online/') + 8)
             END AS online_rest,
             NULL AS collection,
             CASE WHEN t.online_id IS NULL THEN ''
                  WHEN instr(t.online_id, '#') > 0
                    THEN substr(t.online_id, 1, instr(t.online_id, '#') - 1)
                  ELSE t.online_id END AS song_id,
             t.subsong_idx AS subsong_idx
      FROM play_events e JOIN tracks t ON t.id = e.track_id
      $localWhere
      $accountArm
    )
    """;
  }

  static (String, List<Object?>) _statsWindow(int? from, int? to) {
    final where = StringBuffer('1=1');
    final args  = <Object?>[];
    if (from != null) { where.write(' AND e.played_at >= ?'); args.add(from); }
    if (to   != null) { where.write(' AND e.played_at < ?');  args.add(to); }
    return (where.toString(), args);
  }

  /// Headline numbers for the period: total plays + distinct tracks/artists/
  /// albums touched.
  Future<StatsOverview> statsOverview(
      {int? from, int? to, bool merged = false}) async {
    final (where, args) = _statsWindow(from, to);
    final rows = await _database.rawQuery('''
      WITH ${statsEventsCte(merged)}
      SELECT COUNT(*) AS plays,
             COUNT(DISTINCT e.k) AS tracks,
             COUNT(DISTINCT NULLIF(e.artist, '')) AS artists,
             COUNT(DISTINCT e.album_key) AS albums,
             SUM(e.ms) AS listened_ms
      FROM ev e
      WHERE $where
    ''', args);
    final m = rows.first;
    return StatsOverview(
      plays:      (m['plays']   as int?) ?? 0,
      tracks:     (m['tracks']  as int?) ?? 0,
      artists:    (m['artists'] as int?) ?? 0,
      albums:     (m['albums']  as int?) ?? 0,
      listenedMs: (m['listened_ms'] as num?)?.toInt() ?? 0,
    );
  }

  /// Shared shape of the by-collection/format/engine aggregations.
  List<KeyStat> _keyStatsFrom(List<Map<String, Object?>> rows) => [
        for (final m in rows)
          KeyStat(
            (m['k'] as String?) ?? '?',
            (m['plays'] as int?) ?? 0,
            (m['ms'] as num?)?.toInt() ?? 0,
          ),
      ];

  /// Plays per COLLECTION. Locally it is derived from the on-disk layout
  /// (…/online/<collection>/…, see RewampDb._dirSegments); anything not under
  /// online/ is a local file → bucket 'local'. Une écoute venue du compte n'a
  /// pas de chemin: sa collection vient de `account_track_meta`.
  Future<List<KeyStat>> statsTopCollections(
      {int? from, int? to, int limit = 50, bool merged = false}) async {
    final (where, args) = _statsWindow(from, to);
    final rows = await _database.rawQuery('''
      WITH ${statsEventsCte(merged)}
      SELECT CASE
               WHEN e.collection IS NOT NULL AND e.collection != ''
                 THEN e.collection
               WHEN e.online_rest = '' OR instr(e.online_rest, '/') = 0
                 THEN 'local'
               ELSE substr(e.online_rest, 1, instr(e.online_rest, '/') - 1)
             END AS k,
             COUNT(*) AS plays,
             SUM(e.ms) AS ms
      FROM ev e
      WHERE $where
      -- GROUP BY 1 (l'ordinal): `k` nu résout vers la colonne k de la CTE ev,
      -- pas vers l'alias du CASE — même trappe que Top albums.
      GROUP BY 1
      ORDER BY plays DESC
      LIMIT ?
    ''', [...args, limit]);
    return _keyStatsFrom(rows);
  }

  /// Plays per FORMAT (lower-cased extension; unknown → '?').
  Future<List<KeyStat>> statsTopFormats(
      {int? from, int? to, int limit = 50, bool merged = false}) async {
    final (where, args) = _statsWindow(from, to);
    final rows = await _database.rawQuery('''
      WITH ${statsEventsCte(merged)}
      SELECT e.format_ext AS k, COUNT(*) AS plays, SUM(e.ms) AS ms
      FROM ev e
      WHERE $where
      GROUP BY e.format_ext -- pas `k` nu: la CTE ev a SA colonne k
      ORDER BY plays DESC
      LIMIT ?
    ''', [...args, limit]);
    return _keyStatsFrom(rows);
  }

  /// Plays per decoder ENGINE.
  ///
  /// Fusionne comme le reste depuis que le moteur voyage jusqu'au compte
  /// (`p_backend` sur log_play, clé `backend` sur log_plays_ext, colonne sur
  /// user_play_history — le serveur ne le DÉDUIT jamais de l'extension, ce
  /// qui serait faux là où c'est intéressant: deux moteurs pour `.sndh`,
  /// `.hes` disputé entre NEZ et GME).
  ///
  /// Les écoutes sans moteur déclaré sont ÉCARTÉES, pas réparties: tout
  /// l'historique antérieur au déploiement est dans ce cas et formerait une
  /// barre « inconnu » plus grosse que toutes les autres. La carte classe donc
  /// les moteurs entre eux, sur ce qui est attribué.
  Future<List<KeyStat>> statsTopEngines(
      {int? from, int? to, int limit = 50, bool merged = false}) async {
    final (where, args) = _statsWindow(from, to);
    final rows = await _database.rawQuery('''
      WITH ${statsEventsCte(merged)}
      SELECT e.backend AS k, COUNT(*) AS plays, SUM(e.ms) AS ms
      FROM ev e
      WHERE $where AND e.backend IS NOT NULL AND e.backend != ''
      GROUP BY e.backend
      ORDER BY plays DESC
      LIMIT ?
    ''', [...args, limit]);
    return _keyStatsFrom(rows);
  }

  /// LIBRARY snapshot — what the user explicitly saved, matching the Library
  /// tab's own sources: tracks flagged in_library, saved albums/artists/
  /// playlists (library_items), local playlists, favorites.
  Future<LibraryOverview> libraryOverview() async {
    // Compté sur `library_items`, comme l'onglet Bibliothèque et comme la
    // playlist Favoris — et NON sur les colonnes `tracks.in_library` /
    // `tracks.is_favorite`. Ces deux-là ne sont posées que par un geste FAIT
    // ICI: une bibliothèque descendue du compte n'écrit que `library_items`
    // (et ne fabrique une ligne `tracks` que pour affichage, plafonnée par
    // passe). Sur un appareil qui n'a rien mis en favori lui-même, la carte
    // annonçait donc « 0 favoris » avec cinq albums et deux morceaux aimés.
    final li = (await _database.rawQuery('''
      SELECT type, COUNT(*) AS n, SUM(is_favorite) AS favs
      FROM library_items GROUP BY type
    '''));
    int itemCount(String type) => (li
        .where((m) => m['type'] == type)
        .map((m) => (m['n'] as int?) ?? 0)
        .firstOrNull) ?? 0;
    int favCount(String type) => (li
        .where((m) => m['type'] == type)
        .map((m) => (m['favs'] as num?)?.toInt() ?? 0)
        .firstOrNull) ?? 0;
    final pl = (await _database
        .rawQuery('SELECT COUNT(*) AS n FROM playlists')).first;
    return LibraryOverview(
      tracks:    itemCount('track'),
      // Le ♥ porte sur un morceau OU sur un album (la playlist Favoris déplie
      // les seconds): les deux comptent, comme dans cette playlist.
      favorites: favCount('track') + favCount('album'),
      // Local playlists + saved server playlists.
      playlists: ((pl['n'] as int?) ?? 0) + itemCount('playlist'),
      albums:    itemCount('album'),
      artists:   itemCount('artist'),
    );
  }

  /// Most-played tracks in the window, optionally filtered to one [artist]
  /// or one album ([albumKey] = album_id when known, else the meta_album name
  /// — the same key statsTopAlbums returns).
  ///
  /// En vue fusionnée, une piste absente de cet appareil sort quand même: sa
  /// ligne est un [TrackRecord] SYNTHÉTIQUE, `filePath` vide et `onlineId`
  /// renseigné quand le catalogue la connaît — c'est ce couple que l'appelant
  /// teste pour savoir s'il peut la jouer d'ici ou s'il doit passer par le
  /// catalogue.
  Future<List<TrackStat>> statsTopTracks({
    int? from,
    int? to,
    String? artist,
    String? albumKey,
    int limit = 50,
    bool merged = false,
  }) async {
    var (where, args) = _statsWindow(from, to);
    if (artist != null) {
      where = '$where AND e.artist = ?';
      args  = [...args, artist];
    }
    if (albumKey != null) {
      where = '$where AND e.album_key = ?';
      args  = [...args, albumKey];
    }
    final rows = await _database.rawQuery('''
      WITH ${statsEventsCte(merged)},
      agg AS (
        SELECT e.k AS k, COUNT(*) AS plays, MAX(e.played_at) AS last_at,
               MAX(e.track_id) AS track_id, MAX(e.title) AS title,
               MAX(e.artist) AS artist, MAX(e.album_name) AS album_name,
               MAX(e.artwork) AS artwork, MAX(e.format_ext) AS format_ext,
               MAX(e.song_id) AS song_id, MAX(e.subsong_idx) AS subsong_idx
        FROM ev e
        WHERE $where
        GROUP BY e.k
      )
      SELECT COALESCE(t.id, 'account:' || a.k)          AS id,
             COALESCE(t.file_path, '')                  AS file_path,
             COALESCE(t.entry_path, '')                 AS entry_path,
             COALESCE(t.subsong_idx, a.subsong_idx, 0)  AS subsong_idx,
             COALESCE(t.title, a.title)                 AS title,
             COALESCE(t.artist, a.artist)               AS artist,
             COALESCE(t.meta_album, a.album_name)       AS meta_album,
             t.album_id                                 AS album_id,
             t.position                                 AS position,
             t.duration_s                               AS duration_s,
             COALESCE(t.format_ext, NULLIF(a.format_ext, '?')) AS format_ext,
             t.subsong_count                            AS subsong_count,
             COALESCE(t.source, 'online')               AS source,
             COALESCE(t.online_id, NULLIF(a.song_id, '')) AS online_id,
             COALESCE(t.artwork_url, a.artwork)         AS artwork_url,
             COALESCE(t.is_favorite, 0)                 AS is_favorite,
             COALESCE(t.in_library, 0)                  AS in_library,
             COALESCE(t.play_count, 0)                  AS play_count,
             t.last_played_at                           AS last_played_at,
             a.plays                                    AS stat_plays
      FROM agg a LEFT JOIN tracks t ON t.id = a.track_id
      ORDER BY a.plays DESC, a.last_at DESC
      LIMIT ?
    ''', [...args, limit]);
    return [
      for (final m in rows)
        TrackStat(TrackRecord.fromMap(m), (m['stat_plays'] as int?) ?? 0),
    ];
  }

  /// Most-played albums in the window (rows with no album are skipped).
  Future<List<GroupStat>> statsTopAlbums({
    int? from,
    int? to,
    String? artist,
    int limit = 50,
    bool merged = false,
  }) async {
    var (where, args) = _statsWindow(from, to);
    where = "$where AND e.album_name IS NOT NULL AND e.album_name != ''";
    if (artist != null) {
      where = '$where AND e.artist = ?';
      args  = [...args, artist];
    }
    final rows = await _database.rawQuery('''
      WITH ${statsEventsCte(merged)}
      SELECT e.album_key         AS k,
             MAX(e.album_name)   AS name,
             MAX(e.artist)       AS artist,
             MAX(e.artwork)      AS artwork,
             COUNT(*)            AS plays,
             COUNT(DISTINCT e.k) AS track_count
      FROM ev e
      WHERE $where
      -- e.album_key, PAS le `k` nu: la CTE `ev` a SA colonne k (la clé par
      -- piste) et SQLite résout un identifiant nu vers la COLONNE SOURCE avant
      -- l'alias — mesuré, y compris contre un alias de CASE. Groupé par ev.k,
      -- « Top albums » sortait UNE LIGNE PAR PISTE du même album (Wild Arms
      -- 8 fois). Artistes et moteurs qualifiaient déjà: la trappe avait mordu
      -- avant, sans être éradiquée.
      GROUP BY e.album_key
      ORDER BY plays DESC, MAX(e.played_at) DESC
      LIMIT ?
    ''', [...args, limit]);
    return [
      for (final m in rows)
        GroupStat(
          key:        m['k'] as String,
          name:       (m['name'] as String?) ?? '?',
          artist:     m['artist'] as String?,
          artworkUrl: m['artwork'] as String?,
          plays:      (m['plays'] as int?) ?? 0,
          trackCount: (m['track_count'] as int?) ?? 0,
        ),
    ];
  }

  /// Most-played artists in the window (unknown/blank artist skipped).
  ///
  /// ⚠️ En vue fusionnée, une piste du CATALOGUE absente d'ici n'a pas
  /// d'artiste: `user_songs` sert titre/album/pochette mais pas le crédit
  /// (signature de la RPC, migration serveur 189). Ces écoutes comptent dans
  /// les totaux et la timeline, pas dans ce classement.
  Future<List<GroupStat>> statsTopArtists({
    int? from,
    int? to,
    int limit = 50,
    bool merged = false,
  }) async {
    final (where, args) = _statsWindow(from, to);
    final rows = await _database.rawQuery('''
      WITH ${statsEventsCte(merged)}
      SELECT e.artist            AS k,
             MAX(e.artwork)      AS artwork,
             COUNT(*)            AS plays,
             COUNT(DISTINCT e.k) AS track_count
      FROM ev e
      WHERE $where AND e.artist IS NOT NULL AND e.artist != ''
      GROUP BY e.artist
      ORDER BY plays DESC, MAX(e.played_at) DESC
      LIMIT ?
    ''', [...args, limit]);
    return [
      for (final m in rows)
        GroupStat(
          key:        m['k'] as String,
          name:       m['k'] as String,
          artist:     null,
          artworkUrl: m['artwork'] as String?,
          plays:      (m['plays'] as int?) ?? 0,
          trackCount: (m['track_count'] as int?) ?? 0,
        ),
    ];
  }

  /// Plays per day ('%Y-%m-%d') or per month ('%Y-%m') — for the chart.
  /// Buckets with zero plays are absent (the UI fills gaps).
  Future<List<StatsPoint>> statsTimeline({
    int? from,
    int? to,
    required bool byMonth,
    bool merged = false,
  }) async {
    final (where, args) = _statsWindow(from, to);
    final fmt = byMonth ? '%Y-%m' : '%Y-%m-%d';
    final rows = await _database.rawQuery('''
      WITH ${statsEventsCte(merged)}
      SELECT strftime('$fmt', e.played_at, 'unixepoch', 'localtime') AS k,
             COUNT(*) AS n
      FROM ev e
      WHERE $where
      -- Ordinaux: `k` nu résolvait vers ev.k (clé PAR PISTE) — le graphe
      -- comptait une barre par piste, étiquetée d'une date arbitraire.
      GROUP BY 1 ORDER BY 1
    ''', args);
    return [
      for (final m in rows)
        if (m['k'] != null)
          StatsPoint(m['k'] as String, (m['n'] as int?) ?? 0),
    ];
  }

  /// Distinct months ('YYYY-MM', newest first) having at least one play —
  /// feeds the "par mois / par année" period picker.
  Future<List<String>> statsMonths({bool merged = false}) async {
    final rows = await _database.rawQuery('''
      WITH ${statsEventsCte(merged)}
      SELECT DISTINCT
             strftime('%Y-%m', e.played_at, 'unixepoch', 'localtime') AS m
      FROM ev e ORDER BY m DESC
    ''');
    return [for (final r in rows) if (r['m'] != null) r['m'] as String];
  }

  // ── SAP info cache ────────────────────────────────────────────────────────

  /// Returns cached SAP STIL metadata for [md5], or null if not yet cached.
  /// A cached-but-empty entry (queried, no STIL found) has all null fields —
  /// still non-null, so callers can tell "not cached" from "cached, nothing".
  Future<SapInfoCache?> getSapInfoCache(String md5) async {
    final rows = await _database.query('sap_info',
        where: 'md5 = ?', whereArgs: [md5], limit: 1);
    if (rows.isEmpty) return null;
    return SapInfoCache.fromMap(rows.first);
  }

  /// Stores [info] in the sap_info cache (replacing any existing row).
  /// Pass a null-fields [SapInfoCache] to mark "fetched but no STIL found".
  Future<void> upsertSapInfoCache(String md5, SapInfoCache info) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _database.insert(
      'sap_info',
      {
        'md5':          md5,
        'stil_title':   info.stilTitle,
        'stil_artist':  info.stilArtist,
        'stil_comment': info.stilComment,
        'fetched_at':   nowSec,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Cached UADE info for [md5], or null if never queried. Empty subsongs +
  /// subsongCount 0 means "queried, not in songdb".
  Future<UadeInfo?> getUadeCache(String md5) async {
    final rows = await _database.rawQuery(
      'SELECT * FROM uade_cache WHERE md5 = ? ORDER BY subsong_idx ASC',
      [md5],
    );
    if (rows.isEmpty) return null;
    final head = rows.first;
    final subs = <UadeSubsong>[];
    for (final r in rows) {
      final idx = (r['subsong_idx'] as num?)?.toInt() ?? -1;
      if (idx < 0) continue; // sentinel
      subs.add(UadeSubsong(
        idx:      idx,
        lengthMs: (r['length_ms'] as num?)?.toInt(),
        songend:  r['songend'] as String?,
      ));
    }
    return UadeInfo(
      minSubsong:   (head['min_subsong'] as num?)?.toInt() ?? 1,
      subsongCount: (head['subsong_count'] as num?)?.toInt() ?? 0,
      format:       head['format'] as String?,
      channels:     (head['channels'] as num?)?.toInt(),
      authors:      (head['authors'] as String?)?.isNotEmpty == true
          ? (jsonDecode(head['authors'] as String) as List).cast<String>()
          : const [],
      album:        head['album'] as String?,
      year:         (head['year'] as num?)?.toInt(),
      subsongs:     subs,
    );
  }

  /// Stores [info] for [md5]. Always writes a sentinel row at subsong_idx=0 so
  /// getUadeCache returns non-null even when the songdb has no entry.
  Future<void> upsertUadeCache(String md5, UadeInfo info) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final authorsJson = jsonEncode(info.authors);
    await _database.transaction((txn) async {
      await txn.execute('DELETE FROM uade_cache WHERE md5 = ?', [md5]);
      // Sentinel at subsong_idx=-1 (UADE songdb indices can be 0-based, so a
      // real subsong may have idx 0 → can't reuse it as the sentinel).
      await txn.execute('''
        INSERT INTO uade_cache
          (md5, subsong_idx, min_subsong, subsong_count, format, channels,
           authors, album, year, length_ms, songend, fetched_at)
        VALUES (?, -1, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?)
      ''', [md5, info.minSubsong, info.subsongCount, info.format, info.channels,
            authorsJson, info.album, info.year, nowSec]);
      for (final sub in info.subsongs) {
        await txn.execute('''
          INSERT INTO uade_cache
            (md5, subsong_idx, min_subsong, subsong_count, format, channels,
             authors, album, year, length_ms, songend, fetched_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [md5, sub.idx, info.minSubsong, info.subsongCount, info.format,
              info.channels, authorsJson, info.album, info.year,
              sub.lengthMs, sub.songend, nowSec]);
      }
    });
  }

  /// Updates duration_s and/or title for a specific track in the tracks table.
  /// Only writes fields that are non-null.
  Future<void> updateSidTrackMeta({
    required String filePath,
    required int    subsongIdx,
    double? durationS,
    String? title,
    String? artist,
  }) async {
    if (durationS == null && title == null && artist == null) return;
    final sets  = <String>[];
    final args  = <dynamic>[];
    if (durationS != null) { sets.add('duration_s = ?'); args.add(durationS); }
    if (title     != null) { sets.add('title = ?');      args.add(title); }
    // Never clobber an already-known artist (e.g. the composer "Rob Hubbard"
    // from the search result) with a per-subsong STIL credit that may only name
    // the arranger — only fill it in when the track currently has none.
    if (artist    != null) { sets.add('artist = COALESCE(NULLIF(artist, \'\'), ?)'); args.add(artist); }
    args.addAll([filePath, subsongIdx]);
    await _database.execute(
      'UPDATE tracks SET ${sets.join(', ')} WHERE file_path = ? AND subsong_idx = ?',
      args,
    );
  }

  /// Deletes every DB row referencing files under [pathPrefix] (a single
  /// track file, or an album DIRECTORY prefix): tracks, container albums and
  /// recent entries. Used when deleting a download and BEFORE re-downloading
  /// an album, so stale rows (wrong titles / bogus subsongs from old bugs)
  /// stop polluting « écoutés récemment » — fresh plays rewrite clean rows.
  /// Returns the number of track rows removed.
  Future<int> deleteEntriesUnderPath(String pathPrefix) async {
    final like = '${pathPrefix.replaceAll('%', r'\%')}%';
    final n = await _database.transaction((txn) async {
      final n = await txn.delete(
        'tracks',
        where: "file_path = ? OR file_path LIKE ? ESCAPE '\\'",
        whereArgs: [pathPrefix, like],
      );
      await txn.delete(
        'recent_albums',
        where: "file_path = ? OR file_path LIKE ? ESCAPE '\\'",
        whereArgs: [pathPrefix, like],
      );
      return n;
    });
    // Refresh listeners ("écoutés récemment", library screens) — a deleted
    // download must drop out of the lists immediately.
    notifyListeners();
    return n;
  }

  /// Chemins de fichiers des lignes dont l'online_id commence par [prefix]
  /// (les lignes synthétiques '<container>#<i>' d'un album étendu) — la carte
  /// des copies d'extraction, y compris celles laissées sous d'ANCIENS
  /// chemins dérivés (l'artiste a bougé).
  Future<List<String>> filePathsForOnlineIdPrefix(String prefix) async {
    final like = '${prefix.replaceAll('%', r'\%')}%';
    final rows = await _database.rawQuery(
      "SELECT DISTINCT file_path FROM tracks WHERE online_id LIKE ? ESCAPE '\\'",
      [like],
    );
    return [
      for (final r in rows)
        if ((r['file_path'] as String?)?.isNotEmpty == true)
          r['file_path'] as String,
    ];
  }

  /// Removes tracks/albums whose on-disk file no longer exists ("orphans":
  /// deleted downloads, moved folders, rows left by old bugs). Returns the
  /// number of track rows removed.
  Future<int> purgeOrphanEntries() async {
    final rows = await _database.query('tracks', columns: ['id', 'file_path']);
    final checked = <String, bool>{};
    final deadIds = <String>[];
    for (final r in rows) {
      final fp = r['file_path'] as String;
      final ok = checked[fp] ??= await File(fp).exists();
      if (!ok) deadIds.add(r['id'] as String);
    }
    const chunk = 400;
    for (var i = 0; i < deadIds.length; i += chunk) {
      final part = deadIds.sublist(
          i, i + chunk > deadIds.length ? deadIds.length : i + chunk);
      final qs = List.filled(part.length, '?').join(',');
      await _database.delete('tracks', where: 'id IN ($qs)', whereArgs: part);
    }
    // Recent entries pointing at gone files.
    final recents = await _database
        .query('recent_albums', columns: ['album_key', 'file_path']);
    for (final r in recents) {
      final fp = r['file_path'] as String;
      final ok = checked[fp] ??= await File(fp).exists();
      if (!ok) {
        await _database.delete('recent_albums',
            where: 'album_key = ?', whereArgs: [r['album_key']]);
      }
    }
    return deadIds.length;
  }

  /// Clears all play statistics: deletes every play event and resets
  /// play_count / last_played_at on all tracks.
  /// Favourites and library membership are preserved.
  Future<void> clearHistory() async {
    await _database.transaction((txn) async {
      await txn.execute('DELETE FROM play_events');
      // Le miroir du compte fait partie de l'historique montré: l'effacer ici
      // aussi, sinon « effacer l'historique » ne vide que la moitié de l'écran
      // Stats. Le curseur, lui, n'est pas remis à zéro — le geste efface ce
      // que cet appareil montre, il ne redemande pas au compte ce qu'on vient
      // de jeter (seules les écoutes À VENIR redescendront).
      await txn.execute('DELETE FROM account_play_events');
      await txn.execute('DELETE FROM recent_albums');
      await txn.execute(
        'UPDATE tracks SET play_count = 0, last_played_at = NULL',
      );
    });
  }

  /// Clears the fetched-metadata caches (STIL/songlength for SID/SAP, UADE
  /// songdb) so they get re-fetched from the server on the next play. Leaves
  /// history, library, favourites, playlists and track records untouched.
  Future<void> clearMetadataCache() async {
    await _database.transaction((txn) async {
      await txn.execute('DELETE FROM sid_info');
      await txn.execute('DELETE FROM sap_info');
      await txn.execute('DELETE FROM uade_cache');
      // Track durations (duration_s) are re-derived on play; drop any cached
      // value so a fresh metadata fetch isn't shadowed by a stale one.
      await txn.execute('UPDATE tracks SET duration_s = NULL');
    });
  }

  /// Wipes every row from every table — full reset to a blank database.
  /// The schema (tables/triggers) is preserved; only data is deleted.
  Future<void> resetDatabase() async {
    await _database.transaction((txn) async {
      await txn.execute('DELETE FROM play_events');
      await txn.execute('DELETE FROM playlist_tracks');
      await txn.execute('DELETE FROM playlists');
      await txn.execute('DELETE FROM sid_info');
      await txn.execute('DELETE FROM sap_info');
      await txn.execute('DELETE FROM uade_cache');
      await txn.execute('DELETE FROM recent_albums');
      await txn.execute('DELETE FROM library_items');
      await txn.execute('DELETE FROM tracks');
      await txn.execute('DELETE FROM account_play_events');
      await txn.execute('DELETE FROM account_track_meta');
    });
    // A cursor is a claim about what this device ALREADY HOLDS, so wiping the
    // data invalidates it. Left in place, the next pull asked a delta from the
    // old mark, got nothing (the account changed in the meantime, not since),
    // and the device stayed empty for good while the account still held
    // everything — a `full` run does not rescue it either, since its
    // reconciliation walks the LOCAL rows that were just deleted.
    // Same three keys `rebindLocalDataToCurrentAccount` clears when the data
    // stops matching the account; here it is the data that went, not the
    // account. The sync is NOT started from here: the caller decides when.
    UserSettings.instance.libraryCursor       = null;
    UserSettings.instance.playlistCursor      = null;
    UserSettings.instance.libraryReconciledAt = null;
    UserSettings.instance.playHistoryCursor   = null;
    notifyListeners();
  }

  /// Jette la timeline du compte tenue ici — le compte a changé, ces écoutes
  /// sont celles de quelqu'un d'autre. Les écoutes LOCALES restent (elles sont
  /// de cet appareil), mais leur marqueur `pushed` retombe: elles étaient
  /// livrées à l'ANCIEN compte, donc plus rien ne les représente dans le
  /// miroir et l'écran Stats doit les recompter.
  Future<void> clearAccountPlayHistory() async {
    await _database.transaction((txn) async {
      await txn.execute('DELETE FROM account_play_events');
      await txn.execute('DELETE FROM account_track_meta');
      await txn.execute('UPDATE play_events SET pushed = 0 WHERE pushed = 1');
    });
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// Schema — one statement per list entry (sqflite requires single statements)
// ---------------------------------------------------------------------------

const _kUadeCacheSchema = '''CREATE TABLE IF NOT EXISTS uade_cache (
  md5           TEXT    NOT NULL,
  subsong_idx   INTEGER NOT NULL,
  min_subsong   INTEGER,
  subsong_count INTEGER,
  format        TEXT,
  channels      INTEGER,
  authors       TEXT,
  album         TEXT,
  year          INTEGER,
  length_ms     INTEGER,
  songend       TEXT,
  fetched_at    INTEGER NOT NULL,
  PRIMARY KEY (md5, subsong_idx)
)''';

/// A playlist entry is a REFERENCE that stands on its own, not a foreign key.
///
/// [track_id] is only a cached binding to the local `tracks` row (nullable,
/// ON DELETE SET NULL): deleting a download, moving a folder or reinstalling
/// must never remove an entry. What identifies the tune is the snapshot below —
/// the server [song_id] when it comes from the catalogue, and the file
/// coordinates ([file_path] as last seen, [rel_path] relative to the app's base
/// directory so it survives an iOS container change, [entry_path] for an
/// archive member, [subsong_idx]) plus enough metadata to display the entry
/// while the file is missing. Re-binding happens in [_resolvePlaylistEntry].
const _kPlaylistTracksDdl = '''CREATE TABLE IF NOT EXISTS playlist_tracks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    playlist_id TEXT    NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
    track_id    TEXT             REFERENCES tracks(id)    ON DELETE SET NULL,
    position    REAL    NOT NULL,
    added_at    INTEGER NOT NULL DEFAULT 0,
    song_id     TEXT,
    file_path   TEXT,
    rel_path    TEXT,
    entry_path  TEXT    NOT NULL DEFAULT '',
    subsong_idx INTEGER NOT NULL DEFAULT 0,
    title       TEXT,
    artist      TEXT,
    album       TEXT,
    -- Server album_id of the entry's album. NOT derivable from the rest: the
    -- catalogue id of a container says nothing about its album, and without it
    -- a track whose first local row is born of a playlist play has none at all
    -- (see PlayerController._backfillIdentity, which exists to paper over it).
    album_id    TEXT,
    format_ext  TEXT,
    duration_s  REAL
  )''';

const _kSchemaStatements = [
  _kUadeCacheSchema,
  '''CREATE TABLE IF NOT EXISTS tracks (
    id               TEXT    PRIMARY KEY,
    -- Server album_id (rewamp_db), stored verbatim like recent_albums.album_id
    -- (plain TEXT, no FK — the old local `albums` table was never populated
    -- and was dropped in migration 18; its FK broke plays, see migration 11).
    album_id         TEXT,
    file_path        TEXT    NOT NULL,
    entry_path       TEXT    NOT NULL DEFAULT '',
    subsong_idx      INTEGER NOT NULL DEFAULT 0,
    title            TEXT,
    artist           TEXT,
    meta_album       TEXT,
    position         INTEGER,
    duration_s       REAL,
    format_ext       TEXT,
    -- Le nombre de sous-chansons DU FICHIER — jamais le nombre de pistes d'un
    -- album. Catalogue d'abord, sonde moteur ensuite (elle rend 0 pour les
    -- moteurs qu'elle ne chaîne pas: on ne DESCEND jamais). COALESCE à
    -- l'écriture: ne fait que monter. « Cette ligne est déjà résolue » est un
    -- drapeau à part (SearchResult.resolvedSubsong), qui vivait ici (== 1).
    subsong_count    INTEGER,
    source           TEXT    NOT NULL DEFAULT 'local',
    online_id        TEXT,
    artwork_url      TEXT,
    -- (mig 52) origine catalogue, écrite quand on la CONNAÎT (téléchargement,
    -- lecture) plutôt que re-devinée à la relance. `year` avec elles: c'est le
    -- seul champ d'en-tête que `_backfillIdentity` allait rechercher au SERVEUR
    -- alors que la tracklist le portait déjà.
    collection_slug  TEXT,
    platform_name    TEXT,
    year             INTEGER,
    is_favorite      INTEGER NOT NULL DEFAULT 0,
    in_library       INTEGER NOT NULL DEFAULT 0,
    library_added_at INTEGER,
    play_count       INTEGER NOT NULL DEFAULT 0,
    last_played_at   INTEGER,
    ext_key          TEXT,        -- (mig 45) identité hors catalogue du fichier
    UNIQUE (file_path, entry_path, subsong_idx)
  )''',

  // pushed (migration 45), trois états: 0 = le compte DEVRAIT l'avoir et ne
  // l'a pas (envoi raté, hors ligne, pas encore livrée) — la vue fusionnée la
  // compte; 1 = livrée (log_play/log_plays_ext) ou rejouée DEPUIS le compte —
  // c'est le miroir qui la porte; 2 = jamais proposée, sous le seuil de
  // log_play (morceau sauté) — la vue fusionnée l'ignore, sinon deux appareils
  // pourtant synchronisés n'afficheraient pas le même total.
  '''CREATE TABLE IF NOT EXISTS play_events (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    track_id   TEXT    NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    played_at  INTEGER NOT NULL DEFAULT 0,
    played_ms  INTEGER,
    backend    TEXT,
    pushed     INTEGER NOT NULL DEFAULT 0
  )''',

  // Miroir de la timeline du COMPTE (user_play_history, mig serveur 221) —
  // identité serveur, aucun lien vers tracks: une écoute d'un autre appareil
  // porte sur une piste qui peut ne pas exister ici. PK = identité + instant,
  // donc un pull qui rejoue une page (curseur inclusif) n'ajoute rien.
  '''CREATE TABLE IF NOT EXISTS account_play_events (
    kind        TEXT    NOT NULL,
    song_id     TEXT    NOT NULL DEFAULT '',
    subsong_idx INTEGER NOT NULL DEFAULT 0,
    ext_key     TEXT    NOT NULL DEFAULT '',
    played_at   INTEGER NOT NULL,
    played_ms   INTEGER,
    backend     TEXT,           -- (mig 46) moteur, slug tel qu'envoyé
    PRIMARY KEY (song_id, subsong_idx, ext_key, played_at)
  )''',

  // Albums dont la liste COMPLÈTE a été écrite dans `tracks` (migration 47).
  // La présence de lignes ne prouve rien: une seule piste jouée en crée une.
  '''CREATE TABLE IF NOT EXISTS album_materialised (
    album_id    TEXT    PRIMARY KEY,
    track_count INTEGER NOT NULL,
    at          INTEGER NOT NULL
  )''',

  // De quoi NOMMER une piste du compte absente de cet appareil (user_songs
  // pour le catalogue, snapshot ext_ref pour le hors-catalogue).
  '''CREATE TABLE IF NOT EXISTS account_track_meta (
    song_id     TEXT    NOT NULL DEFAULT '',
    subsong_idx INTEGER NOT NULL DEFAULT 0,
    ext_key     TEXT    NOT NULL DEFAULT '',
    title       TEXT,
    artist      TEXT,
    album       TEXT,
    album_id    TEXT,
    artwork_url TEXT,
    collection  TEXT,
    platform    TEXT,
    format_ext  TEXT,
    duration_s  REAL,
    PRIMARY KEY (song_id, subsong_idx, ext_key)
  )''',

  '''CREATE TABLE IF NOT EXISTS playlists (
    id          TEXT    PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    name        TEXT    NOT NULL,
    description TEXT,
    folder_id   TEXT,
    created_at  INTEGER NOT NULL DEFAULT 0,
    updated_at  INTEGER NOT NULL DEFAULT 0,
    server_id   TEXT,
    synced_at   INTEGER,
    server_version TEXT,
    pushed_at   INTEGER,
    dirty_kind  TEXT,
    pushed_count INTEGER,
    folder_changed_at INTEGER
  )''',

  '''CREATE TABLE IF NOT EXISTS playlist_folders (
    id         TEXT    PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    name       TEXT    NOT NULL,
    parent_id  TEXT,
    created_at INTEGER NOT NULL DEFAULT 0
  )''',

  _kPlaylistTracksDdl,

  // Trigger: update track play stats on every new play event
  '''CREATE TRIGGER IF NOT EXISTS trg_after_play_insert
  AFTER INSERT ON play_events
  BEGIN
    UPDATE tracks
    SET play_count     = play_count + 1,
        last_played_at = NEW.played_at
    WHERE id = NEW.track_id;
  END''',

  // Indexes
  'CREATE INDEX IF NOT EXISTS idx_tracks_last_played  ON tracks (last_played_at DESC)',
  'CREATE INDEX IF NOT EXISTS idx_tracks_favorites    ON tracks (is_favorite) WHERE is_favorite = 1',
  'CREATE INDEX IF NOT EXISTS idx_tracks_library      ON tracks (library_added_at DESC) WHERE in_library = 1',
  'CREATE INDEX IF NOT EXISTS idx_tracks_online_id    ON tracks (online_id) WHERE online_id IS NOT NULL',
  'CREATE INDEX IF NOT EXISTS idx_tracks_album        ON tracks (album_id) WHERE album_id IS NOT NULL',
  'CREATE INDEX IF NOT EXISTS idx_play_events_track   ON play_events (track_id)',
  'CREATE INDEX IF NOT EXISTS idx_play_events_recency ON play_events (played_at DESC)',
  'CREATE INDEX IF NOT EXISTS idx_account_plays_recency ON account_play_events (played_at DESC)',
  'CREATE INDEX IF NOT EXISTS idx_playlist_order      ON playlist_tracks (playlist_id, position)',

  // album_key = album_id when known, else "<meta_album>|<album-dir>" — so two
  // same-named albums in different folders/collections don't collapse into one.
  '''CREATE TABLE IF NOT EXISTS recent_albums (
    album_key      TEXT    PRIMARY KEY,
    meta_album     TEXT    NOT NULL,
    album_id       TEXT,
    artist         TEXT,
    file_path      TEXT    NOT NULL,
    artwork_url    TEXT,
    last_played_at INTEGER NOT NULL,
    -- (mig 51) identité catalogue DU FICHIER pointé — un online_id désigne un
    -- fichier, pas une sous-chanson, donc valable pour toutes les subtunes du
    -- même chemin et pour aucun autre chemin.
    online_id      TEXT
  )''',

  // SID metadata cache — keyed by HVSC MD5 + subsong index (1-based).
  // subsong_idx=0 reserved for global/file-level STIL (not used as a playable track).
  '''CREATE TABLE IF NOT EXISTS sid_info (
    md5          TEXT    NOT NULL,
    subsong_idx  INTEGER NOT NULL,
    length_ms    INTEGER,
    stil_name    TEXT,
    stil_author  TEXT,
    stil_title   TEXT,
    stil_artist  TEXT,
    stil_comment TEXT,
    fetched_at   INTEGER NOT NULL,
    PRIMARY KEY (md5, subsong_idx)
  )''',
  'CREATE INDEX IF NOT EXISTS idx_sid_info_md5 ON sid_info (md5)',

  // SAP metadata cache — keyed by standard file MD5 (no subsong dimension).
  '''CREATE TABLE IF NOT EXISTS sap_info (
    md5          TEXT    PRIMARY KEY,
    stil_title   TEXT,
    stil_artist  TEXT,
    stil_comment TEXT,
    fetched_at   INTEGER NOT NULL
  )''',

  '''CREATE TABLE IF NOT EXISTS library_items (
    id              TEXT    PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    type            TEXT    NOT NULL,
    ref_id          TEXT    NOT NULL,
    name            TEXT    NOT NULL,
    artist          TEXT,
    album           TEXT,
    artwork_url     TEXT,
    format_ext      TEXT,
    collection_slug TEXT,
    platform_name   TEXT,
    filename        TEXT,
    download_url    TEXT,
    album_id        TEXT,
    is_favorite     INTEGER NOT NULL DEFAULT 0,
    favorited_at    INTEGER,
    added_at        INTEGER NOT NULL DEFAULT 0,
    folder_id       TEXT,
    folder_changed_at INTEGER,
    fav_changed_at  INTEGER,
    saved           INTEGER NOT NULL DEFAULT 1,  -- 1 = explicit add; 0 = favorite-only
    UNIQUE (type, ref_id)
  )''',
  '''CREATE TABLE IF NOT EXISTS sync_outbox (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    kind        TEXT    NOT NULL,
    item_type   TEXT    NOT NULL,
    item_id     TEXT    NOT NULL,
    subsong_idx INTEGER NOT NULL DEFAULT 0,
    ext_key     TEXT,
    ext_ref     TEXT,
    value       INTEGER NOT NULL,
    favourite   INTEGER,
    changed_at  INTEGER NOT NULL,
    attempts    INTEGER NOT NULL DEFAULT 0
  )''',
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_outbox_item ON sync_outbox '
      '(kind, item_type, item_id, subsong_idx, COALESCE(ext_key, \'\'))',
  'CREATE INDEX IF NOT EXISTS idx_library_items_type ON library_items (type)',

  // Remembers the download_url a song was fetched from (keyed by server
  // song_id). When the server replaces a file (same song_id, NEW url), the play
  // path compares this and purges the stale local copy before re-downloading —
  // otherwise the old extraction shadows the fix forever. See migration 24.
  '''CREATE TABLE IF NOT EXISTS download_sources (
    online_id   TEXT PRIMARY KEY,
    source_url  TEXT NOT NULL,
    updated_at  INTEGER
  )''',

  // Outbox des écoutes de fichiers LOCAUX vers log_plays_ext (migration 44) —
  // livrées par lot, idempotentes serveur (PK user/ext_key/played_at).
  '''CREATE TABLE IF NOT EXISTS ext_play_outbox (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    ext_key       TEXT    NOT NULL,
    ext_ref       TEXT,
    duration_ms   INTEGER NOT NULL,
    played_at     INTEGER NOT NULL,
    attempts      INTEGER NOT NULL DEFAULT 0,
    play_event_id INTEGER,             -- ligne locale à marquer pushed=1
    backend       TEXT                 -- (mig 46) moteur de décodage
  )''',

  // Playlists de presets projectM (migration 50, locales — pas de synchro
  // serveur en v1). `path` est RELATIF à <datadir>/projectm/ (packs/…,
  // presets/…, user/…, single/…): le conteneur iOS change d'UUID à chaque
  // mise à jour, un chemin absolu casserait.
  '''CREATE TABLE IF NOT EXISTS pm_playlists (
    id         TEXT    PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    name       TEXT    NOT NULL,
    server_id  TEXT,    -- curated server playlist this one mirrors (import)
    created_at INTEGER NOT NULL DEFAULT 0,
    updated_at INTEGER NOT NULL DEFAULT 0
  )''',
  '''CREATE TABLE IF NOT EXISTS pm_playlist_items (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    playlist_id TEXT    NOT NULL REFERENCES pm_playlists(id) ON DELETE CASCADE,
    position    INTEGER NOT NULL,
    path        TEXT    NOT NULL,
    preset_id   TEXT,
    name        TEXT
  )''',
  'CREATE INDEX IF NOT EXISTS idx_pm_playlist_items_order '
      'ON pm_playlist_items (playlist_id, position)',
  // Cache chemin→preset_id serveur (uuid5 stable) pour log_preset_uses.
  '''CREATE TABLE IF NOT EXISTS pm_preset_ids (
    path       TEXT PRIMARY KEY,
    preset_id  TEXT NOT NULL
  )''',
];

/// One projectM preset playlist (local, migration 50). [serverId] non-null =
/// the local mirror of a curated server playlist.
class PmPlaylist {
  final String id;
  final String name;
  final String? serverId;
  final int itemCount;
  final int updatedAt; // epoch seconds

  const PmPlaylist({
    required this.id,
    required this.name,
    this.serverId,
    required this.itemCount,
    required this.updatedAt,
  });
}

/// One entry of a projectM preset playlist. [path] is relative to
/// <datadir>/projectm/; [presetId] is the server uuid when known.
class PmPlaylistItem {
  final int id;
  final String path;
  final String? presetId;
  final String? name;
  final int position;

  const PmPlaylistItem({
    required this.id,
    required this.path,
    this.presetId,
    this.name,
    required this.position,
  });
}
