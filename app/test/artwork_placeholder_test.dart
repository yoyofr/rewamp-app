// Empirical check of the themed-placeholder decision paths in ArtworkImage —
// exactly the inputs the player (_ArtworkPanel) and the tiles pass.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/artwork_image.dart';
import 'package:rewamp/platform_artwork.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    // let _load()'s async complete + rebuild
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  String? shownAsset(WidgetTester tester) {
    for (final img in tester.widgetList<Image>(find.byType(Image))) {
      final p = img.image;
      if (p is AssetImage) return p.assetName;
    }
    return null;
  }

  testWidgets('player inputs: url=null + localFilePath .kss -> msx asset',
      (tester) async {
    await pump(
        tester,
        const ArtworkImage(
          url: null,
          localFilePath: '/tmp/does-not-exist/MSX Fan (MSX).kss',
        ));
    expect(shownAsset(tester), 'assets/placeholders/msx.png');
  });

  testWidgets('player inputs: kss path WITH ?subsong suffix -> msx asset',
      (tester) async {
    await pump(
        tester,
        const ArtworkImage(
          url: null,
          localFilePath: '/tmp/x/file.kss?subsong=12',
        ));
    expect(shownAsset(tester), 'assets/placeholders/msx.png');
  });

  testWidgets('empty-string url (not http) -> FileImage error -> placeholder',
      (tester) async {
    await pump(
        tester,
        const ArtworkImage(
          url: '',
          localFilePath: '/tmp/x/file.kss',
        ));
    // '' resolves as a local path -> FileImage('') fails -> errorBuilder ->
    // themed placeholder. Real file IO needs the real event loop (runAsync).
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(shownAsset(tester), 'assets/placeholders/msx.png');
  });

  testWidgets('stale local path url -> FileImage error -> placeholder',
      (tester) async {
    await pump(
        tester,
        const ArtworkImage(
          url: '/tmp/definitely-missing/artwork.jpg',
          localFilePath: '/tmp/x/file.kss',
        ));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(shownAsset(tester), 'assets/placeholders/msx.png');
  });

  test('platform mapping sanity', () {
    expect(platformAssetForPath('/a/b/file.kss'), 'assets/placeholders/msx.png');
    expect(platformAssetForPath('/a/b/file.kss?subsong=3'),
        'assets/placeholders/msx.png');
    expect(platformAssetForPath('file.hes'), 'assets/placeholders/pcengine.png');
    expect(platformAssetForPath('file.xyz'), 'assets/placeholders/rewamp.png');
    expect(platformAssetForPath(null), 'assets/placeholders/rewamp.png');
  });

  // Un nom Amiga porte son FORMAT avant le point, donc la règle du dernier
  // point lit « .monkey island » comme extension et ne trouve rien: le
  // mini-lecteur et « écoutés récemment » montraient la marque générique là où
  // le lecteur, lui, affichait l'Amiga (il reçoit le format à part).
  test('convention de préfixe Amiga', () {
    expect(platformAssetForPath('/a/b/mdat.monkey island'),
        'assets/placeholders/amiga.png');
    expect(platformAssetForPath('cust.turrican'),
        'assets/placeholders/amiga.png');
    expect(platformAssetForPath('/a/b/mdat.monkey island?subsong=3'),
        'assets/placeholders/amiga.png');
    // L'EXTENSION reste prioritaire: un nom dont le premier token ressemble à
    // un format mais qui porte une vraie extension garde la sienne.
    expect(platformAssetForPath('/a/b/fc.foo.sid'),
        'assets/placeholders/c64.png');
    // Et un premier token qui ne nomme aucun format ne décide de rien.
    expect(platformAssetForPath('Mr.Beat'), 'assets/placeholders/rewamp.png');
  });
}
