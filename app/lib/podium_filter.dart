// Filtre « podium » des listings (p_podium côté serveur).
//
// Contrat: null = pas de filtre, 0 = n'importe quel podium, 1, 2 ou 3 = CE
// rang exactement. Le rang est le MEILLEUR du morceau / de l'album — celui
// qu'affiche le badge (compo_podium.rank) —, donc filtre et badge sont
// toujours d'accord, et les trois rangs se partagent les entrées sans doublon:
// le compte « tous podiums » est leur SOMME. Toute autre valeur fait répondre
// le serveur en 400: on borne ici, une fois.
//
// La facette arrive de search_facets avec facet_kind = 'podium' et UNE ligne
// par rang (value '1' / '2' / '3', en chaîne), triée par COMPTE: on reclasse
// par rang, et un rang absent vaut 0.

import 'package:flutter/material.dart';

import 'competition_screen.dart' show podiumColor;
import 'l10n.dart';
import 'rewamp_db.dart' show CompoPodium, FacetCount, PodiumCriteria;
import 'sheet_handle.dart';

// ---------------------------------------------------------------------------
// Dimensions d'un podium (mig serveur 285, navigateur « Podiums »): nature,
// genre de compo, série de party, année de compo. Les valeurs sont celles de
// PodiumCriteria; les libellés viennent de l'ARB (un enum ne porte pas de
// libellé const — règle i18n), avec repli sur la valeur brute pour un genre
// que le serveur inventerait après nous.
// ---------------------------------------------------------------------------

/// Libellé d'un genre de compo (`compo_kind`).
String compoKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
      'tracked'    => l10n.compoKindTracked,
      'chip'       => l10n.compoKindChip,
      'streaming'  => l10n.compoKindStreaming,
      'executable' => l10n.compoKindExecutable,
      'oldskool'   => l10n.compoKindOldskool,
      'combined'   => l10n.compoKindCombined,
      'soundtrack' => l10n.compoKindSoundtrack,
      _            => kind,
    };

/// Une ligne d'explication par genre — « combined » ou « oldskool » ne se
/// comprennent pas sans elle (c'est la pédagogie que la revue serveur
/// demandait au lieu d'un `other`).
String? compoKindHint(AppLocalizations l10n, String kind) => switch (kind) {
      'tracked'    => l10n.compoKindTrackedHint,
      'chip'       => l10n.compoKindChipHint,
      'streaming'  => l10n.compoKindStreamingHint,
      'executable' => l10n.compoKindExecutableHint,
      'oldskool'   => l10n.compoKindOldskoolHint,
      'combined'   => l10n.compoKindCombinedHint,
      'soundtrack' => l10n.compoKindSoundtrackHint,
      _            => null,
    };

/// Libellé de la nature d'un podium (`via`): compo de musique ou bande-son.
String podiumViaLabel(AppLocalizations l10n, String via) => switch (via) {
      'production' => l10n.podiumViaProduction,
      _            => l10n.podiumViaSelf,
    };

/// Comptes d'une facette de dimension, triés par compte décroissant.
/// `kind` ∈ podium_via | compo_kind | party_series | compo_year.
List<FacetCount> podiumDimFacets(Iterable<FacetCount> facets, String kind) {
  final out = [for (final f in facets) if (f.kind == kind && f.value.isNotEmpty) f];
  out.sort((a, b) => b.count.compareTo(a.count));
  return out;
}

/// La décennie d'une année (1993 → 1990).
int decadeOf(int year) => year - year % 10;

/// Facette `compo_year` agrégée en DÉCENNIES, ordre chronologique. Le serveur
/// rend l'année en chaîne, une ligne par année; le client fait les tranches
/// (la revue: 1980 → 219, 1990 → 6 111, 2000 → 5 685, 2010 → 4 366, 2020 →
/// 2 671). Une tranche sans podium n'apparaît pas.
List<({int decade, int count})> decadeCounts(Iterable<FacetCount> facets) {
  final by = <int, int>{};
  for (final f in facets) {
    if (f.kind != 'compo_year') continue;
    final y = int.tryParse(f.value);
    if (y == null) continue;
    by.update(decadeOf(y), (c) => c + f.count, ifAbsent: () => f.count);
  }
  final keys = by.keys.toList()..sort();
  return [for (final d in keys) (decade: d, count: by[d]!)];
}

/// Libellé d'une tranche de décennie (« 1990s », « Années 1990 »). Chaque
/// décennie qui a des podiums a sa tuile — le plus ancien podium du
/// catalogue date de 1986, rien ne précède la tuile 1980.
String decadeLabel(AppLocalizations l10n, int decade) =>
    l10n.podiumDecadeLabel('$decade');

/// Les bornes d'année de compo d'une décennie.
PodiumCriteria decadeCriteria(PodiumCriteria base, int decade) =>
    base.copyWith(yearMin: decade, yearMax: decade + 9);

