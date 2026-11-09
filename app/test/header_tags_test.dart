import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/header_tags.dart';

Uint8List _buf(int len) => Uint8List(len);
void _put(Uint8List b, int off, List<int> bytes) =>
    b.setRange(off, off + bytes.length, bytes);
void _str(Uint8List b, int off, String s) => _put(b, off, latin1.encode(s));

// Pas de moteur dans l'hôte de test: un décodeur de ligne explicite.
String? _noLegacy(List<int> _) => null;
HeaderTags? _parse(Uint8List b) => parseHeaderTags(b, lineDecoder: _noLegacy);

void main() {
  test('PSID: name and author, Latin-1, <?> means unknown', () {
    final b = _buf(0x80);
    _str(b, 0, 'PSID');
    _str(b, 0x16, 'Commando');
    _str(b, 0x36, 'Rob Hubbard');
    expect(_parse(b)!.title, 'Commando');
    expect(_parse(b)!.artist, 'Rob Hubbard');
    final u = _buf(0x80);
    _str(u, 0, 'RSID');
    _str(u, 0x16, 'Tune');
    _str(u, 0x36, '<?>');
    expect(_parse(u)!.artist, isNull);
    final l = _buf(0x80);
    _str(l, 0, 'PSID');
    _put(l, 0x16, [0x4A, 0xE4, 0x67, 0x65, 0x72]); // « Jäger » en Latin-1
    expect(_parse(l)!.title, 'Jäger');
  });

  test('NSF and GBS', () {
    final n = _buf(0x80);
    _str(n, 0, 'NESM\x1A');
    _str(n, 0x0E, 'Mega Man 2');
    _str(n, 0x2E, 'Takashi Tateishi');
    expect(_parse(n)!.title, 'Mega Man 2');
    expect(_parse(n)!.artist, 'Takashi Tateishi');
    final g = _buf(0x80);
    _str(g, 0, 'GBS');
    _str(g, 0x10, 'Tetris');
    _str(g, 0x30, 'Hirokazu Tanaka');
    expect(_parse(g)!.title, 'Tetris');
  });

  test('SPC ID666 text and binary artist offsets', () {
    Uint8List spc({required bool textual}) {
      final b = _buf(0x100);
      _str(b, 0, 'SNES-SPC700 Sound File Data v0.30');
      b[0x23] = 26;
      _str(b, 0x2E, 'Terra');
      _str(b, 0x4E, 'Final Fantasy VI');
      if (textual) {
        _str(b, 0xA9, '180');
        _str(b, 0xAC, '10000');
        _str(b, 0xB1, 'Nobuo Uematsu');
      } else {
        _put(b, 0xA9, [0xB4, 0x00, 0x00, 0x10, 0x27, 0x00, 0x00]);
        _str(b, 0xB0, 'Nobuo Uematsu');
      }
      return b;
    }
    for (final t in [true, false]) {
      final r = _parse(spc(textual: t))!;
      expect(r.title, 'Terra');
      expect(r.artist, 'Nobuo Uematsu', reason: 'textual=$t');
    }
  });

  test('modules: MOD (signature at 1080), XM, S3M, IT', () {
    final m = _buf(1084);
    _str(m, 0, 'space debris');
    _str(m, 1080, 'M.K.');
    expect(_parse(m)!.title, 'space debris');
    final noSig = _buf(1084);
    _str(noSig, 0, 'not a mod');
    expect(_parse(noSig), isNull);
    final x = _buf(80);
    _str(x, 0, 'Extended Module: ');
    _str(x, 17, 'Unreal II');
    expect(_parse(x)!.title, 'Unreal II');
    final s = _buf(0x60);
    _str(s, 0, 'Second Reality');
    _str(s, 0x2C, 'SCRM');
    expect(_parse(s)!.title, 'Second Reality');
    final i = _buf(64);
    _str(i, 0, 'IMPM');
    _str(i, 4, 'Impulse');
    expect(_parse(i)!.title, 'Impulse');
  });

  test('NSFe auth chunk; spaces collapsed', () {
    final chunk = latin1.encode('Castlevania III\x00Hidenori Maezawa\x00Konami\x00');
    final b = _buf(4 + 8 + 4 + 8 + chunk.length);
    _str(b, 0, 'NSFE');
    ByteData.sublistView(b).setUint32(4, 4, Endian.little);
    _str(b, 8, 'INFO');
    final at = 16;
    ByteData.sublistView(b).setUint32(at, chunk.length, Endian.little);
    _str(b, at + 4, 'auth');
    _put(b, at + 8, chunk);
    final r = _parse(b)!;
    expect(r.title, 'Castlevania III');
    expect(r.artist, 'Hidenori Maezawa');
    final m = _buf(1084);
    _str(m, 0, r'$$$   dantro   $$$');
    _str(m, 1080, 'M.K.');
    expect(_parse(m)!.title, r'$$$ dantro $$$');
  });

  test('padding-only fields name nothing', () {
    final m = _buf(1084);
    _str(m, 0, '----   ');
    _str(m, 1080, 'M.K.');
    expect(_parse(m), isNull);
  });

  test('VGM GD3 (plain and gzipped): English first, Japanese fallback', () {
    List<int> u16(String s) => [
          for (final c in s.codeUnits) ...[c & 0xFF, c >> 8],
          0, 0,
        ];
    final gd3Strings = <int>[
      ...u16(''), ...u16('ステージ1'), // titre: EN vide ⇒ JP
      ...u16('Thunder Force IV'), ...u16(''),
      ...u16('Mega Drive'), ...u16(''),
      ...u16('Technosoft'), ...u16(''),
      ...u16('1992'), ...u16('ripper'), ...u16(''),
    ];
    final gd3Off = 0x40;
    final b = _buf(gd3Off + 12 + gd3Strings.length);
    _str(b, 0, 'Vgm ');
    ByteData.sublistView(b).setUint32(0x14, gd3Off - 0x14, Endian.little);
    _str(b, gd3Off, 'Gd3 ');
    ByteData.sublistView(b)
        .setUint32(gd3Off + 8, gd3Strings.length, Endian.little);
    _put(b, gd3Off + 12, gd3Strings);
    final r = _parse(b)!;
    expect(r.title, 'ステージ1');
    expect(r.artist, 'Technosoft');
    final z = Uint8List.fromList(gzip.encode(b));
    expect(_parse(z)!.title, 'ステージ1');
  });

  test('unknown formats give null', () {
    expect(_parse(Uint8List.fromList(utf8.encode('hello world'))), isNull);
    expect(_parse(Uint8List(0)), isNull);
  });
}
