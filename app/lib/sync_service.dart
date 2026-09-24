import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show DatabaseExecutor;

import 'local_db.dart';
import 'playlist_sync.dart';
import 'rewamp_db.dart';
import 'user_settings.dart';

/// Background synchronisation of everything the account holds: library
/// (favourites), playlists, and the client organisation state.
///
/// Two rules shape it:
///
///  * **A user gesture is never lost.** Adding or removing a favourite writes to
///    the local DB *and* to [LocalDb.queueLibraryChange]; the queue is drained
///    when the network allows. A fire-and-forget POST — what the app did before
///    — silently dropped the change when offline, on a 500, or when the app was
///    killed mid-request.
///  * **Nothing blocks the UI.** Every entry point is fire-and-forget and
///    coalesced: several triggers arriving together (launch, resume, a burst of
///    favourites) produce ONE run.
///
/// Runs are serialised by [_running]: two concurrent syncs would push the same
/// queued changes twice and could interleave a push with a pull of the same
/// playlist.
/// What becomes of the device's local library and playlists when the account
/// it speaks for changes.
enum LocalDataAction {
  /// Queue them for the new account (the device carries a library; joining an
  /// account adds it — the server's own merge model).
  publish,
  /// Leave them on the device and push nothing (sign-out: the destination is
  /// not decided yet).
  keepUnpublished,
  /// Delete them locally, so the joined account's data takes their place.
  drop,
}

