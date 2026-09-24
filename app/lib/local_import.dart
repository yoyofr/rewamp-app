// Import de fichiers/dossiers locaux EN BIBLIOTHÈQUE — le plan
// local-import-library. À distinguer de l'OUVERTURE (local_open.dart), qui
// reste l'écoute jetable: copie `opened/`, purge à 30 jours.
//
// Le modèle: « importé » = « en bibliothèque locale ». Une ligne `in_library`
// + `source='local'` règle d'un coup la rétention (in_library ⇒ jamais purgé
// — règle existante d'OpenedFiles.prune), la trouvabilité (écran
// bibliothèque) et la cohérence catalogue/local. La structure d'origine est
// PRÉSERVÉE, jamais gérée: le chemin relatif à la racine d'import
// (`local_rel_path`) est la matière de la facette « dossier »; une
// archive importée est un dossier virtuel du même arbre (extraction pérenne
// sous `local/<nom>/…`), sans geste dédié.
//
// Trois provenances (`local_origin`): 'picker' (fichiers), 'folder' (dossier),
// 'archive' (contenu extrait d'une archive importée).
//
// PERFORMANCE — l'enregistrement se fait en LOT (_registerAll):
// pièce par pièce, chaque piste payait ~4 commits sqflite (fsync chacun), un
// notifyListeners par entrée de bibliothèque (chaque écran à l'écoute
// re-requêtait la base à chaque piste) et jusqu'à sept parcours de dossier
// pour la pochette — un zip de .vgz était « très lent ». Désormais: UNE
// transaction pour tout le lot (LocalDb.runBatchWrites), UN notifyListeners,
// UN listing par dossier (résolution de pochette pure,
// ArtworkCache.localArtworkFromListing).

import 'dart:io';

import 'picker_memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_snack.dart';
import 'artwork_image.dart' show ArtworkCache;
import 'folder_picker.dart';
import 'l10n.dart';
import 'm3u_info.dart';
import 'local_db.dart';
import 'local_ops.dart';
import 'uade_info.dart' show isUadePrefixToken;
import 'local_delete.dart'
    show cleanCompanionsAfterDelete;
import 'player_controller.dart' show PlayerController;
import 'rewamp_db.dart';
import 'sync_service.dart';
import 'storage_roots.dart';

/// La SECONDE CHANCE du moteur (registre complet: extension + en-tête), quand
/// un lecteur existe. Null hors lecture — l'import retombe alors sur les
/// listes d'extensions seules.
bool Function(String)? _engineCanPlay() {
  final a = PlayerController.current?.audio;
  if (a == null) return null;
  return (path) {
    try {
      return a.canPlay(path);
    } catch (_) {
      return false;
    }
  };
}

/// L'identité de bibliothèque d'un fichier importé: le fichier ENTIER,
/// toujours — donc SANS suffixe `?subsong=`.
///
/// ⚠️ `<chemin>?subsong=0` désigne LA sous-chanson 0, et c'est ce que la
/// bibliothèque joue: un `.rsn` de 92 pistes importé ne lançait que la
/// première. L'absence de suffixe est la convention « le fichier entier »
/// (voir `ContainerSubsongScreen._songRefId`), la seule que
/// `playWholeFileLibraryEntry` déplie en file complète.
///
/// **Toujours**, sans compter les sous-chansons d'abord — deux raisons, et la
/// seconde a été payée:
/// - c'est l'INTENTION du geste. On importe un FICHIER; on ne choisit jamais
///   une sous-chanson à l'import. Un fichier à une seule sous-chanson retombe
///   de lui-même sur la lecture simple, le dépliage ne rendant qu'une ligne.
/// - **compter est impossible ici.** La sonde native (`probeSubsongCount`)
///   rend 0 pour UADE, zxtune, PSF, AdPlug, SunVox…, et les sous-chansons
///   UADE ne se connaissent que par la songdb (md5 → réseau). Un filtre par
///   extension ne rattrape rien: `.jt` n'est dans aucune liste, et
///   « unreal menu.jt » ne lançait que sa 1re sous-chanson.
String localImportRefId(String filePath) => filePath;

// ── Les GESTES d'import, partagés ──────────────────────────────────────────
//
// Deux écrans les offrent — l'accueil et l'onglet « Local » — et un geste
// dupliqué diverge: c'est ici qu'ils vivent, une fois.

/// Le dossier où ouvrir le sélecteur Android: la racine du stockage, ou le
/// sous-dossier de musique quand il existe (le sélecteur s'ouvre sinon dans le
/// bac à sable de l'app, où l'utilisateur n'a rien).
///
/// Public: l'OUVERTURE (jouer un fichier) en a besoin autant que l'import.
Future<String?> androidPickerStartDir() async {
  try {
    final ext = await getExternalStorageDirectory();
    if (ext == null) return null;
    // ext = .../Android/data/<pkg>/files — quatre niveaux au-dessus.
    Directory root = ext;
    for (var i = 0; i < 4; i++) {
      root = root.parent;
    }
    for (final name in ['Music/Rewamp', 'Music', 'Download', 'Downloads']) {
      final d = Directory('${root.path}/$name');
      if (await d.exists()) return d.path;
    }
    return root.path;
  } catch (_) {
    return null;
  }
}

/// « Importer des fichiers »: mêmes règles de sélecteur que l'OUVERTURE (aucun
/// filtre — le probe tranche à la réception), mais la destination est la
/// BIBLIOTHÈQUE: copie pérenne sous `<support>/local/`, archives dépliées en
/// dossiers virtuels.
Future<void> pickAndImportFiles(BuildContext context) async {
  final picked = await pickAnyFilePaths(PickerSlot.music,
      mobileStartDir: Platform.isAndroid ? androidPickerStartDir : null);
  if (picked.isEmpty || !context.mounted) return;
  await PickerMemory.rememberFile(PickerSlot.music, picked.first);
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  reportImportOn(messenger, l10n, await importLocalFiles(picked));
}

/// « Importer un dossier »: copie récursive, arborescence préservée.
///
/// ⚠️ La copie se fait DANS le callback de [withPickedFolder]: sur iOS la
/// portée de sécurité n'est ouverte que le temps de cet appel, et lire hors
/// portée ne LÈVE pas — ça rend une liste VIDE, donc un import qui « réussit »
/// sans rien importer.
Future<void> pickAndImportFolder(BuildContext context) async {
  // Messager et l10n capturés AVANT: la copie peut durer, et un contexte
  // démonté entre-temps avalerait le compte-rendu.
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final done = Platform.isAndroid
      ? await importAndroidTree()
      : await withPickedFolder(importLocalFolder);
  if (done == null) return;   // annulé
  reportImportOn(messenger, l10n, done);
}

