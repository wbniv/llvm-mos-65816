#!/usr/bin/env python3
"""Usage: title-emit-first.py IN.ll OUT.ll

Write a copy of IN.ll with the definition of @_title_emit moved ahead of every
other function definition, so llc compiles it before @main. Nothing else in
the module changes.
"""
import re
import sys

if len(sys.argv) != 3 or sys.argv[1] in ('-h', '--help'):
    print(__doc__.strip())
    sys.exit(0 if len(sys.argv) > 1 and sys.argv[1] in ('-h', '--help') else 2)
text = open(sys.argv[1]).read()
parts = re.split(r'(?=^define )', text, flags=re.M)
head, fns = parts[0], parts[1:]
last = fns[-1]
end = last.find('\n}\n') + 3
fns[-1], tail = last[:end], last[end:]
key = 'define internal void @_title_emit('
first = [f for f in fns if f.startswith(key)]
rest = [f for f in fns if not f.startswith(key)]
assert len(first) == 1
open(sys.argv[2], 'w').write(head + first[0] + ''.join(rest) + tail)
