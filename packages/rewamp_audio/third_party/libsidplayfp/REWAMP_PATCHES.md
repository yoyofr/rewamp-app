# rewamp patches to libsidplayfp / libresidfp

All patches applied on top of the vendored copies in this directory.
**Re-apply every section marked MUST RE-APPLY after any upstream update.**

---

## 1. MUST RE-APPLY — `libsidplayfp/src/Event.h` — include guard clash with IOKit

**Problem:** On Apple platforms, `.mm` wrapper files get the Cocoa prefix PCH
(`#import <Cocoa/Cocoa.h>`), which pulls in `AppKit/NSEvent.h` →
`IOKit/hidsystem/IOLLEvent.h` → `#define EVENT_H`.
When `EventScheduler.h` does `#include "Event.h"`, the preprocessor sees
`EVENT_H` already defined and skips the entire file → cascade of
`unknown type name 'Event'` errors.

**Fix:**
```c
// BEFORE (upstream):
#ifndef EVENT_H
#define EVENT_H
// AFTER (rewamp):
#ifndef LIBSIDPLAYFP_EVENT_H
#define LIBSIDPLAYFP_EVENT_H
```
(and the matching `#endif` comment). Nothing else in libsidplayfp uses `EVENT_H`.

---

## 2. MUST RE-APPLY — `libresidfp/src/SID.h` — skip analog filter during seek

**Context:** `mSIDSeekInProgress` is a Modizer-era global (`extern char`) defined in
`rewamp_channel_data.c`. The original Modizer patch gated only the resampler
output and ring-buffer writes behind this flag. The analog filter
(`filter->clock()`) and external filter (`externalFilter.clock()`) still ran
every SID clock cycle during fast-forward seek, making seek as slow as normal
playback.

**Fix — in the inner sample loop of `SID::clock()`:**
```cpp
// BEFORE (Modizer patch — filter still runs during seek):
const int sidOutput = static_cast<int>(filter->clock(voice[0], voice[1], voice[2]));
const int c64Output = externalFilter.clock(sidOutput + INT16_MIN);
if (!mSIDSeekInProgress) {
    if (unlikely(resampler->input(c64Output))) { ... ring-buffer writes ... }
}

// AFTER (rewamp patch — filter short-circuited during seek):
const int sidOutput = mSIDSeekInProgress ? 0
    : static_cast<int>(filter->clock(voice[0], voice[1], voice[2]));
const int c64Output = mSIDSeekInProgress ? 0
    : externalFilter.clock(sidOutput + INT16_MIN);
if (!mSIDSeekInProgress) {
    if (unlikely(resampler->input(c64Output))) { ... ring-buffer writes ... }
}
```

Oscillator `clock()` and envelope `clock()` still run — required for correct
musical state at the seek target. Tradeoff: brief filter "cold start" artifact
on resume (imperceptible in practice, same as Modizer).

---

## 3. Oscilloscope buffer initialisation — reset BEFORE engine->load()

`SID::clock()` (libresidfp, Modizer-patched) writes per-voice samples into
`m_voice_buff[sid_idx+0..3]` on the very first clock cycle. `sidplayfp::load()`
runs the psid driver which clocks the SID immediately. Therefore
`rewamp_channel_data_reset(voiceCount)` **must** run before `load()` — otherwise
`m_voice_buff[*]` is NULL → `EXC_BAD_ACCESS` in `SID::clock`.

- `installedSIDs()` is valid only AFTER `load()`. Use `tune->getInfo()->sidChips()`
  BEFORE load to get the chip count.
- Channel stride is **4 per chip** (3 oscillator voices + 1 digi channel):
  `SID::clock()` writes index `chip*4 + 0..3`. Allocating 3/chip overflows.
- Call `rewamp_channel_data_reset(numVoices)` +
  `rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE*2)`,
  then `load()`, then `initMixer(true)`.

---

## 4. SID seek implementation (`src/rewamp_plugin_sid.cpp :: sid_seek()`)

libsidplayfp has no native seek. Strategy: reload tune (reset to start), then
fast-forward using `play()` only — **no `mix()` call**.

- `mix()` runs the full reSIDfp analog filter pipeline, as expensive as normal
  playback. Skipping it reduces seek time by ~10–20×.
- Set `mSIDSeekInProgress = 1` before the loop, `0` after, so the `SID.h`
  filter skip (patch 2) and ring-buffer suppression both apply.
- Batch size: `SID_FRAMES_PER_CALL * 64` (~1.3 s of SID time per `play()` call)
  to minimise event-scheduler call overhead.
