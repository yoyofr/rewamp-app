// Ce qu'une entrée de bibliothèque a le DROIT de nommer — la garde posée
// AVANT l'écriture, plutôt que le nettoyage APRÈS.
//
// Le fil rouge de la session du 2026-08-28: **une identité par CHEMIN meurt**.
// 338 entrées mortes réparties sur quatre conteneurs iOS, aucune appariable
// avec sa ligne `tracks`. Le nettoyage (LocalDb.missingLocalLibraryEntries +
// SyncService.purgeMissingLocalLibraryEntries) les retire; ce fichier-ci
// empêche d'en fabriquer de nouvelles, et applique EXACTEMENT le même critère
// — sans quoi l'app créerait le matin ce que le nettoyage retire le soir.
//
// Quatre formes, une seule décision par forme:
//  - [LibraryRefKind.catalogue]    uuid serveur                → écrire
//  - [LibraryRefKind.durableImport] `<support>/local/…` présent → écrire
//  - [LibraryRefKind.download]     `<downloads>/online/…`      → RÉSOUDRE le
//    songId (la ligne `tracks` le porte quand on l'a connu), et REFUSER si
//    on ne le trouve pas: le chemin d'un téléchargement porte l'uuid de
//    l'ALBUM, jamais celui de la chanson — en faire une identité fabrique une
//    entrée morte que rien ne pourra rattacher.
//  - [LibraryRefKind.ephemeral]    `opened/`, `Caches/local_archives/`, ou
//    n'importe quel chemin hors des racines connues → proposer l'IMPORT, qui
//    recopie sous `local/` et rend une identité pérenne.
//
// ⚠️ La garde ne s'applique qu'à l'AJOUT. Un RETRAIT doit toujours passer:
// c'est le seul moyen de retirer une entrée cassée déjà en base.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_snack.dart';
import 'l10n.dart';
import 'local_db.dart';
import 'local_import.dart';
import 'opened_files.dart';
import 'rewamp_db.dart';

/// Les identités que la garde a RÉÉCRITES pendant cette session.
///
/// Une garde qui ne fait que rendre une autre clé à l'ÉCRITURE laisse la
/// LECTURE derrière: le bouton interrogé sur l'ancienne clé ne trouve rien et
/// s'éteint aussitôt après le geste. Les deux côtés doivent donc consulter la
/// même table. Elle ne survit pas au redémarrage — inutile: l'ancienne clé
/// nommait un chemin jetable (souvent déjà disparu) ou un fichier dont on ne
/// connaissait pas le songId, et le geste, lui, a été écrit sous la clé
/// pérenne.
final Map<String, String> _rewrites = {};

/// L'inverse: la clé D'ORIGINE d'une clé réécrite. Une réécriture désigne un
/// fichier, et un fichier peut DISPARAÎTRE (l'arbre des imports supprime la
/// copie avec la ligne) — il faut alors pouvoir revenir en arrière plutôt que
/// de refuser à jamais un morceau qu'on est en train d'écouter.
final Map<String, String> _rewrittenFrom = {};

/// La clé réellement utilisée pour [refId] — [refId] lui-même s'il n'a pas été
/// réécrit. Les chaînes sont suivies (un fichier importé puis ré-identifié).
String libraryRefRewrite(String refId) {
  var out = refId;
  for (var i = 0; i < 4; i++) {
    final next = _rewrites[out];
    if (next == null || next == out) break;
    out = next;
  }
  return out;
}

@visibleForTesting
void recordLibraryRefRewrite(String from, String to) {
  if (from == to) return;
  _rewrites[from] = to;
  _rewrittenFrom[to] = from;
}

/// Annule une réécriture devenue fausse et rend la clé d'origine (null si
/// [to] n'en venait pas). Voir [_rewrittenFrom].
String? forgetLibraryRefRewrite(String to) {
  final from = _rewrittenFrom.remove(to);
  if (from != null) _rewrites.remove(from);
  return from;
}

@visibleForTesting
void clearLibraryRefRewrites() {
  _rewrites.clear();
  _rewrittenFrom.clear();
}

