/* libogg: en-tête GÉNÉRÉ par le build amont (autoconf/cmake), que `ogg.h`
 * inclut. Il ne fait que nommer les entiers de taille fixe.
 *
 * Nos sources libogg/libvorbis viennent de l'arbre vendoré par le SUBMODULE
 * libopenmpt (third_party/libopenmpt/include/{ogg,vorbis}), et on ne modifie
 * JAMAIS un submodule — d'où cet en-tête chez nous, avec ce répertoire placé
 * sur le chemin d'inclusion à côté de `ogg/include`.
 *
 * La version générée dépend de la plateforme chez l'amont; ici les quatre
 * cibles (macOS, iOS, Linux, Android) ont toutes <stdint.h>, donc une seule
 * forme suffit et il n'y a rien à configurer. */
#ifndef __CONFIG_TYPES_H__
#define __CONFIG_TYPES_H__

#include <stdint.h>

typedef int16_t  ogg_int16_t;
typedef uint16_t ogg_uint16_t;
typedef int32_t  ogg_int32_t;
typedef uint32_t ogg_uint32_t;
typedef int64_t  ogg_int64_t;
typedef uint64_t ogg_uint64_t;

#endif
