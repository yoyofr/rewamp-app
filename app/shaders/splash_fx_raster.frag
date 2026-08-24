#include <flutter/runtime_effect.glsl>

// Launch-intro effect: "Sunrise → lockup reveal".
//
// The native splash shows the SUN ONLY (iOS LaunchImage + Android-12 masked
// icon are the sun mark). So frame-0 of this effect must be the sun alone over
// #160A1E — pixel-matching the native splash — or the native→Flutter handoff
// flashes. From there the wordmark + EQ (the lower band of the full logo
// texture) RISE + fade into place, the sun blooms once, then the whole thing
// dissolves out to reveal AppShell.
//
// The texture is the FULL logo (splash_logo.png). uLogoRect places it so the
// sun lands exactly where the native sun-only splash had it; the lower band
// (below kSplit) is the wordmark+EQ, hidden at frame-0 and revealed by uProgress.
//
// Uniform/texture contract + invariants: see splash_common.glsl.
#include "splash_common.glsl"

// EQ-bar strip bbox in logo-UV — measured on splash_logo.png (1000x1000):
// wordmark row ends ~y=670/1000, bars run ~705-770/1000, x ~385-615/1000.
// The baked bars in the texture are MASKED OUT over this box and replaced by
// procedurally-drawn solid rectangles whose heights animate like an FFT/EQ
// analyser (baked pixels can't grow/shrink; resampling them warps neighbours).
const vec4  kBars     = vec4(0.385, 0.702, 0.615, 0.772); // x0,y0,x1,y1
const float kBarCount = 11.0;
const float kBarDuty  = 0.42;                       // bar width fraction of its cell
const vec3  kBarCol   = vec3(0.929, 0.169, 0.533);  // logo magenta

// Per-bar analyser height (0..1) at animation time t, for column `col`.
// Two mismatched sines + a hashed offset per bar → uncorrelated, music-like
// motion instead of one uniform ripple.
float barLevel(float col, float t) {
    float h1 = hash11(col);
    float h2 = hash11(col + 37.0);
    float f1 = mix(6.0, 13.0, h1);
    float f2 = mix(3.5, 8.0,  h2);
    float v  = 0.5 + 0.5 * sin(t * f1 + h1 * 6.28318);
    v       *= 0.5 + 0.5 * sin(t * f2 + h2 * 6.28318);
    return mix(0.12, 1.0, v);   // never fully collapse — keep a stub visible
}

void main() {
    vec2 fc  = FlutterFragCoord().xy;
    vec2 luv = (fc - uLogoRect.xy) / uLogoRect.zw;
    bool inLogo = luv.x >= 0.0 && luv.x <= 1.0 && luv.y >= 0.0 && luv.y <= 1.0;

    vec3 base = kBg;
    if (inLogo) {
        // Lower band (wordmark+EQ) rises up + fades in; the sun is always shown.
        float reveal = smoothstep(0.10, 0.45, uProgress);   // 0 at frame-0
        bool  lower  = luv.y > kSplit;
        vec2  s      = luv;
        float a      = 1.0;
        if (lower) {
            s.y += (1.0 - reveal) * 0.05;    // sample from below → slides up
            a    = reveal;                   // 0 at frame-0 → sun only (native match)
        }

        // Mask the baked EQ bars out of the texture over the bar box: they're
        // replaced by procedural rectangles below. Everything else (sun,
        // wordmark) samples the texture as before.
        bool inBarBox = luv.x >= kBars.x && luv.x <= kBars.z &&
                        luv.y >= kBars.y && luv.y <= kBars.w;
        vec4 tex = inBarBox ? vec4(0.0) : texture(uTexLogo, s);   // premultiplied
        base = blendLogo(tex, a);

        // Procedural analyser bars. Solid rounded-top rectangles that grow
        // upward from the strip baseline; heights animate per-bar once the
        // reveal has landed. Unlike the wordmark (which fades in via `a`), the
        // bars RISE: their height is scaled by `reveal`, so at frame-0 they
        // have zero height (invisible → native match) and physically grow up
        // out of the baseline instead of ghosting in.
        if (inBarBox) {
            // Cell = one bar + gap. Center each bar in its cell (kBarDuty wide).
            float fx    = (luv.x - kBars.x) / (kBars.z - kBars.x) * kBarCount;
            float col   = floor(fx);
            float cellX = fract(fx) - 0.5;                 // -0.5..0.5 within cell
            float hw    = kBarDuty * 0.5;
            // Idle (pre-music) height, then blend to the live analyser level
            // — and KEEP animating through the final dissolve (the bars dance
            // until the fade-out completes instead of freezing at ~0.8).
            float anim  = smoothstep(0.45, 0.55, uProgress);
            float idle  = mix(0.35, 0.7, hash11(col + 11.0));
            float h     = mix(idle, barLevel(col, uProgress * 3.0), anim);
            h          *= reveal;   // rise from 0 height at frame-0
            // Bar body from baseline (kBars.w) up to height h of the strip.
            float top   = kBars.w - h * (kBars.w - kBars.y);
            float ax    = 1.0 - smoothstep(hw - 0.006, hw, abs(cellX)); // x edge
            float ay    = smoothstep(top - 0.004, top, luv.y);              // fill below top
            base = mix(base, kBarCol, ax * ay);
        }
    }

    // Sun bloom — one magenta pulse, gated to 0 at frame-0 and eased back to 0
    // by ~0.8 so the animation ends on the clean logo before the dissolve.
    // Computed in SCREEN space and NOT gated on inLogo: exp() falloff has no
    // hard edge, but clipping it to the logo rect's boundary gave it one —
    // a visible ring where the glow got cut off instead of fading into the
    // background. Radiating across the whole canvas lets it blend smoothly.
    float fx = smoothstep(0.05, 0.40, uProgress) * (1.0 - smoothstep(0.55, 0.80, uProgress));
    if (fx > 0.0) {
        float d = distance(fc, uSunPos) / uLogoRect.z;  // normalized by logo width
        base += vec3(0.85, 0.18, 0.55) * exp(-d * 7.0) * fx * 0.5;
    }

    // Dissolve out (last ~18%) → premultiplied transparent.
    float outA = dissolveAlpha(uProgress);
    fragColor = vec4(base * outA, outA);      // frame 0: reveal=fx=0, outA=1 → sun over bg
}
