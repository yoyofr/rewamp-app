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
  final VoidCallback? onRadio;
  final VoidCallback? onSurprise;
  /// Tone down to plain icons (no filled background) where the row already
  /// carries emphasis of its own.
  final bool tonal;

  const RadioSurpriseButtons({
    super.key,
    this.onRadio,
    this.onSurprise,
    this.tonal = true,
  });

  static const double _kGap      = 18;
  static const double _kIcon     = 21;
  static const double _kTouch    = 40;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    Widget button(IconData icon, String label, String hint, VoidCallback? tap) {
      final child = Icon(icon, size: _kIcon);
      final style = ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size(_kTouch, _kTouch)),
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Icons.radio, l10n.searchRadio, l10n.searchRadioTooltip, onRadio),
        const SizedBox(width: _kGap),
        button(Icons.casino_outlined, l10n.searchSurprise,
            l10n.searchSurpriseTooltip, onSurprise),
      ],
    );
  }
}
