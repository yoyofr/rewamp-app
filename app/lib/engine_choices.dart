import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:rewamp_audio/rewamp_audio.dart';

import 'fm_bank_manager.dart';
import 'local_db.dart';
import 'soundfont_manager.dart';
import 'user_settings.dart';

/// Where a « Lire avec… » choice applies.
enum EngineChoiceScope {
  /// This playback only (« Se souvenir » unchecked): gone at the next track.
  once,
  /// Remembered for this file.
  file,
  /// Remembered for its album — the folder it lives in (a catalogue album
  /// has its own, named by its uuid; a local album is its folder).
  album,
}

/// What a bank choice names: an EMBEDDED bank by its index, or an IMPORTED
/// one by its file name (the identity [FmBankManager] persists).
sealed class FmBankRef {
  const FmBankRef();

  /// The stored form: `#<index>` or `u:<file name>`; null when unreadable.
  static FmBankRef? parse(String v) {
    if (v.startsWith('#')) {
      final i = int.tryParse(v.substring(1));
      return i == null || i < 0 ? null : FmBankBuiltin(i);
    }
    if (v.startsWith('u:') && v.length > 2) return FmBankImported(v.substring(2));
    return null;
  }

  String get stored;
}

class FmBankBuiltin extends FmBankRef {
  const FmBankBuiltin(this.index);
  final int index;
  @override
  String get stored => '#$index';
  @override
  bool operator ==(Object other) => other is FmBankBuiltin && other.index == index;
  @override
  int get hashCode => index.hashCode;
}

class FmBankImported extends FmBankRef {
  const FmBankImported(this.fileName);
  final String fileName;
  @override
  String get stored => 'u:$fileName';
  @override
  bool operator ==(Object other) =>
      other is FmBankImported && other.fileName == fileName;
  @override
  int get hashCode => fileName.hashCode;
}

/// « Lire avec… »: which engine plays a given file when several can — and,
/// for the FM-MIDI engines, which instrument BANK.
///
/// Resolution, first match wins: the one-shot choice for this very path, the
/// choice remembered for the FILE, the one remembered for its FOLDER, else the
/// registry's own ranking (and the « Décodeurs par défaut » pins) / the
/// engine's bank setting. Keys are stored paths (`LocalDb.normPath`:
/// `{sandbox}/…` on iOS), so a reinstall does not orphan them. Applied to the
/// native side before every load AND every gapless arm — which is what lets a
/// playlist mix engines (and banks) for files of the same format.
///
/// One store, NAMESPACED: the engine choice under `f:` / `d:` (as first
/// shipped), a bank choice under `b.<engine>/f:` / `b.<engine>/d:`. Each
/// namespace follows the same rules on its own — choosing a bank for an album
/// leaves the engine choices of its files alone.
class EngineChoices {
  EngineChoices._();
  static final EngineChoices instance = EngineChoices._();

  static const _engineNs = '';
  static String _bankNs(String engine) => 'b.$engine/';

  /// The FM-MIDI engines a bank can be chosen for.
  static const bankEngines = ['adlmidi', 'opnmidi'];

  /// One-shot choices, per namespace: (path, value).
  final Map<String, (String, String)> _once = {};

  static String fileKey(String path) => 'f:${LocalDb.normPath(path)}';
  static String dirKey(String path) => 'd:${LocalDb.normPath(p.dirname(path))}';

