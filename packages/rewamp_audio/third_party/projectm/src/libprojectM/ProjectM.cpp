/**
* projectM -- Milkdrop-esque visualisation SDK
* Copyright (C)2003-2004 projectM Team
*
* This library is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) any later version.
*
* This library is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* Lesser General Public License for more details.
*
* You should have received a copy of the GNU Lesser General Public
* License along with this library; if not, write to the Free Software
* Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
* See 'LICENSE.txt' included within this release
*
*/

#include "ProjectM.hpp"

#include "Preset.hpp"
#include "PresetFactoryManager.hpp"
#include "TimeKeeper.hpp"

#include <Audio/PCM.hpp>

#include <Renderer/CopyTexture.hpp>
#include <Renderer/PresetTransition.hpp>
#include <Renderer/TextureManager.hpp>
#include <Renderer/ShaderCache.hpp>
#include <Renderer/TransitionShaderManager.hpp>

#include <UserSprites/SpriteManager.hpp>

#include <algorithm>
#include <filesystem>
#include <random>

namespace libprojectM {

ProjectM::ProjectM()
    : m_presetFactoryManager(std::make_unique<PresetFactoryManager>())
{
    Initialize();
}

ProjectM::~ProjectM()
{
    // Can't use "=default" in the header due to unique_ptr requiring the actual type declarations.
}

void ProjectM::PresetSwitchRequestedEvent(bool) const
{
}

void ProjectM::PresetSwitchFailedEvent(const std::string&, const std::string&) const
{
}

void ProjectM::LoadPresetFile(const std::string& presetFilename, bool smoothTransition)
{
    try
    {
        const auto curPresetDir = std::filesystem::path{ presetFilename }.parent_path().string();
        m_textureManager->SetCurrentPresetPath(curPresetDir);
        
        m_textureManager->PurgeTextures();
        StartPresetTransition(m_presetFactoryManager->CreatePresetFromFile(presetFilename), !smoothTransition);
    }
    catch (const std::exception& ex)
    {
        PresetSwitchFailedEvent(presetFilename, ex.what());
    }
}

void ProjectM::PreLoadPresetFile(const std::string& presetFilename,uint32_t *warpP,uint32_t *compP,uint64_t *randSeed)
{
    try
    {
        // rewamp: NO m_textureManager->SetCurrentPresetPath / PurgeTextures here.
        // This runs on the preload worker CONCURRENTLY with rendering — purging
        // would delete textures the in-flight frame is sampling. The apply path
        // (LoadPreLoadPresetFile, render thread) does both anyway.
        //StartPresetTransition(m_presetFactoryManager->CreatePresetFromFile(presetFilename), !smoothTransition);
        std::unique_ptr<Preset> preloaded_preset=m_presetFactoryManager->CreatePresetFromFile(std::string("preload://")+presetFilename);

        // A fresh seed per preload job: randNN stays random from one load to the
        // next, exactly as in MilkDrop. What changes is that the draw is now
        // REPRODUCIBLE for whoever holds the seed, so this pass can resolve the
        // files and warm them while the render thread is still on the previous
        // preset. Non-zero, since 0 means "no seed" downstream.
        uint64_t seed = 0;
        // PM_NO_RANDWARM=1 hands over no seed, which turns the whole mechanism
        // off (nothing resolved, nothing warmed, render thread draws its own) -
        // an A/B switch inside ONE binary, so a comparison never has to relink a
        // "before" probe, which is exactly how two measurements got confused.
        static const bool randWarmDisabled = (getenv("PM_NO_RANDWARM") != nullptr);
        if (!randWarmDisabled)
        {
            std::random_device rndDevice;
            seed = (static_cast<uint64_t>(rndDevice()) << 32) ^ static_cast<uint64_t>(rndDevice());
            if (seed == 0) seed = 1;
        }
        preloaded_preset->SetRandomTextures(seed, {});

        preloaded_preset->Initialize(GetRenderContext());
        uint32_t warpProg,compProg;
        preloaded_preset->GetShadersCode(&warpProg,&compProg);
        *warpP=warpProg;
        *compP=compProg;

        // Keep the resolved names in-process, keyed by the seed. Only the seed
        // crosses the C API; re-drawing on arrival would NOT give the same files
        // (the scanned list includes the current preset's directory, which this
        // pass deliberately never switches).
        std::map<int, std::string> randomFiles;
        uint64_t reportedSeed = seed;
        preloaded_preset->GetRandomTextures(reportedSeed, randomFiles);
        m_preloadRandomTextures[seed] = std::move(randomFiles);
        m_preloadRandomTextureOrder.push_back(seed);
        // A preload whose preset is never applied leaves its entry behind - the
        // worker runs ahead of every switch, and the prediction can miss.
        while (m_preloadRandomTextureOrder.size() > 8)
        {
            m_preloadRandomTextures.erase(m_preloadRandomTextureOrder.front());
            m_preloadRandomTextureOrder.erase(m_preloadRandomTextureOrder.begin());
        }

        if (randSeed != nullptr) *randSeed = seed;
    }
    catch (const std::exception& ex)
    {
        PresetSwitchFailedEvent(presetFilename, ex.what());
    }
}

void ProjectM::LoadPreLoadPresetFile(const std::string& presetFilename,uint32_t warpP,uint32_t compP, bool smoothTransition,uint64_t randSeed)
{
    try
    {
        const auto curPresetDir = std::filesystem::path{ presetFilename }.parent_path().string();
        m_textureManager->SetCurrentPresetPath(curPresetDir);
        
        m_textureManager->PurgeTextures();
        //StartPresetTransition(m_presetFactoryManager->CreatePresetFromFile(presetFilename), !smoothTransition);
        std::unique_ptr<Preset> preloaded_preset=m_presetFactoryManager->CreatePresetFromFile(std::string("precomp://")+presetFilename);
        preloaded_preset->SetShadersCode(warpP,compP);
        // Hand over the randNN files the matching preload resolved and warmed.
        // Consumed here: the entry is of no use to anyone else, and the preset
        // it belongs to is being applied right now.
        if (randSeed != 0)
        {
            const auto it = m_preloadRandomTextures.find(randSeed);
            if (it != m_preloadRandomTextures.end())
            {
                preloaded_preset->SetRandomTextures(randSeed, it->second);
                m_preloadRandomTextures.erase(it);
                m_preloadRandomTextureOrder.erase(
                    std::remove(m_preloadRandomTextureOrder.begin(),
                                m_preloadRandomTextureOrder.end(), randSeed),
                    m_preloadRandomTextureOrder.end());
            }
            else
            {
                // Names gone (evicted): the seed alone still beats nothing.
                preloaded_preset->SetRandomTextures(randSeed, {});
            }
        }
        StartPresetTransition(std::move(preloaded_preset), !smoothTransition);
    }
    catch (const std::exception& ex)
    {
        PresetSwitchFailedEvent(presetFilename, ex.what());
    }
}



int ProjectM::PreloadedRandomTextureCount(uint64_t randSeed) const
{
    const auto it = m_preloadRandomTextures.find(randSeed);
    return it == m_preloadRandomTextures.end() ? 0 : static_cast<int>(it->second.size());
}

std::vector<uint32_t> ProjectM::GetTransitionShaderPrograms() const
{
    if (!m_transitionShaderManager)
    {
        return {};
    }
    return m_transitionShaderManager->ShaderPrograms();
}

void ProjectM::PreloadTexture(const std::string& name, int colorKey)
{
    if (!m_textureManager || name.empty())
    {
        return;
    }
    try
    {
        if (colorKey >= 0)
        {
            m_textureManager->GetTextureColorKeyed(name, static_cast<uint32_t>(colorKey));
        }
        else
        {
            m_textureManager->GetTexture(name);
        }
    }
    catch (...)
    {
        // A texture that cannot be warmed is simply loaded later, on the render
        // thread, exactly as before. Never let it take the worker down.
    }
}

void ProjectM::SetTransitionIndex(int index)
{
    if (m_transitionShaderManager)
    {
        m_transitionShaderManager->ForcedTransitionIndex(index);
    }
}

int ProjectM::TransitionCount() const
{
    return m_transitionShaderManager ? m_transitionShaderManager->TransitionCount() : 0;
}

void ProjectM::LoadPresetData(std::istream& presetData, bool smoothTransition)
{
    try
    {
        m_textureManager->PurgeTextures();
        StartPresetTransition(m_presetFactoryManager->CreatePresetFromStream(".milk", presetData), !smoothTransition);
    }
    catch (const std::exception& ex)
    {
        PresetSwitchFailedEvent("", ex.what());
    }
}

void ProjectM::SetTexturePaths(std::vector<std::string> texturePaths)
{
    m_textureSearchPaths = std::move(texturePaths);
    m_textureManager = std::make_unique<Renderer::TextureManager>(m_textureSearchPaths);
}

void ProjectM::ResetTextures()
{
    m_textureManager = std::make_unique<Renderer::TextureManager>(m_textureSearchPaths);
}

void ProjectM::RenderFrame(uint32_t targetFramebufferObject /*= 0*/)
{
    // Don't render if window area is zero.
    if (m_windowWidth == 0 || m_windowHeight == 0)
    {
        return;
    }

    // Update FPS and other timer values.
    m_timeKeeper->UpdateTimers();

    // Update and retrieve audio data
    m_audioStorage.UpdateFrameAudioData(m_timeKeeper->SecondsSinceLastFrame(), m_frameCount);
    auto audioData = m_audioStorage.GetFrameAudioData();
    
    // If preset is locked, reset timer if progress has reached 1.0
    if (m_presetLocked) {
        if (m_timeKeeper->PresetProgressA() >= 1.0 ) m_timeKeeper->StartPreset();
    }

    // Check if the preset isn't locked, and we've not already notified the user
    if (!m_presetChangeNotified)
    {
        // If preset is done and we're not already switching
        if (m_timeKeeper->PresetProgressA() >= 1.0 && !m_timeKeeper->IsSmoothing())
        {
            m_presetChangeNotified = true;
            PresetSwitchRequestedEvent(false);
        }
        else if (m_hardCutEnabled &&
                 m_frameCount > 50 &&
                 (audioData.vol - m_previousFrameVolume > m_hardCutSensitivity) &&
                 m_timeKeeper->CanHardCut())
        {
            m_presetChangeNotified = true;
            PresetSwitchRequestedEvent(true);
        }
    }

    // If no preset is active, load the idle preset.
    if (!m_activePreset)
    {
        LoadIdlePreset();
        if (!m_activePreset)
        {
            return;
        }

        m_activePreset->Initialize(GetRenderContext());
    }

    if (m_timeKeeper->IsSmoothing() && m_transitioningPreset != nullptr)
    {
        // ToDo: check if new preset is loaded.

        if (m_timeKeeper->SmoothRatio() >= 1.0)
        {
            m_timeKeeper->EndSmoothing();
        }
    }

    auto renderContext = GetRenderContext();

    // Advance every sprite's per-frame code ONCE, before any preset renders: each preset
    // then stamps the sprite into its own frame (see MilkdropPreset::RenderFrame), and
    // during a transition two presets render, which must not run the code twice.
    m_spriteManager->UpdateFrame(audioData, renderContext);

    if (m_transition != nullptr && m_transitioningPreset != nullptr)
    {
        if (m_transition->IsDone(m_timeKeeper->GetFrameTime()))
        {
            m_activePreset = std::move(m_transitioningPreset);
            m_transitioningPreset.reset();
            m_transition.reset();
            m_spriteManager->PromoteTransitionSlot();
        }
        else
        {
            // Each preset stamps its OWN sprites; both render this frame.
            m_spriteManager->EmbeddedSlot(UserSprites::SpriteManager::Slot::Transitioning);
            m_transitioningPreset->RenderFrame(audioData, renderContext);
        }
    }


    // ToDo: Call the to-be-implemented render method in Renderer
    m_spriteManager->EmbeddedSlot(UserSprites::SpriteManager::Slot::Current);
    m_activePreset->RenderFrame(audioData, renderContext);

    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, static_cast<GLuint>(targetFramebufferObject));

