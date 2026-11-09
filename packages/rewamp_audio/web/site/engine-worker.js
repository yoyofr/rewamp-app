// Worker du moteur: le VRAI pipeline (rewamp_init → producteur → anneau →
// relais gapless → pompe), la page n'a plus qu'un AudioWorklet qui lit
// l'anneau de sortie en mémoire wasm (src/web/rewamp_device_web.h).
// Emscripten lance ses pthreads sur _scriptName = self.location.href dans un
// Worker, donc CE fichier: `__filename` est le seul crochet lu avant.
// Les noms sont HACHÉS (tools/dist.mjs, cache immutable): build.json, seule
// entrée non hachée, dit lesquels charger.
const B = (() => { const x = new XMLHttpRequest(); x.open('GET', 'dist/build.json', false); x.send(); return JSON.parse(x.responseText); })();
self.__filename = new URL('dist/' + B.js, self.location.href).href;
importScripts(self.__filename);

let M, api, queue = [], cur = -1, serial = '', wantPlay = false, ended = false, viz = null, vizCanvas = null, vizGl = 0, vizMode = 3;
const vizStats = { ms: 0, n: 0 };
const say = s => postMessage({ type: 'print', s });

// Un pack d'assets (tools/dist.mjs) déballé sous /data. projectM n'est chargé
// qu'à l'ouverture du visualiseur: c'est la moitié du poids.
const packs = {};
function loadPack(name) {
  return packs[name] ??= (async () => {
    const t0 = performance.now();
    const buf = await (await fetch('dist/' + B.packs[name])).arrayBuffer();
    const n = new DataView(buf).getUint32(0, true);
    const index = JSON.parse(new TextDecoder().decode(new Uint8Array(buf, 4, n)));
    let off = 4 + n;
    for (const [rel, size] of index) {
      let d = '/data';
      for (const p of rel.split('/').slice(0, -1)) { d += '/' + p; try { M.FS.mkdir(d); } catch {} }
      M.FS.writeFile('/data/' + rel, new Uint8Array(buf, off, size)); off += size;
    }
    say(`assets ${name}: ${index.length} fichiers, ${(buf.byteLength / 1e6).toFixed(1)} Mo en ${Math.round(performance.now() - t0)} ms`);
  })();
}

async function boot() {
  M = await RewampAudio({ print: say, printErr: say, locateFile: p => 'dist/' + (p.endsWith('.wasm') ? B.wasm : p) });
  M.FS.mkdir('/data'); M.FS.mkdir('/m');
  await loadPack('core');
  const c = (n, r, a) => M.cwrap(n, r, a);
  api = {
    setDataDir: c('rewamp_set_data_dir', null, ['string']),
    init: c('rewamp_init', 'number', []),
    load: c('rewamp_load_file', 'number', ['string']),
    play: c('rewamp_play', 'number', []), pause: c('rewamp_pause', 'number', []),
    playing: c('rewamp_is_playing', 'number', []),
    pos: c('rewamp_get_position_seconds', 'number', []),
    dur: c('rewamp_get_duration_seconds', 'number', []),
    seek: c('rewamp_seek_seconds', 'number', ['number']),
    backend: c('rewamp_get_backend_name', 'string', []),
    setNext: c('rewamp_set_next_file', null, ['string', 'number', 'number', 'number', 'number', 'number']),
    clearNext: c('rewamp_clear_next_file', null, []),
    serial: c('rewamp_handoff_serial', 'number', []),
    handoffPending: c('rewamp_handoff_pending', 'number', []),
    crossfade: c('rewamp_set_crossfade_seconds', null, ['number']),
    speed: c('rewamp_set_playback_speed', null, ['number']),
    underruns: c('rewamp_underrun_count', 'number', []),
    devGap: c('rewamp_device_max_gap_us', 'number', []),
    ring: c('rewamp_web_audio_ring', 'number', []),
    probe: c('rewamp_probe_subsong_count', 'number', ['string']),
    probeIdx: c('rewamp_probe_subsong_index', 'number', ['number']),
    probeTitle: c('rewamp_probe_get_title', 'string', ['number']),
    canPlay: c('rewamp_can_play', 'number', ['string']),
    extract: c('rewamp_extract_archive', 'number', ['string', 'string']),
    extractErr: c('rewamp_extract_last_error', 'string', []),
    forcedLoop: c('rewamp_set_forced_loop', null, ['number', 'number', 'number', 'number', 'number']),
    nativeLoop: c('rewamp_has_native_loop_support', 'number', []),
    trackEnd: c('rewamp_set_track_end_seconds', null, ['number']),
    silent: c('rewamp_silent_seconds', 'number', []),
    resetSilence: c('rewamp_reset_silence', null, []),
    volume: c('rewamp_set_volume', null, ['number']),
    nominal: c('rewamp_nominal_duration_seconds', 'number', []),
    engineParam: c('rewamp_set_engine_param', null, ['string', 'string', 'number']),
    prefer: c('rewamp_registry_set_preferred_plugin', null, ['string', 'string']),
  };
  api.setDataDir('/data');
  const t0 = performance.now();
  const r = api.init();
  if (r !== 0) return postMessage({ type: 'error', msg: 'rewamp_init=' + r });
  serial = String(api.serial());
  say('rewamp_init en ' + (performance.now() - t0).toFixed(0) + ' ms');
  // La mémoire wasm EST un SharedArrayBuffer: l'AudioWorklet lit l'anneau en
  // place. Le buffer d'aujourd'hui couvre l'anneau (alloué à l'init); une
  // croissance ultérieure fait un nouvel objet mais l'ancien reste valide.
  postMessage({ type: 'ready', buffer: M.HEAPF32.buffer, ring: api.ring() });
}

