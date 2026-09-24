import 'package:flutter/material.dart';

import 'artwork_image.dart';
import 'download_manager.dart';
import 'l10n.dart';
import 'scrolling_text.dart';
import 'rewamp_db.dart' show DownloadInfo, RewampDb;

/// The download queue: the active fetch (live progress from
/// RewampDb.downloadStatus) + the pending jobs, reorderable and removable.
/// Pause stops BETWEEN files; the ✕ on the ACTIVE row aborts the transfer in
/// flight (a big album is not something to sit through once regretted).
class DownloadQueueScreen extends StatelessWidget {
  const DownloadQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;
    final mgr  = DownloadManager.instance;

    return ListenableBuilder(
      // The status notifier too: a PLAY-path download runs OUTSIDE the manager
      // (deliberately — it must not wait behind a paused queue) but must still
      // be VISIBLE here, as its own active row (cancellable, not reorderable).
      listenable: Listenable.merge([mgr, RewampDb.downloadStatus]),
      builder: (context, _) {
        final pending = mgr.pending;
        final active  = mgr.active;
        final direct  = active == null ? RewampDb.downloadStatus.value : null;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.downloadsTitle),
            actions: [
              if (mgr.count > 0 || mgr.paused)
                IconButton(
                  icon: Icon(mgr.paused ? Icons.play_arrow : Icons.pause),
                  tooltip:
                      mgr.paused ? l10n.downloadsResume : l10n.downloadsPause,
                  onPressed: mgr.paused ? mgr.resume : mgr.pause,
                ),
              if (pending.isNotEmpty || active != null)
                IconButton(
                  icon: const Icon(Icons.clear_all),
                  tooltip: l10n.downloadsClear,
                  // Empties the queue AND aborts the transfer in flight —
                  // « remove all » that leaves a 300 MB album downloading is
                  // not what the button says.
                  onPressed: mgr.cancelAll,
                ),
            ],
          ),
          body: (active == null && direct == null && pending.isEmpty)
              ? Center(
                  child: Text(l10n.downloadsEmpty,
                      style: TextStyle(color: cs.outline)))
              : Column(
                  children: [
                    if (mgr.paused)
                      Container(
                        width: double.infinity,
                        color: cs.surfaceContainerHigh,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(l10n.downloadsPausedBanner,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ),
                    if (active != null)
                      ValueListenableBuilder<DownloadInfo?>(
                        valueListenable: RewampDb.downloadStatus,
                        builder: (context, info, _) => ListTile(
                          leading: SizedBox(
                            width: 40,
                            height: 40,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                _art(active.artworkUrl),
                                CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: info?.progress,
                                ),
                              ],
                            ),
                          ),
                          title: ScrollingText(text: active.label),
                          subtitle: info?.progress != null
                              ? Text('${(info!.progress! * 100).round()} %')
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            tooltip: l10n.downloadsCancel,
                            onPressed: active.cancel.isCancelled
                                ? null
                                : mgr.cancelActive,
                          ),
                        ),
                      ),
                    // Play-path download (urgent, outside the queue): it does
                    // not wait behind the queue, but it IS cancellable — that
                    // is the one the user is staring at when a track turns out
                    // to be a 200 MB album archive.
                    if (active == null && direct != null && direct.error == null)
                      ListTile(
                        leading: SizedBox(
                          width: 40,
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _art(null),
                              CircularProgressIndicator(
                                strokeWidth: 2,
                                value: direct.progress,
                              ),
                            ],
                          ),
                        ),
                        title: ScrollingText(text: direct.label),
                        subtitle: direct.progress != null
                            ? Text('${(direct.progress! * 100).round()} %')
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: l10n.downloadsCancel,
                          onPressed: RewampDb.cancelAmbientDownloads,
                        ),
                      ),
                    if (active != null || direct != null)
                      const Divider(height: 1),
                    Expanded(
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: pending.length,
                        onReorderItem: mgr.reorderAdjusted,
                        itemBuilder: (context, i) {
                          final j = pending[i];
                          return ListTile(
                            key: ValueKey(j.id),
                            leading: _art(j.artworkUrl),
                            title: Text(j.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  tooltip: l10n.commonDelete,
                                  onPressed: () => mgr.remove(j.id),
                                ),
                                ReorderableDragStartListener(
                                  index: i,
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(Icons.drag_handle, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _art(String? url) => SizedBox(
        width: 36,
        height: 36,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ArtworkImage(url: url, size: 36),
        ),
      );
}
