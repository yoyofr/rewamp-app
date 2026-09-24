import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'picker_memory.dart';
import 'package:share_plus/share_plus.dart';
import 'home_sections.dart';
import 'shell_tabs.dart';
import 'l10n.dart';
import 'mini_window.dart';
import 'release_notes.dart'
    show kReleaseNotesLabel, showReleaseNotes;
import 'account_screen.dart';
import 'app_snack.dart';
import 'backup_service.dart';
import 'onboarding.dart';
import 'pattern_scope_widget.dart' show PatternPalette;
import 'preset_screen.dart';
import 'screen_wakelock.dart';
import 'data_reset.dart' show runLocalCleanup;
import 'sync_service.dart';
import 'user_settings.dart';
import 'client_info.dart';
import 'package:url_launcher/url_launcher.dart';

import 'engines.dart';
import 'engine_formats_screen.dart';
import 'soundfont_manager.dart';
import 'mt32_rom_manager.dart';
import 'mt32_settings.dart';
import 'local_db.dart';
import 'artwork_image.dart';
import 'rewamp_db.dart';
import 'local_open.dart';
import 'storage_screen.dart';

/// Page de réglages d'un MOTEUR, ouvrable sans passer par l'écran Réglages —
/// le raccourci « Réglages du moteur » du menu « … » du lecteur.
///
/// La clé est le SLUG que le moteur publie (`audio.backendName`), pas le
/// libellé affiché: c'est la seule chose que le lecteur connaisse du décodeur
/// qui joue. Tous les moteurs n'ont pas de page — un slug absent d'ici veut
/// dire « rien à régler », et l'action ne s'affiche simplement pas.
class EngineSettingsPage {
  final String title;
  final List<Widget> Function(BuildContext) children;
  const EngineSettingsPage(this.title, this.children);
}

/// Slug de moteur → sa page. Voir [EngineSettingsPage]; les libellés sont
/// ceux des tuiles de la section « Moteurs » (le nom de la BIBLIOTHÈQUE, pas
/// de la console: une même bibliothèque couvre plusieurs formats).
const Map<String, EngineSettingsPage> kEngineSettingsPages = {
  'libopenmpt':   EngineSettingsPage('libopenmpt', SettingsScreen.omptChildren),
  'libxmp':       EngineSettingsPage('libxmp', SettingsScreen.xmpChildren),
  'libgme':       EngineSettingsPage('libgme', SettingsScreen.gmeChildren),
  'nsfplay':      EngineSettingsPage('nsfplay', SettingsScreen.nsfChildren),
  'gbsplay':      EngineSettingsPage('gbsplay', SettingsScreen.gbsChildren),
  'fluidlite':    EngineSettingsPage('FluidLite', SettingsScreen.midiChildren),
  'mt32':         EngineSettingsPage('Munt (mt32emu)', SettingsScreen.mt32Children),
  'gsf':          EngineSettingsPage('libgsf (VBA)', SettingsScreen.gsfChildren),
  'uade':         EngineSettingsPage('UADE', SettingsScreen.uadeChildren),
  'libsidplayfp': EngineSettingsPage('libsidplayfp', SettingsScreen.sidChildren),
  'adplug':       EngineSettingsPage('AdPlug', SettingsScreen.adplugChildren),
  'highlyexp':    EngineSettingsPage(
      'Highly Experimental', SettingsScreen.heChildren),
  'libvgm':       EngineSettingsPage('libvgm', SettingsScreen.vgmChildren),
};

/// L'ordre d'affichage des moteurs dans Réglages: par NOM, insensible à la
/// casse.
///
/// La casse compte ici pour de vrai: comparer les chaînes telles quelles range
/// toutes les majuscules avant toutes les minuscules (`AdPlug`, `FluidLite`,
/// `UADE`, PUIS `gbsplay`, `libgme`…), ce qui donne deux alphabets au lieu
/// d'un et met `UADE` loin de `libvgm`. Ce n'est pas ce qu'on lit dans une
/// liste.
int compareEngineNames(String a, String b) =>
    a.toLowerCase().compareTo(b.toLowerCase());

/// L'écran de réglages du moteur [slug], ou null si ce moteur n'a rien à
/// régler. Rendu comme WIDGET et non poussé: c'est l'APPELANT qui décide où —
/// et ce choix se voit, puisqu'un push sur le navigateur RACINE recouvre la
/// coquille, mini-lecteur compris (voir `pushEngineSettings`).
Widget? engineSettingsScreen(String slug) {
  final page = kEngineSettingsPages[slug];
  if (page == null) return null;
  return _SettingsSectionScreen(
    title: page.title,
    settings: UserSettings.instance,
    childrenBuilder: page.children,
  );
}

/// Pousse la page de réglages du moteur [slug] sur [nav]. Ne fait rien si ce
/// moteur n'a pas de page (l'appelant teste `kEngineSettingsPages.containsKey`).
///
/// Prend un NavigatorState et non un BuildContext: l'appelant du lecteur ferme
/// sa feuille juste avant, donc son context est déjà démonté au moment du push.
///
/// ⚠️ Le navigateur qu'on lui donne DÉCIDE de ce qu'on voit: sur le navigateur
/// RACINE la page recouvre toute la coquille — mini-lecteur et barre de
/// navigation compris. Depuis le lecteur, passer par l'onglet courant
/// (`_pushOnTab`) est ce qu'il faut: la page s'ouvre AVEC le mini-lecteur, et
/// la promesse de retour ramène au lecteur plein écran en la refermant.
void pushEngineSettings(NavigatorState nav, String slug) {
  final screen = engineSettingsScreen(slug);
  if (screen == null) return;
  nav.push(MaterialPageRoute(builder: (_) => screen));
}

class SettingsScreen extends StatefulWidget {
  /// Called after the play history has been successfully cleared, so the
  /// caller (AppShell) can refresh the recently-played list.
  final VoidCallback? onHistoryCleared;

  /// Called after a full database reset so AppShell can stop playback
  /// and clear any in-memory state derived from the DB.
  final VoidCallback? onDatabaseReset;

  /// Called BEFORE the downloads are deleted, and awaited: the player has to
  /// stop what it is playing and work out which queue entries die, and that
  /// resolution reads the rows and files the delete is about to remove.
  final Future<void> Function()? onOnlineLibraryDeleting;

  const SettingsScreen({
    super.key,
    this.onHistoryCleared,
    this.onDatabaseReset,
    this.onOnlineLibraryDeleting,
  });

