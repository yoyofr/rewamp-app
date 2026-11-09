// Raccourcis clavier du bureau: UNE table, UN répartiteur, UN écran qui la
// liste.
//
// Pourquoi un handler GLOBAL (`HardwareKeyboard.addHandler`) et pas des
// `Shortcuts`/`CallbackShortcuts` dans l'arbre: ceux-là ne reçoivent une
// touche que si le focus Flutter est SOUS eux, et chez nous rien n'a le focus
// la plupart du temps — il retombe sur le scope RACINE, au-dessus de tout
// widget de l'app. Le ⇧⌘M du mini lecteur ne partait qu'après un clic sur un
// bouton (constaté sur macOS le 2026-10-31); le visualiseur avait déjà
// contourné le problème de la même façon.
//
// Règles de la table:
//  - une touche = UNE action, quel que soit l'écran. Un raccourci peut être
//    INACTIF (projectM hors lecteur), jamais changer de sens. Un test refuse
//    deux entrées de même signature (`findShortcutConflicts`).
//  - rien de ce que le système se réserve: ⌘Q, ⌘W, ⌘H, ⌘M, ⌘Tab sur macOS,
//    Alt+F4 sur Windows, Ctrl+Q sous GNOME.
//  - « primaire » = ⌘ sur macOS, Ctrl ailleurs: la même ligne vaut partout.
//  - les touches sans modificateur se taisent dans un champ texte (une
//    recherche, un nom de playlist), et Espace laisse un bouton FOCALISÉ
//    (parcours au Tab) s'activer plutôt que de doubler.
//  - chiffres et touches de la rangée du haut se reconnaissent à la touche
//    PHYSIQUE: sur un AZERTY les chiffres sont en Shift et la touche logique
//    change avec la disposition. Les symboles (`?`, `-`, `+`, `=`) se
//    reconnaissent au CARACTÈRE produit, ce qui vaut aussi sur toute
//    disposition.
//
// La liste affichée (`KeyboardShortcutsScreen`, touche `?`, Réglages) est
// GÉNÉRÉE depuis la table: pas de doublon à la main qui dérive.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'l10n.dart';

enum ShortcutGroup { transport, visualizer, window }

enum ShortcutId {
  playPause,
  prevTrack,
  nextTrack,
  seekBack10,
  seekForward10,
  seekBack60,
  seekForward60,
  seekPercent,
  repeat,
  shuffle,
  favorite,
  speedDown,
  speedUp,
  speedReset,
  vizNext,
  vizPrev,
  vizControls,
  pmNext,
  pmPrev,
  pmLock,
  pmRandom,
  pmPicker,
  miniWindow,
  miniViz,
  alwaysOnTop,
  player,
  escape,
  queuePanel,
  search,
  tabs,
  downloads,
  openFiles,
  linkFolder,
  info,
  settings,
  fullscreen,
  help,
}

/// Une combinaison de touches. Trois façons de reconnaître la touche, une
/// seule renseignée: [logical] (lettres, flèches, Espace…), [physical]
/// (chiffres, touches de fonction — indépendant de la disposition), ou
/// [character] (symbole produit, Shift ignoré puisque le symbole l'implique
/// ou non selon le clavier).
class KeyCombo {
  final LogicalKeyboardKey? logical;
  final PhysicalKeyboardKey? physical;
  final String? character;
  /// ⌘ sur macOS, Ctrl ailleurs.
  final bool primary;
  final bool shift;
  final bool alt;
  /// Ctrl EXPLICITE (⌃ sur macOS) — seulement pour afficher ⌘⌃F, que macOS
  /// traite lui-même.
  final bool control;
  /// La touche telle qu'affichée, sans modificateurs (`M`, `←`, `0 – 9`).
  /// Vide = libellé traduit (Espace, Échap) choisi par [KeyCombo.keyLabel].
  final String display;

  const KeyCombo({
    this.logical,
    this.physical,
    this.character,
    this.primary = false,
    this.shift = false,
    this.alt = false,
    this.control = false,
    required this.display,
  }) : assert(logical != null || physical != null || character != null);

