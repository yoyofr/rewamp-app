// L'en-tête d'un M3U étendu, seule source de métadonnées d'un rip LOCAL.
//
// Échantillon réel (Day of the Tentacle, rip MT-32): trois vocabulaires se
// croisent dans le même fichier — les directives `#EXTALB:`, les tags
// vgmstream `# @TAG valeur`, et un bloc `# Clé: valeur` écrit à la main que
// chaque ripeur invente à sa façon.

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_db.dart' show TrackRecord;
import 'package:rewamp/m3u_info.dart';
import 'package:rewamp/rewamp_db.dart' show RewampDb;

const _dott = '''#EXTM3U
#PLAYLIST:Day of the Tentacle (Maniac Mansion II) (Roland MT-32)
#EXTALB:Day of the Tentacle (Maniac Mansion II)
#EXTART:Peter McConnell, Michael Z. Land, Clint Bajakian
#EXTGENRE:Video Game Soundtrack (Roland MT-32)
#EXTIMG:dott.jpg
#
# Game: Day of the Tentacle (Maniac Mansion II)
# Developer: LucasArts (designers: Tim Schafer, Dave Grossman)
# Publisher: LucasArts
# Release (MS-DOS): June 25, 1993
# Composer(s): Peter McConnell, Michael Z. Land, Clint Bajakian
# Other music credits: McConnell: present; Land: future; Bajakian: past
# Series: Maniac Mansion (sequel)
# Sources: https://en.wikipedia.org/wiki/Day_of_the_Tentacle
#          Cover: https://www.mobygames.com (DOS front cover)
#
#EXTINF:43,Day of the Tentacle (Maniac Mansion II) - tentacle_001
tentacle_001.mid
#EXTINF:40,Day of the Tentacle (Maniac Mansion II) - tentacle_004
tentacle_004.mid
''';

void main() {
  test('les directives du M3U étendu', () {
    final i = parseM3uInfo(_dott);
    expect(i.album, 'Day of the Tentacle (Maniac Mansion II)');
    expect(i.playlist,
        'Day of the Tentacle (Maniac Mansion II) (Roland MT-32)');
    expect(i.genre, 'Video Game Soundtrack (Roland MT-32)');
    expect(i.image, 'dott.jpg');
    expect(i.artists,
        ['Peter McConnell', 'Michael Z. Land', 'Clint Bajakian']);
  });

  test('le bloc libre garde son ORDRE et ses intitulés', () {
    final i = parseM3uInfo(_dott);
    expect([for (final f in i.fields) f.key], [
      'Game', 'Developer', 'Publisher', 'Release (MS-DOS)',
      'Composer(s)', 'Other music credits', 'Series', 'Sources',
    ]);
    expect(i.field(['Publisher']), 'LucasArts');
  });

  test('une ligne INDENTÉE continue le champ précédent', () {
    // Sans cette règle, « #          Cover: … » devenait un champ « Cover »
    // que le fichier ne déclare pas.
    final i = parseM3uInfo(_dott);
    expect(i.fields.where((f) => f.key == 'Cover'), isEmpty);
    expect(i.field(['Sources']), contains('mobygames.com'));
    expect(i.field(['Sources'])!.split('\n').length, 2);
  });

  test('l\'en-tête S\'ARRÊTE à la première piste', () {
    // Un `#EXTINF` porte un titre de PISTE: le laisser entrer ferait du
    // dernier titre lu l'album.
    final i = parseM3uInfo(_dott);
    expect(i.fields.any((f) => f.value.contains('tentacle_')), isFalse);
  });

  test('sans #EXTART, les compositeurs du bloc libre font l\'artiste', () {
    const noExtart = '''#EXTM3U
#EXTALB:Un jeu
# Composer(s): Alice, Bob and Carol
#EXTINF:10,x
x.mid
''';
    expect(parseM3uInfo(noExtart).artists, ['Alice', 'Bob', 'Carol']);
  });

  test('« Other music credits » n\'est pas un artiste', () {
    // Liste de clés volontairement courte: ce qui remplit l'artiste d'une
    // piste, pas tout ce qui ressemble à un crédit.
    const onlyCredits = '''#EXTM3U
# Other music credits: McConnell: present; Land: future
#EXTINF:10,x
x.mid
''';
    expect(parseM3uInfo(onlyCredits).artists, isEmpty);
  });

  test('une URL nue ne devient pas un champ', () {
    const bare = '''#EXTM3U
# https://example.org/notes
#EXTINF:10,x
x.mid
''';
    expect(parseM3uInfo(bare).fields, isEmpty);
  });

  test('un M3U nu ne dit rien', () {
    expect(parseM3uInfo('x.mid\ny.mid\n').isEmpty, isTrue);
  });

  mainFill();
}

