import 'dart:io';

import 'package:flutter/material.dart';

import 'favorite_color.dart';
import 'package:rewamp_audio/rewamp_audio.dart' show SubsongInfo, RewampAudio;
import 'l10n.dart';
import 'rewamp_db.dart';
import 'uade_info.dart';
import 'local_db.dart';
import 'artwork_image.dart';
import 'library_button.dart';
import 'player_controller.dart';
import 'playlist_picker.dart';
import 'track_options_sheet.dart'
    show globalOnAlbumQueueAdd, globalOnPlayAlbum, showTrackOptions;

const _kSidExts = {'sid', 'psid', 'rsid', 'mus'};

String _extOf(String path) {
  final dot = path.lastIndexOf('.');
  return dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
}

/// Shown when the user taps a container-format search result (NSF/GBS/AY/…)
/// that has no server-side album.  Downloads the file, probes subsong count +
/// metadata, then lists the subsongs for individual playback.
class ContainerSubsongScreen extends StatefulWidget {
  final SearchResult result;
  /// Callback to actually play a subsong (same signature as search onTap).
  final void Function(BuildContext, SearchResult) onTap;
  /// Plays the whole subsong list as a queue (from "Lire tous les subsongs").
  final Future<void> Function(BuildContext, List<SearchResult>, {int startIndex})?
      onPlayAll;
  /// Skip the picker UI: as soon as the subsong list is known, play all of
  /// them and pop (e.g. tapping a multi-subsong entry in a discovery rail —
  /// no intermediate list, mirrors "tap an album row -> play the album").
  final bool autoPlayAll;
  /// Tapping a composer/artist name in the header (null → not tappable).
  final void Function(String artistName)? onArtistTap;

  const ContainerSubsongScreen({
    super.key,
    required this.result,
    required this.onTap,
    this.onPlayAll,
    this.autoPlayAll = false,
    this.onArtistTap,
  });

  @override
  State<ContainerSubsongScreen> createState() => _ContainerSubsongScreenState();
}

class _ContainerSubsongScreenState extends State<ContainerSubsongScreen> {
  List<SubsongInfo>? _subsongs;
  /// La liste vient-elle de la TRACKLIST SERVEUR (et non de la sonde native) ?
  /// Décide la FORME d'identité des lignes émises — voir _resultFor.
  bool _fromServerTracklist = false;
  bool  _loading = false;
  String? _error;
  bool _isFav = false;
  // On-disk path of the container when it's an app download (under online/) —
  // enables the delete action; null for the user's own local files.
  String? _deletablePath;
  // Path resolved by _probe — the file this screen actually lists.
  String? _resolvedPath;

  /// Display name of the WHOLE container. widget.result may be a library
  /// trace whose title is one SUBSONG's name ('Commando (2)') — deriving row
  /// fallback titles from it persisted 'Commando (2) (N)' titles on play and
  /// polluted the recents. Prefer the real file's basename.
  String get _containerName {
    final lp = _resolvedPath ?? widget.result.localPath;
    // The Amiga prefix convention puts the FORMAT before the dot
    // ("mdat.monkey island"), so basenameWithoutExtension returns "mdat" —
    // which then became the fallback title of every row, and the player's.
    if (lp != null && lp.isNotEmpty) return UadeInfoService.displayName(lp);
    return widget.result.displayTitle;
  }

  // Library/favorite key for the WHOLE song (no subsong suffix), so it's
  // distinct from any single-subsong library entry and relaunch can play all.
  // songId is non-nullable on SearchResult, so the old
  // `?? localPath ?? filename` chain was dead code — but callers still treat a
  // ref id as optional, so keep the nullable type.
  String? get _songRefId => widget.result.songId;

  @override
  void initState() {
    super.initState();
    _probe();
    _resolveDeletable();
    final ref = _songRefId;
    if (ref != null) {
      LocalDb.instance.isLibraryFavorite('track', ref).then((v) {
        if (mounted) setState(() => _isFav = v);
      });
    }
    // Per-subsong scores (mv_subsong_scores via get_song_context) — exactly
    // this picker's question: which subtune do people actually listen to.
    final id = catalogueSongId(widget.result.songId);
    if (id != null) {
      RewampDb.getSongContext(id).then((c) {
        if (mounted && c != null && c.subsongScores.isNotEmpty) {
          setState(() => _scores = c.subsongScores);
        }
      });
    }
  }

  Map<int, SubsongScore> _scores = const {};

