import 'dart:async';
import 'dart:ui' as ui show lerpDouble;
import 'dart:math' show Random;
import 'dart:ui';

import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp_audio/rewamp_audio.dart';
import 'app_snack.dart';
import 'onboarding.dart';
import 'l10n.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'local_open.dart';
import 'preset_manager.dart';
import 'preset_screen.dart';
import 'local_db.dart';
import 'player_controller.dart' show PlayerController, QueueEntry;
import 'queue_persistence.dart';
import 'media_session.dart';
import 'glass_chrome.dart';
import 'mini_player.dart';
import 'download_banner.dart';
import 'download_cancel.dart';
import 'download_manager.dart';
import 'download_queue_screen.dart';
import 'player_screen.dart' show PlayerScreen, QueuePanel;
import 'playlist_picker.dart' show showAddToPlaylistSheet, trackIdsForRecords, trackIdsForResults;
import 'album_detail_screen.dart';
import 'competition_screen.dart' show globalOnPlayOnlineSong;
import 'home_refresh.dart';
import 'sync_service.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'container_subsong_screen.dart';
import 'track_options_sheet.dart'
    show globalOnQueueAdd, globalOnAlbumQueueAdd, globalOnPlayAlbum,
         globalOnNavigateTag, globalOnOpenGroup,
         globalOnStartFeaturedRadio, globalOnPlayNowSong,
         globalOnLocalQueueAdd, globalQueueHasContent,
         showPlayChoiceSheet, PlayChoice;
import 'library_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'production_screen.dart';
import 'rewamp_db.dart';
import 'uade_info.dart';
import 'user_settings.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

// ── Unified queue item ────────────────────────────────────────────────────────

sealed class _QueueItem {
  // Monotonic creation order — the "proper" (non-shuffled) queue position.
  // Shuffle physically reorders _queue; disabling it re-sorts by this.
  // Not final: a MANUAL reorder renumbers the queue so the arrangement the user
  // just made becomes the natural one. Otherwise turning shuffle off would
  // re-sort by the original seq and silently throw that arrangement away.
  int seq;

  /// Identity, as opposed to [seq] which is an ORDER and gets renumbered.
  /// Never reused, never rewritten: it is what the queue rows key their widgets
  /// on, and a key that moves with the position is exactly the bug that left a
  /// deleted row's red background sitting on the track that took its place.
  static int _nextUid = 0;
  final int uid = _nextUid++;

  _QueueItem(this.seq);
  String get title;
  String? get artist;
}

final class _OnlineItem extends _QueueItem {
  final SearchResult result;
  // A stand-in for a multi-subsong UADE file we chose NOT to probe upfront (it
  // would mean downloading the whole module just to count its subtunes). When
  // this entry is actually reached, _playAt probes the now-downloaded file and
  // splices the real subsongs into the queue. Non-UADE / already-expanded rows
  // leave this false. Mutable: cleared once expanded.
  bool deferExpand;
  _OnlineItem(this.result, int seq, {this.deferExpand = false}) : super(seq);
  @override String  get title  => result.displayTitle;
  @override String? get artist => result.artistLabel.isEmpty ? null : result.artistLabel;
}

final class _LocalItem extends _QueueItem {
  final TrackRecord track;
  _LocalItem(this.track, int seq) : super(seq);
  @override String  get title  => track.displayTitle;
  @override String? get artist => track.artist;
}

// ─────────────────────────────────────────────────────────────────────────────

