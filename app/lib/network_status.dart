// État RÉEL du lien avec le serveur Rewamp — pas seulement « le Wi-Fi est-il
// allumé »: un réseau présent mais instable, ou un serveur surchargé, laissaient
// chaque écran attendre jusqu'à sa propre échéance puis afficher l'exception
// brute en rouge (« TimeoutException after 0:00:25.000000 … »).
//
// Trois pièces:
//  * [NetworkAwareClient] — installé pour TOUTE l'app par `http.runWithClient`
//    (main.dart): chaque requête vers le serveur dit si elle a abouti, échoué,
//    ou traîne. Aucun des ~40 appels de rewamp_db.dart n'a à changer.
//  * [NetworkStatus] — l'état qui en découle (ok / hors ligne / serveur lent),
//    et, tant qu'il n'est pas ok, une SONDE légère et régulière qui constate le
//    retour du serveur au lieu d'attendre que l'utilisateur réessaie.
//  * `load_error.dart` — ce qu'un écran AFFICHE quand son chargement échoue.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'client_info.dart';

enum NetIssue {
  /// Le serveur répond.
  none,

  /// Aucune route: pas de réseau, DNS introuvable, hôte injoignable.
  offline,

  /// Le réseau est là mais le serveur ne répond pas (assez vite): réseau
  /// instable, serveur surchargé, 5xx de passerelle.
  slow,
}

class NetworkStatus extends ValueNotifier<NetIssue> {
  NetworkStatus._() : super(NetIssue.none);
  static final NetworkStatus instance = NetworkStatus._();

  /// Les hôtes dont la santé fait l'état. Les sources tierces (modland,
  /// scene.org…) ont leurs propres pannes, qui ne disent rien du nôtre.
  static const watchedHosts = {'api.rewamp.app'};

  /// Une requête plus longue que ça marque le lien comme lent (elle continue,
  /// et la réussite qui suivra remettra tout à ok).
  static const slowAfter = Duration(seconds: 8);

  /// Ce qu'on interroge pour constater le retour: une ligne d'une table
  /// publique, quelques octets.
  static final Uri probeUri =
      Uri.parse('https://api.rewamp.app/collections?select=slug&limit=1');

  Timer? _probeTimer;
  Duration _probeGap = const Duration(seconds: 10);
  bool _probing = false;

  /// Une requête vers le serveur a abouti (réponse HTTP qui n'est pas une
  /// panne de passerelle).
  void reportOk() {
    if (value == NetIssue.none) return;
    _set(NetIssue.none);
  }

  void reportIssue(NetIssue issue) {
    if (issue == NetIssue.none) return reportOk();
    // « Hors ligne » est plus précis que « lent »: il gagne.
    if (value == NetIssue.offline && issue == NetIssue.slow) return;
    _set(issue);
  }

  void _set(NetIssue v) {
    if (value == v) return;
    debugPrint('[net] $value → $v');
    value = v;
    _probeTimer?.cancel();
    _probeTimer = null;
    if (v != NetIssue.none) {
      _probeGap = const Duration(seconds: 10);
      _scheduleProbe();
    }
  }

  void _scheduleProbe() {
    _probeTimer?.cancel();
    _probeTimer = Timer(_probeGap, probeNow);
  }

  /// Interroge le serveur maintenant (retour au premier plan, bouton
  /// « Réessayer »). Sans effet quand tout va bien.
  Future<void> probeNow() async {
    if (value == NetIssue.none || _probing) return;
    _probing = true;
    // Un client BRUT: la sonde ne passe pas par NetworkAwareClient (elle
    // rapporte elle-même), et un client neuf évite une connexion à moitié
    // morte gardée par le pool.
    final c = http.Client();
    try {
      final r = await c.get(probeUri).timeout(const Duration(seconds: 6));
      if (r.statusCode < 500) {
        _probing = false;
        reportOk();
        return;
      }
      reportIssue(NetIssue.slow);
    } catch (e) {
      reportIssue(classifyNetError(e) == NetIssue.offline
          ? NetIssue.offline
          : NetIssue.slow);
    } finally {
      _probing = false;
      c.close();
    }
    if (value != NetIssue.none) {
      // 10 s, 15 s, 22 s… plafonné à une minute.
      final next = _probeGap * 3 ~/ 2;
      _probeGap = next > const Duration(minutes: 1) ? const Duration(minutes: 1) : next;
      _scheduleProbe();
    }
  }

  @visibleForTesting
  void resetForTest() {
    _probeTimer?.cancel();
    _probeTimer = null;
    value = NetIssue.none;
  }
}

/// Ce qu'une exception dit du LIEN: hors ligne, lent/instable, ou rien du tout
/// (une vraie erreur applicative — on ne la met pas sur le dos du réseau).
NetIssue classifyNetError(Object e) {
  if (e is SocketException) {
    final m = e.message.toLowerCase();
    if (m.contains('timed out')) return NetIssue.slow;
    return NetIssue.offline;
  }
  if (e is TimeoutException) return NetIssue.slow;
  final s = e.toString();
  if (s.contains('Failed host lookup') ||
      s.contains('Network is unreachable') ||
      s.contains('No route to host') ||
      s.contains('Connection refused') ||
      s.contains('nodename nor servname') ||
      s.contains('No address associated')) {
    return NetIssue.offline;
  }
  if (s.contains('TimeoutException') ||
      s.contains('timed out') ||
      s.contains('Connection closed') ||
      s.contains('Connection reset') ||
      s.contains('HandshakeException') ||
      s.contains('Software caused connection abort')) {
    return NetIssue.slow;
  }
  return NetIssue.none;
}

/// Le client HTTP de l'app: transmet tout au client réel et rapporte à
/// [NetworkStatus] ce qu'il voit des requêtes vers [NetworkStatus.watchedHosts].
class NetworkAwareClient extends http.BaseClient {
  NetworkAwareClient([http.Client? inner]) : _inner = inner ?? http.Client();
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final status = NetworkStatus.instance;
    if (!NetworkStatus.watchedHosts.contains(request.url.host)) {
      return _inner.send(request);
    }
    // Qui appelle: plateforme + version, pour les statistiques par plateforme
    // (docs/client_platform_proposal.md). Seulement vers NOTRE API — jamais
    // vers les sources tierces.
    request.headers['X-Rewamp-Client'] = ClientInfo.headerValue;
    final slowTimer =
        Timer(NetworkStatus.slowAfter, () => status.reportIssue(NetIssue.slow));
    try {
      final r = await _inner.send(request);
      // 502/503/504: la passerelle n'a pas eu de réponse du serveur.
      if (r.statusCode == 502 || r.statusCode == 503 || r.statusCode == 504) {
        status.reportIssue(NetIssue.slow);
      } else {
        status.reportOk();
      }
      return r;
    } catch (e) {
      final issue = classifyNetError(e);
      if (issue != NetIssue.none) status.reportIssue(issue);
      rethrow;
    } finally {
      slowTimer.cancel();
    }
  }

  @override
  void close() => _inner.close();
}
