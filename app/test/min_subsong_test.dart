// Le seuil « sous-chansons trop courtes » (Réglages → Lecture).
//
// Un fichier à sous-chansons de JEU tient couramment plus de bruitages que de
// musique, dans la même table et sans rien qui les distingue. Les durées ci-
// dessous sont MESURÉES (sonde AdPlug sur les `.adl` du disque): DUNE19.ADL
// tient 43 sous-chansons vivantes dont trois seulement passent 5 s — 28 s,
// 36 s et 41 s, c'est-à-dire exactement sa musique.

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/min_subsong.dart';

int? _d(int? ms) => ms;

// Les six premières vivantes de DUNE19.ADL, en ms (mesurées).
const _dune19 = [28458, 36166, 41416, 444, 361, 1194, 138, 902];

void main() {
  test('le seuil écarte les bruitages et garde la musique', () {
    expect(filterShortSubsongs(_dune19, _d, minMs: 5000),
        [28458, 36166, 41416]);
  });

  test('0 désactive le filtre', () {
    expect(filterShortSubsongs(_dune19, _d, minMs: 0), _dune19);
  });

  test('une durée INCONNUE passe le filtre', () {
    // La moitié des moteurs ne sait pas dire la longueur d'une sous-chanson.
    // Écarter ce qu'on ne sait pas mesurer viderait des listes entières — et
    // c'est la même règle que partout ailleurs: null n'est PAS zéro.
    expect(filterShortSubsongs([null, 100, 9000], _d, minMs: 5000),
        [null, 9000]);
  });

  test('une durée NULLE est courte, pas inconnue', () {
    // Un slot qui mesure 0 ms n'est pas « non mesuré »: il ne joue rien.
    expect(filterShortSubsongs([0, 9000], _d, minMs: 5000), [9000]);
  });

  test('un filtre qui viderait la liste ne s\'applique pas', () {
    // Un fichier qui n'a QUE des morceaux courts doit rester jouable — même
    // garde-fou que le skip_broken_subsongs d'UADE.
    const allShort = [100, 200, 300];
    expect(filterShortSubsongs(allShort, _d, minMs: 5000), allShort);
  });

  test('une liste d\'UN élément n\'est pas une liste de sous-chansons', () {
    // C'est le fichier lui-même, et un fichier court reste un fichier.
    expect(filterShortSubsongs([100], _d, minMs: 5000), [100]);
  });

  mainQueue();
}

// ── Le filtre de FILE, et le grisé qui le reflète ───────────────────────────
//
// Le filtre vit au remplissage de la file, jamais dans un producteur de liste
// (voir min_subsong.dart). L'écran des sous-chansons GRISE ce qu'il écarterait
// — par la MÊME fonction, parce que les trois gardes (« même fichier »,
// « durée inconnue », « tout filtré ⇒ on ne filtre rien ») sont autant
// d'occasions pour un affichage recodé de mentir sur le comportement.

class _Row {
  const _Row(this.file, this.ms);
  final String file;
  final int? ms;
}

List<_Row> _rows(List<(String, int?)> xs) =>
    [for (final x in xs) _Row(x.$1, x.$2)];

(List<_Row>, int?) _q(List<_Row> rows, int? start, {int minMs = 5000}) =>
    filterQueueSubsongs<_Row>(rows, start,
        minMs: minMs, fileKey: (r) => r.file, durationMs: (r) => r.ms);

void mainQueue() {
  test('la file écarte les courtes et RECALE l\'index de départ', () {
    final rows = _rows([('a', 30000), ('a', 100), ('a', 40000)]);
    final (kept, start) = _q(rows, 2);
    expect(kept.length, 2);
    expect(start, 1, reason: 'la piste demandée a changé de position');
  });

  test('l\'entrée DEMANDÉE n\'est jamais écartée', () {
    // Taper une sous-chanson de 2 s doit la jouer — la faire disparaître sous
    // le doigt serait le pire comportement possible.
    final rows = _rows([('a', 30000), ('a', 2000), ('a', 40000)]);
    final (kept, start) = _q(rows, 1);
    expect(kept.length, 3);
    expect(start, 1);
  });

  test('un album de FICHIERS distincts n\'est pas concerné', () {
    // Un morceau court y est un morceau, pas un bruitage.
    final rows = _rows([('a', 30000), ('b', 100), ('c', 40000)]);
    final (kept, _) = _q(rows, null);
    expect(identical(kept, rows), isTrue);
  });

  test('le grisé est exactement ce que la file écarterait', () {
    final rows = _rows([('a', 30000), ('a', 100), ('a', 2000)]);
    final skipped = skippedQueueSubsongs<_Row>(rows,
        minMs: 5000, fileKey: (r) => r.file, durationMs: (r) => r.ms);
    final (kept, _) = _q(rows, null);
    expect(skipped.length, 2);
    expect(skipped.contains(rows[0]), isFalse);
    expect([for (final r in rows) if (!skipped.contains(r)) r], kept);
  });

  test('rien à griser quand rien n\'est écarté', () {
    // Y compris le cas « tout serait filtré »: la liste reste entière, donc
    // aucune ligne ne doit s'afficher comme écartée.
    final allShort = _rows([('a', 100), ('a', 200)]);
    expect(
        skippedQueueSubsongs<_Row>(allShort,
            minMs: 5000, fileKey: (r) => r.file, durationMs: (r) => r.ms),
        isEmpty);
  });
}
