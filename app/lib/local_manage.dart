// Ranger ses imports: créer un dossier, renommer, déplacer.
//
// ⚠️ **Borné aux IMPORTS** (`<support>/local/`). L'arbre `online/` est le
// miroir du catalogue — ses chemins sont DÉRIVÉS de champs serveur
// (`_dirSegments`), un téléchargement les recalcule, et les rendre modifiables
// ferait diverger le disque de ce que le serveur redonnera.
//
// ── Un chemin EST une identité ──────────────────────────────────────────────
//
// C'est tout le sujet. Déplacer un fichier déplace son identité, et cinq
// porteurs la connaissent:
//
//  * `tracks.file_path` (absolu) ET `tracks.local_rel_path` (relatif à la
//    racine des imports — la matière de la facette « dossier »);
//  * `playlist_tracks.file_path` et `.rel_path`;
//  * `recent_albums.file_path`;
//  * `library_items.ref_id` — pour un import, la clé EST le chemin
//    (`localImportRefId`);
//  * les pochettes VOISINES, nommées d'après le fichier complet
//    (`ArtworkCache.artBasenameFor`, règle Amiga: `mdat.X.jpg`).
//
// ⚠️ **`tracks.ext_key` n'est PAS réécrit, et c'est délibéré.** C'est un
// sha256 de `nom|relatif|entrée|sous-chanson` (`SyncService.localLibraryKey`)
// et c'est l'identité de CE fichier sur le COMPTE: son ♥, son appartenance à
// la bibliothèque et ses écoutes y sont attachés. La recalculer ferait
// repartir de zéro ce que l'utilisateur a accumulé, et laisserait une entrée
// orpheline sur les autres appareils. La clé est opaque: elle a été frappée
// une fois, elle ne bouge plus. Seul le NOM affiché côté compte reste celui de
// l'import d'origine — cosmétique, et le prix juste.

import 'dart:io';

import 'package:path/path.dart' as p;

import 'artwork_image.dart' show ArtworkCache;
import 'library_presence.dart' show invalidateLocalPresence;
import 'local_db.dart';
import 'local_import.dart' show localImportsDir;

/// Pourquoi une opération de rangement a été refusée.
enum LocalManageError {
  /// Hors de `<support>/local/` — voir l'en-tête.
  outsideImports,
  /// Nom vide, `.`/`..`, ou porteur d'un séparateur.
  badName,
  /// Un fichier ou dossier de ce nom existe déjà à l'arrivée.
  exists,
  /// Déplacer un dossier dans lui-même ou dans l'un de ses descendants.
  intoItself,
  /// La source n'existe plus.
  missing,
  /// Échec du système de fichiers.
  io,
}

class LocalManageException implements Exception {
  final LocalManageError reason;
  const LocalManageException(this.reason);
  @override
  String toString() => 'LocalManageException(${reason.name})';
}

