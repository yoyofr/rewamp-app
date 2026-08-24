/* Cheat-engine registration, stubbed: the core declares its RAM regions to
 * Mednafen's patcher, which a player has no use for. */
#ifndef REWAMP_WSWAN_MEMPATCHER_H
#define REWAMP_WSWAN_MEMPATCHER_H

#include <stdint.h>

static inline bool MDFNMP_Init(uint32_t ps, uint32_t numpages)
{ (void)ps; (void)numpages; return true; }
static inline void MDFNMP_AddRAM(uint32_t size, uint32_t address, uint8_t *RAM)
{ (void)size; (void)address; (void)RAM; }
static inline void MDFNMP_Kill(void) {}

#endif
