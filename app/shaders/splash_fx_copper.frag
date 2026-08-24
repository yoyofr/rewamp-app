#include <flutter/runtime_effect.glsl>

// Launch-intro effect: "Copper bars" — 16-bit demoscene raster bars seen
// THROUGH the logo (sun + wordmark act as a mask).
//
// Timeline (uProgress 0..1, ~2.6s):
//   0.00        sun only over kBg (frame-0 native match — invariant 1)
//   0.02..0.18  wordmark fades in softly; copper bars slide in from the top,
//               staggered, visible only inside the logo alpha
//   0.18..0.62  bars dance (sine bounce, per-bar speed/phase from uSeed);
//               the logo's own colours are dimmed so the bars carry the image
//   0.62..0.82  bars exit through the BOTTOM one after another; as they go,
//               the dim lifts and the sun + wordmark return in their normal
//               colours
//   0.82..1.00  shared dissolve to transparent (invariant 2)
//
// Uniform/texture contract + invariants: see splash_common.glsl.
#include "splash_common.glsl"

const float kBarN   = 7.0;   // bar count — all the SAME size
const float kBarH   = 0.05;  // bar half-height, logo-UV units
const float kBarGap = 0.85;  // phase spacing between bars along the sine train
const float kSpeed  = 4.5;   // slow single sine (~1/3 of a cycle over the dance)

// The bars' VIRTUAL SCREEN: top of the sun to the bottom of the logo content,
// measured on splash_logo.png's alpha (rows 275..689 of 1000). Bar centres
// are confined so a bar never swings beyond the visible artwork — outside
// this band the mask is empty and the motion would just be dead time.
const float kScrTop = 0.275;
const float kScrBot = 0.689;

// Soft wordmark reveal (not a pop): alpha for the lower band.
float wordmarkReveal(float p) { return smoothstep(0.02, 0.18, p); }

// Classic copper hue per bar: saturated, metal-bright centre.
vec3 barHue(float i) {
    float h = fract(i / kBarN + 0.61 + uSeed * 0.37);
    return 0.55 + 0.45 * cos(6.28318 * (h + vec3(0.0, 0.33, 0.67)));
}

// Bar centre in logo-UV y at progress p. The HISTORIC look: one slow
// sinusoid, every bar riding it at an even phase offset (i * kBarGap) — a
// train that stretches apart mid-swing and compresses at the turnarounds.
// uSeed only shifts the whole train's phase between launches.
// Slide-in from above and slide-out through the bottom stay staggered.
float barCenter(float i, float p) {
    float theta = p * kSpeed + uSeed * 6.28318;
    float dance = mix(kScrTop + kBarH, kScrBot - kBarH,
                      0.5 + 0.5 * sin(theta - i * kBarGap));
    // Slide in from the top (staggered): a big negative offset easing to 0.
    float tin  = smoothstep(0.02 + i * 0.014, 0.22 + i * 0.014, p);
    float inOf = -1.6 * (1.0 - tin) * (1.0 - tin);
    // Slide out through the bottom (staggered): offset easing to +2.4.
    float tout = smoothstep(0.62 + i * 0.016, 0.80 + i * 0.016, p);
    return dance + inOf + 2.4 * tout * tout;
}

void main() {
    vec2 fc  = FlutterFragCoord().xy;
    vec2 luv = (fc - uLogoRect.xy) / uLogoRect.zw;
    bool inLogo = luv.x >= 0.0 && luv.x <= 1.0 && luv.y >= 0.0 && luv.y <= 1.0;
    float p = uProgress;

    vec3 base = kBg;
    if (inLogo) {
        float aBand = luv.y > kSplit ? wordmarkReveal(p) : 1.0;
        vec4  tex   = texture(uTexLogo, luv);   // premultiplied

        // Dim the logo's own colours while the bars own the stage; 1.0 at
        // frame-0 (native match) and back to 1.0 once the bars have left.
        float stage = smoothstep(0.06, 0.20, p) * (1.0 - smoothstep(0.64, 0.84, p));
        float dim   = 1.0 - 0.68 * stage;
        base = kBg * (1.0 - tex.a * aBand) + tex.rgb * aBand * dim;

        // Copper bars, painter's order (later bars draw over earlier ones),
        // clipped to the logo shape (alpha × reveal) — "through the mask".
        float maskA = tex.a * aBand;
        if (maskA > 0.003) {
            vec3  barCol = vec3(0.0);
            float cov    = 0.0;
            for (float i = 0.0; i < kBarN; i += 1.0) {
                float yc = barCenter(i, p);
                float d  = abs(luv.y - yc);
                if (d < kBarH) {
                    float t    = d / kBarH;              // 0 centre .. 1 edge
                    float edge = 1.0 - smoothstep(0.86, 1.0, t);  // soft rim
                    // Metallic vertical gradient: dark rim, bright body,
                    // near-white core line.
                    vec3 c = barHue(i) * mix(1.15, 0.30, t * t);
                    c += vec3(0.75) * smoothstep(0.28, 0.0, t);
                    barCol = mix(barCol, c, edge);       // over previous bar
                    cov    = max(cov, edge);
                }
            }
            base = mix(base, barCol, cov * maskA);
        }
    }

    float outA = dissolveAlpha(p);
    fragColor = vec4(base * outA, outA);   // frame-0: bars off, dim=1 → sun over bg
}
