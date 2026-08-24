#pragma once
// Shared with scripts/projectm/pm_render_probe.cpp so the adapter that runs in
// the app is the one the oracle checks — a second copy would drift.
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

// MilkDrop 3 embedded sprites: the [SPRITEn_BEGIN]…[SPRITEn_END] blocks a .milk
// can carry, turned into the imgNN sections libprojectM's UserSprites subsystem
// already knows how to run.
//
// The engine side needs nothing: UserSprites/MilkdropSprite.cpp is compiled into
// every build (projectm_sources.txt), ProjectM::RenderFrame already draws the
// sprites each frame, burn-in included, and the C API exposes create/destroy.
// What was missing is that NOBODY PARSED THE BLOCKS and nobody called it.
//
// Two formats meet here, and the translation is the whole job (Milkwave does the
// same in CPlugin::LaunchMilk2Sprites, plugin.cpp:1740 — BSD-3):
//
//   MilkDrop 3 header       what MilkdropSprite wants
//   ─────────────────       ─────────────────────────
//   SpriteName=a\b.png      img=b            (no directory, no extension: the
//                                             TextureManager indexes on the stem)
//   SpriteX/Y               x=/y=, +0.5       (MD3 counts 0,0 = CENTRE)
//   SpriteAlpha/Burn/Repeat a=/burn=/repeatx=
//   SpriteBlend (0..10)     blendmode= (0..10), passed through
//   SpriteLayer             layer=   (0 = on top, 1 = into the preset image)
//   SpriteSX/SY             NOT sx=/sy= — see below
//   SpriteRot               a DIRECTION (+1/-1), not an angle
//   SpriteSpeed             radians per second
//   code_N                  per-frame code, framed by the two above
//
// SpriteLayer is the one field Milkwave gets wrong: it parses it, never reads
// it, and documents it backwards ("0 = behind composite, 1 = on top"). MilkDrop
// 3 is not open source, so the only oracle is its OUTPUT: rendered side by side
// on two presets differing in nothing else, layer 0 draws on top of the finished
// frame and layer 1 goes into the preset's image, to be warped and composited
// like any other content. Without it, a layer-1 decal sprite lands as an opaque
// rectangle over the middle of the screen. SpriteColorKey is applied by Milkwave at LOAD time (D3DX's ColorKey
// builds an alpha channel, texmgr.cpp:104) while libprojectM drops it — which is
// only visible on the images that have no alpha of their own.

struct RewampSpriteBlock {
    std::string img;          // stem only
    long        colorKey = -1; // 0xRRGGBB, -1 = none
    int         blend    = 0;
    int         layer    = 0;  // 0 = on top, >= 1 = into the preset's image
    double      alpha    = 1.0;
    bool        burn     = true;
    double      x        = 0.0, y = 0.0;
    double      sx       = 1.0, sy = 1.0;
    double      rotDir   = 0.0;
    double      speed    = 0.0;
    double      repeatX  = 1.0, repeatY = 1.0;
    std::string initCode;     // user init_N lines, already newline-joined
    std::string code;         // user code_N lines, idem
};

static std::string _spr_trim(const std::string& s) {
    size_t a = 0, b = s.size();
    while (a < b && (s[a] == ' ' || s[a] == '\t')) a++;
    while (b > a && (s[b - 1] == ' ' || s[b - 1] == '\t' ||
                     s[b - 1] == '\r' || s[b - 1] == '\n')) b--;
    return s.substr(a, b - a);
}

// "sprites\cube12.png" → "cube12". Both separators, because a .milk written on
// Windows uses backslashes and the same field can point into textures\ too.
static std::string _spr_stem(const std::string& name) {
    size_t slash = name.find_last_of("/\\");
    std::string base = (slash == std::string::npos) ? name : name.substr(slash + 1);
    size_t dot = base.find_last_of('.');
    return (dot == std::string::npos) ? base : base.substr(0, dot);
}

// MilkDrop 3's blend modes, named by its own Sprites > Blendmode menu:
//   0 Blend  1 Decal  2 Additive  3 Srccolor  4 Colorkey  5 Multiplicative
//   6 Subtractive  7 Invert  8 Cut-off  9 Darken  10 Vivid
// They are passed through untouched - the renderer implements all eleven.
//
// They used to be REMAPPED onto MilkDrop 2's 0..4 using a table Milkwave carries
// in a comment (5->2 additive, 7->4 colorkey, 9->3 srccolor, 10->3). Every line
// of it is wrong: 5 is multiplicative, 7 inverts, 9 darkens, 10 is vivid. The
// table was never anything but a guess, and Milkwave's own renderer cannot even
// reach it - like BeatDrop, it clamps blendmode to 0..4. Mode 10 is the one
// still approximated; see the shader.
static int _spr_map_blend(int md3) {
    return md3 < 0 ? 0 : (md3 > 10 ? 10 : md3);
}


