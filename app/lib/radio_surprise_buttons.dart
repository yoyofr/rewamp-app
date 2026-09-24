import 'package:flutter/material.dart';

import 'l10n.dart';

/// The « Radio » / « Surprise » pair, identical on every screen that offers it.
///
/// Three things it standardises, all of them things that went wrong when each
/// screen rolled its own:
///  - **one shape everywhere** — they used to be labelled `ActionChip`s on the
///    search screen and bare `IconButton`s on the artist screen, so the same
///    two actions looked like two different features;
///  - **icon only** — the labels are the widest thing on a filter row, and on a
///    narrow panel they pushed the facet pickers out of reach. The words live
///    in the tooltip (with the explanatory line under them), not on screen;
///  - **a real gap between them** — these two do very different things (an
///    endless station vs jumping to one random tune), and side by side at chip
///    density they were a mis-tap away from each other. [_kGap] keeps them
///    apart, and each keeps a 40 px touch target.
class RadioSurpriseButtons extends StatelessWidget {
  /// « Tout lire », optionnel, TOUJOURS devant Radio quand il est là — même
  /// forme, même écart: trois actions de lancement qui se lisent comme une
  /// seule famille (demandé le 2026-09-02: le bouton divergeait d'un écran à
  /// l'autre).
  final VoidCallback? onPlayAll;
  final VoidCallback? onRadio;
  final VoidCallback? onSurprise;
  /// Tone down to plain icons (no filled background) where the row already
  /// carries emphasis of its own.
  final bool tonal;
  /// Barre étroite (barre de comptage, AppBar): mêmes couleurs et MÊME fond
  /// tonal, seulement plus petits. ⚠️ Ne jamais dégrader le style à la place —
  /// un bloc sans fond à côté d'un bloc tonal ne se lit plus comme la même
  /// famille de trois actions (retour utilisateur du 2026-09-02).
  final bool dense;

  const RadioSurpriseButtons({
    super.key,
    this.onPlayAll,
    this.onRadio,
    this.onSurprise,
    this.tonal = true,
    this.dense = false,
  });

  static const double _kGap      = 18;
  static const double _kIcon     = 21;
  static const double _kTouch    = 40;
  static const double _kGapDense   = 10;
  static const double _kIconDense  = 18;
  static const double _kTouchDense = 32;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gap   = dense ? _kGapDense   : _kGap;
    final icon  = dense ? _kIconDense  : _kIcon;
    final touch = dense ? _kTouchDense : _kTouch;

    Widget button(IconData ic, String label, String hint, VoidCallback? tap) {
      final child = Icon(ic, size: icon);
      final style = ButtonStyle(
        minimumSize: WidgetStateProperty.all(Size(touch, touch)),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
      // Tooltip = the label AND the explanation: dropping the visible text is
      // only acceptable if the words stay one hover / long-press away.
      return Tooltip(
        message: '$label — $hint',
        child: tonal
            ? IconButton.filledTonal(icon: child, style: style, onPressed: tap)
            : IconButton(icon: child, style: style, onPressed: tap),
      );
    }

    Widget bare(IconData ic, String label, VoidCallback? tap) {
      final child = Icon(ic, size: icon);
      final style = ButtonStyle(
        minimumSize: WidgetStateProperty.all(Size(touch, touch)),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
      return Tooltip(
        message: label,
        child: tonal
            ? IconButton.filledTonal(icon: child, style: style, onPressed: tap)
            : IconButton(icon: child, style: style, onPressed: tap),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onPlayAll != null) ...[
          // Pas de sous-titre dans l'infobulle: « Tout lire » se suffit, et
          // une clé ARB de plus par langue n'apprendrait rien.
          bare(Icons.play_arrow, l10n.browsePlayAll, onPlayAll),
          SizedBox(width: gap),
        ],
        button(Icons.radio, l10n.searchRadio, l10n.searchRadioTooltip, onRadio),
        SizedBox(width: gap),
        button(Icons.casino_outlined, l10n.searchSurprise,
            l10n.searchSurpriseTooltip, onSurprise),
      ],
    );
  }
}
