import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// App version/build + OS/device identity, for server diagnostics (report_song).
/// Loaded once, cached — every field degrades to null on any error so a report
/// never fails for want of a device string.
class ClientInfo {
  ClientInfo._();
  static final ClientInfo instance = ClientInfo._();

  String? appVersion;   // pubspec version, e.g. "0.1.0"
  String? appBuild;     // build number, e.g. "1420"
  String? osName;       // "iOS" | "Android" | "macOS" | "Windows" | "Linux"
  String? osVersion;    // "17.4" | "14" | …
  String? device;       // "iPhone15,2" | "Pixel 8" | …

  bool _loaded = false;

  /// Populates the fields once. Safe to call repeatedly (no-op after the first
  /// success). Call early (app start) so a later report has the data ready.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final pkg = await PackageInfo.fromPlatform();
      appVersion = pkg.version;
      appBuild   = pkg.buildNumber;
    } catch (e) {
      debugPrint('[ClientInfo] package_info failed: $e');
    }
    try {
      final di = DeviceInfoPlugin();
      if (kIsWeb) {
        osName = 'Web';
      } else if (Platform.isIOS) {
        osName = 'iOS';
        final i = await di.iosInfo;
        osVersion = i.systemVersion;      // "17.4"
        device    = i.utsname.machine;    // "iPhone15,2"
      } else if (Platform.isAndroid) {
        osName = 'Android';
        final a = await di.androidInfo;
        osVersion = a.version.release;    // "14"
        device    = '${a.manufacturer} ${a.model}';
      } else if (Platform.isMacOS) {
        osName = 'macOS';
        final m = await di.macOsInfo;
        osVersion = '${m.majorVersion}.${m.minorVersion}.${m.patchVersion}';
        device    = m.model;
      } else if (Platform.isWindows) {
        osName = 'Windows';
        final w = await di.windowsInfo;
        osVersion = w.displayVersion;
        device    = w.productName;
      } else if (Platform.isLinux) {
        osName = 'Linux';
        final l = await di.linuxInfo;
        osVersion = l.versionId ?? l.version;
        device    = l.prettyName;
      }
    } catch (e) {
      debugPrint('[ClientInfo] device_info failed: $e');
      // Last-resort OS strings so a report still carries platform context.
      osName ??= kIsWeb ? 'Web' : Platform.operatingSystem;
      osVersion ??= kIsWeb ? null : Platform.operatingSystemVersion;
    }
    _loaded = true;
  }
}
