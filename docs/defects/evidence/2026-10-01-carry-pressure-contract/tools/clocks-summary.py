#!/usr/bin/env python3
"""Summarize runtime-clocks.py results: per level and mode, total master
clocks and object bytes of each variant over the sims where every variant
passes, against the reference variant, with per-sim movers.

usage: clocks-summary.py RESULTS.tsv [--ref head] [--vs t4]
Also compares every variant with --vs (the ungated design) so a gate's
effect is visible directly. Exit 0 always (a report).
"""
import argparse
import collections


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('results')
    ap.add_argument('--ref', default='head')
    ap.add_argument('--vs', default='t4')
    a = ap.parse_args()
    rows = [l.rstrip('\n').split('\t') for l in open(a.results)]
    hdr, rows = rows[0], rows[1:]
    R = [dict(zip(hdr, r)) for r in rows]
    by = collections.defaultdict(dict)
    variants, statuses = [], collections.Counter()
    for r in R:
        by[(r['level'], r['mode'], r['sim'])][r['variant']] = r
        if r['variant'] not in variants:
            variants.append(r['variant'])
        statuses[(r['level'], r['mode'], r['variant'], r['status'])] += 1
        if r['status'] == 'PASS' and r['deterministic'] != 'True':
            print('NONDETERMINISTIC', r['sim'], r['level'], r['mode'], r['variant'])
    levels = sorted({k[0] for k in by}, key=['O2', 'O3', 'Os', 'Oz'].index)
    modes = sorted({k[1] for k in by})
    for lv in levels:
        for m in modes:
            sims = sorted(s for (l, mm, s), v in by.items() if l == lv and mm == m and
                          all(v.get(x, {}).get('status') == 'PASS' for x in variants))
            bad = sorted(s for (l, mm, s), v in by.items() if l == lv and mm == m and s not in sims)
            print(f'== {lv} {m}: {len(sims)} sims pass under every variant'
                  + (f'; excluded {", ".join(bad)}' if bad else ''))
            tot = {x: (sum(int(by[(lv, m, s)][x]['clocks']) for s in sims),
                       sum(int(by[(lv, m, s)][x]['bytes']) for s in sims)) for x in variants}
            for x in variants:
                c, b = tot[x]
                line = f'   {x:6} clocks {c:>11,}  bytes {b:>6,}'
                for base in (a.ref, a.vs):
                    if x == base:
                        continue
                    c0, b0 = tot[base]
                    d = [int(by[(lv, m, s)][x]['clocks']) - int(by[(lv, m, s)][base]['clocks'])
                         for s in sims]
                    line += (f' | vs {base}: {c - c0:+,} clk ({100 * (c - c0) / c0:+.2f}%),'
                             f' {b - b0:+} B, faster {sum(v < 0 for v in d)}'
                             f' slower {sum(v > 0 for v in d)}')
                print(line)
            for x in variants:
                if x in (a.ref,):
                    continue
                mv = sorted(((int(by[(lv, m, s)][x]['clocks']) - int(by[(lv, m, s)][a.ref]['clocks']), s)
                             for s in sims))
                moved = [f'{s} {d:+,}' for d, s in mv if d]
                if moved:
                    print(f'     {x} vs {a.ref} per sim: ' + '; '.join(moved))
    print('== status counts (level mode variant status: n)')
    for k, n in sorted(statuses.items()):
        if k[3] != 'PASS':
            print('  ', *k, n)


if __name__ == '__main__':
    main()
