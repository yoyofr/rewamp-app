#include <flutter/runtime_effect.glsl>

// Launch-intro effect: "Rotozoom" — the Amiga/ST demo staple, with the splash
// lockup itself as the tile.
//
// The tile IS the logo box: at scale 1 and angle 0 the transform is the
// identity, tile (0,0) covers uLogoRect exactly and its texels ARE the logo's,
// so frame 0 is the flat sun over kBg pixel for pixel (invariant 1) with no
// special case. That is the whole reason the rotozoom is expressed in LOGO-BOX
// units rather than screen ones — a tile of any other size would have to shrink
// or crop the sun the instant the effect began.
//
// Timeline (uProgress 0..1, ~4.2s):
//   0.00        sun only over kBg, dead flat (invariant 1)
//   0.02..0.14  the wordmark+EQ band rises into place: the lockup, fast
//   0.14..0.26  the neighbouring tiles fade up as the field starts moving
//   0.14..1.00  the pivot travels OFF centre and the spin's floor speed runs;
//               the field lands on exactly kTurns whole turns (measured at the
//               pivot — the swirl below is a DEFORMATION on top, not turn)
//   0.14..0.58  ZOOM OUT, decelerating
//   0.40..1.00  ZOOM IN, accelerating — it OVERLAPS the way out, so the field
//               never hangs between the two halves, and a spin with a speed
//               FLOOR carries the eye across the reversal the zoom itself
//               cannot avoid making
//   0.40..1.00  the spin DRAGS the tile out of shape (swirl + radial stretch)
//               and the texture PIXELISES, coarser the closer it comes — the
//               tile ends 22 logo-boxes wide, so the last second is a dive
//               INTO the artwork rather than a look at it
//   0.82..1.00  shared dissolve to transparent (invariant 2)
//
// Scale is interpolated in LOG space. A linear ramp between 1.0 and 0.155
// spends almost all its time near the small end — the eye reads zoom as
// multiplicative, so the exponent is what must be eased, never the factor.
//
// The neighbours are faded in rather than being there from the start: at
// frame 0 the transform is the identity, so a tile drawn unconditionally would
// paper the whole screen with logos and the native handoff would flash. Tile
// (0,0) is exempt from that fade — it is the lockup that just landed and it
// must not blink.
//
// Uniform/texture contract + invariants: see splash_common.glsl.
#include "splash_common.glsl"

const float kRevealA  = 0.02;   // wordmark band starts rising
const float kRevealB  = 0.14;   // ...and has landed: the lockup is complete
const float kOutEnd   = 0.58;   // the zoom-OUT ramp ends here...
const float kInStart  = 0.40;   // ...and the zoom-IN ramp already started here
const float kFar      = 0.22;   // tile size at the turn, in logo boxes
const float kNear     = 22.0;   // tile size at the end — flying INTO it
const float kInPow    = 1.8;    // how hard the return accelerates (see below)
// The field makes exactly kTurns whole turns over the intro, and the three
// terms below are how that total is SPENT, not what it is: kRotIn is the
// REMAINDER, so the landing stays a whole turn whatever the other two are
// retuned to. As three independent constants it was one edit away from 0.94 of
// a turn, which reads as a mistake rather than as a choice.
const float kTurns    = 1.0;    // whole turns by uProgress == 1
const float kRotBase  = 1.15;   // of which: spin that NEVER stops (see below)
const float kRotOut   = 1.30;   // of which: extra while going out
const float kRotIn    = 6.2831853 * kTurns - kRotBase - kRotOut;  // the rest
const vec2  kPivot    = vec2(0.42, -0.60);  // where the field turns, in logo widths
const float kSwirl    = 0.45;   // radius-dependent twist on the way in, rad/width
const float kDrag     = 0.12;   // radial stretch that rides with it
const float kFineBlk  = 1200.0; // texture blocks across a tile, un-pixelised
const float kCoarseBlk= 150.0;  // ...and at full pixelisation
const float kRise     = 0.05;   // wordmark slide, in logo-UV — matches raster

// The two tile shades of the checkerboard the logos sit on. Without a backing
// the tiles are invisible wherever the artwork is transparent, which is most of
// the box: the field would rotate with nothing to read the rotation AGAINST.
// Alternating on tile parity is what makes the spin legible at all.
const vec3 kTileA = vec3(0.115, 0.052, 0.157);
const vec3 kTileB = vec3(0.205, 0.092, 0.272);

