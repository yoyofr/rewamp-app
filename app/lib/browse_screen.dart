import 'collection_families.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'app_snack.dart';
import 'l10n.dart';
import 'library_toolbar.dart' show ListFilterField, kListFilterThreshold,
    matchesFilterQuery;
import 'cancel_field.dart';
import 'scrolling_text.dart';
import 'view_mode_picker.dart';
import 'collection_chip_axis.dart';
import 'rewamp_db.dart';
import 'artwork_image.dart';
import 'album_detail_screen.dart';
import 'facet_picker_sheet.dart';
import 'library_button.dart';
import 'search_screen.dart'
    show playAlbumFromList, ArtistResultsScreen, openGroup;
import 'hover_grow.dart';
import 'entity_play_actions.dart';
import 'radio_surprise_buttons.dart';
import 'song_tile.dart';
import 'track_options_sheet.dart';
import 'user_settings.dart';
import 'shell_insets.dart';

// ---------------------------------------------------------------------------
// BrowseResultsScreen — uses browse_music RPC (no text query)
// ---------------------------------------------------------------------------

class BrowseResultsScreen extends StatefulWidget {
  final String  label;
  final String? collection;
  final String? artistName;
  final String? platform;
  final String? formatFilter;
  final List<String> tags;
  // mig 159: resolve [tags] only within these categories (null = all).
  final List<String>? tagCategories;
  final String  sortBy;
  final bool    showFilter;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnPlayAlbum? onPlayAlbum;

  const BrowseResultsScreen({
    super.key,
    required this.label,
    this.collection,
    this.artistName,
    this.platform,
    this.formatFilter,
    this.tags      = const [],
    this.tagCategories,
    this.sortBy    = 'title',
    this.showFilter = false,
    required this.onTap,
    this.onPlayAlbum,
  });

  @override
  State<BrowseResultsScreen> createState() => _BrowseResultsScreenState();
}

class _BrowseResultsScreenState extends State<BrowseResultsScreen> {
  final _scroll      = ScrollController();
  final _filterCtrl  = TextEditingController();
  final _notifier    = ValueNotifier<List<SearchResult>>([]);
  Timer?  _debounce;
  String? _activeFilter; // non-null → search_music mode

  /// Puce choisie sur l'axe de la collection (null = toutes). Voir
  /// collection_chip_axis.dart: une collection comme `midi` mélange du General
  /// MIDI et du MT-32, qui ne s'écoutent pas de la même façon.
  String? _chipTag;

  /// Les tags RÉELLEMENT envoyés: ceux de la destination plus, le cas échéant,
  /// la puce choisie. Un seul point de vérité — les trois requêtes de l'écran
  /// (morceaux, sonde d'albums, radio) et l'onglet Albums doivent filtrer
  /// PAREIL, sinon l'onglet annonce des albums que la liste ne montre pas.
  List<String> get _tags =>
      _chipTag == null ? widget.tags : [...widget.tags, _chipTag!];

  /// Radio (n = 50) / Surprise (n = 1) sur la portée de l'écran: le serveur
  /// tire au hasard DANS les facettes courantes — ce n'est pas un mélange de
  /// la page chargée, qui ne verrait que les 50 premières lignes.
  Future<void> _playRandomScope(int n) async {
    final seed = DateTime.now().microsecondsSinceEpoch.toString();
    try {
      final songs = await RewampDb.browse(
        collection: widget.collection,
        artistName: widget.artistName,
        platform: widget.platform,
        formatFilter: widget.formatFilter,
        tags: _tags,
        tagCategories: widget.tagCategories,
        sortBy: 'random',
        seed: seed,
        limit: n,
      );
      if (!mounted || songs.isEmpty) return;
      (widget.onPlayAlbum ?? globalOnPlayAlbum)?.call(context, songs);
    } catch (_) {}
  }

  int    _total       = 0;
  int    _offset      = 0;
  bool   _hasMore     = false;
  bool   _loading     = true;
  bool   _loadingMore = false;
  String? _error;

