#!/usr/bin/env python3
"""Compare carry policies on per-input size tables (llc-sizes.sh output).

usage: policy-summary.py DIR [--ref always] [--levels Os,Oz,O2,O3]
                         [--modes default,a16,a16xy16] [--select off,always,gated]

DIR holds POLICY.LEVEL.MODE.tsv. Per level and mode, over the inputs every
policy compiles, prints each policy's total bytes and delta against --ref,
the inputs it makes larger/smaller than --ref, and its growth against `off`
(inputs and bytes). "select" is the per-input minimum over the --select
policies, as a shared-frontend selector would choose (ties keep the first).
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
    ap.add_argument('--ref', default='always')
    ap.add_argument('--levels', default='Os,Oz,O2,O3')
    ap.add_argument('--modes', default='default,a16,a16xy16')
    ap.add_argument('--select', default='off,always,gated')
    a = ap.parse_args()
    sel = a.select.split(',')
    for lv in a.levels.split(','):
        for m in a.modes.split(','):
            tabs = {}
            for f in sorted(glob.glob(os.path.join(a.dir, f'*.{lv}.{m}.tsv'))):
                t = load(f)
                if t:
                    tabs[os.path.basename(f)[:-len(f'.{lv}.{m}.tsv')]] = t
            if a.ref not in tabs or 'off' not in tabs:
                continue
            fails = {n: sum(1 for v in t.values() if v is None) for n, t in tabs.items()}
            keys = set.intersection(*(set(t) for t in tabs.values()))
            keys = sorted(k for k in keys if all(t[k] is not None for t in tabs.values()))
            if all(s in tabs for s in sel):
                tabs['select'] = {k: min(tabs[s][k] for s in sel) for k in keys}
            ref, off = tabs[a.ref], tabs['off']
            b = sum(ref[k] for k in keys)
            print(f'== {lv} {m}: {len(keys)} inputs; {a.ref} {b} B; llc failures '
                  + ', '.join(f'{n}={c}' for n, c in fails.items() if c))
            for n, t in tabs.items():
                c = sum(t[k] for k in keys)
                up = sum(1 for k in keys if t[k] > ref[k])
                dn = sum(1 for k in keys if t[k] < ref[k])
                gro = [t[k] - off[k] for k in keys if t[k] > off[k]]
                print(f'   {n:15} {c:9d} B  {c - b:+7d} ({100.0 * (c - b) / b:+.3f}%)'
                      f'  vs {a.ref}: larger {up:4d} smaller {dn:4d}'
                      f' | vs off: grow {len(gro):4d} inputs, +{sum(gro)} B')


if __name__ == '__main__':
    main()
