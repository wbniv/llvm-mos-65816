#!/usr/bin/env python3
"""Summarize size-matrix.sh output against a reference configuration.

usage: matrix-summary.py MATRIXDIR [--ref base] [--levels Os,Oz,O2,O3]
                         [--modes default,a16,a16xy16]

For each level and mode, counts only inputs that compile under every
configuration present, and prints each configuration's total bytes and its
delta against the reference (bytes, percent, larger, smaller inputs).
"""
import argparse
import glob
import os


def load(p):
    d = {}
    for line in open(p):
        k, v = line.rstrip('\n').split('\t')
        d[os.path.basename(k)] = None if v == 'fail' else int(v)
    return d


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('dir')
    ap.add_argument('--ref', default='base')
    ap.add_argument('--levels', default='Os,Oz,O2,O3')
    ap.add_argument('--modes', default='default,a16,a16xy16')
    a = ap.parse_args()
    for lv in a.levels.split(','):
        for m in a.modes.split(','):
            files = sorted(glob.glob(os.path.join(a.dir, f'*.{lv}.{m}.tsv')))
            if not files:
                continue
            tabs = {os.path.basename(f)[:-len(f'.{lv}.{m}.tsv')]: load(f) for f in files}
            tabs = {n: t for n, t in tabs.items() if t}  # skip runs in progress
            if a.ref not in tabs:
                continue
            keys = set.intersection(*(set(t) for t in tabs.values()))
            fails = {n: sum(1 for k in t if t[k] is None) for n, t in tabs.items()}
            keys = sorted(k for k in keys if all(t[k] is not None for t in tabs.values()))
            ref = tabs[a.ref]
            b = sum(ref[k] for k in keys)
            print(f'== {lv} {m}: {len(keys)} inputs; {a.ref} {b} B; llc failures '
                  + ', '.join(f'{n}={c}' for n, c in fails.items()))
            for n, t in tabs.items():
                if n == a.ref:
                    continue
                c = sum(t[k] for k in keys)
                up = sum(1 for k in keys if t[k] > ref[k])
                dn = sum(1 for k in keys if t[k] < ref[k])
                print(f'   {n:10} {c:9d} B  {c - b:+7d} ({100.0 * (c - b) / b:+.2f}%)'
                      f'  larger {up:3d} smaller {dn:3d}')


if __name__ == '__main__':
    main()
