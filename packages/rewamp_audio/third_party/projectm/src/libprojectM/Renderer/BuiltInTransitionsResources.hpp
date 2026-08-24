#pragma once

#include <string>

static std::string kTransitionShaderBuiltInCircleGlsl330 = R"(
// Circular blend with soft edge, inside-out or outside-in
// Source: https://www.shadertoy.com/view/NdGfzG
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.y / iResolution.x;

    // Randomize direction and edge width
    float inOrOut = mod(float(iRandStatic.x) * .01, 2.);

    float progress;
    vec3 imgInner, imgOuter;
    if (inOrOut < 1.)
    {
        imgInner = texture(iChannel0, uv).xyz;
        imgOuter = texture(iChannel1, uv).xyz;
        progress = iProgressCosine;
    }
    else
    {
        imgOuter = texture(iChannel0, uv).xyz;
        imgInner = texture(iChannel1, uv).xyz;
        progress = 1. - iProgressCosine;
    }
    float blendWidth = mod(float(iRandStatic.y) * .001, .1) + .05;
    progress = progress * (1. + blendWidth) - blendWidth;

    // Blending
    vec2 center = vec2(.5);
    float rad = sqrt(center.x / aspect * center.x / aspect + center.y * center.y) * progress;
    float rad2 = rad + blendWidth;
    float r1 = sqrt((uv.x - center.x) / aspect * (uv.x - center.x) / aspect + (uv.y - center.y) * (uv.y - center.y));

    vec3 col;
    if (r1 > rad2)
    {
        col = imgInner;
    }
    else if (r1 > rad)
    {
        float v1=(r1-rad)/(rad2-rad);
        float v2 = 1.0 - v1;
        col = v1 * imgInner + v2 * imgOuter;
    }
    else
    {
        col = imgOuter;
    }

    // Output to screen
    fragColor = vec4(col, 1.0);
}
)";

static std::string kTransitionShaderBuiltInPlasmaGlsl330 = R"(
// Fractal, plasma-like transition effect with random scales and noise seeds.
// Source: https://www.shadertoy.com/view/MstBzf

float sinNoise(vec2 uv)
{
    return fract(abs(sin(uv.x * 0.018 + uv.y * 0.3077) * (float(iRandStatic.x) * .001)));
}

float valueNoise(vec2 uv, float scale)
{
    vec2 luv = fract(uv * scale);
    vec2 luvs = smoothstep(0.0, 1.0, fract(uv * scale));
    vec2 id = floor(uv * scale);
    float tl = sinNoise(id + vec2(0.0, 1.0));
    float tr = sinNoise(id + vec2(1.0, 1.0));
    float t = mix(tl, tr, luvs.x);

    float bl = sinNoise(id + vec2(0.0, 0.0));
    float br = sinNoise(id + vec2(1.0, 0.0));
    float b = mix(bl, br, luvs.x);

    return mix(b, t, luvs.y) * 2.0 - 1.0;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord/iResolution.xy;

    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    uv.y /= iResolution.x/iResolution.y;

    float sinN = sinNoise(uv);

    float scale = mod(float(iRandStatic.y) * .01, 7.) * 4. + 4.;

    float fractValue = 0.;
    float amp = 1.;
    for(int i = 0; i < 16; i++)
    {
        fractValue += valueNoise(uv, float(i + 1) * scale) * amp;
        amp *= .5;
    }

    fractValue *= .25;
    fractValue += .5;

    float cutoff = smoothstep(iProgressCosine + .1, iProgressCosine - .1, fractValue);
    vec3 col = mix(imgOld, imgNew, cutoff);

    // Output to screen
    fragColor = vec4(col, 1.);
})";

static std::string kTransitionShaderBuiltInSimpleBlendGlsl330 = R"(
// Simple crossfade effect from old to new
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;

    // Blending
    fragColor = vec4(mix(texture(iChannel0, uv).xyz,
                         texture(iChannel1, uv).xyz,
                         iProgressCosine), 1.0);
}
)";

static std::string kTransitionShaderBuiltInSweepGlsl330 = R"(
// Side-to-side sweep with random angle and transition zone width

