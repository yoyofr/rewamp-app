import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp_audio/rewamp_audio.dart';

import 'app_snack.dart';
import 'artwork_image.dart';
import 'l10n.dart';
import 'local_db.dart';
import 'oscilloscope_widget.dart';
import 'preset_manager.dart';
import 'preset_screen.dart';
import 'channel_scope_widget.dart';
import 'notes_scope_widget.dart';
import 'pattern_scope_widget.dart';
import 'projectm_widget.dart';
import 'spectrum_widget.dart';
import 'user_settings.dart';
import 'waveform_icons.dart';
import 'viz_gl_ownership.dart';

/// Which projectM state the centred OSD is currently showing. One slot, because
/// they all draw in the same place: pressing two shortcuts in a row must replace
/// the badge, not stack a second one on it.
enum _VizFlash { lock, presetOrder }

enum VizEffect {
  stereo  (Icons.graphic_eq),
  spectrum(Icons.equalizer),
  voices  (Icons.waves),
  notes   (Icons.piano),
  patterns(Icons.grid_on),
  projectm(Icons.auto_awesome);

  const VizEffect(this.icon);
  final IconData icon;

  /// The button glyph. Material for most of them, but the two oscilloscopes
  /// are DRAWN (see [WaveformIcon]): no Material icon is a trace — graphic_eq
  /// is a bar meter — and none at all is several traces, which is exactly what
  /// separates the stereo scope from the per-voice one.
  Widget iconAt({required double size, required Color color}) => switch (this) {
        VizEffect.stereo => WaveformIcon(size: size, color: color, traces: 1),
        VizEffect.voices => WaveformIcon(size: size, color: color, traces: 2),
        _ => Icon(icon, size: size, color: color),
      };

  /// Human-readable name. 'projectM' is the library's own name — not localized.
  String labelOf(AppLocalizations l10n) => switch (this) {
        VizEffect.stereo   => l10n.vizStereo,
        VizEffect.spectrum => l10n.vizSpectrum,
        VizEffect.voices   => l10n.vizVoices,
        VizEffect.notes    => l10n.vizNotes,
        VizEffect.patterns => l10n.vizPatterns,
        VizEffect.projectm => 'projectM',
      };
}

class VizSelectorWidget extends StatefulWidget {
  final RewampAudio audio;
  final double height;
  final bool fillHeight;

  // Artwork background — decoded and uploaded to GL; opacity from UserSettings.
  final String? artworkUrl;
  final String? artworkLocalFilePath;
  final String? artworkTargetDir;
  final String? artist;
  final String? album;

  // Device fullscreen (native window fullscreen; chrome hides). null hides the
  // button (unsupported platform). Also triggered by double-tapping the viz.
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;

  /// Transport controls drawn at the very bottom while fullscreen (the player
  /// chrome is hidden then). Lives INSIDE the tap-to-reveal overlay, so it
  /// fades in and auto-hides exactly like the visualizer selector.
  final Widget? fullscreenControls;

  /// Transient "what is playing" card drawn bottom-LEFT while fullscreen.
  /// Deliberately OUTSIDE the tap-to-reveal overlay, unlike [fullscreenControls]:
  /// it manages its own show/fade on a track change, and gating it on the
  /// overlay would hide it exactly when it is meant to appear (nobody is
  /// touching the screen when a track auto-advances).
  final Widget? fullscreenTrackInfo;

  /// Leaves the visualizer (back to the artwork). null hides the close button.
  final VoidCallback? onClose;

  /// Corner radius of the visualizer surface. 0 = square. Ignored while
  /// fullscreen (edge-to-edge there).
  ///
  /// Two implementations, because the surface is not the same object on both
  /// platforms and only one of them can be clipped:
  ///  * Apple/desktop — the viz is a Flutter `Texture`, so a plain `ClipRRect`
  ///    (Clip.antiAlias, NEVER antiAliasWithSaveLayer — that allocates and
  ///    composites an offscreen layer every frame) clips it for free.
  ///  * Android — the viz is an OPAQUE SurfaceView composited by SurfaceFlinger
  ///    as its own layer, which a Flutter clip does not touch at all. Instead
  ///    Flutter paints four corner wedges ON TOP of it (hybrid composition lets
  ///    it draw above the platform view): four small static paths per frame,
  ///    no GL change, no extra layer.
  final double borderRadius;

  /// Colour of the Android corner wedges: whatever sits BEHIND the visualizer,
  /// since an opaque SurfaceView cannot show transparency through. Unused on
  /// Apple/desktop (real clipping there). null → black.
  final Color? cornerBackdrop;

  const VizSelectorWidget({
    super.key,
    required this.audio,
    this.height              = 160,
    this.fillHeight          = false,
    this.artworkUrl,
    this.artworkLocalFilePath,
    this.artworkTargetDir,
    this.artist,
    this.album,
    this.isFullscreen        = false,
    this.onToggleFullscreen,
    this.fullscreenControls,
    this.fullscreenTrackInfo,
    this.onClose,
    this.borderRadius        = 0,
    this.cornerBackdrop,
  });

  @override
  State<VizSelectorWidget> createState() => _VizSelectorWidgetState();
}

