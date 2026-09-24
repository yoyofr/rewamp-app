// « Qui a demandé quoi » — trace des commandes de transport.
//
// Écrit pour un défaut qui ne se reproduit pas à la demande: un appui sur
// PAUSE qui passe au morceau SUIVANT. Trois causes possibles, et un journal
// qui ne dit que « la piste a changé » ne les distingue pas:
//
//   1. le BOUTON: l'appui part ailleurs qu'au bouton pause — le lecteur et le
//      mini-lecteur portent un glissement horizontal qui SAUTE de piste, et un
//      appui qui bouge de quelques pixels peut le réveiller;
//   2. l'ÉVÉNEMENT: la commande vient d'ailleurs que de l'écran (centre de
//      contrôle, écouteurs, montre, casque Bluetooth qui envoie « suivant »);
//   3. la DÉTECTION: personne n'a rien demandé et c'est l'app qui a conclu
//      « la piste s'est terminée seule » (voir engineStoppedByItself).
//
// Chaque ligne nomme donc la SOURCE, jamais seulement l'action. Une ligne
// `suivant ← auto` sans appui juste avant accuse la détection; un
// `suivant ← glissement` juste après un appui accuse le geste.
//
// ⚠️ Volontairement PAS conditionné au mode debug: le défaut se produit à
// l'usage, sur un appareil, souvent sur une version installée. Le volume est
// négligeable — quelques lignes par piste, jamais une par frame.
import 'package:flutter/foundation.dart';

/// Trace une commande de transport.
///
/// [action] est ce qui est demandé (« pause », « suivant »…), [source] D'OÙ ça
/// vient (« bouton lecteur », « glissement mini-lecteur », « session média »,
/// « auto »), [detail] l'état qui a décidé.
void logTransport(String action, {required String source, String? detail}) {
  final d = (detail == null || detail.isEmpty) ? '' : ' | $detail';
  debugPrint('[transport] $action ← $source$d');
}
