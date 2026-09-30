#!/usr/bin/env python3
"""Compare two sizes.sh TSVs (reference, candidate).

usage: size-diff.py REF.tsv CAND.tsv [--detail] [--top N]
Per mode: inputs compiled by both, byte totals and delta, larger/smaller
counts, asm-identical count, and inputs excluded because either side failed.
The totals use only inputs that compile on both sides, matching the Phase A
size-compare.sh convention. --detail lists every changed input; --top N lists
the N largest movers in each direction. Exit 0 always (a report, not a gate);
use --gate to exit 1 when any mode's candidate total exceeds the reference.
"""
import sys


def load(p):
    d = {}
    for line in open(p):
        f = line.rstrip('\n').split('\t')
        d[(f[0], f[1])] = f[2:]
    return d


def main():
    args = sys.argv[1:]
    if len(args) < 2 or args[0] in ('-h', '--help'):
        print(__doc__.strip())
        return 0
    a, b = load(args[0]), load(args[1])
    detail = '--detail' in args
    gate = '--gate' in args
    top = int(args[args.index('--top') + 1]) if '--top' in args else 0
    assert a.keys() == b.keys(), 'input sets differ'
    modes = sorted({k[1] for k in a})
    grew = False
    for m in modes:
        ta = tb = n = up = down = same = fail = 0
        rows = []
        for k in sorted(a):
            if k[1] != m:
                continue
            sa, ha, _ = a[k]
            sb, hb, _ = b[k]
            if sa == 'fail' or sb == 'fail':
                fail += 1
                if (sa == 'fail') != (sb == 'fail'):
                    rows.append((0, k[0], sa, sb))
                continue
            sa, sb = int(sa), int(sb)
            ta += sa; tb += sb; n += 1
            up += sb > sa; down += sb < sa; same += ha == hb
            if sa != sb:
                rows.append((sb - sa, k[0], sa, sb))
        print(f'{m}: {n} inputs, bytes {ta} -> {tb} (delta {tb - ta}), '
              f'larger {up}, smaller {down}, asm-identical {same}, excluded {fail}')
        grew |= tb > ta
        if detail:
            for d, name, sa, sb in rows:
                print(f'  {m} {name}: {sa} -> {sb} ({d:+d})' if d else f'  {m} {name}: {sa} -> {sb} (STATUS CHANGE)')
        elif top:
            rs = sorted(rows)
            for d, name, sa, sb in rs[-top:][::-1] + rs[:top]:
                print(f'  {m} {name}: {sa} -> {sb} ({d:+d})')
    return 1 if gate and grew else 0


if __name__ == '__main__':
    sys.exit(main())