  Future<void> _resolveDeletable() async {
    String? fp = widget.result.localPath;
    fp ??= (await LocalDb.instance.getTrackByOnlineId(widget.result.songId))
          ?.filePath;
    if (fp == null) return;
    final sep = Platform.pathSeparator;
    if (!fp.contains('${sep}online$sep')) return;
    if (!await File(fp).exists()) return;
    if (mounted) setState(() => _deletablePath = fp);
  }

  Future<void> _deleteDownload() async {
    final fp = _deletablePath;
    if (fp == null) return;
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.subsongDeleteDownloadTitle),
        content: Text(l10n.subsongDeleteDownloadBody(fp)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.commonDelete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // Stop if this file is playing, drop EVERY queue entry that plays from it
    // (this screen's whole subsong list) and move to the next entry — player
    // closes when nothing follows. Before the delete: it reads the DB rows
    // deleteLocalTrack is about to remove.
    await PlayerController.current?.handleDeletedTrack(fp);
    await RewampDb.deleteLocalTrack(fp);
    if (!mounted) return;
    Navigator.of(context).pop(); // leave the subsong list — file is gone
  }

  Future<void> _toggleFavorite() async {
    final ref = _songRefId;
    if (ref == null) return;
    final r    = widget.result;
    final next = !_isFav;
    setState(() => _isFav = next);
    await LocalDb.instance.setLibraryFavorite(
      type:       'track',
      refId:      ref,
      name:       r.displayTitle,
      artist:     r.artistLabel.isEmpty ? null : r.artistLabel,
      album:      r.album,
      artworkUrl: r.artworkUrl,
      formatExt:  r.formatExt,
      filename:   r.filename,
      value:      next,
    );
  }

  Future<void> _probe() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Server-known tracklist (joshw `subsongs`): list titles/durations without
      // downloading or probing (also dodges non-UTF-8 M3U decode crashes). The
      // file is fetched on play.
      final serverSubs = widget.result.subsongs;
      if (serverSubs.isNotEmpty) {
        setState(() {
          _fromServerTracklist = true;
          _subsongs = [
            for (var i = 0; i < serverSubs.length; i++)
              SubsongInfo(
                index:      i,
                filePath:   '',
                subsongIdx: serverSubs[i].subsong ?? 0,
                title:      serverSubs[i].title,
                durationMs: serverSubs[i].lengthMs,
              ),
          ];
          _loading = false;
        });
        if (widget.autoPlayAll) {
          await _playAll();
          if (mounted) Navigator.pop(context);
        }
        return;
      }

