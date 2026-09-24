import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

/// Le numéro de chanson d'un rip joshw est parfois une POSITION dans la
/// playlist (NSF: 1..N, GBS: 0..N-1), parfois un numéro de chanson ABSOLU du
/// driver, qu'on passe tel quel au moteur. Les deux arrivent sous la même
/// forme — `fichier.ext::FORMAT,$hex,titre,durée` — donc seul le FORMAT permet
/// de trancher, et une position se normalise (−1 si la liste commence à 1) là
/// où un numéro absolu ne se touche JAMAIS.
///
/// Mesuré sur « 1941: Counter Attack » (jw_hes, HC91048): les index vont de
/// `$3E` (62) à `$65` (101), sans `$00`. La règle « ça ne commence pas à 0,
/// donc c'est 1-based » retirait 1 à tout le monde, et le greffon NEZ — qui
/// ajoute 1 pour NEZSetSongNo, 1-based — jouait donc une chanson trop bas:
/// la 2e piste devait lancer la chanson 77 et lançait la 76. Modizer, lui,
/// fait `NEZSetSongNo(index_m3u + 1)` sans rien retirer.
void main() {
  const m3u1941 = '''
# @TITLE       1941: Counter Attack
HC91048.hes::HES,\$57,Opening,10,-,10
HC91048.hes::HES,\$4D,Stage 1,44,43,10
HC91048.hes::HES,\$4F,Stage 1 Boss,54,53,10
''';

  test('un M3U HES garde ses numéros absolus', () {
    final subs = RewampDb.parseM3uToSubsongs(m3u1941, '/tmp');
    expect(subs.map((s) => s.subsongIdx).toList(), [0x57, 0x4D, 0x4F],
        reason: 'le greffon NEZ ajoute 1: 0x4D = 77 doit rester 77');
  });

  test('un M3U NSF reste une POSITION et se normalise', () {
    // Contre-épreuve: là, 1 est bien la première piste.
    const m3u = '''
game.nsf::NSF,1,Title,30
game.nsf::NSF,2,Stage 1,60
''';
    final subs = RewampDb.parseM3uToSubsongs(m3u, '/tmp');
    expect(subs.map((s) => s.subsongIdx).toList(), [0, 1]);
  });

  test('une tracklist SERVEUR de .hes garde ses numéros absolus', () {
    // Le serveur republie le numéro FORMAT-NATIF lu dans le même M3U: le
    // dépliage d'album doit appliquer la même règle que le parseur local,
    // sinon un album téléchargé joue décalé alors qu'un import local non.
    final container = SearchResult.fromJson({
      'song_id': 'uuid',
      'collection': 'jw_hes',
      'title': '1941: Counter Attack',
      'filename': 'HC91048.hes',
      'format_ext': 'hes',
      'tracks': [
        {'file': 'HC91048.hes', 'subsong': 0x57, 'title': 'Opening'},
        {'file': 'HC91048.hes', 'subsong': 0x4D, 'title': 'Stage 1'},
        {'file': 'HC91048.hes', 'subsong': 0x4F, 'title': 'Stage 1 Boss'},
      ],
    });
    final rows = RewampDb.subsongRowsFromServer(container);
    expect(rows.map((r) => r.subsongIdx).toList(), [0x57, 0x4D, 0x4F]);
  });

  test('une tracklist NSF garde la normalisation 1-based', () {
    final container = SearchResult.fromJson({
      'song_id': 'uuid',
      'collection': 'jw_nsf',
      'title': 'Castlevania III',
      'filename': 'cv3.nsf',
      'format_ext': 'nsf',
      'tracks': [
        {'file': 'cv3.nsf', 'subsong': 1, 'title': 'Prelude'},
        {'file': 'cv3.nsf', 'subsong': 2, 'title': 'Beginning'},
      ],
    });
    final rows = RewampDb.subsongRowsFromServer(container);
    expect(rows.map((r) => r.subsongIdx).toList(), [0, 1]);
  });
}
