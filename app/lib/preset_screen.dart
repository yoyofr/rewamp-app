import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'app_snack.dart';
import 'l10n.dart';
import 'local_db.dart';
import 'preset_manager.dart';
import 'user_settings.dart';
import 'rewamp_db.dart'
    show
        PresetFolderEntry,
        PresetInfo,
        PresetPack,
        PresetPlaylistInfo,
        RewampDb;

/// Opens the preset screen from the visualizer, which sits inside the player
/// overlay and therefore has no tab navigator of its own. Set once by AppShell
/// so the push lands on the ACTIVE tab navigator: pushed on the ROOT navigator
/// instead, it covered the whole shell, so the mini player and the bottom bar
/// disappeared while managing presets — and playback controls are exactly what
/// you want at hand there. Same contract as [globalOnOpenProduction].
void Function()? globalOnOpenPresets;

/// projectM preset management: server packs, folder browse + search, local
/// preset playlists (incl. imported curated ones), popularity charts, and
/// local imports. Reached from Réglages → Visualisation → projectM and from
/// the visualizer's top-left source button.
class PresetScreen extends StatelessWidget {
  /// Onglet ouvert à l'arrivée. Les réglages pointent directement sur les
  /// presets écartés: y arriver par l'onglet 0 obligerait à les chercher.
  final int initialTab;
  const PresetScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 5,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.pmManagePresets),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l10n.pmTabPacks),
              Tab(text: l10n.pmTabBrowse),
              Tab(text: l10n.pmTabPlaylists),
              Tab(text: l10n.pmTabPopular),
              Tab(text: l10n.pmTabSetAside),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PacksTab(),
            _BrowseTab(),
            _PlaylistsTab(),
            _PopularTab(),
            _SetAsideTab(),
          ],
        ),
      ),
    );
  }
}

String _fmtBytes(int b) {
  if (b >= 1 << 30) return '${(b / (1 << 30)).toStringAsFixed(1)} GB';
  if (b >= 1 << 20) return '${(b / (1 << 20)).toStringAsFixed(1)} MB';
  if (b >= 1 << 10) return '${(b / (1 << 10)).toStringAsFixed(0)} KB';
  return '$b B';
}

/// Name prompt shared with the visualizer's add-to-playlist flow.
Future<String?> promptPmPlaylistName(
    BuildContext context, AppLocalizations l10n,
    {String? initial}) {
  final ctrl = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.pmPlaylistName),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
          child: Text(l10n.commonOk),
        ),
      ],
    ),
  );
}

/// Local-playlist picker (with a create option). Returns the playlist id.
Future<String?> pickPmPlaylist(BuildContext context) async {
  final l10n = context.l10n;
  final playlists = await LocalDb.instance.pmPlaylists();
  if (!context.mounted) return null;
  final picked = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final pl in playlists)
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: Text(pl.name),
              subtitle: Text(l10n.pmPresetCount(pl.itemCount)),
              onTap: () => Navigator.of(sheetCtx).pop(pl.id),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: Text(l10n.pmNewPlaylist),
            onTap: () => Navigator.of(sheetCtx).pop('__new__'),
          ),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return null;
  if (picked != '__new__') return picked;
  final name = await promptPmPlaylistName(context, l10n);
  if (name == null || name.isEmpty) return null;
  return LocalDb.instance.createPmPlaylist(name);
}

/// Ensure [p] is on disk, then add it to a picked playlist.
Future<void> _addPresetToPlaylist(BuildContext context, PresetInfo p) async {
  final l10n = context.l10n;
  final pm = PresetManager.instance;
  String? path;
  try {
    path = await pm.ensurePresetDownloaded(p);
  } catch (e) {
    if (context.mounted) AppSnack.show(context, l10n.pmDownloadFailed);
    return;
  }
  if (path == null || !context.mounted) return;
  final playlistId = await pickPmPlaylist(context);
  if (playlistId == null || !context.mounted) return;
  final added = await LocalDb.instance.addPmPlaylistItem(playlistId,
      path: pm.relOf(path), presetId: p.presetId, name: p.name);
  if (!context.mounted) return;
  AppSnack.show(
      context, added ? l10n.pmAddedToPlaylist : l10n.pmAlreadyInPlaylist);
}

