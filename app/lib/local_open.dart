import 'picker_memory.dart';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:path/path.dart' as p;

import 'package:flutter/services.dart';
import 'package:rewamp_audio/rewamp_audio.dart' show SubsongInfo;

import 'formats.dart';
import 'local_db.dart' show LocalDb, TrackRecord;
import 'local_import.dart' show androidPickerStartDir;
import 'opened_files.dart';
import 'player_controller.dart';
import 'preset_manager.dart';
import 'rewamp_db.dart';
import 'uade_info.dart';

/// Turning a local PATH into the tracks it stands for — the part of "open a
/// file" that has nothing to do with WHERE the path came from.
///
/// This used to live inside HomeScreen._pickFile, welded to a BuildContext and
/// to that widget's callbacks, and each branch played its result and returned.
/// That is fine for a picker, which hands over exactly one path, and useless
/// for anything else: a drag-and-drop delivers SEVERAL paths at once and has to
/// accumulate them into one queue operation, and a drop on the Dock icon
/// arrives at the app level where HomeScreen may not even be built yet.
///
/// So the routing is here, context-free and UI-free. Callers decide what to do
/// with the tracks (play, append, replace) and how to surface [LocalOpenNotice].

/// Extensions whose files can hold SEVERAL subsongs, so a single path expands
/// into a whole queue — the set the native probe is allowed to interrogate.
const kMultiTrackExts = {
  'nsf', 'nsfe',      // NES
  'gbs',              // Game Boy
  // Un `.gbr` est un rip du DRIVER: aucune table de morceaux, libgbsplay
  // annonce 255 faute de savoir. C'est la sonde native qui demande au pilote
  // lesquels jouent vraiment, et sa liste est CREUSE — la position n'est donc
  // pas l'index (`subsongIndicesFor`), exactement comme un `.adl`.
  'gbr',              // Game Boy — rip de driver
  'sid', 'psid', 'rsid',
  'sap',              // Atari 8-bit
  'kss', 'mgs', 'bgm', 'mpk', 'mbm', 'opx', 'mus',
  'hes', 'sgc',
  'ay', 'vtx', 'pt3', 'stc', 'chp',
  'gym', 's98', 'vgm', 'vgz', 'dro', 'dr0',
  'wsr',              // WonderSwan
  // Un `.adl` Westwood est une TABLE de morceaux — et sa sous-chanson 0 est
  // presque toujours la routine d'ARRÊT du pilote, donc sans cette ligne un
  // `.adl` ouvert localement ne jouait RIEN. ⚠️ Sa liste est CREUSE: la sonde
  // écarte les entrées qui ne jouent aucune note (DUNE19.ADL: 43 vivantes sur
  // 74 annoncées), donc la POSITION n'y est pas l'index — voir
  // subsongIndicesFor.
  'adl',              // Westwood ADL (AdPlug)
  // RSN = un RAR SOLIDE de .spc, joué EN PLACE (jamais dépaqueté, les chemins
  // `.spc` par piste n'existent pas): les pistes sont donc des sous-chansons,
  // pas des fichiers. `gme_open_file` ouvre le conteneur via Rsn_Emu et
  // `gme_track_count` rend le compte réel — et le probe natif n'est filtré par
  // aucune extension, il suffisait de le LUI DEMANDER. Sans cette ligne le
  // navigateur Local jouait la sous-chanson 0 et rien d'autre.
  'rsn',              // SNES — archive RAR de SPC
  'sndh',             // Atari ST — SNDH archives commonly bundle up to 128 subsongs.
  // OpenMPT tracker modules can hold several subsongs (order-list sequences,
  // e.g. some S3M/IT compilations). probeSubsongCount tries to open ANY file
  // via libopenmpt regardless of extension and returns 0/1 for a plain single-
  // song module, so gating on these extensions is safe and just extends the
  // existing count>1 check to trackers.
  ...kTrackerExts,
  // Furnace importe les morceaux d'un `.ftm` FamiTracker (et d'un `.0cc`,
  // `.dnm`, `.eft`) en SOUS-CHANSONS — « Shovel Knight » en porte une dizaine.
  // Même raisonnement que pour les trackers ci-dessus: la sonde native ne
  // revendique qu'au-delà d'une sous-chanson, donc un module simple reste un
  // fichier simple.
  ...kFurnaceExts,
};

/// Something the caller may want to tell the user about. Kept as an enum rather
/// than a string so this file needs no l10n and no BuildContext.
enum LocalOpenNotice {
  extractingArchive,
  archiveEmpty,
  playlistUnreadable,
  /// Milkdrop presets landed in the projectM library instead of the queue
  /// (a dropped .milk, or an archive holding presets and no audio).
  presetsImported,
  /// Ouverture en LOT dont TOUT a été filtré (pochettes, banques
  /// d'échantillons, bibliothèques PSF). Sans ce mot, un « tout sélectionner »
  /// sur un dossier sans musique ne ferait rien du tout, en silence.
  nothingPlayable,
}

/// Hands local paths to the running app — set by AppShell, called by whatever
/// delivers files from outside the UI (a drop on the window, a drop on the Dock
/// icon, "Open With" in the Finder).
///
/// A global rather than a callback threaded down, for the same reason
/// globalOnQueueAdd is one: the caller is not a widget and has no route to the
/// shell. Null until the shell is built, which is exactly the cold-start case
/// the native side has to buffer for.
Future<void> Function(List<String> paths)? globalOpenLocalPaths;

/// Le sélecteur de fichiers de l'OUVERTURE, et rien d'autre: il rend des
/// chemins STABLES, prêts à jouer.
///
/// Sans filtre (le panneau Apple n'a jamais filtré, et un nom Amiga met son
/// format AVANT le point: filtrer grisait des fichiers jouables — c'est le
/// probe qui tranche à la réception), puis matérialisé sous `opened/` sur
/// mobile, où le chemin rendu par le sélecteur est une copie de cache que le
/// système purge quand il veut.
Future<List<String>> pickLocalFilesToPlay() async {
  final picked = await pickAnyFilePaths(PickerSlot.music,
      mobileStartDir: Platform.isAndroid ? androidPickerStartDir : null);
  if (picked.isEmpty) return const [];
  await PickerMemory.rememberFile(PickerSlot.music, picked.first);
  return OpenedFiles.materialise(picked);
}

// ── Files macOS hands the app from outside the UI ────────────────────────────

const _openFilesChannel = MethodChannel('rewamp/open_files');

