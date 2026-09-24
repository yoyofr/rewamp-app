// Le décodage du texte lu dans des FICHIERS (tags PSF, M3U).
//
// Le vrai décodeur Shift-JIS est celui du MOTEUR (`rewamp_decode_text`), qui
// n'existe pas dans l'hôte de test Dart: on injecte donc un décodeur-témoin et
// on épingle ce que le Dart, lui, décide — la coupe en LIGNES, le passage tel
// quel de l'UTF-8, et le repli sans moteur.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/legacy_text.dart';

void main() {
  // Octets RÉELS du tag d'« Aitakute… » (AUT_M1a.psf), en Shift-JIS.
  const artistSjis = [0x95, 0xbd, 0x93, 0x63, 0x20, 0x8f, 0xcb, 0x88, 0xea, 0x98, 0x59];
  const titleSjis = [0x90, 0xe7, 0x8d, 0xd8, 0x81, 0x69, 0x8f, 0x48, 0x81, 0x6a];

  // Témoin: connaît exactement ces deux valeurs, comme le ferait CP932.
  String? fake(List<int> line) {
    final s = line.toString();
    if (s.endsWith(artistSjis.toString().substring(1))) {
      return '${ascii.decode(line.sublist(0, line.length - artistSjis.length))}平田 祥一郎';
    }
    if (s.endsWith(titleSjis.toString().substring(1))) {
      return '${ascii.decode(line.sublist(0, line.length - titleSjis.length))}千菜（秋）';
    }
    return null;
  }

  test('un bloc de tags Shift-JIS se décode, ligne par ligne', () {
    final block = [
      ...ascii.encode('title='), ...titleSjis, 0x0A,
      ...ascii.encode('artist='), ...artistSjis, 0x0A,
      ...ascii.encode('copyright=Konami'),
    ];
    expect(decodeFileText(block, lineDecoder: fake),
        'title=千菜（秋）\nartist=平田 祥一郎\ncopyright=Konami');
  });

  test('l\'UTF-8 valide passe TEL QUEL, sans consulter le décodeur', () {
    var asked = 0;
    final out = decodeFileText(utf8.encode('artist=平田 祥一郎\nx=é'),
        lineDecoder: (_) { asked++; return 'FAUX'; });
    expect(out, 'artist=平田 祥一郎\nx=é');
    expect(asked, 0, reason: 'c\'est aussi ce qui couvre les PSF marqués utf8=');
  });

  test('ligne par ligne: une ligne ratée n\'emporte PAS les suivantes', () {
    // CP932 s'arrête au premier octet indécodable: décoder le bloc entier
    // aurait perdu l'artiste à cause du titre.
    final block = [
      ...ascii.encode('title='), 0xFF, 0xFF, 0x0A,
      ...ascii.encode('artist='), ...artistSjis,
    ];
    final out = decodeFileText(block, lineDecoder: fake);
    expect(out.split('\n')[1], 'artist=平田 祥一郎');
  });

  test('sans moteur: repli sur l\'ancien comportement, jamais une exception', () {
    final out = decodeFileText([...ascii.encode('a='), ...titleSjis],
        lineDecoder: (_) => null);
    expect(out, startsWith('a='));
    expect(out.contains('�'), isTrue);
  });

  test('les fins de ligne CRLF et les lignes vides sont conservées', () {
    expect(decodeFileText(ascii.encode('a=1\r\n\nb=2'), lineDecoder: fake),
        'a=1\r\n\nb=2');
  });
}
