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

  /// Le précalcul de la songdb a établi que ce sous-chant ne donne RIEN — un
  /// emplacement vide du module, pas une mesure manquante. Amont filtre ces
  /// entrées par défaut (`skip_broken_subsongs`), et son critère est la
  /// **longueur MESURÉE à zéro**, quel que soit le code de statut
  /// (`plugin.cc:117-122`) — pas seulement `n` (NOSOUND).
  ///
  /// ⚠️ On l'avait restreint à `n`, si bien qu'un slot `e` (erreur, 0 ms)
  /// restait dans la liste: le premier sous-chant de « m.mod » (Phornee,
  /// modland) s'y trouvait, sans durée, et le lecteur s'y arrêtait — un
  /// morceau qui ne produit rien n'a pas de fin à signaler, donc la file
  /// n'avançait jamais.
  ///
  /// ⚠️ `null` n'est PAS zéro: une durée inconnue reste jouable (beaucoup de
  /// formats n'en ont aucune). Seul un zéro EXPLICITE est un verdict.
  bool get isBroken =>
      lengthMs == 0 ||
      (songend ?? '').split(RegExp(r'[,+]')).contains('n');

  @Deprecated('Renommé isBroken: le critère amont est la longueur nulle, pas '
      'le seul code NOSOUND.')
  bool get isNoSound => isBroken;
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
  ///
  /// Garde-fou d'amont conservé: si TOUT serait filtré, on garde la première
  /// entrée — mieux vaut un sous-chant douteux qu'un fichier qui n'a plus
  /// aucune piste.
  List<UadeSubsong> get playableSubsongs {
    if (subsongs.isEmpty) return subsongs;
    final kept = subsongs.where((s) => !s.isBroken).toList();
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

  /// Un `.mod` que UADE joue: il porte un COMPAGNON de synthèse.
  ///
  /// Startrekker AM et Audio Sculpture sont des modules 31 instruments
  /// ordinaires — extension `.mod`, en-tête de ProTracker — dont le seul signe
  /// distinctif est un fichier VOISIN `NOM.mod.as` / `.nt` portant les
  /// instruments de synthèse. [isUadePath], qui ne regarde que le nom, répond
  /// donc NON, et `mod` n'a rien à faire dans les extensions UADE (on volerait
  /// tous les MOD à libopenmpt, qui les joue mieux). Même règle que la sonde
  /// native `uade_companion_is_audiosculpture`, sans la lecture de magie: ici
  /// on ne décide pas du MOTEUR, seulement s'il vaut la peine d'interroger la
  /// songdb — le pire cas est une requête pour rien.
  ///
  /// Mesuré le 2026-09-06: « m.mod » (Phornee, modland) + « m.mod.as » est
  /// connu de la songdb (8 sous-chants, durées), et l'écran de détail
  /// n'affichait AUCUNE durée faute de passer ce portillon.
  static bool hasAmigaSynthCompanion(String path) {
    if (path.isEmpty) return false;
    for (final suffix in const ['.as', '.AS', '.nt', '.NT']) {
      if (File('$path$suffix').existsSync()) return true;
    }
    return false;
  }

  /// [isUadePath] pour un chemin RÉEL: le nom, ou le compagnon de synthèse.
  /// À n'utiliser que là où le fichier est déjà sur le disque — ailleurs, le
  /// test de nom reste le seul possible.
  static bool isUadeFileAt(String path) =>
      isUadePath(path) || hasAmigaSynthCompanion(path);

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
    // ⚠️ Le portillon du SERVICE, pas seulement celui des appelants: il a un
    // CHEMIN réel (il s'apprête à md5 le fichier), donc il teste aussi le
    // compagnon de synthèse. Corriger les appelants sans corriger celui-ci
    // laissait « m.mod » sans durée malgré la branche UADE prise.
    if (!isUadeFileAt(path)) return null;
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
      if (!isUadeFileAt(path)) continue;
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

/// Le même vocabulaire, pour qui doit décider « ce nom est-il de forme
/// PRÉFIXE ? » hors de cette classe (la migration des noms de pochettes).
bool isUadePrefixToken(String token) =>
    _kUadePrefixes.contains(token.toLowerCase());
