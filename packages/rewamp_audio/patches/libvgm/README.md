# Patchs rewamp pour libvgm

Nos modifications de libvgm — **capture d'oscilloscope par voix** et **capture
de notes** (`m_voice_buff`, `vgm_last_note/vol/instr`, décalages de puces
liées) — vivent ici, jamais dans l'arbre du submodule. `scripts/sync_libvgm.sh`
les réapplique en modifications d'ARBRE DE TRAVAIL, le pointeur de submodule
restant sur un vrai SHA amont. Même schéma que libopenmpt et vgmstream.

`UPSTREAM_BASE` = le commit amont sur lequel ces patchs ont été générés.

## Ce que ces patchs contiennent

Deux choses, dans 59 fichiers:
1. **Capture d'oscilloscope par voix et capture de notes** dans les coeurs de
   puce (`m_voice_buff`, `vgm_last_note/vol/instr`), plus les accroches de
   décalage de puce liée dans les 5 lecteurs.
2. Depuis le 2026-08-21, la même capture pour **SameBoy** (coeur GameBoy par
   défaut) et pour les **six puces ajoutées par l'amont** depuis 2024:
   K007232, K005289, MSM5205, MSM5232, BSMT2000, ICS2115.

⚠️ **Deux formes de boucle, deux façons d'écrire.** Quand la boucle de VOIX est
INTERNE (une passe par échantillon, toutes voies), on remplit un `chanout[]` et
on écrit en fin d'échantillon. Quand elle est EXTERNE (BSMT2000, ICS2115: chaque
voix parcourt tout le bloc), on écrit dans la boucle de chaque voix — **et il
FAUT une passe de rattrapage** qui avance la tête d'écriture des voix muettes en
y écrivant du silence. Sans elle leur tracé reste GELÉ sur sa dernière image au
lieu de retomber à plat, exactement le bug déjà payé sur le SPC de libgme.

## Hauteur d'une puce à ÉCHANTILLONS: 1x = LA4

Convention du projet, la même que dans les coeurs hérités de Modizer
(`c352.c`, `c219.c`, `k053260.c`, `k054539.c`, `iremga20.c`, `multipcm.c`):
**un échantillon lu à vitesse 1x vaut LA4, 440 Hz**, et le reste suit le
rapport des pas de lecture — `vgm_last_note = 440.0 * pas / pas_de_référence`.

Le seul travail par puce est de trouver la valeur de registre qui VAUT 1x, et
elle se lit dans le code d'avance du coeur, jamais de mémoire:

| Puce      | Avance                              | 1x quand        | Note |
|-----------|-------------------------------------|-----------------|------|
| BSMT2000  | `pos += rate`, index `pos>>16`      | `rate == 65536` | `440*rate/65536` |
| ICS2115   | `acc += fc<<2`, adresse `acc>>12`   | `fc == 1024`    | `440*fc/1024` |
| K007232   | `counter -= 32`, recharge `0x1000-step` | `0x1000-step == 32` | `440*32/(0x1000-step)` |
| MSM5205   | ADPCM, aucun registre de hauteur    | toujours        | `440` |

**Deux puces échappent à la convention, et c'est voulu.** Le **K005289** est une
table d'ondes de 32 pas avancée tous les `freq+1` échantillons: sa hauteur RÉELLE
se calcule (`samplerate / (32*(freq+1))`), donc on la publie plutôt qu'un
rapport. Le **MSM5232** est un générateur de tons d'orgue dont chacune des 11
sorties MÉLANGE quatre voix à des pieds différents: une sortie n'a pas UNE
hauteur, en publier une serait inventer — volume seulement.

⚠️ **`m_voice_current_total` se pose INCONDITIONNELLEMENT** dans chaque coeur:
le lecteur accumule `pairedOfs += m_voice_current_total` après chaque device
lié sans jamais remettre ce global à zéro. Le poser sous un `if (length)` fait
hériter le total du dernier coeur rendu — c'est le plantage YM2203/SSG du
2026-08-21.

## Un patch par FICHIER, volontairement

52 fichiers, 52 patchs. Un patch monolithique échouerait en bloc au moindre
changement amont; ici un `scsp.c` qui bouge chez ValleyBell ne fait échouer que
`emu-cores-scsp.c.patch`, et la reprise est chirurgicale.

## ⚠️ Ne PAS « nettoyer » les patchs des espaces

48 % des lignes de ces diffs sont du reformatage tabs → espaces accidentel,
hérité du vendoring d'origine. C'est tentant à retirer. **Mesuré le 2026-08-21,
c'est contre-productif**: régénérés avec `git diff -w`, les patchs passent de
**45/52 à 16/52** qui s'appliquent sur l'amont courant — un diff `-w` ne
s'applique pas de façon fiable, même avec `git apply --ignore-whitespace`.
L'artefact bruyant est le bon.

Le nettoyage correct, si on le veut un jour, est de normaliser l'INDENTATION DE
NOS FICHIERS sur celle de l'amont, puis de régénérer des patchs exacts — pas de
générer des patchs approximatifs.

## ⚠️ Un patch qui S'APPLIQUE n'est pas un patch qui COMPILE

Sur la montée à `d4a07d0` (2026-08-21), `emu-cores-vsu.c.patch` s'est appliqué
sans un mot puis n'a pas compilé: amont avait renommé `Envelope[]` en
`EnvelopeValue[]` (commit « VSU: Improve accuracy »), et le contexte du patch ne
touchait pas cette ligne. **Après toute resynchronisation, passer l'arbre entier
au compilateur**, C et C++, avec la vraie liste de defines des podspecs — pas
seulement regarder si `git apply` est content.

Deux autres pièges de cette montée, invisibles à l'application des patchs:
- `DEVID_OKIM6258/6295` → `DEVID_MSM6258/6295` (amont l'annonce
  « [breaking change] »), donc `rewamp_plugin_vgm.cpp` ET les trois listes de
  defines `SNDDEV_*`.
- **Un `EC_GB_*` est devenu OBLIGATOIRE.** `gbintf.h` auto-active ses deux
  coeurs, **mais seulement `#ifndef SNDDEV_SELECT`** — et nous définissons
  `SNDDEV_SELECT`. Sans un `EC_GB_*` explicite la liste de coeurs GameBoy est
  donc VIDE et les VGM GameBoy cessent de jouer, sans erreur de compilation.
  On définit les DEUX; **l'ordre dans `gbintf.c` décide du défaut** et SameBoy y
  est listé en premier, donc c'est lui qui joue. ⚠️ Ce piège se reproduira à
  chaque puce dont l'amont scinde le coeur: chercher les `#ifndef SNDDEV_SELECT`
  après une montée de version.

## Deux modifications accidentelles, écartées

Le vendoring avait aussi laissé deux choses qui ne sont pas des patchs et qui ne
sont donc PAS reprises ici:
- `emu/cores/ym2612.c` — reformatage tabs → espaces, 0 changement réel
  (`diff -w` est vide).
- `vgm2wav.cpp` — un `DEVID_YM3812` collé par erreur dans un commentaire.
