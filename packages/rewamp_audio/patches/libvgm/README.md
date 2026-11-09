# Patchs rewamp pour libvgm

Nos modifications de libvgm — **capture d'oscilloscope par voix** et **capture
de notes** (`m_voice_buff`, `vgm_last_note/vol/instr`, décalages de puces
liées) — vivent ici, jamais dans l'arbre du submodule. `scripts/sync_libvgm.sh`
les réapplique en modifications d'ARBRE DE TRAVAIL, le pointeur de submodule
restant sur un vrai SHA amont. Même schéma que libopenmpt et vgmstream.

`UPSTREAM_BASE` = le commit amont sur lequel ces patchs ont été générés.

## Ce que ces patchs contiennent

Trois choses, dans 66 patchs:
1. **Capture d'oscilloscope par voix et capture de notes** dans les coeurs de
   puce (`m_voice_buff`, `vgm_last_note/vol/instr`), plus les accroches de
   décalage de puce liée dans les 5 lecteurs.
2. Depuis le 2026-08-21, la même capture pour **SameBoy** (coeur GameBoy par
   défaut) et pour les **six puces ajoutées par l'amont** depuis 2024:
   K007232, K005289, MSM5205, MSM5232, BSMT2000, ICS2115.
3. Depuis le 2026-10-20, **ES5505 / ES5506 + ES5510 (ESP)**, venus du fork
   `vgmrips/es55xx-tools` (section ci-dessous): sept patchs, dont deux qui
   CRÉENT `es5510.c`/`.h`, et `player-vgmplayer.cpp.patch` qui REMPLACE
   l'ancien (il porte nos hunks YOYOFR en plus des siens).
4. Depuis le 2026-10-23, **ZSG-2 + TMS57002 (carte son Taito Zoom)**, du même
   fork (`vgmrips/libvgm`, branche `es55xx`, commits `7ef151f` + `a6fa084` + `e7bf948` + `8cdace1`; section
   ci-dessous): cinq patchs qui CRÉENT `zsg2.c`/`.h` et `tms57002.cpp`/`.h`/
   `_ops.hxx`, plus `emu-SoundDevs.h` et `emu-SoundEmu.c`, et les trois patchs
   du lecteur régénérés.

⚠️ **Deux formes de boucle, deux façons d'écrire.** Quand la boucle de VOIX est
INTERNE (une passe par échantillon, toutes voies), on remplit un `chanout[]` et
on écrit en fin d'échantillon. Quand elle est EXTERNE (BSMT2000, ICS2115: chaque
voix parcourt tout le bloc), on écrit dans la boucle de chaque voix — **et il
FAUT une passe de rattrapage** qui avance la tête d'écriture des voix muettes en
y écrivant du silence. Sans elle leur tracé reste GELÉ sur sa dernière image au
lieu de retomber à plat, exactement le bug déjà payé sur le SPC de libgme.

5. Depuis le 2026-11-01, **VGM v3** (fork `vgmrips/libvgm`, branche `vgm-v3`,
   commit `d892a5c` = `es55xx` + PR #151 de cam900 + commandes v3; section
   ci-dessous): les quatre cœurs **Namco WSG / C15 / C30 / Pole Position**
   CRÉÉS (avec NOS captures), `emu-dac_control.c` neuf, et `SoundDevs.h`,
   `SoundEmu.c`, `zsg2.c`/`.h` et les trois patchs du lecteur régénérés.

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

