/* Headless WonderSwan music core, on top of the beetle-wswan-libretro
 * emulation (Mednafen lineage) — the vendored sources under wswan/ and sound/
 * are byte-identical to upstream; everything this player needs that the
 * libretro frontend used to provide lives here.
 *
 * Replaces the OSwan-based core: same V30MZ idea, markedly better-maintained
 * emulation, and crucially the Sound DMA / Hyper Voice path (ports 0x4A–0x52)
 * that other cores render poorly on WonderSwan Color.
 *
 * What must NOT be trimmed, and is not:
 *   - gfx.c is the CLOCK. Sound drivers run off the HBlank/VBlank/line-compare
 *     interrupts its line state machine raises, so the whole of wsExecuteLine
 *     is kept; only the scanline renderer is skipped (skip=true), which costs
 *     nothing and edits nothing.
 *   - start.inc, the port init table applied at reset with its 0xBA/0xBB/0xC4/
 *     0xC5 exceptions. Without it nothing boots.
 *   - Blip_Buffer's stereo pair: the WonderSwan pans per channel.
 */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "mednafen-types.h"
#include "wswan/wswan.h"
#include "wswan/gfx.h"
#include "wswan/interrupt.h"
#include "wswan/sound.h"
#include "wswan/v30mz.h"
#include "wswan/wswan-memory.h"
#include "wswan/eeprom.h"
#include "wswan/rtc.h"
#include "mempatcher.h"
#include "settings.h"
#include "video.h"

#include "rewamp_wswan.h"

/* Owned by the vendored core. */
extern uint8 *wsCartROM;

/* Owned by the FRONTEND upstream (libretro.c defines them), referenced by the
 * core — so they live here now. `startio` is the reset port table: start.inc is
 * a data-only include, pulled in exactly as upstream does. */
uint32 rom_size;
/* 1 = WonderSwan Color. Always on, see the load path. */
int wsc = 1;
#include "wswan/start.inc"   /* defines `const uint8 startio[256]` */

/* Owned by the frontend upstream, referenced by the core: the button register
 * the memory ports read. A player has no input — it must still exist. */
uint16 WSButtonStatus;

/* Frame audio buffer, owned here and grown by the core itself: SoundFlush's
 * second argument is the buffer CAPACITY (in/out), not an output count —
 * passing a null buffer skipped the drain entirely and the Blip_Buffer
 * overflowed within a second (ASan caught it on the first real file). */
static int16_t *s_sound_buf;
static int32    s_sound_buf_size;

/* Samples decoded but not yet handed out (a frame rarely lines up with the
 * requested block size). */
static int      s_pending;
static int      s_pending_read;

static int      s_loaded;
static int      s_sample_rate = 44100;
static uint32   s_sram_size;
static uint8    s_song;          /* WSR track currently selected */
static uint8    s_first_song;    /* the footer's default */

static uint32 next_pow2(uint32 v)
{
   uint32 r = 1;
   while (r < v) r <<= 1;
   return r;
}

int rewamp_wswan_first_song(void) { return s_first_song; }

int rewamp_wswan_load(const uint8_t *data, size_t size, int sample_rate)
{
   uint32 real_rom_size, pow_size;
   uint8 header[10];

   if (!data || size < 65536) return 0;

   /* WSR detection: a 32-byte footer at the very END of the file. Its byte
    * 0x05 is the track to start on. There is no text metadata at all. */
   s_first_song = 0;
   if (size >= 0x20 && !memcmp(data + size - 0x20, "WSRF", 4))
      s_first_song = data[size - 0x20 + 0x05];
   s_song = s_first_song;

   /* The rip is placed at the END of a power-of-two buffer whose head is filled
    * with 0xFF — the layout the WS boot vectors expect. This is upstream's
    * "real_rom_size vs rom_size funny business", kept verbatim because it is
    * precisely what makes WSR files work. */
   real_rom_size = (uint32)((size + 0xFFFF) & ~0xFFFFu);
   pow_size      = next_pow2(real_rom_size);
   rom_size      = pow_size + (pow_size == 0);

   free(wsCartROM);
   wsCartROM = (uint8 *)calloc(1, rom_size);
   if (!wsCartROM) return 0;
   if (real_rom_size < rom_size)
      memset(wsCartROM, 0xFF, rom_size - real_rom_size);
   memcpy(wsCartROM + (rom_size - real_rom_size), data, size);

   memcpy(header, wsCartROM + rom_size - 10, 10);
   s_sram_size = 0;
   switch (header[5])
   {
      case 0x01: s_sram_size =   8 * 1024; break;
      case 0x02: s_sram_size =  32 * 1024; break;
      case 0x03: s_sram_size = 128 * 1024; break;
      case 0x04: s_sram_size = 256 * 1024; break;
      case 0x05: s_sram_size = 512 * 1024; break;
      default: break; /* the 0x10/0x20/0x50 cases are EEPROM sizes, not SRAM */
   }

   /* Colour model: a .wsr may target WSC (Hyper Voice / Sound DMA), and a mono
    * WS rip runs fine on a colour unit. Always emulate WSC — anything else
    * silently drops the very channels this core exists to get right. */
   wsc = 1;

   MDFNMP_Init(16384, (1 << 20) / 1024);
   v30mz_init(WSwan_readmem20, WSwan_writemem20, WSwan_readport, WSwan_writeport);
   WSwan_MemoryInit(0 /* language */, wsc, s_sram_size, true /* skip save/load */);
   WSwan_GfxInit();
   WSwan_SoundInit();

   s_sample_rate = sample_rate > 0 ? sample_rate : 44100;
   WSwan_SetSoundRate((uint32)s_sample_rate);

   /* Seed the buffer; SoundFlush grows it as needed. */
   if (!s_sound_buf)
   {
      s_sound_buf_size = 4096;
      s_sound_buf = (int16_t *)calloc((size_t)s_sound_buf_size, sizeof(int16_t));
      if (!s_sound_buf) return 0;
   }
   s_pending = s_pending_read = 0;

   s_loaded = 1;
   rewamp_wswan_reset(s_song);
   return 1;
}

