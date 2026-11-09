/* Sortie audio du moteur sur le web (Emscripten) — remplace le ma_device.
 *
 * Pourquoi pas le back-end Web Audio de miniaudio: un AudioContext n'existe que
 * sur le fil PRINCIPAL de la page, alors que le moteur vit dans un Worker (il
 * bloque: rewamp_load_file attend le premier bloc audio, les pthreads joignent);
 * et son mode AudioWorklet exige ASYNCIFY, qui gonfle et ralentit un module de
 * 25 Mo. On garde donc TOUT le moteur (producteur, anneau, relais gapless,
 * fondu enchaîné, vitesse) et on ne remplace que le DERNIER maillon:
 *
 *   producteur ─▶ anneau du moteur ─▶ [pompe: rewamp_device_callback]
 *                                        ─▶ anneau de sortie ─▶ AudioWorklet
 *
 * La pompe est un pthread qui joue le rôle du rappel du périphérique: il
 * appelle le MÊME rewamp_device_callback que les autres plateformes, au rythme
 * où l'AudioWorklet consomme. L'anneau de sortie vit dans la mémoire wasm, qui
 * est déjà un SharedArrayBuffer: l'AudioWorklet (JS pur, pas de wasm) le lit en
 * place, sans copie ni message par bloc.
 *
 * Disposition de l'en-tête (Int32, partagé avec le JS — ne pas réordonner):
 *   [0] write    trames écrites, compteur monotone (modulo 2^32)
 *   [1] read     trames lues par l'AudioWorklet, idem
 *   [2] capacity trames (puissance de deux)
 *   [3] channels 2
 *   [4] rate     44100
 *   [5] started  1 = la pompe rend du son, 0 = suspendu (l'AudioWorklet sort du silence)
 *   [6] underruns compteur tenu par l'AudioWorklet (quantum de 128 incomplet)
 *   [7] data     décalage en OCTETS des échantillons float, depuis l'en-tête
 */
#ifndef REWAMP_DEVICE_WEB_H
#define REWAMP_DEVICE_WEB_H

#include "../miniaudio.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Démarre la pompe (une fois); `callback` est rappelé comme un rappel de
 * ma_device, avec pDevice = NULL. Rend MA_SUCCESS ou une erreur. */
ma_result rewamp_web_device_start(ma_device_data_proc callback);
void      rewamp_web_device_stop(void);      /* suspend: plus de rendu */
ma_result rewamp_web_device_resume(void);
int       rewamp_web_device_is_started(void);
void      rewamp_web_device_uninit(void);
int       rewamp_web_device_period_frames(void);
int       rewamp_web_device_capacity_frames(void);

/* Pour la page: adresse de l'en-tête dans la mémoire wasm (0 avant le start). */
int rewamp_web_audio_ring(void);

#ifdef __cplusplus
}
#endif
#endif
