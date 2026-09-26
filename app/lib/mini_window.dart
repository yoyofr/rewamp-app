import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'package:rewamp_audio/rewamp_audio.dart';
import 'user_settings.dart';

/// Mode « mini lecteur » du bureau (macOS, Linux, Windows) + « toujours au
/// premier plan ».
///
/// **UNE seule fenêtre, rétrécie — pas une seconde fenêtre.** Une seconde
/// fenêtre Flutter voudrait un second moteur: ni le [PlayerController], ni la
/// file (qui appartient à AppShell), ni les textures GL ne se partagent entre
/// deux isolates. On garde donc la fenêtre, on mémorise sa géométrie, on la
/// réduit, et `MiniWindowHost` met la coquille HORS SCÈNE (toujours montée,
/// donc la file et l'état de navigation survivent) le temps du mode. En
/// sortir restaure la géométrie: on « revient sur la fenêtre principale »
/// exactement où on l'avait laissée.
class MiniWindow extends ChangeNotifier {
  MiniWindow._();
  static final MiniWindow instance = MiniWindow._();

  /// Taille minimale de la fenêtre PRINCIPALE. En dessous, la feuille du
  /// lecteur, les visualiseurs et les grilles se coupent. Source unique: le
  /// natif macOS pose la même (MainFlutterWindow.swift), Linux et Windows ne
  /// la reçoivent que d'ici — ⚠️ sur Linux elle NE DOIT PAS redevenir un
  /// `gtk_widget_set_size_request` dans le runner: c'est un plancher DUR que
  /// les geometry hints de window_manager ne peuvent pas traverser, donc le
  /// mini lecteur ne pourrait jamais descendre sous 480×640.
  static const Size kMainMinSize = Size(480, 640);

  /// Géométrie du mini lecteur (points logiques), UNE par mode.
  ///
  /// Compact: la taille par défaut EST le plancher — la mise en page (pochette,
  /// titre, seek, transport) est dessinée pour elle. Visualiseur: le défaut est
  /// un 4:3 confortable, mais le PLANCHER est bien plus bas — un viz reste
  /// lisible en vignette, et c'est l'usage (un coin d'écran). 240 de large est
  /// ce que demande la rangée de transport du voile (épingle + 3 boutons +
  /// retour ≈ 230 px); le sélecteur de modes est un Wrap, il se replie.
  static const Size kMiniSize = Size(440, 132);   // compact: défaut = plancher
  static const Size kVizSize = Size(480, 360);    // visualiseur: défaut, 4:3
  static const Size kVizMinSize = Size(240, 180); // visualiseur: plancher, 4:3

  /// Mode visualiseur du mini lecteur (retenu d'une fois sur l'autre).
  bool get vizMode => UserSettings.instance.miniWindowVizMode;
  /// Taille à (r)ouvrir: la DERNIÈRE que l'utilisateur a donnée à ce mode,
  /// jamais sous son plancher (un plancher relevé par une mise à jour ne doit
  /// pas rouvrir une fenêtre trop petite pour sa mise en page).
  Size get _modeSize {
    final def = vizMode ? kVizSize : kMiniSize;
    final saved = UserSettings.instance.miniWindowSize(viz: vizMode);
    if (saved == null) return def;
    final min = _modeMinSize;
    return Size(
      saved.$1 < min.width ? min.width : saved.$1,
      saved.$2 < min.height ? min.height : saved.$2,
    );
  }

  /// Retient la taille courante pour le mode COURANT — à appeler AVANT de
  /// changer de mode ou de quitter le mini lecteur.
  Future<void> _rememberSize() async {
    try {
      final b = await windowManager.getBounds();
      _lastMiniOrigin = b.topLeft;
      UserSettings.instance
          .setMiniWindowSize(b.width, b.height, viz: vizMode);
    } catch (_) {}
  }
  Size get _modeMinSize => vizMode ? kVizMinSize : kMiniSize;

