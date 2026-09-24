/* Oracle du shader d'ÉCLAIRAGE du viz piano: rend LE VRAI texte
 * (src/piano_light_shader.inc) dans un contexte ANGLE hors écran, avec une
 * scène connue, et imprime ce que le shader a calculé sur le DESSUS des noires
 * et sur les blanches — là où la capture d'écran montrait une noire éclairée
 * à moitié dans sa largeur, que le modèle Python de la formule ne reproduisait
 * pas. Seul le shader exécuté fait foi (leçon de verify_spectrum_line).
 *
 * Scène: 10 blanches de 70 px (W = 700), touches de 280 px de haut (ratio
 * 1:4), base = H = 400. Une lumière au centre du DO# (note 1), enfoncé à fond.
 * Sortie: pour quelques profondeurs d, la passe MODULATION (canal rouge, ce
 * par quoi la touche est multipliée) le long de x, un caractère par 5 px. */
#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define REWAMP_GL_Y_FLIPPED 0
#define PK_NDC_Y "1.0 - py * 2.0 / uView.y"
#include "../src/piano_light_shader.inc"

static const char* k_vert =
    "in vec2 aPos;\nvoid main() { gl_Position = vec4(aPos, 0.0, 1.0); }\n";

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
    const int W = 700, H = 400;
    const float keyW = 70.0f, keyH = 280.0f;
    int pass = argc > 1 ? atoi(argv[1]) : 0;   /* 2 = composite like the app */

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
    glAttachShader(prog, compile(GL_VERTEX_SHADER, k_vert));
    glAttachShader(prog, compile(GL_FRAGMENT_SHADER, k_lfrag));
    glLinkProgram(prog);
    { GLint ok = 0; glGetProgramiv(prog, GL_LINK_STATUS, &ok);
      if (!ok) { char log[4096]; glGetProgramInfoLog(prog, sizeof log, NULL, log);
                 fprintf(stderr, "link: %s\n", log); return 1; } }
    glUseProgram(prog);

    GLuint vao, vbo;
    const float quad[] = { -1,-1, 3,-1, -1,3 };
    glGenVertexArrays(1, &vao); glBindVertexArray(vao);
    glGenBuffers(1, &vbo); glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof quad, quad, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, 0);

    /* la scène */
    float press[128]; memset(press, 0, sizeof press);
    press[1] = 1.0f;   /* C# down */
    press[4] = 1.0f;   /* E down */
    const float bk0 = 0.6367f, bw = 0.56f;
    float lpos[4] = { bk0 + bw * 0.5f, 1.0f,  2.5f, 1.0f };
    float lcol[6] = { 1.0f, 0.2f, 0.9f,   0.2f, 1.0f, 1.0f };
    if (pass < 2) { lcol[0] = lcol[1] = lcol[2] = 1.0f; }
    glUniform2f(glGetUniformLocation(prog, "uView"), (float)W, (float)H);
    glUniform3f(glGetUniformLocation(prog, "uKey"), keyW, 0.0f, keyH);
    glUniform1f(glGetUniformLocation(prog, "uBase"), (float)H);
    glUniform1i(glGetUniformLocation(prog, "uNL"), pass < 2 ? 1 : 2);
    glUniform2fv(glGetUniformLocation(prog, "uLPos"), 2, lpos);
    glUniform3fv(glGetUniformLocation(prog, "uLCol"), 2, lcol);
    glUniform4fv(glGetUniformLocation(prog, "uPress"), 32, press);
    glUniform1i(glGetUniformLocation(prog, "uPass"), pass);

    glViewport(0, 0, W, H);
    glDisable(GL_BLEND);
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    if (pass < 2) {
        glDrawArrays(GL_TRIANGLES, 0, 3);
    } else {
        /* Like the app: a keyboard already on screen (whites 220, blacks 40 on
         * their top 60 %), then pass 0 multiplied in, pass 1 added. The view
         * is offset like a real one (lo = 14 white keys) and the lights are
         * coloured, so a tinted shadow shows up as a colour shift. */
        unsigned char* img = malloc((size_t)W * H * 4);
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
            float py = (float)(H - 1 - y);           /* y down */
            float xk = (float)x / keyW;
            float d  = (py - ((float)H - keyH)) / keyH;
            unsigned char v = 0;
            if (d >= 0.0f) {
                v = 220;
                float u = fmodf(xk, 7.0f);
                const float bk[5] = {0.6367f, 1.8033f, 3.6367f, 4.72f, 5.8033f};
                for (int k = 0; k < 5; k++) if (u >= bk[k] && u < bk[k] + bw && d <= 0.6f) v = 40;
            } else v = 30;
            unsigned char* q = &img[(y * W + x) * 4]; q[0] = q[1] = q[2] = v; q[3] = 255;
        }
        glBindTexture(GL_TEXTURE_2D, tex);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, W, H, GL_RGBA, GL_UNSIGNED_BYTE, img);
        free(img);
        glEnable(GL_BLEND);
        glBlendFunc(GL_ZERO, GL_SRC_COLOR);
        glUniform1i(glGetUniformLocation(prog, "uPass"), 0);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        glBlendFunc(GL_ONE, GL_ONE);
        glUniform1i(glGetUniformLocation(prog, "uPass"), 1);
        glDrawArrays(GL_TRIANGLES, 0, 3);
    }

    unsigned char* px = malloc((size_t)W * H * 4);
    glReadPixels(0, 0, W, H, GL_RGBA, GL_UNSIGNED_BYTE, px);

    printf("pass %d — un caractère = 5 px, x de 0 à 3 touches; '|' = bord de noire\n", pass);
    printf("noires: C# [%.2f,%.2f]  D# [%.2f,%.2f]\n", bk0, bk0 + bw, 1.8033f, 1.8033f + bw);
    const float depths[] = { -0.05f, 0.1f, 0.3f, 0.5f, 0.7f, 0.9f };
    static const char ramp[] = " .:-=+*#%@";
    for (int di = 0; di < 6; di++) {
        float d = depths[di];
        float py = (float)H - keyH + d * keyH;          /* y down */
        int row = H - 1 - (int)py;                       /* readback is bottom-up */
        if (row < 0 || row >= H) continue;
        printf("d=%5.2f ", d);
        for (int x = 0; x < 3 * (int)keyW; x += 5) {
            float xk = (x + 2.5f) / keyW;
            int onB = (xk >= bk0 && xk < bk0 + bw) || (xk >= 1.8033f && xk < 1.8033f + bw);
            unsigned char* q = &px[(row * W + x) * 4];
            if (pass == 2) {
                /* composite: dominant channel letter + level */
                int lvl = (q[0] + q[1] + q[2]) / 3 * 9 / 255;
                char c = (q[0] > q[2] + 30) ? 'R' : (q[2] > q[0] + 30) ? 'C' : 'n';
                if (onB) putchar("0123456789"[lvl]); else putchar(c == 'n' ? ramp[lvl] : (lvl > 4 ? c : c + 32));
            } else {
                int lvl = q[0] * 9 / 255;
                putchar(onB ? "0123456789"[lvl] : ramp[lvl]);
            }
        }
        putchar('\n');
    }
    printf("(chiffres = sur une noire, symboles = sur une blanche; plus haut = plus clair)\n");
    return 0;
}
