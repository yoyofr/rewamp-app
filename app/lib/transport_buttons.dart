import 'package:flutter/material.dart';

import 'l10n.dart';

/// Shuffle / loop toggles, shared by the queue-panel header (full player and
/// desktop sidebar) and the desktop mini-player transport row. Active state is
/// a colour change (rewamp magenta), not a filled background pill.

const Color kTransportActiveAccent = Color(0xFFEC2B88);

/// Idle toggles are chrome, not transport: dimmed so the active state (and the
/// play/skip buttons next to them) stay the eye's first stop.
Color _idleColor(ColorScheme cs) => cs.onSurfaceVariant.withValues(alpha: 0.45);

class ShuffleButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onToggle;
  final double? iconSize;

  const ShuffleButton({
    super.key,
    required this.enabled,
    required this.onToggle,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      iconSize: iconSize,
      tooltip: enabled ? l10n.transportShuffleOn : l10n.transportShuffle,
      icon: Icon(Icons.shuffle,
          color: enabled ? kTransportActiveAccent : _idleColor(cs)),
      onPressed: onToggle,
    );
  }
}

class LoopButton extends StatelessWidget {
  /// 0 = off, 1 = queue, 2 = current track.
  final int mode;
  final VoidCallback? onCycle;
  final double? iconSize;

  const LoopButton({
    super.key,
    required this.mode,
    required this.onCycle,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      iconSize: iconSize,
      tooltip: switch (mode) {
        1 => l10n.transportLoopQueue,
        2 => l10n.transportLoopTrack,
        _ => l10n.transportLoopOff,
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.repeat,
              color: mode != 0 ? kTransportActiveAccent : _idleColor(cs)),
          if (mode == 2)
            const Positioned(
              right: -4,
              bottom: -4,
              child: Icon(Icons.looks_one,
                  size: 12, color: kTransportActiveAccent),
            ),
        ],
      ),
      onPressed: onCycle,
    );
  }
}
