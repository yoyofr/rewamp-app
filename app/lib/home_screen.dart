import 'dart:io';

import 'package:flutter/material.dart';
import 'app_snack.dart';

import 'browse_screen.dart' show PlaylistTracksScreen;
import 'favorite_color.dart';
import 'featured_reason.dart';
import 'home_refresh.dart';
import 'home_sections.dart';
import 'hover_grow.dart';
import 'local_badge.dart';
import 'marquee_text.dart';
import 'track_options_sheet.dart'
    show globalOnAlbumQueueAdd, globalOnLocalQueueAdd, globalOnQueueAdd,
         globalOnStartFeaturedRadio, showPlayChoiceSheet, PlayChoice;
import 'charts_screen.dart' show ChartMode, ChartResultsScreen;
import 'competition_screen.dart';
import 'l10n.dart';
import 'local_open.dart';
import 'uade_info.dart';
import 'local_db.dart' show LocalDb, TrackRecord, RecentEntry, TrackStat;
import 'note_markdown.dart';
import 'player_controller.dart';
import 'search_screen.dart'   show OnFileReady, downloadAndPlay;
import 'artwork_image.dart';
import 'horizontal_scroll_arrows.dart';
import 'rewamp_db.dart'
    show FeaturedSlot, OnPlayAlbum, OnPlayLocalAlbum, Playlist, RewampDb,
         SearchResult;
import 'formats.dart' show kAllDecoderExts;
import 'stats_screen.dart' show LocalTopTracksScreen;
import 'user_settings.dart';
import 'shell_insets.dart';

// Formats that may contain multiple subsongs — trigger queue setup on open.
// UADE multi-subsong files (TFMX, some FC/…) are handled separately below by
// path detection (UadeInfoService.isUadePath), not by extension, so they don't
// need an entry here.

/// Faut-il compléter la liste d'un album LOCAL en scannant son dossier ?
///
/// Non quand l'album a reçu sa liste COMPLÈTE du catalogue
/// (`album_materialised`): elle fait autorité et le dossier en contient
/// davantage — « Wild Arms 3 » (jw_psf2) a 115 pistes au catalogue et 138
/// fichiers d'allure audio sur le disque (doublons `[jp]`/`[us]`, `.vgmstream`
/// non listés). Sinon oui, mais seulement si la base n'a rien apporté de plus
/// que ce qu'elle contenait: les branches précédentes (M3U, sous-chansons,
/// songdb UADE) ont pu déplier la liste, et le scan les écraserait.
///
/// Et JAMAIS pour un album sans identité catalogue. Le scan prend le dossier
/// PARENT du premier fichier connu pour « le dossier de l'album » — vrai d'un
/// album téléchargé (`online/<collection>/<uuid>/` lui est dédié), faux d'un
/// fichier LOCAL dont l'album vient des tags: un `.hip` posé à la RACINE des
/// imports a pour parent `local/` tout entier. Mesuré le 2026-09-04 sur « The
/// Seven Gates of Jambala »: relancé depuis les récents, l'album devenait une
/// file de 200 pistes qui démarrait sur Battle Garegga, chacune estampillée de
/// la pochette et de l'album de Jambala — puis PERSISTÉE ainsi par la lecture
/// (`_persistPlay`), d'où des lignes Garegga portant le `.gif` de Jambala. Un
/// album local n'a pas besoin du scan: l'import enregistre chaque fichier de
/// son dossier, la base EST sa liste.
///
/// Pur et hors classe pour être testable — construire l'écran d'accueil
/// appellerait le natif.
bool shouldScanAlbumDirectory({
  required bool catalogueAlbum,
  required bool materialised,
  required int tracks,
  required int dbTracks,
}) =>
    catalogueAlbum && !materialised && tracks > 0 && tracks == dbTracks;


class HomeScreen extends StatelessWidget {
  final PlayerController  controller;
  final OnFileReady       onFileReady;
  final OnPlayAlbum?      onPlayAlbum;
  final OnPlayLocalAlbum? onPlayLocalAlbum;
  /// « Lire ensuite » / « Ajouter à la fin » pour les fichiers ouverts par le
  /// sélecteur local. Sans lui la feuille de choix n'aurait que « maintenant ».
  final Future<void> Function(List<TrackRecord>, {required bool atEnd})?
      onLocalTracksQueueAdd;
  /// Called when a single local file is opened via the file picker.
  /// AppShell clears both queues then plays the file.
  final OnFileReady?      onPlaySingleLocalFile;

  const HomeScreen({
    super.key,
    required this.controller,
    required this.onFileReady,
    this.onPlayAlbum,
    this.onPlayLocalAlbum,
    this.onLocalTracksQueueAdd,
    this.onPlaySingleLocalFile,
  });

  // Canonical decoder groups (lib/formats.dart) + vgmstream's 700+ set +
  // the container list — the single source of truth, shared with the archive
  // extractor (RewampDb._kExtractedAudioExts). Used by the file picker and the
  // folder scan (.contains).
  static final _audioExtensions = <String>{
    ...kAllDecoderExts,
    ...RewampDb.kVgmstreamExts,
    ...RewampDb.kContainerFormats,
  };



  // ── Online discovery rails: tap handlers ────────────────────────────────

  /// Popular-rail rows are display-only (no download_url) and, since
  /// migration 107, may be an ALBUM-aggregate row (item_type="album", all of
  /// an album's tracks collapsed into one stats entry) rather than a song.
  /// Album → play the whole album; multi-subsong file → play every subsong;
  /// plain song → resolve via get_song_context, then downloadAndPlay.
  Future<void> _playOnlineSong(BuildContext ctx, SearchResult r) async {
    final l10n = ctx.l10n;
    // Same play-choice popup as the recents rail (skips itself when nothing
    // is playing). Covers Tendances / Top all-time / featured songs — they
    // all route through here.
    final choice = await showPlayChoiceSheet(ctx,
        title: r.displayTitle,
        subtitle: r.artistLabel.isEmpty ? null : r.artistLabel,
        result: r);
    if (choice == null || !ctx.mounted) return;
    final asQueueAdd = choice != PlayChoice.now;
    if (r.isAlbumRow) {
      if (r.albumId == null || onPlayAlbum == null) return;
      try {
        // sortBy: 'position' — the default ('track') doesn't sort the way
        // AlbumDetailScreen's own fetches do (which all use 'position'),
        // scrambling both track order and, downstream, which title lands on
        // which queue slot.
        final fetched = await RewampDb.albumTracks(
            albumId: r.albumId!, sortBy: 'position');
        // Un seul geste, quel que soit le type: l'œuvre entière, TOURNÉE à
        // partir de son entrée la plus écoutée (comme un « tout lire » qui
        // démarre au sous-chant de départ: 5 pistes, 3e ⇒ 3,4,5,1,2).
        final tracks = rotateToDefaultSubsong(
            fetched, RewampDb.topEntryIndex(fetched, r));
        if (tracks.isNotEmpty && ctx.mounted) {
          if (asQueueAdd && globalOnAlbumQueueAdd != null) {
            await globalOnAlbumQueueAdd!(tracks,
                atEnd: choice == PlayChoice.end, silent: false);
          } else {
            await onPlayAlbum!(ctx, tracks);
          }
        }
      } catch (_) {
        if (ctx.mounted) {
          AppSnack.show(ctx, l10n.homeAlbumLoadFailed);
        }
      }
      return;
    }

    var resolved = r;
    if (r.downloadUrl == null || r.downloadUrl!.isEmpty) {
      final c = await RewampDb.getSongContext(r.songId);
      if (c == null) {
        if (ctx.mounted) {
          AppSnack.show(ctx, l10n.homeSongLoadFailed);
        }
        return;
      }
      // Une ligne de palmarès reste un CONTENEUR: on reporte l'entrée la plus
      // écoutée (rotation en aval), on ne l'épingle pas à une sous-chanson.
      resolved = r.topSubsongIndex != null
          ? c.song.copyWith(
              subsongIdx: r.subsongIdx,
              topSongId: r.topSongId,
              topSubsongIndex: r.topSubsongIndex)
          : (r.subsongIdx != 0 ? c.song.withSubsong(r.subsongIdx) : c.song);
    }
    if (!ctx.mounted) return;

    // Multi-subsong file (NSF/GBS/SID/…): play every subsong as a queue,
    // directly — no intermediate ContainerSubsongScreen flash. _startAlbumQueue
    // → _subsongEntries expands the subsongs (server list / SID STIL / probe).
    if (RewampDb.isContainerRow(resolved) && onPlayAlbum != null) {
      if (asQueueAdd && globalOnAlbumQueueAdd != null) {
        // _onAlbumQueueAdd expands the container's subsongs itself.
        await globalOnAlbumQueueAdd!([resolved],
            atEnd: choice == PlayChoice.end, silent: false);
      } else {
        await onPlayAlbum!(ctx, [resolved]);
      }
      return;
    }

    if (asQueueAdd && globalOnQueueAdd != null) {
      await globalOnQueueAdd!(resolved, atEnd: choice == PlayChoice.end);
      return;
    }
    // Standalone single song from a rail → clear any existing queue (a leftover
    // album/queue must not linger with prev/next).
    await downloadAndPlay(ctx, resolved, onPlaySingleLocalFile ?? onFileReady);
  }

