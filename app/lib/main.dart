import 'dart:async' show unawaited;
import 'dart:io' show File, Directory, Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rewamp_audio/rewamp_audio.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'data_reset.dart';
import 'keyboard_dismiss.dart';
import 'l10n.dart';
import 'rewamp_db.dart' show RewampDb;
import 'local_db.dart';
import 'locale_resolution.dart';
import 'queue_persistence.dart';
import 'release_notes.dart';
import 'preset_manager.dart';
import 'soundfont_manager.dart';
import 'mt32_rom_manager.dart';
import 'mini_window.dart';
import 'user_settings.dart';
import 'app_shell.dart';
import 'app_snack.dart';
import 'orientation_lock.dart';
import 'system_ui.dart';
import 'splash_intro.dart';
import 'artwork_image.dart';
import 'library_identity.dart';
import 'local_open.dart';
import 'opened_files.dart';
import 'storage_roots.dart';
import 'app_theme.dart';

// Bundled library assets copied to the writable data dir at startup, then
// loaded natively (e.g. libsidplayfp C64 ROMs). Add entries here as new
// playback libraries need auxiliary files.
const _bundledAssets = <String>[
  'assets/c64/kernal.c64',
  'assets/c64/basic.c64',
  'assets/c64/chargen.c64',
  // AdPlug module-info DB (title/length + per-file playback hints some players
  // need). Loaded natively from <datadir>/adplug/adplug.db by rewamp_plugin_adplug.
  'assets/adplug/adplug.db',
  // OPL4/YMF278B wavetable ROM, requested on demand by libvgm's
  // PlayerA::SetFileReqCallback (rewamp_plugin_vgm.cpp) for VGM files that
  // use that chip's PCM/wavetable channels.
  'assets/vgm/yrw801.rom',
  // YM2608 (OPNA) ADPCM rhythm ROM — the PC-98 rhythm section's samples, wanted
  // by BOTH PC-98 engines (libpmdmini's OPNA::Init and libfmpmini's drum ROM
  // loader) from <datadir>/opna/, via the shared `bundlePath` global. Without
  // it a tune plays but its rhythm parts are silent.
  'assets/opna/ym2608_adpcm_rom.bin',
];

/// Asset directory prefixes whose entire contents are copied to the data dir
/// (enumerated at runtime via AssetManifest — too many files to list). UADE
/// needs its ~190 eagleplayers + score + confs under uade/ (UC_BASE_DIR).
const _bundledAssetDirs = <String>[
  'assets/uade/',
  // sc68 loose 68k replays (44 of the 99 are not gzip-embedded in the lib).
  'assets/sc68/',
  // projectM visualizer: Milkdrop presets (.milk) + textures, loaded natively
  // from <datadir>/projectm/{presets,textures}.
  'assets/projectm/',
];

/// Bump when any bundled asset CONTENT changes (new/updated uade score,
/// players, eagleplayer.conf, sc68 replays, presets…). The copy below skips
/// files that already exist on disk — without this stamp, an updated bundle
/// never reaches the data dir and the engines keep running on stale data
/// (bitten for real: the webUADE+ score/conf/players update was invisible to
/// an installed app, so "han." files kept failing with backend="").
// 4: +7 martin milkdrop presets; 5: preset culling + stale-file sync on bump;
// 7: test.milk retiré (le bump seul le purge des installations existantes)
const _kBundledAssetsVersion = 8;