  static bool get supported =>
      !kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows);

  /// « Toujours au premier plan » n'est offert sur Linux que sous X11.
  ///
  /// `window_manager` le fait par de l'EWMH (`_NET_WM_STATE_ABOVE`), qui
  /// n'existe que sous X11: sous Wayland l'appel n'émet AUCUN message de
  /// protocole (mesuré le 2026-09-20) et ne fait rien — d'où le masquage, un
  /// interrupteur qui ment étant pire que pas d'interrupteur. Le compositeur,
  /// lui, le propose dans son menu de fenêtre (Alt+Espace sous GNOME).
  ///
  /// Sous X11 en revanche — session Xorg, ou XWayland, ce qu'est le mode jeu
  /// du Steam Deck — ça marche, et Mutter honore l'état même pour une fenêtre
  /// XWayland (mesuré le 2026-09-26: rewamp reste au-dessus d'une fenêtre
  /// ouverte APRÈS elle, et repasse dessous une fois l'état retiré). Le
  /// backend est connu du plugin GTK avant tout affichage, donc la décision
  /// se prend une fois, au démarrage. Voir docs/FLATPAK.md §5.
  static bool get alwaysOnTopSupported =>
      supported && (!Platform.isLinux || RewampAudio().linuxDisplayIsX11);

  bool _ready = false;
  bool _busy = false;
  bool _isMini = false;
  Size? _frozenSize;
  Rect? _savedBounds;
  bool _wasMaximized = false;

  /// Dernière position du mini lecteur dans CETTE session: y revenir le
  /// remet où l'utilisateur l'avait rangé. Pas persistée d'un lancement à
  /// l'autre — un écran débranché entre-temps la mettrait hors champ.
  Offset? _lastMiniOrigin;

  bool get isMini => _isMini;

  /// Le visualiseur du LECTEUR doit céder la place: il n'en existe qu'UNE
  /// instance à la fois (contexte GL global, `kVizGlOwnedBySelector`, et son
  /// `dispose` appelle `vizUnregister`). ⚠️ Vrai pendant tout le mode mini ET
  /// une frame après la sortie: Flutter exécute le `dispose` d'un widget retiré
  /// en FIN de frame, donc APRÈS l'`initState` de celui qui le remplace dans la
  /// même frame — le sortant désenregistrerait la texture du nouveau. Le relais
  /// se fait donc toujours à une frame d'écart, dans les deux sens (voir aussi
  /// `_MiniWindowPlayerState._vizReady`).
  bool get vizYield => _vizYield;
  bool _vizYield = false;

  /// Alterne compact ⇄ visualiseur, fenêtre redimensionnée autour de son coin
  /// haut-gauche.
  Future<void> setVizMode(bool v) async {
    if (v == vizMode) return;
    if (available && _isMini) await _rememberSize();
    UserSettings.instance.miniWindowVizMode = v;
    notifyListeners();
    if (!available || !_isMini) return;
    try {
      await _applyModeSize(null);
    } catch (e) {
      debugPrint('[mini-window] mode: $e');
    }
  }

  /// Plancher abaissé, PUIS taille, PUIS plancher du mode: dans cet ordre le
  /// passage marche dans les deux sens (un min supérieur à la taille courante,
  /// ou une taille inférieure au min courant, sont refusés selon le bureau).
  Future<void> _applyModeSize(Offset? origin) async {
    final size = _modeSize;
    await windowManager.setMinimumSize(const Size(120, 90));
    if (origin != null) {
      await windowManager.setBounds(origin & size);
    } else {
      await windowManager.setSize(size);
    }
    await windowManager.setMinimumSize(_modeMinSize);
  }

  /// Taille logique de la fenêtre principale AU MOMENT d'entrer en mini: la
  /// coquille hors scène reste mise en page à cette taille (voir
  /// MiniWindowHost), sinon elle basculerait en disposition téléphone à
  /// 440 px de large et reconstruirait tout pour rien.
  Size? get frozenSize => _frozenSize;

  /// À appeler une fois dans `main()`, après `UserSettings.init()`.
  Future<void> init() async {
    if (!supported) return;
    try {
      await windowManager.ensureInitialized();
      await windowManager.setMinimumSize(kMainMinSize);
      _ready = true;
      // Le RÉGLAGE fait foi et le natif le suit — y compris quand il change
      // sans passer par nous (remise à zéro de la section « Général », qui
      // EFFACE la clé): sans cet écouteur la fenêtre resterait épinglée alors
      // que l'interrupteur dit le contraire.
      UserSettings.instance.addListener(_syncAlwaysOnTop);
      _syncAlwaysOnTop();
      if (Platform.isMacOS) {
        _menuCh.setMethodCallHandler((call) async {
          if (call.method == 'toggleAlwaysOnTop') {
            setAlwaysOnTop(!UserSettings.instance.windowAlwaysOnTop);
          }
        });
        _pushMenu();
      }
    } catch (e) {
      // Un greffon de fenêtre qui ne répond pas ne doit pas casser le
      // démarrage: le mode mini est simplement indisponible.
      debugPrint('[mini-window] init: $e');
    }
  }

  bool get available => supported && _ready;

  /// « Toujours au premier plan » — vaut pour la fenêtre principale ET le mini
  /// lecteur: c'est la même fenêtre, et un seul réglage.
  void setAlwaysOnTop(bool v) => UserSettings.instance.windowAlwaysOnTop = v;

  bool _appliedOnTop = false;

  // ── Menu « Fenêtre » de macOS ─────────────────────────────────────────────
  // Canal À PART de `rewamp/window`: celui-ci a déjà un handler Dart (plein
  // écran, player_screen) et un canal n'en porte qu'un.
  static const _menuCh = MethodChannel('rewamp/window_menu');
  String? _menuTitle;
  bool? _menuChecked;
  String? _menuTitleSent;

  /// Libellé TRADUIT de l'entrée de menu. MiniWindow n'a pas de contexte,
  /// donc c'est `MiniWindowHost` qui le pousse depuis son build — idempotent:
  /// rien ne part si ni le libellé ni la coche n'ont bougé.
  void setMenuTitle(String title) {
    if (title == _menuTitle) return;
    _menuTitle = title;
    _pushMenu();
  }

  void _pushMenu() {
    if (!_ready || !Platform.isMacOS) return;
    final checked = UserSettings.instance.windowAlwaysOnTop;
    if (checked == _menuChecked && _menuTitle == _menuTitleSent) return;
    _menuChecked = checked;
    _menuTitleSent = _menuTitle;
    _menuCh.invokeMethod('setAlwaysOnTop', {
      'checked': checked,
      if (_menuTitle != null) 'title': _menuTitle,
    }).catchError((Object e) {
      debugPrint('[mini-window] menu: $e');
    });
  }

  void _syncAlwaysOnTop() {
    final want = UserSettings.instance.windowAlwaysOnTop;
    _pushMenu();
    // UserSettings notifie pour TOUT réglage: ne toucher au natif que si
    // celui-ci a bougé.
    if (!_ready || want == _appliedOnTop) return;
    // Linux/Wayland: réglage masqué — une valeur restée à vrai d'avant ne
    // doit pas agir, puisque plus rien ne permet de la remettre à faux.
    if (!alwaysOnTopSupported) return;
    _appliedOnTop = want;
    windowManager.setAlwaysOnTop(want).catchError((Object e) {
      debugPrint('[mini-window] alwaysOnTop: $e');
    });
  }

  Future<void> toggle(Size currentLogicalSize) =>
      _isMini ? exit() : enter(currentLogicalSize);

  Future<void> enter(Size currentLogicalSize) async {
    if (!available || _isMini || _busy) return;
    _busy = true;
    try {
      // Plein écran / maximisée: en sortir d'abord, sinon le redimensionnement
      // est ignoré (macOS) ou la géométrie mémorisée est celle de l'écran.
      if (await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(false);
        // macOS anime la sortie de plein écran; redimensionner pendant
        // l'animation est sans effet.
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }
      _wasMaximized = await windowManager.isMaximized();
      if (_wasMaximized) await windowManager.unmaximize();
      final bounds = await windowManager.getBounds();
      _savedBounds = bounds;
      _frozenSize = _wasMaximized ? bounds.size : currentLogicalSize;

      // L'UI bascule AVANT le redimensionnement: la coquille est gelée à sa
      // taille, donc rien ne se remet en page pendant que la fenêtre rétrécit.
      _isMini = true;
      _vizYield = true;
      notifyListeners();

      await _tryStep(() => windowManager.setTitleBarStyle(TitleBarStyle.hidden,
          windowButtonVisibility: false));
      // Par défaut: coin haut-droit de la fenêtre principale — même écran par
      // construction.
      final origin = _lastMiniOrigin ??
          Offset(bounds.right - _modeSize.width, bounds.top);
      await _applyModeSize(origin);
    } catch (e) {
      debugPrint('[mini-window] enter: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> exit() async {
    if (!available || !_isMini || _busy) return;
    _busy = true;
    try {
      await _rememberSize();
      await _tryStep(() => windowManager.setTitleBarStyle(TitleBarStyle.normal));
      // Le plancher d'abord remonté APRÈS la géométrie: certains gestionnaires
      // de fenêtres refusent un min supérieur à la taille courante.
      final saved = _savedBounds;
      if (saved != null) await windowManager.setBounds(saved);
      await windowManager.setMinimumSize(kMainMinSize);
      if (_wasMaximized) await windowManager.maximize();
    } catch (e) {
      debugPrint('[mini-window] exit: $e');
    } finally {
      // Quoi qu'il arrive on REND la coquille: rester coincé en mini avec une
      // fenêtre à moitié restaurée serait pire qu'une géométrie approximative.
      _isMini = false;
      _frozenSize = null;
      _busy = false;
      notifyListeners();
      _releaseVizNextFrame();
    }
  }

  void _releaseVizNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vizYield = false;
      notifyListeners();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// Tests: pose le mode sans toucher à la fenêtre native.
  @visibleForTesting
  void debugSetMini(bool mini, {Size? frozenSize}) {
    _isMini = mini;
    _vizYield = mini;
    _frozenSize = mini ? frozenSize : null;
    notifyListeners();
  }

  /// Une étape COSMÉTIQUE (barre de titre) ne doit jamais empêcher le
  /// changement de mode — sa prise en charge varie selon le bureau Linux.
  Future<void> _tryStep(Future<void> Function() step) async {
    try {
      await step();
    } catch (e) {
      debugPrint('[mini-window] étape ignorée: $e');
    }
  }
}
