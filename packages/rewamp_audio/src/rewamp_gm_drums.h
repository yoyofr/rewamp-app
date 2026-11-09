/* Batterie MIDI: un index d'INSTRUMENT par TOUCHE du canal 10.
 *
 * L'index d'instrument (vgm_last_instr[], un OCTET) colore les notes du piano
 * « par instrument » et nomme sa légende. Sur le canal 10 il désignait le KIT
 * (129 + programme): toute la batterie sortait d'une seule couleur, sous le
 * nom « Standard ». Or sur ce canal chaque TOUCHE est un instrument — 36 la
 * grosse caisse, 38 la caisse claire, 42 le charleston fermé — et c'est elle
 * que l'œil cherche. Le kit reste le nom de la VOIE (légende « par voie »).
 *
 * Index: 129 + (touche − 27) pour la plage GM/GM2 27..87 (129..189), 190 pour
 * toute autre touche. Partagé par les quatre greffons MIDI (FluidLite, MT-32,
 * libADLMIDI, libOPNMIDI) — leur espace d'index commun s'arrête à 128 côté
 * mélodique, celui-ci commence au-dessus.
 *
 * ⚠️ Les noms sont ceux de la carte GENERAL MIDI. Un kit qui la redistribue
 * (Orchestra, SFX…) garde ces noms-là: c'est la convention que les fichiers
 * suivent, et la seule qu'on puisse nommer sans lire la banque. La rythmique
 * MT-32 suit la même carte sur cette plage (le GM en descend). */
#ifndef REWAMP_GM_DRUMS_H
#define REWAMP_GM_DRUMS_H

#include "rewamp_channel_data.h"

#define REWAMP_DRUM_INSTR_BASE  129u
#define REWAMP_DRUM_KEY_FIRST   27
#define REWAMP_DRUM_KEY_LAST    87
#define REWAMP_DRUM_INSTR_OTHER (REWAMP_DRUM_INSTR_BASE + \
                                 (REWAMP_DRUM_KEY_LAST - REWAMP_DRUM_KEY_FIRST) + 1u)

static const char* const kRewampGmDrumNames[REWAMP_DRUM_KEY_LAST - REWAMP_DRUM_KEY_FIRST + 1] = {
    "High Q", "Slap", "Scratch Push", "Scratch Pull", "Sticks",           /* 27-31 */
    "Square Click", "Metronome Click", "Metronome Bell",                  /* 32-34 */
    "Acoustic Bass Drum", "Bass Drum", "Side Stick", "Acoustic Snare",    /* 35-38 */
    "Hand Clap", "Electric Snare", "Low Floor Tom", "Closed Hi-Hat",      /* 39-42 */
    "High Floor Tom", "Pedal Hi-Hat", "Low Tom", "Open Hi-Hat",           /* 43-46 */
    "Low-Mid Tom", "Hi-Mid Tom", "Crash Cymbal 1", "High Tom",            /* 47-50 */
    "Ride Cymbal 1", "Chinese Cymbal", "Ride Bell", "Tambourine",         /* 51-54 */
    "Splash Cymbal", "Cowbell", "Crash Cymbal 2", "Vibraslap",            /* 55-58 */
    "Ride Cymbal 2", "Hi Bongo", "Low Bongo", "Mute Hi Conga",            /* 59-62 */
    "Open Hi Conga", "Low Conga", "High Timbale", "Low Timbale",          /* 63-66 */
    "High Agogo", "Low Agogo", "Cabasa", "Maracas",                       /* 67-70 */
    "Short Whistle", "Long Whistle", "Short Guiro", "Long Guiro",         /* 71-74 */
    "Claves", "Hi Wood Block", "Low Wood Block", "Mute Cuica",            /* 75-78 */
    "Open Cuica", "Mute Triangle", "Open Triangle", "Shaker",             /* 79-82 */
    "Jingle Bell", "Bell Tree", "Castanets", "Mute Surdo", "Open Surdo",  /* 83-87 */
};

/* L'index d'instrument d'une touche du canal 10. */
static inline unsigned rewamp_drum_instr_index(int key) {
    if (key < REWAMP_DRUM_KEY_FIRST || key > REWAMP_DRUM_KEY_LAST)
        return REWAMP_DRUM_INSTR_OTHER;
    return REWAMP_DRUM_INSTR_BASE + (unsigned)(key - REWAMP_DRUM_KEY_FIRST);
}

/* Nomme toutes les cases de batterie. À l'ouverture, APRÈS les noms
 * mélodiques (rien ne doit écrire au-dessus de 128 ensuite). */
static inline void rewamp_drum_register_names(void) {
    for (int k = REWAMP_DRUM_KEY_FIRST; k <= REWAMP_DRUM_KEY_LAST; k++)
        rewamp_instrument_set_name((int)rewamp_drum_instr_index(k),
                                   kRewampGmDrumNames[k - REWAMP_DRUM_KEY_FIRST]);
    rewamp_instrument_set_name((int)REWAMP_DRUM_INSTR_OTHER, "Percussion");
}

#endif /* REWAMP_GM_DRUMS_H */
