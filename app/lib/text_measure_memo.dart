import 'package:flutter/widgets.dart';

/// La dernière mesure d'un texte, rendue telle quelle tant que rien de ce qui
/// la détermine n'a changé.
///
/// Les textes défilants (`ScrollingText`, `MarqueeText`) doivent connaître la
/// taille de leur libellé pour savoir s'il déborde. Ils la mesuraient par un
/// `TextPainter` neuf à CHAQUE construction — et le lecteur plein écran se
/// reconstruisait à chaque tick de lecture (250 ms), avec plusieurs de ces
/// libellés. Une mise en page de paragraphe n'est pas gratuite (façonnage,
/// résolution des polices, dont les quinze familles du repli CJK sous Linux),
/// et ces painters n'étaient jamais libérés. Or entre deux ticks, ni le texte,
/// ni le style, ni la largeur ne changent: la mesure est la même.
///
/// Une entrée, pas un cache: chaque widget a SON memo, qui ne retient que la
/// dernière question posée.
class TextMeasureMemo {
  String? _text;
  TextStyle? _style;
  TextDirection? _dir;
  int? _maxLines;
  double? _maxWidth;
  Size _size = Size.zero;

  /// Taille du texte mis en page sous ces paramètres — recalculée seulement
  /// si l'un d'eux a changé depuis l'appel précédent.
  Size measure(
    String text,
    TextStyle style,
    TextDirection dir, {
    int? maxLines,
    double maxWidth = double.infinity,
  }) {
    if (text == _text &&
        style == _style &&
        dir == _dir &&
        maxLines == _maxLines &&
        maxWidth == _maxWidth) {
      return _size;
    }
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      textDirection: dir,
    )..layout(minWidth: 0, maxWidth: maxWidth);
    _size = tp.size;
    tp.dispose();
    _text = text;
    _style = style;
    _dir = dir;
    _maxLines = maxLines;
    _maxWidth = maxWidth;
    return _size;
  }
}
