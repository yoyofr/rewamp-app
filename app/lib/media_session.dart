import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show MethodChannel, rootBundle;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'artwork_image.dart' show ArtworkCache;
import 'platform_artwork.dart'
    show allSoundPlatforms, platformAssetFor, platformAssetForPlatform;
import 'player_controller.dart';
import 'transport_log.dart';

/// System media-session bridge (lock screen / Control Center / artwork / remote
/// commands). Playback stays in the C/miniaudio engine — this handler does NOT
/// play anything; it mirrors [PlayerController] state into the OS media session
/// and forwards remote commands back to the controller.
///
/// Supported by audio_service on iOS, Android and macOS, and on LINUX through
/// `audio_service_mpris` (MPRIS over D-Bus: GNOME's top-bar player, KDE's tray,
/// the keyboard media keys). No-op on Windows (SMTC — not done).
///
/// ⚠️ Linux: `audio_session` n'y a AUCUNE implémentation — ses appels lèvent
/// MissingPluginException. Le bloc de session audio est donc sauté, et surtout
/// `ensureAudioSession` n'est PAS posé: il est appelé à CHAQUE lecture.
RewampAudioHandler? gMediaHandler;
bool _mediaInited = false;

Future<void> initMediaSession(PlayerController c) async {
  // Pochette des notifications système macOS — voir notificationArtFor.
  PlayerController.notificationArtProvider =
      () => RewampAudioHandler.notificationArtFor(c);
  if (_mediaInited) return;
  if (!(Platform.isIOS || Platform.isAndroid || Platform.isMacOS ||
      Platform.isLinux)) {
    return;
  }
  _mediaInited = true;
  if (!Platform.isLinux) await _configureAudioSession(c);

  try {
    gMediaHandler = await AudioService.init(
      builder: () => RewampAudioHandler(c),
      config: AudioServiceConfig(
        // ⚠️ Sur Linux, `audio_service_mpris` DÉRIVE de ces deux champs
        // « android » le nom sur le bus
        // (`org.mpris.MediaPlayer2.<channelId>.instance<pid>`) et l'IDENTITÉ
        // affichée par le bureau. Le nom du canal vaut « Playback » — c'est
        // ce qu'Android montre dans ses réglages, on n'y touche pas — donc
        // GNOME aurait présenté le lecteur comme « Playback ». D'où « Rewamp »
        // sur Linux seulement. Le channelId, lui, ne change pas: le manifeste
        // flatpak autorise précisément ce nom.
        androidNotificationChannelId: 'com.rewamp.app.audio',
        androidNotificationChannelName:
            Platform.isLinux ? 'Rewamp' : 'Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        artDownscaleWidth: 320,
        artDownscaleHeight: 320,
      ),
    );
  } catch (e, s) {
    debugPrint('[media] AudioService.init failed: $e\n$s');
  }
  await _armAppleCommandCenter(c);

  // Android 13+ (API 33): the media-playback notification — the ONLY place the
  // lock-screen / shade transport controls live — is silently dropped unless
  // POST_NOTIFICATIONS is granted, even though the foreground service runs and
  // audio plays. Ask once. iOS/macOS have no equivalent gate.
  if (Platform.isAndroid) {
    await Permission.notification.request();
  }
}

/// La session audio de la plateforme (iOS/Android/macOS — PAS Linux).
Future<void> _configureAudioSession(PlayerController c) async {

  // Configure the platform audio session for music playback. miniaudio (the C
  // engine doing the actual output) is not audio_session-aware, so we set the
  // playback category explicitly here; combined with UIBackgroundModes=audio on
  // iOS this is what lets audio keep playing in the background.
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  // Interruptions (another app grabs the output — Spotify, a call): the system
  // stops our audio unit WITHOUT telling the engine, so the app kept showing
  // the pause glyph over dead audio, and play didn't restart (session
  // deactivated). Mirror the interruption into the controller (honest UI) and
  // resume only when the system says so.
  var pausedByInterruption = false;
  session.interruptionEventStream.listen((event) {
    if (event.begin) {
      if (c.isPlaying) {
        pausedByInterruption = true;
        logTransport('pause', source: 'interruption système');
        c.togglePlay(); // engine device is already stopped; state follows
      }
    } else if (pausedByInterruption) {
      pausedByInterruption = false;
      // type == pause means the system wants us to resume (transient
      // interruption, e.g. a call that ended). Anything else (another player
      // took over for good): stay paused — the user decides, and togglePlay's
      // ensureAudioSession gate reactivates the session when they do.
      if (event.type == AudioInterruptionType.pause && !c.isPlaying) {
        logTransport('lecture', source: 'fin d\'interruption système');
        c.togglePlay();
      }
    }
  });
  // Resume gate: reactivate the (possibly deactivated) session before the
  // engine restarts its device — see PlayerController.togglePlay.
  c.ensureAudioSession = () => session.setActive(true).then((_) {});
}