enum LibraryRefKind {
  /// uuid du catalogue (éventuellement `<uuid>#<i>`) — l'identité du serveur.
  catalogue,

  /// Import local pérenne: `<support>/local/…`. La SEULE forme de chemin
  /// qu'une entrée de bibliothèque a le droit de nommer.
  durableImport,

  /// Téléchargement du catalogue: `<downloads>/online/…`. Le chemin est dérivé
  /// de champs serveur qui BOUGENT (un override mp3 vide `format_ext` et un
  /// niveau de dossier disparaît), et il porte l'uuid de l'ALBUM.
  download,

  /// Tout le reste: copie d'ouverture (`opened/`), cache d'extraction
  /// (`Caches/local_archives/`, que l'OS vide quand il veut), chemin externe.
  ephemeral,
}

/// Les racines connues, résolues UNE fois au démarrage ([initLibraryRoots]).
///
/// Elles sont des champs et non un calcul: comparer des préfixes de chemin
/// réels évite le faux positif d'une recherche de sous-chaîne (un dossier
/// `/Users/x/local/` de l'utilisateur n'est pas notre dossier d'imports). Non
/// renseignées (tests, très tôt au démarrage), le classement retombe sur la
/// même heuristique de sous-chaîne que le nettoyage.
class LibraryRoots {
  LibraryRoots._();

  /// `<support>/local` — imports pérennes.
  static String? imports;

  /// `<base>/local` — la MÊME notion sous l'autre racine. Un import que le
  /// compte décrit et que cet appareil n'a pas encore est matérialisé là par
  /// [LocalDb.expectedPathFor] quand le fichier n'existe sous aucune des deux
  /// racines: le relatif est `local/<nom>`, et le repli est la racine
  /// historique. Ne pas la connaître faisait passer l'import d'un AUTRE
  /// appareil pour un chemin quelconque.
  static String? importsAlt;

  /// `<downloads>/online` — téléchargements du catalogue.
  static String? downloads;

  /// `<cache>/local_archives` — extraction d'une archive simplement OUVERTE.
  static String? archiveCache;

  /// `<support>/opened` — copie stable d'un geste « ouvrir avec ».
  static String? opened;

  @visibleForTesting
  static void reset() {
    imports = importsAlt = downloads = archiveCache = opened = null;
  }
}

/// À appeler une fois au démarrage, après les répertoires de l'app. Un échec
/// n'est pas fatal: le classement retombe sur l'heuristique de sous-chaîne.
Future<void> initLibraryRoots() async {
  try {
    LibraryRoots.imports = (await localImportsDir()).path;
  } catch (_) {}
  try {
    final base = (await RewampDb.downloadsBaseDir()).path;
    LibraryRoots.downloads = p.join(base, 'online');
    LibraryRoots.importsAlt = p.join(base, 'local');
  } catch (_) {}
  try {
    LibraryRoots.archiveCache =
        p.join((await getApplicationCacheDirectory()).path, 'local_archives');
  } catch (_) {}
  try {
    LibraryRoots.opened = (await OpenedFiles.dir()).path;
  } catch (_) {}
}

bool _under(String path, String? root) {
  if (root == null || root.isEmpty) return false;
  if (!path.startsWith(root)) return false;
  return path.length == root.length ||
      path[root.length] == Platform.pathSeparator;
}

/// Le refId est-il un CHEMIN (par opposition à un uuid de catalogue) ?
bool libraryRefIsPath(String base) =>
    base.startsWith('/') ||
    base.startsWith('{sandbox}') ||
    base.contains(':\\') ||
    base.contains(Platform.pathSeparator);

