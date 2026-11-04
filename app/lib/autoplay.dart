// Lecture automatique (le « ∞ » d'Apple Music): quand la file touche à sa
// fin, des morceaux PROCHES de ce qui vient de jouer y sont ajoutés, et la
// musique continue.
//
// Ce fichier ne contient que la DÉCISION — quels morceaux, dans quel ordre —
// hors de tout widget et de tout réseau, pour être testable à sec. Les
// sources (artiste, groupes, collection) sont des fonctions injectées; la
// coquille (app_shell) fournit les vraies, branchées sur rewamp_db, et pose
// les entrées dans la file.
//
// Deux règles que la coquille respecte:
//   * on remplit AVANT la fin: dès que la piste en cours est l'avant-dernière
//     (ou la dernière), pour que le pré-téléchargement ait le temps d'atterrir;
//   * ce qui est ajouté est MARQUÉ (`autoplay`): le panneau le montre, et
//     couper le ∞ retire ce qui n'a pas encore joué — jamais ce qui a joué.
import 'dart:math';

import 'rewamp_db.dart' show SearchResult;

/// Comment les morceaux sont choisis. L'ordre des valeurs est celui du
/// sélecteur de Réglages; la valeur persistée est le NOM, pas l'index.
enum AutoplayMode {
  /// Cascade: même artiste, puis les groupes de l'artiste, puis la collection
  /// (même plateforme d'abord). Les graines viennent de la FIN de la file.
  auto,

  /// Seulement les artistes qui viennent de jouer.
  artist,

  /// Seulement les groupes auxquels ces artistes appartiennent.
  group,

  /// Seulement la collection (et plateforme) de ce qui vient de jouer.
  collection,

  /// Même cascade que [auto], mais les graines viennent de l'HISTORIQUE
  /// d'écoute, pas seulement de la file.
  recent;

  static AutoplayMode fromName(String? n) =>
      AutoplayMode.values.firstWhere((m) => m.name == n,
          orElse: () => AutoplayMode.auto);
}

/// Ce que le planificateur sait d'UN morceau de référence (la fin de la file,
/// ou une écoute récente). Un identifiant d'artiste est préféré au nom
/// (homonymes); un nom seul vaut pour une ligne LOCALE, qui n'en a pas.
class AutoplaySeed {
  final List<String> artistIds;
  final List<String> artistNames;
  final String? collection;
  final String? platform;

  const AutoplaySeed({
    this.artistIds = const [],
    this.artistNames = const [],
    this.collection,
    this.platform,
  });

  bool get hasArtist => artistIds.isNotEmpty || artistNames.isNotEmpty;
}

enum AutoplaySource { artist, group, collection }

/// Une question posée à une source. Pour [AutoplaySource.collection],
/// [platform] nul = toute la collection.
class AutoplayQuery {
  final AutoplaySource source;
  final String? artistId;
  final String? artistName;
  final String? groupName;
  final String? collection;
  final String? platform;
  final int limit;

  const AutoplayQuery._({
    required this.source,
    this.artistId,
    this.artistName,
    this.groupName,
    this.collection,
    this.platform,
    required this.limit,
  });

  const AutoplayQuery.artist({String? id, String? name, required int limit})
      : this._(source: AutoplaySource.artist, artistId: id, artistName: name,
            limit: limit);
  const AutoplayQuery.group(String name, {required int limit})
      : this._(source: AutoplaySource.group, groupName: name, limit: limit);
  const AutoplayQuery.collection(String slug,
      {String? platform, required int limit})
      : this._(source: AutoplaySource.collection, collection: slug,
            platform: platform, limit: limit);

  /// Deux questions identiques ne sont posées qu'une fois par plan.
  String get key => '${source.name}|$artistId|$artistName|$groupName|'
      '$collection|$platform';
}

/// Rend des candidats pour une question — des lignes du catalogue, dans un
/// ordre quelconque (le planificateur mélange). Une erreur réseau se LÈVE: le
/// planificateur la rattrape et passe à la question suivante.
typedef AutoplayFetch = Future<List<SearchResult>> Function(AutoplayQuery q);

/// Les groupes (demozoo) d'un artiste, par nom ou id.
typedef AutoplayGroupsOf = Future<List<String>> Function(
    String? artistId, String? artistName);

class AutoplayPlanner {
  final AutoplayFetch fetch;
  final AutoplayGroupsOf groupsOf;

  /// Une ligne à écarter d'office (rien par défaut: un fichier à
  /// sous-chansons compte pour UN morceau, la coquille le déplie — voir
  /// AppShell._maybeFillAutoplay).
  final bool Function(SearchResult) isExcluded;
  final Random rand;

  AutoplayPlanner({
    required this.fetch,
    required this.groupsOf,
    bool Function(SearchResult)? isExcluded,
    Random? rand,
  })  : isExcluded = isExcluded ?? ((_) => false),
        rand = rand ?? Random();

  /// Part MAXIMALE de chaque source en mode automatique, en premier tour.
  /// Sans quota, un artiste prolifique sans groupe remplissait tout — et
  /// comme les graines suivantes sont la fin de la file, on ne sortait plus
  /// jamais de lui. Avec la collection assurée d'au moins la moitié, la fin de
  /// file apporte d'autres artistes au tour d'après. Ce qu'une source
  /// n'utilise pas coule vers les suivantes; un second tour sans quota comble
  /// ce qui manque encore (un monde où seul l'artiste répond reste rempli).
  static const double kArtistShare = 0.5;
  static const double kGroupShare = 0.25;

