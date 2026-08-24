/**
* 
* @file
*
* @brief  AY/YM device bus implementation
*
* @author vitamin.caig@gmail.com
*
**/

#pragma once

//local includes
#include "device.h"
#include "volume_table.h"

namespace Devices
{
namespace AYM
{
  class PSG
  {
  public:
    explicit PSG(const MultiVolumeTable& table)
      : Table(table)
      , Regs()
      , VoiceOfs(0)
    {
      Regs[Registers::MIXER] = 0xff;
    }

    //YOYOFR (rewamp): index of this chip's first voice in the global voice
    //arrays. TurboSound's second chip starts at 3. The renderer's
    //m_voicesForceOfs cannot be used here — it is only set while GetLevels()
    //runs, and registers arrive outside that window.
    void SetVoiceOfs(int ofs)
    {
      VoiceOfs = ofs;
    }

    void SetDutyCycle(uint_t value, uint_t mask)
    {
      Device.SetDutyCycle(value, mask);
    }

    void Reset()
    {
      std::fill(Regs.begin(), Regs.end(), 0);
      Regs[Registers::MIXER] = 0xff;
      Device.Reset();
    }

    void SetNewData(const Registers& data)
    {
      const uint_t REGS_4BIT_SET = (1 << Registers::TONEA_H) | (1 << Registers::TONEB_H) |
        (1 << Registers::TONEC_H) | (1 << Registers::ENV);
      const uint_t REGS_5BIT_SET = (1 << Registers::TONEN) | (1 << Registers::VOLA) |
        (1 << Registers::VOLB) | (1 << Registers::VOLC);

      uint_t used = 0;
      for (Registers::IndicesIterator it(data); it; ++it)
      {
        const Registers::Index reg = *it;
        if (!data.Has(reg))
        {
          //no new data
          continue;
        }
        //copy registers
        uint8_t val = data[reg];
        const uint_t mask = 1 << reg;
        //limit values
        if (mask & REGS_4BIT_SET)
        {
          val &= 0x0f;
        }
        else if (mask & REGS_5BIT_SET)
        {
          val &= 0x1f;
        }
        Regs[reg] = val;
        used |= mask;
      }
      if (used & (1 << Registers::MIXER))
      {
        Device.SetMixer(GetMixer());
      }
      if (used & ((1 << Registers::TONEA_L) | (1 << Registers::TONEA_H)))
      {
        Device.SetToneA(GetToneA());
      }
      if (used & ((1 << Registers::TONEB_L) | (1 << Registers::TONEB_H)))
      {
        Device.SetToneB(GetToneB());
      }
      if (used & ((1 << Registers::TONEC_L) | (1 << Registers::TONEC_H)))
      {
        Device.SetToneC(GetToneC());
      }
      if (used & (1 << Registers::TONEN))
      {
        Device.SetToneN(GetToneN());
      }
      if (used & ((1 << Registers::TONEE_L) | (1 << Registers::TONEE_H)))
      {
        Device.SetToneE(GetToneE());
      }
      if (used & (1 << Registers::ENV))
      {
        Device.SetEnvType(GetEnvType());
      }
      if (used & ((1 << Registers::VOLA) | (1 << Registers::VOLB) | (1 << Registers::VOLC)))
      {
        Device.SetLevel(Regs[Registers::VOLA], Regs[Registers::VOLB], Regs[Registers::VOLC]);
      }
      UpdateNotes();
    }

    //YOYOFR (rewamp): per-voice pitch/level for the notation viz and the scope's
    //note readout. aym_base.cpp clears vgm_last_note/vol every frame and nothing
    //used to refill them, so every AY format came out with no notes at all —
    //including the ones that have no patterns to fall back on (.vtx/.ym/.psg).
    //
    //The REGISTERS are the answer rather than any player's note number: a tone
    //period is what the chip actually sounds, so slides and ornaments come out
    //right. Two gates, both needed. The MIXER bit decides whether the tone
    //generator reaches the output at all — a noise-only or silent channel must
    //not keep showing the previous pitch — and a zero amplitude with no envelope
    //means the voice is off.
    //
    //The envelope case is not a detail: an AY bass line is very often written
    //with the tone switched OFF and the pitch carried by the envelope itself.
    //Only the REPEATING shapes are a pitch (8/A/C/E cycle; the odd ones and
    //everything below 8 decay once and hold), and the envelope divides the clock
    //by 256 where the tone divides by 16.
    void UpdateNotes() const
    {
      //SetFrequency stores the clock the DEVICE runs at, which soundchip.h has
      //already divided by 8 (AYM_CLOCK_DIVISOR). The tone generator toggles every
      //`period` ticks of THAT clock, so a cycle is 2*period — the familiar
      //master/(16*period) with the division folded in. Same for the envelope:
      //master/(256*period) becomes divided/(32*period).
      const uint64_t clock = m_voice_current_samplerate;
      if (!clock)
      {
        return;
      }
      const uint_t mixer = Regs[Registers::MIXER];
      const uint_t envType = Regs[Registers::ENV];
      const uint_t envPeriod = (uint_t(Regs[Registers::TONEE_H]) << 8) | Regs[Registers::TONEE_L];
      for (int c = 0; c < 3; ++c)
      {
        const int v = VoiceOfs + c;
        if (v >= SOUND_MAXVOICES_BUFFER_FX)
        {
          break;
        }
        const uint_t amp = Regs[Registers::VOLA + c];
        const bool envDriven = 0 != (amp & 0x10);
        const uint_t level = envDriven ? 15 : (amp & 0x0f);
        const bool toneOn = 0 == (mixer & (1 << c));
        const uint_t period = (uint_t(Regs[Registers::TONEA_H + c * 2]) << 8) |
                               Regs[Registers::TONEA_L + c * 2];

        vgm_last_vol[v] = (level * 255) / 15;
        if (toneOn && level && period)
        {
          vgm_last_note[v] = uint_t(double(clock) / (2.0 * period));
        }
        else if (envDriven && !toneOn && envPeriod && (envType & 0x08) && !(envType & 0x01))
        {
          vgm_last_note[v] = uint_t(double(clock) / (32.0 * envPeriod));
        }
        else
        {
          vgm_last_note[v] = 0;
        }
      }
    }

