import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// ---------------------------------------------------------------------------
// Public models
// ---------------------------------------------------------------------------

/// Metadata for one subsong inside a multi-track container (NSF/GBS/AY/…)
/// or one entry in an M3U playlist extracted from an archive.
class SubsongInfo {
  final int     index;      // 0-based position in the overall playlist
  /// Absolute local path to the audio file for this entry.
  /// All entries share the same path for single-file containers (NSF/GBS/…).
  final String  filePath;
  /// 0-based subsong index within [filePath]. 0 = whole file / first subsong.
  final int     subsongIdx;
  final String? title;      // null if the format has no embedded title
  final int?    durationMs; // null if unknown

  const SubsongInfo({
    required this.index,
    required this.filePath,
    this.subsongIdx = 0,
    this.title,
    this.durationMs,
  });

  @override
  String toString() =>
      'SubsongInfo(#$index, sub=$subsongIdx, title=$title, dur=${durationMs}ms)';
}

// ---------------------------------------------------------------------------
// Native function typedefs
// ---------------------------------------------------------------------------

typedef _InitNative = Int32 Function();
typedef _InitDart = int Function();

typedef _UninitNative = Void Function();
typedef _UninitDart = void Function();

typedef _SetDataDirNative = Void Function(Pointer<Utf8> path);
typedef _SetDataDirDart = void Function(Pointer<Utf8> path);

typedef _LoadFileNative = Int32 Function(Pointer<Utf8> path);
typedef _LoadFileDart = int Function(Pointer<Utf8> path);

typedef _SimpleNative = Int32 Function();
typedef _SimpleDart = int Function();

typedef _VoidNative = Void Function();
typedef _VoidDart = void Function();

typedef _IsPlayingNative = Int32 Function();
typedef _IsPlayingDart = int Function();

typedef _GetDoubleNative = Double Function();
typedef _GetDoubleDart = double Function();

typedef _SeekNative = Int32 Function(Double seconds);
typedef _SeekDart = int Function(double seconds);

typedef _SetVolumeNative = Void Function(Float volume);
typedef _SetVolumeDart = void Function(double volume);

typedef _SetForcedLoopNative = Void Function(
    Int32 mode, Int32 count, Int32 fadeoutEnabled, Double fadeoutSeconds,
    Double baseDurationSeconds);
typedef _SetForcedLoopDart = void Function(
    int mode, int count, int fadeoutEnabled, double fadeoutSeconds,
    double baseDurationSeconds);
typedef _HasNativeLoopNative = Int32 Function();
typedef _HasNativeLoopDart = int Function();

typedef _BackendNameNative = Pointer<Utf8> Function();
typedef _BackendNameDart = Pointer<Utf8> Function();
typedef _TrackMessageNative = Pointer<Utf8> Function();
typedef _TrackMessageDart = Pointer<Utf8> Function();
typedef _TrackArtworkNative = Pointer<Uint8> Function(Pointer<Int32> size);
typedef _TrackArtworkDart = Pointer<Uint8> Function(Pointer<Int32> size);
typedef _TrackArtworkMimeNative = Pointer<Utf8> Function();
typedef _TrackArtworkMimeDart = Pointer<Utf8> Function();
typedef _BytesOutNative = Int32 Function(Pointer<Uint8> out, Int32 maxOut);
typedef _BytesOutDart   = int   Function(Pointer<Uint8> out, int maxOut);

typedef _GetWaveformNative = Void Function(Pointer<Float>, Pointer<Float>, Int32);
typedef _GetWaveformDart   = void Function(Pointer<Float>, Pointer<Float>, int);

typedef _VizInitNative = Int32 Function(Int32, Int32);
typedef _VizInitDart   = int  Function(int,   int);

typedef _NotesWindowNative = Int32 Function(Pointer<Float>, Int32, Double, Int32);
typedef _NotesWindowDart   = int   Function(Pointer<Float>, int, double, int);
typedef _NotesVcNative     = Int32 Function();
typedef _NotesVcDart       = int   Function();
typedef _NotesLeadNative   = Double Function();
typedef _NotesLeadDart     = double Function();

typedef _VizRenderNative = Void Function();
typedef _VizRenderDart   = void Function();

typedef _VizUninitNative = Void Function();
typedef _VizUninitDart   = void Function();

// Flutter-texture GPU path (iOS/macOS MetalANGLE).
typedef _VizRegisterNative          = Int64 Function(Int32, Int32);
typedef _VizRegisterDart            = int   Function(int,   int);
typedef _VizResizeRegisterNative    = Int32 Function(Int32, Int32);
typedef _VizResizeRegisterDart      = int   Function(int,   int);
typedef _VizRenderAndNotifyNative   = Void Function();
typedef _VizRenderAndNotifyDart     = void Function();
typedef _VizUnregisterNative        = Void Function();
typedef _VizUnregisterDart          = void Function();
typedef _ScopeRegisterNative        = Int64 Function(Int32, Int32);
typedef _ScopeRegisterDart          = int   Function(int,   int);
typedef _ScopeRenderAndNotifyNative = Void Function();
typedef _ScopeRenderAndNotifyDart   = void Function();

typedef _VizSetArtworkNative     = Void Function(Pointer<Uint8>, Int32, Int32, Float);
typedef _VizSetArtworkDart       = void Function(Pointer<Uint8>, int, int, double);
typedef _VizSetArtworkOpacNative = Void Function(Float);
typedef _VizSetArtworkOpacDart   = void Function(double);
typedef _VizSetFrameTimeNative = Void Function(Double);
typedef _VizSetFrameTimeDart   = void Function(double);
typedef _VizClearArtworkNative   = Void Function();
typedef _VizClearArtworkDart     = void Function();

// ── Tracker-pattern visualizer ──────────────────────────────────────────────
// C: RewampPatternCell — must mirror src/rewamp_plugin.h byte-for-byte.
final class _PatCellNative extends Struct {
  @Int16() external int note;
  @Int32() external int instrument;   // 16-bit range (SunVox module numbers)
  @Int16() external int volume;       // -1 when `vol` carries the text instead
  @Array(4) external Array<Int8> vol; // pre-formatted volume column, '' = none
  @Uint8() external int numFx;
  @Array.multi([8, 4]) external Array<Array<Int8>> fx;  // fx[col][0..3] chars
  @Array(8) external Array<Int32> fxval;                // param, -1 none
}

// C: RewampPatternSongInfo.
final class _PatSongInfoNative extends Struct {
  @Int32() external int numChannels;
  @Int32() external int numOrders;
  @Int32() external int numPatterns;
  @Int32() external int maxFxCols;
  // Per-song field widths in characters, 0 ⇒ the tracker default of 2.
  @Int32() external int instrDigits;
  @Int32() external int volChars;
  @Int32() external int fxcodeChars;
  @Int32() external int fxvalDigits;
}

typedef _PatSupportedNative = Int32 Function();
typedef _PatSupportedDart   = int   Function();
typedef _PatSongInfoNativeFn = Int32 Function(Pointer<_PatSongInfoNative>);
typedef _PatSongInfoDartFn   = int   Function(Pointer<_PatSongInfoNative>);
typedef _PatOrderNative = Int32 Function(Int32);
typedef _PatOrderDart   = int   Function(int);
typedef _PatNumRowsNative = Int32 Function(Int32);
typedef _PatNumRowsDart   = int   Function(int);
typedef _PatGetNative = Int32 Function(Int32, Pointer<_PatCellNative>, Int32);
typedef _PatGetDart   = int   Function(int, Pointer<_PatCellNative>, int);
typedef _PatCursorNative = Int32 Function(Pointer<Int32>, Pointer<Int32>);
typedef _PatCursorDart   = int   Function(Pointer<Int32>, Pointer<Int32>);

typedef _ScopeSetGridNative      = Void Function(Int32);
typedef _ScopeSetGridDart        = void Function(int);

typedef _SetLineWidthNative      = Void Function(Float);
typedef _SetLineWidthDart        = void Function(double);

typedef _SetCrtFlagsNative       = Void Function(Int32);
typedef _SetCrtFlagsDart         = void Function(int);

typedef _SetColorNative          = Void Function(Float, Float, Float);
typedef _SetColorDart            = void Function(double, double, double);
typedef _SetBicolorNative        = Void Function(Int32);
typedef _SetBicolorDart          = void Function(int);

typedef _ChannelCountNative  = Int32 Function();
typedef _ChannelCountDart    = int Function();

typedef _ChannelBufNative    = Int32 Function(Int32 ch, Pointer<Int8> out, Int32 outLen);
typedef _ChannelBufDart      = int  Function(int  ch, Pointer<Int8> out, int  outLen);

typedef _ChannelBufTrigNative = Int32 Function(Int32 ch, Pointer<Int8> out, Int32 outLen);
typedef _ChannelBufTrigDart   = int  Function(int  ch, Pointer<Int8> out, int  outLen);

typedef _ChannelFreqNative   = Float Function(Int32 ch);
typedef _ChannelFreqDart     = double Function(int ch);

typedef _ChannelVolNative    = Int32 Function(Int32 ch);
typedef _ChannelVolDart      = int   Function(int ch);

typedef _ChannelWritePtrNative = Int64 Function(Int32 ch);
typedef _ChannelWritePtrDart   = int   Function(int ch);

// Voice / chipset grouping + muting.
typedef _VoidRetIntNative   = Int32 Function();
typedef _VoidRetIntDart     = int   Function();
typedef _IntRetIntNative    = Int32 Function(Int32 i);
typedef _IntRetIntDart      = int   Function(int i);
typedef _NameNative         = Int32 Function(Int32 i, Pointer<Utf8> out, Int32 len);
typedef _NameDart           = int   Function(int i, Pointer<Utf8> out, int len);
typedef _GetMaskNative      = Int64 Function();
typedef _GetMaskDart        = int   Function();
typedef _SetMaskNative      = Void  Function(Int64 mask);
typedef _SetMaskDart        = void  Function(int mask);

typedef _SetPreferredPluginNative = Void Function(Pointer<Utf8> ext, Pointer<Utf8> plugin_name);
typedef _SetPreferredPluginDart  = void Function(Pointer<Utf8> ext, Pointer<Utf8> plugin_name);

typedef _ProbeSubsongNative      = Int32        Function(Pointer<Utf8> path);
typedef _ProbeSubsongDart        = int          Function(Pointer<Utf8> path);
typedef _ProbeGetTitleNative     = Pointer<Utf8> Function(Int32 idx);
typedef _ProbeGetTitleDart       = Pointer<Utf8> Function(int idx);
typedef _ProbeGetDurationNative  = Int32        Function(Int32 idx);
typedef _ProbeGetDurationDart    = int          Function(int idx);

typedef _ExtractArchiveNative    = Int32        Function(Pointer<Utf8> archivePath, Pointer<Utf8> destDir);
typedef _ExtractArchiveDart      = int          Function(Pointer<Utf8> archivePath, Pointer<Utf8> destDir);
typedef _ExtractLastErrorNative  = Pointer<Utf8> Function();
typedef _ExtractLastErrorDart    = Pointer<Utf8> Function();

typedef _SidMd5Native = Pointer<Utf8> Function(Pointer<Utf8> path);
typedef _SidMd5Dart   = Pointer<Utf8> Function(Pointer<Utf8> path);

