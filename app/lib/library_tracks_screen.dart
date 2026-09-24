
import 'package:flutter/material.dart';

import 'app_snack.dart';
import 'favorite_color.dart';
import 'artwork_image.dart';
import 'hover_grow.dart';
import 'local_db.dart';
import 'l10n.dart';
import 'library_playlists_screen.dart' show OnFileReady;
import 'library_presence.dart';
import 'library_toolbar.dart';
import 'local_badge.dart';
import 'local_open.dart' show tracksForLocalPath;
import 'player_controller.dart' show PlayerController;
import 'rewamp_db.dart' show OnPlayAlbum, OnPlayLocalAlbum, SearchResult;
import 'scrolling_text.dart';
import 'shell_insets.dart';
import 'sync_service.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp_audio/rewamp_audio.dart' show RewampAudio;
import 'track_options_sheet.dart'
    show showPlayChoiceSheet, PlayChoice, globalOnLocalQueueAdd,
        globalOnAlbumQueueAdd;
import 'user_settings.dart';
import 'view_mode_picker.dart';

/// Joue — ou enfile — une entrée de bibliothèque qui vise le FICHIER ENTIER
/// (aucun suffixe `?subsong=`, la convention du conteneur), en dépliant
/// TOUTES ses sous-chansons. Rend `true` quand elle a pris la main.
///
/// Partagée par les deux écrans qui lancent une entrée de bibliothèque —
/// « Ajoutés récemment » et l'onglet Morceaux. L'onglet n'avait AUCUNE
/// gestion du conteneur et jouait la ligne que la base avait sous la main,
/// c'est-à-dire une seule piste; en écrire une seconde copie ici l'aurait fait
/// diverger de la première à la prochaine correction.
///
/// Deux chemins, et le discriminant est l'identité de CATALOGUE:
/// - **local** (`onlineId` nul): le routeur de l'ouverture locale, qui connaît
///   la règle « M3U voisin d'abord » et les titres que donne le fichier;
/// - **catalogue**: un `SearchResult` conteneur, déplié par
///   `expandContainerAlbum`, qui préserve l'identité `<uuid>#i` de chaque
///   sous-chanson. Un `SearchResult` synthétique irait sinon chercher un
///   `songId` qui n'est qu'un chemin.
Future<bool> playWholeFileLibraryEntry(
  BuildContext context, {
  required LibraryItem item,
  required TrackRecord track,
  required String base,
  required PlayChoice choice,
  OnPlayAlbum? onPlayAlbum,
  OnPlayLocalAlbum? onPlayLocalAlbum,
}) async {
  if (track.onlineId == null) {
    final ctrl = PlayerController.current;
    final rows = ctrl == null
        ? const <TrackRecord>[]
        : await tracksForLocalPath(track.filePath, controller: ctrl);
    if (!context.mounted) return true;
    if (rows.length > 1) {
      if (choice == PlayChoice.now) {
        await onPlayLocalAlbum?.call(context, rows);
      } else {
        await globalOnLocalQueueAdd?.call(rows,
            atEnd: choice == PlayChoice.end);
      }
      return true;
    }
    return false;
  }
  if (onPlayAlbum == null) return false;
  int count = 1;
  try {
    count = RewampAudio().probeSubsongCount(track.filePath);
  } catch (_) {}
  if (count <= 1) return false;
  final container = SearchResult(
    songId:       track.onlineId ?? base,
    collection:   item.collectionSlug ?? '',
    title:        item.name,
    filename:     item.filename ?? p.basename(track.filePath),
    album:        track.metaAlbum,
    albumId:      track.albumId ?? item.albumId,
    formatExt:    item.formatExt ?? track.formatExt ?? '',
    downloadUrl:  item.downloadUrl,
    fileSize:     0,
    year:         null,
    totalCount:   0,
    artistNames:  track.artist != null ? [track.artist!] : const [],
    platform:     item.platformName,
    artworkUrl:   item.artworkUrl,
    subsongCount: count,
    localPath:    track.filePath,
  );
  if (!context.mounted) return true;
  if (choice != PlayChoice.now) {
    // En file: `_onAlbumQueueAdd` déplie les sous-chansons du conteneur
    // exactement comme `_startAlbumQueue` sur le chemin de lecture.
    await globalOnAlbumQueueAdd?.call([container],
        atEnd: choice == PlayChoice.end, silent: false);
  } else {
    await onPlayAlbum(context, [container]);
  }
  return true;
}

