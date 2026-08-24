import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'platform_artwork.dart'
    show allSoundPlatforms, platformAssetFor, platformAssetForPlatform;
import 'player_controller.dart';

/// System media-session bridge (lock screen / Control Center / artwork / remote
/// commands). Playback stays in the C/miniaudio engine — this handler does NOT
/// play anything; it mirrors [PlayerController] state into the OS media session
/// and forwards remote commands back to the controller.
///
/// Supported by audio_service on iOS, Android and macOS. No-op elsewhere
/// (Windows/Linux would need SMTC / MPRIS — phase 2).
RewampAudioHandler? gMediaHandler;
bool _mediaInited = false;

Future<void> initMediaSession(PlayerController c) async {
  if (_mediaInited) return;
  if (!(Platform.isIOS || Platform.isAndroid || Platform.isMacOS)) return;
  _mediaInited = true;

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
        c.togglePlay(); // engine device is already stopped; state follows
      }
    } else if (pausedByInterruption) {
      pausedByInterruption = false;
      // type == pause means the system wants us to resume (transient
      // interruption, e.g. a call that ended). Anything else (another player
      // took over for good): stay paused — the user decides, and togglePlay's
      // ensureAudioSession gate reactivates the session when they do.
      if (event.type == AudioInterruptionType.pause && !c.isPlaying) {
        c.togglePlay();
      }
    }
  });
  // Resume gate: reactivate the (possibly deactivated) session before the
  // engine restarts its device — see PlayerController.togglePlay.
  c.ensureAudioSession = () => session.setActive(true).then((_) {});

  try {
    gMediaHandler = await AudioService.init(
      builder: () => RewampAudioHandler(c),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.rewamp.app.audio',
        androidNotificationChannelName: 'Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        artDownscaleWidth: 320,
        artDownscaleHeight: 320,
      ),
    );
  } catch (e, s) {
    debugPrint('[media] AudioService.init failed: $e\n$s');
  }

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
  final handler = gMediaHandler;
  if (handler != null && (Platform.isMacOS || Platform.isIOS)) {
    handler.playbackState
      ..add(handler.playbackState.value.copyWith(playing: true))
      ..add(handler.playbackState.value.copyWith(playing: false));
  }

  // Android 13+ (API 33): the media-playback notification — the ONLY place the
  // lock-screen / shade transport controls live — is silently dropped unless
  // POST_NOTIFICATIONS is granted, even though the foreground service runs and
  // audio plays. Ask once. iOS/macOS have no equivalent gate.
  if (Platform.isAndroid) {
    await Permission.notification.request();
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
  }

  Uri? _artUri() {
    final u = c.artworkUrl;
    if (u != null && u.isNotEmpty) {
      if (u.startsWith('http')) return Uri.tryParse(u);
      if (File(u).existsSync()) return Uri.file(u);
    }
    // No cover of its own → the platform placeholder the app displays, treated
    // like any other artwork. Same signal priority as ArtworkImage: the
    // server's format ext first (a local path can be a container that says
    // nothing about origin), then the file path. The system session only loads
    // file/http URIs, so the bundled assets are materialized to disk once by
    // [_warmupPlaceholders]; until that lands (first launch only) return null
    // and the warmup re-publishes the MediaItem.
    final asset = platformAssetFor(
        platformName: c.currentPlatformName,
        pathOrExt: c.currentFormatExt ?? c.filePath ?? c.fileName);
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
    if (!c.isPlaying) c.togglePlay();
  }

  @override
  Future<void> pause() async {
    if (c.isPlaying) c.togglePlay();
  }

  @override
  Future<void> stop() async => c.stop();

  @override
  Future<void> seek(Duration position) async =>
      c.seek(position.inMilliseconds / 1000.0);

  @override
  Future<void> skipToNext() => c.goNext();

  @override
  Future<void> skipToPrevious() => c.goPrev();
}