/// L'armement du centre de commandes Apple — voir le commentaire ci-dessous.
Future<void> _armAppleCommandCenter(PlayerController c) async {

  // Apple: the media keys (and the lock screen / Control Center) only reach an
  // app that has registered MPRemoteCommandCenter handlers — and audio_service
  // registers them LAZILY, the first time it is told we are playing:
  //
  //   if (playing && !commandCenter) { ... [self activateCommandCenter]; }
  //   [self updateControls];                // early-returns while it is nil
  //
  // So a freshly launched app showing a restored track ignored the keyboard's
  // play key until the in-app play button had been pressed once. Announce one
  // "playing" state and correct it immediately: the command centre is a static
  // that is never torn down afterwards, so a single flip arms it for good.
  // Android is deliberately excluded — there "playing" is what starts the
  // foreground service, and this would raise a playback notification at launch.
  //
  // ⚠️ **La correction part dans un TOUR DE BOUCLE DISTINCT**, et c'est ce qui
  // manquait: enchaînés dans la même passe, les deux états laissaient l'écran
  // verrouillé d'iOS sur « en lecture » — glyphe PAUSE au lancement, sans
  // qu'aucun morceau ne joue. Le plugin ne pose `MPNowPlayingInfoCenter
  // .playbackState` que sur macOS (`#if TARGET_OS_OSX`): sur iOS l'état est
  // DÉDUIT de `MPNowPlayingInfoPropertyPlaybackRate`, et le centre
  // d'informations ne retenait que le premier des deux envois.
  //
  // ⚠️ Et la correction demande l'état RÉEL au moment où elle part: entre les
  // deux, l'utilisateur a pu appuyer sur lecture — écrire « à l'arrêt » en dur
  // éteindrait alors une lecture bien réelle dans le centre de commandes.
  final handler = gMediaHandler;
  if (handler != null && (Platform.isMacOS || Platform.isIOS)) {
    handler.playbackState
        .add(handler.playbackState.value.copyWith(playing: true));
    Future.delayed(const Duration(milliseconds: 250), () {
      handler.playbackState
          .add(handler.playbackState.value.copyWith(playing: c.isPlaying));
      // …et on DIT l'état à iOS, EN FORÇANT: l'armement vient d'écrire le
      // dictionnaire Now Playing avec un « en lecture », et c'est seulement
      // maintenant que la propriété a un dictionnaire sur quoi mordre.
      unawaited(_pushIosPlaybackState(c.isPlaying, force: true));
    });
  }

}

/// `MPNowPlayingInfoCenter.playbackState` — l'état que le plugin ne pose PAS
/// sur iOS (`#if TARGET_OS_OSX` dans son AudioServicePlugin.m, il n'y écrit que
/// le `PlaybackRate`).
///
/// C'est pourtant lui qui décide du glyphe de l'écran verrouillé pour une app
/// qui ne joue pas par AVPlayer: sans lui, iOS tient l'app pour « en lecture »
/// dès que le dictionnaire d'informations est renseigné — au lancement, la
/// piste restaurée affichait donc PAUSE alors que rien ne jouait, et aucun
/// état publié ensuite ne le corrigeait (le natif ne réécrit le dictionnaire
/// que si `playing`/`speed`/`position` CHANGENT, or ils ne bougeaient plus).
const _nowPlayingChannel = MethodChannel('rewamp/now_playing');