// ---------------------------------------------------------------------------
// Library loader
// ---------------------------------------------------------------------------

DynamicLibrary _loadLibrary() {
  if (Platform.isAndroid) return DynamicLibrary.open('librewamp_audio.so');
  if (Platform.isLinux)   return DynamicLibrary.open('librewamp_audio.so');
  if (Platform.isWindows) return DynamicLibrary.open('rewamp_audio.dll');
  return DynamicLibrary.process();
}

// ---------------------------------------------------------------------------
// Tracker-pattern view — plain Dart model returned by the pattern* API below.
// ---------------------------------------------------------------------------

/// Note sentinels (mirror REWAMP_NOTE_* in src/rewamp_plugin.h). A note >= 0 is
/// a semitone index, 0 = C-0 (octave = note ~/ 12, name = note % 12).
class PatternNote {
  static const int empty = -1;
  static const int off   = -2;
  static const int cut   = -3;
  static const int fade  = -4;
}

/// One effect column of a cell: a display [code] ("A", "0F", …) + [param] byte.
class PatternFx {
  final String code;
  final int param;   // 0..255
  const PatternFx(this.code, this.param);
}

/// One tracker cell. Empty fields carry their sentinels (-1 / PatternNote.empty).
class PatternCell {
  final int note;         // semitone index or a PatternNote sentinel
  final int instrument;   // -1 = none
  final int volume;       // -1 = none, else 0..255
  final List<PatternFx> fx;
  const PatternCell({
    required this.note,
    required this.instrument,
    required this.volume,
    required this.fx,
  });
  static const PatternCell blank =
      PatternCell(note: -1, instrument: -1, volume: -1, fx: []);
}

/// Whole-song structure for the pattern visualizer, fetched once at load.
class PatternSong {
  final int numChannels;
  /// Sequence (order) list — each entry is a pattern index; a pattern may repeat.
  final List<int> order;
  /// Row count per pattern index.
  final List<int> patternRows;
  /// Cells per pattern index, laid out [row * numChannels + channel].
  final List<List<PatternCell>> patterns;
  const PatternSong({
    required this.numChannels,
    required this.order,
    required this.patternRows,
    required this.patterns,
  });

  int get numOrders => order.length;
  int get numPatterns => patterns.length;
}

// ---------------------------------------------------------------------------
// RewampAudio public API
// ---------------------------------------------------------------------------

/// One playback output device (desktop route picker).
class AudioOutputDevice {
  final int    index;      // pass to setOutputDevice
  final String name;
  final bool   isDefault;  // the system default output
  final bool   selected;   // explicitly picked earlier this session

  const AudioOutputDevice({
    required this.index,
    required this.name,
    this.isDefault = false,
    this.selected  = false,
  });
}

class RewampAudio {
  static RewampAudio? _instance;
  factory RewampAudio() => _instance ??= RewampAudio._();

  late final DynamicLibrary _lib;

  late final _InitDart        _init;
  late final _UninitDart      _uninit;
  late final _SetDataDirDart  _setDataDir;
  late final _LoadFileDart    _loadFile;
  late final _VoidDart        _unload;
  late final _SimpleDart      _play;
  late final _SimpleDart      _pause;
  late final _SimpleDart      _deviceSuspend;
  late final _SimpleDart      _stop;
  late final _IsPlayingDart   _isPlaying;
  late final _GetDoubleDart   _getPosition;
  late final _GetDoubleDart   _getDuration;
  _GetDoubleDart?       _silentSecondsFn;
  _VizClearArtworkDart? _resetSilenceFn; // void Function()
  late final _SeekDart        _seek;
  _SetVolumeDart?       _setVolumeFn;
  _SetForcedLoopDart?   _setForcedLoopFn;
  _HasNativeLoopDart?   _hasNativeLoopFn;
  late final _BackendNameDart _backendName;
  _TrackMessageDart? _trackMessageFn;
  _TrackArtworkDart? _trackArtworkFn;
  _TrackArtworkMimeDart? _trackArtworkMimeFn;
  _BytesOutDart? _omptActiveInstrFn;
  _TrackMessageDart? _tagTitleFn;
  _TrackMessageDart? _tagArtistFn;
  _TrackMessageDart? _tagAlbumFn;
  _SetDataDirDart?   _setMidiSoundfontFn;
  _TrackMessageDart?  _outputDevicesFn;
  _TrackMessageDart?  _loadedFilesFn;
  int Function(int)?  _setOutputDeviceFn;

  static const int waveformCount = 256;

  _GetWaveformDart? _getWaveformFn;
  Pointer<Float>?   _wfLeft;
  Pointer<Float>?   _wfRight;

  // Visualization (GL backend — optional, iOS+ANGLE only for now).
  _VizInitDart?              _vizInitFn;
  _VizRenderDart?            _vizRenderFn;
  _VizUninitDart?            _vizUninitFn;
  // GPU/Flutter-texture path (MetalANGLE, iOS/macOS).
  int Function()?            _devReqPeriodFn;
  _VizRegisterDart?          _vizRegisterFn;
  _ScopeRegisterDart?        _scopeRegisterFn;
  _ScopeRenderAndNotifyDart? _scopeRenderAndNotifyFn;
  _ScopeRegisterDart?        _notevizRegisterFn;
  _ScopeRenderAndNotifyDart? _notevizRenderAndNotifyFn;
  void Function(double, double)? _notevizSetRangeFn;
  void Function()?               _notevizSetAutoFn;
  int Function()?                _notevizIsManualFn;
  double Function()?             _notevizRangeLoFn;
  double Function()?             _notevizRangeHiFn;
  _ScopeRegisterDart?        _patternvizRegisterFn;
  _ScopeRenderAndNotifyDart? _patternvizRenderAndNotifyFn;
  void Function(int, int, int, int)? _patternvizSetOptionsFn;
  void Function(double)?     _patternvizSetXScrollFn;
  void Function(double, int)? _patternvizSetLayoutFn;
  void Function(double)?     _patternvizSetPixelScaleFn;
  double Function()?         _patternvizFutureSecsFn;
  void Function(int)?        _patternvizOpaqueBgFn;
  _ScopeRegisterDart?        _spectrumRegisterFn;
  _ScopeRenderAndNotifyDart? _spectrumRenderAndNotifyFn;
  _ScopeRegisterDart?        _projectmRegisterFn;
  bool                       _projectmAvailable = false;
  _ScopeRenderAndNotifyDart? _projectmRenderAndNotifyFn;
  _ScopeRenderAndNotifyDart? _projectmNextPresetFn;
  _ScopeRenderAndNotifyDart? _projectmPrevPresetFn;
  void Function(int, int)?   _projectmSetModeFn;
  void Function(int)?        _projectmSetActiveFn;
  void Function(int, int, int, double, double, int, int, int, double, int,
      double, double, int, int, int)? _projectmSetParamsFn;
  int Function()?            _projectmTransitionCountFn;
  int Function()?            _projectmSlowVerdictFn;
  int Function()?            _projectmPresetSerialFn;
  Pointer<Utf8> Function()?  _projectmPresetNameFn;
  Pointer<Utf8> Function()?  _projectmPresetPathFn;
  int Function()?            _projectmPresetCountFn;
  int Function()?            _projectmUsesMouseFn;
  void Function(Pointer<Utf8>, int)? _projectmSetPlaylistFn;
  void Function(double, double, int, int)? _projectmSetMouseFn;
  void Function(Pointer<Utf8>)? _projectmSetTextureDirsFn;
  _VizSetArtworkDart?        _vizSetArtworkFn;
  _VizSetArtworkOpacDart?    _vizSetArtworkOpacFn;
  _VizSetFrameTimeDart?      _vizSetFrameTimeFn;
  _VizClearArtworkDart?      _vizClearArtworkFn;
  _ScopeSetGridDart?         _scopeSetGridFn;
  _SetLineWidthDart?         _setLineWidthFn;
  _SetCrtFlagsDart?          _setCrtFlagsFn;
  _SetColorDart?             _setScopeColorFn;
  _SetColorDart?             _setStereoMonoFn;
  _SetColorDart?             _setStereoLeftFn;
  _SetColorDart?             _setStereoRightFn;
  _SetBicolorDart?           _setStereoBicolorFn;
  _SetBicolorDart?           _setSpectrumPaletteFn;
  _NotesWindowDart?          _notesWindowFn;
  _NotesVcDart?              _notesVcFn;
  _NotesLeadDart?            _notesLeadFn;
  _PatSupportedDart?         _patSupportedFn;
  _PatSongInfoDartFn?        _patSongInfoFn;
  _PatOrderDart?             _patOrderFn;
  _PatNumRowsDart?           _patNumRowsFn;
  _PatGetDart?               _patGetFn;
  _PatCursorDart?            _patCursorFn;
  _SetBicolorDart?           _setLookaheadFn;    // void(int)
  _VizSetFrameTimeDart?      _setLookaheadSecsFn; // void(double)
  _SetBicolorDart?           _setNotePaletteFn;  // void(int)
  _SetBicolorDart?           _setNoteStyleFn;    // void(int)
  _VizResizeRegisterDart?    _vizResizeRegisterFn;
  _VizRenderAndNotifyDart?   _vizRenderAndNotifyFn;
  _VizUnregisterDart?        _vizUnregisterFn;
  void Function(Pointer<Utf8>, Pointer<Utf8>, double)? _setEngineParamFn;
  int _vizWidth  = 0;
  int _vizHeight = 0;

  // Per-channel data (libvgm oscilloscope / piano-roll).
  _ChannelCountDart?    _channelCountFn;
  _ChannelBufDart?      _channelBufFn;
  _ChannelBufTrigDart?  _channelBufTrigFn;
  _ChannelFreqDart?     _channelFreqFn;
  _ChannelVolDart?          _channelVolFn;
  _ChannelWritePtrDart?     _channelWritePtrFn;
  static const int channelBufSize = 512 * 4 * 2; /* SOUND_BUFFER_SIZE_SAMPLE*4*2 */

  // Voice / chipset grouping + muting.
  _VoidRetIntDart? _voiceCountFn;
  _VoidRetIntDart? _voiceCountRawFn;
  _NameDart?       _voiceNameFn;
  _IntRetIntDart?  _voiceChipFn;
  _VoidRetIntDart? _chipCountFn;
  _NameDart?       _chipNameFn;
  _IntRetIntDart?  _chipVoiceStartFn;
  _IntRetIntDart?  _chipVoiceCountFn;
  _GetMaskDart?    _getMuteMaskFn;
  _GetMaskDart?    _underrunCountFn;
  _GetMaskDart?    _underrunFramesFn;
  _GetMaskDart?    _slowReadFn;
  _GetMaskDart?    _lateReadFn;
  _GetMaskDart?    _maxGapFn;
  _GetMaskDart?    _devLateFn;
  _GetMaskDart?    _devMaxGapFn;
  _GetMaskDart?    _devMaxBusyFn;
  _IsPlayingDart?  _devPeriodFramesFn;
  _IsPlayingDart?  _devPeriodsFn;
  _IsPlayingDart?  _devSampleRateFn;
  _SetMaskDart?    _setMuteMaskFn;

