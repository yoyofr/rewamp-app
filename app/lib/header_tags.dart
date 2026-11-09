// Titre et auteur lus dans l'EN-TÊTE d'un fichier, sans moteur.
//
// Sert à l'IMPORT local: sans ça une piste importée ne portait que son nom de
// fichier jusqu'à sa première lecture (le moteur publie ses tags à
// l'ouverture). Ouvrir un décodeur par fichier importé n'est pas une option —
// des centaines de fichiers, des moteurs singleton, et un module Amiga
// malformé TUE l'app (UADE tourne dans notre processus). Les formats dont le
// titre tient à une position fixe de l'en-tête se lisent ici, en Dart pur;
// les autres gardent le nom de fichier, comme avant.
//
// La reconnaissance se fait à la MAGIE, jamais à l'extension: un nom Amiga
// porte son format avant le point, et une extension peut mentir.
//
// Le texte est décodé par `decodeFileText` (UTF-8 valide tel quel, sinon la
// règle Shift-JIS du moteur), sauf le SID, dont la spécification fixe le
// Latin-1, et le GD3 des VGM, en UTF-16LE.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'legacy_text.dart';

class HeaderTags {
  final String? title;
  final String? artist;
  const HeaderTags({this.title, this.artist});
  bool get isEmpty => title == null && artist == null;
}

/// Combien d'octets d'en-tête suffisent à tous les formats sauf le VGM, dont
/// le GD3 est en FIN de fichier (MOD: signature en 1080; NSFe: `auth` après
/// `INFO` et souvent `BANK`).
const kHeaderTagsProbeBytes = 4096;

/// Au-delà, un VGM n'est pas lu en entier pour son GD3 (l'import reste rapide).
const kVgmTagsMaxBytes = 8 * 1024 * 1024;

/// Lit les tags d'en-tête de [path]; `null` si le format n'en a pas ou si la
/// lecture échoue (jamais d'exception: c'est un bonus d'import).
Future<HeaderTags?> readHeaderTagsFromFile(String path,
    {LegacyLineDecoder? lineDecoder}) async {
  try {
    final f = File(path);
    final len = await f.length();
    final raf = await f.open();
    Uint8List head;
    try {
      head = await raf.read(kHeaderTagsProbeBytes);
    } finally {
      await raf.close();
    }
    final vgm = _isVgm(head) || _isGzip(head);
    if (vgm && len <= kVgmTagsMaxBytes) {
      head = await f.readAsBytes();
    }
    return parseHeaderTags(head, lineDecoder: lineDecoder);
  } catch (_) {
    return null;
  }
}

/// Le cœur PUR: [bytes] = le début du fichier (ou tout le fichier pour un
/// VGM/VGZ).
HeaderTags? parseHeaderTags(Uint8List bytes, {LegacyLineDecoder? lineDecoder}) {
  String? text(int off, int len) =>
      _clean(_decode(_cstr(bytes, off, len), lineDecoder));
  String? latin(int off, int len) =>
      _clean(latin1.decode(_cstr(bytes, off, len)));

  HeaderTags? out;
  if (_magic(bytes, 0, 'PSID') || _magic(bytes, 0, 'RSID')) {
    // PSID v1+: nom 0x16, auteur 0x36, 32 octets chacun, Latin-1.
    out = HeaderTags(title: _sidField(latin(0x16, 32)),
        artist: _sidField(latin(0x36, 32)));
  } else if (_magic(bytes, 0, 'NESM\x1A')) {
    out = HeaderTags(title: text(0x0E, 32), artist: text(0x2E, 32));
  } else if (_magic(bytes, 0, 'NSFE')) {
    out = _nsfe(bytes, lineDecoder);
  } else if (_magic(bytes, 0, 'GBS') && bytes.length > 0x50) {
    out = HeaderTags(title: text(0x10, 32), artist: text(0x30, 32));
  } else if (_magic(bytes, 0, 'SNES-SPC700 Sound File Data')) {
    out = _spc(bytes, text);
  } else if (_magic(bytes, 0, 'Extended Module: ')) {
    out = HeaderTags(title: text(17, 20));
  } else if (_magic(bytes, 0x2C, 'SCRM')) {
    out = HeaderTags(title: text(0, 28));
  } else if (_magic(bytes, 0, 'IMPM')) {
    out = HeaderTags(title: text(4, 26));
  } else if (_isModSignature(bytes)) {
    out = HeaderTags(title: text(0, 20));
  } else if (_isVgm(bytes) || _isGzip(bytes)) {
    out = _vgm(bytes);
  }
  return (out == null || out.isEmpty) ? null : out;
}

HeaderTags? _spc(Uint8List b, String? Function(int, int) text) {
  // 0x23 == 26: l'en-tête ID666 est présent.
  if (b.length < 0xD1 || b[0x23] != 26) return null;
  final song = text(0x2E, 32);
  final game = text(0x4E, 32);
  // ID666 TEXTE ou BINAIRE: en texte, 0xA9..0xB0 ne portent que des chiffres
  // (durée, fondu) ou des zéros, et l'artiste commence en 0xB1; en binaire,
  // ce sont des entiers et l'artiste commence en 0xB0.
  var textual = true;
  for (var i = 0xA9; i <= 0xB0; i++) {
    final c = b[i];
    if (c != 0 && (c < 0x30 || c > 0x39)) {
      textual = false;
      break;
    }
  }
  return HeaderTags(
      title: song ?? game, artist: text(textual ? 0xB1 : 0xB0, 32));
}

