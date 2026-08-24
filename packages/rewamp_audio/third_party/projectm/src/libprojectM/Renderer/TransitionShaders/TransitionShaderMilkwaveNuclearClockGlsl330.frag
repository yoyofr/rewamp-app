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