  /// A featured slot is a playlist, an album or a song — each already has a
  /// play path, so this only routes to the right one.
  Future<void> _playFeatured(BuildContext ctx, FeaturedSlot s) async {
    final l10n = ctx.l10n;
    switch (s.kind) {
      case 'playlist':
        // Open the playlist rather than playing it: a Hall of Fame list is
        // something you want to look at first — see the ranking, pick a track —
        // not something to start blind from its first entry.
        final reason = featuredReasonText(ctx, s);
        await Navigator.of(ctx).push(MaterialPageRoute(
          builder: (_) => PlaylistTracksScreen(
            playlist: Playlist(
                id: s.id, slug: '', name: s.name,
                coverUrl: s.artworkUrl, trackCount: s.trackCount,
                // Community card: keep the credit on the screen it opens —
                // the header renders it from this field.
                authorName: s.authorName),
            onTap: (c, r) => downloadAndPlay(
                c, r, onPlaySingleLocalFile ?? onFileReady),
            onPlayAlbum: onPlayAlbum,
            note: reason,   // no room on the card — read it here
          ),
        ));
      case 'album':
        if (onPlayAlbum == null) return;
        // « Voir l'album » aussi depuis une carte du rail. La feuille déduit
        // ses tuiles de la LIGNE, et une carte d'album n'en passait aucune —
        // le tap ne menait donc qu'à la lecture. La section « Nouveautés du
        // catalogue » (mig serveur 258) en apporte jusqu'à 24 d'un coup, ce
        // qui rend le manque voyant.
        //
        // Le slot n'est pas une piste: on fabrique la ligne minimale que la
        // feuille sait lire — nom d'album et uuid, seuls champs dont la tuile
        // « Voir l'album » a besoin. Pas de `subsongCount`, donc aucune tuile
        // de sous-chansons, ce qui est juste: un album n'est pas un fichier.
        final choice = await showPlayChoiceSheet(ctx,
            title: s.name,
            track: TrackRecord(
              id:           '',
              filePath:     '',
              entryPath:    '',
              subsongIdx:   0,
              title:        s.name,
              metaAlbum:    s.name,
              albumId:      s.id,
              artworkUrl:   s.artworkUrl,
              collectionSlug: s.collection,
              source:       'online',
              isFavorite:   false,
              inLibrary:    false,
              playCount:    0,
            ));
        if (choice == null || !ctx.mounted) return;
        try {
          final tracks =
              await RewampDb.albumTracks(albumId: s.id, sortBy: 'position');
          if (tracks.isNotEmpty && ctx.mounted) {
            if (choice != PlayChoice.now && globalOnAlbumQueueAdd != null) {
              await globalOnAlbumQueueAdd!(tracks,
                  atEnd: choice == PlayChoice.end, silent: false);
            } else {
              await onPlayAlbum!(ctx, tracks);
            }
          }
        } catch (_) {
          if (ctx.mounted) {
            AppSnack.show(ctx, l10n.homeAlbumLoadFailed);
          }
        }
      case 'competition':
        // A compo has an INTEGER id, which cannot travel in the uuid `id`
        // column: it comes in competition_id, and `id` is null. Routing on the
        // id instead of the kind produced a dead card (mig 186).
        final compId = s.competitionId;
        if (compId == null) return;
        await openCompetition(ctx,
            competitionId: compId,
            title: s.name,
            note: featuredReasonText(ctx, s));
      default: // 'song'
        final c = await RewampDb.getSongContext(s.id);
        if (c == null) {
          if (ctx.mounted) {
            AppSnack.show(ctx, l10n.homeSongLoadFailed);
          }
          return;
        }
        if (ctx.mounted) await _playOnlineSong(ctx, c.song);
    }
  }

