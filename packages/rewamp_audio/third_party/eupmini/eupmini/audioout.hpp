/*
	Below garbage is from "eupmini" implementation (was in eupplayer_townsEmulator.hpp)
		
	fixme: cleanup that pcm_struct dumbfuckery
*/
#ifndef TJH__EUP_AUDIOOUT_H
#define TJH__EUP_AUDIOOUT_H

/*
 * global data
 *
 */
/* YOYOFR (rewamp): c'etaient des `const int`, et cet en-tete .hpp est inclus
 * par `opn2.c` — donc compile en C, ou un `const int` n'est PAS une expression
 * constante. Trois consequences sous MSVC: les quatre valeurs DERIVEES etaient
 * refusees (C2099), et `buffer[streamAudioBufferOctectsSize]` juste en dessous
 * n'etait plus une taille de tableau valide (C2057). GCC et clang l'acceptent
 * en extension, ce qui est exactement pourquoi personne ne l'avait vu.
 *
 * Un `enum` est une vraie constante de compilation en C COMME en C++, et le
 * type reste `int` pour tous les appelants. */
enum {
    streamAudioSampleOctectSize = 2,
    /* rate 44100 Hz stream */
    streamAudioRate = 44100,
    streamAudioSamplesBlock = 512,
    streamAudioChannelsNum = 2,
    streamAudioSamplesBlockNum = 16,
    streamAudioChannelsSamplesBlock = streamAudioSamplesBlock * streamAudioChannelsNum,
    streamAudioBufferSamples = streamAudioChannelsSamplesBlock * streamAudioSamplesBlockNum,
    streamAudioBufferOctectsSize = streamAudioBufferSamples * streamAudioSampleOctectSize,
    streamBytesPerSecond = streamAudioRate * streamAudioChannelsNum * streamAudioSampleOctectSize
};

struct pcm_struct {
    unsigned char on;
    int stop;

    int write_pos;
    int read_pos;

    int count;

    unsigned char buffer[streamAudioBufferOctectsSize];
};


#endif