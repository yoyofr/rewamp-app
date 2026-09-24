import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

/// Enveloppe un champ texte et lui fournit une croix d'ANNULATION.
///
/// Sur mobile, ouvrir un champ de recherche fait monter le clavier virtuel et
/// il n'y a alors plus rien pour en sortir sans avoir tapé quoi que ce soit:
/// le geste « je me suis trompé d'onglet » n'a pas d'issue, et un champ VIDE
/// n'affiche évidemment pas de bouton « effacer ». D'où une croix visible dès
/// que le champ a le FOCUS, même vide — elle efface la saisie ET referme le
/// clavier. La largeur du champ se réduit d'elle-même pendant ce temps: la
/// croix vit dans le `suffixIcon`, que `InputDecorator` retire de la place
/// offerte au texte.
///
/// ⚠️ **La croix vit À CÔTÉ du champ, jamais dans son `suffixIcon`.** Posée
/// dedans, elle est DANS la zone de geste du `TextField`: l'appuyer efface et
/// referme le clavier, puis le champ traite le même tap, redemande le focus et
/// le clavier remonte aussitôt — le bouton avait l'air de ne rien faire. En
/// voisin dans une `Row`, le tap ne l'atteint jamais. C'est aussi ce qui donne
/// le rétrécissement voulu: le champ rend sa largeur le temps de la saisie et
/// la reprend quand la croix disparaît.
///
/// Le focus est observé par un `Focus` PARENT plutôt que par un `FocusNode`
/// posé sur le champ: `hasFocus` d'un nœud est vrai dès qu'un DESCENDANT a le
/// focus, ce qui évite d'imposer un nœud (donc un State) à chaque site
/// d'appel — la plupart de ces champs vivent dans des closures de feuilles ou
/// de dialogues qui n'en ont pas.
class CancelField extends StatefulWidget {
  /// Le contrôleur du champ, quand il en a un. Certains champs gardent leur
  /// texte dans l'état de leur écran et n'en ont pas: ils passent [hasText] à
  /// la place et effacent eux-mêmes depuis [onCleared].
  final TextEditingController? controller;

  /// Y a-t-il quelque chose à effacer, pour un champ sans contrôleur.
  final bool? hasText;

  /// Construit le champ. La croix est ajoutée À CÔTÉ, par cette classe.
  final Widget Function(BuildContext context) builder;

  /// Prévenu APRÈS l'effacement, avec la chaîne vide — les champs de recherche
  /// relancent leur requête depuis `onChanged`, que `clear()` ne déclenche pas.
  final ValueChanged<String>? onCleared;

  /// Taille de l'icône, à accorder à celle du champ (les champs denses de
  /// filtre en utilisent de plus petites).
  final double iconSize;

  const CancelField({
    super.key,
    this.controller,
    this.hasText,
    required this.builder,
    this.onCleared,
    this.iconSize = 18,
  });

  /// Vrai là où un clavier VIRTUEL couvre l'écran. Sur un ordinateur la croix
  /// à vide n'annulerait rien de visible: le champ garde le comportement
  /// habituel (croix seulement quand il y a du texte à effacer).
  /// `defaultTargetPlatform` plutôt que `Platform.isIOS`: c'est la même
  /// réponse en production, et c'est la seule des deux qu'un test peut
  /// remplacer (`debugDefaultTargetPlatformOverride`).
  static bool get softKeyboard =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  @override
  State<CancelField> createState() => _CancelFieldState();
}

class _CancelFieldState extends State<CancelField> {
  final _node = FocusNode(skipTraversal: true, canRequestFocus: false);

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  bool get _hasText =>
      widget.controller?.text.isNotEmpty ?? widget.hasText ?? false;

  void _cancel() {
    final had = _hasText;
    widget.controller?.clear();
    // Refermer le clavier fait partie de l'annulation: c'est ce qu'on n'avait
    // pas moyen de faire, et c'est aussi la seule chose qui reste à faire
    // quand le champ était déjà vide.
    FocusManager.instance.primaryFocus?.unfocus();
    if (had) widget.onCleared?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      onFocusChange: (_) => setState(() {}),
      // Sans contrôleur il n'y a rien à écouter: le texte vit dans l'état de
      // l'appelant, qui se reconstruit tout seul quand il change.
      child: widget.controller == null
          ? _build(context)
          : AnimatedBuilder(
              animation: widget.controller!,
              builder: (ctx, _) => _build(ctx),
            ),
    );
  }

  Widget _build(BuildContext ctx) {
    final show = _hasText || (_node.hasFocus && CancelField.softKeyboard);
    // ⚠️ La FORME de l'arbre ne change JAMAIS: `Row` toujours, deux enfants
    // toujours, le champ toujours à la même place. Ne l'envelopper QUE quand la
    // croix est visible remplaçait le widget à ce niveau, donc Flutter
    // démontait le sous-arbre et en remontait un neuf — un `TextField` y perd
    // son état, son focus et le clavier qu'on venait d'ouvrir. Le bouton
    // apparaît en échangeant le SECOND enfant, ce que le premier ne voit pas.
    return Row(children: [
      Expanded(child: widget.builder(ctx)),
      if (show)
        // Contraintes serrées: certains de ces champs vivent dans une boîte de
        // 40 px de haut, où un IconButton de taille par défaut déborde.
        IconButton(
          icon: Icon(Icons.clear, size: widget.iconSize),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          visualDensity: VisualDensity.compact,
          tooltip: MaterialLocalizations.of(ctx).cancelButtonLabel,
          onPressed: _cancel,
        )
      else
        const SizedBox.shrink(),
    ]);
  }
}
