#ifndef REWAMP_AUDIO_H
#define REWAMP_AUDIO_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
  #define REWAMP_EXPORT __declspec(dllexport)
#else
  #define REWAMP_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

typedef enum {
    REWAMP_OK = 0,
    REWAMP_ERROR_INIT_FAILED = -1,
    REWAMP_ERROR_LOAD_FAILED = -2,
    REWAMP_ERROR_NOT_INITIALIZED = -3,
    REWAMP_ERROR_NO_SOUND = -4,
} RewampResult;

REWAMP_EXPORT RewampResult rewamp_init(void);
REWAMP_EXPORT void         rewamp_uninit(void);

// Set the root directory for plugin auxiliary assets (e.g. C64 ROMs).
// Should be called before loading files that need them. `path` is copied.
REWAMP_EXPORT void         rewamp_set_data_dir(const char* path);

/* Generic per-engine parameter channel (Settings → Moteurs). Dart pushes
 * values keyed by (engine, key); plugins read them in open() via
 * rewamp_get_engine_param. Applied on the NEXT open (track change). */
REWAMP_EXPORT void         rewamp_set_engine_param(const char* engine,
                                                   const char* key,
                                                   double value);
double                     rewamp_get_engine_param(const char* engine,
                                                   const char* key,
                                                   double defval);

REWAMP_EXPORT RewampResult rewamp_load_file(const char* path);
REWAMP_EXPORT void         rewamp_unload(void);

/* Visualiseurs: « faut-il dessiner cette frame ? » — voir rewamp_viz_idle.h.
 * Déclaré ICI aussi pour que tout appelant C le voie sans inclure ce header. */
REWAMP_EXPORT void         rewamp_viz_wake(void);
REWAMP_EXPORT int          rewamp_viz_should_render(void);

REWAMP_EXPORT RewampResult rewamp_play(void);
REWAMP_EXPORT RewampResult rewamp_pause(void);
/* Stops the audio DEVICE while paused (iOS Now Playing shows "playing" as long
 * as the audio unit runs). Call shortly after rewamp_pause() (post-fade);
 * no-op if the sound is playing again. rewamp_play() restarts the device. */
REWAMP_EXPORT RewampResult rewamp_device_suspend(void);
REWAMP_EXPORT RewampResult rewamp_stop(void);

REWAMP_EXPORT int          rewamp_is_playing(void);
REWAMP_EXPORT double       rewamp_get_position_seconds(void);
REWAMP_EXPORT double       rewamp_get_duration_seconds(void);
REWAMP_EXPORT RewampResult rewamp_seek_seconds(double seconds);

// Linear output gain (0.0 = silent, 1.0 = unity). Used for the forced-loop
// fadeout (Settings → Lecture): generic, engine-level — works for every
// backend uniformly, no per-plugin native fade needed.
REWAMP_EXPORT void rewamp_set_volume(float volume);

// Forced-loop setting (Settings → Lecture), snapshotted by the NEXT
// rewamp_load_file() call: the loop itself is applied to the plugin's own
// native loop support (RewampPluginVTable.configure_loop) if it has any,
// else left to Dart's generic seek+volume fallback (see
// rewamp_has_native_loop_support below).
//   mode            0=off, 1=on (loop `count` times total), 2=infinite
//   fadeoutEnabled/fadeoutSeconds: when mode==1 and the plugin's single-pass
//     length is known (RewampPluginVTable.length), rewamp_load_file()
//     computes the exact frame at which the FINAL pass enters the fadeout
//     window and ds_read() (rewamp_datasource.c) ramps the gain down
//     sample-accurately as it produces those frames — generic, works for
//     ANY plugin with native loop support, no per-plugin fade code needed.
//     No native fadeout is scheduled when mode!=1 or length is unknown —
//     the loop itself still works, only the fadeout is skipped in that case.
// baseDurationSeconds: the known single-pass length of the track about to
// load (from server/DB catalogue metadata), or 0 if unknown. Native-loop
// plugins that can't derive their own base length (plain NSF has no embedded
// duration) use it to seed their loop math instead of a bogus default.
REWAMP_EXPORT void rewamp_set_forced_loop(int mode, int count,
                                          int fadeoutEnabled, double fadeoutSeconds,
                                          double baseDurationSeconds);

// 1 if the CURRENTLY loaded file's plugin claimed native loop support (its
// configure_loop was non-NULL) at the last rewamp_load_file() call, else 0
// — tells Dart whether it needs to run its own generic loop/fadeout logic
// for this file, or whether the plugin's native library already handles it.
REWAMP_EXPORT int rewamp_has_native_loop_support(void);

