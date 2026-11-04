#!/usr/bin/env python3
"""Génère l'en-tête de RENOMMAGE d'une bibliothèque FM-MIDI (libADLMIDI,
libOPNMIDI) à partir des symboles qu'elle DÉFINIT réellement.

Pourquoi: ces bibliothèques posent au niveau global des noms que d'autres
cœurs embarqués portent aussi (Nuked OPL3 d'AdPlug: OPL3_*; esfmu de Furnace:
ESFM_*; YMFM de pmdmini: namespace ymfm), et les deux entre elles (MIDIplay,
BW_MidiSequencer…). L'éditeur de liens FUSIONNE en silence (ODR). Comme pour
furnace_chip_rename.h, un en-tête injecté AVANT chaque TU de la bibliothèque
préfixe tous ses noms de premier niveau; aucun fichier amont n'est modifié.

Seule l'API C publique (préfixe donné, ex. « adl_ ») garde son nom: c'est
elle que le greffon appelle.

Usage:  nm -gU libADLMIDI.a | gen_fm_midi_rename.py --api adl_ --prefix rwadl_ \\
            --guard REWAMP_ADLMIDI_RENAME_H > adlmidi_rename.h
Re-générer à chaque resynchro de la bibliothèque (nouveaux noms possibles),
puis vérifier au symbole: check_fm_midi_symbols.sh.
"""
import argparse, re, subprocess, sys

ap = argparse.ArgumentParser()
ap.add_argument("--api", required=True)
ap.add_argument("--prefix", required=True)
ap.add_argument("--guard", required=True)
ap.add_argument("--lib", required=True)
a = ap.parse_args()

syms = set()
for line in sys.stdin:
    parts = line.split()
    if len(parts) == 3:
        syms.add(parts[2])

def strip_us(s):
    return s[1:] if s.startswith("_") else s

c_names, cpp_mangled = set(), []
for s in syms:
    n = strip_us(s)
    if n.startswith("_Z"):
        cpp_mangled.append(s)
    else:
        c_names.add(n)

demangled = subprocess.run(["c++filt"], input="\n".join(cpp_mangled),
                           capture_output=True, text=True).stdout.splitlines()
top = set()
for d in demangled:
    d = re.sub(r"^(typeinfo name for |typeinfo for |vtable for |"
               r"non-virtual thunk to |guard variable for |VTT for )", "", d)
    # Le PREMIER identifiant suivi de « :: », « < » ou « ( » est le nom de
    # premier niveau (un type de retour, lui, est suivi d'une espace).
    m = re.search(r"([A-Za-z_]\w*)\s*(?=<|::|\()", d)
    if m:
        top.add(m.group(1))

skip = {"std", "__cxxabiv1", "operator"}
names = sorted((c_names | top) - skip)
names = [n for n in names
         if not n.startswith(a.api) or n in top and n not in c_names]
names = [n for n in names if not n.startswith("__") and n != "__clang_call_terminate"]
# L'API C publique est extern "C": un nom à son préfixe ET non mangé reste.
names = [n for n in names if not (n.startswith(a.api) and n in c_names)]

print(f"""/* GÉNÉRÉ par packages/rewamp_audio/scripts/gen_fm_midi_rename.py — ne pas
 * éditer à la main. Injecté AVANT chaque TU de {a.lib} (cmake: -include / /FI;
 * Apple: les wrappers du podspec l'incluent en premier). Préfixe {a.prefix} sur
 * tous les noms de premier niveau de la bibliothèque, sauf l'API C publique
 * ({a.api}*): voir l'en-tête du script pour le pourquoi. */
#ifndef {a.guard}
#define {a.guard}
""")
for n in names:
    print(f"#define {n} {a.prefix}{n}")
print(f"#endif /* {a.guard} */")