float atan_y_over_x(float y, float x)
{
    if (x > 0.0) return atan(y / x);
    else if (x < 0.0 && y >= 0.0) return atan(y / x) + 3.14159265;
    else if (x < 0.0 && y < 0.0) return atan(y / x) - 3.14159265;
    else return 1.57079632 * sign(y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    // Blending
    float currentAngle = mod(float(iRandStatic.x), 360.);
    float blendWidth = mod(float(iRandStatic.y) * .001, .3) + .1;

    uv -= .5;
    float angle = radians(90.0) - radians(currentAngle) + atan_y_over_x(uv.y, uv.x);

    float len = length(uv) / sqrt(2.);
    uv = vec2(cos(angle) * len, sin(angle) * len) + .5;

    vec3 col = mix(imgNew, imgOld, smoothstep(iProgressCosine, iProgressCosine + blendWidth, (uv.x / (1.0 + 2. * blendWidth)) + blendWidth));

    // Output to screen
    fragColor = vec4(col, 1.0);
}
)";

static std::string kTransitionShaderBuiltInWarpGlsl330 = R"(
// Horizontal/vertical warp effect
// Source: https://www.shadertoy.com/view/ssj3Dh
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    // Randomize direction
    float direction = mod(float(iRandStatic.x) * .01, 4.);
    float coord;
    if (direction < 1.) coord = uv.x;
    else if (direction < 2.) coord = 1. - uv.x;
    else if (direction < 3.) coord = uv.y;
    else coord = 1. - uv.y;

    // Blending
    float x = smoothstep(.0,1.0,(iProgressCosine * 2.0 + coord - 1.0));
    fragColor = mix(texture(iChannel0, (uv - .5) * (1. - x) + .5), texture(iChannel1, (uv - .5) * x + .5), x);
}
)";

static std::string kTransitionShaderBuiltInZoomBlurGlsl330 = R"(
const float strength = 0.3;
const float PI = 3.141592653589793;

float Linear_ease(in float begin, in float change, in float duration, in float time) {
    return change * time / duration + begin;
}

float Exponential_easeInOut(in float begin, in float change, in float duration, in float time) {
    if (time == 0.0)
    return begin;
    else if (time == duration)
    return begin + change;
    time = time / (duration / 2.0);
    if (time < 1.0)
    return change / 2.0 * pow(2.0, 10.0 * (time - 1.0)) + begin;
    return change / 2.0 * (-pow(2.0, -10.0 * (time - 1.0)) + 2.0) + begin;
}

float Sinusoidal_easeInOut(in float begin, in float change, in float duration, in float time) {
    return -change / 2.0 * (cos(PI * time / duration) - 1.0) + begin;
}

float random(in vec3 scale, in float seed) {
    return fract(sin(dot(gl_FragCoord.xyz + seed, scale)) * 43758.5453 + seed);
}

vec3 crossFade(in vec2 uv, in float dissolve) {
    return mix(texture(iChannel0, uv).rgb, texture(iChannel1, uv).rgb, dissolve);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    vec2 texCoord = fragCoord.xy / iResolution.xy;
    float progress = iProgressCosine;
    // Linear interpolate center across center half of the image
    vec2 center = vec2(Linear_ease(0.5, 0.0, 1.0, progress),0.5);
    float dissolve = Exponential_easeInOut(0.0, 1.0, 1.0, progress);

    // Mirrored sinusoidal loop. 0->strength then strength->0
    float strength = Sinusoidal_easeInOut(0.0, strength, 0.5, progress);

    vec3 color = vec3(0.0);
    float total = 0.0;
    vec2 toCenter = center - texCoord;

    /* randomize the lookup values to hide the fixed number of samples */
    float offset = random(vec3(12.9898, 78.233, 151.7182), 0.0)*0.5;

    for (float t = 0.0; t <= 20.0; t++) {
        float percent = (t + offset) / 20.0;
        float weight = 1.0 * (percent - percent * percent);
        color += crossFade(texCoord + toCenter * percent * strength, dissolve) * weight;
        total += weight;
    }

    fragColor = vec4(color / total, 1.0);
})";

static std::string kTransitionVertexShaderGlsl330 = R"(
precision mediump float;

layout(location = 0) in vec2 iPosition;

void main() {
    gl_Position = vec4(iPosition, 0.0, 1.0);
}
)";

