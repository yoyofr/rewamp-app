// Navigation à la TÉLÉCOMMANDE (Android TV): croix directionnelle + OK.
//
// Flutter sait déjà déplacer le focus aux flèches et activer au OK/Entrée
// (raccourcis par défaut de WidgetsApp). Ce qui manquait, sur TV:
//  * des cartes FOCALISABLES — nos cartes d'accueil, de bibliothèque, de
//    dossier sont des `GestureDetector`, qu'aucune flèche n'atteint;
//  * un focus VISIBLE de loin — le surlignage Material d'un ListTile ou d'un
//    InkWell est fait pour un clavier à 50 cm, pas pour un canapé à 3 m;
//  * l'appui LONG — le menu des cartes (feuille « Lire / Ajouter / Voir… »)
//    n'avait pas d'équivalent sans doigt: OK maintenu, ou touche Menu.
//
// Tout ici est INERTE hors TV ([TvFocus.enabled]): le bureau et le mobile ne
// changent pas (pas de nœud de focus de plus dans le parcours au Tab).
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show HitTestResult;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'orientation_lock.dart';

class TvFocus {
  TvFocus._();

  /// Vrai sur Android TV. Lu après `OrientationLock.initTv()` (main.dart).
  static bool get enabled => OrientationLock.isTv;

  /// Scope du menu latéral (app_shell.dart): ↑/↓ y restent, ← / → en sortent
  /// par [TvDirectionalFocusAction].
  static final FocusScopeNode railScope = FocusScopeNode(debugLabel: 'tv-rail');

  /// Index de l'onglet SÉLECTIONNÉ dans le menu (posé par AppShell): entrer
  /// dans le menu par ← y mène, et non au dernier élément focalisé du menu —
  /// un écran ouvert depuis le menu (Téléchargements, pleine page) ne change
  /// pas d'onglet.
  static int Function()? railSelectedIndex;

  /// Le mini lecteur (mini_player.dart): ↓ au bout du menu y mène, OK ouvre
  /// le lecteur. Le contenu, lui, défile jusqu'à sa fin avant d'y arriver.
  static final FocusNode miniPlayerNode = FocusNode(debugLabel: 'tv-mini-player');

  /// À appeler une fois, après la détection TV.
  static void install() {
    if (!enabled) return;
    // Sur un appareil tactile Flutter part en mode « toucher », où aucun
    // focus ne se dessine tant qu'une touche n'a pas été pressée. Une TV n'a
    // que des touches.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    FocusManager.instance.addListener(_onFocusMoved);
  }

  static FocusNode? _lastFollowed;

  /// Le rectangle du nœud, ou null s'il n'est pas (encore) mesurable: un
  /// nœud sans contexte ou dont la boîte n'est pas mise en page fait lever
  /// `FocusNode.rect` (assertion, vu au démarrage sur l'émulateur TV).
  static Rect? safeRect(FocusNode n) {
    final ctx = n.context;
    if (ctx == null || !ctx.mounted) return null;
    // Un élément DÉSACTIVÉ (route qui se ferme, onglet qui sort) garde son
    // contexte mais `findRenderObject` y lève une assertion.
    RenderObject? ro;
    try {
      ro = ctx.findRenderObject();
    } catch (_) {
      return null;
    }
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    final r = n.rect;
    return r.isEmpty ? null : r;
  }

  static void _onFocusMoved() {
    final n = FocusManager.instance.primaryFocus;
    if (n == null || identical(n, _lastFollowed)) return;
    _lastFollowed = n;
    if (kDebugMode) {
      final r = safeRect(n);
      debugPrint('[tv-focus] ${n.debugLabel ?? n.context?.widget.runtimeType} '
          '${r == null ? '(non mesuré)' : '${r.left.round()},${r.top.round()} '
              '${r.width.round()}x${r.height.round()}'}');
    }
    // Après le défilement que Flutter fait de lui-même (bord du cadre).
    WidgetsBinding.instance.addPostFrameCallback((_) => _follow(n));
  }

