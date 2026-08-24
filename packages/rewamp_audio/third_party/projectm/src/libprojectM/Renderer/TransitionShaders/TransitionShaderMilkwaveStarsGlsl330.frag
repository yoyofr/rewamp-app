// Stars: ten flat sectors radiating from the centre.
// Ported from Milkwave's blend pattern 14 (plugin_blendpatterns.cpp), BSD-3.
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

    float band     = 0.07 + 0.03 * rnd(iRandStatic.x, 0.0137);
    float phase    = rnd(iRandStatic.y, 0.0091) * 6.2831853;
    float edgeSoft = 0.16 + 0.08 * rnd(iRandStatic.z, 0.0173);
    bool reverse   = (iRandStatic.w % 2 == 0);

    const float segmentCount = 10.0;
    float segment = 6.2831853 / segmentCount;

    float a = angle + phase;
    if (a < 0.0) a += 6.2831853;
    a = mod(a, 6.2831853);

    float sectorPos = a / segment;
    float sector = floor(sectorPos);
    float local = sectorPos - sector;
    float edge = smoothstep(0.0, 1.0, min(min(local, 1.0 - local) / edgeSoft, 1.0));

    float sectorColor = mod(sector, 2.0) == 0.0 ? 1.0 : 0.0;
    float fill = iProgressCosine;
    float t = clamp(fill + (sectorColor - 0.5) * edge * (1.0 - fill) * 2.0, 0.0, 1.0);
    if (reverse) t = 1.0 - t;

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
