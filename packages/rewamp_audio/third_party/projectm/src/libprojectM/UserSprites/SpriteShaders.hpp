#pragma once

#include <string>

static std::string kMilkdropSpriteFragmentGlsl330 = R"(
precision mediump float;

in vec4 fragment_color;
in vec2 fragment_texture;

uniform sampler2D texture_sampler;

uniform int blend_mode;

// 1.0 = fully drawn, 0.0 = not drawn at all. A sprite belongs to a preset, so it has to
// cross-fade with it: without this the outgoing preset's sprite vanished on the first
// frame of the transition and the incoming one appeared at full strength, which is the one
// hard edge in an otherwise smooth blend. Applied toward each mode's IDENTITY, since a
// mode that multiplies or takes a minimum does not fade to black but to white.
uniform float sprite_fade;

out vec4 color;

void main() {
    // Comments contain the original code equivalents used in Milkdrop and a short explanation
    // on what each mode does.
    switch (blend_mode)
    {
        case 0:
        // lpDevice->SetTextureStageState(0, D3DTSS_COLOROP, D3DTOP_MODULATE);
        // lpDevice->SetTextureStageState(0, D3DTSS_COLORARG1, D3DTA_DIFFUSE);
        // lpDevice->SetTextureStageState(0, D3DTSS_COLORARG2, D3DTA_TEXTURE);
        // lpDevice->SetTextureStageState(0, D3DTSS_ALPHAOP, D3DTOP_SELECTARG1);
        // lpDevice->SetTextureStageState(0, D3DTSS_ALPHAARG1, D3DTA_DIFFUSE);
        // for (k=0; k<4; k++) v3[k].Diffuse = D3DCOLOR_RGBA_01(r,g,b,a);

        // Vertex diffuse color is modulated/multiplied with texture diffuse color.
        // Texture stage state in D3D is equivalent to only use vertex diffuse alpha and ignoring texture alpha
        color = vec4(fragment_color.rgb * texture(texture_sampler, fragment_texture.st).rgb, fragment_color.a);
        break;

        case 1:
        // for (k=0; k<4; k++) v3[k].Diffuse = D3DCOLOR_RGBA_01(r*a,g*a,b*a,1);

        // Vertex and texture diffuse colors are multiplied/modulated and then scaled by vertex alpha.
        // Texture alpha is ignored (full opacity).
        color = vec4((fragment_color.rgb * texture(texture_sampler, fragment_texture.st).rgb) * fragment_color.a, 1.0);
        break;

        case 2:
        // for (k=0; k<4; k++) v3[k].Diffuse = D3DCOLOR_RGBA_01(r*a,g*a,b*a,1);

        // Vertex and texture diffuse colors are multiplied/modulated and then scaled by vertex alpha.
        // Texture alpha is ignored (full opacity).
        color = vec4((fragment_color.rgb * texture(texture_sampler, fragment_texture.st).rgb) * fragment_color.a, 1.0);
        break;

        case 3:
        // for (k=0; k<4; k++) v3[k].Diffuse = D3DCOLOR_RGBA_01(1,1,1,1);

        // Vertex color is ignored, only use texture diffuse color.
        // Vertex and texture alpha is also ignored in this mode.
        color = vec4(texture(texture_sampler, fragment_texture.st).rgb, 1.0);
        break;

        case 4:
        // lpDevice->SetTextureStageState(0, D3DTSS_COLOROP, D3DTOP_MODULATE);
        // lpDevice->SetTextureStageState(0, D3DTSS_COLORARG1, D3DTA_DIFFUSE);
        // lpDevice->SetTextureStageState(0, D3DTSS_COLORARG2, D3DTA_TEXTURE);
        // lpDevice->SetTextureStageState(0, D3DTSS_ALPHAOP, D3DTOP_MODULATE);
        // lpDevice->SetTextureStageState(0, D3DTSS_ALPHAARG1, D3DTA_DIFFUSE);
        // lpDevice->SetTextureStageState(0, D3DTSS_ALPHAARG2, D3DTA_TEXTURE);
        // for (k=0; k<4; k++) v3[k].Diffuse = D3DCOLOR_RGBA_01(r,g,b,a);

        // Vertex diffuse color is modulated/multiplied with texture diffuse color.
        // Texture stage state in D3D is equivalent to multiply (AKA modulate) vertex diffuse alpha with texture alpha.
        color = fragment_color * texture(texture_sampler, fragment_texture.st);
        break;

        case 5:
        // MilkDrop 3 "Multiplicative". GL multiplies by the destination
        // (DST_COLOR/ZERO), so the source must be WHITE wherever the sprite is
        // transparent - white is the identity of a multiply, black would punch a
        // hole through the frame.
        {
            vec4 t = texture(texture_sampler, fragment_texture.st);
            float cover = t.a * fragment_color.a;
            color = vec4(mix(vec3(1.0), t.rgb * fragment_color.rgb, cover), 1.0);
        }
        break;

        case 6:
        // MilkDrop 3 "Subtractive". Drawn with FUNC_REVERSE_SUBTRACT and
        // ONE/ONE, so the source is what gets removed: it must be BLACK where
        // the sprite is transparent, and scaled by coverage elsewhere.
        {
            vec4 t = texture(texture_sampler, fragment_texture.st);
            float cover = t.a * fragment_color.a;
            color = vec4(t.rgb * fragment_color.rgb * cover, 1.0);
        }
        break;

        case 7:
        // MilkDrop 3 "Invert" - the name comes straight from its Sprites >
        // Blendmode menu, and the behaviour was measured before that menu was
        // known: sampling two tubes of the source PNG against the same tubes in
        // a MilkDrop 3 capture, blue (0,102,192) renders as (255,143,68) where
        // the inverse is (255,153,63), and pink (217,140,170) renders as
        // (51,131,88) where the inverse is (38,115,85). Alpha behaves as in mode
        // 4, which is what keeps the sprite's cut-out shape.
        {
            vec4 t = texture(texture_sampler, fragment_texture.st);
            color = vec4(1.0 - t.rgb, fragment_color.a * t.a);
        }
        break;

        case 8:
        // MilkDrop 3 "Cut-off": a hard alpha test rather than a gradient, so the
        // sprite is punched out with a crisp edge instead of a soft one.
        {
            vec4 t = texture(texture_sampler, fragment_texture.st);
            if (t.a * fragment_color.a < 0.5) discard;
            color = vec4(t.rgb * fragment_color.rgb, 1.0);
        }
        break;

        case 9:
        // MilkDrop 3 "Darken": drawn with the MIN blend equation, so the source
        // must be WHITE where the sprite is transparent - white is the identity
        // of a minimum, black would flatten the frame to black.
        {
            vec4 t = texture(texture_sampler, fragment_texture.st);
            float cover = t.a * fragment_color.a;
            color = vec4(mix(vec3(1.0), t.rgb * fragment_color.rgb, cover), 1.0);
        }
        break;

        case 10:
        // MilkDrop 3 "Vivid". NOT verified against MilkDrop 3 - the photoshop
        // blend of that name needs to READ the destination, which fixed-function
        // blending cannot do. Approximated as an alpha-blended source with its
        // contrast pushed, which at least keeps the sprite visible and its shape
        // correct. Measure it before trusting it; one preset of the corpus uses
        // this mode.
        {
            vec4 t = texture(texture_sampler, fragment_texture.st);
            vec3 vivid = clamp((t.rgb - 0.5) * 2.0 + 0.5, 0.0, 1.0);
            color = vec4(vivid * fragment_color.rgb, t.a * fragment_color.a);
        }
        break;

        default:
        // Never leave the fragment undefined: an unhandled mode used to fall
        // through the switch without writing `color` at all.
        color = fragment_color * texture(texture_sampler, fragment_texture.st);
        break;
    }

    // Fade toward what each blending mode treats as "draw nothing".
    //  - alpha-blended modes (0, 4, 7, 10, plus 1 and 8, which the C++ side switches to
    //    alpha blending while a fade is in progress): scale the output alpha;
    //  - additive (2), src-colour (3) and subtractive (6): the identity is BLACK, so scale
    //    the colour down;
    //  - multiplicative (5) and darken (9): the identity is WHITE, so fade toward white.
    if (blend_mode == 5 || blend_mode == 9)
    {
        color.rgb = mix(vec3(1.0), color.rgb, sprite_fade);
    }
    else if (blend_mode == 2 || blend_mode == 3 || blend_mode == 6)
    {
        color.rgb *= sprite_fade;
    }
    else
    {
        color.a *= sprite_fade;
    }
}
)";

static std::string kMilkdropSpriteVertexGlsl330 = R"(
precision mediump float;

layout(location = 0) in vec2 vertex_position;
layout(location = 1) in vec4 vertex_color;
layout(location = 2) in vec2 vertex_texture;

out vec4 fragment_color;
out vec2 fragment_texture;

void main(){
    gl_Position = vec4(vertex_position, 0.0, 1.0);
    fragment_color = vertex_color;
    fragment_texture = vertex_texture;
}
)";


