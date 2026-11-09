import 'package:flutter/material.dart';
import 'package:rewamp_audio/rewamp_audio.dart';

import 'engine_choices.dart';
import 'fm_bank_manager.dart';
import 'fm_bank_screen.dart';
import 'l10n.dart';
import 'player_controller.dart';
import 'soundfont_manager.dart';
import 'sheet_handle.dart';
import 'track_options_sheet.dart' show optionsSheetConstraints;
import 'user_settings.dart';

/// The engines able to play [path] (a file ON THE DEVICE — its header is
/// read), or an empty list when « Lire avec… » has nothing to offer: one
/// engine only — unless it is an engine with something else to choose (FM
/// bank, SoundFont, MT-32 model).
List<String> playWithCandidatesFor(RewampAudio audio, String path) {
  final c = audio.pluginCandidates(path);
  if (c.length >= 2) return c;
  if (c.length == 1 &&
      (EngineChoices.bankEngines.contains(c.first) ||
          EngineChoices.optionPlugins.contains(c.first))) {
    return c;
  }
  return const [];
}

/// Same, for the CURRENT track.
List<String> playWithCandidates(PlayerController ctrl) {
  final path = ctrl.filePath;
  return path == null ? const [] : playWithCandidatesFor(ctrl.audio, path);
}

/// What the sheet was closed with.
enum PlayWithAction {
  /// Nothing recorded.
  cancel,

  /// Remembered, not played (a track or album that is not playing).
  save,

  /// Recorded (or set for this playback), and to be played now.
  play,
}

/// « Lire avec… » for the CURRENT track: pick the engine, optionally remember
/// it for the file or its album (« Se souvenir de ce choix »), and the track
/// restarts with it. Without « remember », the choice lasts this playback.
Future<void> showPlayWithSheet(BuildContext context, PlayerController ctrl) async {
  final path = ctrl.filePath;
  if (path == null) return;
  final candidates = playWithCandidates(ctrl);
  if (candidates.isEmpty) return;
  final r = await _show(context, path, candidates, ctrl.audio,
      playing: ctrl.audio.backendName, current: true, album: false);
  if (r == PlayWithAction.play) await ctrl.replayCurrent();
}

/// « Lire avec… » for a track or an ALBUM that is not (necessarily) playing,
/// from its options sheet. [path] = the track's file (on the device, or where
/// it will be downloaded: judged on its extension then) — for an
/// album, any of its files (the choice is the folder's). Returns what to do;
/// [PlayWithAction.play] = the caller plays it (a one-shot choice is kept
/// for [path]'s next load). Null when there is nothing to choose.
Future<PlayWithAction?> showPlayWithSheetFor(
  BuildContext context, {
  required String path,
  required bool album,
}) async {
  final audio = PlayerController.current?.audio;
  if (audio == null) return null;
  final candidates = playWithCandidatesFor(audio, path);
  if (candidates.isEmpty) return null;
  final ctrl = PlayerController.current;
  return _show(context, path, candidates, audio,
      playing: ctrl?.filePath == path ? audio.backendName : null,
      current: false,
      album: album);
}

Future<PlayWithAction> _show(BuildContext context, String path,
    List<String> candidates, RewampAudio audio,
    {required String? playing, required bool current, required bool album}) async {
  final r = await showModalBottomSheet<PlayWithAction>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    constraints: optionsSheetConstraints(context),
    builder: (ctx) => SafeArea(
      child: SheetWithHandle(
        child: _PlayWithSheet(
            path: path,
            candidates: candidates,
            playing: playing,
            audio: audio,
            current: current,
            album: album),
      ),
    ),
  );
  return r ?? PlayWithAction.cancel;
}

class _PlayWithSheet extends StatefulWidget {
  const _PlayWithSheet(
      {required this.path,
      required this.candidates,
      required this.playing,
      required this.audio,
      required this.current,
      required this.album});
  final RewampAudio audio;
  final String path;
  final List<String> candidates; // default order: [0] = « Automatique »
  final String? playing;         // the plugin playing it now, if it plays

  /// The track playing: « Lire » restarts it.
  final bool current;

  /// For an ALBUM: always remembered, for the album (no checkbox, no scope).
  final bool album;

  @override
  State<_PlayWithSheet> createState() => _PlayWithSheetState();
}

class _PlayWithSheetState extends State<_PlayWithSheet> {
  /// null = « Automatique ».
  String? _plugin;
  bool _remember = false;
  EngineChoiceScope _scope = EngineChoiceScope.file;

  /// Bank per FM-MIDI engine; null = the engine's setting.
  final Map<String, FmBankRef?> _bank = {};

  /// Option per plugin (SoundFont slug, MT-32 model); null = its setting.
  final Map<String, String?> _option = {};

  /// The engine that will play: the one picked, or the automatic one.
  String get _engine => _plugin ?? widget.candidates.first;