/// Import d'un dossier sur ANDROID: sélecteur d'arbre SAF, copie NATIVE, puis
/// la passe d'enregistrement habituelle.
///
/// ⚠️ `FilePicker.getDirectoryPath()` ne convient pas ici et l'échec est
/// silencieux: il rend un CHEMIN reconstruit depuis l'URI de l'arbre
/// (`getFullPathFromTreeUri`, ex. `/storage/emulated/0/Music/sid`), or l'app ne
/// déclare AUCUNE permission de stockage — et depuis Android 11 aucune ne donne
/// l'accès par chemin à des fichiers non-médias, `.sid` n'étant pas un média
/// pour MediaStore. L'énumération rendait donc zéro fichier et l'import
/// s'achevait sur « rien de jouable dans la sélection »: un import qui
/// « réussit » sans rien importer, la même famille de piège que la portée de
/// sécurité iOS. La permission d'arbre, elle, ouvre tout le sous-arbre par
/// `ContentResolver` sans rien déclarer.
///
/// Rend null quand l'utilisateur annule — jamais un résultat vide, que
/// l'appelant afficherait comme un échec.
Future<LocalImportResult?> importAndroidTree() async {
  const channel = MethodChannel('rewamp/saf_folder');
  String? uri;
  try {
    uri = await channel.invokeMethod<String>('pick');
  } on MissingPluginException {
    // Binaire plus ancien que ce canal: le sélecteur du greffon échouera
    // peut-être, mais c'est mieux que pas de sélecteur du tout.
    return withPickedFolder(importLocalFolder);
  } catch (_) {
    return null;
  }
  if (uri == null || uri.isEmpty) return null;   // annulé
  final res = LocalImportResult();
  final root = await localImportsDir();
  // Le nom du dossier vient du DERNIER segment de l'URI d'arbre
  // (`…/tree/primary%3AMusic%2Fsid`), décodé — c'est ce que l'utilisateur a
  // choisi et ce qu'il s'attend à retrouver dans sa bibliothèque.
  final destRoot =
      Directory(p.join(root.path, _androidTreeName(uri)));
  await destRoot.create(recursive: true);
  LocalOps.instance.begin(LocalOpKind.import, name: _androidTreeName(uri));
  try {
    try {
      await channel.invokeMethod<int>(
          'copyTree', {'uri': uri, 'dest': destRoot.path});
    } catch (e) {
      res.errors.add('$e');
      return res;
    }
    await registerImportedFolder(destRoot, res);
    return res;
  } finally {
    LocalOps.instance.end();
  }
}

/// Le nom lisible d'une URI d'arbre SAF. Repli sur « import » plutôt qu'un nom
/// vide: un dossier sans nom serait la RACINE des imports, et y déverser des
/// fichiers mélangerait cet import à tous les autres.
@visibleForTesting
String androidTreeName(String uri) => _androidTreeName(uri);

String _androidTreeName(String uri) {
  final decoded = Uri.decodeComponent(uri.split('/').last);
  // « primary:Music/sid » → « sid »; « primary: » (la racine) → rien.
  final afterColon =
      decoded.contains(':') ? decoded.split(':').last : decoded;
  final last = afterColon.split('/').where((s) => s.isNotEmpty).toList();
  final name = last.isEmpty ? '' : last.last;
  return name.isEmpty ? 'import' : name;
}

/// La feuille du bouton « + »: fichiers ou dossier. Les deux gestes existent
/// déjà à l'accueil; ici ils sont sous la main, là où l'on REGARDE ses imports.
Future<void> showLocalImportSheet(BuildContext context) async {
  final l10n = context.l10n;
  final choice = await showModalBottomSheet<int>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.library_add_outlined),
            title: Text(l10n.localImportFiles),
            onTap: () => Navigator.pop(ctx, 0),
          ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text(l10n.localImportFolder),
            onTap: () => Navigator.pop(ctx, 1),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 0) {
    await pickAndImportFiles(context);
  } else {
    await pickAndImportFolder(context);
  }
}

/// Racine PÉRENNE des imports locaux — `<support>/local/`. Distincte de
/// `opened/` (jetable, purgé) et de `Caches/local_archives/` (cache d'archives
/// simplement OUVERTES, purgeable par l'OS).
Future<Directory> localImportsDir() async {
  // Linux et Windows: sous `Documents/Rewamp/local`, visible et parcourable,
  // au lieu du dossier de support caché. Voir storage_roots.dart.
  if (usesRewampFolder) {
    return Directory(p.join((await rewampDocumentsDir()).path, 'local'));
  }
  final support = await getApplicationSupportDirectory();
  return Directory(p.join(support.path, 'local'));
}

/// Un fichier extrait/copié est-il une PISTE audio ? Même règle que
/// l'extraction d'archive ouverte: le suffixe OU le jeton de préfixe Amiga
/// (`mdat.NAME` joue, son compagnon `smpl.NAME` non).
bool _isM3u(String path) {
  final e = p.extension(path).replaceFirst('.', '').toLowerCase();
  return e == 'm3u' || e == 'm3u8';
}

/// L'extension AUDIO d'un fichier, ou null s'il n'en est pas un. Publique
/// parce que la suppression partagée en a besoin pour distinguer une PISTE
/// d'un COMPAGNON (voir local_delete.dart).
String? localAudioFormatOf(String path) {
  final base = p.basename(path);
  if (base.startsWith('.')) return null;
  final ext = p.extension(base).replaceFirst('.', '').toLowerCase();
  if (RewampDb.kExtractedAudioExts.contains(ext)) return ext;
  final prefix = base.contains('.') ? base.split('.').first.toLowerCase() : '';
  if (prefix.isNotEmpty && RewampDb.kExtractedAudioExts.contains(prefix)) {
    return prefix;
  }
  return null;
}

/// Destination sans écrasement: un fichier déjà là de MÊME taille est réputé
/// identique (la clé nom+taille est déjà celle du cache d'archives) et
/// réutilisé; sinon « nom (2).ext ».
Future<File> _destFor(String destPath, int srcLen) async {
  var f = File(destPath);
  var n = 1;
  while (await f.exists()) {
    if (await f.length() == srcLen) return f; // déjà importé, réutiliser
    n++;
    final dir = p.dirname(destPath);
    final stem = p.basenameWithoutExtension(destPath);
    final ext = p.extension(destPath);
    f = File(p.join(dir, '$stem ($n)$ext'));
  }
  return f;
}

