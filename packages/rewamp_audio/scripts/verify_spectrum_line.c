/* Oracle du visualiseur SPECTRE, palette « Ligne »: rend LE VRAI shader hors
 * de l'app, dans un contexte ANGLE, et compte les trous.
 *
 * Pourquoi un rendu GPU et pas un modèle: un modèle Python de la formule
 * annonçait ZÉRO trou là où la capture d'écran en montrait 89 — donc le modèle
 * était faux quelque part (dérivée d'écran, profil d'alpha, arrondi). Un oracle
 * qui exécute le shader ne peut pas se tromper sur ce point.
 *
 * Mesure: pour chaque colonne, l'étendue verticale des pixels dont l'alpha
 * dépasse un seuil, puis le nombre de colonnes VOISINES dont les traits ne se
 * touchent pas — la définition exacte de « la ligne a des trous ».
 */
#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Le shader et ses constantes, tels quels. */
#include "../src/spectrum_line_shader.inc"

static GLuint compile(GLenum type, const char* src) {
    GLuint s = glCreateShader(type);
    const char* srcs[2] = { "#version 300 es\nprecision mediump float;\n", src };
    glShaderSource(s, 2, srcs, NULL);
    glCompileShader(s);
    GLint ok = 0; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) { char log[4096]; glGetShaderInfoLog(s, sizeof log, NULL, log);
               fprintf(stderr, "shader: %s\n", log); exit(1); }
    return s;
}

