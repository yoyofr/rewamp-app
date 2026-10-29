import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/text_measure_memo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const style = TextStyle(fontSize: 14);

  test('même question ⇒ même mesure, sans nouvelle mise en page', () {
    final memo = TextMeasureMemo();
    final a = memo.measure('Peaceful Days', style, TextDirection.ltr, textScaler: TextScaler.noScaling, maxLines: 1);
    final b = memo.measure('Peaceful Days', style, TextDirection.ltr, textScaler: TextScaler.noScaling, maxLines: 1);
    expect(a.width, greaterThan(0));
    expect(identical(a, b), isTrue);
  });

  test('un texte plus long est remesuré', () {
    final memo = TextMeasureMemo();
    final a = memo.measure('abc', style, TextDirection.ltr, textScaler: TextScaler.noScaling, maxLines: 1);
    final b = memo.measure('abcdefghij', style, TextDirection.ltr, textScaler: TextScaler.noScaling, maxLines: 1);
    expect(b.width, greaterThan(a.width));
  });

  test('un style plus gros est remesuré', () {
    final memo = TextMeasureMemo();
    final a = memo.measure('abc', style, TextDirection.ltr, textScaler: TextScaler.noScaling, maxLines: 1);
    final b = memo.measure('abc', const TextStyle(fontSize: 28),
        TextDirection.ltr, textScaler: TextScaler.noScaling, maxLines: 1);
    expect(b.height, greaterThan(a.height));
  });

  test('une largeur plus étroite replie le texte (hauteur remesurée)', () {
    final memo = TextMeasureMemo();
    const t = 'un libellé assez long pour se replier sur plusieurs lignes';
    final wide = memo.measure(t, style, TextDirection.ltr,
        textScaler: TextScaler.noScaling);
    final narrow = memo.measure(t, style, TextDirection.ltr,
        textScaler: TextScaler.noScaling, maxWidth: 60);
    expect(narrow.height, greaterThan(wide.height));
  });

  test('la taille de police du SYSTÈME agrandit la mesure (rewamp-app#2)', () {
    final memo = TextMeasureMemo();
    final a = memo.measure('airforce delta', style, TextDirection.ltr,
        textScaler: TextScaler.noScaling, maxLines: 1);
    final b = memo.measure('airforce delta', style, TextDirection.ltr,
        textScaler: const TextScaler.linear(1.5), maxLines: 1);
    expect(b.width, closeTo(a.width * 1.5, 1));
  });
}
