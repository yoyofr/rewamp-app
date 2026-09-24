// Pochette en PLEIN ÉCRAN, ouverte au tap depuis un écran de détail.
//
// Deux choix qui tiennent la fonction:
//
//  * on affiche le `ImageProvider` DÉJÀ RÉSOLU par la vignette, pas une url
//    qu'on re-résoudrait. La vignette a fait tout le travail (sidecar local à
//    côté du module, cache disque, repli réseau) et un second chemin de
//    résolution finirait par diverger du premier — on montrerait autre chose
//    que ce que l'utilisateur a touché.
//  * l'appelant n'ouvre QUE sur une vraie pochette. `ArtworkImage` signale ce
//    qu'il a résolu, et la clé d'un repli commence par `placeholder:` — agrandir
//    la marque générique par plateforme n'apprendrait rien à personne.
//
// Le tap ferme, sur l'image comme à côté: une seule règle, pas une zone de
// fermeture à trouver.

import 'package:flutter/material.dart';

/// Vrai quand [key], telle que `ArtworkImage.onImageResolved` la publie, décrit
/// une VRAIE pochette et non le placeholder thématisé par plateforme.
bool artworkKeyIsRealCover(String key) => !key.startsWith('placeholder:');

Future<void> showFullscreenArtwork(BuildContext context, ImageProvider image,
    {String? title}) {
  return showGeneralDialog<void>(
    context: context,
    // Le fond est déjà très sombre: la barrière ne sert qu'à fermer.
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, __) => _FullscreenArtwork(image: image, title: title),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
  );
}

class _FullscreenArtwork extends StatelessWidget {
  final ImageProvider image;
  final String? title;

  const _FullscreenArtwork({required this.image, this.title});

  @override
  Widget build(BuildContext context) {
    // `Material` transparent OBLIGATOIRE: `showGeneralDialog` ne pose aucun
    // ancêtre Material, et un `Text` sans lui hérite de
    // `DefaultTextStyle.fallback()` — dont le DOUBLE SOULIGNEMENT JAUNE est un
    // signal de debug de Flutter, pas un style. Fixer `decoration: none` sur le
    // style le masquerait sans traiter la cause: il manque un contexte de
    // style, et c'est lui qu'on fournit.
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        // `opaque`: le tap ferme PARTOUT, y compris sur l'image — sans ça seul le
        // pourtour (la barrière) aurait réagi, et refermer demanderait de viser.
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                // `contain`: le rapport d'aspect est respecté quel que soit
                // l'écran — une pochette n'est pas toujours carrée (jaquettes,
                // scans de disquette, bannières de démo).
                child: Image(image: image, fit: BoxFit.contain),
              ),
            ),
            if (title != null && title!.isNotEmpty)
              Positioned(
                left: 16, right: 16, bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      title!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13, height: 1.3),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