/// Une seule année de compo.
PodiumCriteria yearCriteria(PodiumCriteria base, int year) =>
    base.copyWith(yearMin: year, yearMax: year);

/// Les années d'une facette `compo_year`, ordre chronologique, avec compte.
List<({int year, int count})> yearCounts(Iterable<FacetCount> facets) {
  final out = <({int year, int count})>[];
  for (final f in facets) {
    if (f.kind != 'compo_year') continue;
    final y = int.tryParse(f.value);
    if (y != null) out.add((year: y, count: f.count));
  }
  out.sort((a, b) => a.year.compareTo(b.year));
  return out;
}

/// Libellé court de la tranche d'années d'un critère (puce « Époque »):
/// « 1990s », « 1995 », « 1995 – 2003 ».
String? eraLabel(AppLocalizations l10n, PodiumCriteria c) {
  final a = c.yearMin, b = c.yearMax;
  if (a == null && b == null) return null;
  if (a != null && b != null) {
    if (a == b) return '$a';
    if (a % 10 == 0 && b == a + 9) return decadeLabel(l10n, a);
    return '$a – $b';
  }
  return a != null ? '$a –' : '– $b';
}

/// La valeur envoyée au serveur: 0-3, sinon RIEN (jamais un 400).
int? podiumParam(int? v) => (v != null && v >= 0 && v <= 3) ? v : null;

/// Relit une recherche récente: l'ancien format était un booléen
/// (« avec podium ») — il vaut « n'importe quel podium ».
int? podiumFromStored(Object? raw) {
  if (raw == true) return 0;
  if (raw is num) return podiumParam(raw.toInt());
  return null;
}

/// Cette entrée passe-t-elle le filtre? (côté client: albums d'un artiste,
/// et page reçue d'un serveur qui ne connaît pas encore p_podium).
bool podiumMatches(CompoPodium? p, int? filter) {
  if (filter == null) return true;
  if (p == null) return false;
  return filter == 0 || p.rank == filter;
}

/// Comptes par rang de la facette 'podium' — reclassés, rang absent = 0.
Map<int, int> podiumCounts(Iterable<FacetCount> facets) {
  final out = <int, int>{1: 0, 2: 0, 3: 0};
  for (final f in facets) {
    if (f.kind != 'podium') continue;
    final r = int.tryParse(f.value);
    if (r != null && out.containsKey(r)) out[r] = f.count;
  }
  return out;
}

/// Mêmes comptes, calculés sur une liste COMPLÈTE déjà chargée.
Map<int, int> podiumCountsOf(Iterable<CompoPodium?> podiums) {
  final out = <int, int>{1: 0, 2: 0, 3: 0};
  for (final p in podiums) {
    if (p != null && out.containsKey(p.rank)) out[p.rank] = out[p.rank]! + 1;
  }
  return out;
}

int podiumTotal(Map<int, int> counts) => counts.values.fold(0, (a, b) => a + b);

String podiumRankLabel(AppLocalizations l10n, int rank) => switch (rank) {
      1 => l10n.podiumFirst,
      2 => l10n.podiumSecond,
      _ => l10n.podiumThird,
    };

/// « Podium (N) » au repos, « Podium : 2e » une fois choisi.
String podiumChipLabel(AppLocalizations l10n, int? current, int total) {
  if (current == null) {
    return total > 0 ? '${l10n.searchPodium} ($total)' : l10n.searchPodium;
  }
  return l10n.searchFacetSelected(l10n.searchPodium,
      current == 0 ? l10n.searchPodiumAny : podiumRankLabel(l10n, current));
}

/// Le choix: -1 = retirer le filtre, 0-3 = filtrer, null = fermé sans choix.
Future<int?> showPodiumPicker(BuildContext context,
    {required int? current, required Map<int, int> counts}) {
  final l10n = context.l10n;
  Widget tile(BuildContext ctx, int value, String label, int? n, {Color? color}) =>
      ListTile(
        leading: Icon(value < 0 ? Icons.clear_all : Icons.emoji_events, color: color),
        title: Text(label),
        trailing: n == null ? null : Text('$n'),
        selected: value < 0 ? current == null : value == current,
        onTap: () => Navigator.of(ctx).pop(value),
      );
  // isScrollControlled: sans lui une feuille modale est plafonnée à ~9/16 de
  // l'écran, et les cinq lignes débordaient d'une fenêtre basse (221 px sur
  // macOS). Le défilement couvre les écrans vraiment courts.
  return showHandleSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tile(ctx, -1, l10n.searchFilterAll, null),
            tile(ctx, 0, l10n.searchPodiumAny, podiumTotal(counts)),
            for (final r in const [1, 2, 3])
              tile(ctx, r, podiumRankLabel(l10n, r), counts[r], color: podiumColor(ctx, r)),
          ],
        ),
      ),
    ),
  );
}