  late final _SetPreferredPluginDart _setPreferredPluginFn;
  late final _ProbeSubsongDart    _probeSubsongCount;
  _ProbeSubsongDart?     _canPlayFn;
  _ProbeGetTitleDart?    _probeGetTitleFn;
  _ProbeGetDurationDart? _probeGetDurationFn;
  _SimpleDart?           _probeSubsongBaseFn;
  _ExtractArchiveDart?   _extractArchiveFn;
  _ExtractLastErrorDart? _extractLastErrorFn;
  _SidMd5Dart?     _sidMd5Fn;
  _IsPlayingDart?  _isSeekingFn;
  _GetDoubleDart?  _seekProgressFn;

  RewampAudio._() {
    _lib = _loadLibrary();

    _init        = _lib.lookupFunction<_InitNative,        _InitDart>       ('rewamp_init');
    _uninit      = _lib.lookupFunction<_UninitNative,      _UninitDart>     ('rewamp_uninit');
    _setDataDir  = _lib.lookupFunction<_SetDataDirNative,  _SetDataDirDart> ('rewamp_set_data_dir');
    _loadFile    = _lib.lookupFunction<_LoadFileNative,    _LoadFileDart>   ('rewamp_load_file');
    _unload      = _lib.lookupFunction<_VoidNative,        _VoidDart>       ('rewamp_unload');
    _play        = _lib.lookupFunction<_SimpleNative,      _SimpleDart>     ('rewamp_play');
    _pause       = _lib.lookupFunction<_SimpleNative,      _SimpleDart>     ('rewamp_pause');
    _deviceSuspend = _lib.lookupFunction<_SimpleNative,    _SimpleDart>     ('rewamp_device_suspend');
    _stop        = _lib.lookupFunction<_SimpleNative,      _SimpleDart>     ('rewamp_stop');
    _isPlaying   = _lib.lookupFunction<_IsPlayingNative,   _IsPlayingDart>  ('rewamp_is_playing');
    _getPosition = _lib.lookupFunction<_GetDoubleNative,   _GetDoubleDart>  ('rewamp_get_position_seconds');
    _getDuration = _lib.lookupFunction<_GetDoubleNative,   _GetDoubleDart>  ('rewamp_get_duration_seconds');
    try {
      _silentSecondsFn = _lib.lookupFunction<_GetDoubleNative, _GetDoubleDart>('rewamp_silent_seconds');
      _resetSilenceFn  = _lib.lookupFunction<_VizClearArtworkNative, _VizClearArtworkDart>('rewamp_reset_silence');
    } catch (_) {
      debugLog('rewamp_audio: silence-detection functions not found');
    }
    _seek        = _lib.lookupFunction<_SeekNative,        _SeekDart>       ('rewamp_seek_seconds');
    try {
      _setVolumeFn = _lib.lookupFunction<_SetVolumeNative, _SetVolumeDart>('rewamp_set_volume');
    } catch (_) {
      debugLog('rewamp_audio: rewamp_set_volume not found — forced fadeout disabled');
    }
    try {
      _setForcedLoopFn = _lib.lookupFunction<_SetForcedLoopNative, _SetForcedLoopDart>('rewamp_set_forced_loop');
      _hasNativeLoopFn = _lib.lookupFunction<_HasNativeLoopNative, _HasNativeLoopDart>('rewamp_has_native_loop_support');
    } catch (_) {
      debugLog('rewamp_audio: native forced-loop functions not found');
    }
    _backendName       = _lib.lookupFunction<_BackendNameNative,  _BackendNameDart> ('rewamp_get_backend_name');
    try {
      _trackMessageFn  = _lib.lookupFunction<_TrackMessageNative, _TrackMessageDart>('rewamp_track_message');
    } catch (_) {}
    try {
      _trackArtworkFn = _lib.lookupFunction<_TrackArtworkNative, _TrackArtworkDart>('rewamp_track_artwork');
      _trackArtworkMimeFn = _lib.lookupFunction<_TrackArtworkMimeNative, _TrackArtworkMimeDart>('rewamp_track_artwork_mime');
      _setMidiSoundfontFn = _lib.lookupFunction<_SetDataDirNative, _SetDataDirDart>('rewamp_midi_set_soundfont');
      _omptActiveInstrFn = _lib.lookupFunction<_BytesOutNative, _BytesOutDart>('rewamp_openmpt_active_instruments');
      _tagTitleFn  = _lib.lookupFunction<_TrackMessageNative, _TrackMessageDart>('rewamp_tag_title');
      _tagArtistFn = _lib.lookupFunction<_TrackMessageNative, _TrackMessageDart>('rewamp_tag_artist');
      _tagAlbumFn  = _lib.lookupFunction<_TrackMessageNative, _TrackMessageDart>('rewamp_tag_album');
    } catch (_) {}
    try {
      _outputDevicesFn = _lib.lookupFunction<_TrackMessageNative, _TrackMessageDart>('rewamp_output_devices_json');
      _setOutputDeviceFn = _lib.lookupFunction<Int32 Function(Int32), int Function(int)>('rewamp_set_output_device');
    } catch (_) {/* older native lib — output picker hidden */}
    _setPreferredPluginFn = _lib.lookupFunction<_SetPreferredPluginNative, _SetPreferredPluginDart>('rewamp_registry_set_preferred_plugin');
      try {
        _setEngineParamFn = _lib.lookupFunction<
            Void Function(Pointer<Utf8>, Pointer<Utf8>, Double),
            void Function(Pointer<Utf8>, Pointer<Utf8>, double)>('rewamp_set_engine_param');
      } catch (_) {/* older native lib */}
    try {
      _loadedFilesFn = _lib.lookupFunction<_TrackMessageNative, _TrackMessageDart>(
          'rewamp_loaded_files_json');
    } catch (_) {/* binaire natif antérieur — le panneau ⓘ n'a pas la section */}
    _probeSubsongCount = _lib.lookupFunction<_ProbeSubsongNative, _ProbeSubsongDart>('rewamp_probe_subsong_count');

    // Optionnel: un binaire natif antérieur ne l'a pas. L'appelant retombe
    // alors sur son propre classement (voir RewampDb._findExtractedAudio).
    try {
      _canPlayFn = _lib.lookupFunction<_ProbeSubsongNative, _ProbeSubsongDart>(
          'rewamp_can_play');
    } catch (_) {
      debugLog('rewamp_audio: rewamp_can_play not found — playability check disabled');
    }

    try {
      _probeGetTitleFn    = _lib.lookupFunction<_ProbeGetTitleNative,    _ProbeGetTitleDart>   ('rewamp_probe_get_title');
      _probeGetDurationFn = _lib.lookupFunction<_ProbeGetDurationNative, _ProbeGetDurationDart>('rewamp_probe_get_duration_ms');
    } catch (_) {
      debugLog('rewamp_audio: rewamp_probe_get_title not found — per-subsong metadata disabled');
    }

    try {
      _probeSubsongBaseFn = _lib.lookupFunction<_SimpleNative, _SimpleDart>('rewamp_probe_subsong_base');
    } catch (_) {
      // Older engine without an absolute base → treat as 0 (indices already absolute).
    }

    try {
      _extractArchiveFn   = _lib.lookupFunction<_ExtractArchiveNative,   _ExtractArchiveDart>  ('rewamp_extract_archive');
      _extractLastErrorFn = _lib.lookupFunction<_ExtractLastErrorNative, _ExtractLastErrorDart>('rewamp_extract_last_error');
    } catch (_) {
      debugLog('rewamp_audio: rewamp_extract_archive not found — archive extraction disabled');
    }

    try {
      _sidMd5Fn = _lib.lookupFunction<_SidMd5Native, _SidMd5Dart>('rewamp_sid_md5');
    } catch (_) {
      debugLog('rewamp_audio: rewamp_sid_md5 not found — SID MD5 disabled');
    }

    try {
      _isSeekingFn   = _lib.lookupFunction<_IsPlayingNative,  _IsPlayingDart> ('rewamp_is_seeking');
      _seekProgressFn = _lib.lookupFunction<_GetDoubleNative, _GetDoubleDart>  ('rewamp_seek_progress_seconds');
    } catch (_) {
      debugLog('rewamp_audio: rewamp_is_seeking not found — seek progress disabled');
    }

    try {
      _getWaveformFn = _lib.lookupFunction<_GetWaveformNative, _GetWaveformDart>('rewamp_get_waveform');
      _wfLeft  = calloc<Float>(waveformCount);
      _wfRight = calloc<Float>(waveformCount);
    } catch (_) {
      debugLog('rewamp_audio: rewamp_get_waveform not found — waveform disabled');
    }

    try {
      _vizInitFn   = _lib.lookupFunction<_VizInitNative,   _VizInitDart>  ('rewamp_viz_init');
      _vizRenderFn = _lib.lookupFunction<_VizRenderNative, _VizRenderDart>('rewamp_viz_render');
      _vizUninitFn = _lib.lookupFunction<_VizUninitNative, _VizUninitDart>('rewamp_viz_uninit');
      try {
        _vizRegisterFn        = _lib.lookupFunction<_VizRegisterNative,        _VizRegisterDart>       ('rewamp_viz_register');
        _scopeRegisterFn      = _lib.lookupFunction<_ScopeRegisterNative,      _ScopeRegisterDart>     ('rewamp_scope_register');
        _scopeRenderAndNotifyFn = _lib.lookupFunction<_ScopeRenderAndNotifyNative, _ScopeRenderAndNotifyDart>('rewamp_scope_render_and_notify');
        _notevizRegisterFn      = _lib.lookupFunction<_ScopeRegisterNative,      _ScopeRegisterDart>     ('rewamp_noteviz_register');
        _notevizRenderAndNotifyFn = _lib.lookupFunction<_ScopeRenderAndNotifyNative, _ScopeRenderAndNotifyDart>('rewamp_noteviz_render_and_notify');
        _notevizSetRangeFn = _lib.lookupFunction<Void Function(Float, Float),
            void Function(double, double)>('rewamp_noteviz_set_range');
        _notevizSetAutoFn = _lib.lookupFunction<Void Function(),
            void Function()>('rewamp_noteviz_set_auto');
        _notevizIsManualFn = _lib.lookupFunction<Int32 Function(),
            int Function()>('rewamp_noteviz_is_manual');
        _notevizRangeLoFn = _lib.lookupFunction<Float Function(),
            double Function()>('rewamp_noteviz_range_lo');
        _notevizRangeHiFn = _lib.lookupFunction<Float Function(),
            double Function()>('rewamp_noteviz_range_hi');
        try {
          _patternvizRegisterFn      = _lib.lookupFunction<_ScopeRegisterNative,      _ScopeRegisterDart>     ('rewamp_patternviz_register');
          _patternvizRenderAndNotifyFn = _lib.lookupFunction<_ScopeRenderAndNotifyNative, _ScopeRenderAndNotifyDart>('rewamp_patternviz_render_and_notify');
        } catch (_) {/* GL pattern renderer not in this build */}
        try {
          _spectrumRegisterFn        = _lib.lookupFunction<_ScopeRegisterNative,      _ScopeRegisterDart>     ('rewamp_spectrum_register');
          _spectrumRenderAndNotifyFn = _lib.lookupFunction<_ScopeRenderAndNotifyNative, _ScopeRenderAndNotifyDart>('rewamp_spectrum_render_and_notify');
        } catch (_) {/* spectrum renderer not in this build (stale binary) */}
        // projectM (mode 3). Two symbol groups, looked up SEPARATELY:
        //   - the engine's own (rewamp_projectm_render.cpp) — present wherever
        //     projectM is compiled, Apple AND Android;
        //   - register / render_and_notify — the Flutter-Texture driver, which
        //     only the Apple viz plugin defines. Android renders projectM through
        //     the SurfaceView PlatformView (mode 3) and needs neither.
        // They used to share one try block, so on Android the very first (Apple-
        // only) lookup threw and took the whole preset API down with it.
        try {
          _projectmNextPresetFn = _lib.lookupFunction<_ScopeRenderAndNotifyNative, _ScopeRenderAndNotifyDart>('rewamp_projectm_next_preset');
          _projectmPrevPresetFn = _lib.lookupFunction<_ScopeRenderAndNotifyNative, _ScopeRenderAndNotifyDart>('rewamp_projectm_prev_preset');
          _projectmSetModeFn = _lib.lookupFunction<Void Function(Int32, Int32), void Function(int, int)>('rewamp_projectm_set_mode');
          _projectmSetActiveFn = _lib.lookupFunction<Void Function(Int32), void Function(int)>('rewamp_projectm_set_active');
          _projectmSetParamsFn = _lib.lookupFunction<
              Void Function(Int32, Int32, Int32, Double, Double, Int32, Int32,
                  Int32, Double, Int32, Double, Double, Int32, Int32, Int32),
              void Function(int, int, int, double, double, int, int, int,
                  double, int, double, double, int, int, int)>('rewamp_projectm_set_params');
          _projectmPresetSerialFn = _lib.lookupFunction<Int32 Function(), int Function()>('rewamp_projectm_preset_serial');
          _projectmPresetNameFn = _lib.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>('rewamp_projectm_preset_name');
          _projectmAvailable = true;
        } catch (_) {/* projectM not built on this platform */}
        // Preset-source API (packs / playlists). Own try: an app running against
        // a stale native binary keeps the older projectM API above.
        try {
          _projectmPresetPathFn = _lib.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>('rewamp_projectm_preset_path');
          _projectmPresetCountFn = _lib.lookupFunction<Int32 Function(), int Function()>('rewamp_projectm_preset_count');
          _projectmUsesMouseFn = _lib.lookupFunction<Int32 Function(), int Function()>('rewamp_projectm_preset_uses_mouse');
          _projectmSetPlaylistFn = _lib.lookupFunction<Void Function(Pointer<Utf8>, Int32), void Function(Pointer<Utf8>, int)>('rewamp_projectm_set_playlist');
          _projectmSetTextureDirsFn = _lib.lookupFunction<Void Function(Pointer<Utf8>), void Function(Pointer<Utf8>)>('rewamp_projectm_set_texture_dirs');
          _projectmSetMouseFn = _lib.lookupFunction<
              Void Function(Float, Float, Int32, Int32),
              void Function(double, double, int, int)>('rewamp_projectm_set_mouse');
          _projectmTransitionCountFn = _lib.lookupFunction<Int32 Function(), int Function()>('rewamp_projectm_transition_count');
          _projectmSlowVerdictFn = _lib.lookupFunction<Int32 Function(), int Function()>('rewamp_projectm_take_slow_verdict');
        } catch (_) {/* preset-source API not in this build */}
        try {
          _projectmRegisterFn       = _lib.lookupFunction<_ScopeRegisterNative,      _ScopeRegisterDart>     ('rewamp_projectm_register');
          _projectmRenderAndNotifyFn = _lib.lookupFunction<_ScopeRenderAndNotifyNative, _ScopeRenderAndNotifyDart>('rewamp_projectm_render_and_notify');
        } catch (_) {/* Texture path — Apple only; Android uses the PlatformView */}
        _vizResizeRegisterFn  = _lib.lookupFunction<_VizResizeRegisterNative,  _VizResizeRegisterDart> ('rewamp_viz_resize_register');
        _vizRenderAndNotifyFn = _lib.lookupFunction<_VizRenderAndNotifyNative, _VizRenderAndNotifyDart>('rewamp_viz_render_and_notify');
        _vizUnregisterFn      = _lib.lookupFunction<_VizUnregisterNative,      _VizUnregisterDart>     ('rewamp_viz_unregister');
      } catch (_) {
        // GPU texture path not available on this platform (Android/desktop).
      }
      try {
        _vizSetArtworkFn    = _lib.lookupFunction<_VizSetArtworkNative,     _VizSetArtworkDart>    ('rewamp_viz_set_artwork');
        _vizSetArtworkOpacFn = _lib.lookupFunction<_VizSetArtworkOpacNative, _VizSetArtworkOpacDart>('rewamp_viz_set_artwork_opacity');
        _vizSetFrameTimeFn   = _lib.lookupFunction<_VizSetFrameTimeNative,   _VizSetFrameTimeDart>('rewamp_viz_set_frame_time');
        _vizClearArtworkFn  = _lib.lookupFunction<_VizClearArtworkNative,   _VizClearArtworkDart>  ('rewamp_viz_clear_artwork');
      } catch (_) {
        debugLog('rewamp_audio: artwork functions not found');
      }
      try {
        _scopeSetGridFn = _lib.lookupFunction<_ScopeSetGridNative, _ScopeSetGridDart>('rewamp_scope_set_grid');
      } catch (_) {
        debugLog('rewamp_audio: rewamp_scope_set_grid not found');
      }
      try {
        _setLineWidthFn = _lib.lookupFunction<_SetLineWidthNative, _SetLineWidthDart>('rewamp_set_viz_line_width');
      } catch (_) {
        debugLog('rewamp_audio: rewamp_set_viz_line_width not found');
      }
      try {
        _setCrtFlagsFn = _lib.lookupFunction<_SetCrtFlagsNative, _SetCrtFlagsDart>('rewamp_set_crt_flags');
      } catch (_) {
        debugLog('rewamp_audio: rewamp_set_crt_flags not found');
      }
      try {
        _setScopeColorFn    = _lib.lookupFunction<_SetColorNative, _SetColorDart>('rewamp_set_scope_color');
        _setStereoMonoFn    = _lib.lookupFunction<_SetColorNative, _SetColorDart>('rewamp_set_stereo_mono_color');
        _setStereoLeftFn    = _lib.lookupFunction<_SetColorNative, _SetColorDart>('rewamp_set_stereo_left_color');
        _setStereoRightFn   = _lib.lookupFunction<_SetColorNative, _SetColorDart>('rewamp_set_stereo_right_color');
        _setStereoBicolorFn = _lib.lookupFunction<_SetBicolorNative, _SetBicolorDart>('rewamp_set_stereo_bicolor');
        _setSpectrumPaletteFn = _lib.lookupFunction<_SetBicolorNative, _SetBicolorDart>('rewamp_set_spectrum_palette');
      } catch (_) {
        debugLog('rewamp_audio: scope color functions not found');
      }
      try {
        _notesWindowFn = _lib.lookupFunction<_NotesWindowNative, _NotesWindowDart>('rewamp_notes_window');
        _notesVcFn     = _lib.lookupFunction<_NotesVcNative, _NotesVcDart>('rewamp_notes_voice_count');
        try {
          _patSupportedFn = _lib.lookupFunction<_PatSupportedNative, _PatSupportedDart>('rewamp_pattern_supported');
          _patSongInfoFn  = _lib.lookupFunction<_PatSongInfoNativeFn, _PatSongInfoDartFn>('rewamp_pattern_song_info');
          _patOrderFn     = _lib.lookupFunction<_PatOrderNative, _PatOrderDart>('rewamp_pattern_order');
          _patNumRowsFn   = _lib.lookupFunction<_PatNumRowsNative, _PatNumRowsDart>('rewamp_pattern_num_rows');
          _patGetFn       = _lib.lookupFunction<_PatGetNative, _PatGetDart>('rewamp_pattern_get');
          _patCursorFn    = _lib.lookupFunction<_PatCursorNative, _PatCursorDart>('rewamp_pattern_cursor');
        } catch (_) {
          debugLog('rewamp_audio: pattern-view API not found');
        }
        _notesLeadFn   = _lib.lookupFunction<_NotesLeadNative, _NotesLeadDart>('rewamp_notes_lead_seconds');
        _setLookaheadFn = _lib.lookupFunction<_SetBicolorNative, _SetBicolorDart>('rewamp_set_lookahead');
        _setLookaheadSecsFn = _lib.lookupFunction<_VizSetFrameTimeNative, _VizSetFrameTimeDart>('rewamp_set_lookahead_seconds');
        _setNotePaletteFn = _lib.lookupFunction<_SetBicolorNative, _SetBicolorDart>('rewamp_set_note_palette');
        _setNoteStyleFn   = _lib.lookupFunction<_SetBicolorNative, _SetBicolorDart>('rewamp_set_note_style');
        try {
          _patternvizSetOptionsFn = _lib.lookupFunction<Void Function(Int32, Int32, Int32, Int32),
              void Function(int, int, int, int)>('rewamp_patternviz_set_options');
          _patternvizSetXScrollFn = _lib.lookupFunction<Void Function(Float),
              void Function(double)>('rewamp_patternviz_set_xscroll');
          _patternvizSetLayoutFn = _lib.lookupFunction<Void Function(Float, Int32),
              void Function(double, int)>('rewamp_patternviz_set_layout');
          _patternvizSetPixelScaleFn = _lib.lookupFunction<Void Function(Float),
              void Function(double)>('rewamp_patternviz_set_pixel_scale');
          _patternvizFutureSecsFn = _lib.lookupFunction<Double Function(),
              double Function()>('rewamp_patternviz_future_seconds');
          _patternvizOpaqueBgFn = _lib.lookupFunction<Void Function(Int32),
              void Function(int)>('rewamp_patternviz_set_opaque_bg');
        } catch (_) {/* GL pattern renderer not in this build */}
      } catch (_) {
        debugLog('rewamp_audio: notes timeline functions not found');
      }
    } catch (_) {
      debugLog('rewamp_audio: rewamp_viz_* not found — GL visualizer disabled');
    }

    try {
      _channelCountFn   = _lib.lookupFunction<_ChannelCountNative,   _ChannelCountDart>  ('rewamp_channel_count');
      _channelBufFn     = _lib.lookupFunction<_ChannelBufNative,     _ChannelBufDart>    ('rewamp_channel_buf');
      _channelBufTrigFn = _lib.lookupFunction<_ChannelBufTrigNative, _ChannelBufTrigDart>('rewamp_channel_buf_triggered');
      _channelFreqFn    = _lib.lookupFunction<_ChannelFreqNative,    _ChannelFreqDart>   ('rewamp_channel_freq_hz');
      _channelVolFn         = _lib.lookupFunction<_ChannelVolNative,      _ChannelVolDart>     ('rewamp_channel_volume');
      _channelWritePtrFn    = _lib.lookupFunction<_ChannelWritePtrNative, _ChannelWritePtrDart>('rewamp_channel_write_ptr');
    } catch (_) {
      debugLog('rewamp_audio: rewamp_channel_* not found — per-channel data disabled');
    }

    try {
      _voiceCountFn     = _lib.lookupFunction<_VoidRetIntNative, _VoidRetIntDart>('rewamp_voice_count');
      _voiceCountRawFn  = _lib.lookupFunction<_VoidRetIntNative, _VoidRetIntDart>('rewamp_voice_count_raw');
      _voiceNameFn      = _lib.lookupFunction<_NameNative,       _NameDart>      ('rewamp_voice_name');
      _voiceChipFn      = _lib.lookupFunction<_IntRetIntNative,  _IntRetIntDart> ('rewamp_voice_chip');
      _chipCountFn      = _lib.lookupFunction<_VoidRetIntNative, _VoidRetIntDart>('rewamp_chip_count');
      _chipNameFn       = _lib.lookupFunction<_NameNative,       _NameDart>      ('rewamp_chip_name');
      _chipVoiceStartFn = _lib.lookupFunction<_IntRetIntNative,  _IntRetIntDart> ('rewamp_chip_voice_start');
      _chipVoiceCountFn = _lib.lookupFunction<_IntRetIntNative,  _IntRetIntDart> ('rewamp_chip_voice_count');
      _getMuteMaskFn    = _lib.lookupFunction<_GetMaskNative,    _GetMaskDart>   ('rewamp_get_voice_mute_mask');
      _underrunCountFn  = _lib.lookupFunction<_GetMaskNative,    _GetMaskDart>   ('rewamp_underrun_count');
      _underrunFramesFn = _lib.lookupFunction<_GetMaskNative,    _GetMaskDart>   ('rewamp_underrun_frames');
      _slowReadFn       = _lib.lookupFunction<_GetMaskNative,    _GetMaskDart>   ('rewamp_slow_read_count');
      _lateReadFn       = _lib.lookupFunction<_GetMaskNative,    _GetMaskDart>   ('rewamp_late_read_count');
      _maxGapFn         = _lib.lookupFunction<_GetMaskNative,    _GetMaskDart>   ('rewamp_max_gap_us');
      _devLateFn        = _lib.lookupFunction<_GetMaskNative,    _GetMaskDart>   ('rewamp_device_late_count');
      _devReqPeriodFn   = _lib.lookupFunction<Int32 Function(), int Function()>('rewamp_device_requested_period_ms');
      _devMaxGapFn      = _lib.lookupFunction<_GetMaskNative,    _GetMaskDart>   ('rewamp_device_max_gap_us');
      _devMaxBusyFn     = _lib.lookupFunction<_GetMaskNative,    _GetMaskDart>   ('rewamp_device_max_busy_us');
      _devPeriodFramesFn= _lib.lookupFunction<_IsPlayingNative,  _IsPlayingDart> ('rewamp_device_period_frames');
      _devPeriodsFn     = _lib.lookupFunction<_IsPlayingNative,  _IsPlayingDart> ('rewamp_device_periods');
      _devSampleRateFn  = _lib.lookupFunction<_IsPlayingNative,  _IsPlayingDart> ('rewamp_device_sample_rate');
      _setMuteMaskFn    = _lib.lookupFunction<_SetMaskNative,    _SetMaskDart>   ('rewamp_set_voice_mute_mask');
    } catch (_) {
      debugLog('rewamp_audio: rewamp_voice_*/chip_* not found — voice muting disabled');
    }
  }

