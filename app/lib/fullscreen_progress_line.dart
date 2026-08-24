import 'package:flutter/material.dart';

/// Where we are in the track, under the fullscreen transport pill.
///
/// An INDICATOR, not a slider: the fullscreen visualizer already arbitrates a
/// double tap, a horizontal skip swipe, a dismiss drag and — on the notation
/// view — pan and pinch, and adding a fifth recogniser over a 3 px target is how
/// that arbitration starts going wrong. Seeking stays in the player proper,
/// one tap away.
///
/// Its own widget rather than a method, so a test can build it — and the test
/// asserts the fill's HEIGHT as well as its width, because height is where the
/// real bug was: a childless [ColoredBox] inside a [Row] whose cross-axis
/// alignment was the default (centre) laid out at height zero, so the line
/// reserved its space and painted nothing.
class FullscreenProgressLine extends StatelessWidget {
  const FullscreenProgressLine({
    super.key,
    required this.position,
    required this.duration,
    this.height = 3.0,
    this.animate = true,
  });

  /// Seconds played, and the track length in seconds. A duration of 0 means
  /// "unknown", which several backends report for a perfectly playing track —
  /// the caller decides whether to show anything at all in that case.
  final double position;
  final double duration;
  final double height;

  /// Smooth the fill toward [position]. On while the audio drives it (the
  /// position only refreshes four times a second), OFF while a finger does.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    // Same tween as the main seek bar: the position only refreshes four times a
    // second, so without it the line steps visibly instead of gliding.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
          begin: 0.0, end: duration > 0 ? position.clamp(0.0, duration) : 0.0),
      duration: animate ? const Duration(milliseconds: 230) : Duration.zero,
      curve: Curves.linear,
      builder: (_, pos, __) {
        final t = duration > 0 ? (pos / duration).clamp(0.0, 1.0) : 0.0;
        return ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: Row(
              // STRETCH, and this one line is the whole bug. A ColoredBox with
              // NO CHILD is a RenderProxyBox, which takes constraints.smallest;
              // a Row's default cross-axis alignment is centre, which hands its
              // children LOOSE height constraints, so both halves laid out at
              // height ZERO. The line reserved its 3 px and painted nothing -
              // through seven attempts, in four different places, which is
              // exactly why moving it around never changed anything.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: (t * 1000).round().clamp(0, 1000),
                  child: ColoredBox(color: Colors.white.withValues(alpha: 0.9)),
                ),
                Expanded(
                  flex: (1000 - (t * 1000).round()).clamp(0, 1000),
                  child: ColoredBox(color: Colors.white.withValues(alpha: 0.25)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The same line, made scrubbable.
///
/// Two things make this safe over the fullscreen visualizer, which already
/// arbitrates a double tap, a horizontal skip swipe, a dismiss drag and — on
/// the notation view — pan and pinch:
///
///  * the touch area is [hitHeight] tall, not the line's few pixels, and it is
///    `HitTestBehavior.opaque`, so pointers that land on it never reach the
///    visualizer underneath. Nothing has to win an arena that it never enters.
///  * a scrub is HORIZONTAL. The player's dismiss drag only claims when the
///    vertical distance beats the horizontal one, so the two cannot both fire.
///
/// Seeking happens on tap, and on the END of a drag rather than on every
/// update: a seek re-primes the decoder (it runs on its own thread precisely
/// because it is not free), and firing one per frame while a finger moves would
/// be both wasteful and audibly rough. The fill follows the finger meanwhile,
/// so the gesture still reads as continuous.
class FullscreenSeekBar extends StatefulWidget {
  const FullscreenSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.onPointerDown,
    this.width = 148,
    this.height = 4,
    this.hitHeight = 22,
    this.showLabels = true,
  });

  final double position;
  final double duration;
  final ValueChanged<double> onSeek;

  /// Fires on EVERY pointer landing on the touch area, before any recogniser
  /// decides anything. The player uses it to keep its dismiss drag away: that
  /// drag is a raw ancestor [Listener], outside the gesture arena, so the
  /// opaque hit area shields the recognisers underneath but not it - and a
  /// slightly vertical scrub attempt used to fold the whole player. A child in
  /// the hit-test path receives the down FIRST, which is what makes this a
  /// reliable "this gesture starts on the bar" signal.
  final VoidCallback? onPointerDown;
  final double width;
  final double height;
  final double hitHeight;

  /// Elapsed on the left, total on the right. They live HERE rather than in the
  /// caller because the left one has to show the scrub target while a finger is
  /// down, and that state is this widget's.
  final bool showLabels;

  @override
  State<FullscreenSeekBar> createState() => _FullscreenSeekBarState();
}

class _FullscreenSeekBarState extends State<FullscreenSeekBar> {
  double? _dragSeconds;

  bool get _seekable => widget.duration > 0;

  double _secondsAt(double dx) =>
      (dx / widget.width).clamp(0.0, 1.0) * widget.duration;

  @override
  Widget build(BuildContext context) {
    final line = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.height),
        border:
            Border.all(color: Colors.black.withValues(alpha: 0.65), width: 1),
      ),
      child: SizedBox(
        width: widget.width,
        child: FullscreenProgressLine(
          // While scrubbing, show where the finger is rather than where the
          // audio still is — the seek only fires on release.
          position: _dragSeconds ?? widget.position,
          duration: widget.duration,
          height: widget.height,
          // No glide toward a dragged target: the tween is there to smooth the
          // four-per-second position updates, and applying it to a finger would
          // make the fill lag behind it.
          animate: _dragSeconds == null,
        ),
      ),
    );

    final Widget bar = !_seekable
        ? line
        : Listener(
            // See [FullscreenSeekBar.onPointerDown].
            onPointerDown: (_) => widget.onPointerDown?.call(),
            child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => widget.onSeek(_secondsAt(d.localPosition.dx)),
              onHorizontalDragStart: (d) =>
                  setState(() => _dragSeconds = _secondsAt(d.localPosition.dx)),
              onHorizontalDragUpdate: (d) =>
                  setState(() => _dragSeconds = _secondsAt(d.localPosition.dx)),
              onHorizontalDragEnd: (_) {
                final target = _dragSeconds;
                setState(() => _dragSeconds = null);
                if (target != null) widget.onSeek(target);
              },
              onHorizontalDragCancel: () => setState(() => _dragSeconds = null),
              // Clip.none: the scrub bubble floats ABOVE the touch area.
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: widget.width,
                    height: widget.hitHeight,
                    child: Center(child: line),
                  ),
                  // The time bubble, over the finger. The LEFT label already
                  // follows the finger, but on a phone the finger hides the bar
                  // and that label is small and far from where one is aiming -
                  // the convention (YouTube, Apple Music) is the value floating
                  // above the touch point, gone on release. Same outlined text
                  // as everything laid over the visualizer, just bigger; a drag
                  // only, a tap seeks instantly and needs no preview.
                  if (_dragSeconds != null)
                    Positioned(
                      left: widget.duration > 0
                          ? (_dragSeconds! / widget.duration).clamp(0.0, 1.0) *
                              widget.width
                          : 0,
                      top: -26,
                      child: FractionalTranslation(
                        translation: const Offset(-0.5, 0),
                        child: _OutlinedTime(_fmtTime(_dragSeconds!), size: 15),
                      ),
                    ),
                ],
              ),
            ),
            ),
          );

    if (!widget.showLabels) return bar;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OutlinedTime(_fmtTime(_dragSeconds ?? widget.position)),
        const SizedBox(width: 6),
        bar,
        const SizedBox(width: 6),
        // An unknown length prints the same --:-- as the main seek bar rather
        // than a zero, which would read as a track of no duration.
        _OutlinedTime(_seekable ? _fmtTime(widget.duration) : '--:--'),
      ],
    );
  }
}

String _fmtTime(double seconds) {
  final t = seconds.isFinite && seconds > 0 ? seconds.round() : 0;
  final h = t ~/ 3600;
  final m = (t % 3600) ~/ 60;
  final sec = (t % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
}

/// A timestamp beside the seek bar: black stroke behind, white fill in front,
/// like every other glyph laid over the visualizer.
class _OutlinedTime extends StatelessWidget {
  const _OutlinedTime(this.text, {this.size = 11});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Tabular figures: without them the bar shifts sideways as the digits
    // change width, and a seek bar that moves while you aim at it is worse than
    // no labels at all.
    final base = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1.0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Stack(
      children: [
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size / 4.5
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.black.withValues(alpha: 0.85),
          ),
        ),
        Text(text, style: base.copyWith(color: Colors.white)),
      ],
    );
  }
}
