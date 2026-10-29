// Dossiers LIÉS: les fichiers de l'utilisateur, lus là où ils sont.
//
// Une racine est un dossier que l'app a le droit de lire — rien n'y est
// copié, rien n'y est écrit. Décisions (docs/local_roots_proposal.md):
//   * PARCOURU, pas indexé: aucune ligne `tracks` avant qu'un fichier ne
//     joue; ce qui est en base reste l'historique, les ♥ et les playlists;
//   * mais CHERCHABLE: une table des NOMS (`linked_entries`, chemin + nom +
//     taille + mtime, rien d'autre) est construite en arrière-plan quand la
//     racine est liée, et c'est elle que l'écran et la recherche lisent;
//   * l'IDENTITÉ d'un fichier lié est `(racine, chemin relatif)`, et c'est le
//     relatif seul qui alimente `ext_key` (LocalDb._relPathOf): le même
//     dossier Dropbox lié sur deux appareils donne les mêmes ♥.
//
// Phase 1 (2026-10-27): bureau seulement. Linux et Windows lisent le chemin
// tel quel; macOS (bac à sable) conserve un SIGNET à portée de sécurité et le
// rouvre au lancement (`rewamp/bookmarks`, AppDelegate.swift) — sans quoi
// l'accès est perdu au redémarrage. iOS (signet de Fichiers) et Android
// (arbre SAF + mise en scène) sont les phases suivantes: le modèle les
// accueille par `kind`, rien d'autre ne les connaît.
import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'engines.dart' show kEngines;
import 'local_db.dart';
import 'local_ops.dart';
import 'portable_path.dart';
import 'rewamp_db.dart' show RewampDb;

enum LocalRootKind {
  /// Un chemin natif lu tel quel (Linux, Windows).
  folder,

  /// Un chemin + un signet à portée de sécurité (macOS; iOS plus tard).
  bookmark,

  /// Un arbre SAF (Android) — pas encore.
  saf,
}

class LocalRoot {
  final String id;
  final LocalRootKind kind;
  final String label;

  /// Chemin natif absolu — pour un signet, celui résolu au DERNIER lancement.
  final String path;

  /// Signet (base64), `bookmark` seulement.
  final String? bookmark;
  final DateTime addedAt;

  /// Joignable MAINTENANT (dossier présent, signet résolu). Pas persisté.
  final bool available;

  /// Le dernier parcours a échoué: son message, pour l'écran. Pas persisté.
  final String? scanError;

  const LocalRoot({
    required this.id,
    required this.kind,
    required this.label,
    required this.path,
    this.bookmark,
    required this.addedAt,
    this.available = true,
    this.scanError,
  });

  LocalRoot copyWith({String? label, String? path, bool? available,
      String? bookmark, String? scanError, bool clearScanError = false}) =>
      LocalRoot(
        id: id,
        kind: kind,
        label: label ?? this.label,
        path: path ?? this.path,
        bookmark: bookmark ?? this.bookmark,
        addedAt: addedAt,
        available: available ?? this.available,
        scanError: clearScanError ? null : (scanError ?? this.scanError),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'label': label,
        'path': path,
        if (bookmark != null) 'bookmark': bookmark,
        'addedAt': addedAt.millisecondsSinceEpoch,
      };

  static LocalRoot? fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final path = j['path'];
    if (id is! String || path is! String || id.isEmpty || path.isEmpty) {
      return null;
    }
    return LocalRoot(
      id: id,
      kind: LocalRootKind.values.firstWhere((k) => k.name == j['kind'],
          orElse: () => LocalRootKind.folder),
      label: (j['label'] as String?) ?? p.basename(path),
      path: path,
      bookmark: j['bookmark'] as String?,
      addedAt: DateTime.fromMillisecondsSinceEpoch(
          (j['addedAt'] as num?)?.toInt() ?? 0),
    );
  }
}

