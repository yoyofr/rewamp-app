// La photo d'identités du compte (`user_library_ids`) doit aussi servir à
// repérer ce qui MANQUE sur l'appareil, pas seulement ce qui a été retiré
// ailleurs.
//
// Le curseur de bibliothèque est un cul-de-sac par construction: il n'avance
// que sur ce qu'on a vu, donc une entrée du compte plus ancienne que lui ne
// reviendra jamais dans un delta. Constaté entre un Mac et un iPhone du même
// compte: trois ♥ d'album posés côté serveur avant que le client ne sache lire
// la colonne (migration serveur 206) restaient invisibles sur l'un des deux,
// définitivement.
//
// Le test tient sur la COMPARAISON, pas sur SyncService (qui a besoin du
// réseau et de path_provider): c'est elle qui décide s'il faut repasser sans
// curseur.
import 'package:flutter_test/flutter_test.dart';

/// Une ligne de la photo d'identités, réduite à ce que la comparaison lit.
typedef ServerRow = ({String kind, String id, int subsong, bool favourite});

/// Une entrée locale, même réduction.
typedef LocalRow = ({String kind, String id, int subsong, bool favourite});

/// La règle telle que `SyncService._accountHasWhatWeLack` la pose.
bool accountHasWhatWeLack(List<ServerRow> server, List<LocalRow> local) {
  final songs = {
    for (final l in local)
      if (l.kind == 'song') '${l.id}#${l.subsong}': l.favourite,
  };
  final albums = {
    for (final l in local)
      if (l.kind == 'album') l.id: l.favourite,
  };
  for (final r in server) {
    if (r.kind != 'song' && r.kind != 'album') continue;
    final localFav =
        r.kind == 'song' ? songs['${r.id}#${r.subsong}'] : albums[r.id];
    if (localFav == null) return true;
    if (r.favourite && !localFav) return true;
  }
  return false;
}

void main() {
  test('rien à faire quand les deux côtés coïncident', () {
    expect(
      accountHasWhatWeLack(
        [(kind: 'album', id: 'a1', subsong: 0, favourite: true)],
        [(kind: 'album', id: 'a1', subsong: 0, favourite: true)],
      ),
      isFalse,
    );
  });

  test('un ♥ du compte que l\'appareil ignore déclenche la repasse', () {
    // Le cas vécu: l'album est bien en bibliothèque des deux côtés, mais le ♥
    // a été posé avant que ce client ne sache lire la colonne.
    expect(
      accountHasWhatWeLack(
        [(kind: 'album', id: 'a1', subsong: 0, favourite: true)],
        [(kind: 'album', id: 'a1', subsong: 0, favourite: false)],
      ),
      isTrue,
    );
  });

  test('une entrée du compte absente de l\'appareil déclenche la repasse', () {
    expect(
      accountHasWhatWeLack(
        [(kind: 'song', id: 's1', subsong: 0, favourite: false)],
        const [],
      ),
      isTrue,
    );
  });

  test('deux sous-chansons du même fichier sont deux entrées', () {
    // Comparer sur le seul uuid ferait passer la seconde pour déjà présente.
    expect(
      accountHasWhatWeLack(
        [(kind: 'song', id: 's1', subsong: 1, favourite: true)],
        [(kind: 'song', id: 's1', subsong: 0, favourite: true)],
      ),
      isTrue,
    );
  });

  test('un ♥ local que le compte n\'a pas ne déclenche RIEN ici', () {
    // Ce sens-là appartient à la propagation des suppressions
    // (_reconcileRemovals), pas à la détection de manque.
    expect(
      accountHasWhatWeLack(
        [(kind: 'song', id: 's1', subsong: 0, favourite: false)],
        [(kind: 'song', id: 's1', subsong: 0, favourite: true)],
      ),
      isFalse,
    );
  });
}
