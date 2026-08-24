import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:path_provider/path_provider.dart';
import 'package:rewamp_audio/rewamp_audio.dart';
import 'local_db.dart';
import 'queue_persistence.dart';
import 'rewamp_db.dart';
import 'sync_service.dart';
import 'uade_info.dart';
import 'user_settings.dart';

class QueueEntry {
  final String  title;
  final String? artist;
  /// Context line for the queue list: the album, or — when this entry is one of
  /// several subsongs of a SINGLE file — that file's name (so you can tell which
  /// module a subsong belongs to). Null = nothing to show.
  final String? subtitle;

  /// Everything ArtworkImage needs to show this row's cover — including the
  /// themed per-platform placeholder when there is no artwork at all, which is
  /// why [platformName]/[formatHint] travel with the entry.
  final String? artworkUrl;
  final String? album;
  final String? localFilePath;
  final String? platformName;
  final String? formatHint;

  /// Stable identity of the queue ITEM this row mirrors, for widget keys.
  /// A position is not an identity: with index keys, removing row 2 left the
  /// row that shifted up wearing the same key — so Flutter handed it the
  /// DISMISSED state of the row that just left, red background and all. Null
  /// for the stand-in entries a caller synthesizes (a single-track play).
  final Object? id;

  const QueueEntry({
    required this.title,
    this.artist,
    this.subtitle,
    this.artworkUrl,
    this.album,
    this.localFilePath,
    this.platformName,
    this.formatHint,
    this.id,
  });
}


/// Total à AFFICHER pendant une lecture en boucle INFINIE: la durée nominale
/// arrondie au nombre de passes ENTAMÉES.
///
/// Sans ça le total reste figé à la durée nominale, et l'UI clampe la position
/// dessus (`player_screen.dart`: `displayPos.clamp(0, ctrl.duration)`), donc le
/// compteur gèle à « nominal / nominal » dès la première passe finie alors que
/// la musique continue. Le vocabulaire est celui du mode N passes (base ×
/// passes), le total montant d'une passe à chaque tour au lieu d'être fixé au
/// chargement.
///
/// Rend null si la durée nominale est inconnue: on n'a alors rien de mieux à
/// afficher que ce qu'on avait. Pendant la première passe le résultat vaut la
/// durée nominale, donc l'affichage ne bouge pas — pas de saut au démarrage.
double? infiniteDisplayTotal(double elapsedSeconds, double? nominalSeconds) {
  if (nominalSeconds == null || nominalSeconds <= 0) return null;
  final passes = (elapsedSeconds / nominalSeconds).ceil();
  return nominalSeconds * (passes < 1 ? 1 : passes);
}

/// Ce qu'il faut faire d'une piste qui BOUCLE quand le mode repeat vient d'être
/// coupé en cours de lecture. Pure et hors classe pour être testable (voir
/// [effectiveForceLoopModeFor] pour la même raison).
enum LoopCutAction {
  /// Durée nominale inconnue: on ne devine pas, la piste continue.
  none,

  /// Pas encore arrivé au bout d'une passe: jouer jusqu'à la durée nominale,
  /// donc jusqu'à la fin NATURELLE du morceau.
  playToNominalEnd,

  /// Passe supplémentaire en cours: terminer en fondu.
  fadeOut,

  /// Passe supplémentaire en cours, sans fondu demandé: terminer sec.
  stopNow,
}

LoopCutAction loopCutActionFor({
  required double elapsedSeconds,
  required double? nominalSeconds,
  required bool fadeoutEnabled,
  required double fadeoutSeconds,
}) {
  if (nominalSeconds == null || nominalSeconds <= 0) return LoopCutAction.none;
  if (elapsedSeconds < nominalSeconds) return LoopCutAction.playToNominalEnd;
  return (fadeoutEnabled && fadeoutSeconds > 0)
      ? LoopCutAction.fadeOut
      : LoopCutAction.stopNow;
}

/// Fond le bouton repeat du transport et le réglage global de boucle forcée en
/// UN mode, celui que voient les moteurs. Pure et hors classe pour être
/// testable: instancier un PlayerController appelle le natif.
///
/// Voir PlayerController.effectiveForceLoopMode pour le pourquoi de chaque cas.
String effectiveForceLoopModeFor(int transportLoopMode, String setting) =>
    switch (transportLoopMode) {
      2 => 'infinite',   // repeat-morceau = boucle infinie, pas un rechargement
      1 => 'off',        // repeat-file: la piste doit FINIR pour que la file avance
      _ => setting,
    };

/// Single source of truth for playback state.
/// Lives in AppShell; screens access it via constructor parameter.
class PlayerController extends ChangeNotifier {
  final RewampAudio audio;

  String?  filePath;
  String   entryPath  = '';
  int      subsongIdx = 0;
  String   fileName   = '';
  String   backend    = '';
  String?  artworkUrl;
  String?  artworkTargetDir;
  String?  currentArtist;
  /// True when [currentArtist] is the FILE's own embedded tag standing in for a
  /// catalogue track the catalogue had no artist for — the last resort, after
  /// `get_song_context` came back empty (or unreachable). Such a name is free
  /// text that addresses no artist entity, so the player renders it as plain
  /// text: it is worth showing, it is not worth a link that opens an empty
  /// screen. Always false for a file of the user's own, whose tag-derived
  /// credit the player already validates against the catalogue by name.
  bool     currentArtistIsFileTag = false;
  /// The credit as the catalogue gives it: one entry per artist, with the
  /// aligned uuids (`artist_names` / `artist_ids`, mig 129). [currentArtist]
  /// stays the flattened string every String-shaped consumer needs (the
  /// `tracks.artist` column, the media session); THIS is what the UI shows, so
  /// a two-artist credit is two links to two profiles instead of one link to a
  /// name nobody is called. Empty for a local file or a tag-derived credit —
  /// callers fall back to splitting [currentArtist] (splitArtistCredit).
  List<String> currentArtistNames = const [];
  List<String> currentArtistIds   = const [];
  String?  currentAlbum;
  /// Resolves the CURRENT queue into tracks-table ids (minting rows for
  /// never-played entries) — set by AppShell, which owns the real queue; the
  /// controller's own [queue] is presentation-only (QueueEntry has no track
  /// identity). Consumed by the "save queue as playlist" buttons on both
  /// queue screens. null/empty queue → the buttons hide.
  Future<List<String>> Function()? queueTrackIdsResolver;

  /// Server album_id of the playing track (null for local). Lets "see album"
  /// from the player target the exact album instead of resolving by name.
  String?  currentAlbumId;
  String?  currentOnlineId;
  /// Total subsongs of the current file (server/DB-sourced). <=1 (or null) means
  /// a single-song file — the only case the player offers a direct re-download.
  int?     currentSubsongCount;
  String?  currentFormatExt;
  String?  currentCollectionSlug;
  String?  currentPlatformName;
  /// Release year, when the row that started playback carried one (server
  /// results do, local files don't). Display-only — shown in the fullscreen
  /// track-info flash.
  int?     currentYear;
  /// Demozoo production videos of the current track (server song context,
  /// fetched async after load — empty until then / for local files). Drives
  /// the player's "watch the demo" button.
  List<SongVideo> videos = const [];
  /// Demozoo notes of the current track (same async fetch as [videos]).
  List<SongNote> notes = const [];
  /// Searchable tags of the current track, category → names (same fetch).
  Map<String, List<String>> songTags = const {};
  /// Demozoo productions the current track is used in (same fetch, migs
  /// 161-163) — entities with an id, NOT the old `production` tag strings.
  List<ProductionRef> songProductions = const [];
  /// Competition podium of the playing tune (compo_podium) — drives the cup in
  /// the player, which opens the compo.
  CompoPodium? songPodium;

  /// Podium of the row that is about to be played, handed over by the play path
  /// (`downloadAndPlay`) before the file even lands. Every catalogue listing
  /// carries `compo_podium`, so re-asking `get_song_context` for it just to
  /// show the cup meant the badge appeared a round trip AFTER the music — the
  /// symptom being a track that visibly "gains" its medal a second in.
  ///
  /// Keyed by song id and consumed exactly once: a primed value that does not
  /// match the track actually loading is dropped, so it can never decorate the
  /// wrong tune (a failed download, a skip mid-flight).
  static CompoPodium? _primedPodium;
  static String?      _primedPodiumId;

  /// Called by the play path with the row it is about to fetch.
  static void primePodium(String? songId, CompoPodium? podium) {
    _primedPodium   = podium;
    _primedPodiumId = _podiumKey(songId);
  }

  /// Container ids travel as `uuid#N` on one side and bare `uuid` on the other
  /// (the subsong lives in the audio path, not in the id) — the podium is a
  /// property of the catalogue FILE, so compare on the uuid alone.
  static String? _podiumKey(String? id) {
    if (id == null || id.isEmpty) return null;
    return id.split('#').first;
  }

  static CompoPodium? _takePrimedPodium(String? onlineId) {
    final podium = _primedPodium;
    final key    = _primedPodiumId;
    _primedPodium   = null;
    _primedPodiumId = null;
    if (podium == null || key == null) return null;
    return key == _podiumKey(onlineId) ? podium : null;
  }
  bool     isFavorite = false;
  bool     isPlaying  = false;
  double   position   = 0;
  double   duration   = 0;
  // Duration override from server metadata (HVSC songlength / SID STIL).
  // When set, overrides audio.durationSeconds (which is 0 for SID/GME files
  // that have no natural length reported by the decoder).
  double?  _knownDuration;

  // Currently playing track's DB id (null until first play or DB load)
  String? _currentTrackId;

  // log_play tracking: accumulates real play time, fires once per track.
  int  _elapsedPlayMs  = 0;
  bool _logPlayFired   = false;
  int  _lastTickMs     = 0;

  // Current play_events row (local listening stats): its played_ms is
  // backfilled with the real elapsed time when the play ends (track switch,
  // natural end, stop).
  int? _playEventId;

  // Même ligne, gardée pour un autre usage: la marquer `pushed` une fois
  // l'écoute livrée au compte (log_play / log_plays_ext), ce qui empêche
  // l'écran Stats de la compter deux fois — en local ET dans le miroir de la
  // timeline du compte. Champ distinct parce que [_playEventId] est remis à
  // null par le flush de durée, qui peut passer AVANT l'envoi (l'écoute part
  // souvent à la fin du morceau).
  int? _pushablePlayEventId;

