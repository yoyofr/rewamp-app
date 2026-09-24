import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_open.dart' show rotateToDefaultSubsong;
import 'package:rewamp/rewamp_db.dart';

// `most_popular_songs` classe des ŒUVRES depuis le 2026-09-05
// (docs/popularity_grain_proposal.md). Ce que le client doit tenir:
// `song_id` vient de `top_song_id` (plus de `item_id`, un uuid d'ALBUM sur une
// ligne `album`), la ligne n'est JAMAIS résolue (`subsong_index` a disparu), et
// la lecture tourne la liste à partir de `(top_song_id, top_subsong_index)`.
Map<String, dynamic> _row(Map<String, dynamic> extra) => {
      'item_type': 'song',
      'item_id': 'file-uuid',
      'top_song_id': 'file-uuid',
      'top_subsong_index': 0,
      'title': 'x',
      'collection': 'hvsc',
      'format_ext': 'sid',
      'download_url': 'https://x/y.sid',
      'play_count': 3,
      'unique_users': 2,
      'listener_days': 2,
      'popularity': 50,
      ...extra,
    };

void main() {
  test('ligne album: song_id = top_song_id, album_id = item_id, non résolue', () {
    final r = RewampDb.popularRowToResult(_row({
      'item_type': 'album',
      'item_id': 'album-uuid',
      'album_id': 'album-uuid',
      'top_song_id': 'track-uuid',
      'top_subsong_index': 0,
      'subsong_count': null,
    }))!;
    expect(r.isAlbumRow, isTrue);
    expect(r.albumId, 'album-uuid');
    expect(r.songId, 'track-uuid');
    expect(r.topSongId, 'track-uuid');
    expect(r.resolvedSubsong, isFalse);
  });

  test('ligne fichier multi-sous-chants: conteneur, index = entrée la plus écoutée', () {
    final r = RewampDb.popularRowToResult(_row({
      'title': 'monkey island',
      'top_subsong_index': 5,
      'subsong_count': 22,
    }))!;
    expect(r.isAlbumRow, isFalse);
    expect(r.songId, 'file-uuid');
    expect(r.subsongIdx, 5, reason: 'cible du ♥');
    expect(r.topSubsongIndex, 5);
    expect(r.resolvedSubsong, isFalse, reason: 'jamais épinglée: on déplie puis on tourne');
    expect(RewampDb.isContainerRow(r), isTrue);
    expect(r.listenerDays, 2);
    // Survit à la persistance de la file.
    final back = SearchResult.fromJson(r.toJson());
    expect(back.topSubsongIndex, 5);
    expect(back.topSongId, 'file-uuid');
  });

  test('serveur d\'avant (sans top_song_id): repli sur item_id', () {
    final m = _row({'subsong_count': 3})..remove('top_song_id')..remove('top_subsong_index');
    final r = RewampDb.popularRowToResult(m)!;
    expect(r.songId, 'file-uuid');
    expect(r.topSubsongIndex, isNull);
    expect(r.subsongIdx, 0);
  });

  test('rotation: départ sur l\'entrée la plus écoutée, repli 0 si absente', () {
    final top = RewampDb.popularRowToResult(_row({
      'item_type': 'album', 'item_id': 'a', 'album_id': 'a',
      'top_song_id': 't3', 'top_subsong_index': 0,
    }))!;
    SearchResult t(String id) => SearchResult.fromJson({
          'song_id': id, 'collection': 'c', 'title': id, 'filename': '$id.spc'});
    final tracks = [t('t1'), t('t2'), t('t3'), t('t4'), t('t5')];
    final i = RewampDb.topEntryIndex(tracks, top);
    expect(i, 2);
    expect(rotateToDefaultSubsong(tracks, i).map((x) => x.songId).toList(),
        ['t3', 't4', 't5', 't1', 't2'], reason: 'un tout lire doit tout lire');
    final gone = [t('t1'), t('t2')];
    expect(RewampDb.topEntryIndex(gone, top), 0);
  });
}
