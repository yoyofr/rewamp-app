// Runtime framebuffer-fetch detection (rewamp addition). See FramebufferFetch.hpp.

#include "FramebufferFetch.hpp"

#include "Renderer/OpenGL.h"

#include <cstring>

namespace libprojectM {
namespace MilkdropPreset {

namespace {

bool HasExtension(const char* wanted)
{
    // Core profile / GLES3: the extension list is only available per-index.
    GLint count = 0;
    glGetIntegerv(GL_NUM_EXTENSIONS, &count);
    if (glGetError() == GL_NO_ERROR && count > 0)
    {
        for (GLint i = 0; i < count; ++i)
        {
            const auto* name = reinterpret_cast<const char*>(glGetStringi(GL_EXTENSIONS, static_cast<GLuint>(i)));
            if (name != nullptr && std::strcmp(name, wanted) == 0)
            {
                return true;
            }
        }
        return false;
    }

    // Compatibility fallback: one space-separated string. Match whole tokens —
    // a plain strstr would report GL_EXT_shader_framebuffer_fetch present when
    // only GL_EXT_shader_framebuffer_fetch_non_coherent is.
    const auto* all = reinterpret_cast<const char*>(glGetString(GL_EXTENSIONS));
    if (all == nullptr)
    {
        return false;
    }
    const size_t wantedLength = std::strlen(wanted);
    for (const char* p = std::strstr(all, wanted); p != nullptr; p = std::strstr(p + 1, wanted))
    {
        const bool startOk = (p == all) || (p[-1] == ' ');
        const char after = p[wantedLength];
        const bool endOk = (after == '\0') || (after == ' ');
        if (startOk && endOk)
        {
            return true;
        }
    }
    return false;
}

FramebufferFetchMode Detect()
{
#if defined(CUSTOMSHAPE_NO_FAST_RENDER)
    // Hard opt-out (upstream ANGLE's Metal backend exposes neither extension).
    return FramebufferFetchMode::None;
#else
    // Prefer EXT: it is the more widely implemented of the two and its GLSL form
    // is what the fast path was originally written against.
    if (HasExtension("GL_EXT_shader_framebuffer_fetch"))
    {
        return FramebufferFetchMode::Ext;
    }
    if (HasExtension("GL_ARM_shader_framebuffer_fetch"))
    {
        return FramebufferFetchMode::Arm;
    }
    return FramebufferFetchMode::None;
#endif
}

} // namespace

FramebufferFetchMode FramebufferFetch()
{
    // Cached: the GL context lives for the whole run, and glGetStringi in a hot
    // render path would be wasteful.
    static const FramebufferFetchMode mode = Detect();
    return mode;
}

} // namespace MilkdropPreset
} // namespace libprojectM
