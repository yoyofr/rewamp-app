// Le bouton lune du lecteur et sa feuille de durées (voir sleep_timer.dart).
//
// N'écoute QUE la minuterie, jamais le tick du contrôleur: l'affichage ne
// change qu'à la minute (puis à la seconde de la dernière minute), et
// SleepTimer ne notifie qu'à ces moments-là.
import 'package:flutter/material.dart';

import 'l10n.dart';
import 'sleep_timer.dart';

String sleepRemainingLabel(AppLocalizations l10n, Duration remaining) {
  final p = sleepRemainingParts(remaining);
  return switch (p.unit) {
    SleepRemainingUnit.minutes => l10n.sleepTimerRemainingMinutes(p.count),
    SleepRemainingUnit.seconds => l10n.sleepTimerRemainingSeconds(p.count),
  };
}

class SleepTimerButton extends StatelessWidget {
  const SleepTimerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final t = SleepTimer.instance;
    return ListenableBuilder(
      listenable: t,
      builder: (context, _) {
        if (!t.active) {
          return IconButton(
            icon: const Icon(Icons.bedtime_outlined),
            tooltip: l10n.sleepTimerTitle,
            onPressed: () => showSleepTimerSheet(context),
          );
        }
        // Allumé: la couleur d'accent ET le temps restant, à côté de la lune.
        return Tooltip(
          message: l10n.sleepTimerTitle,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.bedtime, size: 22),
            label: Text(sleepRemainingLabel(l10n, t.remaining)),
            onPressed: () => showSleepTimerSheet(context),
          ),
        );
      },
    );
  }
}

/// Durées proposées, la durée armée cochée; « Désactiver » quand c'est armé.
/// Choisir une autre durée REPART de zéro.
Future<void> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) {
      final l10n = sheetCtx.l10n;
      final cs = Theme.of(sheetCtx).colorScheme;
      final t = SleepTimer.instance;
      return ListenableBuilder(
        listenable: t,
        builder: (context, _) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: Icon(t.active ? Icons.bedtime : Icons.bedtime_outlined,
                    color: t.active ? cs.primary : null),
                title: Text(l10n.sleepTimerTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(t.active
                    ? l10n.sleepTimerActiveRemaining(
                        sleepRemainingLabel(l10n, t.remaining))
                    : l10n.sleepTimerExplain),
              ),
              const Divider(height: 1),
              for (final m in kSleepTimerMinutes)
                ListTile(
                  title: Text(l10n.sleepTimerMinutes(m)),
                  trailing: t.active && t.chosen == Duration(minutes: m)
                      ? Icon(Icons.check, color: cs.primary)
                      : null,
                  onTap: () {
                    t.start(Duration(minutes: m));
                    Navigator.of(sheetCtx).pop();
                  },
                ),
              if (t.active) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.timer_off_outlined),
                  title: Text(l10n.sleepTimerOff),
                  onTap: () {
                    t.cancel();
                    Navigator.of(sheetCtx).pop();
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
