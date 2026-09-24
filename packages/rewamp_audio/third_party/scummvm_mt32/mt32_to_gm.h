/* Table MT-32 -> General MIDI, reprise de ScummVM.
 *
 * Provenance EXACTE: audio/mididrv.cpp, ScummVM v2.0.0
 * (tag v2.0.0, objet 5f5c50a058d194432c608e5c0388804742335fae),
 * https://github.com/scummvm/scummvm — les valeurs sont IDENTIQUES dans le
 * master d'aujourd'hui, mais master est passe en GPL-3.0-or-later alors que
 * la v2.0.0 est GPL-2.0-or-later: on vendore la version la plus PERMISSIVE
 * des deux, pour que cette table ne soit jamais ce qui empeche un jour une
 * distribution compatible GPL-2 (voir LICENSING.md, qui recense deja un
 * composant GPL-2.0-only).
 *
 * Le texte de licence est a cote, dans COPYING. L'en-tete d'origine du
 * fichier suit, verbatim.
 *
 * ----------------------------------------------------------------------
 * ScummVM - Graphic Adventure Engine
 *
 * ScummVM is the legal property of its developers, whose names
 * are too numerous to list here. Please refer to the COPYRIGHT
 * file distributed with this source distribution.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 * ----------------------------------------------------------------------
 *
 * A QUOI CA SERT ICI: un MIDI ecrit pour un MT-32 numerote ses programmes
 * dans la liste d'usine du MT-32, qui n'a RIEN A VOIR avec le General MIDI.
 * Sans ROMs Roland, rewamp le joue sur FluidLite (SoundFont GM) et chaque
 * programme tombe sur un instrument arbitraire. Cette table dit, pour chaque
 * timbre MT-32, le programme GM le plus proche.
 *
 * ⚠️ La table ne couvre QUE les programmes melodiques. Les touches de la
 * partie rythmique (canal 10) passent telles quelles: la carte de percussions
 * du General MIDI DESCEND de celle du MT-32/CM-32L, les sons courants
 * (grosse caisse, caisse claire, charleston) tombent aux memes numeros, et
 * ScummVM lui-meme ne porte aucune table de conversion dans ce sens. Inventer
 * la notre reviendrait a deviner.
 */
#ifndef REWAMP_MT32_TO_GM_H
#define REWAMP_MT32_TO_GM_H

static const unsigned char kMt32ToGm[128] = {
//	  0    1    2    3    4    5    6    7    8    9    A    B    C    D    E    F
	  0,   1,   0,   2,   4,   4,   5,   3,  16,  17,  18,  16,  16,  19,  20,  21, // 0x
	  6,   6,   6,   7,   7,   7,   8, 112,  62,  62,  63,  63,  38,  38,  39,  39, // 1x
	 88,  95,  52,  98,  97,  99,  14,  54, 102,  96,  53, 102,  81, 100,  14,  80, // 2x
	 48,  48,  49,  45,  41,  40,  42,  42,  43,  46,  45,  24,  25,  28,  27, 104, // 3x
	 32,  32,  34,  33,  36,  37,  35,  35,  79,  73,  72,  72,  74,  75,  64,  65, // 4x
	 66,  67,  71,  71,  68,  69,  70,  22,  56,  59,  57,  57,  60,  60,  58,  61, // 5x
	 61,  11,  11,  98,  14,   9,  14,  13,  12, 107, 107,  77,  78,  78,  76,  76, // 6x
	 47, 117, 127, 118, 118, 116, 115, 119, 115, 112,  55, 124, 123,   0,  14, 117  // 7x
};

#endif /* REWAMP_MT32_TO_GM_H */