  // Les contenus de page moteur, exposés pour [kEngineSettingsPages] — ils
  // sont statiques et ne lisent que UserSettings.instance, donc ouvrables
  // hors de cet écran.
  static List<Widget> omptChildren(BuildContext c) =>
      _SettingsScreenState._omptChildren(c);
  static List<Widget> xmpChildren(BuildContext c) =>
      _SettingsScreenState._xmpChildren(c);
  static List<Widget> gmeChildren(BuildContext c) =>
      _SettingsScreenState._gmeChildren(c);
  static List<Widget> nsfChildren(BuildContext c) =>
      _SettingsScreenState._nsfChildren(c);
  static List<Widget> gbsChildren(BuildContext c) =>
      _SettingsScreenState._gbsChildren(c);
  static List<Widget> midiChildren(BuildContext c) =>
      _SettingsScreenState._midiChildren(c);
  static List<Widget> mt32Children(BuildContext c) =>
      _SettingsScreenState._mt32Children(c);
  static List<Widget> gsfChildren(BuildContext c) =>
      _SettingsScreenState._gsfChildren(c);
  static List<Widget> uadeChildren(BuildContext c) =>
      _SettingsScreenState._uadeChildren(c);
  static List<Widget> sidChildren(BuildContext c) =>
      _SettingsScreenState._sidChildren(c);
  static List<Widget> adplugChildren(BuildContext c) =>
      _SettingsScreenState._adplugChildren(c);
  static List<Widget> heChildren(BuildContext c) =>
      _SettingsScreenState._heChildren(c);
  static List<Widget> vgmChildren(BuildContext c) =>
      _SettingsScreenState._vgmChildren(c);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // STATIQUE: les builders de page moteur sont statiques (voir
  // engineSettingsSlugs) pour qu'un raccourci puisse les ouvrir sans passer
  // par l'écran Réglages; ils lisent tous ce singleton.
  static final _settings = UserSettings.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _exportBackup(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    // iPad requires an anchor rect for the share popover.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      final (:bytes, :filename) = await BackupService.buildBackup();
      final tmp = await getTemporaryDirectory();
      final f = File(p.join(tmp.path, filename));
      await f.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(
          files: [XFile(f.path)],
          subject: filename,
          sharePositionOrigin: origin));
    } catch (_) {
      AppSnack.showOn(messenger, l10n.settingsBackupExportFailed,
          isError: true);
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    final l10n = context.l10n;

    // Pick the .rewampbackup (file_picker keeps the real name on Android).
    String? path;
    if (pickerUsesFilePicker) {   // voir pickerUsesFilePicker
      // `pickFile` (singulier) est la porte du choix UNIQUE en file_picker 12:
      // `pickFiles` sélectionne désormais plusieurs fichiers PAR DÉFAUT.
      final res = await fp.FilePicker.pickFile(type: fp.FileType.any);
      path = res?.path;
    } else {
      final xf = await openFile(
          initialDirectory: await PickerMemory.startDir(PickerSlot.backup),
          acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Rewamp',
          extensions: [BackupService.backupExtension, 'zip'],
        ),
      ]);
      path = xf?.path;
      await PickerMemory.rememberFile(PickerSlot.backup, path);
    }
    if (path == null || !context.mounted) return;

    // Destructive: replaces the whole library + settings.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsBackupImportConfirmTitle),
        content: Text(l10n.settingsBackupImportConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.settingsCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.settingsBackupImportConfirm)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await File(path).readAsBytes();
      // La copie d'iOS dans notre Inbox est à nous une fois lue — voir
      // consumeInboxCopy. Un .rewampbackup peut peser lourd.
      await consumeInboxCopy(path);
      await BackupService.restoreBackup(bytes);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.settingsBackupImportedTitle),
          content: Text(l10n.settingsBackupImportedBody),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.settingsOk)),
          ],
        ),
      );
    } on BackupException catch (e) {
      final msg = switch (e.error) {
        BackupError.newerVersion => l10n.settingsBackupTooNew,
        _ => l10n.settingsBackupInvalid,
      };
      AppSnack.showOn(messenger, msg, isError: true);
    } catch (_) {
      AppSnack.showOn(messenger, l10n.settingsBackupImportFailed,
          isError: true);
    }
  }

  Future<void> _renewUserId(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsRenewUserIdTitle),
        content: Text(l10n.settingsRenewUserIdBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.settingsCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.settingsRenew),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final uuid = await RewampDb.registerUser();
    if (!context.mounted) return;

    if (uuid != null && uuid.isNotEmpty) {
      await UserSettings.instance.setUserId(uuid);
      if (!context.mounted) return;
      AppSnack.show(context, l10n.settingsNewUserId(uuid));
    } else {
      AppSnack.show(context, l10n.settingsRenewUserIdFailed);
    }
  }

  Future<void> _cleanupOrphans(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final removed = await LocalDb.instance.purgeOrphanEntries();
    widget.onHistoryCleared?.call(); // refresh « écoutés récemment »
    AppSnack.showOn(messenger, removed > 0
          ? l10n.settingsOrphansRemoved(removed)
          : l10n.settingsDbClean);
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsClearStatsTitle),
        content: Text(l10n.settingsClearStatsBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.settingsCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.settingsDelete),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await LocalDb.instance.clearHistory();
    widget.onHistoryCleared?.call();

    if (!context.mounted) return;
    AppSnack.show(context, l10n.settingsStatsCleared);
  }

  Future<void> _clearCache(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final removed = await ArtworkCache.instance.clearCache();
    await LocalDb.instance.clearMetadataCache();
    if (!context.mounted) return;
    AppSnack.showOn(messenger, l10n.settingsCacheCleared(removed));
  }

  /// Retire les entrées de bibliothèque qui nomment un fichier local absent.
  /// Confirmation obligatoire: la purge touche AUSSI le compte, donc les
  /// autres appareils — c'est irréversible et il faut le dire avant.
  Future<void> _cleanMissingLocalEntries(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsCleanLocalTitle),
        content: Text(l10n.settingsCleanLocalBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.settingsCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.commonDelete)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final n = await _purgeMissingWithBarrier(context, navigator);
    AppSnack.showOn(messenger, l10n.settingsCleanLocalDone(n));
  }

  /// La purge des entrées injouables sous sa barrière d'étapes (scan → sync →
  /// purge → delete). Partagée par l'entrée « Avancé » et par le nettoyage
  /// groupé; ne demande PAS de confirmation, c'est à l'appelant de l'avoir
  /// obtenue — la purge touche le COMPTE.
  Future<int> _purgeMissingWithBarrier(
          BuildContext context, NavigatorState navigator) =>
      _withCleanBarrier(context, navigator,
          (stage) => SyncService.purgeMissingLocalLibraryEntries(onStage: stage));

  /// Le nettoyage GROUPÉ sous la même barrière. Null si le contexte est parti.
  Future<({int orphans, int missing, int artwork})?> _cleanWithBarrier(
          BuildContext context, NavigatorState navigator) =>
      _withCleanBarrier(context, navigator,
          (stage) => runLocalCleanup(onStage: stage));

  /// La barrière d'étapes partagée: elle MONTRE l'étape en cours, et c'est tout
  /// son intérêt — une barrière muette rend « long » indistinguable de
  /// « bloqué », ce qui a déjà été rapporté comme une boucle infinie.
  Future<T> _withCleanBarrier<T>(BuildContext context, NavigatorState navigator,
      Future<T> Function(void Function(String) onStage) body) async {
    // Le nettoyage demande une passe de synchro COMPLÈTE (hydrater les clés du
    // compte) et peut donc durer: mesuré sur un vrai profil, la passe sans
    // curseur applique plus de mille lignes une à une. Barrière non annulable
    // (interrompre laisserait la moitié des entrées purgées côté compte et
    // l'autre non) — mais elle DIT ce qu'elle fait: une barrière muette rend
    // « long » indistinguable de « bloqué », et c'est ce qui a été rapporté.
    final stage = ValueNotifier<String>('scan');
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(children: [
          const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 16),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: stage,
              builder: (c, v, _) => Text(switch (v) {
                'sync'   => c.l10n.cleanStageSync,
                'purge'  => c.l10n.cleanStagePurge,
                'delete' => c.l10n.cleanStageDelete,
                _        => c.l10n.cleanStageScan,
              }),
            ),
          ),
        ]),
      ),
    ));
    try {
      return await body((s) => stage.value = s);
    } finally {
      navigator.pop();   // ferme la barrière, même en cas d'échec
      stage.dispose();
    }
  }

  /// « Nettoyer la base locale et le cache »: les TROIS gestes d'un coup —
  /// entrées orphelines, entrées de bibliothèque injouables ici, cache des
  /// pochettes et métadonnées. Une seule confirmation (la purge touche le
  /// compte) et un seul message de fin, qui juxtapose les trois bilans déjà
  /// traduits plutôt que d'en inventer un quatrième.
  Future<void> _cleanDatabaseAndCache(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsCleanAll),
        content: Text(l10n.settingsCleanAllConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.settingsCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.commonDelete)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    // La séquence elle-même vit dans data_reset.dart, partagée avec le
    // nettoyage automatique du premier lancement d'une build: deux copies
    // finiraient par ne plus nettoyer la même chose. Ici on n'ajoute que la
    // barrière d'étapes et le bilan.
    final res = await _cleanWithBarrier(context, navigator);
    if (res == null) return;
    widget.onHistoryCleared?.call(); // refresh « écoutés récemment »
    AppSnack.showOn(
        messenger,
        [
          res.orphans > 0
              ? l10n.settingsOrphansRemoved(res.orphans)
              : l10n.settingsDbClean,
          l10n.settingsCleanLocalDone(res.missing),
          l10n.settingsCacheCleared(res.artwork),
        ].join(' · '),
        duration: const Duration(seconds: 6));
  }

  Future<void> _confirmResetDatabase(BuildContext context) async {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsResetDbTitle),
        content: Text(l10n.settingsResetDbBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.settingsCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.settingsReset),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await LocalDb.instance.resetDatabase();
    widget.onDatabaseReset?.call();

    if (!context.mounted) return;
    AppSnack.show(context, l10n.settingsDbReset);
  }

  Future<void> _confirmDeleteOnlineLibrary(BuildContext context) async {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsDeleteDownloadsTitle),
        content: Text(l10n.settingsDeleteDownloadsBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.settingsCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.settingsDelete),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // BEFORE the delete: stops playback if the playing file is a download, and
    // resolves the queue entries that are about to lose their file.
    await widget.onOnlineLibraryDeleting?.call();
    await RewampDb.deleteOnlineLibrary();

    if (!context.mounted) return;
    AppSnack.show(context, l10n.settingsDownloadsDeleted);
  }

  // ── Level 1: section list ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.account_circle_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: Text(l10n.accountTitle,
                style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(l10n.accountSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountScreen())),
          ),
          const Divider(height: 1),
          _sectionTile(Icons.tune,            l10n.settingsGeneral,
              l10n.settingsGeneralSubtitle, _generalChildren),
          _sectionTile(Icons.bar_chart,       l10n.settingsVisualisation,
              l10n.settingsVisualisationSubtitle, _visualisationChildren),
          _sectionTile(Icons.music_note,      l10n.settingsPlayback,
              l10n.settingsPlaybackSubtitle, _lectureChildren),
          _sectionTile(Icons.memory,          l10n.settingsEngines,
              l10n.settingsEnginesSubtitle, _enginesChildren),
          _sectionTile(Icons.storage_outlined,l10n.settingsData,
              l10n.settingsDataSubtitle, _dataChildren),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionTile(IconData icon, String title, String subtitle,
      List<Widget> Function(BuildContext) childrenBuilder) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _SettingsSectionScreen(
          title: title,
          settings: _settings,
          childrenBuilder: childrenBuilder,
        ),
      )),
    );
  }

  // ── Level 2: per-section content builders ────────────────────────────────

  List<Widget> _generalChildren(BuildContext context) {
    final l10n = context.l10n;
    return [
      _sectionResetButton('general'),
      SettingRow(
        label: l10n.settingsTheme,
        resetKey: 'themeMode',
        child: SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(
              value: ThemeMode.system,
              label: Text(l10n.settingsAuto),
              icon: const Icon(Icons.brightness_auto, size: 16),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              label: Text(l10n.settingsThemeLight),
              icon: const Icon(Icons.brightness_high, size: 16),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text(l10n.settingsThemeDark),
              icon: const Icon(Icons.brightness_3, size: 16),
            ),
          ],
          selected: {_settings.themeMode},
          onSelectionChanged: (s) => _settings.themeMode = s.first,
        ),
      ),
      // Bureau seulement. Vaut pour la fenêtre principale ET le mini lecteur
      // (c'est la même fenêtre); MiniWindow écoute le réglage et pose le natif.
      if (MiniWindow.instance.available && MiniWindow.alwaysOnTopSupported)
        SwitchListTile(
          secondary: const _ResetDot('windowAlwaysOnTop'),
          title: Text(l10n.settingsAlwaysOnTopTitle),
          subtitle: Text(l10n.settingsAlwaysOnTopSubtitle),
          value: _settings.windowAlwaysOnTop,
          onChanged: (v) => _settings.windowAlwaysOnTop = v,
        ),
      SwitchListTile(
        secondary: const _ResetDot('artworkTintedPlayer'),
        title: Text(l10n.settingsArtworkTintTitle),
        subtitle: Text(l10n.settingsArtworkTintSubtitle),
        value: _settings.artworkTintedPlayer,
        onChanged: (v) => _settings.artworkTintedPlayer = v,
      ),
      SwitchListTile(
        secondary: const _ResetDot('glassEffect'),
        title: Text(l10n.settingsGlassEffectTitle),
        subtitle: Text(l10n.settingsGlassEffectSubtitle),
        value: _settings.glassEffect,
        onChanged: (v) => _settings.glassEffect = v,
      ),
      ListTile(
        leading: const Icon(Icons.swap_vert),
        title: Text(l10n.homeSectionsOrderSettings),
        subtitle: Text(l10n.homeSectionsOrderSubtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openHomeSectionsOrder(context),
      ),
      // L'onglet d'ouverture. Une LISTE et non un menu déroulant: sept entrées
      // avec leur icône se lisent mieux, et un déroulant Material devient
      // scrollable dès qu'il déborde — sa première cellule perd alors ~8 px de
      // zone tactile (voir settings_long_picker_test).
      ListTile(
        leading: const Icon(Icons.flag_outlined),
        title: Text(l10n.settingsLaunchTab),
        subtitle: Text(_settings.launchTab.label(l10n)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _pickLaunchTab(context),
      ),
      // Réservé au TÉLÉPHONE: le rail de bureau montre tous les onglets, il
      // n'a ni barre à quatre places ni « Plus » à ranger.
      if (Platform.isAndroid || Platform.isIOS)
        ListTile(
          leading: const Icon(Icons.reorder),
          title: Text(l10n.settingsTabsOrderTitle),
          subtitle: Text(l10n.settingsTabsOrderSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openShellTabsOrder(context),
        ),
    ];
  }

  /// Choix de l'onglet de lancement. Le bouton de remise à zéro est DANS la
  /// liste (« Accueil » est le défaut, et le dire évite un troisième geste).
  Future<void> _pickLaunchTab(BuildContext context) async {
    final l10n = context.l10n;
    final chosen = await showDialog<ShellTab>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.settingsLaunchTab),
        children: [
          for (final t in kShellTabsDefault)
            ListTile(
              leading: Icon(t.icon),
              title: Text(t.label(l10n)),
              subtitle: t == ShellTab.home ? Text(l10n.settingsDefault) : null,
              trailing: _settings.launchTab == t
                  ? const Icon(Icons.check)
                  : null,
              selected: _settings.launchTab == t,
              onTap: () => Navigator.pop(ctx, t),
            ),
        ],
      ),
    );
    if (chosen != null) setState(() => _settings.launchTab = chosen);
  }

  List<Widget> _visualisationChildren(BuildContext context) {
    final l10n      = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cs        = Theme.of(context).colorScheme;
    return [
      _sectionResetButton('visualisation'),
      // Ce qui vaut pour TOUS les visualiseurs. Les sections qui suivent portent le
      // NOM du visualiseur auquel elles s'appliquent — celui des boutons du
      // sélecteur, pour qu'un réglage se retrouve là où on l'a vu agir.
      _SubHeader(label: l10n.settingsVizAll, cs: cs, textTheme: textTheme),

      SwitchListTile(
        secondary: const _ResetDot('showVisualizer'),
        title: Text(l10n.settingsStartInVizTitle),
        subtitle: Text(l10n.settingsStartInVizSubtitle),
        value: _settings.showVisualizer,
        onChanged: (v) => _settings.showVisualizer = v,
      ),
      // Platform-gated: Linux and Windows have no handler for it (their
      // desktop builds are not started), and a switch that does nothing is
      // worse than no switch.
      if (ScreenWakelock.supported)
        SwitchListTile(
          secondary: const _ResetDot('vizKeepAwake'),
          title: Text(l10n.settingsKeepAwakeTitle),
          subtitle: Text(l10n.settingsKeepAwakeSubtitle),
          value: _settings.vizKeepAwake,
          onChanged: (v) => _settings.vizKeepAwake = v,
        ),
      SettingRow(
        label: l10n.settingsVizFrameRate,
        resetKey: 'vizMaxFps',
        child: DropdownButton<int>(
          value: _settings.vizMaxFps,
          isDense: true,
          items: [
            DropdownMenuItem(value: 30, child: Text(l10n.settingsValueFps(30))),
            DropdownMenuItem(value: 60, child: Text(l10n.settingsValueFps(60))),
            DropdownMenuItem(value: 0, child: Text(l10n.settingsVizFrameRateScreen)),
          ],
          onChanged: (v) { if (v != null) _settings.vizMaxFps = v; },
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(l10n.settingsArtworkOpacity),
            subtitle: Text(l10n.settingsValuePercent(
                (_settings.vizArtworkOpacity * 100).round())),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.settingsValuePercent(
                      (_settings.vizArtworkOpacity * 100).round()),
                  style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const _ResetDot('vizArtworkOpacity'),
              ],
            ),
          ),
          Slider(
            value: _settings.vizArtworkOpacity,
            min: 0, max: 1,
            divisions: 20,
            onChanged: (v) => _settings.vizArtworkOpacity = v,
          ),
        ],
      ),
      // Partagé par les DEUX oscilloscopes (stéréo et par voies): même tracé, même
      // épaisseur de trait, même modulation d'intensité le long de la trace.
      _SubHeader(label: l10n.settingsVizScopes, cs: cs, textTheme: textTheme),

      _SliderRow(
        label: l10n.settingsLineThickness,
        resetKey: 'vizLineThickness',
        value: _settings.vizLineThickness,
        min: 0.5,
        max: 3.0,
        divisions: 25,
        format: (v) => l10n.settingsValueTimes(v.toStringAsFixed(1)),
        onChanged: (v) => _settings.vizLineThickness = v,
      ),
      SettingRow(
        label: l10n.settingsCrtSpeed,
        resetKey: 'crtSpeedLevel',
        child: _CrtLevelSelector(
          level: _settings.crtSpeedLevel,
          onChanged: (v) => _settings.crtSpeedLevel = v,
        ),
      ),
      _SubHeader(label: l10n.vizStereo, cs: cs, textTheme: textTheme),

      SettingRow(
        label: l10n.settingsStereoColors,
        resetKey: 'stereoBicolor',
        child: SegmentedButton<bool>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(value: false, label: Text(l10n.settingsStereoMono)),
            ButtonSegment(value: true,  label: Text(l10n.settingsStereoBi)),
          ],
          selected: {_settings.stereoBicolor},
          showSelectedIcon: false,
          onSelectionChanged: (s) => _settings.stereoBicolor = s.first,
        ),
      ),
      if (!_settings.stereoBicolor)
        _ColorTile(
          resetKey: 'stereoMonoColor',
          label: l10n.settingsStereoMonoColor,
          color: _settings.stereoMonoColor,
          onPicked: (v) => _settings.stereoMonoColor = v,
        )
      else ...[
        _ColorTile(
          resetKey: 'stereoLeftColor',
          label: l10n.settingsStereoLeftColor,
          color: _settings.stereoLeftColor,
          onPicked: (v) => _settings.stereoLeftColor = v,
        ),
        _ColorTile(
          resetKey: 'stereoRightColor',
          label: l10n.settingsStereoRightColor,
          color: _settings.stereoRightColor,
          onPicked: (v) => _settings.stereoRightColor = v,
        ),
      ],
      // The spectrum normally borrows the colors above; the second palette
      // ignores them and colors each bar by its frequency instead.
      _SubHeader(label: l10n.vizVoices, cs: cs, textTheme: textTheme),

      SwitchListTile(
        secondary: const _ResetDot('vizVoiceGrid'),
        title: Text(l10n.settingsVoiceGridTitle),
        subtitle: Text(l10n.settingsVoiceGridSubtitle),
        value: _settings.vizVoiceGrid,
        onChanged: (v) => _settings.vizVoiceGrid = v,
      ),
      SwitchListTile(
        secondary: const _ResetDot('vizVoiceNames'),
        title: Text(l10n.settingsVoiceNamesTitle),
        subtitle: Text(l10n.settingsVoiceNamesSubtitle),
        value: _settings.vizVoiceNames,
        onChanged: (v) => _settings.vizVoiceNames = v,
      ),
      SettingRow(
        // Le libellé de la ligne dit de quoi on choisit la SOURCE (les noms
        // de voies), pas « Couleurs »: ici rien ne change de couleur.
        label: l10n.settingsVoiceNamesTitle,
        resetKey: 'vizVoiceNameSource',
        child: SegmentedButton<int>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(value: 0, label: Text(l10n.settingsPianoColorVoice)),
            ButtonSegment(value: 1, label: Text(l10n.settingsPianoColorInstrument)),
          ],
          selected: {_settings.vizVoiceNameSource},
          showSelectedIcon: false,
          onSelectionChanged: (sel) => _settings.vizVoiceNameSource = sel.first,
        ),
      ),
      _ColorTile(
        resetKey: 'scopeColor',
        label: l10n.settingsScopeVoiceColor,
        color: _settings.scopeColor,
        onPicked: (v) => _settings.scopeColor = v,
      ),
      _SubHeader(label: l10n.vizNotes, cs: cs, textTheme: textTheme),

      SettingRow(
        label: l10n.settingsNotePalette,
        resetKey: 'notePalette',
        // The swatch lives inside each item — the closed button shows the
        // selected item, so the palette appears exactly once either way.
        child: DropdownButton<int>(
          value: _settings.notePalette,
          isDense: true,
          items: [
            for (int i = 0; i < UserSettings.notePaletteNames.length; i++)
              DropdownMenuItem(
                value: i,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PaletteSwatch(palette: i),
                    const SizedBox(width: 8),
                    Text(UserSettings.notePaletteNames[i]),
                  ],
                ),
              ),
          ],
          onChanged: (v) { if (v != null) _settings.notePalette = v; },
        ),
      ),
      SettingRow(
        label: l10n.settingsNoteBoxStyle,
        resetKey: 'noteBoxStyle',
        child: SegmentedButton<bool>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(value: false, label: Text(l10n.settingsNoteStyleFlat)),
            ButtonSegment(value: true,  label: Text(l10n.settingsNoteStyleBox)),
          ],
          selected: {_settings.noteBoxStyle},
          showSelectedIcon: false,
          onSelectionChanged: (s) => _settings.noteBoxStyle = s.first,
        ),
      ),
      SettingRow(
        label: l10n.settingsPianoColor,
        resetKey: 'noteColorMode',
        child: SegmentedButton<int>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(value: 0, label: Text(l10n.settingsPianoColorVoice)),
            ButtonSegment(value: 1, label: Text(l10n.settingsPianoColorInstrument)),
          ],
          selected: {_settings.noteColorMode},
          showSelectedIcon: false,
          onSelectionChanged: (sel) => _settings.noteColorMode = sel.first,
        ),
      ),
      _SubHeader(label: l10n.vizPiano, cs: cs, textTheme: textTheme),

      SettingRow(
        label: l10n.settingsPianoMode,
        resetKey: 'pianoMode',
        child: SegmentedButton<int>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(value: 0, label: Text(l10n.settingsPianoModeRoll)),
            ButtonSegment(value: 1, label: Text(l10n.settingsPianoModeFalling)),
          ],
          selected: {_settings.pianoMode},
          showSelectedIcon: false,
          onSelectionChanged: (s) => _settings.pianoMode = s.first,
        ),
      ),
      SettingRow(
        label: l10n.settingsPianoColor,
        resetKey: 'pianoColorMode',
        child: SegmentedButton<int>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(value: 0, label: Text(l10n.settingsPianoColorVoice)),
            ButtonSegment(value: 1, label: Text(l10n.settingsPianoColorInstrument)),
          ],
          selected: {_settings.pianoColorMode},
          showSelectedIcon: false,
          onSelectionChanged: (s) => _settings.pianoColorMode = s.first,
        ),
      ),
      SettingRow(
        label: l10n.settingsPianoGlow,
        resetKey: 'pianoGlow',
        child: Switch(
          value: _settings.pianoGlow,
          onChanged: (v) => _settings.pianoGlow = v,
        ),
      ),
      SettingRow(
        label: l10n.settingsPianoLighting,
        resetKey: 'pianoLighting',
        child: Switch(
          value: _settings.pianoLighting,
          onChanged: (v) => _settings.pianoLighting = v,
        ),
      ),
      SettingRow(
        label: l10n.settingsPianoVoiceNames,
        resetKey: 'pianoVoiceNames',
        child: Switch(
          value: _settings.pianoVoiceNames,
          onChanged: (v) => _settings.pianoVoiceNames = v,
        ),
      ),
      _SubHeader(label: l10n.vizSpectrum, cs: cs, textTheme: textTheme),

      SettingRow(
        label: l10n.settingsSpectrumMode,
        resetKey: 'spectrumPalette',
        // Scrollable: five labelled segments ("Standard Coloré Faisceau Ligne
        // Anneau") no longer fit the width of a phone, and a SegmentedButton
        // does not scroll on its own — it just overflows.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(
                value: 0, label: Text(l10n.settingsSpectrumModeStandard)),
            ButtonSegment(
                value: 1, label: Text(l10n.settingsSpectrumModeColored)),
            ButtonSegment(
                value: 2, label: Text(l10n.settingsSpectrumModeBeam)),
            ButtonSegment(
                value: 3, label: Text(l10n.settingsSpectrumModeLine)),
            ButtonSegment(
                value: 4, label: Text(l10n.settingsSpectrumModeRing)),
          ],
          selected: {_settings.spectrumPalette},
          showSelectedIcon: false,
          onSelectionChanged: (s) => _settings.spectrumPalette = s.first,
        ),
        ),
      ),
      _SubHeader(label: l10n.vizPatterns, cs: cs, textTheme: textTheme),

      ListTile(
        leading: const Icon(Icons.grid_on),
        title: Text(l10n.settingsPatternTitle),
        subtitle: Text(l10n.settingsPatternSubtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PatternSettingsScreen()),
        ),
      ),
      _SubHeader(label: 'projectM', cs: cs, textTheme: textTheme),

      ListTile(
        leading: const Icon(Icons.auto_awesome),
        title: Text(l10n.settingsProjectMTitle),
        subtitle: Text(l10n.settingsProjectMSubtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProjectMSettingsScreen()),
        ),
      ),
    ];
  }

  List<Widget> _lectureChildren(BuildContext context) {
    final l10n      = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cs        = Theme.of(context).colorScheme;
    return [
      _sectionResetButton('playback'),
      // Desktop only: mobile already carries the track in its media
      // notification. macOS: AppDelegate channel; Linux: D-Bus
      // (linux_notifications.dart). Désactivé par défaut partout.
      if (Platform.isMacOS || Platform.isLinux)
        SwitchListTile(
          secondary: const _ResetDot('notifyTrackChange'),
          title: Text(l10n.settingsNotifyTrackTitle),
          subtitle: Text(l10n.settingsNotifyTrackSubtitle),
          value: _settings.notifyTrackChange,
          onChanged: (v) => _settings.notifyTrackChange = v,
        ),
      _SubHeader(
          label: l10n.settingsCrossfade, cs: cs, textTheme: textTheme),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          l10n.settingsCrossfadeHelp,
          style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
      _SliderRow(
        label: l10n.settingsCrossfade,
        resetKey: 'crossfadeSecs',
        value: _settings.crossfadeSeconds,
        min: 0,
        max: 8,
        divisions: 8, // pas de 1 s — le libellé affiche des secondes entières
        format: (v) => v <= 0
            ? l10n.settingsOff
            : l10n.settingsValueSeconds(v.round()),
        onChanged: (v) => _settings.crossfadeSeconds = v,
      ),
      const Divider(height: 24, indent: 16, endIndent: 16),
      _SubHeader(
          label: l10n.settingsQueuePrefetchSection, cs: cs, textTheme: textTheme),
      SwitchListTile(
        secondary: const _ResetDot('queuePrefetchAll'),
        title: Text(l10n.settingsQueuePrefetchTitle),
        subtitle: Text(l10n.settingsQueuePrefetchSubtitle),
        value: _settings.queuePrefetchAll,
        onChanged: (v) => _settings.queuePrefetchAll = v,
      ),
      const Divider(height: 24, indent: 16, endIndent: 16),
      // Déclic de début de piste des rips CD — voir UserSettings.cdRipDeclick.
      // Pris en compte à l'ouverture du morceau suivant.
      _SubHeader(
          label: l10n.settingsCdRipDeclickSection, cs: cs, textTheme: textTheme),
      SwitchListTile(
        secondary: const _ResetDot('cdRipDeclick'),
        title: Text(l10n.settingsCdRipDeclickTitle),
        subtitle: Text(l10n.settingsCdRipDeclickSubtitle),
        value: _settings.cdRipDeclick,
        onChanged: (v) => _settings.cdRipDeclick = v,
      ),
      const Divider(height: 24, indent: 16, endIndent: 16),
      _SubHeader(
          label: l10n.settingsSilenceDetection, cs: cs, textTheme: textTheme),
      SwitchListTile(
        secondary: const _ResetDot('silenceSkip'),
        title: Text(l10n.settingsSilenceSkipTitle),
        subtitle: Text(l10n.settingsSilenceSkipSubtitle),
        value: _settings.silenceSkipEnabled,
        onChanged: (v) => _settings.silenceSkipEnabled = v,
      ),
      if (_settings.silenceSkipEnabled)
        _SliderRow(
          label: l10n.settingsSilenceDelay,
          resetKey: 'silenceSkipSecs',
          value: _settings.silenceSkipSeconds,
          min: 1,
          max: 30,
          divisions: 29,
          format: (v) => l10n.settingsValueSeconds(v.round()),
          onChanged: (v) => _settings.silenceSkipSeconds = v,
        ),
      const Divider(height: 24, indent: 16, endIndent: 16),
      // Sous-chansons trop courtes — voir UserSettings.minSubsongSeconds et
      // filterShortSubsongs. 0 = ne rien écarter.
      _SubHeader(
          label: l10n.settingsMinSubsongSection, cs: cs, textTheme: textTheme),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          l10n.settingsMinSubsongHelp,
          style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
      _SliderRow(
        label: l10n.settingsMinSubsongTitle,
        resetKey: 'minSubsongSecs',
        value: _settings.minSubsongSeconds,
        min: 0,
        max: 10,
        divisions: 10, // pas de 1 s — le libellé affiche des secondes entières
        format: (v) => v <= 0
            ? l10n.settingsOff
            : l10n.settingsValueSeconds(v.round()),
        onChanged: (v) => _settings.minSubsongSeconds = v,
      ),
      const Divider(height: 24, indent: 16, endIndent: 16),
      _SubHeader(
          label: l10n.settingsDefaultDuration, cs: cs, textTheme: textTheme),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          l10n.settingsDefaultDurationHelp,
          style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
      _SliderRow(
        label: l10n.settingsDefaultDuration,
        resetKey: 'defaultTrackLength',
        value: _settings.defaultTrackLengthSeconds,
        min: 30,
        max: 600,
        divisions: 57,
        format: (v) =>
            '${v ~/ 60}:${(v % 60).round().toString().padLeft(2, '0')}',
        onChanged: (v) => _settings.defaultTrackLengthSeconds = v,
      ),
      const Divider(height: 24, indent: 16, endIndent: 16),
      _SubHeader(
          label: l10n.settingsForcedLoopHeader, cs: cs, textTheme: textTheme),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          l10n.settingsForcedLoopHelp,
          style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
      ListTile(
        leading: const _ResetDot('forceLoopMode'),
        title: Text(l10n.settingsForceLoopCount),
        trailing: DropdownButton<String>(
          value: _settings.forceLoopMode,
          items: [
            DropdownMenuItem(value: 'off',      child: Text(l10n.settingsOff)),
            DropdownMenuItem(value: 'on',       child: Text(l10n.settingsOn)),
            DropdownMenuItem(
                value: 'infinite', child: Text(l10n.settingsInfinite)),
          ],
          onChanged: (v) { if (v != null) _settings.forceLoopMode = v; },
        ),
      ),
      if (_settings.forceLoopMode == 'on')
        _SliderRow(
          label: l10n.settingsLoopCount,
          resetKey: 'loopCount',
          value: _settings.loopCount.toDouble(),
          min: 0,
          max: 16,
          divisions: 16,
          format: (v) => v.round().toString(),
          onChanged: (v) => _settings.loopCount = v.round(),
        ),
      SwitchListTile(
        secondary: const _ResetDot('forceFadeout'),
        title: Text(l10n.settingsForceFadeout),
        value: _settings.forceFadeoutEnabled,
        onChanged: (v) => _settings.forceFadeoutEnabled = v,
      ),
      if (_settings.forceFadeoutEnabled)
        _SliderRow(
          label: l10n.settingsFadeoutDuration,
          resetKey: 'fadeoutSecs',
          value: _settings.fadeoutSeconds,
          min: 0,
          max: 10,
          divisions: 20,
          format: (v) => l10n.settingsValueSecondsFrac(v.toStringAsFixed(1)),
          onChanged: (v) => _settings.fadeoutSeconds = v,
        ),
      const SizedBox(height: 8),
    ];
  }

  // ── Level 2: engine list — each engine opens its own settings page ────────

  Widget _engineTile(BuildContext context, IconData icon, String name,
      String subtitle, List<Widget> Function(BuildContext) childrenBuilder) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(name),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _SettingsSectionScreen(
          title: name,
          settings: _settings,
          childrenBuilder: childrenBuilder,
        ),
      )),
    );
  }

  Future<void> _resetEngineSettings(BuildContext context) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsResetEnginesTitle),
        content: Text(l10n.settingsResetEnginesBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.settingsCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.settingsReset)),
        ],
      ),
    );
    if (ok == true) await _settings.resetEngineSettings();
  }

  /// Reset affordance shared by the non-engine pages (same shape as the
  /// engines pages'): one button per section, plus the per-setting _ResetDot.
  Widget _sectionResetButton(String section) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TextButton.icon(
          icon: const Icon(Icons.restart_alt, size: 16),
          label: Text(context.l10n.settingsResetSection),
          onPressed: () => _settings.resetSectionSettings(section),
        ),
      ),
    );
  }

  List<Widget> _enginesChildren(BuildContext context) {
    final l10n = context.l10n;
    return [
      ListTile(
        leading: Icon(Icons.restart_alt,
            color: Theme.of(context).colorScheme.error),
        title: Text(l10n.settingsResetDefaultsTitle),
        subtitle: Text(l10n.settingsResetDefaultsSubtitle),
        onTap: () => _resetEngineSettings(context),
      ),
      const Divider(height: 1),
      // Which engine wins a format two engines can both read — a routing
      // decision, not a setting of any one engine, so it gets its own page
      // instead of hiding inside the winner's (or the loser's) page.
      _engineTile(context, Icons.alt_route, l10n.settingsDefaultDecoders,
          l10n.settingsDefaultDecodersSubtitle, _decodersChildren),
      const Divider(height: 1),
      // Tiles are named after the ENGINE, not the console/format — the page
      // configures the library, and the same library often spans formats.
      //
      // ⚠️ TRIÉS PAR NOM, et la liste ci-dessous n'est donc PAS un ordre
      // d'affichage: elle n'est qu'un inventaire. C'est ce qui rend l'ajout
      // d'un moteur sûr — l'écrire n'importe où le range au bon endroit — là
      // où une liste ordonnée à la main dérive au premier ajout pressé.
      // Comparaison insensible à la casse: `libvgm` doit voisiner `UADE` et
      // non se retrouver dans un second alphabet des minuscules.
      ...(<({
        IconData icon,
        String name,
        String subtitle,
        List<Widget> Function(BuildContext) children
      })>[
        (icon: Icons.piano, name: 'libopenmpt',
            subtitle: l10n.settingsEngineOpenmptSubtitle, children: _omptChildren),
        (icon: Icons.piano_outlined, name: 'libxmp',
            subtitle: l10n.settingsEngineXmpSubtitle, children: _xmpChildren),
        (icon: Icons.memory, name: 'libgme',
            subtitle: l10n.settingsEngineGmeSubtitle, children: _gmeChildren),
        (icon: Icons.videogame_asset, name: 'nsfplay',
            subtitle: l10n.settingsEngineNsfSubtitle, children: _nsfChildren),
        (icon: Icons.videogame_asset_outlined, name: 'gbsplay',
            subtitle: l10n.settingsEngineGbsSubtitle, children: _gbsChildren),
        (icon: Icons.library_music, name: 'FluidLite',
            subtitle: l10n.settingsEngineMidiSubtitle, children: _midiChildren),
        // Sous-titre = l'état des ROMs: un jeu manquant se voit sans ouvrir.
        (icon: Icons.memory, name: 'Munt (mt32emu)',
            subtitle: Mt32RomManager.instance.status().isEmpty
                ? l10n.settingsMt32RomsMissing
                : l10n.settingsMt32RomsActive(Mt32RomManager.instance.status()),
            children: _mt32Children),
        (icon: Icons.sports_esports, name: 'libgsf (VBA)',
            subtitle: l10n.settingsEngineGsfSubtitle, children: _gsfChildren),
        (icon: Icons.computer, name: 'UADE',
            subtitle: l10n.settingsEngineUadeSubtitle, children: _uadeChildren),
        (icon: Icons.tv, name: 'libsidplayfp',
            subtitle: l10n.settingsEngineSidSubtitle, children: _sidChildren),
        (icon: Icons.piano_off, name: 'AdPlug',
            subtitle: l10n.settingsEngineAdplugSubtitle, children: _adplugChildren),
        (icon: Icons.album, name: 'Highly Experimental',
            subtitle: l10n.settingsEngineHeSubtitle, children: _heChildren),
        (icon: Icons.developer_board, name: 'libvgm',
            subtitle: l10n.settingsEngineVgmSubtitle, children: _vgmChildren),
      ]..sort((a, b) => compareEngineNames(a.name, b.name)))
          .map((e) => _engineTile(context, e.icon, e.name, e.subtitle, e.children)),
      const SizedBox(height: 8),
    ];
  }

  /// Default-decoder page: the formats more than one engine can read. Each row
  /// picks who wins; everything else routes by the registry's probe score.
  List<Widget> _decodersChildren(BuildContext context) {
    final l10n = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt, size: 16),
            label: Text(l10n.settingsResetChoices),
            onPressed: () => _settings.resetEngineSettings('decoders'),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Text(
          l10n.settingsDecodersHelp,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
      SettingRow(
        label: 'NSF / NSFe',
        resetKey: 'nsfPlugin',
        child: DropdownButton<String>(
          value: _settings.nsfPlugin,
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'nsfplay', child: Text('nsfplay')),
            DropdownMenuItem(value: 'libgme',  child: Text('libgme')),
          ],
          onChanged: (v) { if (v != null) _settings.nsfPlugin = v; },
        ),
      ),
      SettingRow(
        label: 'GBS',
        resetKey: 'gbsPlugin',
        child: DropdownButton<String>(
          value: _settings.gbsPlugin,
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'gbsplay', child: Text('gbsplay')),
            DropdownMenuItem(value: 'libgme',  child: Text('libgme')),
          ],
          onChanged: (v) { if (v != null) _settings.gbsPlugin = v; },
        ),
      ),
      SettingRow(
        label: 'SNDH',
        resetKey: 'sndhPlugin',
        child: DropdownButton<String>(
          value: _settings.sndhPlugin,
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'psgplay',    child: Text('PSG play')),
            DropdownMenuItem(value: 'atariaudio', child: Text('AtariAudio')),
          ],
          onChanged: (v) { if (v != null) _settings.sndhPlugin = v; },
        ),
      ),
      SettingRow(
        label: l10n.settingsDecoderAmigaTrackers,
        resetKey: 'amigaTrackerPlugin',
        child: DropdownButton<String>(
          value: _settings.amigaTrackerPlugin,
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'openmpt', child: Text('libopenmpt')),
            DropdownMenuItem(value: 'uade',    child: Text('UADE')),
          ],
          onChanged: (v) { if (v != null) _settings.amigaTrackerPlugin = v; },
        ),
      ),
      // .mid: FluidLite (SoundFont) ou Munt (MT-32) — « auto » laisse la sonde
      // trancher (banque MT-32 dans le fichier ou son dossier, dossier nommé
      // MT32…), les deux autres épinglent (preferredMidiPluginFor).
      SettingRow(
        label: 'MIDI',
        resetKey: 'midiSynth',
        child: DropdownButton<String>(
          value: _settings.midiSynth,
          isDense: true,
          // Libellés longs (« SoundFont (FluidLite) » traduit): SettingRow
          // plafonne le contrôle, l'ellipse évite le débordement.
          isExpanded: true,
          items: [
            DropdownMenuItem(value: 'auto', child: Text(l10n.settingsMidiSynthAuto, overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'soundfont', child: Text(l10n.settingsMidiSynthSoundfont, overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'mt32', child: Text(l10n.settingsMidiSynthMt32, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) { if (v != null) _settings.midiSynth = v; },
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  // ── Level 3: per-engine pages ─────────────────────────────────────────────

  static List<Widget> _omptChildren(BuildContext context) {
    final l10n = context.l10n;
    return [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt, size: 16),
            label: Text(l10n.settingsResetEngine),
            onPressed: () => _settings.resetEngineSettings('openmpt'),
          ),
        ),
      ),
      _SliderRow(
        label: l10n.settingsMasterVolume,
        resetKey: 'omptMasterVolume',
        value: _settings.omptMasterVolume,
        min: 0.1,
        max: 2.0,
        divisions: 19,
        format: (v) => l10n.settingsValuePercent((v * 100).round()),
        onChanged: (v) => _settings.omptMasterVolume = v,
      ),
      SettingRow(
        label: l10n.settingsAmigaFilter,
        resetKey: 'omptAmigaFilter',
        child: DropdownButton<int>(
          value: _settings.omptAmigaFilter,
          isDense: true,
          items: [
            DropdownMenuItem(value: 0, child: Text(l10n.settingsOff)),
            const DropdownMenuItem(value: 1, child: Text('A500')),
            const DropdownMenuItem(value: 2, child: Text('A1200')),
          ],
          onChanged: (v) { if (v != null) _settings.omptAmigaFilter = v; },
        ),
      ),
      SettingRow(
        label: l10n.settingsInterpolation,
        resetKey: 'omptInterpolation',
        child: DropdownButton<int>(
          value: _settings.omptInterpolation,
          isDense: true,
          items: [
            // libopenmpt: 1 = none (nearest), 2 = linear — NOT 0/1 (0 is
            // "engine default", and 1-as-linear shipped a nearest whine).
            DropdownMenuItem(value: 1, child: Text(l10n.settingsInterpNone)),
            DropdownMenuItem(value: 2, child: Text(l10n.settingsInterpLinear)),
            DropdownMenuItem(value: 4, child: Text(l10n.settingsInterpCubic)),
            DropdownMenuItem(value: 8, child: Text(l10n.settingsInterpSinc)),
          ],
          onChanged: (v) { if (v != null) _settings.omptInterpolation = v; },
        ),
      ),
      _SliderRow(
        label: l10n.settingsStereoSeparation,
        resetKey: 'omptStereoSep',
        value: _settings.omptStereoSep.toDouble(),
        min: 0,
        max: 200,
        divisions: 20,
        format: (v) => l10n.settingsValuePercent(v.round()),
        onChanged: (v) => _settings.omptStereoSep = v.round(),
      ),
      const SizedBox(height: 8),
    ];
  }

  /// libxmp — les mêmes réglages que son mixeur expose (interpolation,
  /// séparation stéréo, amplification, volume, filtre passe-bas, mixeur
  /// Paula). Appliqués À CHAUD: la vtable publie `param_changed`.
  static List<Widget> _xmpChildren(BuildContext context) {
    final l10n = context.l10n;
    return [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt, size: 16),
            label: Text(l10n.settingsResetEngine),
            onPressed: () => _settings.resetEngineSettings('xmp'),
          ),
        ),
      ),
      SettingRow(
        label: l10n.settingsInterpolation,
        resetKey: 'xmpInterpolation',
        child: DropdownButton<int>(
          value: _settings.xmpInterpolation,
          isDense: true,
          items: [
            DropdownMenuItem(value: 0, child: Text(l10n.settingsInterpNone)),
            DropdownMenuItem(value: 1, child: Text(l10n.settingsInterpLinear)),
            DropdownMenuItem(value: 2, child: Text(l10n.settingsInterpCubic)),
          ],
          onChanged: (v) { if (v != null) _settings.xmpInterpolation = v; },
        ),
      ),
      _SliderRow(
        label: l10n.settingsStereoSeparation,
        resetKey: 'xmpStereoSep',
        value: _settings.xmpStereoSep.toDouble(),
        min: 0,
        max: 100,
        divisions: 20,
        format: (v) => l10n.settingsValuePercent(v.round()),
        onChanged: (v) => _settings.xmpStereoSep = v.round(),
      ),
      _SliderRow(
        label: l10n.settingsMasterVolume,
        resetKey: 'xmpMasterVolume',
        value: _settings.xmpMasterVolume.toDouble(),
        min: 0,
        max: 200,
        divisions: 20,
        format: (v) => l10n.settingsValuePercent(v.round()),
        onChanged: (v) => _settings.xmpMasterVolume = v.round(),
      ),
      _SliderRow(
        label: l10n.settingsAmplification,
        resetKey: 'xmpAmplify',
        value: _settings.xmpAmplify.toDouble(),
        min: 0,
        max: 3,
        divisions: 3,
        format: (v) => '×${(1 << v.round())}',
        onChanged: (v) => _settings.xmpAmplify = v.round(),
      ),
      SwitchListTile(
        secondary: const _ResetDot('xmpDspLowpass'),
        title: Text(l10n.settingsLowpassFilter),
        value: _settings.xmpDspLowpass,
        onChanged: (v) => _settings.xmpDspLowpass = v,
      ),
      SwitchListTile(
        secondary: const _ResetDot('xmpAmigaMixer'),
        title: Text(l10n.settingsAmigaFilter),
        value: _settings.xmpAmigaMixer,
        onChanged: (v) => _settings.xmpAmigaMixer = v,
      ),
      const SizedBox(height: 8),
    ];
  }

  static List<Widget> _gmeChildren(BuildContext context) {
    final l10n = context.l10n;
    return [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt, size: 16),
            label: Text(l10n.settingsResetEngine),
            onPressed: () => _settings.resetEngineSettings('gme'),
          ),
        ),
      ),
      SwitchListTile(
        secondary: const _ResetDot('gmeSilenceDetection'),
        title: Text(l10n.settingsSilenceDetection),
        subtitle: Text(l10n.settingsGmeSilenceSubtitle),
        value: _settings.gmeSilenceDetection,
        onChanged: (v) => _settings.gmeSilenceDetection = v,
      ),
      _SliderRow(
        label: l10n.settingsStereoDepth,
        resetKey: 'gmeStereoDepth',
        value: _settings.gmeStereoDepth,
        min: 0,
        max: 1,
        divisions: 20,
        format: (v) => l10n.settingsValuePercent((v * 100).round()),
        onChanged: (v) => _settings.gmeStereoDepth = v,
      ),
      SwitchListTile(
        secondary: const _ResetDot('gmeEqEnabled'),
        title: Text(l10n.settingsEqualizer),
        subtitle: Text(l10n.settingsGmeEqSubtitle),
        value: _settings.gmeEqEnabled,
        onChanged: (v) => _settings.gmeEqEnabled = v,
      ),
      if (_settings.gmeEqEnabled) ...[
        _SliderRow(
          label: l10n.settingsBass,
          resetKey: 'gmeEqBass',
          value: _settings.gmeEqBass,
          min: 0,
          max: 4.2,
          divisions: 42,
          format: (v) => v.toStringAsFixed(1),
          onChanged: (v) => _settings.gmeEqBass = v,
        ),
        _SliderRow(
          label: l10n.settingsTreble,
          resetKey: 'gmeEqTreble',
          value: _settings.gmeEqTreble,
          min: -50,
          max: 5,
          divisions: 55,
          format: (v) => l10n.settingsValueDb(v.round()),
          onChanged: (v) => _settings.gmeEqTreble = v,
        ),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(l10n.settingsAppliedLive,
            style: const TextStyle(fontSize: 12)),
      ),
      const SizedBox(height: 8),
    ];
  }

  static List<Widget> _sidChildren(BuildContext context) {
    final l10n = context.l10n;
    return [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt, size: 16),
            label: Text(l10n.settingsResetEngine),
            onPressed: () => _settings.resetEngineSettings('sid'),
          ),
        ),
      ),
      SettingRow(
        label: l10n.settingsSidEmulation,
        resetKey: 'sidEngine',
        child: DropdownButton<int>(
          value: _settings.sidEngine,
          isDense: true,
          items: [
            DropdownMenuItem(value: 0, child: Text(l10n.settingsSidResidfp)),
            DropdownMenuItem(value: 1, child: Text(l10n.settingsSidLite)),
          ],
          onChanged: (v) { if (v != null) _settings.sidEngine = v; },
        ),
      ),
      SettingRow(
        label: l10n.settingsSidSampling,
        resetKey: 'sidSampling',
        child: DropdownButton<int>(
          value: _settings.sidSampling,
          isDense: true,
          items: [
            DropdownMenuItem(
                value: 0, child: Text(l10n.settingsSidSamplingInterp)),
            DropdownMenuItem(
                value: 1, child: Text(l10n.settingsSidSamplingResample)),
          ],
          onChanged: (v) { if (v != null) _settings.sidSampling = v; },
        ),
      ),
      SettingRow(
        label: l10n.settingsSidClock,
        resetKey: 'sidClock',
        child: DropdownButton<int>(
          value: _settings.sidClock,
          isDense: true,
          items: [
            DropdownMenuItem(value: 0, child: Text(l10n.settingsAuto)),
            const DropdownMenuItem(value: 1, child: Text('PAL')),
            const DropdownMenuItem(value: 2, child: Text('NTSC')),
          ],
          onChanged: (v) { if (v != null) _settings.sidClock = v; },
        ),
      ),
      SettingRow(
        label: l10n.settingsSidModel,
        resetKey: 'sidModel',
        child: DropdownButton<int>(
          value: _settings.sidModel,
          isDense: true,
          items: [
            DropdownMenuItem(value: 0, child: Text(l10n.settingsAuto)),
            const DropdownMenuItem(value: 1, child: Text('6581')),
            const DropdownMenuItem(value: 2, child: Text('8580')),
          ],
          onChanged: (v) { if (v != null) _settings.sidModel = v; },
        ),
      ),
      SwitchListTile(
        secondary: const _ResetDot('sidFilter'),
        title: Text(l10n.settingsSidFilter),
        value: _settings.sidFilter,
        onChanged: (v) => _settings.sidFilter = v,
      ),
      SwitchListTile(
        secondary: const _ResetDot('sidSecondOn'),
        title: Text(l10n.settingsSidForceSecond),
        subtitle: Text(l10n.settingsSidSecondSubtitle),
        value: _settings.sidSecondOn,
        onChanged: (v) => _settings.sidSecondOn = v,
      ),
      if (_settings.sidSecondOn)
        SettingRow(
          label: l10n.settingsSidSecondAddr,
          resetKey: 'sidSecondAddr',
          child: DropdownButton<int>(
            value: _settings.sidSecondAddr,
            isDense: true,
            items: const [
              DropdownMenuItem(value: 0xD420, child: Text('0xD420')),
              DropdownMenuItem(value: 0xD500, child: Text('0xD500')),
              DropdownMenuItem(value: 0xDE00, child: Text('0xDE00')),
              DropdownMenuItem(value: 0xDF00, child: Text('0xDF00')),
            ],
            onChanged: (v) { if (v != null) _settings.sidSecondAddr = v; },
          ),
        ),
      SwitchListTile(
        secondary: const _ResetDot('sidThirdOn'),
        title: Text(l10n.settingsSidForceThird),
        value: _settings.sidThirdOn,
        onChanged: (v) => _settings.sidThirdOn = v,
      ),
      if (_settings.sidThirdOn)
        SettingRow(
          label: l10n.settingsSidThirdAddr,
          resetKey: 'sidThirdAddr',
          child: DropdownButton<int>(
            value: _settings.sidThirdAddr,
            isDense: true,
            items: const [
              DropdownMenuItem(value: 0xD440, child: Text('0xD440')),
              DropdownMenuItem(value: 0xD520, child: Text('0xD520')),
              DropdownMenuItem(value: 0xDE20, child: Text('0xDE20')),
              DropdownMenuItem(value: 0xDF20, child: Text('0xDF20')),
            ],
            onChanged: (v) { if (v != null) _settings.sidThirdAddr = v; },
          ),
        ),
      SwitchListTile(
        secondary: const _ResetDot('sidAutoFilter'),
        title: Text(l10n.settingsSidAutoFilter),
        subtitle: Text(l10n.settingsSidAutoFilterSubtitle),
        value: _settings.sidAutoFilter,
        onChanged: (v) => _settings.sidAutoFilter = v,
      ),
      if (!_settings.sidAutoFilter)
        _SliderRow(
          label: l10n.settingsSid6581Range,
          resetKey: 'sid6581Range',
          value: _settings.sid6581Range,
          min: 0, max: 1,
          format: (v) => v.toStringAsFixed(2),
          onChanged: (v) => _settings.sid6581Range = v,
        ),
      _SliderRow(
        label: l10n.settingsSid6581Curve,
        resetKey: 'sid6581Curve',
        // > 0.85 déborde le modèle DAC du 6581 (vérifié) — plafonné.
        value: _settings.sid6581Curve.clamp(0.0, 0.85),
        min: 0, max: 0.85,
        format: (v) => v.toStringAsFixed(2),
        onChanged: (v) => _settings.sid6581Curve = v,
      ),
      _SliderRow(
        label: l10n.settingsSid8580Curve,
        resetKey: 'sid8580Curve',
        value: _settings.sid8580Curve,
        min: 0, max: 1,
        format: (v) => v.toStringAsFixed(2),
        onChanged: (v) => _settings.sid8580Curve = v,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(l10n.settingsSidNote,
            style: const TextStyle(fontSize: 12)),
      ),
      const SizedBox(height: 8),
    ];
  }

  static List<Widget> _adplugChildren(BuildContext context) {
    final l10n = context.l10n;
    return [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt, size: 16),
            label: Text(l10n.settingsResetEngine),
            onPressed: () => _settings.resetEngineSettings('adplug'),
          ),
        ),
      ),
      SettingRow(
        label: l10n.settingsAudioOutput,
        resetKey: 'adplugSurround',
        child: SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l10n.settingsStereo)),
            ButtonSegment(value: true,  label: Text(l10n.settingsSurround)),
          ],
          selected: {_settings.adplugSurround},
          onSelectionChanged: (sel) =>
              _settings.adplugSurround = sel.first,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(l10n.settingsAdplugNote,
            style: const TextStyle(fontSize: 12)),
      ),
      const SizedBox(height: 8),
    ];
  }

  static List<Widget> _heChildren(BuildContext context) {
    final l10n = context.l10n;
    return [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt, size: 16),
            label: Text(l10n.settingsResetEngine),
            onPressed: () => _settings.resetEngineSettings('he'),
          ),
        ),
      ),
      SwitchListTile(
        secondary: const _ResetDot('heSpuMain'),
        title: Text(l10n.settingsHeSpuMain),
        value: _settings.heSpuMain,
        onChanged: (v) => _settings.heSpuMain = v,
      ),
      SwitchListTile(
        secondary: const _ResetDot('heSpuReverb'),
        title: Text(l10n.settingsHeSpuReverb),
        value: _settings.heSpuReverb,
        onChanged: (v) => _settings.heSpuReverb = v,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(l10n.settingsAppliedLive,
            style: const TextStyle(fontSize: 12)),
      ),
      const SizedBox(height: 8),
    ];
  }

  static List<Widget> _vgmChildren(BuildContext context) {
    final l10n = context.l10n;
    Widget core(String label, String resetName, int value, List<String> names,
        ValueChanged<int> set) {
      return SettingRow(
        label: label,
        resetKey: resetName,
        // ⚠️ `isExpanded` + élision, et les DEUX sont nécessaires. Sans
        // `isExpanded`, un DropdownButton se dimensionne sur son item le PLUS
        // LARGE et ignore la contrainte que SettingRow lui pose (60 % de la
        // ligne): sa Row interne déborde — « A RenderFlex overflowed by 16
        // pixels ». Avec `isExpanded` l'item devient flexible, mais un Text
        // sans `overflow` déborde à son tour au lieu de s'élider.
        //
        // C'est la famille de libellés la plus longue de tous les réglages:
        // un nom de cœur porte son avertissement (« SameBoy (sans
        // oscilloscope) »), et il s'allonge encore dans les langues qui
        // traduisent ce suffixe.
        child: DropdownButton<int>(
          value: value,
          isDense: true,
          isExpanded: true,
          items: [
            for (var i = 0; i < names.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(names[i], overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) { if (v != null) set(v); },
        ),
      );
    }

    // Suffixe des coeurs qui n'ont PAS nos captures par voix (voir plus bas).
    final noScope = ' (${l10n.settingsCoreNoScope})';

    return [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt, size: 16),
            label: Text(l10n.settingsResetEngine),
            onPressed: () => _settings.resetEngineSettings('vgm'),
          ),
        ),
      ),
      SwitchListTile(
        secondary: const _ResetDot('vgmJapaneseTags'),
        title: Text(l10n.settingsVgmJapaneseTags),
        subtitle: Text(l10n.settingsVgmJapaneseTagsHelp),
        value: _settings.vgmJapaneseTags,
        onChanged: (v) => _settings.vgmJapaneseTags = v,
      ),
      core('YM2612 (Mega Drive)', 'vgmYm2612Core', _settings.vgmYm2612Core,
          [l10n.settingsDefault, 'GPGX (MAME)', 'Nuked OPN2', 'Gens'],
          (v) => _settings.vgmYm2612Core = v),
      core('YMF262 (OPL3)', 'vgmYmf262Core', _settings.vgmYmf262Core,
          [l10n.settingsDefault, 'AdLibEmu', 'MAME', 'Nuked'],
          (v) => _settings.vgmYmf262Core = v),
      core('YM3812 (OPL2)', 'vgmYm3812Core', _settings.vgmYm3812Core,
          [l10n.settingsDefault, 'AdLibEmu', 'MAME'],
          (v) => _settings.vgmYm3812Core = v),
      core('QSound (CPS)', 'vgmQsoundCore', _settings.vgmQsoundCore,
          [l10n.settingsDefault, 'superctr', 'MAME$noScope'],
          (v) => _settings.vgmQsoundCore = v),
      core('RF5C68 (Mega CD)', 'vgmRf5c68Core', _settings.vgmRf5c68Core,
          [l10n.settingsDefault, 'MAME', 'Gens'],
          (v) => _settings.vgmRf5c68Core = v),
      // ⚠️ Nos captures d'oscilloscope et de notes sont posées PAR COEUR. Un
      // coeur alternatif n'en a pas forcément, et le choisir éteindrait les
      // visualiseurs sans un mot — d'où le suffixe explicite sur ceux-là.
      core('GameBoy DMG', 'vgmGbCore', _settings.vgmGbCore,
          [l10n.settingsDefault, 'SameBoy', 'MAME'],
          (v) => _settings.vgmGbCore = v),
      core('YM2413 (OPLL)', 'vgmYm2413Core', _settings.vgmYm2413Core,
          [l10n.settingsDefault, 'EMU2413',
           'MAME$noScope', 'Nuked OPLL$noScope'],
          (v) => _settings.vgmYm2413Core = v),
      core('YM2151 (OPM)', 'vgmYm2151Core', _settings.vgmYm2151Core,
          [l10n.settingsDefault, 'MAME', 'Nuked OPM$noScope'],
          (v) => _settings.vgmYm2151Core = v),
      core('AY-3-8910 / YM2149', 'vgmAy8910Core', _settings.vgmAy8910Core,
          [l10n.settingsDefault, 'EMU2149', 'MAME$noScope'],
          (v) => _settings.vgmAy8910Core = v),
      core('NES APU (RP2A03)', 'vgmNesCore', _settings.vgmNesCore,
          [l10n.settingsDefault, 'NSFPlay', 'MAME$noScope'],
          (v) => _settings.vgmNesCore = v),
      core('SN76496 / SN76489', 'vgmSn76496Core', _settings.vgmSn76496Core,
          [l10n.settingsDefault, 'MAME', 'Maxim$noScope'],
          (v) => _settings.vgmSn76496Core = v),
      core('SAA1099', 'vgmSaa1099Core', _settings.vgmSaa1099Core,
          [l10n.settingsDefault, 'Valley Bell', 'MAME$noScope'],
          (v) => _settings.vgmSaa1099Core = v),
      core('HuC6280 (PC Engine)', 'vgmC6280Core', _settings.vgmC6280Core,
          [l10n.settingsDefault, 'Ootake', 'MAME$noScope'],
          (v) => _settings.vgmC6280Core = v),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(l10n.settingsAppliedNextTrack,
            style: const TextStyle(fontSize: 12)),
      ),
      const SizedBox(height: 8),
    ];
  }

  /// nsfplay's per-chip emulation switches, one folding tile per chip. These
  /// were already wired on the C side (nsfplay_apply_engine_params) with
  /// Modizer's defaults — this only surfaces them.
  static List<Widget> _nsfChipOptions(BuildContext context) {
    final l10n = context.l10n;
    Widget sw(String label, String? subtitle, String resetKey, bool value,
            ValueChanged<bool> onChanged) =>
        SwitchListTile(
          secondary: _ResetDot(resetKey),
          title: Text(label),
          subtitle: subtitle == null ? null : Text(subtitle),
          dense: true,
          value: value,
          onChanged: onChanged,
        );
    final s = _settings;
    return [
      ExpansionTile(
        title: Text(l10n.settingsNsfApu1Title),
        children: [
          sw(l10n.settingsNsfUnmuteOnReset, null, 'nsfApu1Unmute',
              s.nsfApu1Unmute, (v) => s.nsfApu1Unmute = v),
          sw(l10n.settingsNsfPhaseRefresh, l10n.settingsNsfPhaseRefreshSubtitle,
              'nsfApu1PhaseRefresh', s.nsfApu1PhaseRefresh,
              (v) => s.nsfApu1PhaseRefresh = v),
          sw(l10n.settingsNsfNonlinearMixer,
              l10n.settingsNsfApu1NonlinearSubtitle,
              'nsfApu1NonlinearMixer', s.nsfApu1NonlinearMixer,
              (v) => s.nsfApu1NonlinearMixer = v),
          sw(l10n.settingsNsfDutySwap, l10n.settingsNsfDutySwapSubtitle,
              'nsfApu1DutySwap', s.nsfApu1DutySwap, (v) => s.nsfApu1DutySwap = v),
          sw(l10n.settingsNsfNegateSweep, null, 'nsfApu1NegateSweep',
              s.nsfApu1NegateSweep, (v) => s.nsfApu1NegateSweep = v),
        ],
      ),
      ExpansionTile(
        title: Text(l10n.settingsNsfApu2Title),
        children: [
          sw(l10n.settingsNsfEnable4011, l10n.settingsNsfEnable4011Subtitle,
              'nsfApu2Enable4011', s.nsfApu2Enable4011,
              (v) => s.nsfApu2Enable4011 = v),
          sw(l10n.settingsNsfPeriodicNoise,
              l10n.settingsNsfPeriodicNoiseSubtitle,
              'nsfApu2PeriodicNoise', s.nsfApu2PeriodicNoise,
              (v) => s.nsfApu2PeriodicNoise = v),
          sw(l10n.settingsNsfUnmuteOnReset, null, 'nsfApu2Unmute',
              s.nsfApu2Unmute, (v) => s.nsfApu2Unmute = v),
          sw(l10n.settingsNsfDpcmAntiClick, null, 'nsfApu2DpcmAntiClick',
              s.nsfApu2DpcmAntiClick, (v) => s.nsfApu2DpcmAntiClick = v),
          sw(l10n.settingsNsfNonlinearMixer, null, 'nsfApu2NonlinearMixer',
              s.nsfApu2NonlinearMixer, (v) => s.nsfApu2NonlinearMixer = v),
          sw(l10n.settingsNsfRandomizeNoise, null, 'nsfApu2RandomizeNoise',
              s.nsfApu2RandomizeNoise, (v) => s.nsfApu2RandomizeNoise = v),
          sw(l10n.settingsNsfTriangleMute, l10n.settingsNsfTriangleMuteSubtitle,
              'nsfApu2TriangleMute', s.nsfApu2TriangleMute,
              (v) => s.nsfApu2TriangleMute = v),
          sw(l10n.settingsNsfRandomizeTri, null, 'nsfApu2RandomizeTri',
              s.nsfApu2RandomizeTri, (v) => s.nsfApu2RandomizeTri = v),
          sw(l10n.settingsNsfDpcmReverse, null, 'nsfApu2DpcmReverse',
              s.nsfApu2DpcmReverse, (v) => s.nsfApu2DpcmReverse = v),
        ],
      ),
      ExpansionTile(
        title: const Text('Namco 163'),
        children: [
          sw(l10n.settingsNsfN163Serial, l10n.settingsNsfN163SerialSubtitle,
              'nsfN163Serial', s.nsfN163Serial, (v) => s.nsfN163Serial = v),
          sw(l10n.settingsNsfN163PhaseReadOnly, null, 'nsfN163PhaseReadOnly',
              s.nsfN163PhaseReadOnly, (v) => s.nsfN163PhaseReadOnly = v),
          sw(l10n.settingsNsfN163LimitWavelength, null,
              'nsfN163LimitWavelength',
              s.nsfN163LimitWavelength, (v) => s.nsfN163LimitWavelength = v),
        ],
      ),
      ExpansionTile(
        title: const Text('FDS'),
        children: [
          _SliderRow(
            label: l10n.settingsNsfFdsCutoff,
            resetKey: 'nsfFdsCutoff',
            value: s.nsfFdsCutoff.toDouble(),
            min: 0, max: 4000, divisions: 40,
            format: (v) => l10n.settingsValueHz(v.round()),
            onChanged: (v) => s.nsfFdsCutoff = v.round(),
          ),
          sw(l10n.settingsNsfFds4085Reset, null, 'nsfFds4085Reset',
              s.nsfFds4085Reset, (v) => s.nsfFds4085Reset = v),
          sw(l10n.settingsNsfFdsWriteProtect, null, 'nsfFdsWriteProtect',
              s.nsfFdsWriteProtect, (v) => s.nsfFdsWriteProtect = v),
        ],
      ),
      ExpansionTile(
        title: const Text('MMC5'),
        children: [
          sw(l10n.settingsNsfNonlinearMixer, null, 'nsfMmc5NonlinearMixer',
              s.nsfMmc5NonlinearMixer, (v) => s.nsfMmc5NonlinearMixer = v),
          sw(l10n.settingsNsfPhaseRefresh, null, 'nsfMmc5PhaseRefresh',
              s.nsfMmc5PhaseRefresh, (v) => s.nsfMmc5PhaseRefresh = v),
        ],
      ),
      ExpansionTile(
        title: const Text('VRC7'),
        children: [
          SettingRow(
            label: l10n.settingsNsfVrc7Patch,
            resetKey: 'nsfVrc7Patch',
            child: DropdownButton<int>(
              value: s.nsfVrc7Patch,
              isDense: true,
              items: [
                for (var i = 0; i < UserSettings.nsfVrc7PatchNames.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(UserSettings.nsfVrc7PatchNames[i]),
                  ),
              ],
              onChanged: (v) { if (v != null) s.nsfVrc7Patch = v; },
            ),
          ),
          sw(l10n.settingsNsfVrc7Opll, l10n.settingsNsfVrc7OpllSubtitle,
              'nsfVrc7Opll', s.nsfVrc7Opll, (v) => s.nsfVrc7Opll = v),
        ],
      ),
    ];
  }

  static List<Widget> _nsfChildren(BuildContext context) {
    final l10n = context.l10n;
    return [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt, size: 16),
            label: Text(l10n.settingsResetEngine),
            onPressed: () => _settings.resetEngineSettings('nsfplay'),
          ),
        ),
      ),
      _SliderRow(
        label: l10n.settingsNsfQuality,
        resetKey: 'nsfQuality',
        value: _settings.nsfQuality.toDouble(),
        min: 0, max: 40, divisions: 40,
        format: (v) => '${v.round()}',
        onChanged: (v) => _settings.nsfQuality = v.round(),
      ),
      _SliderRow(
        label: l10n.settingsLowpassFilter,
        resetKey: 'nsfLpf',
        value: _settings.nsfLpf.toDouble(),
        min: 0, max: 400, divisions: 40,
        format: (v) => '${v.round()}',
        onChanged: (v) => _settings.nsfLpf = v.round(),
      ),
      _SliderRow(
        label: l10n.settingsHighpassFilter,
        resetKey: 'nsfHpf',
        value: _settings.nsfHpf.toDouble(),
        min: 0, max: 256, divisions: 32,
        format: (v) => '${v.round()}',
        onChanged: (v) => _settings.nsfHpf = v.round(),
      ),
      SettingRow(
        label: l10n.settingsRegion,
        resetKey: 'nsfRegion',
        child: DropdownButton<int>(
          value: _settings.nsfRegion,
          isDense: true,
          items: [
            DropdownMenuItem(value: 0, child: Text(l10n.settingsAuto)),
            const DropdownMenuItem(value: 1, child: Text('NTSC')),
            const DropdownMenuItem(value: 2, child: Text('PAL')),
            const DropdownMenuItem(value: 3, child: Text('Dendy')),
            DropdownMenuItem(
                value: 4, child: Text(l10n.settingsNsfRegionNtscForced)),
            DropdownMenuItem(
                value: 5, child: Text(l10n.settingsNsfRegionPalForced)),
            DropdownMenuItem(
                value: 6, child: Text(l10n.settingsNsfRegionDendyForced)),
          ],
          onChanged: (v) { if (v != null) _settings.nsfRegion = v; },
        ),
      ),
      SwitchListTile(
        secondary: const _ResetDot('nsfIrq'),
        title: Text(l10n.settingsNsfForceIrq),
        value: _settings.nsfIrq,
        onChanged: (v) => _settings.nsfIrq = v,
      ),

      // Per-chip emulation options (nsfplay's own APU/expansion switches).
      // Folded away: they are accuracy/quirk toggles, not everyday knobs.
      ..._nsfChipOptions(context),

      const SizedBox(height: 8),
    ];
  }

  static List<Widget> _gbsChildren(BuildContext context) {
    final l10n = context.l10n;
    return [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt, size: 16),
            label: Text(l10n.settingsResetEngine),
            onPressed: () => _settings.resetEngineSettings('gbs'),
          ),
        ),
      ),
      SettingRow(
        label: l10n.settingsGbsHpFilter,
        resetKey: 'gbsHpFilter',
        child: DropdownButton<int>(
          value: _settings.gbsHpFilter,
          isDense: true,
          items: [
            DropdownMenuItem(value: 0, child: Text(l10n.settingsOff)),
            DropdownMenuItem(value: 1, child: Text(l10n.settingsGbsFilterDmg)),
            DropdownMenuItem(value: 2, child: Text(l10n.settingsGbsFilterCgb)),
          ],
          onChanged: (v) { if (v != null) _settings.gbsHpFilter = v; },
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  /// Page moteur « Munt (mt32emu) »: ROMs et réglages de l'émulation. Le
  /// choix FluidLite / MT-32 est dans « Décodeurs par défaut », avec les
  /// autres choix de moteur.
  static List<Widget> _mt32Children(BuildContext context) => const [
        Mt32EnginePanel(),
      ];

  static List<Widget> _midiChildren(BuildContext context) {
    final l10n = context.l10n;
    return [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt, size: 16),
            label: Text(l10n.settingsResetEngine),
            onPressed: () => _settings.resetEngineSettings('midi'),
          ),
        ),
      ),
      const _SoundfontPicker(),
      const Divider(height: 24, indent: 16, endIndent: 16),
      _SliderRow(
        label: l10n.settingsMasterVolume,
        resetKey: 'midiGain',
        value: _settings.midiGain,
        min: 0.1,
        max: 1.0,
        divisions: 18,
        format: (v) => l10n.settingsValuePercent((v * 100).round()),
        onChanged: (v) => _settings.midiGain = v,
      ),
      _SliderRow(
        label: l10n.settingsPolyphony,
        resetKey: 'midiPolyphony',
        value: _settings.midiPolyphony.toDouble(),
        min: 32,
        max: 256,
        divisions: 28,
        format: (v) => v.round().toString(),
        onChanged: (v) => _settings.midiPolyphony = v.round(),
      ),
      SettingRow(
        label: l10n.settingsInterpolation,
        resetKey: 'midiInterp',
        child: DropdownButton<int>(
          value: _settings.midiInterp,
          isDense: true,
          items: [
            // libopenmpt: 1 = none (nearest), 2 = linear — NOT 0/1 (0 is
            // "engine default", and 1-as-linear shipped a nearest whine).
            DropdownMenuItem(value: 1, child: Text(l10n.settingsInterpNone)),
            DropdownMenuItem(value: 2, child: Text(l10n.settingsInterpLinear)),
            DropdownMenuItem(value: 4, child: Text(l10n.settingsInterpCubic)),
            DropdownMenuItem(value: 7, child: Text(l10n.settingsInterpSinc)),
          ],
          onChanged: (v) { if (v != null) _settings.midiInterp = v; },
        ),
      ),
      SwitchListTile(
        secondary: const _ResetDot('midiReverb'),
        title: Text(l10n.settingsReverb),
        value: _settings.midiReverb,
        onChanged: (v) => _settings.midiReverb = v,
      ),
      SwitchListTile(
        secondary: const _ResetDot('midiChorus'),
        title: Text(l10n.settingsChorus),
        value: _settings.midiChorus,
        onChanged: (v) => _settings.midiChorus = v,
      ),
      SwitchListTile(
        secondary: const _ResetDot('midiMt32ToGm'),
        title: Text(l10n.settingsMidiMt32ToGm),
        subtitle: Text(l10n.settingsMidiMt32ToGmSubtitle),
        isThreeLine: true,
        value: _settings.midiMt32ToGm,
        onChanged: (v) => _settings.midiMt32ToGm = v,
      ),
      const SizedBox(height: 8),
    ];
  }

  static List<Widget> _gsfChildren(BuildContext context) {
    final l10n = context.l10n;
    return [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt, size: 16),
            label: Text(l10n.settingsResetEngine),
            onPressed: () => _settings.resetEngineSettings('gsf'),
          ),
        ),
      ),
      SwitchListTile(
        secondary: const _ResetDot('gsfInterpolation'),
        title: Text(l10n.settingsInterpolation),
        value: _settings.gsfInterpolation,
        onChanged: (v) => _settings.gsfInterpolation = v,
      ),
      SwitchListTile(
        secondary: const _ResetDot('gsfLowpass'),
        title: Text(l10n.settingsLowpassFilter),
        value: _settings.gsfLowpass,
        onChanged: (v) => _settings.gsfLowpass = v,
      ),
      SwitchListTile(
        secondary: const _ResetDot('gsfEcho'),
        title: Text(l10n.settingsEcho),
        value: _settings.gsfEcho,
        onChanged: (v) => _settings.gsfEcho = v,
      ),
      const SizedBox(height: 8),
    ];
  }

  static List<Widget> _uadeChildren(BuildContext context) {
    final l10n = context.l10n;
    return [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt, size: 16),
            label: Text(l10n.settingsResetEngine),
            onPressed: () => _settings.resetEngineSettings('uade'),
          ),
        ),
      ),
      SwitchListTile(
        secondary: const _ResetDot('uadePostfx'),
        title: Text(l10n.settingsUadePostfx),
        subtitle: Text(l10n.settingsUadePostfxSubtitle),
        value: _settings.uadePostfx,
        onChanged: (v) => _settings.uadePostfx = v,
      ),
      SwitchListTile(
        secondary: const _ResetDot('uadePanEnabled'),
        title: Text(l10n.settingsUadePan),
        value: _settings.uadePanEnabled,
        onChanged: (v) => _settings.uadePanEnabled = v,
      ),
      if (_settings.uadePanEnabled)
        _SliderRow(
          label: l10n.settingsUadePanValue,
          resetKey: 'uadePanValue',
          value: _settings.uadePanValue,
          min: 0,
          max: 1,
          divisions: 20,
          format: (v) => l10n.settingsValuePercent((v * 100).round()),
          onChanged: (v) => _settings.uadePanValue = v,
        ),
      SwitchListTile(
        secondary: const _ResetDot('uadeHeadphones'),
        title: Text(l10n.settingsUadeHeadphones),
        value: _settings.uadeHeadphones,
        onChanged: (v) => _settings.uadeHeadphones = v,
      ),
      SettingRow(
        label: l10n.settingsUadeLed,
        resetKey: 'uadeLed',
        child: DropdownButton<int>(
          value: _settings.uadeLed,
          isDense: true,
          items: [
            DropdownMenuItem(value: 0, child: Text(l10n.settingsUadeLedAuto)),
            DropdownMenuItem(value: 1, child: Text(l10n.settingsUadeLedOn)),
            DropdownMenuItem(value: 2, child: Text(l10n.settingsUadeLedOff)),
          ],
          onChanged: (v) { if (v != null) _settings.uadeLed = v; },
        ),
      ),
      SettingRow(
        label: l10n.settingsUadeFilterType,
        resetKey: 'uadeFilterType',
        child: DropdownButton<int>(
          value: _settings.uadeFilterType,
          isDense: true,
          items: [
            const DropdownMenuItem(value: 0, child: Text('Amiga 500')),
            const DropdownMenuItem(value: 1, child: Text('Amiga 1200')),
            DropdownMenuItem(value: 2, child: Text(l10n.settingsNone)),
          ],
          onChanged: (v) { if (v != null) _settings.uadeFilterType = v; },
        ),
      ),
      SwitchListTile(
        secondary: const _ResetDot('uadeGainEnabled'),
        title: Text(l10n.settingsUadeGain),
        value: _settings.uadeGainEnabled,
        onChanged: (v) => _settings.uadeGainEnabled = v,
      ),
      if (_settings.uadeGainEnabled)
        _SliderRow(
          label: l10n.settingsUadeGainValue,
          resetKey: 'uadeGainValue',
          value: _settings.uadeGainValue,
          min: 0,
          max: 1,
          divisions: 20,
          format: (v) => l10n.settingsValuePercent((v * 100).round()),
          onChanged: (v) => _settings.uadeGainValue = v,
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(l10n.settingsAppliedLive,
            style: const TextStyle(fontSize: 12)),
      ),
      const SizedBox(height: 8),
    ];
  }

  Future<void> _resetAllSettings(BuildContext context) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsResetAllTitle),
        content: Text(l10n.settingsResetAllBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.settingsCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.settingsReset)),
        ],
      ),
    );
    if (ok == true) await _settings.resetAllSettings();
  }

  List<Widget> _dataChildren(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return [
      // Ce que l'app garde sur disque, poste par poste, avec la suppression en
      // face — la contrepartie du fait qu'elle COPIE des fichiers chez elle.
      ListTile(
        leading: Icon(Icons.sd_storage_outlined, color: cs.primary),
        title: Text(l10n.storageTitle),
        subtitle: Text(l10n.storageSubtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StorageScreen()),
        ),
      ),
      const Divider(height: 1),
      ListTile(
        leading: Icon(Icons.ios_share, color: cs.primary),
        title: Text(l10n.settingsBackupExport),
        subtitle: Text(l10n.settingsBackupExportSubtitle),
        onTap: () => _exportBackup(context),
      ),
      ListTile(
        leading: Icon(Icons.download_outlined, color: cs.primary),
        title: Text(l10n.settingsBackupImport),
        subtitle: Text(l10n.settingsBackupImportSubtitle),
        onTap: () => _importBackup(context),
      ),
      const Divider(height: 1),
      ListTile(
        leading: Icon(Icons.settings_backup_restore, color: cs.error),
        title: Text(l10n.settingsResetAll),
        subtitle: Text(l10n.settingsResetAllSubtitle),
        onTap: () => _resetAllSettings(context),
      ),
      const Divider(height: 1),
      // Renewing the id ABANDONS the account behind it. Offered only while the
      // account is anonymous (starting over costs nothing that can be
      // recovered anyway); once an email is attached, the right gesture is
      // "sign out" from the account screen.
      //
      // ⚠️ Il faut le SAVOIR, pas le supposer: le drapeau n'est écrit qu'après
      // un `getAccount()`, donc absent = « pas encore résolu », et son défaut à
      // `false` offrait l'action destructrice à un compte pourvu d'un e-mail
      // tant que l'écran Compte n'avait pas été ouvert une fois. Un compte sans
      // jeton n'a rien à perdre: l'entrée y reste offerte sans rien demander.
      if (!UserSettings.instance.hasAuthToken ||
          (UserSettings.instance.accountHasEmailKnown &&
              !UserSettings.instance.accountHasEmail)) ...[
        ListTile(
          leading: const Icon(Icons.fingerprint_outlined),
          title: Text(l10n.settingsRenewUserId),
          subtitle: Text(
            UserSettings.instance.userId != null
                ? l10n.settingsUserIdValue(UserSettings.instance.userId!)
                : l10n.settingsNoUserId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _renewUserId(context),
        ),
        const Divider(height: 1),
      ],
      // Un seul geste de nettoyage: base (orphelins + injouables) ET cache.
      // Le détail — chaque étape séparément, et les réinitialisations — vit
      // sous « Avancé », groupé par thème.
      ListTile(
        leading: const Icon(Icons.cleaning_services_outlined),
        title: Text(l10n.settingsCleanAll),
        subtitle: Text(l10n.settingsCleanAllSubtitle),
        onTap: () => _cleanDatabaseAndCache(context),
      ),
      ListTile(
        leading: const Icon(Icons.tune_outlined),
        title: Text(l10n.settingsDataAdvanced),
        subtitle: Text(l10n.settingsDataAdvancedSubtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _SettingsSectionScreen(
            title: l10n.settingsDataAdvanced,
            settings: _settings,
            childrenBuilder: _dataAdvancedChildren,
          ),
        )),
      ),
    ];
  }

  /// En-tête de groupe du sous-écran « Avancé ».
  Widget _dataGroupHeader(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
    );
  }

  /// « Avancé », groupé par THÈME dans l'ordre où l'on s'en sert: la base
  /// (orphelins, puis injouables), le cache, puis ce qui réinitialise — du
  /// moins destructeur au plus.
  List<Widget> _dataAdvancedChildren(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return [
      _dataGroupHeader(context, l10n.settingsDataGroupDb),
      ListTile(
        leading: const Icon(Icons.cleaning_services_outlined),
        title: Text(l10n.settingsCleanDb),
        subtitle: Text(l10n.settingsCleanDbSubtitle),
        onTap: () => _cleanupOrphans(context),
      ),
      ListTile(
        leading: const Icon(Icons.devices_other_outlined),
        title: Text(l10n.settingsCleanLocalTitle),
        subtitle: Text(l10n.settingsCleanLocalBody),
        onTap: () => _cleanMissingLocalEntries(context),
      ),
      const Divider(height: 1),
      _dataGroupHeader(context, l10n.settingsDataGroupCache),
      ListTile(
        leading: const Icon(Icons.image_not_supported_outlined),
        title: Text(l10n.settingsClearCache),
        subtitle: Text(l10n.settingsClearCacheSubtitle),
        onTap: () => _clearCache(context),
      ),
      const Divider(height: 1),
      _dataGroupHeader(context, l10n.settingsDataGroupReset),
      ListTile(
        leading: Icon(Icons.delete_sweep_outlined, color: cs.error),
        title: Text(l10n.settingsResetStats,
            style: TextStyle(color: cs.error)),
        subtitle: Text(l10n.settingsResetStatsSubtitle),
        onTap: () => _confirmClearHistory(context),
      ),
      ListTile(
        leading: Icon(Icons.folder_delete_outlined, color: cs.error),
        title: Text(l10n.settingsDeleteDownloads,
            style: TextStyle(color: cs.error)),
        subtitle: Text(l10n.settingsDeleteDownloadsSubtitle),
        onTap: () => _confirmDeleteOnlineLibrary(context),
      ),
      ListTile(
        leading: Icon(Icons.delete_forever_outlined, color: cs.error),
        title: Text(l10n.settingsResetDatabase,
            style: TextStyle(color: cs.error)),
        subtitle: Text(l10n.settingsResetDatabaseSubtitle),
        onTap: () => _confirmResetDatabase(context),
      ),
    ];
  }
}

