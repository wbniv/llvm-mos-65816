#!/usr/bin/env python3
"""Inventory exact opcode tokens in retained MIR outputs without running tools."""

import hashlib
import json
from pathlib import Path
import re
import tarfile


ROOT = Path(__file__).resolve().parents[5]
SOURCE = ROOT / 'docs/defects/evidence/2026-09-28-far-word-policy/source.tar.gz'
RUNS = ROOT / 'docs/defects/evidence/2026-09-28-farblit-range-integration/runs.tar.gz'
OPCODE = re.compile(r'\bG_LOAD_FAR_INDIR(?:_IDX(?:16)?)?\b')
sha = lambda data: hashlib.sha256(data).hexdigest()

with tarfile.open(SOURCE) as archive:
    source = archive.extractfile('source/far-loop-range.mir').read()

expected = {prefix: {} for prefix in ('A16', 'XY16', 'OFF')}
current = {}
for line in source.decode().splitlines():
    label = re.match(r'# (A16|XY16|OFF)-LABEL: name: (\w+)', line)
    check = re.match(r'# (A16|XY16|OFF): = (G_LOAD_FAR_INDIR\w*)\s*$', line)
    if label:
        current[label[1]] = label[2]
    if check:
        expected[check[1]][current[check[1]]] = check[2]

records = []
members = {}
with tarfile.open(RUNS) as archive:
    for prefix, member in [('A16', 'runs/focused-a16.mir'),
                           ('XY16', 'runs/focused-xy16.mir'),
                           ('OFF', 'runs/focused-off.mir')]:
        data = archive.extractfile(member).read()
        members[member] = sha(data)
        text = data.decode()
        starts = list(re.finditer(r'^name:\s+(\w+)\s*$', text, re.M))
        for i, match in enumerate(starts):
            end = starts[i + 1].start() if i + 1 < len(starts) else len(text)
            actual = OPCODE.findall(text[match.end():end])
            want = expected[prefix][match[1]]
            records.append({'prefix': prefix, 'function': match[1],
                            'expected_token': want, 'actual_tokens': actual,
                            'exact_match': actual == [want]})

print(json.dumps({
    'method': 'Static token inventory of retained compiler output; no new compiler, FileCheck or emulator execution.',
    'source_archive_sha256': sha(SOURCE.read_bytes()),
    'source_member_sha256': sha(source),
    'runs_archive_sha256': sha(RUNS.read_bytes()),
    'output_member_sha256': members,
    'expected_cases': sum(map(len, expected.values())),
    'observed_cases': len(records),
    'matching_cases': sum(r['exact_match'] for r in records),
    'cases': records,
}, indent=2))