/* ── Gapless playback ────────────────────────────────────────────────────────
 * Stage the NEXT queue entry: when the current decoder reaches its end, the
 * producer thread closes it, opens this path in place and keeps filling the
 * same ring — the output never stops. The extra parameters are the per-track
 * snapshot rewamp_set_forced_loop would have carried for a plain load of that
 * file (they are applied just before its open()). Staging survives until it
 * is consumed by a handoff, replaced by a newer call, cleared, or superseded
 * by a manual rewamp_load_file(). Path must exist on disk; a handoff that
 * cannot happen (open failure, sample-rate/channel mismatch with the current
 * ring) silently falls back to the plain end-of-track path. */
REWAMP_EXPORT void rewamp_set_next_file(const char* path, int loopMode,
                                        int loopCount, int fadeoutEnabled,
                                        double fadeoutSeconds,
                                        double baseDurationSeconds);
REWAMP_EXPORT void rewamp_clear_next_file(void);
/* Crossfade duration in seconds (0 = plain gapless, the default). When > 0
 * the producer overlaps the end of each track with the head of the staged
 * next one (equal-power curves), and the engines' own default end-fadeouts
 * are suppressed at open() — fading an already-faded tail double-attenuates
 * and the overlap would carry silence instead of music. Needs a known track
 * length; a track whose end cannot be predicted plays plain gapless. */
REWAMP_EXPORT void rewamp_set_crossfade_seconds(double seconds);
/* End of the CURRENT track, seconds (0 = unknown) — for engines that never
 * stop by themselves (SID, NSF…): their duration lives in Dart-side catalogues
 * (HVSC songlengths, UADE songdb), async corrections included. The producer
 * only CUTS there when a next track is staged (gapless/crossfade); otherwise
 * Dart's own end-of-duration logic keeps ruling, unchanged. Reset by every
 * load and handoff — re-post after each track change and duration update. */
REWAMP_EXPORT void rewamp_set_track_end_seconds(double seconds);
/* Monotonic count of AUDIBLE track boundaries crossed (gapless handoffs).
 * Dart polls it each tick; a change means the ear just moved to the staged
 * track — flip title/metadata and advance the queue WITHOUT reloading. Never
 * reset; re-sync the last-seen value after every explicit load. */
REWAMP_EXPORT int64_t rewamp_handoff_serial(void);
/* Vrai entre le RELAIS gapless et sa PROMOTION: le décodeur décrit déjà la
 * piste suivante alors que l'oreille est encore dans la précédente. Les
 * visualiseurs qui lisent du contenu STATIQUE du décodeur (motifs) doivent
 * geler leur morceau affiché tant que c'est vrai. */
REWAMP_EXPORT int rewamp_handoff_pending(void);

/* Name of the decoder backend used for the currently loaded file
 * (e.g. "libopenmpt", "miniaudio"), or "" if nothing is loaded. */
REWAMP_EXPORT const char* rewamp_get_backend_name(void);

/* Seek progress — updated by the audio thread; safe to poll from Dart at 60 Hz.
 * rewamp_is_seeking()            → 1 while a fast-forward seek is running
 * rewamp_seek_progress_seconds() → seconds decoded so far in the current seek */
REWAMP_EXPORT int    rewamp_is_seeking(void);
REWAMP_EXPORT double rewamp_seek_progress_seconds(void);

/* Does ANY registered plugin claim this file? 1 = yes, 0 = no.
 *
 * Asks the registry (extension + header scoring, no decode), so it covers every
 * engine — which rewamp_probe_subsong_count() does NOT: that one is a SUBSONG
 * counter chained over SID/KSS/openmpt/SNDH/sc68/GME and answers 0 for anything
 * else, Furnace, UADE, zxtune, AdPlug, the PSF family, SunVox and libvgm-only
 * formats included. Using it as a "can we play this" oracle rejected a perfectly
 * good `.fur` and accepted the `.vgm` next to it (libgme does play VGM), which
 * is exactly the wrong way round when picking the richest file in an archive. */
REWAMP_EXPORT int rewamp_can_play(const char* path);

/* The files the CURRENT decode actually opened, as
 * `[{"name":…,"size":…}, …]` — the main file plus whatever companions the
 * plugin pulled in (a .psflib, a smpl.NAME, a .pdx, an .fmb bank). Empty
 * array before the first load. Reported BY the loaders: the companion of a
 * multi-file format cannot be derived from the name (a .psflib is named
 * after the game, not the tune). See rewamp_loaded_files.h. */
REWAMP_EXPORT const char* rewamp_loaded_files_json(void);

