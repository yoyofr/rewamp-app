// Regrouper des collections APPARENTÉES en une seule entrée d'interface —
// joshw en compte dix-huit (`jw_*`, une par plateforme), et chaque liste de
// collections leur consacrait les deux tiers de ses lignes.
//
// Le principe: **le regroupement est une affaire d'AFFICHAGE, jamais de
// protocole.** Ce qui voyage vers le serveur reste le slug EXACT d'une
// collection membre — 39 RPC comparent `c.slug = collection_slug`, et les
// chemins de téléchargement, les UTI, la base locale raisonnent tous par slug.
// Une « famille » n'existe donc que dans les deux listes que l'utilisateur
// parcourt (le sélecteur du filtre de recherche, le navigateur de facettes),
// comme un niveau de plus: la famille se déplie en ses membres, et choisir un
// membre fait exactement ce que la liste plate faisait.
//
// Piloté par une TABLE (préfixe → libellé): la prochaine famille est une
// ligne, pas un chantier.

import 'rewamp_db.dart' show Collection;

/// Les familles connues. Le préfixe est celui des SLUGS; le libellé est un nom
/// propre (joshw est un site), donc pas une clé i18n.
const kCollectionFamilies = <({String prefix, String key, String label})>[
  (prefix: 'jw_', key: 'joshw', label: 'joshw'),
];

/// La famille d'un slug, ou null.
({String prefix, String key, String label})? collectionFamilyOf(String slug) {
  for (final f in kCollectionFamilies) {
    if (slug.startsWith(f.prefix)) return f;
  }
  return null;
}

/// Le libellé d'un MEMBRE affiché SOUS sa famille: le nom serveur débarrassé
/// du nom de famille qu'il répète (« joshw SPC (SNES) » → « SPC (SNES) »).
/// Le nom complet reste ce que montrent la pastille du filtre et le titre du
/// hub — hors de la liste dépliée, « SPC (SNES) » ne dit plus d'où il vient.
String collectionMemberLabel(Collection c, String familyLabel) {
  final name = c.name.isNotEmpty ? c.name : c.slug;
  final p = '$familyLabel ';
  if (name.toLowerCase().startsWith(p.toLowerCase()) &&
      name.length > p.length) {
    return name.substring(p.length);
  }
  return name;
}

/// Une ligne de liste de collections: une collection SEULE, ou une famille.
sealed class CollectionEntry {
  const CollectionEntry();
}

class SingleCollectionEntry extends CollectionEntry {
  final Collection collection;
  const SingleCollectionEntry(this.collection);
}

class CollectionFamilyEntry extends CollectionEntry {
  final String key;
  final String label;
  final List<Collection> members;
  const CollectionFamilyEntry(
      {required this.key, required this.label, required this.members});

  int get filesCount =>
      members.fold(0, (sum, c) => sum + c.filesCount);

  bool contains(String? slug) =>
      slug != null && members.any((c) => c.slug == slug);
}

/// Groupe [collections] pour l'affichage. L'ordre d'entrée est PRÉSERVÉ: la
/// famille prend la place de son PREMIER membre — les listes arrivent triées
/// (par nom ou par slug) et « joshw » doit se ranger là où `jw_*` se rangeait,
/// pas en tête ni en queue. Une famille d'UN seul membre reste une ligne
/// simple: un niveau qui n'abrège rien n'est que du chemin en plus.
List<CollectionEntry> groupCollections(List<Collection> collections) {
  final byFamily = <String, List<Collection>>{};
  for (final c in collections) {
    final f = collectionFamilyOf(c.slug);
    if (f != null) byFamily.putIfAbsent(f.key, () => []).add(c);
  }
  final emitted = <String>{};
  final out = <CollectionEntry>[];
  for (final c in collections) {
    final f = collectionFamilyOf(c.slug);
    if (f == null) {
      out.add(SingleCollectionEntry(c));
      continue;
    }
    final members = byFamily[f.key]!;
    if (members.length == 1) {
      out.add(SingleCollectionEntry(c));
      continue;
    }
    if (emitted.add(f.key)) {
      out.add(CollectionFamilyEntry(
          key: f.key, label: f.label, members: members));
    }
  }
  return out;
}