// ── Level 2 detail screen ────────────────────────────────────────────────────

/// Per-setting reset affordance: visible only when the value was customised.
/// [name] is the semantic key in UserSettings.kEnginePrefKeys.
class _ResetDot extends StatelessWidget {
  final String name;
  const _ResetDot(this.name);

  @override
  Widget build(BuildContext context) {
    final s = UserSettings.instance;
    final prefKey = UserSettings.kEnginePrefKeys[name];
    if (prefKey == null) return const SizedBox.shrink();
    // Listen HERE, not just in the enclosing page: these dots are built as
    // `const`, and Flutter skips rebuilding an element whose new widget is the
    // identical const instance — so a parent rebuild never reached them and the
    // dot only appeared/vanished after leaving and re-entering the screen.
    return ListenableBuilder(
      listenable: s,
      builder: (_, __) {
        if (!s.isSet(prefKey)) return const SizedBox.shrink();
        return IconButton(
          icon: const Icon(Icons.restart_alt, size: 16),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: context.l10n.settingsResetToDefault,
          onPressed: () => s.resetSetting(prefKey),
        );
      },
    );
  }
}

class _SettingsSectionScreen extends StatelessWidget {
  final String title;
  final UserSettings settings;
  final List<Widget> Function(BuildContext) childrenBuilder;

