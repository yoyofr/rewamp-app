// Checks the artwork tint's OKLab mapping — the property that matters is not a
// specific colour but that PERCEIVED DEPTH no longer depends on the hue.
//
// The old HSL mapping spread the output over 0.186 of OKLab lightness across
// the hue wheel (a blue landed at 0.364 while an orange landed at 0.550),
// because the WCAG contrast loop darkened by HSL lightness and relative
// luminance weights green ten times blue. Same wheel, same test, after the
// rework: ≤ 0.08.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/artwork_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rewamp/user_settings.dart';

double _lin(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// OKLab lightness — the perceptual "how deep does this read" axis.
double _oklabL(Color x) {
  final r = _lin(x.r), g = _lin(x.g), b = _lin(x.b);
  final l = math.pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3).toDouble();
  final m = math.pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3).toDouble();
  final s = math.pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3).toDouble();
  return 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Widget probe;
  final captured = <double>[];

  setUpAll(() async {
    // artworkTintedPlayer defaults to true; the store just has to exist.
    SharedPreferences.setMockInitialValues({});
    await UserSettings.init();
  });

  testWidgets('tint depth is hue-independent and always legible under white',
      (tester) async {
    final depths = <String, double>{};
    final luminances = <String, double>{};

    for (var hue = 0; hue < 360; hue += 30) {
      PlayerTint.dominant =
          HSLColor.fromAHSL(1, hue.toDouble(), 0.80, 0.50).toColor();
      late Color sheet;
      probe = MaterialApp(
        home: Builder(builder: (context) {
          sheet = PlayerTint.sheet(context)!;
          return const SizedBox.shrink();
        }),
      );
      await tester.pumpWidget(probe);
      depths['$hue'] = _oklabL(sheet);
      luminances['$hue'] = sheet.computeLuminance();
      captured.add(_oklabL(sheet));
    }

    final spread = captured.reduce(math.max) - captured.reduce(math.min);
    debugPrint('depth spread across the hue wheel: '
        '${spread.toStringAsFixed(3)} (was 0.186 in HSL)');
    expect(spread, lessThan(0.08),
        reason: 'perceived depth still depends on the hue: $depths');

    // White body text at 4.5:1 — the reason the clamp exists at all.
    for (final e in luminances.entries) {
      expect(e.value, lessThanOrEqualTo(0.176),
          reason: 'hue ${e.key} is too luminous for white text');
    }
  });

  testWidgets('a darker cover still gives a deeper sheet', (tester) async {
    final out = <double>[];
    for (final l in [0.25, 0.50, 0.75]) {
      PlayerTint.dominant = HSLColor.fromAHSL(1, 240, 0.80, l).toColor();
      late Color sheet;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          sheet = PlayerTint.sheet(context)!;
          return const SizedBox.shrink();
        }),
      ));
      out.add(_oklabL(sheet));
    }
    expect(out[0], lessThan(out[1]));
    expect(out[1], lessThan(out[2]));
  });
}
