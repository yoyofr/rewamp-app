// Le sous-chant sur lequel un fichier veut qu'on DÉMARRE.
//
// Beaucoup de conteneurs ouvrent sur un bruitage, un jingle ou un écran-titre
// et désignent dans leur en-tête le vrai premier morceau. Le serveur le rend
// (`default_subsong` de get_sid_info / get_sap_info), mais l'en-tête est
// SOUS LA MAIN dès que le fichier est sur le disque: pas d'aller-retour, pas
// de trou de cache, et ça marche pour un fichier hors catalogue.
//
// ⚠️ Contrat de sortie: **0-based DENSE**, la valeur qu'on passe au moteur —
// le même contrat que le serveur. Les formats, eux, ne s'accordent pas: SID
// compte à partir de 1, SAP à partir de 0. La conversion se fait ICI, une
// fois, jamais chez l'appelant.

import 'dart:io';
import 'dart:typed_data';

/// Lit le sous-chant de départ dans l'en-tête de [path], ou null quand le
/// format ne le dit pas, que le fichier est illisible, ou que la valeur est
/// triviale (0 = le premier, l'immense majorité des fichiers).
Future<int?> defaultSubsongFromHeader(String path) async {
  final ext = path.split('.').last.toLowerCase();
  try {
    final f = File(path);
    if (!await f.exists()) return null;
    if (ext == 'sid' || ext == 'psid' || ext == 'rsid') {
      final raf = await f.open();
      try {
        final head = await raf.read(0x12);
        return _sidStartSong(head);
      } finally {
        await raf.close();
      }
    }
    if (ext == 'sap') {
      // En-tête TEXTE, lignes CRLF, terminé par 0xFF 0xFF. 1 Ko couvre
      // largement le plus bavard.
      final raf = await f.open();
      try {
        final head = await raf.read(1024);
        return _sapDefSong(head);
      } finally {
        await raf.close();
      }
    }
  } catch (_) {/* illisible: on ne devine pas */}
  return null;
}

/// PSID/RSID: `startSong` est un mot BIG-ENDIAN à l'offset 0x10, compté à
/// partir de 1 (0 signifie « non précisé »). Rendu en 0-based dense.
int? _sidStartSong(Uint8List head) {
  if (head.length < 0x12) return null;
  final magic = String.fromCharCodes(head.sublist(0, 4));
  if (magic != 'PSID' && magic != 'RSID') return null;
  final start = (head[0x10] << 8) | head[0x11];
  if (start <= 1) return null;      // 0 = non précisé, 1 = le premier
  return start - 1;
}

/// SAP: `DEFSONG n` dans l'en-tête texte, compté à partir de 0 — donc AUCUNE
/// conversion (l'y ajouter décalerait tout l'album d'un cran).
int? _sapDefSong(Uint8List head) {
  final magic = String.fromCharCodes(head.take(4).toList());
  if (magic != 'SAP\r' && magic != 'SAP\n') return null;
  final text = String.fromCharCodes(head.takeWhile((b) => b != 0xFF));
  for (final line in text.split(RegExp(r'\r\n|\r|\n'))) {
    final m = RegExp(r'^DEFSONG\s+(\d+)', caseSensitive: false)
        .firstMatch(line.trim());
    if (m != null) {
      final n = int.tryParse(m.group(1)!);
      return (n == null || n <= 0) ? null : n;
    }
  }
  return null;
}
