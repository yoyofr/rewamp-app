// Fire: a flame front climbing from the bottom edge.
// Ported from Milkwave's blend pattern 16 (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
precision highp float;

float rnd(int v, float scale) { return fract(float(v) * scale); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    float band  = 0.08 + 0.04 * rnd(iRandStatic.x, 0.0137);
    float speed = 0.7 + 0.6 * rnd(iRandStatic.y, 0.0091);
    float s1 = rnd(iRandStatic.z, 0.0137) * 10.0;
    float s2 = rnd(iRandStatic.z, 0.0211) * 20.0;
    float s3 = rnd(iRandStatic.w, 0.0173) * 30.0;

    float t0 = iTime;
    // Three octaves of sine along x: enough to read as flame tongues without a
    // noise fetch.
    float flicker = sin(uv.x * 15.0 + s1 + t0 * 2.0) * 0.4
                  + sin(uv.x * 30.0 + s2 + t0 * 3.7) * 0.2
                  + sin(uv.x * 45.0 + s3 + t0 * 5.3) * 0.1;

    float shape = (1.0 - uv.y) * (0.3 + flicker * 0.7);
    float front = mod(t0 * speed, 1.5);
    float t = clamp(1.0 - (uv.y - front + shape), 0.0, 1.0);

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
