//#define MILKDROP_PRESET_DEBUG_ADDITIONNAL

#include "MilkdropShader.hpp"

#include "PerFrameContext.hpp"
#include "PresetState.hpp"
#include "Utils.hpp"

#include <MilkdropStaticShaders.hpp>

#include <GLSLGenerator.h>
#include <HLSLParser.h>
#include <iostream>

#include "ShaderPreprocessor.h" //YOYOFR

#include <glm/gtc/matrix_transform.hpp>
#include <glm/mat4x4.hpp>

#include <algorithm>
#include <atomic>
#include <ctime>
#include <regex>
#include <set>

namespace libprojectM {
namespace MilkdropPreset {

using libprojectM::MilkdropPreset::MilkdropStaticShaders;

static auto floatRand = []() { return static_cast<float>(rand() % 7381) / 7380.0f; };

// PM_DUMP_HLSL=<prefix> writes the HLSL handed to the transpiler to <prefix>.normal and
// <prefix>.precomp. The two paths MUST emit the same source or the precompiled program is
// built from something the render thread would never have written - and nothing detects
// that, the program links and gets used. The rule was broken twice in silence (blur
// samplers resolved as FILES, and a texsize named after the prefixed sampler), which is why
// checking it is worth an oracle rather than a reading. Inert unless the variable is set.
static void DumpTranspilerSource(const char* pathTag, const std::string& label, const std::string& source)
{
    const char* prefix = getenv("PM_DUMP_HLSL");
    if (prefix == nullptr)
    {
        return;
    }

    const std::string fileName = std::string(prefix) + "." + pathTag;
    FILE* file = fopen(fileName.c_str(), "a");
    if (file == nullptr)
    {
        return;
    }
    fprintf(file, "==== %s ====\n%s\n", label.c_str(), source.c_str());
    fclose(file);
}

// Pointer state for the MilkDrop3 "mouse" uniform. Pushed from outside the
// library (the host owns the surface and its input); (-1,-1) is the documented
// "pointer is outside the window" reading, which is also the resting state.
// Not file-static: the host setter below lives outside the namespace.
std::atomic<float> g_mouseX{-1.0f};
std::atomic<float> g_mouseY{-1.0f};
std::atomic<float> g_mouseHeld{0.0f};
std::atomic<float> g_mouseClicked{0.0f};

uint64_t MilkdropShader::RandomSlotSeed(uint64_t presetSeed, int slot)
{
    if (presetSeed == 0)
    {
        return 0; // Caller keeps MilkDrop's per-load draw.
    }
    // splitmix64 on (seed, slot): the 16 slots of one preset must not correlate,
    // and slot 0 must not collapse back onto the preset seed itself.
    uint64_t x = presetSeed + static_cast<uint64_t>(slot + 1) * 0x9E3779B97F4A7C15ULL;
    x = (x ^ (x >> 30)) * 0xBF58476D1CE4E5B9ULL;
    x = (x ^ (x >> 27)) * 0x94D049BB133111EBULL;
    x = x ^ (x >> 31);
    return x != 0 ? x : 1; // 0 means "no seed", so never return it.
}

Renderer::TextureSamplerDescriptor MilkdropShader::ResolveRandomTexture(
    Renderer::TextureManager* textureManager,
    const std::string& samplerName,
    int slot,
    uint64_t presetSeed,
    const std::map<int, std::string>& resolvedFiles)
{
    if (textureManager == nullptr)
    {
        return {};
    }

    // A file the preload already picked wins outright: it is the one that got
    // warmed, and re-drawing could land elsewhere (different scanned list).
    const auto it = resolvedFiles.find(slot);
    if (it != resolvedFiles.end() && !it->second.empty())
    {
        auto desc = textureManager->GetTexture(it->second);
        // Descriptor named after the PRESET's sampler, never the file.
        return {desc.Texture(), desc.Sampler(), samplerName, samplerName};
    }

    return textureManager->GetRandomTexture(samplerName, false,
                                            RandomSlotSeed(presetSeed, slot));
}

MilkdropShader::MilkdropShader(ShaderType type)
    : m_type(type)
    , m_randValues({floatRand(), floatRand(), floatRand(), floatRand()})
{
    unsigned int index = 0;
    do
    {
        for (int i = 0; i < 4; i++)
        {
            float const m_randTranslationMult = 1;
            float const rotMult = 0.9f * powf(index / 8.0f, 3.2f);
            m_randTranslation[index].x = (floatRand() * 2 - 1) * m_randTranslationMult;
            m_randTranslation[index].y = (floatRand() * 2 - 1) * m_randTranslationMult;
            m_randTranslation[index].z = (floatRand() * 2 - 1) * m_randTranslationMult;
            m_randRotationCenters[index].x = floatRand() * 6.28f;
            m_randRotationCenters[index].y = floatRand() * 6.28f;
            m_randRotationCenters[index].z = floatRand() * 6.28f;
            m_randRotationSpeeds[index].x = (floatRand() * 2 - 1) * rotMult;
            m_randRotationSpeeds[index].y = (floatRand() * 2 - 1) * rotMult;
            m_randRotationSpeeds[index].z = (floatRand() * 2 - 1) * rotMult;
            index++;
        }
    } while (index < sizeof(m_randTranslation) / sizeof(m_randTranslation[0]));
}

void MilkdropShader::LoadCode(const std::string& presetShaderCode)
{
    m_fragmentShaderCode = presetShaderCode;
    m_preprocessedCode = m_fragmentShaderCode;

    ShaderPreprocessor::normalizeSamplerNames(m_preprocessedCode);
    GetReferencedSamplers(m_preprocessedCode);
    PreprocessPresetShader(m_preprocessedCode);
}

void MilkdropShader::LoadTexturesAndCompile(PresetState& presetState,uint32_t shaderP)
{
    std::locale loc;
    
        // Now request the textures and descriptors from the texture manager.
        for (const auto& name : m_samplerNames)
        {
            std::string baseName = name;
            if (name.length() > 3 && name.at(2) == '_')
            {
                baseName = name.substr(3);
            }
            
            std::string lowerCaseName = Utils::ToLower(baseName);
            
            // The "main" and "blurX" textures are preset-specific and are not managed by TextureManager.
            if (lowerCaseName == "main")
            {
                Renderer::TextureSamplerDescriptor desc(presetState.mainTexture.lock(),
                                                        presetState.renderContext.textureManager->GetSampler(name),
                                                        name,
                                                        "main");
                m_mainTextureDescriptors.push_back(std::move(desc));
                continue;
            }

            // Audio data textures. Not files, and not managed by the texture manager -
            // they're filled from the current frame's audio data.
            if (lowerCaseName == "fft" || lowerCaseName == "wave")
            {
                m_textureSamplerDescriptors.push_back(presetState.audioTexture.GetDescriptor(lowerCaseName));
                continue;
            }

            // A few presets directly use the (undocumented) sampler name.
            if (lowerCaseName == "blur1")
            {
                UpdateMaxBlurLevel(BlurTexture::BlurLevel::Blur1);
                continue;
            }
            if (lowerCaseName == "blur2")
            {
                UpdateMaxBlurLevel(BlurTexture::BlurLevel::Blur2);
                continue;
            }
            if (lowerCaseName == "blur3")
            {
                UpdateMaxBlurLevel(BlurTexture::BlurLevel::Blur3);
                continue;
            }
            
            // Random textures need special treatment.
            if (lowerCaseName.length() >= 6 &&
                lowerCaseName.substr(0, 4) == "rand" && std::isdigit(lowerCaseName.at(4), loc) && std::isdigit(lowerCaseName.at(5), loc))
            {
                // First look up the random texture index in the preset state so the texture matches between warp and composite shaders
                int randomSlot = -1;
                try
                {
                    randomSlot = std::stoi(lowerCaseName.substr(4, 2));
                }
                catch (...) // Ignore any conversion errors.
                {
                }
                
                if (randomSlot >= 0 && randomSlot <= 15)
                {
                    if (presetState.randomTextureDescriptors.find(randomSlot) != presetState.randomTextureDescriptors.end())
                    {
                        // Use existing texture descriptor.
                        m_textureSamplerDescriptors.push_back(presetState.randomTextureDescriptors.at(randomSlot));
                        continue;
                    }

                    // Slot empty, request a new random texture - unless the
                    // preload worker already resolved AND warmed one for this
                    // slot, in which case that file IS the answer. Re-drawing
                    // from the seed would be wrong as often as not: the scanned
                    // file list includes the current preset's directory, and the
                    // worker never switches it (purging would evict textures the
                    // in-flight frame is sampling), so the two sides can draw
                    // from lists of different sizes. The descriptor is still
                    // built with the PRESET's name ("rand00"), never the file's -
                    // that is what once spliced a file name into a GLSL
                    // identifier.
                    auto desc = MilkdropShader::ResolveRandomTexture(
                        presetState.renderContext.textureManager, name, randomSlot,
                        presetState.randomSeed, presetState.randomTextureFiles);

                    // Also store a copy in preset state!
                    presetState.randomTextureDescriptors.insert({randomSlot, desc});
                    
                    m_textureSamplerDescriptors.push_back(std::move(desc));
                    continue;
                }
                
                // Fall through if slot number is out of range and treat as normal texture.
            }
            
            auto desc = presetState.renderContext.textureManager->GetTexture(name);
            /* What the shader will actually SAMPLE, on the render thread, for
             * real. "Loaded texture X" only says the file was found once; it
             * says nothing about the object this descriptor ends up holding,
             * and a preset whose whole output is one tex2D() renders BLACK,
             * silently, when that object is the 1x1 placeholder. Debug builds
             * only - this is the line that tells a device-only black screen
             * from a shader problem. */
#ifdef DEBUG
            {
                const auto tex = desc.Texture();
                std::cerr << "[preset texture] " << presetState.presetName
                          << " sampler_" << name
                          << " -> id " << (tex ? tex->TextureID() : 0)
                          << " name '" << (tex ? tex->Name() : std::string("<null>"))
                          << "'" << std::endl;
            }
#endif
            m_textureSamplerDescriptors.push_back(std::move(desc));
        }
    
    TranspileHLSLShader(presetState, m_preprocessedCode,shaderP);

    // Update blur texture level if shader was compiled successfully.
    presetState.blurTexture.SetRequiredBlurLevel(m_maxBlurLevelRequired);
}

void MilkdropShader::StringReplaceAll(std::string& s, const std::string& from, const std::string& to) {
    if (from.empty()) return;
    size_t startPos = 0;
    while ((startPos = s.find(from, startPos)) != std::string::npos) {
        s.replace(startPos, from.length(), to);
        startPos += to.length(); // advance past the replaced segment to avoid infinite loop
    }
}

void MilkdropShader::PreLoadTexturesAndCompile(AltPresetState& presetState)
{
    std::locale loc;
    
    // Now request the textures and descriptors from the texture manager.
    std::shared_ptr<Renderer::Sampler> m_dummySampler{std::make_shared<Renderer::Sampler>(GL_CLAMP_TO_EDGE, GL_LINEAR)}; //!< Sampler for preset textures. Uses bilinear
    std::shared_ptr<Renderer::Texture> m_dummyTexture{std::make_shared<Renderer::Texture>("dummy2D", 0, GL_TEXTURE_2D, 0, 0, true)}; //!< Sampler for preset
    std::shared_ptr<Renderer::Texture> m_dummyTexture3D{std::make_shared<Renderer::Texture>("dummy3D", 0, GL_TEXTURE_3D, 0, 0, true)}; //!< Sampler for preset

        for (const auto& name : m_samplerNames)
        {
            std::string baseName = name;
            if (name.length() > 3 && name.at(2) == '_')
            {
                baseName = name.substr(3);
            }
            
            std::string lowerCaseName = Utils::ToLower(baseName);
            
            // The "main" and "blurX" textures are preset-specific and are not managed by TextureManager.
            if (lowerCaseName == "main")
            {
                Renderer::TextureSamplerDescriptor desc(m_dummyTexture,
                                                        m_dummySampler,
                                                        name,
                                                        "main");
                m_mainTextureDescriptors.push_back(std::move(desc));
                continue;
            }
            
            // The blur textures belong to the preset, not to the TextureManager. Falling
            // through to it asked the disk for a file called "blur1", which fails, logs
            // "Failed to find texture blur1" and hands back the placeholder - and, worse,
            // pushed a descriptor that declares texsize_blur1, which the normal path never
            // emits. The two paths must produce the SAME source or the cached program is
            // compiled from something the render thread would not have written.
            // The level itself is already known: it is set while preprocessing, from the
            // GetBlurN calls in the code, which is also what put these names in the list.
            if (lowerCaseName == "blur1")
            {
                UpdateMaxBlurLevel(BlurTexture::BlurLevel::Blur1);
                continue;
            }
            if (lowerCaseName == "blur2")
            {
                UpdateMaxBlurLevel(BlurTexture::BlurLevel::Blur2);
                continue;
            }
            if (lowerCaseName == "blur3")
            {
                UpdateMaxBlurLevel(BlurTexture::BlurLevel::Blur3);
                continue;
            }

            // Random textures need special treatment.
            if (lowerCaseName.length() >= 6 &&
             lowerCaseName.substr(0, 4) == "rand" && std::isdigit(lowerCaseName.at(4), loc) && std::isdigit(lowerCaseName.at(5), loc))
             {
             // First look up the random texture index in the preset state so the texture matches between warp and composite shaders
             int randomSlot = -1;
             try
             {
             randomSlot = std::stoi(lowerCaseName.substr(4, 2));
             }
             catch (...) // Ignore any conversion errors.
             {
             }
             
             if (randomSlot >= 0 && randomSlot <= 15)
             {
             if (presetState.randomTextureDescriptors.find(randomSlot) != presetState.randomTextureDescriptors.end())
             {
             // Use existing texture descriptor.
             m_textureSamplerDescriptors.push_back(presetState.randomTextureDescriptors.at(randomSlot));
             continue;
             }
             
             // Slot empty. Draw the file this slot resolves to and WARM it, but
             // hand the shader a dummy all the same - the warm is a cache
             // effect, the emitted GLSL must not move. The chosen name is
             // recorded in the state and travels to the render thread, which
             // uses it verbatim (see ResolveRandomTexture).
             //
             // The sampler keeps the PRESET's own name ("rand00"),
             // exactly like the normal path (TextureManager::GetRandomTexture
             // builds its descriptor with randomName, not with the file it
             // picked). Naming it after the resolved FILE spliced a file name
             // into a GLSL identifier - "uniform sampler2D sampler_rand00_carved
             // in skin nz+;" - so every preset using randNN failed to
             // precompile on a syntax error at line 1 or 2, silently falling
             // back to a synchronous compile. And since the two paths must emit
             // the SAME source for the cached program to be reusable, the body
             // rewrite that went with it had to go too.
                 Renderer::TextureSamplerDescriptor desc(m_dummyTexture,
                                                         m_dummySampler,
                                                         name,
                                                         name);

             // No seed means nobody can be handed the result, so there is
             // nothing to resolve: fall straight back to the pre-existing
             // behaviour, where the render thread draws and loads for itself.
             if (presetState.randomSeed != 0 && presetState.renderContext.textureManager != nullptr)
             {
                 const uint64_t slotSeed = RandomSlotSeed(presetState.randomSeed, randomSlot);
                 std::string picked = presetState.renderContext.textureManager
                                          ->GetRandomTextureNoLoad(name, slotSeed);
                 if (!picked.empty())
                 {
                     presetState.randomTextureFiles[randomSlot] = picked;
                     try
                     {
                         // Decode + upload here rather than on the render thread.
                         presetState.renderContext.textureManager->GetTexture(picked);
                     }
                     catch (...)
                     {
                         // A texture that cannot be warmed is simply loaded later.
                     }
                 }
             }

             // Also store a copy in preset state!
             presetState.randomTextureDescriptors.insert({randomSlot, desc});
             
             m_textureSamplerDescriptors.push_back(std::move(desc));
             continue;
             }
             
             // Fall through if slot number is out of range and treat as normal texture.
             }
            
            // Warm the real texture into the manager's cache, and ONLY that:
            // the descriptor stays a dummy. The two paths must emit the SAME
            // GLSL for the precompiled program to be reusable, and resolving a
            // texture here is what once spliced a FILE name into a sampler
            // identifier (the randNN bug). Loading it is free of that: it puts
            // the decode and the upload on the preload worker instead of the
            // render thread, where they landed the moment the preset was
            // applied. Safe from this thread since TextureManager took a lock,
            // and worth it because textures are share-group objects — this IS
            // the object the render thread will find.
            if (presetState.renderContext.textureManager != nullptr)
            {
                try
                {
                    presetState.renderContext.textureManager->GetTexture(name);
                }
                catch (...)
                {
                    // A texture that cannot be warmed is simply loaded later.
                }
            }
            // The 4th argument is the TEXSIZE name, and it is the UNQUALIFIED one: the
            // sampler keeps the MilkDrop mode prefix ("fw_noisevol_hq") but the manager
            // builds its descriptor with the stripped name, so the normal path emits
            // "texsize_noisevol_hq". Passing `name` here emitted "texsize_fw_noisevol_hq"
            // instead - a second way for the two paths to disagree on the source, on every
            // preset that uses a prefixed sampler. `baseName` strips exactly what
            // TextureManager::ExtractTextureSettings strips (any XY_ prefix, matched or not).
            if (lowerCaseName.substr(0,8) == "noisevol") {
                // Now request the textures and descriptors from the texture manager.
                Renderer::TextureSamplerDescriptor desc(m_dummyTexture3D,
                                                        m_dummySampler,
                                                        name,
                                                        baseName);
                m_mainTextureDescriptors.push_back(std::move(desc));
            } else {
                // Now request the textures and descriptors from the texture manager.
                Renderer::TextureSamplerDescriptor desc(m_dummyTexture,
                                                        m_dummySampler,
                                                        name,
                                                        baseName);
                m_mainTextureDescriptors.push_back(std::move(desc));
            }
        }
    
    // Now that we have the textures, transpile the code.
    TranspileHLSLShaderPreCompilation(presetState, m_preprocessedCode);
    // Update blur texture level if shader was compiled successfully.
    //presetState.blurTexture.SetRequiredBlurLevel(m_maxBlurLevelRequired);
}


void MilkdropShader::LoadVariables(const PresetState& presetState, const PerFrameContext& perFrameContext)
{
    // These are the inputs: http://www.geisswerks.com/milkdrop/milkdrop_preset_authoring.html#3f6

    auto floatTime = static_cast<float>(presetState.renderContext.time);
    auto timeSincePresetStartWrapped = floatTime - static_cast<int>(floatTime / 10000.0) * 10000;
    auto mipX = logf(static_cast<float>(presetState.renderContext.viewportSizeX)) / logf(2.0f);
    auto mipY = logf(static_cast<float>(presetState.renderContext.viewportSizeY)) / logf(2.0f);
    auto mipAvg = 0.5f * (mipX + mipY);

    BlurTexture::Values blurMin;
    BlurTexture::Values blurMax;
    BlurTexture::GetSafeBlurMinMaxValues(perFrameContext, blurMin, blurMax);

    m_shader.Bind();

    m_shader.SetUniformMat4x4("vertex_transformation", PresetState::orthogonalProjection);

    m_shader.SetUniformFloat4("rand_frame", {floatRand(),
                                             floatRand(),
                                             floatRand(),
                                             floatRand()});
    m_shader.SetUniformFloat4("rand_preset", {m_randValues[0],
                                              m_randValues[1],
                                              m_randValues[2],
                                              m_randValues[3]});

    m_shader.SetUniformFloat4("_c0", {presetState.renderContext.aspectX,
                                      presetState.renderContext.aspectY,
                                      1.0f / presetState.renderContext.aspectX,
                                      1.0f / presetState.renderContext.aspectY});
    m_shader.SetUniformFloat4("_c1", {0.0,
                                      0.0,
                                      0.0,
                                      0.0});
    m_shader.SetUniformFloat4("_c2", {timeSincePresetStartWrapped,
                                      presetState.renderContext.fps,
                                      presetState.renderContext.frame,
                                      presetState.renderContext.progress});
    //YOYOFR
    m_shader.SetUniformFloat4("_c3", {presetState.audioData.bass / 1,
                                      presetState.audioData.mid / 1,
                                      presetState.audioData.treb / 1,
                                      presetState.audioData.vol / 1});
    m_shader.SetUniformFloat4("_c4", {presetState.audioData.bassAtt / 1,
                                      presetState.audioData.midAtt / 1,
                                      presetState.audioData.trebAtt / 1,
                                      presetState.audioData.volAtt / 1});
    //
    m_shader.SetUniformFloat4("_c5", {blurMax[0] - blurMin[0],
                                      blurMin[0],
                                      blurMax[1] - blurMin[1],
                                      blurMin[1]});
    m_shader.SetUniformFloat4("_c6", {blurMax[2] - blurMin[2],
                                      blurMin[2],
                                      blurMin[0],
                                      blurMax[0]});
    m_shader.SetUniformFloat4("_c7", {presetState.renderContext.viewportSizeX,
                                      presetState.renderContext.viewportSizeY,
                                      1.0f / static_cast<float>(presetState.renderContext.viewportSizeX),
                                      1.0f / static_cast<float>(presetState.renderContext.viewportSizeY)});

    m_shader.SetUniformFloat4("_c8", {0.5f + 0.5f * cosf(floatTime * 0.329f + 1.2f),
                                      0.5f + 0.5f * cosf(floatTime * 1.293f + 3.9f),
                                      0.5f + 0.5f * cosf(floatTime * 5.070f + 2.5f),
                                      0.5f + 0.5f * cosf(floatTime * 20.051f + 5.4f)});

    m_shader.SetUniformFloat4("_c9", {0.5f + 0.5f * sinf(floatTime * 0.329f + 1.2f),
                                      0.5f + 0.5f * sinf(floatTime * 1.293f + 3.9f),
                                      0.5f + 0.5f * sinf(floatTime * 5.070f + 2.5f),
                                      0.5f + 0.5f * sinf(floatTime * 20.051f + 5.4f)});

    m_shader.SetUniformFloat4("_c10", {0.5f + 0.5f * cosf(floatTime * 0.0050f + 2.7f),
                                       0.5f + 0.5f * cosf(floatTime * 0.0085f + 5.3f),
                                       0.5f + 0.5f * cosf(floatTime * 0.0133f + 4.5f),
                                       0.5f + 0.5f * cosf(floatTime * 0.0217f + 3.8f)});

    m_shader.SetUniformFloat4("_c11", {0.5f + 0.5f * sinf(floatTime * 0.0050f + 2.7f),
                                       0.5f + 0.5f * sinf(floatTime * 0.0085f + 5.3f),
                                       0.5f + 0.5f * sinf(floatTime * 0.0133f + 4.5f),
                                       0.5f + 0.5f * sinf(floatTime * 0.0217f + 3.8f)});

    m_shader.SetUniformFloat4("_c12", {mipX,
                                       mipY,
                                       mipAvg,
                                       0});
    m_shader.SetUniformFloat4("_c13", {blurMin[1],
                                       blurMax[1],
                                       blurMin[2],
                                       blurMax[2]});

    // MilkDrop3 additions. .xy = pointer position in 0..1 (-1 when the pointer
    // is away), .z = button held, .w = click just released.
    m_shader.SetUniformFloat4("_c14", {g_mouseX.load(std::memory_order_relaxed),
                                       g_mouseY.load(std::memory_order_relaxed),
                                       g_mouseHeld.load(std::memory_order_relaxed),
                                       g_mouseClicked.load(std::memory_order_relaxed)});

    {
        const std::time_t now = std::time(nullptr);
        std::tm local{};
#if defined(_WIN32)
        localtime_s(&local, &now);
#else
        localtime_r(&now, &local);
#endif
        // Weekday as MilkDrop3 numbers it: 1 = Monday … 7 = Sunday.
        const float weekday = static_cast<float>((local.tm_wday + 6) % 7 + 1);
        m_shader.SetUniformFloat4("_c15", {static_cast<float>(local.tm_hour),
                                           static_cast<float>(local.tm_min),
                                           static_cast<float>(local.tm_sec),
                                           static_cast<float>(local.tm_hour * 3600 +
                                                              local.tm_min * 60 +
                                                              local.tm_sec)});
        m_shader.SetUniformFloat4("_c16", {static_cast<float>(local.tm_year + 1900),
                                           static_cast<float>(local.tm_mon + 1),
                                           static_cast<float>(local.tm_mday),
                                           weekday});
    }


    std::array<glm::mat4, 24> tempMatrices{};

    // write matrices
    for (int i = 0; i < 20; i++)
    {
        glm::mat4 const rotationX = glm::rotate(glm::mat4(1.0f), m_randRotationCenters[i].x + m_randRotationSpeeds[i].x * floatTime, glm::vec3(1.0f, 0.0f, 0.0f));
        glm::mat4 const rotationY = glm::rotate(glm::mat4(1.0f), m_randRotationCenters[i].y + m_randRotationSpeeds[i].y * floatTime, glm::vec3(0.0f, 1.0f, 0.0f));
        glm::mat4 const rotationZ = glm::rotate(glm::mat4(1.0f), m_randRotationCenters[i].z + m_randRotationSpeeds[i].z * floatTime, glm::vec3(0.0f, 0.0f, 1.0f));

        glm::mat4 const randomTranslation = glm::translate(glm::mat4(1.0f), glm::vec3(m_randTranslation[i].x, m_randTranslation[i].y, m_randTranslation[i].z));

        tempMatrices[i] = randomTranslation * rotationX;
        tempMatrices[i] = rotationZ * tempMatrices[i];
        tempMatrices[i] = rotationY * tempMatrices[i];
    }

    // the last 4 are totally random, each frame
    for (int i = 20; i < 24; i++)
    {
        glm::mat4 const rotationX = glm::rotate(glm::mat4(1.0f), floatRand() * 6.28f, glm::vec3(1.0f, 0.0f, 0.0f));
        glm::mat4 const rotationY = glm::rotate(glm::mat4(1.0f), floatRand() * 6.28f, glm::vec3(0.0f, 1.0f, 0.0f));
        glm::mat4 const rotationZ = glm::rotate(glm::mat4(1.0f), floatRand() * 6.28f, glm::vec3(0.0f, 0.0f, 1.0f));

        glm::mat4 const randomTranslation = glm::translate(glm::mat4(1.0f), glm::vec3(floatRand(), floatRand(), floatRand()));

        tempMatrices[i] = randomTranslation * rotationX;
        tempMatrices[i] = rotationZ * tempMatrices[i];
        tempMatrices[i] = rotationY * tempMatrices[i];
    }

    m_shader.SetUniformMat3x4("rot_s1", tempMatrices[0]);
    m_shader.SetUniformMat3x4("rot_s2", tempMatrices[1]);
    m_shader.SetUniformMat3x4("rot_s3", tempMatrices[2]);
    m_shader.SetUniformMat3x4("rot_s4", tempMatrices[3]);
    m_shader.SetUniformMat3x4("rot_d1", tempMatrices[4]);
    m_shader.SetUniformMat3x4("rot_d2", tempMatrices[5]);
    m_shader.SetUniformMat3x4("rot_d3", tempMatrices[6]);
    m_shader.SetUniformMat3x4("rot_d4", tempMatrices[7]);
    m_shader.SetUniformMat3x4("rot_f1", tempMatrices[8]);
    m_shader.SetUniformMat3x4("rot_f2", tempMatrices[9]);
    m_shader.SetUniformMat3x4("rot_f3", tempMatrices[10]);
    m_shader.SetUniformMat3x4("rot_f4", tempMatrices[11]);
    m_shader.SetUniformMat3x4("rot_vf1", tempMatrices[12]);
    m_shader.SetUniformMat3x4("rot_vf2", tempMatrices[13]);
    m_shader.SetUniformMat3x4("rot_vf3", tempMatrices[14]);
    m_shader.SetUniformMat3x4("rot_vf4", tempMatrices[15]);
    m_shader.SetUniformMat3x4("rot_uf1", tempMatrices[16]);
    m_shader.SetUniformMat3x4("rot_uf2", tempMatrices[17]);
    m_shader.SetUniformMat3x4("rot_uf3", tempMatrices[18]);
    m_shader.SetUniformMat3x4("rot_uf4", tempMatrices[19]);
    m_shader.SetUniformMat3x4("rot_rand1", tempMatrices[20]);
    m_shader.SetUniformMat3x4("rot_rand2", tempMatrices[21]);
    m_shader.SetUniformMat3x4("rot_rand3", tempMatrices[22]);
    m_shader.SetUniformMat3x4("rot_rand4", tempMatrices[23]);

    // set program uniform "_q[a-h]" values (_qa.x, _qa.y, _qa.z, _qa.w, _qb.x, _qb.y ... ) alias q[1-32]
    for (int i = 0; i < QVarCount; i += 4)
    {
        std::string varName = "_q";
        varName.push_back(static_cast<char>('a' + i / 4));
        m_shader.SetUniformFloat4(varName.c_str(), {presetState.frameQVariables[i],
                                                    presetState.frameQVariables[i + 1],
                                                    presetState.frameQVariables[i + 2],
                                                    presetState.frameQVariables[i + 3]});
    }

    // Bind all texture and sampler descriptors. This includes the main and blur textures.
    GLint textureUnit{0};
    for (auto& desc : m_mainTextureDescriptors)
    {
        // Update main texture, swaps every frame.
        desc.Texture(presetState.mainTexture);
        desc.Bind(textureUnit, m_shader);
        textureUnit++;
    }
    presetState.blurTexture.Bind(textureUnit, m_shader);
    for (auto& desc : m_textureSamplerDescriptors)
    {
        if (desc.Empty())
        {
            desc.TryUpdate(*presetState.renderContext.textureManager);
        }
        desc.Bind(textureUnit, m_shader);
        textureUnit++;
    }
}

auto MilkdropShader::Shader() -> Renderer::Shader&
{
    return m_shader;
}

void MilkdropShader::PreprocessPresetShader(std::string& program)
{

    if (program.length() <= 0)
    {
        throw Renderer::ShaderException("Preset shader is declared, but empty.");
    }

    size_t found;

    // Find "sampler_state" overrides and remove them first, as they're not supported by GLSL.
    // The logic isn't totally fool-proof, but should work in general.
    found = program.find("sampler_state");
    while (found != std::string::npos)
    {
        // Now go backwards and find the assignment
        found = program.rfind('=', found);
        auto startPos = found;

        // Find closing brace and semicolon
        found = program.find('}', found);
        found = program.find(';', found);

        if (found != std::string::npos)
        {
            program.replace(startPos, found - startPos, "");
        }
        else
        {
            // No closing brace and semicolon.
            break;
        }

        found = program.find("sampler_state");
    }

    // replace shader_body with entry point function
    found = program.find("shader_body");
    if (found != std::string::npos)
    {
        if (m_type == ShaderType::WarpShader)
        {
            program.replace(int(found), 11, "\nvoid PS(float4 _vDiffuse : COLOR, float4 _uv : TEXCOORD0, float2 _rad_ang : TEXCOORD1, out float4 _return_value : COLOR0, out float4 _mv_tex_coords : COLOR1)\n");
        }
        else
        {
            program.replace(int(found), 11, "\nvoid PS(float4 _vDiffuse : COLOR, float2 _uv : TEXCOORD0, float2 _rad_ang : TEXCOORD1, out float4 _return_value : COLOR)\n");
        }
    }
    else
    {
        throw Renderer::ShaderException("Preset shader is missing \"shader_body\" entry point.");
    }

    // replace the "{" immediately following shader_body with some variable declarations
    found = program.find('{', found);
    if (found != std::string::npos)
    {
        std::string progMain = "{\nfloat3 ret = 0;\n";
        if (m_type == ShaderType::WarpShader)
        {
            progMain.append("_mv_tex_coords.xy = _uv.xy;\n");
        }
        program.replace(int(found), 1, progMain);
    }
    else
    {
        throw Renderer::ShaderException("Preset shader has no opening braces.");
    }

    // replace "}" with return statement (this can probably be optimized for the GLSL conversion...)
    found = program.rfind('}');
    if (found != std::string::npos)
    {
        program.replace(int(found), 1, "_return_value = float4(ret.xyz, _vDiffuse.w);\n"
                                       "}\n");
    }
    else
    {
        throw Renderer::ShaderException("Preset shader has no closing brace.");
    }

    // Find matching closing brace and cut off excess text after shader's main function
    int bracesOpen = 1;
    size_t pos = found + 1;
    for (; pos < program.length() && bracesOpen > 0; ++pos)
    {
        switch (program.at(pos))
        {
            case '/':
                // Skip comments until EoL to prevent false counting
                if (pos < program.length() - 1 && program.at(pos + 1) == '/')
                {
                    for (; pos < program.length(); ++pos)
                    {
                        if (program.at(pos) == '\n')
                        {
                            break;
                        }
                    }
                }
                continue;

            case '{':
                bracesOpen++;
                continue;

            case '}':
                bracesOpen--;
        }
    }

    if (pos < program.length() - 1)
    {
        program.resize(pos);
    }

    std::string fullSource; //!< Full shader source before translation, includes all uniforms etc.

    // First copy the generic "header" into the shader. Includes uniforms and some defines
    // to unwrap the packed 4-element uniforms into single values.
    fullSource.append(MilkdropStaticShaders::Get()->GetPresetShaderHeader());

    if (m_type == ShaderType::WarpShader)
    {
        fullSource.append("#define rad _rad_ang.x\n"
                          "#define ang _rad_ang.y\n"
                          "#define uv _uv.xy\n"
                          "#define uv_orig _uv.zw\n");
    }
    else
    {
        fullSource.append("#define rad _rad_ang.x\n"
                          "#define ang _rad_ang.y\n"
                          "#define uv _uv.xy\n"
                          "#define uv_orig _uv.xy\n"
                          "#define hue_shader _vDiffuse.xyz\n");
    }

    // Only injected when used: the functions reference samplers which are only declared
    // for presets that asked for them.
    fullSource.append(AudioFunctionDeclarations());

    fullSource.append(program);

    program = fullSource;
}

auto MilkdropShader::AudioFunctionDeclarations() const -> std::string
{
    std::string declarations;

    if (m_usesFftTexture)
    {
        // Row 0 (v = 0.25) is the smoothed spectrum, row 1 (v = 0.75) the peak hold.
        // The magnitude is stored linearly and square-rooted here, like MilkDrop3 does.
        // The Hz mapping assumes the spectrum spans 0 .. 22050 Hz, i.e. 44.1 kHz audio.
        declarations.append("#define HAS_FFT_PEAK 1\n"
                            "float get_fft(float pos) { return sqrt(tex2D(sampler_fft, float2(saturate(pos), 0.25)).x); }\n"
                            "float get_fft_peak(float pos) { return sqrt(tex2D(sampler_fft, float2(saturate(pos), 0.75)).x); }\n"
                            "float get_fft_hz(float freq) { return get_fft(freq * 0.00004535147); }\n"
                            "float get_fft_peak_hz(float freq) { return get_fft_peak(freq * 0.00004535147); }\n");
    }

    if (m_usesWaveTexture)
    {
        declarations.append("#define HAS_WAVE 1\n"
                            "float get_wave_left(float pos) { return tex2D(sampler_wave, float2(saturate(pos), 0.25)).x; }\n"
                            "float get_wave_right(float pos) { return tex2D(sampler_wave, float2(saturate(pos), 0.75)).x; }\n"
                            "float get_wave(float pos) { return (get_wave_left(pos) + get_wave_right(pos)) * 0.5; }\n");
    }

    return declarations;
}

void MilkdropShader::GetReferencedSamplers(const std::string& program)
{
    // Look up samplers referenced in the shader program
    m_samplerNames.clear();

    // "main" should always be present.
    m_samplerNames.insert("main");

    // A sampler name is an IDENTIFIER, so it ends at the first character that
    // cannot be part of one. Stopping at a fixed list of separators instead
    // swallowed whatever followed a name used as an object: a HLSL-4 style
    // "sampler_x.SampleLevel(sampler0, ..." (Milkwave transpiles shadertoy that
    // way, even inside a comment) became the sampler NAME, and the generated
    // declaration "uniform sampler2D sampler_x.SampleLevel(sampler0;" failed to
    // parse - the whole preset died on line 1 with an error pointing at '.'.
    auto identifierEnd = [&program](size_t start) {
        size_t end = start;
        while (end < program.length() &&
               (std::isalnum(static_cast<unsigned char>(program[end])) || program[end] == '_'))
        {
            ++end;
        }
        return end;
    };

    // Search for sampler usage
    auto found = program.find("sampler_", 0);
    while (found != std::string::npos)
    {
        found += 8;
        size_t const end = identifierEnd(found);

        if (end > found)
        {
            std::string const sampler = program.substr(static_cast<int>(found), static_cast<int>(end - found));
            // Skip "sampler_state", as it's a reserved word and not a sampler.
            if (sampler != "state")
            {
                m_samplerNames.insert(sampler);
            }
        }

        found = program.find("sampler_", found);
    }

    // Also search for texsize usage, some presets don't reference the sampler.
    found = program.find("texsize_", 0);
    while (found != std::string::npos)
    {
        found += 8;
        size_t const end = identifierEnd(found);

        if (end > found)
        {
            std::string const sampler = program.substr(static_cast<int>(found), static_cast<int>(end - found));
            m_samplerNames.insert(sampler);
        }

        found = program.find("texsize_", found);
    }

    {
        // Remove duplicate mentions or "randXX" names, keeping the long forms only (first one will determine the actual texture loaded).
        auto samplerName = m_samplerNames.begin();
        std::locale loc;
        while (samplerName != m_samplerNames.end())
        {
            std::string lowerCaseName = Utils::ToLower(*samplerName);
            if (lowerCaseName.length() == 6 &&
                lowerCaseName.substr(0, 4) == "rand" && std::isdigit(lowerCaseName.at(4), loc) && std::isdigit(lowerCaseName.at(5), loc))
            {
                auto additionalName = samplerName;
                additionalName++;
                if (additionalName != m_samplerNames.end())
                {
                    std::string addLowerCaseName = Utils::ToLower(*additionalName);
                    if (addLowerCaseName.length() > 7 &&
                        addLowerCaseName.substr(0, 6) == lowerCaseName &&
                        addLowerCaseName[6] == '_')
                    {
                        samplerName = m_samplerNames.erase(samplerName);
                    }
                }
            }
            samplerName++;
        }
    }

    // MilkDrop3/BeatDrop audio functions. They read from textures the preset never names
    // itself, so the samplers are requested here on the preset's behalf.
    m_usesFftTexture = program.find("get_fft") != std::string::npos;
    m_usesWaveTexture = program.find("get_wave") != std::string::npos;
    if (m_usesFftTexture)
    {
        m_samplerNames.insert("fft");
    }
    if (m_usesWaveTexture)
    {
        m_samplerNames.insert("wave");
    }

    if (program.find("GetBlur3") != std::string::npos)
    {
        UpdateMaxBlurLevel(BlurTexture::BlurLevel::Blur3);
    }
    else if (program.find("GetBlur2") != std::string::npos)
    {
        UpdateMaxBlurLevel(BlurTexture::BlurLevel::Blur2);
    }
    else if (program.find("GetBlur1") != std::string::npos)
    {
        UpdateMaxBlurLevel(BlurTexture::BlurLevel::Blur1);
    }
    else
    {
        m_maxBlurLevelRequired = BlurTexture::BlurLevel::None;
    }
}

void MilkdropShader::TranspileHLSLShader(const PresetState& presetState, std::string& program,uint32_t shaderP)
{
    std::string shaderTypeString = "composite";
    if (m_type == ShaderType::WarpShader)
    {
        shaderTypeString = "warp";
    }
    
    std::string codeToCompile;
    GLuint shaderProg=0;
    
    if (shaderP==0) {
        
        M4::GLSLGenerator generator;
        M4::Allocator allocator;
        
        M4::HLSLTree tree(&allocator);
        M4::HLSLParser parser(&allocator, &tree);
        
        // YOYOFR: Preprocess HLSL program to ease conversion
        ShaderPreprocessor preProcessor(ShaderLanguage::HLSL);
        m_preprocessedCode = preProcessor.preprocess(m_preprocessedCode);
        
        // Preprocess define macros
        std::string sourcePreprocessed;
        if (!parser.ApplyPreprocessor("", program.c_str(), program.size(), sourcePreprocessed))
        {
            throw Renderer::ShaderException("Error translating HLSL " + shaderTypeString + " shader: Preprocessing failed.\nSource:\n" + program);
        }
        
        // Remove previous shader declarations
        // ToDo: Quite some presets declare a sampler_state{} struct to change the wrap mode.
        //       The below code causes invalid syntax as it leaves part of the expression.
        //       Leaving it in causes HLSLParser to add "sampler_XYZ = sampler2D( <unknown expression> );"
        //       in the main() function, which is also bad...
        std::smatch matches;
        while (std::regex_search(sourcePreprocessed, matches, std::regex("sampler(2D|3D|)(\\s+|\\().*")))
        {
            sourcePreprocessed.replace(matches.position(), matches.length(), "");
        }
        
        // Remove previous texsize declarations
        while (std::regex_search(sourcePreprocessed, matches, std::regex("float4\\s+texsize_.*")))
        {
            sourcePreprocessed.replace(matches.position(), matches.length(), "");
        }
        
        // Collect unique samplers and texsize uniforms
        std::set<std::string> samplerDeclarations;
        std::set<std::string> texSizeDeclarations;
        for (const auto& desc : m_mainTextureDescriptors)
        {
            samplerDeclarations.insert(desc.SamplerDeclaration());
            texSizeDeclarations.insert(desc.TexSizeDeclaration());
        }
        for (const auto& desc : presetState.blurTexture.GetDescriptorsForBlurLevel(m_maxBlurLevelRequired))
        {
            samplerDeclarations.insert(desc.SamplerDeclaration());
            // No texsize_blur1 etc.
        }
        for (const auto& desc : m_textureSamplerDescriptors)
        {
            samplerDeclarations.insert(desc.SamplerDeclaration());
            texSizeDeclarations.insert(desc.TexSizeDeclaration());
        }
        
        // Now insert them on top.
        for (const auto& texSizeDeclaration : texSizeDeclarations)
        {
            sourcePreprocessed.insert(0, texSizeDeclaration);
        }
        for (const auto& samplerDeclaration : samplerDeclarations)
        {
            sourcePreprocessed.insert(0, samplerDeclaration);
        }
        
        // Transpile from HLSL (aka preset shader aka DirectX shader) to GLSL (aka OpenGL shader lang)
        // First, parse HLSL into a tree
        // Label the source with the preset and which shader it is: hlslparser prints
    // "<file>(<line>) : ...", and an empty name produced a bare "(3) : Syntax
    // error" that no log line could be pinned to (the loader's lines interleave,
    // so the preset named just above is not necessarily the culprit).
    const std::string shaderLabel =
        presetState.presetName + (m_type == ShaderType::WarpShader ? " [warp]" : " [comp]");
    DumpTranspilerSource("normal", shaderLabel, sourcePreprocessed);
    if (!parser.Parse(shaderLabel.c_str(), sourcePreprocessed.c_str(), sourcePreprocessed.size()))
        {
            throw Renderer::ShaderException("Error translating HLSL " + shaderTypeString + " shader: HLSL parsing failed.\nSource:\n" + sourcePreprocessed);
        }
        
        // Then generate GLSL from the resulting parser tree
        if (!generator.Generate(&tree, M4::GLSLGenerator::Target_FragmentShader,
                                MilkdropStaticShaders::Get()->GetGlslGeneratorVersion(),
                                "PS", M4::GLSLGenerator::Options(M4::GLSLGenerator::Flag_AlternateNanPropagation)))
        {
            throw Renderer::ShaderException("Error translating HLSL " + shaderTypeString + " shader: GLSL generating failed.\nSource:\n" + sourcePreprocessed);
        }
        
        codeToCompile=generator.GetResult();

    } else {
        shaderProg=shaderP;
    }
    
    // Now we have GLSL source for the preset shader program (hopefully it's valid!)
    // Compile the preset shader fragment shader with the standard vertex shader and cross our fingers.
    if (m_type == ShaderType::WarpShader)
    {
        m_shader.CompileProgram(MilkdropStaticShaders::Get()->GetPresetWarpVertexShader(), codeToCompile,shaderProg);
    }
    else
    {
        m_shader.CompileProgram(MilkdropStaticShaders::Get()->GetPresetCompVertexShader(), codeToCompile,shaderProg);
    }
}

void MilkdropShader::TranspileHLSLShaderPreCompilation(const AltPresetState& presetState, std::string& program)
{
    std::string shaderTypeString = "composite";
    if (m_type == ShaderType::WarpShader)
    {
        shaderTypeString = "warp";
    }
    
    M4::GLSLGenerator generator;
    M4::Allocator allocator;

    M4::HLSLTree tree(&allocator);
    M4::HLSLParser parser(&allocator, &tree);
#ifdef MILKDROP_PRESET_DEBUG_ADDITIONNAL
    std::cout << "Original HLSL code" << std::endl;
    std::cout << "==================" << std::endl;
    std::cout << m_preprocessedCode << std::endl;
#endif
    // YOYOFR: Preprocess HLSL program to ease conversion
    ShaderPreprocessor preProcessor(ShaderLanguage::HLSL);
    m_preprocessedCode = preProcessor.preprocess(m_preprocessedCode);
#ifdef MILKDROP_PRESET_DEBUG_ADDITIONNAL
    std::cout << "Preprocessed HLSL code" << std::endl;
    std::cout << "======================" << std::endl;
    std::cout << m_preprocessedCode << std::endl;
#endif

    // Preprocess define macros
    std::string sourcePreprocessed;
    if (!parser.ApplyPreprocessor("", program.c_str(), program.size(), sourcePreprocessed))
    {
        throw Renderer::ShaderException("Error translating HLSL " + shaderTypeString + " shader: Preprocessing failed.\nSource:\n" + program);
    }

    // Remove previous shader declarations
    // ToDo: Quite some presets declare a sampler_state{} struct to change the wrap mode.
    //       The below code causes invalid syntax as it leaves part of the expression.
    //       Leaving it in causes HLSLParser to add "sampler_XYZ = sampler2D( <unknown expression> );"
    //       in the main() function, which is also bad...
    std::smatch matches;
    while (std::regex_search(sourcePreprocessed, matches, std::regex("sampler(2D|3D|)(\\s+|\\().*")))
    {
        sourcePreprocessed.replace(matches.position(), matches.length(), "");
    }

    // Remove previous texsize declarations
    while (std::regex_search(sourcePreprocessed, matches, std::regex("float4\\s+texsize_.*")))
    {
        sourcePreprocessed.replace(matches.position(), matches.length(), "");
    }

    // Collect unique samplers and texsize uniforms
    std::set<std::string> samplerDeclarations;
    std::set<std::string> texSizeDeclarations;
    for (const auto& desc : m_mainTextureDescriptors)
    {
        samplerDeclarations.insert(desc.SamplerDeclaration());
        texSizeDeclarations.insert(desc.TexSizeDeclaration());
    }
    // Same declarations the normal path takes from PresetState::blurTexture, which does
    // not exist on this side (AltPresetState has no BlurTexture, and there would be no
    // point: only the NAMES reach the source). Mirrors GetDescriptorsForBlurLevel - level
    // N declares blur1..blurN - and goes through SamplerDeclaration() rather than pasting
    // the string, so the two paths cannot drift apart.
    {
        auto blurSampler = std::make_shared<Renderer::Sampler>(GL_CLAMP_TO_EDGE, GL_LINEAR);
        auto blurTexture = std::make_shared<Renderer::Texture>("dummy2D", 0, GL_TEXTURE_2D, 0, 0, true);
        for (int level = 1; level <= static_cast<int>(m_maxBlurLevelRequired); level++)
        {
            Renderer::TextureSamplerDescriptor desc(blurTexture, blurSampler,
                                                    "blur" + std::to_string(level),
                                                    std::string());
            samplerDeclarations.insert(desc.SamplerDeclaration());
            // No texsize_blur1 etc.
        }
    }
    for (const auto& desc : m_textureSamplerDescriptors)
    {
        samplerDeclarations.insert(desc.SamplerDeclaration());
        texSizeDeclarations.insert(desc.TexSizeDeclaration());
    }

    // Now insert them on top.
    for (const auto& texSizeDeclaration : texSizeDeclarations)
    {
        sourcePreprocessed.insert(0, texSizeDeclaration);
    }
    for (const auto& samplerDeclaration : samplerDeclarations)
    {
        sourcePreprocessed.insert(0, samplerDeclaration);
    }

    // Transpile from HLSL (aka preset shader aka DirectX shader) to GLSL (aka OpenGL shader lang)
    // First, parse HLSL into a tree
    // Label the source with the preset and which shader it is: hlslparser prints
    // "<file>(<line>) : ...", and an empty name produced a bare "(3) : Syntax
    // error" that no log line could be pinned to (the loader's lines interleave,
    // so the preset named just above is not necessarily the culprit).
    const std::string shaderLabel =
        presetState.presetName + (m_type == ShaderType::WarpShader ? " [warp]" : " [comp]");
    DumpTranspilerSource("precomp", shaderLabel, sourcePreprocessed);
    if (!parser.Parse(shaderLabel.c_str(), sourcePreprocessed.c_str(), sourcePreprocessed.size()))
    {
        throw Renderer::ShaderException("Error translating HLSL " + shaderTypeString + " shader: HLSL parsing failed.\nSource:\n" + sourcePreprocessed);
    }

    // Then generate GLSL from the resulting parser tree
    if (!generator.Generate(&tree, M4::GLSLGenerator::Target_FragmentShader,
                            MilkdropStaticShaders::Get()->GetGlslGeneratorVersion(),
                            "PS", M4::GLSLGenerator::Options(M4::GLSLGenerator::Flag_AlternateNanPropagation)))
    {
        throw Renderer::ShaderException("Error translating HLSL " + shaderTypeString + " shader: GLSL generating failed.\nSource:\n" + sourcePreprocessed);
    }
    
    m_convertedCode=generator.GetResult();
#ifdef MILKDROP_PRESET_DEBUG_ADDITIONNAL
    std::cout << "Converted HLSL code" << std::endl;
    std::cout << "===================" << std::endl;
    std::cout<<m_convertedCode<<std::endl;
#endif
    
    // Now we have GLSL source for the preset shader program (hopefully it's valid!)
    // Compile the preset shader fragment shader with the standard vertex shader and cross our fingers.
    if (m_type == ShaderType::WarpShader)
    {
        m_shader.CompileProgram(MilkdropStaticShaders::Get()->GetPresetWarpVertexShader(), m_convertedCode);
    }
    else
    {
        m_shader.CompileProgram(MilkdropStaticShaders::Get()->GetPresetCompVertexShader(), m_convertedCode);
    }
    
    m_shaderP=m_shader.m_shaderProgram;
    m_shader.m_shaderProgram=0;
}


void MilkdropShader::UpdateMaxBlurLevel(BlurTexture::BlurLevel requestedLevel)
{
    if (m_maxBlurLevelRequired >= requestedLevel)
    {
        return;
    }

    m_maxBlurLevelRequired = requestedLevel;

    if (m_maxBlurLevelRequired == BlurTexture::BlurLevel::Blur3)
    {
        m_samplerNames.insert("blur1");
        m_samplerNames.insert("blur2");
        m_samplerNames.insert("blur3");
    }
    else if (m_maxBlurLevelRequired == BlurTexture::BlurLevel::Blur2)
    {
        m_samplerNames.insert("blur1");
        m_samplerNames.insert("blur2");
    }
    else
    {
        m_samplerNames.insert("blur1");
    }
}

} // namespace MilkdropPreset
} // namespace libprojectM

// Host-facing pointer setter for the MilkDrop3 "mouse" uniform. The library has
// no window and no input of its own, so whoever owns the surface pushes the
// state here. x/y are 0..1 with the origin top-left (the same frame as "uv"),
// or -1 to mean "pointer away".
extern "C" void projectm_set_mouse_state(float x, float y, int held, int clicked)
{
    libprojectM::MilkdropPreset::g_mouseX.store(x, std::memory_order_relaxed);
    libprojectM::MilkdropPreset::g_mouseY.store(y, std::memory_order_relaxed);
    libprojectM::MilkdropPreset::g_mouseHeld.store(held ? 1.0f : 0.0f, std::memory_order_relaxed);
    libprojectM::MilkdropPreset::g_mouseClicked.store(clicked ? 1.0f : 0.0f, std::memory_order_relaxed);
}