  /// Les modificateurs attendus, dans les termes du matériel.
  ({bool meta, bool control, bool alt, bool shift}) expected(
          {required bool macOS}) =>
      (
        meta: primary && macOS,
        control: control || (primary && !macOS),
        alt: alt,
        shift: shift,
      );

  bool matchesModifiers({
    required bool macOS,
    required bool meta,
    required bool control,
    required bool alt,
    required bool shift,
  }) {
    final e = expected(macOS: macOS);
    if (e.meta != meta || e.control != control || e.alt != alt) return false;
    // Un symbole porte son Shift lui-même (`?` est Shift+, sur AZERTY,
    // Shift+/ sur QWERTY; `+` est Shift+= sur les deux).
    if (character != null) return true;
    return e.shift == shift;
  }

  bool matchesKey(KeyEvent event) {
    if (logical != null) return event.logicalKey == logical;
    if (physical != null) return event.physicalKey == physical;
    return event.character == character;
  }

  bool matches(KeyEvent event, {required bool macOS}) {
    final kb = HardwareKeyboard.instance;
    return matchesKey(event) &&
        matchesModifiers(
          macOS: macOS,
          meta: kb.isMetaPressed,
          control: kb.isControlPressed,
          alt: kb.isAltPressed,
          shift: kb.isShiftPressed,
        );
  }

  /// La signature qui sert à détecter un doublon: deux combos de même
  /// signature sur la même plateforme se marcheraient dessus.
  String signature({required bool macOS}) {
    final e = expected(macOS: macOS);
    final key = logical != null
        ? 'l:${logical!.keyId}'
        : physical != null
            ? 'p:${physical!.usbHidUsage}'
            : 'c:$character';
    final shiftPart = character != null ? '*' : (e.shift ? '1' : '0');
    return '$key m${e.meta ? 1 : 0}c${e.control ? 1 : 0}a${e.alt ? 1 : 0}s$shiftPart';
  }

  /// Le libellé complet, modificateurs compris, dans la convention de la
  /// plateforme (`⇧⌘M` / `Ctrl+Shift+M`).
  String label(AppLocalizations l10n, {required bool macOS}) {
    final e = expected(macOS: macOS);
    final key = display.isNotEmpty ? display : keyLabel(l10n);
    if (macOS) {
      final b = StringBuffer();
      if (e.control) b.write('⌃');
      if (e.alt) b.write('⌥');
      if (e.shift) b.write('⇧');
      if (e.meta) b.write('⌘');
      b.write(key);
      return b.toString();
    }
    final parts = <String>[];
    if (e.control) parts.add('Ctrl');
    if (e.alt) parts.add('Alt');
    if (e.shift) parts.add('Shift');
    parts.add(key);
    return parts.join('+');
  }

  String keyLabel(AppLocalizations l10n) {
    if (logical == LogicalKeyboardKey.space) return l10n.shortcutsKeySpace;
    if (logical == LogicalKeyboardKey.escape) return l10n.shortcutsKeyEscape;
    return display;
  }
}

class AppShortcut {
  final ShortcutId id;
  final ShortcutGroup group;
  final List<KeyCombo> keys;
  final String Function(AppLocalizations) label;
  /// `true` = macOS seulement, `false` = tout sauf macOS, `null` = partout.
  final bool? macOS;
  /// Affiché dans la liste mais JAMAIS intercepté: le système s'en charge
  /// (⌘⌃F = plein écran macOS, déjà dans le menu Fenêtre).
  final bool systemHandled;
  /// Une touche maintenue répète l'action (déplacements dans la piste).
  final bool repeats;

  const AppShortcut({
    required this.id,
    required this.group,
    required this.keys,
    required this.label,
    this.macOS,
    this.systemHandled = false,
    this.repeats = false,
  });

  bool appliesTo({required bool macOS}) =>
      this.macOS == null || this.macOS == macOS;
}

