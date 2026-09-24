// Le TRANSFERT d'un téléchargement, dans un isolate à part.
//
// ⚠️ Pourquoi un isolate: sous Linux (Flutter 3.47), l'isolate de l'UI tourne
// sur le fil PRINCIPAL, dont la boucle est celle de GTK. Chaque bloc reçu du
// socket et chaque écriture attendue y est un message qui attend son tour
// dans cette boucle — et elle n'en sert qu'une trentaine par seconde quand
// l'app est au repos. Mesuré le 2026-09-22 sur l'archive « WipEout » (86,7 Mo):
// **1,87 Mo/s, parfaitement plat pendant 46 s**, fil principal à 17 % — une
// CADENCE, pas une charge — contre 16,9 Mo/s pour curl et pour ce MÊME code
// exécuté hors de l'app (`flutter test`, boucle Dart native). Un isolate de
// fond a sa propre boucle Dart, qui ne dépend pas de celle de GTK.
//
// Seul le pompage des octets vit ici. L'orchestration (cookies d'interstitiel,
// rejeu, bannière, jeton d'annulation porté par la ZONE) reste chez
// l'appelant: une zone ne traverse pas une frontière d'isolate.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Ce que la réponse a dit AVANT le corps.
class FetchResponseHead {
  final int status;
  final int? contentLength;
  final String? setCookie;
  const FetchResponseHead(this.status, this.contentLength, this.setCookie);
}

/// Aucun en-tête de réponse dans le délai, deux fois de suite.
class FetchHeaderTimeout implements Exception {
  const FetchHeaderTimeout();
}

/// Échec du transfert, rapporté depuis l'isolate (le type d'origine ne
/// traverse pas: on garde son texte).
class FetchTransferException implements Exception {
  final String message;
  const FetchTransferException(this.message);
  @override
  String toString() => message;
}

class IsolateFetchResult {
  final int length;
  final Uint8List head;   // 512 premiers octets
  final Uint8List? bytes; // null quand on écrivait dans un fichier
  const IsolateFetchResult(this.length, this.head, this.bytes);
}

/// Un GET complet dans un isolate.
///
/// [filePath] non nul: le corps est écrit dans ce fichier (TRONQUÉ à
/// l'ouverture), sinon il revient en mémoire. [onHead] est appelé une fois,
/// avant le corps; un statut autre que 200 termine le transfert sans lire le
/// corps. [onProgress] reçoit le nombre d'octets reçus, au plus ~7 fois par
/// seconde. [registerCancel] reçoit la fonction qui interrompt le transfert.
Future<IsolateFetchResult> isolateFetch(
  String url, {
  String? cookie,
  String? filePath,
  required Duration headerTimeout,
  required Duration stallTimeout,
  required Duration cap,
  required void Function(FetchResponseHead) onHead,
  required void Function(int received) onProgress,
  required void Function(void Function() cancel) registerCancel,
}) async {
  final inbox = ReceivePort();
  final exits = ReceivePort();
  final errors = ReceivePort();
  final done = Completer<IsolateFetchResult>();
  SendPort? control;
  var cancelRequested = false;

  void fail(Object e) {
    if (!done.isCompleted) done.completeError(e);
  }

  registerCancel(() {
    cancelRequested = true;
    control?.send('cancel');
    // Pas de réponse attendue: l'appelant sait déjà POURQUOI ça s'arrête
    // (son jeton), il lui faut seulement que l'attente finisse.
    fail(const FetchTransferException('transfert annulé'));
  });

  inbox.listen((msg) {
    if (msg is SendPort) {
      control = msg;
      if (cancelRequested) msg.send('cancel');
      return;
    }
    final m = msg as Map;
    switch (m['t']) {
      case 'head':
        // Un rappel qui lève (statut refusé) est appelé depuis un écouteur de
        // port: son exception n'atteindrait jamais l'appelant. On arrête le
        // transfert et c'est CETTE exception que rend le futur.
        try {
          onHead(FetchResponseHead(
              m['status'] as int, m['len'] as int?, m['cookie'] as String?));
        } catch (e) {
          control?.send('cancel');
          fail(e);
        }
      case 'prog':
        onProgress(m['n'] as int);
      case 'done':
        final t = m['bytes'] as TransferableTypedData?;
        if (!done.isCompleted) {
          done.complete(IsolateFetchResult(m['n'] as int,
              m['head'] as Uint8List, t?.materialize().asUint8List()));
        }
      case 'hdrTimeout':
        fail(const FetchHeaderTimeout());
      case 'stall':
        fail(TimeoutException('aucun octet reçu en '
            '${stallTimeout.inSeconds} s'));
      case 'cap':
        fail(TimeoutException('download exceeded ${cap.inMinutes} min'));
      case 'err':
        fail(FetchTransferException(m['msg'] as String));
    }
  });
  errors.listen((e) => fail(FetchTransferException('isolate: $e')));
  // Un isolate qui meurt sans rien dire ne doit pas laisser l'appelant
  // attendre pour toujours.
  exits.listen((_) => fail(
      const FetchTransferException('isolate de téléchargement terminé')));

  try {
    await Isolate.spawn(
      _worker,
      _Job(inbox.sendPort, url, cookie, filePath, headerTimeout.inMilliseconds,
          stallTimeout.inMilliseconds, cap.inMilliseconds),
      onExit: exits.sendPort,
      onError: errors.sendPort,
      debugName: 'fetch',
    );
    return await done.future;
  } finally {
    inbox.close();
    exits.close();
    errors.close();
  }
}

