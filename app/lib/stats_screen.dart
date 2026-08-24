import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'artwork_image.dart';
import 'l10n.dart';
import 'local_db.dart';
import 'shell_insets.dart';
import 'sync_service.dart';
import 'competition_screen.dart' show globalOnPlayOnlineSong;
import 'album_detail_screen.dart';
import 'rewamp_db.dart' show OnPlayLocalAlbum, RewampDb, SearchResult;
import 'track_options_sheet.dart'
    show showPlayChoiceSheet, PlayChoice, globalOnQueueAdd,
         globalOnLocalQueueAdd, globalOnPlayNowSong, globalOnPlayAlbum,
         globalOnAlbumQueueAdd;

/// Listening-stats dashboard: period selector (presets + per month/year),
/// headline numbers, plays chart, top tracks/albums/artists with drill-down.
/// Everything is computed locally from play_events (raw one-row-per-play
/// history) — works fully offline.
class StatsScreen extends StatefulWidget {
  final OnPlayLocalAlbum? onPlayLocalAlbum;

  const StatsScreen({super.key, this.onPlayLocalAlbum});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

// ── Period model ──────────────────────────────────────────────────────────────

class _Period {
  final String id;      // stable identity for the chip selection
  final int? from;      // epoch seconds, null = unbounded
  final int? to;
  final bool byMonth;   // chart bucketing

  const _Period(this.id, this.from, this.to, {required this.byMonth});

  /// Human label, derived from [id] — the period objects are built in places
  /// with no BuildContext (state field initializers), so the label can only be
  /// localized at render time.
  ///   'd<N>' = last N days · 'year' = this year · 'all' = everything
  ///   'D<YYYY-MM-DD>' = one day · 'm<YYYY-MM>' = one month · 'y<YYYY>' = one year
  String label(AppLocalizations l10n) {
    if (id == 'all')  return l10n.statsPeriodAll;
    if (id == 'year') return l10n.statsPeriodThisYear;
    final rest = id.substring(1);
    switch (id[0]) {
      case 'd': return l10n.statsPeriodDays(int.parse(rest));
      case 'D':
        final d = DateTime.parse(rest);
        return '${d.day} ${_monthName(l10n, d.month)} ${d.year}';
      case 'm': return _monthLabel(l10n, rest);
      case 'y': return rest;
    }
    return id;
  }

  static _Period days(int n) {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: n));
    return _Period('d$n',
        from.millisecondsSinceEpoch ~/ 1000, null, byMonth: n > 92);
  }

  static _Period thisYear() {
    final now = DateTime.now();
    return _Period('year',
        DateTime(now.year).millisecondsSinceEpoch ~/ 1000, null, byMonth: true);
  }

  static const all = _Period('all', null, null, byMonth: true);

  /// 'YYYY-MM-DD' → that single day.
  static _Period day(String ymd) {
    final d = DateTime.parse(ymd);
    return _Period('D$ymd',
        d.millisecondsSinceEpoch ~/ 1000,
        DateTime(d.year, d.month, d.day + 1).millisecondsSinceEpoch ~/ 1000,
        byMonth: false);
  }

  /// 'YYYY-MM' → that month.
  static _Period month(String ym) {
    final y = int.parse(ym.substring(0, 4)), m = int.parse(ym.substring(5, 7));
    final from = DateTime(y, m);
    final to   = DateTime(y, m + 1);
    return _Period('m$ym',
        from.millisecondsSinceEpoch ~/ 1000,
        to.millisecondsSinceEpoch ~/ 1000, byMonth: false);
  }

  /// 'YYYY' → that year.
  static _Period year(String y) {
    final yi = int.parse(y);
    return _Period('y$y',
        DateTime(yi).millisecondsSinceEpoch ~/ 1000,
        DateTime(yi + 1).millisecondsSinceEpoch ~/ 1000, byMonth: true);
  }
}

/// 1-based month number → month name in the active locale.
///
/// Comes from intl, not from twelve ARB keys: that would be 12 strings × 18
/// languages to translate for something the locale data already knows.
///
/// LLLL/LLL (stand-alone), NOT MMMM/MMM: Slavic languages inflect month names,
/// and the M-forms give the genitive used inside a full date ("5 июля"). These
/// labels stand alone ("июль 2024"), which wants the nominative.
String _monthName(AppLocalizations l10n, int m) =>
    DateFormat.LLLL(l10n.localeName).format(DateTime(2000, m.clamp(1, 12)));

/// Short month name for the chart axis. NOT `_monthName(...).substring(0, 3)`:
/// truncating to three characters mangles non-Latin scripts ("января", "1月").
String _monthNameShort(AppLocalizations l10n, int m) =>
    DateFormat.LLL(l10n.localeName).format(DateTime(2000, m.clamp(1, 12)));

