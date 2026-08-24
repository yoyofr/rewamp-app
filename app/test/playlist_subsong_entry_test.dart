// Une entrée de playlist qui vise UNE sous-chanson d'un fichier multi-pistes.
//
// Le serveur répond avec le FICHIER (un seul `song_id`, `track_count` de toutes
// ses sous-chansons) et garde l'index dans `ext_ref` — c'est ce qui fait
// survivre une entrée de conteneur d'un appareil à l'autre. Le client le jetait:
// les 21 entrées d'une playlist TFMX visaient toutes la sous-chanson 0 du même
// fichier, et chacune se disait encore le fichier ENTIER — « Tout lire » mettait
// donc 61 lignes dans la queue (21 + 21 + 19: les deux entrées dépliées
// avidement re-explosaient en 21 chacune) au lieu de 21.
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

SearchResult _container(String uuid) => SearchResult(
      songId: uuid,
      collection: 'modland',
      title: 'monkey island',
      filename: 'mdat.monkey island',
      album: null,
      formatExt: 'mdat',
      downloadUrl: 'https://example.invalid/mdat.monkey%20island',
      fileSize: 0,
      year: null,
      totalCount: 0,
      artistNames: const ['Chris Huelsbeck'],
      subsongCount: 22,
    );

void main() {
  const uuid = '7b9df3ff-cb1a-5ca9-838c-e3cd34cfeeba';

  test('la ligne épinglée porte la sous-chanson DANS son identité', () {
    final r = _container(uuid).withSubsongEntry(3);
    expect(r.subsongIdx, 3);
    expect(r.songId, '$uuid#3');
    // Le compte du FICHIER est conservé: il est vrai, et c'est ce dont une
    // relance hors ligne a besoin pour reconstruire la queue.
    expect(r.subsongCount, 22);
  });

  test('le `#N` est ce que le serveur attend comme sous-chanson', () {
    expect(catalogueSongRef(_container(uuid).withSubsongEntry(17).songId),
        (uuid, 17));
  });

  test('épingler deux fois n\'empile pas les suffixes', () {
    final twice = _container(uuid).withSubsongEntry(3).withSubsongEntry(5);
    expect(twice.songId, '$uuid#5');
    expect(twice.subsongIdx, 5);
  });

  test('les entrées d\'un même fichier sont NUMÉROTÉES à l\'affichage', () {
    // Le catalogue ne connaît que le FICHIER: 21 entrées, 21 fois le même
    // titre. Le numéro est la POSITION parmi les entrées de ce fichier —
    // calculée à la lecture, donc visible par TOUT LE MONDE et pas seulement
    // sur l'appareil qui a créé la playlist.
    final rows = RewampDb.numberSubsongTitles([
      for (var i = 0; i < 3; i++) _container(uuid).withSubsongEntry(i),
    ]);
    expect(rows.map((r) => r.displayTitle),
        ['monkey island (1)', 'monkey island (2)', 'monkey island (3)']);
    // L'identité et la sous-chanson ne bougent pas.
    expect(rows[2].songId, '$uuid#2');
    expect(rows[2].subsongIdx, 2);
  });

  test('une ligne de catalogue PORTE un ext_ref et se numérote quand même', () {
    // C'est par `ext_ref` que l'index de sous-chanson d'un conteneur voyage:
    // écarter les lignes qui en ont un revenait à ne jamais numéroter.
    final withRef = [
      for (var i = 0; i < 3; i++)
        SearchResult.fromJson({
          'song_id':   uuid,
          'collection': 'modland',
          'title':     'monkey island',
          'filename':  'mdat.monkey island',
          'format_ext': 'tfmx',
          'file_size': 0,
          'total_count': 0,
          'track_count': 22,
          'artist_names': ['Chris Huelsbeck'],
          'ext_ref':   {'file_name': 'mdat.monkey island', 'subsong_idx': i},
        }),
    ];
    expect(withRef.every((r) => r.extRef != null), isTrue);
    expect(RewampDb.numberSubsongTitles(withRef).map((r) => r.displayTitle),
        ['monkey island (1)', 'monkey island (2)', 'monkey island (3)']);
  });

  test('des titres RÉELS ne sont jamais renumérotés', () {
    final rows = RewampDb.numberSubsongTitles([
      _container(uuid).withSubsong(0, title: 'Intro'),
      _container(uuid).withSubsong(1, title: 'Main theme'),
    ]);
    expect(rows.map((r) => r.displayTitle), ['Intro', 'Main theme']);
  });

  test('une entrée seule garde son titre', () {
    final rows =
        RewampDb.numberSubsongTitles([_container(uuid).withSubsongEntry(4)]);
    expect(rows.single.displayTitle, 'monkey island');
  });

  test('la sous-chanson 0 est une identité distincte de l\'uuid nu', () {
    // `#0` et l'uuid nu ne disent pas la même chose au compte: le premier
    // désigne la 1re sous-chanson, le second le fichier.
    expect(_container(uuid).withSubsongEntry(0).songId, '$uuid#0');
  });
}