/// Efface la copie qu'iOS a déposée dans `Documents/Inbox/` pour nous.
///
/// Quand une app reçoit un document sans l'ouvrir « en place » — c'est le mode
/// `.import` qu'utilise `file_selector_ios`, et le cas d'un « Ouvrir avec » sur
/// un fichier non partageable — **iOS en fait une copie dans notre
/// `Documents/Inbox/` et nous en donne le chemin**. Cette copie nous
/// appartient: Apple documente que l'app doit l'effacer une fois le fichier
/// consommé, et personne d'autre ne le fera.
///
/// Laissée là, elle s'accumule à chaque import — dans `Documents`, donc
/// **sauvegardée dans iCloud et visible dans l'app Fichiers**, sans que
/// l'utilisateur ait de quoi faire le lien entre « j'ai importé une SoundFont »
/// et « mon espace disque baisse ». Une SF2 pèse couramment 100 Mo.
///
/// À appeler APRÈS que l'import a lu le fichier. Ne touche QUE des copies que
/// le SÉLECTEUR a faites dans notre bac à sable — Inbox, ou le dossier
/// temporaire où `file_picker` dépose la sienne (depuis le 2026-09-14, les
/// imports mobiles passent tous par lui: voir `pickerUsesFilePicker`). Un
/// chemin ailleurs est le fichier de l'utilisateur, on n'y touche pas.
Future<void> consumeInboxCopy(String? path) async {
  if (path == null || !Platform.isIOS) return;
  final tmp = Directory.systemTemp.path;
  final isPickerCopy = path.contains('/Documents/Inbox/') ||
      (tmp.isNotEmpty && path.startsWith(tmp));
  if (!isPickerCopy) return;
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {/* rien à faire: c'est du ménage, pas une étape du geste */}
}

/// Les plateformes dont le côté natif tient un tampon de fichiers ouverts.
bool get _hasNativeOpen =>
    Platform.isMacOS || Platform.isIOS || Platform.isAndroid;

/// Chemins passés en ARGUMENTS au lancement — le mécanisme de Linux et de
/// Windows, là où Apple a `application(_:open:)`.
///
/// Le runner GTK transmet déjà tout ce qui suit `argv[0]` comme arguments
/// d'entrée Dart; il ne manquait qu'un `main` qui les lise. Appelé depuis
/// `main()`, donc AVANT que le shell existe: les chemins rejoignent la même
/// file d'attente que ceux d'un démarrage à froid sur Apple, et le premier
/// `drainOpenedFiles` les emporte.
///
/// Filtré sur « le fichier existe »: la ligne de commande porte aussi des
/// options (`--enable-impeller`, un `--flag=valeur`), et rien ne les distingue
/// d'un chemin par la forme seule.
void seedOpenedPathsFromArgs(List<String> args) {
  for (final a in args) {
    if (a.isEmpty || a.startsWith('-')) continue;
    try {
      if (File(a).existsSync()) _awaitingShell.add(a);
    } catch (_) {/* chemin invalide: ce n'en était pas un */}
  }
}

/// Paths collected from the native buffer before [globalOpenLocalPaths] was
/// set. `takePending` CLEARS the native side, so anything we fetch is ours to
/// keep or to lose — dropping it because the shell was one frame late would
/// silently swallow the files that started the app.
final List<String> _awaitingShell = [];

/// Starts listening for files opened through the Dock, the Finder, or a
/// double-click. Call once, after [globalOpenLocalPaths] is set.
///
/// macOS, iOS et Android tiennent un tampon natif et la MÊME discipline: le
/// natif ne pousse jamais, Dart tire. Linux et Windows livrent leurs chemins en
/// ARGUMENTS, semés depuis `main` (voir [seedOpenedPathsFromArgs]).
///
/// Sur iOS le chemin rendu est une COPIE dans notre bac à sable (voir
/// `AppDelegate.ingestOpenedFile`): une URL « en place » n'est lisible que le
/// temps d'une portée de sécurité, et nos décodeurs C ouvrent le fichier bien
/// après.
void listenForOpenedFiles() {
  // Linux/Windows n'ont pas de canal natif, mais peuvent avoir des chemins
  // semés par la ligne de commande: on tente le drain quand même.
  if (!_hasNativeOpen) {
    if (_awaitingShell.isNotEmpty) drainOpenedFiles();
    return;
  }
  _openFilesChannel.setMethodCallHandler((call) async {
    if (call.method == 'filesAvailable') await drainOpenedFiles();
  });
  // A cold start opened BY a file: the native buffer is already full and no
  // nudge is coming that we have not already missed, so ask straight away.
  drainOpenedFiles();
}

/// Pulls whatever the native side has buffered and hands it to the shell.
Future<void> drainOpenedFiles() async {
  if (_hasNativeOpen) {
    try {
      final fetched =
          await _openFilesChannel.invokeListMethod<String>('takePending');
      if (fetched != null) _awaitingShell.addAll(fetched);
    } catch (_) {/* channel not up yet — the next nudge retries */}
  }
  final open = globalOpenLocalPaths;
  if (open == null || _awaitingShell.isEmpty) return;
  final batch = List<String>.from(_awaitingShell);
  _awaitingShell.clear();
  await open(batch);
}

typedef LocalOpenReporter = void Function(LocalOpenNotice notice);

/// Extensions qui n'existent QUE pour être chargées par un autre fichier: la
/// moitié « bibliothèque » d'un jeu PSF, dont le `.mini*sf` porte la musique.
///
/// ⚠️ Elles sont dans `kExtractedAudioExts` **à raison** — une archive DOIT les
/// extraire, sinon le `.minigsf` qui les référence ne joue pas. « Faut-il
/// extraire ce fichier ? » et « faut-il le METTRE EN FILE ? » sont deux
/// questions différentes, et c'est la seconde que ce jeu tranche.
const kCompanionOnlyExts = <String>{
  'psflib', 'psf2lib', 'gsflib', '2sflib', 'ncsflib',
  'usflib', 'ssflib', 'dsflib', 'snsflib', 'qsflib',
  // Kits de percussions de FAC Soundtracker: un `.mus` nomme son kit à
  // l'offset `taille - 124` et le moteur va chercher `<NOM>.SM1` + `.SM2` à
  // côté. Ce sont des BANQUES D'ÉCHANTILLONS, jamais des morceaux — les mettre
  // en file donnerait des pistes muettes portant le nom du kit.
  'sm1', 'sm2',
  // Banque MT-32 d'un jeu (dump brut de sysex Roland: Sierra, Prince of
  // Persia, Betrayal at Krondor…): le greffon MT-32 l'envoie avant les
  // morceaux de son dossier. Sans cette ligne, vgmstream — qui réclame toute
  // extension inconnue — en faisait une piste.
  'syx',
};