  bool init() => _init() == 0;

  /// Register the root directory holding bundled library assets (C64 ROMs,
  /// future soundfonts, ...). Plugins load files relative to it.
  void setDataDir(String path) {
    final p = path.toNativeUtf8();
    try {
      _setDataDir(p);
    } finally {
      calloc.free(p);
    }
  }

  void uninit() {
    vizUninit();
    final l = _wfLeft;
    final r = _wfRight;
    if (l != null) calloc.free(l);
    if (r != null) calloc.free(r);
    _uninit();
  }

  bool loadFile(String path) {
    final pathPtr = path.toNativeUtf8();
    final result = _loadFile(pathPtr) == 0;
    calloc.free(pathPtr);
    return result;
  }

  void unload() => _unload();

  bool play()  => _play()  == 0;
  bool pause() => _pause() == 0;
  bool stop()  => _stop()  == 0;

  /// Stops the audio DEVICE while paused (iOS Now Playing ignores rate=0 as
  /// long as the audio unit runs). Call shortly after [pause] (post-fade);
  /// no-op if playback resumed meanwhile. [play] restarts the device.
  bool deviceSuspend() => _deviceSuspend() == 0;

  bool   get isPlaying       => _isPlaying() != 0;
  double get positionSeconds => _getPosition();
  double get durationSeconds => _getDuration();

