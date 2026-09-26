#!/usr/bin/env python3
"""Compare retained scavenger inputs against independently identified repairs."""

import hashlib
import json
from pathlib import Path
import resource
import subprocess

root = Path('/home/will/llvm-mos-65816')
scratch = root / 'build/post-ready-review-reducer'
out = scratch / 'scavenger-nz-reconciliation'
out.mkdir(exist_ok=False)
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
tools = {
    'stock-7bd': root / 'build/post-ready-validation-mos-r2/0054/baseline-bin/llc',
    '0054-only-7bd': root / 'build/post-ready-validation-mos-r2/0054/candidate-bin/llc',
    'retained-0011-plus0030-0031': root / 'build/0030-claude-review/llc-0031-plus-0011',
    'full-fork': root / 'build/llvm-mos/bin/llc',
}
inputs = {
    'v2': scratch / 'scavenger-status-save-range.mir',
    'nested-control': scratch / 'scavenger-nested-save-control.mir',
    'known-0011': root / 'vendor/llvm-mos/llvm/test/CodeGen/MOS/scavenger-p-undef-6502.ll',
}
check = root / 'build/post-ready-validation-mos-r2/0054/candidate-bin/FileCheck'
runs = []

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

hashes = {str(p): sha(p) for p in [*tools.values(), *inputs.values(), check]}
for label, llc in tools.items():
    run(label + '-version', [llc, '--version'])
    for name in ['v2', 'nested-control']:
        inp = inputs[name]
        stem = label + '-' + name
        result = out / (stem + '.mir')
        run(stem + '-input-check', [llc, '-mtriple=mos', '-mcpu=mosw65816',
                                    '-run-pass=machineverifier', inp, '-o', '/dev/null'])
        rc = run(stem, [llc, '-mtriple=mos', '-mcpu=mosw65816',
                        '-run-pass=scavenger-test', '-verify-machineinstrs',
                        inp, '-o', result])
        if rc == 0:
            run(stem + '-output-check', [check, inp, '--input-file', result])
            hashes[str(result)] = sha(result)
    pass_name = 'prologepilog' if label == 'full-fork' else 'prolog-epilog'
    result = out / (label + '-known-0011.mir')
    rc = run(label + '-known-0011', [llc, '-mtriple=mos', '-mcpu=mos6502', '-O0',
                                    '-stop-after=' + pass_name, '-verify-machineinstrs',
                                    inputs['known-0011'], '-o', result])
    if rc == 0:
        run(label + '-known-0011-check', [check, inputs['known-0011'], '--input-file', result])
    (out / 'results.json').write_text(json.dumps(
        {'hashes': hashes, 'runs': runs}, indent=2) + '\n')
