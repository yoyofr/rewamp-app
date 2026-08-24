#include <flutter/runtime_effect.glsl>

// Launch-intro effect: "Twister" — the demoscene rubber bar, a real
// square-section column of four faces.
//
//   face 0  the SUN — square-on at frame 0, so the effect starts as the
//           native splash and nothing moves until it does
//   face 2  the full rewamp lockup, on the OPPOSITE side: it arrives by
//           rotation, not by fading in
//   1 / 3   the sides, a checkerboard
//
// The column is exactly the logo box WIDE — at angle 0 the two side faces are
// edge-on (zero width) and face 0 covers the box precisely, so frame 0 is the
// flat sun over kBg, pixel for pixel (invariant 1). Making the bar narrower is
// what broke that in an earlier pass: the sun came out shrunk the instant the
// effect began.
//
// It is much TALLER than the box, centred on the sun so the overhang is even
// above and below. The column has a SKIN of its own over that whole height and
// the artwork is painted ON it — without it the front face showed nothing where
// the logo is transparent, so the bar had a hole exactly around the sun and the
// ground read through, darker than the panels above and below. The skin fades
// in and out with the dance, so at frame 0 and at the landing there is nothing
// but kBg behind the artwork: both hand-offs stay exact.
//
// The TWIST TRAVELS. Each row runs the same half turn, but starts later the
// lower it is (kLag), so the motion begins at the top and propagates down —
// that lag IS the torsion, and it costs nothing at the ends: every row
// converges on 0 and on pi, so the two flat poses stay exact by construction
// rather than by windowing. A small damped swing rides on top for rubber.
//
// LIGHT comes from the LEFT, level, at 90 degrees, and it ONLY EVER ADDS: the
// gain is 1 + kLit * lambert, never an ambient floor below 1. An ambient of
// 0.55 was multiplying the whole face — its background included — so the ground
// behind the sun went dark the moment the effect started, which is exactly the
// thing that must not move.
//
// Timeline (uProgress 0..1, ~2.6s):
//   0.00        sun only over kBg, dead flat (invariant 1)
//   0.06..0.20  the top starts turning, the overhang fades up
//   0.20..0.82  the twist travels down the bar; the logo face comes round
//   0.82..0.88  every row has landed square-on = the flat logo
//   0.88..1.00  shared dissolve to transparent (invariant 2)
//
// Uniform/texture contract + invariants: see splash_common.glsl.
#include "splash_common.glsl"

const float kPI     = 3.14159265;
const float kHalfPI = 1.57079633;
const float kR      = 0.70710678;  // half-diagonal: face-on width == logo box
const float kSunC   = 0.43;        // sun centre in logo-UV: the bar centres here
const float kBarH   = 2.30;        // bar height, in logo-box heights
const float kSpin   = 0.30;        // how long ONE row takes to make its half turn
const float kLag    = 0.40;        // top-to-bottom delay: this is the torsion
const float kLagP   = 0.35;        // <1 packs the delay near the TOP: see below
const float kSwing  = 0.34;        // damped rubber overshoot, radians
const float kEdgeAA = 0.005;       // face-edge softness, logo-UV units
const float kLit    = 0.85;        // how much a left-facing side GAINS (never loses)
const vec3  kSkin   = vec3(0.17, 0.08, 0.24);  // the column's own material

// The delay of a row, 0 at the top of the bar and kLag at its foot. The CURVE
// is what sets where the bar is most wrung: torsion is the delay's slope, so an
// exponent below 1 piles that slope into the top rows — the head is already
// hard twisted while the foot has barely stirred, which is the demoscene look.
// Linear (kLagP == 1) spreads the same total delay evenly and reads limp.
float rowDelay(float yBar) {
    return kLag * pow(clamp(yBar, 0.0, 1.0), kLagP);
}

// Half a turn for THIS row. `d` is the row's delay.
float spinAngle(float p, float d, float yBar) {
    float t = clamp((p - 0.06 - d) / kSpin, 0.0, 1.0);
    // Damped swing: zero at both ends, so the row still lands dead square. The
    // head whips harder than the foot, like a bar held at the bottom. Rows that
    // have not started or have already landed skip the sine outright — at any
    // moment most of the bar is in one of those two states.
    float swing = 0.0;
    if (t > 0.0 && t < 1.0) {
        float amp = kSwing * (0.6 + 0.9 * (1.0 - yBar));
        swing = amp * sin(6.28318 * t) * (1.0 - t) * (1.0 - t);
    }
    return smoothstep(0.0, 1.0, t) * kPI + swing;
}

// Side material: two purples of the splash palette.
vec3 checker(float u, float y) {
    float c = mod(floor(u * 12.0) + floor(y * 12.0), 2.0);
    return mix(vec3(0.14, 0.07, 0.20), vec3(0.38, 0.18, 0.48), c);
}