  /// Seconds of continuous silence at the output (0 while audio is present).
  double get silentSeconds => _silentSecondsFn?.call() ?? 0.0;
  void resetSilence() => _resetSilenceFn?.call();

  bool seek(double seconds) => _seek(seconds) == 0;

  /// Linear output gain (0.0–1.0). Used for the forced-loop fadeout; a no-op
  /// if the native symbol isn't available (older prebuilt lib).
  void setVolume(double volume) => _setVolumeFn?.call(volume);

  /// Snapshotted by the NEXT [loadFile] call: applied to the plugin's own
  /// native loop support if it has any (see [hasNativeLoopSupport] after
  /// loading), else left to the generic Dart-side fallback. When the plugin
  /// DOES support it and its single-pass length is known, the fadeout is
  /// ALSO handled natively (sample-accurate, in the C engine) — no Dart-side
  /// fadeout runs for that file either.
  /// mode: 0=off, 1=on (loop [count] times total), 2=infinite.
  /// baseDurationSeconds: the known single-pass length of the track (from
  /// server/DB catalogue), or 0 if unknown — lets native-loop plugins that
  /// can't derive their own base length (plain NSF) seed their loop math.
  void setForcedLoop(int mode, int count,
          {bool fadeoutEnabled = false, double fadeoutSeconds = 0,
           double baseDurationSeconds = 0}) =>
      _setForcedLoopFn?.call(mode, count, fadeoutEnabled ? 1 : 0, fadeoutSeconds,
          baseDurationSeconds);

  /// True if the file loaded by the last [loadFile] call has native loop
  /// support (its plugin claimed [setForcedLoop] natively) — the caller
  /// should skip its own generic loop/fadeout handling for this file.
  bool get hasNativeLoopSupport => (_hasNativeLoopFn?.call() ?? 0) != 0;

  String get backendName => _backendName().toDartString();

  /// Free-text metadata about the loaded file/subsong (tags, copyright,
  /// instruments…) — the Modizer "mod_message" equivalent, filled by each
  /// decoder plugin at open(). Empty when the backend exposes nothing.
  String get trackMessage {
    final fn = _trackMessageFn;
    if (fn == null) return '';
    // Tolerant decode: chip-era metadata (PSID headers, GD3, APE tags…) is
    // often Latin-1/PETSCII — a strict UTF-8 decode throws FormatException.
    final ptr = fn().cast<Uint8>();
    var len = 0;
    while (ptr[len] != 0) len++;
    return utf8.decode(ptr.asTypedList(len), allowMalformed: true);
  }

  /// Embedded cover picture of the loaded file (ID3v2 APIC / FLAC PICTURE /
  /// ogg METADATA_BLOCK_PICTURE), or null. Bytes are copied out of the
  /// engine-owned buffer (valid until the next load).
  Uint8List? get trackArtwork {
    final fn = _trackArtworkFn;
    if (fn == null) return null;
    final sizePtr = calloc<Int32>();
    try {
      final ptr = fn(sizePtr);
      final size = sizePtr.value;
      if (ptr == nullptr || size <= 0) return null;
      return Uint8List.fromList(ptr.asTypedList(size));
    } finally {
      calloc.free(sizePtr);
    }
  }

  /// MIME type of [trackArtwork] ("image/jpeg", "image/png", …) or ''.
  String get trackArtworkMime =>
      _trackArtworkMimeFn?.call().toDartString() ?? '';

  String _tagString(_TrackMessageDart? fn) {
    if (fn == null) return '';
    final ptr = fn().cast<Uint8>();
    var len = 0;
    while (ptr[len] != 0) len++;
    return utf8.decode(ptr.asTypedList(len), allowMalformed: true);
  }

  /// Structured tag fields parsed from the loaded file ('' when absent) —
  /// filled for miniaudio-fallback formats (mp3/flac/ogg/wav).
  String get tagTitle  => _tagString(_tagTitleFn);
  String get tagArtist => _tagString(_tagArtistFn);
  String get tagAlbum  => _tagString(_tagAlbumFn);

