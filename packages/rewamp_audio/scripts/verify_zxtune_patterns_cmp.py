"""Compare deux dumps canoniques de grille (voir verify_zxtune_patterns.sh).

Une seule divergence est attendue et donc neutralisée: le PORTAMENTO, dont PT3
écrit la note cible dans le flux — libpt3 la met en colonne de note comme le
tracker, zxtune en fait le paramètre d'une commande.
"""
import os
import subprocess
import sys

KEEP = ('channels', 'order ', 'pattern ', 'c ', '# ')


def dump(binary, path):
    r = subprocess.run([binary, path], capture_output=True, text=True,
                       errors='replace')
    return [l for l in r.stdout.splitlines() if l.startswith(KEEP)]


def compare(zx_bin, pt3_bin, path):
    zl, pl = dump(zx_bin, path), dump(pt3_bin, path)
    name = os.path.basename(path)
    no_zx = any('no grid' in l or 'open failed' in l for l in zl)
    no_pt = any('no grid' in l or 'open failed' in l for l in pl)
    if no_zx or no_pt:
        state = 'les deux' if no_zx and no_pt else ('zxtune' if no_zx else 'libpt3')
        print('SANS GRILLE (%s)  %s' % (state, name))
        return no_zx != no_pt

    porta = set()
    for l in pl:
        if 'PORTA' in l:
            t = l.split()
            porta.add((t[1], t[2], t[3]))

    def strip(lines):
        out = []
        for l in lines:
            t = l.split()
            if t and t[0] == 'c' and (t[1], t[2], t[3]) in porta:
                continue
            out.append(l.replace(' PORTA', ''))
        return out

    zf, pf = strip(zl), strip(pl)
    diff = sum(1 for a, b in zip(zf, pf) if a != b) + abs(len(zf) - len(pf))
    print('%-4s cellules=%d ecarts=%d  %s' %
          ('OK' if not diff else 'DIFF', len(pf), diff, name))
    return diff != 0


def main():
    zx_bin, pt3_bin = sys.argv[1], sys.argv[2]
    bad = sum(compare(zx_bin, pt3_bin, f) for f in sys.argv[3:])
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