  @override
  void initState() {
    super.initState();
    final ch = EngineChoices.instance;
    // For an album, only what is chosen for the ALBUM: a file's own choice
    // (the file used to read it) is not the album's.
    T? albumOnly<T>((T, EngineChoiceScope)? c) =>
        c == null || (widget.album && c.$2 != EngineChoiceScope.album) ? null : c.$1;
    final c = ch.choiceFor(widget.path);
    _plugin = albumOnly(c);   // null = « Automatique », chosen or not
    final scopes = [
      ch.scopeOf(widget.path),
      for (final e in EngineChoices.bankEngines) ch.bankScopeOf(e, widget.path),
    ];
    for (final e in EngineChoices.bankEngines) {
      _bank[e] = albumOnly(ch.bankChoiceFor(e, widget.path));
    }
    for (final o in EngineChoices.optionPlugins) {
      _option[o] = albumOnly(ch.optionChoiceFor(o, widget.path));
      scopes.add(ch.optionScopeOf(o, widget.path));
    }
    final scope = scopes.firstWhere(
        (s) => s != null && s != EngineChoiceScope.once,
        orElse: () => null);
    if (scope != null) {
      _remember = true;
      _scope = scope;
    }
    if (widget.album) {
      _remember = true;
      _scope = EngineChoiceScope.album;
    }
  }

  void _apply(PlayWithAction action) {
    final scope = _remember ? _scope : EngineChoiceScope.once;
    final ch = EngineChoices.instance;
    final path = widget.path;
    // Unchecking « remember » forgets what was remembered for THIS FILE —
    // never an album choice, which other files of the album rely on (the
    // one-shot simply overrides it for this playback).
    if (!_remember && ch.scopeOf(path) == EngineChoiceScope.file) {
      ch.choose(path, null, EngineChoiceScope.file);
    }
    ch.choose(path, _plugin, scope);
    // The bank of the engine that will play; another engine's stays as it is.
    final e = _engine;
    if (EngineChoices.bankEngines.contains(e)) {
      if (!_remember && ch.bankScopeOf(e, path) == EngineChoiceScope.file) {
        ch.chooseBank(e, path, null, EngineChoiceScope.file);
      }
      ch.chooseBank(e, path, _bank[e], scope);
    }
    if (EngineChoices.optionPlugins.contains(e)) {
      if (!_remember && ch.optionScopeOf(e, path) == EngineChoiceScope.file) {
        ch.chooseOption(e, path, null, EngineChoiceScope.file);
      }
      ch.chooseOption(e, path, _option[e], scope);
    }
    Navigator.pop(context, action);
  }

  FmBankKind get _kind =>
      FmBankKind.values.firstWhere((k) => k.engine == _engine);

  List<String> _builtin() => _engine == 'adlmidi'
      ? widget.audio.adlmidiBankNames()
      : widget.audio.opnmidiBankNames();

  /// The bank the engine's setting plays, as Settings shows it.
  String _settingLabel(List<String> builtin) {
    final s = UserSettings.instance;
    return fmBankLabel(_kind, builtin, _engine == 'adlmidi' ? s.adlBank : s.opnBank);
  }

  Future<void> _pickBank() async {
    final builtin = _builtin();
    final r = await Navigator.of(context).push<(FmBankRef?,)>(MaterialPageRoute(
        builder: (_) => FmBankPickScreen(
              kind: _kind,
              builtin: builtin,
              selected: _bank[_engine],
              settingLabel: _settingLabel(builtin),
            )));
    if (r != null && mounted) setState(() => _bank[_engine] = r.$1);
  }