class _VizSelectorWidgetState extends State<VizSelectorWidget>
    with TickerProviderStateMixin {
  late VizEffect _active;
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  Timer? _hideTimer;
  /// Last pointer movement over the panel. The auto-hide countdown restarts
  /// from it rather than from the moment the controls were revealed: someone
  /// moving the mouse over the visualizer is looking at it, and having the
  /// buttons and the track card fade out from under a moving pointer is the
  /// thing being fixed here.
  DateTime _lastPointerMove = DateTime.fromMillisecondsSinceEpoch(0);
  bool _pmPointerHeld = false;   // pointer button state fed to projectM
  // State flash, for the keyboard shortcuts only — see _flashState. ONE
  // controller and one slot for every state a key can toggle: they all draw
  // centred, so two of them would land on top of each other the moment two keys
  // are pressed in a row.
  late final AnimationController _stateFlashCtrl;
  Timer? _stateFlashTimer;
  _VizFlash _stateFlash = _VizFlash.lock;
  String? _loadedArtworkKey;
  bool    _uploading = false;

  // Animated GIF/APNG/WebP artwork: the minimum per-frame delay to honor,
  // guarding against malformed sources reporting a 0ms frame duration
  // (would otherwise busy-loop re-uploading the GL texture every tick).
  static const _kMinFrameDelay = Duration(milliseconds: 20);

  @override
  void initState() {
    super.initState();
    final saved = UserSettings.instance.vizEffect;
    _active = VizEffect.values.firstWhere(
      (e) => e.name == saved,
      orElse: () => VizEffect.stereo,
    );
    // Asymmetric on purpose: appearing is a RESPONSE to a tap and must feel
    // instant, while fading out is ambient and can take its time. One shared
    // 350 ms made the controls feel laggy on the way in.
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 320),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl,
      curve: Curves.easeOutCubic,      // in: fast start, settles
      reverseCurve: Curves.easeIn,     // out: unhurried
    );
    _stateFlashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 360),
    );
    // We own the shared GL context now: children must not destroy it when a
    // switch swaps them out, or the next one rebuilds it from scratch.
    kVizGlOwnedBySelector = true;
    UserSettings.instance.addListener(_onOpacityChanged);
    HardwareKeyboard.instance.addHandler(_onKey);
    _releaseLookaheadIfIdle();   // start at minimum unless the initial viz needs a lead
    _syncSlowWatch();            // le visualiseur peut S'OUVRIR sur projectM
    _pushPmMode();
    _loadArtwork();
  }

  /// N / P / H / S / L while projectM is on screen: next preset, previous
  /// preset, lock toggle (H as in "hold" — L reads as "list" and is the
  /// picker), shuffle toggle (ordered presets vs random) and the quick preset
  /// picker. Same actions as the on-screen arrows, the padlock and the
  /// magnifier, plus the "random next preset" setting.
  ///
  /// A global handler rather than a [Focus] subtree: the visualizer holds no
  /// focus of its own (its surface is a platform view or a texture, and the
  /// controls that DO take focus are buttons), so a focus-scoped shortcut would
  /// only fire after the user happened to click the right thing.
  ///
  /// Being global, it must stay out of the way of text entry: a search field or
  /// a "name this playlist" dialog can be open over the player, and eating its
  /// letters would be worse than having no shortcut at all. Same for any
  /// modified combination, which belongs to the platform's menus.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return false;
    }
    // Text entry wins, always: the preset picker has a filter field, and there
    // are naming dialogs over the player. A bare
    // "primaryFocus.context.widget is EditableText" does NOT detect it — the
    // focused node's context is the Focus widget INSIDE EditableText, so the
    // test never matched and typing "hello" in the filter jumped presets and
    // toggled the lock instead of writing anything.
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null &&
        (focusContext.widget is EditableText ||
            focusContext.findAncestorWidgetOfExactType<EditableText>() !=
                null)) {
      return false;
    }

    final key = event.logicalKey;

    // Reveal, and nothing else — the keyboard equivalent of tapping the panel.
    // Deliberately BEFORE the projectM gate below: the tap that brings the
    // controls up (`onTap: _showOverlay` on the whole stack) knows nothing
    // about the current effect, so its keyboard twin must not either. Without
    // a pointer there is otherwise no way to see the buttons at all.
    if (key == LogicalKeyboardKey.f1 || key == LogicalKeyboardKey.keyI) {
      _showOverlay();
      return true;
    }

    // Everything past here drives projectM and only makes sense there.
    if (_effective != VizEffect.projectm || !widget.audio.hasProjectM) {
      return false;
    }

    if (key == LogicalKeyboardKey.keyN) {
      widget.audio.projectmNextPreset();
    } else if (key == LogicalKeyboardKey.keyP) {
      widget.audio.projectmPrevPreset();
    } else if (key == LogicalKeyboardKey.keyH) {
      // Writing the setting is enough: the settings listener re-pushes the
      // params to the engine, and the padlock button rebuilds from it.
      final s = UserSettings.instance;
      s.pmLockPreset = !s.pmLockPreset;
      _flashState(_VizFlash.lock);
    } else if (key == LogicalKeyboardKey.keyS) {
      // Same trick as the padlock: writing the setting is the whole action, the
      // listener pushes it to the engine.
      final s = UserSettings.instance;
      s.pmRandomNext = !s.pmRandomNext;
      _flashState(_VizFlash.presetOrder);
    } else if (key == LogicalKeyboardKey.keyL) {
      _showPmPresetPicker();
    } else {
      return false;
    }
    // A key press is not a pointer, so nothing else brings the controls up:
    // reveal them, which is what tells the user what just happened (the padlock
    // colour, the preset name in the banner).
    _showOverlay();
    return true;
  }

  /// Feeds the pointer to projectM, for presets that read MilkDrop3's `mouse`
  /// uniform (`mouse.xy` position, `.z` held, `.w` just clicked).
  ///
  /// A [Listener], not a gesture recognizer: it never enters the arena, so the
  /// double-tap-to-fullscreen, the skip swipe and the dismiss drag keep working
  /// exactly as before. Only mounted for projectM — every other visualizer
  /// would pay the hit-test for nothing.
  Widget _pmPointerLayer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        void send(Offset position, {bool held = false, bool clicked = false}) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          if (width <= 0 || height <= 0) return;
          widget.audio.projectmSetMouse(
            (position.dx / width).clamp(0.0, 1.0),
            (position.dy / height).clamp(0.0, 1.0),
            held: held,
            clicked: clicked,
          );
        }

        return MouseRegion(
          opaque: false,
          // Hover only exists on desktop; touch devices go through the Listener.
          onHover: (e) => send(e.localPosition, held: _pmPointerHeld),
          onExit: (_) => widget.audio.projectmSetMouse(-1, -1),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) {
              _pmPointerHeld = true;
              send(e.localPosition, held: true);
            },
            onPointerMove: (e) => send(e.localPosition, held: _pmPointerHeld),
            onPointerUp: (e) {
              _pmPointerHeld = false;
              send(e.localPosition, clicked: true);
              // The click is an EVENT, not a state: presets test it as "did a
              // click just happen", so it has to fall back to 0 on its own.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) send(e.localPosition);
              });
            },
            onPointerCancel: (_) {
              _pmPointerHeld = false;
              widget.audio.projectmSetMouse(-1, -1);
            },
          ),
        );
      },
    );
  }

  /// Brief centred padlock, shown when the lock is toggled from the KEYBOARD.
  ///
  /// The on-screen padlock is the real state display, but three things can hide
  /// it at the moment the key is pressed: the controls may have faded out, they
  /// sit in a corner the eye is not on, and the whole projectM control cluster
  /// is absent on a build without the playlist API. A pointer toggle needs none
  /// of this — the button is under the finger and changes colour there.
  /// Shows WHAT the state is now, briefly and centred, like a volume OSD.
  void _flashState(_VizFlash kind) {
    _stateFlashTimer?.cancel();
    setState(() => _stateFlash = kind);
    _stateFlashCtrl.forward();
    _stateFlashTimer = Timer(const Duration(milliseconds: 850), () {
      if (mounted) _stateFlashCtrl.reverse();
    });
  }

  void _pushPmMode() {
    if (!widget.audio.hasProjectM) return;
    final s = UserSettings.instance;
    widget.audio.projectmSetParams(
      randomNext:         s.pmRandomNext,
      lockPreset:         s.pmLockPreset,
      blend:              s.pmBlend,
      blendTime:          s.pmBlendTime,
      presetDuration:     s.pmPresetDuration,
      qualityShift:       s.pmQuality,
      meshX:              s.pmMeshX,
      meshY:              s.pmMeshY,
      beatSensitivity:    s.pmBeatSensitivity,
      hardcutEnabled:     s.pmHardcut,
      hardcutTime:        s.pmHardcutTime,
      hardcutSensitivity: s.pmHardcutSensitivity,
      aspectCorrection:   s.pmAspectRatio,
      permissive:         s.pmPermissive,
      transitionIndex:    s.pmTransition,
    );
  }

  @override
  void didUpdateWidget(VizSelectorWidget old) {
    super.didUpdateWidget(old);
    final newKey = '${widget.artworkUrl}|${widget.artworkLocalFilePath}';
    if (newKey != _loadedArtworkKey) _loadArtwork();
  }

  @override
  void dispose() {
    UserSettings.instance.removeListener(_onOpacityChanged);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _slowPoll?.cancel();
    _slowClear?.cancel();
    _hideTimer?.cancel();
    _stateFlashTimer?.cancel();
    _stateFlashCtrl.dispose();
    _fadeCtrl.dispose();
    // Leaving the visualizer for real — release the shared GL context the
    // children were told not to touch. Order matters: hand ownership back
    // BEFORE unregistering, so nothing can re-register behind us.
    kVizGlOwnedBySelector = false;
    widget.audio.vizUnregister();
    widget.audio.setLookaheadSeconds(0.0);  // leaving the viz entirely → minimum lead
    super.dispose();
  }

  void _onOpacityChanged() {
    widget.audio.vizSetArtworkOpacity(UserSettings.instance.vizArtworkOpacity);
    _pushPmMode(); // settings listener also covers projectM random/blend changes
  }

  Future<void> _loadArtwork() async {
    final key = '${widget.artworkUrl}|${widget.artworkLocalFilePath}';
    // Claim the key FIRST, before any early return: every in-flight step below
    // compares against it to notice it has been superseded, and the GIF loop
    // stops on it too.
    _loadedArtworkKey = key;
    // A load already running does NOT mean "drop this one". It used to: the
    // guard returned, and the artwork for the track we just switched to was
    // never uploaded — the visualizer kept the previous cover until something
    // else happened to call back in (toggling the viz off and on). Decoding a
    // cover and reading it back as raw RGBA is slow enough that switching
    // tracks lands inside that window regularly. Let the running load finish;
    // its `finally` sees the key moved and re-runs for the newest one.
    if (_uploading) return;

    // Resolve local path
    String? localPath;
    if (widget.artworkLocalFilePath != null) {
      localPath = await ArtworkCache.instance.findLocalArtwork(
          widget.artworkLocalFilePath!);
    }
    if (localPath == null && widget.artworkUrl != null) {
      localPath = await ArtworkCache.instance.getPath(
        widget.artworkUrl!,
        artist:    widget.artist,
        album:     widget.album,
        targetDir: widget.artworkTargetDir,
      );
    }

    // Resolving the path is itself async — the track may have changed again
    // while we were at it, in which case a newer call already owns the key and
    // this one must not touch the texture.
    if (!mounted || key != _loadedArtworkKey) return;
    if (localPath == null) {
      widget.audio.vizClearArtwork();
      return;
    }

    _uploading = true;
    ui.Codec? codec;
    try {
      final bytes = await File(localPath).readAsBytes();
      if (!mounted) return;
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted || key != _loadedArtworkKey) { frame.image.dispose(); return; }
      await _uploadFrame(frame.image);
      if (codec.frameCount > 1) {
        // Animated source (GIF/APNG/WebP): the GL texture upload
        // (rewamp_viz_set_artwork) is one-shot, so without this it freezes
        // on frame 0 for as long as the visualizer stays active. Runs
        // detached (not awaited) — _animateGif stops itself once this
        // track's artwork key changes or the widget unmounts.
        unawaited(_animateGif(codec, key, frame.duration));
      } else {
        codec.dispose();
      }
    } catch (_) {
      widget.audio.vizClearArtwork();
      codec?.dispose();
    } finally {
      _uploading = false;
      // Someone asked for a different cover while this one was loading (the
      // early return above) — serve it now. Converges: each pass takes the
      // newest key, so this stops as soon as no further change came in.
      if (mounted && _loadedArtworkKey != key) unawaited(_loadArtwork());
    }
  }

  /// Uploads one decoded frame to the GL artwork texture. Disposes [image].
  Future<void> _uploadFrame(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = image.width;
    final h = image.height;
    image.dispose();
    if (!mounted || byteData == null) return;
    widget.audio.vizSetArtwork(
      byteData.buffer.asUint8List(), w, h,
      UserSettings.instance.vizArtworkOpacity,
    );
  }

  /// Keeps decoding+uploading subsequent frames of an animated artwork
  /// source. [codec] wraps back to frame 0 automatically past the last
  /// frame (standard ui.Codec behavior), so this loops the animation
  /// forever until [key] is no longer the current artwork.
  Future<void> _animateGif(ui.Codec codec, String key, Duration firstDelay) async {
    try {
      var delay = firstDelay < _kMinFrameDelay ? _kMinFrameDelay : firstDelay;
      while (mounted && key == _loadedArtworkKey) {
        await Future.delayed(delay);
        if (!mounted || key != _loadedArtworkKey) break;
        final frame = await codec.getNextFrame();
        if (!mounted || key != _loadedArtworkKey) { frame.image.dispose(); break; }
        await _uploadFrame(frame.image);
        delay = frame.duration < _kMinFrameDelay ? _kMinFrameDelay : frame.duration;
      }
    } finally {
      codec.dispose();
    }
  }

  static const _kOverlayHold = Duration(seconds: 3);

  void _showOverlay() {
    // forward(), not forward(from: 0): tapping again while the controls are up
    // (or still fading out) should just carry on to full opacity, not snap back
    // to transparent and re-fade — which read as a flicker.
    _fadeCtrl.forward();
    _lastPointerMove = DateTime.now();
    _armOverlayHide();
  }

  void _armOverlayHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_kOverlayHold, _onOverlayHideTick);
  }

  /// Hides only after [_kOverlayHold] of real STILLNESS.
  ///
  /// Re-arming for the REMAINDER rather than restarting the timer on every
  /// pointer event is what keeps this cheap: hover fires at mouse-move rate
  /// (~100/s on a trackpad) and cancelling plus allocating a Timer that often,
  /// for three seconds of hold, is churn for nothing. Here a move writes one
  /// timestamp and the timer reschedules itself at most once per hold.
  void _onOverlayHideTick() {
    if (!mounted) return;
    final idle = DateTime.now().difference(_lastPointerMove);
    if (idle < _kOverlayHold) {
      _hideTimer = Timer(_kOverlayHold - idle, _onOverlayHideTick);
      return;
    }
    _hideTimer = null;
    _fadeCtrl.reverse();
  }

  /// A pointer moved over the panel: keep the controls up.
  ///
  /// Never REVEALS them — merely passing the pointer over the visualizer must
  /// not make the buttons appear, or they would flash on every trip across the
  /// window. It only postpones a fade already scheduled, so it is inert while
  /// the controls are down (no timer armed, nothing to postpone).
  void _pokeOverlay() {
    if (_hideTimer == null) return;
    _lastPointerMove = DateTime.now();
  }

  void _dismissOverlay() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _fadeCtrl.reverse();
  }

  /// Per-voice data availability. A backend that decodes an already-mixed
  /// stream (vgmstream, and miniaudio's mp3/ogg/flac/wav) exposes no chip
  /// channels and therefore no notes: the voice scope, the notation and the
  /// synthesized pattern grid would all draw an empty surface. Stereo and
  /// projectM work from the mixed output alone.
  ///
  /// voiceCountRaw, NOT voiceCount: the latter substitutes two virtual voices
  /// fed from the L/R waveform so the scope always has something to draw, so it
  /// is never 0 for a loaded file and cannot answer this question.
  bool get _voiceDataAvailable => widget.audio.voiceCountRaw > 0;

  /// Pattern grid availability: real tracker data (openmpt/furnace) anywhere,
  /// or the GL renderer's synthesized rows — which are built from the note
  /// timeline, hence the per-voice requirement — EXCEPT for SID, whose fast
  /// same-pitch re-triggers don't map onto an 8-rows/s grid well enough to be
  /// trustworthy (the notes visualizer is the right tool there).
  bool get _patternsAvailable =>
      widget.audio.patternSupported ||
      (widget.audio.hasPatternGl &&
          _voiceDataAvailable &&
          widget.audio.backendName != 'libsidplayfp');

  bool _availableFor(VizEffect e) => switch (e) {
        VizEffect.patterns => _patternsAvailable,
        VizEffect.voices || VizEffect.notes => _voiceDataAvailable,
        VizEffect.projectm => widget.audio.hasProjectM,
        // Track-independent (fed by the main output like stereo), but GL-only:
        // no CustomPaint fallback, so desktop Linux/Windows and a stale binary
        // (hasSpectrum false) don't get a dead button.
        VizEffect.spectrum => widget.audio.hasSpectrum &&
            (widget.audio.vizGpuAvailable ||
                (!kIsWeb && Platform.isAndroid)),
        VizEffect.stereo => true,
      };

  /// What actually renders: the chosen effect, unless it became unavailable
  /// for the current track (patterns on a SID, anything voice-based on an
  /// mp3/ogg/vgmstream stream). _active (the user's choice) is kept, so it
  /// comes back on the next track that supports it.
  VizEffect get _effective {
    if (_availableFor(_active)) return _active;
    // Patterns degrade to the notation when only the grid is unusable; when
    // there is no per-voice data at all, the stereo waveform is the only
    // meaningful fallback.
    if (_active == VizEffect.patterns && _voiceDataAvailable) {
      return VizEffect.notes;
    }
    return VizEffect.stereo;
  }

  // The notes/pattern children set the decode look-ahead they need on show and
  // must NOT clear it on dispose (switching between them would clobber the
  // incoming one — the outgoing child disposes after the new one is built). So
  // the release lives here: whenever the active effect is not a look-ahead one,
  // drop it back to the minimum.
  void _releaseLookaheadIfIdle() {
    if (_effective != VizEffect.notes && _effective != VizEffect.patterns) {
      widget.audio.setLookaheadSeconds(0.0);
    }
  }

  // ── Garde-fou « appareil trop lent » ──────────────────────────────────────
  //
  // Un preset Milkdrop peut être arbitrairement coûteux, et sur un appareil
  // modeste il tombe à quelques images par seconde: l'app paraît gelée alors
  // qu'elle rend. Le moteur mesure la cadence sur son fil de RENDU (seul
  // endroit qui la connaisse — sur Android la SurfaceView est pilotée par
  // AChoreographer, Dart n'est pas dans la boucle) et rend un verdict
  // CONSOMMABLE; ici on ne fait qu'AGIR dessus.
  //
  // Deux paliers, comme demandé: le preset fautif est écarté et on passe au
  // suivant; si ça s'enchaîne, c'est l'appareil qui ne suit pas et le
  // visualiseur entier est coupé. Le compteur de suite ne se remet à zéro
  // qu'après un preset qui a TENU — sinon trois presets lents séparés par un
  // preset sain sur une heure finiraient par couper le visualiseur.
  static const int _kSlowStrikeLimit = 3;
  // Court exprès: les presets peuvent être réglés pour tourner toutes les
  // secondes, donc « trois d'affilée » doit se juger sur une fenêtre du même
  // ordre. Trop long, et trois presets lents espacés dans la session
  // finiraient par couper un visualiseur qui marche.
  static const Duration _kSlowSurvived = Duration(seconds: 8);
  Timer? _slowPoll, _slowClear;
  int _slowStrikes = 0;
  bool _slowHandling = false;
  /// Le preset déjà sanctionné. Un verdict qui le désigne encore ne compte
  /// PAS: le changement demandé n'a pas encore atterri (il s'applique sur le
  /// fil de rendu, à la frame suivante — qui peut être à une seconde d'ici sur
  /// l'appareil même dont on est en train de constater la lenteur).
  String? _slowLastPath;
  /// Et une fenêtre de grâce en TEMPS pour le preset qui arrive: sans elle,
  /// trois verdicts tombaient en une seconde sur un appareil uniformément lent
  /// et le visualiseur se coupait « directement », sans qu'aucun preset ait eu
  /// sa chance. La consigne est « trois presets successifs », pas « trois
  /// verdicts ».
  DateTime _slowGraceUntil = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _kSlowGrace = Duration(seconds: 3);

  void _syncSlowWatch() {
    final want = _effective == VizEffect.projectm && widget.audio.hasProjectM;
    if (want == (_slowPoll != null)) return;
    if (!want) {
      _slowPoll?.cancel();
      _slowPoll = null;
      _slowClear?.cancel();
      _slowClear = null;
      return;
    }
    // 250 ms: le verdict tombe déjà après ~1 s de rendu lent, l'interroger
    // deux fois moins souvent ajouterait un demi-tour de retard à la réaction
    // pour une lecture d'entier par tick.
    _slowPoll = Timer.periodic(
        const Duration(milliseconds: 250), (_) => _checkSlow());
  }

  Future<void> _checkSlow() async {
    if (_slowHandling || !mounted) return;
    if (!widget.audio.projectmTakeSlowVerdict()) return;
    // Le verdict est CONSOMMÉ avant ces deux filtres — c'est voulu: on veut une
    // mesure FRAÎCHE après, pas celle qui traînait.
    if (DateTime.now().isBefore(_slowGraceUntil)) return;
    final path = widget.audio.projectmPresetPath;
    final name = widget.audio.projectmPresetName;
    if (path.isNotEmpty && path == _slowLastPath) return;

    _slowHandling = true;
    // Journalisé: le garde-fou agit tout seul et, quand il ne se déclenche pas,
    // il n'y a rien à regarder pour savoir s'il MESURE ou s'il dort.
    debugPrint('[viz] preset trop lent (${_slowStrikes + 1}/'
        '$_kSlowStrikeLimit): $name');
    try {
      _slowStrikes++;
      _slowClear?.cancel();
      if (_slowStrikes >= _kSlowStrikeLimit) {
        // L'appareil ne suit pas: ce n'est plus un preset à écarter.
        if (path.isNotEmpty) {
          await PresetManager.instance.blockSlowPreset(path);
        }
        _slowStrikes = 0;
        if (!mounted) return;
        _select(VizEffect.stereo);
        _syncSlowWatch();
        // Une BOÎTE DE DIALOGUE, pas un bandeau: le visualiseur vient de
        // disparaître sous les yeux de l'utilisateur et il faut dire pourquoi.
        // Un `AppSnack` ne suffisait pas — il s'affiche dans le messager de la
        // feuille du lecteur, que la sortie du plein écran remonte au même
        // instant, et le message passait inaperçu (constaté: visualiseur coupé,
        // aucun message). Le dialogue va au navigateur RACINE pour la même
        // raison: il doit survivre à ce qui se referme derrière lui.
        final nav = Navigator.of(context, rootNavigator: true);
        showDialog<void>(
          context: nav.context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.l10n.pmSlowDeviceTitle),
            content: Text(ctx.l10n.pmSlowDeviceOff),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(ctx.l10n.commonOk),
              ),
            ],
          ),
        );
        return;
      }
      if (path.isNotEmpty) {
        await PresetManager.instance.blockSlowPreset(path);
      }
      _slowLastPath = path;
      _slowGraceUntil = DateTime.now().add(_kSlowGrace);
      widget.audio.projectmNextPreset();
      if (!mounted) return;
      AppSnack.show(
          context,
          context.l10n.pmSlowPresetDropped(
              name.isEmpty ? '?' : name),
          duration: const Duration(seconds: 4));
      // Un preset qui TIENT efface l'ardoise: la suite doit être vraiment
      // consécutive.
      _slowClear = Timer(_kSlowSurvived, () => _slowStrikes = 0);
    } finally {
      _slowHandling = false;
    }
  }

  void _select(VizEffect e) {
    setState(() => _active = e);
    _releaseLookaheadIfIdle();
    _syncSlowWatch();
    UserSettings.instance.vizEffect = e.name;
    // No artwork re-upload here any more. It existed because the GL context was
    // destroyed and rebuilt on every switch, taking the artwork texture with it.
    // The context now survives a switch, so the texture does too — and re-reading
    // and re-decoding the cover on every tap cost ~25 ms for nothing (measured).
  }

  /// Preset prev/next control: a large semi-transparent triangle (no button
  /// chrome), a shadow keeping it legible over bright presets. Sits centred on
  /// the left/right edge of the visualizer.
  Widget _presetArrow({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      iconSize: 48,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
      color: Colors.white.withValues(alpha: 0.65),
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        icon,
        shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
      ),
    );
  }

  /// projectM top-left cluster: preset-source picker + add-current-to-playlist.
  /// Appends the keyboard shortcut to a tooltip, where there is a keyboard to
  /// press it on. The letter is a key cap, not a word: it stays as-is in every
  /// locale.
  /// The order icons, in ONE place: the on-screen button and the keyboard OSD
  /// show the same state, so showing it with two different glyphs (a shuffle
  /// against a numbered list) read as two different settings.
  static IconData _pmOrderIcon(bool random) =>
      random ? Icons.shuffle : Icons.arrow_forward;

  static String _withKeyHint(String tooltip, String key) {
    final hasKeyboard = !kIsWeb &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
    return hasKeyboard ? '$tooltip  ($key)' : tooltip;
  }

  Widget _pmControls(AppLocalizations l10n, ColorScheme cs) {
    final idle = Colors.white.withValues(alpha: 0.85);
    Widget btn(IconData icon, String tooltip, VoidCallback onTap) => Tooltip(
          message: tooltip,
          child: InkResponse(
            onTap: onTap,
            radius: 22,
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Icon(icon, size: 20, color: idle),
            ),
          ),
        );
    Widget pill(List<Widget> children) => Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pill([
          btn(Icons.queue_music, l10n.pmSourceTooltip, _showPmSourceSheet),
          btn(Icons.playlist_add, l10n.pmAddToPlaylistTooltip,
              _addCurrentPresetToPlaylist),
        ]),
        const SizedBox(height: 6),
        // Jump straight to a preset of the source already playing. The source
        // sheet above changes WHICH list plays; this one picks inside it, which
        // is the thing you want when you remember a name and the rotation is on
        // preset 40 of 255.
        pill([
          btn(Icons.search, _withKeyHint(l10n.pmPickTooltip, 'L'),
              _showPmPresetPicker),
        ]),
        const SizedBox(height: 6),
        // The two projectM settings you reach for WHILE watching: lock (a
        // preset you like must not rotate away in 15 s) and the shuffle/
        // sequential order. Same switches as Settings → Visualisation →
        // projectM: writing the setting is enough, the settings listener
        // re-pushes the params to the engine.
        ListenableBuilder(
          listenable: UserSettings.instance,
          builder: (context, _) {
            final s = UserSettings.instance;
            final idleColor = Colors.white.withValues(alpha: 0.85);
            // No "engaged" colour on any of them: the GLYPH already says which
            // state is on (open vs closed padlock, dice vs arrow), so a second
            // signal on top of it only competed with the icon it was doubling.
            Widget toggle(IconData icon, String tooltip, VoidCallback tap) =>
                Tooltip(
                  message: tooltip,
                  child: InkResponse(
                    onTap: tap,
                    radius: 22,
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(icon, size: 20, color: idleColor),
                    ),
                  ),
                );
            // Tooltips name the ACTION the tap performs, so they flip with the
            // state — a fixed label ("Lock preset") on a already-locked button
            // reads as if the tap would lock it again.
            return pill([
              toggle(
                  s.pmLockPreset ? Icons.lock : Icons.lock_open,
                  // H, not L: L opens the preset picker. The two were swapped
                  // here, so the tooltip taught the wrong key.
                  _withKeyHint(
                      s.pmLockPreset ? l10n.pmUnlockAction : l10n.pmLockAction,
                      'H'),
                  () => s.pmLockPreset = !s.pmLockPreset),
              // Shuffle vs. in-order: both states are a real choice, and the
              // icon itself says which one is on.
              toggle(
                  _pmOrderIcon(s.pmRandomNext),
                  _withKeyHint(
                      s.pmRandomNext
                          ? l10n.pmOrderSequential
                          : l10n.pmOrderRandom,
                      'S'),
                  () => s.pmRandomNext = !s.pmRandomNext),
            ]);
          },
        ),
      ],
    );
  }

  /// Compact source sheet: switch what projectM plays WITHOUT leaving the viz.
  /// The swap is applied by the render thread — no teardown, blend transition.
  /// Quick picker over the presets of the source ALREADY playing: a filter box
  /// and the list, tap to jump. Deliberately not the preset SCREEN (that one
  /// installs, imports and curates, and leaving the player to reach it loses
  /// the visualizer); and deliberately [PresetManager.previewPreset], which
  /// plays the pick WITHOUT narrowing the source to it, so next/prev keep
  /// walking the whole list afterwards.
  Future<void> _showPmPresetPicker() async {
    final l10n = context.l10n;
    final pm = PresetManager.instance;
    final paths = await pm.resolveSource(pm.activeSource);
    if (!mounted) return;
    // A source that resolves to nothing used to make this button do NOTHING —
    // no sheet, no message, indistinguishable from a dead control. It happens
    // for real: the persisted source can name a pack that has since been
    // uninstalled. Say so instead.
    if (paths.isEmpty) {
      AppSnack.show(context, l10n.searchNoResults);
      return;
    }

    final current = widget.audio.projectmPresetPath;
    // The filter state belongs to a STATEFUL WIDGET, not to this closure and not
    // to a StatefulBuilder's setter. `_BottomSheetState.build` calls
    // `widget.builder(context)` again on every rebuild of the sheet - the
    // keyboard coming and going is one - so anything declared inside that
    // closure is re-created, i.e. silently reset. That is what made the filter
    // "switch itself off" on iOS: dismissing the keyboard by tapping a row, or
    // with its search/return key, brought the unfiltered list back - and for the
    // tap it was worse, the list changing UNDER the finger between down and up so
    // the release landed on whatever row had taken that place, selecting a preset
    // nobody aimed at. A State survives those rebuilds (same widget type at the
    // same position → same element), and it also owns the controller's lifetime,
    // which a `dispose()` after the await cannot: the sheet stays mounted through
    // its closing animation, and rebuilding a TextField on a disposed controller
    // asserts.
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,   // the list wants the height; a filter needs it
      builder: (sheetCtx) => _PmPresetPickerSheet(
        paths: paths,
        current: current,
        hintText: l10n.pmPickFilter,
      ),
    );
    if (picked == null || !mounted) return;
    await pm.previewPreset(picked);
  }

  Future<void> _showPmSourceSheet() async {
    final l10n = context.l10n;
    final pm = PresetManager.instance;
    final packs = pm.installedPacks();
    final hasUser = pm.hasUserPresets;
    final playlists = await LocalDb.instance.pmPlaylists();
    if (!mounted) return;
    final active = pm.activeSource;

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        Widget tile(String source, IconData icon, String label,
                {String? subtitle}) =>
            ListTile(
              leading: Icon(icon),
              title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: subtitle == null ? null : Text(subtitle),
              trailing: source == active
                  ? Icon(Icons.check, color: Theme.of(sheetCtx).colorScheme.primary)
                  : null,
              onTap: () => Navigator.of(sheetCtx).pop(source),
            );
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              tile('bundled', Icons.auto_awesome, l10n.pmSourceBundled),
              for (final (slug, name) in packs)
                tile('pack:$slug', Icons.inventory_2_outlined, name),
              if (hasUser)
                tile('user', Icons.folder_outlined, l10n.pmSourceImports),
              for (final pl in playlists)
                tile('plist:${pl.id}', Icons.queue_music, pl.name,
                    subtitle: l10n.pmPresetCount(pl.itemCount)),
              if (packs.isNotEmpty || hasUser || playlists.isNotEmpty)
                tile('all', Icons.all_inclusive, l10n.pmSourceAll),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.tune),
                title: Text(l10n.pmManagePresets),
                onTap: () => Navigator.of(sheetCtx).pop('__manage__'),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    if (picked == '__manage__') {
      // Through the shell, not the root navigator: it lands on the active tab,
      // which keeps the mini player and the bottom bar visible over it.
      final open = globalOnOpenPresets;
      if (open != null) {
        open();
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PresetScreen()),
        );
      }
      return;
    }
    await pm.applySource(picked);
  }

  /// Adds the CURRENT preset to a local preset playlist (picked or created).
  Future<void> _addCurrentPresetToPlaylist() async {
    final l10n = context.l10n;
    final pm = PresetManager.instance;
    final abs = widget.audio.projectmPresetPath;
    if (abs.isEmpty) return;
    final rel = pm.relOf(abs);
    final playlists = await LocalDb.instance.pmPlaylists();
    if (!mounted) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final pl in playlists)
              ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(pl.name),
                subtitle: Text(l10n.pmPresetCount(pl.itemCount)),
                onTap: () => Navigator.of(sheetCtx).pop(pl.id),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.pmNewPlaylist),
              onTap: () => Navigator.of(sheetCtx).pop('__new__'),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;

    var playlistId = picked;
    if (picked == '__new__') {
      final name = await promptPmPlaylistName(context, l10n);
      if (name == null || name.isEmpty || !mounted) return;
      playlistId = await LocalDb.instance.createPmPlaylist(name);
    }
    final base = abs.split('/').last;
    final display =
        base.toLowerCase().endsWith('.milk') ? base.substring(0, base.length - 5) : base;
    final ids = await LocalDb.instance.pmPresetIdsForPaths([rel]);
    final added = await LocalDb.instance.addPmPlaylistItem(playlistId,
        path: rel, presetId: ids[rel], name: display);
    if (!mounted) return;
    AppSnack.show(
        context, added ? l10n.pmAddedToPlaylist : l10n.pmAlreadyInPlaylist);
  }

  Widget _fsButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: IconButton(
        iconSize: 20,
        color: Colors.white,
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _vizButton(VizEffect e, AppLocalizations l10n, ColorScheme cs) {
    final active = _effective == e;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Tooltip(
        message: e.labelOf(l10n),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () { _select(e); _dismissOverlay(); },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: active
                    ? cs.primary
                    : cs.surface.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                border: active
                    ? null
                    : Border.all(
                        color: cs.outline.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
              ),
              child: Center(
                child: e.iconAt(
                  size: 22,
                  color: active
                      ? cs.onPrimary
                      : cs.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Pattern-viz overlay controls (top-left): scroll mode, volume bars, and the
  /// tracker color-scheme picker. Persisted in UserSettings; PatternScopeWidget
  /// listens and repaints. Tooltips are localized; preset names are tracker
  /// product proper nouns (not localized, like 'projectM').
  /// Spectrum: the four palettes, top-left, same shape as the pattern controls.
  /// They existed only in Settings → Visualisation → Colors, which is a long
  /// way from the thing they change — and a look is picked by looking at it.
  Widget _spectrumControls(AppLocalizations l10n, ColorScheme cs) {
    return ListenableBuilder(
      listenable: UserSettings.instance,
      builder: (context, _) {
        final s = UserSettings.instance;
        final idle = Colors.white.withValues(alpha: 0.85);
        const activeColor = Color(0xFF5AD1FF);
        Widget btn(int value, IconData icon, String tooltip) => Tooltip(
              message: tooltip,
              child: InkResponse(
                onTap: () => s.spectrumPalette = value,
                radius: 22,
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Icon(icon,
                      size: 20,
                      color: s.spectrumPalette == value ? activeColor : idle),
                ),
              ),
            );
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              btn(0, Icons.equalizer,      l10n.settingsSpectrumModeStandard),
              btn(1, Icons.gradient,       l10n.settingsSpectrumModeColored),
              btn(2, Icons.blur_linear,    l10n.settingsSpectrumModeBeam),
              btn(3, Icons.show_chart,     l10n.settingsSpectrumModeLine),
              btn(4, Icons.blur_circular,  l10n.settingsSpectrumModeRing),
            ],
          ),
        );
      },
    );
  }

  Widget _patternControls(AppLocalizations l10n, ColorScheme cs) {
    return ListenableBuilder(
      listenable: UserSettings.instance,
      builder: (context, _) {
        final s = UserSettings.instance;
        final idle = Colors.white.withValues(alpha: 0.85);
        // Active option: a bright accent, NOT cs.primary (deep purple, nearly
        // invisible on the dark tracker background).
        const activeColor = Color(0xFF5AD1FF);
        Widget btn({
          required IconData icon,
          required String tooltip,
          required bool active,
          required VoidCallback onTap,
        }) =>
            Tooltip(
              message: tooltip,
              child: InkResponse(
                onTap: onTap,
                radius: 22,
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Icon(icon, size: 20, color: active ? activeColor : idle),
                ),
              ),
            );
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scroll mode + volume bars apply only to a NATIVE tracker grid.
              // A synthesized grid (no real pattern data) has neither a page to
              // scroll nor per-cell volumes — the renderer forces bar-fixed /
              // volume-off there (see PatternScopeWidget._pushGlOptions), so the
              // controls are hidden rather than shown as dead toggles.
              // Smooth (sub-row) scrolling works for BOTH synth and native
              // patterns, so it stays outside the patternSupported gate below.
              btn(
                icon: Icons.animation,
                tooltip: l10n.patternSmoothScroll,
                active: s.patternSmoothScroll,
                onTap: () =>
                    s.patternSmoothScroll = !s.patternSmoothScroll,
              ),
              // Opaque background: like smooth scrolling, it applies to a
              // synthesized grid too, so it stays outside the patternSupported
              // gate. Active = the cover art is hidden behind the grid.
              btn(
                icon: s.patternOpaqueBg
                    ? Icons.hide_image
                    : Icons.image_outlined,
                tooltip: l10n.patternOpaqueBg,
                active: s.patternOpaqueBg,
                onTap: () => s.patternOpaqueBg = !s.patternOpaqueBg,
              ),
              if (widget.audio.patternSupported) ...[
                // A style that PINS the bar (ProTracker) makes this toggle a
                // no-op — the renderer forces the fixed bar — so it is hidden
                // rather than shown dead, exactly like the synth-grid case.
                if (!PatternPalette.selectedPinsBar(s.patternPalette))
                  btn(
                    icon: s.patternScrollMode == 1
                        ? Icons.swap_vert
                        : Icons.vertical_align_center,
                    tooltip: l10n.patternScrollMode,
                    active: s.patternScrollMode == 1,
                    onTap: () =>
                        s.patternScrollMode = s.patternScrollMode == 1 ? 0 : 1,
                  ),
                btn(
                  icon: Icons.equalizer,
                  tooltip: l10n.patternVolumeBars,
                  active: s.patternShowVolume,
                  onTap: () => s.patternShowVolume = !s.patternShowVolume,
                ),
              ],
              Tooltip(
                message: l10n.patternSize,
                child: PopupMenuButton<int>(
                  padding: const EdgeInsets.all(7),
                  iconSize: 20,
                  icon: Icon(Icons.format_size,
                      color: s.patternSizeIndex > 0 ? activeColor : idle),
                  initialValue: s.patternSizeIndex,
                  onSelected: (v) => s.patternSizeIndex = v,
                  itemBuilder: (context) => [
                    for (int i = 0;
                        i < UserSettings.patternSizeValues.length; i++)
                      PopupMenuItem<int>(
                        value: i,
                        child: Text(
                            '×${UserSettings.patternSizeValues[i].toString().replaceAll('.0', '')}'),
                      ),
                  ],
                ),
              ),
              Tooltip(
                message: l10n.patternColumns,
                child: PopupMenuButton<int>(
                  padding: const EdgeInsets.all(7),
                  iconSize: 20,
                  icon: Icon(Icons.view_column,
                      color: s.patternColumns > 0 ? activeColor : idle),
                  initialValue: s.patternColumns,
                  onSelected: (v) => s.patternColumns = v,
                  itemBuilder: (context) => [
                    PopupMenuItem<int>(
                        value: 0, child: Text(l10n.patternColumnsAll)),
                    PopupMenuItem<int>(
                        value: 1, child: Text(l10n.patternColumnsNoteInstr)),
                    PopupMenuItem<int>(
                        value: 2, child: Text(l10n.patternColumnsNote)),
                  ],
                ),
              ),
              Tooltip(
                message: l10n.patternColorScheme,
                child: PopupMenuButton<int>(
                  padding: const EdgeInsets.all(7),
                  iconSize: 20,
                  icon: Icon(Icons.palette, color: idle),
                  initialValue: s.patternPalette,
                  onSelected: (v) => s.patternPalette = v,
                  itemBuilder: (context) => [
                    for (int i = 0; i < PatternPalette.presets.length; i++)
                      PopupMenuItem<int>(
                        value: i,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: PatternPalette.presets[i].note,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(PatternPalette.presets[i].name),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;

    Widget effectWidget;
    switch (_effective) {
      case VizEffect.stereo:
        effectWidget = OscilloscopeWidget(
          audio:      widget.audio,
          height:     widget.height,
          fillHeight: widget.fillHeight,
        );
      case VizEffect.spectrum:
        effectWidget = SpectrumWidget(
          audio:      widget.audio,
          height:     widget.height,
          fillHeight: widget.fillHeight,
        );
      case VizEffect.voices:
        effectWidget = ChannelScopeWidget(
          audio:      widget.audio,
          fillHeight: widget.fillHeight,
          rowHeight:  widget.fillHeight ? 44 : (widget.height / 4).clamp(24, 80),
        );
      case VizEffect.notes:
        effectWidget = NotesScopeWidget(audio: widget.audio);
      case VizEffect.patterns:
        effectWidget = PatternScopeWidget(
          audio:    widget.audio,
          trackKey: widget.artworkLocalFilePath,
        );
      case VizEffect.projectm:
        effectWidget = ProjectMWidget(audio: widget.audio);
    }

    final overlayButtons = Stack(
      children: [
        if (widget.isFullscreen && widget.fullscreenControls != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: widget.fullscreenControls,
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            // Fullscreen hides the player chrome, so PlayerScreen draws the
            // transport controls over the very bottom of the viz — sit above
            // them rather than under them.
            padding: EdgeInsets.only(bottom: widget.isFullscreen ? 76 : 10),
            // Wrap, not Row: five 58-pixel buttons need ~290 px, and the viz
            // panel is as narrow as the window gets (a resized desktop window,
            // a phone in portrait with the panel inset). A Row simply overflows
            // and the last modes become unreachable; this stacks them instead.
            child: Wrap(
              alignment: WrapAlignment.center,
              runSpacing: 6,
              // Only the modes this track can actually feed — see
              // _availableFor. A stream with no chip channels (vgmstream, mp3/
              // ogg/flac via miniaudio) leaves stereo (+ projectM) only.
              children: VizEffect.values
                  .where(_availableFor)
                  .map((e) => _vizButton(e, l10n, cs))
                  .toList(),
            ),
          ),
        ),
        // Window buttons, top-right, stacked: close (back to the artwork) on
        // top, fullscreen right under it. Fullscreen used to sit bottom-right,
        // where it shared the bottom edge with the viz selector and, in
        // fullscreen, with the transport controls. Double-tap on the viz and
        // Escape still do the same thing.
        if (widget.onClose != null || widget.onToggleFullscreen != null)
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onClose != null)
                    _fsButton(
                      icon: Icons.close,
                      tooltip: l10n.vizClose,
                      onPressed: widget.onClose!,
                    ),
                  if (widget.onClose != null &&
                      widget.onToggleFullscreen != null)
                    const SizedBox(height: 6),
                  if (widget.onToggleFullscreen != null)
                    _fsButton(
                      icon: widget.isFullscreen
                          ? Icons.fullscreen_exit
                          : Icons.fullscreen,
                      tooltip: widget.isFullscreen
                          ? l10n.vizExitFullscreen
                          : l10n.vizFullscreen,
                      onPressed: widget.onToggleFullscreen!,
                    ),
                ],
              ),
            ),
          ),
        // Per-visualizer controls. projectM: previous/next preset, centred
        // vertically on each edge (history-aware; random/blend behaviour set in
        // Settings → Visualisation).
        if (_effective == VizEffect.projectm) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _presetArrow(
                icon: Icons.arrow_left,
                tooltip: _withKeyHint(l10n.vizPrevPreset, 'P'),
                onPressed: widget.audio.projectmPrevPreset,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _presetArrow(
                icon: Icons.arrow_right,
                tooltip: _withKeyHint(l10n.vizNextPreset, 'N'),
                onPressed: widget.audio.projectmNextPreset,
              ),
            ),
          ),
          // Preset SOURCE switcher + add-current-to-playlist, top-left (the
          // per-viz controls corner). Only when the native build carries the
          // playlist API.
          if (widget.audio.hasProjectMPlaylist)
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _pmControls(l10n, cs),
              ),
            ),
        ],
        // Spectrum viz: the palette, top-left (same corner as the pattern's).
        if (_effective == VizEffect.spectrum)
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _spectrumControls(l10n, cs),
            ),
          ),
        // Pattern viz: scroll-mode / volume-bars / color-scheme, top-left.
        if (_effective == VizEffect.patterns)
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _patternControls(l10n, cs),
            ),
          ),
      ],
    );

    // The double-tap (fullscreen) detector wraps ONLY the visualizer surface —
    // NOT the controls.
    //
    // DoubleTapGestureRecognizer HOLDS the gesture arena while it waits to see
    // whether a second tap is coming, so no child tap can win until that ~300 ms
    // timeout expires. With the buttons inside it, every visualizer choice was
    // delayed by a third of a second before it was even dispatched — which is
    // why the switch felt sluggish while the work it triggers takes ~4 ms, and
    // why the show/hide button (outside this subtree) always felt instant.
    //
    // As a sibling ABOVE it in the Stack, the controls are hit-tested first and
    // absorb the tap, so it never enters that arena at all.
    // Rounded corners: see VizSelectorWidget.borderRadius. Never while
    // fullscreen — the surface is edge-to-edge there and a radius would just
    // notch the screen corners.
    final radius = widget.isFullscreen ? 0.0 : widget.borderRadius;
    final roundOnAndroid = radius > 0 && Platform.isAndroid;
    final roundByClip    = radius > 0 && !Platform.isAndroid;

    final vizStack = Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _showOverlay,
            onDoubleTap: widget.onToggleFullscreen,
            // The clip must wrap the BLACK BACKDROP too, not just the texture —
            // clipping the texture alone would leave square black corners under
            // its rounded ones.
            child: _maybeClip(
              round: roundByClip,
              radius: radius,
              child: Stack(
              children: [
                // The GL texture clears to transparent (so the artwork quad can
                // blend at its configured opacity); without an opaque backdrop
                // the gaps showed the app theme's surface colour through —
                // washed out and low-contrast in light mode. Visualizers always
                // read best on black regardless of theme, so pin it here rather
                // than following cs.surface.
                const Positioned.fill(child: ColoredBox(color: Colors.black)),
                Positioned.fill(child: effectWidget),
                // Pointer feed for projectM's "mouse" uniform. A SIBLING above
                // the surface, never its parent: on Android the visualizer is a
                // PlatformView and the SurfaceView takes the touches first, so a
                // parent detector would see nothing at all.
                if (_effective == VizEffect.projectm && widget.audio.hasProjectM)
                  Positioned.fill(child: _pmPointerLayer()),
                // Android only: wedges painted over the opaque SurfaceView.
                if (roundOnAndroid)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _VizCornerPainter(
                          radius: radius,
                          color: widget.cornerBackdrop ?? Colors.black,
                        ),
                      ),
                    ),
                  ),
              ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _fadeCtrl,
            builder: (_, child) => IgnorePointer(
              ignoring: _fadeCtrl.value < 0.05,
              child: child,
            ),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: overlayButtons,
            ),
          ),
        ),
        // projectM preset banner: ONE widget for both the change-flash and the
        // tap-reveal (its opacity is the max of the two), so the two can never
        // draw superposed. Outside the fade overlay for the same reason as the
        // track-info card below: a preset change must reveal it on its own.
        if (_effective == VizEffect.projectm)
          Positioned(
            left: 72,
            right: 72,
            top: 10,
            child: IgnorePointer(
              child: Center(
                child:
                    _PmPresetBanner(audio: widget.audio, reveal: _fadeAnim),
              ),
            ),
          ),
        // Keyboard state feedback. Centred and short-lived, like a volume OSD:
        // it says WHAT the state is now (closed padlock = locked, dice = random
        // presets), not what the key did. Icon only — a padlock is a padlock in
        // every locale, and the existing strings name the ACTION ("unlock"),
        // which would read as the opposite of the state being shown.
        if (_effective == VizEffect.projectm)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: FadeTransition(
                  opacity: _stateFlashCtrl,
                  child: ListenableBuilder(
                    listenable: UserSettings.instance,
                    builder: (context, _) {
                      final settings = UserSettings.instance;
                      // "on" = the second of the two states, not a highlight:
                      // locked for the padlock, random for the order.
                      final on = _stateFlash == _VizFlash.lock
                          ? settings.pmLockPreset
                          : settings.pmRandomNext;
                      final IconData icon;
                      switch (_stateFlash) {
                        case _VizFlash.lock:
                          icon = on ? Icons.lock : Icons.lock_open;
                        case _VizFlash.presetOrder:
                          icon = _pmOrderIcon(on);
                      }
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          icon,
                          size: 40,
                          // One colour whatever the state: the GLYPH carries it
                          // (open vs closed padlock, dice vs arrow), and the
                          // buttons this badge doubles are not tinted either.
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        // Track-info card: last in the Stack so it draws above everything, and
        // outside the fade overlay so a track change reveals it on its own.
        // Bottom-LEFT, lifted clear of the two bottomCenter rows below it (the
        // transport pill at 8 and the viz selector at 76 + its ~34 pt height).
        if (widget.isFullscreen && widget.fullscreenTrackInfo != null)
          Positioned(
            left: 12,
            bottom: 120,
            // The reveal scope lets the card surface with the SAME tap that
            // reveals the controls (its opacity maxes the two signals).
            child: VizOverlayReveal(
              animation: _fadeAnim,
              child: widget.fullscreenTrackInfo!,
            ),
          ),
      ],
    );

    // Pointer activity feeds the auto-hide countdown. MouseRegion catches the
    // desktop hover (no button held); the Listener catches moves made WITH a
    // button down, i.e. a drag — zooming the notes viz with the right button
    // must not let the controls fade out mid-gesture. Both are outside the
    // gesture arena, so the double-tap, the skip swipe and the dismiss drag are
    // untouched.
    final pointerAware = MouseRegion(
      opaque: false,
      onHover: (_) => _pokeOverlay(),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerMove: (_) => _pokeOverlay(),
        child: vizStack,
      ),
    );

    if (widget.fillHeight) return pointerAware;
    return SizedBox(height: widget.height, child: pointerAware);
  }
}

