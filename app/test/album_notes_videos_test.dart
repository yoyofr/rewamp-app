// get_album_details, mig serveur 303: `notes` (HTML éditorial) et `videos`
// arrivent EN FIN de ligne et se lisent PAR NOM — un serveur d'avant la
// migration ne les envoie pas.
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

Map<String, dynamic> _row([Map<String, dynamic> extra = const {}]) => {
      'album_id': '1a193dbd-14ee-5c41-b472-e75d1f106e0f',
      'name': 'DoDonPachi Saidaioujou',
      'collection': 'jw_x360',
      'description': 'Ripped by X',
      ...extra,
    };

void main() {
  test('serveur sans la mig 303: pas de note, aucune vidéo', () {
    final d = AlbumDetails.fromJson(_row());
    expect(d.notes, isNull);
    expect(d.videos, isEmpty);
    expect(d.description, 'Ripped by X');
  });

  test('note vide ou blanche = pas de note', () {
    expect(AlbumDetails.fromJson(_row({'notes': ''})).notes, isNull);
    expect(AlbumDetails.fromJson(_row({'notes': '  \n'})).notes, isNull);
  });

  test('note et vidéos lues; embed depuis video_id, départ compris', () {
    final d = AlbumDetails.fromJson(_row({
      'notes': ' <a href="https://shmups.wiki/x">Shmups wiki</a><br> ',
      'videos': [
        {'provider': 'youtube', 'video_id': 'qZ0C-XX0fcQ',
         'url': 'https://www.youtube.com/watch?v=qZ0C-XX0fcQ',
         'title': 'Superplay', 'start_seconds': 42,
         'thumbnail': 'https://i.ytimg.com/vi/qZ0C-XX0fcQ/hqdefault.jpg'},
        {'provider': 'youtube', 'video_id': 'AAAAAAAAAAA',
         'url': 'https://youtu.be/AAAAAAAAAAA', 'title': null},
      ],
    }));
    expect(d.notes, '<a href="https://shmups.wiki/x">Shmups wiki</a><br>');
    expect(d.description, 'Ripped by X');   // combinée, pas remplacée
    expect(d.videos.map((v) => v.videoId), ['qZ0C-XX0fcQ', 'AAAAAAAAAAA']);
    expect(d.videos.first.title, 'Superplay');
    expect(d.videos.first.embedUrl, contains('/embed/qZ0C-XX0fcQ'));
    expect(d.videos.first.embedUrl, contains('start=42'));
    // Aucune production ni morceau derrière une vidéo d'album.
    expect(d.videos.first.productionId, isNull);
    expect(d.videos.first.songId, isNull);
  });
}
