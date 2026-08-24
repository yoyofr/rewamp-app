#!/usr/bin/env python3
"""Parse a TIATracker-exported <song>_trackdata.asm + _variables.asm into the
flat VCS tables, and run the reference player (transcribed from the Apache-2.0
tt_player.asm) to produce a per-frame register trace.

This is the ORACLE: the data comes straight out of the original tracker's
exporter, so any disagreement with our JSON pipeline is our bug.
"""
import re, sys, json


def parse_variables(path):
    v = {}
    for line in open(path):
        line = line.split(';')[0]
        m = re.match(r'\s*(TT_[A-Z_]+)\s*=\s*(\d+)', line)
        if m:
            v[m.group(1)] = int(m.group(2))
    return v


def _bytes_after(txt, label, stop_labels):
    """Collect dc.b byte values following `label:` up to the next label."""
    i = txt.index(label + ':') + len(label) + 1
    end = len(txt)
    for s in stop_labels:
        j = txt.find(s + ':', i)
        if j != -1:
            end = min(end, j)
    seg = txt[i:end]
    out = []
    for line in seg.splitlines():
        line = line.split(';')[0]
        m = re.search(r'dc\.b\s+(.*)', line)
        if not m:
            continue
        for tok in m.group(1).split(','):
            tok = tok.strip()
            if not tok:
                continue
            if tok.startswith('$'):
                out.append(int(tok[1:], 16))
            elif tok.startswith('%'):
                out.append(int(tok[1:], 2))
            elif re.match(r'^\d+$', tok):
                out.append(int(tok))
            else:  # symbolic (TT_INS_HOLD etc.)
                out.append({'TT_INS_HOLD': 8, 'TT_INS_PAUSE': 16}.get(tok, None))
    return out


LABELS = ['tt_InsCtrlTable', 'tt_InsADIndexes', 'tt_InsSustainIndexes',
          'tt_InsReleaseIndexes', 'tt_InsFreqVolTable', 'tt_PercIndexes',
          'tt_PercFreqTable', 'tt_PercCtrlVolTable', 'tt_PatternPtrLo',
          'tt_PatternPtrHi', 'tt_SequenceTable', 'tt_PatternSpeeds']


def _strip_comments(txt):
    # Labels are also mentioned inside the comment blocks ("; - tt_InsADIndexes:
    # the index ..."), and those mentions come FIRST in the file — searching the
    # raw text finds the comment, not the label, and every table parses empty.
    return '\n'.join(line.split(';')[0] for line in txt.splitlines())


def parse_trackdata(path):
    txt = _strip_comments(open(path).read())
    pat_labels = re.findall(r'^(tt_pattern\d+)\b', txt, re.M)
    stops = LABELS + pat_labels + ['tt_TrackDataStart']
    d = {}
    for lab in LABELS:
        if lab + ':' in txt:
            d[lab] = _bytes_after(txt, lab, [s for s in stops if s != lab])
    # patterns, in tt_PatternPtrLo order (the ptr tables list them by index)
    order = re.findall(r'dc\.b\s+#<(tt_pattern\d+)', txt)
    if not order:
        order = sorted(set(pat_labels), key=lambda s: int(s[len('tt_pattern'):]))
    d['patterns'] = [_bytes_after(txt, p, [s for s in stops if s != p]) for p in order]
    d['pattern_names'] = order
    d['sequence'] = d['tt_SequenceTable']
    return d


def parse_init(path):
    """<song>_init.asm holds the authoritative sequence start index of each
    channel (channel 1 starts partway into the shared tt_SequenceTable)."""
    starts, pending = [0, 0], None
    for line in _strip_comments(open(path).read()).splitlines():
        m = re.search(r'lda\s+#(\d+)', line)
        if m:
            pending = int(m.group(1))
        m = re.search(r'sta\s+tt_cur_pat_index_c([01])', line)
        if m and pending is not None:
            starts[int(m.group(1))] = pending
    return starts