/// Une ligne de la table des noms.
class LinkedEntry {
  final String rootId;
  /// Relatif PORTABLE ('/') à la racine.
  final String relPath;
  final int? size;
  final int? mtimeMs;
  const LinkedEntry(this.rootId, this.relPath, {this.size, this.mtimeMs});
  String get name => relPath.split('/').last;
}

/// Les extensions qu'on INDEXE: ce que les moteurs jouent, les archives qu'on
/// sait ouvrir, les playlists. Le reste (readme, images) n'entre pas dans la
/// table: la recherche porte sur de la musique. Un nom à préfixe Amiga
/// (`mdat.x`) se reconnaît à son PREMIER segment, règle du projet.
final Set<String> _kIndexedExts = {
  for (final e in kEngines) ...e.formats.map((x) => x.toLowerCase()),
  ...RewampDb.kLocalArchiveExts.map((x) => x.toLowerCase()),
  'm3u', 'm3u8',
};

/// Un voisin dans le dossier d'un fichier SAF (Android).
class SafSibling {
  final String name;
  final int size;
  final bool isDir;
  const SafSibling(this.name, {this.size = 0, this.isDir = false});
}

/// Les fichiers du dossier à mettre en scène pour que [fileName] joue — pure,
/// testée (local_roots_test.dart).
///
/// Dossier petit (≤ [wholeDirBytes]): TOUT, sous-dossiers exclus. C'est la
/// règle sûre — les conventions de compagnons sont innombrables (UADE seul en
/// a des dizaines) et un dossier de musique pèse rarement plus.
/// Dossier gros: le fichier, puis ce que les moteurs vont chercher par NOM —
///   * même radical au sens Amiga (`mdat.x` ↔ `smpl.x`: même partie APRÈS le
///     premier point) ou au sens courant (`a.mdx` ↔ `a.pdx`: même partie
///     AVANT le dernier point);
///   * les bibliothèques PSF (`*.psflib`, `*.2sflib`… — toute extension en
///     `lib`), partagées par le dossier;
///   * les playlists et descripteurs voisins (`.m3u`, `.m3u8`, `.txth`).
List<String> stagingSetFor(String fileName, List<SafSibling> siblings,
    {int wholeDirBytes = 32 * 1024 * 1024, Set<String>? exts}) {
  final files = [for (final s in siblings) if (!s.isDir) s];
  final total = files.fold<int>(0, (a, s) => a + (s.size > 0 ? s.size : 0));
  if (total <= wholeDirBytes) {
    final all = [for (final s in files) s.name];
    if (!all.contains(fileName)) all.insert(0, fileName);
    return all;
  }
  String afterFirstDot(String n) {
    final i = n.indexOf('.');
    return i < 0 ? '' : n.substring(i + 1).toLowerCase();
  }
  String beforeLastDot(String n) {
    final i = n.lastIndexOf('.');
    return i <= 0 ? n.toLowerCase() : n.substring(0, i).toLowerCase();
  }
  String extOf(String n) {
    final i = n.lastIndexOf('.');
    return i < 0 ? '' : n.substring(i + 1).toLowerCase();
  }
  // ⚠️ Un nom Amiga porte son FORMAT avant le point (`mdat.monkey island`):
  // sa partie « avant le dernier point » est `mdat`, partagée par TOUS les
  // modules du dossier — la règle du radical courant les ramassait tous.
  // Forme préfixe = premier segment connu comme format, dernier non.
  final known = exts ?? _kIndexedExts;
  final lower = fileName.toLowerCase();
  final firstDot = lower.indexOf('.');
  final prefixForm = firstDot > 0 &&
      known.contains(lower.substring(0, firstDot)) &&
      !known.contains(extOf(fileName));
  final amiga = afterFirstDot(fileName);
  final stem = beforeLastDot(fileName);
  final out = <String>[fileName];
  for (final s in files) {
    if (s.name == fileName) continue;
    final ext = extOf(s.name);
    final keep = (amiga.isNotEmpty && afterFirstDot(s.name) == amiga) ||
        (!prefixForm && beforeLastDot(s.name) == stem) ||
        ext.endsWith('lib') ||
        ext == 'm3u' || ext == 'm3u8' || ext == 'txth';
    if (keep) out.add(s.name);
  }
  return out;
}

