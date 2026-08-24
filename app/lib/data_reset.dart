import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rewamp_db.dart';

/// Remise à zéro des données locales, DÉCLENCHÉE PAR UNE VERSION.
///
/// Une beta accumule des états qu'aucune migration ne peut plus décrire: bases
/// écrites par des schémas intermédiaires jamais publiés, téléchargements
/// rangés selon d'anciennes règles de chemin, réglages d'un moteur qui a
/// changé de nom. Plutôt que d'écrire des réparations pour des états que
/// personne n'aura en production, on repart d'un appareil propre au premier
/// lancement de la version.
///
/// **Bumper ce nombre = effacer une fois, au prochain démarrage, sur chaque
/// appareil qui installe la nouvelle build.** L'estampille est un FICHIER (pas
/// une préférence: les préférences font partie de ce qui est effacé).
///
/// Ce qui SURVIT, et c'est l'essentiel: le compte. L'uuid et le jeton vivent
/// dans le trousseau / EncryptedSharedPreferences, jamais dans les
/// préférences — l'appareil redémarre donc « neuf mais connecté », et la
/// synchro reconstruit bibliothèque, favoris et playlists depuis le compte.
/// C'est exactement le parcours qu'on veut voir s'exécuter en beta.
const kDataResetVersion = 3;

/// Clés de préférence épargnées par l'effacement.
///
/// `user.id` est le repli en clair de l'identifiant de compte, écrit seulement
/// quand le stockage sécurisé est indisponible (Linux sans libsecret,
/// entitlement manquant). L'effacer déconnecterait justement les appareils qui
/// n'ont pas de trousseau pour s'en souvenir.
const _kPreservedPrefs = <String>{'user.id'};

/// Vrai quand le dernier appel à [maybeResetLocalData] a réellement effacé
/// quelque chose. Une PREMIÈRE installation passe par la même passe (aucune
/// estampille) sans rien avoir à supprimer: elle ne doit pas se voir annoncer
/// une perte de données qui n'a pas eu lieu (voir release_notes.dart).
bool dataWasReset = false;

/// Efface les données locales si [kDataResetVersion] a changé depuis le dernier
/// lancement. Retourne true si un effacement a eu lieu.
///
/// À appeler dans `main()` AVANT `LocalDb.initialize()` et `UserSettings.init()`
/// — la base doit être supprimée avant d'être ouverte (sinon on efface un
/// fichier que sqflite tient déjà, et les préférences seraient relues en
/// mémoire avant d'être vidées).
Future<bool> maybeResetLocalData() async {
  final support = await getApplicationSupportDirectory();
  final stamp   = File(p.join(support.path, '.data_reset'));

  try {
    if (await stamp.exists() &&
        (await stamp.readAsString()).trim() == '$kDataResetVersion') {
      return false;
    }
  } catch (_) {
    // Estampille illisible: on traite comme une version différente. Effacer
    // une fois de trop est réparable, garder un état incohérent ne l'est pas.
  }

  // La base est le témoin d'un usage antérieur: sans elle, l'appareil n'a
  // jamais lancé l'app et la passe qui suit ne fera que poser l'estampille.
  final dbPath = p.join(support.path, 'rewamp_local.db');
  dataWasReset = await File(dbPath).exists();

  debugPrint('[data-reset] version $kDataResetVersion — '
      '${dataWasReset ? "effacement des données locales "
          "(le compte est conservé)" : "première installation, rien à effacer"}');

  // 1. La base SQLite et ses fichiers annexes. Supprimer le `.db` seul laisse
  //    un WAL qui sera rejoué sur la base neuve: sqflite rouvre alors une base
  //    à moitié ancienne, au schéma d'hier.
  await _deleteFile(dbPath);
  for (final ext in ['-wal', '-shm', '-journal']) {
    await _deleteFile(p.join(support.path, 'rewamp_local.db$ext'));
  }

  // 2. Queue persistée + drapeau de crash (QueuePersistence).
  await _deleteFile(p.join(support.path, 'queue_state.json'));
  await _deleteFile(p.join(support.path, 'loading.flag'));

  // 3. Pochettes génériques recopiées pour le centre de contrôle système.
  await _deleteDir(p.join(support.path, 'media_art'));

  // 4. SoundFonts téléchargées. Le slug choisi est une préférence, donc effacé
  //    juste après: garder les fichiers laisserait des dizaines de Mo orphelins
  //    que plus rien ne désigne.
  await _deleteDir(p.join(support.path, 'rewamp_data', 'soundfonts'));

  // 4bis. Presets projectM NON embarqués: packs serveur, bundles de textures,
  //    téléchargements unitaires, imports. Les playlists partent avec la base,
  //    la source choisie (`vis.pm_source`) avec les préférences — garder les
  //    fichiers laisserait des dizaines de Mo que plus rien ne désigne.
  //    `projectm/{presets,textures}` (le bundle) n'est PAS touché: recopié au
  //    démarrage.
  for (final d in ['packs', 'packtex', 'single', 'user']) {
    await _deleteDir(p.join(support.path, 'rewamp_data', 'projectm', d));
  }

  // 5. Tous les téléchargements. Le reste de `rewamp_data/` (score UADE,
  //    replays sc68, presets projectM embarqués) est du contenu EMBARQUÉ,
  //    recopié au démarrage — l'effacer ne ferait que rallonger le lancement.
  try {
    await RewampDb.deleteOnlineLibrary();
  } catch (e) {
    debugPrint('[data-reset] online/: $e');
  }

  // 6. Les préférences, sauf le repli d'identifiant de compte.
  try {
    final prefs    = await SharedPreferences.getInstance();
    final rescued = <String, String>{};
    for (final k in _kPreservedPrefs) {
      final v = prefs.getString(k);
      if (v != null) rescued[k] = v;
    }
    await prefs.clear();
    for (final e in rescued.entries) {
      await prefs.setString(e.key, e.value);
    }
  } catch (e) {
    debugPrint('[data-reset] préférences: $e');
  }

  try {
    await stamp.parent.create(recursive: true);
    await stamp.writeAsString('$kDataResetVersion', flush: true);
  } catch (e) {
    // Sans estampille l'effacement se répéterait à CHAQUE lancement, ce qui
    // est bien pire qu'un effacement manqué: on le dit fort.
    debugPrint('[data-reset] ÉCHEC de l\'écriture de l\'estampille: $e');
  }
  return true;
}

Future<void> _deleteFile(String path) async {
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (e) {
    debugPrint('[data-reset] $path: $e');
  }
}

Future<void> _deleteDir(String path) async {
  try {
    final d = Directory(path);
    if (await d.exists()) await d.delete(recursive: true);
  } catch (e) {
    debugPrint('[data-reset] $path: $e');
  }
}
