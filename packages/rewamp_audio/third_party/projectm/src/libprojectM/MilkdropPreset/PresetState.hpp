/**
 * @file PresetState.hpp
 *
 * Declares a class that hold the variable states for a single preset.
 */
#pragma once

#include "Constants.hpp"

#include "AudioTexture.hpp"
#include "BlurTexture.hpp"

#include <Audio/FrameAudioData.hpp>

#include <Renderer/RenderContext.hpp>
#include <Renderer/Shader.hpp>
#include <Renderer/TextureSamplerDescriptor.hpp>

#include <projectm-eval.h>

#include <string>

namespace libprojectM {

class PresetFileParser;

namespace MilkdropPreset {


using BlendableFloat = float; //!< Currently a placeholder to mark blendable values.

/**
 * @brief Hold the current preset state and initial values.
 *
 * This is the base state class which is filled on preset load and updated between frames
 * to reflect the current state of rendering.
 */
class PresetState
{
public:
    PresetState();

    ~PresetState();

    /**
     * @brief Loads the initial values and code from the preset file.
     * @param parsedFile The file parser with the preset data.
     */
    void Initialize(::libprojectM::PresetFileParser& parsedFile);

    /**
     * @brief Loads or compiles the generic shaders.
     * Call after setting renderContext.
     */
    void LoadShaders();

    BlendableFloat gammaAdj{2.0f};
    BlendableFloat videoEchoZoom{2.0f};
    BlendableFloat videoEchoAlpha{0.0f};
    BlendableFloat videoEchoAlphaOld{0.0f};
    int videoEchoOrientation{0};
    int videoEchoOrientationOld{0};

    BlendableFloat decay{0.98f};

    int waveMode{0};
    int oldWaveMode{-1};
    bool additiveWaves{false};
    BlendableFloat waveAlpha{0.8f};
    BlendableFloat waveScale{1.0f};
    BlendableFloat waveSmoothing{0.75f};
    bool waveDots{false};
    bool waveThick{false};
    BlendableFloat waveParam{0.0f};
    bool modWaveAlphaByvolume{false};
    BlendableFloat modWaveAlphaStart{0.75f};
    BlendableFloat modWaveAlphaEnd{0.95f};
    float warpAnimSpeed{1.0f};
    BlendableFloat warpScale{1.0f};
    BlendableFloat zoomExponent{1.0f};
    BlendableFloat shader{0.0f};
    bool maximizeWaveColor{true};
    bool texWrap{true};
    bool darkenCenter{false};
    bool redBlueStereo{false};
    bool brighten{false};
    bool darken{false};
    bool solarize{false};
    bool invert{false};

    BlendableFloat zoom{1.0f};
    BlendableFloat rot{0.0f};
    BlendableFloat rotCX{0.5f};
    BlendableFloat rotCY{0.5f};
    BlendableFloat xPush{0.0f};
    BlendableFloat yPush{0.0f};
    BlendableFloat warpAmount{1.0f};
    BlendableFloat stretchX{1.0f};
    BlendableFloat stretchY{1.0f};
    BlendableFloat waveR{1.0f};
    BlendableFloat waveG{1.0f};
    BlendableFloat waveB{1.0f};
    BlendableFloat waveX{0.5f};
    BlendableFloat waveY{0.5f};
    BlendableFloat outerBorderSize{0.01f};
    BlendableFloat outerBorderR{0.0f};
    BlendableFloat outerBorderG{0.0f};
    BlendableFloat outerBorderB{0.0f};
    BlendableFloat outerBorderA{0.0f};
    BlendableFloat innerBorderSize{0.01f};
    BlendableFloat innerBorderR{0.25f};
    BlendableFloat innerBorderG{0.25f};
    BlendableFloat innerBorderB{0.25f};
    BlendableFloat innerBorderA{0.0f};
    BlendableFloat mvX{12.0f};
    BlendableFloat mvY{9.0f};
    BlendableFloat mvDX{0.0f};
    BlendableFloat mvDY{0.0f};
    BlendableFloat mvL{0.9f};
    BlendableFloat mvR{1.0f};
    BlendableFloat mvG{1.0f};
    BlendableFloat mvB{1.0f};
    BlendableFloat mvA{0.0f};
    BlendableFloat blur1Min{0.0f};
    BlendableFloat blur2Min{0.0f};
    BlendableFloat blur3Min{0.0f};
    BlendableFloat blur1Max{1.0f};
    BlendableFloat blur2Max{1.0f};
    BlendableFloat blur3Max{1.0f};
    BlendableFloat blur1EdgeDarken{0.25f};

    float fftAttack{0.5f}; //!< FFTAttack: rise smoothing of the get_fft() spectrum.
    float fftDecay{0.7f};  //!< FFTDecay: fall smoothing of the get_fft() spectrum and peak hold time.

