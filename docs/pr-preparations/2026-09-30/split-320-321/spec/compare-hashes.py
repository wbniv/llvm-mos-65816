#!/usr/bin/env python3
"""Compare two default-hashes TSVs (before, after) and summarize.

usage: compare-hashes.py BEFORE.tsv AFTER.tsv [--names]
Prints one summary line per mode, then each input whose asm or obj result
changed (with --names, or when there are at most 40 changes).
"""
import sys


def load(p):
    d = {}
    for line in open(p):
        f = line.rstrip('\n').split('\t')
        d[(f[0], f[1])] = f[2:]
    return d


def main():
    a, b = load(sys.argv[1]), load(sys.argv[2])
    names = '--names' in sys.argv
    assert a.keys() == b.keys(), 'input sets differ'
    changed = []
    for mode in ('mos6502', 'mosw65816'):
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


if __name__ == '__main__':
    main()