// Reads every sprite block of a .milk. Cannot go through PresetFileParser: two
// blocks both declare SpriteName and code_1, so a flat key→value map would keep
// only the last one.
static std::vector<RewampSpriteBlock> _spr_parse_file(const std::string& path) {
    std::vector<RewampSpriteBlock> blocks;
    FILE* f = fopen(path.c_str(), "rb");
    if (!f) return blocks;

    char line[8192];
    RewampSpriteBlock* cur = nullptr;
    while (fgets(line, sizeof(line), f) != nullptr) {
        std::string s = _spr_trim(line);
        if (s.empty()) continue;

        if (s.size() > 8 && s[0] == '[' && s.compare(1, 6, "SPRITE") == 0) {
            if (s.find("_BEGIN]") != std::string::npos) {
                blocks.emplace_back();
                cur = &blocks.back();
            } else if (s.find("_END]") != std::string::npos) {
                cur = nullptr;
            }
            continue;
        }
        if (cur == nullptr) continue;

        size_t eq = s.find('=');
        if (eq == std::string::npos) continue;
        std::string key = s.substr(0, eq);
        std::string val = s.substr(eq + 1);

        if      (key == "SpriteName")     cur->img     = _spr_stem(val);
        else if (key == "SpriteColorKey") cur->colorKey = strtol(val.c_str(), nullptr, 0);
        else if (key == "SpriteBlend")    cur->blend   = atoi(val.c_str());
        else if (key == "SpriteLayer")    cur->layer   = atoi(val.c_str());
        else if (key == "SpriteAlpha")    cur->alpha   = atof(val.c_str());
        else if (key == "SpriteBurn")     cur->burn    = atoi(val.c_str()) != 0;
        else if (key == "SpriteX")        cur->x       = atof(val.c_str());
        else if (key == "SpriteY")        cur->y       = atof(val.c_str());
        else if (key == "SpriteSX")       cur->sx      = atof(val.c_str());
        else if (key == "SpriteSY")       cur->sy      = atof(val.c_str());
        else if (key == "SpriteRot")      cur->rotDir  = atof(val.c_str());
        else if (key == "SpriteSpeed")    cur->speed   = atof(val.c_str());
        else if (key == "SpriteRepeatX")  cur->repeatX = atof(val.c_str());
        else if (key == "SpriteRepeatY")  cur->repeatY = atof(val.c_str());
        else if (key.compare(0, 5, "init_") == 0) { cur->initCode += val; cur->initCode += '\n'; }
        else if (key.compare(0, 5, "code_") == 0) { cur->code     += val; cur->code     += '\n'; }
    }
    fclose(f);

    // A block with no image is not a sprite.
    blocks.erase(std::remove_if(blocks.begin(), blocks.end(),
                                [](const RewampSpriteBlock& b) { return b.img.empty(); }),
                 blocks.end());
    return blocks;
}

