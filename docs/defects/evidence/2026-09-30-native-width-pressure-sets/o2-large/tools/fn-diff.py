#!/usr/bin/env python3
"""Per-function text size changes between two objects.

usage: fn-diff.py LLVM-NM A.o B.o
Prints every function (t/T symbol) whose size differs, and the net change. Used to
show that the LTO objects' library functions are byte-identical in size between t4 and
memb1 (only demo and snesgfx functions move).
"""
import subprocess, sys


def syms(o):
    d = {}
    for l in subprocess.run([sys.argv[1], '-S', o], capture_output=True, text=True).stdout.splitlines():
        p = l.split()
        if len(p) == 4 and p[2] in 'tT':
            d[p[3]] = int(p[1], 16)
    return d


if len(sys.argv) != 4 or sys.argv[1] in ('-h', '--help'):
    print(__doc__); sys.exit(0)
a, b = syms(sys.argv[2]), syms(sys.argv[3])
tot = 0
for k in sorted(set(a) | set(b)):
    if a.get(k, 0) != b.get(k, 0):
        print(f'  {k} {a.get(k, 0)}->{b.get(k, 0)} ({b.get(k, 0) - a.get(k, 0):+d})')
        tot += b.get(k, 0) - a.get(k, 0)
print(f'  functions {len(a)} / {len(b)}; text total {tot:+d}')