KeyCombo _k(LogicalKeyboardKey key, String display,
        {bool primary = false, bool shift = false, bool alt = false}) =>
    KeyCombo(
        logical: key,
        display: display,
        primary: primary,
        shift: shift,
        alt: alt);

const List<PhysicalKeyboardKey> _kDigits = [
  PhysicalKeyboardKey.digit0,
  PhysicalKeyboardKey.digit1,
  PhysicalKeyboardKey.digit2,
  PhysicalKeyboardKey.digit3,
  PhysicalKeyboardKey.digit4,
  PhysicalKeyboardKey.digit5,
  PhysicalKeyboardKey.digit6,
  PhysicalKeyboardKey.digit7,
  PhysicalKeyboardKey.digit8,
  PhysicalKeyboardKey.digit9,
];

/// Le numéro d'une touche de la rangée des chiffres, ou -1.
int digitOf(PhysicalKeyboardKey key) => _kDigits.indexOf(key);

/// Combien d'onglets ⌘1..⌘N couvrent (l'ordre du rail, `ShellTab.values`).
const int kShortcutTabCount = 8;

/// LA table. L'ordre est celui de l'écran d'aide.
final List<AppShortcut> kAppShortcuts = [
  // ── Lecture ──────────────────────────────────────────────────────────────
  AppShortcut(
      id: ShortcutId.playPause,
      group: ShortcutGroup.transport,
      keys: [_k(LogicalKeyboardKey.space, '')],
      label: (l) => l.shortcutPlayPause),
  AppShortcut(
      id: ShortcutId.prevTrack,
      group: ShortcutGroup.transport,
      keys: [_k(LogicalKeyboardKey.arrowLeft, '←')],
      label: (l) => l.shortcutPrevTrack),
  AppShortcut(
      id: ShortcutId.nextTrack,
      group: ShortcutGroup.transport,
      keys: [_k(LogicalKeyboardKey.arrowRight, '→')],
      label: (l) => l.shortcutNextTrack),
  AppShortcut(
      id: ShortcutId.seekBack10,
      group: ShortcutGroup.transport,
      keys: [_k(LogicalKeyboardKey.arrowLeft, '←', shift: true)],
      label: (l) => l.shortcutSeekBack10,
      repeats: true),
  AppShortcut(
      id: ShortcutId.seekForward10,
      group: ShortcutGroup.transport,
      keys: [_k(LogicalKeyboardKey.arrowRight, '→', shift: true)],
      label: (l) => l.shortcutSeekForward10,
      repeats: true),
  AppShortcut(
      id: ShortcutId.seekBack60,
      group: ShortcutGroup.transport,
      keys: [_k(LogicalKeyboardKey.arrowLeft, '←', alt: true)],
      label: (l) => l.shortcutSeekBack60,
      repeats: true),
  AppShortcut(
      id: ShortcutId.seekForward60,
      group: ShortcutGroup.transport,
      keys: [_k(LogicalKeyboardKey.arrowRight, '→', alt: true)],
      label: (l) => l.shortcutSeekForward60,
      repeats: true),
  AppShortcut(
      id: ShortcutId.seekPercent,
      group: ShortcutGroup.transport,
      keys: [for (final d in _kDigits) KeyCombo(physical: d, display: '0 – 9')],
      label: (l) => l.shortcutSeekPercent),
  AppShortcut(
      id: ShortcutId.repeat,
      group: ShortcutGroup.transport,
      keys: [_k(LogicalKeyboardKey.keyR, 'R')],
      label: (l) => l.shortcutRepeat),
  AppShortcut(
      id: ShortcutId.shuffle,
      group: ShortcutGroup.transport,
      keys: [_k(LogicalKeyboardKey.keyS, 'S')],
      label: (l) => l.shortcutShuffle),
  AppShortcut(
      id: ShortcutId.favorite,
      group: ShortcutGroup.transport,
      keys: [_k(LogicalKeyboardKey.keyF, 'F')],
      label: (l) => l.shortcutFavorite),
  AppShortcut(
      id: ShortcutId.speedDown,
      group: ShortcutGroup.transport,
      keys: [const KeyCombo(character: '-', display: '−')],
      label: (l) => l.shortcutSpeedDown,
      repeats: true),
  AppShortcut(
      id: ShortcutId.speedUp,
      group: ShortcutGroup.transport,
      keys: [const KeyCombo(character: '+', display: '+')],
      label: (l) => l.shortcutSpeedUp,
      repeats: true),
  AppShortcut(
      id: ShortcutId.speedReset,
      group: ShortcutGroup.transport,
      keys: [const KeyCombo(character: '=', display: '=')],
      label: (l) => l.shortcutSpeedReset),
  // ── Visualiseur ──────────────────────────────────────────────────────────
  AppShortcut(
      id: ShortcutId.vizNext,
      group: ShortcutGroup.visualizer,
      keys: [_k(LogicalKeyboardKey.keyV, 'V')],
      label: (l) => l.shortcutVizNext),
  AppShortcut(
      id: ShortcutId.vizPrev,
      group: ShortcutGroup.visualizer,
      keys: [_k(LogicalKeyboardKey.keyV, 'V', shift: true)],
      label: (l) => l.shortcutVizPrev),
  AppShortcut(
      id: ShortcutId.vizControls,
      group: ShortcutGroup.visualizer,
      keys: [
        _k(LogicalKeyboardKey.f1, 'F1'),
        _k(LogicalKeyboardKey.keyI, 'I'),
      ],
      label: (l) => l.shortcutVizControls),
  AppShortcut(
      id: ShortcutId.pmNext,
      group: ShortcutGroup.visualizer,
      keys: [_k(LogicalKeyboardKey.keyN, 'N')],
      label: (l) => l.shortcutPmNext),
  AppShortcut(
      id: ShortcutId.pmPrev,
      group: ShortcutGroup.visualizer,
      keys: [_k(LogicalKeyboardKey.keyP, 'P')],
      label: (l) => l.shortcutPmPrev),
  AppShortcut(
      id: ShortcutId.pmLock,
      group: ShortcutGroup.visualizer,
      keys: [_k(LogicalKeyboardKey.keyH, 'H')],
      label: (l) => l.shortcutPmLock),
  // X et non S: S est l'aléatoire de la FILE, une touche = une action.
  AppShortcut(
      id: ShortcutId.pmRandom,
      group: ShortcutGroup.visualizer,
      keys: [_k(LogicalKeyboardKey.keyX, 'X')],
      label: (l) => l.shortcutPmRandom),
  AppShortcut(
      id: ShortcutId.pmPicker,
      group: ShortcutGroup.visualizer,
      keys: [_k(LogicalKeyboardKey.keyL, 'L')],
      label: (l) => l.shortcutPmPicker),
  // ── Fenêtre et navigation ────────────────────────────────────────────────
  AppShortcut(
      id: ShortcutId.miniWindow,
      group: ShortcutGroup.window,
      // Pas ⌘M seul: c'est « réduire dans le Dock » sur macOS.
      keys: [_k(LogicalKeyboardKey.keyM, 'M', primary: true, shift: true)],
      label: (l) => l.shortcutMiniWindow),
  AppShortcut(
      id: ShortcutId.miniViz,
      group: ShortcutGroup.window,
      keys: [_k(LogicalKeyboardKey.keyV, 'V', primary: true, shift: true)],
      label: (l) => l.shortcutMiniViz),
  AppShortcut(
      id: ShortcutId.alwaysOnTop,
      group: ShortcutGroup.window,
      keys: [_k(LogicalKeyboardKey.keyT, 'T', primary: true, shift: true)],
      label: (l) => l.shortcutAlwaysOnTop),
  AppShortcut(
      id: ShortcutId.player,
      group: ShortcutGroup.window,
      keys: [_k(LogicalKeyboardKey.keyP, 'P', primary: true)],
      label: (l) => l.shortcutPlayer),
  AppShortcut(
      id: ShortcutId.escape,
      group: ShortcutGroup.window,
      keys: [_k(LogicalKeyboardKey.escape, '')],
      label: (l) => l.shortcutEscape),
  AppShortcut(
      id: ShortcutId.queuePanel,
      group: ShortcutGroup.window,
      keys: [_k(LogicalKeyboardKey.keyL, 'L', primary: true)],
      label: (l) => l.shortcutQueue),
  AppShortcut(
      id: ShortcutId.search,
      group: ShortcutGroup.window,
      keys: [_k(LogicalKeyboardKey.keyF, 'F', primary: true)],
      label: (l) => l.shortcutSearch),
  AppShortcut(
      id: ShortcutId.tabs,
      group: ShortcutGroup.window,
      keys: [
        for (final d in _kDigits.sublist(1, kShortcutTabCount + 1))
          KeyCombo(physical: d, primary: true, display: '1 – $kShortcutTabCount'),
      ],
      label: (l) => l.shortcutTabs),
  // La ligne « Téléchargements » du rail, juste après le dernier onglet: elle
  // POUSSE un écran au lieu de se sélectionner, d'où une entrée à part —
  // et la bascule des écrans (second appui = fermer).
  AppShortcut(
      id: ShortcutId.downloads,
      group: ShortcutGroup.window,
      keys: [
        KeyCombo(
            physical: _kDigits[kShortcutTabCount + 1],
            primary: true,
            display: '${kShortcutTabCount + 1}'),
      ],
      label: (l) => l.downloadsTitle),
  AppShortcut(
      id: ShortcutId.openFiles,
      group: ShortcutGroup.window,
      keys: [_k(LogicalKeyboardKey.keyO, 'O', primary: true)],
      label: (l) => l.shortcutOpenFiles),
  AppShortcut(
      id: ShortcutId.linkFolder,
      group: ShortcutGroup.window,
      keys: [_k(LogicalKeyboardKey.keyO, 'O', primary: true, shift: true)],
      label: (l) => l.shortcutLinkFolder),
  AppShortcut(
      id: ShortcutId.info,
      group: ShortcutGroup.window,
      keys: [_k(LogicalKeyboardKey.keyI, 'I', primary: true)],
      label: (l) => l.shortcutInfo),
  AppShortcut(
      id: ShortcutId.settings,
      group: ShortcutGroup.window,
      keys: [_k(LogicalKeyboardKey.comma, ',', primary: true)],
      label: (l) => l.shortcutSettings),
  AppShortcut(
      id: ShortcutId.fullscreen,
      group: ShortcutGroup.window,
      keys: [
        const KeyCombo(
            logical: LogicalKeyboardKey.keyF,
            primary: true,
            control: true,
            display: 'F'),
      ],
      label: (l) => l.shortcutFullscreen,
      macOS: true,
      systemHandled: true),
  AppShortcut(
      id: ShortcutId.fullscreen,
      group: ShortcutGroup.window,
      keys: [_k(LogicalKeyboardKey.f11, 'F11')],
      label: (l) => l.shortcutFullscreen,
      macOS: false),
  AppShortcut(
      id: ShortcutId.help,
      group: ShortcutGroup.window,
      keys: [const KeyCombo(character: '?', display: '?')],
      label: (l) => l.shortcutHelp),
];

