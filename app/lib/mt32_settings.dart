
import 'package:file_picker/file_picker.dart' as fp;
import 'picker_memory.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'app_snack.dart';
import 'l10n.dart';
import 'local_open.dart' show consumeInboxCopy;
import 'mt32_rom_manager.dart';
import 'settings_screen.dart' show SettingRow;
import 'user_settings.dart';

/// Settings → Engines → « Munt (mt32emu) »: the ROM set (import / list /
/// remove — the engine identifies each file, nothing is bundled) and the
/// emulation knobs (model, reverb, gain). Its OWN engine page (user request,
/// 2026-09-11): a second engine with its own ROMs, not a FluidLite detail.
/// Which engine plays a .mid is chosen in « Décodeurs par défaut », with the
/// other engine choices.
/// Reset: the 'mt32' group, so resetting FluidLite never swaps the model.
class Mt32EnginePanel extends StatefulWidget {
  const Mt32EnginePanel({super.key});

  @override
  State<Mt32EnginePanel> createState() => _Mt32EnginePanelState();
}

class _Mt32EnginePanelState extends State<Mt32EnginePanel> {
  final _s = UserSettings.instance;
  bool _busy = false;

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

  Future<void> _import() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    List<String> paths;
    if (pickerUsesFilePicker) {
      // MOBILE: file_picker, pas file_selector, et pour DEUX raisons
      // différentes selon la plateforme.
      //
      // Android: file_selector y renomme la copie d'après le MIME résolu, et
      // un .rom devient octet-stream — le fichier arriverait en « rom.bin ».
      //
      // ⚠️ iOS: file_selector n'accepte QUE des UTI
      // (`XTypeGroup.uniformTypeIdentifiers`); un groupe qui ne porte que des
      // `extensions` lui fait lever un ArgumentError avant même d'ouvrir le
      // panneau — donc le bouton « importer » ne faisait RIEN, sans message ni
      // trace visible. Et il n'existe pas d'UTI pour un .rom de MT-32: le seul
      // filtre honnête serait `public.data`, c'est-à-dire aucun filtre. Autant
      // prendre la porte que le reste de l'app utilise déjà sur mobile
      // (`pickAnyFilePaths`), d'autant que la validation ne vient pas de
      // l'extension mais du SHA1 comparé à la table de mt32emu.
      //
      // file_picker 12: `pickFiles` rend directement la liste (choix multiple).
      final res = await fp.FilePicker.pickFiles(type: fp.FileType.any);
      paths = [for (final f in res) if (f.path != null) f.path!];
    } else {
      const group = XTypeGroup(label: 'ROM', extensions: ['rom', 'bin', 'ROM', 'BIN']);
      final xfs = await openFiles(
          acceptedTypeGroups: const [group],
          initialDirectory: await PickerMemory.startDir(PickerSlot.mt32Roms));
      paths = [for (final x in xfs) x.path];
      if (paths.isNotEmpty) await PickerMemory.rememberFile(PickerSlot.mt32Roms, paths.first);
    }
    if (paths.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await Mt32RomManager.instance.importFiles(paths);
      for (final src in paths) {
        await consumeInboxCopy(src);
      }
      if (!mounted) return;
      if (r.imported.isNotEmpty) {
        AppSnack.showOn(messenger, l10n.settingsMt32ImportDone(r.imported.length));
      }
      for (final name in r.rejected) {
        AppSnack.showOn(messenger, l10n.settingsMt32ImportRejected(name),
            duration: const Duration(seconds: 4));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final mgr = Mt32RomManager.instance;
    final status = mgr.status();
    final roms = mgr.list();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          dense: true,
          leading: Icon(status.isEmpty ? Icons.memory_outlined : Icons.memory,
              color: status.isEmpty ? cs.error : cs.primary),
          title: Text(l10n.settingsMt32RomsTitle),
          subtitle: Text(status.isEmpty
              ? l10n.settingsMt32RomsMissing
              : l10n.settingsMt32RomsActive(status)),
        ),
        for (final r in roms)
          ListTile(
            dense: true,
            leading: const Icon(Icons.sd_card_outlined, size: 20),
            title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
                '${r.description.isEmpty ? '?' : r.description} — ${(r.sizeBytes / 1024).round()} KB',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: l10n.commonDelete,
              onPressed: () async {
                await mgr.delete(r.name);
                if (mounted) setState(() {});
              },
            ),
          ),
        ListTile(
          leading: _busy
              ? const SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.folder_open),
          title: Text(l10n.settingsMt32Import),
          subtitle: Text(l10n.settingsMt32ImportSubtitle),
          onTap: _busy ? null : _import,
        ),
        SettingRow(
          label: l10n.settingsMt32Model,
          resetKey: 'mt32Model',
          child: DropdownButton<int>(
            value: _s.mt32Model,
            isDense: true,
            isExpanded: true,
            items: [
              DropdownMenuItem(value: 0, child: Text(l10n.settingsMt32ModelAuto, overflow: TextOverflow.ellipsis)),
              const DropdownMenuItem(value: 1, child: Text('MT-32')),
              const DropdownMenuItem(value: 2, child: Text('CM-32L')),
            ],
            onChanged: (v) { if (v != null) _s.mt32Model = v; },
          ),
        ),
        SettingRow(
          label: l10n.settingsMt32Reverb,
          resetKey: 'mt32Reverb',
          child: Switch(
            value: _s.mt32Reverb,
            onChanged: (v) => _s.mt32Reverb = v,
          ),
        ),
        SettingRow(
          label: l10n.settingsMasterVolume,
          resetKey: 'mt32Gain',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 160,
                child: Slider(
                  value: _s.mt32Gain.clamp(0.25, 3.0),
                  min: 0.25,
                  max: 3.0,
                  divisions: 11,
                  onChanged: (v) => _s.mt32Gain = v,
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(l10n.settingsValuePercent((_s.mt32Gain * 100).round()),
                    textAlign: TextAlign.end),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              icon: const Icon(Icons.restart_alt, size: 16),
              label: Text(l10n.settingsResetEngine),
              onPressed: () => _s.resetEngineSettings('mt32'),
            ),
          ),
        ),
      ],
    );
  }
}