/// `.nom.ext.icloud` → `nom.ext` (espace réservé iCloud), sinon null. Pur.
String? icloudPlaceholderName(String name) {
  if (!name.startsWith('.') || !name.endsWith('.icloud')) return null;
  final inner = name.substring(1, name.length - '.icloud'.length);
  return inner.isEmpty ? null : inner;
}

/// Pur, pour les tests et l'isolate de parcours.
bool isIndexedFileName(String name, {Set<String>? exts}) {
  final set = exts ?? _kIndexedExts;
  final lower = name.toLowerCase();
  final dot = lower.lastIndexOf('.');
  if (dot > 0 && dot < lower.length - 1 && set.contains(lower.substring(dot + 1))) {
    return true;
  }
  final first = lower.indexOf('.');
  return first > 0 && set.contains(lower.substring(0, first));
}

class LocalRoots extends ChangeNotifier {
  LocalRoots._();
  static final LocalRoots instance = LocalRoots._();

  static const _channel = MethodChannel('rewamp/bookmarks');
  static const _saf = MethodChannel('rewamp/saf_roots');

  /// Taille maximale du cache de mise en scène Android (tous dossiers liés).
  static const int kSafCacheBytes = 500 * 1024 * 1024;

  /// Sous ce total, un dossier est mis en scène EN ENTIER: c'est la règle la
  /// plus sûre pour des compagnons aux conventions infinies (UADE), et elle
  /// couvre l'immense majorité des dossiers de musique.
  static const int kStageWholeDirBytes = 32 * 1024 * 1024;

  /// Bureau, iOS et Android (arbre SAF + mise en scène).
  static bool get supported =>
      !kIsWeb &&
      (Platform.isLinux || Platform.isWindows || Platform.isMacOS ||
          Platform.isIOS || Platform.isAndroid);

  /// iOS: le dossier `Documents` de l'app est VISIBLE dans Fichiers (« Sur mon
  /// iPhone › Rewamp », `UIFileSharingEnabled`) et par câble dans le Finder.
  /// Ce qu'on y dépose se lit EN PLACE, comme un dossier lié — mais sans
  /// geste: c'est une racine IMPLICITE, toujours là, jamais persistée ni
  /// déliable, dont le chemin est recalculé à chaque lancement (l'UUID du
  /// conteneur change; l'identité, elle, est le relatif — inchangé).
  static const appFolderId = 'app-documents';

  /// Ce que l'app range ELLE-MÊME dans `Documents` sur iOS, à ne pas
  /// présenter comme les fichiers de l'utilisateur: le miroir du catalogue
  /// (`online/`), l'ancienne racine d'imports (`local/`), et la boîte de
  /// réception où iOS dépose les copies d'« Ouvrir avec » (`Inbox/`).
  static const _appFolderSkip = {'online', 'local', 'inbox'};

  bool isAppFolder(String rootId) => rootId == appFolderId;

  List<LocalRoot> _roots = const [];
  List<LocalRoot> get roots => _roots;
  bool _loaded = false;

