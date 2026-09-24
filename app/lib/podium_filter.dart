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
import 'rewamp_db.dart' show CompoPodium, FacetCount;

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
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
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