/* Returns the number of subsongs in a multi-track file (e.g. RSN/NSF/GBS)
 * without loading it for playback.  Returns 1 for single-track formats,
 * 0 if the file cannot be probed or the format is unrecognised.
 * Also fills an internal cache so that rewamp_probe_get_title() /
 * rewamp_probe_get_duration_ms() can be called immediately after. */
REWAMP_EXPORT int rewamp_probe_subsong_count(const char* path);

/* Per-subsong metadata accessors — valid until the next rewamp_probe_subsong_count() call.
 * idx is 0-based.
 * rewamp_probe_get_title()       : track title, or "" if unavailable.
 * rewamp_probe_get_duration_ms() : duration in milliseconds, or -1 if unknown. */
REWAMP_EXPORT const char* rewamp_probe_get_title(int idx);

/* Décode un texte lu dans un FICHIER (tag PSF, ligne de M3U…) vers UTF-8, par
 * la MÊME règle que les tags du moteur (rewamp_text_to_utf8): UTF-8 valide
 * rendu tel quel, sinon CP932/Shift-JIS — iconv sur Apple, par dlsym ailleurs,
 * un '?' par glyphe à défaut. Exposée pour que le Dart n'ait PAS sa propre
 * règle: il en avait trois, toutes fausses sur du japonais (U+FFFD, Latin-1,
 * fromCharCodes), d'où des rectangles là où le panneau ⓘ montrait des kanji.
 * [in] est terminé par NUL et doit tenir sur UNE ligne: CP932 s'arrête au
 * premier octet indécodable, donc un bloc entier perdrait tout ce qui suit.
 * Rend la longueur écrite dans [out] (sans le NUL). */
REWAMP_EXPORT int rewamp_decode_text(const char* in, char* out, int out_cap);
REWAMP_EXPORT int         rewamp_probe_get_duration_ms(int idx);

/* Absolute base of the last probe's subsong indices: 0 for formats whose subsong
 * number is already absolute (NSF/GBS/SID), trk_min for KSS. Add this to a 0-based
 * position to get the absolute subsong index that ?subsong= expects. */
REWAMP_EXPORT int rewamp_probe_subsong_base(void);

/* Absolute subsong index of the idx-th row of the LAST probe. Dense formats
 * answer s_probe_base + idx — the old rule, unchanged. It exists for the sparse
 * ones: a Westwood `.adl` holds sentinel entries BETWEEN its playable tracks
 * (DUNE19.ADL: 74 table slots, 46 that produce sound, the 6th playable one
 * sitting at index 10), so the position in the list cannot stand in for the
 * index `?subsong=` expects. */
REWAMP_EXPORT int rewamp_probe_subsong_index(int idx);

/* Extract all files from an archive (7z, zip, tar, lha, gz, bz2, xz, rar) into
 * dest_dir (must already exist).  Files are flattened — only basenames are used,
 * directory structure inside the archive is discarded.
 * Returns 0 on success, non-zero on failure (or if libarchive is not compiled in). */
REWAMP_EXPORT int         rewamp_extract_archive(const char* archive_path, const char* dest_dir);
REWAMP_EXPORT const char* rewamp_extract_last_error(void);

/* Oscilloscope ring-buffer query.
 * Copies the most recent `count` stereo frames into leftOut / rightOut.
 * Values are in the range [-1.0, 1.0].  Safe to call from the Dart/UI thread. */
#define REWAMP_WAVEFORM_COUNT 256
REWAMP_EXPORT void rewamp_get_waveform(float* leftOut, float* rightOut, int count);

/* Seconds of continuous silence at the output (0 while audio is present).
 * Used by the Dart layer to auto-skip a track that has gone silent. */
REWAMP_EXPORT double rewamp_silent_seconds(void);
REWAMP_EXPORT void   rewamp_reset_silence(void);
/* Le décodeur a encore des événements à jouer: la sortie peut être muette
 * sans que le morceau soit fini (voir rewamp_audio.c). */
void rewamp_decoder_activity(void);

/* Oscilloscope line thickness multiplier (0.5–3; 1.0 = default). */
REWAMP_EXPORT void  rewamp_set_viz_line_width(float w);
REWAMP_EXPORT float rewamp_get_viz_line_width(void);

/* CRT effect levels packed into one int:
 *   bits 0-1 = RÉSERVÉS — c'était le halo (« glow »), retiré le 2026-09-15
 *              (demande utilisateur); l'encodage ne bouge pas pour que les
 *              deux côtés gardent la même lecture du masque
 *   bits 2-3 = speed level (0=off, 1=low, 2=high) */
#define REWAMP_CRT_SPEED_LEVEL(f) (((f) >> 2) & 3)
REWAMP_EXPORT void rewamp_set_crt_flags(int mask);
REWAMP_EXPORT int  rewamp_get_crt_flags(void);

