import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

// Les compagnons (aux_files) portent depuis le miroir modland une quatrième
// clé, `mirror_url`. Le client doit la lire, la faire survivre à la
// persistance de la file (toJson/fromJson) et tolérer son absence — un
// serveur d'avant, ou une entrée réduite à un nom de fichier.
void main() {
  test('mirror_url est lu et conservé', () {
    final r = SearchResult.fromJson({
      'song_id': 'x', 'collection': 'modland', 'title': 'spd', 'filename': 'mdat.spd',
      'aux_files': [
        {
          'filename': 'Instruments/4th.L.d3.instr',
          'file_size': 128,
          'mirror_url': 'https://files.rewamp.app/modland/IFF-SMUS/x/Instruments/4th.L.d3.instr',
          'download_url': 'https://ftp.modland.com/pub/modules/IFF-SMUS/x/Instruments/4th.L.d3.instr',
        },
      ],
    });
    expect(r.auxFiles, hasLength(1));
    final a = r.auxFiles.single;
    expect(a.mirrorUrl, startsWith('https://files.rewamp.app/'));
    expect(a.downloadUrl, startsWith('https://ftp.modland.com/'));
    // Le sous-dossier fait partie de l'identité: jamais aplati.
    expect(a.filename, 'Instruments/4th.L.d3.instr');
    final back = SearchResult.fromJson(r.toJson());
    expect(back.auxFiles.single.mirrorUrl, a.mirrorUrl);
    expect(back.auxFiles.single.downloadUrl, a.downloadUrl);
  });

  test('sans mirror_url (serveur d\'avant), rien ne change', () {
    final r = SearchResult.fromJson({
      'song_id': 'x', 'collection': 'modland', 'title': 't', 'filename': 'mdat.t',
      'aux_files': [
        {'filename': 'smpl.t', 'download_url': 'https://ftp.modland.com/pub/modules/TFMX/smpl.t'},
        'bare.name',
      ],
    });
    expect(r.auxFiles.first.mirrorUrl, isNull);
    expect(r.auxFiles.first.downloadUrl, isNotNull);
    expect(r.auxFiles.last.downloadUrl, isNull);
    expect(r.toJson()['aux_files'], isA<List>());
  });
}
