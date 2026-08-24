import 'dart:async';

import 'package:flutter/foundation.dart';

/// Drives refetching of the home screen's server-backed rails.
///
/// The rails cache their fetch in a State field, and the shell keeps the home
/// subtree alive in an IndexedStack, so on their own they fetch exactly once per
/// app process: a server-side change never shows up, and an offline launch
/// leaves them empty until the app is killed and relaunched.
///
/// Two triggers, both TTL-guarded so a rail is never hammered:
///  * [refresh] — app resumed / home tab re-selected (stale data).
///  * a backoff retry timer, armed only while a rail reports a FAILED fetch
///    (offline launch, server down). A fetch that legitimately returns no rows
///    is not a failure and arms nothing — hence [reportResult] takes `failed`,
///    not `isEmpty`, and the RPCs must throw rather than return `[]` on error.
class HomeRefresh extends ChangeNotifier {
  HomeRefresh._();
  static final HomeRefresh instance = HomeRefresh._();

  /// Rails refetch whenever this changes. Also seeds their first fetch, so a
  /// rail only has to react to one thing.
  int get revision => _revision;
  int _revision = 0;

  DateTime? _lastBump;

  /// Rails whose last fetch failed, keyed by an arbitrary per-rail token.
  final Set<Object> _failed = {};
  Timer? _retry;
  int _attempt = 0;

  /// Minimum age before a resume/tab-select refresh actually refetches.
  static const _ttl = Duration(minutes: 10);

  static const _backoff = <Duration>[
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

  /// Refetch if the data is older than [_ttl] (or [force]).
  void refresh({bool force = false}) {
    final last = _lastBump;
    if (!force && last != null && DateTime.now().difference(last) < _ttl) {
      return;
    }
    _bump();
  }

  void _bump() {
    _lastBump = DateTime.now();
    _revision++;
    notifyListeners();
  }

  /// A rail reporting the outcome of the fetch it ran for [revision].
  void reportResult(Object railKey, {required bool failed}) {
    if (failed) {
      _failed.add(railKey);
    } else {
      _failed.remove(railKey);
    }
    if (_failed.isEmpty) {
      _retry?.cancel();
      _retry = null;
      _attempt = 0;
      return;
    }
    // Already waiting on a retry: let it fire rather than restarting the delay
    // once per rail.
    if (_retry != null) return;
    final delay = _backoff[_attempt.clamp(0, _backoff.length - 1)];
    _attempt++;
    _retry = Timer(delay, () {
      _retry = null;
      _bump();
    });
  }

  /// A rail going away — drop its outcome, and disarm the retry if it was the
  /// only one still failing.
  void forget(Object railKey) {
    if (!_failed.remove(railKey) || _failed.isNotEmpty) return;
    _retry?.cancel();
    _retry = null;
    _attempt = 0;
  }

  @visibleForTesting
  void resetForTest() {
    _retry?.cancel();
    _retry = null;
    _attempt = 0;
    _failed.clear();
    _lastBump = null;
    _revision = 0;
  }
}