  /// Garde le focus LISIBLE: centré verticalement dans sa liste (sinon une
  /// rangée du bas passait sous le mini lecteur flottant — « je ne vois plus
  /// où je suis »), et à une marge du bord dans une rangée horizontale
  /// (sinon la première carte collait au bord et son anneau était rogné).
  static void _follow(FocusNode n) {
    final ctx = n.context;
    if (ctx == null || !ctx.mounted || !n.hasPrimaryFocus) return;
    final item = safeRect(n);
    if (item == null) return;
    var scrollable = Scrollable.maybeOf(ctx);
    while (scrollable != null) {
      final box = scrollable.context.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        final view = box.localToGlobal(Offset.zero) & box.size;
        final pos = scrollable.position;
        final vertical = pos.axis == Axis.vertical;
        double delta = 0;
        if (vertical) {
          // Centré, sauf si l'élément est plus haut que le cadre.
          if (item.height < view.height) {
            delta = item.center.dy - view.center.dy;
          }
        } else if (item.width < view.width * 0.8) {
          // Seulement pour une CARTE dans une rangée. Une ligne pleine
          // largeur vit souvent dans un défilement horizontal de PAGES (les
          // onglets Artistes / Albums de la Recherche = TabBarView): la
          // « marge » la poussait de quelques pixels, puis la page se
          // recalait — un aller-retour horizontal à chaque ↓.
          const margin = 24.0;
          if (item.left < view.left + margin) {
            delta = item.left - (view.left + margin);
          } else if (item.right > view.right - margin) {
            delta = item.right - (view.right - margin);
          }
        }
        if (delta.abs() > 1) {
          final target = (pos.pixels + delta)
              .clamp(pos.minScrollExtent, pos.maxScrollExtent);
          if ((target - pos.pixels).abs() > 1) {
            pos.animateTo(target,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic);
          }
        }
      }
      scrollable = Scrollable.maybeOf(scrollable.context);
    }
  }

  /// Touches qui ACTIVENT (OK de la télécommande, Entrée, A d'une manette).
  static bool isActivateKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.gameButtonA;

  /// Touches qui valent un APPUI LONG d'emblée (Menu, Y d'une manette).
  static bool isMenuKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.contextMenu ||
      k == LogicalKeyboardKey.gameButtonY;
}

