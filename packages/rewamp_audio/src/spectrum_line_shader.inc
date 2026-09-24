/* Constantes et SHADER de la palette « Ligne » du visualiseur SPECTRE.
 *
 * Extrait de rewamp_spectrum_render.cpp pour qu'un ORACLE puisse rendre
 * EXACTEMENT le même shader hors de l'app (scripts/verify_spectrum_line.c).
 * ⚠️ C'est la seule façon d'être sûr que ce qu'on mesure est ce qui s'exécute:
 * une copie du shader dans le harnais aurait dérivé au premier réglage — le
 * projet a déjà payé cette règle côté projectM (« les deux chemins doivent
 * émettre la MÊME source »).
 *
 * Inclus par le renderer ET par le harnais; aucune dépendance, que du texte.
 */
#ifndef REWAMP_SPECTRUM_LINE_SHADER_INC
#define REWAMP_SPECTRUM_LINE_SHADER_INC

/* Sommet: le triangle plein écran qui porte vUv (le renderer partage celui du
 * faisceau, dont c'est le texte mot pour mot). */
static const char* k_sp_line_vert =
    "in vec2 aPos;\n"
    "out vec2 vUv;\n"
    "void main() { gl_Position = vec4(aPos, 0.0, 1.0); vUv = aPos * 0.5 + 0.5; }\n";

#define SP_OSC              32     /* oscillators summed per pixel. Original 64.
                                    * Cost is linear in this: it is the loop the
                                    * fragment shader runs for every pixel.     */
#define SP_LINE_XSCALE      800.0  /* horizontal stretch, READ AT A 1000-PIXEL
                                    * PANEL: the shader gets this scaled by the
                                    * real width, so a wave keeps the same size
                                    * IN PIXELS whatever the panel is. LOWER =
                                    * wider, lazier waves. The original's 1000 is
                                    * a fixed number of cycles per screen, which
                                    * is why it read as a tight scribble on a viz
                                    * panel and fine on a Shadertoy canvas.     */
#define SP_LINE_AMPLITUDE   4.5     /* vertical swing, as a fraction of the panel's
                                    * HALF-height (so it no longer changes when
                                    * the window's aspect does). Original 4.    */
/* Ces deux-là sont lus par le CPU depuis que la phase est réduite avant
 * l'envoi (le shader ne reçoit plus d'horloge): ils restent écrits en littéral
 * GLSL par cohérence avec leurs voisins, mais ce sont des doubles ici. */
#define SP_LINE_SCROLL      0.5    /* how fast the whole wave slides left, in
                                    * screen widths per second.                 */
#define SP_LINE_PHASE_SPEED 300.0  /* per-band phase speed (each band gets this
                                    * times its own hash). Higher = busier.     */
#define SP_LINE_WIDTH       1.6    /* core thickness, in pixels.                */
#ifndef SP_LINE_MIN_PERIOD
#define SP_LINE_MIN_PERIOD  8.0f   /* période la plus COURTE qu'une bande a le
                                    * droit d'avoir, EN PIXELS. En dessous il
                                    * n'y a plus de courbe à échantillonner:
                                    * deux colonnes voisines tombent sur des
                                    * phases opposées et la ligne se déchire.
                                    * ⚠️ Indépendant du panneau: la phase par
                                    * pixel vaut f·XSCALE·2/1000, le W de
                                    * uXScale s'annulant — la bande la plus
                                    * haute a une période de 3,9 px SUR TOUT
                                    * ÉCRAN. C'est la cause des petites
                                    * discontinuités qui restaient après le
                                    * budget de pente: celui-ci mesure une
                                    * PENTE, et une bande de faible amplitude
                                    * mais de haute fréquence passait son
                                    * contrôle tout en restant sous-échantillonnée.
                                    * Fondu doux de MIN_PERIOD à 2×MIN_PERIOD. */
#endif
#ifndef SP_LINE_MAX_SLOPE
#define SP_LINE_MAX_SLOPE   96.0   /* how steep a segment may get before the
                                    * line breaks up. The shader widens its
                                    * tolerance with the slope; past this cap a
                                    * near-vertical stretch shades too few
                                    * pixels and the curve comes out DASHED.
                                    * Original 8, on a canvas whose wave never
                                    * got that steep.                           */
#endif
#define SP_LINE_GLOW        0.    /* halo strength around the core, 0 = none.  */
#define SP_LINE_GLOW_SPREAD 32.0   /* how far that halo reaches.                */
/* CPU side: how a band's level becomes an oscillator's amplitude. */
#define SP_LINE_HF_APPEAR   0.6    /* original's HIGH_FREQ_APPERANCE: the level
                                    * is raised to (2 - this), so LOWER darkens
                                    * quiet bands and calms the whole line.     */