  Map<String, String> _stored() {
    final raw = UserSettings.instance.engineChoicesJson;
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw);
      if (m is Map) {
        return {
          for (final e in m.entries)
            if (e.key is String && e.value is String) e.key as String: e.value as String,
        };
      }
    } catch (_) {}
    return {};
  }

  void _save(Map<String, String> m) =>
      UserSettings.instance.engineChoicesJson = m.isEmpty ? null : jsonEncode(m);

  /// The explicit « Automatique »: stored for a FILE whose album has a choice
  /// (and as a one-shot), so that it wins over that choice. Never returned.
  static const kAuto = '';

  /// What decides for [path] in [ns] — the value ([kAuto] = the default,
  /// said explicitly) and its scope — or null when nothing does.
  (String, EngineChoiceScope)? _decision(String ns, String path) {
    final once = _once[ns];
    if (once != null && once.$1 == path) return (once.$2, EngineChoiceScope.once);
    final m = _stored();
    final f = m['$ns${fileKey(path)}'];
    if (f != null) return (f, EngineChoiceScope.file);
    final d = m['$ns${dirKey(path)}'];
    if (d != null) return (d, EngineChoiceScope.album);
    return null;
  }

  (String, EngineChoiceScope)? _choiceIn(String ns, String path) {
    final d = _decision(ns, path);
    return d == null || d.$1 == kAuto ? null : d;
  }

  /// [value] null = « Automatique ». See [choose].
  void _choose(String ns, String path, String? value, EngineChoiceScope scope) {
    if (scope == EngineChoiceScope.once) {
      _once[ns] = (path, value ?? kAuto);
      return;
    }
    // A remembered choice replaces this path's one-shot.
    if (_once[ns]?.$1 == path) _once.remove(ns);
    final m = _stored();
    final dk = '$ns${dirKey(path)}';
    if (scope == EngineChoiceScope.file) {
      final key = '$ns${fileKey(path)}';
      if (value != null) {
        m[key] = value;
      } else if (m.containsKey(dk)) {
        m[key] = kAuto;
      } else {
        m.remove(key);
      }
    } else {
      final dir = LocalDb.normPath(p.dirname(path));
      final fp = '${ns}f:';
      m.removeWhere((k, _) =>
          k.startsWith(fp) && p.dirname(k.substring(fp.length)) == dir);
      if (value == null) {
        m.remove(dk);
      } else {
        m[dk] = value;
      }
    }
    _save(m);
  }

  /// The plugin chosen for [path] and the scope it comes from; null when the
  /// registry decides (nothing chosen, or « Automatique » chosen).
  (String, EngineChoiceScope)? choiceFor(String path) => _choiceIn(_engineNs, path);

  /// Where [path]'s current decision comes from, « Automatique » included —
  /// what the sheet shows as already selected.
  EngineChoiceScope? scopeOf(String path) => _decision(_engineNs, path)?.$2;

  /// Records a choice; [plugin] null = « Automatique ».
  ///  - once: this playback only — « Automatique » too OVERRIDES what is
  ///    remembered, for this playback.
  ///  - file: « Automatique » removes the file's entry, or stores an explicit
  ///    automatic one when its album has a choice (which would still apply).
  ///  - album: replaces the album's choice AND forgets every file choice of
  ///    the folder — choosing for the album is choosing for all of it.
  void choose(String path, String? plugin, EngineChoiceScope scope) =>
      _choose(_engineNs, path, plugin, scope);

  /// The bank chosen for [path] when [engine] plays it, and its scope; null =
  /// the engine's bank setting. An unreadable stored value counts as none.
  (FmBankRef, EngineChoiceScope)? bankChoiceFor(String engine, String path) {
    final c = _choiceIn(_bankNs(engine), path);
    if (c == null) return null;
    final ref = FmBankRef.parse(c.$1);
    return ref == null ? null : (ref, c.$2);
  }

  EngineChoiceScope? bankScopeOf(String engine, String path) =>
      _decision(_bankNs(engine), path)?.$2;

  /// Same rules as [choose]; [bank] null = the engine's setting.
  void chooseBank(String engine, String path, FmBankRef? bank, EngineChoiceScope scope) =>
      _choose(_bankNs(engine), path, bank?.stored, scope);

  /// How many FILES and ALBUMS remember the imported bank [fileName] of
  /// [engine] — what deleting it asks about.
  (int files, int albums) importedBankUsage(String engine, String fileName) {
    final ns = _bankNs(engine);
    final v = FmBankImported(fileName).stored;
    var files = 0, albums = 0;
    for (final e in _stored().entries) {
      if (e.value != v || !e.key.startsWith(ns)) continue;
      if (e.key.startsWith('${ns}f:')) files++;
      if (e.key.startsWith('${ns}d:')) albums++;
    }
    return (files, albums);
  }

  /// Forgets every choice of the imported bank [fileName] (it is being
  /// deleted): those files and albums go back to the engine's setting.
  void forgetImportedBank(String engine, String fileName) {
    final ns = _bankNs(engine);
    final v = FmBankImported(fileName).stored;
    if (_once[ns]?.$2 == v) _once.remove(ns);
    final m = _stored();
    m.removeWhere((k, val) => val == v && k.startsWith(ns));
    _save(m);
  }

  // ── Plugin options (« Lire avec… »): the SoundFont of FluidLite, the model
  // of the MT-32 — same rules, namespace `o.<plugin>/`. Values: a SoundFont
  // SLUG (the identity SoundfontManager persists), a model '1' / '2'.

  static String _optNs(String plugin) => 'o.$plugin/';

  /// The plugins with an option chosen this way.
  static const optionPlugins = ['fluidlite', 'mt32'];

  (String, EngineChoiceScope)? optionChoiceFor(String plugin, String path) =>
      _choiceIn(_optNs(plugin), path);

  EngineChoiceScope? optionScopeOf(String plugin, String path) =>
      _decision(_optNs(plugin), path)?.$2;

  /// Same rules as [choose]; [value] null = the plugin's setting.
  void chooseOption(String plugin, String path, String? value, EngineChoiceScope scope) =>
      _choose(_optNs(plugin), path, value, scope);

  /// How many FILES and ALBUMS remember [value] for [plugin].
  (int files, int albums) optionUsage(String plugin, String value) {
    final ns = _optNs(plugin);
    var files = 0, albums = 0;
    for (final e in _stored().entries) {
      if (e.value != value || !e.key.startsWith(ns)) continue;
      if (e.key.startsWith('${ns}f:')) files++;
      if (e.key.startsWith('${ns}d:')) albums++;
    }
    return (files, albums);
  }

  /// Forgets every choice of [value] for [plugin] (a SoundFont being deleted).
  void forgetOption(String plugin, String value) {
    final ns = _optNs(plugin);
    if (_once[ns]?.$2 == value) _once.remove(ns);
    final m = _stored();
    m.removeWhere((k, v) => v == value && k.startsWith(ns));
    _save(m);
  }

  /// How many choices are remembered (Réglages → Données), banks included.
  int get rememberedCount => _stored().length;

  /// Forgets every remembered choice, and the one-shots.
  void forgetAll() {
    _once.clear();
    _save(const {});
  }

  /// Before a plain LOAD of [path]: the native tables are rebuilt from
  /// scratch (an entry left for another path would apply the next time it
  /// plays), and a one-shot choice made for another file expires.
  void applyForLoad(RewampAudio audio, String path) {
    _once.removeWhere((_, o) => o.$1 != path);
    audio.clearPathPlugins();
    audio.clearPathBanks();
    audio.clearPathOptions();
    applyForArm(audio, path);
  }

  /// Before a gapless ARM of [path]: adds its entries, leaves the current ones.
  void applyForArm(RewampAudio audio, String path) {
    audio.setPathPlugin(path, choiceFor(path)?.$1);
    for (final engine in bankEngines) {
      switch (bankChoiceFor(engine, path)?.$1) {
        case FmBankBuiltin(:final index):
          audio.setPathBank(engine, path, index: index);
        case FmBankImported(:final fileName):
          // Gone (deleted elsewhere): the engine's setting plays it.
          final kind = FmBankKind.values.firstWhere((k) => k.engine == engine);
          final f = FmBankManager.instance.presentPath(kind, fileName);
          if (f != null) audio.setPathBank(engine, path, file: f);
        case null:
          break;
      }
    }
    final sf = optionChoiceFor('fluidlite', path)?.$1;
    if (sf != null && SoundfontManager.instance.isInstalled(sf)) {
      audio.setPathOption(path, 'fluidlite', SoundfontManager.instance.pathFor(sf));
    }
    final model = optionChoiceFor('mt32', path)?.$1;
    if (model != null) audio.setPathOption(path, 'mt32', model);
  }
}

