import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/library_presence.dart';
import 'package:rewamp/local_db.dart';

// « Sur un autre appareil »: une entrée LOCALE dont le fichier n'est pas sur
// ce disque. Le compte transporte la clé, jamais le fichier — l'entrée reste
// listée, grisée, et c'est ce test qui fixe QUI est concerné: les entrées
// locales seulement, jamais un téléchargement de catalogue (qui se
// re-télécharge) ni une clé qui n'est pas un chemin.
void main() {
  late Directory tmp;
  late String present;
  const gone = '/nowhere/rewamp-test/absent.mod';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('presence');
    present = '${tmp.path}/present.mod';
    await File(present).writeAsString('x');
  });
  tearDown(() => tmp.delete(recursive: true));

  LibraryItem item(String refId, {String type = 'track'}) => LibraryItem(
      id: refId, type: type, refId: refId, name: refId,
      addedAt: DateTime(2026));

  TrackRecord track(String path, {String? onlineId}) => TrackRecord(
      id: path, filePath: path, entryPath: '', subsongIdx: 0,
      source: 'local', onlineId: onlineId,
      isFavorite: false, inLibrary: true, playCount: 0);

  test('une piste locale absente est « ailleurs », présente non', () async {
    final missing = await missingLocalLibraryRefs([
      item(present),
      item(gone),
      item('$gone?subsong=3'), // la clé porte la sous-chanson: on teste le FICHIER
    ]);
    expect(missing, {gone, '$gone?subsong=3'});
  });

  test('un id de catalogue ou un chemin online/ ne sont jamais « ailleurs »',
      () async {
    final sep = Platform.pathSeparator;
    final missing = await missingLocalLibraryRefs([
      item('0a1b2c3d-0000-0000-0000-000000000000'),
      item('${tmp.path}${sep}online${sep}jw_spc${sep}absent.spc'),
      item('artiste', type: 'artist'),
    ]);
    expect(missing, isEmpty);
  });

  test('favoris / entrées de playlist: par FICHIER, une fois', () async {
    final missing = await missingLocalTrackFiles([
      track(present),
      track(gone),
      track(gone), // deux sous-chansons du même fichier
      track('/nowhere/catalogue.nsf', onlineId: 'uuid'), // catalogue: exclu
    ]);
    expect(missing, {gone});
  });
}