/// Ce qui n'est JAMAIS de la musique: images, textes, documents, fichiers de
/// contrôle. Règle NÉGATIVE absolue, posée AVANT la seconde chance du moteur:
/// vgmstream réclame toute extension inconnue (score 50), donc `canPlay`
/// répondait OUI pour un `.jpg` — « lire un dossier » mettait la pochette en
/// file, et l'import pouvait l'enregistrer comme piste.
const kNeverPlayableExts = <String>{
  'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'avif', 'tif', 'tiff', 'ico',
  'heic', 'svg', 'txt', 'nfo', 'diz', 'pdf', 'htm', 'html', 'md', 'ini',
  'json', 'xml', 'log', 'doc', 'docx', 'rtf', 'csv', 'sfv', 'md5', 'sha1',
  'url', 'lnk', 'db', 'exe', 'com', 'bat', 'dll',
};

/// Un MIDI qui ne porte QUE des sysex: la banque MT-32 d'un jeu livrée comme
/// un morceau (`sysexmain.mid` d'Ultima VII: « play this first to program the
/// MT-32 »). Le greffon MT-32 la charge pour les morceaux de son dossier; en
/// file, elle ne jouerait que du silence. Restreint aux noms en `sys…`, comme
/// le greffon, et à un fichier de taille raisonnable (lu en entier).
bool isMt32BankMidi(String path) {
  final b = p.basename(path).toLowerCase();
  if (!b.startsWith('sys')) return false;
  final ext = p.extension(b);
  if (ext != '.mid' && ext != '.midi') return false;
  try {
    final f = File(path);
    if (f.lengthSync() > 256 * 1024) return false;
    return midiIsSysexOnly(f.readAsBytesSync());
  } catch (_) {
    return false;
  }
}

/// Vrai quand ce SMF porte au moins un sysex et AUCUNE note. Un fichier
/// illisible n'est pas une banque (faux).
@visibleForTesting
bool midiIsSysexOnly(List<int> d) {
  int u32(int i) => (d[i] << 24) | (d[i + 1] << 16) | (d[i + 2] << 8) | d[i + 3];
  try {
    if (d.length < 14 || String.fromCharCodes(d.sublist(0, 4)) != 'MThd') return false;
    final ntr = (d[10] << 8) | d[11];
    var p0 = 8 + u32(4);
    var sysex = 0;
    for (var t = 0; t < ntr; t++) {
      if (String.fromCharCodes(d.sublist(p0, p0 + 4)) != 'MTrk') return false;
      final end = p0 + 8 + u32(p0 + 4);
      var q = p0 + 8;
      var status = 0;
      int vlq() {
        var v = 0;
        while (true) {
          final c = d[q++];
          v = (v << 7) | (c & 0x7F);
          if (c < 0x80) return v;
        }
      }
      while (q < end) {
        vlq();
        if (d[q] & 0x80 != 0) status = d[q++];
        if (status == 0xFF) {
          q++;
          final l = vlq();
          q += l;
        } else if (status == 0xF0 || status == 0xF7) {
          final l = vlq();
          q += l;
          sysex++;
        } else {
          final k = status & 0xF0;
          if (k == 0xC0 || k == 0xD0) {
            q += 1;
          } else {
            if (k == 0x90 && d[q + 1] > 0) return false;
            q += 2;
          }
        }
      }
      p0 = end;
    }
    return sysex > 0;
  } catch (_) {
    return false;
  }
}

/// Ce fichier mérite-t-il d'entrer dans une file quand on en ouvre PLUSIEURS
/// d'un coup (« tout sélectionner » dans un dossier, dépôt d'un lot, dossier).
///
/// Volontairement PAS appliqué à un choix unique et délibéré: si l'utilisateur
/// désigne un seul fichier, on essaie de le jouer même d'extension inconnue —
/// c'est `rewamp_can_play` qui tranche au chargement. Le filtre sert à ne pas
/// noyer la file sous des pochettes et des banques d'échantillons, pas à
/// interdire.
/// [canPlay] est la SECONDE CHANCE, confiée au moteur, pour ce que la liste
/// d'extensions ne peut pas trancher — et elle est nécessaire, pas cosmétique:
/// certains formats sont reconnus par leur CONTENU et volontairement absents
/// de toute liste d'extensions parce que celle-ci est trop générique. Le `.raw`
/// en est le cas d'école: `monkey island 2 - intro.raw` commence par
/// `RAWADATA` et AdPlug le joue, mais `raw` désigne aussi du PCM sans en-tête,
/// donc ni le probe natif ni `kExtractedAudioExts` ne l'inscrivent — c'est
/// l'en-tête qui décide (`adplug_magic_score`, score 100). Filtrer sur la
/// seule liste écartait donc un fichier parfaitement jouable.
///
/// Passer `rewamp_can_play` (registre complet: extension + en-tête, sans
/// décoder). Les règles NÉGATIVES ci-dessus restent absolues: une bibliothèque
/// PSF est un conteneur valide que le registre accepterait, alors qu'elle n'a
/// pas de musique à elle.
bool isBulkQueueCandidate(String path, {bool Function(String)? canPlay}) {
  final b = path.split(Platform.pathSeparator).last;
  if (b.startsWith('.')) return false;
  // Un dossier de COMPAGNONS ne contient pas de pistes, quelles que soient les
  // extensions qu'on y trouve — et elles sont jouables par ailleurs (`.ss` est
  // SpeedySystem). Règle NÉGATIVE de même nature que kCompanionOnlyExts, mais
  // portée par l'EMPLACEMENT et non par le nom. Voir [isInCompanionDir].
  if (isInCompanionDir(path)) return false;
  final ext = b.contains('.') ? b.split('.').last.toLowerCase() : '';
  // Forme PRÉFIXE des modules Amiga: `mdat.NAME`, `smpl.NAME`… — le format est
  // avant le point, donc le suffixe ne dit rien.
  final pre = b.contains('.') ? b.split('.').first.toLowerCase() : '';
  if (kCompanionOnlyExts.contains(ext)) return false;
  if (kNeverPlayableExts.contains(ext)) return false;
  if (isMt32BankMidi(path)) return false;
  if (RewampDb.kExtractedAudioExts.contains(ext) ||
      RewampDb.kExtractedAudioExts.contains(pre) ||
      RewampDb.kLocalArchiveExts.contains(ext)) {
    return true;
  }
  return canPlay?.call(path) ?? false;
}