void rewamp_wswan_reset(int song)
{
   int u0;
   if (!s_loaded) return;

   s_song = (uint8)(song < 0 ? 0 : song);
   s_pending = s_pending_read = 0;

   v30mz_reset();
   WSwan_MemoryReset();
   WSwan_GfxReset();
   WSwan_SoundReset();
   WSwan_InterruptReset();
   WSwan_RTCReset();
   WSwan_EEPROMReset();

   /* Port init table — the exceptions matter, see start.inc. */
   for (u0 = 0; u0 < 0xc9; u0++)
      if (u0 != 0xC4 && u0 != 0xC5 && u0 != 0xBA && u0 != 0xBB)
         WSwan_writeport(u0, startio[u0]);

   WSwan_writeport(0xC4, 0xF0);
   WSwan_writeport(0xC5, 0xF0);
   WSwan_writeport(0xBA, 0x99);
   WSwan_writeport(0xBB, 0x88);

   /* Track selection: the driver reads it out of AW at entry. This one line is
    * the whole of "WSR support" beyond the footer and the padding. */
   v30mz_set_reg(NEC_AW, s_song);
}

int rewamp_wswan_render(int16_t *out, int frames)
{
   static MDFN_Surface dummy_surface;
   int produced = 0;
   int guard = 0;

   if (!s_loaded || !out || frames <= 0) return 0;

   /* Leftovers from the previous call first: a WS frame yields ~735 samples at
    * 44.1 kHz, never exactly what the caller asked for. */
   if (s_pending > 0)
   {
      int take = s_pending < frames ? s_pending : frames;
      memcpy(out, s_sound_buf + s_pending_read * 2,
             (size_t)take * 2 * sizeof(int16_t));
      produced       += take;
      s_pending      -= take;
      s_pending_read += take;
   }

   while (produced < frames && guard++ < 4096)
   {
      int32 count;

      /* skip=true: the scanline renderer is never entered, but the line state
       * machine, its interrupts and the Sound DMA checks all still run. A
       * dummy surface is passed rather than NULL — nothing dereferences it
       * while skipping, but a null pointer would be a trap waiting for a
       * future upstream change. */
      while (!wsExecuteLine(&dummy_surface, true))
         ;

      count = WSwan_SoundFlush(&s_sound_buf, &s_sound_buf_size);
      /* Upstream resets the CPU timestamp once the frame's audio is out; the
       * Blip_Buffer end-of-frame is relative to it. */
      v30mz_timestamp = 0;

      if (count <= 0) continue;

      {
         int take = count < (frames - produced) ? count : (frames - produced);
         memcpy(out + produced * 2, s_sound_buf,
                (size_t)take * 2 * sizeof(int16_t));
         produced       += take;
         s_pending       = count - take;   /* kept for the next call */
         s_pending_read  = take;
      }
   }

   if (produced < frames)
      memset(out + produced * 2, 0,
             (size_t)(frames - produced) * 2 * sizeof(int16_t));
   return frames;
}

void rewamp_wswan_close(void)
{
   if (!s_loaded) return;
   WSwan_MemoryKill();
   MDFNMP_Kill();
   free(wsCartROM);
   wsCartROM = NULL;
   free(s_sound_buf);
   s_sound_buf = NULL;
   s_sound_buf_size = 0;
   s_pending = s_pending_read = 0;
   s_loaded = 0;
}
