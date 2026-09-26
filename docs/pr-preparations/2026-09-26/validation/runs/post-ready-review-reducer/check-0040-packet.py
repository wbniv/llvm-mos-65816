#!/usr/bin/env python3
"""Record exact posting-fixture input validity and retained-binary execution."""
import hashlib
import json
from pathlib import Path
import resource
import subprocess

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent / '0040-packet-checks'
out.mkdir(exist_ok=False)
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
fixture = out.parent / '0040-packet.mir'
result = {'input': str(fixture.relative_to(root)),
          'input_sha256': hashlib.sha256(fixture.read_bytes()).hexdigest(), 'runs': []}
bins = {'old-before': root / 'build/0040-ra-build/llc-before-0040',
        'old-after': root / 'build/0040-ra-build/llc-0040',
        'current-base': root / 'build/post-ready-validation-mos/0039/baseline-bin/llc'}
for name, llc in bins.items():
    for mode in ['input-verify', 'greedy', 'full']:
        args = ['-run-pass=machineverifier'] if mode == 'input-verify' else (
            ['-run-pass=greedy'] if mode == 'greedy' else ['-start-before=greedy'])
        cmd = [str(llc), '-mtriple=mos', '-mcpu=mos65c02', '-O2', '-disable-spill-hoist',
               '-verify-machineinstrs', *args, str(fixture), '-o', '-']
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        tag = name + '-' + mode
        (out / (tag + '.stdout')).write_bytes(p.stdout)
        (out / (tag + '.stderr')).write_bytes(p.stderr)
        row = {'name': tag, 'command': cmd, 'returncode': p.returncode,
               'binary_sha256': hashlib.sha256(llc.read_bytes()).hexdigest(),
               'stdout_sha256': hashlib.sha256(p.stdout).hexdigest(),
               'stderr_sha256': hashlib.sha256(p.stderr).hexdigest()}
        if mode == 'full' and p.returncode == 0:
            fc = subprocess.run([str(root / 'build/llvm-mos/bin/FileCheck'), str(fixture)],
                                input=p.stdout, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            (out / (tag + '.check')).write_bytes(fc.stderr)
            row['filecheck_returncode'] = fc.returncode
        result['runs'].append(row)
        print(tag, p.returncode, flush=True)
(out / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
