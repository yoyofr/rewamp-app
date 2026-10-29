import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rewamp/l10n.dart';
import 'package:rewamp/local_db.dart';
import 'package:rewamp/rewamp_db.dart';
import 'package:rewamp/track_options_sheet.dart';
import 'package:rewamp/user_settings.dart';

/// La feuille de choix décide SEULE d'un lien « voir »: le lecteur offrait déjà
/// « Voir l'album » et « Voir les subsongs », les LISTES non — un tap n'y menait
/// qu'à la lecture. Les recoder dans chaque écran, c'était garantir qu'il en
/// manquerait toujours un.
void main() {
  // La feuille lit « Toucher un morceau dans l'app » (défaut: demander).
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await UserSettings.init();
  });
  SearchResult row({String? album, int? subsongs, bool resolved = false,
          String songId = 'u1'}) =>
      SearchResult(
        songId: songId, collection: 'hvsc', title: 'Commando',
        filename: 'Commando.sid', album: album, formatExt: 'sid',
        downloadUrl: null, fileSize: 0, year: null,
        artistNames: const ['Rob Hubbard'], totalCount: 1,
        subsongCount: subsongs, resolvedSubsong: resolved,
      );

  Future<void> open(WidgetTester t, {SearchResult? result}) async {
    await t.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (ctx) => Scaffold(
        body: TextButton(
          onPressed: () => showPlayChoiceSheet(ctx, title: 'x', result: result),
          child: const Text('go'),
        ),
      )),
    ));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
  }

  setUp(() {
    // Sans ces crochets la feuille n'a nulle part où aller: les tuiles ne
    // doivent alors PAS s'afficher.
    globalQueueHasContent = () => true;
    globalOnOpenSubsongs  = (_) {};
    globalOnNavigateAlbum = (_, {collection, platform, artworkUrl, albumId}) {};
  });
  tearDown(() {
    globalOnOpenSubsongs = null;
    globalOnNavigateAlbum = null;
    globalQueueHasContent = null;
  });

  testWidgets('un fichier multi-sous-chansons offre « Voir les subsongs »',
      (t) async {
    await open(t, result: row(subsongs: 21));
    expect(find.text('Voir les subsongs'), findsOneWidget);
  });

  testWidgets('une ligne ÉPINGLÉE par le serveur l\'offre quand même',
      (t) async {
    // Règle RÉVISÉE. Une ligne de palmarès est déjà résolue — le serveur y
    // nomme la sous-chanson (`subsong_index`) — et la tuile a pourtant sa
    // place: c'est un LIEN, pas une lecture. Depuis un morceau on veut
    // remonter au fichier qui le contient, et un palmarès est justement
    // l'endroit où l'on tombe sur une sous-chanson isolée.
    //
    // Ce qui reste interdit est de DÉPLIER une ligne résolue pour la jouer,
    // et cet interdit vit dans `_subsongEntries`, pas ici.
    await open(t, result: row(subsongs: 21, resolved: true));
    expect(find.text('Voir les subsongs'), findsOneWidget);
  });

  testWidgets('un RANG de tracklist (`uuid#i`) ne l\'offre pas', (t) async {
    // Lui reste exclu, et pour une raison différente: son identité PORTE le
    // rang, donc on ne peut pas en dériver le conteneur sans couper l'id — et
    // `expandContainerAlbum` a déjà fait ce travail.
    await open(t, result: row(subsongs: 21, songId: 'u1#3'));
    expect(find.text('Voir les subsongs'), findsNothing);
  });

  testWidgets('une piste simple ne l\'offre pas', (t) async {
    await open(t, result: row(subsongs: 1));
    expect(find.text('Voir les subsongs'), findsNothing);
  });

  testWidgets('une ligne qui nomme un album offre « Voir l\'album »',
      (t) async {
    await open(t, result: row(album: 'Commando'));
    expect(find.text('Voir l\'album'), findsOneWidget);
  });

  testWidgets('sans ligne, la feuille garde ses trois choix de lecture',
      (t) async {
    await open(t);
    expect(find.text('Voir les subsongs'), findsNothing);
    expect(find.text('Voir l\'album'), findsNothing);
    expect(find.text('Lire maintenant'), findsOneWidget);
  });

  testWidgets('sans crochet de navigation, aucune tuile', (t) async {
    globalOnOpenSubsongs = null;
    globalOnNavigateAlbum = null;
    await open(t, result: row(album: 'Commando', subsongs: 21));
    expect(find.text('Voir les subsongs'), findsNothing);
    expect(find.text('Voir l\'album'), findsNothing);
  });

  group('trackOffersAlbumLink (ligne locale)', () {
    TrackRecord rec({String? album, String? albumId, String? onlineId}) =>
        TrackRecord(
          id: 'x', filePath: '/d/Gunship 2000.sc68', entryPath: '',
          subsongIdx: 1, metaAlbum: album, albumId: albumId,
          subsongCount: 9, source: 'online', onlineId: onlineId,
          isFavorite: false, inLibrary: false, playCount: 0,
        );
    const uuid = 'fcbd1a27-fa34-5aa2-8c0a-495caea187bc';

    test('catalogue SANS uuid d\'album: le tag du fichier n\'est pas un album',
        () {
      // Gunship 2000.sc68: meta_album = son propre nom (tag lu par le moteur).
      expect(trackOffersAlbumLink(rec(album: 'Gunship 2000', onlineId: uuid)),
          isFalse);
    });
    test('catalogue AVEC uuid d\'album: lien', () {
      expect(trackOffersAlbumLink(
              rec(album: 'Commando', albumId: uuid, onlineId: uuid)),
          isTrue);
    });
    test('import local: le nom (son dossier) est l\'identité', () {
      expect(trackOffersAlbumLink(rec(album: 'Mes rips')), isTrue);
    });
    test('sans album: rien', () {
      expect(trackOffersAlbumLink(rec(onlineId: uuid)), isFalse);
    });
  });
}
