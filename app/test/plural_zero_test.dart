// Un pluriel ne code JAMAIS son nombre en dur.
//
// Le piège: dans l'ARB on écrit `=1{1 élément}`, un match EXACT sur 1. Mais
// `gen-l10n` compile `=1` vers la CATÉGORIE `one` de `Intl.pluralLogic` — et en
// français la catégorie `one` couvre AUSSI zéro. Résultat: une bibliothèque
// vide affichait « 1 élément ». Le compteur était juste, la traduction mentait.
//
// Le remède est d'interpoler le nombre dans TOUTES les branches, y compris la
// singulière. Ce test le fige sur les deux familles de langues: celles où zéro
// est « one » (fr, pt) et celles où il ne l'est pas (en, de…).
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/l10n/app_localizations.dart';
import 'package:rewamp/l10n/app_localizations_de.dart';
import 'package:rewamp/l10n/app_localizations_en.dart';
import 'package:rewamp/l10n/app_localizations_fr.dart';
import 'package:rewamp/l10n/app_localizations_pt.dart';

void main() {
  test('zéro ne s\'affiche jamais « 1 » (français: zéro est « one »)', () {
    final fr = AppLocalizationsFr();
    expect(fr.libraryItemCount(0), '0 élément');
    expect(fr.libraryItemCount(1), '1 élément');
    expect(fr.libraryItemCount(7), '7 éléments');
  });

  test('portugais aussi (zéro y est « one »)', () {
    final pt = AppLocalizationsPt();
    expect(pt.libraryItemCount(0).startsWith('0'), isTrue,
        reason: pt.libraryItemCount(0));
  });

  test('les langues où zéro est « other » restent correctes', () {
    expect(AppLocalizationsEn().libraryItemCount(0), '0 items');
    expect(AppLocalizationsDe().libraryItemCount(0).startsWith('0'), isTrue);
  });

  test('aucun compteur de la bibliothèque ne ment sur zéro', () {
    // Balayage: tout message de comptage doit commencer par le nombre.
    for (final AppLocalizations l in [
      AppLocalizationsFr(),
      AppLocalizationsEn(),
      AppLocalizationsPt(),
      AppLocalizationsDe(),
    ]) {
      for (final s in [
        l.libraryItemCount(0),
        l.statsPlays(0),
        l.playlistTrackCount(0),
        l.subsongCount(0),
      ]) {
        // Une branche `=0` littérale (« Aucun morceau ») est légitime et
        // souhaitable; ce qui ne l'est pas, c'est un « 1 » là où il y a zéro.
        expect(RegExp(r'(?<![\d])1(?![\d])').hasMatch(s), isFalse,
            reason: '${l.localeName}: "$s" contient un 1 codé en dur');
      }
    }
  });
}
