// Fichiers dépliés sur DISQUE (OPFS), lus à la demande — chargé par engine-worker.js.
//
// Un album dépliée tenait ENTIER en mémoire (MEMFS): 297 Mo pour Ace Combat 5,
// 533 pour Ace Combat 4, pour n'en jouer qu'une piste à la fois. Ici chaque
// fichier sorti de l'archive est écrit dans l'Origin Private File System, puis
// monté dans le FS du moteur comme un nœud PARESSEUX: sa taille est connue, ses
// octets sont lus sur le disque au moment où le décodeur les demande (poignée
// d'accès SYNCHRONE, qui n'existe que dans un Worker dédié — c'est le cas: le FS
// du module vit sur ce fil, les lectures des pthreads y sont relayées).
//
// L'album reste sur le disque après usage: un rechargement de la page le
// remonte sans retélécharger ni redéplier (op `restore`). Au-delà d'un plafond
// (une part du quota), les albums les moins récemment montés sont évincés.
//
// Absent (vieux navigateur, navigation privée de Firefox, Safari < 16.4 dont la
// poignée synchrone est bancale), plein, ou verrouillé par un autre onglet:
// chaque fichier retombe en MÉMOIRE, comme avant. OPFS n'est jamais une condition
// pour jouer.
//
// Disposition: <racine OPFS>/rewamp-x/<clé du dossier>/{0,1,2…, _meta.json};
// les fichiers portent un NUMÉRO (un nom d'archive peut dépasser ce qu'OPFS
// accepte), _meta.json les nomme et n'est écrit qu'À LA FIN — un dossier sans
// lui est une écriture interrompue, effacée au démarrage suivant.
'use strict';

