#!/usr/bin/env python3
"""Compare two mode-hashes TSVs (reference, candidate).

usage: compare-hashes.py REF.tsv CAND.tsv [--names]
Prints one summary line per mode, then each input whose asm or object result
changed (with --names, or when there are at most 40 changes). Exits 1 when any
result differs, 0 when every input is identical in every mode.
Derived from build/split-320-321/spec/compare-hashes.py (modes taken from the
data; nonzero exit on difference).
"""
import sys


def load(p):
    d = {}
    for line in open(p):
        f = line.rstrip('\n').split('\t')
        d[(f[0], f[1])] = f[2:]
    return d


def main():
    if len(sys.argv) < 3 or sys.argv[1] in ('-h', '--help'):
        print(__doc__.strip())
        return 0
    a, b = load(sys.argv[1]), load(sys.argv[2])
    names = '--names' in sys.argv
    assert a.keys() == b.keys(), 'input sets differ'
    modes = sorted({k[1] for k in a}, key=lambda m: (m != 'mos6502', m))
    changed = []
    for mode in modes:
        keys = sorted(k for k in a if k[1] == mode)
        same = sum(1 for k in keys if a[k] == b[k])
        asm = sum(1 for k in keys if a[k][:2] != b[k][:2])
        obj_only = sum(1 for k in keys if a[k][:2] == b[k][:2] and a[k][2:] != b[k][2:])
        ok = sum(1 for k in keys if a[k][0] == '0')
        print(f'{mode}: {len(keys)} inputs ({ok} compile before), {same} identical, '
              f'{asm} asm differ, {obj_only} object-only differ')
        changed += [k for k in keys if a[k] != b[k]]
    if changed and (names or len(changed) <= 40):
        for k in changed:
            kind = 'asm' if a[k][:2] != b[k][:2] else 'obj'
            print(f'  {kind} {k[1]} {k[0]}: {a[k]} -> {b[k]}')
    print('RESULT: ' + (f'DIFFER ({len(changed)} input/mode results changed)' if changed
                        else 'IDENTICAL'))
    return 1 if changed else 0


if __name__ == '__main__':
    sys.exit(main())