/// Rend [child] focalisable sur TV et l'active au OK. Maintenir OK (ou la
/// touche Menu) vaut l'appui long.
///
/// ⚠️ Le tap part au RELÂCHER du OK, pas à l'appui: c'est la seule façon de
/// distinguer un appui long (Android répète la touche tant qu'elle est tenue)
/// d'un appui bref.
class TvActivatable extends StatefulWidget {
  const TvActivatable({
    super.key,
    required this.onTap,
    this.onLongPress,
    this.focusNode,
    required this.child,
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final FocusNode? focusNode;
  final Widget child;

  @override
  State<TvActivatable> createState() => _TvActivatableState();
}

class _TvActivatableState extends State<TvActivatable> {
  bool _down = false;
  bool _longFired = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final k = e.logicalKey;
    if (TvFocus.isMenuKey(k)) {
      if (e is KeyDownEvent && widget.onLongPress != null) {
        widget.onLongPress!();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (!TvFocus.isActivateKey(k)) return KeyEventResult.ignored;
    if (e is KeyDownEvent) {
      _down = true;
      _longFired = false;
    } else if (e is KeyRepeatEvent) {
      if (_down && !_longFired && widget.onLongPress != null) {
        _longFired = true;
        widget.onLongPress!();
      }
    } else if (e is KeyUpEvent) {
      final tap = _down && !_longFired;
      _down = false;
      if (tap) widget.onTap();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (!TvFocus.enabled) return widget.child;
    return Focus(
        focusNode: widget.focusNode, onKeyEvent: _onKey, child: widget.child);
  }
}

/// Anneau de focus visible de loin, autour de [child], quand un nœud de son
/// sous-arbre a le focus. La forme de l'arbre ne dépend PAS du focus (seule
/// la couleur de la bordure change).
class TvFocusRing extends StatefulWidget {
  const TvFocusRing({
    super.key,
    required this.child,
    this.radius = 10,
    this.onFocusChange,
  });

  final Widget child;
  final double radius;
  final ValueChanged<bool>? onFocusChange;

  @override
  State<TvFocusRing> createState() => _TvFocusRingState();
}

class _TvFocusRingState extends State<TvFocusRing> {

  @override
  Widget build(BuildContext context) {
    if (!TvFocus.enabled) return widget.child;
    // Un Focus qui ne prend PAS le focus lui-même: il ne sert qu'à savoir si
    // un DESCENDANT l'a (InkWell, ListTile, TvActivatable…). L'anneau, lui,
    // est dessiné pour TOUTE l'app par [_TvFocusHighlight].
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) => widget.onFocusChange?.call(f),
      child: widget.child,
    );
  }
}

/// Remplace l'action « focus dans une direction » sur TV.
///
/// ⚠️ La traversée directionnelle de Flutter ne sort JAMAIS du FocusScope
/// courant, et chaque route en a un: le contenu d'un onglet vit dans le
/// Navigator IMBRIQUÉ de l'onglet, le menu latéral et le mini lecteur dans
/// la coquille — ← depuis la première carte ne trouvait donc rien à gauche
/// (constaté sur l'émulateur TV, 2026-11-15). On garde la traversée de
/// Flutter quand elle aboutit; sinon on cherche, dans TOUT l'écran, le nœud
/// le plus proche dans la direction — à condition qu'il soit VISIBLE et
/// touchable à cet endroit (test de touche en son centre), ce qui écarte les
/// routes recouvertes et ce qui passe sous le mini lecteur flottant.
class TvDirectionalFocusAction extends Action<DirectionalFocusIntent> {
  @override
  void invoke(DirectionalFocusIntent intent) {
    final current = FocusManager.instance.primaryFocus;
    if (current == null) return;
    final dir = intent.direction;
    // ← / → : seulement dans la MÊME rangée (recouvrement vertical). Flutter,
    // faute de voisin dans la rangée, prenait le nœud le plus proche à
    // gauche N'IMPORTE OÙ — une carte d'une autre rangée, hors écran (vu:
    // ← depuis la 1re carte ⇒ focus à y = 1083 sur un écran de 540).
    if (dir == TraversalDirection.left || dir == TraversalDirection.right) {
      final inRow = _nearestInRow(current, dir);
      if (inRow != null) {
        _focus(inRow);
        return;
      }
      // Bout de rangée: le nœud visible le plus proche (menu latéral…).
      final next = _nearestOnScreen(current, dir);
      if (next != null) {
        _focus(next);
      }
      return;
    }
    // Rien de focalisé (un scope seul): Flutter choisit le premier élément.
    // Ou, au lancement, le menu ENTIER (un scope) — rien de visible.
    // On pose alors le focus sur le premier élément VISIBLE du contenu (en
    // haut à gauche), comme une appli TV; à défaut l'onglet du menu.
    if (current is FocusScopeNode &&
        (current.focusedChild == null || identical(current, TvFocus.railScope))) {
      final first = _firstVisible(current) ?? _railSelectedNode();
      if (first != null) {
        first.requestFocus();
      } else {
        current.focusInDirection(dir);
      }
      return;
    }
    // ↑ / ↓ : par les CENTRES, comme ← / → — la traversée de Flutter exige
    // qu'une cible soit entièrement au-dessus / au-dessous du bord, donc les
    // contrôles posés PAR-DESSUS le visualiseur (mode, plein écran, fermer,
    // options) n'étaient jamais atteints depuis lui.
    // Sur un bouton DU mini lecteur (atteint par ← / →), ↓ reprend le mini
    // lecteur ENTIER — d'où OK ouvre le lecteur.
    final mini = TvFocus.miniPlayerNode;
    if (dir == TraversalDirection.down &&
        !identical(current, mini) &&
        _isWithin(current, mini) &&
        mini.canRequestFocus) {
      _focus(mini);
      return;
    }
    final inRail = _isWithin(current, TvFocus.railScope);
    // Hors du menu, ↑ / ↓ n'y entrent JAMAIS: depuis la 1re carte d'une
    // rangée, l'entrée du menu à côté (45 dp plus bas) battait la carte de la
    // rangée suivante (230 dp). On entre dans le menu par ← seulement.
    final vertical = _nearestVertical(current, dir,
        within: inRail ? TvFocus.railScope : null,
        exclude: inRail ? null : TvFocus.railScope);
    if (vertical != null) {
      _focus(vertical);
      return;
    }
    // Au bout du menu latéral, ↓ va au mini lecteur (s'il est là): sinon la
    // recherche géométrique préférait la carte du contenu la plus proche.
    if (intent.direction == TraversalDirection.down && inRail) {
      if (mini.context != null && mini.canRequestFocus) {
        _focus(mini);
        return;
      }
    }
    final next = _nearestOnScreen(current, intent.direction);
    if (next != null) {
      _focus(next);
    }
  }

  /// Donne le focus SANS le défilement de Flutter: son `ensureVisible`
  /// alignait l'élément sur un bord de CHAQUE liste ancêtre (la page
  /// verticale comprise), puis [TvFocus._follow] recentrait — un aller-retour
  /// vertical à chaque ← / →. Le seul défilement est celui de `_follow`.
  ///
  /// Deux redirections, pour qu'on ENTRE quelque part par son point logique:
  ///  * dans le menu latéral depuis l'extérieur ⇒ l'onglet où l'on était
  ///    (le dernier focalisé du menu), pas l'entrée qui se trouve à la même
  ///    hauteur que la ligne quittée (← depuis l'Aide menait à « Search »);
  ///  * dans le mini lecteur depuis l'extérieur ⇒ la barre ENTIÈRE (OK ouvre
  ///    le lecteur), pas le bouton le plus proche (↓ menait à « précédent »).
  static void _focus(FocusNode n) {
    final from = FocusManager.instance.primaryFocus;
    var target = n;
    if (from != null) {
      final rail = TvFocus.railScope;
      if (_isWithin(n, rail) && !_isWithin(from, rail)) {
        final selected = _railSelectedNode();
        final last = rail.focusedChild;
        if (selected != null) {
          target = selected;
        } else if (last != null &&
            last.canRequestFocus &&
            TvFocus.safeRect(last) != null) {
          target = last;
        }
      }
      final mini = TvFocus.miniPlayerNode;
      if (!identical(n, mini) &&
          _isWithin(n, mini) &&
          !_isWithin(from, mini) &&
          mini.canRequestFocus) {
        target = mini;
      }
    }
    target.requestFocus();
  }

  /// Le premier élément visible (le plus haut, puis le plus à gauche) sous
  /// [scope], hors menu latéral et hors mini lecteur.
  static FocusNode? _firstVisible(FocusScopeNode scope) {
    final root = identical(scope, TvFocus.railScope)
        ? FocusManager.instance.rootScope
        : scope;
    FocusNode? best;
    Rect? bestR;
    for (final n in root.traversalDescendants) {
      if (n is FocusScopeNode || !n.canRequestFocus) continue;
      if (_isWithin(n, TvFocus.railScope) ||
          _isWithin(n, TvFocus.miniPlayerNode)) {
        continue;
      }
      final r = TvFocus.safeRect(n);
      if (r == null) continue;
      if (bestR != null &&
          (r.top > bestR.top + 4 ||
              ((r.top - bestR.top).abs() <= 4 && r.left >= bestR.left))) {
        continue;
      }
      if (!_hittableAtCenter(n)) continue;
      best = n;
      bestR = r;
    }
    return best;
  }

  /// L'entrée du menu de l'onglet sélectionné: les entrées focalisables du
  /// menu, dans l'ordre vertical, sont celles des destinations.
  static FocusNode? _railSelectedNode() {
    final idx = TvFocus.railSelectedIndex?.call();
    if (idx == null || idx < 0) return null;
    final entries = <(FocusNode, Rect)>[];
    for (final n in TvFocus.railScope.traversalDescendants) {
      if (n is FocusScopeNode || !n.canRequestFocus) continue;
      final r = TvFocus.safeRect(n);
      if (r != null) entries.add((n, r));
    }
    entries.sort((a, b) => a.$2.top.compareTo(b.$2.top));
    return idx < entries.length ? entries[idx].$1 : null;
  }

  static FocusNode? _nearestOnScreen(FocusNode from, TraversalDirection dir) {
    final cur = TvFocus.safeRect(from);
    if (cur == null) return null;
    FocusNode? best;
    var bestScore = double.infinity;
    for (final n in FocusManager.instance.rootScope.traversalDescendants) {
      if (identical(n, from) || n is FocusScopeNode) continue;
      if (!n.canRequestFocus || _isWithin(from, n)) continue;
      final r = TvFocus.safeRect(n);
      if (r == null) continue;
      final double along;   // distance dans la direction (>= 0 sinon exclu)
      final double across;  // décalage perpendiculaire (0 si recouvrement)
      switch (dir) {
        case TraversalDirection.left:
          along = cur.left - r.right;
          across = _gap(cur.top, cur.bottom, r.top, r.bottom);
        case TraversalDirection.right:
          along = r.left - cur.right;
          across = _gap(cur.top, cur.bottom, r.top, r.bottom);
        case TraversalDirection.up:
          along = cur.top - r.bottom;
          across = _gap(cur.left, cur.right, r.left, r.right);
        case TraversalDirection.down:
          along = r.top - cur.bottom;
          across = _gap(cur.left, cur.right, r.left, r.right);
      }
      if (along < -2) continue;
      final score = along.clamp(0, double.infinity) + across * 3;
      if (score >= bestScore) continue;
      if (!_hittableAtCenter(n)) continue;
      best = n;
      bestScore = score;
    }
    return best;
  }

  /// Le voisin dans la rangée: même bande verticale (au moins la moitié de la
  /// plus petite des deux hauteurs en commun), dans la direction, le plus
  /// proche. Hors écran permis (une rangée défile vers lui), mais alors dans
  /// la MÊME liste défilante que le nœud courant.
  static FocusNode? _nearestInRow(FocusNode from, TraversalDirection dir) {
    final cur = TvFocus.safeRect(from);
    if (cur == null || from.context == null) return null;
    final fromScroll = Scrollable.maybeOf(from.context!);
    FocusNode? best;
    var bestAlong = double.infinity;
    for (final n in FocusManager.instance.rootScope.traversalDescendants) {
      if (identical(n, from) || n is FocusScopeNode || !n.canRequestFocus) {
        continue;
      }
      final r = TvFocus.safeRect(n);
      if (r == null) continue;
      final overlap = (cur.bottom < r.bottom ? cur.bottom : r.bottom) -
          (cur.top > r.top ? cur.top : r.top);
      final minH = cur.height < r.height ? cur.height : r.height;
      if (overlap < minH * 0.5) continue;
      // Par les CENTRES, pas par les bords: un bouton peut être DANS
      // l'élément focalisé (les boutons du mini lecteur sont dans sa zone
      // cliquable) — par les bords il n'était jamais « à gauche » de lui.
      // Un ANCÊTRE du nœud courant n'est jamais une destination.
      if (_isWithin(from, n) || _encloses(r, cur)) continue;
      final along = dir == TraversalDirection.left
          ? cur.center.dx - r.center.dx
          : r.center.dx - cur.center.dx;
      if (along <= 1) continue;
      // À distance égale (deux lignes face à une entrée du menu), la plus
      // alignée verticalement.
      final score = along + (r.center.dy - cur.center.dy).abs() * 0.5;
      if (score >= bestAlong) continue;
      final sameList = fromScroll != null &&
          identical(Scrollable.maybeOf(n.context!), fromScroll);
      if (!sameList && !_hittableAtCenter(n)) continue;
      best = n;
      bestAlong = score;
    }
    return best;
  }

  /// Le voisin au-dessus / au-dessous: centre strictement dans la direction,
  /// le plus proche, en préférant ce qui recouvre horizontalement. Hors écran
  /// permis s'il défile avec le nœud courant (même liste ancêtre), sinon il
  /// doit être visible et touchable. [within]: limiter à ce scope.
  static FocusNode? _nearestVertical(FocusNode from, TraversalDirection dir,
      {FocusNode? within, FocusNode? exclude}) {
    final cur = TvFocus.safeRect(from);
    if (cur == null || from.context == null) return null;
    final fromScrolls = _scrollablesOf(from.context!);
    // Deux classements: ce qui DÉFILE avec le nœud courant (la suite de la
    // page) passe avant le reste (mini lecteur flottant…). Sinon, dans Stats,
    // ↓ depuis les puces de période sautait au mini lecteur, aligné juste
    // dessous, au lieu de descendre vers « Top tracks » — on n'atteignait
    // jamais le bas de la page. Le reste ne gagne qu'au bout du contenu.
    FocusNode? best, bestOther;
    var bestScore = double.infinity, bestOtherScore = double.infinity;
    for (final n in FocusManager.instance.rootScope.traversalDescendants) {
      if (identical(n, from) || n is FocusScopeNode || !n.canRequestFocus) {
        continue;
      }
      if (_isWithin(from, n)) continue;
      if (within != null && !_isWithin(n, within)) continue;
      if (exclude != null && _isWithin(n, exclude)) continue;
      final r = TvFocus.safeRect(n);
      if (r == null || _encloses(r, cur)) continue;
      final along = dir == TraversalDirection.down
          ? r.center.dy - cur.center.dy
          : cur.center.dy - r.center.dy;
      if (along <= 1) continue;
      final across = _gap(cur.left, cur.right, r.left, r.right);
      final score = along + across * 4 + (r.center.dx - cur.center.dx).abs() * 0.1;
      final shared = _scrollablesOf(n.context!).any(fromScrolls.contains);
      if (shared) {
        if (score >= bestScore) continue;
        best = n;
        bestScore = score;
      } else {
        if (score >= bestOtherScore || !_hittableAtCenter(n)) continue;
        bestOther = n;
        bestOtherScore = score;
      }
    }
    return best ?? bestOther;
  }

  /// [outer] contient entièrement [inner]: c'est un CONTENANT de l'élément
  /// focalisé (la surface du visualiseur sous ses boutons), pas un voisin —
  /// son centre, proche, l'emportait sur le bouton d'à côté. On en sort par
  /// Retour ou quand les contrôles s'effacent (le focus y revient seul).
  static bool _encloses(Rect outer, Rect inner) =>
      outer.left <= inner.left + 1 &&
      outer.top <= inner.top + 1 &&
      outer.right >= inner.right - 1 &&
      outer.bottom >= inner.bottom - 1 &&
      outer.width * outer.height > inner.width * inner.height * 1.5;

  static Set<ScrollableState> _scrollablesOf(BuildContext ctx) {
    final out = <ScrollableState>{};
    var s = Scrollable.maybeOf(ctx);
    while (s != null) {
      out.add(s);
      s = Scrollable.maybeOf(s.context);
    }
    return out;
  }

  static bool _isWithin(FocusNode n, FocusNode scope) {
    for (FocusNode? p = n; p != null; p = p.parent) {
      if (identical(p, scope)) return true;
    }
    return false;
  }

  static double _gap(double a0, double a1, double b0, double b1) {
    if (b1 < a0) return a0 - b1;
    if (b0 > a1) return b0 - a1;
    return 0;
  }

  /// Le nœud est-il VU et touchable en son centre ? Un nœud d'une route
  /// recouverte, d'un onglet hors scène ou sous un élément flottant échoue.
  static bool _hittableAtCenter(FocusNode n) {
    final ro = n.context?.findRenderObject();
    if (ro == null || !ro.attached) return false;
    final view = View.maybeOf(n.context!);
    if (view == null) return false;
    final result = HitTestResult();
    WidgetsBinding.instance
        .hitTestInView(result, TvFocus.safeRect(n)!.center, view.viewId);
    for (final e in result.path) {
      if (identical(e.target, ro)) return true;
    }
    return false;
  }
}

/// Pose [TvDirectionalFocusAction] pour toute l'app (MaterialApp.builder).
/// Sans effet hors TV.
Widget tvFocusScope(Widget child) {
  if (!TvFocus.enabled) return child;
  return Shortcuts(
    // ↑ / ↓ SORTENT d'un champ de texte: les raccourcis d'édition de Flutter
    // les gardent (début / fin du texte sur une seule ligne), et dans la
    // Recherche on restait prisonnier du champ, curseur clignotant. Ces
    // raccourcis-ci sont plus proches du focus que ceux d'édition (posés par
    // WidgetsApp au-dessus du builder), donc ils l'emportent; ← / → gardent
    // leur rôle dans le texte. Un Slider garde les siens (plus proches encore).
    shortcuts: const <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.arrowUp): _TvMoveIntent(TraversalDirection.up),
      SingleActivator(LogicalKeyboardKey.arrowDown): _TvMoveIntent(TraversalDirection.down),
    },
    child: Actions(
    actions: <Type, Action<Intent>>{
      DirectionalFocusIntent: TvDirectionalFocusAction(),
      _TvMoveIntent: CallbackAction<_TvMoveIntent>(
        onInvoke: (i) {
          TvDirectionalFocusAction().invoke(DirectionalFocusIntent(i.direction));
          return null;
        },
      ),
    },
    // Même raison que `_focus`: la traversée de Flutter (↑ / ↓) ne défile
    // plus d'elle-même, `TvFocus._follow` s'en charge, une seule fois.
    child: FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(
        requestFocusCallback: (node,
                {alignment, alignmentPolicy, curve, duration}) =>
            node.requestFocus(),
      ),
      // Navigation DIRECTIONNELLE (télécommande) déclarée aux widgets
      // Material: en mode « traditionnel » un Slider garde ↑ / ↓ pour
      // lui-même (il ajuste sa valeur) — on ne sortait plus de la barre de
      // progression du lecteur. En directionnel il ne prend que ← / →.
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(navigationMode: NavigationMode.directional),
          child: _TvFocusHighlight(child: child),
        ),
      ),
    ),
  ),
  );
}

