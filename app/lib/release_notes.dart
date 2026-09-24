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
///
/// Beta 6: la note passe à 6 parce que son CONTENU change (trois points de
/// plus). Ni la 5.0 ni la 5.1 n'ayant été téléversées, personne n'a vu la
/// version 5 — les douze puces qu'elle portait restent donc des nouveautés
/// pour tout le monde.
///
/// **7 = beta 6.1.** La note 6 a été VUE (la beta 6 est partie sur les trois
/// canaux le 2026-09-08), donc ses vingt puces sont RETIRÉES et remplacées:
/// une version de note est un jeu de clés, et remontrer ce que le lecteur a
/// déjà lu noie ce qui a réellement changé depuis.
///
/// Portée GELÉE le 2026-09-19, toujours en **7**: la beta 6.1 (`0.6.1+13`)
/// n'avait été ni bâtie ni envoyée, donc personne n'a vu cette note — elle
/// s'élargit à dix jours de plus au lieu de passer à 8. Quinze puces: les
/// nouveautés d'abord, puis les correctifs, les gains de ressources en
/// dernier (juste avant l'éventuel avertissement d'effacement).
const kReleaseNotesVersion = 7;

const kReleaseNotesLabel = 'Beta 6.1';

/// Les points de la note, dans l'ordre d'affichage. Une note SYNTHÉTIQUE: ce
/// que l'utilisateur verra changer, pas le journal des commits. Le dernier
/// point est l'avertissement d'effacement (voir data_reset.dart) — il est
/// délibérément en dernier et signalé, c'est la seule ligne qui demande
/// quelque chose au lecteur plutôt que de lui annoncer un gain.
List<String> releaseNotesBullets(AppLocalizations l10n) => [
      l10n.releaseNotesV7Mt32,
      l10n.releaseNotesV7Xmp,
      l10n.releaseNotesV7AmigaAdlib,
      l10n.releaseNotesV7MiniPlayer,
      l10n.releaseNotesV7Instruments,
      l10n.releaseNotesV7Podium,
      l10n.releaseNotesV7ShortSubsongs,
      l10n.releaseNotesV7LocalFolders,
      l10n.releaseNotesV7Subsongs,
      l10n.releaseNotesV7Midi,
      l10n.releaseNotesV7ProjectM,
      l10n.releaseNotesV7Piano,
      l10n.releaseNotesV7VizIdle,
      l10n.releaseNotesV7Cpu,
      l10n.releaseNotesV7Database,
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

/// Ouvre la note de version à la demande (depuis « À propos »).
///
/// Même écran qu'au premier lancement, sans le logo: hors de la continuité du
/// splash il n'y a pas d'intro à prolonger, et le rappeler ferait un deuxième
/// écran de bienvenue là où l'utilisateur a simplement demandé à relire.
Future<void> showReleaseNotes(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) =>
          ReleaseNotesSplash(onDismiss: () => Navigator.of(ctx).pop()),
    ),
  );
}

/// La note est-elle encore à montrer sur cet appareil ?
bool releaseNotesPending() =>
    UserSettings.instance.releaseNotesShown < kReleaseNotesVersion;

void markReleaseNotesShown() =>
    UserSettings.instance.releaseNotesShown = kReleaseNotesVersion;
