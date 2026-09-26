#!/usr/bin/env python3
"""Compare retained current tools without changing compiler sources."""
import hashlib
import json
from pathlib import Path
import resource
import subprocess

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent / '0060-current-upstream-reconcile'
out.mkdir(exist_ok=False)
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
mir = out.parent / 'parallel-instr-reduce-x86.mir'
fc = root / 'build/post-ready-validation-mos/0039/baseline-bin/FileCheck'
tools = {
    'mos-current': root / 'build/post-ready-validation-mos/0039/baseline-bin/llvm-reduce',
    'llvm-current': root / 'build/post-ready-validation-llvm/0060/baseline-bin/llvm-reduce',
    'llvm-delta-candidate': root / 'build/post-ready-validation-llvm/0060/candidate-bin/llvm-reduce',
}
result = {'input': str(mir.relative_to(root)), 'input_sha256': hashlib.sha256(mir.read_bytes()).hexdigest(),
          'binaries': {}, 'runs': []}
def run(name, command):
    command = [str(x) for x in command]
    p = subprocess.run(command, capture_output=True, timeout=150)
    log = out / (name + '.log')
    log.write_bytes(p.stdout + p.stderr)
    result['runs'].append({'name': name, 'command': command, 'returncode': p.returncode,
                           'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()})
    print(name, p.returncode, flush=True)
    return p
for name, binary in tools.items():
    result['binaries'][name] = {'path': str(binary.relative_to(root)),
                              'sha256': hashlib.sha256(binary.read_bytes()).hexdigest(),
                              'version': subprocess.check_output([binary, '--version'], text=True)}
    for jobs in [1, 2, 4]:
        output = out / f'{name}-j{jobs}.mir'
        p = run(f'{name}-j{jobs}', [binary, '-x=mir', '-j', jobs, '--delta-passes=instructions',
                '--test', fc, '--test-arg', '--check-prefix=INTERESTING', '--test-arg', mir,
                '--test-arg', '--input-file', mir, '-o', output])
        if p.returncode == 0:
            run(f'{name}-j{jobs}-check', [fc, '--check-prefix=CHECK', mir, '--input-file', output])
    ir = root / 'build/post-ready-2026-09-26-llvm-src/llvm/test/tools/llvm-reduce/operands-skip.ll'
    irout = out / (name + '-parallel-ir.ll')
    p = run(name + '-parallel-ir', [binary, '-j', 2, '--abort-on-invalid-reduction', ir, '-o', irout,
            '--delta-passes=operands-skip', '--test', fc, '--test-arg', ir,
            '--test-arg', '--match-full-lines', '--test-arg', '--check-prefix=INTERESTING',
            '--test-arg', '--input-file'])
    if p.returncode == 0:
        run(name + '-parallel-ir-check', [fc, ir, '--input-file', irout, '--check-prefix=REDUCED'])
(out / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
