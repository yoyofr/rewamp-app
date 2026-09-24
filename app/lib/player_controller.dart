import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:path_provider/path_provider.dart';
import 'package:rewamp_audio/rewamp_audio.dart';
import 'library_identity.dart' show libraryRefIsPath, libraryRefRewrite;
import 'local_db.dart';
import 'artwork_image.dart' show ArtworkCache;
import 'queue_persistence.dart';
import 'rewamp_db.dart';
import 'sync_service.dart';
import 'uade_info.dart';
import 'transport_log.dart';
import 'user_settings.dart';
import 'linux_notifications.dart';

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

  /// La SOUS-CHANSON que cette entrée joue dans [localFilePath].
  ///
  /// Sans elle, la seule façon de désigner une entrée était sa POSITION — et
  /// une position n'est pas une identité (règle payée plusieurs fois dans ce
  /// dépôt). Voir [PlayerController.updateQueueEntries].
  final int? subsongIdx;

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
    this.subsongIdx,
  });

  /// N'énonce que la DIFFÉRENCE. Recopier dix champs à la main en perd en
  /// silence — c'est exactement ce qui vidait la pochette et l'`id` d'une
  /// entrée renommée.
  QueueEntry copyWith({String? title, String? artist}) => QueueEntry(
        id: id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        subtitle: subtitle,
        artworkUrl: artworkUrl,
        album: album,
        localFilePath: localFilePath,
        platformName: platformName,
        formatHint: formatHint,
        subsongIdx: subsongIdx,
      );
}


/// Position AFFICHÉE sous boucle infinie: le temps écoulé, PLAFONNÉ à une
/// passe.
///
/// La règle graduée ne couvre qu'une passe, et c'est ce qui rend le seek
/// exact: toute cible est dans `[0, base]`, donc dans le domaine que le
/// décodeur connaît. Traduire une cible au-delà demanderait le POINT DE BOUCLE
/// du fichier — après la première passe, la vérité musicale est
/// `L + (T − len) % (len − L)`, pas `T % len` — et peu de moteurs savent le
/// dire (libopenmpt boucle en interne sans l'exposer). Un modulo naïf casserait
/// justement les fichiers qui bouclent correctement.
///
/// ⚠️ **Plafonner, et non reboucler.** Faire retomber la barre à zéro à chaque
/// passe prétend savoir OÙ la musique est repartie — c'est faux dès qu'il y a
/// un point de boucle, et on ne le connaît pas. Une barre pleine ne prétend
/// rien: elle dit « au-delà de la durée nominale », ce qui est exactement ce
/// qu'on sait. La barre n'est donc juste que pendant la première passe, et
/// muette ensuite plutôt que menteuse.
///
/// (Le total, lui, ne monte plus. Il l'a fait — base × passes — pour éviter que
/// l'UI clampe une position qui grimpe sur un total figé; plafonner la position
/// lève le même gel par l'autre bout.)
///
/// ⚠️ Ce plafond ne vaut QUE pour la barre. Le compteur de gauche, lui, dit
/// depuis combien de temps ça joue et n'a rien à deviner: il continue de
/// monter (`PlayerController.elapsedPosition`).
///
/// Durée nominale inconnue ⇒ on rend le temps écoulé tel quel: rien pour
/// plafonner.
double infiniteDisplayPosition(double elapsedSeconds, double? nominalSeconds) {
  if (nominalSeconds == null || nominalSeconds <= 0) return elapsedSeconds;
  if (elapsedSeconds <= 0) return 0;
  return elapsedSeconds < nominalSeconds ? elapsedSeconds : nominalSeconds;
}

/// Un SILENCE peut-il vouloir dire « le morceau est fini » ?
///
/// Le détecteur de silence est le seul moyen de voir la fin d'un morceau qui
/// n'en déclare pas (SID, NSF: pas de longueur, le décodeur ne s'arrête
/// jamais). Mais appliqué SANS condition il confond une RESPIRATION MUSICALE
/// avec une fin, et sous boucle infinie il relance alors le morceau depuis
/// zéro — indéfiniment.
///
/// Deux fichiers l'ont montré le 2026-08-29, tous deux en boucle infinie:
///  - « Run » (sceneorg) a des passages silencieux au milieu: la lecture
///    rebouclait sur ses premières secondes.
///  - « Inside The BORG Cube » commence par **1,54 s de silence NUMÉRIQUE**
///    (mesuré sous le seuil du moteur, `REWAMP_SILENCE_EPS`), soit plus que le
///    seuil de relance (1,2 s): la piste se relançait avant d'avoir joué une
///    seule note, en boucle — **aucun son du tout**.
///
/// La règle: un silence n'est une fin que si le décodeur est ARRIVÉ AU BOUT.
/// À 0:03 d'un flux de 2:25, ce qu'on entend est un blanc, pas une fin.
///
/// ⚠️ Ce n'est PAS la règle « la durée nominale ne coupe rien » que la boucle
/// infinie applique par ailleurs — c'est son exact opposé et les deux tiennent
/// ensemble: on ne se sert jamais de la durée pour ARRÊTER une musique qui
/// joue encore, on s'en sert ici pour REFUSER une relance prématurée. La
/// première couperait, la seconde protège.
///
/// Durée nominale inconnue (SID, NSF, PSF sans tag) ⇒ on garde l'ancien
/// comportement: le silence est la seule fin observable, il fait foi. C'est
/// exactement la population pour laquelle ce détecteur a été écrit.
bool silenceCanMeanEnd({
  required double decoderPositionSeconds,
  required double? nominalSeconds,
}) {
  if (nominalSeconds == null || nominalSeconds <= 0) return true;
  return decoderPositionSeconds >= nominalSeconds - _kSilenceEndMarginSecs;
}

/// Marge sous la durée nominale: un décodeur peut s'arrêter quelques dixièmes
/// avant le total annoncé (fondu, padding de fin), et le curseur est échantillonné
/// au tick de 250 ms.
const double _kSilenceEndMarginSecs = 2.0;

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
/// « Le moteur s'est-il arrêté TOUT SEUL ? » — la question dont dépendent la
/// fin de piste (avancer la file) et la relance d'une boucle forcée.
///
/// Fonction PURE et hors classe pour être testable: instancier un
/// [PlayerController] appelle le natif (même raison que
/// [effectiveForceLoopModeFor]).
///
/// L'invariant du lecteur est que toute transition pose `isPlaying` AVANT de
/// toucher au moteur: `pause()`, `stop()` et `loadFile()` le font, donc
/// « moteur à l'arrêt alors qu'on se croit en lecture » ne peut vouloir dire
/// qu'une chose — la piste s'est terminée seule.
///
/// La REPRISE est la seule transition en sens inverse: le drapeau passe à vrai
/// tout de suite (l'UI doit répondre à l'appui) et le moteur ne démarre qu'après
/// une porte ASYNCHRONE — réactiver la session audio de la plateforme. Entre les
/// deux, l'état est mot pour mot celui d'une piste finie, et un tick qui tombe
/// là faisait avancer la file ou relançait le morceau depuis zéro: on appuie sur
/// lecture/pause et c'est « suivant » ou « précédent » qui part, au hasard —
/// selon que le tick de 250 ms tombe ou non dans la fenêtre d'activation.
bool engineStoppedByItself({
  required bool enginePlaying,
  required bool uiPlaying,
  required bool engineStartPending,
}) =>
    !enginePlaying && uiPlaying && !engineStartPending;

