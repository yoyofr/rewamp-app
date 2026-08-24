import 'dart:async';

import 'package:flutter/foundation.dart';

import 'download_cancel.dart';

/// One queued download: a label for the UI and the closure that actually
/// fetches (RewampDb.downloadToLibrary wrapped by the caller). [key] dedups —
/// enqueueing the same key while it is pending/active is a no-op.
class DownloadJob {
  final int    id;
  final String label;
  final String? artworkUrl;
  final String? key;
  final Future<void> Function() run;
  /// Cancellation scope of THIS job. [run] is executed inside it, so every
  /// fetch it starts — however deep — aborts when the job is cancelled.
  final DownloadCancelToken cancel = DownloadCancelToken();

  DownloadJob._({
    required this.id,
    required this.label,
    required this.run,
    this.artworkUrl,
    this.key,
  });
}

/// Sequential download queue behind the bulk flows (album « Télécharger »,
/// post-play prefetch). ONE job runs at a time — same de-facto policy as the
/// old inline loops, but the queue is now visible, editable and pausable
/// (DownloadQueueScreen, badge on the navbar « … »).
///
/// Pause is BETWEEN files: the in-flight job completes, no new one starts.
/// CANCELLING the active job is the other lever — it aborts the transfer in
/// flight (albums can be hundreds of MB), via the job's DownloadCancelToken.
/// The play path's own urgent downloads never go through here — they must not
/// sit behind a paused queue — so they cancel through
/// RewampDb.cancelAmbientDownloads() instead.
class DownloadManager extends ChangeNotifier {
  DownloadManager._();
  static final DownloadManager instance = DownloadManager._();

  final List<DownloadJob> _pending = [];
  DownloadJob? _active;
  bool _paused = false;
  int  _nextId = 1;

  List<DownloadJob> get pending => List.unmodifiable(_pending);
  DownloadJob? get active => _active;
  bool get paused => _paused;

  /// Jobs not yet finished (badge counter).
  int get count => _pending.length + (_active != null ? 1 : 0);

  void enqueue(
    String label,
    Future<void> Function() run, {
    String? artworkUrl,
    String? key,
  }) {
    if (key != null &&
        (_active?.key == key || _pending.any((j) => j.key == key))) {
      return;
    }
    _pending.add(DownloadJob._(
      id: _nextId++,
      label: label,
      run: run,
      artworkUrl: artworkUrl,
      key: key,
    ));
    notifyListeners();
    _pump();
  }

  /// Removes a job. A PENDING one is dropped; the ACTIVE one is cancelled
  /// mid-transfer (its future then fails with DownloadCancelledException,
  /// which _pump treats like any other completion and moves on).
  void remove(int id) {
    if (_active?.id == id) {
      cancelActive();
      return;
    }
    _pending.removeWhere((j) => j.id == id);
    notifyListeners();
  }

  /// Aborts the download in flight. Safe when nothing is running.
  void cancelActive() {
    final job = _active;
    if (job == null || job.cancel.isCancelled) return;
    job.cancel.cancel();
    // _active is NOT cleared here: the job's future is about to complete with
    // the cancellation and _pump owns that transition. Notify anyway so the
    // row can grey its cancel button out during the (usually instant) wind-down.
    notifyListeners();
  }

  void clearPending() {
    _pending.clear();
    notifyListeners();
  }

  /// Empties the queue AND aborts what is downloading.
  void cancelAll() {
    _pending.clear();
    cancelActive();
    notifyListeners();
  }

  /// Reorder within the pending list. [newIndex] is ALREADY adjusted for the
  /// removal (onReorderItem semantics — same convention as the queue panel).
  void reorderAdjusted(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _pending.length) return;
    final j = _pending.removeAt(oldIndex);
    _pending.insert(newIndex.clamp(0, _pending.length), j);
    notifyListeners();
  }

  void pause() {
    if (_paused) return;
    _paused = true;
    notifyListeners();
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    notifyListeners();
    _pump();
  }

  void _pump() {
    if (_paused || _active != null || _pending.isEmpty) return;
    final job = _pending.removeAt(0);
    _active = job;
    notifyListeners();
    job.cancel
        .run(job.run)
        .catchError((_) {/* the banner already surfaced it */})
        .whenComplete(() {
      _active = null;
      notifyListeners();
      _pump();
    });
  }
}
