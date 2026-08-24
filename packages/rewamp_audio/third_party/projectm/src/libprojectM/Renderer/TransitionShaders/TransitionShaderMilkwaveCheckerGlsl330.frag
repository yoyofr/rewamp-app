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
