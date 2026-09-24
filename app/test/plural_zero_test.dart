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
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/l10n/app_localizations.dart';
import 'package:rewamp/l10n/app_localizations_de.dart';
import 'package:rewamp/l10n/app_localizations_en.dart';
import 'package:rewamp/l10n/app_localizations_fr.dart';
import 'package:rewamp/l10n/app_localizations_pt.dart';

void main() {
  test('aucun ARB ne code un nombre en dur dans une branche =1', () {
    // Balayage STATIQUE, pas une liste de clés: c'est une liste de clés qui a
    // laissé passer `storageCategoryStat` — écrit avec `=1{1 file …}`, il
    // affichait « 1 fichier — 0 B » sur un poste VIDE (zéro est « one » en
    // français), et les quatre tests ci-dessous, verts, n'en savaient rien.
    // La règle mécanique: toute branche `=1{…}` doit interpoler {count} — ou
    // n'être qu'un libellé sans chiffre (« Un morceau »), que ce scan tolère
    // en ne cherchant que les branches commençant par un chiffre littéral.
    final offenders = <String>[];
    final re = RegExp(r'=1\{([^{}]|\{[a-zA-Z]+\})*\}');
    for (final f in Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'))) {
      final text = f.readAsStringSync();
      for (final m in re.allMatches(text)) {
        final branch = m.group(0)!;
        final body = branch.substring(3, branch.length - 1);
        final hasDigit = RegExp(r'^\s*\d').hasMatch(body);
        final hasCount = body.contains('{count}') ||
            RegExp(r'\{\w*[Cc]ount\w*\}').hasMatch(body);
        if (hasDigit && !hasCount) {
          offenders.add('${f.path}: $branch');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'branche =1 avec nombre en dur (zéro est « one » en fr/pt):\n'
            '${offenders.join('\n')}');
  });

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
