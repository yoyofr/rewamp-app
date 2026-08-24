#include "TextureManager.hpp"

#include "FileScanner.hpp"
#include "IdleTextures.hpp"
#include "MilkdropNoise.hpp"
#include "Texture.hpp"
#include "Utils.hpp"

#include <SOIL2/SOIL2.h>

#include <algorithm>
#include <memory>
#include <random>
#include <vector>

#ifdef DEBUG
#include <iostream>
#endif

// Missing in macOS SDK. Query will most certainly fail, but then use the default format.
#ifndef GL_TEXTURE_IMAGE_FORMAT
#define GL_TEXTURE_IMAGE_FORMAT 0x828F
#endif

namespace libprojectM {
namespace Renderer {

TextureManager::TextureManager(const std::vector<std::string>& textureSearchPaths)
    : m_textureSearchPaths(textureSearchPaths)
    , m_placeholderTexture(std::make_shared<Texture>("placeholder", 1, 1, false))
{
    Preload();
    m_currentPresetDir=std::string("");
}

void TextureManager::SetCurrentPresetPath(const std::string&currentPath)
{
    const std::lock_guard<std::recursive_mutex> lock(m_mutex);
    m_currentPresetDir=currentPath;
}

TextureSamplerDescriptor TextureManager::GetTexture(const std::string& fullName,bool dontLoad)
{
    std::string unqualifiedName;
    GLint wrapMode;
    GLint filterMode;

    ExtractTextureSettings(fullName, wrapMode, filterMode, unqualifiedName);
    if (!dontLoad) {
        if (m_textures.find(unqualifiedName) == m_textures.end())
        {
            return TryLoadingTexture(fullName);
        }
    }

    return {m_textures[unqualifiedName], m_samplers.at({wrapMode, filterMode}), fullName, unqualifiedName};
}

auto TextureManager::GetTextureColorKeyed(const std::string& fullName, uint32_t colorKey) -> TextureSamplerDescriptor
{
    const std::lock_guard<std::recursive_mutex> lock(m_mutex);
    GLint wrapMode{};
    GLint filterMode{};
    std::string unqualifiedName;
    ExtractTextureSettings(fullName, wrapMode, filterMode, unqualifiedName);

    char suffix[32];
    snprintf(suffix, sizeof(suffix), "#ck%06x", colorKey & 0xFFFFFFu);
    const std::string cacheKey = Utils::ToLower(unqualifiedName) + suffix;

    if (m_textures.find(cacheKey) != m_textures.end())
    {
        return {m_textures[cacheKey], m_samplers.at({wrapMode, filterMode}), fullName, unqualifiedName};
    }

    ScanTextures();

    const std::string lowerCaseUnqualifiedName = Utils::ToLower(unqualifiedName);
    for (const auto& file : m_scannedTextureFiles)
    {
        if (file.lowerCaseBaseName != lowerCaseUnqualifiedName)
        {
            continue;
        }
        auto texture = LoadTextureColorKeyed(file, colorKey, cacheKey);
        if (texture)
        {
            return {texture, m_samplers.at({wrapMode, filterMode}), fullName, unqualifiedName};
        }
    }

    // No such file: fall back to the plain path so the caller behaves as before.
    return GetTexture(fullName);
}

auto TextureManager::LoadTextureColorKeyed(const ScannedFile& file, uint32_t colorKey,
                                           const std::string& cacheKey) -> std::shared_ptr<Texture>
{
    const std::lock_guard<std::recursive_mutex> lock(m_mutex);
    int width{};
    int height{};
    int channels{};

    // SOIL_load_image (rather than SOIL_load_OGL_texture) because the pixels
    // have to be touched before upload — and because it is the only way to know
    // the real dimensions: the OGL variant uploads straight to GL and leaves
    // width/height unset, which is why every Texture built by LoadTexture
    // reports 0x0.
    unsigned char* pixels = SOIL_load_image(file.filePath.c_str(), &width, &height, &channels, SOIL_LOAD_RGBA);
    if (pixels == nullptr || width <= 0 || height <= 0)
    {
        if (pixels != nullptr) SOIL_free_image_data(pixels);
        return {};
    }

    const unsigned char keyR = static_cast<unsigned char>((colorKey >> 16) & 0xFF);
    const unsigned char keyG = static_cast<unsigned char>((colorKey >> 8) & 0xFF);
    const unsigned char keyB = static_cast<unsigned char>(colorKey & 0xFF);

    const size_t texelCount = static_cast<size_t>(width) * static_cast<size_t>(height);
    for (size_t i = 0; i < texelCount; i++)
    {
        unsigned char* texel = pixels + i * 4;
        if (texel[0] == keyR && texel[1] == keyG && texel[2] == keyB)
        {
            // Zero the colour too: the sprite shader modulates RGB by the
            // texture in every blend mode, and a transparent-but-coloured texel
            // still bleeds through linear filtering at the cutout's edge.
            texel[0] = texel[1] = texel[2] = 0;
            texel[3] = 0;
        }
    }

    GLuint textureId{};
    glGenTextures(1, &textureId);
    glBindTexture(GL_TEXTURE_2D, textureId);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    glGenerateMipmap(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D, 0);

    SOIL_free_image_data(pixels);

    auto newTexture = std::make_shared<Texture>(cacheKey, textureId, GL_TEXTURE_2D, width, height, true);
    m_textures[cacheKey] = newTexture;
    m_textureStats.insert({cacheKey, {static_cast<uint32_t>(texelCount * 4)}});

    return newTexture;
}

auto TextureManager::GetSampler(const std::string& fullName) -> std::shared_ptr<class Sampler>
{
    std::string unqualifiedName;
    GLint wrapMode;
    GLint filterMode;

    ExtractTextureSettings(fullName, wrapMode, filterMode, unqualifiedName);

    return m_samplers.at({wrapMode, filterMode});
}

void TextureManager::Preload()
{
    // Create samplers
    m_samplers.emplace(std::make_pair(GL_CLAMP_TO_EDGE, GL_LINEAR), std::make_shared<Sampler>(GL_CLAMP_TO_EDGE, GL_LINEAR));
    m_samplers.emplace(std::make_pair(GL_CLAMP_TO_EDGE, GL_NEAREST), std::make_shared<Sampler>(GL_CLAMP_TO_EDGE, GL_NEAREST));
    m_samplers.emplace(std::make_pair(GL_REPEAT, GL_LINEAR), std::make_shared<Sampler>(GL_REPEAT, GL_LINEAR));
    m_samplers.emplace(std::make_pair(GL_REPEAT, GL_NEAREST), std::make_shared<Sampler>(GL_REPEAT, GL_NEAREST));
    //YOYOFR
    m_samplers.emplace(std::make_pair(GL_REPEAT, GL_LINEAR_MIPMAP_LINEAR), std::make_shared<Sampler>(GL_REPEAT, GL_LINEAR_MIPMAP_LINEAR));
    m_samplers.emplace(std::make_pair(GL_CLAMP_TO_EDGE, GL_LINEAR_MIPMAP_LINEAR), std::make_shared<Sampler>(GL_CLAMP_TO_EDGE, GL_LINEAR_MIPMAP_LINEAR));

    int width{};
    int height{};

    unsigned int tex = SOIL_load_OGL_texture_from_memory(
        M_data,
        M_bytes,
        SOIL_LOAD_AUTO,
        SOIL_CREATE_NEW_ID,
        SOIL_FLAG_POWER_OF_TWO | SOIL_FLAG_MULTIPLY_ALPHA);

    m_textures["idlem"] = std::make_shared<Texture>("idlem", tex, GL_TEXTURE_2D, width, height, false);;

    tex = SOIL_load_OGL_texture_from_memory(
        headphones_data,
        headphones_bytes,
        SOIL_LOAD_AUTO,
        SOIL_CREATE_NEW_ID,
        SOIL_FLAG_POWER_OF_TWO | SOIL_FLAG_MULTIPLY_ALPHA);

    m_textures["idleheadphones"] = std::make_shared<Texture>("idleheadphones", tex, GL_TEXTURE_2D, width, height, false);;

    // Noise textures
    m_textures["noise_lq_lite"] = MilkdropNoise::LowQualityLite();
    m_textures["noise_lq"] = MilkdropNoise::LowQuality();
    m_textures["noise_mq"] = MilkdropNoise::MediumQuality();
    m_textures["noise_hq"] = MilkdropNoise::HighQuality();
    m_textures["noisevol_lq"] = MilkdropNoise::LowQualityVolume();
    m_textures["noisevol_hq"] = MilkdropNoise::HighQualityVolume();
}

void TextureManager::PurgeTextures()
{
    const std::lock_guard<std::recursive_mutex> lock(m_mutex);
    // Increment age of all textures
    for (auto& texture : m_textures)
    {
        if (texture.second->IsUserTexture())
        {
            m_textureStats.at(texture.first).age++;
        }
    }

    // Clear file cache
    m_scannedTextureFiles.clear();
    m_filesScanned = false;

    // Only purge textures with an age of 2 or higher, so we don't evict textures used by the preset being blended out
    uint32_t newest = 99999999;
    uint32_t oldest = 0;
    bool foundTextureToEvict = false;
    for (const auto& stat : m_textureStats)
    {
        if (stat.second.sizeBytes > 0 && stat.second.age > 1)
        {
            newest = std::min(newest, stat.second.age);
            oldest = std::max(oldest, stat.second.age);
            foundTextureToEvict = true;
        }
    }

    if (!foundTextureToEvict)
    {
        return;
    }

    uint32_t biggestBytes = 0;
    std::string biggestName;
    for (const auto& stat : m_textureStats)
    {
        if (stat.second.sizeBytes > 0 && stat.second.age > 1)
        {
            auto sizeMultiplicator = 1.0f + static_cast<float>(stat.second.age - newest) / static_cast<float>(oldest - newest);
            auto scaledSize = static_cast<uint32_t>(stat.second.sizeBytes * sizeMultiplicator);
            if (scaledSize > biggestBytes)
            {
                biggestBytes = scaledSize;
                biggestName = stat.first;
            }
        }
    }

    if (biggestName.empty())
    {
        return;
    }
    // Purge one texture. No need to inform presets, as the texture shouldn't be in use anymore.
    // If this really happens for some reason, it'll simply be reloaded on the next frame.
    m_textures.erase(m_textures.find(biggestName));
    m_textureStats.erase(m_textureStats.find(biggestName));

#ifdef DEBUG
    std::cerr << "Purged texture " << biggestName << std::endl;
#endif
}

auto TextureManager::TryLoadingTexture(const std::string& name) -> TextureSamplerDescriptor
{
    const std::lock_guard<std::recursive_mutex> lock(m_mutex);
    GLint wrapMode{0};
    GLint filterMode{0};
    std::string unqualifiedName;

    ExtractTextureSettings(name, wrapMode, filterMode, unqualifiedName);

    ScanTextures();

    std::string lowerCaseUnqualifiedName = Utils::ToLower(unqualifiedName);
    for (const auto& file : m_scannedTextureFiles)
    {
        if (file.lowerCaseBaseName != lowerCaseUnqualifiedName)
        {
            continue;
        }

        auto texture = LoadTexture(file);

        if (texture)
        {
#ifdef DEBUG
            std::cerr << "Loaded texture " << unqualifiedName << std::endl;
#endif
            return {texture, m_samplers.at({wrapMode, filterMode}), name, unqualifiedName};;
        }
    }

#ifdef DEBUG
    std::cerr << "Failed to find texture " << unqualifiedName << std::endl;
#endif

    // Return a placeholder.
    return {m_placeholderTexture, m_samplers.at({wrapMode, filterMode}), name, unqualifiedName};
}

auto TextureManager::LoadTexture(const ScannedFile& file) -> std::shared_ptr<Texture>
{
    const std::lock_guard<std::recursive_mutex> lock(m_mutex);
    std::string unqualifiedName;

    if (m_textures.find(file.lowerCaseBaseName) != m_textures.end())
    {
        return m_textures.at(file.lowerCaseBaseName);
    }

    int width{};
    int height{};

    unsigned int const tex = SOIL_load_OGL_texture(
        file.filePath.c_str(),
        SOIL_LOAD_RGBA,
        SOIL_CREATE_NEW_ID,
        SOIL_FLAG_MULTIPLY_ALPHA|SOIL_FLAG_GL_MIPMAPS|SOIL_FLAG_MIPMAPS);

    if (tex == 0)
    {
        return {};
    }

    // Build the mip chain OURSELVES, whatever SOIL did. A preset texture is
    // sampled with GL_LINEAR_MIPMAP_LINEAR (ExtractTextureSettings gives that
    // filter to every name that is not one of the engine's own), and in GLES a
    // texture whose min filter asks for mipmaps but which has no mip chain is
    // INCOMPLETE: it samples as opaque black, silently, with no GL error. SOIL
    // resolves glGenerateMipmap dynamically - on iOS through
    // dlsym(RTLD_DEFAULT), where our ANGLE is a STATIC library - and falls back
    // to uploading levels by hand; either way it is a path we do not control and
    // cannot see. Here we link GLES directly, so this call cannot be missing.
    // Cheap, and idempotent when the chain is already there.
    glBindTexture(GL_TEXTURE_2D, tex);
    glGenerateMipmap(GL_TEXTURE_2D);
    const GLenum mipErr = glGetError();
    glBindTexture(GL_TEXTURE_2D, 0);
#ifdef DEBUG
    std::cerr << "Loaded texture " << file.lowerCaseBaseName << " id " << tex
              << " mipmaps " << (mipErr == GL_NO_ERROR ? "ok" : "ERREUR")
              << std::endl;
#else
    (void)mipErr;
#endif

    uint32_t memoryBytes = width * height * 4; // RGBA, unsigned byte color channels.
    auto newTexture = std::make_shared<Texture>(unqualifiedName, tex, GL_TEXTURE_2D, width, height, true);
    m_textures[file.lowerCaseBaseName] = newTexture;
    m_textureStats.insert({file.lowerCaseBaseName, {memoryBytes}});

    return newTexture;
}

auto TextureManager::PickRandomTextureFile(const std::string& randomName, uint64_t seed) -> std::string
{
    const std::lock_guard<std::recursive_mutex> lock(m_mutex);
    std::string selectedFilename;

    // A zero seed keeps MilkDrop's behaviour: a fresh draw on every preset load.
    // A non-zero one makes the draw reproducible for whoever passes the same
    // value - that is how the preload worker resolves the file the render
    // thread will want, before the render thread has parsed the preset.
    std::random_device rndDevice;
    std::mt19937_64 rndEngine(seed != 0 ? seed : static_cast<uint64_t>(rndDevice()));

    ScanTextures();

    std::string lowerCaseName = Utils::ToLower(randomName);

    if (m_scannedTextureFiles.empty())
    {
        return {};
    }

    std::string prefix;
    if (lowerCaseName.length() > 7 && lowerCaseName.at(6) == '_')
    {
        prefix = lowerCaseName.substr(7);
    }

    if (prefix.empty())
    {
        // Just pick a random index.
        std::uniform_int_distribution<size_t> distribution(0, m_scannedTextureFiles.size() - 1);
        selectedFilename = m_scannedTextureFiles.at(distribution(rndEngine)).lowerCaseBaseName;
    }
    else
    {

        std::vector<ScannedFile> filteredFiles;
        auto prefixLength = prefix.length();
        std::copy_if(m_scannedTextureFiles.begin(), m_scannedTextureFiles.end(),
                     std::back_inserter(filteredFiles),
                     [&prefix, prefixLength](const ScannedFile& file) {
                         return file.lowerCaseBaseName.substr(0, prefixLength) == prefix;
                     });

        if (!filteredFiles.empty())
        {
            std::uniform_int_distribution<size_t> distribution(0, filteredFiles.size() - 1);
            selectedFilename = filteredFiles.at(distribution(rndEngine)).lowerCaseBaseName;
        }
    }

    // If a prefix was set and no file matched, filename can be empty.
    return selectedFilename;
}

auto TextureManager::GetRandomTexture(const std::string& randomName,bool dontLoad,uint64_t seed) -> TextureSamplerDescriptor
{
    const std::lock_guard<std::recursive_mutex> lock(m_mutex);

    const std::string selectedFilename = PickRandomTextureFile(randomName, seed);
    if (selectedFilename.empty())
    {
        return {};
    }

    if (dontLoad) return {nullptr, nullptr, randomName, randomName};

    // Use selected filename to load the texture.
    auto desc = GetTexture(selectedFilename,dontLoad);

    // Create new descriptor with the original "rand00[_prefix]" name.
    return {desc.Texture(), desc.Sampler(), randomName, randomName};
}

std::string TextureManager::GetRandomTextureNoLoad(const std::string& randomName,uint64_t seed)
{
    return PickRandomTextureFile(randomName, seed);
}


void TextureManager::AddTextureFile(const std::string& fileName, const std::string& baseName)
{
    std::string lowerCaseBaseName = Utils::ToLower(baseName);

    ScannedFile file;
    file.filePath = fileName;
    file.lowerCaseBaseName = lowerCaseBaseName;

    m_scannedTextureFiles.push_back(std::move(file));
}

void TextureManager::ExtractTextureSettings(const std::string& qualifiedName, GLint& wrapMode, GLint& filterMode, std::string& name)
{
    if (qualifiedName.length() <= 3 || qualifiedName.at(2) != '_')
    {
        name = qualifiedName;
        std::string lowerQualifiedName = Utils::ToLower(qualifiedName);
        //Is it an internal texture
        if ( (lowerQualifiedName == "main") ||
            (name.substr(0,4) == "blur") ||
            (name.substr(0,4) == "rand") ||
            (name.substr(0,5) == "noise")||
            (name.substr(0,4) == "idle") ){
            filterMode = GL_LINEAR;
            wrapMode = GL_REPEAT;
        } else {
            //Or a texture from shader
            filterMode = GL_LINEAR_MIPMAP_LINEAR;
            wrapMode = GL_REPEAT;
        }
        
        return;
    }

    std::string lowerQualifiedName = Utils::ToLower(qualifiedName);

    // Default mode for user textures is "fw" (bilinear filtering + wrap).
    wrapMode = GL_REPEAT;
    filterMode = GL_LINEAR;

    if (lowerQualifiedName.substr(0, 3) == "fc_" || lowerQualifiedName.substr(0, 3) == "cf_")
    {
        name = qualifiedName.substr(3);
        filterMode = GL_LINEAR;
        wrapMode = GL_CLAMP_TO_EDGE;
    }
    else if (lowerQualifiedName.substr(0, 3) == "fw_" || lowerQualifiedName.substr(0, 3) == "wf_")
    {
        name = qualifiedName.substr(3);
        filterMode = GL_LINEAR;
        wrapMode = GL_REPEAT;
    }
    else if (lowerQualifiedName.substr(0, 3) == "pc_" || lowerQualifiedName.substr(0, 3) == "cp_")
    {
        name = qualifiedName.substr(3);
        filterMode = GL_NEAREST;
        wrapMode = GL_CLAMP_TO_EDGE;
    }
    else if (lowerQualifiedName.substr(0, 3) == "pw_" || lowerQualifiedName.substr(0, 3) == "wp_")
    {
        name = qualifiedName.substr(3);
        filterMode = GL_NEAREST;
        wrapMode = GL_REPEAT;
    }
    else
    {
        name = qualifiedName.substr(3); // Milkdrop also removes the XY_ prefix in the case nothing matches.
        filterMode = GL_LINEAR;
        wrapMode = GL_REPEAT;
    }
}

void TextureManager::ScanTextures()
{
    const std::lock_guard<std::recursive_mutex> lock(m_mutex);
    if (!m_filesScanned)
    {
        //add current presetDir if available to search paths
        std::vector<std::string> searchPaths;
        searchPaths=m_textureSearchPaths;
        if (m_currentPresetDir!=std::string("")) searchPaths.emplace_back(m_currentPresetDir);
        
        FileScanner fileScanner = FileScanner(searchPaths, m_extensions);

        using namespace std::placeholders;
        fileScanner.Scan(std::bind(&TextureManager::AddTextureFile, this, _1, _2));
        m_filesScanned = true;
        
    }
}

} // namespace Renderer
} // namespace libprojectM