String _monthLabel(AppLocalizations l10n, String ym) {
  final m = int.parse(ym.substring(5, 7));
  return '${_monthName(l10n, m)} ${ym.substring(0, 4)}';
}

// ── Dashboard ─────────────────────────────────────────────────────────────────

class _StatsScreenState extends State<StatsScreen> {
  _Period _period = _Period.days(30);
  // Chart-bucket drill: tapping a bar restricts the numbers + lists below to
  // that day/month (the chart itself keeps showing the whole period).
  _Period? _bucket;

  StatsOverview?    _overview;
  List<TrackStat>   _topTracks  = [];
  List<GroupStat>   _topAlbums  = [];
  List<GroupStat>   _topArtists = [];
  List<StatsPoint>  _timeline   = [];
  List<KeyStat>     _collections = [];
  List<KeyStat>     _formats     = [];
  List<KeyStat>     _engines     = [];
  LibraryOverview?  _libOverview;
  (int, int)?       _files;   // (file count, bytes) of the downloads tree
  bool _loading = true;
  int  _loadSeq = 0;
  /// Vue FUSIONNÉE: les écoutes de tous les appareils du compte, pas seulement
  /// celles d'ici. Décidée par la donnée — dès que le miroir de la timeline du
  /// compte porte quelque chose (migration 45). Sans compte, sans miroir, la
  /// requête est exactement celle d'avant. Le rail « Vos tendances » de
  /// l'accueil, lui, reste local: il parle de ce qui est SUR cet appareil.
  bool _merged = false;

  /// Period the numbers/lists reflect (chart bucket wins when selected).
  _Period get _effPeriod => _bucket ?? _period;

