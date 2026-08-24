// Bubbles: overlapping discs swelling until they cover the frame.
// Ported from Milkwave's blend pattern 11 (branche Bubble) (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
// ADAPTED, not transcribed: Milkwave draws 10-40 bubbles from a random array
// and takes the max influence per vertex. A shader has no such array, so the
// bubbles live on a hashed lattice - one per cell, jittered - and only the 3x3
// neighbourhood is tested. Same look, bounded cost.
float rnd(int v, float scale) { return fract(float(v) * scale); }

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    float band = 0.05 + 0.15 * rnd(iRandStatic.x, 0.0137);
    float seed = rnd(iRandStatic.y, 0.0091) * 64.0;
    bool growing = (iRandStatic.z % 2 == 0);

    vec2 p = uv * vec2(iResolution.x / iResolution.y, 1.0) * 4.0;
    vec2 cell = floor(p);
    float influence = 0.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 c = cell + vec2(float(i), float(j));
            vec2 centre = c + vec2(hash21(c + seed), hash21(c + seed + 7.3));
            float r = 0.35 + 0.45 * hash21(c + seed + 19.1);
            float v = 1.0 - length(p - centre) / r;
            influence = max(influence, smoothstep(0.0, 1.0, max(v, 0.0)));
        }
    }
    float t = growing ? influence : (1.0 - influence);

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