  const _SettingsSectionScreen({
    required this.title,
    required this.settings,
    required this.childrenBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      // Rebuild on any settings change so toggles/sliders update live.
      body: ListenableBuilder(
        listenable: settings,
        builder: (ctx, _) => ListView(
          children: [
            const SizedBox(height: 8),
            ...childrenBuilder(ctx),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Reusable layout helpers ──────────────────────────────────────────────────

/// A settings row showing a color swatch; tapping opens a picker.
/// The 16 base colours of a note palette as an 8×2 mosaic — shown inside each
/// palette-selector item so the choice is visible, not just named.
class _PaletteSwatch extends StatelessWidget {
  final int palette;

  const _PaletteSwatch({required this.palette});

  static const double cell = 6;
  static const double gap  = 1.5;

  @override
  Widget build(BuildContext context) {
    final colors = UserSettings.notePaletteColors[
        palette.clamp(0, UserSettings.notePaletteColors.length - 1)];
    const perRow = 8;
    Widget row(int start) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = start; i < start + perRow && i < colors.length; i++)
              Container(
                width:  cell,
                height: cell,
                margin: const EdgeInsets.all(gap / 2),
                decoration: BoxDecoration(
                  color: Color(0xFF000000 | colors[i]),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
          ],
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [row(0), row(perRow)],
    );
  }
}

class _ColorTile extends StatelessWidget {
  final String label;
  final int color;                 // 0xRRGGBB
  final ValueChanged<int> onPicked;
  /// Semantic setting name (UserSettings.kEnginePrefKeys) → per-setting reset.
  final String? resetKey;

  const _ColorTile({
    required this.label,
    required this.color,
    required this.onPicked,
    this.resetKey,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: resetKey == null ? null : _ResetDot(resetKey!),
      title: Text(label),
      trailing: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: Color(0xFF000000 | color),
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      onTap: () async {
        final picked = await showDialog<int>(
          context: context,
          builder: (_) => _ColorPickerDialog(initial: color),
        );
        if (picked != null) onPicked(picked);
      },
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final int initial; // 0xRRGGBB
  const _ColorPickerDialog({required this.initial});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _r = ((widget.initial >> 16) & 0xFF).toDouble();
  late double _g = ((widget.initial >> 8) & 0xFF).toDouble();
  late double _b = (widget.initial & 0xFF).toDouble();

  static const _presets = <int>[
    0x00FF44, 0x6BC7FF, 0xFF6B1F, 0xFFFFFF, 0xFFD400, 0xFF3B6B,
    0xB46BFF, 0x00E0C0, 0xFF00AA, 0x7FFF00,
  ];

  int get _value => ((_r.round() & 0xFF) << 16) | ((_g.round() & 0xFF) << 8) | (_b.round() & 0xFF);

  void _setFrom(int v) => setState(() {
        _r = ((v >> 16) & 0xFF).toDouble();
        _g = ((v >> 8) & 0xFF).toDouble();
        _b = (v & 0xFF).toDouble();
      });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.settingsColor),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFF000000 | _value),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final p in _presets)
                GestureDetector(
                  onTap: () => _setFrom(p),
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: Color(0xFF000000 | p),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _channel('R', _r, Colors.red,   (v) => setState(() => _r = v)),
          _channel('G', _g, Colors.green, (v) => setState(() => _g = v)),
          _channel('B', _b, Colors.blue,  (v) => setState(() => _b = v)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.settingsCancel)),
        FilledButton(
            onPressed: () => Navigator.pop(context, _value),
            child: Text(l10n.settingsOk)),
      ],
    );
  }

  Widget _channel(String lbl, double v, Color c, ValueChanged<double> onChanged) {
    return Row(children: [
      SizedBox(width: 16, child: Text(lbl)),
      Expanded(
        child: Slider(
          value: v, min: 0, max: 255, activeColor: c,
          onChanged: onChanged,
        ),
      ),
      SizedBox(width: 32, child: Text(v.round().toString(), textAlign: TextAlign.end)),
    ]);
  }
}

/// Off / Low / High selector for a CRT effect level (0/1/2).
class _CrtLevelSelector extends StatelessWidget {
  final int level;
  final ValueChanged<int> onChanged;

