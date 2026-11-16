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
    HwBlend,    //!< No fetch: same single draw, blending left to the GPU (see below).
};

// HwBlend (rewamp): the single draw does NOT need to read the framebuffer. The
// two blend modes a shape instance can pick are
//   additive: dst' = src*a + dst          alpha: dst' = src*a + dst*(1-a)
// and both are ONE, ONE_MINUS_SRC_ALPHA on a premultiplied output: the shader
// writes (rgb*a, 0) for additive and (rgb*a, a) for alpha. Overlapping
// instances of one draw blend in primitive order, as the fetch path does.
// Alpha CHANNEL: exact for alpha mode (separate alpha factors SRC_ALPHA,
// ONE_MINUS_SRC_ALPHA give a*a + dst_a*(1-a)); additive loses its a*a term.
// Used where neither extension exists and the multi-draw path costs too much:
// WebGL, where every GL call crosses into JS and then the browser's GPU
// process (a preset with hundreds of shape instances issued thousands of draws
// per frame). WebGL has no framebuffer fetch at all.

/// Queries the GL extension list once and caches the result.
FramebufferFetchMode FramebufferFetch();

/// True when the single-draw fast path can be used (fetch or HwBlend).
inline bool FramebufferFetchAvailable()
{
    return FramebufferFetch() != FramebufferFetchMode::None;
}

} // namespace MilkdropPreset
} // namespace libprojectM
