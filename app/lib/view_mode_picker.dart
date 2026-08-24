import 'package:flutter/material.dart';

import 'l10n.dart';

/// Le sélecteur liste / grille / grille compacte, partagé par TOUS les écrans
/// qui présentent une collection — les écrans de navigation par facettes comme
/// ceux de la bibliothèque.
///
/// Il vivait en privé dans `browse_screen.dart`; le sortir est ce qui permet
/// aux écrans de bibliothèque d'offrir la même navigation sans recopier trois
/// icônes et trois libellés qui auraient dérivé.
class ViewModePicker extends StatelessWidget {
  final String mode;
  final ValueChanged<String> onChanged;

  const ViewModePicker({super.key, required this.mode, required this.onChanged});

  /// Les trois valeurs admises, telles qu'elles sont persistées.
  static const list      = 'list';
  static const grid      = 'grid';
  static const gridSmall = 'grid_small';

  static const _icons = {
    list:      Icons.view_list,
    grid:      Icons.grid_view,
    gridSmall: Icons.apps,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      icon: Icon(_icons[mode] ?? Icons.view_list),
      tooltip: l10n.browseViewMode,
      onSelected: onChanged,
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
            value: list,
            checked: mode == list,
            child: Text(l10n.browseViewList)),
        CheckedPopupMenuItem(
            value: grid,
            checked: mode == grid,
            child: Text(l10n.browseViewGrid)),
        CheckedPopupMenuItem(
            value: gridSmall,
            checked: mode == gridSmall,
            child: Text(l10n.browseViewGridCompact)),
      ],
    );
  }
}
