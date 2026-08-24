import 'package:flutter/material.dart';

import 'l10n.dart';
import 'rewamp_db.dart' show FacetCount;

/// Feuille de choix d'une valeur de facette (format, plateforme, collection):
/// titre, CHAMP DE RECHERCHE en tête (les plateformes sont 59, une liste
/// seule ne se parcourt pas), « Tous » pour effacer, coche sur la valeur
/// active.
///
/// Vivait en privé dans `search_screen.dart`; sortie ici quand l'écran
/// d'albums a eu besoin des mêmes puces — recopier la feuille aurait fait
/// dériver les deux dispositions, exactement ce que le partage de
/// `ViewModePicker` avait déjà réglé pour le sélecteur de vue.

class FacetPickerSheet extends StatefulWidget {
  final String            label;     // 'Format' | 'Plateforme' | 'Collection'
  final List<FacetCount>  values;
  final String?           selected;  // null = all
  final ValueChanged<String?> onPick; // null = clear the filter

  const FacetPickerSheet({
    super.key,
    required this.label,
    required this.values,
    required this.selected,
    required this.onPick,
  });

  @override
  State<FacetPickerSheet> createState() => _FacetPickerSheetState();
}

class _FacetPickerSheetState extends State<FacetPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final l10n = context.l10n;
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.values
        : widget.values
            .where((f) => f.value.toLowerCase().contains(q))
            .toList();

    return SafeArea(
      child: Padding(
        // Keep the field above the keyboard when the sheet is half-height.
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(widget.label,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: l10n.searchFilterPlaceholder,
                    border: const OutlineInputBorder(),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _query = ''),
                          ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (q.isEmpty)
                      ListTile(
                        dense: true,
                        leading: Icon(
                            widget.selected == null
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 20,
                            color: widget.selected == null ? accent : null),
                        title: Text(l10n.searchAllOf(widget.label)),
                        onTap: () => widget.onPick(null),
                      ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text(l10n.searchNoMatch)),
                      ),
                    for (final f in filtered)
                      ListTile(
                        dense: true,
                        leading: Icon(
                            widget.selected == f.value
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 20,
                            color:
                                widget.selected == f.value ? accent : null),
                        title: Text(f.value,
                            style: TextStyle(
                                fontWeight: widget.selected == f.value
                                    ? FontWeight.w600
                                    : FontWeight.normal)),
                        trailing: Text('${f.count}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        onTap: () => widget.onPick(f.value),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