    if (m_transition != nullptr && m_transitioningPreset != nullptr)
    {
        m_transition->Draw(*m_activePreset, *m_transitioningPreset, renderContext, audioData, m_timeKeeper->GetFrameTime());
    }
    else
    {
        m_textureCopier->Draw(m_activePreset->OutputTexture(), false, false);
    }

    // Draw the layer-0 sprite copies over the finished frame. The copies stamped INTO the
    // preset image were already drawn, mid-frame, by the preset itself.
    m_spriteManager->Draw(audioData, renderContext, targetFramebufferObject);

    m_frameCount++;
    m_previousFrameVolume = audioData.vol;
}

void ProjectM::Initialize()
{
    /** Initialise start time */
    m_timeKeeper = std::make_unique<TimeKeeper>(m_presetDuration,
                                                m_softCutDuration,
                                                m_hardCutDuration,
                                                m_easterEgg);

    /** Nullify frame stash */

    /** Initialise per-pixel matrix calculations */
    /** We need to initialise this before the builtin param db otherwise bass/mid etc won't bind correctly */
    m_textureManager = std::make_unique<Renderer::TextureManager>(m_textureSearchPaths);
    m_shaderCache = std::make_unique<Renderer::ShaderCache>();

    m_transitionShaderManager = std::make_unique<Renderer::TransitionShaderManager>();

    m_textureCopier = std::make_unique<Renderer::CopyTexture>();

    m_spriteManager = std::make_unique<UserSprites::SpriteManager>();

    m_presetFactoryManager->initialize();

    /* Set the seed to the current time in seconds */
    srand(time(nullptr));

    LoadIdlePreset();

    m_timeKeeper->StartPreset();
}