class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  bool _running = false;
  /// Set while a run is in flight and another trigger arrived — one more run is
  /// scheduled instead of being dropped.
  bool _again = false;
  /// touch_device (mig 204) has been sent this app run.
  bool _devicePinged = false;
  Timer? _debounce;
  Timer? _retry;
  DateTime? _lastSuccess;
  String? _lastError;
  /// Consecutive failures — the app has no connectivity listener, so a failed
  /// run schedules its own retry with a growing delay. That IS the "network is
  /// back" trigger: the queue holds the gestures meanwhile.
  int _failures = 0;

  bool get isRunning => _running;
  DateTime? get lastSuccess => _lastSuccess;
  String? get lastError => _lastError;

  /// Coalescing trigger for a mutation (favourite toggled, playlist edited):
  /// waits [delay] so a burst of gestures results in one run.
  void nudge({Duration delay = const Duration(seconds: 5)}) {
    _debounce?.cancel();
    _debounce = Timer(delay, () => unawaited(syncNow()));
  }

  /// Trigger for a lifecycle moment (launch, back to foreground). Immediate,
  /// but skipped when a successful run just happened and nothing is queued:
  /// macOS/iOS deliver `resumed` AT LAUNCH too, so the launch nudge and the
  /// lifecycle callback produced two full rounds every time.
  void kick() => unawaited(_kickThrottled());

  Timer? _poll;

  /// Au-delà, la prochaine passe est COMPLÈTE (cumuls d'écoute, noms des
  /// pistes du compte, organisation, matérialisation des albums favoris).
  static const _kFullEvery = Duration(minutes: 2);

  /// Dernière passe complète — les passes légères ne la font pas avancer.
  DateTime? _lastFullRun;

  /// Foreground heartbeat. Without it the only pulls were launch and
  /// `resumed`, so two devices left OPEN side by side never saw each other: a
  /// favourite added on the phone reached the account immediately and the
  /// desktop app, never backgrounded, kept showing the old library until it was
  /// restarted. A run is a delta (cursor-scoped) plus one client-state read, so
  /// this stays cheap; it is stopped as soon as the app leaves the foreground.
  /// Cadence LÉGÈRE (voir [syncNow]): c'est le délai au bout duquel un geste
  /// fait sur un autre appareil apparaît ici. 90 s se sentait comme une panne
  /// — on attendait, on relançait l'app pour forcer. Le battement complet, lui,
  /// garde son rythme: [_kFullEvery].
  void startPolling({Duration every = const Duration(seconds: 20)}) {
    if (_poll != null) return;
    _poll = Timer.periodic(every, (_) {
      // An ANONYMOUS account lives on exactly one device: with no email there
      // is no way to sign into it anywhere else, so nothing server-side can
      // change that this device did not do itself. Polling it would only ever
      // read back our own writes. The launch/resume kick still runs (it drains
      // whatever the queue holds and heals a stale local state); this is the
      // repeated pull that has no reason to exist. Checked per tick, not at
      // start, so attaching an email begins the heartbeat without a restart.
      if (!UserSettings.instance.accountHasEmail) return;
      // A run in flight, or one that just finished, needs no help.
      if (_running) return;
      final last = _lastSuccess;
      if (last != null && DateTime.now().difference(last) < every ~/ 2) return;
      // Une passe complète de temps en temps, des passes légères entre-deux.
      final lastFull = _lastFullRun;
      final needFull = lastFull == null ||
          DateTime.now().difference(lastFull) > _kFullEvery;
      unawaited(syncNow(light: !needFull));
    });
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _kickThrottled() async {
    final last = _lastSuccess;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 1) &&
        await LocalDb.instance.pendingSyncCount() == 0) {
      return;
    }
    await syncNow();
  }

  /// Backoff after a failed run: 30 s, 1 min, 2, 4, 8, capped at 15 min. Being
  /// offline is the normal case here, so the retries must not become a
  /// battery-eating poll.
  void _scheduleRetry() {
    _retry?.cancel();
    final seconds = (30 * (1 << (_failures - 1).clamp(0, 5))).clamp(30, 900);
    debugPrint('[SyncService] retry in ${seconds}s');
    _retry = Timer(Duration(seconds: seconds), () => unawaited(syncNow()));
  }

  /// One full pass. Never throws — a sync failure is not the user's problem,
  /// the queue keeps what could not be delivered.
  /// Passe LÉGÈRE: uniquement ce qu'un autre appareil vient peut-être de
  /// changer et qu'on veut voir tout de suite — les gestes en attente partent,
  /// les deltas bibliothèque/playlists et la timeline du compte redescendent.
  /// Quatre appels au plus, tous bornés par un curseur.
  ///
  /// Le reste (cumuls d'écoute, noms des pistes du compte, état
  /// d'organisation, réconciliation complète, matérialisation des albums) ne
  /// bouge pas d'une seconde à l'autre et reste sur la cadence lente: sans ce
  /// partage, accélérer le battement multipliait une dizaine d'appels au lieu
  /// de quatre.
  Future<void> syncNow({bool force = false, bool light = false}) async {
    // The TOKEN authorizes, not the uuid — a device that failed to register (or
    // whose account predates migration 188) would otherwise send a full round
    // of calls that all answer 42501 / empty list.
    if (!UserSettings.instance.hasAuthToken) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    notifyListeners();
    try {
      // Once per app run, not per sync — the row is keyed (account, OS, model)
      // and only its last_seen_at moves.
      if (!_devicePinged) {
        _devicePinged = true;
        unawaited(RewampDb.touchDevice());
      }
      // « Ce compte a-t-il un e-mail ? » se RÉSOUT ici, pas seulement quand
      // l'utilisateur ouvre l'écran Compte — qui était le seul écrivain de ce
      // drapeau. Absent, il valait `false`, et deux choses en dépendent:
      // startPolling coupe le battement pour un compte réputé anonyme (donc un
      // vrai compte ne synchronisait plus tout seul), et l'écran Données
      // proposait « renouveler l'identifiant », qui ABANDONNE le compte. Une
      // requête, une fois dans la vie de l'installation, au moment où l'on
      // parle déjà au serveur.
      if (!UserSettings.instance.accountHasEmailKnown) {
        final acc = await RewampDb.getAccount();
        if (acc != null) {
          UserSettings.instance.accountHasEmail = !acc.isAnonymous;
        }
      }
      // Order matters. Local gestures FIRST, so what this device decided is
      // already server-side before anything is pulled back on top of it.
      await _drainOutbox();
      await _drainExtPlays();
      if (light) {
        // Les deux deltas qui portent ce qu'un autre appareil vient de faire.
        await PlaylistSync.pull(
            since: UserSettings.instance.playlistCursor, reconcile: false);
        await _pullLibrary();
        await _pullPlayHistoryMirror();
        _lastSuccess = DateTime.now();
        _lastError = null;
        _failures = 0;
        return;
      }
      await PlaylistSync.pushAll();
      // Playlist content: delta on the cursor, and a full pass on the same
      // cadence as the library reconciliation — a deleted playlist leaves no
      // tombstone, only the full list shows it is gone.
      final plCursor = UserSettings.instance.playlistCursor;
      final full = plCursor == null ||
          (UserSettings.instance.libraryReconciledAt == null) ||
          DateTime.now()
                  .difference(UserSettings.instance.libraryReconciledAt!) >
              const Duration(hours: 12);
      await PlaylistSync.pull(since: plCursor, reconcile: full);
      await PlaylistSync.syncLibraryPlaylists();
      await _pullLibrary();
      // Après la bibliothèque: les cumuls d'écoute ne transitent par AUCUN
      // delta existant (une écoute ne touche pas updated_at) — RPC dédié.
      await _pullPlayStats();
      // Puis la TIMELINE du compte dans son miroir local: c'est elle, et pas
      // les cumuls, qui permet à l'écran Stats de fusionner les écoutes de
      // tous les appareils sur une période donnée.
      await _pullPlayHistoryMirror();
      await _nameAccountTracks();
      // Le ♥ N'EST PLUS synchronisé ici: depuis la migration serveur 206 c'est
      // une COLONNE des tables de bibliothèque, appliquée par _pullLibrary avec
      // le reste. Le blob `user_state.favourites` n'est plus ni lu ni écrit —
      // il était opaque, réécrit en entier (donc deux appareils qui aimaient en
      // même temps se perdaient un ♥) et inutilisable pour le scoring serveur.
      // Le serveur ne l'efface pas (contrat d'opacité); _purgeFavouritesBlob
      // s'en charge une fois, côté client.
      final state = await RewampDb.getUserState(
          keys: const [PlaylistSync.kFoldersKey]);
      await _purgeFavouritesBlob();
      // Un ♥ d'album reste invisible tant que sa tracklist n'est pas
      // matérialisée (les écrans lisent à travers `tracks`) — indépendant du
      // transport du ♥, donc conservé tel quel.
      await _healAlbumFavourites();
      // The organisation can only file what is already here → last.
      await PlaylistSync.syncOrganisation(state: state);
      _lastSuccess = DateTime.now();
      _lastFullRun = DateTime.now();
      _lastError = null;
      _failures = 0;
      _retry?.cancel();
      _retry = null;
    } catch (e) {
      _lastError = e.toString();
      _failures++;
      _scheduleRetry();
      debugPrint('[SyncService] run failed (attempt $_failures): $e');
    } finally {
      _running = false;
      notifyListeners();
    }
    if (_again) {
      _again = false;
      await syncNow();
    }
  }

  /// Re-binds this device's local data to whatever account it speaks for NOW,
  /// and returns how many library items were queued for delivery.
  ///
  /// Call it on EVERY change of account, whichever way it happened:
  ///  * the token migration (the old anonymous uuid can no longer be proven);
  ///  * signing out (the device takes a fresh anonymous account);
  ///  * signing IN to a different account on the same device.
  ///
  /// Without it the local state keeps referring to the previous account, and
  /// each leftover breaks something quietly: the delta cursor makes the new
  /// account's older rows invisible for ever, a playlist still linked to the
  /// old owner answers `42501 not your playlist` on every push, and the
  /// library the device holds never reaches the account it now belongs to.
  ///
  /// The device's own data is NEVER destroyed here — it is re-published. That
  /// matches the server's merge model: a device carries a library, and joining
  /// an account adds it ("tes favoris locaux ont été ajoutés"). Delivery goes
  /// through the outbox, so it is bounded, retried and offline-safe, and every
  /// apply is idempotent.
  Future<int> rebindLocalDataToCurrentAccount(
      {LocalDataAction action = LocalDataAction.publish}) async {
    // The cursors and the server links belong to the PREVIOUS account.
    // - cursors: a delta asked with them would skip nothing (the new rows are
    //   newer), but a full reconciliation must run once, so clear the marker;
    // - playlist links: the account copy they point at is now someone else's
    //   as far as the server is concerned — every push would raise
    //   `42501 not your playlist` for ever. Unlink LOCALLY (never delete: the
    //   old copy is not ours to remove) so each playlist is re-created.
    UserSettings.instance.libraryCursor       = null;
    UserSettings.instance.playlistCursor      = null;
    // Curseur nul = le prochain sync refait AUSSI le rejeu d'historique ext
    // (nouveau compte, nouvelle timeline).
    UserSettings.instance.playStatsCursor     = null;
    UserSettings.instance.libraryReconciledAt = null;
    // La timeline tenue ici est celle du compte QUITTÉ: la jeter, et rendre
    // aux écoutes locales leur pushed = 0 — plus rien ne les représente.
    UserSettings.instance.playHistoryCursor     = null;
    UserSettings.instance.playHistoryBackfilled = false;
    await LocalDb.instance.clearAccountPlayHistory();
    for (final pl in await LocalDb.instance.getPlaylists()) {
      if (pl.isSynced) {
        await LocalDb.instance.setPlaylistServerLink(pl.id, null);
      }
    }

    // "Start clean on this device": the user chose NOT to carry the previous
    // account's favourites and playlists into the new one. They have to go
    // BEFORE the first sync, or the outbox and the client-state merge would
    // publish them anyway. Deliberately narrow — this is account data, so
    // downloaded files, the tracks table and the listening history stay: they
    // are the device's, not the account's.
    if (action == LocalDataAction.keepUnpublished) {
      // Signing out: the device keeps everything, but nothing is pushed to the
      // fresh anonymous account. That matters — publishing it there would put
      // it back on the server, and `verify_login_code` MERGES the device's
      // account into the one it joins, so the data the user chose to leave
      // behind at the next sign-in would arrive through the back door. Where it
      // goes is decided at sign-in, not here.
      debugPrint('[SyncService] local data kept, unpublished (signed out)');
      return 0;
    }
    if (action == LocalDataAction.drop) {
      var wiped = 0;
      for (final item in await LocalDb.instance.getLibraryItems()) {
        await LocalDb.instance.removeFromLibrary(item.type, item.refId);
        wiped++;
      }
      for (final pl in await LocalDb.instance.getPlaylists()) {
        await LocalDb.instance.deletePlaylist(pl.id);
        wiped++;
      }
      debugPrint('[SyncService] clean switch: $wiped local account item(s) '
          'dropped; the joined account will fill them back in');
      return 0;
    }

    // Pull BEFORE anything is pushed. Signing into an account merges this
    // device's playlists into it server-side, and the local copies were just
    // unlinked above — while syncNow pushes before it pulls. Left alone, the
    // next sync therefore re-creates every playlist the merge had already
    // carried over: two copies in the account and two on the device, once more
    // per sign-in (four "testo" here). Pulling now, while they are still
    // orphans, lets each of them re-link to the copy that came with the merge
    // (PlaylistSync.pull's adoption step); the later push then updates it.
    try {
      await PlaylistSync.pull();
    } catch (e) {
      debugPrint('[SyncService] adoption pull failed: $e');
    }

    var queued = 0;
    for (final item in await LocalDb.instance.getLibraryItems()) {
      final refId = item.refId;
      switch (item.type) {
        case 'track':
          final (base, subsong) = splitLibraryRefId(refId);
          // A path-like ref_id is a local file: no catalogue identity, and the
          // ext-snapshot form needs data this loop does not have. Skipped —
          // it was never on the server either.
          if (base.isEmpty || base.startsWith('/') || base.contains(':\\')) {
            continue;
          }
          await LocalDb.instance.queueLibraryChange(
            itemType: 'song', itemId: catalogueSongId(base) ?? base,
            value: true, subsongIdx: subsong ?? 0);
          queued++;
        case 'album':
          final id = item.albumId;
          if (id == null || id.isEmpty) continue;   // local folder, no identity
          await LocalDb.instance.queueLibraryChange(
            itemType: 'album', itemId: id, value: true);
          queued++;
        case 'playlist':
          // A saved SERVER playlist: the id is the playlist's own uuid.
          if (refId.isEmpty) continue;
          await LocalDb.instance.queueLibraryChange(
            itemType: 'playlist', itemId: refId, value: true);
          queued++;
        default:
          continue;   // 'artist' has no server-side library counterpart
      }
    }
    return queued;
  }

  /// Delivers the queued library changes. A change is deleted only once the
  /// server has taken it; anything else stays for the next run.
  ///
  /// The `updated_at` each write returns is deliberately NOT used to advance
  /// the delta cursor: our own write carries a LATER timestamp than another
  /// device's change we have not pulled yet, so jumping the cursor to it would
  /// skip that change for ever. Letting the next delta return our own rows once
  /// costs nothing — every apply is idempotent.
  /// Gestes livrés EN PARALLÈLE par le drain. `set_library` ne prend qu'un
  /// item par appel, donc vider une file de plusieurs centaines d'entrées —
  /// « tout supprimer » dans Données → Stockage en produit une par fichier —
  /// coûtait autant d'allers-retours SÉQUENTIELS. Six en vol masquent la
  /// latence sans ressembler à une rafale.
  static const int _kOutboxConcurrency = 6;

  /// Cadence de livraison de l'outbox et recul sur 429.
  ///
  /// L'API est derrière un `limit_req` nginx à 60 req/min, rafale 20 (voir
  /// docs/server_auth_proposal.md). Importer puis supprimer un dossier de
  /// plusieurs centaines de pistes en local fait autant de `set_library`:
  /// six en vol sans cadence, quatre passes, et le serveur répondait 429 par
  /// centaines (macOS, 2026-09-08). Rien n'était perdu — la ligne reste dans
  /// l'outbox, `attempts` ne fait que compter — mais on martelait, et chaque
  /// passe rejouait les mêmes refus. Donc: un créneau global d'environ
  /// 1,1 s entre deux livraisons (≈ 55/min, le reste du budget aux pulls), et
  /// au premier 429 le drain S'ARRÊTE pour 65 s (la fenêtre nginx), reprise
  /// programmée. La vraie parade est un `set_library_batch` côté serveur
  /// (docs/set_library_batch_proposal.md): 300 gestes = un appel.
  static const Duration _kOutboxMinGap = Duration(milliseconds: 1100);
  static const Duration _kRateLimitCooldown = Duration(seconds: 65);
  DateTime _outboxNextSlot = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _rateLimitedUntil;

  /// `set_library_batch` (mig serveur 271): null = pas encore su, false = le
  /// serveur a répondu 404 (fonction absente) — mémorisé pour le processus,
  /// même patron que `p_collections`. Le lot est essayé d'abord: 300 gestes =
  /// deux appels au lieu de 300 sous cadence.
  bool? _batchSupported;
  static const int _kBatchMax = 200;

  bool get _rateLimited =>
      _rateLimitedUntil != null && DateTime.now().isBefore(_rateLimitedUntil!);

  Future<void> _paceOutbox() async {
    final now = DateTime.now();
    final slot = _outboxNextSlot.isAfter(now) ? _outboxNextSlot : now;
    _outboxNextSlot = slot.add(_kOutboxMinGap);
    final wait = slot.difference(now);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
  }

  void _onRateLimited(int pending) {
    if (_rateLimited) return;   // déjà en recul: un seul message, un seul timer
    _rateLimitedUntil = DateTime.now().add(_kRateLimitCooldown);
    debugPrint('[SyncService] serveur saturé (429): drain suspendu '
        '${_kRateLimitCooldown.inSeconds} s, $pending geste(s) en attente');
    _retry?.cancel();
    _retry = Timer(_kRateLimitCooldown + const Duration(seconds: 1),
        () => unawaited(syncNow()));
  }

  Future<void> _drainOutbox() async {
    if (!UserSettings.instance.hasAuthToken) return;
    // Jusqu'à ce que l'outbox soit VIDE, pas un seul instantané: des lignes
    // enfilées PENDANT la livraison (une suppression en cours) attendaient
    // sinon le cycle suivant — derrière un pull complet. Borné, au cas où un
    // producteur ne s'arrêterait jamais.
    for (var pass = 0; pass < 4; pass++) {
      if (_rateLimited) return;   // voir _kRateLimitCooldown
      final rows = await LocalDb.instance.pendingSyncChanges();
      if (rows.isEmpty) return;
      await _drainOutboxRows(rows);
    }
  }

  /// Les paramètres d'un geste de l'outbox, tels que `set_library_batch` les
  /// attend (sans `p_`) — les MÊMES règles que [_deliverOutboxRow], en un
  /// seul endroit (test `outbox_batch_params_test.dart`): un ♥ pur ne porte pas `value`, l'instantané `ext_ref` ne
  /// part que pour un AJOUT. Rend null pour une ligne que personne ne peut
  /// livrer (ni item, ni clé).
  @visibleForTesting
  static Map<String, dynamic>? outboxRowParams(Map<String, Object?> row) {
    final itemId   = (row['item_id'] as String?) ?? '';
    final itemType = (row['item_type'] as String?) ?? 'song';
    final value    = (row['value'] as int? ?? 0) == 1;
    final favRaw   = row['favourite'] as int?;
    final favourite = favRaw == null ? null : favRaw == 1;
    final extKey   = row['ext_key'] as String?;
    final rawRef   = row['ext_ref'] as String?;
    if (itemId.isEmpty && (extKey == null || extKey.isEmpty)) return null;
    return {
      if (itemId.isNotEmpty) 'item_id': catalogueSongId(itemId) ?? itemId,
      'item_type': itemType,
      if (favourite == null) 'value': value,
      if (favourite != null) 'favourite': favourite,
      if (itemId.isNotEmpty) 'subsong_index': row['subsong_idx'] as int? ?? 0,
      if (extKey != null && extKey.isNotEmpty) 'ext_key': extKey,
      if ((value || favourite == true) && rawRef != null)
        'ext_ref': Map<String, dynamic>.from(jsonDecode(rawRef) as Map),
    };
  }

  /// Livraison PAR LOTS. Rend false si le serveur n'a pas la fonction (404):
  /// l'appelant retombe sur l'unitaire. Sur 429, réseau ou autre erreur, les
  /// lignes sont gardées et le drain s'arrête pour cette passe (true).
  Future<bool> _drainOutboxBatch(List<Map<String, Object?>> rows) async {
    for (var at = 0; at < rows.length; at += _kBatchMax) {
      if (_rateLimited) return true;
      final packet = rows.sublist(
          at, at + _kBatchMax > rows.length ? rows.length : at + _kBatchMax);
      final items = <Map<String, dynamic>>[];
      final ids = <int>[];   // id de la ligne pour chaque élément du lot
      for (final row in packet) {
        final id = row['id'] as int;
        final params = outboxRowParams(row);
        if (params == null) {
          await LocalDb.instance.deleteSyncChange(id);
          continue;
        }
        items.add(params);
        ids.add(id);
      }
      if (items.isEmpty) continue;
      await _paceOutbox();
      try {
        final res = await RewampDb.setLibraryBatch(items);
        final rejectedAt = <int, LibraryBatchRejection>{
          for (final r in res.rejected) r.index: r,
        };
        var dropped = 0;
        for (var i = 0; i < ids.length; i++) {
          final rej = rejectedAt[i];
          if (rej == null || rej.code == '23514') {
            // Appliqué — ou REFUSÉ pour de bon (contrainte): le rejouer ne
            // changerait rien, et une ligne coincée gèle les retraits
            // (voir _deliverOutboxRow).
            if (rej != null) dropped++;
            await LocalDb.instance.deleteSyncChange(ids[i]);
          } else {
            await LocalDb.instance.bumpSyncAttempts(ids[i]);
          }
        }
        debugPrint('[SyncService] outbox lot: ${res.applied} appliqué(s), '
            '${res.rejected.length} rejeté(s) dont $dropped jeté(s)');
      } on RewampRpcException catch (e) {
        if (e.statusCode == 404) {
          _batchSupported = false;
          debugPrint('[SyncService] set_library_batch absent (404): '
              'livraison unitaire');
          return false;
        }
        if (e.statusCode == 429 || e.isRateLimited) {
          _onRateLimited(await LocalDb.instance.pendingSyncCount());
          return true;
        }
        for (final id in ids) {
          await LocalDb.instance.bumpSyncAttempts(id);
        }
        debugPrint('[SyncService] outbox lot kept: $e');
        return true;
      } catch (e) {
        for (final id in ids) {
          await LocalDb.instance.bumpSyncAttempts(id);
        }
        debugPrint('[SyncService] outbox lot kept: $e');
        return true;
      }
    }
    _batchSupported = true;
    return true;
  }

  Future<void> _drainOutboxRows(List<Map<String, Object?>> rows) async {
    // Le LOT d'abord (set_library_batch): les lignes arrivent triées par
    // date, et le serveur applique dans l'ordre — les chaînes par item
    // ci-dessous ne servent qu'au repli unitaire.
    if (_batchSupported != false) {
      if (await _drainOutboxBatch(rows)) return;
    }
    // ⚠️ Deux gestes sur le MÊME item doivent rester ORDONNÉS (ajouter puis
    // retirer ne vaut pas l'inverse), et la file arrive déjà triée par date.
    // On ne parallélise donc qu'ENTRE items: une chaîne séquentielle par clé,
    // plusieurs chaînes en vol.
    final chains = <String, List<Map<String, Object?>>>{};
    for (final row in rows) {
      final key = '${row['item_type']}|${row['item_id']}|'
          '${row['ext_key']}|${row['subsong_idx']}';
      (chains[key] ??= <Map<String, Object?>>[]).add(row);
    }
    final queue = chains.values.toList();
    var next = 0;
    Future<void> worker() async {
      while (next < queue.length && !_rateLimited) {
        final chain = queue[next++];
        for (final row in chain) {
          if (_rateLimited) return;
          await _paceOutbox();
          await _deliverOutboxRow(row);
        }
      }
    }
    await Future.wait([
      for (var i = 0; i < _kOutboxConcurrency && i < queue.length; i++)
        worker(),
    ]);
  }

  /// Livre UN geste de l'outbox. Extrait du drain pour qu'il puisse en tenir
  /// plusieurs en vol (voir [_kOutboxConcurrency]).
  Future<void> _deliverOutboxRow(Map<String, Object?> row) async {
    {
      final id       = row['id'] as int;
      final itemId   = (row['item_id'] as String?) ?? '';
      final itemType = (row['item_type'] as String?) ?? 'song';
      final value    = (row['value'] as int? ?? 0) == 1;
      // Migration serveur 206: non-null = ce geste EST un ♥. Il part alors SANS
      // p_value, sinon un un-♥ (`p_value: false`) retirerait l'entrée de la
      // bibliothèque — et le serveur efface le ♥ avec elle.
      final favRaw   = row['favourite'] as int?;
      final favourite = favRaw == null ? null : favRaw == 1;
      final extKey   = row['ext_key'] as String?;
      final rawRef   = row['ext_ref'] as String?;
      // A change is either catalogue-identified or carries its own snapshot;
      // one with neither cannot be delivered to anyone.
      if (itemId.isEmpty && (extKey == null || extKey.isEmpty)) {
        await LocalDb.instance.deleteSyncChange(id);
        return;
      }

      try {
        await RewampDb.setLibrary(
          itemId:   itemId.isEmpty ? null : itemId,
          itemType: itemType,
          value:    value,
          sendValue: favourite == null,
          favourite: favourite,
          subsongIndex: itemId.isEmpty
              ? null
              : (row['subsong_idx'] as int? ?? 0),
          extKey:   extKey,
          // The snapshot is only needed when ADDING: a removal just needs to
          // name the entry.
          extRef:   ((value || favourite == true) && rawRef != null)
              ? Map<String, dynamic>.from(jsonDecode(rawRef) as Map)
              : null,
        );
        await LocalDb.instance.deleteSyncChange(id);
      } on RewampRpcException catch (e) {
        // 23514 = le serveur REFUSE ce geste (contrainte violée). Le rejouer
        // ne changera rien, et une ligne coincée gèle bien plus que
        // elle-même: `pendingSyncCount() == 0` est la condition qui autorise
        // l'application des RETRAITS (bibliothèque et playlists), donc un
        // seul geste irrecevable bloquait toute la propagation des
        // suppressions. On la jette, en le disant.
        if (e.code == '23514') {
          await LocalDb.instance.deleteSyncChange(id);
          debugPrint('[SyncService] outbox $id REFUSÉ par le serveur '
              '(${e.code}): ${e.message}');
        } else if (e.statusCode == 429 || e.isRateLimited) {
          // Pas la faute de la ligne: on ne compte pas de tentative, on ne
          // rejoue pas, on attend la fenêtre suivante (voir _onRateLimited).
          _onRateLimited(await LocalDb.instance.pendingSyncCount());
        } else {
          await LocalDb.instance.bumpSyncAttempts(id);
          debugPrint('[SyncService] outbox $id kept: $e');
        }
      } catch (e) {
        await LocalDb.instance.bumpSyncAttempts(id);
        debugPrint('[SyncService] outbox $id kept: $e');
      }
    }
  }

  /// Livre les écoutes de fichiers locaux en attente (log_plays_ext), par
  /// lots ≤500. Idempotent serveur (PK user/ext_key/played_at) — un lot
  /// rejoué après coupure ne double rien. Un échec garde le lot pour la
  /// prochaine passe.
  Future<void> _drainExtPlays() async {
    if (!UserSettings.instance.hasAuthToken) return;
    for (;;) {
      final rows = await LocalDb.instance.pendingExtPlays(limit: 500);
      if (rows.isEmpty) return;
      final events = <Map<String, dynamic>>[];
      final ids = <int>[];
      // Les lignes locales que la livraison rendra « déjà dans le compte ».
      final playEventIds = <int>[];
      for (final r in rows) {
        ids.add(r['id'] as int);
        final pe = r['play_event_id'] as int?;
        if (pe != null) playEventIds.add(pe);
        events.add({
          'ext_key':     r['ext_key'],
          'duration_ms': r['duration_ms'],
          if ((r['backend'] as String?)?.isNotEmpty == true)
            'backend': r['backend'],
          'played_at':   DateTime.fromMillisecondsSinceEpoch(
                  (r['played_at'] as int) * 1000,
                  isUtc: true)
              .toIso8601String(),
          if (r['ext_ref'] != null)
            'ext_ref': jsonDecode(r['ext_ref'] as String),
        });
      }
      try {
        await RewampDb.logPlaysExt(events);
        await LocalDb.instance.deleteExtPlays(ids);
        await LocalDb.instance.markPlayEventsPushed(playEventIds);
        if (rows.length < 500) return;   // last (partial) batch delivered
      } catch (e) {
        await LocalDb.instance.bumpExtPlayAttempts(ids);
        debugPrint('[SyncService] ext plays kept (${ids.length}): $e');
        return;
      }
    }
  }

  /// Ramène les cumuls d'écoute du compte (user_play_stats) et les APPLIQUE en
  /// remplacement — le serveur fait autorité, on n'additionne jamais. Premier
  /// sync (curseur nul): rejoue d'abord la timeline complète
  /// (user_play_history, catalogue ET ext) dans play_events, pour que
  /// « Vos tendances »
  /// reparte avec l'historique sur un nouvel appareil. L'insertion déclenche
  /// le trigger qui gonfle play_count — l'application des cumuls derrière le
  /// remet à la valeur serveur.
  Future<void> _pullPlayStats() async {
    if (!UserSettings.instance.hasAuthToken) return;
    final cursor = UserSettings.instance.playStatsCursor;
    try {
      if (cursor == null) await _replayPlayHistory();
      final stats = await RewampDb.userPlayStats(since: cursor);
      var maxSeen = cursor;
      var applied = 0;
      for (final s in stats) {
        TrackRecord? t;
        if (s.songId != null && s.songId!.isNotEmpty) {
          t = await LocalDb.instance
              .trackByOnlineIdAndSubsong(s.songId!, s.subsongIndex);
        } else if (s.extRef != null) {
          t = await LocalDb.instance.findTrackForSnapshot(
            relPath:    s.extRef!.relPath,
            fileName:   s.extRef!.fileName,
            entryPath:  s.extRef!.entryPath,
            subsongIdx: s.extRef!.subsongIdx,
          );
        }
        final at = s.lastPlayedAt;
        if (t != null && at != null) {
          await LocalDb.instance.setTrackPlayStats(
            trackId:            t.id,
            playCount:          s.playCount,
            lastPlayedAtEpochS: at.millisecondsSinceEpoch ~/ 1000,
          );
          applied++;
        }
        if (at != null && (maxSeen == null || at.isAfter(maxSeen))) {
          maxSeen = at;
        }
      }
      // Le curseur avance même sur les lignes non appariées (piste pas sur cet
      // appareil): les cumuls reviendront par le prochain grand pull si elle
      // apparaît — même compromis que la bibliothèque.
      if (maxSeen != cursor) {
        UserSettings.instance.playStatsCursor = maxSeen;
      }
      if (stats.isNotEmpty) {
        debugPrint('[SyncService] play stats: ${stats.length} rows, '
            '$applied applied (cursor $maxSeen)');
        LocalDb.instance.notifyBatchChanged();
      }
    } catch (e) {
      // Best-effort: des stats en retard ne doivent jamais faire échouer le
      // reste de la synchro (le curseur n'a pas bougé, on réessaiera).
      debugPrint('[SyncService] play stats pull failed: $e');
    }
  }

  /// Une page de timeline demandée au serveur.
  static const _kHistoryPage = 1000;

  /// Retient de quoi AFFICHER une piste du compte que cet appareil n'a pas:
  /// sans elle, une écoute venue d'ailleurs n'est qu'un uuid dans l'écran
  /// Stats. Le catalogue donne titre/album/pochette/plateforme, le hors
  /// catalogue son snapshot (qui, lui, porte un artiste).
  ///
  /// ⚠️ `user_songs` ne sert PAS l'artiste des lignes catalogue (voir la
  /// signature de la RPC, migration serveur 189) — les tops par artiste ne
  /// couvrent donc que les pistes présentes ici, jusqu'à ce que le serveur
  /// l'ajoute.
  Future<void> _cacheAccountTrackMeta(UserLibrarySong s) async {
    if (s.extKey != null && s.extKey!.isNotEmpty) {
      final r = s.extRef;
      await LocalDb.instance.upsertAccountTrackMeta(
        extKey:    s.extKey!,
        title:     r?.title ?? r?.fileName,
        artist:    r?.artist,
        album:     r?.album,
        formatExt: r?.formatExt,
        durationS: r?.durationS,
      );
      return;
    }
    if (s.songId.isEmpty) return;
    await LocalDb.instance.upsertAccountTrackMeta(
      songId:     s.songId,
      subsongIdx: s.subsongIndex ?? 0,
      title:      s.title,
      album:      s.album,
      artworkUrl: s.artworkUrl,
      collection: s.collection,
      platform:   s.platform,
    );
  }

  /// Un morceau du compte, nommé et crédité depuis le catalogue.
  Future<void> _resolveOneAccountTrack(String songId, int subsong) async {
    final c = await RewampDb.getSongContext(songId);
    if (c == null) return;
    final song = c.song;
    await LocalDb.instance.upsertAccountTrackMeta(
      songId:     songId,
      subsongIdx: subsong,
      title:      song.title ?? song.filename,
      // Chaîne VIDE = demandé, pas de crédit. Un null relancerait la demande.
      artist:     song.artistNames.join(' & '),
      album:      song.album,
      albumId:    song.albumId,
      artworkUrl: song.artworkUrl,
      collection: song.collection,
      platform:   song.platform,
      formatExt:  song.formatExt,
    );
  }

  /// Le balayage des écoutes indélivrables a déjà eu lieu dans cette exécution.
  bool _shortPlaysSwept = false;

  /// Démarrage de l'app (epoch s): borne du balayage ci-dessus.
  final int _startedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// La passe « bibliothèque complète » pour les métadonnées a déjà eu lieu
  /// dans cette exécution de l'app: elle ramène TOUT, on ne la refait pas à
  /// chaque battement de 90 s.
  bool _fullMetaPassDone = false;

  /// Les ids déjà demandés à `get_song_context` dans cette exécution — un
  /// morceau que le catalogue ne connaît plus ne doit pas être redemandé à
  /// chaque passe.
  final Set<String> _contextTried = {};

  /// Donne un TITRE (et un crédit) aux pistes du miroir absentes d'ici.
  ///
  /// Le piège est dans `user_songs`: une ligne d'historique seul a un
  /// `updated_at` NULL, donc **elle ne sort JAMAIS d'un delta** (`WHERE
  /// updated_at >= p_since`). Sur un appareil dont le curseur est posé —
  /// c'est-à-dire tous sauf un tout neuf — les métadonnées n'arrivaient donc
  /// jamais, et l'écran Stats affichait l'uuid en guise de titre jusqu'à ce
  /// qu'on joue le morceau. Il faut une passe SANS curseur, une fois par
  /// exécution, et seulement s'il manque quelque chose.
  ///
  /// Ce que `user_songs` ne donne pas: l'ARTISTE (sa signature ne le porte
  /// pas, mig serveur 189). D'où le second temps: `get_song_context` pièce par
  /// pièce — c'est aussi ce qui remplit « Top artistes » pour les morceaux qui
  /// ne sont pas sur cet appareil. Un crédit absent est mémorisé VIDE, pas
  /// null, sinon on le redemanderait sans fin.
  ///
  /// Tout est fait EN UNE PASSE, par paquets de [_kContextConcurrency] en
  /// parallèle: c'était plafonné par passe, ce qui obligeait à synchroniser
  /// cinq ou dix fois avant que les compteurs se stabilisent — et ce n'est
  /// qu'un rattrapage, une seule fois dans la vie de l'appareil (le résultat
  /// est en base pour de bon; ensuite, seuls les nouveaux morceaux écoutés
  /// s'ajoutent, un par un). Le plafond dur reste là pour ne pas partir en
  /// boucle si le serveur répond systématiquement null.
  static const _kContextConcurrency = 6;
  static const _kContextHardCap = 5000;

  Future<void> _nameAccountTracks() async {
    if (!UserSettings.instance.hasAuthToken) return;
    try {
      var missing = await LocalDb.instance.unnamedAccountSongs(limit: 1);
      if (missing.isEmpty) return;

      if (!_fullMetaPassDone) {
        _fullMetaPassDone = true;
        final all = await RewampDb.userSongs(inLibrary: null);
        for (final s in all) {
          await _cacheAccountTrackMeta(s);
        }
        debugPrint('[SyncService] account meta: ${all.length} rows cached');
      }

      missing = await LocalDb.instance.unnamedAccountSongs(limit: 20000);
      final todo = [
        for (final (songId, subsong) in missing)
          if (_contextTried.add('$songId#$subsong')) (songId, subsong),
      ];
      var done = 0;
      for (var i = 0; i < todo.length && i < _kContextHardCap;
          i += _kContextConcurrency) {
        final slice = todo.skip(i).take(_kContextConcurrency);
        await Future.wait([
          for (final (songId, subsong) in slice)
            _resolveOneAccountTrack(songId, subsong),
        ]);
        done += slice.length;
      }
      if (done > 0) {
        debugPrint('[SyncService] account meta: $done resolved by context');
      }
      // Un écran Stats ouvert écoute LocalDb: sans ce réveil, les titres
      // n'apparaîtraient qu'au prochain changement de base.
      LocalDb.instance.notifyBatchChanged();
    } catch (e) {
      debugPrint('[SyncService] account meta failed: $e');
    }
  }

  /// Descend la timeline du COMPTE dans `account_play_events` — le miroir qui
  /// permet à l'écran Stats de fusionner les écoutes de tous les appareils.
  ///
  /// Incrémental sur `sync.play_history_cursor` (`>=` inclusif comme les
  /// autres curseurs de synchro), pagé; la clé primaire du miroir absorbe la
  /// ligne rejouée sur le curseur. Rien à dédupliquer contre le local ici:
  /// c'est le marqueur `play_events.pushed` qui dit, côté local, qu'une écoute
  /// est déjà représentée ici.
  ///
  /// Best-effort comme le reste des stats: un échec laisse le curseur en place.
  Future<void> _pullPlayHistoryMirror() async {
    if (!UserSettings.instance.hasAuthToken) return;
    final cursor = UserSettings.instance.playHistoryCursor;
    var maxSeen = cursor;
    var added = 0;
    try {
      for (var offset = 0;; offset += _kHistoryPage) {
        final page = await RewampDb.userPlayHistory(
            since: cursor, limit: _kHistoryPage, offset: offset);
        final rows = <Map<String, Object?>>[];
        for (final e in page) {
          final at = e.playedAt;
          if (at == null) continue;
          rows.add({
            'kind':        e.kind.isEmpty ? 'song' : e.kind,
            'song_id':     e.songId ?? '',
            'subsong_idx': e.subsongIndex,
            'ext_key':     e.extKey ?? '',
            'played_at':   at.millisecondsSinceEpoch ~/ 1000,
            'played_ms':   e.durationMs > 0 ? e.durationMs : null,
            'backend':     e.backend,
          });
          if (maxSeen == null || at.isAfter(maxSeen)) maxSeen = at;
        }
        added += await LocalDb.instance.upsertAccountPlayEvents(rows);
        if (page.length < _kHistoryPage) break;
      }
      if (maxSeen != cursor) UserSettings.instance.playHistoryCursor = maxSeen;
      if (added > 0) {
        debugPrint('[SyncService] account timeline: +$added events '
            '(cursor $maxSeen)');
      }
      // Une fois par exécution: les écoutes qu'aucun envoi n'a pu porter au
      // compte (trop courtes, ou interrompues par la mort de l'app) sortent de
      // la vue fusionnée. Bornée au démarrage de l'app: la lecture EN COURS a
      // elle aussi un played_ms nul, et elle, elle partira.
      if (!_shortPlaysSwept) {
        _shortPlaysSwept = true;
        final n = await LocalDb.instance.markShortPlaysOffAccount(_startedAt);
        if (n > 0) debugPrint('[SyncService] $n short plays marked off-account');
      }
      // Rattrapage unique: les écoutes locales tombant dans la fenêtre que le
      // compte couvre y sont déjà (livrées avant que `pushed` n'existe).
      if (!UserSettings.instance.playHistoryBackfilled) {
        final start = await LocalDb.instance.accountPlayHistoryStart();
        if (start != null) {
          final n = await LocalDb.instance.markLocalPlaysPushedBefore(start);
          UserSettings.instance.playHistoryBackfilled = true;
          debugPrint('[SyncService] pushed backfill: $n local events');
        }
      }
    } catch (e) {
      debugPrint('[SyncService] account timeline pull failed: $e');
    }
  }

  /// Rejoue la timeline du compte dans play_events (nouvel appareil).
  /// Dédupliquée par (track_id, played_at); seuls les fichiers retrouvés sur
  /// CET appareil sont rejoués.
  ///
  /// `user_play_history` (migration 221) rend les DEUX grains dans une même
  /// liste: catalogue (`kind='song'`) et hors catalogue (`kind='ext'`) — avant
  /// elle, seul l'ext se rejouait et l'historique catalogue d'un compte ne
  /// revenait que sous forme de cumuls. Repli sur `user_ext_play_history` si
  /// le serveur ne connaît pas encore la RPC.
  Future<void> _replayPlayHistory() async {
    var replayed = 0;
    try {
      for (var offset = 0;; offset += _kHistoryPage) {
        final page = await RewampDb.userPlayHistory(
            limit: _kHistoryPage, offset: offset);
        for (final e in page) {
          final at = e.playedAt;
          if (at == null) continue;
          TrackRecord? t;
          if (e.songId != null && e.songId!.isNotEmpty) {
            t = await LocalDb.instance
                .trackByOnlineIdAndSubsong(e.songId!, e.subsongIndex);
          } else if (e.extRef != null) {
            t = await LocalDb.instance.findTrackForSnapshot(
              relPath:    e.extRef!.relPath,
              fileName:   e.extRef!.fileName,
              entryPath:  e.extRef!.entryPath,
              subsongIdx: e.extRef!.subsongIdx,
            );
          }
          if (t == null) continue;
          await LocalDb.instance.insertPlayEventRaw(
            trackId:        t.id,
            playedAtEpochS: at.millisecondsSinceEpoch ~/ 1000,
            playedMs:       e.durationMs > 0 ? e.durationMs : null,
            // Elle VIENT du compte: le miroir la porte déjà, l'écran Stats ne
            // doit pas la recompter du côté local.
            pushed:         true,
          );
          replayed++;
        }
        if (page.length < _kHistoryPage) break;
      }
    } catch (e) {
      debugPrint('[SyncService] unified history unavailable ($e), '
          'falling back to ext only');
      replayed += await _replayExtHistory();
    }
    if (replayed > 0) {
      debugPrint('[SyncService] history replayed: $replayed events');
    }
  }

  /// Repli: la timeline ext seule (`user_ext_play_history`), pour un serveur
  /// antérieur à la migration 221. Rend le nombre d'écoutes rejouées.
  Future<int> _replayExtHistory() async {
    final events = await RewampDb.userExtPlayHistory();
    var replayed = 0;
    for (final e in events) {
      final ref = e.extRef;
      final at = e.playedAt;
      if (ref == null || at == null) continue;
      final t = await LocalDb.instance.findTrackForSnapshot(
        relPath:    ref.relPath,
        fileName:   ref.fileName,
        entryPath:  ref.entryPath,
        subsongIdx: ref.subsongIdx,
      );
      if (t == null) continue;
      await LocalDb.instance.insertPlayEventRaw(
        trackId:        t.id,
        playedAtEpochS: at.millisecondsSinceEpoch ~/ 1000,
        playedMs:       e.durationMs > 0 ? e.durationMs : null,
        pushed:         true,
      );
      replayed++;
    }
    return replayed;
  }

  /// Brings the account's library down.
  ///
  /// Removals propagate ONLY when the outbox is empty — i.e. when everything
  /// this device decided is already server-side. Applying `in_library: false`
  /// while a local add is still queued would delete the favourite the user just
  /// made, and the server row it is compared against predates it.
  ///
  /// Incremental once the server carries `updated_at`: the cursor is the highest
  /// one seen, and the next call asks for `>= cursor` (inclusive on purpose —
  /// see [UserSettings.libraryCursor]). On a server without it, everything comes
  /// back and the cursor stays null: correct, just not cheap.
  Future<void> _pullLibrary() async {
    // Removals can only be judged when everything this device decided is
    // already server-side: otherwise a favourite made here and not yet
    // delivered looks exactly like one removed elsewhere.
    final canRemove = await LocalDb.instance.pendingSyncCount() == 0;
    var cursor = UserSettings.instance.libraryCursor;
    final lastFull = UserSettings.instance.libraryReconciledAt;
    // ONE-SHOT: la dérive née AVANT que la comparaison n'existe ne se répare
    // que par une passe sans curseur. Sans ça, le rattrapage n'aurait lieu
    // qu'à la prochaine réconciliation — jusqu'à douze heures plus tard, et
    // seulement si l'appareil est ouvert à ce moment-là. Constaté: deux
    // appareils relancés côte à côte, `library_reconciled_at` datant de trois
    // heures, donc rien ne se passait.
    final driftAudit = canRemove && !UserSettings.instance.libraryDriftAudited;
    // ONE-SHOT (même forme, autre dérive): les entrées que le plafond de
    // fabrication a laissées sans ligne `tracks`. Elles sont dans la
    // bibliothèque du compte, appliquées ici, et invisibles partout — la
    // comparaison ne savait pas les voir, et le curseur les a dépassées.
    final mintAudit = canRemove && !UserSettings.instance.libraryMintAudited;
    final full = canRemove &&
        (driftAudit ||
         mintAudit ||
         cursor == null ||
         lastFull == null ||
         DateTime.now().difference(lastFull) > const Duration(hours: 12));

    // ONE-SHOT: ask the delta from scratch so the fabricated ext favourites can
    // be seen at all. Their `updated_at` predates this device's cursor — the
    // gesture that created them is old — so an incremental delta will never
    // carry them again, and the purge that knows how to recognise them
    // (_applyExtFavourite → _purgeFabricatedKeys) would wait for ever.
    // `user_library_ids` cannot stand in: it returns identities only, no
    // `ext_ref`, and the signature test needs `file_name` AND `title`.
    // Cursor-less, not recurring: after this pass there is nothing left to look
    // for, and every apply is idempotent (see the class comment), so the only
    // cost is one heavier pull once per install.
    final auditExt = !UserSettings.instance.extLibraryAudited;
    if (auditExt) {
      debugPrint('[SyncService] one-shot ext-library audit: pulling uncapped');
      cursor = null;
    }
    if (driftAudit) {
      debugPrint('[SyncService] one-shot library drift audit: pulling uncapped');
      cursor = null;
    }
    if (mintAudit) {
      debugPrint('[SyncService] one-shot mint audit: pulling uncapped');
      cursor = null;
    }

    DateTime? maxSeen;
    void trackCursor(DateTime? t) {
      // updated_at null = a play-history row that never entered the library —
      // it must not move the cursor (spec §4).
      if (t == null) return;
      if (maxSeen == null || t.isAfter(maxSeen!)) maxSeen = t;
    }

    if (full) {
      // Snapshot reconciliation (spec §6.1): one compact call, identities only.
      final ids = await RewampDb.userLibraryIds();
      for (final r in ids) {
        trackCursor(r.updatedAt);
      }
      await _reconcileRemovals(ids);
      // …et la même photo sert à repérer ce qui MANQUE ici. Sans ça, le
      // curseur est un cul-de-sac: il n'avance que sur ce qu'on a vu, donc une
      // entrée du compte que cet appareil n'a jamais appliquée (elle est plus
      // ancienne que son curseur) ne lui reviendra JAMAIS. Deux façons d'en
      // arriver là, toutes deux constatées entre un Mac et un iPhone du même
      // compte: le client change ce qu'il FAIT d'une ligne (le ♥ est devenu
      // une colonne à la mig 206 — les lignes déjà passées ne repassent pas),
      // ou l'appareil perd une entrée localement sans que le compte bouge.
      // Le remède est le même dans les deux cas: redemander le delta SANS
      // curseur cette fois-ci. Tout apply est idempotent, donc le seul coût
      // est un pull plus gros, et seulement quand un écart existe vraiment.
      if (await _accountHasWhatWeLack(ids)) {
        debugPrint('[SyncService] library drift detected — pulling uncapped');
        cursor = null;
      }
      UserSettings.instance.libraryReconciledAt = DateTime.now();
    }

    // Delta (spec §6.2): WITHOUT p_in_library — filtering to true would hide
    // the removals, which are exactly what a delta must carry. Since migration
    // 180 a row with in_library=false in a delta IS a removal (play-history
    // rows have updated_at null and never leave a delta).
    final songs  = await RewampDb.userSongs(inLibrary: null, since: cursor);
    final albums = await RewampDb.userAlbums(inLibrary: null, since: cursor);

    var minted = 0; // journalisé en fin de lot, aide au diagnostic
    final mintJobs = <({String songId, int subsong, DateTime? updatedAt})>[];
    // La plus ANCIENNE ligne que le plafond de fabrication a laissée sans
    // ligne `tracks`. Le curseur ne doit pas la dépasser: il n'avance que sur
    // ce qu'on a vu, donc une ligne sautée ne revient JAMAIS dans un delta —
    // et l'écart est INVISIBLE à la réconciliation, qui ne compare que les
    // entrées de bibliothèque. C'est exactement ce qui laissait une
    // installation neuve avec ses favoris dans la bibliothèque et une playlist
    // Favoris incomplète (celle-ci lit à travers `tracks`), définitivement.
    DateTime? mintDeferred;
    for (final s in songs) {
      trackCursor(s.updatedAt);
      // AVANT le filtre d'appartenance: une ligne « historique seul »
      // (updated_at null, jamais mise en bibliothèque) est justement celle
      // dont l'écran Stats a besoin pour NOMMER une écoute venue d'un autre
      // appareil. `user_songs` sert les deux, on prend le nom au passage.
      await _cacheAccountTrackMeta(s);
      // Delta without a cursor (first run) returns play-history rows too:
      // updated_at null means the membership never changed — not library data.
      if (s.updatedAt == null) continue;

      if (s.songId.isEmpty) {
        // Out-of-catalogue favourite (a file of the user's own).
        await _applyExtFavourite(s, canRemove: canRemove);
        continue;
      }

      // Arbitration (spec §6.3): a gesture still queued here is only the truth
      // if it is MORE RECENT than what the account holds. One made offline
      // before another device changed the same item must not be replayed on
      // top of it — the delta is where the two dates finally meet.
      final localWins = await _arbitrate(
        itemType: 'song',
        itemId: s.songId,
        subsongIdx: s.subsongIndex ?? 0,
        serverUpdatedAt: s.updatedAt!,
      );

      // Local keys are ALWAYS subsong-scoped ('<id>?subsong=N', N=0 included):
      // 0 is the subsong of index 0, which for a single-track file happens to
      // be the whole file. A server null only exists on rows written before
      // migration 181 normalised it — read it as 0.
      final subsong = s.subsongIndex ?? 0;
      // La PISTE locale que cette ligne de compte désigne — elle connaît les
      // deux formes d'identité (uuid nu + subsong_idx, et le `uuid#N`
      // synthétique d'un conteneur expansé).
      final localTrack =
          await LocalDb.instance.trackByOnlineIdAndSubsong(s.songId, subsong);
      // La clé locale doit être celle de la PISTE, pas `<uuid>?subsong=N`
      // fabriqué depuis l'identité serveur: sur un album conteneur aucune
      // ligne `tracks` ne porte l'uuid nu, donc l'entrée ainsi keyée ne
      // retrouvait aucun fichier — la bibliothèque la donnait pour absente et
      // la relançait en TÉLÉCHARGEMENT, en affichant le titre du conteneur.
      final localRef = (localTrack?.onlineId != null)
          ? '${localTrack!.onlineId}?subsong=${localTrack.subsongIdx}'
          : '${s.songId}?subsong=$subsong';
      // Avec la SOUS-CHANSON: le compte tient une ligne par sous-chanson d'un
      // même uuid, et sans elle toutes retombaient sur la même entrée locale —
      // la dernière appliquée gagnait, éteignant un ♥ posé sur une autre.
      final refId = await LocalDb.instance
              .libraryRefIdForSong(s.songId, subsongIdx: subsong) ??
          localRef;
      if (!s.inLibrary) {
        if (canRemove) {
          await LocalDb.instance.removeFromLibrary('track', refId);
        }
        continue;
      }
      // La ligne LOCALE d'abord pour tout ce qui s'affiche: `user_songs` ne
      // connaît que le morceau du CATALOGUE, or pour un album conteneur c'est
      // le conteneur — son titre est le nom de l'album et son url celle de
      // l'archive entière. Les appliquer sur l'entrée d'une piste la renommait
      // « Wild Arms » et faisait retélécharger l'album à la lecture.
      // ⚠️ **Le NIVEAU du nom doit suivre le NIVEAU de l'entrée.**
      // La ligne locale gagne pour une entrée de PISTE (voir juste au-dessus:
      // `user_songs` ne connaît que le morceau du catalogue, donc pour un
      // album conteneur c'est le conteneur, et l'appliquer à une piste la
      // renommait « Wild Arms »). Mais une entrée de CONTENEUR (refId SANS
      // suffixe `?subsong=`) vise le FICHIER ENTIER, et la ligne locale qu'on
      // résout pour elle est celle de sa SOUS-CHANSON 0 — dont le titre est
      // numéroté. Le pull renommait donc l'entrée « Commando (1) », juste
      // après que le geste l'eut nommée « Commando ». Symétrique du piège
      // ci-dessus, et c'est la même règle qui répare les deux.
      await LocalDb.instance.addToLibrary(
        type:        'track',
        refId:       refId,
        name:        libraryEntryName(
          containerEntry: splitLibraryRefId(refId).$2 == null,
          localTitle:     localTrack?.title,
          catalogueTitle: s.title,
          fileName:       localTrack?.filePath.split(Platform.pathSeparator).last,
        ),
        artist:      localTrack?.artist,
        album:       localTrack?.metaAlbum ?? s.album,
        artworkUrl:  localTrack?.artworkUrl ?? s.artworkUrl,
        // Même règle que le titre et la pochette juste au-dessus, et le
        // dernier champ à l'avoir ignorée: `user_songs` porte l'url que le
        // CATALOGUE avait quand la ligne a été écrite. Elle peut être périmée
        // — « Inside The BORG Cube » y garde le zip scene.org alors que le
        // serveur ne rend plus que l'override mp3 —, et jouer depuis la
        // bibliothèque repartait sur l'archive puis EFFAÇAIT le rendu déjà
        // téléchargé. Ce qu'on a réellement téléchargé fait donc foi.
        downloadUrl:
            await LocalDb.instance.getDownloadSourceUrl(s.songId) ??
                s.downloadUrl,
        collectionSlug: s.collection,
        platformName:   s.platform,
        explicit:    true,
      );

      // Le ♥ vient de la COLONNE (migration serveur 206), plus du blob
      // `user_state.favourites`. Pas quand un geste local plus récent a
      // survécu à l'arbitrage: il est la vérité jusqu'à sa livraison.
      if (!localWins) {
        await LocalDb.instance
            .setLibraryItemFavorite('track', refId, value: s.favourite);
      }

      // A library row alone is INVISIBLE: the library and favourites screens
      // read through the `tracks` table, and a tune this device never played
      // has no row there. Mint one (path computed, file not downloaded — the
      // established convention, same as adding an online result to a playlist);
      // the play path re-downloads on a missing file that carries an online id.
      // `localTrack` connaît les DEUX formes: si la piste est déjà là sous
      // `<uuid>#<i>`, il n'y a rien à fabriquer. `hasTrackFor` ne regardait que
      // l'uuid nu, si bien qu'un album conteneur se faisait fabriquer une ligne
      // fantôme PAR SOUS-CHANSON, toutes au chemin du conteneur et titrées du
      // nom de l'album.
      if (localTrack == null) {
        // COLLECTÉ, résolu EN LOT après la boucle (get_song_entries): 40
        // fabrications coûtaient 40 requêtes par passe, le lot en coûte 1 plus
        // les replis. Nuance de budget assumée: le plafond compte désormais
        // des TENTATIVES et non des succès — un échec consomme une place, la
        // ligne revient à la passe suivante par le curseur, comme une reportée.
        if (mintJobs.length < _kMintPerRun) {
          mintJobs.add(
              (songId: s.songId, subsong: subsong, updatedAt: s.updatedAt));
        } else if (s.updatedAt != null &&
            (mintDeferred == null || s.updatedAt!.isBefore(mintDeferred))) {
          // Reportée par le plafond, pas REFUSÉE: un mint qui échoue (le
          // fichier n'a pas cette sous-chanson, le catalogue ne répond pas) ne
          // doit pas épingler le curseur pour toujours.
          mintDeferred = s.updatedAt;
        }
      }
    }

    // Résolution EN LOT des lignes à fabriquer. Le rang ne se demande que pour
    // une sous-chanson (> 0): la ligne « fichier entier » garde l'online_id NU
    // et son chemin contexte. Un rang non résolu (fichier sans tracklist: la
    // valeur du compte est un vrai index) ou un tronçon en échec réseau
    // retombe sur le chemin contexte, à l'identique de l'unitaire.
    if (mintJobs.isNotEmpty) {
      final rankJobs = [
        for (final j in mintJobs)
          if (j.subsong > 0) j
      ];
      final entries = await RewampDb.getSongEntries([
        for (final j in rankJobs)
          (songId: j.songId, subsongIndex: null, fileName: null,
              entryRank: j.subsong),
      ]);
      var ri = 0;
      for (final j in mintJobs) {
        final entry = j.subsong > 0 ? entries[ri++] : null;
        final ok = entry != null
            ? await _mintFromEntry(j.songId, j.subsong, entry)
            : await _mintViaContext(j.songId, j.subsong);
        if (ok) minted++;
      }
      debugPrint('[SyncService] mint: $minted/${mintJobs.length} '
          '(${mintJobs.where((j) => j.subsong > 0).length} par rang)');
      // ZÉRO succès sur un lot non vide = signature d'une COUPURE RÉSEAU
      // entre le fetch (réussi, sinon on ne serait pas ici) et la
      // fabrication: sans cette borne le curseur était écrit PAR-DESSUS des
      // lignes jamais fabriquées, qu'aucun delta ne re-sert — visibles en
      // bibliothèque, absentes de la playlist Favoris jusqu'à la
      // réconciliation (12 h). Traité comme un plafond atteint: le curseur
      // tient à la plus ancienne, la passe suivante refait le lot.
      //
      // Le critère est TOUT-OU-RIEN exprès: un échec PARTIEL peut être un
      // refus légitime (le fichier n'a pas cette sous-chanson), et borner
      // là-dessus épinglerait le curseur pour toujours sur une ligne
      // irréparable — le bug que la règle « reportée, pas refusée » existe
      // pour empêcher. Quarante refus légitimes simultanés: improbable; une
      // coupure: courante. Et même à tort, la borne ne coûte qu'un lot
      // rejoué par passe, jamais une perte.
      if (minted == 0) {
        for (final j in mintJobs) {
          if (j.updatedAt != null &&
              (mintDeferred == null || j.updatedAt!.isBefore(mintDeferred))) {
            mintDeferred = j.updatedAt;
          }
        }
      }
    }

    for (final a in albums) {
      trackCursor(a.updatedAt);
      if (a.updatedAt == null) continue;
      if (a.albumId.isEmpty && a.name == '?') continue;
      // Keyed by UUID (see albumLibraryRefId): pulling two homonym albums used
      // to write the same row twice, so the account held both and the device
      // showed one.
      final albumRefId =
          albumLibraryRefId(a.name, a.albumId.isEmpty ? null : a.albumId);
      final albumLocalWins = a.albumId.isEmpty
          ? false
          : await _arbitrate(
              itemType: 'album',
              itemId: a.albumId,
              serverUpdatedAt: a.updatedAt!,
            );
      if (!a.inLibrary) {
        if (canRemove) {
          await LocalDb.instance.removeFromLibrary('album', albumRefId);
        }
        continue;
      }
      await LocalDb.instance.addToLibrary(
        type:       'album',
        refId:      albumRefId,
        name:       a.name,
        albumId:    a.albumId.isEmpty ? null : a.albumId,
        artworkUrl: a.artworkUrl,
        collectionSlug: a.collection,
        platformName:   a.platform,
        explicit:   true,
      );
      // Le ♥ d'album vient lui aussi de la colonne (migration serveur 206).
      if (!albumLocalWins) {
        await LocalDb.instance.setLibraryItemFavorite(
            'album', albumRefId,
            value: a.favourite,
            albumId: a.albumId.isEmpty ? null : a.albumId);
      }
    }

    // After the cursor work, so a failing purge can never cost a pull.
    final purged = await _purgeFabricatedKeys();

    // The audit counts as done only once the purge actually landed: marking it
    // on a failed RPC would burn the single pass that can see those rows.
    if (auditExt && purged) UserSettings.instance.extLibraryAudited = true;

    // Le rattrapage ne compte comme fait qu'une fois la passe allée au bout:
    // le marquer plus tôt brûlerait l'unique passe capable de voir ces lignes.
    if (driftAudit) UserSettings.instance.libraryDriftAudited = true;
    // Le rattrapage des lignes manquantes n'a pas besoin de rester ARMÉ tant
    // que tout n'est pas fabriqué: la borne de curseur ci-dessous repart
    // exactement là où le budget s'est épuisé, et une passe sans curseur coûte
    // la liste entière — inutile de la repayer à chaque tour.
    if (mintAudit) UserSettings.instance.libraryMintAudited = true;
    // Le curseur ne dépasse jamais une ligne restée sans `tracks` faute de
    // budget de fabrication: le delta filtre `updated_at >= p_since`, donc s'y
    // arrêter la ramène à la passe suivante, qui reprend le lot d'après. Sans
    // cette borne, une bibliothèque de plus de _kMintPerRun morceaux perdait
    // définitivement tout ce qui suivait le 40e.
    if (mintDeferred != null &&
        (maxSeen == null || !maxSeen!.isBefore(mintDeferred))) {
      maxSeen = mintDeferred;
      debugPrint('[SyncService] mint budget spent — cursor held at $maxSeen');
    }
    if (maxSeen != null) UserSettings.instance.libraryCursor = maxSeen;
    debugPrint('[SyncService] library pulled: ${songs.length} songs, '
        '${albums.length} albums (${auditExt ? "audit+" : ""}'
        '${full ? "full+" : ""}delta, cursor ${maxSeen ?? cursor})');
  }

  /// Drops a queued change that the account has already overtaken. Keeping it
  /// would make an old local gesture win over a newer remote one, which is
  /// exactly the case a plain outbox replay gets wrong.
  ///
  /// Retourne true quand un geste local SURVIT, c'est-à-dire qu'il est plus
  /// récent que le compte: l'appelant ne doit alors pas écraser l'état local
  /// avec celui du serveur (le ♥ de la migration 206 en dépend — sans ça, aimer
  /// hors ligne puis synchroniser rendait le ♥ juste posé).
  Future<bool> _arbitrate({
    required String itemType,
    String? itemId,
    String? extKey,
    int subsongIdx = 0,
    required DateTime serverUpdatedAt,
  }) async {
    final pending = await LocalDb.instance.pendingChangeFor(
      itemType: itemType, itemId: itemId, extKey: extKey,
      subsongIdx: subsongIdx);
    if (pending == null) return false;
    final changedAt = (pending['changed_at'] as int?) ?? 0;
    if (serverUpdatedAt.millisecondsSinceEpoch ~/ 1000 <= changedAt) return true;
    debugPrint('[SyncService] queued change on ${itemId ?? extKey} is older '
        'than the account — dropped');
    await LocalDb.instance.deleteSyncChange(pending['id'] as int);
    return false;
  }

  /// Ceiling on how many catalogue rows a single run resolves: minting needs
  /// one `get_song_context` each, and a fresh device restoring a large library
  /// must not spend its first sync on it. The rest is picked up next run.
  static const _kMintPerRun = 40;

  /// Creates the local `tracks` row a pulled favourite needs to be visible.
  /// The file is NOT downloaded — the path is computed the same way the rest of
  /// the app does for an online result, and playback falls back to
  /// download-and-play when the file is missing but the online id is there.
  /// Fabrique la ligne locale depuis une ENTRÉE résolue par le serveur
  /// (`get_song_entry(p_entry_rank)`): le titre, l'artiste, l'origine et le
  /// VRAI subsong_index de
  /// l'entrée — là où le chemin contexte fabriquait depuis le conteneur
  /// re-rétréci. Héritage borné assumé (clés « vrai index » écrites par
  /// l'ancien écran sur des fichiers à tracklist): faux uniquement sur les
  /// fichiers à décalage, réparé au play suivant.
  Future<bool> _mintFromEntry(
      String songId, int rank, SearchResult entry) async {
    try {
      final path = entry.localPath ?? await RewampDb.localPath(entry);
      await LocalDb.instance.upsertTrack(
        filePath:   path,
        // Le VRAI index (celui que le moteur joue) en clé locale; le RANG
        // reste dans l'identité `#`, comme les lignes nées d'un dépliage.
        subsongIdx: entry.subsongIdx,
        title:      entry.displayTitle,
        artist:     entry.artistLabel.isEmpty ? null : entry.artistLabel,
        metaAlbum:  entry.album,
        position:   entry.trackPosition,
        durationS:  entry.durationMs != null
            ? entry.durationMs! / 1000.0
            : null,
        formatExt:  entry.formatExt,
        subsongCount: entry.subsongCount,
        source:     'online',
        onlineId:   '${catalogueSongId(songId)}#$rank',
        albumId:    entry.albumId,
        collectionSlug: entry.collection,
        platformName:   entry.platform,
        artworkUrl: entry.artworkUrl,
      );
      return true;
    } catch (e) {
      debugPrint('[SyncService] mint(entry) $songId#$rank failed: $e');
      return false;
    }
  }

  /// Le chemin CONTEXTE — pour la ligne « fichier entier » (subsong 0,
  /// online_id NU) et pour un rang que le serveur n'a pas résolu (fichier
  /// sans tracklist: la valeur du compte est un vrai index de sous-chanson).
  Future<bool> _mintViaContext(String songId, int subsongIdx) async {
    try {
      final ctx = await RewampDb.getSongContext(songId);
      // `get_song_context` répond par le CONTENEUR pour un album jw_spc/jw_psf:
      // son `filename` est le nom de l'ALBUM et son `track_count` compte des
      // PISTES, pas des sous-chansons. Écrire ça tel quel posait un compte
      // d'album dans `subsong_count`, et la garde ci-dessous comparait alors un
      // index de sous-chanson à un nombre de membres d'archive — deux unités.
      final row = ctx == null
          ? null
          : RewampDb.narrowedToMember(ctx.song, songId);
      if (row == null) return false;
      // Le catalogue ne connaît que le morceau: pour un album CONTENEUR c'est
      // le conteneur, dont le titre est le nom de l'album et le chemin celui de
      // l'archive. Fabriquer une ligne à ce chemin en lui collant une
      // sous-chanson que le fichier n'a pas produisait un fantôme injouable —
      // que la bibliothèque trouvait AVANT la vraie ligne et relançait en
      // téléchargement. On ne fabrique que ce que le fichier peut porter.
      final count = row.subsongCount ?? 1;
      if (subsongIdx > 0 && subsongIdx >= count) {
        debugPrint('[SyncService] mint skipped: $songId has $count subsong(s), '
            'asked for #$subsongIdx');
        return false;
      }
      final path = row.localPath ?? await RewampDb.localPath(row);
      await LocalDb.instance.upsertTrack(
        filePath:   path,
        subsongIdx: subsongIdx,
        title:      row.displayTitle,
        artist:     row.artistLabel.isEmpty ? null : row.artistLabel,
        metaAlbum:  row.album,
        position:   row.trackPosition,
        durationS:  row.durationMs != null ? row.durationMs! / 1000.0 : null,
        formatExt:  row.formatExt,
        subsongCount: row.subsongCount,
        source:     'online',
        onlineId:   row.songId,
        albumId:    row.albumId,
        // L'ORIGINE est dans la main: la jeter fabriquait une ligne avec un
        // online_id et une collection NULLE, que le rattrapage par chemin ne
        // répare pas (il n'a tourné qu'une fois, à la migration 52).
        collectionSlug: row.collection,
        platformName:   row.platform,
        artworkUrl: row.artworkUrl,
      );
      return true;
    } catch (e) {
      debugPrint('[SyncService] mint $songId failed: $e');
      return false;
    }
  }

  /// Keys collected during one pull for [RewampDb.purgeExtLibrary]. Drained by
  /// [_purgeFabricatedKeys] at the end of the run, never mid-loop: a purge is
  /// irreversible, and one round trip for the whole batch beats one per row.
  final _purgeCandidates = <String>{};

  /// Is this snapshot the SIGNATURE of the title-as-file-name bug — as opposed
  /// to a genuine file that merely has no extension?
  ///
  /// Both clauses are required, and the second is what makes the purge safe.
  /// The bug fed ONE string to two different fields: `fileName` got the display
  /// title that `title` also holds, so the two match exactly ("03 Kingdom
  /// Baron" in both). A real push takes `fileName` from the basename on disk
  /// and `title` from the tags, so they differ — and the basename carries an
  /// extension anyway.
  ///
  /// Deliberately narrow, because the consequence is not symmetric: failing to
  /// purge leaves a harmless row the pull already ignores, while purging a
  /// legitimate key destroys another device's favourite AND its listening
  /// history, with no tombstone to notice it by. A dot-less name alone is NOT
  /// enough — a file with no extension is unusual, not impossible.
  static bool _isTitleShapedKey(PlaylistExtRef ref) =>
      !ref.fileName.contains('.') &&
      ref.title != null &&
      ref.title == ref.fileName;

  /// Retire les entrées de bibliothèque qui nomment un fichier local ABSENT —
  /// localement ET du compte. Rend le nombre retiré.
  ///
  /// Pourquoi une action explicite plutôt qu'un nettoyage automatique: une
  /// entrée locale absente d'ICI peut être présente sur un AUTRE appareil du
  /// compte, et la purge est globale (elle emporte aussi l'historique
  /// d'écoute de cette clé). C'est à l'utilisateur de le demander, en le
  /// sachant.
  ///
  /// Et pourquoi ça ne peut PAS être seulement local: le reset de la base
  /// remet les curseurs à zéro, donc le pull suivant re-matérialise tout
  /// depuis le compte. Supprimer ici sans purger là-bas ne fait que différer.
  ///
  /// ⚠️ La clé ext est RECALCULÉE, et deux variantes partent: avec le chemin
  /// relatif et sans. Les entrées d'avant le correctif des deux racines ont
  /// été poussées avec un `relPath` NUL (le fichier n'était relatif à rien),
  /// donc leur clé serveur ne se recalcule pas de la même façon que celle
  /// d'une entrée récente. Envoyer les deux coûte un élément de liste et
  /// rattrape les deux générations; une clé qui ne correspond à rien est
  /// ignorée par le serveur.
  /// ⚠️ **Chaque étape est BORNÉE dans le temps et se NOMME** ([onStage]).
  ///
  /// Ce geste tient l'écran derrière une barrière non annulable, et il enchaîne
  /// une synchro complète, un appel serveur par lot de 500 clés et une
  /// transaction: n'importe laquelle peut être longue sur une grosse
  /// bibliothèque, et une barrière opaque rend « long » indistinguable de
  /// « bloqué » — c'est exactement ce qui a été rapporté sur macOS. Les
  /// délais ne sont pas des correctifs de sûreté déguisés: chaque étape a un
  /// REPLI correct (garder les clés recalculées, supprimer localement quand
  /// même), donc l'abandonner en cours ne fait que revenir à ce que le code
  /// faisait déjà quand le réseau manque.
  static Future<int> purgeMissingLocalLibraryEntries(
      {void Function(String stage)? onStage}) async {
    final t0 = DateTime.now();
    void stage(String s) {
      debugPrint('[SyncService] nettoyage: $s '
          '(+${DateTime.now().difference(t0).inMilliseconds} ms)');
      onStage?.call(s);
    }

    // Passe COMPLÈTE ensuite, mais SEULEMENT si elle sert à quelque chose:
    // elle n'existe que pour hydrater les `ext_key` manquantes (colonne
    // neuve), et c'est de loin l'étape la plus lente — tout le catalogue de
    // bibliothèque du compte, sans curseur. Quand toutes les entrées
    // candidates portent déjà leur clé, on s'en passe et le nettoyage est
    // immédiat.
    stage('scan');
    // « Anonyme » se lit sur un drapeau RÉSOLU: son défaut est « on ne sait
    // pas encore » (accountHasEmailKnown), et le prendre pour « anonyme »
    // retirerait du compte les entrées d'un autre appareil.
    final solo = UserSettings.instance.accountHasEmailKnown &&
        !UserSettings.instance.accountHasEmail;
    var victims =
        await LocalDb.instance.missingLocalLibraryEntries(soloAccount: solo);
    debugPrint('[SyncService] nettoyage: ${victims.length} entrée(s) visée(s)');
    final needKeys = victims.any((v) => (v.$4 ?? '').isEmpty);
    if (needKeys && UserSettings.instance.hasAuthToken) {
      try {
        UserSettings.instance.libraryCursor = null;
        stage('sync');
        // Bornée: la synchro sert UNIQUEMENT à hydrater les clés manquantes,
        // et son repli — recalculer la clé, deux variantes — existe déjà
        // ci-dessous. La laisser sans limite, c'est faire dépendre un geste
        // local d'une passe serveur complète qui, elle, n'a pas de fin promise.
        await instance
            .syncNow(force: true)
            .timeout(const Duration(seconds: 45), onTimeout: () {
          debugPrint('[SyncService] nettoyage: sync trop longue, on continue '
              'avec les clés recalculées');
        });
      } catch (e) {
        debugPrint('[SyncService] pull préalable au nettoyage échoué: $e');
      }
      stage('scan');
      victims =
          await LocalDb.instance.missingLocalLibraryEntries(soloAccount: solo);
    }
    if (victims.isEmpty) return 0;
    final keys = <String>{};
    for (final (refId, _, sub, stored) in victims) {
      // La clé STOCKÉE d'abord — c'est celle que le compte connaît.
      if (stored != null && stored.isNotEmpty) {
        keys.add(stored);
        continue;
      }
      // Entrée antérieure à la colonne: on RECALCULE, en deux variantes (avec
      // et sans chemin relatif), parce que celles d'avant le correctif des
      // deux racines ont été poussées avec un relPath NUL. Une clé qui ne
      // correspond à rien est ignorée par le serveur.
      final (base, parsedSub) = splitLibraryRefId(refId);
      final fileName = base.split(Platform.pathSeparator).last;
      final rel = await LocalDb.instance.relPathOf(base);
      // Aucun suffixe ⇒ l'entrée vise le fichier ENTIER, et sa clé de compte
      // porte le jeton `whole` (voir localLibraryKey): la recalculer sans lui
      // désignerait la sous-chanson 0, une AUTRE entrée.
      final whole = parsedSub == null;
      keys.add(localLibraryKey(
          fileName: fileName, subsongIdx: sub, whole: whole));
      if (rel != null && rel.isNotEmpty) {
        keys.add(localLibraryKey(
            fileName: fileName, relPath: rel, subsongIdx: sub, whole: whole));
      }
    }
    try {
      if (UserSettings.instance.hasAuthToken) {
        stage('purge');
        // Bornée aussi: un lot de 500 clés par appel, et le commentaire
        // ci-dessous dit déjà quoi faire d'un échec — on supprime localement.
        await RewampDb.purgeExtLibrary(keys.toList())
            .timeout(const Duration(minutes: 2));
      }
    } catch (e) {
      debugPrint('[SyncService] purge ext échouée: $e');
      // On supprime quand même localement: l'utilisateur a demandé le
      // nettoyage, et une entrée que le compte renverra reviendra visible —
      // ce qui est un état honnête, pas une perte.
    }
    stage('delete');
    if (kDebugMode) {
      // Le détail de ce qui part, pour remonter au geste qui l'a écrit: la
      // FORME de la clé dit d'où vient l'entrée (`opened/`, `local_archives/`,
      // un `Caches/`… — voir libraryRefIsDeadIdentity), la clé de compte dit
      // si elle a été synchronisée.
      for (final (refId, name, sub, stored) in victims) {
        debugPrint('[purge] library_items: "$name" sub=$sub'
            ' ext_key=${(stored ?? '').isEmpty ? '-' : stored}'
            ' | $refId');
      }
    }
    await LocalDb.instance.runBatchWrites((db) async {
      for (final (refId, _, _, _) in victims) {
        await LocalDb.instance
            .removeFromLibrary('track', refId, db: db, notify: false);
      }
    });
    stage('done');
    return victims.length;
  }

  /// Hard-deletes the fabricated keys this pull met (migration 203). Best
  /// effort: a failure leaves them on the account, where the check above keeps
  /// ignoring them — exactly the state before the RPC existed.
  ///
  /// Returns false only when the call FAILED; nothing to purge is a success,
  /// and that distinction is what lets the one-shot audit retry instead of
  /// burning its single cursor-less pass on a network error.
  Future<bool> _purgeFabricatedKeys() async {
    if (_purgeCandidates.isEmpty) return true;
    final keys = _purgeCandidates.toList();
    _purgeCandidates.clear();
    try {
      final n = await RewampDb.purgeExtLibrary(keys);
      debugPrint('[SyncService] purged $n fabricated ext favourite(s) '
          'of ${keys.length} sent');
      return true;
    } catch (e) {
      debugPrint('[SyncService] ext purge kept for later: $e');
      return false;
    }
  }

  /// Applies an out-of-catalogue favourite coming from the account.
  ///
  /// Its snapshot describes a file of the user's own, which may not be on THIS
  /// device. Same treatment as a playlist entry: bind it if the file is here,
  /// otherwise keep a row pointing where the file would go, so the favourite is
  /// visible (missing) and binds by itself once the file is copied over.
  Future<void> _applyExtFavourite(UserLibrarySong s,
      {required bool canRemove}) async {
    final ref = s.extRef;
    if (ref == null) return;
    final subsong = ref.subsongIdx;
    if (s.updatedAt != null && s.extKey != null) {
      await _arbitrate(
        itemType: 'song', extKey: s.extKey, serverUpdatedAt: s.updatedAt!);
    }

    final existing = await LocalDb.instance.findTrackForSnapshot(
      relPath:    ref.relPath,
      fileName:   ref.fileName,
      entryPath:  ref.entryPath,
      subsongIdx: subsong,
    );

    // A snapshot whose "file name" carries NO EXTENSION never described a file:
    // it is a DISPLAY TITLE, pushed by the bug fixed in PlayerController (see
    // the comment there, and migration 39 which purged what it left on disk).
    // The account still holds those rows, and without this every pull minted
    // the phantom straight back — "03 Kingdom Baron" reappeared under
    // local/<title>, an entry pointing at a file that cannot exist, and playing
    // it resolved a homonym album.
    if (existing == null && !ref.fileName.contains('.')) {
      debugPrint('[SyncService] ext favourite "${ref.fileName}" has no file '
          'extension — a title, not a file name; skipped');
      if (s.extKey != null && _isTitleShapedKey(ref)) {
        _purgeCandidates.add(s.extKey!);
      }
      return;
    }

    final path = existing?.filePath ??
        await LocalDb.instance.expectedPathFor(
            relPath: ref.relPath, fileName: ref.fileName);
    // Une entrée qui vise le FICHIER ENTIER se reconnaît à l'absence de
    // suffixe (`localImportRefId`, `ContainerSubsongScreen._songRefId`), et le
    // compte le porte désormais explicitement — sans quoi il ne pourrait pas
    // la distinguer d'une entrée posée sur la sous-chanson 0.
    var refId = ref.whole ? path : '$path?subsong=$subsong';
    // ÉPOQUE ANTÉRIEURE: une entrée poussée avant `whole` porte
    // `subsong_idx = 0` et rien d'autre. Quand l'entrée CONTENEUR est déjà là,
    // c'est elle que cette ligne décrit: fabriquer la jumelle `?subsong=0`
    // DOUBLERAIT le fichier en bibliothèque, et la doublure ne jouerait que la
    // 1re sous-chanson. On ADOPTE donc l'entrée existante — même remède que
    // pour une playlist orpheline (voir PlaylistSync.pull). ⚠️ Borné à ce cas
    // d'époque: une entrée `whole` neuve et une entrée sur la sous-chanson 0
    // ont maintenant deux clés de compte distinctes et coexistent.
    if (!ref.whole && subsong == 0 &&
        await LocalDb.instance.isInLibrary('track', path)) {
      refId = path;
    }

    if (!s.inLibrary) {
      if (canRemove) await LocalDb.instance.removeFromLibrary('track', refId);
      return;
    }

    // La ligne `tracks` seulement si le fichier est ICI (ou déjà connu). Une
    // ligne « là où le fichier irait » était la façon d'avant de rendre
    // l'entrée visible; depuis `library_presence` c'est `library_items` seule
    // qui la montre, grisée, « sur un autre appareil ». Et cette ligne fantôme
    // avait un coût: le nettoyage la comptait ORPHELINE (fichier absent),
    // l'effaçait, et le pull suivant — delta INCLUSIF, donc la même entrée
    // revient à chaque passe — la refabriquait: « local/F-Zero.rsn » dans le
    // journal de purge à CHAQUE lancement (macOS, 2026-09-08). Une fois le
    // fichier copié ici, l'import crée la ligne, et `findTrackForSnapshot` la
    // lie au pull suivant.
    final present = existing != null || await File(path).exists();
    if (present) {
      await LocalDb.instance.upsertTrack(
        filePath:   path,
        entryPath:  ref.entryPath,
        subsongIdx: subsong,
        title:      ref.title,
        artist:     ref.artist,
        metaAlbum:  ref.album,
        durationS:  ref.durationS,
        formatExt:  ref.formatExt,
      );
    }
    await LocalDb.instance.addToLibrary(
      type:      'track',
      refId:     refId,
      name:      ref.title ?? ref.fileName,
      artist:    ref.artist,
      album:     ref.album,
      formatExt: ref.formatExt,
      filename:  ref.fileName,
      explicit:  true,
      // La clé que le COMPTE utilise, gardée telle quelle: c'est la seule
      // façon de retirer un jour cette entrée du compte à COUP SÛR. La
      // recalculer rate dès que le chemin a bougé depuis l'écriture (racine
      // différente, conteneur iOS renouvelé, relPath nul à l'époque).
      extKey:    s.extKey,
    );
  }

  /// Deletes the local library entries absent from the account's snapshot.
  /// Only rows with a server identity are candidates: a favourite on the
  /// user's own file is compared by ext_key, and one with neither is left
  /// alone.
  Future<void> _reconcileRemovals(List<LibraryIdRow> ids) async {
    // An EMPTY account cannot mean "everything was removed elsewhere": removals
    // travel as deltas, and no legitimate sequence turns a populated library
    // into a blank snapshot in one step. It is, on the other hand, exactly what
    // a BRAND-NEW account looks like — after an account deletion, or after the
    // token migration forced a re-registration. Reconciling against it would
    // wipe this device's own library. Additions still apply normally.
    if (ids.isEmpty) {
      debugPrint('[SyncService] empty account snapshot — removals skipped');
      return;
    }
    final serverSongs = <String>{};
    final serverExt = <String>{};
    final serverAlbums = <String>{};
    final serverPlaylists = <String>{};
    for (final r in ids) {
      if (r.extKey != null && r.extKey!.isNotEmpty) {
        serverExt.add(r.extKey!);
      } else if (r.id != null) {
        if (r.kind == 'song') serverSongs.add(r.id!);
        if (r.kind == 'album') serverAlbums.add(r.id!);
        if (r.kind == 'playlist') serverPlaylists.add(r.id!);
      }
    }

    var removed = 0;
    for (final item in await LocalDb.instance.getLibraryItems(type: 'track')) {
      final base = splitLibraryRefId(item.refId).$1;
      if (base.startsWith('/') || base.contains(':\\')) {
        // Fichier LOCAL: comparé par sa clé hors catalogue.
        //
        // ⚠️ **La clé STOCKÉE d'abord — c'est celle que le compte connaît**,
        // exactement la règle du nettoyage (`_cleanup`). La RECALCULER doit
        // reproduire tout le matériel du hachage, et cette boucle en oubliait
        // le `relPath`, que la poussée envoie pourtant
        // (`recordTrackMembership` le résout par `relPathOf`). Résultat: la
        // clé d'une entrée de fichier local ne correspondait à rien dans
        // `serverExt`, la réconciliation la SUPPRIMAIT (« 19 library item(s)
        // removed elsewhere »), le pull suivant la re-fabriquait — et les
        // « Ajoutés récemment » clignotaient à chaque cycle de synchro.
        //
        // Le jeton `whole` fait partie du même matériel: sans lui une entrée
        // de CONTENEUR (refId sans suffixe) se recalcule en clé de
        // sous-chanson 0, une AUTRE entrée.
        final parsedSub = splitLibraryRefId(item.refId).$2;
        final stored = item.extKey;
        if (stored != null && stored.isNotEmpty) {
          if (serverExt.contains(stored)) continue;
        } else {
          final fileName = base.split(Platform.pathSeparator).last;
          final rel = await LocalDb.instance.relPathOf(base);
          final whole = parsedSub == null;
          final candidates = <String>{
            localLibraryKey(
                fileName: fileName, relPath: rel,
                subsongIdx: parsedSub ?? 0, whole: whole),
            // Variante SANS chemin relatif: les entrées d'avant le correctif
            // des deux racines sont parties avec un relPath nul (même repli
            // que `_cleanup`).
            localLibraryKey(
                fileName: fileName,
                subsongIdx: parsedSub ?? 0, whole: whole),
          };
          if (candidates.any(serverExt.contains)) continue;
        }
        // Key mismatch is possible for pre-sync rows (different material) —
        // only remove when the account HOLDS ext favourites at all, else a
        // legacy install would lose its local favourites on first sync.
        if (serverExt.isEmpty) continue;
        await LocalDb.instance.removeFromLibrary('track', item.refId, notify: false);
        removed++;
        continue;
      }
      if (serverSongs.contains(base)) continue;
      await LocalDb.instance.removeFromLibrary('track', item.refId, notify: false);
      removed++;
    }
    for (final item in await LocalDb.instance.getLibraryItems(type: 'album')) {
      final id = item.albumId;
      if (id == null || id.isEmpty) continue; // local-only album
      if (serverAlbums.contains(id)) continue;
      await LocalDb.instance.removeFromLibrary('album', item.refId, notify: false);
      removed++;
    }
    // Saved server playlists travel through the same snapshot (kind
    // 'playlist'), so un-saving one on another device is applied here too —
    // syncLibraryPlaylists only ever ADDS.
    for (final item in await LocalDb.instance.getLibraryItems(type: 'playlist')) {
      if (serverPlaylists.contains(item.refId)) continue;
      await LocalDb.instance.removeFromLibrary('playlist', item.refId, notify: false);
      removed++;
    }
    if (removed > 0) {
      debugPrint('[SyncService] $removed library item(s) removed elsewhere');
      // UNE notification pour tout le lot: chaque retrait en émettait une, et
      // chaque écran monté re-requêtait la base à chacune — la grille
      // « Ajoutés récemment » se réorganisait sous les yeux, entrée par
      // entrée.
      LocalDb.instance.notifyListeners();
    }
  }

  /// Le compte tient-il une entrée que cet appareil n'a pas — ou un ♥ que cet
  /// appareil ignore ? La photo d'identités (`user_library_ids`) porte le ♥
  /// depuis la migration 206, donc les deux se voient d'un seul appel.
  ///
  /// Ne CORRIGE rien: dit seulement s'il faut repasser sans curseur. La
  /// correction reste au delta, qui a les métadonnées (nom, pochette) qu'une
  /// photo d'identités n'a pas.
  Future<bool> _accountHasWhatWeLack(List<LibraryIdRow> ids) async {
    if (ids.isEmpty) return false;
    // Les entrées locales, par identité serveur.
    // Clé morceau = identité SERVEUR complète, sous-chanson comprise: deux
    // sous-chansons du même fichier sont deux entrées distinctes du compte, et
    // comparer sur le seul uuid ferait passer la seconde pour déjà présente.
    final localSongs = <String, bool>{};   // '<uuid>#<subsong>' → ♥
    final localAlbums = <String, bool>{};
    // Une entrée de bibliothèque SANS ligne `tracks` est invisible partout —
    // la playlist Favoris comme l'onglet Bibliothèque lisent à travers cette
    // table. C'est l'état que laissait le plafond de fabrication combiné au
    // curseur (une bibliothèque de plus de _kMintPerRun morceaux perdait tout
    // ce qui suivait le 40e), et rien ne le voyait: la photo d'identités ne
    // parle que d'appartenance. Le seul remède est le même que pour une entrée
    // jamais appliquée — repasser sans curseur.
    final localTracks = await LocalDb.instance.catalogueTrackKeys();
    for (final item in await LocalDb.instance.getLibraryItems(type: 'track')) {
      final (base, sub) = splitLibraryRefId(item.refId);
      localSongs['$base#${sub ?? 0}'] = item.isFavorite;
    }
    for (final item in await LocalDb.instance.getLibraryItems(type: 'album')) {
      final id = item.albumId;
      if (id != null && id.isNotEmpty) localAlbums[id] = item.isFavorite;
    }
    for (final r in ids) {
      // Le hors catalogue est laissé de côté: son identité locale est un
      // chemin de fichier, qui n'existe pas forcément sur cet appareil — un
      // écart y est légitime, et `_applyExtFavourite` en a la charge.
      if (r.extKey != null && r.extKey!.isNotEmpty) continue;
      final id = r.id;
      if (id == null) continue;
      if (r.kind != 'song' && r.kind != 'album') continue;
      final local = r.kind == 'song'
          ? localSongs['$id#${r.subsongIndex ?? 0}']
          : localAlbums[id];
      if (local == null) return true;              // entrée jamais appliquée
      if (r.favourite && !local) return true;      // ♥ du compte jamais vu
      // Entrée appliquée mais sans ligne `tracks`: elle n'apparaît nulle part.
      if (r.kind == 'song' &&
          !localTracks.contains('$id#${r.subsongIndex ?? 0}')) {
        return true;
      }
    }
    return false;
  }

  // ── Le ♥ (migration serveur 206) ──────────────────────────────────────────
  //
  // Il vivait ici, dans le blob opaque `user_state.favourites`: le compte
  // n'avait qu'un drapeau `in_library` et « favori » était une notion cliente,
  // fusionnée à la main avec une date par élément. Le serveur porte désormais
  // les DEUX états en colonnes, avec l'invariant `favourite ⇒ inLibrary`
  // garanti côté serveur — donc plus de fusion cliente, plus de blob réécrit en
  // entier, et le ♥ arrive dans le delta `p_since` comme n'importe quel
  // changement d'appartenance. L'écriture part par l'outbox (`p_favourite`),
  // la lecture est appliquée par _pullLibrary.

  static const _kFavouritesKey = 'favourites';

  /// Efface le blob une fois pour toutes. Le serveur ne le touche pas (contrat
  /// d'opacité de la mig 178), donc c'est au client de le faire — sinon un
  /// appareil resté en arrière continuerait de le lire et de croire à un état
  /// que plus personne n'écrit.
  Future<void> _purgeFavouritesBlob() async {
    if (UserSettings.instance.favouritesBlobPurged) return;
    try {
      await RewampDb.setUserState(_kFavouritesKey, null);
      UserSettings.instance.favouritesBlobPurged = true;
      debugPrint('[SyncService] favourites blob purged (server mig 206)');
    } catch (e) {
      debugPrint('[SyncService] favourites blob purge deferred: $e');
    }
  }

  /// Rapatrie la liste COMPLÈTE de chaque album favori, une fois chacun.
  ///
  /// Le seul juge est le marqueur `album_materialised`: ni la présence de
  /// lignes `tracks` (une piste jouée en crée une), ni leur NOMBRE. Une
  /// première version se contentait de « plus d'une piste = tenu pour
  /// complet » et a gelé des listes partielles — un appareil resté à 11 pistes
  /// là où l'autre en listait 67, avec les deux albums marqués complets. Une
  /// requête par album favori, une seule fois dans la vie de l'installation:
  /// c'est le prix d'une liste juste.
  ///
  /// Plafonné par passe — une installation neuve qui restaure une grosse
  /// bibliothèque ne doit pas partir en rafale; la passe suivante prend le
  /// lot d'après.
  static const _kHealAlbumsPerRun = 5;

  Future<void> _healAlbumFavourites() async {
    // ONE-SHOT: jeter les marqueurs posés par le repli « plus d'une piste =
    // complet », qui a figé des listes partielles. Le marqueur n'est qu'un
    // cache: le perdre coûte une requête par album favori.
    if (!UserSettings.instance.albumMaterialisedReset) {
      await LocalDb.instance.clearAlbumMaterialised();
      UserSettings.instance.albumMaterialisedReset = true;
      debugPrint('[SyncService] album materialisation markers reset');
    }
    // Marqueurs que la base DÉMENT — ceux laissés par l'ancienne purge, qui
    // retirait les lignes de catalogue non téléchargées sans toucher au
    // marqueur. Sans ça l'album reste figé sur une liste amputée: le marqueur
    // dit « complet », le heal passe son chemin. À CHAQUE passe et non une
    // seule fois: c'est un contrôle de cohérence, pas une migration — une
    // suppression d'album efface désormais le marqueur elle-même
    // (deleteEntriesUnderPath), mais un chemin oublié se rattraperait ici.
    final pruned = await LocalDb.instance.pruneStaleAlbumMaterialised();
    if (pruned > 0) {
      debugPrint('[SyncService] $pruned marqueur(s) album périmé(s) retiré(s)');
    }
    var healed = 0;
    for (final item in await LocalDb.instance.getLibraryItems(type: 'album')) {
      if (healed >= _kHealAlbumsPerRun) break;
      if (!item.isFavorite) continue;
      final id = item.albumId;
      if (id == null || id.isEmpty) continue;
      // Le test porte sur le MARQUEUR (mig locale 47), pas sur la présence de
      // lignes: `hasLocalAlbum` répond oui dès UNE piste, et une piste jouée
      // ici en crée une — l'album restait alors à une piste pour toujours,
      // alors qu'un autre appareil du compte en listait trente-sept.
      if (await LocalDb.instance.isAlbumMaterialised(id)) continue;
      await _materializeAlbum(id, item.name);
      healed++;
    }
  }

  /// Applies what the merge decided, dating each write with the DECISION's own
  /// timestamp so a received choice does not look authored here.
  /// Fills `tracks` with an album's full listing so a favourite received from
  /// another device lists more than what this one happened to play. Purely
  /// local writes — no download, same as the authoring path.
  Future<void> _materializeAlbum(String albumId, String albumName) async {
    if (albumId.isEmpty) return;
    try {
      final rows = await RewampDb.albumTracks(albumId: albumId);
      if (rows.isEmpty) return;
      await RewampDb.materializeAlbumTracks(albumName, rows, albumId: albumId);
      debugPrint('[SyncService] materialised ${rows.length} track(s) '
          'for album "$albumName"');
    } catch (e) {
      // The heart itself is applied; the list just stays played-only until the
      // next run picks it up.
      debugPrint('[SyncService] materialise album "$albumName" failed: $e');
    }
  }

  /// Stable identity of an OUT-OF-CATALOGUE favourite (a file of the user's
  /// own). Hashed, so it holds whatever the file name and path are while
  /// staying far under the server's 200-character bound; the readable detail
  /// travels in the snapshot next to it.
  static String localLibraryKey({
    required String fileName,
    String? relPath,
    String entryPath = '',
    int subsongIdx = 0,
    /// L'entrée vise le FICHIER ENTIER (voir [PlaylistExtRef.whole]). Le jeton
    /// n'est AJOUTÉ que dans ce cas: une entrée ordinaire garde la clé qu'elle
    /// avait avant ce paramètre, donc aucune entrée de compte existante ne
    /// change d'identité.
    bool whole = false,
  }) {
    final material = [
      fileName.toLowerCase(),
      (relPath ?? '').toLowerCase(),
      entryPath.toLowerCase(),
      '$subsongIdx',
      if (whole) 'whole',
    ].join('|');
    return 'local:${sha256.convert(utf8.encode(material))}';
  }

  /// Queues a favourite made on a LOCAL file (no catalogue id). The change is
  /// parked in the outbox — `set_library` cannot take it yet (proposal §2bis:
  /// `p_ext_key` + `p_ext_ref`) — but it is recorded NOW so nothing is lost the
  /// day the server can receive it.
  static Future<void> recordLocalLibraryChange({
    required String itemType,
    required String fileName,
    required bool value,
    /// Voir [recordLibraryChange] — le ♥ marche à l'identique sur un favori
    /// hors catalogue (`p_ext_key`), spec mig 206 §1.
    bool? favourite,
    String? relPath,
    String entryPath = '',
    int subsongIdx = 0,
    /// L'entrée vise le FICHIER ENTIER (voir [PlaylistExtRef.whole]).
    bool whole = false,
    String? title,
    String? artist,
    String? album,
    String? formatExt,
    double? durationS,
    DatabaseExecutor? db,
    /// La clé que le compte tient DÉJÀ pour cette entrée, quand on la connaît:
    /// elle prime sur le recalcul. Voir LocalDb.libraryExtKeyOf.
    String? extKey,
  }) async {
    final ref = PlaylistExtRef(
      fileName:   fileName,
      relPath:    relPath,
      entryPath:  entryPath,
      subsongIdx: subsongIdx,
      whole:      whole,
      title:      title,
      artist:     artist,
      album:      album,
      formatExt:  formatExt,
      durationS:  durationS,
    );
    await LocalDb.instance.queueLibraryChange(
      db:         db,
      itemType:   itemType,
      itemId:     '', // no server identity — kept until the contract lands
      value:      value,
      favourite:  favourite,
      subsongIdx: subsongIdx,
      extKey:     extKey ?? localLibraryKey(
        fileName: fileName, relPath: relPath,
        entryPath: entryPath, subsongIdx: subsongIdx, whole: whole),
      // Same snapshot the playlists use — a favourite and a playlist entry
      // point at a file the same way.
      extRef:     jsonEncode(ref.toJson()),
    );
  }

  /// Queues one LOCAL-file play for delivery (log_plays_ext). Same ext
  /// identity as an out-of-catalogue favourite ([localLibraryKey]) — écoute et
  /// ♥ fusionnent sur la même ligne serveur. The event survives offline in
  /// its own outbox; the drain ships it in idempotent batches.
  static Future<void> recordExtPlay({
    required String fileName,
    String? relPath,
    String entryPath = '',
    int subsongIdx = 0,
    required int durationMs,
    String? title,
    String? artist,
    String? album,
    String? formatExt,
    double? durationS,
    /// Slug du moteur qui a décodé (voir [RewampDb.logPlay]).
    String? backend,
    /// Ligne `play_events` locale que la livraison du lot marquera `pushed`
    /// (l'écoute reviendra par la timeline du compte — la compter des deux
    /// côtés la doublerait dans l'écran Stats).
    int? playEventId,
    /// Piste locale à qui appartient cette écoute: son `ext_key` est posé au
    /// passage, seul moyen de reconnaître ensuite, dans la timeline du compte,
    /// un fichier qui est ici.
    String? trackId,
  }) async {
    final ref = PlaylistExtRef(
      fileName:   fileName,
      relPath:    relPath,
      entryPath:  entryPath,
      subsongIdx: subsongIdx,
      title:      title,
      artist:     artist,
      album:      album,
      formatExt:  formatExt,
      durationS:  durationS,
    );
    final key = localLibraryKey(
        fileName: fileName, relPath: relPath,
        entryPath: entryPath, subsongIdx: subsongIdx);
    if (trackId != null) await LocalDb.instance.setTrackExtKey(trackId, key);
    await LocalDb.instance.queueExtPlay(
      extKey: key,
      extRef:         jsonEncode(ref.toJson()),
      durationMs:     durationMs,
      playedAtEpochS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      playEventId:    playEventId,
      backend:        backend,
    );
    // Une écoute n'est pas urgente — le prochain sync (ou celui-ci, nudgé
    // large) l'emportera avec le reste.
    instance.nudge(delay: const Duration(seconds: 30));
  }

  /// Le nom d'une entrée de bibliothèque appliquée par le pull.
  ///
  /// ⚠️ **Le NIVEAU du nom doit suivre le NIVEAU de l'entrée**, et les deux
  /// erreurs symétriques ont été payées:
  /// - une entrée de PISTE nommée par le catalogue prenait le nom du
  ///   CONTENEUR (`user_songs` ne connaît que le morceau du catalogue, or pour
  ///   un album conteneur c'est le conteneur): la piste se renommait « Wild
  ///   Arms » et la lecture retéléchargeait l'album. D'où la ligne locale
  ///   d'abord;
  /// - une entrée de CONTENEUR (refId SANS suffixe `?subsong=`) prenait la
  ///   ligne locale, qui est celle de sa SOUS-CHANSON 0 — titre numéroté. Le
  ///   pull renommait « Commando » en « Commando (1) », juste après le geste.
  ///   D'où le titre de CATALOGUE d'abord, puis le nom de fichier.
  @visibleForTesting
  static String libraryEntryName({
    required bool containerEntry,
    String? localTitle,
    String? catalogueTitle,
    String? fileName,
  }) {
    String? pick(List<String?> candidates) {
      for (final c in candidates) {
        if (c != null && c.isNotEmpty) return c;
      }
      return null;
    }
    return (containerEntry
            ? pick([catalogueTitle, fileName, localTitle])
            : pick([localTitle, catalogueTitle])) ??
        '?';
  }

  /// Fait suivre au COMPTE une appartenance de MORCEAU, quelle que soit la
  /// porte d'entrée de l'UI. [refId] est la clé locale
  /// (`<uuid|chemin>?subsong=N`); l'identité catalogue et l'identité de
  /// fichier partent chacune par leur chemin.
  ///
  /// Elle existe parce que ce geste a QUATRE portes d'entrée (le bouton de
  /// bibliothèque, la feuille d'options d'un morceau, le menu du lecteur, son
  /// bouton dédié) et que trois d'entre elles écrivaient en local sans rien
  /// envoyer: le compte gardait l'entrée, l'autre appareil aussi, et le
  /// rattrapage la REMETTAIT sur l'appareil qui venait de la retirer.
  static Future<void> recordTrackMembership({
    required String refId,
    required bool value,
    String? title,
    String? artist,
    String? album,
    String? formatExt,
    /// Écriture en LOT: exécuteur de la transaction en cours (voir
    /// LocalDb.runBatchWrites) — l'outbox s'écrit dans le MÊME commit.
    DatabaseExecutor? db,
  }) async {
    if (!UserSettings.instance.hasAuthToken) return;
    final (base, sub) = splitLibraryRefId(refId);
    if (base.isEmpty) return;
    final isPath = base.startsWith('/') || base.contains(':\\');
    if (isPath) {
      // Un RETRAIT part sous la clé que le compte TIENT, jamais sous une clé
      // recalculée: la forme de l'entrée (nue ou `?subsong=0`) entre dans le
      // hachage et peut différer entre l'appareil qui a ajouté et celui qui
      // retire — le retrait viserait alors une clé que le compte n'a pas, et
      // l'entrée y resterait pour toujours (mesuré sur `F-Zero.rsn`: ajoutée
      // ailleurs en `?subsong=0`, tenue ici en forme nue). Un AJOUT, lui,
      // définit la clé: on la calcule.
      final stored = value
          ? null
          : await LocalDb.instance.libraryExtKeyOf('track', refId, db: db);
      await recordLocalLibraryChange(
        itemType:   'song',
        fileName:   base.split(Platform.pathSeparator).last,
        relPath:    await LocalDb.instance.relPathOf(base),
        value:      value,
        extKey:     stored,
        // Pas de suffixe `?subsong=` ⇒ l'entrée vise le FICHIER ENTIER. Le
        // dire au compte est ce qui la distingue d'un favori posé sur la
        // sous-chanson 0 (voir PlaylistExtRef.whole).
        subsongIdx: sub ?? 0,
        whole:      sub == null,
        title:      title,
        artist:     artist,
        album:      album,
        formatExt:  formatExt,
        db:         db,
      );
      return;
    }
    await recordLibraryChange(
      itemType:   'song',
      itemId:     base,
      value:      value,
      subsongIdx: sub ?? 0,
    );
  }

  /// Queues a favourite/library change AND notifies the server soon. The only
  /// entry point the UI should use — writing straight to [RewampDb.setLibrary]
  /// loses the change when the request fails.
  static Future<void> recordLibraryChange({
    required String itemType,
    required String itemId,
    required bool value,
    /// Migration serveur 206: non-null = ce geste est un ♥ (et [value] ne part
    /// pas). Un ♥ pose l'entrée en bibliothèque côté serveur; un un-♥ l'y
    /// laisse.
    bool? favourite,
    int subsongIdx = 0,
    String? extKey,
    Map<String, dynamic>? extRef,
  }) async {
    // The outbox is SERVER-bound, so it holds the server's shape of the id.
    // A container subsong is '<uuid>#<i>' locally, which the uuid column
    // rejects (22P02) — et le `#N` doit repartir dans la SOUS-CHANSON, sinon
    // toutes les pistes d'un album conteneur écrivent sur la même ligne de
    // compte (voir catalogueSongRef).
    final (serverId, serverSub) =
        catalogueSongRef(itemId, subsongIdx: subsongIdx);
    await LocalDb.instance.queueLibraryChange(
      itemType:   itemType,
      itemId:     serverId ?? itemId,
      value:      value,
      favourite:  favourite,
      subsongIdx: serverSub,
      extKey:     extKey,
      extRef:     extRef == null ? null : jsonEncode(extRef),
    );
    instance.nudge(delay: const Duration(seconds: 3));
  }
}
