// Filtre et tri des écrans de bibliothèque.
//
// Deux règles qui ne se voient pas à l'œil et qu'on casse sans s'en rendre
// compte: le filtre doit chercher AUSSI dans le titre de la piste (le `name`
// d'une entrée est le nom du FICHIER au moment du geste, donc celui de l'album
// dès qu'il s'agit d'un conteneur), et le tri doit être stable — deux entrées
// du même artiste gardent un ordre lisible plutôt que celui du hasard.
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/library_toolbar.dart';
import 'package:rewamp/local_db.dart';

LibraryItem item(String name,
        {String? artist, String? album, String? trackTitle, int addedAt = 0}) =>
    LibraryItem(
      id:      name,
      type:    'track',
      refId:   name,
      name:    name,
      artist:  artist,
      album:   album,
      trackTitle: trackTitle,
      addedAt: DateTime.fromMillisecondsSinceEpoch(addedAt * 1000),
      isFavorite: false,
    );

void main() {
  test('le filtre ignore la casse et les accents', () {
    final items = [item('Björk'), item('Zelda')];

    expect(filterLibraryItems(items, 'bjork').map((i) => i.name), ['Björk']);
    expect(filterLibraryItems(items, 'ZEL').map((i) => i.name), ['Zelda']);
  });

  test('le filtre trouve le TITRE de la piste, pas seulement le nom', () {
    // Le cas réel: une entrée nommée « Wild Arms » (le conteneur) dont la
    // piste est « 129b A Sorrowful Separation ».
    final items = [
      item('Wild Arms', trackTitle: '129b A Sorrowful Separation (Alternate)'),
    ];

    expect(filterLibraryItems(items, 'sorrowful'), hasLength(1));
  });

  test('le filtre cherche aussi dans artiste et album', () {
    final items = [item('x', artist: 'Rob Hubbard', album: 'Commando')];

    expect(filterLibraryItems(items, 'hubbard'), hasLength(1));
    expect(filterLibraryItems(items, 'commando'), hasLength(1));
    expect(filterLibraryItems(items, 'zzz'), isEmpty);
  });

  test('le tri par artiste retombe sur le nom, et le sens s\'inverse', () {
    final items = [
      item('Zeta',  artist: 'A'),
      item('Alpha', artist: 'A'),
      item('Mid',   artist: 'B'),
    ];

    expect(
        sortLibraryItems(items, LibrarySort.artist, true).map((i) => i.name),
        ['Alpha', 'Zeta', 'Mid']);
    expect(
        sortLibraryItems(items, LibrarySort.artist, false).map((i) => i.name),
        ['Mid', 'Zeta', 'Alpha']);
  });

  test('le tri par date d\'ajout est bien chronologique', () {
    final items = [
      item('vieux',  addedAt: 100),
      item('récent', addedAt: 300),
      item('milieu', addedAt: 200),
    ];

    expect(sortLibraryItems(items, LibrarySort.added, true).map((i) => i.name),
        ['vieux', 'milieu', 'récent']);
    expect(sortLibraryItems(items, LibrarySort.added, false).map((i) => i.name),
        ['récent', 'milieu', 'vieux']);
  });

  test('le champ de tri persiste par sa valeur, pas par son nom d\'enum', () {
    // Renommer un cas de l'enum ne doit pas effacer le réglage de
    // l'utilisateur: c'est `pref` qui est écrit dans les préférences.
    for (final s in LibrarySort.values) {
      expect(LibrarySortLabel.fromPref(s.pref, LibrarySort.name), s);
    }
    expect(LibrarySortLabel.fromPref('inconnu', LibrarySort.added),
        LibrarySort.added);
  });
}