/// Copy bundled assets into `{appSupport}/rewamp_data/` (preserving their
/// sub-path under assets/) and return that root so native code can load them.
Future<String> _prepareDataDir() async {
  final support = await getApplicationSupportDirectory();
  final root = Directory('${support.path}/rewamp_data');

  // Version stamp: on mismatch, overwrite everything once, then restamp.
  final stamp = File('${root.path}/.assets_version');
  final fresh =
      !await stamp.exists() || await stamp.readAsString() != '$_kBundledAssetsVersion';

  Future<void> copy(String key) async {
    // Strip the leading "assets/" so on-disk layout is e.g. c64/kernal.c64.
    final rel = key.startsWith('assets/') ? key.substring(7) : key;
    final out = File('${root.path}/$rel');
    if (!fresh && await out.exists()) return; // already copied, same version
    await out.parent.create(recursive: true);
    final data = await rootBundle.load(key);
    await out.writeAsBytes(data.buffer.asUint8List(), flush: true);
  }

  for (final key in _bundledAssets) {
    await copy(key);
  }

  // Copy whole asset directories enumerated from the manifest.
  if (_bundledAssetDirs.isNotEmpty) {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final bundled = <String>[];
    for (final key in manifest.listAssets()) {
      // Finder droppings (.DS_Store) get LISTED in the manifest when they sit
      // in a declared asset dir, but the bundler ships them with empty data —
      // rootBundle.load then throws and kills the whole startup copy.
      final base = key.split('/').last;
      if (base.startsWith('.')) continue;
      if (_bundledAssetDirs.any(key.startsWith)) {
        bundled.add(key);
        await copy(key);
      }
    }

    // On a version bump, also DELETE what the bundle no longer ships: the
    // copy above only adds/overwrites, so an asset removed from the repo
    // (a culled projectM preset) lived on installed devices forever. Owned
    // at the DIRECTORY level: only directories the bundle ships files into
    // are synced (projectm/presets yes; projectm/user, packs/, soundfonts/
    // have no bundled files and are never touched). Dotfiles (.installed,
    // stamps) are spared.
    if (fresh) {
      final rels = {
        for (final k in bundled) k.startsWith('assets/') ? k.substring(7) : k,
      };
      final owned = {
        for (final r in rels)
          if (r.contains('/')) r.substring(0, r.lastIndexOf('/')),
      };
      for (final d in owned) {
        final dir = Directory('${root.path}/$d');
        if (!await dir.exists()) continue;
        await for (final e in dir.list()) {
          if (e is! File) continue;
          final rel = e.path.substring(root.path.length + 1);
          if (rel.split('/').last.startsWith('.')) continue;
          if (!rels.contains(rel)) {
            try { await e.delete(); } catch (_) {}
          }
        }
      }
    }
  }

  if (fresh) {
    await stamp.parent.create(recursive: true);
    await stamp.writeAsString('$_kBundledAssetsVersion', flush: true);
  }

  return root.path;
}

