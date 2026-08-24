import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps the display awake while a visualizer is on screen.
///
/// Watching a visualizer is the one thing this app does that involves NO touch
/// input for minutes at a time, so the system idle timer fires mid-show and
/// blanks it. Same rationale as a video player, and the same fix.
///
/// A MethodChannel rather than a plugin, following `rewamp/route_picker`: the
/// three lines of platform API below are less code than a dependency, and add
/// no `pod install` to the build.
///
/// Reference-COUNTED, not a boolean: the player screen and its fullscreen mode
/// both want the screen awake, they mount and unmount in either order, and a
/// plain flag would let whichever released last win. Callers pair
/// [acquire]/[release] like a lock.
class ScreenWakelock {
  ScreenWakelock._();
  static final ScreenWakelock instance = ScreenWakelock._();

  static const _ch = MethodChannel('rewamp/wakelock');

  int _holders = 0;
  bool _enabled = false;

  /// Whether the platform can hold the display awake at all. Linux and Windows
  /// have no handler (their desktop builds are not started yet), and every call
  /// there would throw a MissingPluginException per toggle.
  static bool get supported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isMacOS);

  Future<void> acquire() async {
    _holders++;
    await _sync();
  }

  Future<void> release() async {
    if (_holders > 0) _holders--;
    await _sync();
  }

  /// Drops every hold — for the setting being switched off while a visualizer
  /// is up, where the screen must go back to normal immediately.
  Future<void> releaseAll() async {
    _holders = 0;
    await _sync();
  }

  Future<void> _sync() async {
    final want = _holders > 0;
    if (want == _enabled || !supported) return;
    _enabled = want;
    try {
      await _ch.invokeMethod<void>('set', {'on': want});
    } catch (e) {
      // Never let a display nicety break playback: an OS that refuses the
      // request simply sleeps as usual.
      debugPrint('ScreenWakelock: $e');
      _enabled = false;
    }
  }
}