// ── Réglages de lecture (Réglages → Lecture, poussés par la page: op 'playback')
// Mêmes défauts et mêmes règles que l'app (player_controller.dart):
//   - boucle forcée: `rewamp_set_forced_loop` AVANT chaque ouverture; le
//     greffon boucle lui-même s'il sait (configure_loop), sinon boucle
//     GÉNÉRIQUE ici (relance au début quand le décodeur s'arrête, durée
//     affichée = base × passes, fondu par le volume);
//   - répéter le morceau = boucle INFINIE (un format à point de boucle ne
//     repart pas de l'intro); répéter la file = boucle COUPÉE (la piste doit
//     finir pour que la file avance);
//   - durée par défaut: un moteur qui ne connaît pas sa fin et sans durée
//     catalogue s'arrête là (150 s);
//   - saut de silence: une sortie muette depuis N s = piste finie.
let pb = { loopMode: 'off', loopCount: 2, fade: false, fadeSecs: 3, defaultLen: 150,
  silenceSkip: true, silenceSecs: 10, queueRepeat: false };
const LOOP = { off: 0, on: 1, infinite: 2 };
const loopModeNow = () => repeatOne ? 2 : pb.queueRepeat ? 0 : (LOOP[pb.loopMode] || 0);
// Base d'une passe pour la boucle: le catalogue, sinon la durée par défaut —
// jamais celle qu'un greffon inventerait (libnsfplay: 5:00 pour tout NSF).
const loopArgs = e => [loopModeNow(), pb.loopCount, pb.fade ? 1 : 0, pb.fadeSecs, (e && e.d) || pb.defaultLen];
// UADE a sa propre base de durées (songdb, arrivée par setdur) et finit seul:
// la durée par défaut ne le coupe jamais (comme l'app).
const defaultLenFor = () => api.backend() === 'uade' ? null : pb.defaultLen;
// Volume de sortie = gain de la boucle générique (fondu de fin) × gain du
// MODE SOMMEIL (fondu avant l'arrêt, piloté par la page). Les deux passent par
// le seul rewamp_set_volume: ils se MULTIPLIENT, aucun n'écrase l'autre.
let loopGain = 1, sleepGain = 1;
const applyVolume = () => api.volume(loopGain * sleepGain);
const setLoopGain = g => { if (g !== loopGain) { loopGain = g; applyVolume(); } };
// La piste CHARGÉE: boucle native ou générique, passes déjà rejouées.
let trk = null;
function trackLoaded() {
  const e = queue[cur];
  trk = { native: !!api.nativeLoop(), mode: loopModeNow(), restarts: 0, lastRestart: 0 };
  loopGain = 1; applyVolume(); api.resetSilence();
  api.trackEnd(producerEnd(e));
}
// Durée d'UNE passe: le moteur, sinon le catalogue, sinon la durée par défaut.
const baseOf = e => api.dur() > 0 ? (trk && trk.native && api.nominal() > 0 ? api.nominal() : api.dur()) : ((e && e.d) || defaultLenFor() || pb.defaultLen);
// Boucle générique: le greffon ne sait pas boucler, on s'en charge.
const generic = () => trk && !trk.native && trk.mode > 0 && !repeatOne;
// Fin imposée par NOUS (null = le moteur s'arrête seul, Infinity = jamais).
function endOf(e) {
  if (!trk) return null;
  if (trk.mode === 2 && (trk.native || !repeatOne)) return Infinity;
  if (generic()) return baseOf(e) * (pb.loopCount + 1);
  return api.dur() > 0 ? null : ((e && e.d) || defaultLenFor());
}
// Ce que le producteur doit savoir pour enchaîner (gapless) un moteur sans fin.
function producerEnd(e) { const x = endOf(e); return x && isFinite(x) && !generic() ? x : 0; }
// Position ENTENDUE, en temps écoulé à travers les passes génériques.
const elapsed = e => generic() ? trk.restarts * baseOf(e) + api.pos() : api.pos();