/// Les entrées valables sur une plateforme, dans l'ordre de la table.
List<AppShortcut> shortcutsFor({required bool macOS}) =>
    [for (final s in kAppShortcuts) if (s.appliesTo(macOS: macOS)) s];

/// Deux entrées qui répondraient à la même touche. Pur — testé; vide attendu.
List<(ShortcutId, ShortcutId)> findShortcutConflicts({required bool macOS}) {
  final seen = <String, ShortcutId>{};
  final out = <(ShortcutId, ShortcutId)>[];
  for (final s in shortcutsFor(macOS: macOS)) {
    for (final k in s.keys) {
      final sig = k.signature(macOS: macOS);
      final prev = seen[sig];
      if (prev != null && prev != s.id) out.add((prev, s.id));
      seen.putIfAbsent(sig, () => s.id);
    }
  }
  return out;
}

/// Le visualiseur monté (lecteur ou mini fenêtre), s'il y en a un: la table
/// lui parle sans le connaître. Posé/retiré par `VizSelectorWidget`.
abstract class VizShortcutTarget {
  bool get projectmActive;
  void showControls();
  void nextEffect();
  void prevEffect();
  void pmNext();
  void pmPrev();
  void pmToggleLock();
  void pmToggleRandom();
  void pmPicker();
}

