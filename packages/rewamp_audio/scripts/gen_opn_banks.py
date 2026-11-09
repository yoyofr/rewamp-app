#!/usr/bin/env python3
"""Génère third_party/libopnmidi/rewamp/opnmidi_banks.c: les banques WOPN
livrées par libOPNMIDI (fm_banks/), EMBARQUÉES dans le binaire — la
bibliothèque n'en embarque aucune (contrairement à libADLMIDI), et un fichier
d'asset ne servirait pas la ligne de commande ni les harnais.

Ordre = index du paramètre moteur "opnmidi"/"bank" (persisté: on AJOUTE en
fin, on ne réordonne jamais). Re-générer après une resynchro:
    scripts/gen_opn_banks.py
"""
import os

pkg = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
root = os.path.join(pkg, "third_party", "libopnmidi")
BANKS = [  # (fichier, nom affiché)
    ("xg.wopn", "XG (Wohlstand)"),
    ("gm-old.wopn", "GM, old (Wohlstand)"),
    ("gs-by-papiezak-and-sneakernets.wopn", "GS / DMXOPN2 (papiezak, sneakernets)"),
    ("gems-fmlib-gmize.wopn", "GEMS fmlib, GM-ized"),
    ("Tomsoft.wopn", "Tomsoft SegaMusic"),
    ("Nineko.wopn", "Nineko (MIDI2VGM)"),
    ("fmmidi.wopn", "fmmidi"),
]
out = ["/* GÉNÉRÉ par packages/rewamp_audio/scripts/gen_opn_banks.py — ne pas",
       " * éditer à la main. Banques WOPN de libOPNMIDI fm_banks/ (licences: voir",
       " * fm_banks/*readme*.txt). */",
       "#include <stddef.h>", ""]
for i, (f, _) in enumerate(BANKS):
    data = open(os.path.join(root, "fm_banks", f), "rb").read()
    out.append(f"/* {f}, {len(data)} octets */")
    out.append(f"static const unsigned char kBank{i}[{len(data)}] = {{")
    for k in range(0, len(data), 24):
        out.append("  " + ",".join(str(b) for b in data[k:k + 24]) + ",")
    out.append("};")
out.append("")
out.append("const int rewamp_opn_bank_count_v = %d;" % len(BANKS))
out.append("const char* const rewamp_opn_bank_names_v[] = {")
for _, n in BANKS:
    out.append(f'  "{n}",')
out.append("};")
out.append("const unsigned char* const rewamp_opn_bank_data_v[] = {")
out.append("  " + ", ".join(f"kBank{i}" for i in range(len(BANKS))) + ",")
out.append("};")
out.append("const size_t rewamp_opn_bank_size_v[] = {")
out.append("  " + ", ".join(f"sizeof(kBank{i})" for i in range(len(BANKS))) + ",")
out.append("};")
open(os.path.join(root, "rewamp", "opnmidi_banks.c"), "w").write("\n".join(out) + "\n")
