// Onglet « Aide »: les raccourcis clavier (bureau) et le lien vers la
// documentation en ligne (rewamp.app/docs, en anglais, avec captures). Le
// guide des fonctions vit sur le site, pas dans l'app: une seule source à
// tenir à jour.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_shortcuts.dart';
import 'app_snack.dart';
import 'l10n.dart';

/// La documentation en ligne (site rewamp_web, dossier `docs/`).
const kOnlineDocsUrl = 'https://rewamp.app/docs/';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    Future<void> openDocs() async {
      final messenger = ScaffoldMessenger.of(context);
      final ok = await launchUrl(Uri.parse(kOnlineDocsUrl),
          mode: LaunchMode.externalApplication);
      if (!ok) AppSnack.showOn(messenger, kOnlineDocsUrl);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: ListView(
        children: [
          // Les raccourcis: la table d'app_shortcuts.dart, générée — la même
          // que la touche « ? ».
          if (AppShortcuts.supported)
            ListTile(
              leading: Icon(Icons.keyboard_outlined, color: cs.primary),
              title: Text(l10n.shortcutsTitle, style: textTheme.titleMedium),
              subtitle: Text(l10n.shortcutsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const KeyboardShortcutsScreen())),
            ),
          ListTile(
            leading: Icon(Icons.menu_book_outlined, color: cs.primary),
            title: Text(l10n.helpDocsTitle, style: textTheme.titleMedium),
            subtitle: Text(l10n.helpDocsSubtitle),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: openDocs,
          ),
        ],
      ),
    );
  }
}
