// Symbol-rename header for libnsfplay's bundled emu2413 (OPLL/YM2413) and
// emu2149 (PSG/AY-3-8910).  These files share function names with the copies
// compiled as part of libvgm; prefixing avoids linker collisions.
//
// Include this header (or pass -include to the compiler) ONLY for the two
// legacy C sources: nsfplay-master/xgm/devices/Sound/legacy/emu2413.c
//                   nsfplay-master/xgm/devices/Sound/legacy/emu2149.c

// NOTE: REWAMP_NSF_OSCILLO_SIZE (the nsfplay scope ring size) is passed as a -D
// compile define from both build systems (podspec + cmake), not defined here,
// so nsfplay.cpp picks it up regardless of whether this header is prepended.

// ── OPLL / emu2413 ────────────────────────────────────────────────────────────
#define OPLL_new              nsf_OPLL_new
#define OPLL_delete           nsf_OPLL_delete
#define OPLL_reset            nsf_OPLL_reset
#define OPLL_resetPatch       nsf_OPLL_resetPatch
#define OPLL_setPatch         nsf_OPLL_setPatch
#define OPLL_copyPatch        nsf_OPLL_copyPatch
#define OPLL_patchToDump      nsf_OPLL_patchToDump
#define OPLL_dumpToPatch      nsf_OPLL_dumpToPatch
#define OPLL_getDefaultPatch  nsf_OPLL_getDefaultPatch
#define OPLL_setRate          nsf_OPLL_setRate
#define OPLL_setQuality       nsf_OPLL_setQuality
#define OPLL_setChipType      nsf_OPLL_setChipType
#define OPLL_setMask          nsf_OPLL_setMask
#define OPLL_toggleMask       nsf_OPLL_toggleMask
#define OPLL_setPan           nsf_OPLL_setPan
#define OPLL_setPanFine       nsf_OPLL_setPanFine
#define OPLL_forceRefresh     nsf_OPLL_forceRefresh
#define OPLL_writeIO          nsf_OPLL_writeIO
#define OPLL_writeReg         nsf_OPLL_writeReg
#define OPLL_calc             nsf_OPLL_calc
#define OPLL_calcStereo       nsf_OPLL_calcStereo
#define OPLL_RateConv_new     nsf_OPLL_RateConv_new
#define OPLL_RateConv_delete  nsf_OPLL_RateConv_delete
#define OPLL_RateConv_reset   nsf_OPLL_RateConv_reset
#define OPLL_RateConv_getData nsf_OPLL_RateConv_getData
#define OPLL_RateConv_putData nsf_OPLL_RateConv_putData

// ── PSG / emu2149 ─────────────────────────────────────────────────────────────
#define PSG_new               nsfplay_PSG_new
#define PSG_delete            nsfplay_PSG_delete
#define PSG_reset             nsfplay_PSG_reset
#define PSG_setMask           nsfplay_PSG_setMask
#define PSG_toggleMask        nsfplay_PSG_toggleMask
#define PSG_set_rate          nsfplay_PSG_set_rate
#define PSG_set_quality       nsfplay_PSG_set_quality
#define PSG_setVolumeMode     nsfplay_PSG_setVolumeMode
#define PSG_writeIO           nsfplay_PSG_writeIO
#define PSG_writeReg          nsfplay_PSG_writeReg
#define PSG_readIO            nsfplay_PSG_readIO
#define PSG_readReg           nsfplay_PSG_readReg
#define PSG_calc              nsfplay_PSG_calc