static std::string kTransitionShaderMilkwaveClockGlsl330 = R"(
// Clock wipe: a hand sweeping around the centre, with a slight radial bias.
// Ported from Milkwave's blend pattern 4 (plugin_blendpatterns.cpp), BSD-3.
//
// Milkwave computes, per MESH VERTEX, two coefficients a and c such that the
// new preset's weight is clamp(a * progress + c, 0, 1) (milkdropfs.cpp:2029),
// with a = (1 + band)/band and c = (t - 1)/band. Substituting gives the single
// expression every ported pattern shares; only `t`, the spatial field, differs.
// Per-pixel here instead of per-vertex, so the mask is exact rather than
// interpolated across the warp mesh.
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    // Per-transition randomness, from the same source the built-in sweep uses.
    float band       = 0.08 + 0.14 * fract(float(iRandStatic.x) * 0.0137);
    float dir        = (iRandStatic.y % 2 == 0) ? 1.0 : -1.0;
    float startAngle = fract(float(iRandStatic.z) * 0.0091) * 6.2831853;

    vec2 d = uv - 0.5;
    d.x *= iResolution.x / iResolution.y;   // keep the hand circular

    float angle = atan(d.y, d.x);           // -PI..PI
    if (angle < 0.0) angle += 6.2831853;
    angle = mod(angle * dir + startAngle + 62.831853, 6.2831853);

    float dist = length(d) * 1.41421356;
    float t = angle / 6.2831853;
    // Seamless wrap: the sliver just past zero belongs to the END of the sweep,
    // otherwise the hand tears where it meets its own start.
    if (t < band) t += 1.0;
    t -= dist * 0.1;                        // slight radial lead

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
)";

static std::string kTransitionShaderMilkwaveCornerGlsl330 = R"(
// Corner wipe: a quarter circle growing out of one corner.
// Ported from Milkwave's blend pattern 8, ".milk2 corner" branch
// (plugin_blendpatterns.cpp), BSD-3. See the clock shader for the derivation of
// the shared mask expression.
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    const float band = 0.38;                // Milkwave fixes this one

    // Which corner. Milkwave only ever anchors bottom-left and flips the
    // direction; picking the corner from the per-transition random makes the
    // pattern worth seeing more than once.
    vec2 corner = vec2(float(iRandStatic.x % 2), float(iRandStatic.y % 2));
    vec2 d = abs(uv - corner);
    d.x *= iResolution.x / iResolution.y;

    float t = length(d) * 0.70710678;
    if (iRandStatic.z % 2 == 1) t = 1.0 - t;   // outside-in

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
)";

static std::string kTransitionShaderMilkwaveCheckerGlsl330 = R"(
// Diamond checkerboard: a 45-degree grid whose cells alternate between coming
// in first and last, with softened cell edges so the seams do not alias.
// Ported from Milkwave's blend pattern 9 (plugin_blendpatterns.cpp), BSD-3.
// See the clock shader for the derivation of the shared mask expression.
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    const float cellsX = 3.0;
    const float cellsY = 3.0;

    float band       = 0.26 + 0.04 * fract(float(iRandStatic.x) * 0.0137);
    float phase      = (fract(float(iRandStatic.y) * 0.0091) - 0.5) * 0.08;
    bool  flipParity = (iRandStatic.z % 2 == 1);

    vec2 d = uv - 0.5;
    d.x *= iResolution.x / iResolution.y;

    // 45 degrees: what makes the cells read as diamonds rather than squares.
    const float c = 0.70710678, s = 0.70710678;
    vec2 r = vec2(d.x * c - d.y * s, d.x * s + d.y * c);

    vec2 cell = vec2(r.x * cellsX + 0.5 + phase, r.y * cellsY + 0.5 - phase);
    vec2 local = fract(cell);
    float edge = min(min(local.x, 1.0 - local.x), min(local.y, 1.0 - local.y));

    // Parity of the cell decides whether it leads or trails.
    float parity = mod(floor(cell.x) + floor(cell.y), 2.0);
    float t = (parity != 0.0) ? 1.0 : 0.0;
    if (flipParity) t = 1.0 - t;

    // Pull the field back towards 0.5 near a cell border, so neighbouring cells
    // meet in a gradient instead of a hard step.
    float edgeSoft = smoothstep(0.0, 1.0, clamp(edge / (band * 1.05), 0.0, 1.0));
    t = 0.5 + (t - 0.5) * edgeSoft;

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
)";

