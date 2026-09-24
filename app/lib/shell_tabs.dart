// Les ONGLETS de la coquille — leur ordre, celui du lancement, et ce qui tient
// dans la barre d'un téléphone.
//
// Même modèle que home_sections.dart, et pour les mêmes raisons: l'identifiant
// persisté est une CHAÎNE stable (jamais l'index de l'enum, qu'une insertion
// décalerait), ce qui est stocké n'est QUE le choix de l'utilisateur, et la
// liste rendue est réconciliée à chaque lecture avec les onglets que ce binaire
// connaît — id inconnu jeté, onglet neuf réinséré JUSTE APRÈS sa plus proche
// devancière de l'ordre livré (viser la suivante rate dès qu'elle a été
// déplacée en tête).
//
// ⚠️ **L'index de l'enum EST l'index de `_screens`** dans app_shell: la liste
// d'écrans est construite dans cet ordre, et c'est aussi l'ordre du rail de
// bureau. Insérer une valeur au milieu de l'enum déplace donc un écran —
// à faire en connaissance de cause, et jamais pour changer un ORDRE
// D'AFFICHAGE, qui est un réglage.

import 'package:flutter/material.dart';

import 'l10n.dart';
import 'ordered_prefs.dart';
import 'user_settings.dart';

enum ShellTab {
  home('home', Icons.home_outlined, Icons.home),
  search('search', Icons.search_outlined, Icons.search),
  // Sous « Recherche »: c'est un navigateur, comme elle — mais du contenu
  // qu'on possède déjà.
  local('local', Icons.devices_outlined, Icons.devices),
  library('library', Icons.library_music_outlined, Icons.library_music),
  stats('stats', Icons.bar_chart_outlined, Icons.bar_chart),
  settings('settings', Icons.settings_outlined, Icons.settings),
  about('about', Icons.info_outline, Icons.info);

  const ShellTab(this.id, this.icon, this.selectedIcon);

  /// Clé persistée, stable — voir l'en-tête.
  final String id;
  final IconData icon;
  final IconData selectedIcon;

  static ShellTab? byId(String id) {
    for (final t in ShellTab.values) {
      if (t.id == id) return t;
    }
    return null;
  }

  String label(AppLocalizations l10n) => switch (this) {
        ShellTab.home     => l10n.navHome,
        ShellTab.search   => l10n.navSearch,
        ShellTab.local    => l10n.navLocal,
        ShellTab.library  => l10n.navLibrary,
        ShellTab.stats    => l10n.navStats,
        ShellTab.settings => l10n.navSettings,
        ShellTab.about    => l10n.navAbout,
      };
}

/// L'ordre du RAIL de bureau: celui de l'enum, donc celui des écrans.
const List<ShellTab> kShellTabsDefault = ShellTab.values;

/// Combien d'onglets tiennent dans la barre d'un téléphone. Le cinquième
/// emplacement est le « … », qui n'est pas un onglet mais l'ouverture du reste.
const int kPhoneBarSlots = 4;

/// L'ordre livré sur TÉLÉPHONE — et il diffère de celui du rail exprès.
///
/// La barre ne montre que [kPhoneBarSlots] onglets: y placer « Local » en
/// troisième (sa place au rail, sous « Recherche ») en chasserait « Stats »,
/// alors que le local est un écran qu'on ouvre à l'occasion. Il commence donc
/// dans le « … », d'où l'utilisateur peut le remonter s'il s'en sert.
const List<ShellTab> kPhoneTabsDefault = [
  ShellTab.home,
  ShellTab.search,
  ShellTab.library,
  ShellTab.stats,
  ShellTab.local,
  ShellTab.settings,
  ShellTab.about,
];

/// Réconcilie une liste persistée avec les onglets connus. Pure — testée.
List<ShellTab> normalizeShellTabs(List<String> stored,
    {List<ShellTab> fallback = kPhoneTabsDefault}) {
  final seen = <ShellTab>{};
  final kept = <ShellTab>[];
  for (final id in stored) {
    final t = ShellTab.byId(id);
    if (t == null || !seen.add(t)) continue;
    kept.add(t);
  }
  if (kept.isEmpty) return List.of(fallback);
  // Fusion STABLE — voir ordered_prefs.dart.
  return mergePreferredOrder(kept, fallback);
}

/// Les onglets de la BARRE (les [kPhoneBarSlots] premiers) et ceux du « … ».
(List<ShellTab> bar, List<ShellTab> overflow) splitPhoneTabs(
    List<ShellTab> order) {
  final bar = order.take(kPhoneBarSlots).toList();
  return (bar, order.skip(kPhoneBarSlots).toList());
}

/// L'éditeur d'ordre des onglets du téléphone. Même patron que
/// [HomeSectionsOrderScreen] — et la ligne de séparation après le quatrième
/// est le CONTRAT de l'écran: sans elle, « ranger ses onglets » ne dit pas ce
/// qui disparaît dans le « … ».
class ShellTabsOrderScreen extends StatefulWidget {
  const ShellTabsOrderScreen({super.key});

  @override
  State<ShellTabsOrderScreen> createState() => _ShellTabsOrderScreenState();
}

class _ShellTabsOrderScreenState extends State<ShellTabsOrderScreen> {
  late List<ShellTab> _order = UserSettings.instance.phoneTabOrder;

  bool get _isDefault {
    if (_order.length != kPhoneTabsDefault.length) return false;
    for (var i = 0; i < _order.length; i++) {
      if (_order[i] != kPhoneTabsDefault[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTabsOrderTitle),
        actions: [
          TextButton(
            onPressed: _isDefault
                ? null
                : () {
                    setState(() => _order = List.of(kPhoneTabsDefault));
                    UserSettings.instance.resetPhoneTabOrder();
                  },
            child: Text(l10n.homeSectionsOrderReset),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(l10n.settingsTabsOrderSubtitle,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _order.length,
              onReorderItem: (from, to) {
                setState(() => _order.insert(to, _order.removeAt(from)));
                UserSettings.instance.phoneTabOrder = _order;
              },
              itemBuilder: (ctx, i) {
                final t = _order[i];
                final inBar = i < kPhoneBarSlots;
                return Container(
                  key: ValueKey(t.id),
                  decoration: BoxDecoration(
                    border: i == kPhoneBarSlots
                        ? Border(top: BorderSide(color: cs.outlineVariant))
                        : null,
                  ),
                  child: ListTile(
                    leading: Icon(t.icon,
                        color: inBar ? null : cs.onSurfaceVariant),
                    title: Text(t.label(l10n)),
                    subtitle: Text(
                        inBar ? l10n.settingsTabsInBar : l10n.settingsTabsInMore,
                        style: TextStyle(color: cs.onSurfaceVariant)),
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_indicator),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> openShellTabsOrder(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const ShellTabsOrderScreen()));
