import 'package:flutter/material.dart';

import 'app_snack.dart';
import 'favorite_color.dart';
import 'local_badge.dart';
import 'artwork_image.dart';
import 'local_db.dart';
import 'l10n.dart';
import 'library_presence.dart';
import 'hover_grow.dart';
import 'scrolling_text.dart';
import 'library_toolbar.dart';
import 'shell_insets.dart';
import 'sync_service.dart';
import 'user_settings.dart';
import 'view_mode_picker.dart';

typedef OnNavigateAlbum = void Function(
  String albumName, {
  String? collection,
  String? platform,
  String? artworkUrl,
  String? albumId,
});

class LibraryAlbumsScreen extends StatefulWidget {
  final OnNavigateAlbum? onNavigateAlbum;

  const LibraryAlbumsScreen({super.key, this.onNavigateAlbum});

  @override
  State<LibraryAlbumsScreen> createState() => _LibraryAlbumsScreenState();
}

class _LibraryAlbumsScreenState extends State<LibraryAlbumsScreen> {
  List<LibraryItem> _items = [];
  /// Albums locaux dont aucun fichier n'est ICI — voir library_presence.
  Set<String> _missing = const {};
  bool _elsewhere(LibraryItem it) => _missing.contains(it.refId);
  bool _loading = true;
  String _query = '';
  LibrarySort _sort = LibrarySortLabel.fromPref(
      UserSettings.instance.librarySort('album'), LibrarySort.added);
  bool _asc = UserSettings.instance.librarySortAsc('album');
  String _view = UserSettings.instance.libraryViewMode;

  @override
  void initState() {
    super.initState();
    LocalDb.instance.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    LocalDb.instance.getLibraryItems(type: 'album').then((items) async {
      final missing = await missingLocalLibraryRefs(items);
      if (!mounted) return;
      setState(() { _items = items; _missing = missing; _loading = false; });
    });
  }

  List<LibraryItem> get _visible =>
      sortLibraryItems(filterLibraryItems(_items, _query), _sort, _asc);

  void _open(LibraryItem item) {
    if (_elsewhere(item)) {
      AppSnack.show(context, libraryElsewhereLabel(context));
      return;
    }
    _navigate(item);
  }

  void _navigate(LibraryItem item) => widget.onNavigateAlbum?.call(
        item.name,
        collection: item.collectionSlug,
        platform:   item.platformName,
        artworkUrl: item.artworkUrl,
        albumId:    item.albumId,
      );

