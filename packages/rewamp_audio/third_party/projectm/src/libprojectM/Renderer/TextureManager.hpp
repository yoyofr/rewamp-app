#pragma once

#include "Renderer/TextureSamplerDescriptor.hpp"

#include <map>
#include <mutex>
#include <string>
#include <vector>

namespace libprojectM {
namespace Renderer {

class TextureManager
{
public:
    TextureManager() = delete;

    /**
     * Constructor.
     * @param textureSearchPaths List of paths to search for textures. These paths are searched in the given order.
     */
    TextureManager(const std::vector<std::string>& textureSearchPaths);

    ~TextureManager() = default;

    /**
     * @brief Sets the current preset path to search for textures in addition to the configured paths.
     * @param path
     */
    void SetCurrentPresetPath(const std::string& path);

    /**
     * @brief Loads a texture and returns a descriptor with the given name.
     * Resets the texture age to zero.
     * @param fullName
     * @return
     */
    auto GetTexture(const std::string& fullName,bool dontLoad=false) -> TextureSamplerDescriptor;

    /**
     * @brief Like GetTexture, but with texels of @p colorKey turned transparent.
     *
     * MilkDrop applies the sprite colour key when the image is LOADED (D3DX's
     * ColorKey argument), which builds an alpha channel even on a JPEG that has
     * none; blend mode 4 then tests that alpha. OpenGL has no such texture
     * state, so the keying has to happen on the pixels here.
     *
     * Cached separately from the plain texture (key + "#ck" + value): the same
     * file is often ALSO used as an ordinary texture by other presets, and that
     * copy must keep its opaque background.
     *
     * @param fullName Texture name as in a preset.
     * @param colorKey 0xRRGGBB. Exact matches only, as in D3DX.
     */
    auto GetTextureColorKeyed(const std::string& fullName, uint32_t colorKey) -> TextureSamplerDescriptor;

    /**
     * @brief Returns a random texture descriptor, optionally using a prefix (after the `randXX_` name).
     * Will use the default texture loading logic by calling GetTexture() if a texture was selected.
     * @param randomName The filename prefix to filter. If empty, all available textures are matches. Case-insensitive.
     * @return A texture descriptor with the random texture and a default sampler, or an empty sampler if no texture could be matched.
     */
    auto GetRandomTexture(const std::string& randomName,bool dontLoad=false,uint64_t seed=0) -> TextureSamplerDescriptor;
    std::string GetRandomTextureNoLoad(const std::string& randomName,uint64_t seed=0);

    /**
     * @brief Returns a sampler for the given name.
     * Does not load any texture, only analyzes the prefix.
     * @param fullName The name of the sampler as used in the preset.
     * @return A sampler with the prefixed mode, or the default settings.
     */
    auto GetSampler(const std::string& fullName) -> std::shared_ptr<class Sampler>;

    /**
     * @brief Purges unused textures and increments the age counter of all stored textures.
     * Also resets the scanned texture list. Must be called exactly once per preset load.
     */
    void PurgeTextures();

private:
    /**
     * Texture usage statistics. Used to determine when to purge a texture.
     */
    struct UsageStats {
        UsageStats(uint32_t size)
            : sizeBytes(size){};

        uint32_t age{};       //!< Age of the texture. Represents the number of presets loaded since it was last retrieved.
        uint32_t sizeBytes{}; //!< The texture in-memory size in bytes.
    };

    /**
     * A scanned texture file on the disk.
     */
    struct ScannedFile {
        std::string filePath;          //!< Full path to the texture file
        std::string lowerCaseBaseName; //!< Texture base file name, lower case.
    };

    /**
     * @brief Picks the file a randNN sampler resolves to. Shared by the two
     * public entry points, which only differ in what they do with the result.
     * @param randomName The preset's sampler name ("rand00", "rand02_prefix").
     * @param seed 0 = draw from random_device, as MilkDrop does. Non-zero =
     *        reproducible draw, so the preload worker and the render thread can
     *        agree on the same file. Note this only holds while the scanned file
     *        list is the same on both sides, which is NOT guaranteed (the list
     *        includes the current preset's directory) - hence the resolved names
     *        travel alongside the seed instead of being re-drawn on arrival.
     * @return The lower-case base name, or empty if nothing matched.
     */
    auto PickRandomTextureFile(const std::string& randomName, uint64_t seed) -> std::string;

    auto TryLoadingTexture(const std::string& name) -> TextureSamplerDescriptor;

    void Preload();

    auto LoadTexture(const ScannedFile& file) -> std::shared_ptr<Texture>;

    auto LoadTextureColorKeyed(const ScannedFile& file, uint32_t colorKey,
                               const std::string& cacheKey) -> std::shared_ptr<Texture>;

    void AddTextureFile(const std::string& fileName, const std::string& baseName);

    static void ExtractTextureSettings(const std::string& qualifiedName, GLint& wrapMode, GLint& filterMode, std::string& name);

    void ScanTextures();

    std::vector<std::string> m_textureSearchPaths;  //!< Search paths to scan for textures.
    std::string m_currentPresetDir;                 //!< Path of the current preset to add to the search list.
    //! Guards every mutable member below. The preload worker (a second GL
    //! context in the same share group) now warms textures for the NEXT preset
    //! while the render thread samples the current one, so the caches are
    //! genuinely shared. Recursive because the public entry points call each
    //! other (GetTexture -> TryLoadingTexture -> LoadTexture).
    //!
    //! It guards the BOOKKEEPING, not the pixels: Textures are held by
    //! shared_ptr, so a purge on one thread cannot pull a texture out from
    //! under a frame that already holds it.
    mutable std::recursive_mutex m_mutex;

    std::vector<ScannedFile> m_scannedTextureFiles; //!< The cached list with scanned texture files.
    bool m_filesScanned{false};                     //!< true if files were scanned since last preset load.

    std::shared_ptr<Texture> m_placeholderTexture;                          //!< Texture used if a requested file couldn't be found. A black 1x1 texture.
    std::map<std::string, std::shared_ptr<Texture>> m_textures;             //!< All loaded textures, including generated ones.
    std::map<std::pair<GLint, GLint>, std::shared_ptr<Sampler>> m_samplers; //!< The four sampler objects for each combination of wrap and filter modes.
    std::map<std::string, UsageStats> m_textureStats;                       //!< Map with texture stats for user-loaded files.
    std::vector<std::string> m_randomTextures;
    //! ".jfif" is JPEG under another name, and MilkDrop 3 ships sprites with it
    //! (face5.jfif is referenced by a preset of the milkdrop3 pack). Without it
    //! the scan skips the file and the sprite silently draws nothing.
    std::vector<std::string> m_extensions{".jpg", ".jpeg", ".jfif", ".dds", ".png", ".tga", ".bmp", ".dib"};
};

} // namespace Renderer
} // namespace libprojectM