/// Dernier état POUSSÉ. Le tick du lecteur notifie quatre fois par seconde:
/// sans ce garde-fou, on traverserait le canal pour rien.
bool? _lastPushedPlaying;

/// [force] traverse le garde-fou. Il le FAUT après tout écrit du plugin dans
/// `nowPlayingInfo`, et c'est ce qui manquait: au lancement l'ordre est
///
///   1. `_sync` pousse « à l'arrêt » — le dictionnaire n'existe pas encore;
///   2. l'armement annonce « en lecture » → le plugin ÉCRIT le dictionnaire,
///      l'app devient l'app Now Playing, l'écran verrouillé montre PAUSE;
///   3. la correction repasse « à l'arrêt »… et le garde-fou la JETAIT, parce
///      que la dernière valeur poussée était déjà `false`.
///
/// Résultat: le seul moment où la propriété comptait — après que le
/// dictionnaire existe — était précisément celui qu'on sautait.
Future<void> _pushIosPlaybackState(bool playing, {bool force = false}) async {
  if (!Platform.isIOS) return;
  if (!force && _lastPushedPlaying == playing) return;
  try {
    await _nowPlayingChannel
        .invokeMethod<void>('setPlaybackState', {'playing': playing});
    debugPrint('[media] iOS playbackState ← ${playing ? "playing" : "paused"}'
        '${force ? " (forcé)" : ""}');
    // Mémorisé APRÈS coup, jamais avant: le tout premier appel peut partir
    // avant que le canal natif existe, et retenir une valeur qui n'est pas
    // passée bloquerait tous les envois suivants (le tick republie le MÊME
    // état, il serait filtré pour toujours).
    _lastPushedPlaying = playing;
  } catch (e) {
    // Binaire plus ancien que ce canal: on retombe sur le comportement du
    // plugin (le rate seul), qui est ce qu'on avait avant.
    debugPrint('[media] setPlaybackState refusé: $e');
  }
}

class RewampAudioHandler extends BaseAudioHandler {
  final PlayerController c;
  String? _lastMediaKey;

  RewampAudioHandler(this.c) {
    c.addListener(_sync);
    _warmupPlaceholders();
    _sync();
  }

  void _sync() {
    // Publish a new MediaItem only when the track identity/metadata changes —
    // re-emitting every 250 ms tick would thrash artwork loading.
    final key = '${c.filePath}|${c.subsongIdx}|${c.fileName}|'
        '${c.currentArtist}|${c.currentAlbum}|${c.duration}|${c.artworkUrl}|'
        '${c.currentPlatformName}|${c.currentFormatExt}';
    if (key != _lastMediaKey) {
      _lastMediaKey = key;
      // Le plugin RÉÉCRIT `nowPlayingInfo` à chaque `setMediaItem`: on
      // ré-affirme l'état APRÈS, sans quoi une piste publiée à l'arrêt (une
      // reprise de session, un saut sans lecture) laisse l'écran verrouillé
      // sur ce que le système déduit d'un dictionnaire tout neuf.
      unawaited(Future<void>.delayed(const Duration(milliseconds: 120),
          () => _pushIosPlaybackState(c.isPlaying, force: true)));
      if (c.hasFile) {
        mediaItem.add(MediaItem(
          id: c.currentOnlineId ?? c.filePath ?? c.fileName,
          title: c.fileName.isNotEmpty ? c.fileName : 'Unknown',
          artist: c.currentArtist,
          album: c.currentAlbum,
          duration: c.duration > 0
              ? Duration(milliseconds: (c.duration * 1000).round())
              : null,
          artUri: _artUri(),
        ));
      } else {
        mediaItem.add(null);
      }
    }

    playbackState.add(playbackState.value.copyWith(
      controls: [
        if (c.canGoPrev) MediaControl.skipToPrevious,
        if (c.isPlaying) MediaControl.pause else MediaControl.play,
        if (c.canGoNext) MediaControl.skipToNext,
        MediaControl.stop,
      ],
      // The Android system media panel (Quick Settings / output switcher) reads
      // the MediaSession's ACTION set, NOT the notification `controls`. Without
      // the transport actions here it greys prev/next and doesn't reflect
      // play/pause. Advertise every action the current state supports.
      systemActions: {
        MediaAction.seek,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
        if (c.canGoPrev) MediaAction.skipToPrevious,
        if (c.canGoNext) MediaAction.skipToNext,
      },
      // Compact view shows exactly the controls that exist: prev is always
      // present (canGoPrev is true whenever a file is loaded), play/pause always,
      // and next only when there IS a next — so index it only then.
      androidCompactActionIndices:
          c.canGoNext ? const [0, 1, 2] : const [0, 1],
      processingState:
          c.hasFile ? AudioProcessingState.ready : AudioProcessingState.idle,
      playing: c.isPlaying,
      updatePosition: Duration(milliseconds: (c.position * 1000).round()),
    ));
    // iOS: l'état que le plugin oublie. Après la publication, pour qu'il
    // décrive bien le dictionnaire que le natif vient d'écrire.
    unawaited(_pushIosPlaybackState(c.isPlaying));
  }

