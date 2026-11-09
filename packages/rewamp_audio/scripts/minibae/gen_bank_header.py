#!/usr/bin/env python3
"""Génère third_party/minibae/rewamp_minibae_bank.h depuis banks/patches111.hsb.

La banque « Beatnik Standard » est embarquée dans le binaire: un RMF ne porte
que les instruments qu'il redéfinit, le reste vient de cette banque GM.
Tableau DÉCIMAL et non littéral de chaîne: MSVC plafonne un littéral à 64 Ko.

Usage: python3 -I scripts/minibae/gen_bank_header.py   (depuis packages/rewamp_audio)
"""
import os, sys

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..',
                    'third_party', 'minibae')
src = os.path.join(root, 'banks', 'patches111.hsb')
dst = os.path.join(root, 'rewamp_minibae_bank.h')
data = open(src, 'rb').read()
with open(dst, 'w', newline='\n') as f:
    f.write('// GÉNÉRÉ par scripts/minibae/gen_bank_header.py depuis '
            'banks/patches111.hsb — ne pas éditer.\n')
    f.write('#ifndef REWAMP_MINIBAE_BANK_H\n#define REWAMP_MINIBAE_BANK_H\n')
    f.write(f'#define REWAMP_MINIBAE_BANK_SIZE {len(data)}u\n')
    f.write('static const unsigned char kRewampMinibaeBank[] = {\n')
    for i in range(0, len(data), 40):
        f.write(','.join(str(b) for b in data[i:i + 40]) + ',\n')
    f.write('};\n#endif\n')
print(f'{dst}: {len(data)} octets embarqués')
