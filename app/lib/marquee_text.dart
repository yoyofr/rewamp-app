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
  /// Pause at each end before turning back.
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
  bool _forward = true;
  // See ScrollingText: an in-flight animateTo() from the previous (long) text
  // outlives the timer cancel and would re-scroll the new (short) text. Each
  // async step captures this and bails when the text has changed since.
  int _gen = 0;

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
      _forward = true;
      if (_ctrl.hasClients) _ctrl.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _schedule());
    }
  }

  void _schedule() {
    if (!mounted || !_ctrl.hasClients) return;
    final extent = _ctrl.position.maxScrollExtent;
    if (extent <= 0) return;   // it fits — leave it alone
    _timer?.cancel();
    _timer = Timer(widget.pause, _step);
  }

  Future<void> _step() async {
    if (!mounted || !_ctrl.hasClients) return;
    final gen = _gen;
    final extent = _ctrl.position.maxScrollExtent;
    if (extent <= 0) return;
    final target = _forward ? extent : 0.0;
    final distance = (target - _ctrl.offset).abs();
    if (distance > 0) {
      await _ctrl.animateTo(
        target,
        duration: Duration(
            milliseconds: (distance / widget.velocity * 1000).round()),
        curve: Curves.linear,
      );
    }
    if (!mounted || gen != _gen) return;   // text swapped mid-animation
    _forward = !_forward;
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
    if (widget.axis == Axis.horizontal) {
      return SingleChildScrollView(
        controller: _ctrl,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child:
            Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
      );
    }

    // Vertical: la fenêtre fait EXACTEMENT [maxLines] lignes, mesurées avec la
    // vraie police plutôt que déduites de `fontSize` — l'interligne dépend du
    // style et de la police système, et une fenêtre approximative coupe une
    // ligne en deux.
    final style = withCjkFallback(widget.style ?? DefaultTextStyle.of(context).style);
    final probe = TextPainter(
      text: TextSpan(text: 'Xg', style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    return SizedBox(
      height: probe.height * widget.maxLines,
      child: SingleChildScrollView(
        controller: _ctrl,
        scrollDirection: Axis.vertical,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(widget.text, style: widget.style),
      ),
    );
  }
}