/* Decode-ahead toggle (notation visualizer look-ahead). */
REWAMP_EXPORT void rewamp_set_lookahead(int on);
REWAMP_EXPORT int  rewamp_get_lookahead(void);
/* Variable look-ahead target in seconds (0 = off). A visualizer sizes this to
 * how far ahead it draws; the datasource clamps it to the ring capacity. */
REWAMP_EXPORT void   rewamp_set_lookahead_seconds(double seconds);
REWAMP_EXPORT double rewamp_get_lookahead_seconds(void);

/* Underrun telemetry: how many times the audio callback found the decode-ahead
 * ring short (producer starved for longer than the whole look-ahead), and how
 * many frames of silence that cost. Monotonic since process start.
 *
 * These exist to answer "is this crackle an underrun?" with a measurement
 * rather than a guess — if they stay flat while the audio crackles, the cause
 * is NOT the decoder falling behind, and the search belongs elsewhere. */
REWAMP_EXPORT int64_t rewamp_underrun_count(void);
REWAMP_EXPORT int64_t rewamp_underrun_frames(void);

/* The other two ways audio can glitch, separated because they need OPPOSITE
 * fixes and only a measurement can tell them apart:
 *
 *   slow_read — the callback took >1ms. It only memcpys, so it WAITED: lock
 *               contention / priority inversion inside our code.
 *   late_read — the callback was scheduled far later than the device period.
 *               The OS was late, not us: the lever is the device buffer, and
 *               nothing in the decode path will help. */
REWAMP_EXPORT int64_t rewamp_slow_read_count(void);
REWAMP_EXPORT int64_t rewamp_late_read_count(void);
/* Worst gap ever seen between two audio callbacks (µs). The count says it
 * happens; this says how bad — 100 ms of CPU starvation and 800 ms are not the
 * same illness, and they don't have the same fix. */
REWAMP_EXPORT int64_t rewamp_max_gap_us(void);

/* The DEVICE callback's own cadence — the one that actually matters.
 *
 * The counters above time ds_read, i.e. how often the DATA SOURCE is read, and
 * that is not the same thing: it stops entirely while paused, which made a
 * 720 ms pause read as a 720 ms scheduling stall and cost three rounds of
 * debugging. The device callback runs continuously as long as output is running,
 * so a gap HERE is unambiguously the OS failing to schedule the realtime thread. */
REWAMP_EXPORT int64_t rewamp_device_late_count(void);
REWAMP_EXPORT int64_t rewamp_device_max_gap_us(void);
/* Worst time spent INSIDE the device callback (µs). Large → the callback was
 * busy/blocked in the engine graph and device gaps are of our own making;
 * microseconds while gaps hit 400 ms → the callback truly was not invoked. */
REWAMP_EXPORT int64_t rewamp_device_max_busy_us(void);

/* La période qu'on DEMANDE au périphérique (REWAMP_PERIOD_MS), en ms.
 * Le message de démarrage annonçait « asked for 40ms » en dur alors que la
 * valeur est 20 — or c'est ce nombre-là qui sert à juger la marge disponible
 * quand on lit device-late. Un diagnostic faux est pire que pas de diagnostic. */
REWAMP_EXPORT int rewamp_device_requested_period_ms(void);

/* What the device ACTUALLY negotiated. periodSizeInMilliseconds is only a
 * request: on iOS it becomes AVAudioSession's *preferred* IO buffer duration,
 * which the system may clamp and which any other component reconfiguring the
 * session can override — and audio_service owns the session here. Read these
 * back rather than assuming the requested buffer is the real one. */
REWAMP_EXPORT int rewamp_device_period_frames(void);
REWAMP_EXPORT int rewamp_device_periods(void);
REWAMP_EXPORT int rewamp_device_sample_rate(void);

/* Output device picker (desktop — the macOS player's route button; mobile
 * OSes route system-wide instead). The JSON lists playback devices
 * [{"i","name","def","sel"}]; the set() index refers to the LAST json call
 * (-1 = back to the system default). */
REWAMP_EXPORT const char*  rewamp_output_devices_json(void);
REWAMP_EXPORT RewampResult rewamp_set_output_device(int index);

/* Oscilloscope colors (RGB 0..1). Voice scope + stereo "mono" use one color;
 * stereo "bi-color" uses separate left/right colors. */
REWAMP_EXPORT void rewamp_set_scope_color(float r, float g, float b);
REWAMP_EXPORT void rewamp_set_stereo_mono_color(float r, float g, float b);
REWAMP_EXPORT void rewamp_set_stereo_left_color(float r, float g, float b);
REWAMP_EXPORT void rewamp_set_stereo_right_color(float r, float g, float b);
REWAMP_EXPORT void rewamp_set_stereo_bicolor(int on);
/* Spectrum palette (viz mode 5): 0 = the scope colors above, 1 = colored by
 * FREQUENCY, brightness by amplitude — the Modizer look. */
