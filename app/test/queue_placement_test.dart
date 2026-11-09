import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/play_start.dart';

void main() {
  test('hors geste: rien à prendre', () {
    expect(takeQueuePlacement(), isNull);
  });

  test('traverse les await, et ne se prend qu\'une fois', () async {
    bool? first, second;
    await withQueuePlacement(
        atEnd: true,
        gesture: () async {
          await Future<void>.delayed(Duration.zero);
          first = takeQueuePlacement();
          second = takeQueuePlacement();
        });
    expect(first, isTrue);
    expect(second, isNull);
  });

  test('une minuterie née dans le geste ne la retrouve pas après coup',
      () async {
    final later = Completer<bool?>();
    await withQueuePlacement(
        atEnd: false,
        gesture: () {
          expect(takeQueuePlacement(), isFalse);
          Timer(Duration.zero, () => later.complete(takeQueuePlacement()));
        });
    expect(await later.future, isNull);
  });
}