/// Download-if-needed then play this preset NOW. The active source is not
/// persisted-over: the preset joins the current list (prepended when it isn't
/// part of it) so next/prev keep walking that list.
Future<void> _previewPreset(BuildContext context, PresetInfo p) async {
  final l10n = context.l10n;
  final pm = PresetManager.instance;
  try {
    final path = await pm.ensurePresetDownloaded(p);
    if (path == null) {
      if (context.mounted) AppSnack.show(context, l10n.pmDownloadFailed);
      return;
    }
    await pm.previewPreset(path);
    if (context.mounted) AppSnack.show(context, l10n.pmPreviewing(p.name));
  } catch (_) {
    if (context.mounted) AppSnack.show(context, l10n.pmDownloadFailed);
  }
}

/// One preset row, shared by browse / search / popular / playlist items.
class _PresetRow extends StatelessWidget {
  final PresetInfo preset;
  final String? trailingText;
  const _PresetRow(this.preset, {this.trailingText});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pm = PresetManager.instance;
    // Cached lookup, not a stat: this runs for every visible row of a list
    // that scrolls (a pack folder holds up to 200 of them per page).
    final downloaded =
        preset.presetId != null && pm.isSingleDownloaded(pm.singlePathFor(preset));
    return ListTile(
      dense: true,
      leading: Icon(
        downloaded ? Icons.check_circle_outline : Icons.auto_awesome,
        size: 20,
        color: downloaded ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(preset.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: preset.author == null || preset.author!.isEmpty
          ? null
          : Text(preset.author!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(trailingText!,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'play':
                  _previewPreset(context, preset);
                case 'playlist':
                  _addPresetToPlaylist(context, preset);
                case 'download':
                  PresetManager.instance
                      .ensurePresetDownloaded(preset)
                      .then((p) {
                    if (context.mounted) {
                      AppSnack.show(
                          context,
                          p != null
                              ? l10n.pmDownloaded
                              : l10n.pmDownloadFailed);
                    }
                  }).catchError((_) {
                    if (context.mounted) {
                      AppSnack.show(context, l10n.pmDownloadFailed);
                    }
                  });
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'play', child: Text(l10n.pmPlayNow)),
              PopupMenuItem(
                  value: 'playlist', child: Text(l10n.pmAddToPlaylistTooltip)),
              if (!downloaded)
                PopupMenuItem(
                    value: 'download', child: Text(l10n.pmDownloadAction)),
            ],
          ),
        ],
      ),
      onTap: () => _previewPreset(context, preset),
    );
  }
}

// ── Packs ────────────────────────────────────────────────────────────────────

class _PacksTab extends StatefulWidget {
  const _PacksTab();
  @override
  State<_PacksTab> createState() => _PacksTabState();
}

class _PacksTabState extends State<_PacksTab> {
  late Future<List<PresetPack>> _future;

  Future<List<PresetPack>> _fetchPacks() async {
    final packs = await RewampDb.listPresetPacks();
    // Feed the slug→name cache: a single-preset download names the pack it
    // BELONGS to, which may not be installed, so disk cannot answer.
    await PresetManager.instance.rememberPackNames(packs);
    return packs;
  }

  @override
  void initState() {
    super.initState();
    _future = _fetchPacks();
    PresetManager.instance.addListener(_onPm);
  }

  @override
  void dispose() {
    PresetManager.instance.removeListener(_onPm);
    super.dispose();
  }

  String? _shownError;

