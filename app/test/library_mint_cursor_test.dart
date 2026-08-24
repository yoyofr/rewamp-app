// Le curseur de bibliothèque ne doit JAMAIS dépasser une ligne que le plafond
// de fabrication (`_kMintPerRun`) a laissée sans ligne `tracks`.
//
// Le symptôme, constaté sur macOS après la remise à zéro de la beta 3: les
// morceaux et albums favoris apparaissaient bien dans l'onglet Bibliothèque
// (qui lit `library_items`), mais la playlist Favoris en listait une partie
// seulement — elle lit à travers `tracks`, et une entrée dont la ligne n'a
// jamais été fabriquée y est invisible. Définitivement: le curseur avait
// avancé sur TOUTES les lignes reçues, y compris celles que le budget n'avait
// pas eu le temps de traiter, et un delta ne ramène jamais ce qui le précède.
// Télécharger un album par un autre chemin (lancer une playlist) fabriquait
// ces lignes et faisait « réapparaître » les favoris correspondants.
//
// Le test porte sur la RÈGLE (borne du curseur + détection de la dérive), pas
// sur SyncService, qui demande réseau et path_provider.
import 'package:flutter_test/flutter_test.dart';

/// Une ligne de delta réduite à ce que la boucle lit.
typedef SongRow = ({String id, int subsong, DateTime? updatedAt});

typedef PullResult = ({DateTime? cursor, Set<String> minted});

/// La boucle de `SyncService._pullLibrary`, réduite à la fabrication et au
/// curseur. [have] = identités déjà présentes dans `tracks`, forme serveur
/// `<uuid>#<sous-chanson>`.
PullResult pull(
  List<SongRow> songs, {
  required Set<String> have,
  required int budget,
}) {
  DateTime? maxSeen;
  DateTime? mintDeferred;
  var minted = 0;
  final made = <String>{};

  for (final s in songs) {
    if (s.updatedAt != null &&
        (maxSeen == null || s.updatedAt!.isAfter(maxSeen))) {
      maxSeen = s.updatedAt;
    }
    if (s.updatedAt == null) continue;
    final key = '${s.id}#${s.subsong}';
    if (have.contains(key) || made.contains(key)) continue;
    if (minted < budget) {
      made.add(key);
      minted++;
    } else if (mintDeferred == null || s.updatedAt!.isBefore(mintDeferred)) {
      mintDeferred = s.updatedAt;
    }
  }

  if (mintDeferred != null &&
      (maxSeen == null || !maxSeen.isBefore(mintDeferred))) {
    maxSeen = mintDeferred;
  }
  return (cursor: maxSeen, minted: made);
}

/// `SyncService._accountHasWhatWeLack`, réduit à la clause ajoutée: une entrée
/// appliquée mais SANS ligne `tracks` est invisible et doit forcer une passe
/// sans curseur.
bool lacksTrackRow(List<SongRow> account, Set<String> localTracks) {
  for (final r in account) {
    if (!localTracks.contains('${r.id}#${r.subsong}')) return true;
  }
  return false;
}

DateTime at(int minute) => DateTime.utc(2026, 8, 17, 12, minute);

void main() {
  test('le curseur s\'arrête à la première ligne reportée', () {
    final songs = [
      for (var i = 0; i < 5; i++)
        (id: 's$i', subsong: 0, updatedAt: at(i)),
    ];
    final r = pull(songs, have: {}, budget: 2);
    expect(r.minted, {'s0#0', 's1#0'});
    // s2 est la première reportée: le curseur ne va pas plus loin, et le delta
    // filtrant `updated_at >= p_since`, la passe suivante la reprend.
    expect(r.cursor, at(2));
  });

  test('la passe suivante reprend exactement où le budget s\'est épuisé', () {
    final songs = [
      for (var i = 0; i < 5; i++)
        (id: 's$i', subsong: 0, updatedAt: at(i)),
    ];
    final first = pull(songs, have: {}, budget: 2);
    final rest = songs
        .where((s) => !s.updatedAt.isBefore(first.cursor!))
        .toList();
    final second = pull(rest, have: first.minted, budget: 2);
    expect(second.minted, {'s2#0', 's3#0'});
    expect(second.cursor, at(4));
    final third = pull(
      songs.where((s) => !s.updatedAt.isBefore(second.cursor!)).toList(),
      have: {...first.minted, ...second.minted},
      budget: 2,
    );
    expect(third.minted, {'s4#0'});
    // Plus rien en attente: le curseur repart en tête.
    expect(third.cursor, at(4));
  });

  test('un budget suffisant laisse le curseur aller au bout', () {
    final songs = [
      for (var i = 0; i < 3; i++)
        (id: 's$i', subsong: 0, updatedAt: at(i)),
    ];
    expect(pull(songs, have: {}, budget: 40).cursor, at(2));
  });

  test('une ligne déjà présente ne consomme pas le budget', () {
    final songs = [
      (id: 's0', subsong: 0, updatedAt: at(0)),
      (id: 's1', subsong: 0, updatedAt: at(1)),
      (id: 's2', subsong: 0, updatedAt: at(2)),
    ];
    final r = pull(songs, have: {'s0#0'}, budget: 2);
    expect(r.minted, {'s1#0', 's2#0'});
    expect(r.cursor, at(2));
  });

  test('deux sous-chansons du même fichier sont deux lignes distinctes', () {
    final songs = [
      (id: 's0', subsong: 0, updatedAt: at(0)),
      (id: 's0', subsong: 1, updatedAt: at(1)),
    ];
    final r = pull(songs, have: {}, budget: 1);
    expect(r.minted, {'s0#0'});
    expect(r.cursor, at(1));
  });

  test('l\'entrée sans ligne tracks est une dérive, pas un état stable', () {
    final account = [
      (id: 's0', subsong: 0, updatedAt: at(0)),
      (id: 's1', subsong: 0, updatedAt: at(1)),
    ];
    expect(lacksTrackRow(account, {'s0#0', 's1#0'}), isFalse);
    expect(lacksTrackRow(account, {'s0#0'}), isTrue);
  });
}