/// Un nom de fichier ou de dossier est-il acceptable ?
///
/// Pur et testable. On refuse ce qui ferait SORTIR de l'arbre (`..`, un
/// séparateur) et ce que les systèmes de fichiers refusent de toute façon.
/// Le reste passe: un nom d'album porte des parenthèses, des apostrophes et
/// des accents, et c'est très bien.
bool isValidLocalName(String name) {
  final n = name.trim();
  if (n.isEmpty || n == '.' || n == '..') return false;
  if (n.contains('/') || n.contains(r'\')) return false;
  // Caractères que Windows refuse et que macOS accepte: on s'aligne sur le
  // plus strict — un import peut voyager par une sauvegarde.
  if (RegExp(r'[:*?"<>|\x00-\x1f]').hasMatch(n)) return false;
  return true;
}

/// Déplacer [from] vers [to] ferait-il entrer un dossier dans lui-même ?
///
/// Pur. `p.isWithin` seul ne suffit pas: déplacer un dossier vers LUI-MÊME
/// n'est pas « dedans » et doit quand même être refusé.
bool movesIntoItself(String from, String to) =>
    p.equals(from, to) || p.isWithin(from, to);

/// Le chemin libre le plus proche de [target]: `nom`, puis `nom (2)`, `nom (3)`…
///
/// Pur (l'existence est fournie), pour que la règle de nommage se teste sans
/// disque.
String freeName(String target, bool Function(String) exists) {
  if (!exists(target)) return target;
  final dir  = p.dirname(target);
  final ext  = p.extension(target);
  final stem = p.basenameWithoutExtension(target);
  for (var n = 2; n < 1000; n++) {
    final c = p.join(dir, '$stem ($n)$ext');
    if (!exists(c)) return c;
  }
  return target;
}

/// Garde commune: [path] est-il sous la racine des imports ?
Future<bool> isUnderLocalImports(String path) async {
  final root = (await localImportsDir()).path;
  return p.equals(root, path) || p.isWithin(root, path);
}

/// Crée un dossier nommé [name] sous [parentDir].
///
/// Rend son chemin. Aucun effet en base: un dossier VIDE n'a pas de ligne —
/// l'arbre du navigateur se dessine à partir de `local_rel_path`, donc un
/// dossier vide n'apparaît que parce que le disque le porte.
Future<String> createLocalFolder(String parentDir, String name) async {
  if (!isValidLocalName(name)) {
    throw const LocalManageException(LocalManageError.badName);
  }
  if (!await isUnderLocalImports(parentDir)) {
    throw const LocalManageException(LocalManageError.outsideImports);
  }
  final dir = Directory(p.join(parentDir, name.trim()));
  if (await dir.exists()) {
    throw const LocalManageException(LocalManageError.exists);
  }
  try {
    await dir.create(recursive: true);
  } catch (_) {
    throw const LocalManageException(LocalManageError.io);
  }
  return dir.path;
}

/// Renomme un fichier ou un dossier importé.
Future<String> renameLocalEntry(String path, String newName) async {
  if (!isValidLocalName(newName)) {
    throw const LocalManageException(LocalManageError.badName);
  }
  return moveLocalEntry(path, p.join(p.dirname(path), newName.trim()));
}

/// Déplace [from] vers [to] (chemin COMPLET d'arrivée), fichier ou dossier,
/// et réécrit tous les porteurs de chemin en UNE transaction.
///
/// Rend le chemin d'arrivée réellement utilisé — il peut différer de [to]
/// quand le nom était pris (`nom (2)`).
Future<String> moveLocalEntry(String from, String to) async {
  if (!await isUnderLocalImports(from) || !await isUnderLocalImports(to)) {
    throw const LocalManageException(LocalManageError.outsideImports);
  }
  if (movesIntoItself(from, to)) {
    throw const LocalManageException(LocalManageError.intoItself);
  }
  final isDir = await Directory(from).exists();
  final isFile = await File(from).exists();
  if (!isDir && !isFile) {
    throw const LocalManageException(LocalManageError.missing);
  }

  final dest = freeName(
      to,
      (c) =>
          File(c).existsSync() || Directory(c).existsSync());
  try {
    await Directory(p.dirname(dest)).create(recursive: true);
    if (isDir) {
      await Directory(from).rename(dest);
    } else {
      await File(from).rename(dest);
      // La pochette VOISINE porte le nom COMPLET du fichier (règle Amiga:
      // `mdat.X` → `mdat.X.jpg`): la laisser derrière, c'est un fichier qui
      // perd son image et un orphelin de plus dans le dossier d'origine.
      await _moveSidecars(from, dest);
    }
  } catch (_) {
    throw const LocalManageException(LocalManageError.io);
  }

  final root = (await localImportsDir()).path;
  await LocalDb.instance.rewriteLocalPathPrefix(
    from: from,
    to: dest,
    importsRoot: root,
    isDirectory: isDir,
  );
  // Le mémo de présence décrit des chemins qui viennent de changer.
  invalidateLocalPresence();
  // Les vignettes déjà construites gardent leur chemin RÉSOLU: un identifiant
  // non nul ne prouve rien après un déplacement, il faut bousculer la
  // génération (même remède que pour le contexte GL).
  ArtworkCache.generation.value++;
  return dest;
}

/// Déplace [paths] (fichiers et/ou dossiers) dans [destDir].
///
/// Un échec n'arrête pas le lot: on range ce qui peut l'être et on rend le
/// nombre de réussites — même choix que `tracksForLocalPaths`, où un fichier
/// illisible ne doit pas faire perdre les neuf autres.
Future<int> moveLocalEntries(List<String> paths, String destDir) async {
  var done = 0;
  for (final src in paths) {
    try {
      await moveLocalEntry(src, p.join(destDir, p.basename(src)));
      done++;
    } catch (_) {/* on continue le lot */}
  }
  return done;
}

/// Emmène avec le fichier ce qui est nommé D'APRÈS lui: sa pochette voisine.
Future<void> _moveSidecars(String from, String to) async {
  const exts = ['.jpg', '.jpeg', '.png', '.webp'];
  for (final e in exts) {
    final src = File('$from$e');
    if (await src.exists()) {
      try {
        await src.rename('$to$e');
      } catch (_) {}
    }
  }
}
