import 'package:flutter/material.dart';

import 'l10n.dart';
import 'local_db.dart';
import 'view_mode_picker.dart';

/// Sur quoi trier une liste de bibliothèque. Chaque écran n'en propose que ce
/// qui a un sens chez lui (un artiste n'a pas d'album).
enum LibrarySort { name, artist, album, added }

extension LibrarySortLabel on LibrarySort {
  String label(AppLocalizations l10n, {bool asTitle = false}) => switch (this) {
        // « Nom » pour un artiste ou un album, « Titre » pour un morceau: c'est
        // le même champ, pas le même mot.
        LibrarySort.name   => asTitle ? l10n.sortTitle : l10n.sortName,
        LibrarySort.artist => l10n.sortArtist,
        LibrarySort.album  => l10n.sortAlbum,
        LibrarySort.added  => l10n.sortDateAdded,
      };

  /// Valeur persistée (les noms d'enum ne doivent pas fuir dans les préfs:
  /// renommer un cas casserait le réglage de l'utilisateur).
  String get pref => switch (this) {
        LibrarySort.name   => 'name',
        LibrarySort.artist => 'artist',
        LibrarySort.album  => 'album',
        LibrarySort.added  => 'added',
      };

  static LibrarySort fromPref(String? v, LibrarySort fallback) =>
      LibrarySort.values.firstWhere((s) => s.pref == v, orElse: () => fallback);
}

/// Ne garde que les entrées qui matchent [query] — nom, artiste, album et
/// titre de la piste, sans accent ni casse.
///
/// Le titre de la PISTE compte: le `name` d'une entrée est le nom du fichier au
/// moment du geste, donc celui de l'album dès qu'il s'agit d'un conteneur.
/// Filtrer sur le seul `name` ne trouvait pas « Sorrowful » dans un album
/// nommé « Wild Arms ».
List<LibraryItem> filterLibraryItems(List<LibraryItem> items, String query) {
  final q = _fold(query);
  if (q.isEmpty) return items;
  return [
    for (final i in items)
      if (_fold(i.name).contains(q) ||
          _fold(i.trackTitle ?? '').contains(q) ||
          _fold(i.artist ?? '').contains(q) ||
          _fold(i.album ?? '').contains(q))
        i,
  ];
}

/// Tri STABLE et sans accent, avec un repli sur le nom pour que deux entrées
/// du même artiste (ou ajoutées la même seconde) gardent un ordre lisible.
List<LibraryItem> sortLibraryItems(
    List<LibraryItem> items, LibrarySort by, bool ascending) {
  final out = [...items];
  int cmp(LibraryItem a, LibraryItem b) {
    final r = switch (by) {
      LibrarySort.name   => _fold(a.name).compareTo(_fold(b.name)),
      LibrarySort.artist =>
        _fold(a.artist ?? '').compareTo(_fold(b.artist ?? '')),
      LibrarySort.album  => _fold(a.album ?? '').compareTo(_fold(b.album ?? '')),
      LibrarySort.added  => a.addedAt.compareTo(b.addedAt),
    };
    if (r != 0) return r;
    return _fold(a.name).compareTo(_fold(b.name));
  }

  out.sort((a, b) => ascending ? cmp(a, b) : -cmp(a, b));
  return out;
}

/// Minuscules sans accents ni signes: « Björk » se trouve en tapant « bjork »,
/// et « Doom II » en tapant « doom 2 » n'est PAS l'objectif — on ne translittère
/// que les diacritiques latins, rien d'autre.
String _fold(String s) {
  const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ';
  const to   = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final i = from.indexOf(c);
    b.write(i < 0 ? c : to[i]);
  }
  return b.toString();
}