/// ↑ / ↓ de la télécommande, y compris depuis un champ de texte.
class _TvMoveIntent extends Intent {
  const _TvMoveIntent(this.direction);
  final TraversalDirection direction;
}

/// L'anneau de focus de TOUTE l'app, dessiné par-dessus tout autour du nœud
/// focalisé, quel qu'il soit.
///
/// Les surlignages propres à chaque widget ne suffisent pas: un InkResponse
/// dessine son focus sur le Material le plus proche, et dans les contrôles
/// du visualiseur (posés sur des fonds opaques) il ne se voyait pas du tout
/// — « on ne sait pas où on est ». Un seul anneau, même forme partout, se
/// voit de loin. Redessiné au changement de focus et à chaque défilement
/// (l'élément bouge avec sa liste), jamais en continu.
class _TvFocusHighlight extends StatefulWidget {
  const _TvFocusHighlight({required this.child});
  final Widget child;

  @override
  State<_TvFocusHighlight> createState() => _TvFocusHighlightState();
}

class _TvFocusHighlightState extends State<_TvFocusHighlight> {
  final _repaint = ValueNotifier<int>(0);
  final _paintKey = GlobalKey();

  void _bump() {
    _repaint.value++;
    // Une seconde fois après la mise en page qui suit (le nœud vient d'être
    // monté, ou sa liste vient de défiler d'un bond).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _repaint.value++;
    });
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_bump);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_bump);
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (_) {
        _repaint.value++;
        return false;
      },
      child: Stack(children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: _paintKey,
              painter: _TvFocusPainter(_repaint, color, _paintKey),
            ),
          ),
        ),
      ]),
    );
  }
}

