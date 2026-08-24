/*
 * ModizerVoicesData.h — compatibility shim for rewamp_audio
 *
 * libvgm chip cores at third_party/libvgm/libvgm/emu/cores/ include:
 *   #include "../../../../../src/ModizerVoicesData.h"
 * which resolves to this file.  We re-export the same declarations the
 * chip cores expect, backed by the globals defined in rewamp_channel_data.c.
 */

#ifndef ModizerVoicesData_h
#define ModizerVoicesData_h

#include "ModizerConstants.h"
#include <stdint.h>
#include <sys/types.h>

#define MAXVAL(a, b) ((a) > (b) ? (a) : (b))
#define LIMIT8(a)    ((a) > 127 ? 127 : ((a) < -128 ? -128 : (a)))

/* ── oscilloscope ring buffers (written per-channel by chip emulators) ─── */
extern signed char      *m_voice_buff[SOUND_MAXVOICES_BUFFER_FX];
extern int64_t           m_voice_current_ptr[SOUND_MAXVOICES_BUFFER_FX];
extern int64_t           m_voice_prev_current_ptr[SOUND_MAXVOICES_BUFFER_FX];
extern int               m_voice_ChipID[SOUND_MAXVOICES_BUFFER_FX];

/* ── per-chip context, set by vgmplayer.cpp before each chip render ────── */
extern signed char       m_voice_current_system;
extern signed char       m_voice_current_systemSub;
extern char              m_voice_current_systemPairedOfs;
extern char              m_voice_current_total;
extern int               m_voice_current_samplerate;
extern double            m_voice_current_rateratio;

/* ── per-channel note / volume (written by chip cores) ────────────────── */
extern unsigned int      vgm_last_vol[SOUND_MAXVOICES_BUFFER_FX];
extern unsigned int      vgm_last_note[SOUND_MAXVOICES_BUFFER_FX];
extern unsigned char     vgm_last_instr[SOUND_MAXVOICES_BUFFER_FX];
extern unsigned int      vgm_last_sample_address[SOUND_MAXVOICES_BUFFER_FX];
extern unsigned int      vgm_last_sample_address_inst[256];
extern unsigned char     vgm_last_sample_address_lastupdate[SOUND_MAXVOICES_BUFFER_FX];

/* ── ES5503 / YMF271-style accumulation buffers ───────────────────────── */
extern signed int       *m_voice_buff_accumul_temp[SOUND_MAXVOICES_BUFFER_FX];
extern unsigned char    *m_voice_buff_accumul_temp_cnt[SOUND_MAXVOICES_BUFFER_FX];
extern int               m_voice_buff_adjustement;
extern int               m_voice_fadeout_factor;

/* ── muting masks ─────────────────────────────────────────────────────── */
extern int64_t           generic_mute_mask;
extern int               m_voicesForceOfs;

/* ── timing helpers (used by some chip cores) ─────────────────────────── */
extern int64_t           mdz_ratio_fp_cnt, mdz_ratio_fp_inc, mdz_ratio_fp_inv_inc;
extern double            mdz_pbratio;

/* ── channel / voice tracking ─────────────────────────────────────────── */
extern int               m_genNumVoicesChannels, m_genNumMidiVoicesChannels;
extern int               m_genMasterVol; /* libnsfplay fader.h */
extern char              m_voicesStatus[SOUND_MAXMOD_CHANNELS];
extern int               m_voice_systemColor[SOUND_VOICES_MAX_ACTIVE_CHIPS];
extern int               m_voice_voiceColor[SOUND_MAXVOICES_BUFFER_FX];

/* ── voice / chipset grouping metadata (generic mute+grouping framework) ─
 * Mirrors Modizer's ModizMusicPlayer.mm model so future core patches drop in:
 * each chip is {startVoice, voicesCount, name}; voices carry a name + ChipID.
 * Populated by a plugin's open() via rewamp_voices_add_chip()/set_name(). */
extern char              modizChipsetStartVoice[MODIZ_MAX_CHIPS];
extern char              modizChipsetVoicesCount[MODIZ_MAX_CHIPS];
extern char              modizChipsetName[MODIZ_MAX_CHIPS][MODIZ_CHIP_NAME_MAX_CHAR];
extern char              modizVoicesName[SOUND_MAXVOICES_BUFFER_FX][MODIZ_VOICE_NAME_MAX_CHAR];
extern char              modizChipsetCount;

/* ── chip variant flags ───────────────────────────────────────────────── */
extern char              vgmVRC7, vgm2610b;

/* ── libsidplayfp oscilloscope state (SID.cpp patches) ────────────────── */
extern void             *m_sid_chipId[MAXSID_CHIPS];
extern int               m_sid_chipNb;
extern char              mSIDSeekInProgress;
extern int               sid_v4;

/* ── ProjectM audio buffer (unused in rewamp but declared for linkage) ── */
extern short int         pmBuffer[PM_BUFFER_SIZE * 2];
extern int               pmBufferPosWrite, pmBufferPosRead;

/* ── MIDI channel mappings (unused in rewamp) ─────────────────────────── */
extern unsigned char     m_voice_channel_mapping[256];
extern unsigned char     m_channel_voice_mapping[256];

#endif /* ModizerVoicesData_h */
