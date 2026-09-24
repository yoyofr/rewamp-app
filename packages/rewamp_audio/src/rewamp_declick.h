/* rewamp_declick — déclic de DÉBUT DE PISTE pour les rips de CD audio.
 *
 * Le problème visé est étroit et se reconnaît à l'oreille comme à l'œil: sur
 * certains rips (jw_hes, jw_ssf…, `.ape`/`.ogg`/`.mp3`/`.flac`), les
 * premiers échantillons non nuls du fichier sont des OCTETS CORROMPUS — une
 * douzaine de valeurs isolées à ±0,5–0,65 pleine échelle, séparées par des
 * quasi-zéros, avant que le plancher de bruit puis la musique n'arrivent.
 * Mesuré sur « World Heroes Perfect » T-3103G_02.ape: 2,02 s de zéros exacts,
 * 12 trames de déchets en 89161–89172, 35 ms de plancher à −0,0006, musique.
 * Ce n'est PAS un clic « vinyle » (impulsion lissée dans de l'audio continu),
 * c'est du bruit de rip: l'`adeclick` de FFmpeg (modèle autorégressif,
 * fenêtres de 55 ms, graphe à drainer) tire à côté et coûte cher.
 *
 * Principe. Un échantillon est un DÉCHET s'il domine de loin son voisinage
 * proche des deux côtés: |x| > K × max(médiane|x| des 5 ms précédentes,
 * médiane|x| des 5 ms suivantes, plancher). La MÉDIANE — et non le RMS — parce
 * que les déchets viennent en grappe: quatre pointes à 0,6 dans une fenêtre de
 * 220 échantillons gonflent le RMS à 0,08 et la première pointe passerait; la
 * médiane, elle, reste au plancher. Une vraie attaque musicale (caisse claire,
 * accord plaqué) a une DÉCROISSANCE: les 5 ms qui suivent sa crête restent à
 * quelques dB sous elle, jamais à 24 dB. Les échantillons marqués sont
 * fusionnés en courses (trous ≤ 8 trames), une course ≤ 64 trames est
 * remplacée par une interpolation linéaire entre ses deux voisins sains; plus
 * longue, on n'y touche pas (ce n'est plus un clic).
 *
 * Portée. Armé à l'ouverture (et à un seek à 0), DÉSARMÉ dès qu'on a vu 200 ms
 * de vraie musique (blocs de 256 trames dont le RMS dépasse −50 dBFS — le
 * plancher de bruit n'en est pas) ou 60 s de piste. Ensuite le flux passe
 * tel quel, sans copie. Le coût en silence est nul (pré-porte sur |x|).
 *
 * Modèle « tire »: le déclic a besoin d'un peu d'AVANCE (contexte à droite,
 * ~512 trames) et d'HISTORIQUE (contexte à gauche): il lit donc la source un
 * peu en avant dans un étage interne et rend exactement ce qu'on lui demande,
 * la position vue par l'appelant ne bouge pas. En fin de fichier il rend ce
 * qu'il reste, contexte tronqué.
 *
 * Oracle: scripts/verify_declick.sh (le même code, hors app, sur un fichier
 * décodé par ffmpeg; mode balayage pour mesurer les faux positifs).
 */
#ifndef REWAMP_DECLICK_H
#define REWAMP_DECLICK_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct RewampDeclick RewampDeclick;

/* Source de trames interleaved float32. Rend le nombre de trames écrites;
 * moins que demandé = fin de flux. */
typedef uint64_t (*RewampDeclickSource)(void* user, float* out, uint64_t frames);

/* Une réparation, pour le diagnostic. */
typedef struct {
    uint64_t frame;   /* première trame réparée (absolue depuis l'armement) */
    int      channel;
    int      length;  /* trames */
    float    peak;    /* |x| max avant réparation */
} RewampDeclickRepair;

RewampDeclick* rewamp_declick_create(int channels, int sampleRate);
void           rewamp_declick_destroy(RewampDeclick* d);

/* Vide l'étage (la source a été repositionnée) et arme ou non le filtre. */
void rewamp_declick_reset(RewampDeclick* d, int armed);
int  rewamp_declick_armed(const RewampDeclick* d);

/* Lit `frames` trames à travers le filtre. Armé: passe par l'étage; désarmé
 * et étage vide: appelle la source directement. */
uint64_t rewamp_declick_read(RewampDeclick* d, float* out, uint64_t frames,
                             RewampDeclickSource src, void* user);

/* Diagnostic: réparations faites depuis le dernier reset. `log` reçoit au
 * plus `max` entrées (les premières); rend le compte total. */
int rewamp_declick_repairs(const RewampDeclick* d, RewampDeclickRepair* log, int max);

/* Extension (sans point, casse libre) d'un format qui sert aux rips de
 * pistes CD audio — le seul domaine où ce déclic a un sens. */
int rewamp_declick_ext_is_cd_rip(const char* ext);

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_DECLICK_H */
