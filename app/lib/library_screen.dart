import 'dart:io';

import 'package:flutter/material.dart';
import 'app_snack.dart';

import 'favorite_color.dart';
import 'hover_grow.dart';
import 'local_badge.dart';
import 'artwork_image.dart';
import 'local_db.dart';
import 'rewamp_db.dart'
    show OnPlayAlbum, OnPlayLocalAlbum, RewampDb, SearchResult, Playlist;
import 'browse_screen.dart' show PlaylistTracksScreen;
import 'track_options_sheet.dart'
    show showPlayChoiceSheet, PlayChoice, globalOnAlbumQueueAdd,
         globalOnLocalQueueAdd;
import 'l10n.dart';
import 'library_presence.dart';
import 'library_playlists_screen.dart';
import 'library_artists_screen.dart';
import 'library_albums_screen.dart';
import 'library_tracks_screen.dart';
import 'shell_insets.dart';

export 'library_playlists_screen.dart' show OnFileReady;
export 'library_artists_screen.dart'  show OnNavigateArtist;
export 'library_albums_screen.dart'   show OnNavigateAlbum;

class LibraryScreen extends StatefulWidget {
  final OnFileReady?      onPlayTrack;
  final OnNavigateAlbum?  onNavigateAlbum;
  final OnNavigateArtist? onNavigateArtist;
  /// Called when a library track can't be found locally and needs downloading.
  final void Function(BuildContext ctx, LibraryItem item)? onDownloadTrack;
  /// Online play path for saved server playlists.
  final Future<void> Function(BuildContext, SearchResult)? onPlayOnline;
  final OnPlayAlbum? onPlayAlbum;
  final OnPlayLocalAlbum? onPlayLocalAlbum;