  void _onPm() {
    if (!mounted) return;
    // DownloadManager swallows job errors by design — the manager parks the
    // message in lastError and this screen is where it becomes visible.
    final err = PresetManager.instance.lastError;
    if (err != null && err != _shownError) {
      _shownError = err;
      AppSnack.show(context, context.l10n.pmInstallFailed);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pm = PresetManager.instance;
    return FutureBuilder<List<PresetPack>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final packs = snap.data;
        if (packs == null || packs.isEmpty) {
          // Offline (or empty catalogue): what is on disk is still actionable.
          final installed = pm.installedPacks();
          return ListView(
            children: [
              if (snap.hasError)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.pmPacksOffline)),
                      TextButton(
                        onPressed: () => setState(() => _future = _fetchPacks()),
                        child: Text(l10n.commonRetry),
                      ),
                    ],
                  ),
                ),
              for (final (slug, name) in installed)
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(name),
                  trailing: TextButton(
                    onPressed: () => pm.applySource('pack:$slug'),
                    child: Text(l10n.pmUse),
                  ),
                ),
            ],
          );
        }
        // Default pack first, then by name.
        final sorted = List<PresetPack>.from(packs)
          ..sort((a, b) {
            if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        return ListView.builder(
          itemCount: sorted.length,
          itemBuilder: (context, i) => _packCard(context, l10n, sorted[i]),
        );
      },
    );
  }

  Widget _packCard(BuildContext context, AppLocalizations l10n,
      PresetPack pack) {
    final pm = PresetManager.instance;
    final installed = pm.isPackInstalled(pack.slug);
    final outdated = pm.packNeedsUpdate(pack);
    final active = pm.activeSource == 'pack:${pack.slug}';
    final cs = Theme.of(context).colorScheme;
    final proposeDefault = pack.isDefault && !installed;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: proposeDefault ? cs.primaryContainer.withValues(alpha: 0.35) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (proposeDefault)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l10n.pmDefaultPackBanner,
                    style: TextStyle(
                        color: cs.primary, fontWeight: FontWeight.w600)),
              ),
            if (outdated)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.system_update_alt,
                        size: 15, color: cs.tertiary),
                    const SizedBox(width: 4),
                    Text(l10n.pmUpdateAvailable,
                        style: TextStyle(
                            color: cs.tertiary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(pack.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (active) Icon(Icons.check, color: cs.primary),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${l10n.pmPresetCount(pack.presetCount)} · ${_fmtBytes(pack.totalBytes)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            // Textures are a separate download and can dwarf the presets
            // (deepfield: 1176 images, 70 MB). The line used to disappear once
            // the bundle was on disk — it read as a pre-tap price tag only. It
            // stays: what a pack brings is worth knowing after the install too,
            // and the figure is the first thing to compare against when the
            // images look wrong. The leading "+" is what still marks a download
            // to come, so the two states remain distinguishable at a glance.
            //
            // These are the CATALOGUE's figures, not a count of what landed on
            // disk: counting the files would mean walking every bundle on every
            // rebuild. A mismatch between this line and reality is exactly the
            // kind of thing worth seeing.
            if (pack.texturesBytes > 0)
              Text(
                '${pm.texturesNeedFetch(pack) ? '+ ' : ''}'
                '${l10n.pmTexturesCount(pack.texturesCount)} · '
                '${_fmtBytes(pack.texturesBytes)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (pack.license != null && pack.license!.isNotEmpty)
              // Community packs come under heterogeneous licences — the card
              // is where the licence must be visible (server contract).
              Text(l10n.pmLicense(pack.license!),
                  style: Theme.of(context).textTheme.bodySmall),
            if (pack.description != null && pack.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(pack.description!,
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(height: 8),
            ValueListenableBuilder<Map<String, double>>(
              valueListenable: pm.progress,
              builder: (context, prog, _) {
                final p = prog['pack:${pack.slug}'];
                if (p != null) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: LinearProgressIndicator(value: p > 0 ? p : null),
                  );
                }
                return Row(
                  children: [
                    if (!installed)
                      FilledButton.tonal(
                        onPressed: () {
                          pm.enqueueInstall(pack);
                          AppSnack.show(context, l10n.pmInstallQueued);
                        },
                        child: Text(l10n.pmInstall),
                      ),
                    if (installed) ...[
                      if (outdated) ...[
                        // Re-install in place: same paths, so preset playlists
                        // built on this pack survive the update.
                        FilledButton(
                          onPressed: () {
                            pm.enqueueInstall(pack);
                            AppSnack.show(context, l10n.pmInstallQueued);
                          },
                          child: Text(l10n.pmUpdate),
                        ),
                        const SizedBox(width: 8),
                      ],
                      FilledButton.tonal(
                        onPressed: active
                            ? null
                            : () => pm.applySource('pack:${pack.slug}'),
                        child: Text(l10n.pmUse),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          await pm.uninstallPack(pack);
                          if (context.mounted) {
                            AppSnack.show(context, l10n.pmUninstalled);
                          }
                        },
                        child: Text(l10n.pmUninstall),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Browse ───────────────────────────────────────────────────────────────────

class _BrowseTab extends StatefulWidget {
  const _BrowseTab();
  @override
  State<_BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<_BrowseTab> {
  static const _kPageSize = 200;   // server caps lim at 1000

  List<PresetPack> _packs = const [];
  String? _pack;
  String _folder = '';
  String _query = '';
  Timer? _debounce;

  // Accumulated rows across pages. A folder like Cream of the Crop's
  // "Drawing/Explosions" holds 304 presets: a single request would silently
  // stop at the server's 200-row page and the rest would be unreachable.
  final List<PresetFolderEntry> _dirs = [];
  final List<PresetInfo> _presets = [];
  int _total = 0;          // dirs+presets for the whole level (1st page only)
  bool _loading = false;
  bool _failed = false;
  int _epoch = 0;          // invalidates in-flight pages after a navigation

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final packs = await RewampDb.listPresetPacks();
      await PresetManager.instance.rememberPackNames(packs);
      if (!mounted) return;
      setState(() {
        _packs = packs;
        _pack = packs.isEmpty ? null : packs.first.slug;
      });
      _reload();
    } catch (_) {/* offline: the tab shows its empty state */}
  }

  bool get _hasMore =>
      _total > 0 && _dirs.length + _presets.length < _total;

  void _reload() {
    _epoch++;
    _dirs.clear();
    _presets.clear();
    _total = 0;
    _failed = false;
    setState(() {});
    _loadMore();
  }

  Future<void> _loadMore() async {
    final pack = _pack;
    if (pack == null || _loading) return;
    final epoch = _epoch;
    setState(() => _loading = true);
    try {
      final page = await RewampDb.browsePresets(
        pack: pack,
        folder: _folder,
        q: _query.isEmpty ? null : _query,
        limit: _kPageSize,
        offset: _dirs.length + _presets.length,
      );
      if (!mounted || epoch != _epoch) return;   // navigated away meanwhile
      setState(() {
        _dirs.addAll(page.dirs);
        _presets.addAll(page.presets);
        // total_count is -1 from the 2nd page on: keep the first page's value.
        if (page.totalCount > 0) _total = page.totalCount;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _loading = false;
        _failed = _dirs.isEmpty && _presets.isEmpty;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Widget _list(AppLocalizations l10n) {
    if (_failed) return Center(child: Text(l10n.pmPacksOffline));
    final rows = _dirs.length + _presets.length;
    if (rows == 0) {
      return Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Text(l10n.searchNoResults),
      );
    }
    // One list, dirs then presets, with a trailing spinner that FETCHES the
    // next page when it scrolls into view (the server pages at 200).
    return ListView.builder(
      itemCount: rows + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= rows) {
          if (!_loading) WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (i < _dirs.length) {
          final d = _dirs[i];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.folder_outlined, size: 20),
            title: Text(d.name),
            subtitle: Text(l10n.pmPresetCount(d.presetCount)),
            onTap: () {
              _folder = d.dirPath;
              _reload();
            },
          );
        }
        return _PresetRow(_presets[i - _dirs.length]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_pack == null) {
      return Center(child: Text(l10n.pmPacksOffline));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          // Side by side only when there is room: a pack name eats most of a
          // phone's width, leaving the search field a sliver with just its
          // magnifier showing. Below the picker it gets the full width.
          child: LayoutBuilder(
            builder: (context, c) {
              final picker = DropdownButton<String>(
                value: _pack,
                isExpanded: true,
                items: [
                  for (final p in _packs)
                    DropdownMenuItem(
                      value: p.slug,
                      child: Text(p.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  _pack = v;
                  _folder = '';
                  _reload();
                },
              );
              final search = TextField(
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: l10n.pmSearchPresets,
                ),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () {
                    _query = v.trim();
                    _reload();
                  });
                },
              );
              if (c.maxWidth < 520) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [picker, const SizedBox(height: 4), search],
                );
              }
              return Row(
                children: [
                  SizedBox(width: 220, child: picker),
                  const SizedBox(width: 12),
                  Expanded(child: search),
                ],
              );
            },
          ),
        ),
        if (_folder.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_upward, size: 16),
              label: Text(_folder, maxLines: 1, overflow: TextOverflow.ellipsis),
              onPressed: () {
                final cut = _folder.lastIndexOf('/');
                _folder = cut < 0 ? '' : _folder.substring(0, cut);
                _reload();
              },
            ),
          ),
        Expanded(child: _list(l10n)),
      ],
    );
  }
}

// ── Playlists ────────────────────────────────────────────────────────────────

class _PlaylistsTab extends StatefulWidget {
  const _PlaylistsTab();
  @override
  State<_PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<_PlaylistsTab> {
  late Future<List<PresetPlaylistInfo>> _curated;

  @override
  void initState() {
    super.initState();
    _curated = RewampDb.listPresetPlaylists();
    LocalDb.instance.addListener(_onDb);
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_onDb);
    super.dispose();
  }

  void _onDb() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pm = PresetManager.instance;
    return FutureBuilder<List<PmPlaylist>>(
      future: LocalDb.instance.pmPlaylists(),
      builder: (context, localSnap) {
        final locals = localSnap.data ?? const <PmPlaylist>[];
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l10n.pmLocalSection,
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.pmNewPlaylist),
                    onPressed: () async {
                      final name = await promptPmPlaylistName(context, l10n);
                      if (name == null || name.isEmpty) return;
                      await LocalDb.instance.createPmPlaylist(name);
                    },
                  ),
                  // Local .milk / preset-archive import lives here too — the
                  // same flow drag'n'drop takes, for people who pick files.
                  IconButton(
                    tooltip: l10n.pmImportFiles,
                    icon: const Icon(Icons.file_open_outlined, size: 20),
                    onPressed: () => _importFromPicker(context, l10n),
                  ),
                ],
              ),
            ),
            // Imports live here too: the flow that fills user/ (picker above,
            // drag'n'drop) needs a place to DELETE from it.
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(l10n.pmSourceImports),
              subtitle: Text(
                  l10n.pmPresetCount(PresetManager.instance.userPresets().length)),
              trailing: pm.activeSource == 'user'
                  ? Icon(Icons.check,
                      color: Theme.of(context).colorScheme.primary)
                  : const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UserImportsScreen())),
            ),
            // Presets tried one by one from Popular/Browse pile up here. Those
            // a playlist points at are NOT offered for deletion.
            FutureBuilder<List<(String, int)>>(
              future: pm.orphanSingles(),
              builder: (context, snap) {
                final list = snap.data ?? const <(String, int)>[];
                if (list.isEmpty) return const SizedBox.shrink();
                final bytes = list.fold<int>(0, (a, e) => a + e.$2);
                return ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: Text(l10n.pmSingleDownloads),
                  subtitle: Text(
                      '${l10n.pmPresetCount(list.length)} · ${_fmtBytes(bytes)}'),
                  trailing: TextButton(
                    child: Text(l10n.pmCleanUp),
                    onPressed: () async {
                      final n = await pm.purgeOrphanSingles();
                      if (context.mounted) {
                        AppSnack.show(context, l10n.pmCleanedUp(n));
                      }
                    },
                  ),
                );
              },
            ),
            // Texture bundles no pack claims any more. Explicit, never
            // automatic: bundles installed before the reference counting cannot
            // be attributed, and a single rescued from a since-uninstalled pack
            // may still need one — so the user decides, warned.
            Builder(
              builder: (context) {
                final orphans = pm.orphanTextureBundles();
                if (orphans.isEmpty) return const SizedBox.shrink();
                final bytes = orphans.fold<int>(0, (a, e) => a + e.$2);
                return ListTile(
                  leading: const Icon(Icons.image_not_supported_outlined),
                  title: Text(l10n.pmUnusedTextures),
                  subtitle: Text(_fmtBytes(bytes)),
                  trailing: TextButton(
                    child: Text(l10n.pmCleanUp),
                    onPressed: () async {
                      final freed = await pm.purgeOrphanTextures();
                      if (context.mounted) {
                        AppSnack.show(
                            context, l10n.pmTexturesFreed(_fmtBytes(freed)));
                      }
                    },
                  ),
                );
              },
            ),
            if (locals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.pmNoPlaylists,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            for (final pl in locals)
              ListTile(
                leading: Icon(pl.serverId == null
                    ? Icons.queue_music
                    : Icons.cloud_done_outlined),
                title: Text(pl.name),
                subtitle: Text(l10n.pmPresetCount(pl.itemCount)),
                trailing: pm.activeSource == 'plist:${pl.id}'
                    ? Icon(Icons.check,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PmPlaylistDetailScreen(playlistId: pl.id))),
              ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(l10n.pmCuratedSection,
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            FutureBuilder<List<PresetPlaylistInfo>>(
              future: _curated,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final list = snap.data;
                if (list == null || list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                        snap.hasError ? l10n.pmPacksOffline : l10n.searchNoResults,
                        style: Theme.of(context).textTheme.bodySmall),
                  );
                }
                return Column(
                  children: [
                    for (final pl in list) _curatedRow(context, l10n, pl),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _curatedRow(BuildContext context, AppLocalizations l10n,
      PresetPlaylistInfo pl) {
    final pm = PresetManager.instance;
    return ValueListenableBuilder<Map<String, double>>(
      valueListenable: pm.progress,
      builder: (context, prog, _) {
        final p = prog['srvlist:${pl.id}'];
        return ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: Text(pl.name),
          subtitle: p != null
              ? LinearProgressIndicator(value: p > 0 ? p : null)
              : Text(l10n.pmPresetCount(pl.itemCount)),
          trailing: p != null
              ? null
              : TextButton(
                  child: Text(l10n.pmImportPlaylist),
                  onPressed: () async {
                    try {
                      final localId = await pm.importServerPlaylist(pl);
                      await pm.applySource('plist:$localId');
                      if (context.mounted) {
                        AppSnack.show(context, l10n.pmPlaylistImported);
                      }
                    } catch (_) {
                      if (context.mounted) {
                        AppSnack.show(context, l10n.pmDownloadFailed);
                      }
                    }
                  },
                ),
        );
      },
    );
  }

  Future<void> _importFromPicker(
      BuildContext context, AppLocalizations l10n) async {
    List<String> paths;
    if (Platform.isAndroid) {
      // NOT file_selector here: its Android implementation renames the cached
      // copy after the resolved MIME type, and a `.milk` resolves to
      // octet-stream — the file would arrive as "preset.bin" and be dropped by
      // the extension check. file_picker keeps the real display name. Same
      // reason the home screen's picker branches (see its comment); an
      // extension filter is useless there anyway, Android filters on MIME.
      final res = await fp.FilePicker.platform
          .pickFiles(type: fp.FileType.any, allowMultiple: true);
      paths = [
        for (final f in res?.files ?? const <fp.PlatformFile>[])
          if (f.path != null) f.path!,
      ];
    } else {
      const group = XTypeGroup(label: 'Milkdrop', extensions: ['milk']);
      final files = await openFiles(acceptedTypeGroups: const [group]);
      paths = [for (final f in files) f.path];
    }
    if (paths.isEmpty) return;
    final n = await PresetManager.instance.importMilkFiles(paths);
    if (context.mounted) AppSnack.show(context, l10n.pmImported(n));
  }
}

/// One local preset playlist: reorderable items, rename/delete, use-as-source.
class PmPlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  const PmPlaylistDetailScreen({super.key, required this.playlistId});

  @override
  State<PmPlaylistDetailScreen> createState() => _PmPlaylistDetailState();
}

