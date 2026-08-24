// Donuts: a bullseye whose inner disc and outer ring close in on a ring.
// Ported from Milkwave's blend pattern 11 (donuts) (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
// Progress drives the RADII here, not only the mask - that is what makes the
// ring travel instead of merely fading.
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

    float band = 0.22 + 0.04 * rnd(iRandStatic.x, 0.0137);
    float p = iProgressCosine * iProgressCosine;
    float inner = 0.05 + 0.26 * p;
    float outer = max(0.68 + 0.12 * p, inner + 0.20);

    float t;
    if (radius <= inner)                 t = 1.0;
    else if (radius < inner + band)      t = 1.0 - smoothstep(0.0, 1.0, (radius - inner) / band);
    else if (radius < outer - band)      t = 0.0;
    else if (radius < outer)             t = smoothstep(0.0, 1.0, (radius - (outer - band)) / band);
    else                                 t = 1.0;

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
