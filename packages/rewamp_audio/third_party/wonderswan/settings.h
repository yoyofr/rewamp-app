/* Mednafen settings, resolved to fixed values.
 *
 * The only consumer in the retained core is the EEPROM "owner data" written at
 * reset (name, birth date, sex, blood type). A music rip never reads it back,
 * but the write must still happen — a driver that boots off a half-initialised
 * EEPROM is exactly the kind of silent difference this port exists to avoid.
 */
#ifndef REWAMP_WSWAN_SETTINGS_H
#define REWAMP_WSWAN_SETTINGS_H

#include <string.h>

static inline unsigned MDFN_GetSettingUI(const char *name)
{
   if (!strcmp(name, "wswan.byear"))  return 1989;
   if (!strcmp(name, "wswan.bmonth")) return 6;
   if (!strcmp(name, "wswan.bday"))   return 23;
   return 0;
}

static inline int MDFN_GetSettingI(const char *name)
{
   if (!strcmp(name, "wswan.sex"))   return 3; /* Mednafen's own default */
   if (!strcmp(name, "wswan.blood")) return 5;
   return 0;
}

static inline const char *MDFN_GetSettingS(const char *name)
{
   (void)name;
   return "REWAMP";
}

static inline bool MDFN_GetSettingB(const char *name)
{
   (void)name;
   return false;
}

#endif
