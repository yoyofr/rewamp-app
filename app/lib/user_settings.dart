import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton that persists all user preferences via SharedPreferences.
/// Extends ChangeNotifier so widgets can rebuild on change.
///
/// Usage:
///   await UserSettings.init();          // once, before runApp()
///   UserSettings.instance.showVisualizer = true;
///   ListenableBuilder(listenable: UserSettings.instance, ...)
class UserSettings extends ChangeNotifier {
  static final UserSettings _instance = UserSettings._();
  static UserSettings get instance => _instance;
  UserSettings._();

  late SharedPreferences _p;

  static Future<void> init() async {
    _instance._p = await SharedPreferences.getInstance();
    await _instance._loadUserId();
  }

  /// Dump every stored preference with a type tag (backup export). JSON can't
  /// tell an int from a double or a String from a List<String>, so each value
  /// is wrapped as {'t': type, 'v': value}.
  Map<String, dynamic> dumpAll() {
    final out = <String, dynamic>{};
    for (final k in _p.getKeys()) {
      final v = _p.get(k);
      String t;
      dynamic val = v;
      if (v is bool) {
        t = 'b';
      } else if (v is int) {
        t = 'i';
      } else if (v is double) {
        t = 'd';
      } else if (v is String) {
        t = 's';
      } else if (v is List) {
        t = 'l';
        val = v.map((e) => e.toString()).toList();
      } else {
        continue;
      }
      out[k] = {'t': t, 'v': val};
    }
    // The account UUID is NOT a preference (it lives in the Keychain, never in
    // SharedPreferences), but a backup that dropped it would strand the user's
    // server library on the old install. Carried under its own key and put back
    // into secure storage by [restoreAll].
    //
    // The auth TOKEN is deliberately NOT exported. A backup is a plain zip the
    // user copies around; the token is a signed credential that grants the
    // account outright, so it would be a key left in a shared file. Since
    // migration 188 the uuid alone no longer authenticates anything either —
    // restoring an account on a new install goes through the email code, which
    // is exactly what the email exists for.
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) {
      out[_kBackupUserId] = {'t': 's', 'v': uid};
    }
    return out;
  }

  /// Replace ALL preferences with [data] (from [dumpAll]). Existing prefs are
  /// cleared first — full-restore semantics. Notifies so live listeners
  /// (engine params, theme, …) re-read.
  Future<void> restoreAll(Map<String, dynamic> data) async {
    await _p.clear();
    for (final e in data.entries) {
      final m = e.value;
      if (m is! Map) continue;
      final t = m['t'];
      final v = m['v'];
      if (e.key == _kBackupUserId || e.key == _kLegacyUserId) {
        // Account UUID: goes to secure storage, never back into the prefs.
        if (v is String && v.isNotEmpty) await setUserId(v);
        continue;
      }
      switch (t) {
        case 'b':
          await _p.setBool(e.key, v as bool);
        case 'i':
          await _p.setInt(e.key, (v as num).toInt());
        case 'd':
          await _p.setDouble(e.key, (v as num).toDouble());
        case 's':
          await _p.setString(e.key, v as String);
        case 'l':
          await _p.setStringList(
              e.key, (v as List).map((x) => x.toString()).toList());
      }
    }
    notifyListeners();
  }

  // ── Général ────────────────────────────────────────────────────────────────

  static const _kThemeMode = 'gen.theme_mode';

  ThemeMode get themeMode {
    switch (_p.getString(_kThemeMode)) {
      case 'light': return ThemeMode.light;
      case 'dark':  return ThemeMode.dark;
      default:      return ThemeMode.system;
    }
  }

  set themeMode(ThemeMode v) {
    final s = v == ThemeMode.light ? 'light' : v == ThemeMode.dark ? 'dark' : 'system';
    _p.setString(_kThemeMode, s);
    notifyListeners();
  }

  static const _kArtworkTintedPlayer = 'ui.artwork_tinted_player';

  /// Apple-Music-style player background: tinted with the artwork's dominant
  /// colour (with soft radial variations). Off → plain theme surface.
  bool get artworkTintedPlayer => _p.getBool(_kArtworkTintedPlayer) ?? true;

  set artworkTintedPlayer(bool v) {
    _p.setBool(_kArtworkTintedPlayer, v);
    notifyListeners();
  }

  static const _kNotifyTrackChange = 'ui.notify_track_change';

  /// System notification on every track change (desktop; macOS posts via
  /// UNUserNotificationCenter). Off by default — Android/iOS already carry the
  /// track in their media notification, this is for the Mac sitting in the
  /// background.
  bool get notifyTrackChange => _p.getBool(_kNotifyTrackChange) ?? false;

  set notifyTrackChange(bool v) {
    _p.setBool(_kNotifyTrackChange, v);
    notifyListeners();
  }

  // ── Visualisation ──────────────────────────────────────────────────────────

  static const _kShowVisualizer = 'vis.show_visualizer';
  static const _kVizEffect      = 'vis.viz_effect';

  /// Whether the player opens in visualizer mode (true) or artwork mode (false).
  bool get showVisualizer => _p.getBool(_kShowVisualizer) ?? false;

  set showVisualizer(bool v) {
    _p.setBool(_kShowVisualizer, v);
    notifyListeners();
  }

  /// Last active visualizer effect: 'stereo' or 'voices'.
  String get vizEffect => _p.getString(_kVizEffect) ?? 'stereo';

  set vizEffect(String v) {
    _p.setString(_kVizEffect, v);
    // No notifyListeners — VizSelectorWidget reads once at init, not reactive.
  }

  static const _kVizKeepAwake = 'vis.keep_awake';

  /// Hold the display awake while a visualizer is on screen (default ON).
  /// Watching a visualizer involves no touch input for minutes, so the system
  /// idle timer blanks it mid-show — the same reason a video player does this.
  bool get vizKeepAwake => _p.getBool(_kVizKeepAwake) ?? true;

  set vizKeepAwake(bool v) {
    _p.setBool(_kVizKeepAwake, v);
    notifyListeners();
  }

  static const _kVizArtworkOpacity = 'vis.artwork_opacity';

  /// Artwork opacity behind the GL visualizer (0.0 = off, 1.0 = fully opaque).
  double get vizArtworkOpacity => _p.getDouble(_kVizArtworkOpacity) ?? 0.30;

  set vizArtworkOpacity(double v) {
    _p.setDouble(_kVizArtworkOpacity, v.clamp(0.0, 1.0));
    notifyListeners();
  }

  // ── projectM (Settings → Visualisation → projectM; mirrors Modizer's set) ──
  static const _kPmRandom      = 'vis.pm_random';
  static const _kPmBlend       = 'vis.pm_blend';
  static const _kPmLock        = 'vis.pm_lock';
  static const _kPmBlendTime   = 'vis.pm_blend_time';
  static const _kPmDuration    = 'vis.pm_duration';
  static const _kPmQuality     = 'vis.pm_quality';
  static const _kPmMeshX       = 'vis.pm_mesh_x';
  static const _kPmMeshY       = 'vis.pm_mesh_y';
  static const _kPmBeatSens    = 'vis.pm_beat_sens';
  static const _kPmHardcut     = 'vis.pm_hardcut';
  static const _kPmHardcutTime = 'vis.pm_hardcut_time';
  static const _kPmHardcutSens = 'vis.pm_hardcut_sens';
  static const _kPmAspect      = 'vis.pm_aspect';
  static const _kPmPermissive  = 'vis.pm_permissive';
  static const _kPmTransition  = 'vis.pm_transition';

  /// projectM: pick the next preset at random (else sequential).
  bool get pmRandomNext => _p.getBool(_kPmRandom) ?? true;
  set pmRandomNext(bool v) { _p.setBool(_kPmRandom, v); notifyListeners(); }

  /// projectM: blend (soft-cut) transition between presets (else hard cut).
  bool get pmBlend => _p.getBool(_kPmBlend) ?? true;
  set pmBlend(bool v) { _p.setBool(_kPmBlend, v); notifyListeners(); }

  /// projectM: lock the current preset (no auto-switch).
  bool get pmLockPreset => _p.getBool(_kPmLock) ?? false;
  set pmLockPreset(bool v) { _p.setBool(_kPmLock, v); notifyListeners(); }

  /// projectM: the 23 built-in transition patterns, in the order
  /// TransitionShaderManager builds them — the index IS the C-side index, so a
  /// pattern added there must be appended HERE, never inserted.
  ///
  /// Proper names, like the notation palettes and the Milkdrop preset names:
  /// they stay in their original form in every language (not translated). Only
  /// the "random" entry is a real label, and it is drawn from l10n.
  static const pmTransitionNames = [
    'Circle', 'Plasma', 'Simple blend', 'Sweep', 'Warp', 'Zoom blur',
    'Clock', 'Corner', 'Checker', 'Spiral', 'Rhombus', 'Nuclear clock',
    'Cross', 'Lines', 'Donuts', 'Bubbles', 'Kaleidoscope', 'Moebius',
    'Stars', 'Disco floor', 'Fire', 'Drain swirl', 'Julia',
  ];

  /// projectM: pinned transition pattern, -1 = pick at random (the default).
  /// Only observable while blending is on: a hard cut has no transition.
  int get pmTransition {
    final v = _p.getInt(_kPmTransition) ?? -1;
    return (v < 0 || v >= pmTransitionNames.length) ? -1 : v;
  }
  set pmTransition(int v) {
    _p.setInt(_kPmTransition,
        (v < 0 || v >= pmTransitionNames.length) ? -1 : v);
    notifyListeners();
  }

  /// projectM: blend duration in seconds (Modizer default 2.7).
  double get pmBlendTime => _p.getDouble(_kPmBlendTime) ?? 2.7;
  set pmBlendTime(double v) { _p.setDouble(_kPmBlendTime, v.clamp(0.5, 10.0)); notifyListeners(); }

  /// projectM: seconds between automatic preset switches (Modizer default 15).
  double get pmPresetDuration => _p.getDouble(_kPmDuration) ?? 15.0;
  set pmPresetDuration(double v) { _p.setDouble(_kPmDuration, v.clamp(3.0, 60.0)); notifyListeners(); }

  static const pmQualityNames = ['Max', '1/2', '1/4', '1/8'];
  /// projectM: render-resolution divider as a power of two (0=Max … 3=1/8).
  int get pmQuality => (_p.getInt(_kPmQuality) ?? 0).clamp(0, 3);
  set pmQuality(int v) { _p.setInt(_kPmQuality, v.clamp(0, 3)); notifyListeners(); }

  /// projectM: mesh size X (Modizer default 32).
  int get pmMeshX => (_p.getInt(_kPmMeshX) ?? 32).clamp(8, 128);
  set pmMeshX(int v) { _p.setInt(_kPmMeshX, v.clamp(8, 128)); notifyListeners(); }

  /// projectM: mesh size Y (Modizer default 24).
  int get pmMeshY => (_p.getInt(_kPmMeshY) ?? 24).clamp(6, 96);
  set pmMeshY(int v) { _p.setInt(_kPmMeshY, v.clamp(6, 96)); notifyListeners(); }

  /// projectM: beat sensitivity (default 1).
  double get pmBeatSensitivity => _p.getDouble(_kPmBeatSens) ?? 1.0;
  set pmBeatSensitivity(double v) { _p.setDouble(_kPmBeatSens, v.clamp(0.0, 5.0)); notifyListeners(); }

  /// projectM: hardcut — beat-synchronised preset switching.
  bool get pmHardcut => _p.getBool(_kPmHardcut) ?? false;
  set pmHardcut(bool v) { _p.setBool(_kPmHardcut, v); notifyListeners(); }

  /// projectM: hardcut minimum time in seconds (default 20).
  double get pmHardcutTime => _p.getDouble(_kPmHardcutTime) ?? 20.0;
  set pmHardcutTime(double v) { _p.setDouble(_kPmHardcutTime, v.clamp(0.0, 60.0)); notifyListeners(); }

  /// projectM: hardcut sensitivity (default 1).
  double get pmHardcutSensitivity => _p.getDouble(_kPmHardcutSens) ?? 1.0;
  set pmHardcutSensitivity(double v) { _p.setDouble(_kPmHardcutSens, v.clamp(0.0, 5.0)); notifyListeners(); }

  /// projectM: preserve aspect ratio for compatible shaders.
  bool get pmAspectRatio => _p.getBool(_kPmAspect) ?? true;
  set pmAspectRatio(bool v) { _p.setBool(_kPmAspect, v); notifyListeners(); }

  /// projectM: allow loading .milk files with script issues.
  bool get pmPermissive => _p.getBool(_kPmPermissive) ?? true;
  set pmPermissive(bool v) { _p.setBool(_kPmPermissive, v); notifyListeners(); }

  static const _kGlassEffect = 'ui.glass_effect';

  /// Liquid-glass chrome (lens + blur on the mini player / nav bar). OFF =
  /// a plain translucent slab — for devices where the shader is too slow.
  bool get glassEffect => _p.getBool(_kGlassEffect) ?? true;

  set glassEffect(bool v) {
    _p.setBool(_kGlassEffect, v);
    notifyListeners();
  }

  static const _kVizVoiceGrid = 'vis.voice_grid';

  /// Whether the per-voice oscilloscope draws its separating grid lines.
  static const _kVizVoiceNames = 'vis.voice_names';

  /// Overlay each voice cell of the per-voice oscilloscope with its name.
  bool get vizVoiceNames => _p.getBool(_kVizVoiceNames) ?? true;

  set vizVoiceNames(bool v) {
    _p.setBool(_kVizVoiceNames, v);
    notifyListeners();
  }

  bool get vizVoiceGrid => _p.getBool(_kVizVoiceGrid) ?? true;

  set vizVoiceGrid(bool v) {
    _p.setBool(_kVizVoiceGrid, v);
    notifyListeners();
  }

  static const _kVizLineThickness = 'vis.line_thickness';

  /// Oscilloscope line thickness multiplier (0.5–3). Default 2.0: at 1.0 the
  /// trace is a hairline on a dense panel, and every tester turned it up.
  double get vizLineThickness => _p.getDouble(_kVizLineThickness) ?? 2.0;

  set vizLineThickness(double v) {
    _p.setDouble(_kVizLineThickness, v.clamp(0.5, 3.0));
    notifyListeners();
  }

  // CRT oscilloscope effects — levels 0=off, 1=low, 2=high.
  static const _kCrtGlow  = 'vis.crt_glow_level';
  static const _kCrtSpeed = 'vis.crt_speed_level';

  int get crtGlowLevel => (_p.getInt(_kCrtGlow) ?? 0).clamp(0, 2);
  set crtGlowLevel(int v) { _p.setInt(_kCrtGlow, v.clamp(0, 2)); notifyListeners(); }
  int get crtSpeedLevel => (_p.getInt(_kCrtSpeed) ?? 0).clamp(0, 2);
  set crtSpeedLevel(int v) { _p.setInt(_kCrtSpeed, v.clamp(0, 2)); notifyListeners(); }

  /// Packed for rewamp_set_crt_flags: bits0-1 = glow level, bits2-3 = speed level.
  int get crtFlags => crtGlowLevel | (crtSpeedLevel << 2);

  // Notation-visualizer color palette (index into the C palette table).
  static const _kNotePalette = 'vis.note_palette';
  // Palette names are proper names, like Milkdrop preset names: they stay in
  // their original form in every language (they are not translated).
  static const notePaletteNames = ['Cyberpunk', 'Retro', 'Pastel', 'Synthwave', 'Classic', 'Vibrant', 'Spring', 'Arcade', 'Candy'];

  /// The 16 base per-voice colours of each palette — a MIRROR of g_palettes in
  /// rewamp_notes_render.cpp (the C side owns the rendering; this copy only
  /// feeds the settings preview). Keep the two in sync when a palette changes.
  /// Voices 16-31 render lighter variants and 32-47 darker ones (C side).
  static const notePaletteColors = <List<int>>[
    // Cyberpunk — neon signage on a night street
    [0x00F0FF, 0xFF2BD6, 0x39FF14, 0xB026FF, 0xFFE000, 0xFF3860, 0x1B6CFF, 0xFF8C00,
     0x7DF9FF, 0xC724B1, 0x00FF9F, 0x8A2BE2, 0xFFF700, 0xFF6EC7, 0x00BFFF, 0xADFF2F],
    // Rétro — warm 8-bit console earth tones
    [0xE84855, 0xF9A03F, 0x6BBF59, 0x3A7CA5, 0xF9C846, 0xC44536, 0x2A9D8F, 0xD9BF77,
     0xE76F51, 0x4E9F3D, 0x6D9DC5, 0xE9C46A, 0xA15C3E, 0x8FBC8F, 0xB5838D, 0xF4A261],
    // Pastel — soft sorbet
    [0x8CE99A, 0xFF8787, 0x74C0FC, 0xFFD43B, 0xB197FC, 0xF783AC, 0x63E6BE, 0xFFA94D,
     0x99E9F2, 0xA9E34B, 0xFFC9C9, 0xD0BFFF, 0xFFE066, 0x96F2D7, 0xFCC2D7, 0xBAC8FF],
    // Synthwave — sunset-grid
    [0xFF6AD5, 0x08F7FE, 0xF5D300, 0xC774E8, 0xFF2E97, 0x94D0FF, 0xFF901F, 0xAD8CFF,
     0xFE53BB, 0x00B8FF, 0xFFD319, 0x8795E8, 0xFF3864, 0x6A00F4, 0x2DE2E6, 0xF222FF],
    // Classique — single-phosphor green scope
    [0x00FF44, 0x66FFAA, 0x00CC55, 0x88FFBB, 0x22DD66, 0x00FF99, 0x44FF88, 0x11EE55,
     0x77FFCC, 0x00DD44, 0x55FFAA, 0x33FF77, 0x00B840, 0x99FFC0, 0x00E87A, 0x2AFF9E],
    // Vibrant — high-contrast categorical
    [0xE60049, 0x0BB4FF, 0x50E991, 0xE6D800, 0x9B19F5, 0xFFA300, 0xDC0AB4, 0x00BFA0,
     0xFF6E54, 0x7C5CFF, 0xB3D4FF, 0x00C2A8, 0xF46A9B, 0x8BD346, 0xFF8C42, 0x5AD2F4],
    // Spring — fresh meadow
    [0xEA5545, 0xF46A9B, 0xEF9B20, 0xEDBF33, 0xBDCF32, 0x87BC45, 0x27AEEF, 0xB33DC6,
     0xEDE15B, 0xFF8C42, 0x5AD2F4, 0x9D4EDD, 0x64C466, 0xF97B72, 0x4CC9F0, 0xDA7FD9],
    // Arcade — cabinet/Pico-8 primaries
    [0xFF004D, 0x29ADFF, 0xFFEC27, 0x00E436, 0xFF77A8, 0x00FFCC, 0xFFA300, 0x7E2FF2,
     0xFF3C00, 0x00B8F5, 0xB5FF39, 0xFF5DB1, 0x00D66C, 0xFFC825, 0x4D7CFF, 0xF25EFF],
    // Candy — sweet shop
    [0xFF87B7, 0x8FE3CF, 0xFFD97A, 0xC79BFF, 0xFFA37A, 0x7AD1FF, 0xFF6F91, 0xA5E887,
     0xFFB3DE, 0x6FDCB8, 0xFFCE85, 0xB19CFF, 0xFF8A80, 0x8CD9FF, 0xE887C7, 0xFFE9A8],
  ];
  int get notePalette => (_p.getInt(_kNotePalette) ?? 0).clamp(0, notePaletteNames.length - 1);
  set notePalette(int v) {
    _p.setInt(_kNotePalette, v.clamp(0, notePaletteNames.length - 1));
    notifyListeners();
  }

  // Notation block style: false = flat, true = box (beveled relief).
  // Le relief est le DÉFAUT: personne n'écrit cette clé au démarrage, donc
  // seuls les appareils qui n'ont jamais touché au réglage suivent, et
  // `resetSetting` retire la préférence — la remise à zéro retombe donc sur
  // la même valeur.
  static const _kNoteBoxStyle = 'vis.note_box_style';
  bool get noteBoxStyle => _p.getBool(_kNoteBoxStyle) ?? true;
  set noteBoxStyle(bool v) { _p.setBool(_kNoteBoxStyle, v); notifyListeners(); }

  // ── Pattern visualizer ────────────────────────────────────────────────────
  // Scroll mode: 0 = fixed bar (current row centered, timeline scrolls under
  // it), 1 = moving bar (page anchored to the current pattern, the bar moves
  // down and the page flips on order change).
  static const _kPatternScroll = 'vis.pattern_scroll';
  int get patternScrollMode => (_p.getInt(_kPatternScroll) ?? 0).clamp(0, 1);
  set patternScrollMode(int v) {
    _p.setInt(_kPatternScroll, v.clamp(0, 1));
    notifyListeners();
  }

  // Per-channel volume bars at the bottom of each column.
  static const _kPatternVolume = 'vis.pattern_volume';
  bool get patternShowVolume => _p.getBool(_kPatternVolume) ?? false;
  set patternShowVolume(bool v) {
    _p.setBool(_kPatternVolume, v);
    notifyListeners();
  }

  // Smooth (sub-row interpolated) pattern scrolling. Default ON.
  static const _kPatternSmooth = 'vis.pattern_smooth';
  bool get patternSmoothScroll => _p.getBool(_kPatternSmooth) ?? true;
  set patternSmoothScroll(bool v) {
    _p.setBool(_kPatternSmooth, v);
    notifyListeners();
  }

  // Glyph zoom: index into patternSizeValues (x1 / x1.5 / x2).
  static const _kPatternSize = 'vis.pattern_size';
  static const List<double> patternSizeValues = [1.0, 1.5, 2.0];
  int get patternSizeIndex =>
      (_p.getInt(_kPatternSize) ?? 0).clamp(0, patternSizeValues.length - 1);
  double get patternSize => patternSizeValues[patternSizeIndex];
  set patternSizeIndex(int v) {
    _p.setInt(_kPatternSize, v.clamp(0, patternSizeValues.length - 1));
    notifyListeners();
  }

  // Column visibility: 0 = all, 1 = note + instrument, 2 = note only.
  static const _kPatternColumns = 'vis.pattern_columns';
  int get patternColumns => (_p.getInt(_kPatternColumns) ?? 0).clamp(0, 2);
  set patternColumns(int v) {
    _p.setInt(_kPatternColumns, v.clamp(0, 2));
    notifyListeners();
  }

  // Color scheme evoking classic trackers (see PatternPalette.presets).
  static const _kPatternOpaqueBg = 'vis.pattern_opaque_bg';

  /// Force an opaque background on the pattern grid (no artwork behind it).
  /// The grid is dense text; a busy cover under it hurts legibility.
  bool get patternOpaqueBg => _p.getBool(_kPatternOpaqueBg) ?? false;
  set patternOpaqueBg(bool v) {
    _p.setBool(_kPatternOpaqueBg, v);
    notifyListeners();
  }

  static const _kPatternPalette = 'vis.pattern_palette';
  static const int patternPaletteCount = 6;
  int get patternPalette =>
      (_p.getInt(_kPatternPalette) ?? 0).clamp(0, patternPaletteCount - 1);
  set patternPalette(int v) {
    _p.setInt(_kPatternPalette, v.clamp(0, patternPaletteCount - 1));
    notifyListeners();
  }

  // Oscilloscope colors (stored as 0xRRGGBB) + stereo color mode.
  static const _kScopeColor   = 'vis.scope_color';        // voice + (legacy) mono
  static const _kStereoMono   = 'vis.stereo_mono_color';
  static const _kStereoLeft   = 'vis.stereo_left_color';
  static const _kStereoRight  = 'vis.stereo_right_color';
  static const _kStereoBicolor = 'vis.stereo_bicolor';
  static const _kSpectrumPalette = 'vis.spectrum_palette';

  int  get scopeColor => _p.getInt(_kScopeColor) ?? 0x00FF44;        // green
  set scopeColor(int v) { _p.setInt(_kScopeColor, v); notifyListeners(); }
  int  get stereoMonoColor => _p.getInt(_kStereoMono) ?? 0x00FF44;   // green
  set stereoMonoColor(int v) { _p.setInt(_kStereoMono, v); notifyListeners(); }
  int  get stereoLeftColor => _p.getInt(_kStereoLeft) ?? 0xF3F1F9; // light, slightly blueish
  set stereoLeftColor(int v) { _p.setInt(_kStereoLeft, v); notifyListeners(); }
  int  get stereoRightColor => _p.getInt(_kStereoRight) ?? 0xDD498D;   // pink
  set stereoRightColor(int v) { _p.setInt(_kStereoRight, v); notifyListeners(); }
  bool get stereoBicolor => _p.getBool(_kStereoBicolor) ?? true;
  set stereoBicolor(bool v) { _p.setBool(_kStereoBicolor, v); notifyListeners(); }

  /// Spectrum bars (viz mode 5): 0 = the scope's own colors, 1 = colored by
  /// frequency with brightness following amplitude (the Modizer palette).
  int get spectrumPalette => _p.getInt(_kSpectrumPalette) ?? 0;
  set spectrumPalette(int v) { _p.setInt(_kSpectrumPalette, v); notifyListeners(); }

  // ── Lecture — libopenmpt ───────────────────────────────────────────────────
  //
  // Values map to OpenMPT's OPENMPT_MODULE_RENDER_INTERPOLATIONFILTER_LENGTH:
  //   1 = no interpolation (nearest), 2 = linear, 4 = cubic,
  //   8 = windowed sinc (default). 0 means "engine default", NOT "none".
  // The picker used to ship the wrong map (0 = none, 1 = linear): picking
  // "linear" actually selected NEAREST, whose per-tick stepping turns into a
  // piercing 16 kHz whine on sample-precise-tempo tracks ("Haesslich",
  // measured at -1.7 dB vs the bass where sinc sits at -31 dB). Stored values
  // from that UI are migrated once below (0 -> 1, 1 -> 2).

  static const _kOmptInterpolation = 'openmpt.interpolation';
  static const _kOmptStereoSep     = 'openmpt.stereo_sep';
  static const _kOmptLoopCount     = 'openmpt.loop_count';

  // libopenmpt engine params (Settings → Moteurs → libopenmpt).
  static const _kOmptMasterVol   = 'ompt_master_volume';
  static const _kOmptAmigaFilter = 'ompt_amiga_filter';
  double get omptMasterVolume => _p.getDouble(_kOmptMasterVol) ?? 1.0;
  set omptMasterVolume(double v) { _p.setDouble(_kOmptMasterVol, v); notifyListeners(); }
  /// 0 = off, 1 = A500, 2 = A1200.
  int get omptAmigaFilter => (_p.getInt(_kOmptAmigaFilter) ?? 0).clamp(0, 2);
  set omptAmigaFilter(int v) { _p.setInt(_kOmptAmigaFilter, v); notifyListeners(); }

  // GME engine params (Settings → Moteurs → GME).
  static const _kGmeSilence     = 'gme_silence_detection';
  static const _kGmeStereoDepth = 'gme_stereo_depth';
  static const _kGmeEqEnabled   = 'gme_eq_enabled';
  static const _kGmeEqBass      = 'gme_eq_bass';
  static const _kGmeEqTreble    = 'gme_eq_treble';
  bool get gmeSilenceDetection => _p.getBool(_kGmeSilence) ?? false;
  set gmeSilenceDetection(bool v) { _p.setBool(_kGmeSilence, v); notifyListeners(); }
  double get gmeStereoDepth => (_p.getDouble(_kGmeStereoDepth) ?? 0.7).clamp(0.0, 1.0);
  set gmeStereoDepth(double v) { _p.setDouble(_kGmeStereoDepth, v); notifyListeners(); }
  bool get gmeEqEnabled => _p.getBool(_kGmeEqEnabled) ?? false;
  set gmeEqEnabled(bool v) { _p.setBool(_kGmeEqEnabled, v); notifyListeners(); }
  double get gmeEqBass => (_p.getDouble(_kGmeEqBass) ?? 2.3).clamp(0.0, 4.2);
  set gmeEqBass(double v) { _p.setDouble(_kGmeEqBass, v); notifyListeners(); }
  double get gmeEqTreble => (_p.getDouble(_kGmeEqTreble) ?? -14.0).clamp(-50.0, 5.0);
  set gmeEqTreble(double v) { _p.setDouble(_kGmeEqTreble, v); notifyListeners(); }

  // Game Boy / GBS (gbsplay): high-pass filter 0=Off 1=DMG 2=CGB.
  static const _kGbsHpFilter = 'gbsplay_hp_filter';
  int get gbsHpFilter => (_p.getInt(_kGbsHpFilter) ?? 1).clamp(0, 2);
  set gbsHpFilter(int v) { _p.setInt(_kGbsHpFilter, v); notifyListeners(); }

  // GSF (GBA): VBA sound flags.
  static const _kGsfInterpolation = 'gsf_interpolation';
  static const _kGsfLowpass      = 'gsf_lowpass';
  static const _kGsfEcho         = 'gsf_echo';
  bool get gsfInterpolation => _p.getBool(_kGsfInterpolation) ?? true;
  set gsfInterpolation(bool v) { _p.setBool(_kGsfInterpolation, v); notifyListeners(); }
  bool get gsfLowpass => _p.getBool(_kGsfLowpass) ?? true;
  set gsfLowpass(bool v) { _p.setBool(_kGsfLowpass, v); notifyListeners(); }
  bool get gsfEcho => _p.getBool(_kGsfEcho) ?? false;
  set gsfEcho(bool v) { _p.setBool(_kGsfEcho, v); notifyListeners(); }

  // UADE (Amiga): audio effects.
  static const _kUadePostfx     = 'uade_postfx';
  static const _kUadePanOn      = 'uade_pan_enabled';
  static const _kUadePanValue   = 'uade_pan_value';
  static const _kUadeHeadphones = 'uade_headphones';
  static const _kUadeGainOn     = 'uade_gain_enabled';
  static const _kUadeGainValue  = 'uade_gain_value';
  static const _kUadeLed        = 'uade_led';
  bool get uadePostfx => _p.getBool(_kUadePostfx) ?? true;
  set uadePostfx(bool v) { _p.setBool(_kUadePostfx, v); notifyListeners(); }
  bool get uadePanEnabled => _p.getBool(_kUadePanOn) ?? true;
  set uadePanEnabled(bool v) { _p.setBool(_kUadePanOn, v); notifyListeners(); }
  double get uadePanValue => (_p.getDouble(_kUadePanValue) ?? 0.7).clamp(0.0, 1.0);
  set uadePanValue(double v) { _p.setDouble(_kUadePanValue, v); notifyListeners(); }
  bool get uadeHeadphones => _p.getBool(_kUadeHeadphones) ?? false;
  set uadeHeadphones(bool v) { _p.setBool(_kUadeHeadphones, v); notifyListeners(); }
  bool get uadeGainEnabled => _p.getBool(_kUadeGainOn) ?? false;
  set uadeGainEnabled(bool v) { _p.setBool(_kUadeGainOn, v); notifyListeners(); }
  double get uadeGainValue => (_p.getDouble(_kUadeGainValue) ?? 0.5).clamp(0.0, 1.0);
  set uadeGainValue(double v) { _p.setDouble(_kUadeGainValue, v); notifyListeners(); }
  /// Preferred decoder for the Amiga tracker formats both libopenmpt and UADE
  /// can play (mod/med/mmd0-3/okt/digi): 'openmpt' (default) or 'uade'.
  static const _kAmigaTrackerPlugin = 'amiga_tracker_plugin';
  String get amigaTrackerPlugin => _p.getString(_kAmigaTrackerPlugin) ?? 'openmpt';
  set amigaTrackerPlugin(String v) { _p.setString(_kAmigaTrackerPlugin, v); notifyListeners(); }

  /// LED (filtre Paula): 0 = auto (le morceau contrôle), 1 = forcée ON,
  /// 2 = forcée OFF.
  int get uadeLed {
    // Legacy: stored as a bool when this was a switch — tolerate it.
    final v = _p.get(_kUadeLed);
    if (v is bool) return v ? 1 : 0;
    return ((v as int?) ?? 0).clamp(0, 2);
  }
  set uadeLed(int v) { _p.setInt(_kUadeLed, v); notifyListeners(); }
  /// Type de filtre Paula: 0 = A500 (défaut), 1 = A1200, 2 = aucun.
  static const _kUadeFilterType = 'uade_filter_type';
  int get uadeFilterType => (_p.getInt(_kUadeFilterType) ?? 0).clamp(0, 2);
  set uadeFilterType(int v) { _p.setInt(_kUadeFilterType, v); notifyListeners(); }

  /// Engine-settings preference keys, grouped per Moteurs page. The DEFAULTS
  /// live in ONE place — each getter's `?? fallback`: resetting simply removes
  /// the stored values so the getters fall back to them.
  static const Map<String, List<String>> kEngineKeysByEngine = {
    'openmpt': [_kOmptMasterVol, _kOmptAmigaFilter, _kOmptInterpolation, _kOmptStereoSep],
    'gme':     [_kGmeSilence, _kGmeStereoDepth, _kGmeEqEnabled, _kGmeEqBass, _kGmeEqTreble],
    'gbs':     [_kGbsHpFilter],
    'gsf':     [_kGsfInterpolation, _kGsfLowpass, _kGsfEcho],
    'midi':    [_kMidiGain, _kMidiPolyphony, _kMidiReverb, _kMidiChorus,
                _kMidiInterp],
    'uade':    [_kUadePostfx, _kUadePanOn, _kUadePanValue, _kUadeHeadphones,
                _kUadeGainOn, _kUadeGainValue, _kUadeLed, _kUadeFilterType],
    // Which engine wins a shared format (Settings → Moteurs → Décodeurs par
    // défaut). Its own group: these are routing choices, not knobs of the
    // engine whose page used to host them — resetting UADE must not silently
    // hand the Amiga trackers back to libopenmpt.
    'decoders': [_kAmigaTrackerPlugin, _kNsfPlugin, _kGbsPlugin, _kSndhPlugin],
    'sid':     [_kSidEngine, _kSidAutoFilter, _kSidFilter,
                _kSid2ndOn, _kSid2ndAddr, _kSid3rdOn, _kSid3rdAddr,
                _kSidSampling, _kSidClock, _kSidModel,
                _kSid6581Curve, _kSid6581Range, _kSid8580Curve],
    'nsfplay': [_kNsfQuality, _kNsfLpf, _kNsfHpf, _kNsfRegion, _kNsfIrq,
                _kNsfApu1Unmute, _kNsfApu1Phase, _kNsfApu1NonLin,
                _kNsfApu1DutySwap, _kNsfApu1NegSweep,
                _kNsfApu2Reg4011, _kNsfApu2PNoise, _kNsfApu2Unmute,
                _kNsfApu2AntiClk, _kNsfApu2NonLin, _kNsfApu2RndNoise,
                _kNsfApu2TriMute, _kNsfApu2RndTri, _kNsfApu2DpcmRev,
                _kNsfN163Serial, _kNsfN163PhaseRO, _kNsfN163LimitWl,
                _kNsfFdsCutoff, _kNsfFds4085, _kNsfFdsWriteProt,
                _kNsfMmc5NonLin, _kNsfMmc5Phase,
                _kNsfVrc7Patch, _kNsfVrc7Opll],
    'he':      [_kHeSpuMain, _kHeSpuReverb],
    'adplug':  [_kAdplugSurround],
    'vgm':     [_kVgmYm2612, _kVgmYmf262, _kVgmYm3812, _kVgmQsound, _kVgmRf5c68,
                _kVgmGb, _kVgmYm2413, _kVgmYm2151, _kVgmAy8910, _kVgmNes, _kVgmSn76496, _kVgmSaa1099, _kVgmC6280],
  };

  /// Public pref-key lookup for the per-setting reset buttons: semantic name →
  /// stored key. Covers the NON-engine pages too (Général / Visualisation /
  /// Lecture). Kept next to kEngineKeysByEngine + kSectionKeys so all stay in
  /// sync.
  static const Map<String, String> kEnginePrefKeys = {
    // Général
    'themeMode': _kThemeMode, 'artworkTintedPlayer': _kArtworkTintedPlayer,
    'notifyTrackChange': _kNotifyTrackChange, 'glassEffect': _kGlassEffect,
    // Visualisation
    'showVisualizer': _kShowVisualizer, 'vizArtworkOpacity': _kVizArtworkOpacity,
    'vizKeepAwake': _kVizKeepAwake,
    'vizVoiceGrid': _kVizVoiceGrid, 'vizVoiceNames': _kVizVoiceNames,
    'vizLineThickness': _kVizLineThickness,
    'crtGlowLevel': _kCrtGlow, 'crtSpeedLevel': _kCrtSpeed,
    'notePalette': _kNotePalette, 'noteBoxStyle': _kNoteBoxStyle,
    'patternScrollMode': _kPatternScroll, 'patternShowVolume': _kPatternVolume,
    'patternPalette': _kPatternPalette,
    'patternSizeIndex': _kPatternSize, 'patternColumns': _kPatternColumns,
    'scopeColor': _kScopeColor, 'stereoMonoColor': _kStereoMono,
    'stereoLeftColor': _kStereoLeft, 'stereoRightColor': _kStereoRight,
    'stereoBicolor': _kStereoBicolor, 'spectrumPalette': _kSpectrumPalette,
    'pmRandom': _kPmRandom, 'pmBlend': _kPmBlend, 'pmLockPreset': _kPmLock,
    'pmBlendTime': _kPmBlendTime, 'pmPresetDuration': _kPmDuration,
    'pmQuality': _kPmQuality, 'pmMeshX': _kPmMeshX, 'pmMeshY': _kPmMeshY,
    'pmBeatSensitivity': _kPmBeatSens, 'pmHardcut': _kPmHardcut,
    'pmHardcutTime': _kPmHardcutTime, 'pmHardcutSensitivity': _kPmHardcutSens,
    'pmAspectCorrection': _kPmAspect, 'pmPermissive': _kPmPermissive,
    'pmTransition': _kPmTransition,
    // Lecture
    'silenceSkip': _kSilenceSkip, 'silenceSkipSecs': _kSilenceSkipSecs,
    'defaultTrackLength': _kDefaultTrackLength,
    'forceLoopMode': _kForceLoopMode, 'loopCount': _kLoopCount,
    'forceFadeout': _kForceFadeout, 'fadeoutSecs': _kFadeoutSecs,
    // Moteurs
    'omptMasterVolume': _kOmptMasterVol, 'omptAmigaFilter': _kOmptAmigaFilter,
    'omptInterpolation': _kOmptInterpolation, 'omptStereoSep': _kOmptStereoSep,
    'gmeSilenceDetection': _kGmeSilence, 'gmeStereoDepth': _kGmeStereoDepth,
    'gmeEqEnabled': _kGmeEqEnabled, 'gmeEqBass': _kGmeEqBass,
    'gmeEqTreble': _kGmeEqTreble,
    'gbsHpFilter': _kGbsHpFilter,
    'gsfInterpolation': _kGsfInterpolation, 'gsfLowpass': _kGsfLowpass,
    'gsfEcho': _kGsfEcho,
    'midiGain': _kMidiGain, 'midiPolyphony': _kMidiPolyphony,
    'midiReverb': _kMidiReverb, 'midiChorus': _kMidiChorus,
    'midiInterp': _kMidiInterp,
    'uadePostfx': _kUadePostfx, 'uadePanEnabled': _kUadePanOn,
    'uadePanValue': _kUadePanValue, 'uadeHeadphones': _kUadeHeadphones,
    'uadeGainEnabled': _kUadeGainOn, 'uadeGainValue': _kUadeGainValue,
    'uadeLed': _kUadeLed, 'uadeFilterType': _kUadeFilterType,
    'amigaTrackerPlugin': _kAmigaTrackerPlugin,
    'nsfPlugin': _kNsfPlugin, 'gbsPlugin': _kGbsPlugin, 'sndhPlugin': _kSndhPlugin,
    'sidEngine': _kSidEngine, 'sidAutoFilter': _kSidAutoFilter,
    'sidFilter': _kSidFilter, 'sidSecondOn': _kSid2ndOn,
    'sidSecondAddr': _kSid2ndAddr, 'sidThirdOn': _kSid3rdOn,
    'sidThirdAddr': _kSid3rdAddr, 'sidSampling': _kSidSampling,
    'sidClock': _kSidClock, 'sidModel': _kSidModel,
    'sid6581Curve': _kSid6581Curve, 'sid6581Range': _kSid6581Range,
    'sid8580Curve': _kSid8580Curve,
    'nsfQuality': _kNsfQuality, 'nsfLpf': _kNsfLpf, 'nsfHpf': _kNsfHpf,
    'nsfRegion': _kNsfRegion, 'nsfIrq': _kNsfIrq,
    'nsfApu1Unmute': _kNsfApu1Unmute,
    'nsfApu1PhaseRefresh': _kNsfApu1Phase,
    'nsfApu1NonlinearMixer': _kNsfApu1NonLin,
    'nsfApu1DutySwap': _kNsfApu1DutySwap,
    'nsfApu1NegateSweep': _kNsfApu1NegSweep,
    'nsfApu2Enable4011': _kNsfApu2Reg4011,
    'nsfApu2PeriodicNoise': _kNsfApu2PNoise,
    'nsfApu2Unmute': _kNsfApu2Unmute,
    'nsfApu2DpcmAntiClick': _kNsfApu2AntiClk,
    'nsfApu2NonlinearMixer': _kNsfApu2NonLin,
    'nsfApu2RandomizeNoise': _kNsfApu2RndNoise,
    'nsfApu2TriangleMute': _kNsfApu2TriMute,
    'nsfApu2RandomizeTri': _kNsfApu2RndTri,
    'nsfApu2DpcmReverse': _kNsfApu2DpcmRev,
    'nsfN163Serial': _kNsfN163Serial,
    'nsfN163PhaseReadOnly': _kNsfN163PhaseRO,
    'nsfN163LimitWavelength': _kNsfN163LimitWl,
    'nsfFdsCutoff': _kNsfFdsCutoff, 'nsfFds4085Reset': _kNsfFds4085,
    'nsfFdsWriteProtect': _kNsfFdsWriteProt,
    'nsfMmc5NonlinearMixer': _kNsfMmc5NonLin,
    'nsfMmc5PhaseRefresh': _kNsfMmc5Phase,
    'nsfVrc7Patch': _kNsfVrc7Patch, 'nsfVrc7Opll': _kNsfVrc7Opll,
    'heSpuMain': _kHeSpuMain, 'heSpuReverb': _kHeSpuReverb,
    'adplugSurround': _kAdplugSurround,
    'vgmYm2612Core': _kVgmYm2612, 'vgmYmf262Core': _kVgmYmf262,
    'vgmYm3812Core': _kVgmYm3812, 'vgmQsoundCore': _kVgmQsound,
    'vgmRf5c68Core': _kVgmRf5c68,
    'vgmGbCore': _kVgmGb,
    'vgmYm2413Core': _kVgmYm2413,
    'vgmYm2151Core': _kVgmYm2151,
    'vgmAy8910Core': _kVgmAy8910,
    'vgmNesCore': _kVgmNes,
    'vgmSn76496Core': _kVgmSn76496,
    'vgmSaa1099Core': _kVgmSaa1099,
    'vgmC6280Core': _kVgmC6280,
  };

  /// True when [prefKey] holds a user-customised value (≠ default).
  bool isSet(String prefKey) => _p.containsKey(prefKey);

  /// Resets ONE setting to its default (removes the stored value).
  Future<void> resetSetting(String prefKey) async {
    await _p.remove(prefKey);
    notifyListeners();
  }

  /// Resets one engine's settings ([engine] = kEngineKeysByEngine key), or
  /// EVERY engine setting when null.
  Future<void> resetEngineSettings([String? engine]) async {
    final keys = engine != null
        ? (kEngineKeysByEngine[engine] ?? const <String>[])
        : [for (final l in kEngineKeysByEngine.values) ...l];
    for (final k in keys) {
      await _p.remove(k);
    }
    notifyListeners();
  }

  /// The NON-engine settings pages, so each gets the same reset affordances as
  /// Moteurs. Same rule as kEngineKeysByEngine: defaults live only in the
  /// getters' `??` fallbacks, so resetting = removing the stored value.
  /// Deliberately excluded: _kVizEffect (last-used visualizer, a state, not a
  /// setting), _kUserId, search/browse history.
  static const Map<String, List<String>> kSectionKeys = {
    'general': [_kThemeMode, _kArtworkTintedPlayer],
    'visualisation': [
      _kShowVisualizer, _kVizArtworkOpacity,
      _kVizVoiceGrid, _kVizVoiceNames, _kVizLineThickness,
      _kCrtGlow, _kCrtSpeed,
      _kNotePalette, _kNoteBoxStyle,
      _kPatternScroll, _kPatternVolume, _kPatternSmooth, _kPatternSize,
      _kPatternColumns, _kPatternPalette, _kPatternOpaqueBg,
      _kScopeColor, _kStereoMono, _kStereoLeft, _kStereoRight, _kStereoBicolor,
      _kSpectrumPalette,
      _kPmRandom, _kPmBlend, _kPmLock, _kPmBlendTime, _kPmDuration,
      _kPmQuality, _kPmMeshX, _kPmMeshY, _kPmBeatSens,
      _kPmHardcut, _kPmHardcutTime, _kPmHardcutSens, _kPmAspect, _kPmPermissive,
      _kPmTransition,
    ],
    'playback': [
      _kSilenceSkip, _kSilenceSkipSecs, _kDefaultTrackLength,
      _kForceLoopMode, _kLoopCount, _kForceFadeout, _kFadeoutSecs,
    ],
    // projectM's own 3rd-level page (a subset of 'visualisation') so its reset
    // button restores only the projectM knobs, not every visualizer setting.
    // The pattern visualizer's own 3rd-level page, same idea as 'projectm':
    // its reset restores only the grid's knobs.
    'pattern': [
      _kPatternScroll, _kPatternVolume, _kPatternSmooth, _kPatternSize,
      _kPatternColumns, _kPatternPalette, _kPatternOpaqueBg,
    ],
    'projectm': [
      _kPmRandom, _kPmBlend, _kPmLock, _kPmBlendTime, _kPmDuration,
      _kPmQuality, _kPmMeshX, _kPmMeshY, _kPmBeatSens,
      _kPmHardcut, _kPmHardcutTime, _kPmHardcutSens, _kPmAspect, _kPmPermissive,
      _kPmTransition,
    ],
  };

  /// Resets one non-engine section ([section] = kSectionKeys key).
  Future<void> resetSectionSettings(String section) async {
    for (final k in kSectionKeys[section] ?? const <String>[]) {
      await _p.remove(k);
    }
    notifyListeners();
  }

  /// Every setting, engine pages included.
  Future<void> resetAllSettings() async {
    for (final l in kSectionKeys.values) {
      for (final k in l) {
        await _p.remove(k);
      }
    }
    await resetEngineSettings();   // notifies
  }
  // SID (libsidplayfp).
  static const _kSidEngine     = 'sid_engine';
  static const _kSidAutoFilter = 'sid_auto_filter';
  static const _kSidFilter     = 'sid_filter';
  static const _kSid2ndOn      = 'sid_second_on';
  static const _kSid2ndAddr    = 'sid_second_addr';
  static const _kSid3rdOn      = 'sid_third_on';
  static const _kSid3rdAddr    = 'sid_third_addr';
  static const _kSidSampling   = 'sid_sampling';
  static const _kSidClock      = 'sid_clock';
  static const _kSidModel      = 'sid_model';
  static const _kSid6581Curve  = 'sid_f6581_curve';
  static const _kSid6581Range  = 'sid_f6581_range';
  static const _kSid8580Curve  = 'sid_f8580_curve';
  /// 0 = ReSIDfp (précis, défaut), 1 = SIDLite (rapide).
  int get sidEngine => (_p.getInt(_kSidEngine) ?? 0).clamp(0, 1);
  set sidEngine(int v) { _p.setInt(_kSidEngine, v); notifyListeners(); }
  /// Plage du filtre 6581 recommandée par auteur (tables sidplayfp).
  bool get sidAutoFilter => _p.getBool(_kSidAutoFilter) ?? true;
  set sidAutoFilter(bool v) { _p.setBool(_kSidAutoFilter, v); notifyListeners(); }
  bool get sidFilter => _p.getBool(_kSidFilter) ?? true;
  set sidFilter(bool v) { _p.setBool(_kSidFilter, v); notifyListeners(); }
  bool get sidSecondOn => _p.getBool(_kSid2ndOn) ?? false;
  set sidSecondOn(bool v) { _p.setBool(_kSid2ndOn, v); notifyListeners(); }
  /// Adresse du 2e SID (hex), défaut 0xD420.
  int get sidSecondAddr => _p.getInt(_kSid2ndAddr) ?? 0xD420;
  set sidSecondAddr(int v) { _p.setInt(_kSid2ndAddr, v); notifyListeners(); }
  bool get sidThirdOn => _p.getBool(_kSid3rdOn) ?? false;
  set sidThirdOn(bool v) { _p.setBool(_kSid3rdOn, v); notifyListeners(); }
  /// Adresse du 3e SID (hex), défaut 0xD440.
  int get sidThirdAddr => _p.getInt(_kSid3rdAddr) ?? 0xD440;
  set sidThirdAddr(int v) { _p.setInt(_kSid3rdAddr, v); notifyListeners(); }
  /// 0 = interpolation (rapide), 1 = resample (meilleure, CPU).
  int get sidSampling => (_p.getInt(_kSidSampling) ?? 0).clamp(0, 1);
  set sidSampling(int v) { _p.setInt(_kSidSampling, v); notifyListeners(); }
  /// 0 auto, 1 PAL, 2 NTSC.
  int get sidClock => (_p.getInt(_kSidClock) ?? 0).clamp(0, 2);
  set sidClock(int v) { _p.setInt(_kSidClock, v); notifyListeners(); }
  /// 0 auto, 1 6581, 2 8580.
  int get sidModel => (_p.getInt(_kSidModel) ?? 0).clamp(0, 2);
  set sidModel(int v) { _p.setInt(_kSidModel, v); notifyListeners(); }
  double get sid6581Curve => (_p.getDouble(_kSid6581Curve) ?? 0.5).clamp(0.0, 1.0);
  set sid6581Curve(double v) { _p.setDouble(_kSid6581Curve, v); notifyListeners(); }
  double get sid6581Range => (_p.getDouble(_kSid6581Range) ?? 0.5).clamp(0.0, 1.0);
  set sid6581Range(double v) { _p.setDouble(_kSid6581Range, v); notifyListeners(); }
  double get sid8580Curve => (_p.getDouble(_kSid8580Curve) ?? 0.5).clamp(0.0, 1.0);
  set sid8580Curve(double v) { _p.setDouble(_kSid8580Curve, v); notifyListeners(); }

  // NSF (nsfplay). Defaults MIRROR the C side (rewamp_plugin_nsfplay.cpp's
  // nsfplay_apply_engine_params) — the getter fallbacks below are the single
  // source of truth for "Réinitialiser", so the two must agree.
  static const _kNsfQuality = 'nsfplay_quality';
  static const _kNsfLpf     = 'nsfplay_lpf';
  static const _kNsfHpf     = 'nsfplay_hpf';
  static const _kNsfRegion  = 'nsfplay_region';
  static const _kNsfIrq     = 'nsfplay_irq';
  // Per-chip emulation options (nes_apu.h / nes_dmc.h / nes_n106.h / nes_fds.h /
  // nes_mmc5.cpp / nes_vrc7.h enums).
  static const _kNsfApu1Unmute   = 'nsfplay_apu1_0'; // OPT_UNMUTE_ON_RESET
  static const _kNsfApu1Phase    = 'nsfplay_apu1_1'; // OPT_PHASE_REFRESH
  static const _kNsfApu1NonLin   = 'nsfplay_apu1_2'; // OPT_NONLINEAR_MIXER
  static const _kNsfApu1DutySwap = 'nsfplay_apu1_3'; // OPT_DUTY_SWAP
  static const _kNsfApu1NegSweep = 'nsfplay_apu1_4'; // OPT_NEGATE_SWEEP_INIT
  static const _kNsfApu2Reg4011  = 'nsfplay_apu2_0'; // OPT_ENABLE_4011
  static const _kNsfApu2PNoise   = 'nsfplay_apu2_1'; // OPT_ENABLE_PNOISE
  static const _kNsfApu2Unmute   = 'nsfplay_apu2_2'; // OPT_UNMUTE_ON_RESET
  static const _kNsfApu2AntiClk  = 'nsfplay_apu2_3'; // OPT_DPCM_ANTI_CLICK
  static const _kNsfApu2NonLin   = 'nsfplay_apu2_4'; // OPT_NONLINEAR_MIXER
  static const _kNsfApu2RndNoise = 'nsfplay_apu2_5'; // OPT_RANDOMIZE_NOISE
  static const _kNsfApu2TriMute  = 'nsfplay_apu2_6'; // OPT_TRI_MUTE
  static const _kNsfApu2RndTri   = 'nsfplay_apu2_7'; // OPT_RANDOMIZE_TRI
  static const _kNsfApu2DpcmRev  = 'nsfplay_apu2_8'; // OPT_DPCM_REVERSE
  static const _kNsfN163Serial   = 'nsfplay_n163_0'; // OPT_SERIAL
  static const _kNsfN163PhaseRO  = 'nsfplay_n163_1'; // OPT_PHASE_READ_ONLY
  static const _kNsfN163LimitWl  = 'nsfplay_n163_2'; // OPT_LIMIT_WAVELENGTH
  static const _kNsfFdsCutoff    = 'nsfplay_fds_lpf_hz';  // OPT_CUTOFF (Hz)
  static const _kNsfFds4085      = 'nsfplay_fds_1';       // OPT_4085_RESET
  static const _kNsfFdsWriteProt = 'nsfplay_fds_2';       // OPT_WRITE_PROTECT
  static const _kNsfMmc5NonLin   = 'nsfplay_mmc5_0'; // OPT_NONLINEAR_MIXER
  static const _kNsfMmc5Phase    = 'nsfplay_mmc5_1'; // OPT_PHASE_REFRESH
  static const _kNsfVrc7Patch    = 'nsfplay_vrc7_patch'; // OPLL_TONE_ENUM 0..9
  static const _kNsfVrc7Opll     = 'nsfplay_vrc7_opll';  // OPT_OPLL
  int get nsfQuality => (_p.getInt(_kNsfQuality) ?? 10).clamp(0, 40);
  set nsfQuality(int v) { _p.setInt(_kNsfQuality, v); notifyListeners(); }
  int get nsfLpf => (_p.getInt(_kNsfLpf) ?? 112).clamp(0, 400);
  set nsfLpf(int v) { _p.setInt(_kNsfLpf, v); notifyListeners(); }
  int get nsfHpf => (_p.getInt(_kNsfHpf) ?? 164).clamp(0, 256);
  set nsfHpf(int v) { _p.setInt(_kNsfHpf, v); notifyListeners(); }
  /// 0 auto … 6 (nsfplay REGION values).
  int get nsfRegion => (_p.getInt(_kNsfRegion) ?? 0).clamp(0, 6);
  set nsfRegion(int v) { _p.setInt(_kNsfRegion, v); notifyListeners(); }
  bool get nsfIrq => _p.getBool(_kNsfIrq) ?? false;
  set nsfIrq(bool v) { _p.setBool(_kNsfIrq, v); notifyListeners(); }

  // 2A03 pulse channels (APU1).
  bool get nsfApu1Unmute => _p.getBool(_kNsfApu1Unmute) ?? true;
  set nsfApu1Unmute(bool v) { _p.setBool(_kNsfApu1Unmute, v); notifyListeners(); }
  bool get nsfApu1PhaseRefresh => _p.getBool(_kNsfApu1Phase) ?? true;
  set nsfApu1PhaseRefresh(bool v) { _p.setBool(_kNsfApu1Phase, v); notifyListeners(); }
  bool get nsfApu1NonlinearMixer => _p.getBool(_kNsfApu1NonLin) ?? true;
  set nsfApu1NonlinearMixer(bool v) { _p.setBool(_kNsfApu1NonLin, v); notifyListeners(); }
  bool get nsfApu1DutySwap => _p.getBool(_kNsfApu1DutySwap) ?? false;
  set nsfApu1DutySwap(bool v) { _p.setBool(_kNsfApu1DutySwap, v); notifyListeners(); }
  bool get nsfApu1NegateSweep => _p.getBool(_kNsfApu1NegSweep) ?? false;
  set nsfApu1NegateSweep(bool v) { _p.setBool(_kNsfApu1NegSweep, v); notifyListeners(); }

  // 2A03 triangle / noise / DPCM (APU2).
  bool get nsfApu2Enable4011 => _p.getBool(_kNsfApu2Reg4011) ?? true;
  set nsfApu2Enable4011(bool v) { _p.setBool(_kNsfApu2Reg4011, v); notifyListeners(); }
  bool get nsfApu2PeriodicNoise => _p.getBool(_kNsfApu2PNoise) ?? true;
  set nsfApu2PeriodicNoise(bool v) { _p.setBool(_kNsfApu2PNoise, v); notifyListeners(); }
  bool get nsfApu2Unmute => _p.getBool(_kNsfApu2Unmute) ?? true;
  set nsfApu2Unmute(bool v) { _p.setBool(_kNsfApu2Unmute, v); notifyListeners(); }
  bool get nsfApu2DpcmAntiClick => _p.getBool(_kNsfApu2AntiClk) ?? false;
  set nsfApu2DpcmAntiClick(bool v) { _p.setBool(_kNsfApu2AntiClk, v); notifyListeners(); }
  bool get nsfApu2NonlinearMixer => _p.getBool(_kNsfApu2NonLin) ?? true;
  set nsfApu2NonlinearMixer(bool v) { _p.setBool(_kNsfApu2NonLin, v); notifyListeners(); }
  bool get nsfApu2RandomizeNoise => _p.getBool(_kNsfApu2RndNoise) ?? true;
  set nsfApu2RandomizeNoise(bool v) { _p.setBool(_kNsfApu2RndNoise, v); notifyListeners(); }
  bool get nsfApu2TriangleMute => _p.getBool(_kNsfApu2TriMute) ?? true;
  set nsfApu2TriangleMute(bool v) { _p.setBool(_kNsfApu2TriMute, v); notifyListeners(); }
  bool get nsfApu2RandomizeTri => _p.getBool(_kNsfApu2RndTri) ?? true;
  set nsfApu2RandomizeTri(bool v) { _p.setBool(_kNsfApu2RndTri, v); notifyListeners(); }
  bool get nsfApu2DpcmReverse => _p.getBool(_kNsfApu2DpcmRev) ?? false;
  set nsfApu2DpcmReverse(bool v) { _p.setBool(_kNsfApu2DpcmRev, v); notifyListeners(); }

  // Namco 163 expansion.
  bool get nsfN163Serial => _p.getBool(_kNsfN163Serial) ?? true;
  set nsfN163Serial(bool v) { _p.setBool(_kNsfN163Serial, v); notifyListeners(); }
  bool get nsfN163PhaseReadOnly => _p.getBool(_kNsfN163PhaseRO) ?? false;
  set nsfN163PhaseReadOnly(bool v) { _p.setBool(_kNsfN163PhaseRO, v); notifyListeners(); }
  bool get nsfN163LimitWavelength => _p.getBool(_kNsfN163LimitWl) ?? false;
  set nsfN163LimitWavelength(bool v) { _p.setBool(_kNsfN163LimitWl, v); notifyListeners(); }

  // FDS expansion.
  int get nsfFdsCutoff => (_p.getInt(_kNsfFdsCutoff) ?? 2000).clamp(0, 4000);
  set nsfFdsCutoff(int v) { _p.setInt(_kNsfFdsCutoff, v); notifyListeners(); }
  bool get nsfFds4085Reset => _p.getBool(_kNsfFds4085) ?? false;
  set nsfFds4085Reset(bool v) { _p.setBool(_kNsfFds4085, v); notifyListeners(); }
  bool get nsfFdsWriteProtect => _p.getBool(_kNsfFdsWriteProt) ?? false;
  set nsfFdsWriteProtect(bool v) { _p.setBool(_kNsfFdsWriteProt, v); notifyListeners(); }

  // MMC5 expansion.
  bool get nsfMmc5NonlinearMixer => _p.getBool(_kNsfMmc5NonLin) ?? true;
  set nsfMmc5NonlinearMixer(bool v) { _p.setBool(_kNsfMmc5NonLin, v); notifyListeners(); }
  bool get nsfMmc5PhaseRefresh => _p.getBool(_kNsfMmc5Phase) ?? true;
  set nsfMmc5PhaseRefresh(bool v) { _p.setBool(_kNsfMmc5Phase, v); notifyListeners(); }

  // VRC7 expansion. Patch set = OPLL_TONE_ENUM (emu2413.h).
  // Patch-set names are chip/dump identifiers, not prose — kept as-is in every
  // language (the first one is the emulator's own default set).
  static const nsfVrc7PatchNames = [
    'VRC7 (default)', 'VRC7 (RW)', 'VRC7 (FT36)', 'VRC7 (FT35)', 'VRC7 (MO)',
    'VRC7 (KT2)', 'VRC7 (KT1)', 'YM2413', 'YMF281B', 'YMF281B (PlgDavid)',
  ];
  int get nsfVrc7Patch =>
      (_p.getInt(_kNsfVrc7Patch) ?? 0).clamp(0, nsfVrc7PatchNames.length - 1);
  set nsfVrc7Patch(int v) { _p.setInt(_kNsfVrc7Patch, v); notifyListeners(); }
  bool get nsfVrc7Opll => _p.getBool(_kNsfVrc7Opll) ?? false;
  set nsfVrc7Opll(bool v) { _p.setBool(_kNsfVrc7Opll, v); notifyListeners(); }

  // PSF (highlyexp): PS1/PS2 SPU toggles.
  static const _kHeSpuMain   = 'he_spu_main';
  static const _kHeSpuReverb = 'he_spu_reverb';
  bool get heSpuMain => _p.getBool(_kHeSpuMain) ?? true;
  set heSpuMain(bool v) { _p.setBool(_kHeSpuMain, v); notifyListeners(); }
  bool get heSpuReverb => _p.getBool(_kHeSpuReverb) ?? true;
  set heSpuReverb(bool v) { _p.setBool(_kHeSpuReverb, v); notifyListeners(); }

  // AdPlug: harmonic mode.
  static const _kAdplugSurround = 'adplug_surround';
  bool get adplugSurround => _p.getBool(_kAdplugSurround) ?? true;
  set adplugSurround(bool v) { _p.setBool(_kAdplugSurround, v); notifyListeners(); }

  // libvgm chip emulator cores (0 = défaut compilation; 1..n = core explicite).
  static const _kVgmYm2612 = 'vgm_ym2612_core';
  static const _kVgmYmf262 = 'vgm_ymf262_core';
  static const _kVgmYm3812 = 'vgm_ym3812_core';
  static const _kVgmQsound = 'vgm_qsound_core';
  static const _kVgmRf5c68 = 'vgm_rf5c68_core';
  int get vgmYm2612Core => (_p.getInt(_kVgmYm2612) ?? 0).clamp(0, 3);
  set vgmYm2612Core(int v) { _p.setInt(_kVgmYm2612, v); notifyListeners(); }
  int get vgmYmf262Core => (_p.getInt(_kVgmYmf262) ?? 0).clamp(0, 3);
  set vgmYmf262Core(int v) { _p.setInt(_kVgmYmf262, v); notifyListeners(); }
  int get vgmYm3812Core => (_p.getInt(_kVgmYm3812) ?? 0).clamp(0, 2);
  set vgmYm3812Core(int v) { _p.setInt(_kVgmYm3812, v); notifyListeners(); }
  int get vgmQsoundCore => (_p.getInt(_kVgmQsound) ?? 0).clamp(0, 2);
  set vgmQsoundCore(int v) { _p.setInt(_kVgmQsound, v); notifyListeners(); }
  int get vgmRf5c68Core => (_p.getInt(_kVgmRf5c68) ?? 0).clamp(0, 2);
  set vgmRf5c68Core(int v) { _p.setInt(_kVgmRf5c68, v); notifyListeners(); }

  // Choix de coeur ajoutés avec la montée libvgm du 2026-08-21.
  // 0 = défaut de la bibliothèque; l'ORDRE suit sel[] dans rewamp_plugin_vgm.cpp.
  static const _kVgmGb = 'vgm_gb_core';
  int get vgmGbCore => (_p.getInt(_kVgmGb) ?? 0).clamp(0, 2);
  set vgmGbCore(int v) { _p.setInt(_kVgmGb, v); notifyListeners(); }
  static const _kVgmYm2413 = 'vgm_ym2413_core';
  int get vgmYm2413Core => (_p.getInt(_kVgmYm2413) ?? 0).clamp(0, 3);
  set vgmYm2413Core(int v) { _p.setInt(_kVgmYm2413, v); notifyListeners(); }
  static const _kVgmYm2151 = 'vgm_ym2151_core';
  int get vgmYm2151Core => (_p.getInt(_kVgmYm2151) ?? 0).clamp(0, 2);
  set vgmYm2151Core(int v) { _p.setInt(_kVgmYm2151, v); notifyListeners(); }
  static const _kVgmAy8910 = 'vgm_ay8910_core';
  int get vgmAy8910Core => (_p.getInt(_kVgmAy8910) ?? 0).clamp(0, 2);
  set vgmAy8910Core(int v) { _p.setInt(_kVgmAy8910, v); notifyListeners(); }
  static const _kVgmNes = 'vgm_nes_core';
  int get vgmNesCore => (_p.getInt(_kVgmNes) ?? 0).clamp(0, 2);
  set vgmNesCore(int v) { _p.setInt(_kVgmNes, v); notifyListeners(); }
  static const _kVgmSn76496 = 'vgm_sn76496_core';
  int get vgmSn76496Core => (_p.getInt(_kVgmSn76496) ?? 0).clamp(0, 2);
  set vgmSn76496Core(int v) { _p.setInt(_kVgmSn76496, v); notifyListeners(); }
  static const _kVgmSaa1099 = 'vgm_saa1099_core';
  int get vgmSaa1099Core => (_p.getInt(_kVgmSaa1099) ?? 0).clamp(0, 2);
  set vgmSaa1099Core(int v) { _p.setInt(_kVgmSaa1099, v); notifyListeners(); }
  static const _kVgmC6280 = 'vgm_c6280_core';
  int get vgmC6280Core => (_p.getInt(_kVgmC6280) ?? 0).clamp(0, 2);
  set vgmC6280Core(int v) { _p.setInt(_kVgmC6280, v); notifyListeners(); }

  static const _kOmptInterpMigrated = 'openmpt.interp_map_migrated';
  int get omptInterpolation {
    // One-shot migration of values written by the mislabeled picker: what the
    // user SAW is what must survive ("none" 0 -> 1, "linear" 1 -> 2).
    if (!(_p.getBool(_kOmptInterpMigrated) ?? false)) {
      final old = _p.getInt(_kOmptInterpolation);
      if (old == 0) _p.setInt(_kOmptInterpolation, 1);
      if (old == 1) _p.setInt(_kOmptInterpolation, 2);
      _p.setBool(_kOmptInterpMigrated, true);
    }
    return _p.getInt(_kOmptInterpolation) ?? 8;
  }
  set omptInterpolation(int v) { _p.setInt(_kOmptInterpolation, v); notifyListeners(); }

  /// Stereo separation in percent (0 = mono, 100 = default, 200 = maximum).
  int get omptStereoSep => _p.getInt(_kOmptStereoSep) ?? 100;
  set omptStereoSep(int v) { _p.setInt(_kOmptStereoSep, v); notifyListeners(); }

  /// -1 = loop forever, 0 = play once, N = repeat N times after first play.
  int get omptLoopCount => _p.getInt(_kOmptLoopCount) ?? -1;
  set omptLoopCount(int v) { _p.setInt(_kOmptLoopCount, v); notifyListeners(); }

  // ── User identity ─────────────────────────────────────────────────────────
  //
  // The UUID IS the account: it is a bearer credential (no session, no token,
  // no expiry — whoever holds it holds the library and the listening history).
  // It therefore lives in the Keychain (iOS/macOS) / EncryptedSharedPreferences
  // (Android), never in SharedPreferences, never in a URL, never in a log.

  /// Pre-Keychain location. Read once at startup, then wiped (see [_loadUserId]).
  static const _kLegacyUserId = 'user.id';

  /// Key used inside a backup archive only (see [dumpAll]).
  static const _kBackupUserId = 'account.user_id';

  static const _kSecureUserId = 'rewamp.user_id';

  /// Signed JWT proving this device owns the account (migrations 188/189). It
  /// IS the account: whoever holds it holds the library. Keychain only — never
  /// in a preference, a URL, a log or a crash report.
  static const _kSecureAuthToken = 'rewamp.auth_token';

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    // first_unlock (not unlocked): a background media session may need to log a
    // play while the device is locked.
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  String? _userId;

  /// False once a secure-storage call has thrown (missing entitlement, no
  /// libsecret on Linux, …). We then keep the id in memory + prefs rather than
  /// lose the account outright; the clear-text copy is the lesser evil.
  bool _secureOk = true;

  /// Permanent user UUID, set on first launch by [RewampDb.registerUser] and
  /// replaced by the one [RewampDb.verifyLoginCode] returns. Cached in memory:
  /// every caller reads it synchronously, the store is async.
  String? get userId => _userId;

  /// True when the id could only be persisted in the clear (secure backend
  /// unavailable) — surfaced in the account screen, not silently swallowed.
  bool get userIdInsecureFallback => !_secureOk;

  String? _authToken;

  /// Bearer token sent on every account call. Null on a device that has never
  /// registered, or one whose stored account predates the token model — the
  /// server then answers `42501` on writes and an EMPTY LIST on reads, so the
  /// caller must treat null as "no account yet", not as "empty library".
  String? get authToken => _authToken;
  bool get hasAuthToken => _authToken != null && _authToken!.isNotEmpty;

  static const _kLibraryCursor = 'sync.library_cursor';

  /// Highest `updated_at` seen in a library delta. The next pull asks for
  /// `>= cursor` (the server filters inclusively on purpose: two writes in the
  /// same microsecond can land exactly on it, and a row seen twice is harmless
  /// where a row lost is forever). Null = never synced → full pull.
  DateTime? get libraryCursor {
    final s = _p.getString(_kLibraryCursor);
    return s == null ? null : DateTime.tryParse(s);
  }

  set libraryCursor(DateTime? v) {
    if (v == null) {
      _p.remove(_kLibraryCursor);
    } else {
      _p.setString(_kLibraryCursor, v.toUtc().toIso8601String());
    }
  }

  static const _kPlayStatsCursor = 'sync.play_stats_cursor';

  /// Highest `last_played_at` seen in a `user_play_stats` delta (same
  /// inclusive `>=` convention as [libraryCursor]). Null = never synced —
  /// the first pull also replays the account's ext play history into
  /// play_events (new-device restore).
  DateTime? get playStatsCursor {
    final s = _p.getString(_kPlayStatsCursor);
    return s == null ? null : DateTime.tryParse(s);
  }

  set playStatsCursor(DateTime? v) {
    if (v == null) {
      _p.remove(_kPlayStatsCursor);
    } else {
      _p.setString(_kPlayStatsCursor, v.toUtc().toIso8601String());
    }
  }

  // ── Bibliothèque: disposition et tri, par écran ──────────────────────────
  static const _kLibraryViewMode = 'library.view_mode';

  /// liste / grille / grille compacte pour les écrans de bibliothèque. Réglage
  /// PROPRE, distinct de `albumViewMode` (la navigation par facettes): les deux
  /// écrans se ressemblent, mais choisir une grille pour parcourir le
  /// catalogue ne veut pas dire la vouloir dans sa bibliothèque.
  String get libraryViewMode =>
      _p.getString(_kLibraryViewMode) ?? 'list';
  set libraryViewMode(String v) => _p.setString(_kLibraryViewMode, v);

  /// Tri d'un écran de bibliothèque ('track' | 'album' | 'artist'): le CHAMP
  /// et le SENS, chacun sa clé pour qu'un ajout de champ ne casse pas le
  /// réglage existant.
  String? librarySort(String kind) => _p.getString('library.sort.$kind');
  bool librarySortAsc(String kind) =>
      _p.getBool('library.sort_asc.$kind') ?? true;
  void setLibrarySort(String kind, String field, bool ascending) {
    _p.setString('library.sort.$kind', field);
    _p.setBool('library.sort_asc.$kind', ascending);
  }

  static const _kAlbumMaterialisedReset = 'sync.album_materialised_reset';

  /// Les marqueurs « album matérialisé » posés par le repli « plus d'une piste
  /// = complet » ont été jetés. Ce repli figeait des listes partielles (11
  /// pistes ici, 67 là, les deux marquées complètes); le marqueur n'étant
  /// qu'un cache, le remède est de tout redemander une fois.
  bool get albumMaterialisedReset =>
      _p.getBool(_kAlbumMaterialisedReset) ?? false;
  set albumMaterialisedReset(bool v) =>
      _p.setBool(_kAlbumMaterialisedReset, v);

  static const _kLibraryDriftAudited = 'sync.library_drift_audited';

  /// La passe de rattrapage « ce que le compte a et que cet appareil n'a pas »
  /// a déjà eu lieu sur cette installation. Un curseur n'avance que sur ce
  /// qu'on a vu: une entrée plus ancienne que lui ne revient jamais dans un
  /// delta, donc une dérive née AVANT ce correctif ne se répare que par une
  /// passe sans curseur, déclenchée une fois — la comparaison qui suit
  /// (`_accountHasWhatWeLack`, à chaque réconciliation) prend le relais.
  bool get libraryDriftAudited =>
      _p.getBool(_kLibraryDriftAudited) ?? false;
  set libraryDriftAudited(bool v) => _p.setBool(_kLibraryDriftAudited, v);

  static const _kLibraryMintAudited = 'sync.library_mint_audited';

  /// La passe de rattrapage « entrée de bibliothèque SANS ligne `tracks` » a
  /// eu lieu. Le plafond de fabrication (40 par passe) laissait le curseur
  /// dépasser les lignes qu'il n'avait pas eu le temps de traiter: au-delà du
  /// 40e morceau, l'entrée restait dans la bibliothèque et n'apparaissait
  /// nulle part (playlist Favoris comprise, qui lit à travers `tracks`), sans
  /// retour possible — un delta ne ramène jamais ce qui précède son curseur.
  /// Le curseur est désormais borné à la première ligne reportée; l'existant
  /// se répare par une passe sans curseur, déclenchée une fois.
  bool get libraryMintAudited =>
      _p.getBool(_kLibraryMintAudited) ?? false;
  set libraryMintAudited(bool v) => _p.setBool(_kLibraryMintAudited, v);

  static const _kPlayHistoryCursor = 'sync.play_history_cursor';

  /// Plus haut `played_at` descendu dans le miroir `account_play_events`
  /// (`user_play_history`). Convention `>=` inclusive comme [libraryCursor]:
  /// la page suivante rejoue au moins la dernière ligne, que la clé primaire
  /// du miroir ignore. Null = miroir jamais rempli.
  DateTime? get playHistoryCursor {
    final s = _p.getString(_kPlayHistoryCursor);
    return s == null ? null : DateTime.tryParse(s);
  }

  set playHistoryCursor(DateTime? v) {
    if (v == null) {
      _p.remove(_kPlayHistoryCursor);
    } else {
      _p.setString(_kPlayHistoryCursor, v.toUtc().toIso8601String());
    }
  }

  static const _kPlayHistoryBackfilled = 'sync.play_history_backfilled';

  /// Le rattrapage unique de `play_events.pushed` a été fait (voir
  /// [LocalDb.markLocalPlaysPushedBefore]): les écoutes locales livrées AVANT
  /// que le marqueur n'existe ont été reconnues comme telles.
  bool get playHistoryBackfilled =>
      _p.getBool(_kPlayHistoryBackfilled) ?? false;
  set playHistoryBackfilled(bool v) =>
      _p.setBool(_kPlayHistoryBackfilled, v);

  static const _kPlaylistCursor = 'sync.playlist_cursor';

  /// Highest `playlists.updated_at` seen — the delta cursor for playlist
  /// CONTENT (migration 182), distinct from the library one.
  DateTime? get playlistCursor {
    final s = _p.getString(_kPlaylistCursor);
    return s == null ? null : DateTime.tryParse(s);
  }

  set playlistCursor(DateTime? v) {
    if (v == null) {
      _p.remove(_kPlaylistCursor);
    } else {
      _p.setString(_kPlaylistCursor, v.toUtc().toIso8601String());
    }
  }

  static const _kLibraryReconciled = 'sync.library_reconciled_at';

  /// Last full reconciliation of the library (the pass that detects what was
  /// removed elsewhere). Deltas cover additions in between.
  DateTime? get libraryReconciledAt {
    final ms = _p.getInt(_kLibraryReconciled);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  set libraryReconciledAt(DateTime? v) {
    if (v == null) {
      _p.remove(_kLibraryReconciled);
    } else {
      _p.setInt(_kLibraryReconciled, v.millisecondsSinceEpoch);
    }
  }

  static const _kExtLibraryAudited = 'sync.ext_library_audited';

  /// Has the one-shot audit of the account's out-of-catalogue favourites run?
  ///
  /// The ext rows fabricated from a display TITLE (see SyncService, migration
  /// 40) sit on the account with an `updated_at` older than this device's
  /// cursor, so a delta will NEVER carry them again and the purge that knows
  /// how to recognise them would never fire. One pull asked WITHOUT the cursor
  /// sees them all; after that there is nothing left to look for, hence a
  /// one-shot flag rather than a recurring full pull.
  bool get extLibraryAudited => _p.getBool(_kExtLibraryAudited) ?? false;
  set extLibraryAudited(bool v) => _p.setBool(_kExtLibraryAudited, v);

  static const _kFavouritesBlobPurged = 'sync.favourites_blob_purged';

  /// Le blob `user_state.favourites` a-t-il été effacé ? Le ♥ est une COLONNE
  /// serveur depuis la migration 206 ; le serveur ne touche pas au blob
  /// (contrat d'opacité de la mig 178), donc le client le purge lui-même — une
  /// fois, sinon chaque synchro paierait une écriture pour rien.
  bool get favouritesBlobPurged =>
      _p.getBool(_kFavouritesBlobPurged) ?? false;
  set favouritesBlobPurged(bool v) => _p.setBool(_kFavouritesBlobPurged, v);

  static const _kReleaseNotesShown = 'app.release_notes_shown';

  /// Version de note de version déjà montrée sur cet appareil (0 = jamais).
  /// Comparée à `kReleaseNotesVersion`; comme toute préférence, elle disparaît
  /// avec la remise à zéro de `data_reset.dart` — et c'est voulu: l'effacement
  /// et la note qui l'annonce vont ensemble.
  int get releaseNotesShown => _p.getInt(_kReleaseNotesShown) ?? 0;
  set releaseNotesShown(int v) => _p.setInt(_kReleaseNotesShown, v);

  static const _kAccountHasEmail = 'account.has_email';

  /// Last known answer of `get_account`: is an email attached to this UUID?
  /// Cached because it gates DESTRUCTIVE settings offline too (renewing the id
  /// on an unrecoverable account throws the library away).
  bool get accountHasEmail => _p.getBool(_kAccountHasEmail) ?? false;
  set accountHasEmail(bool v) {
    _p.setBool(_kAccountHasEmail, v);
    notifyListeners();
  }

  /// A-t-on DÉJÀ résolu ce drapeau ? Il n'est écrit qu'après un
  /// `getAccount()`, donc « absent » ne veut pas dire « anonyme »: ça veut dire
  /// « on ne sait pas encore ». La distinction est load-bearing — l'action
  /// « renouveler l'identifiant » ABANDONNE le compte, et son défaut à `false`
  /// la proposait à un compte pourvu d'un e-mail tant que l'écran Compte
  /// n'avait pas été ouvert une fois.
  bool get accountHasEmailKnown => _p.containsKey(_kAccountHasEmail);

  Future<void> setUserId(String? v) async {
    if (v == null || v.isEmpty) return;
    if (v == _userId) return;
    _userId = v;
    await _writeUserId(v);
    notifyListeners();
  }

  /// Stores the token `register_user` / `verify_login_code` / `revoke_sessions`
  /// returned. Always take the newest one: after a login the token designates a
  /// DIFFERENT account than before (that is the point), and keeping the old one
  /// would go on writing to the abandoned anonymous UUID.
  Future<void> setAuthToken(String? v) async {
    if (v == null || v.isEmpty) return;
    if (v == _authToken) return;
    _authToken = v;
    if (_secureOk) {
      try {
        await _secure.write(key: _kSecureAuthToken, value: v);
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('[UserSettings] secure token write failed: $e');
        _secureOk = false;
      }
    }
    // No secure backend (no libsecret on Linux, missing entitlement…): the
    // token stays in MEMORY for this session only. Deliberately NOT mirrored to
    // SharedPreferences the way the uuid is — the uuid was a weak identifier,
    // this is a signed credential and a clear-text copy is a real key on disk.
    notifyListeners();
  }

  Future<void> clearAuthToken() async {
    _authToken = null;
    try {
      await _secure.delete(key: _kSecureAuthToken);
    } catch (e) {
      debugPrint('[UserSettings] secure token delete failed: $e');
    }
    notifyListeners();
  }

  /// Forget the account on this device. Caller must have checked that it is
  /// recoverable (an email is attached) — without one the data is unreachable
  /// for good.
  Future<void> clearUserId() async {
    _userId = null;
    try {
      await _secure.delete(key: _kSecureUserId);
    } catch (e) {
      debugPrint('[UserSettings] secure delete failed: $e');
    }
    await _p.remove(_kLegacyUserId);
    // The token IS the account — leaving it behind would keep this device
    // writing to the very account the user just forgot.
    await clearAuthToken();
    notifyListeners();
  }

  Future<void> _writeUserId(String v) async {
    if (_secureOk) {
      try {
        await _secure.write(key: _kSecureUserId, value: v);
        await _p.remove(_kLegacyUserId);
        return;
      } catch (e) {
        debugPrint('[UserSettings] secure write failed: $e');
        _secureOk = false;
      }
    }
    await _p.setString(_kLegacyUserId, v);
  }

  Future<void> _loadUserId() async {
    String? secure;
    try {
      secure = await _secure.read(key: _kSecureUserId);
      _authToken = await _secure.read(key: _kSecureAuthToken);
    } catch (e) {
      debugPrint('[UserSettings] secure read failed: $e');
      _secureOk = false;
    }
    final legacy = _p.getString(_kLegacyUserId);
    if (secure != null && secure.isNotEmpty) {
      _userId = secure;
      // A stale clear-text copy is a leak, not a fallback.
      if (legacy != null) await _p.remove(_kLegacyUserId);
      return;
    }
    if (legacy != null && legacy.isNotEmpty) {
      _userId = legacy;
      await _writeUserId(legacy); // migrate, then drop the clear copy
    }
  }

  // ── Lecture — détection de silence ─────────────────────────────────────────

  static const _kSilenceSkip     = 'playback.silence_skip';
  static const _kSilenceSkipSecs = 'playback.silence_skip_secs';

  /// Auto-skip to the next track after a stretch of output silence (default on).
  bool get silenceSkipEnabled => _p.getBool(_kSilenceSkip) ?? true;
  set silenceSkipEnabled(bool v) { _p.setBool(_kSilenceSkip, v); notifyListeners(); }

  /// Silence duration (seconds) before auto-skipping (default 5).
  double get silenceSkipSeconds => _p.getDouble(_kSilenceSkipSecs) ?? 10.0;
  set silenceSkipSeconds(double v) {
    _p.setDouble(_kSilenceSkipSecs, v.clamp(1.0, 30.0));
    notifyListeners();
  }

  // ── Lecture — durée par défaut ─────────────────────────────────────────────

  static const _kDefaultTrackLength = 'playback.default_track_length_secs';

  /// Fallback duration (seconds) applied when a track reports no known
  /// length (native decoder length()==0, no server metadata) — otherwise
  /// such tracks (e.g. chip formats without an embedded length tag) would
  /// loop or play indefinitely. Never applied to UADE tracks, which have
  /// their own async songdb duration lookup instead. Default 2:30 (150s).
  double get defaultTrackLengthSeconds =>
      _p.getDouble(_kDefaultTrackLength) ?? 150.0;
  set defaultTrackLengthSeconds(double v) {
    _p.setDouble(_kDefaultTrackLength, v.clamp(10.0, 3600.0));
    notifyListeners();
  }

  // ── Lecture — forçage boucle / fondu ───────────────────────────────────────
  //
  // Some engines (libvgm, libopenmpt, libgme...) natively understand a
  // format's loop point and can repeat just the loop section N times before
  // fading out — real "hardware-accurate" looping. Others have no loop
  // concept at all and need a generic fallback (replay from the start).
  // These 4 settings are engine-agnostic controls; how each backend applies
  // them is backend-specific (see PLUGINS.md once wired).

  static const _kForceLoopMode = 'playback.force_loop_mode'; // 'off'|'on'|'infinite'
  static const _kLoopCount     = 'playback.loop_count';
  static const _kForceFadeout  = 'playback.force_fadeout';
  static const _kFadeoutSecs   = 'playback.fadeout_secs';

  /// 'off' = use each backend's own default behavior (no override).
  /// 'on' = repeat [loopCount] times, then stop (optionally fading out).
  /// 'infinite' = loop forever (ignore natural end / loopCount).
  String get forceLoopMode => _p.getString(_kForceLoopMode) ?? 'off';
  set forceLoopMode(String v) {
    assert(v == 'off' || v == 'on' || v == 'infinite');
    _p.setString(_kForceLoopMode, v);
    notifyListeners();
  }

  /// Number of loop repeats when [forceLoopMode] == 'on' (0–16, default 2).
  int get loopCount => (_p.getInt(_kLoopCount) ?? 2).clamp(0, 16);
  set loopCount(int v) { _p.setInt(_kLoopCount, v.clamp(0, 16)); notifyListeners(); }

  /// Whether to apply a fade-out before stopping (default off).
  bool get forceFadeoutEnabled => _p.getBool(_kForceFadeout) ?? false;
  set forceFadeoutEnabled(bool v) { _p.setBool(_kForceFadeout, v); notifyListeners(); }

  // ── Transport toggles (shuffle / repeat) ─────────────────────────────────
  //
  // Not Settings rows — they live on the transport, next to play/skip — but
  // they are a MODE the user chose, not a property of one queue: quitting the
  // app used to silently turn both back off. Stored in the preferences rather
  // than in the queue snapshot on purpose: that snapshot is dropped after a
  // crashed launch (safe launch), and a mode has no reason to die with it.
  static const _kTransportShuffle = 'playback.transport_shuffle';
  static const _kTransportLoop    = 'playback.transport_loop_mode';

  bool get transportShuffle => _p.getBool(_kTransportShuffle) ?? false;
  set transportShuffle(bool v) {
    _p.setBool(_kTransportShuffle, v);
    notifyListeners();
  }

  /// 0 = off, 1 = loop the queue, 2 = loop the current track (see LoopButton).
  int get transportLoopMode => (_p.getInt(_kTransportLoop) ?? 0).clamp(0, 2);
  set transportLoopMode(int v) {
    _p.setInt(_kTransportLoop, v.clamp(0, 2));
    notifyListeners();
  }

  /// Fade-out duration in seconds when [forceFadeoutEnabled] (0–10, default 3).
  double get fadeoutSeconds => (_p.getDouble(_kFadeoutSecs) ?? 3.0).clamp(0.0, 10.0);
  set fadeoutSeconds(double v) {
    _p.setDouble(_kFadeoutSecs, v.clamp(0.0, 10.0));
    notifyListeners();
  }

  // ── Playback library preferences ──────────────────────────────────────────

  static const _kNsfPlugin = 'playback.nsf_plugin';

  /// Preferred decoder for NSF/NSFe files. Valid values: 'nsfplay', 'libgme'.
  String get nsfPlugin => _p.getString(_kNsfPlugin) ?? 'nsfplay';
  set nsfPlugin(String v) { _p.setString(_kNsfPlugin, v); notifyListeners(); }

  /// .sndh engine: 'psgplay' (default) or 'atariaudio'. Both are compiled in
  /// and psgplay probes one point LOWER, so this preference is the only thing
  /// that decides — the probe order alone would still pick AtariAudio.
  /// psgplay emulates the whole machine, including the STE LMC1992 tone and
  /// volume mixer, and renders stereo natively where AtariAudio gives mono.
  static const _kSndhPlugin = 'playback.sndh_plugin';

  static const _kGbsPlugin = 'playback.gbs_plugin';

  /// Preferred decoder for GBS files. Valid values: 'gbsplay', 'libgme'.
  String get gbsPlugin => _p.getString(_kGbsPlugin) ?? 'gbsplay';
  set gbsPlugin(String v) { _p.setString(_kGbsPlugin, v); notifyListeners(); }

  String get sndhPlugin => _p.getString(_kSndhPlugin) ?? 'psgplay';
  set sndhPlugin(String v) { _p.setString(_kSndhPlugin, v); notifyListeners(); }

  static const _kPmSource = 'vis.pm_source';

  /// Active projectM preset source, encoded by PresetManager
  /// ('bundled' | 'all' | 'user' | 'pack:<slug>' | 'packdir:<slug>/<dir>' |
  /// 'plist:<localId>' | 'srvlist:<serverId>'). Default: bundled presets.
  String get pmSource => _p.getString(_kPmSource) ?? 'bundled';
  set pmSource(String v) { _p.setString(_kPmSource, v); notifyListeners(); }

  static const _kPmLastPreset = 'vis.pm_last_preset';

  /// Preset on screen when projectM was last seen, RELATIVE to
  /// `<datadir>/projectm/` (same form as the preset playlist tables), so it
  /// survives a container path change. Restored by PresetManager.applyStartup.
  ///
  /// Deliberately does NOT notify: it is written on every preset change,
  /// including the engine's own rotation every few seconds, and the settings
  /// listeners would re-push the whole projectM parameter block each time.
  static const _kPmSlowPresets = 'pm.slow_presets';

  /// Presets écartés par le garde-fou de cadence: sur cet appareil ils sont
  /// restés sous 5 images/s pendant plus de 2 s. Chemins RELATIFS à
  /// `<datadir>/projectm/`, comme partout ailleurs.
  ///
  /// Persisté et propre à l'appareil — c'est une propriété du MATÉRIEL, pas du
  /// preset: le même fichier tourne très bien ailleurs, et une liste partagée
  /// par le compte priverait un appareil rapide de presets sains. Se vide avec
  /// les préférences (remise à zéro des données) ou par le bouton des réglages.
  List<String> get pmSlowPresets =>
      _p.getStringList(_kPmSlowPresets) ?? const [];

  void addPmSlowPreset(String rel) {
    if (rel.isEmpty) return;
    final list = [...pmSlowPresets];
    if (list.contains(rel)) return;
    list.add(rel);
    _p.setStringList(_kPmSlowPresets, list);
    notifyListeners();
  }

  void removePmSlowPreset(String rel) {
    final list = [...pmSlowPresets];
    if (!list.remove(rel)) return;
    if (list.isEmpty) {
      _p.remove(_kPmSlowPresets);
    } else {
      _p.setStringList(_kPmSlowPresets, list);
    }
    notifyListeners();
  }

  void clearPmSlowPresets() {
    if (pmSlowPresets.isEmpty) return;
    _p.remove(_kPmSlowPresets);
    notifyListeners();
  }

  String? get pmLastPreset => _p.getString(_kPmLastPreset);
  set pmLastPreset(String? v) {
    if (v == null || v.isEmpty) {
      _p.remove(_kPmLastPreset);
    } else {
      _p.setString(_kPmLastPreset, v);
    }
  }

  static const _kMidiSoundfont = 'playback.midi_soundfont';

  /// Selected SoundFont slug (server assets catalogue); null = none chosen.
  String? get midiSoundfont => _p.getString(_kMidiSoundfont);
  set midiSoundfont(String? v) {
    if (v == null) {
      _p.remove(_kMidiSoundfont);
    } else {
      _p.setString(_kMidiSoundfont, v);
    }
    notifyListeners();
  }

  // FluidLite synth knobs (Settings → Moteurs → FluidLite). Defaults here are
  // the single source of truth (mirrored in rewamp_plugin_midi.c's fallbacks +
  // the reset path). Applied live via app_shell's _applyPlaybackLibraryPrefs.
  static const _kMidiGain      = 'playback.midi_gain';
  static const _kMidiPolyphony = 'playback.midi_polyphony';
  static const _kMidiReverb    = 'playback.midi_reverb';
  static const _kMidiChorus    = 'playback.midi_chorus';
  static const _kMidiInterp    = 'playback.midi_interp';

  /// Output gain (0.1–2.0; FluidLite's 0.2 default is far too quiet next to
  /// the other engines, hence 0.8).
  double get midiGain => _p.getDouble(_kMidiGain) ?? 0.8;
  set midiGain(double v) { _p.setDouble(_kMidiGain, v); notifyListeners(); }

  /// Maximum simultaneous voices (32–256).
  int get midiPolyphony => _p.getInt(_kMidiPolyphony) ?? 128;
  set midiPolyphony(int v) { _p.setInt(_kMidiPolyphony, v); notifyListeners(); }

  bool get midiReverb => _p.getBool(_kMidiReverb) ?? true;
  set midiReverb(bool v) { _p.setBool(_kMidiReverb, v); notifyListeners(); }

  bool get midiChorus => _p.getBool(_kMidiChorus) ?? true;
  set midiChorus(bool v) { _p.setBool(_kMidiChorus, v); notifyListeners(); }

  /// Interpolation method (FLUID_INTERP_*): 0=none, 1=linear, 4=4th order
  /// (default), 7=7th order.
  int get midiInterp => _p.getInt(_kMidiInterp) ?? 4;
  set midiInterp(int v) { _p.setInt(_kMidiInterp, v); notifyListeners(); }

  // ── Browse preferences ─────────────────────────────────────────────────────

  static const _kAlbumViewMode = 'browse.album_view_mode';
  // Home trends period, shared by the personal + server trend rails.
  // Server RPC vocabulary ('7d'|'30d'|'90d'); default 30d.
  static const _kHomeTrendPeriod = 'home.trend_period';

  /// Album-browse display mode: 'list' | 'grid' (large) | 'grid_small'.
  String get albumViewMode => _p.getString(_kAlbumViewMode) ?? 'list';
  set albumViewMode(String v) {
    _p.setString(_kAlbumViewMode, v);
    notifyListeners();
  }

  String get homeTrendPeriod => _p.getString(_kHomeTrendPeriod) ?? '30d';
  set homeTrendPeriod(String v) {
    _p.setString(_kHomeTrendPeriod, v);
    notifyListeners();
  }

  // ── First-run onboarding ───────────────────────────────────────────────────

  static const _kOnboardingSeenBuild = 'onboarding.seen_build';

  /// Build number whose welcome carousel has been acknowledged ('' = never).
  /// Keyed by BUILD, not a bool: this is a beta, so the data-reset warning is
  /// worth repeating at each update.
  String get onboardingSeenBuild => _p.getString(_kOnboardingSeenBuild) ?? '';
  set onboardingSeenBuild(String v) {
    _p.setString(_kOnboardingSeenBuild, v);
    notifyListeners();
  }

  // ── Search preferences ─────────────────────────────────────────────────────

  static const _kSearchExact = 'search.exact';

  /// Exact (non-fuzzy) search mode. Default true → exact search.
  bool get searchExact => _p.getBool(_kSearchExact) ?? true;
  set searchExact(bool v) { _p.setBool(_kSearchExact, v); notifyListeners(); }

  static const _kRecentSearches    = 'search.recent';
  static const _kRecentSearchesMax = 32;

  /// Recent text searches, most recent first. Recorded when a search returns
  /// results; typing intermediates ("tur", "turri") are dropped when the
  /// longer query ("turrican") lands. Max [_kRecentSearchesMax] entries.
  List<String> get recentSearches =>
      _p.getStringList(_kRecentSearches) ?? const [];

  void addRecentSearch(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    final tl = t.toLowerCase();
    final list = List<String>.of(recentSearches)
      // Drop exact dup + previous entries that are a PREFIX of the new query
      // (debounce fires on intermediate keystrokes of the same word).
      ..removeWhere((e) {
        final el = e.toLowerCase();
        return el == tl || tl.startsWith(el);
      })
      ..insert(0, t);
    _p.setStringList(
        _kRecentSearches, list.take(_kRecentSearchesMax).toList());
    notifyListeners();
  }

  void clearRecentSearches() {
    _p.remove(_kRecentSearches);
    notifyListeners();
  }
}
