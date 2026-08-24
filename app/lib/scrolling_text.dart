import 'dart:async';
import 'package:flutter/material.dart';

/// Single-line text that auto-scrolls (ping-pong) when it overflows its
/// container.  Static when it fits.
class ScrollingText extends StatefulWidget {
  final String     text;
  final TextStyle? style;
  final int        pauseMs;
  final double     pixelsPerSecond;

  const ScrollingText({
    super.key,
    required this.text,
    this.style,
    this.pauseMs        = 1500,
    this.pixelsPerSecond = 40,
  });

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText> {
  final _scroll = ScrollController();
  Timer? _timer;
  double _containerWidth = 0;
  double _textWidth = 0;
  // Bumped whenever the text changes. An in-flight animateTo() from the OLD
  // (long) text keeps running after the text is swapped — cancelling the timer
  // doesn't stop the awaited animation, and its continuation would re-arm a
  // scroll on the NEW (short) text, dragging it off-screen. Every async step
  // captures this token and bails when it no longer matches.
  int _gen = 0;

  bool get _overflows => _textWidth > _containerWidth + 1;

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

  void _scheduleScroll({required bool toEnd}) {
    _cancel();
    final gen = _gen;
    _timer = Timer(Duration(milliseconds: widget.pauseMs), () async {
      if (!mounted || gen != _gen || !_scroll.hasClients || !_overflows) return;
      final target = toEnd ? (_textWidth - _containerWidth) : 0.0;
      final dist   = (target - _scroll.offset).abs();
      if (dist < 1) { _scheduleScroll(toEnd: !toEnd); return; }
      final ms = (dist / widget.pixelsPerSecond * 1000).round();
      await _scroll.animateTo(
        target,
        duration: Duration(milliseconds: ms),
        curve:    Curves.linear,
      );
      // The text may have changed mid-animation (interrupted by jumpTo) — the
      // token guard stops a stale continuation from re-scrolling the new text.
      if (mounted && gen == _gen) _scheduleScroll(toEnd: !toEnd);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cw    = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final style = widget.style ?? DefaultTextStyle.of(ctx).style;
        final tp = TextPainter(
          text:      TextSpan(text: widget.text, style: style),
          maxLines:  1,
          textDirection: Directionality.of(ctx),
        )..layout(minWidth: 0, maxWidth: double.infinity);
        final tw = tp.width;

        if (cw != _containerWidth || tw != _textWidth) {
          _containerWidth = cw;
          _textWidth      = tw;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _cancel();
            if (_scroll.hasClients) _scroll.jumpTo(0);
            if (_overflows) _scheduleScroll(toEnd: true);
          });
        }

        return ClipRect(
          child: SingleChildScrollView(
            controller:      _scroll,
            scrollDirection: Axis.horizontal,
            physics:         const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: tw > cw ? tw : null,
              child: Text(widget.text, style: style, maxLines: 1, softWrap: false),
            ),
          ),
        );
      },
    );
  }
}