/// [args] = la ligne de commande. C'est ainsi que Linux et Windows livrent un
/// fichier à ouvrir (Apple passe par `application(_:open:)`), et le runner GTK
/// les transmet déjà — il ne manquait qu'un `main` qui les lise.
void main([List<String> args = const []]) async {
  if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  WidgetsFlutterBinding.ensureInitialized();

  // Un fichier passé en argument attend dans la même file que ceux d'un
  // démarrage à froid sur Apple: le shell les ramassera quand il existera.
  // Semé ICI et non dans le shell — les arguments ne parviennent qu'à `main`.
  seedOpenedPathsFromArgs(args);

  // Doigt maintenu au démarrage = effet d'intro forcé (grille 3x5). Doit être
  // posé ICI: tout ce qui suit dans main() est asynchrone et dure — un appui y
  // tomberait dans le vide, et comme le doigt reste posé aucun nouveau `down`
  // n'arriverait ensuite. Voir installLaunchTouchProbe.
  installLaunchTouchProbe();

  // Phones are portrait-only (tablets/desktop rotate freely); the fullscreen
  // visualizer/video temporarily unlocks this — see PlayerScreen.
  OrientationLock.lock();

  // Android tablets pin a navigation/dock strip at the bottom; hide it the way
  // other full-screen apps do (the status bar stays). See system_ui.dart.
  SystemUi.hideNavigationBar();

  // Set sandbox root before DB opens so path normalisation works on first write.
  // On iOS the container UUID changes every launch; we strip it and restore it
  // at load time. No-op on platforms with stable paths.
  if (!kIsWeb && Platform.isIOS) {
    final docs = await getApplicationDocumentsDirectory();
    LocalDb.setSandboxRoot(docs.parent.path);
  }

  // Remise à zéro pilotée par la version (beta): efface base, téléchargements
  // et réglages UNE fois quand `kDataResetVersion` a changé, en gardant le
  // compte. Doit passer avant l'ouverture de la base et avant la lecture des
  // préférences — voir data_reset.dart.
  await maybeResetLocalData();

  await LocalDb.initialize();
  // Linux/Windows: déplacer `~/Documents/online` et le `local/` du dossier de
  // support sous `Documents/Rewamp/`. ⚠️ APRÈS la base (elle réécrit les
  // chemins stockés) et AVANT initLibraryRoots (qui fige les racines). Voir
  // storage_roots.dart.
  await migrateStorageRoots();
  // Racines des chemins (imports pérennes, téléchargements, caches): la garde
  // d'identité de bibliothèque les compare en PRÉFIXE plutôt qu'en
  // sous-chaîne — un dossier `local/` de l'utilisateur n'est pas le nôtre.
  await initLibraryRoots();
  // Tampon d'archives d'album (partagé entre les chemins de téléchargement le
  // temps d'un geste): un kill pendant une extraction y laisse des centaines
  // de mégaoctets. Rien n'en dépend au lancement — on n'attend pas.
  unawaited(RewampDb.purgeArchiveCache());
  // Filet du dossier `opened/` (fichiers entrés par « Ouvrir avec » et le
  // sélecteur mobile): efface le vieux NON référencé — jamais ce qu'une
  // playlist, la bibliothèque ou un favori tient encore. La vraie gestion est
  // dans Réglages → Stockage.
  unawaited(OpenedFiles.prune());
  // Une fois: rattraper les pochettes écrites sous l'ancien nom. Estampillée
  // par un FICHIER et non une préférence — une remise à zéro des données efface
  // les préférences, et on relancerait alors une migration sur un disque déjà
  // à jour (inoffensive, mais c'est un balayage récursif pour rien).
  unawaited(() async {
    try {
      final support = await getApplicationSupportDirectory();
      // v2: le balayage v1 a bien tourné, mais un build ANTÉRIEUR au nom
      // complet a pu réécrire l'ancien nom APRÈS lui — les builds de beta et
      // de développement partagent le conteneur. Mesuré sur un vrai profil:
      // migration à 14:48, `mdat.jpg` réapparu à 19:50 le même jour.
      final stamp = File(p.join(support.path, '.artwork_names_v2'));
      if (await stamp.exists()) return;
      await migrateArtworkSidecarNames(
          Directory(p.join((await RewampDb.downloadsBaseDir()).path, 'online')));
      await stamp.writeAsString('1', flush: true);
    } catch (_) {/* une migration ratée ne doit pas casser un démarrage */}
  }());
  await UserSettings.init();
  // Bureau: plancher de taille de la fenêtre + « toujours au premier plan ».
  await MiniWindow.instance.init();
  // Nettoyage AUTOMATIQUE au premier lancement d'une build (kAutoCleanupVersion):
  // le geste « Nettoyer la base locale et le cache » de Réglages → Données,
  // joué une fois tout seul. En ARRIÈRE-PLAN — sa purge d'entrées mortes peut
  // demander une passe de synchro bornée à 45 s, et rien de tout cela ne
  // conditionne le démarrage. Le ticket est pris (et l'estampille posée) ici:
  // un échec ne doit pas rejouer la passe à chaque lancement.
  unawaited(() async {
    try {
      if (!await takeAutoCleanupTicket()) return;
      final res = await runLocalCleanup();
      debugPrint('[auto-cleanup] terminé — ${res.orphans} ligne(s) orpheline(s), '
          '${res.missing} entrée(s) injouable(s), ${res.artwork} pochette(s) '
          'en cache');
    } catch (e) {
      debugPrint('[auto-cleanup] échec (sans conséquence): $e');
    }
  }());
  // Queue persistence / crash guard: must resolve its dir + consume the
  // "loading" flag BEFORE any track can be loaded.
  await QueuePersistence.init();

  // Stage native library assets and register the data dir before playback.
  final dataDir = await _prepareDataDir();
  final audio = RewampAudio();
  audio.init();
  // iOS: **une app dont l'unité audio TOURNE est « en lecture » pour le
  // système**, quoi qu'annonce la session média — c'est la leçon déjà payée
  // sur la PAUSE (voir rewamp_device_suspend et PlayerController.togglePlay),
  // et le lancement tombait dans le même trou: `rewamp_init` démarre le device
  // aussitôt (il rend du silence), donc l'écran verrouillé affichait le glyphe
  // PAUSE sur une app qui n'avait jamais joué. Ni le `playbackRate` ni
  // `MPNowPlayingInfoCenter.playbackState` n'y peuvent quoi que ce soit: le
  // système ne les consulte pas pour cette décision-là.
  //
  // On suspend donc le device tant que rien ne joue. Sans risque: `rewamp_play`
  // est le SEUL chemin qui démarre le son, et il redémarre le device d'abord.
  if (!kIsWeb && Platform.isIOS) audio.deviceSuspend();
  audio.setDataDir(dataDir);
  // SoundFonts (MIDI): apply the persisted selection; if none is installed,
  // quietly fetch the server-default one in the background.
  SoundfontManager.instance.init(dataDir, audio);
  unawaited(SoundfontManager.instance.applyStartup());
  Mt32RomManager.instance.init(dataDir, audio);
  Mt32RomManager.instance.applyStartup();
  // projectM presets: stage the persisted source + texture dirs so the first
  // visualizer init picks them up. No network.
  PresetManager.instance.init(dataDir, audio);
  unawaited(PresetManager.instance.applyStartup());

  // Launch intro: decode the splash logo + pick an effect BEFORE runApp so the
  // intro's first frame is pixel-exact with the native splash (invisible seam).
  // Non-fatal — a decode failure just skips the intro.
  ui.Image? splashImage;
  try {
    splashImage = await loadSplashImage();
  } catch (e) {
    debugPrint('splash intro: image decode failed — $e');
  }
  final splashEffect = pickRandomEffect();

  // EXPÉRIMENTATION (branche feat/liquid-glass-chrome): précharge les shaders
  // de la lentille. Sans ça, la première apparition d'une surface en verre
  // coûte la compilation du programme — même problème que la construction du
  // PSO au premier draw côté projectM.
  await LiquidGlassShaders.ensureLoaded();

  runApp(RewampApp(splashImage: splashImage, splashEffect: splashEffect));
  // Display metrics may not be ready before the first frame (the early lock
  // above is then a no-op) — re-assert once the view has a size.
  WidgetsBinding.instance.addPostFrameCallback((_) => OrientationLock.lock());
}

