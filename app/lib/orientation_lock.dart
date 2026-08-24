import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Phone-only portrait lock. Tablets and desktops rotate freely; phones are
/// portrait-locked except while a fullscreen visual (viz / video) is active.
class OrientationLock {
  OrientationLock._();

  static bool? _isPhoneMemo;

  /// Phone = mobile OS + shortest side < 600 dp (the Material tablet cutoff).
  static bool get isPhone {
    final memo = _isPhoneMemo;
    if (memo != null) return memo;
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) {
      return _isPhoneMemo = false;
    }
    final view = ui.PlatformDispatcher.instance.implicitView;
    if (view == null || view.physicalSize.isEmpty) {
      // Metrics not ready yet — don't memoize a guess, retry on the next call.
      return false;
    }
    final shortestDp = view.physicalSize.shortestSide / view.devicePixelRatio;
    return _isPhoneMemo = shortestDp < 600;
  }

  /// Default state: portrait-only on phones, no-op elsewhere.
  static void lock() {
    if (!isPhone) return;
    SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.portraitUp]);
  }

  /// Fullscreen visual active: let the phone rotate. Empty list restores the
  /// platform defaults (Info.plist / manifest), which allow landscape.
  static void unlock() {
    if (!isPhone) return;
    SystemChrome.setPreferredOrientations(const []);
  }
}
