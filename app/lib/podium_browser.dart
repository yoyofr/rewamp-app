// Navigateur « Podiums » — partir du classement en compo pour découvrir.
//
// Contrat: `docs/podium_browser_proposal.md`, fixé par la revue serveur
// `docs/podium_browser_server_review.md` (migs 283-289). Trois niveaux:
//
//   1. [PodiumHubScreen] — des ANGLES préconstruits avec leurs comptes
//      (vainqueurs récents, nature, genre de compo, époque, parties, artistes
//      les plus primés), parce que personne ne sait ce qu'est une « compo
//      exécutable » avant d'avoir vu la liste. Une seule requête de facettes
//      (`search_facets` avec p_podium = 0) alimente tout l'écran.
//   2. [PodiumListScreen] — la liste de morceaux au grain PODIUM: rang, nature,
//      genre, série de party, époque, puis plateforme et format du morceau.
//      Tri par défaut `podium` (année de compo ↓, rang ↑). Chaque puce se
//      compte SOUS les autres filtres (règle de search_facets).
//   3. Les destinations existantes — écran de compo, écran d'artiste,
//      playlist de compo — par le badge de chaque ligne. Rien de neuf.
//
// Deux règles héritées de la facette podium: le rang est le MEILLEUR du
// morceau (filtre et badge toujours d'accord, les trois rangs se somment) et
// chaque morceau compte UNE fois, pour ce meilleur podium (option 1 de la
// revue: 2,3 % de morceaux ont plusieurs podiums — à dire, pas à corriger).
// Détection de capacité par 404 (`RewampDb.serverLacks`): sans les critères
// de la mig 285 les puces de dimension disparaissent et un critère posé est
// annoncé puis retiré — jamais une liste non filtrée présentée comme filtrée.

import 'dart:async';

import 'package:flutter/material.dart';

import 'app_snack.dart';
import 'artwork_image.dart';
import 'cancel_field.dart';
import 'competition_screen.dart' show podiumColor;
import 'facet_picker_sheet.dart';
import 'l10n.dart';
import 'podium_filter.dart';
import 'radio_surprise_buttons.dart';
import 'rewamp_db.dart';
import 'scrolling_text.dart';
import 'search_screen.dart' show ArtistResultsScreen;
import 'shell_insets.dart';
import 'song_tile.dart';
import 'track_options_sheet.dart' show globalOnPlayAlbum;

/// Le tap sur une ligne de morceau (le même rappel que partout ailleurs).
typedef PodiumOnTap = Future<void> Function(BuildContext, SearchResult);

/// Le serveur connaît-il les critères de podium (mig 285)? Faux après un 404
/// rejoué sans eux — toutes les puces de dimension se cachent alors d'un coup.
bool _dimsOnServer() => !PodiumCriteria.kParams.any(RewampDb.serverLacks);

// ---------------------------------------------------------------------------
// Niveau 1 — le hub
// ---------------------------------------------------------------------------

class PodiumHubScreen extends StatefulWidget {
  final PodiumOnTap onTap;
  final OnPlayAlbum? onPlayAlbum;

  const PodiumHubScreen({super.key, required this.onTap, this.onPlayAlbum});

  @override
  State<PodiumHubScreen> createState() => _PodiumHubScreenState();
}