class LocalImportResult {
  int tracks = 0;   // pistes enregistrées
  int albums = 0;   // albums construits depuis un M3U importé
  int skipped = 0;  // fichiers non-audio ignorés (non copiés)
  final errors = <String>[];
  /// Chemin SOURCE → ce qu'il est devenu sous `local/`: le fichier copié, ou
  /// le DOSSIER d'extraction pour une archive. L'appelant qui importe pour
  /// rendre une identité pérenne (voir library_identity.dart) doit savoir où
  /// pointer désormais, et le déduire du nom échoue dès qu'un homonyme a
  /// forcé un suffixe (« nom (2).ext », « nom (2)/ »).
  final destinations = <String, String>{};
}

/// Une piste à enregistrer — accumulée pendant la copie/extraction, écrite
/// par [_registerAll] en une transaction.
@visibleForTesting
class LocalImportPendingTrack {
  final String filePath;
  final String relPath;
  final String origin;
  final String formatExt;
  /// Album auquel un M3U voisin rattache cette piste (voir [_applyM3uAlbums]).
  /// Non nul ⇒ la piste n'a PAS d'entrée de bibliothèque à elle: c'est
  /// l'ALBUM qui en a une.
  String? album;
  String? artist;
  int?    position;
  String? title;
  LocalImportPendingTrack(this.filePath, this.relPath, this.origin, this.formatExt);
}

/// Un album construit depuis un M3U importé.
@visibleForTesting
class LocalImportPendingAlbum {
  final String name;
  final String firstTrackPath;   // pour la pochette
  const LocalImportPendingAlbum(this.name, this.firstTrackPath);
}

/// Un tag GLOBAL d'un `!tags.m3u` vgmstream: `# @ALBUM …`, `# @ARTIST …`.
String? _m3uGlobalTag(String content, String tag) {
  final m = RegExp('^#\\s*@\\s*$tag%?\\s+(.+)\$',
          caseSensitive: false, multiLine: true)
      .firstMatch(content);
  final v = m?.group(1)?.trim();
  return (v == null || v.isEmpty) ? null : v;
}

/// Le nom de l'album que porte un M3U.
///
/// `@ALBUM` d'abord — un `!tags.m3u` vgmstream le donne, et c'est le VRAI
/// titre. Le nom du FICHIER ensuite… sauf quand il ne nomme rien: un rip
/// joshw appelle sa liste `!tags.m3u`, et « !tags » n'est pas un titre
/// d'album. Le dossier est alors le meilleur repli — c'est lui que le rip
/// nomme d'après le jeu.
String _m3uAlbumName(String content, String m3uPath, String dir) {
  final tagged = _m3uGlobalTag(content, 'ALBUM');
  if (tagged != null) return tagged;
  // ⚠️ `#EXTALB:` — l'autre vocabulaire. `@ALBUM` est le tag vgmstream
  // (séparé par un ESPACE); `#EXTALB` est la directive du M3U étendu (séparée
  // par un `:`), et c'est celle qu'écrivent les rips faits à la main. Sans
  // elle, « Day of the Tentacle (Maniac Mansion II) » devenait le NOM DU
  // FICHIER de la playlist.
  final ext = parseM3uInfo(content).album;
  if (ext != null && ext.isNotEmpty) return ext;
  final stem = p.basenameWithoutExtension(m3uPath);
  final bare = stem.replaceAll(RegExp(r'^[!_\s]+'), '').toLowerCase();
  if (bare.isEmpty || bare == 'tags' || bare == 'playlist') {
    final folder = p.basename(dir);
    if (folder.isNotEmpty) return folder;
  }
  return stem;
}

/// Ce qu'un lot devient une fois les M3U pris en compte.
@visibleForTesting
class LocalImportM3uPlan {
  final List<LocalImportPendingTrack> tracks;
  final List<LocalImportPendingAlbum> albums;
  const LocalImportM3uPlan(this.tracks, this.albums);
}

/// Enregistre le LOT: pour chaque piste, la ligne `tracks` (chemin relatif +
/// provenance + pochette découverte) puis l'entonnoir bibliothèque — les DEUX
/// écritures du geste « Ajouter à la bibliothèque » (LocalDb.addToLibrary +
/// SyncService.recordTrackMembership), jamais l'une sans l'autre (la leçon
/// des quatre portes d'entrée). Tout dans UNE transaction (voir l'en-tête).
///
/// La pochette est découverte À L'IMPORT et PERSISTÉE: sans ça chaque
/// affichage repartait de zéro (flash de placeholder à chaque changement de
/// piste) et la notification restait au générique. Un listing par DOSSIER,
/// résolution pure par piste (les noms `<piste>.jpg` restent par-piste, les
/// génériques cover/folder/unique servent tout le dossier).
Future<void> _registerAll(List<LocalImportPendingTrack> items, LocalImportResult res,
    [List<LocalImportPendingAlbum> albums = const []]) async {
  if (items.isEmpty) return;
  final listings = <String, List<String>>{};
  Future<List<String>> listingOf(String dir) async =>
      listings[dir] ??= await Directory(dir)
          .list(followLinks: false)
          .where((e) => e is File)
          .map((e) => e.path)
          .toList();
  LocalOps.instance.phase(LocalOpPhase.registering, total: items.length);
  var registered = 0;
  await LocalDb.instance.runBatchWrites((db) async {
    for (final it in items) {
      LocalOps.instance.progress(registered++);
      try {
        final title = p.basename(it.filePath);
        String? artwork;
        try {
          artwork = ArtworkCache.localArtworkFromListing(
              await listingOf(p.dirname(it.filePath)), it.filePath);
        } catch (_) {}
        await LocalDb.instance.upsertTrack(
          db:           db,
          filePath:     it.filePath,
          title:        it.title ?? title,
          artist:       it.artist,
          metaAlbum:    it.album,
          position:     it.position,
          formatExt:    it.formatExt,
          source:       'local',
          artworkUrl:   artwork,
          localRelPath: it.relPath,
          localOrigin:  it.origin,
        );
        res.tracks++;
        // Une piste d'ALBUM n'a pas d'entrée de bibliothèque à elle: l'album
        // en a UNE (plus bas). Et elle ne part pas au compte non plus — le
        // pull recréerait alors une entrée « morceau » par piste et l'album se
        // doublerait de sa propre tracklist en bibliothèque.
        if (it.album != null) continue;
        final refId = localImportRefId(it.filePath);
        // Un RÉ-import répare: l'entrée qu'une version antérieure avait écrite
        // sous l'autre convention part, sinon le fichier se dédouble en
        // bibliothèque.
        await LocalDb.instance
            .removeStaleImportEntry('${it.filePath}?subsong=0', db: db);
        await LocalDb.instance.addToLibrary(
          db:         db,
          notify:     false,
          type:       'track',
          refId:      refId,
          name:       title,
          formatExt:  it.formatExt,
          filename:   title,
          artworkUrl: artwork,
        );
        await SyncService.recordTrackMembership(
          db:        db,
          refId:     refId,
          value:     true,
          title:     title,
          formatExt: it.formatExt,
        );
      } catch (e) {
        res.errors.add('${p.basename(it.filePath)}: $e');
      }
    }
    for (final a in albums) {
      try {
        String? art;
        try {
          art = ArtworkCache.localArtworkFromListing(
              await listingOf(p.dirname(a.firstTrackPath)), a.firstTrackPath);
        } catch (_) {}
        await LocalDb.instance.addToLibrary(
          db:         db,
          notify:     false,
          type:       'album',
          // Un album local n'a pas d'uuid serveur: la clé est son NOM (voir
          // albumLibraryRefId). Limite héritée et assumée — deux albums
          // importés du même nom partagent une ligne.
          refId:      albumLibraryRefId(a.name, null),
          name:       a.name,
          artworkUrl: art,
        );
        res.albums++;
      } catch (e) {
        res.errors.add('${a.name}: $e');
      }
    }
  });
}