  const _CrtLevelSelector({required this.level, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<int>(
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        ButtonSegment(value: 0, label: Text(l10n.settingsOff)),
        ButtonSegment(value: 1, label: Text(l10n.settingsLevelLow)),
        ButtonSegment(value: 2, label: Text(l10n.settingsLevelHigh)),
      ],
      selected: {level},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Credits row with a project link. The link is an ICON that opens the page in
/// the platform's own browser (url_launcher) — it used to be a whole-tile tap
/// that merely copied the URL to the clipboard, which told the user nothing
/// about where it went. Falls back to copying only if no browser can be
/// launched (a locked-down device), so the URL is never simply lost.
class _CreditTile extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;
  final String   url;

  const _CreditTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  Future<void> _open(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (_) {/* fall through to the clipboard */}
    if (opened) return;
    await Clipboard.setData(ClipboardData(text: url));
    AppSnack.showOn(messenger, l10n.settingsLinkCopied(url),
        duration: const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      isThreeLine: true,
      trailing: IconButton(
        icon: const Icon(Icons.open_in_new),
        tooltip: context.l10n.settingsOpenLink,
        onPressed: () => _open(context),
      ),
      onTap: () => _open(context),
    );
  }
}

class _SubHeader extends StatelessWidget {
  final String      label;
  final ColorScheme cs;
  final TextTheme   textTheme;

  const _SubHeader({
    required this.label,
    required this.cs,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: textTheme.labelMedium?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Label on the left, arbitrary widget on the right.
/// Publique pour être TESTABLE: la règle « le contrôle est borné, le label
/// garde un plancher » se vérifie à des largeurs réelles, et un widget privé
/// obligerait le test à recopier la disposition — donc à tester sa copie.
class SettingRow extends StatelessWidget {
  final String label;
  final Widget child;
  /// Semantic setting name (UserSettings.kEnginePrefKeys) → shows a small
  /// reset-to-default button when the value was customised.
  final String? resetKey;

  const SettingRow(
      {super.key, required this.label, required this.child, this.resetKey});

  /// Ce que le LABEL garde au minimum, en pixels: la pastille de
  /// réinitialisation demande 28 px et quelques glyphes doivent tenir à côté.
  static const double _kLabelFloor = 96;

  @override
  Widget build(BuildContext context) {
    // ⚠️ Le contrôle est BORNÉ, sinon il mange toute la largeur.
    //
    // Plusieurs de ces contrôles sont des `SingleChildScrollView` horizontaux
    // (un SegmentedButton de cinq segments ne tient pas sur un téléphone et ne
    // scrolle pas tout seul) — et une vue défilante prend TOUTE la contrainte
    // qu'on lui donne, quelle que soit la taille de son contenu. Le côté label,
    // en `Expanded`, ne recevait donc plus que ce qui restait: mesuré à 8,4 px
    // sur une fenêtre étroite, où la pastille de réinitialisation (28 px de
    // large au minimum) débordait de 12 px — « A RenderFlex overflowed ».
    //
    // Un `LayoutBuilder` plutôt qu'un partage de flex: avec deux `Flexible` le
    // label serait plafonné à sa part MÊME quand le contrôle est un simple
    // interrupteur, et un libellé long s'élidrait pour rien. Ici le contrôle
    // n'est qu'un enfant NON flexible avec un plafond, donc il garde sa taille
    // naturelle quand elle est petite et le label reçoit tout le reste — la
    // disposition d'aujourd'hui, moins la famine.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: LayoutBuilder(
        builder: (ctx, cons) {
          final w = cons.maxWidth;
          final cap = w.isFinite
              ? math.max(0.0, math.min(w * 0.6, w - _kLabelFloor))
              : double.infinity;
          return Row(
            children: [
              Expanded(
                child: Row(children: [
                  Flexible(
                      child: Text(label,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium)),
                  if (resetKey != null) _ResetDot(resetKey!),
                ]),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: cap),
                child: child,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Label + current-value badge + Slider.
class _SliderRow extends StatelessWidget {
  final String        label;
  final double        value;
  final double        min;
  final double        max;
  final int?          divisions;
  final String Function(double) format;
  final ValueChanged<double>    onChanged;
  /// Semantic setting name (UserSettings.kEnginePrefKeys) → shows a small
  /// reset-to-default button when the value was customised.
  final String? resetKey;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.format,
    required this.onChanged,
    this.resetKey,
  });

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: textTheme.bodyMedium),
                if (resetKey != null) _ResetDot(resetKey!),
              ]),
              Text(
                format(value),
                style: textTheme.bodySmall?.copyWith(color: cs.primary),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: format(value),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}


// ── MIDI SoundFont picker (server assets catalogue) ─────────────────────────

class _SoundfontPicker extends StatefulWidget {
  const _SoundfontPicker();

  @override
  State<_SoundfontPicker> createState() => _SoundfontPickerState();
}

class _SoundfontPickerState extends State<_SoundfontPicker> {
  List<RemoteAsset>? _assets;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final assets = await SoundfontManager.instance.catalogue();
      if (mounted) setState(() => _assets = assets);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  String _sizeLabel(AppLocalizations l10n, int bytes) => bytes >= (1 << 20)
      ? l10n.settingsSizeMb((bytes / (1 << 20)).toStringAsFixed(1))
      : l10n.settingsSizeKb((bytes / (1 << 10)).toStringAsFixed(0));

  /// Importe une soundfont personnelle depuis l'appareil, et la SÉLECTIONNE:
  /// on ne va pas chercher un fichier pour ensuite devoir le cocher.
  Future<void> _importLocal() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    String? path;
    if (pickerUsesFilePicker) {
      // MOBILE: file_picker et pas file_selector, pour deux raisons distinctes.
      //
      // Android: file_selector y renomme la copie d'après le type MIME résolu,
      // et un `.sf2` devient octet-stream — le fichier arriverait en
      // « soundfont.bin ». Android filtre par MIME de toute façon, une liste
      // d'extensions n'y sert à rien.
      //
      // ⚠️ iOS: file_selector n'accepte QUE des UTI
      // (`XTypeGroup.uniformTypeIdentifiers`) et lève un ArgumentError sur un
      // groupe qui ne porte que des `extensions` — le bouton d'import ne
      // faisait donc RIEN du tout. Aucun UTI système ne décrit une SoundFont;
      // le seul filtre possible serait `public.data`, soit aucun filtre. La
      // validation ne vient de toute façon pas de l'extension mais de l'en-tête
      // (`RIFF`…`sfbk`, vérifié par importLocal).
      //
      // `pickFile` (singulier) est la porte du choix UNIQUE en file_picker 12:
      // `pickFiles` sélectionne désormais plusieurs fichiers PAR DÉFAUT.
      final res = await fp.FilePicker.pickFile(type: fp.FileType.any);
      path = res?.path;
    } else {
      const group = XTypeGroup(label: 'SoundFont', extensions: ['sf2']);
      final xf = await openFile(
          acceptedTypeGroups: const [group],
          initialDirectory: await PickerMemory.startDir(PickerSlot.soundfont));
      path = xf?.path;
      await PickerMemory.rememberFile(PickerSlot.soundfont, path);
    }
    if (path == null) return;
    try {
      final slug = await SoundfontManager.instance.importLocal(path);
      // importLocal a COPIÉ la SF2 dans le dossier des soundfonts: la copie
      // qu'iOS avait déposée dans notre Inbox n'a plus d'usage, et une SF2 pèse
      // couramment 100 Mo.
      await consumeInboxCopy(path);
      await SoundfontManager.instance.select(slug);
      if (mounted) setState(() {});
    } on FormatException {
      // Un fichier qui n'est pas une SF2 donne un synthé MUET, pas une erreur:
      // le dire ICI est la seule occasion de le rattacher au geste.
      AppSnack.showOn(messenger, l10n.settingsSoundfontInvalid, isError: true);
    } catch (e) {
      AppSnack.showOn(messenger, l10n.settingsSoundfontImportFailed('$e'),
          isError: true);
    }
  }

  Future<void> _tap(RemoteAsset a) async {
    final l10n = context.l10n;
    final mgr = SoundfontManager.instance;
    if (!mgr.isInstalled(a.slug)) {
      try {
        await mgr.download(a);
      } catch (e) {
        if (mounted) {
          AppSnack.show(context, l10n.settingsSoundfontDownloadFailed('$e'), duration: const Duration(seconds: 4));
        }
        return;
      }
    }
    await mgr.select(a.slug);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = UserSettings.instance.midiSoundfont;
    final mgr = SoundfontManager.instance;
    final assets = _assets;
    // Le catalogue SERVEUR peut être en erreur ou en cours de chargement sans
    // que ça concerne les soundfonts DÉJÀ sur l'appareil: l'état du réseau
    // occupe une ligne, il ne remplace pas la liste. Sinon, hors ligne, une
    // soundfont importée devenait inatteignable — et le bouton d'import avec.
    return ValueListenableBuilder<Map<String, double>>(
      valueListenable: mgr.progress,
      builder: (_, prog, __) => Column(
        children: [
          if (_error != null)
            ListTile(
                dense: true,
                leading: const Icon(Icons.cloud_off),
                title: Text(l10n.settingsSoundfontCatalogueError(_error!)))
          else if (assets == null)
            ListTile(
                dense: true,
                leading: const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                title: Text(l10n.settingsSoundfontLoading)),
          for (final a in assets ?? const <RemoteAsset>[])
            ListTile(
              leading: Radio<String>(
                value: a.slug,
                // ignore: deprecated_member_use
                groupValue: selected,
                // ignore: deprecated_member_use
                onChanged: mgr.isInstalled(a.slug) && prog[a.slug] == null
                    ? (_) => _tap(a)
                    : null,
              ),
              title: Text(a.name),
              subtitle: Text([
                _sizeLabel(l10n, a.sizeBytes),
                if (a.description != null && a.description!.isNotEmpty)
                  a.description!,
              ].join(' — '), maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: prog[a.slug] != null
                  ? SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, value: prog[a.slug]))
                  : mgr.isInstalled(a.slug)
                      ? (selected == a.slug
                          ? Icon(Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary)
                          : IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: l10n.settingsSoundfontDelete,
                              onPressed: () async {
                                await mgr.delete(a.slug);
                                if (mounted) setState(() {});
                              }))
                      : const Icon(Icons.download_outlined),
              onTap: prog[a.slug] == null ? () => _tap(a) : null,
            ),
          // Soundfonts personnelles: mêmes lignes, même sélection — une fois
          // copiée dans le dossier, une importation n'est plus un cas à part.
          for (final f in mgr.localFonts())
            ListTile(
              leading: Radio<String>(
                value: f.slug,
                // ignore: deprecated_member_use
                groupValue: selected,
                // ignore: deprecated_member_use
                onChanged: (_) => _selectLocal(f.slug),
              ),
              title: Text(f.name),
              subtitle: Text([
                _sizeLabel(l10n, f.sizeBytes),
                l10n.settingsSoundfontImported,
              ].join(' — '), maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: selected == f.slug
                  ? Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary)
                  : IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: l10n.settingsSoundfontDelete,
                      onPressed: () async {
                        await mgr.delete(f.slug);
                        if (mounted) setState(() {});
                      }),
              onTap: () => _selectLocal(f.slug),
            ),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text(l10n.settingsSoundfontImport),
            subtitle: Text(l10n.settingsSoundfontImportSubtitle),
            onTap: _importLocal,
          ),
        ],
      ),
    );
  }

  Future<void> _selectLocal(String slug) async {
    await SoundfontManager.instance.select(slug);
    if (mounted) setState(() {});
  }
}

// ── projectM settings (3rd level: Réglages → Visualisation → projectM) ────────
// Mirrors Modizer's SettingsGenViewController projectM family (minus FX layout
// and bundled/custom presets, which don't apply yet).

/// Pattern visualizer settings — the same knobs as the in-viz overlay, in a
/// 3rd-level page like projectM's, with per-setting reset dots and a section
/// reset. Its own kSectionKeys entry ('pattern') so that reset restores the
/// grid's settings only, not every visualizer.
class PatternSettingsScreen extends StatefulWidget {
  const PatternSettingsScreen({super.key});