static std::string kTransitionShaderMilkwaveSpiralGlsl330 = R"(
// Spiral: an arm winding out of the centre, feathered on both sides.
// Ported from Milkwave's blend pattern 5 (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
float rnd(int v, float scale) { return fract(float(v) * scale); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    vec2 d = uv - 0.5;
    d.x *= iResolution.x / iResolution.y;
    float radius = length(d) * 1.41421356;
    float angle = atan(d.y, d.x);

    float band  = 0.42 + 0.18 * rnd(iRandStatic.x, 0.0137);
    float loops = 0.65 + 0.95 * rnd(iRandStatic.y, 0.0091);
    float phase = rnd(iRandStatic.z, 0.0173) * 6.2831853;
    bool inward = (iRandStatic.w % 2 == 0);

    float spiral = (angle + 3.14159265) / 6.2831853 + loops * radius + phase / 6.2831853;
    spiral -= floor(spiral);
    // Fold the wrap-around into a symmetric distance from the arm's centre,
    // otherwise the arm tears where its two ends meet.
    float dist = min(abs(spiral - 0.5) * 2.0, 1.0);
    float t = smoothstep(0.0, 1.0, dist);
    // Keep the middle neutral longer, so the turn reads instead of the centre
    // flashing all at once.
    float soften = 0.05 + 0.95 * smoothstep(0.0, 1.0, radius);
    t = 0.5 + (t - 0.5) * soften;
    if (inward) t = 1.0 - t;

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
)";

static std::string kTransitionShaderMilkwaveRhombusGlsl330 = R"(
// Rhombus: a diamond growing from (or closing on) the centre.
// Ported from Milkwave's blend pattern 6 (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
float rnd(int v, float scale) { return fract(float(v) * scale); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    vec2 d = uv - 0.5;
    d.x *= iResolution.x / iResolution.y;

    float band = 0.07 + 0.12 * rnd(iRandStatic.x, 0.0137);
    bool reverse = (iRandStatic.y % 2 == 0);

    // Manhattan distance is what makes it a diamond rather than a circle.
    float t = (abs(d.x) + abs(d.y)) * 0.5;
    if (reverse) t = 1.0 - t;

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
)";

static std::string kTransitionShaderMilkwaveNuclearClockGlsl330 = R"(
// Nuclear clock: three hands at once, with a glow leading from the centre.
// Ported from Milkwave's blend pattern 7 (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
float rnd(int v, float scale) { return fract(float(v) * scale); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    float band  = 0.05 + 0.15 * rnd(iRandStatic.x, 0.0137);
    float glowI = 0.5 + 1.5 * rnd(iRandStatic.y, 0.0091);
    bool reverse = (iRandStatic.z % 2 == 0);
    vec2 centre = vec2(0.5) + (vec2(rnd(iRandStatic.w, 0.0137), rnd(iRandStatic.w, 0.0211)) - 0.5) * 0.1;

    vec2 d = uv - centre;
    d.x *= iResolution.x / iResolution.y;
    float radius = length(d) * 1.41421356;
    float angle = atan(d.y, d.x);
    if (angle < 0.0) angle += 6.2831853;

    const float repeats = 3.0;
    float clockPos = angle / 6.2831853 * repeats;
    if (reverse) clockPos = repeats - clockPos;
    clockPos -= floor(clockPos);

    float t = clockPos + (1.0 - radius) * glowI * 0.3;

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
)";

static std::string kTransitionShaderMilkwaveCrossGlsl330 = R"(
// Cross: an X or a + opening out of the centre.
// Ported from Milkwave's blend pattern 8 (branche Square/Diamond) (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
float rnd(int v, float scale) { return fract(float(v) * scale); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    vec2 d = uv - 0.5;
    d.x *= iResolution.x / iResolution.y;

    float band     = 0.08 + 0.12 * rnd(iRandStatic.x, 0.0137);
    bool diagonal  = (iRandStatic.y % 2 == 0);
    float bias     = 0.3 + 0.4 * rnd(iRandStatic.z, 0.0091);
    float softness = 0.1 + 0.2 * rnd(iRandStatic.w, 0.0173);

    float t;
    if (diagonal) {
        float d1 = (d.x + d.y) * 0.7071;
        float d2 = (d.x - d.y) * 0.7071;
        t = max(abs(d1), abs(d2));
    } else {
        t = max(abs(d.x), abs(d.y));
    }
    t = pow(max(t, 0.0), bias);
    t = clamp(t * (1.0 + softness) - softness * 0.5, 0.0, 1.0);

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
)";

