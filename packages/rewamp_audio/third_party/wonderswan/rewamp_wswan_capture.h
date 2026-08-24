/* Per-voice oscilloscope + notes capture and per-voice mute for the vendored
 * beetle-wswan core.
 *
 * beetle-wswan has NO Modizer/YOYOFR hooks (the OSwan core it replaces had
 * them baked into audio.cpp). Everything they need lives here so that the only
 * edits inside wswan/sound.c are a handful of one-line call sites — see
 * patches/wonderswan/ for the exact diff against upstream.
 *
 * ── Slot layout (6 voices), kept IDENTICAL to the OSwan core ──────────────
 *   0-3 : the four PSG tone channels
 *   4   : channel-2 direct D/A "voice" + Hyper Voice (WSC), summed
 *   5   : channel-4 noise
 * Channel 2 in D/A mode and channel 4 in noise mode therefore move OUT of
 * their tone slot: exactly what the OSwan layout did, so an A/B against it
 * compares like with like and the existing voice names still fit.
 *
 * ── How the waveform is sampled ───────────────────────────────────────────
 * sound.c is event-driven (Blip_Buffer deltas at CPU timestamps), not
 * per-sample. The scope wants one 8-bit sample per OUTPUT frame. Since the
 * cycles-per-output-sample ratio is a constant (clock 3072000 / sample rate),
 * an event's output-sample index is known the moment it happens: on each
 * event we fill the ring forward with the value that was in effect since the
 * previous event, then latch the new one. The channel output really is
 * piecewise constant, so this is exact, not an approximation.
 *
 * Every slot is filled to the same absolute sample count at each frame flush,
 * so all six write pointers advance in lockstep with the audio — which is what
 * the delayed (look-ahead) store in rewamp_channel_data.c assumes.
 *
 * The write pointer is NOT wrapped: rewamp_channel_data.c's non-circular mode
 * wants a monotonic m_voice_current_ptr (its delayed capture derives the
 * just-written window from it, and a wrapping pointer makes that window go
 * negative once per lap).
 */
#ifndef REWAMP_WSWAN_CAPTURE_H
#define REWAMP_WSWAN_CAPTURE_H

#include <stdint.h>
#include "../../src/ModizerVoicesData.h"

#define WS_CAP_VOICES 6
/* Must match the rewamp_channel_data_set_ring_write_size() the plugin sets. */
#define WS_CAP_RING   (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)

#define WS_CAP_CLOCK  3072000

static int      ws_cap_rate = 44100;
static int64_t  ws_cap_base;                  /* absolute sample index at frame start */
static int64_t  ws_cap_wr[WS_CAP_VOICES];     /* absolute samples written, per slot */
static int32_t  ws_cap_cur[WS_CAP_VOICES];    /* value in effect since ws_cap_wr */
static int32_t  ws_cap_voice_val;             /* slot 4 has two contributors */
static int32_t  ws_cap_hv_val;
static int      ws_cap_pend_slot = -1;        /* set by MK_SAMPLE_CACHE*, committed by SYNCSAMPLE */
static int32_t  ws_cap_pend_val;

static void ws_cap_set_rate(int rate)
{
   if (rate > 0) ws_cap_rate = rate;
}

static void ws_cap_reset(void)
{
   int i;
   ws_cap_base = 0;
   for (i = 0; i < WS_CAP_VOICES; i++)
   {
      ws_cap_wr[i]  = 0;
      ws_cap_cur[i] = 0;
      vgm_last_vol[i]   = 0;
      vgm_last_note[i]  = 0;
      vgm_last_instr[i] = (unsigned char)i;
   }
   ws_cap_voice_val = ws_cap_hv_val = 0;
   ws_cap_pend_slot = -1;
}

/* Fill slot's ring forward with its current value up to absolute sample
 * `target`. Only ever moves forward. */
static void ws_cap_fill(int slot, int64_t target)
{
   signed char *buf;
   int64_t ptr;
   int64_t n = target - ws_cap_wr[slot];

   if (n <= 0) return;
   ws_cap_wr[slot] = target;

   buf = m_voice_buff[slot];
   if (!buf) return;                       /* channel data not allocated yet */
   if (n > WS_CAP_RING) n = WS_CAP_RING;   /* a longer run is invisible anyway */

   {
      signed char v = (signed char)LIMIT8(ws_cap_cur[slot]);
      ptr = m_voice_current_ptr[slot];
      while (n-- > 0)
      {
         buf[(ptr >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT) % WS_CAP_RING] = v;
         ptr += (int64_t)1 << MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
      }
      m_voice_current_ptr[slot] = ptr;
   }
}