/// Les sous-chansons qu'un M3U posé À CÔTÉ de [path] déclare POUR CE FICHIER,
/// ou null quand il n'y en a pas.
///
/// C'est le M3U qui fait autorité, pas la sonde native, et la différence n'est
/// pas cosmétique: le `.gbs` de « Gargoyle's Quest » a ses morceaux aux index
/// 0, 2, 3, 12 et 16 — la sonde en annonce des dizaines, dont les cases mortes
/// entre les deux, toutes nommées « DMG-RAJ (n) ». Le M3U, lui, donne les cinq
/// vrais, leurs titres et leurs durées. Un rip joshw/GBgbs est TOUJOURS livré
/// avec le sien, dans l'archive comme à côté du fichier.
///
/// Rapproché par BASENAME: le chemin qu'écrit le parseur passe par `_sanitize`
/// et ne vaut pas caractère pour caractère celui du fichier sur disque.
Future<List<TrackRecord>?> m3uSubsongsFor(
  String path, {
  String? album,
  String? artist,
  M3uLookupCache? m3uCache,
}) async {
  List<SubsongInfo>? subs;
  try {
    subs = await RewampDb.probeLocalM3u(path, cache: m3uCache);
  } catch (_) {
    return null;
  }
  if (subs == null || subs.isEmpty) return null;
  final name = path.split(Platform.pathSeparator).last;
  final want = name.toLowerCase();
  final mine = [
    for (final s in subs)
      if (s.filePath.split(Platform.pathSeparator).last.toLowerCase() == want) s
  ];
  if (mine.isEmpty) return null;
  // Un M3U d'ALBUM — plusieurs fichiers DISTINCTS, chacun listé une fois —
  // n'est pas une liste de sous-chansons: l'appliquer à un fichier
  // mono-piste lui inventait un index et un titre (payé sur Battle Garegga:
  // « 02 Rebellion [Opening].vgz » ressortait « 2 »). L'autorité M3U ne vaut
  // que quand le fichier y apparaît PLUSIEURS fois (joshw: un .nsf, vingt
  // lignes) ou que le M3U ne parle que de lui.
  final distinctFiles = {
    for (final s in subs)
      s.filePath.split(Platform.pathSeparator).last.toLowerCase()
  };
  if (mine.length == 1 && distinctFiles.length > 1) return null;
  final ext  = name.split('.').last.toLowerCase();
  final base = name.replaceAll(RegExp(r'\.\w+$'), '');
  return [
    for (var i = 0; i < mine.length; i++)
      TrackRecord(
        id:         '',
        // Le chemin RÉEL, jamais celui reconstruit par le parseur.
        filePath:   path,
        entryPath:  '',
        subsongIdx: mine[i].subsongIdx,
        title:      mine[i].title ?? '$base (${i + 1})',
        metaAlbum:  album,
        artist:     artist,
        durationS:  (mine[i].durationMs ?? 0) > 0
            ? mine[i].durationMs! / 1000.0
            : null,
        formatExt:  ext,
        source:     'local',
        isFavorite: false,
        inLibrary:  false,
        playCount:  0,
      ),
  ];
}

/// Les sous-chansons telles que le FICHIER les déclare: titres et durées lus
/// par le moteur, pas fabriqués.
///
/// Un `.nsfe` porte ses noms de piste (chunk `tlbl`) et ses durées (`time`);
/// un `.gbs`, un `.spc`, un `.kss` en portent aussi selon le rip. Le probe
/// natif les remonte déjà (`rewamp_probe_get_title`/`_duration_ms`), mais
/// l'ouverture locale ne s'en servait pas: elle ne prenait que le COMPTE et
/// fabriquait « NOM (1) », « NOM (2) »… — les vrais titres étaient là, à un
/// appel de distance, et personne ne les lisait.
///
/// Rend null quand il n'y a rien à apporter (une seule sous-chanson, ou aucun
/// titre non vide): l'appelant garde alors ses noms numérotés, qui valent
/// mieux qu'une liste de chaînes vides.
///
/// [known] = les lignes DÉJÀ en base pour ce fichier, par index de
/// sous-chanson. Elles portent l'artwork, les compteurs de lecture et le ♥;
/// on ne remplace que ce que le fichier dit mieux.
List<TrackRecord>? engineSubsongsFor(
  String path,
  PlayerController controller, {
  String? album,
  Map<int, TrackRecord> known = const {},
}) {
  final List<SubsongInfo> subs;
  try {
    subs = controller.audio.probeSubsongs(path);
  } catch (_) {
    return null;
  }
  return subsongRecordsFrom(subs, path, album: album, known: known);
}

/// Les VRAIS index de sous-chanson de [path], dans l'ordre de la liste
/// jouable, ou l'identité quand la sonde ne sait rien (le cas de tout le
/// reste).
///
/// ⚠️ Une liste peut être CREUSE: un `.adl` Westwood garde entre ses morceaux
/// des entrées de CONTRÔLE (arrêt, fondu) qui ne jouent aucune note, et la
/// sonde ne rend que les vivantes. La position n'y est donc pas l'index, et
/// reconstruire la file par `List.generate(count, (i) => …subsongIdx: i)`
/// enfile des slots muets. La liste n'est adoptée que si elle a EXACTEMENT
/// [count] entrées — un compte venu du serveur décrit autre chose.
List<int> subsongIndicesFor(
    String path, PlayerController controller, int count) {
  try {
    final subs = controller.audio.probeSubsongs(path);
    if (subs.length == count) return [for (final s in subs) s.subsongIdx];
  } catch (_) {}
  // Sonde muette: au moins la BASE du format (SNDH/sc68 comptent à partir de 1).
  return RewampDb.genericSubsongIndices(
      path.contains('.') ? path.split('.').last : '', count);
}