  @override
  State<PatternSettingsScreen> createState() => _PatternSettingsScreenState();
}

class _PatternSettingsScreenState extends State<PatternSettingsScreen> {
  final _s = UserSettings.instance;

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

  void _onChanged() { if (mounted) setState(() {}); }

  Widget _title(String label, String resetKey) => Row(
        children: [Flexible(child: Text(label)), _ResetDot(resetKey)],
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPatternTitle)),
      body: ListView(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.restart_alt, size: 16),
                label: Text(l10n.settingsResetSection),
                onPressed: () => _s.resetSectionSettings('pattern'),
              ),
            ),
          ),
          ListTile(
            title: _title(l10n.patternColorScheme, 'patternPalette'),
            trailing: DropdownButton<int>(
              value: _s.patternPalette,
              onChanged: (v) { if (v != null) _s.patternPalette = v; },
              items: [
                for (int i = 0; i < PatternPalette.presets.length; i++)
                  DropdownMenuItem(
                      value: i, child: Text(PatternPalette.presets[i].name)),
              ],
            ),
          ),
          ListTile(
            title: _title(l10n.patternColumns, 'patternColumns'),
            trailing: DropdownButton<int>(
              value: _s.patternColumns,
              onChanged: (v) { if (v != null) _s.patternColumns = v; },
              items: [
                DropdownMenuItem(value: 0, child: Text(l10n.patternColumnsAll)),
                DropdownMenuItem(
                    value: 1, child: Text(l10n.patternColumnsNoteInstr)),
                DropdownMenuItem(value: 2, child: Text(l10n.patternColumnsNote)),
              ],
            ),
          ),
          // CURSEUR et non menu: la taille est continue (0.25→2 par 0.05, 36
          // crans) — un menu de 36 entrées serait scrollable, donc avec sa
          // bande morte en haut de première cellule (voir settings_long_picker).
          _SliderRow(
            label: l10n.patternSize,
            resetKey: 'patternSize',
            value: _s.patternSize,
            min: UserSettings.kPatternSizeMin,
            max: UserSettings.kPatternSizeMax,
            divisions: ((UserSettings.kPatternSizeMax -
                        UserSettings.kPatternSizeMin) /
                    UserSettings.kPatternSizeStep)
                .round(),
            format: (v) => '×${v.toStringAsFixed(2)}',
            onChanged: (v) => _s.patternSize = v,
          ),
          SwitchListTile(
            title: _title(l10n.patternSmoothScroll, 'patternSmoothScroll'),
            value: _s.patternSmoothScroll,
            onChanged: (v) => _s.patternSmoothScroll = v,
          ),
          SwitchListTile(
            // La barre devient un AFFICHEUR de la ligne entendue: le motif
            // défile toujours, mais on ne lit plus deux demi-lignes au centre.
            // Sans défilement fluide il n'y a rien à épingler — la bascule est
            // alors éteinte plutôt que trompeuse.
            title: _title(l10n.patternPinnedRow, 'patternPinnedRow'),
            value: _s.patternPinnedRow,
            onChanged: _s.patternSmoothScroll
                ? (v) => _s.patternPinnedRow = v
                : null,
          ),
          SwitchListTile(
            // Only meaningful on a NATIVE tracker grid; a synthesized one has
            // no page to scroll and the renderer forces it off anyway.
            title: _title(l10n.patternScrollMode, 'patternScrollMode'),
            value: _s.patternScrollMode == 1,
            onChanged: (v) => _s.patternScrollMode = v ? 1 : 0,
          ),
          SwitchListTile(
            title: _title(l10n.patternVolumeBars, 'patternShowVolume'),
            value: _s.patternShowVolume,
            onChanged: (v) => _s.patternShowVolume = v,
          ),
          SwitchListTile(
            title: _title(l10n.patternOpaqueBg, 'patternOpaqueBg'),
            subtitle: Text(l10n.patternOpaqueBgSubtitle),
            value: _s.patternOpaqueBg,
            onChanged: (v) => _s.patternOpaqueBg = v,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class ProjectMSettingsScreen extends StatefulWidget {
  const ProjectMSettingsScreen({super.key});

  @override
  State<ProjectMSettingsScreen> createState() => _ProjectMSettingsScreenState();
}

class _ProjectMSettingsScreenState extends State<ProjectMSettingsScreen> {
  final _s = UserSettings.instance;

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

  void _onChanged() => setState(() {});

  /// A switch/dropdown title with a per-setting reset dot (shown when the value
  /// was customised), matching the _SliderRow(resetKey:)/_SettingRow pattern.
  /// Le motif de transition, choisi dans une LISTE — voir la note au site
  /// d'appel: un menu déroulant scrollable a une bande morte en haut de sa
  /// première cellule, et 23 motifs le rendent scrollable partout.
  Future<void> _pickTransitionPattern(BuildContext context) async {
    const names = UserSettings.pmTransitionNames;
    final current = _s.pmTransition;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(context.l10n.settingsPmTransitionStyle),
        children: [
          for (int i = 0; i < names.length; i++)
            ListTile(
              selected: i == current,
              leading: Icon(i == current
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              title: Text(names[i]),
              onTap: () => Navigator.pop(ctx, i),
            ),
        ],
      ),
    );
    if (picked != null) _s.pmTransition = picked;
  }

  Widget _pmTitle(String label, String resetKey) => Row(
        children: [
          Flexible(child: Text(label)),
          _ResetDot(resetKey),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final l10n      = context.l10n;
    final cs        = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('projectM')),
      body: ListView(
        children: [
          // Section reset at the TOP, like the other settings sections.
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.restart_alt, size: 16),
                label: Text(l10n.settingsResetSection),
                onPressed: () => _s.resetSectionSettings('projectm'),
              ),
            ),
          ),
          _SubHeader(label: l10n.settingsPmPresets, cs: cs, textTheme: textTheme),
          // Packs / playlists / imports manager — the presets themselves.
          ListTile(
            leading: const Icon(Icons.library_music_outlined),
            title: Text(l10n.pmManagePresets),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PresetScreen()),
            ),
          ),
          // Presets écartés par le garde-fou de cadence. La ligne n'existe que
          // s'il y en a: sans elle, un preset écarté disparaît en silence et
          // rien ne permet de revenir dessus — un mécanisme de protection ne
          // doit pas être un cul-de-sac. Le compte est dans le libellé, c'est
          // la seule chose à savoir.
          if (_s.pmSlowPresets.isNotEmpty)
            ListTile(
              title: Text(l10n.settingsPmSlowPresets(_s.pmSlowPresets.length)),
              subtitle: Text(l10n.settingsPmSlowPresetsSubtitle),
              // Ouvre la LISTE plutôt que de tout rétablir d'un geste: les
              // presets y sont nommés avec leur pack et leur sous-dossier, et
              // se réhabilitent un par un — un bouton « tout rétablir » aveugle
              // ici ramènerait aussi ceux qu'on voulait garder écartés.
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PresetScreen(initialTab: 4)));
                if (context.mounted) setState(() {});
              },
            ),
          SwitchListTile(
            title: _pmTitle(l10n.settingsPmRandomNext, 'pmRandom'),
            subtitle: Text(l10n.settingsPmRandomNextSubtitle),
            value: _s.pmRandomNext,
            onChanged: (v) => _s.pmRandomNext = v,
          ),
          SwitchListTile(
            title: _pmTitle(l10n.settingsPmLockPreset, 'pmLockPreset'),
            subtitle: Text(l10n.settingsPmLockPresetSubtitle),
            value: _s.pmLockPreset,
            onChanged: (v) => _s.pmLockPreset = v,
          ),
          _SliderRow(
            label: l10n.settingsPmPresetDuration,
            resetKey: 'pmPresetDuration',
            value: _s.pmPresetDuration,
            min: 3, max: 60, divisions: 57,
            format: (v) => l10n.settingsValueSeconds(v.round()),
            onChanged: (v) => _s.pmPresetDuration = v,
          ),
          _SubHeader(
              label: l10n.settingsPmTransitions, cs: cs, textTheme: textTheme),
          SwitchListTile(
            title: _pmTitle(l10n.settingsPmBlend, 'pmBlend'),
            subtitle: Text(l10n.settingsPmBlendSubtitle),
            value: _s.pmBlend,
            onChanged: (v) => _s.pmBlend = v,
          ),
          if (_s.pmBlend)
            _SliderRow(
              label: l10n.settingsFadeoutDuration,
              resetKey: 'pmBlendTime',
              value: _s.pmBlendTime,
              min: 0.5, max: 10, divisions: 19,
              format: (v) => l10n.settingsValueSecondsFrac(v.toStringAsFixed(1)),
              onChanged: (v) => _s.pmBlendTime = v,
            ),
          // Only under `pmBlend`: a hard cut has no transition at all, so the
          // picker would be a setting with no observable effect.
          //
          // « Aléatoire » est un INTERRUPTEUR, pas une entrée du menu. Avec les
          // 23 motifs il en faisait 24, soit ~1150 px de menu: plus haut que
          // toute fenêtre, donc défilant — et un `DropdownButton` ouvre son
          // menu en alignant l'élément SÉLECTIONNÉ sous le bouton, si bien que
          // le premier sortait de l'écran dès qu'un motif de fin de liste était
          // actif. Il fallait faire défiler, et un tap juste après un
          // défilement est absorbé par le scroll: « ça marche par endroits ».
          // Un choix binaire noyé dans une liste de noms propres n'avait de
          // toute façon pas sa place là.
          if (_s.pmBlend) ...[
            SwitchListTile(
              title: _pmTitle(l10n.settingsPmTransitionRandom, 'pmTransition'),
              subtitle: Text(l10n.settingsPmTransitionStyleSubtitle),
              value: _s.pmTransition < 0,
              onChanged: (v) => _s.pmTransition = v ? -1 : 0,
            ),
            // Une LISTE, pas un DropdownButton. ⚠️ Mesuré (test/
            // settings_long_picker_test.dart): dès qu'un menu déroulant Material
            // devient SCROLLABLE, le haut de sa PREMIÈRE cellule est mort — le
            // `kMaterialListPadding` du ListView interne mange ~8 px, un tap y
            // atterrit sur la liste et pas sur l'entrée. Rien à voir avec la
            // valeur choisie: sortir « Aléatoire » du menu n'a fait que déplacer
            // le symptôme sur « Circle ». 23 motifs = ~1150 px de menu, donc
            // scrollable sur toute fenêtre. Un dialogue liste n'a pas ce défaut,
            // montre la sélection courante et reste atteignable.
            //
            // Masqué sous « Aléatoire »: un motif épinglé n'y aurait aucun effet
            // observable, comme le bloc entier sous une coupe franche.
            if (_s.pmTransition >= 0)
              ListTile(
                title: Text(l10n.settingsPmTransitionStyle),
                // Pattern names are proper names, untranslated — same rule as
                // the notation palettes and the Milkdrop preset names.
                trailing: Text(
                    UserSettings.pmTransitionNames[_s.pmTransition],
                    style: TextStyle(color: cs.primary)),
                onTap: () => _pickTransitionPattern(context),
              ),
          ],
          SwitchListTile(
            title: _pmTitle(l10n.settingsPmHardcut, 'pmHardcut'),
            subtitle: Text(l10n.settingsPmHardcutSubtitle),
            value: _s.pmHardcut,
            onChanged: (v) => _s.pmHardcut = v,
          ),
          if (_s.pmHardcut) ...[
            _SliderRow(
              label: l10n.settingsPmHardcutTime,
              resetKey: 'pmHardcutTime',
              value: _s.pmHardcutTime,
              min: 0, max: 60, divisions: 60,
              format: (v) => l10n.settingsValueSeconds(v.round()),
              onChanged: (v) => _s.pmHardcutTime = v,
            ),
            _SliderRow(
              label: l10n.settingsPmHardcutSensitivity,
              resetKey: 'pmHardcutSensitivity',
              value: _s.pmHardcutSensitivity,
              min: 0, max: 5, divisions: 50,
              format: (v) => v.toStringAsFixed(1),
              onChanged: (v) => _s.pmHardcutSensitivity = v,
            ),
          ],
          _SubHeader(
              label: l10n.settingsPmRendering, cs: cs, textTheme: textTheme),
          ListTile(
            title: _pmTitle(l10n.settingsPmQuality, 'pmQuality'),
            subtitle: Text(l10n.settingsPmQualitySubtitle),
            trailing: DropdownButton<int>(
              value: _s.pmQuality,
              items: [
                for (int i = 0; i < UserSettings.pmQualityNames.length; i++)
                  DropdownMenuItem(
                      value: i, child: Text(UserSettings.pmQualityNames[i])),
              ],
              onChanged: (v) { if (v != null) _s.pmQuality = v; },
            ),
          ),
          _SliderRow(
            label: 'Mesh X',
            resetKey: 'pmMeshX',
            value: _s.pmMeshX.toDouble(),
            min: 8, max: 128, divisions: 120,
            format: (v) => '${v.round()}',
            onChanged: (v) => _s.pmMeshX = v.round(),
          ),
          _SliderRow(
            label: 'Mesh Y',
            resetKey: 'pmMeshY',
            value: _s.pmMeshY.toDouble(),
            min: 6, max: 96, divisions: 90,
            format: (v) => '${v.round()}',
            onChanged: (v) => _s.pmMeshY = v.round(),
          ),
          _SliderRow(
            label: l10n.settingsPmBeatSensitivity,
            resetKey: 'pmBeatSensitivity',
            value: _s.pmBeatSensitivity,
            min: 0, max: 5, divisions: 50,
            format: (v) => v.toStringAsFixed(1),
            onChanged: (v) => _s.pmBeatSensitivity = v,
          ),
          SwitchListTile(
            title: _pmTitle(l10n.settingsPmAspectRatio, 'pmAspectCorrection'),
            subtitle: Text(l10n.settingsPmAspectRatioSubtitle),
            value: _s.pmAspectRatio,
            onChanged: (v) => _s.pmAspectRatio = v,
          ),
          SwitchListTile(
            title: _pmTitle(l10n.settingsPmPermissive, 'pmPermissive'),
            subtitle: Text(l10n.settingsPmPermissiveSubtitle),
            value: _s.pmPermissive,
            onChanged: (v) => _s.pmPermissive = v,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// About — a top-level menu destination gathering everything that is NOT a
// setting: contact/support, tips, and credits/licenses. Reuses the settings
// two-level section pattern (_sectionTile → _SettingsSectionScreen); same
// library, so the private helpers stay reachable. The content builders below
// are top-level (they touch no state) and owned by this screen.
// ══════════════════════════════════════════════════════════════════════════

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Widget _sectionTile(BuildContext context, IconData icon, String title,
      String subtitle, List<Widget> Function(BuildContext) childrenBuilder) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _SettingsSectionScreen(
          title: title,
          settings: UserSettings.instance,
          childrenBuilder: childrenBuilder,
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAbout)),
      body: ListView(
        children: [
          const _AboutHeader(),
          const Divider(height: 1),
          _sectionTile(context, Icons.contact_support_outlined,
              l10n.settingsSupport, l10n.settingsSupportSubtitle,
              _supportChildren),
          _sectionTile(context, Icons.volunteer_activism_outlined,
              l10n.settingsDonation, l10n.settingsDonationSubtitle,
              _donationChildren),
          _sectionTile(context, Icons.info_outline,
              l10n.settingsAboutSubtitle, l10n.settingsCreditsSubtitle,
              _aboutChildren),
          // Relire la note de version. Elle n'était visible qu'UNE fois, au
          // premier lancement d'une build: qui la ferme trop vite n'avait
          // aucun moyen d'y revenir, et rien ne disait ce que cette beta
          // apportait. Le sous-titre porte le nom de version — un nom, donc
          // pas de clé de traduction.
          ListTile(
            leading: Icon(Icons.new_releases_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: Text(l10n.releaseNotesTitle,
                style: Theme.of(context).textTheme.titleMedium),
            subtitle: const Text(kReleaseNotesLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showReleaseNotes(context),
          ),
          // Replays the first-run carousel for the CURRENT build: the beta
          // notice with its version/build line is the thing a tester needs to
          // quote, and it is otherwise only shown once per update.
          ListTile(
            leading: Icon(Icons.slideshow_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: Text(l10n.onboardingReplayTitle,
                style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(l10n.onboardingReplaySubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Onboarding.show(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Header of the About screen: app name, running version/build, authorship.
///
/// The version is the one thing a tester has to quote in a bug report, and it
/// was otherwise only visible inside the once-per-build onboarding carousel.
/// The author line is a proper name — not translated, hence no ARB key.
class _AboutHeader extends StatelessWidget {
  const _AboutHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs   = Theme.of(context).colorScheme;
    final tt   = Theme.of(context).textTheme;
    return FutureBuilder<void>(
      future: ClientInfo.instance.ensureLoaded(),
      builder: (context, _) {
        final ci = ClientInfo.instance;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.graphic_eq,
                    size: 28, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rewamp', style: tt.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      l10n.onboardingVersion(
                          ci.appVersion ?? '?', ci.appBuild ?? '?'),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text('© Yohann Magnien — YoyoFR',
                        style:
                            tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── About content builders (stateless, top-level) ──────────────────────────

// ── Contact & support ──
List<Widget> _supportChildren(BuildContext context) {
  final l10n = context.l10n;
  return [
    ListTile(
      leading: const Icon(Icons.email_outlined),
      title: Text(l10n.settingsSupportEmail),
      subtitle: Text(l10n.settingsSupportEmailSubtitle),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => _sendSupportEmail(context),
    ),
    const Divider(height: 1),
    _CreditTile(
      icon: Icons.language,
      title: l10n.settingsSupportWebsite,
      subtitle: 'rewamp.app',
      url: 'https://rewamp.app',
    ),
  ];
}

/// Open the OS mail client with a pre-filled message to the support address,
/// including the environment block (OS, device, app version, language, user
/// id) so a report is actionable. Falls back to copying the address when no
/// mail client is registered (common on the simulator / a bare desktop).
Future<void> _sendSupportEmail(BuildContext context) async {
  final l10n      = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final lang      = Localizations.localeOf(context).toLanguageTag();
  await ClientInfo.instance.ensureLoaded();
  final ci  = ClientInfo.instance;
  final uid = UserSettings.instance.userId ?? 'n/a';
  final env = StringBuffer()
    ..writeln()
    ..writeln()
    ..writeln('----------')
    ..writeln('Rewamp ${ci.appVersion ?? '?'} (${ci.appBuild ?? '?'})')
    ..writeln('${ci.osName ?? '?'} ${ci.osVersion ?? ''}'.trim())
    ..writeln('Device: ${ci.device ?? '?'}')
    ..writeln('Lang: $lang')
    ..writeln('ID: $uid')
    ..write('----------');
  final body = '${l10n.settingsSupportEmailIntro}\n$env';
  final uri = Uri.parse(
    'mailto:$kSupportEmail'
    '?subject=${Uri.encodeComponent(l10n.settingsSupportEmailSubject)}'
    '&body=${Uri.encodeComponent(body)}',
  );
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {/* fall through to the clipboard */}
  if (opened) return;
  await Clipboard.setData(const ClipboardData(text: kSupportEmail));
  AppSnack.showOn(messenger, l10n.settingsLinkCopied(kSupportEmail),
      duration: const Duration(seconds: 2));
}

/// L'adresse de contact. Elle apparaissait à trois endroits de cette fonction
/// (le mailto, le presse-papiers de repli et le message qui le confirme) — trois
/// littéraux qui doivent rester d'accord, donc trois occasions de diverger.
const kSupportEmail = 'help@rewamp.app';

// ── Tips / donation ──
List<Widget> _donationChildren(BuildContext context) {
  final l10n = context.l10n;
  final cs   = Theme.of(context).colorScheme;
  final tt   = Theme.of(context).textTheme;
  return [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Text(l10n.settingsDonationBlurb,
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
    ),
    const Divider(height: 1),
    _donateTile(context, Icons.save, l10n.settingsDonationFloppy, 2),
    const Divider(height: 1),
    _donateTile(context, Icons.videogame_asset, l10n.settingsDonationCartridge, 5),
    const Divider(height: 1),
    _donateTile(context, Icons.inventory_2, l10n.settingsDonationBox, 10),
    const Divider(height: 1),
    _donateTile(context, Icons.volunteer_activism, l10n.settingsDonationCustom, null),
  ];
}

Widget _donateTile(
    BuildContext context, IconData icon, String label, int? amount) {
  final cs = Theme.of(context).colorScheme;
  return ListTile(
    leading: Icon(icon, color: cs.primary),
    title: Text(label),
    subtitle: amount != null ? Text('$amount €') : null,
    trailing: const Icon(Icons.open_in_new),
    onTap: () => _openDonate(context, amount),
  );
}

/// Open a PayPal donation for [amount] EUR (null = let the donor choose the
/// amount on PayPal). Falls back to copying the link when no browser opens.
Future<void> _openDonate(BuildContext context, int? amount) async {
  final l10n      = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final base = 'https://www.paypal.com/donate/'
      '?business=ymagnien%40hotmail.com'
      '&currency_code=EUR'
      '&item_name=${Uri.encodeComponent('Rewamp')}';
  final url = amount == null ? base : '$base&amount=$amount';
  var opened = false;
  try {
    opened =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {/* fall through to the clipboard */}
  if (opened) return;
  await Clipboard.setData(ClipboardData(text: url));
  AppSnack.showOn(messenger, l10n.settingsLinkCopied(url),
      duration: const Duration(seconds: 2));
}

/// Opens [url] in the platform browser; falls back to the clipboard when no
/// browser can be launched, so the address is never simply lost.
Future<void> _openUrl(BuildContext context, String url) async {
  final l10n      = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {/* fall through to the clipboard */}
  if (opened) return;
  await Clipboard.setData(ClipboardData(text: url));
  AppSnack.showOn(messenger, l10n.settingsLinkCopied(url),
      duration: const Duration(seconds: 2));
}

// ── Credits & licenses ──
List<Widget> _aboutChildren(BuildContext context) {
  final l10n = context.l10n;
  final tt = Theme.of(context).textTheme;
  final cs = Theme.of(context).colorScheme;
  return [
    _SubHeader(label: l10n.settingsCreditsHeader, cs: cs, textTheme: tt),
    // Rights notice: rewamp plays what online preservation archives host; it
    // hosts and distributes nothing itself, and what the user does with the
    // music is the user's call.
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gavel_outlined, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l10n.settingsRightsNotice,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    ),
    const Divider(height: 1),
    // Formats catalogue → dedicated screen grouped by engine.
    ListTile(
      leading: const Icon(Icons.library_music_outlined),
      title: Text(l10n.settingsFormatsCount(kTotalFormatCount)),
      subtitle: Text(l10n.settingsFormatsEngines(kEngines.length)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const EngineFormatsScreen(),
      )),
    ),
    const Divider(height: 1),
    // Data attribution (not an engine): UADE songlengths/metadata.
    _CreditTile(
      icon: Icons.badge_outlined,
      title: l10n.settingsUadeDataTitle,
      subtitle: l10n.settingsUadeDataSubtitle,
      url: 'https://github.com/mvtiaine/audacious-uade',
    ),
    const Divider(height: 1),
    // Data attribution (not an engine): GameBase64 — C64/SID metadata + artwork.
    _CreditTile(
      icon: Icons.image_outlined,
      title: l10n.settingsGb64Title,
      subtitle: l10n.settingsGb64Subtitle,
      url: 'https://gb64.com',
    ),
    const Divider(height: 1),
    // Asset attribution (not an engine): FastTracker 2 bitmap font from ft2-clone.
    _CreditTile(
      icon: Icons.font_download_outlined,
      title: l10n.settingsFt2FontTitle,
      subtitle: l10n.settingsFt2FontSubtitle,
      url: 'https://16-bits.org/ft2.php',
    ),
    const Divider(height: 1),
    _SubHeader(label: l10n.settingsEnginesHeader, cs: cs, textTheme: tt),
    for (final e in kEngines)
      ListTile(
        dense: true,
        leading: const Icon(Icons.memory_outlined),
        title: Text(e.name),
        // License + role, then the author(s) when known — proper nouns, so
        // the second line is never translated.
        subtitle: Text([
          '${e.license} — ${e.descriptionOf(l10n)}',
          if (e.author != null) e.author!,
        ].join('\n')),
        isThreeLine: true,
        // No link when the project has no stable page we are sure of — better
        // nothing than a guessed URL.
        trailing: e.url == null
            ? null
            : IconButton(
                icon: const Icon(Icons.open_in_new, size: 20),
                tooltip: l10n.settingsOpenLink,
                onPressed: () => _openUrl(context, e.url!),
              ),
        onTap: e.url == null ? null : () => _openUrl(context, e.url!),
      ),
    const Divider(height: 1),
    // Bundled third-party code that decodes nothing (converter, visualizer,
    // GL/codec runtimes) — name + license only, both proper nouns.
    _SubHeader(label: l10n.settingsComponentsHeader, cs: cs, textTheme: tt),
    for (final c in kComponents)
      ListTile(
        dense: true,
        leading: const Icon(Icons.extension_outlined),
        title: Text(c.name),
        subtitle: Text([
          c.license,
          if (c.author != null) c.author!,
        ].join('\n')),
        isThreeLine: c.author != null,
        trailing: c.url == null
            ? null
            : IconButton(
                icon: const Icon(Icons.open_in_new, size: 20),
                tooltip: l10n.settingsOpenLink,
                onPressed: () => _openUrl(context, c.url!),
              ),
        onTap: c.url == null ? null : () => _openUrl(context, c.url!),
      ),
    const SizedBox(height: 8),
  ];
}