/// Applique les M3U du lot: ils décident QUELLES pistes existent, et les
/// regroupent en ALBUM.
///
/// **Le M3U fait autorité.** Un rip livre couramment plusieurs VERSIONS du
/// même morceau — Touhou 06 (joshw_pc) a pour chaque piste un `.pos`, un
/// `.wav`, un `.mid` et un `.mid.tag` — et son `!tags.m3u` ne liste que l'une
/// d'elles. Prendre « tout ce qui a une extension audio » donnait donc l'album
/// en double, une fois en WAV sans boucle et une fois en MIDI. Ce que le M3U
/// nomme est la piste; ce qu'il ne nomme pas, dans SON dossier, est un
/// compagnon (le `.wav` est ici le CORPS du `.pos`, pas un morceau à part).
///
/// Deux mouvements, et le second est celui qui compte:
///  - **promotion**: une entrée du M3U devient une piste même si son extension
///    n'est dans aucune liste — `pos` est volontairement absente de
///    `kVgmstreamExts` (trop générique pour être revendiquée auprès du
///    système), et pourtant vgmstream a un meta dédié qui ouvre le `.wav`
///    voisin et lui pose ses points de boucle. [canPlay] (le registre complet:
///    extension + en-tête) confirme, exactement comme la seconde chance de
///    `isBulkQueueCandidate`;
///  - **démotion**: les pistes du dossier du M3U qu'il ne nomme pas sortent du
///    lot. Elles restent COPIÉES — un compagnon doit être là — mais ne sont
///    plus des morceaux.
///
/// Un M3U qui ne désigne QU'UN fichier décrit ses SOUS-CHANSONS et n'est pas
/// un album (autorité de `m3uSubsongsFor` à la lecture): il ne promeut ni ne
/// démote rien.
///
/// Rapprochement par BASENAME: le parseur assainit les chemins qu'il écrit et
/// ils ne valent pas caractère pour caractère ceux du disque.
@visibleForTesting
Future<LocalImportM3uPlan> applyM3uAlbums(
  List<LocalImportPendingTrack> tracks,
  List<LocalImportPendingTrack> others,
  List<String> m3uPaths, {
  bool Function(String)? canPlay,
}) async {
  if (m3uPaths.isEmpty) return LocalImportM3uPlan(tracks, const []);
  // ⚠️ Clé = DOSSIER + nom, jamais le nom seul. Un M3U ne fait la loi que dans
  // SON dossier, et un lot d'import en mélange plusieurs (des archives dépliées
  // chacune dans la sienne, plus la racine). Clefer par nom seul faisait deux
  // choses fausses à la fois: deux fichiers de même nom dans deux dossiers se
  // ÉCRASAIENT dans la table (le dernier gagnait), puis le M3U du PREMIER
  // album réclamait le fichier du SECOND — et lui posait SON nom d'album, SON
  // artiste et une position. Les rips nomment leurs pistes « 01 Title.vgz »:
  // la collision n'est pas théorique. C'est la mécanique qui met l'album et
  // l'artiste d'un morceau sur les premières pistes d'un autre.
  //
  // Le rapprochement reste par NOM à l'intérieur du dossier: le chemin
  // qu'écrit le parseur passe par `_sanitize` et ne vaut pas caractère pour
  // caractère celui du fichier sur disque.
  String keyOf(String dir, String base) =>
      '${p.normalize(dir)}${p.separator}${base.toLowerCase()}';
  final byKey = <String, LocalImportPendingTrack>{
    for (final t in [...tracks, ...others])
      keyOf(p.dirname(t.filePath), p.basename(t.filePath)): t,
  };
  final albums = <LocalImportPendingAlbum>[];
  final promoted = <LocalImportPendingTrack>{};
  final claimed = <String>{};        // clés (dossier + nom) nommées par un M3U
  final ruledDirs = <String>{};      // dossiers dont un M3U d'album fait la loi

  for (final m3u in m3uPaths) {
    try {
      final content = await RewampDb.readM3uText(File(m3u));
      final subs = RewampDb.parseM3uToSubsongs(content, p.dirname(m3u));
      if (subs.isEmpty) continue;
      if ({for (final s in subs) s.filePath}.length < 2) continue;
      final dir = p.dirname(m3u);
      final name = _m3uAlbumName(content, m3u, dir);
      final artist = _m3uGlobalTag(content, 'ARTIST');
      var pos = 0;
      LocalImportPendingTrack? first;
      for (final sub in subs) {
        final key = keyOf(dir, p.basename(sub.filePath));
        final t = byKey[key];
        if (t == null || t.album != null) continue;
        claimed.add(key);
        // Fichier copié mais pas retenu comme piste: le M3U le désigne, le
        // moteur confirme, il devient une piste.
        if (!tracks.contains(t)) {
          if (!(canPlay?.call(t.filePath) ?? false)) continue;
          promoted.add(t);
        }
        t.album = name;
        t.artist = artist;
        t.position = pos++;
        if ((sub.title ?? '').isNotEmpty) t.title = sub.title;
        first ??= t;
      }
      if (first != null) {
        albums.add(LocalImportPendingAlbum(name, first.filePath));
        ruledDirs.add(dir);
      }
    } catch (_) {/* M3U illisible: les pistes restent unitaires */}
  }
  if (albums.isEmpty) return LocalImportM3uPlan(tracks, const []);

  final out = <LocalImportPendingTrack>[
    for (final t in tracks)
      // Démotion: dans un dossier régi par un M3U d'album, ce qu'il ne nomme
      // pas n'est pas une piste.
      if (!ruledDirs.contains(p.dirname(t.filePath)) ||
          claimed.contains(keyOf(p.dirname(t.filePath), p.basename(t.filePath))))
        t,
    ...promoted,
  ];
  // Ordre stable: dossier puis position d'album, sinon le nom.
  out.sort((a, b) {
    final d = p.dirname(a.filePath).compareTo(p.dirname(b.filePath));
    if (d != 0) return d;
    final pa = a.position, pb = b.position;
    if (pa != null && pb != null) return pa.compareTo(pb);
    if (pa != null) return -1;
    if (pb != null) return 1;
    return a.filePath.compareTo(b.filePath);
  });
  return LocalImportM3uPlan(out, albums);
}