  Uri? _artUri() {
    final u = c.artworkUrl;
    if (u != null && u.isNotEmpty) {
      if (u.startsWith('http')) {
        // La copie locale d'abord — c'est elle que l'écran verrouillé et le
        // centre de contrôle affichent sans réseau. Pas encore là: on la
        // demande en PRIORITÉ et on republie la piste quand elle atterrit.
        final local = ArtworkCache.instance.localPathFor(u);
        if (local != null && File(local).existsSync()) return Uri.file(local);
        _republishWhenArtLands(u);
        return Uri.tryParse(u);
      }
      if (File(u).existsSync()) return Uri.file(u);
    }
    return _placeholderUriFor(c);
  }

  final Set<String> _artInFlight = <String>{};
  void _republishWhenArtLands(String url) {
    if (!_artInFlight.add(url)) return;
    unawaited(() async {
      try {
        final path = await ArtworkCache.instance.getPath(
              url,
              album:         c.currentAlbum,
              localFilePath: c.filePath,
              targetDir:     c.artworkTargetDir,
              priority:      true,
            ) ??
            await ArtworkCache.instance
                .awaitDownload(url)
                .timeout(const Duration(seconds: 20), onTimeout: () => null);
        if (path == null || c.artworkUrl != url) return;
        _lastMediaKey = null; // la clé n'a pas bougé, la pochette si
        _sync();
      } catch (_) {
      } finally {
        _artInFlight.remove(url);
      }
    }());
  }

  /// Chemin de FICHIER local pour la pochette de la notification système
  /// macOS (UNNotificationAttachment ne charge que des fichiers, jamais
  /// d'http): la pochette locale si elle existe, sinon le même placeholder
  /// par plateforme que la session média — jamais l'icône générique de
  /// l'app. Branché sur PlayerController.notificationArtProvider par
  /// initMediaSession (media_session importe player_controller, pas
  /// l'inverse — le rappel évite le cycle).
  static Future<String?> notificationArtFor(PlayerController c) async {
    final u = c.artworkUrl;
    if (u != null && u.isNotEmpty) {
      if (!u.startsWith('http')) {
        if (File(u).existsSync()) return u;
      } else {
        // La pochette AFFICHÉE: le même résolveur que l'UI (fichier déjà
        // descendu dans le dossier de la piste, ou téléchargement lancé —
        // auquel cas on n'attend pas: le placeholder plateforme fera la
        // notification, comme l'écran verrouillé).
        try {
          // Prioritaire ET attendue: la notification part une fois, 1,5 s
          // après le chargement, et une descente en vol vaut mieux qu'un
          // placeholder définitif. Bornée: passé 5 s, le placeholder.
          var local = await ArtworkCache.instance.getPath(
            u,
            album:         c.currentAlbum,
            localFilePath: c.filePath,
            targetDir:     c.artworkTargetDir,
            priority:      true,
          );
          local ??= await ArtworkCache.instance
              .awaitDownload(u)
              .timeout(const Duration(seconds: 5), onTimeout: () => null);
          if (local != null && File(local).existsSync()) return local;
        } catch (_) {}
      }
    }
    // Pas d'artworkUrl posé (fichier local dont la découverte n'a pas encore
    // tourné/persisté): la MÊME découverte que l'UI — voisin de dossier
    // (archive importée: son image sert tout le dossier), puis pochette
    // embarquée — avant de se rabattre sur le placeholder plateforme.
    final fp = c.filePath;
    if (fp != null && fp.isNotEmpty) {
      try {
        final local = await ArtworkCache.instance.findLocalArtwork(fp);
        if (local != null) return local;
        final emb = await ArtworkCache.instance.findEmbeddedArtwork(fp);
        if (emb != null) return emb;
      } catch (_) {}
    }
    return _placeholderUriFor(c)?.toFilePath();
  }

