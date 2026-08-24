# tiasound — Atari VCS TIA audio core

Stella's TIA audio emulation (`Audio` + `AudioChannel`), used by the TIATracker
plugin (`.ttt`) to turn the replayer's per-frame AUDC/AUDF/AUDV writes into PCM.

- Origin: the Stella emulator (https://stella-emu.github.io), Copyright (c)
  1995-2021 Bradford W. Mott, Stephen Anthony and the Stella Team. Taken from
  the copy already vendored under `third_party/furnace/src/engine/platform/
  sound/tia/`, which is upstream Stella with furnace's own trimming.
- Licence: as stated in each file header (Stella's `License.txt`, GPL-2.0).

**Why a second copy rather than reusing furnace's.** Same reason every other
duplicated core in this tree carries a rename: furnace exports these classes in
`namespace TIA`, and linking the TIATracker plugin against furnace's objects
would make `.ttt` support silently disappear whenever `REWAMP_WITH_FURNACE=0`.
The namespace here is **`TttTia`** — that is the whole diff against the furnace
copy (`namespace TIA` → `namespace TttTia`, plus the qualified uses). Re-sync by
re-running that substitution, not by editing the sources by hand.

The core is clocked in TIA colour clocks: `tick(n)` advances `n` of them and
refreshes `myCurrentSample` (mono sum) and `myChannelOut[0..1]` (per channel,
which is what feeds the two-voice oscilloscope) every 114 clocks, i.e. at the
~31.4 kHz the hardware updates its audio at.