/// Importe une liste de FICHIERS (le geste « Importer des fichiers »). Les
/// archives (`kLocalArchiveExts`) sont dépliées en dossier virtuel
/// `local/<nom>/…`; le reste est copié à la racine — TOUT le reste, pas
/// seulement l'audio: une multi-sélection embarque ses COMPAGNONS (la
/// pochette `X.jpg` à côté de `X.mid`, la banque `smpl.*` d'un `mdat.*`), et
/// ne copier que les pistes perdait la pochette comme la banque. Copie
/// d'abord, enregistrement ENSUITE (la découverte de pochette regarde les
/// voisins — même leçon que l'import de dossier).
///
/// ⚠️ **Le compagnon d'une ARCHIVE va DANS son dossier d'extraction**, pas à
/// la racine: `Super Mario Land (GB)….zip` + `Super Mario Land (GB)….png`
/// posés CÔTE À CÔTE deviennent `local/Super Mario Land (GB)…/` d'un côté et
/// une image à la racine de l'autre — deux dossiers différents, donc une
/// pochette que la découverte locale ne voit jamais. Deux passes: les
/// archives d'abord (elles créent les dossiers), le reste ensuite, routé vers
/// le dossier de l'archive dont il porte le nom.
Future<LocalImportResult> importLocalFiles(List<String> paths) async {
  // Retour visuel hors écran (LocalOps): le geste rend la main, le bandeau
  // suit — y compris si l'on quitte l'écran Local et qu'on y revient.
  LocalOps.instance.begin(LocalOpKind.import,
      name: paths.length == 1 ? p.basename(paths.first) : null);
  try {
    return await _importLocalFilesInner(paths);
  } finally {
    LocalOps.instance.end();
  }
}

Future<LocalImportResult> _importLocalFilesInner(List<String> paths) async {
  final res = LocalImportResult();
  final root = await localImportsDir();
  await root.create(recursive: true);
  final pending = <LocalImportPendingTrack>[];
  final others  = <LocalImportPendingTrack>[];   // copiés, pas (encore) pistes
  final m3us = <String>[];
  // Nom d'archive (avec son extension) → dossier d'extraction. Rempli par la
  // première passe, consulté par la seconde. L'ordre du sélecteur n'est pas
  // garanti: sans ces deux passes, un `.png` listé AVANT son `.zip` ne
  // trouverait aucun dossier où aller.
  final archiveDirs = <String, String>{};
  final rest = <String>[];
  for (final src in paths) {
    try {
      final f = File(src);
      if (!await f.exists()) continue;
      final base = p.basename(src);
      if (base.startsWith('.')) {
        res.skipped++;
        continue;
      }
      final ext = p.extension(base).replaceFirst('.', '').toLowerCase();
      if (RewampDb.kLocalArchiveExts.contains(ext)) {
        LocalOps.instance.phase(LocalOpPhase.extracting);   // natif, sans compte
        final dir = await _importArchive(f, root, res, pending, others, m3us);
        if (dir != null) {
          archiveDirs[base] = dir;
          res.destinations[src] = dir;
        }
        continue;
      }
      rest.add(src);
    } catch (e) {
      res.errors.add('$src: $e');
    }
  }
  LocalOps.instance.phase(LocalOpPhase.copying, total: rest.length);
  var copied = 0;
  for (final src in rest) {
    LocalOps.instance.progress(copied++);
    try {
      final f = File(src);
      final base = p.basename(src);
      final fmtSrc = localAudioFormatOf(src);
      // Un NON-audio qui porte le nom d'une archive importée est SA pochette
      // (ou ses notes): il va dans son dossier. Une PISTE, elle, reste à la
      // racine même si elle partage ce nom — c'est un morceau à part entière.
      String? into;
      if (fmtSrc == null) {
        for (final e in archiveDirs.entries) {
          if (localImportCompanionClaims(e.key, base)) {
            into = e.value;
            break;
          }
        }
      }
      final dest = await _destFor(
          p.join(into ?? root.path, base), await f.length());
      if (!await dest.exists()) await f.copy(dest.path);
      res.destinations[src] = dest.path;
      final fmt = localAudioFormatOf(dest.path);
      if (fmt == null) {
        res.skipped++; // compagnon (pochette, banque, notes): copié, pas une piste
        if (_isM3u(dest.path)) m3us.add(dest.path);
        others.add(LocalImportPendingTrack(dest.path,
            p.relative(dest.path, from: root.path), 'picker',
            p.extension(dest.path).replaceFirst('.', '').toLowerCase()));
      } else {
        pending.add(LocalImportPendingTrack(
            dest.path, p.relative(dest.path, from: root.path), 'picker', fmt));
      }
    } catch (e) {
      res.errors.add('$src: $e');
    }
  }
  final plan = await applyM3uAlbums(pending, others, m3us,
      canPlay: _engineCanPlay());
  await _registerAll(plan.tracks, res, plan.albums);
  return res;
}