static std::string kTransitionShaderMilkwaveLinesGlsl330 = R"(
// Vertical lines: a repeating sawtooth sweeping sideways.
// Ported from Milkwave's blend pattern 10 (linesvertical) (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
float rnd(int v, float scale) { return fract(float(v) * scale); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    const float repeats = 2.0;
    const float phase   = 0.18;
    float band = 0.10 + 0.03 * rnd(iRandStatic.x, 0.0137);

    float t = fract(uv.x * repeats + phase);

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
)";

static std::string kTransitionShaderMilkwaveDonutsGlsl330 = R"(
// Donuts: a bullseye whose inner disc and outer ring close in on a ring.
// Ported from Milkwave's blend pattern 11 (donuts) (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
// Progress drives the RADII here, not only the mask - that is what makes the
// ring travel instead of merely fading.
float rnd(int v, float scale) { return fract(float(v) * scale); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    vec2 d = uv - 0.5;
    d.x *= iResolution.x / iResolution.y;
    float radius = length(d) * 1.41421356;
    float angle = atan(d.y, d.x);

    float band = 0.22 + 0.04 * rnd(iRandStatic.x, 0.0137);
    float p = iProgressCosine * iProgressCosine;
    float inner = 0.05 + 0.26 * p;
    float outer = max(0.68 + 0.12 * p, inner + 0.20);

    float t;
    if (radius <= inner)                 t = 1.0;
    else if (radius < inner + band)      t = 1.0 - smoothstep(0.0, 1.0, (radius - inner) / band);
    else if (radius < outer - band)      t = 0.0;
    else if (radius < outer)             t = smoothstep(0.0, 1.0, (radius - (outer - band)) / band);
    else                                 t = 1.0;

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
)";

static std::string kTransitionShaderMilkwaveBubblesGlsl330 = R"(
// Bubbles: overlapping discs swelling until they cover the frame.
// Ported from Milkwave's blend pattern 11 (branche Bubble) (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
// ADAPTED, not transcribed: Milkwave draws 10-40 bubbles from a random array
// and takes the max influence per vertex. A shader has no such array, so the
// bubbles live on a hashed lattice - one per cell, jittered - and only the 3x3
// neighbourhood is tested. Same look, bounded cost.
float rnd(int v, float scale) { return fract(float(v) * scale); }

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    float band = 0.05 + 0.15 * rnd(iRandStatic.x, 0.0137);
    float seed = rnd(iRandStatic.y, 0.0091) * 64.0;
    bool growing = (iRandStatic.z % 2 == 0);

    vec2 p = uv * vec2(iResolution.x / iResolution.y, 1.0) * 4.0;
    vec2 cell = floor(p);
    float influence = 0.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 c = cell + vec2(float(i), float(j));
            vec2 centre = c + vec2(hash21(c + seed), hash21(c + seed + 7.3));
            float r = 0.35 + 0.45 * hash21(c + seed + 19.1);
            float v = 1.0 - length(p - centre) / r;
            influence = max(influence, smoothstep(0.0, 1.0, max(v, 0.0)));
        }
    }
    float t = growing ? influence : (1.0 - influence);

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
)";

