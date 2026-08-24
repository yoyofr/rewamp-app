#include <flutter/runtime_effect.glsl>

// Launch-intro effect: "Starfield" — pixels rushing at the viewer while a jet
// of pixels assembles the wordmark.
//
// This .frag now holds ONLY the wordmark reveal. Both flying actors are
// sprites, drawn by splashStarfieldOverlay (splash_fx_overlays.dart):
//
//  * The STARFIELD used to live here as depth LAYERS of a jittered grid — the
//    trick that lets a fragment shader fake sprites without looping over
//    objects. It was still O(layers) PER PIXEL, and the density ramp took it
//    to 64 layers x 3 hashes x 2 divisions on every fragment of the screen:
//    ~160M inner iterations per frame at 1080x2340, which is a mobile GPU's
//    whole budget several times over. Measured as "very slow" on Android.
//    A star is an OBJECT, so it belongs where the other objects went: ~600
//    on-screen stars are now computed once per frame on the CPU and drawn as
//    a handful of drawRawPoints batches. Same model (depth planes, radial
//    rush, progressive birth), O(objects) instead of O(pixels x objects).
//    One deliberate consequence: sprites are drawn AFTER this shader, so the
//    nearest stars now pass IN FRONT of the assembling wordmark instead of
//    behind it — which is what a star rushing at the viewer should do anyway.
//    They still pass behind the sun (the canvas draws it last, sunOnTop).
//
//  * The JET (conveyor): the ribbon of pixels still to come, 180 beads per
//    frame as canvas rects.
//
// What stays here is what needs the TEXTURE: the wordmark is written the way
// a HAND would draw it — a raster scan, one pixel block after another. One
// fractional cursor slot (nHead) is the single clock: a block is lit when the
// cursor has passed its RANK in scan order, with the pen's hot trail as a
// flash. The overlay mirrors nHead, the scan band (the wordmark's measured
// box, x 0.236..0.768, y 0.595..0.689) and the three scan coins drawn from
// uSeed (row/column-major, horizontal direction, vertical direction — eight
// ways of writing the same word).
//
// Timeline (uProgress 0..1, ~3.6s):
//   0.00        sun only over kBg (invariant 1)
//   0.00..0.10  the starfield fades up
//   0.12..0.74  the jet streams; the wordmark aggregates block by block
//   0.74..0.86  the word stands — the pause — stars keep flying
//   0.82..1.00  shared dissolve to transparent (invariant 2)
//
// Uniform/texture contract + invariants: see splash_common.glsl.
#include "splash_common.glsl"

const float kRevIn   = 0.20;    // the pen touches down
const float kRevSpan = 0.52;    // the whole word is written over this window
const float kBlocks  = 128.0;   // wordmark pixelation, near the logo's own pixels
// The scan band: the wordmark's measured bounding box, padded one block.
const float kColLo   = 0.225, kColHi = 0.78;
const float kRowLo   = 0.585, kRowHi = 0.70;

void main() {
    vec2 fc  = FlutterFragCoord().xy;
    vec2 luv = (fc - uLogoRect.xy) / uLogoRect.zw;
    float p  = uProgress;

    vec3 base = kBg;

    // ---- The conveyor's clock ---------------------------------------------
    // The scan grid and the ONE clock: nHead is the fractional rank of the
    // pixel being written right now, in scan order (left to right, top to
    // bottom over the wordmark's bounding box).
    float colLo = floor(kColLo * kBlocks), colHi = floor(kColHi * kBlocks);
    float rowLo = floor(kRowLo * kBlocks), rowHi = floor(kRowHi * kBlocks);
    float nCols = colHi - colLo + 1.0;
    float nRows = rowHi - rowLo + 1.0;
    float total = nCols * nRows;
    float nHead = (p - kRevIn) / kRevSpan * total;

    // Three coins from the seed: rows-first or columns-first, then each
    // axis's direction. Same three used by the conveyor and the reveal — the
    // pattern IS part of the shared clock.
    //
    // ⚠️ SURTOUT PAS un hash à sinus ici. Le convoyeur (splash_fx_overlays.
    // dart) doit tirer EXACTEMENT les mêmes trois pièces, et il calcule en
    // float64 là où le GPU calcule en float32: `sin` est multiplié par
    // 43758.5453, si bien qu'une erreur de 6e-8 sur le sinus devient ~3e-3
    // AVANT le `fract` — assez pour franchir le seuil de 0.5. Mesuré sur des
    // graines tirées dans 0..1: les deux côtés tombent en désaccord 8 % du
    // temps sur rowMaj, 14 % sur flipX, **20 % sur flipY** (et ~50 % pour des
    // graines entières). Un désaccord sur flipY, c'est le stylo qui écrit les
    // lignes de haut en bas pendant que le convoyeur les alimente de bas en
    // haut: les billes atterrissent à la ligne MIROIR. Invisible en
    // colonnes-d'abord (la bille reste dans sa colonne), flagrant en
    // lignes-d'abord, où une rangée entière part 15 lignes plus loin.
    //
    // Les trois bits sont donc LUS dans la graine par une arithmétique que les
    // deux précisions ne peuvent pas départager: ×8 est un décalage
    // d'exposant, exact partout, et `floor` d'un exact reste exact.
    float pat    = floor(uSeed * 8.0);
    float rowMaj = mod(pat, 2.0);
    float flipX  = mod(floor(pat / 2.0), 2.0);
    float flipY  = mod(floor(pat / 4.0), 2.0);

    // ---- The wordmark, written in scan order ------------------------------
    if (luv.x >= 0.0 && luv.x <= 1.0 && luv.y > kSplit && luv.y <= 1.0) {
        vec2  cellIx = floor(luv * kBlocks);
        // This block's RANK under the same clock the conveyor runs on — the
        // alignment between a flying bead and the texel it becomes is the
        // shared nHead, nothing else. Blocks outside the scan band never light
        // (the measured box guarantees they hold no ink).
        // Cell -> rank through the SAME scan pattern as the conveyor.
        float ic = cellIx.x - colLo;
        float ir = cellIx.y - rowLo;
        if (flipX > 0.5) ic = nCols - 1.0 - ic;
        if (flipY > 0.5) ir = nRows - 1.0 - ir;
        float rank = rowMaj > 0.5 ? ir * nCols + ic : ic * nRows + ir;
        bool inBand = cellIx.x >= colLo && cellIx.x <= colHi &&
                      cellIx.y >= rowLo && cellIx.y <= rowHi;
        if (inBand && nHead > rank) {
            vec4 tex = texture(uTexLogo, luv);
            // The landing flash: the pen's trail runs hot for a few slots.
            float flash = max(0.0, 1.0 - (nHead - rank) / 26.0);
            vec3  ink   = tex.rgb * (1.0 + 1.1 * flash);
            base = base * (1.0 - tex.a) + ink;
        }
    }

    float outA = dissolveAlpha(p);
    fragColor = vec4(base * outA, outA);
}
