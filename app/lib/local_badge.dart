import 'package:flutter/material.dart';

/// Small overlay badge marking a user-added LOCAL item (not downloaded from the
/// server) — shown at the bottom-left of artwork cards, mirroring the favourite
/// star at the top-right. Local items live only on this device: they are kept
/// out of server stats/library sync but fully usable in the local library.
class LocalBadge extends StatelessWidget {
  final double size;
  const LocalBadge({super.key, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.smartphone,
        size: size,
        color: Colors.white70,
      ),
    );
  }
}