/* Latch a new value for `slot` at CPU timestamp `ts` (relative to frame start). */
static void ws_cap_emit(int slot, uint32_t ts, int32_t value)
{
   int64_t idx = ws_cap_base + ((int64_t)ts * ws_cap_rate) / WS_CAP_CLOCK;
   ws_cap_fill(slot, idx);
   ws_cap_cur[slot] = value;
}

static int ws_cap_muted(int slot)
{
   return (int)((generic_mute_mask >> slot) & 1);
}

/* ── call sites in sound.c ─────────────────────────────────────────────── */

/* Tone channel: `sample` is the raw 4-bit wave sample, `vol` the packed
 * left/right nibbles. Centring on 8 turns the unipolar wave into the bipolar
 * shape the scope expects. Mute zeroes the cache BEFORE Blip_Synth_offset, so
 * it is the real mix that goes silent, not just the display. */
static void ws_cap_tone(int ch, int sample, int vol, int32_t *cache)
{
   int maxv = ((vol >> 4) & 0x0F) > (vol & 0x0F) ? ((vol >> 4) & 0x0F) : (vol & 0x0F);
   ws_cap_pend_slot = ch;
   ws_cap_pend_val  = (sample - 8) * maxv;
   if (ws_cap_muted(ch))
   {
      cache[0] = cache[1] = 0;
      ws_cap_pend_val = 0;
   }
}

/* Noise lives in slot 5 whatever channel produced it (always ch 3 in practice). */
static void ws_cap_noise(int sample, int vol, int32_t *cache)
{
   int maxv = ((vol >> 4) & 0x0F) > (vol & 0x0F) ? ((vol >> 4) & 0x0F) : (vol & 0x0F);
   ws_cap_pend_slot = 5;
   ws_cap_pend_val  = (sample - 8) * maxv;
   if (ws_cap_muted(5))
   {
      cache[0] = cache[1] = 0;
      ws_cap_pend_val = 0;
   }
}

/* Direct D/A: `raw` is the unsigned 8-bit sample written to the volume port. */
static void ws_cap_voice(int raw, int32_t *cache)
{
   if (ws_cap_muted(4))
   {
      cache[0] = cache[1] = 0;
      ws_cap_voice_val = 0;
   }
   else
      ws_cap_voice_val = raw - 128;
   ws_cap_pend_slot = 4;
   ws_cap_pend_val  = ws_cap_voice_val + ws_cap_hv_val;
}

/* Commit whatever the last MK_SAMPLE_CACHE* prepared, at time `ts`. */
static void ws_cap_commit(uint32_t ts)
{
   if (ws_cap_pend_slot < 0) return;
   ws_cap_emit(ws_cap_pend_slot, ts, ws_cap_pend_val);
   ws_cap_pend_slot = -1;
}

/* Hyper Voice shares slot 4 with the D/A voice; it mixes straight into the
 * Blip synth so it gets its own commit. `sample` is the 11-bit signed value. */
static void ws_cap_hyper(uint32_t ts, int sample, int32_t *left, int32_t *right)
{
   if (ws_cap_muted(4))
   {
      *left = *right = 0;
      ws_cap_hv_val = 0;
   }
   else
      ws_cap_hv_val = sample >> 3;   /* ±1024 → ±128 */
   ws_cap_emit(4, ts, ws_cap_voice_val + ws_cap_hv_val);
}

/* Called from WSwan_SoundFlush once the frame's sample count is known: every
 * slot is squared up to the same absolute position. */
static void ws_cap_frame(int frames)
{
   int i;
   int64_t end;
   if (frames < 0) frames = 0;
   end = ws_cap_base + frames;
   for (i = 0; i < WS_CAP_VOICES; i++)
      ws_cap_fill(i, end);
   /* A slot can sit up to one sample past `end` (Blip carries a fractional
    * sample across frames while our index restarts at 0); the next frame just
    * writes one fewer. Bounded, self-correcting. */
   ws_cap_base = end;
   ws_cap_pend_slot = -1;
}

