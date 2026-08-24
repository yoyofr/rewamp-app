// Drives the real app to capture screenshots of the new search UI remotely.
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screens_test.dart -d <sim> --dart-define=ENV=vps
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:rewamp/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('album sizes', (t) async {
    app.main();
    await t.pumpAndSettle(const Duration(seconds: 4));
    await binding.convertFlutterSurfaceToImage();

    await t.tap(find.text('Recherche'));
    await t.pumpAndSettle(const Duration(seconds: 1));

    await t.enterText(find.byType(TextField).first, 'commando');
    await t.pumpAndSettle(const Duration(seconds: 5));

    // Albums tab — list with per-album size.
    await t.tap(find.text('Albums'));
    await t.pumpAndSettle(const Duration(seconds: 3));
    await binding.takeScreenshot('07_albums_size');

    // Open the first album → detail with per-track + total size.
    final firstAlbum = find.byType(ListTile).first;
    if (firstAlbum.evaluate().isNotEmpty) {
      await t.tap(firstAlbum);
      await t.pumpAndSettle(const Duration(seconds: 5));
      await binding.takeScreenshot('08_album_detail_size');
    }
  });
}