/// NSFe: des blocs `[taille u32][id 4][données]`; `auth` porte jeu, auteur,
/// copyright, ripper — chaînes terminées par 0. Il arrive tôt (après `INFO`),
/// donc l'en-tête lu suffit d'ordinaire; sinon, rien.
HeaderTags? _nsfe(Uint8List b, LegacyLineDecoder? lineDecoder) {
  final bd = ByteData.sublistView(b);
  var off = 4;
  while (off + 8 <= b.length) {
    final size = bd.getUint32(off, Endian.little);
    final id = String.fromCharCodes(b.sublist(off + 4, off + 8));
    final data = off + 8;
    if (id == 'auth') {
      final end = (data + size).clamp(0, b.length);
      final fields = <String?>[];
      var start = data;
      for (var i = data; i < end && fields.length < 2; i++) {
        if (b[i] == 0) {
          fields.add(_clean(_decode(b.sublist(start, i), lineDecoder)));
          start = i + 1;
        }
      }
      if (fields.isEmpty) return null;
      return HeaderTags(
          title: fields[0], artist: fields.length > 1 ? fields[1] : null);
    }
    if (id == 'NEND') return null;
    off = data + size;
  }
  return null;
}

HeaderTags? _vgm(Uint8List b) {
  var data = b;
  if (_isGzip(b)) {
    try {
      data = Uint8List.fromList(gzip.decode(b));
    } catch (_) {
      return null;
    }
  }
  if (!_isVgm(data) || data.length < 0x18) return null;
  final bd = ByteData.sublistView(data);
  final rel = bd.getUint32(0x14, Endian.little);
  if (rel == 0) return null;
  final off = 0x14 + rel;
  if (off + 12 > data.length || !_magic(data, off, 'Gd3 ')) return null;
  final size = bd.getUint32(off + 8, Endian.little);
  final end = (off + 12 + size).clamp(0, data.length);
  // Onze chaînes UTF-16LE terminées par 0: piste EN/JP, jeu EN/JP, système
  // EN/JP, auteur EN/JP, date, ripper, notes.
  final strings = <String>[];
  var cur = <int>[];
  for (var i = off + 12; i + 1 < end && strings.length < 8; i += 2) {
    final u = data[i] | (data[i + 1] << 8);
    if (u == 0) {
      strings.add(String.fromCharCodes(cur));
      cur = <int>[];
    } else {
      cur.add(u);
    }
  }
  String? pick(int en) => en + 1 < strings.length
      ? (_clean(strings[en]) ?? _clean(strings[en + 1]))
      : (en < strings.length ? _clean(strings[en]) : null);
  return HeaderTags(title: pick(0), artist: pick(6));
}

bool _isVgm(Uint8List b) => _magic(b, 0, 'Vgm ');
bool _isGzip(Uint8List b) => b.length > 2 && b[0] == 0x1F && b[1] == 0x8B;

/// Les signatures ProTracker et compagnie à l'offset 1080.
bool _isModSignature(Uint8List b) {
  if (b.length < 1084) return false;
  final sig = String.fromCharCodes(b.sublist(1080, 1084));
  return const {'M.K.', 'M!K!', 'FLT4', 'FLT8', '4CHN', '6CHN', '8CHN',
          'CD81', 'OKTA', 'OCTA', 'TDZ4'}
          .contains(sig) ||
      RegExp(r'^\d\dCH$').hasMatch(sig) ||
      RegExp(r'^\dCHN$').hasMatch(sig);
}

bool _magic(Uint8List b, int off, String m) {
  if (b.length < off + m.length) return false;
  for (var i = 0; i < m.length; i++) {
    if (b[off + i] != m.codeUnitAt(i)) return false;
  }
  return true;
}

/// Un champ de taille fixe, coupé au premier zéro.
List<int> _cstr(Uint8List b, int off, int len) {
  if (off >= b.length) return const [];
  final end = (off + len).clamp(0, b.length);
  var i = off;
  while (i < end && b[i] != 0) {
    i++;
  }
  return b.sublist(off, i);
}

String _decode(List<int> bytes, LegacyLineDecoder? lineDecoder) =>
    decodeFileText(bytes, lineDecoder: lineDecoder);

/// Espaces et contrôles retirés; un champ sans lettre ni chiffre ne nomme
/// rien (bourrage, tirets, points).
String? _clean(String s) {
  // Contrôles retirés et espaces RÉDUITS: un titre de module aligne
  // souvent ses mots à coups d'espaces (« $$$   dantro   $$$ »).
  final t = s
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (t.isEmpty) return null;
  if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(t)) return null;
  return t;
}

/// HVSC écrit `<?>` pour un champ inconnu.
String? _sidField(String? s) => (s == null || s == '<?>') ? null : s;
