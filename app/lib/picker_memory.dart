// Le DERNIER dossier de chaque sélecteur de fichiers, retenu d'une ouverture
// à l'autre.
//
// Sans lui le panneau s'ouvrait TOUJOURS sur le défaut du système (le home
// sur macOS), quel que soit l'endroit d'où l'on venait d'importer. Le dossier
// se retient par USAGE — la musique ne se range pas avec les ROM MT-32 ni avec
// les sauvegardes — et un dossier qui n'existe plus (disque démonté, dossier
// renommé ou supprimé) rend null: le sélecteur retombe alors sur son défaut.
//
// Bureau seulement (macOS, Linux, Windows). Sur Android le chemin rendu est
// une COPIE de cache, dont le dossier ne dit rien de l'endroit choisi — le
// point de départ y reste `androidPickerStartDir`; iOS ignore le dossier
// initial. ⚠️ Pas de repli sur `$HOME`: dans le bac à sable macOS il désigne
// le CONTENEUR de l'app, pas le home de l'utilisateur.

import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

enum PickerSlot { music, presets, mt32Roms, soundfont, backup }

class PickerMemory {
  PickerMemory._();

  static const _prefix = 'pickerLastDir.';

  static bool get isDesktop => Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  /// Où ouvrir le sélecteur de [slot]: le dernier dossier s'il existe encore,
  /// sinon null (défaut du système).
  static Future<String?> startDir(PickerSlot slot) async {
    if (!isDesktop) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      return usableDir(prefs.getString(_prefix + slot.name));
    } catch (_) {
      return null;
    }
  }

  /// Retient le dossier d'un FICHIER choisi.
  static Future<void> rememberFile(PickerSlot slot, String? filePath) =>
      _store(slot, filePath == null || filePath.isEmpty ? null : p.dirname(filePath));

  /// Retient l'endroit d'un DOSSIER choisi: son PARENT, c'est-à-dire ce que
  /// le panneau montrait — rouvrir DANS le dossier en cacherait les voisins.
  static Future<void> rememberFolder(PickerSlot slot, String? folder) =>
      _store(slot, folderStartDir(folder));

  @visibleForTesting
  static String? usableDir(String? stored) =>
      (stored != null && stored.isNotEmpty && Directory(stored).existsSync()) ? stored : null;

  @visibleForTesting
  static String? folderStartDir(String? folder) {
    if (folder == null || folder.isEmpty) return null;
    final norm = p.normalize(folder);
    final parent = p.dirname(norm);
    return parent == norm ? norm : parent;   // la racine se retient elle-même
  }

  static Future<void> _store(PickerSlot slot, String? dir) async {
    if (!isDesktop || dir == null) return;
    try {
      await (await SharedPreferences.getInstance()).setString(_prefix + slot.name, dir);
    } catch (_) {/* un souvenir perdu n'est pas une erreur */}
  }
}

/// Choix multiple de fichiers SANS filtre (le probe tranche à la réception),
/// dans le dossier retenu pour [slot].
///
/// ⚠️ Sur bureau, file_selector et PAS file_picker: file_picker_darwin 1.0.4
/// n'envoie `initialDirectory` à son canal natif NI pour `pickFiles` NI pour
/// `getDirectoryPath` (le champ n'est pas dans la table d'arguments), donc le
/// panneau s'ouvrait toujours sur le home même avec un souvenir enregistré.
/// Mobile inchangé: file_picker garde le vrai nom de fichier sur Android, et
/// iOS ignore de toute façon le dossier initial.
/// Sur MOBILE, un sélecteur de fichier passe par `file_picker` et JAMAIS par
/// `file_selector` — pour deux raisons différentes, et qui tombent toutes les
/// deux sur la même porte.
///
/// Android: `file_selector` y renomme la copie d'après le type MIME résolu, et
/// une extension qu'Android ne connaît pas (`.sf2`, `.milk`, `.rom`) devient
/// octet-stream — le fichier arrive en « quelquechose.bin » et se fait jeter
/// par le contrôle d'extension.
///
/// ⚠️ iOS: `file_selector` n'accepte QUE des UTI
/// (`XTypeGroup.uniformTypeIdentifiers`) et LÈVE un `ArgumentError` sur un
/// groupe qui ne porte que des `extensions` — avant même d'ouvrir le panneau.
/// Vu de l'utilisateur, le bouton ne fait RIEN: pas de panneau, pas de
/// message, pas de trace (signalé le 2026-09-14 sur l'import de ROMs MT-32 et
/// de SoundFont). Et pour ces formats-là aucun UTI système n'existe: le seul
/// filtre possible serait `public.data`, c'est-à-dire aucun filtre.
///
/// Corollaire: c'est le CONTENU qui valide un import sur mobile (en-tête
/// `RIFF`…`sfbk` d'une SF2, SHA1 d'une ROM), jamais le sélecteur.
bool get pickerUsesFilePicker => Platform.isAndroid || Platform.isIOS;

Future<List<String>> pickAnyFilePaths(PickerSlot slot,
    {Future<String?> Function()? mobileStartDir}) async {
  if (PickerMemory.isDesktop) {
    final files = await fs.openFiles(initialDirectory: await PickerMemory.startDir(slot));
    return [for (final f in files) f.path];
  }
  // file_picker 12: `pickFiles` est STATIQUE, rend directement la liste des
  // fichiers (une annulation rend une liste VIDE et non null) et sélectionne
  // plusieurs fichiers par défaut.
  final res = await fp.FilePicker.pickFiles(
    type: fp.FileType.any,
    initialDirectory: mobileStartDir == null ? null : await mobileStartDir(),
  );
  return [
    for (final f in res)
      if (f.path != null) f.path!,
  ];
}
