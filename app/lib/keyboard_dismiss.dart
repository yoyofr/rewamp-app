import 'package:flutter/material.dart';

/// Ferme le clavier virtuel dès qu'un doigt se pose HORS du champ en cours
/// d'édition. Monté une fois, autour du Navigator (MaterialApp.builder).
///
/// Pourquoi un [Listener] et pas un GestureDetector racine: un détecteur à la
/// racine entre dans l'arène des gestes et n'y gagne que les taps que PERSONNE
/// ne revendique — taper une ligne de résultat, un bouton, un onglet aurait
/// laissé le clavier ouvert, précisément les cas qui comptent. Le Listener est
/// hors arène: il voit chaque pointeur posé, n'en consomme aucun, et n'arbitre
/// rien — même famille que le glissement de fermeture du lecteur.
///
/// Deux gardes, et les deux portent:
///  * `viewInsets.bottom > 0` — le clavier est réellement À L'ÉCRAN. C'est ce
///    qui rend le widget inerte sur desktop (inset toujours nul, et le
///    framework y gère déjà le clic-dehors des TextField) et avec un clavier
///    physique.
///  * le point touché est comparé au rectangle du champ FOCALISÉ — sans quoi
///    taper dans le champ lui-même le défocaliserait un instant avant que le
///    tap ne le refocalise: le clavier clignoterait à chaque repositionnement
///    du curseur. Le bouton d'effacement d'un champ est DANS ce rectangle,
///    donc il garde le focus aussi.
class KeyboardDismissOnTapOutside extends StatelessWidget {
  final Widget child;

  const KeyboardDismissOnTapOutside({super.key, required this.child});

  void _onPointerDown(BuildContext context, PointerDownEvent e) {
    if (MediaQuery.viewInsetsOf(context).bottom <= 0) return;
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return;

    final ctx = focus.context;
    final box = ctx?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final local = box.globalToLocal(e.position);
      if ((Offset.zero & box.size).contains(local)) return; // tap DANS le champ
    }
    focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (e) => _onPointerDown(context, e),
      child: child,
    );
  }
}
