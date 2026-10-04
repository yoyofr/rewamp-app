// Chemins RELATIFS portables: toujours en '/', sur toutes les plateformes.
//
// La règle de l'app, posée le 2026-10-04 au portage Windows:
//  * un chemin ABSOLU est NATIF (il ne quitte jamais l'appareil);
//  * un chemin RELATIF s'écrit en '/' — c'est lui qui VOYAGE et qui sert
//    d'IDENTITÉ: `tracks.local_rel_path`, `playlist_tracks.rel_path`, le
//    `rel_path` envoyé au compte, et la matière du hash `ext_key`
//    (SyncService.localLibraryKey). Sous Windows `p.relative` rend
//    `local\Jeux\a.mid`; sans cette règle, le même fichier importé sur un
//    iPhone et sur un PC faisait DEUX entrées de compte, et l'iPhone qui
//    recevait le relatif du PC cherchait un nom contenant des '\'.
//
// ⚠️ La conversion ne s'applique QUE sous le style Windows: sous POSIX, '\'
// est un caractère de nom de fichier légal, et le réécrire changerait le nom.
// Le [p.Context] se passe en paramètre pour que les tests exercent les DEUX
// styles sur n'importe quelle machine (p.windows / p.posix).
import 'package:path/path.dart' as p;

/// [rel] (relatif, au format de [ctx]) → forme portable en '/'.
String toPortableRel(String rel, {p.Context? ctx}) {
  final c = ctx ?? p.context;
  return c.style == p.Style.windows ? rel.replaceAll(r'\', '/') : rel;
}

/// `p.relative(path, from: root)`, rendu sous forme portable.
String portableRelative(String path, {required String from, p.Context? ctx}) {
  final c = ctx ?? p.context;
  return toPortableRel(c.relative(path, from: from), ctx: c);
}

/// [rel] portable → relatif NATIF de [ctx] (pour le joindre à une racine).
String fromPortableRel(String rel, {p.Context? ctx}) {
  final c = ctx ?? p.context;
  if (c.style != p.Style.windows) return rel;
  return c.joinAll(rel.split('/').where((s) => s.isNotEmpty));
}

/// `p.join(root, rel)` pour un relatif PORTABLE: le résultat est natif de bout
/// en bout (jamais `C:\…\racine/local/Jeux/a.mid`).
String joinPortable(String root, String rel, {p.Context? ctx}) {
  final c = ctx ?? p.context;
  return rel.isEmpty ? root : c.join(root, fromPortableRel(rel, ctx: c));
}