// Le relais armé: l'entrée suivante, ou la MÊME en répétition d'un morceau
// (relais vers soi-même: le morceau repart de zéro sans blanc). `armed` dit
// laquelle sera promue — la promotion ne suppose plus « cur + 1 ».
// Jamais d'armement sous boucle générique (le producteur couperait à la fin
// d'une passe) ni sous boucle infinie native (elle ne finit pas).
let repeatOne = false, armed = -1;
function arm() {
  const j = repeatOne ? cur : cur + 1;
  const n = (trk && !repeatOne && (generic() || (trk.native && trk.mode === 2))) ? null : queue[j];
  armed = n ? j : -1;
  if (n) api.setNext(n.p, ...loopArgs(n)); else api.clearNext();
}

// `play` = lancer après le chargement; faux quand l'utilisateur a demandé la
// pause PENDANT l'ouverture (la piste arrive chargée, pas lancée — comme l'app).
function start(i, play = true) {
  if (i < 0 || i >= queue.length) {
    if (wantPlay && i >= queue.length) {
      // Un moteur sans fin (SID) joue encore: la file est épuisée, il se tait.
      if (api.playing()) api.pause();
      ended = true; postMessage({ type: 'ended', n: queue.length });
    }
    wantPlay = false; return;
  }
  ended = false;
  cur = i;
  wakeViz();   // nouvelle piste: l'image change même si elle arrive en pause
  const t0 = performance.now();
  api.forcedLoop(...loopArgs(queue[i]));
  const r = api.load(queue[i].p);
  if (r !== 0) { say('échec ' + queue[i].t + ' (' + r + ')'); return start(i + 1); }
  serial = String(api.serial());
  trackLoaded();
  if (play) { api.play(); wantPlay = true; } else { wantPlay = false; postState(); }
  say(`▶ ${queue[i].t} · ${api.backend()} · chargé en ${(performance.now() - t0).toFixed(0)} ms`);
  arm();
}

// L'état, poussé à la page toutes les 250 ms ET juste après une commande de
// transport (sinon la page attend jusqu'à 250 ms pour voir l'effet d'un clic).
// ⚠️ La durée vient du DÉCODEUR, la position de ce qu'on ENTEND. Pendant un
// relais gapless le producteur a déjà ouvert la piste suivante 1 à 2 s avant
// que l'oreille n'atteigne la frontière: la durée lue serait celle de la piste
// d'APRÈS (vu: « 2:17 / 1:06 »). Tant que le relais n'est pas promu, on garde
// celle de la piste entendue — l'app native fige la sienne au chargement.
let shownDur = 0;
function postState() {
  // Moteur sans durée (SID, UADE…): celle du catalogue, portée par l'entrée.
  // Boucle générique: total = base × passes, position = temps écoulé; boucle
  // infinie: la durée d'UNE passe, position PLAFONNÉE (une barre qui retombe
  // à zéro prétendrait savoir où la musique repart).
  const e = queue[cur];
  let pos = api.pos();
  if (!api.handoffPending()) {
    const end = endOf(e);
    if (generic()) { const base = baseOf(e); pos = elapsed(e); shownDur = isFinite(end) ? end : base; if (!isFinite(end)) pos = Math.min(pos, base); }
    else if (end === Infinity) { shownDur = baseOf(e); pos = Math.min(pos, shownDur); }
    else shownDur = api.dur() > 0 ? api.dur() : (end || 0);
  }
  postMessage({
    type: 'state', pos, dur: shownDur, playing: !!api.playing(),
    title: (queue[cur] && queue[cur].t) || '', key: (queue[cur] && queue[cur].k) ?? null, backend: api.backend() || '', idx: cur, n: queue.length,
    underruns: Number(api.underruns()), devGapMs: Number(api.devGap()) / 1000,
    vizMs: vizStats.n ? vizStats.ms / vizStats.n : 0, vizFps: vizStats.n * 4,
  });
  vizStats.ms = 0; vizStats.n = 0;
}

