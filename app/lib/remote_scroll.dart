// Faire défiler un texte à la TÉLÉCOMMANDE (Android TV) ou au clavier.
//
// Un `SingleChildScrollView` ne défile qu'au doigt, à la souris ou à la
// molette: ↑/↓ d'une télécommande sont des intentions de FOCUS, et dans un
// écran qui n'a qu'un bouton (note de version, visite guidée) elles ne
// faisaient rien — un texte plus long que l'écran restait coupé, sans moyen
// d'en lire la suite. Les raccourcis se posent sur un ANCÊTRE du nœud
// focalisé (le bouton), et visent le contrôleur du texte.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fait défiler [c] de 60 % de sa hauteur visible, vers le bas ([down]) ou le
/// haut. Sans effet tant que la vue n'est pas montée ou n'a rien à défiler.
void remoteScrollBy(ScrollController c, {required bool down}) {
  if (!c.hasClients) return;
  final pos = c.position;
  final step = pos.viewportDimension * 0.6 * (down ? 1 : -1);
  final target = (pos.pixels + step).clamp(pos.minScrollExtent, pos.maxScrollExtent);
  if (target == pos.pixels) return;
  c.animateTo(target,
      duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
}

/// Les raccourcis ↑ / ↓ / Page préc. / Page suiv. qui font défiler [c].
Map<ShortcutActivator, VoidCallback> remoteScrollBindings(
        ScrollController Function() c) =>
    {
      const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
          remoteScrollBy(c(), down: true),
      const SingleActivator(LogicalKeyboardKey.pageDown): () =>
          remoteScrollBy(c(), down: true),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
          remoteScrollBy(c(), down: false),
      const SingleActivator(LogicalKeyboardKey.pageUp): () =>
          remoteScrollBy(c(), down: false),
    };
