/* Savestate contract, stubbed.
 *
 * A .wsr player never saves state, but every core file declares its SFORMAT
 * table and a StateAction function. Providing the types and a no-op entry point
 * keeps those functions COMPILING UNCHANGED, so the vendored sources stay
 * byte-identical to beetle-wswan-libretro (see mednafen-types.h).
 */
#ifndef REWAMP_WSWAN_STATE_H
#define REWAMP_WSWAN_STATE_H

#include <stdint.h>
#include <stdbool.h>

#define MDFNSTATE_RLSB    0x80000000
#define MDFNSTATE_RLSB32  0x40000000
#define MDFNSTATE_RLSB16  0x20000000
#define MDFNSTATE_RLSB64  0x10000000
#define MDFNSTATE_BOOL    0x08000000

/* Opaque savestate cursor — the core's StateAction signatures name it. */
typedef struct
{
   uint8_t *data;
   uint32_t loc;
   uint32_t len;
   uint32_t malloced;
   uint32_t initial_malloc;
} StateMem;

typedef struct
{
   void *v;
   uint32_t size;
   uint32_t flags;
   const char *name;
} SFORMAT;

/* Always "succeeds" and touches nothing. */
static inline int MDFNSS_StateAction(void *st, int load, int data_only,
                                     SFORMAT *sf, const char *name,
                                     bool optional)
{
   (void)st; (void)load; (void)data_only; (void)sf; (void)name; (void)optional;
   return 1;
}

#endif
