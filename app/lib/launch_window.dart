// Bureau: sur quelle fenêtre démarrer — normale, mini lecteur, ou comme à la
// fermeture (Winamp).
//
// ⚠️ Le RUNNER natif doit le savoir AVANT de montrer la fenêtre: démarrer en
// mini, c'est garder la fenêtre INVISIBLE jusqu'à ce que Dart l'ait rétrécie
// (même mécanique que `rewamp --mini`, voir revealLaunchWindow). Or le natif ne
// lit pas les préférences Dart. Dart lui CONFIE donc la réponse
// (`rewamp/cli` `setLaunchMini`) et il la range à sa façon — UserDefaults sur
// macOS, registre HKCU sur Windows, un fichier du dossier de données sous
// Linux: aucun chemin à faire concorder entre les deux mondes. Une réponse
// désaccordée ne coûte qu'un instant: fenêtre vue en grand, ou filet natif de
// 5 s si elle restait cachée.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'l10n/app_localizations.dart';
import 'user_settings.dart';

enum LaunchWindowMode {
  normal,
  mini,
  last;

  static LaunchWindowMode fromName(String? s) {
    for (final v in values) {
      if (v.name == s) return v;
    }
    return LaunchWindowMode.normal;
  }

  String label(AppLocalizations l10n) => switch (this) {
        LaunchWindowMode.normal => l10n.settingsLaunchWindowNormal,
        LaunchWindowMode.mini   => l10n.settingsLaunchWindowMini,
        LaunchWindowMode.last   => l10n.settingsLaunchWindowLast,
      };
}

/// Le prochain lancement (sans `--mini` ni `--window`) part-il en mini?
bool launchPrefersMini(UserSettings s) => switch (s.launchWindow) {
      LaunchWindowMode.normal => false,
      LaunchWindowMode.mini   => true,
      LaunchWindowMode.last   => s.lastWindowMini,
    };

const _cli = MethodChannel('rewamp/cli');
bool? _sent;

/// Recopie [launchPrefersMini] chez le natif — seulement quand la réponse
/// CHANGE. À appeler au démarrage, quand le réglage change et à chaque
/// bascule du mini lecteur (pour `last`).
Future<void> syncLaunchWindow() async {
  if (kIsWeb || !(Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
    return;
  }
  final mini = launchPrefersMini(UserSettings.instance);
  if (_sent == mini) return;
  try {
    await _cli.invokeMethod<void>('setLaunchMini', mini);
    _sent = mini;
  } catch (e) {
    debugPrint('[launch-window] $e');
  }
}