    int presetVersion{100};        //!< Value of MILKDROP_PRESET_VERSION in preset files.
    int warpShaderVersion{2};      //!< PSVERSION or PSVERSION_WARP.
    int compositeShaderVersion{2}; //!< PSVERSION or PSVERSION_COMP.

    std::array<float, 4> hueRandomOffsets; //!< Per-preset constant offsets for the hue animation

    projectm_eval_mem_buffer globalMemory{nullptr};  //!< gmegabuf data. Using per-frame buffers in projectM to reduce interference.
    double globalRegisters[100]{};                   //!< Global reg00-reg99 variables.
    std::array<double, QVarCount> frameQVariables{}; //!< Q variables after per-frame code evaluation.

    libprojectM::Audio::FrameAudioData audioData; //!< Holds audio/spectrum data and values for beat detection.
    Renderer::RenderContext renderContext;        //!< Current renderer state data like viewport size and generic shaders.

    std::string perFrameInitCode; //!< Preset init code, run once on load.
    std::string perFrameCode;     //!< Preset per-frame code, run once at the start of each frame.
    std::string perPixelCode;     //!< Preset per-pixel/per-vertex code, run once per warp mesh vertex.

    std::array<std::string, CustomWaveformCount> customWaveInitCode;     //!< Custom wave init code, run once on load.
    std::array<std::string, CustomWaveformCount> customWavePerFrameCode; //!< Custom wave per-frame code, run once after the per-frame code.
    std::array<std::string, CustomWaveformCount> customWavePerPointCode; //!< Custom wave per-point code, run once per waveform vertex.

    std::array<std::string, CustomShapeCount> customShapeInitCode;     //!< Custom shape init code, run once on load.
    std::array<std::string, CustomShapeCount> customShapePerFrameCode; //!< Custom shape per-frame code, run once per shape instance.

    /** Preset name, used ONLY to label shader-compile errors. hlslparser formats
     * them as "<file>(<line>) : ...", and the file was passed empty, so a parse
     * failure printed a bare "(3) : Syntax error" with nothing tying it to a
     * preset - while the loader logs interleave, so the preset named on the line
     * above is not necessarily the culprit. That cost two investigations. */
    std::string presetName;
    std::string warpShader;      //!< Warp shader code.
    std::string compositeShader; //!< Composite shader code.
    //! Precompiled program names, handed to the app so a preset switch can skip
    //! the ~350 ms compile. MUST start at zero: they are only ever assigned when
    //! the preset HAS a custom shader AND it compiled, so a classic shader-less
    //! preset - or a shader that threw - used to hand back stack garbage, which
    //! the caller's "did the preload produce programs?" test reads as success
    //! and installs as a program name. The symptom is non-deterministic by
    //! construction; it showed up as a failure count that changed run to run
    //! over the SAME 40 presets.
    uint32_t warpP{0}, compP{0};
    
    std::string preCwarpShader;      //!< Warp shader code.
    std::string preCcompositeShader; //!< Composite shader code.
    
    std::weak_ptr<Renderer::Shader> untexturedShader; //!< Shader used to draw untextured primitives, e.g. waveforms.
    std::weak_ptr<Renderer::Shader> texturedShader;   //!< Shader used to draw textured primitives, e.g. textured shapes and the warp mesh.
    std::weak_ptr<Renderer::Shader> untexturedBorderedShader; //!< Shader used to draw untextured primitives, e.g. waveforms.
    std::weak_ptr<Renderer::Shader> texturedBorderedShader;   //!< Shader used to draw textured primitives, e.g. textured shapes and the warp mesh.
    
    
    std::weak_ptr<Renderer::Texture> mainTexture; //!< A weak reference to the main texture in the preset framebuffer.
    BlurTexture blurTexture;                      //!< The blur textures used in this preset. Contents depend on the shader code using GetBlurX().
    AudioTexture audioTexture;                    //!< Spectrum/waveform textures, only allocated if the shaders use get_fft()/get_wave().

    std::map<int, Renderer::TextureSamplerDescriptor> randomTextureDescriptors; //!< Descriptors for random texture IDs. Should be the same across both warp and comp shaders.

    //! Seed for the randNN draws, handed over by the preload worker (0 = draw
    //! freshly, as MilkDrop does).
    uint64_t randomSeed{0};
    //! randNN slot -> texture file the preload worker already resolved AND
    //! warmed into the texture cache. Authoritative when present: the seed alone
    //! would NOT be enough, because the scanned file list includes the current
    //! preset's directory and the worker deliberately never switches it (that
    //! would purge textures the in-flight frame is sampling), so the two sides
    //! can draw from lists of different sizes.
    std::map<int, std::string> randomTextureFiles;

    static const glm::mat4 orthogonalProjection;        //!< Projection matrix that transforms DirectX screen-space coordinates into the OpenGL coordinate frame.
    static const glm::mat4 orthogonalProjectionFlipped; //!< Projection matrix that transforms DirectX screen-space coordinates into the OpenGL coordinate frame.
};

} // namespace MilkdropPreset
} // namespace libprojectM
