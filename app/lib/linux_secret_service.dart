import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

/// Is there a Secret Service (gnome-keyring, KWallet's bridge, KeePassXC…) on
/// the session bus, running or activatable?
///
/// Asked BEFORE any `flutter_secure_storage` call on Linux, because without
/// one the plugin no longer fails politely. Under Flutter 3.47 the libsecret
/// error came back as a PlatformException that `UserSettings` turns into the
/// 0600 token-file fallback (measured on a Steam Deck, 2026-09-26). Under
/// Flutter 3.50 the same call kills the process at launch:
///   terminate called after throwing an instance of 'LibsecretError'
/// (AppImage CI, 2026-11-17 — same plugin version 3.0.3, only Flutter moved).
/// A C++ exception that escapes is not something Dart can catch, so the only
/// safe move is not to make the call.
///
/// Never throws: no session bus, or any D-Bus error, answers false — the
/// fallback is a working account, the alternative is a crash.
Future<bool> linuxSecretServiceAvailable() async {
  DBusClient? client;
  try {
    client = DBusClient.session();
    const name = 'org.freedesktop.secrets';
    if (await client.nameHasOwner(name)) return true;
    final activatable = await client.listActivatableNames();
    return activatable.contains(name);
  } catch (e) {
    debugPrint('[secrets] no Secret Service check possible: $e');
    return false;
  } finally {
    try {
      await client?.close();
    } catch (_) {}
  }
}
