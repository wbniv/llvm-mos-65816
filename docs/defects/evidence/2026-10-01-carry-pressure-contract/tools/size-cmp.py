#!/usr/bin/env python3
"""Compare llc-sizes.sh outputs against a base.

usage: size-cmp.py [--filter SUBSTR] BASE.tsv CAND.tsv [CAND2.tsv ...]

Only inputs that compile in every file are counted. Prints, per candidate:
N inputs, base -> cand bytes (delta, percent), larger, smaller.
"""
import sys

args = sys.argv[1:]
if not args or args[0] in ('-h', '--help'):
    print(__doc__)
    sys.exit(0)
filt = None
if args[0] == '--filter':
    filt = args[1]
    args = args[2:]


def load(p):
    d = {}
    for line in open(p):
        k, v = line.rstrip('\n').split('\t')
        if filt and filt not in k:
            continue
        d[k] = None if v == 'fail' else int(v)
    return d


tabs = [load(p) for p in args]
keys = set(tabs[0])
for t in tabs[1:]:
    keys &= set(t)
keys = sorted(k for k in keys if all(t[k] is not None for t in tabs))
base = tabs[0]
b = sum(base[k] for k in keys)
print(f'{args[0]}: {len(keys)} inputs, {b} B')
for p, t in zip(args[1:], tabs[1:]):
    c = sum(t[k] for k in keys)
    up = sum(1 for k in keys if t[k] > base[k])
    dn = sum(1 for k in keys if t[k] < base[k])
    print(f'  {p}: {b} -> {c} ({c - b:+d}, {100.0 * (c - b) / b:+.2f}%), larger {up}, smaller {dn}')
