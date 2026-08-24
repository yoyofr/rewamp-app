import 'dart:async';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:rewamp_audio/rewamp_audio.dart';

import 'rewamp_db.dart' show RemoteAsset, RewampDb;
import 'user_settings.dart';

/// Manages the SF2 SoundFonts used by the MIDI (FluidLite) plugin.
///
/// Files live in `<datadir>/soundfonts/<slug>.sf2` (the same datadir the
/// native engine got via setDataDir, so the plugin's default.sf2 fallback
/// stays in the same folder). Catalogue = server `list_assets('soundfont')`;
/// downloads are sha256-verified. The selected slug is persisted in
/// UserSettings and applied via setMidiSoundfont.
class SoundfontManager {
  SoundfontManager._();
  static final SoundfontManager instance = SoundfontManager._();

  late String _dir;          // <datadir>/soundfonts
  RewampAudio? _audio;

  /// Per-slug download progress (0..1), null when idle. UI listens per row.
  final ValueNotifier<Map<String, double>> progress = ValueNotifier(const {});

  /// [audio] nullable pour être testable hors de l'app: le moteur natif n'est
  /// pas là dans l'hôte de test Dart (le seul lookup FFI ferait échouer la
  /// construction), et rien ici n'en a besoin avant une sélection.
  void init(String dataDir, RewampAudio? audio) {
    _dir   = '$dataDir/soundfonts';
    _audio = audio;
  }

  String pathFor(String slug) => '$_dir/$slug.sf2';

  /// Préfixe des soundfonts IMPORTÉES par l'utilisateur. Il les sépare des
  /// slugs du catalogue serveur, qui vivent dans le même dossier et se
  /// sélectionnent de la même façon: sans lui, une importation nommée comme
  /// une entrée du catalogue écraserait celle-ci en silence.
  static const String kLocalPrefix = 'local-';

  static bool isLocalSlug(String slug) => slug.startsWith(kLocalPrefix);

  /// Le NOM affiché d'une importation vit dans un fichier voisin: un slug est
  /// aplati (ascii, minuscules) et ne peut pas rendre « Arachno SoundFont
  /// – Version 1.0 ».
  String _namePathFor(String slug) => '$_dir/$slug.name';

  bool isInstalled(String slug) => File(pathFor(slug)).existsSync();

  Future<List<RemoteAsset>> catalogue() => RewampDb.listAssets('soundfont');

  /// Applies the persisted selection at startup (no network). Falls back to
  /// the native default (<datadir>/soundfonts/default.sf2) when nothing is
  /// selected/installed, then kicks a silent download of the server-default
  /// soundfont if NO soundfont at all is present.
  Future<void> applyStartup() async {
    final slug = UserSettings.instance.midiSoundfont;
    if (slug != null && isInstalled(slug)) {
      _audio?.setMidiSoundfont(pathFor(slug));
      return;
    }
    if (File('$_dir/default.sf2').existsSync()) return; // manual install
    // Nothing installed: fetch the catalogue default in the background so
    // .mid files work out of the box. Failures are silent (offline, …).
    try {
      final assets = await catalogue();
      final def = assets.where((a) => a.isDefault).firstOrNull ??
          (assets.isEmpty ? null : assets.first);
      if (def == null || isInstalled(def.slug)) return;
      await download(def);
      await select(def.slug);
    } catch (e) {
      debugPrint('[soundfont] startup default download skipped: $e');
    }
  }

  /// Selects an installed soundfont (persists + applies immediately).
  Future<void> select(String slug) async {
    if (!isInstalled(slug)) return;
    UserSettings.instance.midiSoundfont = slug;
    _audio?.setMidiSoundfont(pathFor(slug));
  }

  /// Downloads [asset] with progress + sha256 verification.
  Future<void> download(RemoteAsset asset) async {
    _setProgress(asset.slug, 0);
    final client = http.Client();
    try {
      final resp = await client
          .send(http.Request('GET', Uri.parse(asset.url)))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final total   = resp.contentLength ?? asset.sizeBytes;
      final builder = BytesBuilder(copy: false);
      await for (final chunk
          in resp.stream.timeout(const Duration(seconds: 30))) {
        builder.add(chunk);
        if (total > 0) _setProgress(asset.slug, builder.length / total);
      }
      final bytes = builder.takeBytes();

      if (asset.sha256 != null && asset.sha256!.isNotEmpty) {
        final digest = sha256.convert(bytes).toString();
        if (digest.toLowerCase() != asset.sha256!.toLowerCase()) {
          throw Exception('sha256 mismatch (got $digest)');
        }
      }

      final f = File(pathFor(asset.slug));
      await f.parent.create(recursive: true);
      await f.writeAsBytes(bytes, flush: true);
    } finally {
      client.close();
      _setProgress(asset.slug, null);
    }
  }