  /// Opens the second level: the list of playlists in a featured series. Picking
  /// one lands on the same [PlaylistTracksScreen] a standalone card would.
  Future<void> _openFeaturedSeries(BuildContext ctx, String label,
      String header, List<FeaturedSlot> slots) async {
    await Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => FeaturedSeriesScreen(
        title:  label,
        header: header,
        slots:  slots,
        onTap:  _playFeatured,   // each entry is a playlist → same routing
        onPlayAlbum: onPlayAlbum, // enables the whole-series play-all / radio
      ),
    ));
  }


  @override
  Widget build(BuildContext context) {
    final l10n       = context.l10n;
    final textTheme  = Theme.of(context).textTheme;
    final cs         = Theme.of(context).colorScheme;
    // viewPadding.top = physical status-bar height, reliable in nested Scaffolds
    final statusBarH = MediaQuery.of(context).viewPadding.top;

    return Scaffold(
      body: ShaderMask(
        // Fades content at the top (status-bar overlap) and at the bottom.
        // ShaderMask is GPU-composited and transparent to hit-testing —
        // unlike Stack+Positioned overlays it doesn't introduce unlaid-out
        // render boxes that trigger the iOS status-bar tap assertion crash.
        blendMode: BlendMode.dstIn,
        shaderCallback: (Rect rect) {
          if (rect.height == 0) {
            return const LinearGradient(
              colors: [Colors.black, Colors.black],
            ).createShader(rect);
          }
          final topStop    = ((statusBarH + 16) / rect.height).clamp(0.0, 0.4);
          final bottomStop = (1.0 - 60.0 / rect.height).clamp(topStop, 0.98);
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Colors.transparent, Colors.black,
              Colors.black,       Colors.transparent,
            ],
            stops: [0.0, topStop, bottomStop, 1.0],
          ).createShader(rect);
        },
        child: ListenableBuilder(
            // Les réglages AUSSI: l'ordre des sections est relu à chaque build,
            // et sans cette écoute revenir de l'éditeur ne redessinerait rien
            // (le lecteur, lui, n'a pas bougé). `Listenable.merge` plutôt qu'un
            // second builder imbriqué: une seule reconstruction par événement.
            listenable: Listenable.merge([controller, UserSettings.instance]),
            builder: (context, _) {
              // Chaque section est une LISTE de slivers (un en-tête + son
              // rail), rangée sous son identifiant: l'ordre d'affichage est
              // celui que l'utilisateur a choisi (voir home_sections.dart), et
              // il est relu à CHAQUE build — `UserSettings` étant un
              // ChangeNotifier, revenir de l'éditeur suffit à réordonner.
              final sections = <HomeSection, List<Widget>>{
                // ── Recently played ────────────────────────────────────────
                HomeSection.recents: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, _kSectionTopGap, 16, 8),
                    child: Text(
                      l10n.recentlyPlayed,
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _RecentRow(
                    entries:  controller.recentEntries,
                    cs:       cs,
                    theme:    textTheme,
                    l10n:     l10n,
                    onTap: (ctx, entry) async {
                      // Choice FIRST (cheap, immediate), resolution after: the
                      // entry resolves into the exact same track lists either
                      // way, only the terminal action differs (replace queue /
                      // insert next / append).
                      // La LIGNE, pas seulement son libellé: sans elle la
                      // feuille n'a rien à interroger et n'offre que les trois
                      // choix de lecture — un module multi-sous-chansons
                      // rejoué depuis les récents ne proposait donc pas
                      // « Voir les sous-chansons », alors que c'est justement
                      // le geste qui doit REDÉPLIER.
                      //
                      // ⚠️ Passée AUSSI pour une entrée d'ALBUM, alors que je
                      // l'en avais d'abord exclue: la feuille déduit ses tuiles
                      // de la ligne, donc l'exclure supprimait « Voir l'album »
                      // là où il a le plus de sens. Rien à filtrer ici — une
                      // entrée d'album n'a pas de `subsongCount` (la moitié
                      // ALBUM de la requête rend NULL), donc la tuile des
                      // sous-chansons ne s'affiche pas d'elle-même.
                      final choice = await showPlayChoiceSheet(ctx,
                          title: entry.label,
                          subtitle: entry.artist,
                          track: entry.asTrackRecord());
                      if (choice == null || !ctx.mounted) return;
                      final queueLocal  = globalOnLocalQueueAdd;
                      final queueOnline = globalOnAlbumQueueAdd;
                      final asQueueAdd  = choice != PlayChoice.now;
                      if (entry.isAlbum && entry.metaAlbum != null) {
                        // Local-file album (e.g. RSN already cached): rebuild
                        // queue from local DB so subsong indices are correct
                        // and no re-download is attempted.
                        if (onPlayLocalAlbum != null) {
                          try {
                            // Resolve the exact album: by server album_id when
                            // known, else by name scoped to this entry's folder
                            // (so two same-named albums in different collections
                            // don't get mixed). Covers multi-file albums (one
                            // .vgz per track).
                            List<TrackRecord> dbTracks = await LocalDb.instance
                                .getTracksForAlbum(
                              entry.metaAlbum!,
                              albumId: entry.albumId,
                              nearFilePath: entry.filePath,
                            );

                            // Single-file multi-subsong (RSN/NSF): fall back
                            // to file-based query.
                            if (dbTracks.length <= 1 &&
                                await File(entry.filePath).exists()) {
                              dbTracks = await LocalDb.instance
                                  .getTracksForFile(entry.filePath);
                            }

                            List<TrackRecord> tracks = dbTracks;

                            // Single-file multi-subsong (SID/NSF/GBS/…): DB
                            // only contains previously-played subsongs.  Ask
                            // the native decoder for the real count and fill
                            // the gaps so the full queue is always available.
                            if (dbTracks.isNotEmpty) {
                              final fp  = dbTracks.first.filePath;
                              final ext = fp.split('.').last.toLowerCase();
                              final allSameFile = dbTracks.every(
                                  (t) => t.filePath == fp);
                              // UADE FIRST, and not through kMultiTrackExts:
                              // that gate reads the last dot, and an Amiga name
                              // carries its format BEFORE it ("mdat.monkey
                              // island" → ext "monkey island"), so no gate ever
                              // matched and the queue stayed at the handful of
                              // subsongs that happened to have been played —
                              // "it resumes where I left off and loads nothing
                              // else". The songdb owns that list (real idx
                              // values, NOSOUND slots dropped, per-subsong
                              // lengths); the native probe cannot count them.
                              if (allSameFile &&
                                  UadeInfoService.isUadePath(fp)) {
                                final rows = await _uadeSubsongRows(
                                    fp, dbTracks, dbTracks.first);
                                if (rows.length > dbTracks.length) tracks = rows;
                              } else if (allSameFile &&
                                  kMultiTrackExts.contains(ext)) {
                                // For joshw-style files an M3U alongside the
                                // audio file defines the real track list.
                                // Prefer it over C probe (which returns the raw
                                // subsong count including sound-effect entries).
                                final m3uSubs =
                                    await RewampDb.probeLocalM3u(fp);
                                if (m3uSubs != null && m3uSubs.isNotEmpty) {
                                  // Key DB rows by (file, subsong): mixed
                                  // albums (jw_hes = .hes subsongs + .ape CD
                                  // tracks in one M3U) reuse subsong indices
                                  // across different files.
                                  final byKey = {
                                    for (final t in dbTracks)
                                      '${t.filePath.toLowerCase()}#${t.subsongIdx}': t
                                  };
                                  // NO identity is invented for a subsong that
                                  // was never played: inside a container each
                                  // entry has its own `<uuid>#<rank>`, and the
                                  // rank is NOT the subsong index (measured on
                                  // a joshw .gbs: subsong 12 carries `#13`).
                                  // `byKey` above returns the real row when
                                  // there is one; the rest keep a null id and
                                  // still display their collection, which the
                                  // player now reads off the on-disk path.
                                  final ref = dbTracks.first;
                                  tracks = m3uSubs.map((s) {
                                    // Honor the M3U entry's OWN file — using
                                    // the container path for every row made
                                    // the .ape entries play the .hes instead.
                                    final entryPath = s.filePath;
                                    final entryExt = entryPath
                                        .split('.')
                                        .last
                                        .toLowerCase();
                                    final key =
                                        '${entryPath.toLowerCase()}#${s.subsongIdx}';
                                    if (byKey.containsKey(key)) {
                                      return byKey[key]!;
                                    }
                                    return TrackRecord(
                                      id:         '',
                                      filePath:   entryPath,
                                      entryPath:  '',
                                      subsongIdx: s.subsongIdx,
                                      title:      s.title ?? '${s.index + 1}',
                                      artist:     ref.artist,
                                      metaAlbum:  ref.metaAlbum,
                                      artworkUrl: ref.artworkUrl,
                                      // Carry the M3U duration — without it the
                                      // player falls back to the decoder default
                                      // (5:05) for never-played subsongs.
                                      durationS:  s.durationMs != null
                                          ? s.durationMs! / 1000.0
                                          : null,
                                      formatExt:  entryExt.isNotEmpty
                                          ? entryExt
                                          : ext,
                                      albumId:    ref.albumId,
                                      source:     ref.source,
                                      isFavorite: false,
                                      inLibrary:  false,
                                      playCount:  0,
                                    );
                                  }).toList();
                                } else {
                                  // Prefer the server's subsong count for an
                                  // online container: the native probe returns a
                                  // format default (HES → 256) when the file
                                  // carries no count, enqueuing phantom subsongs.
                                  // Persisted count first (works OFFLINE), then
                                  // the server, then the native probe.
                                  int count = dbTracks.first.subsongCount ?? 0;
                                  // Per-subsong rows persist onlineId as
                                  // '<songId>#<idx>' (subsongRowsFromServer) —
                                  // strip the suffix or the RPC finds nothing.
                                  final onlineId = dbTracks.first.onlineId
                                      ?.split('#')
                                      .first;
                                  if (count <= 1 &&
                                      onlineId != null && onlineId.isNotEmpty) {
                                    try {
                                      count = (await RewampDb.getSongContext(
                                                  onlineId))
                                              ?.song
                                              .subsongCount ??
                                          0;
                                    } catch (_) {/* best-effort */}
                                  }
                                  if (count <= 1) {
                                    try {
                                      count = controller.audio
                                          .probeSubsongCount(fp);
                                    } catch (_) {}
                                  }
                                  if (count > dbTracks.length) {
                                    final byIdx = {
                                      for (final t in dbTracks) t.subsongIdx: t
                                    };
                                    final ref      = dbTracks.first;
                                    final baseName = fp
                                        .split(Platform.pathSeparator)
                                        .last
                                        .replaceAll(RegExp(r'\.\w+$'), '');
                                    // ⚠️ La POSITION n'est pas l'index: une
                                    // liste peut être CREUSE (`.adl`). Voir
                                    // subsongIndicesFor.
                                    final idx = subsongIndicesFor(
                                        fp, controller, count);
                                    tracks = List.generate(count, (i) {
                                      if (byIdx.containsKey(idx[i])) {
                                        return byIdx[idx[i]]!;
                                      }
                                      return TrackRecord(
                                        id:         '',
                                        filePath:   fp,
                                        entryPath:  '',
                                        subsongIdx: idx[i],
                                        title:      '$baseName (${i + 1})',
                                        artist:     ref.artist,
                                        metaAlbum:  ref.metaAlbum,
                                        onlineId:   ref.onlineId,
                                        albumId:    ref.albumId,
                                        artworkUrl: ref.artworkUrl,
                                        formatExt:  ext,
                                        subsongCount: count,
                                        source:     ref.source,
                                        isFavorite: false,
                                        inLibrary:  false,
                                        playCount:  0,
                                      );
                                    });
                                  }
                                }
                              }
                            }

                            // Multi-file album: DB only contains played tracks.
                            // Scan the directory for the full file list and
                            // merge, using DB data for already-played entries.
                            //
                            // ⚠️ SAUF quand l'album a reçu sa liste COMPLÈTE du
                            // catalogue (`album_materialised`): elle fait alors
                            // autorité, et le dossier contient plus de fichiers
                            // qu'elle n'en nomme. Mesuré sur « Wild Arms 3 »
                            // (jw_psf2): 115 pistes au catalogue et en base,
                            // 138 fichiers d'allure audio sur le disque —
                            // doublons régionaux `[jp]`/`[us]` et `.vgmstream`
                            // que le rip embarque sans les lister. Lancé depuis
                            // l'écran album on avait 115, depuis « Écoutés
                            // récemment » 139, dont certains injouables. Le
                            // marqueur est le SEUL juge: un simple compte de
                            // lignes ne distingue pas « liste complète » de
                            // « ce qui a été joué », ce pour quoi ce marqueur
                            // existe (il n'est posé que sur un lot COMPLET).
                            final materialised = entry.albumId != null &&
                                entry.albumId!.isNotEmpty &&
                                await LocalDb.instance
                                    .isAlbumMaterialised(entry.albumId!);
                            if (shouldScanAlbumDirectory(
                                catalogueAlbum:
                                    (entry.albumId ?? '').isNotEmpty,
                                materialised: materialised,
                                tracks: tracks.length,
                                dbTracks: dbTracks.length)) {
                              final dir = File(dbTracks.first.filePath).parent;
                              if (await dir.exists()) {
                                // RECURSIVE: an extracted archive album keeps
                                // its sub-folders (UnExotica "Game/han.X").
                                final allFiles =
                                    (await dir.list(recursive: true).toList())
                                    .whereType<File>()
                                    .where((f) {
                                      final name = f.path
                                          .split(Platform.pathSeparator)
                                          .last
                                          .toLowerCase();
                                      // Suffix OR Amiga prefix token: modland
                                      // names a module "mdat.NAME"/"han.NAME",
                                      // whose suffix is the SONG name, not a
                                      // format — matching on the suffix alone
                                      // filtered every UnExotica module out and
                                      // left the album a single track. Same
                                      // rule as extractLocalArchiveToTracks.
                                      final dot = name.lastIndexOf('.');
                                      final suffix = dot >= 0
                                          ? name.substring(dot + 1)
                                          : '';
                                      if (_audioExtensions.contains(suffix)) {
                                        return true;
                                      }
                                      final firstDot = name.indexOf('.');
                                      if (firstDot <= 0) return false;
                                      return _audioExtensions
                                          .contains(name.substring(0, firstDot));
                                    })
                                    .toList()
                                  ..sort((a, b) =>
                                      a.path.compareTo(b.path));

                                if (allFiles.length > dbTracks.length) {
                                  final dbByPath = {
                                    for (final t in dbTracks) t.filePath: t
                                  };
                                  // Same rule as the M3U branch: an identity
                                  // is only ever reused for its OWN file. On a
                                  // multi-file album each track has its own
                                  // online_id, so a scanned file with no row
                                  // stays identity-less rather than borrowing
                                  // a sibling's.
                                  final ref = dbTracks.first;
                                  tracks = allFiles.map((f) {
                                    if (dbByPath.containsKey(f.path)) {
                                      return dbByPath[f.path]!;
                                    }
                                    final name = f.path
                                        .split(Platform.pathSeparator)
                                        .last
                                        .replaceAll(RegExp(r'\.\w+$'), '');
                                    final ext = f.path.split('.').last;
                                    return TrackRecord(
                                      id:         '',
                                      filePath:   f.path,
                                      entryPath:  '',
                                      subsongIdx: 0,
                                      title:      name,
                                      artist:     ref.artist,
                                      metaAlbum:  ref.metaAlbum,
                                      artworkUrl: ref.artworkUrl,
                                      formatExt:  ext,
                                      albumId:    ref.albumId,
                                      // Only for THIS file, and only an id
                                      // that names a whole file (no `#rank`
                                      // suffix — that one belongs to a single
                                      // entry of a container).
                                      onlineId:   f.path == entry.filePath
                                          ? entry.onlineId
                                          : null,
                                      source:     f.path == entry.filePath &&
                                              (entry.onlineId ?? '').isNotEmpty
                                          ? 'online'
                                          : 'local',
                                      isFavorite: false,
                                      inLibrary:  false,
                                      playCount:  0,
                                    );
                                  }).toList();
                                }
                              }
                            }

                            // Expand each module into its subsongs, exactly
                            // like opening the archive does. UADE formats have
                            // no entry in kMultiTrackExts (the gate used by
                            // the single-file branch above), so without this a
                            // multi-subsong UnExotica module replayed from the
                            // recents rail queued only its first tune.
                            //
                            // NEVER EXPAND TWICE: _expandLocalModules keys off
                            // the file PATH and has no guard of its own, so a
                            // list the branches above already turned into
                            // subsong rows would come back N×N. Only expand a
                            // list that is still one row per distinct file.
                            if (tracks.isNotEmpty &&
                                !tracks.any((t) => t.subsongIdx > 0) &&
                                tracks.map((t) => t.filePath).toSet().length ==
                                    tracks.length) {
                              tracks = await expandLocalModules(tracks, controller);
                            }

                            if (tracks.isNotEmpty && ctx.mounted) {
                              if (asQueueAdd && queueLocal != null) {
                                await queueLocal(tracks,
                                    atEnd: choice == PlayChoice.end);
                              } else {
                                await onPlayLocalAlbum!(ctx, tracks);
                              }
                              return;
                            }
                          } catch (_) {/* best-effort */}
                        }
                        // Online album: fetch track list from API.
                        if (onPlayAlbum != null) {
                          try {
                            final songs = await RewampDb.browse(
                              albumName: entry.metaAlbum!,
                              limit:     500,
                            );
                            if (songs.isNotEmpty && ctx.mounted) {
                              if (asQueueAdd && queueOnline != null) {
                                await queueOnline(songs,
                                    atEnd: choice == PlayChoice.end,
                                    silent: false);
                              } else {
                                await onPlayAlbum!(ctx, songs);
                              }
                              return;
                            }
                          } catch (_) {/* best-effort */}
                        }
                      }
                      // Track entry of a multi-subsong FILE: the recents list
                      // shows one entry per file, so relaunch ALL its subsongs
                      // as a queue (that's how it was being listened to),
                      // resuming at the last-played one.
                      if (!entry.isAlbum &&
                          onPlayLocalAlbum != null &&
                          await File(entry.filePath).exists()) {
                        int count = 0;
                        // Prefer the SERVER's subsong count for an online
                        // container: the native probe returns a format default
                        // when the file itself carries no count (e.g. HES →
                        // 256), which would enqueue 256 phantom subsongs on
                        // replay. The catalogue knows the real number.
                        // Persisted count first (works OFFLINE), then the
                        // server, then the native probe.
                        final dbTracks = await LocalDb.instance
                            .getTracksForFile(entry.filePath);
                        // UADE: the songdb, not the counts below — the native
                        // probe cannot count these, and the catalogue's
                        // track_count includes the NOSOUND slots the songdb
                        // drops (22 vs the 21 that actually play).
                        if (UadeInfoService.isUadePath(entry.filePath)) {
                          final rows = await _uadeSubsongRows(
                              entry.filePath, dbTracks,
                              dbTracks.isNotEmpty ? dbTracks.first : null);
                          if (rows.length > 1 && ctx.mounted) {
                            if (asQueueAdd && queueLocal != null) {
                              await queueLocal(rows,
                                  atEnd: choice == PlayChoice.end);
                            } else {
                              // The start is the POSITION of that subsong in
                              // the list, not its index: NOSOUND slots are
                              // gone, so the two stop matching past the first.
                              final at = rows.indexWhere(
                                  (t) => t.subsongIdx == entry.subsongIdx);
                              await onPlayLocalAlbum!(ctx, rows,
                                  startIndex: at < 0 ? 0 : at);
                            }
                            return;
                          }
                        }
                        for (final t in dbTracks) {
                          if ((t.subsongCount ?? 0) > count) {
                            count = t.subsongCount!;
                          }
                        }
                        // onlineId may carry a '#<idx>' subsong suffix
                        // (subsongRowsFromServer) — strip it for the RPC.
                        final baseId = entry.onlineId?.split('#').first;
                        if (count <= 1 && baseId != null && baseId.isNotEmpty) {
                          try {
                            final ctx = await RewampDb.getSongContext(baseId);
                            count = ctx?.song.subsongCount ?? 0;
                          } catch (_) {}
                        }
                        if (count <= 1) {
                          try {
                            count = controller.audio
                                .probeSubsongCount(entry.filePath);
                          } catch (_) {}
                        }
                        if (count > 1) {
                          final byIdx = {
                            for (final t in dbTracks) t.subsongIdx: t
                          };
                          final ref = dbTracks.isNotEmpty ? dbTracks.first : null;
                          final baseName = entry.filePath
                              .split(Platform.pathSeparator)
                              .last
                              .replaceAll(RegExp(r'\.\w+$'), '');
                          final ext =
                              entry.filePath.split('.').last.toLowerCase();
                          // ⚠️ La POSITION n'est pas l'index quand la liste
                          // est CREUSE (`.adl`). Voir subsongIndicesFor.
                          final idx = subsongIndicesFor(
                              entry.filePath, controller, count);
                          final tracks = List.generate(count, (i) {
                            if (byIdx.containsKey(idx[i])) return byIdx[idx[i]]!;
                            return TrackRecord(
                              id:         '',
                              filePath:   entry.filePath,
                              entryPath:  '',
                              subsongIdx: idx[i],
                              title:      '$baseName (${i + 1})',
                              artist:     ref?.artist ?? entry.artist,
                              metaAlbum:  ref?.metaAlbum,
                              // Carry the server song id: playing this row
                              // persists it, and a favourite made from the
                              // player then keys on the id — a row without it
                              // keys on the file PATH, which can't be
                              // re-resolved server-side after a delete.
                              onlineId:   ref?.onlineId ?? entry.onlineId,
                              albumId:    ref?.albumId ?? entry.albumId,
                              artworkUrl: ref?.artworkUrl ?? entry.artworkUrl,
                              formatExt:  ext,
                              subsongCount: count,
                              source:     ref?.source ?? 'online',
                              isFavorite: false,
                              inLibrary:  false,
                              playCount:  0,
                            );
                          });
                          if (ctx.mounted) {
                            if (asQueueAdd && queueLocal != null) {
                              await queueLocal(tracks,
                                  atEnd: choice == PlayChoice.end);
                            } else {
                              await onPlayLocalAlbum!(ctx, tracks,
                                  startIndex: entry.subsongIdx
                                      .clamp(0, tracks.length - 1));
                            }
                            return;
                          }
                        }
                      }
                      // Single track or album fetch failed. Queue mode: hand
                      // the stored file to the local queue-add (a DB row when
                      // one exists — it carries format/duration —, else a
                      // minimal record from the entry).
                      if (asQueueAdd && queueLocal != null) {
                        TrackRecord? row = (await LocalDb.instance
                                .getTracksForFile(entry.filePath))
                            .where((t) => t.subsongIdx == entry.subsongIdx)
                            .firstOrNull;
                        row ??= TrackRecord(
                          id:         '',
                          filePath:   entry.filePath,
                          entryPath:  '',
                          subsongIdx: entry.subsongIdx,
                          title:      entry.label,
                          artist:     entry.artist,
                          metaAlbum:  entry.metaAlbum,
                          onlineId:   entry.onlineId,
                          albumId:    entry.albumId,
                          artworkUrl: entry.artworkUrl,
                          formatExt:  entry.filePath.split('.').last,
                          source:     entry.onlineId != null
                              ? 'online' : 'local',
                          isFavorite: false,
                          inLibrary:  false,
                          playCount:  0,
                        );
                        await queueLocal([row],
                            atEnd: choice == PlayChoice.end);
                        return;
                      }
                      // Play now: use onPlaySingleLocalFile so previous
                      // queues are cleared.
                      final playSingle = onPlaySingleLocalFile ?? onFileReady;
                      playSingle(
                        entry.filePath,
                        entry.label,
                        artist:     entry.artist,
                        album:      entry.metaAlbum,
                        albumId:    entry.albumId,
                        // Without the online id the player treats the file as
                        // local and disables the album link entirely.
                        onlineId:   entry.onlineId,
                        artworkUrl: entry.artworkUrl,
                        subsongIdx: entry.subsongIdx,
                      );
                    },
                  ),
                ),

                ],

                // ── En vedette aujourd'hui (party en cours, anniversaires…) ──
                // Sa place PAR DÉFAUT est juste sous les écoutes récentes:
                // c'est le contenu du jour, il périme.
                HomeSection.featured: [
                  SliverToBoxAdapter(
                    child: _FeaturedRail(
                      title: l10n.featuredTitle,
                      onTap: _playFeatured,
                      onOpenGroup: _openFeaturedSeries,
                    ),
                  ),
                ],

                // ── Vos tendances (local, play_events; période au choix) ───
                HomeSection.yourTrends: [
                  if (onPlayLocalAlbum != null)
                    SliverToBoxAdapter(
                      child: _LocalTrendRail(
                        title:            l10n.homeYourTrends,
                        selectablePeriod: true,
                        onPlayLocalAlbum: onPlayLocalAlbum!,
                      ),
                    ),
                ],

                // ── Votre top all-time (local, tout l'historique) ──────────
                HomeSection.yourAllTimeTop: [
                  if (onPlayLocalAlbum != null)
                    SliverToBoxAdapter(
                      child: _LocalTrendRail(
                        title:            l10n.homeYourAllTimeTop,
                        selectablePeriod: false,
                        onPlayLocalAlbum: onPlayLocalAlbum!,
                      ),
                    ),
                ],

                // ── Découverte en ligne (rails; masqués si vide/erreur) ────
                HomeSection.trending: [
                  SliverToBoxAdapter(
                    child: _SongRail(
                      title: l10n.homeTrending,
                      // Server accepts '7d'|'30d'|'90d'|'1y'|'YYYY'|'all'
                      // (_period_bounds, migration 034) — anything else (the
                      // stale 'week' this used to send) silently means all-time.
                      fetchForPeriod: (p) => RewampDb.mostPopularSongs(
                          period: p.serverValue, n: 20),
                      onTap: _playOnlineSong,
                      // La carte « … »: MÊME source que le rail — période
                      // courante comprise — plafond 1000 au lieu de 20.
                      onMore: (ctx, p) => Navigator.of(ctx).push(
                        MaterialPageRoute(
                          builder: (_) => ChartResultsScreen(
                            title: l10n.homeTrending,
                            mode: ChartMode.songs,
                            fetchSongs: () => RewampDb.mostPopularSongs(
                                period: p.serverValue, n: 1000),
                            onTap: _playOnlineSong,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                HomeSection.allTimeTop: [
                  SliverToBoxAdapter(
                    child: _SongRail(
                      title: l10n.homeAllTimeTop,
                      fetch: () =>
                          RewampDb.mostPopularSongs(period: 'all', n: 20),
                      onTap: _playOnlineSong,
                      onMore: (ctx, _) => Navigator.of(ctx).push(
                        MaterialPageRoute(
                          builder: (_) => ChartResultsScreen(
                            title: l10n.homeAllTimeTop,
                            mode: ChartMode.songs,
                            fetchSongs: () => RewampDb.mostPopularSongs(
                                period: 'all', n: 1000),
                            onTap: _playOnlineSong,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

              };

              return CustomScrollView(
                slivers: [
                  // Pushes first item below the status bar at rest; scrolls
                  // away freely so content passes behind the bar.
                  SliverToBoxAdapter(child: SizedBox(height: statusBarH)),
                  // L'ordre choisi. `?[]` et non `[]!`: une section qu'une
                  // version future retirerait ne doit pas faire planter
                  // l'accueil de qui l'a encore dans ses préférences.
                  for (final s in UserSettings.instance.homeSectionOrder)
                    ...?sections[s],

                  // Pas de bouton « ordre des sections » ICI: il vit dans
                  // Réglages → Général. L'accueil est une pile de rails, et un
                  // bouton de configuration au milieu s'y lit comme du bruit —
                  // pour un geste qu'on fait une fois.

                  // « Parcourir » now lives in the search tab's empty-state
                  // landing (Facet Browser cards) — see search_screen.dart.
                  const SliverToBoxAdapter(child: SizedBox(height: 60)),
                  // Room for the floating chrome (see shellInsetSliver).
                  shellInsetSliver(context),
                ],
              );
            },
          ),
        ),
    );
  }
}


/// Toutes les sous-chansons d'un module UADE, prêtes à mettre en queue.
///
/// Le songdb en est propriétaire — vrais `idx` (`min_subsong` n'est pas
/// toujours 0), slots NOSOUND retirés, durée par sous-chanson — là où la sonde
/// native n'en compte AUCUNE et où `tracks` ne retient que celles qui ont déjà
/// été jouées. Les lignes existantes sont réutilisées telles quelles: une
/// sous-chanson déjà écoutée garde son identité, sa durée et son historique.
/// Rend [dbRows] inchangé quand le songdb ne connaît pas le fichier.
Future<List<TrackRecord>> _uadeSubsongRows(
    String path, List<TrackRecord> dbRows, TrackRecord? ref) async {
  final info     = await UadeInfoService.instance.forPath(path);
  final playable = info?.playableSubsongs ?? const <UadeSubsong>[];
  if (playable.length <= 1) return dbRows;
  final byIdx = {for (final t in dbRows) t.subsongIdx: t};
  // Le nom du morceau, pas le token de format: un nom Amiga s'écrit
  // « mdat.monkey island ».
  final base = UadeInfoService.displayName(path);
  return [
    for (var i = 0; i < playable.length; i++)
      byIdx[playable[i].idx] ??
          TrackRecord(
            id:         '',
            filePath:   path,
            entryPath:  '',
            subsongIdx: playable[i].idx,
            // « NOM (n) », la convention de l'écran des sous-chansons — c'est
            // sous ce nom que ces pistes ont été jouées, enregistrées en base
            // et publiées dans une playlist. Une relance depuis les récents ne
            // doit pas les REBAPTISER: seules les sous-chansons jamais jouées
            // passent par ici, et une liste où la moitié s'appelle « 3 – nom »
            // et l'autre « nom (3) » se lit comme deux morceaux différents.
            title:      '$base (${i + 1})',
            artist:     ref?.artist,
            metaAlbum:  ref?.metaAlbum,
            onlineId:   ref?.onlineId,
            albumId:    ref?.albumId,
            artworkUrl: ref?.artworkUrl,
            formatExt:  ref?.formatExt,
            durationS:  (playable[i].lengthMs ?? 0) > 0
                ? playable[i].lengthMs! / 1000.0
                : null,
            source:     ref?.source ?? 'local',
            isFavorite: false,
            inLibrary:  false,
            playCount:  0,
          ),
  ];
}

// ── Recently-played: entry model is RecentEntry from local_db.dart ───────────

// ── Recently-played row ───────────────────────────────────────────────────────

/// Écart au-dessus d'un titre de section — c'est LUI qui sépare deux rails
/// (avec les 8 px sous le titre). Nommé parce qu'il était écrit en dur à
/// quatre endroits, avec déjà deux valeurs différentes (28 et 20): un écart
/// qui se recopie finit par diverger, et une page de rails dont les blancs ne
/// sont pas égaux se voit tout de suite.
const _kSectionTopGap = 18.0;

const _kRecentCardWidth  = 110.0;
// Pochette carrée (110) + 5 d'écart + DEUX lignes de titre + une de sous-titre.
// Le titre passe à deux lignes parce qu'un nom de module tronqué ne dit plus
// rien: « mdat.monkey isl… » ne se distingue pas de son voisin. La hauteur suit
// — sans elle la colonne DÉBORDE (mesuré: la place restante ne portait qu'une
// ligne de chaque).
//
// ⚠️ Pas de défilement automatique sur ces deux lignes: un texte replié a un
// bord droit irrégulier (la 1re ligne s'arrête sur un mot), donc faire glisser
// le bloc ne révèle rien de cohérent. Les deux formes qui marchent sont
// « replier + ellipse » ou « une ligne qui défile », jamais les deux ensemble.
// Le `MarqueeText` reste donc pour le sous-titre et pour le lecteur.
const _kRecentCardHeight = 175.0;

String _entryKey(RecentEntry e) =>
    '${e.isAlbum ? "a" : "t"}|${e.key}';

class _RecentRow extends StatefulWidget {
  final List<RecentEntry>                              entries;
  final ColorScheme                                    cs;
  final TextTheme                                      theme;
  final AppLocalizations                               l10n;
  final Future<void> Function(BuildContext, RecentEntry) onTap;

  const _RecentRow({
    required this.entries,
    required this.cs,
    required this.theme,
    required this.l10n,
    required this.onTap,
  });

  @override
  State<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends State<_RecentRow> {
  final _listKey = GlobalKey<AnimatedListState>();
  List<RecentEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _entries = List.of(widget.entries);
  }

  @override
  void didUpdateWidget(_RecentRow old) {
    super.didUpdateWidget(old);
    // recentEntries is mutated in-place → compare content keys.
    final next     = widget.entries;
    final nextKeys = next.map(_entryKey).join(',');
    final curKeys  = _entries.map(_entryKey).join(',');
    if (nextKeys != curKeys) {
      _diffAndAnimate(List.of(next));
      return;
    }
    // Same set of entries but a per-entry flag (e.g. favourite) may have flipped
    // — that's not an insert/remove/move, so refresh the snapshots in place and
    // rebuild the cards, else the artwork star never updates until the album
    // leaves and re-enters the list.
    final nextFav = next.map((e) => e.isFavorite).join(',');
    final curFav  = _entries.map((e) => e.isFavorite).join(',');
    if (nextFav != curFav) setState(() => _entries = List.of(next));
  }

  void _diffAndAnimate(List<RecentEntry> next) {
    final state = _listKey.currentState;
    if (state == null) {
      // AnimatedList not yet mounted — defer until after frame so the key is attached.
      WidgetsBinding.instance.addPostFrameCallback((_) => _diffAndAnimate(next));
      return;
    }

    final nextKeys = next.map(_entryKey).toList();

    // Remove items missing from new list (reverse order to preserve indices).
    for (int i = _entries.length - 1; i >= 0; i--) {
      if (!nextKeys.contains(_entryKey(_entries[i]))) {
        final removed = _entries.removeAt(i);
        state.removeItem(
          i,
          (ctx, anim) => _buildAnimatedCard(removed, anim),
          duration: const Duration(milliseconds: 280),
        );
      }
    }

    // Insert / reposition items that are new or have moved.
    for (int i = 0; i < next.length; i++) {
      final k = _entryKey(next[i]);
      if (i < _entries.length && _entryKey(_entries[i]) == k) continue;
      // Remove from old position if present (move scenario).
      final oldIdx = _entries.indexWhere((e) => _entryKey(e) == k);
      if (oldIdx >= 0) {
        final moved = _entries.removeAt(oldIdx);
        state.removeItem(oldIdx, (ctx, anim) => _buildAnimatedCard(moved, anim),
            duration: const Duration(milliseconds: 180));
      }
      _entries.insert(i, next[i]);
      state.insertItem(i, duration: const Duration(milliseconds: 320));
    }
  }

  Widget _buildAnimatedCard(RecentEntry e, Animation<double> anim) {
    return SizeTransition(
      sizeFactor:  CurvedAnimation(parent: anim, curve: Curves.easeInOut),
      axis:        Axis.horizontal,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _RecentCard(
            entry: e,
            cs:    widget.cs,
            theme: widget.theme,
            onTap: () => widget.onTap(context, e),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text(
          widget.l10n.noRecentTracks,
          style: widget.theme.bodyMedium?.copyWith(color: widget.cs.onSurfaceVariant),
        ),
      );
    }

    return SizedBox(
      height: _kRecentCardHeight,
      child: HorizontalScrollArrows(
        centerY: _kRecentCardWidth / 2,
        builder: (ctx, controller) => AnimatedList(
          key:             _listKey,
          controller:      controller,
          scrollDirection: Axis.horizontal,
          padding:         const EdgeInsets.symmetric(horizontal: 16),
          initialItemCount: _entries.length,
          itemBuilder: (ctx, i, anim) => _buildAnimatedCard(_entries[i], anim),
        ),
      ),
    );
  }
}

// ── Recently-played card ─────────────────────────────────────────────────────

class _RecentCard extends StatelessWidget {
  final RecentEntry entry;
  final ColorScheme  cs;
  final TextTheme    theme;
  final VoidCallback onTap;

  const _RecentCard({
    required this.entry,
    required this.cs,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Square artwork side = card width
    const artworkSize = _kRecentCardWidth;

    return HoverGrow(child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _kRecentCardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Artwork square ────────────────────────────────────────
            Stack(
              children: [
                RailArtwork(
                  url:          entry.artworkUrl,
                  artist:       entry.artist,
                  album:        entry.metaAlbum,
                  // Local tracks have no artwork_url: let ArtworkImage fall back
                  // to a sibling image / the extracted embedded cover. Albums
                  // key on artist+album, so only pass it for track entries.
                  localFilePath: entry.isAlbum ? null : entry.filePath,
                  // Themed per-platform placeholder, from what the CATALOGUE
                  // says (migration 52) rather than from the file name: an
                  // archive extension carries no origin at all, and an Amiga
                  // name carries its format BEFORE the dot. The path stays as
                  // the last resort, for a purely local file.
                  platformName: entry.platformName,
                  formatHint:   entry.formatExt ?? entry.filePath,
                  size:         artworkSize,
                ),
                // Small album badge when it's a collapsed album entry
                if (entry.isAlbum)
                  Positioned(
                    bottom: 4,
                    right:  4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: cs.surface.withAlpha(200),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.queue_music,
                          size: 14, color: cs.onSurface),
                    ),
                  ),
                // Favorite star badge — top-right corner
                if (entry.isFavorite)
                  const Positioned(
                    top:   2,
                    right: 2,
                    child: Icon(
                      Icons.star_rounded,
                      size: 24,
                      color: kFavoriteColor,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                    ),
                  ),
                // Local-file badge — bottom-left corner
                if (entry.isLocal)
                  const Positioned(
                    bottom: 4,
                    left:   4,
                    child: LocalBadge(),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            // ── Title ─────────────────────────────────────────────────
            // Titre: deux lignes, et il DÉFILE verticalement quand elles ne
            // suffisent pas (« Indiana Jones and the Fate of Atlantis »). Le
            // défilement vertical est le seul cohérent sur un texte replié —
            // chaque ligne est complète, la fenêtre glisse. Il ne bouge que
            // s'il déborde: une carte dont le titre tient reste immobile.
            MarqueeText(
              entry.label,
              axis: Axis.vertical,
              maxLines: 2,
              style: theme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            // ── Artist ────────────────────────────────────────────────
            if (entry.artist != null)
              Text(
                entry.artist!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    ));
  }
}

// ── Trend period selector (shared by the personal + server trend rails) ──────
//
// The server RPC takes the period as a parameter ('7d'|'30d'|'90d'|'1y'|'YYYY'|
// 'all' — _period_bounds, migration 034), and the local stats query takes an
// epoch-seconds window, so one enum drives both. The choice is persisted so the
// home screen comes back the way the user left it.

enum TrendPeriod {
  d7('7d', 7),
  d30('30d', 30),
  d90('90d', 90);

  const TrendPeriod(this.serverValue, this.days);
  final String serverValue;   // most_popular_songs' `period`
  final int    days;

  /// Chip label — localized at render time (the enum itself is const).
  String label(AppLocalizations l10n) => switch (this) {
        TrendPeriod.d7  => l10n.homePeriod7d,
        TrendPeriod.d30 => l10n.homePeriod30d,
        TrendPeriod.d90 => l10n.homePeriod90d,
      };

  /// Epoch seconds for the local play_events window.
  int get sinceEpoch => DateTime.now()
      .subtract(Duration(days: days))
      .millisecondsSinceEpoch ~/ 1000;

  static TrendPeriod fromId(String? id) => TrendPeriod.values.firstWhere(
      (p) => p.serverValue == id,
      orElse: () => TrendPeriod.d30);
}

/// Segmented 7/30/90-day chips shown next to a rail's title.
class _TrendPeriodPicker extends StatelessWidget {
  final TrendPeriod              value;
  final ValueChanged<TrendPeriod> onChanged;

  const _TrendPeriodPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in TrendPeriod.values)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: GestureDetector(
              onTap: () => onChanged(p),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p == value ? cs.secondaryContainer : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  p.label(l10n),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        p == value ? FontWeight.bold : FontWeight.normal,
                    color: p == value
                        ? cs.onSecondaryContainer
                        : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── "Vos tendances" — the user's own most-played tracks (last 30 days),
// computed locally from play_events. Hidden when there is nothing meaningful
// to show; refreshes on DB changes (new plays). Tapping a card queues the
// whole trend list positioned on it (missing files re-download by online id
// via the queue's _LocalItem fallback).

class _LocalTrendRail extends StatefulWidget {
  final String           title;
  /// Fixed all-time rail when null; otherwise the user picks 7/30/90 days.
  final bool             selectablePeriod;
  final OnPlayLocalAlbum onPlayLocalAlbum;

  const _LocalTrendRail({
    required this.title,
    required this.selectablePeriod,
    required this.onPlayLocalAlbum,
  });

  @override
  State<_LocalTrendRail> createState() => _LocalTrendRailState();
}

class _LocalTrendRailState extends State<_LocalTrendRail> {
  List<TrackStat> _stats = const [];
  TrendPeriod _period =
      TrendPeriod.fromId(UserSettings.instance.homeTrendPeriod);

  @override
  void initState() {
    super.initState();
    LocalDb.instance.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_load);
    super.dispose();
  }

  void _setPeriod(TrendPeriod p) {
    if (p == _period) return;
    setState(() => _period = p);
    UserSettings.instance.homeTrendPeriod = p.serverValue;
    _load();
  }

  Future<void> _load() async {
    final from = widget.selectablePeriod ? _period.sinceEpoch : null;
    final stats =
        await LocalDb.instance.statsTopTracks(from: from, limit: 15);
    if (!mounted) return;
    // A rail of 1-play rows is just "recently played" again — require a bit
    // of signal before showing personal trends.
    setState(() =>
        _stats = (stats.length >= 4 && stats.first.plays >= 2) ? stats : const []);
  }

  @override
  Widget build(BuildContext context) {
    if (_stats.isEmpty) return const SizedBox.shrink();
    final l10n  = context.l10n;
    final cs    = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, _kSectionTopGap, 12, 8),
          child: Row(children: [
            Expanded(
              child: Text(
                widget.title,
                style: theme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (widget.selectablePeriod)
              _TrendPeriodPicker(value: _period, onChanged: _setPeriod),
          ]),
        ),
        SizedBox(
          height: _kRecentCardHeight,
          child: HorizontalScrollArrows(
            centerY: _kRecentCardWidth / 2,
            builder: (ctx, controller) => ListView.separated(
              controller: controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _stats.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (ctx, i) {
                if (i == _stats.length) {
                  // « … » — même source que le rail (période comprise),
                  // plafond 1000: LocalTopTracksScreen (stats_screen).
                  return _MoreRailCard(
                    cs: cs, theme: theme,
                    onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
                      builder: (_) => LocalTopTracksScreen(
                        title: widget.title,
                        from: widget.selectablePeriod
                            ? _period.sinceEpoch
                            : null,
                        onPlay: widget.onPlayLocalAlbum,
                      ),
                    )),
                  );
                }
                final s = _stats[i];
                final t = s.track;
                return _RailCard(
                  title:         t.displayTitle,
                  subtitle:      l10n.homePlaysCount(s.plays),
                  artworkUrl:    t.artworkUrl,
                  artist:        t.artist,
                  album:         t.metaAlbum,
                  localFilePath: t.filePath,
                  icon:          Icons.music_note,
                  cs:         cs,
                  theme:      theme,
                  // Play now = the whole rail as a queue from this card (the
                  // established behaviour); queue insert = just this track.
                  onTap: () async {
                    final choice = await showPlayChoiceSheet(ctx,
                        title: t.displayTitle, subtitle: t.artist, track: t);
                    if (choice == null || !ctx.mounted) return;
                    if (choice != PlayChoice.now &&
                        globalOnLocalQueueAdd != null) {
                      await globalOnLocalQueueAdd!([t],
                          atEnd: choice == PlayChoice.end);
                      return;
                    }
                    await widget.onPlayLocalAlbum(
                        ctx, [for (final x in _stats) x.track],
                        startIndex: i);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── Online discovery rails (trending / top / playlists) ──────────────────────
//
// Each rail renders nothing at all — header included — while loading, on error,
// or when the server returns no rows, so the home screen works fully offline.
//
// A rail's State survives every rebuild (controller ticks) AND every tab switch
// (the shell holds the home subtree in an IndexedStack), so its fetch must be
// driven by [HomeRefresh] rather than cached in a field: otherwise it runs once
// per app process — a server-side change never appears, and a rail that failed
// on an offline launch stays empty forever. HomeRefresh bumps its revision on
// app resume (TTL-guarded) and, while a rail reports a FAILED fetch, on a
// backoff timer — which is what makes an offline launch recover once the
// network comes back, with no relaunch.

class _SongRail extends StatefulWidget {
  final String title;
  /// Fetch for a fixed rail (no period selector).
  final Future<List<SearchResult>> Function()? fetch;
  /// Fetch parameterized by the selected period — when set, the rail shows the
  /// 7/30/90-day picker and refetches on change (the server RPC takes `period`).
  final Future<List<SearchResult>> Function(TrendPeriod)? fetchForPeriod;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  /// Carte « … » en fin de rail: ouvre la liste complète (même source que le
  /// rail, plafond plus haut). Reçoit la période COURANTE du rail — c'est le
  /// rail qui la tient, pas l'appelant.
  final void Function(BuildContext, TrendPeriod)? onMore;

  const _SongRail({
    required this.title,
    this.fetch,
    this.fetchForPeriod,
    required this.onTap,
    this.onMore,
  });

  @override
  State<_SongRail> createState() => _SongRailState();
}

class _SongRailState extends State<_SongRail> {
  late TrendPeriod _period =
      TrendPeriod.fromId(UserSettings.instance.homeTrendPeriod);
  late Future<List<SearchResult>> _future = _fetch();
  int _revision = HomeRefresh.instance.revision;

  @override
  void initState() {
    super.initState();
    HomeRefresh.instance.addListener(_onRefresh);
  }

  @override
  void dispose() {
    HomeRefresh.instance.removeListener(_onRefresh);
    HomeRefresh.instance.forget(this);
    super.dispose();
  }

  void _onRefresh() {
    if (HomeRefresh.instance.revision == _revision) return;
    _revision = HomeRefresh.instance.revision;
    // Block body, NOT an arrow: `() => _future = _fetch()` returns the assigned
    // Future and setState asserts on a callback that returns one.
    setState(() { _future = _fetch(); });
  }

  /// Reports the outcome to [HomeRefresh] (a throw = failed → arms its retry
  /// backoff) and swallows it, so the rail just renders empty.
  Future<List<SearchResult>> _fetch() async {
    final f = widget.fetchForPeriod != null
        ? widget.fetchForPeriod!(_period)
        : widget.fetch!();
    try {
      final rows = await f;
      if (mounted) HomeRefresh.instance.reportResult(this, failed: false);
      return rows;
    } catch (_) {
      if (mounted) HomeRefresh.instance.reportResult(this, failed: true);
      return const [];
    }
  }

  void _setPeriod(TrendPeriod p) {
    if (p == _period) return;
    setState(() {
      _period = p;
      _future = _fetch();
    });
    UserSettings.instance.homeTrendPeriod = p.serverValue;
  }

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;

    return FutureBuilder<List<SearchResult>>(
      future: _future,
      builder: (context, snap) {
        final songs = snap.data ?? const <SearchResult>[];
        // Keep the rail (and its picker) on screen while a period switch is in
        // flight — collapsing it would make the chips jump out from under the
        // finger that just tapped them.
        if (songs.isEmpty &&
            !(widget.fetchForPeriod != null &&
                snap.connectionState == ConnectionState.waiting)) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, _kSectionTopGap, 12, 8),
              child: Row(children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style:
                        theme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.fetchForPeriod != null)
                  _TrendPeriodPicker(value: _period, onChanged: _setPeriod),
              ]),
            ),
            SizedBox(
              height: _kRecentCardHeight,
              child: songs.isEmpty
                  ? const Center(
                      child: SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : HorizontalScrollArrows(
                centerY: _kRecentCardWidth / 2,
                builder: (ctx, controller) => ListView.separated(
                controller: controller,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: songs.length + (widget.onMore != null ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) {
                  if (i == songs.length) {
                    return _MoreRailCard(
                      cs: cs, theme: theme,
                      onTap: () => widget.onMore!(ctx, _period),
                    );
                  }
                  final s = songs[i];
                  return _RailCard(
                    title:      s.displayTitle,
                    // Le sous-titre ne doit JAMAIS répéter le titre. Sur une
                    // ligne d'ALBUM des palmarès, `title` et `album` valent
                    // tous deux le nom de l'album (`a.name AS s_title2,
                    // a.name AS s_album2`), et le repli affichait donc le nom
                    // deux fois. Les artistes seraient le bon sous-titre, mais
                    // ils ne sont PAS dans la charge utile: le serveur laisse
                    // les colonnes play-ready — `artist_names` comprise — à
                    // NULL sur une ligne album (mig 216, dit dans son propre
                    // commentaire). On retombe donc sur la collection, qui
                    // apprend quelque chose, plutôt que sur une répétition.
                    subtitle:   s.artistLabel.isNotEmpty
                        ? s.artistLabel
                        : ((s.album != null &&
                                s.album!.isNotEmpty &&
                                s.album != s.displayTitle)
                            ? s.album!
                            : s.collection),
                    artworkUrl: s.artworkUrl,
                    artist:     s.artistNames.isEmpty ? null : s.artistNames.first,
                    album:      s.album,
                    formatHint: s.formatExt,
                    icon:       s.isAlbumRow ? Icons.album : Icons.music_note,
                    cs:         cs,
                    theme:      theme,
                    onTap:      () => widget.onTap(ctx, s),
                  );
                },
              ),
              ),
            ),
          ],
        );
      },
    );
  }
}



/// Calendar-driven rail (list_featured): demoparty podiums in season, tracks
/// released this month N years ago, round game anniversaries.
///
/// The reason line is rendered from `reason_key` + `reason_params` via our ARB
/// catalogue ([featuredReasonText]) — NOT from the server's pre-rendered
/// `reason`. `p_lang` is still sent so an unknown key (a slot type added
/// server-side after this build) still shows something.
class _FeaturedRail extends StatefulWidget {
  final String title;
  /// Tap on a standalone card (a slot with no group) — routes to the playlist.
  final Future<void> Function(BuildContext, FeaturedSlot) onTap;
  /// Tap on a series group card — opens the list of the series' playlists.
  /// (shortLabel, fullHeader, slots)
  final Future<void> Function(BuildContext, String, String, List<FeaturedSlot>)
      onOpenGroup;

  const _FeaturedRail(
      {required this.title, required this.onTap, required this.onOpenGroup});

  @override
  State<_FeaturedRail> createState() => _FeaturedRailState();
}

class _FeaturedRailState extends State<_FeaturedRail> {
  Future<List<FeaturedSlot>>? _future;
  int _revision = HomeRefresh.instance.revision;
  String? _lang;

  @override
  void initState() {
    super.initState();
    HomeRefresh.instance.addListener(_onRefresh);
  }

  @override
  void dispose() {
    HomeRefresh.instance.removeListener(_onRefresh);
    HomeRefresh.instance.forget(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Locale-dependent → resolved here, not in initState (no inherited widgets
    // there). Refetches on a locale change, not on every rebuild.
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == _lang) return;
    _lang = lang;
    _future = _load(lang);
  }

  void _onRefresh() {
    if (HomeRefresh.instance.revision == _revision) return;
    _revision = HomeRefresh.instance.revision;
    final lang = _lang;
    if (lang == null) return;
    // Block body, NOT an arrow: `() => _future = _load(lang)` returns the
    // assigned Future and setState asserts on a callback that returns one.
    setState(() { _future = _load(lang); });
  }

  /// How many community playlists close the rail. Small on purpose: they are
  /// the tail of an editorial selection, not a feed of their own.
  static const _kCommunityCards = 8;

  /// Synthetic group key: it folds those slots into ONE card that opens the
  /// list of them, through the very same grouping the server's series use. The
  /// server never sends this key, so it cannot collide with a real one.
  static const _kCommunityGroup = 'community.recent';

  /// Reports the outcome to [HomeRefresh] (a throw = failed → arms its retry
  /// backoff) and swallows it, so the rail just renders empty.
  Future<List<FeaturedSlot>> _load(String lang) async {
    try {
      final slots = await RewampDb.listFeatured(lang: lang);
      if (mounted) HomeRefresh.instance.reportResult(this, failed: false);
      return [...slots, ...await _community(slots.length)];
    } catch (_) {
      if (mounted) HomeRefresh.instance.reportResult(this, failed: true);
      return const [];
    }
  }

  /// The newest playlists published by people, appended at the END of the rail
  /// (migration 199: p_source='user', and sort_by='recent' now orders on the
  /// APPROVAL date — a playlist made in January and published in July is a
  /// July newcomer). Its own try/catch: this is a bonus, and losing it must
  /// never cost the editorial rail, which is the whole point of the section.
  Future<List<FeaturedSlot>> _community(int from) async {
    try {
      // « Nouveautés de la COMMUNAUTÉ »: ce qui est PUBLIÉ, quel qu'en soit
      // l'auteur. L'appel part avec le jeton (migration 172), donc la réponse
      // mêlait les playlists du COMPTE — privées ou en attente de relecture
      // comprises: une playlist pas encore approuvée s'affichait sur l'accueil
      // de son auteur comme si elle l'était. Le tri est fait par le SERVEUR
      // (`p_only_public`): filtrer ici laissait un `total_count` qui compte
      // les exclues, et il fallait sur-demander pour ne pas finir avec un rail
      // à moitié vide.
      //
      // `excludeMine: false` est EXPLICITE et non un défaut subi: une playlist
      // à soi, publiée et approuvée, est une nouveauté de la communauté comme
      // une autre — la voir là est même la confirmation qu'elle est en ligne.
      // Seul l'état de PUBLICATION filtre, jamais l'auteur.
      final pls = await RewampDb.listPlaylists(
          source: 'user',
          onlyPublic: true,
          excludeMine: false,
          sortBy: 'recent',
          limit: _kCommunityCards);
      return [
        for (final (i, p) in pls.indexed)
          FeaturedSlot.fromPlaylist(p, from + i, groupKey: _kCommunityGroup),
      ];
    } catch (_) {
      return const [];
    }
  }

  IconData _iconFor(String kind) => switch (kind) {
        'playlist' => Icons.emoji_events_outlined,
        'album'    => Icons.album_outlined,
        _          => Icons.music_note,
      };

  /// Groups the flat row list into sections: rows sharing a non-null groupKey
  /// become one series (a group card); a null groupKey is a standalone card.
  /// The server returns rows already sorted and contiguous by section, so a
  /// single linear pass preserving order is enough.
  static List<List<FeaturedSlot>> _sections(List<FeaturedSlot> slots) {
    final out = <List<FeaturedSlot>>[];
    for (final s in slots) {
      final gk = s.groupKey;
      if (gk == null || gk.isEmpty) {
        out.add([s]);
      } else if (out.isNotEmpty && out.last.first.groupKey == gk) {
        out.last.add(s);
      } else {
        out.add([s]);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final l10n  = context.l10n;

    return FutureBuilder<List<FeaturedSlot>>(
      future: _future,
      builder: (context, snap) {
        final slots = snap.data ?? const <FeaturedSlot>[];
        if (slots.isEmpty) return const SizedBox.shrink();
        final sections = _sections(slots);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, _kSectionTopGap, 16, 8),
              child: Text(
                widget.title,
                style: theme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: _kRecentCardHeight,
              child: HorizontalScrollArrows(
                centerY: _kRecentCardWidth / 2,
                builder: (ctx, controller) => ListView.separated(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sections.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (ctx, i) {
                    final section = sections[i];
                    final head    = section.first;
                    final isGroup = head.groupKey != null &&
                                    head.groupKey!.isNotEmpty;
                    if (isGroup) {
                      // A series: one card for the whole group. The full header
                      // sentence is shown inside the series screen; the card
                      // gets a short label + how many playlists it holds.
                      // The community group is ours, not the server's, so its
                      // label comes straight from the ARB — featuredGroupLabel
                      // only knows the server's reason keys and would render
                      // nothing for it.
                      final community = head.groupKey == _kCommunityGroup;
                      final label = community
                          ? l10n.featuredCommunityTitle
                          : featuredGroupLabel(ctx, head);
                      return _RailCard(
                        title:      label,
                        subtitle:   l10n.featuredGroupCount(section.length),
                        artworkUrl: head.artworkUrl,
                        icon:       community
                            ? Icons.groups_outlined
                            : Icons.playlist_play,
                        cs:         cs,
                        theme:      theme,
                        onTap:      () => widget.onOpenGroup(
                            ctx,
                            label,
                            community
                                ? ''   // the card's label says it all
                                : featuredGroupReasonText(ctx, head),
                            section),
                      );
                    }
                    // A community card has no editorial reason to show — it
                    // is credited to its author instead, which is also what
                    // tells it apart from the selections around it.
                    final byAuthor = (head.authorName ?? '').isNotEmpty;
                    return _RailCard(
                      title:           head.name,
                      subtitle:        byAuthor
                          ? l10n.playlistByAuthor(head.authorName!)
                          : featuredReasonText(ctx, head),
                      artworkUrl:      head.artworkUrl,
                      icon:            byAuthor
                          ? Icons.person_outline
                          : _iconFor(head.kind),
                      cs:              cs,
                      theme:           theme,
                      subtitleMarquee: true,   // the reason is a sentence
                      onTap:           () => widget.onTap(ctx, head),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Second level of the featured rail: the list of playlists inside a series
/// (a party's compos, a month's decades, the anniversaries). Tapping a row
/// opens the same [PlaylistTracksScreen] a standalone featured card would.
class FeaturedSeriesScreen extends StatefulWidget {
  final String title;   // short label, shown in the app bar
  final String header;  // full "why" sentence, shown at the top of the list
  final List<FeaturedSlot> slots;
  final Future<void> Function(BuildContext, FeaturedSlot) onTap;
  // Enqueues a built track list. Present ⇒ the "play all" / "radio" actions
  // over the whole series are offered.
  final OnPlayAlbum? onPlayAlbum;

  const FeaturedSeriesScreen({
    super.key,
    required this.title,
    required this.header,
    required this.slots,
    required this.onTap,
    this.onPlayAlbum,
  });

  @override
  State<FeaturedSeriesScreen> createState() => _FeaturedSeriesScreenState();
}

class _FeaturedSeriesScreenState extends State<FeaturedSeriesScreen> {
  // Cap the queue built from a whole series — a busy year holds many playlists
  // of many tracks each. Same ceiling as the folder "Tout lire".
  static const _queueMax = 500;
  bool _busy = false;

  /// Play every entry in the series (playlist or album), in order.
  ///
  /// Entries are resolved and queued ONE AT A TIME, not gathered up front: a
  /// container album (an snesmusic RSN, a joshw 7z, …) has its subsong rows
  /// carry no standalone download_url — the archive must be fetched and
  /// extracted with THAT album's own context (RewampDb.ensureAlbumExtracted),
  /// which a single flattened list mixing several albums can't do (it would try
  /// to extract one archive for everyone → "download impossible" on the rest).
  /// So the first entry starts playback and each following entry is resolved
  /// then appended in the background, so only the album being reached downloads.
  /// (The endless "radio" variant lives in AppShell — a rolling window instead
  /// of this finite gather.)
  Future<void> _gatherAndPlay() async {
    final onPlay = widget.onPlayAlbum;
    if (onPlay == null || _busy) return;
    setState(() => _busy = true);
    final l10n = context.l10n;

    final entries = widget.slots.toList();

    // One entry → its extracted, directly-playable rows. ensureAlbumExtracted
    // is a no-op for a non-archive album (individual .vgz/.nsf files keep their
    // own download_url) and does the download+extract for a real container.
    Future<List<SearchResult>> resolve(FeaturedSlot s) async {
      try {
        switch (s.kind) {
          case 'album':
            return await RewampDb.ensureAlbumExtracted(
                await RewampDb.albumTracks(albumId: s.id, sortBy: 'position'));
          case 'playlist':
            return await RewampDb.playlistTracks(s.id);
          default:
            return const [];
        }
      } catch (_) {
        return const []; // one bad entry must not sink the whole run
      }
    }

    var total = 0;
    var started = false;
    try {
      for (final e in entries) {
        if (total >= _queueMax) break;
        final rows = await resolve(e);
        if (rows.isEmpty) continue;
        total += rows.length;
        if (!started) {
          if (!mounted) return;               // need a context to start
          started = true;
          await onPlay(context, rows);
          if (mounted) setState(() => _busy = false); // first album plays → free the UI
        } else {
          // Global queue-add, silent: works even after this screen is popped,
          // and one snackbar per appended album would be spam.
          await globalOnAlbumQueueAdd?.call(rows, atEnd: true, silent: true);
        }
      }
      if (!started && mounted) {
        AppSnack.show(context, l10n.homeAlbumLoadFailed);
      }
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  bool _noteExpanded = false;

  /// Demozoo's description of the party: one collapsed line, tap for the whole
  /// thing (height-bounded, so a long text never pushes the playlists off).
  ///
  /// Rendered through [NoteMarkdown], never as plain text: the server hands the
  /// demozoo field over untouched, and a third of that corpus is HTML — the
  /// Silly Venture note carries a visible `<a href>` if you print it raw. It is
  /// also not always a blurb (Assembly's is an archival caveat), which is why
  /// it sits under the title as context rather than being promoted anywhere.
  Widget _noteBanner(String note) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      child: InkWell(
        onTap: () => setState(() => _noteExpanded = !_noteExpanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.celebration, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: _noteExpanded
                      ? const SizedBox.shrink()
                      : Text(
                          noteToPlainLine(note),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                ),
                Icon(
                  _noteExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ]),
              if (_noteExpanded)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),
                  child: SingleChildScrollView(
                    child: NoteMarkdown(
                      text: note,
                      onOpenLink: (u) => openExternalLink(context, u),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final tt   = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final title  = widget.title;
    final header = widget.header;
    final slots  = widget.slots;

    // What demozoo knows about the party behind this series, carried by the
    // rows themselves (list_featured's last two columns) — no second call.
    final note = slots.isEmpty ? null : slots.first.groupNote;
    final partyUrl = slots.isEmpty ? null : slots.first.groupUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if ((partyUrl ?? '').isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: l10n.settingsOpenLink,
              onPressed: () => openExternalLink(context, partyUrl!),
            ),
        ],
      ),
      body: Column(children: [
        if ((note ?? '').isNotEmpty) _noteBanner(note!),
        // "Tout lire" + radio header (moved from the AppBar top-right, to match
        // the playlist screens). The radio sits right next to "Tout lire".
        if (widget.onPlayAlbum != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: () => _gatherAndPlay(),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(l10n.commonPlayAll),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.radio),
                tooltip: l10n.searchRadio,
                // Endless station: hand the whole pool to AppShell, which keeps
                // a small rolling window (a few tracks ahead/behind) and refills
                // it forever — instead of the finite play-all.
                onPressed: () =>
                    globalOnStartFeaturedRadio?.call(widget.slots),
              ),
            ]),
          ),
        Expanded(
          child: ListView.separated(
        padding: shellInset(context, const EdgeInsets.only(bottom: 24)),
        itemCount: slots.length + (header.isNotEmpty ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
        itemBuilder: (ctx, i) {
          if (header.isNotEmpty && i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(header,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            );
          }
          final s = slots[header.isNotEmpty ? i - 1 : i];
          // The per-card reason is redundant with the header for a party series
          // (same key) — fall back to the track count there.
          final reason = featuredReasonText(ctx, s);
          // A community row has no editorial reason — it is credited to its
          // author, next to what it holds.
          final byAuthor = (s.authorName ?? '').isNotEmpty;
          final subtitle = byAuthor
              ? [
                  l10n.playlistTrackCount(s.trackCount),
                  l10n.playlistByAuthor(s.authorName!),
                ].join('  ·  ')
              : (reason.isEmpty || reason == header)
                  ? l10n.playlistTrackCount(s.trackCount)
                  : reason;
          return ListTile(
            leading: ArtworkImage(
              url:          s.artworkUrl,
              size:         52,
              borderRadius: BorderRadius.circular(6),
              placeholder: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.emoji_events_outlined,
                    color: cs.onPrimaryContainer),
              ),
            ),
            title: Text(s.name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(subtitle,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => widget.onTap(ctx, s),
          );
        },
          ),
        ),
      ]),
    );
  }
}

/// La carte « … » qui FERME un rail: le bouton occupe la place de la
/// pochette, le libellé sous lui dit ce qu'il ouvre (statsSeeAll — pas de
/// texte en dur, règle i18n).
class _MoreRailCard extends StatelessWidget {
  final ColorScheme  cs;
  final TextTheme    theme;
  final VoidCallback onTap;

  const _MoreRailCard({
    required this.cs,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverGrow(child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _kRecentCardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: _kRecentCardWidth,
              height: _kRecentCardWidth,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.more_horiz,
                  size: 36, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 5),
            Text(
              context.l10n.statsSeeAll,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ));
  }
}


class _RailCard extends StatelessWidget {
  final String       title;
  final String?      subtitle;
  final String?      artworkUrl;
  final String?      artist;
  final String?      album;
  /// Local audio file, when the row is a local track: lets ArtworkImage find a
  /// sibling image or the cover extracted from the file's own tags — a local
  /// track's artwork_url is null in the DB, so without this the card falls back
  /// to the placeholder even though the player shows a cover.
  final String?      localFilePath;
  /// Format/extension hint for the themed per-platform placeholder (a path or
  /// bare ext); null falls back to localFilePath/url inference.
  final String?      formatHint;
  final IconData     icon;
  final ColorScheme  cs;
  final TextTheme    theme;
  final VoidCallback onTap;
  /// The featured rail's subtitle is a sentence ("Solskogen season — podiums
  /// from past editions"), not a track count: a 110pt card cuts it before the
  /// party name and says nothing. Two lines still weren't enough, so it
  /// scrolls instead.
  final bool         subtitleMarquee;

  const _RailCard({
    required this.title,
    this.subtitle,
    this.artworkUrl,
    this.artist,
    this.album,
    this.localFilePath,
    this.formatHint,
    required this.icon,
    required this.cs,
    required this.theme,
    required this.onTap,
    this.subtitleMarquee = false,
  });

  @override
  Widget build(BuildContext context) {
    const artworkSize = _kRecentCardWidth;

    return HoverGrow(child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _kRecentCardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RailArtwork(
              url:           artworkUrl,
              artist:        artist,
              album:         album,
              localFilePath: localFilePath,
              formatHint:    formatHint,
              size:          artworkSize,
            ),
            const SizedBox(height: 5),
            // Titre: deux lignes, et il DÉFILE verticalement quand elles ne
            // suffisent pas (« Indiana Jones and the Fate of Atlantis »). Le
            // défilement vertical est le seul cohérent sur un texte replié —
            // chaque ligne est complète, la fenêtre glisse. Il ne bouge que
            // s'il déborde: une carte dont le titre tient reste immobile.
            MarqueeText(
              title,
              axis: Axis.vertical,
              maxLines: 2,
              style: theme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Builder(builder: (_) {
                final style = theme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                );
                if (subtitleMarquee) {
                  return MarqueeText(subtitle!, style: style);
                }
                return Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                );
              }),
          ],
        ),
      ),
    ));
  }
}
