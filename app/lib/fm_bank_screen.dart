import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'app_snack.dart';
import 'engine_choices.dart';
import 'fm_bank_manager.dart';
import 'l10n.dart';
import 'local_open.dart' show consumeInboxCopy;
import 'picker_memory.dart';
import 'play_with_sheet.dart' show confirmDeleteChosen;
import 'shell_insets.dart';
import 'user_settings.dart';

/// The bank of an FM engine as a settings row shows it: the imported bank
/// when one is selected and present, else the embedded one.
String fmBankLabel(FmBankKind kind, List<String> builtin, int builtinIndex) {
  final file = FmBankManager.instance.selectedFileName(kind);
  if (file != null && FmBankManager.instance.selectedPath(kind) != null) {
    final dot = file.lastIndexOf('.');
    return dot > 0 ? file.substring(0, dot) : file;
  }
  return builtinIndex >= 0 && builtinIndex < builtin.length
      ? builtin[builtinIndex]
      : '#$builtinIndex';
}

/// Imports bank files (WOPL / WOPN, told by their header) and SELECTS the
/// last one for its engine: opening a bank — from this screen, a drop on the
/// window or a double-click — means « play with it ». Says what happened.
Future<void> importFmBanks(
    ScaffoldMessengerState messenger, AppLocalizations l10n, List<String> paths) async {
  for (final path in paths) {
    final name = path.split(RegExp(r'[/\\]')).last;
    try {
      final (kind, bank) = await FmBankManager.instance.import(path);
      FmBankManager.instance.select(kind, bank.fileName);
      AppSnack.showOn(messenger, l10n.fmBankImported(bank.name, kind.engineName));
    } on FormatException {
      AppSnack.showOn(messenger, l10n.fmBankImportInvalid(name), isError: true);
    } catch (e) {
      AppSnack.showOn(messenger, l10n.fmBankImportInvalid(name), isError: true);
    }
    // iOS: la copie que le sélecteur / « Ouvrir dans » a posée chez nous est
    // lue, elle part (le fichier de l'utilisateur, lui, n'est jamais touché).
    await consumeInboxCopy(path);
  }
}

/// The platform's file browser, for [kind]'s banks, then [importFmBanks].
/// Desktop filters on the extension (file_selector, last folder remembered);
/// MOBILE takes any file through file_picker, like the MT-32 ROMs and for the
/// same reasons — no UTI exists for a .wopl, and file_selector on iOS accepts
/// UTIs only (an extension-only group throws before the panel opens). The
/// header decides anyway.
Future<void> pickAndImportFmBanks(BuildContext context, FmBankKind kind) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  List<String> paths;
  if (pickerUsesFilePicker) {
    paths = await pickAnyFilePaths(PickerSlot.fmBanks);
  } else {
    final group = XTypeGroup(
        label: kind.ext.toUpperCase(),
        extensions: [kind.ext, kind.ext.toUpperCase()]);
    final xfs = await openFiles(
        acceptedTypeGroups: [group],
        initialDirectory: await PickerMemory.startDir(PickerSlot.fmBanks));
    paths = [for (final x in xfs) x.path];
  }
  if (paths.isEmpty) return;
  await PickerMemory.rememberFile(PickerSlot.fmBanks, paths.first);
  await importFmBanks(messenger, l10n, paths);
}

/// The row of the bank screen that opens the platform's file browser for
/// [kind]'s banks, like the MT-32 ROM import — the ONE import entry in the
/// app (the engine pages lead here through their bank row).
class FmBankImportTile extends StatefulWidget {
  const FmBankImportTile({super.key, required this.kind});
  final FmBankKind kind;

  @override
  State<FmBankImportTile> createState() => _FmBankImportTileState();
}

class _FmBankImportTileState extends State<FmBankImportTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      leading: _busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.folder_open),
      title: Text(l10n.fmBanksImportTile),
      subtitle: Text(l10n.fmBanksImportSubtitle('.${widget.kind.ext}')),
      onTap: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                await pickAndImportFmBanks(context, widget.kind);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
    );
  }
}

/// Réglages → libADLMIDI / libOPNMIDI → Banque: the EMBEDDED banks (fixed)
/// and the IMPORTED ones (added by import here, a drop on the window or
/// « Ouvrir avec »; removable), filtered by name — libADLMIDI alone embeds 79.
class FmBankScreen extends StatefulWidget {
  const FmBankScreen({
    super.key,
    required this.kind,
    required this.builtin,
    required this.builtinIndex,
    required this.onSelectBuiltin,
  });

  final FmBankKind kind;
  final List<String> builtin;
  final int Function() builtinIndex;
  final void Function(int index) onSelectBuiltin;

  @override
  State<FmBankScreen> createState() => _FmBankScreenState();
}

class _FmBankScreenState extends State<FmBankScreen> {
  final _filter = TextEditingController();
  final _mgr = FmBankManager.instance;
  List<FmUserBank> _imported = const [];

  @override
  void initState() {
    super.initState();
    _reload();
    _mgr.generation.addListener(_reload);
    UserSettings.instance.addListener(_onSettings);
    _filter.addListener(_onSettings);
  }

