#pragma once

#include "UserSprites/Sprite.hpp"

#include <Renderer/RenderContext.hpp>

#include <cstdint>
#include <list>
#include <set>
#include <utility>
#include <vector>

namespace libprojectM {
namespace UserSprites {

class SpriteManager
{
public:
    using SpriteIdentifier = uint32_t;

    /**
     * @brief Which preset a sprite belongs to.
     *
     * A preset sprite ([SPRITEn_BEGIN] in a .milk) lives and dies with its preset, so
     * during a soft cut TWO sets are alive at once and each has to follow its own preset:
     * the outgoing one fades out, the incoming one fades in. Destroying everything at
     * switch time - which is what used to happen - made the outgoing sprite vanish on the
     * first frame of the transition and the incoming one appear at full strength, the one
     * hard edge in an otherwise smooth blend.
     */
    enum class Slot : int
    {
        Current = 0,       //!< Sprites of the preset currently being displayed.
        Transitioning = 1, //!< Sprites of the preset being transitioned to.
    };

    /**
     * @brief Spawns a new sprite.
     * @param type The type name of the sprite.
     * @param spriteData The sprite code/data, depending on the type.
     * @return A unique, non-zero identifier if the sprite was successfully spawned, or zero if an error occurred.
     */
    auto Spawn(const std::string& type,
               const std::string& spriteData,
               const Renderer::RenderContext& renderContext,
               Slot slot = Slot::Current) -> SpriteIdentifier;

    /**
     * @brief Destroys the sprites of one slot, making room for a preset's own.
     * Called when a preset is loaded into that slot.
     */
    void ClearSlot(Slot slot);

    /**
     * @brief The transitioning preset became the current one: its sprites take over and
     * the ones of the preset that just went away are destroyed.
     */
    void PromoteTransitionSlot();

    /**
     * @brief Selects whose sprites the next DrawEmbedded() call draws.
     * Set by ProjectM before each preset renders - during a soft cut two presets render in
     * the same frame and each must stamp only its own.
     */
    void EmbeddedSlot(Slot slot);

    /**
     * @brief Runs every active sprite's per-frame code. Call once per frame, before the
     * presets render: both draw passes below only submit what this computed.
     * @param audioData The frame audio data structure.
     * @param renderContext The current frame's rendering context.
     */
    void UpdateFrame(const Audio::FrameAudioData& audioData,
                     const Renderer::RenderContext& renderContext);

    /**
     * @brief Stamps every sprite that burns in (or lives on layer >= 1) into the currently
     * bound framebuffer. Called by the preset from inside its own frame - see
     * Sprite::DrawEmbedded.
     */
    void DrawEmbedded();

    /**
     * @brief Draws the layer-0 copies on top of the finished frame and reaps finished sprites.
     * @param audioData The frame audio data structure.
     * @param renderContext The current frame's rendering context.
     * @param outputFramebufferObject Framebuffer object the sprite will be rendered to.
     */
    void Draw(const Audio::FrameAudioData& audioData,
              const Renderer::RenderContext& renderContext,
              uint32_t outputFramebufferObject);

    /**
     * @brief Destroys a single active sprite.
     *
     * If spriteIdentifier is invalid, no action will be taken.
     *
     * @param spriteIdentifier The identifier of the sprite to destroy.
     */
    void Destroy(SpriteIdentifier spriteIdentifier);

    /**
     * @brief Destroys all active sprites.
     *
     * Sprites will be removed when drawing the next frame.
     */
    void DestroyAll();

    /**
     * @brief Returns the current number of active sprites.
     * @return The current number of active sprites.
     */
    auto ActiveSpriteCount() const -> uint32_t;

    /**
     * @brief Returns a set of identifiers for all active sprites.
     * @return A vector with the identifiers of all active sprites.
     */
    auto ActiveSpriteIdentifiers() const -> std::vector<SpriteIdentifier>;

    /**
     * @brief Sets the number of available sprite slots, e.g. the number of concurrently active sprites.
     * If there are more active sprites than the newly set limit, the oldest sprites will be destroyed
     * in order until the new limit is matched.
     * @param slots The maximum number of active sprites. 0 disables user sprites. Default is 16.
     */
    void SpriteSlots(uint32_t slots);

    /**
     * @brief Returns the currently set maximum number of active sprites.
     * @return The maximum number of active sprites.
     */
    auto SpriteSlots() const -> uint32_t;

private:
    struct ActiveSprite
    {
        SpriteIdentifier identifier{};
        Sprite::Ptr sprite;
        Slot slot{Slot::Current};
    };

    /**
     * Returns the lowest free ID, starting at 1.
     * @return The lowest available/unused sprite ID.
     */
    SpriteIdentifier GetLowestFreeIdentifier();

    uint32_t m_spriteSlots{16};                     //!< Max number of active sprites.
    std::set<SpriteIdentifier> m_spriteIdentifiers; //!< Set to keep track of ordered sprite IDs.
    std::list<ActiveSprite> m_sprites;              //!< Active sprites with their identifier and owner.
    Slot m_embeddedSlot{Slot::Current};             //!< Whose sprites DrawEmbedded() draws.
};

} // namespace UserSprites
} // namespace libprojectM
