import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Android system-bar policy.
///
/// Tablets (EMUI/MIUI/HyperOS and friends) keep a navigation/dock strip pinned
/// at the bottom, and swiping in from the edge opens the launcher dock. Most
/// full-screen apps hide it on launch and let a swipe bring it back briefly;
/// rewamp did not, so it sat above a permanent bar.
///
/// The STATUS bar stays: clock and battery are wanted on the browse/library
/// screens, and hiding both (immersiveSticky) would also fight the player's own
/// fullscreen visualizer mode.
///
/// Android only. iOS has no equivalent strip to reclaim, and on desktop the
/// call is meaningless.
class SystemUi {
  SystemUi._();

  static bool get _applies => !kIsWeb && Platform.isAndroid;

  static Timer? _rehideTimer;

  /// Hide the navigation bar, keeping the status bar.
  ///
  /// The user can still swipe it back in — Android shows it again and leaves it
  /// there, so a callback re-hides it once they are done with it. Without that
  /// re-hide, the first swipe would permanently undo this for the rest of the
  /// session.
  static void hideNavigationBar() {
    if (!_applies) return;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const [SystemUiOverlay.top],
    );
    SystemChrome.setSystemUIChangeCallback((systemOverlaysAreVisible) async {
      _rehideTimer?.cancel();
      if (!systemOverlaysAreVisible) return;
      // Long enough to actually use the bar (or the dock gesture it hosts),
      // short enough that the strip does not just come back for good.
      _rehideTimer = Timer(const Duration(seconds: 3), () {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: const [SystemUiOverlay.top],
        );
      });
    });
  }
}
