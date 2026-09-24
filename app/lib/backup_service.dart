import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'local_db.dart';
import 'user_settings.dart';

/// Export / import of the user's data as a single self-contained `.rewampbackup`
/// (a zip) so it can be carried to another device.
///
/// Contents:
///   * `rewamp_local.db` — history, library, playlists, recents. The volatile
///     metadata CACHES (uade/sid/sap songlengths) are stripped — they rebuild
///     themselves from the server on the new device, and dropping them keeps
///     the backup tiny (typically < 300 KB).
///   * `settings.json` — every SharedPreferences value (theme, engine params,
///     selected SoundFont, user id, …), type-tagged.
///   * `manifest.json` — format id + schema version, checked on import.
///
/// NOT included: downloaded audio files (re-downloadable from the server via
/// the library's stored download urls) and the artwork cache (regenerable).
class BackupService {
  BackupService._();

  static const String _magic = 'rewamp-backup';
  static const int _formatVersion = 1;
  /// Must match LocalDb's schema `version:` — a backup from a NEWER schema than
  /// this build can't be safely imported (an older one migrates forward).
  static const int _dbSchemaVersion = 21;

  static const String backupExtension = 'rewampbackup';

  static const _dbEntry = 'rewamp_local.db';
  static const _settingsEntry = 'settings.json';
  static const _manifestEntry = 'manifest.json';

  /// Tables dropped from the exported copy (see class doc).
  static const _volatileCaches = ['uade_cache', 'sid_info', 'sap_info'];

  /// Builds the backup archive in memory. Suggested filename is returned too.
  static Future<({Uint8List bytes, String filename})> buildBackup() async {
    final tmp = await getTemporaryDirectory();
    final stamp = DateTime.now();
    final snapPath =
        p.join(tmp.path, 'rewamp_backup_${stamp.millisecondsSinceEpoch}.db');
    // Fresh, defragmented snapshot of the live DB.
    await File(snapPath).delete().catchError((_) => File(snapPath));
    await LocalDb.instance.vacuumInto(snapPath);

    // Strip the volatile caches from the snapshot, then compact.
    final snap = await openDatabase(snapPath);
    try {
      for (final t in _volatileCaches) {
        try {
          await snap.execute('DELETE FROM $t');
        } catch (_) {/* table absent in this schema — fine */}
      }
      await snap.execute('VACUUM');
    } finally {
      await snap.close();
    }

    final dbBytes = await File(snapPath).readAsBytes();
    await File(snapPath).delete().catchError((_) => File(snapPath));

    final settings = jsonEncode(UserSettings.instance.dumpAll());
    final manifest = jsonEncode({
      'magic': _magic,
      'formatVersion': _formatVersion,
      'dbSchemaVersion': _dbSchemaVersion,
      'createdAt': stamp.toUtc().toIso8601String(),
      'platform': Platform.operatingSystem,
    });

    final archive = Archive()
      ..addFile(ArchiveFile(_dbEntry, dbBytes.length, dbBytes))
      ..addFile(_textFile(_settingsEntry, settings))
      ..addFile(_textFile(_manifestEntry, manifest));
    final zip = ZipEncoder().encode(archive);

    final name =
        'rewamp_${_dateStamp(stamp)}.$backupExtension';
    return (bytes: Uint8List.fromList(zip), filename: name);
  }

  /// Validates and applies a backup: replaces the local DB and all settings.
  /// DESTRUCTIVE — the caller must confirm first. Throws [BackupException] on a
  /// malformed / incompatible file.
  static Future<void> restoreBackup(Uint8List zipBytes) async {
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (_) {
      throw const BackupException(BackupError.notAnArchive);
    }

    final manifestFile = _find(archive, _manifestEntry);
    final dbFile = _find(archive, _dbEntry);
    if (manifestFile == null || dbFile == null) {
      throw const BackupException(BackupError.notARewampBackup);
    }

    Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>))
          as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException(BackupError.notARewampBackup);
    }
    if (manifest['magic'] != _magic) {
      throw const BackupException(BackupError.notARewampBackup);
    }
    final schema = (manifest['dbSchemaVersion'] as num?)?.toInt() ?? 0;
    if (schema > _dbSchemaVersion) {
      throw const BackupException(BackupError.newerVersion);
    }

    // Write the DB to a temp file, then hand it to LocalDb for the swap.
    final tmp = await getTemporaryDirectory();
    final tmpDb = p.join(
        tmp.path, 'rewamp_restore_${DateTime.now().millisecondsSinceEpoch}.db');
    await File(tmpDb).writeAsBytes(dbFile.content as List<int>, flush: true);

    await LocalDb.instance.replaceDatabaseFromFile(tmpDb);
    await File(tmpDb).delete().catchError((_) => File(tmpDb));

    // Settings are optional (a DB-only backup still restores).
    final settingsFile = _find(archive, _settingsEntry);
    if (settingsFile != null) {
      try {
        final map =
            jsonDecode(utf8.decode(settingsFile.content as List<int>))
                as Map<String, dynamic>;
        await UserSettings.instance.restoreAll(map);
      } catch (_) {/* keep the DB restore even if settings are unreadable */}
    }
  }

  static ArchiveFile _textFile(String name, String text) {
    final bytes = utf8.encode(text);
    return ArchiveFile(name, bytes.length, bytes);
  }

  static ArchiveFile? _find(Archive a, String name) {
    for (final f in a.files) {
      if (f.isFile && f.name == name) return f;
    }
    return null;
  }

  static String _dateStamp(DateTime d) =>
      '${d.year}${_pad2(d.month)}${_pad2(d.day)}_${_pad2(d.hour)}${_pad2(d.minute)}';
  static String _pad2(int n) => n.toString().padLeft(2, '0');
}

enum BackupError { notAnArchive, notARewampBackup, newerVersion }

class BackupException implements Exception {
  final BackupError error;
  const BackupException(this.error);
}