class LibraryTracksScreen extends StatefulWidget {
  final OnFileReady? onPlayTrack;
  final void Function(BuildContext ctx, LibraryItem item)? onDownloadTrack;
  /// Lance une file de pistes LOCALES — ce que devient un fichier CONTENEUR
  /// importé (une entrée sans suffixe `?subsong=`), déplié en toutes ses
  /// sous-chansons.
  final OnPlayLocalAlbum? onPlayLocalAlbum;
  /// Lance une file de pistes de CATALOGUE — ce que devient un conteneur
  /// (`.sid`, `.nsf`…) déplié en toutes ses sous-chansons.
  final OnPlayAlbum? onPlayAlbum;

  const LibraryTracksScreen({super.key, this.onPlayTrack, this.onDownloadTrack,
      this.onPlayLocalAlbum, this.onPlayAlbum});

  @override
  State<LibraryTracksScreen> createState() => _LibraryTracksScreenState();
}

class _LibraryTracksScreenState extends State<LibraryTracksScreen> {
  List<LibraryItem> _items = [];
  /// Entrées LOCALES dont le fichier n'est pas sur cet appareil. Une telle
  /// entrée est légitime — elle vit sur un autre appareil du même compte et le
  /// pull la pose exprès pour qu'elle se relie à sa copie — mais elle n'est
  /// pas jouable ICI, et l'afficher comme une piste locale ordinaire envoyait
  /// l'utilisateur chercher « où est passé mon fichier ». Calculé au
  /// chargement (un stat par entrée), jamais dans le build.
  Set<String> _missing = const {};
  bool _onAnotherDevice(LibraryItem it) => _missing.contains(it.refId);
  bool _loading = true;
  String _query = '';
  LibrarySort _sort = LibrarySortLabel.fromPref(
      UserSettings.instance.librarySort('track'), LibrarySort.added);
  bool _asc = UserSettings.instance.librarySortAsc('track');
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
    LocalDb.instance.getLibraryItems(type: 'track').then((items) async {
      final missing = await missingLocalLibraryRefs(items);
      if (!mounted) return;
      _missing = missing;
      if (mounted) setState(() { _items = items; _loading = false; });
    });
  }

  List<LibraryItem> get _visible =>
      sortLibraryItems(filterLibraryItems(_items, _query), _sort, _asc);

  /// Retrait: local ET compte. Passer par `recordTrackMembership` est ce qui
  /// évite le retour de l'entrée à la synchro suivante — le compte l'ayant
  /// toujours, le rattrapage la remettrait.
  Future<void> _remove(LibraryItem item) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await LocalDb.instance.removeFromLibrary('track', item.refId);
    await SyncService.recordTrackMembership(
      refId:     item.refId,
      value:     false,
      title:     item.name,
      artist:    item.artist,
      album:     item.album,
      formatExt: item.formatExt,
    );
    // Message NEUTRE: `playerRemovedFromLibrary` dit « Morceau retiré… », ce
    // qui était faux sur un artiste et sur un album.
    AppSnack.showOn(messenger, l10n.libraryRemoved,
        duration: const Duration(seconds: 2));
  }

  Future<void> _play(LibraryItem item) async {
    // ref_id is '<onlineId or filePath>?subsong=<idx>' — the tracks table
    // stores the BARE online id, so the raw key never matches and every play
    // used to detour through the download path (spurious "Téléchargement
    // impossible" banner).
    final (base, sub) = splitLibraryRefId(item.refId);
    TrackRecord? track = await LocalDb.instance.getTrackByOnlineId(base);
    // Rien sous l'identité nue: un album conteneur porte `<uuid>#<i>`.
    track ??= await LocalDb.instance.trackByOnlineIdAndSubsong(base, sub ?? 0);
    if (track != null && sub != null && track.subsongIdx != sub) {
      final all = await LocalDb.instance.getTracksForFile(track.filePath);
      track = all.where((t) => t.subsongIdx == sub).firstOrNull ?? track;
    }
    track ??= (await LocalDb.instance.getTracksForFile(base))
        .where((t) => sub == null || t.subsongIdx == sub)
        .firstOrNull;
    if (!mounted) return;
    if (track == null) {
      widget.onDownloadTrack?.call(context, item);
      return;
    }
    // The resolved row can be another subsong of the same file (LIMIT 1) —
    // always play the REQUESTED index, with the trace's name when the exact
    // row is missing.
    final wantIdx = sub ?? track.subsongIdx;
    final exactRow = track.subsongIdx == wantIdx ? track : null;
    // With something already playing, ask WHERE this goes instead of wiping
    // the queue — same popup as the library cards and the discovery rails.
    // It answers `now` without showing itself when there is nothing to insert
    // relative to.
    final choice = await showPlayChoiceSheet(context,
        title: exactRow?.displayTitle ?? item.name, subtitle: item.artist,
        track: exactRow);
    if (choice == null || !mounted) return;
    // Entrée de CONTENEUR (aucun suffixe `?subsong=`): toutes ses
    // sous-chansons, comme depuis « Ajoutés récemment ».
    if (sub == null &&
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
      // the requested index (same rule as the play call below).
      await queueLocal([
        exactRow ??
            TrackRecord(
              id:         '',
              filePath:   track.filePath,
              entryPath:  '',
              subsongIdx: wantIdx,
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
            ),
      ], atEnd: choice == PlayChoice.end);
      return;
    }
    widget.onPlayTrack!(
      track.filePath,
      exactRow?.displayTitle ?? item.name,
      artist:     track.artist,
      album:      track.metaAlbum,
      albumId:    track.albumId ?? item.albumId,
      formatExt:  track.formatExt,
      onlineId:   track.onlineId,
      artworkUrl: track.artworkUrl ?? item.artworkUrl,
      subsongIdx: wantIdx,
      durationS:  exactRow?.durationS,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n  = context.l10n;
    final cs    = Theme.of(context).colorScheme;
    final items = _visible;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.libraryTracks)),
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
                  LibrarySort.album,
                  LibrarySort.added,
                ],
                sort: _sort,
                ascending: _asc,
                titleWording: true,
                onSort: (s, asc) => setState(() {
                  _sort = s;
                  _asc  = asc;
                  UserSettings.instance.setLibrarySort('track', s.pref, asc);
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
          // Clé sur l'ENTRÉE: avec une clé d'index, la ligne qui remonte après
          // un retrait hérite de l'état « déjà balayée » de celle qui part.
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
          child: _TrackTile(
            item: item, cs: cs,
            elsewhere: _onAnotherDevice(item),
            // Pas de lecture pour un fichier qui n'est pas là — la ligne le
            // DIT, plutôt que d'échouer au tap; le retrait reste possible.
            onPlay: _onAnotherDevice(item) ? null : () => _play(item),
            onRemove: () => _remove(item),
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
        maxCrossAxisExtent: small ? 100 : 140,
        mainAxisSpacing:    10,
        crossAxisSpacing:   10,
        // Pochette carrée + deux lignes, la proportion des rails de l'accueil.
        childAspectRatio:   0.70,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _TrackCard(
        item: items[i], cs: cs,
        elsewhere: _onAnotherDevice(items[i]),
        onPlay: _onAnotherDevice(items[i]) ? null : () => _play(items[i]),
        onRemove: () => _remove(items[i]),
      ),
    );
  }
}

