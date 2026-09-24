// Notification de changement de piste sous LINUX, par l'interface standard du
// bureau (`org.freedesktop.Notifications`, via D-Bus).
//
// Même rôle que le canal `rewamp/notify` de l'AppDelegate macOS — mêmes
// données, même réglage (`notifyTrackChange`, désactivé par défaut), même
// déclencheur (`PlayerController._notifyTrackChange`, 1,5 s après le
// chargement pour laisser la pochette arriver).
//
// Deux indications qui font la différence avec une notification naïve:
//
//   * `replaces_id` — chaque piste REMPLACE la notification de la précédente
//     au lieu de s'empiler. Des sous-chansons de jeu durent souvent trente
//     secondes: sans ça, une pile de bulles en quelques minutes.
//   * `transient` — la notification n'est PAS conservée dans l'historique du
//     bureau. Une annonce de piste passée n'a plus rien à dire.

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

class LinuxTrackNotifier {
  LinuxTrackNotifier._();

  static DBusClient? _client;

  /// L'identifiant de la DERNIÈRE notification montrée, rendu par le serveur:
  /// on le lui repasse pour qu'il la remplace.
  static int _lastId = 0;

  /// Les arguments de `Notify`, construits à part pour être TESTÉS: c'est là
  /// que se jouent l'échappement du texte et les indications.
  @visibleForTesting
  static List<DBusValue> notifyArgs({
    required String title,
    required String body,
    String? imagePath,
    int replacesId = 0,
  }) =>
      [
        const DBusString('Rewamp'), // app_name
        DBusUint32(replacesId),
        // Nom d'icône du thème: celle que le flatpak et l'AppImage installent.
        const DBusString('app.rewamp.Rewamp'),
        DBusString(title),
        // ⚠️ Le corps accepte un balisage minimal (spec `body-markup`), le
        // titre non. Un artiste « Tom & Jerry » passerait sinon pour une
        // entité mal formée — et GNOME rejette alors TOUT le corps.
        DBusString(escapeMarkup(body)),
        DBusArray.string(const []), // actions: aucune
        DBusDict.stringVariant({
          'desktop-entry': const DBusString('app.rewamp.Rewamp'),
          'transient': const DBusBoolean(true),
          if (imagePath != null && imagePath.isNotEmpty)
            'image-path': DBusString(Uri.file(imagePath).toString()),
        }),
        const DBusInt32(-1), // délai: celui du serveur
      ];

  @visibleForTesting
  static String escapeMarkup(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  /// Montre (ou remplace) la notification. Ne lève JAMAIS: un serveur de
  /// notifications absent ou refusant ne doit pas toucher à la lecture.
  static Future<void> show({
    required String title,
    required String body,
    String? imagePath,
  }) async {
    try {
      final client = _client ??= DBusClient.session();
      final reply = await DBusRemoteObject(
        client,
        name: 'org.freedesktop.Notifications',
        path: DBusObjectPath('/org/freedesktop/Notifications'),
      ).callMethod(
        'org.freedesktop.Notifications',
        'Notify',
        notifyArgs(
            title: title, body: body, imagePath: imagePath, replacesId: _lastId),
        replySignature: DBusSignature('u'),
      );
      _lastId = (reply.values.first as DBusUint32).value;
    } catch (e) {
      debugPrint('[notify] Linux: $e');
    }
  }
}