void main() {
    vec2  fc = FlutterFragCoord().xy;
    float p  = uProgress;

    // Deceleration out, acceleration in — and the two windows OVERLAP
    // (kInStart < kOutEnd). Back to back they left the field hanging: an
    // ease-out ends at zero velocity and an ease-in starts at zero, so the two
    // flat ends met and the rotozoom visibly stopped for half a second between
    // the halves. Overlapped, the outgoing ramp is still unwinding while the
    // return is already building.
    //
    // The zoom ITSELF must still cross zero — it reverses, there is no way
    // around that — so what actually carries the eye through the turn is
    // kRotBase below: a spin that never slows at all.
    float t1 = clamp((p - kRevealB) / (kOutEnd - kRevealB), 0.0, 1.0);
    float e1 = 1.0 - pow(1.0 - t1, 2.2);
    // The return is eased with an exponent, not cubed: t^3 leaves the field
    // visibly MOTIONLESS for the best part of a second (it has covered an
    // eighth of the way at the halfway mark) and the accel then all happens
    // under the dissolve, where none of it is seen. 1.8 still reads as
    // accelerating but is moving by the time the fade starts.
    float t2 = clamp((p - kInStart) / (1.0 - kInStart), 0.0, 1.0);
    float e2 = pow(t2, kInPow);

    // Log-space scale: e1 walks 1 -> kFar, e2 then walks kFar -> kNear.
    float scale = exp(e1 * log(kFar) + e2 * log(kNear / kFar));
    // The seed only picks which WAY the field turns. It can never move frame 0:
    // every angle term it scales is already 0 there (seed 0 in tests).
    float dir   = uSeed < 0.5 ? 1.0 : -1.0;
    // kRotBase is a LINEAR term, so the spin's speed has a floor: all three
    // terms grow together, none can cancel another, and the rotation therefore
    // never reaches zero between the two zoom halves.
    float tLin  = clamp((p - kRevealB) / (1.0 - kRevealB), 0.0, 1.0);
    float ang   = dir * (tLin * kRotBase + e1 * kRotOut + e2 * kRotIn);

    // WHERE the field turns. A rotozoom pivoted dead centre reads as a
    // wallpaper being spun on the spot: the same tile stays under the middle
    // of the screen the whole way and the zoom has no direction. Off centre,
    // the field also SLIDES as it turns and the zoom has somewhere to go.
    //
    // The pivot cannot simply BE off centre — at p == 0 the transform has to be
    // the identity or the logo is not where the native splash left it. So it
    // travels there, on the same linear ramp as the base spin, and tile (0,0)'s
    // centre rides with it: the lockup drifts off the middle as the field opens
    // up, and everything afterwards turns and zooms about that point.
    vec2  c   = fc - (uLogoRect.xy + uLogoRect.zw * 0.5
                      + vec2(dir, 1.0) * kPivot * uLogoRect.z * tLin);

    // On the way IN the rotation DRAGS the tile out of shape: the turn angle
    // grows with the distance from the centre, so the grid shears into a swirl
    // instead of turning rigidly — the field looks like it is being wound up by
    // its own spin. Both terms are scaled by e2, which is 0 until kInStart, so
    // neither can touch frame 0 or the way out.
    //
    // The radius is measured in SCREEN space (logo-box widths), not tile space:
    // anchored to the screen it reads as the picture being wrung, whereas in
    // tile space the warp would travel with the zoom and look like a fixed
    // lens instead.
    float rad = length(c) / uLogoRect.z;
    float ang2 = ang + dir * kSwirl * e2 * rad;

    float ca = cos(ang2), sa = sin(ang2);
    vec2  r  = vec2(ca * c.x - sa * c.y, sa * c.x + ca * c.y);
    // ...and the same drag stretches it radially, so the swirl is not a pure
    // shear: tiles further out are pulled longer as well as further round.
    r /= 1.0 + kDrag * e2 * rad;
    vec2  g  = r / (uLogoRect.zw * scale) + 0.5;

    vec2 idx = floor(g);
    vec2 tuv = g - idx;

    // Tile (0,0) is the lockup that just landed: always solid. Every other tile
    // fades up as the field starts to move.
    float neighbours = smoothstep(kRevealB, kRevealB + 0.12, p);
    float centre     = (abs(idx.x) < 0.5 && abs(idx.y) < 0.5) ? 1.0 : 0.0;
    float logoA      = max(centre, neighbours);

    // Checkerboard backing, on tile parity.
    float par  = mod(abs(idx.x + idx.y), 2.0);
    vec3  base = mix(kBg, mix(kTileA, kTileB, par), neighbours * 0.92);

    // The lockup, painted on the tile. The band below kSplit is the wordmark+EQ:
    // it slides up out of the baseline and fades in, so at p == 0 its alpha is
    // exactly 0 and the tile shows the sun alone.
    float reveal = smoothstep(kRevealA, kRevealB, p);
    vec2  s      = tuv;
    float band   = 1.0;
    if (tuv.y > kSplit) {
        s.y += (1.0 - reveal) * kRise;
        band = reveal;
    }
    // PIXELISE on the way in. Flutter's image samplers are linear and there is
    // no API to ask for nearest, so nearest is done in the coordinate: sampling
    // exactly at a block's centre is what a nearest fetch would have returned.
    // The block COUNT coarsens as the zoom builds, so the tile turns into a
    // chunky bitmap rather than a smoothly magnified one.
    //
    // The snap is BLENDED IN (mix on the coordinate) rather than switched on.
    // Snapped-from-frame-0 would alias hard: the logo is 1000 px in a 250 pt
    // box, so at rest the field is MINIFIED 4x and an unfiltered fetch there is
    // noise — and it would break the frame-0 identity outright.
    float pixel = smoothstep(kInStart, 0.86, p);
    if (pixel > 0.0) {
        float n = exp(mix(log(kFineBlk), log(kCoarseBlk), pixel));
        s = mix(s, (floor(s * n) + 0.5) / n, pixel);
    }

    vec4  tex = texture(uTexLogo, s);          // premultiplied
    float a   = logoA * band;
    base = base * (1.0 - tex.a * a) + tex.rgb * a;

    // One magenta pulse off the sun as the field lets go, in SCREEN space so it
    // has no hard edge at the logo rect (the ring the raster effect paid for).
    float fx = smoothstep(0.10, 0.30, p) * (1.0 - smoothstep(0.34, 0.58, p));
    if (fx > 0.0) {
        float d = distance(fc, uSunPos) / uLogoRect.z;
        base += vec3(0.85, 0.18, 0.55) * exp(-d * 7.0) * fx * 0.45;
    }

    float outA = dissolveAlpha(p);
    fragColor = vec4(base * outA, outA);   // frame 0: identity tile = the sun
}
