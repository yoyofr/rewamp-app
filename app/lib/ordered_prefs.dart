// Fusionner un ORDRE CHOISI par l'utilisateur avec l'ordre LIVRÉ.
//
// Le problème se pose deux fois (sections de l'accueil, onglets de la
// coquille) et se posera à chaque liste réordonnable: ce qu'on persiste n'est
// que le choix, et il faut le réconcilier avec ce que le binaire connaît —
// entrées inconnues jetées, entrées neuves réinsérées à une place SENSÉE.
//
// « Sensée » veut dire: à sa place par défaut RELATIVEMENT à ce que
// l'utilisateur a rangé. Deux règles naïves échouent, et chacune a été écrite
// puis retirée:
//  - « devant sa plus proche SUIVANTE » rate dès que cette suivante a été
//    remontée en tête: l'entrée neuve du bas se retrouvait tout en haut;
//  - « après sa plus proche DEVANCIÈRE » rate symétriquement quand c'est la
//    devancière qui a été déplacée en tête.
//
// La bonne formulation est une FUSION STABLE: on parcourt l'ordre livré en
// tenant un curseur dans la liste choisie, qui ne recule jamais. Une entrée
// déjà choisie ne fait qu'avancer le curseur; une entrée absente s'insère AU
// curseur. Chaque insertion respecte donc l'ordre livré vis-à-vis de tout ce
// qui a déjà été placé, sans jamais défaire le rangement de l'utilisateur.

/// Fusionne [chosen] (l'ordre de l'utilisateur, déjà filtré et dédoublonné)
/// avec [fallback] (l'ordre livré, qui fait AUTORITÉ sur le contenu).
///
/// Rend une liste contenant exactement les éléments de [fallback]: ceux que
/// [chosen] nomme dans son ordre, les autres réinsérés au fil du parcours.
List<T> mergePreferredOrder<T>(List<T> chosen, List<T> fallback) {
  if (chosen.isEmpty) return List.of(fallback);
  final out = List.of(chosen);
  var cursor = 0;
  for (final item in fallback) {
    final at = out.indexOf(item);
    if (at >= 0) {
      // Déjà placé par l'utilisateur: le curseur saute derrière, sans jamais
      // reculer — c'est ce « jamais reculer » qui rend la fusion stable.
      if (at + 1 > cursor) cursor = at + 1;
      continue;
    }
    out.insert(cursor, item);
    cursor++;
  }
  return out;
}