/// Ce qui se lit SOUS le nom d'un morceau, en liste comme en grille — une
/// seule définition, sinon les deux dispositions racontent deux choses
/// différentes du même morceau.
///
/// Le titre de la piste vient en premier quand il diffère du nom affiché: ce
/// dernier est le nom du FICHIER au moment du geste, donc celui de l'album dès
/// qu'il s'agit d'un conteneur. L'album n'est répété que s'il n'est pas déjà
/// ce nom-là.
String trackSubtitle(LibraryItem item) => [
      if (item.trackTitle != null &&
          item.trackTitle!.isNotEmpty &&
          item.trackTitle != item.name)
        item.trackTitle!,
      if (item.artist != null && item.artist!.isNotEmpty) item.artist!,
      if (item.album != null &&
          item.album!.isNotEmpty &&
          item.album != item.name)
        item.album!,
    ].join(' · ');

class _TrackTile extends StatelessWidget {
  final LibraryItem   item;
  final ColorScheme   cs;
  final VoidCallback? onPlay;
  final VoidCallback  onRemove;
  /// Le fichier vit sur un autre appareil du compte: grisée, non jouable.
  final bool          elsewhere;

  const _TrackTile({
    required this.item,
    required this.cs,
    required this.onRemove,
    this.onPlay,
    this.elsewhere = false,
  });

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (elsewhere) libraryElsewhereLabel(context),
      trackSubtitle(item),
    ].where((t) => t.isNotEmpty).join(' · ');
    return ListTile(
      enabled: !elsewhere,
      // La MÊME vignette que la grille de cet écran (RailArtwork), donc le
      // placeholder thématisé par plateforme au lieu d'une pastille de texte.
      // Un `placeholder:` explicite ÉCRASE celui d'origine — c'est ce qui
      // faisait qu'un même morceau montrait « MOD » en liste et sa vraie
      // pochette de plateforme en grille, à un bouton d'écart. Même correctif
      // que song_tile.dart: retirer le placeholder et passer les deux indices
      // dont ArtworkImage a besoin pour choisir le bon.
      leading: LocalBadgedArtwork(
        show: item.isLocal,
        child: RailArtwork(
          url:          item.artworkUrl,
          artist:       item.artist,
          album:        item.album,
          formatHint:   item.formatExt ?? item.filename,
          platformName: item.platformName,
          size:         40,
        ),
      ),
      title: ScrollingText(text: item.name),
      subtitle: Text(
        sub,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
      trailing: item.isFavorite
          ? const Icon(Icons.star_rounded, size: 20, color: kFavoriteColor)
          : null,
      onTap: onPlay,
      onLongPress: () =>
          showLibraryItemMenu(context, title: item.name, onRemove: onRemove),
    );
  }
}