  /// Au plus [size] morceaux, dans l'ordre où les jouer.
  ///
  /// [seeds] du plus récent au plus ancien; [exclude] = identifiants de
  /// morceaux à ne pas reproposer (toute la file, les écoutes récentes).
  /// Chaque source est demandée un peu plus large que ce qui manque, pour
  /// qu'après exclusion il en reste.
  Future<List<SearchResult>> plan({
    required AutoplayMode mode,
    required List<AutoplaySeed> seeds,
    required Set<String> exclude,
    required int size,
  }) async {
    if (size <= 0 || seeds.isEmpty) return const [];
    final picked = <SearchResult>[];
    final taken = <String>{...exclude};
    final queries = <AutoplayQuery>[];
    final seen = <String>{};
    for (final q in await _queries(mode, seeds, size)) {
      if (seen.add(q.key)) queries.add(q);
    }
    // Les candidats d'une question, reçus UNE fois, mélangés une fois: le
    // second tour reprend là où le quota avait arrêté le premier.
    final pool = <String, List<SearchResult>>{};
    Future<List<SearchResult>> candidates(AutoplayQuery q) async {
      final cached = pool[q.key];
      if (cached != null) return cached;
      List<SearchResult> rows;
      try {
        rows = await fetch(q);
      } catch (_) {
        rows = const []; // une source muette n'empêche pas les suivantes
      }
      final fresh = <SearchResult>[
        for (final r in rows)
          if (fileIdOf(r.songId).isNotEmpty && !isExcluded(r)) r,
      ]..shuffle(rand);
      return pool[q.key] = fresh;
    }

    final quota = (mode == AutoplayMode.auto || mode == AutoplayMode.recent)
        ? {
            AutoplaySource.artist: (size * kArtistShare).ceil(),
            AutoplaySource.group: (size * kGroupShare).ceil(),
            AutoplaySource.collection: size,
          }
        : const <AutoplaySource, int>{};
    final bySource = <AutoplaySource, int>{};

    for (final capped in [true, false]) {
      for (final q in queries) {
        if (picked.length >= size) return picked;
        var room = size - picked.length;
        if (capped && quota.isNotEmpty) {
          room = min(room, quota[q.source]! - (bySource[q.source] ?? 0));
          if (room <= 0) continue;
        }
        for (final r in await candidates(q)) {
          if (room <= 0) break;
          if (!taken.add(fileIdOf(r.songId))) continue;
          picked.add(r);
          bySource[q.source] = (bySource[q.source] ?? 0) + 1;
          room--;
        }
      }
      if (quota.isEmpty) break; // un mode forcé n'a qu'un tour
    }
    return picked;
  }

  /// L'identité de FICHIER d'une ligne: le rang `#i` et le `?subsong=`
  /// désignent une sous-chanson, et deux sous-chansons d'un même fichier
  /// seraient deux fois le même module dans la file.
  static String fileIdOf(String songId) =>
      songId.split('#').first.split('?').first;

  /// Les questions, dans l'ordre de PRÉFÉRENCE. Une graine plus récente passe
  /// avant une plus ancienne au sein de chaque source.
  Future<List<AutoplayQuery>> _queries(
      AutoplayMode mode, List<AutoplaySeed> seeds, int size) async {
    // Un peu plus large que ce qui manque: les exclusions prennent leur part.
    final limit = size * 3;
    final out = <AutoplayQuery>[];

    void artists() {
      for (final s in seeds) {
        for (final id in s.artistIds) {
          out.add(AutoplayQuery.artist(id: id, limit: limit));
        }
        if (s.artistIds.isEmpty) {
          for (final n in s.artistNames) {
            out.add(AutoplayQuery.artist(name: n, limit: limit));
          }
        }
      }
    }

    Future<void> groups() async {
      for (final s in seeds) {
        final ids = s.artistIds.isNotEmpty
            ? s.artistIds
            : List<String?>.filled(s.artistNames.length, null);
        for (var i = 0; i < ids.length; i++) {
          final name = i < s.artistNames.length ? s.artistNames[i] : null;
          List<String> gs;
          try {
            gs = await groupsOf(ids[i], name);
          } catch (_) {
            continue;
          }
          for (final g in gs) {
            out.add(AutoplayQuery.group(g, limit: limit));
          }
        }
      }
    }

    void collections() {
      for (final s in seeds) {
        final c = s.collection;
        if (c == null || c.isEmpty) continue;
        if (s.platform != null && s.platform!.isNotEmpty) {
          out.add(AutoplayQuery.collection(c, platform: s.platform,
              limit: limit));
        }
      }
      for (final s in seeds) {
        final c = s.collection;
        if (c == null || c.isEmpty) continue;
        out.add(AutoplayQuery.collection(c, limit: limit));
      }
    }

    switch (mode) {
      case AutoplayMode.artist:
        artists();
      case AutoplayMode.group:
        await groups();
      case AutoplayMode.collection:
        collections();
      case AutoplayMode.auto:
      case AutoplayMode.recent:
        artists();
        await groups();
        collections();
    }
    return out;
  }
}
