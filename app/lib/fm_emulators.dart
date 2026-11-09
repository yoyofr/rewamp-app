import 'package:flutter/material.dart';

import 'l10n.dart';

/// How close an emulator is to the real chip — upstream's own words
/// (libADLMIDI / libOPNMIDI READMEs: « very accurate », « well-accurate »,
/// « semi-accurate », « inaccurate »), folded into three levels.
enum FmAccuracy { veryHigh, good, approximate }

/// What it costs to run, MEASURED (CPU seconds to render 60 s of « The Healer
/// Stalks » on 4 chips, -O2, Apple M5; scripts/verify_{adl,opn}midi.sh +
/// `time`): light < 0.7 s, medium < 2.5 s, heavy beyond. A phone is several
/// times slower — upstream advises the light ones there.
enum FmCpu { light, medium, heavy }

class FmEmulator {
  final int value;   // ADL_Emulator / Opn2_Emulator
  final String name; // proper name: nothing to translate
  final FmAccuracy accuracy;
  final FmCpu cpu;
  const FmEmulator(this.value, this.name, this.accuracy, this.cpu);
}

/// The emulators rewamp_add_adlmidi compiles, by ADL_Emulator value.
/// Measured CPU s / 60 s: Nuked 1.8 3.05 · Nuked 1.7.4 1.70 · DOSBox 0.26 ·
/// Opal 1.05 · ESFMu 7.94 · YMFM OPL3 0.91 · YMFM OPL2 0.47 · Nuked OPL2 Lite
/// 1.59 · Nuked CQM 6.68 · DOSBox OPL2 0.14.
const List<FmEmulator> kAdlEmulators = [
  FmEmulator(0, 'Nuked OPL3 1.8', FmAccuracy.veryHigh, FmCpu.heavy),
  FmEmulator(1, 'Nuked OPL3 1.7.4', FmAccuracy.veryHigh, FmCpu.medium),
  FmEmulator(2, 'DOSBox 0.74', FmAccuracy.good, FmCpu.light),
  FmEmulator(3, 'Opal', FmAccuracy.approximate, FmCpu.medium),
  FmEmulator(5, 'ESFMu', FmAccuracy.veryHigh, FmCpu.heavy),
  FmEmulator(8, 'YMFM OPL3', FmAccuracy.good, FmCpu.medium),
  FmEmulator(7, 'YMFM OPL2', FmAccuracy.good, FmCpu.light),
  FmEmulator(11, 'Nuked OPL2 Lite', FmAccuracy.veryHigh, FmCpu.medium),
  // The Creative CQM clone, faithfully — which does not sound like an OPL3.
  FmEmulator(12, 'Nuked CQM (Creative)', FmAccuracy.veryHigh, FmCpu.heavy),
  FmEmulator(13, 'DOSBox OPL2', FmAccuracy.good, FmCpu.light),
];

/// The emulators rewamp_add_opnmidi compiles, by Opn2_Emulator value.
/// Measured CPU s / 60 s: MAME YM2612 0.62 · Nuked YM3438 8.02 · Nuked YM2612
/// 8.62 · GENS 0.17 · YMFM OPN2 1.19 · NP2 OPNA 0.28 · MAME YM2608 1.13 · YMFM
/// OPNA 2.68.
const List<FmEmulator> kOpnEmulators = [
  FmEmulator(0, 'MAME YM2612', FmAccuracy.good, FmCpu.light),
  FmEmulator(1, 'Nuked OPN2 (YM3438)', FmAccuracy.veryHigh, FmCpu.heavy),
  FmEmulator(8, 'Nuked OPN2 (YM2612)', FmAccuracy.veryHigh, FmCpu.heavy),
  FmEmulator(2, 'GENS', FmAccuracy.approximate, FmCpu.light),
  FmEmulator(3, 'YMFM OPN2', FmAccuracy.good, FmCpu.medium),
  FmEmulator(4, 'Neko Project II OPNA', FmAccuracy.approximate, FmCpu.light),
  FmEmulator(5, 'MAME YM2608 (OPNA)', FmAccuracy.good, FmCpu.medium),
  FmEmulator(6, 'YMFM OPNA', FmAccuracy.good, FmCpu.heavy),
];

/// « Very accurate · CPU-heavy » — the two tags of an emulator.
String fmEmulatorTags(AppLocalizations l10n, FmEmulator e) {
  final acc = switch (e.accuracy) {
    FmAccuracy.veryHigh => l10n.fmEmuAccuracyVeryHigh,
    FmAccuracy.good => l10n.fmEmuAccuracyGood,
    FmAccuracy.approximate => l10n.fmEmuAccuracyApproximate,
  };
  final cpu = switch (e.cpu) {
    FmCpu.light => l10n.fmEmuCpuLight,
    FmCpu.medium => l10n.fmEmuCpuMedium,
    FmCpu.heavy => l10n.fmEmuCpuHeavy,
  };
  return '$acc · $cpu';
}

/// The emulator setting as a row: name + tags, a list on tap (a dropdown has
/// no room for the tags). A value not in [list] shows as the first one, like
/// the native fallback does.
class FmEmulatorTile extends StatelessWidget {
  const FmEmulatorTile({
    super.key,
    required this.list,
    required this.value,
    required this.onChanged,
  });

  final List<FmEmulator> list;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cur = list.firstWhere((e) => e.value == value, orElse: () => list.first);
    return ListTile(
      title: Text(l10n.settingsAdlEmulator),
      subtitle: Text('${cur.name} — ${fmEmulatorTags(l10n, cur)}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final v = await showDialog<int>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text(l10n.settingsAdlEmulator),
            children: [
              for (final e in list)
                ListTile(
                  title: Text(e.name),
                  subtitle: Text(fmEmulatorTags(l10n, e)),
                  selected: e.value == cur.value,
                  trailing: e.value == cur.value ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(ctx, e.value),
                ),
            ],
          ),
        );
        if (v != null) onChanged(v);
      },
    );
  }
}
