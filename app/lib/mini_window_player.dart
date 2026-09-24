import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'artwork_image.dart';
import 'fullscreen_progress_line.dart';
import 'l10n.dart';
import 'mini_window.dart';
import 'player_controller.dart';
import 'player_screen.dart' show OutlinedGlyph;
import 'scrolling_text.dart';
import 'transport_buttons.dart';
import 'track_info_flash.dart';
import 'transport_log.dart';
import 'user_settings.dart';
import 'viz_selector_widget.dart';

/// Pose le mini lecteur PAR-DESSUS la coquille, qu'il met hors scène sans la
/// démonter.
///
/// ⚠️ **La forme de l'arbre est la MÊME dans les deux modes** (Offstage →
/// TickerMode → MediaQuery → OverflowBox → child): seuls les PARAMÈTRES
/// changent. Insérer ou retirer un étage selon le mode ferait changer le type
/// à cette profondeur — Flutter démonterait [child], c'est-à-dire AppShell et
/// avec lui la file de lecture.
///
/// Hors scène, la coquille garde la taille qu'avait la fenêtre principale
/// ([MiniWindow.frozenSize], imposée à la fois comme contrainte et comme
/// `MediaQuery.size` — AppShell choisit sa disposition bureau/téléphone sur
/// cette dernière). TickerMode coupe ses animations: un visualiseur resté
/// ouvert sous le mini lecteur ne dessine plus.
class MiniWindowHost extends StatelessWidget {
  /// Ce qui s'affiche en mode mini ([MiniWindowPlayer] dans l'app). Un widget
  /// et non un contrôleur: instancier un `PlayerController` appelle le natif,
  /// donc l'hôte ne serait pas testable.
  final Widget mini;
  final Widget child;

  const MiniWindowHost({
    super.key,
    required this.mini,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MiniWindow.instance,
      child: child,
      builder: (context, child) {
        final mw = MiniWindow.instance;
        final mini = mw.isMini;
        final frozen = mini ? mw.frozenSize : null;
        final mq = MediaQuery.of(context);
        // macOS: libellé traduit de l'entrée « Toujours au premier plan » du
        // menu Fenêtre (idempotent, ne part que s'il change — de langue).
        final menuTitle =
            AppLocalizations.of(context)?.settingsAlwaysOnTopTitle;
        if (menuTitle != null) mw.setMenuTitle(menuTitle);
        return CallbackShortcuts(
          bindings: {
            // Pas Cmd+M seul: c'est « réduire dans le Dock » sur macOS.
            const SingleActivator(LogicalKeyboardKey.keyM,
                meta: true, shift: true): () => _toggle(context),
            const SingleActivator(LogicalKeyboardKey.keyM,
                control: true, shift: true): () => _toggle(context),
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Offstage(
                offstage: mini,
                child: TickerMode(
                  enabled: !mini,
                  child: MediaQuery(
                    data: frozen == null ? mq : mq.copyWith(size: frozen),
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: frozen?.width,
                      maxWidth: frozen?.width,
                      minHeight: frozen?.height,
                      maxHeight: frozen?.height,
                      child: child,
                    ),
                  ),
                ),
              ),
              if (mini) this.mini,
            ],
          ),
        );
      },
    );
  }

  static void _toggle(BuildContext context) {
    if (!MiniWindow.instance.available) return;
    MiniWindow.instance.toggle(MediaQuery.sizeOf(context));
  }
}

/// Bouton d'ENTRÉE dans le mini lecteur — le même partout (barre du bureau,
/// lecteur plein écran), et absent là où le mode n'existe pas.
class MiniWindowButton extends StatelessWidget {
  final double? iconSize;
  final Color? color;
  const MiniWindowButton({super.key, this.iconSize, this.color});

