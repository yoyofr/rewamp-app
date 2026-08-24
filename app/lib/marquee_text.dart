import 'dart:async';

import 'package:flutter/material.dart';

/// Single-line text that scrolls itself when it does not fit.
///
/// Written rather than pulled from a package: the need is narrow (a rail card's
/// caption), and a marquee that scrolls when it must and stays still when it
/// fits is a few lines. Static text never moves — a card whose caption fits
/// should not wiggle.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  /// Scroll speed, logical pixels per second.
  final double velocity;
  /// Pause at each end before turning back.
  final Duration pause;

  const MarqueeText(
    this.text, {
    super.key,
    this.style,
    this.velocity = 26,
    this.pause = const Duration(milliseconds: 1200),
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
    return SingleChildScrollView(
      controller: _ctrl,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
    );
  }
}