/// Classe un `library_items.ref_id` de piste. Pur — les racines sont passées
/// pour le test, sinon lues dans [LibraryRoots].
LibraryRefKind libraryRefKind(
  String refId, {
  String? imports,
  String? importsAlt,
  String? downloads,
  String? archiveCache,
}) {
  final base = splitLibraryRefId(refId).$1;
  if (base.isEmpty || !libraryRefIsPath(base)) return LibraryRefKind.catalogue;

  final impRoot = imports ?? LibraryRoots.imports;
  final impAlt = importsAlt ?? LibraryRoots.importsAlt;
  final dlRoot = downloads ?? LibraryRoots.downloads;
  final arcRoot = archiveCache ?? LibraryRoots.archiveCache;

  // Le cache d'archives d'abord: sur certaines plateformes il vit SOUS la même
  // racine que les imports, et c'est le cas jetable qui doit gagner.
  if (_under(base, arcRoot) || _pathHasSegment(base, 'local_archives')) {
    return LibraryRefKind.ephemeral;
  }
  if (_under(base, dlRoot)) return LibraryRefKind.download;
  if (_under(base, impRoot) || _under(base, impAlt)) {
    return LibraryRefKind.durableImport;
  }

  // Racines inconnues (tests, démarrage très tôt, forme `{sandbox}/…` lue en
  // base): même heuristique que LocalDb.missingLocalLibraryEntries.
  if (impRoot == null && _pathHasSegment(base, 'local')) {
    return LibraryRefKind.durableImport;
  }
  if (dlRoot == null && _pathHasSegment(base, 'online')) {
    return LibraryRefKind.download;
  }
  return LibraryRefKind.ephemeral;
}

bool _pathHasSegment(String path, String segment) =>
    p.split(path.replaceAll('\\', '/')).contains(segment);

/// Cette entrée nomme-t-elle une identité STRUCTURELLEMENT morte, à retirer
/// de cet appareil ET du compte ?
///
/// ⚠️ **Un import ABSENT d'ici n'en est pas une.** Un fichier importé sur un
/// autre appareil du même compte y arrive comme une entrée qui nomme un chemin
/// où le fichier n'est PAS — c'est voulu: `_applyExtFavourite` pose exprès une
/// ligne « à l'endroit où le fichier irait », visible comme manquante, qui se
/// relie toute seule le jour où le fichier est copié. Le nettoyage la comptait
/// pourtant comme cassée et envoyait sa clé à `purge_ext_library`: lancer
/// « nettoyer les entrées injouables » sur l'appareil qui n'a PAS les fichiers
/// effaçait les imports de celui qui les a. Un nettoyage local ne doit jamais
/// pouvoir amputer un autre appareil.
///
/// Restent donc victimes: un TÉLÉCHARGEMENT (son chemin n'est pas une
/// identité — il faut le songId) et tout chemin JETABLE (cache d'archive,
/// copie d'ouverture, chemin hors de nos racines).
/// Un import pérenne dont le fichier n'est pas ICI est-il un FANTÔME ?
///
/// La règle générale (voir [libraryRefIsDeadIdentity]) épargne ces entrées:
/// le compte ne transporte que la clé, donc le fichier vit probablement sur un
/// AUTRE appareil, et les retirer amputerait celui-là. Mais un compte SANS
/// e-mail ne peut pas être rejoint depuis un autre appareil — l'écran Compte
/// le dit mot pour mot — donc il n'y a pas d'ailleurs: plus aucun appareil ne
/// porte ce fichier. Constaté sur un Android de test: 80 entrées d'un import
/// dont `flutter run` avait emporté les fichiers (une réinstallation efface
/// `Android/data/<pkg>`, alors que la sauvegarde système rend le compte), et
/// que « Nettoyer la base locale » ne pouvait pas enlever.
///
/// ⚠️ [accountReachableElsewhere] doit être FAUX seulement quand on SAIT que
/// le compte est anonyme (`accountHasEmailKnown`): le défaut de ce drapeau est
/// « on ne sait pas encore », et le lire comme « anonyme » retirerait du compte
/// les entrées d'un autre appareil.
bool libraryRefIsPhantomImport(
  String refId, {
  required bool accountReachableElsewhere,
  required bool fileExists,
}) =>
    !accountReachableElsewhere &&
    !fileExists &&
    libraryRefKind(refId) == LibraryRefKind.durableImport;

bool libraryRefIsDeadIdentity(String refId) => switch (libraryRefKind(refId)) {
      LibraryRefKind.catalogue     => false,
      LibraryRefKind.durableImport => false,
      LibraryRefKind.download      => true,
      LibraryRefKind.ephemeral     => true,
    };

