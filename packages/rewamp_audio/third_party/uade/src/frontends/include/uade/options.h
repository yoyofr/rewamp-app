#ifndef _UADE_OPTIONS_H_
#define _UADE_OPTIONS_H_
#define UADE_CONFIG_USER_MODE (0)
/* Ces deux chemins sont des DÉFAUTS d'autotools, gravés par le configure qui a
 * généré ce header. Ils pointaient sur le répertoire d'installation temporaire
 * de la machine qui l'a lancé — un chemin qui n'existe nulle part ailleurs, et
 * qui n'avait rien à faire dans un dépôt.
 *
 * Vides, et c'est volontaire:
 *  - BASE_DIR est TOUJOURS écrasé par rewamp_plugin_uade.cpp, qui pose
 *    `<datadir>/uade` (les données d'UADE voyagent en assets et sont recopiées
 *    au démarrage). Un défaut plausible comme /usr/local/share/uade serait
 *    PIRE que vide: il ferait silencieusement lire les données d'une AUTRE
 *    installation d'UADE présente sur la machine. Vide échoue franchement
 *    (`opendir("")`), ce qui est le comportement qu'on veut si l'override
 *    venait à sauter;
 *  - UADE_CORE ne sert qu'au chemin qui EXEC un binaire uadecore séparé, que
 *    -DUADE_IN_PROCESS supprime: le cœur tourne dans un thread ici. */
#define UADE_CONFIG_BASE_DIR ""
#define UADE_CONFIG_UADE_CORE ""
#define UADE_CONFIG_HAVE_URANDOM
#define UADE_VERSION "3.05"

#endif /* _UADE_OPTIONS_H_ */
