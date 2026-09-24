import 'dart:io';

import 'package:flutter/material.dart';

import 'favorite_color.dart';
import 'package:rewamp_audio/rewamp_audio.dart' show SubsongInfo, RewampAudio;
import 'l10n.dart';
import 'rewamp_db.dart';
import 'scrolling_text.dart';
import 'uade_info.dart';
import 'library_identity.dart';
import 'local_db.dart';
import 'min_subsong.dart';
import 'user_settings.dart';
import 'artwork_image.dart';
import 'artwork_viewer.dart';
import 'library_button.dart';
import 'player_controller.dart';
import 'local_open.dart' show rotateToDefaultSubsong;
import 'playlist_picker.dart';
import 'default_subsong.dart' show defaultSubsongFromHeader;
import 'sap_info.dart' show SapInfoService;
import 'app_snack.dart';
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
  /// La pochette RÉELLE résolue par la vignette, ou null tant qu'il n'y a
  /// qu'un placeholder. C'est elle qu'on agrandit — la re-résoudre depuis
  /// l'url finirait par diverger de ce que l'utilisateur a touché.
  final ValueNotifier<ImageProvider?> _fullArt = ValueNotifier(null);

  /// Seuil « sous-chansons trop courtes » tel que cet écran l'affiche.
  ///
  /// ⚠️ Il vit dans l'état, pas lu au vol dans `build`: changer le réglage
  /// pendant que cet écran est MONTÉ (il l'est — Réglages est poussé
  /// PAR-DESSUS) ne reconstruit rien tout seul, et le grisé restait celui
  /// d'avant jusqu'à ce qu'on ferme et rouvre l'écran. `UserSettings` est un
  /// ChangeNotifier: il suffit de l'écouter. Même règle que la coquille et
  /// l'accueil, qui l'écoutent déjà.
  int _minSubsongMs = 0;

  void _onSettingsChanged() {
    final v = minSubsongMs;
    // Seulement quand CE réglage bouge: le notifier est global, et tout
    // reconstruire à chaque poussée de réglage serait du gaspillage pur.
    if (v != _minSubsongMs && mounted) setState(() => _minSubsongMs = v);
  }

  @override
  void dispose() {
    UserSettings.instance.removeListener(_onSettingsChanged);
    _fullArt.dispose();
    super.dispose();
  }

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
    // ⚠️ PAS `displayTitle`: quand le serveur fournit déjà la tracklist (hvsc,
    // joshw), `_probe` sort AVANT de résoudre le chemin — `_resolvedPath` reste
    // nul et on retombe ici. Or la ligne d'un conteneur est celle de sa
    // sous-chanson 0, qui porte SON titre: l'écran s'appelait « Space Game »,
    // le nom STIL de la piste 1 de « One Man and his Droid ».
    return widget.result.containerName;
  }

  // Library/favorite key for the WHOLE song (no subsong suffix), so it's
  // distinct from any single-subsong library entry and relaunch can play all.
  // songId is non-nullable on SearchResult, so the old
  // `?? localPath ?? filename` chain was dead code — but callers still treat a
  // ref id as optional, so keep the nullable type.
  /// Réécriture consultée: un ajout passé par l'import a posé la ligne sous la
  /// clé pérenne (voir library_identity.dart).
  String? get _songRefId => widget.result.songId.isEmpty
      ? widget.result.songId
      : libraryRefRewrite(widget.result.songId);

  @override
  void initState() {
    super.initState();
    _minSubsongMs = minSubsongMs;
    UserSettings.instance.addListener(_onSettingsChanged);
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

  /// « Ce fichier est-il À NOUS, sur le disque ? » — ce qui décide de la
  /// présence de « Re-télécharger » et « Supprimer le téléchargement ».
  ///
  /// ⚠️ Appelée à l'ouverture ET APRÈS CHAQUE LECTURE. Un fichier pas encore
  /// téléchargé répond « non » à l'ouverture; le lire le fait DESCENDRE, et
  /// sans nouvelle résolution le menu restait sans ses deux entrées jusqu'à ce
  /// qu'on quitte l'écran et qu'on y revienne. L'état affiché doit suivre le
  /// disque, pas la première impression qu'on en a eue.
  Future<void> _resolveDeletable() async {
    String? fp = widget.result.localPath;
    fp ??= (await LocalDb.instance.getTrackByOnlineId(widget.result.songId))
          ?.filePath;
    final sep = Platform.pathSeparator;
    final ok = fp != null &&
        fp.contains('${sep}online$sep') &&
        await File(fp).exists();
    // Rendre la main SANS rien changer était l'autre moitié du défaut: la
    // réponse « non » ne s'écrivait jamais, donc un fichier supprimé ailleurs
    // laissait ses entrées de menu en place.
    final next = ok ? fp : null;
    if (mounted && next != _deletablePath) {
      setState(() => _deletablePath = next);
    }
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

  /// Re-télécharge le FICHIER de force, pochette comprise.
  ///
  /// Même geste que celui du lecteur, mais atteignable ici: c'est l'écran où
  /// l'on REGARDE un fichier, donc l'endroit où l'on constate qu'il est périmé —
  /// et le lecteur exige d'être en train de jouer ce fichier-là.
  ///
  /// N'est proposé que pour un fichier qu'on a DESCENDU (`_deletablePath`, sous
  /// `online/`): un fichier local à l'utilisateur n'a rien à re-télécharger.
  /// Le membre d'une archive d'album, lui, n'a pas d'URL à lui — et ça ne se
  /// sait qu'après avoir demandé son contexte au serveur, donc l'action le DIT
  /// plutôt que de disparaître d'un menu.
  Future<void> _redownload() async {
    final fp   = _deletablePath;
    final id   = catalogueSongId(widget.result.songId);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (fp == null || id == null) return;

    final s = (await RewampDb.getSongContext(id))?.song;
    if (s == null || s.downloadUrl == null || s.downloadUrl!.isEmpty) {
      AppSnack.showOn(messenger, l10n.playerRedownloadUnavailable);
      return;
    }

    // Le fichier peut être EN TRAIN de jouer: le lâcher avant de l'effacer,
    // sinon le décodeur tient un fichier qui n'existe plus.
    final ctrl = PlayerController.current;
    if (ctrl != null && ctrl.filePath == fp) ctrl.stop();

    // Table rase: fichier(s) — le nom dérivé peut avoir changé côté serveur —,
    // compagnons, pochette, lignes DB et url de provenance. Le ♥, la
    // bibliothèque et l'historique d'écoute survivent au geste.
    await RewampDb.purgeBeforeRedownload(s, currentPath: fp);

    try {
      await RewampDb.downloadToLibrary(s, force: true);
    } catch (_) {
      if (!mounted) return;
      AppSnack.showOn(messenger, l10n.playerRedownloadUnavailable);
      return;
    }
    if (!mounted) return;
    // La liste vient du fichier (sonde) ou du serveur: la refaire, et re-armer
    // l'action, dont le chemin vient d'être effacé puis recréé.
    setState(() => _deletablePath = null);
    await _resolveDeletable();
    if (mounted) await _probe();
  }

  Future<void> _toggleFavorite() async {
    var ref = _songRefId;
    if (ref == null) return;
    final r    = widget.result;
    final next = !_isFav;
    // Un ♥ EST une entrée de bibliothèque: il passe par la garde d'identité
    // (chemin jetable ⇒ import proposé, téléchargement sans songId ⇒ refus).
    // Un un-♥ n'est jamais gardé — voir library_identity.dart.
    if (next) {
      final ok = await ensureLibraryRefForAdd(context, ref);
      if (ok == null || !mounted) return;
      ref = ok;
    }
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
      } else if (UadeInfoService.isUadeFileAt(localPath)) {
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
        // ⚠️ `probeContainerFile` consulte le M3U quand il y en a un, et
        // **le M3U PRIME sur l'en-tête**. Ça vaut d'avance pour le chantier
        // NSF/GBS (leurs en-têtes portent aussi un octet « première piste »,
        // mais les rips joshw sont livrés avec leur M3U): un fichier dont la
        // liste vient d'un M3U ne doit PAS se voir imposer un départ par
        // l'en-tête — la liste du M3U est déjà celle que le ripper a voulue,
        // ordre compris, et les deux numérotations ne coïncident même pas
        // (le M3U retire les slots morts).
        subs = await RewampDb.probeContainerFile(localPath);
        // ASMA: le `.sap` porte un DEFSONG que le serveur rend 0-based dense,
        // par le même RPC md5 que le STIL. La liste d'un SAP est dense elle
        // aussi, l'index de ligne EST l'index de sous-chanson.
        // …mais l'en-tête est SOUS LA MAIN et le cache SAP local ne retient
        // que le STIL: on le lit d'abord, le serveur n'est qu'un repli.
        if (ext == 'sap') {
          _defaultRow = await defaultSubsongFromHeader(localPath);
          if (_defaultRow == null) {
            try {
              final info = await SapInfoService.instance.forPath(localPath);
              _defaultRow = info?.defaultSubsong;
            } catch (_) {}
          }
        }
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
  /// Sous-chant de départ DÉSIGNÉ par le fichier, en INDEX DE LISTE (pas en
  /// index de sous-chanson: les deux diffèrent dès qu'un slot muet est
  /// retiré). null = démarrer au premier, le cas de l'immense majorité.
  int? _defaultRow;

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
    // `default_subsong` est DÉJÀ 0-based dense (le serveur a converti le
    // 1-based du SID): pour un SID la liste est dense elle aussi, l'index de
    // ligne EST l'index de sous-chanson.
    // L'en-tête d'abord (gratuit, et vrai même hors catalogue), le serveur
    // ensuite — un SID dont l'en-tête ne dit rien peut être connu de HVSC.
    _defaultRow = await defaultSubsongFromHeader(localPath) ??
        info?.defaultSubsong;

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

  /// Le titre PROPRE à une sous-chanson, ou null si elle n'en a pas.
  ///
  /// ⚠️ **Un titre que TOUTES les sous-chansons partagent n'est pas un titre de
  /// sous-chanson: c'est celui du FICHIER.** Un SNDH n'a qu'un tag `TITL`, et
  /// la sonde le rend pour chacune de ses 20 entrées — non nul, donc le repli
  /// numéroté ne partait jamais: la liste affichait vingt fois « Amberstar »
  /// et « tout lire » mettait vingt « Amberstar » en file, là où le MÊME
  /// fichier lancé depuis un rail (AppShell._subsongEntries, qui ne lit pas la
  /// sonde) donnait « Amberstar (1) », « (2) »… Même règle que
  /// RewampDb.numberSubsongTitles: on ne numérote que si les titres sont
  /// IDENTIQUES — une vraie tracklist garde ses noms.
  String? _ownTitle(SubsongInfo sub) {
    final subs = _subsongs;
    if (!identical(subs, _sharedTitleFor)) {
      _sharedTitleFor = subs;
      final first = subs == null || subs.isEmpty ? null : subs.first.title;
      _titleIsShared = subs != null &&
          subs.length > 1 &&
          first != null &&
          first.isNotEmpty &&
          subs.every((s) => s.title == first);
    }
    final own = sub.title;
    if (_titleIsShared || own == null || own.isEmpty) return null;
    return own;
  }

  // Mémo du verdict, clefé sur l'IDENTITÉ de la liste: `_ownTitle` est appelé
  // par ligne depuis le builder, le recalculer là serait quadratique.
  List<SubsongInfo>? _sharedTitleFor;
  bool _titleIsShared = false;

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
      title:       _ownTitle(sub) ?? '$_containerName (${sub.index + 1})',
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
      await _resolveDeletable();
      return;
    }
    widget.onTap(context, _resultFor(sub));
    await _resolveDeletable();
  }

  Future<void> _playAll() async {
    final subs = _subsongs;
    if (subs == null || subs.isEmpty) return;
    // Le fichier désigne son premier morceau: on TOURNE la liste plutôt que
    // de couper devant — « tout lire » doit tout lire (voir
    // rotateToDefaultSubsong).
    final list =
        rotateToDefaultSubsong(subs.map(_resultFor).toList(), _defaultRow);
    final playAll = widget.onPlayAll ?? globalOnPlayAlbum;
    if (playAll != null) {
      await playAll(context, list);
    } else {
      widget.onTap(context, list.first);
    }
    await _resolveDeletable();
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
                          child: Builder(builder: (_) {
                            // Ce qu'un « tout lire » ÉCARTERA (Réglages →
                            // Lecture, durée minimale). Même fonction que la
                            // file, jamais une règle recopiée: les gardes
                            // « même fichier », « durée inconnue » et « tout
                            // filtré ⇒ on ne filtre rien » sont trois
                            // occasions de diverger. `fileKey` reprend celui
                            // de _resultFor, dont seul `filePath` varie.
                            final skipped = skippedQueueSubsongs<SubsongInfo>(
                              subs,
                              minMs: _minSubsongMs,
                              fileKey: (x) => x.filePath,
                              durationMs: (x) => x.durationMs,
                            );
                            return ListView.builder(
                            itemCount: subs.length,
                            itemBuilder: (_, i) {
                              final sub = subs[i];
                              // Grisée = ne sera pas mise en file par un
                              // « tout lire ». Elle reste JOUABLE au tap, et
                              // le sous-titre dit pourquoi + où le changer.
                              final isSkipped = skipped.contains(sub);
                              final title = _ownTitle(sub) ??
                                  l10n.subsongTrackNumber(sub.index + 1);
                              final dur = sub.durationMs != null
                                  ? RewampDb.formatDurationMs(sub.durationMs!)
                                  : null;
                              // Le fichier DÉSIGNE ce sous-chant comme son
                              // premier morceau: la pastille le dit, et
                              // « tout lire » démarre là (rotation).
                              final isDefault = _defaultRow == i;
                              return ListTile(
                                subtitle: isSkipped
                                    ? Text(
                                        l10n.subsongSkippedShort(
                                            (_minSubsongMs / 1000).round()),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: cs.onSurfaceVariant),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis)
                                    : null,
                                leading: CircleAvatar(
                                  // Grisée: la pastille perd sa teinte
                                  // d'accent. On ÉTEINT plutôt qu'on ne baisse
                                  // l'opacité de toute la ligne — le
                                  // sous-titre qui explique pourquoi doit
                                  // rester lisible.
                                  backgroundColor: isSkipped
                                      ? cs.surfaceContainerHighest
                                      : isDefault
                                          ? cs.primary
                                          : cs.primaryContainer,
                                  child: Text('${sub.index + 1}',
                                      style: TextStyle(
                                          color: isSkipped
                                              ? cs.onSurfaceVariant
                                              : isDefault
                                                  ? cs.onPrimary
                                                  : cs.onPrimaryContainer,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                ),
                                // ⚠️ Le style se pose par DefaultTextStyle et
                                // non par `ScrollingText(style:)`: celui-ci
                                // REMPLACE le style hérité (`widget.style ??
                                // DefaultTextStyle.of(ctx).style`), donc un
                                // `TextStyle(color:)` nu perdrait la taille et
                                // la graisse du titre de ListTile. Posé ICI,
                                // il MERGE par-dessus.
                                title: DefaultTextStyle.merge(
                                  style: isSkipped
                                      ? TextStyle(color: cs.onSurfaceVariant)
                                      : null,
                                  child: Row(
                                  children: [
                                    Flexible(
                                        child: ScrollingText(text: title)),
                                    if (isDefault) ...[
                                      const SizedBox(width: 6),
                                      Tooltip(
                                        message: l10n.subsongDefaultTrack,
                                        child: Icon(Icons.play_circle_outline,
                                            size: 15, color: cs.primary),
                                      ),
                                    ],
                                  ],
                                )),
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
                            );
                          }),
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
    // Durée du FICHIER: celle du serveur si elle existe, sinon la SOMME des
    // sous-chants affichés — c'est le cas d'un fichier local, ou d'une
    // collection sans `total_length_ms`. La somme n'est montrée que si CHAQUE
    // entrée a sa durée: partielle, elle mentirait. Les entrées mortes ne s'y
    // trouvent pas, elles ont déjà été retirées de la liste.
    final totalMs = r.totalLengthMs ??
        RewampDb.sumSubsongDurationsMs(
            [for (final s in _subsongs ?? const <SubsongInfo>[]) s.durationMs]);
    final meta = <String>[
      l10n.subsongCount(count),
      if (totalMs != null) RewampDb.formatDurationMs(totalMs),
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
              // Tap = pochette en plein écran, mais SEULEMENT quand il y en a
              // une vraie: `_fullArt` reste nul tant que la vignette n'a
              // résolu qu'un placeholder (voir artworkKeyIsRealCover).
              ValueListenableBuilder<ImageProvider?>(
                valueListenable: _fullArt,
                builder: (_, full, child) => GestureDetector(
                  onTap: full == null
                      ? null
                      : () => showFullscreenArtwork(context, full,
                          title: r.album ?? r.displayTitle),
                  child: child,
                ),
                child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ArtworkImage(
                  // ⚠️ PAS de `setState` ici. `onImageResolved` est notifié
                  // depuis le `build()` d'ArtworkImage, et
                  // `ImageStream.addListener` appelle son écouteur de façon
                  // SYNCHRONE quand l'image est déjà décodée (cache) — on
                  // reconstruisait donc PENDANT la construction, Flutter levait,
                  // la frame était abandonnée et la vignette restait sur son
                  // placeholder. Un notifieur ne reconstruit que le détecteur.
                  onImageResolved: (provider, key) => _fullArt.value =
                      artworkKeyIsRealCover(key) ? provider : null,
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
                  // Le nom du CONTENEUR, jamais `r.displayTitle`: la ligne
                  // d'un conteneur est souvent celle de sa sous-chanson 0,
                  // dont le titre est déjà numéroté — l'entrée s'appelait
                  // « Commando (1) », puis « Commando (1) (1) » au cycle
                  // suivant. Même règle que le titre de l'écran.
                  name:       _containerName,
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
                    case 'redownload':
                      _redownload();
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
                      value: 'redownload',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.refresh),
                        title: Text(l10n.playerRedownload),
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

}