  /// Writes the elapsed play time onto the current play event, once.
  void _flushPlayEventDuration() {
    final id = _playEventId;
    if (id == null) return;
    _playEventId = null;
    if (_elapsedPlayMs > 0) {
      LocalDb.instance.setPlayEventDuration(id, _elapsedPlayMs); // fire & forget
    }
    // Rien n'est parti au compte pour cette écoute: elle n'a pas atteint le
    // seuil de log_play (30 s ou la moitié du morceau) — un morceau sauté.
    // L'historique de cet appareil la garde, la vue fusionnée de l'écran Stats
    // doit l'ignorer: le compte ne la connaîtra jamais, donc la compter ferait
    // diverger deux appareils pourtant synchronisés. Ce n'est PAS le cas d'un
    // envoi raté, qui reste à 0 et compte.
    if (!_logPlayFired) {
      LocalDb.instance.markPlayEventOffAccount(id); // fire & forget
    }
  }

  // Forced loop/fadeout (Settings → Lecture). Some backends (libopenmpt) can
  // handle the loop natively — see loadFile()/_nativeLoopHandled; everything
  // else (and the fadeout-enabled case even for a native-capable backend)
  // falls back to this generic engine-level seek+volume implementation,
  // which works uniformly for any plugin. Le mode en vigueur vient de
  // effectiveForceLoopMode, qui fond le réglage et le bouton transport: un
  // choix de transport explicite prime sur le défaut global.
  bool   _fadingOut         = false;
  int    _fadeStartMs       = 0;
  bool   _nativeLoopHandled = false;
  // Single-pass base length (s) while a generic forced loop is active — the
  // displayed timeline is base×passes but the decoder only spans one pass, so
  // seeks map target→(target % base). Null when unknown / not force-looping.
  double? _forceBaseSecs;
  // Instant d'arrêt armé quand le mode repeat est coupé PENDANT la lecture
  // (voir _endLoopedPlayback). Comparé au temps de lecture ÉCOULÉ, jamais à la
  // position du décodeur: sous boucle native celle-ci repart en arrière à
  // chaque passe et ne dit rien de la durée déjà écoutée.
  double? _loopStopAtSecs;
  // Elapsed-timeline offset of the current pass (target − target%base) while a
  // forced-loop seek is fast-forwarding, so the C within-pass seek progress can
  // be shown on the base×passes slider: displayed = offset + decoderProgress.
  double  _forceSeekOffset = 0;
  /// Mode de boucle forcée RÉELLEMENT en vigueur, réglage et bouton transport
  /// fondus en une seule valeur — c'est elle que voient les moteurs.
  ///
  ///  - repeat-morceau (loopMode 2) EST une boucle infinie: sans ça, un format
  ///    qui a un point de boucle (VGM, vgmstream, module à position de restart)
  ///    repartait de l'INTRO à chaque passe au lieu de boucler sa région de
  ///    boucle, et avec le trou d'un rechargement complet entre les deux.
  ///  - repeat-file (loopMode 1) force 'off': la piste doit FINIR pour que la
  ///    file puisse avancer puis reboucler sur son premier élément.
  ///  - sinon le réglage global (Réglages → Lecture) s'applique tel quel.
  ///
  /// ⚠️ Les moteurs lisent ce mode à l'OUVERTURE du fichier (setForcedLoop
  /// avant load), donc armer repeat en cours de morceau ne devient natif qu'à
  /// la passe suivante — le rechargement déclenché par onTrackEnded reprend le
  /// nouvel instantané. Le chemin générique, lui, est relu à chaque tick.
  String get effectiveForceLoopMode =>
      effectiveForceLoopModeFor(loopMode, UserSettings.instance.forceLoopMode);

  bool get _forceLoopActive =>
      effectiveForceLoopMode != 'off' && !_nativeLoopHandled;

  final List<RecentEntry> recentEntries = [];

  bool get hasFile => filePath != null;

  /// library_items.ref_id for the CURRENT subsong — the single key used by both
  /// the library button and the favourite toggle (a favourite is a library item
  /// with is_favorite=1). ALWAYS subsong-scoped so the two writers agree.
  String? get libraryRefId {
    final base = currentOnlineId ?? filePath;
    return base == null ? null : '$base?subsong=$subsongIdx';
  }

  /// Track title to show; falls back to "Subsong N" (1-based) when the
  /// subsong has no name of its own (common for SID/NSF subtunes).
  String get displayTitle =>
      fileName.isNotEmpty ? fileName : 'Subsong ${subsongIdx + 1}';

  /// "4/25" position within the current queue, or null when there is no
  /// multi-track queue.
  String? get queuePositionLabel {
    final n = _queue.length;
    if (n <= 1 || _queueIdx < 0) return null;
    return '${_queueIdx + 1}/$n';
  }

  PlayerController(this.audio) {
    current = this;
    // Le ♥ peut changer sans passer par le lecteur (retrait depuis une liste,
    // geste redescendu d'un autre appareil): la base prévient, on relit.
    LocalDb.instance.addListener(_onDbChanged);
  }

