// Ce qu'un écran AFFICHE quand son chargement échoue — un message pour
// l'utilisateur, jamais `e.toString()` (« TimeoutException after
// 0:00:25.000000: Future not completed », « search_music HTTP 503 », en
// rouge). La CAUSE précise reste dans les journaux (`debugPrint`).
//
// Quatre familles, du plus au moins fréquent sur un réseau mobile:
//   hors ligne · serveur trop lent / réseau instable · serveur en difficulté ·
//   autre. Les trois premières se RÉPARENT seules: [LoadErrorView] relance son
//   chargement quand NetworkStatus constate le retour du serveur.
import 'package:flutter/material.dart';

import 'l10n.dart';
import 'mini_window.dart';
import 'network_status.dart';

enum LoadErrorKind { offline, slow, server, other }

/// [e] peut être l'exception OU sa forme texte (les écrans gardent souvent
/// `_error = e.toString()`): la classification lit les deux.
LoadErrorKind classifyLoadError(Object e) {
  switch (classifyNetError(e)) {
    case NetIssue.offline:
      return LoadErrorKind.offline;
    case NetIssue.slow:
      return LoadErrorKind.slow;
    case NetIssue.none:
      break;
  }
  final s = e.toString();
  // PostgreSQL a abandonné une requête trop longue (statement_timeout): c'est
  // la charge du serveur, pas une erreur de l'app.
  if (s.contains('57014') || s.contains('statement timeout')) {
    return LoadErrorKind.slow;
  }
  final m = RegExp(r'HTTP (\d{3})|statusCode[:=] ?(\d{3})|\((\d{3})\)').firstMatch(s);
  final code = m == null
      ? null
      : int.tryParse(m.group(1) ?? m.group(2) ?? m.group(3) ?? '');
  if (code != null && (code >= 500 || code == 429 || code == 408)) {
    return code == 408 || code == 504 ? LoadErrorKind.slow : LoadErrorKind.server;
  }
  return LoadErrorKind.other;
}

String loadErrorMessage(AppLocalizations l10n, Object e) =>
    switch (classifyLoadError(e)) {
      LoadErrorKind.offline => l10n.netErrorOffline,
      LoadErrorKind.slow    => l10n.netErrorSlow,
      LoadErrorKind.server  => l10n.netErrorServer,
      LoadErrorKind.other   => l10n.netErrorGeneric,
    };

/// Le message d'un échec SANS le cas « autre »: pour un texte qui a déjà son
/// propre libellé (« Échec du téléchargement : … »), on ne remplace que ce
/// qui est une panne de réseau ou de serveur.
String? netErrorMessageOrNull(AppLocalizations l10n, Object e) {
  final k = classifyLoadError(e);
  return k == LoadErrorKind.other ? null : loadErrorMessage(l10n, e);
}

/// L'échec d'un chargement, au centre d'un écran: icône, message clair,
/// « Réessayer ». Quand c'est le réseau ou le serveur, l'écran se relance
/// SEUL dès que [NetworkStatus] constate le retour.
class LoadErrorView extends StatefulWidget {
  const LoadErrorView({super.key, required this.error, this.onRetry});

  /// L'exception, ou sa forme texte.
  final Object error;
  final VoidCallback? onRetry;

  @override
  State<LoadErrorView> createState() => _LoadErrorViewState();
}

class _LoadErrorViewState extends State<LoadErrorView> {
  final _net = NetworkStatus.instance;

  @override
  void initState() {
    super.initState();
    _net.addListener(_onNet);
    // La cause EXACTE reste lisible dans les journaux: l'écran n'en montre
    // qu'une phrase.
    debugPrint('[load] ${widget.error}');
  }

  @override
  void dispose() {
    _net.removeListener(_onNet);
    super.dispose();
  }

  void _onNet() {
    if (!mounted || _net.value != NetIssue.none) return;
    if (classifyLoadError(widget.error) == LoadErrorKind.other) return;
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final kind = classifyLoadError(widget.error);
    final icon = switch (kind) {
      LoadErrorKind.offline => Icons.cloud_off_outlined,
      LoadErrorKind.slow    => Icons.hourglass_bottom_rounded,
      LoadErrorKind.server  => Icons.dns_outlined,
      LoadErrorKind.other   => Icons.error_outline,
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              loadErrorMessage(l10n, widget.error),
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          if (widget.onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.commonRetry),
              onPressed: () {
                NetworkStatus.instance.probeNow();
                widget.onRetry!();
              },
            ),
          ],
        ]),
      ),
    );
  }
}

/// Bandeau fin, en haut de l'app, tant que le serveur n'est pas joignable —
/// « Hors ligne » ou « Le serveur ne répond pas, nouvel essai automatique ».
/// Il disparaît seul au retour (NetworkStatus sonde régulièrement).
class NetworkBanner extends StatelessWidget {
  const NetworkBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // ⚠️ La FORME de l'arbre ne change jamais (Column → Expanded → child),
    // seul le bandeau apparaît: basculer entre `child` nu et une colonne
    // remonterait toute l'app — Navigator, lecteur, file — à chaque coupure.
    return AnimatedBuilder(
      animation: Listenable.merge([NetworkStatus.instance, MiniWindow.instance]),
      child: child,
      builder: (context, child) {
        final issue = NetworkStatus.instance.value;
        // Le mini lecteur n'a pas la place d'un bandeau.
        final shown = issue != NetIssue.none && !MiniWindow.instance.isMini;
        return Column(children: [
          if (shown) _bar(context, issue),
          Expanded(
            // Le bandeau a pris la zone sûre du haut: l'app en dessous ne
            // doit pas la réserver une seconde fois.
            child: MediaQuery.removePadding(
                context: context, removeTop: shown, child: child!),
          ),
        ]);
      },
    );
  }

  Widget _bar(BuildContext context, NetIssue issue) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final top = MediaQuery.of(context).padding.top;
    final text = issue == NetIssue.offline ? l10n.netBannerOffline : l10n.netBannerSlow;
    return Material(
      color: cs.secondaryContainer,
      child: InkWell(
        // Toucher le bandeau = réessayer tout de suite.
        onTap: NetworkStatus.instance.probeNow,
        child: Padding(
          padding: EdgeInsets.only(top: top + 4, bottom: 4, left: 12, right: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(issue == NetIssue.offline ? Icons.cloud_off_outlined : Icons.wifi_tethering_error,
                size: 16, color: cs.onSecondaryContainer),
            const SizedBox(width: 8),
            Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: cs.onSecondaryContainer)),
            ),
          ]),
        ),
      ),
    );
  }
}