  @override
  Widget build(BuildContext context) {
    if (!MiniWindow.instance.available) return const SizedBox.shrink();
    return IconButton(
      iconSize: iconSize,
      color: color,
      tooltip: context.l10n.miniWindowEnter,
      icon: const Icon(Icons.picture_in_picture_alt_outlined),
      // La taille de la fenêtre ENTIÈRE, pas celle d'un sous-arbre: c'est elle
      // que la coquille gelée doit garder. `View.of` plutôt que MediaQuery —
      // le lecteur plein écran vit sous un MediaQuery retouché.
      onPressed: () {
        final view = View.of(context);
        MiniWindow.instance
            .enter(view.physicalSize / view.devicePixelRatio);
      },
    );
  }
}

/// Le mini lecteur lui-même: pochette, titre, artiste · album, barre de seek,
/// transport. Toute la surface hors boutons DÉPLACE la fenêtre (la barre de
/// titre est masquée).
class MiniWindowPlayer extends StatefulWidget {
  final PlayerController controller;
  const MiniWindowPlayer({super.key, required this.controller});

  @override
  State<MiniWindowPlayer> createState() => _MiniWindowPlayerState();
}

class _MiniWindowPlayerState extends State<MiniWindowPlayer> {
  double? _seekDrag;

  static String _fmt(double s) {
    final t = s.toInt();
    return '${(t ~/ 60).toString().padLeft(2, '0')}:'
        '${(t % 60).toString().padLeft(2, '0')}';
  }

  /// Le visualiseur ne se monte qu'UNE FRAME APRÈS que le mode l'a demandé:
  /// celui du lecteur vient d'être retiré dans la même frame, et son `dispose`
  /// (qui désenregistre la texture GL) ne court qu'en fin de frame — donc après
  /// notre `initState` si on montait tout de suite. Voir MiniWindow.vizYield.
  bool _vizReady = false;

  @override
  void initState() {
    super.initState();
    MiniWindow.instance.addListener(_onModeChanged);
    widget.controller.addListener(_onTrackMaybeChanged);
    _armViz();
  }

  String? _trackKey;
  void _onTrackMaybeChanged() {
    final c = widget.controller;
    final k = '${c.filePath}|${c.artworkUrl}';
    if (k == _trackKey || !mounted) return;
    _trackKey = k;
    if (MiniWindow.instance.vizMode) setState(() {});
  }

  @override
  void dispose() {
    MiniWindow.instance.removeListener(_onModeChanged);
    widget.controller.removeListener(_onTrackMaybeChanged);
    super.dispose();
  }

  void _onModeChanged() {
    if (!mounted) return;
    setState(_armViz);
  }

