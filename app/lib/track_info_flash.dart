import 'dart:async';
import 'package:flutter/material.dart';

import 'artwork_image.dart';
import 'player_controller.dart';
import 'viz_selector_widget.dart' show OutlinedVizText, VizOverlayReveal;

/// Transient track-info card shown over the FULLSCREEN visualizer whenever the
/// track changes — anchored bottom-LEFT, carrying the full identity of what is
/// playing: artwork, title, the album or container file, artists, year,
/// collection, platform and decoder engine.
///
/// Same display contract as the projectM preset banner: ONE widget serves both
/// the change-flash and the tap-overlay reveal (opacity = max of the two, via
/// [VizOverlayReveal]), and the text is outlined instead of boxed in a dark
/// card — readable on a light frame without an imposing background.
///
/// Anything absent is simply omitted — local files have no year/collection,
/// a standalone file has no album. Nothing here is a translatable label: every
/// line is data or a proper noun (engine names, platform names), which is why
/// this widget adds no ARB keys.
class TrackInfoFlash extends StatefulWidget {
  final PlayerController ctrl;

  /// How long the card stays fully visible before fading out.
  static const kHold = Duration(seconds: 5);

  const TrackInfoFlash({super.key, required this.ctrl});

  @override
  State<TrackInfoFlash> createState() => _TrackInfoFlashState();
}

class _TrackInfoFlashState extends State<TrackInfoFlash>
    with SingleTickerProviderStateMixin {
  // Same asymmetry as the preset banner: quick in, gentle out.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    reverseDuration: const Duration(milliseconds: 500),
  );
  String? _lastKey;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    // Seed the key WITHOUT flashing: entering fullscreen shouldn't fire the
    // card for a track that was already playing — only a real change does.
    _lastKey = _trackKey();
    widget.ctrl.addListener(_onCtrl);
  }

  @override
  void didUpdateWidget(TrackInfoFlash old) {
    super.didUpdateWidget(old);
    if (old.ctrl != widget.ctrl) {
      old.ctrl.removeListener(_onCtrl);
      widget.ctrl.addListener(_onCtrl);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _flash.dispose();
    widget.ctrl.removeListener(_onCtrl);
    super.dispose();
  }

  /// Identity of what is playing. Subsong index is part of it: moving between
  /// two subtunes of one .sid IS a track change here, and the file path alone
  /// would not see it.
  String? _trackKey() {
    final c = widget.ctrl;
    if (c.filePath == null) return null;
    return '${c.filePath}#${c.subsongIdx}';
  }

  void _onCtrl() {
    final key = _trackKey();
    if (key == null || key == _lastKey) return;
    _lastKey = key;
    _hideTimer?.cancel();
    setState(() {});          // refresh the card's content for the new track
    _flash.forward();
    _hideTimer = Timer(TrackInfoFlash.kHold, () {
      if (mounted) _flash.reverse();
    });
  }

  /// The container the track came from: its album if it belongs to one, else
  /// the file name when the track is a subsong of a multi-song file (a bare
  /// standalone file adds nothing the title doesn't already say).
  String? _containerLine() {
    final c = widget.ctrl;
    final album = c.currentAlbum;
    if (album != null && album.trim().isNotEmpty) return album.trim();
    if (c.subsongIdx > 0 && c.filePath != null) {
      final p = c.filePath!;
      final slash = p.lastIndexOf(RegExp(r'[/\\]'));
      final base = slash >= 0 ? p.substring(slash + 1) : p;
      if (base.isNotEmpty) return base;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.ctrl;
    if (c.filePath == null) return const SizedBox.shrink();
    // The tap overlay's reveal, when hosted over a visualizer that has one.
    final reveal = VizOverlayReveal.maybeOf(context);

    // Compact facts, dot-separated: only what this track actually has.
    final facts = <String>[
      if (c.currentYear != null) '${c.currentYear}',
      if ((c.currentCollectionSlug ?? '').isNotEmpty) c.currentCollectionSlug!,
      if ((c.currentPlatformName ?? '').isNotEmpty) c.currentPlatformName!,
      if (c.backend.isNotEmpty) c.backend,
    ];
    final container = _containerLine();
    final artist    = (c.currentArtist ?? '').trim();

    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // The artwork is an image — no outline needed, a soft shadow seats
          // it on light frames.
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 6),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ArtworkImage(
                url:           c.artworkUrl,
                artist:        c.currentArtist,
                album:         c.currentAlbum,
                localFilePath: c.filePath,
                targetDir:     c.artworkTargetDir,
                formatHint:    c.currentFormatExt,
                size:          46,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedVizText(c.displayTitle,
                    size: 14, weight: FontWeight.w600),
                if (artist.isNotEmpty)
                  OutlinedVizText(artist, size: 12, fillAlpha: 0.95),
                if (container != null)
                  OutlinedVizText(container, size: 11, fillAlpha: 0.8),
                if (facts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: OutlinedVizText(facts.join(' · '),
                        size: 10, fillAlpha: 0.7),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: reveal == null
            ? _flash
            : Listenable.merge([_flash, reveal]),
        builder: (context, child) {
          final f = _flash.value;
          final r = reveal?.value ?? 0;
          final o = f > r ? f : r;
          if (o < 0.01) return const SizedBox.shrink();
          return Opacity(opacity: o, child: child);
        },
        child: card,
      ),
    );
  }
}