class _TrackCard extends StatelessWidget {
  final LibraryItem   item;
  final ColorScheme   cs;
  final VoidCallback? onPlay;
  final VoidCallback  onRemove;
  /// Voir _TrackTile.elsewhere.
  final bool          elsewhere;

  const _TrackCard({
    required this.item,
    required this.cs,
    required this.onPlay,
    required this.onRemove,
    this.elsewhere = false,
  });

  @override
  Widget build(BuildContext context) {
    // La MÊME seconde ligne qu'en liste: la grille montrait le titre OU
    // l'artiste, jamais l'album.
    final second = [
      if (elsewhere) libraryElsewhereLabel(context),
      trackSubtitle(item),
    ].where((t) => t.isNotEmpty).join(' · ');
    return HoverGrow(child: Opacity(
      opacity: elsewhere ? 0.45 : 1.0,
      child: GestureDetector(
      onTap: onPlay,
      onLongPress: () =>
          showLibraryItemMenu(context, title: item.name, onRemove: onRemove),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(children: [
              RailArtwork(
                url:          item.artworkUrl,
                artist:       item.artist,
                album:        item.album,
                formatHint:   item.formatExt ?? item.filename,
                platformName: item.platformName,
              ),
              if (item.isFavorite)
                const Positioned(
                  top: 2, right: 2,
                  child: Icon(Icons.star_rounded, size: 20,
                      color: kFavoriteColor,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 6)]),
                ),
              if (item.isLocal)
                const Positioned(bottom: 4, left: 4, child: LocalBadge()),
            ]),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall),
                if (second.isNotEmpty)
                  Text(second,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    )));
  }
}
