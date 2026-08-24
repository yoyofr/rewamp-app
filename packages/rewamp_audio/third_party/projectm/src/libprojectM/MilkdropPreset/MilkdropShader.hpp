/**
 * @file MilkdropShader
 * @brief Holds a warp or composite shader of Milkdrop presets.
 *
 * This class wraps the conversion from HLSL shader code to GLSL and also manages the
 * drawing.
 */
#pragma once

#include "BlurTexture.hpp"

#include <Renderer/Shader.hpp>
#include <Renderer/TextureManager.hpp>
#include "AltPresetState.hpp"

#include <array>
#include <set>

namespace libprojectM {
namespace MilkdropPreset {

class PerFrameContext;
class PresetState;
class AltPresetState;

/**
 * @brief Holds a warp or composite shader of Milkdrop presets.
 * Also does the required shader translation from HLSL to GLSL using hlslparser.
 */
class MilkdropShader
{
public:
    enum class ShaderType
    {
        WarpShader,     //!< Warp shader
        CompositeShader //!< Composite shader
    };

    /**
     * constructor.
     * @param type The preset shader type.
     */
    explicit MilkdropShader(ShaderType type);

    /**
     * @brief Translates and compiles the shader code.
     * @param presetShaderCode The preset shader code.
     */
    void LoadCode(const std::string& presetShaderCode);

    /**
     * @brief Loads the required texture references into the shader.
     * Binds the underlying shader program.
     * @param presetState The preset state to pull the values and textures from.
     */
    void LoadTexturesAndCompile(PresetState& presetState,uint32_t shaderP=NULL);
    void PreLoadTexturesAndCompile(AltPresetState& presetState);

    /**
     * @brief Derives the draw seed of one randNN slot from the preset's seed.
     * @param presetSeed 0 = no seed, i.e. keep MilkDrop's per-load random draw.
     * @param slot The randNN slot, 0-15.
     * @return A non-zero seed, or 0 when presetSeed is 0.
     */
    static uint64_t RandomSlotSeed(uint64_t presetSeed, int slot);

    /**
     * @brief Resolves the texture behind a randNN sampler.
     *
     * Prefers the file the preload worker already resolved and warmed for this
     * slot; falls back to a seeded draw, then to a fresh one. The returned
     * descriptor always carries the PRESET's sampler name, never the file's.
     */
    static Renderer::TextureSamplerDescriptor ResolveRandomTexture(
        Renderer::TextureManager* textureManager,
        const std::string& samplerName,
        int slot,
        uint64_t presetSeed,
        const std::map<int, std::string>& resolvedFiles);

    /**
     * @brief Loads all required shader variables into the uniforms.
     * Binds the underlying shader program.
     * @param presetState The preset state to pull the values from.
     * @param perFrameContext The per-frame context with dynamically calculated values.
     */
    void LoadVariables(const PresetState& presetState, const PerFrameContext& perFrameContext);

    /**
     * @brief Returns the contained shader.
     * @return The shader program wrapper.
     */
    auto Shader() -> Renderer::Shader&;
    
    std::string m_convertedCode;
    GLuint m_shaderP;

private:
    /**
     * @brief Prepares the shader code to be translated into GLSL.
     * @param program The program code to work on.
     */
    void PreprocessPresetShader(std::string& program);

    /**
     * @brief Searches for sampler references in the program and stores them in m_samplerNames.
     * @param program The program code to work on.
     */
    void GetReferencedSamplers(const std::string& program);

    /**
     * @brief Rewrites bare sampler declarations to the "sampler_" convention.
     * Milkdrop accepts "sampler MyTexture;" with uses to match; everything here
     * keys on the prefix.
     * @param program The program code to work on.
     */
    void NormalizeSamplerNames(std::string& program);

    /**
     * @brief Translates the HLSL shader into GLSL.
     * @param presetState The preset state to pull the blur textures from.
     * @param program The shader to transpile.
     */
    void TranspileHLSLShader(const PresetState& presetState, std::string& program,uint32_t shaderP=0);
    void TranspileHLSLShaderPreCompilation(const AltPresetState& presetState, std::string& program);
    void StringReplaceAll(std::string& s, const std::string& from, const std::string& to);
    /**
     * @brief Updates the requested blur level if higher than before.
     * Also adds the required samplers.
     * @param requestedLevel The requested blur level.
     */
    void UpdateMaxBlurLevel(BlurTexture::BlurLevel requestedLevel);

    /**
     * @brief Returns the HLSL declarations of the audio shader functions used by this shader.
     * Empty if the shader uses neither the get_fft() nor the get_wave() family.
     */
    auto AudioFunctionDeclarations() const -> std::string;

    ShaderType m_type{ShaderType::WarpShader}; //!< Type of this shader.
    std::string m_fragmentShaderCode;          //!< The original preset fragment shader code.
    std::string m_preprocessedCode;            //!< The preprocessed preset shader code.

    
    
    std::set<std::string> m_samplerNames;                                        //!< All sampler names referenced in the shader code.
    std::vector<Renderer::TextureSamplerDescriptor> m_mainTextureDescriptors;              //!< Descriptors for all main texture references.
    std::vector<Renderer::TextureSamplerDescriptor> m_textureSamplerDescriptors;           //!< Descriptors of all referenced samplers in the shader code.
    BlurTexture::BlurLevel m_maxBlurLevelRequired{BlurTexture::BlurLevel::None}; //!< Max blur level of main texture required by this shader.
    bool m_usesFftTexture{false};                                                //!< true if the shader calls get_fft()/get_fft_peak()/…
    bool m_usesWaveTexture{false};                                               //!< true if the shader calls get_wave()/get_wave_left()/…

    std::array<float, 4> m_randValues{};               //!< Random values which don't change every frame.
    std::array<glm::vec3, 20> m_randTranslation{};     //!< Random translation vectors which don't change every frame.
    std::array<glm::vec3, 20> m_randRotationCenters{}; //!< Random rotation center vectors which don't change every frame.
    std::array<glm::vec3, 20> m_randRotationSpeeds{};  //!< Random rotation speeds which don't change every frame.

    Renderer::Shader m_shader;
};

} // namespace MilkdropPreset
} // namespace libprojectM
