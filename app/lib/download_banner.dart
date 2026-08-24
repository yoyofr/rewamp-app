import 'package:flutter/material.dart';
import 'download_manager.dart';
import 'l10n.dart';
import 'rewamp_db.dart' show DownloadInfo, RewampDb;

/// Thin global banner above the mini player showing the live download state
/// (RewampDb.downloadStatus): label + progress bar while fetching, error line
/// for a few seconds on failure, nothing when idle. Makes queue/radio track
/// changes visible instead of silently hanging on a slow or dead network.
///
/// The ✕ aborts what the bar is measuring. Which token that is depends on WHO
/// is fetching: a queue job owns its own (cancel it through the manager, so
/// the queue moves on to the next file), anything else — the play path — runs
/// on the ambient one. Cancelling the wrong one would leave the bar running.
class DownloadBanner extends StatelessWidget {
  const DownloadBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ValueListenableBuilder<DownloadInfo?>(
      valueListenable: RewampDb.downloadStatus,
      builder: (context, info, _) {
        if (info == null) return const SizedBox.shrink();

        if (info.error != null) {
          return Material(
            color: cs.errorContainer,
            child: InkWell(
              onTap: () => RewampDb.downloadStatus.value = null, // dismiss
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.downloadFailed(info.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
                      ),
                    ),
                    Icon(Icons.close, size: 14, color: cs.onErrorContainer),
                  ],
                ),
              ),
            ),
          );
        }

        final label = info.progress != null
            ? l10n.downloadInProgressPct(
                info.label, (info.progress! * 100).round())
            : l10n.downloadInProgress(info.label);
        return Material(
          color: cs.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: info.progress,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                if (info.progress != null)
                  SizedBox(
                    width: 90,
                    child: LinearProgressIndicator(
                      value: info.progress,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                const SizedBox(width: 4),
                InkResponse(
                  onTap: () {
                    final job = DownloadManager.instance.active;
                    if (job != null) {
                      DownloadManager.instance.cancelActive();
                    } else {
                      RewampDb.cancelAmbientDownloads();
                    }
                  },
                  radius: 16,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Tooltip(
                      message: l10n.downloadsCancel,
                      child: Icon(Icons.close,
                          size: 14, color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
