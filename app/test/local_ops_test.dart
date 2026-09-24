import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_ops.dart';

/// L'état d'une opération locale longue (import, suppression) vit hors de
/// tout écran, en PILE: un dépôt pendant un import ouvre une seconde opération
/// et la fin de l'une ne doit pas effacer l'autre.
void main() {
  test('pile: la plus récente est affichée, la fin rend la précédente', () {
    final ops = LocalOps.instance;
    expect(ops.current, isNull);
    ops.begin(LocalOpKind.import, name: 'a.zip');
    ops.begin(LocalOpKind.delete, name: 'dossier');
    expect(ops.current!.kind, LocalOpKind.delete);
    expect(ops.count, 2);
    ops.end();
    expect(ops.current!.name, 'a.zip');
    ops.end();
    expect(ops.current, isNull);
    ops.end();   // un `end` de trop ne casse rien
    expect(ops.count, 0);
  });

  test('une phase remet le compteur à zéro et pose le total', () {
    final ops = LocalOps.instance;
    ops.begin(LocalOpKind.import);
    ops.phase(LocalOpPhase.copying, total: 10);
    ops.progress(7);
    expect(ops.current!.done, 7);
    expect(ops.current!.total, 10);
    ops.phase(LocalOpPhase.registering, total: 3);
    expect(ops.current!.done, 0);
    expect(ops.current!.total, 3);
    ops.phase(LocalOpPhase.extracting);   // natif: total inconnu
    expect(ops.current!.total, isNull);
    ops.end();
  });

  test('la progression est écrêtée à dix notifications par seconde, '
      'mais un début, une phase et une fin passent toujours', () {
    final ops = LocalOps.instance;
    var n = 0;
    void l() => n++;
    ops.addListener(l);
    ops.begin(LocalOpKind.delete, name: 'x');           // 1
    ops.phase(LocalOpPhase.registering, total: 1000);   // 2
    for (var i = 0; i < 1000; i++) {
      ops.progress(i);
    }
    // Sans écrêtage: 1000 reconstructions du bandeau pour une seule boucle.
    expect(n, lessThan(20));
    ops.end();
    expect(n, greaterThanOrEqualTo(3));
    ops.removeListener(l);
  });
}
