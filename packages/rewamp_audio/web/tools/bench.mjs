// Décode des fichiers hors temps réel sous Node avec le module wasm et mesure.
//   node tools/bench.mjs fichier... [-s secondes]
// Le dossier de chaque fichier est copié à côté (compagnons: .psflib, smpl.*,
// .ins…), comme le verrait le moteur dans l'app.
import fs from 'node:fs';
import path from 'node:path';
const here = path.dirname(new URL(import.meta.url).pathname);
const args = process.argv.slice(2);
const si = args.indexOf('-s');
const seconds = si >= 0 ? +args.splice(si, 2)[1] : 20;
const dist = path.join(here, '../site/dist');
const B = JSON.parse(fs.readFileSync(path.join(dist, 'build.json')));
const M = await (await import(path.join(dist, B.js))).default({
  locateFile: p => path.join(dist, p.endsWith('.wasm') ? B.wasm : p) });
const assets = path.resolve(here, '../../../../app/assets');
const cp = (src, dst) => { M.FS.mkdir(dst); for (const g of fs.readdirSync(src)) {
  const p = path.join(src, g); if (fs.statSync(p).isDirectory()) cp(p, dst + '/' + g); else M.FS.writeFile(dst + '/' + g, fs.readFileSync(p)); } };
M.FS.mkdir('/data');
for (const d of ['uade', 'c64', 'sc68', 'adplug', 'opna', 'vgm']) if (fs.existsSync(path.join(assets, d))) cp(path.join(assets, d), '/data/' + d);
M.ccall('rewamp_set_data_dir', null, ['string'], ['/data']);
const bench = M.cwrap('web_bench', 'number', ['string', 'number']);
let k = 0;
for (const arg of args) {
  const [f, q] = arg.split('?');
  const dir = `/m${k++}`; M.FS.mkdir(dir);
  for (const g of fs.readdirSync(path.dirname(f))) {
    const p = path.join(path.dirname(f), g);
    if (fs.statSync(p).isFile() && fs.statSync(p).size < 64e6) M.FS.writeFile(dir + '/' + g, fs.readFileSync(p));
  }
  // fichier?subsong=N: le suffixe va au moteur, pas au système de fichiers.
  bench(dir + '/' + path.basename(f) + (q ? '?' + q : ''), seconds);
}
process.exit(0);