  @override
  void dispose() {
    _mgr.generation.removeListener(_reload);
    UserSettings.instance.removeListener(_onSettings);
    _filter.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _imported = _mgr.userBanks(widget.kind));
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  Future<void> _delete(FmUserBank b) async {
    final l10n = context.l10n;
    final engine = widget.kind.engine;
    final ok = await confirmDeleteChosen(context,
        name: b.name,
        usage: EngineChoices.instance.importedBankUsage(engine, b.fileName),
        title: l10n.fmBankInUseTitle,
        outro: l10n.fmBankInUseOutro,
        plain: l10n.fmBankDeleteConfirm(b.name));
    if (!ok) return;
    EngineChoices.instance.forgetImportedBank(engine, b.fileName);
    await _mgr.delete(widget.kind, b.fileName);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final q = _filter.text;
    final selectedFile = _mgr.selectedPath(widget.kind) != null
        ? _mgr.selectedFileName(widget.kind)
        : null;
    final idx = widget.builtinIndex();
    final builtin = [
      for (var i = 0; i < widget.builtin.length; i++)
        if (fmBankNameMatches(widget.builtin[i], q)) i,
    ];
    final imported = [
      for (final b in _imported)
        if (fmBankNameMatches(b.name, q)) b,
    ];
    final theme = Theme.of(context);
    Widget header(String t) => Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
          child: Text(t,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.settingsAdlBank} — ${widget.kind.engineName}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _filter,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.fmBanksFilterHint,
                isDense: true,
                suffixIcon: q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: l10n.commonClear,
                        onPressed: _filter.clear,
                      ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: shellInset(context, EdgeInsets.zero),
              children: [
                header('${l10n.fmBanksImported} (${imported.length})'),
                FmBankImportTile(kind: widget.kind),
                if (_imported.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(l10n.fmBanksImportedEmpty,
                        style: theme.textTheme.bodySmall),
                  ),
                for (final b in imported)
                  ListTile(
                    title: Text(b.name),
                    selected: b.fileName == selectedFile,
                    leading: Icon(b.fileName == selectedFile
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.commonDelete,
                      onPressed: () => _delete(b),
                    ),
                    onTap: () => _mgr.select(widget.kind, b.fileName),
                  ),
                header('${l10n.fmBanksBuiltIn} (${builtin.length})'),
                for (final i in builtin)
                  ListTile(
                    title: Text(widget.builtin[i]),
                    selected: selectedFile == null && i == idx,
                    leading: Icon(selectedFile == null && i == idx
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked),
                    onTap: () {
                      _mgr.select(widget.kind, null);
                      widget.onSelectBuiltin(i);
                    },
                  ),
                if (q.isNotEmpty && builtin.isEmpty && imported.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.fmBanksNoMatch,
                        textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// « Lire avec… » → Banque: picks the bank of ONE file (or album) among the
/// embedded and imported ones, or « the setting's » (null). Pops `(choice,)`
/// — a record, since null is a choice; nothing popped = cancelled. No import
/// nor delete here: the bank screen of Settings owns them.
class FmBankPickScreen extends StatefulWidget {
  const FmBankPickScreen({
    super.key,
    required this.kind,
    required this.builtin,
    required this.selected,
    required this.settingLabel,
  });

  final FmBankKind kind;
  final List<String> builtin;
  final FmBankRef? selected;

  /// The bank the engine's setting plays, as its row shows it.
  final String settingLabel;

  @override
  State<FmBankPickScreen> createState() => _FmBankPickScreenState();
}

class _FmBankPickScreenState extends State<FmBankPickScreen> {
  final _filter = TextEditingController();
  late final List<FmUserBank> _imported =
      FmBankManager.instance.userBanks(widget.kind);

  @override
  void initState() {
    super.initState();
    _filter.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final q = _filter.text;
    final sel = widget.selected;
    Widget header(String t) => Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
          child: Text(t,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
        );
    Widget row(String title, FmBankRef? ref) {
      final on = sel == ref;
      return ListTile(
        title: Text(title),
        selected: on,
        leading: Icon(on ? Icons.radio_button_checked : Icons.radio_button_unchecked),
        onTap: () => Navigator.pop(context, (ref,)),
      );
    }

    final imported = [
      for (final b in _imported)
        if (fmBankNameMatches(b.name, q)) b,
    ];
    final builtin = [
      for (var i = 0; i < widget.builtin.length; i++)
        if (fmBankNameMatches(widget.builtin[i], q)) i,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.settingsAdlBank} — ${widget.kind.engineName}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _filter,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.fmBanksFilterHint,
                isDense: true,
                suffixIcon: q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: l10n.commonClear,
                        onPressed: _filter.clear,
                      ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: shellInset(context, EdgeInsets.zero),
              children: [
                row(l10n.playWithBankDefault(widget.settingLabel), null),
                if (imported.isNotEmpty)
                  header('${l10n.fmBanksImported} (${imported.length})'),
                for (final b in imported) row(b.name, FmBankImported(b.fileName)),
                header('${l10n.fmBanksBuiltIn} (${builtin.length})'),
                for (final i in builtin) row(widget.builtin[i], FmBankBuiltin(i)),
                if (q.isNotEmpty && builtin.isEmpty && imported.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.fmBanksNoMatch, textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How a bank choice shows: the imported bank's name, else the embedded one.
String fmBankRefLabel(FmBankRef ref, List<String> builtin) => switch (ref) {
      FmBankImported(:final fileName) => fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName,
      FmBankBuiltin(:final index) =>
        index < builtin.length ? builtin[index] : '#$index',
    };