class Player:
    """Frame-accurate transcription of tt_player.asm (Apache-2.0,
    Copyright 2016 Andre "Kylearan" Wichmann)."""

    def __init__(self, d, v, starts):
        self.d, self.v = d, v
        self.seq = d['sequence']
        self.timer = 0
        # tt_init.asm: channel 0 starts at sequence index 0, channel 1 at the
        # start of its own sub-track.
        self.cur_pat_index = list(starts)
        self.cur_note_index = [0, 0]
        self.cur_ins = [0, 0]
        self.env_index = [0, 0]
        self.audc = [0, 0]
        self.audf = [0, 0]
        self.audv = [0, 0]

    def fetch_note(self, x):
        """TT_FETCH_CURRENT_NOTE. Returns (note, prefetched)."""
        while True:
            p = self.seq[self.cur_pat_index[x]]
            if self.v.get('TT_USE_GOTO') and p >= 128:
                self.cur_pat_index[x] = p & 0x7f
                continue
            prefetched = False
            ni = self.cur_note_index[x]
            if self.v.get('TT_USE_OVERLAY'):
                if ni & 0x80:
                    ni &= 0x7f
                    self.cur_note_index[x] = ni
                    prefetched = True
            note = self.d['patterns'][p][ni]
            if note != 0:
                return note, prefetched
            # end of pattern -> next pattern in the sequence
            self.cur_note_index[x] = 0
            self.cur_pat_index[x] += 1

    def frame(self):
        self.timer -= 1
        if self.timer < 0:
            for x in (1, 0):
                note, prefetched = self.fetch_note(x)
                if note < 16:                       # slide / hold
                    if self.v.get('TT_USE_SLIDE'):
                        self.cur_ins[x] = (self.cur_ins[x] + note - 8) & 0xff
                elif note == 16:                    # pause -> release
                    ins = self.cur_ins[x] >> 5
                    self.env_index[x] = self.d['tt_InsReleaseIndexes'][ins - 1] + 1
                else:                               # new note
                    self.cur_ins[x] = note
                    if note < 32:                   # percussion
                        self.env_index[x] = self.d['tt_PercIndexes'][note - 17]
                    else:                           # melodic instrument
                        if not prefetched:
                            self.env_index[x] = self.d['tt_InsADIndexes'][(note >> 5) - 1]
                self.cur_note_index[x] += 1
            # reset the speed timer
            if self.v.get('TT_GLOBAL_SPEED'):
                spd = self.v['TT_SPEED']
                if self.v.get('TT_USE_FUNKTEMPO') and (self.cur_note_index[0] & 1):
                    spd = self.v['TT_ODD_SPEED']
                self.timer = spd - 1
            else:
                y = self.seq[self.cur_pat_index[0]]
                b = self.d['tt_PatternSpeeds'][y]
                if self.v.get('TT_USE_FUNKTEMPO'):
                    self.timer = (b & 0x0f) if (self.cur_note_index[0] & 1) else (b >> 4)
                else:
                    self.timer = b

        for x in (1, 0):
            ins = self.cur_ins[x]
            if ins == 0:
                continue
            if ins < 32:
                # --- percussion ---
                y = self.env_index[x]
                a = self.d['tt_PercCtrlVolTable'][y - 1]
                if a != 0:
                    self.env_index[x] += 1
                self.audv[x] = a & 0x0f
                self.audc[x] = (a >> 4) & 0x0f
                f = self.d['tt_PercFreqTable'][y - 1]
                self.audf[x] = f & 0x1f
                if self.v.get('TT_USE_OVERLAY') and (f & 0x80):
                    note, _ = self.fetch_note(x)
                    if note >= 32:
                        self.cur_ins[x] = note
                        self.env_index[x] = self.d['tt_InsSustainIndexes'][(note >> 5) - 1]
                        self.cur_note_index[x] |= 0x80
            else:
                # --- melodic instrument ---
                i = ins >> 5
                self.audc[x] = self.d['tt_InsCtrlTable'][i - 1] & 0x0f
                y = self.env_index[x]
                if y == self.d['tt_InsReleaseIndexes'][i - 1]:
                    y = self.d['tt_InsSustainIndexes'][i - 1]
                a = self.d['tt_InsFreqVolTable'][y]
                if a != 0:
                    y += 1
                self.env_index[x] = y
                self.audv[x] = a & 0x0f
                self.audf[x] = (((a >> 4) + ins - 8) & 0xff) & 0x1f
        return (self.audc[0], self.audf[0], self.audv[0],
                self.audc[1], self.audf[1], self.audv[1])


def trace(song, frames):
    d = parse_trackdata(f'gold/{song}_trackdata.asm')
    v = parse_variables(f'gold/{song}_variables.asm')
    s = parse_init(f'gold/{song}_init.asm')
    p = Player(d, v, s)
    return [p.frame() for _ in range(frames)]


if __name__ == '__main__':
    song = sys.argv[1] if len(sys.argv) > 1 else 'Miniblast'
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 200
    if len(sys.argv) > 3 and sys.argv[3] == '--dump':
        d = parse_trackdata(f"gold/{song}_trackdata.asm")
        v = parse_variables(f'gold/{song}_variables.asm')
        print('vars', v)
        for k in LABELS:
            if k in d:
                print(k, [hex(x) for x in d[k]][:40])
        print('n patterns', len(d['patterns']), 'seq_c0_len', d['seq_c0_len'],
              'seq', [hex(x) for x in d['sequence']])
        sys.exit()
    for i, t in enumerate(trace(song, n)):
        print(i, ' '.join('%2d' % x for x in t))
