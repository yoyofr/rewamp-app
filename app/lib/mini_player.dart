import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'glass_chrome.dart';
import 'l10n.dart';
import 'mini_window.dart';
import 'mini_window_player.dart';
import 'player_controller.dart';
import 'transport_log.dart';
import 'artwork_image.dart';
import 'artwork_palette.dart';
import 'scrolling_text.dart';
import 'transport_buttons.dart';

class MiniPlayer extends StatefulWidget {
  final PlayerController controller;
  final VoidCallback onTap;
  final bool isSidebar;
  final bool queueActive;
  final VoidCallback? onToggleQueue;

  /// The full player's open/close animation, OWNED BY THE HOST (AppShell) —
  /// the swipe drives it straight, so what rises under the finger is the real
  /// player, not a stand-in.
  ///
  /// It has to work this way: a route CANNOT be pushed mid-drag — pushing any
  /// route, modal or not, cancels the in-flight pointer
  /// (`DragGestureRecognizer._giveUpPointer` on the `PointerCancelEvent`), so
  /// the finger stops being reported and the transition freezes one frame in.
  /// Measured on a standalone harness: 3 move events after a push, 0 more;
  /// 43 with no route involved. Null (desktop sidebar) falls back to [onTap].
  final AnimationController? playerOpenController;

  /// Mounts the player before the first frame of the drag, so there is
  /// something for [playerOpenController] to move.
  final VoidCallback? onDragOpenBegin;

  /// The finger is off. Paired with [onDragOpenBegin] so the host knows a drag
  /// still OWNS the player: the value passing through 0 mid-gesture (drag up,
  /// come back down, go up again) must not be read as "closed".
  final VoidCallback? onDragOpenEnd;

  const MiniPlayer({
    super.key,
    required this.controller,
    required this.onTap,
    this.isSidebar = false,
    this.queueActive = false,
    this.onToggleQueue,
    this.playerOpenController,
    this.onDragOpenBegin,
    this.onDragOpenEnd,
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  /// A swipe-up is under way and the finger is still down.
  bool _dragOpening = false;
  double _dragTravel = 0;
  double _dragHeight = 1;

  // A skip needs a deliberate horizontal move: 48 px, or a flick. Same
  // threshold as the player screen's own skip swipe, so the two read alike.
  static const double _kSkipDistance = 48;
  static const double _kSkipVelocity = 320;

  /// Above this (px/s) the release is a FLICK and its direction decides,
  /// whatever distance was covered.
  static const double _kFlingVelocity = 300;

  /// How far up the player must have come, as a share of the screen, for a slow
  /// release to complete instead of falling back. The drag maps 1:1 onto the
  /// screen height (the player tracks the finger, which is the point), so a
  /// quarter is already a deliberate ~200 px pull on a phone.
  static const double _kOpenCommit = 0.25;

  void _onHorizontalEnd(DragEndDetails d) {
    final ctrl = widget.controller;
    final vx = d.primaryVelocity ?? 0;
    if (vx.abs() < _kSkipVelocity && _dragTravel.abs() < _kSkipDistance) return;
    // Swipe LEFT (negative) = the next track comes in from the right.
    final wantNext = (vx != 0 ? vx : -_dragTravel) < 0;
    // ⚠️ Le geste couvre TOUTE la bande du mini-lecteur, boutons compris: un
    // appui qui dérape de quelques pixels peut finir ici plutôt que sur pause.
    // C'est précisément ce que le journal doit pouvoir distinguer.
    logTransport(wantNext ? 'suivant' : 'précédent',
        source: 'glissement mini-lecteur',
        detail: 'v=${vx.toStringAsFixed(0)} px/s '
            'dist=${_dragTravel.toStringAsFixed(0)} px');
    if (wantNext) {
      if (ctrl.canGoNext) ctrl.goNext();
    } else {
      if (ctrl.canGoPrev) ctrl.goPrev();
    }
  }

  void _onVerticalUpdate(DragUpdateDetails d) {
    final ctrl = widget.playerOpenController;
    if (ctrl == null) return;
    _dragTravel += d.delta.dy;
    if (!_dragOpening) {
      // Only an UPWARD move opens, and only past the slop — otherwise every
      // stray touch would raise the player.
      if (_dragTravel > -kTouchSlop) return;
      _dragHeight = MediaQuery.sizeOf(context).height;
      _dragOpening = true;
      widget.onDragOpenBegin?.call();
      ctrl.value = 0;
    }
    ctrl.value = (-_dragTravel / _dragHeight).clamp(0.0, 1.0);
  }

  void _onVerticalCancel() {
    if (!_dragOpening) return;
    _dragOpening = false;
    widget.playerOpenController?.fling(velocity: -1);
    widget.onDragOpenEnd?.call();
  }

  void _onVerticalEnd(DragEndDetails d) {
    if (!_dragOpening) return;
    _dragOpening = false;
    final ctrl = widget.playerOpenController;
    if (ctrl == null) {
      widget.onDragOpenEnd?.call();
      return;
    }
    final vy = d.primaryVelocity ?? 0;
    // A flick decides on its own direction; otherwise distance does. Falling
    // back runs the same animation in reverse, and the host unmounts at 0.
    final settleOpen = vy < -_kFlingVelocity ||
        (vy < _kFlingVelocity && ctrl.value > _kOpenCommit);
    if (settleOpen) {
      ctrl.fling(velocity: 1);
    } else {
      ctrl.fling(velocity: -1);
    }
    // AFTER the fling is armed: the host unmounts on a value of 0, and it must
    // see the drag released before it is allowed to.
    widget.onDragOpenEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (!widget.controller.hasFile) return const SizedBox.shrink();
        final bar = _MiniPlayerBar(
          controller: widget.controller,
          onTap: widget.onTap,
          isSidebar: widget.isSidebar,
          queueActive: widget.queueActive,
          onToggleQueue: widget.onToggleQueue,
          // The queue panel also opens for a single-track play (it then shows a
          // one-entry stand-in) — gate on "something is loaded", not on the
          // controller queue, which a single-file play deliberately clears.
          hasQueue: widget.controller.hasFile,
        );
        // Desktop gets the same gestures. The bar there is wider and carries
        // the full transport, but it is still the handle onto the player, and
        // a trackpad swipe reads the same as a thumb. What differs is only
        // what the player pushes on the way up: there is no nav bar below it
        // (see _navBarPush, which is not even built on desktop).
        return GestureDetector(
          // Both axes on ONE detector: Flutter's arena then picks the dominant
          // one for us. Two separate detectors would have the vertical
          // recognizer claim a diagonal drag — it compares |dy| to the slop and
          // never to |dx| (the same trap the notes visualizer paid for).
          onHorizontalDragStart: (_) => _dragTravel = 0,
          onHorizontalDragUpdate: (d) => _dragTravel += d.delta.dx,
          onHorizontalDragEnd: _onHorizontalEnd,
          onVerticalDragStart: (_) => _dragTravel = 0,
          onVerticalDragUpdate: _onVerticalUpdate,
          onVerticalDragEnd: _onVerticalEnd,
          onVerticalDragCancel: _onVerticalCancel,
          child: bar,
        );
      },
    );
  }
}

