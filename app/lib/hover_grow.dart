import 'package:flutter/material.dart';

import 'tv_focus.dart';

/// Wraps a tappable card: grows slightly on mouse hover (desktop) — and, on
/// Android TV, when it holds the remote's focus, with a visible ring.
///
/// [onTap] / [onLongPress]: give them when the card's own gesture is a bare
/// `GestureDetector` (not focusable): on TV the card then becomes a focus
/// target activated by OK, long-pressed by holding OK or the Menu key. A card
/// built on an InkWell / ListTile is focusable already — leave them null, the
/// ring still follows its focus.
class HoverGrow extends StatefulWidget {
  final Widget child;
  final double scale;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const HoverGrow({
    super.key,
    required this.child,
    this.scale = 1.03,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<HoverGrow> createState() => _HoverGrowState();
}

class _HoverGrowState extends State<HoverGrow> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    final tap = widget.onTap;
    if (tap != null) {
      child = TvActivatable(
          onTap: tap, onLongPress: widget.onLongPress, child: child);
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: AnimatedScale(
        // Pas d'agrandissement au focus TV: une carte en bord de rangée
        // débordait la zone de défilement et son anneau était rogné.
        // L'anneau suffit.
        scale: _hover && !_focus ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: TvFocusRing(
          onFocusChange: (f) => setState(() => _focus = f),
          child: child,
        ),
      ),
    );
  }
}
