/* Oracle du fondu PSF: la rampe est-elle linéaire, bornée, et neutre hors
 * fenêtre ? Voir src/rewamp_psf_fade.h. */
#include <stdio.h>
#include <string.h>
#include <math.h>
int    g_force_loop_mode    = 0;
double g_crossfade_seconds  = 0.0;
/* L'anneau des voix n'existe pas dans cet oracle: on note juste ce que le
 * fondu lui demande, pour vérifier que les oscilloscopes suivent le son. */
static int   g_voice_calls = 0;
static float g_voice_g0 = -1, g_voice_g1 = -1;
static int   g_voice_frames = 0;
void rewamp_channel_data_fade_recent(int frames, float g0, float g1) {
    g_voice_calls++; g_voice_frames = frames; g_voice_g0 = g0; g_voice_g1 = g1;
}
#include "rewamp_psf_fade.h"

static int fails = 0;
static void ok(const char* what, int cond) {
    if (!cond) { printf("ÉCHEC: %s\n", what); fails++; }
}
int main(void) {
    const uint32_t rate = 44100;
    const uint64_t total = 10 * rate;              /* 10 s au total */
    uint64_t fade = rewamp_psf_fade_frames(2000, rate, total);  /* 2 s de fondu */
    ok("fondu = 2 s", fade == 2 * rate);

    /* La fenêtre est une pure conversion du tag: repeat et crossfade ne la
     * touchent pas (ils se décident à la LECTURE, voir plus bas). */
    g_force_loop_mode = 2;
    ok("boucle infinie: la fenetre reste calculee",
       rewamp_psf_fade_frames(2000, rate, total) == 2 * rate);
    g_force_loop_mode = 0;
    g_crossfade_seconds = 3.0;
    ok("crossfade: la fenetre reste calculee",
       rewamp_psf_fade_frames(2000, rate, total) == 2 * rate);
    g_crossfade_seconds = 0.0;
    ok("sans tag fade: rien", rewamp_psf_fade_frames(0, rate, total) == 0);
    ok("duree inconnue: rien", rewamp_psf_fade_frames(2000, rate, 0) == 0);
    ok("fade plus long que la piste: borne", 
       rewamp_psf_fade_frames(99000, rate, total) == total);

    /* La rampe. */
    const uint64_t start = total - fade;
    float buf[8 * 2];
    for (int i = 0; i < 16; i++) buf[i] = 1.0f;
    rewamp_psf_fade_apply(buf, 8, 2, 0, total, fade);       /* tout au début */
    ok("hors fenetre: intact", buf[0] == 1.0f && buf[15] == 1.0f);

    for (int i = 0; i < 16; i++) buf[i] = 1.0f;
    rewamp_psf_fade_apply(buf, 8, 2, start, total, fade);   /* pile au debut du fondu */
    ok("premiere frame du fondu = pleine amplitude", fabs(buf[0] - 1.0f) < 1e-6);
    ok("stereo: les deux voies suivent", fabs(buf[0] - buf[1]) < 1e-6);
    ok("ca descend", buf[2] < buf[0] && buf[14] < buf[2]);

    for (int i = 0; i < 16; i++) buf[i] = 1.0f;
    rewamp_psf_fade_apply(buf, 8, 2, start + fade / 2, total, fade);
    ok("mi-fondu ~ 0,5", fabs(buf[0] - 0.5f) < 0.01f);

    for (int i = 0; i < 16; i++) buf[i] = 1.0f;
    rewamp_psf_fade_apply(buf, 8, 2, total - 4, total, fade);
    ok("derniere frame ~ 0", buf[6] < 0.001f);
    ok("au-dela de la fin: silence", buf[8] == 0.0f && buf[15] == 0.0f);

    /* Repeat / crossfade se décident À CHAQUE BLOC, pas à l'ouverture: armer
     * repeat en cours de morceau doit couper le fondu, le désarmer le rendre. */
    for (int i = 0; i < 16; i++) buf[i] = 1.0f;
    g_force_loop_mode = 2;
    rewamp_psf_fade_apply(buf, 8, 2, start + fade / 2, total, fade);
    ok("repeat infini arme en cours: plus de fondu", buf[0] == 1.0f && buf[15] == 1.0f);
    g_force_loop_mode = 1;
    rewamp_psf_fade_apply(buf, 8, 2, start + fade / 2, total, fade);
    ok("N passes en cours: plus de fondu (le generique le fait)", buf[0] == 1.0f);
    g_force_loop_mode = 0;
    g_crossfade_seconds = 3.0;
    rewamp_psf_fade_apply(buf, 8, 2, start + fade / 2, total, fade);
    ok("crossfade en cours: plus de fondu", buf[0] == 1.0f);
    g_crossfade_seconds = 0.0;
    rewamp_psf_fade_apply(buf, 8, 2, start + fade / 2, total, fade);
    ok("repeat coupe en cours: le fondu revient", fabs(buf[0] - 0.5f) < 0.01f);

    /* Mono. */
    float m[4] = {1, 1, 1, 1};
    rewamp_psf_fade_apply(m, 4, 1, start + fade / 2, total, fade);
    ok("mono: rampe aussi", fabs(m[0] - 0.5f) < 0.01f);

    /* Les oscilloscopes reçoivent le MÊME gain que le son. */
    g_voice_calls = 0;
    for (int i = 0; i < 16; i++) buf[i] = 1.0f;
    rewamp_psf_fade_apply(buf, 8, 2, start + fade / 2, total, fade);
    ok("voix: le fondu leur est transmis", g_voice_calls == 1);
    ok("voix: meme fenetre", g_voice_frames == 8);
    ok("voix: gain de depart = celui du son", fabs(g_voice_g0 - buf[0]) < 1e-6);
    ok("voix: gain de fin = celui du son", fabs(g_voice_g1 - buf[14]) < 1e-6);
    g_voice_calls = 0;
    for (int i = 0; i < 16; i++) buf[i] = 1.0f;
    rewamp_psf_fade_apply(buf, 8, 2, 0, total, fade);   /* hors fenetre */
    ok("voix: rien hors fenetre", g_voice_calls == 0);

    printf(fails ? "%d échec(s)\n" : "tout est vert\n", fails);
    return fails ? 1 : 0;
}