class _TvFocusPainter extends CustomPainter {
  _TvFocusPainter(this._repaint, this.color, this._key)
      : super(repaint: _repaint);
  final ValueNotifier<int> _repaint;
  final Color color;
  final GlobalKey _key;

  @override
  void paint(Canvas canvas, Size size) {
    final n = FocusManager.instance.primaryFocus;
    if (n == null || n is FocusScopeNode) return;
    final r = TvFocus.safeRect(n);
    if (r == null) return;
    // Le Stack est à la racine de l'app mais peut être décalé (bandeau
    // « hors ligne » au-dessus): rectangle global → repère du canvas.
    final box = _key.currentContext?.findRenderObject();
    final origin = box is RenderBox && box.attached
        ? box.localToGlobal(Offset.zero)
        : Offset.zero;
    final local = r.shift(-origin);
    final rr = RRect.fromRectAndRadius(local.inflate(2), const Radius.circular(10));
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_TvFocusPainter old) => old.color != color;
}

/// Un champ de texte sur TV: le focus seul ne doit PAS ouvrir le clavier.
///
/// Arriver sur le champ de Recherche aux flèches ouvrait le clavier de la TV
/// aussitôt — il couvre la moitié de l'écran et prend la croix
/// directionnelle pour lui, alors qu'on ne faisait que passer. Ici le champ
/// reste en LECTURE SEULE (pas de connexion au clavier) tant qu'on n'a pas
/// pressé OK dessus; il le redevient quand il perd le focus.
///
/// Usage: `gate.attach(focusNode)` une fois, `readOnly: gate.readOnly` sur
/// le TextField, et reconstruire quand le gate notifie. Inerte hors TV.
class TvTextGate extends ChangeNotifier {
  bool _editing = false;