class RewampApp extends StatefulWidget {
  final ui.Image? splashImage;
  final SplashEffect splashEffect;
  const RewampApp({super.key, this.splashImage, required this.splashEffect});

  @override
  State<RewampApp> createState() => _RewampAppState();
}

class _RewampAppState extends State<RewampApp> {
  @override
  void initState() {
    super.initState();
    UserSettings.instance.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    UserSettings.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  static ThemeData _buildTheme(Brightness brightness) =>
      rewampThemeData(ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: brightness,
      ));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rewamp',
      // App-level navigator: AppSnack falls back to its overlay when a call
      // site's own context is defunct (e.g. a download that outlived its screen).
      navigatorKey: AppSnack.navigatorKey,
      themeMode: UserSettings.instance.themeMode,
      theme:     _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // La liste GÉNÉRÉE, jamais une copie à la main: elle suit les fichiers
      // ARB, et une langue ajoutée n'a rien à recopier ici. (Le pendant Apple,
      // `CFBundleLocalizations`, ne peut pas la partager — les plists sont lus
      // par Xcode; `apple_locales_test.dart` compare les deux.)
      supportedLocales: AppLocalizations.supportedLocales,
      // ⚠️ Apple canonicalise « no » en « nb »: sans ce rapprochement, un
      // appareil norvégien tombe sur la langue de repli alors que sa traduction
      // existe. Voir resolveAppLocale — il fixe aussi le repli, que Flutter
      // prendrait sinon en tête de liste (alphabétique: le tchèque).
      localeResolutionCallback: resolveAppLocale,
      // Mobile: un doigt posé hors du champ en cours d'édition ferme le
      // clavier virtuel. Autour du Navigator pour couvrir routes, feuilles et
      // le lecteur en overlay d'un seul geste — voir keyboard_dismiss.dart.
      builder: (context, child) =>
          KeyboardDismissOnTapOutside(child: child ?? const SizedBox.shrink()),
      home: SplashGate(
        image: widget.splashImage,
        effect: widget.splashEffect,
      ),
    );
  }
}

