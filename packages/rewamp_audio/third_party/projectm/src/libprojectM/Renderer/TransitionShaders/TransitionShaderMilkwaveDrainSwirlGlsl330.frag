// Drain swirl: the frame spiralling into the centre.
// Ported from Milkwave's blend pattern 17 (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
// Milkwave credits Incubo_ for the modification.
precision highp float;

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

    float band      = 0.05 + 0.15 * rnd(iRandStatic.x, 0.0137);
    float intensity = 2.0 + 3.0 * rnd(iRandStatic.y, 0.0091);
    float speed     = 0.5 + 1.5 * rnd(iRandStatic.z, 0.0173);
    float pull      = 0.7 + 0.6 * rnd(iRandStatic.w, 0.0211);
    bool clockwise  = (iRandStatic.y % 2 == 0);
    bool invert     = (iRandStatic.z % 2 == 0);

    // The swirl tightens towards the centre, which is what sells the drain.
    float swirl = (1.0 - radius) * intensity;
    if (clockwise) swirl = -swirl;
    float swirled = angle + swirl + iTime * speed * 2.0;

    float t = radius * pull + (1.0 - pull) * (0.5 + 0.5 * sin(swirled * 2.0 + radius * 5.0));
    if (invert) t = 1.0 - t;

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
