import 'dart:io' show File, Platform;
import 'dart:ui';
import 'app_snack.dart';
import 'sync_service.dart';
import 'artist_links.dart';
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, listEquals, setEquals;
import 'package:flutter/gestures.dart'
    show kTouchSlop, PointerPanZoomStartEvent, PointerPanZoomUpdateEvent;
import 'package:flutter/material.dart';

import 'favorite_color.dart';
import 'fullscreen_progress_line.dart';
import 'package:flutter/services.dart' show HapticFeedback, MethodChannel;
import 'competition_screen.dart' show podiumColor;
import 'l10n.dart';
import 'podium_badge.dart';
import 'player_controller.dart' show PlayerController, QueueEntry;
import 'playlist_picker.dart';
import 'scrolling_text.dart';
import 'viz_selector_widget.dart';
import 'screen_wakelock.dart';
import 'user_settings.dart';
import 'artwork_image.dart';
import 'artwork_palette.dart';
import 'platform_artwork.dart' show platformAssetFor;
import 'local_db.dart';
import 'audio_route.dart';
import 'download_banner.dart';
import 'note_markdown.dart';
import 'orientation_lock.dart';
import 'production_screen.dart' show openProductionOn;
import 'rewamp_db.dart' show DownloadInfo, ProductionRef, RewampDb;
import 'uade_info.dart';
import 'sap_info.dart';
import 'track_info_flash.dart';
import 'track_options_sheet.dart';
import 'video_screen.dart';
import 'transport_buttons.dart';
import 'voices_sheet.dart';

// TODO(artwork-bg): when the C backend exposes vizSetArtworkTexture(pixels,w,h,opacity),
// pass the current artwork bitmap here so the GL renderer composites it as a
// semi-transparent underlay behind the oscilloscope — same behaviour as Modizer.

/// The full player's own background. In dark themes it sits a notch above
/// `surface`: the artwork's black drop shadow is otherwise invisible against a
/// near-black sheet, and tinting the shadow instead read as neon.
Color playerSurfaceColor(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  if (Theme.of(context).brightness != Brightness.dark) return cs.surface;
  return Color.alphaBlend(Colors.white.withValues(alpha: 0.05), cs.surface);
}

class PlayerScreen extends StatefulWidget {
  final PlayerController   controller;
  final OnNavigateAlbum?   onNavigateAlbum;
  final OnNavigateArtist?  onNavigateArtist;
  /// Launches a search filtered by a tag (from the info panel's tag chips).
  final OnNavigateTag?     onNavigateTag;
  /// Opens the subsong list (ContainerSubsongScreen) for the current file.
  /// Non-null only when the current track is a single-file multi-subsong
  /// container that is NOT a real server album — replaces the album link.
  final VoidCallback?      onNavigateSubsongs;
  /// Nom du CONTENEUR en cours (un `.sid`, un `.gbs`…), quand la file est
  /// faite de ses sous-chansons. Sert d'étiquette à la ligne d'album quand il
  /// n'y a pas d'album — ce qui est la règle pour hvsc/asma/modland, dont les
  /// lignes n'ont pas d'album_id, et dont les formats n'ont aucun conteneur de
  /// tags (ID3/Vorbis/RIFF) où le moteur pourrait en trouver un.
  final String?            subsongContainerName;
  /// Forces a re-download of the CURRENT single file (delete + refetch + replay),
  /// so a server-side update is picked up on demand. Null when unavailable.
  final VoidCallback?      onRedownload;

  /// Set when the player is hosted as an OVERLAY instead of a route (AppShell's
  /// swipe-up open). Closing then means driving the host's animation, not
  /// popping — and the animation the video teardown watches is the host's, not
  /// `ModalRoute.of(context)`.
  ///
  /// The player is an overlay so a swipe can raise the REAL screen: a route
  /// cannot be pushed mid-drag (it cancels the pointer), and anything else on
  /// screen while dragging is an imitation that drifts from the real thing.
  final VoidCallback?          onHostClose;
  /// The host's open/close animation — also DRIVEN here by the dismiss drag,
  /// which `showModalBottomSheet` used to provide and an overlay does not.
  final AnimationController?   hostController;

  const PlayerScreen({
    super.key,
    required this.controller,
    this.onNavigateAlbum,
    this.onNavigateArtist,
    this.onNavigateTag,
    this.onNavigateSubsongs,
    this.subsongContainerName,
    this.onRedownload,
    this.onHostClose,
    this.hostController,
  });

