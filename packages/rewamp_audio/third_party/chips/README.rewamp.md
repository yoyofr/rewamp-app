# floooh/chips — Amstrad CPC 6128 (`REWAMP_WITH_CPC`) and ZX Spectrum (`REWAMP_WITH_ZXSPECTRUM`)

Header-only C emulators by Andre Weissflog, zlib licence (`LICENSE`).

- **Source:** https://github.com/floooh/chips, commit
  `9e88298ce56319953ac7a43213a1120359f7a3a6` (2026-09-26). Only the headers
  the CPC needs are vendored: `chips/{chips_common,z80,ay38910,i8255,mc6845,
  am40010,upd765,kbd,clk,mem,fdd,fdd_cpc,beeper}.h`, `systems/cpc.h` and
  `systems/zx.h`.
- **Implementations:** the shared core (z80, ay38910, kbd, clk, mem) is
  implemented ONCE — by `src/rewamp_plugin_cpc.c` (which defines
  `CHIPS_IMPL`), or by `src/rewamp_plugin_zx.c` when the CPC plugin is not
  built (`#ifndef REWAMP_WITH_CPC`). `beeper.h` and `zx.h` are implemented by
  the ZX plugin only. Nothing else may include these headers with `CHIPS_IMPL`.
- **`rewamp_chips_rename.h`** (generated) prefixes every non-static chips
  symbol with `rwcpc_`: nez already defines a `z80_tick`, and names like
  `mem_init` / `kbd_init` / `fdd_read` are collisions waiting to happen. Re-run
  the generator (see the commit that added this file) after a resync.

## rewamp patches (search `REWAMP`)

- `chips/ay38910.h` — per-voice output **averaged over each output sample**
  (`rw_acc`/`rw_chn`) instead of upstream's point sample of the 1 MHz state,
  which aliased high tones and fast envelopes; `rw_mute` silences a voice in
  every output. The mono `sample` upstream computes is now the sum of the
  averaged voices.
- `systems/cpc.h` — `rw_psg_sample` hook (every PSG sample, with the chip, so
  the plugin builds the CPC stereo — A left, B centre, C right — and the
  scopes) and `rw_txt_out` (an opcode fetch at the firmware's TXT OUTPUT entry
  `&BB5A` = one printed character: the plugin shows what a music disk prints
  in the ⓘ panel). Both NULL = upstream behaviour.
- `systems/zx.h` — `rw_sample` (every audio sample, with the machine: the
  plugin mixes beeper + AY voices itself) and `rw_m1` (opcode fetch at
  0x0010 = RST 10h PRINT, and 0x0556 = LD-BYTES; returning true makes the CPU
  execute a RET: the tape trap). All NULL = upstream behaviour.

## ROMs

`roms/cpc6128_{os,basic,amsdos}.bin`, from floooh/chips-test
(`examples/roms`, commit `14f423dd168dbd105a70f3c283392a5dd775a47d`), compiled
in through `rewamp_cpc6128_roms.h` (generated from the `.bin`, do not edit).
SHA-1: os `732ac628…`, basic `d7d03755…`, amsdos `39102c8e…`.

`roms/zx48k.bin`, `roms/zx128_{0,1}.bin` — `amstrad_zx48k.bin`,
`amstrad_zx128k_{0,1}.bin` from the same chips-test commit, compiled in
through `rewamp_zx_roms.h` (generated, do not edit). SHA-1: 48k
`5ea7c2b8…`, 128k_0 `4f4b11ec…`, 128k_1 `80080644…`. The Spectrum ROMs are
(c) Amstrad, which bought Sinclair's computer business in 1986; the vendored
permission below was posted to comp.sys.sinclair about THESE ROMs first, the
CPC's coming in on the same terms.

The ROMs carry "Copyright 1985 Amstrad Consumer Electronics plc and Locomotive
Software Ltd." (printed by the OS at boot; dumps used as shipped by floooh/chips-test, not altered by us). Amstrad's
permission — Cliff Lawson, comp.sys.sinclair / comp.sys.amstrad.8bit,
1999-08-31 — is vendored verbatim in `AMSTRAD-ROM-PERMISSION.txt`. Its terms:
leave the (c) messages unaltered, do not charge for the ROM code, and (asked,
not required) say "Amstrad have kindly given their permission for the
redistribution of their copyrighted material but retain that copyright" —
done in the credits (`app/lib/engines.dart`, THIRD-PARTY-NOTICES.md).
Open point: parts of the CPC firmware are also (c) Locomotive Software, whose
permission the same message says to seek as well; none is vendored.
