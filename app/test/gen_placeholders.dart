// PNG generator for the per-platform placeholder artwork.
//
//   flutter test test/gen_placeholders.dart
//
// Renders `paintPlatformArtwork` (lib/platform_artwork.dart) for every
// SoundPlatform into assets/placeholders/<id>.png at 512×512. Re-run after
// editing the palette/painter. Not a real test — it just draws + writes files
// (always passes).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/platform_artwork.dart';

void main() {
  const size = 512.0;

  testWidgets('generate platform placeholders', (tester) async {
    final dir = Directory('assets/placeholders');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    // The widget-tester's default font draws every glyph as a filled box; load a
    // real font so the platform labels render as actual text. Try a few common
    // macOS/Linux paths; fall back to no family (boxes) if none is found.
    const family = 'GenFont';
    const candidates = [
      '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
      '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
    ];
    String? fontFamily;
    for (final path in candidates) {
      final f = File(path);
      if (f.existsSync()) {
        final loader = FontLoader(family)
          ..addFont(Future.value(f.readAsBytesSync().buffer.asByteData()));
        await loader.load();
        fontFamily = family;
        break;
      }
    }

    // toImage() drives the real engine raster path, which the widget-tester's
    // fake-async would otherwise dead-lock — run it on the real event loop.
    await tester.runAsync(() async {
      for (final p in allSoundPlatforms) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
        paintPlatformArtwork(canvas, const Size(size, size), p,
            fontFamily: fontFamily);
        final picture = recorder.endRecording();
        final image = await picture.toImage(size.toInt(), size.toInt());
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        picture.dispose();
        image.dispose();
        final id = p.name.toLowerCase();
        File('${dir.path}/$id.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        // ignore: avoid_print
        print('wrote ${dir.path}/$id.png');
      }
    });
  });
}
