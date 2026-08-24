// splash_common.glsl — the launch-intro effect CONTRACT, included by every
// shaders/splash_fx_*.frag (after <flutter/runtime_effect.glsl>).
//
// An effect is one .frag + one kSplashEffects entry (splash_intro.dart).
// The driver (SplashIntroPainter) fills the uniforms below for ALL effects —
// an effect must declare the whole block (this include does it), even the
// uniforms it ignores, or setFloat() indexes shift and the shader reads noise.
//
// TWO INVARIANTS, enforced by app/test/splash_contract_test.dart:
//   1. Frame-0 identity: at uProgress == 0 the output is the SUN ONLY
//      (logo-UV y <= kSplit) over kBg — pixel-matching the native splash,
//      or the native→Flutter handoff flashes.
//   2. Dissolve: at uProgress == 1 the output is fully transparent
//      (premultiplied 0) — AppShell is revealed underneath.
//
// Extension point: effects that need the wordmark as a SEPARATE texture
// (letters detached from the logo) will add a second sampler + a
// SplashEffect flag so the painter only binds it when declared. Not needed
// yet — the full-logo alpha already gives shape masks, and its RGB the colours.

uniform vec2      uSize;      // paint size, logical px
uniform float     uProgress;  // 0..1 animation clock
uniform vec4      uLogoRect;  // x,y,w,h of the centred 250pt logo box
uniform vec2      uSunPos;    // sun centre in SCREEN px (driver-computed)
uniform float     uSeed;      // per-launch random 0..1 (0 in tests — determinism)
uniform sampler2D uTexLogo;   // splash_logo.png, full lockup, premultiplied

out vec4 fragColor;

const vec3  kBg    = vec3(0.08627, 0.03922, 0.11765);  // #160A1E
const float kSplit = 0.582;   // logo-UV y: sun above, wordmark+EQ below

float hash11(float x) { return fract(sin(x * 12.9898) * 43758.5453); }

// SIN-FREE hashes for hot loops (Dave Hoskins). hash11 costs a sine, and a
// per-fragment loop over N objects pays it N times per pixel — the starfield
// alone was 600+ sines per fragment before these.
float hashf(float x) {
    x = fract(x * 0.1031);
    x *= x + 33.33;
    x *= x + x;
    return fract(x);
}
vec2 hash22(vec2 v) {
    vec3 q = fract(vec3(v.xyx) * vec3(0.1031, 0.1030, 0.0973));
    q += dot(q, q.yzx + 33.33);
    return fract((q.xx + q.yz) * q.zy);
}

// Premultiplied logo texel over kBg, with an extra alpha factor.
vec3 blendLogo(vec4 tex, float a) {
    return kBg * (1.0 - tex.a * a) + tex.rgb * a;
}

// Shared end-of-intro dissolve (invariant 2). Multiply the final colour AND
// use as output alpha: fragColor = vec4(base * dissolveAlpha(p), dissolveAlpha(p)).
float dissolveAlpha(float p) { return 1.0 - smoothstep(0.82, 1.0, p); }
