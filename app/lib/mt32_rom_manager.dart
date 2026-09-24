import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rewamp_audio/rewamp_audio.dart';

/// The user's Roland MT-32 / CM-32L ROMs, for the mt32emu MIDI engine.
///
/// They are Roland's copyright: never bundled, never downloaded — the same
/// stance as a personal SoundFont, minus the catalogue. Imported files are
/// COPIED under `<datadir>/mt32/` (the picker's path is a sandbox copy on
/// iOS) and identified by the engine itself (`rewamp_mt32_identify_rom`,
/// SHA1 against mt32emu's ROMInfo table): a file the emulator does not know
/// is refused at the gesture, not discovered later as « MIDI is silent ».
/// Which set actually plays (model preference, MAME halves paired) is the
/// engine's decision too — `status()` just asks it.
class Mt32RomManager {
  Mt32RomManager._();
  static final Mt32RomManager instance = Mt32RomManager._();

  late String _dir; // <datadir>/mt32
  RewampAudio? _audio;

  /// [audio] nullable pour être testable hors de l'app (même raison que
  /// SoundfontManager: le natif n'est pas là dans l'hôte de test Dart).
  void init(String dataDir, RewampAudio? audio) {
    _dir = '$dataDir/mt32';
    _audio = audio;
  }

  String get dir => _dir;

  /// Points the engine at the folder. No I/O beyond that: the engine scans it
  /// at every probe/open, so an import is live at the next track.
  void applyStartup() => _audio?.setMt32RomDir(_dir);

  /// The set the engine would play with — "" when none is usable.
  String status() => _audio?.mt32RomStatus() ?? '';

  bool get hasUsableSet => status().isNotEmpty;

  /// One imported file, with what the emulator makes of it.
  List<Mt32Rom> list() {
    final d = Directory(_dir);
    if (!d.existsSync()) return const [];
    final out = <Mt32Rom>[];
    for (final e in d.listSync()) {
      if (e is! File) continue;
      final name = p.basename(e.path);
      if (name.startsWith('.')) continue;
      final desc = _audio?.mt32IdentifyRom(e.path) ?? '';
      out.add(Mt32Rom(name, desc, e.lengthSync()));
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  /// Copies every RECOGNISED file into the folder; returns the imported names
  /// and the rejected ones (unknown to mt32emu — a wrong dump, an archive, a
  /// stray file). An existing file of the same name is replaced: the SHA1
  /// gate guarantees it is the same ROM.
  Future<Mt32ImportResult> importFiles(List<String> paths) async {
    final imported = <String>[];
    final rejected = <String>[];
    for (final src in paths) {
      final f = File(src);
      if (!await f.exists()) { rejected.add(p.basename(src)); continue; }
      final desc = _audio?.mt32IdentifyRom(src) ?? '';
      if (desc.isEmpty) { rejected.add(p.basename(src)); continue; }
      await Directory(_dir).create(recursive: true);
      await f.copy(p.join(_dir, p.basename(src)));
      imported.add(p.basename(src));
    }
    return Mt32ImportResult(imported, rejected);
  }

  Future<void> delete(String name) async {
    final f = File(p.join(_dir, name));
    if (await f.exists()) await f.delete();
  }
}

class Mt32Rom {
  final String name;
  /// mt32emu's description ("MT-32 Control v1.07", "CM-32L/CM-64/LAPC-I PCM
  /// ROM (half)"); empty when the engine is absent (tests).
  final String description;
  final int sizeBytes;
  const Mt32Rom(this.name, this.description, this.sizeBytes);
}

class Mt32ImportResult {
  final List<String> imported;
  final List<String> rejected;
  const Mt32ImportResult(this.imported, this.rejected);
}
