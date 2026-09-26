import 'dart:async';
import 'font_fallback.dart';
import 'package:flutter/material.dart';

/// Single-line text that auto-scrolls when it overflows its container.
/// Static when it fits.
///
/// Défilement en BOUCLE, toujours dans le même sens — pas un aller-retour: le
/// texte est rendu DEUX fois, séparé d'un écart de quelques caractères, et l'on
/// défile jusqu'à ce que la seconde copie occupe exactement la place de la
/// première; là, un `jumpTo(0)` ne change pas un pixel à l'écran, et la pause
/// se fait sur la position de DÉPART — c'est le seul moment où le texte est
/// immobile, et c'est celui où il est lisible depuis son début. Un aller-retour
/// faisait relire le texte à l'envers à chaque cycle. Décidé le 2026-09-26.
class ScrollingText extends StatefulWidget {
  final String     text;
  final TextStyle? style;
  final int        pauseMs;
  final double     pixelsPerSecond;

  /// Prend la largeur du TEXTE quand il tient, au lieu de toute la largeur
  /// offerte.
  ///
  /// Une vue défilante horizontale occupe par défaut TOUTE la contrainte qu'on
  /// lui donne — ce qui convient au titre d'un `ListTile` (aligné à gauche,
  /// pleine largeur de toute façon) mais casse une ligne où le titre est suivi
  /// d'un badge dans une `Row`: le badge partirait au bord droit même derrière
  /// un titre de trois mots. Sans effet quand le texte déborde, la largeur
  /// étant alors celle du conteneur dans les deux cas.
  final bool shrinkWrap;

  const ScrollingText({
    super.key,
    required this.text,
    this.style,
    this.pauseMs        = 1500,
    this.pixelsPerSecond = 40,
    this.shrinkWrap     = false,
  });

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText> {
  final _scroll = ScrollController();
  Timer? _timer;
  double _containerWidth = 0;
  double _textWidth = 0;
  double _gap = 0;
  // Bumped whenever the text changes. An in-flight animateTo() from the OLD
  // (long) text keeps running after the text is swapped — cancelling the timer
  // doesn't stop the awaited animation, and its continuation would re-arm a
  // scroll on the NEW (short) text, dragging it off-screen. Every async step
  // captures this token and bails when it no longer matches.
  int _gen = 0;

  bool get _overflows => _textWidth > _containerWidth + 1;

  /// L'écart entre les deux copies: « quelques caractères », mesurés dans la
  /// police du texte plutôt que fixés en pixels.
  static double gapFor(TextStyle style) => (style.fontSize ?? 14) * 3;

  @override
  void didUpdateWidget(ScrollingText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.style != widget.style) {
      _gen++;
      _cancel();
      if (_scroll.hasClients) _scroll.jumpTo(0);
      _textWidth = 0;
    }
  }

  @override
  void dispose() {
    _cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Un cycle: pause au départ, puis UNE longueur de texte plus l'écart, puis
  /// retour instantané et invisible à zéro. Jamais dans l'autre sens.
  void _scheduleScroll() {
    _cancel();
    final gen = _gen;
    _timer = Timer(Duration(milliseconds: widget.pauseMs), () async {
      if (!mounted || gen != _gen || !_scroll.hasClients || !_overflows) return;
      final target = _textWidth + _gap;
      final dist   = target - _scroll.offset;
      if (dist < 1) { _scroll.jumpTo(0); _scheduleScroll(); return; }
      final ms = (dist / widget.pixelsPerSecond * 1000).round();
      await _scroll.animateTo(
        target,
        duration: Duration(milliseconds: ms),
        curve:    Curves.linear,
      );
      // The text may have changed mid-animation (interrupted by jumpTo) — the
      // token guard stops a stale continuation from re-scrolling the new text.
      if (!mounted || gen != _gen || !_scroll.hasClients) return;
      _scroll.jumpTo(0);   // la seconde copie était là: rien ne bouge à l'écran
      _scheduleScroll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cw    = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        // Le style EFFECTIF (celui que `Text` obtiendrait en fusionnant avec
        // DefaultTextStyle): les deux copies doivent être au pixel près les
        // mêmes, sinon le saut se voit.
        final style = withCjkFallback(
            DefaultTextStyle.of(ctx).style.merge(widget.style));
        final tp = TextPainter(
          text:      TextSpan(text: widget.text, style: style),
          maxLines:  1,
          textDirection: Directionality.of(ctx),
        )..layout(minWidth: 0, maxWidth: double.infinity);
        final tw  = tp.width;
        final gap = gapFor(style);

        if (cw != _containerWidth || tw != _textWidth || gap != _gap) {
          _containerWidth = cw;
          _textWidth      = tw;
          _gap            = gap;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _cancel();
            if (_scroll.hasClients) _scroll.jumpTo(0);
            if (_overflows) _scheduleScroll();
          });
        }

        final overflows = tw > cw + 1;
        final line = Text(widget.text, style: style, maxLines: 1, softWrap: false);
        // La copie de relais est un RichText nu: rendu identique (style
        // effectif, même échelle de texte), mais invisible à `find.text` — un
        // test qui cherche le libellé n'en trouve qu'UN, comme un lecteur
        // d'écran n'en entend qu'un. (`Text.rich` ne suffit pas: c'est un
        // `Text`, que `find.text` reconnaît par son span.)
        final echo = RichText(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1, softWrap: false, overflow: TextOverflow.clip,
          textDirection: Directionality.of(ctx),
          textScaler: MediaQuery.textScalerOf(ctx),
        );
        final view = ClipRect(
          child: SingleChildScrollView(
            controller:      _scroll,
            scrollDirection: Axis.horizontal,
            physics:         const NeverScrollableScrollPhysics(),
            child: overflows
                // Deux copies: la seconde prend la place de la première au bout
                // du cycle. Exclue de la sémantique, sinon un lecteur d'écran
                // lirait le titre deux fois.
                ? SizedBox(
                    width: tw * 2 + gap,
                    child: Row(children: [
                      line,
                      SizedBox(width: gap),
                      ExcludeSemantics(child: echo),
                    ]),
                  )
                : line,
          ),
        );
        if (!widget.shrinkWrap || !constraints.maxWidth.isFinite) return view;
        return SizedBox(width: tw < cw ? tw : cw, child: view);
      },
    );
  }
}
