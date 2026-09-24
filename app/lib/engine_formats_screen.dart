import 'package:flutter/material.dart';
import 'engines.dart';
import 'l10n.dart';

/// Full list of playable formats, grouped by playback engine. Reached from
/// Settings → À propos → "Formats lus".
class EngineFormatsScreen extends StatelessWidget {
  const EngineFormatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.enginesFormatsTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.enginesFormatsSummary(kTotalFormatCount, kEngines.length),
              style: tt.bodyMedium,
            ),
          ),
          const Divider(height: 1),
          for (final e in kEngines)
            ExpansionTile(
              leading: const Icon(Icons.memory_outlined),
              title: Text(e.name),
              subtitle: Text(
                  l10n.enginesLicenseFormats(e.license, e.formatCount),
                  style: tt.bodySmall),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(e.descriptionOf(l10n),
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final ext in e.formats.toList()..sort())
                      Chip(
                        label: Text('.$ext', style: tt.labelSmall),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                      ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
