// Où Rewamp range ce que l'utilisateur VOIT sur son disque: les
// téléchargements (`online/`) et les imports (`local/`).
//
// ── Pourquoi un fichier pour ça ──────────────────────────────────────────────
//
// `getApplicationDocumentsDirectory()` ne veut pas dire la même chose partout:
//
//   iOS, macOS  → un Documents SANDBOXÉ, privé à l'app (et exposé exprès dans
//                 l'app Fichiers d'iOS). Y créer `online/` est correct.
//   Linux,
//   Windows     → le VRAI dossier Documents de l'utilisateur. Y créer `online/`
//                 et `local/` déposait nos dossiers À CÔTÉ de ses propres
//                 fichiers, sans rien qui dise d'où ils venaient. Signalé le
//                 2026-09-21: `~/Documents/online`, 115 Mo.
//
// Sur ces deux plateformes, tout va donc sous `Documents/Rewamp/`. Les autres
// ne bougent pas — et surtout pas macOS, qui a des testeurs beta et dont le
// Documents est déjà privé: les faire migrer ne gagnerait rien.
//
// ⚠️ `local/` bouge AUSSI, et pas seulement `online/`: il était rangé dans le
// dossier de SUPPORT (`~/.local/share/<id>/local`), invisible. Sous
// `Documents/Rewamp/local` les imports deviennent parcourables depuis le
// gestionnaire de fichiers — c'est la disposition demandée.
//
// ── La migration, et le piège qu'elle évite ───────────────────────────────────
//
// Sur Linux et Windows les chemins sont stockés en ABSOLU dans la base (le
// préfixe `{sandbox}` n'est posé que sur iOS, voir `LocalDb.setSandboxRoot`).
// Changer une racine sans rien d'autre laisserait donc toute ligne existante
// pointer dans le vide: exactement la classe de bug que `library_identity.dart`
// documente, et celle qu'un changement d'`APPLICATION_ID` a produite la veille
// sur le dossier de données.
//
// D'où [migrateStorageRoots]: déplacer SUR LE DISQUE, puis réécrire les QUATRE
// porteurs de chemin par `LocalDb.rewriteLocalPathPrefix` — la fonction déjà
// testée contre un vrai SQLite, pas une copie de ses requêtes.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'local_db.dart';

/// Le nom du dossier qui regroupe tout ce que Rewamp dépose chez l'utilisateur.
const String kRewampFolderName = 'Rewamp';

/// Vrai là où « Documents » est le dossier PERSONNEL de l'utilisateur.
bool get usesRewampFolder =>
    !kIsWeb && (Platform.isLinux || Platform.isWindows);

/// `<Documents>/Rewamp` — à n'appeler que si [usesRewampFolder].
Future<Directory> rewampDocumentsDir() async {
  final docs = await getApplicationDocumentsDirectory();
  return Directory(p.join(docs.path, kRewampFolderName));
}

/// Réécrit, dans une valeur JSON décodée, toute CHAÎNE qui désigne [from] ou un
/// chemin sous lui. Rend la nouvelle valeur et le nombre de chaînes changées.
///
/// ⚠️ Même règle que le SQL de `LocalDb.rewriteLocalPaths`: on compare sur
/// « racine + séparateur », jamais sur le préfixe nu — sinon
/// `~/Documents/online2/…` serait pris pour un enfant de `~/Documents/online`.
@visibleForTesting
(Object?, int) rewritePathsInJsonValue(Object? node, String from, String to,
    {String? separator}) {
  final sep = separator ?? Platform.pathSeparator;
  var count = 0;
  Object? walk(Object? n) {
    if (n is String) {
      if (n == from) { count++; return to; }
      if (n.startsWith('$from$sep')) {
        count++;
        return '$to${n.substring(from.length)}';
      }
      return n;
    }
    if (n is List) return [for (final e in n) walk(e)];
    if (n is Map) return {for (final e in n.entries) e.key: walk(e.value)};
    return n;
  }
  final out = walk(node);
  return (out, count);
}

/// Déplace les dossiers d'avant `Documents/Rewamp` et réécrit leurs chemins en
/// base. Idempotente, et sans effet ailleurs que sur Linux et Windows.
///
/// ⚠️ À appeler APRÈS `LocalDb.initialize()` (la réécriture en a besoin) et
/// AVANT `initLibraryRoots()` (qui fige les racines que la garde d'identité
/// compare en PRÉFIXE — elles doivent voir la migration terminée).
Future<void> migrateStorageRoots() async {
  if (!usesRewampFolder) return;
  try {
    final docs    = await getApplicationDocumentsDirectory();
    final support = await getApplicationSupportDirectory();
    final base    = p.join(docs.path, kRewampFolderName);
    final oldLocal = p.join(support.path, 'local');

    await _moveRoot(
      from: p.join(docs.path, 'online'),
      to:   p.join(base, 'online'),
      importsRoot: oldLocal,
    );
    await _moveRoot(
      from: oldLocal,
      to:   p.join(base, 'local'),
      importsRoot: oldLocal,
    );
  } catch (e) {
    // Une migration ratée ne doit pas casser un démarrage — mais elle doit se
    // VOIR: les données restent là où elles étaient, et [_moveRoot] garantit
    // que disque et base ne se contredisent pas.
    debugPrint('[storage] migration Documents/Rewamp: $e');
  }
}