int main(int argc, char** argv) {
    int W = argc > 1 ? atoi(argv[1]) : 794;
    int H = argc > 2 ? atoi(argv[2]) : 1366;
    float thr = argc > 3 ? (float)atof(argv[3]) : 0.55f;
    /* Niveau audio global. ⚠️ La dimension qui manquait: à fond, la courbe est
     * si pentue que sa bande couvre tout; c'est à niveau MOYEN que le trait est
     * fin, et c'est là qu'il se coupe. Un oracle qui ne teste que le pire cas
     * de PENTE rate le pire cas de CONTINUITÉ. */
    float lvl = argc > 4 ? (float)atof(argv[4]) : 1.0f;
    /* Graine du SPECTRE simulé. 0 = toutes les bandes au même niveau; sinon un
     * tirage par bande — c'est la forme que prend un vrai spectre, et la
     * continuité du trait n'en dépend pas de la même façon que du niveau. */
    unsigned seed = argc > 5 ? (unsigned)strtoul(argv[5], NULL, 10) : 0u;

    EGLDisplay dpy = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    eglInitialize(dpy, NULL, NULL);
    const EGLint cfgAttr[] = { EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
                               EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
                               EGL_RED_SIZE, 8, EGL_ALPHA_SIZE, 8, EGL_NONE };
    EGLConfig cfg; EGLint n = 0;
    eglChooseConfig(dpy, cfgAttr, &cfg, 1, &n);
    const EGLint pbAttr[] = { EGL_WIDTH, 16, EGL_HEIGHT, 16, EGL_NONE };
    EGLSurface surf = eglCreatePbufferSurface(dpy, cfg, pbAttr);
    const EGLint ctxAttr[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    EGLContext ctx = eglCreateContext(dpy, cfg, EGL_NO_CONTEXT, ctxAttr);
    if (!eglMakeCurrent(dpy, surf, surf, ctx)) { fprintf(stderr, "EGL\n"); return 1; }

    GLuint fbo, tex;
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, W, H, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0);

    GLuint prog = glCreateProgram();
    glAttachShader(prog, compile(GL_VERTEX_SHADER, k_sp_line_vert));
    glAttachShader(prog, compile(GL_FRAGMENT_SHADER, k_sp_line_frag));
    glLinkProgram(prog);
    glUseProgram(prog);

    GLuint vao, vbo;
    const float quad[] = { -1,-1, 3,-1, -1,3 };
    glGenVertexArrays(1, &vao); glBindVertexArray(vao);
    glGenBuffers(1, &vbo); glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof quad, quad, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, 0);

    /* Mêmes amplitudes que l'app au pire cas (toutes bandes à fond), passées
     * par le budget de pente ET la limite de Nyquist — la fonction est recopiée
     * du renderer pour que l'oracle mesure ce que l'app envoie. */
    float amp[SP_OSC], ph[SP_OSC];
    const float slopeK = (float)SP_LINE_AMPLITUDE / (float)SP_OSC * 0.5f
                       * ((float)SP_LINE_XSCALE * 2.0f / 1000.0f) * (float)H;
    for (int i = 0; i < SP_OSC; i++) {
        const float f  = ((float)(i+1)/SP_OSC) * ((float)(i+1)/SP_OSC);
        const float sl = slopeK * f;
        const float w  = 1.0f / sqrtf(1.0f + (sl/(float)SP_LINE_MAX_SLOPE)
                                          * (sl/(float)SP_LINE_MAX_SLOPE));
        const float per = 6.28318530718f
                        / (f * (float)SP_LINE_XSCALE * 2.0f / 1000.0f);
        float nn = (per - SP_LINE_MIN_PERIOD) / SP_LINE_MIN_PERIOD;
        nn = nn < 0.f ? 0.f : (nn > 1.f ? 1.f : nn);
        nn = nn*nn*(3.f-2.f*nn);
        float band = 1.0f;
        if (seed) {
            unsigned h = (seed * 2246822519u) ^ ((unsigned)i * 3266489917u);
            h ^= h >> 15; h *= 2654435761u; h ^= h >> 13;
            band = (float)(h % 1000u) / 1000.0f;
            band *= band;              /* un spectre réel est très inégal */
        }
        amp[i] = lvl * band
               * (1.0f - (float)SP_LINE_HF_ROLLOFF * (float)i/(SP_OSC-1)) * w * nn;
        ph[i]  = 6.2831853f * (float)((i*2654435761u) % 1000) / 1000.0f;
    }
    glUniform1f(glGetUniformLocation(prog, "uPx"),     2.0f/(float)H);
    glUniform1f(glGetUniformLocation(prog, "uResY"),   (float)H);
    glUniform1f(glGetUniformLocation(prog, "uXScale"), (float)SP_LINE_XSCALE*(float)W/1000.0f);
    glUniform3f(glGetUniformLocation(prog, "uCol"),    1.f, 1.f, 1.f);
    glUniform1fv(glGetUniformLocation(prog, "uAmp"), SP_OSC, amp);
    glUniform1fv(glGetUniformLocation(prog, "uPh"),  SP_OSC, ph);

    glViewport(0, 0, W, H);
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    glDrawArrays(GL_TRIANGLES, 0, 3);

    unsigned char* buf = (unsigned char*)malloc((size_t)W*H*4);
    glReadPixels(0, 0, W, H, GL_RGBA, GL_UNSIGNED_BYTE, buf);

    int empty = 0, disjoint = 0, prevLo = -1, prevHi = -1;
    long thickSum = 0, thickN = 0;
    const unsigned char t8 = (unsigned char)(thr * 255.0f);
    for (int x = 0; x < W; x++) {
        int lo = -1, hi = -1;
        for (int y = 0; y < H; y++) {
            if (buf[((size_t)y*W + x)*4 + 3] >= t8) { if (lo < 0) lo = y; hi = y; }
        }
        if (lo < 0) { empty++; prevLo = prevHi = -1; continue; }
        thickSum += hi - lo + 1; thickN++;
        if (prevLo >= 0) {
            int a = prevLo > lo ? prevLo : lo;
            int b = prevHi < hi ? prevHi : hi;
            if (a - b > 1) disjoint++;
        }
        prevLo = lo; prevHi = hi;
    }
    printf("%dx%d niveau %.2f seuil %.2f → colonnes VIDES %d | paires DISJOINTES %d | épaisseur moyenne %.1f px\n",
           W, H, lvl, thr, empty, disjoint, thickN ? (double)thickSum/thickN : 0.0);
    free(buf);
    return (empty || disjoint) ? 1 : 0;
}
