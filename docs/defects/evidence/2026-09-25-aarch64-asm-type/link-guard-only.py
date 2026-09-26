"""Link the AArch64 guard with the original SelectionDAG implementation."""

from pathlib import Path
import shlex
import subprocess

root = Path('/work')
evidence = root / 'docs/defects/evidence/2026-09-25-aarch64-asm-type'
lines = (evidence / 'candidate-build.log').read_text().splitlines()
args = shlex.split(next(line[2:] for line in reversed(lines) if line.startswith('$ ')))
args[args.index('-o') + 1] = '/tmp/aarch64-asm-type-fix/llc-guard-only'
args = ['lib/libLLVMSelectionDAG.a' if arg == str(
    root / 'build/selectiondag-inlineasm-fix/libLLVMSelectionDAG.a') else arg
    for arg in args]
args = [arg.replace('/llc-link.d', '/guard-only-link.d') for arg in args]
with (evidence / 'guard-only-link.log').open('w') as log:
    log.write('$ ' + shlex.join(args) + '\n')
    log.flush()
    subprocess.run(args, cwd=root / 'build/newton-postra-build',
                   stdout=log, stderr=subprocess.STDOUT, check=True)