/// Le lecteur plein écran monté, s'il l'est.
///
/// Un raccourci qui OUVRE un écran le FERME au second appui (⌘I): d'où des
/// bascules, pas des ouvertures.
abstract class PlayerShortcutTarget {
  /// Le panneau ⓘ: ouvert s'il est fermé, fermé s'il est ouvert.
  void toggleInfo();
  /// Le panneau de file DU LECTEUR (il a le sien).
  bool get queueOpen;
  void toggleQueue();
}

class ShortcutTargets {
  ShortcutTargets._();
  static VizShortcutTarget? viz;
  static PlayerShortcutTarget? player;
}

/// Ce que la coquille sait faire. Chaque méthode est UNE action de la table.
abstract class AppShortcutActions {
  void playPause();
  void prevTrack();
  void nextTrack();
  void seekBy(double seconds);
  void seekToFraction(double fraction);
  void cycleRepeat();
  void toggleShuffle();
  void toggleFavorite();
  void changeSpeed(double delta);
  void resetSpeed();
  void toggleMiniWindow();
  void toggleMiniViz();
  void toggleAlwaysOnTop();
  void togglePlayer();
  /// Ferme ce qui est au-dessus: aide, lecteur, panneau de file. Rend faux
  /// s'il n'y avait rien.
  bool escape();
  /// ⌘L s'adapte à ce qui est affiché: la file du lecteur s'il est ouvert,
  /// celle du mini lecteur en mode mini, sinon celle du bureau.
  void toggleQueuePanel();
  void focusSearch();
  void selectTab(int index);
  void toggleDownloads();
  void openFiles();
  void linkFolder();
  /// ⌘I: bascule le panneau ⓘ (le lecteur s'ouvre d'abord s'il est fermé).
  void toggleInfo();
  void openSettings();
  /// `?`: ouvre la liste des raccourcis — RIEN si elle est déjà affichée,
  /// sinon on l'empile.
  void showHelp();
}