/// Déplie une archive vers `local/<nom>/…` (stockage PÉRENNE — pas le cache
/// d'ouverture) et accumule chaque piste dans [pending]. Les images de
/// l'archive restent en place: la découverte de pochette locale les sert.
/// Rend le dossier d'extraction (null si l'extraction a échoué) — l'appelant
/// y route les compagnons posés à côté de l'archive.
Future<String?> _importArchive(File archive, Directory root,
    LocalImportResult res, List<LocalImportPendingTrack> pending,
    List<LocalImportPendingTrack> others, List<String> m3us,
    {Directory? relRoot}) async {
  // [root] est le PARENT du dossier d'extraction; [relRoot] la racine des
  // chemins relatifs enregistrés (celle des imports). Ils ne coïncident que
  // pour une archive importée seule à la racine — dans un DOSSIER importé,
  // l'archive se déplie à côté d'elle, plusieurs niveaux sous la racine.
  final rel = relRoot ?? root;
  final stem = p.basenameWithoutExtension(archive.path);
  var destDir = Directory(p.join(root.path, stem));
  var n = 1;
  // Une AUTRE archive du même nom ne doit pas fusionner: suffixe. La MÊME
  // archive (marqueur + contenu déjà là) est réimportée par-dessus sans mal —
  // l'extraction est idempotente et les lignes upsertent.
  while (await File(p.join(destDir.path, '.import_src')).exists()) {
    final prev = await File(p.join(destDir.path, '.import_src')).readAsString();
    if (prev == '${p.basename(archive.path)}|${await archive.length()}') break;
    n++;
    destDir = Directory(p.join(root.path, '$stem ($n)'));
  }
  await destDir.create(recursive: true);
  final (rc, err) = await RewampDb.extractArchiveTo(archive.path, destDir.path);
  if (rc != 0) {
    res.errors.add('${p.basename(archive.path)}: $err');
    return null;
  }
  // Compagnons posés À CÔTÉ de l'archive sur le disque et NON sélectionnés:
  // un rip livre couramment `JEU.zip` + `JEU.png`, et n'ouvrir que l'archive
  // laissait la pochette derrière. Le voisinage n'est lisible que quand le
  // sélecteur rend un vrai chemin (bureau); sur mobile il rend une copie de
  // bac à sable seule, et la boucle ne trouve simplement rien.
  try {
    final srcBase = p.basename(archive.path);
    await for (final e
        in archive.parent.list(followLinks: false)) {
      if (e is! File) continue;
      final b = p.basename(e.path);
      if (b == srcBase || localAudioFormatOf(e.path) != null) continue;
      if (!localImportCompanionClaims(srcBase, b)) continue;
      final dest = File(p.join(destDir.path, b));
      if (!await dest.exists()) await e.copy(dest.path);
    }
  } catch (_) {}
  await File(p.join(destDir.path, '.import_src'))
      .writeAsString('${p.basename(archive.path)}|${await archive.length()}');
  await for (final e in destDir.list(recursive: true, followLinks: false)) {
    if (e is! File) continue;
    final fmt = localAudioFormatOf(e.path);
    if (fmt == null) {
      // Le M3U d'un rip vit DANS l'archive: c'est lui qui en fait un album.
      if (_isM3u(e.path)) m3us.add(e.path);
      others.add(LocalImportPendingTrack(
          e.path, p.relative(e.path, from: rel.path), 'archive',
          p.extension(e.path).replaceFirst('.', '').toLowerCase()));
      continue;                // autres compagnons, images, textes…
    }
    pending.add(LocalImportPendingTrack(
        e.path, p.relative(e.path, from: rel.path), 'archive', fmt));
  }
  return destDir.path;
}

/// Importe un DOSSIER entier (le geste « Importer un dossier »): copie
/// récursive sous `local/<nomDuDossier>/…`, arborescence préservée. Sur iOS la
/// copie doit se faire PENDANT la session security-scoped du sélecteur — c'est
/// le cas: l'appelant nous passe le chemin tout juste rendu par le picker et
/// on copie immédiatement, sans bookmark persistant.
Future<LocalImportResult> importLocalFolder(String folderPath) async {
  LocalOps.instance.begin(LocalOpKind.import, name: p.basename(folderPath));
  try {
    return await _importLocalFolderInner(folderPath);
  } finally {
    LocalOps.instance.end();
  }
}

Future<LocalImportResult> _importLocalFolderInner(String folderPath) async {
  final res = LocalImportResult();
  final src = Directory(folderPath);
  if (!await src.exists()) return res;
  final root = await localImportsDir();
  final destRoot = Directory(p.join(root.path, p.basename(folderPath)));
  await destRoot.create(recursive: true);
  // DEUX passes: tout COPIER d'abord, ENREGISTRER ensuite. La découverte de
  // pochette à l'enregistrement regarde les voisins — enregistrer pendant la
  // copie ratait l'image du dossier quand elle arrivait après les modules
  // (l'ordre d'énumération n'est pas alphabétique).
  // Compte inconnu à l'avance (énumérer deux fois coûterait autant que
  // copier sur un gros arbre): barre indéterminée, compteur seul.
  LocalOps.instance.phase(LocalOpPhase.copying);
  var copied = 0;
  await for (final e in src.list(recursive: true, followLinks: false)) {
    if (e is! File) continue;
    final rel = p.relative(e.path, from: src.path);
    if (p.basename(rel).startsWith('.')) continue;
    try {
      final dest = File(p.join(destRoot.path, rel));
      await dest.parent.create(recursive: true);
      if (!await dest.exists() ||
          await dest.length() != await e.length()) {
        await e.copy(dest.path);
      }
    } catch (err) {
      res.errors.add('$rel: $err');
    }
    LocalOps.instance.progress(++copied);
  }
  await registerImportedFolder(destRoot, res);
  return res;
}