  /// Les fichiers que le décodage EN COURS a réellement ouverts: le fichier
  /// principal et les compagnons que le plugin a tirés (un `.psflib`, un
  /// `smpl.NOM`, un `.pdx`, une banque `.fmb`). Vide si le binaire natif est
  /// antérieur.
  ///
  /// C'est le PLUGIN qui les déclare, et lui seul le peut: le compagnon d'un
  /// format multi-fichiers ne se déduit pas du nom — un `.psflib` porte le nom
  /// du jeu, pas celui du morceau.
  List<({String name, int size})> loadedFiles() {
    final fn = _loadedFilesFn;
    if (fn == null) return const [];
    try {
      final j = jsonDecode(fn().toDartString());
      if (j is! List) return const [];
      return [
        for (final e in j)
          if (e is Map && (e['name'] ?? '').toString().isNotEmpty)
            (name: e['name'].toString(), size: (e['size'] as num?)?.toInt() ?? 0),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Playback output devices for the desktop route picker. Empty when the
  /// native lib predates the feature or enumeration failed.
  List<AudioOutputDevice> outputDevices() {
    final fn = _outputDevicesFn;
    if (fn == null) return const [];
    try {
      final raw = fn().toDartString();
      final j = jsonDecode(raw);
      if (j is! List) return const [];
      return [
        for (final e in j)
          if (e is Map)
            AudioOutputDevice(
              index:     (e['i'] as num?)?.toInt() ?? 0,
              name:      (e['name'] ?? '').toString(),
              isDefault: e['def'] == 1,
              selected:  e['sel'] == 1,
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Re-routes output to a device from the last [outputDevices] snapshot;
  /// -1 restores the system default (and default-device following).
  bool setOutputDevice(int index) =>
      (_setOutputDeviceFn?.call(index) ?? -1) == 0;

  /// Instruments (MOD: samples) currently sounding, per libopenmpt channel —
  /// 1-based numbers, VU-gated. Empty when not playing an openmpt module.
  Set<int> get openmptActiveInstruments {
    final fn = _omptActiveInstrFn;
    if (fn == null) return const {};
    final buf = calloc<Uint8>(64);
    try {
      final n = fn(buf, 64);
      final out = <int>{};
      for (var i = 0; i < n; i++) {
        if (buf[i] != 0) out.add(buf[i]);
      }
      return out;
    } finally {
      calloc.free(buf);
    }
  }

  /// Points the MIDI plugin at a SoundFont (.sf2). Without it the plugin
  /// falls back to <datadir>/soundfonts/default.sf2, and declines .mid
  /// files when neither exists.
  void setMidiSoundfont(String path) {
    final fn = _setMidiSoundfontFn;
    if (fn == null) return;
    final p = path.toNativeUtf8();
    fn(p);
    calloc.free(p);
  }

  /// Returns the number of subsongs in [path] (e.g. RSN/NSF/GBS) without
  /// loading it for playback.  Returns 1 for single-track files, 0 on error.
  /// Set the preferred plugin for a file extension (lowercase, no dot).
  /// Pass null to clear the override. The preferred plugin is used if it
  /// can handle the file (probe > 0), falling back to score-based selection.
  void setPreferredPlugin(String ext, String? pluginName) {
    final extPtr  = ext.toNativeUtf8();
    final namePtr = pluginName != null ? pluginName.toNativeUtf8() : nullptr;
    _setPreferredPluginFn(extPtr, namePtr as Pointer<Utf8>);
    calloc.free(extPtr);
    if (pluginName != null) calloc.free(namePtr);
  }

  /// Un greffon réclame-t-il ce fichier ? Question posée au REGISTRE
  /// (extension + en-tête, aucun décodage), donc valable pour tous les moteurs.
  ///
  /// ⚠️ Ne pas confondre avec [probeSubsongCount], qui est un compteur de
  /// SOUS-CHANSONS chaîné sur SID/KSS/openmpt/SNDH/sc68/GME et répond 0 pour
  /// tout le reste — Furnace, UADE, zxtune, AdPlug, la famille PSF, SunVox et
  /// les formats que seul libvgm joue. S'en servir comme test de jouabilité
  /// rejette un `.fur` parfaitement lisible et retient le `.vgm` d'à côté.
  ///
  /// `true` quand le binaire natif ne connaît pas encore l'export: l'appelant
  /// garde alors son propre classement plutôt que d'écarter des fichiers sains.
  bool canPlay(String path) {
    final fn = _canPlayFn;
    if (fn == null) return true;
    final ptr = path.toNativeUtf8();
    try {
      return fn(ptr) != 0;
    } finally {
      calloc.free(ptr);
    }
  }

  /// Also primes the per-subsong cache so [probeSubsongs] can be called next.
  int probeSubsongCount(String path) {
    final ptr = path.toNativeUtf8();
    try {
      return _probeSubsongCount(ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  /// Probes [path] and returns one [SubsongInfo] per subsong.
  /// Returns an empty list on failure.  For single-track files returns a list
  /// with one entry (title/duration may be empty/-1).
  List<SubsongInfo> probeSubsongs(String path) {
    final count = probeSubsongCount(path);
    if (count <= 0) return const [];
    final titleFn    = _probeGetTitleFn;
    final durationFn = _probeGetDurationFn;
    // Some formats number their subsongs from a non-zero base (KSS: trk_min).
    // ?subsong= wants the ABSOLUTE index, so shift the 0-based position by it.
    final base = _probeSubsongBaseFn?.call() ?? 0;
    return List.generate(count, (i) {
      final title = titleFn != null ? titleFn(i).toDartString() : '';
      final ms    = durationFn != null ? durationFn(i) : -1;
      return SubsongInfo(
        index:      i,
        filePath:   path,
        subsongIdx: base + i,
        title:      title.isEmpty ? null : title,
        durationMs: ms < 0 ? null : ms,
      );
    });
  }

  /// Extracts all files from [archivePath] (7z/zip/tar/lha/gz/bz2/xz/rar) into
  /// [destDir] (must already exist).  Files are flattened to basenames.
  /// Returns 0 on success, non-zero on failure or if libarchive is not compiled in.
  int extractArchive(String archivePath, String destDir) {
    final fn = _extractArchiveFn;
    if (fn == null) return -1;
    final pA = archivePath.toNativeUtf8(allocator: calloc);
    final pD = destDir.toNativeUtf8(allocator: calloc);
    try {
      return fn(pA, pD);
    } finally {
      calloc.free(pA);
      calloc.free(pD);
    }
  }

  /// Returns the libarchive error string from the last [extractArchive] call.
  /// Empty string on success or when libarchive is not compiled in.
  String extractLastError() {
    final fn = _extractLastErrorFn;
    if (fn == null) return 'rewamp_extract_last_error not linked';
    return fn().toDartString();
  }

  /// Returns the HVSC MD5 for a SID file (SidTune::createMD5New algorithm).
  /// Returns an empty string if the file cannot be opened or the SID plugin
  /// is not compiled in.  The path may contain a ?subsong=N suffix — it is
  /// stripped before opening.
  String sidMd5(String path) {
    final fn = _sidMd5Fn;
    if (fn == null) return '';
    final ptr = path.toNativeUtf8();
    try {
      final r = fn(ptr);
      if (r == nullptr) return '';
      return r.toDartString();
    } finally {
      calloc.free(ptr);
    }
  }

  /// Returns true while sid_seek() fast-forward loop is running.
  bool isSeeking() => (_isSeekingFn?.call() ?? 0) != 0;

  /// Seconds decoded so far in the current seek (for progress display).
  double seekProgressSeconds() => _seekProgressFn?.call() ?? 0.0;

  void getWaveform(Float32List leftOut, Float32List rightOut) {
    final fn = _getWaveformFn;
    final l  = _wfLeft;
    final r  = _wfRight;
    if (fn == null || l == null || r == null) return;
    fn(l, r, waveformCount);
    leftOut.setAll(0,  l.asTypedList(waveformCount));
    rightOut.setAll(0, r.asTypedList(waveformCount));
  }

  // ---------------------------------------------------------------------------
  // GL visualization API
  // ---------------------------------------------------------------------------

  /// True if the basic GL viz (CPU-readback path) is available.
  bool get vizAvailable => _vizInitFn != null;

  /// True if the GPU/Flutter-texture path is available (iOS/macOS MetalANGLE).
  /// Pushes one per-engine parameter (Settings → Moteurs). Applied by the
  /// plugin on the NEXT open (track change).
  void setEngineParam(String engine, String key, double value) {
    final fn = _setEngineParamFn;
    if (fn == null) return;
    final e = engine.toNativeUtf8();
    final k = key.toNativeUtf8();
    fn(e, k, value);
    calloc.free(e);
    calloc.free(k);
  }

  bool get vizGpuAvailable => _vizRegisterFn != null;

  /// GPU path: init GL + register FlutterTexture. Returns textureId (> 0) or
  /// a negative error code. [width]/[height] are physical pixels.
  int vizRegister(int width, int height) {
    final fn = _vizRegisterFn;
    if (fn == null) return -99;
    _vizWidth  = width;
    _vizHeight = height;
    return fn(width, height);
  }

  /// GPU path: resize IOSurface buffers when widget size changes.
  int vizResizeRegister(int width, int height) {
    final fn = _vizResizeRegisterFn;
    if (fn == null) return -99;
    _vizWidth  = width;
    _vizHeight = height;
    return fn(width, height);
  }

  /// GPU path: render one frame + notify Flutter. Call from Ticker at ~60 Hz.
  void vizRenderAndNotify() => _vizRenderAndNotifyFn?.call();

  /// GPU path: register multi-voice scope texture. Returns textureId (> 0) or error.
  int scopeRegister(int width, int height) {
    final fn = _scopeRegisterFn;
    if (fn == null) return -1;
    return fn(width, height);
  }

  void scopeRenderAndNotify() => _scopeRenderAndNotifyFn?.call();

  /// GPU path: register the scrolling-notation texture. Returns textureId or err.
  int notevizRegister(int width, int height) {
    final fn = _notevizRegisterFn;
    if (fn == null) return -1;
    return fn(width, height);
  }

  void notevizRenderAndNotify() => _notevizRenderAndNotifyFn?.call();

  /// Notes viz vertical range (log2 Hz). Setting a range switches the C
  /// renderer to MANUAL mode (auto-calibration frozen); [notevizSetAuto]
  /// returns to auto, easing from the manual view.
  void notevizSetRange(double lo, double hi) =>
      _notevizSetRangeFn?.call(lo, hi);
  void notevizSetAuto() => _notevizSetAutoFn?.call();
  bool get notevizIsManual => (_notevizIsManualFn?.call() ?? 0) != 0;
  double get notevizRangeLo => _notevizRangeLoFn?.call() ?? 4.5;
  double get notevizRangeHi => _notevizRangeHiFn?.call() ?? 12.5;

  /// GPU path: register the tracker-pattern texture. Returns textureId or err.
  int patternvizRegister(int width, int height) {
    final fn = _patternvizRegisterFn;
    if (fn == null) return -1;
    return fn(width, height);
  }

  void patternvizRenderAndNotify() => _patternvizRenderAndNotifyFn?.call();

  /// True when the GL pattern renderer is compiled into the engine (drives the
  /// widget's GPU-vs-CustomPaint choice; on Android the SurfaceView PlatformView
  /// renders it, so do NOT key this on the register fn — Apple-only).
  bool get hasPatternGl => _patternvizSetOptionsFn != null;

  /// GPU path: register the spectrum-analyzer texture. Returns textureId or err.
  int spectrumRegister(int width, int height) {
    final fn = _spectrumRegisterFn;
    if (fn == null) return -1;
    return fn(width, height);
  }

  void spectrumRenderAndNotify() => _spectrumRenderAndNotifyFn?.call();

  /// True when the spectrum renderer's Texture driver is in this build. On
  /// Android the SurfaceView PlatformView (mode 5) renders it instead, and the
  /// widget checks vizGpuAvailable — this getter only gates stale binaries.
  bool get hasSpectrum => _spectrumRegisterFn != null;

  /// Palette index, scroll mode (0 fixed bar, 1 moving bar) and VU-meter
  /// toggle for the GL pattern renderer. A palette change re-tessellates on
  /// the next frame.
  void setPatternVizOptions(int palette, int scrollMode, bool showVolume,
          {bool smoothScroll = true}) =>
      _patternvizSetOptionsFn?.call(
          palette, scrollMode, showVolume ? 1 : 0, smoothScroll ? 1 : 0);

  /// Force an opaque background on the pattern grid instead of letting the
  /// artwork show through — the grid is dense text and a busy cover under it
  /// hurts legibility.
  void setPatternVizOpaqueBg(bool on) => _patternvizOpaqueBgFn?.call(on ? 1 : 0);

  /// Horizontal scroll (px) of the GL pattern grid — from the drag gesture.
  void setPatternVizXScroll(double px) => _patternvizSetXScrollFn?.call(px);

  /// Zoom (x1 / x1.5 / x2 …) and column visibility (0 all, 1 note+instrument,
  /// 2 note only) of the GL pattern grid. Re-tessellates on the next frame.
  void setPatternVizLayout(double sizeScale, int columnMode) =>
      _patternvizSetLayoutFn?.call(sizeScale, columnMode);

  /// Surface device-pixel-ratio, so the pattern font stays a fixed on-screen
  /// size regardless of window/viewport size. Pass the DPR for a physical-px
  /// surface (Android SurfaceView), 1.0 for a logical-sized one (Apple Texture).
  void setPatternVizPixelScale(double dpr) =>
      _patternvizSetPixelScaleFn?.call(dpr);

  /// Whether the native pattern renderer supports [setPatternVizPixelScale].
  /// False on a stale binary — callers must NOT render the pattern at device
  /// resolution then (the font would not scale up → a half-size grid).
  bool get hasPatternPixelScale => _patternvizSetPixelScaleFn != null;

  /// Seconds of FUTURE rows the synthesized pattern grid currently shows — the
  /// decode look-ahead it needs to fill its leading edge. The renderer owns the
  /// row height (fixed logical px × surface DPR × user zoom), so only it can
  /// answer; a Dart-side copy of that formula went stale and under-asked on
  /// large/high-DPI surfaces. Returns null on a stale binary → caller falls
  /// back to its own estimate.
  double? get patternVizFutureSeconds => _patternvizFutureSecsFn?.call();

  /// GPU path: register the projectM (Milkdrop) texture. Returns textureId or err.
  /// Returns -1 if projectM is not built on this platform.
  int projectmRegister(int width, int height) {
    final fn = _projectmRegisterFn;
    if (fn == null) return -1;
    return fn(width, height);
  }

  /// projectM is compiled into the engine. NOT "the Texture path exists" — on
  /// Android it is driven by the SurfaceView PlatformView instead, so keying
  /// this on _projectmRegisterFn (Apple-only) hid the visualizer there.
  bool get hasProjectM => _projectmAvailable;

  void projectmRenderAndNotify() => _projectmRenderAndNotifyFn?.call();

  /// Next preset (random or sequential per mode; pushes history).
  void projectmNextPreset() => _projectmNextPresetFn?.call();

  /// Previous preset (pops the history stack).
  void projectmPrevPreset() => _projectmPrevPresetFn?.call();

  /// A counter bumped on every preset change (manual next/prev AND the core's
  /// own timed auto-switch). Poll it to detect a change and flash the name.
  int get projectmPresetSerial => _projectmPresetSerialFn?.call() ?? 0;

  /// Current preset display name (basename, no extension); empty if unavailable.
  String get projectmPresetName {
    final fn = _projectmPresetNameFn;
    if (fn == null) return '';
    final ptr = fn();
    return ptr == nullptr ? '' : ptr.toDartString();
  }

  /// Absolute path of the current preset; empty if unavailable.
  String get projectmPresetPath {
    final fn = _projectmPresetPathFn;
    if (fn == null) return '';
    final ptr = fn();
    return ptr == nullptr ? '' : ptr.toDartString();
  }

  /// Number of presets in the active list.
  int get projectmPresetCount => _projectmPresetCountFn?.call() ?? 0;

  /// True when the native build carries the preset-source API (set_playlist /
  /// set_texture_dirs) — gate the source-switcher UI on this.
  bool get hasProjectMPlaylist => _projectmSetPlaylistFn != null;

  /// Replace the active preset list (absolute .milk paths). Applied on the
  /// render thread; empty list = back to the bundled default directory.
  ///
  /// [startIndex] picks which preset opens: -1 keeps the usual behaviour
  /// (random or first, per the shuffle setting), an in-range index forces that
  /// one — what "play THIS preset" needs, while next/prev still walk the whole
  /// list.
  void projectmSetPlaylist(List<String> paths, {int startIndex = -1}) {
    final fn = _projectmSetPlaylistFn;
    if (fn == null) return;
    final joined = paths.join('\n').toNativeUtf8();
    fn(joined, startIndex);
    malloc.free(joined);
  }

  /// Whether the preset on screen reads the `mouse` uniform — i.e. whether
  /// moving the pointer over the visualizer does anything at all.
  bool get projectmPresetUsesMouse => (_projectmUsesMouseFn?.call() ?? 0) != 0;

  /// Pointer state for presets that read MilkDrop3's `mouse` uniform.
  /// [x] and [y] are 0..1 from the top-left of the visualizer, or -1 to say the
  /// pointer is away; [held] is the button being down, [clicked] a release that
  /// just happened (the preset sees it for one frame).
  void projectmSetMouse(double x, double y,
          {bool held = false, bool clicked = false}) =>
      _projectmSetMouseFn?.call(x, y, held ? 1 : 0, clicked ? 1 : 0);

  /// Texture search directories (bundled dir + installed pack texture bundles).
  /// Empty list = default <datadir>/projectm/textures.
  void projectmSetTextureDirs(List<String> dirs) {
    final fn = _projectmSetTextureDirsFn;
    if (fn == null) return;
    final joined = dirs.join('\n').toNativeUtf8();
    fn(joined);
    malloc.free(joined);
  }

  /// [randomNext]: pick the next preset at random; [blend]: soft-cut transition.
  void projectmSetMode({required bool randomNext, required bool blend}) =>
      _projectmSetModeFn?.call(randomNext ? 1 : 0, blend ? 1 : 0);

  /// App lifecycle for the projectM preload worker: background stops it (its
  /// GPU work is forbidden there on iOS and poisons later preset switches),
  /// foreground restarts it on the next render tick. Safe with no instance.
  void projectmSetActive(bool foreground) =>
      _projectmSetActiveFn?.call(foreground ? 1 : 0);

  /// Full projectM tunables (Settings → Visualisation → projectM).
  /// [qualityShift] 0=Max,1=1/2,2=1/4,3=1/8 render resolution.
  void projectmSetParams({
    required bool randomNext,
    required bool lockPreset,
    required bool blend,
    required double blendTime,
    required double presetDuration,
    required int qualityShift,
    required int meshX,
    required int meshY,
    required double beatSensitivity,
    required bool hardcutEnabled,
    required double hardcutTime,
    required double hardcutSensitivity,
    required bool aspectCorrection,
    required bool permissive,
    /// Pinned transition pattern, -1 = pick at random (the default).
    int transitionIndex = -1,
  }) =>
      _projectmSetParamsFn?.call(
          randomNext ? 1 : 0, lockPreset ? 1 : 0, blend ? 1 : 0,
          blendTime, presetDuration, qualityShift, meshX, meshY,
          beatSensitivity, hardcutEnabled ? 1 : 0, hardcutTime,
          hardcutSensitivity, aspectCorrection ? 1 : 0, permissive ? 1 : 0,
          transitionIndex);

  /// Number of built-in transition patterns. 0 before the first projectM init,
  /// so the settings list must fall back to its own name table.
  int projectmTransitionCount() => _projectmTransitionCountFn?.call() ?? 0;

  /// Le preset COURANT est-il resté sous 5 images/s pendant plus de 2 s ?
  ///
  /// Le verdict est CONSOMMÉ: deux interrogations rapprochées ne peuvent pas
  /// traiter le même événement deux fois. `false` quand le binaire natif ne
  /// connaît pas encore l'export — un moteur périmé ne doit pas désactiver des
  /// presets qui vont très bien.
  bool projectmTakeSlowVerdict() =>
      (_projectmSlowVerdictFn?.call() ?? 0) != 0;

  /// Upload an artwork image as the GL visualizer background.
  /// [rgba] must be width×height×4 RGBA8 bytes (row 0 = top of image).
  void vizSetArtwork(Uint8List rgba, int w, int h, double opacity) {
    final fn = _vizSetArtworkFn;
    if (fn == null) return;
    final ptr = malloc<Uint8>(rgba.length);
    ptr.asTypedList(rgba.length).setAll(0, rgba);
    fn(ptr, w, h, opacity);
    malloc.free(ptr);
  }

  void vizSetArtworkOpacity(double opacity) => _vizSetArtworkOpacFn?.call(opacity);

  /// Vsync-aligned frame timestamp (Ticker elapsed, seconds). Call before each
  /// *RenderAndNotify so the native scroll clocks advance on the frame grid
  /// instead of jittery wall-clock-at-render (removes micro-trembling).
  void vizSetFrameTime(double seconds) => _vizSetFrameTimeFn?.call(seconds);

  void vizClearArtwork()                    => _vizClearArtworkFn?.call();

  /// Toggle the per-voice oscilloscope cell grid (GPU path).
  void scopeSetGrid(bool enabled)           => _scopeSetGridFn?.call(enabled ? 1 : 0);

  /// Set the oscilloscope line thickness multiplier (0.5–3; 1.0 = default).
  void setVizLineWidth(double mult)         => _setLineWidthFn?.call(mult);

  /// CRT effect levels packed: bits0-1 glow, bits2-3 speed (0=off,1=low,2=high).
  void setCrtFlags(int mask)                => _setCrtFlagsFn?.call(mask);

  /// Oscilloscope colors (0..1 components).
  void setScopeColor(double r, double g, double b)       => _setScopeColorFn?.call(r, g, b);
  void setStereoMonoColor(double r, double g, double b)  => _setStereoMonoFn?.call(r, g, b);
  void setStereoLeftColor(double r, double g, double b)  => _setStereoLeftFn?.call(r, g, b);
  void setStereoRightColor(double r, double g, double b) => _setStereoRightFn?.call(r, g, b);
  void setStereoBicolor(bool on)                         => _setStereoBicolorFn?.call(on ? 1 : 0);
  /// Spectrum palette (viz mode 5): 0 = the scope colors, 1 = by frequency.
  void setSpectrumPalette(int mode)                      => _setSpectrumPaletteFn?.call(mode);

  /// Look-ahead note timeline (scrolling-notation visualizer).
  int    get notesVoiceCount  => _notesVcFn?.call() ?? 0;
  double get notesLeadSeconds => _notesLeadFn?.call() ?? 0.0;

  /// Fills [out] (cols * voiceCount floats, column-major) with per-voice note Hz
  /// over [now, now + aheadSec]. Returns the voice count.
  int notesWindow(Pointer<Float> out, int cols, double aheadSec) =>
      _notesWindowFn?.call(out, cols, aheadSec, 44100) ?? 0;

  // ── Tracker-pattern visualizer ────────────────────────────────────────────

  /// True when the playing plugin exposes real tracker patterns (openmpt).
  bool get patternSupported => (_patSupportedFn?.call() ?? 0) != 0;

  /// Fetches the whole song structure once (patterns are immutable). Returns
  /// null when the current backend has no pattern data. Marshals the immutable
  /// C table; safe to call right after load.
  PatternSong? fetchPatternSong() {
    final infoFn = _patSongInfoFn, getFn = _patGetFn,
        orderFn = _patOrderFn, rowsFn = _patNumRowsFn;
    if (infoFn == null || getFn == null || orderFn == null || rowsFn == null) {
      return null;
    }
    if (!patternSupported) return null;

    final infoPtr = calloc<_PatSongInfoNative>();
    try {
      if (infoFn(infoPtr) == 0) return null;
      final info = infoPtr.ref;
      final nch = info.numChannels;
      final npat = info.numPatterns;
      if (nch <= 0 || npat <= 0) return null;

      final order = <int>[for (int o = 0; o < info.numOrders; o++) orderFn(o)];
      final rows = <int>[for (int p = 0; p < npat; p++) rowsFn(p)];

      // Largest pattern sizes the scratch cell buffer (reused per pattern).
      int maxCells = 0;
      for (final r in rows) {
        final c = r * nch;
        if (c > maxCells) maxCells = c;
      }
      final patterns = <List<PatternCell>>[];
      if (maxCells == 0) {
        for (int p = 0; p < npat; p++) patterns.add(const []);
        return PatternSong(
            numChannels: nch, order: order, patternRows: rows, patterns: patterns);
      }
      final buf = calloc<_PatCellNative>(maxCells);
      try {
        for (int p = 0; p < npat; p++) {
          final n = getFn(p, buf, maxCells);
          final cells = <PatternCell>[];
          for (int i = 0; i < n; i++) {
            final c = (buf + i).ref;
            final fx = <PatternFx>[];
            for (int k = 0; k < c.numFx && k < 8; k++) {
              // The code is 1-4 chars, NUL-terminated within the slot: a
              // tracker letter, Furnace's 2 hex digits, or SunVox's 4.
              final chars = <int>[];
              for (int j = 0; j < 4; j++) {
                final ch = c.fx[k][j];
                if (ch == 0) break;
                chars.add(ch);
              }
              if (chars.isEmpty) continue;
              fx.add(PatternFx(String.fromCharCodes(chars),
                  c.fxval[k] < 0 ? 0 : c.fxval[k]));
            }
            cells.add(PatternCell(
              note: c.note,
              instrument: c.instrument,
              volume: c.volume,
              fx: fx,
            ));
          }
          patterns.add(cells);
        }
      } finally {
        calloc.free(buf);
      }
      return PatternSong(
          numChannels: nch, order: order, patternRows: rows, patterns: patterns);
    } finally {
      calloc.free(infoPtr);
    }
  }

  /// Live playback cursor synced to the HEARD position: (order, row), or null
  /// when unavailable. Poll each frame; cheap.
  ({int order, int row})? patternCursor() {
    final fn = _patCursorFn;
    if (fn == null) return null;
    final op = calloc<Int32>(2);
    try {
      if (fn(op, op + 1) == 0) return null;
      return (order: op.value, row: (op + 1).value);
    } finally {
      calloc.free(op);
    }
  }

  /// Enable/disable decode-ahead (look-ahead) for the notation visualizer.
  void setLookahead(bool on) => _setLookaheadFn?.call(on ? 1 : 0);

  /// Set the decode-ahead target in SECONDS (0 = off). A visualizer sizes this
  /// to how far ahead it actually draws — the pattern grid scales it with its
  /// on-screen row count, the notation view uses its fixed future window. The
  /// engine clamps it to the ring capacity (~4 s).
  void setLookaheadSeconds(double seconds) =>
      _setLookaheadSecsFn?.call(seconds);

  /// Color palette for the notation visualizer (0=cyberpunk … 4=classic).
  void setNotePalette(int index) => _setNotePaletteFn?.call(index);

  /// Note block style: 0 = flat, 1 = box (beveled relief).
  void setNoteStyle(int style) => _setNoteStyleFn?.call(style);

  /// GPU path: unregister texture + tear down GL.
  void vizUnregister() {
    _vizUnregisterFn?.call();
    _vizWidth  = 0;
    _vizHeight = 0;
  }

  // CPU-readback path (fallback / Android / desktop).
  bool vizInit(int width, int height) {
    final fn = _vizInitFn;
    if (fn == null) return false;
    if (fn(width, height) != 0) return false;
    _vizWidth  = width;
    _vizHeight = height;
    return true;
  }

  void vizRender() => _vizRenderFn?.call();

  int get vizWidth  => _vizWidth;
  int get vizHeight => _vizHeight;

  void vizUninit() {
    _vizUninitFn?.call();
    _vizWidth  = 0;
    _vizHeight = 0;
  }

  // ---------------------------------------------------------------------------
  // Per-channel data (VGM oscilloscope / piano-roll)
  // ---------------------------------------------------------------------------

  /// Number of active channels for the currently loaded VGM/S98/GYM/DRO file.
  /// Returns 0 if the current file has no per-channel data.
  int get channelCount => _channelCountFn?.call() ?? 0;

  /// Copy the oscilloscope ring-buffer for channel [ch] into [out].
  /// [out] must be at least [channelBufSize] bytes.
  /// Returns the number of bytes copied.
  int channelBuf(int ch, Int8List out) {
    final fn = _channelBufFn;
    if (fn == null) return 0;
    final ptr = calloc<Int8>(channelBufSize);
    try {
      final n = fn(ch, ptr, channelBufSize);
      if (n > 0) out.setAll(0, ptr.asTypedList(n));
      return n;
    } finally {
      calloc.free(ptr);
    }
  }

  /// Last detected frequency (Hz) for channel [ch], or 0 if not available.
  int    channelWritePtr(int ch) => _channelWritePtrFn?.call(ch) ?? 0;
  double channelFreqHz(int ch) => _channelFreqFn?.call(ch) ?? 0.0;

  /// Last volume for channel [ch] (0–255), or 0 if not available.
  int channelVolume(int ch) => _channelVolFn?.call(ch) ?? 0;

  /// Low-level: fill a pre-allocated native buffer [ptr] with ring-buffer data
  /// for channel [ch].  Returns the number of bytes written.
  /// Use this from high-frequency code to avoid per-call native heap allocation.
  int channelBufNative(int ch, Pointer<Int8> ptr, int len) =>
      _channelBufFn?.call(ch, ptr, len) ?? 0;

  /// Same as [channelBufNative] but applies a correlation-based trigger to
  /// stabilise the waveform display.  Falls back to raw copy on first call or
  /// when insufficient data is available.
  int channelBufTriggeredNative(int ch, Pointer<Int8> ptr, int len) =>
      _channelBufTrigFn?.call(ch, ptr, len) ?? 0;

  // ── Voice / chipset grouping + muting ─────────────────────────────────
  // Voices are the per-channel scope entries; a plugin may group them by chip
  // and name them. When it doesn't, one synthetic chip "—" spans all voices.

  /// Number of voices for the currently loaded file (0 if none).
  ///
  /// NOTE: this NEVER returns 0 for a loaded file — the engine substitutes two
  /// virtual voices fed from the L/R waveform so the scope always has content.
  /// To ask whether the backend produces real per-voice data, use
  /// [voiceCountRaw].
  int get voiceCount => _voiceCountFn?.call() ?? 0;

  /// REAL per-voice channel count: 0 ⇒ the backend exposes none (vgmstream and
  /// miniaudio's mp3/ogg/flac/wav decode an already-mixed stream, so there are
  /// no chip channels and no notes either).
  int get voiceCountRaw => _voiceCountRawFn?.call() ?? 0;

  /// Number of chip groups (>= 1 when any voices exist).
  int get chipCount => _chipCountFn?.call() ?? 0;

  /// First voice index of chip [c].
  int chipVoiceStart(int c) => _chipVoiceStartFn?.call(c) ?? 0;

  /// Number of voices in chip [c].
  int chipVoiceCount(int c) => _chipVoiceCountFn?.call(c) ?? 0;

  /// Chip group index owning voice [v].
  int voiceChip(int v) => _voiceChipFn?.call(v) ?? 0;

  String _readName(_NameDart? fn, int i) {
    if (fn == null) return '';
    const cap = 32;
    final buf = calloc<Uint8>(cap);
    try {
      fn(i, buf.cast<Utf8>(), cap);
      return buf.cast<Utf8>().toDartString();
    } finally {
      calloc.free(buf);
    }
  }

  /// Display name for voice [v] (e.g. "Voice 1").
  String voiceName(int v) => _readName(_voiceNameFn, v);

  /// Display name for chip [c] (e.g. "Paula", or "—" when ungrouped).
  String chipName(int c) => _readName(_chipNameFn, c);

  /// Live mute mask: bit v set ⇒ voice v muted.
  int get voiceMuteMask => _getMuteMaskFn?.call() ?? 0;

  /// How many times the audio callback found the decode-ahead ring short, i.e.
  /// the decoder failed to stay [lookahead] ahead of playback. Monotonic.
  ///
  /// Diagnostic: if this stays flat while the audio audibly crackles, the
  /// crackle is NOT the decoder falling behind and the cause lies elsewhere.
  int get underrunCount  => _underrunCountFn?.call() ?? 0;

  /// Frames of silence those underruns cost (44100 ≈ one second).
  int get underrunFrames => _underrunFramesFn?.call() ?? 0;

  /// The audio callback took over a millisecond. It only memcpys, so it WAITED:
  /// lock contention / priority inversion inside our own code.
  int get slowReadCount => _slowReadFn?.call() ?? 0;

  /// The audio callback was scheduled far later than the device period. The OS
  /// was late, not us — the lever is the device buffer, and nothing in the
  /// decode path will help.
  int get lateReadCount => _lateReadFn?.call() ?? 0;

  /// Worst gap ever seen between two audio callbacks, in milliseconds. The
  /// counts say a stall happened; this says how deep it was.
  double get maxCallbackGapMs => (_maxGapFn?.call() ?? 0) / 1000.0;

  /// The DEVICE callback missed its period — the OS failed to schedule the
  /// realtime thread. Unlike [lateReadCount], this cannot be faked by a pause:
  /// the device callback runs continuously as long as output is running.
  int get deviceLateCount => _devLateFn?.call() ?? 0;

  /// La période DEMANDÉE au périphérique (ms). Le message de démarrage
  /// l'annonçait en dur, et faux; c'est pourtant ce nombre qui dit si la
  /// marge négociée correspond à ce qu'on voulait.
  int get deviceRequestedPeriodMs => _devReqPeriodFn?.call() ?? 0;

  /// Worst gap between two DEVICE callbacks, in milliseconds.
  double get deviceMaxGapMs => (_devMaxGapFn?.call() ?? 0) / 1000.0;

  /// Worst time spent INSIDE the device callback, in milliseconds. Large means
  /// the engine graph itself blocked and the gaps are self-inflicted;
  /// microseconds while gaps hit 400 ms means the callback was never invoked.
  double get deviceMaxBusyMs => (_devMaxBusyFn?.call() ?? 0) / 1000.0;

  /// The buffer the device ACTUALLY negotiated, in milliseconds — not the one we
  /// asked for. On iOS the request is only AVAudioSession's *preferred* IO
  /// buffer duration: the system may clamp it, and audio_service (which owns the
  /// session category) reconfigures the session right after we init. If this
  /// comes back far below what we asked for, that is the whole story.
  double get devicePeriodMs {
    final frames = _devPeriodFramesFn?.call() ?? 0;
    final rate   = _devSampleRateFn?.call() ?? 0;
    if (frames <= 0 || rate <= 0) return 0;
    return frames * 1000 / rate;
  }

  /// How many such periods the device buffers (total slack = periods × period).
  int get devicePeriods => _devPeriodsFn?.call() ?? 0;
  set voiceMuteMask(int mask) => _setMuteMaskFn?.call(mask);

  /// True if voice [v] is currently audible (not muted).
  bool voiceEnabled(int v) => (voiceMuteMask & (1 << v)) == 0;

  /// Mute/unmute a single voice, applied to the engine immediately.
  void setVoiceEnabled(int v, bool enabled) {
    final bit = 1 << v;
    final m = voiceMuteMask;
    voiceMuteMask = enabled ? (m & ~bit) : (m | bit);
  }

  /// Mute/unmute every voice belonging to chip [c].
  void setChipEnabled(int c, bool enabled) {
    final start = chipVoiceStart(c);
    final count = chipVoiceCount(c);
    var m = voiceMuteMask;
    for (var v = start; v < start + count; v++) {
      final bit = 1 << v;
      m = enabled ? (m & ~bit) : (m | bit);
    }
    voiceMuteMask = m;
  }

  /// Mute/unmute all voices at once.
  void setAllVoicesEnabled(bool enabled) {
    if (enabled) {
      voiceMuteMask = 0;
    } else {
      final n = voiceCount;
      voiceMuteMask = n >= 63 ? -1 : ((1 << n) - 1);
    }
  }
}

void debugLog(String msg) {
  // ignore: avoid_print
  print(msg);
}
