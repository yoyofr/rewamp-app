import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/rewamp_db.dart';

/// « Inside The BORG Cube » (sceneorg) ne jouait pas, et le mp3 n'était nulle
/// part sur le disque. Le serveur ne rend plus QUE l'override pour ce song_id
/// — `search_music`, `browse_music` et `get_song_context` renvoient les trois
/// la même url `files.rewamp.app/overrides/…mp3` —, mais l'entrée de
/// BIBLIOTHÈQUE portait encore celle que `user_songs` avait à l'écriture: le
/// zip scene.org d'origine, qui ne contient qu'un `.xex` Atari et deux `.txt`.
///
/// Jouer depuis la bibliothèque repartait donc sur l'archive, et
/// `_purgeIfSourceUrlChanged` — voyant deux urls pour un même song_id —
/// concluait « remplacé côté serveur » puis EFFAÇAIT le mp3 qui venait d'être
/// téléchargé. 3,9 Mo re-téléchargés à chaque lecture.
void main() {
  const origin = 'https://files.scene.org/get/parties/2023/x/fosterzlx_borg.zip';
  const override = 'https://files.rewamp.app/overrides/sceneorg/abc.mp3';

  test('nom jouable + url d\'archive = ligne périmée', () {
    expect(
        RewampDb.rowLooksStaleAgainstOverride(origin, 'fosterzlx_borg.mp3'),
        isTrue);
  });

  test('un vrai album-archive n\'est PAS une contradiction', () {
    // La ligne s'annonce elle-même comme une archive: son url d'archive est
    // légitime. Sans ce garde-fou, tout album conteneur serait détourné.
    expect(
        RewampDb.rowLooksStaleAgainstOverride(origin, 'eightbm_chipcompo.zip'),
        isFalse);
  });

  test('une ligne déjà sur l\'override ne déclenche rien', () {
    expect(
        RewampDb.rowLooksStaleAgainstOverride(override, 'fosterzlx_borg.mp3'),
        isFalse);
  });

  test('une url de fichier simple ne déclenche rien', () {
    expect(
        RewampDb.rowLooksStaleAgainstOverride(
            'https://ftp.modland.com/pub/modules/Protracker/x/borg.mod',
            'borg.mod'),
        isFalse);
  });

  test('le cache-buster ne masque pas l\'extension de l\'archive', () {
    expect(
        RewampDb.rowLooksStaleAgainstOverride(
            '$origin?rcb=1788031187992', 'fosterzlx_borg.mp3'),
        isTrue);
  });

  test('url absente ou vide: rien à décider', () {
    expect(RewampDb.rowLooksStaleAgainstOverride(null, 'x.mp3'), isFalse);
    expect(RewampDb.rowLooksStaleAgainstOverride('', 'x.mp3'), isFalse);
  });
}
