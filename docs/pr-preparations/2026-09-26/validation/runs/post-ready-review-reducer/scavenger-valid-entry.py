#!/usr/bin/env python3
"""Run the explicit virtual-register scavenger harness against saved tools."""

import hashlib
import json
from pathlib import Path
import resource
import subprocess

root = Path('/home/will/llvm-mos-65816')
out = root / 'build/post-ready-review-reducer/scavenger-valid-entry-v3'
out.mkdir(exist_ok=False)
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
saved = root / 'build/post-ready-validation-mos-r2/0054'
fixture = root / 'build/post-ready-review-reducer/scavenger-status-save-range-isolated.mir'
runs = []
hashes = {}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def run(name, argv):
    result = subprocess.run([str(x) for x in argv], cwd=root,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log = out / (name + '.log')
    log.write_bytes(result.stdout)
    runs.append({'name': name, 'argv': [str(x) for x in argv],
                 'returncode': result.returncode, 'log': str(log),
                 'log_sha256': sha(log)})
    print(name, result.returncode, flush=True)
    return result.returncode

hashes[str(fixture)] = sha(fixture)
for side in ['baseline', 'candidate']:
    llc = saved / (side + '-bin/llc')
    check = saved / (side + '-bin/FileCheck')
    hashes[str(llc)] = sha(llc)
    hashes[str(check)] = sha(check)
    run(side + '-version', [llc, '--version'])
    for cpu in ['mosw65816', 'mos65c02', 'mos6502']:
        name = side + '-' + cpu
        result = out / (name + '.mir')
        rc = run(name, [llc, '-mtriple=mos', '-mcpu=' + cpu,
                        '-run-pass=scavenger-test', '-verify-machineinstrs',
                        fixture, '-o', result])
        if rc == 0:
            run(name + '-check', [check, fixture, '--input-file', result])
            hashes[str(result)] = sha(result)
        (out / 'results.json').write_text(json.dumps(
            {'hashes': hashes, 'runs': runs}, indent=2) + '\n')
