import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'platform_artwork.dart';

// ---------------------------------------------------------------------------
// ArtworkCache — persistent artwork storage
//
// Storage strategy:
//   targetDir given → <targetDir>/artwork.<ext>  (online library tracks)
//   localFilePath   → same directory as the audio file, same basename
//                     (e.g. Aerial.mod → Aerial.jpg)
//   neither         → Caches/artwork/<url-derived-name>  (fallback for display)
//
// Before downloading, the target directory is scanned for a user-placed file
// with the same basename and any supported image extension, so users can drop
// their own artwork in the right folder without any app interaction.
// ---------------------------------------------------------------------------

class ArtworkCache {
  static final ArtworkCache instance = ArtworkCache._();
  ArtworkCache._();

  // url → resolved local path once downloaded
  final _paths   = <String, String>{};
  // url → in-flight download future (deduplicated)
  final _pending = <String, Future<void>>{};
  // host → future that completes 1.5 s after the last download for that host
  // (serializes downloads per origin, prevents temporary bans)
  final _hostQueues = <String, Future<void>>{};

  static const _kArtExts = [
    'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'avif',
  ];

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Deletes the display-artwork cache (`Caches/artwork/`, incl. embedded-cover
  /// dumps) and clears the in-memory path map, so covers are re-fetched/
  /// re-extracted on demand. Does NOT touch artwork stored next to downloaded
  /// tracks (that belongs to the online library, cleared separately). Returns
  /// the number of files removed.
  Future<int> clearCache() async {
    _paths.clear();
    _pending.clear();
    final cacheDir = await getApplicationCacheDirectory();
    final dir = Directory('${cacheDir.path}/artwork');
    if (!await dir.exists()) return 0;
    var removed = 0;
    await for (final e in dir.list()) {
      if (e is File) { try { await e.delete(); removed++; } catch (_) {} }
    }
    return removed;
  }

  /// Returns the local path for [url], downloading if necessary.
  ///
  /// Supply [artist] + [album] for album artwork, or [localFilePath] for
  /// single-track artwork (no album).  Either can be omitted to use the
  /// URL-derived cache fallback.
  Future<String?> getPath(
    String url, {
    String? artist,
    String? album,
    String? localFilePath,
    String? targetDir,  // pre-computed full directory (overrides artist/album)
  }) async {
    if (_paths.containsKey(url)) return _paths[url];

    final targetPath = await _targetPath(
      url,
      artist:        artist,
      album:         album,
      localFilePath: localFilePath,
      targetDir:     targetDir,
    );
    final dirPath  = p.dirname(targetPath);
    // 'artwork' is only unambiguous when targetDir/localFilePath gave us a
    // DEDICATED per-album/per-track directory (lets users drop their own
    // artwork.jpg there too). The url-hash fallback (neither given) shares one
    // cacheDir/artwork/ folder across every album, so it must keep its unique
    // per-url basename — using the generic 'artwork' name there collided
    // between different albums' "does this already exist" checks.
    final hasDedicatedDir = targetDir != null || localFilePath != null;
    final basename = (album != null && hasDedicatedDir)
        ? 'artwork'
        : p.basenameWithoutExtension(targetPath);

    // Honour user-placed artwork or a previously downloaded file.
    final existing = await _scanDir(dirPath, basename);
    if (existing != null) {
      _paths[url] = existing;
      return existing;
    }

    // Start download (deduplicated).
    _pending[url] ??= _startDownload(url, targetPath)
        .whenComplete(() => _pending.remove(url));
    return null;
  }

  /// Awaits any in-progress download for [url], then returns the local path.
  Future<String?> awaitDownload(String url) async {
    await _pending[url];
    return _paths[url];
  }

  /// Looks for user-placed artwork next to a local audio file (no URL needed).
  /// Checks for `<audioFilePath_noext>.(jpg|png|webp|…)` in the same folder.
  Future<String?> findLocalArtwork(String audioFilePath) => _scanDir(
        p.dirname(audioFilePath),
        p.basenameWithoutExtension(audioFilePath),
      );

  /// Looks for a cover the player already extracted from the file's own tags
  /// (PlayerController._applyEmbeddedArtwork dumps it under this exact name).
  /// Without this, a local track with only an EMBEDDED cover showed artwork in
  /// the player but a placeholder everywhere else: the extraction happens after
  /// the DB row is written, so `tracks.artwork_url` stays null.
  Future<String?> findEmbeddedArtwork(String audioFilePath) async {
    final cacheDir = await getApplicationCacheDirectory();
    return _scanDir('${cacheDir.path}/artwork',
        'embedded_${audioFilePath.hashCode.toRadixString(16)}');
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<void> _startDownload(String url, String targetPath) async {
    final host = Uri.tryParse(url)?.host ?? '';

    // Grab previous slot and register ours before any await so concurrent
    // callers for the same host queue up in arrival order.
    final slotDone = Completer<void>();
    final previous = _hostQueues[host] ?? Future<void>.value();
    _hostQueues[host] = slotDone.future;

    await previous; // wait for previous download + its 1.5 s cooloff

    try {
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final file = File(targetPath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(res.bodyBytes);
        _paths[url] = targetPath;
      }
    } catch (_) {
      // leave absent → retried on next getPath call
    }

    // Release our slot after 1.5 s so the next queued download starts then.
    Future.delayed(const Duration(milliseconds: 1500))
        .then((_) => slotDone.complete());
  }

  Future<String> _targetPath(
    String url, {
    String? artist,
    String? album,
    String? localFilePath,
    String? targetDir,
  }) async {
    final ext = _extFromUrl(url);

    // Pre-computed full directory: online/<collection>/<artist>/<platform|format>/<album>/
    if (targetDir != null) {
      return '$targetDir/artwork.$ext';
    }

    if (localFilePath != null) {
      return '${p.dirname(localFilePath)}/${p.basenameWithoutExtension(localFilePath)}.$ext';
    }

    // Fallback: app cache directory, keyed by a hash of the FULL url. Many
    // artwork hosts reuse a generic last-path-segment ("cover.jpg", "folder.jpg")
    // across totally different albums — naming the cache file after just that
    // segment (the old behaviour) collided: whichever album downloaded first
    // "won" that filename and every other album sharing the same segment served
    // its image forever after (e.g. 3 unrelated albums all ending in
    // "/cover.jpg" served one album's cover). Hash the whole URL instead.
    final cacheDir = await getApplicationCacheDirectory();
    final digest   = sha1.convert(utf8.encode(url)).toString();
    return '${cacheDir.path}/artwork/$digest.$ext';
  }

  /// Scans [dir] for `<basename>.<ext>` across all supported image extensions.
  Future<String?> _scanDir(String dir, String basename) async {
    if (!await Directory(dir).exists()) return null;
    for (final ext in _kArtExts) {
      final f = File('$dir/$basename.$ext');
      if (await f.exists()) return f.path;
    }
    return null;
  }

  static String _extFromUrl(String url) {
    final path = Uri.parse(url).path.toLowerCase();
    for (final ext in _kArtExts) {
      if (path.endsWith('.$ext')) return ext;
    }
    return 'jpg';
  }
}

// ---------------------------------------------------------------------------
// ArtworkImage widget
// ---------------------------------------------------------------------------

/// La pochette telle que les rails de l'accueil la posent, et la SEULE façon
/// d'en poser une ailleurs: carrée, recadrée (`BoxFit.cover`), coins à 8, et
/// SANS placeholder maison — c'est le placeholder thématisé par plateforme
/// d'[ArtworkImage] qui doit apparaître quand il n'y a pas d'image, comme sur
/// l'accueil. Une carte qui refaisait l'appel à la main dérivait sur les trois
/// points à la fois (boîte non carrée, aplat de couleur en guise de
/// placeholder, pas de repli sur la pochette voisine d'un fichier local).
///
/// [size] nul = la vignette remplit la largeur qu'on lui donne et se rend
/// carrée toute seule — ce qu'il faut dans une grille, où la largeur d'une
/// tuile n'est pas connue d'avance.
class RailArtwork extends StatelessWidget {
  final String? url;
  final String? artist;
  final String? album;
  final String? localFilePath;
  final String? formatHint;
  final String? platformName;
  final double? size;

  const RailArtwork({
    super.key,
    required this.url,
    this.artist,
    this.album,
    this.localFilePath,
    this.formatHint,
    this.platformName,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final art = ArtworkImage(
      url:           url,
      artist:        artist,
      album:         album,
      localFilePath: localFilePath,
      formatHint:    formatHint,
      platformName:  platformName,
      size:          size,
      borderRadius:  BorderRadius.circular(8),
    );
    return size != null ? art : AspectRatio(aspectRatio: 1, child: art);
  }
}

class ArtworkImage extends StatefulWidget {
  final String?       url;

  /// First artist name — used to build `Documents/online/<artist>/<album>/`.
  final String?       artist;

  /// Album name — determines storage folder; artwork is shared by all tracks.
  final String?       album;

  /// Local audio file path.  Used to locate user-placed sibling artwork when
  /// [url] is null (local files), or to name single-track artwork downloaded
  /// from [url] when no [album] is provided.
  final String?       localFilePath;

  /// Pre-computed full target directory (from RewampDb.artworkDirForResult).
  /// When set, overrides the artist/album path — ensures artwork lands in the
  /// correct online/<collection>/<artist>/<platform|format>/<album>/ folder.
  final String?       targetDir;

  /// Format / extension hint (e.g. "sid", ".nsf") used to theme the fallback
  /// placeholder by origin platform when no artwork is available. When null the
  /// platform is inferred from [localFilePath] or [url].
  final String?       formatHint;

  /// Key planted on the COVER's own box (the aspect-fitted, shadowed frame) —
  /// not on this widget's outer layout box, which includes the letterboxing.
  /// The player's queue-reveal animation measures it to fly from exactly what
  /// is on screen. Only honored on the shadowed path (the player artwork).
  final Key? imageKey;

  /// Origin platform NAME as the server reports it ("Amiga", "X68000", …).
  /// Preferred over [formatHint] for the themed placeholder: a container
  /// extension (.lha/.lzh/.zip/.7z) says nothing about where a track comes from.
  final String?       platformName;

  final double?       size;
  final BoxFit        fit;
  final BorderRadius? borderRadius;
  /// Shown while loading or when no artwork is available. Overrides the built-in
  /// per-platform placeholder.
  final Widget?       placeholder;

  /// Drop shadow painted behind the artwork. The widget then sizes itself to the
  /// image's OWN aspect ratio (resolved from the decoded image), so the shadow
  /// hugs the cover instead of the letterboxed box it is laid out in.
  final List<BoxShadow>? shadows;

  /// Fired (post-frame, once per distinct artwork) with the provider actually
  /// displayed and a stable cache key — lets the player derive a background
  /// palette from whatever this widget resolved (file, cache, network…).
  final void Function(ImageProvider provider, String key)? onImageResolved;

  const ArtworkImage({
    this.imageKey,
    super.key,
    required this.url,
    this.artist,
    this.album,
    this.localFilePath,
    this.targetDir,
    this.formatHint,
    this.platformName,
    this.size,
    this.fit         = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.shadows,
    this.onImageResolved,
  });

  @override
  State<ArtworkImage> createState() => _ArtworkImageState();
}

class _ArtworkImageState extends State<ArtworkImage> {
  String? _localPath;

  // Decoded aspect ratio of the current image; only resolved when a shadow is
  // requested (that's the only case where the widget must hug the cover).
  double?             _ratio;
  ImageStream?        _ratioStream;
  ImageStreamListener? _ratioListener;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ArtworkImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.localFilePath != widget.localFilePath) {
      _localPath   = null;
      _ratio       = null;
      _notifiedKey = null;   // a new url must re-notify onImageResolved (tint)
      _detachRatio();
      _load();
    }
  }

  @override
  void dispose() {
    _detachRatio();
    _detachColorStream();
    super.dispose();
  }

  void _detachRatio() {
    if (_ratioStream != null && _ratioListener != null) {
      _ratioStream!.removeListener(_ratioListener!);
    }
    _ratioStream   = null;
    _ratioListener = null;
  }

  String?             _notifiedKey;
  ImageStream?        _colorStream;
  ImageStreamListener? _colorListener;

  /// Fire onImageResolved when the DISPLAYED image actually DECODES (its stream
  /// delivers a frame) — the reliable "artwork is loaded and on screen" signal.
  /// The old build-time postFrame raced the async load and often never landed;
  /// the stream fires exactly once the picture is ready (immediately if already
  /// cached), for a real cover OR the themed placeholder.
  void _notifyResolved(ImageProvider provider, String key) {
    if (widget.onImageResolved == null || _notifiedKey == key) return;
    _notifiedKey = key;
    _detachColorStream();
    final stream = provider.resolve(const ImageConfiguration());
    // Re-read the callback when the stream fires, not at attach time: the
    // listener outlives the widget configuration that installed it.
    void report() {
      final cb = widget.onImageResolved;
      if (mounted && cb != null) cb(provider, key);
    }
    _colorListener = ImageStreamListener((_, __) => report(),
        onError: (_, __) => report());   // failed decode → still resolve (neutral)
    _colorStream = stream..addListener(_colorListener!);
  }

  void _detachColorStream() {
    if (_colorStream != null && _colorListener != null) {
      _colorStream!.removeListener(_colorListener!);
    }
    _colorStream   = null;
    _colorListener = null;
  }

  /// Subscribes to [provider]'s decoded image to learn its aspect ratio.
  void _trackRatio(ImageProvider provider) {
    final stream = provider.resolve(const ImageConfiguration());
    if (stream.key == _ratioStream?.key) return;
    _detachRatio();
    _ratioListener = ImageStreamListener((info, _) {
      final r = info.image.width / info.image.height;
      if (mounted && r != _ratio) setState(() => _ratio = r);
    }, onError: (_, __) {});
    _ratioStream = stream..addListener(_ratioListener!);
  }

  Future<void> _load() async {
    // url may be a plain local path (embedded artwork extracted to the
    // cache by PlayerController) — display it directly, no download.
    // A missing/empty path (stale cache entry, '') counts as NO artwork so the
    // themed placeholder shows instead of a permanently-blank FileImage.
    final u = widget.url;
    if (u != null && !u.startsWith('http')) {
      final ok = u.isNotEmpty && await File(u).exists();
      final resolved = ok ? u : null;
      if (mounted && resolved != _localPath) {
        setState(() => _localPath = resolved);
      }
      return;
    }
    // Local file with no artwork URL: user-placed sibling file first, then a
    // cover the player already extracted from the file's own tags.
    final localFile = widget.localFilePath;
    if (widget.url == null && localFile != null) {
      final cache = ArtworkCache.instance;
      // Read `widget` ONCE, before the awaits: didUpdateWidget can swap in a
      // row with no local path while findLocalArtwork is in flight, and the
      // second `widget.localFilePath!` then throws on a null.
      final path = await cache.findLocalArtwork(localFile) ??
          await cache.findEmbeddedArtwork(localFile);
      if (mounted && path != _localPath) setState(() => _localPath = path);
      return;
    }
    final url = widget.url;
    if (url == null) return;

    var path = await ArtworkCache.instance.getPath(
      url,
      artist:        widget.artist,
      album:         widget.album,
      localFilePath: widget.localFilePath,
      targetDir:     widget.targetDir,
    );
    if (path != null) {
      if (mounted && path != _localPath) setState(() => _localPath = path);
      return;
    }

    // Download is in progress — show Image.network immediately, then switch
    // to the local file once the download completes.
    path = await ArtworkCache.instance.awaitDownload(url);
    if (mounted && path != null && path != _localPath) {
      setState(() => _localPath = path);
    }
  }

  Widget _placeholder(ColorScheme cs) {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }
    // Theme the fallback by the track's origin platform (C64/NES/Amiga…).
    final hint = widget.formatHint ?? widget.localFilePath ?? widget.url;
    final asset = platformAssetFor(
        platformName: widget.platformName, pathOrExt: hint);
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      // A missing/not-yet-generated asset must never blank the tile.
      errorBuilder: (_, e, __) {
        return Container(
          color: cs.primaryContainer,
          child: Center(
            child: Icon(Icons.music_note, color: cs.onPrimaryContainer, size: 48),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final url = widget.url;

    Widget content;
    var haveImage = true;
    if (_localPath != null) {
      final provider = FileImage(File(_localPath!));
      if (widget.shadows != null) _trackRatio(provider);
      _notifyResolved(provider, _localPath!);
      // A stale/missing local artwork file (e.g. artworkUrl pointing at a
      // cache path that no longer exists) must fall back to the themed
      // placeholder, not render blank.
      content = Image(
        image: provider,
        fit: widget.fit,
        errorBuilder: (_, e, __) {
          return _placeholder(cs);
        },
      );
    } else if (url != null && url.startsWith('http')) {
      final provider = NetworkImage(url);
      if (widget.shadows != null) _trackRatio(provider);
      _notifyResolved(provider, url);
      content = Image(
        image: provider,
        fit: widget.fit,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _placeholder(cs),
        errorBuilder: (_, __, ___) => _placeholder(cs),
      );
    } else {
      content = _placeholder(cs);
      haveImage = false;
      // Feed the themed placeholder to onImageResolved too: the player's
      // tinted background and the visualizer's GL artwork background are
      // driven by it, and stayed EMPTY for artwork-less tracks otherwise.
      if (widget.placeholder == null) {
        final hint = widget.formatHint ?? widget.localFilePath ?? widget.url;
        final asset = platformAssetFor(
            platformName: widget.platformName, pathOrExt: hint);
        _notifyResolved(AssetImage(asset), 'placeholder:$asset');
      }
    }

    if (widget.borderRadius != null) {
      content = ClipRRect(borderRadius: widget.borderRadius!, child: content);
    }

    if (widget.shadows != null) {
      // Hug the cover: size to its real aspect ratio (square until the image is
      // decoded, and for the placeholder) so the shadow traces the artwork's
      // own edges rather than the letterboxed layout box.
      content = Center(
        child: AspectRatio(
          aspectRatio: haveImage ? (_ratio ?? 1.0) : 1.0,
          child: DecoratedBox(
            key: widget.imageKey,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: widget.shadows,
            ),
            child: content,
          ),
        ),
      );
    }

    if (widget.size != null) {
      return SizedBox(width: widget.size, height: widget.size, child: content);
    }
    return content;
  }
}