      // Resolve the on-disk file from the local DB FIRST: a library trace
      // routed through the player has no downloadUrl/album/localPath, and
      // handing it to downloadToLibrary throws inside its status guard —
      // flashing a spurious 'Téléchargement impossible' banner even though
      // the fallback then succeeded. DB-first is also the cheap path.
      String? localPathOrNull = widget.result.localPath;
      if (localPathOrNull == null || !await File(localPathOrNull).exists()) {
        final (base, _) = splitLibraryRefId(widget.result.songId);
        final rec = base.isNotEmpty
            ? await LocalDb.instance.getTrackByOnlineId(base)
            : null;
        localPathOrNull =
            (rec != null && await File(rec.filePath).exists())
                ? rec.filePath
                : null;
      }
      final localPath = localPathOrNull ??
          await RewampDb.downloadToLibrary(widget.result);
      _resolvedPath = localPath;
      // Subsong list source depends on where the metadata lives:
      //  - SID: HVSC songlengths + STIL (per-subsong title/artist/duration)
      //    via get_sid_info(md5). The native probe only gives the count.
      //  - UADE formats: the audacious-uade songdb.
      //  - everything else: the native container probe (NSF/GBS header).
      List<SubsongInfo> subs;
      final ext = _extOf(localPath);
      if (_kSidExts.contains(ext)) {
        subs = await _sidSubsongs(localPath);
      } else if (UadeInfoService.isUadePath(localPath)) {
        final info = await UadeInfoService.instance.forPath(localPath);
        // playableSubsongs: the songdb flags NOSOUND slots (silent, length 0),
        // which upstream's own plugin filters out by default.
        final playable = info?.playableSubsongs ?? const [];
        subs = (info != null && playable.isNotEmpty)
            ? [
                for (var i = 0; i < playable.length; i++)
                  SubsongInfo(
                    index:      i,
                    filePath:   localPath,
                    subsongIdx: playable[i].idx,
                    durationMs: playable[i].lengthMs,
                  ),
              ]
            : await RewampDb.probeContainerFile(localPath);
      } else {
        subs = await RewampDb.probeContainerFile(localPath);
      }
      if (!mounted) return;
      if (subs.isEmpty) {
        setState(() {
          _error   = context.l10n.subsongReadTracksFailed;
          _loading = false;
        });
        return;
      }
      // If single subsong, play immediately and pop.
      if (subs.length == 1) {
        setState(() { _loading = false; });
        _play(subs.first);
        if (mounted) Navigator.pop(context);
        return;
      }
      setState(() { _subsongs = subs; _loading = false; });
      if (widget.autoPlayAll) {
        await _playAll();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// SID subsongs from HVSC songlengths + STIL (get_sid_info by md5).
  /// Falls back to the native probe when the md5 is unknown server-side.
  Future<List<SubsongInfo>> _sidSubsongs(String localPath) async {
    final audio = RewampAudio();
    // Native tune count from the SID header — the authoritative subsong count.
    int nativeCount = 0;
    try {
      nativeCount = audio.probeSubsongCount(localPath);
    } catch (_) {}

    SidInfo? info;
    try {
      final md5 = audio.sidMd5(localPath);
      if (md5.isNotEmpty) info = await RewampDb.getSidInfo(md5);
    } catch (_) {}

    // Count = max(header, STIL) so we never drop tunes the header knows about.
    final count = [
      nativeCount,
      info?.subsongCount ?? 0,
      info?.subsongs.length ?? 0,
    ].reduce((a, b) => a > b ? a : b);
    if (count < 1) return RewampDb.probeContainerFile(localPath);

    return [
      for (var i = 0; i < count; i++)
        SubsongInfo(
          index:      i,
          filePath:   localPath,
          subsongIdx: i,   // SID: rewamp subsong idx = 0-based tune index
          // Per-subsong STIL title ONLY — leave null when the tune has just a
          // global title (or none) so the row shows a numbered "Piste N"
          // instead of the same global title repeated on every subsong.
          title:      info?.perSubsongNameFor(i),
          durationMs: info?.lengthFor(i),
        ),
    ];
  }

  SearchResult _resultFor(SubsongInfo sub) {
    final r = widget.result;
    // La FORME d'identité suit la SOURCE de la liste.
    // Tracklist serveur → `<uuid>#<rang>`,
    // comme les dépliages: ce même fichier joué depuis un album produit des
    // clés de compte en RANG, et cet écran était le SEUL à produire des clés
    // « vrai index » pour un fichier à tracklist — deux lignes de compte pour
    // la même sous-chanson dès que rang ≠ index (.gbs à NOSOUND, .kss
    // absolu). Sonde native (pas de tracklist) → songId nu + vrai index,
    // l'invariant de cette population-là.
    final entryId = _fromServerTracklist
        ? '${r.songId.split('#').first}#${sub.index}'
        : r.songId;
    return SearchResult(
      songId:      entryId,
      collection:  r.collection,
      title:       sub.title ?? '$_containerName (${sub.index + 1})',
      filename:    r.filename,
      // JAMAIS `?? _containerName`: le nom d'album entre dans le CHEMIN de
      // téléchargement (_dirSegments range un album sous son niveau à lui), donc
      // inventer un album pour un fichier qui n'en a pas déplace le fichier —
      // et le renommer le déplace encore. Mesuré: le même module a fini sous
      // « …/amiga/mdat.monkey island » ET « …/amiga/monkey island/mdat.monkey
      // island », avec deux jeux de lignes `tracks` et un téléchargement en
      // double. Le nom du conteneur ne sert qu'à TITRER les lignes ci-dessus.
      album:       r.album,
      formatExt:   r.formatExt,
      downloadUrl: r.downloadUrl,
      fileSize:    r.fileSize,
      year:        r.year,
      totalCount:  r.totalCount,
      artistNames: r.artistNames,
      platform:    r.platform,
      artworkUrl:  r.artworkUrl,
      subsongIdx:  sub.subsongIdx,
      // Le compte décrit le FICHIER, donc identique sur toutes ses lignes —
      // c'est ce qui permet à la base de répondre « ce fichier est-il
      // multi-sous-chansons ? » hors ligne. Le « cette ligne est déjà résolue »
      // est un drapeau à part.
      subsongCount:    _subsongs?.length ?? r.subsongCount,
      resolvedSubsong: true,
      // Carry the sibling list (UADE multifile: TFMX mdat needs smpl) for aux
      // file resolution.
      //
      // Ce `subsongCount` valait 1 — pas un compte, une SENTINELLE « cette
      // ligne n'a plus rien à déplier », sans quoi `_subsongEntries` re-dépliait
      // chaque entrée déjà résolue (N sous-chansons -> N*N entrées de file, le
      // symptôme audible étant que toutes affichaient la durée de la première).
      // La sentinelle est maintenant `resolvedSubsong`, et le compte peut enfin
      // dire ce que son nom annonce.
      auxFiles:    r.auxFiles,
      durationMs:  sub.durationMs,
      // Point at the already-extracted local file so play resolves it directly
      // instead of attempting a (failing) re-download — the container may have
      // no downloadUrl (e.g. opened from the player with only a localPath).
      localPath:   sub.filePath.isNotEmpty ? sub.filePath : r.localPath,
    );
  }

  /// PAS de popup ici: on est DANS la liste des sous-chansons du fichier, et le
  /// tap initialise la file avec TOUTES en démarrant sur celle-ci — comme un
  /// écran d'album. Jouer la seule sous-chanson touchée laissait une file d'un
  /// élément et la lecture s'arrêtait à la fin du morceau.
  Future<void> _play(SubsongInfo sub) async {
    final subs = _subsongs;
    final playAll = widget.onPlayAll ?? globalOnPlayAlbum;
    if (subs != null && subs.isNotEmpty && playAll != null) {
      final start = subs.indexWhere((x) => x.subsongIdx == sub.subsongIdx);
      await playAll(context, subs.map(_resultFor).toList(),
          startIndex: start < 0 ? 0 : start);
      return;
    }
    widget.onTap(context, _resultFor(sub));
  }

  Future<void> _playAll() async {
    final subs = _subsongs;
    if (subs == null || subs.isEmpty) return;
    final list = subs.map(_resultFor).toList();
    final playAll = widget.onPlayAll ?? globalOnPlayAlbum;
    if (playAll != null) {
      await playAll(context, list);
    } else {
      widget.onTap(context, list.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;
    final r    = widget.result;
    final subs = _subsongs;

    return Scaffold(
      appBar: AppBar(
        title: Text(_containerName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(r.formatExt.toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: cs.error),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                          onPressed: _probe,
                          child: Text(l10n.commonRetry)),
                    ],
                  ),
                )
              : subs == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        _header(context, l10n, cs, r, subs.length),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.builder(
                            itemCount: subs.length,
                            itemBuilder: (_, i) {
                              final sub = subs[i];
                              final title = sub.title?.isNotEmpty == true
                                  ? sub.title!
                                  : l10n.subsongTrackNumber(sub.index + 1);
                              final dur = sub.durationMs != null
                                  ? _formatDuration(sub.durationMs!)
                                  : null;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: cs.primaryContainer,
                                  child: Text('${sub.index + 1}',
                                      style: TextStyle(
                                          color: cs.onPrimaryContainer,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                ),
                                title: Text(title,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                // Like album rows: a per-row play button before
                                // the "…" overflow (whole-row tap still plays).
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Subsong-grain scores. Popularity FIRST
                                    // (rating is NULL under 5 listeners, near
                                    // always at this grain). Threshold 50, not
                                    // the listings' 95: a picker compares the
                                    // subtunes of ONE file with each other,
                                    // and « Top 32 % » vs nothing is exactly
                                    // the signal that picks the good one.
                                    ...(() {
                                      final sc = _scores[subs[i].index];
                                      if (sc == null) return const <Widget>[];
                                      return <Widget>[
                                        if (sc.rating != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 6),
                                            child: Text(
                                                '★ ${sc.rating!.toStringAsFixed(1)}',
                                                style: const TextStyle(
                                                    fontSize: 10)),
                                          ),
                                        if ((sc.popularity ?? 0) >= 50)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 6),
                                            child: Text(
                                              context.l10n.statsTopPercent(
                                                  (100 - sc.popularity!)
                                                      .clamp(1, 100)),
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: cs.primary),
                                            ),
                                          ),
                                      ];
                                    })(),
                                    if (dur != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 4),
                                        child: Text(dur,
                                            style: TextStyle(
                                                color: cs.onSurfaceVariant,
                                                fontSize: 12)),
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.play_arrow,
                                          size: 22),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 36, minHeight: 36),
                                      onPressed: () => _play(sub),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.more_vert,
                                          size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 36, minHeight: 36),
                                      onPressed: () => showTrackOptions(
                                        context, _resultFor(sub),
                                        onNavigateArtist: widget.onArtistTap ==
                                                null
                                            ? null
                                            : (name, {collection, artistId}) =>
                                                widget.onArtistTap!(name),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () => _play(sub),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }

