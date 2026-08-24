#include "UserSprites/MilkdropSprite.hpp"

#include "SpriteException.hpp"
#include "SpriteShaders.hpp"

#include <Preset.hpp>
#include <PresetFileParser.hpp>

#include <Renderer/BlendMode.hpp>
#include <Renderer/ShaderCache.hpp>
#include <Renderer/TextureManager.hpp>

#include <Utils.hpp>

#include <cassert>
#include <cmath>
#include <cstdlib>
#include <locale>
#include <sstream>
#include <string>

#define REG_VAR(var) \
    var = projectm_eval_context_register_variable(spriteCodeContext, #var);

namespace libprojectM {
namespace UserSprites {

MilkdropSprite::MilkdropSprite()
    : m_mesh(Renderer::VertexBufferUsage::DynamicDraw, false, true)
{
    m_mesh.SetRenderPrimitiveType(Renderer::Mesh::PrimitiveType::TriangleStrip);

    m_mesh.SetVertexCount(4);
    /*m_mesh.Vertices().Set({{-1.0, 1.0},
                           {1.0, 1.0},
                           {-1.0, -1.0},
                           {1.0, -1.0}});

    m_mesh.UVs().Set({{0.0, 1.0},
                      {1.0, 1.0},
                      {0.0, 0.0},
                      {1.0, 0.0}});

    m_mesh.Indices().Set({0, 1, 2, 3});

    m_mesh.Update();*/
}

void MilkdropSprite::Init(const std::string& spriteData, const Renderer::RenderContext& renderContext)
{
    PresetFileParser parser;
    std::stringstream spriteDataStream(spriteData);
    if (!parser.Read(spriteDataStream))
    {
        throw SpriteException("Error reading sprite data.");
    }

    // Load/compile shader
    auto spriteShader = renderContext.shaderCache->Get("milkdrop_user_sprite");
    if (!spriteShader)
    {
        // ToDo: Better handle this in the shader class to reduce duplicate code.
#ifdef USE_GLES
        // GLES also requires a precision specifier for variables and 3D samplers
        constexpr char versionHeader[] = "#version 300 es\n\nprecision mediump float;\nprecision mediump sampler3D;\n";
#else
        constexpr char versionHeader[] = "#version 330\n\n";
#endif

        spriteShader = std::make_shared<Renderer::Shader>();
        spriteShader->CompileProgram(static_cast<const char*>(versionHeader) + kMilkdropSpriteVertexGlsl330,
                                     static_cast<const char*>(versionHeader) + kMilkdropSpriteFragmentGlsl330);
        renderContext.shaderCache->Insert("milkdrop_user_sprite", spriteShader);
    }

    m_spriteShader = spriteShader;

    // The colour key. OpenGL has no texture render state for it, but the effect
    // MilkDrop gets from D3DX is just "these texels become transparent at load
    // time" — so the TextureManager does it on the pixels, and blend mode 4 then
    // tests that alpha exactly as before. This matters for the images that carry
    // NO alpha of their own: an unkeyed JPEG draws as an opaque rectangle where
    // MilkDrop cuts out the background. Absent key (-1) keeps the shared,
    // un-keyed texture.

    // Load and compile code
    auto initCode = parser.GetCode("init_");
    m_codeContext.RunInitCode(initCode, renderContext);

    auto perFrameCode = parser.GetCode("code_");
    if (!perFrameCode.empty())
    {
        m_codeContext.perFrameCodeHandle = projectm_eval_code_compile(m_codeContext.spriteCodeContext, perFrameCode.c_str());
        if (!m_codeContext.perFrameCodeHandle)
        {
            int errorLine{};
            int errorColumn{};
            auto* errorMessage = projectm_eval_get_error(m_codeContext.spriteCodeContext, &errorLine, &errorColumn);

            throw SpriteException("Error compiling sprite per-frame code:" + std::string(errorMessage) + " (Line " + std::to_string(errorLine) + ", column " + std::to_string(errorColumn) + ")");
        }
    }

    auto imageName = Utils::ToLower(parser.GetString("img", ""));
    const int colorKey = parser.GetInt("colorkey", -1);

    // Store texture as a shared_ptr to make sure TextureManager doesn't delete it.
    std::locale const loc;
    if (imageName.length() >= 6 &&
        imageName.substr(0, 4) == "rand" && std::isdigit(imageName.at(4), loc) && std::isdigit(imageName.at(5), loc))
    {
        m_texture = renderContext.textureManager->GetRandomTexture(imageName).Texture();
    }
    else if (colorKey >= 0)
    {
        m_texture = renderContext.textureManager
                        ->GetTextureColorKeyed(imageName, static_cast<uint32_t>(colorKey))
                        .Texture();
    }
    else
    {
        m_texture = renderContext.textureManager->GetTexture(imageName).Texture();
    }
}

void MilkdropSprite::Update(const Audio::FrameAudioData& audioData,
                            const Renderer::RenderContext& renderContext)
{
    m_codeContext.RunPerFrameCode(audioData, renderContext);

    m_spriteDone = *m_codeContext.done != 0.0;
    m_burnIn = *m_codeContext.burn != 0.0;

    auto& vertices = m_mesh.Vertices().Get();

    // Get values from expression code and clamp them where necessary.
    float x = std::min(1000.0f, std::max(-1000.0f, static_cast<float>(*m_codeContext.x) * 2.0f - 1.0f));
    // NEGATED: MilkDrop counts y from the TOP (its sprite space is D3D's, y=0 up
    // there), while these vertices go straight out as GL NDC, where +y is up.
    // Without the flip a sprite whose per-frame code walks a circle - "Evet +
    // Geiss - Chrome" does exactly that, x = sin(t), y = cos(t) - orbits the
    // wrong way round, and its own spin reads reversed too, since mirroring an
    // axis reverses handedness. The spin was previously "fixed" by negating the
    // rotation in the adapter, which treated the symptom and left the orbit
    // wrong; that negation is reverted with this.
    float y = std::min(1000.0f, std::max(-1000.0f, 1.0f - static_cast<float>(*m_codeContext.y) * 2.0f));
    float sx = std::min(1000.0f, std::max(-1000.0f, static_cast<float>(*m_codeContext.sx)));
    float sy = std::min(1000.0f, std::max(-1000.0f, static_cast<float>(*m_codeContext.sy)));
    float rot = static_cast<float>(*m_codeContext.rot);
    int flipx = (*m_codeContext.flipx == 0.0) ? 0 : 1; // Comparing float to 0.0 isn't actually a good idea...
    int flipy = (*m_codeContext.flipy == 0.0) ? 0 : 1;
    float repeatx = std::min(100.0f, std::max(0.01f, static_cast<float>(*m_codeContext.repeatx)));
    float repeaty = std::min(100.0f, std::max(0.01f, static_cast<float>(*m_codeContext.repeaty)));

    // 0-10, the full MilkDrop 3 range, named by its own Sprites > Blendmode
    // menu: 0 Blend, 1 Decal, 2 Additive, 3 Srccolor, 4 Colorkey,
    // 5 Multiplicative, 6 Subtractive, 7 Invert, 8 Cut-off, 9 Darken, 10 Vivid.
    // MilkDrop 2 only had 0-4 and clamped, which is what every readable
    // derivative still does (Milkwave, BeatDrop) - so the high modes exist
    // nowhere but in MilkDrop 3 itself.
    m_blendMode = std::min(10, std::max(0, (static_cast<int>(*m_codeContext.blendmode))));
    m_modR = std::min(1.0f, std::max(0.0f, (static_cast<float>(*m_codeContext.r))));
    m_modG = std::min(1.0f, std::max(0.0f, (static_cast<float>(*m_codeContext.g))));
    m_modB = std::min(1.0f, std::max(0.0f, (static_cast<float>(*m_codeContext.b))));
    m_modA = std::min(1.0f, std::max(0.0f, (static_cast<float>(*m_codeContext.a))));

    // ToDo: Move all translations to vertex shader
    vertices[0 + flipx].SetX(-sx);
    vertices[1 - flipx].SetX(sx);
    vertices[2 + flipx].SetX(-sx);
    vertices[3 - flipx].SetX(sx);
    vertices[0 + flipy * 2].SetY(-sy);
    vertices[1 + flipy * 2].SetY(-sy);
    vertices[2 - flipy * 2].SetY(sy);
    vertices[3 - flipy * 2].SetY(sy);

    // First aspect ratio: adjust for non-1:1 images
    {
        // Non-square images must be corrected here or the sprite is stretched
        // to fill a square quad — MilkDrop does it (milkdropfs.cpp,
        // "first aspect ratio"). Guarded: a texture that failed to report its
        // size would divide by zero.
        const int textureWidth = m_texture ? m_texture->Width() : 0;
        const int textureHeight = m_texture ? m_texture->Height() : 0;
        auto aspect = (textureWidth > 0 && textureHeight > 0)
                          ? textureHeight / static_cast<float>(textureWidth)
                          : 1.0f;

        if (aspect < 1.0f)
        {
            // Landscape image
            for (auto& vertex : vertices)
            {
                vertex.SetY(vertex.Y() * aspect);
            }
        }
        else
        {
            // Portrait image
            for (auto& vertex : vertices)
            {
                vertex.SetX(vertex.X() / aspect);
            }
        }
    }

    // 2D rotation
    {
        // The angle is NEGATED, for the same reason the translation is flipped
        // just above: MilkDrop's sprite space counts y downwards. Flipping the
        // POSITION alone fixes the orbit of a sprite that walks a circle and
        // leaves its own spin running backwards - the two are independent,
        // because the rotation is applied to the quad around the origin, before
        // the translation. Both are needed, and both come from the same axis.
        auto cos_rot = std::cos(rot);
        auto sin_rot = std::sin(-rot);

        for (auto& vertex : vertices)
        {
            float rotX = vertex.X() * cos_rot - vertex.Y() * sin_rot;
            float rotY = vertex.X() * sin_rot + vertex.Y() * cos_rot;
            vertex = {rotX, rotY};
        }
    }

    // Translation
    for (auto& vertex : vertices)
    {
        vertex.SetX(vertex.X() + x);
        vertex.SetY(vertex.Y() + y);
    }

    // Second aspect ratio: normalize to width of screen
    {
        float aspect = renderContext.viewportSizeX / static_cast<float>(renderContext.viewportSizeY);

        if (aspect > 1.0)
        {
            for (auto& vertex : vertices)
            {
                vertex.SetY(vertex.Y() * aspect);
            }
        }
        else
        {
            for (auto& vertex : vertices)
            {
                vertex.SetX(vertex.X() / aspect);
            }
        }
    }

    // Third aspect ratio: adjust for burn-in
    // -> Not required in projectM, as we always render at viewport size, not a fixed 4:3 ratio

    // Set u,v coords
    {
        float dtu = 0.5f;
        float dtv = 0.5f;

        m_mesh.UVs().Set({{-dtu, dtv},
                          {dtu, dtv},
                          {-dtu, -dtv},
                          {dtu, -dtv}});

        for (auto& uv : m_mesh.UVs().Get())
        {
            uv = {(uv.U() - 0.0f) * repeatx + 0.5f,
                  (uv.V() - 0.0f) * repeaty + 0.5f};
        }
    }

    m_mesh.Update();

    // SpriteLayer 0 = drawn ON TOP of the finished frame, so the sprite stays
    // crisp ("Evet + Geiss - Chrome": its knot is the subject, and MilkDrop
    // renders it unwarped). >= 1 = into the preset's image instead, BEFORE the
    // composite, so it is warped like any other content - which is what turns
    // "the glass bead game 001" into its balloons.
    //
    // The proof is the BORDER: rendered in MilkDrop 3, a layer-1 sprite that
    // covers the whole screen still has the preset's red border drawn OVER it.
    // The border belongs to the pre-composite pass, so anything it covers was
    // drawn before it.
    //
    // What misled a first reading: with a full-screen opaque sprite, layer 1
    // LOOKS static even though it is only burned in - the fresh stamp of each
    // frame hides the drift of the previous one. "It does not move" is therefore
    // NOT evidence of a top draw.
    static const bool topAlways = (getenv("PM_SPR_TOPALWAYS") != nullptr);
    m_drawOnTop = topAlways || (*m_codeContext.layer) < 1.0;

    m_prepared = true;
}

void MilkdropSprite::Submit(float fade)
{
    auto spriteShader = m_spriteShader.lock();
    if (!spriteShader || !m_texture || fade <= 0.0f)
    {
        return;
    }

    spriteShader->Bind();

    spriteShader->SetUniformInt("blend_mode", m_blendMode);
    spriteShader->SetUniformInt("texture_sampler", 0);
    spriteShader->SetUniformFloat("sprite_fade", fade);

    m_texture->Bind(0);
    m_sampler.Bind(0);

    glVertexAttrib4f(1, m_modR, m_modG, m_modB, m_modA);

    // Decal and cut-off draw with blending OFF, which is exactly what makes them opaque -
    // and what makes them impossible to fade. While a fade is running they go through
    // ordinary alpha blending instead, the shader having scaled their alpha down; at
    // fade == 1 the alpha is 1 and the result is the same opaque draw.
    const bool fading = fade < 1.0f;

    switch (m_blendMode)
    {
        case 0:
        default:
            Renderer::BlendMode::Set(true, Renderer::BlendMode::Function::SourceAlpha, Renderer::BlendMode::Function::OneMinusSourceAlpha);
            break;
        case 1:
            if (fading) { Renderer::BlendMode::Set(true, Renderer::BlendMode::Function::SourceAlpha, Renderer::BlendMode::Function::OneMinusSourceAlpha); }
            else { Renderer::BlendMode::SetBlendActive(false); }
            break;
        case 2:
            Renderer::BlendMode::Set(true, Renderer::BlendMode::Function::One, Renderer::BlendMode::Function::One);
            break;
        case 3:
            Renderer::BlendMode::Set(true, Renderer::BlendMode::Function::SourceColor, Renderer::BlendMode::Function::OneMinusSourceColor);
            break;
        case 4:
            // Milkdrop actually changed color keying to using texture alpha. The color key is ignored.
            Renderer::BlendMode::Set(true, Renderer::BlendMode::Function::SourceAlpha, Renderer::BlendMode::Function::OneMinusSourceAlpha);
            break;
        case 5:
            // Multiplicative: the frame is multiplied by the sprite.
            Renderer::BlendMode::Set(true, Renderer::BlendMode::Function::DestinationColor, Renderer::BlendMode::Function::Zero);
            break;
        case 6:
            // Subtractive: the sprite is REMOVED from the frame, which needs the
            // blend EQUATION, not just the factors. Reset to FUNC_ADD after the
            // draw or every later draw in the frame inherits it.
            Renderer::BlendMode::Set(true, Renderer::BlendMode::Function::One, Renderer::BlendMode::Function::One);
            glBlendEquation(GL_FUNC_REVERSE_SUBTRACT);
            break;
        case 7:
        case 10:
            // Invert and Vivid composite normally; the colour math is in the shader.
            Renderer::BlendMode::Set(true, Renderer::BlendMode::Function::SourceAlpha, Renderer::BlendMode::Function::OneMinusSourceAlpha);
            break;
        case 8:
            // Cut-off: the shader discards below the alpha threshold, so what
            // survives is drawn opaque.
            if (fading) { Renderer::BlendMode::Set(true, Renderer::BlendMode::Function::SourceAlpha, Renderer::BlendMode::Function::OneMinusSourceAlpha); }
            else { Renderer::BlendMode::SetBlendActive(false); }
            break;
        case 9:
            // Darken: per-channel minimum, again an equation.
            Renderer::BlendMode::Set(true, Renderer::BlendMode::Function::One, Renderer::BlendMode::Function::One);
            glBlendEquation(GL_MIN);
            break;
    }

    m_mesh.Draw();

    m_texture->Unbind(0);
    Renderer::Mesh::Unbind();
    Renderer::Shader::Unbind();
    Renderer::BlendMode::SetBlendActive(false);
    // Subtractive and Darken change the blend EQUATION, which is global state
    // and would otherwise apply to every draw that follows, in this preset and
    // the next. Nothing else in the engine touches it, so nothing else would
    // put it back.
    glBlendEquation(GL_FUNC_ADD);
}

void MilkdropSprite::DrawEmbedded()
{
    if (!m_prepared)
    {
        return;
    }

    // A layer >= 1 sprite ONLY lives here; a layer 0 sprite is stamped here too when it
    // burns in. Whatever is drawn now goes through the rest of the preset's frame - the
    // shapes, the border and the composite are still to come, which is exactly what
    // MilkDrop does and what the previous placement (after the composite) could not do:
    // the stamp only reached the image on the NEXT frame, already warped once.
    if (!m_burnIn && m_drawOnTop)
    {
        return;
    }

    // Scaled about the quad's own centre (its centroid, which the four corners define
    // exactly) so the sprite grows in place instead of drifting: the translation and the
    // aspect corrections are already baked into these vertices. Default 1.0 - same size as
    // the copy drawn on top; the 4x that used to be here was compensating for a scale law
    // that was simply wrong (see the adapter).
    static const float burnScale =
        getenv("PM_SPR_BURNSCALE") ? (float)atof(getenv("PM_SPR_BURNSCALE")) : 1.0f;

    if (burnScale != 1.0f)
    {
        auto& verts = m_mesh.Vertices().Get();
        const auto unscaled = verts;
        float cx = 0.0f, cy = 0.0f;
        for (const auto& v : verts) { cx += v.X(); cy += v.Y(); }
        cx /= static_cast<float>(verts.size());
        cy /= static_cast<float>(verts.size());
        for (auto& v : verts)
        {
            v = {cx + (v.X() - cx) * burnScale, cy + (v.Y() - cy) * burnScale};
        }
        m_mesh.Update();

        // No fade here: the embedded copy rides its own preset's image, and the transition
        // cross-fades those two images already. Fading it a second time would double it.
        Submit(1.0f);

        // The top copy uses the same vertices, so put them back.
        verts = unscaled;
        m_mesh.Update();
        return;
    }

    Submit(1.0f);
}

void MilkdropSprite::Draw(const Audio::FrameAudioData& audioData,
                          const Renderer::RenderContext& renderContext,
                          uint32_t outputFramebufferObject,
                          float fade)
{
    if (!m_prepared || !m_drawOnTop)
    {
        return;
    }

    // Draw to the current output buffer, which the caller has bound. The fade is the
    // transition's: this copy sits ON TOP of the finished frame, so it takes no part in
    // the blend of the two preset images and has to be faded by hand.
    Submit(fade);
}

auto MilkdropSprite::Done() const -> bool
{
    return m_spriteDone;
}

MilkdropSprite::CodeContext::CodeContext()
    : spriteCodeContext(projectm_eval_context_create(nullptr, nullptr))
{
}

MilkdropSprite::CodeContext::~CodeContext()
{
    projectm_eval_context_destroy(spriteCodeContext);

    spriteCodeContext = nullptr;
    perFrameCodeHandle = nullptr;
}

void MilkdropSprite::CodeContext::RegisterBuiltinVariables()
{
    projectm_eval_context_reset_variables(spriteCodeContext);

    // Input variables
    REG_VAR(time);
    REG_VAR(frame);
    REG_VAR(fps);
    REG_VAR(progress);
    REG_VAR(bass);
    REG_VAR(mid);
    REG_VAR(treb);
    REG_VAR(bass_att);
    REG_VAR(mid_att);
    REG_VAR(treb_att);

    // Output variables
    REG_VAR(done);
    REG_VAR(burn);
    REG_VAR(x);
    REG_VAR(y);
    REG_VAR(sx);
    REG_VAR(sy);
    REG_VAR(rot);
    REG_VAR(flipx);
    REG_VAR(flipy);
    REG_VAR(repeatx);
    REG_VAR(repeaty);
    REG_VAR(layer);
    REG_VAR(blendmode);
    REG_VAR(r);
    REG_VAR(g);
    REG_VAR(b);
    REG_VAR(a);
}

void MilkdropSprite::CodeContext::RunInitCode(const std::string& initCode, const Renderer::RenderContext& renderContext)
{
    RegisterBuiltinVariables();

    // Set default values of output variables:
    // (by not setting these every frame, we allow the values to persist from frame-to-frame.)
    *x = 0.5;
    *y = 0.5;
    *sx = 1.0;
    *sy = 1.0;
    *repeatx = 1.0;
    *repeaty = 1.0;
    *rot = 0.0;
    *flipx = 0.0;
    *flipy = 0.0;
    *r = 1.0;
    *g = 1.0;
    *b = 1.0;
    *a = 1.0;
    *layer = 0.0;
    *blendmode = 0.0;
    *done = 0.0;
    *burn = 1.0;

    if (initCode.empty())
    {
        return;
    }

    // Only time and frame values are passed to the init code.
    *time = renderContext.time;
    *frame = renderContext.frame;

    auto* initCodeHandle = projectm_eval_code_compile(spriteCodeContext, initCode.c_str());
    if (initCodeHandle == nullptr)
    {
        int errorLine{};
        int errorColumn{};
        const auto* errorMessage = projectm_eval_get_error(spriteCodeContext, &errorLine, &errorColumn);

        throw SpriteException("Error compiling sprite init code:" + std::string(errorMessage) + " (Line " + std::to_string(errorLine) + ", column " + std::to_string(errorColumn) + ")");
    }

    projectm_eval_code_execute(initCodeHandle);
    projectm_eval_code_destroy(initCodeHandle);
}

void MilkdropSprite::CodeContext::RunPerFrameCode(const Audio::FrameAudioData& audioData, const Renderer::RenderContext& renderContext)
{
    // If there's no per-frame code, e.g. with static sprites, just skip it.
    if (perFrameCodeHandle == nullptr)
    {
        return;
    }

    // Fill in input variables
    *time = renderContext.time;
    *frame = renderContext.frame;
    *fps = renderContext.fps;
    *progress = renderContext.blendProgress;
    *bass = audioData.bass;
    *mid = audioData.mid;
    *treb = audioData.treb;
    *bass_att = audioData.bassAtt;
    *mid_att = audioData.midAtt;
    *treb_att = audioData.trebAtt;

    // Run the code
    projectm_eval_code_execute(perFrameCodeHandle);
}

} // namespace UserSprites
} // namespace libprojectM
