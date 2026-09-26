import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Le jeton de compte, dans un FICHIER en 0600 — le repli quand aucun service
/// de secrets n'existe.
///
/// Sur un bureau Linux sans `org.freedesktop.secrets` (Steam Deck en mode
/// bureau, une session sans gnome-keyring ni KWallet, un AppImage lancé hors
/// session…), libsecret répond « The name is not activatable » et le jeton ne
/// pouvait vivre qu'en MÉMOIRE. Conséquence mesurée le 2026-09-26: à CHAQUE
/// lancement, `token=false` ⇒ nouvelle inscription ⇒ « account replaced » —
/// le compte de la veille et sa bibliothèque serveur abandonnés, sans un mot.
///
/// Un fichier lisible par le seul utilisateur, sous le dossier de l'app, est
/// ce que `gh`, `git` (credential store) ou `ssh` font depuis toujours: pas
/// un secret chiffré, mais un secret QUI RESTE, et que seul ce compte système
/// peut lire. Décision du 2026-09-26. Le service de secrets garde la priorité
/// partout où il existe; ce fichier n'est écrit que sur son échec, et il est
/// effacé dès qu'un service redevient joignable et accepte le jeton.
class TokenFile {
  TokenFile._();

  /// Tests: un dossier imposé à la place du dossier de support.
  @visibleForTesting
  static Directory? dirOverride;

  static const _name = 'auth_token';

  static Future<File> _file() async {
    final dir = dirOverride ?? await getApplicationSupportDirectory();
    return File('${dir.path}/$_name');
  }

  static Future<String?> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final v = (await f.readAsString()).trim();
      return v.isEmpty ? null : v;
    } catch (e) {
      debugPrint('[TokenFile] read failed: $e');
      return null;
    }
  }

  /// Écrit le jeton, permissions 0600 posées AVANT le contenu: un fichier
  /// créé sous un umask permissif serait lisible le temps du chmod.
  static Future<bool> write(String token) async {
    try {
      final f = await _file();
      await f.parent.create(recursive: true);
      if (!await f.exists()) {
        await f.writeAsString('');
        await _restrict(f);
      }
      await f.writeAsString(token, flush: true);
      await _restrict(f);
      return true;
    } catch (e) {
      debugPrint('[TokenFile] write failed: $e');
      return false;
    }
  }

  static Future<void> delete() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('[TokenFile] delete failed: $e');
    }
  }

  /// `chmod 600`: dart:io n'a pas d'API de permissions. Windows n'a pas de
  /// bits de mode — le profil utilisateur y est déjà privé par ACL.
  static Future<void> _restrict(File f) async {
    if (Platform.isWindows) return;
    final r = await Process.run('chmod', ['600', f.path]);
    if (r.exitCode != 0) {
      throw FileSystemException('chmod 600 a échoué: ${r.stderr}', f.path);
    }
  }
}