/// Title + secondary line (album · 4/25) for the mini player.
class _TitleBlock extends StatelessWidget {
  final PlayerController controller;
  const _TitleBlock({required this.controller});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final album = controller.currentAlbum;
    final pos = controller.queuePositionLabel;
    final parts = <String>[
      if (album != null && album.isNotEmpty) album,
      if (pos != null) pos,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ScrollingText(
          text: controller.displayTitle,
          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        if (parts.isNotEmpty)
          ScrollingText(
            text: parts.join(' · '),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _MiniPlayerBar extends StatelessWidget {
  final PlayerController controller;
  final VoidCallback onTap;
  final bool isSidebar;
  final bool queueActive;
  final VoidCallback? onToggleQueue;
  final bool hasQueue;

  const _MiniPlayerBar({
    required this.controller,
    required this.onTap,
    required this.isSidebar,
    required this.queueActive,
    required this.onToggleQueue,
    required this.hasQueue,
  });

  // Transport hierarchy: play/pause dominates, skips follow, the shuffle/loop
  // toggles are secondary chrome.
  static const double _kPlayIconSize = 34;
  static const double _kSkipIconSize = 23;
  static const double _kToggleIconSize = 14;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = controller.duration > 0
        ? (controller.position / controller.duration).clamp(0.0, 1.0)
        : 0.0;

    // EXPÉRIMENTATION verre: la dalle devient transparente et c'est GlassChrome
    // qui porte le fond. `Material` reste (ripple de l'InkWell, élévation du
    // texte) mais en `transparent`, sinon il repeint par-dessus le verre.
    return GlassChrome(
      // Le mini-lecteur FLOTTE (il est décollé de la barre de navigation de
      // quelques pixels): ses quatre coins sont donc arrondis, pas seulement
      // ceux du haut comme sur une dalle plaquée en bas.
      borderRadius: BorderRadius.circular(26),
      child: Material(
        elevation: 0,
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onTap,
              child: Padding(
                // Dalle plus basse: la vignette et les marges verticales sont
                // ce qui donnait sa hauteur (44 + 2×8 + 2 px de progression).
                //
                // 4 px et non 5: la barre de progression vit maintenant DANS le
                // bloc pochette+titre et le rend 3 px plus haut. Voir le budget
                // de hauteur plus bas.
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    // TRANSPORT D'ABORD, à position FIXE.
                    //
                    // Il était à droite, donc sa position dépendait de la
                    // largeur restante: elle bougeait avec le titre, avec
                    // l'ouverture de la queue, avec la fenêtre. Un bouton de
                    // lecture doit être toujours au même endroit — c'est le
                    // seul de la barre qu'on vise sans regarder. Le TITRE prend
                    // désormais la largeur variable, et c'est lui qui cède.
                    //
                    // ⚠️ Le transport est INFLEXIBLE, et il ne doit surtout pas
                    // redevenir un `Flexible`. Un `Flexible` en fit LOOSE
                    // participe quand même au partage de la place libre: avec
                    // le titre en `Expanded` (flex 1 lui aussi), la moitié de
                    // l'espace lui était ALLOUÉE, il n'en prenait que sa
                    // largeur intrinsèque, et le reste — non redistribué —
                    // s'accumulait en fin de ligne. D'où l'espace VARIABLE à
                    // droite du bouton de queue, qui n'était donc jamais
                    // vraiment collé au bord.
                    //
                    // Corollaire: plus de `FittedBox(scaleDown)` non plus, il
                    // n'avait de sens qu'avec la contrainte que le `Flexible`
                    // lui donnait. La protection contre le débordement vient
                    // maintenant du titre (`Expanded`, qui cède jusqu'à 0) et
                    // du fait que le panneau de queue ne retranche PLUS sa
                    // largeur au mini-lecteur — la cause d'origine du
                    // « A RenderFlex overflowed by 1.00 pixels ».
                    IconButtonTheme(
                      data: IconButtonThemeData(
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          minimumSize: const Size(36, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ⚠️ Les boutons de saut sont TOUJOURS présents,
                          // `onPressed` nul quand l'action est indisponible —
                          // jamais insérés sous condition. Même règle que la
                          // rangée de transport du lecteur plein écran, qui
                          // l'avait payée la première et où elle est déjà
                          // appliquée: un enfant `if (canGoPrev)` DÉCALE toute
                          // la Row quand canGoPrev/canGoNext bascule, et si la
                          // bascule tombe pendant un appui, Flutter réapparie
                          // les IconButton non clés PAR POSITION — l'appui sur
                          // lecture déclenche alors le voisin (« je clique sur
                          // play, ça passe au morceau suivant », une fois,
                          // juste quand l'état de navigation de la queue se
                          // fixe). Le mini-lecteur était resté sur l'ancienne
                          // forme. Les clés rendent la règle STRUCTURELLE:
                          // l'appariement se fait par identité, donc même un
                          // voisin conditionnel (shuffle/loop, qui suivent la
                          // disposition) ne peut plus le faire glisser.
                          //
                          // Sidebar (desktop) gets the full transport:
                          // shuffle and loop frame the prev/play/next group.
                          if (isSidebar)
                            ShuffleButton(
                              key: const ValueKey('mp-shuffle'),
                              enabled: controller.shuffleEnabled,
                              onToggle: controller.toggleShuffle,
                              iconSize: _kToggleIconSize,
                            ),
                          // Prev in both layouts now (mirrors next), so the
                          // sidebar-less bar can go back a track too.
                          IconButton(
                            key: const ValueKey('mp-prev'),
                            iconSize: _kSkipIconSize,
                            icon: const Icon(Icons.fast_rewind),
                            onPressed:
                                controller.canGoPrev ? controller.goPrev : null,
                          ),
                          IconButton(
                            key: const ValueKey('mp-play'),
                            iconSize: _kPlayIconSize,
                            icon: Icon(
                              controller.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                            onPressed: () {
                              logTransport(
                                  controller.isPlaying ? 'pause' : 'lecture',
                                  source: 'bouton mini-lecteur',
                                  detail: 'jouait=${controller.isPlaying}');
                              controller.togglePlay();
                            },
                          ),
                          IconButton(
                            key: const ValueKey('mp-next'),
                            iconSize: _kSkipIconSize,
                            icon: const Icon(Icons.fast_forward),
                            onPressed: controller.canGoNext
                                ? () {
                                    logTransport('suivant',
                                        source: 'bouton mini-lecteur',
                                        detail: 'jouait=${controller.isPlaying}');
                                    controller.goNext();
                                  }
                                : null,
                          ),
                          if (isSidebar)
                            LoopButton(
                              key: const ValueKey('mp-loop'),
                              mode: controller.loopMode,
                              onCycle: controller.cycleLoopMode,
                              iconSize: _kToggleIconSize,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // ── Pochette + titre + progression, en COLONNE ──────────
                    //
                    // La barre est alignée sur la POCHETTE et le TITRE, pas sur
                    // la dalle: elle commence au bord gauche de la vignette et
                    // s'arrête où le titre s'arrête, sans courir sous le
                    // transport ni sous le bouton de queue. C'est la seule
                    // façon d'y arriver sans mesurer la largeur du transport —
                    // qui varie (les bascules shuffle/loop n'existent qu'en
                    // barre latérale).
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            ArtworkImage(
                              url: controller.artworkUrl,
                              // Ce qui JOUE ne fait pas la queue des vignettes:
                              // lancer un album depuis une grille de
                              // collection laissait la barre sur la pochette
                              // précédente le temps que la file d'hôte se
                              // vide. Voir ArtworkImage.priority.
                              priority: true,
                              artist: controller.currentArtist,
                              album: controller.currentAlbum,
                              localFilePath: controller.filePath,
                              targetDir: controller.artworkTargetDir,
                              size: 38,
                              borderRadius: BorderRadius.circular(6),
                              // Pre-warm the palette cache while the track plays in the
                              // bar, so the full player's tinted background is ready the
                              // moment the sheet opens (even on first play).
                              onImageResolved: ArtworkPalette.dominantColor,
                              // No placeholder override: themed per-platform fallback —
                              // but it needs the SIGNALS to pick a platform. Without
                              // them it fell back to the path's extension alone, so the
                              // bar showed the generic mark while the player right above
                              // it showed the Amiga one for the same track.
                              platformName: controller.currentPlatformName,
                              formatHint: controller.currentFormatExt,
                              engine: controller.audio.backendName,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TitleBlock(controller: controller),
                            ),
                          ]),
                          // ⚠️ BUDGET DE HAUTEUR: la dalle est posée dans un
                          // `Positioned(height: _kMiniPlayerHeight)` de 52 px —
                          // une constante dont dépend aussi la géométrie du vol
                          // de pochette à l'ouverture du lecteur. Ce bloc vaut
                          // 38 (vignette) + 2 + 3 = 43, et la marge verticale
                          // est passée de 5 à 4: 4 + 43 + 4 = 51, sous la
                          // borne. Ajouter ici sans reprendre là ferait
                          // déborder.
                          const SizedBox(height: 2),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(end: progress),
                            duration: const Duration(milliseconds: 230),
                            curve: Curves.linear,
                            builder: (_, v, __) => LinearProgressIndicator(
                              value: v,
                              minHeight: 3,
                              borderRadius: BorderRadius.circular(2),
                              color: cs.primary,
                              // Sur le verre, le fond par défaut disparaît
                              // selon ce qui passe derrière: un voile tiré de
                              // `onSurface` tient dans les deux thèmes.
                              backgroundColor:
                                  cs.onSurface.withValues(alpha: 0.22),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // La QUEUE est seule au bord droit, détachée du transport:
                    // elle n'est pas une commande de lecture (elle ouvre un
                    // panneau), et c'est le seul bouton dont la place doit
                    // suivre le bord de la barre, pas le groupe de transport.
                    // Bureau: bascule en mini lecteur — « depuis l'écran
                    // principal », sans avoir à ouvrir le lecteur d'abord.
                    if (isSidebar && MiniWindow.instance.available)
                      const MiniWindowButton(
                          key: ValueKey('mp-miniwin'), iconSize: 20),
                    if (isSidebar && hasQueue)
                      IconButton(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        constraints: const BoxConstraints.tightFor(
                            width: 36, height: 40),
                        icon: Icon(
                          queueActive
                              ? Icons.queue_music
                              : Icons.queue_music_outlined,
                          color: queueActive
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        tooltip: queueActive
                            ? context.l10n.miniPlayerHideQueue
                            : context.l10n.miniPlayerQueue,
                        onPressed: onToggleQueue,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
