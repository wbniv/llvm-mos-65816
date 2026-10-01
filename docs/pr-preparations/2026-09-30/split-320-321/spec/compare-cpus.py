#!/usr/bin/env python3
"""Compare two default-hashes-cpus.sh tables.

usage: compare-cpus.py OLD.tsv NEW.tsv [--list]
Prints, per CPU, how many inputs are identical (assembly and object hashes and
exit codes) and how many differ, split into fail->pass, pass->fail, pass->pass
with different output, and fail->fail with a different error. --list prints
every differing row.
"""
import collections, sys
if len(sys.argv) < 3 or sys.argv[1] in ('-h', '--help'):
    print(__doc__.strip()); sys.exit(0)
def load(p):
    d = {}
    for line in open(p):
        lv, inp, cpu, ra, ha, ro, ho = line.rstrip('\n').split('\t')
        d[(lv, inp, cpu)] = (ra, ha, ro, ho)
    return d
a, b = load(sys.argv[1]), load(sys.argv[2])
assert a.keys() == b.keys(), 'different input sets'
cnt = collections.defaultdict(collections.Counter)
rows = []
for k in sorted(a):
    x, y = a[k], b[k]
    cpu = k[2]
    if x == y:
        cnt[cpu]['same'] += 1; continue
    ok_x, ok_y = x[0] == '0', y[0] == '0'
    kind = ('fail->pass' if not ok_x and ok_y else 'pass->fail' if ok_x and not ok_y
            else 'output' if ok_x else 'error')
    cnt[cpu][kind] += 1
    rows.append((k, kind, x, y))
for cpu in sorted(cnt):
    c = cnt[cpu]
    print(f"{cpu:12s} same={c['same']:3d} fail->pass={c['fail->pass']} pass->fail={c['pass->fail']} output={c['output']} error={c['error']}")
tot = sum((c for c in cnt.values()), collections.Counter())
print(f"{'total':12s} same={tot['same']} fail->pass={tot['fail->pass']} pass->fail={tot['pass->fail']} output={tot['output']} error={tot['error']}")
if '--list' in sys.argv:
    for k, kind, x, y in rows:
        print(kind, *k, x, '->', y)
