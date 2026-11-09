import 'dart:math';

import 'package:flutter/widgets.dart';

import 'rewamp_db.dart' show SearchResult, OnPlayAlbum;

/// Radio d'une LISTE: le bouton 📻 d'un écran (portée d'une collection, d'un
/// artiste, de facettes de recherche, d'un podium…) tire au hasard DANS cette
/// portée, côté serveur.
///
/// Elle tirait UNE page de 50 et la jouait comme un album: arrivée au 50e
/// morceau, la file était finie et la radio s'arrêtait (retour auteur du
/// 2026-11-01). Une radio ne finit pas, et ne déroule pas non plus 50
/// morceaux dans la file: AppShell tient une FENÊTRE glissante (3 devant, 8
/// derrière, comme la radio de l'accueil) nourrie par un tampon que la
/// station recharge lot par lot à la MÊME source, sans sortir de la portée.
///
/// La source est une page `(graine, décalage, taille)` du tri `random`: une
/// graine FIXE donne un ordre stable et paginable, donc les lots successifs ne
/// se répètent pas tant que la portée n'est pas épuisée; épuisée, on repart
/// sur une graine neuve (nouveau tour, un autre ordre).
///
/// ⚠️ La page doit CAPTURER les critères de l'écran au moment du geste, pas
/// relire ses champs à chaque lot: changer de facette après coup ne doit pas
/// changer la station, et l'écran peut être fermé depuis longtemps.
typedef StationPage = Future<List<SearchResult>> Function(
    String seed, int offset, int limit);

/// La suite d'une station: le lot suivant, vide si la portée ne rend plus
/// rien (hors ligne, portée vide).
typedef StationNext = Future<List<SearchResult>> Function();

/// Démarre une station sur la file. Posé une fois par AppShell; null hors de
/// l'app (tests) ⇒ repli sur une lecture finie du premier lot.
Future<void> Function(BuildContext context, List<SearchResult> first,
    StationNext next)? globalOnStartStation;

/// Taille d'un lot demandé au serveur. Il va dans le TAMPON de la station,
/// pas dans la file.
const int kStationBatch = 50;

/// Le curseur d'une station: graine + décalage, nouveau tour à l'épuisement.
class RandomStation {
  final StationPage page;
  final int batch;
  final Random _rand;
  String _seed;
  int _offset = 0;

  RandomStation(this.page, {this.batch = kStationBatch, Random? rand})
      : _rand = rand ?? Random(),
        _seed = '';

  String _newSeed() =>
      '${DateTime.now().microsecondsSinceEpoch}${_rand.nextInt(1 << 20)}';

  /// Le lot suivant. Un lot COURT dit que la portée est épuisée: le tour
  /// suivant repart d'une graine neuve. Un lot VIDE au milieu d'un tour
  /// (portée qui a rétréci entre-temps) est retenté une fois en début de tour.
  Future<List<SearchResult>> next() async {
    if (_seed.isEmpty) _seed = _newSeed();
    var rows = await page(_seed, _offset, batch);
    if (rows.isEmpty && _offset > 0) {
      _seed = _newSeed();
      _offset = 0;
      rows = await page(_seed, 0, batch);
    }
    if (rows.length < batch) {
      _seed = _newSeed();
      _offset = 0;
    } else {
      _offset += rows.length;
    }
    return rows;
  }
}

/// Le geste 📻 complet: premier lot, puis la station prend la file. Rend
/// faux si la portée est vide (rien n'a été lancé).
Future<bool> startRandomStation(
  BuildContext context,
  StationPage page, {
  OnPlayAlbum? fallback,
}) async {
  final station = RandomStation(page);
  final first = await station.next();
  if (first.isEmpty || !context.mounted) return false;
  final start = globalOnStartStation;
  if (start != null) {
    await start(context, first, station.next);
  } else {
    await fallback?.call(context, first);
  }
  return true;
}
