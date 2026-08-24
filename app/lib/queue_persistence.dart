import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists the playback queue across launches, with a crash guard ("safe
/// launch"): a synchronous "loading" flag file is written just before each
/// native track load and removed once the load completed without killing the
/// app. If the flag is still present at the next launch, the previous session
/// died while loading a track — the saved queue is NOT restored, so a file
/// that crashes a decoder can't crash-loop the app at startup.
class QueuePersistence {
  QueuePersistence._();

  static String? _dirPath;
  static String get _queueFile => p.join(_dirPath!, 'queue_state.json');
  static String get _flagFile  => p.join(_dirPath!, 'loading.flag');

  static bool _crashedLastLaunch = false;

  /// True when the previous session died mid-load (the flag survived).
  /// Valid after [init]; the flag itself is consumed (deleted) by init so a
  /// clean next session starts fresh.
  static bool get crashedLastLaunch => _crashedLastLaunch;

  /// Resolve + cache the storage dir and read/consume the crash flag.
  /// Must run BEFORE the first track load (called from main()).
  static Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _dirPath = dir.path;
      final f = File(_flagFile);
      _crashedLastLaunch = f.existsSync();
      if (_crashedLastLaunch) {
        debugPrint('[queue-persist] previous session crashed during a track '
            'load — queue restore skipped (safe launch)');
        f.deleteSync();
      }
    } catch (e) {
      debugPrint('[queue-persist] init: $e');
    }
  }

  /// SYNCHRONOUS write (flushed) right before the native load — if the app
  /// dies before [clearLoading], the next launch sees it.
  static void markLoading(String path) {
    if (_dirPath == null) return;
    try {
      File(_flagFile).writeAsStringSync(path, flush: true);
    } catch (_) {}
  }

  /// The load completed without a crash (success OR clean failure — a clean
  /// "can't open this file" is not a crash and must not poison the next
  /// launch).
  static void clearLoading() {
    if (_dirPath == null) return;
    try {
      final f = File(_flagFile);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  /// Snapshot the queue state (fire-and-forget from the queue owner).
  static Future<void> save(Map<String, dynamic> state) async {
    if (_dirPath == null) return;
    try {
      await File(_queueFile).writeAsString(jsonEncode(state));
    } catch (e) {
      debugPrint('[queue-persist] save: $e');
    }
  }

  static Future<Map<String, dynamic>?> load() async {
    if (_dirPath == null) return null;
    try {
      final f = File(_queueFile);
      if (!await f.exists()) return null;
      final decoded = jsonDecode(await f.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('[queue-persist] load: $e');
      return null;
    }
  }

  static Future<void> clear() async {
    if (_dirPath == null) return;
    try {
      final f = File(_queueFile);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
