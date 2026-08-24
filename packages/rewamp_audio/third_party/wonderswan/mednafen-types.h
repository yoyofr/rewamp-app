/* Mednafen integer aliases, as beetle-wswan's sources expect them.
 *
 * Part of the thin compatibility layer that lets the WonderSwan core be
 * vendored VERBATIM from beetle-wswan-libretro: everything the sources include
 * from outside their own directory is provided here instead of being edited
 * out of them, so a future upstream re-sync stays a plain file copy.
 */
#ifndef REWAMP_WSWAN_MEDNAFEN_TYPES_H
#define REWAMP_WSWAN_MEDNAFEN_TYPES_H

#include <stdint.h>
#include <stdbool.h>

typedef int8_t   int8;
typedef int16_t  int16;
typedef int32_t  int32;
typedef int64_t  int64;
typedef uint8_t  uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef uint64_t uint64;

#ifndef INLINE
#define INLINE inline
#endif

#endif