  @override
  void initState() {
    super.initState();
    LocalDb.instance.addListener(_load);
    _load();
    // Deux appareils en même temps: la timeline du compte descend au rythme du
    // battement de synchro (90 s en avant-plan), mais ouvrir cet écran est
    // justement le moment où on veut le compte à jour. `kick` est throttlé
    // (rien si une passe a réussi il y a moins d'une minute), donc c'est
    // gratuit quand ça vient de tourner. Le miroir notifie LocalDb, ce qui
    // relance `_load` tout seul.
    SyncService.instance.kick();
    // Filesystem walk of the whole downloads tree — heavy, so once per screen
    // open, not on every DB notify.
    RewampDb.localAudioFootprint().then((f) {
      if (mounted) setState(() => _files = f);
    });
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    final p   = _period;
    final eff = _effPeriod;
    final db  = LocalDb.instance;
    final merged = await db.hasAccountPlayEvents();
    if (!mounted || seq != _loadSeq) return;
    final results = await Future.wait([
      db.statsOverview(from: eff.from, to: eff.to, merged: merged),
      db.statsTopTracks(from: eff.from, to: eff.to, limit: 5, merged: merged),
      db.statsTopAlbums(from: eff.from, to: eff.to, limit: 5, merged: merged),
      db.statsTopArtists(from: eff.from, to: eff.to, limit: 5, merged: merged),
      db.statsTimeline(
          from: p.from, to: p.to, byMonth: p.byMonth, merged: merged),
      db.statsTopCollections(
          from: eff.from, to: eff.to, limit: 5, merged: merged),
      db.statsTopFormats(from: eff.from, to: eff.to, limit: 5, merged: merged),
      db.statsTopEngines(from: eff.from, to: eff.to, limit: 5, merged: merged),
      db.libraryOverview(),
    ]);
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _overview    = results[0] as StatsOverview;
      _topTracks   = results[1] as List<TrackStat>;
      _topAlbums   = results[2] as List<GroupStat>;
      _topArtists  = results[3] as List<GroupStat>;
      _timeline    = results[4] as List<StatsPoint>;
      _collections = results[5] as List<KeyStat>;
      _formats     = results[6] as List<KeyStat>;
      _engines     = results[7] as List<KeyStat>;
      _libOverview = results[8] as LibraryOverview;
      _merged      = merged;
      _loading     = false;
    });
  }

  void _setPeriod(_Period p) {
    setState(() { _period = p; _bucket = null; _loading = true; });
    _load();
  }

  void _onBarTap(String label) {
    setState(() {
      if (_bucket != null && _bucket!.id.substring(1) == label) {
        _bucket = null; // tap the selected bar again → back to the full period
      } else {
        _bucket = _period.byMonth ? _Period.month(label) : _Period.day(label);
      }
    });
    _load();
  }

  Future<void> _pickMonthOrYear() async {
    final months = await LocalDb.instance.statsMonths(merged: _merged);
    if (!mounted || months.isEmpty) return;
    final years = months.map((m) => m.substring(0, 4)).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final picked = await showModalBottomSheet<_Period>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(l10n.statsByYear,
                  style: Theme.of(ctx).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final y in years)
                  ActionChip(
                    label: Text(y),
                    onPressed: () => Navigator.pop(ctx, _Period.year(y)),
                  ),
              ]),
              const SizedBox(height: 16),
              Text(l10n.statsByMonth,
                  style: Theme.of(ctx).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              for (final m in months)
                ListTile(
                  dense: true,
                  title: Text(_monthLabel(l10n, m)),
                  onTap: () => Navigator.pop(ctx, _Period.month(m)),
                ),
            ],
          ),
        );
      },
    );
    if (picked != null) _setPeriod(picked);
  }

  void _push(Widget screen) {
    Navigator.push<void>(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _playTopTracks(List<TrackStat> stats, int index) =>
      playStatTrack(context, stats, index, widget.onPlayLocalAlbum);

  @override
  Widget build(BuildContext context) {
    final l10n  = context.l10n;
    final cs    = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final o     = _overview;
    final presets = [
      _Period.days(7),
      _Period.days(30),
      _Period.thisYear(),
      _Period.all,
    ];
    final isPreset = presets.any((p) => p.id == _period.id);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          await SyncService.instance.syncNow();
          await _load();
        },
        child: ListView(
        // Le tirer-pour-rafraîchir doit rester possible quand le contenu tient
        // dans l'écran (compte neuf, période vide).
        physics: const AlwaysScrollableScrollPhysics(),
        padding: shellInset(context, const EdgeInsets.only(bottom: 32)),
        children: [
          // ── Period chips ─────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              for (final p in presets) ...[
                ChoiceChip(
                  label: Text(p.label(l10n)),
                  selected: _period.id == p.id,
                  onSelected: (_) => _setPeriod(p),
                ),
                const SizedBox(width: 8),
              ],
              ChoiceChip(
                label: Text(
                    isPreset ? l10n.statsByMonthOrYear : _period.label(l10n)),
                selected: !isPreset,
                onSelected: (_) => _pickMonthOrYear(),
              ),
            ]),
          ),

          if (_loading && o == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (o != null) ...[
            // ── Headline numbers (restricted to the chart bucket if any) ─
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                _StatCard(label: l10n.statsPlaysLabel,   value: '${o.plays}',   cs: cs),
                const SizedBox(width: 8),
                _StatCard(label: l10n.statsTracksLabel,  value: '${o.tracks}',  cs: cs),
                const SizedBox(width: 8),
                _StatCard(label: l10n.statsArtistsLabel, value: '${o.artists}', cs: cs),
                const SizedBox(width: 8),
                _StatCard(label: l10n.statsAlbumsLabel,  value: '${o.albums}',  cs: cs),
              ]),
            ),

            // ── Cumulated listening time ────────────────────────────────
            if (o.listenedMs >= 60000)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  _StatCard(
                      label: l10n.statsListenTime,
                      value: _fmtListen(o.listenedMs),
                      cs: cs),
                ]),
              ),

            // ── Chart (always the full period; tap a bar to drill) ─────
            if (_timeline.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _BarChart(
                  points:        _filledTimeline(),
                  byMonth:       _period.byMonth,
                  selectedLabel: _bucket?.id.substring(1),
                  onBarTap:      _onBarTap,
                  cs:            cs,
                  theme:         theme,
                ),
              ),

            // Selected-bucket chip — makes the restriction visible + clearable.
            if (_bucket != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    label: Text(_bucket!.label(l10n)),
                    selected: true,
                    onDeleted: () => _onBarTap(_bucket!.id.substring(1)),
                  ),
                ),
              ),

            if (o.plays == 0)
              Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Column(children: [
                    Icon(Icons.bar_chart, size: 64, color: cs.outline),
                    const SizedBox(height: 12),
                    Text(l10n.statsNoPlaysInPeriod,
                        style: TextStyle(color: cs.outline)),
                  ]),
                ),
              ),

            // ── Top tracks ─────────────────────────────────────────────
            if (_topTracks.isNotEmpty) ...[
              _SectionHeader(
                title: l10n.statsTopTracks,
                onSeeAll: () => _push(_TopTracksScreen(
                  title:  l10n.statsTopTracksIn(_effPeriod.label(l10n)),
                  period: _effPeriod,
                  onPlay: widget.onPlayLocalAlbum,
                  merged: _merged,
                )),
              ),
              for (var i = 0; i < _topTracks.length; i++)
                _TrackRow(
                  rank: i + 1,
                  stat: _topTracks[i],
                  cs:   cs,
                  onTap: () => _playTopTracks(_topTracks, i),
                ),
            ],

            // ── Top albums ─────────────────────────────────────────────
            if (_topAlbums.isNotEmpty) ...[
              _SectionHeader(
                title: l10n.statsTopAlbums,
                onSeeAll: () => _push(_TopGroupsScreen(
                  title:   l10n.statsTopAlbumsIn(_effPeriod.label(l10n)),
                  period:  _effPeriod,
                  albums:  true,
                  onPlay:  widget.onPlayLocalAlbum,
                  merged:  _merged,
                )),
              ),
              for (var i = 0; i < _topAlbums.length; i++)
                _GroupRow(
                  rank:  i + 1,
                  stat:  _topAlbums[i],
                  icon:  Icons.album,
                  cs:    cs,
                  onTap: () => openStatAlbum(
                      context, _topAlbums[i], widget.onPlayLocalAlbum),
                ),
            ],

            // ── Top artists ────────────────────────────────────────────
            if (_topArtists.isNotEmpty) ...[
              _SectionHeader(
                title: l10n.statsTopArtists,
                onSeeAll: () => _push(_TopGroupsScreen(
                  title:   l10n.statsTopArtistsIn(_effPeriod.label(l10n)),
                  period:  _effPeriod,
                  albums:  false,
                  onPlay:  widget.onPlayLocalAlbum,
                  merged:  _merged,
                )),
              ),
              for (var i = 0; i < _topArtists.length; i++)
                _GroupRow(
                  rank:  i + 1,
                  stat:  _topArtists[i],
                  icon:  Icons.person,
                  cs:    cs,
                  onTap: () => _push(_TopTracksScreen(
                    title:  _topArtists[i].name,
                    period: _effPeriod,
                    artist: _topArtists[i].key,
                    onPlay: widget.onPlayLocalAlbum,
                    merged: _merged,
                  )),
                ),
            ],

            // ── By collection / format / engine (same period) ───────────
            if (_collections.isNotEmpty) ...[
              _PlainHeader(title: l10n.statsByCollection),
              for (var i = 0; i < _collections.length; i++)
                _KeyRow(rank: i + 1, stat: _collections[i], cs: cs),
            ],
            if (_formats.isNotEmpty) ...[
              _PlainHeader(title: l10n.statsByFormat),
              for (var i = 0; i < _formats.length; i++)
                _KeyRow(rank: i + 1, stat: _formats[i], cs: cs, upper: true),
            ],
            if (_engines.isNotEmpty) ...[
              _PlainHeader(title: l10n.statsByEngine),
              for (var i = 0; i < _engines.length; i++)
                _KeyRow(rank: i + 1, stat: _engines[i], cs: cs),
            ],
          ],

          // ── Library + local files (period-independent) ────────────────
          if (_libOverview != null) ...[
            _PlainHeader(title: l10n.navLibrary),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(children: [
                _StatCard(
                    label: l10n.statsTracksLabel,
                    value: '${_libOverview!.tracks}', cs: cs),
                const SizedBox(width: 8),
                _StatCard(
                    label: l10n.libraryFavorites,
                    value: '${_libOverview!.favorites}', cs: cs),
                const SizedBox(width: 8),
                _StatCard(
                    label: l10n.statsPlaylistsLabel,
                    value: '${_libOverview!.playlists}', cs: cs),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                _StatCard(
                    label: l10n.statsAlbumsLabel,
                    value: '${_libOverview!.albums}', cs: cs),
                const SizedBox(width: 8),
                _StatCard(
                    label: l10n.statsArtistsLabel,
                    value: '${_libOverview!.artists}', cs: cs),
              ]),
            ),
          ],
          if (_files != null) ...[
            _PlainHeader(title: l10n.statsLocalFilesSection),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(children: [
                _StatCard(
                    label: l10n.statsFilesLabel,
                    value: '${_files!.$1}', cs: cs),
                const SizedBox(width: 8),
                _StatCard(
                    label: l10n.statsSpaceLabel,
                    value: _fmtBytes(_files!.$2), cs: cs),
              ]),
            ),
          ],
        ],
        ),
      ),
    );
  }

  /// Fill zero-play gaps so the chart has one bar per day/month of the window.
  List<StatsPoint> _filledTimeline() {
    if (_timeline.isEmpty) return _timeline;
    final byLabel = {for (final p in _timeline) p.label: p.count};
    final start = _period.from != null
        ? DateTime.fromMillisecondsSinceEpoch(_period.from! * 1000)
        : _parseLabel(_timeline.first.label);
    final end = _period.to != null
        ? DateTime.fromMillisecondsSinceEpoch(_period.to! * 1000)
            .subtract(const Duration(days: 1))
        : DateTime.now();
    final out = <StatsPoint>[];
    if (_period.byMonth) {
      var d = DateTime(start.year, start.month);
      while (!d.isAfter(end) && out.length < 240) {
        final l = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        out.add(StatsPoint(l, byLabel[l] ?? 0));
        d = DateTime(d.year, d.month + 1);
      }
    } else {
      var d = DateTime(start.year, start.month, start.day);
      while (!d.isAfter(end) && out.length < 240) {
        final l = '${d.year}-${d.month.toString().padLeft(2, '0')}'
            '-${d.day.toString().padLeft(2, '0')}';
        out.add(StatsPoint(l, byLabel[l] ?? 0));
        d = d.add(const Duration(days: 1));
      }
    }
    return out;
  }

  static DateTime _parseLabel(String l) => l.length >= 10
      ? DateTime.parse(l)
      : DateTime(int.parse(l.substring(0, 4)), int.parse(l.substring(5, 7)));
}