/// Cold-start gate: builds [AppShell] underneath and overlays the launch intro
/// on top. The intro plays once per process (main() runs once per cold start —
/// no replay on in-app navigation) and the overlay is removed on completion.
/// If the splash image failed to decode, shows AppShell straight away.
class SplashGate extends StatefulWidget {
  final ui.Image? image;
  final SplashEffect effect;
  const SplashGate({super.key, required this.image, required this.effect});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _introDone = false;

  /// Lu UNE fois, au montage: marquer la note comme vue changerait la réponse
  /// en cours de route et la ferait disparaître avant le fondu.
  late bool _showNotes = releaseNotesPending();

  /// L'effet joué. Il part du tirage au sort fait dans main(), et un doigt
  /// MAINTENU au démarrage peut l'écraser une fois: l'écran est une grille
  /// 3x5, une case = un effet (voir splashEffectIndexAt).
  late SplashEffect _effect = widget.effect;

  @override
  void initState() {
    super.initState();
    // La sonde tourne depuis la première ligne de main(), donc le doigt a pu
    // se poser bien avant ce montage: elle le rend tout de suite s'il est déjà
    // maintenu. Elle reste armée jusqu'à la FIN de l'intro — un doigt posé
    // avant le lancement n'atteint jamais Dart (le système livre le geste à la
    // fenêtre qui a pris son `down`), donc le seul moment où l'appui est
    // livrable est pendant que le soleil est à l'écran.
    listenLaunchTouch(_onLaunchTouch);
  }

  @override
  void dispose() {
    stopLaunchTouchProbe();
    super.dispose();
  }

  void _onIntroDone() {
    stopLaunchTouchProbe();
    setState(() => _introDone = true);
  }

  void _onLaunchTouch(Offset pos) {
    if (!mounted || _introDone) return;
    // Position ET taille en pixels PHYSIQUES, de la même vue: la grille ne
    // fait que des rapports, donc le ratio d'échelle s'annule au lieu d'avoir
    // à être connu — il ne l'est pas forcément quand l'appui est capté, et une
    // conversion fausse envoie le doigt dans une case vide sans un mot.
    final view = ui.PlatformDispatcher.instance.implicitView;
    final size = view?.physicalSize ??
        (MediaQuery.sizeOf(context) * MediaQuery.devicePixelRatioOf(context));
    final idx = splashEffectIndexAt(pos, size);
    final col = (pos.dx / size.width * kSplashGridCols).floor();
    final row = (pos.dy / size.height * kSplashGridRows).floor();
    debugPrint('[launch touch] @${pos.dx.round()},${pos.dy.round()} '
        'sur ${size.width.round()}x${size.height.round()} → '
        'colonne ${col + 1}, rangée ${row + 1} → '
        '${idx == null ? "AUCUN effet sur cette case" : kSplashEffects[idx].asset}');
    if (idx == null || kSplashEffects[idx].asset == _effect.asset) return;
    // La clé porte l'asset, donc SplashIntro est REMONTÉ et repart de sa
    // frame 0 — le soleil seul pour tous les effets, si bien que la bascule
    // ne se voit pas.
    setState(() => _effect = kSplashEffects[idx]);
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.image;
    final showIntro = !_introDone && img != null;
    return Stack(
      children: [
        const AppShell(),               // builds/warms up under the intro
        // La note PROLONGE l'intro: elle prend le relais sur le même fond,
        // sans que l'app apparaisse entre les deux. Elle reste dans la même
        // pile (pas une route) pour la même raison que le lecteur — rien à
        // pousser, rien à dépiler, et AppShell continue de se réchauffer
        // dessous pendant la lecture.
        if (!showIntro && _showNotes)
          Positioned.fill(
            child: ReleaseNotesSplash(
              image: img,
              onDismiss: () {
                markReleaseNotesShown();
                setState(() => _showNotes = false);
              },
            ),
          ),
        if (showIntro)
          Positioned.fill(
            child: SplashIntro(
              key: ValueKey<String>(_effect.asset),
              effect: _effect,
              image: img,
              onDone: _onIntroDone,
            ),
          ),
      ],
    );
  }
}