  Future<void> _pickSoundfont() async {
    final l10n = context.l10n;
    final mgr = SoundfontManager.instance;
    final setting = UserSettings.instance.midiSoundfont;
    final settingName = setting == null ? '—' : mgr.nameOf(setting);
    final r = await showDialog<(String?,)>(
      context: context,
      builder: (ctx) {
        final fonts = mgr.installedFonts();
        final sel = _option['fluidlite'];
        Widget row(String title, String? slug) => ListTile(
              title: Text(title),
              selected: sel == slug,
              leading: Icon(sel == slug
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              onTap: () => Navigator.pop(ctx, (slug,)),
            );
        return AlertDialog(
          title: const Text('SoundFont'),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                row(l10n.playWithSoundfontDefault(settingName), null),
                for (final f in fonts) row(f.$2, f.$1),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel)),
          ],
        );
      },
    );
    if (r != null && mounted) setState(() => _option['fluidlite'] = r.$1);
  }

  Widget _soundfontTile(AppLocalizations l10n) {
    final slug = _option['fluidlite'];
    final mgr = SoundfontManager.instance;
    final setting = UserSettings.instance.midiSoundfont;
    return ListTile(
      leading: const Icon(Icons.piano),
      title: const Text('SoundFont'),
      subtitle: Text(slug == null
          ? l10n.playWithSoundfontDefault(setting == null ? '—' : mgr.nameOf(setting))
          : mgr.nameOf(slug)),
      trailing: const Icon(Icons.chevron_right),
      onTap: _pickSoundfont,
    );
  }

  Widget _mt32Tile(AppLocalizations l10n) {
    final setting = switch (UserSettings.instance.mt32Model) {
      1 => 'MT-32',
      2 => 'CM-32L',
      _ => l10n.settingsMt32ModelAuto,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.settingsMt32Model, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(l10n.playWithMt32Default(setting),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: '', label: Text(l10n.playWithOptionSetting)),
              const ButtonSegment(value: '1', label: Text('MT-32')),
              const ButtonSegment(value: '2', label: Text('CM-32L')),
            ],
            selected: {_option['mt32'] ?? ''},
            onSelectionChanged: (v) => setState(
                () => _option['mt32'] = v.first.isEmpty ? null : v.first),
          ),
        ],
      ),
    );
  }

  Widget _bankTile(AppLocalizations l10n) {
    final builtin = _builtin();
    final b = _bank[_engine];
    return ListTile(
      leading: const Icon(Icons.piano),
      title: Text(l10n.playWithBank),
      subtitle: Text(b == null
          ? l10n.playWithBankDefault(_settingLabel(builtin))
          : fmBankRefLabel(b, builtin)),
      trailing: const Icon(Icons.chevron_right),
      onTap: _pickBank,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tt = Theme.of(context).textTheme;
    Widget option(String? plugin, String label) => RadioListTile<String?>(
          value: plugin,
          title: Text(label),
          subtitle: widget.playing != null &&
                  (plugin ?? widget.candidates.first) == widget.playing
              ? Text(l10n.playWithPlayingNow)
              : null,
        );
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
            child: Text(widget.album ? l10n.playWithTitleAlbum : l10n.playWithTitle,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          if (widget.candidates.length >= 2)
          RadioGroup<String?>(
            groupValue: _plugin,
            onChanged: (v) => setState(() => _plugin = v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                option(null, l10n.playWithAuto(enginePluginLabel(widget.candidates.first))),
                for (final c in widget.candidates) option(c, enginePluginLabel(c)),
              ],
            ),
          ),
          if (EngineChoices.bankEngines.contains(_engine)) ...[
            const Divider(),
            _bankTile(l10n),
          ],
          if (_engine == 'fluidlite') ...[
            const Divider(),
            _soundfontTile(l10n),
          ],
          if (_engine == 'mt32') ...[
            const Divider(),
            _mt32Tile(l10n),
          ],
          if (!widget.album) ...[
          const Divider(),
          CheckboxListTile(
            value: _remember,
            title: Text(l10n.playWithRemember),
            subtitle: Text(_remember
                ? l10n.playWithRememberOn
                : l10n.playWithRememberOff),
            onChanged: (v) => setState(() => _remember = v ?? false),
          ),
          if (_remember)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<EngineChoiceScope>(
                segments: [
                  ButtonSegment(
                      value: EngineChoiceScope.file,
                      label: Text(l10n.playWithScopeFile)),
                  ButtonSegment(
                      value: EngineChoiceScope.album,
                      label: Text(l10n.playWithScopeAlbum)),
                ],
                selected: {_scope},
                onSelectionChanged: (s) => setState(() => _scope = s.first),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    // Nothing recorded, nothing reloaded.
                    onPressed: () => Navigator.pop(context, PlayWithAction.cancel),
                    child: Text(l10n.commonCancel),
                  ),
                ),
                // Not playing: remember without playing (a one-shot choice
                // would be pointless without the play).
                if (!widget.current) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _remember ? () => _apply(PlayWithAction.save) : null,
                      child: Text(l10n.playWithSave),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                      onPressed: () => _apply(PlayWithAction.play),
                      child: Text(l10n.playWithApply)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Deleting something chosen EXPLICITLY for files or albums (« Lire avec… »):
/// the confirmation says how many, and what they will play with instead.
/// Without such a use, [plain] (null = no confirmation at all: true).
Future<bool> confirmDeleteChosen(
  BuildContext context, {
  required String name,
  required (int, int) usage,
  required String title,
  required String outro,
  String? plain,
}) async {
  final l10n = context.l10n;
  final (files, albums) = usage;
  final inUse = files + albums > 0;
  if (!inUse && plain == null) return true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: inUse ? Text(title) : null,
      content: inUse
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.fmBankInUseIntro(name)),
                const SizedBox(height: 8),
                if (files > 0) Text('• ${l10n.fmBankInUseFiles(files)}'),
                if (albums > 0) Text('• ${l10n.fmBankInUseAlbums(albums)}'),
                const SizedBox(height: 8),
                Text(outro),
              ],
            )
          : Text(plain!),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel)),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete)),
      ],
    ),
  );
  return ok == true;
}