/// Rounds the visualizer on the platforms where a Flutter clip actually bites
/// (everything except Android — see VizSelectorWidget.borderRadius).
/// Clip.antiAlias, deliberately NOT antiAliasWithSaveLayer: the latter pushes
/// an offscreen layer every frame, which is exactly the cost this whole
/// approach exists to avoid.
Widget _maybeClip({
  required bool round,
  required double radius,
  required Widget child,
}) {
  if (!round) return child;
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

/// Android: four corner wedges painted OVER the opaque SurfaceView, which no
/// Flutter clip can reach (SurfaceFlinger composites it as its own layer).
/// One even-odd path, four small arcs — no layer, no GL involvement.
class _VizCornerPainter extends CustomPainter {
  final double radius;
  final Color  color;

  const _VizCornerPainter({required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    canvas.drawPath(path, Paint()..color = color..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_VizCornerPainter old) =>
      old.radius != radius || old.color != color;
}

/// Exposes the tap-overlay's reveal animation to widgets hosted OVER the viz
/// (the fullscreen track card): they can surface with the same tap without
/// being inside the fade-gated overlay subtree.
class VizOverlayReveal extends InheritedWidget {
  final Animation<double> animation;
  const VizOverlayReveal(
      {super.key, required this.animation, required super.child});

  static Animation<double>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<VizOverlayReveal>()
      ?.animation;

  @override
  bool updateShouldNotify(VizOverlayReveal old) => old.animation != animation;
}

/// Subtitle-style outlined text (thin black stroke UNDER a white fill):
/// readable over a near-white visualizer frame without boxing the label in a
/// dark pill. Two stacked Texts — the stroke one first, the fill on top.
/// Shared by the projectM preset banner and the fullscreen track card.
class OutlinedVizText extends StatelessWidget {
  final String text;
  final double size;
  final FontWeight weight;
  final double fillAlpha;
  final int maxLines;
  final TextAlign align;

  const OutlinedVizText(
    this.text, {
    super.key,
    required this.size,
    this.weight = FontWeight.w500,
    this.fillAlpha = 1,
    this.maxLines = 1,
    this.align = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: 0.2,
      height: 1.25,
    );
    return Stack(
      children: [
        Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size / 5
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.black.withValues(alpha: 0.85),
          ),
        ),
        Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: base.copyWith(
            color: Colors.white.withValues(alpha: fillAlpha),
            shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
          ),
        ),
      ],
    );
  }
}

