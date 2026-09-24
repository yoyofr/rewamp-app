// Suppression de fichiers locaux — la partie PARTAGÉE entre les deux arbres
// du navigateur Local: les IMPORTS (`<support>/local/`) et les
// TÉLÉCHARGEMENTS (`<documents>/online/`).
//
// Les deux gestes effacent la même chose autour de la piste — compagnons,
// pochette voisine, dossiers devenus vides — et la règle qui décide qu'un
// compagnon PART ou RESTE (`localImportCompanionClaims`) n'a rien d'un détail:
// `X.mid` et `X.vgz` partagent `X.jpg`, `smpl.Y` sert `mdat.Y`. En écrire deux
// copies, c'était garantir qu'elles divergent.
//
// ⚠️ Ce qu'ils NE partagent PAS, et c'est volontaire: un import supprimé quitte
// aussi la BIBLIOTHÈQUE et le compte (c'est le fichier de l'utilisateur, il
// n'existe nulle part ailleurs), tandis qu'un téléchargement supprimé ne libère
// que de la PLACE — son entrée reste, le catalogue le re-téléchargera. C'est
// déjà le contrat de Réglages → Données → Stockage.

import 'dart:io';

import 'package:path/path.dart' as p;

import 'local_import.dart'
    show localAudioFormatOf, localImportCompanionClaims;
import 'player_controller.dart' show PlayerController;
import 'rewamp_db.dart';

/// Ménage des COMPAGNONS après la suppression d'une piste: un compagnon que la
/// piste supprimée revendiquait part avec elle — SAUF s'il est PARTAGÉ, c'est-
/// à-dire encore revendiqué par une piste restante du dossier. Quand plus
/// AUCUNE piste ne reste, le reste (pochette générique, `.m3u`, notes,
/// marqueur `.import_src`) a fini sa vie aussi, et les dossiers vides sont
/// élagués jusqu'à [root], exclue.
Future<void> cleanCompanionsAfterDelete(String dir, String deletedBase,
    {required String root, bool prune = true}) async {
  try {
    final entries = <String>[];
    await for (final e in Directory(dir).list(followLinks: false)) {
      if (e is File) entries.add(e.path);
    }
    final remainingAudio = [
      for (final f in entries)
        if (localAudioFormatOf(f) != null) p.basename(f),
    ];
    for (final f in entries) {
      if (localAudioFormatOf(f) != null) continue;
      final base = p.basename(f);
      final shared =
          remainingAudio.any((a) => localImportCompanionClaims(a, base));
      if (shared) continue;
      if (localImportCompanionClaims(deletedBase, base) ||
          remainingAudio.isEmpty) {
        try {
          await File(f).delete();
        } catch (_) {}
      }
    }
    if (prune && remainingAudio.isEmpty) await pruneEmptyDirs(dir, root: root);
  } catch (_) {}
}

/// Élague les dossiers VIDES en remontant vers [root] (exclue).
///
/// ⚠️ **Pour l'arbre des TÉLÉCHARGEMENTS seulement.** Dans `online/`, un
/// dossier n'existe que pour porter un album: vidé, c'est un résidu, et le
/// laisser garde des branches mortes dans le navigateur.
///
/// Dans l'arbre des IMPORTS, un dossier est un objet que l'utilisateur CRÉE et
/// range (voir local_manage.dart): l'effacer parce qu'il s'est vidé, c'est
/// défaire son geste. Créer `test`, y créer `test2`, supprimer `test2` — et
/// `test` disparaissait aussi. C'est la frontière déjà posée pour le
/// renommage et le déplacement: `online/` appartient à l'app, `local/` à
/// l'utilisateur.
Future<void> pruneEmptyDirs(String dirPath, {required String root}) async {
  var cur = Directory(dirPath);
  while (p.isWithin(root, cur.path)) {
    try {
      if (!await cur.list(followLinks: false).isEmpty) return;
      await cur.delete();
    } catch (_) {
      return;
    }
    cur = cur.parent;
  }
}

/// Supprime UN fichier TÉLÉCHARGÉ: lecture en cours et file d'abord, puis le
/// fichier et ses lignes locales, puis les compagnons que plus personne ne
/// revendique.
///
/// ⚠️ L'ordre n'est pas cosmétique: `handleDeletedTrack` RÉSOUT quelles entrées
/// de file meurent, et cette résolution lit des lignes et un fichier que la
/// suppression va emporter.
///
/// L'entrée de BIBLIOTHÈQUE est laissée en place — voir l'en-tête: un
/// téléchargement se re-télécharge, contrairement à un import.
Future<void> deleteDownloadedTrack(String filePath) async {
  await PlayerController.current?.handleDeletedTrack(filePath);
  await RewampDb.deleteLocalTrack(filePath);
  await cleanCompanionsAfterDelete(
      p.dirname(filePath), p.basename(filePath),
      root: await RewampDb.onlineLibraryDir());
}

/// Supprime un DOSSIER téléchargé (sous-arbre entier: audio, pochettes, `.m3u`,
/// fichiers extraits) et toutes les lignes locales qui vivent dessous.
///
/// Le dossier part d'un bloc — donc pas de ménage de compagnons à faire — mais
/// les dossiers PARENTS devenus vides sont élagués, sinon l'arbre du navigateur
/// garde des branches mortes.
Future<void> deleteDownloadedFolder(String dirPath) async {
  await PlayerController.current?.handleDeletedAlbum(dirPath);
  await RewampDb.deleteLocalAlbumDir(dirPath);
  await pruneEmptyDirs(p.dirname(dirPath),
      root: await RewampDb.onlineLibraryDir());
}
