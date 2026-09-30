#!/usr/bin/env python3
"""Red/green proof for the tests the split adds.

usage: red-green.py EVIDENCE_DIR LABEL_PREFIX > red-green.tsv

For each added test (from the '# Focused tests added' part of 321.spec and
320.spec), with introducing commit k in series S:
  red   = its probe result at stage S-(k-1) (the parent build),
  green = its result in the in-tree lit run of every stage S-k .. end,
          and of every #320 stage for #321 tests.
Probe results come from <prefix>S-NN/probe-summary.txt, in-tree results
from <prefix>S-NN/lit.json.
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ev, pre = sys.argv[1], sys.argv[2]


def added(series):
    out, on = [], False
    for line in open(os.path.join(HERE, f'{series}.spec')):
        if line.startswith('# Focused test'):
            on = True
        f = line.split()
        if on and f and f[0] == 'file':
            out.append((f[1], int(f[2])))
    return out


def probe(label, path):
    name = os.path.basename(path)
    for line in open(os.path.join(ev, pre + label, 'probe-summary.txt')):
        if line.split(' ')[0].rstrip(':') in ('PASS', 'FAIL') and f'/zz-probe/{name} ' in line:
            return line.split(':')[0]
    return 'MISSING'


def reason(label, path):
    """First diagnostic line of the test's probe run at `label`."""
    name = os.path.basename(path)
    txt = open(os.path.join(ev, pre + label, 'probe-lit.log'), errors='replace').read()
    start = txt.find(f'zz-probe/{name} (')
    if start < 0:
        return ''
    end = txt.find('\n********************\n', txt.find('\n', start) + 1)
    block = txt[start:end if end > 0 else len(txt)]
    import re
    for pat in (r'unknown (?:register|machine instruction)[^\n]*', r'Assertion `[^\n]*', r'LLVM ERROR:[^\n]*', r'error: [^\n]*'):
        m = re.search(pat, block)
        if m:
            return m.group(0).replace('/work/build/register-exhaustion-src/', '')[:160]
    return ''


def intree(label, path):
    d = json.load(open(os.path.join(ev, pre + label, 'lit.json')))
    key = path.replace('llvm/test/', 'LLVM :: ')
    for t in d['tests']:
        if t['name'] == key:
            return t['code']
    return 'ABSENT'


stages = {'321': range(0, 17), '320': range(0, 5)}
print('test\tcommit\tred(parent probe)\tgreen(own..end)\tresult\tred reason')
for series in ('321', '320'):
    for path, k in added(series):
        red = probe(f'{series}-{k-1:02d}', path)
        greens = [intree(f'{series}-{j:02d}', path) for j in range(k, max(stages[series]) + 1)]
        if series == '321':
            greens += [intree(f'320-{j:02d}', path) for j in stages['320']]
        g = 'PASS x%d' % len(greens) if all(x == 'PASS' for x in greens) else ','.join(greens)
        ok = red == 'FAIL' and all(x == 'PASS' for x in greens)
        why = reason(f'{series}-{k-1:02d}', path)
        print(f'{path}\t{series}-{k:02d}\t{red}\t{g}\t{"OK" if ok else "CHECK"}\t{why}')
