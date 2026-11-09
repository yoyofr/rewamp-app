// Serveur statique de la démo, isolé cross-origin (COOP + COEP): sans ça pas de
// SharedArrayBuffer, donc ni threads wasm ni anneau de sortie partagé.
//   node server.mjs [port]      (défaut 8797)
// dist/ vient de tools/dist.mjs: un nom HACHÉ est servi en cache immutable, et
// son .br à la place quand le navigateur accepte brotli. build.json, non haché,
// reste en no-cache.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
const root = path.dirname(new URL(import.meta.url).pathname);
const port = +(process.argv[2] || 8797);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.wasm': 'application/wasm', '.json': 'application/json' };
http.createServer((req, res) => {
  let u = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (u === '/') u = '/index.html';
  const f = path.resolve(path.join(root, u));
  if (!f.startsWith(root + path.sep)) { res.writeHead(403); return res.end(); }
  const hashed = /\.[0-9a-f]{10}\.[a-z]+$/.test(f);
  const br = hashed && /\bbr\b/.test(req.headers['accept-encoding'] || '') && fs.existsSync(f + '.br');
  fs.readFile(br ? f + '.br' : f, (err, data) => {
    if (err) { res.writeHead(404); return res.end(); }
    res.writeHead(200, {
      'Content-Type': types[path.extname(f)] || 'application/octet-stream',
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
      'Cross-Origin-Resource-Policy': 'same-origin',
      'Cache-Control': hashed ? 'public, max-age=31536000, immutable' : 'no-cache',
      ...(br ? { 'Content-Encoding': 'br', 'Vary': 'Accept-Encoding' } : {}),
    });
    res.end(data);
  });
}).listen(port, '127.0.0.1', () => console.log(`http://127.0.0.1:${port}/`));
