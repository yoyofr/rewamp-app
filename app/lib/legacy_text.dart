// Le texte qu'on lit dans des FICHIERS — tags PSF, lignes de M3U — n'est pas
// forcément de l'UTF-8.
//
// Un tag PSF est du Shift-JIS sauf `utf8=` (mesuré sur 390 fichiers du disque:
// 150 portent du non-ASCII, AUCUN n'annonce `utf8`), et les playlists joshw le
// sont souvent aussi. Le moteur C le savait depuis le 2026-09-05
// (`rewamp_text_to_utf8`); le Dart avait TROIS lectures parallèles qui ne le
// savaient pas, chacune fausse à sa manière:
//
//   utf8.decode(allowMalformed)  → U+FFFD à chaque octet japonais
//   latin1.decode                → octets 0x80–0x9F = contrôles C1, SANS glyphe
//   String.fromCharCodes         → la même chose, et faux même pour de l'UTF-8
//
// Les deux dernières font des octets 0x80–0x9F des contrôles C1, sans glyphe;
// la première, des U+FFFD. Mesuré le 2026-09-21 sur de vrais tags Shift-JIS.
//
// ⚠️ Ce n'était PAS la cause des rectangles signalés le même jour sur
// « Aitakute… » — cru d'abord, démenti ensuite: ceux-là venaient du repli de
// police de Flutter sous Linux (voir font_fallback.dart), et l'album tient son
// artiste du SERVEUR, sans passer par ici. Le bug corrigé ici est réel, mais il
// ne se voit que sur un album SANS artiste serveur, ou sur un import local.
//
// ⚠️ La règle n'est PAS réécrite ici: elle est empruntée au moteur par FFI
// (`rewamp_decode_text`). Deux décodeurs Shift-JIS finiraient par diverger —
// c'est exactement ce qui avait produit le bug.

import 'dart:convert';

import 'package:rewamp_audio/rewamp_audio.dart';

/// Décode UNE ligne non-UTF-8. `null` = pas de décodeur disponible.
typedef LegacyLineDecoder = String? Function(List<int> line);

/// Décode le texte d'un fichier LIGNE PAR LIGNE.
///
/// ⚠️ Ligne par ligne, et pas d'un bloc: CP932 s'arrête au premier octet
/// indécodable, donc un bloc entier perdrait tout ce qui le suit — un seul
/// octet abîmé dans le titre effacerait l'artiste trois lignes plus bas.
/// Couper sur 0x0A est sûr en Shift-JIS: ses octets de queue sont dans
/// 0x40–0xFC, jamais 0x0A ni 0x0D.
///
/// Une ligne déjà en UTF-8 valide passe telle quelle (c'est aussi la règle du
/// moteur, et ce qui couvre les PSF marqués `utf8=`). Sans décodeur, on retombe
/// sur l'ancien comportement plutôt que de lever.
String decodeFileText(List<int> bytes, {LegacyLineDecoder? lineDecoder}) {
  final decode = lineDecoder ?? _engineDecoder;
  final out = StringBuffer();
  var start = 0;
  for (var i = 0; i <= bytes.length; i++) {
    if (i < bytes.length && bytes[i] != 0x0A) continue;
    if (start > 0) out.write('\n');
    out.write(_decodeLine(bytes.sublist(start, i), decode));
    start = i + 1;
  }
  return out.toString();
}

String _decodeLine(List<int> line, LegacyLineDecoder decode) {
  if (line.every((b) => b < 0x80)) return String.fromCharCodes(line);
  try {
    return utf8.decode(line); // UTF-8 VALIDE: tel quel
  } on FormatException {
    return decode(line) ?? utf8.decode(line, allowMalformed: true);
  }
}

// Le moteur, créé à la PREMIÈRE ligne non-UTF-8 et jamais avant: la plupart
// des fichiers sont en ASCII et n'en ont pas besoin. Un échec (hôte de test
// Dart sans bibliothèque native) est mémorisé et donne le repli.
RewampAudio? _engine;
bool _engineTried = false;

String? _engineDecoder(List<int> line) {
  if (!_engineTried) {
    _engineTried = true;
    try {
      _engine = RewampAudio();
    } catch (_) {
      _engine = null;
    }
  }
  return _engine?.decodeLegacyLine(line);
}