  /// Retrait: local ET compte (l'album a une identité serveur — sans l'envoi,
  /// le rattrapage le remettrait à la synchro suivante).
  Future<void> _remove(LibraryItem item) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await LocalDb.instance.removeFromLibrary('album', item.refId);
    final id = item.albumId;
    if (id != null && id.isNotEmpty) {
      await SyncService.recordLibraryChange(
          itemType: 'album', itemId: id, value: false);
    }
    // Message NEUTRE: `playerRemovedFromLibrary` dit « Morceau retiré… », ce
    // qui était faux sur un artiste et sur un album.
    AppSnack.showOn(messenger, l10n.libraryRemoved,
        duration: const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    final l10n  = context.l10n;
    final cs    = Theme.of(context).colorScheme;
    final items = _visible;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.libraryAlbums)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              LibraryToolbar(
                query:   _query,
                onQuery: (v) => setState(() => _query = v),
                hintText: l10n.searchFilterPlaceholder,
                sorts: const [
                  LibrarySort.name,
                  LibrarySort.artist,
                  LibrarySort.added,
                ],
                sort: _sort,
                ascending: _asc,
                onSort: (s, asc) => setState(() {
                  _sort = s;
                  _asc  = asc;
                  UserSettings.instance.setLibrarySort('album', s.pref, asc);
                }),
                viewMode: _view,
                onViewMode: (v) => setState(() {
                  _view = v;
                  UserSettings.instance.libraryViewMode = v;
                }),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text(
                        _items.isEmpty ? l10n.libraryEmpty : l10n.searchNoResults,
                        style: TextStyle(color: cs.outline)))
                    : _view == ViewModePicker.list
                        ? _buildList(items, cs)
                        : _buildGrid(items, cs),
              ),
            ]),
    );
  }

  Widget _buildList(List<LibraryItem> items, ColorScheme cs) {
    return ListView.builder(
      padding: shellInset(context, EdgeInsets.zero),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return Dismissible(
          key: ValueKey(item.refId),
          direction: DismissDirection.endToStart,
          // Le balayage PROPOSE, il ne décide pas: sans ce garde-fou, un geste
          // de trop retirait l'entrée sans retour possible.
          confirmDismiss: (_) => confirmLibraryRemoval(context, item.name),
          background: Container(
            color: cs.errorContainer,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
          ),
          onDismissed: (_) => _remove(item),
          child: ListTile(
            leading: LocalBadgedArtwork(
              show: item.isLocal,
              child: RailArtwork(
                url:          item.artworkUrl,
                artist:       item.artist,
                album:        item.name,
                formatHint:   item.formatExt ?? item.filename,
                platformName: item.platformName,
                size:         40,
              ),
            ),
            enabled: !_elsewhere(item),
            title: ScrollingText(text: item.name),
            subtitle: _elsewhere(item)
                ? Text(libraryElsewhereLabel(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurfaceVariant))
                : (item.artist == null || item.artist!.isEmpty)
                    ? null
                    : Text(item.artist!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurfaceVariant)),
            trailing: item.isFavorite
                ? const Icon(Icons.star_rounded, size: 20, color: kFavoriteColor)
                : null,
            onTap: () => _open(item),
            onLongPress: () => showLibraryItemMenu(context,
                title: item.name, onRemove: () => _remove(item)),
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<LibraryItem> items, ColorScheme cs) {
    final small = _view == ViewModePicker.gridSmall;
    return GridView.builder(
      padding: shellInset(context, const EdgeInsets.all(12)),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: small ? 100 : 130,
        mainAxisSpacing:    10,
        crossAxisSpacing:   10,
        // Pochette CARRÉE + deux lignes de texte, comme les rails de l'accueil
        // et comme « Ajouts récents ».
        childAspectRatio:   0.70,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _AlbumCard(
        item: items[i], cs: cs,
        elsewhere: _elsewhere(items[i]),
        onTap: () => _open(items[i]),
        onRemove: () => _remove(items[i]),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final LibraryItem       item;
  final ColorScheme       cs;
  final VoidCallback?     onTap;
  final VoidCallback?     onRemove;
  /// Sur un autre appareil (library_presence): grisée, la deuxième ligne le dit.
  final bool              elsewhere;

  const _AlbumCard(
      {required this.item, required this.cs, this.onTap, this.onRemove,
      this.elsewhere = false});

  @override
  Widget build(BuildContext context) {
    return HoverGrow(child: GestureDetector(
      onTap: onTap,
      onLongPress: onRemove == null
          ? null
          : () => showLibraryItemMenu(context,
              title: item.name, onRemove: onRemove!),
      child: Opacity(
        opacity: elsewhere ? 0.45 : 1.0,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // EXACTEMENT la pochette des rails de l'accueil (voir RailArtwork).
          // Cette grille avait son propre traitement — fond flouté de la
          // pochette + `BoxFit.contain` par-dessus — joli mais unique dans
          // l'app: trois écrans montraient la même pochette de trois façons.
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                RailArtwork(
                  url:          item.artworkUrl,
                  artist:       item.artist,
                  album:        item.name,
                  formatHint:   item.formatExt ?? item.filename,
                  platformName: item.platformName,
                ),
                if (item.isFavorite)
                  const Positioned(
                    top:   2,
                    right: 2,
                    child: Icon(
                      Icons.star_rounded,
                      size: 20,
                      color: kFavoriteColor,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                    ),
                  ),
                if (item.isLocal)
                  const Positioned(
                    bottom: 4,
                    left:   4,
                    child: LocalBadge(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Flexible: la pochette impose sa hauteur (carrée), donc c'est le
          // texte qui cède sur une tuile étroite plutôt que la colonne qui
          // déborde.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ScrollingText(
                  text: item.name,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (elsewhere)
                  ScrollingText(
                    text: libraryElsewhereLabel(context),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant),
                  )
                else if (item.artist != null)
                  ScrollingText(
                    text: item.artist!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
    ));
  }
}