setInterval(() => {
  if (!api) return;
  // Relais gapless promu: le consommateur a franchi la frontière.
  const s = String(api.serial());
  if (s !== serial) {
    serial = s; cur = armed >= 0 ? armed : cur + 1;
    say(`⇢ relais: ${queue[cur] && queue[cur].t} · ${api.backend()}`);
    trackLoaded();
    arm();
  } else if (wantPlay && !api.handoffPending()) tickTrack();
  if (viz && vizAsleep && vizShouldRender()) { vizAsleep = false; vizFrame(); }   // la lecture reprend
  // projectM a changé de preset (tout seul ou à la main): la page en prépare un
  // de plus d'avance (presets à la demande) et met à jour le nom affiché.
  if (viz && vizMode === 3) {
    const ps = M.ccall('rewamp_projectm_preset_serial', 'number', [], []);
    if (ps !== lastPresetSerial) { lastPresetSerial = ps; postMessage({ type: 'presetchange', serial: ps, name: M.ccall('rewamp_projectm_preset_name', 'string', [], []) || '', path: M.ccall('rewamp_projectm_preset_path', 'string', [], []) || '' }); }
  }
  postState();
}, 250);

const advance = () => start(repeatOne ? cur : cur + 1);
function tickTrack() {
  const e = queue[cur]; if (!e || !trk) return;
  const playing = api.playing(), now = performance.now();
  if (generic()) {
    const base = baseOf(e), end = endOf(e), el = elapsed(e);
    if (el >= end) return advance();
    // Décodeur arrêté NET, ou muet arrivé au bout d'une passe: on relance la
    // passe suivante (seek 0, + play s'il s'est arrêté).
    const stalled = !playing || (api.silent() >= 2 && api.pos() >= base - 1);
    if (stalled) {
      if (now - trk.lastRestart < 1500) return;
      trk.lastRestart = now; trk.restarts++;
      api.seek(0); api.resetSilence(); if (!playing) api.play();
      return;
    }
  } else {
    if (!playing) return advance();   // fin sans relais (pas de suivant armé, ou relais impossible)
    // Un moteur qui ne connaît pas sa fin (SID, UADE…) ne s'arrête jamais: la
    // durée catalogue, sinon la durée par défaut, fait foi (`reachedKnownEnd`).
    const end = endOf(e);
    if (end && isFinite(end) && api.pos() >= end) return advance();
  }
  if (pb.silenceSkip && endOf(e) !== Infinity && api.silent() >= pb.silenceSecs) { api.resetSilence(); return advance(); }
}
// Fondu de fin de la boucle générique (le natif fait le sien dans le C):
// rampe de volume sur les fadeSecs dernières secondes, à 20 images/s.
setInterval(() => {
  if (!api || !wantPlay || !generic() || !pb.fade || !(pb.fadeSecs > 0)) return;
  const e = queue[cur], end = endOf(e); if (!isFinite(end)) return;
  const left = end - elapsed(e);
  setLoopGain(left < pb.fadeSecs ? Math.max(0, left / pb.fadeSecs) : 1);
}, 50);

