import 'uade_info.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'background_task.dart';
import 'm3u_info.dart';
import 'download_cancel.dart';
import 'isolate_fetch.dart';
import 'client_info.dart';
import 'formats.dart'
    show kAllDecoderExts, kPatternExts, kStreamAudioExts, isInCompanionDir;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rewamp_audio/rewamp_audio.dart' show RewampAudio, SubsongInfo;
import 'artwork_image.dart';
import 'local_db.dart';
import 'local_delete.dart' show cleanCompanionsAfterDelete;
import 'opened_files.dart' show OpenedFiles;
import 'user_settings.dart';
import 'legacy_text.dart';
import 'storage_roots.dart';

/// An auxiliary file that must sit next to the main file for playback to work
/// (e.g. UADE multifile: the "smpl.*" sample file beside a "mdat.*" module).
/// The server lists these in a search result's `aux_files`; the client must
/// download them all into the same directory before launching the main file.
class AuxFile {
  final String filename;
  final String? downloadUrl;
  /// Même contrat que pour le morceau: le miroir (R2) d'abord, l'origine
  /// (`download_url`) si NULL ou en échec. Rempli par le serveur depuis le
  /// 2026-09-05 (miroir modland): sans lui, un module TFMX arrivait du miroir
  /// pendant que sa banque d'échantillons venait encore de modland — muet dès
  /// que le site tombe, exactement ce que le miroir devait supprimer.
  /// L'encodage est celui de `download_url` (espaces bruts, `#`/`?`/`%` déjà
  /// encodés): le même chemin d'encodage s'applique.
  final String? mirrorUrl;
  final int fileSize;

  const AuxFile(
      {required this.filename,
      this.downloadUrl,
      this.mirrorUrl,
      this.fileSize = 0});

  factory AuxFile.fromJson(Map<String, dynamic> j) => AuxFile(
        filename: j['filename'] as String,
        downloadUrl: j['download_url'] as String?,
        mirrorUrl: j['mirror_url'] as String?,
        fileSize: (j['file_size'] as num?)?.toInt() ?? 0,
      );
}

// Callback used by any screen to start album playback via AppShell.
// [startIndex] sets which track plays first (a user-tapped track — kept first
// even in shuffle mode). OMIT it for "play all": with shuffle ON the whole
// queue, including the first played track, is then randomized. The full
// [songs] list is always loaded as the queue so prev/next work across tracks.
typedef OnPlayAlbum = Future<void> Function(
  BuildContext context,
  List<SearchResult> songs, {
  int? startIndex,
});

// Callback for replaying a locally-cached multi-track archive (RSN, NSF, …)
// whose tracks are already in the local DB with correct subsong indices.
typedef OnPlayLocalAlbum = Future<void> Function(
  BuildContext context,
  List<TrackRecord> tracks, {
  int? startIndex,
});

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

/// One entry of a container/album's persisted tracklist — the `tracks` JSONB
/// column on get_album_tracks rows + get_song_context (server, formerly
/// `subsongs`). Lets the client show the full track list of a container album
/// (titles/durations) BEFORE downloading. `subsong` = the index to pass to the
/// player; ABSENT (null) means "play the whole file as one song" (group by
/// `file` to tell songs from subsongs). Empty outside joshw (HVSC/asma use
/// subsong_lengths_ms; modland uses get_uade_info).
class AlbumSubsong {
  final String? file;     // basename inside the container/archive
  final int? subsong;     // player subsong index; null = whole file
  final String? title;
  final int? lengthMs;
  /// Artiste PAR ENTRÉE quand le serveur le connaît (OST multi-artistes:
  /// Frequency = 30 artistes distincts). Sans lui, chaque piste portait
  /// l'UNION des artistes du conteneur.
  final String? artist;

  const AlbumSubsong(
      {this.file, this.subsong, this.title, this.lengthMs, this.artist});

  factory AlbumSubsong.fromJson(Map<String, dynamic> j) => AlbumSubsong(
        file: j['file'] as String?,
        subsong: (j['subsong'] as num?)?.toInt(),
        title: j['title'] as String?,
        lengthMs: (j['length_ms'] as num?)?.toInt(),
        artist: j['artist'] as String?,
      );

  static List<AlbumSubsong> listFrom(dynamic v) {
    if (v is! List) return const [];
    return v
        .whereType<Map>()
        .map((e) => AlbumSubsong.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}

/// Snapshot of a playlist entry the catalogue does NOT know (a file of the
/// user's own: local folder, extracted archive, subsong of a local container).
///
/// Server contract (migration 176): carried as the `ext_ref` member of a
/// `p_entries` element and rendered back verbatim by `get_playlist_tracks` —
/// the server never interprets it, so the shape belongs to the client and can
/// change without a server migration. Hard limit: **2048 bytes of JSON**, above
/// which the whole call fails with `23514 ext_ref too large` — [toJson] trims
/// the free-text fields rather than let a long title lose the entry.
///
/// It carries what makes the tune findable again on another device: the file
/// name, the app-relative path, the archive member and the subsong index —
/// plus enough metadata to display the entry while the file is absent.
class PlaylistExtRef {
  final String fileName;
  final String? relPath;
  final String entryPath;
  final int subsongIdx;
  /// L'entrée vise le FICHIER ENTIER, pas une sous-chanson.
  ///
  /// ⚠️ **Le compte n'a que [subsongIdx], un ENTIER: sans ce drapeau il ne
  /// peut pas distinguer « tout le fichier » de « la sous-chanson 0 ».** Les
  /// deux existent pour de bon — une entrée de conteneur s'écrit sans suffixe
  /// (`localImportRefId`, `ContainerSubsongScreen._songRefId`), un favori posé
  /// sur la 1re sous-chanson s'écrit `?subsong=0` — et les confondre faisait
  /// soit une entrée EN DOUBLE, soit un favori qui atterrit sur le conteneur.
  ///
  /// Il entre aussi dans [SyncService.localLibraryKey], sinon les deux
  /// partageraient la même ligne de compte. Un client ANTÉRIEUR l'ignore et
  /// retombe sur `?subsong=0`: dégradé, jamais faux.
  final bool whole;
  final String? title;
  final String? artist;
  final String? album;
  /// Server album id. STRUCTURAL, like the paths: it is what another device
  /// cannot deduce (a container's song id says nothing about its album) and
  /// what saves it a `get_song_context` per tune. 36 bytes in a 2048-byte
  /// budget, so it is never what makes an entry too big.
  final String? albumId;
  final String? formatExt;
  final double? durationS;

  const PlaylistExtRef({
    required this.fileName,
    this.relPath,
    this.entryPath = '',
    this.subsongIdx = 0,
    this.whole = false,
    this.title,
    this.artist,
    this.album,
    this.albumId,
    this.formatExt,
    this.durationS,
  });

  static const _maxBytes = 2048;

  /// Room left for the free-text fields once the structural ones are counted.
  static String? _clip(String? s, int max) {
    if (s == null || s.isEmpty) return null;
    return s.length <= max ? s : s.substring(0, max);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> build(int textMax) => {
          'file_name':   _clip(fileName, 255) ?? '',
          if (relPath != null && relPath!.isNotEmpty)
            'rel_path': _clip(relPath, 512),
          if (entryPath.isNotEmpty) 'entry_path': _clip(entryPath, 512),
          'subsong_idx': subsongIdx,
          // Émis SEULEMENT quand il est vrai: une entrée ordinaire garde
          // exactement la forme qu'elle avait avant ce champ.
          if (whole) 'whole': true,
          // Before the free-text fields on purpose: build(textMax) trims those
          // when the entry is too big, and this one must survive that.
          if (albumId != null && albumId!.isNotEmpty) 'album_id': albumId,
          if (title != null)  'title':  _clip(title, textMax),
          if (artist != null) 'artist': _clip(artist, textMax),
          if (album != null)  'album':  _clip(album, textMax),
          if (formatExt != null) 'format_ext': _clip(formatExt, 16),
          if (durationS != null) 'duration_s': durationS,
        };
    var out = build(300);
    // Paths are what makes the entry findable again — trim the display text
    // first, and only then give up on the metadata entirely.
    for (final max in const [120, 40, 0]) {
      if (utf8.encode(jsonEncode(out)).length <= _maxBytes) return out;
      out = build(max);
    }
    return out;
  }

  factory PlaylistExtRef.fromJson(Map<String, dynamic> j) => PlaylistExtRef(
        fileName:   (j['file_name'] as String?) ?? '',
        relPath:    j['rel_path']   as String?,
        entryPath:  (j['entry_path'] as String?) ?? '',
        subsongIdx: (j['subsong_idx'] as num?)?.toInt() ?? 0,
        whole:      j['whole'] == true,
        title:      j['title']      as String?,
        artist:     j['artist']     as String?,
        album:      j['album']      as String?,
        albumId:    j['album_id']   as String?,
        formatExt:  j['format_ext'] as String?,
        durationS:  (j['duration_s'] as num?)?.toDouble(),
      );
}

/// Outcome of a playlist write (migration 182). [conflict] true means NOTHING
/// was written because the playlist moved since [PlaylistSync] last saw it; the
/// answer then carries the server's current version so the client can merge and
/// write again. It is a RESULT, not an error: PostgREST replays a transaction
/// that fails with 40001, so raising would loop for ever.
class PlaylistWriteResult {
  final bool conflict;
  final DateTime? updatedAt;
  final Playlist? playlist;

  const PlaylistWriteResult({
    this.conflict = false,
    this.updatedAt,
    this.playlist,
  });

  factory PlaylistWriteResult.fromJson(dynamic json) {
    final map = json is List ? (json.isEmpty ? null : json.first) : json;
    if (map is! Map) return const PlaylistWriteResult();
    final inner = map['playlist'];
    return PlaylistWriteResult(
      conflict:  map['conflict'] == true,
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? ''),
      playlist: inner is Map
          ? Playlist.fromJson(Map<String, dynamic>.from(inner))
          : (map['id'] is String
              ? Playlist.fromJson(Map<String, dynamic>.from(map))
              : null),
    );
  }
}

/// One element of `p_entries`: a catalogue reference, an out-of-catalogue
/// snapshot, or both. An entry carrying [extRef] is ALWAYS kept by the server;
/// a [songId] it does not know, with no [extRef], is dropped silently.
class PlaylistItemPayload {
  final String? songId;
  final PlaylistExtRef? extRef;

  const PlaylistItemPayload({this.songId, this.extRef})
      : assert(songId != null || extRef != null);

  Map<String, dynamic> toJson() => {
        'song_id': catalogueSongId(songId),
        if (extRef != null) 'ext_ref': extRef!.toJson(),
      };
}

/// The CATALOGUE id behind a LOCAL song identity, or null when there is none.
///
/// Local identities are richer than the catalogue's, and deliberately so:
///  * a container expanded into its subsongs mints `<uuid>#<i>` rows, one per
///    entry of the tracklist ([RewampDb.expandContainerAlbum]);
///  * a queue/library key is subsong-scoped, `<id>?subsong=N`;
///  * a file the user brought themselves has a PATH where an id would be.
///
/// Every server column holding a song is declared `uuid`, so handing it one of
/// those verbatim kills the whole call with 22P02 `invalid input syntax for
/// type uuid`. That is what stalled the outbox (13 changes kept, retried for
/// ever) and every push of a playlist holding one container subsong — which in
/// turn made publishing that playlist impossible, since publishing pushes
/// first. The subsong is NOT lost: it travels in its own column
/// (`p_subsong_index`) or inside the entry's `ext_ref`.
///
/// Returns null for anything that is not a catalogue uuid, so a caller can tell
/// "no server identity" from "an identity the server will reject".
String? catalogueSongId(String? raw) {
  if (raw == null) return null;
  final base = raw.split('#').first.split('?').first.trim();
  return _kUuidRe.hasMatch(base) ? base : null;
}

/// L'identité SERVEUR d'un morceau: l'uuid du catalogue ET la sous-chanson,
/// tirés ensemble d'une identité locale.
///
/// [catalogueSongId] coupe le `#N` d'un `<uuid>#<i>` — c'est ce que veut la
/// colonne `uuid` du serveur — mais ce `#N` EST la sous-chanson: le jeter sans
/// le reporter faisait retomber toutes les pistes d'un album conteneur sur la
/// même ligne de compte (`uuid`, 0). Un ♥ posé sur la 30e piste écrivait donc
/// sur la ligne de la 1re, et la synchro suivante ramenait l'état de celle-ci.
/// [subsongIdx] ne sert que faute de `#N` (clé `<uuid>?subsong=N`).
(String?, int) catalogueSongRef(String? raw, {int subsongIdx = 0}) {
  final id = catalogueSongId(raw);
  if (id == null || raw == null) return (id, subsongIdx);
  final hash = raw.split('?').first;
  final i = hash.indexOf('#');
  if (i < 0) return (id, subsongIdx);
  return (id, int.tryParse(hash.substring(i + 1)) ?? subsongIdx);
}

final RegExp _kUuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// The id `log_play` wants — THE ONE EXCEPTION to [catalogueSongId].
///
/// Every other server column holding a song is typed `uuid`, so the subsong has
/// to be stripped and travel in a column of its own. `log_play` is the opposite:
/// its `p_song_id` is declared TEXT *precisely* to carry `uuid#N`, which it
/// parses back into `v_subsong_idx` (server migration 036, whose signature says
/// so in a comment). Running it through [catalogueSongId] therefore threw away
/// exactly what it was built to receive: every subsong of a container was
/// counted against the container, `subsong_index` NULL, and the 204 said
/// nothing — seen live logging `<uuid>#4` then `<uuid>#5` as the same tune.
///
/// The subsong marker is preserved VERBATIM (`#0` included — a bare uuid and
/// `#0` are not the same statement to the server), and the local `?subsong=N`
/// spelling is normalised to the `#N` the server parses. Null when there is no
/// catalogue identity at all, so the caller skips rather than send a path.
String? playLogSongId(String? raw) {
  final base = catalogueSongId(raw);
  if (base == null || raw == null) return null;
  final hash = raw.indexOf('#');
  if (hash >= 0) {
    final n = int.tryParse(raw.substring(hash + 1).split('?').first.trim());
    return n == null ? base : '$base#$n';
  }
  final (_, subsong) = splitLibraryRefId(raw);
  return subsong == null ? base : '$base#$subsong';
}

/// [catalogueSongId] over a list, dropping what has no catalogue identity —
/// one unusable id used to fail the WHOLE call, taking every valid id with it.
List<String> _catalogueIds(Iterable<String>? raw) => [
      for (final id in raw ?? const <String>[])
        if (catalogueSongId(id) case final c?) c,
    ];

class SearchResult {
  final String songId;
  final String collection;
  final String? title;
  final String filename;
  final String? album;
  // Stable album identifier (browse_music/search_music album_id column) — lets the
  // UI group/target the right album when several share a name (e.g. "Commando").
  final String? albumId;
  final String formatExt;
  /// Vrai quand [formatExt] vient du NOM DE FICHIER et non de la colonne
  /// serveur `format_ext` (null pour les formats que le catalogue ne classe
  /// pas — une ligne sceneorg est un `.zip` dont le module est DEDANS).
  ///
  /// ⚠️ Une valeur dérivée ici ne peut pas servir de CLÉ DE FILTRE au serveur:
  /// il filtre sur sa colonne, qui est justement NULL pour ces lignes. Proposer
  /// « ZIP » dans un sélecteur de format donnait donc une option qui ne
  /// ramenait jamais rien. Le repli reste bon pour AFFICHER — il ne l'est pas
  /// pour INTERROGER.
  final bool formatExtFromFileName;
  final String? downloadUrl;
  /// R2/CDN mirror of [downloadUrl] (null = collection not mirrored). Prefer
  /// it for downloads; on 404 (not yet synced) fall back to the origin.
  final String? mirrorUrl;
  final int fileSize;
  final int? year;
  final List<String> artistNames;
  /// Artist UUIDs aligned with the crediting (all songs RPCs, migration 129).
  /// Homonym artists share a name — only the id addresses the right profile.
  /// Empty = song with no credited artist.
  final List<String> artistIds;
  final int totalCount;
  // vgmrips platform tag (e.g. "Mega Drive", "Arcade"); null for modland
  final String? platform;
  // vgmrips rating (0.0–5.0); null for modland
  final double? rating;
  /// Percentile d'usage 0–100 (migrations serveur 207/208), sur les lignes de
  /// `most_popular_songs`. C'est un RANG ­— « plus populaire que N % des
  /// morceaux écoutés » — pas un pourcentage d'écoutes, et il glisse à chaque
  /// recalcul nocturne. null = jamais écouté, ou RPC qui ne le renvoie pas.
  final int? popularity;
  // album artwork URL (may be null for collections that don't have artwork)
  final String? artworkUrl;
  // track number within its album (null when not provided by the collection)
  final int? trackPosition;
  // Subsong index within a multi-track archive (e.g. RSN). 0 = first/only track.
  final int subsongIdx;
  // Total subsongs in this file when the server knows it (native header parse,
  // UADE songdb, …). null/1 = single track, >1 → route to the subsong screen.
  // Generic across formats — supersedes the hardcoded kContainerFormats check.
  final int? subsongCount;
  /// Cette ligne désigne DÉJÀ une sous-chanson précise: ne pas la redéplier.
  ///
  /// Séparé de [subsongCount] exprès. Le drapeau voyageait auparavant DANS le
  /// compte — « subsongCount == 1 » servait de sentinelle « déjà résolue » —,
  /// ce qui donnait deux sens à une même colonne: `isContainerRow` et la vue
  /// des stats y lisent « ce FICHIER a N sous-chansons », propriété du fichier
  /// donc identique sur toutes ses lignes, tandis que la sentinelle parlait de
  /// LA LIGNE. Une ligne de sous-chanson d'un `.sid` sortait donc à 1 et se
  /// faisait lire comme « fichier à une seule sous-chanson ».
  final bool resolvedSubsong;
  /// Palmarès (`most_popular_songs` depuis le 2026-09-05, docs/
  /// popularity_grain_proposal.md): la ligne est une ŒUVRE — album ou fichier —
  /// et désigne son ENTRÉE la plus écoutée sur la période, `(top_song_id,
  /// top_subsong_index)`, toujours rendue. C'est la cible du tap et du ♥; la
  /// ligne reste un CONTENEUR (jamais `resolvedSubsong`), et la lecture TOURNE
  /// la liste à partir de cette entrée (rotateToDefaultSubsong). null hors
  /// palmarès.
  final String? topSongId;
  final int? topSubsongIndex;
  /// Couples (auditeur, jour) distincts sur l'œuvre — la mesure de tri des
  /// « Tendances ». null hors palmarès.
  final int? listenerDays;
  /// Durée du FICHIER ENTIER (`total_length_ms`, listings serveur). À ne pas
  /// confondre avec [durationMs] (`subsong_length_ms`), qui est celle du
  /// PREMIER sous-chant: les deux ne coïncident que sur un fichier mono.
  /// Les sous-chants morts (songend `n`/`e`) sont hors de la somme, donc elle
  /// décrit ce qui est réellement jouable. **NULL = INCONNU, jamais zéro** —
  /// des collections entières n'ont aucune durée en base (vgmrips, snesmusic,
  /// sceneorg, les jw_*), et un « 0:00 » y serait un mensonge.
  final int? totalLengthMs;
  // Duration in milliseconds (HVSC only, null for other collections).
  final int? durationMs;
  // Auxiliary sibling files that must be downloaded next to this file before it
  // can play (UADE multifile: sample/instrument files). Empty for single-file
  // formats. See AuxFile + _ensureAuxFiles.
  final List<AuxFile> auxFiles;
  // Exact on-disk path when this row was synthesized from an already-extracted
  // file (PSF album expansion). downloadToLibrary short-circuits on it —
  // without it the path is re-derived from artist/format/album, which can
  // differ from the extraction layout and silently re-download the whole
  // archive for every track.
  final String? localPath;
  // Compo rank / production / group (get_playlist_tracks rows only).
  final PlaylistTrackMeta? playlistMeta;
  // Persisted per-subsong tracklist of a container album (joshw `subsongs`
  // JSONB). Non-empty when the server knows the subsong titles/durations, so
  // the album screen can list them without downloading. See AlbumSubsong.
  final List<AlbumSubsong> subsongs;
  // When a search query matched a SUBSONG title (not the game title/album),
  // the server returns that subsong so the client can show it + play it
  // directly. `matchSubsongIndex` = the player subsong index (null for a
  // whole-file entry, e.g. 2sf .mini2sf). Both null for a title/album match or
  // browse_music. See search_music (server) match_subsong_*.
  final String? matchSubsongTitle;
  final int? matchSubsongIndex;
  /// Durée de la piste que le serveur a nommée (`match_track_length_ms`), en
  /// ms — la SIENNE, pas celle du fichier. Sans elle, une ligne qui affiche
  /// « Iron Arms » ne pouvait montrer aucune durée: `total_length_ms` décrit
  /// les 73 sous-chants du `.gbs`, et `subsong_length_ms` le premier.
  final int? matchSubsongLengthMs;
  // True when this row is an ALBUM-aggregate stats row (most_popular_songs
  // item_type="album", migration 107): songId/albumId both hold the album's
  // UUID, there is no underlying playable file — tap must resolve via
  // RewampDb.albumTracks(albumId), never getSongContext/downloadAndPlay.
  final bool isAlbumRow;
  // Server-side songs.path (migration 113, last column of search_music/
  // browse_music/browse_folder) — the file's location in the collection's
  // folder tree (e.g. "Fasttracker 2/4-Mat/1081.xm"). Enables "Voir dans le
  // dossier" (browse_folder on dirname). Raw as stored: jw_* paths are
  // URL-encoded. Distinct from [localPath] (on-disk after download).
  final String? path;
  // Demozoo video(s) linked to this tune. Today only get_playlist_tracks rows
  // carry the `videos` column; also reads a `has_video` bool so the badge
  // lights up everywhere the day the list RPCs expose one.
  final bool hasVideo;
  // Best podium of this tune (compo_podium, migration 184) — null on nearly
  // every row. Parsed by NAME, so any RPC that starts sending the column lights
  // the badge up on its own.
  final CompoPodium? podium;
  // get_playlist_tracks, migration 176: snapshot of an OUT-OF-CATALOGUE entry
  // (a file of the user's own). Non-null ⇒ songId is empty and every catalogue
  // column is null — the row is only playable if that file exists on THIS
  // device, which is resolved locally. See [PlaylistExtRef].
  final PlaylistExtRef? extRef;

  const SearchResult({
    required this.songId,
    required this.collection,
    required this.title,
    required this.filename,
    required this.album,
    this.albumId,
    required this.formatExt,
    this.formatExtFromFileName = false,
    required this.downloadUrl,
    this.mirrorUrl,
    required this.fileSize,
    required this.year,
    required this.artistNames,
    this.artistIds = const [],
    required this.totalCount,
    this.platform,
    this.rating,
    this.popularity,
    this.artworkUrl,
    this.trackPosition,
    this.subsongIdx = 0,
    this.subsongCount,
    this.resolvedSubsong = false,
    this.topSongId,
    this.topSubsongIndex,
    this.listenerDays,
    this.totalLengthMs,
    this.durationMs,
    this.auxFiles = const [],
    this.localPath,
    this.playlistMeta,
    this.subsongs = const [],
    this.matchSubsongTitle,
    this.matchSubsongLengthMs,
    this.matchSubsongIndex,
    this.isAlbumRow = false,
    this.path,
    this.hasVideo = false,
    this.podium,
    this.extRef,
  });

  // Formats where the DB returns 1 row per subsong and track_position is the
  // 1-based subsong number within a single file (HVSC SID). For these we map
  // track_position → subsongIdx so each row plays a distinct subsong of the
  // same downloaded file.
  static const _subsongFormats = {'sid', 'psid', 'rsid', 'mus'};

  // Cast a required String field, naming the field + the offending row when it is
  // missing, so a server-side null surfaces as a diagnosable message instead of
  // an opaque "type 'Null' is not a subtype of type 'String' in type cast".
  static String _reqStr(Map<String, dynamic> j, String field) {
    final v = j[field];
    if (v is String) return v;
    final id = j['filename'] ?? j['song_id'] ?? j['title'] ?? '?';
    throw FormatException(
        'search result: required field "$field" was '
        '${v == null ? 'null' : '${v.runtimeType} ($v)'} — row: $id');
  }

  // Lowercased extension of a filename, or '' if none.
  static String _extOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
  }

  /// Row of `get_playlist_tracks` whose `ext_ref` is set: every catalogue
  /// column is null, so nothing can be parsed the usual way — the row IS the
  /// snapshot. [songId] stays empty on purpose: there is nothing to download,
  /// the file either exists on this device or the entry shows as missing.
  factory SearchResult.fromExtRef(PlaylistExtRef ref, {int? trackPosition}) =>
      SearchResult(
        songId:      '',
        collection:  '',
        title:       ref.title,
        filename:    ref.fileName,
        album:       ref.album,
        formatExt:   ref.formatExt ?? _extOf(ref.fileName),
        downloadUrl: null,
        fileSize:    0,
        year:        null,
        artistNames: [if (ref.artist != null && ref.artist!.isNotEmpty) ref.artist!],
        totalCount:  -1,
        trackPosition: trackPosition,
        subsongIdx:  ref.subsongIdx,
        durationMs:  ref.durationS == null
            ? null
            : (ref.durationS! * 1000).round(),
        extRef:      ref,
      );

  factory SearchResult.fromJson(Map<String, dynamic> j) {
    List<String> names = [];
    final raw = j['artist_names'];
    if (raw is List) {
      // A JSON null element stringifies to "null" via toString() — drop those
      // (and empties) so the literal word "null" never shows as an artist or
      // ends up as a "null" directory segment in the download path.
      names = raw
          .where((e) => e != null)
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty && s.toLowerCase() != 'null')
          .toList();
    }

    final filename = _reqStr(j, 'filename');
    // format_ext can be null for formats the server doesn't classify (e.g. .fxm);
    // fall back to the filename's extension so the row stays usable.
    final serverFormat = j['format_ext'] as String?;
    final formatExt = serverFormat ?? _extOf(filename);
    final trackPos  = (j['track_position'] as num?)?.toInt();

    // subsong_index from stats RPCs (most_popular_songs, recently_played_songs)
    // takes precedence; fall back to track_position → SID mapping. A playlist
    // entry's ext_ref wins over both: it is exactly what the user pinned.
    final extSubsong = (j['ext_ref'] is Map)
        ? ((j['ext_ref'] as Map)['subsong_idx'] as num?)?.toInt()
        : null;
    // ⚠️ `subsong_index` n'est rendu QUE par les palmarès (`most_popular_songs`;
    // vérifié: absent de search_music, browse_music, get_album_tracks,
    // list_featured). Sa présence signifie donc que le serveur a nommé UNE
    // sous-chanson précise — la ligne est DÉJÀ RÉSOLUE, ce n'est pas le
    // conteneur. Sans ce drapeau, `_subsongEntries` la déplie en 0..count-1 et
    // la lecture repart de la sous-chanson 0: deux entrées « Monkey Island »
    // dans un palmarès jouaient toutes deux la première.
    //
    // Le défaut était masqué tant que `subsongCount` restait nul (le compte
    // venait de `track_count`, que ces RPC n'envoient pas): l'expansion ne
    // trouvait rien à déplier. Réparer le compte a donc RÉVÉLÉ ce manque, il ne
    // l'a pas créé — les deux vont ensemble.
    final namedSubsong = j['subsong_index'] != null;
    final serverSubsong = extSubsong ?? (j['subsong_index'] as num?)?.toInt();
    // Palmarès: l'entrée la plus écoutée devient l'index de la ligne (cible du
    // ♥ et point de départ de la rotation) SANS la résoudre — `subsong_index`
    // n'y existe plus, donc `namedSubsong` reste faux.
    final topSubsong = (j['top_subsong_index'] as num?)?.toInt();
    final subsong = serverSubsong ?? topSubsong ??
        ((_subsongFormats.contains(formatExt.toLowerCase()) &&
                trackPos != null &&
                trackPos > 0)
            ? trackPos - 1 // 1-based → 0-based subsong index
            : 0);

    return SearchResult(
      songId: _reqStr(j, 'song_id'),
      collection: _reqStr(j, 'collection'),
      title: j['title'] as String?,
      filename: filename,
      album: j['album'] as String?,
      albumId: j['album_id'] as String?,
      formatExt: formatExt,
      formatExtFromFileName: serverFormat == null,
      downloadUrl: j['download_url'] as String?,
      mirrorUrl: j['mirror_url'] as String?,
      fileSize: (j['file_size'] as num?)?.toInt() ?? 0,
      year: (j['year'] as num?)?.toInt(),
      artistNames: names,
      artistIds: [
        if (j['artist_ids'] is List)
          for (final e in j['artist_ids'] as List)
            if (e != null && e.toString().isNotEmpty) e.toString(),
      ],
      totalCount: (j['total_count'] as num?)?.toInt() ?? 0,
      platform: j['platform'] as String?,
      rating: (j['rating'] as num?)?.toDouble(),
      popularity: (j['popularity'] as num?)?.toInt(),
      artworkUrl: j['artwork_url'] as String?,
      trackPosition: trackPos,
      subsongIdx: subsong,
      // Server field renames (2026-07): subsong_count→track_count,
      // subsongs→tracks, match_subsong_*→match_track_* on search_music/
      // browse_music/get_album_tracks/get_playlist_tracks/get_song_context.
      // (get_sid_info/get_uade_info keep the old subsong_* vocabulary.)
      //
      // ⚠️ Les PALMARÈS n'ont pas été renommés: `most_popular_songs` rend
      // toujours `subsong_count` (vérifié dans sa signature, mig serveur 244).
      // Ne lire que `track_count` laissait donc `subsongCount` NUL sur tout
      // rail servi par ces RPC — « Tendances », « Top de tous les temps » — et
      // la tuile « Voir les sous-chansons » ne pouvait pas s'afficher pour un
      // fichier qui en a vingt. Le compte pilote aussi le routage vers l'écran
      // conteneur, donc l'absence ne se voyait pas qu'à cet endroit.
      //
      // On accepte les DEUX noms: un même document ne peut pas porter les deux
      // sens, et cette tolérance survit au prochain renommage partiel.
      subsongCount:
          ((j['track_count'] ?? j['subsong_count']) as num?)?.toInt(),
      resolvedSubsong: namedSubsong,
      topSongId: j['top_song_id'] as String?,
      topSubsongIndex: topSubsong,
      listenerDays: (j['listener_days'] as num?)?.toInt(),
      totalLengthMs: (j['total_length_ms'] as num?)?.toInt(),
      durationMs: (j['subsong_length_ms'] as num?)?.toInt(),
      auxFiles: _parseAuxFiles(j['aux_files']),
      playlistMeta: PlaylistTrackMeta.fromJson(j['meta']),
      subsongs: AlbumSubsong.listFrom(j['tracks']),
      matchSubsongTitle: j['match_track_title'] as String?,
      matchSubsongIndex: (j['match_track_index'] as num?)?.toInt(),
      matchSubsongLengthMs: (j['match_track_length_ms'] as num?)?.toInt(),
      isAlbumRow: j['item_type'] == 'album',
      path: j['path'] as String?,
      hasVideo: (j['videos'] is List && (j['videos'] as List).isNotEmpty) ||
          j['has_video'] == true,
      // Not a server field: written by toJson() so a persisted queue item
      // keeps its already-extracted on-disk path (PSF album expansion rows
      // have no downloadUrl at all).
      localPath: j['_local_path'] as String?,
      podium: CompoPodium.fromJson(j['compo_podium']),
      // A catalogue row MAY also carry an ext_ref (playlist entry that needed
      // client detail the catalogue row has no place for — a container's
      // subsong index, an archive member).
      extRef: j['ext_ref'] is Map
          ? PlaylistExtRef.fromJson(
              Map<String, dynamic>.from(j['ext_ref'] as Map))
          : null,
    );
  }

  /// Local persistence (queue snapshot across launches) — mirrors the
  /// [fromJson] field names so the round trip is lossless for playback.
  /// playlistMeta/subsongs/match* are deliberately dropped: a queue is
  /// already expanded, they aren't needed to replay an item.
  Map<String, dynamic> toJson() => {
        'song_id': songId,
        'collection': collection,
        if (title != null) 'title': title,
        'filename': filename,
        if (album != null) 'album': album,
        if (albumId != null) 'album_id': albumId,
        if (topSongId != null) 'top_song_id': topSongId,
        if (topSubsongIndex != null) 'top_subsong_index': topSubsongIndex,
        if (listenerDays != null) 'listener_days': listenerDays,
        if (totalLengthMs != null) 'total_length_ms': totalLengthMs,
        'format_ext': formatExt,
        if (downloadUrl != null) 'download_url': downloadUrl,
        if (mirrorUrl != null) 'mirror_url': mirrorUrl,
        'file_size': fileSize,
        if (year != null) 'year': year,
        'artist_names': artistNames,
        if (artistIds.isNotEmpty) 'artist_ids': artistIds,
        'total_count': totalCount,
        if (platform != null) 'platform': platform,
        if (rating != null) 'rating': rating,
        if (artworkUrl != null) 'artwork_url': artworkUrl,
        if (trackPosition != null) 'track_position': trackPosition,
        'subsong_index': subsongIdx, // takes precedence in fromJson
        if (subsongCount != null) 'track_count': subsongCount,
        if (durationMs != null) 'subsong_length_ms': durationMs,
        if (auxFiles.isNotEmpty)
          'aux_files': [
            for (final a in auxFiles)
              {
                'filename': a.filename,
                if (a.downloadUrl != null) 'download_url': a.downloadUrl,
                if (a.mirrorUrl != null) 'mirror_url': a.mirrorUrl,
                'file_size': a.fileSize,
              }
          ],
        if (localPath != null) '_local_path': localPath,
        if (path != null) 'path': path,
      };

  // aux_files may be a list of objects ({filename, download_url, file_size}) or,
  // tolerantly, a list of bare filename strings (no URL → not downloadable).
  static List<AuxFile> _parseAuxFiles(dynamic raw) {
    if (raw is! List) return const [];
    final out = <AuxFile>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        final fn = e['filename'];
        if (fn is String && fn.isNotEmpty) out.add(AuxFile.fromJson(e));
      } else if (e is String && e.isNotEmpty) {
        out.add(AuxFile(filename: e));
      }
    }
    return out;
  }

  /// Same row targeting a specific subsong (stats rows carry the subsong index
  /// but must be re-resolved via get_song_context for a playable URL — this
  /// re-applies the index onto the resolved row).
  /// Returns a copy carrying [id] as the album id (used to stamp the
  /// authoritative server album_id onto tracks fetched without one).
  SearchResult withAlbumId(String id) => SearchResult(
        songId: songId,
        collection: collection,
        title: title,
        filename: filename,
        album: album,
        albumId: id,
        formatExt: formatExt,
        formatExtFromFileName: formatExtFromFileName,
        downloadUrl: downloadUrl,
        mirrorUrl: mirrorUrl,
        fileSize: fileSize,
        year: year,
        artistNames: artistNames,
        artistIds: artistIds,
        totalCount: totalCount,
        platform: platform,
        rating: rating,
        artworkUrl: artworkUrl,
        trackPosition: trackPosition,
        subsongIdx: subsongIdx,
        subsongCount: subsongCount,
        topSongId: topSongId,
        topSubsongIndex: topSubsongIndex,
        listenerDays: listenerDays,
        totalLengthMs: totalLengthMs,
        durationMs: durationMs,
        auxFiles: auxFiles,
        localPath: localPath,
        playlistMeta: playlistMeta,
        subsongs: subsongs,
        path: path,
      );

  /// A copy carrying the catalogue IDENTITY of this tune — album, album id,
  /// collection — with the caller's own values kept when it already has them.
  ///
  /// What a row needs to be found again after its file was deleted: an album
  /// NAME alone matches homonyms across collections (a "Final Fantasy III"
  /// exists on SNES and on NES), and the wrong album then yields the wrong
  /// track. Null arguments change nothing.
  SearchResult copyWithIdentity({
    String? collection,
    String? album,
    String? albumId,
  }) =>
      SearchResult(
        songId: songId,
        collection: (this.collection.isNotEmpty)
            ? this.collection
            : (collection ?? this.collection),
        title: title,
        filename: filename,
        album: this.album ?? album,
        albumId: this.albumId ?? albumId,
        formatExt: formatExt,
        formatExtFromFileName: formatExtFromFileName,
        downloadUrl: downloadUrl,
        mirrorUrl: mirrorUrl,
        fileSize: fileSize,
        year: year,
        artistNames: artistNames,
        artistIds: artistIds,
        totalCount: totalCount,
        platform: platform,
        rating: rating,
        artworkUrl: artworkUrl,
        trackPosition: trackPosition,
        subsongIdx: subsongIdx,
        subsongCount: subsongCount,
        topSongId: topSongId,
        topSubsongIndex: topSubsongIndex,
        listenerDays: listenerDays,
        totalLengthMs: totalLengthMs,
        durationMs: durationMs,
        auxFiles: auxFiles,
        localPath: localPath,
        playlistMeta: playlistMeta,
        subsongs: subsongs,
        path: path,
      );

  /// LA copie canonique: chaque champ absent est repris de `this`.
  ///
  /// Les trois « faiseurs de lignes » (withSubsong, withSubsongEntry,
  /// narrowedToFile) recopiaient chacun ~30 champs à la main: tout champ
  /// ajouté à la classe devait être reporté dans chacun, sinon il
  /// disparaissait EN SILENCE de la copie — payé plusieurs fois (podium et
  /// badge vidéo perdus par withSubsong), et VIVANT au moment de cette
  /// réécriture: narrowedToFile perdait sept champs, dont hasVideo, podium et
  /// extRef. Désormais un faiseur n'énonce QUE sa différence.
  ///
  /// Limite assumée du patron: copyWith ne sait pas remettre un champ à null.
  /// Aucun faiseur n'en a besoin aujourd'hui; celui qui en aura besoin
  /// construira explicitement.
  SearchResult copyWith({
    String? songId,
    String? collection,
    String? title,
    String? filename,
    String? album,
    String? albumId,
    String? formatExt,
    String? downloadUrl,
    String? mirrorUrl,
    int? fileSize,
    int? year,
    List<String>? artistNames,
    List<String>? artistIds,
    int? totalCount,
    String? platform,
    double? rating,
    int? popularity,
    String? artworkUrl,
    int? trackPosition,
    int? subsongIdx,
    int? subsongCount,
    bool? resolvedSubsong,
    /// `durationMs` est le seul champ qu'on doive parfois EFFACER: il décrit
    /// UN sous-chant (le serveur rend `subsong_length_ms`, celui du PREMIER),
    /// donc il ne suit pas la ligne quand elle en désigne un autre. Un `null`
    /// ordinaire veut dire « ne change rien », d'où ce drapeau explicite.
    bool dropDurationMs = false,
    String? topSongId,
    int? topSubsongIndex,
    int? durationMs,
    List<AuxFile>? auxFiles,
    String? localPath,
    PlaylistTrackMeta? playlistMeta,
    List<AlbumSubsong>? subsongs,
    String? matchSubsongTitle,
    int? matchSubsongIndex,
    bool? isAlbumRow,
    String? path,
    bool? hasVideo,
    CompoPodium? podium,
    PlaylistExtRef? extRef,
  }) =>
      SearchResult(
        songId: songId ?? this.songId,
        collection: collection ?? this.collection,
        title: title ?? this.title,
        filename: filename ?? this.filename,
        album: album ?? this.album,
        albumId: albumId ?? this.albumId,
        formatExt: formatExt ?? this.formatExt,
        // Le drapeau suit son format: sans ça un dérivé (withSubsong…)
        // ferait passer un format DÉDUIT pour un format serveur.
        formatExtFromFileName: formatExt == null && formatExtFromFileName,
        downloadUrl: downloadUrl ?? this.downloadUrl,
        mirrorUrl: mirrorUrl ?? this.mirrorUrl,
        fileSize: fileSize ?? this.fileSize,
        year: year ?? this.year,
        artistNames: artistNames ?? this.artistNames,
        artistIds: artistIds ?? this.artistIds,
        totalCount: totalCount ?? this.totalCount,
        platform: platform ?? this.platform,
        rating: rating ?? this.rating,
        popularity: popularity ?? this.popularity,
        artworkUrl: artworkUrl ?? this.artworkUrl,
        trackPosition: trackPosition ?? this.trackPosition,
        subsongIdx: subsongIdx ?? this.subsongIdx,
        subsongCount: subsongCount ?? this.subsongCount,
        resolvedSubsong: resolvedSubsong ?? this.resolvedSubsong,
        topSongId: topSongId ?? this.topSongId,
        topSubsongIndex: topSubsongIndex ?? this.topSubsongIndex,
        listenerDays: listenerDays,
        totalLengthMs: totalLengthMs,
        durationMs: dropDurationMs ? null : (durationMs ?? this.durationMs),
        auxFiles: auxFiles ?? this.auxFiles,
        localPath: localPath ?? this.localPath,
        playlistMeta: playlistMeta ?? this.playlistMeta,
        subsongs: subsongs ?? this.subsongs,
        matchSubsongTitle: matchSubsongTitle ?? this.matchSubsongTitle,
        matchSubsongIndex: matchSubsongIndex ?? this.matchSubsongIndex,
        matchSubsongLengthMs: matchSubsongLengthMs,
        isAlbumRow: isAlbumRow ?? this.isAlbumRow,
        path: path ?? this.path,
        hasVideo: hasVideo ?? this.hasVideo,
        podium: podium ?? this.podium,
        extRef: extRef ?? this.extRef,
      );

  /// La même ligne, sur une autre sous-chanson — le dépliage brut.
  /// ⚠️ La durée ne SUIT PAS le changement de sous-chant. `subsong_length_ms`
  /// (search_music / browse_music / get_song_context) est la durée du PREMIER
  /// sous-chant — mesuré: « Commando » rend 235594 ms, celle du sous-chant 1,
  /// quand le 2e en fait 61288 et le 4e 1124. La recopier sur les 19 lignes
  /// dépliées donnait 3:55 partout, affiché ET appliqué: le filet « fin
  /// connue » (SID/NSF ne finissent jamais seuls) jouait 3:55 de silence sur
  /// un sous-chant d'une seconde. Sans durée, la vraie arrive juste après —
  /// `_applyLocalSidMeta` pour un SID, `_applyUadeDuration` pour UADE, la
  /// sonde/M3U pour un NSFe — alors qu'un mauvais nombre ne se corrige pas
  /// tout seul.
  SearchResult withSubsong(int idx, {String? title, int? durationMs}) =>
      copyWith(
        subsongIdx: idx,
        title: title,
        durationMs: durationMs,
        dropDurationMs: durationMs == null && idx != subsongIdx,
      );

  /// A copy pinned to ONE subsong of the file, with the synthetic
  /// `<uuid>#<subsong>` identity the rest of the app reads as "already
  /// resolved — do not expand this again".
  ///
  /// A playlist entry pointing INSIDE a multi-subsong file comes back from the
  /// server as the CONTAINER row (same `song_id`, `track_count` of the whole
  /// file) with the subsong in `ext_ref`. Left as-is, every entry claimed the
  /// whole file: a 21-entry playlist of one TFMX module put 61 rows in the
  /// queue (each eagerly-expanded entry re-exploded into all 21 subsongs).
  /// The FILE's subsongCount is kept: it is true, and an offline recents
  /// replay needs it to rebuild the queue.
  SearchResult withSubsongEntry(int idx) => copyWith(
        songId: '${songId.split('#').first}#$idx',
        subsongIdx: idx,
        resolvedSubsong: true,
        dropDurationMs: idx != subsongIdx,   // voir withSubsong
      );

  /// A copy of a CONTAINER-album row narrowed to ONE of its files. What a
  /// playlist entry pointing INSIDE a multi-file album (ext_ref.file_name)
  /// must yield: still a container (the play path extracts the album), but
  /// with a single-entry tracklist — kept whole, the 67-track `tracks` list
  /// enqueued the ENTIRE album in place of the one pinned track.
  ///
  /// Deux situations, et le compte n'y vaut pas la même chose:
  ///  * vers un FICHIER de l'archive (`s.file` renseigné) — ce fichier a une
  ///    seule sous-chanson;
  ///  * vers une SOUS-CHANSON du même fichier (index seul) — le fichier garde
  ///    son compte (un `.sid` HVSC: 19), et écrire 1 ici était le dernier
  ///    endroit d'où sortait un « fichier à une seule sous-chanson » faux.
  /// « Déjà résolue » est vrai dans les deux cas: `resolvedSubsong` le porte.
  SearchResult narrowedToFile(AlbumSubsong s) => copyWith(
        title: (s.title != null && s.title!.isNotEmpty) ? s.title : null,
        artistNames: (s.artist != null && s.artist!.isNotEmpty)
            ? [s.artist!]
            : null,
        subsongIdx: s.subsong ?? 0,
        // Une entrée sans durée connue reste SANS durée: celle du conteneur
        // décrit son premier sous-chant (voir withSubsong).
        dropDurationMs: s.lengthMs == null,
        subsongCount: (s.file == null || s.file!.isEmpty) ? null : 1,
        resolvedSubsong: true,
        durationMs: s.lengthMs,
        subsongs: [s],
      );

  String get displayTitle =>
      (title != null && title!.isNotEmpty) ? title! : filename;

  /// Le nom du FICHIER, quand cette ligne est regardée comme un CONTENEUR.
  ///
  /// ⚠️ `displayTitle` ne convient pas: la ligne d'un conteneur est celle de sa
  /// sous-chanson 0, et une sous-chanson porte SON titre — STIL nomme la piste 1
  /// de « One Man and his Droid » « Space Game », si bien que l'écran de détail
  /// du conteneur et la ligne d'album du lecteur s'appelaient tous deux
  /// « Space Game ». Le titre du catalogue et celui du sous-chant vivent dans le
  /// MÊME champ; seul le nom de fichier est à coup sûr du niveau FICHIER.
  ///
  /// `filename` est donc préféré dès qu'il existe. Le convention Amiga met le
  /// FORMAT avant le point (`mdat.monkey island`), d'où le découpage par la
  /// DERNIÈRE extension seulement quand elle ressemble à une extension.
  String get containerName {
    final f = filename;
    if (f.isEmpty) return displayTitle;
    final dot = f.lastIndexOf('.');
    if (dot <= 0) return f;
    final ext = f.substring(dot + 1);
    // Un suffixe d'extension plausible: court et sans espace. « mdat.monkey
    // island » n'en est pas un, et son nom doit rester entier.
    if (ext.isEmpty || ext.length > 5 || ext.contains(' ')) return f;
    return f.substring(0, dot);
  }

  /// La base d'un titre de sous-chanson « NOM (n) ».
  ///
  /// ⚠️ **Jamais [displayTitle] tel quel.** La ligne d'un CONTENEUR est
  /// souvent celle de sa sous-chanson 0, qui porte SON titre — déjà numéroté.
  /// Le renuméroter donne « Commando (1) (1) », que la lecture PERSISTE dans
  /// `tracks`, d'où la ligne se relit au tour suivant: le suffixe s'EMPILE.
  /// Mesuré sur la base réelle: « Commando (1) (1) (1) » après trois
  /// aller-retours, entrée de bibliothèque comprise.
  ///
  /// On garde le titre — meilleur qu'un nom de fichier quand le catalogue en
  /// donne un — et on retire seulement le suffixe que NOUS avons posé: celui
  /// qui suit le nom du FICHIER. Un vrai titre finissant par une parenthèse
  /// numérique (« Sonic (2) » pour `sonic2.nsf`) ne commence pas par ce
  /// nom-là et reste intact.
  String get subsongTitleBase {
    var t = displayTitle;
    final file = containerName;
    while (t.length > file.length) {
      final m = RegExp(r'^(.*) \(\d+\)$').firstMatch(t);
      if (m == null) break;
      final head = m.group(1)!;
      if (!head.startsWith(file)) break;
      t = head;
    }
    return t;
  }

  String get artistLabel => artistNames.isEmpty ? '' : artistNames.join(' & ');

  // Total bytes to download for this song = the main file plus every auxiliary
  // sibling (UADE multifile), since all of them are fetched together.
  int get totalFileSize =>
      fileSize + auxFiles.fold<int>(0, (sum, a) => sum + a.fileSize);

  String get fileSizeLabel {
    final size = totalFileSize;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ---------------------------------------------------------------------------
// Browse models
// ---------------------------------------------------------------------------

/// Collections whose `songs.path` is a real navigable folder tree (modland
/// format/artist, HVSC MUSICIANS/GAMES/DEMOS, ASMA Composers, sc68
/// artist/platform, jw_* letter dirs) — route their tap to
/// CollectionFolderScreen. The rest either have synthetic paths (sceneorg
/// demozoo ids, smspower slugs, zxart ids), opaque dirs (snesmusic), or are
/// album-grain (vgmrips) → album/artist landing instead.
bool collectionHasFolderTree(String slug) =>
    slug == 'modland' || slug == 'hvsc' || slug == 'asma' ||
    // UnExotica is path-structured too, and its FIRST level is the useful
    // distinction browse_music cannot express: Demo vs Game (then author, then
    // the production). It was missing here, so the collection fell through to
    // the generic flat listing and that split was unreachable.
    slug == 'unexotica' ||
    slug == 'sc68' || slug.startsWith('jw_');

/// Album-grain collections: every song belongs to exactly one album/pack and
/// the album is the natural browse unit → CollectionAlbumsScreen
/// (search_albums with an empty q browses the whole catalogue).
bool collectionIsAlbumGrain(String slug) =>
    slug == 'vgmrips' || slug == 'snesmusic' || slug == 'smspower';

/// Artist-grain collections: no folder structure (standalone tracks with
/// demozoo/zxart author metadata). No longer a ROUTE of their own — they land
/// on the CollectionHubScreen like every unstructured collection (the hub's
/// first card is the same A–Z artist list their direct landing used to be).
/// Kept for callers that want the distinction.
bool collectionIsArtistGrain(String slug) =>
    slug == 'zxart' || slug == 'sceneorg';

/// One-call profile of a collection (`get_collection_overview`, server
/// 275a58a) — what drives the collection hub: a card only exists for an axis
/// whose count is non-zero, so the hub is data-driven, never per-slug.
/// Counts come from materialized views refreshed after imports: they can lag
/// a running import by hours, which is fine for navigation.
/// Une playlist de CLASSEMENT (« chart »): reconstruite intégralement côté
/// serveur chaque dimanche depuis une source EXTERNE (HVSC Top 100,
/// snesmusic Top 100…).
///
/// ⚠️ Le discriminant est `kind='chart'` CÔTÉ SERVEUR — jamais le slug ni le
/// nom. Deux chemins la servent: `get_collection_overview.charts` (l'écran de
/// collection) et `list_charts()` (vue transverse, avec `collection`). Elle se
/// LIT comme n'importe quelle playlist (`get_playlist_tracks`, `position` = le
/// rang, `meta.rank` le répète — la convention des compos demozoo), et ne se
/// PROPOSE JAMAIS à l'édition: toute modification serait écrasée au dimanche
/// suivant. `chartUrl` est le crédit vers la source — à montrer, c'est leur
/// travail; `updatedAt` dit la fraîcheur.
class ChartPlaylist {
  final String id;
  final String slug;
  final String name;
  final String? description;
  /// Slug de collection — porté par `list_charts`, absent du chemin overview
  /// (où la collection est déjà connue de l'appelant).
  final String? collection;
  final String? chartUrl;
  final String? coverUrl;
  final int trackCount;
  final DateTime? updatedAt;
  /// Le GRAIN du classement, DÉCLARÉ par le serveur: 'album' (vgmrips,
  /// snesmusic — des packs) ou 'song' (hvsc — des morceaux). C'est lui qui
  /// décide la présentation AVANT tout chargement; null = serveur antérieur,
  /// traité comme 'song' (l'écran de playlist marche partout).
  final String? grain;
  /// Nombre d'ALBUMS du classement quand grain='album' (un album présent
  /// plusieurs fois garde son meilleur rang, dédoublonnage serveur).
  final int albumCount;

  const ChartPlaylist({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.collection,
    this.chartUrl,
    this.coverUrl,
    this.trackCount = 0,
    this.updatedAt,
    this.grain,
    this.albumCount = 0,
  });

  bool get albumGrain => grain == 'album';

  factory ChartPlaylist.fromJson(Map<String, dynamic> j) => ChartPlaylist(
        id:          j['id'] as String,
        slug:        (j['slug'] as String?) ?? '',
        name:        (j['name'] as String?) ?? '',
        description: j['description'] as String?,
        collection:  j['collection'] as String?,
        chartUrl:    j['chart_url'] as String?,
        coverUrl:    j['cover_url'] as String?,
        trackCount:  (j['track_count'] as num?)?.toInt() ?? 0,
        updatedAt:   DateTime.tryParse((j['updated_at'] as String?) ?? ''),
        grain:       j['grain'] as String?,
        albumCount:  (j['album_count'] as num?)?.toInt() ?? 0,
      );
}

/// Une ligne de `most_popular_albums` — volontairement maigre: le RPC ne rend
/// que de quoi afficher et naviguer (l'écran d'album recharge le reste par
/// l'uuid).
class PopularAlbum {
  final String albumId;
  final String name;
  final String? platform;
  final String collection;
  final String? artworkUrl;
  final int playCount;

  const PopularAlbum({
    required this.albumId,
    required this.name,
    this.platform,
    required this.collection,
    this.artworkUrl,
    this.playCount = 0,
  });

  factory PopularAlbum.fromJson(Map<String, dynamic> j) => PopularAlbum(
        albumId:    j['album_id'] as String,
        name:       (j['name'] as String?) ?? '',
        platform:   j['platform'] as String?,
        collection: (j['collection'] as String?) ?? '',
        artworkUrl: j['artwork_url'] as String?,
        playCount:  (j['play_count'] as num?)?.toInt() ?? 0,
      );
}

class CollectionOverview {
  final int songCount;
  final int artistCount;
  final int albumCount;
  /// Union of the three tag-resolution paths (song ∪ album ∪ artist tags) —
  /// amp's groups only exist artist-side, a song-tag count would be 0 there.
  final int groupCount;
  final int countryCount;
  /// (country, artist count), server-sorted. Display-only for now: no listing
  /// RPC takes a country filter yet.
  final List<({String country, int artists})> countries;
  final int? yearMin;
  final int? yearMax;
  /// Complete format census, count-desc.
  final List<({String ext, int count})> formats;
  /// Les playlists de CLASSEMENT de la collection — `[]` si elle n'en a pas.
  final List<ChartPlaylist> charts;

  const CollectionOverview({
    this.songCount = 0,
    this.artistCount = 0,
    this.albumCount = 0,
    this.groupCount = 0,
    this.countryCount = 0,
    this.countries = const [],
    this.yearMin,
    this.yearMax,
    this.formats = const [],
    this.charts = const [],
  });

  factory CollectionOverview.fromJson(Map<String, dynamic> j) {
    final countries = <({String country, int artists})>[];
    if (j['countries'] is List) {
      for (final e in j['countries'] as List) {
        if (e is Map && e['country'] is String) {
          countries.add((
            country: e['country'] as String,
            artists: (e['artists'] as num?)?.toInt() ?? 0,
          ));
        }
      }
    }
    final formats = <({String ext, int count})>[];
    if (j['formats'] is List) {
      for (final e in j['formats'] as List) {
        if (e is Map && e['ext'] is String) {
          formats.add((
            ext:   e['ext'] as String,
            count: (e['count'] as num?)?.toInt() ?? 0,
          ));
        }
      }
    }
    return CollectionOverview(
      songCount:    (j['song_count'] as num?)?.toInt() ?? 0,
      artistCount:  (j['artist_count'] as num?)?.toInt() ?? 0,
      albumCount:   (j['album_count'] as num?)?.toInt() ?? 0,
      groupCount:   (j['group_count'] as num?)?.toInt() ?? 0,
      countryCount: (j['country_count'] as num?)?.toInt() ?? 0,
      countries:    countries,
      yearMin:      (j['year_min'] as num?)?.toInt(),
      yearMax:      (j['year_max'] as num?)?.toInt(),
      formats:      formats,
      charts: [
        if (j['charts'] is List)
          for (final e in j['charts'] as List)
            if (e is Map && e['id'] is String)
              ChartPlaylist.fromJson(Map<String, dynamic>.from(e)),
      ],
    );
  }
}

/// One group of a collection (`list_collection_groups`): same tag-resolution
/// union as the overview. [totalCount] is -1 past the first page.
class CollectionGroupRow {
  final String? tagId;
  final String  name;
  final int     artistCount;
  final int     songCount;
  final int     totalCount;

  const CollectionGroupRow({
    this.tagId,
    required this.name,
    this.artistCount = 0,
    this.songCount = 0,
    this.totalCount = -1,
  });

  factory CollectionGroupRow.fromJson(Map<String, dynamic> j) =>
      CollectionGroupRow(
        tagId:       j['tag_id']?.toString(),
        name:        (j['name'] ?? '').toString(),
        artistCount: (j['artist_count'] as num?)?.toInt() ?? 0,
        songCount:   (j['song_count'] as num?)?.toInt() ?? 0,
        totalCount:  (j['total_count'] as num?)?.toInt() ?? -1,
      );
}

/// One `most_popular_artists` row — the hub's top-artists chips.
class PopularArtist {
  final String? artistId;
  final String  name;
  final int     playCount;

  const PopularArtist({this.artistId, required this.name, this.playCount = 0});

  factory PopularArtist.fromJson(Map<String, dynamic> j) => PopularArtist(
        artistId:  j['artist_id'] as String?,
        name:      (j['name'] ?? '').toString(),
        playCount: (j['play_count'] as num?)?.toInt() ?? 0,
      );
}

/// One subdirectory row from `browse_folder`. [dirPath] round-trips as the
/// next call's `folder`; [songCount] is recursive over the whole subtree.
class FolderEntry {
  final String name;
  final String dirPath;
  final int songCount;

  const FolderEntry({
    required this.name,
    required this.dirPath,
    required this.songCount,
  });
}

/// One `browse_folder` page: dirs first, then the songs directly in the
/// folder. [totalCount] = dirs+songs for the whole folder (pagination).
class FolderPage {
  final List<FolderEntry> dirs;
  final List<SearchResult> songs;
  final int totalCount;

  const FolderPage({
    required this.dirs,
    required this.songs,
    required this.totalCount,
  });
}

class Collection {
  final String slug;
  final String name;
  final int filesCount;

  const Collection(
      {required this.slug, required this.name, required this.filesCount});

  factory Collection.fromJson(Map<String, dynamic> j) => Collection(
        slug: j['slug'] as String,
        name: j['name'] as String,
        filesCount: (j['files_count'] as num?)?.toInt() ?? 0,
      );
}

class TagItem {
  final String slug;
  final String name;
  final String? category; // chip | group | party | saga | genre | …
  final int? usageCount;  // songs carrying this tag (list_tags RPC)
  final int? totalCount;  // total matching tags (pagination, 1st row)

  const TagItem({
    required this.slug,
    required this.name,
    this.category,
    this.usageCount,
    this.totalCount,
  });

  factory TagItem.fromJson(Map<String, dynamic> j) => TagItem(
        slug: j['slug'] as String,
        name: j['name'] as String,
        category: j['category'] as String?,
        usageCount: (j['usage_count'] as num?)?.toInt(),
        totalCount: (j['total_count'] as num?)?.toInt(),
      );
}

/// Downloadable asset (kind 'soundfont' today; UADE data / ADLMIDI banks later).
class RemoteAsset {
  final String  kind;
  final String  slug;
  final String  name;
  final String? description;
  final String  url;
  final int     sizeBytes;
  final String? sha256;
  final bool    isDefault;
  final int     sortOrder;

  const RemoteAsset({
    required this.kind,
    required this.slug,
    required this.name,
    this.description,
    required this.url,
    required this.sizeBytes,
    this.sha256,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  factory RemoteAsset.fromJson(Map<String, dynamic> j) => RemoteAsset(
        kind:        j['kind'] as String,
        slug:        j['slug'] as String,
        name:        j['name'] as String,
        description: j['description'] as String?,
        url:         j['url'] as String,
        sizeBytes:   (j['size_bytes'] as num?)?.toInt() ?? 0,
        sha256:      j['sha256'] as String?,
        isDefault:   j['is_default'] == true,
        sortOrder:   (j['sort_order'] as num?)?.toInt() ?? 0,
      );
}

/// One Milkdrop preset pack (`list_preset_packs`). [license] is heterogeneous
/// community licensing and MUST be shown on the pack card. [texturesUrl] is a
/// shared bundle: several packs can point at the SAME url (download once,
/// keyed by url); null = nothing to install. Install order: textures BEFORE
/// presets (a .milk references its bitmaps by bare name).
class PresetPack {
  final String slug;
  final String name;
  final String? description;
  final String? license;
  final String? version;     // upstream revision ('master', 'manual', …)
  final int presetCount;
  final int totalBytes;
  final bool isDefault;      // the ≤1 pack to propose by default
  final String? archiveUrl;  // bulk zip of every .milk
  final String? texturesUrl;
  // Change detection (server migs 232/233). Both hash the CONTENT, never the
  // zip bytes (a zip carries per-member timestamps, so a rebuild of identical
  // images would have looked like a change). They move INDEPENDENTLY: images
  // can change with no preset touched, and the reverse.
  // content_hash: null = empty pack (which is NOT the same as unknown).
  final String? contentHash;
  final String? texturesHash;
  final int texturesCount;
  final int texturesBytes;   // announce the weight: deepfield = 70 MB

  const PresetPack({
    required this.slug,
    required this.name,
    this.description,
    this.license,
    this.version,
    required this.presetCount,
    required this.totalBytes,
    this.isDefault = false,
    this.archiveUrl,
    this.texturesUrl,
    this.contentHash,
    this.texturesHash,
    this.texturesCount = 0,
    this.texturesBytes = 0,
  });

  factory PresetPack.fromJson(Map<String, dynamic> j) => PresetPack(
        slug:        j['slug'] as String,
        name:        (j['name'] ?? j['slug']).toString(),
        description: j['description'] as String?,
        license:     j['license'] as String?,
        version:     j['version'] as String?,
        presetCount: (j['preset_count'] as num?)?.toInt() ?? 0,
        totalBytes:  (j['total_bytes'] as num?)?.toInt() ?? 0,
        isDefault:   j['is_default'] == true,
        archiveUrl:  j['archive_url'] as String?,
        texturesUrl: j['textures_url'] as String?,
        contentHash:  j['content_hash'] as String?,
        texturesHash: j['textures_hash'] as String?,
        texturesCount: (j['textures_count'] as num?)?.toInt() ?? 0,
        texturesBytes: (j['textures_bytes'] as num?)?.toInt() ?? 0,
      );
}

/// One preset row (`browse_presets` / `search_presets` /
/// `most_popular_presets` / `get_preset_playlist_items` / `get_preset`).
/// [downloadUrl] is CDN, already percent-encoded — never re-encode it.
/// [presetId] is stable across server re-imports (uuid5 of the path) → safe
/// local cache key. Fields parsed by NAME so extra columns light up alone.
class PresetInfo {
  final String? presetId;
  final String name;
  final String? pack;         // pack slug (cross-pack rows)
  final String? path;         // server-relative path within the pack
  final String? author;
  final String? downloadUrl;
  final int fileSize;
  final String? sha256;
  final int? itemPosition;    // playlist items (column is item_position)
  final int? totalUses;       // get_preset stats
  final int? uses30d;

  const PresetInfo({
    this.presetId,
    required this.name,
    this.pack,
    this.path,
    this.author,
    this.downloadUrl,
    this.fileSize = 0,
    this.sha256,
    this.itemPosition,
    this.totalUses,
    this.uses30d,
  });

  factory PresetInfo.fromJson(Map<String, dynamic> j) {
    final stats = j['stats'] is Map ? j['stats'] as Map : const {};
    return PresetInfo(
      presetId:     (j['preset_id'] ?? j['id']) as String?,
      name:         (j['name'] ?? j['title'] ?? '').toString(),
      pack:         (j['pack'] ?? j['pack_slug']) as String?,
      path:         (j['path'] ?? j['file_path'] ?? j['rel_path']) as String?,
      author:       j['author'] as String?,
      downloadUrl:  j['download_url'] as String?,
      fileSize:     (j['file_size'] as num?)?.toInt() ?? 0,
      sha256:       j['sha256'] as String?,
      itemPosition: (j['item_position'] as num?)?.toInt(),
      totalUses:    ((j['total_uses'] ?? stats['total_uses']) as num?)?.toInt(),
      uses30d:      ((j['uses_30d'] ?? stats['uses_30d']) as num?)?.toInt(),
    );
  }
}

/// One subdirectory row from `browse_presets` (same contract as
/// `browse_folder`); [presetCount] is recursive over the subtree.
class PresetFolderEntry {
  final String name;
  final String dirPath;
  final int presetCount;

  const PresetFolderEntry({
    required this.name,
    required this.dirPath,
    required this.presetCount,
  });
}

/// One `browse_presets` page: dirs first, then the presets in the folder.
class PresetBrowsePage {
  final List<PresetFolderEntry> dirs;
  final List<PresetInfo> presets;
  final int totalCount;

  const PresetBrowsePage({
    required this.dirs,
    required this.presets,
    required this.totalCount,
  });
}

/// One server-curated preset playlist (`list_preset_playlists`).
class PresetPlaylistInfo {
  final String id;
  final String name;
  final String? description;
  final int itemCount;

  const PresetPlaylistInfo({
    required this.id,
    required this.name,
    this.description,
    required this.itemCount,
  });

  factory PresetPlaylistInfo.fromJson(Map<String, dynamic> j) =>
      PresetPlaylistInfo(
        id:          (j['id'] ?? j['playlist_id']).toString(),
        name:        (j['name'] ?? '').toString(),
        description: j['description'] as String?,
        itemCount:   ((j['item_count'] ?? j['preset_count']) as num?)?.toInt() ?? 0,
      );
}

class Playlist {
  final String id;
  final String slug;
  final String name;
  final String? description;
  final String? coverUrl;
  final int trackCount;
  final List<String> tags;
  // Why this playlist matched (list_playlists, migration 099):
  // 'direct' (name) | 'via_artist' | 'via_album' | 'via_song' | null (browse/tag).
  final String? matchReason;
  // Total matching playlists before pagination (1st row, from_offset=0), else -1.
  final int totalCount;
  // Migration 172: this playlist belongs to the calling p_user_id (server-curated
  // playlists are never owned → read-only).
  final bool isOwned;
  // Only meaningful on an owned playlist: visible to everyone in list_playlists.
  final bool isPublic;
  final DateTime? updatedAt;
  // Migration 192: private | pending | approved | rejected. Publishing is a
  // REQUEST, not a switch — a CHECK constraint forbids is_public without
  // review_status='approved', so this is the field that says where a playlist
  // stands. Absent (older server) → 'private', which shows no badge.
  final String reviewStatus;
  // Why a submission was refused. The server returns it to the OWNER only, so
  // a null here on someone else's playlist means nothing.
  final String? reviewNote;
  // Migration 193: the public display name the author is credited under. Read
  // live from `users`, never copied onto the playlist — a name the operator
  // clears disappears from what is already published.
  final String? authorName;

  /// Appartenance à la bibliothèque du COMPTE (`user_playlists`, mig 178) —
  /// null quand la réponse ne porte pas la colonne (listings publics).
  /// `false` ne veut PAS dire « inconnue »: c'est un retrait fait ailleurs, et
  /// c'est ce que la synchro doit appliquer au lieu de re-déclarer la
  /// playlist.
  final bool? inLibrary;

  const Playlist({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.coverUrl,
    this.trackCount = 0,
    this.tags = const [],
    this.matchReason,
    this.totalCount = -1,
    this.isOwned = false,
    this.isPublic = false,
    this.updatedAt,
    this.reviewStatus = 'private',
    this.reviewNote,
    this.authorName,
    this.inLibrary,
  });

  bool get isPendingReview  => reviewStatus == 'pending';
  bool get isReviewRejected => reviewStatus == 'rejected';
  bool get isApproved       => reviewStatus == 'approved';

  factory Playlist.fromJson(Map<String, dynamic> j) {
    final rawTags = j['tags'];
    final tags = <String>[];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t is Map && t['name'] is String) tags.add(t['name'] as String);
      }
    }
    return Playlist(
      id:          j['id'] as String,
      slug:        j['slug'] as String? ?? '',
      name:        j['name'] as String? ?? '?',
      description: j['description'] as String?,
      coverUrl:    j['cover_url'] as String?,
      trackCount:  (j['track_count'] as num?)?.toInt() ?? 0,
      tags:        tags,
      matchReason: j['match_reason'] as String?,
      totalCount:  (j['total_count'] as num?)?.toInt() ?? -1,
      isOwned:     j['is_owned']  == true,
      isPublic:    j['is_public'] == true,
      updatedAt:   DateTime.tryParse(j['updated_at'] as String? ?? ''),
      reviewStatus: (j['review_status'] as String?) ?? 'private',
      reviewNote:   j['review_note'] as String?,
      authorName:   j['author_name'] as String?,
      inLibrary:   j['in_library'] as bool?,
    );
  }

  Playlist copyWith({String? name, String? description, String? coverUrl,
      int? trackCount, bool? isPublic, DateTime? updatedAt,
      String? reviewStatus, String? reviewNote, String? authorName}) {
    return Playlist(
      id:          id,
      slug:        slug,
      name:        name ?? this.name,
      description: description ?? this.description,
      coverUrl:    coverUrl ?? this.coverUrl,
      trackCount:  trackCount ?? this.trackCount,
      tags:        tags,
      matchReason: matchReason,
      totalCount:  totalCount,
      isOwned:     isOwned,
      isPublic:    isPublic ?? this.isPublic,
      updatedAt:   updatedAt ?? this.updatedAt,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      reviewNote:   reviewNote ?? this.reviewNote,
      authorName:   authorName ?? this.authorName,
    );
  }
}

/// A PostgREST error surfaced to the UI (account + playlist writes are the only
/// calls where the failure MEANS something to the user — everything else in this
/// file is fire-and-forget). [code] is the SQLSTATE the server raised, e.g.
/// 23514 (invalid email / invalid code / quota), 53300 (rate limit),
/// 42501 (not your playlist), 23503 (unknown playlist or user).
/// Réponse de `set_library_batch` (voir [RewampDb.setLibraryBatch]).
class LibraryBatchRejection {
  final int index;
  final String code;
  final String message;
  const LibraryBatchRejection(this.index, this.code, this.message);
}

class LibraryBatchResult {
  final int applied;
  final List<LibraryBatchRejection> rejected;
  const LibraryBatchResult(this.applied, this.rejected);
}

class RewampRpcException implements Exception {
  final String code;
  final String message;
  final int statusCode;

  const RewampRpcException(this.code, this.message, [this.statusCode = 0]);

  /// Server messages are stable strings (see the account spec), so the UI maps
  /// on (code, message) rather than on the raw text.
  bool get isRateLimited => code == '53300';
  bool get isInvalidCode => code == '23514' && message.contains('invalid code');
  bool get isInvalidEmail => code == '23514' && message.contains('invalid email');

  @override
  String toString() => 'RewampRpcException($code, $message)';
}

/// One identity row of `user_library_ids` (migration 180): what is in the
/// library, stripped to its key. `kind` = song | album | playlist; an
/// out-of-catalogue row has a null [id] and a non-null [extKey].
class LibraryIdRow {
  final String kind;
  final String? id;
  final int? subsongIndex;
  final String? extKey;
  final DateTime? updatedAt;
  /// Le ♥, colonne serveur depuis la migration 206 (toujours false sur une
  /// ligne `playlist`: le modèle n'a pas de ♥ de playlist).
  final bool favourite;

  const LibraryIdRow({
    required this.kind,
    this.id,
    this.subsongIndex,
    this.extKey,
    this.updatedAt,
    this.favourite = false,
  });

  factory LibraryIdRow.fromJson(Map<String, dynamic> j) => LibraryIdRow(
        kind:         (j['kind'] as String?) ?? 'song',
        id:           j['id'] as String?,
        subsongIndex: (j['subsong_index'] as num?)?.toInt(),
        extKey:       j['ext_key'] as String?,
        updatedAt:    DateTime.tryParse(j['updated_at'] as String? ?? ''),
        favourite:    j['favourite'] == true,
      );
}

/// One song of the account library (`user_songs`). Deliberately NOT a
/// [SearchResult]: those rows carry no `filename`, which the search parser
/// requires — they are a library index, not a play-ready row (resolve through
/// [RewampDb.getSongContext] before playing).
class UserLibrarySong {
  final String songId;
  final String? title;
  final String? album;
  final String? collection;
  final String? platform;
  final String? artworkUrl;
  final String? downloadUrl;
  final bool inLibrary;
  /// Le ♥, colonne serveur depuis la migration 206 (avant: blob `user_state`).
  final bool favourite;
  final int playCount;
  final DateTime? lastPlayedAt;
  final DateTime? addedAt;
  /// Last change of [inLibrary] — the cursor a delta sync advances on. Null on
  /// a server that does not send it yet.
  final DateTime? updatedAt;
  /// Subsong the favourite points at. Null ⟺ out-of-catalogue row (spec §3.3):
  /// there the subsong lives in [extRef], which is what makes it authoritative.
  final int? subsongIndex;
  /// Out-of-catalogue identity + snapshot (a file of the user's own). When
  /// [extKey] is set, every catalogue column of the row is null.
  final String? extKey;
  final PlaylistExtRef? extRef;

  const UserLibrarySong({
    required this.songId,
    this.title,
    this.album,
    this.collection,
    this.platform,
    this.artworkUrl,
    this.downloadUrl,
    this.inLibrary = true,
    this.favourite = false,
    this.playCount = 0,
    this.lastPlayedAt,
    this.addedAt,
    this.updatedAt,
    this.subsongIndex,
    this.extKey,
    this.extRef,
  });

  factory UserLibrarySong.fromJson(Map<String, dynamic> j) => UserLibrarySong(
        songId:      (j['song_id'] as String?) ?? '',
        title:       j['title'] as String?,
        album:       j['album'] as String?,
        collection:  j['collection'] as String?,
        platform:    j['platform'] as String?,
        artworkUrl:  j['artwork_url'] as String?,
        downloadUrl: j['download_url'] as String?,
        inLibrary:   j['in_library'] != false,
        favourite:   j['favourite'] == true,
        playCount:   (j['play_count'] as num?)?.toInt() ?? 0,
        lastPlayedAt: DateTime.tryParse(j['last_played_at'] as String? ?? ''),
        addedAt:      DateTime.tryParse(j['added_at'] as String? ?? ''),
        updatedAt:    DateTime.tryParse(j['updated_at'] as String? ?? ''),
        subsongIndex: (j['subsong_index'] as num?)?.toInt(),
        extKey:       j['ext_key'] as String?,
        // Same snapshot shape as a rich playlist entry — one file reference
        // model for the whole app.
        extRef:       j['ext_ref'] is Map
            ? PlaylistExtRef.fromJson(
                Map<String, dynamic>.from(j['ext_ref'] as Map))
            : null,
      );
}

/// One per-track play cumul of the account (`user_play_stats`): EITHER a
/// catalogue row (songId + subsongIndex) OR an ext one (extKey + snapshot) —
/// the two kinds travel in the same list, cursored on [lastPlayedAt].
class UserPlayStat {
  final String? songId;
  final int subsongIndex;
  final String? extKey;
  final PlaylistExtRef? extRef;
  final int playCount;
  final DateTime? lastPlayedAt;

  const UserPlayStat({
    this.songId,
    this.subsongIndex = 0,
    this.extKey,
    this.extRef,
    this.playCount = 0,
    this.lastPlayedAt,
  });

  factory UserPlayStat.fromJson(Map<String, dynamic> j) => UserPlayStat(
        songId:       j['song_id'] as String?,
        subsongIndex: (j['subsong_index'] as num?)?.toInt() ?? 0,
        extKey:       j['ext_key'] as String?,
        extRef:       j['ext_ref'] is Map
            ? PlaylistExtRef.fromJson(
                Map<String, dynamic>.from(j['ext_ref'] as Map))
            : null,
        playCount:    (j['play_count'] as num?)?.toInt() ?? 0,
        lastPlayedAt: DateTime.tryParse(j['last_played_at'] as String? ?? ''),
      );
}

/// One raw ext play (`user_ext_play_history`) — the timeline a new device
/// replays into its local play_events.
class ExtPlayEvent {
  final String extKey;
  final PlaylistExtRef? extRef;
  final int durationMs;
  final DateTime? playedAt;

  const ExtPlayEvent({
    required this.extKey,
    this.extRef,
    this.durationMs = 0,
    this.playedAt,
  });

  factory ExtPlayEvent.fromJson(Map<String, dynamic> j) => ExtPlayEvent(
        extKey:     (j['ext_key'] as String?) ?? '',
        extRef:     j['ext_ref'] is Map
            ? PlaylistExtRef.fromJson(
                Map<String, dynamic>.from(j['ext_ref'] as Map))
            : null,
        durationMs: (j['duration_ms'] as num?)?.toInt() ?? 0,
        playedAt:   DateTime.tryParse(j['played_at'] as String? ?? ''),
      );
}

/// One raw play of the account (`user_play_history`, migration 221) — the
/// UNIFIED timeline, one row per listen: `kind='song'` carries a catalogue
/// identity (songId + subsongIndex), `kind='ext'` an out-of-catalogue one
/// (extKey + snapshot). Identity columns are those of [UserPlayStat], so the
/// same resolution code serves both. Retention is 24 rolling months
/// server-side; the cumuls of [UserPlayStat] never expire.
class UserPlayEvent {
  final String kind;            // 'song' | 'ext'
  final String? songId;
  final int subsongIndex;
  final String? extKey;
  final PlaylistExtRef? extRef;
  final int durationMs;
  final DateTime? playedAt;
  /// Moteur de décodage, slug tel que le client l'a envoyé (colonne ajoutée
  /// avec `p_backend`). Null = écoute antérieure, ou jamais déclarée: le
  /// serveur ne le déduit pas de l'extension et n'invente rien.
  final String? backend;

  const UserPlayEvent({
    this.kind = '',
    this.songId,
    this.subsongIndex = 0,
    this.extKey,
    this.extRef,
    this.durationMs = 0,
    this.playedAt,
    this.backend,
  });

  factory UserPlayEvent.fromJson(Map<String, dynamic> j) => UserPlayEvent(
        kind:         (j['kind'] as String?) ??
            ((j['song_id'] as String?)?.isNotEmpty == true ? 'song' : 'ext'),
        songId:       j['song_id'] as String?,
        subsongIndex: (j['subsong_index'] as num?)?.toInt() ?? 0,
        extKey:       j['ext_key'] as String?,
        extRef:       j['ext_ref'] is Map
            ? PlaylistExtRef.fromJson(
                Map<String, dynamic>.from(j['ext_ref'] as Map))
            : null,
        durationMs:   (j['duration_ms'] as num?)?.toInt() ??
            (j['played_ms'] as num?)?.toInt() ?? 0,
        playedAt:     DateTime.tryParse(j['played_at'] as String? ?? ''),
        backend:      j['backend'] as String?,
      );
}

/// One album of the account library (`user_albums`).
class UserLibraryAlbum {
  final String albumId;
  final String name;
  final String? collection;
  final String? platform;
  final String? artworkUrl;
  final String? zipUrl;
  final bool inLibrary;
  /// Le ♥, colonne serveur depuis la migration 206.
  final bool favourite;
  final DateTime? addedAt;
  final DateTime? updatedAt;

  const UserLibraryAlbum({
    required this.albumId,
    required this.name,
    this.collection,
    this.platform,
    this.artworkUrl,
    this.zipUrl,
    this.inLibrary = true,
    this.favourite = false,
    this.addedAt,
    this.updatedAt,
  });

  factory UserLibraryAlbum.fromJson(Map<String, dynamic> j) => UserLibraryAlbum(
        albumId:    (j['album_id'] as String?) ?? '',
        name:       (j['name'] as String?) ?? '?',
        collection: j['collection'] as String?,
        platform:   j['platform'] as String?,
        artworkUrl: j['artwork_url'] as String?,
        zipUrl:     j['zip_url'] as String?,
        inLibrary:  j['in_library'] != false,
        favourite:  j['favourite'] == true,
        addedAt:    DateTime.tryParse(j['added_at'] as String? ?? ''),
        updatedAt:  DateTime.tryParse(j['updated_at'] as String? ?? ''),
      );
}

/// Snapshot of the account behind the current UUID (`get_account`).
class RewampAccount {
  final String userId;
  /// null = anonymous account: nothing can recover it if this install is lost.
  final String? email;
  /// Migration 193: the public pen name, unique across accounts, that published
  /// playlists are credited to. null = never chosen — and nothing can be
  /// published until it is.
  final String? displayName;
  final bool emailVerified;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final int librarySongs;
  final int libraryAlbums;
  /// Playlists put in the library (migration 178) — distinct from [playlists],
  /// which counts the ones the user OWNS.
  final int libraryPlaylists;
  final int playlists;
  final int plays;

  const RewampAccount({
    required this.userId,
    this.email,
    this.displayName,
    this.emailVerified = false,
    this.createdAt,
    this.lastSeenAt,
    this.librarySongs = 0,
    this.libraryAlbums = 0,
    this.libraryPlaylists = 0,
    this.playlists = 0,
    this.plays = 0,
  });

  bool get isAnonymous => email == null || email!.isEmpty;

  factory RewampAccount.fromJson(Map<String, dynamic> j) => RewampAccount(
        userId:        j['user_id'] as String? ?? '',
        email:         j['email'] as String?,
        displayName:   j['display_name'] as String?,
        emailVerified: j['email_verified'] == true,
        createdAt:     DateTime.tryParse(j['created_at']  as String? ?? ''),
        lastSeenAt:    DateTime.tryParse(j['last_seen_at'] as String? ?? ''),
        librarySongs:  (j['library_songs']  as num?)?.toInt() ?? 0,
        libraryAlbums: (j['library_albums'] as num?)?.toInt() ?? 0,
        libraryPlaylists: (j['library_playlists'] as num?)?.toInt() ?? 0,
        playlists:     (j['playlists'] as num?)?.toInt() ?? 0,
        plays:         (j['plays'] as num?)?.toInt() ?? 0,
      );
}

/// Outcome of `set_display_name` (migration 193).
class DisplayNameResult {
  final String displayName;
  /// false = the name given was already the account's own, nothing happened.
  final bool changed;
  /// How many published playlists this change sent back for review. Shown after
  /// the fact; the warning itself has to come BEFORE the call.
  final int playlistsBackInReview;

  const DisplayNameResult({
    required this.displayName,
    this.changed = false,
    this.playlistsBackInReview = 0,
  });

  factory DisplayNameResult.fromJson(Map<String, dynamic> j) => DisplayNameResult(
        displayName: (j['display_name'] as String?) ?? '',
        changed: j['changed'] == true,
        playlistsBackInReview:
            (j['playlists_back_in_review'] as num?)?.toInt() ?? 0,
      );
}

/// Outcome of `verify_login_code`: which of the three situations we landed in
/// (see the account spec §2.3) plus the UUID that MUST replace the local one.
class LoginResult {
  final String userId;
  final String? email;
  /// This device's anonymous account just became the email account.
  final bool created;
  /// An existing account was joined AND this device's data was merged into it.
  final bool merged;
  /// The account's new credential (migration 188). Stored by
  /// [RewampDb.verifyLoginCode] itself — kept here only so a caller can tell a
  /// pre-token server (null) from a successful login.
  final String? token;

  const LoginResult({
    required this.userId,
    this.email,
    this.created = false,
    this.merged = false,
    this.token,
  });

  factory LoginResult.fromJson(Map<String, dynamic> j) => LoginResult(
        userId:  j['user_id'] as String? ?? '',
        email:   j['email'] as String?,
        created: j['created'] == true,
        merged:  j['merged']  == true,
        token:   j['token'] as String?,
      );
}


/// Best podium (gold/silver/bronze) of a song or an album — `compo_podium`,
/// last column of every listing RPC (migrations 184/186). null on the vast
/// majority of rows.
///
/// One object only, the BEST placement: highest rank, then `self` over
/// `production`, then the OLDEST. That last tie-break is not cosmetic — taking
/// the most recent badged "condom corruption" (the music of State of the Art,
/// 1st at The Party 1992) as a 2017 demo that merely reuses it. What makes a
/// tune interesting is its original placement.
class CompoPodium {
  /// 1, 2 or 3 — podium only.
  final int rank;
  /// 'self'       — this song/album itself competed
  /// 'production' — the demo it soundtracks placed
  /// 'song'       — (albums only) one of its songs placed
  final String via;
  final int? competitionId;
  final String? competitionName;
  final String? party;
  final int? year;
  /// Absent when the compo has no playlist (mig 183) — open the competition by
  /// [competitionId] instead, which is always there.
  final String? playlistId;
  final String? playlistName;
  final int? productionId;
  final String? production;

  const CompoPodium({
    required this.rank,
    this.via = 'self',
    this.competitionId,
    this.competitionName,
    this.party,
    this.year,
    this.playlistId,
    this.playlistName,
    this.productionId,
    this.production,
  });

  bool get isGold => rank == 1;

  static CompoPodium? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final rank = (raw['rank'] as num?)?.toInt();
    if (rank == null || rank < 1 || rank > 3) return null;
    return CompoPodium(
      rank:            rank,
      via:             (raw['via'] as String?) ?? 'self',
      competitionId:   (raw['competition_id'] as num?)?.toInt(),
      competitionName: raw['competition_name'] as String?,
      party:           raw['party'] as String?,
      year:            (raw['year'] as num?)?.toInt(),
      playlistId:      raw['playlist_id'] as String?,
      playlistName:    raw['playlist_name'] as String?,
      productionId:    (raw['production_id'] as num?)?.toInt(),
      production:      raw['production'] as String?,
    );
  }
}

/// One ranked entry of a competition (`get_competition_entries`, mig 183): a
/// PRODUCTION, with the songs/albums the catalogue has for it.
class CompetitionEntry {
  final int position;
  /// The rank as demozoo DISPLAYS it: "1", "2=", sometimes empty.
  final String ranking;
  final String? score;
  final int? productionId;
  final String title;
  final String? supertype;
  final List<String> types;
  final List<String> groups;
  final String? releaseDate;
  final String? artworkUrl;
  final String? url;
  final List<String> songIds;
  final int songCount;
  final bool hasVideo;
  final int videoCount;
  final List<String> albumIds;

  const CompetitionEntry({
    required this.position,
    this.ranking = '',
    this.score,
    this.productionId,
    required this.title,
    this.supertype,
    this.types = const [],
    this.groups = const [],
    this.releaseDate,
    this.artworkUrl,
    this.url,
    this.songIds = const [],
    this.songCount = 0,
    this.hasVideo = false,
    this.videoCount = 0,
    this.albumIds = const [],
  });

  /// Numeric rank parsed out of [ranking] ("2=" → 2), for the podium colours.
  int? get rankNumber {
    final m = RegExp(r'^(\d+)').firstMatch(ranking);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  static List<String> _ids(dynamic raw) => raw is List
      ? [for (final e in raw) if (e is String && e.isNotEmpty) e]
      : const [];

  factory CompetitionEntry.fromJson(Map<String, dynamic> j) => CompetitionEntry(
        position:     (j['entry_position'] as num?)?.toInt() ?? 0,
        ranking:      (j['ranking'] as String?) ?? '',
        score:        j['score']?.toString(),
        productionId: (j['production_id'] as num?)?.toInt(),
        title:        (j['title'] as String?) ?? '?',
        supertype:    j['supertype'] as String?,
        types:        _ids(j['types']),
        groups:       _ids(j['groups']),
        releaseDate:  j['release_date'] as String?,
        artworkUrl:   j['artwork_url'] as String?,
        url:          j['url'] as String?,
        songIds:      _ids(j['song_ids']),
        songCount:    (j['song_count'] as num?)?.toInt() ?? 0,
        hasVideo:     j['has_video'] == true,
        videoCount:   (j['video_count'] as num?)?.toInt() ?? 0,
        albumIds:     _ids(j['album_ids']),
      );
}

/// One slot of the calendar-driven "featured" rail (list_featured, migration 115).
///
/// The reason label is NOT taken from the server's pre-rendered [reason] string:
/// we render it ourselves from [reasonKey] + [reasonParams] through the ARB/ICU
/// catalogue (see `FeaturedReason.render`). That is the reference contract — it
/// is the only way to get correct plural rules in Russian/Polish/Czech, and it
/// makes a new UI language a client-side change only. [reason] is kept as a
/// last-resort fallback for a key this build doesn't know yet.
class FeaturedSlot {
  final int position;
  /// playlist | album | song | **competition** (migration 186).
  final String kind;
  /// UUID of the playlist/album/song. EMPTY on a `competition` row — a compo is
  /// identified by an integer, which cannot travel in a uuid column, so it
  /// comes in [competitionId] instead. Routing must therefore switch on [kind],
  /// never on this id.
  final String id;
  /// Set only when [kind] == 'competition' → `get_competition_entries`.
  final int? competitionId;
  final String name;
  final String? artworkUrl;
  final String? collection; // null for a playlist
  final int trackCount;
  final int? year;
  final String reason;      // server-rendered, fallback only
  final String reasonKey;   // party.now | party.starts_in | party.season |
                            // month.released | anniversary.years_ago
  final Map<String, dynamic> reasonParams; // {party,series,days,month,year,age,decade}
  final String rule;        // party | month | anniversary | manual

  // ── Series grouping (added with the featured v2 contract) ────────────────
  // Rows sharing a non-null [groupKey] form a series (party:<série>, month:<MM>,
  // anniversary). null = a standalone card. The server already returns rows
  // sorted and contiguous by section, so a simple groupBy preserves order.
  final String? groupKey;
  // The section header, rendered client-side from [groupReasonKey] +
  // [groupReasonParams] through the same ICU catalogue as the card reason
  // (party.* keys are shared; sections also use month.header / anniversary.header).
  final String? groupReasonKey;
  final Map<String, dynamic> groupReasonParams;
  final String? groupReason; // server-rendered, last-resort fallback

  /// Demozoo's own description of the party this SERIES belongs to, and the
  /// party's site (list_featured, last two columns of a party section). Raw
  /// demozoo text: a third of the corpus carries HTML and a few use Markdown
  /// links, so it must go through [noteHtmlToMarkdown] / NoteMarkdown before it
  /// is shown — and it is not always a blurb (Assembly's is an archival
  /// caveat), so it is context, never a headline.
  final String? groupNote;
  final String? groupUrl;

  /// Pen name of the author, for a COMMUNITY row. Never sent by
  /// `list_featured` — the home rail appends the newest published user
  /// playlists itself (see [FeaturedSlot.fromPlaylist]), and this is what makes
  /// them recognisable among the editorial cards.
  final String? authorName;

  const FeaturedSlot({
    required this.position,
    required this.kind,
    required this.id,
    this.competitionId,
    required this.name,
    this.artworkUrl,
    this.collection,
    this.trackCount = 0,
    this.year,
    this.reason = '',
    this.reasonKey = '',
    this.reasonParams = const {},
    this.rule = '',
    this.groupKey,
    this.groupReasonKey,
    this.groupReasonParams = const {},
    this.groupReason,
    this.groupNote,
    this.groupUrl,
    this.authorName,
  });

  /// A published user playlist rendered as a featured slot. [groupKey] makes
  /// the rail fold them into ONE card that opens the list of them, exactly as a
  /// party series does; the card shows the author, and tapping a row routes
  /// like any other playlist slot (kind + uuid).
  factory FeaturedSlot.fromPlaylist(Playlist p, int position,
          {String? groupKey}) =>
      FeaturedSlot(
        position:   position,
        kind:       'playlist',
        id:         p.id,
        name:       p.name,
        artworkUrl: p.coverUrl,
        trackCount: p.trackCount,
        authorName: p.authorName,
        groupKey:   groupKey,
      );

  factory FeaturedSlot.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> params(Object? raw) => raw is Map
        ? raw.map((k, v) => MapEntry(k.toString(), v))
        : const {};
    return FeaturedSlot(
      position:     (j['position'] as num?)?.toInt() ?? 0,
      kind:         j['kind'] as String? ?? '',
      id:           j['id'] as String? ?? '',
      competitionId: (j['competition_id'] as num?)?.toInt(),
      name:         j['name'] as String? ?? '?',
      artworkUrl:   j['artwork_url'] as String?,
      collection:   j['collection'] as String?,
      trackCount:   (j['track_count'] as num?)?.toInt() ?? 0,
      year:         (j['year'] as num?)?.toInt(),
      reason:       j['reason'] as String? ?? '',
      reasonKey:    j['reason_key'] as String? ?? '',
      reasonParams: params(j['reason_params']),
      rule:         j['rule'] as String? ?? '',
      groupKey:         j['group_key'] as String?,
      groupReasonKey:   j['group_reason_key'] as String?,
      groupReasonParams: params(j['group_reason_params']),
      groupReason:      j['group_reason'] as String?,
      groupNote:        j['group_note'] as String?,
      groupUrl:         j['group_url'] as String?,
    );
  }
}

class MusicFormat {
  final String name;
  final String extension;
  final int? songCount; // list_formats usage count (per-collection when scoped)

  const MusicFormat(
      {required this.name, required this.extension, this.songCount});

  factory MusicFormat.fromJson(Map<String, dynamic> j) => MusicFormat(
        name: j['name'] as String,
        extension: j['extension'] as String,
        songCount: (j['song_count'] as num?)?.toInt(),
      );
}

class Artist {
  final String id;
  final String name;

  const Artist({required this.id, required this.name});

  factory Artist.fromJson(Map<String, dynamic> j) => Artist(
        id: j['id'] as String,
        name: j['name'] as String,
      );
}

/// One row of the `search_artists` RPC (Artistes tab of cross-entity search,
/// migration 098). Replaces the old client-side derivation of artists from the
/// song page. Aggregates (song/album counts, avg_rating) are over the *connected*
/// songs: full filtered catalog for a `direct` (name) match, only the matched
/// tracks for a `via_song`/`via_album` hop.
class ArtistResult {
  final String artistId;
  final String name;
  final String? country;      // ISO 3166-1 alpha-2
  final String? realName;     // disambiguates same-name artists in lists
  final int songCount;
  final int albumCount;
  final List<String> collections;
  final List<String> platforms;
  final double? avgRating;    // popularity = avg rating of connected songs
  final String? artworkUrl;
  final int totalCount;       // total before pagination (1st row), else -1
  final String? matchReason;  // direct | via_song | via_album | null (browse)
  final double matchRank;     // quality score (migration 100); 1.0 = exact substring

  /// `total_count` n'est qu'un PLANCHER (migration serveur 247, dernière
  /// colonne). Le serveur borne son décompte sur les recherches très larges;
  /// quand il l'a fait, il le DIT au lieu de rendre un nombre qui a l'air
  /// exact. Une seule conséquence côté client: écrire « 4403+ ».
  final bool totalTruncated;

  const ArtistResult({
    required this.artistId,
    required this.name,
    this.country,
    this.realName,
    this.songCount = 0,
    this.albumCount = 0,
    this.collections = const [],
    this.platforms = const [],
    this.avgRating,
    this.artworkUrl,
    this.totalCount = -1,
    this.matchReason,
    this.matchRank = 0,
    this.totalTruncated = false,
  });

  factory ArtistResult.fromJson(Map<String, dynamic> j) => ArtistResult(
        artistId:    j['artist_id'] as String,
        name:        j['name'] as String? ?? '?',
        country:     j['country'] as String?,
        realName:    j['real_name'] as String?,
        songCount:   (j['song_count'] as num?)?.toInt() ?? 0,
        albumCount:  (j['album_count'] as num?)?.toInt() ?? 0,
        collections: AlbumDetails._toStrList(j['collections']),
        platforms:   AlbumDetails._toStrList(j['platforms']),
        avgRating:   (j['avg_rating'] as num?)?.toDouble(),
        artworkUrl:  j['artwork_url'] as String?,
        totalCount:  (j['total_count'] as num?)?.toInt() ?? -1,
        matchReason: j['match_reason'] as String?,
        matchRank:   (j['match_rank'] as num?)?.toDouble() ?? 0,
        // Absente d'un serveur antérieur à la 247 ⇒ false: un total non borné.
        totalTruncated: j['truncated'] == true,
      );
}

/// One `(facet_kind, value, count)` row of the `search_facets` RPC (migration
/// 098). Feeds the Format/Platform/Collection filter dropdowns with true totals
/// over the whole candidate set (client-side derivation is wrong under pagination).
/// The counted dimension is NOT filtered by its own value, so a dropdown keeps
/// all its options even while that dimension is selected.
class FacetCount {
  final String kind;   // 'format' | 'platform' | 'collection' | 'podium' (value '1'-'3', un rang par ligne)
  final String value;  // extension / platform name / collection slug
  final int count;     // candidate songs bearing this value

  const FacetCount({required this.kind, required this.value, required this.count});

  factory FacetCount.fromJson(Map<String, dynamic> j) => FacetCount(
        kind:  j['facet_kind'] as String,
        value: j['value'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// Full context of one song via `get_song_context` (single RPC call): a
/// play-ready row (download_url + aux_files included) plus artists and tags
/// grouped by category — the "rebond" chips of the song context panel.
/// One demozoo production video linked to a song (song_videos, mig 147).
/// kind 'own' = the song's own production; 'used_in' = the song was used in
/// that production; placed = the production placed in its compo.
class SongVideo {
  final String  provider;   // 'youtube' | 'vimeo'
  final String  url;
  final String? thumbnail;
  final String? title;
  final String  kind;       // 'own' | 'used_in'
  final bool    placed;
  /// Provider-side id, server-cleaned. The `url` is raw demozoo data and can
  /// carry junk after the id ("…?v=ID/688"), so prefer this when it is there.
  final String? videoId;
  /// The production this video documents — the key report_video wants.
  /// Present on get_song_context / get_playlist_tracks videos; null on
  /// get_production_details ones (the screen knows its own id there), and null
  /// on a MANUAL video, attached straight to a song with no production behind
  /// it — that one is reported by [songId] instead.
  final int?    productionId;
  /// The song a manual (production-less) video hangs off. Sent by the server
  /// when it has one; otherwise the screen supplies the song it fetched the
  /// videos for. Only consulted when [productionId] is null.
  final String? songId;
  /// Where the tune starts inside the capture, when demozoo says so.
  final int?    startSeconds;

  const SongVideo({
    required this.provider,
    required this.url,
    this.thumbnail,
    this.title,
    this.kind = 'own',
    this.placed = false,
    this.videoId,
    this.productionId,
    this.songId,
    this.startSeconds,
  });

  static List<SongVideo> listFrom(dynamic raw) {
    if (raw is! List) return const []; // null / absent = no videos (common)
    final out = <SongVideo>[];
    for (final e in raw) {
      if (e is Map && e['url'] is String && (e['url'] as String).isNotEmpty) {
        out.add(SongVideo(
          provider:  (e['provider'] ?? '').toString(),
          url:       e['url'] as String,
          thumbnail: e['thumbnail'] as String?,
          title:     e['title'] as String?,
          kind:      (e['kind'] ?? 'own').toString(),
          placed:    e['placed'] == true,
          videoId:   e['video_id'] as String?,
          productionId: (e['production_id'] as num?)?.toInt(),
          songId:       e['song_id'] as String?,
          startSeconds: (e['start_seconds'] as num?)?.toInt(),
        ));
      }
    }
    return out;
  }

  /// In-app embed URL (autoplay). YouTube watch/short/youtu.be and Vimeo page
  /// URLs → their player embeds; anything unrecognized loads as-is.
  String get embedUrl {
    final u = Uri.tryParse(url);
    if (u == null) return url;
    final host = u.host.toLowerCase();
    String? ytId;
    if (host.endsWith('youtu.be')) {
      ytId = u.pathSegments.isNotEmpty ? u.pathSegments.first : null;
    } else if (host.contains('youtube.com')) {
      ytId = u.queryParameters['v'];
      if (ytId == null &&
          u.pathSegments.length >= 2 &&
          (u.pathSegments.first == 'shorts' ||
              u.pathSegments.first == 'embed')) {
        ytId = u.pathSegments[1];
      }
    }
    if (ytId != null && ytId.isNotEmpty) {
      // Demozoo data carries dirty ids ("J8515VaCgw8/688", "ID&t=30") — a video
      // id is 11 chars of [A-Za-z0-9_-]; anything after that is junk that would
      // make the embed 404. The server-cleaned video_id wins when present.
      final m = RegExp(r'^[A-Za-z0-9_-]{11}').firstMatch(videoId ?? ytId);
      if (m != null) ytId = m.group(0);
      // fs=0: the embed's own fullscreen button can't work inside the app's
      // WebView frame (and our screen IS the fullscreen mode).
      return 'https://www.youtube.com/embed/$ytId'
          '?autoplay=1&playsinline=1&fs=0'
          '${(startSeconds ?? 0) > 0 ? '&start=$startSeconds' : ''}';
    }
    if (host.contains('vimeo.com')) {
      final id = u.pathSegments.lastWhere(
          (s) => int.tryParse(s) != null, orElse: () => '');
      if (id.isNotEmpty) {
        return 'https://player.vimeo.com/video/$id?autoplay=1';
      }
    }
    return url;
  }
}

/// One demozoo note attached to a song. kind 'own' = the tune's own note;
/// 'used_in' = the note of a production that uses the tune. Server-sorted:
/// used_in first, then placed productions — display the first, badge the rest.
class SongNote {
  final String  kind;      // 'own' | 'used_in'
  final String? title;     // production / tune title
  final String  note;      // Markdown (links to demozoo.org)
  final String? url;       // demozoo page of the noted entity
  final bool    placed;    // the production placed in its compo

  const SongNote({
    this.kind = 'own',
    this.title,
    required this.note,
    this.url,
    this.placed = false,
  });

  static List<SongNote> listFrom(dynamic raw) {
    if (raw is! List) return const []; // null / absent = no notes (common)
    final out = <SongNote>[];
    for (final e in raw) {
      if (e is Map && e['note'] is String && (e['note'] as String).trim().isNotEmpty) {
        out.add(SongNote(
          kind:   (e['kind'] ?? 'own').toString(),
          title:  e['title'] as String?,
          note:   (e['note'] as String).trim(),
          url:    e['url'] as String?,
          placed: e['placed'] == true,
        ));
      }
    }
    return out;
  }
}

/// One demozoo PRODUCTION attached to a song or an album (migs 161-163).
/// Replaces the old `tags.production` strings: productions are now entities
/// with an id, so two "Megademo" no longer collapse into one tag. [kind]:
/// 'used_in' = the demo/intro/musicdisk this tune is used in (what the old
/// chips meant); 'own' = the tune's OWN demozoo entry (a link, not a browse).
class ProductionRef {
  final int          id;
  final String       title;
  final String       kind;         // 'used_in' | 'own'
  final int?         position;     // soundtrack order inside the production
  final String?      supertype;    // 'production' | 'graphics' | …
  final List<String> types;        // ['Demo'], ['Intro'], …
  final List<String> groups;       // ['Future Crew']
  final String?      releaseDate;  // ISO 'YYYY-MM-DD' (precision varies)
  final String?      datePrecision;// 'd' | 'm' | 'y'
  final String?      url;          // demozoo.org page
  final String?      artworkUrl;

  const ProductionRef({
    required this.id,
    required this.title,
    this.kind = 'used_in',
    this.position,
    this.supertype,
    this.types = const [],
    this.groups = const [],
    this.releaseDate,
    this.datePrecision,
    this.url,
    this.artworkUrl,
  });

  /// Release year, when the server sent a parsable date.
  int? get year {
    final d = releaseDate;
    if (d == null || d.length < 4) return null;
    return int.tryParse(d.substring(0, 4));
  }

  /// Chip text: the title alone is ambiguous (several "Megademo"), so the
  /// releasing group and/or the year disambiguate when known.
  String get label {
    final extra = [
      if (groups.isNotEmpty) groups.first,
      if (year != null) '$year',
    ];
    return extra.isEmpty ? title : '$title (${extra.join(', ')})';
  }

  /// Subtitle line for a production header/row: types + groups + year.
  String get subtitle => [
        ...types,
        if (groups.isNotEmpty) groups.join(', '),
        if (year != null) '$year',
      ].join(' · ');

  static ProductionRef? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final id = (raw['id'] ?? raw['production_id']) as num?;
    final title = raw['title'] as String?;
    if (id == null || title == null || title.isEmpty) return null;
    return ProductionRef(
      id:            id.toInt(),
      title:         title,
      kind:          (raw['kind'] ?? 'used_in').toString(),
      position:      (raw['position'] as num?)?.toInt(),
      supertype:     raw['supertype'] as String?,
      types:         AlbumDetails._toStrList(raw['types']),
      groups:        AlbumDetails._toStrList(raw['groups']),
      releaseDate:   raw['release_date'] as String?,
      datePrecision: raw['date_precision'] as String?,
      // Song/album context says `url`; list_productions and
      // search_productions say `demozoo_url` — same link either way.
      url:           (raw['url'] ?? raw['demozoo_url']) as String?,
      artworkUrl:    raw['artwork_url'] as String?,
    );
  }

  static List<ProductionRef> listFrom(dynamic raw) {
    if (raw is! List) return const []; // null / absent = none (common)
    final out = <ProductionRef>[];
    for (final e in raw) {
      final p = ProductionRef.fromJson(e);
      if (p != null) out.add(p);
    }
    return out;
  }
}

/// Full production sheet via `get_production_details(p_production_id)` — the
/// header of the production screen, whose track list comes from
/// `get_production_tracks` (same columns as get_playlist_tracks).
class ProductionDetails {
  final int          id;
  final String       title;
  final List<String> types;
  final List<String> groups;
  final String?      releaseDate;
  final String?      datePrecision;
  final String?      url;          // demozoo.org page
  final String?      artworkUrl;   // screenshot
  final int          songCount;
  final int          albumCount;
  final List<SongVideo> videos;

  const ProductionDetails({
    required this.id,
    required this.title,
    this.types = const [],
    this.groups = const [],
    this.releaseDate,
    this.datePrecision,
    this.url,
    this.artworkUrl,
    this.songCount = 0,
    this.albumCount = 0,
    this.videos = const [],
  });

  int? get year {
    final d = releaseDate;
    if (d == null || d.length < 4) return null;
    return int.tryParse(d.substring(0, 4));
  }

  String get subtitle => [
        ...types,
        if (groups.isNotEmpty) groups.join(', '),
        if (year != null) '$year',
      ].join(' · ');

  factory ProductionDetails.fromJson(Map<String, dynamic> j) =>
      ProductionDetails(
        id:            ((j['id'] ?? j['production_id']) as num?)?.toInt() ?? 0,
        title:         (j['title'] ?? '').toString(),
        types:         AlbumDetails._toStrList(j['types']),
        groups:        AlbumDetails._toStrList(j['groups']),
        releaseDate:   j['release_date'] as String?,
        datePrecision: j['date_precision'] as String?,
        url:           (j['url'] ?? j['demozoo_url']) as String?,
        artworkUrl:    (j['artwork_url'] ?? j['screenshot_url']) as String?,
        songCount:     (j['song_count'] as num?)?.toInt() ?? 0,
        albumCount:    (j['album_count'] as num?)?.toInt() ?? 0,
        videos:        SongVideo.listFrom(j['videos']),
      );
}

/// One `search_productions` / `list_productions` row — already disambiguated
/// server-side. [hasVideo] is the PRODUCTION's own demozoo video (the very set
/// `get_production_details.videos[]` returns), not "one of its tunes has one".
///
/// Parsed BY NAME: search_productions v2 inserted `has_video` before
/// `total_count`, which would have shifted an index-based parser.
class ProductionSearchRow {
  final ProductionRef production;
  final int songCount;
  final bool hasVideo;
  final int videoCount;
  final int totalCount;   // total matches, for paging

  const ProductionSearchRow(
      {required this.production,
      this.songCount = 0,
      this.hasVideo = false,
      this.videoCount = 0,
      this.totalCount = 0});

  /// Nothing playable, but there IS a video: the row's only action is
  /// watching it (get_production_tracks comes back empty for these).
  bool get isVideoOnly => songCount == 0 && hasVideo;

  static ProductionSearchRow? fromJson(Map<String, dynamic> j) {
    final p = ProductionRef.fromJson(j);
    if (p == null) return null;
    final videoCount = (j['video_count'] as num?)?.toInt() ?? 0;
    return ProductionSearchRow(
      production: p,
      songCount:  (j['song_count'] as num?)?.toInt() ?? 0,
      hasVideo:   j['has_video'] == true || videoCount > 0,
      videoCount: videoCount,
      totalCount: (j['total_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Per-subsong score of a multi-subsong file (mv_subsong_scores): same
/// formulas as the file-grain 207/208 but per (song, subsong), and the
/// percentile lives on its OWN scale (all listened subsongs) — never compare
/// it with a file-grain popularity. Rating is NULL under 5 listeners, which
/// at this grain is almost always: show popularity first.
class SubsongScore {
  final int     subsong;
  final int     listeners;
  final int?    popularity;
  final double? rating;

  const SubsongScore({
    required this.subsong,
    this.listeners = 0,
    this.popularity,
    this.rating,
  });

  static Map<int, SubsongScore> mapFrom(dynamic raw) {
    if (raw is! List) return const {};
    final out = <int, SubsongScore>{};
    for (final e in raw) {
      if (e is! Map) continue;
      final sub = (e['subsong'] as num?)?.toInt();
      if (sub == null) continue;
      out[sub] = SubsongScore(
        subsong:    sub,
        listeners:  (e['listeners'] as num?)?.toInt() ?? 0,
        popularity: (e['popularity'] as num?)?.toInt(),
        rating:     (e['rating'] as num?)?.toDouble(),
      );
    }
    return out;
  }
}

class SongContext {
  final SearchResult song;
  final List<Artist> artists;
  final Map<String, List<String>> tags; // category → tag names
  /// Demozoo production videos (placed-in-compo first, server-ordered).
  final List<SongVideo> videos;
  /// Demozoo notes (used_in productions first, server-ordered).
  final List<SongNote> notes;
  /// Demozoo productions this tune belongs to (mig 161-163) — REPLACES the old
  /// `tags['production']` strings, which the server no longer sends.
  final List<ProductionRef> productions;
  /// Observed subsongs of a multi-subsong file, keyed by subsong index
  /// (`subsong_scores`, files with track_count>1 only; empty otherwise).
  final Map<int, SubsongScore> subsongScores;

  const SongContext(
      {required this.song,
      this.artists = const [],
      this.tags = const {},
      this.videos = const [],
      this.notes = const [],
      this.productions = const [],
      this.subsongScores = const {}});

  /// The productions the tune is USED IN (the old chips). The tune's own
  /// demozoo entry ([ownProduction]) is a link, not a browse target.
  List<ProductionRef> get usedIn =>
      productions.where((p) => p.kind != 'own').toList();

  ProductionRef? get ownProduction {
    for (final p in productions) {
      if (p.kind == 'own') return p;
    }
    return null;
  }

  factory SongContext.fromJson(Map<String, dynamic> j) {
    final artists = <Artist>[];
    final rawArtists = j['artists'];
    if (rawArtists is List) {
      for (final a in rawArtists) {
        if (a is Map<String, dynamic> && a['id'] is String && a['name'] is String) {
          artists.add(Artist.fromJson(a));
        }
      }
    }
    final tags = <String, List<String>>{};
    final rawTags = j['tags'];
    if (rawTags is Map) {
      rawTags.forEach((k, v) {
        if (v is List) {
          final names = v.whereType<String>().toList();
          if (names.isNotEmpty) tags['$k'] = names;
        }
      });
    }
    // Shape the payload like a search row so SearchResult.fromJson applies
    // (context has artists[{id,name}] instead of artist_names).
    final m = Map<String, dynamic>.of(j);
    m['artist_names'] = artists.map((a) => a.name).toList();
    return SongContext(
        song: SearchResult.fromJson(m),
        artists: artists,
        tags: tags,
        videos: SongVideo.listFrom(j['videos']),
        notes: SongNote.listFrom(j['notes']),
        productions: ProductionRef.listFrom(j['productions']),
        subsongScores: SubsongScore.mapFrom(j['subsong_scores']));
  }
}

/// One AMP (Amiga Music Preservation) handle for an artist: the historical
/// nickname plus how many modules are archived under it.
class ArtistAmp {
  final String? ampId;
  final String  handle;
  final int     moduleCount;

  const ArtistAmp({this.ampId, required this.handle, this.moduleCount = 0});

  factory ArtistAmp.fromJson(Map<String, dynamic> j) => ArtistAmp(
        ampId:       j['amp_id']?.toString(),
        handle:      (j['handle'] ?? '').toString(),
        moduleCount: (j['module_count'] as num?)?.toInt() ?? 0,
      );
}

/// One searchable artist tag: `{name, category}` (category from the
/// list_tag_categories namespace — 'group', 'party', …; null when the server
/// sent a bare string).
class ArtistTag {
  final String  name;
  final String? category;
  const ArtistTag(this.name, this.category);
}

/// Full artist profile via `get_artist_details(p_name, p_artist_id)` — one JSONB
/// blob. Everything is optional: any field the server omits degrades to
/// null/empty and the header simply hides that row. `tags` are the SEARCHABLE
/// set (same name namespace as `list_tag_categories`), now typed with their
/// category — groups live there with category 'group', which is what makes the
/// "Groupes" chips clickable. `collections`/`countries` stay display-only.
class ArtistDetails {
  final String        name;
  final String?       country;
  final String?       bio;
  final String?       birthDate;
  final String?       birthSource;
  final String?       realName;
  final List<String>  aliases;
  final List<String>  countries;
  final List<String>  groups;
  final String?       interviewUrl;
  final List<ArtistAmp> amp;
  final int           songCount;
  final List<String>  collections;
  final List<ArtistTag> tags;
  /// Demozoo scener note (Markdown) + its demozoo page. Null when none.
  final String?       notes;
  final String?       notesUrl;

  /// Header chips: every searchable tag EXCEPT groups (those render as their
  /// own clickable section in "À propos" — avoids the same names twice).
  List<ArtistTag> get nonGroupTags =>
      [for (final t in tags) if (t.category != 'group') t];

  /// Group memberships — derived from the typed tags (category 'group');
  /// the legacy top-level `groups` array was removed server-side (mig 144).
  /// Every entry is in the searchable tag namespace by construction.
  List<String> get groupNames =>
      [for (final t in tags) if (t.category == 'group') t.name];

  const ArtistDetails({
    required this.name,
    this.country,
    this.bio,
    this.birthDate,
    this.birthSource,
    this.realName,
    this.aliases     = const [],
    this.countries   = const [],
    this.groups      = const [],
    this.interviewUrl,
    this.amp         = const [],
    this.songCount   = 0,
    this.collections = const [],
    this.tags        = const [],
    this.notes,
    this.notesUrl,
  });

  /// Accepts a list of bare strings OR objects ({name|label|value|tag}); drops
  /// blanks. Robust to whichever shape the server settles on per field.
  static List<String> _nameList(dynamic v) {
    if (v is! List) return const [];
    final out = <String>[];
    for (final e in v) {
      if (e is String) {
        if (e.trim().isNotEmpty) out.add(e);
      } else if (e is Map) {
        final n = e['name'] ?? e['label'] ?? e['value'] ?? e['tag'];
        if (n is String && n.trim().isNotEmpty) out.add(n);
      }
    }
    return out;
  }

  static String? _str(dynamic v) {
    if (v is String && v.trim().isNotEmpty) return v;
    return null;
  }

  /// Tags arrive as `{name, category}` objects (post-2026-07 server) or bare
  /// strings (older shape) — accept both, drop blanks.
  static List<ArtistTag> _tagList(dynamic v) {
    if (v is! List) return const [];
    final out = <ArtistTag>[];
    for (final e in v) {
      if (e is String) {
        if (e.trim().isNotEmpty) out.add(ArtistTag(e, null));
      } else if (e is Map) {
        final n = e['name'] ?? e['label'] ?? e['value'] ?? e['tag'];
        if (n is String && n.trim().isNotEmpty) {
          final c = e['category'];
          out.add(ArtistTag(n, c is String && c.isNotEmpty ? c : null));
        }
      }
    }
    return out;
  }

  factory ArtistDetails.fromJson(Map<String, dynamic> j) {
    final amp = <ArtistAmp>[];
    final rawAmp = j['amp'];
    if (rawAmp is List) {
      for (final a in rawAmp) {
        if (a is Map<String, dynamic>) amp.add(ArtistAmp.fromJson(a));
      }
    }
    return ArtistDetails(
      name:         (j['name'] ?? '').toString(),
      country:      _str(j['country']),
      bio:          _str(j['bio']),
      birthDate:    _str(j['birth_date']),
      birthSource:  _str(j['birth_source']),
      realName:     _str(j['real_name']),
      aliases:      _nameList(j['aliases']),
      countries:    _nameList(j['countries']),
      groups:       _nameList(j['groups']),
      interviewUrl: _str(j['interview_url']),
      amp:          amp,
      songCount:    (j['song_count'] as num?)?.toInt() ?? 0,
      collections:  _nameList(j['collections']),
      tags:         _tagList(j['tags']),
      notes:        _str(j['notes']),
      notesUrl:     _str(j['notes_url']),
    );
  }

  /// True when nothing beyond the bare name is present — the header hides
  /// itself entirely rather than showing an empty card.
  bool get isEmpty =>
      country == null &&
      bio == null &&
      birthDate == null &&
      realName == null &&
      interviewUrl == null &&
      aliases.isEmpty &&
      countries.isEmpty &&
      groups.isEmpty &&
      amp.isEmpty &&
      collections.isEmpty &&
      tags.isEmpty &&
      notes == null;
}

/// Per-entity totals of a group (`get_group_details.counts`, mig 201).
///
/// Computed by the same formulas as the listings (a song counts when the tag is
/// on it, on its album or on one of its artists), from a materialized view
/// refreshed by the imports — so a badge can trail a live listing by a unit or
/// two. That is expected, not an error: once a list is loaded, prefer its own
/// `total_count`. Never recompute these client-side from something else.
class GroupCounts {
  final int songs, artists, members, albums, playlists, productions, videos;

  const GroupCounts({
    this.songs = 0,
    this.artists = 0,
    this.members = 0,
    this.albums = 0,
    this.playlists = 0,
    this.productions = 0,
    this.videos = 0,
  });

  factory GroupCounts.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return GroupCounts(
      songs:       n('songs'),
      artists:     n('artists'),
      members:     n('members'),
      albums:      n('albums'),
      playlists:   n('playlists'),
      productions: n('productions'),
      videos:      n('videos'),
    );
  }
}

/// Group profile via `get_group_details(p_name | p_tag_id)` — demozoo note,
/// members and per-tab counts. Null server-side when the group is unknown.
class GroupDetails {
  final String        name;
  final String?       tagId;     // null for a group known only via productions
  final String?       note;      // Markdown
  final String?       notesUrl;  // demozoo group page
  final String?       notesFormat;
  /// ⚠️ MEMBERS, not "artists with a song" — it goes with [artists] and equals
  /// `counts.members`. The Artists tab must use `counts.artists` instead
  /// (161 artists have an Abyss track; 29 people are members).
  final int           artistCount;
  final List<Artist>  artists;   // members (server-capped at 200)
  final GroupCounts   counts;

  const GroupDetails({
    required this.name,
    this.tagId,
    this.note,
    this.notesUrl,
    this.notesFormat,
    this.artistCount = 0,
    this.artists = const [],
    this.counts = const GroupCounts(),
  });

  factory GroupDetails.fromJson(Map<String, dynamic> j) {
    final artists = <Artist>[];
    final raw = j['artists'];
    if (raw is List) {
      for (final a in raw) {
        if (a is Map<String, dynamic> &&
            a['id'] is String &&
            a['name'] is String) {
          artists.add(Artist.fromJson(a));
        }
      }
    }
    String? str(dynamic v) =>
        v is String && v.trim().isNotEmpty ? v : null;
    final c = j['counts'];
    return GroupDetails(
      name:        (j['name'] ?? '').toString(),
      tagId:       str(j['tag_id']),
      note:        str(j['note']),
      notesUrl:    str(j['notes_url']),
      notesFormat: str(j['notes_format']),
      artistCount: (j['artist_count'] as num?)?.toInt() ?? artists.length,
      artists:     artists,
      counts: c is Map<String, dynamic>
          ? GroupCounts.fromJson(c)
          : const GroupCounts(),
    );
  }
}

/// One row of `search_groups` (mig 201) — the Groups search tab.
///
/// `tagId` is NULL for the 1605 groups (of 14 697) known only through
/// `productions.groups`: they have no tag, hence `songCount == 0`, and they are
/// addressed by NAME alone. That is not an anomaly — do not filter them out
/// (use `only_with_content` when only servable groups are wanted).
class GroupSearchResult {
  final String? tagId;
  final String  name;
  final int     songCount, artistCount, memberCount;
  final int     albumCount, playlistCount, productionCount, videoCount;
  final bool    hasNote;
  final double? relevance;   // null when q is empty (browse)
  /// -1 as soon as `from_offset > 0` — the server only counts the first page.
  /// Never render that as "0 result".
  final int     totalCount;

  const GroupSearchResult({
    required this.name,
    this.tagId,
    this.songCount = 0,
    this.artistCount = 0,
    this.memberCount = 0,
    this.albumCount = 0,
    this.playlistCount = 0,
    this.productionCount = 0,
    this.videoCount = 0,
    this.hasNote = false,
    this.relevance,
    this.totalCount = -1,
  });

  static GroupSearchResult? fromJson(Map<String, dynamic> j) {
    final name = (j['name'] ?? '').toString();
    if (name.isEmpty) return null;
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    final id = j['tag_id'];
    return GroupSearchResult(
      name:            name,
      tagId:           id is String && id.isNotEmpty ? id : null,
      songCount:       n('song_count'),
      artistCount:     n('artist_count'),
      memberCount:     n('member_count'),
      albumCount:      n('album_count'),
      playlistCount:   n('playlist_count'),
      productionCount: n('production_count'),
      videoCount:      n('video_count'),
      hasNote:         j['has_note'] == true,
      relevance:       (j['relevance'] as num?)?.toDouble(),
      totalCount:      (j['total_count'] as num?)?.toInt() ?? -1,
    );
  }

  /// Anything to open a tab on. A tag-less group still has its productions.
  bool get hasContent =>
      songCount > 0 || productionCount > 0 || videoCount > 0;
}

class AlbumAlias {
  final String name;
  final String? region;
  final String? language;

  const AlbumAlias({required this.name, this.region, this.language});

  factory AlbumAlias.fromJson(Map<String, dynamic> j) => AlbumAlias(
        name: j['name'] as String,
        region: j['region'] as String?,
        language: j['language'] as String?,
      );

  /// "Name (region)" or just "Name" when region is absent.
  String get label {
    final tag = region ?? language;
    return tag != null ? '$name ($tag)' : name;
  }
}

class ArtistAlbum {
  final String name;
  final String collection;
  final String? platform;
  final int songCount;
  final String? artworkUrl;
  final List<AlbumAlias> aliases;
  // Stable album id (search_albums / get_artist_albums album_id column). Null for
  // text-only albums with no id. Identity key — supersedes name/platform matching.
  final String? albumId;
  // Artists/composers of the album (search_albums.artist_names). Empty when the
  // server doesn't provide it.
  final List<String> artistNames;
  // Representative file format (search_albums.format_ext) — shown in place of the
  // platform when the album has no platform. Null when the server omits it.
  final String? format;
  // Total size of the album's files in bytes (search_albums.file_size); 0 if
  // the server omits it.
  final int fileSize;
  // Why this album matched the query (search_albums, migration 099):
  // 'direct' (name/alias) | 'via_artist' | 'via_song' | null (browse / tag-only).
  final String? matchReason;
  // Total matching albums before pagination (1st row only, from_offset=0), else -1.
  final int totalCount;
  // Any track of the album has a linked demozoo video. Reads a `has_video`
  // bool the album RPCs don't expose YET (server proposal pending) — the
  // badge stays dark until they do.
  final bool hasVideo;

  /// Album-level best podium (mig 186): `via` = 'self' (the album IS the
  /// placed production) or 'song' (one of its tracks placed).
  final CompoPodium? podium;

  /// Album-grain calibrated rating / popularity percentile (same 207/208
  /// semantics as songs). Parsed BY NAME from columns the album listing RPCs
  /// don't expose YET (server proposal pending) — the display lights up on
  /// its own the day they ship. NULL ≠ 0★, as ever.
  final double? rating;
  final int?    popularity;

  const ArtistAlbum({
    required this.name,
    required this.collection,
    this.platform,
    required this.songCount,
    this.artworkUrl,
    this.aliases = const [],
    this.albumId,
    this.artistNames = const [],
    this.format,
    this.fileSize = 0,
    this.matchReason,
    this.totalCount = -1,
    this.hasVideo = false,
    this.podium,
    this.rating,
    this.popularity,
  });

  factory ArtistAlbum.fromJson(Map<String, dynamic> j) => ArtistAlbum(
        name: j['album'] as String,
        collection: j['collection'] as String,
        platform: j['platform'] as String?,
        songCount: (j['song_count'] as num).toInt(),
        artworkUrl: j['artwork_url'] as String?,
        aliases: _toAliasList(j['aliases']),
        albumId: j['album_id'] as String?,
        artistNames: AlbumDetails._toStrList(j['artist_names']),
        format: j['format_ext'] as String?,
        fileSize: (j['file_size'] as num?)?.toInt() ?? 0,
        matchReason: j['match_reason'] as String?,
        totalCount: (j['total_count'] as num?)?.toInt() ?? -1,
        hasVideo: j['has_video'] == true,
        podium: CompoPodium.fromJson(j['compo_podium']),
        rating: ((j['rating'] ?? j['avg_rating']) as num?)?.toDouble(),
        popularity: (j['popularity'] as num?)?.toInt(),
      );

  String get fileSizeLabel {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(0)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static List<AlbumAlias> _toAliasList(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map<String, dynamic>>()
          .map(AlbumAlias.fromJson)
          .toList();
    }
    return const [];
  }

  String? get qualifier {
    final parts = <String>[
      if (platform != null && platform!.isNotEmpty) platform!,
      collection,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

// ---------------------------------------------------------------------------
// Album details (from get_album_details RPC)
// ---------------------------------------------------------------------------

class AlbumDetails {
  final String albumId;
  final String name;
  final String? platform;
  final int? year;
  final String? description;
  final List<String> composerNames;
  final List<String> developerNames;
  final List<String> publisherNames;
  final List<String> chipNames;
  final double? rating;
  final int? ratingCount;
  final String? artworkUrl;
  final String? zipUrl;
  /// R2/CDN mirror of [zipUrl]; same 404-fallback policy.
  final String? mirrorZipUrl;
  final String? packPageUrl;
  final String collection;
  final List<AlbumAlias> aliases;
  /// Demozoo productions this album comes from (mig 163) — e.g. the musicdisk
  /// a modland folder rips. Same shape as the song chips, without `position`.
  final List<ProductionRef> productions;

  /// Album-level best podium (mig 186), same shape as [ArtistAlbum.podium]:
  /// `via` = 'self' (the album IS the placed production) or 'song' (one of its
  /// tracks placed). get_album_details has carried it since the migration; the
  /// album screen simply never read it.
  final CompoPodium? podium;

  const AlbumDetails({
    required this.albumId,
    required this.name,
    this.platform,
    this.year,
    this.description,
    required this.composerNames,
    required this.developerNames,
    required this.publisherNames,
    required this.chipNames,
    this.rating,
    this.ratingCount,
    this.artworkUrl,
    this.zipUrl,
    this.mirrorZipUrl,
    this.packPageUrl,
    required this.collection,
    this.aliases = const [],
    this.productions = const [],
    this.podium,
  });

  factory AlbumDetails.fromJson(Map<String, dynamic> j) => AlbumDetails(
        albumId: j['album_id'] as String,
        name: j['name'] as String,
        platform: j['platform'] as String?,
        year: (j['year'] as num?)?.toInt(),
        description: j['description'] as String?,
        podium: CompoPodium.fromJson(j['compo_podium']),
        composerNames: _toStrList(j['composer_names']),
        developerNames: _toStrList(j['developer_names']),
        publisherNames: _toStrList(j['publisher_names']),
        chipNames: _toStrList(j['chip_names']),
        rating: (j['rating'] as num?)?.toDouble(),
        ratingCount: (j['rating_count'] as num?)?.toInt(),
        artworkUrl: j['artwork_url'] as String?,
        zipUrl: j['zip_url'] as String?,
        mirrorZipUrl: j['mirror_zip_url'] as String?,
        packPageUrl: j['pack_page_url'] as String?,
        collection: j['collection'] as String,
        aliases: ArtistAlbum._toAliasList(j['aliases']),
        productions: ProductionRef.listFrom(j['productions']),
      );

  static List<String> _toStrList(dynamic v) {
    if (v is List) {
      return v
          .where((e) => e != null)
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty && s.toLowerCase() != 'null')
          .toList();
    }
    return [];
  }
}

// ---------------------------------------------------------------------------
// SID metadata (get_sid_info RPC)
// ---------------------------------------------------------------------------

/// Une entrée STIL, telle que le format la définit — et il définit QUATRE
/// champs de nommage, avec deux usages OPPOSÉS:
///
///   NAME   le nom du sous-chant voulu par son auteur  → titre de piste
///   AUTHOR le compositeur du sous-chant               → artiste de piste
///   TITLE  l'ŒUVRE REPRISE                            → panneau ⓘ
///   ARTIST l'auteur de l'œuvre reprise                → panneau ⓘ
///
/// La FAQ STIL le dit depuis la v4.1: « the NAME and AUTHOR fields make sure
/// that the original TITLE and ARTIST fields are used exclusively for cover
/// information ». Son exemple canonique est `NAME: Tocca` avec
/// `TITARTIST: Bach` — les deux coexistent et ne se confondent pas.
///
/// Le serveur ne remontait que TITLE/ARTIST (migration 237 ajoute name/author),
/// et le client les affichait comme titre et artiste: la piste 1 de « One Man
/// and His Droid » s'appelle « Space Game » et s'affichait « Magnetic Fields,
/// Part 1 » de Jean-Michel Jarre — l'œuvre citée à la place du morceau.
class SidSubsongInfo {
  final int idx; // 1-based, matches track_position / STIL.txt
  final int? lengthMs;
  /// STIL NAME — le nom du sous-chant. C'est le TITRE de la piste.
  final String? name;
  /// STIL AUTHOR — le compositeur du sous-chant. C'est son ARTISTE.
  final String? author;
  /// STIL TITLE — l'œuvre REPRISE, jamais un titre de piste.
  final String? title;
  /// STIL ARTIST — l'auteur de l'œuvre reprise.
  final String? artist;
  final String? comment;
  /// TOUTES les reprises citées, dans l'ordre du fichier — donc chronologique.
  /// `title`/`artist` restent le PREMIER groupe (migration serveur 238), pas
  /// une autre donnée: ils sont là pour les clients qui ne lisent pas ce champ.
  final List<SidCover> covers;

  const SidSubsongInfo({
    required this.idx,
    this.lengthMs,
    this.name,
    this.author,
    this.title,
    this.artist,
    this.comment,
    this.covers = const [],
  });

  factory SidSubsongInfo.fromJson(Map<String, dynamic> j) => SidSubsongInfo(
        idx: (j['idx'] as num).toInt(),
        lengthMs: (j['length_ms'] as num?)?.toInt(),
        name: j['name'] as String?,
        author: j['author'] as String?,
        title: j['title'] as String?,
        artist: j['artist'] as String?,
        comment: j['comment'] as String?,
        covers: sidCoversFromJson(j['covers']),
      );

  /// « reprend X de Y », ou null quand le sous-chant ne cite rien.
  bool get hasCover =>
      (title?.isNotEmpty ?? false) || (artist?.isNotEmpty ?? false);
}

class SidGlobalStil {
  /// Mêmes quatre champs, même partage — voir [SidSubsongInfo].
  final String? name;
  final String? author;
  final String? title;
  final String? artist;
  final String? comment;
  final List<SidCover> covers;

  const SidGlobalStil(
      {this.name, this.author, this.title, this.artist, this.comment,
       this.covers = const []});

  factory SidGlobalStil.fromJson(Map<String, dynamic> j) => SidGlobalStil(
        name: j['name'] as String?,
        author: j['author'] as String?,
        title: j['title'] as String?,
        artist: j['artist'] as String?,
        comment: j['comment'] as String?,
        covers: sidCoversFromJson(j['covers']),
      );
}

class SidInfo {
  final String md5;
  final int? subsongCount;
  /// Sous-chant sur lequel DÉMARRER, 0-based DENSE — la valeur à passer telle
  /// quelle au moteur. Beaucoup de SID ouvrent sur un bruitage ou un jingle et
  /// désignent dans leur en-tête le vrai morceau (`startSong`); le serveur a
  /// déjà fait la conversion depuis son 1-based, NE PAS la refaire.
  /// null = démarrer à 0 (l'immense majorité, et les en-têtes non lus).
  final int? defaultSubsong;
  final SidGlobalStil? stilGlobal;
  final List<SidSubsongInfo> subsongs;

  const SidInfo({
    required this.md5,
    this.subsongCount,
    this.defaultSubsong,
    this.stilGlobal,
    this.subsongs = const [],
  });

  factory SidInfo.fromJson(Map<String, dynamic> j) => SidInfo(
        md5: j['md5'] as String,
        subsongCount: (j['subsong_count'] as num?)?.toInt(),
        defaultSubsong: (j['default_subsong'] as num?)?.toInt(),
        stilGlobal: j['stil_global'] != null
            ? SidGlobalStil.fromJson(j['stil_global'] as Map<String, dynamic>)
            : null,
        subsongs: (j['subsongs'] as List?)
                ?.map((e) => SidSubsongInfo.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  SidSubsongInfo? subsongAt(int subsongIdx) =>
      subsongs.where((s) => s.idx - 1 == subsongIdx).firstOrNull;

  /// Le TITRE de la sous-chanson: STIL NAME, propre au sous-chant puis global.
  /// Null = STIL ne la nomme pas (le cas des 13 autres sous-chants de « One Man
  /// and His Droid »); l'appelant garde alors le nom qu'il a déjà.
  String? nameFor(int subsongIdx) =>
      subsongAt(subsongIdx)?.name ?? stilGlobal?.name;

  /// NAME propre au sous-chant SEULEMENT — sans le repli global, pour une liste
  /// où répéter le même nom sur chaque ligne n'apprendrait rien.
  String? perSubsongNameFor(int subsongIdx) => subsongAt(subsongIdx)?.name;

  /// L'ARTISTE de la sous-chanson: STIL AUTHOR.
  String? authorFor(int subsongIdx) =>
      subsongAt(subsongIdx)?.author ?? stilGlobal?.author;

  /// L'ŒUVRE REPRISE et son auteur — panneau ⓘ, jamais titre ni artiste de
  /// piste. Les accesseurs portent « cover » dans leur nom exprès: c'est
  /// précisément la confusion que ce changement défait.
  String? coverTitleFor(int subsongIdx) =>
      subsongAt(subsongIdx)?.title ?? stilGlobal?.title;

  String? coverArtistFor(int subsongIdx) =>
      subsongAt(subsongIdx)?.artist ?? stilGlobal?.artist;

  /// Toutes les reprises du sous-chant, sinon celles du bloc global — même
  /// repli que [coverTitleFor], dont ce champ est la version complète.
  List<SidCover> coversFor(int subsongIdx) {
    final own = subsongAt(subsongIdx)?.covers ?? const <SidCover>[];
    if (own.isNotEmpty) return own;
    return stilGlobal?.covers ?? const [];
  }

  /// Subsong length in ms for [subsongIdx] (0-based), or null.
  int? lengthFor(int subsongIdx) =>
      subsongs.where((s) => s.idx - 1 == subsongIdx).firstOrNull?.lengthMs;
}

// ---------------------------------------------------------------------------
// SAP metadata (get_sap_info RPC) — mirrors get_sid_info for ASMA, but no
// subsong split (ASMA's STIL.txt has no per-subsong granularity).
// ---------------------------------------------------------------------------

class SapInfo {
  final String md5;
  /// STIL NAME/AUTHOR — voir [SidSubsongInfo]: ils nomment le MORCEAU, pas
  /// l'œuvre citée. Panneau ⓘ seulement ici: ASMA n'a pas de découpage par
  /// sous-chant, donc un NAME nommerait le FICHIER, et on ne renomme pas une
  /// piste sur cette base.
  final String? stilName;
  final String? stilAuthor;
  final String? stilTitle;   // original work title (if this .sap is a cover)
  final String? stilArtist;  // original composer (≠ the SAP file's own author)
  final String? stilComment;
  /// TOUTES les reprises citées — le serveur rend `stil.covers`, que le client
  /// IGNORAIT: `stilTitle`/`stilArtist` n'en sont que la première. Même trou
  /// que la migration locale 61 côté SID, où une entrée en citait sept.
  final List<SidCover> stilCovers;
  final int? subsongCount;
  /// Voir [SidInfo.defaultSubsong] — même contrat: 0-based dense, null = 0.
  final int? defaultSubsong;

  const SapInfo({
    required this.md5,
    this.stilName,
    this.stilAuthor,
    this.stilTitle,
    this.stilArtist,
    this.stilComment,
    this.stilCovers = const [],
    this.subsongCount,
    this.defaultSubsong,
  });

  factory SapInfo.fromJson(Map<String, dynamic> j) {
    final stil = j['stil'] as Map<String, dynamic>?;
    return SapInfo(
      md5: j['md5'] as String,
      subsongCount: (j['subsong_count'] as num?)?.toInt(),
      defaultSubsong: (j['default_subsong'] as num?)?.toInt(),
      stilName: stil?['name'] as String?,
      stilAuthor: stil?['author'] as String?,
      stilTitle: stil?['title'] as String?,
      stilArtist: stil?['artist'] as String?,
      stilComment: stil?['comment'] as String?,
      stilCovers: sidCoversFromJson(stil?['covers']),
    );
  }

  bool get hasStil =>
      (stilName?.isNotEmpty ?? false) ||
      (stilAuthor?.isNotEmpty ?? false) ||
      (stilTitle?.isNotEmpty ?? false) ||
      (stilArtist?.isNotEmpty ?? false) ||
      (stilComment?.isNotEmpty ?? false) ||
      stilCovers.isNotEmpty;
}

// ---------------------------------------------------------------------------
// Client
// ---------------------------------------------------------------------------

/// Per-track playlist metadata (`playlist_items.meta` JSONB from
/// get_playlist_tracks): compo RANK (may repeat — several songs of one demo
/// share its ranking), and where it placed.
///
/// The shape varies by playlist kind, which is why every field is optional:
/// a party compo playlist carries {rank, production, group}, while the
/// calendar-driven "Hall of Fame — `<series>`" ones carry {rank, party, year}
/// (the party naming the edition and compo, e.g. "Solskogen 2020 — Oldschool
/// Music"). null rank ⇒ non-compo playlist, fall back to track_position.
class PlaylistTrackMeta {
  final int? rank;
  final String? production;
  final String? group;
  final String? party;   // "Solskogen 2020 — Oldschool Music"
  final int? year;
  /// get_production_tracks rows only: 'own' = the production's own tune,
  /// 'used_in' = a tune it uses. null for playlist rows.
  final String? kind;

  const PlaylistTrackMeta(
      {this.rank, this.production, this.group, this.party, this.year,
      this.kind});

  static PlaylistTrackMeta? fromJson(dynamic j) {
    if (j is! Map) return null;
    final rank = (j['rank'] as num?)?.toInt();
    final production = j['production'] as String?;
    final group = j['group'] as String?;
    final party = j['party'] as String?;
    final year = (j['year'] as num?)?.toInt();
    final kind = j['kind'] as String?;
    if (rank == null && production == null && group == null &&
        party == null && year == null && kind == null) {
      return null;
    }
    return PlaylistTrackMeta(
        rank: rank, production: production, group: group,
        party: party, year: year, kind: kind);
  }
}

/// Live status of the current library download, surfaced by a global UI
/// banner (see DownloadBanner). null on [RewampDb.downloadStatus] = idle.
class DownloadInfo {
  final String label;     // what is being fetched (track title, aux file, album)
  final double? progress; // 0..1; null = size unknown (indeterminate bar)
  final String? error;    // non-null = the download failed (shown briefly)

  const DownloadInfo(this.label, {this.progress, this.error});
}

/// Thrown when a file was fetched fine but no bundled engine can play its format
/// (e.g. an archive that unpacks to a one-off Amiga custom no decoder claims).
/// Caught by the play path to show an explicit "unsupported format" message
/// (naming file + ext) and report the song — NOT the misleading "download
/// failed" banner. [songId] is the online song UUID (null = local, unreportable).
/// L'archive de l'album ne contient PAS le fichier que la tracklist annonce.
///
/// Mesuré sur « Atelier Annie - Alchemists of Sera Island » (jw_2sf): le rip
/// joshw liste 55 pistes, dont six `.mp3` (les vocales) — et son `.7z` n'en
/// contient AUCUNE: 49 `.mini2sf`, un `.2sflib`, le `!playlist.m3u`. Le
/// serveur reprend cette liste telle quelle, donc six lignes de l'écran album
/// ne désignent rien. Sans cette exception elles retombaient sur le pick
/// générique: les trois premières jouaient toutes le MÊME fichier (le
/// `.2sflib` de 8,9 Mo, seul « gros fichier d'allure audio » du dossier), et
/// la ligne cliquée se marquait « téléchargée » puisqu'un chemin venait d'y
/// être écrit.
class ArchiveEntryMissingException implements Exception {
  final String filename;   // le nom que la tracklist annonce
  final String url;        // l'archive où il devait se trouver
  final String? songId;    // pour report_song
  final int subsongIndex;
  const ArchiveEntryMissingException({
    required this.filename,
    required this.url,
    this.songId,
    this.subsongIndex = 0,
  });
  @override
  String toString() =>
      'ArchiveEntryMissingException($filename absent de $url)';
}

class FormatUnsupportedException implements Exception {
  final String filename;     // basename shown to the user
  final String ext;          // extension without the dot
  final String? songId;      // online UUID for report_song, null if unknown
  final int subsongIndex;    // 0 = whole file
  final String detail;       // engine-facing detail for the report
  final String? triedUrl;    // download_url that produced this file (for the
                             // "was it replaced server-side?" retry check)
  const FormatUnsupportedException({
    required this.filename,
    required this.ext,
    this.songId,
    this.subsongIndex = 0,
    this.detail = '',
    this.triedUrl,
  });
  @override
  String toString() => 'FormatUnsupportedException($filename .$ext)';
}

/// A file download that returned an HTTP error status (not a transient network
/// glitch). [statusCode] 404/403/410 means the file is GONE from the origin —
/// the play path reports that (report_song, reason: download_failed) instead of
/// silently skipping. [isGone] is the "report it" predicate.
class DownloadHttpException implements Exception {
  final int statusCode;
  final String url;
  const DownloadHttpException(this.statusCode, this.url);
  /// Permanent absence (not a 5xx / rate-limit blip): worth reporting.
  bool get isGone =>
      statusCode == 404 || statusCode == 403 || statusCode == 410;
  @override
  String toString() => 'DownloadHttpException($statusCode $url)';
}

/// L'origine n'a pas répondu à temps.
///
/// ⚠️ Distincte d'un `TimeoutException` nu, qui remontait tel quel jusqu'au
/// bandeau: le testeur lisait « TimeoutException after 0:00:20.000000: Future
/// not completed » là où le fait utile est « ce serveur-là n'a pas répondu ».
/// Elle nomme l'HÔTE, parce que c'est lui le fautif — et sur un module Amiga
/// c'est toujours le même. (modland n'était pas miroité jusqu'au 2026-09-05 —
/// `mirror_url` nul sur toutes ses lignes; depuis, morceaux ET compagnons ont
/// un miroir, l'origine ne sert plus qu'en repli.)
class DownloadTimeoutException implements Exception {
  final String host;
  final String url;
  const DownloadTimeoutException(this.host, this.url);
  @override
  String toString() => 'DownloadTimeoutException($host — $url)';
}

class RewampDb {
  // Switch between local dev server and VPS by toggling this flag.
  // ENV=local  → localhost (macOS/iOS simulator: 127.0.0.1, Android emulator: 10.0.2.2)
  // ENV=vps    → public VPS over HTTPS (default)
  //
  // The VPS URL is overridable (REWAMP_API_URL) so a fork can point at its own
  // instance. It must stay https: cleartext to the VPS is refused by ATS (iOS)
  // and by network_security_config (Android), which only whitelists the local
  // dev hosts above.
  static const _env = String.fromEnvironment('ENV', defaultValue: 'vps');

  static const String _localUrl        = 'http://127.0.0.1:3000';
  static const String _androidLocalUrl = 'http://10.0.2.2:3000';
  static const String _vpsUrl = String.fromEnvironment(
    'REWAMP_API_URL',
    defaultValue: 'https://api.rewamp.app',
  );

  static String get _baseUrl {
    if (_env == 'local') {
      return Platform.isAndroid ? _androidLocalUrl : _localUrl;
    }
    return _vpsUrl;
  }

  // Tag filter params for search_music / browse_music.
  //
  // Server `tags TEXT[]`, AND semantics, matched by tag NAME (case-insensitive)
  // — slugs are NOT matched, send display names.
  static Map<String, dynamic> _tagParams(List<String> tags,
          [List<String>? tagCategories]) =>
      tags.isEmpty
          ? const {}
          : {
              'tags': tags,
              // mig 159: resolve tags only within these categories
              // (null/absent = all categories, historic union behavior).
              if (tagCategories != null && tagCategories.isNotEmpty)
                'tag_categories': tagCategories,
            };

  /// POST JSON avec des clés OPTIONNELLES: PostgREST rejette un paramètre
  /// inconnu (PGRST202, HTTP 404) au lieu de l'ignorer — un serveur antérieur
  /// à la migration qui l'ajoute ferait donc échouer TOUT l'appel. Sur 404
  /// avec une clé optionnelle posée, on rejoue sans elle: le filtre concerné
  /// se dégrade, l'appel aboutit. Même contrat que _rpcOptional, pour les
  /// liaisons qui décodent elles-mêmes leur réponse.
  /// Paramètres OPTIONNELS qu'un serveur a refusés pendant ce processus (404
  /// PostgREST ⇒ requête rejouée SANS eux). ⚠️ Un FILTRE retiré ainsi n'est
  /// PAS appliqué: l'appelant doit pouvoir le savoir, sinon il affiche un
  /// résultat non filtré comme s'il l'était (docs/podium_filter_proposal.md).
  static final Set<String> _serverLacks = <String>{};
  static bool serverLacks(String param) => _serverLacks.contains(param);

  /// Bumped when [serverLacks] learns a new parameter — an open screen can
  /// react (announce it, clear the filter that cannot apply).
  static final ValueNotifier<int> serverLacksChanged = ValueNotifier<int>(0);

  static Future<http.Response> _postJsonOptional(
    Uri uri,
    Map<String, dynamic> body, {
    Set<String> optional = const {},
    Duration timeout = const Duration(seconds: 20),
    Map<String, String>? headers,
  }) async {
    final h = headers ?? const {'Content-Type': 'application/json'};
    final r = await http
        .post(uri, headers: h, body: jsonEncode(body))
        .timeout(timeout);
    if (r.statusCode == 404 &&
        optional.isNotEmpty &&
        optional.any(body.containsKey)) {
      final trimmed = {...body}..removeWhere((k, _) => optional.contains(k));
      final lacked = optional.where(body.containsKey).toSet();
      if (!_serverLacks.containsAll(lacked)) {
        _serverLacks.addAll(lacked);
        serverLacksChanged.value++;
      }
      debugPrint('[RewampDb] ${uri.pathSegments.last}: server lacks '
          '${optional.join('/')} — retrying without');
      return http
          .post(uri, headers: h, body: jsonEncode(trimmed))
          .timeout(timeout);
    }
    return r;
  }

  static Future<List<SearchResult>> search(
    String q, {
    bool fuzzy = false, // server reco: exact/prefix; use true as a fallback
    String? artistName,
    String? artistId, // p_artist_id (mig 146): homonym-proof artist scoping
    String? albumName,
    String? collection, // maps to collection_slug
    /// PLUSIEURS collections en OU (mig serveur 240) — c'est ce qui porte la
    /// famille « joshw » du sélecteur: le client déplie la famille en ses
    /// membres, le serveur reste ignorant du regroupement. Ignoré si
    /// [collection] est posé (le serveur donne priorité au slug unique).
    List<String>? collections, // maps to p_collections
    String? platform, // maps to platform_name
    String? formatFilter, // maps to format_filter  (e.g. 'mod', 'vgz')
    String? chipName, // maps to chip_name
    List<String> tags = const [], // tag filter(s); see _tagParams
    List<String>? tagCategories, // mig 159: tag_categories
    int? yearMin, // inclusive; NB: filtering excludes undated (year=null) songs
    int? yearMax,
    num? ratingMin, // 0..5; rating derives from plays, unrated songs excluded
    int? podium, // p_podium: null = aucun, 0 = tout podium, 1-3 = ce rang (podium_filter.dart)
    String? seed, // for sortBy 'random': fixed seed = stable paginated order
    String sortBy = 'relevance', // relevance|name|popularity|year|random (+title/rating aliases)
    String? sortDir, // asc|desc; server default per sort_by
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/rpc/search_music');
    final response = await _postJsonOptional(
          uri,
          {
            'q': q,
            'fuzzy': fuzzy,
            if (artistName != null) 'artist_name': artistName,
            if (artistId != null) 'p_artist_id': artistId,
            if (albumName != null) 'album_name': albumName,
            if (collection != null) 'collection_slug': collection,
            if (collections != null && collections.isNotEmpty)
              'p_collections': collections,
            if (platform != null) 'platform_name': platform,
            if (formatFilter != null) 'format_filter': formatFilter,
            if (chipName != null) 'chip_name': chipName,
            ..._tagParams(tags, tagCategories),
            if (yearMin != null) 'year_min': yearMin,
            if (yearMax != null) 'year_max': yearMax,
            if (ratingMin != null) 'rating_min': ratingMin,
            if (podium != null && podium >= 0 && podium <= 3) 'p_podium': podium,
            if (seed != null) 'seed': seed,
            'sort_by': sortBy,
            if (sortDir != null) 'sort_dir': sortDir,
            'lim': limit,
            'from_offset': offset,
          },
          optional: const {'p_collections', 'p_podium'},
        );

    if (response.statusCode != 200) {
      throw Exception('search_music HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    final rows = list
        .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
    // Serveur sans p_podium: la page reçue n'est PAS filtrée — on filtre ici.
    return podium != null && serverLacks('p_podium')
        ? [for (final r in rows) if (r.podium != null && (podium == 0 || r.podium!.rank == podium)) r]
        : rows;
  }

  // ---- Browse (no text query) -----------------------------------------------

  /// Returns songs from `browse_music` RPC — collection browsing without FTS.
  static Future<List<SearchResult>> browse({
    String? collection,
    List<String>? collections, // p_collections (mig 240) — voir search()
    String? albumName,
    String? artistName,
    String? artistId, // p_artist_id (mig 146): homonym-proof artist scoping
    String? platform,
    String? formatFilter,
    String? chipName,
    List<String> tags = const [],
    List<String>? tagCategories, // mig 159: tag_categories
    int? yearMin,
    int? yearMax,
    num? ratingMin,
    int? podium, // p_podium — voir search()
    String? seed, // for sortBy 'random': fixed seed = stable paginated order
    // Folder-subtree filter (migration 113): songs.path LIKE prefix || '%',
    // scoped to [collection]. Must end with '/' to target a folder (not a
    // sibling name sharing the prefix). Powers folder play-all/shuffle/radio.
    String? pathPrefix,
    String sortBy = 'name', // name|popularity|year|random (title/rating aliases)
    String? sortDir,
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/rpc/browse_music');
    final response = await _postJsonOptional(
          uri,
          {
            if (collection != null) 'collection_slug': collection,
            if (collections != null && collections.isNotEmpty)
              'p_collections': collections,
            if (albumName != null) 'album_name': albumName,
            if (artistName != null) 'artist_name': artistName,
            if (artistId != null) 'p_artist_id': artistId,
            if (platform != null) 'platform_name': platform,
            if (formatFilter != null) 'format_filter': formatFilter,
            if (chipName != null) 'chip_name': chipName,
            ..._tagParams(tags, tagCategories),
            if (yearMin != null) 'year_min': yearMin,
            if (yearMax != null) 'year_max': yearMax,
            if (ratingMin != null) 'rating_min': ratingMin,
            if (podium != null && podium >= 0 && podium <= 3) 'p_podium': podium,
            if (seed != null) 'seed': seed,
            if (pathPrefix != null) 'path_prefix': pathPrefix,
            'sort_by': sortBy,
            if (sortDir != null) 'sort_dir': sortDir,
            'lim': limit,
            'from_offset': offset,
          },
          optional: const {'p_collections', 'p_podium'},
          timeout: const Duration(seconds: 15),
        );

    if (response.statusCode != 200) {
      throw Exception('browse_music HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    final rows = list
        .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
    return podium != null && serverLacks('p_podium')
        ? [for (final r in rows) if (r.podium != null && (podium == 0 || r.podium!.rank == podium)) r]
        : rows;
  }

  /// One page of a collection's folder tree via `browse_folder` (migration
  /// 113): the immediate children of [folder] — subdirectories (aggregated,
  /// recursive song count) first, then the songs directly inside it, each
  /// group sorted alphabetically. [folder] has no leading/trailing slash
  /// ('' = root) and must round-trip exactly from [FolderEntry.dirPath]
  /// (paths are raw as stored — jw_* are URL-encoded). Non-null [q] switches
  /// to a recursive subtree search: the response is a flat song list, no dir
  /// rows. `totalCount` counts dirs+songs; the server returns -1 for it on
  /// offset>0 pages — keep the first page's value.
  static Future<FolderPage> browseFolder({
    required String collection,
    String folder = '',
    String? q,
    int limit = 200,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/rpc/browse_folder');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'collection_slug': collection,
            'folder': folder,
            if (q != null && q.isNotEmpty) 'q': q,
            'lim': limit,
            'off': offset,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('browse_folder HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    final dirs  = <FolderEntry>[];
    final songs = <SearchResult>[];
    var total = 0;
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final t = (m['total_count'] as num?)?.toInt() ?? 0;
      if (t > total) total = t;
      if (m['entry_type'] == 'dir') {
        dirs.add(FolderEntry(
          name:      m['name'] as String? ?? '',
          dirPath:   m['dir_path'] as String? ?? '',
          songCount: (m['dir_song_count'] as num?)?.toInt() ?? 0,
        ));
      } else {
        songs.add(SearchResult.fromJson(m));
      }
    }
    return FolderPage(dirs: dirs, songs: songs, totalCount: total);
  }

  /// One-call collection profile (`get_collection_overview`) — drives the
  /// collection hub. Null on any error OR unknown slug (server answers null):
  /// the hub then degrades to the flat all-songs entry.
  static Future<CollectionOverview?> getCollectionOverview(String slug) async {
    try {
      final uri = Uri.parse('$_baseUrl/rpc/get_collection_overview');
      final resp = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'p_slug': slug}))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final j = jsonDecode(resp.body);
      // PostgREST may return the object bare or as a 1-element list.
      final m = j is List ? (j.isEmpty ? null : j.first) : j;
      if (m is! Map<String, dynamic>) return null;
      return CollectionOverview.fromJson(m);
    } catch (_) {
      return null;
    }
  }

  /// Paged groups of one collection (`list_collection_groups`), song-count
  /// desc then name. Same union as the overview's group_count.
  static Future<List<CollectionGroupRow>> listCollectionGroups(
    String slug, {
    String? query,
    int limit = 100,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/rpc/list_collection_groups');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'p_slug': slug,
            if (query != null && query.isNotEmpty) 'q': query,
            'lim': limit,
            'from_offset': offset,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('list_collection_groups HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => CollectionGroupRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Top artists by real listens (`most_popular_artists`). Empty on error —
  /// a hub section that cannot load simply does not show.
  static Future<List<PopularArtist>> mostPopularArtists({
    String period = 'all',
    int n = 10,
    String? collectionSlug,
    List<String>? collections, // p_collections (mig 243) — voir search()
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/rpc/most_popular_artists');
      final resp = await _postJsonOptional(
          uri,
          {
            'period': period,
            'n': n,
            if (collectionSlug != null) 'collection_slug': collectionSlug,
            if (collectionSlug == null &&
                collections != null &&
                collections.isNotEmpty)
              'p_collections': collections,
          },
          optional: const {'p_collections'},
          timeout: const Duration(seconds: 15));
      if (resp.statusCode != 200) return const [];
      final list = jsonDecode(resp.body) as List;
      return list
          .map((e) => PopularArtist.fromJson(e as Map<String, dynamic>))
          .where((a) => a.name.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Returns every track of ONE specific album via `get_album_tracks` RPC.
  /// Pass a `SearchResult.albumId` to target the exact album when several share
  /// a name (e.g. "Commando" spans 5 distinct albums).
  static Future<List<SearchResult>> albumTracks({
    required String albumId,
    String sortBy = 'track',
    int limit = 500,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/rpc/get_album_tracks');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'p_album_id': albumId,
            'sort_by': sortBy,
            'lim': limit,
            'from_offset': offset,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('get_album_tracks HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Tag facet values / typeahead via the `list_tags` RPC. Optional [query]
  /// and [category]; [byUsage] sorts by usage_count (descending) — each row
  /// then carries `usage_count` + `total_count` (pagination, 1st row).
  static Future<List<TagItem>> listTags({
    String? query,
    String? category,
    bool byUsage = false,
    int limit = 40,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/rpc/list_tags');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
            if (category != null && category.isNotEmpty) 'category': category,
            'by_usage': byUsage,
            'lim': limit,
            'from_offset': offset,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('list_tags HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => TagItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Distinct tag categories via the `list_tag_categories` RPC (no params).
  /// Returns the category slugs ordered by usage (most-used first) so the
  /// facet selector stays in sync with whatever the server actually has
  /// (e.g. a new `production` category shows up without a client change).
  static Future<List<String>> listTagCategories() async {
    final uri = Uri.parse('$_baseUrl/rpc/list_tag_categories');
    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: '{}')
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('POST /rpc/list_tag_categories HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    final rows = list
        .map((e) => e as Map<String, dynamic>)
        .where((e) => (e['category'] as String?)?.isNotEmpty ?? false)
        .toList();
    // Rank by usage_count desc (fallback: tag_count) to mirror "usefulness".
    rows.sort((a, b) {
      int n(Map<String, dynamic> r) =>
          (r['usage_count'] as num?)?.toInt() ??
          (r['tag_count'] as num?)?.toInt() ??
          0;
      return n(b).compareTo(n(a));
    });
    return rows.map((e) => e['category'] as String).toList();
  }

  // ---- UADE metadata (audacious-uade songdb) ------------------------------

  /// Per-subsong UADE metadata for a file md5. null on network error; a valid
  /// UadeInfo with subsongCount 0 means "not in the songdb".
  static Future<UadeInfo?> getUadeInfo(String md5) async {
    final uri = Uri.parse('$_baseUrl/rpc/get_uade_info');
    final response = await http
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'p_md5': md5}))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('get_uade_info HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body);
    // PostgREST may return the row directly or wrapped in a single-element list.
    final Map<String, dynamic>? row = body is List
        ? (body.isEmpty ? null : body.first as Map<String, dynamic>)
        : body as Map<String, dynamic>?;
    if (row == null) return null;
    return UadeInfo.fromJson(row);
  }

  /// Batch variant: md5 → UadeInfo for every md5 the songdb knows.
  static Future<Map<String, UadeInfo>> getUadeInfoBatch(
      List<String> md5s) async {
    if (md5s.isEmpty) return const {};
    final uri = Uri.parse('$_baseUrl/rpc/get_uade_info_batch');
    final response = await http
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'p_md5s': md5s}))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('get_uade_info_batch HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    final out = <String, UadeInfo>{};
    for (final e in list) {
      if (e is Map<String, dynamic>) {
        final md5 = e['md5'] as String?;
        if (md5 != null) out[md5] = UadeInfo.fromJson(e);
      }
    }
    return out;
  }

  // ---- Downloadable assets (soundfonts, …) --------------------------------

  /// One row of the server `assets` catalogue (list_assets RPC).
  static Future<List<RemoteAsset>> listAssets(String kind) async {
    final uri = Uri.parse('$_baseUrl/rpc/list_assets');
    final response = await http
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'p_kind': kind}))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('list_assets HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => RemoteAsset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- Milkdrop preset packs (projectM) -----------------------------------

  /// Pack cards for the install screen (`list_preset_packs`).
  static Future<List<PresetPack>> listPresetPacks() async {
    final json = await _rpc('list_preset_packs', const {});
    if (json is! List) return const [];
    return [
      for (final row in json)
        if (row is Map) PresetPack.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// A pack's preset tree at [folder] (`browse_presets`): subdirectories
  /// (recursive preset count) first, then the presets directly inside. Non-empty
  /// [q] = recursive search under the folder (flat preset list, no dir rows).
  ///
  /// Paginated exactly like `browse_folder` — the parameter is `off` (a server
  /// build once named it `from_offset` and ignored `off`, so every page came
  /// back as page one; that is fixed, and the old signature is gone). `lim`
  /// caps at 1000 server-side. `totalCount` counts dirs+presets for the whole
  /// level and is -1 from the 2nd page on: keep the first page's value.
  static Future<PresetBrowsePage> browsePresets({
    required String pack,
    String folder = '',
    String? q,
    int limit = 200,
    int offset = 0,
  }) async {
    final json = await _rpc('browse_presets', {
      'p_pack': pack,
      'p_folder': folder,
      if (q != null && q.isNotEmpty) 'q': q,
      'lim': limit,
      'off': offset,
    });
    final dirs = <PresetFolderEntry>[];
    final presets = <PresetInfo>[];
    var total = 0;
    if (json is List) {
      for (final e in json) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final t = (m['total_count'] as num?)?.toInt() ?? 0;
        if (t > total) total = t;
        if (m['entry_type'] == 'dir') {
          // The folder path is `path` — the FULL path from the pack root
          // ('Dancer/Aurora'), which is exactly what the next call's p_folder
          // wants. Reading `dir_path` (browse_folder's name for it) gave an
          // empty string, so every sub-folder tap re-listed the root.
          dirs.add(PresetFolderEntry(
            name:        m['name'] as String? ?? '',
            dirPath:     (m['path'] ?? m['dir_path']) as String? ?? '',
            presetCount: (m['dir_preset_count'] as num?)?.toInt() ?? 0,
          ));
        } else {
          presets.add(PresetInfo.fromJson(m));
        }
      }
    }
    return PresetBrowsePage(dirs: dirs, presets: presets, totalCount: total);
  }

  /// Computed popularity chart, not a playlist (`most_popular_presets`).
  static Future<List<PresetInfo>> mostPopularPresets(
      {int days = 30, String? pack, int limit = 100}) async {
    final json = await _rpcOptional('most_popular_presets', {
      'p_days': days,
      if (pack != null) 'p_pack': pack,
      'lim': limit,
    }, {'lim'});
    if (json is! List) return const [];
    return [
      for (final row in json)
        if (row is Map) PresetInfo.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Server-curated preset playlists (`list_preset_playlists`).
  static Future<List<PresetPlaylistInfo>> listPresetPlaylists() async {
    final json = await _rpc('list_preset_playlists', const {});
    if (json is! List) return const [];
    return [
      for (final row in json)
        if (row is Map)
          PresetPlaylistInfo.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Items of a curated preset playlist, ordered by `item_position` (that is
  /// the column name — not `position`).
  static Future<List<PresetInfo>> getPresetPlaylistItems(String id) async {
    final json = await _rpc('get_preset_playlist_items', {'p_id': id});
    if (json is! List) return const [];
    final items = [
      for (final row in json)
        if (row is Map) PresetInfo.fromJson(Map<String, dynamic>.from(row)),
    ];
    items.sort((a, b) => (a.itemPosition ?? 0).compareTo(b.itemPosition ?? 0));
    return items;
  }

  /// Batched preset-usage push (`log_preset_uses`). Accumulate client-side and
  /// send in batches (never one POST per switch); the server caps at 500 ids
  /// per batch and ignores unknown ids. Counted per-user too when the auth
  /// token rides along (via [_headers]). Returns the number counted.
  static Future<int> logPresetUses(List<String> presetIds) async {
    if (presetIds.isEmpty) return 0;
    final batch =
        presetIds.length > 500 ? presetIds.sublist(0, 500) : presetIds;
    final json = await _rpc('log_preset_uses', {'p_preset_ids': batch});
    if (json is num) return json.toInt();
    if (json is Map) return ((json['count'] ?? json['counted']) as num?)?.toInt() ?? 0;
    return 0;
  }

  /// Server-curated playlists via `list_playlists` RPC. [tags] = AND filter
  /// (e.g. ['Assembly'] → every Assembly compo playlist).
  static Future<List<Playlist>> listPlaylists({
    String? tag,
    List<String> tags = const [],
    List<String>? tagCategories, // mig 159: tag_categories
    String? query,
    bool fuzzy = false,
    String? collection,
    /// p_collections (mig 247) — voir search().
    List<String>? collections,
    String? platform,
    String? formatFilter,
    String? chipName,
    int? yearMin,
    int? yearMax,
    num? ratingMin,
    String? seed,
    String? sortBy,  // relevance|name|popularity|recent|random (server default)
    String? sortDir,
    int limit = 100,
    int offset = 0,
    // Migration 172: without it the answer holds server playlists only — the
    // user's own ones (and their is_owned/is_public flags) never come back.
    bool onlyMine = false,
    /// Migration 199: 'user' = playlists published by people, 'server' = ours,
    /// null = both. A user playlist was otherwise unreachable except by typing
    /// its name — free browsing sorts by popularity, and a playlist has no
    /// listens on the day it appears.
    String? source,
    /// Ne garde que les playlists PUBLIQUES — le filtre du rail « nouveautés
    /// de la communauté ». Filtrer côté client ne suffisait pas: l'appel part
    /// avec le jeton, donc la réponse mêle les playlists du compte (privées ou
    /// en attente de relecture comprises) et le `total_count` les COMPTE, ce
    /// que rien de local ne peut corriger.
    bool onlyPublic = false,
    /// Écarter MES playlists de la réponse. Orthogonal à [onlyPublic]:
    /// « publique » parle de l'état de publication, celui-ci de l'auteur.
    /// null = laisser le défaut du serveur; le rail communauté passe `false`
    /// EXPLICITEMENT — une playlist à soi, publiée et approuvée, est une
    /// nouveauté de la communauté comme une autre, et la voir sur son accueil
    /// est la confirmation qu'elle est bien en ligne.
    bool? excludeMine,
    /// Migration 182: only the playlists whose CONTENT changed since this
    /// cursor (`playlists.updated_at >= p_since`, every write moves it).
    DateTime? since,
  }) async {
    final uri = Uri.parse('$_baseUrl/rpc/list_playlists');
    // _headers, not a bare content-type: the caller's own playlists (and
    // p_only_mine) exist only for an identified user, and identity now travels
    // in the Authorization header.
    Future<http.Response> call({
      required bool withFuzzy,
      required bool withCollections,
    }) => http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            if (tag != null && tag.isNotEmpty) 'tag': tag,
            if (tags.isNotEmpty) 'tags': tags,
            if (((tag != null && tag.isNotEmpty) || tags.isNotEmpty) &&
                tagCategories != null && tagCategories.isNotEmpty)
              'tag_categories': tagCategories,
            if (query != null && query.isNotEmpty) 'q': query,
            if (withFuzzy) 'fuzzy': true,
            if (source != null && source.isNotEmpty) 'p_source': source,
            if (collection != null) 'collection_slug': collection,
            if (withCollections) 'p_collections': collections,
            if (platform != null) 'platform_name': platform,
            if (formatFilter != null) 'format_filter': formatFilter,
            if (chipName != null) 'chip_name': chipName,
            if (yearMin != null) 'year_min': yearMin,
            if (yearMax != null) 'year_max': yearMax,
            if (ratingMin != null) 'rating_min': ratingMin,
            if (seed != null) 'seed': seed,
            if (sortBy != null) 'sort_by': sortBy,
            if (sortDir != null) 'sort_dir': sortDir,
            if (onlyMine) 'p_only_mine': true,
            if (onlyPublic) 'p_only_public': true,
            if (excludeMine != null) 'p_exclude_mine': excludeMine,
            if (since != null)
              'p_since': since.toUtc().toIso8601String(),
            'lim': limit,
            'from_offset': offset,
          }),
        )
        .timeout(const Duration(seconds: 15));
    // Cet appel a DEUX paramètres qu'un serveur antérieur peut ne pas
    // connaître, et PostgREST répond 404 pour l'un comme pour l'autre — on ne
    // peut donc pas savoir lequel a fâché. On les retire du plus récent au
    // plus ancien: `p_collections` (mig 247) d'abord, `fuzzy` ensuite.
    final wantCollections =
        collection == null && collections != null && collections.isNotEmpty;
    var response =
        await call(withFuzzy: fuzzy, withCollections: wantCollections);
    if (wantCollections && response.statusCode == 404) {
      debugPrint('[RewampDb] list_playlists: server lacks p_collections '
          '— retrying without');
      response = await call(withFuzzy: fuzzy, withCollections: false);
    }
    // Older server without the fuzzy parameter → retry without it.
    if (fuzzy && response.statusCode == 404) {
      response = await call(withFuzzy: false, withCollections: false);
    }
    if (response.statusCode != 200) {
      throw Exception('list_playlists HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Calendar-driven home rail via `list_featured` (migration 115/116).
  ///
  /// [lang] only drives the server's pre-rendered `reason` fallback — we render
  /// the label ourselves from reason_key/reason_params (see [FeaturedSlot]), so
  /// passing it is belt-and-braces for a key this build doesn't know yet.
  static Future<List<FeaturedSlot>> listFeatured({String lang = 'en'}) async {
    final uri = Uri.parse('$_baseUrl/rpc/list_featured');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'p_lang': lang}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('list_featured HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => FeaturedSlot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Demozoo production sheet via `get_production_details` (migs 161-163).
  /// null when the id is unknown / the RPC fails — the caller keeps the chip
  /// title it already had.
  static Future<ProductionDetails?> getProductionDetails(int productionId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rpc/get_production_details');
      final response = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'p_production_id': productionId}))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      // The RPC returns a row set; a JSONB scalar would decode to a Map.
      final j = decoded is List
          ? (decoded.isEmpty ? null : decoded.first as Map<String, dynamic>)
          : decoded as Map<String, dynamic>?;
      if (j == null) return null;
      return ProductionDetails.fromJson(j);
    } catch (_) {
      return null;
    }
  }

  /// Soundtrack of a production via `get_production_tracks` — SAME columns as
  /// get_playlist_tracks, so the SearchResult parser applies as-is
  /// (`track_position` = order inside the demo, `meta.kind` = own|used_in).
  static Future<List<SearchResult>> productionTracks(int productionId) async {
    final uri = Uri.parse('$_baseUrl/rpc/get_production_tracks');
    final response = await http
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'p_production_id': productionId}))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('get_production_tracks HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `list_productions` — the browse catalogue of demozoo productions (the
  /// facet card that replaced the removed `production` tag category).
  /// [byUsage] true = most tunes first, false = alphabetical.
  /// [onlyWithVideo] keeps only productions with a video OF THEIR OWN.
  /// Productions with no playable tune are excluded server-side.
  static Future<List<ProductionSearchRow>> listProductions({
    String? query,
    bool byUsage = true,
    bool onlyWithVideo = false,
    bool fuzzy = true,
    List<String>? types,
    String? group,
    int? yearMin,
    int? yearMax,
    int limit = 100,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/rpc/list_productions');
    final response = await http
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
              'fuzzy': fuzzy,
              'by_usage': byUsage,
              'only_with_video': onlyWithVideo,
              if (types != null && types.isNotEmpty) 'types_filter': types,
              if (group != null && group.isNotEmpty) 'group_name': group,
              if (yearMin != null) 'year_min': yearMin,
              if (yearMax != null) 'year_max': yearMax,
              'lim': limit,
              'from_offset': offset,
            }))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('list_productions HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    final out = <ProductionSearchRow>[];
    for (final e in list) {
      final row = ProductionSearchRow.fromJson(e as Map<String, dynamic>);
      if (row != null) out.add(row);
    }
    return out;
  }

  /// Albums a production's tunes come from — `get_production_albums`, EXACT
  /// shape of get_artist_albums (artist_names = the album's composers), so the
  /// ArtistAlbum parser and the album tiles apply unchanged.
  static Future<List<ArtistAlbum>> getProductionAlbums(int productionId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rpc/get_production_albums');
      final response = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'p_production_id': productionId}))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return const [];
      final list = jsonDecode(response.body) as List;
      return list
          .map((e) => ArtistAlbum.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// `search_productions` — disambiguated production rows for the search tab
  /// and the typeahead. Empty list on any failure (a search must never throw
  /// the whole screen).
  static Future<List<ProductionSearchRow>> searchProductions(
    String query, {
    bool fuzzy = true,
    bool onlyWithVideo = false,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/rpc/search_productions');
      final response = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'q': query,
                'fuzzy': fuzzy,
                'only_with_video': onlyWithVideo,
                'lim': limit,
                'from_offset': offset,
              }))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return const [];
      final list = jsonDecode(response.body) as List;
      final out = <ProductionSearchRow>[];
      for (final e in list) {
        final row = ProductionSearchRow.fromJson(e as Map<String, dynamic>);
        if (row != null) out.add(row);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Ordered tracks of a playlist via `get_playlist_tracks` RPC.
  /// Same columns as browse_music → reuse SearchResult parser.
  ///
  /// The token is sent unconditionally (see [_headers]): a PRIVATE playlist
  /// without it comes back as an EMPTY LIST, not as an error — the failure mode
  /// looks exactly like an empty playlist. Ignored for server-curated ones.
  ///
  /// A row whose `ext_ref` is set (migration 176) is an out-of-catalogue entry:
  /// EVERY catalogue column is null on it, so it must never reach the normal
  /// parser (`filename` is required there and would throw).
  ///
  /// ⚠️ Le serveur PLAFONNE une page à 1000 lignes — silencieusement: la
  /// playlist de classement vgmrips (2364 pistes) revenait tronquée sans
  /// erreur. [offset]/[limit] passent `from_offset`/`lim` (noms vérifiés dans
  /// le hint PostgREST); [playlistTracksAll] enchaîne les pages.
  static Future<List<SearchResult>> playlistTracks(String playlistId,
      {int? limit, int? offset}) async {
    final uri = Uri.parse('$_baseUrl/rpc/get_playlist_tracks');
    final response = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'p_playlist_id': playlistId,
            if (limit != null) 'lim': limit,
            if (offset != null) 'from_offset': offset,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('get_playlist_tracks HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return numberSubsongTitles([
      // The branch is on `filename`, NOT on ext_ref: an entry may carry BOTH a
      // song_id and an ext_ref (verified against the server — the row then
      // comes back complete, catalogue columns included). That is how a
      // catalogue container keeps its subsong index across devices.
      for (final e in list.cast<Map<String, dynamic>>())
        if (e['filename'] == null && e['ext_ref'] is Map)
          SearchResult.fromExtRef(
            PlaylistExtRef.fromJson(
                Map<String, dynamic>.from(e['ext_ref'] as Map)),
            trackPosition: (e['track_position'] as num?)?.toInt(),
          )
        else
          _playlistCatalogueRow(e),
    ]);
  }

  /// Numbers the entries that are SUBSONGS OF ONE FILE and share its single
  /// catalogue title.
  ///
  /// A container has no per-subsong name server-side — the catalogue knows the
  /// FILE ("monkey island") and nothing else — so a published playlist made of
  /// its subsongs came back as 21 identical lines, where the local copy read
  /// "monkey island (1)", "(2)"… The numbering is not stored anywhere: it is
  /// the entry's POSITION among the entries of that same file, computed here
  /// so every reader of the playlist sees it, not just the device that built
  /// it. Left untouched as soon as the titles actually differ — a real
  /// tracklist (joshw, STIL) names its subsongs and must keep those names.
  static List<SearchResult> numberSubsongTitles(List<SearchResult> rows) {
    final groups = <String, List<int>>{};
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      // Out-of-catalogue entries carry their own snapshot title — et elles se
      // reconnaissent à leur songId VIDE, pas à la présence d'un `ext_ref`:
      // une ligne de CATALOGUE en porte un aussi (c'est là que voyage l'index
      // de sous-chanson d'un conteneur). Tester `extRef != null` écartait donc
      // toutes les lignes de la playlist, et la numérotation ne s'appliquait
      // jamais là où elle sert.
      if (r.songId.isEmpty) continue;
      (groups['${r.songId.split('#').first}|${r.filename}'] ??= <int>[]).add(i);
    }
    final out = List.of(rows);
    for (final idxs in groups.values) {
      if (idxs.length < 2) continue;
      final title = out[idxs.first].displayTitle;
      if (title.isEmpty) continue;
      if (!idxs.every((i) => out[i].displayTitle == title)) continue;
      for (var k = 0; k < idxs.length; k++) {
        out[idxs[k]] =
            out[idxs[k]].withSubsong(out[idxs[k]].subsongIdx,
                title: '$title (${k + 1})');
      }
    }
    return out;
  }

  /// Catalogue playlist row. When the row is a CONTAINER album and the entry's
  /// ext_ref names a file inside it, narrow to that single file: the server
  /// returns the container COMPLETE (its full `tracks` list), and enqueuing it
  /// as-is put the whole album in the queue in place of the one pinned track
  /// (a 4-entry playlist holding one jw_spc track queued 70 rows).
  /// Exposée pour le test de la traduction rang → vrai index (les membres
  /// privés ne traversent pas la frontière de bibliothèque).
  @visibleForTesting
  static SearchResult playlistCatalogueRowForTest(Map<String, dynamic> e) =>
      _playlistCatalogueRow(e);

  static SearchResult _playlistCatalogueRow(Map<String, dynamic> e) {
    var r = SearchResult.fromJson(e);
    final ext = e['ext_ref'];
    if (ext is! Map) return r;
    // La tracklist COMPLÈTE du conteneur, capturée AVANT tout rétrécissement:
    // c'est elle qui traduit le rang transporté par ext_ref en VRAI index de
    // sous-chanson, sans aller-retour serveur.
    final tracklist = r.subsongs;
    final fn = ext['file_name'] as String?;
    if (r.subsongs.length > 1 && fn != null && fn.isNotEmpty) {
      for (final s in r.subsongs) {
        if (s.file == fn) { r = r.narrowedToFile(s); break; }
      }
    }
    // ...and the SUBSONG the entry pinned. The server answers with the whole
    // FILE (one `song_id`, `track_count` of every subsong it holds) and keeps
    // the index in `ext_ref` — which is how a container entry survives from one
    // device to the next. Dropping it left all 21 entries of a TFMX playlist
    // pointing at subsong 0 of the same file, and each one still claiming the
    // whole file, so play-all queued 61 rows instead of 21.
    final sub = (ext['subsong_idx'] as num?)?.toInt();
    if (sub != null && (sub != 0 || (r.subsongCount ?? 0) > 1)) {
      r = r.withSubsongEntry(sub);
      // La valeur d'ext_ref est un RANG pour un fichier à tracklist — or
      // withSubsongEntry la posait
      // AUSSI en subsong_idx, l'index que le moteur joue: sur un fichier à
      // décalage (.gbs à NOSOUND, .kss absolu) la lecture visait la
      // sous-chanson du rang. Le rang reste l'IDENTITÉ (`#rang`); l'index
      // joué vient de l'entrée de tracklist qu'il désigne.
      if (sub >= 0 && sub < tracklist.length) {
        final t = tracklist[sub];
        if (t.subsong != null) {
          r = r.copyWith(
            subsongIdx: t.subsong,
            durationMs: t.lengthMs,
            title: (t.title != null && t.title!.isNotEmpty) ? t.title : null,
          );
        } else if (fn != null && fn.isNotEmpty) {
          // Membre d'album multi-fichiers (pas de clé subsong): SON fichier
          // joue entier — narrowedToFile avait posé 0, withSubsongEntry
          // l'avait écrasé par le rang.
          r = r.copyWith(subsongIdx: 0);
        }
      }
    }
    return r;
  }

  /// Returns full album metadata via `get_album_details` RPC.
  /// Returns a list (may contain multiple if album name is ambiguous).
  static Future<List<AlbumDetails>> fetchAlbumDetails(
    String albumName, {
    String? platformName,
    String? collectionSlug,
    String? albumId,
  }) async {
    final uri = Uri.parse('$_baseUrl/rpc/get_album_details');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          // p_album_id (when present) is authoritative server-side → returns the
          // exact album; otherwise fall back to name/platform/collection match.
          body: jsonEncode({
            if (albumId != null) 'p_album_id': albumId,
            'album_name': albumName,
            if (platformName != null) 'platform_name': platformName,
            if (collectionSlug != null) 'collection_slug': collectionSlug,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('get_album_details HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => AlbumDetails.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- Reference data -------------------------------------------------------

  /// slug → nom lisible, mémorisé au premier [fetchCollections].
  ///
  /// Une ligne de recherche ne porte que le SLUG (`jw_dsf`, `asma`), et c'est
  /// lui qu'on affichait. Le nom vit dans une table de référence que les écrans
  /// de recherche et de navigation chargent déjà pour leurs menus de facettes —
  /// le mémoriser ici évite de le redemander et rend le nom disponible SANS
  /// attente à l'endroit où il s'affiche.
  static Map<String, String> _collectionNames = const {};

  /// Le nom lisible d'une collection, ou le slug tant qu'on ne le connaît pas
  /// (premier affichage avant que la table de référence soit chargée) — jamais
  /// une chaîne vide: mieux vaut un slug qu'un trou.
  static String collectionLabel(String slug) =>
      _collectionNames[slug] ?? slug;

  static Future<List<Collection>> fetchCollections() async {
    final uri = Uri.parse('$_baseUrl/collections').replace(queryParameters: {
      'select': 'slug,name,files_count',
      'order': 'name.asc',
    });
    final response = await http.get(uri, headers: {
      'Accept': 'application/json'
    }).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('fetchCollections HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    final cols = list
        .map((e) => Collection.fromJson(e as Map<String, dynamic>))
        .toList();
    _collectionNames = {for (final c in cols) c.slug: c.name};
    return cols;
  }

  /// Formats actually present (with usage counts) via `list_formats` RPC,
  /// optionally scoped to one collection. Sorted by popularity server-side.
  static Future<List<MusicFormat>> fetchFormats({
    String? collection,
    List<String>? collections, // p_collections (mig 243) — voir search()
  }) async {
    final uri = Uri.parse('$_baseUrl/rpc/list_formats');
    final response = await _postJsonOptional(
          uri,
          {
            if (collection != null) 'collection_slug': collection,
            if (collection == null && collections != null && collections.isNotEmpty)
              'p_collections': collections,
          },
          optional: const {'p_collections'},
        );
    if (response.statusCode != 200) {
      throw Exception('fetchFormats HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => MusicFormat.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Albums tab of the cross-entity search via `search_albums` RPC. An album
  /// matches by name/alias (direct) OR via an artist / a song title (1-hop,
  /// migration 099). Full song-level filter set + sort contract. `fuzzy` defaults
  /// false (exact/prefix — server reco); use true as a "did you mean" fallback.
  static Future<List<ArtistAlbum>> searchAlbums(
    String q, {
    bool fuzzy = false,
    String? collection,
    List<String>? collections, // p_collections (mig 240) — voir search()
    String? platform,
    String? formatFilter,
    String? chipName,
    List<String> tags = const [],
    List<String>? tagCategories, // mig 159: tag_categories
    int? yearMin,
    int? yearMax,
    num? ratingMin,
    int? podium, // p_podium — voir search()
    String? seed,
    String sortBy = 'relevance', // relevance|name|popularity|year|recent|random
    String? sortDir,             // asc|desc; server default per sort_by
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/rpc/search_albums');
    final response = await _postJsonOptional(
          uri,
          {
            'q': q,
            'fuzzy': fuzzy,
            if (collection != null) 'collection_slug': collection,
            if (collections != null && collections.isNotEmpty)
              'p_collections': collections,
            if (platform != null) 'platform_name': platform,
            if (formatFilter != null) 'format_filter': formatFilter,
            if (chipName != null) 'chip_name': chipName,
            ..._tagParams(tags, tagCategories),
            if (yearMin != null) 'year_min': yearMin,
            if (yearMax != null) 'year_max': yearMax,
            if (ratingMin != null) 'rating_min': ratingMin,
            if (podium != null && podium >= 0 && podium <= 3) 'p_podium': podium,
            if (seed != null) 'seed': seed,
            'sort_by': sortBy,
            if (sortDir != null) 'sort_dir': sortDir,
            'lim': limit,
            'from_offset': offset,
          },
          optional: const {'p_collections', 'p_podium'},
        );
    if (response.statusCode != 200) {
      throw Exception('search_albums HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    final rows = list
        .map((e) => ArtistAlbum.fromJson(e as Map<String, dynamic>))
        .toList();
    return podium != null && serverLacks('p_podium')
        ? [for (final a in rows) if (a.podium != null && (podium == 0 || a.podium!.rank == podium)) a]
        : rows;
  }

  /// Artistes tab of the cross-entity search via `search_artists` RPC (migration
  /// 098) — the real server-side artist search (replaces the old lossy client
  /// derivation). Matches by name (direct) OR via a matched song/album (1-hop).
  /// `fuzzy` defaults false; full filter set + sort contract.
  static Future<List<ArtistResult>> searchArtists(
    String q, {
    bool fuzzy = false,
    String? collection,
    /// p_collections (mig 247) — voir search(). ⚠️ Le serveur filtre sur les
    /// MORCEAUX connectés et rend une UNION: sc68 157 + zxart 16 = 173
    /// artistes, pas 173 par addition — un même artiste présent dans les deux
    /// collections ne compte qu'une fois.
    List<String>? collections,
    String? platform,
    String? formatFilter,
    String? chipName,
    /// Full country name as `CollectionOverview.countries[]` renders it
    /// ("Norway", never "NO") — server compares lower(), union of
    /// artists.country ∪ amp_artists.countries (mig 213).
    String? country,
    List<String> tags = const [],
    List<String>? tagCategories, // mig 159: tag_categories
    int? yearMin,
    int? yearMax,
    num? ratingMin,
    String? seed,
    String sortBy = 'relevance', // relevance|name|popularity|random
    String? sortDir,
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/rpc/search_artists');
    final response = await _postJsonOptional(
          uri,
          {
            'q': q,
            'fuzzy': fuzzy,
            if (collection != null) 'collection_slug': collection,
            if (collection == null && collections != null && collections.isNotEmpty)
              'p_collections': collections,
            if (platform != null) 'platform_name': platform,
            if (formatFilter != null) 'format_filter': formatFilter,
            if (chipName != null) 'chip_name': chipName,
            if (country != null) 'p_country': country,
            ..._tagParams(tags, tagCategories),
            if (yearMin != null) 'year_min': yearMin,
            if (yearMax != null) 'year_max': yearMax,
            if (ratingMin != null) 'rating_min': ratingMin,
            if (seed != null) 'seed': seed,
            'sort_by': sortBy,
            if (sortDir != null) 'sort_dir': sortDir,
            'lim': limit,
            'from_offset': offset,
          },
          optional: const {'p_collections'},
        );
    if (response.statusCode != 200) {
      throw Exception('search_artists HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => ArtistResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Facet counts (format / platform / collection) for the current `q` + filters
  /// via `search_facets` RPC (migration 098) — feeds the filter dropdowns with
  /// true totals over the whole candidate set. No sort/pagination (aggregation).
  /// The counted dimension is NOT restricted by its own value, so pass every
  /// active filter EXCEPT (optionally) the one being displayed.
  ///
  /// [grain] choisit CE QUI EST COMPTÉ (migration 229): 'song' (défaut) ou
  /// 'album'. Un écran d'albums doit demander 'album' — au grain morceau, C64
  /// annonçait 64 697 « entrées » pour zéro album, et l'unité affichée mentait.
  /// Au grain album les valeurs à zéro ne sortent tout simplement pas, donc la
  /// liste n'a plus d'entrées mortes à écarter.
  static Future<List<FacetCount>> searchFacets(
    String q, {
    bool fuzzy = false,
    String? grain,
    /// Scopes the counts to ONE artist (homonym-proof id, else the name) —
    /// what makes the artist screen's filter dropdowns complete instead of
    /// "whatever rows happen to be loaded".
    String? artistId,
    String? artistName,
    String? collection,
    List<String>? collections, // p_collections (mig 243) — voir search()
    String? platform,
    String? formatFilter,
    String? chipName,
    List<String> tags = const [],
    List<String>? tagCategories, // mig 159: tag_categories
    int? yearMin,
    int? yearMax,
    num? ratingMin,
    int? podium, // p_podium: null = aucun, 0 = tout podium, 1-3 = ce rang (podium_filter.dart)
  }) async {
    final uri = Uri.parse('$_baseUrl/rpc/search_facets');
    final response = await _postJsonOptional(
          uri,
          {
            'q': q,
            'fuzzy': fuzzy,
            if (grain != null) 'p_grain': grain,
            if (artistId != null) 'p_artist_id': artistId,
            if (artistName != null) 'artist_name': artistName,
            if (collection != null) 'collection_slug': collection,
            if (collection == null && collections != null && collections.isNotEmpty)
              'p_collections': collections,
            if (platform != null) 'platform_name': platform,
            if (formatFilter != null) 'format_filter': formatFilter,
            if (chipName != null) 'chip_name': chipName,
            ..._tagParams(tags, tagCategories),
            if (yearMin != null) 'year_min': yearMin,
            if (yearMax != null) 'year_max': yearMax,
            if (ratingMin != null) 'rating_min': ratingMin,
            if (podium != null && podium >= 0 && podium <= 3) 'p_podium': podium,
          },
          optional: const {'p_collections', 'p_podium'},
        );
    if (response.statusCode != 200) {
      throw Exception('search_facets HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => FacetCount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns distinct albums for [artistName] via `get_artist_albums` RPC.
  static Future<List<ArtistAlbum>> fetchArtistAlbums(
    String artistName, {
    String? artistId, // p_artist_id (mig 146): homonym-proof artist scoping
    String? collection,
  }) async {
    final uri = Uri.parse('$_baseUrl/rpc/get_artist_albums');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'artist_name': artistName,
            if (artistId != null) 'p_artist_id': artistId,
            if (collection != null) 'collection_slug': collection,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('get_artist_albums HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => ArtistAlbum.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Lists artists, optionally filtered by a name substring (ilike).
  /// Returns up to [limit] entries starting at [offset] — use for infinite scroll.
  static Future<List<Artist>> fetchArtists({
    String? nameFilter,
    int limit = 100,
    int offset = 0,
  }) async {
    var url = '$_baseUrl/artists?select=id,name&order=name.asc'
        '&limit=$limit&offset=$offset';
    if (nameFilter != null && nameFilter.isNotEmpty) {
      url += '&name=ilike.*${Uri.encodeQueryComponent(nameFilter)}*';
    }
    final response = await http.get(Uri.parse(url), headers: {
      'Accept': 'application/json'
    }).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('fetchArtists HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list.map((e) => Artist.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ---- SID metadata ---------------------------------------------------------

  /// Fetches subsong lengths + STIL metadata for a SID file by its HVSC MD5.
  /// Returns null if the server returns no result or an error occurs.
  static Future<SidInfo?> getSidInfo(String md5) async {
    if (md5.isEmpty) return null;
    try {
      final uri = Uri.parse('$_baseUrl/rpc/get_sid_info');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'p_md5': md5}),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      // PostgREST wraps single-row RPC results in a list.
      final Map<String, dynamic>? data = body is List
          ? (body.isNotEmpty ? body.first as Map<String, dynamic>? : null)
          : body as Map<String, dynamic>?;
      if (data == null || data['md5'] == null) return null;
      return SidInfo.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Fetches STIL metadata for an ASMA .sap file by its standard file MD5
  /// (unlike SID, no special libsidplayfp MD5 — any generic file-bytes MD5,
  /// e.g. Dart's crypto package, matches). Returns null if the server
  /// returns no result (unknown MD5) or an error occurs.
  static Future<SapInfo?> getSapInfo(String md5) async {
    if (md5.isEmpty) return null;
    try {
      final uri = Uri.parse('$_baseUrl/rpc/get_sap_info');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'p_md5': md5}),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      final Map<String, dynamic>? data = body is List
          ? (body.isNotEmpty ? body.first as Map<String, dynamic>? : null)
          : body as Map<String, dynamic>?;
      if (data == null || data['md5'] == null) return null;
      return SapInfo.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  // ---- Download -------------------------------------------------------------

  /// Downloads [result] into the persistent online library and returns the
  /// local file path.
  ///
  /// Layout: `<appSupport>/online/<artist>/<format>/<album>/<filename>`
  /// Album segment is omitted when null/empty.
  /// If the file already exists locally it is returned immediately (cache).
  /// Global download status, for the UI banner. Written by every download in
  /// this class; cleared when the download chain completes. On failure the
  /// error stays visible a few seconds (unless a new download replaces it).
  static final ValueNotifier<DownloadInfo?> downloadStatus =
      ValueNotifier<DownloadInfo?>(null);

  static void _statusClear() => downloadStatus.value = null;

  // ── Cancellation ───────────────────────────────────────────────────────────
  // A download started OUTSIDE the queue manager (the play path, deliberately:
  // it must not wait behind a paused queue) has no zone token of its own, so
  // it falls back on this ambient one. Cancelling it aborts every such
  // non-queued fetch in flight — acceptable because the global banner already
  // models the play path as one visible download at a time.
  //
  // A cancelled token is DEAD, so cancelling swaps in a fresh one: the fetches
  // already running captured the old object and still see it cancelled, while
  // anything started afterwards is a new download and must not be born aborted.
  static DownloadCancelToken _ambientCancel = DownloadCancelToken();

  /// True while a non-queued (play-path) download is running and cancellable.
  static bool get hasCancellableAmbientDownload =>
      downloadStatus.value != null && downloadStatus.value!.error == null;

  /// Aborts the download(s) not owned by the queue manager (play path, aux
  /// files). The chain throws [DownloadCancelledException].
  static void cancelAmbientDownloads() {
    _ambientCancel.cancel();
    _ambientCancel = DownloadCancelToken();
    _statusClear();
  }

  static void _statusFail(String label, Object e) {
    downloadStatus.value = DownloadInfo(label, error: e.toString());
    Timer(const Duration(seconds: 6), () {
      final v = downloadStatus.value;
      if (v != null && v.error != null) downloadStatus.value = null;
    });
  }

  // ── Politeness throttle for ban-prone origin hosts (scene.org) ─────────────
  // scene.org bans clients that hammer it. When a multi-file list resolves to
  // scene.org origins (no R2 mirror yet), fetches must go ONE AT A TIME and be
  // spaced out. This gate serializes every throttled fetch and keeps >= 2 s
  // between the START of consecutive ones (so a slow download naturally spaces
  // the next, a fast one waits out the remainder). R2/CDN mirror fetches are
  // NOT throttled — only the origin.
  static const Duration _kOriginMinGap = Duration(seconds: 2);
  static Future<void> _originGate = Future<void>.value();  // serialization chain
  static DateTime? _lastOriginFetchStart;

  /// Combien de temps on attend les EN-TÊTES d'une origine. Voir le
  /// commentaire au point d'appel: 20 s perdait des morceaux sur une route
  /// lente par intermittence.
  static const Duration _kHeaderTimeout = Duration(seconds: 45);

  static bool _isThrottledHost(String url) {
    final h = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return h.contains('scene.org');
  }

  static Future<T> _throttleOrigin<T>(Future<T> Function() body) async {
    final prev = _originGate;
    final gate = Completer<void>();
    _originGate = gate.future;
    try {
      await prev;   // our turn — only one throttled fetch runs at a time
      final last = _lastOriginFetchStart;
      if (last != null) {
        final wait = _kOriginMinGap - DateTime.now().difference(last);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      _lastOriginFetchStart = DateTime.now();
      return await body();
    } finally {
      gate.complete();
    }
  }

  /// Streamed GET with live progress + stall detection. A dead or crawling
  /// network aborts with TimeoutException (20 s to connect, 30 s max between
  /// chunks, [cap] overall) instead of hanging the playback chain.
  /// Ban-prone origin hosts (scene.org) are serialized + rate-limited.
  static Future<Uint8List> _fetchBytes(
    String url, {
    required String label,
    Duration cap = const Duration(minutes: 5),
  }) {
    debugPrint('[fetch] $label ← $url');
    if (_isThrottledHost(url)) {
      return _throttleOrigin(() => _fetchBytesRaw(url, label: label, cap: cap));
    }
    return _fetchBytesRaw(url, label: label, cap: cap);
  }

  /// Challenge cookies captured per host (e.g. exotica.org.uk's `verified`).
  /// The interstitial's cookie IS the proof of a "real browser"; we replay it
  /// on the retry and on later downloads to the same host (24 h lifetime),
  /// skipping the interstitial round-trip.
  static final Map<String, String> _hostCookies = {};

  static Future<Uint8List> _fetchBytesRaw(
    String url, {
    required String label,
    Duration cap = const Duration(minutes: 5),
  }) async {
    final sink = _MemorySink();
    await _fetchInto(url, sink, label: label, cap: cap);
    return sink.takeBytes();
  }

  /// Comme [_fetchBytesRaw], mais écrit AU FIL DE L'EAU dans [dest] au lieu
  /// de tout accumuler en mémoire. Rend la taille et l'EN-TÊTE (512 octets).
  ///
  /// ⚠️ Pourquoi pas tout en mémoire: une archive d'album pèse couramment
  /// plusieurs centaines de Mo, et elle existait jusqu'ici en ENTIER dans la
  /// RAM — deux fois pour un album zip, `Isolate.run` COPIANT la valeur
  /// capturée dans le nouvel isolate. Sur la machine de développement Linux
  /// (3 Go) c'était un candidat sérieux aux lenteurs signalées le 2026-09-21.
  ///
  /// ⚠️ Écrit dans `<dest>.part`, renommé SEULEMENT au succès. Le tampon
  /// d'archives ne vérifie que l'existence et l'âge d'un fichier: une descente
  /// annulée à mi-course y laisserait sinon une archive TRONQUÉE que
  /// l'appelant suivant réutiliserait comme bonne.
  @visibleForTesting
  static Future<Uint8List> fetchBytesForTest(String url,
          {String label = 'test'}) =>
      _fetchBytesRaw(url, label: label);

  @visibleForTesting
  static Future<(int, Uint8List)> fetchToFileForTest(String url, File dest,
          {String label = 'test'}) =>
      _fetchToFileRaw(url, dest, label: label);

  static Future<(int, Uint8List)> _fetchToFileRaw(
    String url,
    File dest, {
    required String label,
    Duration cap = const Duration(minutes: 5),
  }) async {
    await dest.parent.create(recursive: true);
    final part = File('${dest.path}.part');
    final sink = await _FileSink.open(part);
    try {
      await _fetchInto(url, sink, label: label, cap: cap);
      await sink.close();
      // Une re-descente cache-bustée écrit sur la MÊME destination qu'une
      // première descente réussie: sous Windows, un renommage vers un fichier
      // existant échoue — on l'efface d'abord.
      if (await dest.exists()) await dest.delete();
      await part.rename(dest.path);
      return (sink.length, sink.head);
    } catch (_) {
      await sink.discard();
      rethrow;
    }
  }

  static Future<void> _fetchInto(
    String url,
    _FetchSink sink, {
    required String label,
    Duration cap = const Duration(minutes: 5),
    bool retriedChallenge = false,
  }) async {
    // Cancellation: the token comes from the ZONE the chain runs in (a queue
    // job, or the ambient one for the play path). Two mechanisms because one
    // is not enough — polling per chunk never fires on a STALLED transfer, and
    // force-closing the client alone loses the race against a fast download.
    final cancel = DownloadCancelToken.current ?? _ambientCancel;
    cancel.throwIfCancelled(label);
    // Ce qu'on a écrit EN DERNIER dans la bannière. Sert à ne la ranger que si
    // elle nous décrit encore — un autre téléchargement a pu prendre la main
    // entre-temps, et l'effacer serait lui voler son affichage.
    DownloadInfo? mine;
    void publish(DownloadInfo info) {
      mine = info;
      downloadStatus.value = info;
    }
    publish(DownloadInfo(label));
    final watch = Stopwatch()..start();
    // Le transfert lui-même tourne dans un ISOLATE (voir isolate_fetch.dart:
    // sous Linux la boucle de l'isolate UI plafonnait le débit à ~1,9 Mo/s).
    // Le jeton d'annulation reste ICI — une zone ne traverse pas l'isolate —
    // et lui transmet l'ordre par la fonction enregistrée.
    void Function()? stopTransfer;
    void closeClient() => stopTransfer?.call();
    cancel.register(closeClient);
    try {
      final host = Uri.parse(url).host;
      final cachedCookie = _hostCookies[host];
      // ⚠️ Budget d'ARRIVÉE DES EN-TÊTES, pas du corps (celui-ci a son propre
      // délai d'inactivité, 30 s par bloc, et le plafond total `cap`).
      //
      // 20 s était trop serré pour une origine NON MIROITÉE. Mesuré le
      // 2026-09-02 sur `ftp.modland.com`: 0,19 s de TTFB depuis un poste fixe,
      // 8 requêtes d'affilée sans throttling — et pourtant plus de 20 s depuis
      // une tablette Android, deux fois, avant de repasser tout seul. Une
      // route qui traîne par intermittence ne doit pas coûter le morceau: on
      // laisse 45 s, puis on retente UNE fois sur une connexion NEUVE (un
      // socket à moitié établi ne se répare pas tout seul) — dans l'isolate.
      int? total;
      final IsolateFetchResult got;
      try {
        got = await isolateFetch(
          url,
          cookie: cachedCookie,
          filePath: sink.path,
          headerTimeout: _kHeaderTimeout,
          stallTimeout: const Duration(seconds: 30),
          cap: cap,
          registerCancel: (stop) => stopTransfer = stop,
          onHead: (h) {
            if (h.status != 200) {
              throw DownloadHttpException(h.status, url);
            }
            total = h.contentLength;
            // Some origins (exotica.org.uk) answer the first hit with a 200
            // HTML interstitial that only sets a `verified` cookie +
            // JS-reloads. Capture that cookie so the retry below (and future
            // downloads) get the file.
            final setCookie = h.setCookie;
            if (setCookie != null) {
              final m = RegExp(r'(verified=[^;]+)').firstMatch(setCookie);
              if (m != null) _hostCookies[host] = m.group(1)!;
            }
          },
          onProgress: (n) {
            sink.progress(n);
            final t = total;
            publish(DownloadInfo(
              label,
              progress: (t != null && t > 0) ? n / t : null,
            ));
          },
        );
      } on FetchHeaderTimeout {
        throw DownloadTimeoutException(host, url);
      }
      sink.finish(got);
      // Got the interstitial, not the file — replay once with the cookie the
      // interstitial just handed us (the JS reload does exactly this).
      if (!retriedChallenge &&
          _looksLikeHtml(sink.head) &&
          _hostCookies.containsKey(host)) {
        // `await` OBLIGATOIRE: sans lui le rejeu sort du `try` avant de
        // pouvoir échouer, donc un interstitiel qui rate emporte AVEC LUI le
        // rangement de bannière et la requalification en annulation ci-dessous
        // — le « en cours de téléchargement » POUR TOUJOURS que ce catch
        // existe précisément pour éviter.
        // Le puits repart de ZÉRO: sans ça la page d'interstitiel resterait
        // collée devant le vrai fichier.
        await sink.reset();
        return await _fetchInto(url, sink,
            label: label, cap: cap, retriedChallenge: true);
      }
      final secs = watch.elapsedMilliseconds / 1000;
      debugPrint('[fetch] $label: ${sink.length} octets en '
          '${secs.toStringAsFixed(1)} s '
          '(${(sink.length / (secs > 0 ? secs : 1) / 1e6).toStringAsFixed(2)} Mo/s)');
    } catch (e) {
      debugPrint('[fetch] $label: ÉCHEC après '
          '${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)} s et '
          '${sink.length} octets — $e');
      // ⚠️ **Un fetch qui LÈVE doit ranger la bannière qu'il a allumée.**
      // Elle est posée à l'entrée, et seul le succès la rangeait (via le
      // `_statusClear()` de `downloadToLibrary`): tout appelant qui rattrape
      // l'échec sans repasser par là — un miroir qui bascule sur l'origine,
      // une annexe optionnelle, une archive partagée — laissait « en cours de
      // téléchargement » à l'écran POUR TOUJOURS, sans rien pour l'enlever.
      // Rapporté par un testeur beta Android derrière un domaine bloqué: la
      // bannière est restée alors que le fichier s'était bien téléchargé
      // ensuite. Le cas d'une erreur AFFICHÉE, lui, se range tout seul
      // (`_statusFail` arme un délai de 6 s) — c'est le cas silencieux qui
      // manquait.
      //
      // Rangée seulement si elle nous décrit ENCORE: entre-temps un autre
      // téléchargement a pu prendre la bannière, et l'effacer lui volerait
      // son affichage.
      if (identical(downloadStatus.value, mine)) _statusClear();
      // A cancel force-closes the socket, so the failure surfaces as a
      // ClientException/StateError from the aborted stream. The token is the
      // ground truth about WHY it died.
      if (cancel.isCancelled && e is! DownloadCancelledException) {
        throw DownloadCancelledException(label);
      }
      rethrow;
    } finally {
      cancel.unregister(closeClient);
    }
  }

  /// Mirror-first download: try [mirrorUrl] (R2/CDN) when present, fall back
  /// to [originUrl] if the mirror fails (404 = not yet synced, or any error).
  /// True when [bytes] begin with HTML rather than binary payload — i.e. the
  /// server answered with a page (bot check, 404 body, captcha) under a 200.
  static bool _looksLikeHtml(List<int> bytes) {
    final n = bytes.length < 512 ? bytes.length : 512;
    if (n == 0) return false;
    final head = String.fromCharCodes(bytes.sublist(0, n)).trimLeft().toLowerCase();
    return head.startsWith('<!doctype html') ||
           head.startsWith('<html') ||
           head.startsWith('<?xml') && head.contains('<html');
  }

  /// Ajoute une query unique à [url] — clé de cache différente, donc l'edge
  /// CDN ne peut pas répondre avec sa copie. Utilisé quand on SAIT que le
  /// contenu a changé sous la même url (album remplacé, « Re-télécharger »).
  static String cacheBusted(String url) =>
      '$url${url.contains('?') ? '&' : '?'}'
      'rcb=${DateTime.now().millisecondsSinceEpoch}';

  /// Fetch d'une archive dont le serveur annonce la TAILLE. Une taille reçue
  /// différente = l'edge CDN a servi une copie PÉRIMÉE (les archives sont
  /// publiées en `Cache-Control: immutable`, et un remplacement réutilise
  /// l'url en changeant `file_size`) → une seule re-descente cache-bustée.
  /// C'est ce qui évite de payer, au PREMIER téléchargement, l'ancienne
  /// version puis tout le ballet de détection/wipe derrière.
  /// Taille annoncée par le serveur d'origine pour [url], via HEAD — servie
  /// depuis la MÊME clé de cache que le GET, donc elle dit ce que l'edge
  /// s'apprête à livrer. -1 = inconnue (méthode refusée, réseau, en-tête
  /// absent): l'appelant continue sans juger.
  static Future<int> _remoteSize(String url) async {
    try {
      final resp = await http
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode < 200 || resp.statusCode >= 300) return -1;
      return int.tryParse(resp.headers['content-length'] ?? '') ?? -1;
    } catch (_) {
      return -1;
    }
  }

  /// L'url SANS son cache-buster: `rcb=` change à chaque appel, donc une clé
  /// qui le garde ne reconnaît jamais deux fetchs de la même archive — et la
  /// déduplication ci-dessous ne servirait à rien, en silence. Publique pour
  /// être testable (`archive_dedup_test.dart`).
  static String archiveKeyForUrl(String url) {
    final qi = url.indexOf('?');
    if (qi < 0) return url;
    final kept = url
        .substring(qi + 1)
        .split('&')
        .where((part) => !part.startsWith('rcb='))
        .join('&');
    return kept.isEmpty ? url.substring(0, qi) : '${url.substring(0, qi)}?$kept';
  }

  /// Taille RÉELLE d'une archive, une fois qu'une descente cache-bustée a
  /// prouvé que le `file_size` du catalogue était périmé.
  ///
  /// Sans ce mémo, chaque appel refait le même constat et le REPAYE: sur
  /// « Remember Me » (298 Mo, catalogue en retard de 275 Ko), la détection
  /// coûtait une seconde descente complète au premier appel, puis une
  /// troisième au suivant via la sonde HEAD. Le catalogue a tort une fois pour
  /// toutes — pas une fois par appelant. Effacé par un `force`
  /// (« Re-télécharger »), dont la raison d'être est justement que le contenu
  /// a pu changer sous la même url.
  static final Map<String, int> _archiveRealSize = {};

  static Future<(int, Uint8List)> _fetchArchiveVerified(
    String? mirrorUrl,
    String originUrl,
    File dest, {
    required String label,
    required int expectedSize,
    Duration cap = const Duration(minutes: 5),
  }) async {
    final key = archiveKeyForUrl(originUrl);
    // Le mémo prime sur le catalogue: il a été MESURÉ, l'autre est déclaratif.
    final expect = _archiveRealSize[key] ?? expectedSize;

    // Sonde AVANT de payer l'archive: un HEAD (quelques octets) sur l'url qui
    // servira en premier. Taille différente de celle attendue ⇒ l'edge tient
    // une copie périmée ⇒ on part directement en cache-busté au lieu de
    // télécharger 200 Mo pour les jeter.
    if (expect > 0) {
      var remote = -1;
      if (mirrorUrl != null && mirrorUrl.isNotEmpty) {
        remote = await _remoteSize(mirrorUrl);
      }
      // Miroir muet (404 « pas encore synchronisé », méthode refusée): sonder
      // l'ORIGINE, qui est ce qui servira alors. C'est ce chaînon qui manquait
      // — sans lui le désaccord n'apparaissait qu'APRÈS les 298 Mo, et la
      // détection coûtait un aller-retour complet au lieu d'un HEAD.
      if (remote <= 0) remote = await _remoteSize(originUrl);
      if (remote > 0 && remote != expect) {
        debugPrint('[fetch] $label: HEAD says $remote, expected $expect '
            '— skipping the stale copy, fetching cache-busted');
        final busted = await _fetchToFileMirror(
            null, cacheBusted(originUrl), dest, label: label, cap: cap);
        _rememberArchiveSize(key, busted.$1, expectedSize, label);
        return busted;
      }
    }
    final got = await _fetchToFileMirror(mirrorUrl, originUrl, dest,
        label: label, cap: cap);
    if (expect <= 0 || got.$1 == expect) return got;
    debugPrint('[fetch] $label: ${got.$1} bytes but expected $expect '
        '— stale CDN copy, refetching cache-busted');
    final fresh = await _fetchToFileMirror(
        null, cacheBusted(originUrl), dest, label: label, cap: cap);
    _rememberArchiveSize(key, fresh.$1, expectedSize, label);
    return fresh;
  }

  /// Une descente cache-bustée dit ce que l'ORIGINE sert vraiment. Si ça ne
  /// colle toujours pas au catalogue, c'est le catalogue qui est en retard:
  /// on garde ce qui est arrivé et on le note, pour que l'appelant suivant
  /// n'ait pas à le redécouvrir à ses frais.
  static void _rememberArchiveSize(
      String key, int got, int catalogueSize, String label) {
    if (got <= 0) return;
    _archiveRealSize[key] = got;
    if (catalogueSize > 0 && got != catalogueSize) {
      debugPrint('[fetch] $label: still $got bytes after busting — catalogue '
          'file_size ($catalogueSize) is stale, remembered for this session');
    }
  }

  // ── Archive partagée entre appelants ──────────────────────────────────────
  // UNE archive d'album est réclamée par PLUSIEURS chemins pendant le même
  // geste: la voie « tracklist connue » (downloadAndExtractZip), la voie PSF
  // (downloadPsfAlbum) et l'extraction PAR PISTE (_downloadAndExtractSingle)
  // descendent chacune la même url, de zéro. Mesuré sur « Remember Me »
  // (jw_x360, 298 Mo): quatre descentes, ~1,2 Go, pour un album.
  //
  // Rien ne dédupliquait parce que rien n'était clé sur l'URL — chaque voie
  // raisonne sur son DOSSIER (_withDirLock) ou sur le fichier qu'elle attend,
  // et deux voies visant le même dossier n'y voient rien de commun tant que
  // l'extraction n'a pas eu lieu. La bonne clé est l'archive elle-même.
  //
  // Donc: une copie sur disque, partagée, à durée de vie courte. Court parce
  // qu'un album pèse des centaines de mégaoctets — c'est un tampon de geste,
  // pas un cache. Purgée au démarrage ([purgeArchiveCache], appelée par
  // main()) et à chaque accès au-delà de [_kArchiveCacheTtl].
  static const Duration _kArchiveCacheTtl = Duration(minutes: 10);
  static final Map<String, Future<String>> _archiveInflight = {};

  static Future<Directory> _archiveCacheDir() async {
    final base = await _baseDir();
    final d = Directory(p.join(base.path, 'online', '_archive_cache'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static String _archiveCacheName(String key, String url) {
    // Le NOM du fichier ne peut pas être l'url (longueur, séparateurs); un
    // digest la représente sans ambiguïté. L'extension est conservée: elle est
    // ce que libarchive lit pour choisir son format.
    final ext = p.extension(Uri.tryParse(url)?.path ?? url);
    return '${sha1.convert(utf8.encode(key))}$ext';
  }

  /// Efface les entrées trop vieilles. Appelée à chaque accès: le tampon ne
  /// doit pas survivre au geste qui l'a rempli.
  static Future<void> _sweepArchiveCache() async {
    try {
      final dir = await _archiveCacheDir();
      final now = DateTime.now();
      await for (final e in dir.list()) {
        if (e is! File) continue;
        final age = now.difference((await e.stat()).modified);
        if (age > _kArchiveCacheTtl) await e.delete().catchError((_) => e);
      }
    } catch (_) {/* le tampon est un confort, jamais une condition */}
  }

  /// Vide le tampon d'archives. À appeler au démarrage: un plantage ou un kill
  /// pendant une extraction laisse sinon des centaines de mégaoctets derrière.
  static Future<void> purgeArchiveCache() async {
    try {
      final dir = Directory(
          p.join((await _baseDir()).path, 'online', '_archive_cache'));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// Une entrée VALIDE du tampon: présente et plus jeune que le TTL. Rend sa
  /// taille et son EN-TÊTE — jamais son contenu: c'était une relecture ENTIÈRE
  /// de l'archive en mémoire à chaque réutilisation.
  static Future<(int, Uint8List)?> _archiveCacheHead(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      final st = await f.stat();
      if (DateTime.now().difference(st.modified) > _kArchiveCacheTtl) {
        await f.delete().catchError((_) => f);
        return null;
      }
      final head = await _readHead(path);
      return head == null ? null : (st.size, head);
    } catch (_) {
      return null;
    }
  }

  /// Les 512 premiers octets d'un fichier — ce que regardent les reniflages.
  static Future<Uint8List?> _readHead(String path) async {
    RandomAccessFile? raf;
    try {
      raf = await File(path).open();
      return await raf.read(512);
    } catch (_) {
      return null;
    } finally {
      await raf?.close();
    }
  }

  static Future<String> _archiveCachePath(String key, String url) async =>
      p.join((await _archiveCacheDir()).path, _archiveCacheName(key, url));

  static Future<void> _archiveCacheDrop(String key, String url) async {
    try {
      final dir = await _archiveCacheDir();
      final f = File(p.join(dir.path, _archiveCacheName(key, url)));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Point d'entrée UNIQUE des trois chemins qui descendent une archive
  /// d'album. Rend les octets, en les partageant avec les autres appelants:
  /// une descente déjà EN VOL est rejointe, une descente déjà FAITE est relue
  /// sur disque.
  ///
  /// [bustCache] = geste « Re-télécharger »: il doit traverser l'edge CDN ET
  /// notre propre tampon, sinon il re-sert fidèlement ce qu'on voulait
  /// remplacer.
  /// Rend les octets ET le chemin de la copie partagée (null si le tampon
  /// n'a pas pu être écrit): un appelant qui ne fait qu'EXTRAIRE se sert du
  /// chemin et évite de réécrire 300 Mo dans son propre `_tmp_archive`.
  static Future<(Uint8List, String)> _fetchArchiveShared(
    String? mirrorUrl,
    String originUrl, {
    required String label,
    required int expectedSize,
    Duration cap = const Duration(minutes: 5),
    bool bustCache = false,
  }) async {
    final key = archiveKeyForUrl(originUrl);
    unawaited(_sweepArchiveCache());
    // ⚠️ La descente écrit DIRECTEMENT à cet endroit (via un `.part`), au lieu
    // de tout accumuler en mémoire puis de le recopier dans le tampon. Rend
    // donc toujours un chemin: « tampon indisponible » n'est plus un cas —
    // un disque qui refuse le tampon refuserait aussi les pistes extraites.
    final cachePath = await _archiveCachePath(key, originUrl);

    if (bustCache) {
      _archiveRealSize.remove(key);
      await _archiveCacheDrop(key, originUrl);
    } else {
      final hit = await _archiveCacheHead(cachePath);
      if (hit != null) {
        debugPrint('[archive] $label: reusing the copy already fetched '
            '(${hit.$1} bytes) — $key');
        return (hit.$2, cachePath);
      }
      final inflight = _archiveInflight[key];
      if (inflight != null) {
        debugPrint('[archive] $label: joining the fetch already in flight');
        try {
          final path = await inflight;
          final head = await _readHead(path);
          if (head != null) return (head, path);
        } catch (_) {
          // Celle d'en face a échoué (ou a été annulée par SON auteur): ce
          // n'est pas notre échec, on descend nous-mêmes.
        }
      }
    }

    final done = Completer<String>();
    // Personne n'attend forcément ce futur — sans ignore(), un échec sans
    // rejoignant remonterait en « unhandled exception ».
    done.future.ignore();
    _archiveInflight[key] = done.future;
    try {
      final dest = File(cachePath);
      final (len, head) = bustCache
          ? await _fetchToFileMirror(null, cacheBusted(originUrl), dest,
              label: label, cap: cap)
          : await _fetchArchiveVerified(mirrorUrl, originUrl, dest,
              label: label, expectedSize: expectedSize, cap: cap);
      if (bustCache) _rememberArchiveSize(key, len, expectedSize, label);
      done.complete(cachePath);
      return (head, cachePath);
    } catch (e, st) {
      done.completeError(e, st);
      rethrow;
    } finally {
      _archiveInflight.remove(key);
    }
  }

  /// Pendant fichier de [_fetchBytes]: même routage vers la file de politesse
  /// pour les hôtes qui bannissent (scene.org).
  static Future<(int, Uint8List)> _fetchToFile(
    String url,
    File dest, {
    required String label,
    Duration cap = const Duration(minutes: 5),
  }) {
    debugPrint('[fetch] $label ← $url (→ fichier)');
    if (_isThrottledHost(url)) {
      return _throttleOrigin(
          () => _fetchToFileRaw(url, dest, label: label, cap: cap));
    }
    return _fetchToFileRaw(url, dest, label: label, cap: cap);
  }

  /// Pendant fichier de [_fetchBytesMirror]: miroir d'abord, origine ensuite.
  /// Un miroir qui échoue À MI-COURSE ne laisse rien: `_fetchToFileRaw` repart
  /// d'un `.part` neuf et efface le précédent.
  static Future<(int, Uint8List)> _fetchToFileMirror(
    String? mirrorUrl,
    String originUrl,
    File dest, {
    required String label,
    Duration cap = const Duration(minutes: 5),
  }) async {
    if (mirrorUrl != null && mirrorUrl.isNotEmpty && mirrorUrl != originUrl) {
      try {
        return await _fetchToFile(mirrorUrl, dest, label: label, cap: cap);
      } on DownloadCancelledException {
        rethrow; // the user aborted — do NOT retry against the origin
      } catch (e) {
        debugPrint('[mirror] $mirrorUrl failed ($e) → origin');
      }
    }
    return _fetchToFile(originUrl, dest, label: label, cap: cap);
  }

  static Future<Uint8List> _fetchBytesMirror(
    String? mirrorUrl,
    String originUrl, {
    required String label,
    Duration cap = const Duration(minutes: 5),
  }) async {
    if (mirrorUrl != null && mirrorUrl.isNotEmpty && mirrorUrl != originUrl) {
      try {
        return await _fetchBytes(mirrorUrl, label: label, cap: cap);
      } on DownloadCancelledException {
        rethrow; // the user aborted — do NOT retry against the origin
      } catch (e) {
        debugPrint('[mirror] $mirrorUrl failed ($e) → origin');
      }
    }
    return _fetchBytes(originUrl, label: label, cap: cap);
  }

  /// Runs the C libarchive extraction in a background isolate: it is a
  /// blocking CPU+IO FFI call that froze the UI for seconds on big albums
  /// (PSF/psf2 7z). RewampAudio() in the new isolate just re-binds the FFI
  /// symbols against the same process library — extraction has no engine
  /// state. Returns (rc, lastError).
  /// Extraction publique HORS du fil UI — l'import local (local_import.dart)
  /// déplie une archive vers le stockage pérenne des imports par ce chemin.
  static Future<(int, String)> extractArchiveTo(
          String archivePath, String destDir) =>
      _extractArchiveOffThread(archivePath, destDir);

  static Future<(int, String)> _extractArchiveOffThread(
      String archivePath, String destDir) {
    return Isolate.run(() {
      final audio = RewampAudio();
      final rc = audio.extractArchive(archivePath, destDir);
      return (rc, rc != 0 ? audio.extractLastError() : '');
    }).timeout(
      // The network fetch has its own timeouts; extraction had NONE, so a wedged
      // native call would hang the whole play chain (and its "downloading…"
      // dialog) forever. Bound it — the caller then surfaces it as an error.
      const Duration(seconds: 120),
      onTimeout: () => (-1, 'archive extraction timed out'),
    );
  }

  // Downloads sharing a source (every subsong row of one archive album shares
  // its .7z downloadUrl) that are already in flight, so a background PREFETCH
  // and the on-demand play of the same album — or two fast taps — reuse ONE
  // download+extraction instead of racing on the same `_tmp_archive` / target
  // dir. Keyed by downloadUrl (stable, shared across an album's tracks), else
  // the target path.
  static final Map<String, Future<String>> _inFlightDownloads = {};

  /// Deletes the stale local copy of a song whose server file was replaced, so
  /// the caller re-downloads the new one. Removes the recorded played file, the
  /// old + new derived paths, AND — because the previous attempt may have
  /// unpacked an archive into the song's dir under names the row can't tell us
  /// (a .xrns module + a scene.org.txt readme…) — every non-artwork file in the
  /// song's own directory except the fresh target. That dir wipe is SKIPPED for
  /// album-grain collections, whose flattened dir is SHARED by every album
  /// member (see _dirSegments) — wiping it would delete sibling tracks.
  /// Best-effort; never throws.
  static Future<void> _purgeSongDownload(
      SearchResult oldRow, SearchResult freshRow, String songId) async {
    var deleted = 0;
    try {
      final rec = await LocalDb.instance.getTrackByOnlineId(songId);
      final freshPath = await _localPath(freshRow);
      final direct = <String>{
        if (rec != null && rec.filePath.isNotEmpty) rec.filePath,
        await _localPath(oldRow),
        freshPath,
      };
      for (final path in direct) {
        try {
          final f = File(path);
          if (await f.exists()) { await f.delete(); deleted++; }
        } catch (_) {}
      }
      // Wipe every non-artwork file in the song's directory (keep the cover +
      // the fresh target). For a per-track dir this just removes the stale
      // extraction junk whose names the row can't give us. For a SHARED album
      // dir — every non-album-grain multi-track album, AND the flattened
      // album-grain dir (online/<col>/<albumKey>, see _dirSegments) — it drops
      // the WHOLE album; the siblings simply re-download on their next play.
      // That is the intended behaviour: if one member of an album was replaced
      // server-side, re-fetching the album is the clean, uniform fix.
      final dir = await artworkDirForResult(oldRow);
      try {
        // RÉCURSIF: un compagnon peut vivre dans un SOUS-DOSSIER
        // (`Instruments/` d'un SMUS, voir [auxRelativePath]). Un balayage à
        // plat les laissait derrière, et « purger » n'aurait purgé qu'à
        // moitié — précisément le cas où le morceau a été remplacé côté
        // serveur et où d'anciens échantillons resteraient collés au neuf.
        await for (final e in Directory(dir).list(recursive: true)) {
          if (e is! File) continue;
          final base = p.basename(e.path);
          if (base.startsWith('artwork.')) continue;   // keep the cover
          if (p.equals(e.path, freshPath)) continue;    // keep the new file
          try { await e.delete(); deleted++; } catch (_) {}
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('[RewampDb] _purgeSongDownload error: $e');
    }
    debugPrint('[RewampDb] purged $deleted stale file(s) for $songId');
  }

  /// When the server has replaced a song's file (same song_id, but a DIFFERENT
  /// download_url than the one we recorded last time), purge the stale local
  /// copy so the caller re-downloads the new file. No-op when the url is
  /// unchanged or was never recorded.
  /// Une url d'OVERRIDE — le rendu que rewamp héberge lui-même pour un morceau
  /// dont l'original n'est pas jouable tel quel.
  static bool _isOverrideUrl(String? url) =>
      url != null && url.contains('/overrides/');

  /// L'OVERRIDE fait autorité: une ligne qui porte encore l'url de l'ORIGINE
  /// est périmée, et il faut la corriger AVANT toute décision de
  /// téléchargement.
  ///
  /// Le cas mesuré (« Inside The BORG Cube », sceneorg): le serveur ne rend
  /// plus QUE l'override pour ce `song_id` — `search_music`, `browse_music` et
  /// `get_song_context` renvoient tous les trois
  /// `files.rewamp.app/overrides/…mp3`. Mais l'entrée de BIBLIOTHÈQUE, elle,
  /// porte l'url que `user_songs` avait au moment où elle a été écrite: le zip
  /// scene.org d'origine, qui ne contient qu'un `.xex` Atari et deux `.txt`.
  /// Jouer depuis la bibliothèque partait donc sur ce zip.
  ///
  /// Deux dégâts, et le second est le pire: `_purgeIfSourceUrlChanged` voyait
  /// deux urls différentes pour un même `song_id`, concluait « remplacé côté
  /// serveur » et EFFAÇAIT le mp3 qui venait d'être téléchargé — d'où un
  /// fichier absent de `online/<collection>/…` et 3,9 Mo re-téléchargés à
  /// chaque lecture.
  ///
  /// ⚠️ La base n'est interrogée que sur une INCOHÉRENCE de la ligne — son
  /// nom de fichier annonce un format, son url pointe une ARCHIVE. Le cas
  /// normal ne coûte donc rien, ce qui compte: ce chemin est celui d'un saut
  /// de piste (voir le CHEMIN RAPIDE de downloadToLibrary).
  static Future<SearchResult> _preferRecordedOverride(SearchResult r) async {
    if (r.songId.isEmpty) return r;
    if (!rowLooksStaleAgainstOverride(r.downloadUrl, r.filename)) return r;
    try {
      final stored = await LocalDb.instance.getDownloadSourceUrl(r.songId);
      if (!_isOverrideUrl(stored)) return r;
      debugPrint('[RewampDb] ${r.songId}: ligne périmée (${r.downloadUrl}) — '
          "l'override fait autorité ($stored)");
      return r.copyWith(downloadUrl: stored, mirrorUrl: stored);
    } catch (_) {
      return r;
    }
  }

  /// La ligne se CONTREDIT-elle — un nom de fichier qui annonce un format
  /// jouable, une url qui pointe une ARCHIVE ? C'est la signature d'une ligne
  /// écrite avant qu'un override existe. PURE et testable: c'est la décision,
  /// la lecture en base ne fait que fournir l'url de remplacement.
  ///
  /// ⚠️ C'est aussi ce qui rend le cas normal GRATUIT: sans contradiction, on
  /// ne demande rien à la base — et ce chemin est celui d'un saut de piste.
  static bool rowLooksStaleAgainstOverride(String? url, String filename) {
    if (url == null || url.isEmpty || _isOverrideUrl(url)) return false;
    const archiveExts = {'zip', '7z', 'rar', 'lha', 'lzh', 'tar', 'gz', 'xz'};
    final urlExt = url.split('?').first.split('.').last.toLowerCase();
    if (!archiveExts.contains(urlExt)) return false;
    final nameExt =
        filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
    return nameExt.isNotEmpty && !archiveExts.contains(nameExt);
  }

  /// Point d'entrée de test pour la règle d'autorité de l'override.
  @visibleForTesting
  static Future<SearchResult> debugPreferRecordedOverride(SearchResult r) =>
      _preferRecordedOverride(r);

  static Future<void> _purgeIfSourceUrlChanged(SearchResult r) async {
    try {
      // A row with NO url of its own says nothing about the source having
      // moved — an archive member (RSN/zip) from a playlist or search comes
      // with download_url null while the recorded source is the ARCHIVE's url
      // (written when the album was played). Comparing null against it purged
      // the whole download on EVERY launch of such a playlist.
      if (r.downloadUrl == null || r.downloadUrl!.isEmpty) return;
      final stored = await LocalDb.instance.getDownloadSourceUrl(r.songId);
      if (stored == null || stored == r.downloadUrl) return;
      // Un OVERRIDE ne se laisse pas évincer par une url d'ORIGINE: ce n'est
      // pas un remplacement côté serveur, c'est une ligne périmée (voir
      // _preferRecordedOverride). Sans cette garde, la ligne de bibliothèque
      // effaçait le rendu qu'on venait de télécharger.
      if (_isOverrideUrl(stored) && !_isOverrideUrl(r.downloadUrl)) {
        debugPrint('[RewampDb] ${r.songId}: url d\'origine ignorée, '
            "l'override reste la source");
        return;
      }
      debugPrint('[RewampDb] source url changed for ${r.songId} (was: $stored)');
      await _purgeSongDownload(r, r, r.songId);
    } catch (e) {
      debugPrint('[RewampDb] _purgeIfSourceUrlChanged error: $e');
    }
  }

  /// After a [FormatUnsupportedException], asks the server whether this song's
  /// download_url has CHANGED since the file we just failed on (the common case:
  /// a broken file replaced server-side, same song_id). If so, purges the stale
  /// local copy and returns a FRESH SearchResult pointing at the new file, so
  /// the caller can retry playback once. Returns null when unchanged (the server
  /// file itself is genuinely unsupported), when offline, or with no song_id —
  /// the caller then shows the "unsupported format" message. A round-trip is
  /// spent ONLY on failure, never on the happy path.
  static Future<SearchResult?> resolveReplacement(
      FormatUnsupportedException e, SearchResult oldRow) async {
    final songId = e.songId;
    if (songId == null || songId.isEmpty) return null;
    try {
      final sc = await getSongContext(songId);
      final s = sc?.song;
      final newUrl = s?.downloadUrl;
      if (s == null || newUrl == null || newUrl.isEmpty) return null;
      // Reference = the url we just failed on (else the last recorded one).
      final reference =
          e.triedUrl ?? await LocalDb.instance.getDownloadSourceUrl(songId);
      if (reference != null && reference == newUrl) return null; // unchanged
      // Replaced: purge the stale local copy (incl. the old extraction) so the
      // retry re-downloads the new file cleanly.
      await _purgeSongDownload(oldRow, s, songId);
      debugPrint('[RewampDb] $songId replaced server-side '
          '(was: ${e.triedUrl}) — retrying with $newUrl');
      return s;
    } catch (err) {
      debugPrint('[RewampDb] resolveReplacement error: $err');
      return null;
    }
  }

  /// On a DOWNLOAD failure (origin gone/404), re-fetch the song's server
  /// metadata and return a FRESH SearchResult when the server now offers a
  /// DIFFERENT source than [oldRow] carried — specifically a newly-added R2
  /// `mirror_url` (the common case: the file was un-mirrored when this row was
  /// cached, and a mirror has since been synced), or a changed `download_url`.
  ///
  /// This is distinct from [resolveReplacement], which gates ONLY on
  /// `download_url` (correct for a REPLACED file, but a new mirror leaves
  /// download_url unchanged, so that gate would miss it). It is also only worth
  /// calling on a *download* failure — a new mirror is the same bytes, so it
  /// cannot rescue a genuinely unsupported FORMAT.
  ///
  /// [triedUrl] is the url we just failed on (so a changed download_url is
  /// measured against what actually failed, not a stale record). Returns null
  /// when the server offers nothing new — the caller then gives up.
  static Future<SearchResult?> refreshSongSource(SearchResult oldRow,
      {String? triedUrl}) async {
    final songId = oldRow.songId.split('#').first.split('?').first;
    if (songId.isEmpty) return null;
    try {
      final s = (await getSongContext(songId))?.song;
      if (s == null) return null;
      final freshMirror = s.mirrorUrl;
      final freshDl = s.downloadUrl;
      final newMirror = freshMirror != null &&
          freshMirror.isNotEmpty &&
          freshMirror != oldRow.mirrorUrl;
      final newDl = freshDl != null &&
          freshDl.isNotEmpty &&
          freshDl != (triedUrl ?? oldRow.downloadUrl);
      if (!newMirror && !newDl) return null;
      debugPrint('[RewampDb] $songId source refreshed after download failure '
          '(mirror ${oldRow.mirrorUrl} → $freshMirror, '
          'dl ${oldRow.downloadUrl} → $freshDl)');
      return s;
    } catch (err) {
      debugPrint('[RewampDb] refreshSongSource error: $err');
      return null;
    }
  }

  /// [force] = « Re-télécharger »: aucun repli sur ce qui est déjà sur disque,
  /// et l'archive est demandée avec un cache-buster (l'edge CDN sert du
  /// `Cache-Control: immutable` — sans ça on re-télécharge fidèlement la copie
  /// périmée qu'on voulait remplacer).
  /// Vérifications qui n'ont RIEN à faire sur le chemin critique d'une lecture:
  /// détecter un remplacement côté serveur et enregistrer l'url de provenance.
  /// Le fichier demandé est déjà sur le disque — le jouer ne dépend d'aucune
  /// des deux, et les attendre coûtait tout le délai d'un saut de piste.
  ///
  /// Le purge éventuel prend donc effet à la lecture SUIVANTE de ce morceau:
  /// une lecture périmée de plus, contre une base interrogée à chaque saut.
  static Future<void> _verifySourceInBackground(SearchResult r) async {
    try {
      if (r.songId.isEmpty ||
          r.downloadUrl == null || r.downloadUrl!.isEmpty) {
        return;
      }
      await _purgeIfSourceUrlChanged(r);
      await LocalDb.instance.setDownloadSourceUrl(r.songId, r.downloadUrl!);
    } catch (e) {
      debugPrint('[RewampDb] _verifySourceInBackground error: $e');
    }
  }

  static Future<String> downloadToLibrary(SearchResult rowIn,
      {bool force = false}) async {
    // L'OVERRIDE fait autorité: une ligne de bibliothèque peut porter encore
    // l'url de l'ORIGINE (voir _preferRecordedOverride). Corrigé AVANT toute
    // décision — sinon on part sur une archive et on efface le rendu.
    final r = await _preferRecordedOverride(rowIn);
    // ── CHEMIN RAPIDE ────────────────────────────────────────────────────────
    // La ligne nomme elle-même un fichier, et ce fichier est ici: il n'y a rien
    // à résoudre ni à télécharger. Tout ce qui restait — la détection d'un
    // remplacement serveur et l'enregistrement de l'url — est de la
    // COMPTABILITÉ, pas une condition pour jouer, et part en arrière-plan.
    //
    // Mesuré sur macOS: un saut de piste passait 650-1800 ms ici, avec le
    // fichier déjà sur disque et le décodeur qui, lui, s'ouvre en 3 ms. Le
    // temps n'était pas dans la requête (clé primaire, 1-2 ms) mais dans
    // l'ATTENTE de la file sqflite — un `SELECT 1` mettait 1782 ms au même
    // instant, boucle d'événements libre. Une lecture qui n'a rien à demander
    // à la base ne doit pas faire la queue derrière ce qui la sature.
    if (!force && r.localPath != null && await File(r.localPath!).exists()) {
      // Même sortie que le `run()` qu'on court-circuite: TOUT chemin range la
      // bannière, y compris celui qui ne télécharge rien. Sans ça un « en
      // cours de téléchargement » laissé par un fetch précédent survivrait à
      // la lecture suivante.
      _statusClear();
      unawaited(_verifySourceInBackground(r));
      return r.localPath!;
    }
    // EVERY path runs the impl through this wrapper, so the "downloading…" status
    // is always cleared (success) or turned into an error (failure) — never left
    // stuck showing progress. Even the already-on-disk fast return goes through
    // it: the impl may fetch missing aux siblings, which sets the status.
    Future<String> run() => BackgroundTask.guard(() async {
          try {
            final path = await _downloadToLibraryImpl(r, force: force);
            _statusClear();
            // Remember the url this song was fetched from, so a later
            // server-side replacement (same song_id, new url) is detected.
            if (r.songId.isNotEmpty &&
                r.downloadUrl != null && r.downloadUrl!.isNotEmpty) {
              await LocalDb.instance
                  .setDownloadSourceUrl(r.songId, r.downloadUrl!);
            }
            return path;
          } on DownloadCancelledException {
            // The user aborted: no error banner, no report — just idle.
            _statusClear();
            rethrow;
          } on FormatUnsupportedException {
            // Not a download failure — the play path shows the explicit
            // "unsupported format" message + reports it. Don't flash the
            // misleading "download failed" banner.
            _statusClear();
            rethrow;
          } catch (e) {
            _statusFail(r.displayTitle, e);
            rethrow;
          }
        });

    // Server-side file replacement: same song_id, NEW download_url. Purge the
    // stale local copy so the cache-hit path below re-downloads. Only when the
    // row carries a url to compare (album-zip rows carry none → skipped).
    if (r.songId.isNotEmpty &&
        r.downloadUrl != null && r.downloadUrl!.isNotEmpty) {
      await _purgeIfSourceUrlChanged(r);
    }

    // Already on disk → run() (fast return inside the impl), still wrapped.
    // force saute ce court-circuit: c'est justement la copie locale qu'on
    // veut remplacer (l'impl ignore aussi ses propres replis).
    final lp = r.localPath ?? await _localPath(r);
    if (!force && await File(lp).exists()) return run();

    // Not local: coalesce with any in-flight download of the SAME source. Every
    // subsong row of one archive album shares its .7z downloadUrl, so a
    // background prefetch (or a fast second tap) and the on-demand play reuse
    // ONE download+extraction instead of racing on the same target dir. After
    // the shared fetch, run() resolves THIS row's own file (fast return).
    final key = (r.downloadUrl != null && r.downloadUrl!.isNotEmpty)
        ? r.downloadUrl!
        : lp;
    final inflight = _inFlightDownloads[key];
    if (!force && inflight != null) {
      try { await inflight; } catch (_) {}
      return run();
    }
    // NB block body, NOT `=> _inFlightDownloads.remove(key)`: Map.remove returns
    // the stored value (this very Future), and whenComplete AWAITS any Future its
    // callback returns → the Future would wait on itself and never complete (the
    // download WORK finishes — file on disk, 2nd play works — but the first
    // caller hangs forever on "downloading…"). The block discards the value.
    final fut = run().whenComplete(() {
      _inFlightDownloads.remove(key);
    });
    _inFlightDownloads[key] = fut;
    return fut;
  }

  static Future<String> _downloadToLibraryImpl(SearchResult r,
      {bool force = false}) async {
    // Row synthesized from an already-extracted file (PSF album expansion):
    // play it in place. Deriving the path from artist/format/album instead
    // would miss the extraction layout and re-download the whole archive.
    // force = « Re-télécharger »: tous les replis sur l'existant sont sautés
    // (localPath, chemin dérivé, chemin connu en DB) — sinon le geste est un
    // no-op, c'est CE fichier qu'on remplace.
    if (!force && r.localPath != null && await File(r.localPath!).exists()) {
      return r.localPath!;
    }

    final localPath = await _localPath(r);
    final file = File(localPath);

    if (!force && await file.exists()) {
      // Main file cached, but auxiliary siblings may be missing (e.g. an earlier
      // download before aux_files shipped). Ensure them before returning.
      await _ensureAuxFiles(r, localPath);
      return localPath;
    }

    // The path above is DERIVED from server fields — collection, artist,
    // platform-or-format, album, filename — and those move. Replacing an
    // unplayable scene.org module with an mp3 override cleared `format_ext` on
    // the row, so the "zip" directory level vanished from the computed path and
    // a file that was sitting on disk became invisible: the same track
    // re-downloaded on every single play. The DB knows where the bytes actually
    // landed, keyed by the one thing that does NOT move — the song id.
    // Checked AFTER the purge in downloadToLibrary(), so a genuine server-side
    // replacement still wins: it deletes the file first, and this misses too.
    if (!force && r.songId.isNotEmpty) {
      final known = await LocalDb.instance.getTrackByOnlineId(r.songId);
      final knownPath = known?.filePath;
      if (knownPath != null &&
          knownPath.isNotEmpty &&
          knownPath != localPath &&
          await File(knownPath).exists()) {
        debugPrint('[RewampDb] ${r.songId}: reusing $knownPath '
            '(computed path moved to $localPath)');
        await _ensureAuxFiles(r, knownPath);
        return knownPath;
      }
    }

    if (r.downloadUrl != null) {
      // Detect when downloadUrl is an archive (.7z / .zip / ...) but filename
      // is an audio file — common for joshw-style collections that wrap one
      // NSF/GBS/AY inside a 7z with an accompanying M3U.
      final urlExt = p.extension(r.downloadUrl!).replaceFirst('.', '').toLowerCase();
      const archiveExts = {'7z', 'zip', 'rar', 'gz', 'tar', 'lha', 'lzh', 'xz'};
      // Wrapped-audio archive: the URL is an archive AND the row's format is
      // either a real audio ext (joshw: nsf-in-7z) or unknown/an archive ext
      // itself (sceneorg rows ship format_ext=null with a .zip filename —
      // the module lives inside; playing the raw .zip fails and the queue
      // auto-skips).
      final fmtLower = r.formatExt.toLowerCase();
      if (archiveExts.contains(urlExt) &&
          (urlExt != fmtLower || archiveExts.contains(fmtLower))) {
        // Download the archive, extract into the audio dir, return audio path.
        return _downloadAndExtractSingle(r, localPath, force: force);
      }

      var bytes = await _fetchBytesMirror(
          force ? null : r.mirrorUrl,
          force ? cacheBusted(r.downloadUrl!) : r.downloadUrl!,
          label: r.displayTitle);
      // Soft 404: some origins answer a gone file with 200 + an HTML error page
      // (scene.org does). Writing that as the "audio" would fail to decode and
      // mis-report as an unsupported format — treat it as gone instead.
      if (_looksLikeHtml(bytes)) {
        throw DownloadHttpException(404, r.downloadUrl!);
      }
      // AMP (amp.dascene.net) serves each module gzip-wrapped through a php
      // endpoint: magic 1f 8b, no .gz anywhere in URL or filename. Saved raw,
      // no decoder can probe it. Unwrap transparently — unless the row's own
      // format IS a gzip container played compressed natively (.vgz/.gz VGM).
      final extLower =
          p.extension(localPath).replaceFirst('.', '').toLowerCase();
      const gzipNativeExts = {'gz', 'vgz', 'tgz'};
      if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b &&
          !gzipNativeExts.contains(extLower)) {
        try {
          bytes = Uint8List.fromList(gzip.decode(bytes));
        } catch (_) {
          // Not actually gzip (or corrupt) — keep the raw bytes.
        }
      }
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      // Download auxiliary siblings into the same dir before the file is played.
      await _ensureAuxFiles(r, localPath);
      return localPath;
    }

    // No direct URL — track lives inside an album archive (e.g. SID in zip).
    if (r.album == null) {
      throw Exception('No download URL and no album for ${r.filename}');
    }
    debugPrint('[album] branch for ${r.songId} "${r.displayTitle}" '
        '(album "${r.album}" / ${r.collection}, albumId=${r.albumId})');
    final col     = r.collection.isNotEmpty ? r.collection : null;
    final details = await fetchAlbumDetails(r.album!, collectionSlug: col);
    final zipUrl  = details.isNotEmpty ? details.first.zipUrl : null;
    final mirrorZip =
        details.isNotEmpty ? details.first.mirrorZipUrl : null;
    if (zipUrl == null) {
      throw Exception('No zip URL for album ${r.album}');
    }
    final songs = await browse(
      albumName:  r.album,
      collection: col,
      sortBy:     'position',
      limit:      500,
    );
    final firstTrack = songs.isEmpty ? r : songs.first;
    await downloadAndExtractZip(zipUrl, songs.isEmpty ? [r] : songs,
        mirrorZipUrl: mirrorZip, force: force);

    // RSN albums (snesmusic .rsn = RAR of SPC files) are NOT unpacked into
    // individual .spc files — the whole .rsn plays in place, each track a
    // subsong (see _handleRsnDownload). So the per-track localPath (…/kryk-18
    // .spc) never exists; return the .rsn, which the caller plays with the
    // track's subsong index. rsnLocalPath MUST be derived from the SAME track
    // downloadAndExtractZip keys on (songs.first) — a playlist row's own
    // metadata (artist order / null platform) can differ from the album's
    // canonical first track, yielding a different path that "doesn't exist"
    // and wrongly threw "File not found" / flashed "Téléchargement impossible"
    // on the next queue entry.
    final rsnPath = await rsnLocalPath(firstTrack);
    if (await File(rsnPath).exists()) {
      return rsnPath;
    }

    if (!await file.exists()) {
      throw Exception('File not found after zip extraction: $localPath');
    }
    return localPath;
  }

  /// Downloads any auxiliary sibling files ([r.auxFiles]) into the directory of
  /// [mainPath], so multifile formats (UADE TFMX mdat./smpl., sampled songs)
  /// find their companions next to the main file. Files already present (and
  /// non-empty) are skipped, so this is cheap to call on a cache hit. Each aux
  /// file is written under its basename in the main file's directory.
  static Future<void> _ensureAuxFiles(SearchResult r, String mainPath) async {
    if (r.auxFiles.isEmpty) return;
    final dir = p.dirname(mainPath);
    await Directory(dir).create(recursive: true);
    for (final aux in r.auxFiles) {
      // ⚠️ Le SOUS-DOSSIER d'un compagnon fait partie de son identité — on ne
      // peut pas l'aplatir. Voir [auxRelativePath].
      final name = auxRelativePath(aux.filename);
      if (name.isEmpty) continue;
      final f = File(p.join(dir, name));
      if (await f.exists() && await f.length() > 0) continue;
      // Le dossier n'existe pas forcément (« Instruments/ »).
      final auxDir = p.dirname(f.path);
      if (auxDir != dir) await Directory(auxDir).create(recursive: true);
      if (aux.downloadUrl == null) {
        throw Exception('aux file "$name" has no download_url (for ${r.filename})');
      }
      // Miroir puis origine, comme le morceau lui-même (voir AuxFile.mirrorUrl).
      final bytes = await _fetchBytesMirror(aux.mirrorUrl, aux.downloadUrl!,
          label: '$name (annexe)');
      await f.writeAsBytes(bytes, flush: true);
    }
  }

  /// Downloads [r.downloadUrl] (an archive: .7z/.zip/…) and extracts it via
  /// libarchive into the audio dir.  Returns the path to the actual extracted
  /// audio file — which often differs from [r.filename] (joshw archives use
  /// long descriptive names inside, but the DB stores a short album name).
  /// Sérialise téléchargement + extraction PAR DOSSIER album. Les pistes d'un
  /// même album partagent l'archive et son `_tmp_archive` — lancées en
  /// parallèle (lecture + prefetch de la queue) elles se marchaient dessus:
  /// « open failed » (tmp supprimé sous le lecteur), « Damaged 7-Zip archive »
  /// (lu pendant l'écriture), et 233 Mo re-téléchargés PAR PISTE. Une fois la
  /// première passée, les suivantes retombent sur l'exact-hit sans réseau.
  static final Map<String, Future<void>> _dirLocks = {};
  static Future<T> _withDirLock<T>(String dir, Future<T> Function() body) async {
    final key = p.normalize(dir);
    final prev = _dirLocks[key] ?? Future<void>.value();
    final gate = Completer<void>();
    _dirLocks[key] = gate.future;
    await prev;
    try {
      return await body();
    } finally {
      gate.complete();
      if (identical(_dirLocks[key], gate.future)) _dirLocks.remove(key);
    }
  }

  /// Point d'entrée de test pour [_findByStem] — la règle vaut d'être figée
  /// (elle décide quel fichier une ligne joue), et la fonction est privée.
  @visibleForTesting
  static Future<String?> debugFindByStem(String dir, String filename) =>
      _findByStem(dir, filename);

  /// Point d'entrée de test pour [_findExtractedAudio] — il décide quel fichier
  /// d'une archive est joué quand plusieurs conviennent, et l'ordre est une
  /// règle, pas un détail (voir [_formatTier]).
  @visibleForTesting
  static Future<String?> debugFindExtractedAudio(String dir,
          {String formatExt = ''}) async =>
      (await _findExtractedAudio(dir, formatExt))?.path;

  /// Le fichier de CETTE ligne sous [dir], reconnu par son RADICAL (nom sans
  /// extension) quand l'extension du catalogue ne correspond pas à celle de
  /// l'archive — vu sur jw_psf: la tracklist dit « Audio Track 01.wav », le 7z
  /// contient « Audio Track 01.ogg ».
  ///
  /// Deux garde-fous, sans quoi ce serait le pick générique qu'on vient
  /// d'éviter: la correspondance doit être UNIQUE (deux fichiers du même
  /// radical = archive ambiguë, on préfère échouer franc) et l'extension
  /// trouvée doit être jouable — sinon on servirait un `.txt` ou une pochette
  /// au moindre nom partagé.
  /// Does [dir] already hold a file one of our engines could play? Used to tell
  /// "the download was stale" (nothing usable came out) from "the catalogue and
  /// the archive disagree on a name" (plenty came out) — only the first is
  /// worth fetching again.
  static Future<bool> _dirHoldsPlayableFile(String dir) async {
    try {
      await for (final e in Directory(dir).list(recursive: true)) {
        if (e is! File) continue;
        final base = p.basename(e.path);
        if (base.startsWith('artwork.') || base.startsWith('_tmp_archive')) {
          continue;
        }
        if (isInCompanionDir(p.relative(e.path, from: dir))) continue;
        final ext = p.extension(base).replaceFirst('.', '').toLowerCase();
        if (ext.isNotEmpty && kExtractedAudioExts.contains(ext)) return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<String?> _findByStem(String dir, String filename) async {
    final want = p.basenameWithoutExtension(filename).toLowerCase();
    if (want.isEmpty) return null;
    final hits = <String>[];
    try {
      await for (final e in Directory(dir).list(recursive: true)) {
        if (e is! File) continue;
        final base = p.basename(e.path);
        if (base.startsWith('artwork.') || base.startsWith('_tmp_archive')) {
          continue;
        }
        if (isInCompanionDir(p.relative(e.path, from: dir))) continue;
        if (p.basenameWithoutExtension(base).toLowerCase() != want) continue;
        final ext = p.extension(base).replaceFirst('.', '').toLowerCase();
        // Même liste blanche que le scan générique: sans elle, un `.txt` ou
        // une pochette au nom de la piste passerait pour le morceau.
        if (ext.isEmpty || !kExtractedAudioExts.contains(ext)) continue;
        hits.add(e.path);
      }
    } catch (_) {
      return null;
    }
    if (hits.isEmpty) return null;
    if (hits.length == 1) return hits.first;

    // Plusieurs copies du MÊME nom, dans des dossiers différents (le rip
    // « Disgaea » range les mêmes SNDPAK_* sous `jp/` et sous `usa/`). Abandonner
    // était pire que choisir: l'appelant retombait sur le scan générique, qui
    // sert le plus gros fichier d'allure audio — donc une AUTRE piste. Le nom
    // demandé, lui, est le bon; on prend la copie la moins enfouie, à ordre
    // stable, et on dit lequel.
    hits.sort((a, b) {
      final byDepth = p.split(a).length.compareTo(p.split(b).length);
      return byDepth != 0 ? byDepth : a.compareTo(b);
    });
    debugPrint('[extract] radical « ${p.basenameWithoutExtension(filename)} » '
        'présent ${hits.length}× → ${hits.first}');
    return hits.first;
  }

  static Future<String> _downloadAndExtractSingle(
      SearchResult r, String audioFilePath, {bool force = false}) async {
    // Extraction root = the ALBUM directory (collection/artist/platform/album),
    // NOT dirname(audioFilePath): when the row's filename carries an archive
    // sub-folder ("Enlightenment/han.Druid_music"), dirname(localPath) is one
    // level too deep — the archive (with its own wrapper folder) then extracted
    // into album/<sub>/, every other row's localPath stopped matching, and the
    // fallback below picked an arbitrary "audio-looking" file (UnExotica's
    // smp.* sample bank went to vgmstream). For a plain filename dirname ==
    // album dir, so this changes nothing for the usual joshw archives.
    final audioDir = await artworkDirForResult(r);
    await Directory(audioDir).create(recursive: true);

    // Exact hit first: the row names its own file inside the archive — if that
    // precise path exists, never let the generic scan choose for us. force
    // saute TOUS les replis sur l'existant (c'est ce contenu qu'on remplace).
    final exact =
        File(p.joinAll([audioDir, ..._fileSegments(r.filename)]));
    if (!force && await exact.exists()) return exact.path;

    // Salvage: same basename anywhere under the album dir. Heals layouts left
    // by the earlier misplaced extractions (album/<sub>/<wrapper>/…) without a
    // re-download, and still targets the row's OWN file — unlike the generic
    // scan below, which happily returns a sample bank.
    final wantBase = p.basename(r.filename).toLowerCase();
    if (!force && wantBase.isNotEmpty && wantBase != '.') {
      try {
        await for (final e in Directory(audioDir).list(recursive: true)) {
          if (e is File && p.basename(e.path).toLowerCase() == wantBase) {
            return e.path;
          }
        }
      } catch (_) {}
    }

    // Même RADICAL, autre extension. Le catalogue et l'archive peuvent ne pas
    // s'accorder sur l'extension d'une même piste: jw_psf « Hexen — Beyond
    // Heretic » annonce « Audio Track 01.wav » là où le 7z contient
    // « Audio Track 01.ogg ». Sans cette passe, l'exact-hit manquait pour
    // TOUTES les pistes et chacune repartait en téléchargement — deux fois,
    // le miss déclenchant en plus la reprise cache-bustée — pour finir sur un
    // pick générique qui servait la piste 01 à tout l'album.
    //
    // C'est le nom de la piste qui identifie, pas son extension: on cible
    // toujours le fichier de CETTE ligne, et seulement s'il est le SEUL de ce
    // radical (sinon l'archive est ambiguë et il vaut mieux échouer franc).
    final stemMatch = force ? null : await _findByStem(audioDir, r.filename);
    if (stemMatch != null) return stemMatch;

    // Legacy layout: before archives got a directory of their own, everything
    // extracted straight into the parent, where several unrelated archives
    // piled up. Claim OUR file there — matched on the archive's own stem
    // ("dt_dope.zip" → "DT_DOPE.XM", case-insensitively), which is precise
    // enough not to steal a neighbour's — so an existing install keeps playing
    // without re-downloading.
    final stem = _archiveStem(r);
    // Only when this row actually got a directory of its own (see
    // _dirSegments): for an album row the parent is the shared album dir, where
    // a same-stem file would belong to a sibling.
    if (!force && stem != null && p.basename(audioDir) == stem) {
      final parent = p.dirname(audioDir);
      try {
        await for (final e in Directory(parent).list()) {
          if (e is! File) continue;
          final base = p.basename(e.path);
          if (base.startsWith('_tmp_archive') || base.startsWith('artwork.')) {
            continue;
          }
          if (p.basenameWithoutExtension(base).toLowerCase() ==
              stem.toLowerCase()) {
            return e.path;
          }
        }
      } catch (_) {/* parent may not exist — nothing to salvage */}
    }

    // Cache: reuse an already-extracted audio file — but only if it's the SOLE
    // file of this format here. For a multi-file album whose exact track was
    // deleted (exact + salvage both missed above), a surviving sibling must NOT
    // be substituted; uniqueOnly ⇒ null ⇒ fall through and re-extract the real
    // one from the archive.
    final cached = force
        ? null
        : await _findExtractedAudio(audioDir, r.formatExt, uniqueOnly: true);
    if (cached != null) {
      debugPrint('[extract] ${r.displayTitle}: cache hit ${cached.path} '
          '(exact wanted: ${exact.path})');
      return cached.path;
    }

    // Téléchargement + extraction sous le VERROU du dossier (voir _withDirLock):
    // les autres pistes du même album attendent, puis retrouvent leur fichier
    // par l'exact-hit sans réseau.
    return _withDirLock(audioDir, () async {
      // Un concurrent vient peut-être de tout extraire pendant l'attente.
      if (!force && await exact.exists()) return exact.path;

      Future<void> fetchAndExtract({required bool bustCache}) async {
        // Cache-buster: le CDN peut servir une copie EDGE périmée d'une
        // archive remplacée sous la même url (vécu: l'ancien rip de
        // "Frequency" revenait avec des mtimes 2024 pendant que curl recevait
        // la nouvelle). La query change la clé de cache → l'origine répond.
        // _fetchArchiveShared s'en charge (et purge son propre tampon).
        debugPrint('[extract] ${r.displayTitle}: fetching archive into '
            '$audioDir (want ${exact.path}${bustCache ? ", cache-busted" : ""})');
        final (archHead, sharedPath) = await _fetchArchiveShared(
            r.mirrorUrl, r.downloadUrl!,
            label: '${r.displayTitle} (archive)',
            expectedSize: r.fileSize,
            bustCache: bustCache);
        // Some origins answer a bot check with HTTP 200 + an HTML interstitial
        // ("Verifying your browser…") instead of the file — exotica.org.uk
        // does. Extraction then fails or yields nothing; name what happened.
        if (_looksLikeHtml(archHead)) {
          throw Exception(
              'Server returned an HTML page, not an archive (bot check / '
              'error page): ${r.downloadUrl}');
        }
        // La copie partagée EST déjà sur disque, et l'extraction lit un
        // chemin: aucune copie intermédiaire.
        // Extract via C libarchive (handles 7z, zip, lha, etc.) — off-thread.
        final (rc, err) = await _extractArchiveOffThread(sharedPath, audioDir);
        if (rc != 0) {
          throw Exception(
              'Archive extraction failed (rc=$rc): $err — ${r.downloadUrl}');
        }
      }

      await fetchAndExtract(bustCache: force);

      // Exact hit first here too (post-extraction): the freshly unpacked
      // archive should contain the row's own file at its relative path. A
      // MISS after a clean extraction = the bytes were not the advertised
      // archive (stale CDN edge) → ONE cache-busted retry.
      // Le radical d'abord: une extraction propre dont seul le SUFFIXE diffère
      // n'est pas un CDN périmé, c'est un désaccord de nommage entre le
      // catalogue et l'archive. Confondre les deux coûtait un second
      // téléchargement complet ET un effacement du dossier — donc aussi les
      // pistes des autres lignes, fraîchement extraites, ce qui interdisait à
      // la suivante d'en profiter: l'album ne convergeait jamais.
      if (!await exact.exists()) {
        final byStem = await _findByStem(audioDir, r.filename);
        if (byStem != null) {
          debugPrint('[extract] ${r.displayTitle}: exact MISS mais radical '
              'trouvé → $byStem');
          return byStem;
        }
      }
      // Un miss de NOM n'est pas un miss de CONTENU — même règle que le miss
      // d'extension juste au-dessus, et le cas est plus large qu'il n'y paraît:
      // le tracklist de jw_psf2 « Disgaea » nomme une piste `SNDPAK_0000000F`
      // sans son dossier alors que l'archive la range sous `jp/` ET `usa/`,
      // deux copies qui rendent le radical ambigu. L'extraction a pourtant
      // parfaitement réussi. Re-télécharger là (200 Mo, à CHAQUE lecture et à
      // chaque préchargement) et effacer le dossier au passage ne répare rien:
      // la seconde extraction produit exactement les mêmes fichiers.
      final extractedSomething = await _dirHoldsPlayableFile(audioDir);
      if (!await exact.exists() && extractedSomething) {
        debugPrint('[extract] ${r.displayTitle}: exact MISS '
            '(${exact.path}) mais le dossier contient déjà des fichiers '
            'jouables — pas de re-téléchargement (désaccord de nommage)');
      } else if (!await exact.exists()) {
        debugPrint('[extract] ${r.displayTitle}: rc=0 but exact MISS '
            '(${exact.path}) — retrying with a cache-buster');
        // Ce que le 1er essai a extrait vient d'octets PÉRIMÉS (l'ancienne
        // archive servie par l'edge): résidu à effacer avant la
        // ré-extraction, sinon le vieux rip reste posé à côté du nouveau
        // contenu (artwork conservé).
        try {
          await for (final e in Directory(audioDir).list()) {
            final base = p.basename(e.path);
            if (base.startsWith('artwork.')) continue;
            try {
              await e.delete(recursive: true);
            } catch (_) {}
          }
        } catch (_) {}
        await fetchAndExtract(bustCache: true);
      }
      if (await exact.exists()) return exact.path;
      final byStem2 = await _findByStem(audioDir, r.filename);
      if (byStem2 != null) return byStem2;

      // La ligne nomme PRÉCISÉMENT son fichier dans l'archive (chemin relatif
      // du tracklist serveur): un pick générique à sa place est un mensonge —
      // il a servi un .mmv du vieux rip comme « The Winner.mp3 », loadFile a
      // échoué et le morceau s'est fait signaler no_playback. Échouer franc.
      if (r.filename.contains('/')) {
        throw Exception(
            'Extraction produced nothing at the advertised path '
            '(${r.filename}) — archive/tracklist mismatch: ${r.downloadUrl}');
      }
      // Même règle, TROISIÈME forme, et c'est la plus fréquente: une ligne
      // NÉE d'une tracklist serveur (`subsongRowsFromServer`) nomme l'entrée
      // exacte de l'archive — `resolvedSubsong` + une position, et un compte
      // de sous-chansons NUL parce qu'elle a un fichier à elle. Si ce fichier
      // n'est pas sorti de l'archive, il n'y est pas: certains rips listent
      // des pistes qu'ils ne distribuent pas (« Atelier Annie », six `.mp3`
      // annoncés, zéro dans le `.7z`). Le pick générique servait alors le
      // `.2sflib` du driver aux trois premières lignes — même son pour les
      // trois, et un chemin écrit qui les faisait passer pour téléchargées.
      if (r.resolvedSubsong &&
          r.trackPosition != null &&
          r.subsongCount == null) {
        throw ArchiveEntryMissingException(
          filename: r.filename,
          url: r.downloadUrl ?? '',
          songId: r.songId.split('#').first,
          subsongIndex: r.subsongIdx,
        );
      }
      // Même règle, autre forme: une ligne CONTENEUR porte la liste EXACTE des
      // fichiers de l'archive (`subsongs`), donc son `filename` est le nom de
      // l'ALBUM et ne désigne aucun fichier — « Final Fantasy V.spc » n'existe
      // pas dans le 7z de jw_spc. Le pick générique servait alors une piste au
      // hasard (« 124 Nostalgia.spc » rendu comme « Harvest ») et la PERSISTAIT
      // dans `tracks` puis dans l'entrée de playlist qui en naissait: la
      // playlist jouait définitivement le mauvais morceau. Un conteneur se
      // déplie (expandContainerAlbum), il ne se devine pas.
      if (r.subsongs.isNotEmpty) {
        throw Exception(
            'Container row "${r.filename}" names no file of its own '
            '(${r.subsongs.length} listed) — expand it instead of guessing: '
            '${r.downloadUrl}');
      }
      debugPrint('[extract] ${r.displayTitle}: exact MISS '
          '(${exact.path}) — falling back to generic scan');

      final found = await _findExtractedAudio(audioDir, r.formatExt,
          preferStem: stem);
    if (found != null) {
      debugPrint('[extract] ${r.displayTitle}: generic scan picked '
          '${found.path}');
    }
    if (found == null) {
      // The archive unpacked fine — it simply holds no format any of our engines
      // claims. That is a real case, not a broken download: UnExotica carries
      // plenty of one-off Amiga customs (Enlightenment.lha = "han.Druid_music",
      // an IFF FORM/AkDTRK that no bundled engine, UADE included, recognises).
      // Name what came out so it reads as "unsupported", not "download failed".
      final entries = <(String rel, int size)>[];
      try {
        await for (final e in Directory(audioDir).list(recursive: true)) {
          if (e is! File) continue;
          if (p.basename(e.path).startsWith('_tmp_archive')) continue;
          var size = 0;
          try { size = await e.length(); } catch (_) {}
          entries.add((p.relative(e.path, from: audioDir), size));
        }
      } catch (_) {}
      // The MAIN candidate is what to name — never a companion. Skip obvious
      // accompaniment (readme .txt, FILE_ID.DIZ, .nfo, cover images…) and pick
      // the LARGEST remaining file (the module is almost always the biggest).
      // If EVERYTHING is junk, name the archive itself — NEVER a .diz/.txt.
      const junkExts = {
        'txt', 'diz', 'nfo', 'md', 'readme', 'url', 'ini', 'cfg', 'log',
        'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'pdf', 'doc',
      };
      final pick = (entries
              .where((e) => !junkExts.contains(
                  p.extension(e.$1).replaceFirst('.', '').toLowerCase()))
              .toList()
            ..sort((a, b) => b.$2.compareTo(a.$2)))
          .map((e) => e.$1)
          .firstOrNull;
      final archiveExt =
          p.extension(r.filename).replaceFirst('.', '').toLowerCase();
      String fname = p.basename(r.filename);
      String ext = r.formatExt.isNotEmpty ? r.formatExt : archiveExt;
      if (pick != null) {
        fname = p.basename(pick);
        final innerExt = p.extension(pick).replaceFirst('.', '');
        if (innerExt.isNotEmpty) ext = innerExt;
      }
      final names = entries.take(6).map((e) => e.$1).toList();
      throw FormatUnsupportedException(
        filename: fname,
        ext: ext,
        songId: r.songId.isNotEmpty ? r.songId : null,
        subsongIndex: r.subsongIdx,
        detail: 'archive holds no supported format '
            '(${names.isEmpty ? "empty" : names.join(", ")})',
        triedUrl: r.downloadUrl,
      );
    }
    return found.path;
    });
  }

  /// Scans [dir] for an extracted audio file.  Prefers one matching [formatExt];
  /// else returns the first file with any container/audio format.  Null if none.
  /// Every extension vgmstream claims (src/formats.c extension_list, minus
  /// numeric-only / single-char / non-audio generic names). vgmstream is the
  /// last-resort plugin (probes by content); listing these lets archive
  /// extraction + the file picker recognise its 700+ game-audio formats.
  static const kVgmstreamExts = {
    '2dx', '2dx9', '3do', '3ds', '9tav', 'a3c', 'aa3', 'aac', 'aaf', 'aax', 'abc', 'abk',
    'ac3', 'acb', 'acm', 'acx', 'ad', 'adc', 'adm', 'adm2', 'adp', 'adpcm', 'adpcmx', 'ads',
    'adw', 'adx', 'afc', 'afs2', 'agsc', 'ahv', 'ahx', 'ai', 'aif', 'aifc', 'aiff', 'aix',
    'akb', 'al', 'al2', 'amb', 'ams', 'amx', 'an2', 'ao', 'ap', 'apc', 'apm', 'as4',
    'asbin', 'asd', 'asf', 'asr', 'ast', 'at3', 'at9', 'atsl', 'atsl3', 'atsl4', 'atslx', 'atx',
    'aud', 'audio', 'audio_data', 'audiopkg', 'aus', 'awa', 'awb', 'awc', 'awd', 'awx', 'b1s', 'baa',
    'baf', 'baka', 'bank', 'bao', 'bar', 'bcstm', 'bcv', 'bcwav', 'bdm', 'bfstm', 'bfwav', 'bg00',
    'bgm', 'bgw', 'bigrp', 'bik', 'bika', 'binka', 'bk2', 'bkh', 'bkr', 'blk', 'bms', 'bnk',
    'bnm', 'bns', 'bnsf', 'bo2', 'brstm', 'brstmspm', 'brwav', 'brwsd', 'bsnd', 'btsnd', 'bvg', 'bwav',
    'bx', 'cads', 'caf', 'cat', 'cbd2', 'cbx', 'cd', 'cfn', 'chd', 'chk', 'ckb', 'ckd',
    'cks', 'cnk', 'cpk', 'cps', 'crd', 'csa', 'csb', 'csmp', 'cvs', 'cwav', 'cxb', 'cxk',
    'cxs', 'd2', 'da', 'dax', 'dbm', 'dcs', 'dct', 'ddsp', 'de2', 'dec', 'dic', 'diva',
    'dmsg', 'drm', 'ds2', 'dsb', 'dsf', 'dsp', 'dspw', 'dtk', 'dty', 'dvi', 'dyx', 'e4x',
    'eam', 'eas', 'eda', 'emff', 'enm', 'eno', 'ens', 'esf', 'exa', 'ezw', 'fag', 'fda',
    'filp', 'fish', 'flac', 'flx', 'fsb', 'fsv', 'fwav', 'fwse', 'g1l', 'gbts', 'gca', 'gcm',
    'gcub', 'gcw', 'ged', 'genh', 'gin', 'gmd', 'gms', 'grn', 'gsf', 'gsp', 'gtd', 'gwb',
    'gwm', 'h4m', 'hab', 'hbd', 'hca', 'hd', 'hd2', 'hd3', 'hdt', 'his', 'hps', 'hsf',
    'hvqm', 'hwas', 'hwb', 'hwd', 'hwx', 'hx2', 'hx3', 'hxc', 'hxd', 'hxg', 'hxx', 'iab',
    'iadp', 'iap', 'idmsf', 'idsp', 'idvi', 'idwav', 'idxma', 'ifs', 'ikm', 'ild', 'ilf', 'ilv',
    'ima', 'imc', 'imf', 'imx', 'int', 'is14', 'isb', 'isd', 'ish', 'isws', 'itl', 'ivag',
    'ivaud', 'ivb', 'ivs', 'ixa', 'joe', 'jstm', 'k2sb', 'ka1a', 'kat', 'kces', 'kcey', 'km9',
    'kma', 'kmx', 'kno', 'kns', 'koe', 'kovs', 'kraw', 'ktac', 'ktsl2asbin', 'ktss', 'kvs', 'kwa',
    'l00', 'laac', 'lac3', 'ladpcm', 'laif', 'laifc', 'laiff', 'lasf', 'lbin', 'ldat', 'ldt', 'lep',
    'lflac', 'lin', 'lm0', 'lm1', 'lm2', 'lm3', 'lm4', 'lm5', 'lm6', 'lm7', 'lmp2', 'lmp3',
    'lmp4', 'lmpc', 'logg', 'lopus', 'lp', 'lpcm', 'lpk', 'lps', 'lrmh', 'lse', 'lsf', 'lstm',
    'lwav', 'lwd', 'lwma', 'm4a', 'm4v', 'mab', 'mad', 'mc3', 'mca', 'mcadpcm', 'mcg', 'mds',
    'mdsp', 'med', 'mhk', 'mi4', 'mib', 'mic', 'mio', 'mjh', 'mogg', 'mon', 'mov', 'move',
    'mp2', 'mp3', 'mp4', 'mpc', 'mpds', 'mpdsp', 'mpf', 'mps', 'ms', 'msa', 'msb', 'msd',
    'mse', 'msf', 'msh', 'mss', 'msv', 'msvp', 'msx', 'mta', 'mta2', 'mtaf', 'mtt', 'mul',
    'mups', 'mus', 'musc', 'musx', 'mvb', 'mwa', 'mwv', 'mxst', 'myspd', 'n64', 'naac', 'ndp',
    'nds', 'nfx', 'nlsd', 'no', 'nop', 'nps', 'npsf', 'nsa', 'nsopus', 'nub', 'nub2', 'nus3audio',
    'nus3bank', 'nusnub', 'nwa', 'nwav', 'nxa', 'nxms', 'nxopus', 'nxse', 'oga', 'ogg', 'ogg_', 'ogl',
    'ogs', 'ogv', 'oma', 'omu', 'oor', 'opu', 'opus', 'opusnx', 'opusx', 'oto', 'ovb', 'owp',
    'p04', 'p08', 'p16', 'p1d', 'p2a', 'p2bt', 'p3d', 'paf', 'past', 'patch3audio', 'pcm', 'pdt',
    'phd', 'pk', 'pona', 'ps3', 'psb', 'psf', 'psh', 'psn', 'pth', 'pwb', 'qwv', 'rac',
    'rad', 'rak', 'ras', 'rda', 'res', 'rkv', 'rof', 'rpgmvo', 'rrds', 'rsd', 'rsf', 'rsm',
    'rsnd', 'rsoundast', 'rsoundsnd', 'rsp', 'rstm', 'rvw', 'rvws', 'rwar', 'rwav', 'rws', 'rwsd', 'rwx',
    'rxx', 's14', 's3s', 's3v', 'sab', 'sad', 'saf', 'sag', 'sam', 'sap', 'sb0', 'sb1',
    'sb2', 'sb3', 'sb4', 'sb5', 'sb6', 'sb7', 'sbin', 'sbk', 'sbr', 'sbv', 'sc', 'scd',
    'sch', 'sd9', 'sdd', 'sdf', 'sdl', 'sdp', 'sdt', 'sdx', 'se', 'se3', 'seb', 'sed',
    'seg', 'sem', 'sf0', 'sfa', 'sfl', 'sfs', 'sfx', 'sgb', 'sgd', 'sgt', 'shaa', 'shsa',
    'sig', 'skx', 'slb', 'sli', 'sm0', 'sm1', 'sm2', 'sm3', 'sm4', 'sm5', 'sm6', 'sm7',
    'smh', 'smk', 'smp', 'smv', 'sn0', 'snb', 'snd', 'snds', 'sng', 'sngw', 'snr', 'sns',
    'snu', 'snz', 'sod', 'son', 'sounds', 'spc', 'sph', 'spk', 'spm', 'sps', 'spsd', 'spsis14',
    'spsis22', 'spt', 'spw', 'srcd', 'sre', 'srsa', 'ss2', 'ssd', 'ssf', 'ssm', 'ssp', 'sspr',
    'sss', 'ster', 'sth', 'stm', 'str', 'stream', 'strm', 'sts', 'sts_cp3', 'stv', 'stx', 'svag',
    'svg', 'svs', 'swag', 'swar', 'swav', 'swd', 'switch', 'switch_audio', 'sx', 'sxd', 'sxd2', 'sxd3',
    'szd', 'szd1', 'szd3', 'tad', 'tgq', 'tgv', 'thp', 'tmx', 'tra', 'trk', 'trs', 'tsdse3',
    'tsdse4', 'tun', 'txth', 'txtp', 'u0', 'ue4opus', 'ueba', 'ueopus', 'ulw', 'um3', 'usm', 'utk',
    'uv', 'v0', 'v1', 'va3', 'vab', 'vag', 'vai', 'vam', 'vas', 'vb', 'vbk', 'vbx',
    'vca', 'vcb', 'vdm', 'vds', 'vgi', 'vgm', 'vgmstream', 'vgs', 'vgv', 'vh', 'vid', 'vig',
    'vis', 'vm4', 'vms', 'vmu', 'voi', 'vp6', 'vpk', 'vs', 'vsf', 'vsv', 'vxn', 'waa',
    'wac', 'wad', 'waf', 'wam', 'was', 'wav', 'wavc', 'wave', 'wavebatch', 'wavm', 'wavx', 'wax',
    'way', 'wb', 'wb2', 'wbd', 'wbk', 'wd', 'wem', 'wic', 'wiive', 'wip', 'wlv', 'wmw',
    'wp2', 'wpd', 'wsd', 'wsi', 'wst', 'wua', 'wv2', 'wv6', 'wvd', 'wve', 'wvp', 'wvs',
    'wvx', 'wxh', 'wxv', 'x360audio', 'xa', 'xa2', 'xa30', 'xag', 'xai', 'xau', 'xav', 'xb',
    'xbw', 'xen', 'xhd', 'xma', 'xma2', 'xmd', 'xms', 'xmu', 'xmv', 'xnb', 'xopus', 'xps',
    'xse', 'xsew', 'xsf', 'xsh', 'xss', 'xst', 'xvag', 'xwav', 'xwb', 'xwc', 'xwm', 'xwma',
    'xws', 'xwv', 'ydsp', 'ymf', 'zic', 'zsd', 'zsm', 'zss', 'zwv',
  };

  // Audio exts recognized inside a wrapped archive (scene.org zips carry the
  // module + junk like 'scene.org'/'file_id.diz' — whitelist, don't guess).
  // `final`, not `const`: kVgmstreamExts overlaps the explicit entries below
  // (ahx/wav/spc/…); a Set literal dedupes them at runtime, a const set can't.
  // Which extracted file is the playable audio. Composed from the canonical
  // decoder groups (lib/formats.dart) + vgmstream's full set + the container
  // list — the single source of truth, shared with home_screen._audioExtensions.
  static final kExtractedAudioExts = <String>{
    ...kContainerFormats,
    ...kVgmstreamExts,
    ...kAllDecoderExts,
  };

  /// True when [f] is, byte for byte, TEXT — which no bundled decoder's format
  /// is. Scene archives ship marker files whose "extension" collides with a
  /// real audio format (`scene.org` is a plain text stub, and `org` is
  /// Organya), so the extension whitelist called one music and handed it to the
  /// Organya decoder — "Invalid Org header '  ____'" — while the module next to
  /// it was never tried.
  ///
  /// Content, not a list of known names: the same stub travels in mirrors of
  /// those zips under other collections, and the next piece of junk will have a
  /// name nobody wrote down. Read in full (bounded), and any NUL or a real
  /// share of high/control bytes settles it as binary — which is what keeps a
  /// text-HEADED format like ASAP's `.sap` on the music side, since its payload
  /// is binary a few hundred bytes in.
  static Future<bool> _isTextStub(File f, int size) async {
    const maxStub = 64 * 1024;   // a stub is small; never read a real module
    if (size <= 0 || size > maxStub) return false;
    try {
      final bytes = await f.readAsBytes();
      var suspicious = 0;
      for (final b in bytes) {
        if (b == 0) return false;                      // NUL ⇒ binary, decided
        final ok = b == 9 || b == 10 || b == 13 || (b >= 32 && b < 127);
        if (!ok) suspicious++;                          // control or >= 0x80
      }
      return suspicious * 20 <= bytes.length;           // ≤ 5 % ⇒ text
    } catch (_) {
      return false;   // unreadable: treat as music rather than drop a track
    }
  }

  /// Un fichier SOURCE de tracker qu'AUCUN moteur ne joue — donc à écarter du
  /// classement, sinon il gagne et le vrai morceau n'est jamais essayé.
  ///
  /// Le cas mesuré: la release scene.org « eightbm_tomarkus_chipcompo » (compo
  /// Chip MSX de Xenium 2024) porte un `.prg` de 4 200 octets — un exécutable
  /// C64 que libsidplayfp joue très bien — et un `.sng` de 21 288 octets, qui
  /// est le SOURCE GoatTracker 2 du même morceau. Les deux sont au palier 1
  /// (`.prg` par [kSidExts], `.sng` par [kUadeExts]: c'est aussi l'extension du
  /// ZoundMonitor AMIGA), l'égalité se départage à la TAILLE DÉCROISSANTE, et
  /// c'est donc le source qui sortait — que rien ne sait jouer.
  ///
  /// ⚠️ **La seconde chance `rewamp_can_play` ne rattrape PAS ce cas**, et c'est
  /// la leçon générale: vgmstream réclame TOUTE extension qu'il ne connaît pas
  /// (score 50, `kSkipExts` mis à part), donc le registre répond « oui » pour
  /// presque n'importe quoi. Le veto par moteur trie les formats que quelqu'un
  /// REFUSE, pas ceux que le fourre-tout accepte sans savoir les décoder.
  ///
  /// D'où une règle NÉGATIVE, sur le CONTENU comme [_isTextStub]: un `.sng` qui
  /// commence par « GTS » est un morceau GoatTracker (C64, `GTS3`/`GTS4`/`GTS5`)
  /// et non un module Amiga. Aucun moteur embarqué ne lit GoatTracker; le nier
  /// coûte le morceau entier, l'écarter ne coûte rien.
  static Future<bool> _isTrackerSourceOnly(File f, String ext) async {
    if (ext != 'sng') return false;
    try {
      final h = await f.openRead(0, 3).expand((c) => c).toList();
      return h.length >= 3 && h[0] == 0x47 && h[1] == 0x54 && h[2] == 0x53;
    } catch (_) {
      return false;   // illisible: on ne retire pas une piste sur un doute
    }
  }

  /// [uniqueOnly]: return a format match ONLY when it is the SOLE audio file of
  /// that format in [dir]. A caller re-resolving ONE specific track of a
  /// multi-file album (whose exact file was deleted) must NOT be handed an
  /// arbitrary surviving sibling — that plays the wrong track; ambiguous ⇒ null
  /// so it re-extracts and restores the real file. A single-file archive still
  /// resolves (exactly one match).
  /// [preferStem]: the archive's own name. A zip named "dt_birth.zip" holding
  /// "dt_birth.xm" says which file is the music; nothing else in that archive
  /// does.
  static Future<File?> _findExtractedAudio(String dir, String formatExt,
      {bool uniqueOnly = false, String? preferStem}) async {
    final want = formatExt.toLowerCase();
    const archiveExts = {'7z', 'zip', 'rar', 'gz', 'tar', 'lha', 'lzh', 'xz'};
    final wantIsArchive = archiveExts.contains(want) || want.isEmpty;
    final candidates = <({File file, int size, bool stemHit, int tier})>[];
    File? fmtMatch; int fmtCount = 0;
    final stem = preferStem?.toLowerCase();
    try {
      // RECURSIVE: the native extractor preserves the archive's structure, and
      // plenty of archives wrap everything in one folder (UnExotica's .lha put
      // "Enlightenment/han.Druid_music" one level down). A flat scan found
      // nothing there and the caller reported the misleading "No audio file
      // found after extracting …".
      await for (final e in Directory(dir).list(recursive: true)) {
        if (e is! File) continue;
        final base = p.basename(e.path);
        if (base.startsWith('_tmp_archive')) continue;
        final ext = p.extension(e.path).replaceFirst('.', '').toLowerCase();
        // Amiga/modland PREFIX convention: many UADE formats are named
        // "<format>.<song>" (e.g. cust.FirstSamurai, mod.samurai v2), so the
        // format token is the PREFIX, not the suffix — p.extension returns the
        // song name. Match on the prefix token too.
        final prefix = base.contains('.') ? base.split('.').first.toLowerCase() : '';
        // When the row's own format is an archive/unknown, only the audio
        // whitelist decides (matching 'zip' would return the archive itself).
        if (!wantIsArchive && (ext == want || prefix == want)) {
          if (!uniqueOnly) return e;      // first format match wins
          fmtMatch = e; fmtCount++;       // …unless we must confirm it's unique
        }
        // Un dossier de compagnons ne contient pas de pistes — et ses
        // fichiers PORTENT des extensions jouables (`.ss` = SpeedySystem).
        // Sans ce filtre, un échantillon de 31 Ko bat le module de 6 Ko à la
        // TAILLE et le pick générique sert un instrument. Voir
        // [isInCompanionDir].
        if (isInCompanionDir(p.relative(e.path, from: dir))) continue;
        if (kExtractedAudioExts.contains(ext) ||
            (prefix.isNotEmpty && kExtractedAudioExts.contains(prefix))) {
          var size = 0;
          try { size = await e.length(); } catch (_) {}
          if (await _isTextStub(e, size)) continue;   // a readme, not a module
          // Un SOURCE de tracker que rien ne joue (voir _isTrackerSourceOnly).
          if (await _isTrackerSourceOnly(e, ext)) continue;
          candidates.add((
            file: e,
            size: size,
            stemHit: stem != null &&
                p.basenameWithoutExtension(base).toLowerCase() == stem,
            tier: _formatTier(ext, prefix),
          ));
        }
      }
    } catch (_) {}
    if (uniqueOnly) return fmtCount == 1 ? fmtMatch : null;  // ambiguous ⇒ re-extract
    if (candidates.isEmpty) return null;
    // RANKED, not first-found. Directory order means nothing, and a leftover
    // stub sorted before the module is exactly how a playable archive became
    // unplayable.
    //
    // L'ordre est: le NOM de l'archive d'abord (une pochette d'archive qui
    // s'appelle comme elle est ce qu'elle publie), puis la RICHESSE du format,
    // et la taille seulement pour départager. Une release scene.org embarque
    // couramment le même morceau plusieurs fois — le `.xm` d'origine ET son
    // rendu `.mp3` —, et la plus grosse est justement la moins intéressante:
    // le mp3 pèse dix fois le module et ne donne ni patterns, ni voies, ni
    // sous-chansons. Trier par taille servait donc systématiquement le rendu.
    candidates.sort((a, b) {
      if (a.stemHit != b.stemHit) return a.stemHit ? -1 : 1;
      if (a.tier != b.tier) return a.tier.compareTo(b.tier);
      if (a.size != b.size) return b.size.compareTo(a.size);
      return a.file.path.compareTo(b.file.path);   // stable
    });
    // « … si disponible ET NON REJETÉ AU CHARGEMENT »: le rang ne vaut rien si
    // le fichier préféré n'est réclamé par aucun greffon. `rewamp_can_play`
    // pose la question au REGISTRE (extension + en-tête, aucun décodage), donc
    // pour TOUS les moteurs.
    //
    // ⚠️ NE PAS utiliser `probeSubsongCount` ici, essayé et faux: c'est un
    // compteur de SOUS-CHANSONS chaîné sur SID/KSS/openmpt/SNDH/sc68/GME, qui
    // répond 0 pour tout le reste — Furnace, UADE, zxtune, AdPlug, la famille
    // PSF, SunVox, et les formats que seul libvgm joue. Sur « Progressive
    // Chiptunez » (sceneorg), il rejetait le `.fur` (palier 0) et validait le
    // `.vgm` (palier 1, que libgme sait ouvrir): le classement était juste, la
    // sonde le défaisait.
    //
    // Plafonné: une vérification touche le fichier, et une archive pathologique
    // en contient des centaines. Au-delà on garde le mieux classé — l'ancien
    // comportement, jamais pire.
    const maxProbes = 8;
    final probes = math.min(candidates.length, maxProbes);
    for (var i = 0; i < probes; i++) {
      var ok = true;
      try {
        ok = RewampAudio().canPlay(candidates[i].file.path);
      } catch (_) {
        ok = true;   // pas de moteur (tests) ⇒ on fait confiance au rang
      }
      if (ok) {
        if (i > 0) {
          debugPrint('[extract] ${p.basename(candidates.first.file.path)} '
              'refusé par le moteur → ${p.basename(candidates[i].file.path)}');
        }
        return candidates[i].file;
      }
    }
    return candidates.first.file;
  }

  /// Richesse du format, du plus riche au plus pauvre — ce qui départage deux
  /// fichiers d'une même archive quand aucun ne porte le nom de celle-ci.
  ///
  ///   0 · PATTERNS natifs (libopenmpt, Furnace, SunVox, TIATracker): vue
  ///       patterns + voies + sous-chansons, la version la plus riche du morceau.
  ///   1 · PUCE multi-voies (vgm, nsf, sid, psf, uade, …): pas de patterns mais
  ///       un oscilloscope par voie, des mutes, des sous-chansons.
  ///   2 · FLUX (mp3, ogg, vgmstream, ape, …): rien d'autre qu'une stéréo.
  ///
  /// ⚠️ L'EXTENSION fait autorité; le préfixe n'est qu'un REPLI. Un nom Amiga
  /// porte bien son format avant le point (`mdat.monkey island`), mais cette
  /// convention ne vaut que pour les fichiers dont le suffixe ne dit rien.
  /// Consulter le préfixe d'un fichier qui a DÉJÀ une extension connue laisse
  /// n'importe quel nom en deux parties tirer le fichier dans un autre groupe:
  /// mesuré sur `bgm.vgz`, dont le préfixe `bgm` est un vrai token (libkss, et
  /// vgmstream) — c'est lui, et pas l'extension, qui décidait du palier.
  ///
  /// ⚠️ Et l'ORDRE des tests compte: `kVgmstreamExts` réclame 705 extensions,
  /// dont `vgm` et `spc`, qui sont des formats à PUCE joués par libvgm et
  /// libgme. Tester « vgmstream ⇒ flux » avant les groupes dédiés les
  /// classerait en flux et les ferait perdre contre un `.ogg` voisin. Les
  /// conteneurs de son échantillonné sont des flux d'office, tout ce qu'un
  /// décodeur DÉDIÉ réclame est une puce, et vgmstream ne tranche qu'en dernier
  /// ressort — pour ce que personne d'autre ne connaît.
  static int _formatTier(String ext, String prefix) {
    int tierOf(String tok) {
      if (tok.isEmpty) return -1;
      if (kPatternExts.contains(tok)) return 0;
      if (kStreamAudioExts.contains(tok)) return 2;
      if (kAllDecoderExts.contains(tok)) return 1;
      if (kVgmstreamExts.contains(tok)) return 2;
      return -1;                       // inconnu
    }

    final byExt = tierOf(ext);
    if (byExt >= 0) return byExt;
    final byPrefix = tierOf(prefix);
    return byPrefix >= 0 ? byPrefix : 2;
  }

  /// Archive extensions a locally-opened file can be unpacked from (libarchive
  /// handles all of these — the vendored LHA reader covers UnExotica's `.lha`).
  static const kLocalArchiveExts = {
    'lha', 'lzh', 'zip', '7z', 'rar', 'tar', 'gz', 'xz',
  };

  /// The cache dir a locally-opened archive extracts into (basename + byte
  /// length keyed). Public so the preset-import path can inspect an extraction
  /// that yielded no PLAYABLE track for `.milk` presets — without a second
  /// extraction.
  static Future<String> localArchiveCacheDir(String archivePath) async {
    final len = await File(archivePath).length();
    final base = p.basenameWithoutExtension(archivePath);
    final cacheRoot = await getApplicationCacheDirectory();
    return p.join(cacheRoot.path, 'local_archives', '${_sanitize(base)}_$len');
  }

  /// Ré-extraction à la volée d'un fichier de cache d'archive PURGÉ.
  ///
  /// `Caches/local_archives/` est un cache que l'OS peut vider quand il veut —
  /// mais l'ARCHIVE d'origine, elle, est encore là: sur mobile c'est la copie
  /// stable du geste dans `opened/` (OpenedFiles.materialise). Le nom du
  /// dossier de cache encode déjà la clé de l'archive
  /// (`<radical assaini>_<taille>`, voir [localArchiveCacheDir]): on cherche
  /// dans `opened/` une archive qui reproduit cette clé et on ré-extrait —
  /// même clé ⇒ même dossier, le chemin demandé redevient valide TEL QUEL.
  /// Rend true quand le fichier existe à nouveau. Desktop: `opened/` n'est pas
  /// alimenté (le sélecteur y rend le vrai chemin), le repli échoue simplement.
  static Future<bool> reExtractForMissingLocalPath(String path) async {
    final parts = p.split(path);
    final i = parts.indexOf('local_archives');
    if (i < 0 || i + 1 >= parts.length) return false;
    final archive = await openedArchiveForCacheKey(parts[i + 1]);
    if (archive == null) return false;
    try {
      await extractLocalArchiveToTracks(archive); // ré-extrait (marqueur mort)
      return await File(path).exists();
    } catch (_) {}
    return false;
  }

  /// L'ARCHIVE d'origine d'un dossier de cache d'extraction, cherchée dans
  /// `opened/` (la copie stable du geste). [cacheKey] est le nom du dossier,
  /// `<radical assaini>_<taille>` — voir [localArchiveCacheDir].
  ///
  /// Publique parce que deux appelants en ont besoin, pour des raisons
  /// différentes: la ré-extraction à la volée d'un cache purgé, et la garde
  /// d'identité de bibliothèque, qui importe l'ARCHIVE plutôt que le membre
  /// isolé (ses compagnons sont ses voisins dedans). Null sur desktop, où
  /// `opened/` n'est pas alimenté.
  static Future<String?> openedArchiveForCacheKey(String cacheKey) async {
    try {
      final opened = await OpenedFiles.dir();
      if (!await opened.exists()) return null;
      await for (final e in opened.list(followLinks: false)) {
        if (e is! File) continue;
        final ext = p.extension(e.path).replaceFirst('.', '').toLowerCase();
        if (!kLocalArchiveExts.contains(ext)) continue;
        final stem = p.basenameWithoutExtension(e.path);
        final len = await e.length();
        if ('${_sanitize(stem)}_$len' != cacheKey) continue;
        return e.path;
      }
    } catch (_) {}
    return null;
  }

  /// Extracts a LOCALLY-opened archive (UnExotica `.lha`, or any container in
  /// [kLocalArchiveExts]) into a per-archive cache dir and returns one
  /// TrackRecord per playable module inside. Companions (TFMX `smpl.*`, etc.)
  /// are skipped because they match neither an audio extension nor an audio
  /// PREFIX token; UADE multifile modules resolve their siblings from the same
  /// extracted directory at play time. Re-opening the same archive reuses the
  /// extraction (keyed by basename + byte length). Empty list = nothing
  /// playable inside, or extraction failed.
  static Future<List<TrackRecord>> extractLocalArchiveToTracks(
      String archivePath) async {
    final file = File(archivePath);
    if (!await file.exists()) return const [];
    final destDir = await localArchiveCacheDir(archivePath);
    final dir = Directory(destDir);

    // Extract once. A marker file distinguishes "already extracted" from a
    // half-written dir left by an interrupted run.
    final marker = File(p.join(destDir, '.extracted'));
    if (!await marker.exists()) {
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
      final (rc, err) = await _extractArchiveOffThread(archivePath, destDir);
      if (rc != 0) {
        debugPrint('[RewampDb] local archive extract failed rc=$rc: $err');
        return const [];
      }
      await marker.writeAsString('1', flush: true);
    }

    // Enumerate playable modules recursively. A file is playable when its
    // suffix OR its Amiga prefix token is an audio format (the prefix rule is
    // what makes "mdat.NAME" playable while its "smpl.NAME" companion — whose
    // prefix isn't a format — is correctly skipped). See _findExtractedAudio.
    final out = <TrackRecord>[];
    final album = p.basename(archivePath);
    final files = <(File, String)>[];   // (file, format token)
    try {
      await for (final e in dir.list(recursive: true)) {
        if (e is! File) continue;
        final baseName = p.basename(e.path);
        if (baseName.startsWith('.')) continue;
        final ext = p.extension(e.path).replaceFirst('.', '').toLowerCase();
        final prefix =
            baseName.contains('.') ? baseName.split('.').first.toLowerCase() : '';
        String? fmt;
        if (kExtractedAudioExts.contains(ext)) {
          fmt = ext;
        } else if (prefix.isNotEmpty && kExtractedAudioExts.contains(prefix)) {
          fmt = prefix;
        }
        if (fmt != null) {
          // Same guard as _findExtractedAudio: a whitelisted extension on a
          // text file (scene.org and friends) is a stub, not a track.
          var size = 0;
          try { size = await e.length(); } catch (_) {}
          if (await _isTextStub(e, size)) continue;
          files.add((e, fmt));
        }
      }
    } catch (_) {}
    files.sort((a, b) => a.$1.path.toLowerCase().compareTo(b.$1.path.toLowerCase()));

    for (final (f, fmt) in files) {
      out.add(TrackRecord(
        id: '',
        filePath: f.path,
        entryPath: '',
        subsongIdx: 0,
        title: p.basename(f.path),
        metaAlbum: album,
        formatExt: fmt,
        source: 'local',
        isFavorite: false,
        inLibrary: false,
        playCount: 0,
      ));
    }
    return out;
  }

  /// Public alias — needed by screens that want to check cache before ZIP download.
  static Future<String> localPath(SearchResult r) => _localPath(r);

  /// The authoritative in-archive subsong index for a downloaded track.
  ///
  /// An RSN (snesmusic) album is one `.rsn` played in place, each track a
  /// subsong; the correct index is the track's rank INSIDE the archive, which
  /// `_rsnResults` records in the DB at download time keyed by the track's
  /// (unique) online id. A search/playlist row's own `subsongIdx` doesn't know
  /// that rank — hence the wrong-track bug. For any other path we keep
  /// [fallback] (e.g. SID shares one online id across all its subsongs, so a DB
  /// lookup would be ambiguous — its own subsongIdx is already correct).
  static Future<int> archiveSubsongIndex({
    required String path,
    required String songId,
    required int fallback,
  }) async {
    if (songId.isEmpty || !path.toLowerCase().endsWith('.rsn')) return fallback;
    final row = await LocalDb.instance.getTrackByOnlineId(songId);
    return row?.subsongIdx ?? fallback;
  }

  /// Downloads [zipUrl] and extracts its contents into the directory tree used
  /// by [downloadToLibrary], so subsequent calls find files already cached.
  ///
  /// - Audio files → `Documents/online/<artist>/<format>/<album>/`
  /// - Artwork     → `Documents/online/<artist>/<album>/artwork.<ext>`
  ///   (where [ArtworkCache] looks)
  /// - M3U/M3U8   → parsed to determine playback order
  ///
  /// Returns the [tracks] list reordered according to the embedded playlist,
  /// or `null` if no playlist was found (keep original order).
  /// [force] = « Re-télécharger l'album »: le dossier est vidé (pochette
  /// comprise), l'archive redemandée en contournant l'edge CDN et le tampon
  /// local, et AUCUN repli sur ce qui est déjà là — sans quoi le geste est un
  /// pur no-op sur un album zip: le `.rsn` en place court-circuite tout dès la
  /// première ligne.
  static Future<List<SearchResult>?> downloadAndExtractZip(
    String zipUrl,
    List<SearchResult> tracks, {
    String? mirrorZipUrl,
    String? albumId,
    bool force = false,
  }) =>
      BackgroundTask.guard(() async {
        try {
          final res = await _downloadAndExtractZipImpl(
              zipUrl, tracks, mirrorZipUrl, albumId, force);
          _statusClear();
          return res;
        } on DownloadCancelledException {
          _statusClear();
          rethrow;
        } catch (e) {
          _statusFail(
              tracks.isEmpty ? zipUrl : (tracks.first.album ?? zipUrl), e);
          rethrow;
        }
      });

  static Future<List<SearchResult>?> _downloadAndExtractZipImpl(
    String zipUrl,
    List<SearchResult> tracks,
    String? mirrorZipUrl,
    String? albumId,
    bool force,
  ) async {
    if (tracks.isEmpty) return null;

    // Already-downloaded RSN short-circuit: the .rsn lives at a deterministic
    // path derived from the first track. If it is already on disk, rebuild the
    // subsong list from it WITHOUT fetching the archive again. Without this the
    // bytes were re-downloaded over the network on every play (the write was
    // skipped, but the fetch was not) — the "re-downloads systematically" bug.
    final rsnPath = await rsnLocalPath(tracks.first);
    if (!force && await File(rsnPath).exists()) {
      debugPrint('[album] rsn cached, no fetch: $rsnPath');
      return _rsnResults(zipUrl, rsnPath, tracks, albumId,
          await File(rsnPath).length());
    }
    debugPrint('[album] rsn probe MISS: $rsnPath '
        '(first=${tracks.first.songId} albumId=${tracks.first.albumId})');

    // Determine target audio directory from the first track.
    final firstPath = await _localPath(tracks.first);
    final audioDir =
        p.dirname(firstPath); // .../online/<artist>/<format>/<album>

    // Même verrou par dossier que _downloadAndExtractSingle: l'album entier
    // se télécharge/extrait UNE fois, les appels concurrents attendent puis
    // retombent sur les fichiers en place.
    return _withDirLock(audioDir, () async {
    if (!force && await File(rsnPath).exists()) {
      // Un concurrent vient de poser le .rsn pendant l'attente du verrou.
      return _rsnResults(zipUrl, rsnPath, tracks, albumId,
          await File(rsnPath).length());
    }
    if (force) {
      // Table rase: fichiers extraits, `.rsn` en place, pochette et lignes DB.
      // Le dossier vidé est ce qui rend le geste effectif — l'extraction
      // écrase les fichiers de MÊME nom, jamais ceux que la nouvelle archive
      // ne porte plus.
      await _wipeAlbumDirs({audioDir, p.dirname(rsnPath)},
          keepArtwork: false, keepUserState: true);
    }
    await Directory(audioDir).create(recursive: true);

    // Artwork → same folder as audio (disambiguated by albumId in path).
    final artworkDir = audioDir;

    // Download the archive — to DISK, not memory (see _fetchToFileRaw).
    final albumLabel = tracks.first.album ?? p.basename(zipUrl);
    final (head, archivePath) = await _fetchArchiveShared(
        force ? null : mirrorZipUrl, zipUrl,
        label: '$albumLabel (album)',
        expectedSize: tracks.first.fileSize,
        cap: const Duration(minutes: 10),
        bustCache: force);

    // Detect RAR archive by magic 'Rar!' (0x52 0x61 0x72 0x21).
    // snesmusic distributes albums as .rsn (RAR of SPC files) — handle before
    // attempting ZIP decode.
    if (head.length >= 4 &&
        head[0] == 0x52 &&
        head[1] == 0x61 &&
        head[2] == 0x72 &&
        head[3] == 0x21) {
      return _handleRsnDownload(zipUrl, archivePath, audioDir, tracks, albumId);
    }

    // Shared whitelist (chip/tracker + plain audio + midi) so zip albums
    // extract every playable entry, not just the historical chip subset.
    final audioExts = kExtractedAudioExts;
    const artworkExts = {'jpg', 'jpeg', 'png', 'webp', 'gif'};
    const playlistExts = {'m3u', 'm3u8'};

    // Decode + decompress + write in a background isolate: ArchiveFile
    // decompression is lazy (runs at entry.content in this loop) and froze
    // the UI on big albums. The closure only captures sendable values.
    // ⚠️ La closure ne capture plus que le CHEMIN. Elle capturait les OCTETS,
    // et `Isolate.run` COPIE ce qu'il capture dans le nouvel isolate: un album
    // zip de 300 Mo existait donc DEUX fois en mémoire. Le décodeur lit
    // maintenant le fichier lui-même, et décompresse chaque entrée À LA
    // DEMANDE — d'où la fermeture du flux seulement APRÈS la dernière entrée.
    final m3uContent = await Isolate.run(() {
      final input = InputFileStream(archivePath);
      try {
        final archive = ZipDecoder().decodeStream(input);
        String? m3uRegular;
        int m3uBestEntries = -1;   // regular playlist with the most entries wins
        String? m3uTags; // vgmstream !tags.m3u — playlist of last resort

        // Entry paths RELATIVE to the archive's content root, mirroring what the
        // server stores in each row's `filename`.
        //
        // Sub-folders are PRESERVED (the native extractor used for PSF albums
        // does the same, and _localPath()/_fileSegments() resolve them): taking
        // p.basename() here used to flatten "XA/VIDEO/ASPI.ogg" to "ASPI.ogg",
        // which silently loses one of two same-named files in different folders
        // and disagrees with every lookup path. What DOES need stripping is the
        // single wrapper directory ZIPs are usually built with — and only when
        // every entry shares it, which is exactly what makes it a wrapper rather
        // than real structure.
        final fileEntries = archive.where((e) => e.isFile).toList();
        String? wrapper;
        for (final e in fileEntries) {
          final segs = e.name.replaceAll('\\', '/').split('/')
              .where((s) => s.isNotEmpty).toList();
          if (segs.length < 2) { wrapper = null; break; }   // a root-level file ⇒ no wrapper
          if (wrapper == null) {
            wrapper = segs.first;
          } else if (wrapper != segs.first) {
            wrapper = null; break;                          // entries disagree ⇒ real structure
          }
        }

        String relPath(String rawName) {
          var segs = rawName.replaceAll('\\', '/').split('/')
              .where((s) => s.isNotEmpty && s != '.' && s != '..')  // no traversal
              .toList();
          if (wrapper != null && segs.length > 1 && segs.first == wrapper) {
            segs = segs.sublist(1);
          }
          return p.joinAll(segs.map(_sanitize));
        }

        for (final entry in fileEntries) {
          final name = p.basename(entry.name);
          final ext = p.extension(name).replaceFirst('.', '').toLowerCase();

          if (audioExts.contains(ext)) {
            final dest = File(p.join(audioDir, relPath(entry.name)));
            if (!dest.existsSync()) {
              dest.parent.createSync(recursive: true);
              dest.writeAsBytesSync(entry.content as List<int>);
            }
          } else if (artworkExts.contains(ext)) {
            final dest = File(p.join(artworkDir, 'artwork.$ext'));
            if (!dest.existsSync()) {
              dest.writeAsBytesSync(entry.content as List<int>);
            }
          } else if (playlistExts.contains(ext)) {
            // Save EVERY m3u to disk (so probe/complementary reads find them),
            // and keep the regular playlist with the most entries; a !tags.m3u
            // is the playlist only when it is the sole m3u.
            final data = entry.content as List<int>;
            // ⚠️ Pas `String.fromCharCodes`: il fait d'un octet un caractère,
            // donc c'était faux même pour de l'UTF-8 (« Ã© » pour « é »), et
            // du Shift-JIS en sortait en rectangles. Voir legacy_text.dart —
            // l'isolate crée son propre moteur au besoin.
            final text = decodeFileText(data);
            // Same relative placement as the audio: an m3u's entries are relative
            // to the folder holding it, so moving it changes what it points at.
            final dest = File(p.join(audioDir, relPath(entry.name)));
            if (!dest.existsSync()) {
              dest.parent.createSync(recursive: true);
              dest.writeAsBytesSync(data);
            }
            if (_isTagsM3uName(name)) {
              m3uTags ??= text;
            } else {
              final n = _countM3uEntries(text);
              if (n > m3uBestEntries) {
                m3uBestEntries = n;
                m3uRegular = text;
              }
            }
          }
        }
        return m3uRegular ?? m3uTags;
      } finally {
        input.closeSync();
      }
    });

    if (m3uContent == null) return null;
    return _applyM3UOrder(m3uContent, tracks);
    });
  }

  /// Deterministic on-disk path of an album's `.rsn`, keyed on the ALBUM
  /// (album_id, else zip_url, else album name) via _dirSegments — never the
  /// artist, so a foreign playlist/search row whose artist ordering differs
  /// from the album's canonical first track resolves the SAME path. Doubles as
  /// the "is this album already downloaded?" probe. Mirrors the layout
  /// [_handleRsnDownload] writes to.
  static Future<String> rsnLocalPath(SearchResult t) async {
    final base = await _baseDir();
    final albumName = t.album ?? 'album';
    final rsnName = '${_sanitize(albumName)}.rsn';
    // Album-keyed, artist-free — same dir _dirSegments builds for the RSN's
    // artwork, and stable across a foreign playlist/search row whose artist
    // ordering differs from the album's canonical first track.
    return p.joinAll([base.path, ..._dirSegments(t), rsnName]);
  }

  /// Saves an RSN (RAR archive of SPC files) and returns a rewritten track
  /// list where every entry points to the single local RSN file.  Each track
  /// gets a [SearchResult.subsongIdx] matching its position in the album so
  /// the GME plugin can call gme_start_track() with the right index.
  static Future<List<SearchResult>> _handleRsnDownload(
    String rsnUrl,
    String archivePath,
    String audioDir,
    List<SearchResult> tracks,
    String? albumId,
  ) async {
    // Save RSN to the canonical deterministic path (same one used to later probe
    // "already downloaded?"), NOT audioDir (which was derived for formatExt='spc'
    // → .../spc/<album>/) — a mismatch would re-download on every play.
    final rsnPath = await rsnLocalPath(tracks.first);
    await Directory(p.dirname(rsnPath)).create(recursive: true);
    final rsnFile = File(rsnPath);
    // Une COPIE de fichier, faite par le système — pas une relecture en
    // mémoire: un .rsn complet se joue en place et peut peser lourd.
    if (!await rsnFile.exists()) await File(archivePath).copy(rsnPath);
    return _rsnResults(
        rsnUrl, rsnPath, tracks, albumId, await File(archivePath).length());
  }

  /// Builds the per-subsong track list for a saved `.rsn` at [rsnPath] and
  /// pre-populates the local DB, WITHOUT any network I/O. Shared by the initial
  /// download and the already-cached short-circuit.
  static Future<List<SearchResult>> _rsnResults(
    String rsnUrl,
    String rsnPath,
    List<SearchResult> tracks,
    String? albumId,
    int fileSize,
  ) async {
    // Prefer the authoritative album id threaded from the caller; otherwise fall
    // back to whichever track row carried one (get_album_tracks may stamp it).
    final effAlbumId = (albumId != null && albumId.isNotEmpty)
        ? albumId
        : tracks
            .map((t) => t.albumId)
            .firstWhere((id) => id != null && id.isNotEmpty, orElse: () => null);
    final albumName = tracks.first.album ?? 'album';
    final rsnName = '${_sanitize(albumName)}.rsn';

    final artistRaw = tracks.first.artistNames.isNotEmpty
        ? tracks.first.artistNames.first
        : null;

    // In-archive rank per song id — this rank IS what plays. The CALLER's list
    // order cannot be trusted: a playlist (even single-album) hands its rows in
    // PLAYLIST order, possibly a subset. Canonical order = the album's rows
    // sorted by position (what the archive was built from); offline replay
    // falls back to the DB rows written at download time; a song absent from
    // both keeps its list index. The upsert below also HEALS rows corrupted by
    // the pre-fix playlist path.
    final rank = <String, int>{};
    try {
      final canon = await browse(
        albumName:  tracks.first.album,
        collection: tracks.first.collection.isNotEmpty
            ? tracks.first.collection
            : null,
        sortBy:     'position',
        limit:      500,
      );
      for (var i = 0; i < canon.length; i++) {
        rank[canon[i].songId] = i;
      }
    } catch (_) {}
    if (rank.isEmpty) {
      try {
        for (final row in await LocalDb.instance.getTracksForFile(rsnPath)) {
          final id = row.onlineId;
          if (id != null && id.isNotEmpty) rank[id] = row.subsongIdx;
        }
      } catch (_) {}
    }

    final results = List<SearchResult>.generate(tracks.length, (i) {
      final t = tracks[i];
      return SearchResult(
        songId: t.songId,
        collection: t.collection,
        title: t.title,
        filename: rsnName,
        album: t.album,
        albumId: effAlbumId,
        formatExt: 'rsn',
        downloadUrl: rsnUrl,
        fileSize: fileSize,
        year: t.year,
        artistNames: t.artistNames,
        totalCount: t.totalCount,
        platform: t.platform,
        rating: t.rating,
        artworkUrl: t.artworkUrl,
        trackPosition: t.trackPosition,
        subsongIdx: rank[t.songId] ?? i,
      );
    });

    // Pre-populate local DB with all subsongs so getTracksForFile() can
    // reconstruct the full queue even before each track has been played.
    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      await LocalDb.instance.upsertTrack(
        filePath: rsnPath,
        subsongIdx: r.subsongIdx,
        title: r.displayTitle,
        artist: artistRaw,
        metaAlbum: albumName,
        formatExt: 'rsn',
        source: 'online',
        onlineId: r.songId,
        albumId: effAlbumId,
        artworkUrl: r.artworkUrl,
        collectionSlug: r.collection,
        platformName:   r.platform,
        year:           r.year,
      );
    }

    return results;
  }

  /// Reorders [tracks] according to an M3U playlist string.
  /// Tracks not referenced in the playlist are appended at the end.
  static List<SearchResult> _applyM3UOrder(
    String m3u,
    List<SearchResult> tracks,
  ) {
    // Case-insensitive lookup by filename. A row's filename may carry the
    // archive sub-folder it lives in ("XA/VIDEO/ASPI.ogg"), while an M3U line is
    // matched on its basename — so index BOTH forms, else every sub-folder track
    // missed its M3U line and silently fell through to the "unreferenced" tail
    // at the end of the album. Full paths are inserted last so they win a clash
    // between a bare name and a same-named file inside a sub-folder.
    final byFilename = <String, SearchResult>{};
    for (final t in tracks) {
      final f = t.filename.toLowerCase();
      byFilename.putIfAbsent(p.basename(f), () => t);
    }
    for (final t in tracks) {
      byFilename[t.filename.toLowerCase()] = t;
    }

    final ordered = <SearchResult>[];
    final used = <SearchResult>{};

    for (final raw in m3u.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      // Try the line's own relative path first (it disambiguates two same-named
      // files in different folders), then its basename.
      final rel  = line.replaceAll('\\', '/').toLowerCase();
      final match = byFilename[rel] ?? byFilename[p.basename(rel)];
      if (match != null && used.add(match)) ordered.add(match);
    }

    // Append any tracks the M3U didn't reference.
    for (final t in tracks) {
      if (used.add(t)) ordered.add(t);
    }

    return ordered.isEmpty ? tracks : ordered;
  }

  // ── Container probing ────────────────────────────────────────────────────

  /// File extensions that are single-file multi-subsong containers
  /// (i.e. a single downloaded file can contain N tracks).
  /// Formats dont SEUL le décodeur sait compter les sous-chansons — le serveur
  /// n'a jamais de tracklist pour eux, et son `track_count` y vaut 1 par
  /// DÉFAUT, pas par constat. C'est la seule exception à la règle
  /// « `subsong_count == 1` = mono, affirmé » d'[isContainerRow].
  ///
  /// ⚠️ `.adl` Westwood: une TABLE de morceaux dont la sous-chanson 0 est
  /// presque toujours la routine d'ARRÊT du pilote. Joué tel quel — ce que
  /// faisait tout téléchargement depuis modland, `track_count: 1` — il ne
  /// produisait RIEN, alors que le même fichier importé localement jouait ses
  /// 43 morceaux (la porte locale est `kMultiTrackExts`, qui ne regarde que
  /// l'extension). Mesuré sur `modland/Ad Lib/ADL/Paul Mudra/eob2 -
  /// catacomb.adl`: le serveur annonce 1, le fichier en tient 111.
  ///
  /// ⚠️ `.gbr` Game Boy: un rip du DRIVER, sans table de morceaux — libgbsplay
  /// annonce 255, la valeur maximale d'un `uint8_t`, qui veut dire « je ne
  /// sais pas ». C'est la sonde native qui demande au pilote lesquels jouent
  /// vraiment, et sa liste est CREUSE comme celle d'un `.adl`.
  static const kNativeCountedContainerFormats = {'adl', 'gbr'};

  /// Formats dont les sous-chansons se numérotent à partir de **1** dans
  /// `?subsong=`: le moteur y lit le numéro NATIF du format (SNDH, sc68 —
  /// `rewamp_*_probe_base()` rend 1), et **0 n'y désigne pas « la première »
  /// mais « le défaut du fichier »**.
  ///
  /// La sonde native connaît cette base; un dépliage fait SANS le fichier
  /// (AppShell._subsongEntries, depuis un rail ou un palmarès: on n'a que le
  /// `subsong_count` du catalogue) ne la connaissait pas et comptait 0..n-1.
  /// Tout était alors décalé d'un cran: « Amberstar (2) » jouait le morceau 1,
  /// « (1) » jouait le défaut (le 1 aussi, le plus souvent), et le DERNIER
  /// morceau du fichier n'était jamais atteint. Le palmarès, lui, désigne son
  /// entrée la plus écoutée par son VRAI index (1-based ici): la rotation
  /// tombait donc sur la bonne MUSIQUE sous le mauvais NOM.
  ///
  /// KSS a aussi une base non nulle, mais DYNAMIQUE (`trkmin`, lue dans le
  /// fichier) — il passe par la tracklist serveur ou la sonde, pas par ici.
  static const kOneBasedSubsongExts = {'sndh', 'sc68'};

  /// Les index de sous-chanson d'un fichier dont on ne connaît que le COMPTE.
  /// Pure, pour être testable.
  static List<int> genericSubsongIndices(String formatExt, int count) {
    final base = kOneBasedSubsongExts.contains(formatExt.toLowerCase()) ? 1 : 0;
    return List.generate(count, (i) => base + i);
  }

  static const kContainerFormats = {
    'nsf', 'nsfe', 'ay', 'gbs', 'kss', 'sap', 'hes',
    'vgm', 'vgz', 'sid', 'psid', 'rsid',
    'mgs', 'bgm', 'opx', 'mpk', 'mbm',
  };

  /// Whether [r] is a multi-subsong container that must route through the
  /// subsong screen / download+probe path rather than playing as one track.
  ///
  /// Encodes the mirror-sidecar `tracklist` rule (server-side, ingested into the
  /// row's `subsong_count`):
  ///   • `subsong_count > 1`  → enumeration known (N subsongs) → container.
  ///   • `subsong_count == 1` → the sidecar positively says mono → play direct,
  ///     NEVER a container (even for a container-format ext like .gbs).
  ///   • `subsong_count == null` → un-annotated: fall back to the format guess
  ///     (kContainerFormats) → probe on open. "tracklist absent = unknown".
  /// A non-null `trackPosition` means the row is already one track of an
  /// expanded list, so it is never itself a container.
  static bool isContainerRow(SearchResult r) {
    if (r.trackPosition != null) return false;
    if ((r.subsongCount ?? 0) > 1) return true;
    final ext = r.formatExt.toLowerCase();
    // L'exception à la règle du sidecar: pour ces formats le compte du serveur
    // ne dit rien (voir kNativeCountedContainerFormats) — sauf sur une ligne
    // DÉJÀ résolue, qui désigne une sous-chanson précise et n'est donc pas le
    // conteneur.
    if (!r.resolvedSubsong && kNativeCountedContainerFormats.contains(ext)) {
      return true;
    }
    return r.subsongCount == null && kContainerFormats.contains(ext);
  }

  /// True when a search/browse row is an ALBUM-level match that should be HIDDEN
  /// from the songs list — a joshw container (album_id set + track_count > 1)
  /// matched by its GAME/album name, not a track (match_track_title == null). It
  /// already appears under "albums" (same album_id), and its 44 real tracks live
  /// in the `tracks` JSONB, not as separate song rows. hvsc/asma/modland have
  /// album_id == null → always shown as songs. When the query matched a specific
  /// track (match_track_title != null) the row IS shown (as that track).
  /// `>= 1`, not `> 1`: an UnExotica game with a single module is still an
  /// album (cover art, year, "the game"), and its browse_folder row carries
  /// track_count=1 — requiring >1 made those play as bare files with no album
  /// screen. A row with a KNOWN count of one album track is the whole album by
  /// construction (one row per archive); null counts keep the old behavior.
  /// **Routing, not visibility.** This says "tapping this row should open its
  /// ALBUM rather than play it" — a joshw archive matched by its game name is
  /// not a playable track. It used to double as a filter on the songs listings
  /// and that was wrong on principle: a tab whose job is to list tunes must
  /// list them all, standalone or inside an album, or a tune becomes
  /// unfindable. Both call sites now show every row (see search_screen).
  ///
  /// `>= 1` alone was not enough, and it hid REAL tracks: the rule assumed
  /// "album_id set" implied a container row, which stopped being true when
  /// per-file collections started carrying album ids (modland's "Insignificant
  /// Demo" — 4 `.4v` modules, `album_id` set, `track_count` 1 — searched fine,
  /// counted 4, and listed nothing, because every row was taken for the album
  /// itself). So the row also has to LOOK like a container: several tracks
  /// inside, or an archive/multi-subsong file rather than a plain module.
  static const _kAlbumRowArchiveExts = {
    '7z', 'zip', 'rar', 'gz', 'tar', 'lha', 'lzh', 'xz',
  };

  /// Résout une ligne dont le serveur a nommé la PISTE (`match_track_title`)
  /// vers cette piste précise — c'est elle qu'il faut jouer, pas le conteneur.
  ///
  /// Même chemin que le tap d'une ligne (`SongTile._handleTap`): la tracklist
  /// de l'album donne les vraies sous-chansons, on prend celle dont l'INDEX
  /// joueur correspond, à défaut celle dont le titre correspond. Sans album_id
  /// (fichier unique multi-sous-chansons), l'index suffit. Toute impasse rend
  /// la ligne d'origine — jamais null: perdre une ligne déplacerait le début
  /// de la lecture.
  static Future<SearchResult> resolveMatchedTrack(SearchResult r) async {
    if (r.matchSubsongTitle == null) return r;
    if (r.albumId != null) {
      try {
        final tracks = await albumTracks(albumId: r.albumId!);
        if (tracks.isNotEmpty) {
          final rows = subsongRowsFromServer(tracks.first);
          SearchResult? pick;
          if (r.matchSubsongIndex != null) {
            for (final x in rows) {
              if (x.subsongIdx == r.matchSubsongIndex) {
                pick = x;
                break;
              }
            }
          }
          if (pick == null) {
            for (final x in rows) {
              if (x.title == r.matchSubsongTitle) {
                pick = x;
                break;
              }
            }
          }
          if (pick != null) return pick;
        }
      } catch (_) {/* repli ci-dessous */}
    }
    // Repli: on épingle l'index nommé, avec la durée que le serveur donne pour
    // CETTE piste (`match_track_length_ms`) — sans elle, `withSubsong` la
    // laisserait vide, la durée du conteneur ne décrivant pas ce sous-chant.
    return r.matchSubsongIndex != null
        ? r.withSubsong(r.matchSubsongIndex!,
            durationMs: r.matchSubsongLengthMs)
        : r;
  }

  /// [resolveMatchedTrack] sur une LISTE, par lots de 5 et dans l'ordre.
  static Future<List<SearchResult>> resolveMatchedTracks(
      List<SearchResult> rows) async {
    if (!rows.any((r) => r.matchSubsongTitle != null)) return rows;
    final out = <SearchResult>[];
    for (var i = 0; i < rows.length; i += 5) {
      final end = i + 5 < rows.length ? i + 5 : rows.length;
      out.addAll(await Future.wait(
          [for (final r in rows.sublist(i, end)) resolveMatchedTrack(r)]));
    }
    return out;
  }

  /// Cette ligne n'a matché QUE par le nom de son ALBUM.
  ///
  /// Chercher « Kondo » ramenait les onze pistes d'un album snesmusic dont
  /// AUCUN titre ne contient le mot (« A Challenging Opponent », « Game
  /// Over »…): c'est le nom de l'album qui matche. Ces lignes polluent
  /// l'onglet Morceaux, qui doit lister les pistes dont le NOM correspond —
  /// dans un album ou non — et l'album lui-même a son onglet.
  ///
  /// ⚠️ Le test est CONSERVATEUR par construction: on n'écarte que si l'on peut
  /// ATTRIBUER le match à l'album (son nom contient bien la recherche). Sous
  /// recherche FLOUE, un titre peut matcher sans contenir la chaîne (faute de
  /// frappe, radicaux); dans ce cas l'album ne la contient pas non plus, et la
  /// ligne est GARDÉE. Le doute profite au résultat: une ligne cachée est une
  /// piste que l'utilisateur ne trouve plus.
  ///
  /// Un match par ARTISTE reste un match: les morceaux de Koji Kondo sortent
  /// sur « Kondo » même quand leur titre ne le porte pas.
  static bool matchedAlbumNameOnly(SearchResult r, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    // Le serveur a nommé une PISTE dans le conteneur: le match vient d'elle,
    // pas du nom d'album — même sous recherche floue, où son titre ne contient
    // pas forcément la chaîne.
    if (r.matchSubsongTitle != null) return false;
    final album = (r.album ?? '').toLowerCase();
    if (!album.contains(q)) return false;
    bool has(String? v) => v != null && v.toLowerCase().contains(q);
    if (has(r.title) || has(r.filename) || has(r.matchSubsongTitle)) {
      return false;
    }
    for (final a in r.artistNames) {
      if (has(a)) return false;
    }
    return true;
  }

  /// Une ligne qui REPRÉSENTE UN ALBUM ENTIER — l'archive joshw d'un jeu, dont
  /// le serveur ne connaît aucun détail piste par piste — et non un morceau.
  ///
  /// ⚠️ Bien plus ÉTROIT que [isAlbumLevelMatch], qui sert à décider d'une
  /// NAVIGATION et attrape aussi les MEMBRES d'archive sans url à eux (les
  /// `.spc` d'un `.rsn` snesmusic: `download_url` ET `mirror_url` nuls). Ceux-là
  /// sont des morceaux, et les confondre avec des albums est ce qui a vidé la
  /// liste de « Tout lire » sur « Kondo » + plage d'années — 10 lignes sur 10
  /// écartées, bouton muet. Trois conditions, toutes nécessaires: un album
  /// identifié, AUCUNE position de piste, et PLUSIEURS pistes annoncées (un
  /// fichier multi-sous-chansons sans album — un `.sid` HVSC — reste un
  /// morceau, `albumId` étant nul).
  /// ⚠️ Et `match_track_title` NON NUL est décisif: le serveur a nommé UNE
  /// piste À L'INTÉRIEUR du conteneur, donc la ligne EST cette piste. Chercher
  /// « into the wilderness » ne rend que des lignes de cette sorte (8 sur 8:
  /// Wild Arms → « To the End of the Wilderness », Ys V → « Wilderness »…):
  /// sans cette garde l'onglet Morceaux affichait « 0 / 8 ».
  static bool isWholeAlbumRow(SearchResult r) =>
      r.albumId != null &&
      r.matchSubsongTitle == null &&
      r.trackPosition == null &&
      (r.subsongCount ?? 0) > 1;

  static bool isAlbumLevelMatch(SearchResult r) {
    if (r.albumId == null || r.matchSubsongTitle != null) return false;
    if ((r.subsongCount ?? 0) > 1) return true;   // enumerated tracks inside
    // No file of its own = not a row you can list on its own: it is a member of
    // the album's archive (a snesmusic .spc lives inside the .rsn and has no
    // url), which is exactly why those belong under Albums.
    if (r.downloadUrl == null && r.mirrorUrl == null) return true;
    // A single-module UnExotica game is still an album: its row is the .lha,
    // and the server sends no format_ext for it (the client falls back to the
    // archive's own extension).
    final ext = r.formatExt.toLowerCase();
    return ext.isEmpty ||
        _kAlbumRowArchiveExts.contains(ext) ||
        kContainerFormats.contains(ext);
  }

  // PSF/PSF2 archive formats — individual files, no subsongs, packaged in 7z.
  // Extensions that indicate an archive-album where each file = one track.
  // Includes vgmstream TXTP (text playlists that reference streaming audio).
  static const kPsfFormats = {
    'psf', 'minipsf', 'psf2', 'minipsf2',
    'txtp',
  };

  /// True when [tracks] represent a PSF/TXTP archive album where the server
  /// does NOT know the per-file tracklist — the whole .7z is one row and the
  /// real tracks must be DISCOVERED by extracting + scanning the dir (M3U
  /// order). Only PSF/miniPSF/TXTP: for these the server ships just the archive.
  /// Albums whose server tracklist IS known (RSN spc, vgmstream .ogg, …) are
  /// handled by the reorder-known-tracklist path (downloadAndExtractZip), NOT
  /// here — routing them through downloadPsfAlbum drops files it can't match.
  static bool isPsfArchiveAlbum(List<SearchResult> tracks) {
    if (tracks.isEmpty) return false;
    final fmtExt = tracks.first.formatExt.toLowerCase();
    if (!kPsfFormats.contains(fmtExt)) return false;
    final url = tracks.first.downloadUrl;
    if (url == null) return false;
    const archiveExts = {'7z', 'zip', 'rar', 'gz', 'tar', 'lha', 'lzh', 'xz'};
    return archiveExts.contains(
        p.extension(url).replaceFirst('.', '').toLowerCase());
  }

  /// True when at least one PSF/miniPSF/TXTP file is already in the local dir.
  static Future<bool> isPsfAlbumDownloaded(List<SearchResult> tracks) async {
    if (tracks.isEmpty) return false;
    // Rows rebuilt from a previous extraction carry localPath — the file
    // itself is the proof. The DERIVED dir below can differ from where the
    // archive actually extracted (the rebuild recovers per-file artists from
    // the PSF tags, and the artist is a path segment), and scanning the wrong
    // dir re-downloaded a fully extracted album on play (jw_psf2).
    final lp = tracks.first.localPath;
    if (lp != null && await File(lp).exists()) return true;
    final base = await _baseDir();
    final dir = p.joinAll([base.path, ..._dirSegments(tracks.first)]);
    try {
      // Recursive: psf2 sets often extract into subfolders (+ .psf2lib data);
      // a non-recursive scan misses them and re-downloads on every visit.
      await for (final e in Directory(dir).list(recursive: true)) {
        if (e is! File) continue;
        final ext = p.extension(e.path).replaceFirst('.', '').toLowerCase();
        if (kPsfFormats.contains(ext)) return true;
      }
    } catch (_) {}
    return false;
  }

  /// Downloads the 7z archive and extracts all PSF/miniPSF/psflib files.
  ///
  /// If [tracks] has N > 1 entries (server knows the list): reorders by M3U
  /// and returns the original SearchResult list (server metadata intact).
  ///
  /// If [tracks] has 1 entry with null trackPosition (unknown contents):
  /// builds the track list from the extracted directory + M3U order.
  ///
  /// Set [force] to re-download even if files already exist.
  static Future<List<SearchResult>> downloadPsfAlbum(
    List<SearchResult> tracks, {
    bool force = false,
  }) =>
      BackgroundTask.guard(() async {
        try {
          final res = await _downloadPsfAlbumImpl(tracks, force: force);
          _statusClear();
          return res;
        } on DownloadCancelledException {
          _statusClear();
          rethrow;
        } catch (e) {
          _statusFail(tracks.isEmpty ? 'album' : (tracks.first.album ?? 'album'), e);
          rethrow;
        }
      });

  /// Single entry point that makes an album's real per-track files exist on
  /// disk and returns the tracklist in the archive's true order. Dispatches to
  /// the right extractor (PSF archives need directory scanning + TXTP/M3U track
  /// discovery; RSN/zip albums just reorder a known server tracklist), so
  /// callers don't repeat the branch. Idempotent (skips when already on disk);
  /// returns the input unchanged for plain per-file albums or on any failure.
  /// Persists an album's FULL track list into the local `tracks` table, so the
  /// Favoris auto-playlist — which reads `tracks WHERE meta_album = <refId>` —
  /// lists every track and not only the ones that happened to be PLAYED (the
  /// table is otherwise only fed at play time). Called when an album is
  /// favourited. Container rows carrying the server tracklist (`subsongs`
  /// JSONB, e.g. Wild Arms' 86 entries) are expanded here; each row is keyed by
  /// its canonical library path (localPath when already extracted, else the
  /// deterministic download path) so a later download/play lands on the SAME
  /// row instead of duplicating it. Purely local — no network, no download.
  static Future<void> materializeAlbumTracks(
    String albumName,
    List<SearchResult> rows, {
    String? albumId,
  }) async {
    final expanded = <SearchResult>[];
    for (final r in rows) {
      if (r.subsongs.isNotEmpty) {
        expanded.addAll(subsongRowsFromServer(r));
      } else {
        expanded.add(r);
      }
    }
    var pos = 0;
    var written = 0;
    Object? firstError;
    for (final r in expanded) {
      pos++;
      try {
        var fp = r.localPath;
        var subsongIdx = r.subsongIdx;
        if (fp == null && r.collection == 'snesmusic') {
          // Membre d'un album RSN: l'archive n'est JAMAIS dépliée, le chemin
          // par piste (…/ct-02.spc) n'existera jamais — le dériver écrivait
          // des lignes FANTÔMES qui doublaient chaque piste à la relecture
          // locale de l'album (le vrai jeu de lignes est clé sur le .rsn +
          // rang d'archive, écrit par _rsnResults au téléchargement). Sans
          // mapping en base on n'INVENTE pas: le rang dans l'archive n'est
          // connaissable qu'à l'extraction, et une ligne devinée fausse est
          // pire qu'une ligne absente (materialise n'est qu'un cache).
          final existing = await LocalDb.instance.getTrackByOnlineId(r.songId);
          final ep = existing?.filePath;
          if (ep == null || !ep.toLowerCase().endsWith('.rsn')) continue;
          fp = ep;
          subsongIdx = existing!.subsongIdx;
        }
        fp ??= await _localPath(r);
        await LocalDb.instance.upsertTrack(
          filePath:   fp,
          subsongIdx: subsongIdx,
          title:      r.displayTitle,
          artist:     r.artistNames.isNotEmpty ? r.artistNames.first : null,
          metaAlbum:  albumName,
          position:   r.trackPosition ?? pos,
          durationS:  r.durationMs != null ? r.durationMs! / 1000.0 : null,
          formatExt:  r.formatExt,
          source:     'online',
          onlineId:   r.songId,
          albumId:    albumId ?? r.albumId,
          artworkUrl: r.artworkUrl,
          // Origin recorded up front (mig 52): the server row knows it, and a
          // track materialised here may be replayed long before it is ever
          // played once — nothing else would tell the player where it is from.
          collectionSlug: r.collection,
          platformName:   r.platform,
          year:           r.year,
        );
        written++;
      } catch (e) {
        // Une mauvaise ligne ne doit pas couler le lot — mais un lot ENTIER qui
        // échoue en silence est ce qui a laissé trois albums favoris marqués
        // « liste complète » avec zéro ligne écrite (Wild Arms: marqueur 86,
        // tracks 0), donc invisibles dans la playlist Favoris pour toujours.
        firstError ??= e;
      }
    }
    if (written < expanded.length) {
      debugPrint('[RewampDb] materialise "$albumName": $written/'
          '${expanded.length} ligne(s) écrite(s) — 1re erreur: $firstError');
    }
    // Marqueur « liste complète reçue » (mig locale 47): le rattrapage des
    // albums favoris ne peut pas le déduire des lignes présentes, une seule
    // piste jouée en crée une.
    //
    // Posé SEULEMENT sur un lot COMPLET: le marqueur dit « inutile de
    // redemander », et le poser sur une liste partielle la fige — c'est
    // exactement la faute que la mig 47 corrigeait (« plus d'une piste =
    // complet »), refaite ici par un autre chemin. Un lot raté laisse l'album
    // au rattrapage, qui le reprendra à la passe suivante.
    final id = albumId ?? (rows.isNotEmpty ? rows.first.albumId : null);
    if (id != null && id.isNotEmpty && written == expanded.length) {
      await LocalDb.instance.markAlbumMaterialised(id, expanded.length);
    }
    LocalDb.instance.notifyBatchChanged();
  }

  static Future<List<SearchResult>> ensureAlbumExtracted(
    List<SearchResult> songs, {
    bool force = false,
  }) async {
    if (songs.isEmpty) return songs;
    try {
      // Container row with a SERVER-KNOWN tracklist (`tracks` JSONB → subsongs):
      // the whole archive is one row but the server ships the exact ordered,
      // mixed file list (e.g. Wild Arms = 66 .psf + 17 .ogg + 3 .xa). Use it
      // directly (extract + map to the server list) so EVERY file is kept.
      // downloadPsfAlbum must NOT be used here — it re-discovers from the
      // archive and drops files it can't classify (the .ogg/.xa vanished).
      if (songs.length == 1 && songs.first.subsongs.isNotEmpty) {
        return await expandContainerAlbum(songs.first);
      }
      // A HETEROGENEOUS list (a playlist mixing albums) must NEVER be treated
      // as one album's tracklist: the zip/PSF branches below extract the FIRST
      // row's album and would map EVERY row — whatever its album — onto that
      // archive, with its list position as subsong rank. That is exactly what
      // played the wrong tracks for a community RSN playlist (each entry wrote
      // its PLAYLIST rank as the .rsn subsong, keyed to the first album's
      // file). Per-track handling at play time resolves each row correctly.
      if (songs.any((s) =>
          s.album != songs.first.album ||
          s.collection != songs.first.collection)) {
        return songs;
      }
      // PSF archive with NO server tracklist — must discover by extracting +
      // scanning the dir (M3U order). Runs even for songs.length == 1.
      if (isPsfArchiveAlbum(songs)) {
        return await downloadPsfAlbum(songs, force: force);
      }
      if (songs.length < 2) return songs;
      final first = songs.first;
      // Non-PSF album packaged as a zip/7z (RSN spc, vgmstream .ogg, SID zip, …):
      // the server DOES know the tracklist (N rows), so extract the archive and
      // reorder the known rows to match its contents — keeping every file.
      // Mirrors AlbumDetailScreen: gate on the album's zipUrl, NOT on the track
      // download_url (which, for these, IS the .7z and is non-null).
      if (first.album != null &&
          (force || !await File(await _localPath(first)).exists())) {
        final details = await fetchAlbumDetails(
          first.album!,
          collectionSlug: first.collection,
          platformName:   first.platform,
        );
        final zipUrl    = details.isNotEmpty ? details.first.zipUrl : null;
        final mirrorZip = details.isNotEmpty ? details.first.mirrorZipUrl : null;
        if (zipUrl != null) {
          final reordered =
              await downloadAndExtractZip(zipUrl, songs,
                  mirrorZipUrl: mirrorZip, force: force);
          if (reordered != null) return reordered;
        }
      }
    } on DownloadCancelledException {
      rethrow; // the user aborted the whole album, not just its zip
    } catch (_) {/* per-track download fallback happens at play time */}
    return songs;
  }

  static Future<List<SearchResult>> _downloadPsfAlbumImpl(
    List<SearchResult> tracks, {
    bool force = false,
  }) async {
    if (tracks.isEmpty) return tracks;

    // Extraction dir: the first row's REAL file when it has one (rows rebuilt
    // from a previous extraction), else the derived path. Deriving from a
    // rebuilt row lands in a different dir when its artist came from the PSF
    // tag rather than the server album row — see isPsfAlbumDownloaded.
    //
    // force = « Re-télécharger l'album »: TOUJOURS le chemin DÉRIVÉ (le layout
    // canonique du moment — par album-id depuis qu'il existe), jamais le
    // vieux localPath des lignes: réutiliser l'ancien dossier faisait du
    // re-téléchargement un no-op (les fichiers existaient → tout était
    // sauté) et laissait l'album éparpillé dans ses anciens dossiers artiste.
    final lp = tracks.first.localPath;
    final firstPath = (!force && lp != null && await File(lp).exists())
        ? lp
        : await _localPath(tracks.first);
    final audioDir  = p.dirname(firstPath);
    await Directory(audioDir).create(recursive: true);

    if (force || !await isPsfAlbumDownloaded(tracks)) {
      await _withDirLock(audioDir, () async {
        if (force) {
          // Copie neuve: cible vidée (artwork gardé), et les ANCIENNES copies
          // (dossiers artiste d'avant la migration album-id) purgées — lignes
          // DB comprises, sinon le repli « reusing » continue d'y renvoyer.
          final containerId = tracks.first.songId.split('#').first;
          final anchors = <String>{
            p.basename(audioDir).toLowerCase(),
            if (tracks.first.album != null && tracks.first.album!.isNotEmpty)
              _sanitize(tracks.first.album!).toLowerCase(),
            if (tracks.first.albumId != null &&
                tracks.first.albumId!.isNotEmpty)
              tracks.first.albumId!.toLowerCase(),
          };
          await _wipeAlbumDirs(
            {audioDir, ...await _albumCopyDirs(containerId, anchors)},
            // « Re-télécharger » = « ce que j'ai est périmé »: la pochette
            // aussi. Le ♥ et l'appartenance à la bibliothèque, eux, restent.
            keepArtwork: false,
            keepUserState: true,
          );
        }
        final origin     = tracks.first.downloadUrl!;
        // force = « Re-télécharger »: la raison d'être du geste est que le
        // contenu a changé sous la même url — contourner l'edge CDN, sinon on
        // re-télécharge fidèlement la copie périmée qu'on voulait remplacer.
        final (_, sharedPath) = await _fetchArchiveShared(null, origin,
            label: '${tracks.first.album ?? p.basename(origin)} (album)',
            expectedSize: tracks.first.fileSize,
            cap: const Duration(minutes: 10),
            // force = « Re-télécharger »: la raison d'être du geste est que le
            // contenu a changé sous la même url — contourner l'edge CDN ET le
            // tampon local, sinon on re-sert la copie périmée qu'on remplace.
            bustCache: force);
        final (rc, err) = await _extractArchiveOffThread(sharedPath, audioDir);
        if (rc != 0) {
          throw Exception('PSF archive extraction failed (rc=$rc): $err');
        }
      });
    }

    // Scan the dir recursively.
    // - Primary tracks: PSF/miniPSF/TXTP files (one file = one track, no subsongs)
    // - TXTP files are parsed to extract the basenames of the audio files they
    //   reference (e.g. "movies/cc_0001.vgmstream") so those are NOT added
    //   as standalone tracks.
    // - Any other audio file NOT referenced by a TXTP is added as a standalone track.
    // - First M3U/M3U8 found is used for ordering when the server knows the tracklist.
    const kStandaloneAudioExts = {
      'adx', 'hca', 'at9', 'at3', 'aa3',
      'dsp', 'brstm', 'bcstm', 'bfstm', 'bcwav', 'bfwav',
      'xma', 'xwb', 'xwm', 'fsb', 'vgmstream', 'genh',
      'txth',
      'wav', 'flac', 'ogg', 'mp3',
    };

    String? m3uContent;
    int m3uBestEntries = -1;   // regular playlist with the most entries wins
    String? m3uTagsContent; // vgmstream !tags.m3u — playlist of last resort
    final trackFiles      = <File>[];         // txtp + psf → direct tracks
    final referencedNames = <String>{};       // basenames referenced inside txtp files
    final candidateAudio  = <File>[];         // other audio files (may be standalone)

    try {
      await for (final e in Directory(audioDir).list(recursive: true)) {
        if (e is! File) continue;
        final base = p.basename(e.path);
        if (base.startsWith('_tmp_archive')) continue;
        if (base.startsWith('.')) continue; // skip hidden files (.vgmstream.txth etc.)
        final ext = p.extension(e.path).replaceFirst('.', '').toLowerCase();
        if (ext == 'm3u' || ext == 'm3u8') {
          if (_isTagsM3uName(base)) {
            m3uTagsContent ??= await readM3uText(e);
          } else {
            // Keep the regular playlist with the most entries; the rest are
            // complementary metadata only.
            final text = await readM3uText(e);
            final n = _countM3uEntries(text);
            if (n > m3uBestEntries) {
              m3uBestEntries = n;
              m3uContent = text;
            }
          }
        } else if (kPsfFormats.contains(ext)) {
          trackFiles.add(e);
          if (ext == 'txtp') {
            // Parse TXTP: lines are `filename #options` or `##comment` or blank.
            try {
              final content = await readM3uText(e);
              for (final line in content.split('\n')) {
                final t = line.trim();
                if (t.isEmpty || t.startsWith('##')) continue;
                final filename = t.split('#').first.trim();
                if (filename.isNotEmpty) {
                  referencedNames.add(p.basename(filename).toLowerCase());
                }
              }
            } catch (_) {}
          }
        } else if (kStandaloneAudioExts.contains(ext)) {
          candidateAudio.add(e);
        }
      }
    } catch (_) {}

    // Add audio files not already referenced by any TXTP.
    for (final f in candidateAudio) {
      if (!referencedNames.contains(p.basename(f.path).toLowerCase())) {
        trackFiles.add(f);
      }
    }

    // A lone !tags.m3u doubles as the playlist (file lines are plain names).
    m3uContent ??= m3uTagsContent;
    // Per-file %TITLE overlay from the vgmstream tag file, when present.
    final tagsTitles = m3uTagsContent != null
        ? _parseTagsM3uTitles(m3uTagsContent)
        : const <String, String>{};

    // Known track list (N > 1 OR single with trackPosition set): reorder only.
    final placeholder =
        tracks.length == 1 && tracks.first.trackPosition == null;
    if (!placeholder) {
      if (m3uContent != null) return _applyM3UOrder(m3uContent, tracks);
      return tracks;
    }

    // Unknown contents: build list from extracted files.
    trackFiles.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    // Apply M3U order if present.
    if (m3uContent != null) {
      final ordered = <File>[];
      final used    = <String>{};
      final byName  = <String, File>{
        for (final f in trackFiles) p.basename(f.path).toLowerCase(): f,
      };
      for (final raw in m3uContent.split('\n')) {
        final line = raw.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final key = p.basename(line).toLowerCase();
        final f   = byName[key];
        if (f != null && used.add(key)) ordered.add(f);
      }
      for (final f in trackFiles) {
        if (used.add(p.basename(f.path).toLowerCase())) ordered.add(f);
      }
      if (ordered.isNotEmpty) {
        trackFiles
        ..clear()
        ..addAll(ordered);
      }
    }

    final tmpl = tracks.first;
    // When the album/M3U gives no artist, recover it per file from the PSF tag
    // ([TAG] section, "artist=" line) so it shows + persists in the local DB.
    final albumHasArtist = tmpl.artistNames.isNotEmpty;

    final results = <SearchResult>[];
    for (int i = 0; i < trackFiles.length; i++) {
      final ext = p.extension(trackFiles[i].path).replaceFirst('.', '').toLowerCase();
      var artists = tmpl.artistNames;
      if (!albumHasArtist &&
          const {'psf', 'minipsf', 'psf2', 'minipsf2'}.contains(ext)) {
        final a = await _psfTagArtists(trackFiles[i].path);
        if (a.isNotEmpty) artists = a;
      }
      results.add(SearchResult(
        songId:        '${tmpl.songId}#$i',
        collection:    tmpl.collection,
        title:         tagsTitles[p.basename(trackFiles[i].path).toLowerCase()] ??
                       p.basenameWithoutExtension(trackFiles[i].path),
        filename:      p.basename(trackFiles[i].path),
        album:         tmpl.album ?? tmpl.displayTitle,
        // Keep the server album id on the synthetic rows — without it the
        // player's "Voir l'album" link dies after a re-download.
        albumId:       tmpl.albumId,
        formatExt:     p.extension(trackFiles[i].path).replaceFirst('.', ''),
        downloadUrl:   tmpl.downloadUrl,
        fileSize:      tmpl.fileSize,
        year:          tmpl.year,
        artistNames:   artists,
        totalCount:    trackFiles.length,
        platform:      tmpl.platform,
        rating:        tmpl.rating,
        artworkUrl:    tmpl.artworkUrl,
        trackPosition: i + 1,
        subsongIdx:    0,
        durationMs:    tmpl.durationMs,
        localPath:     trackFiles[i].path,
      ));
    }
    return results;
  }

  /// Reads the "artist" tag(s) from a PSF/PSF2 file's `[TAG]` section
  /// (key=value lines at the end). ⚠️ Ces lignes ne sont PAS de l'UTF-8: un tag
  /// PSF est du Shift-JIS sauf `utf8=`. Décodées ici en `utf8.decode(allowMalformed)`
  /// jusqu'au 2026-09-21, elles donnaient des U+FFFD (mesuré sur les octets
  /// de `平田 祥一郎`). Voir legacy_text.dart.
  /// A single tag may list several artists
  /// separated by comma / `;` / `&` — each becomes a distinct entry.
  /// Returns an empty list if absent.
  static Future<List<String>> _psfTagArtists(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      // [TAG] marker = 0x5B 0x54 0x41 0x47 0x5D; search from the end.
      int idx = -1;
      for (int i = bytes.length - 5; i >= 0; i--) {
        if (bytes[i] == 0x5B && bytes[i + 1] == 0x54 && bytes[i + 2] == 0x41 &&
            bytes[i + 3] == 0x47 && bytes[i + 4] == 0x5D) {
          idx = i + 5;
          break;
        }
      }
      if (idx < 0) return const [];
      final tag = decodeFileText(bytes.sublist(idx));
      final out  = <String>[];
      final seen = <String>{};
      for (final line in tag.split('\n')) {
        final eq = line.indexOf('=');
        if (eq <= 0) continue;
        if (line.substring(0, eq).trim().toLowerCase() != 'artist') continue;
        final raw = line.substring(eq + 1);
        for (final part in raw.split(RegExp(r'\s*[,;]\s*|\s*&\s*'))) {
          final n = part.trim();
          if (n.isEmpty || n.toLowerCase() == 'null') continue;
          if (seen.add(n)) out.add(n);
        }
      }
      return out;
    } catch (_) {}
    return const [];
  }

  /// Parses an M3U/M3U8 string and resolves track paths against [dir].
  ///
  /// Handles two line formats:
  ///  1. Modland extended:  `file.nsf::NSF,1,Title,duration_ms[,loop_ms]`
  ///  2. Standard extended: `#EXTINF:duration_sec,Title` followed by filename
  ///
  /// Returns one [SubsongInfo] per playable entry.
  /// Parses an M3U duration field into milliseconds.  Handles:
  /// - `H:MM:SS.mmm` / `M:SS.mmm` / `MM:SS` (joshw nsfe2m3u format)
  /// - plain integer milliseconds (Modland style)
  /// Returns null for empty / zero / unparseable values.
  static int? _parseM3uDuration(String s) {
    s = s.trim();
    if (s.isEmpty) return null;

    if (s.contains(':')) {
      final parts = s.split(':');
      double total = 0;
      for (final part in parts) {
        total = total * 60 + (double.tryParse(part) ?? 0);
      }
      final ms = (total * 1000).round();
      return ms > 0 ? ms : null;
    }

    // Plain number: treat large values as ms, small as seconds.
    final n = double.tryParse(s);
    if (n == null || n <= 0) return null;
    return n > 1000 ? n.round() : (n * 1000).round();
  }

  /// Extracts year from joshw M3U header.
  /// Handles:
  ///   `# @DATE        YYYY[-MM[-DD]]`   (GBS)
  ///   `# Copyright YYYY <company>`      (NSF/joshw_nes)
  static int? _parseM3uYear(String m3u) {
    final patterns = [
      RegExp(r'^#\s*@DATE\s+(\d{4})',           caseSensitive: false),
      RegExp(r'^#\s*Copyright\s+(\d{4})\b',     caseSensitive: false),
    ];
    for (final line in m3u.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      for (final re in patterns) {
        final m = re.firstMatch(t);
        if (m != null) return int.tryParse(m.group(1)!);
      }
    }
    return null;
  }

  /// Extracts artist list from joshw M3U header comments.
  /// Handles:
  ///   `# Music by <artist[, artist]>`        (NSF/NSFE)
  ///   `# @COMPOSER    <artist[, artist]>`    (GBS and others)
  ///   `#EXTART:` / `# Composer(s):`          (M3U étendu, rips faits main)
  ///
  /// ⚠️ Les DEUX vocabulaires: `# @TAG valeur` (séparateur ESPACE, vgmstream)
  /// et `#DIRECTIVE:valeur` (séparateur `:`, M3U étendu). Les rips soignés
  /// écrivent le second, et rien ne le lisait — voir m3u_info.dart.
  static List<String> _parseM3uArtists(String m3u) {
    final fromHeader = parseM3uInfo(m3u).artists;
    if (fromHeader.isNotEmpty) return fromHeader;
    final re = RegExp(
      r'^#\s*(?:Music\s+by|@COMPOSER|@ARTIST)\s+(.+)',
      caseSensitive: false,
    );
    for (final line in m3u.split(RegExp(r'\r?\n'))) {
      final m = re.firstMatch(line.trim());
      if (m != null) {
        final raw = m.group(1)!.trim();
        if (raw.isEmpty) continue;
        final parts = raw
            .split(',')
            .map((s) => s.trim()
                .replaceFirst(RegExp(r'^and\s+', caseSensitive: false), '')
                .replaceFirst(RegExp(r'^&\s+'), '')
                .trim())
            .where((s) => s.isNotEmpty)
            .toList();
        return parts.isNotEmpty ? parts : [raw];
      }
    }
    return [];
  }

  /// Splits [s] by commas, treating `\,` as a literal comma within a field.
  static List<String> _splitEscapedCsv(String s) {
    final result = <String>[];
    final buf    = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (s[i] == r'\' && i + 1 < s.length && s[i + 1] == ',') {
        buf.write(',');
        i++;
      } else if (s[i] == ',') {
        result.add(buf.toString());
        buf.clear();
      } else {
        buf.write(s[i]);
      }
    }
    result.add(buf.toString());
    return result;
  }

  /// Formats dont le numéro de chanson d'un rip joshw est un numéro ABSOLU du
  /// driver — jamais une position dans la playlist.
  ///
  /// Les deux arrivent sous la même forme (`fichier.ext::FORMAT,$hex,…`), donc
  /// seul le FORMAT permet de trancher. Une POSITION se normalise (retirer 1
  /// quand la liste commence à 1, comme NSF); un numéro ABSOLU se passe tel
  /// quel au moteur, et lui retirer 1 joue une chanson trop bas.
  ///
  /// - famille KSS: le nombre part à `KSSPLAY_reset` (Vampire Killer liste
  ///   128..142);
  /// - NEZplug++ (`.hes`, `.sgc`): le greffon fait `NEZSetSongNo(subsong + 1)`,
  ///   comme Modizer fait `NEZSetSongNo(index_m3u + 1)` — le M3U porte donc
  ///   déjà le numéro que le moteur attend. Mesuré sur « 1941: Counter Attack »
  ///   (jw_hes): index de `$3E` (62) à `$65` (101), sans `$00`, donc rien qui
  ///   ressemble à une position; la 2e piste doit lancer la chanson 77 et
  ///   lançait la 76.
  ///
  /// ⚠️ Deux endroits appliquent cette règle — le M3U local
  /// ([parseM3uToSubsongs]) et la tracklist serveur ([subsongRowsFromServer]),
  /// qui republie le même numéro. Les séparer, c'est un album importé qui joue
  /// juste et le même album téléchargé qui joue décalé.
  static const kAbsoluteSongNumberExts = {
    'kss', 'mgs', 'bgm', 'mpk', 'mbm', 'opx', 'mus',   // libkss
    'hes', 'sgc',                                      // NEZplug++
  };

  static List<SubsongInfo> parseM3uToSubsongs(String m3u, String dir) {
    final lines  = m3u.split(RegExp(r'\r?\n'));
    String? pendingTitle;
    int?    pendingDurationMs;

    // First pass: collect raw (path, rawSubsong, title, durationMs) tuples.
    // We defer the 0-based / 1-based decision until we've seen all entries.
    final raw = <({String path, int rawSub, String? title, int? durationMs})>[];

    for (var line0 in lines) {
      final line = line0.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        final rest  = line.substring(8);
        final comma = rest.indexOf(',');
        if (comma >= 0) {
          final secStr = rest.substring(0, comma).trim();
          final sec    = double.tryParse(secStr);
          pendingDurationMs = (sec != null && sec > 0) ? (sec * 1000).round() : null;
          pendingTitle      = rest.substring(comma + 1).trim();
          if (pendingTitle.isEmpty) pendingTitle = null;
        }
        continue;
      }

      if (line.startsWith('#')) {
        // vgmstream !tags.m3u local tag: "# %TITLE <text>" applies to the
        // NEXT file line (see vgmstream doc/USAGE.md#tagging). Other tag
        // comments (@GLOBALs, %ARTIST…) are handled by dedicated parsers.
        final tag = RegExp(r'^#\s*%\s*TITLE%?\s+(.+)$', caseSensitive: false)
            .firstMatch(line);
        if (tag != null) {
          final t = tag.group(1)!.trim();
          if (t.isNotEmpty) pendingTitle = t;
        }
        continue;
      }

      // Modland format: path[::FORMAT,subsong,title,duration_ms[,...]]
      // The subsong field may be 0-based or 1-based depending on the source.
      String filePart  = line;
      int    rawSub    = -1; // sentinel = no explicit subsong in this entry
      String? inlineTitle;
      int?    inlineDurationMs;

      final doubleColon = line.indexOf('::');
      if (doubleColon >= 0) {
        filePart = line.substring(0, doubleColon);
        // joshw format uses \, to escape literal commas inside fields
        // (e.g. artist names). Split respecting the escape.
        final meta = _splitEscapedCsv(line.substring(doubleColon + 2));
        if (meta.length >= 2) {
          // joshw uses hex subsong indices with a '$' prefix ("$00", "$1a").
          final rawStr = meta[1].trim();
          rawSub = rawStr.startsWith('\$')
              ? (int.tryParse(rawStr.substring(1), radix: 16) ?? -1)
              : (int.tryParse(rawStr) ?? -1);
        }
        if (meta.length >= 3) {
          inlineTitle = meta[2].trim();
          if (inlineTitle.isEmpty) inlineTitle = null;
        }
        if (meta.length >= 4) {
          inlineDurationMs = _parseM3uDuration(meta[3].trim());
        }
      }

      final absPath = p.isAbsolute(filePart)
          ? filePart
          : p.join(dir, _sanitize(p.basename(filePart)));

      raw.add((
        path:       absPath,
        rawSub:     rawSub,
        title:      inlineTitle ?? pendingTitle,
        durationMs: inlineDurationMs ?? pendingDurationMs,
      ));

      pendingTitle      = null;
      pendingDurationMs = null;
    }

    if (raw.isEmpty) return [];

    // Determine subsong offset: if any entry has an explicit rawSub == 0 it is
    // already 0-based; otherwise assume 1-based and subtract 1.
    final hasExplicit = raw.any((e) => e.rawSub >= 0);
    final minRaw      = hasExplicit
        ? raw.where((e) => e.rawSub >= 0).map((e) => e.rawSub).reduce((a, b) => a < b ? a : b)
        : 1; // treat absent indices as 1-based (offset 1)
    // Numéro ABSOLU du driver ⇒ on ne retire rien (voir
    // kAbsoluteSongNumberExts). Sinon c'est une position: 1-based ⇒ −1.
    final firstExt = p.extension(raw.first.path).replaceFirst('.', '').toLowerCase();
    final offset   = kAbsoluteSongNumberExts.contains(firstExt)
        ? 0
        : (minRaw == 0 ? 0 : 1);

    // Sequential fallback indices only make sense when every entry targets the
    // SAME file (a subsong list). In a multi-file playlist (jw_hes: .hes
    // subsongs + standalone .ape lines) an index-less entry is a whole file →
    // subsong 0.
    final distinctFiles = raw.map((e) => e.path.toLowerCase()).toSet().length;

    final result = <SubsongInfo>[];
    for (final e in raw) {
      final subsongIdx = e.rawSub >= 0
          ? e.rawSub - offset
          : (distinctFiles > 1 ? 0 : result.length);
      result.add(SubsongInfo(
        index:      result.length,
        filePath:   e.path,
        subsongIdx: subsongIdx < 0 ? 0 : subsongIdx,
        title:      e.title,
        durationMs: e.durationMs,
      ));
    }

    return result;
  }

  /// basename(lowercase) → `# %TITLE` mapping from a vgmstream `!tags.m3u`
  /// (local tags apply to the NEXT file line — doc/USAGE.md#tagging).
  static Map<String, String> _parseTagsM3uTitles(String content) {
    final out = <String, String>{};
    String? pending;
    for (final raw in content.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) {
        final m = RegExp(r'^#\s*%\s*TITLE%?\s+(.+)$', caseSensitive: false)
            .firstMatch(line);
        if (m != null) pending = m.group(1)!.trim();
        continue;
      }
      if (pending != null && pending.isNotEmpty) {
        out[p.basename(line).toLowerCase()] = pending;
      }
      pending = null;
    }
    return out;
  }

  /// Given a local audio file path, looks for an M3U alongside it and
  /// parses it. Returns subsong list, or null if no M3U / empty result.
  /// L'en-tête du M3U voisin de [audioPath] — album, artistes, éditeur, année,
  /// sources. null quand le fichier n'a pas de playlist à côté.
  ///
  /// Un rip LOCAL n'a aucune ligne serveur: son M3U est la seule chose qui
  /// sache le nom de l'album et ses compositeurs. Voir m3u_info.dart.
  static Future<M3uInfo?> localM3uInfo(String audioPath,
      {M3uLookupCache? cache}) async {
    try {
      final dir = p.dirname(audioPath);
      final m3u = await _findM3uForFile(dir, audioPath, cache: cache);
      if (m3u == null) return null;
      if (cache != null && cache.info.containsKey(m3u.path)) {
        return cache.info[m3u.path];
      }
      final content = cache?.text[m3u.path] ?? await readM3uText(m3u);
      if (cache != null) cache.text[m3u.path] = content;
      final parsed = parseM3uInfo(content);
      final info = parsed.isEmpty ? null : parsed;
      if (cache != null) cache.info[m3u.path] = info;
      return info;
    } catch (_) {
      return null;
    }
  }

  /// L'entrée du M3U voisin qui désigne EXACTEMENT [audioPath], quand il n'y
  /// en a qu'une. null sinon.
  ///
  /// « Qu'une seule » est la garde qui compte: un fichier listé PLUSIEURS fois
  /// est un conteneur dont le M3U décrit les sous-chansons, et ce chemin-là a
  /// déjà son traitement (`m3uSubsongsFor`). Ici on ne vise que le cas d'un
  /// M3U d'ALBUM qui nomme chacun de ses fichiers une fois.
  static Future<SubsongInfo?> localM3uEntryFor(String audioPath,
      {M3uLookupCache? cache}) async {
    try {
      final subs = await probeLocalM3u(audioPath, cache: cache);
      if (subs == null) return null;
      final want = p.basename(audioPath).toLowerCase();
      final mine = [
        for (final s in subs)
          if (p.basename(s.filePath).toLowerCase() == want) s
      ];
      return mine.length == 1 ? mine.first : null;
    } catch (_) {
      return null;
    }
  }

  static Future<List<SubsongInfo>?> probeLocalM3u(String audioPath,
      {M3uLookupCache? cache}) async {
    final dir = p.dirname(audioPath);
    final m3u = await _findM3uForFile(dir, audioPath, cache: cache);
    if (m3u == null) return null;
    if (cache != null) {
      // Un même M3U sert TOUS les fichiers de son dossier: lu et parsé une fois.
      final hit = cache.subs[m3u.path];
      if (hit != null) return hit.isNotEmpty ? hit : null;
      final content = cache.text[m3u.path] ??= await readM3uText(m3u);
      final subs = cache.subs[m3u.path] = parseM3uToSubsongs(content, dir);
      return subs.isNotEmpty ? subs : null;
    }
    final content = await readM3uText(m3u);
    final subs    = parseM3uToSubsongs(content, dir);
    return subs.isNotEmpty ? subs : null;
  }

  /// Unified probe entry point. Given a downloaded local [path]:
  ///
  /// - **Archive** (zip/7z/rar): extracts to a temp dir if not already
  ///   extracted, finds the first M3U, parses it → [SubsongInfo] list.
  ///   Falls back to C probe if no M3U is found.
  /// - **Single music file**: delegates to [RewampAudio.probeSubsongs].
  ///
  /// Returns an empty list on failure.
  static Future<List<SubsongInfo>> probeContainerFile(String path) async {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    const archiveExts = {'zip', '7z', 'gz', 'tar', 'lha', 'lzh'};

    if (archiveExts.contains(ext)) {
      return _probeArchive(path);
    }

    // Single music file (e.g. extracted .nsf). Prefer an accompanying M3U in the
    // same directory (joshw ships file.nsf + file.m3u listing the subsongs);
    // fall back to the C probe (libgme track count + per-track metadata).
    final dir  = p.dirname(path);
    final m3u  = await _findM3uForFile(dir, path);
    if (m3u != null) {
      final content = await readM3uText(m3u);
      final subs    = parseM3uToSubsongs(content, dir);
      if (subs.isNotEmpty) return subs;
    }
    return RewampAudio().probeSubsongs(path);
  }

  /// True for a vgmstream-style `!tags.m3u` (dual tags/playlist file — used
  /// as the playlist only when no regular M3U exists).
  static bool _isTagsM3uName(String path) =>
      p.basename(path).toLowerCase() == '!tags.m3u';

  /// Reads an M3U / tag file tolerant of non-UTF-8 encodings — joshw playlists
  /// are frequently Shift-JIS, and `File.readAsString()` (UTF-8) throws on the
  /// first invalid byte (crash: "Failed to decode data using encoding
  /// 'utf-8'").
  ///
  /// ⚠️ Le repli était Latin-1, justifié par « les titres viennent de toute
  /// façon du serveur ». Faux deux fois: les titres `%TITLE` d'un `!tags.m3u`
  /// SONT affichés, et un import local n'a pas de serveur. Et Latin-1 sur du
  /// Shift-JIS fait des octets 0x80–0x9F des contrôles C1 — sans glyphe, donc
  /// des RECTANGLES. Même règle que les tags du moteur désormais: voir
  /// legacy_text.dart.
  static Future<String> readM3uText(File f) async =>
      decodeFileText(await f.readAsBytes());

  /// Number of playable entries in an M3U (non-blank, non-comment lines).
  /// `#EXTINF`/`# %TAG` metadata lines don't count — one path line per track.
  static int _countM3uEntries(String content) {
    var n = 0;
    for (final raw in content.split('\n')) {
      final l = raw.trim();
      if (l.isEmpty || l.startsWith('#')) continue;
      n++;
    }
    return n;
  }

  /// Picks THE playlist M3U from a set of candidates, per the archive rule:
  /// among the regular (non `!tags.m3u`) playlists, the one with the MOST
  /// entries wins; the others are complementary metadata only. A `!tags.m3u`
  /// is chosen as the playlist solely when no regular M3U exists (it then
  /// doubles as the track list). [stemForTie] (an audio basename sans ext),
  /// when given, breaks ties in favour of the M3U named like the audio file.
  /// Returns null when [m3us] is empty.
  static Future<File?> _pickPlaylistM3u(List<File> m3us,
      {String? stemForTie, M3uLookupCache? cache}) async {
    File? best;
    var bestN = -1;
    File? tags;
    for (final f in m3us) {
      if (_isTagsM3uName(f.path)) {
        tags ??= f;
        continue;
      }
      final n = cache == null
          ? _countM3uEntries(await readM3uText(f))
          : (cache.entryCount[f.path] ??=
              _countM3uEntries(cache.text[f.path] ??= await readM3uText(f)));
      final isStem = stemForTie != null &&
          p.basenameWithoutExtension(f.path).toLowerCase() == stemForTie;
      // Strictly more entries wins; on a tie, the stem-matching M3U wins.
      if (n > bestN || (n == bestN && isStem)) {
        bestN = n;
        best = f;
      }
    }
    return best ?? tags;
  }

  /// Finds the playlist M3U/M3U8 in [dir]. Among regular playlists the one with
  /// the MOST entries wins (ties broken toward the M3U named like [audioPath]);
  /// a `!tags.m3u` (vgmstream tagging file) is used only as LAST resort — when
  /// it is the only M3U in a joshw 7z it doubles as the playlist.
  static Future<File?> _findM3uForFile(String dir, String audioPath,
      {M3uLookupCache? cache}) async {
    final stem = p.basenameWithoutExtension(audioPath).toLowerCase();
    var m3us = cache?.m3usByDir[dir];
    if (m3us == null) {
      m3us = <File>[];
      await for (final e in Directory(dir).list(recursive: false)) {
        if (e is! File) continue;
        final ext = p.extension(e.path).replaceFirst('.', '').toLowerCase();
        if (ext == 'm3u' || ext == 'm3u8') m3us.add(e);
      }
      cache?.m3usByDir[dir] = m3us;
    }
    return _pickPlaylistM3u(m3us, stemForTie: stem, cache: cache);
  }

  static Future<List<SubsongInfo>> _probeArchive(String path) async {
    final dir = p.dirname(path);

    // Find an already-extracted audio dir alongside the archive.
    // (downloadAndExtractZip writes files next to / in the same dir.)
    final m3uCandidates = await Directory(dir)
        .list(recursive: false)
        .where((e) {
          final ext = p.extension(e.path).replaceFirst('.', '').toLowerCase();
          return e is File && (ext == 'm3u' || ext == 'm3u8');
        })
        .cast<File>()
        .toList();

    if (m3uCandidates.isNotEmpty) {
      // Regular playlist with the most entries; a lone !tags.m3u doubles as it.
      final chosen = await _pickPlaylistM3u(m3uCandidates);
      if (chosen != null) {
        final content = await readM3uText(chosen);
        final subs    = parseM3uToSubsongs(content, dir);
        if (subs.isNotEmpty) return subs;
      }
    }

    // No M3U found — try C probe on any music file in the dir.
    final audio = await Directory(dir)
        .list(recursive: false)
        .where((e) {
          final ext = p.extension(e.path).replaceFirst('.', '').toLowerCase();
          return e is File && kContainerFormats.contains(ext);
        })
        .cast<File>()
        .toList();

    if (audio.isEmpty) return const [];
    return RewampAudio().probeSubsongs(audio.first.path);
  }

  /// True when a container album's audio is already on disk (either the file
  /// itself or extracted from its wrapping archive). Pure disk check — lets
  /// the album screen show a "download to see the tracks" placeholder instead
  /// of fetching the archive just by opening the screen.
  static Future<bool> isContainerDownloaded(SearchResult r) async {
    final localPath = await _localPath(r);
    // Tracklist serveur connue → « téléchargé » signifie que SES fichiers
    // sont sur disque, pas « le dossier contient quelque chose d'audio »:
    // après un remplacement d'album côté serveur, le dossier porte l'ANCIENNE
    // extraction, et répondre oui faisait déclencher à l'écran album un
    // téléchargement complet juste pour LISTER les pistes (le préview serveur
    // suffit et ne coûte rien).
    if (r.subsongs.isNotEmpty) {
      final first = r.subsongs.first.file;
      if (first != null && first.isNotEmpty) {
        return File(p.joinAll(
                [p.dirname(localPath), ..._fileSegments(first)]))
            .exists();
      }
    }
    if (await File(localPath).exists()) return true;
    final found = await _findExtractedAudio(p.dirname(localPath), r.formatExt,
        preferStem: _archiveStem(r));
    return found != null;
  }

  /// Given a container [container] SearchResult (a single multi-subsong file
  /// such as a joshw NSF wrapped in a 7z), downloads + extracts the file,
  /// probes its subsongs, and returns one SearchResult per M3U entry. Entries
  /// may point at OTHER extracted files (joshw jw_hes ships .hes + .ape CD
  /// rips in one 7z): those rows carry their own filename/format/localPath
  /// and subsong 0, not the container's.
  /// Builds the per-track rows of a container album straight from the server
  /// `tracks` tracklist — no probe. Same row shape + `songId` scheme
  /// (`<container>#<i>`) as [expandContainerAlbum], so the pre-download preview
  /// and the post-download expansion are identical (tap → play resolves by
  /// songId).
  ///
  /// Two kinds of entry (see the server `tracks` doc):
  ///  - WITH `subsong`  → a subsong of ONE file (NSF/GBS): all such rows share
  ///    the same file, differing by `subsongIdx`.
  ///  - WITHOUT `subsong` → a distinct whole FILE inside the archive (GSF/2SF/
  ///    PSF: each `.minigsf`/`.mini2sf` is its own track).
  /// Either way each row's `filename` is the entry's `file`, so once the
  /// archive is extracted every row resolves to its own on-disk file.
  /// [extractedDir] = the directory the archive was extracted into (its files
  /// are named per `file`); null for the pre-download preview (localPath stays
  /// null and playback extracts on demand). `[container]` when no tracklist.
  /// La ligne du MEMBRE que [songId] désigne, quand le catalogue a répondu par
  /// le CONTENEUR.
  ///
  /// `get_song_context` ne connaît que le morceau du catalogue: pour un album
  /// conteneur (jw_spc, jw_psf) c'est l'archive entière, dont le `filename` est
  /// le nom de l'ALBUM et ne désigne aucun fichier. Toute utilisation directe
  /// de cette ligne demande donc « Final Fantasy VI.spc », qui n'existe pas
  /// dans le 7z: exact-miss, puis pick générique (une piste au hasard servie
  /// sous le titre d'une autre, écrite dans `tracks` et dans la playlist qui en
  /// naît) ou, depuis le garde-fou, échec franc.
  ///
  /// L'identité `<uuid>#<i>` porte justement le rang dans l'expansion; on
  /// refait donc l'expansion et on prend la ligne `i`. [wantFileName] (le nom
  /// de fichier que l'appelant sait déjà vouloir — le basename de sa ligne
  /// locale) passe DEVANT: il est vrai même si le tracklist serveur a changé
  /// d'ordre depuis la matérialisation.
  static SearchResult narrowedToMember(SearchResult container, String songId,
      {String? wantFileName}) {
    if (container.subsongs.isEmpty) return container;
    final rows = subsongRowsFromServer(container);
    if (rows.length < 2) return container;
    if (wantFileName != null && wantFileName.isNotEmpty) {
      final want = p.basename(wantFileName);
      for (final r in rows) {
        if (p.basename(r.filename) == want) return r;
      }
    }
    final hash = songId.indexOf('#');
    if (hash >= 0) {
      final i = int.tryParse(songId.substring(hash + 1));
      if (i != null && i >= 0 && i < rows.length) return rows[i];
    }
    return container;
  }

  static List<SearchResult> subsongRowsFromServer(SearchResult container,
      {String? extractedDir}) {
    final subs = container.subsongs;
    if (subs.isEmpty) return [container];
    // The server stores each track's FORMAT-NATIVE song number (joshw m3u): NSF
    // is 1-based (1..N), GBS is 0-based (0..N-1). rewamp playback (?subsong=N)
    // is uniformly 0-based, so normalize the album's first song to 0 — same
    // offset idiom as parseM3uToSubsongs. Without this, NSF albums played one
    // subsong off (Castlevania 3's "Prelude" = server subsong 22 → SetSong(22)
    // = the 23rd song).
    final rawSubs = subs.map((s) => s.subsong).whereType<int>();
    final minSub = rawSubs.isEmpty ? 0 : rawSubs.reduce((a, b) => a < b ? a : b);
    // Numéro ABSOLU du driver (famille KSS, NEZ) → on ne retire jamais rien;
    // le serveur republie le numéro du M3U, donc la MÊME règle que
    // parseM3uToSubsongs (voir kAbsoluteSongNumberExts).
    final isAbsolute =
        kAbsoluteSongNumberExts.contains(container.formatExt.toLowerCase());
    // ⚠️ Ce repérage du 1-based lit le MINIMUM de la liste, donc il n'a de sens
    // que si la liste couvre le FICHIER. Une tracklist d'UNE entrée ne dit rien
    // de sa base: zxart publie le même conteneur .ay une fois par tune, et
    // chaque ligne porte sa seule entrée — `tracks=[{"subsong":6}]`. Le minimum
    // y vaut 6, l'ancienne règle en concluait « 1-based » et jouait la tune 6 au
    // lieu de la 7, et ainsi de suite pour sept lignes sur huit. Une entrée
    // unique est prise telle quelle: le serveur la publie 0-based.
    final subOffset =
        (isAbsolute || subs.length < 2) ? 0 : (minSub == 0 ? 0 : 1);
    return [
      for (var i = 0; i < subs.length; i++)
        () {
          final file = subs[i].file;
          final fileExt = (file != null && file.contains('.'))
              ? file.substring(file.lastIndexOf('.') + 1).toLowerCase()
              : container.formatExt;
          // An archive entry may sit in a SUB-FOLDER ("XA/VIDEO/ASPI.ogg" —
          // jw_psf's Fade to Black keeps its streamed CD audio there), and the
          // native extractor preserves that structure. _sanitize() maps '/' to
          // '_', so sanitizing the whole string built "XA_VIDEO_ASPI.ogg" and
          // every sub-folder entry resolved to a file that does not exist —
          // which is why that album played its first 53 (root-level) tracks and
          // nothing sane after them. Sanitize each SEGMENT and re-join instead;
          // drop empty/'..' segments so a hostile entry can't escape the dir.
          final local = (extractedDir != null && file != null)
              ? p.joinAll([extractedDir, ..._fileSegments(file)])
              : null;
          return SearchResult(
            songId:        '${container.songId}#$i',
            collection:    container.collection,
            title:         (subs[i].title != null && subs[i].title!.isNotEmpty)
                ? subs[i].title!
                : '${container.subsongTitleBase} (${i + 1})',
            filename:      file ?? container.filename,
            album:         container.album ?? container.displayTitle,
            albumId:       container.albumId,
            formatExt:     fileExt,
            downloadUrl:   container.downloadUrl,
            mirrorUrl:     container.mirrorUrl,
            fileSize:      i == 0 ? container.fileSize : 0,
            year:          container.year,
            // L'artiste de L'ENTRÉE quand le serveur le donne — l'union du
            // conteneur ne sert que de repli (albums mono-artiste sans champ).
            artistNames:   (subs[i].artist != null &&
                    subs[i].artist!.isNotEmpty)
                ? [subs[i].artist!]
                : container.artistNames,
            totalCount:    subs.length,
            platform:      container.platform,
            rating:        container.rating,
            artworkUrl:    container.artworkUrl,
            trackPosition: i + 1,
            subsongIdx:    subs[i].subsong == null
                ? 0
                : (subs[i].subsong! - subOffset).clamp(0, 1 << 20),
            durationMs:    subs[i].lengthMs,
            auxFiles:      container.auxFiles,
            localPath:     local,
            // Le compte décrit le FICHIER de la ligne. Une entrée qui nomme
            // son propre fichier (`file` non nul — membre d'un album
            // multi-fichiers, jw_spc/jw_psf) n'hérite PAS du nombre de pistes
            // de l'album: personne ne s'en sert là, et l'écran des stats y
            // lisait « fichier multi-sous-chansons » et ouvrait une liste pour
            // un .psf d'une seule. null = inconnu, la sonde moteur remplit au
            // premier play. Sans `file`, l'entrée EST une sous-chanson du
            // conteneur: subs.length est bien le compte du fichier.
            subsongCount:  file != null ? null : subs.length,
            resolvedSubsong: true,
            // The container IS the placed production, so its podium belongs to
            // every subsong it holds. Rebuilding these rows field by field had
            // silently dropped it: the album header showed the cup (that comes
            // from get_album_details) while the tracks under it showed none.
            podium:        container.podium,
          );
        }(),
    ];
  }

  /// Drops the subsong rows the UADE songdb marks NOSOUND (a silent, empty
  /// slot in the module — e.g. Turrican II "World 5" #4, whose music is really
  /// #5). Upstream's own plugin filters these by default.
  ///
  /// Why it is done HERE and not from the row data: the server's `tracks`
  /// tracklist carries `length_ms: null` for such an entry but NO `songend`,
  /// and a null length alone is not proof of silence (plenty of formats simply
  /// have no known duration). So the exact status is read back from the songdb
  /// — free in practice, since the rows point at files already extracted on
  /// disk and UadeInfoService caches by md5.
  ///
  /// Conservative by construction: non-UADE rows, rows whose length IS known,
  /// and anything the songdb doesn't know are all kept untouched, and a lookup
  /// failure keeps everything.
  static Future<List<SearchResult>> dropNoSoundSubsongs(
      List<SearchResult> rows) async {
    // Only rows that could be silent are worth a lookup.
    final suspect = rows.where((r) =>
        (r.durationMs ?? 0) <= 0 &&
        r.localPath != null &&
        UadeInfoService.isUadeFileAt(r.localPath!));
    if (suspect.isEmpty) return rows;

    // md5 per FILE (a module's subsongs all share one), cached by the service.
    final infos = <String, UadeInfo?>{};
    for (final path in suspect.map((r) => r.localPath!).toSet()) {
      try {
        infos[path] = await UadeInfoService.instance.forPath(path);
      } catch (_) {/* keep the rows on any failure */}
    }
    if (infos.isEmpty) return rows;

    // Row order per file, for the positional fallback below.
    final orderInFile = <SearchResult, int>{};
    {
      final seen = <String, int>{};
      for (final r in rows) {
        final key = r.localPath ?? '';
        orderInFile[r] = seen[key] = (seen[key] ?? -1) + 1;
      }
    }

    final kept = rows.where((r) {
      if ((r.durationMs ?? 0) > 0 || r.localPath == null) return true;
      final info = infos[r.localPath!];
      if (info == null || !info.isKnown) return true;
      // subsongRowsFromServer rebases `subsong` by the format's own offset, so
      // the row index does not always equal the songdb idx. Match on idx when
      // that idx exists, else fall back to the row's position among its file's
      // rows (the same "never assume 1-based" rule as durationMsFor).
      final byIdx = info.subsongs.where((s) => s.idx == r.subsongIdx);
      if (byIdx.isNotEmpty) return !byIdx.first.isBroken;
      final pos = orderInFile[r] ?? -1;
      if (pos < 0 || pos >= info.subsongs.length) return true;
      return !info.subsongs[pos].isBroken;
    }).toList();

    // Never empty an album out (same safety net as upstream).
    return kept.isEmpty ? rows : kept;
  }

  /// Le dossier D'ALBUM contenant [filePath]: remonte jusqu'au segment dont le
  /// nom est un des [anchors] (nom d'album sanitisé pour l'ancien layout
  /// artiste, album-id pour le layout canonique). Null si aucun ne matche.
  static String? _albumDirOfPath(String filePath, Set<String> anchors) {
    var d = p.dirname(filePath);
    while (d.length > 1 && p.dirname(d) != d) {
      if (anchors.contains(p.basename(d).toLowerCase())) return d;
      d = p.dirname(d);
    }
    return null;
  }

  /// Efface le CONTENU de chaque dossier + les lignes DB dessous — le ménage
  /// des copies d'un album (périmées ou re-téléchargées).
  ///
  /// [keepArtwork] : la pochette survit à un ménage de COPIE PÉRIMÉE (elle est
  /// juste au bon endroit et rien ne dit qu'elle a changé), mais PAS à un
  /// « Re-télécharger », dont le sens est « ce que j'ai est périmé » — pochette
  /// comprise. Le cache mémoire est invalidé avec elle, sinon le bitmap déjà
  /// décodé continuerait d'être servi.
  static Future<void> _wipeAlbumDirs(Iterable<String> dirs,
      {bool keepArtwork = true, bool keepUserState = false}) async {
    for (final sd in dirs) {
      debugPrint('[RewampDb] wiping album copy: $sd');
      try {
        await for (final e in Directory(sd).list()) {
          final base = p.basename(e.path);
          if (keepArtwork && base.startsWith('artwork.')) continue;
          if (!keepArtwork && e is File) {
            await ArtworkCache.instance.forgetLocalFile(e.path);
          }
          try {
            await e.delete(recursive: true);
          } catch (_) {}
        }
      } catch (_) {}
      await LocalDb.instance
          .deleteEntriesUnderPath(sd, keepUserState: keepUserState);
    }
    // Une seule fois pour tout le ménage: les vignettes montées se
    // reconstruisent sur ce compteur (voir ArtworkCache.generation).
    if (!keepArtwork) ArtworkCache.generation.value++;
  }

  /// Table rase avant un « Re-télécharger » d'ALBUM: le contenu du dossier
  /// (pochette comprise) et les lignes DB dessous — en gardant ce que
  /// l'utilisateur a posé (♥, bibliothèque, historique d'écoute).
  static Future<void> purgeAlbumDirBeforeRedownload(String dirPath) =>
      _wipeAlbumDirs({dirPath}, keepArtwork: false, keepUserState: true);

  /// Table rase avant un « Re-télécharger » de FICHIER: les octets, tout ce qui
  /// les accompagnait, et tout ce que la base en disait.
  ///
  /// Efface CHAQUE copie connue du fichier — celle qui joue, le chemin DÉRIVÉ
  /// du moment (les champs serveur bougent: un nom, une extension, un niveau de
  /// dossier) et celle que la base a enregistrée —, puis les COMPAGNONS que
  /// plus personne ne revendique (une banque `smpl.X`, un `.as` Startrekker,
  /// une pochette voisine: les laisser, c'est re-jouer le nouveau module avec
  /// les vieux échantillons), la pochette (disque + bitmap décodé), les lignes
  /// `tracks`/`recent_albums` et l'url de provenance mémorisée.
  ///
  /// ⚠️ Ce que le geste ne touche PAS: ce que l'utilisateur a posé. Le ♥ et
  /// l'appartenance à la bibliothèque restent (`keepUserState`), l'entrée
  /// `library_items` n'est jamais consultée ici — re-télécharger n'est pas
  /// supprimer.
  ///
  /// ⚠️ L'appelant doit avoir LÂCHÉ le fichier (arrêt de la lecture) avant:
  /// le décodeur ne doit pas tenir un fichier qui n'existe plus.
  static Future<void> purgeBeforeRedownload(SearchResult r,
      {String? currentPath, String? artworkUrl}) async {
    final paths = <String>{};
    if (currentPath != null && currentPath.isNotEmpty) paths.add(currentPath);
    try {
      paths.add(await _localPath(r));
    } catch (_) {}
    final id = catalogueSongId(r.songId) ?? r.songId;
    if (id.isNotEmpty) {
      try {
        final known = await LocalDb.instance.getTrackByOnlineId(id);
        if (known != null && known.filePath.isNotEmpty) paths.add(known.filePath);
      } catch (_) {}
    }

    // La pochette d'abord: elle se résout à partir des champs de la ligne ET du
    // chemin du fichier (une pochette Amiga est un VOISIN nommé d'après le
    // fichier complet), donc pendant qu'ils existent encore.
    for (final path in paths) {
      await invalidateArtworkFor(r, alsoUrl: artworkUrl, localFilePath: path);
    }

    final root = await onlineLibraryDir();
    for (final path in paths) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      // Compagnons: seulement sous `online/` — un fichier IMPORTÉ par
      // l'utilisateur n'a rien à re-télécharger, et son dossier ne nous
      // appartient pas.
      if (p.isWithin(root, path)) {
        await cleanCompanionsAfterDelete(p.dirname(path), p.basename(path),
            root: root);
      }
      await LocalDb.instance
          .deleteEntriesUnderPath(path, keepUserState: true, notify: false);
    }
    if (id.isNotEmpty) {
      await LocalDb.instance.clearDownloadSourceUrl(id);
    }
    LocalDb.instance.notifyListenersNow();
  }

  /// Tous les dossiers portant une copie de l'album de [containerId] d'après
  /// les lignes DB de ses pistes (`<containerId>#i`) — y compris les anciens
  /// layouts artiste. [anchors] = noms de dossier valides (album/albumId).
  static Future<Set<String>> _albumCopyDirs(
      String containerId, Set<String> anchors) async {
    final dirs = <String>{};
    if (containerId.isEmpty) return dirs;
    for (final fp in await LocalDb.instance
        .filePathsForOnlineIdPrefix('$containerId#')) {
      final d = _albumDirOfPath(fp, anchors) ?? p.dirname(fp);
      dirs.add(d);
    }
    return dirs;
  }

  static Future<List<SearchResult>> expandContainerAlbum(
      SearchResult container, {bool force = false}) async {
    // Server-known tracklist (`tracks`): use it directly — no native probe.
    // Extract the archive once via the first track's real filename, then point
    // every row at its own extracted file (works for single-file subsong
    // containers AND multi-file archives like GSF/2SF where each entry is a
    // distinct .minigsf/.mini2sf).
    if (container.subsongs.isNotEmpty) {
      final rows = subsongRowsFromServer(container);
      String? extractedDir;
      try {
        // The extraction ROOT (album dir), not dirname of the first track's
        // resolved path: with archive sub-folders the first track can sit one
        // level down ("Enlightenment/Druid_game_kit"), and joining every other
        // row's relative `file` onto ITS parent doubled the sub-folder — no
        // row resolved, and playback degraded into the pick-any-audio-file
        // fallback (vgmstream playing the smp.* sample bank).
        extractedDir = await artworkDirForResult(rows.first);
        // Album REMPLACÉ côté serveur SOUS LA MÊME URL (nouvelles pistes,
        // nouveau format — jw_psf2 "Frequency": rip psf2 → mp3): la purge par
        // changement d'url ne tire pas, l'ancienne extraction reste, et les
        // vieilles lignes synthétiques continuent d'être servies telles
        // quelles (« ne jamais ré-étendre »). La tracklist serveur est le
        // CONTRAT: si le fichier de sa première entrée manque alors que le
        // dossier album a déjà du contenu, l'extraction sur place est
        // périmée — on efface le dossier (artwork gardé) et ses lignes DB,
        // puis on ré-extrait à neuf.
        // Ancrages de dossier d'album: le layout canonique (basename du dossier
        // dérivé — l'album-id) ET l'ancien layout artiste (…/<nom d'album>).
        final anchors = <String>{
          p.basename(extractedDir).toLowerCase(),
          if (container.album != null && container.album!.isNotEmpty)
            _sanitize(container.album!).toLowerCase(),
          if (container.albumId != null && container.albumId!.isNotEmpty)
            container.albumId!.toLowerCase(),
        };
        if (force) {
          // « Re-télécharger l'album »: copie neuve au chemin canonique —
          // TOUTES les copies existantes (anciens dossiers artiste compris)
          // sont purgées, lignes DB avec, sinon le repli « reusing » continue
          // de servir l'ancienne et le re-téléchargement est un no-op.
          await _wipeAlbumDirs(
            {extractedDir, ...await _albumCopyDirs(container.songId, anchors)},
            keepArtwork: false,
            keepUserState: true,
          );
        } else {
          final firstFile = File(p.joinAll(
              [extractedDir, ..._fileSegments(rows.first.filename)]));
          if (!await firstFile.exists()) {
            final dir = Directory(extractedDir);
            var hasContent = false;
            if (await dir.exists()) {
              await for (final e in dir.list()) {
                final base = p.basename(e.path);
                if (base.startsWith('artwork.') || base.startsWith('_tmp_')) {
                  continue;
                }
                hasContent = true;
                break;
              }
            }
            // Les extractions périmées peuvent vivre sous PLUSIEURS dossiers:
            // chemin dérivé de l'artiste, qui a bougé ("unknown/…" ET
            // "Akrobatik/…"). Les vieilles lignes DB en sont la carte — mais
            // périmées SEULEMENT si leur fichier ne colle plus à la tracklist
            // (une copie saine sous l'ancien layout reste jouable en place).
            final staleDirs = <String>{if (hasContent) extractedDir};
            for (final d
                in await _albumCopyDirs(container.songId, anchors)) {
              if (p.equals(d, extractedDir)) continue;
              final probe = File(p.joinAll(
                  [d, ..._fileSegments(rows.first.filename)]));
              if (!await probe.exists()) staleDirs.add(d);
            }
            if (staleDirs.isNotEmpty) {
              debugPrint('[RewampDb] stale album extraction (server tracklist '
                  'mismatch)');
              await _wipeAlbumDirs(staleDirs);
            }
          }
        }
        await downloadToLibrary(rows.first, force: force);
      } catch (_) {}
      return dropNoSoundSubsongs(
          subsongRowsFromServer(container, extractedDir: extractedDir));
    }
    final localPath = await downloadToLibrary(container);
    final subs      = await probeContainerFile(localPath);
    if (subs.isEmpty) return [container];

    // Derive artist and year from M3U header if present.
    var artistNames = container.artistNames;
    var year        = container.year;
    final m3uFile   = await _findM3uForFile(p.dirname(localPath), localPath);
    if (m3uFile != null) {
      final m3uContent = await readM3uText(m3uFile);
      final m3uArtists = _parseM3uArtists(m3uContent);
      if (m3uArtists.isNotEmpty) artistNames = m3uArtists;
      final m3uYear = _parseM3uYear(m3uContent);
      if (m3uYear != null) year = m3uYear;
    }

    // Complementary vgmstream !tags.m3u (tags-only when a regular M3U is the
    // playlist): per-file %TITLE overlay + global @ARTIST fallback.
    var tagsTitles = const <String, String>{};
    final tagsFile = File(p.join(p.dirname(localPath), '!tags.m3u'));
    if (await tagsFile.exists()) {
      final tagsContent = await readM3uText(tagsFile);
      tagsTitles = _parseTagsM3uTitles(tagsContent);
      if (artistNames.isEmpty) {
        final a = _parseM3uArtists(tagsContent);
        if (a.isNotEmpty) artistNames = a;
      }
      year ??= _parseM3uYear(tagsContent);
    }

    final results = <SearchResult>[];
    // Real on-disk size per distinct file, attributed to its FIRST row only —
    // several subsong rows share one .hes; giving each the container/archive
    // size multiplied the album total (user saw 213 MB × every HES row).
    final seenFiles = <String>{};
    for (final s in subs) {
      // M3U entries pointing at a DIFFERENT extracted file (e.g. the .ape CD
      // tracks shipped beside the .hes in jw_hes archives) are standalone
      // single-song files: own name/format, subsong 0, played in place.
      final external = !p.equals(s.filePath, localPath);
      final entryExt =
          p.extension(s.filePath).replaceFirst('.', '').toLowerCase();
      int size = 0;
      if (seenFiles.add(s.filePath.toLowerCase())) {
        try {
          size = await File(s.filePath).length();
        } catch (_) {}
      }
      results.add(SearchResult(
        songId:      '${container.songId}#${s.index}',
        collection:  container.collection,
        title:       (s.title != null && s.title!.isNotEmpty)
            ? s.title!
            : tagsTitles[p.basename(s.filePath).toLowerCase()] ??
                (external
                    ? p.basenameWithoutExtension(s.filePath)
                    : '${container.subsongTitleBase} (${s.index + 1})'),
        filename:    p.basename(s.filePath),
        album:       container.album ?? container.displayTitle,
        formatExt:   entryExt.isNotEmpty ? entryExt : container.formatExt,
        downloadUrl: container.downloadUrl,
        fileSize:    size,
        year:        year,
        artistNames: artistNames,
        totalCount:  subs.length,
        platform:    container.platform,
        rating:      container.rating,
        artworkUrl:  container.artworkUrl,
        trackPosition: s.index + 1,
        subsongIdx:  external ? 0 : s.subsongIdx,
        durationMs:  s.durationMs,
        localPath:   s.filePath, // already on disk (extracted alongside)
        // Même règle que subsongRowsFromServer: un fichier EXTERNE (extrait
        // sous son propre nom) ne porte pas le compte de l'album.
        subsongCount: external ? null : subs.length,
        resolvedSubsong: true,
        // Same as the server-tracklist path above: the container's podium
        // applies to every subsong it holds.
        podium:      container.podium,
      ));
    }
    return results;
  }

  /// Deletes ONE downloaded track: the file on disk + every local-DB row
  /// referencing it (tracks/recents). Sibling-safe: only that exact file.
  static Future<void> deleteLocalTrack(String filePath) async {
    try {
      final f = File(filePath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    await LocalDb.instance.deleteEntriesUnderPath(filePath);
  }

  /// Deletes a downloaded ALBUM: its whole directory (audio + artwork + m3u +
  /// extracted files) and every local-DB row under it. [dirPath] must be the
  /// album directory (e.g. dirname of any of its tracks).
  static Future<void> deleteLocalAlbumDir(String dirPath) async {
    try {
      final d = Directory(dirPath);
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
    await LocalDb.instance.deleteEntriesUnderPath(dirPath);
  }

  /// Local-files footprint: (file count, total bytes) of the downloaded-audio
  /// tree (`online/`). Streamed walk — no directory listing held in memory.
  static Future<(int, int)> localAudioFootprint() async {
    final base = await _baseDir();
    final dir  = Directory(p.join(base.path, 'online'));
    if (!await dir.exists()) return (0, 0);
    int files = 0, bytes = 0;
    try {
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is File) {
          files++;
          try { bytes += await e.length(); } catch (_) {}
        }
      }
    } catch (_) {} // a dir vanishing mid-walk (delete) just ends the count
    return (files, bytes);
  }

  /// The directory every DOWNLOAD lives under. Public because deleting them all
  /// has to be announced to the player first (see
  /// [PlayerController.handleDeletedAlbum]), and only this class knows where the
  /// base directory is on each platform.
  static Future<String> onlineLibraryDir() async =>
      p.join((await _baseDir()).path, 'online');

  /// Deletes the entire `online/` subdirectory (all downloaded tracks,
  /// albums, and artwork).  No-op if the directory does not exist.
  ///
  /// Files only — the `tracks` rows are left alone, exactly as a single-album
  /// delete does. Callers must hand the directory to the player BEFORE calling
  /// this: it stops playback and resolves which queue entries die, and that
  /// resolution reads rows and files that are about to go.
  static Future<void> deleteOnlineLibrary() async {
    final onlineDir = Directory(await onlineLibraryDir());
    if (await onlineDir.exists()) {
      await onlineDir.delete(recursive: true);
    }
  }

  /// Base directory for downloaded files.
  /// Android: app-specific external storage (`Android/data/<pkg>/files`) —
  ///          always writable without permission; visible in Files by Google
  ///          under Android → data → com.rewamp.app (the applicationId).
  /// Others:  app Documents (exposed in iOS Files app).
  /// Le dossier qui contient `online/` — exposé pour l'écran Stockage, qui
  /// mesure les postes sur le DISQUE et doit viser le même endroit que les
  /// téléchargements (stockage externe sur Android, Documents ailleurs).
  static Future<Directory> downloadsBaseDir() => _baseDir();

  /// Couture de TEST: remplace la racine des téléchargements. `path_provider`
  /// n'a pas d'implémentation dans l'hôte de test Dart, et le simuler
  /// demanderait une dépendance de plus pour une seule racine.
  @visibleForTesting
  static Directory? debugDownloadsBaseOverride;

  /// Point d'entrée de test du tampon d'archives partagé.
  @visibleForTesting
  static Future<(Uint8List, String)> fetchArchiveSharedForTest(
          String? mirrorUrl, String originUrl,
          {required int expectedSize, bool bustCache = false}) =>
      _fetchArchiveShared(mirrorUrl, originUrl,
          label: 'test', expectedSize: expectedSize, bustCache: bustCache);

  static Future<Directory> _baseDir() async {
    final override = debugDownloadsBaseOverride;
    if (override != null) return override;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) return ext;
      } catch (_) {}
    }
    // Linux et Windows: « Documents » y est le dossier PERSONNEL de
    // l'utilisateur, pas un conteneur privé — `online/` y atterrissait à côté
    // de ses propres fichiers. Tout va sous `Documents/Rewamp/`, et la
    // migration des dossiers d'avant est dans storage_roots.dart.
    if (usesRewampFolder) return rewampDocumentsDir();
    return getApplicationDocumentsDirectory();
  }

  /// Builds the organised local path for a search result.
  static Future<String> _localPath(SearchResult r) async {
    final base = await _baseDir();
    return p.joinAll(
        [base.path, ..._dirSegments(r), ..._fileSegments(_effectiveFilename(r))]);
  }

  /// The on-disk filename to use for [r]. Normally the row's own `filename`, but
  /// when the row points at a DIRECT (non-archive) download whose URL extension
  /// disagrees with `filename` — a server-side replacement swapped, say, a
  /// `.zip`-wrapped module for a plain `.mp3` while the DB `filename` stayed
  /// `.zip` — keep the nice stem and adopt the URL's real extension, so the file
  /// lands with a routable name (else the mp3 was saved as "…​.zip" and failed
  /// to decode, spuriously reported as an unsupported format).
  static String _effectiveFilename(SearchResult r) {
    final url = r.downloadUrl;
    if (url == null || url.isEmpty) return _withFallbackExt(r, r.filename);
    // DECODED last segment, not Uri.path — that one keeps the percent-encoding,
    // so a modland TFMX row ("mdat.jim power (title)", served from
    // ".../mdat.jim%20power%20(title)") adopted "jim%20power%20(title)" as its
    // "extension" and landed on disk as "mdat.jim%20power%20(title)". Its
    // "smpl." companion, named from the decoded aux filename, then no longer
    // matched what UADE derives from the module's name → "score died".
    final urlSegs = Uri.parse(url).pathSegments;
    final urlName = urlSegs.isEmpty ? '' : urlSegs.last;
    final urlExt = p.extension(urlName).replaceFirst('.', '').toLowerCase();
    if (urlExt.isEmpty) return _withFallbackExt(r, r.filename);
    // Only a PLAUSIBLE extension may be adopted. An Amiga prefix form has a dot
    // but no extension ("mdat.jim power (title)" → p.extension is the whole
    // title), and adopting that both renames the file and, when the two spell
    // the tail differently, breaks the multifile pairing. Real extensions are
    // short and alphanumeric.
    if (!RegExp(r'^[a-z0-9]{1,5}$').hasMatch(urlExt)) {
      return _withFallbackExt(r, r.filename);
    }
    const archiveExts = {'zip', '7z', 'rar', 'gz', 'tar', 'lha', 'lzh', 'xz'};
    if (archiveExts.contains(urlExt)) return r.filename; // extracted, not saved raw
    // Web ENDPOINT extensions are not the content's type — a "download.php" (or
    // .cgi/.aspx/…) serves the real file (e.g. an .rsn) through a script. Adopting
    // "php" saved the RSN as "<name>.php", which won't play. Trust the row's own
    // filename extension in that case. (snesmusic switched to such endpoints.)
    const webExts = {
      'php', 'html', 'htm', 'asp', 'aspx', 'jsp', 'cgi', 'pl', 'do', 'action',
    };
    if (webExts.contains(urlExt)) return _withFallbackExt(r, r.filename);
    final nameExt =
        p.extension(r.filename).replaceFirst('.', '').toLowerCase();
    if (urlExt == nameExt) return r.filename;
    return '${p.basenameWithoutExtension(r.filename)}.$urlExt';
  }

  /// AMP rows carry an extension-less filename ("Starshine - PM") with the
  /// real type only in format_ext ("s3m") — saved as-is, no plugin can route
  /// it. Append format_ext when the filename has NO extension at all. Files
  /// with a dot anywhere in the tail (real ext, Amiga prefix/suffix forms
  /// like "mdat.X" whose p.extension is non-empty) pass through untouched.
  static String _withFallbackExt(SearchResult r, String name) {
    if (p.extension(name).isNotEmpty) return name;
    final fmt = r.formatExt.toLowerCase().trim();
    if (fmt.isEmpty) return name;
    return '$name.$fmt';
  }

  /// Filename split into on-disk path segments, each sanitized separately.
  ///
  /// Almost every row's filename is a bare name and this is just
  /// `[_sanitize(filename)]`. The exception is a container entry that lives in
  /// an archive SUB-FOLDER ("XA/VIDEO/ASPI.ogg" — jw_psf's Fade to Black keeps
  /// its streamed CD audio there): the native extractor preserves that
  /// structure, so the lookup has to as well. Sanitizing the whole string
  /// instead mapped '/' to '_' and pointed at a file that never exists, which
  /// is how that album ended up with only its 53 root-level tracks in the DB.
  static List<String> _fileSegments(String filename) {
    final parts = p
        .split(filename.replaceAll('\\', '/'))
        .where((s) => s.isNotEmpty && s != '.' && s != '..')  // no traversal
        .map(_sanitize)
        .toList();
    return parts.isEmpty ? [_sanitize(filename)] : parts;
  }

  /// Oublie la pochette de [r] — table, fichier sur disque et bitmap décodé.
  ///
  /// Une pochette est mise en cache SOUS SON URL et resservie depuis le disque
  /// sans rien redemander; une image remplacée côté serveur garde la même URL,
  /// donc rien ne se re-télécharge et l'ancienne reste affichée pour toujours.
  /// Tout geste « ce que j'ai est périmé » doit passer par ici — et les DEUX
  /// portes de re-téléchargement (le lecteur, l'écran de conteneur) partagent
  /// donc cette fonction plutôt que d'en recopier la règle.
  ///
  /// [alsoUrl] couvre l'url que l'écran affiche RÉELLEMENT quand elle diffère
  /// de celle du catalogue (le lecteur tient la sienne).
  /// [localFilePath] n'est pas facultatif en pratique: sans album, la pochette
  /// est un VOISIN du fichier audio (`<morceau>.png`) et non le `artwork.png`
  /// du dossier — l'oublier ferait viser le mauvais fichier, donc effacer un
  /// cache qui n'existe pas pendant que le vrai reste en place.
  static Future<void> invalidateArtworkFor(SearchResult r,
      {String? alsoUrl, String? localFilePath}) async {
    final dir = await artworkDirForResult(r);
    for (final url in {r.artworkUrl, alsoUrl}) {
      if (url == null || url.isEmpty) continue;
      await ArtworkCache.instance.invalidate(
        url,
        artist:        r.artistNames.isEmpty ? null : r.artistNames.first,
        album:         r.album,
        localFilePath: localFilePath,
        targetDir:     dir,
      );
    }
  }

  /// Full directory path where artwork for [r] should be stored.
  /// Matches _localPath() — artwork lives in the same folder as the tracks.
  static Future<String> artworkDirForResult(SearchResult r) async {
    final base = await _baseDir();
    return p.joinAll([base.path, ..._dirSegments(r)]);
  }

  /// Directory segments for a SearchResult (no filename).
  /// Structure: `online/<collection>/<artist>/<platform|format>/<album>`
  ///
  /// EXCEPTION — album-grain zip collections (smspower, vgmrips, snesmusic):
  /// the album is downloaded as ONE zip and each member resolves by filename
  /// inside it; there is no per-track download_url/mirror_url. The cache path
  /// MUST be keyed on the ALBUM (album_id, else zip_url, else album name),
  /// never the artist. A member played from a playlist/search/featured row
  /// carries a different `artistNames.first` than the album's canonical first
  /// track (which the zip was extracted under), so an artist-in-path layout
  /// makes extraction dir (keyed on songs.first) and lookup dir (keyed on the
  /// playing row) diverge → "File not found" / "Téléchargement impossible".
  /// This generalises the RSN-only workaround (rsnLocalPath(firstTrack)).
  static List<String> _dirSegments(SearchResult r) {
    final col = _sanitize(r.collection.toLowerCase());

    if (collectionIsAlbumGrain(r.collection.toLowerCase())) {
      return ['online', col, _albumKey(r)];
    }

    // Un ALBUM IDENTIFIÉ (uuid serveur) est rangé par SON identité, jamais par
    // l'artiste de la ligne: l'artiste varie selon le FLUX (l'album dit
    // « Harmonix », la piste dit « Akrobatik », une ligne re-résolue dit
    // « unknown ») et chaque variante créait SA copie du même album —
    // « Amplitude » téléchargé trois fois dans trois dossiers. Même leçon que
    // rsnLocalPath (« album-keyed, artist-free »). Les contenus déjà posés
    // sous les anciens chemins artiste restent trouvés par les replis
    // (getTrackByOnlineId préfère la ligne dont le fichier existe).
    if (r.albumId != null && r.albumId!.isNotEmpty) {
      return ['online', col, _sanitize(r.albumId!)];
    }

    final artist = _sanitize(
        r.artistNames.isNotEmpty ? r.artistNames.first : 'unknown');
    final level3 = _sanitize(
        (r.platform != null && r.platform!.isNotEmpty)
            ? r.platform!.toLowerCase()
            : r.formatExt.toLowerCase());
    // Use album name as last dir; non-null guaranteed by API for multi-track albums.
    final album = (r.album != null && r.album!.isNotEmpty)
        ? _sanitize(r.album!)
        : null;
    if (album != null) return ['online', col, artist, level3, album];
    // No album to group by, and the download is an ARCHIVE: give it a directory
    // of its own, named after the archive. Two unrelated archives otherwise
    // extracted side by side — scene.org's "dt_birth.zip" and "dt_dope.zip" both
    // land under sceneorg/unknown/zip, since neither row carries an artist, a
    // platform or an album. Their CONTENT is named nothing like the row
    // ("dt_birth.zip" holds "dt_birth.xm"), so the exact-path and basename
    // lookups both miss, and the "reuse the only extracted audio here" fallback
    // then handed the second track the first one's file: one of the two was
    // simply unplayable from the app.
    final stem = _archiveStem(r);
    return stem != null
        ? ['online', col, artist, level3, stem]
        : ['online', col, artist, level3];
  }

  /// Name of the archive this row downloads, without its extension — the
  /// per-archive directory key. Null when the download is not an archive (a
  /// direct file needs no folder of its own: its own name identifies it).
  static String? _archiveStem(SearchResult r) {
    const archiveExts = {'zip', '7z', 'rar', 'gz', 'tar', 'lha', 'lzh', 'xz'};
    String? nameOf(String? s) {
      if (s == null || s.isEmpty) return null;
      final base = p.basename(s);
      final ext = p.extension(base).replaceFirst('.', '').toLowerCase();
      if (!archiveExts.contains(ext)) return null;
      final stem = p.basenameWithoutExtension(base).trim();
      return stem.isEmpty ? null : _sanitize(stem);
    }
    // The row's own filename first (server data, stable); the URL is the
    // fallback for rows whose filename does not carry the archive's name.
    final url = r.downloadUrl;
    return nameOf(r.filename) ??
        nameOf(url == null ? null : Uri.parse(url).pathSegments.lastOrNull);
  }

  /// Stable album-cache key for album-grain zip collections (album_id, else
  /// album name). Never the artist — a member played from a foreign row carries
  /// a different artistNames.first than the album's canonical first track, so an
  /// artist key makes extraction and lookup dirs diverge. (zip_url lives on
  /// AlbumDetails, not the member SearchResult, so it can't key here.) Shared by
  /// _dirSegments and rsnLocalPath.
  static String _albumKey(SearchResult r) =>
      (r.albumId != null && r.albumId!.isNotEmpty)
          ? _sanitize(r.albumId!)
          : (r.album != null && r.album!.isNotEmpty)
              ? _sanitize(r.album!)
              : 'unknown_album';

  /// Replaces characters that are invalid in directory/file names.
  /// Un échec RÉSEAU, par opposition à une réponse du serveur.
  ///
  /// Hors ligne, `http` lève une `SocketException` (« Failed host lookup »)
  /// enveloppée dans une `ClientException`. La distinguer d'une vraie erreur
  /// serveur change ce qu'on peut faire: hors ligne, ce que le disque connaît
  /// DÉJÀ fait très bien l'affaire; sur un 500, non.
  static bool isOffline(Object e) {
    if (e is SocketException) return true;
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('Network is unreachable') ||
        s.contains('Connection refused') ||
        s.contains('Connection closed') ||
        s.contains('Connection timed out');
  }

  /// Une ligne LOCALE vue comme une ligne de catalogue.
  ///
  /// ⚠️ `songId` VIDE quand la piste n'a pas d'identité catalogue — c'est la
  /// convention que lisent les écrans de conteneur, et inventer un id serait
  /// pire que ne pas en avoir. `localPath` porte le fichier: c'est lui qui
  /// permet de jouer sans réseau.
  static SearchResult searchResultFromTrack(TrackRecord t) => SearchResult(
        songId:       t.onlineId ?? '',
        collection:   t.collectionSlug ?? '',
        title:        t.title,
        filename:     p.basename(t.filePath),
        album:        t.metaAlbum,
        albumId:      t.albumId,
        formatExt:    t.formatExt ?? '',
        downloadUrl:  null,
        fileSize:     0,
        year:         t.year,
        artistNames:  [if (t.artist != null && t.artist!.isNotEmpty) t.artist!],
        totalCount:   -1,
        platform:     t.platformName,
        artworkUrl:   t.artworkUrl,
        trackPosition: t.position,
        subsongIdx:   t.subsongIdx,
        subsongCount: t.subsongCount,
        resolvedSubsong: true,
        durationMs:   t.durationS == null ? null : (t.durationS! * 1000).round(),
        localPath:    t.filePath,
      );

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_').trim();

  /// Le chemin d'un fichier COMPAGNON, relatif au dossier du module — et il
  /// peut porter un SOUS-DOSSIER.
  ///
  /// Longtemps aplati au basename, ce qui marche pour les compagnons frères
  /// (TFMX `mdat.X` / `smpl.X`, `.pdx` de mdxplay) mais casse les formats dont
  /// le player cherche ses échantillons dans un RÉPERTOIRE. C'est le cas de
  /// SMUS (Sonix Music Driver): le catalogue modland livre ses instruments
  /// sous `Instruments/…` (`aux_files[].filename` vaut bien
  /// « Instruments/Bello.instr »), et UADE résout le volume Amiga
  /// `Instruments:` en `<dossier du module>/instruments/`
  /// (`ossupport.c`, « ScottJohnston player loads samples from Instruments: »).
  /// Aplatis à côté du `.smus`, les instruments sont introuvables et le
  /// morceau joue sans eux.
  ///
  /// ⚠️ La sécurité NE PEUT PLUS être « un basename, donc pas de traversée »:
  /// chaque composant est assaini séparément, et `.` / `..` / un préfixe
  /// absolu sont JETÉS. Un chemin qui ne laisse aucun composant rend une
  /// chaîne vide — l'appelant saute l'entrée.
  @visibleForTesting
  static String auxRelativePath(String filename) {
    final parts = <String>[];
    for (final raw in filename.split(RegExp(r'[/\\]'))) {
      final seg = raw.trim();
      if (seg.isEmpty || seg == '.' || seg == '..') continue;
      // Même assainissement que le fichier principal (_localPath), appliqué
      // par COMPOSANT: le séparateur a déjà fait son office ci-dessus.
      final clean = _sanitize(seg);
      if (clean.isEmpty || clean == '.' || clean == '..') continue;
      parts.add(clean);
    }
    return parts.join(p.separator);
  }

  // ── User API ──────────────────────────────────────────────────────────────

  /// Headers for every call that carries an IDENTITY (account, library,
  /// playlists, plays). Since migrations 188/189 the server reads the user from
  /// a signed token in this header and no RPC takes `p_user_id` any more —
  /// sending it now fails the whole call with PGRST202 "function not found".
  ///
  /// Harmless on catalogue RPCs, and REQUIRED on some that look like catalogue
  /// ones: `get_playlist_tracks` on a private playlist answers an EMPTY LIST
  /// without it, which is indistinguishable from an empty playlist.
  static Map<String, String> get _headers {
    final token = UserSettings.instance.authToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Registers a new anonymous account and PERSISTS both halves of it: the uuid
  /// (display only) and the token (the credential). Returns the uuid, or null
  /// on any failure.
  ///
  /// Since migration 188 the answer is an OBJECT `{user_id, token}` — it used
  /// to be a bare JSON string, and the old parser (`decoded as String?`) throws
  /// on it, which is why a fresh install ended up with no account at all.
  /// The response is never logged: it carries the token.
  static Future<String?> registerUser() async {
    try {
      final uri = Uri.parse('$_baseUrl/rpc/register_user');
      debugPrint('[RewampDb] registerUser → $uri');
      final resp = await http.post(uri, headers: _headers, body: '{}')
          .timeout(const Duration(seconds: 20));
      debugPrint('[RewampDb] registerUser ← ${resp.statusCode}');
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body.trim());
      final map = decoded is List
          ? (decoded.isEmpty ? null : decoded.first)
          : decoded;
      if (map is! Map) return null;
      final userId = map['user_id'] as String?;
      final token  = map['token'] as String?;
      if (token != null && token.isNotEmpty) {
        await UserSettings.instance.setAuthToken(token);
      }
      return (userId != null && userId.isNotEmpty) ? userId : null;
    } catch (e) {
      debugPrint('[RewampDb] registerUser ERROR: $e');
    }
    return null;
  }

  // ── Account (email recovery) ───────────────────────────────────────────────
  //
  // The UUID is the whole authentication model: a bearer credential, no session,
  // no expiry. An email does not "log you in", it only makes that UUID
  // RECOVERABLE on another install. Everything below exists for that.

  /// POSTs [body] to [rpc] and returns the decoded JSON, raising
  /// [RewampRpcException] on a PostgREST error. For the calls whose failure the
  /// user must see (account + playlist writes).
  static Future<dynamic> _rpc(String rpc, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl/rpc/$rpc');
    final resp = await http
        .post(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    // Never log the body of an account call: it carries the UUID (and the code).
    debugPrint('[RewampDb] $rpc ← ${resp.statusCode}');
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final txt = resp.body.trim();
      if (txt.isEmpty) return null;
      return jsonDecode(txt);
    }
    String code = '${resp.statusCode}';
    String message = resp.body;
    try {
      final err = jsonDecode(resp.body);
      if (err is Map) {
        code = (err['code'] as String?) ?? code;
        message = (err['message'] as String?) ?? message;
      }
    } catch (_) {/* not a PostgREST error envelope — keep the raw body */}
    throw RewampRpcException(code, message, resp.statusCode);
  }

  /// Emails a 6-digit login code. The answer is deliberately IDENTICAL whether
  /// the address is known or not (account enumeration) — never tell the user
  /// "no such account" here. Limits: 3 per 15 min per address, the code lives
  /// 10 minutes, and a new request invalidates the previous code.
  /// Throws [RewampRpcException] 23514 (invalid email) / 53300 (too many).
  static Future<void> requestLoginCode(String email) async {
    debugPrint('[RewampDb] requestLoginCode →');
    await _rpc('request_login_code', {'p_email': email});
  }

  /// Redeems the code, and REPLACES the stored token with the one it returns.
  ///
  /// What gets merged is decided by the token this device sends (the header is
  /// added by [_headers]) — `p_merge_from` is gone since migration 189, where
  /// it let a caller name someone else's account and absorb it. Without a token
  /// on this call, joining an existing account silently abandons the local
  /// library, so a device that has none should register first.
  ///
  /// The new token designates a possibly DIFFERENT account than a second before
  /// — that is the entire point — so every later call must use it. The caller
  /// stores [LoginResult.userId] as the local uuid (display). Single-use code;
  /// 23514 "invalid code" covers wrong, expired and 5-attempts-burnt alike
  /// (deliberately indistinguishable).
  static Future<LoginResult> verifyLoginCode({
    required String email,
    required String code,
  }) async {
    final json = await _rpc('verify_login_code', {
      'p_email': email,
      'p_code': code,
    });
    final map = json is List ? json.first : json;
    final result = LoginResult.fromJson(Map<String, dynamic>.from(map as Map));
    if (result.token != null && result.token!.isNotEmpty) {
      await UserSettings.instance.setAuthToken(result.token);
    }
    return result;
  }

  /// Invalidates every token of this account ("log out everywhere", lost
  /// device) and adopts the fresh one it returns for THIS device. Other
  /// installs are logged out on their next call.
  static Future<String?> revokeSessions() async {
    final json = await _rpc('revoke_sessions', const {});
    final map = json is List ? (json.isEmpty ? null : json.first) : json;
    if (map is! Map) return null;
    final token = map['token'] as String?;
    if (token != null && token.isNotEmpty) {
      await UserSettings.instance.setAuthToken(token);
    }
    return map['user_id'] as String?;
  }

  /// Account snapshot for the settings screen. Returns null on a transport
  /// error (offline) so the screen can show a retry instead of an exception.
  static Future<RewampAccount?> getAccount() async {
    try {
      final json = await _rpc('get_account', const {});
      final map = json is List ? (json.isEmpty ? null : json.first) : json;
      if (map is! Map) return null;
      return RewampAccount.fromJson(Map<String, dynamic>.from(map));
    } catch (e) {
      debugPrint('[RewampDb] getAccount ERROR: $e');
      return null;
    }
  }

  /// Sets the public pen name published playlists are credited to
  /// (migration 193). ONE name per account, UNIQUE case-insensitively — the
  /// constraint is there against impersonation ("Rob Hubbard" is one form away).
  ///
  /// Throws [RewampRpcException]: 23505 taken, 23514 outside 2–40 characters.
  ///
  /// CHANGING it sends every published playlist back to 'pending' and unpublishes
  /// them until the new name is reviewed — same rule as renaming a playlist, for
  /// the same reason (the displayed text changed after approval).
  /// [DisplayNameResult.playlistsBackInReview] says how many; the user has to be
  /// warned BEFORE confirming, or they watch their playlists vanish for no
  /// visible reason.
  static Future<DisplayNameResult> setDisplayName(String name) async {
    _requireAccount();
    final json = await _rpc('set_display_name', {'p_name': name});
    final map = json is List ? (json.isEmpty ? null : json.first) : json;
    return DisplayNameResult.fromJson(
        map is Map ? Map<String, dynamic>.from(map) : const {});
  }

  /// ERASES the account: library, playlists and the account row itself, with no
  /// grace period and no undo (migration 191 — RGPD art. 17 / App Store
  /// 5.1.1(v) require an in-app deletion for any app that creates accounts).
  /// Listening events are KEPT but de-identified, so the catalogue's popularity
  /// stats do not collapse when someone leaves.
  ///
  /// Never call this from a sign-out: signing out is purely local (there is no
  /// logout RPC at all, precisely so the two can never be confused). The caller
  /// must then drop the stored token — the old one is not "invalid", it simply
  /// designates a row that no longer exists — and register again.
  ///
  /// Returns the server-side counts it removed (taken BEFORE the delete).
  static Future<Map<String, int>> deleteAccount() async {
    final json = await _rpc('delete_account', const {});
    final map = json is List ? (json.isEmpty ? null : json.first) : json;
    final removed = (map is Map ? map['removed'] : null);
    if (removed is! Map) return const {};
    return {
      for (final e in removed.entries)
        if (e.value is num) e.key.toString(): (e.value as num).toInt(),
    };
  }

  /// Unlinks the email WITHOUT touching any data: the account goes back to
  /// anonymous and the address becomes free again. It also becomes
  /// unrecoverable — the caller must say so.
  static Future<void> detachEmail() async {
    await _rpc('detach_email', const {});
  }

  // ── Synchronisable client state (migration 178) ────────────────────────────
  //
  // Per-user key/value space, same contract as ext_ref: the value is NEVER
  // interpreted server-side, so its shape belongs to the client. Bounds: 64 KB
  // per value, 32 keys per user, object or array only (a scalar is refused).

  /// Reads client state. [keys] empty = every key. Returns key → (value,
  /// updatedAt); pass that timestamp back to [setUserState] to write safely.
  static Future<Map<String, (dynamic, DateTime?)>> getUserState(
      {List<String> keys = const []}) async {
    if (!UserSettings.instance.hasAuthToken) return {};
    final json = await _rpc('get_user_state', {
      if (keys.isNotEmpty) 'p_keys': keys,
    });
    final out = <String, (dynamic, DateTime?)>{};
    if (json is List) {
      for (final row in json) {
        if (row is! Map) continue;
        final k = row['key'] as String?;
        if (k == null) continue;
        out[k] = (row['value'], DateTime.tryParse(row['updated_at'] as String? ?? ''));
      }
    }
    return out;
  }

  /// Writes (or deletes, with a null [value]) one client-state key.
  ///
  /// [ifUnmodifiedSince] is the `updated_at` of the value this write is based
  /// on. If the key moved since, NOTHING is written and the answer carries
  /// `conflict: true` **with the current value** — merge it and write again.
  /// The conflict is a RESULT, not an error: PostgREST replays a transaction
  /// that fails with 40001, so raising would loop forever.
  ///
  /// Returns null on success, or the current (value, updatedAt) on conflict.
  static Future<(dynamic, DateTime?)?> setUserState(
      String key, Object? value, {DateTime? ifUnmodifiedSince}) async {
    _requireAccount();
    final json = await _rpc('set_user_state', {
      'p_key': key,
      'p_value': value,
      if (ifUnmodifiedSince != null)
        'p_if_unmodified_since': ifUnmodifiedSince.toUtc().toIso8601String(),
    });
    final map = json is List ? (json.isEmpty ? null : json.first) : json;
    if (map is Map && map['conflict'] == true) {
      return (map['value'], DateTime.tryParse(map['updated_at'] as String? ?? ''));
    }
    return null;
  }

  /// PostgREST resolves a function by its ARGUMENT NAMES: sending a parameter
  /// the deployed version does not declare is a 404, not an ignored field. So a
  /// call that uses a parameter still being rolled out retries without it —
  /// same pattern as `fuzzy` on list_playlists.
  static Future<dynamic> _rpcOptional(
      String rpc, Map<String, dynamic> body, Set<String> optional) async {
    try {
      return await _rpc(rpc, body);
    } on RewampRpcException catch (e) {
      if (e.statusCode != 404) rethrow;
      final trimmed = {...body}..removeWhere((k, _) => optional.contains(k));
      if (trimmed.length == body.length) rethrow;
      debugPrint('[RewampDb] $rpc: server has no ${optional.join('/')} yet');
      return _rpc(rpc, trimmed);
    }
  }

  /// Songs of the account library (`user_songs`). [inLibrary] null returns the
  /// REMOVED ones too (`in_library: false`) — those rows are the tombstones a
  /// two-way sync needs, so they are never purged server-side.
  ///
  /// [since] asks for the rows changed since a cursor. The server filters on
  /// `updated_at >= since` deliberately: two writes within the same microsecond
  /// can land exactly on the cursor, and re-sending a row the client already
  /// has (harmless, every apply is idempotent) beats losing one for good.
  static Future<List<UserLibrarySong>> userSongs(
      {bool? inLibrary = true, DateTime? since}) async {
    if (!UserSettings.instance.hasAuthToken) return const [];
    final json = await _rpcOptional('user_songs', {
      if (inLibrary != null) 'p_in_library': inLibrary,
      if (since != null) 'p_since': since.toUtc().toIso8601String(),
    }, {'p_since'});
    if (json is! List) return const [];
    return [
      for (final row in json)
        if (row is Map) UserLibrarySong.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Albums of the account library (`user_albums`). See [userSongs] for [since].
  static Future<List<UserLibraryAlbum>> userAlbums(
      {bool? inLibrary = true, DateTime? since}) async {
    if (!UserSettings.instance.hasAuthToken) return const [];
    final json = await _rpcOptional('user_albums', {
      if (inLibrary != null) 'p_in_library': inLibrary,
      if (since != null) 'p_since': since.toUtc().toIso8601String(),
    }, {'p_since'});
    if (json is! List) return const [];
    return [
      for (final row in json)
        if (row is Map) UserLibraryAlbum.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Playlists the user put in their library (migration 178). Same columns as
  /// [listPlaylists] plus in_library/last_played_at/added_at.
  static Future<List<Playlist>> userPlaylists({bool? inLibrary = true}) async {
    if (!UserSettings.instance.hasAuthToken) return const [];
    final json = await _rpc('user_playlists', {
      if (inLibrary != null) 'p_in_library': inLibrary,
    });
    if (json is! List) return const [];
    return [
      for (final row in json)
        if (row is Map)
          Playlist.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  // ── Personal playlists (migration 172) ─────────────────────────────────────
  //
  // Ownership is checked server-side on every write (42501 on someone else's,
  // or on a server-curated playlist). A song may appear SEVERAL TIMES in one
  // playlist — so `position` (1-based) identifies an entry, `song_id` does not,
  // and positions are re-densified to 1..N after every operation: any position
  // held client-side is stale as soon as a write succeeds.

  /// Fails fast when this device has no credential. Since migration 188 the
  /// server answers `42501 authentication required` on a write without one and
  /// an EMPTY LIST on a read — the second failure mode is invisible, hence the
  /// explicit check before every write.
  static void _requireAccount() {
    if (!UserSettings.instance.hasAuthToken) {
      throw const RewampRpcException('42501', 'authentication required');
    }
  }

  /// Creates a playlist, optionally with an initial track list (kept in the
  /// given order).
  ///
  /// Prefer [entries] (migration 176): it is the only form that preserves an
  /// out-of-catalogue tune. With [songIds] alone, an id the server does not
  /// know is dropped silently and the playlist comes back shorter — and holed,
  /// since the surviving entries close ranks. **Never send both**: `p_entries`
  /// wins server-side.
  static Future<Playlist> createPlaylist({
    required String name,
    String? description,
    List<String>? songIds,
    List<PlaylistItemPayload>? entries,
    bool isPublic = false,
  }) async {
    final json = await _rpc('create_playlist', {
      'p_name': name,
      if (description != null && description.isNotEmpty)
        'p_description': description,
      if (entries != null && entries.isNotEmpty)
        'p_entries': [for (final e in entries) e.toJson()]
      else if (songIds != null && songIds.isNotEmpty)
        'p_song_ids': _catalogueIds(songIds),
      'p_is_public': isPublic,
    });
    final map = json is List ? json.first : json;
    return Playlist.fromJson(Map<String, dynamic>.from(map as Map));
  }

  /// Updates the fields that are passed; the others keep their value.
  ///
  /// [ifUnmodifiedSince] = the server version this write is based on. If the
  /// playlist moved since, nothing is written and the result carries
  /// `conflict: true` with the current state (migration 182).
  static Future<PlaylistWriteResult> updatePlaylist({
    required String playlistId,
    String? name,
    String? description,
    String? coverUrl,
    bool? isPublic,
    DateTime? ifUnmodifiedSince,
  }) async {
    final json = await _rpc('update_playlist', {
      'p_playlist_id': playlistId,
      if (name != null) 'p_name': name,
      if (description != null) 'p_description': description,
      if (coverUrl != null) 'p_cover_url': coverUrl,
      if (isPublic != null) 'p_is_public': isPublic,
      if (ifUnmodifiedSince != null)
        'p_if_unmodified_since': ifUnmodifiedSince.toUtc().toIso8601String(),
    });
    return PlaylistWriteResult.fromJson(json);
  }

  static Future<void> deletePlaylist(String playlistId) async {
    await _rpc('delete_playlist', {
      'p_playlist_id': playlistId,
    });
  }

  // ── Publishing a playlist (migrations 192/193) ──────────────────────────────
  //
  // A user playlist is born private and becoming public is a REQUEST, reviewed
  // by the operator: private → pending → approved | rejected. There is no direct
  // write that publishes (a CHECK constraint forbids is_public without an
  // approval), so these two calls are the only path.
  //
  // The server refuses a submission with 23514 on any of: no display name yet,
  // fewer than 5 CATALOGUE tracks, the slightest local entry (an ext_ref nobody
  // else could play, and unmoderated client text), or three requests already
  // pending. The caller checks all four first — a bare 23514 tells the user
  // nothing.

  /// Asks for the playlist to be published. Returns it with review_status
  /// 'pending'. Throws [RewampRpcException] 23514 when a rule above is broken,
  /// 42501 when it is not this account's playlist.
  static Future<Playlist> submitPlaylistForReview(String playlistId) async {
    _requireAccount();
    final json = await _rpc('submit_playlist_for_review', {
      'p_playlist_id': playlistId,
    });
    final map = json is List ? json.first : json;
    return Playlist.fromJson(Map<String, dynamic>.from(map as Map));
  }

  /// Back to 'private', from ANY state — including a playlist already public.
  static Future<Playlist> withdrawPlaylist(String playlistId) async {
    _requireAccount();
    final json = await _rpc('withdraw_playlist', {
      'p_playlist_id': playlistId,
    });
    final map = json is List ? json.first : json;
    return Playlist.fromJson(Map<String, dynamic>.from(map as Map));
  }

  /// Appends AT THE END, keeping the given order. Returns how many entries were
  /// actually added — with [songIds] that can be fewer than asked (unknown ids
  /// are dropped); with [entries] every element carrying an `ext_ref` is kept.
  static Future<PlaylistWriteResult> addPlaylistItems({
    required String playlistId,
    List<String> songIds = const [],
    List<PlaylistItemPayload>? entries,
    DateTime? ifUnmodifiedSince,
  }) async {
    if (songIds.isEmpty && (entries == null || entries.isEmpty)) {
      return const PlaylistWriteResult();
    }
    final json = await _rpc('add_playlist_items', {
      'p_playlist_id': playlistId,
      if (entries != null && entries.isNotEmpty)
        'p_entries': [for (final e in entries) e.toJson()]
      else
        'p_song_ids': _catalogueIds(songIds),
      if (ifUnmodifiedSince != null)
        'p_if_unmodified_since': ifUnmodifiedSince.toUtc().toIso8601String(),
    });
    return PlaylistWriteResult.fromJson(json);
  }

  /// Removes entries by [positions] (1-based, ONE precise line each) and/or by
  /// [songIds] (EVERY occurrence of those songs). Positions shift afterwards:
  /// reload the list before removing again.
  static Future<int> removePlaylistItems({
    required String playlistId,
    List<int>? positions,
    List<String>? songIds,
  }) async {
    final json = await _rpc('remove_playlist_items', {
      'p_playlist_id': playlistId,
      if (positions != null && positions.isNotEmpty) 'p_positions': positions,
      if (songIds != null && songIds.isNotEmpty)
        'p_song_ids': _catalogueIds(songIds),
    });
    final map = json is List ? json.first : json;
    return ((map as Map)['removed'] as num?)?.toInt() ?? 0;
  }

  /// FULL replacement of the track list, in display order, duplicates included
  /// ([A, B, A] is accepted as-is). Anything left out is removed.
  ///
  /// With [songIds] on a playlist that holds out-of-catalogue entries, those
  /// entries are NOT in the new list and are therefore deleted — pass [entries]
  /// (the complete list, catalogue and non-catalogue alike) instead.
  ///
  /// [ifUnmodifiedSince] matters MORE here than anywhere else: this call is a
  /// full replacement, so without it a concurrent edit from another device is
  /// not partially lost but ENTIRELY lost.
  static Future<PlaylistWriteResult> reorderPlaylist({
    required String playlistId,
    List<String> songIds = const [],
    List<PlaylistItemPayload>? entries,
    DateTime? ifUnmodifiedSince,
  }) async {
    final json = await _rpc('reorder_playlist', {
      'p_playlist_id': playlistId,
      if (entries != null)
        'p_entries': [for (final e in entries) e.toJson()]
      else
        'p_song_ids': _catalogueIds(songIds),
      if (ifUnmodifiedSince != null)
        'p_if_unmodified_since': ifUnmodifiedSince.toUtc().toIso8601String(),
    });
    return PlaylistWriteResult.fromJson(json);
  }

  /// Fires once per track when 30 s elapsed, half-duration elapsed, or track ends.
  ///
  /// [songId] is the LOCAL identity (`uuid`, `uuid#N`, `uuid?subsong=N`); the
  /// subsong is KEPT — see [playLogSongId] for why this one call differs from
  /// every other. A songId with no catalogue identity is dropped here rather
  /// than sent as-is: `p_song_id::UUID` would 22P02 on it.
  /// Rend `true` quand le serveur a bien pris l'écoute — c'est ce que le
  /// contrôleur utilise pour marquer la ligne locale `pushed` (elle reviendra
  /// par la timeline du compte, donc l'écran Stats ne doit pas la compter deux
  /// fois). Sans reprise: un échec laisse l'écoute purement locale.
  static Future<bool> logPlay({
    required String songId,
    required int durationMs,
    /// Slug du moteur qui a décodé (`audio.backendName`: `psgplay`, `gme`,
    /// `uade`…), jamais un libellé d'affichage: le serveur ne tient aucune
    /// liste blanche, il normalise en minuscules et tronque à 40 caractères,
    /// donc c'est le vocabulaire du client qui fait foi. Null/vide = non
    /// déclaré, le serveur n'invente rien.
    String? backend,
  }) async {
    final sent = playLogSongId(songId);
    if (sent == null) {
      debugPrint('[RewampDb] logPlay skipped (no catalogue id): $songId');
      return false;
    }
    try {
      final uri = Uri.parse('$_baseUrl/rpc/log_play');
      debugPrint('[RewampDb] logPlay → songId=$sent durationMs=$durationMs');
      final resp = await http.post(uri,
        headers: _headers,
        body: jsonEncode({
          'p_song_id':     sent,
          'p_duration_ms': durationMs,
          if (backend != null && backend.isNotEmpty) 'p_backend': backend,
        }),
      ).timeout(const Duration(seconds: 20));
      debugPrint('[RewampDb] logPlay ← ${resp.statusCode} ${resp.body}');
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      debugPrint('[RewampDb] logPlay ERROR: $e');
      return false;
    }
  }

  /// Reports a problem with a song to the server (report_song RPC). Fire-and-
  /// forget: never throws, never blocks playback. [songId] is the song's UUID
  /// (for a multi-track container, the parent's; the subsong goes in
  /// [subsongIndex], 1-based). [reason] must be one of the server's enum
  /// (no_playback · download_failed · wrong_track · bad_audio · other). Client
  /// Declares this device to the server (`touch_device`, mig 204): one row per
  /// (account, OS, model), timestamped, so the admin can see which platforms an
  /// account actually uses. Fire-and-forget — never surfaces to the user.
  static Future<void> touchDevice() async {
    try {
      await ClientInfo.instance.ensureLoaded();
      final ci = ClientInfo.instance;
      if (ci.osName == null) return;
      final uri = Uri.parse('$_baseUrl/rpc/touch_device');
      final body = <String, dynamic>{
        'p_os_name': ci.osName,
        if (ci.device != null)     'p_device':      ci.device,
        if (ci.osVersion != null)  'p_os_version':  ci.osVersion,
        if (ci.appVersion != null) 'p_app_version': ci.appVersion,
        if (ci.appBuild != null)   'p_app_build':   ci.appBuild,
      };
      final resp = await http.post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      debugPrint('[RewampDb] touchDevice ← ${resp.statusCode}');
    } catch (e) {
      debugPrint('[RewampDb] touchDevice ERROR: $e');
    }
  }

  /// version/build + OS/device (from ClientInfo) are attached so a targeted bug
  /// can be reproduced. Local files have no songId → callers skip the report.
  static Future<void> reportSong({
    required String songId,
    required String reason,
    int? subsongIndex,
    String? detail,
  }) async {
    try {
      await ClientInfo.instance.ensureLoaded();
      final ci = ClientInfo.instance;
      final uri = Uri.parse('$_baseUrl/rpc/report_song');
      final body = <String, dynamic>{
        'p_song_id': catalogueSongId(songId) ?? songId,
        'p_reason':  reason,
        if (subsongIndex != null && subsongIndex > 0)
          'p_subsong_index': subsongIndex,
        if (detail != null && detail.isNotEmpty) 'p_detail': detail,
        if (ci.appVersion != null) 'p_app_version': ci.appVersion,
        if (ci.appBuild != null)   'p_app_build':   ci.appBuild,
        if (ci.osName != null)     'p_os_name':     ci.osName,
        if (ci.osVersion != null)  'p_os_version':  ci.osVersion,
        if (ci.device != null)     'p_device':      ci.device,
      };
      debugPrint('[RewampDb] reportSong → songId=$songId reason=$reason '
          'sub=$subsongIndex ${ci.osName}/${ci.osVersion} ${ci.device}');
      final resp = await http.post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      debugPrint('[RewampDb] reportSong ← ${resp.statusCode} ${resp.body}');
    } catch (e) {
      debugPrint('[RewampDb] reportSong ERROR: $e');
    }
  }

  /// Reports a broken demozoo video (`report_video`). Fire-and-forget, like
  /// [reportSong] — a failed report must never surface to the user.
  /// [reason] ∈ video_unavailable | video_private | video_geoblocked |
  /// wrong_video | other; anything else is rejected server-side (23514).
  /// The server aggregates: same (production, video, reason) bumps
  /// occurrence_count, and one user counts once.
  ///
  /// A video hangs EITHER off a production (the demozoo case, [productionId])
  /// OR straight off a song (a manually attached video, whose videos[] row
  /// carries a null production_id) — then [songId] is the key, and the same
  /// reasons and the same aggregation apply. Exactly one of the two travels;
  /// with neither the report is dropped (nothing to key it on).
  static Future<void> reportVideo({
    int? productionId,
    String? songId,
    required String reason,
    String? provider,
    String? videoId,
    String? detail,
  }) async {
    // A local id (`uuid#N`, `uuid?subsong=N`, a path) is not a catalogue uuid,
    // and the server column is one: 22P02 on anything else.
    final song = productionId == null ? catalogueSongId(songId) : null;
    if (productionId == null && song == null) {
      debugPrint('[RewampDb] reportVideo SKIP — no production nor song id');
      return;
    }
    try {
      await ClientInfo.instance.ensureLoaded();
      final ci = ClientInfo.instance;
      final uri = Uri.parse('$_baseUrl/rpc/report_video');
      final body = <String, dynamic>{
        if (productionId != null) 'p_production_id': productionId,
        if (song != null)         'p_song_id':       song,
        'p_reason':        reason,
        if (provider != null && provider.isNotEmpty) 'p_provider': provider,
        if (videoId != null && videoId.isNotEmpty)   'p_video_id': videoId,
        if (detail != null && detail.isNotEmpty)     'p_detail':   detail,
        if (ci.appVersion != null) 'p_app_version': ci.appVersion,
        if (ci.osName != null)     'p_os_name':     ci.osName,
        if (ci.osVersion != null)  'p_os_version':  ci.osVersion,
        if (ci.device != null)     'p_device':      ci.device,
      };
      debugPrint('[RewampDb] reportVideo → prod=$productionId song=$song '
          'reason=$reason provider=$provider video=$videoId');
      // The old anonymous-retry (on a 23503 for an FK the server didn't know)
      // is gone with p_user_id: an unknown or absent identity is now simply a
      // report attributed to nobody, never a failed insert.
      final resp = await http
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      debugPrint('[RewampDb] reportVideo ← ${resp.statusCode} ${resp.body}');
    } catch (e) {
      debugPrint('[RewampDb] reportVideo ERROR: $e');
    }
  }

  /// Syncs library add/remove with the server. Throws so the caller's outbox
  /// can keep an undelivered change instead of losing it.
  ///
  /// An entry is identified EITHER by [itemId] (+ [subsongIndex], which is what
  /// distinguishes two subtunes of one file) OR by [extKey] for a file the
  /// catalogue does not know, whose snapshot travels in [extRef].
  /// Returns the `updated_at` the SERVER kept — the value that arbitrates and
  /// moves the delta cursor (null on an older server that answered `void`).
  /// [favourite] (migration serveur 206) porte le ♥, qui est désormais une
  /// COLONNE serveur et non plus le blob opaque `user_state.favourites` — lequel
  /// était réécrit en entier à chaque fois, donc deux appareils qui aimaient en
  /// même temps se perdaient un ♥.
  ///
  /// null = ne pas toucher au ♥. Les règles serveur qu'il faut connaître sans
  /// les réimplémenter: `favourite: true` force aussi l'entrée en bibliothèque,
  /// et un retrait (`value: false`) EFFACE le ♥ — d'où [sendValue], que le
  /// drainage de l'outbox met à false pour un geste ♥ pur: un un-♥ doit laisser
  /// l'entrée en bibliothèque.
  static Future<DateTime?> setLibrary({
    String? itemId,
    required String itemType, // 'song' | 'album' | 'playlist'
    required bool value,
    bool sendValue = true,
    bool? favourite,
    int? subsongIndex,
    String? extKey,
    Map<String, dynamic>? extRef,
  }) async {
    final json = await _rpc('set_library', {
      if (itemId != null && itemId.isNotEmpty)
        'p_item_id': catalogueSongId(itemId) ?? itemId,
      'p_item_type': itemType,
      if (sendValue) 'p_value': value,
      if (favourite != null) 'p_favourite': favourite,
      if (subsongIndex != null) 'p_subsong_index': subsongIndex,
      if (extKey != null && extKey.isNotEmpty) 'p_ext_key': extKey,
      if (extRef != null) 'p_ext_ref': extRef,
    });
    final map = json is List ? (json.isEmpty ? null : json.first) : json;
    if (map is! Map) return null;
    return DateTime.tryParse(map['updated_at'] as String? ?? '');
  }

  /// Lot de gestes de bibliothèque (`set_library_batch`, migration serveur
  /// 271): chaque élément porte les paramètres de [setLibrary] SANS le
  /// préfixe `p_`, absents = mêmes défauts qu'en unitaire; ≤ 200 éléments
  /// (au-delà 23514), appliqués DANS L'ORDRE, chacun par `set_library`
  /// elle-même. Un élément irrecevable ne tue pas le lot: il revient dans
  /// `rejected` avec son index et son code. Un serveur sans la fonction
  /// répond 404 (PostgREST): l'appelant retombe sur l'unitaire.
  static Future<LibraryBatchResult> setLibraryBatch(
      List<Map<String, dynamic>> items) async {
    final json = await _rpc('set_library_batch', {'p_items': items});
    final map = json is List ? (json.isEmpty ? null : json.first) : json;
    if (map is! Map) return const LibraryBatchResult(0, []);
    final rejected = <LibraryBatchRejection>[];
    final raw = map['rejected'];
    if (raw is List) {
      for (final r in raw) {
        if (r is! Map) continue;
        final idx = r['index'];
        if (idx is! num) continue;
        rejected.add(LibraryBatchRejection(idx.toInt(),
            '${r['code'] ?? ''}', '${r['message'] ?? ''}'));
      }
    }
    return LibraryBatchResult((map['applied'] as num?)?.toInt() ?? 0, rejected);
  }

  /// Ranked entries of a competition (`get_competition_entries`, mig 183).
  /// The tap target of a podium badge when the compo has no playlist — and of
  /// a `kind='competition'` featured card.
  static Future<List<CompetitionEntry>> competitionEntries(int competitionId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rpc/get_competition_entries');
      final resp = await http
          .post(uri, headers: _headers,
              body: jsonEncode({'p_competition_id': competitionId}))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) return const [];
      final list = jsonDecode(resp.body);
      if (list is! List) return const [];
      return [
        for (final row in list)
          if (row is Map)
            CompetitionEntry.fromJson(Map<String, dynamic>.from(row)),
      ];
    } catch (e) {
      debugPrint('[RewampDb] competitionEntries ERROR: $e');
      return const [];
    }
  }

  /// Hard-deletes out-of-catalogue favourites BY KEY (`purge_ext_library`,
  /// migration 203). Returns how many rows the account actually dropped.
  ///
  /// IRREVERSIBLE, and NOT the way to un-favourite something: the row carries
  /// `play_count`/`last_played_at`, so a purge destroys that history — the same
  /// trap migration 180 documented for `user_song_library`, where 657 of 659
  /// `in_library=false` rows were listening history rather than removals.
  /// Un-favouriting stays [setLibrary] with `value: false`.
  ///
  /// It also leaves NO TOMBSTONE: a device that only ever pulls the `p_since`
  /// delta will never hear about the deletion, so peers converge through the
  /// `user_library_ids` snapshot — the model migration 182 already set for
  /// deleted playlists, and what [SyncService] reconciles against.
  ///
  /// The server caps a call at 500 keys; this batches accordingly. Identity is
  /// the JWT, so it can only ever purge the caller's own rows.
  static Future<int> purgeExtLibrary(List<String> extKeys) async {
    if (extKeys.isEmpty || !UserSettings.instance.hasAuthToken) return 0;
    var removed = 0;
    for (var i = 0; i < extKeys.length; i += 500) {
      final batch = extKeys.sublist(i, math.min(i + 500, extKeys.length));
      final json = await _rpc('purge_ext_library', {'p_ext_keys': batch});
      final n = json is List ? (json.isEmpty ? null : json.first) : json;
      removed += (n is int) ? n : int.tryParse('$n') ?? 0;
    }
    return removed;
  }

  /// Compact snapshot of everything in the library, all four grains in one
  /// call (`user_library_ids`, migration 180): identity only — no title, no
  /// artwork. THE call for set-difference reconciliation.
  static Future<List<LibraryIdRow>> userLibraryIds() async {
    if (!UserSettings.instance.hasAuthToken) return const [];
    final json = await _rpc('user_library_ids', const {});
    if (json is! List) return const [];
    return [
      for (final row in json)
        if (row is Map) LibraryIdRow.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Fetches most popular songs from the server ('day'|'week'|'month'|'all').
  /// Rows are display-only (no filename/download_url — see api docs): resolve
  /// via [getSongContext] before playing.
  ///
  /// Migration 107 (2026-07): tracks belonging to an album are now collapsed
  /// server-side into one row per album (plays summed) — the response carries
  /// `item_id`/`item_type` ("song"|"album") instead of `song_id`. Album rows
  /// keep [SearchResult.isAlbumRow] set and carry `album_id`, so the rail's
  /// tap handler routes them through [albumTracks] instead of
  /// [getSongContext].
  static Future<List<SearchResult>> mostPopularSongs({
    // Valid server values: '7d' | '30d' | '90d' | '1y' | 'YYYY' | 'all'
    // (_period_bounds, migration 034); anything else silently means 'all'.
    String period = '7d',
    int n = 20,
    String? collectionSlug,
    /// 'plays' (défaut serveur) | 'popularity' | 'rating' — ces deux derniers
    /// depuis les migrations 207/208. `popularity` est un percentile décayé sur
    /// 90 j: il classe autrement que le simple volume d'écoutes.
    String? sortBy,
    List<String>? collections, // p_collections (mig 243) — voir search()
  }) async {
    // Throws on network failure / non-200 — the caller needs to tell a failed
    // fetch (retry later) apart from a server that genuinely has no rows.
    final uri = Uri.parse('$_baseUrl/rpc/most_popular_songs');
    final body = <String, dynamic>{'period': period, 'n': n};
    if (sortBy != null) body['sort_by'] = sortBy;
    if (collectionSlug != null) body['collection_slug'] = collectionSlug;
    if (collectionSlug == null && collections != null && collections.isNotEmpty) {
      body['p_collections'] = collections;
    }
    final resp = await _postJsonOptional(uri, body,
        optional: const {'p_collections'}, headers: _headers);
    if (resp.statusCode != 200) {
      throw Exception('most_popular_songs HTTP ${resp.statusCode}');
    }
    final list = jsonDecode(resp.body) as List<dynamic>;
    final out = <SearchResult>[];
    for (final j in list) {
      final r = popularRowToResult(Map<String, dynamic>.of(j as Map<String, dynamic>));
      if (r != null) out.add(r);
    }
    return out;
  }

  /// Une ligne de `most_popular_songs` → [SearchResult]. Pure, testable.
  ///
  /// Depuis le 2026-09-05 la ligne est une ŒUVRE (`item_type` dit dans quelle
  /// table vit `item_id`: `albums` ou `songs`) et désigne son entrée la plus
  /// écoutée `(top_song_id, top_subsong_index)`. **`song_id` vient de
  /// `top_song_id`**, plus jamais de `item_id`: sur une ligne `album`, `item_id`
  /// est un uuid d'ALBUM et la feuille de choix comme le ♥ tomberaient sur la
  /// mauvaise clé. `item_id` ne nourrit plus que `album_id`. Serveur d'avant
  /// (pas de `top_song_id`): l'ancien repli sur `item_id` tient toujours. Les
  /// lignes de stats n'ont pas de `filename` et nomment la note `avg_rating`;
  /// une ligne malformée est sautée plutôt que de perdre le rail.
  static SearchResult? popularRowToResult(Map<String, dynamic> m) {
    m['song_id'] = (m['top_song_id'] as String?) ?? m['song_id'] ?? m['item_id'];
    if (m['item_type'] == 'album') m['album_id'] ??= m['item_id'];
    m['filename'] ??= (m['title'] as String?) ?? '';
    m['rating'] ??= m['avg_rating'];
    try {
      return SearchResult.fromJson(m);
    } catch (_) {
      return null;
    }
  }

  /// La durée à MONTRER sur une ligne de liste, en ms — null si on ne sait pas.
  ///
  /// Un conteneur montre la durée du FICHIER (`total_length_ms`) et jamais
  /// celle de son premier sous-chant: écrire 3:55 sous « Commando », dont les
  /// 19 sous-chants totalisent bien autre chose, désigne une durée que rien ne
  /// joue. Une ligne qui désigne UN morceau (fichier mono, sous-chant résolu)
  /// montre la sienne, et retombe sur le total quand le serveur ne connaît que
  /// lui — sur un mono les deux sont la même valeur.
  static int? listDurationMs(SearchResult r) {
    // ⚠️ Une ligne peut PORTER un conteneur tout en DÉSIGNANT une piste: un
    // résultat de recherche qui a matché un titre à l'intérieur du fichier
    // (`match_track_title`), une entrée épinglée à un sous-chant, une ligne
    // dépliée. Elle affiche ce titre-là, donc la durée du FICHIER y serait un
    // contresens — « Iron Arms [Iron Ore Weapon Battle] » annonçait 1:18:37,
    // la durée des 73 sous-chants de « Juukou Senki Bullet Battlers.gbs ».
    // Le serveur ne donne pas la durée de CETTE piste sur cette ligne: on
    // n'affiche donc rien, comme partout ailleurs où l'on ne sait pas.
    final narrowed = r.matchSubsongTitle != null ||
        r.matchSubsongIndex != null ||
        r.resolvedSubsong ||
        r.subsongIdx != 0;
    // Le serveur donne la durée de la piste nommée depuis le 2026-09-06
    // (`match_track_length_ms`); avant, ces lignes n'en avaient aucune.
    if (narrowed) return r.matchSubsongLengthMs ?? r.durationMs;
    return isContainerRow(r) ? r.totalLengthMs : (r.durationMs ?? r.totalLengthMs);
  }

  /// Somme des durées d'une liste de sous-chants — null si UNE seule manque.
  ///
  /// C'est le repli quand le serveur ne donne pas de total: un fichier LOCAL,
  /// ou une collection sans `total_length_ms`. Partielle, elle mentirait
  /// (« 2:04 » pour un fichier qui en fait 12), donc on n'affiche rien plutôt
  /// qu'un total faux. Les entrées mortes n'y sont pas: elles ont déjà été
  /// retirées de la liste (voir `UadeSubsong.isBroken`).
  static int? sumSubsongDurationsMs(Iterable<int?> durations) {
    var total = 0;
    var any = false;
    for (final d in durations) {
      if (d == null || d <= 0) return null;
      total += d;
      any = true;
    }
    return any ? total : null;
  }

  /// Durée d'un ALBUM: la somme de ce qu'on connaît, et si c'est PARTIEL on
  /// le dit — « 45:26+ ». null quand aucune piste n'a de durée.
  ///
  /// Le serveur ne rend pas de total d'album: `total_length_ms` est PAR
  /// FICHIER, donc le client somme les lignes (règle 4 du contrat). Une somme
  /// partielle est utile — l'album fait au moins ça — à condition de ne pas se
  /// faire passer pour exacte, d'où le suffixe. Chaque ligne apporte la durée
  /// que sa LISTE afficherait ([listDurationMs]): pour un conteneur c'est le
  /// fichier entier, jamais son premier sous-chant.
  static String? albumDurationLabel(Iterable<SearchResult> rows) {
    var total = 0;
    var known = 0, missing = 0;
    for (final r in rows) {
      final ms = listDurationMs(r);
      if (ms != null && ms > 0) {
        total += ms;
        known++;
      } else {
        missing++;
      }
    }
    if (known == 0) return null;
    return missing == 0
        ? formatDurationMs(total)
        : '${formatDurationMs(total)}+';
  }

  /// « m:ss », ou « h:mm:ss » au-delà de l'heure. Partagé par les listes et
  /// l'écran de détail — deux formats pour la même chose se remarquent.
  static String formatDurationMs(int ms) {
    final total = ms ~/ 1000;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
    return '$m:$ss';
  }

  /// Position, dans [rows], de l'entrée la plus écoutée que [top] désigne —
  /// le point de départ de la rotation. Fichier ET sous-chant, puis fichier
  /// seul, puis 0: une entrée disparue de la tracklist (piste retirée,
  /// renommée) n'est jamais un échec, un rail ne doit pas casser sur une carte.
  static int topEntryIndex(List<SearchResult> rows, SearchResult top) {
    final id = top.topSongId;
    if (id == null || id.isEmpty) return 0;
    final sub = top.topSubsongIndex ?? 0;
    String base(String s) => s.split('#').first;
    var i = rows.indexWhere((r) => base(r.songId) == id && r.subsongIdx == sub);
    if (i < 0) i = rows.indexWhere((r) => base(r.songId) == id);
    return i < 0 ? 0 : i;
  }

  /// Palmarès d'ALBUMS (`most_popular_albums`). ⚠️ Signature vérifiée sur le
  /// serveur: `(collection_slug, n, p_collections, p_country_code, period)` —
  /// PAS de `sort_by`, contrairement aux morceaux: un palmarès d'albums est
  /// toujours au volume d'écoutes.
  static Future<List<PopularAlbum>> mostPopularAlbums({
    String period = 'all',
    int n = 100,
    String? collectionSlug,
  }) async {
    final j = await _rpc('most_popular_albums', {
      'period': period,
      'n': n,
      if (collectionSlug != null) 'collection_slug': collectionSlug,
    });
    if (j is! List) return const [];
    return [
      for (final e in j)
        if (e is Map && e['album_id'] is String)
          PopularAlbum.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  /// Les playlists de CLASSEMENT (`list_charts`), toutes ou pour une
  /// collection. Voir [ChartPlaylist] pour le contrat.
  static Future<List<ChartPlaylist>> listCharts({String? collection}) async {
    final j = await _rpc('list_charts', {
      if (collection != null) 'p_collection': collection,
    });
    if (j is! List) return const [];
    return [
      for (final e in j)
        if (e is Map && e['id'] is String)
          ChartPlaylist.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  /// Les ALBUMS d'un classement au grain 'album' (`get_chart_albums`), dans
  /// l'ordre du rang. Colonnes alignées sur `search_albums` — le parseur
  /// [ArtistAlbum.fromJson] sert tel quel — plus `rank`. 100 lignes au lieu
  /// des 2364 pistes de la playlist vgmrips.
  static Future<List<(int rank, ArtistAlbum album)>> chartAlbums(
      String playlistId, {int limit = 200, int offset = 0}) async {
    final j = await _rpc('get_chart_albums', {
      'p_playlist_id': playlistId,
      'lim': limit,
      'from_offset': offset,
    });
    if (j is! List) return const [];
    return [
      for (final e in j)
        if (e is Map && e['album'] is String)
          (
            ((e['rank'] as num?)?.toInt()) ?? 0,
            ArtistAlbum.fromJson(Map<String, dynamic>.from(e)),
          ),
    ];
  }

  // ── Écoutes: backup en ligne des stats (log_plays_ext & co) ──────────────

  /// Livre un LOT (≤500) d'écoutes de fichiers locaux. Idempotent côté
  /// serveur (PK user/ext_key/played_at): un lot rejoué après coupure ne
  /// double rien. Chaque événement: {ext_key, duration_ms, played_at, ext_ref,
  /// backend} — le moteur compte SURTOUT ici, c'est sur un fichier local que
  /// l'extension renseigne le moins (un `.sndh` peut passer par psgplay ou
  /// AtariAudio, selon le réglage).
  static Future<void> logPlaysExt(List<Map<String, dynamic>> events) async {
    if (events.isEmpty || !UserSettings.instance.hasAuthToken) return;
    await _rpc('log_plays_ext', {'p_events': events});
  }

  /// Cumuls d'écoute du compte (`user_play_stats`): catalogue
  /// (song_id+subsong_index) et ext (ext_key) dans une même liste, curseur
  /// `last_played_at >=` croissant. Le serveur fait autorité — le client
  /// REMPLACE ses compteurs, il n'additionne pas.
  static Future<List<UserPlayStat>> userPlayStats({DateTime? since}) async {
    final j = await _rpc('user_play_stats', {
      if (since != null) 'p_since': since.toUtc().toIso8601String(),
    });
    if (j is! List) return const [];
    return [
      for (final e in j.whereType<Map>())
        UserPlayStat.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  /// Timeline brute des écoutes ext (1 ligne/écoute) — le rejeu d'historique
  /// d'un nouvel appareil.
  static Future<List<ExtPlayEvent>> userExtPlayHistory(
      {DateTime? since, String? extKey}) async {
    final j = await _rpc('user_ext_play_history', {
      if (since != null) 'p_since': since.toUtc().toIso8601String(),
      if (extKey != null) 'p_ext_key': extKey,
    });
    if (j is! List) return const [];
    return [
      for (final e in j.whereType<Map>())
        ExtPlayEvent.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  /// Timeline UNIFIÉE des écoutes du compte (`user_play_history`, migration
  /// 221): 1 ligne par écoute, catalogue (`kind='song'`) et hors catalogue
  /// (`kind='ext'`) dans la MÊME liste, colonnes d'identité identiques à
  /// `user_play_stats`. Curseur `p_since` sur `played_at` (filtre `>=`, tri
  /// croissant), pagination `p_limit`/`p_offset`. Rétention serveur: 24 mois
  /// glissants — les cumuls (`user_play_stats`) n'expirent jamais.
  static Future<List<UserPlayEvent>> userPlayHistory({
    DateTime? since,
    String? kind,
    String? extKey,
    String? songId,
    int? limit,
    int? offset,
  }) async {
    final j = await _rpc('user_play_history', {
      if (since != null) 'p_since': since.toUtc().toIso8601String(),
      if (kind != null) 'p_kind': kind,
      if (extKey != null) 'p_ext_key': extKey,
      if (songId != null) 'p_song_id': catalogueSongId(songId) ?? songId,
      if (limit != null) 'p_limit': limit,
      if (offset != null) 'p_offset': offset,
    });
    if (j is! List) return const [];
    return [
      for (final e in j.whereType<Map>())
        UserPlayEvent.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  /// Résout une ENTRÉE jouable côté serveur (`get_song_entry`, mig 235):
  /// membre d'archive par [fileName] (repli radical inclus — cas Hexen
  /// op.wav/op.txtp), ou rang de tracklist par [entryRank]. UN paramètre par
  /// appel; introuvable = null EXPLICITE, jamais de repli sur une autre entrée
  /// — le pick générique est fermé côté serveur.
  ///
  /// ⚠️ `subsong_index` et `entry_rank` ne sont PAS interchangeables (mesuré
  /// en prod sur un .gbs: subsong 13 = rang 40, rang 13 = subsong 12). Le
  /// client historique raisonne en RANG (`<uuid>#<i>` = index de tracklist),
  /// donc les remplaçants de `narrowedToMember` passent par [entryRank].
  static Future<SearchResult?> getSongEntry(
    String songId, {
    int? subsongIndex,
    String? fileName,
    int? entryRank,
  }) async {
    final id = catalogueSongId(songId);
    if (id == null) return null;
    try {
      final uri = Uri.parse('$_baseUrl/rpc/get_song_entry');
      final resp = await http
          .post(uri,
              headers: _headers,
              body: jsonEncode({
                'p_song_id': id,
                if (subsongIndex != null) 'p_subsong_index': subsongIndex,
                if (fileName != null && fileName.isNotEmpty)
                  'p_file_name': fileName,
                if (entryRank != null) 'p_entry_rank': entryRank,
              }))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      var j = jsonDecode(resp.body);
      if (j is List) j = j.isEmpty ? null : j.first;
      return _songEntryFromJson(j);
    } catch (_) {
      return null;
    }
  }

  /// Une ENTRÉE de `get_song_entry`/`get_song_entries` → [SearchResult].
  /// fromJson mappe subsongCount depuis `track_count` (la colonne catalogue);
  /// le RPC renvoie LES DEUX sens séparés — c'est son intérêt: `subsong_count`
  /// est compté sur les entrées partageant le fichier de l'entrée (un .gbs:
  /// 49; un membre psf: 1). Préférer ce dernier, et le basename du membre
  /// par-dessus le nom d'album du conteneur.
  static SearchResult? _songEntryFromJson(dynamic j) {
    if (j is! Map) return null;
    final m = Map<String, dynamic>.from(j);
    final base = SearchResult.fromJson(m);
    final fn = (m['file_name'] ?? '').toString();
    return base.copyWith(
      subsongCount: (m['subsong_count'] as num?)?.toInt(),
      filename: fn.isNotEmpty ? fn : null,
      resolvedSubsong: true,
    );
  }

  /// Le LOT (`get_song_entries`, ≤ 50 par appel — le RPC répond 22023
  /// au-delà, d'où le découpage ici): tableau ALIGNÉ sur [refs], null aux
  /// positions non résolues — l'appelant doit savoir LAQUELLE a échoué. Une
  /// erreur réseau laisse son tronçon à null: chaque position retombe sur son
  /// chemin individuel, rien n'est perdu.
  static Future<List<SearchResult?>> getSongEntries(
      List<({String songId, int? subsongIndex, String? fileName,
          int? entryRank})> refs) async {
    final out = List<SearchResult?>.filled(refs.length, null);
    for (var start = 0; start < refs.length; start += 50) {
      final chunk = refs.sublist(
          start, (start + 50 > refs.length) ? refs.length : start + 50);
      try {
        final uri = Uri.parse('$_baseUrl/rpc/get_song_entries');
        final resp = await http
            .post(uri,
                headers: _headers,
                body: jsonEncode({
                  'p_refs': [
                    for (final r in chunk)
                      {
                        'song_id': catalogueSongId(r.songId),
                        if (r.subsongIndex != null)
                          'subsong_index': r.subsongIndex,
                        if (r.fileName != null && r.fileName!.isNotEmpty)
                          'file_name': r.fileName,
                        if (r.entryRank != null) 'entry_rank': r.entryRank,
                      }
                  ],
                }))
            .timeout(const Duration(seconds: 20));
        if (resp.statusCode != 200) continue;
        final j = jsonDecode(resp.body);
        if (j is! List) continue;
        for (var i = 0; i < chunk.length && i < j.length; i++) {
          out[start + i] = _songEntryFromJson(j[i]);
        }
      } catch (_) {/* tronçon à null, replis individuels */}
    }
    return out;
  }

  /// One-call song context (`get_song_context`): play-ready row + artists +
  /// tags by category. Returns null on any error (rails degrade gracefully).
  static Future<SongContext?> getSongContext(String songId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rpc/get_song_context');
      final resp = await http
          .post(uri, headers: _headers, body: jsonEncode({'p_song_id': catalogueSongId(songId) ?? songId}))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final j = jsonDecode(resp.body);
      // PostgREST may return the object bare or as a 1-element list.
      final m = j is List ? (j.isEmpty ? null : j.first) : j;
      if (m is! Map<String, dynamic>) return null;
      return SongContext.fromJson(m);
    } catch (_) {
      return null;
    }
  }

  /// One-call artist profile (`get_artist_details`): bio, aliases, groups, AMP
  /// handles, tags, counts. `name` is required; `artistId` disambiguates when
  /// two artists share a name (null → the server resolves by name alone).
  /// Returns null on any error — the artist screen just skips the header.
  static Future<ArtistDetails?> getArtistDetails(String name,
      {String? artistId}) async {
    try {
      final uri = Uri.parse('$_baseUrl/rpc/get_artist_details');
      final resp = await http
          .post(uri,
              headers: _headers,
              body: jsonEncode({'p_name': name, 'p_artist_id': artistId}))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final j = jsonDecode(resp.body);
      // PostgREST may return the object bare or as a 1-element list.
      final m = j is List ? (j.isEmpty ? null : j.first) : j;
      if (m is! Map<String, dynamic>) return null;
      return ArtistDetails.fromJson(m);
    } catch (_) {
      return null;
    }
  }

  /// Groups matching [q] (`search_groups`, mig 201) — the Groups search tab.
  ///
  /// Empty/omitted `q` = browse, ordered by content. **Never re-sort**: the
  /// server already ranks by relevance, then songs, then productions, then
  /// name. Preferred over `list_tags(category:'group')` — 17 ms vs ~290 ms, it
  /// tolerates typos, and `list_tags` cannot see the tag-less groups.
  static Future<List<GroupSearchResult>> searchGroups(
    String q, {
    bool fuzzy = false,
    bool onlyWithContent = false,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/rpc/search_groups');
      final resp = await http
          .post(uri,
              headers: _headers,
              body: jsonEncode({
                if (q.trim().isNotEmpty) 'q': q.trim(),
                'fuzzy': fuzzy,
                'only_with_content': onlyWithContent,
                'lim': limit,
                'from_offset': offset,
              }))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) return const [];
      final list = jsonDecode(resp.body) as List;
      final out = <GroupSearchResult>[];
      for (final e in list) {
        final row = GroupSearchResult.fromJson(e as Map<String, dynamic>);
        if (row != null) out.add(row);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// One-call group profile (`get_group_details`): demozoo note, members and
  /// per-tab counts. [tagId] WINS over the name server-side and must be passed
  /// whenever known — two groups can carry confusable names, same reason as
  /// `p_artist_id` on get_artist_details. Returns null on unknown group / any
  /// error — callers fall back to the plain tag search.
  static Future<GroupDetails?> getGroupDetails(String name,
      {String? tagId}) async {
    try {
      final uri = Uri.parse('$_baseUrl/rpc/get_group_details');
      final resp = await http
          .post(uri,
              headers: _headers,
              body: jsonEncode({'p_name': name, 'p_tag_id': tagId}))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final j = jsonDecode(resp.body);
      // PostgREST may return the object bare or as a 1-element list.
      final m = j is List ? (j.isEmpty ? null : j.first) : j;
      if (m is! Map<String, dynamic>) return null;
      final d = GroupDetails.fromJson(m);
      return d.name.isEmpty ? null : d;
    } catch (_) {
      return null;
    }
  }

  /// Demozoo note of a party (Markdown) — direct PostgREST read on
  /// `demoparties` (no RPC). Tries the exact name first, then the series
  /// (`Assembly 2004` → series `Assembly`). Null when unknown / no note.
  static Future<String?> getPartyNotes(String name) async {
    Future<String?> query(String col, String value) async {
      final uri = Uri.parse('$_baseUrl/demoparties').replace(
          queryParameters: {col: 'eq.$value', 'select': 'notes', 'limit': '1'});
      final resp = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final j = jsonDecode(resp.body);
      if (j is List && j.isNotEmpty && j.first is Map) {
        final n = (j.first as Map)['notes'];
        if (n is String && n.trim().isNotEmpty) return n;
      }
      return null;
    }

    try {
      return await query('name', name) ?? await query('series', name);
    } catch (_) {
      return null;
    }
  }
}


/// Mémoire des M3U pour la durée d'UN geste d'ouverture (« Tout lire » sur un
/// dossier, archive dépliée).
///
/// Chercher le M3U voisin d'un fichier LISTAIT tout son dossier puis relisait
/// chaque M3U pour en compter les entrées — pour CHAQUE fichier: sur un dossier
/// de n conteneurs, n listages de n entrées et n relectures du même M3U, un
/// coût qui croît comme n². Avec elle, chaque dossier est listé une fois, chaque
/// M3U lu, compté et parsé une fois. Créée et jetée par l'appelant: sa durée de
/// vie est celle du geste, donc rien n'a le temps de périmer.
class M3uLookupCache {
  /// Les fichiers `.m3u`/`.m3u8` de chaque dossier déjà listé.
  final Map<String, List<File>> m3usByDir = {};
  /// Texte de chaque M3U lu (tolérant UTF-8 / Latin-1, voir readM3uText).
  final Map<String, String> text = {};
  /// Nombre d'entrées de chaque M3U (choix de la playlist du dossier).
  final Map<String, int> entryCount = {};
  /// Sous-chansons parsées de chaque M3U retenu.
  final Map<String, List<SubsongInfo>> subs = {};
  /// En-tête parsé de chaque M3U retenu (album, artistes, bloc libre).
  final Map<String, M3uInfo?> info = {};
}

/// Où va un téléchargement: en MÉMOIRE (fichiers courts) ou dans un FICHIER
/// (archives de plusieurs centaines de Mo). Un seul cœur (`_fetchInto`) les
/// alimente, donc annulation, bannière et délais sont identiques par
/// construction — les dupliquer, c'était fabriquer deux règles qui divergent.
abstract class _FetchSink {
  Uint8List _head = Uint8List(0);
  int _length = 0;

  /// Octets reçus jusqu'ici.
  int get length => _length;

  /// Les 512 premiers octets: tout ce que regardent les reniflages
  /// (`_looksLikeHtml` s'arrête à 512, `Rar!` et gzip en prennent 4 et 2).
  Uint8List get head => _head;

  /// Fichier où l'isolate de transfert écrit, ou null pour la mémoire.
  String? get path;

  /// Avancement rapporté par l'isolate.
  void progress(int n) => _length = n;

  /// Fin du transfert.
  void finish(IsolateFetchResult r) {
    _length = r.length;
    _head = r.head;
  }

  /// Repart de zéro (rejeu après un interstitiel). Le contenu lui-même est
  /// remplacé par le transfert suivant: l'isolate ouvre le fichier en le
  /// TRONQUANT, et la mémoire est remplacée en bloc par [finish].
  Future<void> reset() async {
    _head = Uint8List(0);
    _length = 0;
  }
}

class _MemorySink extends _FetchSink {
  Uint8List? _bytes;

  @override
  String? get path => null;

  @override
  void finish(IsolateFetchResult r) {
    super.finish(r);
    _bytes = r.bytes;
  }

  Uint8List takeBytes() {
    final b = _bytes ?? Uint8List(0);
    _bytes = null;
    return b;
  }
}

class _FileSink extends _FetchSink {
  _FileSink._(this._file);
  final File _file;

  // ⚠️ L'isolate de transfert ouvre le fichier lui-même et y attend
  // `writeFrom` à CHAQUE bloc (contre-pression: un `IOSink` tamponnerait sans
  // limite quand le disque est plus lent que le réseau).
  static Future<_FileSink> open(File f) async => _FileSink._(f);

  @override
  String get path => _file.path;

  Future<void> close() async {}

  /// Échec: on efface — un `.part` resté derrière ne sert à rien.
  Future<void> discard() async {
    try { if (await _file.exists()) await _file.delete(); } catch (_) {}
  }
}