static std::string kTransitionShaderMilkwaveKaleidoscopeGlsl330 = R"(
// Kaleidoscope: 3 to 12 mirrored wedges arriving together.
// Ported from Milkwave's blend pattern 12 (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
float rnd(int v, float scale) { return fract(float(v) * scale); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    vec2 d = uv - 0.5;
    d.x *= iResolution.x / iResolution.y;
    float radius = length(d) * 1.41421356;
    float angle = atan(d.y, d.x);

    float band     = 0.06 + 0.14 * rnd(iRandStatic.x, 0.0137);
    float segments = 3.0 + floor(rnd(iRandStatic.y, 0.0091) * 9.0);
    float rotation = rnd(iRandStatic.z, 0.0173) * 6.2831853;
    bool mirrored  = (iRandStatic.w % 2 == 0);
    float radial   = 0.5 + rnd(iRandStatic.w, 0.0211);

    float a = angle + rotation;
    if (a < 0.0) a += 6.2831853;
    a = mod(a, 6.2831853);

    float segAngle = 6.2831853 / segments;
    float offset = mod(a, segAngle);
    // Mirroring is what turns a rotation into a kaleidoscope: without it the
    // wedges all lean the same way.
    if (mirrored && offset > segAngle * 0.5) offset = segAngle - offset;

    float t = (offset / segAngle) * 0.7 + radius * 0.3 * radial;

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
)";

static std::string kTransitionShaderMilkwaveMoebiusGlsl330 = R"(
// Moebius: concentric bands twisted by a half turn around the circle.
// Ported from Milkwave's blend pattern 13 (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
float rnd(int v, float scale) { return fract(float(v) * scale); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    vec2 d = uv - 0.5;
    d.x *= iResolution.x / iResolution.y;
    float radius = length(d) * 1.41421356;
    float angle = atan(d.y, d.x);

    float band       = 0.07 + 0.13 * rnd(iRandStatic.x, 0.0137);
    float twist      = 1.0 + 2.0 * rnd(iRandStatic.y, 0.0091);
    float stripWidth = 0.3 + 0.4 * rnd(iRandStatic.z, 0.0173);
    float offset     = 0.5 * rnd(iRandStatic.w, 0.0211);
    bool reverse     = (iRandStatic.w % 2 == 0);

    float na = (angle + 3.14159265) / 6.2831853;
    float twistProgress = (na + offset) * twist;
    if (reverse) twistProgress = -twistProgress;

    float m = radius + 0.3 * sin(twistProgress * 3.14159265);
    float t = 1.0 - fract(m / stripWidth);

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
)";

static std::string kTransitionShaderMilkwaveStarsGlsl330 = R"(
// Stars: ten flat sectors radiating from the centre.
// Ported from Milkwave's blend pattern 14 (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
float rnd(int v, float scale) { return fract(float(v) * scale); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    vec2 d = uv - 0.5;
    d.x *= iResolution.x / iResolution.y;
    float radius = length(d) * 1.41421356;
    float angle = atan(d.y, d.x);

    float band     = 0.07 + 0.03 * rnd(iRandStatic.x, 0.0137);
    float phase    = rnd(iRandStatic.y, 0.0091) * 6.2831853;
    float edgeSoft = 0.16 + 0.08 * rnd(iRandStatic.z, 0.0173);
    bool reverse   = (iRandStatic.w % 2 == 0);

    const float segmentCount = 10.0;
    float segment = 6.2831853 / segmentCount;

    float a = angle + phase;
    if (a < 0.0) a += 6.2831853;
    a = mod(a, 6.2831853);

    float sectorPos = a / segment;
    float sector = floor(sectorPos);
    float local = sectorPos - sector;
    float edge = smoothstep(0.0, 1.0, min(min(local, 1.0 - local) / edgeSoft, 1.0));

    float sectorColor = mod(sector, 2.0) == 0.0 ? 1.0 : 0.0;
    float fill = iProgressCosine;
    float t = clamp(fill + (sectorColor - 0.5) * edge * (1.0 - fill) * 2.0, 0.0, 1.0);
    if (reverse) t = 1.0 - t;

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
)";

static std::string kTransitionShaderMilkwaveDiscoFloorGlsl330 = R"(
// Disco floor: a tiled floor pulsing on its own beat.
// Ported from Milkwave's blend pattern 15 (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
// Milkwave accumulates a static clock at the frame rate; iTime is the same
// idea without the hidden state.
precision highp float;

