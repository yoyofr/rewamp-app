#include "TransitionShaderManager.hpp"

#include "BuiltInTransitionsResources.hpp"

#include <iostream>

namespace libprojectM {
namespace Renderer {

TransitionShaderManager::TransitionShaderManager()
    : m_transitionShaders({CompileTransitionShader(kTransitionShaderBuiltInCircleGlsl330),
                           CompileTransitionShader(kTransitionShaderBuiltInPlasmaGlsl330),
                           CompileTransitionShader(kTransitionShaderBuiltInSimpleBlendGlsl330),
                           CompileTransitionShader(kTransitionShaderBuiltInSweepGlsl330),
                           CompileTransitionShader(kTransitionShaderBuiltInWarpGlsl330),
                           CompileTransitionShader(kTransitionShaderBuiltInZoomBlurGlsl330),
                           // Ported from Milkwave's mask-based blend patterns
                           // (BSD-3). See the .frag files for the derivation.
                           CompileTransitionShader(kTransitionShaderMilkwaveClockGlsl330),
                           CompileTransitionShader(kTransitionShaderMilkwaveCornerGlsl330),
                           CompileTransitionShader(kTransitionShaderMilkwaveCheckerGlsl330),
                           CompileTransitionShader(kTransitionShaderMilkwaveSpiralGlsl330),
                           CompileTransitionShader(kTransitionShaderMilkwaveRhombusGlsl330),
                           CompileTransitionShader(kTransitionShaderMilkwaveNuclearClockGlsl330),
                           CompileTransitionShader(kTransitionShaderMilkwaveCrossGlsl330),
                           CompileTransitionShader(kTransitionShaderMilkwaveLinesGlsl330),
                           CompileTransitionShader(kTransitionShaderMilkwaveDonutsGlsl330),
                           CompileTransitionShader(kTransitionShaderMilkwaveBubblesGlsl330),
                           CompileTransitionShader(kTransitionShaderMilkwaveKaleidoscopeGlsl330),
                           CompileTransitionShader(kTransitionShaderMilkwaveMoebiusGlsl330),
                           CompileTransitionShader(kTransitionShaderMilkwaveStarsGlsl330),
                           CompileTransitionShader(kTransitionShaderMilkwaveDiscoFloorGlsl330),
                           CompileTransitionShader(kTransitionShaderMilkwaveFireGlsl330),
                           CompileTransitionShader(kTransitionShaderMilkwaveDrainSwirlGlsl330),
                           CompileTransitionShader(kTransitionShaderMilkwaveJuliaGlsl330)})
    , m_mersenneTwister(m_randomDevice())
{
}

auto TransitionShaderManager::RandomTransition() -> std::shared_ptr<Shader>
{
    if (m_transitionShaders.empty())
    {
        return {};
    }

    // A pinned index is what makes a single pattern observable at all: without
    // it every transition is a fresh draw from the bag, so a newly written one
    // cannot be looked at on purpose - which is the difference between shipping
    // a shader and shipping a shader someone has seen.
    if (m_forcedIndex >= 0 && static_cast<size_t>(m_forcedIndex) < m_transitionShaders.size())
    {
        return m_transitionShaders.at(static_cast<size_t>(m_forcedIndex));
    }

    return m_transitionShaders.at(m_mersenneTwister() % m_transitionShaders.size());
}

void TransitionShaderManager::ForcedTransitionIndex(int index)
{
    m_forcedIndex = index;
}

auto TransitionShaderManager::TransitionCount() const -> int
{
    return static_cast<int>(m_transitionShaders.size());
}

auto TransitionShaderManager::ShaderPrograms() const -> std::vector<uint32_t>
{
    std::vector<uint32_t> programs;
    for (const auto& shader : m_transitionShaders)
    {
        if (shader && shader->ProgramId())
        {
            programs.push_back(shader->ProgramId());
        }
    }
    return programs;
}

auto TransitionShaderManager::CompileTransitionShader(const std::string& shaderBodyCode) -> std::shared_ptr<Shader>
{
#ifdef USE_GLES
    // GLES also requires a precision specifier for variables and 3D samplers
    constexpr char versionHeader[] = "#version 300 es\n\nprecision mediump float;\nprecision mediump sampler3D;\n";
#else
    constexpr char versionHeader[] = "#version 330\n\n";
#endif

    std::string fragmentShaderSource(static_cast<const char*>(versionHeader));
    fragmentShaderSource.append(kTransitionShaderHeaderGlsl330);
    fragmentShaderSource.append("\n");
    fragmentShaderSource.append(shaderBodyCode);
    fragmentShaderSource.append("\n");
    fragmentShaderSource.append(kTransitionShaderMainGlsl330);

    try
    {
        auto transitionShader = std::make_shared<Shader>();
        transitionShader->CompileProgram(static_cast<const char*>(versionHeader) + kTransitionVertexShaderGlsl330, fragmentShaderSource);
        return transitionShader;
    }
    catch (const ShaderException&)
    {
        // ToDo: Log proper shader compile error once logging API is in place
        return {};
    }
}

} // namespace Renderer
} // namespace libprojectM
