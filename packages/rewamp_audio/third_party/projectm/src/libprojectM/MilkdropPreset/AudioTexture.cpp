#include "AudioTexture.hpp"

#include <algorithm>
#include <cmath>

namespace libprojectM {
namespace MilkdropPreset {

namespace {

// Level shaping follows Milkwave rather than BeatDrop. BeatDrop divides the spectrum by
// its own RMS, which is an auto-gain: on peaky material (chip music, where a handful of
// harmonics carry everything) the loud bins land far above 1.0, and presets are written
// against a 0..1 range - "Cosmic Iris EQ" turns its core into a floodlight as soon as
// get_fft(0.04) passes 1.67, because that flips the sign of an exp() exponent. Milkwave
// uses a fixed scale plus a pink-noise tilt instead, and that is the rendering the
// preset authors check their work against.
constexpr float FftNoiseGate = 5e-5f;       //!< Raw values below this are window sidelobes.
constexpr float FftVisibleFloor = 2.5e-4f;  //!< Smoothed values below this snap to zero.
constexpr float PeakHoldSeconds = 0.5f;     //!< How long a peak is held before it falls.
constexpr float PeakFallTau = 0.3f;         //!< Peak fall time constant after the hold.

// Fixed output gain. Calibrated with scripts/projectm/pm_fft_levels.cpp so that a
// full-scale sine reads get_fft() == 1.0 in its own band: that is the natural ceiling for
// presets, which treat 1.0 as "this band is as loud as it gets". Depends on the FFT size
// and on MilkdropFFT's (unnormalized) magnitudes, so re-measure if either changes.
constexpr float FftScaling = 6.5e-5f;

// Pink-noise compensation: +3 dB/octave normalized to 1.0 at 1 kHz. Music rolls off as
// 1/f, so without this the top half of the spectrum reads as silence - a "full-range EQ"
// preset then shows bass only.
constexpr float PinkReferenceBin = 1000.0f * static_cast<float>(AudioTexture::FftBins) / 22050.0f;

// High bins fluctuate more from frame to frame (fewer periods per window), so they get
// progressively more temporal smoothing to appear as steady as the low ones.
constexpr float HighFreqBinLow = 4000.0f * static_cast<float>(AudioTexture::FftBins) / 22050.0f;
constexpr float HighFreqBinHigh = 16000.0f * static_cast<float>(AudioTexture::FftBins) / 22050.0f;

// The two texture rows are sampled at 0.25 and 0.75, so both rows are hit dead center
// even with a bilinear sampler.
constexpr int TextureRows = 2;

} // namespace

auto AudioTexture::GetDescriptor(const std::string& name) -> Renderer::TextureSamplerDescriptor
{
    if (!m_sampler)
    {
        m_sampler = std::make_shared<Renderer::Sampler>(GL_CLAMP_TO_EDGE, GL_LINEAR);
    }

    if (name == "fft")
    {
        if (!m_fftTexture)
        {
            // GL_R16F rather than GL_R32F: 32-bit float textures are not filterable in
            // OpenGL ES 3.0 without OES_texture_float_linear, and a linear filter is what
            // interpolates between bins for free.
            m_fftTexture = std::make_shared<Renderer::Texture>("fft", m_fftPixels.data(), GL_TEXTURE_2D,
                                                               FftBins, TextureRows, 0,
                                                               GL_R16F, GL_RED, GL_FLOAT, false);
        }
        return {m_fftTexture, m_sampler, "fft", "fft"};
    }

    if (name == "wave")
    {
        if (!m_waveTexture)
        {
            m_waveTexture = std::make_shared<Renderer::Texture>("wave", m_wavePixels.data(), GL_TEXTURE_2D,
                                                                WaveSamples, TextureRows, 0,
                                                                GL_R16F, GL_RED, GL_FLOAT, false);
        }
        return {m_waveTexture, m_sampler, "wave", "wave"};
    }

    return {};
}

void AudioTexture::Update(const libprojectM::Audio::FrameAudioData& audioData,
                          double secondsSinceLastFrame,
                          float attack,
                          float decay)
{
    auto frameTime = static_cast<float>(secondsSinceLastFrame);
    if (!(frameTime > 0.0f) || frameTime > 1.0f)
    {
        frameTime = 1.0f / 60.0f;
    }

    if (m_fftTexture)
    {
        UpdateSpectrum(audioData, frameTime, attack, decay);
        m_fftTexture->Update(m_fftPixels.data());
    }

    if (m_waveTexture)
    {
        UpdateWaveform(audioData);
        m_waveTexture->Update(m_wavePixels.data());
    }
}

void AudioTexture::UpdateSpectrum(const libprojectM::Audio::FrameAudioData& audioData,
                                  float secondsSinceLastFrame,
                                  float attack,
                                  float decay)
{
    // The un-equalized spectrum is used here on purpose: the equalized one used for beat
    // detection zeroes the lowest bin and heavily tilts the low end, which turns any
    // full-range EQ preset into a treble-only display.
    const auto& left = audioData.shaderSpectrumLeft;
    const auto& right = audioData.shaderSpectrumRight;

    // Smoothing coefficients, made frame rate independent against a 60 fps reference.
    attack = std::min(std::max(attack, 0.0f), 1.0f);
    decay = std::min(std::max(decay, 0.0f), 1.0f);
    const float decayFactor = (1.0f - decay) * (1.0f - decay) * 0.75f;
    const float frames60 = secondsSinceLastFrame * 60.0f;
    const float decayPerFrame = 1.0f - std::pow(1.0f - decayFactor, frames60);

    const float peakFall = std::exp(-secondsSinceLastFrame / PeakFallTau);

    for (int bin = 0; bin < FftBins; bin++)
    {
        float mono = (left[bin] + right[bin]) * 0.5f * FftScaling;
        if (mono < FftNoiseGate)
        {
            mono = 0.0f;
        }
        mono *= std::sqrt(static_cast<float>(bin + 1) / PinkReferenceBin);

        const float highBlend = std::min(std::max((static_cast<float>(bin) - HighFreqBinLow) /
                                                      (HighFreqBinHigh - HighFreqBinLow),
                                                  0.0f),
                                         1.0f);
        const float effectiveAttack = attack * (0.7f - 0.2f * highBlend);
        const float attackPerFrame = 1.0f - std::pow(1.0f - effectiveAttack, frames60);

        const float coefficient = (mono > m_smoothed[bin]) ? attackPerFrame : decayPerFrame;
        m_smoothed[bin] += (mono - m_smoothed[bin]) * coefficient;
        if (m_smoothed[bin] < FftVisibleFloor)
        {
            m_smoothed[bin] = 0.0f;
        }

        // Peak hold: latch the maximum, hold it, then let it fall smoothly.
        if (m_smoothed[bin] >= m_peak[bin])
        {
            m_peak[bin] = m_smoothed[bin];
            m_peakHold[bin] = PeakHoldSeconds;
        }
        else if (m_peakHold[bin] > 0.0f)
        {
            m_peakHold[bin] -= secondsSinceLastFrame;
        }
        else
        {
            m_peak[bin] *= peakFall;
            if (m_peak[bin] < FftVisibleFloor)
            {
                m_peak[bin] = 0.0f;
            }
        }

        m_fftPixels[bin] = m_smoothed[bin];
        m_fftPixels[FftBins + bin] = m_peak[bin];
    }
}

void AudioTexture::UpdateWaveform(const libprojectM::Audio::FrameAudioData& audioData)
{
    for (int sample = 0; sample < WaveSamples; sample++)
    {
        m_wavePixels[sample] = audioData.waveformLeft[sample];
        m_wavePixels[WaveSamples + sample] = audioData.waveformRight[sample];
    }
}

} // namespace MilkdropPreset
} // namespace libprojectM