float rnd(int v, float scale) { return fract(float(v) * scale); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    float band     = 0.08 + 0.12 * rnd(iRandStatic.x, 0.0137);
    float tiles    = 8.0 + floor(rnd(iRandStatic.y, 0.0091) * 25.0);
    float beatSync = 0.5 + 1.5 * rnd(iRandStatic.z, 0.0173);
    float speed    = 0.5 + 2.0 * rnd(iRandStatic.w, 0.0211);
    bool diagonal  = (iRandStatic.y % 2 == 0);

    float t0 = iTime * speed;
    float beat = pow(sin(t0 * 3.0) * 0.5 + 0.5, beatSync);

    vec2 tile = floor(uv * tiles);
    float pattern = diagonal ? (mod(tile.x + tile.y, 2.0) * 0.8 + 0.1)
                             : ((mod(tile.x, 2.0) == mod(tile.y, 2.0)) ? 0.9 : 0.1);
    float anim = sin(t0 * 2.0 + tile.x * 0.3 + tile.y * 0.7) * 0.5 + 0.5;

    float t = (pattern * 0.7 + anim * 0.3) * beat;

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
)";

static std::string kTransitionShaderMilkwaveFireGlsl330 = R"(
// Fire: a flame front climbing from the bottom edge.
// Ported from Milkwave's blend pattern 16 (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
precision highp float;

float rnd(int v, float scale) { return fract(float(v) * scale); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    float band  = 0.08 + 0.04 * rnd(iRandStatic.x, 0.0137);
    float speed = 0.7 + 0.6 * rnd(iRandStatic.y, 0.0091);
    float s1 = rnd(iRandStatic.z, 0.0137) * 10.0;
    float s2 = rnd(iRandStatic.z, 0.0211) * 20.0;
    float s3 = rnd(iRandStatic.w, 0.0173) * 30.0;

    float t0 = iTime;
    // Three octaves of sine along x: enough to read as flame tongues without a
    // noise fetch.
    float flicker = sin(uv.x * 15.0 + s1 + t0 * 2.0) * 0.4
                  + sin(uv.x * 30.0 + s2 + t0 * 3.7) * 0.2
                  + sin(uv.x * 45.0 + s3 + t0 * 5.3) * 0.1;

    float shape = (1.0 - uv.y) * (0.3 + flicker * 0.7);
    float front = mod(t0 * speed, 1.5);
    float t = clamp(1.0 - (uv.y - front + shape), 0.0, 1.0);

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
)";

static std::string kTransitionShaderMilkwaveDrainSwirlGlsl330 = R"(
// Drain swirl: the frame spiralling into the centre.
// Ported from Milkwave's blend pattern 17 (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
// Milkwave credits Incubo_ for the modification.
precision highp float;

float rnd(int v, float scale) { return fract(float(v) * scale); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    vec2 d = uv - 0.5;
    d.x *= iResolution.x / iResolution.y;
    float radius = length(d) * 1.41421356;
    float angle = atan(d.y, d.x);

    float band      = 0.05 + 0.15 * rnd(iRandStatic.x, 0.0137);
    float intensity = 2.0 + 3.0 * rnd(iRandStatic.y, 0.0091);
    float speed     = 0.5 + 1.5 * rnd(iRandStatic.z, 0.0173);
    float pull      = 0.7 + 0.6 * rnd(iRandStatic.w, 0.0211);
    bool clockwise  = (iRandStatic.y % 2 == 0);
    bool invert     = (iRandStatic.z % 2 == 0);

    // The swirl tightens towards the centre, which is what sells the drain.
    float swirl = (1.0 - radius) * intensity;
    if (clockwise) swirl = -swirl;
    float swirled = angle + swirl + iTime * speed * 2.0;

    float t = radius * pull + (1.0 - pull) * (0.5 + 0.5 * sin(swirled * 2.0 + radius * 5.0));
    if (invert) t = 1.0 - t;

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
)";

static std::string kTransitionShaderMilkwaveJuliaGlsl330 = R"(
// Julia: the escape time of a Julia set as the wipe field.
// Ported from Milkwave's blend pattern 18 (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
// One departure: Milkwave normalises the field against the min/max over the
// whole mesh, which a fragment shader cannot do without a reduction pass. The
// smooth escape count is already ~0..1, so it is used directly and the contrast
// term absorbs the difference.
precision highp float;

