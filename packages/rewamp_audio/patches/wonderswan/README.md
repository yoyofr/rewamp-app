# beetle-wswan patches

Upstream: <https://github.com/libretro/beetle-wswan-libretro> (`mednafen/wswan/`
+ `mednafen/sound/Blip_Buffer.c` + `include/`).

Everything under `third_party/wonderswan/wswan/` and `sound/` is upstream
**byte-for-byte** except `wswan/sound.c`, whose diff is `sound.c.patch`. Nothing
the libretro frontend used to provide was edited out of the sources: it lives in
the compat headers at the tree root (`mednafen-types.h`, `state.h`,
`state_inline.h`, `settings.h`, `mempatcher.h`, `video.h`) and in
`rewamp_wswan.c`. A re-sync is therefore a file copy plus this one patch.

`sound.c.patch` adds nothing but call sites — all the logic sits in
`third_party/wonderswan/rewamp_wswan_capture.h`:

* per-voice oscilloscope + notes capture (6 slots, OSwan's layout: 0-3 tone,
  4 = direct-D/A voice + Hyper Voice, 5 = noise),
* `generic_mute_mask` gating applied to `sample_cache[]` **before**
  `Blip_Synth_offset`, so muting silences the real mix and not just the display.

Apply with `patch -p0` from `third_party/wonderswan/wswan/` after copying a
fresh upstream `sound.c` over it.