/// Ce que la garde a décidé pour un geste d'AJOUT.
sealed class LibraryRefDecision {
  const LibraryRefDecision();
}

/// Identité utilisable telle quelle (éventuellement RÉÉCRITE: un chemin de
/// téléchargement devient le songId que porte sa ligne `tracks`).
class LibraryRefAccepted extends LibraryRefDecision {
  final String refId;
  const LibraryRefAccepted(this.refId);
}

/// Le fichier n'est pas à un endroit pérenne — l'importer d'abord.
/// [source] est ce qu'il faut donner à l'import: le fichier lui-même, ou
/// l'ARCHIVE dont il a été extrait (les compagnons voyagent avec elle).
class LibraryRefNeedsImport extends LibraryRefDecision {
  final String path;
  final String source;
  final int subsongIdx;
  const LibraryRefNeedsImport(
      {required this.path, required this.source, required this.subsongIdx});

  bool get sourceIsArchive => source != path;
}

/// Pourquoi un ajout est refusé — le message le dit, sinon l'utilisateur lit
/// « identifiant de catalogue inconnu » à propos d'un fichier qu'il vient de
/// supprimer.
enum LibraryRefRefusal {
  /// Fichier du catalogue dont on ne connaît pas le songId sur cet appareil.
  noCatalogueId,

  /// Import pérenne dont le fichier n'est plus là.
  fileGone,
}

/// Aucune identité défendable. Écrire le chemin ferait exactement l'entrée
/// morte que le nettoyage retire.
class LibraryRefRefused extends LibraryRefDecision {
  final LibraryRefRefusal reason;
  const LibraryRefRefused([this.reason = LibraryRefRefusal.noCatalogueId]);
}

/// La décision, sans UI — testable et réutilisable.
Future<LibraryRefDecision> resolveLibraryRefForAdd(String refId) async {
  final (base, sub) = splitLibraryRefId(refId);
  switch (libraryRefKind(refId)) {
    case LibraryRefKind.catalogue:
      return LibraryRefAccepted(refId);

    case LibraryRefKind.durableImport:
      // Un import dont le fichier a disparu n'est plus un import.
      if (await File(base).exists()) return LibraryRefAccepted(refId);
      return const LibraryRefRefused(LibraryRefRefusal.fileGone);

    case LibraryRefKind.download:
      // La ligne `tracks` porte le songId quand on l'a connu — c'est la seule
      // identité que ce fichier possède. Sous-chanson d'abord, puis n'importe
      // quelle ligne du fichier (l'uuid est celui du FICHIER, pas de la
      // sous-chanson: `?subsong=N` le re-porte).
      final rows = await LocalDb.instance.getTracksForFile(base);
      String? onlineId;
      for (final r in rows) {
        if ((r.onlineId ?? '').isEmpty) continue;
        onlineId = r.onlineId;
        if (r.subsongIdx == (sub ?? 0)) break;
      }
      if (onlineId == null || onlineId.isEmpty) {
        return const LibraryRefRefused();
      }
      return LibraryRefAccepted('$onlineId?subsong=${sub ?? 0}');

    case LibraryRefKind.ephemeral:
      return LibraryRefNeedsImport(
          path: base,
          source: await _importSourceFor(base),
          subsongIdx: sub ?? 0);
  }
}

/// Ce qu'il faut IMPORTER pour rendre [path] pérenne.
///
/// Un membre de `Caches/local_archives/<clé>/…` n'est pas importable seul: ses
/// compagnons (banque d'échantillons, M3U, pochette) sont ses voisins dans
/// l'archive. On remonte donc à l'ARCHIVE, dont la copie stable est dans
/// `opened/` — même clé `<radical assaini>_<taille>` que
/// [RewampDb.localArchiveCacheDir]. Introuvable (desktop, où `opened/` n'est
/// pas alimenté), on importe le fichier seul: mieux vaut une piste sans ses
/// compagnons qu'un geste qui ne fait rien.
Future<String> _importSourceFor(String path) async {
  final parts = p.split(path);
  final i = parts.indexOf('local_archives');
  if (i < 0 || i + 1 >= parts.length) return path;
  final archive = await RewampDb.openedArchiveForCacheKey(parts[i + 1]);
  return archive ?? path;
}