float rnd(int v, float scale) { return fract(float(v) * scale); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    float band     = 0.08 + 0.12 * rnd(iRandStatic.x, 0.0137);
    float cRe      = -0.8 + 1.6 * rnd(iRandStatic.y, 0.0137);
    float cIm      = -0.8 + 1.6 * rnd(iRandStatic.y, 0.0211);
    float zoom     = 0.7 + 1.6 * rnd(iRandStatic.z, 0.0091);
    float rotation = rnd(iRandStatic.z, 0.0173) * 6.2831853;
    float softness = 0.3 + 0.5 * rnd(iRandStatic.w, 0.0137);
    float contrast = 0.7 + 0.6 * rnd(iRandStatic.w, 0.0211);
    const int maxIterations = 28;

    vec2 d = uv - 0.5;
    d.x *= iResolution.x / iResolution.y;
    float cr = cos(rotation), sr = sin(rotation);
    vec2 z = vec2(d.x * cr - d.y * sr, d.x * sr + d.y * cr) * zoom * 3.0;

    int i = 0;
    for (int k = 0; k < maxIterations; k++) {
        z = vec2(z.x * z.x - z.y * z.y + cRe, 2.0 * z.x * z.y + cIm);
        if (dot(z, z) > 4.0) break;
        i = k + 1;
    }

    float t;
    if (i < maxIterations) {
        float logZn = log(max(dot(z, z), 1e-6)) * 0.5;
        float nu = log(max(logZn / log(2.0), 1e-6)) / log(2.0);
        t = (float(i) + 1.0 - nu) / float(maxIterations);
    } else {
        t = 1.0;
    }
    t = pow(clamp(t, 0.0, 1.0), contrast);
    t = smoothstep(0.0, 1.0, t) * (1.0 - softness) + t * softness;

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
)";

static std::string kTransitionShaderHeaderGlsl330 = R"(
// Uniforms
uniform vec3 iResolution;
uniform vec4 durationParams;
uniform vec2 timeParams;
uniform float iFrameRate;
uniform int iFrame;
uniform ivec4 iRandStatic;
uniform ivec4 iRandFrame;
uniform vec3 iBeatValues;
uniform vec3 iBeatAttValues;

#define iProgressLinear durationParams.x
#define iProgressCosine durationParams.y
#define iProgressBicubic durationParams.z
#define iTransitionDuration durationParams.w

#define iTime timeParams.x
#define iTimeDelta timeParams.y

#define iBass iBeatValues.x;
#define iMid iBeatValues.y;
#define iTreb iBeatValues.z;

#define iBassAtt iBeatAttValues.x;
#define iMidAtt iBeatAttValues.y;
#define iTrebAtt iBeatAttValues.z;

// Samplers
uniform sampler2D iChannel0;
uniform sampler2D iChannel1;

// These are named as in Milkdrop shaders so we can reuse the code.
uniform sampler2D sampler_noise_lq;
uniform sampler2D sampler_pw_noise_lq;
uniform sampler2D sampler_noise_mq;
uniform sampler2D sampler_pw_noise_mq;
uniform sampler2D sampler_noise_hq;
uniform sampler2D sampler_pw_noise_hq;
uniform sampler3D sampler_noisevol_lq;
uniform sampler3D sampler_pw_noisevol_lq;
uniform sampler3D sampler_noisevol_hq;
uniform sampler3D sampler_pw_noisevol_hq;

#define iNoiseLQ sampler_noise_lq;
#define iNoiseLQNearest sampler_pw_noise_lq;
#define iNoiseMQ sampler_noise_mq;
#define iNoiseMQNearest sampler_pw_noise_mq;
#define iNoiseHQ sampler_noise_hq;
#define iNoiseHQNearest sampler_pw_noise_hq;
#define iNoiseVolLQ sampler_noisevol_lq;
#define iNoiseVolLQNearest sampler_pw_noisevol_lq;
#define iNoiseVolHQ sampler_noisevol_hq;
#define iNoiseVolHQNearest sampler_pw_noisevol_hq;

// Shader output
out vec4 _prjm_transition_out;
)";

static std::string kTransitionShaderMainGlsl330 = R"(

void main() {
    _prjm_transition_out = vec4(1.0, 1.0, 1.0, 1.0);

    vec4 _user_out_color = vec4(1.0, 1.0, 1.0, 1.0);

    mainImage(_user_out_color, gl_FragCoord.xy);

    _prjm_transition_out = vec4(_user_out_color.xyz, 1.0);
})";


