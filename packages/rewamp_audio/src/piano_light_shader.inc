/* The piano visualizer's LIGHTING fragment shader — one text, two readers:
 * rewamp_piano_render.cpp (the app) and scripts/verify_piano_light.c (the
 * oracle that renders it in a bare ANGLE context and reads the pixels back).
 * Needs REWAMP_GL_Y_FLIPPED defined (rewamp_gl_orientation.h) before it. */
/* ── Lighting: a point light in front of each struck key, shadows cast by
 * the black keys. The keyboard is ANALYTIC in key units (a white is 1
 * wide, 1 key-length long; a black is 0.5 wide, 0.6 long, raised HB at the
 * offsets of the octave pattern), so every fragment recovers where it sits
 * — key, depth along the key, surface height — from its screen position
 * and the view uniforms alone, and each light is tested against the black
 * keys between it and the fragment by intersecting the light ray with
 * their slabs. Output is PREMULTIPLIED: rgb = light to ADD, a = how much
 * to DARKEN (dst*(1-a) + rgb) — one pass does both highlight and shadow.
 * Lights within ±3 keys only (the falloff makes the rest negligible),
 * two samples per light for a soft edge. highp on purpose: mediump on
 * Adreno/Mali cannot hold key-unit positions past a few octaves. */
static const char* k_lfrag =
    "precision highp float;\n"
    "uniform highp vec2 uView;\n"
    "uniform highp vec3 uKey;\n"     /* keyW px, offX px, keyH px */
    "uniform highp float uBase;\n"   /* px, bottom of this keyboard's keys */
    "uniform int uNL;\n"
    "uniform vec2 uLPos[32];\n"      /* x (key units), intensity */
    "uniform vec3 uLCol[32];\n"
    "uniform vec4 uPress[32];\n"     /* press amount per MIDI note, 4 per vec4 */
    "uniform int uPass;\n"           /* 0 = modulate (tint + dim), 1 = add (highlight) */
    "out vec4 fragColor;\n"
    "const float HB = 0.12;\n"       /* black key height, in key-width units */
    "const float LB = 0.6;\n"        /* black key length, in key-length units */
    "const float BW = 0.56;\n"       /* black key width (= PK_BW) */
    /* Keys PIVOT at the felt: pressed, the top edge stays put and the
     * front sinks. TILT = how much of a black key's height its far end
     * loses at full press; SINKW = how far a white key's front goes down. */
    "const float TILT = 0.6;\n"
    "const float SINKW = 0.05;\n"
    "const int WN[7] = int[7](0, 2, 4, 5, 7, 9, 11);\n"   /* white slot → semitone */
    "const int BN[5] = int[5](1, 3, 6, 8, 10);\n"          /* black slot → semitone */
    /* Component picked by a MASK, not by a dynamic subscript: `v[j]` with a
     * runtime j on a uniform vec4 is legal GLSL ES 3.0, but it is exactly
     * the kind of construct a translator (ANGLE → Metal) can get wrong,
     * and a wrong press here bends every height in the model. */
    "float pressOf(int n) {\n"
    "  int i = n / 4; int j = n - i * 4;\n"
    "  vec4 m = vec4(equal(ivec4(0, 1, 2, 3), ivec4(j)));\n"
    "  return dot(uPress[i], m);\n"
    "}\n"
    /* The light sits ON the top of the struck key — just above the black
     * keys' height so their tops still catch it — not floating in front
     * of the felt. Low and close: a tight pool of light on the key and
     * its two neighbours, shadows carved by the black keys behind it. */
    /* 2.5 black keys high. A struck BLACK key still shades the whites
     * beside it from its own light (the ray dips under its top before
     * leaving its footprint) — a wedge that tapers as the key sinks — but
     * an UNPRESSED black key beside a struck white no longer throws a long
     * stripe down that white's overlap strip: at 0.145 (just over the
     * black keys) E's and B's left third were shadowed to the bottom by
     * D#/A#, and it read as a stray band on the lit key. */
    "const float HL = 0.38;\n"       /* light height (HB = 0.12) — low, not overhead */
    "const float DL = -0.25;\n"      /* light depth: a quarter key BEHIND the felt line, in the keys' axis */
    /* Ambient: with lighting on, the resting keyboard sits in half-light so
     * a struck key's light stands out; the shadows are carved out of what
     * that light would have brought. */
    "const float AMBIENT = 0.32;\n"  /* darkening of the unlit keyboard */
    "const float GAIN = 3.6;\n"      /* light added on the lit surface */
    "const float SHADOW = 6.0;\n"    /* how fast a shadow saturates to the light's colour */
    "const float FALL = 2.2;\n"      /* attenuation: 1/(1 + FALL·d²), d in key widths */
    /* Black keys of one octave, left edge in white units. */
    /* left edges = Modizer's offsets, re-centred for BW (see pk_build_tables) */
    "const float BK[5] = float[5](0.6367, 1.8033, 3.6367, 4.72, 5.8033);\n"
    /* Is the segment light→fragment blocked by the black key at bx, whose
     * press amount pk tilts its top: height HB·(1 − pk·TILT·d/LB) at
     * depth d? Ray: h(t) = HL + (hf − HL)t, d(t) = DL + (df − DL)t. Both
     * linear, so "ray below the key top" is a half-line in t, intersected
     * with the x-slab and the key's footprint in depth [0, LB]. */
    "bool blocked(float xl, float xf, float df, float hf, float bx, float pk) {\n"
    "  float dx = xf - xl;\n"
    /* nothing stands between the light and the felt (the keys start at
       d = 0, in front of both) */
    "  if (df <= 0.0) return false;\n"
    "  if (abs(dx) < 1e-4) return false;\n"
    "  float t0 = (bx - xl) / dx, t1 = (bx + BW - xl) / dx;\n"
    "  float ta = max(min(t0, t1), 0.0), tb = min(max(t0, t1), 1.0);\n"
    "  if (ta >= tb) return false;\n"
    "  float dd = df - DL;\n"
    "  float a = (HL - HB) + HB * pk * TILT * DL / LB;\n"
    "  float b = (hf - HL) + HB * pk * TILT * dd / LB;\n"
    "  if (b >= 0.0) return false;\n"           /* the ray never dips under the key top */
    "  ta = max(ta, -a / b);\n"
    "  ta = max(ta, -DL / dd);\n"               /* over the key's near end (d ≥ 0) */
    "  tb = min(tb, (LB - DL) / dd);\n"         /* past the key's far end: over it */
    "  return ta < tb;\n"
    "}\n"
    "void main() {\n"