REWAMP_EXPORT void rewamp_set_spectrum_palette(int mode);
const float* rewamp_scope_color(void);
const float* rewamp_stereo_mono_color(void);
const float* rewamp_stereo_left_color(void);
const float* rewamp_stereo_right_color(void);
int          rewamp_stereo_bicolor(void);
int          rewamp_spectrum_palette(void);

/* ── Per-channel data (oscilloscope / piano-roll) ───────────────────────
 * Populated when REWAMP_WITH_VGM is active and the decoder has per-channel
 * support (VGM/S98/GYM/DRO).  All functions are safe to call from any thread.
 *
 * Ring buffer layout: SOUND_BUFFER_SIZE_SAMPLE*4*2 bytes of int8 samples,
 * written by the chip emulator at native chip sample rate (fixed-point
 * interpolated to align with playback).  Call rewamp_channel_buf() each
 * render frame (e.g. 60 Hz) to get the most recent oscilloscope snapshot.
 */
REWAMP_EXPORT int   rewamp_channel_count(void);
REWAMP_EXPORT int   rewamp_channel_buf(int ch, int8_t* out, int outLen);
REWAMP_EXPORT int   rewamp_channel_buf_triggered(int ch, int8_t* out, int outLen);
REWAMP_EXPORT float rewamp_channel_freq_hz(int ch);
REWAMP_EXPORT int   rewamp_channel_volume(int ch);

/* ── Voice / chipset grouping + muting (generic framework) ──────────────
 * Voices are the per-channel scope entries above; a plugin may group them by
 * chip and name them (see rewamp_voices_add_chip in rewamp_channel_data.h).
 * When a plugin sets no metadata, one synthetic chip "—" spans all voices,
 * named "Voice N".  Names are written into `out` (NUL-terminated, truncated to
 * `len`); the return value is the string length written. */
REWAMP_EXPORT int     rewamp_voice_count(void);
/* REAL per-voice channel count: 0 ⇒ the backend exposes none at all (vgmstream
 * and miniaudio's mp3/ogg/flac/wav decode an already-mixed stream). Unlike
 * rewamp_voice_count(), which substitutes 2 virtual voices so the scope always
 * has something to draw, this NEVER lies — use it to decide whether per-voice
 * UI (voice scope, notation, synthesized pattern grid) makes any sense. */
REWAMP_EXPORT int     rewamp_voice_count_raw(void);
REWAMP_EXPORT int     rewamp_voice_name(int v, char* out, int len);
REWAMP_EXPORT int     rewamp_instrument_name(int idx, char* out, int len);
REWAMP_EXPORT int     rewamp_voice_instrument(int v);
REWAMP_EXPORT int     rewamp_voice_instruments(int32_t* out, int max);
/* Instruments DATÉS, lus dans la timeline des notes (voir rewamp_notes.c). */
REWAMP_EXPORT int     rewamp_notes_instruments_window(double fromSec, double toSec,
                                                      int32_t* out, int max);
REWAMP_EXPORT int     rewamp_notes_voice_instruments(int32_t* out, int max);
REWAMP_EXPORT unsigned rewamp_instrument_names_generation(void);
REWAMP_EXPORT int     rewamp_voice_chip(int v);
REWAMP_EXPORT int     rewamp_chip_count(void);
REWAMP_EXPORT int     rewamp_chip_name(int c, char* out, int len);
REWAMP_EXPORT int     rewamp_chip_voice_start(int c);
REWAMP_EXPORT int     rewamp_chip_voice_count(int c);
/* Mute mask: bit v set ⇒ voice v muted. Applied live by adopting plugins. */
REWAMP_EXPORT int64_t rewamp_get_voice_mute_mask(void);
REWAMP_EXPORT void    rewamp_set_voice_mute_mask(int64_t mask);

/* GPU oscilloscope — IOSurface double-buffer + FlutterTexture.
 * iOS: MetalANGLE (OpenGL ES 3.0).  macOS: native OpenGL 3.2 core.
 * On other platforms these symbols are not linked; Dart catches the lookup failure. */
