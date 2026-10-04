import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

/// `browse_music` rend les collections joshw à archives (jw_psf, jw_gsf…)
/// UNE ligne par ALBUM: le fichier de la ligne est le `.7z` entier. Une liste
/// de MORCEAUX (onglet Morceaux d'un artiste) doit la remplacer par ses
/// pistes — Michiko Naruke y montrait « 2 morceaux » qui étaient ses 2
/// albums. `isArchiveAlbumRow` décide QUELLES lignes se déplient; le critère
/// est l'URL (le fichier EST l'archive), pas le seul album_id.
SearchResult _row({
  String? albumId = 'a1',
  String? url = 'https://x/Wild%20Arms%20(1996)(Media%20Vision)%5bPS1%5d.7z',
  int? subsongCount = 86,
  int? trackPosition,
  bool resolved = false,
  String? matchTitle,
  String ext = 'psf',
}) =>
    SearchResult(
      songId: 's1',
      collection: 'jw_psf',
      title: 'Wild Arms',
      filename: 'Wild Arms.$ext',
      album: 'Wild Arms',
      albumId: albumId,
      formatExt: ext,
      downloadUrl: url,
      fileSize: 0,
      year: null,
      artistNames: const ['Michiko Naruke'],
      totalCount: 2,
      subsongCount: subsongCount,
      trackPosition: trackPosition,
      resolvedSubsong: resolved,
      matchSubsongTitle: matchTitle,
    );

void main() {
  test('une archive d\'album (album_id + .7z + plusieurs pistes) se déplie',
      () {
    expect(RewampDb.isArchiveAlbumRow(_row()), isTrue);
    expect(RewampDb.isArchiveAlbumRow(_row(ext: 'nsf')), isTrue);
  });

  test('une piste DÉJÀ dépliée garde l\'url de l\'archive mais n\'en est pas une',
      () {
    expect(RewampDb.isArchiveAlbumRow(_row(trackPosition: 3)), isFalse);
    expect(RewampDb.isArchiveAlbumRow(_row(resolved: true)), isFalse);
    expect(RewampDb.isArchiveAlbumRow(_row(matchTitle: 'Hope')), isFalse);
  });

  test('un fichier qui n\'est PAS l\'archive ne se déplie pas', () {
    // Module modland d'un album multi-fichiers: album_id + sous-chansons,
    // mais la ligne ne désigne que LUI-MÊME.
    expect(
        RewampDb.isArchiveAlbumRow(
            _row(url: 'https://x/mdat.monkey%20island', ext: 'mdat')),
        isFalse);
    expect(RewampDb.isArchiveAlbumRow(_row(albumId: null)), isFalse);
    expect(RewampDb.isArchiveAlbumRow(_row(subsongCount: 1)), isFalse);
    expect(RewampDb.isArchiveAlbumRow(_row(url: null)), isFalse);
  });
}