    void Tick(uint_t ticks)
    {
      Device.Tick(ticks);
    }

    Sound::Sample GetLevels() const
    {
      return Table.Get(Device.GetLevels());
    }
      
      Sound::Sample GetLevelsChan(int chan) const
      {
        return Table.Get(Device.GetLevelsChan(chan));
      }
      
      

    void GetState(MultiChannelState& state) const
    {
      const uint_t TONE_VOICES = 3;
      const LevelType COMMON_LEVEL_DELTA(1, TONE_VOICES);
      const LevelType EMPTY_LEVEL;
      LevelType noiseLevel, envLevel;
      //taking into account only periodic envelope
      const bool periodicEnv = 0 != ((1 << GetEnvType()) & ((1 << 8) | (1 << 10) | (1 << 12) | (1 << 14)));
      const uint_t mixer = ~GetMixer();
      for (uint_t chan = 0; chan != TONE_VOICES; ++chan) 
      {
        const uint_t volReg = Regs[Registers::VOLA + chan];
        const bool hasNoise = 0 != (mixer & (uint_t(Registers::MASK_NOISEA) << chan));
        const bool hasTone = 0 != (mixer & (uint_t(Registers::MASK_TONEA) << chan));
        const bool hasEnv = 0 != (volReg & Registers::MASK_ENV);
        //accumulate level in noise channel
        if (hasNoise)
        {
          noiseLevel += COMMON_LEVEL_DELTA;
        }
        //accumulate level in envelope channel      
        if (hasEnv)
        {        
          envLevel += COMMON_LEVEL_DELTA;
        }
        //calculate tone channel
        if (hasTone)
        {
          const uint_t MAX_VOL = Registers::MASK_VOL;
          const LevelType level(volReg & Registers::MASK_VOL, MAX_VOL);
          const uint_t band = 2 * (256 * Regs[Registers::TONEA_H + chan * 2] +
            Regs[Registers::TONEA_L + chan * 2]);
          state.push_back(ChannelState(band, level));
        }
      }
      if (noiseLevel != EMPTY_LEVEL)
      {
        state.push_back(ChannelState(GetToneN(), noiseLevel));
      }
      if (periodicEnv && envLevel != EMPTY_LEVEL)
      {
        //periodic envelopes has 32 steps, so multiply period to 32
        state.push_back(ChannelState(32 * GetToneE(), envLevel));
      }  
    }
  private:
    uint_t GetMixer() const
    {
      return Regs[Registers::MIXER];
    }

    uint_t GetToneA() const
    {
      return 256 * Regs[Registers::TONEA_H] + Regs[Registers::TONEA_L];
    }

    uint_t GetToneB() const
    {
      return 256 * Regs[Registers::TONEB_H] + Regs[Registers::TONEB_L];
    }

    uint_t GetToneC() const
    {
      return 256 * Regs[Registers::TONEC_H] + Regs[Registers::TONEC_L];
    }

    uint_t GetToneN() const
    {
      return 2 * Regs[Registers::TONEN];//for optimization
    }

    uint_t GetToneE() const
    {
      return 256 * Regs[Registers::TONEE_H] + Regs[Registers::TONEE_L];
    }

    uint_t GetEnvType() const
    {
      return Regs[Registers::ENV];
    }
  private:
    const MultiVolumeTable& Table;
    //registers state
    boost::array<uint_t, Registers::TOTAL> Regs;
    int VoiceOfs;   //YOYOFR (rewamp)
    //device
    AYMDevice Device;
  };
}
}