/// Le répartiteur. Une instance au plus, posée par AppShell sur le bureau.
class AppShortcuts {
  final AppShortcutActions actions;
  final bool macOS;
  AppShortcuts._(this.actions, this.macOS);

  static AppShortcuts? _installed;

  static bool get supported =>
      !kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows);

  static void install(AppShortcutActions actions) {
    if (!supported || _installed != null) return;
    final s = AppShortcuts._(actions, Platform.isMacOS);
    HardwareKeyboard.instance.addHandler(s._onKey);
    _installed = s;
  }

  static void uninstall() {
    final s = _installed;
    if (s == null) return;
    HardwareKeyboard.instance.removeHandler(s._onKey);
    _installed = null;
  }

  /// Un champ texte a le focus: toutes les touches lui appartiennent.
  ///
  /// ⚠️ `primaryFocus.context.widget is EditableText` ne suffit pas: le nœud
  /// focalisé est le `Focus` À L'INTÉRIEUR d'EditableText — d'où la remontée.
  static bool textEntryFocused() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// Un widget FOCALISABLE (bouton, curseur…) a le focus — l'utilisateur
  /// navigue au Tab: Espace et Entrée lui reviennent.
  static bool controlFocused() {
    final node = FocusManager.instance.primaryFocus;
    return node != null && node is! FocusScopeNode;
  }

  /// Une route est POUSSÉE au-dessus de celle où vit le focus (dialogue,
  /// feuille, écran de détail): Échap lui appartient.
  static bool routeAboveShell() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    final route = ModalRoute.of(ctx);
    return route != null && !route.isFirst;
  }

  bool _onKey(KeyEvent event) {
    final repeat = event is KeyRepeatEvent;
    if (event is! KeyDownEvent && !repeat) return false;
    if (textEntryFocused()) return false;
    for (final s in kAppShortcuts) {
      if (!s.appliesTo(macOS: macOS) || s.systemHandled) continue;
      if (repeat && !s.repeats) continue;
      for (final k in s.keys) {
        if (k.matches(event, macOS: macOS)) return _dispatch(s, event);
      }
    }
    return false;
  }

  bool _dispatch(AppShortcut s, KeyEvent event) {
    final a = actions;
    switch (s.id) {
      case ShortcutId.playPause:
        if (controlFocused()) return false;
        a.playPause();
      case ShortcutId.prevTrack:
        a.prevTrack();
      case ShortcutId.nextTrack:
        a.nextTrack();
      case ShortcutId.seekBack10:
        a.seekBy(-10);
      case ShortcutId.seekForward10:
        a.seekBy(10);
      case ShortcutId.seekBack60:
        a.seekBy(-60);
      case ShortcutId.seekForward60:
        a.seekBy(60);
      case ShortcutId.seekPercent:
        final d = digitOf(event.physicalKey);
        if (d < 0) return false;
        a.seekToFraction(d / 10.0);
      case ShortcutId.repeat:
        a.cycleRepeat();
      case ShortcutId.shuffle:
        a.toggleShuffle();
      case ShortcutId.favorite:
        a.toggleFavorite();
      case ShortcutId.speedDown:
        a.changeSpeed(-0.1);
      case ShortcutId.speedUp:
        a.changeSpeed(0.1);
      case ShortcutId.speedReset:
        a.resetSpeed();
      case ShortcutId.vizNext:
        final v = ShortcutTargets.viz;
        if (v == null) return false;
        v.nextEffect();
      case ShortcutId.vizPrev:
        final v = ShortcutTargets.viz;
        if (v == null) return false;
        v.prevEffect();
      case ShortcutId.vizControls:
        final v = ShortcutTargets.viz;
        if (v == null) return false;
        v.showControls();
      case ShortcutId.pmNext:
        final v = _pm();
        if (v == null) return false;
        v.pmNext();
      case ShortcutId.pmPrev:
        final v = _pm();
        if (v == null) return false;
        v.pmPrev();
      case ShortcutId.pmLock:
        final v = _pm();
        if (v == null) return false;
        v.pmToggleLock();
      case ShortcutId.pmRandom:
        final v = _pm();
        if (v == null) return false;
        v.pmToggleRandom();
      case ShortcutId.pmPicker:
        final v = _pm();
        if (v == null) return false;
        v.pmPicker();
      case ShortcutId.miniWindow:
        a.toggleMiniWindow();
      case ShortcutId.miniViz:
        a.toggleMiniViz();
      case ShortcutId.alwaysOnTop:
        a.toggleAlwaysOnTop();
      case ShortcutId.player:
        a.togglePlayer();
      case ShortcutId.escape:
        // Un dialogue ou une feuille au-dessus: Flutter ferme lui-même sur
        // Échap, et un écran poussé garde son bouton retour.
        if (routeAboveShell()) return false;
        return a.escape();
      case ShortcutId.queuePanel:
        a.toggleQueuePanel();
      case ShortcutId.search:
        a.focusSearch();
      case ShortcutId.tabs:
        final d = digitOf(event.physicalKey);
        if (d < 1 || d > kShortcutTabCount) return false;
        a.selectTab(d - 1);
      case ShortcutId.downloads:
        a.toggleDownloads();
      case ShortcutId.openFiles:
        a.openFiles();
      case ShortcutId.linkFolder:
        a.linkFolder();
      case ShortcutId.info:
        a.toggleInfo();
      case ShortcutId.settings:
        a.openSettings();
      case ShortcutId.fullscreen:
        _toggleWindowFullscreen();
      case ShortcutId.help:
        if (KeyboardShortcutsScreen.isOpen) return true;
        a.showHelp();
    }
    return true;
  }

  VizShortcutTarget? _pm() {
    final v = ShortcutTargets.viz;
    return (v != null && v.projectmActive) ? v : null;
  }

  /// F11 (Linux, Windows): le plein écran de la FENÊTRE, celui que macOS fait
  /// lui-même sur ⌘⌃F.
  static Future<void> _toggleWindowFullscreen() async {
    try {
      final fs = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!fs);
    } catch (e) {
      debugPrint('[shortcuts] fullscreen: $e');
    }
  }
}

