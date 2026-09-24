import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'local_db.dart';

/// Le dossier `<support>/opened/` — les fichiers que l'utilisateur a fait
/// ENTRER dans l'app: « Ouvrir avec », partage, et (sur mobile) le sélecteur.
///
/// Pourquoi il existe: sur iOS et Android, un fichier choisi au sélecteur est
/// une COPIE dans un cache que le système purge quand il veut, et un fichier
/// « en place » n'est lisible que sous une portée de sécurité qui ne couvre
/// jamais ses COMPAGNONS (le `.gsflib` d'un `.minigsf`, les entrées d'un M3U,
/// la banque d'un `mdat.`). Nos 38 décodeurs C partagent une seule interface —
/// un chemin dans un vrai dossier — et ce dossier-ci la matérialise: les
/// fichiers d'un même geste y atterrissent côte à côte, sous des chemins qui
/// survivent au relancement. C'est ce qui rend une PLAYLIST d'entrées locales
/// fiable sur mobile.
///
/// Règles du dossier:
/// - exclu de la sauvegarde iCloud (côté natif): l'utilisateur possède déjà
///   ces fichiers ailleurs;
/// - purgé par L'APP, jamais par le système — et la purge ÉPARGNE tout ce que
///   la base référence encore (playlist, bibliothèque, favori);
/// - VISIBLE: l'écran Réglages → Stockage le liste fichier par fichier, avec
///   suppression. La purge automatique est un filet, pas le mécanisme.
class OpenedFiles {
  OpenedFiles._();

  static Future<Directory> dir() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'opened'));
  }

  /// Recopie [paths] dans le dossier et rend les chemins STABLES.
  ///
  /// Desktop rend les chemins tels quels: le sélecteur y donne le VRAI chemin
  /// du fichier de l'utilisateur, et le dupliquer ferait de sa bibliothèque une
  /// copie fantôme. Le problème que la copie résout — un chemin de cache
  /// périssable — n'existe que sur mobile.
  ///
  /// Même nom = remplacement: rouvrir le même fichier ne doit pas empiler
  /// `chanson (1).sid`, et un fichier RE-choisi est la version que l'utilisateur
  /// veut. Deux fichiers différents portant le même nom dans le même geste
  /// restent distincts (suffixe numérique).
  static Future<List<String>> materialise(List<String> paths) async {
    if (!Platform.isIOS && !Platform.isAndroid) return paths;
    final d = await dir();
    await d.create(recursive: true);
    final out = <String>[];
    final claimed = <String>{};
    for (final src in paths) {
      final f = File(src);
      if (!await f.exists()) continue;
      var name = p.basename(src);
      if (!claimed.add(name.toLowerCase())) {
        final stem = p.basenameWithoutExtension(name);
        final ext = p.extension(name);
        var i = 2;
        while (!claimed.add('$stem ($i)$ext'.toLowerCase())) {
          i++;
        }
        name = '$stem ($i)$ext';
      }
      final dest = p.join(d.path, name);
      try {
        if (dest != src) await f.copy(dest);
        out.add(dest);
      } catch (_) {
        // Copie impossible (disque plein…): on joue depuis le cache du
        // sélecteur plutôt que de perdre le geste — le fichier est là, il est
        // juste périssable.
        out.add(src);
      }
    }
    return out;
  }

  /// Recopie un DOSSIER entier et rend le chemin stable de la copie.
  ///
  /// Même raison que [materialise], et une de plus: sur iOS la portée de
  /// sécurité d'un dossier choisi meurt à la fin de l'appel du sélecteur (voir
  /// withPickedFolder), donc la copie doit se faire PENDANT — et lire hors
  /// portée ne lève pas, ça rend une liste VIDE. L'arborescence est PRÉSERVÉE:
  /// un module Amiga trouve ses compagnons à côté de lui, et un M3U ses
  /// entrées au chemin relatif qu'il écrit.
  ///
  /// Desktop rend le chemin tel quel (le sélecteur y donne le vrai dossier).
  /// Un dossier du même nom déjà là est REMPLACÉ: rejouer un dossier doit
  /// jouer ce qu'il contient MAINTENANT, pas un mélange avec l'ancien.
  static Future<String> materialiseFolder(String path) async {
    if (!Platform.isIOS && !Platform.isAndroid) return path;
    final d = await dir();
    final dest = Directory(p.join(d.path, p.basename(path)));
    if (await dest.exists()) await dest.delete(recursive: true);
    await dest.create(recursive: true);
    try {
      await for (final e
          in Directory(path).list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        final out = File(p.join(dest.path, p.relative(e.path, from: path)));
        await out.parent.create(recursive: true);
        await e.copy(out.path);
      }
    } catch (_) {
      // Copie partielle: on joue ce qui est arrivé plutôt que de perdre le
      // geste — le dossier reste visible dans Réglages → Stockage.
    }
    return dest.path;
  }

  /// Chemins du dossier que la base référence ENCORE — ceux que ni la purge ni
  /// « tout supprimer » ne doivent toucher.
  ///
  /// Référencé = dans une playlist, en bibliothèque ou en favori. Une simple
  /// ligne `tracks` ne suffit PAS: chaque fichier joué en a une, l'exemption
  /// couvrirait tout. Les récents meurent donc avec la purge — c'est le cas
  /// « fichier manquant », déjà géré et affiché comme tel.
  static Future<Set<String>> referencedPaths() async {
    final rows = await LocalDb.instance.rawQuery('''
      SELECT DISTINCT t.file_path FROM tracks t
      WHERE t.id IN (SELECT track_id FROM playlist_tracks
                     WHERE track_id IS NOT NULL)
         OR t.is_favorite = 1
         OR t.in_library = 1
         OR t.id IN (SELECT ref_id FROM library_items)
         OR (t.online_id IS NOT NULL AND
             t.online_id IN (SELECT ref_id FROM library_items))
    ''');
    final d = await dir();
    final prefix = '${d.path}${Platform.pathSeparator}';
    return {
      for (final r in rows)
        if ((r['file_path'] as String?)?.startsWith(prefix) ?? false)
          r['file_path'] as String,
    };
    // Les file_path/rel_path que playlist_tracks garde en SNAPSHOT (entrée
    // déliée) ne sont pas couverts exprès: une entrée déliée est déjà
    // « manquante » à l'affichage, la garder sur disque ne la relierait pas.
  }

  /// Filet: efface ce qui a plus de [maxAge] ET n'est pas référencé.
  ///
  /// En DART et non côté natif: seul Dart peut interroger la base, et une purge
  /// qui ignore les références aurait tué les playlists qu'on vient de rendre
  /// possibles. Appelée au démarrage, après l'ouverture de la base.
  static Future<void> prune({Duration maxAge = const Duration(days: 30)}) async {
    try {
      final d = await dir();
      if (!await d.exists()) return;
      final keep = await referencedPaths();
      final cutoff = DateTime.now().subtract(maxAge);
      await for (final e in d.list()) {
        if (e is! File) continue;
        if (keep.contains(e.path)) continue;
        try {
          final stat = await e.stat();
          if (stat.modified.isBefore(cutoff)) await e.delete();
        } catch (_) {}
      }
    } catch (_) {/* le filet ne doit jamais casser un démarrage */}
  }
}