/// Enregistre ce qui est DÉJÀ sous [destRoot] — la seconde passe d'un import de
/// dossier, isolée parce que la COPIE n'a pas toujours lieu en Dart: sur
/// Android elle est faite par le natif à travers le Storage Access Framework
/// (voir [importAndroidTree]), le seul chemin qui puisse lire un dossier choisi
/// par l'utilisateur sans permission de stockage déclarée.
Future<void> registerImportedFolder(
    Directory destRoot, LocalImportResult res) async {
  final root = await localImportsDir();
  final pending = <LocalImportPendingTrack>[];
  final others  = <LocalImportPendingTrack>[];
  final m3us = <String>[];
  // Les ARCHIVES du dossier d'abord, dépliées À CÔTÉ d'elles (dossier virtuel
  // du nom de l'archive, comme pour une archive importée seule): l'import de
  // dossier copiait tout tel quel puis ne classait que par extension AUDIO —
  // un `.zip` n'en est pas une, donc un dossier de rips zippés (le cas des
  // packs MT-32: `jeu.zip` = `.mid` + `.syx` + notes) donnait zéro piste et
  // « Rien de jouable » (2026-09-12). Notre copie de l'archive part une fois
  // extraite: son contenu la remplace, et la garder ferait re-déplier à
  // chaque réenregistrement. Liste figée AVANT extraction: on ne parcourt pas
  // un arbre qu'on est en train de remplir.
  final archives = <File>[];
  await for (final e in destRoot.list(recursive: true, followLinks: false)) {
    if (e is! File || p.basename(e.path).startsWith('.')) continue;
    final ext = p.extension(e.path).replaceFirst('.', '').toLowerCase();
    if (RewampDb.kLocalArchiveExts.contains(ext)) archives.add(e);
  }
  if (archives.isNotEmpty) LocalOps.instance.phase(LocalOpPhase.extracting);
  for (final a in archives) {
    final dir = await _importArchive(a, a.parent, res, pending, others, m3us,
        relRoot: root);
    if (dir != null) {
      try { await a.delete(); } catch (_) {}
    }
  }
  await for (final e in destRoot.list(recursive: true, followLinks: false)) {
    if (e is! File) continue;
    if (p.basename(e.path).startsWith('.')) continue;
    // Une archive restée là (extraction en échec) n'est ni piste ni compagnon.
    if (RewampDb.kLocalArchiveExts.contains(
        p.extension(e.path).replaceFirst('.', '').toLowerCase())) {
      continue;
    }
    // Ce que les archives ont déjà enregistré ne doit pas l'être deux fois.
    if (pending.any((t) => t.filePath == e.path) ||
        others.any((t) => t.filePath == e.path)) {
      continue;
    }
    final fmt = localAudioFormatOf(e.path);
    if (fmt == null) {
      res.skipped++; // images (pochettes), compagnons: copiés, pas des pistes
      if (_isM3u(e.path)) m3us.add(e.path);
      others.add(LocalImportPendingTrack(e.path,
          p.relative(e.path, from: root.path), 'folder',
          p.extension(e.path).replaceFirst('.', '').toLowerCase()));
    } else {
      pending.add(LocalImportPendingTrack(
          e.path, p.relative(e.path, from: root.path), 'folder', fmt));
    }
  }
  final plan = await applyM3uAlbums(pending, others, m3us,
      canPlay: _engineCanPlay());
  await _registerAll(plan.tracks, res, plan.albums);
}

// ── Suppression ─────────────────────────────────────────────────────────────

/// Un compagnon est « revendiqué » par une piste quand son nom en dérive:
/// même radical (`X.jpg` ↔ `X.mid`), nom complet (`X.mid.jpg` — la forme
/// artBasenameFor), ou même reste après le premier point pour la forme
/// préfixe Amiga (`smpl.Y` ↔ `mdat.Y`).
/// Publique (et non plus seulement `@visibleForTesting`): la suppression
/// PARTAGÉE entre imports et téléchargements en dépend — c'est elle qui décide
/// qu'un compagnon part ou reste. Voir local_delete.dart.
bool localImportCompanionClaims(String audioBase, String companionBase) {
  final a = audioBase.toLowerCase();
  final c = companionBase.toLowerCase();
  final aStem = p.basenameWithoutExtension(a);
  final cStem = p.basenameWithoutExtension(c);
  if (cStem == a || cStem == aStem) return true;
  // Forme PRÉFIXE Amiga: `mdat.NAME` et `smpl.NAME` désignent le même morceau,
  // le format est AVANT le point et le nom après. ⚠️ Le test ne vaut QUE pour
  // cette forme: écrit sans garde, « même partie après le premier point » veut
  // dire « même extension », donc `cbmt.zip` réclamait `kq5mt.zip` et chaque
  // archive d'un dossier se faisait copier toutes ses voisines (constaté dans
  // `local/midimt32/cbmt/` le 2026-09-12).
  final aDot = a.indexOf('.');
  final cDot = c.indexOf('.');
  if (aDot > 0 && cDot > 0 &&
      isUadePrefixToken(a.substring(0, aDot)) &&
      isUadePrefixToken(c.substring(0, cDot)) &&
      a.substring(aDot + 1) == c.substring(cDot + 1)) {
    return true;
  }
  return false;
}

/// Retire l'entrée de bibliothèque d'un fichier importé — les DEUX formes.
///
/// ⚠️ L'import écrit `<chemin>` pour un fichier CONTENEUR et
/// `<chemin>?subsong=0` sinon (voir [localImportRefId]): ne retirer qu'une
/// forme laisserait l'autre en place, et le compte la ferait revivre au
/// prochain pull — la leçon du favori fantôme. On ne cherche pas laquelle
/// existe (une reconstruction de la sonde pourrait répondre autrement
/// qu'à l'import): on retire les deux.
/// Les formes d'identité sous lesquelles [filePath] est RÉELLEMENT en
/// bibliothèque — le chemin nu, et la forme `?subsong=0` qu'une version
/// antérieure écrivait. Lu AVANT toute transaction: `isInLibrary` passe par la
/// connexion principale, qui se bloquerait depuis un `transaction()`.
///
/// ⚠️ On ne pousse un retrait QUE pour une forme présente. Pousser les deux à
/// l'aveugle doublait les allers-retours `set_library` pour rien — la moitié
/// visaient une entrée que le compte n'a jamais eue. L'écran Stockage faisait
/// déjà le bon geste; celui-ci non.
Future<List<String>> _libraryFormsOf(String filePath) async {
  final out = <String>[];
  for (final refId in [filePath, '$filePath?subsong=0']) {
    if (await LocalDb.instance.isInLibrary('track', refId)) out.add(refId);
  }
  return out;
}

Future<void> _forgetLibraryEntry(String filePath) async {
  final forms = await _libraryFormsOf(filePath);
  if (forms.isEmpty) return;
  await LocalDb.instance.runBatchWrites((db) async {
    for (final refId in forms) {
      await SyncService.recordTrackMembership(
          db: db, refId: refId, value: false);
      await LocalDb.instance
          .removeFromLibrary('track', refId, db: db, notify: false);
    }
  });
}

