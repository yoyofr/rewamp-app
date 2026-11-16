// Une tracklist serveur peut lister un DOSSIER de l'archive comme une piste:
// DoDonPachi Saidaioujou (jw_x360) a « music » au rang 25, suivi de
// « music/01_select.xma »… La ligne n'a rien à jouer et finissait en échec
// dans la file. Elle est SAUTÉE, mais les rangs `<uuid>#<i>` des autres ne
// bougent pas: c'est une identité de compte, et le serveur compte le dossier.
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

const _subs = [
  AlbumSubsong(file: 'CA022090.wma', title: 'CA022090'),
  AlbumSubsong(file: 'SD_OPN.wma', title: 'SD_OPN'),
  AlbumSubsong(file: 'music', title: 'music'),
  AlbumSubsong(file: 'music/01_select.xma', title: 'select'),
  AlbumSubsong(file: 'music/02_stg1.xma', title: 'stg1'),
];

SearchResult _album() => SearchResult(
      songId: 'uuid',
      collection: 'jw_x360',
      title: 'DoDonPachi Saidaioujou',
      filename: 'DoDonPachi Saidaioujou.7z',
      album: 'DoDonPachi Saidaioujou',
      formatExt: '',
      downloadUrl: null,
      fileSize: 0,
      year: 2013,
      artistNames: const [],
      totalCount: 1,
      subsongs: _subs,
      platform: 'X360',
    );

void main() {
  test('le dossier est repéré, et seulement lui', () {
    expect(RewampDb.tracklistFolderEntries(_subs), {2});
  });

  test('un fichier sans extension mais sans rien sous lui reste une piste', () {
    const subs = [
      AlbumSubsong(file: 'mdat.tune'),   // forme préfixe Amiga: a un point
      AlbumSubsong(file: 'README'),      // sans extension, rien dessous
      AlbumSubsong(file: 'musicbox.mod'),
    ];
    expect(RewampDb.tracklistFolderEntries(subs), isEmpty);
  });

  test('le dossier est sauté, les rangs des autres sont conservés', () {
    final rows = RewampDb.subsongRowsFromServer(_album());
    expect(rows.map((r) => r.title), ['CA022090', 'SD_OPN', 'select', 'stg1']);
    expect(rows.map((r) => r.songId),
        ['uuid#0', 'uuid#1', 'uuid#3', 'uuid#4']);
  });

  test('narrowedToMember retrouve une piste par son RANG, pas sa position', () {
    expect(RewampDb.narrowedToMember(_album(), 'uuid#4').title, 'stg1');
    expect(RewampDb.narrowedToMember(_album(), 'uuid#3').title, 'select');
    // Le rang du dossier ne désigne rien: on rend le conteneur.
    expect(RewampDb.narrowedToMember(_album(), 'uuid#2').songId, 'uuid');
  });
}