/// La liste des raccourcis, générée depuis [kAppShortcuts]. Ouverte par `?`
/// et depuis Réglages; Échap la ferme (c'est une route: le répartiteur
/// global s'abstient, voir [AppShortcuts.routeAboveShell]).
class KeyboardShortcutsScreen extends StatefulWidget {
  const KeyboardShortcutsScreen({super.key});

  /// Combien d'exemplaires sont MONTÉS (onglet Aide, touche `?`): la touche
  /// `?` ne rouvre pas la liste par-dessus elle-même.
  static int _mounted = 0;
  static bool get isOpen => _mounted > 0;

  static Future<void> show(BuildContext context) {
    if (isOpen) return Future.value();
    return Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        builder: (_) => const KeyboardShortcutsScreen()));
  }

  static String groupTitle(ShortcutGroup g, AppLocalizations l10n) =>
      switch (g) {
        ShortcutGroup.transport => l10n.shortcutsGroupTransport,
        ShortcutGroup.visualizer => l10n.shortcutsGroupVisualizer,
        ShortcutGroup.window => l10n.shortcutsGroupWindow,
      };

  /// Les touches d'une entrée, dédoublonnées sur l'affichage (les dix
  /// chiffres font UNE puce « 0 – 9 »).
  static List<String> keyLabels(AppShortcut s, AppLocalizations l10n,
      {required bool macOS}) {
    final out = <String>[];
    for (final k in s.keys) {
      final l = k.label(l10n, macOS: macOS);
      if (!out.contains(l)) out.add(l);
    }
    return out;
  }

  @override
  State<KeyboardShortcutsScreen> createState() =>
      _KeyboardShortcutsScreenState();
}