/// La moitié PURE de [engineSubsongsFor] — celle qui décide — séparée du
/// moteur pour être testable: l'hôte de test Dart n'a pas le natif.
List<TrackRecord>? subsongRecordsFrom(
  List<SubsongInfo> subs,
  String path, {
  String? album,
  Map<int, TrackRecord> known = const {},
}) {
  if (subs.length < 2) return null;
  // Sans titres, la sonde n'apporte rien que le COMPTE ne dise déjà — sauf
  // quand la liste est CREUSE: là, l'index réel est une information que le
  // repli par position (`List.generate(count, (i) => …i)`) ne peut PAS
  // reconstruire, et s'en passer met en file des slots silencieux.
  final sparse = subs.any((s) => s.subsongIdx != s.index);
  if (!sparse && !subs.any((s) => (s.title ?? '').trim().isNotEmpty)) return null;

  final name = path.split(Platform.pathSeparator).last;
  final ext  = name.split('.').last.toLowerCase();
  final base = name.replaceAll(RegExp(r'\.\w+$'), '');
  return [
    for (var i = 0; i < subs.length; i++)
      () {
        final s     = subs[i];
        final title = (s.title ?? '').trim();
        final secs  = (s.durationMs ?? 0) > 0 ? s.durationMs! / 1000.0 : null;
        final row   = known[s.subsongIdx];
        // Une ligne déjà connue garde TOUT ce qu'elle sait (♥, écoutes,
        // pochette) et ne reçoit que ce que le fichier énonce mieux.
        if (row != null) {
          return row.copyWith(
            title:     title.isEmpty ? null : title,
            durationS: secs,
          );
        }
        return TrackRecord(
          id:         '',
          filePath:   path,
          entryPath:  '',
          subsongIdx: s.subsongIdx,
          // Un titre vide au milieu d'une liste qui en a: on numérote celui-là
          // seul, plutôt que de laisser une ligne sans nom.
          title:      title.isEmpty ? '$base (${i + 1})' : title,
          metaAlbum:  album,
          durationS:  secs,
          formatExt:  ext,
          source:     'local',
          isFavorite: false,
          inLibrary:  false,
          playCount:  0,
        );
      }(),
  ];
}

/// Every playable track [path] stands for, in play order.
///
/// Empty means "nothing playable here" — the caller decides whether that is
/// worth a message. A plain single-subsong file returns exactly one record.
/// Complète une ligne locale avec ce que dit le M3U voisin: son TITRE d'entrée
/// (`#EXTINF`), puis l'album et les artistes de l'en-tête.
///
/// Un rip local n'a aucune ligne serveur: son M3U est la seule chose qui sache
/// le nom de l'album et ses compositeurs (`#EXTALB:`, `#EXTART:`, ou un
/// « # Composer(s): » du bloc libre — voir m3u_info.dart). La branche « fichier
/// simple » fabriquait une ligne qui ne porte que le NOM DU FICHIER: le lecteur
/// affichait donc un titre nu, sans artiste ni album, pour un dossier qui les
/// déclare en toutes lettres.
///
/// Deux régimes, et ils ne sont pas contradictoires:
///
///  * **le TITRE d'entrée fait AUTORITÉ** et remplace celui de la ligne —
///    c'est la règle du dépôt (« le M3U fait autorité »), et la ligne
///    fabriquée ne porte de toute façon que le nom du fichier;
///  * **l'album et l'artiste ne comblent que les TROUS**. « La ligne DÉJÀ EN
///    BASE gagne »: une lecture qui ne sait pas ne doit rien écraser.
///
/// ⚠️ Rien de tout ça sur une ligne du CATALOGUE (`online_id` posé): le
/// serveur dit mieux, et un M3U traîne à côté de tout album téléchargé.
///
/// ⚠️ Posé dans l'ENTONNOIR et non dans les cinq branches qui fabriquent des
/// lignes (conteneur, UADE, M3U, moteur, fichier simple): les recoder une par
/// une garantirait qu'il en manque une.
Future<List<TrackRecord>> _fillFromM3uHeader(
    String path, List<TrackRecord> rows, M3uLookupCache? cache) async {
  if (rows.isEmpty) return rows;
  // Une ligne du CATALOGUE ne se fait pas corriger par un M3U voisin: le
  // serveur dit mieux, et un M3U traîne à côté de tout album téléchargé.
  if (rows.any((t) => (t.onlineId ?? '').isNotEmpty)) return rows;

  // Le TITRE que le M3U donne à CE fichier. `#EXTINF:43,Nom de la piste` —
  // c'est le nom que le ripeur a voulu, et le dépôt tient déjà le M3U pour
  // AUTORITAIRE sur les titres. La ligne fabriquée, elle, ne porte que le nom
  // du fichier (« tentacle_001 »).
  //
  // ⚠️ Seulement pour un fichier SIMPLE — une ligne, sous-chanson 0. Un
  // fichier listé plusieurs fois est un conteneur dont le M3U décrit les
  // sous-chansons, et ce chemin-là a déjà son traitement (m3uSubsongsFor):
  // `localM3uEntryFor` ne répond que s'il n'y a qu'une entrée.
  if (rows.length == 1 && rows.first.subsongIdx == 0) {
    final entry = await RewampDb.localM3uEntryFor(path, cache: cache);
    final t = (entry?.title ?? '').trim();
    if (t.isNotEmpty && t != rows.first.title) {
      rows = [rows.first.copyWith(title: t)];
    }
  }

  final needs = rows.any((t) =>
      (t.artist ?? '').isEmpty || (t.metaAlbum ?? '').isEmpty);
  if (!needs) return rows;
  final info = await RewampDb.localM3uInfo(path, cache: cache);
  if (info == null) return rows;
  final artist = info.artists.isEmpty ? null : info.artists.join(', ');
  final album  = info.album;
  if (artist == null && album == null) return rows;
  return [
    for (final t in rows)
      t.copyWith(
        artist:    (t.artist ?? '').isEmpty ? artist : null,
        metaAlbum: (t.metaAlbum ?? '').isEmpty ? album : null,
      ),
  ];
}

/// Enveloppe de [_tracksForLocalPathInner] — voir [_fillFromM3uHeader].
Future<List<TrackRecord>> tracksForLocalPath(
  String path, {
  required PlayerController controller,
  LocalOpenReporter? report,
  LocalOpenBatch? batch,
}) async {
  final rows = await _tracksForLocalPathInner(path,
      controller: controller, report: report, batch: batch);
  // Un DOSSIER a déjà enrichi chacun de ses fichiers par leur propre M3U (la
  // récursion passe par ici): l'appel du dessus ne trouve plus de trou.
  return _fillFromM3uHeader(path, rows, batch?.m3u);
}

