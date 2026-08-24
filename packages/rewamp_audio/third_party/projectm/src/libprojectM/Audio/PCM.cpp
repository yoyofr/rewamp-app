#include "PCM.hpp"

#include <algorithm>
#include <cmath>

namespace libprojectM {
namespace Audio {

template<
    int signalAmplitude,
    int signalOffset,
    typename SampleType>
void PCM::AddToBuffer(
    SampleType const* const samples,
    uint32_t channels,
    size_t const sampleCount)
{
    if (channels == 0 || sampleCount == 0)
    {
        return;
    }

    for (size_t i = 0; i < sampleCount; i++)
    {
        size_t const bufferOffset = (m_start + i) % AudioBufferSamples;
        m_inputBufferL[bufferOffset] = 128.0f * (static_cast<float>(samples[0 + i * channels]) - float(signalOffset)) / float(signalAmplitude);
        if (channels > 1)
        {
            m_inputBufferR[bufferOffset] = 128.0f * (static_cast<float>(samples[1 + i * channels]) - float(signalOffset)) / float(signalAmplitude);
        }
        else
        {
            m_inputBufferR[bufferOffset] = m_inputBufferL[bufferOffset];
        }
    }
    m_start = (m_start + sampleCount) % AudioBufferSamples;
}

void PCM::Add(float const* const samples, uint32_t channels, size_t const count)
{
    AddToBuffer<1, 0>(samples, channels, count);
}
void PCM::Add(uint8_t const* const samples, uint32_t channels, size_t const count)
{
    AddToBuffer<128, 128>(samples, channels, count);
}
void PCM::Add(int16_t const* const samples, uint32_t channels, size_t const count)
{
    AddToBuffer<32768, 0>(samples, channels, count);
}

void PCM::UpdateFrameAudioData(double secondsSinceLastFrame, uint32_t frame)
{
    // 1. Copy audio data from input buffer
    CopyNewWaveformData(m_inputBufferL, m_waveformL);
    CopyNewWaveformData(m_inputBufferR, m_waveformR);

    // 2. Update spectrum analyzer data for both channels
    UpdateSpectrum(m_fft, m_waveformL, m_spectrumL);
    UpdateSpectrum(m_fft, m_waveformR, m_spectrumR);

    // 2b. Same again without the equalizer curve, for the get_fft() shader functions.
    UpdateSpectrum(m_shaderFft, m_waveformL, m_shaderSpectrumL);
    UpdateSpectrum(m_shaderFft, m_waveformR, m_shaderSpectrumR);

    // 3. Align waveforms
    m_alignL.Align(m_waveformL);
    m_alignR.Align(m_waveformR);

    // 4. Update beat detection values
    // ONE decision for the three bands: does a long-term reference exist at all?
    // Taken per band it is a threshold each crosses at its own moment - bass
    // holds far more energy than treble, so after a short burst of audio their
    // long averages cross 0.001 several SECONDS apart, and in between the bands
    // report wildly different relative levels with nothing playing. Presets
    // normalise across the bands, so that gap comes out as a full-scale signal.
    // The loudest band decides for all: as long as ANY band still has a
    // reference, none of them is allowed to claim it has none.
    const float longest = std::max({m_bass.LongAverage(),
                                    m_middles.LongAverage(),
                                    m_treble.LongAverage()});
    const bool hasReference = std::fabs(longest) >= 0.001f;

    m_bass.Update(m_spectrumL, secondsSinceLastFrame, frame, hasReference);
    m_middles.Update(m_spectrumL, secondsSinceLastFrame, frame, hasReference);
    m_treble.Update(m_spectrumL, secondsSinceLastFrame, frame, hasReference);

}

auto PCM::GetFrameAudioData() const -> FrameAudioData
{
    FrameAudioData data{};

    std::copy(m_waveformL.begin(), m_waveformL.begin() + WaveformSamples, data.waveformLeft.begin());
    std::copy(m_waveformR.begin(), m_waveformR.begin() + WaveformSamples, data.waveformRight.begin());
    std::copy(m_spectrumL.begin(), m_spectrumL.begin() + SpectrumSamples, data.spectrumLeft.begin());
    std::copy(m_spectrumR.begin(), m_spectrumR.begin() + SpectrumSamples, data.spectrumRight.begin());
    std::copy(m_shaderSpectrumL.begin(), m_shaderSpectrumL.begin() + SpectrumSamples, data.shaderSpectrumLeft.begin());
    std::copy(m_shaderSpectrumR.begin(), m_shaderSpectrumR.begin() + SpectrumSamples, data.shaderSpectrumRight.begin());

    data.bass = m_bass.CurrentRelative();
    data.mid = m_middles.CurrentRelative();
    data.treb = m_treble.CurrentRelative();

    data.bassAtt = m_bass.AverageRelative();
    data.midAtt = m_middles.AverageRelative();
    data.trebAtt = m_treble.AverageRelative();
    
    data.vol = (data.bass + data.mid + data.treb) * 0.333f;
    data.volAtt = (data.bassAtt + data.midAtt + data.trebAtt) * 0.333f;

    return data;
}

void PCM::UpdateSpectrum(MilkdropFFT& fft, const WaveformBuffer& waveformData, SpectrumBuffer& spectrumData)
{
    std::vector<float> waveformSamples(AudioBufferSamples);
    std::vector<float> spectrumValues;

    size_t oldI{0};
    for (size_t i = 0; i < AudioBufferSamples; i++)
    {
        // Damp the input into the FFT a bit, to reduce high-frequency noise:
        waveformSamples[i] = 0.5f * (waveformData[i] + waveformData[oldI]);
        oldI = i;
    }

    fft.TimeToFrequencyDomain(waveformSamples, spectrumValues);

    std::copy(spectrumValues.begin(), spectrumValues.end(), spectrumData.begin());
}

void PCM::CopyNewWaveformData(const WaveformBuffer& source, WaveformBuffer& destination)
{
    auto const bufferStartIndex = m_start.load();

    for (size_t i = 0; i < AudioBufferSamples; i++)
    {
        destination[i] = source[(bufferStartIndex + i) % AudioBufferSamples];
    }
}


} // namespace Audio
} // namespace libprojectM