  /// Les soundfonts importées présentes sur l'appareil, triées par nom.
  /// Lue à chaque affichage: le dossier fait autorité, pas un index qu'il
  /// faudrait tenir à jour.
  List<LocalSoundfont> localFonts() {
    final dir = Directory(_dir);
    if (!dir.existsSync()) return const [];
    final out = <LocalSoundfont>[];
    for (final e in dir.listSync()) {
      if (e is! File) continue;
      final base = p.basename(e.path);
      if (!base.startsWith(kLocalPrefix) || !base.endsWith('.sf2')) continue;
      final slug = base.substring(0, base.length - 4);
      String name = slug.substring(kLocalPrefix.length);
      try {
        final n = File(_namePathFor(slug));
        if (n.existsSync()) name = n.readAsStringSync().trim();
      } catch (_) {/* le repli sur le slug suffit */}
      var size = 0;
      try {
        size = e.lengthSync();
      } catch (_) {}
      out.add(LocalSoundfont(slug: slug, name: name, sizeBytes: size));
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  /// Importe une soundfont choisie par l'utilisateur et rend son slug.
  ///
  /// COPIÉE dans `<datadir>/soundfonts`, jamais référencée là où elle a été
  /// prise: sur iOS le chemin rendu par le sélecteur est une copie de bac à
  /// sable qui ne survit pas à la session, et ailleurs l'utilisateur peut
  /// déplacer son fichier. Une fois copiée elle vit comme n'importe quelle
  /// entrée du catalogue — même sélection, même suppression.
  Future<String> importLocal(String srcPath) async {
    final src = File(srcPath);
    if (!await src.exists()) {
      throw const FormatException('file not found');
    }
    // En-tête RIFF….sfbk. Un fichier qui n'en est pas un ne fait pas ÉCHOUER
    // FluidLite bruyamment: il donne un synthé MUET, c'est-à-dire un bug qui
    // se présente comme « le MIDI ne marche plus », loin de ce geste-ci.
    final raf = await src.open();
    List<int> head;
    try {
      head = await raf.read(12);
    } finally {
      await raf.close();
    }
    if (head.length < 12 ||
        String.fromCharCodes(head.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(head.sublist(8, 12)) != 'sfbk') {
      throw const FormatException('not a SoundFont 2 file');
    }

    final name = p.basenameWithoutExtension(srcPath);
    var slug = '$kLocalPrefix${_slugify(name)}';
    // Deux fichiers de même nom pris dans deux dossiers: on ne remplace pas
    // en silence celui qui est déjà là.
    if (File(pathFor(slug)).existsSync()) {
      var n = 2;
      while (File(pathFor('$slug-$n')).existsSync()) {
        n++;
      }
      slug = '$slug-$n';
    }
    await Directory(_dir).create(recursive: true);
    // copy(), pas readAsBytes()+write: une soundfont pèse couramment des
    // centaines de mégaoctets et n'a aucune raison de passer par la RAM.
    await src.copy(pathFor(slug));
    try {
      await File(_namePathFor(slug)).writeAsString(name, flush: true);
    } catch (_) {/* le nom affiché retombera sur le slug */}
    return slug;
  }

  static String _slugify(String s) {
    final out = StringBuffer();
    for (final c in s.toLowerCase().runes) {
      final ch = String.fromCharCode(c);
      if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
        out.write(ch);
      } else if (out.isNotEmpty && !out.toString().endsWith('-')) {
        out.write('-');
      }
    }
    final r = out.toString().replaceAll(RegExp(r'-+$'), '');
    return r.isEmpty ? 'soundfont' : r;
  }

  Future<void> delete(String slug) async {
    final f = File(pathFor(slug));
    if (await f.exists()) await f.delete();
    final n = File(_namePathFor(slug));
    if (await n.exists()) await n.delete();
    if (UserSettings.instance.midiSoundfont == slug) {
      UserSettings.instance.midiSoundfont = null;
      _audio?.setMidiSoundfont('');
    }
  }

  void _setProgress(String slug, double? v) {
    final m = Map<String, double>.from(progress.value);
    if (v == null) {
      m.remove(slug);
    } else {
      m[slug] = v;
    }
    progress.value = m;
  }
}

/// Une soundfont importée par l'utilisateur, telle qu'affichée dans les
/// réglages.
class LocalSoundfont {
  final String slug;
  final String name;
  final int sizeBytes;
  const LocalSoundfont(
      {required this.slug, required this.name, required this.sizeBytes});
}