Future<List<TrackRecord>> _tracksForLocalPathInner(
  String path, {
  required PlayerController controller,
  LocalOpenReporter? report,
  LocalOpenBatch? batch,
}) async {
  // Les lignes en base d'un fichier: prises dans le LOT quand il couvre ce
  // chemin (une requête pour tout le dossier), sinon demandées à la base.
  Future<List<TrackRecord>> knownFor(String f) async =>
      (batch != null && batch.covers(f))
          ? (batch.known[f] ?? const <TrackRecord>[])
          : await LocalDb.instance.getTracksForFile(f);
  final name = path.split(Platform.pathSeparator).last;
  final ext  = name.split('.').last.toLowerCase();
  final base = name.replaceAll(RegExp(r'\.\w+$'), '');

  // Dropped FOLDER: presets first (a folder of .milk must never end up queued
  // as bogus audio), then every playable file inside, recursively — each one
  // back through this router so archives/containers inside the folder expand
  // exactly like a direct drop.
  if (FileSystemEntity.isDirectorySync(path)) {
    final n = await PresetManager.instance.importFromDir(path);
    if (n > 0) report?.call(LocalOpenNotice.presetsImported);
    final files = <String>[];
    try {
      await for (final e
          in Directory(path).list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        // Même règle que « tout sélectionner » dans un dossier: un dossier est
        // plein de pochettes, de notes et de banques d'échantillons qu'une file
        // doit sauter (voir isBulkQueueCandidate).
        if (isBulkQueueCandidate(e.path, canPlay: controller.audio.canPlay)) {
          files.add(e.path);
        }
      }
    } catch (_) {}
    files.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final inner = await LocalOpenBatch.prepare(files, m3u: batch?.m3u);
    final out = <TrackRecord>[];
    for (final f in files) {
      out.addAll(await tracksForLocalPath(f,
          controller: controller, report: report, batch: inner));
    }
    return out;
  }

  // Milkdrop preset: not audio — it goes to the projectM library (user/ dir),
  // never to the queue.
  if (ext == 'milk') {
    final n = await PresetManager.instance.importMilkFiles([path]);
    if (n > 0) report?.call(LocalOpenNotice.presetsImported);
    return const [];
  }

  // Local archive (UnExotica .lha, or any container): extract to cache and
  // enqueue every playable module inside. A locally-opened archive carries no
  // server aux_files, so any multifile companions (TFMX smpl.*, …) must live
  // inside the archive — and do, since the C extractor unpacks every entry;
  // UADE then resolves them as siblings.
  if (RewampDb.kLocalArchiveExts.contains(ext)) {
    report?.call(LocalOpenNotice.extractingArchive);
    final fileRecs = await RewampDb.extractLocalArchiveToTracks(path);
    if (fileRecs.isEmpty) {
      // Content detection: an archive with no playable audio can still be a
      // PRESET pack (zip of .milk + textures). The extraction already
      // happened into the cache dir — inspect it, no second extraction.
      try {
        final dir = await RewampDb.localArchiveCacheDir(path);
        final n = await PresetManager.instance.importFromDir(dir);
        if (n > 0) {
          report?.call(LocalOpenNotice.presetsImported);
          return const [];
        }
      } catch (_) {}
      report?.call(LocalOpenNotice.archiveEmpty);
      return const [];
    }
    // Expand each module into its subsongs so the queue plays EVERY subsong,
    // not just the first of each multi-subsong module (TFMX/NSF/…).
    return expandLocalModules(fileRecs, controller);
  }

  // Playlist file: expand the M3U/M3U8 and queue everything it references
  // (files resolved as siblings in the M3U's own directory; per-entry subsong
  // indices + titles/durations honoured). See RewampDb.parseM3uToSubsongs.
  if (ext == 'm3u' || ext == 'm3u8') {
    try {
      final content = await RewampDb.readM3uText(File(path));
      final subs    = RewampDb.parseM3uToSubsongs(content, File(path).parent.path);
      if (subs.isNotEmpty) {
        // La ligne DÉJÀ EN BASE d'abord, comme pour un fichier simple: un M3U
        // livré DANS un album téléchargé nomme ses entrées « 1 », « 2 »… et
        // n'a pour album que SON PROPRE NOM. Persisté tel quel, ça remplaçait
        // le titre et l'album du catalogue — mesuré sur jw_dsf, où l'album
        // affiché était « !playlist(MusicPlayer) » et les titres des numéros.
        //
        // Ce que le M3U apporte reste PRIORITAIRE là où il sait: un titre
        // d'entrée (les rips en portent souvent) bat celui de la base, et
        // c'est l'autorité que le projet lui reconnaît sur les sous-chansons.
        final byFile = <String, Map<int, TrackRecord>>{};
        for (final s in subs) {
          byFile.putIfAbsent(s.filePath, () => {});
        }
        for (final f in byFile.keys.toList()) {
          for (final t in await knownFor(f)) {
            byFile[f]![t.subsongIdx] = t;
          }
        }
        return [
          for (final s in subs)
            () {
              final known = byFile[s.filePath]?[s.subsongIdx];
              final title = s.title ?? known?.title ?? '${s.index + 1}';
              final dur = (s.durationMs ?? 0) > 0
                  ? s.durationMs! / 1000.0
                  : known?.durationS;
              if (known != null) {
                return known.copyWith(
                  title: title,
                  durationS: dur,
                  // L'album de la BASE quand elle en a un: le nom du M3U n'est
                  // un album que faute de mieux.
                  metaAlbum: (known.metaAlbum ?? '').isNotEmpty
                      ? known.metaAlbum
                      : base,
                );
              }
              return TrackRecord(
                id:         '',
                filePath:   s.filePath,
                entryPath:  '',
                subsongIdx: s.subsongIdx,
                title:      title,
                metaAlbum:  base,
                durationS:  dur,
                formatExt:  s.filePath.split('.').last.toLowerCase(),
                source:     'local',
                isFavorite: false,
                inLibrary:  false,
                playCount:  0,
              );
            }(),
        ];
      }
    } catch (_) {/* fall through to the notice below */}
    report?.call(LocalOpenNotice.playlistUnreadable);
    return const [];
  }

  // Multi-track container (NSF/GBS/SID/…): rebuild the full subsong queue.
  if (kMultiTrackExts.contains(ext)) {
    // Un M3U voisin bat la sonde native — voir m3uSubsongsFor.
    final fromM3u = await m3uSubsongsFor(path, m3uCache: batch?.m3u);
    if (fromM3u != null) return fromM3u;
    // Real subsong count from the native decoder (header).
    final count = controller.audio.probeSubsongCount(path);
    // Titles/artwork for subsongs already played (keyed by subsong index).
    final played = await knownFor(path);
    final byIdx  = {for (final t in played) t.subsongIdx: t};
    // Puis ce que le FICHIER déclare (NSFe `tlbl`/`time`, …), avant les noms
    // fabriqués plus bas.
    final fromEngine =
        engineSubsongsFor(path, controller, known: byIdx);
    if (fromEngine != null) return fromEngine;
    if (count > 1) {
      // Reuse DB rows when present so a single previously-played subsong never
      // collapses the queue to one entry.
      return List.generate(count, (i) => byIdx[i] ?? TrackRecord(
        id:         '',
        filePath:   path,
        entryPath:  '',
        subsongIdx: i,
        title:      '$base (${i + 1})',
        formatExt:  ext,
        source:     'local',
        isFavorite: false,
        inLibrary:  false,
        playCount:  0,
      ));
    }
    if (played.isNotEmpty) return played; // single-subsong, already known
  }

  // UADE multi-subsong (TFMX, some FC/…): subsong count/titles/durations come
  // from the audacious-uade songdb, not a native probe.
  if (UadeInfoService.isUadeFileAt(path)) {
    final info = await UadeInfoService.instance.forPath(path);
    // playableSubsongs drops the songdb's NOSOUND slots (silent, length 0) —
    // same default as upstream's skip_broken_subsongs.
    final playable = info?.playableSubsongs ?? const [];
    if (info != null && info.subsongCount > 1 && playable.length > 1) {
      return [
        for (var i = 0; i < playable.length; i++)
          TrackRecord(
            id:         '',
            filePath:   path,
            entryPath:  '',
            subsongIdx: playable[i].idx,
            title:      '$base (${i + 1})',
            metaAlbum:  info.album,
            artist:     info.authors.isEmpty ? null : info.authors.join(', '),
            durationS:  (playable[i].lengthMs ?? 0) > 0
                ? playable[i].lengthMs! / 1000.0
                : null,
            formatExt:  ext,
            source:     'local',
            isFavorite: false,
            inLibrary:  false,
            playCount:  0,
          ),
      ];
    }
  }

  // Fichier simple.
  //
  // ⚠️ **La ligne DÉJÀ EN BASE gagne sur celle qu'on fabriquerait.** Elle porte
  // le titre du catalogue, l'artiste, l'album, l'`online_id`, la pochette — et
  // la ligne fabriquée ci-dessous ne porte que le NOM DU FICHIER. Or ce qui est
  // joué est ensuite PERSISTÉ (`_persistPlay` réécrit la ligne avec le libellé
  // qui a lancé la lecture): ouvrir par CHEMIN un fichier que la base connaît
  // le DÉGRADAIT en base. Mesuré sur « Axelay » (jw_spc): « Set Up » est
  // devenu « 02 Set Up » et l'album a disparu du lecteur — une fois par piste
  // ouverte ainsi. La branche conteneur juste au-dessus réutilise déjà les
  // lignes connues, pour une raison voisine; celle-ci ne le faisait pas.
  //
  // Vaut pour TOUS les chemins par chemin: dépôt sur la fenêtre, sélecteur,
  // navigateur local.
  final known = await knownFor(path);
  for (final t in known) {
    if (t.subsongIdx == 0 && t.entryPath.isEmpty) {
      return [t.formatExt == null ? t.copyWith(formatExt: ext) : t];
    }
  }
  return [
    TrackRecord(
      id:         '',
      filePath:   path,
      entryPath:  '',
      subsongIdx: 0,
      title:      base,
      formatExt:  ext,
      source:     'local',
      isFavorite: false,
      inLibrary:  false,
      playCount:  0,
    ),
  ];
}

