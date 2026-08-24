#include <flutter/runtime_effect.glsl>

// Launch-intro effect: "Laser engraver" — the wordmark is BURNT into the plate
// by one to three lasers firing from the screen edge.
//
// This shader draws the PLATE and nothing else. Everything that engraves —
// the cut blocks, the beams, the sparks — is in splashLaserOverlay
// (splash_fx_overlays.dart), and that split is not a preference:
//
//   A laser must only ever point at a block that HOLDS INK, or it reads as a
//   cathode-ray sweep wandering over empty plate. That means ordering the
//   blocks by "how many inked blocks come before me in this laser's band",
//   which a fragment cannot know without sampling every block above it — up to
//   1080 texture reads per pixel. The overlay already holds the decoded
//   artwork (SplashFrame.logoPixelAt), so it counts them once per frame and
//   draws each cut block itself: ~400 canvas rects instead of a per-pixel
//   scan, the same O(objects) argument as every other hybrid effect here.
//
// Nothing is mirrored between the two sides any more, so nothing can drift
// apart (see splash_fx_starfield.frag for what that cost when it was).
//
// Timeline (uProgress 0..1, ~3.6s):
//   0.00        sun only over kBg (invariant 1)
//   0.14..0.74  the lasers cut; blocks land white-hot and cool
//   0.74..0.86  the word stands, the last blocks finish cooling
//   0.82..1.00  shared dissolve to transparent (invariant 2)
//
// Uniform/texture contract + invariants: see splash_common.glsl.
#include "splash_common.glsl"

void main() {
    // The bare plate. The sun is drawn by the canvas afterwards (sunOnTop), so
    // the beams and sparks pass BEHIND it.
    fragColor = vec4(kBg * dissolveAlpha(uProgress), dissolveAlpha(uProgress));
}