  static void show(
    BuildContext       context,
    PlayerController   controller, {
    OnNavigateAlbum?   onNavigateAlbum,
    OnNavigateArtist?  onNavigateArtist,
    OnNavigateTag?     onNavigateTag,
    VoidCallback?      onNavigateSubsongs,
    String?            subsongContainerName,
    VoidCallback?      onRedownload,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // The safe-area inset is applied INSIDE (see build) rather than by the
      // sheet: with useSafeArea the sheet simply stopped below the notch, so
      // the fullscreen visualizer had the dimmed home showing in the status-bar
      // strip instead of black. Now the sheet spans the whole screen and only
      // its CONTENT is inset, which lets the fullscreen backdrop paint edge to
      // edge behind the safe areas.
      useSafeArea: false,
      // Material caps modal bottom sheets at ~640 pt wide on large screens; the
      // player already fills the full height, so let it fill the full width too —
      // otherwise the fullscreen visualizer is boxed to that 640 pt column.
      constraints: const BoxConstraints(maxWidth: double.infinity),
      // The sheet's own Material must be TRANSPARENT: the visible surface is the
      // capped/centred Container inside PlayerScreen.build — an opaque sheet
      // Material would span the full width and hide the home behind the player.
      backgroundColor: Colors.transparent,
      elevation: 0,
      // Own ScaffoldMessenger: SnackBars fired from inside the player (library
      // add, favourites, …) otherwise land on the Scaffold BENEATH the sheet —
      // invisible while the player covers it. The transparent Scaffold hosts
      // them above the sheet content.
      builder: (_) => ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: PlayerScreen(
            controller:         controller,
            onNavigateAlbum:    onNavigateAlbum,
            onNavigateArtist:   onNavigateArtist,
            onNavigateTag:      onNavigateTag,
            onNavigateSubsongs: onNavigateSubsongs,
            subsongContainerName: subsongContainerName,
            onRedownload:       onRedownload,
          ),
        ),
      ),
    );
  }

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late bool _showVisualizer;
  // Inline demozoo-video mode: the video plays in the SAME frame as the
  // visualizer/artwork; fullscreen is an explicit button. Auto-exits when the
  // music is resumed or the track changes (videos reset).
  bool _showVideo  = false;
  bool _videoFs    = false;   // video expanded in place (chrome hidden)
  int  _videoIndex = 0;
  bool _showQueue = false;
  /// Closing in progress: the panel is on its way OUT and must stay mounted.
  /// Without it the panel vanished on the frame `_showQueue` went false — the
  /// flying cover animated back over a hole. It fades on the tail of the same
  /// reverse flight (the first ~20% of 420 ms, so ~85 ms), which is why the
  /// close needs no animation of its own.
  bool _queueClosing = false;

  // ── Queue reveal: flying artwork copy ─────────────────────────────────────
  // A copy of the player's cover shrinks into the current row's thumbnail when
  // the panel opens. DELIBERATELY decoupled from the panel: the animation
  // drives no setState, mounts/unmounts nothing, and the panel knows nothing
  // about it (the flight child is ALWAYS in the Stack, drawing nothing while
  // idle) — an earlier version that rebuilt the panel from animation status
  // left it unpainted on-device, in a way no widget test reproduced.
  late final AnimationController _flightCtrl;
  late final Animation<double>   _flightAnim;
  final ValueNotifier<Rect?> _flightFrom = ValueNotifier(null);
  final ValueNotifier<Rect?> _flightTo   = ValueNotifier(null);
  final GlobalKey _artKey         = GlobalKey();  // player artwork (start)
  final GlobalKey _queueListKey   = GlobalKey();  // queue list area (target)
  final GlobalKey _visualStackKey = GlobalKey();  // shared coordinate space
  final GlobalKey<QueuePanelState> _queuePanelKey = GlobalKey();
  bool _windowFullscreen = false;   // native macOS window fullscreen state
  bool _vizFs = false;              // viz-fullscreen MODE (chrome hidden)
  bool _tookWindowFs = false;       // we entered window fullscreen ourselves
  // Stable key so the viz widget (and its registered GL texture) keeps identity
  // when the surrounding chrome toggles (see _buildTabBarLayout).
  final GlobalKey _vizKey = GlobalKey();

  static const _windowCh = MethodChannel('rewamp/window');
  bool get _macDesktop => !kIsWeb && Platform.isMacOS;

  // Viz fills the whole sheet ONLY in viz-fullscreen mode (the viz button /
  // double-tap). Native window fullscreen taken by the user (green button)
  // keeps the classic layout — it must NOT force the visualizer fullscreen.
  bool get _fsActive =>
      (_vizFs && _showVisualizer) || (_videoFs && _showVideo);
  double? _seekDragValue; // non-null while user is dragging the seek bar

  // Local files: artist navigation only makes sense for names the server
  // actually knows (same rule as _PlayerOptionsSheetState). Cached per
  // artist string so track changes (queue skip) re-check.
  Set<String>? _serverArtists;
  String? _serverArtistsCheckedFor;

  /// The credit as its individual artists. Prefers the catalogue's own list
  /// (names + aligned uuids): splitting the flattened label is a guess that
  /// cannot survive a name containing "&", and it throws the ids away, so a
  /// homonym opens the wrong profile. Falls back to the split only for the
  /// sources that never had a list — a local file's tag, a DB row.
  static List<String> _artistNamesOf(PlayerController ctrl, String artist) =>
      ctrl.currentArtistNames.isNotEmpty
          ? ctrl.currentArtistNames
          : splitArtistCredit(artist);

  static List<String> _artistIdsOf(PlayerController ctrl) =>
      ctrl.currentArtistNames.isNotEmpty ? ctrl.currentArtistIds : const [];

  void _ensureServerArtistsChecked(bool isLocal, String artist) {
    if (!isLocal) return;
    if (_serverArtistsCheckedFor == artist) return;
    _serverArtistsCheckedFor = artist;
    _serverArtists = null;
    // A local file has no catalogue credit by definition, so its own tag is
    // all there is to split here.
    _checkServerArtists(splitArtistCredit(artist));
  }

  Future<void> _checkServerArtists(List<String> names) async {
    final found = <String>{};
    for (final name in names) {
      try {
        final matches = await RewampDb.fetchArtists(nameFilter: name, limit: 5);
        if (matches.any((a) => a.name.toLowerCase() == name.toLowerCase())) {
          found.add(name);
        }
      } catch (_) {/* offline → leave hidden */}
    }
    if (mounted) setState(() => _serverArtists = found);
  }

  /// Opens ONE artist. There used to be a picker sheet here, because the line
  /// was a single link for the whole credit and the tap had to ask which of
  /// the names was meant; each name is now its own target, so the tap knows.
  void _openArtist(String name, {String? artistId}) {
    if (widget.onNavigateArtist == null) return;
    _dismiss();   // the player must not stay on top of the artist screen
                  // being pushed underneath.
    widget.onNavigateArtist!(name, artistId: artistId);
  }

  @override
  void initState() {
    super.initState();
    _flightCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    // Plain symmetric cubic: emphasized's steep mid-flight acceleration read
    // as violent at this travel distance; this one stays calm without being
    // slow (same 420 ms).
    _flightAnim = CurvedAnimation(
        parent: _flightCtrl, curve: Curves.easeInOutCubic);
    // The closing flight has landed → the panel can finally leave the tree.
    _flightCtrl.addStatusListener((st) {
      if (st == AnimationStatus.dismissed && _queueClosing && mounted) {
        setState(() => _queueClosing = false);
      }
      // Open fade finished over a visualizer → rebuild so it unmounts
      // (updates stop) now that the panel fully covers it.
      if (st == AnimationStatus.completed && _showQueue && mounted) {
        setState(() {});
      }
    });
    // Register the player-closer so delete flows elsewhere (album options,
    // container screen) can dismiss this sheet when they remove the playing file.
    widget.controller.playerUiCloser = () {
      if (mounted) unawaited(_closePlayer());
    };
    _showVisualizer = UserSettings.instance.showVisualizer;
    _syncWakelock();
    UserSettings.instance.addListener(_onSettingsChanged);
    widget.controller.addListener(_onControllerChanged);
    _onControllerChanged(); // seed the artwork identity for the current track
    WidgetsBinding.instance.addObserver(this); // rotation → auto-fullscreen
    // The player just opened with a viz/video area: allow phone rotation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncOrientation();
    });
    if (_macDesktop) {
      _windowCh.setMethodCallHandler((call) async {
        if (call.method == 'onFullScreenChanged' && mounted) {
          final fs = call.arguments == true;
          setState(() {
            _windowFullscreen = fs;
            if (!fs) {
              // Escape / green button exited window fullscreen → also leave
              // viz-fullscreen mode.
              _vizFs = false;
              _tookWindowFs = false;
            }
          });
        }
        return null;
      });
    }
  }

  @override
  void dispose() {
    _routeAnim?.removeStatusListener(_onRouteAnimStatus);
    // The sheet can be dismissed with rotation unlocked (viz visible, delete
    // flow, playerUiCloser) — restore the phone portrait lock.
    OrientationLock.lock();
    WidgetsBinding.instance.removeObserver(this);
    _cursorTimer?.cancel();
    _cursorHidden.dispose();
    widget.controller.playerUiCloser = null;
    widget.controller.removeListener(_onControllerChanged);
    PlayerTint.dominant = null; // player closed → panels elsewhere stay neutral
    PlayerTint.dominantAlt = null;
    UserSettings.instance.removeListener(_onSettingsChanged);
    // The visualizer goes with the sheet, so the display hold does too — the
    // player is the ONLY place a viz is mounted (it is torn down at 0), which
    // is what makes this the single release site.
    if (_wakelockHeld) {
      _wakelockHeld = false;
      unawaited(ScreenWakelock.instance.release());
    }
    if (_macDesktop) _windowCh.setMethodCallHandler(null);
    _flightCtrl.dispose();
    _tintTick.dispose();
    super.dispose();
  }

  // The sheet route's animation — watched only to drop the video WebView as
  // soon as the sheet starts closing (see _onRouteAnimStatus).
  Animation<double>? _routeAnim;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The HOST's animation when the player is an overlay; the route's otherwise.
    final anim = widget.hostController ?? ModalRoute.of(context)?.animation;
    if (identical(anim, _routeAnim)) return;
    _routeAnim?.removeStatusListener(_onRouteAnimStatus);
    _routeAnim = anim;
    _routeAnim?.addStatusListener(_onRouteAnimStatus);
  }

  /// Last-resort teardown: the sheet is already animating out and the video is
  /// somehow still mounted. Tearing a WebView platform view down INSIDE the
  /// closing transition is what stalls the sheet half-way — this listener used
  /// to be the only teardown, and `reverse` fires at the FIRST frame of the
  /// close (on a drag-to-dismiss, as soon as the pointer starts moving, since
  /// showModalBottomSheet drives the route animation straight from the drag).
  /// So it always destroyed the WKWebView mid-transition and merely got away
  /// with it most of the time; after a fullscreen round trip, with the view
  /// freshly re-laid-out twice, the platform thread blocked long enough for the
  /// animation to freeze at mid-course — the app still answered, and a click on
  /// the barrier finished the close.
  ///
  /// The real teardowns now happen BEFORE the transition: [_closePlayer] for
  /// every explicit close, [_onSheetPointerMove] for the dismiss drag. This
  /// stays as the backstop for any path that reaches a pop without them.
  void _onRouteAnimStatus(AnimationStatus status) {
    if (status != AnimationStatus.reverse) return;
    if (!mounted || !(_showVideo || _videoFs)) return;
    setState(() { _showVideo = false; _videoFs = false; });
  }

  /// Closes the player, giving a mounted video panel one full frame to go away
  /// first. The pop then animates over a pure-Flutter tree, with no platform
  /// view to dispose mid-flight.
  Future<void> _closePlayer() async {
    if (_showVideo || _videoFs) {
      setState(() { _showVideo = false; _videoFs = false; });
      _syncOrientation();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    if (mounted) _dismiss();
  }

  /// Makes the player go away, WHATEVER hosts it: an overlay animates back
  /// down, a route pops. Every "close the player" path goes through here — a
  /// stray `Navigator.pop` would take the screen underneath instead.
  void _dismiss() {
    final host = widget.onHostClose;
    if (host != null) {
      host();
      return;
    }
    Navigator.of(context).maybePop();
  }

  // Dismiss-drag detection, one frame ahead of the route animation.
  Offset? _sheetDragFrom;
  // (le drapeau partagé avec le balayage horizontal est en bas de fichier:
  //  _playerDismissDragActive)
  bool    _sheetDragOverVisual = false;
  // Posé par le onPointerDown de la FullscreenSeekBar, consommé par
  // _beginSheetDrag: « ce pointeur est né sur la barre ».
  bool    _seekBarTouched = false;

  void _onSheetPointerDown(PointerDownEvent e) => _beginSheetDrag(e.position);

  /// Trackpad. A two-finger swipe emits PAN-ZOOM events, never PointerMove, so
  /// the dismiss drag was invisible to it on macOS whatever the zone — the
  /// `Listener` was only listening for a pressed pointer.
  void _onSheetPanZoomStart(PointerPanZoomStartEvent e) =>
      _beginSheetDrag(e.position);

  void _onSheetPanZoomUpdate(PointerPanZoomUpdateEvent e) =>
      _handleSheetDrag(e.pan.dx, e.pan.dy);

  void _beginSheetDrag(Offset pos) {
    // Un geste parti de la SEEK BAR appartient à la seek bar, verticale
    // comprise: son aire tactile est opaque pour les RECONNAISSEURS, mais ce
    // Listener-ci est hors arène et voyait quand même le pointeur — un scrub
    // un peu de biais repliait le lecteur. L'enfant reçoit le down AVANT nous
    // (chemin de hit-test), donc le drapeau est déjà posé en arrivant ici.
    if (_seekBarTouched) {
      _seekBarTouched = false;
      _sheetDragFrom = null;
      _playerDismissDragActive = false;
      return;
    }
    _sheetDragFrom = pos;
    // Filet: un `up` manqué (pointeur annulé par une route, geste avalé par un
    // enfant) laisserait le balayage horizontal muet pour toujours.
    _playerDismissDragActive = false;
    // A drag that starts over the visual panel belongs to what the panel is
    // SHOWING only when that content actually USES vertical drags: the NOTES
    // visualizer pans vertically, and the video embed swallows vertical drags
    // on purpose (a platform view that would otherwise keep the pointer-up).
    // Every other visualizer claims nothing vertical — the dismiss swipe must
    // work over them exactly like over plain artwork (which claims nothing
    // either: excluding the panel unconditionally meant the whole middle of
    // the player refused to dismiss, exactly where the gesture is natural).
    //
    // La QUEUE OUVERTE garde TOUS ses gestes. Ce `Listener` n'entre pas dans
    // l'arène: il voit le pointeur quoi que fasse l'enfant, donc tant qu'il
    // s'autorisait la fermeture au-dessus du panneau, il la déclenchait pendant
    // un scroll ET pendant un glisser-déposer de réordonnancement — le doigt
    // tenait une poignée, le lecteur descendait. La convention iOS « au sommet
    // de la liste, le glissement ferme la feuille » ne vaut pas ici: la liste
    // est réordonnable, donc un glissement vertical partant du haut est
    // ambigu. Le panneau a son propre bouton de fermeture, et le reste du
    // lecteur (transport, pochette hors panneau) ferme toujours.
    if ((_showQueue || _queueClosing) && _visualPanelContains(pos)) {
      _sheetDragOverVisual = true;
      return;
    }
    final vizClaimsVertical =
        _showVisualizer && UserSettings.instance.vizEffect == 'notes';
    _sheetDragOverVisual = (vizClaimsVertical || _showVideo || _videoFs) &&
        _visualPanelContains(pos);
  }

  /// True once this pointer has been claimed as a dismiss drag, so a later
  /// upward move keeps driving it instead of being ignored.
  bool _sheetDragActive = false;

  void _onSheetPointerMove(PointerMoveEvent e) {
    final from = _sheetDragFrom;
    if (from == null) return;
    _handleSheetDrag(e.position.dx - from.dx, e.position.dy - from.dy);
  }

  /// [dy] is how far DOWN the gesture has travelled since it started, [dx] how
  /// far SIDEWAYS, whatever emitted it — a pressed pointer or a trackpad pan.
  void _handleSheetDrag(double dx, double dy) {
    if (_sheetDragFrom == null || _sheetDragOverVisual) return;

    // Drop the WebView as soon as a downward drag passes the slop, while
    // nothing is animating yet.
    if ((_showVideo || _videoFs) && dy >= kTouchSlop) {
      setState(() { _showVideo = false; _videoFs = false; });
      _syncOrientation();
    }

    // Drag DOWN to dismiss. `showModalBottomSheet` gave this for free over the
    // WHOLE sheet; an overlay gives nothing, and putting it on the little
    // handle alone made it undiscoverable — the natural gesture is to pull the
    // artwork area down. Same perimeter as the old sheet: everything EXCEPT the
    // visual panel, where a drag belongs to the visualizer (notes pan/zoom) and
    // to the video embed.
    final host = widget.hostController;
    if (host == null) return;
    if (!_sheetDragActive) {
      if (dy < kTouchSlop) return;   // downward only, and past the slop
      // …et VERTICAL: un geste franchement de biais appartient au balayage
      // horizontal (piste suivante / précédente). Sans cette comparaison, une
      // fermeture un peu diagonale déclenchait les deux à la fois — le
      // `Listener` ne participe pas à l'arène des gestes, donc rien n'arbitre
      // à sa place.
      if (dy.abs() <= dx.abs()) return;
      _sheetDragActive = true;
      // À partir d'ici le geste est à nous jusqu'au relâchement: le balayage
      // horizontal doit se taire même si le doigt part ensuite de côté.
      _playerDismissDragActive = true;
    }
    final h = MediaQuery.sizeOf(context).height;
    host.value = (1 - dy / h).clamp(0.0, 1.0);
  }

  /// Settles the dismiss drag. Under three quarters of the way up the player
  /// goes; above it, it springs back.
  void _onSheetPointerUp(PointerEvent e) {
    _sheetDragFrom = null;
    // ⚠️ Le drapeau n'est PAS baissé ici. Un `Listener` est dans le chemin de
    // hit-test, donc il reçoit le `PointerUp` AVANT que l'arène ne tranche et
    // n'appelle `onHorizontalDragEnd`: le baisser ici le rendait toujours faux
    // au moment où le balayage horizontal le consultait — le blocage ne
    // marchait tout simplement pas. Il retombe au DÉBUT du geste suivant
    // (_beginSheetDrag).
    if (!_sheetDragActive) return;
    _sheetDragActive = false;
    final host = widget.hostController;
    if (host == null) return;
    if (host.value < 0.75) {
      _closePlayer();
    } else {
      host.fling(velocity: 1);
    }
  }

  bool _visualPanelContains(Offset globalPos) {
    final box =
        _visualStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    return (Offset.zero & box.size).contains(box.globalToLocal(globalPos));
  }

  // Phones are portrait-locked except while the player shows a visualizer or
  // a video (fullscreen or not — rotation must be POSSIBLE for the auto-
  // fullscreen below to ever trigger) — call after every mutation of _vizFs /
  // _videoFs / _showVisualizer / _showVideo. No-op on tablets and desktop.
  bool get _rotationAllowed => _showVisualizer || _showVideo;

  void _syncOrientation() {
    if (_rotationAllowed || _fsActive) {
      OrientationLock.unlock();
    } else {
      OrientationLock.lock();
    }
    // Piggyback: every fullscreen mutation goes through here — (re)arm or
    // disarm the idle-cursor timer accordingly.
    _pokeCursor();
  }

  // Fullscreen on desktop: hide the mouse cursor after 3s idle, back on move.
  // A ValueNotifier (not setState) because the sheet subtree sits under
  // DraggableScrollableSheet.builder + LayoutBuilder, which don't re-run on
  // setState (same reason the tint uses _tintTick).
  final ValueNotifier<bool> _cursorHidden = ValueNotifier(false);
  Timer? _cursorTimer;
  bool get _mouseDesktop => !kIsWeb &&
      (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  void _pokeCursor() {
    if (_cursorHidden.value) _cursorHidden.value = false;
    _cursorTimer?.cancel();
    if (!_fsActive || !_mouseDesktop) return;
    _cursorTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _fsActive) _cursorHidden.value = true;
    });
  }

  Widget _fsCursorWrap(Widget child) {
    if (!_mouseDesktop) return child;
    return ValueListenableBuilder<bool>(
      valueListenable: _cursorHidden,
      builder: (_, hidden, c) => MouseRegion(
        cursor: hidden && _fsActive ? SystemMouseCursors.none : MouseCursor.defer,
        onHover: (_) => _pokeCursor(),
        child: c,
      ),
      child: child,
    );
  }

  // Auto-fullscreen on phone rotation: landscape with a viz/video showing →
  // enter fullscreen; back to portrait → leave it. Transitions only (manual
  // fullscreen exit while landscape must not immediately re-enter).
  bool _wasLandscape = false;

  @override
  void didChangeMetrics() {
    if (!mounted || !OrientationLock.isPhone) return;
    final size = View.of(context).physicalSize;
    final landscape = size.width > size.height;
    if (landscape == _wasLandscape) return;
    _wasLandscape = landscape;
    if (landscape && !_fsActive) {
      if (_showVideo) {
        setState(() => _videoFs = true);
      } else if (_showVisualizer) {
        _toggleVizFullscreen();
      }
    } else if (!landscape && _fsActive) {
      if (_videoFs) {
        setState(() => _videoFs = false);
      } else if (_vizFs) {
        _toggleVizFullscreen();
      }
    }
  }

  // Viz fullscreen toggle (viz button / double-tap). Enters native window
  // fullscreen if the window isn't already there; leaving only exits window
  // fullscreen when WE entered it (a green-button fullscreen stays untouched).
  void _toggleVizFullscreen() {
    setState(() {
      if (!_vizFs) {
        _vizFs = true;
        if (_macDesktop && !_windowFullscreen) {
          _tookWindowFs = true;
          _windowCh.invokeMethod('toggleFullScreen');
        }
      } else {
        _vizFs = false;
        if (_macDesktop && _tookWindowFs && _windowFullscreen) {
          _windowCh.invokeMethod('toggleFullScreen');
        }
        _tookWindowFs = false;
      }
    });
    _syncOrientation();
  }

  void _onSettingsChanged() {
    // Rebuild for any setting the sheet reads live (visualizer mode, artwork-
    // tinted background).
    setState(() => _showVisualizer = UserSettings.instance.showVisualizer);
    _syncOrientation();
    _syncWakelock();
  }

  // ── Keep the display awake while a visualizer is up ────────────────────────
  // Watching a visualizer is minutes without a touch, so the idle timer blanks
  // the screen mid-show. Held from the moment the viz is on, not only in
  // fullscreen: the panel in the normal player is just as much a thing you
  // watch. Video is NOT covered here - a WebView embed manages its own idle
  // timer, and doubling that is how you end up never releasing.
  bool _wakelockHeld = false;

  void _syncWakelock() {
    final want = _showVisualizer && UserSettings.instance.vizKeepAwake;
    if (want == _wakelockHeld) return;
    _wakelockHeld = want;
    unawaited(want
        ? ScreenWakelock.instance.acquire()
        : ScreenWakelock.instance.release());
  }

  // ── Artwork-tinted background (Apple-Music-style) ───────────────────────────
  // The offstage ArtworkImage in _buildTabBarLayout resolves whatever artwork
  // the current track has and hands us the provider; ArtworkPalette caches the
  // dominant colour per artwork, so this costs one 64px decode per cover.

  // Dominant colour per artwork identity, remembered across player openings —
  // the sheet gets its tint on the FIRST frame when reopened on a known track
  // (the async extraction otherwise left a visibly neutral pause).
  static final Map<String, ArtworkTint?> _artColorMemo = {};
  // Resolved cover path per track identity, remembered across openings — lets a
  // reopened/known track seed _resolvedArtPath on the FIRST frame so the queue
  // flying copy paints the real cover instantly (no async race that flashed the
  // generic, notably on animated GIFs).
  static final Map<String, String?> _artPathMemo = {};

  ArtworkTint? _artColor;
  String? _artIdentity;    // current track's stable id (filePath)
  // On-disk path of the CURRENT track's real cover (null = none/still loading),
  // resolved by _resolveTint. Handed to the queue-reveal flying copy as its
  // placeholder so its first frames paint the real cover instead of the themed
  // generic — the fresh ArtworkImage mounted at flight start has _localPath=null
  // until its own async _load lands, which flashed the generic for a beat.
  String? _resolvedArtPath;
  // The EXACT provider the main cover resolved and painted (fed by its
  // onImageResolved). Handed to the flight so it reuses the already-decoded,
  // already-cached image — no re-decode, and no divergence from what the screen
  // shows (the display may be on NetworkImage while _resolvedArtPath points at a
  // not-yet-decoded FileImage; painting the path then flashed on first frame).
  ImageProvider? _resolvedArtProvider;
  // Drives the background repaint DIRECTLY. The background's _sheetBase(context)
  // is read inside DraggableScrollableSheet.builder → LayoutBuilder, which do
  // NOT re-run on this State's setState (LayoutBuilder rebuilds on constraint
  // changes; the sheet gates its builder on the scroll extent) — so a tint
  // update landed in PlayerTint but the background never re-read it until a
  // reopen. A ValueListenableBuilder on this notifier bypasses that chain.
  final ValueNotifier<ArtworkTint?> _tintTick =
      ValueNotifier<ArtworkTint?>(null);

  void _onControllerChanged() {
    final c = widget.controller;
    // STABLE identity: filePath, NOT artworkUrl — the latter churns for online
    // tracks (https://…/cover.png → a downloaded /Caches/…png path), which used
    // to flip the identity mid-track and guard out the in-flight extraction
    // (idMatch failed) so the tint never applied without a close/reopen.
    final id = c.filePath ?? '';
    if (id == _artIdentity) return;
    _artIdentity = id;
    // Known track → its cover path immediately (no flash); unknown → null until
    // _resolveTint lands. The exact provider is cleared and re-published by the
    // new cover's onImageResolved (fires as soon as it paints).
    _resolvedArtPath = _artPathMemo[id];
    _resolvedArtProvider = null;
    // New track: seed from the memo (known artwork → tint immediately; unknown →
    // neutral), then resolve directly — NOT via any displayed widget's
    // callbacks. The widget chain (offstage resolver / visible cover) proved
    // unreliable across viz modes, animations and rebuild timing; this is
    // deterministic: pick the image the display WOULD show, extract, apply.
    _setArtColor(_artColorMemo[id]);
    unawaited(_resolveTint(id));
  }

  /// Mirrors ArtworkImage._load's image choice for the current track, extracts
  /// its dominant colour, and applies it if the track is still current.
  Future<void> _resolveTint(String id) async {
    final c = widget.controller;
    final url = c.artworkUrl;
    final filePath = c.filePath;
    String? path;
    try {
      if (url != null && !url.startsWith('http')) {
        // Plain local path (embedded artwork already extracted).
        if (url.isNotEmpty && await File(url).exists()) path = url;
      } else if (url == null && filePath != null) {
        // Local file: user-placed sibling cover, else embedded tag cover.
        path = await ArtworkCache.instance.findLocalArtwork(filePath) ??
            await ArtworkCache.instance.findEmbeddedArtwork(filePath);
      } else if (url != null) {
        // Server artwork: use the cached copy if it's already on disk. If not,
        // do NOT block on the download here — downloads are queued per host
        // with a 1.5 s cooloff (rail thumbnails etc. ahead of us), so awaiting
        // it kept the background NEUTRAL for the whole wait. The display shows
        // the placeholder during the download, so the tint does the same
        // (below), then upgrades when the cover lands.
        path = await ArtworkCache.instance.getPath(
          url,
          artist:        c.currentArtist,
          album:         c.currentAlbum,
          localFilePath: filePath,
          targetDir:     c.artworkTargetDir,
        );
      }
    } catch (_) {/* fall through to the placeholder */}

    // Publish the resolved cover path for the flying copy (guard: still current)
    // and memoize it so a later reopen seeds it synchronously.
    _artPathMemo[id] = path;
    if (_artIdentity == id) _resolvedArtPath = path;

    try {
      if (path != null) {
        await _applyTint(id, FileImage(File(path)), path);
        return;
      }
      // No cover on disk (none, or still downloading) → tint the themed
      // platform placeholder the display is showing right now.
      final asset = platformAssetFor(
          platformName: c.currentPlatformName, pathOrExt: filePath ?? url);
      await _applyTint(id, AssetImage(asset), 'placeholder:$asset');
      if (url != null && url.startsWith('http')) {
        // The display shows the cover via Image.network IMMEDIATELY, while the
        // file download sits in the per-host queue (1.5 s cooloff, thumbnails
        // ahead) or may fail — so tint from the network image first (what the
        // screen shows), then refine from the on-disk copy once it lands.
        await _applyTint(id, NetworkImage(url), url);
        final dl = await ArtworkCache.instance.awaitDownload(url);
        if (dl != null) await _applyTint(id, FileImage(File(dl)), dl);
      }
    } catch (_) {/* keep whatever tint is applied */}
  }

  /// Extracts [provider]'s dominant colour and applies it if [id] is still the
  /// current track.
  Future<void> _applyTint(String id, ImageProvider provider, String key) async {
    final color = await ArtworkPalette.tint(provider, key);
    if (!mounted || _artIdentity != id) return;   // track changed meanwhile
    _artColorMemo[id] = color;
    if (color != _artColor) setState(() => _setArtColor(color));
  }

  /// The tinted base colour: the artwork's dominant hue kept fairly rich
  /// (Apple-Music-like), just darker than the cover in dark mode and lighter
  /// in light mode.
  Color _sheetBase(BuildContext context) =>
      PlayerTint.sheet(context) ?? playerSurfaceColor(context);

  /// Colour the bottom-right glow blooms from. A cover with a genuine SECOND
  /// dominant hue gives it here, so the slab mixes two colours across the
  /// diagonal instead of being one hue lit twice; a single-hue cover falls back
  /// to the base shifted exactly as it always was, which keeps the old look and
  /// — because it is always a real colour — lets the tween animate smoothly
  /// when the next track happens to have two.
  Color _sheetAlt(BuildContext context) {
    final alt = PlayerTint.sheetAlt(context);
    if (alt != null) return alt;
    final hsl = HSLColor.fromColor(_sheetBase(context));
    return hsl
        .withLightness((hsl.lightness - 0.06).clamp(0.0, 1.0))
        .withHue((hsl.hue + 10) % 360)
        .toColor();
  }

  /// Publishes the current tint for the panels this player opens (voices, info,
  /// options) so they share the same colour family.
  void _setArtColor(ArtworkTint? c) {
    _artColor = c;
    PlayerTint.dominant = c?.primary;
    PlayerTint.dominantAlt = c?.secondary;
    _tintTick.value = c;   // repaint the background (see the field comment)
  }

  /// Base fill + two soft radial glows — the gentle mottling Apple Music has
  /// instead of a flat slab. The top-left one is [base] lightened; the
  /// bottom-right one blooms from [alt], the cover's SECOND dominant colour
  /// when it has one (see [_sheetAlt]), so the two hues meet and mix across the
  /// diagonal. Both colours are tween-animated by the caller, so the glows
  /// follow along.
  Widget _sheetBackground(
      BuildContext context, Color base, Color alt, Widget child) {
    // Fullscreen: the two corner glows go to zero alpha rather than being
    // removed. Same reason as everywhere else in this subtree — the tree shape
    // must not change, or the GlobalKey'd visualizer remounts with it. Black
    // shifted +0.10 is a grey haze, which is exactly what one does not want
    // over a fullscreen visualizer.
    final glow = _fsActive ? 0.0 : 1.0;
    final hsl = HSLColor.fromColor(base);
    Color shift(double dl, double dh) => hsl
        .withLightness((hsl.lightness + dl).clamp(0.0, 1.0))
        .withHue((hsl.hue + dh) % 360)
        .toColor();
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: DecoratedBox(
        decoration: BoxDecoration(color: base),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.9, -0.8),
                      radius: 1.4,
                      colors: [
                        // +0.10: the base is deep now (see PlayerTint._tinted);
                        // the old +0.06 was tuned for a pastel slab and reads
                        // as flat on a dark one.
                        shift(0.10, -8).withValues(alpha: 0.60 * glow),
                        shift(0.10, -8).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.9, 0.9),
                      radius: 1.5,
                      colors: [
                        alt.withValues(alpha: 0.62 * glow),
                        alt.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }

  void _toggleQueue() {
    final opening = !_showQueue;
    // Viz (or video) active → NO artwork flight: the cover is not on screen,
    // and swapping the viz for a just-mounted artwork flew a cover out of
    // nowhere. Quick cross-fade instead — the PANEL does the fading over the
    // live visual (Opacity on the Android SurfaceView is not safe), the viz
    // unmounts once fully covered (updates stop; see _visualContent) and
    // remounts under the panel fading back out.
    final vizFade = _showVisualizer || _showVideo;
    setState(() {
      _showQueue = opening;
      // Mount-through for the closing fade; cleared by the status listener.
      if (!opening) _queueClosing = true;
    });
    if (vizFade) {
      _flightFrom.value = _flightTo.value = null;   // no flying copy
      if (opening) {
        _flightCtrl.animateTo(1.0,
            duration: const Duration(milliseconds: 160));
      } else {
        _flightCtrl.animateBack(0.0,
            duration: const Duration(milliseconds: 160));
      }
      return;
    }
    if (!opening) {
      // Closing: measure BEFORE the panel unmounts. The flight starts from the
      // row's LIVE position (the user may have scrolled since opening); a row
      // scrolled out of view yields a zero-size start at the nearest list edge
      // (the cover grows out of it). The artwork stays hidden until landing —
      // see _closingFlight.
      final stackBox =
          _visualStackKey.currentContext?.findRenderObject() as RenderBox?;
      final artBox = _artKey.currentContext?.findRenderObject() as RenderBox?;
      Rect? from, to;
      if (stackBox != null && artBox != null && artBox.hasSize) {
        from = MatrixUtils.transformRect(
            artBox.getTransformTo(stackBox), Offset.zero & artBox.size);
        to = _queuePanelKey.currentState?.coverRectIn(stackBox);
      }
      if (from != null && to != null) {
        _flightFrom.value = from;
        _flightTo.value = to;
      } else {
        // Nothing to fly (measurement failed) — the copy simply draws nothing.
        // The reverse still runs: it is what fades the panel out, and without
        // it the panel would sit there fully opaque with _showQueue false.
        _flightFrom.value = _flightTo.value = null;
      }
      _flightCtrl.reverse(from: 1);
      return;
    }
    _flightCtrl.value = 0;   // panel hidden until the flight lands (or below)
    // Measure once the panel exists (next frame). Both rects live in the
    // visual Stack's space. The landing spot is DERIVED from the list area —
    // the current row is scrolled to the top, its cover sits at a fixed offset
    // in the first row. No key inside the ListView (rows are recycled; a
    // GlobalKey there gets duplicated for a frame and Flutter unmounts the
    // subtree). Failure to measure = no flight, nothing else changes.
    _flightFrom.value = _flightTo.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showQueue) return;
      final stackBox =
          _visualStackKey.currentContext?.findRenderObject() as RenderBox?;
      final artBox = _artKey.currentContext?.findRenderObject() as RenderBox?;
      // The landing spot comes from the panel's own geometry, at the offset
      // its scroll-to-top WILL settle on (see coverRectIn.predictCentered —
      // a short queue clamps that scroll, so the row is not always at row 0's
      // spot). Transform-aware on the artwork side: the paused cover sits
      // under an AnimatedScale(0.75).
      Rect? from, to;
      if (stackBox != null && artBox != null && artBox.hasSize) {
        from = MatrixUtils.transformRect(
            artBox.getTransformTo(stackBox), Offset.zero & artBox.size);
        to = _queuePanelKey.currentState
            ?.coverRectIn(stackBox, predictCentered: true);
      }
      if (from == null || to == null) {
        _flightCtrl.value = 1;   // no flight → reveal the panel right away
        return;
      }
      _flightFrom.value = from;
      _flightTo.value = to;
      _flightCtrl.forward(from: 0);
    });
  }

  String _fmt(double s) {
    final t = s.toInt();
    return '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // When the artwork tint is active the sheet is DEEP whatever the app theme
    // (see PlayerTint._tinted), so the whole subtree runs under a dark scheme
    // seeded from the cover — that is what keeps text/icons legible in a light
    // app theme. `cs` is derived from the override so the many direct `cs.`
    // reads below follow it too.
    final tintTheme = PlayerTint.themeOf(context);
    final theme = tintTheme ?? Theme.of(context);
    final cs = theme.colorScheme;

    // DraggableScrollableSheet provides bounded height constraints (needed for
    // the Expanded widget below).  The scrollController is intentionally unused
    // because we have no scrollable content — all gestures bubble up to the
    // sheet and let it be dragged to resize / dismiss.
    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      // The modal sheet spans the full width (so the fullscreen visualizer can
      // fill the screen), but the visible surface is capped and centred when NOT
      // fullscreen — the transparent sides let the dimmed home show through, as
      // before. A LayoutBuilder + fixed-size SizedBox keeps the height tight (the
      // inner Column has an Expanded) while capping the width; the structure stays
      // constant (only the width value changes) so the keyed viz never reparents.
      builder: (_, __) => LayoutBuilder(
        builder: (ctx, cons) {
          final w = _fsActive
              ? cons.maxWidth
              : (cons.maxWidth < 640 ? cons.maxWidth : 640.0);
          // Safe-area inset applied here (the sheet itself spans the screen —
          // see useSafeArea in show()). Fullscreen paints black UNDER the
          // insets so the notch/home-indicator strips match the visualizer
          // instead of showing the dimmed home through them.
          // NOT MediaQuery.of(ctx): with useSafeArea:false the modal route
          // wraps its child in MediaQuery.removePadding(removeTop: true), so
          // the top inset reads 0 there and the content ran under the notch.
          // The view's own padding is the real one.
          final safe = MediaQueryData.fromView(View.of(ctx)).padding;
          return _fsCursorWrap(Theme(
            data: theme,
            child: Stack(
            children: [
              // ALWAYS present, only its colour changes. A conditional child
              // here would shift every later child's index in this Stack, and
              // Flutter re-matches unkeyed children BY POSITION: toggling
              // fullscreen then remounted the whole subtree — including the
              // GlobalKey'd visualizer, which is what threw the mouse_tracker
              // '!_debugDuringDeviceUpdate' / '_elements.contains(element)'
              // assertion storm. Keeping the slot stable costs one transparent
              // paint.
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: _fsActive ? Colors.black : Colors.transparent,
                  ),
                ),
              ),
              // The transparent side areas belong to the sheet, so taps there
              // never reach the modal barrier — catch them and dismiss, like a
              // barrier tap would.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closePlayer,
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: w,
                  // FULL height, and the safe-area inset moved INSIDE (onto the
                  // content) rather than around this box. Inset here, the
                  // tinted slab stopped at the notch and at the home
                  // indicator, and the dimmed home showed through both strips
                  // — the player looked like it was floating on the previous
                  // screen. The slab now runs edge to edge vertically; only the
                  // controls stay clear of the insets.
                  height: cons.maxHeight,
                  // ValueListenableBuilder so a tint change repaints the
                  // background even though this subtree sits under
                  // DraggableScrollableSheet.builder + LayoutBuilder (which don't
                  // re-run on setState). _sheetBase is re-read inside it.
                  child: ValueListenableBuilder<ArtworkTint?>(
                    valueListenable: _tintTick,
                    child: Padding(
                      // ALL four insets: in landscape the notch lives in
                      // safe.left/right (whichever side is up), and without
                      // them it covered a strip of the fullscreen viz/video.
                      padding: EdgeInsets.only(
                          top: safe.top,
                          bottom: safe.bottom,
                          left: safe.left,
                          right: safe.right),
                      child: ListenableBuilder(
                        listenable: widget.controller,
                        builder: (context, _) => _buildContent(context, cs),
                      ),
                    ),
                    builder: (context, tintV, content) {
                      // Two nested tweens: the slab's base colour and the
                      // second-hue glow animate independently, so a track whose
                      // cover has two dominant colours doesn't snap either of
                      // them when the previous cover only had one.
                      // Fullscreen is BLACK, insets included. The slab runs
                      // edge to edge and the safe areas are a padding INSIDE
                      // it, so leaving it tinted left two coloured strips
                      // framing a black visualizer at the notch and the home
                      // indicator. Only the colours change — the widget tree
                      // stays identical, for the same reason the black
                      // ColoredBox above is always mounted (Flutter re-matches
                      // unkeyed children by POSITION, and remounting this
                      // subtree takes the GlobalKey'd visualizer with it).
                      return TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                          end: _fsActive ? Colors.black : _sheetBase(context)),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      builder: (context, base, child) =>
                          TweenAnimationBuilder<Color?>(
                        tween: ColorTween(
                            end: _fsActive ? Colors.black : _sheetAlt(context)),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        child: child,
                        builder: (context, alt, inner) => _sheetBackground(
                            context,
                            base ?? playerSurfaceColor(context),
                            alt ?? base ?? playerSurfaceColor(context),
                            inner!),
                      ),
                      child: content,
                    );
                    },
                  ),
                ),
              ),
              // Fullscreen hides the player chrome, so the download banner has
              // no row to live in — overlay it at the BOTTOM, just above the
              // fullscreen transport pill (bottomCenter, ~48pt), so it sits
              // right over the controls and stays well visible while a track
              // downloads. Draws nothing while idle, so this costs nothing the
              // rest of the time.
              if (_fsActive)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 76),
                      child: ValueListenableBuilder<DownloadInfo?>(
                        valueListenable: RewampDb.downloadStatus,
                        builder: (_, info, __) => info == null
                            ? const SizedBox.shrink()
                            : const DownloadBanner(),
                      ),
                    ),
                  ),
                ),
            ],
          )));
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme cs) {
    final ctrl = widget.controller;
    // The queue overlay is reachable as soon as something plays: a single-track
    // play leaves the controller's queue empty, and _overlayQueue stands in a
    // one-entry list for it.
    final hasQueue = ctrl.hasFile;
    // Full-player modal always uses the compact tab-bar layout on all screen sizes.
    return _buildTabBarLayout(context, cs, ctrl, hasQueue);
  }

  // The visualizer widget. Its tree position never changes — fullscreen just
  // hides the surrounding player chrome so the viz's Expanded fills the sheet
  // (a Global-key reparent into an overlay tripped Flutter's LayoutBuilder-in-
  // performLayout assertion, so we resize in place instead).
  Widget _vizWidget(PlayerController ctrl) {
    return VizSelectorWidget(
      key:                  _vizKey,
      audio:                ctrl.audio,
      fillHeight:           true,
      artworkUrl:           ctrl.artworkUrl,
      artworkLocalFilePath: ctrl.filePath,
      artworkTargetDir:     ctrl.artworkTargetDir,
      artist:               ctrl.currentArtist,
      album:                ctrl.currentAlbum,
      isFullscreen:       _vizFs,
      onToggleFullscreen: _toggleVizFullscreen,
      // Fullscreen hides the player chrome — hand the transport to the viz so
      // it rides the same tap-to-reveal/auto-hide overlay as the selector.
      fullscreenControls: _fsTransportBar(ctrl),
      // Fullscreen hides every bit of "what is playing", so flash it back for a
      // few seconds on each track change.
      fullscreenTrackInfo: TrackInfoFlash(ctrl: ctrl),
      onClose: _closeVisualizer,
      borderRadius: 8,
      // Android paints its corner wedges rather than clipping (opaque
      // SurfaceView) — they have to match what sits behind the visualizer,
      // which is the sheet's tinted base. The two radial glows drawn over that
      // base are widest away from the corners, so the base alone matches
      // closely enough there.
      cornerBackdrop: _sheetBase(context),
    );
  }

  /// Viz close button (top-right): back to the artwork. Leaves viz-fullscreen
  /// first — otherwise the chrome would come back while _vizFs stayed armed.
  void _closeVisualizer() {
    if (_vizFs) _toggleVizFullscreen();
    if (_showVisualizer) _toggleVisualizer();
  }

  /// Prev / play-pause / next over the fullscreen visualizer: a translucent
  /// pill so it stays legible over a bright preset.
  Widget _fsTransportBar(PlayerController ctrl) {
    Widget btn(IconData icon, VoidCallback? onPressed, double size) => IconButton(
          iconSize: size,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          constraints: const BoxConstraints(),
          icon: _OutlinedGlyph(icon: icon, size: size, enabled: onPressed != null),
          onPressed: onPressed,
        );
    // AnimatedBuilder: PlayerScreen does NOT rebuild when the controller ticks -
    // its listener returns early unless the TRACK changed (it exists to follow
    // the artwork identity). Without this the transport would live on whatever
    // build happened last, play/pause glyph and progress included.
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => _fsTransportBody(ctrl, btn),
    );
  }

  Widget _fsTransportBody(
      PlayerController ctrl, Widget Function(IconData, VoidCallback?, double) btn) {
    // NO backdrop. Legibility comes from a black outline around each glyph, the
    // same trick the text over the visualizer uses (a stroked copy behind, the
    // filled one in front): it stays readable over a white preset without
    // laying a slab over the very thing one is watching.
    const lineWidth = 148.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            btn(Icons.fast_rewind, ctrl.canGoPrev ? ctrl.goPrev : null, 30),
            btn(ctrl.isPlaying ? Icons.pause : Icons.play_arrow,
                ctrl.hasFile ? ctrl.togglePlay : null, 40),
            btn(Icons.fast_forward, ctrl.canGoNext ? ctrl.goNext : null, 30),
          ],
        ),
        const SizedBox(height: 4),
        // Scrubbable: a tap or a horizontal drag seeks. Safe over the
        // visualizer because the touch area is opaque to hit-testing, so the
        // viz's own recognisers never see those pointers, and because a scrub
        // is horizontal while the player's dismiss drag only claims when the
        // vertical distance wins.
        FullscreenSeekBar(
          position: ctrl.position,
          duration: ctrl.duration,
          width: lineWidth,
          onSeek: ctrl.seek,
          onPointerDown: () => _seekBarTouched = true,
        ),
      ],
    );
  }



  // ── Tab-bar layout ────────────────────────────────────────────────────────────
  Widget _buildTabBarLayout(
    BuildContext context,
    ColorScheme cs,
    PlayerController ctrl,
    bool hasQueue,
  ) {
    final l10n      = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    // Hide the player chrome when the viz fills the sheet OR the window is in
    // native fullscreen.
    final fs = _fsActive;
    return Listener(
      // Watches the dismiss drag WITHOUT taking part in it (translucent, no
      // recognizer): see _onSheetPointerMove — the video panel has to be gone
      // before the sheet starts moving, not one frame into the move.
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onSheetPointerDown,
      onPointerMove: _onSheetPointerMove,
      onPointerUp: _onSheetPointerUp,
      onPointerCancel: _onSheetPointerUp,
      // Trackpad: a two-finger swipe is a PAN, not a pressed pointer.
      onPointerPanZoomStart:  _onSheetPanZoomStart,
      onPointerPanZoomUpdate: _onSheetPanZoomUpdate,
      onPointerPanZoomEnd:    _onSheetPointerUp,
      child: Column(
      children: [
        // (The tinted background resolves its colour directly on track change —
        // see _resolveTint — no widget-based resolver needed here.)
        if (!fs) _dragHeader(cs, context),

        // Visual panel — artwork always behind; queue overlays with blur when active.
        // In fullscreen the surrounding chrome is hidden and the padding drops to
        // zero, so this Expanded fills the whole sheet (viz stays in place).
        // Stable key: when the chrome siblings toggle, the Column's child indices
        // shift; without a key Flutter would rebuild this Expanded and reparent the
        // keyed viz subtree (→ the LayoutBuilder-in-performLayout crash).
        Expanded(
          key: const ValueKey('player-visual-panel'),
          child: Padding(
            padding: fs
                ? EdgeInsets.zero
                : const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Stack(
              key: _visualStackKey,
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _flightCtrl,
                    builder: (_, child) => Opacity(
                      // The artwork hides only once the flying copy is actually
                      // on screen — i.e. while the flight ANIMATES, or after the
                      // open flight has LANDED (value≥1, panel now opaque). It
                      // must NOT hide in the one-frame gap between _showQueue
                      // flipping true and the post-frame that starts the flight:
                      // there the flying copy draws nothing and the panel is
                      // still transparent, so hiding here left a blank frame that
                      // read as a flash right before the dezoom. Seeing the
                      // original through the panel's translucency (the reason it
                      // hides at all) only matters once the panel is opaque —
                      // exactly the landed state. Close: _showQueue is already
                      // false, so isAnimating alone keeps it hidden until the
                      // closing flight lands. Kept layout (Opacity, not unmount):
                      // the open flight measures this box. ARTWORK only — the
                      // visualizer stays untouched (wrapping the Android
                      // SurfaceView PlatformView in Opacity is not safe).
                      opacity: (!_showVisualizer &&
                              (_flightCtrl.isAnimating ||
                                  (_showQueue && _flightCtrl.value >= 1.0)))
                          ? 0.0
                          : 1.0,
                      child: child,
                    ),
                    child: _visualContent(cs, ctrl),
                  ),
                ),
                if ((_showQueue || _queueClosing) && hasQueue)
                  Positioned.fill(
                    child: IgnorePointer(
                      // On its way out it is a picture, not a target: a tap
                      // during the fade must reach the player underneath.
                      ignoring: _queueClosing,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        // The panel (scrim + rows) only fades in on the tail of the
                        // open flight — before that the row thumbnails would show
                        // the mini cover while the flying copy is still on its way.
                        // Driven by the controller VALUE (a failed measurement
                        // jumps it to 1, see _toggleQueue), so a no-flight open
                        // shows the panel immediately. The BackdropFilter's blur
                        // rides the SAME opacity: at sigma 4 fixed, the panel mounts
                        // (needed for the flight's landing measurement) one frame
                        // before the flight starts and blurred the still-visible
                        // artwork underneath for that frame — the residual "blurry
                        // artwork at animation start". Sigma 0 while the panel is
                        // transparent kills it.
                        child: AnimatedBuilder(
                          animation: _flightCtrl,
                          builder: (_, child) {
                            final v = _flightCtrl.value;
                            // With a flight, the panel only fades on its tail
                            // (the thumbnails must not show before the copy
                            // lands). No flight (viz cross-fade, failed
                            // measurement) → full-range fade.
                            final panelOp = _flightFrom.value == null
                                ? v
                                : (v < 0.8 ? 0.0 : (v - 0.8) / 0.2);
                            final sigma = 4.0 * panelOp;
                            return BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                              child: Opacity(opacity: panelOp, child: child),
                            );
                          },
                          // Le panneau AVALE les pointeurs qui l'atteignent.
                          // Sans ça, une zone sans cible (les vides de
                          // l'en-tête) laissait passer le geste au détecteur
                          // horizontal de la pochette, dessous: un balayage
                          // dans la queue changeait de piste. Aucun
                          // reconnaisseur ajouté — juste un hit-test opaque,
                          // donc le balayage-retrait des lignes et le
                          // glisser-déposer gardent l'arène pour eux.
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              // Darker than the plain surface tint: the queue text
                              // sits over artwork or a running visualizer, and 0.55
                              // of surface alone left both fighting for attention.
                              color: PlayerTint.queueReveal(context)
                                      ?.withValues(alpha: 0.94) ??
                                  Color.alphaBlend(
                                    Colors.black.withValues(alpha: 0.42),
                                    cs.surface,
                                  ).withValues(alpha: 0.88),
                              child: QueuePanel(
                                key: _queuePanelKey,
                                cs: cs,
                                queue: _overlayQueue(ctrl),
                                currentIdx: ctrl.queue.isEmpty ? 0 : ctrl.queueIdx,
                                onTap: ctrl.goToQueueIndex,
                                backgroundColor: Colors.transparent,
                                shuffleEnabled: ctrl.shuffleEnabled,
                                onToggleShuffle: ctrl.toggleShuffle,
                                loopMode: ctrl.loopMode,
                                onCycleLoop: ctrl.cycleLoopMode,
                                title: l10n.playerQueue,
                                onClose: _toggleQueue,
                                onAddToPlaylist: ctrl.queue.isEmpty ||
                                        ctrl.queueTrackIdsResolver == null
                                    ? null
                                    : () => showAddToPlaylistSheet(context,
                                        resolveTrackIds:
                                            ctrl.queueTrackIdsResolver!),
                                onClearQueue: ctrl.queue.isEmpty ||
                                        ctrl.onClearQueue == null
                                    ? null
                                    : ctrl.onClearQueue,
                                listAreaKey: _queueListKey,
                                // A single-track play leaves the controller's
                                // queue EMPTY and _overlayQueue stands in a
                                // one-row list — there is nothing to reorder or
                                // remove there, so the controls stay hidden.
                                onReorder: ctrl.queue.isEmpty || !ctrl.canEditQueue
                                    ? null
                                    : ctrl.reorderQueue,
                                onRemove: ctrl.queue.isEmpty || !ctrl.canEditQueue
                                    ? null
                                    : ctrl.removeFromQueue,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Flying artwork copy — always mounted, draws nothing while
                // idle. See the field comment for why it must stay decoupled.
                AnimatedBuilder(
                  animation: Listenable.merge(
                      [_flightAnim, _flightFrom, _flightTo]),
                  builder: (_, __) {
                    final from = _flightFrom.value, to = _flightTo.value;
                    final t = _flightAnim.value;
                    // ALWAYS a Positioned child: a lone non-positioned child
                    // (SizedBox.shrink) makes a Stack whose other children are
                    // all Positioned.fill size itself to 0x0 — which blanked
                    // the whole player, except DURING the flight when this
                    // briefly became Positioned. Hence "visible only while
                    // animating".
                    if (from == null || to == null ||
                        !_flightCtrl.isAnimating) {
                      return const Positioned(
                          left: 0, top: 0, width: 0, height: 0,
                          child: SizedBox.shrink());
                    }
                    final r = Rect.lerp(from, to, t)!;
                    final radius = BorderRadius.circular(12 + (6 - 12) * t);
                    return Positioned.fromRect(
                      rect: r,
                      child: IgnorePointer(
                        // Drop shadow OUTSIDE the clip so it hugs the box. It
                        // mirrors the player cover's shadow at t≈0 (full size)
                        // and fades out fast as the cover shrinks into the row —
                        // symmetric on close (t:1→0 grows it back, shadow fades
                        // in), so the shadow never cuts abruptly at the handoff.
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            boxShadow: _flyingShadows(t, cs, ctrl),
                          ),
                          child: ClipRRect(
                            borderRadius: radius,
                            // Paint the SAME provider the cover already resolved
                            // (exact + decoded + cached) as one persistent Image
                            // for the whole flight — no async load, no
                            // placeholder→real swap (the swap flashed animated
                            // GIFs; a path re-derived from _resolveTint could
                            // also diverge from what the screen shows and flash
                            // on first frame). Preference: exact provider →
                            // memoized cover path → ArtworkImage (themed generic,
                            // matches the display when there is no cover).
                            child: _flyingArtwork(ctrl, r),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Download banner directly ABOVE the controls: hitting "next" on a
        // remote track (or auto-advancing a queue) can sit on a download for
        // seconds, and from inside the player that looked like a hang. Placed
        // here it sits right where the user is looking — at the controls — not
        // lost at the top. In fullscreen it is overlaid instead (see build()).
        // ⚠️ CHAQUE bloc porte une CLÉ, et c'est ce qui protège la rangée de
        // transport. Ces enfants sont conditionnels et se suivent, plusieurs
        // partagent le même type (deux `Transform.translate` voisins, chacun
        // contenant une `Row` d'`IconButton`): dès qu'un bloc apparaît ou
        // disparaît, Flutter réapparie les enfants NON CLÉS par POSITION et par
        // type — un élément de la rangée de transport peut alors être mis à
        // jour avec le widget de la barre d'actions du bas. Si ça tombe pendant
        // un appui, le geste en vol appartient toujours à l'élément, mais son
        // callback est devenu celui du voisin: on appuie sur lecture et c'est
        // « suivant » qui part. Rendre les enfants de la rangée inconditionnels
        // (2026-07-21) ne suffisait donc pas — le décalage venait d'un cran
        // au-dessus. Avec des clés, l'appariement se fait par identité: un
        // enfant clé ne peut plus être mis à jour par un widget d'une autre
        // liste, et le décalage devient impossible.
        //
        // Download banner directly ABOVE the controls: hitting "next" on a
        // remote track (or auto-advancing a queue) can sit on a download for
        // seconds, and from inside the player that looked like a hang. Placed
        // here it sits right where the user is looking — at the controls — not
        // lost at the top. In fullscreen it is overlaid instead (see build()).
        if (!fs) const KeyedSubtree(
            key: ValueKey('ps-download-banner'), child: DownloadBanner()),
        if (!fs)
          KeyedSubtree(
              key: const ValueKey('ps-track-info'),
              child: _trackInfo(textTheme, cs, ctrl)),
        if (!fs)
          KeyedSubtree(
              key: const ValueKey('ps-seek-bar'),
              child: _seekBar(ctrl, textTheme)),
        if (!fs)
          Transform.translate(
            key: const ValueKey('ps-transport'),
            offset: const Offset(0, -6),
            child: _transportRow(ctrl, cs),
          ),

        // ── Bottom action bar: viz | output | queue ───────────────────
        if (!fs)
          Transform.translate(
            key: const ValueKey('ps-action-bar'),
            offset: const Offset(0, -10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                // Clés ici aussi: cette rangée est la VOISINE immédiate de la
                // rangée de transport et porte des `IconButton` de même type —
                // c'est exactement ce qui peut être apparié à sa place quand un
                // bloc conditionnel apparaît au-dessus.
                IconButton(
                  key: const ValueKey('ps-act-viz'),
                  icon: Icon(
                      _showVisualizer ? Icons.image_outlined : Icons.equalizer),
                  tooltip: _showVisualizer
                      ? l10n.playerArtwork
                      : l10n.playerVisualizer,
                  onPressed: _toggleVisualizer,
                ),
                // With per-voice data → chip/voice mutes; stereo-only
                // backends (APE, vgmstream…) → the sheet offers L/R mutes.
                IconButton(
                  key: const ValueKey('ps-act-voices'),
                  icon: const Icon(Icons.tune),
                  tooltip: l10n.playerVoices,
                  onPressed: () => VoicesSheet.show(context, ctrl.audio),
                ),
                // Audio route/output picker — centre of the bottom row.
                // iOS: AVRoutePickerView; Android: system Output Switcher;
                // macOS: in-app device sheet (see AudioRoute).
                if (AudioRoute.supported)
                  Builder(
                    builder: (btnCtx) => IconButton(
                      key: const ValueKey('ps-act-route'),
                      icon: Icon((!kIsWeb && Platform.isAndroid)
                          ? Icons.speaker_group_outlined
                          : Icons.airplay),
                      tooltip: l10n.audioOutput,
                      onPressed: () => AudioRoute.show(btnCtx, ctrl.audio),
                    ),
                  ),
                IconButton(
                  key: const ValueKey('ps-act-info'),
                  icon: const Icon(Icons.info_outline),
                  tooltip: l10n.playerTrackInfo,
                  // Also enabled when only server tags are known — the sheet
                  // renders them as clickable chips above the (possibly
                  // empty-state) native info text.
                  onPressed: ctrl.audio.trackMessage.isNotEmpty ||
                          _isSidFile(ctrl) ||
                          ctrl.backend == 'asap' ||
                          ctrl.songTags.isNotEmpty
                      ? () => _showTrackInfo(context, ctrl)
                      : null,
                ),
                IconButton(
                  key: const ValueKey('ps-act-queue'),
                  icon: Icon(
                    _showQueue ? Icons.queue_music : Icons.queue_music_outlined,
                    color: (_showQueue && hasQueue) ? cs.primary : null,
                  ),
                  tooltip:
                      _showQueue ? l10n.playerHideQueue : l10n.playerShowQueue,
                  onPressed: hasQueue ? _toggleQueue : null,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    );
  }

  // ── Track info panel (rewamp_track_message + SID STIL) ─────────────────────

  static const _kSidExts = {'sid', 'psid', 'rsid', 'mus'};

  bool _isSidFile(PlayerController ctrl) {
    final path = ctrl.filePath;
    if (path == null) return false;
    final dot = path.lastIndexOf('.');
    if (dot < 0) return false;
    return _kSidExts.contains(path.substring(dot + 1).toLowerCase());
  }

  /// Full info text for the CURRENT track (native message + SID STIL).
  /// The body is engine-provided (English field names — Title/Artist/Length —
  /// exactly as the native tag panels print them); only the empty-state line
  /// is localized.
  static Future<String> _buildInfoText(
      PlayerController ctrl, AppLocalizations l10n) async {
    var text = ctrl.audio.trackMessage;

    // SID: append the cached STIL entry for the current subsong (fetched and
    // cached per HVSC MD5 by app_shell's _applyLocalSidMeta).
    final path = ctrl.filePath;
    final dot  = path?.lastIndexOf('.') ?? -1;
    final isSid = path != null && dot >= 0 &&
        _kSidExts.contains(path.substring(dot + 1).toLowerCase());
    if (isSid) {
      try {
        final md5 = ctrl.audio.sidMd5(path);
        if (md5.isNotEmpty) {
          final cached = await LocalDb.instance.getSidInfoCache(md5);
          final sub = cached
              ?.where((s) => s.idx - 1 == ctrl.subsongIdx)
              .firstOrNull;
          if (sub != null &&
              ((sub.stilName?.isNotEmpty ?? false) ||
                  (sub.stilAuthor?.isNotEmpty ?? false) ||
                  (sub.stilTitle?.isNotEmpty ?? false) ||
                  (sub.stilArtist?.isNotEmpty ?? false) ||
                  (sub.stilComment?.isNotEmpty ?? false))) {
            text += '\nSTIL:\n';
            // NAME/AUTHOR nomment le SOUS-CHANT — ils sont déjà le titre et
            // l'artiste affichés, et on les répète ici parce que le panneau ⓘ
            // dit d'où vient ce qu'on lit.
            if (sub.stilName?.isNotEmpty ?? false) {
              text += 'Name: ${sub.stilName}\n';
            }
            if (sub.stilAuthor?.isNotEmpty ?? false) {
              text += 'Author: ${sub.stilAuthor}\n';
            }
            // TITLE/ARTIST nomment l'ŒUVRE REPRISE: une phrase, pas deux
            // étiquettes qu'on relit comme un titre et un artiste de piste —
            // c'est exactement la confusion qui faisait passer « Magnetic
            // Fields, Part 1 » de Jean-Michel Jarre pour le nom du morceau.
            final coverT = sub.stilTitle ?? '';
            final coverA = sub.stilArtist ?? '';
            if (coverT.isNotEmpty || coverA.isNotEmpty) {
              text += coverT.isNotEmpty && coverA.isNotEmpty
                  ? '${l10n.stilCoverOf(coverT, coverA)}\n'
                  : '${l10n.stilCover(coverT.isNotEmpty ? coverT : coverA)}\n';
            }
            if (sub.stilComment?.isNotEmpty ?? false) {
              text += '${sub.stilComment}\n';
            }
          }
        }
      } catch (_) {}
    }

    // UADE: append songdb metadata (authors / album / year) for the ⓘ panel.
    // Useful mostly for local files outside the server DB.
    if (ctrl.backend == 'uade' && ctrl.filePath != null) {
      try {
        final info = await UadeInfoService.instance.forPath(ctrl.filePath!);
        if (info != null) {
          final extra = <String>[];
          if (info.authors.isNotEmpty) {
            extra.add('Author: ${info.authors.join(', ')}');
          }
          if (info.album != null && info.album!.isNotEmpty) {
            extra.add('Album: ${info.album}');
          }
          if (info.year != null) extra.add('Year: ${info.year}');
          final ms = info.durationMsFor(ctrl.subsongIdx);
          if (ms != null && ms > 0) {
            extra.add('Length: ${ms ~/ 60000}:'
                '${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}');
          }
          if (extra.isNotEmpty) {
            text += '\n${extra.join('\n')}\n';
          }
        }
      } catch (_) {}
    }

    // ASAP (Atari SAP/POKEY): append ASMA's STIL entry for the ⓘ panel — no
    // subsong split, one entry per file (unlike SID's per-subsong STIL).
    if (ctrl.backend == 'asap' && ctrl.filePath != null) {
      try {
        final info = await SapInfoService.instance.forPath(ctrl.filePath!);
        if (info != null &&
            ((info.stilTitle?.isNotEmpty ?? false) ||
                (info.stilArtist?.isNotEmpty ?? false) ||
                (info.stilComment?.isNotEmpty ?? false))) {
          text += '\nSTIL:\n';
          if (info.stilTitle?.isNotEmpty ?? false) {
            text += 'Title: ${info.stilTitle}\n';
          }
          if (info.stilArtist?.isNotEmpty ?? false) {
            text += 'Artist: ${info.stilArtist}\n';
          }
          if (info.stilComment?.isNotEmpty ?? false) {
            text += '${info.stilComment}\n';
          }
        }
      } catch (_) {}
    }

    text += await _filesSection(ctrl);

    return text.trim().isEmpty ? l10n.playerNoTrackInfo : text;
  }

  /// `Files:` — le ou les fichiers réellement lus, avec leur taille.
  ///
  /// La liste vient du MOTEUR (`rewamp_loaded_files_json`): chaque loader
  /// déclare les fichiers qu'il ouvre, et lui seul le peut. Beaucoup de formats
  /// ne tiennent pas dans un fichier — un `.minipsf` a besoin de son `.psflib`,
  /// un `mdat.NOM` de son `smpl.NOM`, un `.mdx` de son `.pdx`, un `.eup` de ses
  /// banques — et le compagnon ne se déduit PAS du nom: un `.psflib` porte le
  /// nom du jeu, pas celui du morceau.
  ///
  /// Repli pour un binaire natif antérieur: le fichier joué, seul. On ne
  /// retombe pas sur une recherche de voisins par radical — elle rate le cas
  /// qui compte et peut ramasser un fichier sans rapport.
  ///
  /// Section en anglais comme le reste du corps du panneau, qui vient des
  /// moteurs (`Title:`, `Author:`, `STIL:`) — rien à traduire.
  static Future<String> _filesSection(PlayerController ctrl) async {
    final path = ctrl.filePath;
    if (path == null || path.isEmpty) return '';
    var files = ctrl.audio.loadedFiles();
    if (files.isEmpty) {
      try {
        final f = File(path);
        if (!await f.exists()) return '';
        files = [
          (name: path.split(Platform.pathSeparator).last, size: await f.length())
        ];
      } catch (_) {
        return '';
      }
    }
    final lines = [
      for (final f in files) '${f.name}  (${_humanSize(f.size)})',
    ];
    return '\nFiles:\n${lines.join('\n')}\n';
  }

  static String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _showTrackInfo(BuildContext context, PlayerController ctrl) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: PlayerTint.panel(context),
      // The modal is a separate route: it does NOT inherit the player's dark
      // tint theme, so it gets its own (black text on the deep panel otherwise).
      builder: (ctx) => PlayerTint.wrap(
        ctx,
        DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (ctx, scroll) => _TrackInfoSheetBody(
              ctrl: ctrl,
              scroll: scroll,
              onNavigateTag: widget.onNavigateTag,
              onLeavePlayer: () {
                Navigator.pop(ctx); // the info sheet only
                _dismiss();         // the player overlay, through its host
              }),
        ),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────────

  Widget _dragHeader(ColorScheme cs, BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _closePlayer,
      // No drag handlers here: the dismiss drag is driven by the Listener that
      // wraps the whole player (see _onSheetPointerMove), and this strip sits
      // inside it. Two drivers on one pointer would fight over the value.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _trackInfo(
      TextTheme textTheme, ColorScheme cs, PlayerController ctrl) {
    final l10n  = context.l10n;
    final album = ctrl.currentAlbum;
    final pos   = ctrl.queuePositionLabel;
    final artist = ctrl.currentArtist;
    final isLocal = ctrl.currentOnlineId == null;
    // Album link is clickable for a real server album — which the ALBUM ID
    // alone establishes. A standalone multi-subsong file (SID/NSF/…) carries a
    // pseudo "album" tag but no albumId, so it stays inert; a file of the
    // user's own never gets one either (it is only ever written from a
    // catalogue answer).
    //
    // It used to require a non-null onlineId on top of that, and THAT is what
    // broke a multi-file album: only the container of an album has a catalogue
    // song id (a jw_spc album is one server row with a tracklist), so every
    // .spc but the one that carried the id played "local" and the link died
    // from the second track on — with the album id sitting right there. The id
    // of the SONG says nothing about whether the ALBUM is known.
    final albumTappable = album != null && album.isNotEmpty &&
        ctrl.currentAlbumId != null && ctrl.currentAlbumId!.isNotEmpty &&
        widget.onNavigateAlbum != null;
    // Single-file multi-subsong container (not a real album): the label instead
    // links to the subsong list. app_shell provides the callback only in that case.
    final subsongLink   = widget.onNavigateSubsongs;
    final showSubsongs  = !albumTappable && subsongLink != null;
    final linkTappable  = albumTappable || showSubsongs;
    // Sans album, le NOM DU CONTENEUR plutôt qu'un libellé générique: c'est
    // l'information, et « Voir les subsongs » ne la remplace pas. Le générique
    // ne reste que si le conteneur lui-même n'a pas de nom.
    final containerName = widget.subsongContainerName;
    final albumLabel    = (album != null && album.isNotEmpty)
        ? album
        : (showSubsongs && (containerName ?? '').isNotEmpty
            ? containerName!
            : l10n.playerViewSubsongs);
    if (artist != null && artist.isNotEmpty) {
      _ensureServerArtistsChecked(isLocal, artist);
    }
    final artistNames = artist == null || artist.isEmpty
        ? const <String>[]
        : _artistNamesOf(ctrl, artist);
    // Not tappable when the credit is the FILE's own tag standing in for a
    // catalogue track the catalogue could not credit: that string names no
    // artist entity, and a link opening an empty artist screen is worse than
    // plain text. A LOCAL file keeps its own rule — its tag is validated
    // against the catalogue by name before the line becomes a link.
    final artistTappable = artist != null && artist.isNotEmpty &&
        widget.onNavigateArtist != null &&
        !ctrl.currentArtistIsFileTag &&
        (!isLocal || (_serverArtists?.isNotEmpty ?? false));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: title + album + position/backend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScrollingText(
                  text:  ctrl.displayTitle,
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if ((album != null && album.isNotEmpty) || showSubsongs) ...[
                  const SizedBox(height: 2),
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: !linkTappable
                        ? null
                        : () {
                            _dismiss();   // close the player screen — it must
                            // not stay on top of the screen being pushed
                            // underneath.
                            if (albumTappable) {
                              widget.onNavigateAlbum!(album,
                                  collection: ctrl.currentCollectionSlug,
                                  platform:   ctrl.currentPlatformName,
                                  artworkUrl: ctrl.artworkUrl,
                                  albumId:    ctrl.currentAlbumId);
                            } else {
                              subsongLink!();
                            }
                          },
                    child: ScrollingText(
                      text:  albumLabel,
                      style: textTheme.bodyMedium?.copyWith(
                          color: linkTappable ? cs.primary : cs.onSurfaceVariant,
                          decoration:
                              linkTappable ? TextDecoration.underline : null),
                    ),
                  ),
                ],
                if (artist != null && artist.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  // ONE credit is not ONE artist. A single name keeps the
                  // marquee (a long one has to scroll); several become one
                  // link each, so a two-artist tune points at two profiles
                  // instead of at a name nobody is called.
                  if (artistNames.length <= 1)
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: artistTappable
                          ? () => _openArtist(
                                artistNames.isNotEmpty ? artistNames.first : artist,
                                artistId: artistIdAt(_artistIdsOf(ctrl), 0))
                          : null,
                      child: ScrollingText(
                        text:  artist,
                        style: textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: artistTappable ? cs.primary : cs.onSurfaceVariant,
                            decoration:
                                artistTappable ? TextDecoration.underline : null),
                      ),
                    )
                  else
                    ArtistNames(
                      names: artistNames,
                      ids:   _artistIdsOf(ctrl),
                      onTap: widget.onNavigateArtist == null
                          ? null
                          : (name, {artistId}) =>
                              _openArtist(name, artistId: artistId),
                      // Same rule as the single-name line: a local file's
                      // credit only links out once the catalogue confirms that
                      // name exists.
                      isTappable: (name) => !ctrl.currentArtistIsFileTag &&
                          (!isLocal || (_serverArtists?.contains(name) ?? false)),
                      style: textTheme.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic),
                    ),
                ],
                // Source line: queue position · collection · platform. The
                // engine name moved under the progress bar (centered between
                // the times).
                //
                // "local" is what we say when we have NOTHING to say about the
                // origin — it used to be keyed on `currentOnlineId == null`,
                // which is a statement about the catalogue IDENTITY, not about
                // where the file came from: a downloaded album replayed from
                // the recents rail reads its slug off the on-disk path
                // (`online/jw_gbs/…`) yet was labelled "local" because the id
                // had been lost on the way. Show the slug whenever we have
                // one, and fall back to the word only when we do not.
                Builder(builder: (_) {
                  final slug = ctrl.currentCollectionSlug ?? '';
                  final coll = slug.isNotEmpty
                      ? slug
                      : (isLocal ? l10n.playerSourceLocal : '');
                  final plat = ctrl.currentPlatformName ?? '';
                  final parts = <String>[
                    if (pos != null) pos,
                    if (coll.isNotEmpty) coll,
                    if (plat.isNotEmpty) plat,
                  ];
                  if (parts.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      parts.join(' · '),
                      style: textTheme.bodySmall?.copyWith(color: cs.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
            ),
          ),
          // Right: more options on the first line, favorite + library beneath
          // (one row saved vs stacking all three).
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Competition podium — opens the compo (its playlist when
                  // there is one, its ranking otherwise).
                  if (ctrl.songPodium != null)
                    IconButton(
                      icon: Icon(Icons.emoji_events,
                          color: podiumColor(context, ctrl.songPodium!.rank)),
                      tooltip: podiumLabel(context, ctrl.songPodium!),
                      onPressed: () => openPodium(context, ctrl.songPodium!),
                    ),
                  // Demozoo production video(s) — only when known. Plays
                  // INLINE in the viz frame; fullscreen is a button there.
                  if (ctrl.videos.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.ondemand_video,
                          color: _showVideo ? cs.primary : null),
                      tooltip: l10n.videoWatchDemo,
                      onPressed: () => _toggleVideo(ctrl),
                    ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    tooltip: l10n.playerMoreOptions,
                    onPressed: ctrl.hasFile
                        ? () => _showPlayerOptions(context, ctrl)
                        : null,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      ctrl.isFavorite ? Icons.star : Icons.star_border,
                      color: ctrl.isFavorite ? kFavoriteColor : null,
                    ),
                    tooltip: ctrl.isFavorite
                        ? l10n.playerRemoveFavorite
                        : l10n.playerAddFavorite,
                    onPressed: ctrl.hasFile ? ctrl.toggleFavorite : null,
                  ),
                  if (ctrl.hasFile)
                    _LibraryToggleButton(
                      // Subsong-aware key so the button rebuilds (and re-checks
                      // its in-library state) when the subsong changes.
                      key: ValueKey(playerLibraryRefId(ctrl)),
                      ctrl: ctrl,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seekBar(PlayerController ctrl, TextTheme textTheme) {
    // Unknown duration (no length in the catalogue AND none derivable from the
    // file — e.g. a UADE songdb entry whose subsong has length_ms 0). Only the
    // SEEKING is impossible then: the elapsed time and the engine name do not
    // depend on the total at all, and this used to drop the whole row, which
    // left the player looking broken on a perfectly playing track.
    if (ctrl.duration <= 0) {
      return _seekBarChrome(
        ctrl,
        textTheme,
        track: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(height: 3),
        ),
        displayPos: ctrl.position,
        totalLabel: '--:--',
      );
    }
    // Show the drag target position while the user is scrubbing; switch back
    // to the live position immediately on release (after the seek fires).
    final displayPos =
        (_seekDragValue ?? ctrl.position).clamp(0.0, ctrl.duration);
    return _seekBarChrome(
      ctrl,
      textTheme,
      displayPos: displayPos,
      totalLabel: _fmt(ctrl.duration),
      // Même signal que la FullscreenSeekBar, même consommateur: un geste NÉ
      // sur le Slider appartient au Slider, verticale comprise. Le glissement
      // de fermeture est un Listener ancêtre hors arène — le Slider gagne bien
      // l'arène pour le drag HORIZONTAL, mais un scrub qui dévie vers le bas
      // franchissait le seuil du Listener et repliait le lecteur en plein seek.
      track: Listener(
        onPointerDown: (_) => _seekBarTouched = true,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: displayPos),
            duration: _seekDragValue != null
                ? Duration.zero
                : const Duration(milliseconds: 230),
            curve: Curves.linear,
            builder: (_, v, __) => Slider(
              value: v.clamp(0.0, ctrl.duration),
              min: 0,
              max: ctrl.duration,
              onChanged: (val) => setState(() => _seekDragValue = val),
              onChangeEnd: (val) {
                setState(() => _seekDragValue = null);
                ctrl.seek(val);
              },
            ),
          ),
        ),
        ),
      ),
    );
  }

  /// Shared layout of the seek row: [track] on top, then elapsed / engine /
  /// total. Both the seekable and the unknown-duration cases go through it so
  /// the player keeps exactly the same shape either way.
  Widget _seekBarChrome(
    PlayerController ctrl,
    TextTheme textTheme, {
    required Widget track,
    required double displayPos,
    required String totalLabel,
  }) {
    return Column(
      children: [
        track,
        Transform.translate(
          offset: const Offset(0, -12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(_fmt(displayPos), style: textTheme.bodySmall),
                // Engine name, centered between the two times.
                Expanded(
                  child: Center(
                    child: Text(
                      ctrl.backend,
                      // Same style as the two times it sits between — it is
                      // part of that line, not an accent.
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Text(totalLabel, style: textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The list the queue overlay shows. A single-track play leaves the
  /// controller's queue empty, so stand in a one-entry list for the loaded
  /// track — the overlay stays reachable in every playing state.
  List<QueueEntry> _overlayQueue(PlayerController ctrl) {
    if (ctrl.queue.isNotEmpty) return ctrl.queue;
    // Carry the artwork params so the single row resolves the SAME cover the
    // player shows — a bare title/artist entry fell through to the themed
    // generic (visible when reloading a track from "recently played").
    return [QueueEntry(
      title:         ctrl.displayTitle,
      artist:        ctrl.currentArtist,
      artworkUrl:    ctrl.artworkUrl,
      album:         ctrl.currentAlbum,
      localFilePath: ctrl.filePath,
      platformName:  ctrl.currentPlatformName,
      formatHint:    ctrl.currentFormatExt,
    )];
  }

  /// The queue-reveal flying cover. Prefers the exact provider the player's
  /// cover resolved (already decoded, in cache → paints instantly, no flash),
  /// then a memoized on-disk path, then a fresh ArtworkImage (async — themed
  /// generic first). gaplessPlayback keeps the last GIF frame across changes.
  Widget _flyingArtwork(PlayerController ctrl, Rect r) {
    final provider = _resolvedArtProvider ??
        (_resolvedArtPath != null ? FileImage(File(_resolvedArtPath!)) : null);
    if (provider != null) {
      return Image(
        image: provider,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        width: r.width,
        height: r.height,
        errorBuilder: (_, __, ___) => _flyingArtworkFallback(ctrl, r),
      );
    }
    return _flyingArtworkFallback(ctrl, r);
  }

  /// Flying-cover drop shadow, matching the player cover's (black, 3 casts) but
  /// scaled by a fast fade [s]: full at the cover's resting size (t≈0), gone by
  /// t≈0.25 as it shrinks into the queue row. Nil when paused (the resting cover
  /// is flat then, lift=0). Keyed on t (position), so open and close fade the
  /// same way.
  List<BoxShadow> _flyingShadows(double t, ColorScheme cs, PlayerController ctrl) {
    final s = (1 - t / 0.25).clamp(0.0, 1.0) * (ctrl.isPlaying ? 1.0 : 0.0);
    if (s == 0) return const [];
    final dark = cs.brightness == Brightness.dark;
    return [
      BoxShadow(
          color: Colors.black.withValues(alpha: s * (dark ? 0.4 : 0.3)),
          blurRadius: 16, offset: const Offset(0, 16)),
      BoxShadow(
          color: Colors.black.withValues(alpha: s * (dark ? 0.2 : 0.15)),
          blurRadius: 12, offset: const Offset(-12, 0)),
      BoxShadow(
          color: Colors.black.withValues(alpha: s * (dark ? 0.2 : 0.15)),
          blurRadius: 12, offset: const Offset(12, 0)),
    ];
  }

  Widget _flyingArtworkFallback(PlayerController ctrl, Rect r) => ArtworkImage(
        url:           ctrl.artworkUrl,
        artist:        ctrl.currentArtist,
        album:         ctrl.currentAlbum,
        localFilePath: ctrl.filePath,
        targetDir:     ctrl.artworkTargetDir,
        platformName:  ctrl.currentPlatformName,
        formatHint:    ctrl.currentFormatExt,
        size:          r.width,
      );

  Widget _transportRow(PlayerController ctrl, ColorScheme cs) {
    // Shuffle and loop FRAME the prev/play/next group, as they do in the
    // desktop mini-player, and deliberately smaller: 18 against 40 for the
    // skips and 52 for play/pause, close to the mini-player's own 15/26/40.
    // They are chrome that says what the queue will do next, not transport, so
    // the play button stays the eye's first stop. Before this they were
    // reachable only through the queue overlay's header, which is a place one
    // has to know about.
    // Buttons are ALWAYS present (onPressed nulled when unavailable), never
    // conditionally inserted. A conditional `if (canGoPrev)` child shifts the
    // whole Row when canGoPrev/canGoNext flips; if that flip coincides with a
    // tap, Flutter re-associates the unkeyed IconButtons by position and the
    // play/pause tap can fire the neighbour's callback (→ track skips on a
    // play/pause press, once, right as the queue-nav state settles).
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      // Les clés rendent la règle STRUCTURELLE au lieu de conventionnelle: elle
      // ne tenait que tant que personne ne réintroduisait un enfant
      // conditionnel dans cette rangée. Avec une clé par bouton, l'appariement
      // se fait par identité et un enfant inséré ou retiré ne peut plus
      // déplacer l'appui en vol vers le voisin.
      children: [
        ShuffleButton(
          key: const ValueKey('ps-shuffle'),
          enabled:  ctrl.shuffleEnabled,
          onToggle: ctrl.toggleShuffle,
          iconSize: 18,
        ),
        IconButton(
          key: const ValueKey('ps-prev'),
          iconSize: 40,
          icon: const Icon(Icons.fast_rewind),
          onPressed: ctrl.canGoPrev ? ctrl.goPrev : null,
        ),
        const SizedBox(width: 4),
        IconButton(
          key: const ValueKey('ps-play'),
          iconSize: 52,
          icon: Icon(ctrl.isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: ctrl.hasFile ? ctrl.togglePlay : null,
        ),
        const SizedBox(width: 4),
        IconButton(
          key: const ValueKey('ps-next'),
          iconSize: 40,
          icon: const Icon(Icons.fast_forward),
          onPressed: ctrl.canGoNext ? ctrl.goNext : null,
        ),
        LoopButton(
          key: const ValueKey('ps-loop'),
          mode:     ctrl.loopMode,
          onCycle:  ctrl.cycleLoopMode,
          iconSize: 18,
        ),
      ],
    );
  }

  void _toggleVisualizer() {
    final next = !_showVisualizer;
    setState(() => _showVisualizer = next);
    UserSettings.instance.showVisualizer = next;
  }

  void _showPlayerOptions(BuildContext context, PlayerController ctrl) {
    final refId = playerLibraryRefId(ctrl);
    if (refId == null) return;
    showModalBottomSheet<void>(
      context: context,
      // Same colour family as the artwork-tinted player behind it.
      backgroundColor: PlayerTint.panel(context),
      useRootNavigator: false,
      isScrollControlled: true,
      // Separate route → wrap in the tint's dark theme (see _showTrackInfo).
      builder: (ctx) => PlayerTint.wrap(ctx, _PlayerOptionsSheet(
        ctrl:             ctrl,
        refId:            refId,
        onNavigateAlbum:  widget.onNavigateAlbum != null
            ? (name, {collection, platform, artworkUrl, albumId}) {
                Navigator.pop(ctx);
                _dismiss(); // close the player itself (route OR overlay)
                widget.onNavigateAlbum!(name,
                    collection: collection,
                    platform:   platform,
                    artworkUrl: artworkUrl,
                    albumId:    albumId);
              }
            : null,
        onNavigateArtist: widget.onNavigateArtist != null
            ? (name, {collection, artistId}) {
                Navigator.pop(ctx);
                _dismiss(); // close the player itself (route OR overlay)
                widget.onNavigateArtist!(name,
                    collection: collection, artistId: artistId);
              }
            : null,
        onNavigateSubsongs: widget.onNavigateSubsongs != null
            ? () {
                Navigator.pop(ctx);
                _dismiss(); // close the player itself (route OR overlay)
                widget.onNavigateSubsongs!();
              }
            : null,
        onRedownload: widget.onRedownload != null
            ? () {
                Navigator.pop(ctx); // close the options sheet only; the player
                                    // stays open and reloads in place.
                widget.onRedownload!();
              }
            : null,
      )),
    );
  }

  // Visual content without embedded toggle button.
  // Tapping the artwork swaps it for the visualizer (the bottom-left button
  // does the same, and is the way back).
  /// Swipe left = next track, swipe right = previous — over the artwork AND the
  /// visualizer, whichever is showing.
  ///
  /// Horizontal only: the sheet itself is dragged VERTICALLY (resize/dismiss),
  /// and Flutter's arena settles the two by dominant axis, so they do not fight.
  /// The visualizer's own tap / double-tap keep working: a drag only wins once
  /// the finger actually moves.
  // Accumulated horizontal travel of the current drag over the viz. The viz
  // buttons (play/pause etc.) sit INSIDE this horizontal-drag detector, so a tap
  // that wobbles can let the drag win the arena — and a wobble can spike the
  // release VELOCITY without any real TRAVEL. Gating on distance too means only a
  // genuine swipe skips; a wobbled button-tap does not (it just does nothing,
  // and the user's next tap lands). Was: velocity-only → random skip on pause.
  double _visualSwipeDx = 0;

  void _onVisualSwipe(DragEndDetails d, PlayerController ctrl) {
    final v    = d.primaryVelocity ?? 0;
    final dist = _visualSwipeDx;
    _visualSwipeDx = 0;
    // Un glissement de FERMETURE est en cours: il a pris le geste, ce
    // balayage-ci n'est que sa composante horizontale.
    if (_playerDismissDragActive) return;
    // A real flick: it must have TRAVELLED, not just ended fast. A tap-wobble
    // covers a few px even if its release velocity spikes.
    if (dist.abs() < 48) return;
    if (v.abs() < 250) return;
    final goNext = v < 0;   // left = forward, the usual direction of travel
    if (goNext ? !ctrl.canGoNext : !ctrl.canGoPrev) return;
    HapticFeedback.lightImpact();
    (goNext ? ctrl.goNext : ctrl.goPrev)();
  }

  void _toggleVideo(PlayerController ctrl) {
    if (_showVideo) {
      setState(() { _showVideo = false; _videoFs = false; });
      _syncOrientation();
      return;
    }
    if (!videoWebViewSupported) {
      // No in-app WebView on this desktop → straight to the browser.
      VideoScreen.open(context, ctrl, ctrl.videos,
          songId: ctrl.currentOnlineId);
      return;
    }
    if (ctrl.isPlaying) ctrl.togglePlay(); // the demo carries its own audio
    setState(() { _showVideo = true; _videoIndex = 0; });
    _syncOrientation();
  }

  /// Inline video panel — same frame as the visualizer, custom chrome
  /// (the embeds' native controls are disabled; see VideoEmbedController).
  Widget _videoPanel(PlayerController ctrl) {
    return GestureDetector(
      // Swallow VERTICAL drags over the embed. The player is a modal bottom
      // sheet whose drag-to-dismiss reads any downward drag on its content —
      // but the WebView is a platform view and can keep the pointer-up, so the
      // sheet stopped half-closed and the whole app stayed unresponsive
      // (the gesture never ended). A child recognizer wins over the sheet's,
      // and these handlers do nothing, so no drag ever starts here. Taps and
      // the embed's own gestures still reach the WebView (deferToChild).
      behavior: HitTestBehavior.deferToChild,
      onVerticalDragStart:  (_) {},
      onVerticalDragUpdate: (_) {},
      onVerticalDragEnd:    (_) {},
      child: ClipRRect(
      // Square corners while expanded — it fills the whole sheet.
      borderRadius: BorderRadius.circular(_videoFs ? 0 : 8),
      child: VideoPlayerPanel(
        key: ValueKey('inline_video_${ctrl.currentOnlineId}'),
        videos: ctrl.videos,
        songId: ctrl.currentOnlineId,
        initialIndex: _videoIndex,
        compact: !_videoFs,
        isFullscreen: _videoFs,
        onClose: () {
          setState(() { _showVideo = false; _videoFs = false; });
          _syncOrientation();
        },
        // In-place expand (same trick as the viz fullscreen): the player
        // chrome hides and this frame fills the sheet — the WebView is NOT
        // re-created (a second embed instance kept playing behind the first).
        onFullscreen: (i) {
          _videoIndex = i;
          setState(() => _videoFs = !_videoFs);
          _syncOrientation();
        },
      ),
    ),
    );
  }

  Widget _visualContent(ColorScheme cs, PlayerController ctrl) {
    // Inline video mode. Auto-exit when the track changed (videos reset) or
    // the music was resumed (both audios at once = cacophony) — schedule the
    // state flip after this frame.
    if (_showVideo && (ctrl.videos.isEmpty || ctrl.isPlaying)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showVideo) {
          setState(() { _showVideo = false; _videoFs = false; });
          _syncOrientation();
        }
      });
    } else if (_showVideo) {
      return _videoPanel(ctrl);
    }
    // Queue overlay FULLY open → the visualizer is UNMOUNTED (updates stop):
    // rendering GL behind an opaque panel is pure cost on modest devices.
    // During the open/close cross-fade it stays mounted — the panel fades
    // OVER the live viz (Opacity on the Android SurfaceView is not safe) and
    // covers it before the unmount; on close it is remounted from the first
    // frame, under the panel fading out. Remount is cheap (shared GL context
    // survives, register ≈ 0-4 ms).
    final vizAllowed =
        _showVisualizer && !(_showQueue && _flightCtrl.isCompleted);
    final Widget child = vizAllowed
        ? _vizWidget(ctrl)
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleVisualizer,
            child: _ArtworkPanel(
              imageKey: _artKey,
              cs: cs,
              artworkUrl:    ctrl.artworkUrl,
              artist:        ctrl.currentArtist,
              album:         ctrl.currentAlbum,
              localFilePath: ctrl.filePath,
              targetDir:     ctrl.artworkTargetDir,
              platformName:  ctrl.currentPlatformName,
              formatHint:    ctrl.currentFormatExt,
              isPlaying:     ctrl.isPlaying,
              // Capture the exact provider the cover paints, so the queue flight
              // reuses it (already decoded) instead of re-deriving a path.
              onImageResolved: (provider, _) => _resolvedArtProvider = provider,
            ),
          );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart:  (_) => _visualSwipeDx = 0,
      // Le glissement de fermeture a pris le geste: on n'accumule même pas la
      // distance, sinon un changement de direction en cours de route la
      // ramènerait au-dessus du seuil.
      onHorizontalDragUpdate: (d) => _visualSwipeDx =
          _playerDismissDragActive ? 0 : _visualSwipeDx + d.delta.dx,
      onHorizontalDragEnd:    (d) => _onVisualSwipe(d, ctrl),
      child: child,
    );
  }
}

// ── Queue panel ───────────────────────────────────────────────────────────────

class QueuePanel extends StatefulWidget {
  final ColorScheme cs;
  final List<QueueEntry> queue;
  final int currentIdx;
  final void Function(int)? onTap;
  // null = use default opaque surface; Colors.transparent for overlay use.
  final Color? backgroundColor;
  final bool shuffleEnabled;
  final VoidCallback? onToggleShuffle;
  final int loopMode;            // 0=off, 1=queue, 2=track
  final VoidCallback? onCycleLoop;
  /// Header title (null → no title, e.g. when the caller draws its own).
  final String? title;
  /// Close (X) button in the header (null → not shown).
  final VoidCallback? onClose;

  /// Saves the whole queue into a playlist (opens the playlist picker).
  /// null hides the button.
  final VoidCallback? onAddToPlaylist;

  /// Empties the queue AND stops what is playing (a « clear » that leaves the
  /// current track running has not cleared the queue — it has cleared it of
  /// everything EXCEPT what one can hear). The panel asks for confirmation
  /// before calling it: the queue can be a long, hand-built list and there is
  /// no undo. null hides the button.
  final VoidCallback? onClearQueue;

  /// Key on the LIST AREA (not on a row): the opening animation derives the
  /// current row's cover rect from it geometrically. A GlobalKey INSIDE the
  /// ListView is not usable here — rows are recycled, the key can appear twice
  /// for one frame, and Flutter then unmounts one of the two subtrees, which
  /// blanked the whole panel.
  final GlobalKey? listAreaKey;

  /// Blanks the current row's cover while the flying copy is in the air, so the
  /// artwork is never visible twice.
  final bool hideCurrentThumb;

  /// Queue editing. Both null (a read-only listing) hides the handles, the
  /// swipe action and the edit button — the panel is used in places that only
  /// mirror a queue they do not own.
  final void Function(int oldIndex, int newIndex)? onReorder;
  final void Function(Set<int> indices)? onRemove;

  /// Row height and the cover geometry inside a row — shared with the animation
  /// so it can compute the landing rect without measuring a row.
  static const double kRowHeight   = 60;
  static const double kCoverSize   = 40;
  static const double kCoverLeft   = 16 + 18 + 4;  // ListTile padding + index + gap

  const QueuePanel({
    super.key,
    required this.cs,
    required this.queue,
    required this.currentIdx,
    this.onTap,
    this.backgroundColor,
    this.shuffleEnabled = false,
    this.onToggleShuffle,
    this.loopMode = 0,
    this.onCycleLoop,
    this.title,
    this.onClose,
    this.onAddToPlaylist,
    this.onClearQueue,
    this.listAreaKey,
    this.hideCurrentThumb = false,
    this.onReorder,
    this.onRemove,
  });

  @override
  State<QueuePanel> createState() => QueuePanelState();
}

class QueuePanelState extends State<QueuePanel> {
  // Fixed row height lets us compute the scroll offset that centers the
  // current track directly, without GlobalKey/ensureVisible plumbing.
  static const double _kItemExtent = QueuePanel.kRowHeight;

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Center on open (post-frame: viewport isn't measured yet this frame).
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _centerCurrent(animate: false));
  }

  @override
  void didUpdateWidget(covariant QueuePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIdx != widget.currentIdx) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _centerCurrent(animate: true));
    }
  }

  /// Brings the playing track to the TOP of the list rather than its middle:
  /// on opening, the eye should land on what is playing and read FORWARD into
  /// what comes next — and it is also what makes the artwork fly to a
  /// predictable place (the first visible row) when the panel opens.
  /// The current row's cover rect, expressed in [ancestor]'s space, at its
  /// LIVE scroll position. A row scrolled out of view returns a ZERO-SIZE rect
  /// at the nearest list edge (top or bottom), centered on the cover column —
  /// the caller's flight then grows the cover out of that edge.
  /// [predictCentered] computes the row's position as it will be AFTER
  /// _centerCurrent's scroll-to-top (same clamp): the open flight measures
  /// before that jump has happened, and a short queue clamps the scroll so the
  /// current row does NOT land at the top — assuming it did aimed at row 0.
  Rect? coverRectIn(RenderBox ancestor, {bool predictCentered = false}) {
    final listBox =
        widget.listAreaKey?.currentContext?.findRenderObject() as RenderBox?;
    if (listBox == null || !listBox.hasSize || !_scroll.hasClients) return null;
    const vGap = (QueuePanel.kRowHeight - QueuePanel.kCoverSize) / 2;
    final offset = predictCentered
        ? (widget.currentIdx * _kItemExtent)
            .clamp(0.0, _scroll.position.maxScrollExtent)
        : _scroll.offset;
    final rowTop = 2 + widget.currentIdx * _kItemExtent - offset;
    final viewport = listBox.size.height;
    Rect xform(Rect r) =>
        MatrixUtils.transformRect(listBox.getTransformTo(ancestor), r);
    const cx = QueuePanel.kCoverLeft + QueuePanel.kCoverSize / 2;
    if (rowTop + _kItemExtent <= 0) {
      return xform(
          Rect.fromCenter(center: const Offset(cx, 0), width: 0, height: 0));
    }
    if (rowTop >= viewport) {
      return xform(Rect.fromCenter(
          center: Offset(cx, viewport), width: 0, height: 0));
    }
    return xform(Rect.fromLTWH(QueuePanel.kCoverLeft, rowTop + vGap,
        QueuePanel.kCoverSize, QueuePanel.kCoverSize));
  }

  /// Multi-select mode: the rows grow a checkbox, the tap selects instead of
  /// playing, and the header offers to remove the lot. Kept local to the panel
  /// — leaving edit mode is not a queue mutation, nothing outside needs it.
  bool _editing = false;
  final _selected = <int>{};

  void _setEditing(bool on) => setState(() {
        _editing = on;
        _selected.clear();
      });

  void _removeSelected() {
    if (_selected.isEmpty) return;
    // Copy: the callback rebuilds this panel from a shorter queue, and the
    // indices in the set stop meaning anything the moment it does.
    final go = Set<int>.of(_selected);
    _setEditing(false);
    widget.onRemove!(go);
  }

  void _centerCurrent({required bool animate}) {
    if (!_scroll.hasClients) return;
    final i = widget.currentIdx;
    if (i < 0 || i >= widget.queue.length) return;
    final target = (i * _kItemExtent)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Les actions du bandeau, sans le titre ni la fermeture — la même liste
  /// qu'on affiche sur une ligne ou sur deux.
  ///
  /// ICON-ONLY, deliberately, same lesson as the radio/surprise pair: a text
  /// button is the widest thing on this row, and this panel is 259 px wide
  /// inside the player on a phone — "Modifier" next to the other icons
  /// overflowed it by 42 px. The words live in the tooltips.
  List<Widget> _headerActions(BuildContext context) {
    final l10n = context.l10n;
    // Edit mode swaps the queue's own controls for its actions: shuffling or
    // looping mid-selection makes no sense, and the row indices being selected
    // would move under the user.
    if (_editing) {
      return [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.delete_outline),
          tooltip: l10n.queueRemoveSelected,
          onPressed: _selected.isEmpty ? null : _removeSelected,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.done),
          tooltip: l10n.queueEditDone,
          onPressed: () => _setEditing(false),
        ),
      ];
    }
    return [
      if (widget.onRemove != null && widget.queue.isNotEmpty)
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.checklist),
          tooltip: l10n.queueEdit,
          onPressed: () => _setEditing(true),
        ),
      if (widget.onAddToPlaylist != null)
        IconButton(
          icon: const Icon(Icons.playlist_add),
          tooltip: l10n.queueAddToPlaylist,
          onPressed: widget.onAddToPlaylist,
        ),
      if (widget.onClearQueue != null && widget.queue.isNotEmpty)
        IconButton(
          // playlist_remove, pas delete_outline: celui-là est déjà « retirer
          // la sélection » deux icônes plus loin en mode édition, et deux
          // gestes de portée très différente ne partagent pas un glyphe.
          icon: const Icon(Icons.playlist_remove),
          tooltip: l10n.queueClear,
          onPressed: _confirmClearQueue,
        ),
      if (widget.onToggleShuffle != null)
        ShuffleButton(
          enabled: widget.shuffleEnabled,
          onToggle: widget.onToggleShuffle,
        ),
      if (widget.onCycleLoop != null)
        LoopButton(
          mode: widget.loopMode,
          onCycle: widget.onCycleLoop,
        ),
    ];
  }

  /// Vider la file est irréversible ET arrête la lecture: on demande, et le
  /// texte dit les DEUX conséquences — un utilisateur qui n'attend que le
  /// vidage ne doit pas découvrir l'arrêt après coup.
  Future<void> _confirmClearQueue() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.queueClearConfirmTitle),
        content: Text(l10n.queueClearConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.queueClearConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // Sortir du mode édition: sa sélection porte sur des index qui n'existent
    // plus.
    if (_editing) _setEditing(false);
    widget.onClearQueue?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final textTheme = Theme.of(context).textTheme;
    final bgColor = widget.backgroundColor ?? cs.surfaceContainerHigh.withAlpha(230);
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          // Pinned header — title + controls; stays visible while list scrolls.
          //
          // UNE ou DEUX lignes selon la LARGEUR DISPONIBLE, pas selon
          // l'appelant: ce panneau fait 280 px dans la barre latérale et 259
          // dans le lecteur d'un téléphone, et les actions sont
          // conditionnelles — le même appelant tient sur une ligne ou non
          // selon l'état de la file. Sur deux lignes, le titre garde sa ligne
          // avec la fermeture (ce qu'on lit d'abord) et les actions passent
          // dessous, alignées à droite sous cette fermeture.
          if (widget.title != null ||
              widget.onToggleShuffle != null ||
              widget.onCycleLoop != null ||
              widget.onRemove != null ||
              widget.onClearQueue != null ||
              widget.onClose != null)
            LayoutBuilder(
              builder: (context, c) {
                final actions = _headerActions(context);
                final close = widget.onClose == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: context.l10n.playerClose,
                        onPressed: widget.onClose,
                      );
                // Largeur d'un bouton d'icône (compact ou non) + le minimum
                // sous lequel un titre ne dit plus rien. Une estimation suffit:
                // se tromper d'un cheveu ne coûte qu'une ligne de plus.
                const kBtn = 44.0, kMinTitle = 96.0;
                final needed = (actions.length + (close != null ? 1 : 0)) * kBtn +
                    (widget.title != null ? kMinTitle : 0) + 20;
                final stacked = widget.title != null && needed > c.maxWidth;
                final titleWidget = widget.title == null
                    ? null
                    // Single line: with no maxLines the title WRAPS inside
                    // the Row instead of ellipsing, which is what turned a
                    // too-narrow header into a 312 px tall one.
                    : Text(widget.title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold));
                if (stacked) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          Expanded(child: titleWidget!),
                          if (close != null) close,
                        ]),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: actions,
                        ),
                      ],
                    ),
                  );
                }
                return Padding(
                  padding:
                      EdgeInsets.fromLTRB(widget.title != null ? 16 : 4, 4, 4, 0),
                  child: Row(
                    children: [
                      if (titleWidget != null)
                        Expanded(child: titleWidget)
                      else
                        const Spacer(),
                      ...actions,
                      if (close != null) close,
                    ],
                  ),
                );
              },
            ),
          if (widget.title != null ||
              widget.onToggleShuffle != null ||
              widget.onCycleLoop != null ||
              widget.onClose != null)
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
          Expanded(
            key: widget.listAreaKey,
            child: widget.onReorder == null
                ? ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    itemCount: widget.queue.length,
                    itemExtent: _kItemExtent,
                    itemBuilder: _row,
                  )
                // Explicit handles only: the default ones make the WHOLE row a
                // drag target on desktop, which would swallow the tap that
                // plays a track and the swipe that removes it.
                : ReorderableListView.builder(
                    scrollController: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    itemCount: widget.queue.length,
                    itemExtent: _kItemExtent,
                    buildDefaultDragHandles: false,
                    // onReorderItem, not onReorder: the newIndex it hands over
                    // is already adjusted for the item having left oldIndex
                    // (the old callback made every caller do that by hand).
                    onReorderItem: (o, n) {
                      // A selection is a set of INDICES; moving a row makes
                      // every one of them mean a different track.
                      if (_selected.isNotEmpty) setState(_selected.clear);
                      widget.onReorder!(o, n);
                    },
                    itemBuilder: _row,
                  ),
          ),
        ],
      ),
    );
  }

  /// One queue row. Wrapped in a Dismissible (swipe left to remove) outside of
  /// edit mode; in edit mode the row selects instead, so a swipe would fight
  /// the checkbox for the same gesture.
  Widget _row(BuildContext ctx, int i) {
    final cs = widget.cs;
    final textTheme = Theme.of(ctx).textTheme;
    final e = widget.queue[i];
    final isCurrent = i == widget.currentIdx;
    final selected = _selected.contains(i);

    final tile = ListTile(
      dense: true,
      // Position marker + cover. The cover is what the player's big
      // artwork flies into when the panel opens, so the CURRENT
      // row's one carries the target key and can be hidden for the
      // duration of that flight.
      leading: SizedBox(
        width: _editing ? 68 : 62,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              // The checkbox takes over the index/play-marker slot: it answers
              // the same question (which row is this), and widening the row
              // instead would move the cover the opening animation flies into.
              width: _editing ? 24 : 18,
              child: _editing
                  ? Checkbox(
                      value: selected,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) => setState(() =>
                          v == true ? _selected.add(i) : _selected.remove(i)),
                    )
                  : isCurrent
                      ? Icon(Icons.play_arrow, color: cs.primary, size: 18)
                      : Text(
                          '${i + 1}',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
            ),
            const SizedBox(width: 4),
            Opacity(
              opacity:
                  (isCurrent && widget.hideCurrentThumb) ? 0.0 : 1.0,
              child: SizedBox(
                width: QueuePanel.kCoverSize,
                height: QueuePanel.kCoverSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ArtworkImage(
                    url:           e.artworkUrl,
                    artist:        e.artist,
                    album:         e.album,
                    localFilePath: e.localFilePath,
                    platformName:  e.platformName,
                    formatHint:    e.formatHint,
                    size:          QueuePanel.kCoverSize,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      title: ScrollingText(
        text: e.title,
        style: textTheme.bodyMedium?.copyWith(
          fontWeight: isCurrent ? FontWeight.bold : null,
          color: isCurrent ? cs.primary : null,
        ),
      ),
      subtitle: (e.subtitle ?? e.artist) != null
          ? ScrollingText(
              text: (e.subtitle ?? e.artist)!,
              style: textTheme.bodySmall)
          : null,
      onTap: _editing
          ? () => setState(() =>
              selected ? _selected.remove(i) : _selected.add(i))
          : (widget.onTap != null ? () => widget.onTap!(i) : null),
      trailing: widget.onReorder == null
          ? null
          : ReorderableDragStartListener(
              index: i,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.drag_handle,
                    size: 20,
                    color: cs.onSurfaceVariant,
                    semanticLabel: ctx.l10n.queueReorder),
              ),
            ),
      selected: selected,
      selectedTileColor: cs.primary.withValues(alpha: 0.10),
    );

    // Key the ITEM, never the position — see QueueEntry.id. Falls back to the
    // index only for the synthesized stand-in rows, which are never editable.
    final key = ValueKey(e.id ?? 'idx-$i');
    if (widget.onRemove == null || _editing) {
      return KeyedSubtree(key: key, child: tile);
    }
    return Dismissible(
      key: key,
      direction: DismissDirection.endToStart,
      // Deliberately past halfway: a queue row is one flick away from gone and
      // there is no undo, so the gesture has to be meant.
      dismissThresholds: const {DismissDirection.endToStart: 0.5},
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: cs.errorContainer,
        child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
      ),
      onDismissed: (_) => widget.onRemove!({i}),
      child: tile,
    );
  }
}

