// Tri et disposition des navigateurs de FICHIERS locaux — imports,
// téléchargements (local_library_screen.dart) et dossiers liés
// (linked_root_screen.dart) — comme un Finder ou un explorateur: par nom ou par
// date de modification, croissant ou décroissant, en liste ou en icônes.
//
// Un seul réglage pour les deux écrans (UserSettings `local.*`): c'est le même
// geste — parcourir des dossiers — et l'utilisateur ne doit pas le régler deux
// fois. Les DOSSIERS restent devant les fichiers (règle des explorateurs de
// fichiers classiques), triés entre eux par la même clé.
import 'dart:io';

import 'package:flutter/material.dart';

import 'hover_grow.dart';
import 'l10n.dart';
import 'library_toolbar.dart' show LibrarySort, LibrarySortLabel;
import 'user_settings.dart';
import 'view_mode_picker.dart';

/// Les deux clés de tri d'un navigateur de fichiers.
const kLocalBrowseSorts = [LibrarySort.name, LibrarySort.modified];

/// Le réglage commun: clé, sens, disposition.
class LocalBrowseOrder {
  final LibrarySort sort;
  final bool ascending;
  final String view;
  const LocalBrowseOrder(this.sort, this.ascending, this.view);

  static LocalBrowseOrder read() {
    final s = UserSettings.instance;
    return LocalBrowseOrder(
      LibrarySortLabel.fromPref(s.librarySort('local'), LibrarySort.name),
      s.librarySortAsc('local'),
      s.localBrowserViewMode,
    );
  }

  bool get byDate => sort == LibrarySort.modified;
  bool get isGrid => view != ViewModePicker.list;
}

/// Trie [items] par nom (sans casse, chiffres dans l'ordre NATUREL: « 2 »
/// avant « 10 », comme le Finder) ou par date de modification. Une date
/// INCONNUE (`null`) va toujours en FIN, quel que soit le sens — elle n'est ni
/// ancienne ni récente. À clé égale, le nom départage, toujours croissant.
List<T> sortLocalEntries<T>(
  Iterable<T> items, {
  required String Function(T) name,
  int? Function(T)? mtime,
  required LibrarySort sort,
  required bool ascending,
}) {
  final out = [...items];
  int byName(T a, T b) => compareNatural(name(a), name(b));
  out.sort((a, b) {
    if (sort == LibrarySort.modified && mtime != null) {
      final ma = mtime(a), mb = mtime(b);
      if (ma == null || mb == null) {
        if (ma != mb) return ma == null ? 1 : -1;
      } else if (ma != mb) {
        return ascending ? ma.compareTo(mb) : mb.compareTo(ma);
      }
      return byName(a, b);
    }
    final r = byName(a, b);
    return ascending ? r : -r;
  });
  return out;
}

/// Comparaison « naturelle », sans casse: les suites de chiffres se comparent
/// par leur VALEUR (`track 2` < `track 10`).
int compareNatural(String a, String b) {
  final x = a.toLowerCase(), y = b.toLowerCase();
  var i = 0, j = 0;
  bool dig(int c) => c >= 48 && c <= 57;
  while (i < x.length && j < y.length) {
    final cx = x.codeUnitAt(i), cy = y.codeUnitAt(j);
    if (dig(cx) && dig(cy)) {
      final si = i, sj = j;
      while (i < x.length && dig(x.codeUnitAt(i))) {
        i++;
      }
      while (j < y.length && dig(y.codeUnitAt(j))) {
        j++;
      }
      final nx = BigInt.parse(x.substring(si, i)),
          ny = BigInt.parse(y.substring(sj, j));
      final r = nx.compareTo(ny);
      if (r != 0) return r;
      continue;
    }
    if (cx != cy) return cx.compareTo(cy);
    i++;
    j++;
  }
  final r = (x.length - i).compareTo(y.length - j);
  return r != 0 ? r : a.compareTo(b);
}

/// Date de modification d'un chemin du disque, en ms; null si illisible.
Future<int?> localMtimeMs(String path) async {
  try {
    final st = await FileStat.stat(path);
    if (st.type == FileSystemEntityType.notFound) return null;
    return st.modified.millisecondsSinceEpoch;
  } catch (_) {
    return null;
  }
}

