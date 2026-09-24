import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/collection_families.dart';
import 'package:rewamp/rewamp_db.dart' show Collection;

/// Le regroupement joshw: une affaire d'AFFICHAGE, jamais de protocole — le
/// serveur ne connaît que les slugs exacts, et c'est un membre qui voyage.
void main() {
  Collection c(String slug, String name, [int n = 10]) =>
      Collection(slug: slug, name: name, filesCount: n);

  final cols = [
    c('hvsc', 'HVSC', 61157),
    c('jw_2sf', 'joshw 2SF (Nintendo DS)', 3316),
    c('jw_spc', 'joshw SPC (SNES)', 1918),
    c('modland', 'Modland', 299845),
  ];

  test('les jw_* se replient en UNE ligne, à la place du premier membre', () {
    final entries = groupCollections(cols);
    expect(entries.length, 3);
    expect(entries[0], isA<SingleCollectionEntry>()); // hvsc
    final fam = entries[1] as CollectionFamilyEntry;
    expect(fam.label, 'joshw');
    expect(fam.members.map((m) => m.slug), ['jw_2sf', 'jw_spc']);
    // Le compte est la SOMME: la ligne dit ce que la famille pèse.
    expect(fam.filesCount, 3316 + 1918);
    expect((entries[2] as SingleCollectionEntry).collection.slug, 'modland');
  });

  test('une famille d’UN membre reste une ligne simple', () {
    final entries = groupCollections([c('hvsc', 'HVSC'), c('jw_spc', 'joshw SPC (SNES)')]);
    expect(entries.whereType<CollectionFamilyEntry>(), isEmpty);
  });

  test('le libellé d’un membre perd le nom de famille qu’il répète', () {
    expect(collectionMemberLabel(c('jw_spc', 'joshw SPC (SNES)'), 'joshw'),
        'SPC (SNES)');
    // Un nom qui ne le répète pas reste entier — on n'ampute pas au jugé.
    expect(collectionMemberLabel(c('jw_x', 'Xbox rips'), 'joshw'), 'Xbox rips');
    // Un nom qui N'EST QUE le nom de famille reste entier aussi.
    expect(collectionMemberLabel(c('jw_y', 'joshw'), 'joshw'), 'joshw');
  });

  test('la sélection se reconnaît à travers la famille', () {
    final fam = groupCollections(cols).whereType<CollectionFamilyEntry>().first;
    expect(fam.contains('jw_spc'), isTrue);
    expect(fam.contains('hvsc'), isFalse);
    expect(fam.contains(null), isFalse);
  });

  test('collectionFamilyOf ne mord que sur le préfixe', () {
    expect(collectionFamilyOf('jw_spc')?.key, 'joshw');
    expect(collectionFamilyOf('sceneorg'), isNull);
  });
}
