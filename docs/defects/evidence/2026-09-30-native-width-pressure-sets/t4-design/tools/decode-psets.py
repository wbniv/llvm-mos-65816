#!/usr/bin/env python3
"""Decode a MOSGenRegisterInfoTargetDesc.inc pressure section into readable
per-class and per-unit pressure-set lists, with set limits.

usage: decode-psets.py TARGETDESC.inc ENUMS.inc MCDESC.inc
Prints: each set with its limit; each register class with its weight and the
names of the sets it counts toward; the non-imaginary register units likewise.
"""
import re, sys

if len(sys.argv) != 4 or sys.argv[1] in ('-h', '--help'):
    print(__doc__.strip()); sys.exit(0)
td, en, mc = (open(p).read() for p in sys.argv[1:])
names = re.findall(r'"([^"]+)",', re.search(r'PressureNameTable\[\] = \{(.*?)\};', td, re.S).group(1))
limits = [int(x) for x in re.findall(r'^\s*(\d+),', re.search(r'PressureLimitTable\[\] = \{(.*?)\};', td, re.S).group(1), re.M)]
body = re.search(r'RCSetsTable\[\] = \{(.*?)\};', td, re.S).group(1)
flat = [int(x) for x in re.findall(r'-?\d+', re.sub(r'/\*.*?\*/', '', body))]
def sets_at(i):
    out = []
    while flat[i] != -1:
        out.append(names[flat[i]]); i += 1
    return out
rcstart = [int(x) for x in re.search(r'RCSetStartTable\[\] = \{(.*?)\};', td, re.S).group(1).split(',') if x.strip()]
rustart = [int(x) for x in re.search(r'RUSetStartTable\[\] = \{(.*?)\};', td, re.S).group(1).split(',') if x.strip()]
cls = dict((int(i), n) for n, i in re.findall(r'(\w+)RegClassID = (\d+),', en))
w = re.findall(r'\{(\d+), (\d+)\},\s*// (\w+)', re.search(r'RCWeightTable\[\] = \{(.*?)\};', td, re.S).group(1))
roots = re.findall(r'\{ MOS::(\w+) ', re.search(r'MOSRegUnitRoots\[\]\[2\] = \{(.*?)\};', mc, re.S).group(1))
print('sets:', ', '.join(f'{n}={l}' for n, l in zip(names, limits)))
for i, s in enumerate(rcstart):
    rw, wl = w[i][0], w[i][1]
    print(f'class {cls[i]:<20} w={rw} lim={wl:<4} -> {" ".join(sets_at(s)) or "(none)"}')
for u, s in enumerate(rustart[:14]):
    print(f'unit {u:<3} {roots[u]:<8} -> {" ".join(sets_at(s)) or "(none)"}')
print(f'unit 13.. {roots[13]}.. -> {" ".join(sets_at(rustart[13]))}')
