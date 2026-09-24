// Les « saveurs » d'une collection qui sont des TAGS DE PUCE.
//
// Le cas qui l'a demandé (2026-09-15): la collection `midi` mélange deux
// choses qu'on n'écoute pas de la même façon — 12 052 morceaux écrits pour le
// General MIDI et 1 454 pour le Roland MT-32 (554 albums contre 62). Les deux
// sont DÉJÀ étiquetés côté serveur, catégorie `chip`, par l'import de la
// collection: rien à ajouter là-bas, il manquait seulement de quoi choisir.
//
// ⚠️ Pourquoi une table ÉCRITE À LA MAIN plutôt qu'une facette:
//   - `search_facets` ne rend que trois axes — collection, format, plateforme.
//     Vérifié sur `midi` ET sur `vgmrips`: aucun axe `chip`, donc la feuille de
//     filtres ne peut pas l'apprendre;
//   - `list_tags` n'a AUCUN paramètre de collection, et c'est explicite chez
//     l'amont (migration serveur 243: « hors portée volontairement »). Demander
//     « quelles puces dans cette collection ? » n'a donc pas de réponse
//     aujourd'hui.
// Le jour où `search_facets` gagne un axe `chip`, cette table disparaît et la
// feuille de filtres l'affiche pour TOUTE collection — voir
// docs/chip_facet_proposal.md.
//
// Les valeurs sont les NOMS de tags, pas les slugs: c'est ce que le serveur
// apparie (`tags TEXT[]`, insensible à la casse, jamais les slugs — voir
// `_tagParams`). Des noms propres, donc rien à traduire.
library;

const Map<String, List<String>> kCollectionChipAxis = {
  'midi': ['General MIDI', 'MT-32'],
};

/// Les choix de puce d'une collection, vide quand il n'y en a pas.
List<String> chipAxisFor(String? collectionSlug) =>
    (collectionSlug == null ? null : kCollectionChipAxis[collectionSlug]) ??
    const [];
