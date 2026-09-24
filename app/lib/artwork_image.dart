import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'uade_info.dart';
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
  /// Les urls pour lesquelles une descente PRIORITAIRE double déjà une
  /// descente ordinaire (voir getPath): sans ça, chaque image reconstruite en
  /// lancerait une de plus.
  final Set<String> _pendingPriority = <String>{};
  // host → future that completes 1.5 s after the last download for that host
  // (serializes downloads per origin, prevents temporary bans)
  //
  // ⚠️ Ne vaut QUE pour les hôtes TIERS. Notre miroir en est exempté — voir
  // [_isOwnMirror].
  final _hostQueues = <String, Future<void>>{};

  /// Descentes simultanées vers NOTRE miroir.
  ///
  /// Six, la convention des navigateurs pour HTTP/1.1 (le paquet `http` de
  /// Dart ne parle pas HTTP/2, donc pas de multiplexage sur une connexion).
  /// Un plafond reste nécessaire même sans bridage côté serveur: une grille de
  /// deux cents vignettes ouvrirait sinon deux cents sockets d'un coup.
  static const int _kMirrorConcurrency = 6;
  int _mirrorInFlight = 0;
  final List<Completer<void>> _mirrorWaiters = [];

  /// Le radical d'une pochette rangée à côté de son morceau: le nom de fichier
  /// COMPLET, extension comprise.
  ///
  /// ⚠️ **Un nom Amiga porte son FORMAT AVANT le point** (`mdat.monkey island`),
  /// donc `basenameWithoutExtension` y répond « mdat » — et TOUS les modules
  /// d'un même dossier partageaient alors un unique `mdat.jpg`. Constaté sur un
  /// vrai profil: un seul `mdat.jpg` pour « monkey island », « carl lewis
  /// challenge » et « carl lewis challenge-ingame ». C'est la CINQUIÈME fois
  /// que cette convention mord (titre, placeholder, porte multi-pistes, nom
  /// de conteneur).
  ///
  /// Garder le nom entier rend la collision impossible sans avoir à deviner si
  /// le nom est de forme préfixe: `mdat.monkey island.jpg`, `Chrono
  /// Trigger.spc.jpg`. Le prix est que les pochettes déjà rangées sous
  /// l'ancien nom ne sont plus trouvées — elles se re-téléchargent une fois.
  static String artBasenameFor(String audioFilePath) =>
      p.basename(audioFilePath);

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
    _pendingPriority.clear();
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
    // La pochette du MORCEAU EN COURS ne fait pas la queue: les descentes vers
    // un hôte TIERS sont sérialisées avec 1,5 s de pause après chacune (notre
    // miroir en est exempté depuis le 2026-09-21, voir _isOwnMirror, mais il
    // garde un plafond de concurrence), et une rafale de vignettes suffit à retarder
    // de plusieurs dizaines de secondes celle que le lecteur, la session média
    // et la notification attendent. Mesuré le 2026-09-05 sur « Space
    // Adventure Cobra » (jw_hes): trois écoutes, l'UI montrait la pochette
    // par NetworkImage, et AUCUNE copie n'avait atterri sur le disque.
    bool priority = false,
  }) async {
    // Le mémo n'est qu'un CHEMIN: le fichier peut avoir disparu depuis
    // (suppression de l'album, donc de son dossier). Rendu tel quel, il
    // faisait afficher le placeholder PARTOUT pour cette url — recherche,
    // rails, lecteur — jusqu'au redémarrage. Vu le 2026-09-05 sur « Space
    // Adventure Cobra » juste après « Supprimer l'album ».
    final memo = _paths[url];
    if (memo != null) {
      if (File(memo).existsSync()) {
        if (priority) unawaited(revalidate(url, memo));
        return memo;
      }
      _paths.remove(url);
    }

    final targetPath = await _targetPath(
      url,
      artist:        artist,
      album:         album,
      localFilePath: localFilePath,
      targetDir:     targetDir,
    );
    final dirPath = p.dirname(targetPath);
    // Le nom cherché est TOUJOURS celui que `_targetPath` vient de décider — une
    // seconde règle tenue en parallèle finit par diverger de la première, et le
    // symptôme est alors « le fichier existe mais on le re-télécharge » ou, pire,
    // « on sert le fichier d'un autre ».
    final basename = p.basenameWithoutExtension(targetPath);

    // Honour user-placed artwork or a previously downloaded file.
    final existing = await _scanDir(dirPath, basename);
    if (existing != null) {
      _paths[url] = existing;
      if (priority) unawaited(revalidate(url, existing));
      return existing;
    }

    // Start download (deduplicated).
    //
    // ⚠️ La déduplication seule ANNULE la priorité, et c'est le cas le plus
    // courant: la grille d'albums d'une collection a déjà demandé cette même
    // pochette, donc une descente NON prioritaire est déjà en attente derrière
    // les vignettes; s'y raccrocher fait attendre le morceau en cours
    // exactement comme si l'on n'avait rien demandé. Une demande prioritaire
    // qui tombe sur une descente ordinaire en lance donc une DEUXIÈME, hors
    // file. Elles écrivent le même octet au même endroit, et la seule qui
    // compte est la première arrivée.
    final pending = _pending[url];
    if (pending == null) {
      _pending[url] = _startDownload(url, targetPath, priority: priority)
          .whenComplete(() => _pending.remove(url));
    } else if (priority && !_pendingPriority.contains(url)) {
      _pendingPriority.add(url);
      unawaited(_startDownload(url, targetPath, priority: true)
          .whenComplete(() => _pendingPriority.remove(url)));
    }
    return null;
  }

  /// Revalide la copie locale de [url] contre le serveur, UNE fois par
  /// processus et par url, en arrière-plan.
  ///
  /// Une pochette REMPLACÉE côté serveur garde son url (`…/cover.jpg`,
  /// `Cache-Control: max-age=86400`): `getPath` rend le fichier existant sans
  /// jamais rien redemander, et l'ancienne image reste affichée POUR TOUJOURS —
  /// « Ice Frontier » (Skaven, modland), 2026-09-08: serveur à 11 581 octets
  /// depuis 00:06, voisin `ice frontier.s3m.jpg` de 18 003 octets descendu à
  /// 00:00 et réputé bon. Seule la pochette du MORCEAU EN COURS est revalidée
  /// (`priority`), et par un GET CONDITIONNEL (`If-Modified-Since` = la date
  /// du fichier): 304 dans le cas courant, le corps seulement quand l'image a
  /// changé. Un serveur qui ignorerait l'en-tête rend 200 avec les mêmes
  /// octets: comparés avant d'écrire, pour ne pas bumper la génération (et
  /// redécoder toutes les vignettes) pour rien. Sur changement: fichier
  /// réécrit sur place, bitmap évincé, génération bumpée — les listes suivent,
  /// elles montrent le même fichier.
  final Set<String> _revalidated = <String>{};
  Future<void> revalidate(String url, String localPath) async {
    if (!url.startsWith('http') || !_revalidated.add(url)) return;
    try {
      final f = File(localPath);
      if (!await f.exists()) return;
      final since = HttpDate.format((await f.lastModified()).toUtc());
      final res = await http
          .get(Uri.parse(url), headers: {'If-Modified-Since': since})
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return;
      final old = await f.readAsBytes();
      if (old.length == res.bodyBytes.length) {
        var same = true;
        for (var i = 0; i < old.length; i++) {
          if (old[i] != res.bodyBytes[i]) { same = false; break; }
        }
        if (same) return;
      }
      await f.writeAsBytes(res.bodyBytes, flush: true);
      PaintingBinding.instance.imageCache.evict(FileImage(f));
      PaintingBinding.instance.imageCache.evict(NetworkImage(url));
      generation.value++;
    } catch (_) {/* hors ligne, ou serveur muet: l'ancienne reste, c'est le cas normal */}
  }

  /// La copie locale déjà connue de [url] dans ce processus, sans rien lancer.
  String? localPathFor(String url) {
    final memo = _paths[url];
    if (memo == null) return null;
    if (File(memo).existsSync()) return memo;
    _paths.remove(url);
    return null;
  }

  /// Une descente de [url] est en vol (voir [awaitDownload]).
  bool isPending(String url) => _pending.containsKey(url);

  /// Oublie tout ce qu'on sait de [url] et EFFACE le fichier déjà descendu.
  ///
  /// Une pochette est mise en cache SOUS SON URL, et `getPath` rend le fichier
  /// existant sans jamais rien redemander — c'est ce qui la rend gratuite au
  /// centième affichage. Mais une pochette REMPLACÉE côté serveur garde la même
  /// URL: rien ne change, donc rien ne se re-télécharge, et l'ancienne image
  /// reste affichée pour toujours. Même famille que l'album republié sous une
  /// URL constante (voir `_purgeIfSourceUrlChanged`).
  ///
  /// Trois caches à défaire, et les oublier laisse le symptôme intact:
  /// la table `url → chemin`, le FICHIER sur disque, et le cache d'images de
  /// Flutter — qui garde le bitmap DÉCODÉ, indexé par le fournisseur, donc un
  /// `FileImage` du même chemin ressert l'ancienne image même après effacement.
  ///
  /// Les mêmes paramètres que [getPath] sont nécessaires: ce sont eux qui
  /// décident du chemin cible (dossier dédié de l'album, voisin du fichier
  /// audio, ou repli haché dans le cache).
  /// Bumpée à CHAQUE invalidation. Toute [ArtworkImage] montée l'écoute et se
  /// recharge quand elle bouge.
  ///
  /// ⚠️ Sans ça, une pochette REMPLACÉE SOUS LA MÊME URL restait affichée.
  /// `didUpdateWidget` ne recharge que si l'url CHANGE — or « re-télécharger »
  /// ne change rien à l'url, il change l'image derrière. Le fichier était bien
  /// effacé et le bitmap évincé, mais les vignettes déjà construites (le
  /// panneau de file, le mini-lecteur) gardaient leur chemin résolu et
  /// n'avaient aucune raison de se reconstruire. Un id de GÉNÉRATION est le
  /// même remède que pour le contexte GL: un identifiant non nul ne prouve
  /// rien après une invalidation, il faut comparer une génération.
  static final ValueNotifier<int> generation = ValueNotifier<int>(0);

  Future<void> invalidate(
    String url, {
    String? artist,
    String? album,
    String? localFilePath,
    String? targetDir,
  }) async {
    if (url.isEmpty) return;
    final known = _paths.remove(url);
    _pending.remove(url);

    final victims = <String>{if (known != null) known};
    try {
      final targetPath = await _targetPath(
        url,
        artist:        artist,
        album:         album,
        localFilePath: localFilePath,
        targetDir:     targetDir,
      );
      final existing = await _scanDir(
          p.dirname(targetPath), p.basenameWithoutExtension(targetPath));
      if (existing != null) victims.add(existing);
      // Et le VOISIN du fichier audio lui-même, quel que soit le dossier que
      // les champs de la ligne ont fait calculer: c'est lui que le lecteur
      // et les listes d'un morceau téléchargé affichent, et une ligne dont
      // l'artiste ou la plateforme diffère de ceux du téléchargement le
      // manquerait — l'ancienne image survivrait à « Re-télécharger ».
      if (localFilePath != null) {
        final beside = await _scanDir(
            p.dirname(localFilePath), artBasenameFor(localFilePath));
        if (beside != null) victims.add(beside);
      }
    } catch (_) {/* chemin non calculable: on efface au moins ce qu'on savait */}

    for (final path in victims) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      // Le bitmap décodé survit à l'effacement du fichier: l'évincer aussi.
      PaintingBinding.instance.imageCache.evict(FileImage(File(path)));
    }
    if (url.startsWith('http')) {
      PaintingBinding.instance.imageCache.evict(NetworkImage(url));
    }
    // EN DERNIER: les vignettes montées se rechargent, et il faut que le
    // disque et le cache mémoire soient déjà propres quand elles le font — y
    // compris les listings de dossier, qui viennent de perdre un fichier.
    _forgetListings();
    generation.value++;
  }

  /// Oublie UN fichier de pochette déjà posé sur le disque, sans connaître son
  /// url: le bitmap décodé est évincé et toute url qui pointait dessus est
  /// déliée. Sert au ménage d'un dossier d'album re-téléchargé, où l'on tient
  /// les CHEMINS et pas les urls — évincer par url y raterait la moitié du
  /// travail (une même pochette est atteinte par l'url du morceau ET par celle
  /// de l'album).
  ///
  /// N'efface PAS le fichier: l'appelant est en train de vider le dossier.
  /// Ne bump PAS la génération non plus — un ménage de dossier en appelle des
  /// dizaines, et c'est à l'appelant de la bump UNE fois, à la fin.
  Future<void> forgetLocalFile(String path) async {
    _forgetListings(p.dirname(path));
    _paths.removeWhere((_, v) => v == path);
    PaintingBinding.instance.imageCache.evict(FileImage(File(path)));
  }

  /// Awaits any in-progress download for [url], then returns the local path.
  Future<String?> awaitDownload(String url) async {
    await _pending[url];
    return _paths[url];
  }

  /// Looks for user-placed artwork next to a local audio file (no URL needed).
  ///
  /// Deux noms, dans cet ordre: celui que NOUS écrivons (nom de fichier
  /// COMPLET + extension d'image, voir [artBasenameFor]) puis la convention
  /// courante `<nom sans extension>.jpg`, qui est celle qu'un utilisateur suit
  /// quand il dépose sa propre pochette à la main. Sur un nom ordinaire les
  /// deux diffèrent (`X.spc.jpg` vs `X.jpg`), donc chercher les deux n'est pas
  /// une redondance — mais le second est SAUTÉ sur un nom de forme préfixe,
  /// où il désigne le format et non le morceau (voir
  /// [localArtworkFromListing]).
  /// Listing de dossier mémorisé, le temps d'une RAFALE.
  ///
  /// Chaque vignette locale sans url cherche une pochette VOISINE, donc lit le
  /// dossier de son fichier. Les pistes d'un même album partagent ce dossier —
  /// qui peut contenir des centaines de fichiers — et un rail qui se
  /// reconstruit relit le même dossier une fois par vignette. Mesuré sur
  /// macOS, app au repos sur l'accueil: DEUX fils d'entrées-sorties saturés en
  /// continu par `Directory.list`, l'app à ~100 % de processeur.
  ///
  /// Courte VOLONTAIREMENT: c'est un cache de rafale, pas un index. Une
  /// pochette déposée à la main apparaît au plus tard après ce délai, et toute
  /// écriture de pochette le vide (voir [_forgetListings]).
  static const _kListingTtl = Duration(seconds: 5);
  final Map<String, ({DateTime at, List<String> files})> _listings = {};

  void _forgetListings([String? dir]) {
    if (dir == null) {
      _listings.clear();
    } else {
      _listings.remove(dir);
    }
  }

  Future<List<String>> _listDir(String dir) async {
    final now = DateTime.now();
    final memo = _listings[dir];
    if (memo != null && now.difference(memo.at) < _kListingTtl) return memo.files;
    final files = <String>[
      await for (final e in Directory(dir).list(followLinks: false))
        if (e is File) e.path,
    ];
    _listings[dir] = (at: now, files: files);
    return files;
  }

  /// La pochette d'un DOSSIER, pour le navigateur local: les règles
  /// GÉNÉRIQUES de [localArtworkFromListing] seulement — noms consacrés
  /// (folder/cover/front/artwork), sinon l'UNIQUE image du dossier qui
  /// n'appartient à aucune piste. Jamais la pochette d'UN morceau: une image
  /// `<morceau>.jpg` décrit ce morceau, pas le dossier. Listing mémorisé
  /// ([_listDir]): l'écran se recharge à chaque notification de la base.
  Future<String?> findFolderArtwork(String dir) async {
    try {
      final name = p.basename(dir);
      final inside = await _listDir(dir);
      final own = folderArtworkFromListing(inside, folderName: name);
      if (own != null) return own;
      // ⚠️ L'image peut être POSÉE À CÔTÉ du dossier, pas dedans: un pack de
      // rips livre `jeu.zip` + `jeu.jpg` côte à côte, et l'import déplie
      // l'archive en dossier `jeu/` — la pochette reste alors la voisine du
      // DOSSIER. Listage du parent, mémoïsé comme les autres.
      return _artNamed(await _listDir(p.dirname(dir)), name);
    } catch (_) {
      return null;
    }
  }

  /// L'image du listing dont le radical est [stem] (insensible à la casse).
  static String? _artNamed(List<String> paths, String stem) {
    final want = stem.toLowerCase();
    for (final path in paths) {
      final b = p.basename(path).toLowerCase();
      for (final ext in _kArtExts) {
        if (b == '$want.$ext') return path;
      }
    }
    return null;
  }

  /// [findFolderArtwork] sans le disque.
  ///
  /// [folderName] = le nom du dossier: **une image qui le porte EST sa
  /// pochette** (`cbmt/cbmt.jpg`), et c'est la règle qui manquait — la règle
  /// générique l'écartait parce qu'elle appartient aussi à la piste
  /// `cbmt.mid`, si bien que le dossier restait sur son icône alors que le
  /// morceau à l'intérieur montrait l'image (constaté 2026-09-12). Ça reste
  /// une règle GÉNÉRIQUE: elle ne prend jamais la pochette d'UN morceau au
  /// hasard, seulement celle qui nomme le dossier lui-même.
  static String? folderArtworkFromListing(List<String> dirFilePaths,
      {String? folderName}) {
    if (dirFilePaths.isEmpty) return null;
    if (folderName != null && folderName.isNotEmpty) {
      final own = _artNamed(dirFilePaths, folderName);
      if (own != null) return own;
    }
    // Une « piste » qui n'existe pas: aucune image ne porte son nom, donc
    // seules les règles génériques peuvent répondre.
    final dir = p.dirname(dirFilePaths.first);
    return localArtworkFromListing(dirFilePaths, p.join(dir, '\u0000folder'));
  }

  Future<String?> findLocalArtwork(String audioFilePath) async {
    final dir = p.dirname(audioFilePath);
    try {
      return localArtworkFromListing(await _listDir(dir), audioFilePath);
    } catch (_) {
      return null;
    }
  }

  /// Résolution PURE de la pochette locale à partir du LISTING du dossier —
  /// les règles de [findLocalArtwork], qui n'est plus qu'une lecture du
  /// dossier suivie de cet appel. Séparée pour l'import en LOT: résoudre par
  /// piste refaisait jusqu'à sept parcours de dossier PAR PISTE (les stats de
  /// _scanDir + le listing générique), l'import liste chaque dossier UNE fois
  /// et résout toutes ses pistes en mémoire.
  ///
  /// [dirFilePaths] = les FICHIERS du dossier de la piste (pas de récursion).
  static String? localArtworkFromListing(
      List<String> dirFilePaths, String audioFilePath) {
    String? byStem(String stem) {
      final lower = stem.toLowerCase();
      for (final path in dirFilePaths) {
        final b = p.basename(path).toLowerCase();
        for (final ext in _kArtExts) {
          if (b == '$lower.$ext') return path;
        }
      }
      return null;
    }

    // ⚠️ Le second nom N'EXISTE PAS pour un nom de forme PRÉFIXE
    // (`mdat.apidya (level 1)`): ce que `basenameWithoutExtension` en retire
    // est le TITRE, et ce qu'il rend est le FORMAT — « mdat », commun à tout
    // le dossier. Un `mdat.jpg` (résidu d'une version d'avant le nom complet,
    // ou pochette déposée à la main) servait alors la pochette de « monkey
    // island » à « apidya », même artiste, même dossier. Vu le 2026-09-06.
    final base = p.basename(audioFilePath);
    final firstDot = base.indexOf('.');
    final prefixForm =
        firstDot > 0 && isUadePrefixToken(base.substring(0, firstDot));
    final named = byStem(artBasenameFor(audioFilePath)) ??
        (prefixForm ? null : byStem(p.basenameWithoutExtension(audioFilePath)));
    if (named != null) return named;
    // Pochette GÉNÉRIQUE du dossier — une image livrée DANS une archive ou un
    // dossier importé (folder.jpg, cover.png…) sert toutes les pistes de son
    // dossier. Les noms consacrés d'abord; à défaut, l'UNIQUE image du dossier
    // (deux images ou plus = ambigu, on ne devine pas — la leçon `mdat.jpg`:
    // servir la mauvaise pochette est pire que le placeholder). ⚠️ Jamais le
    // nom d'UN morceau: ces formes-là sont couvertes au-dessus, et une image
    // `<autre morceau>.jpg` ne doit PAS fuir sur ses voisins.
    for (final stem in const ['folder', 'cover', 'front', 'artwork']) {
      final hit = byStem(stem);
      if (hit != null) return hit;
    }
    final images = <String>[];
    final audioStems = <String>{};
    // Les voisins qui ne sont PAS des pistes (playlist, notes de rip…) ne
    // « possèdent » aucune image: un pack livre couramment
    // `Album.png` + `Album.m3u` + `Album.txt`, et c'est bien la pochette de
    // l'album — la bloquer parce que le .m3u partage son radical la rendait
    // introuvable (payé sur Battle Garegga).
    const nonTrack = {
      'm3u', 'm3u8', 'txt', 'nfo', 'diz', 'pdf', 'htm', 'html',
      'md', 'ini', 'json', 'xml', 'log', 'doc', 'rtf', 'cue',
    };
    for (final path in dirFilePaths) {
      final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
      if (_kArtExts.contains(ext)) {
        images.add(path);
        if (images.length > 1) return null; // ambigu: on s'arrête là
      } else if (!nonTrack.contains(ext)) {
        audioStems.add(p.basename(path).toLowerCase());
      }
    }
    if (images.length != 1) return null;
    // Une image nommée d'après un AUTRE fichier audio du dossier lui
    // appartient — pas au dossier.
    final stem = p.basenameWithoutExtension(images.first).toLowerCase();
    final mine = p.basename(audioFilePath).toLowerCase();
    final owned = audioStems.any((a) =>
        a != mine && (a == stem || p.withoutExtension(a) == stem));
    return owned ? null : images.first;
  }

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

  /// Notre propre miroir, qu'on n'a AUCUNE raison de ménager.
  ///
  /// ⚠️ La pause de 1,5 s par hôte a longtemps été présentée comme une
  /// « politesse envers files.rewamp.app ». Mesuré le 2026-09-21: le domaine
  /// est servi par **Cloudflare** (`server: cloudflare`), et **60 requêtes
  /// d'affilée sans pause rendent 60 × HTTP 200** — aucun bridage. Pendant ce
  /// temps la pause s'appliquait quand même, et c'était le goulot:
  ///
  ///     ce que le miroir sert (keep-alive)   28 ms par pochette
  ///     ce que l'app s'imposait            1 500 ms par pochette
  ///
  /// Une grille de vingt albums mettait donc TRENTE secondes à se remplir sur
  /// une connexion à 42 Mo/s — rapporté comme « les téléchargements sont très
  /// lents alors que la connexion est rapide ».
  ///
  /// La politesse RESTE pour les hôtes tiers (exotica, modland, scene.org…),
  /// qui bannissent un client trop pressé: c'est pour eux qu'elle existait.
  static bool _isOwnMirror(String host) => host == 'files.rewamp.app';

  Future<void> _acquireMirror() async {
    if (_mirrorInFlight < _kMirrorConcurrency) {
      _mirrorInFlight++;
      return;
    }
    final c = Completer<void>();
    _mirrorWaiters.add(c);
    await c.future;
  }

  void _releaseMirror() {
    // Passer la main à un attendant garde le compte inchangé: le créneau
    // change de titulaire, il ne se libère pas.
    if (_mirrorWaiters.isNotEmpty) {
      _mirrorWaiters.removeAt(0).complete();
    } else {
      _mirrorInFlight--;
    }
  }

  Future<void> _startDownload(String url, String targetPath,
      {bool priority = false}) async {
    final host = Uri.tryParse(url)?.host ?? '';

    // Grab previous slot and register ours before any await so concurrent
    // callers for the same host queue up in arrival order. Une descente
    // PRIORITAIRE (pochette du morceau en cours) ne prend pas de créneau et
    // n'attend personne — voir getPath.
    // Notre miroir: un plafond de concurrence, et AUCUNE pause (voir
    // _isOwnMirror). Les hôtes tiers gardent la file sérialisée + 1,5 s.
    final own = _isOwnMirror(host);
    final slotDone = Completer<void>();
    if (own) {
      if (!priority) await _acquireMirror();
    } else {
      final previous = _hostQueues[host] ?? Future<void>.value();
      if (!priority) _hostQueues[host] = slotDone.future;
      if (!priority) await previous; // wait for previous download + its 1.5 s cooloff
    }

    try {
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final file = File(targetPath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(res.bodyBytes);
        _forgetListings(p.dirname(targetPath));   // le dossier vient de changer
        _paths[url] = targetPath;
      }
    } catch (_) {
      // leave absent → retried on next getPath call
    }

    if (priority) return;
    if (own) {
      _releaseMirror();
      return;
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
    //
    // ⚠️ `artwork.<ext>` est un nom d'ALBUM, et il n'est unique que si le dossier
    // l'est. Sans album — hvsc, modland, asma — le dossier vaut
    // `<artiste>/<plateforme>`, donc TOUS les morceaux d'un même artiste s'y
    // partageaient un seul `artwork.png`: le premier à le descendre gagnait le
    // nom, et les autres se voyaient servir SON image pour toujours, sans jamais
    // demander la leur. Constaté sur disque: un `Rob Hubbard/c64/artwork.png` à
    // côté de `Commando.png`, `Monty_on_the_Run.png` et
    // `One_Man_and_his_Droid.png` — quatre images pour trois morceaux, et celle
    // qu'on voyait dépendait de l'ÉCRAN (selon qu'il passe `targetDir` ou
    // `localFilePath`).
    if (targetDir != null && album != null && album.isNotEmpty) {
      return '$targetDir/artwork.$ext';
    }

    if (localFilePath != null) {
      final dir = targetDir ?? p.dirname(localFilePath);
      return '$dir/${artBasenameFor(localFilePath)}.$ext';
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

  /// Slug du moteur qui joue ce fichier (`audio.backendName`), quand il est
  /// connu — c'est-à-dire pour la piste EN COURS seulement: une ligne de liste
  /// ne joue rien. Sert à départager les extensions partagées par deux
  /// plateformes (`.mus`: C64 chez libsidplayfp, MSX chez libkss).
  final String? engine;
  final double? size;

  const RailArtwork({
    super.key,
    required this.url,
    this.artist,
    this.album,
    this.localFilePath,
    this.formatHint,
    this.platformName,
    this.engine,
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
      engine:        engine,
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
  /// correct `online/<collection>/<artist>/<platform|format>/<album>/` folder.
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

  /// Slug du moteur qui joue ce fichier (`audio.backendName`), quand il est
  /// connu — la piste EN COURS seulement, une ligne de liste ne jouant rien.
  /// Départage les extensions partagées par deux plateformes (`.mus`: C64 chez
  /// libsidplayfp, MSX chez libkss).
  final String?       engine;

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

  /// La pochette du morceau EN COURS: elle ne fait pas la queue.
  ///
  /// Les descentes sont sérialisées PAR HÔTE avec 1,5 s de pause entre chacune
  /// (voir [ArtworkCache.getPath]). Une grille d'albums remplit cette file de
  /// vignettes, et la pochette de ce qui JOUE se retrouvait derrière elles:
  /// lancer un album depuis une collection laissait le mini-lecteur sur la
  /// pochette précédente pendant des dizaines de secondes, puis elle finissait
  /// par arriver (signalé le 2026-09-15). Le lecteur plein écran et la session
  /// média demandaient déjà la priorité en appelant `getPath` directement; le
  /// mini-lecteur, lui, passe par ce widget.
  final bool priority;

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
    this.engine,
    this.size,
    this.fit         = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.shadows,
    this.onImageResolved,
    this.priority = false,
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

  /// Résolution SYNCHRONE d'une url qui est déjà un chemin local: un stat()
  /// coûte moins qu'une frame, et c'est ce qui supprime le FLASH de
  /// placeholder à chaque changement de piste (rapporté trois fois sur
  /// Battle Garegga: l'async posait _localPath une frame après le build).
  /// Rend true si l'url est de ce type (résolue, existante ou non).
  bool _syncLocalFromUrl() {
    final u = widget.url;
    if (u == null || u.isEmpty || u.startsWith('http')) return false;
    _localPath = File(u).existsSync() ? u : null;
    return true;
  }

  /// Génération observée lors de la dernière résolution. Voir
  /// [ArtworkCache.generation].
  int _gen = ArtworkCache.generation.value;

  void _onArtworkInvalidated() {
    final g = ArtworkCache.generation.value;
    if (g == _gen || !mounted) return;
    _gen = g;
    // Même chemin que didUpdateWidget: résolution synchrone si l'url EST un
    // chemin, sinon relecture. `_notifiedKey` remis à zéro pour que la teinte
    // soit recalculée sur la NOUVELLE image.
    _notifiedKey = null;
    _detachRatio();
    _ratio = null;
    // ⚠️ `setState` INCONDITIONNEL, avant toute résolution: après un
    // re-téléchargement le chemin est le MÊME (même nom de fichier), donc
    // `_load` ne poserait rien (`resolved != _localPath` est faux) et rien ne
    // se reconstruirait. Or c'est justement la reconstruction qui redécode
    // depuis le disque — le bitmap ayant été évincé du cache mémoire juste
    // avant. Sans elle, effacer le fichier ne change rien à l'écran.
    setState(() { if (_syncLocalFromUrl()) return; });
    if (widget.url == null || widget.url!.startsWith('http')) _load();
  }

  @override
  void initState() {
    super.initState();
    ArtworkCache.generation.addListener(_onArtworkInvalidated);
    if (!_syncLocalFromUrl()) _load();
  }

  @override
  void didUpdateWidget(ArtworkImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.localFilePath != widget.localFilePath) {
      _ratio       = null;
      _notifiedKey = null;   // a new url must re-notify onImageResolved (tint)
      _detachRatio();
      // Chemin local: résolu ICI, synchrone — aucune frame de placeholder.
      if (_syncLocalFromUrl()) return;
      // Sinon (http / découverte voisine): on GARDE l'image précédente
      // affichée pendant la résolution — le placeholder ne s'intercale plus;
      // _load() posera la nouvelle (ou null si rien) quand elle est connue.
      _load();
    }
  }

  @override
  void dispose() {
    ArtworkCache.generation.removeListener(_onArtworkInvalidated);
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
    //
    // ⚠️ **Jamais pendant la construction.** `_notifyResolved` est appelé
    // depuis `build()`, et `ImageStream.addListener` invoque son écouteur
    // SYNCHRONEMENT quand l'image est déjà décodée — le cas du cache, donc le
    // cas courant. Un consommateur qui reconstruit sur ce signal (un
    // `setState`, un `ValueNotifier` écouté par un `ValueListenableBuilder`)
    // se voyait alors marqué « à reconstruire » en pleine construction:
    // Flutter lève, la frame est abandonnée, et la vignette reste sur son
    // placeholder. Déplacer le `setState` chez l'appelant ne suffit PAS —
    // c'est le MOMENT qu'il faut corriger, et ça se fait ici, une fois, pour
    // tous les consommateurs.
    void report() {
      final cb = widget.onImageResolved;
      if (!mounted || cb == null) return;
      final phase = SchedulerBinding.instance.schedulerPhase;
      final building = phase == SchedulerPhase.persistentCallbacks ||
          phase == SchedulerPhase.midFrameMicrotasks;
      if (!building) {
        cb(provider, key);
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final late = widget.onImageResolved;
        if (mounted && late != null) late(provider, key);
      });
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
    if (url == null) {
      // RIEN à résoudre — et c'est exactement le cas où garder l'image
      // précédente est FAUX. Le « on garde pendant la résolution » de
      // didUpdateWidget vaut pour une url http ou une découverte voisine, qui
      // FINIRONT par poser une valeur; ici il n'y a aucune source, donc rien
      // ne viendrait jamais l'effacer. Sur une liste (les éléments sont
      // RECYCLÉS), la vignette d'une piste sans pochette gardait alors celle
      // de la piste que ce même élément affichait avant: pas un placeholder,
      // la pochette d'un AUTRE album.
      if (mounted && _localPath != null) setState(() => _localPath = null);
      return;
    }

    var path = await ArtworkCache.instance.getPath(
      url,
      artist:        widget.artist,
      album:         widget.album,
      localFilePath: widget.localFilePath,
      targetDir:     widget.targetDir,
      priority:      widget.priority,
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
        platformName: widget.platformName, pathOrExt: hint,
        engine: widget.engine);
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
        // Changement de fichier (piste suivante, autre pochette): garder la
        // frame PRÉCÉDENTE le temps du décodage au lieu de flasher un blanc —
        // la moitié « décodage » du clignotement au changement de piste.
        gaplessPlayback: true,
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
            platformName: widget.platformName, pathOrExt: hint,
            engine: widget.engine);
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

// ── Migration des noms de pochettes rangées à côté des morceaux ──────────────

/// Rattrape les pochettes écrites sous l'ANCIEN nom (`<nom sans extension>.jpg`)
/// après le passage au nom complet (voir [ArtworkCache.artBasenameFor]).
///
/// Sans ça elles ne sont plus jamais consultées NI effacées: la nouvelle
/// recherche ne les trouve pas, une neuve se télécharge à côté, et l'ancienne
/// reste sur le disque pour toujours. Un fichier qui ne se recrée jamais ne
/// disparaît jamais non plus.
///
/// **On RENOMME, on n'efface presque pas** — et ce n'est pas de la prudence
/// gratuite: `online/` ne contient pas que nos copies. Une archive d'album y
/// dépose son propre contenu, vu sur un vrai profil dans le même dossier qu'un
/// `.flac`: `Skipp-Syntetyzer-CoverArt.png` et un `.nfo`. Une règle « efface ce
/// qui n'est plus référencé » les aurait supprimés. Renommer préserve les
/// octets ET évite le re-téléchargement.
///
/// Une seule exception, celle qui ne peut PAS être sauvée: une image nommée
/// d'après un TOKEN DE PRÉFIXE Amiga (`mdat.jpg`) alors que plusieurs modules du
/// dossier portent ce token. Elle appartient à un seul d'entre eux et rien ne
/// dit lequel — la renommer affirmerait une association fausse pour les autres.
/// Elle était déjà fausse pour tous sauf un: on l'efface.
Future<void> migrateArtworkSidecarNames(Directory onlineRoot) async {
  if (!await onlineRoot.exists()) return;
  const artExts = {
    '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.avif',
  };
  final byDir = <String, List<FileSystemEntity>>{};
  try {
    await for (final e in onlineRoot.list(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      byDir.putIfAbsent(p.dirname(e.path), () => []).add(e);
    }
  } catch (_) {
    return;
  }

  for (final entry in byDir.entries) {
    final names = [for (final e in entry.value) p.basename(e.path)];
    final images = [
      for (final n in names)
        if (artExts.contains(p.extension(n).toLowerCase())) n,
    ];
    if (images.isEmpty) continue;
    final others = [
      for (final n in names)
        if (!artExts.contains(p.extension(n).toLowerCase()) &&
            !n.startsWith('.'))
          n,
    ];

    for (final img in images) {
      final imgExt = p.extension(img);
      final base = img.substring(0, img.length - imgExt.length);
      if (base == 'artwork') continue;             // convention d'ALBUM
      if (others.contains(base)) continue;         // DÉJÀ au nouveau nom

      // Ancien nom: le radical d'un fichier du dossier, extension retirée.
      final cands = [
        for (final o in others)
          if (p.basenameWithoutExtension(o) == base) o,
      ];
      if (cands.length == 1) {
        final dest = p.join(entry.key, '${cands.first}$imgExt');
        try {
          if (!await File(dest).exists()) {
            await File(p.join(entry.key, img)).rename(dest);
          }
        } catch (_) {}
        continue;
      }
      if (cands.length > 1 &&
          !base.contains('.') &&
          isUadePrefixToken(base) &&
          cands.every((c) => c.startsWith('$base.'))) {
        // `mdat.jpg` servant trois modules: fausse pour au moins deux d'entre
        // eux, et impossible d'en désigner le propriétaire.
        try {
          await File(p.join(entry.key, img)).delete();
        } catch (_) {}
      }
      // Tout le reste est laissé en place: on ne sait pas que c'est à nous.
    }
  }
}