class _PmPlaylistDetailState extends State<PmPlaylistDetailScreen> {
  PmPlaylist? _pl;
  List<PmPlaylistItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
    LocalDb.instance.addListener(_load);
  }

  @override
  void dispose() {
    LocalDb.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final pls = await LocalDb.instance.pmPlaylists();
    final items = await LocalDb.instance.pmPlaylistItems(widget.playlistId);
    if (!mounted) return;
    setState(() {
      _pl = pls.where((p) => p.id == widget.playlistId).firstOrNull;
      _items = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pm = PresetManager.instance;
    final pl = _pl;
    return Scaffold(
      appBar: AppBar(
        title: Text(pl?.name ?? ''),
        actions: [
          IconButton(
            tooltip: l10n.pmUse,
            icon: const Icon(Icons.play_arrow),
            onPressed: () async {
              await pm.applySource('plist:${widget.playlistId}');
              if (context.mounted) {
                AppSnack.show(context, l10n.pmSourceApplied);
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'rename':
                  final name = await promptPmPlaylistName(context, l10n,
                      initial: pl?.name);
                  if (name != null && name.isNotEmpty) {
                    await LocalDb.instance
                        .renamePmPlaylist(widget.playlistId, name);
                  }
                case 'delete':
                  await LocalDb.instance.deletePmPlaylist(widget.playlistId);
                  if (context.mounted) Navigator.of(context).pop();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'rename', child: Text(l10n.playlistRenameTitle)),
              PopupMenuItem(value: 'delete', child: Text(l10n.playerDelete)),
            ],
          ),
        ],
      ),
      body: _items.isEmpty
          ? Center(child: Text(l10n.pmPlaylistEmpty))
          : ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: _items.length,
              onReorderItem: (oldIndex, newIndex) => LocalDb.instance
                  .reorderPmPlaylistItem(widget.playlistId, oldIndex, newIndex),
              itemBuilder: (context, i) {
                final it = _items[i];
                return ListTile(
                  key: ValueKey(it.id),
                  dense: true,
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_handle, size: 20),
                  ),
                  title: Text(it.name ?? it.path.split('/').last,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => LocalDb.instance
                        .removePmPlaylistItem(widget.playlistId, it.id),
                  ),
                  onTap: () {
                    final abs = PresetManager.instance.absOf(it.path);
                    unawaited(PresetManager.instance.previewPreset(abs));
                  },
                );
              },
            ),
    );
  }
}