#define SP_LINE_GATE_LO     0.05f  /* below this a band contributes nothing.    */
#define SP_LINE_GATE_HI     0.65f  /* at this it contributes fully. The original
                                    * gates 0.2..1.0 on an audio-texture
                                    * magnitude; ours is a dB mapping with a
                                    * -60 dB floor, where an audible band sits
                                    * around 0.3-0.5 — gated that high, almost
                                    * nothing survived and the line stayed flat.*/
#define SP_LINE_HF_ROLLOFF  0.75f  /* the top band keeps (1 - this) of its
                                    * weight. High bands drive the FAST sines
                                    * (the law is (i/N)²), so without this a
                                    * bright top end shreds the wave.           */

#define SP_STR2(x) #x
#define SP_STR(x)  SP_STR2(x)

static const char* k_sp_line_frag =
    /* highp OBLIGATOIRE, et c'est un bug Android à lui tout seul: le préambule
     * GLES déclare `precision mediump float`, or mediump est un demi-flottant
     * (11 bits de mantisse) sur Adreno et Mali. L'argument du sinus monte à
     * ±uXScale (1920 sur un écran de 2400 px): à cette magnitude le pas de
     * quantification d'un half est de 2 RADIANS, donc des pixels voisins
     * tombent sur la même valeur puis sautent — la courbe sort en marches
     * horizontales reliées par des traits verticaux, pile ce qu'on voyait.
     * Apple ne le montrait pas: ANGLE/Metal promeut mediump, et le chemin
     * desktop est en `#version 150` où tout est déjà du float32. */
    "precision highp float;\n"
    "uniform float uPx;\n"        /* 1 / min(W,H) */
    "uniform float uResY;\n"
    "uniform float uXScale;\n"
    "uniform vec3  uCol;\n"
    "uniform float uAmp[" SP_STR(SP_OSC) "];\n"
    /* Phase de la bande, DÉJÀ réduite modulo 2π côté CPU (défilement et temps
     * compris). Le shader recevait `uTime` et refaisait `f*(x + uTime*300*ph)`:
     * ce terme croît sans borne, donc après quelques minutes il mangeait toute
     * la précision disponible — en mediump immédiatement, en highp à la longue.
     * Une phase réduite est stable indéfiniment et coûte une multiplication de
     * moins par itération. */
    "uniform float uPh["  SP_STR(SP_OSC) "];\n"
    "in vec2 vUv;\n"
    "out vec4 fragColor;\n"
    "float osc(float x) {\n"
    "    float s = 0.0;\n"
    "    for (int i = 0; i < " SP_STR(SP_OSC) "; i++) {\n"
    "        float f = (float(i) + 1.0) / " SP_STR(SP_OSC) ".0;\n"
    "        f *= f;\n"
    "        s += uAmp[i] * sin(f * x + uPh[i]);\n"
    "    }\n"
    "    return s / " SP_STR(SP_OSC) ".0;\n"
    "}\n"
    "void main() {\n"
    /* NO aspect division here, unlike the original: it normalised both axes by
     * the WIDTH, so on a wide panel the same wave value covered proportionally
     * more height — going full screen amplified the curve vertically, made it
     * steeper in pixels than the slope cap allowed, and broke it into dashes.
     * With uv.y left in [-1,1], AMPLITUDE is a fraction of the half-height and
     * means the same thing at any aspect. */
    "    vec2 uv = vUv * 2.0 - 1.0;\n"
    "    float o = osc(uv.x * uXScale) * " SP_STR(SP_LINE_AMPLITUDE) ";\n"
    /* Slope in pixels per pixel — against the HEIGHT now, since that is what
     * uv.y maps onto. */
    "    float tg = clamp(fwidth(o) * uResY * 0.5, 0.0, "
                       SP_STR(SP_LINE_MAX_SLOPE) ");\n"
    "    float d  = abs(uv.y - o) / sqrt(tg * tg + 2.0);\n"
    "    float line = smoothstep(0.0, 0.5, 1.0 - smoothstep(0.0, uPx * "
                       SP_STR(SP_LINE_WIDTH) ", d));\n"
    "    float blur = (1.0 - smoothstep(0.0, uPx * " SP_STR(SP_LINE_WIDTH) " * "
                       SP_STR(SP_LINE_GLOW_SPREAD) ", d * 4.0)) * "
                       SP_STR(SP_LINE_GLOW) ";\n"
    "    float a = clamp(line + blur, 0.0, 1.0);\n"
    "    fragColor = vec4(uCol * a, a);\n"
    "}\n";


#endif  /* REWAMP_SPECTRUM_LINE_SHADER_INC */
