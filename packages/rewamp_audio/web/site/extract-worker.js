// Worker JETABLE de dépliage: un par archive, détruit par engine-worker.js dès
// qu'il a rendu les fichiers. Déplier un gros 7z fait grandir la mémoire wasm
// des tampons de décompression (64 → 303 Mo pour un album PSF2 de 292 Mo), et
// une mémoire wasm ne rétrécit jamais: dans le module du moteur, ce pic restait
// réservé jusqu'à la fermeture de l'onglet. Ici il part avec le Worker.
//
// Protocole (un seul message dans chaque sens):
//   ← { buf: ArrayBuffer, off, len }            l'archive (transférée, pas copiée)
//   → { file: { rel, buf } }                    UN par fichier, dès qu'il est sorti
//                                               (octets transférés): le moteur
//                                               l'écrit sur disque et le lâche
//   → { ok: true, n }                           fin
//   → { ok: false, error, rc?, buf?, off?, len? } rc = échec de libarchive (archive
//                                               illisible); l'archive est RENDUE
//                                               quand on l'a encore, pour un repli.
const B = (() => { const x = new XMLHttpRequest(); x.open('GET', 'dist/build.json', false); x.send(); return JSON.parse(x.responseText); })();
importScripts('dist/' + B.extractJs);

onmessage = async e => {
  let { buf, off, len } = e.data;
  const fail = (error, rc) => {
    const back = buf ? { buf, off, len } : {};
    postMessage({ ok: false, error: String(error), rc, ...back }, buf ? [buf] : []);
  };
  // Chaque fichier arrive dans UN tampon à sa taille exacte (rewamp_extract_main.c):
  // pas de fichier MEMFS qui grandit par recopies, pas de relecture — et il part
  // aussitôt: ce Worker ne tient jamais plus d'un fichier dépliée à la fois.
  let n = 0, cur = null;
  const hooks = {
    onBegin(rel, size) { cur = { rel, a: new Uint8Array(size >= 0 ? size : 1 << 20), n: 0 }; },
    onBlock(v, off) {
      if (!cur) return;
      const end = off + v.length;
      if (end > cur.a.length) { const b = new Uint8Array(Math.max(end, cur.a.length * 2)); b.set(cur.a.subarray(0, cur.n)); cur.a = b; }
      cur.a.set(v, off);
      if (end > cur.n) cur.n = end;
    },
    onEnd() {
      if (!cur) return;
      const a = cur.n === cur.a.length ? cur.a : cur.a.slice(0, cur.n);
      postMessage({ file: { rel: cur.rel, buf: a.buffer } }, [a.buffer]); cur = null; n++;
    },
  };
  let M;
  try {
    M = await RewampExtract({ print() {}, printErr() {}, ...hooks,
      locateFile: p => 'dist/' + (p.endsWith('.wasm') ? B.extractWasm : p) });
  } catch (err) { return fail(err?.message || err); }
  try {
    M.FS.mkdir('/in');
    // canOwn: MEMFS garde CETTE vue au lieu de copier l'archive.
    M.FS.writeFile('/in/a', new Uint8Array(buf, off, len), { canOwn: true });
    const rc = M.ccall('rewamp_extract_to_js', 'number', ['string'], ['/in/a']);
    if (rc !== 0) return fail(`extraction ${rc}: ${M.ccall('rewamp_extract_js_last_error', 'string', [], [])}`, rc);
    M.FS.unlink('/in/a'); buf = null;   // l'archive n'est plus rendue: elle est dépliée
    postMessage({ ok: true, n });
  } catch (err) { fail(err?.message || err); }
};
