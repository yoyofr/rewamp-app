# vgm_v3.h

Copied verbatim from https://github.com/yoyofr/vgm-tools (`vgm_v3.h`, commit
`e298ba7`). Header-only C++17, standard library only.

Converts the first ES5505/ES5506/ES5510 and ZSG-2/TMS57002 VGM encoding (v1:
libvgm `es55xx` branch and MAME logger until 2026-10-31) to the v3 encoding
(`VGM-proposal-v3-allocation.md` in the same repository) that the libvgm
`vgm-v3` branch reads. `rewamp_plugin_vgm.cpp` runs it in memory at load time;
files on disk are never modified.

Refresh: copy the file again and update the commit above.
