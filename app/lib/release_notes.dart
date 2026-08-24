import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'data_reset.dart' show dataWasReset;
import 'l10n.dart';
import 'splash_intro.dart' show kSplashBg;
import 'user_settings.dart';

/// Note de version montrée UNE fois, au premier lancement d'une build, dans la
/// continuité du splash.
///
/// **Bumper ce nombre = remontrer la note**, sur chaque appareil, au prochain
/// démarrage. Il est indépendant du numéro de build: une build de correction
/// n'a rien à raconter et ne doit pas rouvrir l'écran.
const kReleaseNotesVersion = 4;

/// Nom public de la version. Pas de traduction: c'est un nom, comme « Rewamp ».
const kReleaseNotesLabel = 'Beta 4';

/// Les points de la note, dans l'ordre d'affichage. Une note SYNTHÉTIQUE: ce
/// que l'utilisateur verra changer, pas le journal des commits. Le dernier
/// point est l'avertissement d'effacement (voir data_reset.dart) — il est
/// délibérément en dernier et signalé, c'est la seule ligne qui demande
/// quelque chose au lecteur plutôt que de lui annoncer un gain.
List<String> releaseNotesBullets(AppLocalizations l10n) => [
      l10n.releaseNotesV4Downloads,
      l10n.releaseNotesV4Queue,
      l10n.releaseNotesV4DropFiles,
      l10n.releaseNotesV4Soundfont,
      l10n.releaseNotesV4Formats,
      l10n.releaseNotesV4Chips,
      l10n.releaseNotesV4Zx,
      l10n.releaseNotesV4Loop,
      l10n.releaseNotesV4Info,
      l10n.releaseNotesV4Linux,
    ];

/// L'écran lui-même: fond du splash, logo réduit, la note, un bouton.
///
/// Il reprend le fond du splash plutôt que le thème de l'app parce qu'il
/// PROLONGE l'intro — l'animation se termine, le logo remonte, le texte
/// apparaît. Basculer sur une surface Material ferait un deuxième écran là où
/// il n'y a qu'un seul moment.
class ReleaseNotesSplash extends StatelessWidget {
  final ui.Image? image;
  final VoidCallback onDismiss;

  const ReleaseNotesSplash({super.key, this.image, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final img  = image;
    // Texte clair imposé: le fond est sombre quel que soit le thème système.
    const fg  = Colors.white;
    final dim = Colors.white.withValues(alpha: 0.72);

    return Material(
      color: kSplashBg,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (img != null)
                          Center(
                            child: SizedBox(
                              width: 96, height: 96,
                              child: RawImage(image: img, fit: BoxFit.contain),
                            ),
                          ),
                        const SizedBox(height: 20),
                        Text(l10n.releaseNotesTitle,
                            style: const TextStyle(
                              color: fg,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(height: 4),
                        Text(kReleaseNotesLabel,
                            style: TextStyle(color: dim, fontSize: 15)),
                        const SizedBox(height: 22),
                        for (final b in releaseNotesBullets(l10n))
                          _Bullet(text: b, color: fg),
                        // L'effacement est signalé à part: il ne s'annonce pas
                        // comme une nouveauté, il prévient d'une perte. Et il
                        // ne s'affiche QUE s'il a eu lieu — une première
                        // installation n'a rien perdu.
                        if (dataWasReset) ...[
                          const SizedBox(height: 14),
                          _Bullet(
                            text: l10n.releaseNotesDataReset,
                            color: dim,
                            icon: Icons.info_outline,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onDismiss,
                      child: Text(l10n.releaseNotesDismiss),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _Bullet({
    required this.text,
    required this.color,
    this.icon = Icons.check,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(color: color, fontSize: 14.5, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

/// La note est-elle encore à montrer sur cet appareil ?
bool releaseNotesPending() =>
    UserSettings.instance.releaseNotesShown < kReleaseNotesVersion;

void markReleaseNotesShown() =>
    UserSettings.instance.releaseNotesShown = kReleaseNotesVersion;