/* Notes visualizer state, refreshed once per frame from the register file.
 * Also silences the value latched for any slot whose source is off, so the
 * next frame draws a flat line instead of holding the last sample. */
static void ws_cap_notes(const uint16_t *period, const uint8_t *volume,
                         uint8_t control, uint8_t noise_control,
                         uint8_t voice_volume, uint8_t hvctrl, uint8_t hvchan)
{
   int ch;
   /* Control port 0x90: bits 0-3 enable channels 1-4, bit 5 puts channel 2 in
    * direct D/A, bit 6 sweeps channel 3, bit 7 puts channel 4 in noise mode.
    * The mode bits are NOT enough on their own — WSwan_SoundUpdate only takes
    * the noise path when 0x80 is set as well as the channel's enable bit, and
    * testing only the enable bit sent the notes to slot 5 while the waveform
    * kept going to slot 3. */
   int voice_on = (control & 0x02) && (control & 0x20);
   int noise_on = (control & 0x08) && (control & 0x80) && (noise_control & 0x10);
   int hyper_on = (hvctrl & 0x80) && (hvchan & 0x60);

   for (ch = 0; ch < 4; ch++)
   {
      int      slot = ch;
      unsigned pt   = 2048u - (unsigned)(period[ch] & 0x7FF);
      int      maxv = ((volume[ch] >> 4) & 0x0F) > (volume[ch] & 0x0F)
                      ? ((volume[ch] >> 4) & 0x0F) : (volume[ch] & 0x0F);
      int      on   = (control & (1 << ch)) != 0;

      if (ch == 1 && voice_on) on = 0;   /* moved to slot 4 */
      if (ch == 3 && noise_on) on = 0;   /* moved to slot 5 */

      if (!on || !maxv || ws_cap_muted(slot))
      {
         vgm_last_vol[slot]  = 0;
         vgm_last_note[slot] = 0;
         if (!on) ws_cap_cur[slot] = 0;
         continue;
      }
      /* 32 wave steps per cycle, one step every (2048 - period) CPU cycles. */
      vgm_last_note[slot]  = (unsigned)((double)WS_CAP_CLOCK / (double)(pt * 32u));
      vgm_last_vol[slot]   = (unsigned)(maxv * 17);
      vgm_last_instr[slot] = (unsigned char)slot;
   }

   /* Slot 5 — noise. No discrete pitch, but the LFSR step rate is what the ear
    * hears as its "colour", so report it on the same scale as the tones. */
   if (noise_on && !ws_cap_muted(5))
   {
      unsigned pt   = 2048u - (unsigned)(period[3] & 0x7FF);
      int      maxv = ((volume[3] >> 4) & 0x0F) > (volume[3] & 0x0F)
                      ? ((volume[3] >> 4) & 0x0F) : (volume[3] & 0x0F);
      vgm_last_note[5]  = (unsigned)((double)WS_CAP_CLOCK / (double)(pt * 32u));
      vgm_last_vol[5]   = (unsigned)(maxv * 17);
      vgm_last_instr[5] = 5;
   }
   else
   {
      vgm_last_vol[5]  = 0;
      vgm_last_note[5] = 0;
      if (!noise_on) ws_cap_cur[5] = 0;
   }

   /* Slot 4 — sampled voice: no pitch at all (the driver streams arbitrary
    * PCM), so report a fixed mid tone like the OSwan core did rather than a
    * meaningless number. */
   if ((voice_on && (voice_volume & 0x0F)) || hyper_on)
   {
      if (ws_cap_muted(4))
      {
         vgm_last_vol[4]  = 0;
         vgm_last_note[4] = 0;
      }
      else
      {
         vgm_last_note[4]  = 220;
         vgm_last_vol[4]   = 255;
         vgm_last_instr[4] = 4;
      }
   }
   else
   {
      vgm_last_vol[4]  = 0;
      vgm_last_note[4] = 0;
      ws_cap_cur[4]    = 0;
      ws_cap_voice_val = ws_cap_hv_val = 0;
   }
}

#endif /* REWAMP_WSWAN_CAPTURE_H */
