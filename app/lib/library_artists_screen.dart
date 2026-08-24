import 'package:flutter/material.dart';

import 'app_snack.dart';
import 'library_toolbar.dart';
import 'local_db.dart';
import 'l10n.dart';
import 'shell_insets.dart';
import 'user_settings.dart';

typedef OnNavigateArtist = void Function(String artistName,
    {String? collection, String? artistId});

class LibraryArtistsScreen extends StatefulWidget {
  final OnNavigateArtist? onNavigateArtist;

  const LibraryArtistsScreen({super.key, this.onNavigateArtist});

  @override
  State<LibraryArtistsScreen> createState() => _LibraryArtistsScreenState();
}

class _LibraryArtistsScreenState extends State<LibraryArtistsScreen> {
  List<LibraryItem> _items = [];
  bool _loading = true;
  String _query = '';
  LibrarySort _sort = LibrarySortLabel.fromPref(
      UserSettings.instance.librarySort('artist'), LibrarySort.name);
  bool _asc = UserSettings.instance.librarySortAsc('artist');

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
    LocalDb.instance.getLibraryItems(type: 'artist').then((items) {
      if (mounted) setState(() { _items = items; _loading = false; });
    });
  }

  List<LibraryItem> get _visible =>
      sortLibraryItems(filterLibraryItems(_items, _query), _sort, _asc);

  /// Un artiste favori n'a PAS de contrepartie serveur (voir LibraryButton):
  /// le retrait est purement local, et toutes les formes de clé partent
  /// ensemble (uuid, nom) pour ne pas laisser un doublon derrière.
  Future<void> _remove(LibraryItem item) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await LocalDb.instance
        .removeArtistFromLibrary(item.name, refId: item.refId);
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
      appBar: AppBar(title: Text(l10n.libraryArtists)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              LibraryToolbar(
                query:   _query,
                onQuery: (v) => setState(() => _query = v),
                hintText: l10n.searchFilterPlaceholder,
                sorts: const [LibrarySort.name, LibrarySort.added],
                sort: _sort,
                ascending: _asc,
                onSort: (s, asc) => setState(() {
                  _sort = s;
                  _asc  = asc;
                  UserSettings.instance.setLibrarySort('artist', s.pref, asc);
                }),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text(
                        _items.isEmpty ? l10n.libraryEmpty : l10n.searchNoResults,
                        style: TextStyle(color: cs.outline)))
                    : ListView.builder(
                  padding: shellInset(context, EdgeInsets.zero),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return Dismissible(
                      key: ValueKey(item.refId),
                      direction: DismissDirection.endToStart,
                      // Le balayage PROPOSE, il ne décide pas: sans ce
                      // garde-fou, un geste de trop retirait l'entrée sans
                      // retour possible.
                      confirmDismiss: (_) =>
                          confirmLibraryRemoval(context, item.name),
                      background: Container(
                        color: cs.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: Icon(Icons.delete_outline,
                            color: cs.onErrorContainer),
                      ),
                      onDismissed: (_) => _remove(item),
                      child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          item.name.isNotEmpty
                              ? item.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                      title: Text(item.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: widget.onNavigateArtist != null
                          ? const Icon(Icons.chevron_right)
                          : null,
                      onLongPress: () => showLibraryItemMenu(context,
                          title: item.name, onRemove: () => _remove(item)),
                      onTap: widget.onNavigateArtist == null ? null : () {
                        // refId = the artist uuid when the row was saved from
                        // a screen that knew it (homonym-proof); it equals the
                        // NAME for legacy rows, which must not travel as an id.
                        widget.onNavigateArtist!(item.name,
                            collection: item.collectionSlug,
                            artistId: item.refId != item.name
                                ? item.refId
                                : null);
                      },
                    ),
                    );
                  },
                ),
              ),
            ]),
    );
  }
}
