// Julia: the escape time of a Julia set as the wipe field.
// Ported from Milkwave's blend pattern 18 (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
// One departure: Milkwave normalises the field against the min/max over the
// whole mesh, which a fragment shader cannot do without a reduction pass. The
// smooth escape count is already ~0..1, so it is used directly and the contrast
// term absorbs the difference.
precision highp float;

float rnd(int v, float scale) { return fract(float(v) * scale); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    float band     = 0.08 + 0.12 * rnd(iRandStatic.x, 0.0137);
    float cRe      = -0.8 + 1.6 * rnd(iRandStatic.y, 0.0137);
    float cIm      = -0.8 + 1.6 * rnd(iRandStatic.y, 0.0211);
    float zoom     = 0.7 + 1.6 * rnd(iRandStatic.z, 0.0091);
    float rotation = rnd(iRandStatic.z, 0.0173) * 6.2831853;
    float softness = 0.3 + 0.5 * rnd(iRandStatic.w, 0.0137);
    float contrast = 0.7 + 0.6 * rnd(iRandStatic.w, 0.0211);
    const int maxIterations = 28;

    vec2 d = uv - 0.5;
    d.x *= iResolution.x / iResolution.y;
    float cr = cos(rotation), sr = sin(rotation);
    vec2 z = vec2(d.x * cr - d.y * sr, d.x * sr + d.y * cr) * zoom * 3.0;

    int i = 0;
    for (int k = 0; k < maxIterations; k++) {
        z = vec2(z.x * z.x - z.y * z.y + cRe, 2.0 * z.x * z.y + cIm);
        if (dot(z, z) > 4.0) break;
        i = k + 1;
    }

    float t;
    if (i < maxIterations) {
        float logZn = log(max(dot(z, z), 1e-6)) * 0.5;
        float nu = log(max(logZn / log(2.0), 1e-6)) / log(2.0);
        t = (float(i) + 1.0 - nu) / float(maxIterations);
    } else {
        t = 1.0;
    }
    t = pow(clamp(t, 0.0, 1.0), contrast);
    t = smoothstep(0.0, 1.0, t) * (1.0 - softness) + t * softness;

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