- Always resets to position 0 then fast-forwards; handles backward seeks
  automatically.

**Dart UI:** `player_screen.dart` uses `onChangeEnd` (not `onChanged`) on the
`Slider` so the seek fires once when the user releases. A `_seekDragValue`
local state shows the preview position during drag without triggering C seeks.

---

## 5. `rewamp_sid_md5()` — HVSC MD5 for metadata lookup

`extern "C" const char* rewamp_sid_md5(const char* path)` in
`src/rewamp_plugin_sid.cpp`: opens a fresh `SidTune`, strips any `?subsong=N`
suffix, calls `tune.createMD5New(buf)`, returns a static 32-char hex string.

Used by Dart FFI (`RewampAudio.sidMd5()`) to look up songlength + STIL data
via the server `get_sid_info` RPC (POST `/rpc/get_sid_info`, param `p_md5`).

Note: `createMD5New` computes the HVSC MD5 (hash over load/init/play addresses
+ data + speed/clock/model flags), not a raw file MD5. This matches the key
used by `Songlengths.md5` and `STIL.txt` in the HVSC distribution.

---

## 6. `rewamp_channel_data_clear()` — stop clears oscilloscope/notes

Defined in `src/rewamp_channel_data.c`, declared in `src/rewamp_channel_data.h`.
Called from `rewamp_stop()` in `src/rewamp_audio.c` (which also zeros the
stereo waveform ring buffer `g_wf_left` / `g_wf_right` / `g_wf_pos`).

What it does:
- Zeros all `m_voice_buff[i]` ring-buffer contents (memset to 0)
- Resets `m_voice_current_ptr[i]` and `m_voice_prev_current_ptr[i]` to 0
- Zeros `vgm_last_vol`, `vgm_last_note`, `vgm_last_instr`
- Zeros `g_trigger_template`
- Does **not** change `g_channel_count` — buffers refill automatically when
  playback resumes; no reload needed.

---

## 7. Seek progress + cancellation

Three volatile globals in `rewamp_audio.c` let Dart poll seek progress at ~60 Hz and cancel an in-progress seek:

| Global | Type | Written by | Read by |
|---|---|---|---|
| `g_seek_cancel` | `volatile int` | Main thread (Dart → `rewamp_stop` / `rewamp_seek_seconds`) | `sid_seek()` loop check |
| `g_is_seeking` | `volatile int` | `sid_seek()` (set 1 at start, 0 at end) | Dart FFI `rewamp_is_seeking()` |
| `g_seek_progress_s` | `volatile double` | `sid_seek()` each batch | Dart FFI `rewamp_seek_progress_seconds()` |

**Flow:**
1. `rewamp_seek_seconds(target)` → sets `g_seek_cancel=1` (aborts running seek), resets `g_seek_progress_s=0`, sets `g_seek_cancel=0`, posts new seek via `ma_sound_seek_to_pcm_frame`.
2. `rewamp_stop()` → sets `g_seek_cancel=1` (abort) before stopping.
3. `sid_seek()` loop: `while (remaining > 0 && !g_seek_cancel)` — each batch updates `g_seek_progress_s = framePos / SID_RENDER_RATE`.
4. Dart `PlayerController.tick()`: if `isSeeking`, polls `audio.isSeeking()` + `audio.seekProgressSeconds()` → updates `ctrl.position` → rebuilds seek bar.
5. When `audio.isSeeking()` returns false, `isSeeking = false` in Dart and cursor snaps to real position.

No locking — deliberate. A torn read of `double g_seek_progress_s` at 60 Hz is invisible (max error = ~1 ms at 48 kHz, single batch duration).

---

## 8. Build flags and header paths (CocoaPods, Apple platforms only)

```ruby
# In macos/rewamp_audio.podspec prepare_command:
preprocessor << 'REWAMP_WITH_SID=1'
preprocessor << 'HAVE_CXX23=1'   # → HAVE_CXX11 via sidcxx11.h cascade

# pod_target_xcconfig:
'USE_HEADERMAP'                => 'NO',
'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',

# Header search paths (relative to pod root):
"#{sid_root}/libsidplayfp/src"
"#{sid_root}/libsidplayfp/src/sidplayfp"
"#{sid_root}/libsidplayfp/src/builders/residfp-builder"
"#{sid_root}/libresidfp/src"
```

One `.mm` wrapper per `.cpp` source (no unity build — static name conflicts).
Wrappers live in `Classes/sid_cores/`; `residfp/` subdir files get their own
wrapper loop with `test.cpp` excluded (it defines `main()`).
