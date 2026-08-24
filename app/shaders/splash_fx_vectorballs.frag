#include <flutter/runtime_effect.glsl>

// Launch-intro effect: "Vector balls" — HYBRID. This shader paints only the
// ground; the balls are SPRITES drawn by splashVectorBallsOverlay and the sun
// band is drawn by the canvas on top of them (sunOnTop) — see
// splash_fx_overlays.dart for why: a fragment loop pays O(pixels x objects),
// a sprite pays O(its own pixels), which is how the era ran this at 60fps.
//
// Invariants still hold here: frame 0 = the canvas sun over this kBg fill;
// progress 1 = transparent via the shared dissolve.
//
// Uniform/texture contract: see splash_common.glsl.
#include "splash_common.glsl"

void main() {
    float outA = dissolveAlpha(uProgress);
    fragColor = vec4(kBg * outA, outA);
}