// ── Artwork panel ─────────────────────────────────────────────────────────────
//
// Shows a square artwork image centred in the available space.
// Currently uses a placeholder; will display Image.network(artworkUrl) once
// the server exposes artwork_url on songs / ArtistAlbum.


/// A transport glyph over the fullscreen visualizer: a black stroke behind, the
/// white fill in front.
///
/// The same construction the text over the visualizer uses, and for the same
/// reason: a preset can be white, and a translucent slab behind the controls
/// would cover the very thing one is watching. An icon font is text, so the
/// glyph is drawn as text twice - Icon itself takes no foreground paint.
class _OutlinedGlyph extends StatelessWidget {
  const _OutlinedGlyph({
    required this.icon,
    required this.size,
    this.enabled = true,
  });

  final IconData icon;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final glyph = String.fromCharCode(icon.codePoint);
    final base = TextStyle(
      fontSize: size,
      fontFamily: icon.fontFamily,
      package: icon.fontPackage,
      height: 1.0,
    );
    return Stack(
      children: [
        Text(
          glyph,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              // Same ratio as the outlined text (size / 5 there, for thin
              // letterforms); an icon's strokes are already fat, so a thinner
              // outline keeps the shape readable instead of filling it in.
              ..strokeWidth = size / 10
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.black.withValues(alpha: enabled ? 0.85 : 0.45),
          ),
        ),
        Text(
          glyph,
          style: base.copyWith(
            color: enabled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

class _ArtworkPanel extends StatelessWidget {
  final ColorScheme cs;
  /// Forwarded to ArtworkImage.imageKey — marks the COVER's visible box.
  final Key? imageKey;
  final String? artworkUrl;
  final String? artist;
  final String? album;
  final String? localFilePath;
  final String? targetDir;
  /// The track's origin, straight from the controller. Without it the themed
  /// placeholder can only guess from the file's EXTENSION, so any format
  /// missing from the ext→platform table (a Quartet ST `.4v`, say) fell back to
  /// the generic rewamp mark while the source line right below said "Atari ST".
  final String? platformName;
  final String? formatHint;
  final bool isPlaying;
  final void Function(ImageProvider provider, String key)? onImageResolved;

  const _ArtworkPanel({
    required this.cs,
    this.imageKey,
    this.artworkUrl,
    this.artist,
    this.album,
    this.localFilePath,
    this.targetDir,
    this.platformName,
    this.formatHint,
    this.isPlaying = true,
    this.onImageResolved,
  });

  // Pause → play: the cover overshoots its full size by ~4% and snaps back —
  // a short, tight bounce, not a wobble. Play → pause: no overshoot (0.75 is a
  // resting state), long emphasized deceleration so it lands softly.
  static const Duration _kZoomInDuration  = Duration(milliseconds: 750);
  static const Duration _kZoomOutDuration = Duration(milliseconds: 750);
  // Cubic "back-out", tuned for punch: shoots to ~1.10 scale in the first ~100
  // ms (a quarter of the travel time), then snaps back onto 1.0. A late, gentle
  // peak reads as mushy — the overshoot has to land early and hard.
  static const Curve    _kZoomInCurve  = Cubic(0.2, 1.80, 0.40, 1.0);
  static const Curve    _kZoomOutCurve = Curves.easeInOutCubicEmphasized;
  static const double   _kRadius       = 12;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Plain black in both themes. In dark it only reads because the sheet behind
    // the cover is lifted a notch (see playerSurfaceColor).
    const shadowTint = Colors.black;

    // Playing → full size, barely lifted off the page. Paused → 75%, flat.
    // The shadow's opacity rides the same tween as the scale so both settle
    // together. The overshoot only applies going IN (see the curves above).
    final duration = isPlaying ? _kZoomInDuration : _kZoomOutDuration;
    final curve    = isPlaying ? _kZoomInCurve    : _kZoomOutCurve;
    return AnimatedScale(
      scale: isPlaying ? 1.0 : 0.75,
      duration: duration,
      curve: curve,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: isPlaying ? 1.0 : 0.0),
          duration: duration,
          // The shadow must NOT overshoot (alpha would clamp and look flat) —
          // it just follows the scale's timing.
          curve: isPlaying ? Curves.easeOutCubic : _kZoomOutCurve,
          builder: (context, lift, _) => ArtworkImage(
            imageKey: imageKey,
            url: artworkUrl,
            artist: artist,
            album: album,
            localFilePath: localFilePath,
            targetDir: targetDir,
            platformName: platformName,
            formatHint: formatHint,
            onImageResolved: onImageResolved,
            fit: BoxFit.contain,
            borderRadius: BorderRadius.circular(_kRadius),
            // ArtworkImage sizes itself to the cover's real aspect ratio when a
            // shadow is set, so this traces the artwork's own edges.
            shadows: [
              BoxShadow(
                color: shadowTint.withValues(alpha: lift * (dark ? 0.4 : 0.3)),
                blurRadius: 16,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: shadowTint.withValues(alpha: lift * (dark ? 0.2 : 0.15)),
                blurRadius: 12,
                offset: const Offset(-12, 0),
              ),
              BoxShadow(
                color: shadowTint.withValues(alpha: lift * (dark ? 0.2 : 0.15)),
                blurRadius: 12,
                offset: const Offset(12, 0),
              ),
            ],
            // No placeholder override: fall through to ArtworkImage's themed
            // per-platform placeholder (rewamp sun in the format's colours).
          ),
        ),
      ),
    );
  }
}