#if REWAMP_GL_Y_FLIPPED
    "  float py = gl_FragCoord.y;\n"
#else
    "  float py = uView.y - gl_FragCoord.y;\n"
#endif
    "  float xf = (gl_FragCoord.x - uKey.y) / uKey.x;\n"
    "  float df = (py - (uBase - uKey.z)) / uKey.z;\n"   /* 0 felt line .. 1 key bottom */
    "  float A  = uKey.z / uKey.x;\n"                  /* key length in width units */
    /* surface under the fragment: a black key's (tilted) top, or a white
       key's (sinking) face — each at its own press amount */
    "  float oct = floor(xf / 7.0); float u = xf - oct * 7.0;\n"
    "  int octI = int(oct); int wslot = int(floor(u));\n"
    "  float hf = -pressOf(octI * 12 + WN[clamp(wslot, 0, 6)]) * SINKW * max(df, 0.0);\n"
    /* The key under the fragment, as an INTEGER id (octave*5 + slot). It used
       to be its left edge as a float, compared with `==` against the same
       expression evaluated in the occluder loop — and under Metal one of the
       two got contracted into an FMA, one ULP apart: the key then shadowed
       ITSELF for one of the two light samples, and every black key came out
       lit on one half only. Never compare floats for identity in a shader. */
    "  int myKey = -1; float myBx = -1.0;\n"
    "  if (df >= 0.0 && df <= LB) {\n"
    "    for (int k = 0; k < 5; k++) {\n"
    "      if (u >= BK[k] && u < BK[k] + BW) {\n"
    "        myKey = octI * 5 + k; myBx = oct * 7.0 + BK[k];\n"
    "        hf = HB * (1.0 - pressOf(octI * 12 + BN[k]) * TILT * df / LB);\n"
    "      }\n"
    "    }\n"
    "  }\n"
    "  vec3 add = vec3(0.0); float dark = 0.0;\n"
    "  float sh = 0.0; vec3 shCol = vec3(0.0);\n"
    "  for (int i = 0; i < 32; i++) {\n"
    "    if (i >= uNL) break;\n"
    "    float xl = uLPos[i].x;\n"
    "    float dx = xf - xl;\n"
    "    if (abs(dx) > 3.5) continue;\n"
    "    float dd = (df - DL) * A;\n"
    "    float att = uLPos[i].y / (1.0 + FALL * (dx * dx + dd * dd));\n"
    /* fade the light OUT before the cutoff: a hard |dx| > 3 cut left a
       vertical step of a quarter of the brightness across whichever key
       sat three keys away — read as a band on the black keys */
    "    att *= 1.0 - smoothstep(2.0, 3.5, abs(dx));\n"
    "    if (att < 0.002) continue;\n"
    /* shadow: the black keys between light and fragment, two light samples */
    /* three light samples across the source: a softer penumbra, and no
       0.5 steps in the visibility */
    "    float vis = 0.0;\n"
    "    for (int s = 0; s < 3; s++) {\n"
    "      float xs = xl + (float(s) - 1.0) * 0.22;\n"
    "      float lo = min(xs, xf), hi = max(xs, xf);\n"
    "      bool blk = false;\n"
    "      float o0 = floor(lo / 7.0), o1 = floor(hi / 7.0);\n"
    "      for (float o = o0; o <= o1 && !blk; o += 1.0) {\n"
    "        for (int k = 0; k < 5 && !blk; k++) {\n"
    "          float bx = o * 7.0 + BK[k];\n"
    "          if (bx + BW < lo || bx > hi || int(o) * 5 + k == myKey) continue;\n"
    "          blk = blocked(xs, xf, df, hf, bx, pressOf(int(o) * 12 + BN[k]));\n"
    "        }\n"
    "      }\n"
    "      vis += blk ? 0.0 : (1.0 / 3.0);\n"
    "    }\n"
    /* a black key's top is closer to the light: a touch brighter */
    "    float lift = (hf > 0.0) ? 1.25 : 1.0;\n"
    "    add  += uLCol[i] * att * GAIN * vis * lift;\n"
    "    dark += att * vis;\n"
    "    sh   += att * (1.0 - vis);\n"
    "    shCol += uLCol[i] * att * (1.0 - vis);\n"
    "  }\n"
    /* Two passes over the same quad (see the C side):
         0 — MODULATE (dst × rgb): the ambient dims the resting keyboard;
             a lit surface escapes the dimming; a SHADOWED one is
             multiplied by the colour of the light it is deprived of — on
             a white key that IS the note's colour, darkened. No blend
             mode can multiply per channel and add in one pass, hence two.
         1 — ADD (dst + rgb): the highlight of the light itself. */
    /* uPass 3 = DIAGNOSTIC (env REWAMP_PIANO_LIGHT_DEBUG): what the shader
       believes about the fragment — red = position inside the white-key
       cell, green = on a black key's top, blue = depth along the key. Blend
       off, drawn in place of the keys. */
    "  if (uPass == 3) { fragColor = vec4(fract(xf), myBx >= 0.0 ? 1.0 : 0.0, clamp(df, 0.0, 1.0), 1.0); return; }\n"
    "  if (uPass == 0) {\n"
    "    float base = (1.0 - AMBIENT) + min(dark, 1.0) * AMBIENT;\n"
    "    vec3 tint = (sh > 1e-4) ? shCol / sh : vec3(1.0);\n"
    "    float k = clamp(sh * SHADOW, 0.0, 1.0);\n"
    "    vec3 m = vec3(base) * mix(vec3(1.0), tint, k);\n"
    "    fragColor = vec4(m, 1.0);\n"
    "  } else {\n"
    "    fragColor = vec4(add, 0.0);\n"
    "  }\n"
    "}\n";
