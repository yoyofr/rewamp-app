import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'formats.dart' show kUadeExts;
import 'local_db.dart';
import 'rewamp_db.dart' show RewampDb;

/// Per-subsong UADE metadata (audacious-uade songdb via the server, cached
/// locally by file md5).
@immutable
class UadeSubsong {
  final int     idx;        // songdb subsong index (NOT necessarily 1-based)
  final int?    lengthMs;
  /// songdb status code (src/common/songend.h upstream):
  /// p=player(reliable) l=loop s=silence t=timeout e=error v=volume r=repeat
  /// n=NOSOUND. Combined forms exist ("p,!", "p+s"), hence the split below.
  final String? songend;
  const UadeSubsong({required this.idx, this.lengthMs, this.songend});

  /// The songdb precalc found this subsong produces NO SOUND at all — an empty
  /// slot in the module, not a missing measurement (e.g. Turrican II
  /// "World 5" idx 3, whose music is really idx 4). Upstream's own plugin
  /// filters these out by default (`skip_broken_subsongs`).
  bool get isNoSound =>
      (lengthMs ?? 0) == 0 &&
      (songend ?? '').split(RegExp(r'[,+]')).contains('n');
}

@immutable
class UadeInfo {
  final int          minSubsong;
  final int          subsongCount;   // 0 = not in the songdb
  final String?      format;
  final int?         channels;
  final List<String> authors;
  final String?      album;
  final int?         year;
  final List<UadeSubsong> subsongs;   // sorted by idx

  const UadeInfo({
    required this.minSubsong,
    required this.subsongCount,
    this.format,
    this.channels,
    this.authors = const [],
    this.album,
    this.year,
    this.subsongs = const [],
  });

  bool get isKnown => subsongCount > 0 && subsongs.isNotEmpty;

  /// [subsongs] minus the silent ones — what should actually be enqueued.
  ///
  /// Mirrors upstream's `skip_broken_subsongs` (ON by default there), including
  /// its safety net: if EVERYTHING would be filtered, keep the first entry
  /// rather than produce an unplayable file. Upstream also drops duplicates
  /// and absurd lengths, which we cannot: `is_duplicate` and the precalc
  /// timeout are not exposed by the server's get_uade_info.
  ///
  /// Callers must take the idx AND the duration from the same entry — do not
  /// mix this filtered list with [durationMsFor], which indexes the FULL one.
  List<UadeSubsong> get playableSubsongs {
    if (subsongs.isEmpty) return subsongs;
    final kept = subsongs.where((s) => !s.isNoSound).toList();
    return kept.isEmpty ? [subsongs.first] : kept;
  }

  /// Duration for the player's [subsongIdx].
  ///
  /// The index the player carries IS the songdb idx whenever the queue was
  /// built from [playableSubsongs] (it enqueues `e.idx`), so match on idx
  /// first. Only when no entry claims that idx is it read as a POSITION — the
  /// i-th UADE subsong from minSubsong — which is what a row numbered 0..n-1
  /// by some other path means. Never assumes 1-based. Same two-step rule as
  /// the NOSOUND filter in RewampDb (see its `byIdx` / position fallback).
  int? durationMsFor(int subsongIdx) {
    if (subsongs.isEmpty) return null;
    for (final s in subsongs) {
      if (s.idx == subsongIdx) return s.lengthMs;
    }
    final i = subsongIdx.clamp(0, subsongs.length - 1);
    return subsongs[i].lengthMs;
  }

  factory UadeInfo.fromJson(Map<String, dynamic> j) {
    final subs = <UadeSubsong>[];
    final rawSubs = j['subsongs'];
    if (rawSubs is List) {
      for (final e in rawSubs) {
        if (e is Map) {
          subs.add(UadeSubsong(
            idx:      (e['idx'] as num?)?.toInt() ?? 0,
            lengthMs: (e['length_ms'] as num?)?.toInt(),
            songend:  e['songend'] as String?,
          ));
        }
      }
      subs.sort((a, b) => a.idx.compareTo(b.idx));
    }
    List<String> authors = const [];
    final rawAuthors = j['authors'];
    if (rawAuthors is List) {
      authors = rawAuthors.whereType<String>().toList();
    }
    return UadeInfo(
      minSubsong:   (j['min_subsong'] as num?)?.toInt() ?? 1,
      subsongCount: (j['subsong_count'] as num?)?.toInt() ?? 0,
      format:       j['format'] as String?,
      channels:     (j['channels'] as num?)?.toInt(),
      authors:      authors,
      album:        j['album'] as String?,
      year:         (j['year'] as num?)?.toInt(),
      subsongs:     subs,
    );
  }
}

/// Resolves UADE metadata for a file: md5 → local cache → server RPC → cache.
class UadeInfoService {
  UadeInfoService._();
  static final UadeInfoService instance = UadeInfoService._();

  final Map<String, UadeInfo> _mem = {};   // md5 → info (session cache)
  /// path → md5, so an already-resolved file can be answered SYNCHRONOUSLY
  /// (hashing it means reading the whole module). Session-scoped like _mem.
  final Map<String, String> _md5ByPath = {};