  // Album-detail-style header: artwork, title, platform/year, tappable
  // artists, subsong count + size, and Play-all / library / favourite actions.
  Widget _header(BuildContext context, AppLocalizations l10n, ColorScheme cs,
      SearchResult r, int count) {
    final tt = Theme.of(context).textTheme;
    final subline = <String>[
      if (r.platform != null && r.platform!.isNotEmpty) r.platform!,
      if (r.year != null) r.year.toString(),
    ].join(' · ');
    final meta = <String>[
      l10n.subsongCount(count),
      if (r.fileSize > 0) _formatSize(l10n, r.fileSize),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ArtworkImage(
                  url:           r.artworkUrl,
                  // Le fichier RÉSOLU quand la sonde l'a trouvé: c'est lui qui
                  // porte une éventuelle pochette voisine, et la ligne de
                  // recherche n'a pas encore de chemin local.
                  localFilePath: _resolvedPath ?? r.localPath,
                  artist:        r.artistNames.isNotEmpty ? r.artistNames.first : null,
                  album:         r.album,
                  // Sans ces deux signaux le placeholder tombait sur le
                  // générique: le chemin manque tant que rien n'est
                  // téléchargé, et un nom Amiga porte de toute façon son
                  // format AVANT le point.
                  platformName:  r.platform,
                  formatHint:    r.formatExt,
                  size:          88,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.displayTitle,
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (subline.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subline, style: tt.bodyMedium?.copyWith(color: cs.primary)),
                    ],
                    if (r.artistNames.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        children: [
                          for (int i = 0; i < r.artistNames.length; i++) ...[
                            GestureDetector(
                              onTap: widget.onArtistTap != null
                                  ? () => widget.onArtistTap!(r.artistNames[i])
                                  : null,
                              child: Text(
                                r.artistNames[i],
                                style: tt.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: widget.onArtistTap != null
                                      ? cs.primary : cs.onSurfaceVariant,
                                  decoration: widget.onArtistTap != null
                                      ? TextDecoration.underline : null,
                                ),
                              ),
                            ),
                            if (i < r.artistNames.length - 1)
                              Text(', ', style: tt.bodySmall),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(meta,
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _playAll,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.commonPlayAll),
              ),
              const Spacer(),
              IconButton(
                tooltip: _isFav
                    ? l10n.commonRemoveFromFavorites
                    : l10n.commonAddToFavorites,
                icon: Icon(_isFav ? Icons.star : Icons.star_border,
                    color: _isFav ? kFavoriteColor : null),
                onPressed: _songRefId == null ? null : _toggleFavorite,
              ),
              if (_songRefId != null)
                LibraryButton(
                  type:       'track',
                  refId:      _songRefId!,
                  name:       r.displayTitle,
                  artist:     r.artistLabel.isEmpty ? null : r.artistLabel,
                  album:      r.album,
                  artworkUrl: r.artworkUrl,
                  formatExt:  r.formatExt,
                  filename:   r.filename,
                  onDownload: () => RewampDb.downloadToLibrary(r),
                ),
              // "…" menu — same placement as the album screen (right of the
              // action row): queue + playlist for the whole subsong list,
              // delete only for app downloads (under online/).
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: l10n.commonOptions,
                onSelected: (v) {
                  final subs = _subsongs;
                  final rows = subs == null
                      ? <SearchResult>[]
                      : subs.map(_resultFor).toList();
                  switch (v) {
                    case 'next':
                      (globalOnAlbumQueueAdd)?.call(rows, atEnd: false);
                    case 'end':
                      (globalOnAlbumQueueAdd)?.call(rows, atEnd: true);
                    case 'playlist':
                      showAddToPlaylistSheet(context,
                          resolveTrackIds: () => trackIdsForResults(rows));
                    case 'delete':
                      _deleteDownload();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'playlist',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.playlist_add),
                      title: Text(l10n.commonAddToPlaylist),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'next',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.queue_play_next_outlined),
                      title: Text(l10n.commonPlayNext),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'end',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.add_to_queue_outlined),
                      title: Text(l10n.commonAddToQueueEnd),
                    ),
                  ),
                  if (_deletablePath != null)
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.delete_outline),
                        title: Text(l10n.commonDeleteDownload),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatSize(AppLocalizations l10n, int bytes) {
    if (bytes >= 1024 * 1024) {
      return l10n.unitMegabytes((bytes / (1024 * 1024)).toStringAsFixed(1));
    }
    if (bytes >= 1024) {
      return l10n.unitKilobytes((bytes / 1024).toStringAsFixed(0));
    }
    return l10n.unitBytes('$bytes');
  }

  static String _formatDuration(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}
