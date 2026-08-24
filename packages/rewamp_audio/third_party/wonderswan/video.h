/* Video surface, declared but never used.
 *
 * gfx.c keeps its `wsExecuteLine(MDFN_Surface*, bool skip)` signature: the
 * headless player always passes skip=true, so the scanline renderer is never
 * entered and the surface is never dereferenced. Nothing is edited out of
 * gfx.c — and above all its LINE STATE MACHINE stays intact, which is what
 * raises the HBlank/VBlank/line-compare interrupts the sound drivers run on.
 */
#ifndef REWAMP_WSWAN_VIDEO_H
#define REWAMP_WSWAN_VIDEO_H

#include <stdint.h>

/* Colour-conversion macros, verbatim from beetle-wswan's video.h: gfx.c builds
 * its palette with them at reset, before any rendering decision. Kept so the
 * file compiles untouched — the palette itself is never read headless. */
#define RED_SHIFT_24 16
#define GREEN_SHIFT_24 8
#define BLUE_SHIFT_24 0
#define ALPHA_SHIFT_24 24
#define MAKECOLOR_24(r, g, b, a) ((r << RED_SHIFT_24) | (g << GREEN_SHIFT_24) | (b << BLUE_SHIFT_24) | (a << ALPHA_SHIFT_24))

/* 16bit color - RGB565 */
#define RED_EXPAND_16 3
#define GREEN_EXPAND_16 2
#define BLUE_EXPAND_16 3
#define RED_SHIFT_16 11
#define GREEN_SHIFT_16 5
#define BLUE_SHIFT_16 0
#define MAKECOLOR_16(r, g, b, a) (((r >> RED_EXPAND_16) << RED_SHIFT_16) | ((g >> GREEN_EXPAND_16) << GREEN_SHIFT_16) | ((b >> BLUE_EXPAND_16) << BLUE_SHIFT_16))

/* 16bit color - RGB555 */
#define RED_EXPAND_15 3
#define GREEN_EXPAND_15 3
#define BLUE_EXPAND_15 3
#define RED_SHIFT_15 10
#define GREEN_SHIFT_15 5
#define BLUE_SHIFT_15 0
#define MAKECOLOR_15(r, g, b, a) (((r >> RED_EXPAND_15) << RED_SHIFT_15) | ((g >> GREEN_EXPAND_15) << GREEN_SHIFT_15) | ((b >> BLUE_EXPAND_15) << BLUE_SHIFT_15))

/* 16bit color - BGR555 */
#define BLUE_EXPAND_15_1 3
#define GREEN_EXPAND_15_1 3
#define RED_EXPAND_15_1 3
#define BLUE_SHIFT_15_1 10
#define GREEN_SHIFT_15_1 5
#define RED_SHIFT_15_1 0
#define MAKECOLOR_15_1(r, g, b, a) (((r >> RED_EXPAND_15_1) << RED_SHIFT_15_1) | ((g >> GREEN_EXPAND_15_1) << GREEN_SHIFT_15_1) | ((b >> BLUE_EXPAND_15_1) << BLUE_SHIFT_15_1))

typedef struct
{
   uint32_t *pixels;
   int32_t   pitch;
   int32_t   depth;
} MDFN_Surface;

#endif
