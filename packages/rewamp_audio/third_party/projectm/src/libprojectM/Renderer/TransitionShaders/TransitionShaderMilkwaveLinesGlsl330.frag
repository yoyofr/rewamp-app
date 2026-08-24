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
