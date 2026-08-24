import 'dart:io';
import 'package:flutter/services.dart';

/// Requests extra background execution time on iOS (UIApplication
/// beginBackgroundTask) so an in-flight download keeps running for a while after
/// the app is backgrounded without audio playing. When audio IS playing the
/// app already stays alive via the `audio` UIBackgroundMode; this covers the
/// download-only case (best-effort: iOS grants ~30s).
///
/// No-op on every platform except iOS.
class BackgroundTask {
  static const _ch = MethodChannel('rewamp/background');

  /// Runs [body] wrapped in a background task. Always ends the task, even on
  /// error. Failures to acquire the task are ignored — [body] still runs.
  static Future<T> guard<T>(Future<T> Function() body) async {
    if (!Platform.isIOS) return body();
    int? id;
    try {
      id = await _ch.invokeMethod<int>('begin');
    } catch (_) {
      id = null;
    }
    try {
      return await body();
    } finally {
      if (id != null) {
        try {
          await _ch.invokeMethod<void>('end', id);
        } catch (_) {}
      }
    }
  }
}
