/*
 * This file is part of libsidplayfp, a SID player engine.
 *
 * Copyright 2011-2026 Leandro Nini <drfiemost@users.sourceforge.net>
 * Copyright 2007-2010 Antti Lankila
 * Copyright 2004 Dag Lem <resid@nimrod.no>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#ifndef FILTER_H
#define FILTER_H

//TODO:  MODIZER changes start / YOYOFR
extern "C" int sid_v4;
extern "C" int sid_scope_v[3];   // REWAMP: per-voice scope through the filter
extern "C" int sid_scope_filter_on;
//TODO:  MODIZER changes end / YOYOFR

#include "FilterModelConfig.h"
#include "Integrator.h"
#include "Voice.h"

#include "siddefs-fp.h"

namespace reSIDfp
{

/**
 * SID filter base class
 */
class Filter
{
    friend class State;

private:
    uint16_t* mixer;
    uint16_t* summer;
    uint16_t* resonance;
    uint16_t* volume;

    const FilterModelConfig& m_fmc;

    const Integrator& m_hpIntegrator;

    const Integrator& m_bpIntegrator;

    /// Current filter/voice mixer setting.
    uint16_t* currentMixer = nullptr;

    /// Filter input summer setting.
    uint16_t* currentSummer = nullptr;

    /// Filter resonance value.
    uint16_t* currentResonance = nullptr;

    /// Current volume amplifier setting.
    uint16_t* currentVolume = nullptr;

    /// Filter highpass state.
    int32_t Vhp = 0;

    /// Filter bandpass state.
    int32_t Vbp = 0;

    /// Filter lowpass state.
    int32_t Vlp = 0;

    /// Filter external input.
    float extin = 0;

    // REWAMP: per-voice oscilloscope through the filter. Each voice routed to
    // the filter also runs ALONE through a copy of its two integrators (same
    // cutoff, curve and resonance, set by the derived class with the real
    // ones), so the scope shows what the filter does to THAT voice. The
    // filter is not linear: the sum of these is not the audio, only each
    // voice's share of it.
    // Index 3: the filter fed with silence (rest level of its outputs).
    const Integrator* m_scopeHpI[4] = { nullptr, nullptr, nullptr, nullptr };
    const Integrator* m_scopeBpI[4] = { nullptr, nullptr, nullptr, nullptr };
    int32_t scopeVhp[4] = { 0, 0, 0, 0 };
    int32_t scopeVbp[4] = { 0, 0, 0, 0 };
    int32_t scopeVlp[4] = { 0, 0, 0, 0 };
    int32_t m_scopeFilt[4] = { 0, 0, 0, 0 };   // filter section output per state
    int32_t m_scopeSF = 0;        // a silent voice, filter input
    int32_t m_scopeSM = 0;        // a silent voice, mixer input
    bool m_scopeConstOk = false;
    uintptr_t m_scopeRestKey = 0;

    /// Filter cutoff frequency.
    uint16_t fc = 0;

    /// Routing to filter or outside filter
    //@{
    bool filt1 = false;
    bool filt2 = false;
    bool filt3 = false;
    bool filtE = false;
    //@}

    /// Switch voice 3 off.
    bool voice3off = false;

    /// Highpass, bandpass, and lowpass filter modes.
    //@{
    bool hp = false;
    bool bp = false;
    bool lp = false;
    //@}

private:
    /// Current volume.
    uint8_t vol = 0;

    /// Filter enabled.
    bool enabled = true;

    /// Selects which inputs to route through filter.
    uint8_t filt = 0;

protected:
    /**
     * Update filter cutoff frequency.
     */
    virtual void updateCenterFrequency() = 0;

    /**
     * Update filter resonance.
     *
     * @param res the new resonance value
     */
    void updateResonance(uint8_t res) { currentResonance = resonance + (res * (1<<16)); }

    /**
     * Mixing configuration modified (offsets change)
     */
    void updateMixing();

    /**
     * Get the filter cutoff register value
     */
    inline unsigned int getFC() const { return static_cast<unsigned int>(fc); }

    virtual void restartIntegrators() = 0;

    /// REWAMP: rest filter settled (cleared on any change of its parameters).
    bool m_scopeRestConverged = false;

    inline int32_t scopeRunFilter(int k, int32_t vin)
    {
        const int32_t vs = vin + scopeVlp[k] + currentResonance[scopeVbp[k]];
        scopeVhp[k] = currentSummer[vs];
        scopeVbp[k] = m_scopeHpI[k]->solve(scopeVhp[k]);
        scopeVlp[k] = m_scopeBpI[k]->solve(scopeVbp[k]);
        int32_t f = 0;
        if (lp) f += scopeVlp[k];
        if (bp) f += scopeVbp[k];
        if (hp) f += scopeVhp[k];
        return f;
    }

