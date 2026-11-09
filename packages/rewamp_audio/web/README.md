# Moteur Rewamp pour le web (WebAssembly)

Le moteur C/C++ de Rewamp compilé par Emscripten : **le même code que les autres
plateformes** (`cmake/rewamp.cmake`, mêmes drapeaux `REWAMP_WITH_*`), avec une
sortie audio et une couche GL propres au web dans `src/web/`. Il y a aussi une
page de démo minimale (`site/`), qui n'est pas l'interface de l'app.

## Construire et lancer

```bash
brew install emscripten          # testé avec Emscripten 7.0.0
./build.sh                       # → site/dist/ (wasm, js et assets, noms hachés + .br)
node site/server.mjs             # → http://127.0.0.1:8797/
```

`REWAMP_WITH_<X>=0 ./build.sh` retire un moteur, comme ailleurs.

**Ce que la page télécharge** (`tools/dist.mjs`, mesuré le 2026-11-07) :

| fichier | brut | brotli | quand |
|---|---|---|---|
| `rewamp_audio.<hash>.wasm` | 26,9 Mo | 7,4 Mo | au démarrage |
| `core.<hash>.pack` (uade, sc68, c64, adplug, opna, vgm) | 5,0 Mo | 2,5 Mo | au démarrage |
| `projectm.<hash>.pack` (presets, textures) | 5,4 Mo | 4,8 Mo | à l'ouverture du visualiseur |

Les noms sont hachés et servis en cache immutable. Seul `dist/build.json`, qui
les nomme, est en `no-cache`. Un pack regroupe les assets de l'app en un seul
fichier ; avant, il fallait ~400 requêtes. Le serveur doit envoyer le `.br`
voisin avec `Content-Encoding: br` quand le navigateur l'accepte (`server.mjs`
le fait). Les noms de fonctions sont retirés du wasm (2 Mo) ;
`REWAMP_WEB_NAMES=1 ./build.sh` les garde pour lire une pile.

**Pourquoi le wasm n'est pas découpé par moteur** : aucun ne domine (Furnace
4,3 Mo, vgmstream+FFmpeg 4, zxtune 3, openmpt 1,7, puis une longue traîne). Un
découpage passerait par des modules chargés par `dlopen`, avec un code
relogeable plus lent de 10 à 20 %, et les relais gapless entre moteurs
devraient survivre au changement de module. Le seul gain serait sur le premier
téléchargement, que le cache absorbe ensuite.

**vgmstream et FFmpeg.** `build.sh` appelle d'abord `build_ffmpeg.sh`, qui bâtit
une seule fois un FFmpeg 7.1 **statique** dans `build/ffmpeg`. On y garde
seulement les démultiplexeurs, parseurs et décodeurs listés par vgmstream
(`third_party/vgmstream/cmake/dependencies/ffmpeg.cmake`), soit libavcodec à
2,6 Mo. `CMakeLists.txt` le trouve seul. Sans lui, vgmstream est coupé : il
ouvrirait ses formats Vorbis/Opus/AAC/ATRAC/XMA puis rendrait du silence.
⚠️ FFmpeg se compile avec `-pthread`, même sans threads : wasm-ld refuse
d'assembler un objet sans `atomics` dans un module à mémoire partagée.

Bench hors temps réel sous Node : `node tools/bench.mjs fichier… [-s secondes]`. Il donne le
facteur temps réel et le RMS, car un décodeur qui « tourne » vite peut très bien ne rendre que du silence.

## Architecture

```
page (fil principal)            Worker du moteur (module wasm)
────────────────────            ───────────────────────────────────────────
AudioContext 44100 Hz           rewamp_init / rewamp_load_file / rewamp_play…
 └ AudioWorklet ◀── lit ────    producteur ─▶ anneau ─▶ pompe (pthread)
   (out-worklet.js)  en place    (relais gapless, fondu, vitesse: inchangés)
                                       └▶ anneau de sortie EN MÉMOIRE WASM
OffscreenCanvas ── transféré ─▶ projectM (WebGL 2) rendu dans le Worker
```

- **Le moteur vit dans un Worker** : il bloque (`rewamp_load_file` attend le
  premier bloc audio, des threads se joignent), ce qui est interdit sur le fil
  principal.
- **Pas de sortie Web Audio de miniaudio.** Un AudioContext n'existe que sur
  le fil principal, et le mode AudioWorklet de miniaudio exige ASYNCIFY, beaucoup
  trop coûteux sur un module de cette taille. La sortie est donc une pompe
  pthread qui appelle le même `rewamp_device_callback` qu'ailleurs, au rythme où
  l'AudioWorklet consomme. Celui-ci lit l'anneau directement dans la mémoire wasm,
  qui est déjà un SharedArrayBuffer (`src/web/rewamp_device_web.h`, disposition de
  l'en-tête comprise). Latence : 93 ms d'anneau plus la latence du navigateur.
- **projectM** : contexte WebGL 2 créé côté JS sur l'OffscreenCanvas, inscrit
  par `GL.registerContext` (`src/web/rewamp_gl_web.c`). Il n'y a pas de
  préchargement des presets (WebGL ne partage rien entre contextes), donc les
  chargements sont synchrones.
- **C'est l'appelant qui déplie**, comme le fait Dart dans l'app :
  - les sous-chansons, par `rewamp_probe_subsong_count` et
    `rewamp_probe_subsong_index`, en entrées `chemin?subsong=N` ;
  - les archives, par `rewamp_extract_archive` dans un dossier propre à
    l'archive (les compagnons restent à côté du module), puis `rewamp_can_play`.

## Pièges payés

- **Isolation cross-origin obligatoire** (COOP + COEP, cf. `server.mjs`). Sans
  elle, pas de SharedArrayBuffer, donc ni threads ni anneau de sortie.
- **Pthreads lancés depuis un Worker** : Emscripten prend `self.location.href`
  (le script du Worker) comme script des threads. Il faut poser
  `self.__filename = URL de rewamp_audio.js` **avant** `importScripts`.
- **Pool de threads** (`-sPTHREAD_POOL_SIZE`). Dans un navigateur, un thread
  neuf ne démarre que quand son créateur rend la main ; un fil qui crée puis
  joint gèle si le pool ne suffit pas. reSIDfp en lance 6. Node ne montre pas ce
  défaut.
- **zlib : `HAVE_UNISTD_H` doit être PUBLIC.** Sinon une signature incompatible
  devient un piège à l'exécution ; `build.sh` refuse tout avertissement
  « function signature mismatch ».
- **UADE** : pas de `socketpair` sous Emscripten. Un canal en mémoire le remplace
  (`uade/src/frontends/common/unixatomic.c`, sous `__EMSCRIPTEN__`).
- **Furnace** : la liste de sources ne doit pas contenir `adpcm-xq.c`. Son
  `main()` de ligne de commande était exécuté au démarrage du module.
