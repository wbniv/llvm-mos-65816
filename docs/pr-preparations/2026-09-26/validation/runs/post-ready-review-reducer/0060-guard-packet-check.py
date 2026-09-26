#!/usr/bin/env python3
"""Execute exact companion RUNs against preserved current MOS/LLVM tools."""
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import subprocess

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent / '0060-guard-packet-check'
out.mkdir(exist_ok=False)
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
fixture = out.parent / '0060-valid-mir-guard.mir'
result = {'input_sha256': hashlib.sha256(fixture.read_bytes()).hexdigest(), 'runs': []}
for name, bindir in [('mos', root / 'build/post-ready-validation-mos/0039/baseline-bin'),
                     ('llvm', root / 'build/post-ready-validation-llvm/0060/baseline-bin')]:
    env = os.environ.copy()
    env['PATH'] = str(bindir) + os.pathsep + env['PATH']
    for index, line in enumerate(l for l in fixture.read_text().splitlines() if l.startswith('# RUN:')):
        command = line.removeprefix('# RUN: ')
        command = command.replace('%S', str(root / 'build/post-ready-2026-09-26-llvm-src/llvm/test/tools/llvm-reduce/mir'))
        command = command.replace('%s', str(fixture)).replace('%t', str(out / name))
        command = re.sub(r'\bFileCheck\b', str(bindir / 'FileCheck'), command)
        p = subprocess.run(['bash', '-o', 'pipefail', '-c', command], env=env, capture_output=True, timeout=150)
        log = out / f'{name}-{index}.log'
        log.write_bytes(p.stdout + p.stderr)
        row = {'variant': name, 'command': command, 'returncode': p.returncode,
               'log': str(log.relative_to(root)), 'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()}
        result['runs'].append(row)
        print(name, index, p.returncode, flush=True)
(out / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