/// THE preset name display for projectM — the change-flash (3 s hold) and the
/// tap-overlay reveal go through this one widget: its opacity is the MAX of
/// the flash animation and the overlay's reveal animation, so the two paths
/// can never draw two labels superposed. Dark pill behind the text: a preset
/// can render a near-white frame, drop shadows alone were not enough.
/// The projectM preset picker's content: a filter field over the preset list.
///
/// A widget with a State, deliberately: the modal sheet re-runs its `builder`
/// on every rebuild (the keyboard is one), so filter state kept in that closure
/// is reset without a sound — while a State, attached to the element tree,
/// survives. It also owns the controller for exactly as long as the sheet is
/// mounted, closing animation included.
class _PmPresetPickerSheet extends StatefulWidget {
  const _PmPresetPickerSheet({
    required this.paths,
    required this.current,
    required this.hintText,
  });

  final List<String> paths;
  final String? current;
  final String hintText;

  @override
  State<_PmPresetPickerSheet> createState() => _PmPresetPickerSheetState();
}

class _PmPresetPickerSheetState extends State<_PmPresetPickerSheet> {
  final TextEditingController _filter = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // A controller rather than onChanged alone, so the field's text and the
    // filter cannot drift apart across the sheet's rebuilds.
    _filter.addListener(() {
      if (_filter.text != _query) setState(() => _query = _filter.text);
    });
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needle = _query.trim().toLowerCase();
    final shown = needle.isEmpty
        ? widget.paths
        : [
            for (final path in widget.paths)
              if (p.basenameWithoutExtension(path).toLowerCase().contains(needle))
                path,
          ];
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _filter,
              autofocus: true,
              // The list filters as you type, so the search key has nothing left
              // to do: keep the results up and let it dismiss the keyboard.
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: widget.hintText,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: shown.length,
              itemBuilder: (_, i) {
                final path = shown[i];
                final isCurrent = path == widget.current;
                return ListTile(
                  dense: true,
                  leading: Icon(
                    isCurrent ? Icons.play_arrow : Icons.auto_awesome_outlined,
                    size: 20,
                  ),
                  title: Text(
                    p.basenameWithoutExtension(path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isCurrent
                        ? const TextStyle(fontWeight: FontWeight.w600)
                        : null,
                  ),
                  onTap: () => Navigator.of(context).pop(path),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PmPresetBanner extends StatefulWidget {
  final RewampAudio audio;
  final Animation<double> reveal; // the tap overlay's fade
  const _PmPresetBanner({required this.audio, required this.reveal});

  @override
  State<_PmPresetBanner> createState() => _PmPresetBannerState();
}

class _PmPresetBannerState extends State<_PmPresetBanner>
    with SingleTickerProviderStateMixin {
  static const _kHold = Duration(seconds: 3);
  // The viz takes a moment to produce its first frames and fade in — hold the
  // activation flash back so it isn't wasted on the still-black backdrop.
  static const _kActivationDelay = Duration(milliseconds: 800);

  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    reverseDuration: const Duration(milliseconds: 500),
  );
  Timer? _poll, _hold, _activation;
  int _serial = -1;
  String _name = '';
  bool _usesMouse = false;
  String _kind = '';
  String? _packName;
  String? _subDir;

  @override
  void initState() {
    super.initState();
    _refresh(flash: false);
    _activation = Timer(_kActivationDelay, _doFlash);
    // Poll: there is no native preset-change callback. One FFI int per tick.
    _poll = Timer.periodic(
        const Duration(milliseconds: 300), (_) => _refresh(flash: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _hold?.cancel();
    _activation?.cancel();
    _flash.dispose();
    super.dispose();
  }

  void _refresh({required bool flash}) {
    final s = widget.audio.projectmPresetSerial;
    if (s == _serial) return;
    _serial = s;
    final path = widget.audio.projectmPresetPath;
    // This poll is the only place a preset change is observed at all — there is
    // no native callback, and the engine rotates presets on its own — so it is
    // also where "what was on screen last" gets remembered for the next run.
    PresetManager.instance.rememberCurrentPreset(path);
    final (kind, packName, subDir) =
        PresetManager.instance.sourceOfPath(path);
    if (!mounted) return;
    setState(() {
      _name = widget.audio.projectmPresetName;
      _usesMouse = widget.audio.projectmPresetUsesMouse;
      _kind = kind;
      _packName = packName;
      _subDir = subDir;
    });
    if (flash) _doFlash();
  }

  void _doFlash() {
    if (_name.isEmpty || !mounted) return;
    _flash.forward();
    _hold?.cancel();
    _hold = Timer(_kHold, () {
      if (mounted) _flash.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_name.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    var subtitle = switch (_kind) {
      'pack'    => _packName,
      'bundled' => l10n.pmSourceBundled,
      'user'    => l10n.pmSourceImports,
      // A one-off download names the pack it BELONGS to — that is the pack to
      // install if this preset is a keeper. Falls back to the generic label
      // when the row carried no pack.
      'single'  => _packName != null
          ? l10n.pmAvailableIn(_packName!)
          : l10n.pmSingleDownloads,
      _         => null,
    };
    // Sub-folders locate the preset inside a 10 000-file tree.
    if (subtitle != null && _subDir != null && _packName != null) {
      subtitle = '$subtitle · $_subDir';
    }
    return AnimatedBuilder(
      animation: Listenable.merge([widget.reveal, _flash]),
      builder: (context, child) {
        final r = widget.reveal.value;
        final f = _flash.value;
        final o = r > f ? r : f;
        if (o < 0.01) return const SizedBox.shrink();
        return Opacity(opacity: o, child: child);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Only shown for presets that actually read the pointer: it says
              // "moving the mouse here does something", which is false for
              // almost every other preset. Rides the banner's own opacity, so
              // it appears and fades exactly with the name.
              if (_usesMouse) ...[
                const Icon(Icons.mouse, size: 13, color: Colors.white,
                    shadows: [Shadow(color: Colors.black, blurRadius: 3)]),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: OutlinedVizText(_name,
                    size: 13.5,
                    weight: FontWeight.w600,
                    maxLines: 2,
                    align: TextAlign.center),
              ),
            ],
          ),
          if (subtitle != null)
            OutlinedVizText(subtitle,
                size: 11,
                fillAlpha: 0.85,
                maxLines: 2,
                align: TextAlign.center),
        ],
      ),
    );
  }
}
