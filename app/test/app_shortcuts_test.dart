// Les raccourcis clavier (lib/app_shortcuts.dart): la table n'a pas deux
// entrées sur la même touche, chaque entrée a un libellé et une touche
// affichable, et la convention des modificateurs suit la plateforme.
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/app_shortcuts.dart';
import 'package:rewamp/l10n/app_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  for (final macOS in [true, false]) {
    final name = macOS ? 'macOS' : 'Linux/Windows';
    test('aucun conflit de touche ($name)', () {
      expect(findShortcutConflicts(macOS: macOS), isEmpty);
    });

    test('chaque entrée a un libellé et des touches ($name)', () {
      for (final s in shortcutsFor(macOS: macOS)) {
        expect(s.label(en), isNotEmpty, reason: '${s.id}');
        expect(s.keys, isNotEmpty, reason: '${s.id}');
        for (final k in s.keys) {
          expect(k.label(en, macOS: macOS), isNotEmpty, reason: '${s.id}');
        }
      }
    });
  }

  test('toutes les ShortcutId sont dans la table', () {
    final ids = kAppShortcuts.map((s) => s.id).toSet();
    expect(ids, containsAll(ShortcutId.values));
  });

  test('⌘9 = Téléchargements, juste après le dernier onglet du rail', () {
    final d = kAppShortcuts.singleWhere((s) => s.id == ShortcutId.downloads);
    expect(d.keys.single.physical, PhysicalKeyboardKey.digit9);
    expect(d.keys.single.label(en, macOS: true), '⌘9');
    final tabs = kAppShortcuts.singleWhere((s) => s.id == ShortcutId.tabs);
    expect(tabs.keys.map((k) => k.physical),
        isNot(contains(PhysicalKeyboardKey.digit9)));
  });

  test('plein écran: ⌘⌃F affiché seulement sur macOS, F11 ailleurs', () {
    final mac = shortcutsFor(macOS: true)
        .where((s) => s.id == ShortcutId.fullscreen)
        .toList();
    final other = shortcutsFor(macOS: false)
        .where((s) => s.id == ShortcutId.fullscreen)
        .toList();
    expect(mac, hasLength(1));
    expect(mac.single.systemHandled, isTrue);
    expect(mac.single.keys.single.label(en, macOS: true), '⌃⌘F');
    expect(other, hasLength(1));
    expect(other.single.systemHandled, isFalse);
    expect(other.single.keys.single.label(en, macOS: false), 'F11');
  });

  test('« primaire » = ⌘ sur macOS, Ctrl ailleurs', () {
    const k = KeyCombo(
        logical: LogicalKeyboardKey.keyM, primary: true, shift: true,
        display: 'M');
    expect(k.label(en, macOS: true), '⇧⌘M');
    expect(k.label(en, macOS: false), 'Ctrl+Shift+M');
    expect(k.matchesModifiers(macOS: true, meta: true, control: false,
        alt: false, shift: true), isTrue);
    expect(k.matchesModifiers(macOS: true, meta: false, control: true,
        alt: false, shift: true), isFalse);
    expect(k.matchesModifiers(macOS: false, meta: false, control: true,
        alt: false, shift: true), isTrue);
    // Un modificateur EN PLUS n'est pas le même raccourci.
    expect(k.matchesModifiers(macOS: true, meta: true, control: false,
        alt: true, shift: true), isFalse);
  });

  test('un symbole ignore Shift (il le porte lui-même)', () {
    const q = KeyCombo(character: '?', display: '?');
    expect(q.matchesModifiers(macOS: true, meta: false, control: false,
        alt: false, shift: true), isTrue);
    expect(q.matchesModifiers(macOS: true, meta: false, control: false,
        alt: false, shift: false), isTrue);
    expect(q.matchesModifiers(macOS: true, meta: true, control: false,
        alt: false, shift: false), isFalse);
  });

  test('Espace et Échap ont un nom traduit', () {
    const space = KeyCombo(logical: LogicalKeyboardKey.space, display: '');
    const esc = KeyCombo(logical: LogicalKeyboardKey.escape, display: '');
    expect(space.label(en, macOS: true), 'Space');
    expect(esc.label(en, macOS: false), 'Esc');
  });

  test('les dix chiffres font une seule puce « 0 – 9 »', () {
    final s = kAppShortcuts.firstWhere((s) => s.id == ShortcutId.seekPercent);
    expect(KeyboardShortcutsScreen.keyLabels(s, en, macOS: true), ['0 – 9']);
    expect(digitOf(PhysicalKeyboardKey.digit7), 7);
    expect(digitOf(PhysicalKeyboardKey.keyA), -1);
  });
}
