// La lecture automatique (∞) décide HORS réseau: ces tests injectent des
// sources en mémoire et vérifient la cascade, les exclusions et les bornes.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/autoplay.dart';
import 'package:rewamp/rewamp_db.dart';

SearchResult row(String id, {String? artist, int? subsongs}) => SearchResult(
      songId: id,
      collection: 'modland',
      title: id,
      filename: '$id.mod',
      formatExt: 'mod',
      downloadUrl: null,
      fileSize: 1,
      year: null,
      artistNames: [if (artist != null) artist],
      totalCount: 1,
      album: null,
      subsongCount: subsongs,
    );

/// Un catalogue de poche: une liste par question (clé = `AutoplayQuery.key`
/// sans la limite), et le journal des questions posées.
class FakeSources {
  final Map<AutoplaySource, List<SearchResult>> bySource;
  final Map<String, List<String>> groups;
  final asked = <AutoplayQuery>[];
  final failing = <AutoplaySource>{};

  FakeSources(this.bySource, {this.groups = const {}});

  Future<List<SearchResult>> fetch(AutoplayQuery q) async {
    asked.add(q);
    if (failing.contains(q.source)) throw Exception('réseau');
    return bySource[q.source] ?? const [];
  }

  Future<List<String>> groupsOf(String? id, String? name) async =>
      groups[id ?? name] ?? const [];
}

AutoplayPlanner planner(FakeSources s) => AutoplayPlanner(
      fetch: s.fetch,
      groupsOf: s.groupsOf,
      rand: Random(1),
    );

const seed = AutoplaySeed(
    artistIds: ['a1'], artistNames: ['4-Mat'], collection: 'modland',
    platform: 'PC');

