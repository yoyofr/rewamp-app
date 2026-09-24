import 'package:flutter/material.dart';

import 'album_detail_screen.dart';
import 'app_snack.dart';
import 'artwork_image.dart';
import 'browse_screen.dart' show BrowseResultsScreen;
import 'container_subsong_screen.dart';
import 'favorite_color.dart';
import 'l10n.dart';
import 'podium_badge.dart';
import 'hover_grow.dart';
import 'local_db.dart';
import 'rewamp_db.dart';
import 'scrolling_text.dart';
import 'track_options_sheet.dart';

/// THE canonical song row — used by search results, browse lists, artist
/// results and playlist tracks. One place owns the tap routing:
///   query-matched subsong → resolve + play that exact track,
///   whole-album row (joshw archive/container album) → AlbumDetailScreen,
///   multi-subsong file → ContainerSubsongScreen,
///   plain song → play.
/// It also shows the live favourite star, the album ▶ shortcut on album rows,
/// and the '…' options sheet. Previously duplicated as search's _SongTile and
/// browse's _BrowseSongTile, which had drifted apart (no star / no album row /
/// missing album navigation depending on the copy).
/// La ligne de sous-titre d'une tuile de morceau: ce que le morceau EST.
///
/// ⚠️ La COLLECTION n'y est PAS — elle dit d'où il vient, pas ce qu'il est, et
/// elle a sa propre ligne en dessous. L'y remettre la noierait au milieu de six
/// autres mentions, ce qui était le cas avant et la rendait illisible sur une
/// recherche qui brasse dix collections.
String songTileSubtitle(SearchResult r) => [
      if (r.matchSubsongTitle != null) r.displayTitle,
      if (r.artistLabel.isNotEmpty) r.artistLabel,
      if (r.album != null && r.album!.isNotEmpty && r.album != r.displayTitle)
        r.album,
      if (r.platform != null && r.platform!.isNotEmpty) r.platform,
      if (r.formatExt.isNotEmpty) r.formatExt.toUpperCase(),
      if (r.fileSize > 0) r.fileSizeLabel,
    ].join(' · ');

class SongTile extends StatefulWidget {
  final SearchResult result;
  final Future<void> Function(BuildContext, SearchResult) onTap;
  final OnNavigateAlbum?  onNavigateAlbum;
  final OnNavigateArtist? onNavigateArtist;
  final OnQueueAdd?       onQueueAdd;
  final OnPlayAlbum?      onPlayAlbum;
  /// Artwork-grid cell instead of the default list row (same tap routing,
  /// same options sheet on long-press). [small] = compact grid.
  final bool grid;
  final bool small;
  /// Montre la COLLECTION de la ligne, sur une seconde ligne de sous-titre en
  /// petit — pour les listes qui en mélangent plusieurs (recherche, écran
  /// artiste, écran groupe).
  final bool showCollection;

  /// Whether a row may be treated as a WHOLE ALBUM (tap opens the album, and
  /// the play-album action appears). True for search results, where a text
  /// query can legitimately match a container by its game name.
  ///
  /// FALSE for browse listings. The album-row test relies on matchSubsongTitle
  /// being null to mean "matched by album, not by track title", and browse_music
  /// runs no text search — so it is null on every row there and the test would
  /// call the entire catalogue an album.
  final bool albumRowsAllowed;

  const SongTile({
    super.key,
    required this.result,
    required this.onTap,
    this.onNavigateAlbum,
    this.onNavigateArtist,
    this.onQueueAdd,
    this.onPlayAlbum,
    this.albumRowsAllowed = true,
    this.grid  = false,
    this.small = false,
    this.showCollection = false,
  });

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
  bool _inLibrary = false;

