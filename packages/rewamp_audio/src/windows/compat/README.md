# src/windows/compat — en-têtes POSIX manquants sous MSVC

Ces fichiers ne sont PAS une couche de portabilité générale: ce sont les
quelques en-têtes POSIX que des arbres vendorés incluent **sans garde**, et
qu'un `#ifdef _WIN32` dans chacun d'eux aurait fallu écrire 38 fois.

Ils sont posés sur le chemin d'include des SEULES cibles qui en ont besoin
(`rewamp_win_compat_dir()` dans `cmake/rewamp.cmake`), jamais globalement.
C'est volontaire: mis sur le chemin de tout le monde, ils masqueraient le jour
où une source NOUVELLE inclurait `<unistd.h>` par accident, et ils
intercepteraient aussi les inclusions de code qui a, lui, un vrai chemin
Windows.

⚠️ Chaque en-tête ne déclare QUE ce que nos arbres utilisent réellement. Un
symbole absent est un symbole que personne n'a demandé — on l'ajoute quand le
compilateur le réclame, pas d'avance: une couche POSIX « complète » sous MSVC
est un mensonge qui se paie plus tard (un `fork()` déclaré mais absent lie, et
plante à l'exécution).