class _AppShellState extends State<AppShell>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final PlayerController _controller;
  late final List<Widget> _screens;
  Timer? _ticker;
  int _index = 0;

  // ── Unified playback queue ───────────────────────────────────────────────────
  final _queue    = <_QueueItem>[];
  // ── Endless "radio" over a featured series ───────────────────────────────────
  // Non-empty ⇒ radio mode: the queue is a rolling window over this album/
  // playlist pool. On every advance one fresh random-entry track is resolved
  // and appended, and stale entries beyond a small back-window are trimmed —
  // so the station never ends yet stays cheap, and the user can still step back
  // a few tracks (to favourite / add to library / a playlist). Any explicit new
  // play or queue edit exits radio (_exitRadio).
  List<FeaturedSlot> _radioPool = const [];
  bool _radioResolving = false;              // guard: one refill in flight
  final _rand = Random();
  static const int _radioAhead  = 3;         // tracks kept ahead of current
  static const int _radioBehind = 8;         // past tracks kept for back-nav
  // Consecutive queue-item download failures — 3 in a row = stop auto-skipping
  // (network most likely down) instead of burning through the whole queue.
  int _consecutiveDlFailures = 0;
  // Song ids we've already tried to rescue with a source refresh after an
  // origin-gone (404) failure — so a mirror that ALSO fails can't loop us.
  final Set<String> _sourceRefreshedIds = <String>{};
  // Consecutive native-decode (loadFile) failures — a file that downloaded fine
  // but the decoder refused (corrupt module, or a mis-tagged row asking for a
  // ?subsong=N the file doesn't have). Same 3-in-a-row cap as downloads, so a
  // run of bad rows skips forward once each instead of spamming loadFile FAILED.
  int _consecutiveLoadFailures = 0;
  // Local path of the queue entry currently being PREFETCHED (the next entry
  // that needs a real download), so we don't launch it twice. Cleared when that
  // download finishes. See _prefetchNextDownload.
  String? _prefetchingPath;
  // Prefetch targets whose speculative download already failed this queue — so a
  // broken source (e.g. a whole collection with malformed mirror URLs) isn't
  // re-hammered on every track advance. Cleared when a fresh queue is built.
  final Set<String> _prefetchFailed = {};
  // Bumped when the search tab is re-selected → SearchScreen resets criteria.
  final _searchResetTick = ValueNotifier<int>(0);
  int   _queueIdx = -1;
  // Index of the last entry that ACTUALLY started playing (loadFile ok). A
  // failed jump restores the counter/highlight to this so the display never
  // strands on an unplayable entry while the audio stays on the real track.
  int   _lastGoodIdx = -1;
  // The single-file multi-subsong container currently playing (subsongIdx 0),
  // or null when the current item isn't such a container. Set at play time
  // (not derived from _queue, which single online plays don't populate) so the
  // player can offer a "subsongs" link. See _currentContainerResult.
  SearchResult? _playingContainer;
  // Monotonic — assigns each _QueueItem its "proper order" slot (see
  // _QueueItem.seq); never reset, only ever increases.
  int _nextQueueSeq = 0;
  int _seq() => _nextQueueSeq++;
  // Restored from the preferences (see UserSettings.transportShuffle): a
  // transport mode survives quitting the app. The saved queue is stored in its
  // SHUFFLED order, so a restore must not re-shuffle — only mirror the flag.
  bool _shuffleEnabled = UserSettings.instance.transportShuffle;

  // ── Sidebar queue panel visibility ────────────────────────────────────────────
  /// A drag is hovering the window (drop feedback).
  bool _dragOver = false;
  bool _showSidebarQueue = false;

  // One Navigator key per tab so each tab has its own navigation stack.
  // Navigation inside a tab (e.g. artist → song list) stays within that
  // tab's area; the sidebar and MiniPlayer are never affected.
  final _navKeys = List.generate(6, (_) => GlobalKey<NavigatorState>());
  /// What each tab currently has stacked, newest last — fed by a real
  /// NavigatorObserver so it also sees the pushes that do NOT go through
  /// [_pushOnTab] (an artist opened from an album screen, say). An untracked
  /// route contributes a null, which simply never matches a name.
  late final _navStacks = List.generate(6, (_) => <String?>[]);
  late final _navObservers =
      List.generate(6, (i) => _TabRouteObserver(_navStacks[i]));

  static const double _desktopBreakpoint = 600.0;

  // ── Full player, hosted as an OVERLAY rather than a route ────────────────
  //
  // A route cannot be pushed while a finger is down: the push cancels the
  // in-flight pointer, so the drag stops being reported and the transition
  // freezes (measured — see MiniPlayer.onDragOpen). Anything drawn INSTEAD of
  // the player during the drag is an imitation that drifts from it. So the
  // player is the real widget, mounted here, and "open" is this controller.
  //
  // Mounted LAZILY and unmounted at 0: keeping it alive would keep a GL
  // visualizer running behind every screen.
  late final AnimationController _playerCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 260),
  )..addStatusListener(_onPlayerAnimStatus);
  bool _playerMounted = false;

  /// A finger currently owns the open animation. While it does, a value of 0
  /// is a POSITION, not a verdict: dragging up, back down past the start and up
  /// again crosses 0 mid-gesture, and unmounting there left the nav bar being
  /// pushed by a player that no longer existed.
  bool _playerDragActive = false;

  void _onPlayerDragBegin() {
    _playerDragActive = true;
    _mountPlayer();
  }

  void _onPlayerDragEnd() {
    _playerDragActive = false;
    // The release may leave it exactly at 0, where no status CHANGE fires and
    // the listener below would never run — an invisible player left mounted,
    // visualizer and all.
    //
    // Unless the release ARMED an opening fling: a flick up from exactly the
    // start (dragged up, back down to 0, flicked) is still at 0 on this frame
    // and would be torn down mid-open.
    if (_playerCtrl.value == 0 &&
        _playerCtrl.status != AnimationStatus.forward) {
      _unmountPlayer();
    }
  }

  void _unmountPlayer() {
    if (!_playerMounted || !mounted) return;
    _openFromRect = null;
    setState(() => _playerMounted = false);
  }

  void _onPlayerAnimStatus(AnimationStatus s) {
    // Back to 0 → unmount, which stops the visualizer. PlayerScreen.dispose
    // clears playerUiCloser itself, so nothing to undo here.
    if (s == AnimationStatus.dismissed && !_playerDragActive) {
      _unmountPlayer();
    }
  }

  /// Whether the back button should close the player rather than leave the app.
  /// Keyed on MOUNTED, not on the animation value: the value moves without a
  /// setState, so a PopScope reading it would never rebuild — and mounted is
  /// true over exactly the window where back must mean "close the player".
  bool get _playerOpen => _playerMounted;

  // The open animation reads in THREE beats, and each needs its own span or
  // the whole thing looks like one box growing:
  //   1. the bar BECOMES the player — full width, corners, cross-fade;
  //   2. it PUSHES the nav bar off the bottom and takes its place;
  //   3. it climbs, top edge under the finger, for the rest of the gesture.
  // Beat 1 has to be seen (4 % was ~30 px of thumb, over before the eye), beat
  // 2 has to follow it rather than run with it, or nothing is being pushed.

  /// Share spent on beat 1. ~12 % of a 1:1 drag ≈ 95 px of thumb travel.
  static const double _kEmergeFraction = 0.12;

  /// Share spent on beat 2, starting where beat 1 ends. It now spans the
  /// WHOLE remainder of the animation: the player pushes the nav bar down
  /// progressively all the way through (bottom edge and bar still travel
  /// together), instead of expelling it in a quick 10 % burst.
  static const double _kPushFraction = 1.0 - _kEmergeFraction;

  /// Where the cross-fade is complete — a touch before beat 1 ends, so the bar
  /// is already fully covered when it stops being carried along. ONE constant:
  /// the overlay's opacity and the bar's follow must end together or the bar
  /// visibly parts company with the player.
  static const double _kFadeEnd = _kEmergeFraction * 0.8;

  /// How far the nav bar has been shoved down, in pixels, at the current point
  /// of the open animation. Zero while the bar is still turning into the
  /// player: it is the player REACHING the bottom that pushes, not its
  /// appearing.
  /// Progress of the push beat (0 → 1 over beat 2). Shared by the downward
  /// push (two-line mode) and the leftward push of the condensed pill.
  double get _navBarPushProgress =>
      ((_playerCtrl.value - _kEmergeFraction) / _kPushFraction)
          .clamp(0.0, 1.0)
          .toDouble();

  double _navBarPush(BuildContext context) {
    final p = _navBarPushProgress;
    if (p <= 0) return 0;
    // Its whole travel plus the gap and the bottom inset, so it is fully gone
    // rather than half-visible at the edge.
    return p *
        (_kNavBarHeight +
            _kGlassGap +
            _kNavBarLift +
            MediaQuery.of(context).padding.bottom);
  }

  /// Marks the mini player so the opening animation can start FROM its rect —
  /// the player grows out of the bar instead of sliding in from the screen
  /// edge (see the overlay's builder).
  final GlobalKey _miniPlayerKey = GlobalKey();

  /// The mini player's rect, CAPTURED ONCE when the player mounts.
  ///
  /// Not re-measured per frame, and that is load-bearing now that the bar is
  /// translated to follow the finger: `localToGlobal` accounts for the
  /// transform, so measuring live would feed the bar's own movement back into
  /// the rect it is derived from.
  Rect? _openFromRect;

  /// Where the mini player sits on screen, or null when it is not laid out
  /// (nothing playing, desktop sidebar, first frame). Null falls the animation
  /// back to a plain bottom-edge slide.
  Rect? _miniPlayerRect() {
    final box = _miniPlayerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// How far the mini player has been carried UP with the opening player, in
  /// pixels (negative = up). It stays glued to the player's top edge until the
  /// cross-fade is over — past that it is fully covered, so it stops moving
  /// rather than drifting behind an opaque screen.
  double _miniPlayerFollow() {
    final from = _openFromRect;
    if (from == null) return 0;
    final v = _playerCtrl.value.clamp(0.0, _kFadeEnd);
    // The player's top edge rises by exactly this much (see the overlay's
    // builder: top = lerp(from.top, 0, v)), so the two travel together.
    return -from.top * v;
  }

  /// Mounts the player without animating it — the caller then drives
  /// [_playerCtrl] (a finger) or forwards it (a tap).
  void _mountPlayer() {
    if (_playerMounted) return;
    if (_controller.filePath == null) return;
    _playerIntentSeq++;
    // Measured BEFORE the bar starts moving, and kept for the whole animation.
    _openFromRect = _miniPlayerRect();
    setState(() => _playerMounted = true);
  }

  void _closePlayerOverlay() {
    if (!_playerMounted) return;
    _playerIntentSeq++;
    _playerCtrl.reverse();
  }

  /// Bumped every time the player is opened or closed — by a tap on the mini
  /// player, a drag, the close button, the back button, OR by a chip inside
  /// the player navigating away.
  ///
  /// Navigating from the player arms "put the player back when this screen
  /// pops" (see [_pushOnTab]). That promise is only valid as long as nobody
  /// touches the player meanwhile: open the player again from the mini bar
  /// while standing on the album screen, close it, go back — and the stale
  /// promise used to summon the player a second time, so back did not go back.
  /// Comparing this counter makes the promise expire on the first manual
  /// gesture; there is no "player position in the navigation stack" to keep in
  /// sync, because the player is an overlay and has none.
  int _playerIntentSeq = 0;
  // ── Condensed bottom chrome (Apple-Music-style) ──────────────────────────
  //
  // On a phone, once the user starts scrolling vertically while the mini
  // player is visible, the two bottom slabs collapse onto ONE line: the nav
  // bar shrinks to just the selected icon (left-aligned) and the mini player
  // drops level with it, taking the remaining width. Tapping the condensed
  // nav icon restores the two-line layout. Everything is driven by
  // [_chromeCtrl] (0 = two lines, 1 = one line).
  late final AnimationController _chromeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> _chromeT =
      CurvedAnimation(parent: _chromeCtrl, curve: Curves.easeInOutCubic);
  bool _chromeCondensed = false;

  void _setChromeCondensed(bool v) {
    // Without a mini player there is nothing to pair the pill with — the nav
    // bar alone stays full-width.
    if (v && !_controller.hasFile) return;
    if (_chromeCondensed == v) return;
    _chromeCondensed = v;
    if (v) {
      _chromeCtrl.forward();
    } else {
      _chromeCtrl.reverse();
    }
  }

  /// Hauteur réservée au mini-lecteur flottant (expérimentation verre).
  static const double _kMiniPlayerHeight = 52.0;
  /// Hauteur de la barre de navigation. Material 3 la met à 80 par défaut, ce
  /// qui est haut pour une dalle flottante; la valeur est imposée à la
  /// NavigationBar ET sert au calcul des décalages — les deux DOIVENT rester
  /// égales, sinon le mini-lecteur flotte trop haut ou passe sous la barre.
  static const double _kNavBarHeight = 52.0;
  /// Le strict minimum pour que le mini-lecteur se lise comme une dalle
  /// posée AU-DESSUS de la barre, et non collée à elle.
  static const double _kGlassGap = 6.0;
  /// Marge latérale des deux dalles: elles ne doivent pas toucher les bords de
  /// la fenêtre, sinon elles se lisent comme des barres pleine largeur et non
  /// comme des dalles posées par-dessus le contenu.
  static const double _kGlassInset = 10.0;
  /// Même raison en bas: la barre de navigation est décollée du bord, ce qui
  /// permet aussi d'arrondir ses quatre coins.
  static const double _kNavBarLift = 6.0;
  // Nav rail shows labels when there is enough horizontal room.
  static const double _kExtendedNavRailBreakpoint = 800.0;

  @override
  void initState() {
    super.initState();
    // Home rails only refetch when HomeRefresh says so — the home subtree lives
    // in the IndexedStack below and is never rebuilt from scratch.
    WidgetsBinding.instance.addObserver(this);
    // Queue fallbacks for screens that reach the options sheet without the
    // callbacks threaded through (facet browser, party/playlist details, …).
    globalOnQueueAdd      = _onQueueAdd;
    globalOnAlbumQueueAdd = _onAlbumQueueAdd;
    globalOnPlayAlbum     = _startAlbumQueue;
    // "Lire maintenant": replaces the queue. Uses OUR context, never the
    // caller's — the options sheet pops itself before invoking, and
    // _startAlbumQueue bails on an unmounted ctx.
    globalOnPlayNowSong   = (r) => _startAlbumQueue(context, [r]);
    globalOnLocalQueueAdd = _onLocalQueueAdd;
    globalQueueHasContent = () => _queue.isNotEmpty || _controller.hasFile;
    globalOnStartFeaturedRadio = _startFeaturedRadio;
    globalOnNavigateTag   = _pushTagSearch;
    globalOnOpenProduction = _pushProduction;
    globalOnOpenGroup     = _pushGroup;
    globalOnOpenPresets   = _pushPresets;
    globalOpenLocalPaths  = _openLocalPaths;
    // Dock drop / Open With / double-click. Set the hook FIRST:
    // the native buffer is drained immediately and its contents
    // are cleared on the native side by that very call.
    listenForOpenedFiles();
    // Play path for the competition screen's entries (podium badges land there).
    globalOnPlayOnlineSong = _downloadAndPlayOnline;
    // Welcome carousel (beta warning + a short tour), once per build. After the
    // first frame so it lands on top of the shell rather than racing it, and
    // after the launch intro has had its moment.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      // Shown even when the app was launched BY a file. Skipping it there was
      // tried and reverted: it is a beta warning about data that may be wiped,
      // so it has to be SEEN, and gating it on "the next ordinary launch"
      // means someone who only ever double-clicks modules never gets one. It
      // does not block playback — the track is already playing behind it.
      if (mounted) await Onboarding.maybeShow(context);
    });
    final audio = RewampAudio();
    final ok = audio.init();
    if (!ok) debugPrint('rewamp_audio: init failed');
    // The buffer we ASKED for is only a request; on iOS audio_service owns the
    // AVAudioSession and reconfigures it right after this. Print what the device
    // actually negotiated — every "we have N ms of slack" conclusion rests on it.
    if (!kReleaseMode && ok) {
      final ms = audio.devicePeriodMs;
      debugPrint('rewamp_audio: device buffer = '
          '${ms.toStringAsFixed(1)}ms × ${audio.devicePeriods} periods '
          '= ${(ms * audio.devicePeriods).toStringAsFixed(0)}ms de marge '
          '(demandé: ${audio.deviceRequestedPeriodMs}ms)');
    }

    _controller = PlayerController(audio);
    _controller.queueTrackIdsResolver = _queueTrackIds;
    _controller.onToggleShuffle = _toggleShuffle;
    // The shuffle flag is restored from the preferences; the controller only
    // MIRRORS it for the queue panel, so hand it over at birth (loopMode reads
    // the pref itself — it is the controller's own state).
    _controller.setShuffleEnabled(_shuffleEnabled);
    _applyPlaybackLibraryPrefs(audio);
    UserSettings.instance.addListener(() => _applyPlaybackLibraryPrefs(_controller.audio));
    _controller.onTrackEnded = () {
      final mode = _controller.loopMode;
      if (mode == 2) {
        // Filet, plus le mécanisme: repeat-morceau est une boucle forcée
        // INFINIE (effectiveForceLoopMode), donc le moteur ne rend normalement
        // jamais la main ici — un format à point de boucle reboucle sa région
        // au lieu de repartir de l'intro. On n'arrive dans cette branche que
        // si le mode a été armé EN COURS de morceau (l'instantané moteur date
        // de l'ouverture): le rechargement ci-dessous reprend le bon.
        _controller.replayCurrent();
      } else if (mode == 1 && !_controller.canGoNext && _queue.isNotEmpty) {
        // Loop the queue: wrap to the first item once the last one ends.
        _playAt(0);
      } else if (_controller.canGoNext) {
        _controller.goNext();
      } else if (_queue.isNotEmpty) {
        // Nothing advanced: the queue is done. Arm the restart so the next play
        // press opens the FIRST entry instead of replaying the last one (the
        // decoder still holds it, which is the only reason it replayed).
        _controller.queueExhausted = true;
      }
    };
    _controller.onRestartQueue = () {
      if (_queue.isNotEmpty) _playAt(0);
    };
    _controller.onGoToQueueIndex = (i) {
      if (i >= 0 && i < _queue.length) _playAt(i);
    };
    _controller.onReorderQueue = _reorderQueue;
    _controller.onRemoveFromQueue = _removeFromQueue;
    _controller.onClearQueue = _clearQueue;
    _controller.onLoadResult = _onLoadResult;
    _controller.onTrackDeleted = _onTrackDeleted;
    // First play press on a restored (primed) queue actually loads the track.
    _controller.onResumePrimed = () => _playAt(_queueIdx);

    _ticker = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) {
        _controller.tick();
        _logUnderruns();
      },
    );

    // System media session (lock screen / Control Center / artwork / remote).
    // Playback stays in the C engine; this only mirrors state + forwards
    // commands. No-op on Windows/Linux. Fire-and-forget.
    initMediaSession(_controller);

    // Restore recently-played list from the local DB.
    _controller.loadHistory();

    // Restore the playback queue from the previous session (paused on the
    // track that was playing). No-op after a crash during a track load.
    _restoreQueueAtLaunch();

    // Register anonymous user on first launch (no-op if UUID already stored).
    _ensureUserId();

    _screens = [
      _TabNavigator(
        navKey: _navKeys[0],
        observer: _navObservers[0],
        child: HomeScreen(
          controller: _controller,
          onFileReady: _onFileReady,
          onPlayAlbum: _startAlbumQueue,
          onPlayLocalAlbum: _startLocalTrackQueue,
          onLocalTracksQueueAdd: _onLocalTracksQueueAdd,
          onPlaySingleLocalFile: _onSingleLocalFileReady,
        ),
      ),
      _TabNavigator(
        navKey: _navKeys[1],
        observer: _navObservers[1],
        child: SearchScreen(
          onFileReady:     _onSingleLocalFileReady,
          onPlayAlbum:     _startAlbumQueue,
          onQueueAdd:      _onQueueAdd,
          onAlbumQueueAdd: _onAlbumQueueAdd,
          resetTick:       _searchResetTick,
        ),
      ),
      _TabNavigator(
        navKey: _navKeys[2],
        observer: _navObservers[2],
        child: LibraryScreen(
          onPlayTrack:       _onSingleLocalFileReady,
          onDownloadTrack:   _downloadLibraryTrack,
          onPlayOnline:      (c, r) => _downloadAndPlayOnline(c, r),
          onPlayAlbum:       _startAlbumQueue,
          onPlayLocalAlbum:  _startLocalTrackQueue,
          onNavigateAlbum:   (name, {collection, platform, artworkUrl, albumId}) =>
              _navKeys[2].currentState?.push(MaterialPageRoute(
                builder: (_) => AlbumDetailScreen(
                  albumName:       name,
                  albumId:         albumId,
                  collectionSlug:  collection,
                  platformName:    platform,
                  artworkUrl:      artworkUrl,
                  onTap:           (c, r) => _downloadAndPlayOnline(c, r),
                  onPlayAlbum:     _startAlbumQueue,
                  onPlayLocalAlbum: _startLocalTrackQueue,
                  onQueueAdd:      _onQueueAdd,
                  onAlbumQueueAdd: _onAlbumQueueAdd,
                ),
              )),
          onNavigateArtist:  (name, {collection, artistId}) =>
              _navKeys[2].currentState?.push(MaterialPageRoute(
                builder: (_) => ArtistResultsScreen(
                  artistName:      name,
                  artistId:        artistId,
                  collection:      collection,
                  onTap:           (c, r) => _downloadAndPlayOnline(c, r),
                  onPlayAlbum:     _startAlbumQueue,
                  onQueueAdd:      _onQueueAdd,
                  onAlbumQueueAdd: _onAlbumQueueAdd,
                  onNavigateTag:   _pushTagSearch,
                ),
              )),
        ),
      ),
      _TabNavigator(
        navKey: _navKeys[3],
        observer: _navObservers[3],
        child: StatsScreen(onPlayLocalAlbum: _startLocalTrackQueue),
      ),
      _TabNavigator(
        navKey: _navKeys[4],
        observer: _navObservers[4],
        child: SettingsScreen(
          onHistoryCleared:       () => _controller.loadHistory(),
          onDatabaseReset:        _onDatabaseReset,
          onOnlineLibraryDeleting: _onOnlineLibraryDeleting,
        ),
      ),
      _TabNavigator(
        navKey: _navKeys[5],
        observer: _navObservers[5],
        child: const AboutScreen(),
      ),
    ];
  }

  // Audio-underrun telemetry (debug only). The counter is bumped by the audio
  // callback when the decode-ahead ring came up short — i.e. the decoder failed
  // to stay ahead of playback. Logged from here, NEVER from the audio thread: a
  // print on that thread would itself stall it and cause the very glitch we are
  // chasing. Silent while it stays flat.
  int _lastUnderruns = 0;
  int _lastSlow      = 0;
  int _lastDevLate   = 0;

  void _logUnderruns() {
    // Not kDebugMode: a starved realtime thread is exactly what debug fakes
    // (JIT Dart, unoptimized native). The run that matters is --profile.
    if (kReleaseMode) return;
    final a       = _controller.audio;
    final n       = a.underrunCount;
    final slow    = a.slowReadCount;
    final devLate = a.deviceLateCount;
    if (n == _lastUnderruns && slow == _lastSlow && devLate == _lastDevLate) {
      return;
    }

    // Three causes, three opposite fixes — so name which one just happened.
    // DEVICE-LATE is the real scheduling metric: the old LATE-READ timed how
    // often the DATA SOURCE was read, which stops while paused, so it reported a
    // 720 ms pause as a 720 ms stall.
    final what = <String>[
      if (n > _lastUnderruns)
        'UNDERRUN ×${n - _lastUnderruns} (decoder behind → raise the lead)',
      if (slow > _lastSlow)
        'SLOW-READ ×${slow - _lastSlow} (callback blocked on a lock → our sync)',
      if (devLate > _lastDevLate)
        'DEVICE-LATE ×${devLate - _lastDevLate} (OS did not schedule the '
            'realtime thread)',
    ].join('  |  ');
    final ms = a.underrunFrames * 1000 ~/ 44100;
    debugPrint('rewamp_audio: $what   [underrun=$n (~${ms}ms) slow=$slow '
        'device-late=$devLate  worst device gap='
        '${a.deviceMaxGapMs.toStringAsFixed(0)}ms  worst busy='
        '${a.deviceMaxBusyMs.toStringAsFixed(1)}ms]');

    _lastUnderruns = n;
    _lastSlow      = slow;
    _lastDevLate   = devLate;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Back from the background: the featured rail is calendar-driven (a party
    // podium, a "this month N years ago") and the trends move server-side, so
    // stale data is refetched. TTL-guarded inside HomeRefresh.
    if (state == AppLifecycleState.resumed) {
      HomeRefresh.instance.refresh();
      // Also the moment the network is most likely back (another app used it,
      // the device left a tunnel): drain whatever the queue still holds.
      SyncService.instance.kick();
      SyncService.instance.startPolling();
      // projectM preload worker back up (restarted by the next render tick).
      _controller.audio.projectmSetActive(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Deliberately NOT on `inactive`: macOS reports that on every focus loss,
      // and a desktop app sitting visible next to a phone is exactly the case
      // the heartbeat exists for.
      SyncService.instance.stopPolling();
      // Stop the projectM preload worker: a plain pthread, it kept compiling
      // and warm-drawing while backgrounded — forbidden GPU work on iOS that
      // poisoned the pipeline (post-resume preset switches hitched until a
      // full restart).
      _controller.audio.projectmSetActive(false);
      // Ship the accumulated preset-usage batch while the network is still up.
      unawaited(PresetManager.instance.flushUsage());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SyncService.instance.stopPolling();
    _playerCtrl.dispose();
    _chromeCtrl.dispose();
    _ticker?.cancel();
    _controller.audio.uninit();
    _controller.dispose();
    super.dispose();
  }

  void _applyPlaybackLibraryPrefs(RewampAudio audio) {
    final s = UserSettings.instance;
    // NSF / NSFe: apply user preference (default: nsfplay).
    for (final ext in ['nsf', 'nsfe']) {
      audio.setPreferredPlugin(ext, s.nsfPlugin);
    }
    // GBS: apply user preference (default: gbsplay).
    audio.setPreferredPlugin('gbs', s.gbsPlugin);
    // .sndh: psgplay by default (whole-machine emulation incl. the STE
    // LMC1992 mixer, native stereo), AtariAudio on request. Both are
    // registered and psgplay probes LOWER, so this call is what actually
    // selects it — without it the registry would fall back to AtariAudio.
    audio.setPreferredPlugin('sndh', s.sndhPlugin == 'psgplay' ? 'psgplay' : 'sndh');

    // Per-engine parameters (Settings → Moteurs) — read by the plugin's
    // open(), i.e. applied on the next track (re)load.
    audio.setEngineParam('openmpt', 'interpolation', s.omptInterpolation.toDouble());
    audio.setEngineParam('openmpt', 'stereo_sep',    s.omptStereoSep.toDouble());
    audio.setEngineParam('openmpt', 'master_volume', s.omptMasterVolume);
    audio.setEngineParam('openmpt', 'amiga_filter',  s.omptAmigaFilter.toDouble());
    audio.setEngineParam('gme', 'silence_detection', s.gmeSilenceDetection ? 1 : 0);
    audio.setEngineParam('gme', 'stereo_depth',      s.gmeStereoDepth);
    audio.setEngineParam('gme', 'eq_enabled',        s.gmeEqEnabled ? 1 : 0);
    audio.setEngineParam('gme', 'eq_bass',           s.gmeEqBass);
    audio.setEngineParam('gme', 'eq_treble',         s.gmeEqTreble);
    audio.setEngineParam('gbsplay', 'hp_filter',     s.gbsHpFilter.toDouble());
    audio.setEngineParam('gsf', 'interpolation',     s.gsfInterpolation ? 1 : 0);
    audio.setEngineParam('gsf', 'lowpass',           s.gsfLowpass ? 1 : 0);
    audio.setEngineParam('gsf', 'echo',              s.gsfEcho ? 1 : 0);
    audio.setEngineParam('uade', 'postfx',           s.uadePostfx ? 1 : 0);
    audio.setEngineParam('uade', 'pan_enabled',      s.uadePanEnabled ? 1 : 0);
    audio.setEngineParam('uade', 'pan_value',        s.uadePanValue);
    audio.setEngineParam('uade', 'headphones',       s.uadeHeadphones ? 1 : 0);
    audio.setEngineParam('uade', 'gain_enabled',     s.uadeGainEnabled ? 1 : 0);
    audio.setEngineParam('uade', 'gain_value',       s.uadeGainValue);
    audio.setEngineParam('uade', 'led',              s.uadeLed.toDouble());
    audio.setEngineParam('uade', 'filter_type',      s.uadeFilterType.toDouble());

    audio.setEngineParam('sid', 'engine',          s.sidEngine.toDouble());
    audio.setEngineParam('sid', 'auto_filter',     s.sidAutoFilter ? 1 : 0);
    audio.setEngineParam('sid', 'filter',          s.sidFilter ? 1 : 0);
    audio.setEngineParam('sid', 'second_sid_addr',
        s.sidSecondOn ? s.sidSecondAddr.toDouble() : 0);
    audio.setEngineParam('sid', 'third_sid_addr',
        s.sidThirdOn ? s.sidThirdAddr.toDouble() : 0);
    audio.setEngineParam('sid', 'sampling',        s.sidSampling.toDouble());
    audio.setEngineParam('sid', 'clock',           s.sidClock.toDouble());
    audio.setEngineParam('sid', 'model',           s.sidModel.toDouble());
    audio.setEngineParam('sid', 'f6581_curve',     s.sid6581Curve);
    audio.setEngineParam('sid', 'f6581_range',     s.sid6581Range);
    audio.setEngineParam('sid', 'f8580_curve',     s.sid8580Curve);
    audio.setEngineParam('nsfplay', 'quality',     s.nsfQuality.toDouble());
    audio.setEngineParam('nsfplay', 'lpf',         s.nsfLpf.toDouble());
    audio.setEngineParam('nsfplay', 'hpf',         s.nsfHpf.toDouble());
    audio.setEngineParam('nsfplay', 'region',      s.nsfRegion.toDouble());
    audio.setEngineParam('nsfplay', 'irq',         s.nsfIrq ? 1 : 0);
    // Per-chip emulation options. The C keys are positional (apu1_<i> etc.,
    // matching the nes_* OPT_ enums) — see nsfplay_apply_engine_params.
    audio.setEngineParam('nsfplay', 'apu1_0', s.nsfApu1Unmute ? 1 : 0);
    audio.setEngineParam('nsfplay', 'apu1_1', s.nsfApu1PhaseRefresh ? 1 : 0);
    audio.setEngineParam('nsfplay', 'apu1_2', s.nsfApu1NonlinearMixer ? 1 : 0);
    audio.setEngineParam('nsfplay', 'apu1_3', s.nsfApu1DutySwap ? 1 : 0);
    audio.setEngineParam('nsfplay', 'apu1_4', s.nsfApu1NegateSweep ? 1 : 0);
    audio.setEngineParam('nsfplay', 'apu2_0', s.nsfApu2Enable4011 ? 1 : 0);
    audio.setEngineParam('nsfplay', 'apu2_1', s.nsfApu2PeriodicNoise ? 1 : 0);
    audio.setEngineParam('nsfplay', 'apu2_2', s.nsfApu2Unmute ? 1 : 0);
    audio.setEngineParam('nsfplay', 'apu2_3', s.nsfApu2DpcmAntiClick ? 1 : 0);
    audio.setEngineParam('nsfplay', 'apu2_4', s.nsfApu2NonlinearMixer ? 1 : 0);
    audio.setEngineParam('nsfplay', 'apu2_5', s.nsfApu2RandomizeNoise ? 1 : 0);
    audio.setEngineParam('nsfplay', 'apu2_6', s.nsfApu2TriangleMute ? 1 : 0);
    audio.setEngineParam('nsfplay', 'apu2_7', s.nsfApu2RandomizeTri ? 1 : 0);
    audio.setEngineParam('nsfplay', 'apu2_8', s.nsfApu2DpcmReverse ? 1 : 0);
    audio.setEngineParam('nsfplay', 'n163_0', s.nsfN163Serial ? 1 : 0);
    audio.setEngineParam('nsfplay', 'n163_1', s.nsfN163PhaseReadOnly ? 1 : 0);
    audio.setEngineParam('nsfplay', 'n163_2', s.nsfN163LimitWavelength ? 1 : 0);
    audio.setEngineParam('nsfplay', 'fds_lpf_hz', s.nsfFdsCutoff.toDouble());
    audio.setEngineParam('nsfplay', 'fds_1', s.nsfFds4085Reset ? 1 : 0);
    audio.setEngineParam('nsfplay', 'fds_2', s.nsfFdsWriteProtect ? 1 : 0);
    audio.setEngineParam('nsfplay', 'mmc5_0', s.nsfMmc5NonlinearMixer ? 1 : 0);
    audio.setEngineParam('nsfplay', 'mmc5_1', s.nsfMmc5PhaseRefresh ? 1 : 0);
    audio.setEngineParam('nsfplay', 'vrc7_patch', s.nsfVrc7Patch.toDouble());
    audio.setEngineParam('nsfplay', 'vrc7_opll', s.nsfVrc7Opll ? 1 : 0);
    audio.setEngineParam('highlyexp', 'spu_main',  s.heSpuMain ? 1 : 0);
    audio.setEngineParam('highlyexp', 'spu_reverb', s.heSpuReverb ? 1 : 0);
    audio.setEngineParam('adplug', 'surround',     s.adplugSurround ? 1 : 0);
    audio.setEngineParam('vgm', 'ym2612_core',     s.vgmYm2612Core.toDouble());
    audio.setEngineParam('vgm', 'ymf262_core',     s.vgmYmf262Core.toDouble());
    audio.setEngineParam('vgm', 'ym3812_core',     s.vgmYm3812Core.toDouble());
    audio.setEngineParam('vgm', 'qsound_core',     s.vgmQsoundCore.toDouble());
    audio.setEngineParam('vgm', 'rf5c68_core',     s.vgmRf5c68Core.toDouble());
    audio.setEngineParam('vgm', 'gb_core',         s.vgmGbCore.toDouble());
    audio.setEngineParam('vgm', 'ym2413_core',     s.vgmYm2413Core.toDouble());
    audio.setEngineParam('vgm', 'ym2151_core',     s.vgmYm2151Core.toDouble());
    audio.setEngineParam('vgm', 'ay8910_core',     s.vgmAy8910Core.toDouble());
    audio.setEngineParam('vgm', 'nes_core',        s.vgmNesCore.toDouble());
    audio.setEngineParam('vgm', 'sn76496_core',    s.vgmSn76496Core.toDouble());
    audio.setEngineParam('vgm', 'saa1099_core',    s.vgmSaa1099Core.toDouble());
    audio.setEngineParam('vgm', 'c6280_core',      s.vgmC6280Core.toDouble());
    audio.setEngineParam('midi', 'gain',       s.midiGain);
    audio.setEngineParam('midi', 'polyphony',  s.midiPolyphony.toDouble());
    audio.setEngineParam('midi', 'reverb',     s.midiReverb ? 1 : 0);
    audio.setEngineParam('midi', 'chorus',     s.midiChorus ? 1 : 0);
    audio.setEngineParam('midi', 'interp',     s.midiInterp.toDouble());

    // Amiga tracker formats playable by BOTH libopenmpt and UADE: route per
    // the user's preference (libopenmpt wins by default; UADE claims them at
    // a low score so the pin can flip it).
    final amigaPlugin =
        s.amigaTrackerPlugin == 'uade' ? 'uade' : 'libopenmpt';
    for (final ext in ['mod', 'med', 'mmd0', 'mmd1', 'mmd2', 'mmd3', 'okt', 'digi']) {
      audio.setPreferredPlugin(ext, amigaPlugin);
    }
  }

  Future<void> _ensureUserId() async {
    final settings = UserSettings.instance;
    final existing = settings.userId;
    debugPrint('[AppShell] _ensureUserId existing=$existing '
        'token=${settings.hasAuthToken}');
    // The CREDENTIAL, not the uuid, decides whether we have an account. Since
    // migrations 188/189 the uuid proves nothing and no RPC takes it: an
    // install that predates the token has an id the server will no longer
    // answer to, so it needs a real registration like a fresh one.
    if (!settings.hasAuthToken) {
      final uuid = await RewampDb.registerUser();
      debugPrint('[AppShell] _ensureUserId registered=$uuid');
      if (uuid != null && uuid.isNotEmpty) {
        final replacedAnonymous = existing != null && existing != uuid;
        await settings.setUserId(uuid);
        if (replacedAnonymous) {
          // The old anonymous account still holds this device's server-side
          // library, and nothing can prove we own it any more (that is exactly
          // what the migration removed). The LOCAL library is intact, so
          // re-publish it under the new account rather than let the two drift.
          // A user with an email attached can instead sign back in, which
          // merges properly — this is the floor, not the ideal path.
          final n = await SyncService.instance.rebindLocalDataToCurrentAccount();
          debugPrint('[AppShell] account replaced ($existing → $uuid): '
              '$n library item(s) re-queued');
        }
      }
    }
    // First sync of the session, once the identity is known — for an EXISTING
    // install too, which is the normal case (an early return here left the
    // launch sync dead code: verified, nothing ran for 75 s).
    // Delayed: launch is already busy (engine init, splash, queue restore) and
    // nothing here is urgent.
    if (UserSettings.instance.userId != null) {
      SyncService.instance.nudge(delay: const Duration(seconds: 8));
      // The app starts foregrounded and `resumed` may already have fired before
      // the identity was known, so arm the heartbeat here too (idempotent).
      SyncService.instance.startPolling();
    }
  }

  Future<void> _onAlbumQueueAdd(List<SearchResult> tracks,
      {required bool atEnd, bool silent = false}) async {
    _exitRadio();
    final l10n = context.l10n;
    await _seedQueueWithCurrent(); // playing outside an empty queue — see it
    // Expand each track into its subsongs (matches _startAlbumQueue) so a
    // multi-subsong file within the album queues every subsong, not just one.
    final expanded = <SearchResult>[];
    for (final t in tracks) {
      expanded.addAll(await _subsongEntries(t));
    }
    // seq assigned in canonical (album/subsong) order first, so turning
    // shuffle back off can restore it — only the INSERTION order is shuffled.
    var items = [for (final s in expanded) _OnlineItem(s, _seq())];
    if (_shuffleEnabled) items = items.toList()..shuffle();
    if (atEnd) {
      _queue.addAll(items);
    } else {
      final insertAt = _queue.isEmpty ? 0 : (_queueIdx + 1).clamp(0, _queue.length);
      _queue.insertAll(insertAt, items);
      if (insertAt <= _queueIdx) _queueIdx += items.length;
    }
    _syncControllerQueue();
    _refreshQueueNav();
    if (!mounted || silent) return; // silent: bulk background appends (featured
    // play-all) don't want one snackbar per album — subsong expansion awaited,
    // the shell may also be gone by now.
    final label =
        atEnd ? l10n.shellAlbumQueuedAtEnd : l10n.shellAlbumQueuedNext;
    AppSnack.show(context, label, duration: const Duration(seconds: 2));
  }

  /// « Lire ensuite » / « Ajouter à la fin » pour des pistes LOCALES.
  ///
  /// Calqué sur [_onAlbumQueueAdd], à deux différences près: les pistes sont
  /// déjà DÉPLIÉES (tracksForLocalPaths a fait les sous-chansons, les archives
  /// et les M3U), et elles deviennent des _LocalItem et non des _OnlineItem.
  Future<void> _onLocalTracksQueueAdd(List<TrackRecord> tracks,
      {required bool atEnd, bool silent = false}) async {
    if (tracks.isEmpty) return;
    _exitRadio();
    final l10n = context.l10n;
    await _seedQueueWithCurrent(); // jouer hors d'une file vide — l'y remettre
    // seq en ordre canonique d'abord, pour que couper le shuffle restaure
    // l'ordre; seule l'INSERTION est mélangée.
    var items = [for (final t in tracks) _LocalItem(t, _seq())];
    if (_shuffleEnabled) items = items.toList()..shuffle();
    if (atEnd) {
      _queue.addAll(items);
    } else {
      final insertAt = _queue.isEmpty ? 0 : (_queueIdx + 1).clamp(0, _queue.length);
      _queue.insertAll(insertAt, items);
      if (insertAt <= _queueIdx) _queueIdx += items.length;
    }
    _syncControllerQueue();
    _refreshQueueNav();
    if (!mounted || silent) return;
    AppSnack.show(context, l10n.shellTracksQueued(tracks.length),
        duration: const Duration(seconds: 2));
  }

  /// La feuille « Lire maintenant / ensuite / à la fin » est-elle ouverte pour
  /// un dépôt en cours, et ce qu'elle décidera. Un DEUXIÈME dépôt pendant
  /// qu'elle est affichée (deux glissers à la suite, un dossier puis un
  /// fichier) ne doit pas empiler une seconde feuille par-dessus la première:
  /// ses pistes rejoignent le lot, et le choix déjà demandé vaut pour tout.
  bool _dropChoiceOpen = false;
  final List<TrackRecord> _droppedBatch = [];

  /// Files handed to the app from outside the UI: dropped on the window, on
  /// the Dock icon, or opened with the Finder.
  ///
  /// Le geste POSE des fichiers, il ne dit pas QUAND les entendre — d'où la
  /// même feuille que partout ailleurs. Elle répond `now` d'elle-même quand il
  /// n'y a ni file ni lecture (rien à protéger, donc rien à demander), ce qui
  /// garde le comportement d'avant sur une app fraîchement lancée; et une
  /// feuille écartée n'enfile RIEN — c'est un refus, pas un « à la fin » par
  /// défaut.
  Future<void> _openLocalPaths(List<String> paths) async {
    if (paths.isEmpty || !mounted) return;
    final l10n      = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final tracks = await tracksForLocalPaths(
      paths,
      controller: _controller,
      // Un dépôt filtre TOUJOURS, à un fichier comme à cent: le filtre doit
      // passer AVANT la feuille de choix, sinon on demande où ranger une
      // pochette. Rien ne reste ⇒ `nothingPlayable` le dit et on s'arrête là.
      filterCandidates: true,
      report: (n) => AppSnack.showOn(messenger, switch (n) {
        LocalOpenNotice.extractingArchive  => l10n.homeExtractingArchive,
        LocalOpenNotice.archiveEmpty       => l10n.homeArchiveEmpty,
        LocalOpenNotice.playlistUnreadable => l10n.homePlaylistUnreadable,
        LocalOpenNotice.presetsImported    => l10n.pmPresetsImported,
        LocalOpenNotice.nothingPlayable    => l10n.homeNothingPlayable,
      }, duration: const Duration(seconds: 2)),
    );
    if (!mounted || tracks.isEmpty) return;

    if (_dropChoiceOpen) {
      _droppedBatch.addAll(tracks);
      return;
    }
    _droppedBatch
      ..clear()
      ..addAll(tracks);

    PlayChoice? choice;
    _dropChoiceOpen = true;
    try {
      choice = await showPlayChoiceSheet(
        context,
        title: tracks.length == 1
            ? tracks.first.displayTitle
            // Même libellé que le sélecteur de fichiers pour le même cas.
            : l10n.albumTrackCount(tracks.length),
      );
    } finally {
      _dropChoiceOpen = false;
    }
    // Relu APRÈS la feuille: il a pu grossir pendant qu'elle était ouverte.
    final batch = List<TrackRecord>.of(_droppedBatch);
    _droppedBatch.clear();
    if (choice == null || batch.isEmpty || !mounted) return;

    _exitRadio();
    switch (choice) {
      case PlayChoice.now:
        await _startLocalTrackQueue(context, batch);
        return;
      case PlayChoice.next:
        await _onLocalTracksQueueAdd(batch, atEnd: false, silent: true);
      // `open` n'est pas proposé ici (pas d'openLabel): un dépôt n'a pas
      // d'écran de détail où aller.
      case PlayChoice.end:
      case PlayChoice.open:
        await _onLocalTracksQueueAdd(batch, atEnd: true, silent: true);
    }
    if (!mounted) return;
    // Le compte RÉEL, pas celui montré par la feuille: un dépôt arrivé
    // entre-temps a rejoint le lot.
    AppSnack.showOn(messenger, l10n.shellTracksQueued(batch.length),
        duration: const Duration(seconds: 2));
  }

  /// A track can be PLAYING while [_queue] is empty: the single-file play
  /// paths (_onSingleLocalFileReady, rail single fallbacks) clear the queue
  /// and play OUTSIDE it. A later "Lire ensuite / à la fin" would then land
  /// alone in the empty queue — reading as if it had REPLACED the current
  /// track, and "next" would jump into the insert instead of after it. Seed
  /// the queue with the playing track first, so inserts go after it.
  Future<void> _seedQueueWithCurrent() async {
    if (_queue.isNotEmpty || !_controller.hasFile) return;
    final path = _controller.filePath;
    if (path == null || path.isEmpty) return;
    final sub = _controller.subsongIdx;
    TrackRecord? row;
    try {
      row = (await LocalDb.instance.getTracksForFile(path))
          .where((t) => t.subsongIdx == sub)
          .firstOrNull;
    } catch (_) {}
    row ??= TrackRecord(
      id:         '',
      filePath:   path,
      entryPath:  '',
      subsongIdx: sub,
      title:      _controller.displayTitle,
      artist:     _controller.currentArtist,
      metaAlbum:  _controller.currentAlbum,
      albumId:    _controller.currentAlbumId,
      onlineId:   _controller.currentOnlineId,
      source:     _controller.currentOnlineId != null ? 'online' : 'local',
      isFavorite: false,
      inLibrary:  false,
      playCount:  0,
    );
    _queue.add(_LocalItem(row, _seq()));
    _queueIdx = 0;
    _controller.updateQueueIdx(0);
  }

  /// Queue-add for LOCAL rows (rail popups): the files are already on disk,
  /// so unlike [_onQueueAdd] there is nothing to download. Same insertion
  /// semantics: next = right after the playing index, end = appended; empty
  /// queue and nothing playing = just start them.
  Future<void> _onLocalQueueAdd(List<TrackRecord> tracks,
      {required bool atEnd}) async {
    if (tracks.isEmpty) return;
    _exitRadio();
    final l10n = context.l10n;
    if (_queue.isEmpty && !_controller.hasFile) {
      await _startLocalTrackQueue(context, tracks);
      return;
    }
    await _seedQueueWithCurrent();
    var items = [for (final t in tracks) _LocalItem(t, _seq())];
    if (_shuffleEnabled) items = items.toList()..shuffle();
    if (atEnd) {
      _queue.addAll(items);
    } else {
      final insertAt =
          _queue.isEmpty ? 0 : (_queueIdx + 1).clamp(0, _queue.length);
      _queue.insertAll(insertAt, items);
      if (insertAt <= _queueIdx) _queueIdx += items.length;
    }
    _syncControllerQueue();
    _refreshQueueNav();
    if (!mounted) return;
    AppSnack.show(
        context,
        tracks.length == 1
            ? (atEnd
                ? l10n.shellTrackQueuedAtEnd(tracks.first.displayTitle)
                : l10n.shellTrackQueuedNext(tracks.first.displayTitle))
            : (atEnd ? l10n.shellAlbumQueuedAtEnd : l10n.shellAlbumQueuedNext),
        duration: const Duration(seconds: 2));
  }

  Future<void> _onQueueAdd(SearchResult r, {required bool atEnd}) async {
    _exitRadio();
    final l10n      = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final label     = atEnd ? l10n.shellAddingToQueue : l10n.shellAddingNext;

    // Show a persistent loading bar while downloading.
    AppSnack.showOn(messenger, label, duration: const Duration(seconds: 30));

    try {
      // Ensure file (or archive) is present locally before inserting.
      await RewampDb.downloadToLibrary(r);
    } on DownloadCancelledException {
      // The user pressed ✕ on the banner: not a failure, and saying so would
      // be reporting their own gesture back at them.
      messenger.clearSnackBars();
      return;
    } catch (e) {
      messenger.clearSnackBars();
      AppSnack.showOn(messenger, l10n.shellDownloadFailed(e.toString()), duration: const Duration(seconds: 4));
      return;
    }

    messenger.clearSnackBars();

    if (!mounted) return; // the download above was awaited
    if (_queue.isEmpty && !_controller.hasFile) {
      _startAlbumQueue(context, [r]);
      return;
    }
    await _seedQueueWithCurrent(); // playing outside an empty queue — see it

    // Multi-subsong file: queue every subsong (matches _startAlbumQueue).
    final expanded = await _subsongEntries(r);
    var items = [for (final s in expanded) _OnlineItem(s, _seq())];
    if (_shuffleEnabled) items = items.toList()..shuffle();
    if (atEnd) {
      _queue.addAll(items);
    } else {
      final insertIdx = _queue.isEmpty ? 0 : (_queueIdx + 1).clamp(0, _queue.length);
      _queue.insertAll(insertIdx, items);
      if (insertIdx <= _queueIdx) _queueIdx += items.length;
    }
    _syncControllerQueue();
    _refreshQueueNav();
    AppSnack.showOn(messenger, atEnd
          ? l10n.shellTrackQueuedAtEnd(r.displayTitle)
          : l10n.shellTrackQueuedNext(r.displayTitle), duration: const Duration(seconds: 2));
  }

  void _onFileReady(
    String path,
    String label, {
    String? artist,
    List<String>? artistNames,
    List<String>? artistIds,
    String? album,
    String? albumId,
    String? formatExt,
    String? onlineId,
    String? artworkUrl,
    String? artworkTargetDir,
    int subsongIdx = 0,
    double? durationS,
    int? subsongCount,
  }) {
    _playingContainer = null; // standalone single-file play, not a container
    // The file may simply not be HERE. An account syncs its history and its
    // library between devices, so a row can name a track this device never
    // downloaded - and this path used to hand that path straight to the
    // decoder, which failed with a "format" error for a file it never read.
    //
    // The check lives in THIS funnel rather than in one of its callers: every
    // screen that plays a known file goes through here (library, playlists,
    // recents, search history, an .m3u entry), and putting it upstream would
    // have covered exactly the one screen it was written for. Free for the
    // normal case - a download that just finished leaves the file right there.
    if (_recoverMissingFile(
      path:       path,
      label:      label,
      onlineId:   onlineId,
      artist:     artist,
      album:      album,
      albumId:    albumId,
      formatExt:  formatExt,
      artworkUrl: artworkUrl,
      subsongIdx: subsongIdx,
    )) {
      return;
    }
    _controller.loadFile(
      path,
      label,
      subsongIdx:       subsongIdx,
      artist:           artist,
      artistNames:      artistNames,
      artistIds:        artistIds,
      metaAlbum:        album,
      metaAlbumId:      albumId,
      formatExt:        formatExt,
      subsongCount:     subsongCount,
      onlineId:         onlineId,
      source:           onlineId != null ? 'online' : 'local',
      artworkUrl:       artworkUrl,
      artworkTargetDir: artworkTargetDir,
      durationS:        durationS,
      recordAsAlbum:    false,
    );
    if (onlineId != null) {
      // Online file: derive collection + platform from the reliable on-disk path.
      final (col, plat) = _albumContextFromPath(path, formatExt);
      // forPath: cette origine a été calculée APRÈS un await; sans ça, une
      // réponse en retard repeint la ligne du morceau SUIVANT (mig 55).
      _controller.setAlbumContext(
          collectionSlug: col, platformName: plat, forPath: path);
    } else if (album != null) {
      _lookupAlbumContext(album);
    }
  }

  /// Forces a re-download of the CURRENT single online file (player options →
  /// "re-download"): re-resolve its current server URL, delete the local copy,
  /// and refetch + replay in place. For single-song direct files only — the
  /// player gates the option on that (see _canRedownload).
  Future<void> _redownloadCurrentTrack() async {
    final id      = _controller.currentOnlineId;
    final oldPath = _controller.filePath;
    if (id == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final s = (await RewampDb.getSongContext(id))?.song;
    if (s == null || s.downloadUrl == null || s.downloadUrl!.isEmpty) {
      // Album-archive member / no direct URL → can't refetch a single file.
      AppSnack.showOn(messenger, l10n.playerRedownloadUnavailable);
      return;
    }
    _controller.stop();
    // Delete the current file + the freshly-derived path so downloadAndPlay
    // refetches instead of serving the cached copy (the name may have changed).
    final paths = <String>{
      if (oldPath != null && oldPath.isNotEmpty) oldPath,
      await RewampDb.localPath(s),
    };
    for (final path in paths) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    if (!mounted) return;
    await downloadAndPlay(context, s, _onFileReady);
  }

  void _downloadLibraryTrack(BuildContext ctx, LibraryItem item) {
    // Track library rows are keyed by libraryRefId = '<onlineId>?subsong=<idx>'
    // (so each subsong is its own favourite). The DB tracks table stores the
    // BARE online id — split the key back apart, else getTrackByOnlineId never
    // matches (cache miss → slow path) and the subsong index is lost (always
    // played track 0).
    final (songId, parsedIdx) = splitLibraryRefId(item.refId);
    final subsongIdx = parsedIdx ?? 0;
    final r = SearchResult(
      songId:      songId,
      collection:  item.collectionSlug ?? '',
      title:       item.name,
      filename:    item.filename ?? item.name,
      album:       item.album,
      albumId:     item.albumId,
      formatExt:   item.formatExt ?? '',
      downloadUrl: item.downloadUrl,
      fileSize:    0,
      year:        null,
      totalCount:  0,
      artistNames: item.artist != null ? [item.artist!] : [],
      platform:    item.platformName,
      artworkUrl:  item.artworkUrl,
      subsongIdx:  subsongIdx,
    );
    // Single-track play: clear any leftover queue first — the cached replay
    // path (_onSingleLocalFileReady) does, but this download path didn't, so
    // a stale 19-subsong queue from an earlier album play stayed attached to
    // the newly played library track.
    _queue.clear();
    _queueIdx = -1;
    _controller.clearQueue();
    _refreshQueueNav();
    _downloadAndPlayOnline(ctx, r);
  }

  /// Origine (collection/plateforme) d'un album, cherchée en base — donc de
  /// façon ASYNCHRONE, et c'est tout le problème: la réponse arrive quand elle
  /// arrive, et `setAlbumContext` l'écrit sur le morceau COURANT, pas sur celui
  /// qui l'a demandée. Enchaîner Commando (C64) puis Monkey Island (Amiga)
  /// suffisait à estampiller « c64 » sur une ligne du module Amiga — et comme
  /// l'écriture d'origine est en COALESCE, la valeur fausse restait, servait le
  /// placeholder C64 au morceau suivant, et se réinstallait à chaque relance
  /// depuis « écoutés récemment ». La demande est donc DATÉE par le morceau qui
  /// jouait quand elle est partie, et abandonnée s'il a changé.
  void _lookupAlbumContext(String albumName) {
    final forPath = _controller.filePath;
    LocalDb.instance.getLibraryAlbum(albumName).then((li) {
      if (li == null) return;
      _controller.setAlbumContext(
        collectionSlug: li.collectionSlug,
        platformName:   li.platformName,
        forPath:        forPath,
      );
    });
  }

  /// Infers (collection, platform) from an online file's on-disk path:
  ///   online/<collection>/<artist>/<platform|formatExt>/<album>/<file>
  /// The level-3 segment is the platform OR the format ext (see
  /// RewampDb._dirSegments) — it's a platform only when it isn't the format ext.
  /// This is the reliable source: the path is always present, unlike the
  /// library row (which may be missing or have a null platform).
  ///
  /// Album-grain zip collections use a flattened, artist-free layout
  /// (online/<collection>/<albumKey>/<file>) — no platform segment there, so
  /// return only the collection (idx+3 would be the filename).
  (String?, String?) _albumContextFromPath(String path, String? formatExt) {
    final parts = path.split(p.separator);
    final idx   = parts.indexOf('online');
    if (idx < 0) return (null, null);
    String? col;
    String? plat;
    if (idx + 1 < parts.length) col = parts[idx + 1];
    if (col != null && collectionIsAlbumGrain(col.toLowerCase())) {
      return (col, null);
    }
    // Layout par ALBUM (online/<col>/<albumId>/…, albums identifiés hors
    // album-grain): pas de segment artiste/plateforme — sans cette garde, le
    // sous-dossier d'archive ou le fichier passait pour une « plateforme ».
    if (idx + 2 < parts.length &&
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
            .hasMatch(parts[idx + 2].toLowerCase())) {
      return (col, null);
    }
    if (idx + 3 < parts.length) {
      final level3 = parts[idx + 3];
      final ext = (formatExt ?? _pathExt(path)).toLowerCase();
      if (level3.toLowerCase() != ext) plat = level3;
    }
    return (col, plat);
  }

  /// Same as [_onFileReady] but records the play against the album
  /// (updates recent_albums.last_played_at, not track.last_played_at).
  /// Used by all album-queue play paths.
  void _onFileReadyAsAlbum(
    String path,
    String label, {
    String? artist,
    List<String>? artistNames,
    List<String>? artistIds,
    String? album,
    String? albumId,
    String? formatExt,
    String? onlineId,
    String? artworkUrl,
    String? artworkTargetDir,
    int subsongIdx = 0,
    double? durationS,
    int? subsongCount,
  }) {
    // The file may simply not be HERE. An account syncs its history and its
    // library between devices, so a row can name a track this device never
    // downloaded - and this path used to hand that path straight to the
    // decoder, which failed with a "format" error for a file it never read.
    //
    // The check lives in THIS funnel rather than in one of its callers: every
    // screen that plays a known file goes through here (library, playlists,
    // recents, search history, an .m3u entry), and putting it upstream would
    // have covered exactly the one screen it was written for. Free for the
    // normal case - a download that just finished leaves the file right there.
    if (_recoverMissingFile(
      path:       path,
      label:      label,
      onlineId:   onlineId,
      artist:     artist,
      album:      album,
      albumId:    albumId,
      formatExt:  formatExt,
      artworkUrl: artworkUrl,
      subsongIdx: subsongIdx,
    )) {
      return;
    }
    _controller.loadFile(
      path,
      label,
      subsongIdx:       subsongIdx,
      artist:           artist,
      artistNames:      artistNames,
      artistIds:        artistIds,
      metaAlbum:        album,
      metaAlbumId:      albumId,
      formatExt:        formatExt,
      subsongCount:     subsongCount,
      onlineId:         onlineId,
      source:           onlineId != null ? 'online' : 'local',
      artworkUrl:       artworkUrl,
      artworkTargetDir: artworkTargetDir,
      durationS:        durationS,
      recordAsAlbum:    true,
    );
  }

  static const _kSidExts = {
    'sid',
    'psid',
    'rsid',
    'mus',
    'str',
    'dat',
    'prg',
    'p00'
  };

  /// Like _onFileReady but also clears the queue.
  /// Used when a single local file is opened via the file picker so that
  /// prev/next from a previous album don't linger.
  void _onSingleLocalFileReady(
    String path,
    String label, {
    String? artist,
    List<String>? artistNames,
    List<String>? artistIds,
    String? album,
    String? albumId,
    String? formatExt,
    String? onlineId,
    String? artworkUrl,
    String? artworkTargetDir,
    int subsongIdx = 0,
    double? durationS,
    int? subsongCount,
  }) {
    _queue.clear();
    _queueIdx = -1;
    _controller.clearQueue();
    _refreshQueueNav();
    _onFileReady(
      path,
      label,
      artist:           artist,
      artistNames:      artistNames,
      artistIds:        artistIds,
      album:            album,
      albumId:          albumId,
      formatExt:        formatExt,
      onlineId:         onlineId,
      artworkUrl:       artworkUrl,
      artworkTargetDir: artworkTargetDir,
      subsongIdx:       subsongIdx,
      durationS:        durationS,
      subsongCount:     subsongCount,
    );
    final ext = (formatExt ?? _pathExt(path)).toLowerCase();
    if (_kSidExts.contains(ext)) {
      _applyLocalSidMeta(path);
    }
  }


  /// The catalogue row for a file that is NOT on this device, when the
  /// catalogue can still hand it back. Null when nothing identifies it there —
  /// a file that only ever existed on another device, which no download can
  /// recover.
  ///
  /// Everything but the id is derived from the PATH, and each piece is there
  /// for a reason paid at least once:
  ///  * the collection ('…/online/<collection>/…') scopes the album
  ///    re-resolution, which otherwise matches a homonym in another collection;
  ///  * an album-grain collection files its tracks under
  ///    '…/online/<collection>/<albumId>/…', and that key IS the album uuid
  ///    when it was known at download time — free, offline, and exactly what
  ///    the re-resolution wants;
  ///  * the QUEUE's album is the last resort, and only for a track that really
  ///    belongs to one (it then carries the album NAME too). `_queueAlbumId`
  ///    outlives the album that set it, and here it does not merely mislabel a
  ///    row: this id DECIDES WHERE THE FILE IS DOWNLOADED.
  /// A play asked for a file that is not on this device: fetch it from the
  /// catalogue and play it, or say plainly that it cannot be fetched. Returns
  /// true when it took over, i.e. when the caller must not go on to load.
  ///
  /// Both outcomes matter. A track can be missing here and perfectly present
  /// elsewhere - an account syncs its history and its library across devices -
  /// and a file that only ever existed on another device is recoverable by
  /// nobody, which is worth saying rather than failing as a format error.
  /// The path a catalogue fetch is currently trying to restore. See the guard
  /// in [_recoverMissingFile].
  String? _recoveringPath;

  bool _recoverMissingFile({
    required String path,
    required String label,
    String? onlineId,
    String? artist,
    String? album,
    String? albumId,
    String? formatExt,
    String? artworkUrl,
    int subsongIdx = 0,
  }) {
    if (File(path).existsSync()) {
      _recoveringPath = null;
      return false;
    }
    // Re-entrancy guard, and it is not theoretical: the download hands the file
    // back through _onFileReadyAsAlbum, which runs this same check. If the file
    // ever lands somewhere other than the path we were asked for, the two would
    // call each other for ever, downloading each time. One attempt per path.
    if (_recoveringPath == path) {
      _recoveringPath = null;
      if (mounted) {
        AppSnack.show(context, context.l10n.playbackFileMissing(label),
            duration: const Duration(seconds: 4));
      }
      return true;
    }
    final row = _catalogueRowForMissingFile(
      path:       path,
      title:      label,
      onlineId:   onlineId,
      artist:     artist,
      album:      album,
      albumId:    albumId,
      formatExt:  formatExt,
      artworkUrl: artworkUrl,
      subsongIdx: subsongIdx,
    );
    if (row != null) {
      _recoveringPath = path;
      unawaited(downloadAndPlay(context, row, _onFileReadyAsAlbum));
      return true;
    }
    if (mounted) {
      AppSnack.show(context, context.l10n.playbackFileMissing(label),
          duration: const Duration(seconds: 4));
    }
    return true;
  }

  SearchResult? _catalogueRowForMissingFile({
    required String path,
    required String title,
    String? onlineId,
    String? artist,
    String? album,
    String? albumId,
    String? formatExt,
    String? artworkUrl,
    int subsongIdx = 0,
  }) {
    if (onlineId == null || onlineId.isEmpty) return null;
    if (catalogueSongId(onlineId) == null) return null;   // a path, not an id
    final (pathColl, pathPlat) = _albumContextFromPath(path, formatExt);
    final pathFromDisk = () {
      final parts = path.split(p.separator);
      final i = parts.indexOf('online');
      return (i >= 0 && i + 2 < parts.length)
          ? catalogueSongId(parts[i + 2])
          : null;
    }();
    return SearchResult(
      songId:      onlineId,
      collection:  pathColl ?? '',
      title:       title,
      filename:    p.basename(path),
      album:       album,
      albumId: albumId ??
          pathFromDisk ??
          ((album ?? '').isNotEmpty ? _queueAlbumId : null),
      formatExt:   formatExt ?? _pathExt(path),
      downloadUrl: null,
      fileSize:    0,
      year:        null,
      totalCount:  0,
      artistNames: artist != null ? [artist] : const [],
      platform:    pathPlat,
      artworkUrl:  artworkUrl,
      subsongIdx:  subsongIdx,
    );
  }

  static String _pathExt(String path) {
    final dot = path.lastIndexOf('.');
    return dot >= 0 ? path.substring(dot + 1) : '';
  }

  // ── Queue management ────────────────────────────────────────────────────────

  /// What the sidebar queue panel shows: the real queue, or a one-entry
  /// stand-in for the currently loaded track when a single file is playing
  /// (single-track plays deliberately clear the queue).
  List<QueueEntry> _sidebarQueue() {
    if (_controller.queue.isNotEmpty) return _controller.queue;
    return [
      QueueEntry(
          title: _controller.displayTitle, artist: _controller.currentArtist),
    ];
  }

  /// Maps the live queue to tracks-table ids, in queue order, minting rows
  /// for entries never played yet (same helpers as the playlist picker).
  Future<List<String>> _queueTrackIds() async {
    final ids = <String>[];
    for (final it in List<_QueueItem>.of(_queue)) {
      switch (it) {
        case _OnlineItem(:final result):
          ids.addAll(await trackIdsForResults([result]));
        case _LocalItem(:final track):
          ids.addAll(await trackIdsForRecords([track]));
      }
    }
    return ids;
  }

  void _syncControllerQueue() {
    String fileOf(_QueueItem it) => switch (it) {
      _OnlineItem(:final result) => result.filename,
      _LocalItem(:final track)   => p.basename(track.filePath),
    };
    String? albumOf(_QueueItem it) => switch (it) {
      _OnlineItem(:final result) => result.album,
      _LocalItem(:final track)   => track.metaAlbum,
    };
    // A file appearing on more than one queue entry = several subsongs of ONE
    // module → show the FILE as the context line (which module the subsong is
    // from); otherwise show the album.
    final fileCounts = <String, int>{};
    for (final it in _queue) {
      final f = fileOf(it);
      fileCounts[f] = (fileCounts[f] ?? 0) + 1;
    }
    _controller.setQueue(
      _queue.map((item) {
        final f = fileOf(item);
        final subtitle = (fileCounts[f] ?? 0) > 1 ? f : (albumOf(item) ?? f);
        // Artwork context for the row thumbnail (falls back to the themed
        // per-platform placeholder when nothing resolves).
        final (art, alb, local, plat, fmt) = switch (item) {
          _OnlineItem(:final result) => (
              result.artworkUrl,
              result.album,
              result.localPath,
              result.platform,
              result.formatExt,
            ),
          _LocalItem(:final track) => (
              track.artworkUrl,
              track.metaAlbum,
              track.filePath,
              null,
              track.formatExt,
            ),
        };
        return QueueEntry(
          id: item.uid,
          title: item.title,
          artist: item.artist,
          subtitle: subtitle,
          artworkUrl: art,
          album: alb,
          localFilePath: local,
          platformName: plat,
          formatHint: fmt,
        );
      }).toList(),
      currentIdx: _queueIdx,
    );
  }

  void _refreshQueueNav() {
    // Radio never ends: keep "next" live even when the rolling window hasn't
    // been refilled yet (_playNext resolves one on demand in that case).
    final radio = _radioPool.isNotEmpty;
    _controller.setQueueNav(
      next: (radio || _queueIdx < _queue.length - 1) ? _playNext : null,
      prev: _queueIdx > 0 ? _playPrev : null,
    );
    // Every queue mutation path (start/add/clear/shuffle/jump) ends here —
    // single choke point for the cross-launch snapshot.
    _persistQueue();
  }

  // ── Queue persistence across launches ──────────────────────────────────────

  /// Snapshot the queue + current index (fire-and-forget JSON write).
  /// Online items keep their full SearchResult; local items only their DB
  /// track id (re-fetched at restore, so metadata stays current).
  void _persistQueue() {
    final items = <Map<String, dynamic>>[];
    for (final it in _queue) {
      switch (it) {
        case _OnlineItem(:final result):
          items.add({'t': 'online', 's': it.seq, 'r': result.toJson()});
        case _LocalItem(:final track):
          // Full record, not just the id: local album/folder queues are
          // synthesized on the fly — only tracks that actually PLAYED have a
          // row in the tracks table, so an id-only snapshot lost every other
          // queue entry at restore.
          items.add({
            't': 'local',
            's': it.seq,
            'id': track.id,
            'm': track.toPersistMap(),
          });
      }
    }
    QueuePersistence.save({'v': 1, 'idx': _queueIdx, 'items': items});
  }

  /// Restore the saved queue at launch and reload the track that was playing —
  /// left PAUSED (restoring state, not blasting audio at startup). Skipped
  /// entirely when the previous session crashed during a track load (see
  /// QueuePersistence — the flag was consumed by init() in main()).
  Future<void> _restoreQueueAtLaunch() async {
    if (QueuePersistence.crashedLastLaunch) {
      // Drop the snapshot too: restoring it later would reload the same track.
      await QueuePersistence.clear();
      return;
    }
    final state = await QueuePersistence.load();
    if (state == null) return;
    final rawItems = state['items'];
    if (rawItems is! List || rawItems.isEmpty) return;
    final items = <_QueueItem>[];
    for (final e in rawItems) {
      if (e is! Map) continue;
      try {
        final m = e.cast<String, dynamic>();
        // The saved ORDER is the shuffled one; `seq` is the proper order the
        // shuffle button restores, so it has to survive the snapshot too —
        // without it a restored queue un-shuffled back into its shuffled
        // order, which reads as the button doing nothing. Absent (snapshot
        // written by an older build) → fall back to the position.
        final seq = (m['s'] as num?)?.toInt() ?? _seq();
        if (m['t'] == 'online' && m['r'] is Map) {
          items.add(_OnlineItem(
              SearchResult.fromJson((m['r'] as Map).cast<String, dynamic>()),
              seq));
        } else if (m['t'] == 'local' && m['id'] is String) {
          // Prefer the live DB row (metadata stays current); fall back to the
          // serialized record — synthesized queue entries have no DB row.
          final tr = await LocalDb.instance.getTrackById(m['id'] as String) ??
              (m['m'] is Map
                  ? TrackRecord.fromMap((m['m'] as Map).cast<String, dynamic>())
                  : null);
          if (tr != null) items.add(_LocalItem(tr, seq));
        }
      } catch (err) {
        debugPrint('[queue-persist] item skipped: $err');
      }
    }
    if (items.isEmpty || !mounted) return;
    // A track the user started before the restore finished wins.
    if (_queue.isNotEmpty || _controller.hasFile) return;
    // Anything queued from now on must sort AFTER the restored entries.
    for (final it in items) {
      if (it.seq >= _nextQueueSeq) _nextQueueSeq = it.seq + 1;
    }
    _queue
      ..clear()
      ..addAll(items);
    _prefetchFailed.clear();
    final rawIdx = (state['idx'] as num?)?.toInt() ?? 0;
    _queueIdx = rawIdx.clamp(0, items.length - 1);
    _syncControllerQueue();
    _refreshQueueNav();
    // Prime the player to DISPLAY the restored current track, PAUSED, WITHOUT
    // touching the native decoder. Playback starts on the first play press
    // (onResumePrimed → _playAt). Auto-playing at launch leaked audio on iOS and
    // brought up the media session, which tripped Android's foreground-service
    // watchdog (ForegroundServiceDidNotStartInTimeException → crash loop).
    final cur = _queue[_queueIdx];
    switch (cur) {
      case _OnlineItem(:final result):
        String fp;
        try {
          fp = result.localPath ?? await RewampDb.localPath(result);
        } catch (_) {
          fp = result.filename;
        }
        if (!mounted) return;
        _controller.primeForDisplay(
          filePath:   fp,
          label:      result.displayTitle,
          artist:     result.artistLabel.isEmpty ? null : result.artistLabel,
          artistNames: result.artistNames,
          artistIds:   result.artistIds,
          album:      result.album,
          albumId:    result.albumId,
          onlineId:   result.songId,
          artworkUrl: result.artworkUrl,
          subsongIdx: result.subsongIdx,
          durationS:  result.durationMs != null ? result.durationMs! / 1000.0 : null,
        );
        // Collection/platform for the primed screen (source line + album nav),
        // same on-disk-path preference as _playAt.
        final (col, plat) = _albumContextFromPath(fp, result.formatExt);
        _controller.setAlbumContext(
            collectionSlug: col ?? result.collection,
            platformName:   plat ?? result.platform, year: result.year,
            forPath: fp);
      case _LocalItem(:final track):
        _controller.primeForDisplay(
          filePath:   track.filePath,
          label:      track.displayTitle,
          artist:     track.artist,
          album:      track.metaAlbum,
          albumId:    track.albumId,
          onlineId:   track.onlineId,
          artworkUrl: track.artworkUrl,
          subsongIdx: track.subsongIdx,
          durationS:  track.durationS,
        );
        if (track.source == 'online') {
          final (col, plat) =
              _albumContextFromPath(track.filePath, track.formatExt);
          _controller.setAlbumContext(
              collectionSlug: col, platformName: plat,
              forPath: track.filePath);
        }
    }
  }

  // ── Shuffle ──────────────────────────────────────────────────────────────
  //
  // The queue array itself is physically reordered (no separate play-order
  // indirection) so _queueIdx / _playAt(i) / next/prev-by-index keep working
  // unchanged. Each item's `seq` records its original ("proper") position —
  // set once at creation, never mutated — so turning shuffle off can always
  // restore it exactly, including the internal order of an album's tracks or
  // a multi-subsong file's subsongs (they got consecutive seqs when added).

  void _toggleShuffle() {
    _shuffleEnabled = !_shuffleEnabled;
    UserSettings.instance.transportShuffle = _shuffleEnabled;
    if (_shuffleEnabled) {
      _shuffleQueue();
    } else {
      _unshuffleQueue();
    }
    _controller.setShuffleEnabled(_shuffleEnabled);
    _syncControllerQueue();
    _refreshQueueNav();
  }

  /// Shuffles the queue in place, keeping the currently-playing item at its
  /// own index (so nothing about "now playing" changes, only its neighbours).
  void _shuffleQueue() {
    if (_queue.length < 2) return;
    if (_queueIdx < 0 || _queueIdx >= _queue.length) {
      _queue.shuffle();
      return;
    }
    final current = _queue[_queueIdx];
    final others = [
      for (var i = 0; i < _queue.length; i++)
        if (i != _queueIdx) _queue[i],
    ]..shuffle();
    _queue
      ..clear()
      ..addAll(others.take(_queueIdx))
      ..add(current)
      ..addAll(others.skip(_queueIdx));
  }

  /// Restores the queue's original insertion order (per-item `seq`).
  void _unshuffleQueue() {
    final current = (_queueIdx >= 0 && _queueIdx < _queue.length)
        ? _queue[_queueIdx]
        : null;
    _queue.sort((a, b) => a.seq.compareTo(b.seq));
    if (current != null) _queueIdx = _queue.indexOf(current);
  }

  // ── Endless radio ──────────────────────────────────────────────────────────

  /// Start (or restart) an endless station over [pool]. Seeds the queue with a
  /// single resolved track, plays it, then lets the rolling refill fill ahead.
  Future<void> _startFeaturedRadio(List<FeaturedSlot> pool) async {
    if (pool.isEmpty) return;
    _radioPool = List.of(pool);
    _radioResolving = false;
    final first = await _radioResolveOne();
    if (!mounted || _radioPool.isEmpty) return;
    if (first == null) {
      _radioPool = const [];
      AppSnack.show(context, context.l10n.homeAlbumLoadFailed);
      return;
    }
    _queue
      ..clear()
      ..add(_OnlineItem(first, _seq()));
    _prefetchFailed.clear();
    _queueIdx = 0;
    _consecutiveDlFailures = 0;
    _consecutiveLoadFailures = 0;
    _syncControllerQueue();
    _refreshQueueNav();
    await _playAt(0);              // (also kicks off the first _radioRefill)
  }

  /// Leave radio mode (any explicit new play / queue edit). The queue that was
  /// built stays as a normal finite queue.
  void _exitRadio() {
    if (_radioPool.isEmpty) return;
    _radioPool = const [];
    _refreshQueueNav();           // drop the forced-live "next"
  }

  /// Resolve ONE random, directly-playable track from the pool. Picks a random
  /// entry, extracts it if it's a container album (ensureAlbumExtracted is a
  /// no-op for loose-file albums), and returns one random track from it. Tries
  /// a few entries before giving up so one dead album doesn't stall the station.
  Future<SearchResult?> _radioResolveOne() async {
    for (var attempt = 0; attempt < 5 && _radioPool.isNotEmpty; attempt++) {
      final s = _radioPool[_rand.nextInt(_radioPool.length)];
      try {
        List<SearchResult> rows;
        switch (s.kind) {
          case 'album':
            rows = await RewampDb.ensureAlbumExtracted(
                await RewampDb.albumTracks(albumId: s.id, sortBy: 'position'));
          case 'playlist':
            rows = await RewampDb.playlistTracks(s.id);
          default:
            continue;
        }
        if (rows.isEmpty) continue;
        return rows[_rand.nextInt(rows.length)];
      } catch (_) {
        // network / extraction failure on this entry — try another
      }
    }
    return null;
  }

  /// Keep the rolling window filled to [_radioAhead] tracks ahead of the
  /// current one and trimmed to [_radioBehind] behind. One in flight at a time;
  /// re-checked on every advance so it self-corrects if the user outran it.
  Future<void> _radioRefill() async {
    if (_radioResolving) return;
    _radioResolving = true;
    try {
      while (_radioPool.isNotEmpty &&
             (_queue.length - 1 - _queueIdx) < _radioAhead) {
        final r = await _radioResolveOne();
        if (r == null || _radioPool.isEmpty) break;
        _queue.add(_OnlineItem(r, _seq()));
        _trimRadioBehind();
        _syncControllerQueue();
        _refreshQueueNav();
      }
    } finally {
      _radioResolving = false;
    }
  }

  /// Drop the oldest entries once more than [_radioBehind] sit behind current,
  /// keeping the current track playing (index shifts, playback untouched).
  void _trimRadioBehind() {
    while (_queueIdx > _radioBehind) {
      _queue.removeAt(0);
      _queueIdx--;
    }
  }

  // ── Manual queue editing (reorder / remove) ────────────────────────────────
  //
  // The queue is a PLAIN LIST and _queueIdx is a position in it, so every edit
  // has to keep that index pointing at the same track — the alternative (an
  // identity lookup) does not exist here: the same file legitimately appears
  // several times (subsongs, a track queued twice).

  /// [newIndex] is the FINAL position, already adjusted for the item having
  /// left [oldIndex] — that is what ReorderableListView's onReorderItem gives
  /// (its deprecated onReorder made every caller subtract one by hand).
  void _reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex == newIndex ||
        oldIndex < 0 || oldIndex >= _queue.length ||
        newIndex < 0 || newIndex >= _queue.length) {
      return;
    }
    setState(() {
      final item = _queue.removeAt(oldIndex);
      _queue.insert(newIndex, item);
      if (_queueIdx == oldIndex) {
        _queueIdx = newIndex;
      } else {
        if (oldIndex < _queueIdx) _queueIdx--;
        if (newIndex <= _queueIdx) _queueIdx++;
      }
      // The arrangement the user just made IS the queue order now — see the
      // note on _QueueItem.seq: without this, turning shuffle off would re-sort
      // by the original order and undo it.
      for (int i = 0; i < _queue.length; i++) {
        _queue[i].seq = i;
      }
    });
    _syncControllerQueue();
    _refreshQueueNav();
  }

  void _removeFromQueue(Set<int> indices) {
    if (indices.isEmpty || _queue.isEmpty) return;
    final removedCurrent = indices.contains(_queueIdx);
    final removedBefore = indices.where((i) => i < _queueIdx).length;
    // Where the next surviving track lands — out of range when the removal
    // took everything after the current one too.
    final nextIdx = _queueIdx - removedBefore;

    setState(() {
      final kept = <_QueueItem>[];
      for (int i = 0; i < _queue.length; i++) {
        if (!indices.contains(i)) kept.add(_queue[i]);
      }
      _queue
        ..clear()
        ..addAll(kept);
      _queueIdx = _queue.isEmpty
          ? -1
          : (_queueIdx - removedBefore).clamp(0, _queue.length - 1);
    });
    _syncControllerQueue();
    _refreshQueueNav();

    if (!removedCurrent) return;
    // The track that was playing has just left the queue: hand over to the one
    // that shifted into its slot, or fold the player away when there is none.
    if (nextIdx >= 0 && nextIdx < _queue.length) {
      _playAt(nextIdx);
    } else {
      _controller.stopAndTearDown();
    }
  }

  /// Vide la file ET arrête ce qui joue. Les deux vont ensemble: laisser le
  /// morceau en cours ne vide pas la file, ça la vide de tout SAUF de ce qu'on
  /// entend — et la piste restante n'aurait plus ni suivante ni précédente.
  ///
  /// `_exitRadio()` d'abord, sinon la station remplit à nouveau la file dans la
  /// foulée et le geste n'a l'air de rien faire.
  void _clearQueue() {
    _exitRadio();
    setState(() {
      _queue.clear();
      _queueIdx = -1;
      _controller.queueExhausted = false;
    });
    _syncControllerQueue();
    _refreshQueueNav();
    _controller.stopAndTearDown();
  }

  Future<void> _playNext() async {
    // Radio: the rolling refill usually keeps a few tracks ahead, but if the
    // user (or auto-advance) outran it, resolve one right now so the station
    // never dead-ends.
    if (_radioPool.isNotEmpty && _queueIdx + 1 >= _queue.length) {
      final r = await _radioResolveOne();
      if (_radioPool.isEmpty) return;       // radio exited during the resolve
      if (r != null) {
        _queue.add(_OnlineItem(r, _seq()));
        _syncControllerQueue();
        _refreshQueueNav();
      }
    }
    if (_queueIdx + 1 < _queue.length) return _playAt(_queueIdx + 1);
  }

  Future<void> _downloadAndPlayOnline(BuildContext ctx, SearchResult r) async {
    _exitRadio();
    _playingContainer = RewampDb.isContainerRow(r)
        ? (r.subsongIdx != 0 ? r.withSubsong(0) : r)
        : null;
    await downloadAndPlay(ctx, r, _onFileReadyAsAlbum);
    // downloadToLibrary returns instantly here (file just downloaded); use the
    // path to recover the platform, which server browse may not provide. If the
    // download failed, downloadAndPlay already surfaced the error — skip.
    // Archive-based tracks (RSN subsong: no per-track downloadUrl) can't go
    // through downloadToLibrary at all — it throws and flashes a spurious
    // "Téléchargement impossible" banner; resolve the path from the DB instead.
    try {
      final path = (r.downloadUrl != null)
          ? await RewampDb.downloadToLibrary(r)
          : ((await LocalDb.instance.getTrackByOnlineId(r.songId))?.filePath);
      if (path == null) return;
      final (col, plat) = _albumContextFromPath(path, r.formatExt);
      _controller.setAlbumContext(
          collectionSlug: col ?? r.collection, platformName: plat ?? r.platform,
          year: r.year, forPath: path);
    } catch (_) {}
  }
  Future<void> _playPrev() => _playAt(_queueIdx - 1);

  /// Restores the queue counter/highlight to [idx] (the track actually playing)
  /// after a failed jump left it on an unplayable entry. No-op when nothing is
  /// playing (nothing to stay on) or [idx] is out of range.
  void _restoreQueueIdx(int idx) {
    if (idx < 0 || idx >= _queue.length || !_controller.hasFile) return;
    _queueIdx = idx;
    _controller.updateQueueIdx(idx);
    _refreshQueueNav();
  }

  /// Plays queue entry [i]. [revertTo] is the index to fall back to if the whole
  /// attempt fails (no retry, no advance) — so a manual jump to an UNPLAYABLE
  /// track doesn't leave the player's counter/highlight stranded on it while the
  /// audio (and title/artwork) stay on the track that's actually still playing.
  /// Threaded through the auto-advance chain so a run of failures restores to the
  /// track that was playing BEFORE the jump, not an intermediate skipped one.
  Future<void> _playAt(int i, {int? revertTo}) async {
    final prevIdx = revertTo ?? _queueIdx;
    _queueIdx = i;
    _controller.updateQueueIdx(i);
    _refreshQueueNav();
    final item = _queue[i];
    switch (item) {
      case _OnlineItem(:final result):
        // Deferred UADE entry reached: probe the (now needed anyway) download
        // and splice its real subsongs in, then restart at this index — which
        // is now a plain, already-expanded subsong entry.
        if (item.deferExpand &&
            UadeInfoService.isUadePath(result.filename) &&
            !_isResolvedSubsong(result)) {
          item.deferExpand = false; // once, even if the probe finds nothing
          try {
            final path = await RewampDb.downloadToLibrary(result);
            final info = await UadeInfoService.instance.forPath(path);
            // playableSubsongs, not subsongs: the songdb marks some slots
            // NOSOUND (empty slot in the module), and queueing them gives a
            // silent, zero-length track.
            final playable = info?.playableSubsongs ?? const [];
            if (info != null && playable.length > 1 &&
                i < _queue.length && identical(_queue[i], item)) {
              final rows = [
                // Le numéro est la POSITION dans la liste jouable, jamais
                // l'idx: les slots NOSOUND en sont retirés, donc les deux
                // divergent après le premier trou et la même sous-chanson
                // recevrait deux noms selon le chemin qui la déplie.
                for (var k = 0; k < playable.length; k++)
                  result.withSubsong(playable[k].idx,
                      title: '${result.displayTitle} (${k + 1})',
                      // Own length, never the container's: the catalogue row
                      // carries subsong 0's and withSubsong copies it.
                      durationMs: playable[k].lengthMs)
              ];
              _queue.replaceRange(
                  i, i + 1, [for (final r in rows) _OnlineItem(r, _seq())]);
              _syncControllerQueue();
              _refreshQueueNav();
              return _playAt(i);
            }
          } catch (_) {/* fall through to normal single-file play */}
        }
        try {
          final path       = await RewampDb.downloadToLibrary(result);
          final artworkDir = await RewampDb.artworkDirForResult(result);
          // RSN (snesmusic): the playlist row's subsongIdx doesn't know the
          // track's rank inside the .rsn — resolve it from the DB (written at
          // download). Other formats keep their own index.
          final subsongIdx = await RewampDb.archiveSubsongIndex(
              path: path, songId: result.songId, fallback: result.subsongIdx);
          _onFileReadyAsAlbum(
            path,
            result.displayTitle,
            artist:           result.artistLabel.isEmpty ? null : result.artistLabel,
            artistNames:      result.artistNames,
            artistIds:        result.artistIds,
            album:            result.album,
            albumId:          result.albumId,
            formatExt:        result.formatExt,
            onlineId:         result.songId,
            artworkUrl:       result.artworkUrl,
            artworkTargetDir: artworkDir,
            subsongIdx:       subsongIdx,
            durationS:        result.durationMs != null ? result.durationMs! / 1000.0 : null,
            subsongCount:     result.subsongCount,
          );
          // STIL info (get_sid_info) for the ⓘ panel — was only wired for
          // locally-replayed SID files (_LocalItem below); an online SID
          // played here for the first time never got it fetched/cached.
          if (_kSidExts.contains(result.formatExt.toLowerCase())) {
            _applyLocalSidMeta(path);
          }
          // Prefer the on-disk path for platform: server browse often returns a
          // null platform per track (jw_psf), so result.platform is unreliable.
          final (col, plat) = _albumContextFromPath(path, result.formatExt);
          _controller.setAlbumContext(
              collectionSlug: col ?? result.collection,
              platformName:   plat ?? result.platform, year: result.year,
              forPath: path);
        } on DownloadCancelledException {
          // The user aborted this download: stay on whatever plays, do NOT
          // auto-advance (skipping to the next track would start ANOTHER
          // download — the opposite of what the ✕ asked for) and do not count
          // it as a network failure.
          debugPrint('[queue] download cancelled at $i');
          _restoreQueueIdx(prevIdx);
          return;
        } on FormatUnsupportedException catch (e) {
          // The file failed to play. Before blaming the format, ask the server
          // whether it was REPLACED (same song_id, new download_url) — the file
          // may have been fixed since this queue row was built. If so, swap the
          // row for the fresh one and retry once (url converges → no loop).
          final fresh = await RewampDb.resolveReplacement(e, result);
          if (fresh != null && mounted && i < _queue.length) {
            debugPrint('[queue] $i replaced server-side — retrying');
            _queue[i] = _OnlineItem(fresh, _seq());
            _syncControllerQueue();
            return _playAt(i, revertTo: prevIdx);
          }
          // Genuinely unsupported — say so explicitly (not "download failed")
          // and report the song. Advance so the queue keeps flowing, WITHOUT
          // counting toward the network-down threshold.
          debugPrint('[queue] unsupported format at $i: ${e.filename} .${e.ext}');
          _reportUnsupportedFormat(
            file: e.filename,
            ext: e.ext,
            songId: e.songId,
            subsongIndex: e.subsongIndex,
            detail: e.detail,
          );
          if (i + 1 < _queue.length) return _playAt(i + 1, revertTo: prevIdx);
          _restoreQueueIdx(prevIdx); // couldn't start anything → stay on what plays
          return;
        } catch (e) {
          // The file is GONE from the origin (404/403/410): report it
          // (download_failed) and skip — it is NOT a network outage, so it must
          // not count toward the network-down threshold or show the generic
          // "download failed" banner.
          if (e is DownloadHttpException && e.isGone) {
            // The ORIGIN is gone — but the server may since have added an R2
            // mirror (download_url unchanged, so resolveReplacement wouldn't
            // catch it). Refresh the source ONCE per song and retry via the new
            // mirror before giving up. The guard set stops a mirror that itself
            // 404s from looping.
            final sid = result.songId.split('#').first.split('?').first;
            if (sid.isNotEmpty && !_sourceRefreshedIds.contains(sid)) {
              _sourceRefreshedIds.add(sid);
              final fresh =
                  await RewampDb.refreshSongSource(result, triedUrl: e.url);
              if (fresh != null && mounted && i < _queue.length) {
                debugPrint('[queue] $i source refreshed after 404 — retrying');
                _queue[i] = _OnlineItem(fresh, _seq());
                _syncControllerQueue();
                return _playAt(i, revertTo: prevIdx);
              }
            }
            debugPrint('[queue] file gone at $i (HTTP ${e.statusCode}): ${e.url}');
            _reportDownloadGone(result, e);
            if (i + 1 < _queue.length) return _playAt(i + 1, revertTo: prevIdx);
            _restoreQueueIdx(prevIdx);
            return;
          }
          // Download failed (network down/slow, timeout, 5xx…). Surface it and
          // auto-advance so the radio/queue keeps flowing — but stop after 3
          // consecutive failures (network is likely fully down).
          debugPrint('[queue] download error at $i: $e');
          _consecutiveDlFailures++;
          if (mounted) {
            AppSnack.show(context, context.l10n.shellDownloadFailedSkipping(result.displayTitle), duration: const Duration(seconds: 3));
          }
          if (_consecutiveDlFailures < 3 && i + 1 < _queue.length) {
            return _playAt(i + 1, revertTo: prevIdx);
          }
          if (mounted && _consecutiveDlFailures >= 3) {
            AppSnack.show(context, context.l10n.shellNetworkUnavailable, duration: const Duration(seconds: 4));
          }
          _restoreQueueIdx(prevIdx); // gave up → restore the playing track's index
          return;
        }
        _consecutiveDlFailures = 0;
      case _LocalItem(:final track):
        // Playlist/library trace whose file was deleted: re-resolve through
        // the online download machinery (get_song_context et al) instead of
        // failing the load and silently skipping.
        if (track.onlineId != null &&
            !await File(track.filePath).exists()) {
          // The collection is derivable from where the file lives/lived
          // ('…/online/<collection>/…'), and it MATTERS: without it the album
          // re-resolution below falls back to a bare name, which matches
          // homonyms across collections. Costs nothing — the path is right here.
          final (pathColl, pathPlat) =
              _albumContextFromPath(track.filePath, track.formatExt);
          // An album-grain collection stores its files under
          // '…/online/<collection>/<albumKey>/…', and that key IS the album's
          // uuid whenever it was known at download time. Free, offline, and
          // exactly what the re-resolution needs — catalogueSongId() rejects
          // the fallback form (the album NAME) for us.
          //
          // The QUEUE's album is the LAST resort and only for a track that
          // actually belongs to an album — a track that does carries its NAME
          // too. `_queueAlbumId` outlives the album that set it, and here it
          // does not merely mislabel a row: this id DECIDES WHERE THE FILE IS
          // DOWNLOADED (_dirSegments files an identified album under its uuid).
          // A modland tune replayed after a jw_gbs album landed under that
          // album's uuid, so the same song existed at two paths — two entries
          // in the recents rail, and the one whose file was never written
          // there failed with "MISSING ON DISK". Same lesson as migration 48,
          // one level deeper.
          final pathFromDisk = () {
            final parts = track.filePath.split(p.separator);
            final i = parts.indexOf('online');
            return (i >= 0 && i + 2 < parts.length)
                ? catalogueSongId(parts[i + 2])
                : null;
          }();
          final pathAlbumId = track.albumId ??
              pathFromDisk ??
              ((track.metaAlbum ?? '').isNotEmpty ? _queueAlbumId : null);
          final r = SearchResult(
            songId:      track.onlineId!,
            collection:  pathColl ?? '',
            title:       track.displayTitle,
            filename:    p.basename(track.filePath),
            album:       track.metaAlbum,
            albumId:     pathAlbumId,
            formatExt:   track.formatExt ?? _pathExt(track.filePath),
            downloadUrl: null,
            fileSize:    0,
            year:        null,
            totalCount:  0,
            artistNames: track.artist != null ? [track.artist!] : const [],
            platform:    pathPlat,
            artworkUrl:  track.artworkUrl,
            subsongIdx:  track.subsongIdx,
          );
          if (!mounted) return; // File.exists() was awaited above
          final before = _controller.filePath;
          await downloadAndPlay(context, r, _onFileReadyAsAlbum);
          // downloadAndPlay swallows a FormatUnsupportedException (it shows the
          // message itself). If nothing new actually loaded, the counter is
          // stranded on this unplayable entry while the previous track still
          // plays — restore it to what's playing.
          if (_controller.filePath == before) _restoreQueueIdx(prevIdx);
          // This branch RETURNS, so it used to skip the prefetch at the end of
          // the method — and it is exactly the branch a playlist of not-yet
          // downloaded entries takes on EVERY track. Nothing was ever warmed:
          // each track downloaded when its turn came, with the gap that goes
          // with it. Warm the next one here too.
          _prefetchNextDownload();
          return;
        }
        final artworkDir = track.source == 'online' ? p.dirname(track.filePath) : null;
        _onFileReadyAsAlbum(
          track.filePath,
          track.displayTitle,
          artist:           track.artist,
          album:            track.metaAlbum,
          // The queue's id when this row has none — see [_queueAlbumId].
          albumId:          track.albumId ?? _queueAlbumId,
          formatExt:        track.formatExt,
          onlineId:         track.onlineId,
          artworkUrl:       track.artworkUrl,
          artworkTargetDir: artworkDir,
          subsongIdx:       track.subsongIdx,
          durationS:        track.durationS,
          subsongCount:     track.subsongCount,
        );
        // Origin: what the row STORES first (mig 52 — written when the album
        // was downloaded or the track played, i.e. when it was actually
        // known), and only then what the on-disk path says. The path fallback
        // is no longer gated on `source == 'online'`: that field is a default
        // on a row this shell synthesised from a directory listing, so a
        // downloaded album replayed from the recents rail lost its collection
        // while the very path it reads from spells `online/jw_gbs/…`.
        final (pathCollection, pathPlatform) =
            _albumContextFromPath(track.filePath, track.formatExt);
        // Le CHEMIN d'abord quand il sait, la ligne ensuite. Il dit où les
        // octets SONT (`online/<collection>/…/<plateforme>/…`), là où la valeur
        // stockée est une écriture passée — qui a pu être polluée: une
        // recherche d'origine d'album asynchrone estampillait la réponse sur le
        // morceau courant, si bien que deux sous-chansons d'un module Amiga de
        // modland portaient « hvsc / c64 », l'origine de Commando joué juste
        // avant. La course est fermée (voir _lookupAlbumContext), mais les
        // lignes fausses restaient et resservaient le mauvais placeholder à
        // chaque relance; `setTrackOrigin` écrasant colonne par colonne, lire
        // le chemin en premier les RÉPARE dès la lecture suivante.
        //
        // Le chemin ne répond que lorsqu'il porte vraiment l'information (une
        // collection au grain album, ou un dossier d'album par uuid, n'ont pas
        // de niveau plateforme), donc la ligne reste le repli utile.
        final trackCollection = (pathCollection ?? '').isNotEmpty
            ? pathCollection
            : track.collectionSlug;
        final trackPlatform = (pathPlatform ?? '').isNotEmpty
            ? pathPlatform
            : track.platformName;
        _controller.setAlbumContext(
            forPath: track.filePath,
            collectionSlug: trackCollection,
            platformName: trackPlatform,
            // Stored with the rest (mig 52) — it was the one header field
            // `_backfillIdentity` still went to the SERVER for, while the
            // tracklist had carried it all along.
            year: track.year);
        final ext = (track.formatExt ?? _pathExt(track.filePath)).toLowerCase();
        if (_kSidExts.contains(ext)) _applyLocalSidMeta(track.filePath);
    }
    // A backfill may have just resolved the album id for this queue — keep it
    // so the NEXT track gets the link without its own lookup.
    final resolvedAlbumId = _controller.currentAlbumId;
    if ((_queueAlbumId ?? '').isEmpty && (resolvedAlbumId ?? '').isNotEmpty) {
      _queueAlbumId = resolvedAlbumId;
    }
    // Now that this entry is playing, warm the next real download so advancing
    // to it (last subsong / next album) doesn't stall. Fire-and-forget.
    _prefetchNextDownload();
    // Radio: top the rolling window back up and trim the tail. Fire-and-forget
    // (it downloads/extracts the next album in the background while this plays).
    if (_radioPool.isNotEmpty) unawaited(_radioRefill());
  }

  /// Safety net for a file that downloaded fine but the native decoder refused
  /// (corrupt module, or a mis-tagged row asking for a `?subsong=N` the file
  /// doesn't have). Without it the queue stalls silently on that entry. Skips
  /// forward one entry, capped at 3 consecutive decode failures so a run of bad
  /// rows can't spin through the whole queue. A success clears the count.
  void _onLoadResult(bool ok) {
    if (ok) {
      _consecutiveLoadFailures = 0;
      _lastGoodIdx = _queueIdx;   // this entry is now genuinely playing
      return;
    }
    if (_controller.lastLoadMissingOnDisk) {
      // Not a format problem: the file is not on this device. Saying
      // "unsupported format" here was wrong twice - it names the wrong cause,
      // and it filed a `no_playback` report against a track that plays fine
      // wherever its file actually is.
      final path = _controller.lastLoadPath;
      if (mounted) {
        AppSnack.show(
          context,
          context.l10n
              .playbackFileMissing(path == null ? '' : p.basename(path)),
          duration: const Duration(seconds: 4),
        );
      }
    } else {
      // The file is there and the native decoder REFUSED it (unsupported or
      // corrupt format, or a bad ?subsong=N). Name it explicitly and report it.
      _reportUnplayable();
    }

    // A single (non-queue) play, or an empty/invalid queue → nothing to skip to.
    if (_queue.isEmpty || _queueIdx < 0 || _queueIdx >= _queue.length) return;
    _consecutiveLoadFailures++;
    if (_consecutiveLoadFailures < 3 && _queueIdx + 1 < _queue.length) {
      _playAt(_queueIdx + 1, revertTo: _lastGoodIdx);
    } else {
      // Gave up (this was a manual jump to an unplayable entry, or a run of
      // bad rows): put the counter/highlight back on what's actually playing.
      _restoreQueueIdx(_lastGoodIdx);
    }
  }

  /// Names the unplayable file (filename + extension) in a snackbar and reports
  /// it to the server (report_song) with the client version/build + OS/device,
  /// so a targeted format bug can be reproduced. Online tracks only carry a song
  /// UUID; local files can't be reported (no p_song_id).
  void _reportUnplayable() {
    final ctrl = _controller;
    final path = ctrl.lastLoadPath;
    if (path == null) return;
    final file = p.basename(path);
    final ext = (ctrl.lastLoadFormatExt != null &&
            ctrl.lastLoadFormatExt!.isNotEmpty)
        ? ctrl.lastLoadFormatExt!
        : p.extension(path).replaceFirst('.', '');
    _reportUnsupportedFormat(
      file: file,
      ext: ext,
      songId: ctrl.lastLoadOnlineId,
      subsongIndex: ctrl.lastLoadSubsongIdx,
      detail: 'decode refused: $file (.$ext)',
    );
  }

  /// Shows the explicit "unsupported format" snackbar (file + ext) and reports
  /// the song. Shared by the native-decode-refused path (_reportUnplayable) and
  /// the download-layer FormatUnsupportedException path (queue play). Local
  /// files have no song UUID → report skipped (report_song's p_song_id is a FK).
  void _reportUnsupportedFormat({
    required String file,
    required String ext,
    String? songId,
    int subsongIndex = 0,
    String detail = '',
  }) {
    if (mounted) {
      AppSnack.show(
        context,
        context.l10n.playbackFormatUnsupported(file, ext),
        duration: const Duration(seconds: 3),
      );
    }
    // Strip any synthetic suffix ('<uuid>#<i>' expanded subsong,
    // '<uuid>?subsong=N') to a bare UUID; carry the subsong index separately.
    if (songId == null || songId.isEmpty) return;
    final id = songId.split('#').first.split('?').first;
    if (id.isEmpty) return;
    RewampDb.reportSong(
      songId:       id,
      reason:       'no_playback',
      subsongIndex: subsongIndex > 0 ? subsongIndex : null,
      detail:       detail.isNotEmpty ? detail : 'unsupported: $file (.$ext)',
    );
  }

  /// A queue entry whose file is GONE from the origin (HTTP 404/403/410):
  /// snackbar + report_song with reason `download_failed`. Online rows only
  /// (local files carry no song UUID).
  void _reportDownloadGone(SearchResult r, DownloadHttpException e) {
    final file = p.basename(r.filename);
    if (mounted) {
      AppSnack.show(
        context,
        context.l10n.playbackFileGone(file),
        duration: const Duration(seconds: 3),
      );
    }
    final songId = r.songId.split('#').first.split('?').first;
    if (songId.isEmpty) return;
    RewampDb.reportSong(
      songId:       songId,
      reason:       'download_failed',
      subsongIndex: r.subsongIdx > 0 ? r.subsongIdx : null,
      detail:       'HTTP ${e.statusCode} at ${e.url}',
    );
  }

  /// Warms the NEXT real download while the current entry plays, so reaching the
  /// last subsong/track of an album (or the last entry before the next file)
  /// doesn't stall waiting on a download. Scans forward for the first queue
  /// entry NOT already on disk — entries that resolve to an already-downloaded
  /// file (other subsongs of the current file, other tracks of an extracted
  /// archive) are skipped — and prefetches just that ONE (never the whole
  /// queue). Fire-and-forget, guarded, at most one prefetch in flight.
  Future<void> _prefetchNextDownload() async {
    for (var j = _queueIdx + 1; j < _queue.length; j++) {
      final it = _queue[j];
      // A local row whose file is NOT on disk but which carries a catalogue id
      // (a playlist entry queued before its download — see LocalPlaylistScreen
      // ._queueTracks). "Local items are already on disk" stopped being true
      // the day a playlist could queue what it had not fetched yet, and the
      // download then only started when the track's turn came, mid-gap.
      if (it is _LocalItem) {
        final t  = it.track;
        final id = t.onlineId;
        if (id == null || id.isEmpty) continue;   // a file of the user's own
        if (await File(t.filePath).exists()) continue;
        final rec = await LocalDb.instance.getTrackByOnlineId(id);
        if (rec != null && await File(rec.filePath).exists()) continue;
        // Keyed by song id rather than by path: the row's path is a guess
        // until the catalogue answers (the snapshot's file name, or the title).
        if (_prefetchFailed.contains(id)) continue;
        if (_prefetchingPath == id) return;
        _prefetchingPath = id;
        debugPrint('[prefetch] warming entry $j (catalogue id $id)');
        unawaited(Future(() async {
          // The row carries no download url — only the id — so the playable
          // one has to come from the catalogue first, exactly as the play path
          // does through downloadAndPlay.
          //
          // `get_song_entry` (mig 235) rend directement l'ENTRÉE — membre par
          // son basename, repli radical serveur inclus — là où il fallait
          // getSongContext (qui répond par le CONTENEUR) puis un
          // rétrécissement client. Un appel au lieu de deux, et introuvable =
          // null explicite, jamais une autre piste. Repli sur l'ancien chemin
          // pour un serveur antérieur à la migration.
          final row = await RewampDb.getSongEntry(id,
                  fileName: p.basename(t.filePath)) ??
              await () async {
                final ctx = (await RewampDb.getSongContext(id))?.song;
                if (ctx == null) throw StateError('no context for $id');
                return RewampDb.narrowedToMember(ctx, id,
                    wantFileName: p.basename(t.filePath));
              }();
          await RewampDb.downloadToLibrary(row);
        }).then((_) {}, onError: (e) {
          // Logged, not silent: a prefetch that never fires is invisible from
          // the UI — the track simply downloads late, which reads as "prefetch
          // does not work" with nothing to go on.
          debugPrint('[prefetch] $id FAILED: $e');
          // A CANCEL is not a bad file: blacklisting it would keep this track
          // from ever being prefetched again this session.
          if (e is! DownloadCancelledException) _prefetchFailed.add(id);
        }).whenComplete(
            () { if (_prefetchingPath == id) _prefetchingPath = null; }));
        return;   // one download ahead, same rule as below
      }
      if (it is! _OnlineItem) continue; // nothing to fetch for the rest
      final r  = it.result;
      final lp = r.localPath ?? await RewampDb.localPath(r);
      if (await File(lp).exists()) continue; // same album/file → nothing to fetch
      // Archive tracks (RSN): _localPath is a per-track .spc that never exists,
      // so the DB-recorded real path (the .rsn) is the actual "downloaded?"
      // probe — without it every next entry re-ran album metadata fetches.
      final rec = await LocalDb.instance.getTrackByOnlineId(r.songId);
      if (rec != null && await File(rec.filePath).exists()) continue;
      if (_prefetchFailed.contains(lp)) continue; // known-bad → try the one after
      if (_prefetchingPath == lp) return;    // already prefetching this one
      _prefetchingPath = lp;
      unawaited(RewampDb.downloadToLibrary(r).then(
        (_) {},
        // Block body, not `=> _prefetchFailed.add(lp)`: Set.add returns bool,
        // but this then() yields Future<void> and a Future.then error handler
        // must return the future's own type — the bool tripped a runtime
        // "error handler must return a value of the returned future's type".
        onError: (e) { if (e is! DownloadCancelledException) _prefetchFailed.add(lp); },
      ).whenComplete(
          () { if (_prefetchingPath == lp) _prefetchingPath = null; }));
      return; // only the next one — keep exactly one download ahead
    }
  }

  /// Replaces the queue with online [songs] and starts playback at [startIndex].
  /// Subsong entries for one album track. Server-known counts (vgmrips/gme etc.)
  /// expand for free; a UADE file whose count the server doesn't know is resolved
  /// via the audacious-uade songdb (md5) after download — so an album's
  /// multi-subsong module (e.g. cust.FirstSamurai, 4 tunes) queues all of them,
  /// matching the local-browser behaviour. Falls back to [s] when single/unknown.
  /// The row ALREADY designates one subsong — expanding it again is always
  /// wrong. Two markers, both minted by this app, and every expansion decision
  /// must consult BOTH: they were duplicated at three sites and drifted apart,
  /// which is how a 21-entry playlist queued 61 rows, then 41 once the deferred
  /// path was the only one left disagreeing.
  ///
  ///   - synthetic `<uuid>#<i>` id — expandContainerAlbum,
  ///     subsongRowsFromServer, a playlist entry pinned by `ext_ref`;
  ///   - `resolvedSubsong` — ContainerSubsongScreen et narrowedToFile. Ce
  ///     drapeau vivait DANS `subsongCount` (== 1), qui décrit pourtant le
  ///     FICHIER et pas la ligne: une sous-chanson de `.sid` sortait à 1 et se
  ///     lisait comme « fichier à une seule sous-chanson ».
  ///
  /// Re-expanding such a row also regenerates a raw 0..count-1 index, dropping
  /// the server's real numbering (International Karate MSX's first track is KSS
  /// subsong 6, not 0).
  static bool _isResolvedSubsong(SearchResult r) =>
      r.songId.contains('#') || r.resolvedSubsong;

  Future<List<SearchResult>> _subsongEntries(SearchResult s,
      {bool eager = true}) async {
    if (_isResolvedSubsong(s)) return [s];
    // Server already knows the per-subsong tracklist (real titles/durations,
    // and — critically — the correct subsong numbering incl. the joshw
    // NSF 1-based/GBS 0-based offset). A naive s.withSubsong(i) loop below
    // copies the CONTAINER's own title onto every row (blank/wrong titles)
    // and uses the raw 0..count-1 loop index with no offset correction
    // (starts the queue on the wrong physical subsong). Match
    // RewampDb.expandContainerAlbum's own preference for this data.
    if (s.subsongs.isNotEmpty) {
      return RewampDb.subsongRowsFromServer(s);
    }
    int count = s.subsongCount ?? 0;
    List<int>? idxs;
    // Per-subsong lengths, when a source knows them (UADE songdb). The
    // catalogue row carries ONE duration — the container's, which is subsong
    // 0's — and withSubsong COPIES it, so without this every subsong of a
    // 22-tune TFMX claimed the length of the first.
    Map<int, int>? lensMs;
    // UADE: the songdb OWNS the subsong list — its real idx values (min_subsong
    // is not always 0), its NOSOUND filtering (an empty slot in the module) and
    // its per-subsong lengths. The generic 0..count-1 loop below has none of
    // that, so every UADE file goes through the probe...
    //
    // ...except an already-resolved row, which returned above
    // (_isResolvedSubsong). The server's own track_count is songdb-derived
    // (verified on modland: 22 for mdat.monkey island, 5 for mdat.jim power
    // end, 1 for mdat.apidya (load)), so a 1 there really is a single-subsong
    // file, not "unknown".
    //
    // Probing means downloading the module, so for a big playlist only the
    // started track (+ the next) is probed EAGERLY; the others are enqueued as
    // ONE deferred entry (see _OnlineItem.deferExpand) and expanded when
    // reached — the download they need to play doubles as the probe.
    final isUade = UadeInfoService.isUadePath(s.filename);
    if (isUade && !eager) {
      return [s];
    }
    if (isUade) {
      try {
        final path = await RewampDb.downloadToLibrary(s);
        final info = await UadeInfoService.instance.forPath(path);
        final playable = info?.playableSubsongs ?? const [];
        if (info != null && playable.length > 1) {
          idxs = playable.map((e) => e.idx).toList();
          count = idxs.length;
          lensMs = {
            for (final e in playable)
              if ((e.lengthMs ?? 0) > 0) e.idx: e.lengthMs!,
          };
        }
      } catch (_) {}
    }
    // SID per-subsong STIL titles are filled ASYNC by _applyLocalSidMeta after
    // playback starts — NOT here: doing the download + get_sid_info RPC inline
    // blocked the queue build (a visible pause before a rail SID started). The
    // numbered fallback below is shown until STIL arrives.
    if (count > 1) {
      final list = idxs ?? List.generate(count, (i) => i);
      // No per-subsong metadata → still number the rows so they're distinct.
      // Le numéro est la POSITION dans la liste, pas l'index de sous-chanson:
      // une liste UADE a ses slots NOSOUND retirés, et c'est la position que
      // porte le nom partout ailleurs.
      return [
        for (var k = 0; k < list.length; k++)
          s.withSubsong(list[k],
              title: '${s.displayTitle} (${k + 1})',
              durationMs: lensMs?[list[k]]),
      ];
    }
    return [s];
  }

  Future<void> _startAlbumQueue(
    BuildContext ctx,
    List<SearchResult> songs, {
    int? startIndex,
  }) async {
    if (songs.isEmpty) return;
    _exitRadio();
    // A single multi-subsong file played whole ("Lire tous les subsongs") — the
    // queue is one container's subsongs. Remember it so the player offers the
    // subsong-list link. A real multi-file album leaves this null.
    // Single-FILE multi-subsong container only (SID/NSF/HES…) → offers the
    // subsong link. A PSF/archive album expands to many distinct files (Wild
    // Arms = 86 psf/ogg/xa) — that's an album, not a subsong container.
    //
    // « Une file d'un seul élément » ne suffit PAS comme critère: taper une
    // sous-chanson dans la liste enfile désormais TOUTES les sous-chansons du
    // fichier (sinon la lecture s'arrête au bout d'une), et le lien vers cette
    // liste disparaissait alors du lecteur — avec lui le nom affiché, le repli
    // sur le tag album du moteur étant coupé dès qu'un album_id est présent.
    // Ce qui compte, c'est que toutes les entrées soient des sous-chansons du
    // MÊME fichier: c'est un conteneur, quelle que soit la longueur de la file.
    final firstId = songs.first.songId.split('#').first;
    final oneFile = songs.every((s) =>
        s.songId.split('#').first == firstId &&
        s.localPath == songs.first.localPath);
    _playingContainer = (oneFile &&
            RewampDb.isContainerRow(songs.first) &&
            !RewampDb.isPsfArchiveAlbum(songs))
        ? (songs.first.subsongIdx != 0 ? songs.first.withSubsong(0) : songs.first)
        : null;

    // Archive album whose real per-track files only exist after extraction:
    // extract FIRST and reorder `songs` to the archive's true contents, so
    // songs[startIndex] resolves to the RIGHT file even on the very first
    // (pre-download) play. Idempotent — skipped once files are on disk (that's
    // why a re-launch already worked). One helper dispatches PSF vs zip.
    songs = await RewampDb.ensureAlbumExtracted(songs);

    final startTrack = (startIndex ?? 0).clamp(0, songs.length - 1);
    // Expand each track into its subsongs, tracking where the started track
    // lands. Only the started track (+ the immediate next) is expanded EAGERLY;
    // a non-eager UADE file whose subsong count the server doesn't know stays a
    // single DEFERRED entry, so starting a huge playlist never downloads every
    // Amiga module up front just to count subtunes. Deferred entries expand when
    // reached (_playAt) — the download they need to play doubles as the probe.
    final items = <_OnlineItem>[];
    int idx = 0;
    for (var t = 0; t < songs.length; t++) {
      if (t == startTrack) idx = items.length;
      final eager = t == startTrack || t == startTrack + 1;
      final rows  = await _subsongEntries(songs[t], eager: eager);
      final deferred = !eager &&
          rows.length == 1 &&
          UadeInfoService.isUadePath(rows.first.filename) &&
          !_isResolvedSubsong(rows.first);
      for (final r in rows) {
        items.add(_OnlineItem(r, _seq(), deferExpand: deferred));
      }
    }
    if (items.isEmpty) return;
    idx = idx.clamp(0, items.length - 1);
    // Shuffle mode ON: the fresh queue starts shuffled too. On a plain "play
    // all" (no explicit startIndex) the FIRST played track/subsong is random as
    // well — otherwise track/subsong 1 always led. When the user tapped a
    // specific track, keep that one first and only shuffle its neighbours
    // (done via _shuffleQueue below, which pins _queueIdx).
    if (_shuffleEnabled && startIndex == null) {
      items.shuffle();
      idx = 0;
    }
    final expanded = [for (final it in items) it.result];
    _queue
      ..clear()
      ..addAll(items);
    _prefetchFailed.clear();
    _queueIdx = idx;
    if (_shuffleEnabled && startIndex != null) _shuffleQueue();
    _syncControllerQueue();
    _refreshQueueNav();
    songs = expanded; // subsequent album-context lookup uses the expanded list
    // Extraction + subsong probing were awaited above; the caller's context may
    // have been disposed meanwhile (downloadAndPlay shows SnackBars with it).
    if (!ctx.mounted) return;
    await downloadAndPlay(ctx, songs[idx], _onFileReadyAsAlbum);
    // downloadAndPlay is a generic helper with no controller access, so set the
    // album context here. Use the on-disk path for platform — server browse
    // often returns null platform per track (jw_psf), so songs[idx].platform
    // would otherwise leave the full-screen player showing a null platform.
    // On download failure downloadAndPlay already surfaced the error — skip.
    try {
      final path = await RewampDb.downloadToLibrary(songs[idx]);
      final (col, plat) = _albumContextFromPath(path, songs[idx].formatExt);
      _controller.setAlbumContext(
          collectionSlug: col ?? songs[idx].collection,
          platformName:   plat ?? songs[idx].platform,
          forPath: path);
      // SID: fill per-subsong STIL titles/durations into the queue + live track
      // asynchronously (kept OFF the play path so it never delays start).
      final ext = (songs[idx].formatExt).toLowerCase();
      if (_kSidExts.contains(ext)) _applyLocalSidMeta(path);
      // Write the WHOLE tracklist down while we hold it, instead of letting
      // each track's identity appear only once it has been played. This is the
      // same helper the album screen and the favourites catch-up already use;
      // it simply was never called on the path that DOWNLOADS an album, so a
      // track replayed from the recents rail before its first play had no row,
      // no id and no collection. Off the play path — the queue is already
      // running — and errors stay silent, it is a cache.
      // No `songs.length > 1` gate: `songs` is the EXPANDED list, so a
      // single multi-subsong container (a .gbs album = one file, sixteen
      // subtunes) arrives here as sixteen rows — but a one-track album arrives
      // as one, and writing that single row costs nothing while sparing it the
      // same identity-less replay.
      final albumName = songs[idx].album;
      if (albumName != null && albumName.isNotEmpty) {
        unawaited(RewampDb.materializeAlbumTracks(
          albumName,
          songs,
          albumId: songs[idx].albumId,
        ).catchError((_) {}));
      }
    } catch (_) {}
    // Warm the next real download while this first track plays (this path uses
    // downloadAndPlay directly, not _playAt, so prefetch here too).
    _prefetchNextDownload();
  }

  /// Replaces the queue with local [tracks] and starts playback at [startIndex].
  /// The album the CURRENT local queue belongs to, when any of its rows knows
  /// it. Album identity is a property of the queue, not of each row: rows born
  /// of a playlist entry carry no album id (the snapshot has none), so a
  /// multi-file album replayed from the recents had the album link on the one
  /// track that happened to know, and an inert label on every other. Also
  /// filled in from the player once a backfill resolves it (see
  /// PlayerController._backfillIdentity), so the rest of the queue benefits
  /// from the single lookup the first track paid for.
  String? _queueAlbumId;

  Future<void> _startLocalTrackQueue(
    BuildContext ctx,
    List<TrackRecord> tracks, {
    int? startIndex,
  }) async {
    if (tracks.isEmpty) return;
    _exitRadio();
    _queueAlbumId = tracks
        .map((t) => t.albumId)
        .where((id) => id != null && id.isNotEmpty)
        .firstOrNull;
    // TODO: reconstruct a container SearchResult from the local tracks so the
    // subsong link works on recent-album replay too; null for now (no link).
    _playingContainer = null;
    var idx = (startIndex ?? 0).clamp(0, tracks.length - 1);
    _queue
      ..clear()
      ..addAll([for (final t in tracks) _LocalItem(t, _seq())]);
    _prefetchFailed.clear();
    _queueIdx = idx;
    // Fresh "play all" with shuffle ON → first track random too (see
    // _startAlbumQueue); a tapped track stays first.
    if (_shuffleEnabled) {
      if (startIndex == null) {
        _queue.shuffle();
        _queueIdx = 0;
      } else {
        _shuffleQueue();
      }
    }
    idx = _queueIdx;
    _syncControllerQueue();
    _refreshQueueNav();
    await _playAt(idx);
  }

  // ── Data management callbacks ────────────────────────────────────────────────

  void _onDatabaseReset() {
    _controller.stop();
    _queue.clear();
    _queueIdx = -1;
    _controller.clearQueue();
    _controller.loadHistory();
    // resetDatabase() cleared the sync cursors (the device holds nothing any
    // more, so no cursor is true); pull straight away rather than wait for the
    // next poll — the point of the reset is to start again from the account,
    // and an empty library in the meantime reads as data loss.
    // syncNow, NOT kick: kick() is throttled out when a run succeeded in the
    // last minute and the outbox is empty, which is exactly the state a reset
    // leaves behind. It never throws.
    unawaited(SyncService.instance.syncNow());
  }

  /// Every download is about to be deleted. Treated as ONE album directory —
  /// `handleDeletedAlbum` already stops playback when the playing file lives
  /// under it, drops every queue entry that plays from it, lets the next
  /// survivor start, and TEARS DOWN the player when there is none.
  ///
  /// That teardown is what the old code missed: it stopped and cleared the
  /// queue but never cleared `filePath` nor called `playerUiCloser`, so the
  /// mini player went on showing a track whose file had just been erased. A
  /// LOCAL file keeps playing — it does not live under `online/`, which is the
  /// whole point of testing the directory rather than the source column.
  Future<void> _onOnlineLibraryDeleting() async {
    await _controller.handleDeletedAlbum(await RewampDb.onlineLibraryDir());
    if (!mounted) return;
    _refreshQueueNav();
  }

  /// Does [it] play FROM the file [path]? Not "is it that track" — one file
  /// backs many entries (every subsong of a .sid/.nsf/.kss, every member of an
  /// .rsn), and deleting the file kills them all. Candidates are tried cheapest
  /// first; the DB row is authoritative (written at play time, it holds the
  /// REAL path: the .rsn, not the per-track ".spc" that never exists on disk).
  Future<bool> _entryPlaysFrom(_QueueItem it, String path,
      {bool asPrefix = false}) async {
    // A deleted ALBUM is a directory: match everything under it.
    bool hit(String? candidate) {
      if (candidate == null) return false;
      if (!asPrefix) return candidate == path;
      final sep = Platform.pathSeparator;
      return candidate == path ||
          candidate.startsWith(path.endsWith(sep) ? path : '$path$sep');
    }

    switch (it) {
      case _LocalItem(:final track):
        return hit(track.filePath);
      case _OnlineItem(:final result):
        if (hit(result.localPath)) return true;
        try {
          if (hit(await RewampDb.localPath(result))) return true;
        } catch (_) {}
        if (collectionIsAlbumGrain(result.collection.toLowerCase())) {
          try {
            if (hit(await RewampDb.rsnLocalPath(result))) return true;
          } catch (_) {}
        }
        try {
          final rec = await LocalDb.instance.getTrackByOnlineId(result.songId);
          if (rec != null && hit(rec.filePath)) return true;
        } catch (_) {}
        return false;
    }
  }

  /// A downloaded FILE was deleted — drop every queue entry that plays from it,
  /// not just the one the user tapped: a .sid/.nsf/.rsn backs one entry PER
  /// SUBSONG. Without this the dead entries linger and, tapped, re-resolve to a
  /// surviving sibling and play the WRONG track. Returns true when the deleted
  /// file was playing and the next queue entry took over.
  ///
  /// Must run BEFORE the file's DB rows are deleted (they resolve the entries).
  Future<bool> _onTrackDeleted(String path, {bool asPrefix = false}) async {
    if (_queue.isEmpty) return false;
    // The entry that is PLAYING is also matched on the controller's own file
    // path — the cheapest and most reliable identity we have for it.
    final playingPath = _controller.filePath;
    final snapshot = List<_QueueItem>.of(_queue);
    int removedBefore = 0;
    bool removedCurrent = false;
    final kept = <_QueueItem>[];
    for (int i = 0; i < snapshot.length; i++) {
      final it = snapshot[i];
      final hit = (i == _queueIdx && playingPath == path) ||
          await _entryPlaysFrom(it, path, asPrefix: asPrefix);
      if (hit) {
        if (i < _queueIdx) removedBefore++;
        if (i == _queueIdx) removedCurrent = true;
        continue;   // drop
      }
      kept.add(it);
    }
    if (kept.length == snapshot.length) return false;   // nothing matched
    if (!mounted) return false;
    // Slot the next surviving track shifted into — out of range when nothing
    // in the queue outlived the deleted file.
    final nextIdx = _queueIdx - removedBefore;
    setState(() {
      _queue..clear()..addAll(kept);
      _queueIdx -= removedBefore;
      if (removedCurrent) {
        if (_queue.isEmpty) {
          _queueIdx = -1;
        } else {
          _queueIdx = _queueIdx.clamp(0, _queue.length - 1);
        }
      }
    });
    _syncControllerQueue();
    _refreshQueueNav();
    // The deleted track was playing: continue with the next queue entry.
    // Nothing after it → report "no takeover" so the player tears itself down.
    if (removedCurrent && nextIdx >= 0 && nextIdx < _queue.length) {
      _playAt(nextIdx);
      return true;
    }
    return false;
  }

  // ── SID metadata enrichment ──────────────────────────────────────────────────

  /// Called (fire-and-forget) after loading a local SID file.
  /// Computes HVSC MD5, checks local cache, fetches from server if needed,
  /// then updates DB tracks + live controller for the currently playing subsong.
  /// Union of two artist strings (comma/semicolon/&-separated), de-duplicated
  /// case-insensitively, order-preserving (existing first). Returns null only
  /// when both are empty.
  static String? _mergeArtists(String? existing, String? incoming) {
    List<String> split(String? s) => (s ?? '')
        .split(RegExp(r'\s*[,;]\s*|\s*&\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.toLowerCase() != 'null')
        .toList();
    final out  = <String>[];
    final seen = <String>{};
    for (final name in [...split(existing), ...split(incoming)]) {
      final k = name.toLowerCase();
      if (seen.add(k)) out.add(name);
    }
    return out.isEmpty ? null : out.join(', ');
  }

  Future<void> _applyLocalSidMeta(String filePath) async {
    try {
      final md5 = _controller.audio.sidMd5(filePath);
      if (md5.isEmpty) return;

      // Check local cache.
      List<SidSubsongCache>? cached =
          await LocalDb.instance.getSidInfoCache(md5);

      if (cached == null) {
        // Not yet cached — fetch from server.
        final info = await RewampDb.getSidInfo(md5);
        if (info != null) {
          final subsongs = info.subsongs
              .map((s) => SidSubsongCache(
                    idx: s.idx,
                    lengthMs: s.lengthMs,
                    stilName: s.name,
                    stilAuthor: s.author,
                    stilTitle: s.title,
                    stilArtist: s.artist,
                    stilComment: s.comment,
                  ))
              .toList();
          await LocalDb.instance.upsertSidInfoCache(md5, subsongs);
          cached = subsongs;
        } else {
          // Server returned nothing — cache empty sentinel so we don't retry
          // on every play.
          await LocalDb.instance.upsertSidInfoCache(md5, const []);
          cached = const [];
        }
      }

      if (cached.isEmpty) return;

      // Durée + NOM du sous-chant. Le titre vient de STIL NAME et l'artiste de
      // STIL AUTHOR — surtout PAS de TITLE/ARTIST, qui nomment l'œuvre reprise
      // (voir SidSubsongInfo). Null laisse en place le nom déjà calculé
      // (« NOM (n) »), que STIL ne nomme pas: c'est le cas des 13 autres
      // sous-chants de « One Man and His Droid ».
      for (final sub in cached) {
        final durS = sub.lengthMs != null ? sub.lengthMs! / 1000.0 : null;
        await LocalDb.instance.updateSidTrackMeta(
          filePath: filePath,
          subsongIdx: sub.idx - 1, // DB uses 0-based
          durationS: durS,
          title: sub.stilName,
          artist: sub.stilAuthor,
        );
      }

      // Update queue panel entries with STIL titles (0-based subsong_idx =
      // queue position, since getTracksForFile orders by subsong_idx ASC).
      final queueUpdates = <int, String>{};
      for (final sub in cached) {
        final qIdx = sub.idx - 1; // 1-based → 0-based
        if (sub.stilName != null && sub.stilName!.isNotEmpty) {
          queueUpdates[qIdx] = sub.stilName!;
        }
      }
      if (queueUpdates.isNotEmpty) {
        _controller.updateQueueEntries(queueUpdates);
      }

      // Apply to the live controller if still playing this file.
      if (_controller.filePath == filePath) {
        final playingIdx = _controller.subsongIdx;
        final thisSub =
            cached.where((s) => s.idx - 1 == playingIdx).firstOrNull;
        if (thisSub != null) {
          if (thisSub.lengthMs != null) {
            _controller.setKnownDuration(thisSub.lengthMs! / 1000.0);
          }
          // Merge the STIL credit with the artist we already have (from the
          // search result / file) rather than replacing it — the per-subsong
          // STIL entry often names only the arranger and would otherwise drop
          // the composer (e.g. "Rob Hubbard").
          _controller.updateTrackLabel(
            title: thisSub.stilName,
            artist:
                _mergeArtists(_controller.currentArtist, thisSub.stilAuthor),
          );
        }
      }
    } catch (e) {
      debugPrint('[SID meta] error: $e');
    }
  }

  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildMiniPlayer(bool isDesktop) => MiniPlayer(
        key: _miniPlayerKey,
        controller: _controller,
        onTap: _openFullPlayer,
        playerOpenController: _playerCtrl,
        onDragOpenBegin: _onPlayerDragBegin,
        onDragOpenEnd: _onPlayerDragEnd,
        isSidebar: isDesktop,
        queueActive: isDesktop && _showSidebarQueue,
        onToggleQueue: isDesktop
            ? () => setState(() => _showSidebarQueue = !_showSidebarQueue)
            : null,
      );

  /// Phone bottom chrome: mini player above the nav bar (two lines),
  /// collapsing onto ONE line once the user scrolls (see [_chromeCtrl]): the
  /// nav slab shrinks to a square pill holding the selected icon, left-aligned,
  /// and the mini player drops level with it on the remaining width — the two
  /// slabs stay disjoint, Apple-Music-style. Tapping the pill expands back.
  Widget _phoneChrome(BuildContext context, ColorScheme cs,
      List<NavigationDestination> barDestinations) {
    // Filled variants, aligned with barDestinations' selectedIcons.
    const navIcons = [
      Icons.home,
      Icons.search,
      Icons.library_music,
      Icons.bar_chart,
      Icons.more_horiz,
    ];
    return AnimatedBuilder(
      // Le contrôleur aussi: l'apparition du mini-lecteur (premier fichier
      // chargé) doit reconstruire la géométrie — l'animation seule ne tique
      // pas à ce moment-là, et la dalle restait invisible jusqu'au premier
      // scroll.
      animation: Listenable.merge([_chromeT, _controller]),
      builder: (context, _) {
        final hasMini = _controller.hasFile;
        // The mini player can disappear (stop, delete) while condensed —
        // geometry falls back to two-line at once, the flag follows.
        final t = hasMini ? _chromeT.value : 0.0;
        if (!hasMini && _chromeCondensed) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _setChromeCondensed(false));
        }
        // Le chrome téléphone vit un peu plus BAS, dans la safe area (moitié
        // de la marge), dans les DEUX modes — comme Apple Music — et garde la
        // MÊME largeur effective dans les deux. Translation (pas layout): la
        // place rendue au contenu est déjà gérée par l'inset animé.
        final dip = MediaQuery.of(context).padding.bottom * 0.5;
        return Transform.translate(
          offset: Offset(0, dip),
          child: LayoutBuilder(builder: (context, cons) {
          final w = cons.maxWidth;
          final navW = ui.lerpDouble(w, _kNavBarHeight, t)!;
          final regionH = _kNavBarHeight +
              (hasMini ? (1 - t) * (_kMiniPlayerHeight + _kGlassGap) : 0.0);
          final miniLeft = ui.lerpDouble(0, _kNavBarHeight + _kGlassGap, t)!;
          final miniBottom = ui.lerpDouble(_kNavBarHeight + _kGlassGap, 0, t)!;
          return SizedBox(
            height: regionH,
            width: w,
            child: Stack(clipBehavior: Clip.none, children: [
              // Mini player — carried up with the opening player (follow),
              // and dropped level with the nav pill when condensed.
              if (hasMini)
                Positioned(
                  left: miniLeft,
                  right: 0,
                  bottom: miniBottom,
                  height: _kMiniPlayerHeight,
                  child: AnimatedBuilder(
                    animation: _playerCtrl,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, _miniPlayerFollow()),
                      child: child,
                    ),
                    child: _buildMiniPlayer(false),
                  ),
                ),
              // Nav slab. Hauteur FIXÉE ici: c'est la boîte qui décide, pas
              // la barre (dans le slot du Scaffold, sa SafeArea interne
              // ajoutait la marge du bas à sa hauteur). La barre est POUSSÉE
              // hors de l'écran par le lecteur qui s'ouvre (_navBarPush).
              Positioned(
                left: 0,
                bottom: 0,
                width: navW,
                height: _kNavBarHeight,
                child: AnimatedBuilder(
                  animation: _playerCtrl,
                  // Deux directions de chasse selon le mode: en 2 lignes le
                  // lecteur pousse la barre vers le BAS (beat 2, étalé); en
                  // 1 ligne la pastille part vers la GAUCHE. Sa course suit
                  // la valeur BRUTE de l'animation — progressive sur TOUTE
                  // l'ouverture, et démarrant à 0 pour être visible avant que
                  // le lecteur pleine largeur ne la recouvre (le beat 2, lui,
                  // commence après coup, donc caché ici).
                  builder: (context, child) => Transform.translate(
                    offset: Offset(
                      -t * _playerCtrl.value * (navW + _kGlassInset),
                      (1 - t) * _navBarPush(context),
                    ),
                    child: child,
                  ),
                  child: GlassChrome(
                    borderRadius: BorderRadius.circular(26),
                    child: Stack(fit: StackFit.expand, children: [
                      // Full bar — kept at FULL width inside an OverflowBox
                      // so the shrinking slab CLIPS it instead of squeezing
                      // five destinations into 52 px; faded out over the
                      // first half of the collapse.
                      IgnorePointer(
                        ignoring: t > 0.05,
                        child: Opacity(
                          opacity: (1 - t * 2.2).clamp(0.0, 1.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: OverflowBox(
                              minWidth: w,
                              maxWidth: w,
                              alignment: Alignment.centerLeft,
                              // Toutes les marges système remises à zéro pour
                              // ce sous-arbre, pas seulement `padding`: la
                              // SafeArea interne de la NavigationBar les
                              // mangeait dans nos 52 px et les icônes
                              // disparaissaient sur iPhone.
                              child: MediaQuery(
                                data: MediaQuery.of(context).copyWith(
                                  padding: EdgeInsets.zero,
                                  viewPadding: EdgeInsets.zero,
                                  viewInsets: EdgeInsets.zero,
                                ),
                                child: NavigationBarTheme(
                                  // La pastille M3 par défaut (stadium 64×32)
                                  // sort ÉCRASÉE dans nos 52 px — coins
                                  // carrés-arrondis à la place, et icônes
                                  // montées à 26 (24 par défaut).
                                  // Icônes à 34 (24 par défaut M3): ça tient
                                  // dans les 52 px de la barre avec le padding
                                  // de 6 du carré de sélection (34+12 = 46).
                                  data:
                                      NavigationBarTheme.of(context).copyWith(
                                    // L'indicateur natif est ÉTEINT (sa taille
                                    // 64×32 n'est pas thémable) — le
                                    // surlignage carré vit dans selectedIcon.
                                    indicatorColor: Colors.transparent,
                                    // Le voile hover/pressed est dessiné à la
                                    // TAILLE de l'indicateur natif — éteint
                                    // aussi.
                                    overlayColor: const WidgetStatePropertyAll(
                                        Colors.transparent),
                                    // Couleurs des défauts M3 reprises à la
                                    // main : fournir un iconTheme REMPLACE
                                    // celui des défauts, teintes comprises.
                                    iconTheme: WidgetStateProperty.resolveWith(
                                      (states) => IconThemeData(
                                        size: 34,
                                        // Selected glyph carries the brand
                                        // tint — the square keeps its theme
                                        // colour.
                                        color: states
                                                .contains(WidgetState.selected)
                                            ? _kBrandPink
                                            : cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  child: NavigationBar(
                                    height: _kNavBarHeight,
                                    labelBehavior:
                                        NavigationDestinationLabelBehavior
                                            .alwaysHide,
                                    backgroundColor: Colors.transparent,
                                    surfaceTintColor: Colors.transparent,
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    // Settings(4)/About(5) partagent « Plus ».
                                    selectedIndex: _index >= 4 ? 4 : _index,
                                    onDestinationSelected: _onBarSelected,
                                    destinations: barDestinations,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Condensed pill — the selected tab's icon; tapping it
                      // restores the two-line layout.
                      IgnorePointer(
                        ignoring: t < 0.95,
                        child: Opacity(
                          opacity: ((t - 0.55) / 0.45).clamp(0.0, 1.0),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(26),
                            onTap: () => _setChromeCondensed(false),
                            child: Center(
                              child: Icon(
                                navIcons[_index >= 4 ? 4 : _index],
                                size: 34,
                                color: _kBrandPink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          );
          }),
        );
      },
    );
  }

  // Bottom bar routing. Slots 0-3 are direct tabs; slot 4 ("More") is not a
  // tab but the overflow group {Settings=4, About=5} that doesn't fit a phone
  // bottom bar → it opens a picker sheet instead of switching directly.
  void _onBarSelected(int i) {
    if (i < 4) {
      _onTabSelected(i);
    } else {
      _showMoreMenu();
    }
  }

  void _showMoreMenu() {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                  _index == 4 ? Icons.settings : Icons.settings_outlined),
              title: Text(l10n.navSettings),
              selected: _index == 4,
              onTap: () {
                Navigator.pop(ctx);
                _onTabSelected(4);
              },
            ),
            ListTile(
              leading: Icon(_index == 5 ? Icons.info : Icons.info_outline),
              title: Text(l10n.navAbout),
              selected: _index == 5,
              onTap: () {
                Navigator.pop(ctx);
                _onTabSelected(5);
              },
            ),
            // Download queue — live counter, pause/resume/edit inside.
            ListenableBuilder(
              listenable: Listenable.merge(
                  [DownloadManager.instance, RewampDb.downloadStatus]),
              builder: (context, _) {
                final n = downloadActivityCount();
                return ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: Text(l10n.downloadsTitle),
                  trailing: n > 0
                      ? Badge.count(count: n)
                      : (DownloadManager.instance.paused
                          ? const Icon(Icons.pause, size: 18)
                          : null),
                  onTap: () {
                    Navigator.pop(ctx);
                    // Root navigator: a management screen over the whole
                    // shell, same as the modal screens.
                    Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                            builder: (_) => const DownloadQueueScreen()));
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Index de la ligne « Téléchargements » du rail: la dernière, après les six
  /// vrais onglets. Elle ne se SÉLECTIONNE pas — elle pousse un écran.
  static const _kDownloadsRailIndex = 6;

  void _onTabSelected(int i) {
    if (i == _kDownloadsRailIndex) {
      Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => const DownloadQueueScreen()));
      return;
    }
    _setChromeCondensed(false);
    if (i == _index) {
      // Already on this tab → pop to its root
      _navKeys[i].currentState?.popUntil((route) => route.isFirst);
      // Re-selecting the search tab also resets every search criterion.
      if (i == 1) _searchResetTick.value++;
      // Re-tapping home is the manual refresh gesture (there's no pull-to-
      // refresh: the home scroll view is a full-bleed shader-masked stack).
      if (i == 0) HomeRefresh.instance.refresh(force: true);
    } else {
      setState(() => _index = i);
      // Coming back to home: refetch if the data has gone stale.
      if (i == 0) HomeRefresh.instance.refresh();
    }
  }

  /// The currently-playing item as a container SearchResult (subsongIdx 0) when
  /// it's a single-file multi-subsong container, else null. Used to offer the
  /// "subsongs" link in the player instead of an album link.
  SearchResult? _currentContainerResult() {
    if (_playingContainer != null) return _playingContainer;
    // Fallback for play paths that don't set _playingContainer (e.g. a direct
    // search tap → downloadAndPlay): decide from the actual file. If it has
    // more than one subsong, synthesize a container result pointing at the
    // already-downloaded local file (localPath → ContainerSubsongScreen probes
    // it directly; songId lets each subsong resolve its cached track for play).
    final fp       = _controller.filePath;
    final onlineId = _controller.currentOnlineId;
    if (fp == null || onlineId == null) return null;
    // The native probe cannot count UADE subsongs — only the songdb knows —
    // so it answers 1 for every Amiga module and the subsong link never
    // appeared on a TFMX/AHX file. Fall back to what the songdb already told
    // us for this exact file (resolved on every UADE load, for the durations),
    // NOT to a fresh lookup: this getter is synchronous.
    var count = _controller.audio.probeSubsongCount(fp);
    if (count <= 1 && UadeInfoService.isUadePath(fp)) {
      final playable =
          UadeInfoService.instance.cachedForPath(fp)?.playableSubsongs;
      if (playable != null && playable.length > 1) count = playable.length;
    }
    if (count <= 1) return null;
    final artist = _controller.currentArtist;
    return SearchResult(
      songId:       onlineId,
      // Container-level name, NOT _controller.fileName (which is the CURRENT
      // subsong's title after STIL merge) — otherwise the subsong list would
      // fall back to that one name for every row. Per-subsong titles still
      // come from STIL (get_sid_info) when available.
      collection:   _controller.currentCollectionSlug ?? '',
      // displayName, not basenameWithoutExtension: an Amiga name carries its
      // FORMAT before the dot ("mdat.monkey island"), so the latter answers
      // "mdat".
      title:        UadeInfoService.displayName(fp),
      filename:     p.basename(fp),
      album:        _controller.currentAlbum,
      formatExt:    _controller.currentFormatExt ?? _pathExt(fp),
      downloadUrl:  null,
      fileSize:     0,
      year:         null,
      artistNames:  (artist != null && artist.isNotEmpty) ? [artist] : const [],
      totalCount:   0,
      platform:     _controller.currentPlatformName,
      artworkUrl:   _controller.artworkUrl,
      subsongCount: count,
      localPath:    fp,
    );
  }

  /// THE way this shell pushes a screen. Two rules live here rather than in
  /// each of the six call sites that used to copy them:
  ///
  /// 1. **No duplicate on top.** Opening the album of the track you are
  ///    listening to, from the album screen you already reached that way,
  ///    stacked a second identical screen — so "back" walked through the same
  ///    album twice. When [name] matches the route already on top, the push is
  ///    skipped (the player has already closed itself, which is what the tap
  ///    was for).
  /// 2. **The player comes back only if nothing touched it.** [_playerIntentSeq]
  ///    is captured now and re-checked on the way back.
  void _pushOnTab(String name, WidgetBuilder builder) {
    final nav = _navKeys[_index].currentState;
    if (nav == null) return;
    // Already the screen on top: the tap was "go there", and we are there.
    if (_navStacks[_index].isNotEmpty && _navStacks[_index].last == name) {
      return;
    }

    // Captured AFTER the player closed itself (a chip inside the player
    // dismisses first, and the overlay stays mounted while it animates shut,
    // so `_playerOpen` is still true here — that is the signal that the push
    // came FROM the player and the trip should end back in it).
    final wasOpen = _playerOpen;
    final token = _playerIntentSeq;
    nav.push(MaterialPageRoute(
      settings: RouteSettings(name: name),
      builder: builder,
    )).then((_) {
      if (!mounted || !wasOpen) return;
      if (token != _playerIntentSeq) return;   // expired: the user moved on
      _openFullPlayer();
    });
  }

  void _openSubsongList(SearchResult container) {
    _pushOnTab(
      // songId is non-null but empty for a purely local container.
      'subsongs:${container.songId.isNotEmpty ? container.songId : (container.localPath ?? container.title ?? '')}',
      (_) => ContainerSubsongScreen(
        result:      container,
        onTap:       (c, r) => _downloadAndPlayOnline(c, r),
        onPlayAll:   _startAlbumQueue,
        onArtistTap: (name) => _navKeys[_index].currentState?.push(
          MaterialPageRoute(
            builder: (_) => ArtistResultsScreen(
              artistName:      name,
              onTap:           (c, r) => _downloadAndPlayOnline(c, r),
              onPlayAlbum:     _startAlbumQueue,
              onQueueAdd:      _onQueueAdd,
              onAlbumQueueAdd: _onAlbumQueueAdd,
              onNavigateTag:   _pushTagSearch,
            ),
          ),
        ),
      ),
    );
  }

  /// Cross-entity search scoped to one tag (songs + artists + albums), pushed
  /// on the current tab's navigator. Shared by the player track-info sheet and
  /// the artist-header tag chips.
  void _pushTagSearch(String tag, {String? category}) {
    _pushOnTab('tag:${category ?? ''}:$tag', (_) => SearchScreen(
      initialTags:     [tag],
      initialTagCategory: category,
      onFileReady:     _onSingleLocalFileReady,
      onPlayAlbum:     _startAlbumQueue,
      onQueueAdd:      _onQueueAdd,
      onAlbumQueueAdd: _onAlbumQueueAdd,
    ));
  }

  /// Demozoo production chip (migs 161-163) → its screen, on the ACTIVE tab
  /// navigator; the full player is restored on the way back, exactly like a
  /// tag search.
  /// Group chip (server migs 201/202) → its screen, on the ACTIVE tab
  /// navigator, player restored on the way back — same contract as a tag
  /// search. NOT a tag search: only this screen lists a group's productions.
  void _pushGroup(String name, {String? tagId}) {
    _pushOnTab('group:$name', (_) => GroupScreen(
      name:            name,
      tagId:           tagId,
      onTap:           _downloadAndPlayOnline,
      onPlayAlbum:     _startAlbumQueue,
      onQueueAdd:      _onQueueAdd,
      onAlbumQueueAdd: _onAlbumQueueAdd,
      onFileReady:     _onSingleLocalFileReady,
    ));
  }

  /// projectM preset management, opened from the visualizer's source button.
  /// On the tab navigator like every other screen, so the mini player and the
  /// bottom bar stay put and the full player comes back on the way out.
  ///
  /// Closing the player FIRST is what makes that visible: [_pushOnTab] pushes
  /// on the tab navigator, which lives UNDER the player overlay — pushed with
  /// the player still up, the screen opens behind it and the tap looks like it
  /// only dismissed the sheet. Every other in-player navigation does the same;
  /// they get it for free because their chip lives in a sheet that pops itself.
  /// The restore-on-return promise survives: [_pushOnTab] reads the intent
  /// sequence after this bump, not before.
  void _pushPresets() {
    _closePlayerOverlay();
    _pushOnTab('presets', (_) => const PresetScreen());
  }

  void _pushProduction(int productionId, {String? title}) {
    _pushOnTab('production:$productionId', (_) => ProductionScreen(
      productionId: productionId,
      title:        title,
      onPlayAlbum:  _startAlbumQueue,
    ));
  }

  /// Opens the full player. It is an OVERLAY, not a route (see [_playerCtrl]):
  /// opening is mounting it and running the animation forward.
  void _openFullPlayer() {
    // Nothing current (e.g. the playing file was just deleted): don't reopen
    // the player when a pushed screen (subsong list, album view) pops back.
    if (_controller.filePath == null) return;
    _mountPlayer();
    _playerCtrl.forward();
  }

  /// The player widget itself. Built fresh on each frame the overlay is
  /// mounted; every navigation callback closes it through `onHostClose`.
  PlayerScreen _buildPlayerScreen() {
    final container = _currentContainerResult();
    return PlayerScreen(
      controller:    _controller,
      onHostClose:   _closePlayerOverlay,
      hostController: _playerCtrl,
      onNavigateSubsongs:
          container == null ? null : () => _openSubsongList(container),
      // Le NOM du conteneur, pour que la ligne d'album l'affiche au lieu d'un
      // libellé générique quand le fichier n'appartient à aucun album — le cas
      // de hvsc/asma/modland.
      subsongContainerName: container?.displayTitle,
      onRedownload: _redownloadCurrentTrack,
      onNavigateAlbum: (albumName, {collection, platform, artworkUrl, albumId}) {
        _pushOnTab('album:${albumId ?? albumName}', (ctx) => AlbumDetailScreen(
            albumName:       albumName,
            albumId:         albumId,
            platformName:    platform,
            collectionSlug:  collection,
            artworkUrl:      artworkUrl,
            onTap:           (c, r) => _downloadAndPlayOnline(c, r),
            onPlayAlbum:     _startAlbumQueue,
            onPlayLocalAlbum: _startLocalTrackQueue,
            onQueueAdd:      _onQueueAdd,
            onAlbumQueueAdd: _onAlbumQueueAdd,
            onArtistTap:     (name) => Navigator.of(ctx).push(MaterialPageRoute(
              builder: (_) => ArtistResultsScreen(
                artistName:      name,
                onTap:           (c, r) => _downloadAndPlayOnline(c, r),
                onPlayAlbum:     _startAlbumQueue,
                onQueueAdd:      _onQueueAdd,
                onAlbumQueueAdd: _onAlbumQueueAdd,
                onNavigateTag:   _pushTagSearch,
              ),
            )),
        ));
      },
      onNavigateArtist: (artistName, {collection, artistId}) {
        _pushOnTab('artist:${artistId ?? artistName}', (_) => ArtistResultsScreen(
          artistName:      artistName,
          artistId:        artistId,
          collection:      collection,
          onTap:           (ctx, r) => _downloadAndPlayOnline(ctx, r),
          onPlayAlbum:     _startAlbumQueue,
          onQueueAdd:      _onQueueAdd,
          onAlbumQueueAdd: _onAlbumQueueAdd,
          onNavigateTag:   _pushTagSearch,
        ));
      },
      onNavigateTag: _pushTagSearch,
    );
  }

  static const double _kQueuePanelWidth = 280.0;

  /// Hauteur que le mini-lecteur occupe en bas de fenêtre, marges comprises
  /// (2 px de progression + 2×5 de padding + 40 de ligne + `_kGlassInset` en
  /// haut et en bas). Le panneau de queue s'en réserve autant en bas: le
  /// mini-lecteur est dessiné PAR-DESSUS lui.
  static const double _kMiniPlayerReserve = 72.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= _desktopBreakpoint;
    final extendRail = width >= _kExtendedNavRailBreakpoint;
    // A single-track play leaves the queue empty; the panel then shows a
    // one-entry stand-in for the loaded track (see _sidebarQueue), so the
    // overlay stays reachable whenever something is playing.
    final hasQueue = _controller.hasFile;
    final showQueueOverlay = isDesktop && _showSidebarQueue && hasQueue;

    // Home screen (index 0) keeps full width so "recently played" is not
    // squeezed by the queue overlay.  All other screens get right-padding.
    final queuePad = EdgeInsets.only(
      right: showQueueOverlay ? _kQueuePanelWidth : 0,
    );
    final body = IndexedStack(
      index: _index,
      children: [
        for (int i = 0; i < _screens.length; i++)
          i == 0
              ? _screens[i]
              : AnimatedPadding(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: queuePad,
                  child: _screens[i],
                ),
      ],
    );

    final railDestinations = <NavigationRailDestination>[
      NavigationRailDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: Text(l10n.navHome),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.search_outlined),
        selectedIcon: const Icon(Icons.search),
        label: Text(l10n.navSearch),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.library_music_outlined),
        selectedIcon: const Icon(Icons.library_music),
        label: Text(l10n.navLibrary),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.bar_chart_outlined),
        selectedIcon: const Icon(Icons.bar_chart),
        label: Text(l10n.navStats),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: Text(l10n.navSettings),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.info_outline),
        selectedIcon: const Icon(Icons.info),
        label: Text(l10n.navAbout),
      ),
      // Téléchargements: pas un onglet (la sélection n'y va jamais, la ligne
      // pousse un écran), mais une VRAIE destination quand même. Posée en
      // `trailing`, il fallait refaire à la main l'alignement, la typographie
      // et la largeur du rail — et ça se voyait: icône décalée, libellé
      // tronqué en « Télécharge… ». Une destination hérite de tout ça.
      NavigationRailDestination(
        icon: const _DownloadRailIcon(),
        // Ellipse plutôt que débordement si la police système est agrandie:
        // c'est le libellé le plus long du rail.
        label: Text(l10n.downloadsTitle,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ];

    // L'indicateur M3 (64×32, taille NON thémable) sortait en pastille
    // écrasée: il est rendu transparent et le surlignage est un CARRÉ arrondi
    // 38×38 dessiné par _NavSquareIcon — plein à la sélection, fantôme au
    // survol (le voile natif, coupé, avait la forme du rectangle 64×32).
    final barDestinations = <NavigationDestination>[
      NavigationDestination(
        icon: const _NavSquareIcon(Icons.home_outlined),
        selectedIcon: const _NavSquareIcon(Icons.home, selected: true),
        label: l10n.navHome,
      ),
      NavigationDestination(
        icon: const _NavSquareIcon(Icons.search_outlined),
        selectedIcon: const _NavSquareIcon(Icons.search, selected: true),
        label: l10n.navSearch,
      ),
      NavigationDestination(
        icon: const _NavSquareIcon(Icons.library_music_outlined),
        selectedIcon:
            const _NavSquareIcon(Icons.library_music, selected: true),
        label: l10n.navLibrary,
      ),
      NavigationDestination(
        icon: const _NavSquareIcon(Icons.bar_chart_outlined),
        selectedIcon: const _NavSquareIcon(Icons.bar_chart, selected: true),
        label: l10n.navStats,
      ),
      // 5th slot stands in for the {Settings, About} overflow group (a phone
      // bottom bar can't hold 6 comfortably) — tapping it opens a picker sheet.
      NavigationDestination(
        icon: const _NavDownloadBadge(
            child: _NavSquareIcon(Icons.more_horiz)),
        selectedIcon: const _NavDownloadBadge(
            child: _NavSquareIcon(Icons.more_horiz, selected: true)),
        label: l10n.navMore,
      ),
    ];

    // Drop anywhere on the window. Wrapping the WHOLE Scaffold rather than the
    // content area is deliberate: a file dragged onto the nav rail, the mini
    // player or the queue panel is still a file the user wants played, and
    // hunting for the one valid target is the kind of precision nobody should
    // have to give a music player.
    // The player used to be a route, so Android's back button closed it for
    // free. As an overlay it needs saying. Only fires when THIS route is the
    // one being popped — a sheet opened from inside the player is a route above
    // it and still closes first, which is the order we want.
    return PopScope(
      canPop: !_playerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closePlayerOverlay();
      },
      child: DropTarget(
      onDragEntered: (_) { if (mounted) setState(() => _dragOver = true); },
      onDragExited:  (_) { if (mounted) setState(() => _dragOver = false); },
      onDragDone: (detail) async {
        if (mounted) setState(() => _dragOver = false);
        await _openLocalPaths([for (final f in detail.files) f.path]);
      },
      child: Stack(children: [
        Scaffold(
        // Top-level Row: nav rail (desktop) | content stack
        body: Row(
          children: [
            // Left nav rail — separate from Stack so it's never covered by overlay.
            if (isDesktop) ...[
              NavigationRail(
                extended: extendRail,
                // 160 suffisait aux six onglets (« Bibliothèque » est le plus
                // long) mais pas à « Téléchargements », qui sortait tronqué.
                minExtendedWidth: 200,
                selectedIndex: _index,
                onDestinationSelected: _onTabSelected,
                destinations: railDestinations,
                // Brand tint on the selected ICON (and label), matching the
                // bottom bar: 60% veil pill, full-opacity neon glyph on top.
                indicatorColor: cs.secondaryContainer.withValues(alpha: 0.6),
                selectedIconTheme:
                    const IconThemeData(color: _kBrandPink),
                selectedLabelTextStyle: const TextStyle(
                    color: _kBrandPink, fontWeight: FontWeight.w600),
              ),
              const VerticalDivider(width: 1, thickness: 1),
            ],

            // Content column + queue overlay in a Stack.
            // Mini player is at the bottom of the Column so it is never behind the nav rail,
            // but the queue overlay (full-height Positioned) does cover it on the right —
            // which is fine because the close button lives inside the overlay.
            Expanded(
              child: Stack(
                children: [
                  // EXPÉRIMENTATION verre: le mini-lecteur FLOTTE au-dessus du
                  // contenu au lieu de le pousser — c'est la seule façon
                  // d'avoir quelque chose à flouter derrière lui. Le contenu
                  // récupère la place en padding (MediaQuery), sinon la
                  // dernière ligne d'une liste finit sous le verre.
                  // Le chrome condensé rend la place du mini-lecteur au
                  // contenu — l'inset suit l'animation (AnimatedBuilder).
                  AnimatedBuilder(
                    // _controller aussi: l'inset dépend de hasFile, qui change
                    // sans setState du shell (voir _phoneChrome).
                    animation: Listenable.merge([_chromeT, _controller]),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        padding: MediaQuery.of(context).padding.copyWith(
                              bottom: MediaQuery.of(context).padding.bottom +
                                  (isDesktop
                                      ? _kGlassInset
                                      : _kNavBarHeight +
                                          _kNavBarLift +
                                          _kGlassGap) +
                                  (_controller.hasFile
                                      ? (1 - _chromeT.value) *
                                          (_kMiniPlayerHeight + _kGlassGap)
                                      : 0),
                            ),
                      ),
                      child: child!,
                    ),
                    // Un scroll vertical, n'importe où dans le contenu,
                    // condense le chrome (façon Apple Music); revenir TOUT EN
                    // HAUT le ré-étend, comme le tap sur l'icône condensée ou
                    // un changement d'onglet.
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (isDesktop || !_controller.hasFile) return false;
                        if (n.metrics.axis != Axis.vertical) return false;
                        if (n is! ScrollUpdateNotification) return false;
                        final atTop = n.metrics.pixels <=
                            n.metrics.minScrollExtent + 1;
                        if (atTop) {
                          _setChromeCondensed(false);
                        } else if ((n.scrollDelta ?? 0).abs() > 0.5) {
                          _setChromeCondensed(true);
                        }
                        return false;
                      },
                      child: body,
                    ),
                  ),
                  // Queue panel — full-height overlay, blurred background.
                  //
                  // ⚠️ CLÉ OBLIGATOIRE, sur celui-ci comme sur le mini-lecteur
                  // juste en dessous. Cet enfant est CONDITIONNEL et le
                  // mini-lecteur le suit désormais dans le Stack: sans clé,
                  // Flutter réapparie les enfants par POSITION, donc chaque
                  // bascule de la queue décale le mini-lecteur d'un cran et
                  // désactive/réactive son élément — or il porte un GlobalKey,
                  // et cette réactivation tombe pendant le layout d'un
                  // LayoutBuilder: « A _RenderLayoutBuilder was mutated in
                  // _RenderLayoutBuilder.performLayout ». Avec des clés,
                  // l'appariement se fait par identité et l'élément est réutilisé.
                  if (showQueueOverlay)
                    Positioned(
                      key: const ValueKey('queue-panel'),
                      top: 0,
                      bottom: 0,
                      right: 0,
                      width: _kQueuePanelWidth,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.7),
                              border: Border(
                                left: BorderSide(
                                  color: cs.outlineVariant.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                            ),
                            // Le mini-lecteur passe PAR-DESSUS ce panneau (il
                            // est après lui dans le Stack), donc les dernières
                            // lignes de la queue doivent lui laisser sa place —
                            // sinon la piste du bas est définitivement cachée.
                            padding: EdgeInsets.only(
                              bottom: _controller.filePath == null
                                  ? 0
                                  : _kMiniPlayerReserve,
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: ListenableBuilder(
                                    listenable: _controller,
                                    builder: (context, _) => QueuePanel(
                                      cs: cs,
                                      queue: _sidebarQueue(),
                                      currentIdx: _controller.queue.isEmpty
                                          ? 0
                                          : _controller.queueIdx,
                                      onTap: _controller.goToQueueIndex,
                                          backgroundColor: Colors.transparent,
                                      title: l10n.playerQueue,
                                      onClose: () => setState(
                                          () => _showSidebarQueue = false),
                                      shuffleEnabled: _controller.shuffleEnabled,
                                      onToggleShuffle: _controller.toggleShuffle,
                                      loopMode: _controller.loopMode,
                                      onCycleLoop: _controller.cycleLoopMode,
                                      onAddToPlaylist: _queue.isEmpty
                                          ? null
                                          : () => showAddToPlaylistSheet(context,
                                              resolveTrackIds: _queueTrackIds),
                                      onClearQueue:
                                          _queue.isEmpty ? null : _clearQueue,
                                      onReorder: _queue.isEmpty
                                          ? null : _reorderQueue,
                                      onRemove: _queue.isEmpty
                                          ? null : _removeFromQueue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  Positioned(
                    // Voir la note sur le panneau de queue: clé obligatoire, le
                    // sous-arbre porte un GlobalKey et son voisin est conditionnel.
                    key: const ValueKey('bottom-chrome'),
                    left: 0,
                    right: 0,
                    // `extendBody` fait descendre le corps jusqu'au bas de la
                    // fenêtre: sans ce décalage, le mini-lecteur se retrouve
                    // SOUS la barre de navigation, invisible. En mode barre
                    // latérale il n'y a pas de barre du bas, mais la dalle ne
                    // doit pas toucher le bas de la fenêtre pour autant.
                    bottom: (isDesktop ? _kGlassInset : _kNavBarLift) +
                        MediaQuery.of(context).padding.bottom,
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.only(
                        // Même marge dans les deux dispositions: en mode
                        // barre latérale la dalle touchait le bord droit de la
                        // fenêtre et le séparateur du rail à gauche.
                        left: _kGlassInset,
                        // La queue ne PREND PLUS de largeur au mini-lecteur:
                        // il passe PAR-DESSUS (il est désormais après elle dans
                        // le Stack). Lui retrancher les 320 px du panneau le
                        // réduisait à 267 px sur une fenêtre étroite avec le
                        // rail — moins que la somme de ses enfants fixes, d'où
                        // « A RenderFlex overflowed by 1.00 pixels ». Une barre
                        // de transport n'a pas de largeur souple: la seule
                        // place qu'on peut lui rendre est celle du panneau.
                        right: _kGlassInset,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const DownloadBanner(),
                          // Carried up with the opening player while the two
                          // cross-fade, so the bar does not sit still under a
                          // screen that is visibly growing out of it.
                          // Sur téléphone, mini-lecteur + barre vivent dans
                          // _phoneChrome (chrome condensable façon Apple
                          // Music); en desktop le mini-lecteur reste seul.
                          if (isDesktop)
                            AnimatedBuilder(
                              animation: _playerCtrl,
                              builder: (context, child) =>
                                  Transform.translate(
                                offset: Offset(0, _miniPlayerFollow()),
                                child: child,
                              ),
                              child: _buildMiniPlayer(isDesktop),
                            )
                          else
                            _phoneChrome(context, cs, barDestinations),
                        ],
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ],
        ),
        // EXPÉRIMENTATION verre: la barre de navigation N'EST PLUS dans le
        // slot `bottomNavigationBar` du Scaffold. Elle y ajoutait la marge de
        // sécurité du bas à sa propre hauteur (SafeArea interne), et la dalle
        // de verre s'étirait donc jusqu'au bord de l'écran sur iPhone alors
        // que les icônes tenaient dans leurs 52 px. `removePadding` n'a pas
        // suffi. Elle est maintenant posée dans le MÊME overlay que le
        // mini-lecteur, dans une boîte dont nous fixons la hauteur — plus
        // aucune couche intermédiaire ne peut la gonfler.
        extendBody: true,
        ),
        // The FULL PLAYER — last, so it covers the nav bar, the mini player and
        // the drop feedback, exactly as its route used to. It is the real
        // screen at every point of the animation: that is the whole reason it
        // stopped being a route (see _playerCtrl).
        if (_playerMounted)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _playerCtrl,
              // Built ONCE per animation frame instead of rebuilt: the player
              // subtree is heavy (visualizer, artwork) and only its offset
              // changes while it rises.
              //
              // The Scaffold and the ScaffoldMessenger came FREE with the route
              // and had to move with the player: without the Scaffold there is
              // no Material ancestor and every InkResponse inside asserts
              // ("No Material widget found", hundreds per frame); without its
              // own messenger, a SnackBar fired from inside the player lands on
              // the Scaffold BENEATH it — invisible under a full-screen player.
              // Transparent, because the visible surface is the capped, centred
              // slab PlayerScreen paints itself.
              child: ScaffoldMessenger(
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: _buildPlayerScreen(),
                ),
              ),
              builder: (context, child) {
                final v = _playerCtrl.value;
                final screen = MediaQuery.sizeOf(context);
                final full = Offset.zero & screen;
                // The player GROWS OUT OF the mini player rather than sliding
                // in from the screen edge: at 0 the window on it is the bar's
                // own rect, at 1 the whole screen. Its content is laid out at
                // full size the entire time (OverflowBox), so nothing reflows
                // while it opens — only the window and the corner radius move.
                final from = _openFromRect ?? full;
                // TWO SPEEDS, and that is the point. Escaping the bar — going
                // full width and dropping to the bottom edge — happens in the
                // first few pixels of travel: it is a change of IDENTITY, not a
                // distance, and stretching it over the whole drag made the
                // player look like a growing box rather than something that
                // came out of the bar. The TOP edge then follows the finger
                // linearly for the rest, which is the part that IS a distance.
                final e = (v / _kEmergeFraction).clamp(0.0, 1.0);
                final p = ((v - _kEmergeFraction) / _kPushFraction)
                    .clamp(0.0, 1.0)
                    .toDouble();
                // Chrome condensé (1 ligne): la pastille de nav est à GAUCHE
                // du mini-lecteur, chassée au rythme de v — le bord gauche du
                // lecteur doit avancer au MÊME rythme (il la pousse), pas en
                // 12 % (il la recouvrait pendant qu'elle partait lentement).
                final leftT = ui.lerpDouble(e, v, _chromeT.value)!;
                final rect = Rect.fromLTRB(
                  // Beat 1: full width (left edge paced by the condensed pill).
                  ui.lerpDouble(from.left,   0,              leftT)!,
                  // Beat 3: the top edge under the finger, all the way.
                  ui.lerpDouble(from.top,    0,              v)!,
                  ui.lerpDouble(from.right,  screen.width,   e)!,
                  // Beat 2: down over the nav bar, in step with it leaving.
                  ui.lerpDouble(from.bottom, screen.height,  p)!,
                );
                final radius = ui.lerpDouble(18, 20, e)!;
                // The cross-fade rides the SAME fast phase: past it the bar is
                // fully covered and the two must already read as one object.
                final fade = (v / _kFadeEnd).clamp(0.0, 1.0);
                return Stack(children: [
                    // The scrim the modal barrier used to draw.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.55 * v),
                        ),
                      ),
                    ),
                    Positioned.fromRect(
                      rect: rect,
                      child: Opacity(
                        opacity: fade,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(radius),
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minWidth: screen.width,
                            maxWidth: screen.width,
                            minHeight: screen.height,
                            maxHeight: screen.height,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                ]);
              },
            ),
          ),
        // Feedback while a drag hovers. IgnorePointer or it would eat the drop
        // it is announcing.
        if (_dragOver)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  border: Border.all(color: cs.primary, width: 3),
                ),
              ),
            ),
          ),
      ]),
    ),
    );
  }
}

/// Wraps a screen in its own Navigator so pushes from that screen
/// stay within the tab content area.
class _TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navKey;
  final Widget child;
  final NavigatorObserver? observer;

  const _TabNavigator(
      {required this.navKey, required this.child, this.observer});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navKey,
      observers: observer == null ? const [] : [observer!],
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) => child,
      ),
    );
  }
}

/// Mirrors one tab's route names into a plain list. An observer rather than
/// bookkeeping inside the push helper, because plenty of screens push their
/// own routes directly (an album opening an artist): missing those would make
/// the list claim a stale screen is on top, and the next push would be
/// wrongly skipped.
class _TabRouteObserver extends NavigatorObserver {
  final List<String?> stack;
  _TabRouteObserver(this.stack);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    stack.add(route.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _drop(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _drop(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _drop(oldRoute);
    if (newRoute != null) stack.add(newRoute.settings.name);
  }

  // Remove by NAME from the top down: a pop is normally the last entry, but
  // popUntil removes several and out of order.
  void _drop(Route<dynamic> route) {
    final i = stack.lastIndexOf(route.settings.name);
    if (i >= 0) stack.removeAt(i);
  }
}

/// Rewamp brand accent tinting the selected nav GLYPH. Hot neon magenta —
/// the sunset sun's deep magenta (0xFFE81E8C, platform_artwork.dart) pushed
/// to full brightness: the soft pink 0xFFFF6FB4 read as dull on the chrome.
const Color _kBrandPink = Color(0xFFFF1E8C);

/// Nav-bar icon with OUR square highlight: filled (secondaryContainer) when
/// selected, ghost (low-alpha onSurface) on hover — same 38×38 rounded-square
/// geometry in both states. Exists because the M3 indicator/overlay pair is
/// locked to a 64×32 rectangle: indicator size isn't themable and the
/// hover/pressed veil is drawn at that same shape, so both are disabled on the
/// NavigationBar (indicatorColor/overlayColor transparent) and the highlight
/// lives here instead.
class _NavSquareIcon extends StatefulWidget {
  final IconData icon;
  final bool selected;

  const _NavSquareIcon(this.icon, {this.selected = false});

  @override
  State<_NavSquareIcon> createState() => _NavSquareIconState();
}

class _NavSquareIconState extends State<_NavSquareIcon> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      // Painted veil-first: the selected square is a 60% veil over the glass
      // (chrome shows through), then the glyph on top at FULL opacity so the
      // brand neon keeps its punch.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: widget.selected
              ? cs.secondaryContainer.withValues(alpha: 0.6)
              : _hover
                  ? cs.onSurface.withValues(alpha: 0.08)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(widget.icon),
      ),
    );
  }
}

/// Wraps the « … » nav icon with the download-queue counter — one glance says
/// work is queued without opening the menu.
class _NavDownloadBadge extends StatelessWidget {
  final Widget child;

  const _NavDownloadBadge({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // downloadStatus too: a play-path download runs outside the manager but
      // still counts as download activity.
      listenable:
          Listenable.merge([DownloadManager.instance, RewampDb.downloadStatus]),
      builder: (context, _) {
        final n = downloadActivityCount();
        if (n == 0) return child;
        return Badge.count(count: n, child: child);
      },
    );
  }
}

/// Manager jobs + the direct (play-path) download when one is running outside
/// the manager — the number every downloads badge shows.
int downloadActivityCount() {
  final mgr = DownloadManager.instance;
  final direct = mgr.active == null &&
      RewampDb.downloadStatus.value != null &&
      RewampDb.downloadStatus.value!.error == null;
  return mgr.count + (direct ? 1 : 0);
}

/// L'icône de la ligne « Téléchargements » du rail: l'état de la file (en
/// pause / en cours) et sa pastille de compte, sur l'ICÔNE seule — dans un
/// rail déployé, une pastille posée sur toute la ligne atterrirait au bout du
/// libellé. Elle s'abonne elle-même, pour ne pas reconstruire le rail entier à
/// chaque avancée de téléchargement.
class _DownloadRailIcon extends StatelessWidget {
  const _DownloadRailIcon();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable:
          Listenable.merge([DownloadManager.instance, RewampDb.downloadStatus]),
      builder: (context, _) {
        final n = downloadActivityCount();
        final icon = Icon(DownloadManager.instance.paused
            ? Icons.pause_circle_outline
            : Icons.download_outlined);
        return n > 0 ? Badge.count(count: n, child: icon) : icon;
      },
    );
  }
}
