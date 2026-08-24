// Cross: an X or a + opening out of the centre.
// Ported from Milkwave's blend pattern 8 (branche Square/Diamond) (plugin_blendpatterns.cpp), BSD-3.
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

    float band     = 0.08 + 0.12 * rnd(iRandStatic.x, 0.0137);
    bool diagonal  = (iRandStatic.y % 2 == 0);
    float bias     = 0.3 + 0.4 * rnd(iRandStatic.z, 0.0091);
    float softness = 0.1 + 0.2 * rnd(iRandStatic.w, 0.0173);

    float t;
    if (diagonal) {
        float d1 = (d.x + d.y) * 0.7071;
        float d2 = (d.x - d.y) * 0.7071;
        t = max(abs(d1), abs(d2));
    } else {
        t = max(abs(d.x), abs(d.y));
    }
    t = pow(max(t, 0.0), bias);
    t = clamp(t * (1.0 + softness) - softness * 0.5, 0.0, 1.0);

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
