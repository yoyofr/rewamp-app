import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/artwork_image.dart';

/// Une pochette REMPLACÉE SOUS LA MÊME URL restait affichée pour toujours dans
/// la file: `didUpdateWidget` ne recharge que si l'url CHANGE, or
/// « re-télécharger » ne change pas l'url — il change l'image derrière. Le
/// fichier était bien effacé et le bitmap évincé, mais les vignettes DÉJÀ
/// construites gardaient leur chemin résolu et n'avaient aucune raison de se
/// reconstruire.
///
/// Le remède est un id de GÉNÉRATION, comme pour le contexte GL: un identifiant
/// non nul ne prouve rien après une invalidation, il faut comparer une
/// génération.
void main() {
  // `invalidate` évince du cache d'images: le binding doit exister.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la génération démarre à zéro et monte à chaque invalidation', () async {
    final g0 = ArtworkCache.generation.value;
    // Une url VIDE ne doit rien invalider — donc ne pas bumper non plus.
    await ArtworkCache.instance.invalidate('');
    expect(ArtworkCache.generation.value, g0);

    await ArtworkCache.instance.invalidate('https://example/cover.jpg');
    expect(ArtworkCache.generation.value, g0 + 1,
        reason: 'sans ce bump, aucune vignette montée ne se recharge');
  });

  // ⚠️ La MOITIÉ widget ne se teste pas ici: `ArtworkImage` attend de l'IO
  // réelle et le test PEND (piège déjà payé, voir artwork_placeholder_test).
  // Ce qui se teste — et qui est le vrai contrat — c'est le BUMP: sans lui,
  // aucune vignette montée n'a de raison de se recharger.
}
