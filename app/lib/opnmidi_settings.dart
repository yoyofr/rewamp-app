import 'package:flutter/material.dart';

import 'fm_bank_manager.dart';
import 'fm_bank_screen.dart';
import 'fm_emulators.dart';
import 'l10n.dart';
import 'player_controller.dart';
import 'settings_screen.dart' show SettingRow;
import 'user_settings.dart';

/// Réglages → Moteurs → « libOPNMIDI »: le MIDI sur une puce OPN2 (YM2612,
/// Mega Drive) ou OPNA (YM2608, PC-98) émulée. Quel moteur joue un .mid se
/// choisit dans « Décodeurs par défaut » (Synthé MIDI: OPN2). Remise à zéro:
/// le groupe 'opnmidi'. Mêmes libellés que la page libADLMIDI (génériques).
///
/// La banque est une liste: un dialogue, jamais un DropdownButton (voir
/// settings_long_picker_test.dart).
class OpnmidiEnginePanel extends StatefulWidget {
  const OpnmidiEnginePanel({super.key});

  @override
  State<OpnmidiEnginePanel> createState() => _OpnmidiEnginePanelState();
}

/// OPNMIDI_VolumeModel_*, après « auto » (0) et « générique » (1): des noms
/// de pilotes, donc propres.
const List<(int, String)> kOpnVolumeModels = [
  (2, 'OPN2 native'),
  (3, 'DMX'),
  (4, 'Apogee'),
  (5, 'Win9x'),
];

class _OpnmidiEnginePanelState extends State<OpnmidiEnginePanel> {
  final _s = UserSettings.instance;
  late final List<String> _banks =
      PlayerController.current?.audio.opnmidiBankNames() ?? const [];

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

  String _volumeLabel(BuildContext context, int v) {
    final l10n = context.l10n;
    if (v == 0) return l10n.settingsAuto;
    if (v == 1) return l10n.settingsAdlVolumeGeneric;
    for (final (k, n) in kOpnVolumeModels) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_banks.isNotEmpty)
          ListTile(
            title: Text(l10n.settingsAdlBank),
            subtitle: Text(fmBankLabel(FmBankKind.wopn, _banks, _s.opnBank)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => FmBankScreen(
                      kind: FmBankKind.wopn,
                      builtin: _banks,
                      builtinIndex: () => _s.opnBank,
                      onSelectBuiltin: (i) => _s.opnBank = i,
                    ))),
          ),
        FmEmulatorTile(
          list: kOpnEmulators,
          value: _s.opnEmulator,
          onChanged: (v) => _s.opnEmulator = v,
        ),
        SettingRow(
          label: l10n.settingsAdlChips,
          resetKey: 'opnChips',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 160,
                child: Slider(
                  value: _s.opnChips.clamp(1, 16).toDouble(),
                  min: 1,
                  max: 16,
                  divisions: 15,
                  onChanged: (v) => _s.opnChips = v.round(),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text('${_s.opnChips}', textAlign: TextAlign.end),
              ),
            ],
          ),
        ),
        ListTile(
          title: Text(l10n.settingsAdlVolumeModel),
          subtitle: Text(_volumeLabel(context, _s.opnVolumeModel)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final v = await _pick(context, l10n.settingsAdlVolumeModel, [
              (0, l10n.settingsAuto),
              (1, l10n.settingsAdlVolumeGeneric),
              ...kOpnVolumeModels,
            ], _s.opnVolumeModel);
            if (v != null) _s.opnVolumeModel = v;
          },
        ),
        SettingRow(
          label: l10n.settingsAdlSoftPan,
          resetKey: 'opnSoftPan',
          child: Switch(
            value: _s.opnSoftPan,
            onChanged: (v) => _s.opnSoftPan = v,
          ),
        ),
        SettingRow(
          label: l10n.settingsMasterVolume,
          resetKey: 'opnGain',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 160,
                child: Slider(
                  value: _s.opnGain.clamp(0.5, 6.0),
                  min: 0.5,
                  max: 6.0,
                  divisions: 11,
                  onChanged: (v) => _s.opnGain = v,
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                    l10n.settingsValuePercent((_s.opnGain * 100).round()),
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
              onPressed: () => _s.resetEngineSettings('opnmidi'),
            ),
          ),
        ),
      ],
    );
  }
}
