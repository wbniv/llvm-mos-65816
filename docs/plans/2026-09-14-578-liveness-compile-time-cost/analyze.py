#!/usr/bin/env python3
"""Summarize results.csv from bench-578-liveness.sh: corpus totals, per-file ratios, large inputs."""
import csv, statistics, sys
from collections import defaultdict

import os
path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), 'results.csv')
rows = list(csv.DictReader(open(path)))

# only rows where both binaries succeeded for that (file, rep)
ok = defaultdict(dict)  # (file,rep) -> {binary: (ins, clk)}
for r in rows:
    if r['rc'] != '0' or r['instructions'] in ('NA', '', '<not counted>'):
        continue
    ok[(r['file'], r['rep'])][r['binary']] = (int(r['instructions']), float(r['task_clock_ms']))
pairs = {k: v for k, v in ok.items() if 'prefix' in v and 'postfix' in v}

corpus = {k: v for k, v in pairs.items() if not k[1].startswith('L')}
large = {k: v for k, v in pairs.items() if k[1].startswith('L')}

# per-file: median over reps of each binary's instructions, then ratio
def per_file(d):
    by = defaultdict(lambda: {'prefix': [], 'postfix': [], 'pclk': [], 'qclk': []})
    for (f, rep), v in d.items():
        by[f]['prefix'].append(v['prefix'][0]); by[f]['postfix'].append(v['postfix'][0])
        by[f]['pclk'].append(v['prefix'][1]);   by[f]['qclk'].append(v['postfix'][1])
    out = {}
    for f, v in by.items():
        p, q = statistics.median(v['prefix']), statistics.median(v['postfix'])
        out[f] = (p, q, q / p, q - p, statistics.median(v['pclk']), statistics.median(v['qclk']), len(v['prefix']))
    return out

cf = per_file(corpus)
files_compiled = len(cf)
tot_p = sum(v[0] for v in cf.values()); tot_q = sum(v[1] for v in cf.values())
ratios = sorted(v[2] for v in cf.values())
print(f"CORPUS: {files_compiled} files compiled on both binaries (reps per file: {min(v[6] for v in cf.values())}-{max(v[6] for v in cf.values())})")
print(f"  total instructions  prefix={tot_p:,}  postfix={tot_q:,}  ratio={tot_q/tot_p:.5f}  delta={tot_q-tot_p:+,}")
clk_p = sum(v[4] for v in cf.values()); clk_q = sum(v[5] for v in cf.values())
print(f"  total task-clock ms prefix={clk_p:.0f}  postfix={clk_q:.0f}  ratio={clk_q/clk_p:.4f}  (load-sensitive, secondary)")
print(f"  per-file ratio: min={ratios[0]:.5f} median={statistics.median(ratios):.5f} max={ratios[-1]:.5f}")
above = [(f, v) for f, v in cf.items() if v[2] > 1.01]
print(f"  files with ratio > 1.01: {len(above)}")
top = sorted(cf.items(), key=lambda kv: -kv[1][3])[:5]
print("  top-5 by absolute instruction delta:")
for f, v in top:
    print(f"    {f:28s} prefix={v[0]:>12,} postfix={v[1]:>12,} ratio={v[2]:.5f} delta={v[3]:+,}")
bot = sorted(cf.items(), key=lambda kv: kv[1][3])[:3]
print("  bottom-3 (most negative delta, i.e. noise floor):")
for f, v in bot:
    print(f"    {f:28s} ratio={v[2]:.5f} delta={v[3]:+,}")

# per-rep stability of instruction counts: max spread across reps for one binary, one file
spreads = []
for (f, rep), v in corpus.items(): pass
by_fb = defaultdict(list)
for (f, rep), v in corpus.items():
    by_fb[(f, 'prefix')].append(v['prefix'][0]); by_fb[(f, 'postfix')].append(v['postfix'][0])
sp = [ (max(x)-min(x))/statistics.median(x) for x in by_fb.values() if len(x) > 1 ]
if sp:
    print(f"  instruction-count rep-to-rep spread: median={statistics.median(sp)*100:.4f}%  max={max(sp)*100:.4f}%  (metric stability)")

if large:
    lf = per_file(large)
    print(f"\nLARGE INPUTS (N per side = {min(v[6] for v in lf.values())}):")
    for f in sorted(lf):
        v = lf[f]
        print(f"  {f:18s} prefix={v[0]:>13,} postfix={v[1]:>13,} ratio={v[2]:.5f} delta={v[3]:+,}  clk {v[4]:.0f}->{v[5]:.0f} ms")

failed = [r for r in rows if r['rc'] != '0']
asym = set()
for (f, rep), v in ok.items():
    if len(v) == 1: asym.add(f)
print(f"\nfailed compiles (both binaries, fork-only legalization): {len({r['file'] for r in failed})} files; asymmetric (one binary only): {len(asym)}")