const OpfsStore = (() => {
  const META = '_meta.json';
  const keyOf = dest => encodeURIComponent(dest);
  let M = null, root = null, cap = 0, lazyOps = null, tmp = new Uint8Array(1 << 20);
  const index = new Map();     // clé → { bytes, used } (dossiers COMPLETS sur disque)
  const mounted = new Map();   // dest → [poignées ouvertes]
  const say = s => postMessage({ type: 'print', s: '[opfs] ' + s });

  async function writeText(dir, name, text) {
    const h = await (await dir.getFileHandle(name, { create: true })).createSyncAccessHandle();
    try { const b = new TextEncoder().encode(text); h.truncate(0); h.write(b, { at: 0 }); h.flush(); } finally { h.close(); }
  }
  async function readMeta(dir) {
    try { return JSON.parse(await (await (await dir.getFileHandle(META)).getFile()).text()); } catch { return null; }
  }
  const total = () => { let t = 0; for (const v of index.values()) t += v.bytes; return t; };

  // Les moins récemment montés d'abord, jamais un dossier monté en ce moment.
  async function evict(need) {
    const busy = new Set([...mounted.keys()].map(keyOf));
    const lru = [...index.entries()].filter(([k]) => !busy.has(k)).sort((a, b) => a[1].used - b[1].used);
    for (const [k, v] of lru) {
      if (total() + need <= cap) break;
      try { await root.removeEntry(k, { recursive: true }); index.delete(k); say(`évincé ${decodeURIComponent(k)} (${(v.bytes / 1e6).toFixed(0)} Mo)`); } catch {}
    }
  }

  // Lecture d'un nœud paresseux: par tranches de 4 Mo au plus, via un tampon
  // NON partagé (la mémoire wasm est un SharedArrayBuffer, que la poignée peut refuser).
  // ⚠️ Une exception JS qui n'est pas une ErrnoError, ici, ne remonte PAS au C:
  // l'appel relayé depuis un pthread ne se termine jamais, ce fil reste bloqué
  // en tenant le verrou du décodeur, et tout le moteur gèle. Toute erreur de
  // la poignée (fermée, disque) devient donc un EIO.
  function lazyRead(stream, buffer, offset, length, position) {
    const node = stream.node;
    let n = Math.min(length, node.usedBytes - position), done = 0;
    if (n <= 0) return 0;
    try {
      while (done < n) {
        const want = Math.min(n - done, 4 << 20);
        if (tmp.length < want) tmp = new Uint8Array(want);
        const got = node.opfs.read(tmp.subarray(0, want), { at: position + done });
        if (got <= 0) break;
        new Uint8Array(buffer.buffer, buffer.byteOffset + offset + done, got).set(tmp.subarray(0, got));
        done += got;
      }
    } catch (err) {
      say(`lecture refusée ${node.name} @${position + done}: ${err?.name || ''} ${err?.message || err}`);
      if (done) return done;
      throw new M.FS.ErrnoError(29);   // EIO
    }
    return done;
  }

  // Nœud du FS du moteur dont les octets restent sur le disque.
  function lazyNode(path, h, size, mkdirs) {
    mkdirs(path);
    try { M.FS.unlink(path); } catch {}
    M.FS.writeFile(path, new Uint8Array(0));
    const node = M.FS.lookupPath(path).node;
    if (!lazyOps) { const base = node.stream_ops; lazyOps = Object.assign({}, base, {
      // Compte des ouvertures: un dossier relâché pendant qu'un décodeur lit
      // encore un de ses fichiers (piste quittée, suivante préparée) ne ferme
      // la poignée qu'à la DERNIÈRE fermeture — comme un fichier MEMFS effacé
      // reste lisible tant qu'il est ouvert.
      open(stream) { stream.node.opens = (stream.node.opens || 0) + 1; base.open?.(stream); },
      close(stream) {
        const nd = stream.node; base.close?.(stream);
        if (--nd.opens <= 0 && nd.closeLater) { nd.closeLater = false; try { nd.opfs.close(); } catch {} }
      },
      read: lazyRead,
      write() { throw new M.FS.ErrnoError(63); },   // EPERM: un fichier d'archive ne s'écrit pas
      mmap() { throw new M.FS.ErrnoError(43); },    // ENODEV
    }); }
    node.contents = null; node.usedBytes = size; node.opfs = h; node.stream_ops = lazyOps;
    return node;
  }
  // Ferme la poignée d'un nœud, ou à sa dernière fermeture s'il est ouvert.
  function release(e) {
    if (e.node && e.node.opens > 0) e.node.closeLater = true;
    else try { e.h.close(); } catch {}
  }

  return {
    get ready() { return !!root; },

    async init(module) {
      M = module;
      try {
        if (!navigator.storage?.getDirectory || !self.FileSystemFileHandle?.prototype.createSyncAccessHandle) return;
        const top = await navigator.storage.getDirectory();
        root = await top.getDirectoryHandle('rewamp-x', { create: true });
        const est = await navigator.storage.estimate?.().catch(() => null);
        cap = Math.max(256 << 20, Math.min(4 * 2 ** 30, (est?.quota || 2 ** 31) * 0.25));
        for await (const [k, h] of root.entries()) {
          if (h.kind !== 'directory') continue;
          const meta = await readMeta(h);
          if (meta) index.set(k, { bytes: meta.bytes, used: meta.used || 0 });
          else await root.removeEntry(k, { recursive: true }).catch(() => {});   // écriture interrompue
        }
        say(`prêt: ${index.size} dossiers, ${(total() / 1e6).toFixed(0)} Mo sur ${(cap / 1e6).toFixed(0)} Mo permis`);
      } catch (err) { root = null; say('indisponible: ' + (err?.message || err)); }
    },

    // Début d'un dépliage vers `dest` (taille estimée: celle de l'archive).
    async begin(dest, estimate) {
      if (!root) return null;
      try {
        const k = keyOf(dest);
        if (index.has(k)) { await root.removeEntry(k, { recursive: true }).catch(() => {}); index.delete(k); }
        await evict(estimate * 1.2);
        const dir = await root.getDirectoryHandle(k, { create: true });
        const w = { dest, k, dir, files: [], bytes: 0, broken: false, handles: [] };
        mounted.set(dest, w.handles);
        return w;
      } catch { return null; }
    },

    // Écrit UN fichier et le monte; false = au disque de refuser (quota, nom):
    // l'appelant le garde en mémoire, et le dossier ne sera pas restaurable.
    async put(w, rel, u8, mkdirs) {
      if (!w || w.broken) return false;
      let h = null;
      try {
        const i = w.files.length;
        h = await (await w.dir.getFileHandle(String(i), { create: true })).createSyncAccessHandle();
        if (h.write(u8, { at: 0 }) !== u8.length) throw new Error('écriture courte');
        h.flush();
        w.files.push([rel, u8.length]); w.bytes += u8.length;
        w.handles.push({ h, node: lazyNode(w.dest + '/' + rel, h, u8.length, mkdirs) });
        return true;
      } catch (err) {
        try { h?.close(); } catch {}
        w.broken = true; say(`écriture refusée (${err?.message || err}): le reste en mémoire`);
        return false;
      }
    },

    async finish(w) {
      if (!w || w.broken || !w.files.length) return;
      const meta = { files: w.files, bytes: w.bytes, used: Date.now() };
      try { await writeText(w.dir, META, JSON.stringify(meta)); index.set(w.k, { bytes: w.bytes, used: meta.used }); }
      catch { w.broken = true; }
    },

    // Dépliage raté: on efface ce qui a été écrit.
    async abort(w) {
      if (!w) return;
      for (const e of w.handles) release(e);
      mounted.delete(w.dest);
      await root.removeEntry(w.k, { recursive: true }).catch(() => {});
    },

    // Remonte un dossier déjà sur le disque. true = ses fichiers sont dans le FS.
    async restore(dest, mkdirs) {
      if (!root) return false;
      const k = keyOf(dest), entry = index.get(k);
      if (!entry) return false;
      try {
        const dir = await root.getDirectoryHandle(k);
        const meta = await readMeta(dir);
        if (!meta) throw new Error('méta illisible');
        const handles = [];
        mounted.set(dest, handles);
        for (let i = 0; i < meta.files.length; i++) {
          const [rel, size] = meta.files[i];
          const fh = await dir.getFileHandle(String(i));
          try {
            const h = await fh.createSyncAccessHandle();   // verrou exclusif: un autre onglet peut le tenir
            handles.push({ h, node: lazyNode(dest + '/' + rel, h, size, mkdirs) });
          } catch {
            const b = new Uint8Array(await (await fh.getFile()).arrayBuffer());
            const p = dest + '/' + rel; mkdirs(p); M.FS.writeFile(p, b, { canOwn: true });
          }
        }
        meta.used = Date.now(); entry.used = meta.used;
        writeText(dir, META, JSON.stringify(meta)).catch(() => {});
        say(`remonté ${dest}: ${meta.files.length} fichiers, ${(meta.bytes / 1e6).toFixed(0)} Mo, sans téléchargement`);
        return true;
      } catch (err) {
        this.unmount(dest);
        index.delete(k); await root.removeEntry(k, { recursive: true }).catch(() => {});
        say(`remontage impossible (${err?.message || err}): dossier effacé`);
        return false;
      }
    },

    // Le dossier quitte le FS du moteur: on lâche les poignées, le disque garde
    // les fichiers (sauf un dossier incomplet, qu'on ne saurait pas remonter).
    unmount(dest) {
      const hs = mounted.get(dest);
      if (!hs) return;
      for (const e of hs) release(e);
      mounted.delete(dest);
      const k = keyOf(dest);
      if (!index.has(k)) root?.removeEntry(k, { recursive: true }).catch(() => {});
    },
    // Dossiers montés sous `dir` (drop d'un dossier parent).
    unmountUnder(dir) { for (const d of [...mounted.keys()]) if (d === dir || d.startsWith(dir + '/')) this.unmount(d); },

    stats() {
      let open = 0, bytes = 0;
      for (const [d, hs] of mounted) { open += hs.length; const e = index.get(keyOf(d)); if (e) bytes += e.bytes; }
      return { ready: !!root, dirs: index.size, disk: total(), mountedBytes: bytes, open, cap };
    },
  };
})();