/* Low-level GL context (IOSurface double-buffer). */
REWAMP_EXPORT int          rewamp_gl_init(int width, int height);
REWAMP_EXPORT int          rewamp_gl_resize(int width, int height);
REWAMP_EXPORT void         rewamp_viz_set_frame_time(double seconds);
REWAMP_EXPORT double       rewamp_viz_frame_time(void);
REWAMP_EXPORT void         rewamp_gl_make_current(void);
REWAMP_EXPORT void         rewamp_gl_flush(void);
REWAMP_EXPORT void         rewamp_gl_uninit(void);
REWAMP_EXPORT unsigned int rewamp_gl_get_fbo(void);
REWAMP_EXPORT unsigned int rewamp_gl_get_texture(void);
REWAMP_EXPORT int          rewamp_gl_width(void);
REWAMP_EXPORT int          rewamp_gl_height(void);
/* Returns a retained CVPixelBufferRef (front buffer) for Flutter's copyPixelBuffer. */
REWAMP_EXPORT void*        rewamp_gl_get_front_pixel_buffer(void);

/* Visualization renderer (oscilloscope). */
REWAMP_EXPORT int   rewamp_viz_init(int width, int height);
REWAMP_EXPORT void  rewamp_viz_render(void);
REWAMP_EXPORT void  rewamp_viz_uninit(void);

/* Per-channel (multi-voice) oscilloscope renderer — mutually exclusive with viz. */
REWAMP_EXPORT int   rewamp_scope_init(int width, int height);
REWAMP_EXPORT void  rewamp_scope_render(void);
REWAMP_EXPORT void  rewamp_scope_uninit(void);
REWAMP_EXPORT void  rewamp_scope_set_grid(int enabled);

/* Scrolling-notation visualizer (mode 2). */
REWAMP_EXPORT int   rewamp_noteviz_init(int width, int height);
REWAMP_EXPORT void  rewamp_noteviz_render(void);
REWAMP_EXPORT void  rewamp_noteviz_uninit(void);
/* Vertical range control: manual (drag/pinch) overrides the auto-calibration;
 * set_auto returns to it (easing from the manual view). lo/hi in log2(Hz). */
REWAMP_EXPORT void  rewamp_noteviz_set_range(float lo, float hi);
REWAMP_EXPORT void  rewamp_noteviz_set_auto(void);
REWAMP_EXPORT int   rewamp_noteviz_is_manual(void);
REWAMP_EXPORT float rewamp_noteviz_range_lo(void);
REWAMP_EXPORT float rewamp_noteviz_range_hi(void);
REWAMP_EXPORT void  rewamp_set_note_palette(int index);  /* 0..4 */
REWAMP_EXPORT void  rewamp_set_note_style(int style);    /* 0=flat, 1=box */
REWAMP_EXPORT void  rewamp_set_note_color_mode(int mode); /* 0=voix, 1=instrument */

/* Tracker-pattern visualizer (mode 4). Declared here so the C++ TU gets C
 * linkage (unmangled symbols for the Dart FFI lookup). */
REWAMP_EXPORT int   rewamp_patternviz_init(int width, int height);
REWAMP_EXPORT void  rewamp_patternviz_render(void);
REWAMP_EXPORT void  rewamp_patternviz_uninit(void);
REWAMP_EXPORT void  rewamp_patternviz_set_options(int palette, int scrollMode,
                                                  int showVolume, int smoothScroll);
REWAMP_EXPORT void  rewamp_patternviz_set_xscroll(float px);
/* Ligne active ÉPINGLÉE sur la barre: le motif défile toujours en continu,
 * mais la barre affiche la ligne ENTENDUE alignée au pixel (notes, instruments,
 * volumes, effets) au lieu des deux demi-lignes qui la traversent. Sans effet
 * en mode « barre mobile ». */
REWAMP_EXPORT void  rewamp_patternviz_set_pinned_row(int on);
REWAMP_EXPORT void  rewamp_patternviz_set_layout(float sizeScale, int columnMode);
REWAMP_EXPORT void  rewamp_patternviz_set_pixel_scale(float dpr);
/* 1 = opaque palette background (no artwork behind the grid), 0 = blended. */
REWAMP_EXPORT void  rewamp_patternviz_set_opaque_bg(int on);
/* Seconds of FUTURE rows currently on screen (synthesized grid look-ahead). */
REWAMP_EXPORT double rewamp_patternviz_future_seconds(void);

/* Stereo spectrum analyzer (FFT) visualizer (mode 5). Mirrored bars around a
 * horizontal midline (left up / right down); colors follow the stereo scope's
 * mono/bi-color settings. Declared here so the C++ TU gets C linkage — see the
 * mangled-export rule (four FFI lookups have silently failed on
 * exactly this). */
REWAMP_EXPORT int   rewamp_spectrum_init(int width, int height);
REWAMP_EXPORT void  rewamp_spectrum_render(void);
REWAMP_EXPORT void  rewamp_spectrum_uninit(void);

