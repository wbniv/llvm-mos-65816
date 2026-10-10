#!/usr/bin/env python3
"""Split a git-format patch into per-file sections and splice replacements.
usage: p2sections.py extract PATCH PATH OUT
       p2sections.py replace PATCH PATH SECTION_FILE OUT"""
import sys, re
def split(text):
    parts = re.split(r'(?m)^(?=diff --git )', text)
    return parts[0], parts[1:]
def key(sec):
    return sec.split('\n', 1)[0].split(' b/', 1)[1]
cmd = sys.argv[1]
text = open(sys.argv[2]).read()
head, secs = split(text)
path = sys.argv[3]
idx = [i for i, s in enumerate(secs) if key(s) == path]
assert len(idx) == 1, (path, idx)
if cmd == 'extract':
    open(sys.argv[4], 'w').write(secs[idx[0]])
else:
    secs[idx[0]] = open(sys.argv[4]).read()
    open(sys.argv[5], 'w').write(head + ''.join(secs))