  const LibraryScreen({
    super.key,
    this.onPlayTrack,
    this.onNavigateAlbum,
    this.onNavigateArtist,
    this.onDownloadTrack,
    this.onPlayOnline,
    this.onPlayAlbum,
    this.onPlayLocalAlbum,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<LibraryItem> _recent = [];
  /// Entrées locales dont le fichier n'est pas ICI — voir library_presence.
  Set<String> _missing = const {};
  int _playlistCount  = 0;
  int _artistCount    = 0;
  int _albumCount     = 0;
  int _trackCount     = 0;
  bool _loading       = true;
  /// ⚠️ Une erreur ICI laissait l'écran sur son indicateur POUR TOUJOURS: rien
  /// n'attrapait, donc `_loading` ne repassait jamais à faux et l'utilisateur
  /// n'avait aucun texte à rapporter (« l'onglet charge sans fin », beta 5
  /// Android). Un écran qui échoue doit le DIRE, avec le message, et offrir de
  /// réessayer — le diagnostic vient de là.
  String? _error;

  @override
  void initState() {
    super.initState();
    LocalDb.instance.addListener(_onDbChanged);
    _load();
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_onDbChanged);
    super.dispose();
  }

  void _onDbChanged() => _load();

  Future<void> _load() async {
    try {
      await _loadInner();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _loadInner() async {
    final all = await LocalDb.instance.getLibraryItems();
    // The user's OWN playlists live in the `playlists` table, not in
    // `library_items` (which only holds what was SAVED from the server), so
    // counting library items alone announced « 1 » — the automatic Favoris —
    // to someone holding a dozen playlists. The tile must count what the
    // screen behind it lists: local playlists + saved server ones + Favoris.
    final mine = await LocalDb.instance.getPlaylistsFiltered();
    final missing = await missingLocalLibraryRefs(all);
    if (!mounted) return;
    setState(() {
      _error         = null;
      _recent        = all;
      _missing       = missing;
      _playlistCount =
          mine.length + all.where((i) => i.type == 'playlist').length;
      _artistCount   = all.where((i) => i.type == 'artist').length;
      _albumCount    = all.where((i) => i.type == 'album').length;
      _trackCount    = all.where((i) => i.type == 'track').length;
      _loading       = false;
    });
  }

  void _pushPlaylists() => _push(LibraryPlaylistsScreen(
      onPlayTrack:  widget.onPlayTrack,
      onPlayOnline: widget.onPlayOnline,
      onPlayAlbum:  widget.onPlayAlbum,
      onPlayLocalAlbum: widget.onPlayLocalAlbum));

  void _pushArtists() => _push(LibraryArtistsScreen(
      onNavigateArtist: widget.onNavigateArtist));

  void _pushAlbums() => _push(LibraryAlbumsScreen(
      onNavigateAlbum: widget.onNavigateAlbum));

  void _pushTracks() => _push(LibraryTracksScreen(
      onPlayTrack:      widget.onPlayTrack,
      onDownloadTrack:  widget.onDownloadTrack,
      onPlayLocalAlbum: widget.onPlayLocalAlbum,
      onPlayAlbum:      widget.onPlayAlbum));

  void _push(Widget screen) {
    Navigator.push<void>(
        context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navLibrary)),
      body: _error != null
          ? _ErrorRetry(message: _error!, onRetry: () {
              setState(() { _error = null; _loading = true; });
              _load();
            })
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── 4 section tiles ──────────────────────────────────────
                SliverList(
                  delegate: SliverChildListDelegate([
                    _NavTile(
                      icon: Icons.queue_music,
                      color: cs.tertiary,
                      label: l10n.libraryPlaylists,
                      count: _playlistCount + 1, // +1 for auto Favoris
                      onTap: _pushPlaylists,
                    ),
                    _NavTile(
                      icon: Icons.person,
                      color: cs.secondary,
                      label: l10n.libraryArtists,
                      count: _artistCount,
                      onTap: _pushArtists,
                    ),
                    _NavTile(
                      icon: Icons.album,
                      color: cs.primary,
                      label: l10n.libraryAlbums,
                      count: _albumCount,
                      onTap: _pushAlbums,
                    ),
                    _NavTile(
                      icon: Icons.music_note,
                      color: cs.primary,
                      label: l10n.libraryTracks,
                      count: _trackCount,
                      onTap: _pushTracks,
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),

                // ── Recently added grid header ────────────────────────────
                if (_recent.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        l10n.libraryRecentlyAdded,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  // ── Recently added artwork grid ───────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 120,
                        mainAxisSpacing:    10,
                        crossAxisSpacing:   10,
                        // Pochette CARRÉE + deux lignes de texte, comme les
                        // rails de l'accueil (110 de large pour 158 de haut).
                        childAspectRatio:   0.70,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _RecentCard(
                          item: _recent[i],
                          cs:   cs,
                          elsewhere: _missing.contains(_recent[i].refId),
                          onTap: () => _onRecentTap(_recent[i]),
                        ),
                        childCount: _recent.length,
                      ),
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                ],

                if (_recent.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.library_music_outlined,
                              size: 64, color: cs.outline),
                          const SizedBox(height: 12),
                          Text(l10n.libraryEmptyHint,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: cs.outline)),
                        ],
                      ),
                    ),
                  ),
                // Room for the floating chrome (see shellInsetSliver).
                shellInsetSliver(context),
              ],
            ),
    );
  }

  void _onRecentTap(LibraryItem item) {
    if (_missing.contains(item.refId)) {
      AppSnack.show(context, libraryElsewhereLabel(context));
      return;
    }
    switch (item.type) {
      case 'album':
        _albumChoice(item);
      case 'artist':
        widget.onNavigateArtist?.call(item.name);
      case 'track':
        if (widget.onPlayTrack == null) return;
        _trackChoice(item);
      case 'playlist':
        _openServerPlaylist(item);
    }
  }

  /// Album card: play-choice popup (now / next / end / view). "Voir l'album"
  /// keeps the old navigation reachable — the popup must not turn the card
  /// into a dead end to the detail screen.
  Future<void> _albumChoice(LibraryItem item) async {
    final choice = await showPlayChoiceSheet(context,
        title: item.name,
        subtitle: item.artist,
        openLabel: context.l10n.playerViewAlbum);
    if (choice == null || !mounted) return;
    if (choice == PlayChoice.open) {
      widget.onNavigateAlbum?.call(item.name,
          collection: item.collectionSlug,
          platform:   item.platformName,
          artworkUrl: item.artworkUrl,
          albumId:    item.albumId);
      return;
    }
    // ⚠️ **La base LOCALE d'abord.** Un album de bibliothèque n'a pas
    // forcément d'identité de catalogue — un album IMPORTÉ n'en a aucune — et
    // le repli « chercher par NOM sur le serveur » lui trouvait alors un
    // homonyme, sans le moindre rapport: on lançait la lecture d'un autre
    // album. Un nom n'est pas une identité (deux « Final Fantasy VI »), et
    // c'est encore plus vrai entre un import local et le catalogue.
    //
    // Interroger le disque d'abord répare aussi un cas moins visible: un album
    // du catalogue entièrement téléchargé n'a plus besoin du réseau pour être
    // relancé.
    final localTracks = await LocalDb.instance
        .tracksForAlbum(albumId: item.albumId, albumName: item.name);
    if (!mounted) return;
    if (localTracks.isNotEmpty && widget.onPlayLocalAlbum != null) {
      if (choice == PlayChoice.now) {
        await widget.onPlayLocalAlbum!(context, localTracks);
      } else {
        await globalOnLocalQueueAdd?.call(localTracks,
            atEnd: choice == PlayChoice.end);
      }
      return;
    }

    // Sinon seulement, le catalogue: par ID quand on le connaît (les homonymes
    // partagent un nom), par nom en dernier recours.
    List<SearchResult> songs = const [];
    try {
      songs = (item.albumId != null && item.albumId!.isNotEmpty)
          ? await RewampDb.albumTracks(albumId: item.albumId!)
          : await RewampDb.browse(albumName: item.name, limit: 500);
    } catch (_) {}
    if (!mounted) return;
    if (songs.isEmpty) {
      // Unresolvable (offline, local-only album): fall back to the detail
      // screen rather than doing nothing.
      widget.onNavigateAlbum?.call(item.name,
          collection: item.collectionSlug,
          platform:   item.platformName,
          artworkUrl: item.artworkUrl,
          albumId:    item.albumId);
      return;
    }
    if (choice == PlayChoice.now) {
      await widget.onPlayAlbum?.call(context, songs);
    } else {
      await globalOnAlbumQueueAdd?.call(songs,
          atEnd: choice == PlayChoice.end, silent: false);
    }
  }

  /// Track card: same popup, then the existing play path or a queue insert.
  Future<void> _trackChoice(LibraryItem item) async {
    // La LIGNE, pas seulement son libellé: sans elle la feuille n'a rien à
    // interroger et n'offre que les trois choix de lecture. Un fichier
    // multi-sous-chansons ouvert depuis « Ajoutés récemment » ne proposait donc
    // pas « Voir les sous-chansons » — alors que la même entrée, atteinte
    // depuis l'onglet « Morceaux », la proposait: cette liste-là passe déjà une
    // ligne. Le résolveur est le même des deux côtés.
    final resolved = await _resolveLibraryRow(item);
    if (!mounted) return;
    final choice = await showPlayChoiceSheet(context,
        title: item.name, subtitle: item.artist, track: resolved.track);
    if (choice == null || !mounted) return;
    await _playLibraryTrack(item, choice: choice);
  }

  /// A library item of type 'playlist' is always a SERVER playlist (local
  /// playlists live in the `playlists` table, not `library_items`). Reconstruct
  /// the server DTO and open it read-only — same as the Playlists screen.
  void _openServerPlaylist(LibraryItem item) {
    if (widget.onPlayOnline == null) return;
    Navigator.push<void>(context, MaterialPageRoute(
      builder: (_) => PlaylistTracksScreen(
        playlist: Playlist(
          id:       item.refId,
          slug:     item.filename ?? '',
          name:     item.name,
          coverUrl: item.artworkUrl,
        ),
        onTap:       widget.onPlayOnline!,
        onPlayAlbum: widget.onPlayAlbum,
      ),
    ));
  }

  /// Résout l'entrée de bibliothèque en LIGNE de piste.
  ///
  /// Extrait pour n'exister qu'UNE fois: la feuille de choix en a besoin (pour
  /// proposer « Voir les sous-chansons », qui exige le chemin du fichier et le
  /// compte) et la lecture aussi. Deux copies de cette résolution divergeraient
  /// — elle connaît DEUX formes d'identité, et « tout site qui n'en cherche
  /// qu'une casse quelque chose ».
  ///
  /// Rend aussi `sub` (la sous-chanson demandée) et `qi` (négatif quand
  /// l'entrée vise le CONTENEUR, sans suffixe), dont la lecture a besoin.
  /// `exact` est la ligne de LA sous-chanson demandée, `track` un repli quand
  /// elle n'a jamais été jouée (le fichier est là, la ligne pas encore). Les
  /// deux sont rendus: l'appelant force l'index demandé et n'affiche un titre
  /// que si la ligne exacte existe.
  Future<({TrackRecord? track, TrackRecord? exact, String base, int sub,
      int qi})> _resolveLibraryRow(LibraryItem item) async {
    // refId may carry a "?subsong=N" suffix for a single-file multi-subsong
    // container (see playerLibraryRefId) — split it off and resolve the exact
    // subsong from the file's already-downloaded tracks.
    final (base, parsedSub) = splitLibraryRefId(item.refId);
    final qi  = parsedSub == null ? -1 : 0; // <0 = container-level entry
    final sub = parsedSub ?? 0;

    // getTrackByOnlineId returns ONE arbitrary row (LIMIT 1 — e.g. the other
    // favourited subsong): refine to the requested subsong whenever the found
    // row doesn't match, INCLUDING sub == 0 (the old `sub > 0` guard replayed
    // subsong 1 when the user asked for subsong 0).
    TrackRecord? anyRow = await LocalDb.instance.getTrackByOnlineId(base);
    // Rien sous l'identité NUE: sur un album conteneur, les lignes `tracks`
    // portent la forme `<uuid>#<i>` et rien ne porte l'uuid seul. Une entrée
    // keyée `<uuid>?subsong=N` (celle que la synchro fabriquait) ne trouvait
    // donc aucun fichier — la bibliothèque la croyait absente et relançait un
    // TÉLÉCHARGEMENT complet de l'album. La résolution par (uuid,
    // sous-chanson) connaît les deux formes.
    anyRow ??= await LocalDb.instance.trackByOnlineIdAndSubsong(base, sub);
    final filePath = anyRow?.filePath ?? base;
    TrackRecord? exact =
        (anyRow != null && anyRow.subsongIdx == sub) ? anyRow : null;
    if (exact == null) {
      final all = await LocalDb.instance.getTracksForFile(filePath);
      exact  = all.where((t) => t.subsongIdx == sub).firstOrNull;
      anyRow ??= all.firstOrNull;
    }
    // Playable when the file is on disk, even if THIS subsong has no DB row
    // yet (never played) — the caller then forces the requested index.
    return (track: exact ?? anyRow, exact: exact, base: base,
            sub: sub, qi: qi);
  }

  Future<void> _playLibraryTrack(LibraryItem item,
      {PlayChoice choice = PlayChoice.now}) async {
    final resolved = await _resolveLibraryRow(item);
    final sub   = resolved.sub;
    final qi    = resolved.qi;
    final track = resolved.track;
    final exact = resolved.exact;
    final base  = resolved.base;
    // Resolve on-disk presence BEFORE the mounted check — awaiting after it
    // would make the check meaningless for the context uses below.
    final onDisk = track != null && await File(track.filePath).exists();
    if (!mounted) return;
    if (!onDisk) {
      if (widget.onDownloadTrack != null) {
        widget.onDownloadTrack!(context, item);
      } else {
        AppSnack.show(context, context.l10n.libraryDownloadFromSearchFirst, duration: const Duration(seconds: 3));
      }
      return;
    }
    // Entrée de CONTENEUR (aucun suffixe `?subsong=`): le fichier joue TOUTES
    // ses sous-chansons, comme il a été ajouté (« le song complet »). Les
    // entrées à une seule sous-chanson tombent dans la lecture simple.
    // Partagé avec l'onglet Morceaux — voir playWholeFileLibraryEntry.
    if (qi < 0 &&
        await playWholeFileLibraryEntry(context,
            item: item, track: track, base: base, choice: choice,
            onPlayAlbum: widget.onPlayAlbum,
            onPlayLocalAlbum: widget.onPlayLocalAlbum)) {
      return;
    }
    if (!mounted) return;
    if (choice != PlayChoice.now) {
      final queueLocal = globalOnLocalQueueAdd;
      if (queueLocal == null) return;
      // The exact subsong row when it exists; else a minimal record forcing
      // the requested index (same rule as the play path below).
      final row = exact ??
          TrackRecord(
            id:         '',
            filePath:   track.filePath,
            entryPath:  '',
            subsongIdx: sub,
            title:      item.name,
            artist:     track.artist,
            metaAlbum:  track.metaAlbum,
            onlineId:   track.onlineId,
            albumId:    track.albumId ?? item.albumId,
            artworkUrl: track.artworkUrl ?? item.artworkUrl,
            formatExt:  track.formatExt,
            source:     track.source,
            isFavorite: false,
            inLibrary:  false,
            playCount:  0,
          );
      await queueLocal([row], atEnd: choice == PlayChoice.end);
      return;
    }
    widget.onPlayTrack!(
      track.filePath,
      exact?.displayTitle ?? item.name,
      artist:     track.artist,
      album:      track.metaAlbum,
      // Without the album id the player can't offer "Voir l'album" and falls
      // back to the subsong-container link.
      albumId:    track.albumId ?? item.albumId,
      formatExt:  track.formatExt,
      onlineId:   track.onlineId,
      artworkUrl: track.artworkUrl ?? item.artworkUrl,
      // ALWAYS the requested subsong — never the arbitrary row's index.
      subsongIdx: sub,
      durationS:  exact?.durationS,
    );
  }
}