/* Piano visualizer (mode 6): one keyboard per voice (mode 0) or falling bars
 * onto one keyboard (mode 1). Fed by the look-ahead note timeline, like the
 * notation. Options: mode, colour by voice (0) / instrument (1), sparkles on
 * struck keys. Same C-linkage rule as the spectrum above. */
REWAMP_EXPORT int   rewamp_pianoviz_init(int width, int height);
REWAMP_EXPORT void  rewamp_pianoviz_render(void);
REWAMP_EXPORT void  rewamp_pianoviz_uninit(void);
REWAMP_EXPORT void  rewamp_set_piano_options(int mode, int colorMode, int glow, int light);
/* Horizontal view in WHITE-KEY units over the whole MIDI range (C-1 = white
 * key 0, 75 whites in all): [lo, lo+span]. set_view = manual (drag/pinch from
 * Dart, follows the finger); set_auto = back to the eased auto range. The
 * getters return the view in force (manual or the eased auto one). */
REWAMP_EXPORT void  rewamp_pianoviz_set_view(float lo, float span);
REWAMP_EXPORT void  rewamp_pianoviz_set_auto(void);
REWAMP_EXPORT int   rewamp_pianoviz_is_manual(void);
REWAMP_EXPORT float rewamp_pianoviz_view_lo(void);
REWAMP_EXPORT float rewamp_pianoviz_view_span(void);
REWAMP_EXPORT double rewamp_pianoviz_future_seconds(void);

/* projectM (Milkdrop) visualizer (mode 3) — renders a full opaque frame; no
 * artwork background. Presets/textures load from <datadir>/projectm/. */
REWAMP_EXPORT int   rewamp_projectm_init(int width, int height);
REWAMP_EXPORT void  rewamp_projectm_render(void);
REWAMP_EXPORT void  rewamp_projectm_uninit(void);
REWAMP_EXPORT void  rewamp_projectm_next_preset(void);  /* random/seq + history */
REWAMP_EXPORT void  rewamp_projectm_prev_preset(void);  /* pops preset history */
REWAMP_EXPORT int   rewamp_projectm_preset_count(void);
/* 1 when the preset on screen reads the "mouse" uniform. */
REWAMP_EXPORT int   rewamp_projectm_preset_uses_mouse(void);
REWAMP_EXPORT void  rewamp_projectm_set_mode(int random_next, int blend);
/* MilkDrop3 "mouse" uniform: x/y in 0..1 from the top-left of the visualizer
 * (-1 = pointer away), held = button down, clicked = release just happened. */
REWAMP_EXPORT void  rewamp_projectm_set_mouse(float x, float y, int held, int clicked);
// App lifecycle: 0 = background (stops the preload worker — GPU work is
// forbidden there on iOS and poisoned later preset switches), 1 = foreground
// (worker restarted by the next render tick).
REWAMP_EXPORT void  rewamp_projectm_set_active(int foreground);
REWAMP_EXPORT void  rewamp_projectm_set_params(
    int random_next, int lock_preset, int blend, double blend_time,
    double preset_duration, int quality_shift,
    int mesh_x, int mesh_y, double beat_sensitivity,
    int hardcut_enabled, double hardcut_time, double hardcut_sensitivity,
    int aspect_correction, int permissive,
    /* Pinned transition pattern, -1 = random (the default). */
    int transition_index);
/* Number of built-in transition patterns. 0 until an instance exists. */
REWAMP_EXPORT int   rewamp_projectm_transition_count(void);

/* Garde-fou « appareil trop lent »: 1 quand le preset COURANT est resté sous
 * 5 images/s pendant plus de 2 s d'affilée, 0 sinon. Le verdict est CONSOMMÉ
 * (rendu puis remis à zéro) pour qu'un client qui interroge périodiquement ne
 * traite jamais deux fois le même, et le compteur repart à chaque chargement
 * de preset — il juge un preset, pas une session. Mesuré sur le fil de RENDU,
 * seul endroit qui connaisse la cadence réelle (sur Android la SurfaceView est
 * pilotée par AChoreographer, Dart n'est pas dans la boucle). */
REWAMP_EXPORT int   rewamp_projectm_take_slow_verdict(void);
/* Serial bumped on every preset load (incl. the core's auto-switch); name/path
 * describe the current preset (empty until one is loaded). */
REWAMP_EXPORT int         rewamp_projectm_preset_serial(void);
REWAMP_EXPORT const char* rewamp_projectm_preset_name(void);
REWAMP_EXPORT const char* rewamp_projectm_preset_path(void);
/* Replace the active preset list: absolute *.milk paths joined by '\n'.
 * Applied on the render thread (or at the next init when the viz is off):
 * clears the history, invalidates the preload prediction, then blends into a
 * preset of the new list. Empty/NULL = fall back to scanning
 * <datadir>/projectm/presets. The list survives uninit. */
