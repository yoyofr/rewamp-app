// L'ORDRE des sections de l'accueil — un réglage, pas une constante.
//
// Le principe: la liste persistée ne DÉCRIT que le choix de l'utilisateur, et
// elle est réconciliée avec la liste des sections que le binaire connaît à
// chaque lecture ([normalizeHomeSections]). Deux règles, chacune payée ailleurs
// dans ce projet:
//  - un id INCONNU est jeté (une section retirée d'une version à l'autre ne
//    doit pas laisser un trou ni faire planter le rendu);
//  - une section ABSENTE de la liste est réinsérée À SA PLACE PAR DÉFAUT, et
//    non ajoutée à la fin — sinon toute nouvelle section apparaîtrait tout en
//    bas chez les utilisateurs qui ont déjà rangé leur accueil, c'est-à-dire
//    là où personne ne la verra.
//
// L'identifiant est une CHAÎNE stable (`recents`, `featured`…), jamais l'index
// de l'enum: réordonner ou insérer une valeur dans l'enum changerait le sens
// de tout ce qui est déjà persisté.

import 'package:flutter/material.dart';

import 'l10n.dart';
import 'ordered_prefs.dart';
import 'user_settings.dart';

enum HomeSection {
  recents('recents'),
  featured('featured'),
  yourTrends('your_trends'),
  yourAllTimeTop('your_all_time_top'),
  trending('trending'),
  allTimeTop('all_time_top');

  // `local_files` a EXISTÉ (les gestes lire/importer sur l'accueil) et a été
  // retiré quand l'onglet Local est arrivé: mêmes gestes, meilleure place. Un
  // id persisté qui le nomme encore est simplement JETÉ par
  // normalizeHomeSections — c'est exactement le cas « section retirée d'une
  // version à l'autre » que l'en-tête de ce fichier annonce.


  const HomeSection(this.id);

  /// Clé persistée. Stable — voir l'en-tête du fichier.
  final String id;

  static HomeSection? byId(String id) {
    for (final s in HomeSection.values) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Libellé traduit. Une méthode et non un champ `const`: un libellé dans un
  /// champ constant est intraduisible (règle i18n du projet).
  String label(AppLocalizations l10n) => switch (this) {
        HomeSection.recents        => l10n.recentlyPlayed,
        HomeSection.featured       => l10n.featuredTitle,
        HomeSection.yourTrends     => l10n.homeYourTrends,
        HomeSection.yourAllTimeTop => l10n.homeYourAllTimeTop,
        HomeSection.trending       => l10n.homeTrending,
        HomeSection.allTimeTop     => l10n.homeAllTimeTop,
      };
}

/// L'ordre livré — celui de l'accueil avant que ce réglage existe.
const List<HomeSection> kHomeSectionsDefault = HomeSection.values;

/// Réconcilie une liste persistée avec les sections que ce binaire connaît:
/// les ids inconnus tombent, les sections manquantes reviennent à leur place
/// par défaut, les doublons sont écrasés. Pure — testée.
List<HomeSection> normalizeHomeSections(List<String> stored) {
  final seen = <HomeSection>{};
  final kept = <HomeSection>[];
  for (final id in stored) {
    final s = HomeSection.byId(id);
    if (s == null || !seen.add(s)) continue;
    kept.add(s);
  }
  if (kept.isEmpty) return List.of(kHomeSectionsDefault);
  // Fusion STABLE avec l'ordre livré — voir ordered_prefs.dart pour les deux
  // règles naïves qui ont échoué avant elle.
  return mergePreferredOrder(kept, kHomeSectionsDefault);
}

/// L'écran d'édition, ouvert depuis l'accueil ET depuis les Réglages — un seul
/// widget pour les deux, sinon les deux divergent.
class HomeSectionsOrderScreen extends StatefulWidget {
  const HomeSectionsOrderScreen({super.key});

  @override
  State<HomeSectionsOrderScreen> createState() =>
      _HomeSectionsOrderScreenState();
}

class _HomeSectionsOrderScreenState extends State<HomeSectionsOrderScreen> {
  late List<HomeSection> _order = UserSettings.instance.homeSectionOrder;

  void _save() =>
      UserSettings.instance.homeSectionOrder = _order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDefault = _order.length == kHomeSectionsDefault.length &&
        List.generate(_order.length, (i) => _order[i] == kHomeSectionsDefault[i])
            .every((e) => e);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeSectionsOrderTitle),
        actions: [
          TextButton(
            onPressed: isDefault
                ? null
                : () {
                    setState(() => _order = List.of(kHomeSectionsDefault));
                    UserSettings.instance.resetHomeSectionOrder();
                  },
            child: Text(l10n.homeSectionsOrderReset),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(l10n.homeSectionsOrderSubtitle,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _order.length,
              // `onReorderItem` et non `onReorder`: celui-ci compte la cible
              // dans la liste d'AVANT le retrait (un de trop dès qu'on
              // descend), et il est déprécié depuis que Flutter fait
              // l'ajustement lui-même.
              onReorderItem: (from, to) {
                setState(() => _order.insert(to, _order.removeAt(from)));
                _save();
              },
              itemBuilder: (ctx, i) {
                final s = _order[i];
                return ListTile(
                  key: ValueKey(s.id),
                  leading: const Icon(Icons.drag_handle),
                  title: Text(s.label(l10n)),
                  trailing: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_indicator),
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

/// Ouvre l'éditeur d'ordre. Un seul point d'entrée pour l'accueil et les
/// Réglages — l'accueil se reconstruit au retour parce que [UserSettings] est
/// un ChangeNotifier et que la liste est lue à chaque build.
Future<void> openHomeSectionsOrder(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const HomeSectionsOrderScreen()));
