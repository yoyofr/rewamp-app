import 'dart:async';
import 'font_fallback.dart';

import 'package:flutter/material.dart';

/// Text that scrolls itself when it does not fit — sur UN axe ou sur l'AUTRE.
///
/// Written rather than pulled from a package: the need is narrow (a rail card's
/// caption), and a marquee that scrolls when it must and stays still when it
/// fits is a few lines. Static text never moves — a card whose caption fits
/// should not wiggle.
///
/// ⚠️ **L'axe n'est pas un détail cosmétique.** À l'HORIZONTALE le texte doit
/// tenir sur UNE ligne: faire glisser un texte REPLIÉ ne révèle rien de
/// cohérent, son bord droit étant irrégulier (chaque ligne s'arrête sur un
/// mot). À la VERTICALE c'est l'inverse — le texte se replie normalement,
/// chaque ligne est complète, et la fenêtre de [maxLines] lignes glisse pour
/// découvrir les suivantes. D'où deux usages distincts: une seule ligne qui
/// défile latéralement (sous-titre, lecteur), ou N lignes qui défilent
/// verticalement (titre d'une carte de rail).
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  /// Scroll speed, logical pixels per second.
  final double velocity;
  /// Pause sur la position de DÉPART, à chaque tour. Le défilement est une
  /// BOUCLE dans un seul sens (voir ScrollingText): deux copies séparées d'un
  /// écart, et un retour invisible à zéro quand la seconde a pris la place de
  /// la première — jamais d'aller-retour.
  final Duration pause;

  /// Axe du défilement. `horizontal` impose une ligne unique; `vertical`
  /// replie sur [maxLines] et fait défiler le bloc.
  final Axis axis;

  /// Hauteur de la fenêtre, en lignes. N'a de sens qu'à la verticale.
  final int maxLines;

  const MarqueeText(
    this.text, {
    super.key,
    this.style,
    this.velocity = 26,
    this.pause = const Duration(milliseconds: 1200),
    this.axis = Axis.horizontal,
    this.maxLines = 1,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final _ctrl = ScrollController();
  Timer? _timer;
  // See ScrollingText: an in-flight animateTo() from the previous (long) text
  // outlives the timer cancel and would re-scroll the new (short) text. Each
  // async step captures this and bails when the text has changed since.
  int _gen = 0;
  // Longueur d'un cycle (une copie + l'écart), posée au build; 0 = ça tient.
  double _cycle = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedule());
  }

  @override
  void didUpdateWidget(MarqueeText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _gen++;
      _timer?.cancel();
      if (_ctrl.hasClients) _ctrl.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _schedule());
    }
  }

  void _schedule() {
    if (!mounted || !_ctrl.hasClients || _cycle <= 0) return;
    _timer?.cancel();
    _timer = Timer(widget.pause, _step);
  }

  Future<void> _step() async {
    if (!mounted || !_ctrl.hasClients || _cycle <= 0) return;
    final gen = _gen;
    final distance = _cycle - _ctrl.offset;
    if (distance > 0) {
      await _ctrl.animateTo(
        _cycle,
        duration: Duration(
            milliseconds: (distance / widget.velocity * 1000).round()),
        curve: Curves.linear,
      );
    }
    if (!mounted || gen != _gen || !_ctrl.hasClients) return;   // text swapped mid-animation
    _ctrl.jumpTo(0);   // la seconde copie était là: rien ne bouge à l'écran
    _timer = Timer(widget.pause, _step);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Style EFFECTIF (fusion avec DefaultTextStyle), le même pour les deux
    // copies — voir ScrollingText.
    final style = withCjkFallback(
        DefaultTextStyle.of(context).style.merge(widget.style));
    final dir = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);

    if (widget.axis == Axis.horizontal) {
      return LayoutBuilder(builder: (ctx, constraints) {
        final cw = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final tp = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: dir,
        )..layout(minWidth: 0, maxWidth: double.infinity);
        final tw = tp.width;
        final gap = (style.fontSize ?? 14) * 3;   // « quelques caractères »
        final overflows = cw > 0 && tw > cw + 1;
        _cycle = overflows ? tw + gap : 0;
        final line = Text(widget.text, style: style, maxLines: 1, softWrap: false);
        // Copie de relais en RichText nu: invisible à `find.text` (voir ScrollingText).
        final echo = RichText(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1, softWrap: false, overflow: TextOverflow.clip,
          textDirection: dir, textScaler: scaler,
        );
        return SingleChildScrollView(
          controller: _ctrl,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: overflows
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  line, SizedBox(width: gap), ExcludeSemantics(child: echo),
                ])
              : line,
        );
      });
    }

    // Vertical: la fenêtre fait EXACTEMENT [maxLines] lignes, mesurées avec la
    // vraie police plutôt que déduites de `fontSize` — l'interligne dépend du
    // style et de la police système, et une fenêtre approximative coupe une
    // ligne en deux. Le texte replié est mesuré à la largeur du conteneur pour
    // savoir s'il déborde; s'il déborde, deux copies séparées d'UNE ligne vide.
    final probe = TextPainter(
      text: TextSpan(text: 'Xg', style: style),
      maxLines: 1,
      textDirection: dir,
    )..layout();
    final lineH = probe.height;
    return LayoutBuilder(builder: (ctx, constraints) {
      final cw = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
      final tp = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        textDirection: dir,
      )..layout(minWidth: 0, maxWidth: cw > 0 ? cw : double.infinity);
      final th = tp.height;
      final windowH = lineH * widget.maxLines;
      final overflows = cw > 0 && th > windowH + 1;
      _cycle = overflows ? th + lineH : 0;
      final block = Text(widget.text, style: style);
      final echo  = RichText(
        text: TextSpan(text: widget.text, style: style),
        textDirection: dir, textScaler: scaler,
      );
      return SizedBox(
        height: windowH,
        child: SingleChildScrollView(
          controller: _ctrl,
          scrollDirection: Axis.vertical,
          physics: const NeverScrollableScrollPhysics(),
          child: overflows
              ? Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    block, SizedBox(height: lineH), ExcludeSemantics(child: echo),
                  ])
              : block,
        ),
      );
    });
  }
}
