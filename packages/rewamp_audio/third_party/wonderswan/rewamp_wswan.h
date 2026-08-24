/* Headless WonderSwan music core — the surface the plugin wrapper uses.
 * See rewamp_wswan.c for what the port keeps and why. */
#ifndef REWAMP_WSWAN_H
#define REWAMP_WSWAN_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Loads a .wsr image (footer-detected) and boots it. Returns 0 on failure. */
int  rewamp_wswan_load(const uint8_t *data, size_t size, int sample_rate);

/* Re-boots on a given track (0-based, as carried in AW). */
void rewamp_wswan_reset(int song);

/* The track the WSR footer asks for — the default when no subsong is given. */
int  rewamp_wswan_first_song(void);

/* Renders interleaved stereo int16. Always fills [frames]. */
int  rewamp_wswan_render(int16_t *out, int frames);

void rewamp_wswan_close(void);

#ifdef __cplusplus
}
#endif

#endif
