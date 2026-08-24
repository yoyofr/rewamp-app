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