/// Imported presets (`<datadir>/projectm/user/`): preview, add to playlist,
/// DELETE — drag'n'drop copies files in, this is the way back out.
class UserImportsScreen extends StatefulWidget {
  const UserImportsScreen({super.key});

  @override
  State<UserImportsScreen> createState() => _UserImportsScreenState();
}

class _UserImportsScreenState extends State<UserImportsScreen> {
  late List<String> _paths;

  /// Selection mode, and what is selected — BY PATH, never by index. The list
  /// shrinks as soon as a delete lands, so index-keyed selections point at the
  /// wrong rows the moment anything goes (the trap the queue panel documents).
  bool _editing = false;
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _paths = PresetManager.instance.userPresets();
  }

  void _reload() => setState(() {
        _paths = PresetManager.instance.userPresets();
        // Drop what no longer exists rather than keep stale paths around.
        _selected.removeWhere((p) => !_paths.contains(p));
      });

  void _exitEditing() => setState(() {
        _editing = false;
        _selected.clear();
      });

  Future<void> _deleteSelected(AppLocalizations l10n) async {
    if (_selected.isEmpty) return;
    final victims = _selected.toList(growable: false);
    final n = await PresetManager.instance.deleteUserPresets(victims);
    if (!mounted) return;
    _exitEditing();
    _reload();
    AppSnack.show(context, l10n.pmCleanedUp(n));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pm = PresetManager.instance;
    final allSelected = _paths.isNotEmpty && _selected.length == _paths.length;
    return Scaffold(
      appBar: AppBar(
        leading: _editing
            ? IconButton(
                tooltip: l10n.queueEditDone,
                icon: const Icon(Icons.close),
                onPressed: _exitEditing,
              )
            : null,
        title: Text(_editing
            ? l10n.pmSelectedCount(_selected.length)
            : l10n.pmSourceImports),
        actions: _editing
            ? [
                IconButton(
                  tooltip: allSelected ? l10n.pmSelectNone : l10n.pmSelectAll,
                  icon: Icon(allSelected
                      ? Icons.deselect
                      : Icons.select_all),
                  onPressed: () => setState(() {
                    if (allSelected) {
                      _selected.clear();
                    } else {
                      _selected
                        ..clear()
                        ..addAll(_paths);
                    }
                  }),
                ),
                IconButton(
                  tooltip: l10n.playerDelete,
                  icon: const Icon(Icons.delete_outline),
                  // Disabled rather than hidden: a button that appears and
                  // disappears under the thumb is worse than a greyed one.
                  onPressed:
                      _selected.isEmpty ? null : () => _deleteSelected(l10n),
                ),
              ]
            : [
                if (_paths.isNotEmpty)
                  IconButton(
                    tooltip: l10n.queueEdit,
                    icon: const Icon(Icons.checklist),
                    onPressed: () => setState(() => _editing = true),
                  ),
                IconButton(
                  tooltip: l10n.pmUse,
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () async {
                    await pm.applySource('user');
                    if (context.mounted) {
                      AppSnack.show(context, l10n.pmSourceApplied);
                    }
                  },
                ),
              ],
      ),
      body: _paths.isEmpty
          ? Center(child: Text(l10n.searchNoResults))
          : ListView.builder(
              itemCount: _paths.length,
              itemBuilder: (context, i) {
                final abs = _paths[i];
                final base = abs.split('/').last;
                final display = base.toLowerCase().endsWith('.milk')
                    ? base.substring(0, base.length - 5)
                    : base;
                final selected = _selected.contains(abs);
                return ListTile(
                  dense: true,
                  leading: _editing
                      ? Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        )
                      : const Icon(Icons.auto_awesome, size: 20),
                  selected: _editing && selected,
                  title: Text(display,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  // A long press enters selection mode on the row pressed, which
                  // is what every list in the app already does for a bulk
                  // gesture — the toolbar button is for finding it the first
                  // time.
                  onLongPress: _editing
                      ? null
                      : () => setState(() {
                            _editing = true;
                            _selected.add(abs);
                          }),
                  onTap: _editing
                      ? () => setState(() =>
                          selected ? _selected.remove(abs) : _selected.add(abs))
                      : () => unawaited(pm.previewPreset(abs)),
                  trailing: _editing
                      ? null
                      : PopupMenuButton<String>(
                    onSelected: (v) async {
                      switch (v) {
                        case 'playlist':
                          final playlistId = await pickPmPlaylist(context);
                          if (playlistId == null || !context.mounted) return;
                          final added = await LocalDb.instance
                              .addPmPlaylistItem(playlistId,
                                  path: pm.relOf(abs), name: display);
                          if (context.mounted) {
                            AppSnack.show(
                                context,
                                added
                                    ? l10n.pmAddedToPlaylist
                                    : l10n.pmAlreadyInPlaylist);
                          }
                        case 'delete':
                          await pm.deleteUserPreset(abs);
                          _reload();
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'playlist',
                          child: Text(l10n.pmAddToPlaylistTooltip)),
                      PopupMenuItem(
                          value: 'delete', child: Text(l10n.playerDelete)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ── Popular ──────────────────────────────────────────────────────────────────

class _PopularTab extends StatefulWidget {
  const _PopularTab();
  @override
  State<_PopularTab> createState() => _PopularTabState();
}

class _PopularTabState extends State<_PopularTab> {
  int _days = 30;
  late Future<List<PresetInfo>> _future;

  @override
  void initState() {
    super.initState();
    _future = RewampDb.mostPopularPresets(days: _days);
  }

  void _setDays(int d) {
    setState(() {
      _days = d;
      _future = RewampDb.mostPopularPresets(days: d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 7, label: Text(l10n.pmDays7)),
                ButtonSegment(value: 30, label: Text(l10n.pmDays30)),
                ButtonSegment(value: 365, label: Text(l10n.pmDays365)),
              ],
              selected: {_days},
              onSelectionChanged: (s) => _setDays(s.first),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<PresetInfo>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data;
              if (list == null || list.isEmpty) {
                return Center(
                    child: Text(snap.hasError
                        ? l10n.pmPacksOffline
                        : l10n.searchNoResults));
              }
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) => _PresetRow(
                  list[i],
                  trailingText: list[i].totalUses == null
                      ? null
                      : l10n.pmUsesCount(list[i].totalUses!),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Presets écartés ─────────────────────────────────────────────────────────
//
// Le garde-fou de cadence (voir `rewamp_projectm_take_slow_verdict`) retire de
// la rotation les presets qui font tomber l'appareil sous 6 images/s. Sans
// cette liste ils disparaissent en silence: un mécanisme de protection qui
// n'est pas INSPECTABLE se lit comme un preset perdu.
//
// L'appartenance est affichée par la MÊME fonction que la bannière du
// visualiseur (`sourceOfPath`), donc un preset se nomme ici exactement comme
// il se nommait à l'écran quand il a été écarté — pack et sous-dossier
// compris, ce qui est la seule façon de le retrouver dans un arbre de 10 000
// fichiers.
class _SetAsideTab extends StatefulWidget {
  const _SetAsideTab();
  @override
  State<_SetAsideTab> createState() => _SetAsideTabState();
}

class _SetAsideTabState extends State<_SetAsideTab> {
  @override
  void initState() {
    super.initState();
    UserSettings.instance.addListener(_onSettings);
  }

  @override
  void dispose() {
    UserSettings.instance.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  String _subtitle(AppLocalizations l10n, String rel) {
    final pm = PresetManager.instance;
    final (kind, packName, subDir) = pm.sourceOfPath(pm.absOf(rel));
    final where = switch (kind) {
      'pack'    => packName,
      'bundled' => l10n.pmSourceBundled,
      'user'    => l10n.pmSourceImports,
      'single'  => packName != null
          ? l10n.pmAvailableIn(packName)
          : l10n.pmSingleDownloads,
      _         => null,
    };
    if (where == null) return rel;
    return subDir == null ? where : '$where · $subDir';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final list = UserSettings.instance.pmSlowPresets;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(l10n.pmSetAsideEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(l10n.settingsPmSlowPresetsSubtitle,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              TextButton(
                onPressed: () async {
                  UserSettings.instance.clearPmSlowPresets();
                  await PresetManager.instance.applySource(
                      UserSettings.instance.pmSource,
                      persist: false);
                },
                child: Text(l10n.pmSetAsideRestoreAll),
              ),
            ],
          ),
        ),
        for (final rel in list)
          ListTile(
            leading: const Icon(Icons.speed_outlined),
            // Le nom du FICHIER sans son extension, comme partout ailleurs:
            // c'est ce que le moteur affiche et ce que l'utilisateur a vu.
            title: Text(
              p.basenameWithoutExtension(rel),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(_subtitle(l10n, rel),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: TextButton(
              onPressed: () =>
                  PresetManager.instance.unblockSlowPreset(rel),
              child: Text(l10n.settingsPmSlowPresetsRestore),
            ),
          ),
      ],
    );
  }
}
