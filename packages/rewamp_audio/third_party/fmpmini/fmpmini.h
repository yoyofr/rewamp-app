//
//  fmpmini.h
//  libfmpmini
//
//  Created by Yohann Magnien David on 08/05/2024.
//

#ifndef fmpmini_h
#define fmpmini_h

#include <stdio.h>
#include <stdlib.h>
/* YOYOFR (rewamp): cet en-tête DÉCLARE avec `int16_t` et `int64_t`
 * (fmpmini_render, fmpmini_getLength) sans jamais les définir — il les
 * recevait par accident, d'un en-tête inclus avant lui chez les appelants.
 * Sous MSVC l'accident ne se produit pas, et l'erreur ne nomme pas le type
 * manquant: elle sort en « absence de ')' avant '*' » sur la déclaration,
 * puis en cascade sur toutes les suivantes. Un en-tête public déclare ses
 * propres types. */
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int fmpmini_loadFile(const char *path);
void fmpmini_reset(void);
int fmpmini_render(int16_t *buffer,int samples);
const char *fmpmini_getName(void);
void fmpmini_mute(int mask);
void fmpmini_close(void);
void fmpmini_init(void);
int64_t fmpmini_getLength(void);
void fmpmini_setMaxLoop(int loop);
const char *fmpmini_getComment(int line);
int fmpmini_channelsNb(void);


#ifdef __cplusplus
}
#endif

#endif /* fmpmini_h */
