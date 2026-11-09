// AudioWorklet: lit l'anneau de sortie du moteur EN PLACE dans la mémoire wasm
// (SharedArrayBuffer). Disposition de l'en-tête: src/web/rewamp_device_web.h.
// Jamais d'attente ici (Atomics.wait interdit): données absentes = silence.
const H_WRITE = 0, H_READ = 1, H_CAP = 2, H_STARTED = 5, H_UNDER = 6, H_DATA = 7;
class RewampOut extends AudioWorkletProcessor {
  constructor(o) {
    super();
    const { buffer, ring } = o.processorOptions;
    this.h = new Int32Array(buffer, ring, 8);
    this.cap = this.h[H_CAP];
    this.f = new Float32Array(buffer, ring + this.h[H_DATA], this.cap * 2);
  }
  process(_, outputs) {
    const [L, R] = outputs[0], n = L.length, h = this.h, mask = this.cap - 1, f = this.f;
    const w = Atomics.load(h, H_WRITE), r = Atomics.load(h, H_READ);
    if (((w - r) | 0) < n) {
      L.fill(0); R.fill(0);
      if (Atomics.load(h, H_STARTED)) Atomics.add(h, H_UNDER, 1);
      return true;
    }
    for (let i = 0; i < n; i++) { const o = ((r + i) & mask) * 2; L[i] = f[o]; R[i] = f[o + 1]; }
    Atomics.store(h, H_READ, (r + n) | 0);
    Atomics.notify(h, H_READ);
    return true;
  }
}
registerProcessor('rewamp-out', RewampOut);
