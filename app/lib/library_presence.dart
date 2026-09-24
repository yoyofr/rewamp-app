import 'dart:io';
import 'dart:isolate';

import 'package:flutter/widgets.dart';

import 'l10n.dart';
import 'user_settings.dart';

import 'local_db.dart';

/// « Sur un autre appareil ».
///
/// Une entrée LOCALE de bibliothèque vient soit d'un geste fait ici, soit du
/// COMPTE — et le compte ne transporte que la clé, jamais le fichier. Une
/// entrée dont le fichier n'est pas sur CE disque n'est donc pas cassée: elle
/// est jouable ailleurs. L'afficher comme une piste locale ordinaire envoyait
/// l'utilisateur chercher « où est passé mon fichier »; la retirer amputerait
/// l'autre appareil (voir libraryRefIsDeadIdentity, qui ne vise que les
/// identités MORTES). Elle reste donc listée, grisée, non jouable ici — et
/// retirable, puisque c'est un geste de compte.
///
/// Les deux entrées se calculent au CHARGEMENT (un stat par entrée, une
/// requête pour tous les albums), jamais dans le build.

bool _isPath(String s) => s.startsWith('/') || s.contains(r':\');

/// « Ce fichier est-il là ? », pour BEAUCOUP de fichiers.
///
/// Un `await File(p).exists()` par entrée coûtait un aller-retour par le port
/// natif et une continuation sur l'isolate principal — 6 491 fois par écran
/// de bibliothèque, sur TROIS écrans, à CHAQUE notification de la base
/// (mesuré au profileur: un tiers du temps de l'isolate principal). Ici les
/// `stat` se font EN BLOC, synchrones, dans un isolate de travail: un seul
/// saut, et l'interface ne voit rien passer.
///
/// Et un verdict est MÉMORISÉ quelques secondes: les trois écrans rechargent
/// sur la même notification, donc le premier calcule et les deux autres
/// relisent. Un fichier ne va ni ne vient en cinq secondes sans un geste, et
/// les gestes (import, suppression) notifient bien après ce délai. La
/// sémantique reste la même: présent / absent, rien de deviné.
const Duration _kPresenceTtl = Duration(seconds: 5);
final Map<String, bool> _presence = {};
DateTime? _presenceAt;

/// Les chemins de [paths] qui n'existent PAS.
Future<Set<String>> _missingPaths(Iterable<String> paths) async {
  final now = DateTime.now();
  if (_presenceAt == null || now.difference(_presenceAt!) > _kPresenceTtl) {
    _presence.clear();
    _presenceAt = now;
  }
  final todo = <String>{};
  for (final p in paths) {
    if (!_presence.containsKey(p)) todo.add(p);
  }
  if (todo.isNotEmpty) {
    final list = todo.toList(growable: false);
    // `existsSync` dans un isolate: rien à attendre par chemin, et le résultat
    // revient en une seule liste.
    final gone = await Isolate.run(() => <String>{
      for (final p in list) if (!File(p).existsSync()) p,
    });
    for (final p in list) {
      _presence[p] = !gone.contains(p);
    }
  }
  return {for (final p in paths) if (_presence[p] == false) p};
}

/// Les chemins de [paths] réellement PRÉSENTS — même mécanique (bloc,
/// isolate, mémo 5 s) que le reste de ce fichier.
///
/// ⚠️ Le navigateur « Téléchargements » en a besoin depuis que la purge juge
/// l'IDENTITÉ et non le fichier (voir LocalDb.purgeOrphanEntries): la table
/// `tracks` porte désormais, et volontairement, des lignes de catalogue dont
/// le fichier n'est pas encore là. Un écran qui prétend montrer ce qui est SUR
/// LE DISQUE doit donc le demander au disque. C'est la règle de ce fichier:
/// la présence se CALCULE, elle ne se stocke pas.
Future<Set<String>> presentPaths(Iterable<String> paths) async {
  final missing = await _missingPaths(paths);
  return {for (final p in paths) if (!missing.contains(p)) p};
}

/// À appeler quand un geste a MIS ou RETIRÉ des fichiers (import, suppression):
/// le mémo ne doit pas survivre à ce qu'il décrit.
void invalidateLocalPresence() {
  _presence.clear();
  _presenceAt = null;
}

/// Même critère que LibraryItem.isLocal pour une piste: ni id de catalogue,
/// ni album serveur, et hors de l'arbre `online/` (un téléchargement sans
/// uuid n'est pas un fichier de l'utilisateur).
bool _trackIsLocal(TrackRecord t) =>
    t.onlineId == null &&
    t.albumId == null &&
    !t.filePath.contains(
        '${Platform.pathSeparator}online${Platform.pathSeparator}');

/// Les `refId` de [items] dont rien n'est présent ici. Pistes: le fichier
/// nommé par la clé. Albums LOCAUX (clés par NOM, sans uuid): aucune de leurs
/// lignes `tracks` n'a de fichier sur le disque — y compris « aucune ligne »,
/// l'album n'ayant jamais été importé ici.
Future<Set<String>> missingLocalLibraryRefs(Iterable<LibraryItem> items) async {
  final out = <String>{};
  final localAlbums = <String>{};
  // ⚠️ chemin → LES refId, pas « le » refId. Deux entrées de bibliothèque
  // peuvent nommer le MÊME fichier — le fichier entier et l'une de ses
  // sous-chansons (`<chemin>` et `<chemin>?subsong=N`), la paire que
  // `removeStaleImportEntry` connaît déjà. Avec une valeur unique, la seconde
  // ÉCRASAIT la première et une seule des deux se grisait: l'autre restait
  // affichée comme jouable ici, et échouait au tap.
  final trackPaths = <String, List<String>>{};
  for (final it in items) {
    if (!it.isLocal) continue;
    if (it.type == 'track') {
      final path = splitLibraryRefId(it.refId).$1;
      if (!_isPath(path)) continue;
      (trackPaths[path] ??= <String>[]).add(it.refId);
    } else if (it.type == 'album') {
      localAlbums.add(it.refId);
    }
  }
  Map<String, List<String>> albumPaths = const {};
  if (localAlbums.isNotEmpty) {
    albumPaths = await LocalDb.instance.filePathsForLocalAlbums(localAlbums);
  }
  // Un seul passage pour tout: les pistes ET les fichiers des albums.
  final gone = await _missingPaths({
    ...trackPaths.keys,
    for (final ps in albumPaths.values) ...ps,
  });
  for (final e in trackPaths.entries) {
    if (gone.contains(e.key)) out.addAll(e.value);
  }
  for (final name in localAlbums) {
    final ps = albumPaths[name] ?? const <String>[];
    if (!ps.any((p) => !gone.contains(p))) out.add(name);
  }
  return out;
}

/// Les `filePath` de [tracks] locales absentes du disque (favoris, entrées de
/// playlist). Un fichier n'est testé qu'une fois, quel que soit son nombre de
/// sous-chansons.
Future<Set<String>> missingLocalTrackFiles(Iterable<TrackRecord> tracks) async {
  final paths = <String>{
    for (final t in tracks) if (_trackIsLocal(t)) t.filePath,
  };
  return _missingPaths(paths);
}

/// Le libellé d'une entrée locale dont le fichier n'est pas sur CE disque.
///
/// ⚠️ « Sur un autre appareil » est une promesse que seul un compte JOIGNABLE
/// peut tenir. Sans e-mail, le compte ne peut pas être retrouvé depuis un autre
/// appareil (l'écran Compte le dit), donc le fichier n'est nulle part: il
/// MANQUE. Un seul point de décision pour les cinq écrans qui listent la
/// bibliothèque — recoder la règle par écran garantissait qu'il en resterait un
/// à dire le contraire des autres.
///
/// Le drapeau doit être RÉSOLU pour conclure: son défaut est « on ne sait pas
/// encore », pas « anonyme » (voir accountHasEmailKnown).
String libraryElsewhereLabel(BuildContext context) {
  final s = UserSettings.instance;
  final solo = s.accountHasEmailKnown && !s.accountHasEmail;
  return solo
      ? context.l10n.libraryFileMissing
      : context.l10n.libraryOnAnotherDevice;
}