REWAMP_EXPORT void  rewamp_projectm_set_playlist(const char* paths,
                                                int start_index);
/* Texture search dirs joined by '\n' (bundle dir + installed pack bundles).
 * Empty/NULL = default <datadir>/projectm/textures. Survives uninit. */
REWAMP_EXPORT void  rewamp_projectm_set_texture_dirs(const char* dirs);

/* Flutter texture integration — call from Dart via FFI.
 * rewamp_viz_register    : init GL + register FlutterTexture → returns textureId.
 * rewamp_viz_resize_register : resize IOSurface buffers, notify Flutter.
 * rewamp_viz_render_and_notify : render frame + notify Flutter (call at ~60 Hz).
 * rewamp_viz_unregister  : tear down GL + unregister texture. */
REWAMP_EXPORT int64_t rewamp_viz_register(int width, int height);
REWAMP_EXPORT int64_t rewamp_scope_register(int width, int height);
REWAMP_EXPORT int64_t rewamp_noteviz_register(int width, int height);
REWAMP_EXPORT int64_t rewamp_patternviz_register(int width, int height);
REWAMP_EXPORT int64_t rewamp_spectrum_register(int width, int height);
REWAMP_EXPORT int64_t rewamp_pianoviz_register(int width, int height);
REWAMP_EXPORT int64_t rewamp_projectm_register(int width, int height);
REWAMP_EXPORT int     rewamp_viz_resize_register(int width, int height);
REWAMP_EXPORT void    rewamp_viz_render_and_notify(void);
REWAMP_EXPORT void    rewamp_scope_render_and_notify(void);
REWAMP_EXPORT void    rewamp_noteviz_render_and_notify(void);
REWAMP_EXPORT void    rewamp_patternviz_render_and_notify(void);
REWAMP_EXPORT void    rewamp_spectrum_render_and_notify(void);
REWAMP_EXPORT void    rewamp_pianoviz_render_and_notify(void);
REWAMP_EXPORT void    rewamp_projectm_render_and_notify(void);
REWAMP_EXPORT void    rewamp_viz_unregister(void);

/* Artwork background for GL visualizers.
 * rgba    : RGBA8 pixels (w×h×4 bytes), copied internally — caller may free.
 * opacity : 0.0 = invisible, 1.0 = fully opaque; used every render frame. */
REWAMP_EXPORT void rewamp_viz_set_artwork(const uint8_t* rgba, int w, int h, float opacity);
REWAMP_EXPORT void rewamp_viz_set_artwork_opacity(float opacity);
REWAMP_EXPORT void rewamp_viz_clear_artwork(void);

/* Exports par MOTEUR, appelés depuis Dart. Ils n'avaient jusqu'ici aucune
 * déclaration: définis directement dans leur TU de plugin, ils ne sortaient
 * que par la visibilité PAR DÉFAUT du compilateur. Apple ne le voit pas (le
 * moteur est lié statiquement dans le process, Dart passe par
 * DynamicLibrary.process()) et Android non plus (son CMakeLists ne restreint
 * pas la visibilité). Le plugin Linux, lui, construit une .so avec
 * C_VISIBILITY_PRESET hidden: sans REWAMP_EXPORT le symbole EXISTE dans le
 * binaire mais pas dans sa table dynamique, et lookupFunction lève. */
REWAMP_EXPORT void        rewamp_midi_set_soundfont(const char* path);
/* 1 = le morceau chargé est un MIDI écrit pour MT-32 que FluidLite joue en
 * GM faute de ROMs Roland (programmes traduits par la table ScummVM). Posé à
 * chaque ouverture, y compris à 0. */
REWAMP_EXPORT int         rewamp_midi_mt32_fallback(void);
/* MT-32 (mt32emu): dossier des ROMs importées (défaut <datadir>/mt32), jeu
 * retenu ("" = aucun utilisable — le greffon décline alors les .mid), et
 * identification d'UN fichier pour l'import ("" = inconnu de mt32emu). */
REWAMP_EXPORT void        rewamp_mt32_set_rom_dir(const char* path);
REWAMP_EXPORT const char* rewamp_mt32_rom_status(void);
REWAMP_EXPORT const char* rewamp_mt32_identify_rom(const char* path);
REWAMP_EXPORT const char* rewamp_mt32_lcd(void);
REWAMP_EXPORT int         rewamp_openmpt_active_instruments(uint8_t* out, int maxOut);
REWAMP_EXPORT const char* rewamp_sid_md5(const char* path);

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_AUDIO_H */