/// [tracksForLocalPath] over several paths, concatenated in the given order.
///
/// Order is the caller's: a Finder multi-selection arrives in the order the
/// user picked, and a drop keeps it. Unreadable paths are skipped rather than
/// aborting the batch — dropping ten files and getting nothing because the
/// third is a .txt would be the wrong trade.
Future<List<TrackRecord>> tracksForLocalPaths(
  List<String> paths, {
  required PlayerController controller,
  LocalOpenReporter? report,
  bool? filterCandidates,
}) async {
  // Ouverture en LOT (tout sélectionner, dépôt multiple): écarter ce qui n'a
  // rien à faire dans une file. Un chemin UNIQUE passe tel quel — voir
  // isBulkQueueCandidate pour pourquoi le filtre ne s'applique pas là.
  //
  // [filterCandidates] force la décision: un DÉPÔT filtre toujours, même à un
  // seul fichier. Poser une pochette sur la fenêtre n'est pas « ouvre ce
  // fichier-ci », c'est un geste large qui attrape ce qui passe — alors qu'un
  // sélecteur, lui, DÉSIGNE. Sans ça, un `.jpg` déposé seul devenait une piste
  // et allait jusqu'à faire apparaître la feuille « Lire maintenant ».
  final filter = filterCandidates ?? paths.length > 1;
  final kept = filter
      ? paths
          .where((path) =>
              // Un DOSSIER n'est pas jugé ici: il est parcouru plus bas, et
              // c'est son CONTENU qui est filtré.
              FileSystemEntity.isDirectorySync(path) ||
              isBulkQueueCandidate(path, canPlay: controller.audio.canPlay))
          .toList()
      : paths;
  if (kept.isEmpty && paths.isNotEmpty) {
    report?.call(LocalOpenNotice.nothingPlayable);
    return const [];
  }
  final out = <TrackRecord>[];
  // UNE requête pour les lignes connues de tout le lot et une mémoire des M3U
  // par dossier — au lieu d'une requête et d'un listage de dossier par fichier.
  final batch = await LocalOpenBatch.prepare(
      [for (final p in kept) if (!FileSystemEntity.isDirectorySync(p)) p]);
  for (final p in kept) {
    try {
      out.addAll(await tracksForLocalPath(p,
          controller: controller, report: report, batch: batch));
    } catch (_) {/* skip this one, keep the batch */}
  }
  return out;
}

