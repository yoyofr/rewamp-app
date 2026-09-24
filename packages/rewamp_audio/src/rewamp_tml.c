/* L'UNIQUE implémentation de tml.h (TinyMidiLoader) du binaire.
 *
 * Deux greffons lisent des fichiers MIDI — FluidLite (SoundFont) et mt32emu
 * (Roland MT-32) — et chacun est désactivable (REWAMP_WITH_MIDI / _MT32). Un
 * en-tête « single-file » ne s'implémente qu'UNE fois par binaire, donc
 * l'implémentation vit ici, compilée dès que l'un des deux est présent, et
 * les greffons n'incluent tml.h qu'en déclaration. */
#define TML_IMPLEMENTATION
#include "tml.h"
