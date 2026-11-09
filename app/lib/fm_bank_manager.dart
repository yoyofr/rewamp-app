import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'user_settings.dart';

/// The two FM instrument-bank formats, one per FM-MIDI engine.
enum FmBankKind {
  /// WOPL — libADLMIDI (OPL3).
  wopl('wopl', 'adlmidi', 'libADLMIDI'),

  /// WOPN — libOPNMIDI (OPN2 / OPNA).
  wopn('wopn', 'opnmidi', 'libOPNMIDI');

  const FmBankKind(this.ext, this.engine, this.engineName);
  final String ext;
  final String engine;
  final String engineName;
}

/// The format a bank file announces in its header, or null when it is not a
/// bank: WOPL `WOPL3-BANK\0`, WOPN `WOPN2-BANK\0` (v1) or `WOPN2-B2NK\0` (v2).
/// The CONTENT decides, never the extension — a `.wopl` that is not one would
/// otherwise reach the engine, which then falls back to its embedded bank
/// without the user knowing why their bank changed nothing. Pure, testable.
FmBankKind? fmBankKindOfHeader(List<int> head) {
  if (head.length < 11 || head[10] != 0) return null;
  final magic = String.fromCharCodes(head.sublist(0, 10));
  return switch (magic) {
    'WOPL3-BANK' => FmBankKind.wopl,
    'WOPN2-BANK' || 'WOPN2-B2NK' => FmBankKind.wopn,
    _ => null,
  };
}

/// A path that NAMES a bank file — the router's first sort, before anything
/// tries to play it; [FmBankManager.import] then checks the header.
bool isFmBankFileName(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return false;
  final ext = path.substring(dot + 1).toLowerCase();
  return ext == 'wopl' || ext == 'wopn';
}

/// A bank the user imported, as listed in the bank screen.
class FmUserBank {
  /// File name in the kind's folder — the IDENTITY persisted by the setting
  /// (a path would die with the iOS container UUID at reinstall).
  final String fileName;
  final String name;
  final int sizeBytes;
  const FmUserBank(
      {required this.fileName, required this.name, required this.sizeBytes});
}

/// User-imported FM banks (WOPL for libADLMIDI, WOPN for libOPNMIDI).
///
/// The EMBEDDED banks live in the engines and cannot be removed; the imported
/// ones are COPIED into `<datadir>/fm_banks/<ext>/` — never referenced where
/// they were picked: an iOS picker path is a sandbox copy that does not survive
/// the session, and elsewhere the user may move the file. The folder is the
/// list (no index to keep in sync). The selection is a file name in
/// UserSettings (`adlBankFile` / `opnBankFile`); AppShell hands its path to the
/// engine with the other engine settings.
class FmBankManager {
  FmBankManager._();
  static final FmBankManager instance = FmBankManager._();

  String? _root;

  /// Notifies after an import or a delete (the bank screen lists the folder).
  final ValueNotifier<int> generation = ValueNotifier(0);

  void init(String dataDir) => _root = p.join(dataDir, 'fm_banks');

  @visibleForTesting
  void initForTest(String root) => _root = root;

  String _dirFor(FmBankKind k) => p.join(_root!, k.ext);

  String pathFor(FmBankKind k, String fileName) => p.join(_dirFor(k), fileName);

  /// Path of the imported bank [fileName], null when it is not there.
  String? presentPath(FmBankKind k, String fileName) {
    if (_root == null) return null;
    final path = pathFor(k, fileName);
    return File(path).existsSync() ? path : null;
  }

  String? selectedFileName(FmBankKind k) => switch (k) {
        FmBankKind.wopl => UserSettings.instance.adlBankFile,
        FmBankKind.wopn => UserSettings.instance.opnBankFile,
      };

  /// Path of the selected imported bank, null when the embedded one plays
  /// (nothing selected, or the file is gone).
  String? selectedPath(FmBankKind k) {
    final f = selectedFileName(k);
    if (f == null || _root == null) return null;
    final path = pathFor(k, f);
    return File(path).existsSync() ? path : null;
  }

  /// Selects an imported bank ([fileName]) or the embedded ones (null).
  void select(FmBankKind k, String? fileName) {
    switch (k) {
      case FmBankKind.wopl:
        UserSettings.instance.adlBankFile = fileName;
      case FmBankKind.wopn:
        UserSettings.instance.opnBankFile = fileName;
    }
  }

  List<FmUserBank> userBanks(FmBankKind k) {
    if (_root == null) return const [];
    final dir = Directory(_dirFor(k));
    if (!dir.existsSync()) return const [];
    final out = <FmUserBank>[];
    for (final e in dir.listSync()) {
      if (e is! File) continue;
      final base = p.basename(e.path);
      if (base.startsWith('.') ||
          p.extension(base).toLowerCase() != '.${k.ext}') {
        continue;
      }
      var size = 0;
      try {
        size = e.lengthSync();
      } catch (_) {}
      out.add(FmUserBank(
          fileName: base,
          name: p.basenameWithoutExtension(base),
          sizeBytes: size));
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  /// The kind of bank [path] holds, read from its header; null = not a bank.
  static Future<FmBankKind?> sniff(String path) async {
    try {
      final raf = await File(path).open();
      try {
        return fmBankKindOfHeader(await raf.read(11));
      } finally {
        await raf.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// Imports [srcPath] (a WOPL or WOPN bank, told by its header) and returns
  /// its kind and the imported bank. Throws [FormatException] when the file is
  /// not a bank. A same-named bank already there is NOT replaced: « name (2) ».
  Future<(FmBankKind, FmUserBank)> import(String srcPath) async {
    final kind = await sniff(srcPath);
    if (kind == null) throw const FormatException('not a WOPL / WOPN bank');
    final dir = Directory(_dirFor(kind));
    await dir.create(recursive: true);
    final stem = p.basenameWithoutExtension(srcPath);
    var fileName = '$stem.${kind.ext}';
    for (var n = 2; File(pathFor(kind, fileName)).existsSync(); n++) {
      fileName = '$stem ($n).${kind.ext}';
    }
    final dst = File(pathFor(kind, fileName));
    await File(srcPath).copy(dst.path);
    generation.value++;
    return (
      kind,
      FmUserBank(
          fileName: fileName,
          name: p.basenameWithoutExtension(fileName),
          sizeBytes: await dst.length()),
    );
  }

  /// Deletes an imported bank; the selection falls back to the embedded bank
  /// when it was this one.
  Future<void> delete(FmBankKind k, String fileName) async {
    final f = File(pathFor(k, fileName));
    if (await f.exists()) await f.delete();
    if (selectedFileName(k) == fileName) select(k, null);
    generation.value++;
  }
}

/// Filter by name, case-insensitive: every space-separated term of [query]
/// must appear in [name], in any order. Pure, testable.
bool fmBankNameMatches(String name, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final n = name.toLowerCase();
  return q.split(RegExp(r'\s+')).every(n.contains);
}