Un fichier, un patch (66 aujourd'hui). Un patch monolithique échouerait en bloc au moindre
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

## ES5505 / ES5506 / ES5510 (2026-10-20)

Port du cœur MAME 0.288 (cam900) + DSP d'effets ES5510, fait dans un fork
(`vgmrips/es55xx-tools/rewamp-patches/`). Ce qu'il ajoute au format VGM:
- `0xD7` extension ES5506 (banque externe par voix, fenêtre et alias de région
  ROM, acquittement d'IRQ), `0xD8` commandes ESP (écriture hôte, HALT, routage),
  `0xE3` gain par sortie (8.8). Sous-commandes nommées dans `es5506.h`.
- `0xD6` lu **gros-boutiste** (comme le logger MAME et la commande C352).
- Bit 31 de l'horloge = ES5506 (sinon ES5505), en `cfg.flags` bit 7; bits 0-3
  = paires de sortie, TOUTES rendues puis mixées en stéréo.
- `DEVRW_A8D32` dans `EmuStructs.h`; volume de lecture ES5506 ramené à l'unité.
- L'ESP est un SOUS-OBJET du cœur ES5506 (créé à la première `0xD8`), pas un
  appareil libvgm: aucune voie à afficher, il traite les paires 1-3.

**Vérifié**: `dariusg_track.vgz` (Darius Gaiden, ES5505 + ESP) rendu par notre
arbre patché = rendu `vgm2wav` du fork pur **au bit près** (84 s), et 32 voies
d'oscilloscope + notes vivantes sous AddressSanitizer, sans erreur.

### ⚠️ La capture du fork était celle de MODIZER, pas la nôtre
Le cœur livré écrivait dans `m_voice_buff_accumul_temp[voie]` et laissait au
LECTEUR le soin de vider vers `m_voice_buff` (`ModizMusicPlayer.mm`, bloc VGM).
Chez nous **personne n'alloue ces tampons au-delà de `[0]` ni ne les vide**:
crash NULL au premier échantillon non nul (vu sous ASan). Il bouclait aussi son
pointeur sur `SOUND_BUFFER_SIZE_SAMPLE*2` alors que le greffon pose un anneau
de `*4*2`, et n'écrivait pas le silence (tracé figé). Réécrit sur le modèle de
`c352.c`: écriture DIRECTE dans `m_voice_buff`, masque `*4*2`, les 32 voix
avancent à chaque échantillon (silence compris), `>> 11` (crête mesurée ~48/127
sur Darius Gaiden), et une voix arrêtée publie note 0 (sinon sa touche de piano
reste enfoncée). Le son n'est pas touché.

**`es5503.c` et `ymf271.c`: même correctif, fait le 2026-10-22.** L'ES5503
plantait au PREMIER échantillon (Zany Golf, Apple IIGS, au catalogue vgmrips:
SEGV dans `es5503_pcm_update`), donc tout VGM IIGS tuait l'app. Le YMF271 n'a
pas eu besoin du sien: amont a REMPLACÉ le cœur (« YMF271: new OPX core »,
`3124492`) et l'ancien patch n'avait plus de contexte — capture réécrite sur le
nouveau cœur, une voix par GROUPE (les 12 voies que libvgm coupe), somme des
porteuses, note = première porteuse qui sonne (FM: incrément de phase, PCM:
pas 1x = LA4). Éprouvés sous ASan sur Battle Balls (Seibu SPI) et Zany Golf.

## VGM 1.72: les puces de l'en-tête 0xE4-0xFC

Le logger MAME (`vgmwrite.cpp`, `Header_SizeCheck(…, 0x172, 0x100)`) estampille
1.72 tout fichier qui porte Mikey, K007232, K005289, MSM5205, MSM5232,
BSMT2000, ICS2115 — et l'extension ES55xx. La garde YOYOFR héritée de Modizer
ne refusait que Mikey sous 1.72; elle refuse désormais toute horloge lue à un
décalage ≥ 0xE4 d'un fichier < 1.72 (un en-tête 1.71 qui atteint 0x100 n'y
porte que du bourrage). `0xD6` reste lu gros-boutiste pour TOUTES les versions:
le logger MAME l'a toujours écrit MSB d'abord, c'est l'ancienne lecture
petit-boutiste de libvgm qui était fausse (son ES5506 n'était qu'un bouchon).

## Premier morceau après le lancement: le puits, pas NULL

`Resmpl_Init` fait tourner chaque puce pendant `PlayerA::Start()`, donc AVANT
que `vgm_setup_channels` n'alloue les anneaux, et `m_voice_ChipID[]` statique à
zéro désigne alors la puce 0 pour tout le monde. `rewamp_channel_data_init`
laissait `m_voice_buff[]` à NULL: un ES5506 ouvert en PREMIER plantait
(vasara_0.vgm). L'init pose maintenant le puits partout, comme `reset()`
au-delà des voies allouées.

## ZSG-2 + TMS57002, Taito Zoom (2026-10-23)

Port C du ZSG-2 de MAME 0.288 avec le mixeur de la carte Taito Zoom, et port
C++ du DSP TMS57002 (`tms57002_ops.hxx` GÉNÉRÉ, 21 900 lignes, inclus par
`tms57002.cpp` — jamais compilé seul). Fork `~/Documents/Dev/vgmrips/libvgm`,
commits `7ef151f` + `a6fa084` + `e7bf948` + `8cdace1`; spécification `vgm-tools/VGM-ZSG2-proposal.md`:
- puce `0x30` (`DEVID_ZSG2`), horloge d'en-tête en `0x100`, en-tête de
  `0x110` octets, **VGM 1.72** (décision de l'auteur du 2026-10-23: toutes ses
  extensions de format restent en 1.72 pour l'instant — la spec parlait d'une
  1.73, le fork a été corrigé en `a6fa084`); commande `0xE4` (offset 16 bits, donnée 16
  bits: registres ZSG-2, écriture hôte et lignes PLOAD/CLOAD du DSP, gains du
  mixeur, reset, pré-exécution du DSP); bloc ROM `0x97`; poids de volume `0x200`.
- Le DSP est un SOUS-OBJET du ZSG-2 (comme l'ESP de l'ES5506): aucune voie à
  afficher.
- Garde de version: l'horloge en `0x100` tombe sous la garde 1.72 existante de
  `GetHeaderChipClock` (lue seulement en ≥ 1.72). ⚠️ Ne PAS la monter en
  1.73: les fichiers produits par le logger sont en 1.72.
- `tms57002.cpp` est le PREMIER cœur C++ que nous compilons dans `emu/cores`:
  CMake et les deux podspecs le nomment EXPLICITEMENT. ⚠️ Pas de glob
  `emu/cores/*.cpp`: il ramasserait `ymfmintf.cpp` (YM2414, amont), dont nous
  ne bâtissons pas la bibliothèque ymfm — l'édition de liens échoue.

Capture écrite chez nous (le fork n'en a pas), modèle `es5506.c`: les 48 voix
écrivent DIRECTEMENT dans `m_voice_buff` (masque `*4*2`, silence compris),
`>> 7` (crête mesurée 79/127 sur Ray Storm), note = `440 × step / 0x4000` (un
pas de `0x4000` lit un échantillon par tick), note 0 pour une voix arrêtée.
**Mute au-delà de 32 voies.** `SetMuteMask` ne porte qu'un `UINT32`, et
`PLR_MUTE_OPTS.chnMute[1]` est réservé à la puce LIÉE. Une puce de plus de 32
voies SANS puce liée déclare donc une seconde fonction
`{RWF_CHN_MUTE | RWF_WRITE, DEVRW_ALL, RWUSER_CHN_MUTE_HI, fn}` (défini dans
`EmuStructs.h`), que `VGMPlayer::RefreshMuting` appelle avec `chnMute[1]`.
`zsg2_set_mute_mask` ne touche plus que 0-31 (sinon il effacerait 32-47 à
chaque appel). Le greffon remplit `chnMute[1]` au-delà de 32, et sa boucle
monte à 64 voies — elle s'arrêtait à 32, ce qui laissait aussi les FM 9-18 de
l'OPL4 (YMF278B, 42 voies) impossibles à couper. Vérifié: sans mute = fork au
bit près; 33-48 coupées ⇒ RMS 2540 → 2147; 1-32 ⇒ 1400; les 48 ⇒ 0.

**Image d'état du DSP, bloc `0x98` (fork `8cdace1`).** Les premiers fichiers
rejouaient l'HISTOIRE du DSP depuis le boot de MAME par des commandes PRERUN
(`0xE4`, sous-adresse 8): environ 230 avant la première note de
`raystorm_track_01`, ~2,5 M pas DSP au total, tous dans le PREMIER `Render` —
4 à 16 s d'attente selon la piste (l'histoire s'allonge au fil de la session de
log). Plafonner le prerun côté lecteur n'est PAS une issue: le son change
(écart mesuré jusqu'à ~9 000 par échantillon). Le logger écrit désormais
l'état complet du DSP (registres, file des coefficients, programme, mémoires,
plages non nulles de la mémoire externe) dans un bloc `0x98`, chargé par
`tms57002_state_load`: premier rendu en 1 ms. Les fonctions mémoire du ZSG-2
portent des user IDs distincts (ROM 1, état 2), lus par `InitDevices` en
`romSize`/`romWrite` et `romSizeB`/`romWriteB`. `e7bf948`: la file CLOAD est
appliquée PAR ADRESSE (une rafale VGM posait chaque valeur sur le mauvais
coefficient, les presets de réverbération du jeu partaient en saturation).
Vérifié: pistes 01/02/06 = `vgm2wav` du fork au bit près jusqu'à la fin de
passe (au-delà, le fondu de 8 s de `vgm2wav`), ASan propre, 48 voies, mute
33-48 / 1-32 / tout ⇒ RMS 3715 → 2978 / 2197 / 0.

**Vérifié**: `raystorm - test piste 1 (boucle).vgz` rendu par notre arbre
patché = `vgm2wav` du fork pur **au bit près** (26 s), 48 voies d'oscilloscope
et notes vivantes sous AddressSanitizer, sans erreur; aller-retour
`sync_libvgm.sh` identique à l'arbre de travail.

## VGM v3: Namco WSG, ZSG-2 déplacé (2026-11-01)

Spécification: `VGM-proposal-v3-allocation.md` dans `yoyofr/vgm-tools`. La PR
#151 (Namco WSG, cam900) prend les DEVID 0x30-0x33, les horloges 0x100-0x10C et
les commandes 0x45-0x48 / 0xCA / 0xCB; le ZSG-2 passe en **DEVID 0x34**, horloge
**0x110**, et les commandes ES55xx/Zoom bougent. Les deux encodages annoncent
**1.72**: le numéro de version ne les distingue pas.

⚠️ **Un fichier v1 (packs publiés jusqu'au 31/10/2026) joué tel quel sonne
FAUX** (ZSG-2 lu comme un WSG: son de Pac-Man ou silence). Il est CONVERTI EN
MÉMOIRE au chargement par `vgm_v3.h` (`third_party/vgm_v3/`, copie de
vgm-tools), dans `rewamp_plugin_vgm.cpp` (`vgm_convert_v1_ext`), jamais sur le
disque. ⚠️ Le test « v1 ? » recommandé lit l'horloge ES5506 en 0xD0 — or un
**extra header** (1.70+, offset en 0xBC) VIT dans la zone d'en-tête: un rip
CPS1 de vgmrips l'a en 0xC0 et passait pour un ES5506 (refusé ensuite par le
convertisseur, son intact, mais faux positif). L'en-tête utile s'arrête donc au
début de l'extra header. Mesuré sur 1040 VGM du disque: seuls les 6 albums ES /
ZSG-2 du catalogue et les 7 captures locales déclenchent, 96/96 convertis.

Les cœurs Namco de la PR n'avaient AUCUNE capture: oscilloscope + notes écrits
chez nous (une boucle de voix INTERNE ⇒ `scope_v[]` puis écriture en fin
d'échantillon, toutes voies, muettes à 0), note = vraie hauteur
`freq × rate / 2^fracbits / 32`. Sorties à 192 kHz et plus: `smplIncr` < 1 en
virgule fixe, chaque case de l'anneau est visitée.

Vérifié au bit près contre le `vgm2wav` du fork (`--loops 2 --fade 0`, 25-30 s):
Darius Gaiden v1 converti ET le même en v3, G-Darius (ZSG-2) v1 converti,
RayCrisis v3 natif, un CPS1 classique inchangé. Namco: pas de capture réelle
sur le disque — un VGM synthétique C15 (PROM + 2 voix) donne les notes exactes
440,0 / 660,0 Hz, WSG / C30 stéréo / Pole Position passent ASan.