  void _armViz() {
    if (!MiniWindow.instance.vizMode) {
      _vizReady = false;
      return;
    }
    if (_vizReady) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && MiniWindow.instance.vizMode) {
        setState(() => _vizReady = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MiniWindow.instance.vizMode
        ? _buildViz(context)
        : _buildCompact(context);
  }

  // ── Mode visualiseur ─────────────────────────────────────────────────────
  // Le visualiseur « comme en plein écran »: bord à bord, sélecteur de mode,
  // transport et commandes de fenêtre dans le voile tap-pour-révéler.
  Widget _buildViz(BuildContext context) {
    final c = widget.controller;
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_vizReady)
            // ⚠️ PAS de ListenableBuilder sur le contrôleur ici: il tique toutes
            // les 250 ms, et reconstruire le visualiseur à ce rythme est
            // exactement ce que PlayerScreen évite. La pochette de fond suit la
            // PISTE par `_onTrackMaybeChanged` (setState au changement seul).
            Builder(
              builder: (_) => VizSelectorWidget(
                audio: c.audio,
                fillHeight: true,
                artworkUrl: c.artworkUrl,
                artworkLocalFilePath: c.filePath,
                artworkTargetDir: c.artworkTargetDir,
                artist: c.currentArtist,
                album: c.currentAlbum,
                isFullscreen: true,
                fullscreenControls: _vizControls(context),
                fullscreenTrackInfo: TrackInfoFlash(ctrl: c),
                // La croix du viz ramène au mini lecteur compact.
                onClose: () => MiniWindow.instance.setVizMode(false),
              ),
            ),
          // Bande de déplacement: la barre de titre est masquée, et le viz a
          // ses propres gestes (pan du piano, de la notation) — la fenêtre ne
          // peut donc pas se saisir par lui. `translucent` sans enfant: la
          // bande entre dans l'arène pour le PAN mais ne bloque pas le hit-test,
          // donc un tap sous elle atteint toujours le visualiseur.
          Positioned(
            top: 0, left: 0, right: 48, height: 26,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vizControls(BuildContext context) {
    final c = widget.controller;
    final l10n = context.l10n;
    Widget btn(IconData icon, VoidCallback? onPressed, double size,
            {String? tooltip, Key? key}) =>
        IconButton(
          key: key,
          iconSize: size,
          tooltip: tooltip,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          constraints: const BoxConstraints(),
          icon: OutlinedGlyph(
              icon: icon, size: size, enabled: onPressed != null),
          onPressed: onPressed,
        );
    return ListenableBuilder(
      listenable: Listenable.merge([c, UserSettings.instance]),
      builder: (_, __) {
        final pinned = UserSettings.instance.windowAlwaysOnTop;
        // scaleDown: au plancher (240 px) la rangée tient à ~10 px près — une
        // police système agrandie la ferait déborder.
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (MiniWindow.alwaysOnTopSupported) ...[
                  btn(pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      () => MiniWindow.instance.setAlwaysOnTop(!pinned), 20,
                      tooltip: pinned
                          ? l10n.windowAlwaysOnTopOn
                          : l10n.settingsAlwaysOnTopTitle,
                      key: const ValueKey('mwv-pin')),
                  const SizedBox(width: 10),
                ],
                btn(Icons.fast_rewind, c.canGoPrev ? c.goPrev : null, 28,
                    key: const ValueKey('mwv-prev')),
                btn(c.isPlaying ? Icons.pause : Icons.play_arrow,
                    c.hasFile
                        ? () {
                            logTransport(c.isPlaying ? 'pause' : 'lecture',
                                source: 'bouton fenêtre mini (viz)',
                                detail: 'jouait=${c.isPlaying}');
                            c.togglePlay();
                          }
                        : null,
                    38,
                    key: const ValueKey('mwv-play')),
                btn(Icons.fast_forward, c.canGoNext ? c.goNext : null, 28,
                    key: const ValueKey('mwv-next')),
                const SizedBox(width: 10),
                btn(Icons.open_in_full, MiniWindow.instance.exit, 20,
                    tooltip: l10n.miniWindowExit,
                    key: const ValueKey('mwv-exit')),
              ],
            ),
            const SizedBox(height: 4),
            FullscreenSeekBar(
              position: c.position,
              elapsed: c.elapsedPosition,
              infinite: c.effectiveForceLoopMode == 'infinite',
              duration: c.duration,
              width: 148,
              onSeek: c.seek,
            ),
          ],
        ),
        );
      },
    );
  }

  // ── Mode compact ─────────────────────────────────────────────────────────
  Widget _buildCompact(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      // Pas le `DragToMoveArea` du paquet: son double-tap MAXIMISE la fenêtre
      // (absurde pour un mini lecteur), et un double-tap ancêtre retient dans
      // l'arène chaque tap de bouton ~300 ms — lecture/pause deviendrait mou.
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => windowManager.startDragging(),
        child: ListenableBuilder(
          listenable:
              Listenable.merge([widget.controller, UserSettings.instance]),
          builder: (context, _) => LayoutBuilder(
            builder: (context, box) {
              // La pochette est un carré calé sur la HAUTEUR: la fenêtre
              // s'élargit, la pochette ne grossit pas.
              final art = (box.maxHeight - 16).clamp(48.0, 160.0);
              return Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _artwork(art),
                    const SizedBox(width: 10),
                    Expanded(child: _body(context)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _artwork(double size) {
    final c = widget.controller;
    final fill = UserSettings.instance.miniWindowCoverFill;
    return Center(
      // Un clic alterne « entière » (défaut) et « zoomée pour remplir ». Un
      // tap et le pan de déplacement de fenêtre cohabitent dans l'arène: sans
      // mouvement c'est un tap, au-delà du slop c'est la fenêtre qui part.
      child: Tooltip(
        message: fill
            ? context.l10n.miniWindowCoverFit
            : context.l10n.miniWindowCoverFill,
        waitDuration: const Duration(milliseconds: 700),
        child: GestureDetector(
          onTap: () => UserSettings.instance.miniWindowCoverFill = !fill,
          child: ArtworkImage(
            url: c.artworkUrl,
            priority: true,
            artist: c.currentArtist,
            album: c.currentAlbum,
            localFilePath: c.filePath,
            targetDir: c.artworkTargetDir,
            size: size,
            fit: fill ? BoxFit.cover : BoxFit.contain,
            borderRadius: BorderRadius.circular(8),
            platformName: c.currentPlatformName,
            formatHint: c.currentFormatExt,
            engine: c.audio.backendName,
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final c = widget.controller;
    final artist = c.currentArtist;
    final album = c.currentAlbum;
    final sub = <String>[
      if (artist != null && artist.isNotEmpty) artist,
      if (album != null && album.isNotEmpty) album,
    ].join(' · ');
    final pinned = UserSettings.instance.windowAlwaysOnTop;

    // ⚠️ La taille demandée à window_manager n'est PAS celle que la vue
    // reçoit: sur Linux, GTK compte les extents de décoration dans la
    // géométrie de la fenêtre, et le plancher de 440×132 rend une vue de
    // 396×105 (mesuré) — 44 et 27 px de moins. Or le corps demande 36 (titre +
    // sous-titre) + 20 (seek) + 34 (transport) = 90 px: il en manquait
    // exactement UN, et la mise en page sortait en jaune et noir. Le `Spacer`
    // ne pouvait rien y faire — il rend son espace jusqu'à zéro, jamais moins.
    //
    // D'où un en-tête ÉLASTIQUE: il prend ce qui reste et ce qui dépasse est
    // rogné, en silence. C'est la seule partie qui PEUT céder — les deux
    // rangées du bas sont des cibles de clic, on ne rogne pas un bouton — et
    // le rognage mord le BAS du sous-titre. La marge ainsi rendue est celle de
    // l'en-tête entier (36 px): en dessous, c'est-à-dire sous ~70 px de vue,
    // ce sont les rangées du bas qui déborderaient à leur tour, mais le
    // plancher de la fenêtre n'y descend pas.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minHeight: 0,
              maxHeight: double.infinity,
              child: _header(context, sub: sub, pinned: pinned),
            ),
          ),
        ),
        _seekRow(context),
        _transport(context),
      ],
    );
  }

  /// Titre, sous-titre et boutons de chrome. Hauteur NATURELLE: c'est
  /// l'appelant qui décide de ce qu'il lui donne (voir `_body`).
  Widget _header(BuildContext context,
      {required String sub, required bool pinned}) {
    final c = widget.controller;
    final l10n = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ScrollingText(
                text: c.hasFile ? c.displayTitle : l10n.miniWindowIdle,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (sub.isNotEmpty)
                ScrollingText(
                  text: sub,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
        _chromeButton(
          tooltip: l10n.playerVisualizer,
          icon: Icons.equalizer,
          color: cs.onSurfaceVariant,
          onPressed: () => MiniWindow.instance.setVizMode(true),
        ),
        if (MiniWindow.alwaysOnTopSupported)
          _chromeButton(
            tooltip: pinned
                ? l10n.windowAlwaysOnTopOn
                : l10n.settingsAlwaysOnTopTitle,
            icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
            color: pinned ? kTransportActiveAccent : cs.onSurfaceVariant,
            onPressed: () => MiniWindow.instance.setAlwaysOnTop(!pinned),
          ),
        _chromeButton(
          tooltip: l10n.miniWindowExit,
          icon: Icons.open_in_full,
          color: cs.onSurfaceVariant,
          onPressed: MiniWindow.instance.exit,
        ),
      ],
    );
  }

  Widget _chromeButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      iconSize: 16,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 26, height: 26),
      icon: Icon(icon, color: color),
      onPressed: onPressed,
    );
  }

  Widget _seekRow(BuildContext context) {
    final c = widget.controller;
    final tt = Theme.of(context).textTheme;
    final known = c.hasFile && c.duration > 0;
    final infinite = c.effectiveForceLoopMode == 'infinite';
    final total = !known
        ? (infinite ? '∞' : '--:--')
        : (infinite ? '∞ (${_fmt(c.duration)})' : _fmt(c.duration));
    final pos = known ? (_seekDrag ?? c.position).clamp(0.0, c.duration) : 0.0;
    // Le compteur n'est PAS la position de la barre: sous boucle infinie la
    // barre sature à la durée nominale, le temps écoulé continue de monter.
    final elapsed = _seekDrag ?? (c.hasFile ? c.elapsedPosition : 0.0);

    return Row(
      children: [
        Text(_fmt(elapsed), style: tt.labelSmall),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: SizedBox(
              height: 20,
              child: Slider(
                value: pos,
                min: 0,
                max: known ? c.duration : 1,
                // Durée inconnue ⇒ barre DÉSACTIVÉE plutôt qu'absente, comme
                // dans le lecteur: on ne se déplace pas dans une durée qu'on
                // ne connaît pas, mais la piste joue très bien.
                onChanged:
                    known ? (v) => setState(() => _seekDrag = v) : null,
                onChangeEnd: known
                    ? (v) {
                        setState(() => _seekDrag = null);
                        c.seek(v);
                      }
                    : null,
              ),
            ),
          ),
        ),
        Text(total, style: tt.labelSmall),
      ],
    );
  }

  Widget _transport(BuildContext context) {
    final c = widget.controller;
    return IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          minimumSize: const Size(36, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ⚠️ Boutons TOUJOURS présents et CLEFÉS, `onPressed` nul quand
          // l'action est indisponible — même règle que le mini-lecteur de la
          // coquille: un enfant conditionnel décale la Row, et un appui en
          // cours se réapparie PAR POSITION sur le voisin.
          ShuffleButton(
            key: const ValueKey('mw-shuffle'),
            enabled: c.shuffleEnabled,
            onToggle: c.toggleShuffle,
            iconSize: 15,
          ),
          IconButton(
            key: const ValueKey('mw-prev'),
            iconSize: 22,
            icon: const Icon(Icons.fast_rewind),
            onPressed: c.canGoPrev ? c.goPrev : null,
          ),
          IconButton(
            key: const ValueKey('mw-play'),
            iconSize: 30,
            icon: Icon(c.isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: c.hasFile
                ? () {
                    logTransport(c.isPlaying ? 'pause' : 'lecture',
                        source: 'bouton fenêtre mini',
                        detail: 'jouait=${c.isPlaying}');
                    c.togglePlay();
                  }
                : null,
          ),
          IconButton(
            key: const ValueKey('mw-next'),
            iconSize: 22,
            icon: const Icon(Icons.fast_forward),
            onPressed: c.canGoNext
                ? () {
                    logTransport('suivant',
                        source: 'bouton fenêtre mini',
                        detail: 'jouait=${c.isPlaying}');
                    c.goNext();
                  }
                : null,
          ),
          LoopButton(
            key: const ValueKey('mw-loop'),
            mode: c.loopMode,
            onCycle: c.cycleLoopMode,
            iconSize: 15,
          ),
        ],
      ),
    );
  }
}