// ── Visualizer panel ──────────────────────────────────────────────────────────
//
// Shows the per-channel oscilloscope when voice data is available (VGM/S98/…),
// otherwise falls back to the global stereo waveform.  A Ticker polls
// audio.channelCount every frame so the switch is seamless mid-playback.
//
// The painter derives row height from the actual canvas size, so the grid
// never overflows regardless of voice count.
//
// Future: tap gesture → visualizer picker menu (Dear ImGui rendered via OpenGL,
// same architecture as Modizer).


// ── Player options sheet ───────────────────────────────────────────────────────

class _PlayerOptionsSheet extends StatefulWidget {
  final PlayerController   ctrl;
  final String             refId;      // onlineId ?? filePath
  final OnNavigateAlbum?   onNavigateAlbum;
  final OnNavigateArtist?  onNavigateArtist;
  final VoidCallback?      onNavigateSubsongs;
  final VoidCallback?      onRedownload;

  const _PlayerOptionsSheet({
    required this.ctrl,
    required this.refId,
    this.onNavigateAlbum,
    this.onNavigateArtist,
    this.onNavigateSubsongs,
    this.onRedownload,
  });

  @override
  State<_PlayerOptionsSheet> createState() => _PlayerOptionsSheetState();
}

class _PlayerOptionsSheetState extends State<_PlayerOptionsSheet> {
  bool _inLibrary = false;
  bool _loading   = true;