void main() {
    vec2 fc  = FlutterFragCoord().xy;
    vec2 luv = (fc - uLogoRect.xy) / uLogoRect.zw;
    float p  = uProgress;

    vec3 base = kBg;

    // Bar space: 0 at the top of the column, 1 at its foot. The logo box is the
    // slice 0..1 of luv.y inside it.
    float yBar = (luv.y - (kSunC - kBarH * 0.5)) / kBarH;

    // The column is kR wide EITHER SIDE of centre at every angle (a corner is
    // at kR by construction), so a fragment further out than that can never be
    // covered, whatever the row is doing. Without this cull every fragment of
    // the bar's full-height band paid the whole trigonometry for nothing, and
    // the bar is only ~0.7 of the logo box wide inside a band that spans 2.3
    // logo heights: on a phone that is most of the screen.
    float dx = luv.x - 0.5;
    if (yBar >= 0.0 && yBar <= 1.0 && abs(dx) <= kR + kEdgeAA) {
        float ang = spinAngle(p, rowDelay(yBar), yBar);
        float a0  = ang + kHalfPI;   // face 0 square-on at ang == 0
        // ONE sine and ONE cosine for the whole column section. The four faces
        // are a quarter turn apart, so their corners and normals are the same
        // two numbers permuted and negated — the loop used to call cos/sin
        // four times over (16 transcendentals per fragment) to rediscover
        // that. Corner k is kR*cos(a0 + k*pi/2 - pi/4), which expands to
        // 0.5*(cos + sin) of the face normal; the four come out as +-xA, +-xB.
        float cn = cos(a0), sn = sin(a0);
        float xA = 0.5 * (cn + sn);   // corner 0
        float xB = 0.5 * (cn - sn);   // corner 1  (corner 2 = -xA, 3 = -xB)

        // The column has a SKIN of its own, over its whole height, and the
        // artwork is painted ON it. Without it the front face showed nothing
        // where the logo is transparent, so the bar had a hole exactly around
        // the sun - the ground read through, darker than the panels above and
        // below, which is what looked like the background turning black.
        // The skin fades up as the dance starts and away before it ends, and
        // its tips soften, so at frame 0 and at the landing there is nothing
        // but kBg behind the artwork: both hand-offs stay exact.
        bool  inBox = luv.y >= 0.0 && luv.y <= 1.0;
        float tip   = smoothstep(0.0, 0.10, yBar) * (1.0 - smoothstep(0.90, 1.0, yBar));
        float win   = smoothstep(0.04, 0.20, p) * (1.0 - smoothstep(0.74, 0.86, p));
        float skinA = win * tip;

        vec3  col = kBg;
        float cov = 0.0;
        for (float k = 0.0; k < 4.0; k += 1.0) {
            // Corners and normal, permuted from the single sin/cos above.
            float xL = k < 0.5 ? xA : (k < 1.5 ?  xB : (k < 2.5 ? -xA : -xB));
            float xR = k < 0.5 ? xB : (k < 1.5 ? -xA : (k < 2.5 ? -xB :  xA));
            float sN = k < 0.5 ? sn : (k < 1.5 ?  cn : (k < 2.5 ? -sn : -cn));
            float cN = k < 0.5 ? cn : (k < 1.5 ? -sn : (k < 2.5 ? -cn :  sn));
            if (sN <= 0.0) continue;                         // faces away

            float lo = min(xL, xR), hi = max(xL, xR);
            float c = smoothstep(lo - kEdgeAA, lo + kEdgeAA, dx) *
                      (1.0 - smoothstep(hi - kEdgeAA, hi + kEdgeAA, dx));
            if (c <= 0.0) continue;

            float u = clamp((xL - dx) / max(xL - xR, 1e-4), 0.0, 1.0);

            // Light from the LEFT, level (90 degrees): direction (-1, 0), so a
            // face gains by how far its normal points left. A pure GAIN: at
            // rest it is exactly 1, which is what leaves both flat poses - and
            // the ground they sit on - untouched, no window needed.
            float gain = 1.0 + kLit * max(0.0, -cN);

            // Materials, composited over the column's own skin. Face 0 shows
            // the sun ALONE (the frame-0 image), face 2 the whole lockup — so
            // the wordmark arrives by turning. The logo texture is
            // PREMULTIPLIED (see splash_common.glsl): its rgb goes over the
            // skin as it is, never multiplied by alpha a second time.
            vec3 faceCol;
            if (k == 1.0 || k == 3.0) {
                // A side is never seen in a flat pose, so it is pure material.
                faceCol = mix(kBg, checker(u, yBar * kBarH) * gain, skinA);
            } else {
                vec3 skin = mix(kBg, kSkin * gain, skinA);
                if (inBox) {
                    // Face 2 is painted ON the back: read it the right way
                    // round rather than mirrored by the geometry.
                    vec4  tex  = texture(uTexLogo,
                                         vec2(k == 0.0 ? u : 1.0 - u, luv.y));
                    float band = (k == 0.0 && luv.y > kSplit) ? 0.0 : 1.0;
                    faceCol = skin * (1.0 - tex.a * band) + tex.rgb * band * gain;
                } else {
                    faceCol = skin;
                }
            }

            col = mix(col, faceCol, c);
            cov = max(cov, c);
        }
        base = mix(base, col, cov);
    }

    float outA = dissolveAlpha(p);
    fragColor = vec4(base * outA, outA);   // frame-0: face 0 square-on = the sun
}
