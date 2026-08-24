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