/// Expands each extracted archive module into its subsongs so a picked archive
/// plays EVERY subsong, not just the first of each multi-subsong module.
/// TFMX/FC/… resolve via the UADE songdb (md5 lookup); NSF/GBS/SID/… via the
/// native probe. Single-subsong modules stay one entry.
Future<List<TrackRecord>> expandLocalModules(
    List<TrackRecord> recs, PlayerController controller) async {
  // Warm the UADE songdb cache in one batch so the per-file forPath() calls
  // below hit the cache instead of N serial round-trips.
  await UadeInfoService.instance
      .prefetchPaths([for (final r in recs) r.filePath]);
  // Les modules extraits partagent UN dossier: sans mémoire, chacun le
  // relistait pour y chercher son M3U.
  final m3uCache = M3uLookupCache();

  final out = <TrackRecord>[];
  for (final r in recs) {
    final path = r.filePath;
    final ext  = (r.formatExt ?? '').toLowerCase();
    final name = r.title ?? path.split(Platform.pathSeparator).last;
    // Song base name for the "<base> – N" subsong titles. Amiga prefix-form
    // ("mdat.Turrican_2") → the part AFTER the format token; suffix-form
    // ("song.tfmx") → the part before the extension.
    final base = name.toLowerCase().startsWith('$ext.')
        ? name.substring(ext.length + 1)
        : name.replaceAll(RegExp(r'\.\w+$'), '');

    // UADE multi-subsong (audacious-uade songdb).
    if (UadeInfoService.isUadeFileAt(path)) {
      final info = await UadeInfoService.instance.forPath(path);
      // NOSOUND slots filtered out — see UadeInfo.playableSubsongs.
      final playable = info?.playableSubsongs ?? const [];
      if (info != null && info.subsongCount > 1 && playable.length > 1) {
        for (var i = 0; i < playable.length; i++) {
          out.add(TrackRecord(
            id: '', filePath: path, entryPath: '',
            subsongIdx: playable[i].idx,
            title: '$base (${i + 1})',
            metaAlbum: r.metaAlbum,
            artist: info.authors.isEmpty ? null : info.authors.join(', '),
            durationS: (playable[i].lengthMs ?? 0) > 0
                ? playable[i].lengthMs! / 1000.0
                : null,
            formatExt: ext, source: 'local',
            isFavorite: false, inLibrary: false, playCount: 0,
          ));
        }
        continue;
      }
      out.add(r);
      continue;
    }

    // Native multi-track container (NSF/GBS/SID/…).
    if (kMultiTrackExts.contains(ext)) {
      // Le M3U de l'archive: extrait à côté du module, il nomme les morceaux
      // et ne liste que les vrais. Il était simplement ignoré — un `.zip`
      // GBgbs jouait ses cases mortes sous des titres numérotés.
      final fromM3u =
          await m3uSubsongsFor(path, album: r.metaAlbum, m3uCache: m3uCache);
      if (fromM3u != null) {
        out.addAll(fromM3u);
        continue;
      }
      // Puis les titres que porte le fichier lui-même.
      final fromEngine =
          engineSubsongsFor(path, controller, album: r.metaAlbum);
      if (fromEngine != null) {
        out.addAll(fromEngine);
        continue;
      }
      final count = controller.audio.probeSubsongCount(path);
      if (count > 1) {
        for (var i = 0; i < count; i++) {
          out.add(TrackRecord(
            id: '', filePath: path, entryPath: '', subsongIdx: i,
            title: '$base (${i + 1})', metaAlbum: r.metaAlbum,
            formatExt: ext, source: 'local',
            isFavorite: false, inLibrary: false, playCount: 0,
          ));
        }
        continue;
      }
    }
    out.add(r);
  }
  return out;
}

/// Ordre de lecture d'un conteneur qui DÉSIGNE son sous-chant de départ.
///
/// Beaucoup de fichiers ouvrent sur un bruitage ou un jingle et nomment dans
/// leur en-tête le vrai premier morceau (`startSong` d'un SID, `DEFSONG` d'un
/// SAP; le serveur les rend en 0-based dense sous `default_subsong`). « Tout
/// lire » doit alors commencer là — et ne pas PERDRE ce qui précède: on fait
/// TOURNER la liste. Cinq pistes, défaut sur la 3e ⇒ 3, 4, 5, 1, 2.
///
/// Une rotation plutôt qu'un simple `startIndex`: la file doit finir par ce
/// qu'on a sauté, sinon un « tout lire » ne joue pas tout. Et une rotation
/// plutôt qu'un tri: l'ordre relatif reste celui du fichier.
///
/// [defaultIdx] est un INDEX DANS LA LISTE, pas un index de sous-chanson —
/// c'est à l'appelant de faire la correspondance (les deux diffèrent dès
/// qu'un slot muet est retiré, cas UADE). null ou hors bornes ⇒ liste
/// inchangée, jamais une erreur.
List<T> rotateToDefaultSubsong<T>(List<T> items, int? defaultIdx) {
  if (defaultIdx == null || defaultIdx <= 0 || defaultIdx >= items.length) {
    return items;
  }
  return [...items.sublist(defaultIdx), ...items.sublist(0, defaultIdx)];
}

/// Ce qu'un geste d'ouverture précharge UNE fois pour tous ses fichiers.
///
/// Sans lui, chaque fichier d'un « Tout lire » posait sa requête `tracks` et
/// relistait son dossier pour y chercher un M3U — en série. La requête coûte
/// 0,02 ms, mais sqflite n'a qu'une file: 185 fichiers = 185 attentes derrière
/// ce que l'app fait au même moment. Mesuré: 5,2 s de résolution pour 185
/// MIDIs, jusqu'à 197 ms pour un seul.
class LocalOpenBatch {
  LocalOpenBatch._(this._covered, this.known, this.m3u);

  /// Les chemins dont [known] fait autorité: un chemin couvert et ABSENT de
  /// [known] n'a aucune ligne; un chemin non couvert se demande à la base.
  final Set<String> _covered;

  /// Lignes `tracks` par chemin.
  final Map<String, List<TrackRecord>> known;

  /// Listages de dossiers et M3U déjà lus pendant ce geste.
  final M3uLookupCache m3u;

  bool covers(String path) => _covered.contains(path);

  static Future<LocalOpenBatch> prepare(List<String> files,
      {M3uLookupCache? m3u}) async {
    // Un sous-dossier HÉRITE de la mémoire M3U du geste qui le contient.
    final cache = m3u ?? M3uLookupCache();
    try {
      final known = await LocalDb.instance.getTracksForFiles(files);
      return LocalOpenBatch._(files.toSet(), known, cache);
    } catch (_) {
      // Base indisponible: rien n'est « couvert », chaque fichier retombe
      // sur sa requête individuelle — plus lent, jamais faux.
      return LocalOpenBatch._(const {}, const {}, cache);
    }
  }
}
