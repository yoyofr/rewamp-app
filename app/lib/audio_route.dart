import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rewamp_audio/rewamp_audio.dart';

import 'l10n.dart';

/// Audio output ("route") picker, per platform:
/// - iOS: the system AVRoutePickerView (AirPlay / Bluetooth) — a hidden native
///   picker whose button is triggered over a MethodChannel; it routes the
///   whole audio session, which is what miniaudio plays through.
/// - Android: the system Output Switcher panel (same as the media
///   notification's output chip; falls back to Bluetooth settings).
/// - macOS: our own device sheet — AVRoutePickerView only routes AVPlayer
///   content there, NOT our CoreAudio output, so the engine enumerates the
///   playback devices (miniaudio context) and swaps its device.
class AudioRoute {
  AudioRoute._();

  static const _ch = MethodChannel('rewamp/route_picker');

  static bool get supported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isMacOS);

  /// [context] should be the tapped button's — on iPad the native picker's
  /// popover anchors to its rect.
  static Future<void> show(BuildContext context, RewampAudio audio) async {
    if (Platform.isMacOS) return _showDeviceSheet(context, audio);
    if (Platform.isAndroid) {
      try {
        await _ch.invokeMethod('show');
      } catch (_) {/* no handler (old build) — nothing to open */}
      return;
    }
    // iOS — anchor rect in logical points == UIKit points.
    Rect r = Rect.zero;
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      r = box.localToGlobal(Offset.zero) & box.size;
    }
    try {
      await _ch.invokeMethod('show',
          {'x': r.left, 'y': r.top, 'w': r.width, 'h': r.height});
    } catch (_) {}
  }

  static Future<void> _showDeviceSheet(
      BuildContext context, RewampAudio audio) async {
    final devices = audio.outputDevices();
    if (devices.isEmpty) return;
    final explicit = devices.any((d) => d.selected);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(l10n.audioOutput,
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              // System default first — also re-enables default-device
              // following (the engine tracks the default when unpinned).
              ListTile(
                leading: const Icon(Icons.speaker_outlined),
                title: Text(l10n.audioOutputSystemDefault),
                trailing: !explicit ? const Icon(Icons.check) : null,
                onTap: () {
                  audio.setOutputDevice(-1);
                  Navigator.pop(ctx);
                },
              ),
              for (final d in devices)
                ListTile(
                  leading: Icon(d.isDefault
                      ? Icons.speaker
                      : Icons.speaker_outlined),
                  title: Text(d.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: d.selected ? const Icon(Icons.check) : null,
                  onTap: () {
                    audio.setOutputDevice(d.index);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
