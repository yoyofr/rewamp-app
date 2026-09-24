// Choisir un DOSSIER, et pouvoir le lire ensuite.
//
// Sur iOS, un dossier choisi hors du bac à sable n'est lisible qu'entre
// `startAccessingSecurityScopedResource()` et son `stop` — et le sélecteur de
// `file_picker` ne prend jamais cette portée (il construit en plus son panneau
// avec l'API dépréciée, dont le bouton « Ouvrir » ne valide rien). D'où un
// canal maison: le natif ouvre la portée et rend le chemin, l'appelant la
// referme QUAND IL A FINI DE COPIER.
//
// ⚠️ Toujours passer par [withPickedFolder]: relâcher trop tôt donne le pire
// des symptômes — un import qui « réussit » et n'importe rien, parce que
// l'énumération d'un dossier hors portée ne lève pas, elle rend une liste
// VIDE.

import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:file_selector/file_selector.dart' as fs;
import 'picker_memory.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('rewamp/folder_picker');

/// Ouvre le sélecteur de dossier et exécute [action] avec son chemin, la
/// portée de sécurité tenue ouverte pendant tout ce temps. Rend null si
/// l'utilisateur annule.
///
/// Hors iOS, `file_picker` suffit: sur macOS le sélecteur rend un vrai chemin
/// lisible, et Android n'a pas de portée à prendre pour un dossier choisi.
/// Sur bureau le panneau s'ouvre là où le dernier choix de [slot] a été fait
/// (voir PickerMemory).
Future<T?> withPickedFolder<T>(Future<T> Function(String path) action,
    {PickerSlot slot = PickerSlot.music}) async {
  if (!Platform.isIOS) {
    // ⚠️ Sur bureau, file_selector et PAS file_picker: file_picker_darwin
    // 1.0.4 appelle son canal natif `dir` SANS AUCUN argument
    // (`invokeMethod('dir')`), donc `initialDirectory` n'atteint jamais le
    // panneau, qui retombe sur son défaut — le home. Le souvenir était bien
    // enregistré et ne servait à rien. file_selector transmet le dossier
    // (`panel.directoryURL` sur macOS) et sait déjà ouvrir nos fichiers.
    final dir = Platform.isAndroid
        ? await fp.FilePicker.getDirectoryPath()
        : await fs.getDirectoryPath(initialDirectory: await PickerMemory.startDir(slot));
    if (dir == null || dir.isEmpty) return null;
    await PickerMemory.rememberFolder(slot, dir);
    return action(dir);
  }
  String? path;
  try {
    path = await _channel.invokeMethod<String>('pick');
  } on MissingPluginException {
    // Binaire plus ancien que ce canal: mieux vaut le sélecteur du greffon
    // (qui échouera peut-être) que pas de sélecteur du tout.
    final dir = await fp.FilePicker.getDirectoryPath();
    if (dir == null || dir.isEmpty) return null;
    return action(dir);
  } catch (_) {
    return null;
  }
  if (path == null || path.isEmpty) return null;
  try {
    return await action(path);
  } finally {
    try {
      await _channel.invokeMethod<void>('release');
    } catch (_) {/* la portée mourra avec le processus */}
  }
}