class _PodiumHubScreenState extends State<PodiumHubScreen> {
  List<FacetCount> _facets = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    RewampDb.serverLacksChanged.addListener(_onCaps);
  }

  @override
  void dispose() {
    RewampDb.serverLacksChanged.removeListener(_onCaps);
    super.dispose();
  }

  void _onCaps() { if (mounted) setState(() {}); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // p_podium = 0: les facettes de dimension n'existent QUE sous un podium
      // posé — et c'est aussi ce qui fait de `podium` la somme des trois rangs.
      final f = await RewampDb.searchFacets('', podium: 0);
      if (!mounted) return;
      setState(() { _facets = f; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _playRandom(int n) async {
    final seed = DateTime.now().microsecondsSinceEpoch.toString();
    try {
      final songs = await RewampDb.browse(
          podium: 0, sortBy: 'random', seed: seed, limit: n);
      if (!mounted || songs.isEmpty) return;
      if (n == 1) {
        await widget.onTap(context, songs.first);
      } else {
        await (widget.onPlayAlbum ?? globalOnPlayAlbum)?.call(context, songs);
      }
    } catch (_) {}
  }

  void _openList(String title, {int rank = 0, PodiumCriteria criteria = PodiumCriteria.empty}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PodiumListScreen(
        title: title,
        rank: rank,
        criteria: criteria,
        onTap: widget.onTap,
        onPlayAlbum: widget.onPlayAlbum,
      ),
    ));
  }

  void _openHallOfFame(String axis, String title) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PodiumHallOfFameScreen(
        axis: axis,
        title: title,
        onTap: widget.onTap,
        onPlayAlbum: widget.onPlayAlbum,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;
    final tt   = Theme.of(context).textTheme;

    final ranks  = podiumCounts(_facets);
    final total  = podiumTotal(ranks);
    final vias   = {for (final f in podiumDimFacets(_facets, 'podium_via')) f.value: f.count};
    final kinds  = podiumDimFacets(_facets, 'compo_kind');
    final eras   = decadeCounts(_facets);
    final dims   = _dimsOnServer();
    final hof    = !RewampDb.serverLacks('podium_hall_of_fame');
    final thisYear = DateTime.now().year;

    Widget card({
      required Widget leading,
      required String title,
      String? subtitle,
      required VoidCallback onTap,
    }) =>
        ListTile(
          leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: leading,
          ),
          title: ScrollingText(text: title),
          subtitle: subtitle != null
              ? Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis)
              : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        );
    Widget icon(IconData i, {Color? color}) =>
        Icon(i, color: color ?? cs.onPrimaryContainer, size: 20);
    Widget sectionTitle(String s) => Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
          child: Text(s, style: tt.titleMedium),
        );

    final children = <Widget>[
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 0),
        child: Row(children: [
          Expanded(
            child: Text(
              total > 0 ? l10n.searchSongsCount(total) : '',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          RadioSurpriseButtons(
              onRadio: () => _playRandom(50), onSurprise: () => _playRandom(1)),
        ]),
      ),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
        child: Text(l10n.podiumHubBias,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ),
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, style: TextStyle(color: cs.error)),
        ),
      // Les trois rangs: une rangée de puces aux couleurs des coupes.
      if (total > 0)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in const [1, 2, 3])
              ActionChip(
                avatar: Icon(Icons.emoji_events, size: 16,
                    color: podiumColor(context, r)),
                label: Text('${podiumRankLabel(l10n, r)} (${ranks[r]})'),
                onPressed: () => _openList(podiumRankLabel(l10n, r), rank: r),
              ),
          ]),
        ),
      card(
        leading: icon(Icons.emoji_events, color: podiumColor(context, 1)),
        title: l10n.podiumRecentWinners,
        subtitle: l10n.podiumRecentWinnersSubtitle,
        onTap: () => _openList(l10n.podiumRecentWinners,
            rank: 1,
            criteria: dims
                ? PodiumCriteria(yearMin: thisYear - 1)
                : PodiumCriteria.empty),
      ),
      if (dims) ...[
        card(
          leading: icon(Icons.music_note_outlined),
          title: l10n.podiumViaSelf,
          subtitle: [
            if ((vias['self'] ?? 0) > 0) l10n.searchSongsCount(vias['self']!),
            l10n.podiumViaSelfSubtitle,
          ].join(' · '),
          onTap: () => _openList(l10n.podiumViaSelf,
              criteria: const PodiumCriteria(via: 'self')),
        ),
        card(
          leading: icon(Icons.movie_outlined),
          title: l10n.podiumViaProduction,
          subtitle: [
            if ((vias['production'] ?? 0) > 0)
              l10n.searchSongsCount(vias['production']!),
            l10n.podiumViaProductionSubtitle,
          ].join(' · '),
          onTap: () => _openList(l10n.podiumViaProduction,
              criteria: const PodiumCriteria(via: 'production')),
        ),
        if (kinds.isNotEmpty) ...[
          sectionTitle(l10n.podiumByKind),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in kinds)
                Tooltip(
                  message: compoKindHint(l10n, k.value) ?? '',
                  child: ActionChip(
                    label: Text('${compoKindLabel(l10n, k.value)} (${k.count})'),
                    onPressed: () => _openList(compoKindLabel(l10n, k.value),
                        criteria: PodiumCriteria(kinds: {k.value})),
                  ),
                ),
            ]),
          ),
        ],
        if (eras.isNotEmpty) ...[
          sectionTitle(l10n.podiumByEra),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in eras)
                ActionChip(
                  label: Text('${decadeLabel(l10n, e.decade)} (${e.count})'),
                  onPressed: () => _openList(decadeLabel(l10n, e.decade),
                      criteria: decadeCriteria(PodiumCriteria.empty, e.decade)),
                ),
            ]),
          ),
        ],
      ],
      if (hof) ...[
        const SizedBox(height: 8),
        card(
          leading: icon(Icons.celebration),
          title: l10n.podiumByParty,
          subtitle: l10n.podiumByPartySubtitle,
          onTap: () => _openHallOfFame('party', l10n.podiumByParty),
        ),
        card(
          leading: icon(Icons.person_outline),
          title: l10n.podiumTopArtists,
          onTap: () => _openHallOfFame('artist', l10n.podiumTopArtists),
        ),
      ],
      card(
        leading: icon(Icons.list),
        title: l10n.podiumAll,
        subtitle: l10n.podiumAllSubtitle,
        onTap: () => _openList(l10n.podiumAll),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.podiumBrowserTitle)),
      body: ListView(
        padding: shellInset(context, const EdgeInsets.only(bottom: 16)),
        children: children,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Niveau 2 — la liste au grain podium
// ---------------------------------------------------------------------------

class PodiumListScreen extends StatefulWidget {
  final String title;
  /// 0 = tout podium, 1-3 = ce rang (le MEILLEUR du morceau).
  final int rank;
  final PodiumCriteria criteria;
  final PodiumOnTap onTap;
  final OnPlayAlbum? onPlayAlbum;

  const PodiumListScreen({
    super.key,
    required this.title,
    this.rank = 0,
    this.criteria = PodiumCriteria.empty,
    required this.onTap,
    this.onPlayAlbum,
  });

  @override
  State<PodiumListScreen> createState() => _PodiumListScreenState();
}

class _PodiumListScreenState extends State<PodiumListScreen> {
  final _scroll = ScrollController();
  final _filterCtrl = TextEditingController();
  Timer? _debounce;
  /// Filtre par TITRE (demandé le 2026-10-20): non nul ⇒ la page vient de
  /// `search_music` (même p_podium, mêmes critères, même tri `podium`,
  /// mig 289) au lieu de `browse_music`. Les facettes suivent (`q`).
  String? _titleFilter;
  /// Mode de `search_music` sous filtre: `false` = EXACT, c'est-à-dire un
  /// PRÉFIXE par mot (« blu » trouve « Blue », « Blur », « Blues ») —
  /// `true` = similarité par trigrammes, qui RATE « Blue » pour « blu » (la
  /// chaîne est trop courte pour passer le seuil) et coûte 3-4× plus cher.
  /// Mesuré le 2026-10-20 sur « blu » + or + 2025: fuzzy 1 ligne (un match
  /// d'artiste), exact 2 dont « I am Blue ». Le flou n'est qu'un REPLI quand
  /// l'exact ne rend rien (fautes de frappe), comme dans la Recherche.
  bool _fuzzy = false;
  late int _rank = widget.rank;
  late PodiumCriteria _criteria = widget.criteria;
  String? _platform, _format;
  /// `podium` = année de compo ↓ puis rang ↑ (mig 285); `name`, `popularity`,
  /// `year` comme partout ailleurs.
  String _sort = 'podium';

  List<FacetCount> _facets = const [];
  List<SearchResult> _rows = const [];
  int _total = 0, _offset = 0, _reqId = 0;
  bool _hasMore = false, _loading = true, _loadingMore = false;
  String? _error;

  static const _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
    RewampDb.serverLacksChanged.addListener(_onCaps);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _filterCtrl.dispose();
    _debounce?.cancel();
    RewampDb.serverLacksChanged.removeListener(_onCaps);
    super.dispose();
  }

  void _onFilterChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final t = text.trim();
      final next = t.isEmpty ? null : t;
      if (next == _titleFilter) return;
      _titleFilter = next;
      _reload();
    });
  }

  /// Le serveur ne connaît pas les critères de la mig 285 (404 rejoué sans
  /// eux): la page reçue a été filtrée côté client et paginer plus loin
  /// prendrait de faux décalages. On le dit, on retire les critères, on
  /// recharge — le rang, lui, reste (p_podium est antérieur).
  void _onCaps() {
    if (!mounted) return;
    if (!_dimsOnServer() && !_criteria.isEmpty) {
      AppSnack.show(context, context.l10n.searchPodiumUnavailable);
      _criteria = PodiumCriteria.empty;
      _reload();
    } else {
      setState(() {});
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<List<SearchResult>> _fetch(int offset, {String? sort, String? seed, int? limit}) {
    final q = _titleFilter;
    if (q != null) {
      return RewampDb.search(
        q,
        fuzzy: _fuzzy,
        podium: _rank,
        podiumCriteria: _criteria.isEmpty ? null : _criteria,
        platform: _platform,
        formatFilter: _format,
        sortBy: sort ?? _sort,
        seed: seed,
        limit: limit ?? _pageSize,
        offset: offset,
      );
    }
    return RewampDb.browse(
      podium: _rank,
      podiumCriteria: _criteria.isEmpty ? null : _criteria,
      platform: _platform,
      formatFilter: _format,
      sortBy: sort ?? _sort,
      seed: seed,
      limit: limit ?? _pageSize,
      offset: offset,
    );
  }

  void _loadFacets(int id) {
    RewampDb.searchFacets(_titleFilter ?? '',
            fuzzy: _titleFilter != null && _fuzzy,
            podium: _rank,
            podiumCriteria: _criteria.isEmpty ? null : _criteria,
            platform: _platform,
            formatFilter: _format)
        .then((f) {
      if (mounted && id == _reqId) setState(() => _facets = f);
    }).catchError((_) {});
  }

  Future<void> _reload() async {
    final id = ++_reqId;
    _fuzzy = false;
    setState(() { _loading = true; _error = null; _rows = const []; });
    // Facettes et page en parallèle: indépendantes, et la barre de puces ne
    // doit pas attendre la liste (ni l'inverse).
    _loadFacets(id);
    try {
      var res = await _fetch(0);
      if (!mounted || id != _reqId) return;
      // Exact muet sous filtre texte: repli FLOU, pour la page ET les
      // facettes (le mode vaut ensuite pour la pagination).
      if (res.isEmpty && _titleFilter != null) {
        _fuzzy = true;
        _loadFacets(id);
        res = await _fetch(0);
        if (!mounted || id != _reqId) return;
      }
      setState(() {
        _rows    = _songsOnly(res);
        _total   = res.isEmpty ? 0 : res.first.totalCount;
        _offset  = res.length;
        _hasMore = _total > 0 && _offset < _total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  /// Sous filtre TEXTE le flux est search_music: il ramène aussi la ligne
  /// d'un album ENTIER dont le nom matche — cette liste est celle des
  /// MORCEAUX (même règle que BrowseResultsScreen).
  List<SearchResult> _songsOnly(List<SearchResult> rows) {
    final q = _titleFilter;
    if (q == null) return rows;
    return [
      for (final r in rows)
        if (!RewampDb.isWholeAlbumRow(r) && !RewampDb.matchedAlbumNameOnly(r, q)) r,
    ];
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    final id = _reqId;
    try {
      final more = await _fetch(_offset);
      if (!mounted || id != _reqId) return;
      setState(() {
        _rows = [..._rows, ..._songsOnly(more)];
        _offset += more.length;
        _hasMore = more.isNotEmpty && _offset < _total;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Radio (50) / Surprise (1): le serveur tire au hasard DANS la portée
  /// courante — pas un mélange de la page chargée.
  Future<void> _playRandom(int n) async {
    final seed = DateTime.now().microsecondsSinceEpoch.toString();
    try {
      final songs = await _fetch(0, sort: 'random', seed: seed, limit: n);
      if (!mounted || songs.isEmpty) return;
      if (n == 1) {
        await widget.onTap(context, songs.first);
      } else {
        await (widget.onPlayAlbum ?? globalOnPlayAlbum)?.call(context, songs);
      }
    } catch (_) {}
  }

  /// « Tout lire »: ce qui est AFFICHÉ, dans l'ordre affiché — en tri
  /// `podium`, c'est l'ordre de classement que la proposition demandait.
  Future<void> _playAll() async {
    if (_rows.isEmpty) return;
    final resolved = await RewampDb.resolveMatchedTracks(_rows);
    if (!mounted) return;
    await (widget.onPlayAlbum ?? globalOnPlayAlbum)?.call(context, resolved);
  }

  void _set(VoidCallback change) { setState(change); _reload(); }

  // ---- Puces --------------------------------------------------------------

  Widget _chip(String label, String? selectedLabel, VoidCallback onPressed,
      {IconData? avatar}) {
    final selected = selectedLabel != null;
    return ActionChip(
      avatar: Icon(selected ? Icons.check : (avatar ?? Icons.expand_more), size: 14),
      label: Text(
          selected ? context.l10n.searchFacetSelected(label, selectedLabel) : label,
          style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor:
          selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      onPressed: onPressed,
    );
  }

  /// Feuille de choix d'UNE valeur parmi des options libellées (nature,
  /// genre, époque): « Tous » en tête, coche sur la valeur active. Rend la
  /// valeur, `''` pour effacer, null si fermée sans choix.
  Future<String?> _pickLabelled(String title, List<_Choice> options, String? current) {
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            ListTile(
              dense: true,
              leading: Icon(current == null ? Icons.check_circle : Icons.circle_outlined,
                  size: 20, color: current == null ? accent : null),
              title: Text(l10n.searchAllOf(title)),
              onTap: () => Navigator.of(ctx).pop(''),
            ),
            for (final o in options)
              ListTile(
                dense: true,
                leading: Icon(
                    current == o.value ? Icons.check_circle : Icons.circle_outlined,
                    size: 20, color: current == o.value ? accent : null),
                title: Text(o.label,
                    style: TextStyle(
                        fontWeight: current == o.value ? FontWeight.w600 : FontWeight.normal)),
                subtitle: o.hint != null ? Text(o.hint!) : null,
                trailing: o.count != null
                    ? Text('${o.count}', style: const TextStyle(fontSize: 12, color: Colors.grey))
                    : null,
                onTap: () => Navigator.of(ctx).pop(o.value),
              ),
          ]),
        ),
      ),
    );
  }

  /// Feuille de valeurs BRUTES avec champ de recherche (séries de party: 714;
  /// plateformes; formats) — celle de la Recherche.
  Future<void> _pickRaw(String label, List<FacetCount> values, String? current,
      void Function(String?) onPick) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => FacetPickerSheet(
        label: label,
        values: values,
        selected: current,
        onPick: (v) { Navigator.of(ctx).pop(); onPick(v); },
      ),
    );
  }

  /// Feuille « Époque »: une décennie (ligne, avec son compte) OU une année
  /// précise (puces sous sa décennie) — demandé le 2026-10-20: les périodes
  /// ne suffisent pas à retrouver « la compo de 1995 ».
  Future<({_EraKind kind, int value})?> _pickEra(
      List<({int decade, int count})> decades,
      List<({int year, int count})> years) {
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    final selDecade = _criteria.yearMin != null && _criteria.yearMax == _criteria.yearMin! + 9
        && _criteria.yearMin! % 10 == 0 ? _criteria.yearMin : null;
    final selYear = _criteria.yearMin != null && _criteria.yearMin == _criteria.yearMax
        ? _criteria.yearMin : null;
    final none = _criteria.yearMin == null && _criteria.yearMax == null;
    return showModalBottomSheet<({_EraKind kind, int value})>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: ListView(shrinkWrap: true, children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
              child: Text(l10n.podiumChipEra,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              dense: true,
              leading: Icon(none ? Icons.check_circle : Icons.circle_outlined,
                  size: 20, color: none ? accent : null),
              title: Text(l10n.searchAllOf(l10n.podiumChipEra)),
              onTap: () => Navigator.of(ctx).pop((kind: _EraKind.all, value: 0)),
            ),
            for (final d in decades) ...[
              ListTile(
                dense: true,
                leading: Icon(selDecade == d.decade ? Icons.check_circle : Icons.circle_outlined,
                    size: 20, color: selDecade == d.decade ? accent : null),
                title: Text(decadeLabel(l10n, d.decade),
                    style: TextStyle(fontWeight: selDecade == d.decade ? FontWeight.w600 : FontWeight.normal)),
                trailing: Text('${d.count}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () => Navigator.of(ctx).pop((kind: _EraKind.decade, value: d.decade)),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(56, 0, 16, 8),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final y in years)
                    if (decadeOf(y.year) == d.decade)
                      ChoiceChip(
                        label: Text('${y.year} (${y.count})', style: const TextStyle(fontSize: 11)),
                        selected: selYear == y.year,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onSelected: (_) => Navigator.of(ctx).pop((kind: _EraKind.year, value: y.year)),
                      ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _chipBar() {
    final l10n = context.l10n;
    final dims = _dimsOnServer();
    final ranks = podiumCounts(_facets);
    final vias  = podiumDimFacets(_facets, 'podium_via');
    final kinds = podiumDimFacets(_facets, 'compo_kind');
    final series = podiumDimFacets(_facets, 'party_series');
    final eras  = decadeCounts(_facets);
    final platforms = podiumDimFacets(_facets, 'platform');
    final formats   = podiumDimFacets(_facets, 'format');
    final era = eraLabel(l10n, _criteria);
    final chips = <Widget>[
      _chip(l10n.searchPodium, _rank == 0 ? null : podiumRankLabel(l10n, _rank), () async {
        final v = await showPodiumPicker(context,
            current: _rank == 0 ? null : _rank, counts: ranks);
        if (v == null || !mounted) return;
        _set(() => _rank = v < 0 ? 0 : v);
      }, avatar: Icons.emoji_events_outlined),
      if (dims && (vias.length > 1 || _criteria.via != null))
        _chip(l10n.podiumChipVia,
            _criteria.via == null ? null : podiumViaLabel(l10n, _criteria.via!), () async {
          final v = await _pickLabelled(l10n.podiumChipVia, [
            for (final f in vias)
              _Choice(f.value, podiumViaLabel(l10n, f.value), count: f.count,
                  hint: f.value == 'production'
                      ? l10n.podiumViaProductionSubtitle
                      : l10n.podiumViaSelfSubtitle),
          ], _criteria.via);
          if (v == null || !mounted) return;
          _set(() => _criteria = _criteria.copyWith(via: v.isEmpty ? null : v));
        }),
      if (dims && (kinds.length > 1 || _criteria.kinds.isNotEmpty))
        _chip(l10n.podiumChipKind,
            _criteria.kinds.isEmpty ? null : compoKindLabel(l10n, _criteria.kinds.first), () async {
          final v = await _pickLabelled(l10n.podiumChipKind, [
            for (final f in kinds)
              _Choice(f.value, compoKindLabel(l10n, f.value),
                  count: f.count, hint: compoKindHint(l10n, f.value)),
          ], _criteria.kinds.isEmpty ? null : _criteria.kinds.first);
          if (v == null || !mounted) return;
          _set(() => _criteria = _criteria.copyWith(kinds: v.isEmpty ? const {} : {v}));
        }),
      if (dims && (series.length > 1 || _criteria.series.isNotEmpty))
        _chip(l10n.podiumChipSeries,
            _criteria.series.isEmpty ? null : _criteria.series.first, () {
          _pickRaw(l10n.podiumChipSeries, series,
              _criteria.series.isEmpty ? null : _criteria.series.first,
              (v) => _set(() => _criteria =
                  _criteria.copyWith(series: v == null ? const {} : {v})));
        }),
      if (dims && (eras.length > 1 || era != null))
        _chip(l10n.podiumChipEra, era, () async {
          final v = await _pickEra(eras, yearCounts(_facets));
          if (v == null || !mounted) return;
          _set(() => _criteria = switch (v) {
            (kind: _EraKind.all, value: _) =>
              _criteria.copyWith(yearMin: null, yearMax: null),
            (kind: _EraKind.decade, value: final d) => decadeCriteria(_criteria, d),
            (kind: _EraKind.year, value: final y) => yearCriteria(_criteria, y),
          });
        }),
      if (platforms.isNotEmpty || _platform != null)
        _chip(l10n.searchPlatform, _platform, () {
          _pickRaw(l10n.searchPlatform, platforms, _platform,
              (v) => _set(() => _platform = v));
        }),
      if (formats.isNotEmpty || _format != null)
        _chip(l10n.searchFormat, _format?.toUpperCase(), () {
          _pickRaw(l10n.searchFormat, formats, _format,
              (v) => _set(() => _format = v));
        }),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 12, 4),
      child: Row(children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          chips[i],
        ],
      ]),
    );
  }

  String _sortLabel(AppLocalizations l10n, String s) => switch (s) {
        'podium'     => l10n.podiumSortPodium,
        'name'       => l10n.sortTitle,
        'popularity' => l10n.searchSortPopular,
        'year'       => l10n.searchSortYear,
        _            => s,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: l10n.commonSort,
            initialValue: _sort,
            onSelected: (s) { if (s != _sort) _set(() => _sort = s); },
            itemBuilder: (_) => [
              for (final s in const ['podium', 'name', 'popularity', 'year'])
                PopupMenuItem(value: s, child: Text(_sortLabel(l10n, s))),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
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
        _chipBar(),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)));
    }
    if (_rows.isEmpty) {
      return Center(child: Text(
          _titleFilter != null ? l10n.searchNoResults : l10n.browseNoSongs));
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Text(
            _total > 0
                ? l10n.browseCountSongs(_total, _rows.length)
                : l10n.browseLoadedSongs(_rows.length),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_loadingMore) ...[
            const SizedBox(width: 8),
            const SizedBox(width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ],
          const Spacer(),
          RadioSurpriseButtons(
            onPlayAll: _playAll,
            onRadio: () => _playRandom(50),
            onSurprise: () => _playRandom(1),
            dense: true,
          ),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          controller: _scroll,
          padding: shellInset(context, EdgeInsets.zero),
          itemCount: _rows.length + (_hasMore ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i == _rows.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            // Le navigateur brasse tout le catalogue: la collection de chaque
            // ligne est une information (règle des navigateurs par facette).
            return SongTile(
              result: _rows[i],
              onTap: widget.onTap,
              onPlayAlbum: widget.onPlayAlbum,
              albumRowsAllowed: false,
              showCollection: true,
              // L'année de la COMPO, sur la ligne de collection: c'est l'ordre
              // de la liste, il faut pouvoir le lire (demandé le 2026-10-20).
              showYear: true,
            );
          },
        ),
      ),
    ]);
  }
}

enum _EraKind { all, decade, year }

class _Choice {
  final String value, label;
  final String? hint;
  final int? count;
  const _Choice(this.value, this.label, {this.hint, this.count});
}

// ---------------------------------------------------------------------------
// Palmarès — podium_hall_of_fame (artiste, série de party, année)
// ---------------------------------------------------------------------------

class PodiumHallOfFameScreen extends StatefulWidget {
  /// 'artist' | 'party' | 'year'.
  final String axis;
  final String title;
  final int rank;
  final PodiumCriteria criteria;
  final PodiumOnTap onTap;
  final OnPlayAlbum? onPlayAlbum;

  const PodiumHallOfFameScreen({
    super.key,
    required this.axis,
    required this.title,
    this.rank = 0,
    this.criteria = PodiumCriteria.empty,
    required this.onTap,
    this.onPlayAlbum,
  });

  @override
  State<PodiumHallOfFameScreen> createState() => _PodiumHallOfFameScreenState();
}

class _PodiumHallOfFameScreenState extends State<PodiumHallOfFameScreen> {
  final _scroll = ScrollController();
  List<HallOfFameRow> _rows = const [];
  int _total = 0;
  bool _hasMore = false, _loading = true, _loadingMore = false;
  String? _error;

  static const _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<List<HallOfFameRow>> _fetch(int offset) => RewampDb.podiumHallOfFame(
        widget.axis,
        podium: widget.rank,
        criteria: widget.criteria.isEmpty ? null : widget.criteria,
        limit: _pageSize,
        offset: offset,
      );

  Future<void> _load() async {
    try {
      final res = await _fetch(0);
      if (!mounted) return;
      setState(() {
        _rows    = res;
        _total   = res.isEmpty ? 0 : res.first.totalCount;
        _hasMore = _total > res.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _fetch(_rows.length);
      if (!mounted) return;
      setState(() {
        _rows = [..._rows, ...more];
        _hasMore = more.isNotEmpty && _rows.length < _total;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _open(HallOfFameRow r) {
    switch (widget.axis) {
      case 'artist':
        // `key_id` est l'uuid d'artiste — jamais le libellé (un crédit n'est
        // pas un artiste, règle d'artist_links.dart).
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ArtistResultsScreen(
            artistName: r.label,
            artistId: r.keyId.isEmpty ? null : r.keyId,
            onTap: widget.onTap,
            onPlayAlbum: widget.onPlayAlbum,
          ),
        ));
      case 'party':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PodiumListScreen(
            title: r.label,
            rank: widget.rank,
            criteria: widget.criteria.copyWith(series: {r.keyId}),
            onTap: widget.onTap,
            onPlayAlbum: widget.onPlayAlbum,
          ),
        ));
      default:
        final y = int.tryParse(r.keyId);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PodiumListScreen(
            title: r.label,
            rank: widget.rank,
            criteria: widget.criteria.copyWith(yearMin: y, yearMax: y),
            onTap: widget.onTap,
            onPlayAlbum: widget.onPlayAlbum,
          ),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(child: Text(_error!, style: TextStyle(color: cs.error)));
    } else if (_rows.isEmpty) {
      body = Center(child: Text(l10n.searchNoResults));
    } else {
      body = ListView.builder(
        controller: _scroll,
        padding: shellInset(context, EdgeInsets.zero),
        itemCount: _rows.length + (_hasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == _rows.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final r = _rows[i];
          return ListTile(
            leading: SizedBox(
              width: 44, height: 44,
              child: ArtworkImage(
                url: r.artworkUrl,
                size: 44,
                borderRadius: BorderRadius.circular(6),
                placeholder: Icon(
                    widget.axis == 'artist'
                        ? Icons.person_outline
                        : widget.axis == 'party'
                            ? Icons.celebration
                            : Icons.calendar_month,
                    color: cs.primary),
              ),
            ),
            title: Row(children: [
              // Le rang dans le palmarès: utile pour parler d'un « top 10 ».
              SizedBox(
                width: 28,
                child: Text('${i + 1}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ),
              Expanded(child: ScrollingText(text: r.label)),
            ]),
            subtitle: Padding(
              padding: const EdgeInsetsDirectional.only(start: 28),
              child: _Medals(gold: r.gold, silver: r.silver, bronze: r.bronze),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(r),
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: body,
    );
  }
}

/// Trois coupes et leurs comptes: or, argent, bronze. Des icônes et des
/// nombres nus — aucun nom à décliner avec le nombre (règle i18n).
class _Medals extends StatelessWidget {
  final int gold, silver, bronze;
  const _Medals({required this.gold, required this.silver, required this.bronze});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    Widget one(int rank, int n) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.emoji_events, size: 14, color: podiumColor(context, rank)),
            const SizedBox(width: 2),
            Text('$n', style: style),
          ]),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      one(1, gold), one(2, silver), one(3, bronze),
    ]);
  }
}
