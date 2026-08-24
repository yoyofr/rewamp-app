import 'package:flutter/material.dart';
import 'package:rewamp_audio/rewamp_audio.dart';

import 'artwork_palette.dart';
import 'l10n.dart';

/// Compact voice-control sheet: voices grouped by chip, one small pill per
/// voice. Tap a pill = mute/unmute; LONG-PRESS = solo (mutes everything else;
/// long-press the solo'd voice again to restore the previous state). A chip
/// header switch toggles its whole group, and a master button toggles all.
/// Muting is applied to the engine immediately via the generic voice mute
/// mask (bit v set ⇒ voice v muted).
class VoicesSheet extends StatefulWidget {
  final RewampAudio audio;
  const VoicesSheet({super.key, required this.audio});

  static void show(BuildContext context, RewampAudio audio) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      // Follows the player's artwork tint when one is active (null = theme).
      backgroundColor: PlayerTint.panel(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      // Separate route → the player's dark tint theme must be re-applied here
      // or a light app theme puts black text on the deep panel.
      builder: (ctx) => PlayerTint.wrap(ctx, VoicesSheet(audio: audio)),
    );
  }

  @override
  State<VoicesSheet> createState() => _VoicesSheetState();
}

class _Chip {
  final int index;
  final String name;
  final int start;
  final int count;
  const _Chip(this.index, this.name, this.start, this.count);
}

class _VoicesSheetState extends State<VoicesSheet> {
  late final List<_Chip> _chips;
  late final List<String> _voiceNames;
  late int _voiceCount;
  /// Stereo-only backend: the chip/voice names are UI labels, not engine data,
  /// so they are resolved from [AppLocalizations] in build (never in initState,
  /// where an inherited-widget lookup isn't allowed).
  bool _stereoFallback = false;

  // Solo state: voice index currently solo'd + the mask to restore on exit.
  int? _soloVoice;
  int _maskBeforeSolo = 0;

  @override
  void initState() {
    super.initState();
    final a = widget.audio;
    _voiceCount = a.voiceCount;
    if (_voiceCount > 0) {
      _chips = [
        for (var c = 0; c < a.chipCount; c++)
          _Chip(c, a.chipName(c), a.chipVoiceStart(c), a.chipVoiceCount(c)),
      ];
      _voiceNames = [for (var v = 0; v < _voiceCount; v++) a.voiceName(v)];
    } else {
      // Stereo-only backend (APE, vgmstream, miniaudio…): expose the output
      // channels as two pseudo-voices — the datasource mutes L/R on mask
      // bits 0/1, and the stereo oscilloscope shows that very output.
      _voiceCount = 2;
      _stereoFallback = true;
      _chips = const [];
      _voiceNames = const [];
    }
  }

  bool get _allOn => widget.audio.voiceMuteMask == 0;

  void _toggleVoice(int v) {
    final a = widget.audio;
    _soloVoice = null; // manual edit ends any solo session
    setState(() => a.setVoiceEnabled(v, !a.voiceEnabled(v)));
  }

  void _toggleSolo(int v) {
    final a = widget.audio;
    setState(() {
      if (_soloVoice == v) {
        // Exit solo: restore the pre-solo state.
        a.voiceMuteMask = _maskBeforeSolo;
        _soloVoice = null;
      } else {
        if (_soloVoice == null) _maskBeforeSolo = a.voiceMuteMask;
        var mask = 0;
        for (var i = 0; i < _voiceCount && i < 64; i++) {
          if (i != v) mask |= 1 << i;
        }
        a.voiceMuteMask = mask;
        _soloVoice = v;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final a = widget.audio;

    if (_voiceCount == 0) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(l10n.voicesNone),
      );
    }

    final chips = _stereoFallback
        ? [_Chip(0, l10n.voicesStereoOutput, 0, 2)]
        : _chips;
    final names = _stereoFallback
        ? [l10n.voicesLeft, l10n.voicesRight]
        : _voiceNames;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 2),
              child: Row(
                children: [
                  Text(l10n.voicesTitle, style: tt.titleMedium),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.voicesLongPressSolo,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                  TextButton.icon(
                    icon: Icon(_allOn ? Icons.volume_up : Icons.volume_off,
                        size: 18),
                    label: Text(_allOn ? l10n.voicesMuteAll : l10n.voicesUnmuteAll),
                    onPressed: () => setState(() {
                      _soloVoice = null;
                      a.setAllVoicesEnabled(!_allOn);
                    }),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  for (final chip in chips) _chipSection(chip, names, cs, tt, a),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipSection(_Chip chip, List<String> names, ColorScheme cs,
      TextTheme tt, RewampAudio a) {
    bool chipOn = false;
    for (var v = chip.start; v < chip.start + chip.count; v++) {
      if (a.voiceEnabled(v)) {
        chipOn = true;
        break;
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(chip.name.isEmpty ? '—' : chip.name,
                    style: tt.labelLarge),
              ),
              // Compact per-chip toggle (voice loop — also works for the
              // synthetic stereo chip, which the engine doesn't know about).
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: chipOn,
                  onChanged: (on) => setState(() {
                    _soloVoice = null;
                    for (var v = chip.start;
                        v < chip.start + chip.count && v < _voiceCount;
                        v++) {
                      a.setVoiceEnabled(v, on);
                    }
                  }),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var v = chip.start;
                  v < chip.start + chip.count && v < _voiceCount;
                  v++)
                _voicePill(v, names, cs, tt, a),
            ],
          ),
        ],
      ),
    );
  }

  Widget _voicePill(int v, List<String> names, ColorScheme cs, TextTheme tt,
      RewampAudio a) {
    final enabled = a.voiceEnabled(v);
    final solo = _soloVoice == v;
    final name = (v < names.length && names[v].isNotEmpty)
        ? names[v]
        : '${v + 1}';
    // On an artwork-tinted panel the pills follow the same hue; solo keeps the
    // theme's tertiary so it still stands out as a distinct state.
    final tintFill = PlayerTint.container(context);
    final tintText = PlayerTint.onContainer(context);
    final fill = enabled
        ? (solo
            ? cs.tertiaryContainer
            : (tintFill ?? cs.primaryContainer))
        : (tintFill ?? cs.surfaceContainerHighest).withAlpha(60);
    final fg = enabled
        ? (solo
            ? cs.onTertiaryContainer
            : (tintText ?? cs.onPrimaryContainer))
        : (tintText ?? cs.onSurfaceVariant).withAlpha(140);
    return GestureDetector(
      onTap: () => _toggleVoice(v),
      onLongPress: () => _toggleSolo(v),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: solo ? Border.all(color: cs.tertiary, width: 1.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (solo) ...[
              Icon(Icons.headphones, size: 13, color: cs.onTertiaryContainer),
              const SizedBox(width: 4),
            ],
            Text(
              name,
              style: tt.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: fg,
                decoration: enabled ? null : TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
