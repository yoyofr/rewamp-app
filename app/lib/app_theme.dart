// La SEULE fabrique de ThemeData de l'app.
//
// ⚠️ Il y en avait trois, écrites « exactement comme » la première: le thème
// de l'app (main.dart), celui du lecteur teinté par la pochette
// (artwork_palette.dart) et celui du carrousel d'accueil (onboarding.dart).
// Trois copies d'une règle divergent: le 2026-09-21 le repli de police CJK a
// été posé sur la première seulement, et le LECTEUR comme le panneau ⓘ ont
// continué d'afficher des rectangles à la place des kanji — ils vivent sous le
// thème teinté. Tout thème passe donc par ici; `app_theme_test.dart` fait
// échouer la suite si un `ThemeData(` réapparaît ailleurs.

import 'package:flutter/material.dart';

import 'font_fallback.dart';

ThemeData rewampThemeData(ColorScheme colorScheme) => ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      // Linux: sans ce repli NOMMÉ, tout texte CJK sort en rectangles —
      // interface comprise. Voir font_fallback.dart.
      fontFamilyFallback: platformCjkFontFallback(),
    );