/// Demande confirmation avant un retrait. Le geste est à un doigt d'écart
/// (balayage) et ne se défait pas: ce qui se retire vite doit se confirmer.
Future<bool> confirmLibraryRemoval(BuildContext context, String name) async {
  final l10n = context.l10n;
  final cs   = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.trackOptionsRemoveFromLibrary),
      content: Text(name),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: cs.error),
          child: Text(l10n.commonDelete),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Feuille commune aux deux dispositions: le retrait doit être atteignable
/// aussi bien depuis une grille (pas de balayage) que depuis une liste.
Future<void> showLibraryItemMenu(
  BuildContext context, {
  required String title,
  required VoidCallback onRemove,
}) async {
  final l10n = context.l10n;
  final removed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          dense: true,
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: Text(l10n.trackOptionsRemoveFromLibrary),
          onTap: () => Navigator.pop(ctx, true),
        ),
      ]),
    ),
  );
  // La confirmation est demandée APRÈS la fermeture de la feuille: un dialogue
  // ouvert par-dessus une feuille modale se ferme avec elle sur certains
  // parcours, et le contexte de la feuille est alors mort.
  if (removed != true || !context.mounted) return;
  if (await confirmLibraryRemoval(context, title)) onRemove();
}

/// La barre d'outils commune aux écrans de bibliothèque: filtre texte, tri
/// (champ ET sens) et, quand l'écran sait le faire, choix de la disposition.
///
/// Un seul endroit pour les trois affordances: c'est ce qui garantit qu'elles
/// se ressemblent d'un écran à l'autre, ce qu'aligner trois écrans à la main
/// n'a jamais tenu bien longtemps.
class LibraryToolbar extends StatelessWidget {
  final String query;
  final ValueChanged<String> onQuery;
  final String hintText;

  final List<LibrarySort> sorts;
  final LibrarySort sort;
  final bool ascending;
  final void Function(LibrarySort sort, bool ascending) onSort;

  /// Libellé du champ « nom » en « Titre » (écran Morceaux).
  final bool titleWording;

  /// null = cet écran n'a qu'une disposition.
  final String? viewMode;
  final ValueChanged<String>? onViewMode;

  const LibraryToolbar({
    super.key,
    required this.query,
    required this.onQuery,
    required this.hintText,
    required this.sorts,
    required this.sort,
    required this.ascending,
    required this.onSort,
    this.titleWording = false,
    this.viewMode,
    this.onViewMode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              // Un `controller` recréé à chaque build replacerait le curseur au
              // début à la frappe: l'état vit chez l'appelant, la valeur
              // initiale suffit ici.
              controller: TextEditingController(text: query)
                ..selection = TextSelection.collapsed(offset: query.length),
              onChanged: onQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: hintText,
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 34, minHeight: 34),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: l10n.commonClear,
                        onPressed: () => onQuery(''),
                      ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: Icon(ascending ? Icons.sort : Icons.sort,
              color: cs.onSurfaceVariant),
          tooltip: l10n.commonSort,
          onSelected: (v) {
            if (v == 'asc' || v == 'desc') {
              onSort(sort, v == 'asc');
            } else {
              onSort(LibrarySortLabel.fromPref(v, sort), ascending);
            }
          },
          itemBuilder: (_) => [
            for (final s in sorts)
              CheckedPopupMenuItem(
                value: s.pref,
                checked: s == sort,
                child: Text(s.label(l10n, asTitle: titleWording && s == LibrarySort.name)),
              ),
            const PopupMenuDivider(),
            // Le SENS, que l'écran des playlists ne proposait pas: choisir
            // « Nom » sans pouvoir l'inverser laisse la moitié du tri
            // inaccessible.
            CheckedPopupMenuItem(
                value: 'asc',
                checked: ascending,
                child: Text(l10n.searchSortAsc)),
            CheckedPopupMenuItem(
                value: 'desc',
                checked: !ascending,
                child: Text(l10n.searchSortDesc)),
          ],
        ),
        if (viewMode != null && onViewMode != null)
          ViewModePicker(mode: viewMode!, onChanged: onViewMode!),
      ]),
    );
  }
}
