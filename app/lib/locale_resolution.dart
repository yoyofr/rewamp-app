import 'package:flutter/widgets.dart';

/// Quelle traduction servir pour la langue que l'appareil demande.
///
/// Flutter fait déjà l'essentiel: il rapproche par CODE DE LANGUE, donc
/// `fr_CA` trouve `fr` et `zh_Hant_TW` trouve `zh`. Deux trous restent, et le
/// second est un vrai piège.
///
/// 1. **Le norvégien a trois codes.** `no` est la MACROLANGUE (le code de nos
///    traductions, `app_no.arb`), `nb` le bokmål et `nn` le nynorsk. Apple
///    CANONICALISE `no` en `nb` — mesuré sur macOS 26:
///    `Locale.canonicalLanguageIdentifier(from: "no")` rend `nb` — donc le
///    système peut très bien nous rendre `nb` là où on n'a que `no`. Sans
///    correspondance, Flutter abandonne et sert la langue de repli: un
///    utilisateur norvégien voit l'app en anglais alors que sa traduction est
///    là, complète.
///
/// 2. **Le repli ne doit pas dépendre de l'ORDRE de la liste.** Sans callback,
///    Flutter sert `supportedLocales.first` quand rien ne correspond — et la
///    liste générée par `gen-l10n` est ALPHABÉTIQUE, donc elle commence par le
///    tchèque. L'anglais est nommé ici explicitement.
///
/// Pure et hors widget: c'est la seule façon de la tester sans construire
/// l'app (qui appelle le natif au premier build).
Locale resolveAppLocale(Locale? device, Iterable<Locale> supported) {
  const fallback = Locale('en');
  if (device == null) return fallback;

  // Alias de langue: plusieurs codes désignent la même traduction.
  const aliases = <String, String>{
    'nb': 'no',   // bokmål — la forme canonique d'Apple pour « no »
    'nn': 'no',   // nynorsk
    'in': 'id',   // codes hérités que l'on rencontre encore sur Android
    'iw': 'he',
    'ji': 'yi',
  };

  final wanted = device.languageCode.toLowerCase();
  final code = aliases[wanted] ?? wanted;

  for (final l in supported) {
    if (l.languageCode.toLowerCase() != code) continue;
    // À code égal, une correspondance de PAYS est meilleure — inerte
    // aujourd'hui (aucune de nos 18 locales n'en porte), mais le jour où
    // `pt_BR` rejoint `pt`, le choix se fait ici et pas par hasard.
    if (l.countryCode == null ||
        l.countryCode == device.countryCode) {
      return l;
    }
  }
  for (final l in supported) {
    if (l.languageCode.toLowerCase() == code) return l;
  }
  return fallback;
}