void ProjectM::LoadIdlePreset()
{
    LoadPresetFile("idle://Geiss & Sperl - Feedback (projectM idle HDR mix).milk", false);
    assert(m_activePreset);
}

void ProjectM::SetWindowSize(uint32_t width, uint32_t height)
{
    /** Stash the new dimensions */
    m_windowWidth = width;
    m_windowHeight = height;
}

void ProjectM::StartPresetTransition(std::unique_ptr<Preset>&& preset, bool hardCut)
{
    m_presetChangeNotified = m_presetLocked;

    if (preset == nullptr)
    {
        return;
    }

    preset->Initialize(GetRenderContext());

    // If already in a transition, force immediate completion.
    if (m_transitioningPreset != nullptr)
    {
        m_activePreset = std::move(m_transitioningPreset);
        m_transition.reset();
        // The preset that was coming in is now the one being displayed, so its sprites
        // are the current ones.
        m_spriteManager->PromoteTransitionSlot();
    }

    if (m_activePreset && !m_presetStartClean)
    {
        preset->DrawInitialImage(m_activePreset->OutputTexture(), GetRenderContext());
    }

    // Make room for the sprites of the preset being loaded, and ONLY those: the ones of
    // the preset still on screen keep living until the transition ends, which is what lets
    // them fade out instead of vanishing on its first frame.
    if (hardCut)
    {
        m_activePreset = std::move(preset);
        m_timeKeeper->StartPreset();
        m_spriteManager->ClearSlot(UserSprites::SpriteManager::Slot::Transitioning);
        m_spriteManager->ClearSlot(UserSprites::SpriteManager::Slot::Current);
    }
    else
    {
        m_spriteManager->ClearSlot(UserSprites::SpriteManager::Slot::Transitioning);
        m_transitioningPreset = std::move(preset);
        m_timeKeeper->StartSmoothing();
        m_transition = std::make_unique<Renderer::PresetTransition>(m_transitionShaderManager->RandomTransition(), m_softCutDuration, m_timeKeeper->GetFrameTime());
    }
}

