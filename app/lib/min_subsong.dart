import 'user_settings.dart';

/// Écarte les sous-chansons plus COURTES que le seuil de Réglages → Lecture.
///
/// ⚠️ **Ce filtre vit au REMPLISSAGE DE LA FILE, jamais dans un producteur de
/// liste.** Une première version le posait dans les quatre endroits qui
/// fabriquent une liste de sous-chansons (écran conteneur, dépliage en ligne,
/// dépliage local, album conteneur), et chacun demandait sa propre précaution:
/// `subsong_count` décrit le FICHIER et se serait mis à décrire « ce que mon
/// seuil en laisse voir » (persisté, donc divergent d'un appareil à l'autre —
/// et un fichier réduit à une entrée cessait d'être un conteneur); le
/// sous-chant de DÉPART d'un SID/SAP est un index de LIGNE, que filtrer
/// déplace; une entrée M3U peut désigner un AUTRE fichier, c'est-à-dire une
/// PISTE d'album et pas une sous-chanson. Au remplissage de la file, aucune de
/// ces trois questions ne se pose: on ne touche ni à une identité, ni à un
/// compte, ni à un affichage — seulement à ce qu'on va écouter. C'est aussi ce
/// que le réglage PROMET, étant dans « Lecture ».
///
/// Un fichier à sous-chansons de JEU tient couramment plus de bruitages que de
/// musique, dans la même table et sans rien qui les distingue: un `.adl`
/// Westwood mêle ses thèmes aux effets sonores du jeu. Mesuré avec le seuil par
/// défaut (5 s), DUNE19.ADL garde 3 morceaux sur 43 — 28 s, 36 s et 41 s,
/// c'est-à-dire exactement sa musique.
///
/// Générique sur la façon de lire une durée, parce que les listes de
/// sous-chansons existent sous trois formes selon le chemin (`SubsongInfo`
/// pour la sonde, `TrackRecord` pour le local, `SearchResult` pour le
/// catalogue) et qu'une règle de lecture ne doit pas dépendre de celle qu'on
/// tient en main.
///
/// Trois règles, chacune payée ailleurs dans ce dépôt:
///
///  * **`null` n'est pas zéro.** Une durée INCONNUE passe le filtre. La moitié
///    des moteurs ne sait pas dire la longueur d'une sous-chanson, et écarter
///    ce qu'on ne sait pas mesurer viderait des listes entières.
///  * **Une liste d'UN élément n'est pas une liste de sous-chansons**: c'est le
///    fichier lui-même, et un fichier court reste un fichier.
///  * **Un filtre qui viderait la liste ne s'applique pas.** Un fichier qui n'a
///    que des morceaux courts doit rester jouable — même garde-fou que le
///    `skip_broken_subsongs` d'UADE.
///
/// ⚠️ [minMs] est EXIGÉ, et la lecture du réglage vit à côté ([minSubsongMs]):
/// cette fonction est appelée depuis la moitié PURE de l'ouverture locale
/// (`subsongRecordsFrom`), que l'hôte de test Dart exécute sans préférences —
/// y lire `UserSettings.instance` faisait lever `LateInitializationError` sur
/// quatre tests existants. Un réglage se lit chez l'appelant qui a le droit
/// d'être impur.
List<T> filterShortSubsongs<T>(
  List<T> rows,
  int? Function(T row) durationMs, {
  required int minMs,
}) {
  final min = minMs;
  if (min <= 0 || rows.length < 2) return rows;
  final kept = [
    for (final r in rows)
      // `?? min`: une durée inconnue passe, sans écrire deux fois le test.
      if ((durationMs(r) ?? min) >= min) r,
  ];
  return kept.isEmpty ? rows : kept;
}

/// Le seuil courant, en millisecondes (0 = ne rien écarter). Lit le réglage,
/// donc à n'appeler que depuis du code qui tourne dans l'app.
int get minSubsongMs =>
    (UserSettings.instance.minSubsongSeconds * 1000).round();

/// Écarte d'une FILE les sous-chansons trop courtes. LE point d'application du
/// réglage — voir l'avertissement de [filterShortSubsongs] sur le pourquoi.
///
/// Deux gardes, sans lesquelles le réglage ferait autre chose que ce qu'il dit:
///
///  * **Seulement des sous-chansons du MÊME fichier** ([fileKey] identique
///    partout). Un album de fichiers distincts n'est pas concerné: un morceau
///    court y est un morceau, pas un bruitage.
///  * **L'entrée DEMANDÉE n'est jamais écartée.** Taper une sous-chanson de 2 s
///    doit la jouer — la faire disparaître sous le doigt serait le pire
///    comportement possible. Elle est déclarée de durée INCONNUE, ce que la
///    règle générale garde déjà.
///
/// Rend la liste filtrée et l'index de départ RECALÉ (filtrer déplace les
/// positions). Rend la liste D'ORIGINE, à l'identique, quand rien n'est écarté:
/// `identical(kept, rows)` est le test que l'appelant peut utiliser.
(List<T>, int?) filterQueueSubsongs<T>(
  List<T> rows,
  int? startIndex, {
  required int minMs,
  required String Function(T) fileKey,
  required int? Function(T) durationMs,
}) {
  if (minMs <= 0 || rows.length < 2) return (rows, startIndex);
  final key = fileKey(rows.first);
  if (!rows.every((r) => fileKey(r) == key)) return (rows, startIndex);
  final start =
      (startIndex != null && startIndex >= 0 && startIndex < rows.length)
          ? rows[startIndex]
          : null;
  final kept = filterShortSubsongs(
      rows, (r) => identical(r, start) ? null : durationMs(r),
      minMs: minMs);
  if (identical(kept, rows)) return (rows, startIndex);
  final at = start == null ? null : kept.indexWhere((r) => identical(r, start));
  return (kept, at == null || at < 0 ? startIndex : at);
}

/// Les entrées que [filterQueueSubsongs] ÉCARTERAIT — pour les GRISER dans une
/// liste.
///
/// ⚠️ Passe par la même fonction, exprès: un affichage qui recoderait la règle
/// finirait par mentir sur le comportement (les gardes « même fichier », « tout
/// filtré ⇒ on ne filtre pas » et « durée inconnue » sont trois occasions de
/// diverger). Une entrée grisée reste JOUABLE au tap — c'est « pas mise en
/// file par un “tout lire” », pas « injouable ».
Set<T> skippedQueueSubsongs<T extends Object>(
  List<T> rows, {
  required int minMs,
  required String Function(T) fileKey,
  required int? Function(T) durationMs,
}) {
  final (kept, _) = filterQueueSubsongs<T>(rows, null,
      minMs: minMs, fileKey: fileKey, durationMs: durationMs);
  if (identical(kept, rows)) return const {};
  final keptSet = Set<T>.identity()..addAll(kept);
  return {
    for (final r in rows)
      if (!keptSet.contains(r)) r,
  };
}