  /// Les parcours en cours, par racine — un seul à la fois par racine.
  final Set<String> _scanning = {};
  bool isScanning(String rootId) => _scanning.contains(rootId);

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'local_roots.json'));
  }

  /// Au démarrage, après `initLibraryRoots()`: lit la liste et, sur macOS,
  /// rouvre chaque signet. Une racine qu'on ne peut pas rouvrir reste LISTÉE
  /// (grisée) — ses ♥ et playlists ne disparaissent pas parce qu'un disque
  /// n'est pas branché.
  Future<void> init() async {
    if (_loaded || !supported) return;
    _loaded = true;
    try {
      final f = await _file();
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString());
        final list = (j is Map ? j['roots'] : null);
        if (list is List) {
          final out = <LocalRoot>[];
          for (final e in list) {
            if (e is! Map) continue;
            final r = LocalRoot.fromJson(e.cast<String, dynamic>());
            if (r != null) out.add(r);
          }
          _roots = out;
        }
      }
    } catch (e) {
      debugPrint('[roots] lecture: $e');
    }
    final resolved = <LocalRoot>[];
    for (final r in _roots) {
      if (r.id == appFolderId) continue; // implicite: jamais lue du fichier
      resolved.add(await _reopen(r));
    }
    if (Platform.isIOS) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        resolved.insert(0, LocalRoot(
          id: appFolderId,
          kind: LocalRootKind.folder,
          label: 'Rewamp',
          path: docs.path,
          addedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ));
      } catch (_) {}
    }
    _roots = resolved;
    notifyListeners();
    // Ce qui a pu être déposé dans Fichiers depuis le dernier lancement.
    if (Platform.isIOS) unawaited(scan(appFolderId));
  }

  DateTime? _appFolderScannedAt;

  /// Retour au premier plan (iOS): l'utilisateur a peut-être déposé des
  /// fichiers dans Fichiers entre-temps. Borné: pas plus d'un parcours par
  /// 30 s, un aller-retour d'app rapide ne relance rien.
  void onResumed() {
    if (!Platform.isIOS || byId(appFolderId) == null) return;
    final last = _appFolderScannedAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 30)) {
      return;
    }
    unawaited(scan(appFolderId));
  }

  Future<LocalRoot> _reopen(LocalRoot r) async {
    if (r.kind == LocalRootKind.saf) {
      // Android: la permission d'arbre persistée tient-elle encore ? (Elle
      // part si l'utilisateur la retire, ou si le fournisseur disparaît.)
      try {
        final ok = await _saf.invokeMethod<bool>(
            'hasPermission', {'uri': r.bookmark});
        return r.copyWith(available: ok == true);
      } catch (_) {
        return r.copyWith(available: false);
      }
    }
    if (r.kind == LocalRootKind.bookmark && r.bookmark != null) {
      try {
        final res = await _channel.invokeMapMethod<String, dynamic>(
            'resolve', {'bookmark': base64Decode(r.bookmark!)});
        final path = res?['path'] as String?;
        if (path != null && path.isNotEmpty) {
          // Signet « périmé » (dossier déplacé): macOS l'a quand même résolu,
          // on en refait un frais pour la prochaine fois.
          String? fresh;
          if (res?['stale'] == true) fresh = await _makeBookmark(path);
          return r.copyWith(path: path, available: true, bookmark: fresh);
        }
      } catch (e) {
        debugPrint('[roots] signet ${r.label}: $e');
      }
      return r.copyWith(available: false);
    }
    return r.copyWith(available: await Directory(r.path).exists());
  }

  Future<String?> _makeBookmark(String path) async {
    try {
      final bytes =
          await _channel.invokeMethod<Uint8List>('create', {'path': path});
      return bytes == null ? null : base64Encode(bytes);
    } catch (e) {
      debugPrint('[roots] création du signet: $e');
      return null;
    }
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({
        'v': 1,
        'roots': [
          for (final r in _roots)
            if (r.id != appFolderId) r.toJson(),
        ],
      }), flush: true);
    } catch (e) {
      debugPrint('[roots] écriture: $e');
    }
  }

  /// Lie [path]. Déjà lié (ou sous une racine liée) ⇒ rend l'existante.
  Future<LocalRoot> link(String path, {String? label}) async {
    final norm = p.normalize(path);
    final existing = rootOf(norm);
    if (existing != null) return existing;
    String? bookmark;
    var kind = LocalRootKind.folder;
    if (Platform.isMacOS || Platform.isIOS) {
      // Pendant la portée du sélecteur: c'est là que le signet peut naître.
      bookmark = await _makeBookmark(norm);
      if (bookmark != null) kind = LocalRootKind.bookmark;
    }
    var root = LocalRoot(
      id: _newId(),
      kind: kind,
      label: label ?? (p.basename(norm).isEmpty ? norm : p.basename(norm)),
      path: norm,
      bookmark: bookmark,
      addedAt: DateTime.now(),
    );
    // Rouvert TOUT DE SUITE par son signet: la portée du sélecteur se
    // referme dès que l'appelant rend la main (withPickedFolder), et sur iOS
    // le parcours qui suit lirait alors une liste VIDE sans lever.
    if (kind == LocalRootKind.bookmark) root = await _reopen(root);
    _roots = [..._roots, root];
    await _save();
    notifyListeners();
    unawaited(scan(root.id));
    return root;
  }

  /// Android: le sélecteur d'ARBRE du système, permission persistée. Le
  /// `path` de la racine est son dossier de MISE EN SCÈNE dans le cache —
  /// c'est là que les fichiers deviennent des chemins pour le moteur, et c'est
  /// ce qui rend tout le reste (identité, relatif, recherche) identique aux
  /// autres plateformes. L'URI de l'arbre voyage dans `bookmark`.
  Future<LocalRoot?> linkSaf() async {
    Map<String, dynamic>? res;
    try {
      res = await _saf.invokeMapMethod<String, dynamic>('pick');
    } catch (e) {
      debugPrint('[roots] sélecteur SAF: $e');
      return null;
    }
    final uri = res?['uri'] as String?;
    if (uri == null || uri.isEmpty) return null;
    for (final r in _roots) {
      if (r.kind == LocalRootKind.saf && r.bookmark == uri) return r;
    }
    final id = _newId();
    final cache = await getApplicationCacheDirectory();
    final root = LocalRoot(
      id: id,
      kind: LocalRootKind.saf,
      label: (res?['label'] as String?) ?? 'Android',
      path: p.join(cache.path, 'roots', id),
      bookmark: uri,
      addedAt: DateTime.now(),
    );
    _roots = [..._roots, root];
    await _save();
    notifyListeners();
    unawaited(scan(root.id));
    return root;
  }

  /// Délie: la table des noms part, la portée est relâchée. Rien sur le
  /// disque, rien dans la bibliothèque — une entrée ♥ qui nommait ce dossier
  /// devient « sur un autre appareil » jusqu'à ce qu'il soit relié.
  Future<void> unlink(String id) async {
    final r = byId(id);
    if (r == null || r.id == appFolderId) return;
    _roots = [for (final x in _roots) if (x.id != id) x];
    await _save();
    notifyListeners();
    try {
      await LocalDb.instance.deleteLinkedEntries(id);
    } catch (_) {}
    if (r.kind == LocalRootKind.bookmark) {
      try {
        await _channel.invokeMethod('release', {'path': r.path});
      } catch (_) {}
    }
    if (r.kind == LocalRootKind.saf) {
      try {
        await _saf.invokeMethod('release', {'uri': r.bookmark});
      } catch (_) {}
      // Le cache de mise en scène est à NOUS: il part avec la racine.
      try {
        final d = Directory(r.path);
        if (await d.exists()) await d.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> rename(String id, String label) async {
    final t = label.trim();
    if (t.isEmpty) return;
    _roots = [for (final x in _roots) x.id == id ? x.copyWith(label: t) : x];
    await _save();
    notifyListeners();
  }

  LocalRoot? byId(String id) {
    for (final r in _roots) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// La racine qui CONTIENT [absolute] (ou l'est), sinon null.
  LocalRoot? rootOf(String absolute, {p.Context? ctx}) {
    final c = ctx ?? p.context;
    for (final r in _roots) {
      if (c.equals(absolute, r.path) || c.isWithin(r.path, absolute)) return r;
    }
    return null;
  }

  /// `(racine, relatif portable)` pour un chemin sous une racine liée.
  (LocalRoot, String)? relPathOf(String absolute, {p.Context? ctx}) {
    final r = rootOf(absolute, ctx: ctx);
    if (r == null) return null;
    return (r, portableRelative(absolute, from: r.path, ctx: ctx));
  }

  /// Le chemin natif d'une entrée.
  String absolutePathOf(LinkedEntry e) {
    final r = byId(e.rootId);
    if (r == null) return e.relPath;
    return joinPortable(r.path, e.relPath);
  }

  /// Parcourt la racine dans un isolate et REMPLACE sa table des noms. Un
  /// parcours à la fois par racine; une racine injoignable n'efface pas ce
  /// qu'on savait d'elle.
  Future<void> scan(String rootId) async {
    final r = byId(rootId);
    if (r == null || !_scanning.add(rootId)) return;
    notifyListeners();
    final ops = LocalOps.instance;
    try {
      if (r.kind == LocalRootKind.saf) {
        await _scanSaf(r);
        return;
      }
      if (!await Directory(r.path).exists()) {
        _roots = [for (final x in _roots) x.id == rootId ? x.copyWith(available: false) : x];
        return;
      }
      ops.begin(LocalOpKind.scan, name: r.label, phase: LocalOpPhase.scanning);
      final port = ReceivePort();
      var seen = 0;
      port.listen((n) {
        seen = n as int;
        ops.progress(seen);
      });
      // ⚠️ Le jeu d'extensions se calcule ICI, sur l'isolate principal, et
      // VOYAGE en argument: c'est une globale dérivée de `kEngines`, et
      // engines.dart tire le plugin FFI — l'initialiser dans l'isolate de
      // parcours levait là-bas, le parcours « réussissait » avec zéro entrée
      // et l'écran restait vide sans un mot (mesuré sur macOS le 2026-10-27).
      final exts = Set<String>.of(_kIndexedExts);
      final skip = r.id == appFolderId ? _appFolderSkip : const <String>{};
      if (r.id == appFolderId) _appFolderScannedAt = DateTime.now();
      final entries = await _runWalk(r.path, exts, skip, port.sendPort);
      port.close();
      ops.phase(LocalOpPhase.registering, total: entries.length);
      await LocalDb.instance.replaceLinkedEntries(rootId, entries);
      _roots = [
        for (final x in _roots)
          x.id == rootId ? x.copyWith(available: true, clearScanError: true) : x
      ];
      debugPrint('[roots] ${r.label}: ${entries.length} entrées');
    } catch (e) {
      debugPrint('[roots] parcours ${r.label}: $e');
      _roots = [
        for (final x in _roots)
          x.id == rootId ? x.copyWith(scanError: '$e') : x
      ];
    } finally {
      ops.end();
      _scanning.remove(rootId);
      notifyListeners();
    }
  }

  /// Android: le parcours est NATIF (une requête `DocumentsContract` par
  /// dossier), hors du fil principal côté Kotlin.
  Future<void> _scanSaf(LocalRoot r) async {
    final ops = LocalOps.instance;
    ops.begin(LocalOpKind.scan, name: r.label, phase: LocalOpPhase.scanning);
    try {
      final ok = await _saf.invokeMethod<bool>('hasPermission', {'uri': r.bookmark});
      if (ok != true) {
        _roots = [for (final x in _roots) x.id == r.id ? x.copyWith(available: false) : x];
        return;
      }
      final raw = await _saf.invokeListMethod<dynamic>('walk', {
        'uri': r.bookmark,
        'exts': _kIndexedExts.toList(),
      });
      final entries = <LinkedEntry>[
        for (final e in raw ?? const [])
          if (e is Map && e['rel'] is String)
            LinkedEntry('', e['rel'] as String,
                size: (e['size'] as num?)?.toInt(),
                mtimeMs: (e['mtime'] as num?)?.toInt()),
      ];
      ops.phase(LocalOpPhase.registering, total: entries.length);
      await LocalDb.instance.replaceLinkedEntries(r.id, entries);
      _roots = [
        for (final x in _roots)
          x.id == r.id ? x.copyWith(available: true, clearScanError: true) : x
      ];
      debugPrint('[roots] ${r.label}: ${entries.length} entrées (SAF)');
    } catch (e) {
      debugPrint('[roots] parcours SAF ${r.label}: $e');
      _roots = [
        for (final x in _roots) x.id == r.id ? x.copyWith(scanError: '$e') : x
      ];
    } finally {
      ops.end();
    }
  }

  /// Un chemin d'une racine SAF JOIGNABLE est « présent » même s'il n'est pas
  /// (encore) dans le cache: il le sera à la lecture. Sans ça la bibliothèque
  /// grisait comme « sur un autre appareil » tout fichier pas encore joué.
  bool isVirtuallyPresent(String absolute) {
    final r = rootOf(absolute);
    return r != null && r.kind == LocalRootKind.saf && r.available;
  }

  /// ⚠️ Dans SA méthode, exprès: une fermeture capture le CONTEXTE de la
  /// fonction qui la contient, partagé avec les autres fermetures de cette
  /// fonction. Écrite dans [scan], à côté du `port.listen` qui touche
  /// `LocalOps`, elle emportait l'instance et ses écouteurs — l'arbre de
  /// widgets entier — et `Isolate.run` refusait: « object is unsendable ».
  /// Ici le contexte ne contient que trois valeurs envoyables.
  static Future<List<LinkedEntry>> _runWalk(String path, Set<String> exts,
          Set<String> skipTop, SendPort progress) =>
      Isolate.run(() => _walk(path, exts, skipTop, progress));

  /// Le parcours lui-même, hors de l'isolate principal. Pas de liens
  /// symboliques (une boucle serait fatale), pas de dossiers cachés.
  static List<LinkedEntry> _walk(String root, Set<String> exts,
      Set<String> skipTop, SendPort progress) {
    final out = <LinkedEntry>[];
    var seen = 0;
    void visit(Directory d, {required bool top}) {
      List<FileSystemEntity> children;
      try {
        children = d.listSync(followLinks: false);
      } catch (_) {
        return; // un dossier illisible n'arrête pas le parcours
      }
      for (final e in children) {
        var name = p.basename(e.path);
        if (e is Directory) {
          if (name.startsWith('.')) continue;
          if (top && skipTop.contains(name.toLowerCase())) continue;
          visit(e, top: false);
        } else if (e is File) {
          // Un fichier iCloud pas encore descendu n'existe que sous la forme
          // `.nom.icloud`: on l'indexe sous son VRAI nom — la lecture le fera
          // descendre (LocalRoots.materialize).
          var rel = portableRelative(e.path, from: root);
          final placeholder = icloudPlaceholderName(name);
          if (placeholder != null) {
            name = placeholder;
            final slash = rel.lastIndexOf('/');
            rel = '${slash < 0 ? '' : rel.substring(0, slash + 1)}$name';
          } else if (name.startsWith('.')) {
            continue;
          }
          if (!isIndexedFileName(name, exts: exts)) continue;
          FileStat? st;
          if (placeholder == null) {
            try { st = e.statSync(); } catch (_) {}
          }
          out.add(LinkedEntry('', rel,
              size: st?.size, mtimeMs: st?.modified.millisecondsSinceEpoch));
        }
        if (++seen % 500 == 0) progress.send(seen);
      }
    }
    visit(Directory(root), top: true);
    return out;
  }

  /// Rend jouables des chemins de dossiers liés: un fichier iCloud encore à
  /// l'état d'espace réservé est descendu d'abord (iOS). Rend les chemins qui
  /// existent, dans l'ordre; un fichier qui n'a pas pu venir est écarté (la
  /// file avance sans lui).
  Future<List<String>> materialize(List<String> paths) async {
    if (Platform.isAndroid) return _stageSaf(paths);
    if (!Platform.isIOS) return paths;
    final out = <String>[];
    for (final path in paths) {
      if (await File(path).exists()) {
        out.add(path);
        continue;
      }
      final dir = p.dirname(path);
      final ph = p.join(dir, '.${p.basename(path)}.icloud');
      if (!await File(ph).exists()) continue;
      try {
        final ok = await _channel.invokeMethod<bool>('download', {'path': path});
        if (ok == true) out.add(path);
      } catch (e) {
        debugPrint('[roots] descente iCloud $path: $e');
      }
    }
    return out;
  }

  /// Android: met en scène dans le cache les fichiers de [paths] qui viennent
  /// d'une racine SAF et n'y sont pas encore — avec leurs VOISINS, car le
  /// moteur va chercher ses compagnons par nom dans le dossier du fichier
  /// (samples Amiga, `_lib` PSF, `.pdx`, M3U…). Les autres chemins passent.
  Future<List<String>> _stageSaf(List<String> paths) async {
    final out = <String>[];
    final staged = <String>{};
    // Un dossier se met en scène UNE fois par appel, même pour cent fichiers.
    final doneDirs = <String>{};
    for (final path in paths) {
      final hit = relPathOf(path);
      if (hit == null || hit.$1.kind != LocalRootKind.saf) {
        out.add(path);
        continue;
      }
      final (root, rel) = hit;
      final slash = rel.lastIndexOf('/');
      final relDir = slash < 0 ? '' : rel.substring(0, slash);
      final dirKey = '${root.id}|$relDir';
      if (!doneDirs.contains(dirKey) || !await File(path).exists()) {
        doneDirs.add(dirKey);
        try {
          final list = await _saf.invokeListMethod<dynamic>(
              'listDir', {'uri': root.bookmark, 'rel': relDir});
          final siblings = <SafSibling>[
            for (final e in list ?? const [])
              if (e is Map && e['name'] is String)
                SafSibling(e['name'] as String,
                    size: (e['size'] as num?)?.toInt() ?? 0,
                    isDir: e['dir'] == true),
          ];
          final names = stagingSetFor(rel.substring(slash + 1), siblings,
              wholeDirBytes: kStageWholeDirBytes);
          final rels = [
            for (final n in names) relDir.isEmpty ? n : '$relDir/$n',
          ];
          final copied = await _saf.invokeListMethod<dynamic>('copy', {
            'uri': root.bookmark,
            'rels': rels,
            'dest': root.path,
          });
          for (final c in copied ?? const []) {
            if (c is String) staged.add(joinPortable(root.path, c));
          }
        } catch (e) {
          debugPrint('[roots] mise en scène $rel: $e');
        }
      }
      if (await File(path).exists()) {
        // Touché: le plus récemment JOUÉ est le dernier à partir (LRU).
        try { await File(path).setLastModified(DateTime.now()); } catch (_) {}
        out.add(path);
      }
    }
    if (staged.isNotEmpty) unawaited(_pruneSafCache(keep: {...out, ...staged}));
    return out;
  }

  /// Le cache de mise en scène reste sous [kSafCacheBytes]: les fichiers les
  /// moins récemment joués partent d'abord, jamais ceux qu'on vient de poser.
  Future<void> _pruneSafCache({required Set<String> keep}) async {
    try {
      final base = Directory(
          p.join((await getApplicationCacheDirectory()).path, 'roots'));
      if (!await base.exists()) return;
      final files = <(File, int, DateTime)>[];
      var total = 0;
      await for (final e in base.list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        final st = await e.stat();
        files.add((e, st.size, st.modified));
        total += st.size;
      }
      if (total <= kSafCacheBytes) return;
      files.sort((a, b) => a.$3.compareTo(b.$3));
      for (final (f, size, _) in files) {
        if (total <= kSafCacheBytes) break;
        if (keep.contains(f.path)) continue;
        try {
          await f.delete();
          total -= size;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[roots] élagage du cache: $e');
    }
  }

  static String _newId() {
    final r = DateTime.now().microsecondsSinceEpoch;
    return 'root-${r.toRadixString(36)}';
  }

  @visibleForTesting
  void debugSetRoots(List<LocalRoot> roots) {
    _roots = roots;
    _loaded = true;
    notifyListeners();
  }
}