  void _onDbChanged() {
    if (filePath == null) return;
    unawaited(refreshFavourite());
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_onDbChanged);
    super.dispose();
  }

  /// The app's single live controller — lets delete flows (album options,
  /// container screen) stop playback + close the player without plumbing the
  /// controller through every sheet.
  static PlayerController? current;

  /// Set by PlayerScreen while it is shown; closes the player sheet.
  VoidCallback? playerUiCloser;

  /// True when the playing file is [pathPrefix] itself or lives under it
  /// (album directory).
  bool isPlayingUnder(String pathPrefix) {
    final fp = filePath;
    if (fp == null) return false;
    final sep = Platform.pathSeparator;
    return fp == pathPrefix ||
        fp.startsWith(pathPrefix.endsWith(sep) ? pathPrefix : '$pathPrefix$sep');
  }

  /// A whole album directory was deleted: same contract as
  /// [handleDeletedTrack], but every queue entry playing from ANY file under
  /// [dirPath] goes (an album's other tracks lingered in the queue and, tapped,
  /// hit a file that no longer exists).
  Future<bool> handleDeletedAlbum(String dirPath) async {
    final wasPlaying = isPlayingUnder(dirPath);
    if (wasPlaying) stop();
    final tookOver = await notifyTrackDeleted(dirPath, asPrefix: true);
    if (wasPlaying && !tookOver) _tearDownPlayerUi();
    return tookOver;
  }

  /// The file is gone — clear the "current track" so the mini player hides and
  /// navigation flows don't reopen the full player on a deleted file.
  /// The queue owner removed the PLAYING entry and has nothing to put in its
  /// place (a manual queue edit that took out the last track). Same teardown as
  /// a deleted file: stop, then fold the player away.
  void stopAndTearDown() {
    stop();
    _tearDownPlayerUi();
  }

  void _tearDownPlayerUi() {
    filePath = null;
    notifyListeners();
    playerUiCloser?.call();
  }

  /// A single downloaded FILE was deleted. Stops playback when it is the file
  /// playing, drops every queue entry that plays from it (all the subsongs of a
  /// .sid/.nsf, all the members of an .rsn) and lets the queue owner start the
  /// next entry; with nothing left to play the player is torn down (mini player
  /// hides, full player closes). Returns true when another track took over.
  ///
  /// MUST be awaited BEFORE the file and its DB rows are deleted — resolving
  /// which queue entries share the file reads those rows.
  Future<bool> handleDeletedTrack(String path) async {
    final wasPlaying = isPlayingUnder(path);
    // Stop BEFORE the file disappears from under the decoder.
    if (wasPlaying) stop();
    final tookOver = await notifyTrackDeleted(path);
    if (wasPlaying && !tookOver) _tearDownPlayerUi();
    return tookOver;
  }

  bool _recentListenerAttached = false;

  /// Call once after LocalDb.initialize() — restores recently played list.
  Future<void> loadHistory() async {
    // Keep "recently played" in sync with library/favourite edits: favouriting
    // an album writes library_items but not recent_albums, so the star overlay
    // (which comes from a JOIN in getRecentEntries) only updates on a reload.
    if (!_recentListenerAttached) {
      _recentListenerAttached = true;
      LocalDb.instance.addListener(() => _refreshRecent());
    }
    try {
      final entries = await LocalDb.instance.getRecentEntries(limit: 32);
      recentEntries
        ..clear()
        ..addAll(entries);
      notifyListeners();
    } catch (e) {
      debugPrint('loadHistory error: $e');
    }
  }

  /// Loads [path] and starts playback immediately. DB persistence happens
  /// in the background so that a DB error never blocks audio.
  Future<bool> loadFile(
    String path,
    String label, {
    String  entryPath        = '',
    int     subsongIdx       = 0,
    String? artist,
    /// The credit unflattened, when the caller has it (a catalogue row does;
    /// a DB row or a file's tag does not). Aligned with [artistIds].
    List<String>? artistNames,
    List<String>? artistIds,
    String? metaAlbum,
    String? metaAlbumId,
    double? durationS,
    String? formatExt,
    // Total subsongs of the container (server-sourced) — persisted so an
    // offline recents replay rebuilds the right queue (native probe returns a
    // format default for count-less headers, e.g. HES/KSS → 256).
    int?    subsongCount,
    String  source           = 'local',
    String? onlineId,
    String? artworkUrl,
    String? artworkTargetDir,
    bool    recordAsAlbum    = false,
  }) async {
    // The previous track's play ends here — backfill its real listened time
    // BEFORE _elapsedPlayMs is reset below.
    _flushPlayEventDuration();
    audio.stop();
    // Forced-loop (Settings → Lecture): snapshotted for the plugin about to
    // open, in case it has native support (see hasNativeLoopSupport below).
    // The fadeout is passed through too — when the plugin supports native
    // looping AND its single-pass length is known, the C engine computes the
    // exact frame the final pass enters the fadeout window and ramps gain
    // sample-accurately in ds_read() (generic — no per-plugin fade code).
    // Length-unknown is the one case that silently gets no fadeout at all
    // (native loop still works; there's no reliable way to predict "N
    // seconds before an end we can't compute" from either side).
    final loopSettingOn = effectiveForceLoopMode != 'off';
    final loopModeCode = switch (effectiveForceLoopMode) {
      'infinite' => 2,
      'on'       => 1,
      _          => 0,
    };
    // Single-pass base length used for the forced-loop math. Prefer the known
    // catalogue length (durationS); when a subsong has none (e.g. NSF tracks
    // the server didn't measure), fall back to the user's default track length
    // rather than letting a native plugin invent its own — libnsfplay's is a
    // 5-minute default, which is exactly what pinned those unmeasured subsongs
    // at 5:00. This keeps every forced-loop track at base×passes, never 5:00.
    final baseSecs = (durationS != null && durationS > 0)
        ? durationS
        : UserSettings.instance.defaultTrackLengthSeconds;
    audio.setForcedLoop(
      loopModeCode,
      UserSettings.instance.loopCount,
      fadeoutEnabled: UserSettings.instance.forceFadeoutEnabled,
      fadeoutSeconds: UserSettings.instance.fadeoutSeconds,
      baseDurationSeconds: baseSecs,
    );
    // Remember this attempt's identity before decoding, so a failure can name
    // and report the exact file (these outlive a failed decode; filePath does
    // not update on failure).
    lastLoadPath       = path;
    lastLoadLabel      = label;
    lastLoadFormatExt  = formatExt;
    lastLoadSubsongIdx = subsongIdx;
    lastLoadOnlineId   = onlineId;
    // Encode subsong as a query suffix parsed by the native GME plugin.
    final audioPath = subsongIdx > 0 ? '$path?subsong=$subsongIdx' : path;
    // Crash guard ("safe launch"): flag on disk while the native decoder
    // opens the file. Cleared right after — success or clean failure, either
    // way the app survived. If it's still there at the next launch, this load
    // killed the app and the saved queue is not restored.
    QueuePersistence.markLoading(audioPath);
    final loaded = audio.loadFile(audioPath);
    QueuePersistence.clearLoading();
    lastLoadMissingOnDisk = false;
    // True when a native plugin is handling the loop this time — Dart's own
    // generic seek+volume machinery (_forceLoopActive) stays out of the way
    // entirely for this file, loop AND fadeout both.
    _nativeLoopHandled = loaded && loopSettingOn && audio.hasNativeLoopSupport;
    if (!loaded) {
      // Richer diagnostics: whether the file is actually on disk, its size, and
      // which native backend (if any) the registry ended up selecting. An empty
      // backend means no plugin claimed it (fell through to miniaudio and that
      // failed too) — points at a stale build / unregistered plugin rather than
      // a decode error.
      String extra = '';
      try {
        final f = File(path);
        lastLoadMissingOnDisk = !f.existsSync();
        extra = lastLoadMissingOnDisk
            ? 'MISSING ON DISK'
            : 'exists, ${f.lengthSync()} bytes';
      } catch (e) {
        extra = 'stat error $e';
      }
      debugPrint('[PlayerCtrl] loadFile FAILED for "$audioPath" '
          '($extra, backend="${audio.backendName}")');
    }

    if (loaded) {
      primed              = false; // a real decode supersedes any primed display
      queueExhausted      = false; // ...and a fresh track means the queue is live again
      filePath            = path;
      this.entryPath      = entryPath;
      this.subsongIdx     = subsongIdx;
      fileName            = label;
      backend             = audio.backendName;
      this.artworkUrl          = artworkUrl;
      this.artworkTargetDir    = artworkTargetDir;
      currentArtist            = artist;
      currentArtistNames       = artistNames == null
          ? const []
          : artistNames.where((a) => a.trim().isNotEmpty).toList();
      currentArtistIds         = artistIds ?? const [];
      currentAlbum             = metaAlbum;
      currentArtistIsFileTag   = false;
      // A FILE OF THE USER'S OWN falls back to its embedded tags (ID3/Vorbis/
      // RIFF) straight away — there is no other source for it, and the player
      // already refuses to make such a name tappable unless the catalogue
      // knows it (see _checkServerArtists).
      //
      // A CATALOGUE track does NOT, not here. An embedded tag is free text
      // written by whoever encoded the file: "Memento Mori" carries
      // `ARTIST=aMUSiC and Leviathan` where the catalogue holds the two real
      // artists ["Amusic","Leviathan"], each with an id. Letting the tag stand
      // in produced an artist line that named nobody the server knows —
      // tapping it opened an empty artist screen — and it silently disagreed
      // with every other surface (search row, album, artist chips), which all
      // read the catalogue.
      //
      // So the catalogue is asked first (_backfillIdentity below). Only if it
      // answers with no artist at all does the tag get its turn, flagged
      // [currentArtistIsFileTag] so the line renders as plain text: it is
      // information, not a link, because there is nothing behind it to open.
      final fromCatalogue = onlineId != null && onlineId.isNotEmpty;
      if (!fromCatalogue) {
        if (currentArtist == null || currentArtist!.isEmpty) {
          final t = audio.tagArtist;
          if (t.isNotEmpty) currentArtist = t;
        }
      }
      // The album line is milder — it only becomes a link when metaAlbumId is
      // set — but the same rule applies where it matters: a tag must never
      // supply the TEXT of a link pointing at a catalogue album it does not
      // name. With no album id there is nothing to contradict, so the tag fills
      // an empty line as it always did.
      if ((currentAlbum == null || currentAlbum!.isEmpty) &&
          (metaAlbumId == null || metaAlbumId.isEmpty)) {
        final t = audio.tagAlbum;
        if (t.isNotEmpty) currentAlbum = t;
      }
      currentAlbumId           = metaAlbumId;
      currentOnlineId          = onlineId;
      currentSubsongCount      = subsongCount;
      currentFormatExt         = formatExt;
      currentCollectionSlug    = null;
      currentPlatformName      = null;
      currentYear              = null;
      videos                   = const [];
      notes                    = const [];
      // The row that started this play already CARRIED its podium
      // (`compo_podium` is a column of every listing: search, album tracks,
      // playlist tracks), so the cup can be up on the very first frame instead
      // of waiting for the get_song_context round trip below. Keyed on the
      // song id, so a primed value can never leak onto the next track.
      songPodium               = _takePrimedPodium(onlineId);
      songTags                 = const {};
      songProductions          = const [];
      _fetchVideos(onlineId);  // async; notifies when they land
      isFavorite               = false; // reset; updated async after DB upsert
      isPlaying         = true;
      isSeeking         = false;
      position          = 0;
      _elapsedPlayMs    = 0;
      _loopStopAtSecs   = null;
      _lastLoopRestartMs = 0;
      _logPlayFired     = false;
      _lastTickMs       = DateTime.now().millisecondsSinceEpoch;
      // Forced-loop (Settings → Lecture) state is per-track.
      if (_fadingOut) { _fadingOut = false; audio.setVolume(1.0); }
      // Displayed duration under a native forced loop. We must NOT trust the
      // plugin's own GetLength() here: some engines (libnsfplay for a plain
      // NSF with no embedded length) report a bogus 5-minute default, which is
      // what made the duration jump to 5:00 the moment force-loop was enabled.
      // Instead, when we know the single-pass base length (durationS, from the
      // subsong metadata / server / cache), compute the looped total in Dart
      // as base × passes — correct for ANY plugin, independent of what its
      // native length getter returns. Infinite mode or unknown base → fall
      // back to the native value (nothing better to show).
      // Single-pass base length: catalogue (durationS) if known, else the
      // plugin's own reported length (NSFe embedded, plumbed default, …); 0 for
      // SID/GME which report nothing here (an async songlength fills it later).
      final baseSingle = (durationS != null && durationS > 0)
          ? durationS
          : (audio.durationSeconds > 0 ? audio.durationSeconds : null);
      final passes = UserSettings.instance.loopCount + 1;
      _forceBaseSecs = baseSingle;
      if (_nativeLoopHandled) {
        // Native plugin reports its own looped length. Only override the
        // DISPLAY with base×passes when we have a clean catalogue base; for
        // infinite / embedded-only / plain-default, trust the native value.
        _knownDuration = (loopModeCode == 1 && durationS != null && durationS > 0)
            ? durationS * passes
            : null;
      } else if (_forceLoopActive && loopModeCode == 1 && baseSingle != null) {
        // Generic forced loop ('on'): the whole run is base×passes, played on
        // the elapsed-time timeline (_tickForceLoop) with restart-on-silence.
        _knownDuration = baseSingle * passes;
      } else {
        // No forced loop, or infinite, or unknown base → single-pass length.
        _knownDuration = baseSingle;
      }
      // No known length from any source (server metadata, native decoder)?
      // Apply the user-configured default so the track doesn't play/loop
      // forever with no end. Never for UADE — it gets its own async songdb
      // lookup below (_applyUadeDuration), which is the authoritative source
      // for Amiga tracks and shouldn't be pre-empted by a generic fallback.
      if (_knownDuration == null && audio.durationSeconds <= 0 &&
          backend != 'uade') {
        _knownDuration = UserSettings.instance.defaultTrackLengthSeconds;
      }
      duration          = _knownDuration ?? audio.durationSeconds;
      audio.play();
      notifyListeners();
      _notifyTrackChange();

      // Embedded cover (ID3/FLAC/Ogg picture) when nothing better is known:
      // dump it to the cache and use the file path as the artwork source.
      if (artworkUrl == null || artworkUrl.isEmpty) {
        _applyEmbeddedArtwork(path).catchError(
            (Object e) => debugPrint('embedded artwork: $e'));
      }

      // UADE songdb duration (audacious-uade): md5 → cache/server → apply the
      // per-subsong length.
      //
      // NOT gated on "the caller gave us no duration": for a multi-subsong
      // module the caller's value is the CONTAINER's — the catalogue holds one
      // length per FILE (subsong 0's) and every expanded row inherits it — so
      // skipping the lookup left all 22 tunes of a TFMX claiming the length of
      // the first. The songdb is per-subsong and is the authoritative source
      // for Amiga tracks; the lookup is cached by md5 (memory + local DB) and
      // runs off the play path.
      if (backend == 'uade') {
        _applyUadeDuration(path, subsongIdx);
      }

      // DB persistence in background — never blocks or breaks playback.
      _persistPlay(
        path:          path,
        entryPath:     entryPath,
        subsongIdx:    subsongIdx,
        label:         label,
        artist:        artist,
        metaAlbum:     metaAlbum,
        // Persist the SINGLE-PASS length only, never the forced-loop total.
        // When a native plugin is handling the loop, audio.durationSeconds is
        // the looped total (base×loops+fade) — caching that as the track's
        // canonical duration poisons it (and re-feeds itself as the base next
        // play). Prefer the known base (durationS); else the natural native
        // length, but only when NOT force-looping.
        durationS:     durationS ??
            ((audio.durationSeconds > 0 && !_nativeLoopHandled)
                ? audio.durationSeconds : null),
        formatExt:     formatExt,
        subsongCount:  subsongCount,
        source:        source,
        onlineId:      onlineId,
        artworkUrl:    artworkUrl,
        recordAsAlbum: recordAsAlbum,
      ).catchError((Object e, StackTrace st) {
        debugPrint('LocalDb _persistPlay ERROR: $e');
        debugPrint(st.toString());
      });
    } else {
      notifyListeners();
    }
    onLoadResult?.call(loaded);
    return loaded;
  }

  /// Optional system notification on track change (Réglages). macOS only:
  /// Android/iOS already show the track in their media notification, and the
  /// desktop channel lives in the mac AppDelegate. Fire-and-forget — a failed
  /// post must never touch playback.
  static const _notifyChannel = MethodChannel('rewamp/notify');
  void _notifyTrackChange() {
    if (!Platform.isMacOS) return;
    if (!UserSettings.instance.notifyTrackChange) return;
    _notifyChannel.invokeMethod('track', {
      'title':  displayTitle,
      'artist': currentArtist ?? '',
    }).catchError((_) => null);
  }

  /// Looks up the UADE songdb duration for [audioPath]'s [subsongIdx] and
  /// applies it as the known duration (audacious-uade metadata). No-op when
  /// unknown or when the track changed while the lookup was in flight.
  Future<void> _applyUadeDuration(String audioPath, int subsongIdx) async {
    try {
      final info = await UadeInfoService.instance.forPath(audioPath);
      if (info == null) return;
      final ms = info.durationMsFor(subsongIdx);
      if (ms == null || ms <= 0) return;
      if (filePath != audioPath || this.subsongIdx != subsongIdx) return;
      _forceBaseSecs = ms / 1000.0;
      _knownDuration = _displayedDurationFor(ms / 1000.0);
      duration = _knownDuration!;
      notifyListeners();
    } catch (e) {
      debugPrint('uade duration: $e');
    }
  }

  /// Writes the embedded cover picture (if the native tag reader found one)
  /// to the cache and points [artworkUrl] at it. No-op when the file has no
  /// picture. Keyed by audio file path so repeated plays reuse the file.
  Future<void> _applyEmbeddedArtwork(String audioPath) async {
    final bytes = audio.trackArtwork;
    if (bytes == null || bytes.isEmpty) return;
    final mime = audio.trackArtworkMime;
    final ext = mime.contains('png') ? 'png' : 'jpg';
    final cacheDir = await getApplicationCacheDirectory();
    final name = audioPath.hashCode.toRadixString(16);
    final f = File('${cacheDir.path}/artwork/embedded_$name.$ext');
    if (!await f.exists()) {
      await f.parent.create(recursive: true);
      await f.writeAsBytes(bytes);
    }
    // Only apply if the track hasn't changed while we were writing.
    if (filePath == audioPath && (artworkUrl == null || artworkUrl!.isEmpty)) {
      artworkUrl = f.path;
      notifyListeners();
    }
  }

  Future<void> _persistPlay({
    required String  path,
    required String  entryPath,
    required int     subsongIdx,
    required String  label,
    String?  artist,
    String?  metaAlbum,
    double?  durationS,
    String?  formatExt,
    int?     subsongCount,
    required String  source,
    String?  onlineId,
    String?  artworkUrl,
    bool     recordAsAlbum = false,
  }) async {
    // `subsong_count` décrit le FICHIER, et l'appelant ne le sait pas toujours:
    // pour un `.sid` de HVSC le catalogue envoie `track_count = 1` (une ligne
    // = un fichier), alors que le fichier porte 21 sous-chansons. Le MOTEUR,
    // lui, le sait. On ne consulte la sonde que si la valeur connue ne dit
    // rien d'utile (null ou 1), et on ne descend JAMAIS: elle rend 0 pour les
    // moteurs qu'elle ne chaîne pas (Furnace, UADE, zxtune, AdPlug, la famille
    // PSF, SunVox), et un 0 écrit serait un mensonge de plus.
    var count = subsongCount;
    if ((count ?? 0) <= 1) {
      try {
        final probed = audio.probeSubsongCount(path);
        if (probed > 1) count = probed;
      } catch (_) {}
    }
    _currentTrackId = await LocalDb.instance.upsertTrack(
      filePath:     path,
      entryPath:    entryPath,
      subsongIdx:   subsongIdx,
      title:        label,
      artist:       artist,
      metaAlbum:    metaAlbum,
      durationS:    durationS,
      formatExt:    formatExt,
      subsongCount: count,
      source:       source,
      onlineId:     onlineId,
      // Origine catalogue, écrite au moment où on la CONNAÎT (mig 52). Sans
      // ça, une relance devait la re-déduire du chemin ou d'une ligne voisine,
      // et une piste rejouée depuis les récents s'affichait « local ».
      collectionSlug: currentCollectionSlug,
      platformName:   currentPlatformName,
      year:           currentYear,
      // L'album est une propriété de la QUEUE, pas du morceau: `currentAlbumId`
      // survit à la fin d'une lecture d'album, et le stamper sur les morceaux
      // joués ensuite rattachait des inconnus à cet album — quatre pistes de
      // modland et de sceneorg se sont retrouvées dans les favoris « Final
      // Fantasy V ». Un morceau qui appartient vraiment à un album porte AUSSI
      // son nom; sans nom d'album, pas d'identité d'album.
      albumId:      (metaAlbum != null && metaAlbum.isNotEmpty)
          ? currentAlbumId
          : null,
      artworkUrl:   artworkUrl,
    );
    // A play just SUCCEEDED for this catalogue identity, which is the exact
    // moment the mig-53 criterion is free: this row's file is present, so any
    // sibling row (same online_id + subsong, other path) whose file is absent
    // is a stale duplicate - the same tune filed under another artist credit or
    // another album's uuid. Left alone it becomes a second, unplayable card in
    // the recents rail (the query partitions by file_path). Continuous, because
    // a one-shot sweep (mig 53) could not stay done: every flow disagreement on
    // the artist credit of an album-less track re-creates one.
    if (onlineId != null && onlineId.isNotEmpty) {
      unawaited(LocalDb.instance
          .pruneMissingDuplicates(onlineId, subsongIdx, keepPath: path)
          .catchError((Object e) {
        debugPrint('pruneMissingDuplicates ERROR: $e');
      }));
    }
    // EVERY play records a play event: play_events is the listening-stats
    // source (Stats tab, "Vos tendances"), and album/queue plays — an NSF's
    // subsongs, an album's tracks — are listening too. They used to record
    // only the recent-album row, so the bulk of real listening was invisible
    // to the stats. The recents DISPLAY difference is preserved below: the
    // recents query hides a track whose album has its own recent_albums row,
    // which the album path always writes.
    // L'ORIGINE, dès que la ligne existe.
    //
    // `setAlbumContext` l'écrit par `setTrackOrigin(_currentTrackId, …)`, mais
    // `_persistPlay` tourne en ARRIÈRE-PLAN: quand le contexte arrive — juste
    // après le démarrage de la lecture — l'id n'est pas encore produit, la
    // garde `trackId != null` saute l'écriture, et l'origine n'atterrissait
    // qu'au battement suivant (fin de morceau, changement de piste). D'où
    // « collection_slug reste NULL pendant toute la lecture ».
    //
    // Ici l'id vient d'être obtenu et les champs `current*` ont été posés
    // SYNCHRONEMENT par setAlbumContext, donc il n'y a plus de course. Gardé
    // sur le FICHIER: si la lecture a déjà changé, cette origine n'est plus la
    // bonne. Idempotent avec l'autre écriture (COALESCE des deux côtés).
    if (path == filePath &&
        ((currentCollectionSlug ?? '').isNotEmpty ||
            (currentPlatformName ?? '').isNotEmpty ||
            currentYear != null)) {
      unawaited(LocalDb.instance.setTrackOrigin(_currentTrackId!,
          currentCollectionSlug, currentPlatformName, currentYear));
    }

    _playEventId =
        await LocalDb.instance.recordPlay(_currentTrackId!, backend: backend);
    _pushablePlayEventId = _playEventId;
    if (recordAsAlbum && metaAlbum != null && metaAlbum.isNotEmpty) {
      // Album play: the album carries the recents entry, not the track.
      await LocalDb.instance.upsertRecentAlbum(
        metaAlbum,
        path,
        artist:     artist,
        artworkUrl: artworkUrl,
        albumId:    currentAlbumId,
        // Identity of the FILE this entry points at, so replaying the album
        // from the recents rail knows what it is playing (a subsong list
        // rebuilt from disk carries none of its own).
        onlineId:   currentOnlineId,
      );
    } else {
      // Recents lists ALBUMS or standalone FILES only: a track of a real
      // (server-id) album played individually refreshes the ALBUM entry —
      // the query hides its per-track row. Pseudo-albums (SID container
      // names, albumId null) stay file entries.
      if (metaAlbum != null &&
          metaAlbum.isNotEmpty &&
          currentAlbumId != null &&
          currentAlbumId!.isNotEmpty) {
        await LocalDb.instance.upsertRecentAlbum(
          metaAlbum,
          path,
          artist:     artist,
          artworkUrl: artworkUrl,
          albumId:    currentAlbumId,
          onlineId:   currentOnlineId,
        );
      }
    }
    await _refreshRecent();
    // Load favorite state for the UI heart button. La SOURCE est
    // `library_items` (migration serveur 206): `tracks.is_favorite` n'est posée
    // que par un geste fait ICI, donc un ♥ venu du compte laissait le cœur du
    // lecteur éteint sur un morceau pourtant aimé. La colonne ne sert plus que
    // de repli, pour une piste sans entrée de bibliothèque.
    await refreshFavourite();
    _backfillIdentity(path, metaAlbum: metaAlbum, artist: artist);
  }

  /// Song ids already looked up this session — the guard that keeps a queue of
  /// twenty tracks from the same album to ONE request.
  final Set<String> _identityAsked = <String>{};

  /// Asks the catalogue for what this play could not know: the album id, the
  /// cover, and the artist credit. Fire-and-forget, once per song id, and only
  /// when something is actually missing.
  ///
  /// A track whose first local row was born of a PLAYLIST entry has neither —
  /// the playlist snapshot carries no album id (see
  /// [LocalDb.backfillTrackIdentity]) — so the player showed an inert album
  /// label and the recents rail an empty cover, for a tune sitting in the
  /// catalogue with both. The fix is self-healing: the row keeps what comes
  /// back, so this runs at most once per tune, ever.
  ///
  /// The artist joined the list for the same reason and one more: since a
  /// catalogue track no longer borrows the file's embedded tag (see
  /// [loadFile]), a row that reached the DB without its credits would show no
  /// artist at all. `get_song_context` answers with `artists[{id,name}]`, i.e.
  /// the REAL list — two names for "Memento Mori", not the one free-text
  /// string its Vorbis comment carries — which is also what makes each of them
  /// tappable down to its own artist screen. Every path that ends without a
  /// catalogue credit hands over to [_fallBackToFileTagArtist], so the tag is
  /// the LAST word rather than the first.
  void _backfillIdentity(String path, {String? metaAlbum, String? artist}) {
    final id = currentOnlineId;
    if (id == null || id.isEmpty) return;
    if ((currentAlbumId ?? '').isNotEmpty &&
        (artworkUrl ?? '').isNotEmpty &&
        (currentArtist ?? '').isNotEmpty) {
      return;
    }
    // Asked once per song id per session — but the ANSWER is not cached, so a
    // second play of a tune the catalogue credits to nobody must still reach
    // the tag, or the artist line would be empty every time but the first.
    if (!_identityAsked.add(id)) {
      _fallBackToFileTagArtist(path);
      return;
    }
    unawaited(() async {
      try {
        final song = (await RewampDb.getSongContext(id))?.song;
        if (song == null) {
          _fallBackToFileTagArtist(path);
          return;
        }
        final aid = song.albumId;
        final art = song.artworkUrl;
        // Only fill a credit we do NOT have — a caller that passed one knows
        // the row it played (a subsong's own arranger, say) better than the
        // song-level context does.
        final cre = (currentArtist ?? '').isEmpty && song.artistLabel.isNotEmpty
            ? song.artistLabel
            : null;
        // The catalogue has been asked and named nobody: the file's tag is now
        // the only thing left, and it gets its turn (unlinked).
        if (cre == null) _fallBackToFileTagArtist(path);
        if ((aid ?? '').isEmpty && (art ?? '').isEmpty && cre == null) return;
        await LocalDb.instance.backfillTrackIdentity(path,
            albumId: aid, artworkUrl: art, artist: cre);
        // The recents row is keyed on the album id when there is one, so this
        // is also what re-keys an entry filed under its NAME and gives it its
        // cover (upsertRecentAlbum reconciles the two forms itself).
        final album = metaAlbum ?? currentAlbum;
        if (album != null && album.isNotEmpty && (aid ?? '').isNotEmpty) {
          await LocalDb.instance.upsertRecentAlbum(album, path,
              artist: artist ?? currentArtist ?? cre,
              artworkUrl: art ?? artworkUrl,
              albumId: aid,
              onlineId: currentOnlineId);
        }
        // Live too, not just on disk: the album link is computed from these
        // fields, and waiting for the next play to show it would be odd.
        if (filePath != path) return;   // track changed meanwhile
        currentAlbumId ??= aid;
        artworkUrl ??= art;
        if ((currentArtist ?? '').isEmpty && cre != null) currentArtist = cre;
        // The unflattened credit travels with it: the context answers with the
        // names AND their ids, and the artist line renders one link per artist
        // off them (a flattened "A & B" would have to be guessed apart again).
        if (currentArtistNames.isEmpty && song.artistNames.isNotEmpty) {
          currentArtistNames = song.artistNames;
          currentArtistIds   = song.artistIds;
        }
        await _refreshRecent();
        notifyListeners();
      } catch (_) {
        // Offline or unknown id. The catalogue could not answer, so the tag is
        // all we have — same treatment as an answer with no artist. It is not
        // written to the DB either way: a tag must never become the stored
        // credit of a catalogue row, only what the player shows for lack of
        // anything better.
        _fallBackToFileTagArtist(path);
      }
    }());
  }

  /// Last-resort artist for a CATALOGUE track: the file's own embedded tag,
  /// flagged [currentArtistIsFileTag] so the player draws it as plain text.
  /// No-op if a credit is already known or the track moved on meanwhile, and
  /// it never touches the database — see [_backfillIdentity].
  void _fallBackToFileTagArtist(String path) {
    if (filePath != path) return;             // track changed meanwhile
    if ((currentArtist ?? '').isNotEmpty) return;
    final t = audio.tagArtist;
    if (t.isEmpty) return;
    currentArtist          = t;
    currentArtistIsFileTag = true;
    notifyListeners();
  }

  /// [forPath] = le fichier POUR lequel ce contexte a été calculé.
  ///
  /// Ces valeurs viennent presque toujours d'après un `await` (téléchargement,
  /// lecture en base), et elles étaient appliquées au morceau COURANT — pas à
  /// celui qui les avait demandées. Lancer Commando (hvsc/c64) puis enchaîner
  /// sur un module Amiga suffisait: la réponse de Commando arrivait ensuite et
  /// repeignait le lecteur en C64, placeholder compris, puis se PERSISTAIT sur
  /// la ligne du module (l'écriture d'origine est en COALESCE). Un appelant qui
  /// sait pour quel fichier il a calculé passe donc [forPath], et la réponse en
  /// retard est jetée. Comparé au FICHIER seul: l'origine est une propriété du
  /// fichier, changer de sous-chanson ne l'invalide pas.
  void setAlbumContext({String? collectionSlug, String? platformName, int? year,
      String? forPath}) {
    if (forPath != null && filePath != forPath) return;
    currentCollectionSlug = collectionSlug;
    currentPlatformName   = platformName;
    // Only overwrite when the caller actually knows a year: several call sites
    // set collection/platform from an album while the year came from the track
    // row that loadFile already went through.
    if (year != null) currentYear = year;
    // Persist it too, on the row loadFile just wrote (mig 52). The order is the
    // whole point: `_persistPlay` runs INSIDE loadFile, before the caller gets
    // to hand over the album context, so the play alone would always store a
    // null origin — and a later replay would be back to guessing it from the
    // file path. Fire-and-forget; upsertTrack COALESCEs, so a call that knows
    // nothing erases nothing.
    final trackId = _currentTrackId;
    if (trackId != null &&
        ((collectionSlug ?? '').isNotEmpty ||
            (platformName ?? '').isNotEmpty ||
            year != null)) {
      unawaited(LocalDb.instance
          .setTrackOrigin(trackId, collectionSlug, platformName, year));
    }
    notifyListeners();
  }

  /// Relit le ♥ du morceau courant. Appelée au chargement, et à chaque
  /// changement de la base: le ♥ peut bouger SANS passer par le lecteur —
  /// retrait de la bibliothèque depuis une liste (le ♥ part avec l'entrée),
  /// geste fait sur un autre appareil et redescendu par la synchro. Le cœur
  /// restait alors allumé sur un morceau qui n'était plus favori.
  Future<void> refreshFavourite() async {
    final refId = libraryRefId;
    // `library_items` fait foi (migration serveur 206). PAS d'entrée = PAS de
    // favori: un favori est une entrée de bibliothèque, donc retirer le
    // morceau de la bibliothèque retire le ♥ — c'est l'invariant que le
    // serveur applique aussi. Garder la valeur courante « faute de mieux »
    // laissait le cœur allumé sur un morceau qu'on venait de retirer.
    var fav = refId == null
        ? null
        : await LocalDb.instance.libraryItemFavourite('track', refId);
    // Repli hérité, pour une piste jouée qui n'a jamais eu d'entrée.
    final id = _currentTrackId;
    if (fav == null && id != null) {
      fav = await LocalDb.instance.trackIsFavourite(id);
    }
    final v = fav ?? false;
    if (v != isFavorite) {
      isFavorite = v;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite() async {
    final id = _currentTrackId;
    if (id == null) return;
    isFavorite = !isFavorite;
    notifyListeners();
    await LocalDb.instance.setFavorite(id, value: isFavorite);
    // A favourite is a library item with is_favorite=1 — write it under the SAME
    // subsong-scoped ref_id the library button uses (libraryRefId), else the two
    // disagree (bare online id vs "…?subsong=N") → button stays dark + duplicate
    // library rows. Un-favourite keeps the row (favourite ⊆ library).
    final refId = libraryRefId;
    if (refId != null) {
      if (isFavorite) {
        await LocalDb.instance.addToLibrary(
          type:        'track',
          refId:       refId,
          name:        fileName,
          artist:      currentArtist,
          album:       currentAlbum,
          albumId:     currentAlbumId,
          artworkUrl:  artworkUrl,
          formatExt:   currentFormatExt,
          filename:    fileName,
          isFavorite:  true,
          explicit:    false, // favorite flow — not an explicit library add
        );
      } else {
        await LocalDb.instance.setLibraryItemFavorite('track', refId, value: false);
      }
    }
    // Server-side favourite/library sync uses the bare online identity. Queued,
    // not POSTed: a gesture made offline (or lost to a 500) must survive until
    // it is actually delivered.
    if (currentOnlineId != null) {
      await SyncService.recordLibraryChange(
        itemType:   'song',
        itemId:     currentOnlineId!,
        // Le ♥, pas l'appartenance (migration serveur 206): un ♥ pose l'entrée
        // en bibliothèque côté serveur, un un-♥ l'y laisse. Avant, un un-♥
        // partait en `p_value: false` et RETIRAIT le morceau de la
        // bibliothèque.
        value:      isFavorite,
        favourite:  isFavorite,
        subsongIdx: subsongIdx,
      );
    } else if (filePath != null) {
      // A file of the user's own: queued with its snapshot so it travels the
      // day the server can take it (proposal §2bis) instead of staying local
      // for ever.
      await SyncService.recordLocalLibraryChange(
        itemType:   'song',
        // Un favori HORS CATALOGUE marche à l'identique (`p_ext_key`), spec
        // mig 206 §1 — c'est un ♥, pas une appartenance.
        favourite:  isFavorite,
        // The FILE's name, never `fileName` — that field is the display title
        // ("Kingdom Baron"), and using it built an ext identity out of a title:
        // the round trip then minted a row at the computed path
        // `local/Kingdom Baron` instead of finding the .spc already on disk,
        // and the tune appeared twice in the library.
        fileName:   filePath!.split(Platform.pathSeparator).last,
        relPath:    await LocalDb.instance.relPathOf(filePath),
        value:      isFavorite,
        entryPath:  entryPath,
        subsongIdx: subsongIdx,
        title:      fileName,
        artist:     currentArtist,
        album:      currentAlbum,
        formatExt:  currentFormatExt,
        durationS:  duration > 0 ? duration : null,
      );
    }
  }

  void _maybeFireLogPlay({bool forceEnd = false}) {
    if (_logPlayFired) return;
    if (_elapsedPlayMs < 10000) return; // client-side guard: ignore very short plays
    // The token is what attributes the play; without one the call is refused.
    if (!UserSettings.instance.hasAuthToken) return;

    final durationMs = duration > 0 ? (duration * 1000).round() : 0;
    const threshold30s = 30000;
    final thresholdHalf = durationMs > 0 ? durationMs ~/ 2 : 0;

    final shouldFire = forceEnd ||
        _elapsedPlayMs >= threshold30s ||
        (thresholdHalf > 0 && _elapsedPlayMs >= thresholdHalf);

    if (!shouldFire) return;
    // Fichier HORS CATALOGUE: l'écoute part par l'outbox log_plays_ext (lot
    // idempotent, survit hors-ligne) — même identité ext que le ♥, donc
    // écoute et favori fusionnent sur la même ligne serveur.
    if (currentOnlineId == null) {
      final path = filePath;
      if (path == null) return;
      _logPlayFired = true;
      final elapsed = _elapsedPlayMs;
      final eventId = _pushablePlayEventId;
      final trackId = _currentTrackId;
      unawaited(() async {
        try {
          await SyncService.recordExtPlay(
            fileName:   path.split(Platform.pathSeparator).last,
            relPath:    await LocalDb.instance.relPathOf(path),
            entryPath:  entryPath,
            subsongIdx: subsongIdx,
            durationMs: elapsed,
            backend:    backend,
            // La ligne locale que la livraison du lot marquera `pushed`.
            playEventId: eventId,
            trackId:     trackId,
            title:      fileName,
            artist:     currentArtist,
            album:      currentAlbum,
            formatExt:  currentFormatExt,
            durationS:  duration > 0 ? duration : null,
          );
        } catch (e) {
          debugPrint('[PlayerCtrl] recordExtPlay failed: $e');
        }
      }());
      return;
    }
    _logPlayFired = true;
    // currentOnlineId is already uuid#N for container tracks (built by
    // expandContainerAlbum's synthetic ids) — but a SID/NSF subsong played
    // through `?subsong=N` keeps a BARE uuid (the suffix lives on the audio
    // path, never on the id), so every subtune was logged as the file's
    // first track (Commando #2 counted as Commando #0). Stamp the LIVE
    // subsong index on: `#0` included when the file is multi-subsong — a
    // bare uuid and `#0` are not the same statement to the server.
    var sent = currentOnlineId!;
    if (!sent.contains('#') &&
        (subsongIdx > 0 || (currentSubsongCount ?? 0) > 1)) {
      sent = '$sent#$subsongIdx';
    }
    debugPrint('[PlayerCtrl] logPlay firing elapsed=${_elapsedPlayMs}ms songId=$sent');
    final eventId = _pushablePlayEventId;
    unawaited(RewampDb.logPlay(
      songId:     sent,
      durationMs: _elapsedPlayMs,
      // `audio.backendName`, le slug du plugin qui a réellement pris le
      // fichier — c'est la seule source qui ne se trompe pas: l'extension ne
      // désigne pas le moteur (deux pour `.sndh`, `.hes` disputé, etc.).
      backend:    backend,
    ).then((delivered) {
      // Livrée = le compte la porte, donc le miroir de la timeline la
      // ramènera: l'écran Stats doit la lire LÀ, pas ici. Un envoi raté
      // (log_play est sans reprise) laisse pushed = 0 et l'écoute reste
      // comptée localement — jamais perdue, jamais doublée.
      if (delivered && eventId != null) {
        LocalDb.instance.markPlayEventsPushed([eventId]);
      }
    }));
  }

  /// Loads the demozoo videos, notes and tags of [onlineId] (bare uuid or
  /// 'uuid#N' container key — the server wants the bare uuid). Fire-and-forget;
  /// ignores results landing after the track changed.
  Future<void> _fetchVideos(String? onlineId) async {
    if (onlineId == null || onlineId.isEmpty) return;
    final id = onlineId.split('#').first;
    final expected = currentOnlineId;
    try {
      final ctx = await RewampDb.getSongContext(id);
      if (ctx == null || currentOnlineId != expected) return;
      if (ctx.videos.isNotEmpty || ctx.notes.isNotEmpty ||
          ctx.tags.isNotEmpty || ctx.productions.isNotEmpty ||
          ctx.song.podium != null) {
        videos          = ctx.videos;
        notes           = ctx.notes;
        songTags        = ctx.tags;
        songProductions = ctx.productions;
        // Never DOWNGRADE a podium the play path already handed over: both come
        // from the same catalogue column, and a context call that answers with
        // none (a container id resolved to its file, say) would otherwise make
        // the cup blink out a second after it appeared.
        songPodium      = ctx.song.podium ?? songPodium;
        notifyListeners();
      }
    } catch (_) {/* context extras are optional */}
  }

  void togglePlay() {
    // First press on a restored-but-not-loaded track: load it for real now.
    if (primed) {
      primed = false;
      onResumePrimed?.call();
      return;
    }
    // The queue played out: play means "start the queue again", not "replay the
    // last track" — the decoder still holds it, which is the only reason the
    // old behaviour existed. Guarded on !isPlaying so this can never hijack a
    // pause press.
    if (queueExhausted && !isPlaying && onRestartQueue != null) {
      queueExhausted = false;
      onRestartQueue!.call();
      return;
    }
    if (!hasFile) return;
    if (isPlaying) {
      audio.pause();
      isPlaying = false;
      // iOS: Now Playing / Control Center keeps showing the PAUSE glyph as
      // long as the audio unit is running (it ignores the playbackRate=0 the
      // media session advertises) — pause only stops the ma_sound, the device
      // keeps rendering silence. Stop the whole device once the 12 ms
      // anti-click fade has rendered; C-side re-checks it is still paused (a
      // quick play wins the race) and play() restarts the device.
      if (Platform.isIOS) {
        Future.delayed(const Duration(milliseconds: 60), () {
          if (!isPlaying) audio.deviceSuspend();
        });
      }
    } else {
      // Resuming after an AVAudioSession interruption (another app took the
      // output): the session was deactivated by the system and the engine's
      // ma_device_start alone plays into a dead session. Reactivate first —
      // the gate is injected by initMediaSession (null off-iOS/-Android).
      final gate = ensureAudioSession;
      if (gate != null) {
        isPlaying = true; // optimistic: the UI flips immediately
        gate().catchError((_) {}).whenComplete(() {
          if (isPlaying) audio.play();
        });
        notifyListeners();
        return;
      }
      audio.play();
      isPlaying = true;
    }
    notifyListeners();
  }

  /// Reactivates the platform audio session before an engine resume — set by
  /// initMediaSession. See togglePlay.
  Future<void> Function()? ensureAudioSession;

  void stop() {
    _flushPlayEventDuration();
    // Cancel any in-progress fast-forward seek before stopping.
    // rewamp_stop() already sets g_seek_cancel; the audio.stop() call triggers it.
    audio.stop();
    isPlaying  = false;
    position   = 0;
    isSeeking  = false;
    notifyListeners();
  }

  bool isSeeking = false;

  void seek(double seconds) {
    // Pointing at a position outranks "the queue ended": play resumes there.
    queueExhausted = false;
    // Forced loop: the slider spans base×passes (elapsed timeline) but the
    // decoder only spans one pass and loops. Move the elapsed clock to the
    // target and seek the decoder to the equivalent point WITHIN the current
    // pass (target % base). Display tracks the elapsed clock, not the C-side
    // fast-forward cursor (which is on the single-pass timeline), so don't arm
    // the isSeeking polling path here.
    if (_forceLoopActive) {
      final base   = _forceBaseSecs;
      final within = (base != null && base > 0) ? seconds % base : seconds;
      _elapsedPlayMs   = (seconds * 1000).round();
      _forceSeekOffset = seconds - within;   // completed-passes offset
      audio.seek(within);
      audio.resetSilence();   // fresh decode position → don't trip restart-on-silence
      isSeeking = true;       // animate progress via the tick() polling below
      position  = seconds;
      notifyListeners();
      return;
    }
    // rewamp_seek_seconds() cancels any previous seek and starts a new one.
    audio.seek(seconds);
    isSeeking = true;
    position  = seconds;
    notifyListeners();
  }

  /// Maps a single-pass base length to the DISPLAYED known duration: base×passes
  /// while a generic forced loop is active ('on'), otherwise the base as-is.
  /// (Native-loop plugins never take this path — they're handled at load.)
  double? _displayedDurationFor(double? baseSeconds) {
    if (baseSeconds == null || baseSeconds <= 0) return null;
    if (_forceLoopActive && effectiveForceLoopMode == 'on') {
      return baseSeconds * (UserSettings.instance.loopCount + 1);
    }
    return baseSeconds;
  }

  /// Override the displayed duration (e.g. from HVSC songlength database).
  /// Pass null to revert to the audio engine's own reported length. The value
  /// is a SINGLE-pass length; a generic forced loop expands it to base×passes.
  void setKnownDuration(double? seconds) {
    _forceBaseSecs = (seconds != null && seconds > 0) ? seconds : null;
    _knownDuration = _displayedDurationFor(seconds);
    duration = _knownDuration ?? audio.durationSeconds;
    notifyListeners();
  }

  /// Update the track label and/or artist shown in the UI (e.g. after
  /// fetching STIL data from the server for local SID files).
  void updateTrackLabel({String? title, String? artist}) {
    bool changed = false;
    if (title  != null && title  != fileName) { fileName      = title;  changed = true; }
    if (artist != null && artist != currentArtist) {
      currentArtist = artist;
      // A real credit (STIL, HVSC…) supersedes a file tag standing in for one.
      currentArtistIsFileTag = false;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Called when the track ends naturally (not via stop/pause/loadFile).
  /// AppShell wires this up to advance the album queue.
  VoidCallback? onTrackEnded;

  /// Called at the end of every [loadFile] with its result. AppShell uses it as
  /// a safety net: a file that DOWNLOADED fine but the native decoder REFUSED
  /// (a corrupt module, or a mis-tagged row asking for a `?subsong=N` the file
  /// doesn't have) would otherwise stall the queue silently. `ok == false` →
  /// skip to the next entry (bounded, so a run of bad rows can't spin forever);
  /// `ok == true` clears that consecutive-failure count.
  void Function(bool ok)? onLoadResult;

  // Context of the most recent loadFile ATTEMPT — set unconditionally (success
  // AND failure), unlike filePath/currentOnlineId which only update on success.
  // The load-failure handler reads these to name the unplayable file in the
  // message and to report it to the server (report_song).
  String? lastLoadPath;
  /// The last failed load failed because THE FILE WAS NOT THERE, not because a
  /// decoder refused it. The two need different words and different
  /// consequences: a missing file is not a format bug and must not be reported
  /// as one (report_song would gain a `no_playback` row for a perfectly good
  /// tune), and it is often recoverable - the catalogue can hand the file back.
  bool lastLoadMissingOnDisk = false;
  String? lastLoadLabel;
  String? lastLoadFormatExt;
  int     lastLoadSubsongIdx = 0;
  String? lastLoadOnlineId;

  /// True when the player is DISPLAYING a track (title/artist/artwork) that has
  /// NOT been handed to the native decoder yet — the restored-queue "resume"
  /// state at launch. The first play press loads it for real (via
  /// [onResumePrimed]) instead of toggling a not-loaded file. Cleared by any
  /// real [loadFile]. Starting playback at launch instead leaked audio on iOS
  /// and tripped Android's foreground-service watchdog.
  bool primed = false;
  VoidCallback? onResumePrimed;

  /// True once the LAST queue entry has played out with no loop and nothing to
  /// advance to. The decoder still holds that file, so a plain play press would
  /// replay it — which reads as "the player is stuck on the last track" rather
  /// than as the end of a listening session. The next play press restarts the
  /// queue from the top instead (via [onRestartQueue]).
  ///
  /// Only a NATURAL end sets it, so pause/play mid-track is unaffected, and any
  /// real [loadFile] or a [seek] clears it — after a seek the user is pointing
  /// at a position and expects play to resume there.
  bool queueExhausted = false;
  VoidCallback? onRestartQueue;

  /// Shows [item metadata] as the current track WITHOUT loading the decoder, so
  /// the mini-player/player reappear paused after a relaunch. Playback starts on
  /// the first play press (see [togglePlay] → [onResumePrimed]).
  void primeForDisplay({
    required String filePath,
    required String label,
    String? artist,
    List<String>? artistNames,
    List<String>? artistIds,
    String? album,
    String? albumId,
    String? onlineId,
    String? artworkUrl,
    String? artworkTargetDir,
    int subsongIdx = 0,
    double? durationS,
  }) {
    this.filePath         = filePath;
    fileName              = label;
    currentArtist         = artist;
    currentArtistNames    = artistNames ?? const [];
    currentArtistIds      = artistIds ?? const [];
    // A primed display comes from the persisted queue, i.e. from the DB, which
    // never stores a file tag as a credit — so whatever is shown here is real.
    currentArtistIsFileTag = false;
    currentAlbum          = album;
    // Album/online identity too — without them the primed player screen showed
    // the album name as an inert label (the link needs a real albumId and a
    // non-local onlineId) until playback was actually restarted.
    currentAlbumId        = albumId;
    currentOnlineId       = onlineId;
    this.artworkUrl       = artworkUrl;
    this.artworkTargetDir = artworkTargetDir;
    this.subsongIdx       = subsongIdx;
    duration              = durationS ?? 0;
    position              = 0;
    isPlaying             = false;
    primed                = true;
    notifyListeners();
  }

  /// Called by AppShell's periodic timer to refresh position.
  void tick() {
    if (!hasFile) return;

    // While a fast-forward seek is running, poll C-side progress so the slider
    // animates.  Transition isSeeking→false when the audio thread finishes.
    if (isSeeking) {
      final seeking = audio.isSeeking();
      final prog    = audio.seekProgressSeconds();
      final d       = _knownDuration ?? audio.durationSeconds;
      // Under a forced loop the C seek runs on the single-pass timeline; shift
      // its progress onto the base×passes slider by the completed-passes offset.
      final isForce = _forceLoopActive;
      if (!seeking) {
        isSeeking = false;
        // Snap to the real cursor once done — elapsed target for a forced loop,
        // the decoder cursor otherwise.
        final p = isForce ? (_elapsedPlayMs / 1000.0) : audio.positionSeconds;
        if (p != position || d != duration) {
          position = p;
          duration = d;
          notifyListeners();
        } else {
          notifyListeners();
        }
      } else {
        final disp = isForce ? (_forceSeekOffset + prog) : prog;
        if (disp != position) {
          position = disp;
          if (d != duration) duration = d;
          notifyListeners();
        }
      }
      return;
    }

    final p  = audio.positionSeconds;
    final d  = _knownDuration ?? audio.durationSeconds;

    // Accumulate real play time for log_play.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (isPlaying && !isSeeking && _lastTickMs > 0) {
      _elapsedPlayMs += nowMs - _lastTickMs;
    }
    _lastTickMs = nowMs;

    // Forced-fadeout in progress: ramp volume down in real time, independent
    // of the normal position/duration bookkeeping below.
    if (_fadingOut) {
      _tickForcedFadeout(nowMs);
      return;
    }

    // Arrêt armé par _endLoopedPlayback (repeat coupé en cours de lecture),
    // mesuré sur le temps écoulé et non sur `p` — voir _loopStopAtSecs.
    if (_loopStopAtSecs != null &&
        _elapsedPlayMs / 1000.0 >= _loopStopAtSecs!) {
      _loopStopAtSecs = null;
      _stopAfterForcedLoop();
      return;
    }

    // Forced loop owns its own end-of-track / looping / fadeout timeline.
    if (_forceLoopActive) {
      _tickForceLoop(nowMs);
      return;
    }

    // Enforce known duration: chip-music formats (NSF, SID, GBS, …) loop
    // indefinitely — audio.isPlaying never goes false on its own. Stop the
    // engine here so the end-of-track branch below fires normally (for a
    // genuinely finite format, audio.isPlaying already went false on its
    // own instead).
    final reachedKnownEnd = _knownDuration != null && _knownDuration! > 0 &&
        p >= _knownDuration! && audio.isPlaying;
    if (reachedKnownEnd) {
      audio.stop();
    }

    final pl = audio.isPlaying;
    final naturalEnd = !pl && isPlaying;

    // Natural end-of-track: audio stopped on its own.
    // stop(), pause() and loadFile() all update `isPlaying` before this tick
    // runs (Dart is single-threaded), so they never trigger this branch.
    if (naturalEnd) {
      _maybeFireLogPlay(forceEnd: true);
      _flushPlayEventDuration();
      onTrackEnded?.call();
      // END OF THE QUEUE (the handler advanced nothing): same iOS quirk the
      // pause path works around — the device keeps rendering silence and
      // Control Center keeps the PAUSE glyph as long as the audio unit runs.
      // Suspend it once nothing restarted; rewamp_play() restarts the device,
      // so a later advance (even a slow download) is unaffected.
      if (Platform.isIOS) {
        Future.delayed(const Duration(milliseconds: 60), () {
          if (!isPlaying && !audio.isPlaying) audio.deviceSuspend();
        });
      }
    }
    // Silence auto-skip: if the output has been silent past the configured
    // threshold while still "playing", treat the track as ended and advance.
    // Covers formats that loop or never signal end (e.g. PSF without a length
    // tag that fades to silence).
    else if (pl && isPlaying && !isSeeking &&
        UserSettings.instance.silenceSkipEnabled &&
        audio.silentSeconds >= UserSettings.instance.silenceSkipSeconds) {
      audio.resetSilence();
      _maybeFireLogPlay(forceEnd: true);
      onTrackEnded?.call();
    }
    _maybeFireLogPlay();

    // Boucle infinie NATIVE (libvgm, vgmstream): le moteur annonce la durée
    // d'UNE passe mais sa position continue de monter — même gel d'affichage
    // que le chemin générique, par un autre trajet. On ne fait suivre le total
    // que s'il est réellement dépassé, ce qui laisse tranquille un moteur dont
    // la position REBOUCLE à chaque passe (libopenmpt): là le curseur repart à
    // zéro et l'affichage est déjà cohérent.
    final dShown = (effectiveForceLoopMode == 'infinite' && p > d)
        ? (infiniteDisplayTotal(p, _forceBaseSecs ?? (d > 0 ? d : null)) ?? d)
        : d;
    if (p != position || dShown != duration || pl != isPlaying) {
      position  = p;
      duration  = dShown;
      isPlaying = pl;
      notifyListeners();
    }
  }

  // ── Forced loop/fadeout (Settings → Lecture) ────────────────────────────────

  /// Time (s) the output must stay silent before we treat a tune as "no longer
  /// generating audio" and restart it to keep the forced loop going. Long
  /// enough not to trip on musical rests, short enough to feel like a loop.
  static const double _kForceLoopRestartSilence = 1.2;

  /// Temps de lecture minimal avant de juger qu'un moteur ARRÊTÉ l'est pour de
  /// bon: au tout début, le producteur n'a pas encore rempli l'anneau et le son
  /// peut légitimement se dire à l'arrêt pendant quelques dizaines de ms.
  static const int _kForceLoopStartGraceMs = 1500;

  /// Écart minimal entre deux relances, pour qu'un fichier qui ne produit
  /// RIEN ne se fasse pas relancer à chaque tick (250 ms) sans fin.
  static const int _kForceLoopRestartCooldownMs = 1000;
  int _lastLoopRestartMs = 0;

  /// Drives forced-loop playback on the elapsed-time timeline.
  ///
  /// The displayed duration is base×passes (the whole forced run). Progress is
  /// tracked by *elapsed play time* (_elapsedPlayMs), NOT the decoder position
  /// — because the two cases below can reset the decoder to 0 mid-run:
  ///   • self-looping tune (many SIDs keep generating audio past the base
  ///     length): left to play through — we do NOT seek it back, per the
  ///     "don't reset if still producing audio" rule.
  ///   • non-self-looping tune (goes silent at its natural end before the
  ///     forced total): restarted from 0 so audio continues to the total.
  ///   • tune whose DECODER stops outright, with no trailing silence at all:
  ///     also restarted — le compteur de silence ne peut pas le voir (voir le
  ///     commentaire de `engineStopped` plus bas).
  /// Aucune connaissance par format n'est nécessaire: on ne regarde que « est-ce
  /// que ça sort encore du son », sous ses deux formes.
  void _tickForceLoop(int nowMs) {
    final mode    = effectiveForceLoopMode; // 'on' | 'infinite'
    final elapsed = _elapsedPlayMs / 1000.0;

    // « la musique ne produit plus rien » a DEUX formes, et la seconde
    // n'apparaît PAS dans le compteur de silence. `g_silent_frames` est
    // alimenté par le PRODUCTEUR sur du PCM décodé (rewamp_waveform_write):
    // un décodeur qui s'arrête NET — 0 image, sans traîne silencieuse — le
    // laisse GELÉ, pas croissant. Le moteur, lui, passe à l'arrêt. Sans ce
    // second cas, la branche 'infinite' sortait par son `return` avant toute
    // détection de fin: ni relance, ni avancement de file. Cas réaliste: un
    // flux vgmstream SANS point de boucle, vetoé donc générique.
    final engineStopped = !audio.isPlaying &&
        _elapsedPlayMs > _kForceLoopStartGraceMs;
    final stalled = isPlaying &&
        (engineStopped ||
            (audio.isPlaying &&
                audio.silentSeconds >= _kForceLoopRestartSilence));

    void restartIfStalled() {
      if (!stalled) return;
      if (nowMs - _lastLoopRestartMs < _kForceLoopRestartCooldownMs) return;
      _lastLoopRestartMs = nowMs;
      audio.seek(0);
      audio.resetSilence();
      // Un seek seul ne relance pas un son TERMINÉ — miniaudio l'a démonté.
      if (engineStopped) audio.play();
    }

    if (mode == 'infinite') {
      restartIfStalled();
      final total = infiniteDisplayTotal(elapsed, _forceBaseSecs) ?? duration;
      if (elapsed != position || total != duration) {
        position = elapsed;
        duration = total;
        notifyListeners();
      }
      return;
    }

    final total = _knownDuration; // base × passes
    if (total == null || total <= 0) {
      // Base length not known yet (e.g. SID songlength still loading) — keep it
      // alive like infinite until a real total arrives via setKnownDuration.
      restartIfStalled();
      return;
    }

    // Proactive fadeout so it audibly finishes AT the total.
    if (UserSettings.instance.forceFadeoutEnabled &&
        UserSettings.instance.fadeoutSeconds > 0 &&
        total - elapsed <= UserSettings.instance.fadeoutSeconds) {
      _fadingOut   = true;
      _fadeStartMs = nowMs;
      notifyListeners();
      return;
    }
    // Reached the total with no fade → stop / advance.
    if (elapsed >= total) {
      _stopAfterForcedLoop();
      return;
    }
    // Mid-run: keep the tune audible if it went silent.
    restartIfStalled();
    if (elapsed != position || total != duration) {
      position = elapsed;
      duration = total;
      notifyListeners();
    }
  }

  void _tickForcedFadeout(int nowMs) {
    final total = UserSettings.instance.fadeoutSeconds;
    final t = total > 0
        ? ((nowMs - _fadeStartMs) / 1000.0 / total).clamp(0.0, 1.0)
        : 1.0;
    audio.setVolume(1.0 - t);
    if (t >= 1.0) {
      _fadingOut = false;
      _stopAfterForcedLoop();
    } else {
      notifyListeners();
    }
  }

  void _stopAfterForcedLoop() {
    audio.stop();
    audio.setVolume(1.0); // restore for whatever plays next
    isPlaying = false;
    _maybeFireLogPlay(forceEnd: true);
    onTrackEnded?.call();
    notifyListeners();
  }

  // ── "Playing now" queue (display only, owned by AppShell) ───────────────────

  List<QueueEntry> _queue    = const [];
  int               _queueIdx = -1;

  List<QueueEntry> get queue    => _queue;
  int               get queueIdx => _queueIdx;

  void setQueue(List<QueueEntry> entries, {int currentIdx = 0}) {
    _queue    = entries;
    _queueIdx = currentIdx;
    notifyListeners();
  }

  void updateQueueIdx(int idx) {
    if (_queueIdx == idx) return;
    _queueIdx = idx;
    notifyListeners();
  }

  /// Update queue entry titles after async metadata fetch (e.g. STIL names).
  /// [idxToTitle] maps 0-based queue position → new title string.
  void updateQueueEntries(Map<int, String> idxToTitle) {
    bool changed = false;
    for (final e in idxToTitle.entries) {
      if (e.key >= 0 && e.key < _queue.length && _queue[e.key].title != e.value) {
        _queue[e.key] = QueueEntry(title: e.value, artist: _queue[e.key].artist);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void clearQueue() {
    _queue    = const [];
    _queueIdx = -1;
    notifyListeners();
  }

  // Called by PlayerScreen when user taps a queue entry.
  // AppShell wires this up to the appropriate jump function.
  void Function(int)? onGoToQueueIndex;

  void goToQueueIndex(int i) => onGoToQueueIndex?.call(i);

  /// Queue EDITING, wired by AppShell — which owns the real queue; the
  /// controller's own [queue] is a presentation mirror with no identity of its
  /// own, so a reorder/removal cannot be applied here. Both queue panels (the
  /// player's overlay and the desktop sidebar) go through these, the same way
  /// they already go through [goToQueueIndex] for the tap.
  void Function(int oldIndex, int newIndex)? onReorderQueue;
  void Function(Set<int> indices)? onRemoveFromQueue;

  /// Vider la file ET arrêter la lecture — voir AppShell._clearQueue. Passe
  /// par le même relais que les deux ci-dessus: [clearQueue] ne touche que le
  /// MIROIR de présentation, la vraie file appartient à AppShell.
  VoidCallback? onClearQueue;

  bool get canEditQueue => onReorderQueue != null && onRemoveFromQueue != null;

  void reorderQueue(int oldIndex, int newIndex) =>
      onReorderQueue?.call(oldIndex, newIndex);

  void removeFromQueue(Set<int> indices) {
    if (indices.isEmpty) return;
    onRemoveFromQueue?.call(indices);
  }

  /// A downloaded track was just deleted from disk — AppShell drops any queue
  /// entry pointing at it (so it stops showing / can't be tapped into playing a
  /// surviving sibling). Called by the delete actions with the deleted file path.
  /// Returns true when the deleted track was the current one AND AppShell
  /// started the next queue entry in its place.
  /// [asPrefix] = [path] is a DIRECTORY: every entry under it goes, not just
  /// the entries playing from that exact file.
  Future<bool> Function(String path, {bool asPrefix})? onTrackDeleted;
  Future<bool> notifyTrackDeleted(String path, {bool asPrefix = false}) async =>
      await onTrackDeleted?.call(path, asPrefix: asPrefix) ?? false;

  // ── Shuffle (real queue-reorder logic owned by AppShell; mirrored here so
  // the queue panel — reachable from the full player AND the sidebar — can
  // show/toggle it without reaching into AppShell directly) ──────────────────
  bool _shuffleEnabled = false;
  bool get shuffleEnabled => _shuffleEnabled;

  void setShuffleEnabled(bool v) {
    if (_shuffleEnabled == v) return;
    _shuffleEnabled = v;
    notifyListeners();
  }

  VoidCallback? onToggleShuffle;
  void toggleShuffle() => onToggleShuffle?.call();

  // ── Repeat / loop ────────────────────────────────────────────────────────
  // 0 = off (stop at the end of the queue, today's behaviour)
  // 1 = queue: wrap to the first queue item when the last one ends
  // 2 = track: replay the current track forever ("1" badge)
  // The wrap/replay itself happens in AppShell's onTrackEnded (it owns the
  // queue) — this is just the observable mode + a way to cycle it from the UI.
  // Restored from the preferences: a transport mode survives quitting the app
  // (see UserSettings.transportLoopMode).
  int _loopMode = UserSettings.instance.transportLoopMode;
  int get loopMode => _loopMode;
  void cycleLoopMode() {
    final wasLooping = effectiveForceLoopMode != 'off';
    _loopMode = (_loopMode + 1) % 3;
    UserSettings.instance.transportLoopMode = _loopMode;
    if (wasLooping && effectiveForceLoopMode == 'off') _endLoopedPlayback();
    notifyListeners();
  }

  /// Le mode repeat vient d'être coupé alors que le moteur BOUCLE déjà, et
  /// aucun moteur ne peut être reconfiguré en vol de façon uniforme: libvgm
  /// finirait la passe en cours, vgmstream couperait net (sous play-forever il
  /// saute le clamp de `play_position`, qui dépasse `play_duration` — effacer
  /// le drapeau rend « terminé » immédiatement), et tout le chemin générique
  /// n'a aucun moyen de l'exprimer. On tranche donc ICI, une fois, pour tous.
  ///
  /// Règle, sur la durée NOMINALE (celle d'UNE passe, sans boucle):
  ///  - pas encore atteinte → on laisse jouer et on s'arrête À la durée
  ///    nominale, c'est-à-dire la fin naturelle du morceau. Couper à 0:30 d'un
  ///    morceau de 2:30 parce qu'on éteint repeat serait un saut de piste
  ///    déguisé — ce n'est pas ce que le bouton dit faire.
  ///  - atteinte ou dépassée → on est dans une passe SUPPLÉMENTAIRE, qui n'a
  ///    plus de raison d'être: on termine, avec le fondu si l'utilisateur en a
  ///    demandé un dans Réglages → Lecture.
  ///
  /// Durée nominale inconnue → on ne devine pas: la piste continue comme
  /// avant, et le mode s'appliquera au prochain chargement. En pause non plus
  /// on ne fait rien (arrêter là ferait avancer la file sans qu'on joue).
  void _endLoopedPlayback() {
    _loopStopAtSecs = null;
    if (!hasFile || !isPlaying) return;
    final base = _forceBaseSecs;
    switch (loopCutActionFor(
      elapsedSeconds: _elapsedPlayMs / 1000.0,
      nominalSeconds: base,
      fadeoutEnabled: UserSettings.instance.forceFadeoutEnabled,
      fadeoutSeconds: UserSettings.instance.fadeoutSeconds,
    )) {
      case LoopCutAction.none:
        return;
      case LoopCutAction.playToNominalEnd:
        _loopStopAtSecs = base;
      case LoopCutAction.fadeOut:
        _fadingOut   = true;
        _fadeStartMs = DateTime.now().millisecondsSinceEpoch;
      case LoopCutAction.stopNow:
        _stopAfterForcedLoop();
    }
  }

  /// Reloads the current track from the start — used for loop-track mode.
  Future<void> replayCurrent() async {
    if (!hasFile) return;
    await loadFile(
      filePath!,
      fileName,
      entryPath:        entryPath,
      subsongIdx:        subsongIdx,
      artist:            currentArtist,
      metaAlbum:         currentAlbum,
      metaAlbumId:       currentAlbumId,
      formatExt:         currentFormatExt,
      onlineId:          currentOnlineId,
      artworkUrl:        artworkUrl,
      artworkTargetDir:  artworkTargetDir,
      durationS:         _knownDuration,
    );
  }

  // ── Album queue navigation (callbacks owned by AppShell) ──────────────────
  //
  // PlayerController knows nothing about SearchResult or downloads.
  // AppShell wires up closures that download the next/prev item and call
  // loadFile once ready.

  Future<void> Function()? _queueNext;
  Future<void> Function()? _queuePrev;

  bool get canGoNext => _queueNext != null;

  /// "Previous" is always available once a track is loaded: past
  /// [_kPrevRestartSecs] it restarts the current track rather than stepping
  /// back in the queue (standard transport behaviour).
  bool get canGoPrev => _queuePrev != null || hasFile;

  void setQueueNav({
    Future<void> Function()? next,
    Future<void> Function()? prev,
  }) {
    _queueNext = next;
    _queuePrev = prev;
    notifyListeners();
  }

  Future<void> goNext() async => _queueNext?.call();

  /// Elapsed time past which "previous" restarts the current track instead of
  /// going back one entry in the queue.
  static const double _kPrevRestartSecs = 3.0;

  Future<void> goPrev() async {
    // Restarting the current track instead of stepping back is standard
    // transport behaviour — but ONLY while it is actually playing. Stopped, a
    // seek to zero makes no sound, and the button read as broken: that is the
    // case after a queue finishes, and after a queue is restored at launch and
    // sits primed. Both are exactly when a user reaches for "previous".
    final restartInPlace = isPlaying && position >= _kPrevRestartSecs;
    if (_queuePrev != null && !restartInPlace) {
      await _queuePrev!.call();
      return;
    }
    // No previous entry (first in the queue) — start what is here rather than
    // doing nothing. A primed track has to be loaded for real first.
    if (primed) {
      primed = false;
      onResumePrimed?.call();
      return;
    }
    if (!hasFile) return;
    seek(0);
    if (!isPlaying) togglePlay();
  }

  // ── Favorites / library passthrough ────────────────────────────────────────

  Future<void> setFavorite(String trackId, {required bool value}) async {
    await LocalDb.instance.setFavorite(trackId, value: value);
    await _refreshRecent();
  }

  Future<void> setInLibrary(String trackId, {required bool value}) async {
    await LocalDb.instance.setInLibrary(trackId, value: value);
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<void> _refreshRecent() async {
    final entries = await LocalDb.instance.getRecentEntries(limit: 32);
    recentEntries
      ..clear()
      ..addAll(entries);
    notifyListeners();
  }
}