/// La garde côté UI: rend l'identité à écrire, ou null si le geste s'arrête.
///
/// À appeler AVANT tout ajout en bibliothèque (ou pose de ♥) — jamais avant un
/// retrait. Trois issues:
///  - identité valable (éventuellement réécrite en songId): elle est rendue;
///  - fichier non pérenne: on PROPOSE l'import, et l'identité rendue est celle
///    de la copie importée;
///  - fichier du catalogue sans songId: refus expliqué, null.
Future<String?> ensureLibraryRefForAdd(
    BuildContext context, String refId) async {
  var decision = await resolveLibraryRefForAdd(refId);
  // ⚠️ Une réécriture MORTE se défait plutôt que de refuser. Elle désigne un
  // fichier, et l'arbre des imports supprime le fichier AVEC la ligne: la clé
  // pérenne d'hier ne nomme alors plus rien, et le geste échouait sur
  // « fichier absent de cet appareil » à propos d'un morceau qu'on est en
  // train d'ÉCOUTER. On revient à la clé d'origine et on rejoue la décision —
  // qui reproposera l'import, ce qui est exactement l'état des lieux.
  if (decision is LibraryRefRefused &&
      decision.reason == LibraryRefRefusal.fileGone) {
    final original = forgetLibraryRefRewrite(refId);
    if (original != null) {
      refId = original;
      decision = await resolveLibraryRefForAdd(refId);
    }
  }
  if (!context.mounted) return null;
  switch (decision) {
    case LibraryRefAccepted(refId: final ok):
      recordLibraryRefRewrite(refId, ok);
      return ok;

    case LibraryRefRefused(:final reason):
      AppSnack.show(
          context,
          switch (reason) {
            LibraryRefRefusal.noCatalogueId =>
              context.l10n.libraryAddNeedsCatalogueId,
            LibraryRefRefusal.fileGone => context.l10n.playlistEntryMissing,
          });
      return null;

    case LibraryRefNeedsImport(
        :final path,
        :final source,
        :final subsongIdx,
        :final sourceIsArchive
      ):
      final l10n = context.l10n;
      final messenger = ScaffoldMessenger.of(context);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.libraryImportBeforeAddTitle),
          content: Text(sourceIsArchive
              ? l10n.libraryImportBeforeAddArchiveBody
              : l10n.libraryImportBeforeAddBody),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.commonImport)),
          ],
        ),
      );
      if (ok != true) return null;
      final res = await importLocalFiles([source]);
      final moved = movedImportPath(res, path: path, source: source);
      if (moved == null) {
        // L'import n'a rien produit d'utilisable: on le DIT (même compte-rendu
        // que le geste « Importer des fichiers ») et on n'écrit rien — une
        // entrée posée sur le chemin jetable serait exactement l'entrée morte
        // que cette garde existe pour empêcher.
        reportImportOn(messenger, l10n, res);
        return null;
      }
      final durable = '$moved?subsong=$subsongIdx';
      recordLibraryRefRewrite(refId, durable);
      return durable;
  }
}

/// Où [path] a atterri après l'import de [source].
///
/// Fichier importé seul: la destination est celle de la source. Archive: la
/// destination est le DOSSIER d'extraction, et le membre s'y retrouve au même
/// chemin RELATIF que dans le cache — les deux extractions partent de la même
/// archive, donc la même arborescence.
@visibleForTesting
String? movedImportPath(LocalImportResult res,
    {required String path, required String source}) {
  final dest = res.destinations[source];
  if (dest == null) return null;
  if (source == path) return dest;
  final parts = p.split(path);
  final i = parts.indexOf('local_archives');
  if (i < 0 || i + 1 >= parts.length) return null;
  final cacheDir = p.joinAll(parts.sublist(0, i + 2));
  return p.join(dest, p.relative(path, from: cacheDir));
}