  /// Local file (no online id): the album isn't in the server DB, and artist
  /// navigation only makes sense for names the server actually knows.
  bool get _isLocal => widget.ctrl.currentOnlineId == null;

  /// True when the playing file was DOWNLOADED by the app (lives under the
  /// online/ tree) — the only case where "delete the download" is offered.
  bool get _isDownloadedFile {
    final fp = widget.ctrl.filePath;
    if (fp == null) return false;
    final sep = Platform.pathSeparator;
    return fp.contains('${sep}online$sep');
  }

  /// Offer a forced re-download only for a downloaded, single-song ONLINE file
  /// (not a container subsong, not an album archive) — "pas un album ni un
  /// fichier multisong". The action re-resolves the current URL and refetches.
  bool get _canRedownload =>
      widget.onRedownload != null &&
      _isDownloadedFile &&
      !_isLocal &&
      widget.ctrl.subsongIdx == 0 &&
      (widget.ctrl.currentSubsongCount ?? 1) <= 1;

  Future<void> _deleteDownload() async {
    final fp = widget.ctrl.filePath;
    if (fp == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return AlertDialog(
          title: Text(l10n.playerDeleteDownloadTitle),
          content: Text(l10n.playerDeleteDownloadBody(fp)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.playerCancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.playerDelete)),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    // Close the options sheet FIRST — the player itself is closed (or not) by
    // handleDeletedTrack below, through the controller's playerUiCloser, which
    // pops the top route.
    Navigator.of(context).pop();
    // Stops playback (the decoder is reading this file), drops EVERY queue entry
    // that plays from it (all subsongs of a .sid/.nsf, all members of an .rsn)
    // and starts the next entry; with nothing after it the player closes.
    // Before the delete: it reads the DB rows deleteLocalTrack removes.
    // (Recents refresh via LocalDb.notifyListeners in deleteEntriesUnderPath.)
    await widget.ctrl.handleDeletedTrack(fp);
    await RewampDb.deleteLocalTrack(fp);
  }

  /// For local files: tag-artist names confirmed to exist server-side.
  Set<String>? _serverArtists; // null = check pending

  static List<String> _splitArtists(String artist) => artist
      .split(RegExp(r'\s*[,;]\s*|\s*&\s*'))
      .map((a) => a.trim())
      .where((a) => a.isNotEmpty && a.toLowerCase() != 'null')
      .toSet()
      .toList();

  @override
  void initState() {
    super.initState();
    LocalDb.instance.isInLibrary('track', widget.refId).then((v) {
      if (mounted) setState(() { _inLibrary = v; _loading = false; });
    });
    final artist = widget.ctrl.currentArtist;
    if (_isLocal && artist != null && artist.isNotEmpty) {
      _checkServerArtists(_splitArtists(artist));
    }
  }

  Future<void> _checkServerArtists(List<String> names) async {
    final found = <String>{};
    for (final name in names) {
      try {
        final matches = await RewampDb.fetchArtists(nameFilter: name, limit: 5);
        if (matches.any((a) => a.name.toLowerCase() == name.toLowerCase())) {
          found.add(name);
        }
      } catch (_) {/* offline → leave hidden */}
    }
    if (mounted) setState(() => _serverArtists = found);
  }

  Future<void> _toggleLibrary() async {
    final ctrl      = widget.ctrl;
    final next      = !_inLibrary;
    final l10n      = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _inLibrary = next);
    Navigator.pop(context);
    if (next) {
      await LocalDb.instance.addToLibrary(
        type:       'track',
        refId:      widget.refId,
        name:       ctrl.displayTitle,
        artist:     ctrl.currentArtist,
        album:      ctrl.currentAlbum,
        albumId:    ctrl.currentAlbumId,
        artworkUrl: ctrl.artworkUrl,
        formatExt:  ctrl.currentFormatExt,
      );
    } else {
      await LocalDb.instance.removeFromLibrary('track', widget.refId);
    }
    // …et le compte doit l'apprendre: ce menu écrivait en local seulement.
    await SyncService.recordTrackMembership(
      refId:     widget.refId,
      value:     next,
      title:     ctrl.displayTitle,
      artist:    ctrl.currentArtist,
      album:     ctrl.currentAlbum,
      formatExt: ctrl.currentFormatExt,
    );
    AppSnack.showOn(messenger, next
          ? l10n.playerAddedToLibrary
          : l10n.playerRemovedFromLibrary, duration: const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;
    final tt   = Theme.of(context).textTheme;
    final album  = ctrl.currentAlbum;
    final artist = ctrl.currentArtist;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScrollingText(
                      text: ctrl.displayTitle,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (artist != null && artist.isNotEmpty)
                      ScrollingText(
                        text: artist,
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Library toggle
              ListTile(
                leading: _loading
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _inLibrary
                            ? Icons.library_add_check
                            : Icons.library_add_outlined,
                        color: _inLibrary ? cs.primary : null,
                      ),
                title: Text(_inLibrary
                    ? l10n.playerRemoveFromLibrary
                    : l10n.playerAddToLibrary),
                enabled: !_loading,
                onTap: _toggleLibrary,
              ),

              // View album — only for a real server album (known albumId),
              // hidden for local files (album not in the DB).
              if (!_isLocal &&
                  album != null && album.isNotEmpty &&
                  ctrl.currentAlbumId != null && ctrl.currentAlbumId!.isNotEmpty &&
                  widget.onNavigateAlbum != null)
                ListTile(
                  leading: const Icon(Icons.album_outlined),
                  title: Text(l10n.playerViewAlbum),
                  subtitle: Text(album, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => widget.onNavigateAlbum!(album,
                      collection: ctrl.currentCollectionSlug,
                      platform:   ctrl.currentPlatformName,
                      artworkUrl: ctrl.artworkUrl,
                      albumId:    ctrl.currentAlbumId),
                )
              // Single-file multi-subsong container (not a real album): open the
              // subsong list instead.
              else if (widget.onNavigateSubsongs != null)
                ListTile(
                  leading: const Icon(Icons.queue_music_outlined),
                  title: Text(l10n.playerViewSubsongs),
                  onTap: widget.onNavigateSubsongs,
                ),

              // View artist(s) — split joined "A & B", "A, B", "A; B" into
              // individual entries (PSF tags / M3U list several composers).
              // Local files: only names confirmed to exist server-side.
              if (artist != null && artist.isNotEmpty && widget.onNavigateArtist != null)
                ..._splitArtists(artist)
                    .where((a) =>
                        !_isLocal || (_serverArtists?.contains(a) ?? false))
                    .map((a) => ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(l10n.playerViewArtist),
                          subtitle: Text(a, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => widget.onNavigateArtist!(a),
                        )),

              // Demozoo notes of this track — only when known (same sheet as
              // the track options' Notes tile).
              if (ctrl.notes.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.notes_outlined),
                  title: Text(l10n.contextNotes),
                  subtitle: ctrl.notes.first.title != null
                      ? Text(ctrl.notes.first.title!,
                          maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    showSongNotesSheet(context, ctrl.notes);
                  },
                ),

              // Playlists — add the CURRENTLY PLAYING track (just itself).
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: Text(l10n.playerAddToPlaylist),
                onTap: () {
                  Navigator.pop(context);
                  final c = ctrl;
                  showAddToPlaylistSheet(context, resolveTrackIds: () async {
                    final id = await LocalDb.instance.upsertTrack(
                      filePath:   c.filePath ?? '',
                      subsongIdx: c.subsongIdx,
                      title:      c.displayTitle,
                      artist:     c.currentArtist,
                      metaAlbum:  c.currentAlbum,
                      formatExt:  c.currentFormatExt,
                      source:     c.currentOnlineId != null ? 'online' : 'local',
                      onlineId:   c.currentOnlineId,
                      albumId:    c.currentAlbumId,
                      collectionSlug: c.currentCollectionSlug,
                      platformName:   c.currentPlatformName,
                      artworkUrl: c.artworkUrl,
                    );
                    return [id];
                  });
                },
              ),

              // Force a re-download of the current single file (server-side
              // update): delete + refetch + replay in place.
              if (_canRedownload)
                ListTile(
                  leading: Icon(Icons.refresh, color: cs.primary),
                  title: Text(l10n.playerRedownload),
                  onTap: widget.onRedownload,
                ),

              // Delete the downloaded file (+ its local DB rows) — the same
              // affordance the album options offer, for a single/container
              // file. Only for files we downloaded (under online/): never
              // offered for the user's own local files.
              if (_isDownloadedFile)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: cs.error),
                  title: Text(l10n.playerDeleteDownload),
                  onTap: _deleteDownload,
                ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}



// ── Track info sheet body — live-refreshes when the track changes ───────────

class _TrackInfoSheetBody extends StatefulWidget {
  final PlayerController  ctrl;
  final ScrollController  scroll;
  final OnNavigateTag?    onNavigateTag;
  /// Closes the info sheet AND the player. The player is an OVERLAY, not a
  /// route: a chip must go through the host's _dismiss — a second
  /// Navigator.pop used to pop the SCREEN UNDERNEATH the player instead
  /// (black screen).
  final VoidCallback?     onLeavePlayer;

