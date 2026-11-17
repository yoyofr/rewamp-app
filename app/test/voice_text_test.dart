// Texte dicté ↔ catalogue, indépendamment de la langue (voice_text.dart,
// carplay_voice_search.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/carplay_voice_search.dart';
import 'package:rewamp/voice_text.dart';

void main() {
  test('diacritiques latins retirés, toutes langues', () {
    expect(foldVoiceText('Légende Über Łódź Ærø Straße Dvořák'),
        'legende uber lodz aero strasse dvorak');
  });

  test('cyrillique et grec translittérés', () {
    expect(foldVoiceText('Тетрис'), 'tetris');
    expect(foldVoiceText('Коробейники'), 'korobeyniki');
    expect(foldVoiceText('Μουσική'), 'mousiki');
  });

  test('kana en romaji, syllabes composées et consonne doublée', () {
    expect(foldVoiceText('テトリス'), 'tetorisu');
    expect(foldVoiceText('ゼルダ'), 'zeruda');
    expect(foldVoiceText('きょう'), 'kyou');
    expect(foldVoiceText('ロックマン'), 'rokkuman');
  });

  test('kanji laissés tels quels (pas de forme latine)', () {
    expect(foldVoiceText('伝説'), '伝説');
  });

  test('écritures à translittérer détectées', () {
    expect(hasTransliterableScript('Тетрис'), isTrue);
    expect(hasTransliterableScript('テトリス'), isTrue);
    expect(hasTransliterableScript('Tetris'), isFalse);
  });

  test('découpage titre / artiste sans liste de connecteurs', () {
    final de = CarPlayVoiceSearcher.splitCandidates('Thunderstruck von AC DC');
    expect(de, contains(('Thunderstruck', 'AC DC')));
    final it = CarPlayVoiceSearcher.splitCandidates('Tetris di Hirokazu Tanaka');
    expect(it, contains(('Tetris', 'Hirokazu Tanaka')));
    final fr = CarPlayVoiceSearcher.splitCandidates("Thunderstruck d'AC/DC");
    expect(fr, contains(('Thunderstruck', 'AC/DC')));
  });

  test('CJK: artiste AVANT la particule possessive', () {
    final ja = CarPlayVoiceSearcher.splitCandidates('久石譲の天空の城');
    expect(ja.first, ('天空の城', '久石譲'));
    final zh = CarPlayVoiceSearcher.splitCandidates('周杰伦的晴天');
    expect(zh.first, ('晴天', '周杰伦'));
  });
}
