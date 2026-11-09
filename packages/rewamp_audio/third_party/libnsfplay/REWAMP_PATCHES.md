# Patches rewamp sur libnsfplay (vendoré tel quel, pas de sous-module)

Tous balisés `REWAMP` dans le code. À RÉAPPLIQUER après toute resynchro amont.

## 1. Vitesse de lecture (2026-10-10)

But: tempo plus rapide/lent SANS changer la hauteur. Principe: la routine
`PLAY` du NSF est appelée `speed` fois plus souvent, le CPU et l'APU gardent
leur horloge.

- `devices/CPU/nes_cpu.h/.cpp`: `rewamp_play_speed`, `rewamp_play_rate`,
  `SetPlaySpeed(speed)` (public). `Start()` divise la période de PLAY
  (`fclocks_per_frame`) par `play_rate × rewamp_play_speed` — la vitesse
  SURVIT donc à un `Reset()`. Constructeur: vitesse 1.
- `player/nsf/nsfplay.h/.cpp`: `rewamp_speed` + `RewampSetSpeed(speed)`
  (CPU, temps, relevés). `time_in_ms` avance × vitesse (Render ET Skip): il
  décide le fondu et la fin, donc il compte en temps du MORCEAU.
  `frame_render` (cadence des relevés `infobuf`, d'où viennent les notes que
  publie le greffon) = une trame de MORCEAU: sinon, à 2×, la moitié des notes
  brèves échappait au relevé. `CheckTerminal()`: la durée du fondu passée à
  `FadeStart` (qui compte en sortie) est ÷ vitesse.

Le `MULT_SPEED` d'origine (codé en dur à 256) accélérait CPU ET APU: hauteur
comprise. Il n'est pas utilisé.

## 2. Dépassement d'entier du temps (2026-10-10)

`time_in_ms += (int)(1000 * length / rate …)`: `length` est un `UINT32`,
×1000 débordait au-delà de ~97 s de SORTIE en un seul appel — un seek long
(`Skip`) laissait un temps faux, donc une fin fausse. Calcul en `double`.

Oracle: `scripts/verify_playback_speed.sh` (mode NOTES et mode longueur).

## 3. Fraction décimale des temps .m3u (2026-11-03)

`player/nsf/pls/ppls.cpp` `get_time()`: accepte `m:ss.mmm` (forme des rips
joshw/Knurek: `0:06.559`, `0:12.800`). L'amont ne lisait que l'apostrophe
NEZplug (`0:06'55`, centièmes) et s'arrêtait au point: temps ET fondu
tronqués à la seconde (fin du morceau coupée jusqu'à 999 ms).