  const _TrackInfoSheetBody(
      {required this.ctrl, required this.scroll, this.onNavigateTag,
       this.onLeavePlayer});

  @override
  State<_TrackInfoSheetBody> createState() => _TrackInfoSheetBodyState();
}

class _TrackInfoSheetBodyState extends State<_TrackInfoSheetBody> {
  String _text = '';
  String _trackKey = '';
  Set<int> _activeInstr = const {};
  List<({String name, String category})> _tags = const [];
  List<ProductionRef> _productions = const [];

  bool _didInitialRefresh = false;

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onCtrl);
    // NOT _refresh() here: it reads context.l10n, and an inherited widget
    // cannot be looked up before initState completes — it threw, and the info
    // panel stayed empty. The first refresh belongs in didChangeDependencies.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialRefresh) return;
    _didInitialRefresh = true;
    _refresh();
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onCtrl);
    super.dispose();
  }

  String get _key => '${widget.ctrl.filePath}#${widget.ctrl.subsongIdx}';

  bool get _isOpenmpt => widget.ctrl.backend == 'libopenmpt';

  // Tags come from the controller's song context (category → names), fetched
  // once at load time — no second RPC here. A local file has none. The
  // category rides along so the tag search scopes to it (mig 159).
  static List<({String name, String category})> _flatTags(PlayerController c) =>
      [
        for (final e in c.songTags.entries)
          for (final name in e.value) (name: name, category: e.key),
      ];

  void _onCtrl() {
    if (_key != _trackKey) {
      _refresh();
      return;
    }
    // The song-context fetch is async — tags/productions can land after the
    // sheet opened.
    final tags = _flatTags(widget.ctrl);
    final prods = widget.ctrl.songProductions
        .where((p) => p.kind != 'own')
        .toList();
    if (!listEquals(tags, _tags) || prods.length != _productions.length) {
      setState(() { _tags = tags; _productions = prods; });
    }
    // Live instrument highlight (openmpt): the controller ticks ~4×/s;
    // repaint only when the active set actually changed.
    if (_isOpenmpt) {
      final now = widget.ctrl.audio.openmptActiveInstruments;
      if (!setEquals(now, _activeInstr)) {
        setState(() => _activeInstr = now);
      }
    }
  }

  Future<void> _refresh() async {
    _trackKey = _key;
    _tags = _flatTags(widget.ctrl);
    _productions =
        widget.ctrl.songProductions.where((p) => p.kind != 'own').toList();
    final text =
        await _PlayerScreenState._buildInfoText(widget.ctrl, context.l10n);
    if (mounted) setState(() => _text = text);
  }

  /// Renders the info text; inside the "Instruments:" / "Samples:" sections
  /// the lines whose "NN:" prefix is currently sounding get highlighted.
  Widget _buildText(BuildContext context) {
    const base = TextStyle(
        fontFamily: 'monospace', fontSize: 12, height: 1.35);
    if (!_isOpenmpt || _activeInstr.isEmpty) {
      return SelectableText(_text, style: base);
    }
    final primary = Theme.of(context).colorScheme.primary;
    final hi = base.copyWith(color: primary, fontWeight: FontWeight.bold);
    // Fixed-width leading gutter so the dot never shifts the text: a text
    // bullet would fall back to a non-monospace glyph of a different advance
    // and push the line right. Every list line reserves the same gutter; only
    // the sounding ones fill it with a dot.
    const gutterW = 14.0;
    final lineH = (base.fontSize ?? 12) * (base.height ?? 1.0);
    InlineSpan gutter(bool active) => WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(
            width: gutterW,
            height: lineH,
            child: active
                ? Center(
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: primary, shape: BoxShape.circle),
                    ),
                  )
                : null,
          ),
        );

    final spans = <InlineSpan>[];
    var inList = false;
    for (final line in _text.split('\n')) {
      if (line == 'Instruments:' || line == 'Samples:') {
        inList = true;
      } else if (line.isEmpty) {
        inList = false;
      }
      if (inList) {
        final m = RegExp(r'^(\d+):').firstMatch(line);
        if (m != null) {
          final active = _activeInstr.contains(int.parse(m.group(1)!));
          spans.add(gutter(active));
          spans.add(TextSpan(text: '$line\n', style: active ? hi : base));
          continue;
        }
      }
      spans.add(TextSpan(text: '$line\n', style: base));
    }
    return SelectableText.rich(TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.playerTrackInfo,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          // Clickable tags first: tapping one closes the sheet and launches a
          // search filtered by that tag. Hidden for a local file (no song id).
          // Group chips no longer need onNavigateTag: they open the group
          // screen through the global hook (migs 201/202).
          if (_productions.isNotEmpty || _tags.isNotEmpty) ...[
            // One ChipTheme rather than a style per chip: these are TAPPABLE,
            // and on the default surface colour they read as plain labels. The
            // colour is a SCHEME ROLE, not a hand-picked shade — the player runs
            // under a theme seeded from the cover, so secondaryContainer is
            // harmonious with the artwork by construction and Material
            // guarantees onSecondaryContainer legible against it. A hand-picked
            // colour would have to be re-picked for every cover.
            ChipTheme(
              data: ChipThemeData(
                backgroundColor: cs.secondaryContainer,
                labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                iconTheme:
                    IconThemeData(size: 14, color: cs.onSecondaryContainer),
                // A thin outline separates two adjacent chips, which the fill
                // alone stops doing once they touch.
                side: BorderSide(
                    color: cs.onSecondaryContainer.withValues(alpha: 0.25)),
                shape: const StadiumBorder(),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: -4,
                children: [
                // Productions are entities (migs 161-163): the chip opens THAT
                // demo by id, not a tag search that mixed up homonyms.
                for (final prod in _productions)
                  ActionChip(
                    avatar: const Icon(Icons.movie_outlined, size: 14),
                    label: Text(prod.label),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onPressed: () {
                      // Capture the navigator BEFORE closing (openProductionOn
                      // only uses it when the AppShell hook is absent), then
                      // close sheet + player through the host — never a second
                      // pop, the player is an overlay.
                      final nav = Navigator.of(context);
                      widget.onLeavePlayer?.call();
                      openProductionOn(nav, prod);
                    },
                  ),
                for (final t in _tags)
                  if (t.category == 'group' || widget.onNavigateTag != null)
                    ActionChip(
                      label: Text(t.name),
                      avatar: t.category == 'group'
                          ? const Icon(Icons.groups, size: 14)
                          : null,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: () {
                        // Close the sheet AND the player through the host
                        // (_dismiss): the player is an OVERLAY, and the old
                        // double Navigator.pop popped the screen UNDERNEATH
                        // it instead — black screen, playback torn down.
                        widget.onLeavePlayer?.call();
                        // A group is an entity, not a tag: its screen is the
                        // only place its productions can be listed.
                        final hook = globalOnOpenGroup;
                        if (t.category == 'group' && hook != null) {
                          hook(t.name);
                          return;
                        }
                        widget.onNavigateTag?.call(t.name,
                            category: t.category);
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildText(context),
        ],
      ),
    );
  }
}

/// Player-screen library add/remove toggle (next to the favourite star).
/// Library membership lives in LocalDb (keyed by refId), not on the
/// controller — so this owns its own async-loaded state, re-created per track
/// via a ValueKey(refId) by the parent.
/// Library refId for the currently-playing track. A single-file multi-subsong
/// container needs the subsong index baked in, or every subsong would collide
/// on one library row (UNIQUE(type, ref_id)) and relaunch would play the wrong
/// one. Mirrors the "?subsong=N" path convention used across the engine.
// Single source of truth: PlayerController.libraryRefId. ALWAYS subsong-scoped
// (even subsong 0) — playing from the player adds only the current subsong; the
// whole-file entry (added from the container screen) uses the bare base with no
// suffix, keeping the two distinct. The favourite toggle uses the same getter.
String? playerLibraryRefId(PlayerController ctrl) => ctrl.libraryRefId;

class _LibraryToggleButton extends StatefulWidget {
  final PlayerController ctrl;
  const _LibraryToggleButton({super.key, required this.ctrl});

  @override
  State<_LibraryToggleButton> createState() => _LibraryToggleButtonState();
}

class _LibraryToggleButtonState extends State<_LibraryToggleButton> {
  bool _inLibrary = false;
  bool _loading   = true;

  String? get _refId => playerLibraryRefId(widget.ctrl);

  @override
  void initState() {
    super.initState();
    // Re-check on any library mutation (LocalDb is a ChangeNotifier) so the
    // button lights up immediately when the star adds this track as a favourite
    // (a favourite is a library item with is_favorite=1).
    LocalDb.instance.addListener(_recheck);
    _recheck();
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_recheck);
    super.dispose();
  }

  void _recheck() {
    final refId = _refId;
    if (refId == null) { if (mounted) setState(() => _loading = false); return; }
    LocalDb.instance.isInLibrary('track', refId).then((v) {
      if (mounted) setState(() { _inLibrary = v; _loading = false; });
    });
  }

  Future<void> _toggle() async {
    final refId = _refId;
    if (refId == null) return;
    final ctrl      = widget.ctrl;
    final next      = !_inLibrary;
    final l10n      = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _inLibrary = next);
    if (next) {
      await LocalDb.instance.addToLibrary(
        type:       'track',
        refId:      refId,
        name:       ctrl.displayTitle,
        artist:     ctrl.currentArtist,
        album:      ctrl.currentAlbum,
        albumId:    ctrl.currentAlbumId,
        artworkUrl: ctrl.artworkUrl,
        formatExt:  ctrl.currentFormatExt,
      );
    } else {
      await LocalDb.instance.removeFromLibrary('track', refId);
    }
    await SyncService.recordTrackMembership(
      refId:     refId,
      value:     next,
      title:     ctrl.displayTitle,
      artist:    ctrl.currentArtist,
      album:     ctrl.currentAlbum,
      formatExt: ctrl.currentFormatExt,
    );
    AppSnack.showOn(messenger, next
          ? l10n.playerAddedToLibrary
          : l10n.playerRemovedFromLibrary, duration: const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_inLibrary ? Icons.library_add_check : Icons.library_add),
      tooltip: _inLibrary
          ? context.l10n.playerRemoveFromLibrary
          : context.l10n.playerAddToLibrary,
      onPressed: _loading ? null : _toggle,
    );
  }
}

/// Un glissement VERTICAL de fermeture du lecteur est en cours.
///
/// Le glissement de fermeture est un `Listener` — il observe les pointeurs
/// sans entrer dans l'arène des gestes (voir `_buildTabBarLayout`), donc rien
/// n'arbitre entre lui et le `GestureDetector` horizontal qui change de piste:
/// une fermeture un peu diagonale déclenchait les deux. Le drapeau rétablit
/// l'exclusion que l'arène aurait faite, dans le seul sens qui compte — le
/// vertical, une fois revendiqué, garde le geste jusqu'au relâchement.
bool _playerDismissDragActive = false;