auto ProjectM::WindowWidth() -> int
{
    return m_windowWidth;
}

auto ProjectM::WindowHeight() -> int
{
    return m_windowHeight;
}

auto ProjectM::AddUserSprite(const std::string& type, const std::string& spriteData) -> uint32_t
{
    // A sprite is spawned right after the preset that declares it was loaded, so it
    // belongs to whichever preset that load landed in: the incoming one while a soft cut
    // is running, the current one otherwise. StartPresetTransition has already emptied
    // that slot, so the two sets never mix.
    const auto slot = (m_transitioningPreset != nullptr)
                          ? UserSprites::SpriteManager::Slot::Transitioning
                          : UserSprites::SpriteManager::Slot::Current;
    return m_spriteManager->Spawn(type, spriteData, GetRenderContext(), slot);
}

void ProjectM::DestroyUserSprite(uint32_t spriteIdentifier)
{
    m_spriteManager->Destroy(spriteIdentifier);
}

void ProjectM::DestroyAllUserSprites()
{
    m_spriteManager->DestroyAll();
}

auto ProjectM::UserSpriteCount() const -> uint32_t
{
    return m_spriteManager->ActiveSpriteCount();
}

void ProjectM::SetUserSpriteLimit(uint32_t maxSprites)
{
    m_spriteManager->SpriteSlots(maxSprites);
}