// ── Full-list screens ─────────────────────────────────────────────────────────

class _TopTracksScreen extends StatelessWidget {
  final String   title;
  final _Period  period;
  final String?  artist;
  final OnPlayLocalAlbum? onPlay;
  final bool     merged;

  const _TopTracksScreen({
    required this.title,
    required this.period,
    this.artist,
    this.onPlay,
    this.merged = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: FutureBuilder<List<TrackStat>>(
        future: LocalDb.instance.statsTopTracks(
          from: period.from, to: period.to,
          artist: artist, limit: 200, merged: merged,
        ),
        builder: (context, snap) {
          final stats = snap.data;
          if (stats == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (stats.isEmpty) {
            return Center(
                child: Text(context.l10n.statsNoPlays,
                    style: TextStyle(color: cs.outline)));
          }
          return ListView.builder(
            itemCount: stats.length,
            itemBuilder: (_, i) => _TrackRow(
              rank: i + 1,
              stat: stats[i],
              cs:   cs,
              onTap: () => playStatTrack(context, stats, i, onPlay),
            ),
          );
        },
      ),
    );
  }
}

class _TopGroupsScreen extends StatelessWidget {
  final String  title;
  final _Period period;
  final bool    albums;
  final OnPlayLocalAlbum? onPlay;
  final bool    merged;

