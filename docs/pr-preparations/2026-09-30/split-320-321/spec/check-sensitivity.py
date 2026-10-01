#!/usr/bin/env python3
"""Check real legalizer outputs and reject opcode-suffix substitutions.

For each far-word test and configuration below, run the legalizer with the
candidate llc, check the real output with FileCheck, then mutate every far
access opcode in every function to each sibling form of the same access
(explicit pointer, 8-bit index, 16-bit index) and require FileCheck to reject
each mutant. A function with no far access opcode (for example an atomic load
the fold rejects) is recorded with zero mutations; its CHECK-NOT lines cover it.

Covers far-loop-range.mir and far-word-policy.mir (the original runner), and
since review N8 also far-loop-range-boundaries.mir and
far-word-index-boundaries.mir.
"""
import argparse, hashlib, json, re, subprocess
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
p.add_argument('--root', type=Path, required=True, help='repository root')
p.add_argument('--work', type=Path, help='directory holding source, candidate/llc and build/bin (default: ROOT/build/far-word-upstream)')
p.add_argument('--llc', type=Path, help='llc to test (default: WORK/candidate/llc)')
p.add_argument('--filecheck', type=Path, help='FileCheck (default: WORK/build/bin/FileCheck)')
p.add_argument('--tests', type=Path, help='CodeGen/MOS test directory (default: WORK/source/llvm/test/CodeGen/MOS)')
p.add_argument('--out', type=Path, help='output directory (default: WORK/sensitivity)')
a = p.parse_args()
r = a.root.resolve()
w = a.work.resolve() if a.work else r / 'build/far-word-upstream'
llc = a.llc or w / 'candidate/llc'
fc = a.filecheck or w / 'build/bin/FileCheck'
tests = a.tests or w / 'source/llvm/test/CodeGen/MOS'
out = a.out or w / 'sensitivity'
out.mkdir(parents=True, exist_ok=True)

A16 = ['-mattr=+mos-a16']
XY16 = ['-mattr=+mos-a16,+mos-xy16']
CASES = [
    ('far-loop-range.mir', [('A16', A16), ('XY16', XY16)]),
    ('far-word-policy.mir', [('SPEED', A16), ('ALL', A16 + ['-mos-far-word-index=all']),
                             ('OFF', A16 + ['-mos-far-word-index=off'])]),
    ('far-loop-range-boundaries.mir', [('CHECK', A16)]),
    ('far-word-index-boundaries.mir', [('CHECK', A16), ('CHECK', XY16)]),
]
# One far access opcode: access kind and width, then the addressing suffix.
FAR = re.compile(r'\bG_(LOAD|STORE)(16)?_FAR_INDIR(_IDX16|_IDX)?\b')
SUFFIXES = ['', '_IDX', '_IDX16']

records, positives, functions = [], [], []
for file, configs in CASES:
    for prefix, flags in configs:
        cmd = [str(llc), '-mtriple=mos', '-mcpu=mosw65816', *flags, '-run-pass=legalizer',
               '-verify-machineinstrs', str(tests / file), '-o', '-']
        raw = subprocess.run(cmd, capture_output=True, text=True)
        assert raw.returncode == 0, raw.stderr
        text = raw.stdout
        tag = f"{file}.{prefix}.{'xy16' if flags == XY16 else 'a16'}"
        (out / f'{tag}.out').write_text(text)
        check = [str(fc), str(tests / file), '--check-prefix=' + prefix]
        pos = subprocess.run(check, input=text, text=True, capture_output=True)
        assert pos.returncode == 0, pos.stderr
        positives.append(dict(file=file, prefix=prefix, command=cmd,
                              sha256=hashlib.sha256(text.encode()).hexdigest()))
        labels = list(re.finditer(r'^name:[ \t]+(\w+)[ \t]*$', text, re.M))
        for i, label in enumerate(labels):
            start = label.end()
            end = labels[i + 1].start() if i + 1 < len(labels) else len(text)
            matches = list(FAR.finditer(text, start, end))
            functions.append(dict(file=file, prefix=prefix, flags=flags, function=label[1],
                                  far_opcodes=[m[0] for m in matches]))
            for m in matches:
                stem = f'G_{m[1]}{m[2] or ""}_FAR_INDIR'
                for suffix in SUFFIXES:
                    replacement = stem + suffix
                    if replacement == m[0]:
                        continue
                    mutant = text[:m.start()] + replacement + text[m.end():]
                    res = subprocess.run(check, input=mutant, text=True, capture_output=True)
                    records.append(dict(file=file, prefix=prefix, flags=flags, function=label[1],
                                        expected=m[0], replacement=replacement,
                                        returncode=res.returncode))
                    assert res.returncode == 1, records[-1]

summary = dict(positive_passes=len(positives), functions=len(functions),
               functions_without_far_opcode=sum(not f['far_opcodes'] for f in functions),
               mutations=len(records), rejected=sum(x['returncode'] == 1 for x in records))
(out / 'results.json').write_text(json.dumps(dict(summary=summary, positives=positives,
                                                  functions=functions, mutations=records),
                                             indent=2) + '\n')
print(summary)
