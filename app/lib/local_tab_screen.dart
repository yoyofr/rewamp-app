// La racine de l'onglet « Local »: deux arbres, et les deux gestes qui font
// entrer des fichiers dans l'app.
//
// Pourquoi un niveau de plus plutôt que deux onglets: ce sont deux arbres du
// MÊME contenu — ce que cet appareil possède — et ils se parcourent de la même
// façon (mêmes dossiers, même recherche, même « tout lire »). Ce qui les
// sépare est la PROPRIÉTÉ: les imports appartiennent à l'utilisateur (il les
// supprime d'ici), les téléchargements appartiennent au catalogue (ils se
// re-téléchargent, et leur suppression est un geste de place disque, dans
// Réglages → Données → Stockage).

import 'package:flutter/material.dart';

import 'l10n.dart';
import 'local_db.dart';
import 'local_ops.dart' show LocalOpsBanner;
import 'local_import.dart' show showLocalImportSheet;
import 'local_library_screen.dart';

class LocalTabScreen extends StatefulWidget {
  /// « Lire des fichiers » / « Lire un dossier » — les sélecteurs d'OUVERTURE
  /// (écoute jetable), pas l'import. Fournis par la coquille, qui seule sait
  /// mettre en file. Le bouton unique de la barre ouvre une feuille de choix,
  /// symétrique du « + » (importer des fichiers / un dossier).
  final Future<void> Function(BuildContext context)? onPlayFiles;
  final Future<void> Function(BuildContext context)? onPlayFolder;

  const LocalTabScreen({super.key, this.onPlayFiles, this.onPlayFolder});

  @override
  State<LocalTabScreen> createState() => _LocalTabScreenState();
}

class _LocalTabScreenState extends State<LocalTabScreen> {
  int? _imports;
  int? _downloads;

  @override
  void initState() {
    super.initState();
    _load();
    // Un import, une suppression ou un téléchargement changent les comptes.
    LocalDb.instance.addListener(_load);
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    // Des COMPTES, pas des listes: cet écran n'affiche que deux nombres, et il
    // se recharge à chaque notification de la base. Charger les deux listes
    // entières coûtait un balayage complet de `tracks` (voir
    // LocalDb.countDownloadedTracks).
    final imports   = await LocalDb.instance.countLocalImports();
    final downloads = await LocalDb.instance.countDownloadedTracks();
    if (!mounted) return;
    setState(() {
      _imports = imports;
      _downloads = downloads;
    });
  }

  /// Fichiers ou dossier — la même paire que le « + », côté lecture.
  Future<void> _showPlaySheet() async {
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.onPlayFiles != null)
              ListTile(
                leading: const Icon(Icons.audio_file_outlined),
                title: Text(l10n.homePlayFiles),
                onTap: () => Navigator.pop(ctx, 0),
              ),
            if (widget.onPlayFolder != null)
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: Text(l10n.homePlayFolder),
                onTap: () => Navigator.pop(ctx, 1),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 0) {
      await widget.onPlayFiles!(context);
    } else {
      await widget.onPlayFolder!(context);
    }
  }

  void _open(LocalBrowseSource source, String title) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => LocalLibraryScreen(source: source, title: title),
      ));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navLocal),
      ),
      // `ListView` (un `BoxScrollView`) lit la marge basse du chrome TOUT SEUL
      // tant qu'on ne lui donne pas de `padding` — voir shell_insets.dart.
      body: ListView(
        children: [
          // Un import ou une suppression en cours se voit ICI d'abord — c'est
          // l'écran où l'on revient voir si c'est fini.
          const LocalOpsBanner(),
          // Les ACTIONS d'abord, et dans la LISTE — pas en haut à droite.
          // Reléguées en icônes d'AppBar elles étaient les deux gestes les
          // plus utiles de l'écran et les moins visibles: deux glyphes sans
          // texte, à l'opposé du regard qui descend la liste. Un écran qui
          // n'offre que deux rubriques a la place de les montrer en toutes
          // lettres.
          //
          // ⚠️ Libellés au VERBE: « Lecture » était un NOM et détonnait à côté
          // d'« Importer ». Une ligne de liste qui déclenche une action se lit
          // à l'infinitif — et elle annonce les DEUX choix de la feuille
          // qu'elle ouvre (fichier ou dossier), sinon on ne sait pas avant
          // d'avoir tapé.
          if (widget.onPlayFiles != null || widget.onPlayFolder != null)
            _entry(
              cs,
              icon: Icons.audio_file_outlined,
              label: l10n.localActionPlay,
              count: null,
              subtitle: '',
              onTap: _showPlaySheet,
            ),
          _entry(
            cs,
            icon: Icons.library_add_outlined,
            label: l10n.localActionImport,
            count: null,
            subtitle: '',
            onTap: () => showLocalImportSheet(context),
          ),
          const Divider(height: 1),
          _entry(
            cs,
            icon: Icons.download_outlined,
            label: l10n.downloadsTitle,
            count: _downloads,
            onTap: () =>
                _open(LocalBrowseSource.downloads, l10n.downloadsTitle),
          ),
          _entry(
            cs,
            icon: Icons.folder_special_outlined,
            label: l10n.storageLocalImports,
            count: _imports,
            onTap: () =>
                _open(LocalBrowseSource.imports, l10n.storageLocalImports),
          ),
        ],
      ),
    );
  }

  /// Une ligne de l'écran. [subtitle] vide = pas de sous-titre du tout: une
  /// ACTION n'a pas de compte à afficher, et lui coller « … » lui ferait
  /// promettre un chargement qui ne viendra jamais.
  Widget _entry(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required int? count,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    final l10n = context.l10n;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(label),
      // Le compte est CHARGÉ, pas deviné: un arbre vide et un arbre pas encore
      // lu ne se disent pas pareil.
      subtitle: subtitle != null
          ? (subtitle.isEmpty ? null : Text(subtitle))
          : Text(count == null ? '…' : l10n.albumTrackCount(count)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
