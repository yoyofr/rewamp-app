// Le remélange d'un NOUVEAU TOUR de file, isolé du widget pour être testable.
//
// La lecture aléatoire est une PERMUTATION calculée une fois (app_shell,
// _shuffleQueue): sur un tour, chaque morceau passe exactement une fois, et
// couper le shuffle restaure l'ordre d'insertion grâce au `seq` de chaque
// entrée. Mais le tour SUIVANT — reboucler la file, ou appuyer sur play sur
// une file épuisée — rejouait la MÊME permutation, donc le même ordre
// indéfiniment tant qu'on ne rebasculait pas le bouton.
import 'dart:math';

/// Rend une nouvelle permutation de [items] pour un tour suivant.
///
/// ⚠️ La permutation ne COMMENCE jamais par [justPlayed] quand il y a de quoi
/// choisir: un tirage uniforme la remet en tête une fois sur N, et juste à la
/// frontière d'un tour ça s'entend comme un morceau qui se répète — le seul
/// endroit où un vrai hasard a l'air d'un bug.
///
/// [rng] n'existe que pour les tests: par défaut, `List.shuffle()` prend un
/// `Random()` semé par l'entropie système (vérifié: trois exécutions donnent
/// trois ordres différents), contrairement au tirage de presets projectM qui,
/// lui, repartait d'une constante.
List<T> reshuffledForNewPass<T>(List<T> items, {T? justPlayed, Random? rng}) {
  if (items.length < 2) return List<T>.of(items);
  final out = List<T>.of(items)..shuffle(rng);
  if (justPlayed != null && identical(out.first, justPlayed)) {
    final r = rng ?? Random();
    final swap = 1 + r.nextInt(out.length - 1);
    final first = out[0];
    out[0] = out[swap];
    out[swap] = first;
  }
  return out;
}