class _Job {
  final SendPort out;
  final String url;
  final String? cookie;
  final String? filePath;
  final int headerMs, stallMs, capMs;
  const _Job(this.out, this.url, this.cookie, this.filePath, this.headerMs,
      this.stallMs, this.capMs);
}

Future<void> _worker(_Job job) async {
  final out = job.out;
  final control = ReceivePort();
  out.send(control.sendPort);
  final client = http.Client();
  var cancelled = false;
  control.listen((msg) {
    if (msg == 'cancel') {
      cancelled = true;
      client.close();   // interrompt aussi un transfert ARRÊTÉ
    }
  });

  RandomAccessFile? raf;
  try {
    http.Request req() {
      final r = http.Request('GET', Uri.parse(job.url));
      if (job.cookie != null) r.headers['cookie'] = job.cookie!;
      return r;
    }

    // Un socket à moitié établi ne se répare pas tout seul: une seconde
    // tentative sur une requête NEUVE (voir _kHeaderTimeout côté appelant).
    final headerTimeout = Duration(milliseconds: job.headerMs);
    http.StreamedResponse resp;
    try {
      resp = await client.send(req()).timeout(headerTimeout);
    } on TimeoutException {
      if (cancelled) return;
      try {
        resp = await client.send(req()).timeout(headerTimeout);
      } on TimeoutException {
        out.send({'t': 'hdrTimeout'});
        return;
      }
    }
    out.send({
      't': 'head',
      'status': resp.statusCode,
      'len': resp.contentLength,
      'cookie': resp.headers['set-cookie'],
    });
    if (resp.statusCode != 200) {
      out.send({'t': 'done', 'n': 0, 'head': Uint8List(0), 'bytes': null});
      return;
    }

    final head = BytesBuilder(copy: true);
    final mem = job.filePath == null ? BytesBuilder(copy: false) : null;
    // `writeFrom` attendu à CHAQUE bloc: c'est la contre-pression (un IOSink
    // tamponnerait sans limite si le disque est plus lent que le réseau). Ici
    // l'attente ne coûte plus rien — c'est la boucle native de cet isolate.
    if (job.filePath != null) {
      raf = await File(job.filePath!).open(mode: FileMode.write);
    }
    final deadline =
        DateTime.now().add(Duration(milliseconds: job.capMs));
    var n = 0;
    var lastNotify = DateTime.now();
    try {
      await for (final chunk in resp.stream
          .timeout(Duration(milliseconds: job.stallMs))) {
        final need = 512 - head.length;
        if (need > 0) {
          head.add(chunk.length <= need ? chunk : chunk.sublist(0, need));
        }
        n += chunk.length;
        if (raf != null) {
          await raf.writeFrom(chunk);
        } else {
          mem!.add(chunk);
        }
        final now = DateTime.now();
        if (now.isAfter(deadline)) {
          out.send({'t': 'cap'});
          return;
        }
        if (now.difference(lastNotify).inMilliseconds > 150) {
          lastNotify = now;
          out.send({'t': 'prog', 'n': n});
        }
      }
    } on TimeoutException {
      out.send({'t': 'stall'});
      return;
    }
    if (raf != null) {
      await raf.flush();
      await raf.close();
      raf = null;
    }
    out.send({
      't': 'done',
      'n': n,
      'head': head.toBytes(),
      'bytes': mem == null
          ? null
          : TransferableTypedData.fromList([mem.takeBytes()]),
    });
  } catch (e) {
    out.send({'t': 'err', 'msg': e.toString()});
  } finally {
    try {
      await raf?.close();
    } catch (_) {}
    client.close();
    control.close();
  }
}