  const _TopGroupsScreen({
    required this.title,
    required this.period,
    required this.albums,
    this.onPlay,
    this.merged = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: FutureBuilder<List<GroupStat>>(
        future: albums
            ? LocalDb.instance.statsTopAlbums(
                from: period.from, to: period.to, limit: 200, merged: merged)
            : LocalDb.instance.statsTopArtists(
                from: period.from, to: period.to, limit: 200, merged: merged),
        builder: (context, snap) {
          final stats = snap.data;
          if (stats == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (stats.isEmpty) {
            return Center(
                child: Text(context.l10n.statsNoPlays,
                    style: TextStyle(color: cs.outline)));
          }
          return ListView.builder(
            itemCount: stats.length,
            itemBuilder: (_, i) => _GroupRow(
              rank: i + 1,
              stat: stats[i],
              icon: albums ? Icons.album : Icons.person,
              cs:   cs,
              onTap: () => albums
                  ? openStatAlbum(context, stats[i], onPlay)
                  : Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => _TopTracksScreen(
                    title:    stats[i].name,
                    period:   period,
                    artist:   stats[i].key,
                    onPlay:   onPlay,
                    merged:   merged,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Joue la ligne [index] d'un classement.
///
/// En vue fusionnée, une ligne peut porter une piste que cet appareil n'a PAS:
/// son [TrackRecord] est synthétique (`filePath` vide, `onlineId` renseigné
/// quand le catalogue la connaît). Deux chemins, donc:
///  * piste locale → la file est faite des seules pistes locales du
///    classement, sur laquelle l'index est recalé (sinon la file contiendrait
///    des chemins vides et le lecteur échouerait sur la première);
///  * piste absente → on la résout au catalogue puis on la joue comme un
///    résultat de recherche (téléchargement compris).
/// Une piste absente ET sans identité catalogue (un fichier local d'un AUTRE
/// appareil) n'est pas jouable: la ligne reste affichée, elle compte dans les
/// totaux, le tap ne fait rien.
/// Un ALBUM des stats ouvre son ÉCRAN DE DÉTAIL — la tracklist complète, dans
/// l'ordre de l'album, avec ses actions. La liste des meilleures pistes ne
/// montre que ce qui a DÉJÀ été écouté: le sujet des stats, pas ce qu'on
/// demande en tapant un album. `album_key` vaut `COALESCE(album_id,
/// meta_album)`: différent du nom ⇒ c'est un identifiant.
///
/// UNE aide pour TOUS les sites — la première correction n'avait couvert que
/// l'écran « voir tout », et les cinq albums du tableau de bord poussaient
/// toujours la liste.
void openStatAlbum(BuildContext ctx, GroupStat g, OnPlayLocalAlbum? onPlay) {
  Navigator.push<void>(
    ctx,
    MaterialPageRoute(
      // Le MÊME câblage que la poussée du shell (onNavigateAlbum): l'écran
      // n'affiche « Lire l'album » que si onPlayAlbum est fourni, et les
      // entrées « lire ensuite / à la fin » veulent leurs crochets — un écran
      // atteint depuis les stats n'a pas à être moins capable qu'ailleurs.
      builder: (_) => AlbumDetailScreen(
        albumName:  g.name,
        albumId:    g.key == g.name ? null : g.key,
        artworkUrl: g.artworkUrl,
        onTap: globalOnPlayOnlineSong ??
            (BuildContext c, SearchResult r) async {},
        onPlayAlbum:      globalOnPlayAlbum,
        onQueueAdd:       globalOnQueueAdd,
        onAlbumQueueAdd:  globalOnAlbumQueueAdd,
        onPlayLocalAlbum: onPlay,
      ),
    ),
  );
}

Future<void> playStatTrack(BuildContext ctx, List<TrackStat> stats, int index,
    OnPlayLocalAlbum? onPlayLocal) async {
  final t = stats[index].track;
  // Un tap qui ÉCRASERAIT la file demande d'abord — même popup que les rails
  // et les cartes de bibliothèque. `showPlayChoiceSheet` répond `now` sans
  // s'afficher quand il n'y a rien à insérer par rapport à quoi, donc le cas
  // courant ne bouge pas. Les DEUX branches passent par là: la locale écrase
  // la file avec toute la liste de stats, l'autre avec un morceau.
  final choice = await showPlayChoiceSheet(ctx,
      title: t.title, subtitle: t.artist);
  if (choice == null || !ctx.mounted) return;

  if (t.filePath.isNotEmpty) {
    if (choice != PlayChoice.now) {
      await globalOnLocalQueueAdd?.call([t], atEnd: choice == PlayChoice.end);
      return;
    }
    if (onPlayLocal == null) return;
    final local = [for (final s in stats) if (s.track.filePath.isNotEmpty) s.track];
    final start = local.indexWhere((x) => x.id == t.id);
    await onPlayLocal(ctx, local, startIndex: start < 0 ? 0 : start);
    return;
  }
  final id   = t.onlineId;
  if (id == null || id.isEmpty) return;
  final c = await RewampDb.getSongContext(id);
  if (c == null || !ctx.mounted) return;
  // Une ligne du top morceaux désigne UNE sous-chanson précise — c'est le
  // grain du regroupement des stats — donc on joue CELLE-LÀ, jamais la liste
  // ni le fichier entier. Deux pièges fermés ici:
  //  * identité `<uuid>#<rang>` (piste d'un conteneur, venue du compte): le
  //    contexte répond par le CONTENEUR — l'entrée se résout par le RANG
  //    (get_song_entry, repli narrowedToMember), comme partout;
  //  * sinon (hvsc & co: uuid nu + vrai index), la ligne est ÉPINGLÉE
  //    résolue. Sans `resolvedSubsong`, `_startAlbumQueue` prenait un
  //    Commando.sid à 19 sous-chansons pour un conteneur à déplier et
  //    lançait TOUT — y compris pour la sous-chanson 0, que l'ancien code
  //    laissait passer comme « le fichier entier ».
  SearchResult row;
  final hashRank =
      id.contains('#') ? int.tryParse(id.split('#').last) : null;
  if (hashRank != null) {
    row = await RewampDb.getSongEntry(id, entryRank: hashRank) ??
        RewampDb.narrowedToMember(c.song, id);
  } else {
    row = c.song.copyWith(
      subsongIdx: t.subsongIdx,
      resolvedSubsong: true,
      // Le titre de la LIGNE de stats est déjà subsong-scopé (« Commando
      // (3) »); celui du contexte nomme le fichier.
      title: (t.title ?? '').isNotEmpty ? t.title : null,
    );
  }
  if (choice != PlayChoice.now) {
    await globalOnQueueAdd?.call(row, atEnd: choice == PlayChoice.end);
    return;
  }
  // « Lire maintenant » REMPLACE la file (bug constaté: l'album jw_spc en
  // cours restait dans la queue). `globalOnPlayOnlineSong` joue SANS toucher
  // la file — son entonnoir est celui de l'avancement d'album; le crochet du
  // shell fait le remplacement.
  final playNow = globalOnPlayNowSong;
  if (playNow != null) {
    await playNow(row);
    return;
  }
  final play = globalOnPlayOnlineSong;
  if (play == null || !ctx.mounted) return;
  await play(ctx, row);
}

// ── Building blocks ───────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String      label;
  final String      value;
  final ColorScheme cs;

  const _StatCard({required this.label, required this.value, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold, color: cs.primary)),
          ),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

/// Section title without a "see all" action.
class _PlainHeader extends StatelessWidget {
  final String title;
  const _PlainHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

/// Cumulated listening time, compact: "42 min" / "3 h 07 min" / "128 h".
String _fmtListen(int ms) {
  final min = ms ~/ 60000;
  if (min < 1) return '—';
  final h = min ~/ 60, m = min % 60;
  if (h == 0) return '$m min';
  if (h >= 100) return '$h h';
  return '$h h ${m.toString().padLeft(2, '0')}';
}

String _fmtBytes(int b) {
  if (b >= 1 << 30) return '${(b / (1 << 30)).toStringAsFixed(2)} GB';
  if (b >= 1 << 20) return '${(b / (1 << 20)).toStringAsFixed(1)} MB';
  if (b >= 1024)    return '${(b / 1024).toStringAsFixed(0)} KB';
  return '$b B';
}

/// One by-collection/format/engine row: rank, key, plays + listened time.
class _KeyRow extends StatelessWidget {
  final int         rank;
  final KeyStat     stat;
  final ColorScheme cs;
  final bool        upper;   // formats read better upper-cased (S3M, VGM…)

  const _KeyRow({
    required this.rank,
    required this.stat,
    required this.cs,
    this.upper = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: SizedBox(
        width: 24,
        child: Text('$rank',
            textAlign: TextAlign.center,
            style: theme.titleSmall?.copyWith(
                color: cs.outline, fontWeight: FontWeight.bold)),
      ),
      title: Text(upper ? stat.key.toUpperCase() : stat.key,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${stat.plays}',
              style: theme.titleSmall?.copyWith(
                  color: cs.primary, fontWeight: FontWeight.bold)),
          if (stat.listenedMs >= 60000)
            Text(_fmtListen(stat.listenedMs),
                style: theme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String       title;
  final VoidCallback onSeeAll;

  const _SectionHeader({required this.title, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 8, 0),
      child: Row(children: [
        Expanded(
          child: Text(title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
        TextButton(onPressed: onSeeAll, child: Text(context.l10n.statsSeeAll)),
      ]),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int         rank;
  final ColorScheme cs;

  const _RankBadge({required this.rank, required this.cs});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      child: Text('$rank',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
            color: rank <= 3 ? cs.primary : cs.onSurfaceVariant,
          )),
    );
  }
}

class _TrackRow extends StatelessWidget {
  final int           rank;
  final TrackStat     stat;
  final ColorScheme   cs;
  final VoidCallback? onTap;

  const _TrackRow({
    required this.rank,
    required this.stat,
    required this.cs,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = stat.track;
    // Vue fusionnée: une piste écoutée sur un AUTRE appareil n'a pas de
    // fichier ici. Elle compte dans les classements (c'est tout l'objet de la
    // fusion) et se joue par le catalogue quand il la connaît.
    final elsewhere = t.filePath.isEmpty;
    final title = t.displayTitle.isNotEmpty
        ? t.displayTitle
        : (t.onlineId ?? '?');
    return ListTile(
      dense: true,
      leading: Row(mainAxisSize: MainAxisSize.min, children: [
        _RankBadge(rank: rank, cs: cs),
        const SizedBox(width: 8),
        ArtworkImage(
          url:          t.artworkUrl,
          artist:       t.artist,
          album:        t.metaAlbum,
          size:         40,
          borderRadius: BorderRadius.circular(6),
          placeholder:  Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.music_note,
                size: 20, color: cs.onPrimaryContainer),
          ),
        ),
      ]),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: t.artist != null
          ? Text(t.artist!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (elsewhere) ...[
          Icon(Icons.devices_other, size: 14, color: cs.outline),
          const SizedBox(width: 6),
        ],
        Text(context.l10n.statsPlays(stat.plays),
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
      ]),
      onTap: onTap,
    );
  }
}

class _GroupRow extends StatelessWidget {
  final int          rank;
  final GroupStat    stat;
  final IconData     icon;
  final ColorScheme  cs;
  final VoidCallback onTap;

  const _GroupRow({
    required this.rank,
    required this.stat,
    required this.icon,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      dense: true,
      leading: Row(mainAxisSize: MainAxisSize.min, children: [
        _RankBadge(rank: rank, cs: cs),
        const SizedBox(width: 8),
        ArtworkImage(
          url:          stat.artworkUrl,
          artist:       stat.artist ?? (icon == Icons.person ? stat.name : null),
          album:        icon == Icons.album ? stat.name : null,
          size:         40,
          borderRadius: BorderRadius.circular(icon == Icons.person ? 20 : 6),
          placeholder:  Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius:
                  BorderRadius.circular(icon == Icons.person ? 20 : 6),
            ),
            child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
          ),
        ),
      ]),
      title: Text(stat.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${l10n.statsPlays(stat.plays)} · '
        '${l10n.statsTrackCount(stat.trackCount)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// ── Bar chart (custom painted — no dependency) ────────────────────────────────

class _BarChart extends StatelessWidget {
  final List<StatsPoint> points;
  final bool             byMonth;
  /// Label ('YYYY-MM-DD'/'YYYY-MM') of the selected bar, if any.
  final String?          selectedLabel;
  final void Function(String label)? onBarTap;
  final ColorScheme      cs;
  final TextTheme        theme;

  const _BarChart({
    required this.points,
    required this.byMonth,
    this.selectedLabel,
    this.onBarTap,
    required this.cs,
    required this.theme,
  });

  /// Axis tick: "jul 26" (month buckets) / "14/07" (day buckets). The month is
  String _shortLabel(AppLocalizations l10n, String l) => byMonth
      ? '${_monthNameShort(l10n, int.parse(l.substring(5, 7)))}'
          ' ${l.substring(2, 4)}'
      : '${l.substring(8, 10)}/${l.substring(5, 7)}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxCount =
        points.fold<int>(0, (m, p) => p.count > m ? p.count : m);
    final selIdx = selectedLabel == null
        ? -1
        : points.indexWhere((p) => p.label == selectedLabel);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 96,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (ctx, box) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: onBarTap == null
                ? null
                : (d) {
                    final i = (d.localPosition.dx / box.maxWidth * points.length)
                        .floor()
                        .clamp(0, points.length - 1);
                    onBarTap!(points[i].label);
                  },
            child: CustomPaint(
              size: Size(box.maxWidth, 96),
              painter: _BarPainter(
                points:   points,
                max:      maxCount,
                color:    cs.primary,
                selected: selIdx,
                selColor: cs.tertiary,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 2),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_shortLabel(l10n, points.first.label),
              style: theme.bodySmall
                  ?.copyWith(fontSize: 10, color: cs.onSurfaceVariant)),
          Text(l10n.statsChartMax(maxCount),
              style: theme.bodySmall
                  ?.copyWith(fontSize: 10, color: cs.onSurfaceVariant)),
          Text(_shortLabel(l10n, points.last.label),
              style: theme.bodySmall
                  ?.copyWith(fontSize: 10, color: cs.onSurfaceVariant)),
        ],
      ),
    ]);
  }
}

class _BarPainter extends CustomPainter {
  final List<StatsPoint> points;
  final int              max;
  final Color            color;
  final int              selected; // index of the tapped bar, -1 = none
  final Color            selColor;

  _BarPainter({
    required this.points,
    required this.max,
    required this.color,
    this.selected = -1,
    required this.selColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || max <= 0) return;
    final n     = points.length;
    final slot  = size.width / n;
    final gap   = slot > 6 ? 2.0 : (slot > 3 ? 1.0 : 0.0);
    final barW  = (slot - gap).clamp(1.0, double.infinity);
    final track = Paint()..color = color.withValues(alpha: 0.06);
    for (var i = 0; i < n; i++) {
      final x = i * slot + gap / 2;
      // Faint full-height track so empty buckets stay visible (brighter on the
      // selected column so a zero-play selection still shows).
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 0, barW, size.height), const Radius.circular(2)),
        i == selected
            ? (Paint()..color = selColor.withValues(alpha: 0.25))
            : track,
      );
      final h = size.height * points[i].count / max;
      if (h > 0) {
        // With a selection, the other bars dim so the drill target pops.
        final p = Paint()
          ..color = i == selected
              ? selColor
              : (selected >= 0
                  ? color.withValues(alpha: 0.35)
                  : color);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, size.height - h, barW, h),
              const Radius.circular(2)),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.points != points || old.max != max || old.color != color ||
      old.selected != selected || old.selColor != selColor;
}
