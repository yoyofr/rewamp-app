import 'package:flutter/material.dart';

/// The two queue-insertion icons, drawn rather than picked from the Material
/// set: "play next" and "play last" differ only by *where* the track lands, and
/// no Material glyph pair says that. This is the Apple Music convention — a
/// stack of bars with one in bold and a chevron pointing at it: bold on top for
/// next, bold at the bottom for last.
class QueuePositionIcon extends StatelessWidget {
  /// true → bold bar on top (play next); false → bold bar at the bottom (last).
  final bool first;
  final double size;
  final Color? color;

  const QueuePositionIcon({super.key, required this.first, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Theme.of(context).iconTheme.color!;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _QueuePositionPainter(first: first, color: c)),
    );
  }
}

class _QueuePositionPainter extends CustomPainter {
  final bool first;
  final Color color;

  _QueuePositionPainter({required this.first, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0; // designed on a 24×24 grid
    final bar = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Three bars; the highlighted one is thicker (the row being targeted).
    const ys = [6.0, 12.0, 18.0];
    final boldIndex = first ? 0 : ys.length - 1;
    for (var i = 0; i < ys.length; i++) {
      final isBold = i == boldIndex;
      bar
        ..strokeWidth = (isBold ? 3.0 : 1.6) * s
        ..color = color.withValues(alpha: isBold ? 1.0 : 0.55);
      canvas.drawLine(
        Offset(9 * s, ys[i] * s),
        Offset(22 * s, ys[i] * s),
        bar,
      );
    }

    // Chevron pointing at the highlighted bar.
    final y = ys[boldIndex] * s;
    final chevron = Paint()
      ..color = color
      ..strokeWidth = 2.0 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(1.5 * s, y - 3.5 * s)
        ..lineTo(5.0 * s, y)
        ..lineTo(1.5 * s, y + 3.5 * s),
      chevron,
    );
  }

  @override
  bool shouldRepaint(_QueuePositionPainter old) =>
      old.first != first || old.color != color;
}