// Visualiseur au REPOS (comme l'app, rewamp_viz_idle.h): on dessine quand ça
// joue, et 3 s de grâce après tout le reste (les animations finissent: touches
// du piano, étincelles, fondu de preset). Endormi, il ne demande même plus
// d'image: le tick de 250 ms le relance quand rewamp_viz_should_render repasse
// à 1 (lecture), et wakeViz() sur tout ce qui change l'affichage sans que la
// musique avance (mode, option, taille, piste, preset, déplacement).
let vizAsleep = false, lastVizDraw = 0, lastPresetSerial = -1;
const vizShouldRender = () => !!M.ccall('rewamp_viz_should_render', 'number', [], []);
function wakeViz() {
  if (!M) return;
  M.ccall('rewamp_viz_wake', null, [], []);
  if (viz && vizAsleep) { vizAsleep = false; vizFrame(); }
}
function vizFrame(ts) {
  if (!viz) return;
  if (!vizShouldRender()) { vizAsleep = true; return; }   // figé: plus de rendu ni d'image demandée
  // Plafond de cadence (Réglages → Visualiseurs: 30, 60 ou celle de l'écran),
  // comme l'app (rewamp_viz_idle.h): un écran à 120 Hz ne redessine pas deux
  // fois la même forme d'onde. 0 = la cadence de l'écran.
  const fps = M.ccall('rewamp_viz_max_fps', 'number', [], []), now = performance.now();
  if (fps > 0 && now - lastVizDraw < 1000 / fps - 3) { (self.requestAnimationFrame || (f => setTimeout(f, 16)))(vizFrame); return; }
  lastVizDraw = now;
  const t0 = performance.now();
  // L'horloge d'image avant chaque rendu (notation, piano et motifs défilent
  // sur elle), puis le renderer du mode choisi — src/web/rewamp_viz_web.cpp.
  M.ccall('rewamp_web_viz_render', null, ['number'], [(ts ?? t0) / 1000]);
  vizStats.ms += performance.now() - t0; vizStats.n++;
  (self.requestAnimationFrame || (f => setTimeout(f, 16)))(vizFrame);
}

// Archives: comme l'app (RewampDb.extractLocalArchiveToTracks), extraire dans
// un dossier PROPRE à l'archive — les compagnons (smpl.*, .ins, .psflib)
// doivent rester à côté de leur module — puis mettre en file ce que le moteur
// sait jouer. Un .rsn n'est PAS une archive ici: il joue en place (RAR de .spc).
const ARCHIVE = /\.(zip|7z|lha|lzh|rar|tar|gz|tgz|xz|bz2|lzx)$/i;
const COMPANION = /lib$|^smpl\.|\.smpl$|\.(ins|txt|nfo|diz|m3u|m3u8|jpg|jpeg|png|gif|pdf|htm|html|doc)$/i;
function expandArchive(path, name, pushFile) {
  const dest = path + '.d';
  try { M.FS.mkdir(dest); } catch {}
  const t0 = performance.now();
  const rc = api.extract(path, dest);
  if (rc !== 0) { say(`archive ${name}: échec ${rc} ${api.extractErr()}`); return; }
  const files = [];
  const walk = d => { for (const f of M.FS.readdir(d)) { if (f === '.' || f === '..') continue;
    const q = d + '/' + f; if (M.FS.isDir(M.FS.stat(q).mode)) walk(q); else files.push(q); } };
  walk(dest);
  files.sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' }));
  let n = 0;
  for (const q of files) {
    const base = q.slice(q.lastIndexOf('/') + 1);
    if (COMPANION.test(base) || !api.canPlay(q)) continue;
    pushFile(q, `${name} › ${base}`); n++;
  }
  say(`archive ${name}: ${files.length} fichiers, ${n} jouables, extraite en ${(performance.now() - t0).toFixed(0)} ms`);
}

// Un fichier à sous-chansons (RSN, NSF, SID, KSS…) devient UNE entrée par
// sous-chanson, adressée par ?subsong=<index ABSOLU> — comme le fait l'app
// (Dart), sinon seul le premier morceau joue. Rend [{p, t, idx}].
function subsongEntries(p, label) {
  const n = api.probe(p);
  if (n <= 1) return [{ p, t: label, idx: null }];
  const out = [];
  for (let k = 0; k < n; k++) {
    const t = api.probeTitle(k), idx = api.probeIdx(k);
    out.push({ p: p + '?subsong=' + idx, t: `${label} · ${t || '#' + (k + 1)}`, title: t || '', idx });
  }
  return out;
}
const mkdirs = path => { let d = ''; for (const part of path.split('/').slice(1, -1)) { d += '/' + part; try { M.FS.mkdir(d); } catch {} } };
const walkFiles = d => { const out = []; const w = d => { for (const f of M.FS.readdir(d)) { if (f === '.' || f === '..') continue;
  const q = d + '/' + f; if (M.FS.isDir(M.FS.stat(q).mode)) w(q); else out.push(q); } }; w(d); return out; };