auto ProjectM::UserSpriteLimit() const -> uint32_t
{
    return m_spriteManager->SpriteSlots();
}

auto ProjectM::UserSpriteIdentifiers() const -> std::vector<uint32_t>
{
    return m_spriteManager->ActiveSpriteIdentifiers();
}

void ProjectM::SetPresetLocked(bool locked)
{
    // ToDo: Add a preset switch timer separate from the display timer and reset to 0 when
    //       disabling the preset switch lock.
    m_presetLocked = locked;
    m_presetChangeNotified = locked;
}

auto ProjectM::PresetLocked() const -> bool
{
    return m_presetLocked;
}

void ProjectM::SetPresetStartClean(bool enabled)
{
    m_presetStartClean = enabled;
}

auto ProjectM::PresetStartClean() const -> bool
{
    return m_presetStartClean;
}

void ProjectM::SetFrameTime(double secondsSinceStart)
{
    m_timeKeeper->SetFrameTime(secondsSinceStart);
}

double ProjectM::GetFrameTime()
{
    return m_timeKeeper->GetFrameTime();
}

void ProjectM::SetBeatSensitivity(float sensitivity)
{
    m_beatSensitivity = std::min(std::max(0.0f, sensitivity), 2.0f);
}

auto ProjectM::GetBeatSensitivity() const -> float
{
    return m_beatSensitivity;
}

auto ProjectM::SoftCutDuration() const -> double
{
    return m_softCutDuration;
}

void ProjectM::SetSoftCutDuration(double seconds)
{
    m_softCutDuration = seconds;
    m_timeKeeper->ChangeSoftCutDuration(seconds);
}

auto ProjectM::HardCutDuration() const -> double
{
    return m_hardCutDuration;
}

void ProjectM::SetHardCutDuration(double seconds)
{
    m_hardCutDuration = static_cast<int>(seconds);
    m_timeKeeper->ChangeHardCutDuration(seconds);
}

auto ProjectM::HardCutEnabled() const -> bool
{
    return m_hardCutEnabled;
}

void ProjectM::SetHardCutEnabled(bool enabled)
{
    m_hardCutEnabled = enabled;
}

auto ProjectM::HardCutSensitivity() const -> float
{
    return m_hardCutSensitivity;
}

