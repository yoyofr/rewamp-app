import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/text_measure_memo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const style = TextStyle(fontSize: 14);

  test('même question ⇒ même mesure, sans nouvelle mise en page', () {
    final memo = TextMeasureMemo();
    final a = memo.measure('Peaceful Days', style, TextDirection.ltr, maxLines: 1);
    final b = memo.measure('Peaceful Days', style, TextDirection.ltr, maxLines: 1);
    expect(a.width, greaterThan(0));
    expect(identical(a, b), isTrue);
  });

  test('un texte plus long est remesuré', () {
    final memo = TextMeasureMemo();
    final a = memo.measure('abc', style, TextDirection.ltr, maxLines: 1);
    final b = memo.measure('abcdefghij', style, TextDirection.ltr, maxLines: 1);
    expect(b.width, greaterThan(a.width));
  });

  test('un style plus gros est remesuré', () {
    final memo = TextMeasureMemo();
    final a = memo.measure('abc', style, TextDirection.ltr, maxLines: 1);
    final b = memo.measure('abc', const TextStyle(fontSize: 28),
        TextDirection.ltr, maxLines: 1);
    expect(b.height, greaterThan(a.height));
  });

  test('une largeur plus étroite replie le texte (hauteur remesurée)', () {
    final memo = TextMeasureMemo();
    const t = 'un libellé assez long pour se replier sur plusieurs lignes';
    final wide = memo.measure(t, style, TextDirection.ltr);
    final narrow = memo.measure(t, style, TextDirection.ltr, maxWidth: 60);
    expect(narrow.height, greaterThan(wide.height));
  });
}