/// Applique des titres STIL à une file, par FICHIER et SOUS-CHANSON.
///
/// Fonction PURE et hors classe pour être testable (instancier un
/// [PlayerController] appelle le natif) — même patron que
/// [effectiveForceLoopModeFor]. Rend la MÊME instance pour une entrée
/// inchangée, ce qui laisse l'appelant détecter s'il y a lieu de notifier.
List<QueueEntry> applyQueueTitles(
    List<QueueEntry> queue, String filePath, Map<int, String> subsongToTitle) {
  return [
    for (final e in queue)
      if (e.localFilePath == filePath &&
          (subsongToTitle[e.subsongIdx ?? 0]?.isNotEmpty ?? false) &&
          e.title != subsongToTitle[e.subsongIdx ?? 0])
        e.copyWith(title: subsongToTitle[e.subsongIdx ?? 0])
      else
        e,
  ];
}

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
  /// Temps écoulé depuis le début du morceau, NON PLAFONNÉ.
  ///
  /// Égal à [position] partout — SAUF en boucle infinie, où [position] sature
  /// à la durée nominale parce que la barre ne peut pas dire OÙ la musique est
  /// repartie (voir [infiniteDisplayPosition]), alors que le compteur de
  /// gauche, lui, n'a rien à deviner: il dit depuis combien de temps ça joue,
  /// et doit continuer de monter. Deux grandeurs, deux champs.
  double   elapsedPosition = 0;
  // Duration override from server metadata (HVSC songlength / SID STIL).
  // When set, overrides audio.durationSeconds (which is 0 for SID/GME files
  // that have no natural length reported by the decoder).
  double?  _knownDuration;

  // Currently playing track's DB id (null until first play or DB load)
  String? _currentTrackId;

  /// Le FICHIER que [_currentTrackId] décrit.
  ///
  /// ⚠️ Sans lui, l'id est une identité SANS PORTÉE, et c'est ce qui produisait
  /// les écritures croisées d'origine. `_persistPlay` tourne en arrière-plan et
  /// ne pose `_currentTrackId` qu'APRÈS son aller-retour SQL; pendant ce temps
  /// le champ pointe encore la ligne du morceau PRÉCÉDENT — il n'était remis à
  /// zéro nulle part. `setAlbumContext` gardait bien le FICHIER (`forPath`),
  /// mais écrivait ensuite sur « la ligne courante », c'est-à-dire l'ancienne:
  /// le morceau N recevait la collection de N+1. Mesuré sur la base réelle:
  /// `hexplosion.hvl` (modland) estampillé `asma` et `Airball.sap` (asma)
  /// estampillé `modland`, à une minute d'intervalle, `play_count = 1` des deux
  /// côtés — donc des lignes NEUVES, pas d'anciennes rejouées.
  ///
  /// Le commentaire de la remontée d'origine, plus bas, frôlait la cause: il
  /// supposait l'id « pas encore produit », donc NULL. Il ne l'était pas.
  String? _currentTrackIdPath;

  // log_play tracking: accumulates real play time, fires once per track.
  int  _elapsedPlayMs  = 0;

  /// Horloge D'AFFICHAGE du compteur écoulé, en ms. Même accumulation que
  /// [_elapsedPlayMs] — mais elle, un SEEK la recale sur sa cible, alors que
  /// le temps réellement écouté ne recule pas. Deux questions différentes: la
  /// première nourrit le compteur de gauche sous boucle infinie (voir
  /// [elapsedPosition]), la seconde `log_play`.
  int  _playClockMs    = 0;
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
    if (base == null) return null;
    // La garde d'ajout peut avoir RÉÉCRIT cette identité (un chemin jetable
    // devenu la copie importée, un téléchargement devenu son songId): sans
    // consulter la réécriture, le ♥ qu'on vient de poser s'éteindrait au
    // relevé suivant — il chercherait la ligne sous l'ancienne clé. Voir
    // library_identity.dart.
    return libraryRefRewrite('$base?subsong=$subsongIdx');
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
    // Réglages → Lecture (boucles forcées, fondu) se change en cours de
    // morceau: le moteur doit le voir tout de suite, voir
    // _pushForcedLoopSnapshot.
    UserSettings.instance.addListener(_pushForcedLoopSnapshot);
  }

  void _onDbChanged() {
    if (filePath == null) return;
    unawaited(refreshFavourite());
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_onDbChanged);
    UserSettings.instance.removeListener(_pushForcedLoopSnapshot);
    super.dispose();
  }

  /// Durée d'UNE passe du morceau chargé, telle que transmise au moteur
  /// (catalogue, sinon la longueur par défaut des réglages).
  double? _forcedLoopBaseSecs;

  /// Pousse au moteur l'instantané de boucle forcée EN VIGUEUR: mode effectif
  /// (bouton repeat + Réglages → Lecture), passes, fondu, durée de base.
  ///
  /// Appelé à l'ouverture, comme avant — mais AUSSI à chaque geste qui change
  /// cet état en cours de lecture (bouton repeat, réglage). Les moteurs
  /// lisent la plupart de ces valeurs à l'ouverture, où c'est sans effet;
  /// mais la famille PSF consulte `g_force_loop_mode` à CHAQUE BLOC pour
  /// décider d'appliquer ou non son fondu de fin (rewamp_psf_fade.h): repeat
  /// infini armé à 1:00 d'un .dsf laissait le fondu calculé à l'ouverture
  /// éteindre le morceau avant qu'il ne reboucle. Le chemin générique Dart,
  /// lui, relit `effectiveForceLoopMode` à chaque tick et n'a pas besoin de ça.
  ///
  /// Sans fichier chargé, rien à pousser: `loadFile` le fera avec la bonne
  /// durée de base.
  void _pushForcedLoopSnapshot() {
    final base = _forcedLoopBaseSecs;
    if (base == null) return;
    final loopModeCode = switch (effectiveForceLoopMode) {
      'infinite' => 2,
      'on'       => 1,
      _          => 0,
    };
    audio.setForcedLoop(
      loopModeCode,
      UserSettings.instance.loopCount,
      fadeoutEnabled: UserSettings.instance.forceFadeoutEnabled,
      fadeoutSeconds: UserSettings.instance.fadeoutSeconds,
      baseDurationSeconds: base,
    );
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
    // ⚠️ AVANT le stop: après, `isPlaying` est faux quoi qu'il arrive, et la
    // file ne saurait plus si elle doit ENCHAÎNER ou seulement s'armer.
    final wasAudible = wasPlaying && isPlaying;
    if (wasPlaying) stop();
    final tookOver = await notifyTrackDeleted(dirPath,
        asPrefix: true, resume: wasAudible);
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
    // ⚠️ Lu AVANT le stop — voir handleDeletedAlbum.
    final wasAudible = wasPlaying && isPlaying;
    // Stop BEFORE the file disappears from under the decoder.
    if (wasPlaying) stop();
    final tookOver = await notifyTrackDeleted(path, resume: wasAudible);
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
    /// GAPLESS ADOPTION: the native engine already switched to this track (a
    /// producer-side handoff whose boundary the listener just crossed). Run
    /// the METADATA half only — title, duration, persistence, media session —
    /// and leave the audio strictly alone: no stop, no load, no play. The
    /// forced-loop snapshot was staged at arm time (armNextTrack) and applied
    /// by the native side just before the handoff's open().
    bool    adoptHandoff     = false,
  }) async {
    // The previous track's play ends here — backfill its real listened time
    // BEFORE _elapsedPlayMs is reset below.
    _flushPlayEventDuration();
    if (!adoptHandoff) audio.stop();
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
    _forcedLoopBaseSecs = baseSecs;
    if (!adoptHandoff) _pushForcedLoopSnapshot();
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
    final bool loaded;
    if (adoptHandoff) {
      // The native side is ALREADY playing this file (the handoff opened it
      // through the same registry cascade a load would have used).
      loaded = true;
    } else {
      // Crash guard ("safe launch"): flag on disk while the native decoder
      // opens the file. Cleared right after — success or clean failure, either
      // way the app survived. If it's still there at the next launch, this load
      // killed the app and the saved queue is not restored.
      QueuePersistence.markLoading(audioPath);
      loaded = audio.loadFile(audioPath);
      QueuePersistence.clearLoading();
    }
    // Either path leaves the boundary counter CONSUMED: a plain load resets
    // the native pipeline, an adoption IS the boundary being handled.
    _lastHandoffSerial = audio.handoffSerial;
    // Et le staging natif est consommé/annulé dans les deux cas — AppShell
    // ré-arme après coup (_onLoadResult → _armNext).
    _nextArmed = false;
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
        // Le TITRE que le FICHIER déclare (GD3 d'un VGM, ID3, Vorbis…) bat un
        // libellé qui n'est que le nom de fichier — « 01 Raizing Logo.vgz »
        // s'appelle « Raizing Logo ». Fichier MONO-piste seulement: les
        // libellés de sous-chansons (« NOM (n) », M3U, NSFe) portent une
        // information que le tag du conteneur n'a pas. C'est aussi ce qui
        // RÉPARE les titres corrompus déjà en base (la ligne réutilisée
        // repassait son libellé tel quel à chaque lecture).
        if (subsongIdx == 0 && (subsongCount ?? 1) <= 1) {
          final t = audio.tagTitle.trim();
          if (t.isNotEmpty) fileName = t;
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
      // L'id de ligne appartient au morceau qu'on QUITTE: tant que
      // `_persistPlay` n'a pas rendu celui du nouveau, personne ne doit écrire
      // dessus. Vaut aussi pour `toggleFavorite`, qui posait sinon le ♥ sur la
      // ligne précédente pendant la même fenêtre.
      _currentTrackId          = null;
      _currentTrackIdPath      = null;
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
      // ⚠️ `audio.play()` n'arrive que bien plus bas, APRÈS des `await`
      // (pochette locale). Sans armement, un tick tombant dans cet intervalle
      // lit « moteur à l'arrêt alors qu'on se croit en lecture » et fait
      // avancer la file. Voir _engineStartPending.
      //
      // ⚠️ SAUF en adoption de relais: là on ne DEMANDE aucun démarrage — le
      // moteur joue déjà la piste, c'est la prémisse même du gapless. Armer y
      // neutralisait la fin de piste pour un morceau que le producteur a pu
      // terminer entre-temps (une sous-chanson `.adl` de 13 ms tient tout
      // entière dans l'avance de 200 ms du tampon), et le lecteur restait 5 s
      // à se croire en lecture avant de s'arrêter SANS avancer la file.
      if (!adoptHandoff) _armEngineStart();
      isSeeking         = false;
      position          = 0;
      elapsedPosition   = 0;
      _elapsedPlayMs    = 0;
      _playClockMs      = 0;
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
      // Pochette d'un fichier LOCAL: résolue EN LIGNE, avant le premier
      // notifyListeners — la découverte n'est qu'un listage de dossier
      // (quelques ms), et la faire APRÈS coup faisait flasher le placeholder
      // à chaque changement de piste avant que la vraie pochette n'arrive
      // (rapporté deux fois sur Battle Garegga; la persistance seule ne
      // suffisait pas: la file en mémoire garde ses artworkUrl d'avant).
      if (artworkUrl == null || artworkUrl.isEmpty) {
        try {
          await _applyLocalArtwork(path, entryPath, subsongIdx);
        } catch (e) {
          debugPrint('local artwork: $e');
        }
      }
      // Fin de piste pour le producteur natif (moteurs sans fin propre —
      // SID/NSF: le gapless et le crossfade en dépendent). La longueur du
      // décodeur prime côté C quand il en a une; re-posée à chaque
      // correction asynchrone (songdb UADE, songlengths SID).
      audio.setTrackEndSeconds(_producerTrackEndSecs);
      if (!adoptHandoff) _playAndConfirmStart();
      notifyListeners();
      _notifyTrackChange();



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
        // fileName, pas label: le titre a pu etre ameliore par le tag du
        // fichier ci-dessus - persister le libelle entrant re-graverait le
        // nom de fichier (ou un titre corrompu) a chaque lecture.
        label:         fileName,
        // Même règle pour l'artiste et l'album: le FICHIER les déclare (GD3
        // d'un VGM, ID3, Vorbis…) et le lecteur les affichait déjà — sans
        // jamais les écrire, `_persistPlay` recevant le paramètre entrant.
        // « Dune » importé localement montrait « Stéphane Picq » pendant
        // l'écoute et rien sous l'album dans les récents (recent_albums.artist
        // vide), alors que le GD3 de chaque .vgz porte l'auteur. Hors
        // catalogue seulement: un morceau du catalogue garde l'artiste du
        // serveur (ids, liens). Et seulement si l'entrant est VIDE: la ligne
        // d'un album importé porte déjà son album (nom de dossier, M3U), et
        // le tag ne doit pas le renommer — deux noms pour un même dossier
        // couperaient l'album en deux.
        artist:        (artist ?? '').isEmpty && (onlineId ?? '').isEmpty
            ? currentArtist
            : artist,
        metaAlbum:     (metaAlbum ?? '').isEmpty && (onlineId ?? '').isEmpty
            ? currentAlbum
            : metaAlbum,
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

  /// Optional system notification on track change (Réglages). Desktop only
  /// (macOS, Linux): Android/iOS already show the track in their media
  /// notification. macOS posts through the AppDelegate channel, Linux through
  /// `org.freedesktop.Notifications` (linux_notifications.dart). Fire-and-forget
  /// — a failed post must never touch playback.
  static const _notifyChannel = MethodChannel('rewamp/notify');
  /// Résout un chemin de FICHIER local pour la pochette de la notification
  /// (posé par initMediaSession — la session média possède déjà la logique
  /// pochette-ou-placeholder-plateforme; le rappel évite un import cyclique).
  /// ASYNCHRONE: la pochette AFFICHÉE arrive après le chargement (téléchargée
  /// dans le dossier de la piste, ou extraite des tags) — résoudre au moment
  /// du load ne donnait que le placeholder.
  static Future<String?> Function()? notificationArtProvider;
  void _notifyTrackChange() {
    if (!(Platform.isMacOS || Platform.isLinux)) return;
    if (!UserSettings.instance.notifyTrackChange) return;
    // Différée: au moment du load, la pochette du morceau n'est le plus
    // souvent PAS ENCORE sur disque (téléchargement / extraction des tags en
    // vol). 1,5 s laisse ces chemins aboutir; la garde d'identité jette la
    // notification si la piste a changé entre-temps (skip rapide).
    final expectPath = filePath;
    final expectSub  = subsongIdx;
    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (filePath != expectPath || subsongIdx != expectSub) return;
      String art = '';
      try {
        art = await notificationArtProvider?.call() ?? '';
      } catch (_) {}
      if (filePath != expectPath || subsongIdx != expectSub) return;
      if (Platform.isLinux) {
        await LinuxTrackNotifier.show(
          title:     displayTitle,
          body:      currentArtist ?? '',
          imagePath: art.isEmpty ? null : art,
        );
        return;
      }
      _notifyChannel.invokeMethod('track', {
        'title':   displayTitle,
        'artist':  currentArtist ?? '',
        'artwork': art,
      }).catchError((_) => null);
    });
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
      audio.setTrackEndSeconds(_producerTrackEndSecs);  // le producteur suit
      notifyListeners();
    } catch (e) {
      debugPrint('uade duration: $e');
    }
  }

  /// Writes the embedded cover picture (if the native tag reader found one)
  /// to the cache and points [artworkUrl] at it. No-op when the file has no
  /// picture. Keyed by audio file path so repeated plays reuse the file.
  /// Découvre la pochette d'un fichier LOCAL (voisin de dossier d'abord,
  /// embarquée ensuite), l'applique ET la grave dans la ligne `tracks` — la
  /// prochaine lecture part avec `artworkUrl` déjà posé, plus de flash.
  Future<void> _applyLocalArtwork(
      String audioPath, String entryPath, int subsongIdx) async {
    final local = await ArtworkCache.instance.findLocalArtwork(audioPath);
    if (local != null) {
      if (filePath == audioPath &&
          (artworkUrl == null || artworkUrl!.isEmpty)) {
        artworkUrl = local;
        notifyListeners();
      }
      // ⚠️ PAS upsertTrack: ses champs null ÉCRASENT titre/artiste/durée —
      // une mise à jour ciblée, COALESCE côté SQL.
      unawaited(LocalDb.instance
          .setTrackArtwork(
            filePath:   audioPath,
            entryPath:  entryPath,
            subsongIdx: subsongIdx,
            artworkUrl: local,
          )
          .catchError((Object _) {}));
      return;
    }
    await _applyEmbeddedArtwork(audioPath);
  }

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
    // ⚠️ Tout ce qui décrit la piste se lit AVANT le premier `await`: cette
    // méthode tourne en arrière-plan et l'utilisateur a pu passer à la piste
    // suivante entre-temps — `backend`, `currentAlbumId`, `currentOnlineId`
    // désignent alors l'AUTRE morceau. Mesuré dans `play_events` du
    // 2026-09-04: des `.vgz` enregistrés « libopenmpt », des `.mid` en
    // « gbsplay », au rythme des sauts de piste.
    final backendNow  = backend;
    final albumIdNow  = currentAlbumId;
    final onlineIdNow = currentOnlineId;
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
    final persistedId = await LocalDb.instance.upsertTrack(
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
    // L'id ET le fichier qu'il décrit, posés ENSEMBLE: c'est l'appariement qui
    // rend l'id inutilisable pour un autre morceau. Si la lecture a déjà changé
    // pendant l'aller-retour SQL, on garde quand même la paire — elle décrit
    // honnêtement une ligne qui existe, et les gardes `== filePath` des
    // appelants feront le tri.
    _currentTrackId     = persistedId;
    _currentTrackIdPath = path;
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
      // `persistedId`, pas `_currentTrackId`: la variable LOCALE désigne la
      // ligne de CETTE passe. Le champ, lui, a pu être repris entre-temps par
      // la persistance d'un morceau suivant — c'est la mécanique même qui a
      // produit les écritures croisées.
      unawaited(LocalDb.instance.setTrackOrigin(persistedId,
          currentCollectionSlug, currentPlatformName, currentYear));
    }

    _playEventId =
        await LocalDb.instance.recordPlay(persistedId, backend: backendNow);
    _pushablePlayEventId = _playEventId;
    // ⚠️ **Un CONTENEUR du catalogue sans album n'est pas un album.** Un
    // fichier multi-sous-chansons (SNDH, SID…) que le catalogue ne rattache à
    // AUCUN album (`albumId` vide) peut arriver ici avec un `metaAlbum` qui
    // n'est que le NOM DU CONTENEUR, posé pour l'affichage par certains
    // dépliages — et seulement sur la sous-chanson LANCÉE, les suivantes de la
    // file n'en portent pas. L'accepter écrivait une entrée ALBUM dans les
    // récents pour la première, pendant que les autres restaient une entrée
    // FICHIER (le masquage de la requête exige un `meta_album`): « Amberstar »
    // sortait DEUX fois. Les récents listent des albums OU des fichiers, et un
    // conteneur est un FICHIER: son entrée porte déjà l'icône multi-pistes et
    // le lien vers ses sous-chansons. Borné aux lignes du CATALOGUE — un album
    // LOCAL (tags, pas d'uuid) de fichiers à sous-chansons reste un album.
    final pseudoContainerAlbum = (albumIdNow ?? '').isEmpty &&
        (onlineIdNow ?? '').isNotEmpty &&
        (count ?? 0) > 1;
    if (recordAsAlbum &&
        metaAlbum != null &&
        metaAlbum.isNotEmpty &&
        !pseudoContainerAlbum) {
      // Album play: the album carries the recents entry, not the track.
      await LocalDb.instance.upsertRecentAlbum(
        metaAlbum,
        path,
        artist:     artist,
        artworkUrl: artworkUrl,
        albumId:    albumIdNow,
        // Identity of the FILE this entry points at, so replaying the album
        // from the recents rail knows what it is playing (a subsong list
        // rebuilt from disk carries none of its own).
        onlineId:   onlineIdNow,
      );
    } else {
      // Recents lists ALBUMS or standalone FILES only: a track of a real
      // (server-id) album played individually refreshes the ALBUM entry —
      // the query hides its per-track row. Pseudo-albums (SID container
      // names, albumId null) stay file entries.
      if (metaAlbum != null &&
          metaAlbum.isNotEmpty &&
          albumIdNow != null &&
          albumIdNow.isNotEmpty) {
        await LocalDb.instance.upsertRecentAlbum(
          metaAlbum,
          path,
          artist:     artist,
          artworkUrl: artworkUrl,
          albumId:    albumIdNow,
          onlineId:   onlineIdNow,
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
    // ⚠️ La garde `forPath` ci-dessus protège le FICHIER; celle-ci protège la
    // LIGNE. Les deux sont nécessaires: entre le début d'un chargement et la
    // fin de `_persistPlay`, `filePath` désigne déjà le nouveau morceau alors
    // que `_currentTrackId` désigne encore l'ancien. Quand l'id n'est pas
    // encore celui de ce fichier on n'écrit RIEN et rien n'est perdu: les
    // champs `current*` viennent d'être posés synchronement, et la remontée
    // d'origine à la fin de `_persistPlay` (gardée sur `path == filePath`) les
    // écrira sur la bonne ligne.
    final trackId = (_currentTrackIdPath != null &&
            _currentTrackIdPath == (forPath ?? filePath))
        ? _currentTrackId
        : null;
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

  /// [guardedRefId] est l'identité rendue par la garde d'ajout
  /// ([ensureLibraryRefForAdd]) quand l'appelant en a passé une: elle peut
  /// différer de [libraryRefId] — un chemin de téléchargement y devient le
  /// songId du catalogue, un fichier jetable le chemin de sa copie importée.
  /// Absente (un un-♥, un appelant sans contexte), on garde [libraryRefId].
  Future<void> toggleFavorite({String? guardedRefId}) async {
    final id = _currentTrackId;
    if (id == null) return;
    isFavorite = !isFavorite;
    notifyListeners();
    await LocalDb.instance.setFavorite(id, value: isFavorite);
    // A favourite is a library item with is_favorite=1 — write it under the SAME
    // subsong-scoped ref_id the library button uses (libraryRefId), else the two
    // disagree (bare online id vs "…?subsong=N") → button stays dark + duplicate
    // library rows. Un-favourite keeps the row (favourite ⊆ library).
    final refId = guardedRefId ?? libraryRefId;
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
    //
    // L'identité envoyée est celle que le LOCAL vient d'écrire — sinon les deux
    // moitiés du geste décrivent deux morceaux: la garde d'ajout peut avoir
    // remplacé un chemin de téléchargement par son songId (le compte veut alors
    // l'uuid, pas un instantané de fichier) ou un chemin jetable par celui de la
    // copie importée (le compte veut alors l'instantané de CETTE copie).
    final refBase = refId == null ? null : splitLibraryRefId(refId).$1;
    final onlineId = refBase != null && !libraryRefIsPath(refBase)
        ? refBase
        : currentOnlineId;
    final localFile =
        refBase != null && libraryRefIsPath(refBase) ? refBase : filePath;
    if (onlineId != null) {
      await SyncService.recordLibraryChange(
        itemType:   'song',
        itemId:     onlineId,
        // Le ♥, pas l'appartenance (migration serveur 206): un ♥ pose l'entrée
        // en bibliothèque côté serveur, un un-♥ l'y laisse. Avant, un un-♥
        // partait en `p_value: false` et RETIRAIT le morceau de la
        // bibliothèque.
        value:      isFavorite,
        favourite:  isFavorite,
        subsongIdx: subsongIdx,
      );
    } else if (localFile != null) {
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
        fileName:   localFile.split(Platform.pathSeparator).last,
        relPath:    await LocalDb.instance.relPathOf(localFile),
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
    // Garde client: on n'envoie pas une lecture trop courte. Le MÊME seuil
    // sert au comptage LOCAL des stats (LocalDb.kCountedPlayMinMs) — s'ils
    // divergent, le rail « Vos tendances » et l'écran Stats affichent deux
    // nombres pour la même chose, ce qui est arrivé (74 contre 24).
    if (_elapsedPlayMs < LocalDb.kCountedPlayMinMs) return;
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
      _disarmEngineStart();
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
        _armEngineStart();
        // ⚠️ Le drapeau est en AVANCE sur le moteur, et c'est la SEULE
        // transition dans ce sens: pause/stop/loadFile posent `isPlaying`
        // AVANT d'arrêter le moteur, et toute la détection de fin de piste
        // repose là-dessus (« `!audio.isPlaying` alors qu'on se croit en
        // lecture » = la piste s'est terminée seule). Ici, entre l'appui et le
        // `audio.play()` d'après la porte ASYNCHRONE, l'état est exactement
        // celui d'une piste finie — et un tick qui tombe dans cette fenêtre
        // faisait avancer la file (chemin générique) ou relançait le morceau
        // depuis zéro (boucle forcée). Vu de l'utilisateur: on appuie sur le
        // bouton lecture/pause et c'est « suivant » ou « précédent » qui part,
        // au hasard. `_engineStartPending` neutralise les deux détections le
        // temps que le moteur démarre pour de bon.
        gate().catchError((_) {}).whenComplete(() {
          // Le drapeau n'est PAS désarmé ici: `audio.play()` peut très bien
          // ne rien démarrer (rien de chargé côté natif). Seul le moteur qui
          // se déclare en lecture le désarme, dans le tick.
          if (isPlaying) {
            _playAndConfirmStart();
          } else {
            _disarmEngineStart();
          }
        });
        notifyListeners();
        return;
      }
      isPlaying = true;
      _armEngineStart();
      _playAndConfirmStart();
    }
    notifyListeners();
  }

  /// Vrai entre le moment où `isPlaying` passe à vrai et le démarrage EFFECTIF
  /// du moteur.
  ///
  /// Pendant ce temps `isPlaying` est vrai et `audio.isPlaying` est faux —
  /// l'exacte signature d'une piste qui vient de se terminer. Tout test de fin
  /// de piste doit donc l'écarter.
  ///
  /// ⚠️ Cette fenêtre a TROIS formes, et n'en couvrir qu'une laissait le bug
  /// entier: la porte asynchrone de [ensureAudioSession] (iOS, Android **et
  /// macOS**), le `audio.play()` qui ÉCHOUE parce que le natif n'a rien de
  /// chargé (`REWAMP_ERROR_NO_SOUND` — un appui sur lecture pendant qu'un
  /// chargement est en vol), et surtout le chargement lui-même: [loadFile]
  /// pose `isPlaying = true` bien AVANT son `audio.play()`, avec des `await`
  /// entre les deux. Mesuré sur macOS: en martelant lecture/pause au début
  /// d'un morceau, le tick de 250 ms tombait dans l'une de ces fenêtres,
  /// concluait « la piste s'est terminée seule » et faisait avancer la file —
  /// vu de l'utilisateur, le bouton pause déclenche « suivant ».
  ///
  /// D'où un drapeau ARMÉ à chaque pose optimiste et désarmé par le MOTEUR
  /// (le tick le voit démarrer), jamais par le code qui a demandé le démarrage.
  bool _engineStartPending = false;
  int  _engineStartArmedMs = 0;

  /// Au-delà, le moteur ne démarrera plus: on rend l'affichage HONNÊTE
  /// (`isPlaying = false`) plutôt que de laisser un lecteur qui se dit en
  /// lecture sans un son — et surtout sans jamais faire avancer la file, ce
  /// qui est exactement ce qu'on cherche à empêcher ici. Se répare tout seul
  /// si le moteur démarre plus tard (le tick recopie alors son état).
  static const int _kEngineStartTimeoutMs = 5000;

  void _armEngineStart() {
    _engineStartPending = true;
    _engineStartArmedMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _disarmEngineStart() => _engineStartPending = false;

  /// Démarre le moteur, puis lui DEMANDE aussitôt s'il tourne.
  ///
  /// ⚠️ Le désarmement ne pouvait pas attendre le tick. [_engineStartPending]
  /// n'est levé que par le MOTEUR, et son SEUL observateur était le tick de
  /// 250 ms: une piste plus COURTE que ça démarrait et se terminait entre deux
  /// ticks, sans qu'aucun ne voie jamais `audio.isPlaying` vrai. Le drapeau
  /// restait donc armé, la détection de fin de piste restait neutralisée, et au
  /// bout de 5 s le lecteur se déclarait à l'arrêt **sans avancer la file** —
  /// vu de l'utilisateur, la lecture s'arrête et il faut la relancer à la main.
  ///
  /// Ce n'est pas un cas de laboratoire: un `.adl` Westwood en fait la règle.
  /// Mesuré avec `songlength()` d'AdPlug — « eob2 - catacomb »: 28 de ses 120
  /// sous-chansons durent moins de 250 ms, la plus courte **13 ms**; DUNE19.ADL
  /// en a 10, LOREINTR.ADL 13. Une série de bruitages courts arrêtait donc la
  /// file à coup sûr.
  ///
  /// ⚠️ Ce n'est PAS un désarmement à l'aveugle, et l'invariant tient: côté C,
  /// `ma_sound_start` a déjà posé l'état quand `rewamp_play` rend la main, donc
  /// `audio.isPlaying` juste après est la réponse du MOTEUR et non une
  /// supposition de l'appelant. Un `play()` qui n'a rien démarré (rien de
  /// chargé côté natif, `REWAMP_ERROR_NO_SOUND`) répond faux et le drapeau
  /// reste armé — ce qui est exactement son rôle.
  void _playAndConfirmStart() {
    audio.play();
    if (audio.isPlaying) _disarmEngineStart();
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
    _disarmEngineStart();
    position   = 0;
    elapsedPosition = 0;
    _playClockMs = 0;
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
      _playClockMs     = (seconds * 1000).round();
      _forceSeekOffset = seconds - within;   // completed-passes offset
      audio.seek(within);
      audio.resetSilence();   // fresh decode position → don't trip restart-on-silence
      isSeeking = true;       // animate progress via the tick() polling below
      position  = seconds;
      elapsedPosition = seconds;
      notifyListeners();
      return;
    }
    // rewamp_seek_seconds() cancels any previous seek and starts a new one.
    audio.seek(seconds);
    isSeeking = true;
    // Le compteur de gauche doit se caler sur la CIBLE. `_elapsedPlayMs` reste
    // intact: sauter en avant n'a rien fait écouter de plus.
    _playClockMs = (seconds * 1000).round();
    position  = seconds;
    elapsedPosition = seconds;
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

  /// Fin de piste à armer sur le PRODUCTEUR natif — 0 = « pas de fin connue ».
  ///
  /// ⚠️ **En boucle INFINIE, la piste n'a pas de fin, et le producteur doit le
  /// savoir.** La règle « en infini la durée nominale n'est JAMAIS consultée »
  /// était appliquée côté Dart mais pas transmise ici: on armait quand même la
  /// durée d'UNE passe, donc le producteur coupait le morceau juste avant que
  /// le moteur n'atteigne son point de boucle. La piste « se terminait », et
  /// repeat-morceau la rechargeait depuis zéro — au lieu de la laisser boucler
  /// là où le fichier le demande. Mesuré sur un VGM: en mode 1 avec un grand
  /// nombre de passes la durée armée vaut base×(n+1) et tout fonctionne, ce qui
  /// isolait la fin de piste comme seule différence.
  double get _producerTrackEndSecs =>
      effectiveForceLoopMode == 'infinite' ? 0 : (_knownDuration ?? 0);

  /// Override the displayed duration (e.g. from HVSC songlength database).
  /// Pass null to revert to the audio engine's own reported length. The value
  /// is a SINGLE-pass length; a generic forced loop expands it to base×passes.
  void setKnownDuration(double? seconds) {
    _forceBaseSecs = (seconds != null && seconds > 0) ? seconds : null;
    _knownDuration = _displayedDurationFor(seconds);
    duration = _knownDuration ?? audio.durationSeconds;
    audio.setTrackEndSeconds(_producerTrackEndSecs);  // le producteur suit
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

  /// GAPLESS: called when the listener audibly crossed into the track staged
  /// by [armNextTrack] (the native producer switched decoders earlier, at the
  /// look-ahead's depth — the flip waits for the EAR). AppShell advances the
  /// queue pointer and adopts the track's metadata WITHOUT reloading.
  VoidCallback? onTrackHandoff;
  int _lastHandoffSerial = 0;

  /// Called after [cycleLoopMode] — the staged next track's loop snapshot
  /// depends on the transport mode, so AppShell re-arms.
  VoidCallback? onLoopModeChanged;

  /// GAPLESS: stage [path] as the track the native engine opens the instant
  /// the current one ends — same ring, no audible break. Carries the same
  /// per-track forced-loop snapshot a plain load would have applied.
  ///
  /// Declines (clears instead) when the handoff cannot work:
  ///  - repeat-track: the engine loops forever, there is no end to hand off;
  ///  - the CURRENT track runs the GENERIC forced loop (non-native): its
  ///    restart machinery replays the decoder after EOF, and a staged next
  ///    would hijack that first EOF and kill the loop.
  /// Un suivant est ARMÉ côté natif: la fin de la piste courante appartient
  /// alors au producteur (relais/crossfade), et le filet Dart de fin-à-durée
  /// prend 2 s de marge au lieu de couper pile — sans ça il tuerait le
  /// relais qu'il est censé doubler.
  bool _nextArmed = false;

  void armNextTrack({required String path,
                     int subsongIdx = 0,
                     double? durationS}) {
    if (!audio.supportsGapless) return;
    final mode = effectiveForceLoopMode;
    if (mode == 'infinite' || _forceLoopActive) {
      audio.clearNextFile();
      _nextArmed = false;
      return;
    }
    _nextArmed = true;
    final baseSecs = (durationS != null && durationS > 0)
        ? durationS
        : UserSettings.instance.defaultTrackLengthSeconds;
    final audioPath = subsongIdx > 0 ? '$path?subsong=$subsongIdx' : path;
    audio.setNextFile(
      audioPath,
      mode == 'on' ? 1 : 0,
      UserSettings.instance.loopCount,
      fadeoutEnabled: UserSettings.instance.forceFadeoutEnabled,
      fadeoutSeconds: UserSettings.instance.fadeoutSeconds,
      baseDurationSeconds: baseSecs,
    );
  }

  void clearNextTrack() {
    audio.clearNextFile();
    _nextArmed = false;
  }

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
    elapsedPosition       = 0;
    _playClockMs          = 0;
    isPlaying             = false;
    _disarmEngineStart();
    primed                = true;
    notifyListeners();
  }

  /// Called by AppShell's periodic timer to refresh position.
  void tick() {
    if (!hasFile) return;

    // GAPLESS: has the listener crossed a staged track boundary since the
    // last tick? The serial only moves when the CONSUMER heard the switch —
    // the handler adopts metadata/queue state without touching the audio.
    if (audio.supportsGapless) {
      final hs = audio.handoffSerial;
      if (hs != _lastHandoffSerial) {
        _lastHandoffSerial = hs;
        onTrackHandoff?.call();
      }
    }

    // While a fast-forward seek is running, poll C-side progress so the slider
    // animates.  Transition isSeeking→false when the audio thread finishes.
    if (isSeeking) {
      final seeking = audio.isSeeking();
      final prog    = audio.seekProgressSeconds();
      final d       = _knownDuration ?? audio.durationSeconds;
      // Under a forced loop the C seek runs on the single-pass timeline; shift
      // its progress onto the base×passes slider by the completed-passes offset.
      final isForce = _forceLoopActive;
      // Sous boucle infinie le seek du C court sur la timeline d'UNE passe: sa
      // progression ne dit rien du temps écoulé. L'horloge d'affichage, elle,
      // a été recalée sur la cible par `seek()` et n'avance pas pendant le
      // seek — c'est elle qui fait autorité sur le compteur de gauche.
      final infinite = effectiveForceLoopMode == 'infinite';
      if (!seeking) {
        isSeeking = false;
        // Snap to the real cursor once done — elapsed target for a forced loop,
        // the decoder cursor otherwise.
        final p = isForce ? (_elapsedPlayMs / 1000.0) : audio.positionSeconds;
        final e = infinite ? (_playClockMs / 1000.0) : p;
        if (p != position || e != elapsedPosition || d != duration) {
          position = p;
          elapsedPosition = e;
          duration = d;
          notifyListeners();
        } else {
          notifyListeners();
        }
      } else {
        final disp = isForce ? (_forceSeekOffset + prog) : prog;
        final e    = infinite ? (_playClockMs / 1000.0) : disp;
        if (disp != position || e != elapsedPosition) {
          position = disp;
          elapsedPosition = e;
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
      _playClockMs   += nowMs - _lastTickMs;
    }
    _lastTickMs = nowMs;

    // Le moteur est le SEUL à pouvoir désarmer une pose optimiste de
    // `isPlaying`: tant qu'il ne se déclare pas en lecture, l'état est celui
    // d'une piste finie et toute détection de fin doit rester neutralisée.
    // Passé le délai, le démarrage n'aura pas lieu (rien de chargé, périphérique
    // en échec): on rend l'affichage honnête SANS avancer la file.
    if (_engineStartPending) {
      if (audio.isPlaying) {
        _disarmEngineStart();
      } else if (nowMs - _engineStartArmedMs > _kEngineStartTimeoutMs) {
        _disarmEngineStart();
        isPlaying = false;
        notifyListeners();
        return;
      }
    }

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
    // Avec un suivant armé, la fin appartient au PRODUCTEUR natif (relais ou
    // crossfade à la même durée): couper ici pile à la durée tuerait le
    // relais. 2 s de marge — si le natif n'a pas relayé d'ici là (échec
    // d'open, format sans fin connue de son côté), le filet reprend.
    // ⚠️ **Sous boucle INFINIE, la durée nominale ne coupe RIEN.** La règle
    // était écrite pour la branche générique (« en infini on ne consulte
    // jamais la durée nominale ») mais ce filet-ci, qui sert la boucle NATIVE,
    // la consultait quand même: à 2:30 il appelait `audio.stop()`, la piste
    // passait pour terminée et repeat-morceau la rechargeait depuis zéro —
    // juste avant que le moteur n'atteigne son point de boucle. Mesuré sur un
    // VGM: avec un nombre de passes FIXE la durée vaut base×(n+1) et rien ne
    // se déclenche, ce qui isolait ce test comme seule différence.
    //
    // Un moteur en boucle infinie native n'a pas de fin à faire respecter:
    // c'est lui qui décide où et quand reboucler.
    final endSlack = _nextArmed ? 2.0 : 0.0;
    final reachedKnownEnd = effectiveForceLoopMode != 'infinite' &&
        _knownDuration != null && _knownDuration! > 0 &&
        p >= _knownDuration! + endSlack && audio.isPlaying;
    if (reachedKnownEnd) {
      logTransport('fin forcée', source: 'durée connue atteinte',
          detail: 'pos=${p.toStringAsFixed(1)}s durée=${_knownDuration!.toStringAsFixed(1)}s');
      audio.stop();
    }

    final pl = audio.isPlaying;
    final naturalEnd = engineStoppedByItself(
      enginePlaying:      pl,
      uiPlaying:          isPlaying,
      engineStartPending: _engineStartPending,
    );

    // Natural end-of-track: audio stopped on its own.
    // stop(), pause() and loadFile() all update `isPlaying` before this tick
    // runs (Dart is single-threaded), so they never trigger this branch.
    if (naturalEnd) {
      // ⚠️ LE suspect quand « pause » enchaîne sur la piste suivante: personne
      // n'a rien demandé, c'est cette conclusion-là qui avance la file. Les
      // trois états qui la décident sont donc dans la ligne — l'interface se
      // croyait en lecture, le moteur ne jouait pas, et aucun démarrage
      // n'était en attente (voir engineStoppedByItself).
      logTransport('fin de piste', source: 'auto (moteur arrêté seul)',
          detail: 'moteur=$pl ui=$isPlaying démarrageEnAttente=$_engineStartPending '
              'pos=${p.toStringAsFixed(1)}s');
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
      logTransport('fin de piste', source: 'auto (silence)',
          detail: 'silence=${audio.silentSeconds.toStringAsFixed(1)}s '
              'seuil=${UserSettings.instance.silenceSkipSeconds}s');
      audio.resetSilence();
      _maybeFireLogPlay(forceEnd: true);
      onTrackEnded?.call();
    }
    _maybeFireLogPlay();

    // Boucle infinie NATIVE (libvgm, vgmstream, libopenmpt): le moteur annonce
    // la durée d'UNE passe et notre curseur, lui, est le nombre d'images
    // LIVRÉES — monotone à travers les boucles. On ramène donc la position
    // dans la passe plutôt que d'allonger le total: la règle graduée reste
    // celle du fichier, et un seek vise toujours un point que le décodeur sait
    // atteindre. Voir infiniteDisplayPosition.
    final infinite = effectiveForceLoopMode == 'infinite';
    final pShown = infinite
        ? infiniteDisplayPosition(p, _forceBaseSecs ?? (d > 0 ? d : null))
        : p;
    // Le temps ÉCOULÉ, lui, ne sature pas. Sous boucle infinie il ne peut pas
    // venir du curseur du moteur: celui de libvgm est monotone à travers les
    // passes, mais celui de libopenmpt REBOUCLE (c'est déjà pourquoi le total
    // natif ne s'allonge que quand la position dépasse le total) — le compteur
    // retomberait à zéro à chaque passe. On prend donc l'horloge d'affichage,
    // qui répond exactement à la question posée: depuis combien de temps ça
    // joue. Elle est RECALÉE par un seek et remise à zéro au chargement, donc
    // elle suit aussi les sauts — c'est ce qui la distingue de
    // `_elapsedPlayMs`, que le seek ne doit PAS toucher.
    final elapsedShown = infinite ? (_playClockMs / 1000.0) : p;
    final dShown = d;
    // Le moteur fait autorité sur `isPlaying` — SAUF pendant une reprise en
    // vol, où le drapeau est volontairement en avance sur lui. Le recopier là
    // le remettrait à faux, et c'est précisément ce que teste le
    // `whenComplete` de togglePlay: la reprise n'aurait alors jamais lieu et
    // l'appui sur lecture ne ferait RIEN.
    final plShown = _engineStartPending ? isPlaying : pl;
    // `pShown` est FIGÉ dès la première passe en boucle infinie — sans le test
    // sur `elapsedPosition`, plus aucune notification ne partait et le compteur
    // de gauche gelait avec la barre.
    if (pShown != position ||
        elapsedShown != elapsedPosition ||
        dShown != duration ||
        plShown != isPlaying) {
      position  = pShown;
      elapsedPosition = elapsedShown;
      duration  = dShown;
      isPlaying = plShown;
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
  /// Relances consécutives qui n'ont PAS réveillé le moteur.
  ///
  /// Le repli générique relance par `seek(0)` + `play()`, ce qui suppose qu'un
  /// décodeur TERMINÉ redevienne vivant après un seek. Trois bibliothèques ont
  /// déjà démenti cette supposition — vgmstream (`decode_done` jamais effacé),
  /// furnace (`seek` ne rallume pas le moteur), zxtune (`LOOPED` qui reboucle
  /// sur du vide) — et il y a 39 greffons. Plutôt que de les auditer un par un,
  /// on garde un filet: au bout de deux relances sans effet, on RECHARGE le
  /// fichier, ce qu'aucun état interne de décodeur ne peut refuser.
  ///
  /// Le compteur est remis à zéro dès que le moteur repart, donc un greffon
  /// sain n'atteint jamais le rechargement.
  int _loopRestartsFailed = 0;

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
    final engineStopped = engineStoppedByItself(
          enginePlaying:      audio.isPlaying,
          uiPlaying:          isPlaying,
          engineStartPending: _engineStartPending,
        ) &&
        _elapsedPlayMs > _kForceLoopStartGraceMs;
    final silentLongEnough =
        audio.isPlaying && audio.silentSeconds >= _kForceLoopRestartSilence;
    final stalled = isPlaying &&
        (engineStopped ||
            (silentLongEnough &&
                silenceCanMeanEnd(
                  decoderPositionSeconds: audio.positionSeconds,
                  nominalSeconds: _forceBaseSecs,
                )));

    void restartIfStalled() {
      if (!stalled) return;
      if (nowMs - _lastLoopRestartMs < _kForceLoopRestartCooldownMs) return;
      _lastLoopRestartMs = nowMs;
      // Le moteur est-il reparti depuis la relance précédente ? Si oui, le
      // greffon sait revivre et le filet reste au repos.
      if (engineStopped) {
        _loopRestartsFailed++;
      } else {
        _loopRestartsFailed = 0;
      }
      if (_loopRestartsFailed > 2) {
        // Deux relances sans effet: ce décodeur ne revient pas d'un seek.
        // Le rechargement, lui, repart d'un `open()` neuf.
        _loopRestartsFailed = 0;
        unawaited(replayCurrent());
        return;
      }
      audio.seek(0);
      audio.resetSilence();
      // Un seek seul ne relance pas un son TERMINÉ — miniaudio l'a démonté.
      if (engineStopped) audio.play();
    }

    if (mode == 'infinite') {
      restartIfStalled();
      final total = _forceBaseSecs ?? duration;
      final shown = infiniteDisplayPosition(elapsed, _forceBaseSecs);
      // La barre sature, le compteur continue: c'est `elapsed` qui monte.
      if (shown != position ||
          elapsed != elapsedPosition ||
          total != duration) {
        position = shown;
        elapsedPosition = elapsed;
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
      elapsedPosition = elapsed;
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
    _disarmEngineStart();
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
  /// Renomme les entrées de file qui jouent [filePath], par SOUS-CHANSON.
  ///
  /// ⚠️ Deux bugs vécus, tous deux dans l'ancienne signature `Map<int,String>`
  /// indexée par POSITION:
  ///
  /// 1. Elle supposait « position = index de sous-chanson », vrai seulement
  ///    quand la file est le dépliage d'UN conteneur. Lancer un morceau depuis
  ///    le rail « Vos tendances » donne une file de morceaux SANS RAPPORT: STIL
  ///    nomme la sous-chanson 0 « Space Game », et c'était l'entrée 0 de la
  ///    file qui était renommée — « Panic », un .s3m de Purple Motion.
  /// 2. Elle reconstruisait l'entrée avec DEUX champs sur dix: pochette,
  ///    sous-titre, album et `id` partaient à la poubelle. Un `id` nul casse
  ///    les clés de widget du panneau (voir [QueueEntry.id]) — donc renommer
  ///    une ligne pouvait rendre à une autre l'état d'un glissement en cours.
  ///    D'où `copyWith`, même patron et même raison que `TrackRecord.copyWith`.
  void updateQueueEntries(String filePath, Map<int, String> subsongToTitle) {
    final next = applyQueueTitles(_queue, filePath, subsongToTitle);
    for (var i = 0; i < _queue.length; i++) {
      if (!identical(next[i], _queue[i])) {
        _queue = next;
        notifyListeners();
        return;
      }
    }
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
  /// [resume] = la lecture était EN COURS quand la suppression est arrivée.
  /// Supprimer un fichier n'est pas « joue le suivant »: à l'arrêt ou en pause,
  /// la file prend la place libérée sans rien lancer.
  Future<bool> Function(String path, {bool asPrefix, bool resume})?
      onTrackDeleted;
  Future<bool> notifyTrackDeleted(String path,
          {bool asPrefix = false, bool resume = true}) async =>
      await onTrackDeleted?.call(path, asPrefix: asPrefix, resume: resume) ??
          false;

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
    // Le moteur voit le nouveau mode TOUT DE SUITE (fondu PSF, voir
    // _pushForcedLoopSnapshot) — le setter ci-dessus notifie UserSettings,
    // dont on est déjà auditeur, mais l'ordre des auditeurs n'est pas un
    // contrat: on pousse explicitement.
    _pushForcedLoopSnapshot();
    if (wasLooping && effectiveForceLoopMode == 'off') _endLoopedPlayback();
    onLoopModeChanged?.call();  // gapless: the staged next track must re-arm
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