void ProjectM::SetHardCutSensitivity(float sensitivity)
{
    m_hardCutSensitivity = sensitivity;
}

void ProjectM::SetPresetDuration(double seconds)
{
    m_timeKeeper->ChangePresetDuration(seconds);
}

auto ProjectM::PresetDuration() const -> double
{
    return m_timeKeeper->PresetDuration();
}

auto ProjectM::TargetFramesPerSecond() const -> int32_t
{
    return m_targetFps;
}

void ProjectM::SetTargetFramesPerSecond(int32_t fps)
{
    m_targetFps = fps;
}

auto ProjectM::AspectCorrection() const -> bool
{
    return m_aspectCorrection;
}

void ProjectM::SetAspectCorrection(bool enabled)
{
    m_aspectCorrection = enabled;
}

auto ProjectM::EasterEgg() const -> float
{
    return m_easterEgg;
}

void ProjectM::SetEasterEgg(float value)
{
    m_easterEgg = value;
    m_timeKeeper->ChangeEasterEgg(value);
}

void ProjectM::MeshSize(uint32_t& meshResolutionX, uint32_t& meshResolutionY) const
{
    meshResolutionX = m_meshX;
    meshResolutionY = m_meshY;
}

void ProjectM::SetMeshSize(uint32_t meshResolutionX, uint32_t meshResolutionY)
{
    m_meshX = meshResolutionX;
    m_meshY = meshResolutionY;

    // Need multiples of two, otherwise will not render a horizontal and/or vertical bar in the center of the warp mesh.
    if (m_meshX % 2 == 1)
    {
        m_meshX++;
    }

    if (m_meshY % 2 == 1)
    {
        m_meshY++;
    }

    // Constrain per-pixel mesh size to sensible limits
    m_meshX = std::max(8u, std::min(300u, m_meshX));
    m_meshY = std::max(8u, std::min(300u, m_meshY));
}

auto ProjectM::PCM() -> libprojectM::Audio::PCM&
{
    return m_audioStorage;
}

void ProjectM::Touch(float, float, int, int)
{
    // UNIMPLEMENTED
}

void ProjectM::TouchDrag(float, float, int)
{
    // UNIMPLEMENTED
}

void ProjectM::TouchDestroy(float, float)
{
    // UNIMPLEMENTED
}

void ProjectM::TouchDestroyAll()
{
    // UNIMPLEMENTED
}

auto ProjectM::GetRenderContext() -> Renderer::RenderContext
{
    Renderer::RenderContext ctx{};
    ctx.viewportSizeX = m_windowWidth;
    ctx.viewportSizeY = m_windowHeight;
    ctx.time = static_cast<float>(m_timeKeeper->GetRunningTime());
    ctx.progress = static_cast<float>(m_timeKeeper->PresetProgressA());
    ctx.fps = static_cast<float>(m_targetFps);
    ctx.frame = m_frameCount;
    ctx.aspectX = (m_windowHeight > m_windowWidth) ? static_cast<float>(m_windowWidth) / static_cast<float>(m_windowHeight) : 1.0f;
    ctx.aspectY = (m_windowWidth > m_windowHeight) ? static_cast<float>(m_windowHeight) / static_cast<float>(m_windowWidth) : 1.0f;
    ctx.invAspectX = 1.0f / ctx.aspectX;
    ctx.invAspectY = 1.0f / ctx.aspectY;
    ctx.perPixelMeshX = static_cast<int>(m_meshX);
    ctx.perPixelMeshY = static_cast<int>(m_meshY);
    ctx.textureManager = m_textureManager.get();
    ctx.shaderCache = m_shaderCache.get();
    ctx.spriteManager = m_spriteManager.get();

    if (m_transition)
    {
        ctx.blendProgress = m_transition->Progress(ctx.time);
    }
    else
    {
        ctx.blendProgress = 0.0;
    }

    return ctx;
}

} // namespace libprojectM