// Builds the imgNN section MilkdropSprite parses (plain key=value text; init_N /
// code_N are concatenated by PresetFileParser::GetCode).
static std::string _spr_build_section(const RewampSpriteBlock& b, int viewW, int viewH) {
    // Kept in the signature although the scale no longer reads them: the size
    // turned out NOT to depend on the viewport (measured at two aspects), and
    // the next field that needs it should not have to change every call site.
    (void)viewW;
    (void)viewH;
    char buf[1024];
    std::string out = "img=" + b.img + "\n";
    // Passed through as a key so MilkdropSprite can load a keyed copy of the
    // image: MilkDrop applies the key at LOAD time, which is what gives a JPEG
    // the alpha that blend mode 4 tests.
    if (b.colorKey >= 0) {
        snprintf(buf, sizeof(buf), "colorkey=%ld\n", b.colorKey);
        out += buf;
    }

    // SpriteSX/SY are NOT initial values: MilkDrop 3 keeps them as persistent
    // multipliers applied AFTER the per-frame code, so a preset writing "sx=…"
    // scales the sprite instead of replacing its size. They are stashed in
    // _bsx/_bsy and re-applied at the end of the per-frame block.
    //
    // The scale is 1 + SpriteSX, not SpriteSX. The quad spans that fraction of
    // the screen width, so 0 means "exactly full screen" and a NEGATIVE
    // SpriteSX shrinks (it does not mirror).
    //
    // Measured against MilkDrop 3 on a preset built for it - one sprite, no
    // warp, no shapes, no shader - by sweeping SpriteSX and reading the period
    // of the image's vertical bars:
    //     SpriteSX   0.03   0.06   0.125   0.5    2.0
    //     mesuré     84     86     91      121    238   px
    //     81.7*(1+x) 84.1   86.6   91.9    122.6  245
    // and it is what finally reconciles "Evet + Geiss - Chrome", whose sprite
    // declares SpriteSX = -0.8: 1 - 0.8 = 0.2, against 0.22 of the screen width
    // measured on two MilkDrop captures. Every earlier attempt (a constant times
    // SpriteSX, with or without the screen aspect) fitted one preset and missed
    // the other, which is what made a per-path fudge look necessary.
    // The 1.2 is the one thing the bar sweep could NOT see - it is absorbed in
    // the fit's constant - so it comes from Chrome, whose knot is measurable:
    // 1.2 * (1 - 0.8) = 0.24 of the screen width, against 0.22 measured.
    const double kSpriteScale = 1.2;
    const double bsx = kSpriteScale * (1.0 + b.sx);
    const double bsy = kSpriteScale * (1.0 + b.sy);

    snprintf(buf, sizeof(buf),
             "init_1=x=%f;\n"
             "init_2=y=%f;\n"
             "init_3=sx=1;\n"
             "init_4=sy=1;\n"
             "init_5=rot=0;\n"
             "init_6=a=%f;\n"
             "init_7=blendmode=%d;\n"
             "init_8=burn=%d;\n"
             "init_9=repeatx=%f;\n"
             "init_10=repeaty=%f;\n"
             "init_11=done=0;\n"
             "init_12=_bsx=%f;\n"
             "init_13=_bsy=%f;\n"
             "init_14=layer=%d;\n",
             b.x + 0.5, b.y + 0.5,          // MD3: 0,0 is the CENTRE
             b.alpha, _spr_map_blend(b.blend), b.burn ? 1 : 0,
             b.repeatX, b.repeatY, bsx, bsy, b.layer);
    out += buf;

    int initLine = 15;
    size_t pos = 0;
    while (pos < b.initCode.size()) {
        size_t nl = b.initCode.find('\n', pos);
        if (nl == std::string::npos) nl = b.initCode.size();
        std::string l = b.initCode.substr(pos, nl - pos);
        pos = nl + 1;
        if (l.empty()) continue;
        snprintf(buf, sizeof(buf), "init_%d=%s\n", initLine++, l.c_str());
        out += buf;
    }

    // Per-frame, in three parts and the order matters: the rotation step first
    // (SpriteRot is the DIRECTION, SpriteSpeed the radians per second), then the
    // preset's own code, then the base-scale multiplication.
    // sx/sy are RESET here, and this is a deliberate divergence from Milkwave.
    // The sprite variables persist across frames (MilkdropSprite::CodeContext::
    // RunPerFrameCode assigns only the inputs; MilkDrop's texmgr behaves the
    // same), so appending "sx=sx*_bsx" to the per-frame COMPOUNDS whenever the
    // preset does not assign sx itself: the sprite shrinks to nothing in a
    // handful of frames. Measured — a sprite with no code_N never appeared.
    // Resetting to 1 first makes the multiplier mean what MilkDrop 3 documents,
    // "a persistent scale applied after the per-frame code", in both cases:
    // without user code sx = _bsx every frame, with "sx=<abs>" it behaves
    // exactly as Milkwave. Only a preset writing a RELATIVE sx (sx=sx*k) would
    // differ, and that is already broken upstream.
    // rot is NOT reset: it accumulates by design.
    int codeLine = 1;
    out += "code_1=sx=1;\n";
    out += "code_2=sy=1;\n";
    codeLine = 3;
    // Milkwave's sign, restored: the sprite spinning the wrong way was a
    // symptom of the Y axis being flipped (see MilkdropSprite), not of this
    // field. Negating it here made the spin look right while leaving the
    // sprite's ORBIT running backwards.
    if (b.rotDir != 0.0 && b.speed != 0.0) {
        snprintf(buf, sizeof(buf), "code_%d=rot=rot+%f/fps;\n",
                 codeLine++, b.speed * b.rotDir);
        out += buf;
    }
    pos = 0;
    while (pos < b.code.size()) {
        size_t nl = b.code.find('\n', pos);
        if (nl == std::string::npos) nl = b.code.size();
        std::string l = b.code.substr(pos, nl - pos);
        pos = nl + 1;
        if (l.empty()) continue;
        snprintf(buf, sizeof(buf), "code_%d=%s\n", codeLine++, l.c_str());
        out += buf;
    }
    snprintf(buf, sizeof(buf),
             "code_%d=sx=sx*_bsx;\n"
             "code_%d=sy=sy*_bsy;\n",
             codeLine, codeLine + 1);
    out += buf;

    return out;
}