/// Registry plugin name → the name a person knows the engine by. Proper
/// names: nothing to translate. Unknown names show as they are.
String enginePluginLabel(String plugin) => switch (plugin) {
      'libopenmpt' => 'libopenmpt',
      'libxmp' => 'libxmp',
      'uade' => 'UADE',
      'libsidplayfp' => 'libsidplayfp',
      'fluidlite' => 'FluidLite (SoundFont)',
      'mt32' => 'Munt (MT-32)',
      'adlmidi' => 'libADLMIDI (OPL3)',
      'opnmidi' => 'libOPNMIDI (OPN2)',
      'libgme' => 'libgme (Game Music Emu)',
      'nsfplay' => 'NSFPlay',
      'gbsplay' => 'gbsplay',
      'sndh' => 'AtariAudio',
      'atariaudio_ym' => 'AtariAudio',
      'psgplay' => 'PSG play',
      'sc68' => 'sc68',
      'libvgm' => 'libvgm',
      'vgmstream' => 'vgmstream',
      'zxtune' => 'ZXTune',
      'libpt3' => 'libpt3',
      'kss' => 'libkss',
      'nez' => 'NEZplug',
      'furnace' => 'Furnace',
      'adplug' => 'AdPlug',
      'asap' => 'ASAP',
      'hivelytracker' => 'HivelyTracker',
      'highlyexp' => 'Highly Experimental',
      'highlyquixotic' => 'Highly Quixotic',
      'highlytheoritical' => 'Highly Theoretical',
      'monkeyaudio' => "Monkey's Audio",
      _ => plugin,
    };
