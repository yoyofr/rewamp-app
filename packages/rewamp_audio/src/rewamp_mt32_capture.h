/* Accroches de capture PAR PARTIE pour mt32emu (oscilloscope du viz-voices).
 *
 * mt32emu mélange ses 32 partiels dans des tampons COMMUNS (non-reverb /
 * reverb-dry): la contribution d'une partie n'est isolée nulle part. Les trois
 * accroches ci-dessous, posées dans le cœur vendoré (grep YOYOFR sous
 * third_party/mt32emu), reconstruisent cette contribution: `run_begin` au
 * début d'une passe de rendu (longueur en échantillons NATIFS 32 kHz),
 * `run_add` depuis Partial::produceAndMixSample pour chaque échantillon de
 * chaque partiel (partie 0-7 mélodiques, 8 = rythme), `run_end` quand la passe
 * est mixée — c'est là que le greffon pousse le tout dans les anneaux.
 *
 * Linkage C: le cœur est du C++ dans le namespace MT32Emu, le greffon les
 * définit dans son propre TU; extern "C" garde le nom stable des deux côtés. */
#ifndef REWAMP_MT32_CAPTURE_H
#define REWAMP_MT32_CAPTURE_H
#ifdef __cplusplus
extern "C" {
#endif
void rewamp_mt32_run_begin(unsigned int nativeLen);
void rewamp_mt32_run_add(unsigned int part, unsigned int sampleNum, float lr);
void rewamp_mt32_run_end(unsigned int nativeLen);
#ifdef __cplusplus
}
#endif
#endif