/// « Trier » (nom / date de modification + sens) et « Disposition »
/// (liste / icônes / petites icônes), pour la barre d'un navigateur local.
class LocalBrowseActions extends StatelessWidget {
  final LocalBrowseOrder order;
  final ValueChanged<LocalBrowseOrder> onChanged;

  const LocalBrowseActions(
      {super.key, required this.order, required this.onChanged});

  void _set(LocalBrowseOrder o) {
    final s = UserSettings.instance;
    s.setLibrarySort('local', o.sort.pref, o.ascending);
    s.localBrowserViewMode = o.view;
    onChanged(o);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      PopupMenuButton<String>(
        icon: const Icon(Icons.sort),
        tooltip: l10n.commonSort,
        onSelected: (v) => _set(v == 'asc' || v == 'desc'
            ? LocalBrowseOrder(order.sort, v == 'asc', order.view)
            : LocalBrowseOrder(LibrarySortLabel.fromPref(v, order.sort),
                order.ascending, order.view)),
        itemBuilder: (_) => [
          for (final s in kLocalBrowseSorts)
            CheckedPopupMenuItem(
                value: s.pref, checked: s == order.sort, child: Text(s.label(l10n))),
          const PopupMenuDivider(),
          CheckedPopupMenuItem(
              value: 'asc',
              checked: order.ascending,
              child: Text(l10n.searchSortAsc)),
          CheckedPopupMenuItem(
              value: 'desc',
              checked: !order.ascending,
              child: Text(l10n.searchSortDesc)),
        ],
      ),
      ViewModePicker(
        mode: order.view,
        onChanged: (v) => _set(LocalBrowseOrder(order.sort, order.ascending, v)),
      ),
    ]);
  }
}

/// La grille des icônes: tuiles carrées + nom sur deux lignes.
SliverGridDelegate localGridDelegate(String view) =>
    SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: view == ViewModePicker.gridSmall ? 96 : 132,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.72,
    );

/// Une tuile de la vue « icônes »: image (ou icône) carrée, nom en dessous.
/// En sélection, une case à cocher en surimpression et le tap coche.
class LocalGridTile extends StatelessWidget {
  final Widget art;
  final String title;
  final String? subtitle;
  final bool selecting;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double opacity;

  const LocalGridTile({
    super.key,
    required this.art,
    required this.title,
    this.subtitle,
    this.selecting = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return HoverGrow(
      onTap: onTap,
      onLongPress: onLongPress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Opacity(
          opacity: opacity,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(fit: StackFit.expand, children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: selected
                        ? Border.all(color: cs.primary, width: 2.5)
                        : null,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(selected ? 2.5 : 0),
                    child: art,
                  ),
                ),
                if (selecting)
                  PositionedDirectional(
                    top: 2,
                    start: 2,
                    child: Icon(
                      selected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: selected ? cs.primary : Colors.white,
                      shadows: const [Shadow(blurRadius: 4)],
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 4),
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: tt.bodySmall),
            if (subtitle != null)
              Text(subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

/// L'image carrée d'un DOSSIER en vue icônes: sa pochette quand il en a une
/// (glyphe de dossier en badge), sinon un grand glyphe de dossier.
class LocalFolderArt extends StatelessWidget {
  final String? art;
  const LocalFolderArt({super.key, this.art});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final glyph = LayoutBuilder(
      builder: (_, c) => Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.folder, size: c.maxWidth * 0.55, color: cs.primary),
      ),
    );
    final a = art;
    if (a == null) return glyph;
    final image = a.startsWith('http')
        ? Image.network(a, fit: BoxFit.cover, errorBuilder: (_, __, ___) => glyph)
        : Image.file(File(a),
            fit: BoxFit.cover,
            cacheWidth: 300,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => glyph);
    return Stack(fit: StackFit.expand, children: [
      ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
      PositionedDirectional(
        end: 4,
        bottom: 4,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6)),
          child: Icon(Icons.folder, size: 16, color: cs.primary),
        ),
      ),
    ]);
  }
}
