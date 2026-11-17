// « Annuler » doit atteindre la descente qu'un geste lance APRÈS (résolution
// des détails d'album d'abord) — et ce qu'un geste laisse derrière lui ne doit
// pas rester mort pour toujours (jw_psf « Wipeout », 2026-11-17).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/download_cancel.dart';
import 'package:rewamp/rewamp_db.dart';

void main() {
  test('annuler pendant la résolution annule la descente lancée ensuite',
      () async {
    final resolving = Completer<void>();
    final proceed = Completer<void>();
    final f = RewampDb.playPathScope(() async {
      resolving.complete();
      await proceed.future; // « détails d'album » en cours
      // La descente démarre APRÈS l'annulation: elle doit la voir.
      DownloadCancelToken.current!.throwIfCancelled('descente');
    });
    await resolving.future;
    RewampDb.cancelAmbientDownloads();
    proceed.complete();
    await expectLater(f, throwsA(isA<DownloadCancelledException>()));
  });

  test('après le geste, ses continuations retombent sur le jeton du moment',
      () async {
    final fired = Completer<DownloadCancelToken?>();
    await RewampDb.playPathScope(() async {
      // Un pré-téléchargement armé par la piste jouée, plus tard: un Timer
      // créé DANS le geste s'exécute dans sa zone.
      Timer(const Duration(milliseconds: 20),
          () => fired.complete(DownloadCancelToken.current));
    });
    RewampDb.cancelAmbientDownloads();
    expect(await fired.future, isNull);
  });

  test('un jeton de file (DownloadManager) reste celui de la chaîne', () async {
    final job = DownloadCancelToken();
    await job.run(() => RewampDb.playPathScope(() async {
          expect(identical(DownloadCancelToken.current, job), isTrue);
        }));
  });
}
