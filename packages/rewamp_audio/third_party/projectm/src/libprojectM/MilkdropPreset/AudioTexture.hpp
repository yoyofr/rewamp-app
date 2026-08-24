/**
 * @file AudioTexture.hpp
 * @brief Spectrum and waveform data exposed to preset shaders as textures.
 *
 * Implements the MilkDrop3/BeatDrop shader audio functions (get_fft(), get_fft_peak(),
 * get_wave() and friends). Two small textures are filled once per frame:
 *
 *  - "fft":  SpectrumSamples x 2, row 0 = smoothed magnitude, row 1 = peak hold.
 *  - "wave": WaveformSamples x 2, row 0 = left channel, row 1 = right channel.
 *
 * Both are only allocated if the preset actually references them, so presets which
 * don't use the audio functions pay nothing.
 */
#pragma once

#include <Audio/AudioConstants.hpp>
#include <Audio/FrameAudioData.hpp>

#include <Renderer/Sampler.hpp>
#include <Renderer/Texture.hpp>
#include <Renderer/TextureSamplerDescriptor.hpp>

#include <array>
#include <memory>
#include <string>

namespace libprojectM {
namespace MilkdropPreset {

/**
 * @brief Holds the per-preset audio textures used by the shader audio functions.
 */
class AudioTexture
{
public:
    static constexpr int FftBins = libprojectM::Audio::SpectrumSamples;       //!< Number of spectrum bins in the "fft" texture.
    static constexpr int WaveSamples = libprojectM::Audio::WaveformSamples;   //!< Number of samples in the "wave" texture.

    /**
     * @brief Returns a descriptor for the given audio texture, allocating it on first use.
     * @param name Either "fft" or "wave".
     * @return A descriptor with the texture and a clamped, bilinear sampler.
     */
    auto GetDescriptor(const std::string& name) -> Renderer::TextureSamplerDescriptor;

    /**
     * @brief Uploads the current frame's audio data into the allocated textures.
     * Does nothing for textures which were never requested by a shader.
     * @param audioData The current frame's audio data.
     * @param secondsSinceLastFrame Frame time, used to keep smoothing frame rate independent.
     * @param attack Preset FFTAttack value (0..1).
     * @param decay Preset FFTDecay value (0..1).
     */
    void Update(const libprojectM::Audio::FrameAudioData& audioData,
                double secondsSinceLastFrame,
                float attack,
                float decay);

    /**
     * @brief Computes the smoothed spectrum and peak hold into the staging buffer.
     * Public so the offline oracle (scripts/projectm/pm_fft_levels.cpp) can measure the
     * exact values get_fft() will return, without a GL context.
     */
    void UpdateSpectrum(const libprojectM::Audio::FrameAudioData& audioData,
                        float secondsSinceLastFrame,
                        float attack,
                        float decay);

    /**
     * @brief Returns the staging buffer holding the spectrum texture contents.
     * Row 0 is the smoothed spectrum, row 1 the peak hold. Values are linear; get_fft()
     * returns their square root.
     */
    auto SpectrumPixels() const -> const std::array<float, FftBins * 2>& { return m_fftPixels; }

private:
    void UpdateWaveform(const libprojectM::Audio::FrameAudioData& audioData);

    std::shared_ptr<Renderer::Sampler> m_sampler;     //!< Clamped, bilinear sampler shared by both textures.
    std::shared_ptr<Renderer::Texture> m_fftTexture;  //!< The spectrum texture, if requested by a shader.
    std::shared_ptr<Renderer::Texture> m_waveTexture; //!< The waveform texture, if requested by a shader.

    std::array<float, FftBins> m_smoothed{};   //!< Attack/decay smoothed spectrum.
    std::array<float, FftBins> m_peak{};       //!< Peak hold values.
    std::array<float, FftBins> m_peakHold{};   //!< Remaining hold time per bin, in seconds.

    std::array<float, FftBins * 2> m_fftPixels{};        //!< Staging buffer for the spectrum texture.
    std::array<float, WaveSamples * 2> m_wavePixels{};   //!< Staging buffer for the waveform texture.
};

} // namespace MilkdropPreset
} // namespace libprojectM