void main() {
  test('auto: l\'artiste n\'a que la MOITIÉ, la collection assure le reste',
      () async {
    final s = FakeSources({
      AutoplaySource.artist: [for (var i = 0; i < 20; i++) row('art$i')],
      AutoplaySource.collection: [for (var i = 0; i < 20; i++) row('col$i')],
    });
    final out = await planner(s).plan(
        mode: AutoplayMode.auto, seeds: [seed], exclude: {}, size: 10);
    expect(out.length, 10);
    expect(out.where((r) => r.songId.startsWith('art')).length, 5);
    expect(out.where((r) => r.songId.startsWith('col')).length, 5);
    // L'artiste d'abord, la collection ensuite — l'ordre de jeu suit la
    // préférence même si les parts sont égales.
    expect(out.first.songId, startsWith('art'));
  });

  test('auto: un monde où SEUL l\'artiste répond reste rempli (2e tour)',
      () async {
    final s = FakeSources({
      AutoplaySource.artist: [for (var i = 0; i < 20; i++) row('art$i')],
    });
    final out = await planner(s).plan(
        mode: AutoplayMode.auto, seeds: [seed], exclude: {}, size: 10);
    expect(out.length, 10);
    // La source n'est consultée qu'UNE fois malgré les deux tours.
    expect(s.asked.where((q) => q.source == AutoplaySource.artist).length, 1);
  });

  test('un mode FORCÉ n\'a pas de quota', () async {
    final s = FakeSources({
      AutoplaySource.artist: [for (var i = 0; i < 20; i++) row('art$i')],
    });
    final out = await planner(s).plan(
        mode: AutoplayMode.artist, seeds: [seed], exclude: {}, size: 10);
    expect(out.length, 10);
  });

  test('auto: cascade artiste → groupes → collection quand il en manque',
      () async {
    final s = FakeSources({
      AutoplaySource.artist: [row('art1'), row('art2')],
      AutoplaySource.group: [row('grp1')],
      AutoplaySource.collection: [for (var i = 0; i < 10; i++) row('col$i')],
    }, groups: {'a1': ['Anarchy']});
    final out = await planner(s).plan(
        mode: AutoplayMode.auto, seeds: [seed], exclude: {}, size: 6);
    expect(out.length, 6);
    // L'ordre de préférence est respecté: les deux de l'artiste d'abord,
    // puis le groupe, puis la collection pour combler.
    expect(out.take(2).map((r) => r.songId).toSet(), {'art1', 'art2'});
    expect(out[2].songId, 'grp1');
    expect(out.skip(3).every((r) => r.songId.startsWith('col')), isTrue);
    final sources = s.asked.map((q) => q.source).toList();
    // La collection à la MÊME plateforme a suffi: la question « toute la
    // collection » n'est jamais posée quand on est déjà plein — et chaque
    // question n'est posée qu'une fois, quel que soit le nombre de tours.
    expect(sources, [
      AutoplaySource.artist,
      AutoplaySource.group,
      AutoplaySource.collection,
    ]);
    expect(s.asked[1].groupName, 'Anarchy');
    expect(s.asked[2].platform, 'PC');
  });

  test('la collection ENTIÈRE n\'est demandée que si la plateforme ne '
      'suffit pas', () async {
    var calls = 0;
    final s = FakeSources({});
    final out = await AutoplayPlanner(
      fetch: (q) async {
        calls++;
        return q.platform == null ? [row('any1'), row('any2')] : [row('pc1')];
      },
      groupsOf: s.groupsOf,
      rand: Random(1),
    ).plan(mode: AutoplayMode.collection, seeds: [seed], exclude: {}, size: 3);
    expect(out.first.songId, 'pc1');
    expect(out.map((r) => r.songId).toSet(), {'pc1', 'any1', 'any2'});
    expect(calls, 2);
  });

  test('ce qui est exclu (file, écoutes récentes) ne revient pas, ni deux '
      'sous-chansons du même fichier; un conteneur, lui, COMPTE', () async {
    final s = FakeSources({
      AutoplaySource.artist: [
        row('inqueue'),
        row('heard'),
        row('sid', subsongs: 12),
        row('same#1'),
        row('same#2'),
        row('ok'),
      ],
    });
    final out = await planner(s).plan(
        mode: AutoplayMode.artist,
        seeds: [seed],
        exclude: {'inqueue', 'heard'},
        size: 10);
    expect(out.map((r) => AutoplayPlanner.fileIdOf(r.songId)).toSet(),
        {'sid', 'same', 'ok'});
  });

  test('un mode forcé ne consulte que sa source', () async {
    final s = FakeSources({
      AutoplaySource.artist: [row('art1')],
      AutoplaySource.collection: [row('col1')],
    });
    final out = await planner(s).plan(
        mode: AutoplayMode.collection, seeds: [seed], exclude: {}, size: 5);
    expect(out.map((r) => r.songId), ['col1']);
    expect(s.asked.every((q) => q.source == AutoplaySource.collection), isTrue);
  });

  test('une source qui lève est sautée, pas fatale', () async {
    final s = FakeSources({
      AutoplaySource.artist: [row('art1')],
      AutoplaySource.collection: [row('col1')],
    })..failing.add(AutoplaySource.artist);
    final out = await planner(s).plan(
        mode: AutoplayMode.auto, seeds: [seed], exclude: {}, size: 5);
    expect(out.map((r) => r.songId), ['col1']);
  });

  test('une ligne LOCALE sans id d\'artiste interroge par NOM', () async {
    final s = FakeSources({AutoplaySource.artist: [row('art1')]});
    const local = AutoplaySeed(artistNames: ['Jogeir Liljedahl']);
    await planner(s).plan(
        mode: AutoplayMode.artist, seeds: [local], exclude: {}, size: 5);
    expect(s.asked.single.artistId, isNull);
    expect(s.asked.single.artistName, 'Jogeir Liljedahl');
  });

  test('la même question n\'est posée qu\'une fois par plan', () async {
    final s = FakeSources({AutoplaySource.artist: []});
    await planner(s).plan(
        mode: AutoplayMode.artist, seeds: [seed, seed], exclude: {}, size: 5);
    expect(s.asked.length, 1);
  });

  test('sans graine ou sans taille: rien, et aucune question', () async {
    final s = FakeSources({AutoplaySource.artist: [row('art1')]});
    expect(await planner(s).plan(
        mode: AutoplayMode.auto, seeds: [], exclude: {}, size: 5), isEmpty);
    expect(await planner(s).plan(
        mode: AutoplayMode.auto, seeds: [seed], exclude: {}, size: 0), isEmpty);
    expect(s.asked, isEmpty);
  });

  test('fileIdOf retire le rang et la sous-chanson', () {
    expect(AutoplayPlanner.fileIdOf('u#3'), 'u');
    expect(AutoplayPlanner.fileIdOf('u?subsong=2'), 'u');
    expect(AutoplayPlanner.fileIdOf('u'), 'u');
  });
}
