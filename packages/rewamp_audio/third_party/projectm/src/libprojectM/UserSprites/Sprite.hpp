#pragma once

#include <Preset.hpp>

#include <Audio/FrameAudioData.hpp>

#include <Renderer/RenderContext.hpp>

#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <vector>

namespace libprojectM {
namespace UserSprites {

class Sprite
{
public:
    using Ptr = std::unique_ptr<Sprite>;

    virtual ~Sprite() = default;

    /**
     * @brief Initializes the sprite instance for rendering.
     * @param spriteData The data for the sprite type.
     * @param renderContext The current frame's rendering context.
     */
    virtual void Init(const std::string& spriteData, const Renderer::RenderContext& renderContext) = 0;

    /**
     * @brief Runs the sprite's per-frame code and rebuilds its geometry.
     *
     * Called exactly ONCE per frame, before any preset renders. The two draw calls below
     * only submit what this computed: during a transition two presets render and each one
     * stamps the embedded copy, which must not advance the sprite's code twice.
     *
     * @param audioData The frame audio data structure.
     * @param renderContext The current frame's rendering context.
     */
    virtual void Update(const Audio::FrameAudioData& audioData,
                        const Renderer::RenderContext& renderContext) = 0;

    /**
     * @brief Draws the copy that is stamped INTO the preset's own image.
     *
     * Called from inside the preset's frame, into whatever framebuffer it has bound, at the
     * point MilkDrop stamps sprites: after the warp mesh, before the shapes, the border and
     * the composite. That is what makes the copy get warped and composited like any other
     * preset content, in the SAME frame - drawing it after the composite showed it one frame
     * late, already warped once.
     *
     * Draws nothing unless the sprite burns in or is a layer >= 1 sprite.
     */
    virtual void DrawEmbedded() = 0;

    /**
     * @brief Draws the crisp copy on top of the finished frame (layer 0).
     * @param audioData The frame audio data structure.
     * @param renderContext The current frame's rendering context.
     * @param outputFramebufferObject Framebuffer object the sprite will be rendered to.
     * @param fade 1.0 outside a transition; during one, how much of the sprite's OWN
     *             preset is currently showing. This copy is drawn over the finished
     *             frame, so the transition's blend of the two preset images does not
     *             touch it and it has to be faded here.
     */
    virtual void Draw(const Audio::FrameAudioData& audioData,
                      const Renderer::RenderContext& renderContext,
                      uint32_t outputFramebufferObject,
                      float fade) = 0;

    /**
     * @brief Returns if the sprite has finished rendering and should be deleted.
     * @return true if the sprite should be deleted, false if not.
     */
    virtual auto Done() const -> bool = 0;
};

} // namespace UserSprites
} // namespace libprojectM
