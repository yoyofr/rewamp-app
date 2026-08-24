// Disco floor: a tiled floor pulsing on its own beat.
// Ported from Milkwave's blend pattern 15 (plugin_blendpatterns.cpp), BSD-3.
// The mask expression is the one derived in the clock shader; only `t`, the
// spatial field, differs.
// Milkwave accumulates a static clock at the frame rate; iTime is the same
// idea without the hidden state.
precision highp float;

float rnd(int v, float scale) { return fract(float(v) * scale); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 imgOld = texture(iChannel0, uv).xyz;
    vec3 imgNew = texture(iChannel1, uv).xyz;

    float band     = 0.08 + 0.12 * rnd(iRandStatic.x, 0.0137);
    float tiles    = 8.0 + floor(rnd(iRandStatic.y, 0.0091) * 25.0);
    float beatSync = 0.5 + 1.5 * rnd(iRandStatic.z, 0.0173);
    float speed    = 0.5 + 2.0 * rnd(iRandStatic.w, 0.0211);
    bool diagonal  = (iRandStatic.y % 2 == 0);

    float t0 = iTime * speed;
    float beat = pow(sin(t0 * 3.0) * 0.5 + 0.5, beatSync);

    vec2 tile = floor(uv * tiles);
    float pattern = diagonal ? (mod(tile.x + tile.y, 2.0) * 0.8 + 0.1)
                             : ((mod(tile.x, 2.0) == mod(tile.y, 2.0)) ? 0.9 : 0.1);
    float anim = sin(t0 * 2.0 + tile.x * 0.3 + tile.y * 0.7) * 0.5 + 0.5;

    float t = (pattern * 0.7 + anim * 0.3) * beat;

    float mask = clamp(((1.0 + band) * iProgressCosine + t - 1.0) / band, 0.0, 1.0);
    fragColor = vec4(mix(imgOld, imgNew, mask), 1.0);
}
