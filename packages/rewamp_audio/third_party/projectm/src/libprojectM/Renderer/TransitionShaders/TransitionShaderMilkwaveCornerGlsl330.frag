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
