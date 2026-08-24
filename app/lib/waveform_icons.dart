import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Oscilloscope glyphs for the visualizer buttons, drawn rather than picked
/// from a font: no Material icon says "a trace" (graphic_eq is a bar meter) and
/// none at all says "SEVERAL traces", which is the whole difference between the
/// stereo scope and the per-voice one.
///
/// [traces] is the entire design: ONE line for the stereo scope, TWO stacked
/// and deliberately out of step for the per-voice scope. The second one is not
/// a copy — different frequency, different phase, smaller amplitude — because
/// two identical waves read as one thick line, not as two voices.
class WaveformIcon extends StatelessWidget {
  final double size;
  final Color color;
  final int traces;

  const WaveformIcon({
    super.key,
    required this.size,
    required this.color,
    this.traces = 1,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _WaveformPainter(color, traces)),
      );
}

class _WaveformPainter extends CustomPainter {
  final Color color;
  final int traces;
  const _WaveformPainter(this.color, this.traces);

  /// One trace, sampled as a polyline. Sampling beats fitting curves here: at
  /// 22 px the eye cannot tell, and it keeps the shape a formula one can read.
  ///
  /// The envelope tapers to zero at both ends (`sin(pi*t)`) so a trace starts
  /// and dies on the midline instead of being cut mid-swing at the icon's edge.
  Path _trace(Size box, double cy, double amp, double cycles, double phase) {
    const steps = 56;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = box.width * (0.10 + 0.80 * t);
      final y = cy -
          amp *
              math.sin(math.pi * t) *
              math.sin(2 * math.pi * cycles * t + phase);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      // Thinner when two traces share the box, or they close the gap between
      // them and the pair reads as a single scribble.
      ..strokeWidth = s * (traces > 1 ? 0.085 : 0.105)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // 2.5 cycles rather than 1.5: an odd half-cycle count leaves the trace
    // lopsided (it ends on a downswing), and at 22 px that reads as a mistake
    // rather than as a wave. Checked by rendering the formula at the real size.
    if (traces <= 1) {
      canvas.drawPath(_trace(size, s * 0.5, s * 0.30, 2.5, 0), paint);
      return;
    }
    // Two voices: upper and lower halves, one slower than the other and a
    // half-cycle apart, so they never look like the same wave drawn twice.
    canvas.drawPath(_trace(size, s * 0.30, s * 0.17, 1.5, 0), paint);
    canvas.drawPath(_trace(size, s * 0.70, s * 0.17, 2.5, math.pi), paint);
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.color != color || old.traces != traces;
}