  bool get readOnly => TvFocus.enabled && !_editing;

  void attach(FocusNode node) {
    if (!TvFocus.enabled) return;
    node.onKeyEvent = (n, e) {
      if (!_editing &&
          e is KeyDownEvent &&
          TvFocus.isActivateKey(e.logicalKey)) {
        _editing = true;
        notifyListeners();
        // Après la reconstruction qui ouvre la connexion au clavier.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SystemChannels.textInput.invokeMethod<void>('TextInput.show');
        });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    node.addListener(() {
      if (!node.hasFocus && _editing) {
        _editing = false;
        notifyListeners();
      }
    });
  }
}

/// Monte un champ de texte derrière un [TvTextGate] sans que l'appelant ait à
/// gérer un état: [builder] reçoit le FocusNode à poser et la valeur de
/// `readOnly`. Pour les champs partagés (filtres de liste…).
class TvGatedText extends StatefulWidget {
  const TvGatedText({super.key, required this.builder});
  final Widget Function(FocusNode focusNode, bool readOnly) builder;

  @override
  State<TvGatedText> createState() => _TvGatedTextState();
}

class _TvGatedTextState extends State<TvGatedText> {
  final _node = FocusNode();
  final _gate = TvTextGate();

  @override
  void initState() {
    super.initState();
    _gate.attach(_node);
    _gate.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _gate.dispose();
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(_node, _gate.readOnly);
}