  @override
  void initState() {
    super.initState();
    LocalDb.instance.addListener(_recheck);
    _recheck();
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_recheck);
    super.dispose();
  }

  void _recheck() {
    final id = widget.result.songId;
    if (id.isEmpty) return;
    // Track keys are subsong-scoped ('<id>?subsong=N') — match any subsong.
    LocalDb.instance.isTrackInLibraryAnySubsong(id).then((v) {
      if (mounted && v != _inLibrary) setState(() => _inLibrary = v);
    });
  }

  /// Tapping a plain song with something already playing asks WHERE it goes —
  /// the same popup the discovery rails and the library cards use — instead of
  /// wiping the queue without warning. [showPlayChoiceSheet] answers `now`
  /// straight away (no popup) when there is nothing to insert relative to, so
  /// the common case is unchanged.
  Future<void> _playOrQueue(BuildContext ctx, SearchResult row) async {
    final r = widget.result;
    final choice = await showPlayChoiceSheet(ctx,
        title: row.displayTitle,
        subtitle: r.artistLabel.isEmpty ? null : r.artistLabel,
        // La ligne elle-même: la feuille y lit de quoi proposer « Voir
        // l'album » / « Voir les subsongs ». `r` et non `row` — `row` est la
        // ligne RÉSOLUE pour la lecture, `r` porte l'identité du conteneur.
        result: r);
    if (choice == null || !ctx.mounted) return;
    if (choice == PlayChoice.now) {
      // « Lire maintenant » REMPLACE la file — c'est sa promesse, et le popup
      // n'existe que pour la faire consentir. `widget.onTap` route vers
      // `_downloadAndPlayOnline`, dont l'entonnoir (`_onFileReadyAsAlbum`) ne
      // touche PAS la file, exprès: c'est lui que l'avancement d'album
      // emprunte. Le crochet du shell (`_startAlbumQueue(ctx, [r])`) fait le
      // remplacement ET sait déplier un conteneur; onTap reste le repli d'un
      // hôte qui ne l'a pas câblé.
      final playNow = globalOnPlayNowSong;
      if (playNow != null) {
        await playNow(row);
      } else {
        await widget.onTap(ctx, row);
      }
      return;
    }
    final add = widget.onQueueAdd ?? globalOnQueueAdd;
    await add?.call(row, atEnd: choice == PlayChoice.end);
  }

  /// A row that IS a whole album (joshw archive / container album: album_id +
  /// several tracks, not an already-expanded track row).
  bool get _isAlbumRow =>
      widget.albumRowsAllowed && RewampDb.isAlbumLevelMatch(widget.result);

  void _openAlbum(BuildContext ctx) {
    final r = widget.result;
    final name = (r.album != null && r.album!.isNotEmpty)
        ? r.album!
        : r.displayTitle;
    if (name.isEmpty) return;
    // Prefer the host screen's album navigation (it wires its own callbacks);
    // fall back to a direct push so album rows always navigate.
    final nav = widget.onNavigateAlbum;
    if (nav != null) {
      nav(name,
          collection: r.collection,
          platform:   r.platform,
          artworkUrl: r.artworkUrl,
          albumId:    r.albumId);
      return;
    }
    Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => AlbumDetailScreen(
        albumName:      name,
        albumId:        r.albumId,
        platformName:   r.platform,
        collectionSlug: r.collection,
        artworkUrl:     r.artworkUrl,
        onTap:          widget.onTap,
        onPlayAlbum:    widget.onPlayAlbum,
        onQueueAdd:     widget.onQueueAdd,
      ),
    ));
  }

  /// ▶ on an album row: queue the whole album, in album order (sortBy
  /// 'position' — matches AlbumDetailScreen's own fetches).
  Future<void> _playWholeAlbum(BuildContext ctx) async {
    final id = widget.result.albumId;
    final onPlay = widget.onPlayAlbum;
    if (id == null || onPlay == null) return;
    try {
      final tracks =
          await RewampDb.albumTracks(albumId: id, sortBy: 'position');
      if (tracks.isNotEmpty && ctx.mounted) {
        await onPlay(ctx, tracks);
      }
    } catch (e) {
      if (ctx.mounted) {
        AppSnack.show(ctx, ctx.l10n.songTilePlayFailed('$e'));
      }
    }
  }

  Future<void> _handleTap(BuildContext context) async {
    final r = widget.result;
    // Query matched a TRACK title inside a container → play that exact track,
    // skipping the picker. For a joshw container (album_id set) the row has
    // no per-track file, so resolve it from the album's `tracks` (match by
    // the player index when present, else by title); a track without a
    // subsong is a distinct file (2SF), one with a subsong shares the
    // container (GBS). Server sets match_track_* only when the track beat the
    // title/album match.
    if (r.matchSubsongTitle != null) {
      // Une seule définition de « quelle piste le serveur a nommé » —
      // partagée avec « Tout lire » (RewampDb.resolveMatchedTracks), sinon les
      // deux chemins divergent et le bouton joue autre chose que le tap.
      final pick = await RewampDb.resolveMatchedTrack(r);
      if (context.mounted) await _playOrQueue(context, pick);
      return;
    }
    // Whole-album row → album detail.
    if (_isAlbumRow) {
      _openAlbum(context);
      return;
    }
    // Route to ContainerSubsongScreen when the file holds several subsongs.
    // Generic: the server's subsong_count decides it for ANY format; the
    // kContainerFormats list is the fallback for un-annotated rows.
    if (RewampDb.isContainerRow(r)) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ContainerSubsongScreen(
          result:      r,
          onTap:       widget.onTap,
          onPlayAll:   widget.onPlayAlbum,
          onArtistTap: widget.onNavigateArtist != null
              ? (name) => widget.onNavigateArtist!(name)
              : null,
        ),
      ));
      return;
    }
    await _playOrQueue(context, r);
  }

  void _showOptions(BuildContext context) {
    final r = widget.result;
    showTrackOptions(
      context, r,
      onNavigateAlbum: widget.onNavigateAlbum ??
          (r.album != null && r.album!.isNotEmpty
              ? (name, {collection, platform, artworkUrl, albumId}) =>
                  _openAlbum(context)
              : null),
      onNavigateArtist: widget.onNavigateArtist,
      onNavigateTag: (tag, {category}) =>
          Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BrowseResultsScreen(
          label:       tag,
          tags:        [tag],
          tagCategories: category != null ? [category] : null,
          showFilter:  true,
          onTap:       widget.onTap,
          onPlayAlbum: widget.onPlayAlbum,
        ),
      )),
      onQueueAdd: widget.onQueueAdd,
    );
  }

  /// Artwork cell: cover + title (+ subtitle when large), library star kept,
  /// options on long-press (no room for a '…' button).
  Widget _buildGridCell(BuildContext context) {
    final r     = widget.result;
    final cs    = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final small = widget.small;
    return HoverGrow(child: InkWell(
      onTap:      () => _handleTap(context),
      onLongPress: () => _showOptions(context),
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ArtworkImage(
                  url:          r.artworkUrl,
                  artist:       r.artistNames.firstOrNull,
                  album:        r.album,
                  // Themed per-platform placeholder (rewamp sun in the origin
                  // platform's colours) when no cover is available.
                  formatHint:   r.formatExt,
                  platformName: r.platform,
                  borderRadius: BorderRadius.circular(8),
                ),
                if (_inLibrary)
                  const Positioned(
                    top: 4, right: 4,
                    child: Icon(Icons.star_rounded,
                        size: 16,
                        color: kFavoriteColor,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 4)
                        ]),
                  ),
                // Competition podium (gold/silver/bronze) — tapping it opens
                // the compo, so it sits above the artwork like the video badge.
                if (r.podium != null)
                  Positioned(
                    top: 4, right: 4,
                    child: PodiumBadge(r.podium!, size: 16),
                  ),
                // Linked demozoo video badge.
                if (r.hasVideo)
                  const Positioned(
                    top: 4, left: 4,
                    child: Icon(Icons.ondemand_video,
                        size: 14,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 4)
                        ]),
                  ),
                if (_isAlbumRow && widget.onPlayAlbum != null)
                  Positioned(
                    right: 4, bottom: 4,
                    child: _GridPlayButton(
                        onPlay: () => _playWholeAlbum(context)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            r.matchSubsongTitle ?? r.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: small ? theme.bodySmall : theme.bodyMedium,
          ),
          if (!small)
            Text(
              [
                if (r.artistLabel.isNotEmpty) r.artistLabel,
                if (r.formatExt.isNotEmpty) r.formatExt.toUpperCase(),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodySmall?.copyWith(color: cs.outline),
            ),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.grid) return _buildGridCell(context);
    final r  = widget.result;
    final showCollectionLine =
        widget.showCollection && r.collection.isNotEmpty;
    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          ArtworkImage(
            url:          r.artworkUrl,
            artist:       r.artistNames.firstOrNull,
            album:        r.album,
            size:         40,
            // Same themed per-platform placeholder the GRID cell already used
            // (rewamp sun in the origin platform's colours). This mode passed
            // neither formatHint nor a way through to it: an explicit
            // `placeholder:` OVERRIDES the built-in one, so every list row got a
            // plain "LHA"/"MOD" text pill while the very same track showed real
            // platform art in grid and album views.
            formatHint:   r.formatExt,
            platformName: r.platform,
            borderRadius: BorderRadius.circular(4),
          ),
          if (_inLibrary)
            const Positioned(
              top:   2,
              right: 2,
              child: Icon(
                Icons.star_rounded,
                size: 14,
                color: kFavoriteColor,
                shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
              ),
            ),
        ],
      ),
      // When the query matched a SUBSONG title, show it as the title and the
      // game/album as context underneath (the tap plays that subsong directly).
      title: Row(children: [
        Flexible(
          // shrinkWrap: le badge podium et l'icône vidéo suivent le titre
          // dans cette Row; sans lui la vue défilante prendrait toute la
          // largeur et les pousserait au bord droit même sur un titre court.
          child: ScrollingText(
              text: r.matchSubsongTitle ?? r.displayTitle, shrinkWrap: true),
        ),
        if (r.podium != null)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: PodiumBadge(r.podium!, size: 15),
          ),
        // Linked demozoo video — the ▶ tile/button appears in the player.
        if (r.hasVideo)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(Icons.ondemand_video,
                size: 14, color: Theme.of(context).colorScheme.primary),
          ),
      ]),
      // La COLLECTION va sur une SECONDE ligne, en petit, et non dans la liste
      // pointée du dessus: cette liste dit ce qu'est le morceau (artiste,
      // album, plateforme, format, taille), la collection dit D'OÙ IL VIENT.
      // Noyée au milieu des autres, elle était illisible sur une recherche qui
      // en mélange dix — et c'est justement là qu'on la cherche.
      isThreeLine: showCollectionLine,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            songTileSubtitle(r),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (showCollectionLine)
            Text(
              // Le NOM, pas le slug: « jw_dsf » ne dit rien à personne.
              RewampDb.collectionLabel(r.collection),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // Même corps que la note et le « Top N % » de la ligne: c'est la
              // taille des mentions accessoires de cette tuile.
              style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Durée: celle du FICHIER pour un conteneur (`total_length_ms`),
          // celle du morceau sinon — voir RewampDb.listDurationMs. Inconnue =
          // rien d'affiché, jamais « 0:00 »: des collections entières n'ont
          // aucune durée en base.
          if (RewampDb.listDurationMs(r) != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                RewampDb.formatDurationMs(RewampDb.listDurationMs(r)!),
                style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          if (r.rating != null)
            Text(
              '★ ${r.rating!.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 10),
            ),
          // Popularité = un RANG (percentile), pas une jauge: on n'affiche donc
          // que le haut du panier, sous forme de « Top N % ». En dessous de 95
          // le chiffre ne dit rien à personne et encombrerait chaque ligne.
          if ((r.popularity ?? 0) >= 95)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                // Le percentile plafonne à 100, et « Top 0 % » ne veut rien
                // dire — le meilleur rang possible, c'est le premier centile.
                // Mesuré sur le serveur: Wild Arms et Commando sont à 100.
                context.l10n.statsTopPercent(
                    (100 - r.popularity!).clamp(1, 100)),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary),
              ),
            ),
          if (_isAlbumRow && widget.onPlayAlbum != null)
            IconButton(
              icon: const Icon(Icons.play_circle_outline, size: 22),
              tooltip: context.l10n.albumPlayAlbum,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => _playWholeAlbum(context),
            ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => _showOptions(context),
          ),
        ],
      ),
      onTap: () => _handleTap(context),
    );
  }
}


/// ▶ over a grid cell's artwork (scrimmed circle so it stays visible on any
/// cover) — album rows only.
class _GridPlayButton extends StatelessWidget {
  final Future<void> Function() onPlay;
  const _GridPlayButton({required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPlay,
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.play_arrow, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}
