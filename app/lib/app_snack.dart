import 'dart:async';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

/// Central in-app notification (the "bordereau"). Every transient message goes
/// through here instead of a raw SnackBar so they all share one compact look:
///   * fixed small height (single line, never wraps to a tall block),
///   * long text auto-scrolls (marquee) instead of growing the banner,
///   * a tap anywhere dismisses it immediately.
///
/// Rendered as a TOP overlay banner, not a bottom SnackBar. A floating SnackBar
/// clears a Scaffold's bottomNavigationBar but not the system gesture/home
/// inset when there is none (the player runs its own nav-bar-less Scaffold), so
/// the banner overlapped the Android home indicator. The top edge only has the
/// status bar, which SafeArea handles uniformly on every screen and platform.
/// Inserted into the ROOT overlay (above all routes, incl. the player sheet), so
/// it is always visible — the reason the player used to need its own messenger.
class AppSnack {
  AppSnack._();

  static OverlayEntry? _entry;
  static ValueNotifier<bool>? _visible;
  static Timer? _timer;

  /// App-level navigator, wired into [MaterialApp.navigatorKey]. Its overlay is
  /// the FALLBACK when a call site's own context/messenger is defunct — e.g. a
  /// download that outlived the screen that started it, whose captured
  /// messenger.context no longer resolves an overlay (the queue → downloadAndPlay
  /// path, where the "unsupported format" banner silently no-op'd). Note: the
  /// navigator's OWN overlay is used (not Overlay.maybeOf on its context, which
  /// walks ANCESTORS and would miss the overlay sitting below it).
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

  /// Resolves the root overlay from [ctx] first, then the app-level navigator.
  static OverlayState? _overlay(BuildContext? ctx) {
    if (ctx != null) {
      final o = Overlay.maybeOf(ctx, rootOverlay: true);
      if (o != null) return o;
    }
    return navigatorKey.currentState?.overlay;
  }

  /// Show [message] from a [BuildContext].
  static void show(BuildContext context, String message,
      {bool isError = false, Duration? duration}) {
    final overlay = _overlay(context);
    if (overlay != null) {
      _showIn(overlay, message, isError: isError, duration: duration);
    }
  }

  /// Show from an already-captured [ScaffoldMessengerState] (call sites that
  /// grabbed the messenger before an await because their context may unmount).
  /// Falls back to the app-level messenger when that context is defunct.
  static void showOn(ScaffoldMessengerState messenger, String message,
      {bool isError = false, Duration? duration}) {
    final overlay = _overlay(messenger.context);
    if (overlay != null) {
      _showIn(overlay, message, isError: isError, duration: duration);
    }
  }

  static void _showIn(OverlayState overlay, String message,
      {required bool isError, Duration? duration}) {
    _removeNow(); // replace any current banner instantly
    final vis = ValueNotifier<bool>(true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopSnack(
        message: message,
        isError: isError,
        visible: vis,
        onTap: _dismiss,
        onGone: () => _finish(entry, vis),
      ),
    );
    _entry = entry;
    _visible = vis;
    overlay.insert(entry);
    _timer = Timer(duration ?? const Duration(seconds: 3), _dismiss);
  }

  /// Animate the current banner out; [_finish] tears it down once the reverse
  /// animation completes.
  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _visible?.value = false;
  }

  /// Called by the banner once its exit animation is done. Guarded by identity
  /// so a stale banner finishing its reverse can't clear a newer one's state.
  static void _finish(OverlayEntry entry, ValueNotifier<bool> vis) {
    if (_entry == entry) {
      _timer?.cancel();
      _timer = null;
      _entry = null;
      _visible = null;
    }
    entry.remove();      // → _TopSnack.dispose removes its listener (vis alive)
    vis.dispose();
  }

  /// Tear the current banner down immediately (no exit animation), e.g. before
  /// showing a replacement.
  static void _removeNow() {
    final e = _entry;
    final v = _visible;
    _timer?.cancel();
    _timer = null;
    _entry = null;
    _visible = null;
    e?.remove();         // dispose removes its listener while v is still alive
    v?.dispose();
  }
}

/// The overlay banner: pinned below the status bar, slides + fades in, and
/// reverses out when [visible] flips to false.
class _TopSnack extends StatefulWidget {
  const _TopSnack({
    required this.message,
    required this.isError,
    required this.visible,
    required this.onTap,
    required this.onGone,
  });

  final String message;
  final bool isError;
  final ValueListenable<bool> visible;
  final VoidCallback onTap;
  final VoidCallback onGone;

  @override
  State<_TopSnack> createState() => _TopSnackState();
}

class _TopSnackState extends State<_TopSnack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _anim = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    _ctrl.forward();
    widget.visible.addListener(_onVisibility);
  }

  void _onVisibility() {
    if (!widget.visible.value) {
      _ctrl.reverse().then((_) {
        if (mounted) widget.onGone();
      });
    }
  }

  @override
  void dispose() {
    widget.visible.removeListener(_onVisibility);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              // Keep it readable, not screen-wide, on tablets/desktop.
              constraints: const BoxConstraints(maxWidth: 560),
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, child) => Opacity(
                  opacity: _anim.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, (1 - _anim.value) * -24),
                    child: child,
                  ),
                ),
                child: _SnackContent(
                  message: widget.message,
                  isError: widget.isError,
                  onTap: widget.onTap,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SnackContent extends StatelessWidget {
  const _SnackContent(
      {required this.message, required this.isError, required this.onTap});

  final String message;
  final bool isError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bg = isError ? cs.errorContainer : cs.inverseSurface;
    final fg = isError ? cs.onErrorContainer : cs.onInverseSurface;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Material(
        color: bg,
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              if (isError) ...[
                Icon(Icons.error_outline, size: 15, color: fg),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _Marquee(
                  message,
                  style: tt.bodySmall?.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single-line text that horizontally auto-scrolls (back and forth, looping)
/// when it doesn't fit, and stays put when it does. Keeps the banner one line
/// tall regardless of message length.
class _Marquee extends StatefulWidget {
  const _Marquee(this.text, {this.style});
  final String text;
  final TextStyle? style;

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee> {
  final _sc = ScrollController();
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loop());
  }

  Future<void> _loop() async {
    if (_running) return;
    _running = true;
    // Let the first frame settle, then scroll only if the text overflows.
    while (mounted && _sc.hasClients) {
      final max = _sc.position.maxScrollExtent;
      if (max <= 0) break; // fits — nothing to scroll
      // Pixels/second → duration; clamp so short and very long strings both
      // scroll at a readable pace.
      final ms = (max * 14).clamp(1600, 9000).toInt();
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted || !_sc.hasClients) break;
      await _sc.animateTo(_sc.position.maxScrollExtent,
          duration: Duration(milliseconds: ms), curve: Curves.linear);
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted || !_sc.hasClients) break;
      await _sc.animateTo(0,
          duration: Duration(milliseconds: ms), curve: Curves.linear);
    }
    _running = false;
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _sc,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, maxLines: 1, style: widget.style),
    );
  }
}
