// Spiral: an arm winding out of the centre, feathered on both sides.
// Ported from Milkwave's blend pattern 5 (plugin_blendpatterns.cpp), BSD-3.
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

    float band  = 0.42 + 0.18 * rnd(iRandStatic.x, 0.0137);
    float loops = 0.65 + 0.95 * rnd(iRandStatic.y, 0.0091);
    float phase = rnd(iRandStatic.z, 0.0173) * 6.2831853;
    bool inward = (iRandStatic.w % 2 == 0);

    float spiral = (angle + 3.14159265) / 6.2831853 + loops * radius + phase / 6.2831853;
    spiral -= floor(spiral);
    // Fold the wrap-around into a symmetric distance from the arm's centre,
    // otherwise the arm tears where its two ends meet.
    float dist = min(abs(spiral - 0.5) * 2.0, 1.0);
    float t = smoothstep(0.0, 1.0, dist);
    // Keep the middle neutral longer, so the turn reads instead of the centre
    // flashing all at once.
    float soften = 0.05 + 0.95 * smoothstep(0.0, 1.0, radius);
    t = 0.5 + (t - 0.5) * soften;
    if (inward) t = 1.0 - t;

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
