// Clock wipe: a hand sweeping around the centre, with a slight radial bias.
// Ported from Milkwave's blend pattern 4 (plugin_blendpatterns.cpp), BSD-3.
//
// Milkwave computes, per MESH VERTEX, two coefficients a and c such that the
// new preset's weight is clamp(a * progress + c, 0, 1) (milkdropfs.cpp:2029),
// with a = (1 + band)/band and c = (t - 1)/band. Substituting gives the single
// expression every ported pattern shares; only `t`, the spatial field, differs.
// Per-pixel here instead of per-vertex, so the mask is exact rather than
// interpolated across the warp mesh.
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    // Per-transition randomness, from the same source the built-in sweep uses.
    float band       = 0.08 + 0.14 * fract(float(iRandStatic.x) * 0.0137);
    float dir        = (iRandStatic.y % 2 == 0) ? 1.0 : -1.0;
    float startAngle = fract(float(iRandStatic.z) * 0.0091) * 6.2831853;

    vec2 d = uv - 0.5;
    d.x *= iResolution.x / iResolution.y;   // keep the hand circular

    float angle = atan(d.y, d.x);           // -PI..PI
    if (angle < 0.0) angle += 6.2831853;
    angle = mod(angle * dir + startAngle + 62.831853, 6.2831853);

    float dist = length(d) * 1.41421356;
    float t = angle / 6.2831853;
    // Seamless wrap: the sliver just past zero belongs to the END of the sweep,
    // otherwise the hand tears where it meets its own start.
    if (t < band) t += 1.0;
    t -= dist * 0.1;                        // slight radial lead

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