    // REWAMP: the derived class hands over its per-voice scope integrators.
    void setScopeIntegrators(const Integrator* hp[4], const Integrator* bp[4])
    {
        for (int i = 0; i < 4; i++) { m_scopeHpI[i] = hp[i]; m_scopeBpI[i] = bp[i]; }
    }

    inline int32_t getNormalizedVoice(float v, uint8_t env) const
    {
        return m_fmc.getNormalizedVoice(v, env);
    }

    virtual int32_t getNormalizedMixerVoice(float v, uint8_t env) const = 0;

public:
    Filter(const FilterModelConfig& fmc,
           const Integrator& hpIntegrator,
           const Integrator& bpIntegrator);

    virtual ~Filter() = default;

    /**
     * SID clocking - 1 cycle
     *
     * @param voice1 voice 1 in
     * @param voice2 voice 2 in
     * @param voice3 voice 3 in
     * @return filtered output, unsigned 16 bit
     */
    uint16_t clock(Voice& voice1, Voice& voice2, Voice& voice3);

    /**
     * REWAMP: the voice oscilloscope's mixer half, at an OUTPUT sample only.
     * Each voice alone through the same chain as the audio — same summer and
     * mixer tables for the current routing, cutoff, resonance, mode, volume —
     * with every OTHER input held at its REST level: a silent voice is a DC
     * level in this model, and one voice fed alone would fall off the mixer
     * table. Relative to the all-silent chain (0 = rest), into sid_scope_v.
     */
    void scopeOutput(Voice& voice1, Voice& voice2, Voice& voice3)
    {
        if (!m_scopeConstOk) { sid_scope_v[0] = sid_scope_v[1] = sid_scope_v[2] = 0; return; }
        Voice* v[3] = { &voice1, &voice2, &voice3 };
        const bool filts[3] = { filt1, filt2, filt3 };
        const int nDirect = !filt1 + !filt2 + (!filt3 && !voice3off) + !filtE;
        const int32_t base = currentVolume[currentMixer[nDirect * m_scopeSM + m_scopeFilt[3]]];
        for (int i = 0; i < 3; i++)
        {
            int32_t vmix;
            if (filts[i])
                vmix = nDirect * m_scopeSM + m_scopeFilt[i];
            else if (i == 2 && voice3off)
            {
                sid_scope_v[i] = 0;
                continue;
            }
            else
                vmix = (nDirect - 1) * m_scopeSM +
                       getNormalizedMixerVoice(v[i]->output(), v[i]->envelope()->output()) +
                       m_scopeFilt[3];
            sid_scope_v[i] = static_cast<int32_t>(currentVolume[currentMixer[vmix]]) - base;
        }
    }

    /**
     * Enable filter.
     *
     * @param enable
     */
    void enable(bool enable);

    /**
     * SID reset.
     */
    void reset();

    /**
     * Write Frequency Cutoff Low register.
     *
     * @param fc_lo Frequency Cutoff Low-Byte
     */
    void writeFC_LO(uint8_t fc_lo);

    /**
     * Write Frequency Cutoff High register.
     *
     * @param fc_hi Frequency Cutoff High-Byte
     */
    void writeFC_HI(uint8_t fc_hi);

    /**
     * Write Resonance/Filter register.
     *
     * @param res_filt Resonance/Filter
     */
    void writeRES_FILT(uint8_t res_filt);

    /**
     * Write filter Mode/Volume register.
     *
     * @param mode_vol Filter Mode/Volume
     */
    void writeMODE_VOL(uint8_t mode_vol);

    /**
     * Apply a signal to EXT-IN
     *
     * @param input a signed 16 bit sample
     */
    void input(int16_t input) { extin = input/65535.f; }

    void restart()
    {
        restartIntegrators(); Vhp = 0; Vlp = 0; Vbp = 0;
        for (int i = 0; i < 4; i++) { scopeVhp[i] = 0; scopeVbp[i] = 0; scopeVlp[i] = 0; }  // REWAMP
        m_scopeRestConverged = false;
    }
};

} // namespace reSIDfp

#if RESIDFP_INLINING || defined(FILTER_CPP)