// ── Nav tile ─────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       label;
  final int          count;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label),
      subtitle: Text(context.l10n.libraryItemCount(count),
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// ── Recent card ───────────────────────────────────────────────────────────────

/// Ce qu'on met sous le nom d'une carte: le titre de la piste s'il diffère du
/// nom affiché (conteneur), l'artiste sinon.
String? _secondLine(LibraryItem item) {
  final t = item.trackTitle;
  if (t != null && t.isNotEmpty && t != item.name) return t;
  final a = item.artist;
  return (a != null && a.isNotEmpty) ? a : null;
}

class _RecentCard extends StatelessWidget {
  final LibraryItem   item;
  final ColorScheme   cs;
  final VoidCallback? onTap;
  /// Sur un autre appareil (library_presence): grisée, la deuxième ligne le dit.
  final bool          elsewhere;

  const _RecentCard(
      {required this.item, required this.cs, this.onTap,
      this.elsewhere = false});

  @override
  Widget build(BuildContext context) {
    final isAlbum    = item.type == 'album';
    final isPlaylist = item.type == 'playlist';
    final second     = elsewhere
        ? libraryElsewhereLabel(context)
        : _secondLine(item);
    return HoverGrow(child: GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: elsewhere ? 0.45 : 1.0,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CARRÉE, comme sur l'accueil: le rail y donne une taille fixe à
          // `ArtworkImage`, donc toutes les pochettes sont recadrées dans le
          // même format. Ici la vignette prenait la hauteur RESTANTE de la
          // cellule — une boîte qui n'est pas carrée — et une image qui ne
          // l'est pas non plus s'y recadrait autrement d'une tuile à l'autre.
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // EXACTEMENT la pochette des rails de l'accueil (voir
                // RailArtwork): carrée, recadrée, coins à 8, et le placeholder
                // thématisé par plateforme plutôt qu'un aplat + icône.
                RailArtwork(
                  url:          item.artworkUrl,
                  artist:       item.artist,
                  album:        item.album ?? item.name,
                  formatHint:   item.formatExt ?? item.filename,
                  platformName: item.platformName,
                ),
                // Album: queue_music badge bottom-right (home screen style)
                if (isAlbum)
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
                // Server playlist: a small server badge marks it as remote /
                // read-only (it's not editable like a local playlist).
                if (isPlaylist)
                  Positioned(
                    bottom: 4,
                    right:  4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: cs.surface.withAlpha(200),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.cloud, size: 14, color: cs.onSurface),
                    ),
                  ),
                if (item.isFavorite)
                  const Positioned(
                    top:   2,
                    right: 2,
                    child: Icon(
                      Icons.star_rounded,
                      size: 22,
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
          // Flexible: la pochette a désormais une hauteur imposée par sa
          // largeur, donc c'est le TEXTE qui doit céder si la tuile est plus
          // courte que prévu (écran très étroit) — sinon la colonne déborde.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Chaque ligne est FLEXIBLE, pas seulement le bloc.
                // `Flexible` en fit loose ne fait que PLAFONNER la hauteur
                // offerte au bloc: à l'intérieur, un `Column` en
                // `mainAxisSize.min` pose quand même ses enfants à leur hauteur
                // naturelle et déborde — deux `labelSmall` demandaient 32,03 px
                // pour 31,6 offerts par la tuile, soit « A RenderFlex
                // overflowed by 0.429 pixels ». Le débordement est
                // sous-pixellaire (arrondi de `childAspectRatio`), donc laisser
                // les lignes céder ne coûte rien de visible; l'assertion, si.
                Flexible(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                // Un MORCEAU affichait le nom de son fichier — celui de
                // l'ALBUM dès que le fichier est un conteneur (`.psf` d'album
                // jw_psf, `.nsf` multi-subsongs). La deuxième ligne porte donc
                // le titre de la piste quand il apporte quelque chose, et
                // l'artiste sinon.
                if (second != null)
                  Flexible(
                    child: Text(
                      second,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant),
                    ),
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

/// L'état d'échec partagé par les écrans dont TOUT le contenu vient de la base:
/// le message exact (c'est lui qu'on demande à un testeur) et un bouton pour
/// refaire l'essai.
class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 32),
            const SizedBox(height: 12),
            Text(l10n.searchError(message),
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.tonal(
                onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}
