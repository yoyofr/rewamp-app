import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RendererBinding;

/// Wraps a horizontally-scrolling child (built with the provided
/// [ScrollController]) and overlays fade-in left/right arrow buttons on the
/// edges that can still scroll. Clicking an arrow scrolls one page.
///
/// Desktop-only affordance: many mice can't scroll horizontally, so the
/// arrows give a click target. On touch/trackpad they're harmless (they only
/// appear on hover-less platforms too, but do nothing intrusive).
class HorizontalScrollArrows extends StatefulWidget {
  /// Builds the scrollable; MUST attach [controller] to its ListView/scroll.
  final Widget Function(BuildContext, ScrollController) builder;

  /// Fraction of the viewport width scrolled per arrow click.
  final double pageFraction;

  /// If set, the arrows are vertically centred on this Y (from the top of the
  /// scroll area) instead of the full-height centre. Use it to line the arrows
  /// up with the middle of the artwork when cards have a text caption below.
  final double? centerY;

  const HorizontalScrollArrows({
    super.key,
    required this.builder,
    this.pageFraction = 0.8,
    this.centerY,
  });

  @override
  State<HorizontalScrollArrows> createState() => _HorizontalScrollArrowsState();
}

class _HorizontalScrollArrowsState extends State<HorizontalScrollArrows> {
  final _controller = ScrollController();
  bool _canLeft = false;
  bool _canRight = false;
  // Arrows are for mouse users (a mouse may lack a horizontal scroll wheel);
  // hidden for touch. Driven by the pointer kind actually used, not the OS —
  // a tablet with a mouse gets arrows, a touchscreen laptop doesn't until a
  // mouse is used. Seeded from whether any mouse is currently connected.
  bool _hasMouse = RendererBinding.instance.mouseTracker.mouseIsConnected;
  bool _hovering = false;   // pointer currently over the rail

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
    // First frame: positions aren't available until after layout.
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  void _onPointer(PointerEvent e) {
    final mouse = e.kind == PointerDeviceKind.mouse;
    if (mouse != _hasMouse) setState(() => _hasMouse = mouse);
  }

  @override
  void dispose() {
    _controller.removeListener(_update);
    _controller.dispose();
    super.dispose();
  }

  void _update() {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final left  = p.pixels > p.minScrollExtent + 1;
    final right = p.pixels < p.maxScrollExtent - 1;
    if (left != _canLeft || right != _canRight) {
      setState(() { _canLeft = left; _canRight = right; });
    }
  }

  void _scrollBy(double sign) {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final delta = p.viewportDimension * widget.pageFraction * sign;
    _controller.animateTo(
      (p.pixels + delta).clamp(p.minScrollExtent, p.maxScrollExtent),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Listener sees the pointer kind (hover for mouse, down for touch) to keep
    // _hasMouse in sync with the device actually being used.
    return MouseRegion(
      onEnter: (_) { if (!_hovering) setState(() => _hovering = true); },
      onExit:  (_) { if (_hovering) setState(() => _hovering = false); },
      child: Listener(
        onPointerHover: _onPointer,
        onPointerDown:  _onPointer,
        child: LayoutBuilder(builder: (context, constraints) {
          // Re-evaluate scrollability when the width changes (window resize).
          WidgetsBinding.instance.addPostFrameCallback((_) => _update());
          final show = _hasMouse && _hovering;
          return Stack(
            children: [
              widget.builder(context, _controller),
              _arrow(cs, left: true,  visible: show && _canLeft),
              _arrow(cs, left: false, visible: show && _canRight),
            ],
          );
        }),
      ),
    );
  }

  Widget _arrow(ColorScheme cs, {required bool left, required bool visible}) {
    const pillH = 72.0;
    final pill = IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        // Slim, vertically-elongated translucent pill.
        child: Material(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(9),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _scrollBy(left ? -1.0 : 1.0),
            child: SizedBox(
              width: 26,
              height: pillH,
              child: Icon(left ? Icons.chevron_left : Icons.chevron_right,
                  size: 22, color: cs.onSurface),
            ),
          ),
        ),
      ),
    );
    // Centre on centerY (artwork middle) when provided, else full height.
    if (widget.centerY != null) {
      return Positioned(
        left:  left ? 8 : null,
        right: left ? null : 8,
        top:   widget.centerY! - pillH / 2,
        child: pill,
      );
    }
    return Positioned(
      left:   left ? 8 : null,
      right:  left ? null : 8,
      top: 0,
      bottom: 0,
      child: Center(child: pill),
    );
  }
}