/// Déplace UNE racine, disque puis base, avec retour arrière.
///
/// ⚠️ **Ni l'ordre « base puis disque » ni « disque puis base » n'est atomique.**
/// On déplace d'abord sur le disque, puis on réécrit la base en UNE transaction;
/// si la réécriture échoue, on REMET le dossier en place. La transaction étant
/// tout-ou-rien, le retour arrière rend un état cohérent — ce qui n'existerait
/// pas dans l'autre sens, où un renommage raté après une base réécrite
/// laisserait chaque ligne pointer sur un dossier absent.
Future<void> _moveRoot({
  required String from,
  required String to,
  required String importsRoot,
}) async {
  final src = Directory(from);
  if (!await src.exists()) return;          // rien à migrer, cas normal

  final dst = Directory(to);
  if (await dst.exists()) {
    // Un dossier VIDE à l'arrivée ne compte pas: une ouverture précédente a pu
    // le créer avant que la migration ait sa chance. Un dossier PLEIN, si:
    // fusionner deux arbres automatiquement, c'est choisir à la place de
    // l'utilisateur quelle copie d'un fichier survit.
    if (await dst.list().isEmpty) {
      await dst.delete();
    } else {
      debugPrint('[storage] $from ET $to existent tous deux — pas de fusion '
          'automatique, l\'ancien reste en place');
      return;
    }
  }

  await dst.parent.create(recursive: true);
  try {
    await src.rename(to);
  } on FileSystemException catch (e) {
    // Typiquement EXDEV: Documents et le dossier de support sur deux systèmes
    // de fichiers différents, où un renommage ne peut pas traverser. On NE
    // copie PAS en douce — des centaines de Mo au démarrage, sans barre de
    // progression — et on ne touche pas la base: rien n'est déplacé, donc rien
    // n'est perdu.
    debugPrint('[storage] impossible de déplacer $from → $to ($e)');
    return;
  }

  try {
    await LocalDb.instance.rewriteLocalPathPrefix(
      from: from,
      to: to,
      importsRoot: importsRoot,
      isDirectory: true,
      // C'est la RACINE qui bouge: les chemins relatifs à elle sont
      // INVARIANTS. Voir `LocalDb.rewriteLocalPaths`.
      rewriteRelative: false,
    );
    debugPrint('[storage] $from → $to');
  } catch (e) {
    debugPrint('[storage] base non réécrite ($e) — retour arrière du dossier');
    await Directory(to).rename(from);
    rethrow;
  }

  await _rewriteQueueFile(from, to);
}

/// ⚠️ **Un CINQUIÈME porteur de chemin, hors de la base.** `rewriteLocalPaths`
/// connaît les quatre colonnes SQL; la file persistée (`queue_state.json`, dans
/// le dossier de support) garde ses chemins ABSOLUS dans un fichier JSON, et
/// rien ne la réécrivait.
///
/// Payé à la première exécution réelle de cette migration (2026-09-21): la
/// base était juste — 248 pistes réécrites — mais la file restaurée désignait
/// encore 86 chemins sous `~/Documents/online`. Deux secondes après le
/// déplacement, la pochette voisine du morceau courant s'y est rangée, ce qui
/// a RECRÉÉ l'ancien dossier. Et jouer la file aurait cherché des fichiers
/// partis.
///
/// Trouvé en cherchant l'ancienne racine dans TOUT le dossier de support et
/// dans TOUTES les colonnes de TOUTES les tables, plutôt qu'en énumérant les
/// porteurs connus: c'est le seul fichier hors base qui en portait.
///
/// Si la réécriture échoue, la file est EFFACÉE plutôt que laissée telle quelle:
/// une file vide se reconstruit en un geste, une file périmée recrée l'ancien
/// dossier et pointe dans le vide.
Future<void> _rewriteQueueFile(String from, String to) async {
  final File f;
  try {
    f = File(p.join((await getApplicationSupportDirectory()).path,
        'queue_state.json'));
    if (!await f.exists()) return;
  } catch (_) {
    return;
  }
  try {
    final decoded = jsonDecode(await f.readAsString());
    final (out, n) = rewritePathsInJsonValue(decoded, from, to);
    if (n == 0) return;
    await f.writeAsString(jsonEncode(out), flush: true);
    debugPrint('[storage] file persistée: $n chemin(s) réécrit(s)');
  } catch (e) {
    debugPrint('[storage] file persistée illisible ($e) — effacée');
    try { await f.delete(); } catch (_) {}
  }
}
