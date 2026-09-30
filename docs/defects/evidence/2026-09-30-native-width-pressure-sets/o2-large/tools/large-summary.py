#!/usr/bin/env python3
"""Summarize runtime-clocks-large.py results per level, mode and program.

usage: large-summary.py RESULTS.tsv [--ref head] [--vs t4] [--off memb1]

Each program runs at two lengths (specs NAME:MACRO=K1 and NAME:MACRO=K2, K1 < K2). Reported:
  whole  - master clocks of the long run (main's entry to the verified corpus_result write);
  loop   - long minus short: (K2 - K1) iterations of the demo's steady-state frame loop;
  setup  - short minus loop * K1 / (K2 - K1): app_init, title, the gate CRC and the fold.
For every variant, the change against --ref and --vs, and the off-vs-on figure the verdict uses
(--off against --vs). Totals are over the programs that pass under every variant at both
lengths. Object bytes are the long run's (text+data+rodata of the llc object). Exit 0 always.
"""
import argparse
import collections
import re


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('results')
    ap.add_argument('--ref', default='head')
    ap.add_argument('--vs', default='t4')
    ap.add_argument('--off', default='memb1')
    a = ap.parse_args()
    lines = [l.rstrip('\n').split('\t') for l in open(a.results)]
    hdr, rows = lines[0], [dict(zip(lines[0], r)) for r in lines[1:]]
    by = collections.defaultdict(dict)
    variants = []
    bad = []
    for r in rows:
        name, _, define = r['sim'].partition(':')
        k = int(re.search(r'=(\d+)$', define).group(1))
        by[(r['level'], r['mode'], name)].setdefault(r['variant'], {})[k] = r
        if r['variant'] not in variants:
            variants.append(r['variant'])
        if r['status'] != 'PASS' or r['deterministic'] != 'True':
            bad.append((r['sim'], r['level'], r['mode'], r['variant'], r['status'],
                        r['deterministic']))
    print(f'rows {len(rows)}; not PASS or not deterministic: {len(bad)}')
    for b in bad:
        print('  ', *b)
    levels = sorted({k[0] for k in by})
    modes = sorted({k[1] for k in by})

    def parts(v):
        (k1, r1), (k2, r2) = sorted(v.items())
        c1, c2 = int(r1['clocks']), int(r2['clocks'])
        loop = c2 - c1
        return {'whole': c2, 'loop': loop, 'setup': c1 - loop * k1 // (k2 - k1),
                'bytes': int(r2['bytes']), 'k': (k1, k2)}

    def pct(x, y):
        return f'{x - y:+,} ({100 * (x - y) / y:+.2f}%)' if y else f'{x - y:+,}'

    for lv in levels:
        for m in modes:
            progs = sorted(p for (l, mm, p), v in by.items() if l == lv and mm == m and
                           all(x in v and len(v[x]) == 2 and
                               all(r['status'] == 'PASS' for r in v[x].values())
                               for x in variants))
            print(f'== {lv} {m}: {len(progs)} programs pass under every variant at both lengths')
            tot = collections.defaultdict(lambda: collections.Counter())
            for p in progs:
                P = {x: parts(by[(lv, m, p)][x]) for x in variants}
                k1, k2 = P[variants[0]]['k']
                print(f'  {p} (K {k1} -> {k2})')
                for x in variants:
                    q = P[x]
                    for f in ('whole', 'loop', 'setup', 'bytes'):
                        tot[x][f] += q[f]
                    line = (f'    {x:6} whole {q["whole"]:>12,}  loop {q["loop"]:>12,}'
                            f'  setup {q["setup"]:>11,}  bytes {q["bytes"]:>6,}')
                    if x != a.ref:
                        line += (f' | vs {a.ref}: whole {pct(q["whole"], P[a.ref]["whole"])}'
                                 f' loop {pct(q["loop"], P[a.ref]["loop"])}'
                                 f' {q["bytes"] - P[a.ref]["bytes"]:+} B')
                    if x not in (a.ref, a.vs):
                        line += (f' | vs {a.vs}: whole {pct(q["whole"], P[a.vs]["whole"])}'
                                 f' loop {pct(q["loop"], P[a.vs]["loop"])}'
                                 f' setup {pct(q["setup"], P[a.vs]["setup"])}'
                                 f' {q["bytes"] - P[a.vs]["bytes"]:+} B')
                    print(line)
            print('  total')
            for x in variants:
                q = tot[x]
                line = (f'    {x:6} whole {q["whole"]:>12,}  loop {q["loop"]:>12,}'
                        f'  setup {q["setup"]:>11,}  bytes {q["bytes"]:>6,}')
                if x != a.ref:
                    line += (f' | vs {a.ref}: whole {pct(q["whole"], tot[a.ref]["whole"])}'
                             f' loop {pct(q["loop"], tot[a.ref]["loop"])}')
                if x not in (a.ref, a.vs):
                    line += (f' | vs {a.vs}: whole {pct(q["whole"], tot[a.vs]["whole"])}'
                             f' loop {pct(q["loop"], tot[a.vs]["loop"])}'
                             f' setup {pct(q["setup"], tot[a.vs]["setup"])}')
                print(line)


if __name__ == '__main__':
    main()