  /// UADE-owned extensions we should enrich. Cheap suffix gate to avoid
  /// hashing every opened file. (Prefix-form names like "mdat.x" are handled
  /// too — the suffix set below is a superset of what actually reaches uade.)
  static bool isUadePath(String path) {
    final slash = path.lastIndexOf('/');
    final name = slash >= 0 ? path.substring(slash + 1) : path;
    // Prefix convention: "ahx.song", "mdat.name" → token before the dot.
    final firstDot = name.indexOf('.');
    if (firstDot > 0) {
      final pre = name.substring(0, firstDot).toLowerCase();
      if (_kUadePrefixes.contains(pre)) return true;
    }
    final dot = name.lastIndexOf('.');
    if (dot < 0) return false;
    return _kUadeExts.contains(name.substring(dot + 1).toLowerCase());
  }

  /// Display name of an Amiga file, prefix convention included.
  ///
  /// `p.basenameWithoutExtension` is WRONG here: modland names a TFMX module
  /// "mdat.monkey island", so the "extension" it strips is ".monkey island"
  /// and what is left is the FORMAT TOKEN — the player and the subsong screen
  /// both ended up titled "mdat". The token sits BEFORE the dot on these
  /// files, so it is the remainder that names the tune. Everything else keeps
  /// the usual basename-minus-extension.
  static String displayName(String path) {
    final slash = path.lastIndexOf(Platform.pathSeparator);
    var name = slash >= 0 ? path.substring(slash + 1) : path;
    final unixSlash = name.lastIndexOf('/');
    if (unixSlash >= 0) name = name.substring(unixSlash + 1);
    final firstDot = name.indexOf('.');
    if (firstDot > 0 &&
        _kUadePrefixes.contains(name.substring(0, firstDot).toLowerCase())) {
      final rest = name.substring(firstDot + 1).trim();
      if (rest.isNotEmpty) return rest;
    }
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  Future<String?> _md5(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      final bytes = await f.readAsBytes();
      return md5.convert(bytes).toString();
    } catch (_) {
      return null;
    }
  }

  /// Returns UADE info for [path], hitting the local cache first, then the
  /// server. Returns null if the file isn't a UADE format or md5 fails.
  Future<UadeInfo?> forPath(String path) async {
    if (!isUadePath(path)) return null;
    final md5hex = await _md5(path);
    if (md5hex == null) return null;
    _md5ByPath[path] = md5hex;
    return forMd5(md5hex);
  }

  /// What [forPath] already resolved for this file, WITHOUT touching the disk
  /// or the network — null when it was never asked.
  ///
  /// The native probe cannot count UADE subsongs (only the songdb knows), so
  /// the shell's "does the playing file hold several tunes?" test — the one
  /// that offers the link back to the subsong list — answered 1 for every
  /// Amiga module and the link never appeared. That test is synchronous, hence
  /// this accessor; it is warm by then because every UADE load resolves the
  /// per-subsong duration through [forPath].
  UadeInfo? cachedForPath(String path) {
    final md5hex = _md5ByPath[path];
    return md5hex == null ? null : _mem[md5hex];
  }

  Future<UadeInfo?> forMd5(String md5hex) async {
    if (_mem.containsKey(md5hex)) return _mem[md5hex];
    final cached = await LocalDb.instance.getUadeCache(md5hex);
    if (cached != null) {
      _mem[md5hex] = cached;
      return cached;
    }
    try {
      final info = await RewampDb.getUadeInfo(md5hex);
      if (info != null) {
        await LocalDb.instance.upsertUadeCache(md5hex, info);
        _mem[md5hex] = info;
      }
      return info;
    } catch (e) {
      debugPrint('[uade-info] $md5hex: $e');
      return null;
    }
  }

  /// Batch pre-fetch for an album's files (paths). Cheap-gates + skips cached.
  Future<void> prefetchPaths(List<String> paths) async {
    final want = <String, String>{}; // md5 → (kept for possible future use)
    for (final path in paths) {
      if (!isUadePath(path)) continue;
      final md5hex = await _md5(path);
      if (md5hex == null || _mem.containsKey(md5hex)) continue;
      if (await LocalDb.instance.getUadeCache(md5hex) != null) continue;
      want[md5hex] = path;
    }
    if (want.isEmpty) return;
    try {
      final infos = await RewampDb.getUadeInfoBatch(want.keys.toList());
      for (final entry in infos.entries) {
        await LocalDb.instance.upsertUadeCache(entry.key, entry.value);
        _mem[entry.key] = entry.value;
      }
    } catch (e) {
      debugPrint('[uade-info] batch: $e');
    }
  }
}

// La liste GÉNÉRÉE des extensions UADE (formats.dart, même source que le
// plugin C) — plus un sous-ensemble écrit à la main: la copie locale de 95
// entrées laissait ~270 formats UADE (fred, gray, dz, kris, …) sans
// enrichissement songdb, donc sans durée ni auteur. Enrichment is
// best-effort: an over-broad set just means an extra md5 + cache miss.
const _kUadeExts = kUadeExts;

// Amiga prefix-convention tokens ("mdat.NAME", "ahx.NAME"). Même vocabulaire
// que les suffixes (le plugin C sonde le token de préfixe contre la même
// liste), plus "smpl" (compagnon multifichier, jamais un suffixe).
final _kUadePrefixes = {...kUadeExts, 'smpl', 'mod'};