  static Uri? _placeholderUriFor(PlayerController c) {
    // No cover of its own → the platform placeholder the app displays, treated
    // like any other artwork. Same signal priority as ArtworkImage: the
    // server's format ext first (a local path can be a container that says
    // nothing about origin), then the file path. The system session only loads
    // file/http URIs, so the bundled assets are materialized to disk once by
    // [_warmupPlaceholders]; until that lands (first launch only) return null
    // and the warmup re-publishes the MediaItem.
    final asset = platformAssetFor(
        platformName: c.currentPlatformName,
        pathOrExt: c.currentFormatExt ?? c.filePath ?? c.fileName,
        engine: c.audio.backendName);
    final cached = _placeholderFiles[asset];
    return cached != null ? Uri.file(cached) : null;
  }

  /// asset key → on-disk copy, filled by [_warmupPlaceholders].
  static final Map<String, String> _placeholderFiles = {};

  /// Copies every platform-placeholder PNG to `<support>/media_art/` so
  /// [_artUri] can hand the session a file URI synchronously. ~25 small PNGs,
  /// no-op cost after the first launch (existing files are kept).
  Future<void> _warmupPlaceholders() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final artDir = Directory('${dir.path}/media_art');
      await artDir.create(recursive: true);
      for (final p in allSoundPlatforms) {
        final asset = platformAssetForPlatform(p);
        final f = File('${artDir.path}/${asset.split('/').last}');
        if (!f.existsSync()) {
          final bytes = await rootBundle.load(asset);
          await f.writeAsBytes(bytes.buffer
              .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
        }
        _placeholderFiles[asset] = f.path;
      }
      _lastMediaKey = null; // re-publish the current MediaItem with its artUri
      _sync();
    } catch (e) {
      debugPrint('[media] placeholder warmup failed: $e');
    }
  }

  // ---- Remote commands → controller ----------------------------------------
  @override
  Future<void> play() async {
    // Centre de contrôle, écran verrouillé, écouteurs, montre, voiture: tout ce
    // qui n'est pas l'écran de l'app arrive ICI. Une commande « suivant » vue
    // ici alors que l'utilisateur dit avoir appuyé sur pause désigne
    // l'ÉVÉNEMENT (un casque qui envoie autre chose), pas notre bouton.
    logTransport('lecture', source: 'session média', detail: 'jouait=${c.isPlaying}');
    if (!c.isPlaying) c.togglePlay();
  }

  @override
  Future<void> pause() async {
    logTransport('pause', source: 'session média', detail: 'jouait=${c.isPlaying}');
    if (c.isPlaying) c.togglePlay();
  }

  @override
  Future<void> stop() async {
    logTransport('stop', source: 'session média', detail: 'jouait=${c.isPlaying}');
    return c.stop();
  }

  @override
  Future<void> seek(Duration position) async =>
      c.seek(position.inMilliseconds / 1000.0);

  @override
  Future<void> skipToNext() {
    logTransport('suivant', source: 'session média', detail: 'jouait=${c.isPlaying}');
    return c.goNext();
  }

  @override
  Future<void> skipToPrevious() {
    logTransport('précédent', source: 'session média', detail: 'jouait=${c.isPlaying}');
    return c.goPrev();
  }
}