namespace reSIDfp
{

RESIDFP_INLINE
uint16_t Filter::clock(Voice& voice1, Voice& voice2, Voice& voice3)
{
    // Waveform outputs
    const float wav1 = voice1.output();
    const float wav2 = voice2.output();
    const float wav3 = voice3.output();

    // Envelope outputs
    const uint8_t env1 = voice1.envelope()->output();
    const uint8_t env2 = voice2.envelope()->output();
    const uint8_t env3 = voice3.envelope()->output();

    // Voltage summer for filter input
    int32_t Vsum = 0;
    Vsum += filt1 ? getNormalizedVoice(wav1, env1) : 0;
    Vsum += filt2 ? getNormalizedVoice(wav2, env2) : 0;
    Vsum += filt3 ? getNormalizedVoice(wav3, env3) : 0;
    Vsum += filtE ? getNormalizedVoice(extin, 0) : 0;
    Vsum += Vlp;
    Vsum += currentResonance[Vbp];

    // Filter
    Vhp = currentSummer[Vsum];
    Vbp = m_hpIntegrator.solve(Vhp);
    Vlp = m_bpIntegrator.solve(Vbp);

    int32_t Vfilt = 0;
    if (lp) Vfilt += Vlp;
    if (bp) Vfilt += Vbp;
    if (hp) Vfilt += Vhp;

    // Voltage summer for mixer input
    int32_t Vmix = 0;
    Vmix += filt1 ? 0 : getNormalizedMixerVoice(wav1, env1);
    Vmix += filt2 ? 0 : getNormalizedMixerVoice(wav2, env2);
    // Voice 3 is silenced by voice3off if it is not routed through the filter
    Vmix += (filt3 || voice3off) ? 0 : getNormalizedMixerVoice(wav3, env3);
    Vmix += filtE ? 0 : getNormalizedMixerVoice(extin, 0);
    Vmix += Vfilt;

    //TODO:  MODIZER changes start / YOYOFR
    // Digi voice: what the mixer outputs from the external input alone, i.e.
    // the volume-register DAC that sample players drive.
    sid_v4 = currentVolume[currentMixer[filtE ? 0 : getNormalizedMixerVoice(extin, 0)]];
    //TODO:  MODIZER changes end / YOYOFR

    // REWAMP: voice oscilloscope through the filter — the per-CYCLE half:
    // only the integrators, which must see every cycle. The mixer half, which
    // only matters where the resampler emits a sample (~1 cycle in 22),
    // lives in scopeOutput(). Only while a voice oscilloscope is shown.
    if (sid_scope_filter_on && m_scopeHpI[3] != nullptr)
    {
        if (!m_scopeConstOk)
        {
            m_scopeSF = getNormalizedVoice(0.f, 0);
            m_scopeSM = getNormalizedMixerVoice(0.f, 0);
            m_scopeConstOk = true;
        }
        const int nSum = filt1 + filt2 + filt3 + filtE;
        // Resonance, routing and mode change the rest level; the cutoff and
        // curve are flagged by the derived class (updateCenterFrequency).
        const uintptr_t key = reinterpret_cast<uintptr_t>(currentResonance) ^
                              (reinterpret_cast<uintptr_t>(currentSummer) << 1) ^
                              (static_cast<uintptr_t>(lp | (bp << 1) | (hp << 2)) << 3);
        if (key != m_scopeRestKey) { m_scopeRestKey = key; m_scopeRestConverged = false; }
        // Filter 3 = the filter fed with silence. Its input never changes, so
        // it settles: stepped until a cycle leaves it unchanged, then frozen
        // until a register moves it.
        const int32_t restIn = nSum * m_scopeSF;
        if (nSum == 0)
        {
            m_scopeFilt[3] = 0;
        }
        else if (!m_scopeRestConverged)
        {
            const int32_t h = scopeVhp[3], b = scopeVbp[3], l = scopeVlp[3];
            m_scopeFilt[3] = scopeRunFilter(3, restIn);
            m_scopeRestConverged = h == scopeVhp[3] && b == scopeVbp[3] && l == scopeVlp[3];
        }
        const float wavs[3] = { wav1, wav2, wav3 };
        const uint8_t envs[3] = { env1, env2, env3 };
        const bool filts[3] = { filt1, filt2, filt3 };
        for (int i = 0; i < 3; i++)
        {
            if (!filts[i]) continue;
            const int32_t vin = getNormalizedVoice(wavs[i], envs[i]) + (nSum - 1) * m_scopeSF;
            // A silent voice whose filter already sits at rest: nothing to
            // integrate, the rest filter answers for it.
            if (m_scopeRestConverged && vin == restIn &&
                scopeVhp[i] == scopeVhp[3] && scopeVbp[i] == scopeVbp[3] &&
                scopeVlp[i] == scopeVlp[3])
            {
                m_scopeFilt[i] = m_scopeFilt[3];
                continue;
            }
            m_scopeFilt[i] = scopeRunFilter(i, vin);
        }
    }

    return currentVolume[currentMixer[Vmix]];
}

} // namespace reSIDfp

#endif

#endif
