import 'package:flutter/material.dart';

import 'l10n.dart';
import 'user_settings.dart';

/// One format an engine SHARES with another, and the « Décodeurs par
/// défaut » choice that makes this engine the one that plays it.
class DecoderDefault {
  const DecoderDefault(this.format, this.isCurrent, this.select);

  /// The format as « Décodeurs par défaut » names it.
  final String Function(AppLocalizations l10n) format;
  final bool Function(UserSettings s) isCurrent;
  final void Function(UserSettings s) select;
}

String _nsf(AppLocalizations _) => 'NSF / NSFe';
String _gbs(AppLocalizations _) => 'GBS';
String _midi(AppLocalizations _) => 'MIDI';
String _amiga(AppLocalizations l10n) => l10n.settingsDecoderAmigaTrackers;
String _dos(AppLocalizations l10n) => l10n.settingsDecoderDosMidi;
String _sndh(AppLocalizations _) => 'SNDH';

/// Engine page id (kEngineSettingsPages) → the shared formats it can be the
/// default player of. The SAME settings as « Décodeurs par défaut » — this is
/// a shortcut to them, never a second copy of the choice. AtariAudio has no
/// engine page (nothing to set), so its SNDH choice lives there only. MIDI « auto » plays
/// FluidLite (the MT-32 only on files carrying its sysex), hence FluidLite is
/// current under « auto » too.
final Map<String, List<DecoderDefault>> kDefaultDecoderShortcuts = {
  'nsfplay': [
    DecoderDefault(_nsf, (s) => s.nsfPlugin == 'nsfplay', (s) => s.nsfPlugin = 'nsfplay'),
  ],
  'libgme': [
    DecoderDefault(_nsf, (s) => s.nsfPlugin == 'libgme', (s) => s.nsfPlugin = 'libgme'),
    DecoderDefault(_gbs, (s) => s.gbsPlugin == 'libgme', (s) => s.gbsPlugin = 'libgme'),
  ],
  'psgplay': [
    DecoderDefault(_sndh, (s) => s.sndhPlugin == 'psgplay',
        (s) => s.sndhPlugin = 'psgplay'),
  ],
  'gbsplay': [
    DecoderDefault(_gbs, (s) => s.gbsPlugin == 'gbsplay', (s) => s.gbsPlugin = 'gbsplay'),
  ],
  'libopenmpt': [
    DecoderDefault(_amiga, (s) => s.amigaTrackerPlugin == 'openmpt',
        (s) => s.amigaTrackerPlugin = 'openmpt'),
  ],
  'libxmp': [
    DecoderDefault(_amiga, (s) => s.amigaTrackerPlugin == 'xmp',
        (s) => s.amigaTrackerPlugin = 'xmp'),
  ],
  'uade': [
    DecoderDefault(_amiga, (s) => s.amigaTrackerPlugin == 'uade',
        (s) => s.amigaTrackerPlugin = 'uade'),
  ],
  'fluidlite': [
    DecoderDefault(_midi, (s) => s.midiSynth == 'soundfont' || s.midiSynth == 'auto',
        (s) => s.midiSynth = 'soundfont'),
  ],
  'mt32': [
    DecoderDefault(_midi, (s) => s.midiSynth == 'mt32', (s) => s.midiSynth = 'mt32'),
  ],
  'adlmidi': [
    DecoderDefault(_midi, (s) => s.midiSynth == 'opl3', (s) => s.midiSynth = 'opl3'),
    DecoderDefault(_dos, (s) => s.dosMidiPlugin != 'opnmidi',
        (s) => s.dosMidiPlugin = 'adlmidi'),
  ],
  'opnmidi': [
    DecoderDefault(_midi, (s) => s.midiSynth == 'opn2', (s) => s.midiSynth = 'opn2'),
    DecoderDefault(_dos, (s) => s.dosMidiPlugin == 'opnmidi',
        (s) => s.dosMidiPlugin = 'opnmidi'),
  ],
};

/// The top rows of an engine page: « Default player for MIDI » — a check when
/// it already is, a tap to make it so otherwise. Nothing for an engine that
/// shares no format.
class DefaultDecoderShortcuts extends StatelessWidget {
  const DefaultDecoderShortcuts({super.key, required this.engine});

  /// Page id in kEngineSettingsPages ('adlmidi', 'libgme'…).
  final String engine;

  @override
  Widget build(BuildContext context) {
    final list = kDefaultDecoderShortcuts[engine];
    if (list == null) return const SizedBox.shrink();
    final s = UserSettings.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final l10n = context.l10n;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in list)
              Builder(builder: (context) {
                final current = d.isCurrent(s);
                return ListTile(
                  leading: Icon(current ? Icons.check_circle : Icons.star_outline,
                      color: current ? Theme.of(context).colorScheme.primary : null),
                  title: Text(l10n.settingsDefaultFor(d.format(l10n))),
                  subtitle: Text(current
                      ? l10n.settingsDefaultForActive
                      : l10n.settingsDefaultForSet(l10n.settingsDefaultDecoders)),
                  onTap: current ? null : () => d.select(s),
                );
              }),
          ],
        );
      },
    );
  }
}
