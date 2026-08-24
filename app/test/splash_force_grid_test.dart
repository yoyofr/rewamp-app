// The hidden launch picker: hold a finger while the app starts and the cell it
// lands in forces one intro effect. The mapping is a CONTRACT — someone learns
// "top-left is the raster" — so it is pinned here: a cell must keep pointing at
// the same effect, which means new effects are APPENDED to kSplashEffects and
// never inserted in the middle.

import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/splash_intro.dart';

const Size _kScreen = Size(390, 845); // 3 and 5 divide these cleanly

Offset _cellCentre(int col, int row) => Offset(
      (col + 0.5) * _kScreen.width / kSplashGridCols,
      (row + 0.5) * _kScreen.height / kSplashGridRows,
    );

void main() {
  test('reading order: left to right, then down', () {
    var n = 0;
    for (var row = 0; row < kSplashGridRows; row++) {
      for (var col = 0; col < kSplashGridCols; col++) {
        final idx = splashEffectIndexAt(_cellCentre(col, row), _kScreen);
        if (n < kSplashEffects.length) {
          expect(idx, n, reason: 'cell (col $col, row $row) moved');
        } else {
          expect(idx, isNull,
              reason: 'cell (col $col, row $row) has no effect behind it');
        }
        n++;
      }
    }
  });

  test('the corners belong to the cells they sit in', () {
    expect(splashEffectIndexAt(Offset.zero, _kScreen), 0);
    expect(
        splashEffectIndexAt(
            Offset(_kScreen.width - 0.01, _kScreen.height - 0.01), _kScreen),
        // Bottom-right cell = index 14, past the end of the registry today.
        kSplashEffects.length > 14 ? 14 : null);
  });

  test('a point outside the screen still lands on a cell, never out of range',
      () {
    // A pointer can report a position a hair outside the view; the grid clamps
    // rather than indexing past its own edge.
    for (final p in [
      const Offset(-5, -5),
      Offset(_kScreen.width + 5, _kScreen.height + 5),
    ]) {
      final idx = splashEffectIndexAt(p, _kScreen);
      if (idx != null) expect(idx, lessThan(kSplashEffects.length));
    }
    expect(splashEffectIndexAt(const Offset(-5, -5), _kScreen), 0);
  });

  test('a degenerate size decides nothing', () {
    expect(splashEffectIndexAt(Offset.zero, Size.zero), isNull);
  });
}
