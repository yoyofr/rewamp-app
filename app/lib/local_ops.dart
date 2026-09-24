import 'package:flutter/material.dart';

import 'l10n.dart';

/// Ce qu'une opération LOCALE longue est en train de faire.
///
/// Importer une grosse archive (extraction native, puis des centaines de
/// lignes à enregistrer) ou effacer un dossier de plusieurs centaines de
/// fichiers prend des secondes, parfois des dizaines. Rien ne bloque — le
/// geste rend la main tout de suite — mais sans retour l'utilisateur ne sait
/// pas si ça tourne, et s'il quitte l'écran Local puis y revient, il ne trouve
/// ni progression ni signe de vie. D'où cet état de PROCESSUS, hors de tout
/// écran: les boucles d'import et de suppression le tiennent à jour, et deux
/// bandeaux le lisent — en tête des écrans Local, et dans la coquille à côté
/// du bandeau de téléchargement, pour qu'on le voie même ailleurs.
///
/// Une pile, pas une case: un dépôt pendant un import en cours ouvre une
/// seconde opération, et la fin de l'une ne doit pas effacer l'autre. Le
/// bandeau montre la plus récente.
enum LocalOpKind { import, delete }

enum LocalOpPhase { copying, extracting, registering, deleting }

class LocalOpState {
  final LocalOpKind kind;
  /// Nom du fichier, de l'archive ou du dossier; null = une sélection.
  final String? name;
  final LocalOpPhase phase;
  final int done;
  /// null = inconnu (extraction native, copie d'un arbre dont on ne connaît
  /// pas le compte à l'avance): barre indéterminée, compteur seul.
  final int? total;

  const LocalOpState(this.kind, this.name, this.phase, this.done, this.total);

  LocalOpState copyWith({LocalOpPhase? phase, int? done, int? total,
      bool dropTotal = false}) =>
      LocalOpState(kind, name, phase ?? this.phase, done ?? this.done,
          dropTotal ? null : (total ?? this.total));
}

class LocalOps extends ChangeNotifier {
  LocalOps._();
  static final LocalOps instance = LocalOps._();

  final List<LocalOpState> _stack = <LocalOpState>[];
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  /// L'opération affichée (la plus récente), ou null au repos.
  LocalOpState? get current => _stack.isEmpty ? null : _stack.last;
  int get count => _stack.length;

  /// Ouvre une opération; TOUJOURS fermée par [end], dans un `finally`.
  void begin(LocalOpKind kind, {String? name, LocalOpPhase? phase}) {
    _stack.add(LocalOpState(kind, name,
        phase ?? (kind == LocalOpKind.delete
            ? LocalOpPhase.deleting
            : LocalOpPhase.copying),
        0, null));
    _emit(force: true);
  }

  /// Nouvelle phase de l'opération courante, compteur remis à zéro.
  void phase(LocalOpPhase phase, {int? total}) {
    if (_stack.isEmpty) return;
    _stack[_stack.length - 1] = _stack.last
        .copyWith(phase: phase, done: 0, total: total, dropTotal: total == null);
    _emit(force: true);
  }

  /// Avancée dans la phase courante. Notifie au plus dix fois par seconde:
  /// une boucle d'enregistrement fait des centaines de pas, et chaque
  /// notification reconstruit des bandeaux.
  void progress(int done, {int? total}) {
    if (_stack.isEmpty) return;
    final cur = _stack.last;
    _stack[_stack.length - 1] =
        cur.copyWith(done: done, total: total ?? cur.total);
    _emit(force: total != null && done >= total);
  }

  void end() {
    if (_stack.isEmpty) return;
    _stack.removeLast();
    _emit(force: true);
  }

  void _emit({bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastNotify).inMilliseconds < 100) return;
    _lastNotify = now;
    notifyListeners();
  }
}

/// Le bandeau: une ligne fine, spinner + libellé + compteur, barre linéaire
/// quand le total est connu. Rien au repos. Même dessin que le bandeau de
/// téléchargement (download_banner.dart), pour que les deux se lisent comme
/// une seule famille d'« activité en cours ».
class LocalOpsBanner extends StatelessWidget {
  const LocalOpsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalOps.instance,
      builder: (context, _) {
        final op = LocalOps.instance.current;
        if (op == null) return const SizedBox.shrink();
        final l10n = context.l10n;
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        final title = switch (op.kind) {
          LocalOpKind.import => op.name != null
              ? l10n.localOpsImporting(op.name!)
              : l10n.localOpsImportingSelection,
          LocalOpKind.delete => l10n.localOpsDeleting(op.name ?? ''),
        };
        final phase = switch (op.phase) {
          LocalOpPhase.copying     => l10n.localOpsPhaseCopying,
          LocalOpPhase.extracting  => l10n.localOpsPhaseExtracting,
          LocalOpPhase.registering => l10n.localOpsPhaseRegistering,
          LocalOpPhase.deleting    => l10n.localOpsPhaseDeleting,
        };
        // Le compteur est un NOMBRE, pas une phrase: pas de clé de traduction
        // à décliner, et « 12 / 340 » se lit pareil partout.
        final count = op.total != null
            ? '${op.done} / ${op.total}'
            : (op.done > 0 ? '${op.done}' : '');
        final ratio = (op.total != null && op.total! > 0)
            ? (op.done / op.total!).clamp(0.0, 1.0)
            : null;

        return Material(
          color: cs.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, value: ratio),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    count.isEmpty ? '$title · $phase' : '$title · $phase · $count',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                if (ratio != null)
                  SizedBox(
                    width: 90,
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
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