class _KeyboardShortcutsScreenState extends State<KeyboardShortcutsScreen> {
  @override
  void initState() {
    super.initState();
    KeyboardShortcutsScreen._mounted++;
  }

  @override
  void dispose() {
    KeyboardShortcutsScreen._mounted--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final macOS = !kIsWeb && Platform.isMacOS;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final rows = <Widget>[];
    for (final g in ShortcutGroup.values) {
      final items = shortcutsFor(macOS: macOS).where((s) => s.group == g);
      if (items.isEmpty) continue;
      rows.add(Padding(
        padding: const EdgeInsetsDirectional.only(
            start: 16, end: 16, top: 20, bottom: 6),
        child: Text(KeyboardShortcutsScreen.groupTitle(g, l10n),
            style: textTheme.titleSmall?.copyWith(color: cs.primary)),
      ));
      for (final s in items) {
        rows.add(ListTile(
          dense: true,
          title: Text(s.label(l10n)),
          trailing: Wrap(
            spacing: 6,
            children: [
              for (final k in KeyboardShortcutsScreen.keyLabels(s, l10n, macOS: macOS))
                _KeyCap(k, cs: cs, textTheme: textTheme),
            ],
          ),
        ));
      }
    }
    rows.add(Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Text(l10n.shortcutsHint,
          style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
    ));
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.shortcutsTitle)),
          body: ListView(children: rows),
        ),
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  final TextTheme textTheme;
  const _KeyCap(this.text, {required this.cs, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(text,
          style: textTheme.labelMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()])),
    );
  }
}
