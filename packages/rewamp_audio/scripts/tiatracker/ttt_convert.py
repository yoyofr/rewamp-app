#!/usr/bin/env python3
"""Prototype of the .ttt (JSON) -> VCS tables conversion, checked against the
tracker's OWN exported trackdata.asm.

Comparison is semantic, not byte-for-byte: the exporter renumbers instruments
(only the used ones, and a "Pure Combined" instrument becomes two), so table
INDEXES differ. What must match is what each pattern row actually plays:
(kind, AUDC waveform, frequency) for a melodic note, (kind, percussion frames)
for a percussion, and the commands.
"""
import json, sys, collections
import gold_parse

HOLD, INSTRUMENT, PAUSE, PERCUSSION, SLIDE = 0, 1, 2, 3, 4
COMBINED = 16          # "Pure Combined (4+12)" pseudo-waveform
COMBINED_PAIR = (4, 12)


def load_json(path):
    return json.load(open(path))


def trim_envelope(vols, freqs, length, sustain_start, release_start):
    """The tracker's editor keeps trailing zero-volume frames; the exporter
    drops them. That is not cosmetic: the VCS release phase is terminated by a
    literal $00 byte, and a "volume 0, no pitch change" frame encodes as $80,
    so keeping those frames would run the envelope index off the end of the
    instrument. The release keeps at least one frame."""
    n = length
    while n > release_start + 1 and vols[n - 1] == 0:
        n -= 1
    return tuple(vols[:n]), tuple(freqs[:n]), n, sustain_start, release_start


def decode_json_rows(d, combined_low_first):
    """Normalized rows per pattern, straight from the .ttt."""
    out = []
    for pat in d['patterns']:
        rows = []
        for n in pat['notes']:
            t, num, val = n['type'], n['number'], n['value']
            if t == HOLD:
                rows.append(('hold',))
            elif t == PAUSE:
                rows.append(('pause',))
            elif t == SLIDE:
                # JSON stores the signed amount (-7..+7); the note byte is
                # amount + 8, which is what the player subtracts back out.
                rows.append(('slide', val + 8))
            elif t == PERCUSSION:
                perc = d['percussion'][num]
                rows.append(('perc', tuple(perc['waveforms']), tuple(perc['frequencies']),
                             tuple(perc['volumes']), perc['overlay']))
            elif t == INSTRUMENT:
                ins = d['instruments'][num]
                wf = ins['waveform']
                if wf == COMBINED:
                    lo, hi = COMBINED_PAIR if combined_low_first else COMBINED_PAIR[::-1]
                    wf, freq = (lo, val) if val < 32 else (hi, val - 32)
                else:
                    freq = val
                rows.append(('ins', wf, freq) + trim_envelope(
                    ins['volumes'], ins['frequencies'], ins['envelopeLength'],
                    ins['sustainStart'], ins['releaseStart']))
            else:
                rows.append(('?%d' % t, num, val))
        out.append(rows)
    return out


def decode_gold_rows(g):
    """Same normalized rows, decoded out of the exported tables."""
    ins_ctrl = g['tt_InsCtrlTable']
    ad, sus, rel = g['tt_InsADIndexes'], g['tt_InsSustainIndexes'], g['tt_InsReleaseIndexes']
    fv = g['tt_InsFreqVolTable']
    pidx, pfreq, pcv = g['tt_PercIndexes'], g['tt_PercFreqTable'], g['tt_PercCtrlVolTable']

    def ins_env(i):
        """(volumes, freq modifiers, length, sustainStart, releaseStart) as the
        tracker's editor would show them."""
        a, s, r = ad[i], sus[i], rel[i] + 1        # release index is stored -1
        vols, freqs = [], []
        j = a
        while True:
            b = fv[j]
            if j == rel[i]:                        # the junk byte between S and R
                j += 1
                continue
            if b == 0 and j >= r:                  # 0 terminates the release
                break
            vols.append(b & 0x0f)
            freqs.append((b >> 4) - 8)
            j += 1
            if j >= len(fv):
                break
        return tuple(vols), tuple(freqs), len(vols), s - a, r - a - 1

    def perc_frames(k):
        start = pidx[k] - 1                        # stored +1
        wf, fr, vol = [], [], []
        j = start
        while pcv[j] != 0:
            wf.append((pcv[j] >> 4) & 0x0f)
            vol.append(pcv[j] & 0x0f)
            fr.append(pfreq[j] & 0x1f)
            j += 1
        overlay = any(pfreq[i] & 0x80 for i in range(start, j))
        return tuple(wf), tuple(fr), tuple(vol), overlay

    out = []
    for pat in g['patterns']:
        rows = []
        for b in pat:
            if b == 0:
                break
            if b == 8:
                rows.append(('hold',))
            elif b < 16:
                rows.append(('slide', b))
            elif b == 16:
                rows.append(('pause',))
            elif b < 32:
                rows.append(('perc',) + perc_frames(b - 17))
            else:
                i, freq = (b >> 5) - 1, b & 0x1f
                v, f, ln, ss, rs = ins_env(i)
                rows.append(('ins', ins_ctrl[i] & 0x0f, freq, v, f, ln, ss, rs))
        out.append(rows)
    return out


def compare(song, combined_low_first):
    d = load_json(f'gold/{song}.ttt')
    g = gold_parse.parse_trackdata(f'gold/{song}_trackdata.asm')
    mine = decode_json_rows(d, combined_low_first)
    theirs = decode_gold_rows(g)
    # the exporter drops unused patterns, so match ours INTO theirs
    pool = collections.Counter(tuple(p) for p in theirs)
    matched, missing = 0, []
    for i, p in enumerate(mine):
        key = tuple(p)
        if pool[key] > 0:
            pool[key] -= 1
            matched += 1
        else:
            missing.append(i)
    return matched, len(theirs), missing, mine, theirs


if __name__ == '__main__':
    songs = sys.argv[1:] or ['Miniblast', 'Beside', 'Speedtest', 'Salami', 'Tetris-A', 'heckno2']
    for song in songs:
        for clf in (True, False):
            m, t, miss, mine, theirs = compare(song, clf)
            print(f'{song:10s} combined_low_first={clf!s:5s} matched {m}/{t} exported'
                  + (f'  unmatched json patterns: {miss[:6]}' if miss else ''))
