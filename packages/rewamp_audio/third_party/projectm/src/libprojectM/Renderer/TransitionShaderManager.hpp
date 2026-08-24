#pragma once

#include "Renderer/Shader.hpp"

#include <random>
#include <vector>

namespace libprojectM {
namespace Renderer {

/**
 * @brief Manages all available transition shaders.
 */
class TransitionShaderManager
{
public:
    TransitionShaderManager();

    /**
     * @brief Selects a random transition shader from the list.
     * @return A shared pointer to a transition shader.
     */
    auto RandomTransition() -> std::shared_ptr<Shader>;

    /**
     * @brief GL program ids of all compiled transition shaders (rewamp).
     *
     * There are only a handful and they are all compiled up-front in the
     * constructor, so the GL compile/link never costs anything at switch time —
     * but on ANGLE's Metal backend the pipeline state is still built at the
     * shader's FIRST DRAW, which lands in the middle of a transition. Handing
     * the ids out lets the preload worker warm them once, off the render thread.
     */
    auto ShaderPrograms() const -> std::vector<uint32_t>;

    /**
     * @brief Pins the transition to one index, or -1 to draw at random.
     */
    void ForcedTransitionIndex(int index);

    /**
     * @brief Number of available transitions.
     */
    auto TransitionCount() const -> int;

private:
    /**
     * @brief Compiles a single transition shader program.
     * @param shaderBodyCode The mainImage() fragment shader code, without any headers etc.
     */
    static auto CompileTransitionShader(const std::string& shaderBodyCode) -> std::shared_ptr<Shader>;

    std::vector<std::shared_ptr<Shader>> m_transitionShaders; //!< Currently loaded and compiled transition shaders.

    int m_forcedIndex{-1}; //!< Pinned transition index, -1 = pick at random.

    std::random_device m_randomDevice; //!< Seed for the random number generator
    std::mt19937 m_mersenneTwister; //!< Random engine to select shader
};

} // namespace Renderer
} // namespace libprojectM
