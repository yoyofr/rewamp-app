#include "Loudness.hpp"

#include <cmath>

namespace libprojectM {
namespace Audio {

Loudness::Loudness(Loudness::Band band)
    : m_band(band)
{
}

void Loudness::Update(const std::array<float, SpectrumSamples>& spectrumSamples, double secondsSinceLastFrame, uint32_t frame, bool hasReference)
{
    SumBand(spectrumSamples);
    UpdateBandAverage(secondsSinceLastFrame, frame, hasReference);
}

auto Loudness::CurrentRelative() const -> float
{
    return m_currentRelative;
}

auto Loudness::AverageRelative() const -> float
{
    return m_averageRelative;
}

void Loudness::SumBand(const std::array<float, SpectrumSamples>& spectrumSamples)
{
    int start = SpectrumSamples * static_cast<int>(m_band) / 6;
    int end = SpectrumSamples * (static_cast<int>(m_band) + 1) / 6;

    m_current = 0.0f;
    for (int sample = start; sample < end; sample++)
    {
        m_current += spectrumSamples[sample];
    }
}

void Loudness::UpdateBandAverage(double secondsSinceLastFrame, uint32_t frame, bool hasReference)
{
    float rate = AdjustRateToFps(m_current > m_average ? 0.2f : 0.5f, secondsSinceLastFrame);
    m_average = m_average * rate + m_current * (1.0f - rate);

    rate = AdjustRateToFps(frame < 50 ? 0.9f : 0.992f, secondsSinceLastFrame);
    m_longAverage = m_longAverage * rate + m_current * (1.0f - rate);

    // With no long-term reference yet, the relative level reads 1.0 - "an
    // average amount of sound" - and NOT 0.
    //
    // This was briefly changed to 0 on silence, on the reasoning that reporting
    // full scale with nothing playing is absurd and made presets that integrate
    // their audio drift for ever at launch. MilkDrop 3 says otherwise, and a
    // preset settles it: "the glass bead game 001" scales its four little
    // lights by `rad = rad*mid_att`, so mid_att = 0 gives them a radius of zero
    // and they vanish - while in MilkDrop 3, with no music at all, those lights
    // are the ONLY thing moving on screen. 1.0 is what the reference engine
    // reports, so it is what a preset is written against.
    //
    // The cost is real and known: presets that accumulate audio into a variable
    // will drift at launch instead of standing still. That is apparently what
    // MilkDrop does too.
    // The decision is the CALLER's, taken once for the three bands together, and
    // that is the whole point: taken per band it is a discontinuity each band
    // crosses at its own moment. Presets normalise ACROSS the bands - "the glass
    // bead game 001" computes (bb-mn)/(mx-mn) - so a window where bass says 0
    // and mid/treb say 1 is not a small error, it is a FULL SCALE signal out of
    // nothing, and its accumulators (q26 = rotation, q27 = growth) then drift
    // for as long as the disagreement lasts. Measured: after a short burst of
    // audio the three long averages decay at their own rate (bass carries far
    // more energy than treble) and cross the 0.001 threshold several SECONDS
    // apart - which is exactly the reported "it was straight for a moment, then
    // it deformed", with nothing playing.
    m_currentRelative = hasReference ? m_current / m_longAverage : 1.0f;
    m_averageRelative = hasReference ? m_average / m_longAverage : 1.0f;
}

auto Loudness::AdjustRateToFps(float rate, double secondsSinceLastFrame) -> float
{
    float const perSecondDecayRateAtFps1 = std::pow(rate, 30.0f);
    float const perFrameDecayRateAtFps2 = std::pow(perSecondDecayRateAtFps1, static_cast<float>(secondsSinceLastFrame));

    return perFrameDecayRateAtFps2;
}

} // namespace Audio
} // namespace libprojectM