// ── Ce que l'en-tête remplit sur une ligne locale ───────────────────────────
//
// La branche « fichier simple » de `tracksForLocalPath` fabrique une ligne qui
// ne porte que le NOM DU FICHIER: le lecteur affichait un titre nu, sans
// artiste ni album, pour un dossier qui les déclare en toutes lettres. Le M3U
// comble les trous — et RIEN d'autre: « la ligne DÉJÀ EN BASE gagne », une
// lecture qui ne sait pas ne doit rien écraser.

TrackRecord _row({String? artist, String? album}) => TrackRecord(
      id: '', filePath: '/m/tentacle_001.mid', entryPath: '', subsongIdx: 0,
      title: 'tentacle_001', artist: artist, metaAlbum: album,
      formatExt: 'mid', source: 'local',
      isFavorite: false, inLibrary: false, playCount: 0,
    );

/// La MÊME règle que `_fillFromM3uHeader`, sur des valeurs déjà résolues.
TrackRecord _fill(TrackRecord t, M3uInfo info) => t.copyWith(
      artist: (t.artist ?? '').isEmpty
          ? (info.artists.isEmpty ? null : info.artists.join(', '))
          : null,
      metaAlbum: (t.metaAlbum ?? '').isEmpty ? info.album : null,
    );

void mainFill() {
  final info = parseM3uInfo(_dott);

  test('une ligne nue reçoit l\'album et les artistes du M3U', () {
    final t = _fill(_row(), info);
    expect(t.artist, 'Peter McConnell, Michael Z. Land, Clint Bajakian');
    expect(t.metaAlbum, 'Day of the Tentacle (Maniac Mansion II)');
  });

  test('une ligne qui SAIT déjà n\'est pas écrasée', () {
    final t = _fill(_row(artist: 'Quelqu\'un', album: 'Un autre album'), info);
    expect(t.artist, 'Quelqu\'un');
    expect(t.metaAlbum, 'Un autre album');
  });

  test('le TITRE d\'entrée du M3U fait autorité', () {
    // `#EXTINF:43,…` porte le nom que le ripeur a voulu; la ligne fabriquée ne
    // porte que le nom du FICHIER. Règle du dépôt: le M3U fait autorité sur
    // les titres.
    final subs = RewampDb.parseM3uToSubsongs(_dott, '/m');
    final mine = [
      for (final x in subs)
        if (x.filePath.endsWith('tentacle_004.mid')) x
    ];
    expect(mine.length, 1, reason: 'un fichier listé UNE fois = fichier simple');
    expect(mine.first.title,
        'Day of the Tentacle (Maniac Mansion II) - tentacle_004');
  });

  test('un fichier listé PLUSIEURS fois n\'est pas un fichier simple', () {
    // C'est un conteneur dont le M3U décrit les sous-chansons: ce chemin-là a
    // son propre traitement, et le remplissage doit s'abstenir.
    const container = '''#EXTM3U
#EXTALB:Un jeu
#EXTINF:10,Piste 1
jeu.nsf
#EXTINF:20,Piste 2
jeu.nsf
''';
    final subs = RewampDb.parseM3uToSubsongs(container, '/m');
    expect(subs.where((x) => x.filePath.endsWith('jeu.nsf')).length, 2);
  });

  test('chaque trou se comble indépendamment', () {
    final t = _fill(_row(album: 'Un autre album'), info);
    expect(t.artist, 'Peter McConnell, Michael Z. Land, Clint Bajakian');
    expect(t.metaAlbum, 'Un autre album');
  });
}
