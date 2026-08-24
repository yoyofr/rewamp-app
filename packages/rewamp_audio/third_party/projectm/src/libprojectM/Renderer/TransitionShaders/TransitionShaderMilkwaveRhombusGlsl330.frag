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
