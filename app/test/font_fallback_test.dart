// L'ordre du repli CJK sous Linux.
//
// ⚠️ L'ORDRE est la partie qui compte (unification Han): un même point de code
// se dessine différemment en japonais, chinois simplifié/traditionnel et
// coréen — la variante de la langue d'interface doit passer en tête.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/font_fallback.dart';

void main() {
  List<String>? fb(String? lang, [String? script]) => cjkFontFallback(lang,
      scriptCode: script, platform: TargetPlatform.linux);

  test('hors Linux: aucun repli ajouté (le repli système y fonctionne)', () {
    for (final p in [TargetPlatform.macOS, TargetPlatform.iOS,
        TargetPlatform.android, TargetPlatform.windows]) {
      expect(cjkFontFallback('ja', platform: p), isNull, reason: '$p');
    }
  });

  test('la variante de la langue d\'interface passe EN TÊTE', () {
    expect(fb('ja')!.first, 'Noto Sans CJK JP');
    expect(fb('zh')!.first, 'Noto Sans CJK SC');
    expect(fb('zh', 'Hant')!.first, 'Noto Sans CJK TC');
    expect(fb('ko')!.first, 'Noto Sans CJK KR');
  });

  test('langue non CJK: japonais d\'abord (le plus fréquent des tags de jeu)',
      () {
    expect(fb('fr')!.first, 'Noto Sans CJK JP');
    expect(fb(null)!.first, 'Noto Sans CJK JP');
  });

  test('les QUATRE variantes restent présentes, et le dernier recours à la fin',
      () {
    final l = fb('ko')!;
    for (final f in ['Noto Sans CJK JP', 'Noto Sans CJK SC',
        'Noto Sans CJK TC', 'Noto Sans CJK KR']) {
      expect(l, contains(f));
    }
    expect(l.last, 'Droid Sans Fallback');
    expect(l.toSet().length, l.length, reason: 'aucun doublon');
  });
}
