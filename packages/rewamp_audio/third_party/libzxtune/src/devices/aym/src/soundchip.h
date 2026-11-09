/**
* 
* @file
*
* @brief  AY/YM-based chips base implementation
*
* @author vitamin.caig@gmail.com
*
**/

#pragma once

//local includes
#include "renderers.h"
#include "volume_table.h"
//library includes
#include <devices/details/analysis_map.h>
#include <devices/details/parameters_helper.h>

namespace Devices
{
namespace AYM
{
  template<class Traits>
  class SoundChip : public Traits::ChipBaseType
  {
  public:
    SoundChip(ChipParameters::Ptr params, MixerType::Ptr mixer, Sound::Receiver::Ptr target)
      : Params(params)
      , Mixer(mixer)
      , Target(target)
      , PSG(VolTable)
      , Clock()
      , Renderers(Clock, PSG)
      , VoiceBase(rewamp_zx_voice_base)   //YOYOFR (rewamp)
    {
      SoundChip::Reset();
      //YOYOFR (rewamp): the PSG stamps notes by voice index outside the render
      //window, so it must know the base too (TurboSound: both halves).
      PSG.SetVoiceOfs(VoiceBase);
    }

    //YOYOFR (rewamp): the voice-capture globals the renderers read. They used
    //to be set by the PLAYERS (0 and 3, hard-coded), so every AY chip of a
    //MultiTrackContainer wrote the same voices 0-2 — three PT3 in one .mtc
    //showed one oscilloscope three times and six flat ones. Each chip now
    //binds its own range right before it renders.
    void BindVoices() const
    {
      m_voicesForceOfs = VoiceBase;
      m_voice_current_total = (char)Traits::CAPTURE_VOICES;
      rewamp_voice_notes_clear(VoiceBase, (int)Traits::CAPTURE_VOICES);   //the frame starts blank, for THIS chip
    }

    virtual void RenderData(const typename Traits::DataChunkType& src)
    {
      BindVoices();
      if (Clock.HasSamplesBefore(src.TimeStamp))
      {
        SynchronizeParameters();
        RenderTill(src.TimeStamp);
      }
      PSG.SetNewData(src.Data);
    }

    virtual void RenderData(const std::vector<typename Traits::DataChunkType>& src)
    {
      if (src.empty())
      {
        return;
      }
      BindVoices();
      const Stamp end = src.back().TimeStamp;
      if (Clock.HasSamplesBefore(end))
      {
        SynchronizeParameters();
        const uint_t samples = Clock.SamplesTill(end);
        Sound::ChunkBuilder builder;
        builder.Reserve(samples);
        for (typename std::vector<typename Traits::DataChunkType>::const_iterator it = src.begin(), lim = src.end(); it != lim; ++it)
        {
          const typename Traits::DataChunkType& chunk = *it;
          Renderers.Render(chunk.TimeStamp, builder);
          PSG.SetNewData(it->Data);
        }
        Target->ApplyData(builder.GetResult());
        Target->Flush();
      }
      else
      {
        for (typename std::vector<typename Traits::DataChunkType>::const_iterator it = src.begin(), lim = src.end(); it != lim; ++it)
        {
          PSG.SetNewData(it->Data);
        }
      }
    }

    virtual void Reset()
    {
      Params.Reset();
      PSG.Reset();
      Renderers.Reset();
    }

    virtual void GetState(MultiChannelState& state) const
    {
      MultiChannelState res;
      res.reserve(Traits::VOICES);
      PSG.GetState(res);
      for (MultiChannelState::iterator it = res.begin(), lim = res.end(); it != lim; ++it)
      {
        it->Band = Analyser.GetBandByPeriod(it->Band);
      }
      state.swap(res);
    }
  private:
    void SynchronizeParameters()
    {
      const uint_t AYM_CLOCK_DIVISOR = 8;

      if (Params.IsChanged())
      {
        PSG.SetDutyCycle(Params->DutyCycleValue(), Params->DutyCycleMask());
        const uint64_t clock = Params->ClockFreq() / AYM_CLOCK_DIVISOR;
        const uint_t sndFreq = Params->SoundFreq();
        Renderers.SetFrequency(clock, sndFreq);
        Renderers.SetInterpolation(Params->Interpolation());
        Analyser.SetClockRate(clock);
        VolTable.SetParameters(Params->Type(), Params->Layout(), *Mixer);
      }
    }

    void RenderTill(Stamp stamp)
    {
      const uint_t samples = Clock.SamplesTill(stamp);
      Sound::ChunkBuilder builder;
      builder.Reserve(samples);
      Renderers.Render(stamp, samples, builder);
      Target->ApplyData(builder.GetResult());
      Target->Flush();
    }
  private:
    Details::ParametersHelper<ChipParameters> Params;
    const MixerType::Ptr Mixer;
    const Sound::Receiver::Ptr Target;
    MultiVolumeTable VolTable;
    typename Traits::PSGType PSG;
    ClockSource Clock;
    Details::AnalysisMap Analyser;
    RenderersSet<typename Traits::PSGType> Renderers;
    const int VoiceBase;   //YOYOFR (rewamp): first global voice of this chip
  };
}
}
