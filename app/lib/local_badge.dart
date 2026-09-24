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

/// Pose la pastille « local » sur une VIGNETTE de liste.
///
/// Les dispositions en GRILLE la posaient déjà (accueil, albums, « Ajoutés
/// récemment »), les listes non — un même morceau était donc marqué en grille
/// et nu en liste, à un bouton d'écart. Elle vit ici pour que les deux
/// dispositions ne divergent plus.
///
/// ⚠️ Réduite: une vignette de liste fait 40 px, où la pastille des cartes
/// (icône 14 + 3 px de marge, soit ~20 px) couvrirait un quart de l'image.
class LocalBadgedArtwork extends StatelessWidget {
  final Widget child;
  final bool   show;
  final double size;

  const LocalBadgedArtwork({
    super.key,
    required this.child,
    required this.show,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (!show) return SizedBox(width: size, height: size, child: child);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(children: [
        Positioned.fill(child: child),
        const Positioned(bottom: 0, left: 0, child: LocalBadge(size: 9)),
      ]),
    );
  }
}