const rmTree = d => { try { for (const f of M.FS.readdir(d)) { if (f === '.' || f === '..') continue; const q = d + '/' + f;
  if (M.FS.isDir(M.FS.stat(q).mode)) rmTree(q); else M.FS.unlink(q); } M.FS.rmdir(d); } catch {} };

// API par requêtes (l'app web: webapp/). Chaque {type:'call', id, op, args}
// reçoit {type:'reply', id, ok, value|error}. La file appartient à l'APPELANT:
// il n'envoie que des entrées dont les fichiers sont déjà dans le FS, et
// complète la file sur 'ended' (ou avant, pour le gapless).
const ops = {
  // Écrit un fichier (dossiers créés).
  put(path, data) { mkdirs(path); M.FS.writeFile(path, new Uint8Array(data)); },
  exists(path) { try { M.FS.stat(path); return true; } catch { return false; } },
  // Appel C direct, borné aux exports du moteur (réglages des visualiseurs:
  // palettes, aspect du piano…). La page n'appelle que des noms qu'elle connaît.
  ccall(name, ret, types, args) {
    if (!/^rewamp_[a-z0-9_]+$/.test(name)) throw new Error('appel refusé: ' + name);
    const r = M.ccall(name, ret, types, args);
    wakeViz();   // une option de visualiseur change l'image: la redessiner, même en pause
    return r;
  },
  // Panneau d'informations (comme ⓘ dans l'app): le texte du greffon pour la
  // piste en cours (tags, format, moteur) et les fichiers qu'il a ouverts
  // (compagnons compris).
  info() {
    let files = [];
    try { files = JSON.parse(M.ccall('rewamp_loaded_files_json', 'string', [], []) || '[]'); } catch {}
    return { message: M.ccall('rewamp_track_message', 'string', [], []) || '', files, backend: api.backend() || '' };
  },
  // Octets d'un fichier du FS (copie): MD5 d'un fichier extrait, pour les durées.
  read(path) { const d = M.FS.readFile(path); return d.buffer.slice(d.byteOffset, d.byteOffset + d.byteLength); },
  // Déplie une archive dans dest; rend [{path, playable}] trié.
  extract(archive, dest) {
    mkdirs(dest + '/x'); try { M.FS.mkdir(dest); } catch {}
    const rc = api.extract(archive, dest);
    if (rc !== 0) throw new Error(`extraction ${rc}: ${api.extractErr()}`);
    return walkFiles(dest).sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' }))
      .map(path => ({ path, playable: !COMPANION.test(path.slice(path.lastIndexOf('/') + 1)) && !!api.canPlay(path) }));
  },
  canPlay(path) { return !!api.canPlay(path); },
  // Sous-chansons d'un fichier: [{p, idx, title}] (une seule entrée, idx null, si aucune).
  entries(path) { return subsongEntries(path, '').map(e => ({ p: e.p, idx: e.idx, title: e.title || '' })); },
  // Remplace la file ([{p, t, k}]) et lance l'entrée `start`.
  queue(entries, startAt = 0, play = true) { queue = entries.slice(); ended = false; start(startAt, play); },
  // Ajoute en fin; arme le suivant si on jouait la dernière.
  // Ajoute en fin. On ne LANCE l'ajout que si rien n'a encore joué ou si la
  // file était ÉPUISÉE — jamais parce qu'on est en PAUSE: le préchargement de
  // l'app ajoute la piste suivante à tout moment, et « pas en lecture » faisait
  // repartir la musique (sur la piste d'après) pendant une pause.
  append(entries) { const first = queue.length; queue.push(...entries); if (cur < 0 || ended) start(first); else arm(); },
  jump(i) { start(i); },
  // La page a réordonné / retiré des unités derrière la piste en cours: on
  // coupe la file du moteur après l'entrée n-1 (jamais la piste en cours, ni un
  // relais déjà ouvert par le producteur, qui sera promu quoi qu'il arrive).
  truncate(n) {
    const keep = Math.max(cur + 1, api.handoffPending() && armed >= 0 ? armed + 1 : 0, n);
    if (keep < queue.length) queue.length = keep;
    arm();
  },
  // Vider la file: silence, plus rien de chargé à reprendre par « lecture ».
  stop() { api.pause(); api.clearNext(); M.ccall('rewamp_unload', null, [], []); queue = []; cur = -1; trk = null; armed = -1; wantPlay = false; ended = true; postState(); },
  // Répéter le morceau en cours (le mode « répéter la file » vit dans la page).
  repeat(one) { repeatOne = !!one; if (cur >= 0) arm(); },
  // Durée catalogue arrivée APRÈS coup (piste en cours, moteur sans durée).
  setdur(k, d) {
    const e = queue.find(x => x.k === k); if (!e || !(d > 0)) return;
    e.d = d;
    if (e === queue[cur]) api.trackEnd(producerEnd(e)); else arm();   // la base du suivant armé change
  },
  // Réglages des moteurs (Réglages → Moteurs, comme app_shell.dart): des
  // triplets [moteur, clé, valeur] pour rewamp_set_engine_param — lus par les
  // greffons à leur open(), donc pour le PROCHAIN morceau ouvert — et des
  // paires [extension, greffon|null] pour l'épingle des décodeurs par défaut.
  // Mode sommeil: gain 0..1 du fondu avant l'arrêt (1 = normal).
  sleepgain(g) { const v = Math.min(1, Math.max(0, +g)); if (v !== sleepGain) { sleepGain = v; applyVolume(); } },
  engineParams(list) { for (const [e, k, v] of list) api.engineParam(e, k, +v); },
  prefer(list) { for (const [ext, name] of list) api.prefer(ext, name || null); },
  // Réglages de lecture (voir `pb`): pris en compte au prochain chargement
  // pour la boucle native, tout de suite pour le reste.
  playback(o) { pb = { ...pb, ...o }; if (cur >= 0) { api.trackEnd(producerEnd(queue[cur])); arm(); } },
  // Retire un dossier du FS (mémoire): un album qu'on n'écoute plus.
  drop(dir) { rmTree(dir); },
  // Fichiers d'un dossier du FS (presets intégrés de projectM: le navigateur de presets).
  ls(dir) { try { return M.FS.readdir(dir).filter(f => f !== '.' && f !== '..'); } catch { return []; } },
};

