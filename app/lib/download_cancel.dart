import 'dart:async';

/// Thrown by the streamed fetch when its [DownloadCancelToken] was cancelled.
/// Every layer that turns an exception into UI (banner, snack, queue
/// auto-advance) must treat it as « the user asked », NEVER as a failure: it
/// must not flash « download failed », not count toward the network-down
/// threshold, and not report the song.
class DownloadCancelledException implements Exception {
  final String label;
  const DownloadCancelledException([this.label = '']);
  @override
  String toString() => 'DownloadCancelledException($label)';
}

/// Cancellation scope for ONE download chain (a queue job, a play-path fetch,
/// a preset pack install).
///
/// Carried by a **Zone**, not by a parameter: a download chain crosses a dozen
/// call sites (downloadToLibrary → impl → mirror → aux siblings → archive
/// extraction) and threading a token through all of them would be a wide,
/// error-prone diff where one missed hop = a cancel that silently does
/// nothing. The zone value is inherited by every async continuation started
/// inside [run], so the byte loop deep down reads it from [current] with no
/// intermediate cooperation.
///
/// Two abort mechanisms, both needed: the loop polls [isCancelled] per chunk
/// (a fast download would otherwise finish before the socket dies) and every
/// in-flight `http.Client` is [register]ed so [cancel] force-closes it (a
/// STALLED download produces no chunk to poll on, so polling alone would hang
/// until the 30 s inter-chunk timeout).
class DownloadCancelToken {
  static const Object _key = #rewampDownloadCancel;

  bool _cancelled = false;
  final List<void Function()> _closers = [];

  bool get isCancelled => _cancelled;

  /// The token of the chain the current async context belongs to, if any.
  static DownloadCancelToken? get current =>
      Zone.current[_key] as DownloadCancelToken?;

  /// Runs [body] with this token installed for the whole async chain.
  Future<T> run<T>(Future<T> Function() body) =>
      runZoned(body, zoneValues: {_key: this});

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final closers = List<void Function()>.of(_closers);
    _closers.clear();
    for (final c in closers) {
      try {
        c();
      } catch (_) {/* closing a dead client is fine */}
    }
  }

  void throwIfCancelled([String label = '']) {
    if (_cancelled) throw DownloadCancelledException(label);
  }

  /// Registers an abort callback (an http.Client.close) for the duration of a
  /// fetch. Cancelling after the fact runs it immediately.
  void register(void Function() closer) {
    if (_cancelled) {
      try {
        closer();
      } catch (_) {}
      return;
    }
    _closers.add(closer);
  }

  void unregister(void Function() closer) => _closers.remove(closer);
}
