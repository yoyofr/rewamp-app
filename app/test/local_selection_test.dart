import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/local_library_screen.dart';

/// Sélection multiple du navigateur local: ce que « Lire » et « Supprimer »
/// visent. Des pistes cochées et des dossiers cochés, dépliés dans l'ordre de
/// l'arbre, sans rien compter deux fois.
void main() {
  // (chemin relatif, piste) — ici la « piste » est son chemin absolu.
  final tree = <(String, String)>[
    ('Album A/01.mid', '/l/Album A/01.mid'),
    ('Album A/02.mid', '/l/Album A/02.mid'),
    ('Album A/CD2/03.mid', '/l/Album A/CD2/03.mid'),
    ('Album B/01.vgz', '/l/Album B/01.vgz'),
    ('solo.sid', '/l/solo.sid'),
    ('solo.sid', '/l/solo.sid'), // deux sous-chansons, un seul fichier
  ];
  String id(String s) => s;

  test('un dossier coché emporte tout son sous-arbre, dans l\'ordre', () {
    expect(expandLocalSelection(tree, {'dir:Album A/'}, id),
        ['/l/Album A/01.mid', '/l/Album A/02.mid', '/l/Album A/CD2/03.mid']);
  });

  test('pistes et dossiers mêlés, sans doublon', () {
    expect(
        expandLocalSelection(
            tree, {'dir:Album A/', 'track:/l/Album A/02.mid', 'track:/l/solo.sid'}, id),
        ['/l/Album A/01.mid', '/l/Album A/02.mid', '/l/Album A/CD2/03.mid', '/l/solo.sid']);
  });

  test('un préfixe de dossier ne capture pas un voisin au nom plus long', () {
    final t2 = <(String, String)>[
      ('Album/1.mid', '/l/Album/1.mid'),
      ('Album 2/1.mid', '/l/Album 2/1.mid'),
    ];
    expect(expandLocalSelection(t2, {'dir:Album/'}, id), ['/l/Album/1.mid']);
  });

  test('rien de coché: rien', () {
    expect(expandLocalSelection(tree, const {}, id), isEmpty);
  });
}
