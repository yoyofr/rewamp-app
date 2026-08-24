import 'package:flutter/material.dart';

/// Desktop hover feedback for a clickable artwork card: slight grow + the
/// click cursor. Shape-agnostic on purpose (no ink veil — the child's corner
/// radius is unknown here), so it can wrap any card whose own GestureDetector
/// keeps the tap. Touch platforms never hover: this is a no-op there.
class HoverGrow extends StatefulWidget {
  final Widget child;
  final double scale;

  const HoverGrow({super.key, required this.child, this.scale = 1.03});

  @override
  State<HoverGrow> createState() => _HoverGrowState();
}

class _HoverGrowState extends State<HoverGrow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
