import 'package:flutter/material.dart';

import 'l10n.dart';
import 'player_controller.dart';
import 'settings_screen.dart' show SettingRow;
import 'user_settings.dart';

/// Réglages → Moteurs → « libADLMIDI »: le MIDI (et XMI, MUS DMX, HMI/HMP) sur
/// une puce OPL3 émulée. Quel moteur joue un .mid se choisit dans « Décodeurs
/// par défaut » (Synthé MIDI: OPL3), avec les autres choix de moteur.
/// Remise à zéro: le groupe 'adlmidi'.
///
/// La banque et le modèle de volume sont des listes LONGUES (79 et 15
/// entrées): un dialogue, jamais un DropdownButton (voir
/// settings_long_picker_test.dart).
class AdlmidiEnginePanel extends StatefulWidget {
  const AdlmidiEnginePanel({super.key});

  @override
  State<AdlmidiEnginePanel> createState() => _AdlmidiEnginePanelState();
}

/// Les émulateurs COMPILÉS (rewamp_add_adlmidi), par valeur de ADL_Emulator.
/// Des noms propres: rien à traduire.
const List<(int, String)> kAdlEmulators = [
  (0, 'Nuked OPL3 1.8'),
  (1, 'Nuked OPL3 1.7.4'),
  (2, 'DOSBox 0.74'),
  (3, 'Opal'),
  (5, 'ESFMu'),
  (8, 'YMFM OPL3'),
  (7, 'YMFM OPL2'),
  (11, 'Nuked OPL2 Lite'),
  (12, 'Nuked CQM'),
  (13, 'DOSBox OPL2'),
];

/// ADLMIDI_VolumeModel_*, après « auto » (0) et « générique » (1), traduits:
/// des noms de pilotes, donc propres.
const List<(int, String)> kAdlVolumeModels = [
  (2, 'OPL3 / CMF'),
  (3, 'DMX'),
  (4, 'Apogee'),
  (5, 'Win9x'),
  (6, 'DMX (fixed)'),
  (7, 'Apogee (fixed)'),
  (8, 'AIL'),
  (9, 'Win9x (generic FM)'),
  (10, 'HMI'),
  (11, 'HMI (old)'),
  (12, 'MS AdLib'),
  (13, 'IMF Creator'),
  (14, "O'Connell"),
];

class _AdlmidiEnginePanelState extends State<AdlmidiEnginePanel> {
  final _s = UserSettings.instance;
  late final List<String> _banks =
      PlayerController.current?.audio.adlmidiBankNames() ?? const [];

  @override
  void initState() {
    super.initState();
    _s.addListener(_onChanged);
  }

  @override
  void dispose() {
    _s.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  String _bankLabel(int i) =>
      i >= 0 && i < _banks.length ? _banks[i] : '#$i';

  String _volumeLabel(BuildContext context, int v) {
    final l10n = context.l10n;
    if (v == 0) return l10n.settingsAuto;
    if (v == 1) return l10n.settingsAdlVolumeGeneric;
    for (final (k, n) in kAdlVolumeModels) {
      if (k == v) return n;
    }
    return '#$v';
  }

  Future<int?> _pick(BuildContext context, String title,
      List<(int, String)> items, int current) {
    return showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: [
          SizedBox(
            width: 420,
            height: MediaQuery.sizeOf(ctx).height * 0.6,
            child: ListView(
              children: [
                for (final (v, label) in items)
                  ListTile(
                    title: Text(label),
                    trailing: v == current ? const Icon(Icons.check) : null,
                    selected: v == current,
                    onTap: () => Navigator.pop(ctx, v),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final emu = kAdlEmulators.any((e) => e.$1 == _s.adlEmulator)
        ? _s.adlEmulator
        : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_banks.isNotEmpty)
          ListTile(
            title: Text(l10n.settingsAdlBank),
            subtitle: Text(_bankLabel(_s.adlBank)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final v = await _pick(context, l10n.settingsAdlBank,
                  [for (var i = 0; i < _banks.length; i++) (i, _banks[i])],
                  _s.adlBank);
              if (v != null) _s.adlBank = v;
            },
          ),
        SettingRow(
          label: l10n.settingsAdlEmulator,
          resetKey: 'adlEmulator',
          child: DropdownButton<int>(
            value: emu,
            isDense: true,
            isExpanded: true,
            items: [
              for (final (v, n) in kAdlEmulators)
                DropdownMenuItem(
                    value: v,
                    child: Text(n, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) { if (v != null) _s.adlEmulator = v; },
          ),
        ),
        SettingRow(
          label: l10n.settingsAdlChips,
          resetKey: 'adlChips',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 160,
                child: Slider(
                  value: _s.adlChips.clamp(1, 16).toDouble(),
                  min: 1,
                  max: 16,
                  divisions: 15,
                  onChanged: (v) => _s.adlChips = v.round(),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text('${_s.adlChips}', textAlign: TextAlign.end),
              ),
            ],
          ),
        ),
        ListTile(
          title: Text(l10n.settingsAdlVolumeModel),
          subtitle: Text(_volumeLabel(context, _s.adlVolumeModel)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final v = await _pick(context, l10n.settingsAdlVolumeModel, [
              (0, l10n.settingsAuto),
              (1, l10n.settingsAdlVolumeGeneric),
              ...kAdlVolumeModels,
            ], _s.adlVolumeModel);
            if (v != null) _s.adlVolumeModel = v;
          },
        ),
        SettingRow(
          label: l10n.settingsAdlSoftPan,
          resetKey: 'adlSoftPan',
          child: Switch(
            value: _s.adlSoftPan,
            onChanged: (v) => _s.adlSoftPan = v,
          ),
        ),
        SettingRow(
          label: l10n.settingsMasterVolume,
          resetKey: 'adlGain',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 160,
                child: Slider(
                  value: _s.adlGain.clamp(0.5, 6.0),
                  min: 0.5,
                  max: 6.0,
                  divisions: 11,
                  onChanged: (v) => _s.adlGain = v,
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                    l10n.settingsValuePercent((_s.adlGain * 100).round()),
                    textAlign: TextAlign.end),
              ),
            ],
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: TextButton.icon(
              icon: const Icon(Icons.restart_alt, size: 16),
              label: Text(l10n.settingsResetEngine),
              onPressed: () => _s.resetEngineSettings('adlmidi'),
            ),
          ),
        ),
      ],
    );
  }
}
