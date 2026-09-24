// Le style « Visualiser » de la vue MOTIFS: les couleurs de Rewamp MOINS la
// grille. Ce que ce test épingle, c'est le CONTRAT que le renderer natif
// mirroir (g_pv_palettes dans rewamp_pattern_render.cpp) — les deux listes
// sont indexées POSITIONNELLEMENT, donc l'ordre est load-bearing.

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/pattern_scope_widget.dart';
import 'package:rewamp/user_settings.dart';

void main() {
  PatternPalette byName(String n) =>
      PatternPalette.presets.firstWhere((p) => p.name == n);

  test('le clamp de UserSettings connaît TOUTES les palettes', () {
    // Le compte est recopié dans UserSettings (qui ne peut pas lire la liste:
    // l'import va dans l'autre sens). Le laisser derrière ne casse rien de
    // visible — le sélecteur propose la palette et le réglage retombe en
    // silence sur l'avant-dernière.
    expect(UserSettings.patternPaletteCount, PatternPalette.presets.length);
  });

  test('Visualiser est la DERNIÈRE palette', () {
    // L'index Dart EST l'index natif: on ajoute en fin, jamais au milieu.
    expect(PatternPalette.presets.last.name, 'Visualiser');
  });

  test('ni séparateur de colonne ni bande de mesure', () {
    final v = byName('Visualiser');
    expect(v.separator.a, 0, reason: 'séparateur transparent');
    expect(v.beatBg.a, 0, reason: 'pas de bande régulière');
  });

  test('les couleurs de contenu restent celles de Rewamp', () {
    final r = byName('Rewamp');
    final v = byName('Visualiser');
    for (final pair in [
      (r.note, v.note),
      (r.noteEmpty, v.noteEmpty),
      (r.instrument, v.instrument),
      (r.volume, v.volume),
      (r.rowNum, v.rowNum),
    ]) {
      expect(pair.$2, pair.$1);
    }
  });

  test('le fond est un noir TEINTÉ, pas le noir de Rewamp ni le noir pur', () {
    final v = byName('Visualiser');
    expect(v.bg, isNot(byName('Rewamp').bg));
    expect(v.bg, isNot(const Color(0xFF000000)));
    // Proche du noir, et teinté vers le rose de marque: rouge > vert.
    expect(v.bg.r, lessThan(0.12));
    expect(v.bg.r, greaterThan(v.bg.g));
    expect(v.bg.b, greaterThan(v.bg.g));
  });

  test('barre FIXE et défilement par lignes entières', () {
    // Une image faite de motifs ne se lit qu'alignée sur sa grille: une barre
    // qui remonte et un décalage sous-ligne la font trembler. Les deux
    // drapeaux masquent aussi leurs boutons — un interrupteur sans effet vaut
    // moins que pas d'interrupteur.
    final v = byName('Visualiser');
    expect(v.pinsBar, isTrue);
    expect(v.forcesNoSmooth, isTrue);
    expect(PatternPalette.selectedForcesNoSmooth(
        PatternPalette.presets.length - 1), isTrue);
    // Et aucun autre style ne l'impose.
    expect(byName('Rewamp').forcesNoSmooth, isFalse);
  });
}
