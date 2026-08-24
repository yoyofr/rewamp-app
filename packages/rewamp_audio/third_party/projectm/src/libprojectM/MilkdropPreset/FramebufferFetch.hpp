#pragma once

// Runtime detection of the framebuffer-fetch extension (rewamp addition).
//
// CustomShape's fast render path does additive/alpha blending inside a single
// shader by READING the current framebuffer colour in the fragment shader. Two
// mutually-exclusive extensions expose that, and they are NOT source-compatible:
//
//   GL_EXT_shader_framebuffer_fetch — the destination colour is the `inout vec4`
//       output variable itself (read then written).
//   GL_ARM_shader_framebuffer_fetch — the output is a plain `out vec4`, and the
//       destination colour is read from the built-in `gl_LastFragColorARM`.
//
// Availability is a per-GPU/per-driver fact, so it cannot be a build-time
// decision: iOS (MetalANGLE) has EXT, upstream ANGLE's Metal backend (macOS) has
// neither, and on Android it depends on the GPU (Adreno/newer Mali expose EXT,
// older Mali only the ARM variant). Anything without one of the two must fall
// back to projectM's standard multi-draw blend path, or shape rendering breaks.
//
// Detect() must be called with a current GL context; the result is cached.
// Defining CUSTOMSHAPE_NO_FAST_RENDER forces None (hard opt-out, kept for the
// macOS/ANGLE-Metal build which is known to lack both).

namespace libprojectM {
namespace MilkdropPreset {

enum class FramebufferFetchMode
{
    None = 0,   //!< No framebuffer fetch → use the standard blend path.
    Ext,        //!< GL_EXT_shader_framebuffer_fetch (inout colour).
    Arm,        //!< GL_ARM_shader_framebuffer_fetch (gl_LastFragColorARM).
};

/// Queries the GL extension list once and caches the result.
FramebufferFetchMode FramebufferFetch();

/// True when the single-draw, in-shader-blending fast path can be used.
inline bool FramebufferFetchAvailable()
{
    return FramebufferFetch() != FramebufferFetchMode::None;
}

} // namespace MilkdropPreset
} // namespace libprojectM
