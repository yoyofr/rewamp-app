// Prépare ce que la page télécharge, dans site/dist/ (régénéré à chaque build):
//   - rewamp_audio.<hash>.{js,wasm}: noms HACHÉS, donc servis en cache immutable
//     (un nouveau build = un nouveau nom, jamais un vieux wasm resservi);
//   - <nom>.<hash>.pack: les assets de l'app que le moteur lit à l'exécution,
//     en UN fichier par groupe au lieu de ~400 requêtes. « core » au démarrage,
//     « projectm » (presets + textures, la moitié du poids) seulement quand le
//     visualiseur s'ouvre;
//   - un .br à côté de chaque fichier (server.mjs le sert si le navigateur
//     l'accepte), et build.json, la seule entrée NON hachée, qui les nomme.
// Format d'un pack: u32 LE (longueur de l'index JSON), index [[chemin, taille]…],
// puis les octets bout à bout. Chemins relatifs à app/assets/.
//   node tools/dist.mjs <dossier de build>
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
const here = path.dirname(new URL(import.meta.url).pathname);
const build = path.resolve(process.argv[2] || path.join(here, '../build'));
const site = path.resolve(here, '../site');
const dist = path.join(site, 'dist');
const assets = path.resolve(here, '../../../../app/assets');

// uade: score + eagleplayers · c64: ROMs libres de sidplayfp · sc68: replays ·
// adplug: banques · opna: rythmes YM2608 · vgm: ROM OPL4 · projectm: presets et
// textures. (soundfonts/ et mt32/ ne sont pas embarqués: téléchargés à part.)
const groups = { core: ['uade', 'c64', 'sc68', 'adplug', 'opna', 'vgm'], projectm: ['projectm'] };

const hash = b => crypto.createHash('sha256').update(b).digest('hex').slice(0, 10);
fs.rmSync(dist, { recursive: true, force: true });
fs.mkdirSync(dist);
const put = (stem, ext, data) => {
  const name = `${stem}.${hash(data)}.${ext}`;
  fs.writeFileSync(path.join(dist, name), data);
  fs.writeFileSync(path.join(dist, name + '.br'), zlib.brotliCompressSync(data, {
    params: { [zlib.constants.BROTLI_PARAM_QUALITY]: 11, [zlib.constants.BROTLI_PARAM_SIZE_HINT]: data.length } }));
  return name;
};

const walk = (d, out) => {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    if (e.name === '.DS_Store') continue;
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p, out); else out.push(p);
  }
  return out;
};
const pack = dirs => {
  const files = dirs.filter(d => fs.existsSync(path.join(assets, d)))
    .flatMap(d => walk(path.join(assets, d), [])).sort();
  const blobs = files.map(f => fs.readFileSync(f));
  const index = Buffer.from(JSON.stringify(files.map((f, i) =>
    [path.relative(assets, f).split(path.sep).join('/'), blobs[i].length])));
  const head = Buffer.alloc(4); head.writeUInt32LE(index.length);
  return Buffer.concat([head, index, ...blobs]);
};

const out = { packs: {} };
out.wasm = put('rewamp_audio', 'wasm', fs.readFileSync(path.join(build, 'rewamp_audio.wasm')));
out.js = put('rewamp_audio', 'js', fs.readFileSync(path.join(build, 'rewamp_audio.js')));
for (const [g, dirs] of Object.entries(groups)) out.packs[g] = put(g, 'pack', pack(dirs));
fs.writeFileSync(path.join(dist, 'build.json'), JSON.stringify(out, null, 1));

for (const n of [out.js, out.wasm, ...Object.values(out.packs)]) {
  const a = fs.statSync(path.join(dist, n)).size, b = fs.statSync(path.join(dist, n + '.br')).size;
  console.log(`${n.padEnd(36)} ${(a / 1e6).toFixed(2).padStart(6)} Mo → ${(b / 1e6).toFixed(2).padStart(5)} Mo br`);
}
