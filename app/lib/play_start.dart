// QUAND entendre ce qu'on lance: demander (la feuille « Lire maintenant /
// ensuite / à la fin »), ou décider d'avance.
//
// Deux réglages, mêmes valeurs (UserSettings): un geste DANS l'app (tap sur un
// morceau, un rail, une carte, un dépôt sur la fenêtre) et un fichier ouvert
// DEPUIS le système (double-clic, « Ouvrir avec », Dock, ligne de commande sans
// option de placement). On peut vouloir la feuille dans l'app et une lecture
// directe au double-clic, comme dans Winamp.
//
// La feuille ne sert pas qu'à choisir: elle porte « Voir l'album » et « Voir
// les subsongs », seul chemin vers le détail depuis une carte. Quand le
// réglage la saute, l'APPUI LONG (clic droit sur le bureau) la rend:
// [withPlayChoiceSheet] marque la zone, et `showPlayChoiceSheet` la lit — une
// valeur de zone traverse les `await` du gestionnaire de tap, qui résout
// souvent sa ligne au serveur AVANT de demander.
import 'dart:async';

import 'package:flutter/material.dart' show ListTile;
import 'package:flutter/widgets.dart';

import 'l10n/app_localizations.dart';

enum PlayStartAction {
  ask,
  now,
  next,
  end;

  static PlayStartAction fromName(String? s, PlayStartAction fallback) {
    for (final v in values) {
      if (v.name == s) return v;
    }
    return fallback;
  }

  String label(AppLocalizations l10n) => switch (this) {
        PlayStartAction.ask  => l10n.settingsPlayStartAsk,
        PlayStartAction.now  => l10n.trackOptionsPlayNow,
        PlayStartAction.next => l10n.trackOptionsPlayNext,
        PlayStartAction.end  => l10n.trackOptionsAddToQueueEnd,
      };
}

final Object _forceSheetKey = Object();

/// Exécute [gesture] en imposant la feuille de choix, quel que soit le
/// réglage: l'appui long / clic droit d'une carte dont le tap lance direct.
Future<void> withPlayChoiceSheet(FutureOr<void> Function() gesture) async {
  await runZoned(() async => gesture(), zoneValues: {_forceSheetKey: true});
}

/// Vrai dans un geste lancé par [withPlayChoiceSheet].
bool get playChoiceSheetForced => Zone.current[_forceSheetKey] == true;

final Object _queuePlacementKey = Object();

class _QueuePlacement {
  final bool atEnd;
  bool taken = false;
  _QueuePlacement(this.atEnd);
}

/// « Lire ensuite » / « À la fin » d'une rangée tout lire · radio · surprise
/// (le menu « … » de `RadioSurpriseButtons`): refait le geste « tout lire »
/// de l'écran, mais ce qu'il enverrait à la file y est AJOUTÉ au lieu de la
/// remplacer. Une valeur de ZONE et non un paramètre: chaque écran a son
/// « tout lire » (dépliage d'entités, requêtes, fichiers locaux…) et tous
/// finissent dans les mêmes entonnoirs d'AppShell, qui la lisent
/// (`_startAlbumQueue`, `_startLocalTrackQueue`, `_openLocalPaths`,
/// `showPlayChoiceSheet`) — une ligne par entonnoir au lieu d'une par écran.
/// Elle traverse les `await` du geste comme [withPlayChoiceSheet].
///
/// ⚠️ À USAGE UNIQUE ([takeQueuePlacement]): une minuterie ou un écouteur
/// créé pendant le geste hérite de la zone, et un `_startAlbumQueue` lancé
/// bien plus tard par lui (fin de file, relance) AJOUTERAIT au lieu de
/// remplacer. Le premier entonnoir qui la lit la consomme.
Future<void> withQueuePlacement(
    {required bool atEnd, required FutureOr<void> Function() gesture}) async {
  await runZoned(() async => gesture(),
      zoneValues: {_queuePlacementKey: _QueuePlacement(atEnd)});
}

/// Dans un geste [withQueuePlacement] pas encore consommé: `true` = à la fin,
/// `false` = ensuite — et la marque est CONSOMMÉE. `null` ailleurs (le geste
/// REMPLACE la file).
bool? takeQueuePlacement() {
  final p = Zone.current[_queuePlacementKey] as _QueuePlacement?;
  if (p == null || p.taken) return null;
  p.taken = true;
  return p.atEnd;
}

/// L'appui long (et le clic droit) d'une carte dont le tap peut lancer la
/// lecture d'office: refait le MÊME geste, feuille imposée. À poser autour
/// d'un élément qui n'a pas déjà son propre appui long (les lignes de morceau
/// ouvrent le menu d'options, qui porte les trois choix).
class PlayChoiceHold extends StatelessWidget {
  const PlayChoiceHold({super.key, required this.onTap, required this.child});

  /// Une ligne de liste: le geste est son propre `onTap`, rien à recopier.
  PlayChoiceHold.tile(ListTile tile, {super.key})
      : onTap = tile.onTap,
        child = tile;

  /// Le geste du tap, tel quel.
  final FutureOr<void> Function()? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    if (tap == null) return child;
    void hold() => unawaited(withPlayChoiceSheet(tap));
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onLongPress: hold,
      onSecondaryTap: hold,
      child: child,
    );
  }
}
