#include <flutter/runtime_effect.glsl>

// Uniform layout:
//   uSize         → setFloat(0, w), setFloat(1, h)
//   uWaveform     → setImageSampler(0, img)  — 256×2 RGBA8
//                   row 0 (y=0.25): left  channel, R = (sample*0.5+0.5)*255
//                   row 1 (y=0.75): right channel, R = (sample*0.5+0.5)*255
uniform vec2      uSize;
uniform sampler2D uWaveform;

out vec4 fragColor;

void main() {
    vec2  fc = FlutterFragCoord().xy;
    float x  = fc.x / uSize.x;   // 0..1 horizontal
    float y  = fc.y / uSize.y;   // 0..1 vertical (0=top)

    // Bilinear sampling gives smooth interpolation between the 256 stored samples.
    float lRaw = texture(uWaveform, vec2(x, 0.25)).r;  // 0..1
    float rRaw = texture(uWaveform, vec2(x, 0.75)).r;  // 0..1

    // Map encoded [0,1] to screen Y: positive peaks go up (y=0), negative down (y=1).
    float ly = 1.0 - lRaw;
    float ry = 1.0 - rRaw;

    // Anti-aliased line: 3-px half-width in normalised Y.
    float pw = 3.0 / uSize.y;
    float la = smoothstep(pw, 0.0, abs(y - ly));
    float ra = smoothstep(pw, 0.0, abs(y - ry));

    // Left = teal-green, right = orange; additive blend where they cross.
    vec3 col = vec3(0.11, 0.91, 0.71) * la
             + vec3(1.0,  0.42, 0.12) * ra;

    // Dark background.
    col = mix(vec3(0.04, 0.06, 0.10), col, clamp(la + ra, 0.0, 1.0));

    fragColor = vec4(col, 1.0);
}
