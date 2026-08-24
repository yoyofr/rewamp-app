#include "UserSprites/SpriteManager.hpp"

#include "UserSprites/Factory.hpp"
#include "UserSprites/SpriteException.hpp"

#include <Renderer/Shader.hpp>

#include <algorithm>

namespace libprojectM {
namespace UserSprites {

auto SpriteManager::Spawn(const std::string& type,
                          const std::string& spriteData,
                          const Renderer::RenderContext& renderContext,
                          Slot slot) -> uint32_t
{
    // If user set the limit to zero, don't bother.
    if (m_spriteSlots == 0)
    {
        return 0;
    }

    auto sprite = Factory::CreateSprite(type);

    if (!sprite)
    {
        return 0;
    }

    try
    {
        sprite->Init(spriteData, renderContext);
    }
    catch (SpriteException& ex)
    {
        return 0;
    }
    catch (Renderer::ShaderException& ex)
    {
        return 0;
    }
    catch (...)
    {
        return 0;
    }

    auto spriteIdentifier = GetLowestFreeIdentifier();

    // Already at max sprites, destroy the oldest sprite to make room.
    if (m_sprites.size() == m_spriteSlots)
    {
        Destroy(m_sprites.front().identifier);
    }

    m_sprites.push_back({spriteIdentifier, std::move(sprite), slot});
    m_spriteIdentifiers.insert(spriteIdentifier);

    return spriteIdentifier;
}

void SpriteManager::ClearSlot(Slot slot)
{
    for (const auto& active : m_sprites)
    {
        if (active.slot == slot)
        {
            m_spriteIdentifiers.erase(active.identifier);
        }
    }
    m_sprites.remove_if([slot](const ActiveSprite& active) { return active.slot == slot; });
}

void SpriteManager::PromoteTransitionSlot()
{
    // Unconditional: called only when a transitioning preset really did become the current
    // one, and an incoming preset with NO sprites is exactly the case where the outgoing
    // one must still be dropped. Guarding on "does the incoming slot hold anything" left
    // the old sprite on screen for good when switching to a sprite-less preset.
    ClearSlot(Slot::Current);
    for (auto& active : m_sprites)
    {
        active.slot = Slot::Current;
    }
}

void SpriteManager::EmbeddedSlot(Slot slot)
{
    m_embeddedSlot = slot;
}

void SpriteManager::UpdateFrame(const Audio::FrameAudioData& audioData,
                                const Renderer::RenderContext& renderContext)
{
    for (auto& active : m_sprites)
    {
        active.sprite->Update(audioData, renderContext);
    }
}

void SpriteManager::DrawEmbedded()
{
    for (auto& active : m_sprites)
    {
        if (active.slot != m_embeddedSlot)
        {
            continue;
        }
        active.sprite->DrawEmbedded();
    }
}

void SpriteManager::Draw(const Audio::FrameAudioData& audioData,
                         const Renderer::RenderContext& renderContext,
                         uint32_t outputFramebufferObject)
{
    std::vector<SpriteIdentifier> toDestroy;

    // How much of the incoming preset is showing. blendProgress is 0 outside a transition,
    // so the current preset's sprites come out at 1 - 0 = 1 and no separate "are we
    // transitioning" flag is needed - one that was derived from the sprites themselves got
    // this wrong the moment the incoming preset had none.
    const float incoming = std::min(1.0f, std::max(0.0f, renderContext.blendProgress));

    for (auto& active : m_sprites) {
        const float fade = (active.slot == Slot::Transitioning) ? incoming : 1.0f - incoming;
        active.sprite->Draw(audioData, renderContext, outputFramebufferObject, fade);

        if (active.sprite->Done())
        {
            toDestroy.push_back(active.identifier);
        }
    }

    for (auto id : toDestroy)
    {
        Destroy(id);
    }
}

void SpriteManager::Destroy(SpriteIdentifier spriteIdentifier)
{
    if (m_spriteIdentifiers.find(spriteIdentifier) == m_spriteIdentifiers.end())
    {
        return;
    }

    m_spriteIdentifiers.erase(spriteIdentifier);
    m_sprites.remove_if([spriteIdentifier](const ActiveSprite& active) {
        return active.identifier == spriteIdentifier;
    });
}

void SpriteManager::DestroyAll()
{
    m_spriteIdentifiers.clear();
    m_sprites.clear();
}

auto SpriteManager::ActiveSpriteCount() const -> uint32_t
{
    return m_sprites.size();
}

auto SpriteManager::ActiveSpriteIdentifiers() const -> std::vector<SpriteIdentifier>
{
    std::vector<SpriteIdentifier> identifierList;
    for (auto& active : m_sprites)
    {
        identifierList.emplace_back(active.identifier);
    }

    return identifierList;
}

void SpriteManager::SpriteSlots(uint32_t slots)
{
    m_spriteSlots = slots;

    // Remove excess sprites if limit was lowered
    while (m_sprites.size() > slots)
    {
        m_spriteIdentifiers.erase(m_sprites.front().identifier);
        m_sprites.pop_front();
    }
}

auto SpriteManager::SpriteSlots() const -> uint32_t
{
    return m_spriteSlots;
}

auto SpriteManager::GetLowestFreeIdentifier() -> SpriteIdentifier
{
    SpriteIdentifier lowestId = 0;

    for (const auto& spriteId : m_spriteIdentifiers)
    {
        if (spriteId > lowestId + 1)
        {
            return lowestId + 1;
        }

        lowestId = spriteId;
    }

    return lowestId + 1;
}

} // namespace UserSprites
} // namespace libprojectM