/// Supprime UNE piste importée: file d'attente/lecteur d'abord, retrait
/// bibliothèque + synchro (sinon le compte la fait revivre au prochain pull —
/// la leçon du favori fantôme), lignes locales + fichier, puis les compagnons
/// que plus personne ne revendique.
Future<void> deleteLocalImportTrack(String filePath) async {
  LocalOps.instance.begin(LocalOpKind.delete, name: p.basename(filePath));
  try {
    await PlayerController.current?.handleDeletedTrack(filePath);
    await _forgetLibraryEntry(filePath);
    await RewampDb.deleteLocalTrack(filePath);
    // ⚠️ `prune: false`: dans l'arbre des IMPORTS, un dossier est un objet que
    // l'utilisateur a créé et range (local_manage.dart). Le vider n'autorise
    // pas à l'effacer — voir pruneEmptyDirs.
    await cleanCompanionsAfterDelete(p.dirname(filePath), p.basename(filePath),
        root: (await localImportsDir()).path, prune: false);
  } finally {
    LocalOps.instance.end();
  }
}

/// Supprime un DOSSIER importé (sous-arbre ENTIER). [childPrefix] est le
/// préfixe de chemin relatif du dossier, terminé par '/'. Chaque piste passe
/// par le même retrait bibliothèque/synchro que la suppression unitaire, puis
/// le répertoire part en bloc — compagnons et pochettes avec lui.
Future<void> deleteLocalImportFolder(String childPrefix) async {
  final rel = childPrefix.endsWith('/')
      ? childPrefix.substring(0, childPrefix.length - 1)
      : childPrefix;
  LocalOps.instance.begin(LocalOpKind.delete, name: p.basename(rel));
  try {
    await _deleteLocalImportFolderInner(childPrefix, rel);
  } finally {
    LocalOps.instance.end();
  }
}

Future<void> _deleteLocalImportFolderInner(String childPrefix, String rel) async {
  final root = await localImportsDir();
  final dirPath = p.join(root.path, rel);
  // ⚠️ UNE seule notification pour tout le sous-arbre, pas une par piste.
  //
  // `handleDeletedTrack` par fichier faisait, pour CHACUN: un parcours complet
  // de la file (avec des lectures en base par entrée) et — quand l'entrée
  // courante tombait — un `_playAt` qui CHARGE et JOUE la piste suivante…
  // elle-même sur le point d'être supprimée au tour d'après. D'où les deux
  // symptômes rapportés: effacer un dossier importé relançait la lecture, et
  // la suppression traînait. `handleDeletedAlbum` fait le même travail en
  // mode PRÉFIXE, une fois.
  await PlayerController.current?.handleDeletedAlbum(dirPath);
  final rows = await LocalDb.instance.getLocalImports();
  // Ce qui est en bibliothèque, lu d'abord (hors transaction — voir
  // _libraryFormsOf), puis TOUT en UN commit: un retrait par forme présente,
  // l'outbox alimentée dans le même commit, UNE notification à la fin. La
  // version précédente faisait, par piste, deux retraits à l'aveugle chacun
  // dans sa propre écriture, entrelacés avec le drain de l'outbox et les
  // re-requêtes des écrans sur la même file sqflite — un dossier de N pistes
  // coûtait ~6N opérations de base sérialisées, plus 2N appels serveur.
  //
  // `recordTrackMembership` appelle `relPathOf` de l'intérieur: pour un
  // import local c'est un calcul de chemin pur (sous le dossier de support),
  // sa branche « requête tracks » ne s'exécute pas — sinon elle bloquerait
  // depuis la transaction.
  final forms = <String>[];
  for (final (relPath, t) in rows) {
    if (!relPath.startsWith(childPrefix)) continue;
    forms.addAll(await _libraryFormsOf(t.filePath));
  }
  if (forms.isNotEmpty) {
    LocalOps.instance.phase(LocalOpPhase.registering, total: forms.length);
    var n = 0;
    await LocalDb.instance.runBatchWrites((db) async {
      for (final refId in forms) {
        LocalOps.instance.progress(n++);
        await SyncService.recordTrackMembership(
            db: db, refId: refId, value: false);
        await LocalDb.instance
            .removeFromLibrary('track', refId, db: db, notify: false);
      }
    });
  }
  LocalOps.instance.phase(LocalOpPhase.deleting);   // le répertoire, en bloc
  await RewampDb.deleteLocalAlbumDir(dirPath);
  // ⚠️ Pas d'élagage des PARENTS ici. Supprimer `test/test2` remontait à
  // `test`, le trouvait vide et l'effaçait: le dossier que l'utilisateur avait
  // créé disparaissait parce qu'il en avait retiré le contenu. Voir
  // pruneEmptyDirs — `online/` appartient à l'app, `local/` à l'utilisateur.
  // Un seul coup de coude, APRÈS que tout est dans l'outbox: lancé plus tôt,
  // le drain prenait un instantané au milieu du lot, livrait la première
  // moitié, enchaînait une synchro COMPLÈTE (pull bibliothèque, historique,
  // état), et la seconde moitié attendait le cycle suivant — la « seconde
  // salve » de set_library visible dans les logs.
  SyncService.instance.kick();
}

/// Résume un import à l'utilisateur — un geste délibéré ne finit jamais en
/// silence, même quand rien n'était importable. Le messager est capturé AVANT
/// l'attente par l'appelant (patron _openLocalPaths): un contexte démonté
/// pendant la copie avalerait le message.
void reportImportOn(ScaffoldMessengerState messenger, AppLocalizations l10n,
    LocalImportResult res) {
  if (res.tracks > 0) {
    // Un import qui a construit des ALBUMS le dit: les pistes concernées ne
    // sont PAS dans l'onglet Morceaux, elles sont dans leur album — sans ça
    // le compte annoncé et ce qu'on trouve ensuite ne concordent pas.
    AppSnack.showOn(messenger, res.albums > 0
        ? l10n.localImportDoneAlbums(res.tracks, res.albums)
        : l10n.localImportDone(res.tracks));
  } else if (res.errors.isNotEmpty) {
    AppSnack.showOn(messenger, l10n.localImportFailed(res.errors.first));
  } else {
    AppSnack.showOn(messenger, l10n.homeNothingPlayable);
  }
}
