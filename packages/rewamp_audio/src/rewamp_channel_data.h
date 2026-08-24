#ifndef REWAMP_CHANNEL_DATA_H
#define REWAMP_CHANNEL_DATA_H

#include <stdint.h>
#include <stddef.h>
#include "rewamp_audio.h"   /* REWAMP_EXPORT */
#include "ModizerConstants.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Maximum active channels the ring buffer system supports. */
#define REWAMP_MAX_CHANNELS SOUND_MAXVOICES_BUFFER_FX

/*
 * Allocate / free the per-channel ring buffers.
 * Call rewamp_channel_data_init() once at startup and
 * rewamp_channel_data_cleanup() at shutdown.
 */
void rewamp_channel_data_init(void);
void rewamp_channel_data_cleanup(void);

/*
 * Reset channel data before loading a new file.
 * channelCount: number of channels the new file will use (≤ REWAMP_MAX_CHANNELS).
 */
void rewamp_channel_data_reset(int channelCount);

/* Zero all ring-buffer contents and note/volume state without freeing
 * allocations or changing the channel count.  Call on stop so the
 * oscilloscope goes blank immediately; the buffers refill automatically
 * when playback resumes. */
void rewamp_channel_data_clear(void);

/* Set the effective ring-buffer write size for the current backend.
 * Must be called after rewamp_channel_data_reset().
 * libvgm / libopenmpt write with mask &(SOUND_BUFFER_SIZE_SAMPLE*4*2-1) → 4096.
 * libgme writes with mask &(SOUND_BUFFER_SIZE_SAMPLE*4*4-1) → 8192 (default). */
void rewamp_channel_data_set_ring_write_size(int size);

/* Set circular mode: when non-zero, ring_read treats ptr as wrapping mod
 * write_size and always returns write_size samples (no ramp-up on wrap).
 * Use for backends like libnsfplay whose patches wrap m_voice_current_ptr. */
void rewamp_channel_data_set_ring_circular(int circular);

/* ── Delayed store (look-ahead sync) ───────────────────────────────────────
 * When the data source decodes ahead of playback, these keep the voice
 * oscilloscope synced to the HEARD audio (see rewamp_channel_data.c). */
void rewamp_channel_data_set_delayed(int active);
void rewamp_channel_data_set_consumer_pos(int64_t framePos);
void rewamp_channel_data_capture_delayed(int64_t startFramePos, int frames);

/* ── Voice / chipset grouping metadata (called from a plugin's open()) ───
 * Describe the loaded file's voices so the UI can group + mute them:
 *   rewamp_voices_meta_reset();
 *   rewamp_voices_add_chip("Paula", 0, 4);   // one group per sound source
 *   rewamp_voice_set_name(0, "Voice 1");      // optional per-voice label
 * add_chip auto-fills m_voice_ChipID for its voice range and returns the
 * chip index (or -1 if the chip table is full). */
void rewamp_voices_meta_reset(void);
int  rewamp_voices_add_chip(const char* name, int startVoice, int count);
void rewamp_voice_set_name(int v, const char* name);

/* Voice muting uses the `generic_mute_mask` global (bit v set ⇒ voice v muted),
 * declared in ModizerVoicesData.h. Adopting plugins read it during decode; the
 * Dart-facing get/set FFI wrappers live in rewamp_audio.c. */

/* ── Track info message (Modizer mod_message equivalent) ────────────────────
 * Free-text metadata about the loaded file/subsong, shown by the player's
 * info panel. Cleared by the engine before each plugin open(); plugins append
 * whatever their library exposes (tags, copyright, instruments, dumper, …).
 * rewamp_track_message() is the Dart-facing getter (UTF-8, never NULL). */
#define REWAMP_TRACK_MSG_MAX 16384
void        rewamp_track_message_clear(void);
void        rewamp_track_message_append(const char* fmt, ...);
REWAMP_EXPORT const char* rewamp_track_message(void);

/* Shift-JIS (CP932) → UTF-8, best effort — several Japanese chip formats
 * (PxTone, MDX, …) store their tags in it, and publishing them raw shows
 * mojibake in the info panel. Pure-ASCII input passes through unchanged; on
 * Apple iconv converts the rest; elsewhere (Android has no iconv) each
 * non-ASCII glyph degrades to '?'. `out` is always NUL-terminated. */
void        rewamp_sjis_to_utf8(const char* in, char* out, size_t outCap);

/* ISO-8859-1 → UTF-8, for tags a format defines as 8-bit Latin (PSID header
 * strings, and every other pre-Unicode container that stores names as raw
 * bytes). A string that is ALREADY valid UTF-8 passes through untouched, so
 * this is safe to apply to a field whose encoding is not certain — the two
 * cannot be confused, a Latin-1 accent is never a valid UTF-8 sequence.
 * No iconv (the mapping is a pure two-byte expansion), so it behaves the same
 * on Android. `out` is always NUL-terminated. */
void        rewamp_latin1_to_utf8(const char* in, char* out, size_t outCap);

/* rewamp_tags.c: append ID3 / Vorbis-comment / RIFF-INFO tags of a plain
 * audio file (mp3/flac/ogg/wav) to the track message. Used by the miniaudio
 * fallback, whose decoder does not expose metadata. */
void        rewamp_tags_append_info(const char* path);

/* Embedded cover picture found by rewamp_tags_append_info (ID3v2 APIC /
 * FLAC PICTURE / ogg METADATA_BLOCK_PICTURE). Buffer owned by the engine,
 * valid until the next load. NULL/0 when the file has none. */
REWAMP_EXPORT const uint8_t* rewamp_track_artwork(int* size);
REWAMP_EXPORT const char*    rewamp_track_artwork_mime(void);
void           rewamp_track_artwork_clear(void);

/* Structured tag fields parsed by rewamp_tags_append_info ('' when absent). */
REWAMP_EXPORT const char* rewamp_tag_title(void);
REWAMP_EXPORT const char* rewamp_tag_artist(void);
REWAMP_EXPORT const char* rewamp_tag_album(void);

/* ── Query API (called from Dart FFI) ──────────────────────────────────── */

/* Number of active channels for the currently loaded file. NB: falls back to
 * 2 virtual voices (L/R waveform) when the backend registered none. */
int rewamp_channel_count(void);

/* Same WITHOUT the fallback: 0 ⇒ stereo-only backend (no per-voice data). */
int rewamp_channel_count_raw(void);

/*
 * Copy the oscilloscope ring-buffer for channel `ch` into `out`.
 * `out` must point to at least SOUND_BUFFER_SIZE_SAMPLE*4*2 bytes.
 * Returns the number of bytes copied, or 0 on error.
 */
int rewamp_channel_buf(int ch, int8_t* out, int outLen);

/* Same as rewamp_channel_buf but applies a correlation-based trigger to
 * stabilise the waveform display.  Stores a per-channel template and aligns
 * each frame to minimise L1 distance against the previous frame's center.
 * Falls back to raw copy when insufficient data or on the first call. */
REWAMP_EXPORT int rewamp_channel_buf_triggered(int ch, int8_t* out, int outLen);

/* Monotonically increasing write pointer for channel `ch` (sample units).
 * If the value is unchanged between two calls, the channel wrote no new data
 * (silent / inactive). Returns 0 if ch is out of range. */
REWAMP_EXPORT int64_t rewamp_channel_write_ptr(int ch);

/* Last frequency detected for channel `ch` (Hz), or 0 if not available. */
float rewamp_channel_freq_hz(int ch);

/* Last volume for channel `ch` (0–255), or 0 if not available. */
int rewamp_channel_volume(int ch);

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_CHANNEL_DATA_H */
