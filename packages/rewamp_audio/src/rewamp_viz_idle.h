/* rewamp_viz_idle — « faut-il dessiner cette frame ? », UNE règle pour tous
 * les visualiseurs et pour les DEUX chemins de rendu.
 *
 * Un visualiseur tourne à la cadence de l'écran (60 à 120 img/s) tant qu'il est
 * affiché, que la musique joue ou non. Lecteur en pause, l'image ne change
 * pourtant plus: l'anneau audio n'avance pas, le curseur de motifs non plus,
 * les touches sont relevées. On brûle donc du GPU, du CPU et de la batterie
 * pour redessiner la même image — et sur téléphone c'est le cas le plus
 * courant, parce qu'on met en pause et on repose l'appareil sans fermer le
 * lecteur.
 *
 * La règle: on dessine quand ça JOUE, et pendant une fenêtre de grâce après
 * tout le reste. La fenêtre est nécessaire — couper au premier tick de pause
 * FIGERAIT une animation en cours: les touches du piano se relèvent, les
 * étincelles s'éteignent, l'oscilloscope retombe à plat, la plage automatique
 * finit son glissement, un fondu de preset projectM se termine. Trois secondes
 * couvrent tout cela avec de la marge.
 *
 * Elle est REPOUSSÉE par [rewamp_viz_wake], que l'on appelle sur tout ce qui
 * change ce qui est affiché sans que la musique avance: un réglage, un geste
 * (zoom, déplacement), un changement de piste, une pochette qui atterrit, une
 * reconstruction du widget. Côté Dart, `build()` réveille — une reconstruction
 * signifie précisément que quelque chose a changé.
 *
 * ⚠️ La lecture ne suffit pas comme unique critère: `rewamp_is_playing()` peut
 * être faux pendant les fenêtres où l'état Dart est en avance sur le moteur
 * (voir `engineStoppedByItself`). La grâce absorbe ces trous — au pire on
 * dessine trois secondes de trop, jamais l'inverse.
 */
#ifndef REWAMP_VIZ_IDLE_H
#define REWAMP_VIZ_IDLE_H

#include "rewamp_audio.h"   /* REWAMP_EXPORT */

#ifdef __cplusplus
extern "C" {
#endif

/* Repousse la fenêtre de grâce: « quelque chose a changé, dessine ». */
REWAMP_EXPORT void rewamp_viz_wake(void);

/* 1 = le visualiseur est ÉVEILLÉ (ça joue, ou la grâce court encore).
 *
 * ⚠️ Question IDEMPOTENTE: plusieurs widgets la posent DEUX fois dans la même
 * frame — une fois pour décider de dessiner, une fois pour savoir s'il faut
 * relire les noms d'instruments ou compter les voies. Elle ne consomme donc
 * rien; c'est `rewamp_viz_frame_due` qui compte les images. */
REWAMP_EXPORT int rewamp_viz_should_render(void);

/* Plafond de cadence, en images par seconde (0 = celle de l'écran).
 *
 * Un visualiseur suit le rafraîchissement de l'écran: 120 Hz sur un téléphone
 * récent, donc deux fois le GPU, le CPU et la batterie d'un rendu à 60 pour
 * une différence que l'œil ne réclame pas sur une forme d'onde. Poussé depuis
 * Réglages → Visualisation. */
REWAMP_EXPORT void rewamp_viz_set_max_fps(int fps);
REWAMP_EXPORT int  rewamp_viz_max_fps(void);

/* 1 = dessiner MAINTENANT: éveillé ET l'image est due sous le plafond.
 *
 * ⚠️ CONSOMME l'image quand elle rend 1 — un appelant qui demande doit
 * dessiner. Une seule question par frame et par chemin de rendu (le ticker
 * Dart d'Apple/Linux, la boucle SurfaceView d'Android); tout le reste utilise
 * `rewamp_viz_should_render`. */
REWAMP_EXPORT int rewamp_viz_frame_due(void);

/* « Le visualiseur a-t-il DORMI depuis ma dernière question ? » — vrai si au
 * moins une image a été refusée (lecteur en pause, grâce écoulée). CONSOMMÉ à
 * la lecture. Pour qui mesure une PÉRIODE de rendu: l'intervalle qui enjambe un
 * sommeil n'est pas une frame lente, c'est un TROU voulu. Sans ça le garde-fou
 * « appareil trop lent » de projectM prenait une pause pour un preset à
 * 1 image/s et l'ÉCARTAIT — toute pause de 4 à 8 s (sous 5 s de trou, son
 * propre seuil « absurde » ne jouait pas). */
int rewamp_viz_take_idle_gap(void);

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_VIZ_IDLE_H */
