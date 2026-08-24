import 'dart:io';

import 'package:crypto/crypto.dart';

import 'local_db.dart';
import 'rewamp_db.dart' show RewampDb, SapInfo;

/// Resolves ASMA STIL metadata for a .sap file: standard file MD5 (unlike
/// SID, no special libsidplayfp MD5 needed) → local cache → get_sap_info RPC
/// → cache. No subsong dimension (unlike SID) — used purely to fill the
/// player screen's ⓘ info panel, not queue titles.
class SapInfoService {
  SapInfoService._();
  static final instance = SapInfoService._();

  final Map<String, SapInfo?> _mem = {}; // md5 → info (session cache)

  Future<String?> _md5(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      final bytes = await f.readAsBytes();
      return md5.convert(bytes).toString();
    } catch (_) {
      return null;
    }
  }

  /// Returns SAP STIL info for [path], hitting the local cache first, then
  /// the server. Returns null if the md5 fails or nothing is known.
  Future<SapInfo?> forPath(String path) async {
    final md5hex = await _md5(path);
    if (md5hex == null) return null;
    return forMd5(md5hex);
  }

  Future<SapInfo?> forMd5(String md5hex) async {
    if (_mem.containsKey(md5hex)) return _mem[md5hex];

    final cached = await LocalDb.instance.getSapInfoCache(md5hex);
    if (cached != null) {
      final info = (cached.stilTitle == null &&
              cached.stilArtist == null &&
              cached.stilComment == null)
          ? null
          : SapInfo(
              md5: md5hex,
              stilTitle: cached.stilTitle,
              stilArtist: cached.stilArtist,
              stilComment: cached.stilComment,
            );
      _mem[md5hex] = info;
      return info;
    }

    final info = await RewampDb.getSapInfo(md5hex);
    await LocalDb.instance.upsertSapInfoCache(
      md5hex,
      SapInfoCache(
        stilTitle: info?.stilTitle,
        stilArtist: info?.stilArtist,
        stilComment: info?.stilComment,
      ),
    );
    _mem[md5hex] = info;
    return info;
  }
}
