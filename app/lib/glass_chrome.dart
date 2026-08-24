import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'user_settings.dart';

/// EXPÉRIMENTATION — branche `feat/liquid-glass-chrome`.
///
/// Une seule et même surface « verre » pour les deux éléments de chrome du bas
/// (mini-lecteur + barre de navigation). Tout le paquet est confiné ici et dans
/// les deux points d'appel: supprimer ce fichier et les deux appels suffit à
/// revenir en arrière.
///
/// ## Pourquoi `liquid_glass_easy` et plus `liquid_glass_widgets`
///
/// Le premier kit n'expose la vraie lentille — la déformation du contenu le
/// long du bord — que sur son chemin « Premium », **Impeller uniquement**; son
/// chemin « Standard » n'en est qu'une approximation plate, ce qui faisait
/// qu'y changer `thickness` ou `refractiveIndex` ne se voyait pas. Or
/// **Android tourne sous Skia chez nous** (Impeller y est désactivé à cause du
/// strobe du visualiseur SurfaceView): cette moitié du parc n'aurait jamais eu
/// l'effet.
///
/// Celui-ci fait la réfraction de bord sur les DEUX moteurs, au prix d'une
/// différence de câblage qu'il faut connaître:
///  - sur **Impeller** (macOS/iOS ici), une `LiquidGlassLens` posée n'importe
///    où réfracte le fond VIVANT — rien d'autre à faire;
///  - sur **Skia** (Android), elle réfracte le fond CAPTURÉ par un
///    `LiquidGlassView` englobant. Sans ce parent elle retombe sur du verre
///    dépoli: visible, mais sans lentille. Ce parent n'est pas encore posé — il
///    demande de faire passer tout l'arbre de l'app en `backgroundWidget`, et
///    son coût de capture est justement ce qu'il faudra mesurer.
///
/// L'autre limite, inchangée et structurelle: un fond, capturé ou vivant, ne
/// voit pas une PlatformView. Le visualiseur Android (SurfaceView) et la vidéo
/// ne seront donc pas réfractés — d'où la teinte ci-dessous, qui tient la
/// lisibilité même quand il n'y a rien à réfracter.
class GlassChrome extends StatelessWidget {
  final Widget child;

  /// Rayon des coins: le mini-lecteur flotte (quatre coins arrondis), la barre
  /// de navigation reste plaquée en bas.
  final BorderRadius borderRadius;

  const GlassChrome({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(18)),
  });

  /// Le verre d'Apple ne floute quasiment pas: on lit encore le texte qui passe
  /// dessous, il est seulement délavé et déformé au bord. D'où un sigma très
  /// bas — c'est la lentille qui doit travailler, pas le dépoli.
  static const _kBlurSigma = 1.25;
  static const _kDistortion = 0.20;

  /// Largeur en pixels de la bande déformée le long du bord. C'est ce réglage
  /// qui décide si l'effet « se voit », plus que son intensité.
  static const _kDistortionWidth = 30.0;

  /// Voile de lisibilité, FIXE et décidé par le seul thème: clair sous thème
  /// clair, sombre sous thème sombre. Un voile qui suivait le contenu (dosé par
  /// échantillonnage du fond) a été essayé puis retiré — le chrome changeait
  /// d'épaisseur pendant qu'on faisait défiler, ce qui attire l'œil sur
  /// lui-même, et rien ne bouge ainsi dans Apple Music.
  static Color _veil(Brightness b) => b == Brightness.light
      ? Colors.white.withValues(alpha: 0.6)
      : Colors.black.withValues(alpha: 0.6);

  @override
  Widget build(BuildContext context) {
    // À l'écoute des Réglages: le basculement de l'option doit re-rendre le
    // chrome immédiatement, sans dépendre d'un rebuild ancêtre.
    return ListenableBuilder(
      listenable: UserSettings.instance,
      builder: (context, _) => _slab(context),
    );
  }

  Widget _slab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    // Réglages → effet coupé (devices trop lents pour le shader): dalle
    // translucide plate, même voile et même liseré — la géométrie et la
    // lisibilité ne changent pas, seule la lentille/le flou disparaissent.
    if (!UserSettings.instance.glassEffect) {
      return DecoratedBox(
        decoration: BoxDecoration(
          // Un peu plus opaque que le voile du verre: sans le délavage de la
          // lentille, 0.5 laissait le contenu se battre avec les icônes.
          color: (brightness == Brightness.light
              ? Colors.white.withValues(alpha: 0.78)
              : Colors.black.withValues(alpha: 0.78)),
          borderRadius: borderRadius,
          border: Border.all(
              color: cs.onSurface.withValues(alpha: 0.18), width: 1.0),
        ),
        child: child,
      );
    }
    return LiquidGlassLens(
      style: LiquidGlassStyle(
        shape: LiquidGlassShape(
          cornerStyle: LiquidGlassCornerStyle.continuousRoundedRectangle,
          cornerRadius: borderRadius.topLeft.x,
          // Le liseré donne au bord son épaisseur de vraie dalle.
          borderWidth: 1.0,
          borderColor: cs.onSurface.withValues(alpha: 0.18),
          lightIntensity: 0.55,
        ),
        appearance: LiquidGlassAppearance(
          saturation: 1.1,
          blur: const LiquidGlassBlur(sigmaX: _kBlurSigma, sigmaY: _kBlurSigma),
          color: _veil(brightness),
        ),
        refraction: const LiquidGlassRefraction(
          distortion: _kDistortion,
          distortionWidth: _kDistortionWidth,
          magnification: 1.0,
          chromaticAberration: 0.0,
        ),
      ),
      child: child,
    );
  }
}