const handlers = {
  call(m) {
    try { postMessage({ type: 'reply', id: m.id, ok: true, value: ops[m.op](...(m.args || [])) }); }
    catch (err) { postMessage({ type: 'reply', id: m.id, ok: false, error: String(err && err.message || err) }); }
  },
  add(m) {
    for (const f of m.files) M.FS.writeFile('/m/' + f.name, new Uint8Array(f.data));
    const entries = [];
    const pushFile = (p, label) => {
      const e = subsongEntries(p, label);
      entries.push(...e.map(x => ({ p: x.p, t: x.t })));
      if (e.length > 1) say(`${label}: ${e.length} sous-chansons`);
    };
    for (const name of m.tracks) {
      if (ARCHIVE.test(name)) { expandArchive('/m/' + name, name, pushFile); continue; }
      pushFile('/m/' + name, name);
    }
    if (!entries.length) return say('rien de jouable: la file ne change pas');
    if (m.replace) { queue = entries; return start(0); }
    const first = queue.length;
    queue.push(...entries);
    if (cur < 0 || ended) start(first); else arm();   // jamais relancé par une pause
  },
  toggle() { if (api.playing()) { api.pause(); wantPlay = false; } else if (cur >= 0) { api.play(); wantPlay = true; } postState(); },
  // Intentions EXPLICITES (l'app web): deux clics rapides font lecture puis
  // pause, jamais deux bascules dont la seconde annule la première alors que
  // le Worker n'a pas encore traité la première.
  play() { if (cur >= 0) { api.play(); wantPlay = true; } postState(); },
  pause() { api.pause(); wantPlay = false; postState(); },
  next() { start(cur + 1); },
  prev() { start(Math.max(cur - 1, 0)); },
  // Boucle générique: la position est en temps ÉCOULÉ à travers les passes.
  seek(m) {
    const e = queue[cur];
    if (generic()) { const base = baseOf(e); trk.restarts = Math.floor(m.t / base); api.seek(m.t % base); setLoopGain(1); }
    else if (endOf(e) === Infinity) api.seek(Math.min(m.t, baseOf(e)));
    else api.seek(m.t);
    api.resetSilence();
    wakeViz();   // la grille de motifs / le piano sautent à la nouvelle position
  },
  crossfade(m) { api.crossfade(m.s); arm(); },
  speed(m) { api.speed(m.v); },
  // Le canvas (transféré UNE fois) et le mode de départ: 0 stéréo, 1 voies,
  // 2 notation, 3 projectM (défaut, la démo), 4 motifs, 5 spectre, 6 piano.
  async viz(m) {
    const gl = m.canvas.getContext('webgl2', { alpha: false, antialias: false, depth: true, preserveDrawingBuffer: false });
    if (!gl) return postMessage({ type: 'error', msg: 'pas de WebGL2 dans le Worker' });
    vizGl = M.GL.registerContext(gl, { majorVersion: 2, minorVersion: 0, enableExtensionsByDefault: true });
    vizCanvas = m.canvas;
    M.ccall('rewamp_gl_web_set_context', null, ['number', 'number', 'number'], [vizGl, m.canvas.width, m.canvas.height]);
    await handlers.vizmode({ mode: m.mode ?? 3 });
    viz = m.canvas; vizFrame();
  },
  // Changer de visualiseur: les objets GL des autres survivent (init idempotente).
  // Les assets projectM (la moitié du poids) ne descendent qu'à son premier usage.
  async vizmode(m) {
    if (!vizCanvas) { vizMode = m.mode; return; }
    if (m.mode === 3) await loadPack('projectm');
    const r = M.ccall('rewamp_web_viz_select', 'number', ['number', 'number', 'number'], [m.mode, vizCanvas.width, vizCanvas.height]);
    if (r !== 0) return say(`visualiseur ${m.mode}: init ${r}`);
    vizMode = m.mode;
    if (m.mode === 3) postPreset();
    wakeViz();
    postMessage({ type: 'vizmode', mode: m.mode,
      preset: m.mode === 3 ? M.ccall('rewamp_projectm_preset_name', 'string', [], []) : '' });
  },
  // Taille en pixels du canvas (celle de sa boîte × devicePixelRatio).
  vizsize(m) {
    // La grille des motifs dessine son texte en pixels: l'échelle d'écran
    // (devicePixelRatio, plafonné par la page), comme le widget Dart.
    if (m.scale) M.ccall('rewamp_patternviz_set_pixel_scale', null, ['number'], [m.scale]);
    if (!vizCanvas || (vizCanvas.width === m.w && vizCanvas.height === m.h)) return;
    vizCanvas.width = m.w; vizCanvas.height = m.h;
    M.ccall('rewamp_gl_web_set_context', null, ['number', 'number', 'number'], [vizGl, m.w, m.h]);
    // projectM relit rewamp_gl_width/height à chaque image; les autres
    // renderers aussi, l'init idempotente recale ce qui dépend de la taille.
    M.ccall('rewamp_web_viz_select', 'number', ['number', 'number', 'number'], [vizMode, m.w, m.h]);
    wakeViz();
  },
  // Masquer arrête le rendu (et rend l'avance demandée au producteur);
  // afficher le relance, sans recréer le canvas.
  vizpause() { if (viz) { viz = null; M.ccall('rewamp_web_viz_idle', null, [], []); } },
  vizresume() { if (!viz && vizCanvas) { viz = vizCanvas; vizAsleep = false; M.ccall('rewamp_viz_wake', null, [], []); handlers.vizmode({ mode: vizMode }); vizFrame(); } },
  nextpreset() { M.ccall('rewamp_projectm_next_preset', null, [], []); postPreset(); wakeViz(); },
  prevpreset() { M.ccall('rewamp_projectm_prev_preset', null, [], []); postPreset(); wakeViz(); },
};
// Nom du preset projectM, poussé à la page (affiché dans les contrôles du viz).
// Un chargement peut être différé d'une image: on renvoie aussi un peu après.
function postPreset() {
  const send = () => postMessage({ type: 'preset', name: M.ccall('rewamp_projectm_preset_name', 'string', [], []) || '', path: M.ccall('rewamp_projectm_preset_path', 'string', [], []) || '' });
  send(); setTimeout(send, 300);
}
const fail = err => postMessage({ type: 'error', msg: String(err && err.stack || err) });
onmessage = e => { try { Promise.resolve(handlers[e.data.type](e.data)).catch(fail); } catch (err) { fail(err); } };
boot();
