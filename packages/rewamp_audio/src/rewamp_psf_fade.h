/* Fondu de fin de la famille PSF — partagé par les huit greffons.
 *
 * Un fichier PSF (psf/psf2, gsf, 2sf, ncsf, usf, qsf, ssf/dsf, snsf) porte DEUX
 * tags de temps: `length`, la musique, et `fade`, l'extinction qui la suit. Les
 * greffons additionnaient les deux pour savoir OÙ COUPER, mais aucun ne
 * rampait: la piste s'arrêtait NET à la fin de la fenêtre de fondu, ce qui
 * s'entend d'autant plus que le driver, lui, tourne encore.
 *
 * Le fondu est LINÉAIRE en amplitude sur `fade`, la convention des lecteurs
 * PSF (foo_psf, Audio Overload). Il ne s'applique pas dans trois cas:
 *   - boucle forcée, quel que soit le mode: en INFINI il n'y a plus de fin à
 *     atteindre (la troncature est levée), et à N PASSES c'est le chemin
 *     générique Dart qui possède le fondu — un fondu natif à chaque passe
 *     couperait la musique au milieu du morceau;
 *   - crossfade actif: le recouvrement fait déjà la descente, et fondre deux
 *     fois donne un trou. Même décision que libgme, qui repousse alors son
 *     propre fondu (voir rewamp_plugin_gme.cpp).
 *   - durée inconnue: sans fin, pas de fenêtre.
 *
 * ⚠️ Les deux premiers se décident À CHAQUE LECTURE (`rewamp_psf_fade_apply`),
 * pas à l'ouverture. Ils l'étaient à l'ouverture (dans `_fade_frames`), et le
 * bouton repeat se touche EN COURS de morceau: repeat infini armé à 1:00 d'un
 * .dsf, le fondu calculé à l'ouverture continuait de s'appliquer, le morceau
 * s'éteignait avant de reboucler — et à l'inverse, repeat coupé en cours de
 * lecture d'un morceau ouvert sous repeat laissait la fin tomber NET. La
 * fenêtre (`fadeFrames`) reste donc une pure conversion du tag, et c'est la
 * rampe qui regarde l'état du moment; Dart pousse cet état au moteur au geste
 * (`PlayerController._pushForcedLoopSnapshot`), pas seulement à l'ouverture.
 */
#ifndef REWAMP_PSF_FADE_H
#define REWAMP_PSF_FADE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

extern int    g_force_loop_mode;      /* rewamp_audio.c */
extern double g_crossfade_seconds;    /* rewamp_datasource.c */

/* Nombre de frames de la FENÊTRE de fondu en fin de piste, 0 = aucune.
 * [fadeMs] est le tag `fade`, [totalFrames] la troncature (length + fade).
 * Pure conversion: elle ne regarde ni la boucle ni le crossfade — ça, c'est
 * `rewamp_psf_fade_active`, consultée à chaque lecture. */
static inline uint64_t rewamp_psf_fade_frames(int fadeMs, uint32_t sampleRate,
                                              uint64_t totalFrames) {
    if (fadeMs <= 0 || sampleRate == 0 || totalFrames == 0) return 0;
    uint64_t frames = (uint64_t)((double)fadeMs / 1000.0 * (double)sampleRate);
    /* Un tag qui prétend fondre plus longtemps que la piste entière ne peut
     * pas être pris au mot: on fond au plus tout le morceau. */
    return frames > totalFrames ? totalFrames : frames;
}

/* Gain du fondu à la position absolue [pos]: 1 avant la fenêtre, 0 après la
 * fin, rampe linéaire entre les deux. */
static inline double rewamp_psf_fade_gain_at(uint64_t pos, uint64_t totalFrames,
                                             uint64_t fadeFrames) {
    if (fadeFrames == 0 || totalFrames == 0) return 1.0;
    const uint64_t start = totalFrames - fadeFrames;
    if (pos < start) return 1.0;
    if (pos >= totalFrames) return 0.0;
    return 1.0 - (double)(pos - start) / (double)fadeFrames;
}

/* Les OSCILLOSCOPES suivent le son: l'anneau par voix est atténué du même
 * gain, sinon les voies restent à pleine amplitude pendant que la musique
 * s'éteint — un oscilloscope qui ne montre pas ce qu'on entend. Défini dans
 * rewamp_channel_data.c (l'anneau et sa taille y sont statiques); il atténue
 * les [frames] derniers échantillons écrits, en interpolant entre les deux
 * gains. Même hypothèse que rewamp_channel_data_capture_delayed: pour ces
 * cœurs, un échantillon d'oscilloscope vaut une frame audio. */
void rewamp_channel_data_fade_recent(int frames, float gainStart, float gainEnd);

/* Applique le fondu sur [frames] frames INTERLEAVÉES écrites à [out], la
 * première portant l'index absolu [basePos] — et sur les captures de voix.
 * Ne fait rien hors fenêtre. */
/* Le fondu a-t-il lieu d'être EN CE MOMENT ? Lu à chaque bloc: repeat et
 * crossfade se changent en cours de lecture. */
static inline int rewamp_psf_fade_active(void) {
    return g_force_loop_mode == 0 && g_crossfade_seconds <= 0.0;
}

static inline void rewamp_psf_fade_apply(float* out, uint64_t frames,
                                         int channels, uint64_t basePos,
                                         uint64_t totalFrames,
                                         uint64_t fadeFrames) {
    if (!out || fadeFrames == 0 || frames == 0 || channels <= 0) return;
    if (!rewamp_psf_fade_active()) return;
    const uint64_t start = totalFrames - fadeFrames;   /* début du fondu */
    if (basePos + frames <= start) return;             /* encore en pleine musique */
    for (uint64_t i = 0; i < frames; i++) {
        const uint64_t pos = basePos + i;
        if (pos < start) continue;
        const double gain = rewamp_psf_fade_gain_at(pos, totalFrames, fadeFrames);
        float* f = out + i * (uint64_t)channels;
        for (int c = 0; c < channels; c++) f[c] *= (float)gain;
    }
    /* La rampe étant linéaire, les deux bornes suffisent à la décrire. */
    rewamp_channel_data_fade_recent(
        (int)frames,
        (float)rewamp_psf_fade_gain_at(basePos, totalFrames, fadeFrames),
        (float)rewamp_psf_fade_gain_at(basePos + frames - 1, totalFrames,
                                       fadeFrames));
}

#ifdef __cplusplus
}
#endif
#endif /* REWAMP_PSF_FADE_H */