  /// Nombre d'albums sur cet axe, 0 tant qu'on ne sait pas. Sert uniquement à
  /// décider si la bascule Albums s'affiche.
  int _albumCount = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
    _probeAlbums();
  }

  /// Une requête d'UNE ligne, juste pour lire `total_count`. `search_albums`
  /// accepte `platform_name` et `tags[]` — c'est ce que ces destinations ne
  /// demandaient jamais, d'où « il n'y a que des morceaux ». Sondé plutôt que
  /// supposé: beaucoup de plateformes (les collections modland par exemple) et
  /// de tags n'ont aucun album, et un onglet vide est pire que pas d'onglet.
  /// Silencieux en cas d'échec: c'est une affordance, pas le contenu.
  Future<void> _probeAlbums() async {
    if (widget.platform == null && _tags.isEmpty) return;
    try {
      final res = await RewampDb.searchAlbums(
        '',
        collection:    widget.collection,
        platform:      widget.platform,
        tags:          _tags,
        tagCategories: widget.tagCategories,
        sortBy:        'name',
        sortDir:       'asc',
        limit:         1,
      );
      if (!mounted) return;
      setState(() => _albumCount = res.isEmpty ? 0 : res.first.totalCount);
    } catch (_) {/* pas d'affordance, tant pis */}
  }

  /// La rangée de puces coiffe les deux onglets — elle les filtre tous les
  /// deux, donc elle ne peut pas vivre dans l'un d'eux.
  Widget _withChipRow(Widget? chipRow, Widget body) => chipRow == null
      ? body
      : Column(children: [chipRow, Expanded(child: body)]);

  @override
  void dispose() {
    _scroll.dispose();
    _filterCtrl.dispose();
    _notifier.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  /// Change de puce: tout est refait — la liste, la sonde d'albums (une puce
  /// peut n'avoir aucun album alors que l'autre en a 554) et, par sa clé,
  /// l'onglet Albums.
  void _onChipAxis(String? tag) {
    if (_chipTag == tag) return;
    setState(() { _chipTag = tag; _albumCount = 0; });
    _reload();
    _probeAlbums();
  }

  void _onFilterChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _activeFilter = text.trim().isEmpty ? null : text.trim();
      _reload();
    });
  }

  // Fetches a page of results. Uses search_music when a text filter is active,
  // browse_music otherwise — caller passes the same _activeFilter snapshot.
  Future<List<SearchResult>> _fetch(String? filter, int offset) {
    if (filter != null) {
      return RewampDb.search(
        filter,
        fuzzy:        true,
        collection:   widget.collection,
        artistName:   widget.artistName,
        platform:     widget.platform,
        formatFilter: widget.formatFilter,
        tags:         _tags,
        tagCategories: widget.tagCategories,
        sortBy:       widget.sortBy,
        limit:        50,
        offset:       offset,
      );
    }
    return RewampDb.browse(
      collection:   widget.collection,
      artistName:   widget.artistName,
      platform:     widget.platform,
      formatFilter: widget.formatFilter,
      tags:         _tags,
        tagCategories: widget.tagCategories,
      sortBy:       widget.sortBy,
      limit:        50,
      offset:       offset,
    );
  }

  Future<void> _reload() async {
    final filter = _activeFilter;
    setState(() { _loading = true; _error = null; });
    _notifier.value = [];
    try {
      final res = await _fetch(filter, 0);
      if (!mounted) return;
      _notifier.value = res;
      _total   = res.isEmpty ? 0 : res.first.totalCount;
      _offset  = res.length;
      _hasMore = _total > 0 && _offset < _total;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final filter = _activeFilter;
    try {
      final more = await _fetch(filter, _offset);
      if (!mounted) return;
      _notifier.value = [..._notifier.value, ...more];
      _offset  += more.length;
      _hasMore  = _offset < _total;
      setState(() => _loadingMore = false);
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Axe de PUCE de la collection (General MIDI / MT-32 sur `midi`): une
    // rangée de puces au-dessus des deux onglets, parce qu'elle les filtre
    // TOUS LES DEUX. Rien à afficher pour une collection qui n'en déclare pas.
    final chipAxis = chipAxisFor(widget.collection);
    Widget? chipRow;
    if (chipAxis.isNotEmpty) {
      chipRow = Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(l10n.searchCollectionAll),
              selected: _chipTag == null,
              onSelected: (_) => _onChipAxis(null),
            ),
            // Noms de tags, pas de slugs: c'est ce que le serveur apparie, et
            // ce sont des noms propres — rien à traduire.
            for (final tag in chipAxis)
              ChoiceChip(
                label: Text(tag),
                selected: _chipTag == tag,
                onSelected: (_) => _onChipAxis(tag),
              ),
          ],
        ),
      );
    }

    final songsBody = Column(
      children: [
        if (widget.showFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: CancelField(
              controller: _filterCtrl,
              onCleared: _onFilterChanged,
              builder: (_) => TextField(
                controller: _filterCtrl,
                decoration: InputDecoration(
                  hintText: l10n.browseFilterByTitle,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: _onFilterChanged,
              ),
            ),
          ),
        Expanded(child: _buildBody()),
      ],
    );

    // Deux onglets Morceaux / Albums dès que l'axe (plateforme ou tag) porte
    // des albums — sondé à l'ouverture (_probeAlbums), même règle que les
    // cartes du hub de collection: un axe vide ne s'affiche pas plutôt que de
    // mener à une liste vide. L'onglet Albums est l'écran d'albums EMBARQUÉ,
    // avec ses filtres (plateforme/collection) et ses dispositions.
    if (_albumCount <= 0) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.label)),
        body: chipRow == null
            ? songsBody
            : Column(children: [chipRow, Expanded(child: songsBody)]),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.label),
          bottom: TabBar(tabs: [
            Tab(text: l10n.tabAll),
            Tab(text: l10n.tabAlbums),
          ]),
        ),
        body: _withChipRow(chipRow, TabBarView(children: [
          songsBody,
          CollectionAlbumsScreen(
            // La clé porte la puce: l'écran d'albums charge dans son
            // initState, donc sans elle changer de puce ne rechargeait rien.
            key:           ValueKey(_chipTag),
            collection:    widget.collection,
            platform:      widget.platform,
            tags:          _tags,
            tagCategories: widget.tagCategories,
            title:         widget.label,
            embedded:      true,
            onTap:         widget.onTap,
            onPlayAlbum:   widget.onPlayAlbum,
          ),
        ])),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    return ValueListenableBuilder<List<SearchResult>>(
      valueListenable: _notifier,
      builder: (_, raw, __) {
        // Sous filtre TEXTE le flux est search_music: il ramène aussi les
        // pistes d'un album dont seul le NOM d'album matche, et la ligne de
        // l'album entier. Cette liste est celle des MORCEAUX — même règle que
        // l'onglet Morceaux de la recherche, sinon « Tout lire » et la liste
        // ne montrent pas la même chose.
        final filter = _activeFilter;
        final results = filter == null
            ? raw
            : [
                for (final r in raw)
                  if (!RewampDb.isWholeAlbumRow(r) &&
                      !RewampDb.matchedAlbumNameOnly(r, filter))
                    r,
              ];
        // Page entièrement filtrée: la ListView serait vide, ne défilerait pas,
        // et plus rien ne rappellerait loadMore.
        if (results.isEmpty && raw.isNotEmpty && _hasMore && !_loadingMore) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
        }
        if (raw.isEmpty) {
          return Center(
            child: Text(
              _activeFilter != null ? l10n.searchNoResults : l10n.browseNoSongs,
            ),
          );
        }
        return Column(
          children: [
            _BrowseCountBar(
              loaded: results.length,
              total: _total,
              loading: _loadingMore,
              // « Tout lire » sur les MORCEAUX chargés: une ligne qui
              // représente un ALBUM ENTIER (archive joshw, flux search_music
              // sous filtre texte) n'en est pas un. ⚠️ Prédicat ÉTROIT
              // (isWholeAlbumRow): `isAlbumLevelMatch` attrape aussi les
              // membres d'archive sans url à eux, qui sont des morceaux — les
              // écarter vidait la liste et rendait le bouton muet.
              // Radio / Surprise: la MÊME portée (collection, artiste,
              // plateforme, format, tags), tirée au hasard côté serveur — une
              // station sur ce qu'on parcourt, pas sur la page chargée.
              onRadio: () => _playRandomScope(50),
              onSurprise: () => _playRandomScope(1),
              onPlayAll: () async {
                final songs = _activeFilter == null
                    ? results
                    : [
                        for (final r in results)
                          if (!RewampDb.isWholeAlbumRow(r) &&
                              !RewampDb.matchedAlbumNameOnly(r, _activeFilter!))
                            r,
                      ];
                if (songs.isEmpty) return;
                // Ligne dont le serveur a nommé la piste → cette piste, pas le
                // conteneur.
                final resolved = await RewampDb.resolveMatchedTracks(songs);
                if (!mounted) return;
                (widget.onPlayAlbum ?? globalOnPlayAlbum)
                    ?.call(context, resolved);
              },
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                itemCount: results.length + (_hasMore ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == results.length) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return SongTile(
                      result:      results[i],
                      onTap:       widget.onTap,
                      onPlayAlbum: widget.onPlayAlbum,
                      // Les navigateurs par facette qui ne sont PAS bornés à
                      // une collection (plateforme, puce, éditeur, année…)
                      // brassent tout le catalogue: d'où vient chaque ligne
                      // est une information — en petit, sur sa propre ligne.
                      // Borné à une collection, elle serait du bruit répété.
                      showCollection: widget.collection == null);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _CountKind { songs, albums, artists }

/// Rangée d'actions seule — les écrans d'angle qui n'ont pas de barre de
/// comptage (groupes, pays, formats, valeurs de facette) portent la MÊME
/// famille de trois boutons que le reste de l'application. Aucune action = la
/// rangée ne s'affiche pas.
class _ActionsBar extends StatelessWidget {
  final VoidCallback? onPlayAll, onRadio, onSurprise;
  const _ActionsBar({this.onPlayAll, this.onRadio, this.onSurprise});

  @override
  Widget build(BuildContext context) {
    if (onPlayAll == null && onRadio == null && onSurprise == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(children: [
        const Spacer(),
        RadioSurpriseButtons(
          onPlayAll: onPlayAll,
          onRadio: onRadio,
          onSurprise: onSurprise,
          dense: true,
        ),
      ]),
    );
  }
}

class _BrowseCountBar extends StatelessWidget {
  final int  loaded;
  final int  total;
  final bool loading;
  /// What is being counted. NOT a noun injected into the sentence: Slavic
  /// languages decline the noun with the number ("2 песни" vs "340 песен"), so
  /// each kind needs its own plural-aware message.
  final _CountKind kind;
  /// « Tout lire » — lance ce qui est AFFICHÉ (les lignes chargées, pas le
  /// total serveur). Plafond de file en aval (kQueueLimit, annoncé).
  final VoidCallback? onPlayAll;
  /// Radio / Surprise: la MÊME famille de trois boutons que partout ailleurs
  /// (recherche, artiste, palmarès). Une barre sans aucune des trois actions
  /// n'affiche RIEN — un bouton grisé sur une liste vide laissait croire
  /// qu'il y a quelque chose à lancer.
  final VoidCallback? onRadio;
  final VoidCallback? onSurprise;

  const _BrowseCountBar(
      {required this.loaded,
      required this.total,
      required this.loading,
      this.kind = _CountKind.songs,
      this.onPlayAll,
      this.onRadio,
      this.onSurprise});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = total > 0
        ? switch (kind) {
            _CountKind.songs   => l10n.browseCountSongs(total, loaded),
            _CountKind.albums  => l10n.browseCountAlbums(total, loaded),
            _CountKind.artists => l10n.browseCountArtists(total, loaded),
          }
        : switch (kind) {
            _CountKind.songs   => l10n.browseLoadedSongs(loaded),
            _CountKind.albums  => l10n.browseLoadedAlbums(loaded),
            _CountKind.artists => l10n.browseLoadedArtists(loaded),
          };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          if (loading) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
          if (onPlayAll != null || onRadio != null || onSurprise != null) ...[
            const Spacer(),
            RadioSurpriseButtons(
              onPlayAll: onPlayAll,
              onRadio: onRadio,
              onSurprise: onSurprise,
              dense: true,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FormatPickerScreen — fetches /formats, navigates to BrowseResultsScreen
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// FacetValuesScreen — 1st level of « Parcourir » : the values of ONE facet
// (collections, groupes, chips, années, parties…), usage-sorted with counts.
// Tap a value → BrowseResultsScreen filtered on it. Collections use the same
// screen/logic as the tag categories.
// ---------------------------------------------------------------------------

class FacetValuesScreen extends StatefulWidget {
  final String title;
  /// Tag category slug ('group', 'chip', …) — null means collections mode.
  final String? tagCategory;
  /// Mode collections: clé d'une FAMILLE (`joshw`) dont on liste les seuls
  /// membres, à plat. Null = la liste racine, où les familles sont repliées en
  /// une ligne chacune (voir collection_families.dart). L'écran se réutilise
  /// donc tel quel comme niveau de descente — même recherche, même hub.
  final String? collectionFamily;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  /// Queue playback (parties: play a compo in ranking order). Optional.
  final OnPlayAlbum? onPlayAlbum;

  const FacetValuesScreen({
    super.key,
    required this.title,
    this.tagCategory,
    this.collectionFamily,
    required this.onTap,
    this.onPlayAlbum,
  });

  @override
  State<FacetValuesScreen> createState() => _FacetValuesScreenState();
}

class _FacetValuesScreenState extends State<FacetValuesScreen> {
  final _filterCtrl = TextEditingController();
  final _scroll     = ScrollController();
  Timer? _debounce;

  // Row model shared by both modes.
  final _values = <({String label, String key, int? count})>[];
  String _query       = '';
  bool   _loading     = true;
  bool   _loadingMore = false;
  bool   _hasMore     = false;
  String? _error;
  int    _reqId = 0;

  static const _pageSize = 100;

  bool get _isCollections => widget.tagCategory == null;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    _scroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _onFilterChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _query = text.trim();
      _load();
    });
  }

  Future<void> _load() async {
    final id = ++_reqId;
    setState(() { _loading = true; _error = null; });
    try {
      if (_isCollections) {
        final cols = await RewampDb.fetchCollections();
        if (!mounted || id != _reqId) return;
        final q = _query.toLowerCase();
        final family = widget.collectionFamily;
        final visible = cols
            .where((c) => c.filesCount > 0)
            // Niveau famille: ses membres et rien d'autre.
            .where((c) => family == null ||
                collectionFamilyOf(c.slug)?.key == family)
            .where((c) =>
                q.isEmpty || c.name.toLowerCase().contains(q) ||
                c.slug.toLowerCase().contains(q))
            .toList();
        // À la racine, au repos: les familles se replient en une ligne (clé
        // `family:<key>`, résolue au tap). Sous recherche la liste reste
        // PLATE — on a tapé, on veut des correspondances, pas de la structure.
        // Au niveau famille, les membres perdent le nom qu'ils répètent
        // (« joshw SPC (SNES) » → « SPC (SNES) »).
        final rows = <({String label, String key, int? count})>[];
        if (family != null) {
          final label = kCollectionFamilies
              .firstWhere((f) => f.key == family)
              .label;
          rows.addAll(visible.map((c) => (
                label: collectionMemberLabel(c, label),
                key: c.slug,
                count: c.filesCount)));
        } else if (q.isNotEmpty) {
          rows.addAll(visible.map((c) => (
                label: c.name.isNotEmpty ? c.name : c.slug,
                key: c.slug,
                count: c.filesCount)));
        } else {
          for (final e in groupCollections(visible)) {
            rows.add(switch (e) {
              SingleCollectionEntry(:final collection) => (
                  label: collection.name.isNotEmpty
                      ? collection.name
                      : collection.slug,
                  key: collection.slug,
                  count: collection.filesCount),
              CollectionFamilyEntry() => (
                  label: e.label,
                  key: 'family:${e.key}',
                  count: e.filesCount),
            });
          }
        }
        setState(() {
          _values
            ..clear()
            ..addAll(rows);
          _hasMore = false;
          _loading = false;
        });
      } else {
        final tags = await RewampDb.listTags(
          query:    _query.isEmpty ? null : _query,
          category: widget.tagCategory,
          byUsage:  true,
          limit:    _pageSize,
        );
        if (!mounted || id != _reqId) return;
        setState(() {
          _values
            ..clear()
            ..addAll(tags.map((t) =>
                (label: t.name, key: t.name, count: t.usageCount)));
          final total = tags.isEmpty ? 0 : (tags.first.totalCount ?? 0);
          _hasMore = total > _values.length;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadMore() async {
    if (_isCollections || _loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    final id = _reqId;
    try {
      final more = await RewampDb.listTags(
        query:    _query.isEmpty ? null : _query,
        category: widget.tagCategory,
        byUsage:  true,
        limit:    _pageSize,
        offset:   _values.length,
      );
      if (!mounted || id != _reqId) return;
      setState(() {
        _values.addAll(more.map((t) =>
            (label: t.name, key: t.name, count: t.usageCount)));
        _hasMore = more.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openValue(({String label, String key, int? count}) v) {
    // Parties get an intermediate level: « Toutes les années » + the compo
    // playlists per year, ordered by the party ranking.
    if (widget.tagCategory == 'party') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PartyDetailScreen(
          party:       v.key,
          onTap:       widget.onTap,
          onPlayAlbum: widget.onPlayAlbum,
        ),
      ));
      return;
    }
    // A group is an entity, not a filter value: its screen carries the members,
    // the demozoo note and — the part no tag query can produce — its
    // productions (a production is not tagged, it is released BY a group).
    if (widget.tagCategory == 'group') {
      openGroup(context, v.key);
      return;
    }
    // EVERY collection lands on the data-driven hub — never the flat
    // alphabetical dump (445k rows for modland). The hub keeps each
    // collection's structural entry as its FIRST card (folder tree for
    // modland/hvsc/…, albums for vgmrips/snesmusic/…, the A–Z artist list
    // for zxart/sceneorg) and the rest of the cards come from
    // get_collection_overview counts, so a collection only offers the axes
    // it actually has (groups, countries, formats, top…).
    if (_isCollections) {
      // Une FAMILLE descend d'un niveau (le même écran, filtré à ses
      // membres); une collection ouvre son hub, comme toujours. Le slug qui
      // part au serveur reste celui d'un membre — jamais la famille.
      if (v.key.startsWith('family:')) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FacetValuesScreen(
            title:            v.label,
            collectionFamily: v.key.substring('family:'.length),
            onTap:            widget.onTap,
            onPlayAlbum:      widget.onPlayAlbum,
          ),
        ));
        return;
      }
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CollectionHubScreen(
          collection:  v.key,
          title:       v.label,
          onTap:       widget.onTap,
          onPlayAlbum: widget.onPlayAlbum,
        ),
      ));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BrowseResultsScreen(
        label:       v.label,
        tags:        [v.key],
        tagCategories: widget.tagCategory != null
            ? [widget.tagCategory!]
            : null,
        showFilter:  true,
        onTap:       widget.onTap,
        onPlayAlbum: widget.onPlayAlbum,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: CancelField(
              controller: _filterCtrl,
              onCleared: _onFilterChanged,
              builder: (_) => TextField(
                controller: _filterCtrl,
                decoration: InputDecoration(
                  hintText: context.l10n.browseFilterFacet(widget.title.toLowerCase()),
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: _onFilterChanged,
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          // Une VALEUR de facette se déplie par `browse_music`: la collection
          // elle-même en mode collections, le tag dans sa catégorie sinon.
          if (!_loading && _values.isNotEmpty)
            Builder(builder: (ctx) {
              final a = entityPlayActions<({String label, String key, int? count})>(
                ctx,
                _values,
                (v) => _isCollections
                    ? RewampDb.browse(
                        collection: v.key, sortBy: 'name', limit: 200)
                    : RewampDb.browse(
                        tags: [v.key],
                        tagCategories: [widget.tagCategory!],
                        sortBy: 'name',
                        limit: 200),
                onPlayAlbum: widget.onPlayAlbum,
              );
              return _ActionsBar(
                  onPlayAll: a.playAll,
                  onRadio: a.radio,
                  onSurprise: a.surprise);
            }),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    itemCount: _values.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= _values.length) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                              child: SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))),
                        );
                      }
                      final v = _values[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.primaryContainer,
                          child: Text(
                            v.label.isNotEmpty ? v.label[0].toUpperCase() : '?',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: cs.onPrimaryContainer),
                          ),
                        ),
                        title: ScrollingText(text: v.label),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (v.count != null)
                              Text('${v.count}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _openValue(v),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PartyDetailScreen — one demoscene party: « Toutes les années » + the compo
// playlists grouped by year (each playlist = one compo, tracks ordered by the
// party RANKING via track_position — no server change needed).
// ---------------------------------------------------------------------------

class PartyDetailScreen extends StatefulWidget {
  final String party; // party tag name, e.g. 'Assembly'
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnPlayAlbum? onPlayAlbum;

  const PartyDetailScreen({
    super.key,
    required this.party,
    required this.onTap,
    this.onPlayAlbum,
  });

  @override
  State<PartyDetailScreen> createState() => _PartyDetailScreenState();
}

class _PartyDetailScreenState extends State<PartyDetailScreen> {
  List<Playlist>? _playlists;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pls =
          await RewampDb.listPlaylists(
              tags: [widget.party],
              tagCategories: const ['party'],
              limit: 300);
      if (!mounted) return;
      setState(() => _playlists = pls);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  String? _yearOf(Playlist p) {
    for (final t in p.tags) {
      if (RegExp(r'^(19|20)\d\d$').hasMatch(t)) return t;
    }
    return null;
  }

  /// ▶ on a compo row: play the whole ranked playlist.
  Future<void> _playPlaylist(BuildContext ctx, Playlist p) async {
    try {
      final tracks = await RewampDb.playlistTracks(p.id);
      if (!ctx.mounted || tracks.isEmpty) return;
      if (widget.onPlayAlbum != null) {
        await widget.onPlayAlbum!(ctx, tracks);
      } else {
        await widget.onTap(ctx, tracks.first);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;

    // Group compo playlists by year, newest first; no-year ones at the end.
    final byYear = <String, List<Playlist>>{};
    for (final p in _playlists ?? const <Playlist>[]) {
      byYear.putIfAbsent(_yearOf(p) ?? '—', () => []).add(p);
    }
    final years = byYear.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // '—' sorts before digits → move last
    if (years.remove('—')) years.add('—');

    return Scaffold(
      appBar: AppBar(title: Text(widget.party)),
      body: _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _playlists == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    // « Toutes les années » — plain tag browse over the party.
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Icon(Icons.all_inclusive,
                            size: 20, color: cs.onPrimaryContainer),
                      ),
                      title: Text(l10n.browseAllYears),
                      subtitle: Text(l10n.browseAllYearsSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => BrowseResultsScreen(
                          label:      widget.party,
                          tags:       [widget.party],
                          tagCategories: const ['party'],
                          showFilter: true,
                          onTap:      widget.onTap,
                        ),
                      )),
                    ),
                    const Divider(height: 1),
                    if ((_playlists ?? const []).isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          l10n.browseNoCompo,
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    for (final y in years) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          y == '—' ? l10n.browseOthers : y,
                          style: tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      for (final p in byYear[y]!)
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.emoji_events_outlined,
                              color: cs.primary),
                          title: ScrollingText(text: p.name),
                          subtitle: Text([
                            l10n.browseCompoEntries(p.trackCount),
                            // Author of a published user playlist (mig 193);
                            // absent on the server's own playlists.
                            if ((p.authorName ?? '').isNotEmpty)
                              l10n.playlistByAuthor(p.authorName!),
                          ].join('  ·  '),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_circle_outline),
                                tooltip: l10n.browsePlayPlaylist,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 36, minHeight: 36),
                                onPressed: () => _playPlaylist(context, p),
                              ),
                              LibraryButton(
                                type:       'playlist',
                                refId:      p.id,
                                name:       p.name,
                                artworkUrl: p.coverUrl,
                                filename:   p.slug,
                                // Stash the entry count so the library list can
                                // show it without a network round-trip — and the
                                // author's pen name with it, for the same reason
                                // (empty on a server-curated playlist).
                                formatExt:  p.trackCount > 0
                                    ? '${p.trackCount}'
                                    : null,
                                artist:     p.authorName,
                                iconSize:   20,
                                padding:    const EdgeInsets.all(4),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () =>
                              Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => PlaylistTracksScreen(
                              playlist:    p,
                              onTap:       widget.onTap,
                              onPlayAlbum: widget.onPlayAlbum,
                            ),
                          )),
                        ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// PlaylistTracksScreen — ordered playlist (compo ranking: 1 = winner).
// ---------------------------------------------------------------------------

/// Playlist identity at the top of its track list: cover, name, description,
/// track count. Without it a "Hall of Fame — Solskogen" list is just a wall of
/// songs — the header is what says what you are looking at, and where a
/// featured-rail tap lands rather than starting playback blind.
class _PlaylistHeader extends StatelessWidget {
  final Playlist playlist;
  final int trackCount;
  /// Why this playlist is being shown — the featured rail's reason ("Solskogen
  /// season — podiums from past editions"). It has no room on a rail card, so
  /// it belongs here, where it can be read in full.
  final String? note;

  const _PlaylistHeader(
      {required this.playlist, required this.trackCount, this.note});

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final tt   = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final desc = playlist.description;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox.square(
              dimension: 96,
              child: playlist.coverUrl != null
                  ? ArtworkImage(url: playlist.coverUrl, size: 96)
                  : Container(
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.queue_music,
                          color: cs.onSurfaceVariant, size: 40),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(playlist.name,
                    style: tt.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(l10n.browseTracksCount(trackCount),
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
                // A published user playlist is credited to its author's public
                // name (migration 193). Server-curated playlists carry none, so
                // this line simply does not appear on them.
                if ((playlist.authorName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(l10n.playlistByAuthor(playlist.authorName!),
                      style: tt.bodySmall?.copyWith(color: cs.primary)),
                ],
                // Une note IDENTIQUE à la description ne dit rien deux fois.
                if (note != null && note!.isNotEmpty && note != desc) ...[
                  const SizedBox(height: 6),
                  Text(note!,
                      style: tt.bodySmall?.copyWith(
                          color: cs.primary, fontStyle: FontStyle.italic)),
                ],
                if (desc != null && desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(desc,
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlaylistTracksScreen extends StatefulWidget {
  final Playlist playlist;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnPlayAlbum? onPlayAlbum;
  /// Why the user got here (the featured rail's reason). Shown in the header.
  final String? note;

  const PlaylistTracksScreen({
    super.key,
    required this.playlist,
    required this.onTap,
    this.onPlayAlbum,
    this.note,
  });

  @override
  State<PlaylistTracksScreen> createState() => _PlaylistTracksScreenState();
}

class _PlaylistTracksScreenState extends State<PlaylistTracksScreen> {
  List<SearchResult>? _tracks;
  String? _error;
  String _query = '';

  /// Les indices, dans `_tracks`, des lignes que la liste MONTRE.
  ///
  /// ⚠️ **Le filtre sert à TROUVER, pas à redéfinir la playlist**: la lecture
  /// porte sur la liste ENTIÈRE et l'index de la ligne tapée est celui de
  /// cette liste-là ([_playFrom]). Le rang affiché aussi — c'est une position
  /// dans la playlist, pas dans ce qu'on a filtré.
  List<int> get _visibleIdx {
    final t = _tracks ?? const <SearchResult>[];
    return [
      for (var i = 0; i < t.length; i++)
        if (matchesFilterQuery(_query,
            [t[i].displayTitle, t[i].artistLabel, t[i].album]))
          i,
    ];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tracks = await RewampDb.playlistTracks(widget.playlist.id);
      if (!mounted) return;
      setState(() => _tracks = tracks);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  /// [idx] null = "Tout lire": the queue starts wherever the play path decides,
  /// which under shuffle means a RANDOM first track. Passing 0 instead pins
  /// track 1 at the head (that is how a TAPPED row is expressed), so play-all
  /// always opened on the same tune with shuffle on.
  Future<void> _playFrom(int? idx) async {
    final tracks = _tracks;
    if (tracks == null || tracks.isEmpty) return;
    if (widget.onPlayAlbum != null) {
      await widget.onPlayAlbum!(context, tracks, startIndex: idx);
    } else {
      await widget.onTap(context, tracks[idx ?? 0]);
    }
  }

  String _rankLabel(int pos) => switch (pos) {
        1 => '🥇',
        2 => '🥈',
        3 => '🥉',
        _ => '$pos',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _tracks == null
              ? const Center(child: CircularProgressIndicator())
              : Builder(builder: (context) {
                final visible = _visibleIdx;
                return Column(children: [
                  // Le filtre n'apparaît qu'au-delà du seuil: en dessous, l'œil
                  // va plus vite que le clavier.
                  if (_tracks!.length > kListFilterThreshold)
                    ListFilterField(
                      query: _query,
                      onQuery: (v) => setState(() => _query = v),
                    ),
                  Expanded(child: ListView.builder(
                  // Row 0 = playlist info, row 1 = "play the playlist",
                  // then the tracks.
                  itemCount: visible.length + 2,
                  itemBuilder: (ctx, idx) {
                    if (idx == 0) {
                      return _PlaylistHeader(
                          playlist:   widget.playlist,
                          trackCount: _tracks!.length,
                          note:       widget.note);
                    }
                    if (idx == 1) {
                      // Canonical "Tout lire" button — same FilledButton.icon +
                      // commonPlayAll used by the local-playlist and subsong
                      // screens (was a divergent bold ListTile).
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(children: [
                          FilledButton.icon(
                            onPressed:
                                _tracks!.isEmpty ? null : () => _playFrom(null),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(l10n.commonPlayAll),
                          ),
                          const SizedBox(width: 8),
                          // In-library toggle sits next to "Tout lire" (moved
                          // from the AppBar, which also carried a duplicate
                          // play-all button — removed).
                          LibraryButton(
                            type:       'playlist',
                            refId:      widget.playlist.id,
                            name:       widget.playlist.name,
                            artworkUrl: widget.playlist.coverUrl,
                            filename:   widget.playlist.slug,
                            formatExt:  widget.playlist.trackCount > 0
                                ? '${widget.playlist.trackCount}'
                                : null,
                            artist:     widget.playlist.authorName,
                          ),
                          const Spacer(),
                          Text(
                            l10n.playlistTrackCount(_tracks!.length),
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ]),
                      );
                    }
                    final i    = visible[idx - 2];
                    final r    = _tracks![i];
                    final meta = r.playlistMeta;
                    // Compo rank from playlist_items.meta (may repeat: several
                    // songs of one demo share its ranking); non-compo
                    // playlists have no meta → sequential position.
                    final pos = meta?.rank ?? r.trackPosition ?? (i + 1);
                    // Medals ONLY for a real compo ranking (meta.rank). A
                    // non-compo playlist (anniversary "Games of…") has no rank →
                    // the number is just the entry position, so no podium.
                    final hasRank  = meta?.rank != null;
                    final isMedal  = hasRank && pos <= 3;
                    final rankStr  = hasRank ? _rankLabel(pos) : '$pos';
                    // Where it placed. The meta shape differs per playlist kind
                    // (compo → production/group, Hall of Fame → party/year), so
                    // take whichever is there. Platform only when the row has
                    // one (null on the demoscene collections).
                    final placing = [
                      if (meta?.production != null) meta!.production!,
                      if (meta?.group != null) meta!.group!,
                      if (meta?.party != null) meta!.party!,
                      if (meta?.year != null) '${meta!.year}',
                      if (r.platform != null && r.platform!.isNotEmpty)
                        r.platform!,
                    ].join(' · ');
                    final subtitle = [
                      if (r.artistLabel.isNotEmpty) r.artistLabel,
                      if (placing.isNotEmpty) placing,
                    ].join(' — ');
                    final hasArt =
                        r.artworkUrl != null && r.artworkUrl!.isNotEmpty;
                    final rankText = Text(
                      rankStr,
                      style: TextStyle(
                        fontSize: isMedal ? 20 : 14,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurfaceVariant,
                      ),
                    );
                    return ListTile(
                      // Small album/file artwork when the row has one, with the
                      // rank as a badge over its corner; plain rank otherwise.
                      leading: hasArt
                          ? SizedBox(
                              width: 44,
                              height: 44,
                              child: Stack(
                                children: [
                                  // Placeholder thématisé (voir RailArtwork):
                                  // un `placeholder:` explicite l'écrase.
                                  RailArtwork(
                                    url:          r.artworkUrl,
                                    artist:       r.artistLabel.isEmpty
                                        ? null : r.artistLabel,
                                    album:        r.album,
                                    formatHint:   r.formatExt,
                                    platformName: r.platform,
                                    size:         44,
                                  ),
                                  Positioned(
                                    left: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                            alpha: 0.6),
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(5),
                                          bottomLeft: Radius.circular(5),
                                        ),
                                      ),
                                      child: Text(
                                        rankStr,
                                        style: TextStyle(
                                          fontSize: isMedal ? 13 : 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SizedBox(width: 36, child: Center(child: rankText)),
                      title: Row(children: [
                        Flexible(
                          child: Text(r.displayTitle,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        // Linked demozoo video. This screen draws its own rows
                        // (rank medals) instead of SongTile, so it needs its
                        // own badge — get_playlist_tracks is precisely the RPC
                        // that carries videos[] today.
                        if (r.hasVideo)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(Icons.ondemand_video,
                                size: 14, color: cs.primary),
                          ),
                      ]),
                      subtitle: subtitle.isEmpty
                          ? null
                          : Text(subtitle,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                        // Queue options come from the AppShell global
                        // fallbacks (Lire ensuite / Ajouter à la fin).
                        onPressed: () => showTrackOptions(ctx, r),
                      ),
                      // Tapping an entry starts the WHOLE playlist as a
                      // queue, positioned on the tapped entry (containers
                      // expand to their subsongs inside the queue).
                      onTap: () {
                        if (widget.onPlayAlbum != null) {
                          widget.onPlayAlbum!(context, List.of(_tracks!),
                              startIndex: i);
                        } else {
                          widget.onTap(context, r);
                        }
                      },
                    );
                  },
                )),
                ]);
              }),
    );
  }
}

// ---------------------------------------------------------------------------
// CollectionFolderScreen — folder-tree navigation of one collection via the
// browse_folder RPC (migration 113): subdirectories first (recursive song
// count), then the songs directly in the folder. The search field switches to
// a recursive subtree search (flat song list). « Tout lire » / shuffle queue
// the whole subtree via browse_music + path_prefix.
// ---------------------------------------------------------------------------

class CollectionFolderScreen extends StatefulWidget {
  final String collection; // slug ('modland', 'hvsc', 'asma', 'jw_nsf', …)
  final String title;      // collection name at root, folder segment deeper
  final String folder;     // '' = root; no leading/trailing slash
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnPlayAlbum? onPlayAlbum;

  const CollectionFolderScreen({
    super.key,
    required this.collection,
    required this.title,
    this.folder = '',
    required this.onTap,
    this.onPlayAlbum,
  });

  @override
  State<CollectionFolderScreen> createState() => _CollectionFolderScreenState();
}

class _CollectionFolderScreenState extends State<CollectionFolderScreen> {
  final _scroll     = ScrollController();
  final _filterCtrl = TextEditingController();
  Timer? _debounce;

  final _dirs  = <FolderEntry>[];
  final _songs = <SearchResult>[];
  // Two filter modes:
  //   _recursive = false (default) → filter THIS level's loaded rows locally,
  //     folders included. Typing narrows what is on screen — PLUS a server
  //     `q` lookup merged in (see _qDirs): local filtering only sees fetched
  //     pages, and a folder past the paging cap (modland Protracker = 7 361
  //     rows, cap 3 000 — "Zodiak" is beyond) would otherwise not exist.
  //   _recursive = true → browse_folder's `q` alone: subtree FOLDER-name
  //     search (the server matches dir names, NOT song titles, and returns
  //     dir rows with their full dir_path).
  bool   _recursive = false;
  String _filter    = '';   // raw field text (local mode: applied immediately)
  String? _query;      // non-null → recursive subtree search (dir rows)
  // Server-matched subtree folders merged into the local filter's results.
  final _qDirs = <FolderEntry>[];
  int _qDirsReqId = 0;
  int    _total       = 0;
  int    _offset      = 0;
  bool   _hasMore     = false;
  bool   _loading     = true;
  bool   _loadingMore = false;
  bool   _queueBusy   = false;
  String? _error;
  int    _reqId = 0;

  // 'list' | 'grid' | 'grid_small' — the SAME setting the album-browse screens
  // use, so the choice follows the user across the whole facet browser. Applies
  // to both folder levels (dirs) and the last level (files).
  String _viewMode = UserSettings.instance.albumViewMode;

  static const _pageSize = 200;
  // Queue cap for « Tout lire » / shuffle on a big subtree (modland format
  // dirs are tens of thousands of files).
  static const _queueMax = 500;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _filterCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _onFilterChanged(String text) {
    _debounce?.cancel();
    if (!_recursive) {
      // Local: no round-trip, apply as it is typed. Pull the rest of the folder
      // in behind it so the filter sees every row, not just the first page —
      // and ask the server for matching subtree folders in parallel (capped
      // paging means a far-alphabet folder may never be loaded locally).
      setState(() => _filter = text.trim());
      if (_filter.isEmpty) {
        setState(_qDirs.clear);
      } else {
        _loadAllForFilter();
        final id = ++_qDirsReqId;
        _debounce = Timer(const Duration(milliseconds: 300), () async {
          try {
            final page = await RewampDb.browseFolder(
              collection: widget.collection,
              folder:     widget.folder,
              q:          _filter,
              limit:      100,
            );
            if (!mounted || id != _qDirsReqId || _filter.isEmpty) return;
            setState(() => _qDirs
              ..clear()
              ..addAll(page.dirs));
          } catch (_) {/* merge is best-effort, local results stand */}
        });
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = text.trim();
      _filter = q;
      _query  = q.isEmpty ? null : q;
      _load();
    });
  }

  void _setRecursive(bool on) {
    _debounce?.cancel();
    setState(() => _recursive = on);
    final q = _filterCtrl.text.trim();
    _filter = q;
    // Only a non-empty filter makes the two modes differ; an empty one shows
    // the plain listing either way, so don't re-fetch for nothing.
    if (q.isEmpty) { setState(() => _query = null); return; }
    _query = on ? q : null;
    _load().then((_) {
      // Back to local mode with text in the field: re-run the local filter
      // machinery (page-in behind the filter + server subtree-dir merge).
      if (mounted && !on) _onFilterChanged(q);
    });
  }

  /// Local filtering only sees loaded rows, so a match past the first page
  /// would silently not exist. Keep paging until the folder is exhausted (or
  /// the cap is hit — a modland format dir holds tens of thousands of rows and
  /// the point is a responsive filter, not a full mirror).
  static const _filterLoadCap = 3000;
  Future<void> _loadAllForFilter() async {
    while (mounted && !_recursive && _filter.isNotEmpty &&
        _hasMore && !_loading && _offset < _filterLoadCap) {
      final before = _offset;
      await _loadMore();
      if (_offset == before) break;   // no progress (error) → don't spin
    }
  }

  bool _matches(String s) =>
      s.toLowerCase().contains(_filter.toLowerCase());

  /// Rows to render: everything in local mode with an empty filter, else the
  /// name matches. In recursive mode the server already filtered. Local mode
  /// also merges the server's subtree matches (_qDirs) — deduped on dir_path,
  /// since a locally-loaded folder can come back from the server too.
  List<FolderEntry> get _visibleDirs {
    if (_recursive || _filter.isEmpty) return _dirs;
    final local = _dirs.where((d) => _matches(_displayName(d.name))).toList();
    if (_qDirs.isEmpty) return local;
    final seen = {for (final d in local) d.dirPath};
    return [...local, ..._qDirs.where((d) => !seen.contains(d.dirPath))];
  }

  List<SearchResult> get _visibleSongs => (_recursive || _filter.isEmpty)
      ? _songs
      : _songs
          .where((s) =>
              _matches(_displayName(s.displayTitle)) ||
              _matches(_displayName(s.filename)))
          .toList();

  // jw_* paths are stored URL-encoded (`%20`, `%5b`…) — decode for display
  // only (dirPath round-trips raw). Other collections' paths are plain; a
  // literal '%' in a name would make decoding throw, hence the fallback.
  String _displayName(String s) {
    if (!widget.collection.startsWith('jw_')) return s;
    try {
      return Uri.decodeComponent(s);
    } catch (_) {
      return s;
    }
  }

  Future<void> _load() async {
    final id = ++_reqId;
    setState(() { _loading = true; _error = null; });
    try {
      final page = await RewampDb.browseFolder(
        collection: widget.collection,
        folder:     widget.folder,
        q:          _query,
        limit:      _pageSize,
      );
      if (!mounted || id != _reqId) return;
      setState(() {
        _dirs  ..clear()..addAll(page.dirs);
        _songs ..clear()..addAll(page.songs);
        _total   = page.totalCount;
        _offset  = page.dirs.length + page.songs.length;
        _hasMore = _offset < _total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    final id = _reqId;
    try {
      final page = await RewampDb.browseFolder(
        collection: widget.collection,
        folder:     widget.folder,
        q:          _query,
        limit:      _pageSize,
        offset:     _offset,
      );
      if (!mounted || id != _reqId) return;
      setState(() {
        _dirs.addAll(page.dirs);
        _songs.addAll(page.songs);
        _offset += page.dirs.length + page.songs.length;
        // total_count is -1 on offset>0 pages — keep the first page's value.
        _hasMore = (page.dirs.length + page.songs.length) >= _pageSize &&
            _offset < _total;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // « Tout lire » / radio / surprise: queue up to [count] songs of the WHOLE
  // subtree (recursive — an artist folder may hold album subdirs) via
  // path_prefix. [count] null = _queueMax; 1 = surprise.
  Future<void> _playSubtree({required bool shuffle, int? count}) async {
    final onPlay = widget.onPlayAlbum;
    if (onPlay == null || _queueBusy) return;
    setState(() => _queueBusy = true);
    try {
      final songs = await RewampDb.browse(
        collection: widget.collection,
        pathPrefix: widget.folder.isEmpty ? null : '${widget.folder}/',
        sortBy:     shuffle ? 'random' : 'title',
        seed:       shuffle
            ? DateTime.now().microsecondsSinceEpoch.toString()
            : null,
        limit:      count ?? _queueMax,
      );
      if (!mounted) return;
      if (songs.isNotEmpty) await onPlay(context, songs);
    } catch (e) {
      if (mounted) {
        AppSnack.show(context, context.l10n.browsePlaybackError('$e'));
      }
    } finally {
      if (mounted) setState(() => _queueBusy = false);
    }
  }

  void _openDir(FolderEntry d) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CollectionFolderScreen(
        collection:  widget.collection,
        title:       _displayName(d.name),
        folder:      d.dirPath,
        onTap:       widget.onTap,
        onPlayAlbum: widget.onPlayAlbum,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          ViewModePicker(
            mode: _viewMode,
            onChanged: (v) {
              setState(() => _viewMode = v);
              UserSettings.instance.albumViewMode = v;
            },
          ),
          // jw_* collections are also album-grain server-side (search_albums
          // carries their artwork) → offer the album/artwork browse as an
          // alternative to the folder tree, from the root only.
          if (widget.folder.isEmpty && widget.collection.startsWith('jw_'))
            IconButton(
              icon: const Icon(Icons.folder_special_outlined),
              tooltip: l10n.browseByAlbums,
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CollectionAlbumsScreen(
                    collection:  widget.collection,
                    title:       widget.title,
                    onTap:       widget.onTap,
                    onPlayAlbum: widget.onPlayAlbum,
                  ),
                ));
              },
            ),
          // Même famille que partout: Tout lire / Radio / Surprise sur le
          // SOUS-ARBRE (path_prefix). Radio = le sous-arbre mélangé, surprise
          // = un morceau au hasard dedans. Offert aussi à la RACINE: la liste
          // des dossiers est un angle du navigateur, pas une page d'accueil.
          if (widget.onPlayAlbum != null) ...[
            if (_queueBusy)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Center(
                    child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: RadioSurpriseButtons(
                  onPlayAll: () => _playSubtree(shuffle: false),
                  onRadio: () => _playSubtree(shuffle: true),
                  onSurprise: () => _playSubtree(shuffle: true, count: 1),
                  dense: true,
                ),
              ),
          ],
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CancelField(
              controller: _filterCtrl,
              onCleared: _onFilterChanged,
              builder: (_) => TextField(
                controller: _filterCtrl,
                decoration: InputDecoration(
                  hintText: _recursive
                      ? l10n.browseSearchInFolder
                      : l10n.browseFilterThisList,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: _onFilterChanged,
              ),
            ),
          ),
          // The two filter scopes are a real distinction (this list vs the whole
          // subtree, folders vs songs only) — spell it out rather than let the
          // field silently do the second one.
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => _setRecursive(!_recursive),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _recursive,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) => _setRecursive(v ?? false),
                    ),
                    const SizedBox(width: 4),
                    Text(l10n.browseSearchSubfolders,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
          if (widget.folder.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _displayName(widget.folder).replaceAll('/', ' › '),
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          Expanded(child: _buildBody(cs)),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    final dirs  = _visibleDirs;
    final songs = _visibleSongs;
    final count = dirs.length + songs.length;
    if (count == 0) {
      final l10n = context.l10n;
      return Center(
          child: Text((_query != null || _filter.isNotEmpty)
              ? l10n.searchNoResults
              : l10n.browseEmptyFolder));
    }
    if (_viewMode != 'list') return _buildGrid(cs, dirs, songs);
    return ListView.builder(
      controller: _scroll,
      itemCount: count + (_hasMore || _loadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= count) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (i < dirs.length) {
          final d = dirs[i];
          return ListTile(
            leading: Icon(Icons.folder, color: cs.primary),
            title: ScrollingText(text: _displayName(d.name)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${d.songCount}',
                    style: Theme.of(ctx).textTheme.bodySmall),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _openDir(d),
          );
        }
        return SongTile(
            result:      songs[i - dirs.length],
            onTap:       widget.onTap,
            onPlayAlbum: widget.onPlayAlbum);
      },
    );
  }

  /// Artwork grid over the SAME dirs+songs list: folders render as cover-sized
  /// folder cards, files as SongTile's grid cell (identical tap routing).
  Widget _buildGrid(
      ColorScheme cs, List<FolderEntry> dirs, List<SearchResult> songs) {
    final count = dirs.length + songs.length;
    final small = _viewMode == 'grid_small';
    return GridView.builder(
      controller: _scroll,
      padding: shellInset(context, const EdgeInsets.fromLTRB(12, 4, 12, 12)),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: small ? 120 : 190,
        mainAxisSpacing:    small ? 8 : 12,
        crossAxisSpacing:   small ? 8 : 12,
        childAspectRatio:   small ? 0.80 : 0.72,
      ),
      itemCount: count + (_hasMore || _loadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= count) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
          return const Center(
            child: SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (i < dirs.length) {
          final d = dirs[i];
          return _FolderGridTile(
            name:  _displayName(d.name),
            count: d.songCount,
            small: small,
            cs:    cs,
            onTap: () => _openDir(d),
          );
        }
        return SongTile(
          result:      songs[i - dirs.length],
          onTap:       widget.onTap,
          onPlayAlbum: widget.onPlayAlbum,
          grid:        true,
          small:       small,
        );
      },
    );
  }
}

/// Folder cell of the browse grid — matches the song/album cells' geometry so
/// mixed folders (dirs + files) line up.
class _FolderGridTile extends StatelessWidget {
  final String       name;
  final int          count;
  final bool         small;
  final ColorScheme  cs;
  final VoidCallback onTap;

  const _FolderGridTile({
    required this.name,
    required this.count,
    required this.small,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return HoverGrow(child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(Icons.folder,
                    size: small ? 32 : 48, color: cs.primary),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: small ? theme.bodySmall : theme.bodyMedium),
          if (!small)
            Text(context.l10n.browseTracksCount(count),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySmall?.copyWith(color: cs.outline)),
        ],
      ),
    ));
  }
}

// ---------------------------------------------------------------------------
// CollectionAlbumsScreen — album-grain collections (vgmrips, snesmusic,
// smspower): browse the whole catalogue as albums via search_albums with an
// empty q (alphabetical), search field on top. Tap → AlbumDetailScreen;
// ▶ → playAlbumFromList (handles zip-only albums: RSN, smspower packs).
// ---------------------------------------------------------------------------

class CollectionAlbumsScreen extends StatefulWidget {
  /// Slug de collection, ou null = tout le catalogue (la carte Albums du
  /// facet browser). `search_albums` sans `collection_slug` parcourt tout;
  /// chaque ligne porte SA collection, et `_openAlbum` route déjà par elle.
  final String? collection;
  final String title;

  /// Axe PLATEFORME, optionnel. `search_albums` accepte `platform_name`
  /// depuis toujours; c'est le client qui n'avait aucun chemin pour le lui
  /// demander — la destination d'une plateforme n'appelait que `browse_music`,
  /// donc ne montrait que des morceaux.
  final String? platform;

  /// Axe TAG (développeur, éditeur, chip, année…), même contrat que
  /// `BrowseResultsScreen`: c'est ce qui fait l'onglet Albums d'une valeur du
  /// facet browser.
  final List<String> tags;
  final List<String>? tagCategories;

  /// Embarqué dans un onglet (pas de Scaffold/AppBar à soi): le sélecteur de
  /// disposition rejoint alors la ligne du champ de recherche.
  final bool embedded;

  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnPlayAlbum? onPlayAlbum;

  const CollectionAlbumsScreen({
    super.key,
    required this.collection,
    required this.title,
    this.platform,
    this.tags = const [],
    this.tagCategories,
    this.embedded = false,
    required this.onTap,
    this.onPlayAlbum,
  });

  @override
  State<CollectionAlbumsScreen> createState() => _CollectionAlbumsScreenState();
}

class _CollectionAlbumsScreenState extends State<CollectionAlbumsScreen> {
  final _scroll     = ScrollController();
  final _filterCtrl = TextEditingController();
  Timer? _debounce;

  final _albums = <ArtistAlbum>[];
  String _query       = '';
  int    _total       = -1;
  bool   _hasMore     = false;
  bool   _loading     = true;
  bool   _loadingMore = false;
  String? _error;
  int    _reqId = 0;

  // Filtres proposés quand l'axe n'est pas déjà FIXÉ par l'appelant: la carte
  // Albums du facet browser ouvre le catalogue entier, sans plateforme ni
  // collection — c'est là qu'ils servent. Un écran arrivé depuis un hub de
  // collection ne montre pas le filtre collection (l'écran EST la collection),
  // même règle pour la plateforme.
  String? _selPlatform;
  String? _selCollection;

  /// Valeurs réelles, comptées en ALBUMS (`search_facets` au grain album).
  List<FacetCount> _platFacets = const [];
  List<FacetCount> _collFacets = const [];

  // 'list' | 'grid' | 'grid_small' — shared across all album-browse screens.
  String _viewMode = UserSettings.instance.albumViewMode;

  static const _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
    _loadFacets();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _filterCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFacets() async {
    // Rien à proposer si les deux axes sont déjà fixés par l'appelant.
    if (widget.platform != null && widget.collection != null) return;
    try {
      // Grain ALBUM (migration 229): les comptes sont en albums, et les
      // valeurs à zéro ne sortent pas — C64 (64 697 morceaux, zéro album)
      // n'est plus dans la liste du tout, au lieu d'y figurer morte. Scopé aux
      // MÊMES critères que la liste (tags compris), donc les valeurs proposées
      // sont celles qui existent vraiment sous ce tag.
      final all = await RewampDb.searchFacets('',
          grain:         'album',
          collection:    widget.collection,
          tags:          _tags,
          tagCategories: widget.tagCategories);
      if (!mounted) return;
      // Tri par VOLUME, redevenu pertinent maintenant que l'unité est la bonne.
      List<FacetCount> of(String kind) =>
          (all.where((f) => f.kind == kind && f.value.isNotEmpty).toList()
            ..sort((a, b) => b.count.compareTo(a.count)));
      setState(() {
        _platFacets = of('platform');
        _collFacets = of('collection');
      });
    } catch (_) {/* pas de filtres, l'écran reste utilisable */}
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _onFilterChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _query = text.trim();
      _load();
    });
  }

  /// Puce choisie sur l'axe de la collection (null = toutes) — voir
  /// collection_chip_axis.dart. ⚠️ Cet écran est AUSSI l'onglet Albums de
  /// BrowseResultsScreen, qui filtre déjà par la puce et passe le tag dans
  /// `widget.tags`: la rangée n'apparaît donc que pour la carte Albums d'un
  /// hub de collection (`embedded == false`), jamais deux fois.
  String? _chipTag;
  List<String> get _tags =>
      _chipTag == null ? widget.tags : [...widget.tags, _chipTag!];

  Future<List<ArtistAlbum>> _fetch(int offset) => RewampDb.searchAlbums(
        _query,
        collection:    widget.collection ?? _selCollection,
        platform:      widget.platform ?? _selPlatform,
        tags:          _tags,
        tagCategories: widget.tagCategories,
        // Empty q: relevance is meaningless → stable alphabetical browse.
        sortBy:  _query.isEmpty ? 'name' : 'relevance',
        sortDir: _query.isEmpty ? 'asc' : null,
        limit:   _pageSize,
        offset:  offset,
      );

  /// Change de puce: la liste ET les facettes (plateforme/format) sont
  /// refaites — les valeurs proposées doivent être celles qui existent sous la
  /// puce choisie, pas sous la collection entière.
  void _onChipAxis(String? tag) {
    if (_chipTag == tag) return;
    setState(() => _chipTag = tag);
    _load();
    _loadFacets();
  }

  Future<void> _load() async {
    final id = ++_reqId;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _fetch(0);
      if (!mounted || id != _reqId) return;
      setState(() {
        _albums ..clear()..addAll(res);
        _total   = res.isEmpty ? 0 : res.first.totalCount;
        _hasMore = res.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    final id = _reqId;
    try {
      final more = await _fetch(_albums.length);
      if (!mounted || id != _reqId) return;
      setState(() {
        _albums.addAll(more);
        _hasMore = more.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openAlbum(ArtistAlbum a) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AlbumDetailScreen(
        albumName:      a.name,
        albumId:        a.albumId,
        platformName:   a.platform,
        collectionSlug: a.collection,
        artworkUrl:     a.artworkUrl,
        onTap:          widget.onTap,
        onPlayAlbum:    widget.onPlayAlbum,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final picker = ViewModePicker(
      mode: _viewMode,
      onChanged: (v) {
        setState(() => _viewMode = v);
        UserSettings.instance.albumViewMode = v;
      },
    );
    // Axe de PUCE (General MIDI / MT-32 sur `midi`). Pas quand l'écran est
    // EMBARQUÉ: il est alors l'onglet Albums d'un écran qui porte déjà la
    // rangée, et son filtre arrive par widget.tags.
    final chipAxis = widget.embedded ? const <String>[] : chipAxisFor(widget.collection);
    final content = Column(
      children: [
        if (chipAxis.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(context.l10n.searchCollectionAll),
                  selected: _chipTag == null,
                  onSelected: (_) => _onChipAxis(null),
                ),
                for (final tag in chipAxis)
                  ChoiceChip(
                    label: Text(tag),
                    selected: _chipTag == tag,
                    onSelected: (_) => _onChipAxis(tag),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(children: [
            Expanded(
              child: CancelField(
                controller: _filterCtrl,
                onCleared: _onFilterChanged,
                builder: (_) => TextField(
                  controller: _filterCtrl,
                  decoration: InputDecoration(
                    hintText: context.l10n.browseSearchAlbum,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _onFilterChanged,
                ),
              ),
            ),
            // Embarqué: pas d'AppBar à soi, le sélecteur de disposition
            // rejoint la ligne du champ.
            if (widget.embedded) picker,
          ]),
        ),
        _buildFilterBar(),
        Expanded(child: _buildBody()),
      ],
    );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [picker]),
      body: content,
    );
  }

  /// Puces Plateforme / Collection, seulement pour les axes que l'appelant n'a
  /// pas déjà fixés. Même forme que la barre de facettes de la recherche
  /// (puce → feuille de choix), en plus simple: valeurs triées par volume,
  /// « Toutes » en tête pour effacer.
  Widget _buildFilterBar() {
    final l10n = context.l10n;
    final showPlat = widget.platform == null && _platFacets.isNotEmpty;
    final showColl = widget.collection == null && _collFacets.isNotEmpty;
    if (!showPlat && !showColl) return const SizedBox.shrink();

    Widget chip(String label, String? current, List<FacetCount> values,
        void Function(String?) onPick) {
      final selected = current != null;
      final cs = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ActionChip(
          avatar: Icon(selected ? Icons.check : Icons.expand_more, size: 14),
          label: Text(selected ? current : label,
              style: const TextStyle(fontSize: 11)),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: selected ? cs.secondaryContainer : null,
          // La MÊME feuille que la barre de facettes de la recherche
          // (facet_picker_sheet.dart): titre, champ de recherche en tête,
          // « Tous », coche sur la valeur active. Les comptes sont affichés:
          // ils sont en ALBUMS depuis que les facettes sont demandées au grain
          // album, donc dans l'unité de l'écran.
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (ctx) => FacetPickerSheet(
              label:      label,
              values:     values,
              selected:   current,
              onPick: (v) {
                Navigator.of(ctx).pop();
                onPick(v);
              },
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(children: [
        if (showPlat)
          chip(l10n.searchPlatform, _selPlatform, _platFacets,
              (v) { setState(() => _selPlatform = v); _load(); }),
        if (showColl)
          chip(l10n.filterCollection, _selCollection, _collFacets,
              (v) { setState(() => _selCollection = v); _load(); }),
      ]),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_albums.isEmpty) {
      return Center(
          child: Text(
              _query.isNotEmpty ? l10n.searchNoResults : l10n.browseNoAlbum));
    }
    return Column(
      children: [
        Builder(builder: (ctx) {
          // Les entrées sont des ALBUMS: elles se déplient en pistes. Un album
          // CONTENEUR (archive joshw sans détail serveur) reste UNE entrée —
          // jeté, il faisait démarrer la lecture à l'album SUIVANT.
          final a = entityPlayActions<ArtistAlbum>(
            ctx,
            _albums,
            (al) => RewampDb.browse(
                albumName: al.name,
                collection: al.collection,
                platform: al.platform,
                sortBy: 'position',
                limit: 500),
            onPlayAlbum: widget.onPlayAlbum,
          );
          return _BrowseCountBar(
              loaded: _albums.length,
              total: _total > 0 ? _total : 0,
              loading: _loadingMore,
              kind: _CountKind.albums,
              onPlayAll: a.playAll,
              onRadio: a.radio,
              onSurprise: a.surprise);
        }),
        Expanded(
          child: _viewMode == 'list' ? _buildList() : _buildGrid(),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.builder(
      controller: _scroll,
      itemCount: _albums.length + (_hasMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= _albums.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final a = _albums[i];
        return ListTile(
          // Même vignette que la GRILLE de cet écran (RailArtwork): un
          // `placeholder:` explicite écrase le placeholder thématisé par
          // plateforme, et le même album montrait une icône générique en liste
          // et sa vraie pochette d'origine en grille.
          leading: RailArtwork(
            url:          a.artworkUrl,
            album:        a.name,
            artist:       a.artistNames.firstOrNull,
            formatHint:   a.format,
            platformName: a.platform,
            size:         48,
          ),
          title: Text(a.name,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          // Même règle que SongTile: la COLLECTION dit d'où vient l'album, pas
          // ce qu'il est — sa propre ligne, en petit, et seulement quand cet
          // écran parcourt TOUT le catalogue (la carte « Albums »).
          isThreeLine: widget.collection == null,
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _albumSubtitle(a),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.collection == null)
                Text(
                  RewampDb.collectionLabel(a.collection),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onPlayAlbum != null)
                _TilePlayButton(onPlay: () => _playAlbum(ctx, a)),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => _openAlbum(a),
        );
      },
    );
  }

  Widget _buildGrid() {
    final small = _viewMode == 'grid_small';
    return GridView.builder(
      controller: _scroll,
      padding: shellInset(context, const EdgeInsets.fromLTRB(12, 4, 12, 12)),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: small ? 120 : 190,
        mainAxisSpacing:    small ? 8 : 12,
        crossAxisSpacing:   small ? 8 : 12,
        childAspectRatio:   small ? 0.80 : 0.72,
      ),
      itemCount: _albums.length + (_hasMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= _albums.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
          return const Center(
            child: SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return _AlbumGridTile(
          showCollection: widget.collection == null,
          album:  _albums[i],
          small:  small,
          onTap:  () => _openAlbum(_albums[i]),
          onPlay: widget.onPlayAlbum == null
              ? null
              : () => _playAlbum(ctx, _albums[i]),
        );
      },
    );
  }

  String _albumSubtitle(ArtistAlbum a) => [
        if (a.platform != null && a.platform!.isNotEmpty) a.platform!,
        context.l10n.browseTracksCount(a.songCount),
        if (a.artistNames.isNotEmpty) a.artistNames.join(' · '),
        // Album-grain scores — parsed by name, light up when the listing
        // RPCs ship the columns (207/208 rules: rank shown top-of-basket
        // only, clamped).
        if (a.rating != null) '★ ${a.rating!.toStringAsFixed(1)}',
        if ((a.popularity ?? 0) >= 95)
          context.l10n.statsTopPercent((100 - a.popularity!).clamp(1, 100)),
      ].join(' · ');

  Future<void> _playAlbum(BuildContext ctx, ArtistAlbum a) =>
      playAlbumFromList(
        ctx,
        a.name,
        collection:  a.collection,
        platform:    a.platform,
        onPlayAlbum: widget.onPlayAlbum!,
      );
}

// One album cell of the artwork grid (large or compact): square-ish cover on
// top, name (+ platform/count when large) below, ▶ overlay bottom-right.
class _AlbumGridTile extends StatelessWidget {
  final ArtistAlbum album;
  final bool small;
  /// Voir la liste de cet écran: la collection ne s'affiche que sur le
  /// parcours TOUT-catalogue.
  final bool showCollection;
  final VoidCallback onTap;
  final Future<void> Function()? onPlay;

  const _AlbumGridTile({
    required this.album,
    required this.small,
    this.showCollection = false,
    required this.onTap,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    return HoverGrow(child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ArtworkImage(
                  url:          album.artworkUrl,
                  album:        album.name,
                  borderRadius: BorderRadius.circular(8),
                  placeholder: Container(
                    color: cs.surfaceContainerHighest,
                    child: Icon(Icons.album,
                        size: small ? 28 : 44, color: cs.outline),
                  ),
                ),
                if (onPlay != null)
                  Positioned(
                    right: 4, bottom: 4,
                    child: _GridPlayOverlay(onPlay: onPlay!),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: small ? theme.bodySmall : theme.bodyMedium,
          ),
          if (!small)
            Text(
              [
                // En GRILLE la hauteur de cellule est FIXE (childAspectRatio):
                // pas de troisième ligne possible, la collection rejoint la
                // ligne existante — la liste, elle, a sa ligne dédiée.
                if (showCollection)
                  RewampDb.collectionLabel(album.collection),
                if (album.platform != null && album.platform!.isNotEmpty)
                  album.platform!,
                context.l10n.browseTracksCount(album.songCount),
                if (album.rating != null)
                  '★ ${album.rating!.toStringAsFixed(1)}',
                if ((album.popularity ?? 0) >= 95)
                  context.l10n.statsTopPercent(
                      (100 - album.popularity!).clamp(1, 100)),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodySmall?.copyWith(color: cs.outline),
            ),
        ],
      ),
    ));
  }
}

// Small ▶ button drawn over the grid tile's artwork (scrimmed circle so it
// stays visible on any cover).
class _GridPlayOverlay extends StatefulWidget {
  final Future<void> Function() onPlay;
  const _GridPlayOverlay({required this.onPlay});

  @override
  State<_GridPlayOverlay> createState() => _GridPlayOverlayState();
}

class _GridPlayOverlayState extends State<_GridPlayOverlay> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _busy
            ? null
            : () async {
                final messenger = ScaffoldMessenger.of(context);
                final l10n = context.l10n;
                setState(() => _busy = true);
                try {
                  await widget.onPlay();
                } catch (e) {
                  AppSnack.showOn(messenger, l10n.browsePlaybackError('$e'));
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: _busy
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.play_arrow, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CollectionArtistsScreen — artist-grain collections (zxart, sceneorg): no
// folder tree, no albums — browse the catalogue by artist via search_artists
// with an empty q (alphabetical). Tap → ArtistResultsScreen scoped to the
// collection.
// ---------------------------------------------------------------------------

class CollectionArtistsScreen extends StatefulWidget {
  final String collection; // slug
  final String title;
  /// Full country name from `CollectionOverview.countries[]` — narrows the
  /// list to that country's artists (hub Pays card, mig 213).
  final String? country;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnPlayAlbum? onPlayAlbum;

  const CollectionArtistsScreen({
    super.key,
    required this.collection,
    required this.title,
    this.country,
    required this.onTap,
    this.onPlayAlbum,
  });

  @override
  State<CollectionArtistsScreen> createState() =>
      _CollectionArtistsScreenState();
}

class _CollectionArtistsScreenState extends State<CollectionArtistsScreen> {
  final _scroll     = ScrollController();
  final _filterCtrl = TextEditingController();
  Timer? _debounce;

  final _artists = <ArtistResult>[];
  String _query       = '';
  int    _total       = -1;
  bool   _hasMore     = false;
  bool   _loading     = true;
  bool   _loadingMore = false;
  String? _error;
  int    _reqId = 0;

  static const _pageSize = 100;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _filterCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _onFilterChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _query = text.trim();
      _load();
    });
  }

  Future<List<ArtistResult>> _fetch(int offset) => RewampDb.searchArtists(
        _query,
        collection: widget.collection,
        country: widget.country,
        sortBy:  _query.isEmpty ? 'name' : 'relevance',
        sortDir: _query.isEmpty ? 'asc' : null,
        limit:   _pageSize,
        offset:  offset,
      );

  Future<void> _load() async {
    final id = ++_reqId;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _fetch(0);
      if (!mounted || id != _reqId) return;
      setState(() {
        _artists ..clear()..addAll(res);
        _total   = res.isEmpty ? 0 : res.first.totalCount;
        _hasMore = res.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    final id = _reqId;
    try {
      final more = await _fetch(_artists.length);
      if (!mounted || id != _reqId) return;
      setState(() {
        _artists.addAll(more);
        _hasMore = more.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.country != null
              ? '${widget.title} · ${widget.country}'
              : widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: CancelField(
              controller: _filterCtrl,
              onCleared: _onFilterChanged,
              builder: (_) => TextField(
                controller: _filterCtrl,
                decoration: InputDecoration(
                  hintText: context.l10n.browseSearchArtist,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: _onFilterChanged,
              ),
            ),
          ),
          Expanded(child: _buildBody(cs)),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_artists.isEmpty) {
      return Center(
          child: Text(
              _query.isNotEmpty ? l10n.searchNoResults : l10n.browseNoArtist));
    }
    return Column(
      children: [
        Builder(builder: (ctx) {
          // Les entrées sont des ARTISTES: chacune se déplie en ses morceaux
          // DANS cette collection (l'écran a été atteint par elle).
          final a = entityPlayActions<ArtistResult>(
            ctx,
            _artists,
            (ar) => RewampDb.browse(
                collection: widget.collection,
                artistId: ar.artistId.isEmpty ? null : ar.artistId,
                artistName: ar.artistId.isEmpty ? ar.name : null,
                sortBy: 'name',
                limit: 200),
            onPlayAlbum: widget.onPlayAlbum,
          );
          return _BrowseCountBar(
              loaded: _artists.length,
              total: _total > 0 ? _total : 0,
              loading: _loadingMore,
              kind: _CountKind.artists,
              onPlayAll: a.playAll,
              onRadio: a.radio,
              onSurprise: a.surprise);
        }),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            itemCount: _artists.length + (_hasMore ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i >= _artists.length) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _loadMore());
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final a = _artists[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer),
                  ),
                ),
                title: Text(a.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                // Real name / country tell homonym artists apart in the list.
                subtitle: (a.realName != null && a.realName!.isNotEmpty &&
                            a.realName != a.name) ||
                        (a.country != null && a.country!.isNotEmpty)
                    ? Text(
                        [
                          if (a.realName != null && a.realName!.isNotEmpty &&
                              a.realName != a.name) a.realName!,
                          if (a.country != null && a.country!.isNotEmpty)
                            a.country!,
                        ].join(' · '),
                        maxLines: 1, overflow: TextOverflow.ellipsis)
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${a.songCount}',
                        style: Theme.of(ctx).textTheme.bodySmall),
                    // Save-artist heart — uuid as refId when known (names
                    // collide; the artist screen's own heart does the same).
                    LibraryButton(
                      type:  'artist',
                      refId: a.artistId.isNotEmpty ? a.artistId : a.name,
                      name:  a.name,
                      collectionSlug: widget.collection,
                      iconSize: 20,
                      padding: const EdgeInsets.all(4),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ArtistResultsScreen(
                    artistName:  a.name,
                    artistId:    a.artistId,
                    collection:  widget.collection,
                    onTap:       widget.onTap,
                    onPlayAlbum: widget.onPlayAlbum,
                  ),
                )),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Play button with a per-tile busy spinner (album rows: the track list /
/// zip fetch takes a moment).
class _TilePlayButton extends StatefulWidget {
  final Future<void> Function() onPlay;
  const _TilePlayButton({required this.onPlay});

  @override
  State<_TilePlayButton> createState() => _TilePlayButtonState();
}

class _TilePlayButtonState extends State<_TilePlayButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const SizedBox(
        width: 36, height: 36,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final l10n = context.l10n;
    return IconButton(
      icon: const Icon(Icons.play_circle_outline, size: 22),
      tooltip: l10n.browsePlayAlbum,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        setState(() => _busy = true);
        try {
          await widget.onPlay();
        } catch (e) {
          AppSnack.showOn(messenger, l10n.browsePlaybackError('$e'));
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// CollectionHubScreen — data-driven landing of a structureless collection
// (amp first). One get_collection_overview call decides the cards: an axis
// with a zero count simply has no card, so nothing here is hardcoded per
// slug. Top sections come from the most_popular RPCs scoped to the
// collection. Overview unreachable → the all-songs entry still works.
// ---------------------------------------------------------------------------

class CollectionHubScreen extends StatefulWidget {
  final String collection; // slug
  final String title;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnPlayAlbum? onPlayAlbum;

  const CollectionHubScreen({
    super.key,
    required this.collection,
    required this.title,
    required this.onTap,
    this.onPlayAlbum,
  });

  @override
  State<CollectionHubScreen> createState() => _CollectionHubScreenState();
}

class _CollectionHubScreenState extends State<CollectionHubScreen> {
  CollectionOverview? _overview;
  bool _loadingOverview = true;
  List<SearchResult>  _topSongs   = const [];
  List<PopularArtist> _topArtists = const [];

  @override
  void initState() {
    super.initState();
    RewampDb.getCollectionOverview(widget.collection).then((o) {
      if (mounted) setState(() { _overview = o; _loadingOverview = false; });
    });
    // Play counts are tiny in beta: 'all' keeps the sections alive; both rails
    // vanish quietly when empty.
    //
    // Stats rows carry NO artist_names and NO download_url. Resolve them
    // through get_song_context AT FETCH TIME, not at tap: the derived cache
    // path uses artistNames.first (else 'unknown'), so playing a raw stats
    // row re-downloaded the file under online/<coll>/unknown/… — a duplicate
    // copy AND a duplicate recents entry (recents dedups by file_path).
    // Resolving here also feeds the row's "…" menu and queue-adds correctly.
    RewampDb.mostPopularSongs(
            period: 'all', n: 5, collectionSlug: widget.collection)
        .then((s) async {
          final resolved = await Future.wait(s
              // Album-aggregate rows (item_type='album', mig 107) need the
              // album routing the home rail has; this rail is tracks-only.
              .where((r) => !r.isAlbumRow)
              .map((r) async {
            if (r.downloadUrl != null && r.downloadUrl!.isNotEmpty) return r;
            try {
              final c = await RewampDb.getSongContext(r.songId);
              if (c == null) return r;
              return r.subsongIdx != 0
                  ? c.song.withSubsong(r.subsongIdx)
                  : c.song;
            } catch (_) {
              return r;
            }
          }));
          if (mounted) setState(() => _topSongs = resolved);
        })
        .catchError((_) => null);
    RewampDb.mostPopularArtists(
            period: 'all', n: 12, collectionSlug: widget.collection)
        .then((a) { if (mounted) setState(() => _topArtists = a); });
  }

  // 📻 endless random queue over the whole collection (same recipe as the
  // search landing's radio: one random page, played as an album).
  Future<void> _startRadio() async {
    final seed = DateTime.now().millisecondsSinceEpoch.toString();
    try {
      final songs = await RewampDb.browse(
          collection: widget.collection,
          sortBy: 'random', seed: seed, limit: 50);
      if (!mounted || songs.isEmpty) return;
      if (widget.onPlayAlbum != null) {
        await widget.onPlayAlbum!(context, songs);
      } else {
        await widget.onTap(context, songs.first);
      }
    } catch (_) {}
  }

  // 🎲 one random song of the collection.
  Future<void> _surpriseMe() async {
    final seed = '${DateTime.now().microsecondsSinceEpoch}';
    try {
      final songs = await RewampDb.browse(
          collection: widget.collection,
          sortBy: 'random', seed: seed, limit: 1);
      if (!mounted || songs.isEmpty) return;
      await widget.onTap(context, songs.first);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;
    final o    = _overview;

    Widget card({
      required IconData icon,
      required String title,
      String? subtitle,
      required VoidCallback onTap,
    }) =>
        ListTile(
          leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Icon(icon, color: cs.onPrimaryContainer, size: 20),
          ),
          title: ScrollingText(text: title),
          subtitle: subtitle != null
              ? Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis)
              : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        );

    // The collection's STRUCTURAL entry comes first — it is what the old
    // direct landing was (folder tree / album list), so hub users find it
    // where their reflex expects it.
    final isFolderTree = collectionHasFolderTree(widget.collection);
    final isAlbumGrain = collectionIsAlbumGrain(widget.collection);

    final foldersCard = isFolderTree
        ? card(
            icon: Icons.folder_outlined,
            title: l10n.browseFoldersCard,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CollectionFolderScreen(
                collection:  widget.collection,
                title:       widget.title,
                onTap:       widget.onTap,
                onPlayAlbum: widget.onPlayAlbum,
              ),
            )),
          )
        : null;
    final albumsCard = (o != null && o.albumCount > 0)
        ? card(
            icon: Icons.album_outlined,
            title: l10n.tabAlbums,
            subtitle: l10n.browseLoadedAlbums(o.albumCount),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CollectionAlbumsScreen(
                collection:  widget.collection,
                title:       widget.title,
                onTap:       widget.onTap,
                onPlayAlbum: widget.onPlayAlbum,
              ),
            )),
          )
        : null;

    final children = <Widget>[
      // Header: size of the collection + radio/surprise on the whole of it.
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                o != null ? l10n.searchSongsCount(o.songCount) : '',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            RadioSurpriseButtons(
                onRadio: _startRadio, onSurprise: _surpriseMe),
          ],
        ),
      ),
      if (_loadingOverview)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (foldersCard != null) foldersCard,
      if (isAlbumGrain && albumsCard != null) albumsCard,
      if (o != null && o.artistCount > 0)
        card(
          icon: Icons.person_outline,
          title: l10n.tabArtists,
          subtitle: l10n.browseLoadedArtists(o.artistCount),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CollectionArtistsScreen(
              collection:  widget.collection,
              title:       widget.title,
              onTap:       widget.onTap,
              onPlayAlbum: widget.onPlayAlbum,
            ),
          )),
        ),
      if (o != null && o.groupCount > 0)
        card(
          icon: Icons.groups_outlined,
          title: l10n.searchCategoryGroup,
          subtitle: l10n.browseGroupsCount(o.groupCount),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CollectionGroupsScreen(
              collection:  widget.collection,
              title:       widget.title,
              onTap:       widget.onTap,
              onPlayAlbum: widget.onPlayAlbum,
            ),
          )),
        ),
      if (!isAlbumGrain && albumsCard != null) albumsCard,
      if (o != null && o.countries.isNotEmpty)
        card(
          icon: Icons.public,
          title: l10n.browseCountries,
          subtitle: l10n.browseCountriesCount(o.countries.length),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _CollectionCountriesScreen(
              collection:  widget.collection,
              title:       widget.title,
              countries:   o.countries,
              onTap:       widget.onTap,
              onPlayAlbum: widget.onPlayAlbum,
            ),
          )),
        ),
      // A single format is data, not navigation: filtering on it would show
      // the whole collection again (every album-grain collection is like
      // that — vgm-only, spc-only…).
      if (o != null && o.formats.length > 1)
        card(
          icon: Icons.audio_file_outlined,
          title: l10n.browseByFormat,
          subtitle: o.formats
              .take(6)
              .map((f) => f.ext.toUpperCase())
              .join(' · '),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _CollectionFormatsScreen(
              collection:  widget.collection,
              title:       widget.title,
              formats:     o.formats,
              onTap:       widget.onTap,
              onPlayAlbum: widget.onPlayAlbum,
            ),
          )),
        ),
      // Always reachable, even with the overview down — the old flat listing,
      // one card among the others instead of the whole experience.
      card(
        icon: Icons.list,
        title: l10n.browseAllSongs,
        subtitle: l10n.browseAllSongsSubtitleAlpha,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BrowseResultsScreen(
            label:       widget.title,
            collection:  widget.collection,
            showFilter:  true,
            onTap:       widget.onTap,
            onPlayAlbum: widget.onPlayAlbum,
          ),
        )),
      ),
      if (_topArtists.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(l10n.statsTopArtists,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in _topArtists)
                ActionChip(
                  label: Text(a.name),
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ArtistResultsScreen(
                      artistName:  a.name,
                      artistId:    a.artistId,
                      collection:  widget.collection,
                      onTap:       widget.onTap,
                      onPlayAlbum: widget.onPlayAlbum,
                    ),
                  )),
                ),
            ],
          ),
        ),
      ],
      if (_topSongs.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(l10n.statsTopTracks,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final s in _topSongs)
          SongTile(
            result: s,
            onTap: widget.onTap,
            onPlayAlbum: widget.onPlayAlbum,
            albumRowsAllowed: false,
          ),
      ],
    ];

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: shellInset(context, const EdgeInsets.only(bottom: 16)),
        children: children,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CollectionGroupsScreen — paged groups of one collection
// (list_collection_groups), song-count desc. Tap → the group ENTITY screen
// (members, productions, note), same as every other group chip in the app.
// ---------------------------------------------------------------------------

class CollectionGroupsScreen extends StatefulWidget {
  final String collection; // slug
  final String title;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnPlayAlbum? onPlayAlbum;

  const CollectionGroupsScreen({
    super.key,
    required this.collection,
    required this.title,
    required this.onTap,
    this.onPlayAlbum,
  });

  @override
  State<CollectionGroupsScreen> createState() => _CollectionGroupsScreenState();
}

class _CollectionGroupsScreenState extends State<CollectionGroupsScreen> {
  final _scroll     = ScrollController();
  final _filterCtrl = TextEditingController();
  Timer? _debounce;

  final _groups = <CollectionGroupRow>[];
  String _query       = '';
  bool   _hasMore     = false;
  bool   _loading     = true;
  bool   _loadingMore = false;
  String? _error;
  int    _reqId = 0;

  static const _pageSize = 100;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _filterCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _onFilterChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _query = text.trim();
      _load();
    });
  }

  Future<void> _load() async {
    final id = ++_reqId;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await RewampDb.listCollectionGroups(
          widget.collection,
          query: _query.isEmpty ? null : _query,
          limit: _pageSize);
      if (!mounted || id != _reqId) return;
      setState(() {
        _groups ..clear()..addAll(res);
        _hasMore = res.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    final id = _reqId;
    try {
      final more = await RewampDb.listCollectionGroups(
          widget.collection,
          query: _query.isEmpty ? null : _query,
          limit: _pageSize,
          offset: _groups.length);
      if (!mounted || id != _reqId) return;
      setState(() {
        _groups.addAll(more);
        _hasMore = more.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: Text('${widget.title} · ${l10n.searchCategoryGroup}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: CancelField(
              controller: _filterCtrl,
              onCleared: _onFilterChanged,
              builder: (_) => TextField(
                controller: _filterCtrl,
                decoration: InputDecoration(
                  hintText: l10n.browseFilterFacet(
                      l10n.searchCategoryGroup.toLowerCase()),
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: _onFilterChanged,
              ),
            ),
          ),
          Expanded(child: _buildBody(cs, l10n)),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, dynamic l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_groups.isEmpty) {
      return Center(child: Text(l10n.searchNoResults));
    }
    // Un GROUPE se déplie en ses morceaux DANS cette collection — même
    // requête que le tap d'une ligne (browse_music sur le tag 'group'), pas
    // une recherche texte qui ramènerait tout ce qui contient le nom.
    final actions = entityPlayActions<CollectionGroupRow>(
      context,
      _groups,
      (g) => RewampDb.browse(
          collection: widget.collection,
          tags: [g.name],
          tagCategories: const ['group'],
          sortBy: 'name',
          limit: 200),
      onPlayAlbum: widget.onPlayAlbum,
    );
    return Column(children: [
      _ActionsBar(
          onPlayAll: actions.playAll,
          onRadio: actions.radio,
          onSurprise: actions.surprise),
      Expanded(
        child: ListView.builder(
      controller: _scroll,
      itemCount: _groups.length + (_hasMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= _groups.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final g = _groups[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Icon(Icons.groups, color: cs.onPrimaryContainer, size: 20),
          ),
          title: ScrollingText(text: g.name),
          subtitle: Text(
            '${l10n.browseLoadedArtists(g.artistCount)} · '
            '${l10n.browseLoadedSongs(g.songCount)}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          // Row tap = the group's songs WITHIN this collection (the list was
          // reached from the collection hub — landing on the global group
          // entity dumped the group's whole output, most of it from other
          // collections). The entity screen (members, productions, note)
          // stays reachable via the trailing button.
          trailing: IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: g.name,
            onPressed: () => openGroup(context, g.name, tagId: g.tagId),
          ),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BrowseResultsScreen(
              label:         '${g.name} · ${widget.title}',
              collection:    widget.collection,
              tags:          [g.name],
              tagCategories: const ['group'],
              showFilter:    true,
              onTap:         widget.onTap,
              onPlayAlbum:   widget.onPlayAlbum,
            ),
          )),
        );
      },
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// _CollectionCountriesScreen — the overview's country census (artist counts),
// no extra fetch. Country NAMES stay as the server renders them ("Norway"):
// they are data, and they round-trip verbatim into search_artists p_country
// (mig 213 compares lower() on the full name, never a code).
// ---------------------------------------------------------------------------

class _CollectionCountriesScreen extends StatelessWidget {
  final String collection;
  final String title;
  final List<({String country, int artists})> countries;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnPlayAlbum? onPlayAlbum;

  const _CollectionCountriesScreen({
    required this.collection,
    required this.title,
    required this.countries,
    required this.onTap,
    this.onPlayAlbum,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('$title · ${l10n.browseCountries}')),
      body: Column(children: [
      // ⚠️ Un PAYS n'est pas une portée que `browse_music` sait filtrer:
      // `p_country` n'existe que sur `search_artists` (mig 213). Un pays se
      // déplie donc en DEUX temps — ses artistes, puis leurs morceaux — d'où
      // des plafonds serrés (5 artistes × 50 morceaux): c'est un lancement,
      // pas un inventaire du pays.
      Builder(builder: (ctx) {
        final a = entityPlayActions<({String country, int artists})>(
          ctx,
          countries,
          (c) async {
            final artists = await RewampDb.searchArtists('',
                collection: collection, country: c.country, limit: 5);
            if (artists.isEmpty) return const <SearchResult>[];
            final lists = await Future.wait([
              for (final ar in artists)
                RewampDb.browse(
                        collection: collection,
                        artistId: ar.artistId.isEmpty ? null : ar.artistId,
                        artistName: ar.artistId.isEmpty ? ar.name : null,
                        sortBy: 'name',
                        limit: 50)
                    .catchError((_) => const <SearchResult>[]),
            ]);
            return [for (final l in lists) ...l];
          },
          onPlayAlbum: onPlayAlbum,
          maxExpand: 5,
        );
        return _ActionsBar(
            onPlayAll: countries.isEmpty ? null : a.playAll,
            onRadio: countries.isEmpty ? null : a.radio,
            onSurprise: countries.isEmpty ? null : a.surprise);
      }),
      Expanded(
        child: ListView.builder(
        itemCount: countries.length,
        itemBuilder: (_, i) {
          final c = countries[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Text(
                c.country.isNotEmpty ? c.country[0].toUpperCase() : '?',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer),
              ),
            ),
            title: Text(c.country,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(l10n.browseLoadedArtists(c.artists)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CollectionArtistsScreen(
                collection:  collection,
                title:       title,
                country:     c.country,
                onTap:       onTap,
                onPlayAlbum: onPlayAlbum,
              ),
            )),
          );
        },
        ),
      ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// _CollectionFormatsScreen — the overview's format census, no extra fetch.
// Tap → the collection filtered on that extension.
// ---------------------------------------------------------------------------

class _CollectionFormatsScreen extends StatefulWidget {
  final String collection;
  final String title;
  final List<({String ext, int count})> formats;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnPlayAlbum? onPlayAlbum;

  const _CollectionFormatsScreen({
    required this.collection,
    required this.title,
    required this.formats,
    required this.onTap,
    this.onPlayAlbum,
  });

  @override
  State<_CollectionFormatsScreen> createState() =>
      _CollectionFormatsScreenState();
}

class _CollectionFormatsScreenState extends State<_CollectionFormatsScreen> {
  // modland liste des CENTAINES de formats — sans filtre, en trouver un est
  // une lecture intégrale (demande utilisateur). Filtrage en mémoire: la
  // liste est déjà là, servie par get_collection_overview.
  final _filterCtrl = TextEditingController();

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;
    final q = _filterCtrl.text.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.formats
        : [for (final f in widget.formats) if (f.ext.toLowerCase().contains(q)) f];
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} · ${l10n.browseByFormat}')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: CancelField(
            controller: _filterCtrl,
            onCleared: (_) => setState(() {}),
            builder: (_) => TextField(
              controller: _filterCtrl,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: l10n.storageFilterHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        // Les actions portent sur ce qui est AFFICHÉ (liste filtrée): un
        // format se déplie par `browse_music` sur son extension.
        Builder(builder: (ctx) {
          final a = entityPlayActions<({String ext, int count})>(
            ctx,
            shown,
            (f) => RewampDb.browse(
                collection: widget.collection,
                formatFilter: f.ext,
                sortBy: 'name',
                limit: 200),
            onPlayAlbum: widget.onPlayAlbum,
          );
          return _ActionsBar(
              onPlayAll: shown.isEmpty ? null : a.playAll,
              onRadio: shown.isEmpty ? null : a.radio,
              onSurprise: shown.isEmpty ? null : a.surprise);
        }),
        Expanded(
            child: ListView.builder(
        itemCount: shown.length,
        itemBuilder: (_, i) {
          final f = shown[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Text(
                f.ext.length > 4
                    ? f.ext.substring(0, 4).toUpperCase()
                    : f.ext.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer),
              ),
            ),
            title: Text(f.ext.toUpperCase()),
            subtitle: Text(l10n.searchSongsCount(f.count)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BrowseResultsScreen(
                label:        '${widget.title} · ${f.ext.toUpperCase()}',
                collection:   widget.collection,
                formatFilter: f.ext,
                showFilter:   true,
                onTap:        widget.onTap,
                onPlayAlbum:  widget.onPlayAlbum,
              ),
            )),
          );
        },
      )),
      ]),
    );
  }
}
